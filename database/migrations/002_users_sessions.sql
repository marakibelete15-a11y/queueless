CREATE TABLE app_user (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), clinic_id uuid NOT NULL REFERENCES clinic(id) ON DELETE RESTRICT,
  username text NOT NULL, password_hash text NOT NULL, role text NOT NULL CHECK (role IN ('Receptionist','Doctor','Administrator')),
  failed_login_attempts integer NOT NULL DEFAULT 0 CHECK (failed_login_attempts >= 0), locked_until timestamptz,
  must_change_password boolean NOT NULL DEFAULT false, temporary_password_expires_at timestamptz,
  is_active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (clinic_id, id), UNIQUE (clinic_id, username),
  CHECK (temporary_password_expires_at IS NULL OR must_change_password)
);

CREATE TABLE user_session (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), clinic_id uuid NOT NULL, user_id uuid NOT NULL,
  token_hash text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), last_activity_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL, absolute_expires_at timestamptz NOT NULL, invalidated_at timestamptz,
  invalidation_reason text, UNIQUE (clinic_id, id), UNIQUE (token_hash),
  FOREIGN KEY (clinic_id, user_id) REFERENCES app_user(clinic_id, id) ON DELETE RESTRICT,
  CHECK (expires_at > created_at), CHECK (absolute_expires_at >= expires_at),
  CHECK (invalidated_at IS NULL OR invalidated_at >= created_at)
);
CREATE INDEX user_session_user_active_idx ON user_session(clinic_id, user_id, expires_at) WHERE invalidated_at IS NULL;
