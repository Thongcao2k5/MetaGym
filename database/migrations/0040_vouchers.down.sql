BEGIN;

ALTER TABLE payments
  DROP COLUMN IF EXISTS discount_amount,
  DROP COLUMN IF EXISTS original_amount,
  DROP COLUMN IF EXISTS voucher_code_snapshot,
  DROP COLUMN IF EXISTS voucher_id;

DROP TABLE IF EXISTS voucher_redemptions;
DROP TRIGGER IF EXISTS trg_vouchers_updated_at ON vouchers;
DROP TABLE IF EXISTS vouchers;

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
    'BANNER',
    'SLIDE',
    'PROGRESS_PHOTO',
    'MEAL_PHOTO',
    'MESSAGE'
  ));

COMMIT;
