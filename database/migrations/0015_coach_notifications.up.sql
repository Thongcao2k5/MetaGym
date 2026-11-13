BEGIN;
CREATE TABLE coach_notifications (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  kind text NOT NULL,
  subject_id uuid NOT NULL,
  event_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  read_at timestamptz
);
CREATE INDEX ix_coach_notifications_user ON coach_notifications (user_id, id DESC);

CREATE FUNCTION notify_coach_booking() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO coach_notifications (user_id, kind, subject_id)
      VALUES (NEW.coach_id, 'BOOKED', NEW.id);
  ELSIF NEW.status <> OLD.status THEN
    INSERT INTO coach_notifications (user_id, kind, subject_id)
      SELECT user_id, NEW.status, NEW.id
      FROM (VALUES (NEW.member_id), (NEW.coach_id)) AS participant(user_id)
      WHERE participant.user_id IS DISTINCT FROM NEW.resolved_by;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_notify_coach_booking AFTER INSERT OR UPDATE OF status ON coach_bookings
  FOR EACH ROW EXECUTE FUNCTION notify_coach_booking();

CREATE FUNCTION notify_coach_package() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE event_kind text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    event_kind := 'PACKAGE_' || NEW.status;
  ELSIF NEW.status <> OLD.status THEN
    event_kind := 'PACKAGE_' || NEW.status;
  ELSIF NEW.ends_on IS DISTINCT FROM OLD.ends_on THEN
    event_kind := 'PACKAGE_EXTENDED';
  ELSIF NEW.remaining_sessions = 1 AND OLD.remaining_sessions > 1 THEN
    event_kind := 'PACKAGE_LAST_SESSION';
  END IF;
  IF event_kind IS NOT NULL THEN
    INSERT INTO coach_notifications (user_id, kind, subject_id)
      VALUES (NEW.member_id, event_kind, NEW.id);
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_notify_coach_package AFTER INSERT OR UPDATE ON coach_entitlements
  FOR EACH ROW EXECUTE FUNCTION notify_coach_package();
COMMIT;
