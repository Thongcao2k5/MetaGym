BEGIN;

ALTER TABLE payments
  DROP CONSTRAINT payments_method_check,
  DROP CONSTRAINT ck_payments_state_details,
  ADD COLUMN vnpay_transaction_no varchar(15),
  ADD COLUMN vnpay_response_code varchar(2),
  ADD COLUMN vnpay_transaction_status varchar(2),
  ADD COLUMN vnpay_last_query_at timestamptz,
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
  ),
  ADD CONSTRAINT ck_payments_vnpay_confirmation CHECK (
    method <> 'VNPAY' OR status <> 'SUCCESS'
    OR (vnpay_transaction_no IS NOT NULL AND vnpay_transaction_no ~ '^[1-9][0-9]{0,14}$'
      AND vnpay_response_code IS NOT DISTINCT FROM '00'
      AND vnpay_transaction_status IS NOT DISTINCT FROM '00')
  );

CREATE UNIQUE INDEX uq_payments_vnpay_pending_member ON payments (member_id)
  WHERE method = 'VNPAY' AND status = 'PENDING';
CREATE UNIQUE INDEX uq_payments_vnpay_transaction_no ON payments (vnpay_transaction_no)
  WHERE method = 'VNPAY' AND vnpay_transaction_no IS NOT NULL;

COMMIT;
