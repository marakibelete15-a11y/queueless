-- UP
-- Cross-tenant user references use clinic_id + the globally unique entity ID.
-- RESTRICT keeps the editor identity while settings remain attributable.
ALTER TABLE clinic_setting ADD CONSTRAINT clinic_setting_updater_fk
  FOREIGN KEY (clinic_id, updated_by) REFERENCES app_user(clinic_id, user_id) ON DELETE RESTRICT;
-- RESTRICT protects schedule templates while the clinic exists.
ALTER TABLE doctor_schedule ADD CONSTRAINT doctor_schedule_clinic_fk
  FOREIGN KEY (clinic_id) REFERENCES clinic(clinic_id) ON DELETE RESTRICT;
-- RESTRICT preserves one-off schedule blocks with clinic history.
ALTER TABLE schedule_block ADD CONSTRAINT schedule_block_clinic_fk
  FOREIGN KEY (clinic_id) REFERENCES clinic(clinic_id) ON DELETE RESTRICT;
-- RESTRICT preserves appointment slots with clinic history.
ALTER TABLE slot ADD CONSTRAINT slot_clinic_fk
  FOREIGN KEY (clinic_id) REFERENCES clinic(clinic_id) ON DELETE RESTRICT;
-- RESTRICT avoids removing server-side sessions through clinic deletion.
ALTER TABLE session ADD CONSTRAINT session_clinic_fk
  FOREIGN KEY (clinic_id) REFERENCES clinic(clinic_id) ON DELETE RESTRICT;
-- RESTRICT preserves clinic-owned visits until approved retention processing.
ALTER TABLE visit ADD CONSTRAINT visit_clinic_fk
  FOREIGN KEY (clinic_id) REFERENCES clinic(clinic_id) ON DELETE RESTRICT;
-- RESTRICT retains daily queue state with its clinic.
ALTER TABLE doctor_day_queue ADD CONSTRAINT doctor_day_queue_clinic_fk
  FOREIGN KEY (clinic_id) REFERENCES clinic(clinic_id) ON DELETE RESTRICT;
-- RESTRICT retains queue history with its clinic.
ALTER TABLE queue_entry ADD CONSTRAINT queue_entry_clinic_fk
  FOREIGN KEY (clinic_id) REFERENCES clinic(clinic_id) ON DELETE RESTRICT;
-- RESTRICT retains visit events with their clinic.
ALTER TABLE visit_event ADD CONSTRAINT visit_event_clinic_fk
  FOREIGN KEY (clinic_id) REFERENCES clinic(clinic_id) ON DELETE RESTRICT;

CREATE FUNCTION generate_booking_ref() RETURNS text
LANGUAGE plpgsql VOLATILE AS $$
DECLARE alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
DECLARE bytes bytea := gen_random_bytes(12);
DECLARE result text := '';
DECLARE i integer;
BEGIN
  FOR i IN 0..11 LOOP
    result := result || substr(alphabet, (get_byte(bytes, i) % 32) + 1, 1);
  END LOOP;
  RETURN result;
END $$;

CREATE FUNCTION touch_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := clock_timestamp();
  RETURN NEW;
END $$;
CREATE TRIGGER clinic_updated_at BEFORE UPDATE ON clinic FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER clinic_setting_updated_at BEFORE UPDATE ON clinic_setting FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER app_user_updated_at BEFORE UPDATE ON app_user FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER doctor_updated_at BEFORE UPDATE ON doctor FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER doctor_schedule_updated_at BEFORE UPDATE ON doctor_schedule FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER schedule_block_updated_at BEFORE UPDATE ON schedule_block FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER slot_updated_at BEFORE UPDATE ON slot FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER patient_updated_at BEFORE UPDATE ON patient FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER clinic_notice_updated_at BEFORE UPDATE ON clinic_notice FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE FUNCTION touch_day_queue_version() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := clock_timestamp();
  NEW.version := OLD.version + 1;
  IF NEW.next_queue_no < OLD.next_queue_no OR NEW.next_sequence_no < OLD.next_sequence_no THEN
    RAISE EXCEPTION 'doctor-day queue counters cannot move backwards' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER doctor_day_queue_version BEFORE UPDATE ON doctor_day_queue
FOR EACH ROW EXECUTE FUNCTION touch_day_queue_version();

CREATE FUNCTION validate_slot_schedule_owner() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.schedule_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM doctor_schedule s WHERE s.clinic_id = NEW.clinic_id
      AND s.schedule_id = NEW.schedule_id AND s.doctor_id = NEW.doctor_id
  ) THEN RAISE EXCEPTION 'slot schedule must belong to its clinic and doctor' USING ERRCODE = '23514'; END IF;
  IF NEW.is_blocked AND EXISTS (
    SELECT 1 FROM visit v WHERE v.clinic_id = NEW.clinic_id AND v.slot_id = NEW.slot_id
      AND v.status <> 'Cancelled'
  ) THEN RAISE EXCEPTION 'a booked slot cannot be blocked' USING ERRCODE = '23514'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER slot_schedule_owner BEFORE INSERT OR UPDATE OF clinic_id, doctor_id, schedule_id, is_blocked ON slot
FOR EACH ROW EXECUTE FUNCTION validate_slot_schedule_owner();

CREATE FUNCTION validate_visit_slot_owner() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.slot_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM slot s JOIN clinic c ON c.clinic_id = s.clinic_id
    WHERE s.clinic_id = NEW.clinic_id AND s.slot_id = NEW.slot_id
      AND s.doctor_id = NEW.doctor_id AND NOT s.is_blocked
      AND (s.start_at AT TIME ZONE c.timezone)::date = NEW.visit_date
  ) THEN RAISE EXCEPTION 'appointment slot must belong to the visit doctor and clinic day and be available' USING ERRCODE = '23514'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER visit_slot_owner BEFORE INSERT OR UPDATE OF clinic_id, doctor_id, slot_id, visit_date ON visit
FOR EACH ROW EXECUTE FUNCTION validate_visit_slot_owner();

CREATE FUNCTION validate_queue_entry_visit_owner() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM visit v WHERE v.clinic_id = NEW.clinic_id AND v.visit_id = NEW.visit_id
      AND v.doctor_id = NEW.doctor_id AND v.visit_date = NEW.queue_date
      AND v.status NOT IN ('Booked', 'No-Show')
  ) THEN RAISE EXCEPTION 'queue entry must match an arrived visit clinic, doctor, and day' USING ERRCODE = '23514'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER queue_entry_visit_owner BEFORE INSERT OR UPDATE OF clinic_id, visit_id, doctor_id, queue_date ON queue_entry
FOR EACH ROW EXECUTE FUNCTION validate_queue_entry_visit_owner();

CREATE FUNCTION enforce_visit_queue_times() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  target_visit uuid := NEW.visit_id;
  visit_status text;
  arrival_time timestamptz;
  call_time timestamptz;
  start_time timestamptz;
  completion_time timestamptz;
BEGIN
  SELECT status INTO visit_status FROM visit WHERE visit_id = target_visit;
  IF NOT FOUND THEN RETURN NULL; END IF;
  SELECT arrived_at, called_at, started_at, completed_at
    INTO arrival_time, call_time, start_time, completion_time
  FROM queue_entry WHERE visit_id = target_visit;
  IF visit_status IN ('Waiting', 'Called', 'In Consultation', 'Completed') AND arrival_time IS NULL THEN
    RAISE EXCEPTION 'visit status % requires queue_entry.arrived_at', visit_status USING ERRCODE = '23514';
  END IF;
  IF visit_status IN ('Called', 'In Consultation', 'Completed') AND call_time IS NULL THEN
    RAISE EXCEPTION 'visit status % requires queue_entry.called_at', visit_status USING ERRCODE = '23514';
  END IF;
  IF visit_status IN ('In Consultation', 'Completed') AND start_time IS NULL THEN
    RAISE EXCEPTION 'visit status % requires queue_entry.started_at', visit_status USING ERRCODE = '23514';
  END IF;
  IF visit_status = 'Completed' AND completion_time IS NULL THEN
    RAISE EXCEPTION 'Completed visits require queue_entry.completed_at' USING ERRCODE = '23514';
  END IF;
  RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER visit_queue_times_from_visit AFTER INSERT OR UPDATE OF status ON visit
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION enforce_visit_queue_times();
CREATE CONSTRAINT TRIGGER visit_queue_times_from_entry AFTER INSERT OR UPDATE ON queue_entry
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION enforce_visit_queue_times();

-- DB-1: canceled appointments release their slot; all other appointment statuses reserve it.
CREATE UNIQUE INDEX visit_one_active_appointment_per_slot_uq
  ON visit(slot_id) WHERE type = 'appointment' AND status <> 'Cancelled';
-- DB-4: one visit may be Called and one may be In Consultation per doctor.
CREATE UNIQUE INDEX visit_one_called_per_doctor_uq ON visit(doctor_id) WHERE status = 'Called';
CREATE UNIQUE INDEX visit_one_consultation_per_doctor_uq ON visit(doctor_id) WHERE status = 'In Consultation';
-- DB-6: paper ticket identifiers are clinic-day unique only when supplied.
CREATE UNIQUE INDEX queue_entry_paper_ref_uq ON queue_entry(clinic_id, queue_date, paper_ref) WHERE paper_ref IS NOT NULL;

-- Foreign-key indexes (the key begins with each referencing clinic/entity scope).
CREATE INDEX clinic_setting_updated_by_idx ON clinic_setting(clinic_id, updated_by) WHERE updated_by IS NOT NULL;
CREATE INDEX doctor_schedule_clinic_fk_idx ON doctor_schedule(clinic_id);
CREATE INDEX schedule_block_clinic_fk_idx ON schedule_block(clinic_id);
CREATE INDEX slot_clinic_fk_idx ON slot(clinic_id);
CREATE INDEX session_clinic_fk_idx ON session(clinic_id);
CREATE INDEX visit_clinic_fk_idx ON visit(clinic_id);
CREATE INDEX doctor_day_queue_clinic_fk_idx ON doctor_day_queue(clinic_id);
CREATE INDEX queue_entry_clinic_fk_idx ON queue_entry(clinic_id);
CREATE INDEX queue_entry_visit_fk_idx ON queue_entry(clinic_id, visit_id);
CREATE INDEX visit_event_clinic_fk_idx ON visit_event(clinic_id);
CREATE INDEX visit_event_visit_fk_idx ON visit_event(clinic_id, visit_id);
CREATE INDEX app_user_clinic_idx ON app_user(clinic_id);
CREATE INDEX session_user_fk_idx ON session(clinic_id, user_id);
CREATE INDEX doctor_user_fk_idx ON doctor(clinic_id, user_id) WHERE user_id IS NOT NULL;
CREATE INDEX doctor_schedule_doctor_fk_idx ON doctor_schedule(clinic_id, doctor_id);
CREATE INDEX schedule_block_doctor_fk_idx ON schedule_block(clinic_id, doctor_id);
CREATE INDEX schedule_block_creator_fk_idx ON schedule_block(clinic_id, created_by);
CREATE INDEX slot_doctor_fk_idx ON slot(clinic_id, doctor_id);
CREATE INDEX slot_schedule_fk_idx ON slot(clinic_id, schedule_id) WHERE schedule_id IS NOT NULL;
CREATE INDEX patient_clinic_fk_idx ON patient(clinic_id);
CREATE INDEX visit_patient_fk_idx ON visit(clinic_id, patient_id);
CREATE INDEX visit_doctor_fk_idx ON visit(clinic_id, doctor_id);
CREATE INDEX visit_slot_fk_idx ON visit(clinic_id, slot_id) WHERE slot_id IS NOT NULL;
CREATE INDEX visit_booker_fk_idx ON visit(clinic_id, booked_by) WHERE booked_by IS NOT NULL;
CREATE INDEX queue_entry_doctor_fk_idx ON queue_entry(clinic_id, doctor_id, queue_date);
CREATE INDEX queue_entry_backfiller_fk_idx ON queue_entry(clinic_id, backfilled_by) WHERE backfilled_by IS NOT NULL;
CREATE INDEX visit_event_actor_fk_idx ON visit_event(clinic_id, actor_user_id) WHERE actor_user_id IS NOT NULL;
CREATE INDEX clinic_notice_clinic_fk_idx ON clinic_notice(clinic_id);
CREATE INDEX activity_log_actor_fk_idx ON activity_log(clinic_id, actor_user_id) WHERE actor_user_id IS NOT NULL;
CREATE INDEX rate_limit_clinic_fk_idx ON rate_limit_counter(clinic_id);
CREATE INDEX retention_approval_actor_fk_idx ON retention_approval(clinic_id, approved_by);
CREATE INDEX retention_summary_approval_fk_idx ON retention_visit_summary(approval_id);
CREATE INDEX retention_summary_doctor_fk_idx ON retention_visit_summary(clinic_id, doctor_id);

-- Time-sort and dashboard-query indexes.
CREATE INDEX visit_created_at_idx ON visit(created_at DESC);
CREATE INDEX visit_dashboard_day_idx ON visit(clinic_id, visit_date, doctor_id, status);
CREATE INDEX visit_patient_lookup_idx ON visit(clinic_id, patient_id, created_at DESC);
CREATE INDEX visit_status_token_idx ON visit(status_token) WHERE status_token IS NOT NULL;
CREATE INDEX patient_phone_idx ON patient(clinic_id, phone) WHERE phone IS NOT NULL;
CREATE INDEX slot_start_at_idx ON slot(start_at);
CREATE INDEX queue_entry_effective_time_idx ON queue_entry(effective_time);
CREATE INDEX queue_entry_arrived_at_idx ON queue_entry(arrived_at) WHERE arrived_at IS NOT NULL;
CREATE INDEX queue_entry_board_idx ON queue_entry(doctor_id, queue_date, priority_flag DESC, effective_time, sequence_no);
CREATE INDEX queue_entry_eta_idx ON queue_entry(doctor_id, completed_at DESC)
  WHERE completed_at IS NOT NULL AND times_backfilled = false;
CREATE INDEX visit_event_created_at_idx ON visit_event(created_at DESC);
CREATE INDEX visit_event_unread_idx ON visit_event(visit_id, is_read) WHERE is_read = false;
CREATE INDEX activity_log_newest_idx ON activity_log(clinic_id, at DESC);
CREATE INDEX session_expiry_idx ON session(expires_at);
CREATE INDEX rate_limit_expiry_idx ON rate_limit_counter(expires_at);
CREATE INDEX retention_approval_pending_idx ON retention_approval(clinic_id, category, cutoff_at) WHERE executed_at IS NULL;

-- DOWN
DROP INDEX IF EXISTS retention_approval_pending_idx;
DROP INDEX IF EXISTS rate_limit_expiry_idx;
DROP INDEX IF EXISTS session_expiry_idx;
DROP INDEX IF EXISTS activity_log_newest_idx;
DROP INDEX IF EXISTS visit_event_unread_idx;
DROP INDEX IF EXISTS visit_event_created_at_idx;
DROP INDEX IF EXISTS queue_entry_eta_idx;
DROP INDEX IF EXISTS queue_entry_board_idx;
DROP INDEX IF EXISTS queue_entry_arrived_at_idx;
DROP INDEX IF EXISTS queue_entry_effective_time_idx;
DROP INDEX IF EXISTS slot_start_at_idx;
DROP INDEX IF EXISTS patient_phone_idx;
DROP INDEX IF EXISTS visit_status_token_idx;
DROP INDEX IF EXISTS visit_patient_lookup_idx;
DROP INDEX IF EXISTS visit_dashboard_day_idx;
DROP INDEX IF EXISTS visit_created_at_idx;
DROP INDEX IF EXISTS retention_summary_doctor_fk_idx;
DROP INDEX IF EXISTS retention_approval_actor_fk_idx;
DROP INDEX IF EXISTS retention_summary_approval_fk_idx;
DROP INDEX IF EXISTS rate_limit_clinic_fk_idx;
DROP INDEX IF EXISTS activity_log_actor_fk_idx;
DROP INDEX IF EXISTS clinic_notice_clinic_fk_idx;
DROP INDEX IF EXISTS visit_event_actor_fk_idx;
DROP INDEX IF EXISTS queue_entry_backfiller_fk_idx;
DROP INDEX IF EXISTS queue_entry_doctor_fk_idx;
DROP INDEX IF EXISTS visit_booker_fk_idx;
DROP INDEX IF EXISTS visit_slot_fk_idx;
DROP INDEX IF EXISTS visit_doctor_fk_idx;
DROP INDEX IF EXISTS visit_patient_fk_idx;
DROP INDEX IF EXISTS patient_clinic_fk_idx;
DROP INDEX IF EXISTS slot_schedule_fk_idx;
DROP INDEX IF EXISTS slot_doctor_fk_idx;
DROP INDEX IF EXISTS schedule_block_creator_fk_idx;
DROP INDEX IF EXISTS schedule_block_doctor_fk_idx;
DROP INDEX IF EXISTS doctor_schedule_doctor_fk_idx;
DROP INDEX IF EXISTS doctor_user_fk_idx;
DROP INDEX IF EXISTS session_user_fk_idx;
DROP INDEX IF EXISTS app_user_clinic_idx;
DROP INDEX IF EXISTS clinic_setting_updated_by_idx;
DROP INDEX IF EXISTS visit_event_clinic_fk_idx;
DROP INDEX IF EXISTS visit_event_visit_fk_idx;
DROP INDEX IF EXISTS queue_entry_clinic_fk_idx;
DROP INDEX IF EXISTS queue_entry_visit_fk_idx;
DROP INDEX IF EXISTS doctor_day_queue_clinic_fk_idx;
DROP INDEX IF EXISTS visit_clinic_fk_idx;
DROP INDEX IF EXISTS session_clinic_fk_idx;
DROP INDEX IF EXISTS slot_clinic_fk_idx;
DROP INDEX IF EXISTS schedule_block_clinic_fk_idx;
DROP INDEX IF EXISTS doctor_schedule_clinic_fk_idx;
DROP INDEX IF EXISTS queue_entry_paper_ref_uq;
DROP INDEX IF EXISTS visit_one_consultation_per_doctor_uq;
DROP INDEX IF EXISTS visit_one_called_per_doctor_uq;
DROP INDEX IF EXISTS visit_one_active_appointment_per_slot_uq;
DROP TRIGGER IF EXISTS visit_queue_times_from_entry ON queue_entry;
DROP TRIGGER IF EXISTS visit_queue_times_from_visit ON visit;
DROP FUNCTION IF EXISTS enforce_visit_queue_times();
DROP TRIGGER IF EXISTS queue_entry_visit_owner ON queue_entry;
DROP FUNCTION IF EXISTS validate_queue_entry_visit_owner();
DROP TRIGGER IF EXISTS visit_slot_owner ON visit;
DROP FUNCTION IF EXISTS validate_visit_slot_owner();
DROP TRIGGER IF EXISTS slot_schedule_owner ON slot;
DROP FUNCTION IF EXISTS validate_slot_schedule_owner();
DROP TRIGGER IF EXISTS doctor_day_queue_version ON doctor_day_queue;
DROP FUNCTION IF EXISTS touch_day_queue_version();
DROP TRIGGER IF EXISTS clinic_notice_updated_at ON clinic_notice;
DROP TRIGGER IF EXISTS patient_updated_at ON patient;
DROP TRIGGER IF EXISTS slot_updated_at ON slot;
DROP TRIGGER IF EXISTS schedule_block_updated_at ON schedule_block;
DROP TRIGGER IF EXISTS doctor_schedule_updated_at ON doctor_schedule;
DROP TRIGGER IF EXISTS doctor_updated_at ON doctor;
DROP TRIGGER IF EXISTS app_user_updated_at ON app_user;
DROP TRIGGER IF EXISTS clinic_setting_updated_at ON clinic_setting;
DROP TRIGGER IF EXISTS clinic_updated_at ON clinic;
DROP FUNCTION IF EXISTS touch_updated_at();
DROP FUNCTION IF EXISTS generate_booking_ref();
ALTER TABLE clinic_setting DROP CONSTRAINT IF EXISTS clinic_setting_updater_fk;
ALTER TABLE visit_event DROP CONSTRAINT IF EXISTS visit_event_clinic_fk;
ALTER TABLE queue_entry DROP CONSTRAINT IF EXISTS queue_entry_clinic_fk;
ALTER TABLE doctor_day_queue DROP CONSTRAINT IF EXISTS doctor_day_queue_clinic_fk;
ALTER TABLE visit DROP CONSTRAINT IF EXISTS visit_clinic_fk;
ALTER TABLE session DROP CONSTRAINT IF EXISTS session_clinic_fk;
ALTER TABLE slot DROP CONSTRAINT IF EXISTS slot_clinic_fk;
ALTER TABLE schedule_block DROP CONSTRAINT IF EXISTS schedule_block_clinic_fk;
ALTER TABLE doctor_schedule DROP CONSTRAINT IF EXISTS doctor_schedule_clinic_fk;
