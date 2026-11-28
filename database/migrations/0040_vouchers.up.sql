BEGIN;

ALTER TABLE media_assets
  DROP CONSTRAINT IF EXISTS media_assets_purpose_check;

ALTER TABLE media_assets
  ADD CONSTRAINT media_assets_purpose_check
  CHECK (purpose IN (
    'AVATAR',
    'GYM',
    'EQUIPMENT',
    'EXERCISE',
    'COACH_OUTCOME',
    'PACKAGE',
    'SYSTEM_ICON',
    'VOUCHER',
    'BANNER',
    'SLIDE',
    'PROGRESS_PHOTO',
    'MEAL_PHOTO',
    'MESSAGE'
  ));

CREATE TABLE IF NOT EXISTS vouchers (
  id uuid PRIMARY KEY,
  code varchar(40) NOT NULL UNIQUE,
  title varchar(120) NOT NULL,
  description text,
  image_media_id uuid REFERENCES media_assets(id) ON DELETE SET NULL,
  discount_type varchar(20) NOT NULL
    CHECK (discount_type IN ('FIXED_AMOUNT', 'PERCENT')),
  discount_value bigint NOT NULL CHECK (discount_value > 0),
  max_discount_amount bigint CHECK (max_discount_amount IS NULL OR max_discount_amount > 0),
  apply_scope varchar(20) NOT NULL DEFAULT 'ALL'
    CHECK (apply_scope IN ('ALL', 'GYM_PLAN', 'COACH_PACKAGE')),
  target_plan_id uuid REFERENCES membership_plans(id) ON DELETE SET NULL,
  target_member_scope varchar(30) NOT NULL DEFAULT 'ALL'
    CHECK (target_member_scope IN ('ALL', 'NEW_MEMBER', 'RENEWAL')),
  min_order_amount bigint NOT NULL DEFAULT 0 CHECK (min_order_amount >= 0),
  max_total_uses integer CHECK (max_total_uses IS NULL OR max_total_uses > 0),
  max_uses_per_member integer NOT NULL DEFAULT 1 CHECK (max_uses_per_member > 0),
  used_count integer NOT NULL DEFAULT 0 CHECK (used_count >= 0),
  starts_at timestamptz,
  ends_at timestamptz,
  status varchar(20) NOT NULL DEFAULT 'ACTIVE'
    CHECK (status IN ('ACTIVE', 'PAUSED', 'ARCHIVED')),
  created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_vouchers_percent_bounds CHECK (
    discount_type <> 'PERCENT' OR (discount_value BETWEEN 1 AND 100)
  ),
  CONSTRAINT ck_vouchers_date_range CHECK (
    starts_at IS NULL OR ends_at IS NULL OR ends_at >= starts_at
  )
);

CREATE INDEX IF NOT EXISTS ix_vouchers_status_dates
  ON vouchers (status, starts_at, ends_at);

CREATE INDEX IF NOT EXISTS ix_vouchers_code_upper
  ON vouchers (upper(code));

DROP TRIGGER IF EXISTS trg_vouchers_updated_at ON vouchers;
CREATE TRIGGER trg_vouchers_updated_at
  BEFORE UPDATE ON vouchers
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS voucher_redemptions (
  id uuid PRIMARY KEY,
  voucher_id uuid NOT NULL REFERENCES vouchers(id) ON DELETE RESTRICT,
  voucher_code_snapshot varchar(40) NOT NULL,
  member_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  payment_id uuid REFERENCES payments(id) ON DELETE SET NULL,
  original_amount bigint NOT NULL CHECK (original_amount >= 0),
  discount_amount bigint NOT NULL CHECK (discount_amount >= 0),
  final_amount bigint NOT NULL CHECK (final_amount >= 0),
  status varchar(20) NOT NULL DEFAULT 'APPLIED'
    CHECK (status IN ('RESERVED', 'APPLIED', 'RELEASED')),
  created_at timestamptz NOT NULL DEFAULT now(),
  applied_at timestamptz
);

CREATE INDEX IF NOT EXISTS ix_voucher_redemptions_voucher_member
  ON voucher_redemptions (voucher_id, member_id)
  WHERE status <> 'RELEASED';

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS voucher_id uuid REFERENCES vouchers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS voucher_code_snapshot varchar(40),
  ADD COLUMN IF NOT EXISTS original_amount bigint CHECK (original_amount IS NULL OR original_amount >= 0),
  ADD COLUMN IF NOT EXISTS discount_amount bigint NOT NULL DEFAULT 0 CHECK (discount_amount >= 0);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON vouchers, voucher_redemptions FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    REVOKE ALL ON vouchers, voucher_redemptions FROM authenticated;
  END IF;
END
$$;

COMMIT;
