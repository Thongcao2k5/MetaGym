BEGIN;

CREATE TABLE IF NOT EXISTS roles (
  id uuid PRIMARY KEY,
  code varchar(50) NOT NULL UNIQUE,
  name varchar(100) NOT NULL,
  permissions jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO roles (id, code, name, permissions)
VALUES
  ('00000000-0000-4000-8000-000000000101', 'super_admin', 'Super Administrator', '["*"]'::jsonb),
  ('00000000-0000-4000-8000-000000000102', 'admin', 'Administrator', '["images:*","albums:*","folders:*","tags:*","shares:*","api_keys:*","analytics:read"]'::jsonb),
  ('00000000-0000-4000-8000-000000000103', 'user', 'Standard User', '["images:read","images:write","albums:read","albums:write","folders:read","folders:write","tags:read","shares:read","shares:write"]'::jsonb)
ON CONFLICT (code) DO NOTHING;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS role_id uuid REFERENCES roles(id),
  ADD COLUMN IF NOT EXISTS storage_quota_bytes bigint NOT NULL DEFAULT 1073741824 CHECK (storage_quota_bytes >= 0),
  ADD COLUMN IF NOT EXISTS storage_used_bytes bigint NOT NULL DEFAULT 0 CHECK (storage_used_bytes >= 0),
  ADD COLUMN IF NOT EXISTS is_locked boolean NOT NULL DEFAULT false;

UPDATE users
   SET role_id = CASE
         WHEN role = 'ADMIN' THEN '00000000-0000-4000-8000-000000000101'::uuid
         ELSE '00000000-0000-4000-8000-000000000103'::uuid
       END,
       is_locked = (status = 'DISABLED')
 WHERE role_id IS NULL;

CREATE TABLE IF NOT EXISTS storage_providers (
  id uuid PRIMARY KEY,
  name varchar(100) NOT NULL,
  type varchar(30) NOT NULL CHECK (type IN ('local', 'supabase', 's3', 'r2', 'minio')),
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_default boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  health_status varchar(30) NOT NULL DEFAULT 'unknown',
  last_checked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO storage_providers (id, name, type, config, is_default, is_active, health_status)
VALUES
  ('00000000-0000-4000-8000-000000000201', 'Local Filesystem Storage', 'local', '{"basePath":"uploads/media"}'::jsonb, false, true, 'healthy'),
  ('00000000-0000-4000-8000-000000000202', 'Supabase Storage Bucket', 'supabase', '{"bucketEnv":"SUPABASE_STORAGE_BUCKET"}'::jsonb, true, true, 'unknown'),
  ('00000000-0000-4000-8000-000000000203', 'S3 / Cloudflare R2 / MinIO', 's3', '{"region":"auto"}'::jsonb, false, false, 'unknown')
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS folders (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES folders(id) ON DELETE CASCADE,
  name varchar(150) NOT NULL,
  slug varchar(180) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_folders_owner_parent_name_active
  ON folders (owner_id, COALESCE(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name))
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_folders_owner_parent
  ON folders (owner_id, parent_id)
  WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS images (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  folder_id uuid REFERENCES folders(id) ON DELETE SET NULL,
  storage_provider_id uuid NOT NULL REFERENCES storage_providers(id),
  filename varchar(255) NOT NULL,
  original_filename varchar(255) NOT NULL,
  storage_key varchar(500) NOT NULL UNIQUE,
  extension varchar(20) NOT NULL,
  mime_type varchar(100) NOT NULL,
  size_bytes bigint NOT NULL CHECK (size_bytes >= 0),
  width integer CHECK (width IS NULL OR width > 0),
  height integer CHECK (height IS NULL OR height > 0),
  sha256_hash char(64) NOT NULL,
  exif_data jsonb,
  description text,
  visibility varchar(20) NOT NULL DEFAULT 'private' CHECK (visibility IN ('public', 'private')),
  view_count bigint NOT NULL DEFAULT 0 CHECK (view_count >= 0),
  download_count bigint NOT NULL DEFAULT 0 CHECK (download_count >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE INDEX IF NOT EXISTS ix_images_owner_created ON images (owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS ix_images_mime_type ON images (mime_type);
CREATE INDEX IF NOT EXISTS ix_images_sha256_hash ON images (sha256_hash);
CREATE INDEX IF NOT EXISTS ix_images_folder_id ON images (folder_id);
CREATE INDEX IF NOT EXISTS ix_images_visibility ON images (visibility) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS image_variants (
  id uuid PRIMARY KEY,
  image_id uuid NOT NULL REFERENCES images(id) ON DELETE CASCADE,
  variant_type varchar(40) NOT NULL CHECK (variant_type IN ('thumbnail', 'webp', 'avif', 'edited', 'custom')),
  label varchar(100),
  storage_key varchar(500) NOT NULL UNIQUE,
  extension varchar(20) NOT NULL,
  mime_type varchar(100) NOT NULL,
  size_bytes bigint NOT NULL CHECK (size_bytes >= 0),
  width integer CHECK (width IS NULL OR width > 0),
  height integer CHECK (height IS NULL OR height > 0),
  transform_params jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_image_variants_image_type ON image_variants (image_id, variant_type);

CREATE TABLE IF NOT EXISTS albums (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title varchar(180) NOT NULL,
  description text,
  cover_image_id uuid REFERENCES images(id) ON DELETE SET NULL,
  visibility varchar(20) NOT NULL DEFAULT 'private' CHECK (visibility IN ('public', 'private')),
  share_slug varchar(100) UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE INDEX IF NOT EXISTS ix_albums_owner_created ON albums (owner_id, created_at DESC) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS album_images (
  album_id uuid NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
  image_id uuid NOT NULL REFERENCES images(id) ON DELETE CASCADE,
  sort_order integer NOT NULL DEFAULT 0,
  added_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (album_id, image_id)
);

CREATE TABLE IF NOT EXISTS tags (
  id uuid PRIMARY KEY,
  name varchar(80) NOT NULL,
  slug varchar(100) NOT NULL UNIQUE,
  color varchar(20),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS image_tags (
  image_id uuid NOT NULL REFERENCES images(id) ON DELETE CASCADE,
  tag_id uuid NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (image_id, tag_id)
);

CREATE TRIGGER trg_roles_updated_at
  BEFORE UPDATE ON roles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_storage_providers_updated_at
  BEFORE UPDATE ON storage_providers
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_folders_updated_at
  BEFORE UPDATE ON folders
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_images_updated_at
  BEFORE UPDATE ON images
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_image_variants_updated_at
  BEFORE UPDATE ON image_variants
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_albums_updated_at
  BEFORE UPDATE ON albums
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_tags_updated_at
  BEFORE UPDATE ON tags
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
