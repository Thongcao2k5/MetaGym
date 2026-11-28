BEGIN;

DROP TRIGGER IF EXISTS trg_staff_profiles_updated_at ON staff_profiles;
DROP TABLE IF EXISTS staff_profiles;

DELETE FROM users WHERE role = 'STAFF';

ALTER TABLE users
  DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE users
  ADD CONSTRAINT users_role_check
  CHECK (role IN ('MEMBER', 'COACH', 'ADMIN'));

UPDATE users
   SET role_id = '00000000-0000-4000-8000-000000000103'::uuid
 WHERE role = 'COACH';

DELETE FROM roles
 WHERE code IN ('manager', 'receptionist', 'coach', 'technician');

COMMIT;
