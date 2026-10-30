-- UP
CREATE TABLE app_user (
  user_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL,
  username text NOT NULL CHECK (length(btrim(username)) > 0),
  email text,
  display_name text NOT NULL CHECK (length(btrim(display_name)) > 0),
  password_hash text NOT NULL CHECK (length(password_hash) >= 20),
  role text NOT NULL CHECK (role IN ('receptionist', 'doctor', 'administrator')),
  is_active boolean NOT NULL DEFAULT true,
  failed_count integer NOT NULL DEFAULT 0 CHECK (failed_count >= 0),
  locked_until timestamptz,
  must_change_password boolean NOT NULL DEFAULT false,
  temp_password_expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (clinic_id, user_id),
  -- RESTRICT retains user identity referenced by operational records.
  CONSTRAINT app_user_clinic_fk FOREIGN KEY (clinic_id)
    REFERENCES clinic(clinic_id) ON DELETE RESTRICT,
  CHECK (email IS NULL OR length(btrim(email)) > 0),
  CHECK (temp_password_expires_at IS NULL OR must_change_password)
);
CREATE UNIQUE INDEX app_user_username_per_clinic_uq ON app_user (clinic_id, lower(username));
CREATE UNIQUE INDEX app_user_email_per_clinic_uq ON app_user (clinic_id, lower(email)) WHERE email IS NOT NULL;

CREATE TABLE session (
  session_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL,
  user_id uuid NOT NULL,
  token_hash bytea NOT NULL UNIQUE CHECK (octet_length(token_hash) = 32),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  last_seen_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  expires_at timestamptz NOT NULL,
  absolute_expires_at timestamptz NOT NULL,
  -- CASCADE removes server-side sessions when their user is removed.
  CONSTRAINT session_user_fk FOREIGN KEY (clinic_id, user_id)
    REFERENCES app_user(clinic_id, user_id) ON DELETE CASCADE,
  CHECK (expires_at > created_at),
  CHECK (absolute_expires_at >= expires_at)
);

-- Index supports expired/idle session cleanup and user's active-session lookup.
CREATE INDEX session_cleanup_idx ON session (expires_at);
CREATE INDEX session_user_active_idx ON session (clinic_id, user_id, expires_at);

-- DOWN
DROP TABLE IF EXISTS session;
DROP TABLE IF EXISTS app_user;
