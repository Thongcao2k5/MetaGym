BEGIN;

CREATE TABLE workout_logs (
  id uuid PRIMARY KEY,
  member_id uuid NOT NULL REFERENCES users(id),
  training_session_id uuid,
  training_plan_id uuid,
  performed_at timestamptz NOT NULL,
  duration_minutes smallint CHECK (duration_minutes > 0),
  completion_level smallint CHECK (completion_level BETWEEN 0 AND 100),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_workout_log_member UNIQUE (id, member_id),
  CONSTRAINT fk_workout_session_member
    FOREIGN KEY (training_session_id, member_id)
    REFERENCES training_sessions(id, member_id),
  CONSTRAINT fk_workout_plan_member
    FOREIGN KEY (training_plan_id, member_id)
    REFERENCES training_plans(id, member_id)
);

CREATE INDEX ix_workout_logs_member_performed
  ON workout_logs (member_id, performed_at DESC);

CREATE TABLE workout_log_exercises (
  id uuid PRIMARY KEY,
  workout_log_id uuid NOT NULL REFERENCES workout_logs(id),
  exercise_id uuid REFERENCES exercises(id),
  exercise_name_snapshot varchar(120) NOT NULL,
  display_order smallint NOT NULL CHECK (display_order > 0),
  sets_completed smallint CHECK (sets_completed >= 0),
  reps_summary varchar(100),
  weight_kg numeric(6,2) CHECK (weight_kg >= 0),
  duration_seconds integer CHECK (duration_seconds > 0),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_workout_exercise_order UNIQUE (workout_log_id, display_order)
);

CREATE TABLE meal_logs (
  id uuid PRIMARY KEY,
  member_id uuid NOT NULL REFERENCES users(id),
  eaten_at timestamptz NOT NULL,
  meal_type varchar(20)
    CHECK (meal_type IN ('BREAKFAST', 'LUNCH', 'DINNER', 'SNACK', 'OTHER')),
  meal_name varchar(150) NOT NULL,
  description text,
  estimated_calories integer CHECK (estimated_calories >= 0),
  image_media_id uuid,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_meal_log_member UNIQUE (id, member_id),
  CONSTRAINT fk_meal_image_owner
    FOREIGN KEY (image_media_id, member_id)
    REFERENCES media_assets(id, owner_id)
);

CREATE INDEX ix_meal_logs_member_eaten
  ON meal_logs (member_id, eaten_at DESC);

CREATE TABLE body_measurements (
  id uuid PRIMARY KEY,
  member_id uuid NOT NULL REFERENCES users(id),
  measured_at timestamptz NOT NULL,
  weight_kg numeric(5,2) NOT NULL CHECK (weight_kg > 0),
  body_fat_percent numeric(5,2) CHECK (body_fat_percent BETWEEN 0 AND 100),
  chest_cm numeric(5,2) CHECK (chest_cm > 0),
  waist_cm numeric(5,2) CHECK (waist_cm > 0),
  hips_cm numeric(5,2) CHECK (hips_cm > 0),
  arm_cm numeric(5,2) CHECK (arm_cm > 0),
  thigh_cm numeric(5,2) CHECK (thigh_cm > 0),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_body_measurement_member UNIQUE (id, member_id)
);

CREATE INDEX ix_measurements_member_measured
  ON body_measurements (member_id, measured_at DESC);

CREATE TABLE progress_photos (
  id uuid PRIMARY KEY,
  member_id uuid NOT NULL REFERENCES users(id),
  media_id uuid NOT NULL UNIQUE,
  taken_at timestamptz NOT NULL,
  pose varchar(20) CHECK (pose IN ('FRONT', 'SIDE', 'BACK', 'OTHER')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_progress_photo_member UNIQUE (id, member_id),
  CONSTRAINT fk_progress_photo_media_owner
    FOREIGN KEY (media_id, member_id)
    REFERENCES media_assets(id, owner_id)
);

CREATE INDEX ix_progress_photos_member_taken
  ON progress_photos (member_id, taken_at DESC);

CREATE TABLE progress_comments (
  id uuid PRIMARY KEY,
  member_id uuid NOT NULL REFERENCES users(id),
  coach_id uuid NOT NULL REFERENCES users(id),
  relationship_id uuid NOT NULL,
  workout_log_id uuid,
  meal_log_id uuid,
  measurement_id uuid,
  progress_photo_id uuid,
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_progress_comment_relationship
    FOREIGN KEY (relationship_id, member_id, coach_id)
    REFERENCES coach_relationships(id, member_id, coach_id),
  CONSTRAINT fk_comment_workout_member
    FOREIGN KEY (workout_log_id, member_id)
    REFERENCES workout_logs(id, member_id),
  CONSTRAINT fk_comment_meal_member
    FOREIGN KEY (meal_log_id, member_id)
    REFERENCES meal_logs(id, member_id),
  CONSTRAINT fk_comment_measurement_member
    FOREIGN KEY (measurement_id, member_id)
    REFERENCES body_measurements(id, member_id),
  CONSTRAINT fk_comment_photo_member
    FOREIGN KEY (progress_photo_id, member_id)
    REFERENCES progress_photos(id, member_id),
  CONSTRAINT ck_progress_comment_one_target CHECK (
    num_nonnulls(workout_log_id, meal_log_id, measurement_id, progress_photo_id) <= 1
  )
);

CREATE INDEX ix_comments_workout
  ON progress_comments (workout_log_id)
  WHERE workout_log_id IS NOT NULL;
CREATE INDEX ix_comments_meal
  ON progress_comments (meal_log_id)
  WHERE meal_log_id IS NOT NULL;
CREATE INDEX ix_comments_measurement
  ON progress_comments (measurement_id)
  WHERE measurement_id IS NOT NULL;
CREATE INDEX ix_comments_photo
  ON progress_comments (progress_photo_id)
  WHERE progress_photo_id IS NOT NULL;

CREATE TRIGGER trg_workout_logs_updated_at
  BEFORE UPDATE ON workout_logs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_meal_logs_updated_at
  BEFORE UPDATE ON meal_logs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_body_measurements_updated_at
  BEFORE UPDATE ON body_measurements
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_progress_photos_updated_at
  BEFORE UPDATE ON progress_photos
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
