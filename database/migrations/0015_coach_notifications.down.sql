BEGIN;
DROP TRIGGER trg_notify_coach_package ON coach_entitlements;
DROP TRIGGER trg_notify_coach_booking ON coach_bookings;
DROP FUNCTION notify_coach_package();
DROP FUNCTION notify_coach_booking();
DROP TABLE coach_notifications;
COMMIT;
