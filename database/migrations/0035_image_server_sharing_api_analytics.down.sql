BEGIN;

DROP TRIGGER IF EXISTS trg_system_settings_updated_at ON system_settings;
DROP TRIGGER IF EXISTS trg_api_keys_updated_at ON api_keys;
DROP TRIGGER IF EXISTS trg_share_links_updated_at ON share_links;

DROP TABLE IF EXISTS system_settings;
DROP TABLE IF EXISTS image_views;
DROP TABLE IF EXISTS api_logs;
DROP TABLE IF EXISTS api_keys;
DROP TABLE IF EXISTS share_links;

COMMIT;
