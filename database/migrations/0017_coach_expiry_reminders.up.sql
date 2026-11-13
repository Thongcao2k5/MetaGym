BEGIN;
CREATE UNIQUE INDEX uq_coach_expiry_reminder ON coach_notifications (user_id, kind, subject_id)
  WHERE kind = 'PACKAGE_EXPIRING';
COMMIT;
