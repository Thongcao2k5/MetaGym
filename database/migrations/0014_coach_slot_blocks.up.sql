BEGIN;
CREATE TABLE coach_slot_blocks (
  coach_id uuid NOT NULL REFERENCES users(id),
  starts_at timestamptz NOT NULL,
  reason text NOT NULL,
  PRIMARY KEY (coach_id, starts_at)
);
COMMIT;
