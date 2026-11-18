BEGIN;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM payments WHERE method = 'ZALOPAY') THEN
    RAISE EXCEPTION 'Cannot roll back ZaloPay Sandbox while ZaloPay payment history exists';
  END IF;
END $$;

ALTER TABLE payments
  DROP CONSTRAINT ck_payments_zalopay_confirmation,
  DROP CONSTRAINT payments_method_check,
  DROP CONSTRAINT ck_payments_state_details,
  DROP COLUMN zalopay_transaction_no,
  DROP COLUMN zalopay_response_code,
  DROP COLUMN zalopay_last_query_at,
  DROP COLUMN zalopay_checkout_url,
  ADD CONSTRAINT payments_method_check CHECK (method IN ('MOCK_QR', 'FRONT_DESK', 'VNPAY', 'MOMO')),
  ADD CONSTRAINT ck_payments_state_details CHECK (
    (status = 'PENDING' AND confirmed_at IS NULL AND decided_at IS NULL
      AND decided_by IS NULL AND failure_reason IS NULL)
    OR (status = 'SUCCESS' AND confirmed_at IS NOT NULL AND decided_at IS NOT NULL
      AND failure_reason IS NULL AND (
        (method IN ('MOCK_QR', 'VNPAY', 'MOMO') AND decided_by IS NULL)
        OR (method = 'FRONT_DESK' AND decided_by IS NOT NULL)))
    OR (status IN ('FAILED', 'CANCELLED') AND confirmed_at IS NULL
      AND decided_at IS NOT NULL AND failure_reason IS NOT NULL)
  );
DROP INDEX uq_payments_zalopay_pending_member;

COMMIT;
