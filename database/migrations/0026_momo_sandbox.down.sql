BEGIN;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM payments WHERE method = 'MOMO') THEN
    RAISE EXCEPTION 'Cannot roll back MoMo Sandbox while MoMo payment history exists';
  END IF;
END $$;

ALTER TABLE payments
  DROP CONSTRAINT ck_payments_momo_confirmation,
  DROP CONSTRAINT payments_method_check,
  DROP CONSTRAINT ck_payments_state_details,
  DROP COLUMN momo_transaction_no,
  DROP COLUMN momo_response_code,
  DROP COLUMN momo_last_query_at,
  DROP COLUMN momo_checkout_url,
  ADD CONSTRAINT payments_method_check CHECK (method IN ('MOCK_QR', 'FRONT_DESK', 'VNPAY')),
  ADD CONSTRAINT ck_payments_state_details CHECK (
    (status = 'PENDING' AND confirmed_at IS NULL AND decided_at IS NULL
      AND decided_by IS NULL AND failure_reason IS NULL)
    OR (status = 'SUCCESS' AND confirmed_at IS NOT NULL AND decided_at IS NOT NULL
      AND failure_reason IS NULL AND (
        (method IN ('MOCK_QR', 'VNPAY') AND decided_by IS NULL)
        OR (method = 'FRONT_DESK' AND decided_by IS NOT NULL)))
    OR (status IN ('FAILED', 'CANCELLED') AND confirmed_at IS NULL
      AND decided_at IS NOT NULL AND failure_reason IS NOT NULL)
  );
DROP INDEX uq_payments_momo_pending_member;

COMMIT;
