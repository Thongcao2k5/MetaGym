BEGIN;

CREATE TABLE training_plans (
  id uuid PRIMARY KEY,
  relationship_id uuid NOT NULL,
  member_id uuid NOT NULL REFERENCES users(id),
  coach_id uuid NOT NULL REFERENCES users(id),
  title varchar(150) NOT NULL,
  goal text,
  start_date date,
  end_date date,
  version integer NOT NULL CHECK (version > 0),
  status varchar(20) NOT NULL DEFAULT 'DRAFT'
    CHECK (status IN ('DRAFT', 'ACTIVE', 'ARCHIVED')),
  published_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_training_plan_relationship
    FOREIGN KEY (relationship_id, member_id, coach_id)
    REFERENCES coach_relationships(id, member_id, coach_id),
  CONSTRAINT uq_training_plan_member_version UNIQUE (member_id, version),
  CONSTRAINT uq_training_plan_owner UNIQUE (id, member_id),
  CONSTRAINT ck_training_plan_dates CHECK (
    end_date IS NULL OR start_date IS NULL OR end_date >= start_date
  ),
  CONSTRAINT ck_training_plan_state_details CHECK (
    (status = 'DRAFT' AND published_at IS NULL AND archived_at IS NULL)
    OR
    (status = 'ACTIVE' AND published_at IS NOT NULL AND archived_at IS NULL)
    OR
    (status = 'ARCHIVED' AND published_at IS NOT NULL AND archived_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX uq_training_plan_active_member
  ON training_plans (member_id)
  WHERE status = 'ACTIVE';

CREATE TABLE training_plan_days (
  id uuid PRIMARY KEY,
  plan_id uuid NOT NULL REFERENCES training_plans(id),
  day_number smallint NOT NULL CHECK (day_number > 0),
  title varchar(120) NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_training_plan_day UNIQUE (plan_id, day_number)
);

CREATE TABLE training_plan_exercises (
  id uuid PRIMARY KEY,
  plan_day_id uuid NOT NULL REFERENCES training_plan_days(id),
  exercise_id uuid NOT NULL REFERENCES exercises(id),
  exercise_name_snapshot varchar(120),
  instructions_snapshot text,
  safety_notes_snapshot text,
  display_order smallint NOT NULL CHECK (display_order > 0),
  sets smallint CHECK (sets > 0),
  reps varchar(50),
  duration_seconds integer CHECK (duration_seconds > 0),
  rest_seconds integer CHECK (rest_seconds >= 0),
  weight_guidance varchar(100),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_training_plan_exercise_order UNIQUE (plan_day_id, display_order),
  CONSTRAINT ck_training_plan_exercise_target CHECK (
    reps IS NOT NULL OR duration_seconds IS NOT NULL
  )
);

CREATE TABLE nutrition_guides (
  id uuid PRIMARY KEY,
  relationship_id uuid NOT NULL,
  member_id uuid NOT NULL REFERENCES users(id),
  coach_id uuid NOT NULL REFERENCES users(id),
  title varchar(150) NOT NULL,
  content text NOT NULL,
  version integer NOT NULL CHECK (version > 0),
  status varchar(20) NOT NULL DEFAULT 'DRAFT'
    CHECK (status IN ('DRAFT', 'ACTIVE', 'ARCHIVED')),
  published_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_nutrition_relationship
    FOREIGN KEY (relationship_id, member_id, coach_id)
    REFERENCES coach_relationships(id, member_id, coach_id),
  CONSTRAINT uq_nutrition_member_version UNIQUE (member_id, version),
  CONSTRAINT ck_nutrition_state_details CHECK (
    (status = 'DRAFT' AND published_at IS NULL AND archived_at IS NULL)
    OR
    (status = 'ACTIVE' AND published_at IS NOT NULL AND archived_at IS NULL)
    OR
    (status = 'ARCHIVED' AND published_at IS NOT NULL AND archived_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX uq_nutrition_active_member
  ON nutrition_guides (member_id)
  WHERE status = 'ACTIVE';

CREATE TABLE training_sessions (
  id uuid PRIMARY KEY,
  relationship_id uuid NOT NULL,
  member_id uuid NOT NULL REFERENCES users(id),
  title varchar(150) NOT NULL,
  scheduled_start_at timestamptz NOT NULL,
  scheduled_end_at timestamptz,
  status varchar(20) NOT NULL DEFAULT 'SCHEDULED'
    CHECK (status IN ('SCHEDULED', 'COMPLETED', 'MEMBER_ABSENT', 'CANCELLED')),
  notes text,
  cancellation_reason text,
  cancelled_at timestamptz,
  completed_at timestamptz,
  absent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_training_session_relationship_member
    FOREIGN KEY (relationship_id, member_id)
    REFERENCES coach_relationships(id, member_id),
  CONSTRAINT uq_training_session_member UNIQUE (id, member_id),
  CONSTRAINT ck_training_session_schedule CHECK (
    scheduled_end_at IS NULL OR scheduled_end_at > scheduled_start_at
  ),
  CONSTRAINT ck_training_session_state_details CHECK (
    (status = 'SCHEDULED'
      AND completed_at IS NULL AND absent_at IS NULL
      AND cancelled_at IS NULL AND cancellation_reason IS NULL)
    OR
    (status = 'COMPLETED'
      AND completed_at IS NOT NULL AND absent_at IS NULL
      AND cancelled_at IS NULL AND cancellation_reason IS NULL)
    OR
    (status = 'MEMBER_ABSENT'
      AND absent_at IS NOT NULL AND completed_at IS NULL
      AND cancelled_at IS NULL AND cancellation_reason IS NULL)
    OR
    (status = 'CANCELLED'
      AND cancelled_at IS NOT NULL AND cancellation_reason IS NOT NULL
      AND completed_at IS NULL AND absent_at IS NULL)
  )
);

CREATE INDEX ix_training_sessions_relationship_start
  ON training_sessions (relationship_id, scheduled_start_at);

CREATE TRIGGER trg_training_plans_updated_at
  BEFORE UPDATE ON training_plans
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_training_plan_days_updated_at
  BEFORE UPDATE ON training_plan_days
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_training_plan_exercises_updated_at
  BEFORE UPDATE ON training_plan_exercises
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_nutrition_guides_updated_at
  BEFORE UPDATE ON nutrition_guides
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_training_sessions_updated_at
  BEFORE UPDATE ON training_sessions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
