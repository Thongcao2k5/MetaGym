BEGIN;

LOCK TABLE payments IN ACCESS EXCLUSIVE MODE;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM payments WHERE method = 'VNPAY') THEN
    RAISE EXCEPTION 'VNPay payment history exists; restore a backup instead of discarding it';
  END IF;
END $$;

DROP INDEX uq_payments_vnpay_pending_member;
DROP INDEX uq_payments_vnpay_transaction_no;
ALTER TABLE payments
  DROP CONSTRAINT ck_payments_vnpay_confirmation,
  DROP CONSTRAINT payments_method_check,
  DROP CONSTRAINT ck_payments_state_details,
  DROP COLUMN vnpay_transaction_no,
  DROP COLUMN vnpay_response_code,
  DROP COLUMN vnpay_transaction_status,
  DROP COLUMN vnpay_last_query_at,
  ADD CONSTRAINT payments_method_check CHECK (method IN ('MOCK_QR', 'FRONT_DESK')),
  ADD CONSTRAINT ck_payments_state_details CHECK (
    (status = 'PENDING' AND confirmed_at IS NULL AND decided_at IS NULL
      AND decided_by IS NULL AND failure_reason IS NULL)
    OR (status = 'SUCCESS' AND confirmed_at IS NOT NULL AND decided_at IS NOT NULL
      AND failure_reason IS NULL AND (
        (method = 'MOCK_QR' AND decided_by IS NULL)
        OR (method = 'FRONT_DESK' AND decided_by IS NOT NULL)))
    OR (status IN ('FAILED', 'CANCELLED') AND confirmed_at IS NULL
      AND decided_at IS NOT NULL AND failure_reason IS NOT NULL)
  );

COMMIT;
