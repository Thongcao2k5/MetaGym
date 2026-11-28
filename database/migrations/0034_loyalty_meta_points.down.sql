BEGIN;

ALTER TABLE payments
  DROP COLUMN IF EXISTS loyalty_discount_amount,
  DROP COLUMN IF EXISTS loyalty_redemption_id;

DROP TRIGGER IF EXISTS trg_loyalty_rewards_updated_at ON loyalty_rewards;
DROP TRIGGER IF EXISTS trg_loyalty_accounts_updated_at ON loyalty_accounts;

DROP TABLE IF EXISTS loyalty_point_transactions;
DROP TABLE IF EXISTS loyalty_redemptions;
DROP TABLE IF EXISTS loyalty_rewards;
DROP TABLE IF EXISTS loyalty_accounts;

COMMIT;
