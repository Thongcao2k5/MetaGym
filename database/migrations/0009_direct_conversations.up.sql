BEGIN;

ALTER TABLE conversations ALTER COLUMN relationship_id DROP NOT NULL;
ALTER TABLE conversations ADD COLUMN member_id uuid REFERENCES users(id);
ALTER TABLE conversations ADD COLUMN coach_id uuid REFERENCES users(id);

UPDATE conversations c
SET member_id = r.member_id, coach_id = r.coach_id
FROM coach_relationships r
WHERE c.relationship_id = r.id;

ALTER TABLE conversations ADD CONSTRAINT ck_direct_conversation_pair
  CHECK (relationship_id IS NOT NULL OR
    (member_id IS NOT NULL AND coach_id IS NOT NULL AND member_id <> coach_id));
CREATE UNIQUE INDEX uq_direct_conversation_pair
  ON conversations (member_id, coach_id)
  WHERE relationship_id IS NULL;
CREATE INDEX ix_conversations_pair
  ON conversations (member_id, coach_id, last_message_at DESC);

COMMIT;
