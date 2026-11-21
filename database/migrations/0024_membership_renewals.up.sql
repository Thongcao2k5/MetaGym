BEGIN;

ALTER TABLE member_memberships
  ADD CONSTRAINT uq_member_membership_owner UNIQUE (id, member_id);

ALTER TABLE payments
  ADD COLUMN renewed_membership_id uuid,
  ADD CONSTRAINT fk_payment_renewed_membership
    FOREIGN KEY (renewed_membership_id, member_id)
    REFERENCES member_memberships (id, member_id)
    ON DELETE SET NULL (renewed_membership_id);

CREATE INDEX ix_payments_renewed_membership
  ON payments (renewed_membership_id) WHERE renewed_membership_id IS NOT NULL;

-- Fold consecutive prepaid periods into the current period. Keep the
-- original rows and payments so the purchase history remains auditable.
DO $$
DECLARE
  business_date date := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
  current_period record;
  next_period record;
  extended_end date;
BEGIN
  FOR current_period IN
    SELECT id, member_id, end_date
    FROM member_memberships
    WHERE status IN ('ACTIVE', 'SCHEDULED')
      AND business_date BETWEEN start_date AND end_date
  LOOP
    extended_end := current_period.end_date;
    FOR next_period IN
      SELECT id, source_payment_id, start_date, end_date
      FROM member_memberships
      WHERE member_id = current_period.member_id AND status = 'SCHEDULED'
        AND start_date > current_period.end_date
      ORDER BY start_date
    LOOP
      EXIT WHEN next_period.start_date <> extended_end + 1;
      UPDATE member_memberships SET status = 'CANCELLED' WHERE id = next_period.id;
      UPDATE payments SET renewed_membership_id = current_period.id
      WHERE id = next_period.source_payment_id;
      extended_end := next_period.end_date;
    END LOOP;
    IF extended_end <> current_period.end_date THEN
      UPDATE member_memberships SET end_date = extended_end WHERE id = current_period.id;
    END IF;
  END LOOP;
END $$;

COMMIT;
