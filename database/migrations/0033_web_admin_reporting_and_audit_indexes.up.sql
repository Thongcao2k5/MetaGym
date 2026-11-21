BEGIN;

-- Reporting, audit log viewer, and VN-timezone dashboard indexes (T3 §4)
CREATE INDEX ix_audit_created_desc
  ON admin_audit_logs (created_at DESC, id DESC);

CREATE INDEX ix_audit_action_created
  ON admin_audit_logs (action, created_at DESC);

CREATE INDEX ix_payments_confirmed_success
  ON payments (confirmed_at DESC)
  WHERE status = 'SUCCESS';

CREATE INDEX ix_coach_holds_consumed_settled
  ON coach_payment_holds (settled_at DESC)
  WHERE status = 'CONSUMED';

CREATE INDEX ix_coach_incidents_status_created
  ON coach_lock_incidents (status, created_at DESC);

CREATE INDEX ix_simulated_refunds_created_at
  ON simulated_refunds (created_at DESC, id DESC);

CREATE INDEX ix_payment_adjustments_created_at
  ON payment_adjustments (created_at DESC, id DESC);

CREATE INDEX ix_termination_disputed_created
  ON coach_termination_requests (disputed_at DESC)
  WHERE status = 'DISPUTED';

CREATE INDEX ix_nutrition_foods_name_lower
  ON nutrition_foods (lower(name));

COMMIT;
