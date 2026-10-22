BEGIN;

CREATE TABLE auth_login_rate_limits (
  key_hash text PRIMARY KEY CHECK (key_hash ~ '^[0-9a-f]{64}$'),
  scope text NOT NULL CHECK (scope IN ('ACCOUNT', 'IP')),
  failure_count integer NOT NULL DEFAULT 0 CHECK (failure_count >= 0),
  window_started_at timestamptz NOT NULL DEFAULT now(),
  blocked_until timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_auth_login_rate_limit_block CHECK (
    blocked_until IS NULL OR blocked_until >= window_started_at
  )
);

CREATE INDEX ix_auth_login_rate_limits_cleanup
  ON auth_login_rate_limits (updated_at);

COMMIT;
