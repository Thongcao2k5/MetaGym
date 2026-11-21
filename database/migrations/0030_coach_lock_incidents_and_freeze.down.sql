BEGIN;

-- 4. Restore 0015 notify_coach_package() and 0013 close_coach_entitlements()
CREATE OR REPLACE FUNCTION notify_coach_package() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  event_kind text;
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

CREATE OR REPLACE FUNCTION close_coach_entitlements() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status = 'ENDED' THEN
    UPDATE coach_entitlements SET status = 'ENDED', ended_at = statement_timestamp()
      WHERE relationship_id = NEW.id AND status IN ('ACTIVE', 'QUEUED');
    UPDATE training_plans SET status = 'ARCHIVED', archived_at = statement_timestamp()
      WHERE relationship_id = NEW.id AND status = 'ACTIVE';
    UPDATE nutrition_guides SET status = 'ARCHIVED', archived_at = statement_timestamp()
      WHERE relationship_id = NEW.id AND status = 'ACTIVE';
    UPDATE coach_payment_holds SET status = 'CANCELLED'
      WHERE member_id = NEW.member_id AND coach_id = NEW.coach_id AND status = 'HELD';
  END IF;
  UPDATE coach_bookings b SET status = 'CANCELLED', resolved_at = statement_timestamp(),
    resolved_by = NEW.ended_by, reason = 'Quan hệ Coach không còn hoạt động'
    FROM coach_entitlements e WHERE e.relationship_id = NEW.id AND b.entitlement_id = e.id
      AND b.status = 'BOOKED' AND b.starts_at > statement_timestamp();
  RETURN NEW;
END;
$$;

-- 3. Drop coach_lock_incidents
DROP TABLE coach_lock_incidents;

-- 2. Restore coach_entitlements dates constraint & drop freeze/grace columns
ALTER TABLE coach_entitlements
  DROP CONSTRAINT ck_coach_entitlement_dates,
  DROP COLUMN grace_days_added,
  DROP COLUMN frozen_days_total,
  DROP COLUMN frozen_at,
  ADD CONSTRAINT ck_coach_entitlement_dates CHECK (
    (starts_on IS NULL AND original_ends_on IS NULL AND ends_on IS NULL)
    OR (starts_on IS NOT NULL AND original_ends_on IS NOT NULL AND ends_on IS NOT NULL
      AND original_ends_on = starts_on + duration_days - 1
      AND ends_on IN (original_ends_on, original_ends_on + 7))
  );

-- 1. Restore coach_relationships pause_reason constraint
ALTER TABLE coach_relationships
  DROP CONSTRAINT coach_relationships_pause_reason_check,
  ADD CONSTRAINT coach_relationships_pause_reason_check
    CHECK (pause_reason IN ('MEMBERSHIP_EXPIRED'));

COMMIT;
