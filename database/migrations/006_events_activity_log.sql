CREATE TABLE visit_event (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), clinic_id uuid NOT NULL, visit_id uuid NOT NULL, actor_user_id uuid,
  event_type text NOT NULL CHECK (event_type IN ('Booked','Checked In','Called','Skipped','Consultation Started','Completed','Cancelled','No-Show','Resumed','Backfilled')),
  from_status text CHECK (from_status IN ('Booked','Waiting','Called','In Consultation','Completed','Cancelled','No-Show')),
  to_status text CHECK (to_status IN ('Booked','Waiting','Called','In Consultation','Completed','Cancelled','No-Show')),
  message_key text, occurred_at timestamptz NOT NULL DEFAULT now(), is_backfilled boolean NOT NULL DEFAULT false,
  backfilled_at timestamptz, administrative_reason text,
  FOREIGN KEY (clinic_id, visit_id) REFERENCES visit(clinic_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (clinic_id, actor_user_id) REFERENCES app_user(clinic_id, id) ON DELETE RESTRICT,
  CHECK ((is_backfilled AND backfilled_at IS NOT NULL) OR (NOT is_backfilled AND backfilled_at IS NULL)),
  CHECK (administrative_reason IS NULL OR length(trim(administrative_reason)) > 0)
);
CREATE INDEX visit_event_history_idx ON visit_event(clinic_id, visit_id, occurred_at);

CREATE TABLE clinic_notice (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), clinic_id uuid NOT NULL REFERENCES clinic(id) ON DELETE RESTRICT,
  notice_type text NOT NULL CHECK (notice_type IN ('Public','Emergency')), message text NOT NULL CHECK (length(trim(message)) > 0),
  starts_at timestamptz NOT NULL, ends_at timestamptz, created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (clinic_id, created_by) REFERENCES app_user(clinic_id, id) ON DELETE RESTRICT,
  CHECK (ends_at IS NULL OR ends_at > starts_at)
);
CREATE INDEX clinic_notice_current_idx ON clinic_notice(clinic_id, starts_at, ends_at);

CREATE TABLE activity_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, clinic_id uuid NOT NULL REFERENCES clinic(id) ON DELETE RESTRICT,
  actor_user_id uuid, session_id uuid, event_type text NOT NULL CHECK (length(trim(event_type)) > 0),
  entity_type text, entity_id text, details jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (clinic_id, actor_user_id) REFERENCES app_user(clinic_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (clinic_id, session_id) REFERENCES user_session(clinic_id, id) ON DELETE RESTRICT,
  CHECK (jsonb_typeof(details) = 'object')
);
CREATE INDEX activity_log_clinic_time_idx ON activity_log(clinic_id, occurred_at DESC);

CREATE TABLE rate_limit_counter (
  clinic_id uuid NOT NULL REFERENCES clinic(id) ON DELETE RESTRICT, key_hash bytea NOT NULL CHECK (octet_length(key_hash) = 32),
  window_started_at timestamptz NOT NULL, count integer NOT NULL DEFAULT 0 CHECK (count >= 0), expires_at timestamptz NOT NULL,
  PRIMARY KEY (clinic_id, key_hash, window_started_at), CHECK (expires_at > window_started_at)
);
CREATE INDEX rate_limit_expiry_idx ON rate_limit_counter(expires_at);
