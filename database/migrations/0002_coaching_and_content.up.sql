BEGIN;

CREATE TABLE coach_requests (
  id uuid PRIMARY KEY,
  member_id uuid NOT NULL REFERENCES users(id),
  coach_id uuid NOT NULL REFERENCES users(id),
  message text,
  status varchar(20) NOT NULL DEFAULT 'PENDING'
    CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'CANCELLED')),
  rejection_reason text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_coach_requests_identity UNIQUE (id, member_id, coach_id),
  CONSTRAINT ck_coach_request_distinct_users CHECK (member_id <> coach_id),
  CONSTRAINT ck_coach_request_state_details CHECK (
    (status = 'PENDING' AND decided_at IS NULL AND rejection_reason IS NULL)
    OR
    (status = 'REJECTED' AND decided_at IS NOT NULL AND rejection_reason IS NOT NULL)
    OR
    (status IN ('ACCEPTED', 'CANCELLED') AND decided_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX uq_coach_requests_pending_member
  ON coach_requests (member_id)
  WHERE status = 'PENDING';
CREATE INDEX ix_coach_requests_coach_pending
  ON coach_requests (coach_id, requested_at DESC)
  WHERE status = 'PENDING';

CREATE TABLE coach_relationships (
  id uuid PRIMARY KEY,
  member_id uuid NOT NULL REFERENCES users(id),
  coach_id uuid NOT NULL REFERENCES users(id),
  source_request_id uuid,
  status varchar(20) NOT NULL DEFAULT 'ACTIVE'
    CHECK (status IN ('ACTIVE', 'PAUSED', 'ENDED')),
  started_at timestamptz NOT NULL DEFAULT now(),
  paused_at timestamptz,
  pause_reason varchar(30) CHECK (pause_reason IN ('MEMBERSHIP_EXPIRED')),
  ended_at timestamptz,
  ended_by uuid REFERENCES users(id),
  end_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_relationship_identity UNIQUE (id, member_id, coach_id),
  CONSTRAINT uq_relationship_member UNIQUE (id, member_id),
  CONSTRAINT uq_relationship_coach UNIQUE (id, coach_id),
  CONSTRAINT uq_relationship_source_request UNIQUE (source_request_id),
  CONSTRAINT fk_relationship_source_request
    FOREIGN KEY (source_request_id, member_id, coach_id)
    REFERENCES coach_requests(id, member_id, coach_id),
  CONSTRAINT ck_relationship_distinct_users CHECK (member_id <> coach_id),
  CONSTRAINT ck_relationship_state_details CHECK (
    (status = 'ACTIVE'
      AND paused_at IS NULL AND pause_reason IS NULL
      AND ended_at IS NULL AND ended_by IS NULL AND end_reason IS NULL)
    OR
    (status = 'PAUSED'
      AND paused_at IS NOT NULL AND pause_reason IS NOT NULL
      AND ended_at IS NULL AND ended_by IS NULL AND end_reason IS NULL)
    OR
    (status = 'ENDED'
      AND ended_at IS NOT NULL AND ended_by IS NOT NULL AND end_reason IS NOT NULL)
  )
);

CREATE UNIQUE INDEX uq_relationship_current_member
  ON coach_relationships (member_id)
  WHERE status IN ('ACTIVE', 'PAUSED');
CREATE INDEX ix_relationships_coach_status
  ON coach_relationships (coach_id, status);

CREATE TABLE coach_termination_requests (
  id uuid PRIMARY KEY,
  relationship_id uuid NOT NULL,
  coach_id uuid NOT NULL REFERENCES users(id),
  reason text NOT NULL,
  status varchar(20) NOT NULL DEFAULT 'PENDING'
    CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED')),
  admin_note text,
  decided_by uuid REFERENCES users(id),
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_termination_relationship_coach
    FOREIGN KEY (relationship_id, coach_id)
    REFERENCES coach_relationships(id, coach_id),
  CONSTRAINT ck_termination_state_details CHECK (
    (status = 'PENDING' AND decided_by IS NULL AND decided_at IS NULL)
    OR
    (status IN ('APPROVED', 'REJECTED')
      AND decided_by IS NOT NULL AND decided_at IS NOT NULL)
    OR
    (status = 'CANCELLED' AND decided_by IS NULL AND decided_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX uq_termination_pending_relationship
  ON coach_termination_requests (relationship_id)
  WHERE status = 'PENDING';
CREATE INDEX ix_termination_pending_created
  ON coach_termination_requests (created_at DESC)
  WHERE status = 'PENDING';

CREATE TABLE coach_transfer_history (
  id uuid PRIMARY KEY,
  member_id uuid NOT NULL REFERENCES users(id),
  old_relationship_id uuid NOT NULL,
  new_relationship_id uuid NOT NULL,
  old_coach_id uuid NOT NULL REFERENCES users(id),
  new_coach_id uuid NOT NULL REFERENCES users(id),
  reason text NOT NULL,
  admin_id uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_transfer_old_relationship
    FOREIGN KEY (old_relationship_id, member_id, old_coach_id)
    REFERENCES coach_relationships(id, member_id, coach_id),
  CONSTRAINT fk_transfer_new_relationship
    FOREIGN KEY (new_relationship_id, member_id, new_coach_id)
    REFERENCES coach_relationships(id, member_id, coach_id),
  CONSTRAINT ck_transfer_relationships_differ
    CHECK (old_relationship_id <> new_relationship_id),
  CONSTRAINT ck_transfer_coaches_differ
    CHECK (old_coach_id <> new_coach_id)
);

CREATE INDEX ix_transfer_member_created
  ON coach_transfer_history (member_id, created_at DESC);

CREATE TABLE media_assets (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES users(id),
  purpose varchar(30) NOT NULL
    CHECK (purpose IN ('AVATAR', 'MESSAGE', 'PROGRESS_PHOTO', 'MEAL_PHOTO', 'EQUIPMENT', 'GYM')),
  access_scope varchar(20) NOT NULL CHECK (access_scope IN ('PUBLIC', 'PRIVATE')),
  storage_key text NOT NULL UNIQUE,
  original_name varchar(255) NOT NULL,
  mime_type varchar(100),
  size_bytes bigint CHECK (size_bytes > 0),
  width integer CHECK (width > 0),
  height integer CHECK (height > 0),
  status varchar(20) NOT NULL DEFAULT 'UPLOADING'
    CHECK (status IN ('UPLOADING', 'READY', 'FAILED', 'DELETED')),
  expires_at timestamptz NOT NULL,
  ready_at timestamptz,
  failed_at timestamptz,
  failure_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT uq_media_owner UNIQUE (id, owner_id),
  CONSTRAINT ck_media_expiry CHECK (expires_at > created_at),
  CONSTRAINT ck_media_state_details CHECK (
    (status = 'UPLOADING'
      AND ready_at IS NULL AND failed_at IS NULL AND deleted_at IS NULL)
    OR
    (status = 'READY'
      AND mime_type IS NOT NULL AND size_bytes IS NOT NULL
      AND width IS NOT NULL AND height IS NOT NULL
      AND ready_at IS NOT NULL AND failed_at IS NULL AND deleted_at IS NULL)
    OR
    (status = 'FAILED'
      AND failed_at IS NOT NULL AND failure_reason IS NOT NULL
      AND ready_at IS NULL AND deleted_at IS NULL)
    OR
    (status = 'DELETED' AND deleted_at IS NOT NULL)
  )
);

CREATE INDEX ix_media_upload_expiry
  ON media_assets (expires_at)
  WHERE status = 'UPLOADING';
CREATE INDEX ix_media_cleanup
  ON media_assets (status, created_at)
  WHERE status IN ('FAILED', 'DELETED');

ALTER TABLE users
  ADD CONSTRAINT fk_users_avatar_owner
  FOREIGN KEY (avatar_media_id, id)
  REFERENCES media_assets(id, owner_id);

CREATE TABLE gym_profile (
  id smallint PRIMARY KEY CHECK (id = 1),
  name varchar(150) NOT NULL,
  address text NOT NULL,
  phone varchar(20),
  email citext,
  description text,
  opening_hours jsonb NOT NULL CHECK (jsonb_typeof(opening_hours) = 'object'),
  rules text,
  cover_media_id uuid REFERENCES media_assets(id),
  updated_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE equipment (
  id uuid PRIMARY KEY,
  name varchar(120) NOT NULL,
  category varchar(80) NOT NULL,
  target_muscles text[] NOT NULL DEFAULT '{}',
  image_media_id uuid REFERENCES media_assets(id),
  description text,
  usage_steps jsonb NOT NULL
    CHECK (jsonb_typeof(usage_steps) = 'array' AND jsonb_array_length(usage_steps) > 0),
  safety_notes text,
  video_url text,
  status varchar(20) NOT NULL CHECK (status IN ('ACTIVE', 'HIDDEN')),
  created_by uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_equipment_status_category ON equipment (status, category);
CREATE INDEX ix_equipment_name_lower ON equipment (lower(name));

CREATE TABLE exercises (
  id uuid PRIMARY KEY,
  equipment_id uuid REFERENCES equipment(id),
  name varchar(120) NOT NULL,
  description text,
  target_muscles text[] NOT NULL DEFAULT '{}',
  instructions text NOT NULL,
  safety_notes text,
  difficulty varchar(20)
    CHECK (difficulty IN ('BEGINNER', 'INTERMEDIATE', 'ADVANCED')),
  video_url text,
  status varchar(20) NOT NULL CHECK (status IN ('ACTIVE', 'HIDDEN')),
  created_by uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_exercises_status ON exercises (status);
CREATE INDEX ix_exercises_name_lower ON exercises (lower(name));

CREATE TRIGGER trg_coach_requests_updated_at
  BEFORE UPDATE ON coach_requests
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_coach_relationships_updated_at
  BEFORE UPDATE ON coach_relationships
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_coach_termination_requests_updated_at
  BEFORE UPDATE ON coach_termination_requests
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_gym_profile_updated_at
  BEFORE UPDATE ON gym_profile
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_equipment_updated_at
  BEFORE UPDATE ON equipment
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_exercises_updated_at
  BEFORE UPDATE ON exercises
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
