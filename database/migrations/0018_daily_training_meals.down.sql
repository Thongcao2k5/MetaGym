BEGIN;

DROP TABLE training_plan_day_meals;
DROP INDEX uq_training_plan_scheduled_date;
ALTER TABLE training_plan_days DROP COLUMN scheduled_date;

COMMIT;
