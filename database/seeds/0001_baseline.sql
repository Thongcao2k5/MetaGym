\set ON_ERROR_STOP on

-- Required psql variables:
-- admin_id, admin_email, admin_password_hash, admin_full_name,
-- gym_name, gym_address

BEGIN;

INSERT INTO users (
  id,
  email,
  password_hash,
  role,
  full_name,
  status
)
VALUES (
  :'admin_id'::uuid,
  :'admin_email',
  :'admin_password_hash',
  'ADMIN',
  :'admin_full_name',
  'ACTIVE'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO gym_profile (
  id,
  name,
  address,
  opening_hours,
  updated_by
)
VALUES (
  1,
  :'gym_name',
  :'gym_address',
  '{}'::jsonb,
  :'admin_id'::uuid
)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    address = EXCLUDED.address,
    updated_by = EXCLUDED.updated_by;

COMMIT;

SELECT (
  (SELECT count(*) FROM users WHERE role = 'ADMIN') = 1
  AND EXISTS (
    SELECT 1
      FROM users
     WHERE id = :'admin_id'::uuid
       AND email = :'admin_email'::citext
       AND role = 'ADMIN'
       AND status = 'ACTIVE'
  )
  AND EXISTS (
    SELECT 1
      FROM gym_profile
     WHERE id = 1
       AND name <> ''
       AND address <> ''
  )
) AS baseline_seed_valid \gset

\if :baseline_seed_valid
  \echo 'baseline seed verified'
\else
  \echo 'baseline seed verification failed'
  \quit 1
\endif
