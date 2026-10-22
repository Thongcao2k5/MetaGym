BEGIN;

CREATE TABLE conversations (
  id uuid PRIMARY KEY,
  relationship_id uuid NOT NULL UNIQUE REFERENCES coach_relationships(id),
  last_message_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE conversation_participants (
  conversation_id uuid NOT NULL REFERENCES conversations(id),
  user_id uuid NOT NULL REFERENCES users(id),
  last_read_message_id uuid,
  last_read_at timestamptz,
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, user_id)
);

CREATE TABLE messages (
  id uuid PRIMARY KEY,
  conversation_id uuid NOT NULL REFERENCES conversations(id),
  sender_id uuid NOT NULL REFERENCES users(id),
  client_message_id uuid NOT NULL,
  message_type varchar(20) NOT NULL CHECK (message_type IN ('TEXT', 'IMAGE')),
  content text,
  media_id uuid,
  sent_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_messages_sender_client UNIQUE (sender_id, client_message_id),
  CONSTRAINT uq_messages_conversation_identity UNIQUE (id, conversation_id),
  CONSTRAINT fk_message_sender_participant
    FOREIGN KEY (conversation_id, sender_id)
    REFERENCES conversation_participants(conversation_id, user_id),
  CONSTRAINT fk_message_media_owner
    FOREIGN KEY (media_id, sender_id)
    REFERENCES media_assets(id, owner_id),
  CONSTRAINT ck_message_payload CHECK (
    (message_type = 'TEXT' AND content IS NOT NULL AND media_id IS NULL)
    OR
    (message_type = 'IMAGE' AND media_id IS NOT NULL)
  )
);

CREATE INDEX ix_messages_conversation_page
  ON messages (conversation_id, sent_at DESC, id);

ALTER TABLE conversation_participants
  ADD CONSTRAINT fk_participant_read_cursor
  FOREIGN KEY (last_read_message_id, conversation_id)
  REFERENCES messages(id, conversation_id);

CREATE TABLE call_logs (
  id uuid PRIMARY KEY,
  relationship_id uuid NOT NULL REFERENCES coach_relationships(id),
  provider_call_id varchar(150) UNIQUE,
  caller_id uuid NOT NULL REFERENCES users(id),
  receiver_id uuid NOT NULL REFERENCES users(id),
  call_type varchar(20) NOT NULL CHECK (call_type IN ('VOICE', 'VIDEO')),
  status varchar(20) NOT NULL DEFAULT 'CREATED'
    CHECK (status IN ('CREATED', 'RINGING', 'ANSWERED', 'REJECTED', 'MISSED', 'ENDED', 'FAILED')),
  initiated_at timestamptz NOT NULL DEFAULT now(),
  answered_at timestamptz,
  ended_at timestamptz,
  duration_seconds integer NOT NULL DEFAULT 0 CHECK (duration_seconds >= 0),
  failure_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_call_distinct_users CHECK (caller_id <> receiver_id),
  CONSTRAINT ck_call_timestamp_order CHECK (
    (answered_at IS NULL OR answered_at >= initiated_at)
    AND (ended_at IS NULL OR ended_at >= initiated_at)
    AND (answered_at IS NULL OR ended_at IS NULL OR ended_at >= answered_at)
  ),
  CONSTRAINT ck_call_state_details CHECK (
    (status IN ('CREATED', 'RINGING')
      AND answered_at IS NULL AND ended_at IS NULL AND failure_reason IS NULL)
    OR
    (status = 'ANSWERED'
      AND answered_at IS NOT NULL AND ended_at IS NULL AND failure_reason IS NULL)
    OR
    (status IN ('REJECTED', 'MISSED')
      AND answered_at IS NULL AND ended_at IS NOT NULL AND failure_reason IS NULL)
    OR
    (status = 'ENDED' AND ended_at IS NOT NULL AND failure_reason IS NULL)
    OR
    (status = 'FAILED' AND ended_at IS NOT NULL AND failure_reason IS NOT NULL)
  )
);

CREATE INDEX ix_calls_caller_started ON call_logs (caller_id, initiated_at DESC);
CREATE INDEX ix_calls_receiver_started ON call_logs (receiver_id, initiated_at DESC);

CREATE TABLE ai_conversations (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  title varchar(150) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE INDEX ix_ai_conversations_owner_active
  ON ai_conversations (user_id, updated_at DESC)
  WHERE deleted_at IS NULL;

CREATE TABLE ai_messages (
  id uuid PRIMARY KEY,
  conversation_id uuid NOT NULL REFERENCES ai_conversations(id),
  role varchar(20) NOT NULL CHECK (role IN ('USER', 'ASSISTANT')),
  content text NOT NULL,
  client_request_id uuid,
  request_hash varchar(64),
  reply_to_message_id uuid,
  status varchar(20) NOT NULL CHECK (status IN ('PROCESSING', 'COMPLETED', 'FAILED')),
  provider varchar(50),
  model_name varchar(100),
  provider_request_id varchar(150),
  input_tokens integer CHECK (input_tokens >= 0),
  output_tokens integer CHECK (output_tokens >= 0),
  safety_category varchar(50),
  completed_at timestamptz,
  failed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_ai_message_conversation_identity UNIQUE (id, conversation_id),
  CONSTRAINT uq_ai_reply_target UNIQUE (reply_to_message_id),
  CONSTRAINT ck_ai_message_shape CHECK (
    (role = 'USER'
      AND client_request_id IS NOT NULL
      AND request_hash ~ '^[0-9a-f]{64}$'
      AND reply_to_message_id IS NULL)
    OR
    (role = 'ASSISTANT'
      AND client_request_id IS NULL AND request_hash IS NULL
      AND reply_to_message_id IS NOT NULL AND status = 'COMPLETED')
  ),
  CONSTRAINT ck_ai_message_state_details CHECK (
    (status = 'PROCESSING' AND completed_at IS NULL AND failed_at IS NULL)
    OR
    (status = 'COMPLETED' AND completed_at IS NOT NULL AND failed_at IS NULL)
    OR
    (status = 'FAILED' AND completed_at IS NULL AND failed_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX uq_ai_user_request
  ON ai_messages (conversation_id, client_request_id)
  WHERE role = 'USER';
CREATE INDEX ix_ai_messages_conversation_page
  ON ai_messages (conversation_id, created_at, id);

ALTER TABLE ai_messages
  ADD CONSTRAINT fk_ai_reply_conversation
  FOREIGN KEY (reply_to_message_id, conversation_id)
  REFERENCES ai_messages(id, conversation_id);

CREATE TABLE admin_audit_logs (
  id uuid PRIMARY KEY,
  admin_id uuid NOT NULL REFERENCES users(id),
  action varchar(80) NOT NULL,
  entity_type varchar(50) NOT NULL,
  entity_id text NOT NULL,
  summary text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_audit_admin_created
  ON admin_audit_logs (admin_id, created_at DESC);
CREATE INDEX ix_audit_entity_created
  ON admin_audit_logs (entity_type, entity_id, created_at DESC);

CREATE TRIGGER trg_conversations_updated_at
  BEFORE UPDATE ON conversations
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_call_logs_updated_at
  BEFORE UPDATE ON call_logs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_ai_conversations_updated_at
  BEFORE UPDATE ON ai_conversations
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
