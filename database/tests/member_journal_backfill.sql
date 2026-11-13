\set ON_ERROR_STOP on

INSERT INTO users (id, email, password_hash, role, full_name)
VALUES ('e903da24-8967-48f9-9edb-990297376403', 'backfill-fixture@example.test', 'fixture', 'MEMBER', 'Backfill fixture');

INSERT INTO workout_logs (id, member_id, performed_at, notes)
VALUES (gen_random_uuid(), 'e903da24-8967-48f9-9edb-990297376403', '2025-10-01 17:30:00+00', 'Buổi thứ nhất'),
       (gen_random_uuid(), 'e903da24-8967-48f9-9edb-990297376403', '2025-10-02 11:00:00+00', 'Buổi thứ hai');

INSERT INTO body_measurements (id, member_id, measured_at, weight_kg, waist_cm)
VALUES (gen_random_uuid(), 'e903da24-8967-48f9-9edb-990297376403', '2025-10-02 12:00:00+00', 70, 80);

INSERT INTO member_journal_entries (id, member_id, journal_date, notes)
VALUES (gen_random_uuid(), 'e903da24-8967-48f9-9edb-990297376403', '2025-10-03', 'Đã ghi từ V2');

INSERT INTO workout_logs (id, member_id, performed_at, notes)
VALUES (gen_random_uuid(), 'e903da24-8967-48f9-9edb-990297376403', '2025-10-03 10:00:00+07', 'Ghi cũ');

\ir ../migrations/0019_backfill_member_journal.up.sql
\ir ../migrations/0019_backfill_member_journal.up.sql

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM member_journal_entries WHERE member_id = 'e903da24-8967-48f9-9edb-990297376403'
      AND journal_date = '2025-10-02' AND waist_cm = 80
      AND notes = concat_ws(chr(10), 'Buổi thứ nhất', 'Buổi thứ hai')
  ) OR NOT EXISTS (
    SELECT 1 FROM member_journal_entries WHERE member_id = 'e903da24-8967-48f9-9edb-990297376403'
      AND journal_date = '2025-10-03' AND notes = 'Đã ghi từ V2'
  ) THEN
    RAISE EXCEPTION 'Unexpected journal backfill';
  END IF;
END;
$$;

DELETE FROM member_journal_entries WHERE member_id = 'e903da24-8967-48f9-9edb-990297376403';
DELETE FROM body_measurements WHERE member_id = 'e903da24-8967-48f9-9edb-990297376403';
DELETE FROM workout_logs WHERE member_id = 'e903da24-8967-48f9-9edb-990297376403';
DELETE FROM users WHERE id = 'e903da24-8967-48f9-9edb-990297376403';
