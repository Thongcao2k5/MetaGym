BEGIN;

-- 1. Extend coach_termination_requests for D5 two-party 72h early termination & dispute adjudication
ALTER TABLE coach_termination_requests
  ADD COLUMN requested_by_user_id uuid REFERENCES users(id),
  ADD COLUMN requested_by_role varchar(10)
    CHECK (requested_by_role IN ('MEMBER', 'COACH')),
  ADD COLUMN counterparty_user_id uuid REFERENCES users(id),
  ADD COLUMN counterparty_decision varchar(20)
    CHECK (counterparty_decision IN ('ACCEPTED', 'REJECTED')),
  ADD COLUMN counterparty_reason text,
  ADD COLUMN counterparty_decided_at timestamptz,
  ADD COLUMN response_deadline_at timestamptz,
  ADD COLUMN disputed_at timestamptz,
  ADD COLUMN escalation_reason varchar(30)
    CHECK (escalation_reason IN ('COUNTERPARTY_REJECTED', 'TIMEOUT_72H'));

-- 2. Drop legacy status constraints & indexes before widening status and backfilling historical rows
ALTER TABLE coach_termination_requests
  DROP CONSTRAINT coach_termination_requests_status_check,
  DROP CONSTRAINT ck_termination_state_details;

DROP INDEX uq_termination_pending_relationship;
DROP INDEX ix_termination_pending_created;

ALTER TABLE coach_termination_requests
  ALTER COLUMN status DROP DEFAULT,
  ALTER COLUMN status TYPE varchar(30),
  ALTER COLUMN status SET DEFAULT 'PENDING_COUNTERPARTY';

-- 3. Backfill historical rows while preserving coach_id and fk_termination_relationship_coach
UPDATE coach_termination_requests t
   SET requested_by_user_id = t.coach_id,
       requested_by_role = 'COACH',
       counterparty_user_id = r.member_id,
       response_deadline_at = t.created_at + interval '72 hours',
       status = CASE WHEN t.status = 'PENDING' THEN 'DISPUTED' ELSE t.status END,
       disputed_at = CASE WHEN t.status = 'PENDING' THEN now() ELSE t.disputed_at END,
       escalation_reason = CASE WHEN t.status = 'PENDING' THEN 'TIMEOUT_72H' ELSE t.escalation_reason END
  FROM coach_relationships r
 WHERE r.id = t.relationship_id;

ALTER TABLE coach_termination_requests
  ALTER COLUMN requested_by_user_id SET NOT NULL,
  ALTER COLUMN requested_by_role SET NOT NULL,
  ALTER COLUMN counterparty_user_id SET NOT NULL,
  ALTER COLUMN response_deadline_at SET NOT NULL;

-- 4. Enforce V2 D5 status & state detail invariants (retaining APPROVED/REJECTED for historical closed rows)
ALTER TABLE coach_termination_requests
  ADD CONSTRAINT coach_termination_requests_status_check
    CHECK (status IN (
      'PENDING_COUNTERPARTY',
      'ACCEPTED',
      'DISPUTED',
      'ADMIN_APPROVED',
      'ADMIN_REJECTED',
      'CANCELLED',
      'APPROVED',
      'REJECTED'
    )),
  ADD CONSTRAINT ck_termination_state_details CHECK (
    requested_by_user_id <> counterparty_user_id
    AND (
      (status = 'PENDING_COUNTERPARTY'
        AND counterparty_decision IS NULL
        AND counterparty_decided_at IS NULL
        AND disputed_at IS NULL
        AND escalation_reason IS NULL
        AND decided_by IS NULL
        AND decided_at IS NULL)
      OR
      (status = 'ACCEPTED'
        AND counterparty_decision = 'ACCEPTED'
        AND counterparty_decided_at IS NOT NULL
        AND disputed_at IS NULL
        AND escalation_reason IS NULL
        AND decided_by IS NULL
        AND decided_at IS NOT NULL)
      OR
      (status = 'DISPUTED'
        AND disputed_at IS NOT NULL
        AND escalation_reason IS NOT NULL
        AND decided_by IS NULL
        AND decided_at IS NULL
        AND (
          (escalation_reason = 'COUNTERPARTY_REJECTED'
            AND counterparty_decision = 'REJECTED'
            AND counterparty_decided_at IS NOT NULL
            AND counterparty_reason IS NOT NULL
            AND btrim(counterparty_reason) <> '')
          OR
          (escalation_reason = 'TIMEOUT_72H'
            AND counterparty_decision IS NULL
            AND counterparty_decided_at IS NULL)
        ))
      OR
      (status IN ('ADMIN_APPROVED', 'ADMIN_REJECTED')
        AND disputed_at IS NOT NULL
        AND escalation_reason IS NOT NULL
        AND decided_by IS NOT NULL
        AND decided_at IS NOT NULL
        AND admin_note IS NOT NULL
        AND btrim(admin_note) <> '')
      OR
      (status IN ('APPROVED', 'REJECTED')
        AND decided_by IS NOT NULL
        AND decided_at IS NOT NULL)
      OR
      (status = 'CANCELLED'
        AND decided_by IS NULL
        AND decided_at IS NOT NULL)
    )
  );

-- 5. At most one open early-termination request (PENDING_COUNTERPARTY or DISPUTED) per relationship
CREATE UNIQUE INDEX uq_termination_open_relationship
  ON coach_termination_requests (relationship_id)
  WHERE status IN ('PENDING_COUNTERPARTY', 'DISPUTED');

CREATE INDEX ix_termination_open_deadline
  ON coach_termination_requests (response_deadline_at ASC)
  WHERE status = 'PENDING_COUNTERPARTY';

-- 6. Auto-cancel open D5 termination requests whenever a relationship transitions to ENDED via another path
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

    UPDATE coach_termination_requests
       SET status = 'CANCELLED',
           decided_at = statement_timestamp()
     WHERE relationship_id = NEW.id
       AND status IN ('PENDING_COUNTERPARTY', 'DISPUTED');

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

COMMIT;
