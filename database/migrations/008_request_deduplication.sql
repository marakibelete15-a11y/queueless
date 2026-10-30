-- UP
-- Supporting table for Phase 3 request idempotency; no API behavior is implemented here.
CREATE TABLE request_deduplication (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), clinic_id uuid NOT NULL,
  operation_scope text NOT NULL, request_key text NOT NULL CHECK (length(request_key) BETWEEN 16 AND 200),
  payload_sha256 char(64) NOT NULL CHECK (payload_sha256 ~ '^[0-9a-f]{64}$'),
  response_status smallint CHECK (response_status BETWEEN 100 AND 599), response_body jsonb,
  created_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL,
  UNIQUE (clinic_id, operation_scope, request_key),
  -- RESTRICT preserves idempotency receipts with their clinic's request history.
  CONSTRAINT request_deduplication_clinic_fk FOREIGN KEY (clinic_id) REFERENCES clinic(clinic_id) ON DELETE RESTRICT,
  CHECK (expires_at > created_at),
  CHECK ((response_status IS NULL) = (response_body IS NULL))
);
CREATE INDEX request_deduplication_expiry_idx ON request_deduplication(expires_at);

-- DOWN
DROP TABLE IF EXISTS request_deduplication;
