CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE clinic (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (length(trim(name)) > 0),
  timezone text NOT NULL DEFAULT 'Africa/Addis_Ababa',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id)
);

CREATE TABLE clinic_setting (
  clinic_id uuid PRIMARY KEY REFERENCES clinic(id) ON DELETE RESTRICT,
  grace_window_minutes integer NOT NULL DEFAULT 15 CHECK (grace_window_minutes >= 0),
  no_show_deadline_minutes integer NOT NULL DEFAULT 30 CHECK (no_show_deadline_minutes > 0),
  resume_grace_minutes integer NOT NULL DEFAULT 10 CHECK (resume_grace_minutes >= 0),
  staff_activity_guard_minutes integer NOT NULL DEFAULT 10 CHECK (staff_activity_guard_minutes > 0),
  call_timeout_minutes integer NOT NULL DEFAULT 5 CHECK (call_timeout_minutes > 0),
  patient_cancellation_cutoff_hours integer NOT NULL DEFAULT 2 CHECK (patient_cancellation_cutoff_hours >= 0),
  booking_window_days integer NOT NULL DEFAULT 14 CHECK (booking_window_days > 0),
  active_future_appointments_per_phone integer NOT NULL DEFAULT 3 CHECK (active_future_appointments_per_phone > 0),
  default_consultation_minutes integer NOT NULL DEFAULT 10 CHECK (default_consultation_minutes > 0),
  consultation_sample_size integer NOT NULL DEFAULT 20 CHECK (consultation_sample_size > 0),
  consultation_minimum_sample integer NOT NULL DEFAULT 5 CHECK (consultation_minimum_sample > 0 AND consultation_minimum_sample <= consultation_sample_size),
  login_failed_attempt_limit integer NOT NULL DEFAULT 5 CHECK (login_failed_attempt_limit > 0),
  login_lockout_minutes integer NOT NULL DEFAULT 15 CHECK (login_lockout_minutes > 0),
  session_idle_minutes integer NOT NULL DEFAULT 30 CHECK (session_idle_minutes > 0),
  session_absolute_hours integer NOT NULL DEFAULT 12 CHECK (session_absolute_hours > 0),
  temporary_password_hours integer NOT NULL DEFAULT 24 CHECK (temporary_password_hours > 0),
  public_refresh_seconds integer NOT NULL DEFAULT 15 CHECK (public_refresh_seconds > 0),
  staff_refresh_seconds integer NOT NULL DEFAULT 10 CHECK (staff_refresh_seconds > 0),
  day_end_sweep_enabled boolean NOT NULL DEFAULT true,
  day_end_sweep_local_time time NOT NULL DEFAULT '23:59',
  retention_visits_days integer CHECK (retention_visits_days > 0),
  retention_patients_days integer CHECK (retention_patients_days > 0),
  retention_sessions_days integer CHECK (retention_sessions_days > 0),
  retention_events_days integer CHECK (retention_events_days > 0),
  retention_activity_days integer CHECK (retention_activity_days > 0),
  retention_notices_days integer CHECK (retention_notices_days > 0),
  retention_rate_limits_days integer CHECK (retention_rate_limits_days > 0),
  retention_request_receipts_days integer CHECK (retention_request_receipts_days > 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (grace_window_minutes < no_show_deadline_minutes)
);
