-- UP
CREATE TABLE doctor_day_queue (
  clinic_id uuid NOT NULL,
  doctor_id uuid NOT NULL,
  queue_date date NOT NULL,
  state text NOT NULL DEFAULT 'open' CHECK (state IN ('open', 'closed')),
  auto_noshow_paused boolean NOT NULL DEFAULT false,
  delay_minutes integer NOT NULL DEFAULT 0 CHECK (delay_minutes >= 0),
  manual_mode boolean NOT NULL DEFAULT false,
  next_queue_no integer NOT NULL DEFAULT 1 CHECK (next_queue_no > 0),
  next_sequence_no integer NOT NULL DEFAULT 1 CHECK (next_sequence_no > 0),
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  -- Required natural primary key: one lockable queue row per doctor and clinic day.
  PRIMARY KEY (doctor_id, queue_date),
  UNIQUE (clinic_id, doctor_id, queue_date),
  -- RESTRICT retains doctor-day state while historical queue entries reference the doctor.
  CONSTRAINT doctor_day_queue_doctor_fk FOREIGN KEY (clinic_id, doctor_id)
    REFERENCES doctor(clinic_id, doctor_id) ON DELETE RESTRICT
);

CREATE TABLE queue_entry (
  queue_entry_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id uuid NOT NULL UNIQUE,
  clinic_id uuid NOT NULL,
  doctor_id uuid NOT NULL,
  queue_date date NOT NULL,
  queue_no integer NOT NULL CHECK (queue_no > 0),
  sequence_no integer NOT NULL CHECK (sequence_no > 0),
  effective_time timestamptz NOT NULL DEFAULT clock_timestamp(),
  priority_flag boolean NOT NULL DEFAULT false,
  priority_reason text,
  priority_set_at timestamptz,
  skip_count smallint NOT NULL DEFAULT 0 CHECK (skip_count BETWEEN 0 AND 2),
  arrived_at timestamptz,
  called_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  times_backfilled boolean NOT NULL DEFAULT false,
  backfilled_at timestamptz,
  backfilled_by uuid,
  paper_ref text,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (clinic_id, doctor_id, queue_date, queue_no),
  UNIQUE (clinic_id, doctor_id, queue_date, sequence_no),
  -- RESTRICT preserves the visit record and its sole queue entry together.
  CONSTRAINT queue_entry_visit_fk FOREIGN KEY (clinic_id, visit_id)
    REFERENCES visit(clinic_id, visit_id) ON DELETE RESTRICT,
  -- RESTRICT keeps the per-day serialization row while queue history exists.
  CONSTRAINT queue_entry_day_fk FOREIGN KEY (clinic_id, doctor_id, queue_date)
    REFERENCES doctor_day_queue(clinic_id, doctor_id, queue_date) ON DELETE RESTRICT,
  -- RESTRICT preserves staff attribution for manually backfilled times.
  CONSTRAINT queue_entry_backfiller_fk FOREIGN KEY (clinic_id, backfilled_by)
    REFERENCES app_user(clinic_id, user_id) ON DELETE RESTRICT,
  CHECK (
    (priority_flag AND priority_reason IS NOT NULL AND length(btrim(priority_reason)) BETWEEN 5 AND 200
      AND priority_set_at IS NOT NULL)
    OR (NOT priority_flag AND priority_reason IS NULL AND priority_set_at IS NULL)
  ),
  CHECK ((times_backfilled AND backfilled_at IS NOT NULL) OR (NOT times_backfilled AND backfilled_at IS NULL)),
  CHECK (completed_at IS NULL OR started_at IS NOT NULL),
  CHECK (started_at IS NULL OR called_at IS NOT NULL),
  CHECK (called_at IS NULL OR arrived_at IS NOT NULL),
  CHECK (called_at IS NULL OR called_at >= arrived_at),
  CHECK (started_at IS NULL OR started_at >= called_at),
  CHECK (completed_at IS NULL OR completed_at >= started_at),
  CHECK (paper_ref IS NULL OR length(btrim(paper_ref)) > 0)
);

CREATE FUNCTION stamp_queue_server_times() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  now_at timestamptz := clock_timestamp();
BEGIN
  IF NOT NEW.times_backfilled THEN
    IF TG_OP = 'INSERT' THEN
      NEW.effective_time := now_at;
      NEW.arrived_at := CASE WHEN NEW.arrived_at IS NULL THEN NULL ELSE now_at END;
      NEW.called_at := CASE WHEN NEW.called_at IS NULL THEN NULL ELSE now_at END;
      NEW.started_at := CASE WHEN NEW.started_at IS NULL THEN NULL ELSE now_at END;
      NEW.completed_at := CASE WHEN NEW.completed_at IS NULL THEN NULL ELSE now_at END;
      NEW.priority_set_at := CASE WHEN NEW.priority_flag THEN now_at ELSE NULL END;
    ELSE
      IF NEW.arrived_at IS DISTINCT FROM OLD.arrived_at AND NEW.arrived_at IS NOT NULL THEN NEW.arrived_at := now_at; END IF;
      IF NEW.called_at IS DISTINCT FROM OLD.called_at AND NEW.called_at IS NOT NULL THEN NEW.called_at := now_at; END IF;
      IF NEW.started_at IS DISTINCT FROM OLD.started_at AND NEW.started_at IS NOT NULL THEN NEW.started_at := now_at; END IF;
      IF NEW.completed_at IS DISTINCT FROM OLD.completed_at AND NEW.completed_at IS NOT NULL THEN NEW.completed_at := now_at; END IF;
      IF NEW.priority_flag AND (OLD.priority_flag IS DISTINCT FROM NEW.priority_flag OR OLD.priority_reason IS DISTINCT FROM NEW.priority_reason)
        THEN NEW.priority_set_at := now_at;
      ELSIF NOT NEW.priority_flag THEN NEW.priority_set_at := NULL;
      END IF;
    END IF;
    NEW.backfilled_at := NULL;
  ELSIF NEW.backfilled_at IS NULL THEN
    NEW.backfilled_at := now_at;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER queue_entry_server_times BEFORE INSERT OR UPDATE ON queue_entry
FOR EACH ROW EXECUTE FUNCTION stamp_queue_server_times();

-- DOWN
DROP TRIGGER IF EXISTS queue_entry_server_times ON queue_entry;
DROP FUNCTION IF EXISTS stamp_queue_server_times();
DROP TABLE IF EXISTS queue_entry;
DROP TABLE IF EXISTS doctor_day_queue;
