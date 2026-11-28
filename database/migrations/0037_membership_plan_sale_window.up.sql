BEGIN;

ALTER TABLE membership_plans
  ADD COLUMN IF NOT EXISTS sales_start_at timestamptz,
  ADD COLUMN IF NOT EXISTS sales_end_at timestamptz,
  ADD CONSTRAINT ck_membership_plans_sale_window
    CHECK (sales_start_at IS NULL OR sales_end_at IS NULL OR sales_end_at >= sales_start_at);

CREATE INDEX IF NOT EXISTS ix_membership_plans_sale_window
  ON membership_plans (status, sales_start_at, sales_end_at);

COMMIT;
