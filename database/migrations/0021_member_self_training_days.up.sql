BEGIN;

CREATE TABLE member_self_training_days (
  id uuid PRIMARY KEY,
  member_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_date date NOT NULL,
  title varchar(120) NOT NULL,
  start_time time,
  notes varchar(2000),
  exercises jsonb NOT NULL DEFAULT '[]'::jsonb
    CHECK (jsonb_typeof(exercises) = 'array' AND jsonb_array_length(exercises) <= 20),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_member_self_training_day UNIQUE (member_id, plan_date)
);

CREATE INDEX ix_member_self_training_days_member_date
  ON member_self_training_days (member_id, plan_date DESC);

COMMIT;
