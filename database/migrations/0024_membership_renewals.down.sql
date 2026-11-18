BEGIN;

LOCK TABLE payments IN ACCESS EXCLUSIVE MODE;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM payments WHERE renewed_membership_id IS NOT NULL) THEN
    RAISE EXCEPTION 'Restore the pre-migration backup before rolling back applied membership renewals';
  END IF;
END $$;

ALTER TABLE payments DROP COLUMN renewed_membership_id;
ALTER TABLE member_memberships DROP CONSTRAINT uq_member_membership_owner;

COMMIT;
