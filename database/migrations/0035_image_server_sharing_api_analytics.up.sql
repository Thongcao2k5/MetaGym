BEGIN;

CREATE TABLE IF NOT EXISTS share_links (
  id uuid PRIMARY KEY,
  created_by uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_type varchar(20) NOT NULL CHECK (target_type IN ('image', 'album')),
  image_id uuid REFERENCES images(id) ON DELETE CASCADE,
  album_id uuid REFERENCES albums(id) ON DELETE CASCADE,
  token varchar(128) NOT NULL UNIQUE,
  password_hash varchar(255),
  allow_download boolean NOT NULL DEFAULT true,
  expires_at timestamptz,
  revoked_at timestamptz,
  access_count bigint NOT NULL DEFAULT 0 CHECK (access_count >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_share_links_target CHECK (
    (target_type = 'image' AND image_id IS NOT NULL AND album_id IS NULL)
    OR
    (target_type = 'album' AND album_id IS NOT NULL AND image_id IS NULL)
  )
);

CREATE INDEX IF NOT EXISTS ix_share_links_token ON share_links (token);
CREATE INDEX IF NOT EXISTS ix_share_links_created_by ON share_links (created_by, created_at DESC);
CREATE INDEX IF NOT EXISTS ix_share_links_expires_at ON share_links (expires_at);

CREATE TABLE IF NOT EXISTS api_keys (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name varchar(120) NOT NULL,
  key_prefix varchar(16) NOT NULL,
  key_hash char(64) NOT NULL UNIQUE,
  scopes jsonb NOT NULL DEFAULT '["images:read"]'::jsonb,
  rate_limit_per_minute integer NOT NULL DEFAULT 60 CHECK (rate_limit_per_minute > 0),
  request_count bigint NOT NULL DEFAULT 0 CHECK (request_count >= 0),
  last_used_at timestamptz,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_api_keys_user_created ON api_keys (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS api_logs (
  id bigserial PRIMARY KEY,
  api_key_id uuid REFERENCES api_keys(id) ON DELETE SET NULL,
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  method varchar(10) NOT NULL,
  endpoint varchar(255) NOT NULL,
  status_code smallint NOT NULL,
  response_time_ms integer,
  bytes_transferred bigint NOT NULL DEFAULT 0,
  ip_address inet,
  user_agent text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_api_logs_created_desc ON api_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS ix_api_logs_key_created ON api_logs (api_key_id, created_at DESC);
CREATE INDEX IF NOT EXISTS ix_api_logs_status_code ON api_logs (status_code);

CREATE TABLE IF NOT EXISTS image_views (
  id bigserial PRIMARY KEY,
  image_id uuid NOT NULL REFERENCES images(id) ON DELETE CASCADE,
  event_type varchar(20) NOT NULL DEFAULT 'view' CHECK (event_type IN ('view', 'download')),
  is_bot boolean NOT NULL DEFAULT false,
  referer text,
  ip_hash char(64),
  user_agent text,
  bytes_served bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_image_views_image_created ON image_views (image_id, created_at DESC);
CREATE INDEX IF NOT EXISTS ix_image_views_created_bot ON image_views (created_at DESC, is_bot);

CREATE TABLE IF NOT EXISTS system_settings (
  key varchar(100) PRIMARY KEY,
  value jsonb NOT NULL,
  updated_by uuid REFERENCES users(id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO system_settings (key, value)
VALUES
  ('site_branding', '{"siteName":"Meta Gym Image Server","logoUrl":"","faviconUrl":""}'::jsonb),
  ('upload_limits', '{"maxFileSizeMb":10,"maxFilesPerUpload":20,"allowedFormats":["jpeg","png","webp","avif","gif","svg"],"defaultVisibility":"private","allowUrlImport":true}'::jsonb),
  ('image_processing', '{"thumbnailSize":400,"autoWebp":false,"autoAvif":false,"defaultQuality":82,"stripGpsExif":false}'::jsonb),
  ('smtp', '{"enabled":false,"host":"","port":587,"secure":false,"fromEmail":""}'::jsonb),
  ('rate_limits', '{"publicApiPerMinute":60,"uploadPerMinute":30}'::jsonb),
  ('maintenance_mode', '{"enabled":false,"message":"Hệ thống đang bảo trì định kỳ, vui lòng quay lại sau."}'::jsonb),
  ('backup_policy', '{"autoBackupEnabled":false,"retentionDays":30}'::jsonb)
ON CONFLICT (key) DO NOTHING;

CREATE TRIGGER trg_share_links_updated_at
  BEFORE UPDATE ON share_links
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_api_keys_updated_at
  BEFORE UPDATE ON api_keys
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_system_settings_updated_at
  BEFORE UPDATE ON system_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
