-- UP
CREATE TABLE visit_event (
  event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL,
  visit_id uuid NOT NULL,
  actor_user_id uuid,
  event_key text NOT NULL CHECK (length(btrim(event_key)) > 0),
  message_key text,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  -- RESTRICT retains event history until its parent visit is approved for retention cleanup.
  CONSTRAINT visit_event_visit_fk FOREIGN KEY (clinic_id, visit_id)
    REFERENCES visit(clinic_id, visit_id) ON DELETE RESTRICT,
  -- SET NULL keeps patient-visible visit history when a staff identity is removed.
  CONSTRAINT visit_event_actor_fk FOREIGN KEY (clinic_id, actor_user_id)
    REFERENCES app_user(clinic_id, user_id) ON DELETE SET NULL (actor_user_id)
);

CREATE TABLE clinic_notice (
  notice_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL,
  kind text NOT NULL CHECK (kind IN ('public', 'emergency')),
  text text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  -- RESTRICT prevents losing clinic notices when a clinic row is removed.
  CONSTRAINT clinic_notice_clinic_fk FOREIGN KEY (clinic_id)
    REFERENCES clinic(clinic_id) ON DELETE RESTRICT,
  CHECK (kind <> 'emergency' OR length(btrim(text)) > 0)
);

CREATE TABLE activity_log (
  log_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL,
  at timestamptz NOT NULL DEFAULT clock_timestamp(),
  actor_user_id uuid,
  action text NOT NULL CHECK (length(btrim(action)) > 0),
  target_type text NOT NULL CHECK (length(btrim(target_type)) > 0),
  target_id text,
  reason text,
  -- RESTRICT retains audit rows while their clinic exists.
  CONSTRAINT activity_log_clinic_fk FOREIGN KEY (clinic_id)
    REFERENCES clinic(clinic_id) ON DELETE RESTRICT,
  -- SET NULL preserves the audit record if the attributed user is removed.
  CONSTRAINT activity_log_actor_fk FOREIGN KEY (clinic_id, actor_user_id)
    REFERENCES app_user(clinic_id, user_id) ON DELETE SET NULL (actor_user_id)
);

CREATE TABLE rate_limit_counter (
  clinic_id uuid NOT NULL,
  key_hash bytea NOT NULL CHECK (octet_length(key_hash) = 32),
  window_start timestamptz NOT NULL,
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  expires_at timestamptz NOT NULL,
  PRIMARY KEY (clinic_id, key_hash, window_start),
  -- RESTRICT retains technical counters until explicit expiry cleanup.
  CONSTRAINT rate_limit_clinic_fk FOREIGN KEY (clinic_id)
    REFERENCES clinic(clinic_id) ON DELETE RESTRICT,
  CHECK (expires_at > window_start)
);

CREATE TABLE retention_approval (
  approval_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL,
  category text NOT NULL CHECK (category IN ('visits', 'patients', 'activity_log')),
  cutoff_at timestamptz NOT NULL,
  approved_by uuid NOT NULL,
  reason text NOT NULL CHECK (length(btrim(reason)) BETWEEN 5 AND 500),
  approved_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  executed_at timestamptz,
  -- RESTRICT preserves retention approval evidence.
  CONSTRAINT retention_approval_clinic_fk FOREIGN KEY (clinic_id)
    REFERENCES clinic(clinic_id) ON DELETE RESTRICT,
  -- RESTRICT preserves the identity of the approving administrator.
  CONSTRAINT retention_approval_user_fk FOREIGN KEY (clinic_id, approved_by)
    REFERENCES app_user(clinic_id, user_id) ON DELETE RESTRICT,
  CHECK (cutoff_at <= approved_at)
);

CREATE FUNCTION require_retention_administrator() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM app_user u WHERE u.clinic_id=NEW.clinic_id
    AND u.user_id=NEW.approved_by AND u.role='administrator' AND u.is_active) THEN
    RAISE EXCEPTION 'retention approval must be recorded by an active administrator' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER retention_approval_admin_only BEFORE INSERT ON retention_approval
FOR EACH ROW EXECUTE FUNCTION require_retention_administrator();

CREATE TABLE retention_visit_summary (
  summary_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  approval_id uuid NOT NULL,
  clinic_id uuid NOT NULL,
  visit_date date NOT NULL,
  doctor_id uuid NOT NULL,
  status_counts jsonb NOT NULL CHECK (jsonb_typeof(status_counts) = 'object'),
  archived_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  -- RESTRICT keeps each aggregate attached to the approval that authorized its creation.
  CONSTRAINT retention_summary_approval_fk FOREIGN KEY (approval_id)
    REFERENCES retention_approval(approval_id) ON DELETE RESTRICT,
  -- RESTRICT keeps report aggregates attached to the clinic.
  CONSTRAINT retention_summary_clinic_fk FOREIGN KEY (clinic_id)
    REFERENCES clinic(clinic_id) ON DELETE RESTRICT,
  -- RESTRICT prevents removing a doctor referenced by retained aggregates.
  CONSTRAINT retention_summary_doctor_fk FOREIGN KEY (clinic_id, doctor_id)
    REFERENCES doctor(clinic_id, doctor_id) ON DELETE RESTRICT
);

CREATE FUNCTION reject_activity_log_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE'
     AND current_user <> session_user
     AND current_setting('queueless.retention_approval_id', true) IS NOT NULL
     AND EXISTS (
       SELECT 1 FROM retention_approval a
       WHERE a.approval_id = current_setting('queueless.retention_approval_id', true)::uuid
         AND a.category = 'activity_log' AND a.executed_at IS NULL
     ) THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'activity_log is append-only; approved retention procedure required' USING ERRCODE = '55000';
END $$;
CREATE TRIGGER activity_log_append_only BEFORE UPDATE OR DELETE ON activity_log
FOR EACH ROW EXECUTE FUNCTION reject_activity_log_mutation();

CREATE FUNCTION cleanup_expired_rate_limit_counters() RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE removed bigint;
BEGIN
  DELETE FROM rate_limit_counter WHERE expires_at <= clock_timestamp();
  GET DIAGNOSTICS removed = ROW_COUNT;
  RETURN removed;
END $$;

CREATE FUNCTION cleanup_expired_sessions() RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE removed bigint;
BEGIN
  DELETE FROM session WHERE expires_at <= clock_timestamp();
  GET DIAGNOSTICS removed = ROW_COUNT;
  RETURN removed;
END $$;

CREATE FUNCTION clear_expired_final_status_tokens() RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE removed bigint;
BEGIN
  UPDATE visit SET status_token = NULL, version = version + 1
  WHERE status IN ('Completed', 'Cancelled', 'No-Show')
    AND status_token IS NOT NULL AND status_token_expires_at <= clock_timestamp();
  GET DIAGNOSTICS removed = ROW_COUNT;
  RETURN removed;
END $$;

CREATE FUNCTION queue_due_no_shows() RETURNS TABLE (visit_id uuid, clinic_id uuid, doctor_id uuid, visit_date date)
LANGUAGE sql VOLATILE AS $$
  SELECT v.visit_id, v.clinic_id, v.doctor_id, v.visit_date
  FROM visit v
  JOIN slot s ON s.clinic_id = v.clinic_id AND s.slot_id = v.slot_id
  JOIN doctor_day_queue q ON q.clinic_id = v.clinic_id AND q.doctor_id = v.doctor_id AND q.queue_date = v.visit_date
  JOIN clinic_setting timing ON timing.clinic_id = v.clinic_id AND timing.key = 'queue_timing'
  WHERE v.status = 'Booked'
    AND v.type = 'appointment'
    AND q.state = 'open'
    AND NOT q.auto_noshow_paused
    AND s.start_at + ((timing.value->>'no_show_deadline_minutes')::integer * interval '1 minute') <= clock_timestamp()
    AND NOT EXISTS (
      SELECT 1 FROM activity_log a
      WHERE a.clinic_id = v.clinic_id AND a.actor_user_id IS NOT NULL
        AND a.at >= clock_timestamp() - ((timing.value->>'staff_activity_guard_minutes')::integer * interval '1 minute')
    )
$$;

CREATE FUNCTION apply_due_no_shows() RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
  item record;
  changed bigint := 0;
BEGIN
  FOR item IN
    SELECT v.visit_id, v.clinic_id, v.doctor_id, v.visit_date
    FROM visit v
    JOIN slot s ON s.clinic_id=v.clinic_id AND s.slot_id=v.slot_id
    JOIN doctor_day_queue q ON q.clinic_id=v.clinic_id AND q.doctor_id=v.doctor_id AND q.queue_date=v.visit_date
    JOIN clinic_setting timing ON timing.clinic_id=v.clinic_id AND timing.key='queue_timing'
    WHERE v.status='Booked' AND v.type='appointment' AND q.state='open' AND NOT q.auto_noshow_paused
      AND s.start_at + ((timing.value->>'no_show_deadline_minutes')::integer * interval '1 minute') <= clock_timestamp()
      AND NOT EXISTS (
        SELECT 1 FROM activity_log a WHERE a.clinic_id=v.clinic_id AND a.actor_user_id IS NOT NULL
          AND a.at >= clock_timestamp() - ((timing.value->>'staff_activity_guard_minutes')::integer * interval '1 minute')
      )
    ORDER BY v.doctor_id, v.visit_date, s.start_at
    FOR UPDATE OF q, v SKIP LOCKED
  LOOP
    UPDATE visit SET status='No-Show', version=version+1 WHERE visit_id=item.visit_id AND status='Booked';
    IF FOUND THEN
      INSERT INTO visit_event (clinic_id, visit_id, event_key, message_key)
      VALUES (item.clinic_id, item.visit_id, 'visit.no_show', 'visit.no_show');
      INSERT INTO activity_log (clinic_id, action, target_type, target_id, reason)
      VALUES (item.clinic_id, 'visit.no_show.automatic', 'visit', item.visit_id::text,
              'No-Show deadline elapsed without arrival');
      changed := changed + 1;
    END IF;
  END LOOP;
  RETURN changed;
END $$;

CREATE FUNCTION execute_retention_approval(p_approval_id uuid) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
  approval retention_approval%ROWTYPE;
  allowed_days integer;
  changed bigint := 0;
  affected bigint := 0;
BEGIN
  SELECT * INTO approval FROM public.retention_approval
    WHERE approval_id = p_approval_id AND executed_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unknown or already executed retention approval'; END IF;

  SELECT (value #>> '{}')::integer INTO allowed_days
  FROM public.clinic_setting WHERE clinic_id = approval.clinic_id
    AND key = 'retention.' || approval.category || '_days' AND value IS NOT NULL;
  IF allowed_days IS NULL OR approval.cutoff_at > clock_timestamp() - (allowed_days * interval '1 day') THEN
    RAISE EXCEPTION 'retention period is unset or approval cutoff is not yet eligible';
  END IF;

  IF approval.category = 'visits' THEN
    INSERT INTO public.retention_visit_summary(approval_id, clinic_id, visit_date, doctor_id, status_counts)
    SELECT approval.approval_id, grouped.clinic_id, grouped.visit_date, grouped.doctor_id,
           jsonb_object_agg(grouped.status, grouped.visit_count)
    FROM (
      SELECT clinic_id, visit_date, doctor_id, status, count(*) AS visit_count
      FROM public.visit WHERE clinic_id = approval.clinic_id AND created_at < approval.cutoff_at
      GROUP BY clinic_id, visit_date, doctor_id, status
    ) grouped
    GROUP BY approval.approval_id, grouped.clinic_id, grouped.visit_date, grouped.doctor_id;
    DELETE FROM public.visit_event e USING public.visit v
      WHERE e.clinic_id = v.clinic_id AND e.visit_id = v.visit_id
        AND v.clinic_id = approval.clinic_id AND v.created_at < approval.cutoff_at;
    DELETE FROM public.queue_entry q USING public.visit v
      WHERE q.clinic_id = v.clinic_id AND q.visit_id = v.visit_id
        AND v.clinic_id = approval.clinic_id AND v.created_at < approval.cutoff_at;
    DELETE FROM public.visit WHERE clinic_id = approval.clinic_id AND created_at < approval.cutoff_at;
    GET DIAGNOSTICS changed = ROW_COUNT;
  ELSIF approval.category = 'patients' THEN
    DELETE FROM public.patient p WHERE p.clinic_id = approval.clinic_id AND p.created_at < approval.cutoff_at
      AND NOT EXISTS (SELECT 1 FROM public.visit v WHERE v.clinic_id = p.clinic_id AND v.patient_id = p.patient_id);
    GET DIAGNOSTICS changed = ROW_COUNT;
  ELSIF approval.category = 'activity_log' THEN
    PERFORM set_config('queueless.retention_approval_id', p_approval_id::text, true);
    DELETE FROM public.activity_log WHERE clinic_id = approval.clinic_id AND at < approval.cutoff_at;
    GET DIAGNOSTICS changed = ROW_COUNT;
  END IF;
  affected := changed;
  INSERT INTO public.activity_log (clinic_id, actor_user_id, action, target_type, target_id, reason)
  VALUES (approval.clinic_id, approval.approved_by, 'retention.executed', approval.category,
          approval.approval_id::text, 'Approved retention batch execution');
  UPDATE public.retention_approval SET executed_at = clock_timestamp() WHERE approval_id = p_approval_id;
  RETURN affected;
END $$;

REVOKE ALL ON FUNCTION execute_retention_approval(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION cleanup_expired_rate_limit_counters() FROM PUBLIC;
REVOKE ALL ON FUNCTION cleanup_expired_sessions() FROM PUBLIC;
REVOKE ALL ON FUNCTION clear_expired_final_status_tokens() FROM PUBLIC;
REVOKE ALL ON FUNCTION queue_due_no_shows() FROM PUBLIC;
REVOKE ALL ON FUNCTION apply_due_no_shows() FROM PUBLIC;

-- DOWN
DROP FUNCTION IF EXISTS execute_retention_approval(uuid);
DROP FUNCTION IF EXISTS apply_due_no_shows();
DROP FUNCTION IF EXISTS queue_due_no_shows();
DROP FUNCTION IF EXISTS clear_expired_final_status_tokens();
DROP FUNCTION IF EXISTS cleanup_expired_sessions();
DROP FUNCTION IF EXISTS cleanup_expired_rate_limit_counters();
DROP TRIGGER IF EXISTS activity_log_append_only ON activity_log;
DROP FUNCTION IF EXISTS reject_activity_log_mutation();
DROP TRIGGER IF EXISTS retention_approval_admin_only ON retention_approval;
DROP FUNCTION IF EXISTS require_retention_administrator();
DROP TABLE IF EXISTS retention_visit_summary;
DROP TABLE IF EXISTS retention_approval;
DROP TABLE IF EXISTS rate_limit_counter;
DROP TABLE IF EXISTS activity_log;
DROP TABLE IF EXISTS clinic_notice;
DROP TABLE IF EXISTS visit_event;
