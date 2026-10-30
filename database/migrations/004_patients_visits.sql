-- UP
CREATE TABLE patient (
  patient_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL,
  full_name text NOT NULL CHECK (length(btrim(full_name)) > 0),
  phone text,
  is_minor boolean NOT NULL DEFAULT false,
  contact_person_name text,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (clinic_id, patient_id),
  -- RESTRICT preserves visits and requires an approved retention process before patient removal.
  CONSTRAINT patient_clinic_fk FOREIGN KEY (clinic_id)
    REFERENCES clinic(clinic_id) ON DELETE RESTRICT,
  CHECK (phone IS NULL OR phone ~ '^\+[1-9][0-9]{7,14}$'),
  CHECK (NOT is_minor OR (contact_person_name IS NOT NULL AND length(btrim(contact_person_name)) > 0))
);

CREATE TABLE visit (
  visit_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL,
  patient_id uuid NOT NULL,
  doctor_id uuid NOT NULL,
  slot_id uuid,
  type text NOT NULL CHECK (type IN ('appointment', 'walk-in')),
  status text NOT NULL CHECK (status IN (
    'Booked', 'Waiting', 'Called', 'In Consultation', 'Completed', 'Cancelled', 'No-Show'
  )),
  booking_ref text NOT NULL
    CHECK (booking_ref ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{10,}$'),
  status_token text UNIQUE,
  status_token_expires_at timestamptz,
  booked_by uuid,
  cancel_reason_code text CHECK (cancel_reason_code IN (
    'PATIENT_REQUEST', 'STAFF_REQUEST', 'DOCTOR_UNAVAILABLE', 'LEFT_BEFORE_SEEN',
    'DUPLICATE_ENTRY', 'DAY_CLOSED', 'OTHER'
  )),
  cancel_reason_text text,
  visit_date date NOT NULL,
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (clinic_id, visit_id),
  CONSTRAINT visit_booking_ref_uq UNIQUE (booking_ref),
  -- RESTRICT preserves a patient's visit history until approved retention or anonymization.
  CONSTRAINT visit_patient_fk FOREIGN KEY (clinic_id, patient_id)
    REFERENCES patient(clinic_id, patient_id) ON DELETE RESTRICT,
  -- RESTRICT preserves doctor attribution for historical visits.
  CONSTRAINT visit_doctor_fk FOREIGN KEY (clinic_id, doctor_id)
    REFERENCES doctor(clinic_id, doctor_id) ON DELETE RESTRICT,
  -- RESTRICT prevents deleting a slot with visit history.
  CONSTRAINT visit_slot_fk FOREIGN KEY (clinic_id, slot_id)
    REFERENCES slot(clinic_id, slot_id) ON DELETE RESTRICT,
  -- SET NULL retains public-booking visits if the staff account is removed.
  CONSTRAINT visit_booker_fk FOREIGN KEY (clinic_id, booked_by)
    REFERENCES app_user(clinic_id, user_id) ON DELETE SET NULL (booked_by),
  CHECK ((type = 'appointment' AND slot_id IS NOT NULL) OR (type = 'walk-in' AND slot_id IS NULL)),
  CHECK (cancel_reason_text IS NULL OR length(btrim(cancel_reason_text)) BETWEEN 1 AND 200),
  CHECK (status <> 'Cancelled' OR cancel_reason_code IS NOT NULL OR cancel_reason_text IS NOT NULL),
  CHECK (status_token IS NOT NULL OR status_token_expires_at IS NULL)
);

CREATE FUNCTION stamp_visit_server_time() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := clock_timestamp();
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NEW.status IN ('Completed', 'Cancelled', 'No-Show') THEN
      NEW.status_token_expires_at := clock_timestamp() + interval '24 hours';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER visit_server_status_time BEFORE UPDATE ON visit
FOR EACH ROW EXECUTE FUNCTION stamp_visit_server_time();

-- DOWN
DROP TRIGGER IF EXISTS visit_server_status_time ON visit;
DROP FUNCTION IF EXISTS stamp_visit_server_time();
DROP TABLE IF EXISTS visit;
DROP TABLE IF EXISTS patient;
