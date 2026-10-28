CREATE TABLE doctor (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), clinic_id uuid NOT NULL, user_id uuid,
  display_name text NOT NULL CHECK (length(trim(display_name)) > 0), is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (clinic_id, id), UNIQUE (clinic_id, user_id),
  FOREIGN KEY (clinic_id) REFERENCES clinic(id) ON DELETE RESTRICT,
  FOREIGN KEY (clinic_id, user_id) REFERENCES app_user(clinic_id, id) ON DELETE RESTRICT
);
CREATE TABLE doctor_schedule (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), clinic_id uuid NOT NULL, doctor_id uuid NOT NULL,
  weekday smallint NOT NULL CHECK (weekday BETWEEN 0 AND 6), starts_at time NOT NULL, ends_at time NOT NULL,
  slot_duration_minutes integer NOT NULL CHECK (slot_duration_minutes > 0), effective_from date NOT NULL,
  effective_until date, is_active boolean NOT NULL DEFAULT true,
  UNIQUE (clinic_id, id), FOREIGN KEY (clinic_id, doctor_id) REFERENCES doctor(clinic_id, id) ON DELETE RESTRICT,
  CHECK (ends_at > starts_at), CHECK (effective_until IS NULL OR effective_until >= effective_from)
);
CREATE TABLE schedule_block (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), clinic_id uuid NOT NULL, doctor_id uuid NOT NULL,
  starts_at timestamptz NOT NULL, ends_at timestamptz NOT NULL, reason_code text NOT NULL,
  created_by uuid, created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (clinic_id, doctor_id) REFERENCES doctor(clinic_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (clinic_id, created_by) REFERENCES app_user(clinic_id, id) ON DELETE RESTRICT,
  CHECK (ends_at > starts_at)
);
CREATE TABLE slot (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), clinic_id uuid NOT NULL, doctor_id uuid NOT NULL,
  starts_at timestamptz NOT NULL, ends_at timestamptz NOT NULL, schedule_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (clinic_id, id),
  FOREIGN KEY (clinic_id, doctor_id) REFERENCES doctor(clinic_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (clinic_id, schedule_id) REFERENCES doctor_schedule(clinic_id, id) ON DELETE RESTRICT,
  CHECK (ends_at > starts_at), UNIQUE (clinic_id, doctor_id, starts_at)
);
CREATE INDEX schedule_block_doctor_time_idx ON schedule_block(clinic_id, doctor_id, starts_at, ends_at);
CREATE INDEX slot_doctor_time_idx ON slot(clinic_id, doctor_id, starts_at);
