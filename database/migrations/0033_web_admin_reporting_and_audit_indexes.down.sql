BEGIN;

DROP INDEX IF EXISTS ix_nutrition_foods_name_lower;
DROP INDEX IF EXISTS ix_termination_disputed_created;
DROP INDEX IF EXISTS ix_payment_adjustments_created_at;
DROP INDEX IF EXISTS ix_simulated_refunds_created_at;
DROP INDEX IF EXISTS ix_coach_incidents_status_created;
DROP INDEX IF EXISTS ix_coach_holds_consumed_settled;
DROP INDEX IF EXISTS ix_payments_confirmed_success;
DROP INDEX IF EXISTS ix_audit_action_created;
DROP INDEX IF EXISTS ix_audit_created_desc;

COMMIT;
