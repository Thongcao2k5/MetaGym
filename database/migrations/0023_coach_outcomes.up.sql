BEGIN;

ALTER TABLE media_assets DROP CONSTRAINT media_assets_purpose_check;
ALTER TABLE media_assets ADD CONSTRAINT media_assets_purpose_check
  CHECK (purpose IN (
    'AVATAR',
    'MESSAGE',
    'PROGRESS_PHOTO',
    'MEAL_PHOTO',
    'EQUIPMENT',
    'GYM',
    'COACH_OUTCOME'
  ));

CREATE TABLE coach_outcome_cases (
  id uuid PRIMARY KEY,
  coach_id uuid NOT NULL REFERENCES users(id),
  member_id uuid NOT NULL REFERENCES users(id),
  relationship_id uuid NOT NULL REFERENCES coach_relationships(id),
  goal varchar(200) NOT NULL,
  duration_weeks integer NOT NULL CHECK (duration_weeks > 0 AND duration_weeks <= 520),
  before_weight_kg numeric(6,2) NOT NULL CHECK (before_weight_kg > 0 AND before_weight_kg <= 999.99),
  after_weight_kg numeric(6,2) NOT NULL CHECK (after_weight_kg > 0 AND after_weight_kg <= 999.99),
  before_body_fat_percent numeric(5,2) CHECK (before_body_fat_percent > 0 AND before_body_fat_percent <= 100),
  after_body_fat_percent numeric(5,2) CHECK (after_body_fat_percent > 0 AND after_body_fat_percent <= 100),
  before_media_id uuid REFERENCES media_assets(id),
  after_media_id uuid REFERENCES media_assets(id),
  status varchar(20) NOT NULL DEFAULT 'PENDING_MEMBER'
    CHECK (status IN ('PENDING_MEMBER', 'APPROVED', 'DECLINED', 'WITHDRAWN')),
  allow_real_name boolean NOT NULL DEFAULT false,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_coach_outcome_different_pair CHECK (coach_id <> member_id)
);

CREATE INDEX ix_coach_outcomes_coach_status
  ON coach_outcome_cases (coach_id, status, submitted_at DESC);
CREATE INDEX ix_coach_outcomes_member_status
  ON coach_outcome_cases (member_id, status, submitted_at DESC);

COMMIT;
