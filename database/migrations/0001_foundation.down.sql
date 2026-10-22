BEGIN;

DROP TABLE IF EXISTS member_memberships;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS membership_plans;
DROP TABLE IF EXISTS password_reset_codes;
DROP TABLE IF EXISTS coach_profiles;
DROP TABLE IF EXISTS member_profiles;
DROP TABLE IF EXISTS users;
DROP FUNCTION IF EXISTS set_updated_at();

DROP EXTENSION IF EXISTS btree_gist;
DROP EXTENSION IF EXISTS citext;

COMMIT;
