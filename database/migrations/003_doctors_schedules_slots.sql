-- UP
CREATE TABLE doctor (
  doctor_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL,
  user_id uuid,
  name text NOT NULL CHECK (length(btrim(name)) > 0),
  specialty text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (clinic_id, doctor_id),
  UNIQUE (clinic_id, user_id),
  -- RESTRICT preserves doctor-linked appointment history.
  CONSTRAINT doctor_clinic_fk FOREIGN KEY (clinic_id)
    REFERENCES clinic(clinic_id) ON DELETE RESTRICT,
  -- RESTRICT prevents deletion of a linked staff identity while it is assigned as a doctor.
  CONSTRAINT doctor_user_fk FOREIGN KEY (clinic_id, user_id)
    REFERENCES app_user(clinic_id, user_id) ON DELETE RESTRICT
);

CREATE TABLE doctor_schedule (
  schedule_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL,
  doctor_id uuid NOT NULL,
  title text NOT NULL DEFAULT 'Regular clinic hours' CHECK (length(btrim(title)) > 0),
  weekday smallint NOT NULL CHECK (weekday BETWEEN 0 AND 6),
  start_time time NOT NULL,
  end_time time NOT NULL,
  slot_minutes smallint NOT NULL CHECK (slot_minutes BETWEEN 5 AND 60),
  effective_from date NOT NULL DEFAULT CURRENT_DATE,
  effective_until date,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (clinic_id, schedule_id),
  -- CASCADE removes recurring templates when a doctor is removed; visit history is separately RESTRICTed.
  CONSTRAINT doctor_schedule_doctor_fk FOREIGN KEY (clinic_id, doctor_id)
    REFERENCES doctor(clinic_id, doctor_id) ON DELETE CASCADE,
  CHECK (end_time > start_time),
  CHECK (effective_until IS NULL OR effective_until >= effective_from)
);

CREATE TABLE schedule_block (
  block_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL,
  doctor_id uuid NOT NULL,
  start_at timestamptz NOT NULL,
  end_at timestamptz NOT NULL,
  reason_code text NOT NULL CHECK (length(btrim(reason_code)) > 0),
  created_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  -- CASCADE removes one-off schedule blocks when a doctor is removed.
  CONSTRAINT schedule_block_doctor_fk FOREIGN KEY (clinic_id, doctor_id)
    REFERENCES doctor(clinic_id, doctor_id) ON DELETE CASCADE,
  -- RESTRICT keeps staff attribution until the block is explicitly handled.
  CONSTRAINT schedule_block_creator_fk FOREIGN KEY (clinic_id, created_by)
    REFERENCES app_user(clinic_id, user_id) ON DELETE RESTRICT,
  CHECK (end_at > start_at)
);

CREATE TABLE slot (
  slot_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL,
  doctor_id uuid NOT NULL,
  schedule_id uuid,
  title text NOT NULL DEFAULT 'Appointment slot' CHECK (length(btrim(title)) > 0),
  start_at timestamptz NOT NULL,
  end_at timestamptz NOT NULL,
  is_blocked boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (clinic_id, slot_id),
  UNIQUE (doctor_id, start_at),
  -- RESTRICT preserves concrete slot history while visits refer to it.
  CONSTRAINT slot_doctor_fk FOREIGN KEY (clinic_id, doctor_id)
    REFERENCES doctor(clinic_id, doctor_id) ON DELETE RESTRICT,
  -- RESTRICT prevents removing a recurring template while its generated slots remain.
  CONSTRAINT slot_schedule_fk FOREIGN KEY (clinic_id, schedule_id)
    REFERENCES doctor_schedule(clinic_id, schedule_id) ON DELETE RESTRICT,
  CHECK (end_at > start_at)
);

-- DOWN
DROP TABLE IF EXISTS slot;
DROP TABLE IF EXISTS schedule_block;
DROP TABLE IF EXISTS doctor_schedule;
DROP TABLE IF EXISTS doctor;
