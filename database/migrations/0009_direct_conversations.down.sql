BEGIN;

-- A rollback with direct conversations must stop rather than erase messages.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM conversations WHERE relationship_id IS NULL) THEN
    RAISE EXCEPTION 'Direct conversations must be migrated before rollback';
  END IF;
END;
$$;

DROP INDEX ix_conversations_pair;
DROP INDEX uq_direct_conversation_pair;
ALTER TABLE conversations DROP CONSTRAINT ck_direct_conversation_pair;
ALTER TABLE conversations DROP COLUMN coach_id;
ALTER TABLE conversations DROP COLUMN member_id;
ALTER TABLE conversations ALTER COLUMN relationship_id SET NOT NULL;

COMMIT;
