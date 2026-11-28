BEGIN;

DROP INDEX IF EXISTS ix_equipment_icon_media_id;

ALTER TABLE equipment
  DROP COLUMN IF EXISTS icon_media_id,
  DROP COLUMN IF EXISTS icon_key;

COMMIT;
