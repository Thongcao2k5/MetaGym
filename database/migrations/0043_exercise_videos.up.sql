BEGIN;

ALTER TABLE media_assets
  DROP CONSTRAINT IF EXISTS ck_media_state_details;

ALTER TABLE media_assets
  ADD CONSTRAINT ck_media_state_details CHECK (
    (status = 'UPLOADING'
      AND ready_at IS NULL AND failed_at IS NULL AND deleted_at IS NULL)
    OR
    (status = 'READY'
      AND mime_type IS NOT NULL AND size_bytes IS NOT NULL
      AND ((mime_type LIKE 'video/%') OR (width IS NOT NULL AND height IS NOT NULL))
      AND ready_at IS NOT NULL AND failed_at IS NULL AND deleted_at IS NULL)
    OR
    (status = 'FAILED'
      AND failed_at IS NOT NULL AND failure_reason IS NOT NULL
      AND ready_at IS NULL AND deleted_at IS NULL)
    OR
    (status = 'DELETED' AND deleted_at IS NOT NULL)
  );

ALTER TABLE exercises
  ADD COLUMN IF NOT EXISTS video_media_id uuid REFERENCES media_assets(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS ix_exercises_video_media_id
  ON exercises (video_media_id)
  WHERE video_media_id IS NOT NULL;

COMMIT;
