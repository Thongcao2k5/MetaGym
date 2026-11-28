BEGIN;

ALTER TABLE equipment
  ADD COLUMN IF NOT EXISTS icon_key varchar(60),
  ADD COLUMN IF NOT EXISTS icon_media_id uuid REFERENCES media_assets(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS ix_equipment_icon_media_id
  ON equipment (icon_media_id)
  WHERE icon_media_id IS NOT NULL;

COMMIT;
