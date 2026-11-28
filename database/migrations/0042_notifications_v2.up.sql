BEGIN;

ALTER TABLE coach_notifications
  ALTER COLUMN subject_id DROP NOT NULL;

ALTER TABLE coach_notifications
  ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'COACH'
    CHECK (category IN ('COACH', 'TRAINING', 'MESSAGE', 'SYSTEM')),
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS body text,
  ADD COLUMN IF NOT EXISTS action_route text,
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS ix_coach_notifications_user_unread
  ON coach_notifications (user_id, id DESC)
  WHERE read_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_coach_notifications_user_cat
  ON coach_notifications (user_id, category, id DESC);

CREATE TABLE IF NOT EXISTS user_device_tokens (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token text NOT NULL UNIQUE,
  platform text NOT NULL CHECK (platform IN ('ANDROID', 'IOS', 'WEB')),
  device_label text,
  is_active boolean NOT NULL DEFAULT true,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_user_device_tokens_user_active
  ON user_device_tokens (user_id)
  WHERE is_active;

CREATE TABLE IF NOT EXISTS user_notification_preferences (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  workout_reminders_enabled boolean NOT NULL DEFAULT true,
  reminder_time text NOT NULL DEFAULT '17:30'
    CHECK (reminder_time ~ '^([01]\d|2[0-3]):[0-5]\d$'),
  pt_before_minutes integer NOT NULL DEFAULT 30
    CHECK (pt_before_minutes IN (0, 15, 30, 60)),
  nutrition_reminders_enabled boolean NOT NULL DEFAULT true,
  coach_updates_enabled boolean NOT NULL DEFAULT true,
  messages_enabled boolean NOT NULL DEFAULT true,
  calls_enabled boolean NOT NULL DEFAULT true,
  admin_broadcasts_enabled boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS admin_notification_broadcasts (
  id uuid PRIMARY KEY,
  admin_id uuid NOT NULL REFERENCES users(id),
  title text NOT NULL,
  body text NOT NULL,
  audience text NOT NULL CHECK (audience IN ('ALL', 'MEMBER', 'COACH')),
  action_route text,
  recipient_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMIT;
