BEGIN;

ALTER TABLE membership_plans
  DROP COLUMN IF EXISTS card_highlights,
  DROP COLUMN IF EXISTS back_media_id,
  DROP COLUMN IF EXISTS front_media_id,
  DROP COLUMN IF EXISTS card_tier;

DELETE FROM media_assets WHERE purpose = 'PACKAGE';

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

COMMIT;
