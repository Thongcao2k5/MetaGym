BEGIN;

DROP TABLE IF EXISTS coach_outcome_cases;

ALTER TABLE media_assets DROP CONSTRAINT media_assets_purpose_check;
ALTER TABLE media_assets ADD CONSTRAINT media_assets_purpose_check
  CHECK (purpose IN (
    'AVATAR',
    'MESSAGE',
    'PROGRESS_PHOTO',
    'MEAL_PHOTO',
    'EQUIPMENT',
    'GYM'
  ));

COMMIT;
