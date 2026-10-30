-- UP
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE clinic (
  clinic_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (length(btrim(name)) > 0),
  address text,
  phone text,
  timezone text NOT NULL DEFAULT 'Africa/Addis_Ababa',
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE clinic_setting (
  clinic_id uuid NOT NULL,
  key text NOT NULL CHECK (key IN (
    'queue_timing', 'booking_policy', 'consultation_policy', 'authentication_policy',
    'refresh_intervals', 'enabled_languages', 'emergency_contact_numbers',
    'application_mode', 'backup_policy', 'rate_limit_policy',
    'retention.visits_days', 'retention.patients_days', 'retention.activity_log_days'
  )),
  value jsonb,
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_by uuid,
  PRIMARY KEY (clinic_id, key),
  -- RESTRICT protects clinic configuration from accidental clinic deletion.
  CONSTRAINT clinic_setting_clinic_fk FOREIGN KEY (clinic_id)
    REFERENCES clinic(clinic_id) ON DELETE RESTRICT,
  CHECK (
    key <> 'queue_timing' OR value IS NULL OR
    ((value->>'grace_window_minutes')::integer < (value->>'no_show_deadline_minutes')::integer)
  ),
  CHECK (key <> 'application_mode' OR value IS NULL OR value->>'mode' IN ('demo', 'pilot')),
  CHECK (key NOT LIKE 'retention.%' OR value IS NULL OR
    (jsonb_typeof(value)='number' AND (value #>> '{}')::integer > 0))
);

CREATE FUNCTION enforce_pilot_retention_settings() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  mode_value text;
  configured_count integer;
BEGIN
  SELECT value->>'mode' INTO mode_value
  FROM clinic_setting WHERE clinic_id = NEW.clinic_id AND key = 'application_mode';
  IF NEW.key = 'application_mode' THEN
    mode_value := NEW.value->>'mode';
  END IF;
  IF mode_value = 'pilot' THEN
    SELECT count(*) INTO configured_count FROM clinic_setting
    WHERE clinic_id = NEW.clinic_id
      AND key IN ('retention.visits_days', 'retention.patients_days', 'retention.activity_log_days')
      AND value IS NOT NULL;
    IF NEW.key IN ('retention.visits_days', 'retention.patients_days', 'retention.activity_log_days')
       AND NEW.value IS NOT NULL AND NOT EXISTS (
         SELECT 1 FROM clinic_setting s WHERE s.clinic_id = NEW.clinic_id
           AND s.key IN ('retention.visits_days', 'retention.patients_days', 'retention.activity_log_days')
           AND s.key <> NEW.key AND s.value IS NOT NULL
       ) THEN
      configured_count := configured_count + 1;
    END IF;
    IF configured_count <> 3 THEN
      RAISE EXCEPTION 'pilot mode requires visits, patients, and activity_log retention values' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END $$;

CREATE CONSTRAINT TRIGGER clinic_setting_pilot_retention_ck
AFTER INSERT OR UPDATE ON clinic_setting DEFERRABLE INITIALLY IMMEDIATE
FOR EACH ROW EXECUTE FUNCTION enforce_pilot_retention_settings();

CREATE FUNCTION prevent_clinic_setting_delete() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'clinic settings are updated in place; delete is not permitted' USING ERRCODE = '55000';
END $$;
CREATE TRIGGER clinic_setting_no_delete BEFORE DELETE ON clinic_setting
FOR EACH ROW EXECUTE FUNCTION prevent_clinic_setting_delete();

-- DOWN
DROP TRIGGER IF EXISTS clinic_setting_no_delete ON clinic_setting;
DROP FUNCTION IF EXISTS prevent_clinic_setting_delete();
DROP TRIGGER IF EXISTS clinic_setting_pilot_retention_ck ON clinic_setting;
DROP FUNCTION IF EXISTS enforce_pilot_retention_settings();
DROP TABLE IF EXISTS clinic_setting;
DROP TABLE IF EXISTS clinic;
DROP EXTENSION IF EXISTS pgcrypto;
