BEGIN;

ALTER TABLE training_plan_days ADD COLUMN scheduled_date date;

CREATE UNIQUE INDEX uq_training_plan_scheduled_date
  ON training_plan_days (plan_id, scheduled_date)
  WHERE scheduled_date IS NOT NULL;

CREATE TABLE training_plan_day_meals (
  id uuid PRIMARY KEY,
  plan_day_id uuid NOT NULL REFERENCES training_plan_days(id),
  display_order smallint NOT NULL CHECK (display_order > 0),
  meal_type varchar(20) NOT NULL
    CHECK (meal_type IN ('BREAKFAST', 'LUNCH', 'DINNER', 'SNACK', 'OTHER')),
  scheduled_time time,
  title varchar(120) NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_training_plan_day_meal_order UNIQUE (plan_day_id, display_order)
);

CREATE TRIGGER trg_training_plan_day_meals_updated_at
  BEFORE UPDATE ON training_plan_day_meals
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
