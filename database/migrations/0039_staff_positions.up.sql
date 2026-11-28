BEGIN;

-- Expand users.role to support operational STAFF positions while preserving uq_users_single_admin
ALTER TABLE users
  DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE users
  ADD CONSTRAINT users_role_check
  CHECK (role IN ('MEMBER', 'COACH', 'ADMIN', 'STAFF'));

-- Upsert official MetaGym backoffice & coaching role templates in roles table (from 0034)
INSERT INTO roles (id, code, name, permissions)
VALUES
  (
    '00000000-0000-4000-8000-000000000101',
    'super_admin',
    'Quản trị viên (Admin)',
    '["*"]'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000104',
    'manager',
    'Quản lý vận hành / Trưởng ca (Manager)',
    '["dashboard:read","incidents:read","incidents:manage","disputes:read","disputes:manage","refunds:read","refunds:manage","payments:read","payments:frontdesk","payments:void","gym:read","gym:manage","members:read","members:manage","coaches:read","coaches:manage","relationships:read","relationships:manage","transfers:read","transfers:manage","plans:read","plans:manage","coach-packages:read","coach-packages:manage","staff:read","staff:manage","equipment:manage","foods:manage","media:read","media:manage","system:read","audit:read"]'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000105',
    'receptionist',
    'Lễ tân & Thu ngân (Receptionist)',
    '["dashboard:read","payments:read","payments:frontdesk","gym:read","members:read","members:manage","coaches:read","relationships:read","plans:read","coach-packages:read"]'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000106',
    'coach',
    'Huấn luyện viên (Coach)',
    '["mobile:coach"]'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000107',
    'technician',
    'Kỹ thuật viên & Nội dung (Technician)',
    '["gym:read","equipment:manage","foods:manage","media:read","media:manage","system:read"]'::jsonb
  )
ON CONFLICT (code) DO UPDATE
  SET name = EXCLUDED.name,
      permissions = EXCLUDED.permissions,
      updated_at = now();

CREATE TABLE IF NOT EXISTS staff_profiles (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  position_code varchar(30) NOT NULL
    CHECK (position_code IN ('MANAGER', 'RECEPTIONIST', 'TECHNICIAN')),
  department varchar(80) NOT NULL DEFAULT 'Vận hành',
  shift_note varchar(200),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_staff_profiles_position
  ON staff_profiles (position_code);

DROP TRIGGER IF EXISTS trg_staff_profiles_updated_at ON staff_profiles;
CREATE TRIGGER trg_staff_profiles_updated_at
  BEFORE UPDATE ON staff_profiles
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

UPDATE users
   SET role_id = '00000000-0000-4000-8000-000000000106'::uuid
 WHERE role = 'COACH';

REVOKE ALL ON staff_profiles FROM anon, authenticated;

COMMIT;
