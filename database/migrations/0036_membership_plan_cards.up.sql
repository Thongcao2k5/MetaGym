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
    'COACH_OUTCOME',
    'PACKAGE'
  ));

ALTER TABLE membership_plans
  ADD COLUMN IF NOT EXISTS card_tier varchar(20)
    CHECK (card_tier IN ('BRONZE', 'SILVER', 'GOLD', 'DIAMOND')),
  ADD COLUMN IF NOT EXISTS front_media_id uuid REFERENCES media_assets(id),
  ADD COLUMN IF NOT EXISTS back_media_id uuid REFERENCES media_assets(id),
  ADD COLUMN IF NOT EXISTS card_highlights text[] NOT NULL DEFAULT '{}';

COMMIT;
