BEGIN;

-- 1. Hard cap 8 Members per Coach (S4)
UPDATE coach_profiles
   SET member_limit = 8
 WHERE member_limit <> 8;

ALTER TABLE coach_profiles
  ALTER COLUMN member_limit SET DEFAULT 8,
  DROP CONSTRAINT coach_profiles_member_limit_check,
  ADD CONSTRAINT ck_coach_profiles_member_limit_fixed CHECK (member_limit = 8);

-- 2. Dynamic Coach package catalog (S3)
ALTER TABLE coach_package_plans
  DROP CONSTRAINT coach_package_plans_code_check,
  DROP CONSTRAINT ck_coach_package_fixed_terms;

ALTER TABLE coach_package_plans
  ALTER COLUMN code TYPE varchar(40),
  ALTER COLUMN name TYPE varchar(100);

ALTER TABLE coach_package_plans
  ADD CONSTRAINT ck_coach_package_code_format
    CHECK (code ~ '^[A-Z0-9][A-Z0-9_-]{1,39}$'),
  ADD COLUMN description text,
  ADD COLUMN created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN created_by uuid REFERENCES users(id);

-- 3. Coach payment holds: widen code/name and track settled_at
ALTER TABLE coach_payment_holds
  ALTER COLUMN plan_code TYPE varchar(40),
  ALTER COLUMN plan_name TYPE varchar(100),
  ADD COLUMN settled_at timestamptz;

UPDATE coach_payment_holds
   SET settled_at = created_at
 WHERE status = 'CONSUMED'
   AND settled_at IS NULL;

-- 4. Coach entitlements: snapshot fields, transfer lineage, close_reason
ALTER TABLE coach_entitlements
  ADD COLUMN plan_code varchar(40),
  ADD COLUMN plan_name varchar(100),
  ADD COLUMN snapshot_price bigint CHECK (snapshot_price >= 0),
  ADD COLUMN original_hold_id uuid REFERENCES coach_payment_holds(id),
  ADD COLUMN source_entitlement_id uuid REFERENCES coach_entitlements(id),
  ADD COLUMN close_reason varchar(30)
    CHECK (close_reason IN (
      'COMPLETED_SESSIONS',
      'EXPIRED',
      'EARLY_TERMINATION',
      'TRANSFERRED',
      'SIMULATED_REFUND'
    ));

UPDATE coach_entitlements e
   SET plan_code = h.plan_code,
       plan_name = h.plan_name,
       snapshot_price = h.amount,
       original_hold_id = h.id
  FROM coach_payment_holds h
 WHERE e.hold_id = h.id;

ALTER TABLE coach_entitlements
  DROP CONSTRAINT coach_entitlements_hold_id_key,
  ALTER COLUMN hold_id DROP NOT NULL;

CREATE UNIQUE INDEX uq_coach_entitlement_origin_hold
  ON coach_entitlements (hold_id)
  WHERE hold_id IS NOT NULL;

ALTER TABLE coach_entitlements
  ADD CONSTRAINT ck_coach_entitlement_origin
    CHECK ((source_entitlement_id IS NULL) = (hold_id IS NOT NULL));

COMMIT;
