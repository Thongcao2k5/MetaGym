BEGIN;

DROP TRIGGER IF EXISTS trg_tags_updated_at ON tags;
DROP TRIGGER IF EXISTS trg_albums_updated_at ON albums;
DROP TRIGGER IF EXISTS trg_image_variants_updated_at ON image_variants;
DROP TRIGGER IF EXISTS trg_images_updated_at ON images;
DROP TRIGGER IF EXISTS trg_folders_updated_at ON folders;
DROP TRIGGER IF EXISTS trg_storage_providers_updated_at ON storage_providers;
DROP TRIGGER IF EXISTS trg_roles_updated_at ON roles;

DROP TABLE IF EXISTS image_tags;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS album_images;
DROP TABLE IF EXISTS albums;
DROP TABLE IF EXISTS image_variants;
DROP TABLE IF EXISTS images;
DROP TABLE IF EXISTS folders;
DROP TABLE IF EXISTS storage_providers;

ALTER TABLE users
  DROP COLUMN IF EXISTS is_locked,
  DROP COLUMN IF EXISTS storage_used_bytes,
  DROP COLUMN IF EXISTS storage_quota_bytes,
  DROP COLUMN IF EXISTS role_id;

DROP TABLE IF EXISTS roles;

COMMIT;
