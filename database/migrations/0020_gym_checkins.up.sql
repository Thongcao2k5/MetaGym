BEGIN;

-- One printable code for the single Meta Gym location. Admin can rotate it
-- when a printed copy is lost; old copies stop working immediately.
CREATE TABLE gym_checkin_code (
  id smallint PRIMARY KEY CHECK (id = 1),
  code uuid NOT NULL UNIQUE,
  updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO gym_checkin_code (id, code) VALUES (1, gen_random_uuid());

CREATE TABLE gym_visits (
  id uuid PRIMARY KEY,
  member_id uuid NOT NULL REFERENCES users(id),
  visit_day date NOT NULL,
  checked_in_at timestamptz NOT NULL DEFAULT now(),
  gym_name varchar(150) NOT NULL,
  gym_address text NOT NULL
);
CREATE INDEX ix_gym_visits_member_day ON gym_visits (member_id, visit_day DESC, checked_in_at DESC);

COMMIT;
