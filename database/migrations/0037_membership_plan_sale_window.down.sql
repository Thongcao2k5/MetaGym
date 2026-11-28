BEGIN;

DROP INDEX IF EXISTS ix_membership_plans_sale_window;

ALTER TABLE membership_plans
  DROP CONSTRAINT IF EXISTS ck_membership_plans_sale_window,
  DROP COLUMN IF EXISTS sales_end_at,
  DROP COLUMN IF EXISTS sales_start_at;

COMMIT;
