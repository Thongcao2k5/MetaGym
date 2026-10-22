BEGIN;

CREATE TABLE auth_password_reset_rate_limits (
  key_hash text PRIMARY KEY CHECK (key_hash ~ '^[0-9a-f]{64}$'),
  scope text NOT NULL CHECK (scope IN ('ACCOUNT', 'IP')),
  request_count integer NOT NULL DEFAULT 0 CHECK (request_count >= 0),
  window_started_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_password_reset_rate_limits_cleanup
  ON auth_password_reset_rate_limits (updated_at);

COMMIT;
