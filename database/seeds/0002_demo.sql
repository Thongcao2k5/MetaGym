\set ON_ERROR_STOP on

-- Development/test only. Never run this seed in production.
-- Demo credentials are documented in database/README.md.

\if :{?demo_seed_environment}
\else
  DO $$
  BEGIN
    RAISE EXCEPTION 'demo_seed_environment is required (development or test)';
  END
  $$;
\endif

SELECT :'demo_seed_environment' IN ('development', 'test') AS demo_seed_allowed
\gset

\if :demo_seed_allowed
\else
  DO $$
  BEGIN
    RAISE EXCEPTION 'refusing to run demo seed outside development/test';
  END
  $$;
\endif

BEGIN;

SELECT id AS demo_admin_id
  FROM users
 WHERE role = 'ADMIN'
\gset

UPDATE users
   SET email = 'admin@metagym.local',
       password_hash = '$2b$12$3dIkiUqhgvkQb8thSXKTCeHbA3bdSf8VFRR8RW5dVBQQaIlsMj19u',
       full_name = 'Meta Gym Admin Demo',
       phone = NULL,
       status = 'ACTIVE',
       session_version = CASE
         WHEN password_hash <> '$2b$12$3dIkiUqhgvkQb8thSXKTCeHbA3bdSf8VFRR8RW5dVBQQaIlsMj19u'
           THEN session_version + 1
         ELSE session_version
       END,
       disabled_at = NULL,
       disabled_reason = NULL,
       last_login_at = NULL
 WHERE id = :'demo_admin_id'::uuid;

INSERT INTO users (
  id,
  email,
  password_hash,
  role,
  full_name,
  phone,
  status,
  session_version
)
VALUES
  (
    '10000000-0000-4000-8000-000000000002'::uuid,
    'coach@metagym.local',
    '$2b$12$X9TF4BAse3o0Q6594pZHlu1nyt7UdFpSgAcg3f7GZRWpJlcMdeyeG',
    'COACH',
    'Coach Demo',
    '0900000002',
    'ACTIVE',
    0
  ),
  (
    '10000000-0000-4000-8000-000000000003'::uuid,
    'member@metagym.local',
    '$2b$12$x4gF0BjY7gS0/KT3YBgIfuho0EJobzGMJ6HmgGSZKGrYO6vE5BWbK',
    'MEMBER',
    'Member Demo',
    '0900000003',
    'ACTIVE',
    0
  )
ON CONFLICT (id) DO UPDATE
SET email = EXCLUDED.email,
    password_hash = EXCLUDED.password_hash,
    role = EXCLUDED.role,
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    status = 'ACTIVE',
    session_version = CASE
      WHEN users.password_hash <> EXCLUDED.password_hash
        THEN users.session_version + 1
      ELSE users.session_version
    END,
    disabled_at = NULL,
    disabled_reason = NULL,
    last_login_at = NULL;

INSERT INTO coach_profiles (
  user_id,
  biography,
  specialties,
  qualifications,
  experience_years,
  availability_note,
  member_limit
)
VALUES (
  '10000000-0000-4000-8000-000000000002'::uuid,
  'Coach mẫu cho môi trường phát triển và kiểm thử.',
  ARRAY['Tăng sức bền', 'Giảm mỡ'],
  'Chứng chỉ huấn luyện viên thể hình demo',
  5,
  'Thứ Hai đến Thứ Sáu, 08:00–18:00',
  10
)
ON CONFLICT (user_id) DO UPDATE
SET biography = EXCLUDED.biography,
    specialties = EXCLUDED.specialties,
    qualifications = EXCLUDED.qualifications,
    experience_years = EXCLUDED.experience_years,
    availability_note = EXCLUDED.availability_note,
    member_limit = EXCLUDED.member_limit;

INSERT INTO member_profiles (
  user_id,
  date_of_birth,
  gender,
  height_cm,
  fitness_goal,
  experience_level,
  activity_level,
  dietary_preferences
)
VALUES (
  '10000000-0000-4000-8000-000000000003'::uuid,
  DATE '2002-01-15',
  'PREFER_NOT_TO_SAY',
  168.00,
  'Cải thiện sức khỏe tổng thể',
  'BEGINNER',
  'MODERATE',
  'Không có yêu cầu đặc biệt'
)
ON CONFLICT (user_id) DO UPDATE
SET date_of_birth = EXCLUDED.date_of_birth,
    gender = EXCLUDED.gender,
    height_cm = EXCLUDED.height_cm,
    fitness_goal = EXCLUDED.fitness_goal,
    experience_level = EXCLUDED.experience_level,
    activity_level = EXCLUDED.activity_level,
    dietary_preferences = EXCLUDED.dietary_preferences;

INSERT INTO membership_plans (
  id,
  name,
  description,
  price,
  duration_days,
  status,
  created_by
)
VALUES (
  '20000000-0000-4000-8000-000000000001'::uuid,
  'Gói Demo 30 Ngày',
  'Gói mẫu dùng để trình diễn luồng mua gói và membership.',
  500000,
  30,
  'ACTIVE',
  :'demo_admin_id'::uuid
)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    price = EXCLUDED.price,
    duration_days = EXCLUDED.duration_days,
    status = EXCLUDED.status,
    created_by = EXCLUDED.created_by;

INSERT INTO equipment (
  id,
  name,
  category,
  target_muscles,
  description,
  usage_steps,
  safety_notes,
  status,
  created_by
)
VALUES (
  '30000000-0000-4000-8000-000000000001'::uuid,
  'Máy chạy bộ demo',
  'Cardio',
  ARRAY['Chân', 'Tim mạch'],
  'Thiết bị mẫu dùng trong môi trường phát triển.',
  '["Kiểm tra khóa an toàn", "Chọn tốc độ thấp", "Tăng tốc từ từ"]'::jsonb,
  'Dừng máy ngay nếu cảm thấy chóng mặt hoặc đau bất thường.',
  'ACTIVE',
  :'demo_admin_id'::uuid
)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    category = EXCLUDED.category,
    target_muscles = EXCLUDED.target_muscles,
    description = EXCLUDED.description,
    usage_steps = EXCLUDED.usage_steps,
    safety_notes = EXCLUDED.safety_notes,
    status = EXCLUDED.status,
    created_by = EXCLUDED.created_by;

INSERT INTO exercises (
  id,
  equipment_id,
  name,
  description,
  target_muscles,
  instructions,
  safety_notes,
  difficulty,
  status,
  created_by
)
VALUES (
  '40000000-0000-4000-8000-000000000001'::uuid,
  '30000000-0000-4000-8000-000000000001'::uuid,
  'Đi bộ khởi động demo',
  'Bài tập mẫu giúp làm nóng cơ thể trước buổi tập.',
  ARRAY['Chân', 'Tim mạch'],
  'Đi bộ 5–10 phút với tốc độ vừa phải, giữ thân người thẳng.',
  'Gắn khóa an toàn và không tăng tốc đột ngột.',
  'BEGINNER',
  'ACTIVE',
  :'demo_admin_id'::uuid
)
ON CONFLICT (id) DO UPDATE
SET equipment_id = EXCLUDED.equipment_id,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    target_muscles = EXCLUDED.target_muscles,
    instructions = EXCLUDED.instructions,
    safety_notes = EXCLUDED.safety_notes,
    difficulty = EXCLUDED.difficulty,
    status = EXCLUDED.status,
    created_by = EXCLUDED.created_by;

COMMIT;

\ir ../tests/demo_seed_assertions.sql
