BEGIN;

-- 1. Simulated refunds for COACH_LOCKED incidents (D2 + D3)
CREATE TABLE simulated_refunds (
  id uuid PRIMARY KEY,
  refund_batch_id uuid NOT NULL,
  incident_id uuid NOT NULL REFERENCES coach_lock_incidents(id),
  coach_entitlement_id uuid NOT NULL UNIQUE REFERENCES coach_entitlements(id),
  relationship_id uuid NOT NULL REFERENCES coach_relationships(id),
  member_id uuid NOT NULL REFERENCES users(id),
  coach_id uuid NOT NULL REFERENCES users(id),
  entitlement_kind varchar(10) NOT NULL CHECK (entitlement_kind IN ('ACTIVE', 'QUEUED')),
  snapshot_price bigint NOT NULL CHECK (snapshot_price >= 0),
  total_sessions integer NOT NULL CHECK (total_sessions > 0),
  remaining_sessions integer NOT NULL CHECK (remaining_sessions BETWEEN 0 AND total_sessions),
  refund_amount bigint NOT NULL CHECK (refund_amount >= 0 AND refund_amount <= snapshot_price),
  status varchar(20) NOT NULL DEFAULT 'COMPLETED' CHECK (status = 'COMPLETED'),
  reason text NOT NULL CHECK (btrim(reason) <> ''),
  idempotency_key varchar(100) NOT NULL,
  request_hash varchar(64) NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_simulated_refund_idempotency
    UNIQUE (created_by, idempotency_key, entitlement_kind),
  CONSTRAINT ck_simulated_refund_formula CHECK (
    (entitlement_kind = 'QUEUED'
      AND remaining_sessions = total_sessions
      AND refund_amount = snapshot_price)
    OR
    (entitlement_kind = 'ACTIVE'
      AND refund_amount = (div(div(snapshot_price::numeric * remaining_sessions, total_sessions), 1000) * 1000)::bigint)
  )
);

-- 2. Immutable VOID_REVERSAL adjustments for FRONT_DESK Gym payments (D6)
CREATE TABLE payment_adjustments (
  id uuid PRIMARY KEY,
  payment_id uuid NOT NULL UNIQUE REFERENCES payments(id),
  member_id uuid NOT NULL REFERENCES users(id),
  affected_membership_id uuid NOT NULL REFERENCES member_memberships(id),
  adjustment_type varchar(30) NOT NULL DEFAULT 'VOID_REVERSAL'
    CHECK (adjustment_type = 'VOID_REVERSAL'),
  reversed_amount bigint NOT NULL CHECK (reversed_amount >= 0),
  previous_membership_status varchar(20) NOT NULL,
  previous_end_date date NOT NULL,
  restored_end_date date,
  reason text NOT NULL CHECK (btrim(reason) <> ''),
  idempotency_key varchar(100) NOT NULL,
  request_hash varchar(64) NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_payment_adjustment_idempotency UNIQUE (created_by, idempotency_key)
);

COMMIT;
