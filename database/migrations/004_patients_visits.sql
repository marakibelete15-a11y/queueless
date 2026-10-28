CREATE TABLE patient (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), clinic_id uuid NOT NULL, display_name text NOT NULL CHECK (length(trim(display_name)) > 0),
  normalized_phone text, secondary_phone text, preferred_contact_method text CHECK (preferred_contact_method IN ('SMS','Call','WhatsApp') OR preferred_contact_method IS NULL),
  is_minor boolean NOT NULL DEFAULT false, guardian_name text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (clinic_id, id), FOREIGN KEY (clinic_id) REFERENCES clinic(id) ON DELETE RESTRICT,
  CHECK (NOT is_minor OR guardian_name IS NOT NULL), CHECK (normalized_phone IS NULL OR length(trim(normalized_phone)) > 0)
);

CREATE TABLE visit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), clinic_id uuid NOT NULL, patient_id uuid NOT NULL, doctor_id uuid NOT NULL,
  slot_id uuid, booking_ref text NOT NULL UNIQUE CHECK (length(booking_ref) >= 10),
  visit_type text NOT NULL CHECK (visit_type IN ('Appointment','Walk-in')),
  status text NOT NULL CHECK (status IN ('Booked','Waiting','Called','In Consultation','Completed','Cancelled','No-Show')),
  cancellation_reason_code text, administrative_reason text, visit_date date NOT NULL,
  version integer NOT NULL DEFAULT 1 CHECK (version > 0), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (clinic_id, id), FOREIGN KEY (clinic_id, patient_id) REFERENCES patient(clinic_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (clinic_id, doctor_id) REFERENCES doctor(clinic_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (clinic_id, slot_id) REFERENCES slot(clinic_id, id) ON DELETE RESTRICT,
  CHECK ((visit_type = 'Appointment' AND slot_id IS NOT NULL) OR (visit_type = 'Walk-in' AND slot_id IS NULL)),
  CHECK (status <> 'Cancelled' OR cancellation_reason_code IS NOT NULL OR administrative_reason IS NOT NULL),
  CHECK (administrative_reason IS NULL OR length(trim(administrative_reason)) > 0)
);
CREATE INDEX visit_patient_history_idx ON visit(clinic_id, patient_id, visit_date DESC);
CREATE INDEX visit_doctor_day_idx ON visit(clinic_id, doctor_id, visit_date, status);
