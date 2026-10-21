BEGIN;

DROP TABLE IF EXISTS admin_audit_logs;
ALTER TABLE ai_messages DROP CONSTRAINT IF EXISTS fk_ai_reply_conversation;
DROP TABLE IF EXISTS ai_messages;
DROP TABLE IF EXISTS ai_conversations;
DROP TABLE IF EXISTS call_logs;
ALTER TABLE conversation_participants DROP CONSTRAINT IF EXISTS fk_participant_read_cursor;
DROP TABLE IF EXISTS messages;
DROP TABLE IF EXISTS conversation_participants;
DROP TABLE IF EXISTS conversations;

COMMIT;
