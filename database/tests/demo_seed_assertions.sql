\set ON_ERROR_STOP on

DO $$
DECLARE
  demo_admin_id uuid;
BEGIN
  SELECT id
    INTO demo_admin_id
    FROM users
   WHERE email = 'admin@metagym.local'::citext
     AND role = 'ADMIN'
     AND status = 'ACTIVE';

  IF demo_admin_id IS NULL THEN
    RAISE EXCEPTION 'demo admin account is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM users u
      JOIN coach_profiles cp ON cp.user_id = u.id
     WHERE u.id = '10000000-0000-4000-8000-000000000002'::uuid
       AND u.email = 'coach@metagym.local'::citext
       AND u.role = 'COACH'
       AND u.status = 'ACTIVE'
       AND cp.member_limit = 10
  ) THEN
    RAISE EXCEPTION 'demo coach account/profile is missing or invalid';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM users u
      JOIN member_profiles mp ON mp.user_id = u.id
     WHERE u.id = '10000000-0000-4000-8000-000000000003'::uuid
       AND u.email = 'member@metagym.local'::citext
       AND u.role = 'MEMBER'
       AND u.status = 'ACTIVE'
       AND mp.experience_level = 'BEGINNER'
  ) THEN
    RAISE EXCEPTION 'demo member account/profile is missing or invalid';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM membership_plans
     WHERE id = '20000000-0000-4000-8000-000000000001'::uuid
       AND name = 'Gói Demo 30 Ngày'
       AND status = 'ACTIVE'
       AND created_by = demo_admin_id
  ) THEN
    RAISE EXCEPTION 'demo membership plan is missing or invalid';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM equipment
     WHERE id = '30000000-0000-4000-8000-000000000001'::uuid
       AND name = 'Máy chạy bộ demo'
       AND status = 'ACTIVE'
       AND created_by = demo_admin_id
  ) THEN
    RAISE EXCEPTION 'demo equipment is missing or invalid';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM exercises
     WHERE id = '40000000-0000-4000-8000-000000000001'::uuid
       AND equipment_id = '30000000-0000-4000-8000-000000000001'::uuid
       AND name = 'Đi bộ khởi động demo'
       AND status = 'ACTIVE'
       AND created_by = demo_admin_id
  ) THEN
    RAISE EXCEPTION 'demo exercise is missing or invalid';
  END IF;

  IF EXISTS (
    SELECT 1
      FROM users
     WHERE id IN (
       '10000000-0000-4000-8000-000000000002'::uuid,
       '10000000-0000-4000-8000-000000000003'::uuid
     )
     GROUP BY id
    HAVING count(*) <> 1
  ) THEN
    RAISE EXCEPTION 'demo user ids are duplicated';
  END IF;
END
$$;

SELECT 'demo seed assertions passed' AS result;
