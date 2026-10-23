import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();
const paging = z.strictObject({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});
const send = z.discriminatedUnion('messageType', [
  z.strictObject({ messageType: z.literal('TEXT'), clientMessageId: uuid,
    content: z.string().trim().min(1).max(5000) }),
  z.strictObject({ messageType: z.literal('IMAGE'), clientMessageId: uuid,
    mediaId: uuid, content: z.string().trim().max(5000).nullable().optional() }),
]);

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, message, details: {} } });
}

function view(row) {
  return { id: row.id, relationshipId: row.relationship_id,
    senderId: row.sender_id, clientMessageId: row.client_message_id,
    messageType: row.message_type, content: row.content,
    mediaId: row.media_id, sentAt: row.sent_at };
}

async function conversation(database, relationshipId, userId, lock = false) {
  const found = await database.query(
    `SELECT c.id, c.relationship_id, r.status, r.member_id, r.coach_id
     FROM conversations c JOIN coach_relationships r ON r.id = c.relationship_id
     JOIN conversation_participants p ON p.conversation_id = c.id
     WHERE c.relationship_id = $1 AND p.user_id = $2
     ${lock ? 'FOR UPDATE OF c, r' : ''}`, [relationshipId, userId],
  );
  return found.rows[0];
}

export function createMessagingRouter({ database, jwtSecret }) {
  const router = Router();
  router.use(createAuthentication({ database, jwtSecret }));
  router.use('/conversations', (request, response, next) =>
    ['MEMBER', 'COACH'].includes(request.authUser.role) ? next()
      : fail(response, 403, 'FORBIDDEN', 'Chỉ Member và Coach được nhắn tin'));

  router.get('/conversations', async (request, response) => {
    const parsed = paging.safeParse(request.query);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Phân trang không hợp lệ');
    const { page, pageSize } = parsed.data;
    try {
      const total = await database.query(
        `SELECT count(*)::int AS count FROM conversation_participants WHERE user_id = $1`,
        [request.authUser.id],
      );
      const result = await database.query(
        `SELECT c.id, c.relationship_id, c.last_message_at, r.status,
                r.member_id, r.coach_id,
                (SELECT count(*)::int FROM messages m
                 LEFT JOIN messages last_read ON last_read.id = p.last_read_message_id
                 WHERE m.conversation_id = c.id AND m.sender_id <> $1
                 AND (last_read.id IS NULL OR
                      (m.sent_at, m.id) > (last_read.sent_at, last_read.id))) AS unread_count
         FROM conversation_participants p JOIN conversations c ON c.id = p.conversation_id
         JOIN coach_relationships r ON r.id = c.relationship_id
         WHERE p.user_id = $1
         ORDER BY c.last_message_at DESC NULLS LAST, c.id DESC
         LIMIT $2 OFFSET $3`, [request.authUser.id, pageSize, (page - 1) * pageSize],
      );
      const totalItems = total.rows[0].count;
      return response.json({ data: result.rows.map((row) => ({
        id: row.id, relationshipId: row.relationship_id, status: row.status,
        memberId: row.member_id, coachId: row.coach_id,
        lastMessageAt: row.last_message_at, unreadCount: row.unread_count,
      })), pagination: { page, pageSize, totalItems,
        totalPages: Math.ceil(totalItems / pageSize) } });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được cuộc trò chuyện'); }
  });

  router.get('/conversations/:relationshipId/messages', async (request, response) => {
    if (!uuid.safeParse(request.params.relationshipId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã quan hệ không hợp lệ');
    const parsed = paging.safeParse(request.query);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Phân trang không hợp lệ');
    try {
      const found = await conversation(database, request.params.relationshipId, request.authUser.id);
      if (!found) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy cuộc trò chuyện');
      const { page, pageSize } = parsed.data;
      const total = await database.query('SELECT count(*)::int AS count FROM messages WHERE conversation_id = $1', [found.id]);
      const result = await database.query(
        `SELECT m.*, $2::uuid AS relationship_id FROM messages m
         WHERE m.conversation_id = $1 ORDER BY m.sent_at DESC, m.id DESC
         LIMIT $3 OFFSET $4`,
        [found.id, found.relationship_id, pageSize, (page - 1) * pageSize],
      );
      const totalItems = total.rows[0].count;
      return response.json({ data: result.rows.map(view), pagination: {
        page, pageSize, totalItems, totalPages: Math.ceil(totalItems / pageSize),
      } });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được tin nhắn'); }
  });

  router.post('/conversations/:relationshipId/messages', async (request, response) => {
    if (!uuid.safeParse(request.params.relationshipId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã quan hệ không hợp lệ');
    const parsed = send.safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Tin nhắn không hợp lệ');
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const found = await conversation(client, request.params.relationshipId, request.authUser.id, true);
      if (!found) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy cuộc trò chuyện');
      }
      const data = parsed.data;
      const existing = await client.query(
        `SELECT m.*, $3::uuid AS relationship_id FROM messages m
         WHERE sender_id = $1 AND client_message_id = $2`,
        [request.authUser.id, data.clientMessageId, found.relationship_id],
      );
      if (existing.rows.length) {
        const old = existing.rows[0];
        if (old.conversation_id !== found.id || old.message_type !== data.messageType ||
          old.content !== (data.content ?? null) || old.media_id !== (data.mediaId ?? null)) {
          await client.query('ROLLBACK');
          return fail(response, 409, 'MESSAGE_ID_CONFLICT', 'Mã tin nhắn đã được dùng');
        }
        await client.query('COMMIT');
        return response.json({ data: view(old) });
      }
      if (found.status !== 'ACTIVE') {
        await client.query('ROLLBACK');
        return fail(response, 403, 'RELATIONSHIP_INACTIVE', 'Quan hệ không hoạt động');
      }
      if (data.messageType === 'IMAGE') {
        const media = await client.query(
          `SELECT 1 FROM media_assets WHERE id = $1 AND owner_id = $2
           AND purpose = 'MESSAGE' AND status = 'READY'`,
          [data.mediaId, request.authUser.id],
        );
        if (!media.rows.length) {
          await client.query('ROLLBACK');
          return fail(response, 422, 'VALIDATION_ERROR', 'Ảnh không hợp lệ');
        }
      }
      const result = await client.query(
        `INSERT INTO messages
         (id, conversation_id, sender_id, client_message_id, message_type, content, media_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *, $8::uuid AS relationship_id`,
        [randomUUID(), found.id, request.authUser.id, data.clientMessageId,
          data.messageType, data.content ?? null, data.mediaId ?? null,
          found.relationship_id],
      );
      await client.query('UPDATE conversations SET last_message_at = $1 WHERE id = $2',
        [result.rows[0].sent_at, found.id]);
      await client.query('COMMIT');
      return response.status(201).json({ data: view(result.rows[0]) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không gửi được tin nhắn');
    } finally { client.release(); }
  });

  router.patch('/conversations/:relationshipId/read-state', async (request, response) => {
    if (!uuid.safeParse(request.params.relationshipId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã quan hệ không hợp lệ');
    const parsed = z.strictObject({ messageId: uuid }).safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã tin nhắn không hợp lệ');
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const found = await conversation(client, request.params.relationshipId, request.authUser.id);
      if (!found) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy cuộc trò chuyện');
      }
      const cursor = await client.query(
        `SELECT m.id, m.sent_at, m.sender_id FROM messages m
         WHERE m.id = $1 AND m.conversation_id = $2`, [parsed.data.messageId, found.id],
      );
      if (!cursor.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy tin nhắn');
      }
      if (cursor.rows[0].sender_id === request.authUser.id) {
        await client.query('ROLLBACK');
        return fail(response, 422, 'VALIDATION_ERROR', 'Chỉ đánh dấu đã đọc tin nhắn nhận được');
      }
      const updated = await client.query(
        `UPDATE conversation_participants p
         SET last_read_message_id = $1, last_read_at = now()
         WHERE p.conversation_id = $2 AND p.user_id = $3
         AND (p.last_read_message_id IS NULL OR EXISTS (
           SELECT 1 FROM messages previous WHERE previous.id = p.last_read_message_id
           AND (previous.sent_at, previous.id) < ($4::timestamptz, $1::uuid)))
         RETURNING last_read_message_id, last_read_at`,
        [cursor.rows[0].id, found.id, request.authUser.id, cursor.rows[0].sent_at],
      );
      const current = updated.rows[0] ?? (await client.query(
        `SELECT last_read_message_id, last_read_at FROM conversation_participants
         WHERE conversation_id = $1 AND user_id = $2`, [found.id, request.authUser.id],
      )).rows[0];
      await client.query('COMMIT');
      return response.json({ data: { lastReadMessageId: current.last_read_message_id,
        lastReadAt: current.last_read_at } });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không cập nhật được trạng thái đọc');
    } finally { client.release(); }
  });
  return router;
}
