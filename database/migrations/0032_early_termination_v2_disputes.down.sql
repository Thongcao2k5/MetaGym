BEGIN;

-- 6. Restore 0030 close_coach_entitlements() trigger function
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

-- 5. Drop V2 indexes
DROP INDEX ix_termination_open_deadline;
DROP INDEX uq_termination_open_relationship;

-- 4. Drop V2 constraints
ALTER TABLE coach_termination_requests
  DROP CONSTRAINT ck_termination_state_details,
  DROP CONSTRAINT coach_termination_requests_status_check;

-- 3. Map V2 statuses back to legacy V1 statuses if any rows exist during rollback
UPDATE coach_termination_requests
   SET status = CASE status
         WHEN 'PENDING_COUNTERPARTY' THEN 'PENDING'
         WHEN 'DISPUTED' THEN 'PENDING'
         WHEN 'ADMIN_APPROVED' THEN 'APPROVED'
         WHEN 'ADMIN_REJECTED' THEN 'REJECTED'
         WHEN 'ACCEPTED' THEN 'CANCELLED'
         ELSE status
       END,
       decided_by = CASE
         WHEN status IN ('PENDING_COUNTERPARTY', 'DISPUTED', 'ACCEPTED') THEN NULL
         ELSE decided_by
       END,
       decided_at = CASE
         WHEN status IN ('PENDING_COUNTERPARTY', 'DISPUTED') THEN NULL
         WHEN status = 'ACCEPTED' THEN COALESCE(decided_at, counterparty_decided_at, now())
         ELSE decided_at
       END;

-- 2. Restore status column type/default and drop V2 columns
ALTER TABLE coach_termination_requests
  ALTER COLUMN status DROP DEFAULT,
  ALTER COLUMN status TYPE varchar(20),
  ALTER COLUMN status SET DEFAULT 'PENDING',
  DROP COLUMN escalation_reason,
  DROP COLUMN disputed_at,
  DROP COLUMN response_deadline_at,
  DROP COLUMN counterparty_decided_at,
  DROP COLUMN counterparty_reason,
  DROP COLUMN counterparty_decision,
  DROP COLUMN counterparty_user_id,
  DROP COLUMN requested_by_role,
  DROP COLUMN requested_by_user_id;

-- 1. Restore 0002 constraints & indexes
ALTER TABLE coach_termination_requests
  ADD CONSTRAINT coach_termination_requests_status_check
    CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED')),
  ADD CONSTRAINT ck_termination_state_details CHECK (
    (status = 'PENDING' AND decided_by IS NULL AND decided_at IS NULL)
    OR
    (status IN ('APPROVED', 'REJECTED')
      AND decided_by IS NOT NULL AND decided_at IS NOT NULL)
    OR
    (status = 'CANCELLED' AND decided_by IS NULL AND decided_at IS NOT NULL)
  );

CREATE UNIQUE INDEX uq_termination_pending_relationship
  ON coach_termination_requests (relationship_id)
  WHERE status = 'PENDING';

CREATE INDEX ix_termination_pending_created
  ON coach_termination_requests (created_at DESC)
  WHERE status = 'PENDING';

COMMIT;
