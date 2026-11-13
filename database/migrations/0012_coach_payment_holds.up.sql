BEGIN;

CREATE TABLE coach_payment_holds (
  id uuid PRIMARY KEY,
  member_id uuid NOT NULL REFERENCES users(id),
  coach_id uuid NOT NULL REFERENCES users(id),
  plan_code varchar(20) NOT NULL REFERENCES coach_package_plans(code),
  plan_name varchar(50) NOT NULL,
  session_count integer NOT NULL CHECK (session_count > 0),
  duration_days integer NOT NULL CHECK (duration_days > 0),
  amount bigint NOT NULL CHECK (amount >= 0),
  request_key uuid NOT NULL,
  status varchar(20) NOT NULL DEFAULT 'HELD'
    CHECK (status IN ('HELD', 'CANCELLED', 'EXPIRED')),
  created_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  CONSTRAINT uq_coach_hold_request UNIQUE (member_id, request_key),
  CHECK (member_id <> coach_id),
  CHECK (expires_at = created_at + interval '15 minutes')
);

CREATE UNIQUE INDEX uq_coach_hold_open_member ON coach_payment_holds (member_id)
  WHERE status = 'HELD';
CREATE INDEX ix_coach_hold_expiry ON coach_payment_holds (coach_id, expires_at)
  WHERE status = 'HELD';

CREATE FUNCTION coach_occupied_seats(target_coach uuid) RETURNS integer
LANGUAGE sql STABLE AS $$
  SELECT (
    (SELECT count(*) FROM coach_relationships
     WHERE coach_id = target_coach AND status IN ('ACTIVE', 'PAUSED')) +
    (SELECT count(*) FROM coach_payment_holds
     WHERE coach_id = target_coach AND status = 'HELD'
       AND expires_at > statement_timestamp())
  )::integer;
$$;

COMMIT;
