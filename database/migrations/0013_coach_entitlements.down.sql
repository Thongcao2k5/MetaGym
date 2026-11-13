BEGIN;
-- Refuse rollback while entitlement history needs preservation.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM coach_entitlements) THEN
    RAISE EXCEPTION 'Export and migrate Coach entitlements before rollback';
  END IF;
END;
$$;
UPDATE coach_payment_holds SET status = 'CANCELLED' WHERE status = 'FAILED';
ALTER TABLE coach_payment_holds DROP CONSTRAINT coach_payment_holds_status_check;
ALTER TABLE coach_payment_holds ADD CONSTRAINT coach_payment_holds_status_check
  CHECK (status IN ('HELD', 'CANCELLED', 'EXPIRED'));
DROP TRIGGER trg_close_coach_entitlements ON coach_relationships;
DROP FUNCTION close_coach_entitlements();
DROP TABLE coach_bookings;
DROP TABLE coach_entitlements;
CREATE OR REPLACE FUNCTION coach_occupied_seats(target_coach uuid) RETURNS integer
LANGUAGE sql STABLE AS $$
  SELECT (
    (SELECT count(*) FROM coach_relationships
     WHERE coach_id = target_coach AND status IN ('ACTIVE', 'PAUSED')) +
    (SELECT count(*) FROM coach_payment_holds
     WHERE coach_id = target_coach AND status = 'HELD'
       AND expires_at > statement_timestamp())
  )::integer;
$$;
COMMIT;
