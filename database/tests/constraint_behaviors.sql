\set ON_ERROR_STOP on

BEGIN;

INSERT INTO users (id, email, password_hash, role, full_name)
VALUES
  ('10000000-0000-4000-8000-000000000001', 'admin-one@test.local', 'hash', 'ADMIN', 'Admin One'),
  ('10000000-0000-4000-8000-000000000002', 'member-one@test.local', 'hash', 'MEMBER', 'Member One'),
  ('10000000-0000-4000-8000-000000000003', 'member-two@test.local', 'hash', 'MEMBER', 'Member Two'),
  ('10000000-0000-4000-8000-000000000004', 'coach-one@test.local', 'hash', 'COACH', 'Coach One'),
  ('10000000-0000-4000-8000-000000000005', 'coach-two@test.local', 'hash', 'COACH', 'Coach Two'),
  ('10000000-0000-4000-8000-000000000006', 'outsider@test.local', 'hash', 'MEMBER', 'Outsider');

DO $$
BEGIN
  BEGIN
    INSERT INTO users (id, email, password_hash, role, full_name)
    VALUES ('10000000-0000-4000-8000-000000000007', 'admin-two@test.local', 'hash', 'ADMIN', 'Admin Two');
    RAISE EXCEPTION 'Expected second Admin to be rejected';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;
END
$$;

INSERT INTO membership_plans (
  id, name, price, duration_days, status, created_by
)
VALUES (
  '20000000-0000-4000-8000-000000000001',
  'Test Plan',
  100000,
  30,
  'ACTIVE',
  '10000000-0000-4000-8000-000000000001'
);

DO $$
BEGIN
  BEGIN
    INSERT INTO payments (
      id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
      amount, method, status, transaction_code, idempotency_key, request_hash,
      created_by, decided_by
    )
    VALUES (
      '30000000-0000-4000-8000-000000000099',
      '10000000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000001',
      'Test Plan', 30, 100000, 'MOCK_QR', 'PENDING', 'PAY-INVALID-PENDING',
      'intent-invalid-pending', repeat('f', 64),
      '10000000-0000-4000-8000-000000000002',
      '10000000-0000-4000-8000-000000000001'
    );
    RAISE EXCEPTION 'Expected a PENDING payment with decided_by to be rejected';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;
END
$$;

INSERT INTO payments (
  id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
  amount, method, status, transaction_code, idempotency_key, request_hash,
  created_by, confirmed_at, decided_at
)
VALUES (
  '30000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000002',
  '20000000-0000-4000-8000-000000000001',
  'Test Plan', 30, 100000, 'MOCK_QR', 'SUCCESS', 'PAY-TEST-1',
  'intent-1', repeat('a', 64),
  '10000000-0000-4000-8000-000000000002', now(), now()
);

DO $$
BEGIN
  BEGIN
    INSERT INTO member_memberships (
      id, member_id, plan_id, source_payment_id,
      start_date, end_date, status, activated_at
    )
    VALUES (
      '40000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      current_date, current_date + 29, 'ACTIVE', now()
    );
    RAISE EXCEPTION 'Expected payment/member mismatch to be rejected';
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;
END
$$;

INSERT INTO coach_requests (
  id, member_id, coach_id, status, decided_at
)
VALUES (
  '50000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000004',
  'ACCEPTED', now()
);

DO $$
BEGIN
  BEGIN
    INSERT INTO coach_relationships (
      id, member_id, coach_id, source_request_id, status
    )
    VALUES (
      '60000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002',
      '10000000-0000-4000-8000-000000000005',
      '50000000-0000-4000-8000-000000000001',
      'ACTIVE'
    );
    RAISE EXCEPTION 'Expected request/relationship mismatch to be rejected';
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;
END
$$;

INSERT INTO coach_relationships (
  id, member_id, coach_id, source_request_id, status
)
VALUES (
  '60000000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000004',
  '50000000-0000-4000-8000-000000000001',
  'ACTIVE'
);

INSERT INTO conversations (id, relationship_id)
VALUES (
  '70000000-0000-4000-8000-000000000001',
  '60000000-0000-4000-8000-000000000002'
);

INSERT INTO conversation_participants (conversation_id, user_id)
VALUES
  ('70000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002'),
  ('70000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000004');

DO $$
BEGIN
  BEGIN
    INSERT INTO messages (
      id, conversation_id, sender_id, client_message_id, message_type, content
    )
    VALUES (
      '80000000-0000-4000-8000-000000000001',
      '70000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000006',
      '80000000-0000-4000-8000-000000000002',
      'TEXT', 'Outsider message'
    );
    RAISE EXCEPTION 'Expected non-participant sender to be rejected';
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;
END
$$;

ROLLBACK;

SELECT 'constraint behavior tests passed' AS result;
