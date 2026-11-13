BEGIN;

CREATE TABLE coach_weekly_slots (
  id uuid PRIMARY KEY,
  coach_id uuid NOT NULL REFERENCES users(id),
  weekday smallint NOT NULL CHECK (weekday BETWEEN 1 AND 7),
  start_minute smallint NOT NULL CHECK (start_minute BETWEEN 0 AND 1350),
  end_minute smallint GENERATED ALWAYS AS (start_minute + 90) STORED,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_coach_weekly_slot UNIQUE (coach_id, weekday, start_minute),
  CONSTRAINT ex_coach_weekly_slot_overlap EXCLUDE USING gist (
    coach_id WITH =, weekday WITH =,
    int4range(start_minute::integer, start_minute::integer + 90, '[)') WITH &&
  )
);

CREATE INDEX ix_coach_weekly_slots_day
  ON coach_weekly_slots (coach_id, weekday, start_minute);

COMMIT;
