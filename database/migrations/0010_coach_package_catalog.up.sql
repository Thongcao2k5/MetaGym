BEGIN;

CREATE TABLE coach_package_plans (
  code varchar(20) PRIMARY KEY CHECK (code IN ('BASIC', 'STANDARD', 'ADVANCED')),
  name varchar(50) NOT NULL,
  session_count integer NOT NULL CHECK (session_count > 0),
  duration_days integer NOT NULL CHECK (duration_days > 0),
  price bigint NOT NULL DEFAULT 0 CHECK (price >= 0),
  status varchar(20) NOT NULL DEFAULT 'INACTIVE'
    CHECK (status IN ('ACTIVE', 'INACTIVE')),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_coach_package_fixed_terms CHECK (
    (code = 'BASIC' AND session_count = 10 AND duration_days = 30) OR
    (code = 'STANDARD' AND session_count = 20 AND duration_days = 60) OR
    (code = 'ADVANCED' AND session_count = 30 AND duration_days = 90)
  )
);

INSERT INTO coach_package_plans (code, name, session_count, duration_days)
VALUES ('BASIC', 'Cơ bản', 10, 30),
       ('STANDARD', 'Tiêu chuẩn', 20, 60),
       ('ADVANCED', 'Nâng cao', 30, 90);

CREATE TRIGGER trg_coach_package_plans_updated_at
  BEFORE UPDATE ON coach_package_plans
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
