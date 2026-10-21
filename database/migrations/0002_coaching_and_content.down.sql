BEGIN;

DROP TABLE IF EXISTS exercises;
DROP TABLE IF EXISTS equipment;
DROP TABLE IF EXISTS gym_profile;
ALTER TABLE users DROP CONSTRAINT IF EXISTS fk_users_avatar_owner;
DROP TABLE IF EXISTS media_assets;
DROP TABLE IF EXISTS coach_transfer_history;
DROP TABLE IF EXISTS coach_termination_requests;
DROP TABLE IF EXISTS coach_relationships;
DROP TABLE IF EXISTS coach_requests;

COMMIT;
