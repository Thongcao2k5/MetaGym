BEGIN;

-- 1. Expand coach_relationships pause_reason for D1 (COACH_LOCKED) & D4 (MEMBER_LOCKED)
ALTER TABLE coach_relationships
  DROP CONSTRAINT coach_relationships_pause_reason_check,
  ADD CONSTRAINT coach_relationships_pause_reason_check
    CHECK (pause_reason IN ('MEMBERSHIP_EXPIRED', 'COACH_LOCKED', 'MEMBER_LOCKED'));

-- 2. Entitlement freeze tracking & explicit 7-day grace counter
ALTER TABLE coach_entitlements
  ADD COLUMN frozen_at timestamptz,
  ADD COLUMN frozen_days_total integer NOT NULL DEFAULT 0 CHECK (frozen_days_total >= 0),
  ADD COLUMN grace_days_added integer NOT NULL DEFAULT 0 CHECK (grace_days_added IN (0, 7));

UPDATE coach_entitlements
   SET grace_days_added = CASE
     WHEN ends_on = original_ends_on + 7 THEN 7
     ELSE 0
   END
 WHERE original_ends_on IS NOT NULL
   AND ends_on IS NOT NULL;

ALTER TABLE coach_entitlements
  DROP CONSTRAINT ck_coach_entitlement_dates,
  ADD CONSTRAINT ck_coach_entitlement_dates CHECK (
    (starts_on IS NULL AND original_ends_on IS NULL AND ends_on IS NULL
      AND frozen_at IS NULL AND frozen_days_total = 0 AND grace_days_added = 0)
    OR
    (starts_on IS NOT NULL AND original_ends_on IS NOT NULL AND ends_on IS NOT NULL
      AND original_ends_on = starts_on + duration_days - 1
      AND ends_on = original_ends_on + frozen_days_total + grace_days_added)
  );

-- 3. Coach lock incidents table (D1, D2, D3)
CREATE TABLE coach_lock_incidents (
  id uuid PRIMARY KEY,
  coach_id uuid NOT NULL REFERENCES users(id),
  member_id uuid NOT NULL REFERENCES users(id),
  relationship_id uuid NOT NULL REFERENCES coach_relationships(id),
  active_entitlement_id uuid REFERENCES coach_entitlements(id),
  queued_entitlement_id uuid REFERENCES coach_entitlements(id),
  lock_reason text NOT NULL,
  locked_by uuid NOT NULL REFERENCES users(id),
  locked_at timestamptz NOT NULL DEFAULT now(),
  frozen_started_at timestamptz,
  frozen_ended_at timestamptz,
  frozen_days_applied integer CHECK (frozen_days_applied IS NULL OR frozen_days_applied >= 0),
  member_choice varchar(20) NOT NULL DEFAULT 'WAIT'
    CHECK (member_choice IN ('WAIT', 'REFUND')),
  member_choice_at timestamptz,
  member_choice_note text,
  status varchar(30) NOT NULL DEFAULT 'OPEN'
    CHECK (status IN (
      'OPEN',
      'RESOLVED_COACH_UNLOCKED',
      'RESOLVED_TRANSFERRED',
      'RESOLVED_REFUNDED',
      'RESOLVED_ENDED'
    )),
  transfer_history_id uuid REFERENCES coach_transfer_history(id),
  refund_batch_id uuid,
  resolved_by uuid REFERENCES users(id),
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uq_coach_lock_incident_open
  ON coach_lock_incidents (relationship_id)
  WHERE status = 'OPEN';

CREATE TRIGGER trg_coach_lock_incidents_updated_at
  BEFORE UPDATE ON coach_lock_incidents
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 4. Update close_coach_entitlements() and notify_coach_package() triggers
CREATE OR REPLACE FUNCTION close_coach_entitlements() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  cancel_reason text;
BEGIN
  IF NEW.status = 'ENDED' THEN
    UPDATE coach_entitlements
       SET status = 'ENDED',
           ended_at = statement_timestamp(),
           frozen_at = NULL,
           close_reason = COALESCE(
             close_reason,
             CASE
               WHEN NEW.end_reason = 'Đã dùng hết số buổi Coach' THEN 'COMPLETED_SESSIONS'
               WHEN NEW.end_reason = 'Gói Coach đã hết hạn' THEN 'EXPIRED'
               ELSE 'EARLY_TERMINATION'
             END
           )
     WHERE relationship_id = NEW.id
       AND status IN ('ACTIVE', 'QUEUED');

    UPDATE training_plans
       SET status = 'ARCHIVED', archived_at = statement_timestamp()
     WHERE relationship_id = NEW.id AND status = 'ACTIVE';

    UPDATE nutrition_guides
       SET status = 'ARCHIVED', archived_at = statement_timestamp()
     WHERE relationship_id = NEW.id AND status = 'ACTIVE';

    UPDATE coach_payment_holds
       SET status = 'CANCELLED'
     WHERE member_id = NEW.member_id AND coach_id = NEW.coach_id AND status = 'HELD';

    UPDATE coach_lock_incidents
       SET status = 'RESOLVED_ENDED',
           resolved_at = statement_timestamp(),
           resolved_by = COALESCE(resolved_by, NEW.ended_by)
     WHERE relationship_id = NEW.id
       AND status = 'OPEN';

    cancel_reason := COALESCE(NULLIF(btrim(NEW.end_reason), ''), 'Quan hệ Coach không còn hoạt động');
  ELSE
    cancel_reason := CASE NEW.pause_reason
      WHEN 'COACH_LOCKED' THEN 'Tài khoản Coach bị khóa'
      WHEN 'MEMBER_LOCKED' THEN 'Tài khoản Member bị khóa'
      WHEN 'MEMBERSHIP_EXPIRED' THEN 'Gói tập của Member đã hết hạn'
      ELSE 'Quan hệ Coach không còn hoạt động'
    END;
  END IF;

  UPDATE coach_bookings b
     SET status = 'CANCELLED',
         resolved_at = statement_timestamp(),
         resolved_by = NEW.ended_by,
         reason = cancel_reason
    FROM coach_entitlements e
   WHERE e.relationship_id = NEW.id
     AND b.entitlement_id = e.id
     AND b.status = 'BOOKED'
     AND b.starts_at > statement_timestamp();

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION notify_coach_package() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  event_kind text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.source_entitlement_id IS NULL THEN
      event_kind := 'PACKAGE_' || NEW.status;
    END IF;
  ELSIF NEW.status <> OLD.status THEN
    IF NOT (NEW.status = 'ENDED' AND NEW.close_reason IN ('TRANSFERRED', 'SIMULATED_REFUND')) THEN
      event_kind := 'PACKAGE_' || NEW.status;
    END IF;
  ELSIF NEW.grace_days_added > OLD.grace_days_added THEN
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

COMMIT;
