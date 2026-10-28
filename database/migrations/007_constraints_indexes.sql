-- A slot is released when its appointment is Cancelled and may then be rebooked.
CREATE UNIQUE INDEX visit_one_active_appointment_per_slot_uq
  ON visit(slot_id) WHERE slot_id IS NOT NULL AND visit_type = 'Appointment' AND status <> 'Cancelled';
-- A doctor can have at most one active call and one active consultation at a time.
CREATE UNIQUE INDEX visit_one_called_per_doctor_uq ON visit(clinic_id, doctor_id) WHERE status = 'Called';
CREATE UNIQUE INDEX visit_one_consultation_per_doctor_uq ON visit(clinic_id, doctor_id) WHERE status = 'In Consultation';

CREATE FUNCTION validate_slot_schedule() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.schedule_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM doctor_schedule s WHERE s.clinic_id = NEW.clinic_id AND s.id = NEW.schedule_id AND s.doctor_id = NEW.doctor_id
  ) THEN RAISE EXCEPTION 'slot schedule must belong to its clinic and doctor' USING ERRCODE = '23514'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER slot_schedule_consistency BEFORE INSERT OR UPDATE OF clinic_id, doctor_id, schedule_id ON slot
FOR EACH ROW EXECUTE FUNCTION validate_slot_schedule();

CREATE FUNCTION validate_visit_slot() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.slot_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM slot s WHERE s.clinic_id = NEW.clinic_id AND s.id = NEW.slot_id AND s.doctor_id = NEW.doctor_id
      AND (s.starts_at AT TIME ZONE 'Africa/Addis_Ababa')::date = NEW.visit_date
  ) THEN RAISE EXCEPTION 'visit slot must belong to its clinic and doctor and fall on its visit date' USING ERRCODE = '23514'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER visit_slot_consistency BEFORE INSERT OR UPDATE OF clinic_id, doctor_id, slot_id, visit_date ON visit
FOR EACH ROW EXECUTE FUNCTION validate_visit_slot();
CREATE FUNCTION require_visit_version_increment() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.version <> OLD.version + 1 THEN
    RAISE EXCEPTION 'every visit update must increment version exactly once' USING ERRCODE = '40001';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER visit_version_increment BEFORE UPDATE ON visit
FOR EACH ROW EXECUTE FUNCTION require_visit_version_increment();

CREATE FUNCTION protect_doctor_day_counters() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.next_queue_no < OLD.next_queue_no OR NEW.next_sequence_no < OLD.next_sequence_no THEN
    RAISE EXCEPTION 'doctor-day queue counters cannot move backwards' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER doctor_day_queue_counters_monotonic BEFORE UPDATE OF next_queue_no, next_sequence_no ON doctor_day_queue
FOR EACH ROW EXECUTE FUNCTION protect_doctor_day_counters();

CREATE FUNCTION validate_queue_entry_visit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM visit v WHERE v.clinic_id = NEW.clinic_id AND v.id = NEW.visit_id
      AND v.doctor_id = NEW.doctor_id AND v.visit_date = NEW.queue_date AND v.status NOT IN ('Booked','Cancelled'))
  THEN RAISE EXCEPTION 'queue entry must match its visit clinic, doctor, and day' USING ERRCODE = '23514'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER queue_entry_visit_consistency BEFORE INSERT OR UPDATE OF clinic_id, visit_id, doctor_id, queue_date ON queue_entry
FOR EACH ROW EXECUTE FUNCTION validate_queue_entry_visit();
CREATE FUNCTION protect_queue_identity() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'queue entries are historical records and cannot be deleted' USING ERRCODE = '55000'; END IF;
  IF (NEW.clinic_id, NEW.visit_id, NEW.doctor_id, NEW.queue_date, NEW.queue_no, NEW.sequence_no)
     IS DISTINCT FROM (OLD.clinic_id, OLD.visit_id, OLD.doctor_id, OLD.queue_date, OLD.queue_no, OLD.sequence_no)
  THEN RAISE EXCEPTION 'queue identity and assigned numbers are immutable' USING ERRCODE = '55000'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER queue_entry_identity_immutable BEFORE UPDATE OR DELETE ON queue_entry
FOR EACH ROW EXECUTE FUNCTION protect_queue_identity();

-- The application role can add activity rows but cannot rewrite history.
CREATE FUNCTION reject_history_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'visit and activity history is append-only' USING ERRCODE = '55000'; END $$;
CREATE TRIGGER activity_log_immutable BEFORE UPDATE OR DELETE ON activity_log
FOR EACH ROW EXECUTE FUNCTION reject_history_mutation();
CREATE TRIGGER visit_event_immutable BEFORE UPDATE OR DELETE ON visit_event
FOR EACH ROW EXECUTE FUNCTION reject_history_mutation();

CREATE INDEX doctor_schedule_lookup_idx ON doctor_schedule(clinic_id, doctor_id, weekday) WHERE is_active;
CREATE INDEX patient_phone_lookup_idx ON patient(clinic_id, normalized_phone) WHERE normalized_phone IS NOT NULL;
CREATE INDEX visit_active_patient_future_idx ON visit(clinic_id, patient_id, visit_date) WHERE status IN ('Booked','Waiting','Called','In Consultation');
