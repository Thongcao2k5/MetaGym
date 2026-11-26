BEGIN;

ALTER TABLE member_self_training_days
  DROP CONSTRAINT IF EXISTS uq_member_self_training_day;

CREATE INDEX IF NOT EXISTS ix_member_self_training_days_member_date_time
  ON member_self_training_days (member_id, plan_date, start_time);

COMMIT;
