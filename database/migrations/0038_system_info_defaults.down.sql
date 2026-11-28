BEGIN;

DELETE FROM system_settings
 WHERE key IN (
   'legal_privacy_policy',
   'legal_terms_of_service',
   'home_quick_icons',
   'payment_methods'
 );

DELETE FROM media_assets WHERE purpose = 'SYSTEM_ICON';

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

COMMIT;
