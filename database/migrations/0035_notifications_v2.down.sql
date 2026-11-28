BEGIN;

DROP TABLE IF EXISTS admin_notification_broadcasts;
DROP TABLE IF EXISTS user_notification_preferences;
DROP TABLE IF EXISTS user_device_tokens;

DROP INDEX IF EXISTS ix_coach_notifications_user_cat;
DROP INDEX IF EXISTS ix_coach_notifications_user_unread;

ALTER TABLE coach_notifications
  DROP COLUMN IF EXISTS metadata,
  DROP COLUMN IF EXISTS action_route,
  DROP COLUMN IF EXISTS body,
  DROP COLUMN IF EXISTS title,
  DROP COLUMN IF EXISTS category;

DELETE FROM coach_notifications WHERE subject_id IS NULL;

ALTER TABLE coach_notifications
  ALTER COLUMN subject_id SET NOT NULL;

COMMIT;
