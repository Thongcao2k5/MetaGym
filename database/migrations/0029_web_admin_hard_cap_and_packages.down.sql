BEGIN;

-- 4. Revert coach_entitlements
ALTER TABLE coach_entitlements
  DROP CONSTRAINT ck_coach_entitlement_origin;

DROP INDEX uq_coach_entitlement_origin_hold;

ALTER TABLE coach_entitlements
  ALTER COLUMN hold_id SET NOT NULL,
  ADD CONSTRAINT coach_entitlements_hold_id_key UNIQUE (hold_id),
  DROP COLUMN close_reason,
  DROP COLUMN source_entitlement_id,
  DROP COLUMN original_hold_id,
  DROP COLUMN snapshot_price,
  DROP COLUMN plan_name,
  DROP COLUMN plan_code;

-- 3. Revert coach_payment_holds
ALTER TABLE coach_payment_holds
  DROP COLUMN settled_at,
  ALTER COLUMN plan_name TYPE varchar(50),
  ALTER COLUMN plan_code TYPE varchar(20);

-- 2. Revert coach_package_plans
ALTER TABLE coach_package_plans
  DROP COLUMN created_by,
  DROP COLUMN created_at,
  DROP COLUMN description,
  DROP CONSTRAINT ck_coach_package_code_format;

ALTER TABLE coach_package_plans
  ALTER COLUMN name TYPE varchar(50),
  ALTER COLUMN code TYPE varchar(20);

ALTER TABLE coach_package_plans
  ADD CONSTRAINT coach_package_plans_code_check
    CHECK (code IN ('BASIC', 'STANDARD', 'ADVANCED')),
  ADD CONSTRAINT ck_coach_package_fixed_terms CHECK (
    (code = 'BASIC' AND session_count = 10 AND duration_days = 30) OR
    (code = 'STANDARD' AND session_count = 20 AND duration_days = 60) OR
    (code = 'ADVANCED' AND session_count = 30 AND duration_days = 90)
  );

-- 1. Revert coach_profiles
ALTER TABLE coach_profiles
  DROP CONSTRAINT ck_coach_profiles_member_limit_fixed,
  ALTER COLUMN member_limit DROP DEFAULT,
  ADD CONSTRAINT coach_profiles_member_limit_check CHECK (member_limit > 0);

COMMIT;
