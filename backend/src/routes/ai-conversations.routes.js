import { createHash, randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();
const paging = z.strictObject({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});
const title = z.string().trim().min(1).max(150);

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, message, details: {} } });
}

function view(row) {
  return { id: row.id, title: row.title,
    createdAt: row.created_at, updatedAt: row.updated_at };
}

const replySchema = z.strictObject({
  content: z.string().trim().min(1).max(20000),
  provider: z.string().trim().min(1).max(50),
  modelName: z.string().trim().min(1).max(100),
  providerRequestId: z.string().trim().max(150).nullable().optional(),
  inputTokens: z.number().int().min(0).nullable().optional(),
  outputTokens: z.number().int().min(0).nullable().optional(),
  safetyCategory: z.string().trim().max(50).nullable().optional(),
});

export function createAiConversationsRouter({ database, jwtSecret, aiResponder }) {
  const router = Router();
  router.use(createAuthentication({ database, jwtSecret }));
  router.use('/ai-conversations', (request, response, next) =>
    ['MEMBER', 'COACH'].includes(request.authUser.role) ? next()
      : fail(response, 403, 'FORBIDDEN', 'Chỉ Member và Coach được dùng AI'));

  router.get('/ai-conversations', async (request, response) => {
    const parsed = paging.safeParse(request.query);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Phân trang không hợp lệ');
    const { page, pageSize } = parsed.data;
    try {
      const total = await database.query(
        `SELECT count(*)::int AS count FROM ai_conversations
         WHERE user_id = $1 AND deleted_at IS NULL`, [request.authUser.id],
      );
      const result = await database.query(
        `SELECT * FROM ai_conversations WHERE user_id = $1 AND deleted_at IS NULL
         ORDER BY updated_at DESC, id DESC LIMIT $2 OFFSET $3`,
        [request.authUser.id, pageSize, (page - 1) * pageSize],
      );
      const totalItems = total.rows[0].count;
      return response.json({ data: result.rows.map(view), pagination: {
        page, pageSize, totalItems, totalPages: Math.ceil(totalItems / pageSize),
      } });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được cuộc trò chuyện AI'); }
  });

  router.post('/ai-conversations', async (request, response) => {
    const parsed = z.strictObject({ title: title.optional() }).safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu không hợp lệ');
    try {
      const result = await database.query(
        `INSERT INTO ai_conversations (id, user_id, title)
         VALUES ($1, $2, $3) RETURNING *`,
        [randomUUID(), request.authUser.id,
          parsed.data.title ?? 'Cuộc trò chuyện mới'],
      );
      return response.status(201).json({ data: view(result.rows[0]) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tạo được cuộc trò chuyện AI'); }
  });

  router.get('/ai-conversations/:conversationId', async (request, response) => {
    if (!uuid.safeParse(request.params.conversationId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã không hợp lệ');
    try {
      const result = await database.query(
        `SELECT * FROM ai_conversations WHERE id = $1 AND user_id = $2
         AND deleted_at IS NULL`, [request.params.conversationId, request.authUser.id],
      );
      return result.rows.length ? response.json({ data: view(result.rows[0]) })
        : fail(response, 404, 'NOT_FOUND', 'Không tìm thấy cuộc trò chuyện AI');
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được cuộc trò chuyện AI'); }
  });

  router.patch('/ai-conversations/:conversationId', async (request, response) => {
    if (!uuid.safeParse(request.params.conversationId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã không hợp lệ');
    const parsed = z.strictObject({ title }).safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Tiêu đề không hợp lệ');
    try {
      const result = await database.query(
        `UPDATE ai_conversations SET title = $1 WHERE id = $2 AND user_id = $3
         AND deleted_at IS NULL RETURNING *`,
        [parsed.data.title, request.params.conversationId, request.authUser.id],
      );
      return result.rows.length ? response.json({ data: view(result.rows[0]) })
        : fail(response, 404, 'NOT_FOUND', 'Không tìm thấy cuộc trò chuyện AI');
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không sửa được cuộc trò chuyện AI'); }
  });

  router.delete('/ai-conversations/:conversationId', async (request, response) => {
    if (!uuid.safeParse(request.params.conversationId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã không hợp lệ');
    try {
      const result = await database.query(
        `UPDATE ai_conversations SET deleted_at = now()
         WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL RETURNING id`,
        [request.params.conversationId, request.authUser.id],
      );
      return result.rows.length ? response.json({ data: { deleted: true } })
        : fail(response, 404, 'NOT_FOUND', 'Không tìm thấy cuộc trò chuyện AI');
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không xóa được cuộc trò chuyện AI'); }
  });

  router.get('/ai-conversations/:conversationId/messages', async (request, response) => {
    if (!uuid.safeParse(request.params.conversationId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã không hợp lệ');
    const parsed = paging.safeParse(request.query);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Phân trang không hợp lệ');
    try {
      const owner = await database.query(
        `SELECT 1 FROM ai_conversations WHERE id = $1 AND user_id = $2
         AND deleted_at IS NULL`, [request.params.conversationId, request.authUser.id],
      );
      if (!owner.rows.length) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy cuộc trò chuyện AI');
      const { page, pageSize } = parsed.data;
      const total = await database.query(
        'SELECT count(*)::int AS count FROM ai_messages WHERE conversation_id = $1',
        [request.params.conversationId],
      );
      const result = await database.query(
        `SELECT id, role, content, status, created_at, completed_at, failed_at
         FROM ai_messages WHERE conversation_id = $1
         ORDER BY created_at, id LIMIT $2 OFFSET $3`,
        [request.params.conversationId, pageSize, (page - 1) * pageSize],
      );
      const totalItems = total.rows[0].count;
      return response.json({ data: result.rows.map((row) => ({
        id: row.id, role: row.role, content: row.content,
        status: row.status, createdAt: row.created_at,
        completedAt: row.completed_at, failedAt: row.failed_at,
      })), pagination: { page, pageSize, totalItems,
        totalPages: Math.ceil(totalItems / pageSize) } });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được lịch sử AI'); }
  });

  router.post('/ai-conversations/:conversationId/messages', async (request, response) => {
    if (!uuid.safeParse(request.params.conversationId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã không hợp lệ');
    const parsed = z.strictObject({
      clientRequestId: uuid,
      content: z.string().trim().min(1).max(10000),
    }).safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Câu hỏi không hợp lệ');
    if (typeof aiResponder !== 'function') {
      return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Dịch vụ AI chưa được cấu hình');
    }
    const { content, clientRequestId } = parsed.data;
    const requestHash = createHash('sha256').update(content).digest('hex');
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    let messageId;
    try {
      await client.query('BEGIN');
      const owner = await client.query(
        `SELECT id FROM ai_conversations WHERE id = $1 AND user_id = $2
         AND deleted_at IS NULL FOR UPDATE`,
        [request.params.conversationId, request.authUser.id],
      );
      if (!owner.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy cuộc trò chuyện AI');
      }
      const previous = await client.query(
        `SELECT * FROM ai_messages WHERE conversation_id = $1
         AND client_request_id = $2 AND role = 'USER'`,
        [request.params.conversationId, clientRequestId],
      );
      if (previous.rows.length) {
        const row = previous.rows[0];
        if (row.request_hash !== requestHash) {
          await client.query('ROLLBACK');
          return fail(response, 409, 'REQUEST_ID_CONFLICT', 'Mã yêu cầu đã được dùng');
        }
        const reply = await client.query(
          `SELECT id, content, provider, model_name, created_at
           FROM ai_messages WHERE reply_to_message_id = $1`, [row.id],
        );
        await client.query('COMMIT');
        return response.status(reply.rows.length ? 200 : 202).json({ data: {
          requestId: row.id, status: row.status,
          reply: reply.rows.length ? {
            id: reply.rows[0].id, content: reply.rows[0].content,
            provider: reply.rows[0].provider,
            modelName: reply.rows[0].model_name,
            createdAt: reply.rows[0].created_at,
          } : null,
        } });
      }
      messageId = randomUUID();
      await client.query(
        `INSERT INTO ai_messages
         (id, conversation_id, role, content, client_request_id,
          request_hash, status)
         VALUES ($1, $2, 'USER', $3, $4, $5, 'PROCESSING')`,
        [messageId, request.params.conversationId, content,
          clientRequestId, requestHash],
      );
      await client.query('COMMIT');
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không gửi được câu hỏi');
    } finally { client.release(); }

    let reply;
    try {
      reply = replySchema.parse(await aiResponder({ content,
        conversationId: request.params.conversationId, userId: request.authUser.id }));
    } catch {
      await database.query(
        `UPDATE ai_messages SET status = 'FAILED', failed_at = now()
         WHERE id = $1 AND status = 'PROCESSING'`, [messageId],
      ).catch(() => {});
      return fail(response, 502, 'AI_PROVIDER_ERROR', 'Dịch vụ AI không trả được câu trả lời hợp lệ');
    }
    const saving = await database.connect().catch(() => null);
    if (!saving) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await saving.query('BEGIN');
      const replyId = randomUUID();
      const result = await saving.query(
        `INSERT INTO ai_messages
         (id, conversation_id, role, content, status, provider,
          model_name, provider_request_id, input_tokens, output_tokens,
          safety_category, reply_to_message_id, completed_at)
         VALUES ($1, $2, 'ASSISTANT', $3, 'COMPLETED', $4, $5,
                 $6, $7, $8, $9, $10, now()) RETURNING *`,
        [replyId, request.params.conversationId, reply.content,
          reply.provider, reply.modelName, reply.providerRequestId ?? null,
          reply.inputTokens ?? null, reply.outputTokens ?? null,
          reply.safetyCategory ?? null, messageId],
      );
      await saving.query(
        `UPDATE ai_messages SET status = 'COMPLETED', completed_at = now()
         WHERE id = $1 AND status = 'PROCESSING'`, [messageId],
      );
      await saving.query(
        'UPDATE ai_conversations SET updated_at = now() WHERE id = $1',
        [request.params.conversationId],
      );
      await saving.query('COMMIT');
      return response.status(201).json({ data: {
        requestId: messageId, status: 'COMPLETED', reply: {
          id: result.rows[0].id, content: result.rows[0].content,
          provider: result.rows[0].provider,
          modelName: result.rows[0].model_name,
          createdAt: result.rows[0].created_at,
        },
      } });
    } catch {
      await saving.query('ROLLBACK').catch(() => {});
      await database.query(
        `UPDATE ai_messages SET status = 'FAILED', failed_at = now()
         WHERE id = $1 AND status = 'PROCESSING'`, [messageId],
      ).catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không lưu được câu trả lời AI');
    } finally { saving.release(); }
  });
  return router;
}
