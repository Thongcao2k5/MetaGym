BEGIN;

ALTER TABLE payments
  ADD COLUMN momo_transaction_no varchar(19),
  ADD COLUMN momo_response_code varchar(4),
  ADD COLUMN momo_last_query_at timestamptz,
  ADD COLUMN momo_checkout_url text,
  DROP CONSTRAINT payments_method_check,
  DROP CONSTRAINT ck_payments_state_details,
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
  ),
  ADD CONSTRAINT ck_payments_momo_confirmation CHECK (
    method <> 'MOMO' OR status <> 'SUCCESS'
    OR (momo_transaction_no IS NOT NULL AND momo_transaction_no ~ '^[1-9][0-9]{0,18}$'
      AND momo_response_code IS NOT DISTINCT FROM '0')
  );

CREATE UNIQUE INDEX uq_payments_momo_pending_member ON payments (member_id)
  WHERE method = 'MOMO' AND status = 'PENDING';
CREATE UNIQUE INDEX uq_payments_momo_transaction_no ON payments (momo_transaction_no)
  WHERE method = 'MOMO' AND momo_transaction_no IS NOT NULL;

COMMIT;
