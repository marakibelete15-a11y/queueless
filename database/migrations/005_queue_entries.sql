CREATE TABLE doctor_day_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), clinic_id uuid NOT NULL, doctor_id uuid NOT NULL, queue_date date NOT NULL,
  next_queue_no integer NOT NULL DEFAULT 1 CHECK (next_queue_no > 0), next_sequence_no integer NOT NULL DEFAULT 1 CHECK (next_sequence_no > 0),
  state text NOT NULL DEFAULT 'Open' CHECK (state IN ('Open','Paused','Closed')), delay_minutes integer NOT NULL DEFAULT 0 CHECK (delay_minutes >= 0),
  auto_no_show_suspended boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (clinic_id, doctor_id, queue_date), UNIQUE (clinic_id, id),
  FOREIGN KEY (clinic_id, doctor_id) REFERENCES doctor(clinic_id, id) ON DELETE RESTRICT
);
CREATE TABLE queue_entry (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), clinic_id uuid NOT NULL, visit_id uuid NOT NULL, doctor_id uuid NOT NULL,
  queue_date date NOT NULL, queue_no integer NOT NULL CHECK (queue_no > 0), sequence_no integer NOT NULL CHECK (sequence_no > 0),
  effective_at timestamptz NOT NULL, is_priority boolean NOT NULL DEFAULT false, priority_reason text, priority_at timestamptz,
  skip_count smallint NOT NULL DEFAULT 0 CHECK (skip_count BETWEEN 0 AND 2), arrived_at timestamptz,
  called_at timestamptz, consultation_started_at timestamptz, completed_at timestamptz,
  backfilled boolean NOT NULL DEFAULT false, backfilled_at timestamptz, backfilled_by uuid, paper_ref text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (visit_id), UNIQUE (clinic_id, doctor_id, queue_date, queue_no), UNIQUE (clinic_id, doctor_id, queue_date, sequence_no),
  FOREIGN KEY (clinic_id, visit_id) REFERENCES visit(clinic_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (clinic_id, doctor_id, queue_date) REFERENCES doctor_day_queue(clinic_id, doctor_id, queue_date) ON DELETE RESTRICT,
  FOREIGN KEY (clinic_id, backfilled_by) REFERENCES app_user(clinic_id, id) ON DELETE RESTRICT,
  CHECK ((is_priority AND priority_reason IS NOT NULL AND priority_at IS NOT NULL) OR (NOT is_priority AND priority_reason IS NULL AND priority_at IS NULL)),
  CHECK ((backfilled AND backfilled_at IS NOT NULL) OR (NOT backfilled AND backfilled_at IS NULL)),
  CHECK (completed_at IS NULL OR consultation_started_at IS NOT NULL),
  CHECK (called_at IS NULL OR arrived_at IS NOT NULL), CHECK (consultation_started_at IS NULL OR called_at IS NOT NULL),
  CHECK (called_at IS NULL OR called_at >= arrived_at),
  CHECK (consultation_started_at IS NULL OR consultation_started_at >= called_at),
  CHECK (completed_at IS NULL OR completed_at >= consultation_started_at),
  CHECK (paper_ref IS NULL OR length(trim(paper_ref)) > 0)
);
CREATE UNIQUE INDEX queue_entry_paper_ref_uq ON queue_entry(clinic_id, queue_date, paper_ref) WHERE paper_ref IS NOT NULL;
CREATE INDEX queue_entry_order_idx ON queue_entry(clinic_id, doctor_id, queue_date, is_priority DESC, effective_at, sequence_no);
CREATE INDEX queue_entry_visit_idx ON queue_entry(clinic_id, visit_id);
