import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from '../users/users.routes.js';

const uuid = z.uuid();
const paging = z.strictObject({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, message, details: {} } });
}

function view(row) {
  return { id: row.id, relationshipId: row.relationship_id,
    callerId: row.caller_id, receiverId: row.receiver_id,
    callerName: row.caller_name ?? null,
    receiverName: row.receiver_name ?? null,
    callType: row.call_type, status: row.status,
    initiatedAt: row.initiated_at, answeredAt: row.answered_at,
    endedAt: row.ended_at, durationSeconds: row.duration_seconds,
    failureReason: row.failure_reason };
}

const callSelect = `c.*, caller.full_name AS caller_name, receiver.full_name AS receiver_name`;
const callUserJoins = `LEFT JOIN users caller ON caller.id = c.caller_id
  LEFT JOIN users receiver ON receiver.id = c.receiver_id`;

const ringWindow = "interval '45 seconds'";

export function createCallsRouter({ database, jwtSecret, callTokenProvider, liveKit, realtime }) {
  const router = Router();
  const issueToken = liveKit?.issueToken ?? callTokenProvider;
  router.use('/calls', createAuthentication({ database, jwtSecret }));
  router.use('/calls', (request, response, next) =>
    ['MEMBER', 'COACH'].includes(request.authUser.role) ? next()
      : fail(response, 403, 'FORBIDDEN', 'Chỉ Member và Coach được gọi'));

  router.get('/calls', async (request, response) => {
    const parsed = paging.safeParse(request.query);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Phân trang không hợp lệ');
    const { page, pageSize } = parsed.data;
    try {
      const [total, result] = await Promise.all([
        database.query(
          `SELECT count(*)::int AS count FROM call_logs
           WHERE caller_id = $1 OR receiver_id = $1`, [request.authUser.id],
        ),
        database.query(
          `SELECT ${callSelect} FROM call_logs c ${callUserJoins}
           WHERE c.caller_id = $1 OR c.receiver_id = $1
           ORDER BY c.initiated_at DESC, c.id DESC LIMIT $2 OFFSET $3`,
          [request.authUser.id, pageSize, (page - 1) * pageSize],
        ),
      ]);
      const totalItems = total.rows[0].count;
      return response.json({ data: result.rows.map(view), pagination: {
        page, pageSize, totalItems, totalPages: Math.ceil(totalItems / pageSize),
      } });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được lịch sử gọi'); }
  });

  router.get('/calls/incoming', async (request, response) => {
    if (!liveKit) return response.json({ data: [] });
    try {
      const result = await database.query(
        `SELECT ${callSelect} FROM call_logs c
         JOIN coach_relationships r ON r.id = c.relationship_id
         ${callUserJoins}
         WHERE c.receiver_id = $1 AND c.status = 'RINGING' AND r.status = 'ACTIVE'
           AND c.initiated_at > statement_timestamp() - ${ringWindow}
         ORDER BY c.initiated_at DESC LIMIT 1`, [request.authUser.id],
      );
      return response.json({ data: result.rows.map(view) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được cuộc gọi đến'); }
  });

  router.get('/calls/:callId', async (request, response) => {
    if (!uuid.safeParse(request.params.callId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã cuộc gọi không hợp lệ');
    }
    const params = [request.params.callId, request.authUser.id];
    try {
      if (liveKit) {
        await database.query(
          `UPDATE call_logs SET status = 'MISSED', ended_at = statement_timestamp()
           WHERE id = $1 AND (caller_id = $2 OR receiver_id = $2)
             AND status = 'RINGING' AND initiated_at <= statement_timestamp() - ${ringWindow}`, params,
        );
      }
      const { rows: [call] } = await database.query(
        `SELECT ${callSelect} FROM call_logs c ${callUserJoins}
         WHERE c.id = $1 AND (c.caller_id = $2 OR c.receiver_id = $2)`, params,
      );
      if (!call) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy cuộc gọi');
      return response.json({ data: view(call) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được cuộc gọi'); }
  });

  router.post('/calls', async (request, response) => {
    const parsed = z.strictObject({
      relationshipId: uuid, callType: z.enum(['VOICE', 'VIDEO']),
      live: z.boolean().optional(),
    }).safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Cuộc gọi không hợp lệ');
    if (parsed.data.live && !liveKit) {
      return fail(response, 503, 'SERVICE_UNAVAILABLE', 'LiveKit chưa được cấu hình.');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const found = await client.query(
        `SELECT member_id, coach_id FROM coach_relationships
         WHERE id = $1 AND status = 'ACTIVE' FOR SHARE`,
        [parsed.data.relationshipId],
      );
      const row = found.rows[0];
      if (!row || ![row.member_id, row.coach_id].includes(request.authUser.id)) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy quan hệ đang hoạt động');
      }
      const receiverId = request.authUser.id === row.member_id
        ? row.coach_id : row.member_id;
      if (parsed.data.live) {
        await client.query('SELECT pg_advisory_xact_lock(hashtext($1), hashtext($2))',
          ['metagym-live-call', parsed.data.relationshipId]);
        const pending = await client.query(
          `SELECT 1 FROM call_logs WHERE relationship_id = $1 AND status = 'RINGING'
             AND initiated_at > statement_timestamp() - ${ringWindow} LIMIT 1`,
          [parsed.data.relationshipId],
        );
        if (pending.rowCount) {
          await client.query('ROLLBACK');
          return fail(response, 409, 'CALL_ALREADY_RINGING', 'Đang có cuộc gọi chờ trả lời');
        }
      }
      const result = await client.query(
        `WITH c AS (
           INSERT INTO call_logs
           (id, relationship_id, caller_id, receiver_id, call_type, status)
           VALUES ($1, $2, $3, $4, $5, $6) RETURNING *
         )
         SELECT ${callSelect} FROM c ${callUserJoins}`,
        [randomUUID(), parsed.data.relationshipId, request.authUser.id,
          receiverId, parsed.data.callType, parsed.data.live ? 'RINGING' : 'CREATED'],
      );
      await client.query('COMMIT');
      if (parsed.data.live) void realtime?.publish(receiverId, 'incoming_call', {});
      return response.status(201).json({ data: view(result.rows[0]) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tạo được cuộc gọi');
    } finally { client.release(); }
  });

  router.patch('/calls/:callId', async (request, response) => {
    if (!uuid.safeParse(request.params.callId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã cuộc gọi không hợp lệ');
    const parsed = z.strictObject({
      status: z.enum(['RINGING', 'ANSWERED', 'REJECTED', 'MISSED', 'ENDED', 'FAILED']),
      failureReason: z.string().trim().min(1).max(2000).optional(),
    }).safeParse(request.body);
    if (!parsed.success || (parsed.data.status === 'FAILED') !== !!parsed.data.failureReason) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Trạng thái cuộc gọi không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const found = await client.query(
        `SELECT * FROM call_logs WHERE id = $1
         AND (caller_id = $2 OR receiver_id = $2) FOR UPDATE`,
        [request.params.callId, request.authUser.id],
      );
      if (!found.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy cuộc gọi');
      }
      const row = found.rows[0];
      if (liveKit && row.status === 'RINGING' && parsed.data.status === 'ANSWERED') {
        const active = await client.query(
          `SELECT 1 FROM coach_relationships r JOIN call_logs c ON c.relationship_id = r.id
           WHERE c.id = $1 AND r.status = 'ACTIVE'
             AND c.initiated_at > statement_timestamp() - ${ringWindow}`, [row.id],
        );
        if (!active.rowCount) {
          await client.query('ROLLBACK');
          return fail(response, 409, 'CALL_NOT_ACTIVE', 'Cuộc gọi không còn hoạt động');
        }
      }
      const allowed = {
        CREATED: ['RINGING', 'REJECTED', 'MISSED', 'FAILED'],
        RINGING: ['ANSWERED', 'REJECTED', 'MISSED', 'FAILED'],
        ANSWERED: ['ENDED', 'FAILED'],
      };
      if (!allowed[row.status]?.includes(parsed.data.status) ||
        (['ANSWERED', 'REJECTED'].includes(parsed.data.status) &&
          request.authUser.id !== row.receiver_id)) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'INVALID_CALL_TRANSITION', 'Không thể đổi trạng thái cuộc gọi');
      }
      const status = parsed.data.status;
      const now = new Date();
      const answeredAt = status === 'ANSWERED' ? now : row.answered_at;
      const endedAt = ['REJECTED', 'MISSED', 'ENDED', 'FAILED'].includes(status)
        ? now : null;
      const durationSeconds = endedAt && answeredAt
        ? Math.max(0, Math.floor((endedAt - new Date(answeredAt)) / 1000)) : 0;
      const result = await client.query(
        `WITH c AS (
           UPDATE call_logs SET status = $1, answered_at = $2, ended_at = $3,
            duration_seconds = $4, failure_reason = $5 WHERE id = $6 RETURNING *
         )
         SELECT ${callSelect} FROM c ${callUserJoins}`,
        [status, answeredAt, endedAt, durationSeconds,
          parsed.data.failureReason ?? null, row.id],
      );
      await client.query('COMMIT');
      if (endedAt && row.provider_call_id && liveKit) {
        void liveKit.closeRoom(row.provider_call_id, [row.caller_id, row.receiver_id])
          .catch(() => console.error('Failed to close LiveKit room for call', row.id));
      }
      return response.json({ data: view(result.rows[0]) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không đổi được trạng thái cuộc gọi');
    } finally { client.release(); }
  });

  router.post('/calls/:callId/access-tokens', async (request, response) => {
    if (!uuid.safeParse(request.params.callId).success ||
      !z.strictObject({}).safeParse(request.body ?? {}).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu không hợp lệ');
    }
    if (typeof issueToken !== 'function') {
      return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Dịch vụ gọi chưa được cấu hình');
    }
    let call;
    try {
      const found = await database.query(
        `SELECT c.*, r.status AS relationship_status FROM call_logs c
         JOIN coach_relationships r ON r.id = c.relationship_id
         WHERE c.id = $1 AND (c.caller_id = $2 OR c.receiver_id = $2)`,
        [request.params.callId, request.authUser.id],
      );
      call = found.rows[0];
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được cuộc gọi'); }
    if (!call) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy cuộc gọi');
    const joinable = liveKit ? ['ANSWERED'] : ['CREATED', 'RINGING', 'ANSWERED'];
    if (call.relationship_status !== 'ACTIVE' || !joinable.includes(call.status)) {
      return fail(response, 409, 'CALL_NOT_ACTIVE', 'Cuộc gọi không còn hoạt động');
    }
    const schema = z.strictObject({
      accessToken: z.string().min(1).max(4096),
      providerCallId: z.string().trim().min(1).max(150),
      expiresAt: z.iso.datetime({ offset: true }),
      channelId: z.string().trim().min(1).max(150),
    });
    let token;
    try {
      token = schema.parse(await issueToken({
        callId: call.id, relationshipId: call.relationship_id,
        userId: request.authUser.id, callerId: call.caller_id,
        receiverId: call.receiver_id, callType: call.call_type,
      }));
      const remaining = new Date(token.expiresAt).getTime() - Date.now();
      if (remaining <= 0 || remaining > 15 * 60 * 1000) throw new Error('INVALID_EXPIRY');
    } catch { return fail(response, 502, 'CALL_PROVIDER_ERROR', 'Dịch vụ gọi không trả token hợp lệ'); }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 502, 'CALL_PROVIDER_ERROR', 'Không ghi được thông tin dịch vụ gọi');
    try {
      await client.query('BEGIN');
      const account = await client.query(
        `SELECT id FROM users WHERE id = $1 AND status = 'ACTIVE'
         AND role = $2 AND session_version = $3 FOR SHARE`,
        [request.authUser.id, request.authUser.role, request.authUser.session_version],
      );
      if (!account.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'CALL_NOT_ACTIVE', 'Cuộc gọi không còn hoạt động');
      }
      const relationship = await client.query(
        `SELECT id FROM coach_relationships WHERE id = $1 AND status = 'ACTIVE'
         FOR SHARE`, [call.relationship_id],
      );
      if (!relationship.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'CALL_NOT_ACTIVE', 'Cuộc gọi không còn hoạt động');
      }
      const updated = await client.query(
        `UPDATE call_logs SET provider_call_id = $1 WHERE id = $2
         AND relationship_id = $3
         AND (caller_id = $4 OR receiver_id = $4)
         AND (provider_call_id IS NULL OR provider_call_id = $1)
         AND status = ANY($5::text[]) RETURNING id`,
        [token.providerCallId, call.id, call.relationship_id, request.authUser.id, joinable],
      );
      if (!updated.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'CALL_NOT_ACTIVE', 'Cuộc gọi không còn hoạt động');
      }
      await client.query('COMMIT');
      return response.json({ data: {
        accessToken: token.accessToken, channelId: token.channelId,
        expiresAt: token.expiresAt,
        ...(liveKit ? { serverUrl: liveKit.url } : {}),
      } });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 502, 'CALL_PROVIDER_ERROR', 'Không ghi được thông tin dịch vụ gọi');
    } finally { client.release(); }
  });
  return router;
}
