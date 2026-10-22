import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();
const input = z.strictObject({
  memberId: uuid, title: z.string().trim().min(1).max(150),
  scheduledStartAt: z.iso.datetime({ offset: true }),
  scheduledEndAt: z.iso.datetime({ offset: true }).nullable().optional(),
  notes: z.string().trim().max(5000).nullable().optional(),
});
const patch = z.strictObject({
  title: z.string().trim().min(1).max(150).optional(),
  scheduledStartAt: z.iso.datetime({ offset: true }).optional(),
  scheduledEndAt: z.iso.datetime({ offset: true }).nullable().optional(),
  notes: z.string().trim().max(5000).nullable().optional(),
  status: z.enum(['COMPLETED', 'MEMBER_ABSENT', 'CANCELLED']).optional(),
  cancellationReason: z.string().trim().min(1).max(2000).optional(),
});

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, message, details: {} } });
}

function view(row) {
  return { id: row.id, relationshipId: row.relationship_id, memberId: row.member_id,
    title: row.title, scheduledStartAt: row.scheduled_start_at,
    scheduledEndAt: row.scheduled_end_at, status: row.status, notes: row.notes,
    cancellationReason: row.cancellation_reason, cancelledAt: row.cancelled_at,
    completedAt: row.completed_at, absentAt: row.absent_at };
}

export function createSessionsRouter({ database, jwtSecret }) {
  const router = Router();
  router.use(createAuthentication({ database, jwtSecret }));

  router.get('/training-sessions/me', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem');
    try {
      const result = await database.query(
        `SELECT * FROM training_sessions WHERE member_id = $1
         ORDER BY scheduled_start_at DESC, id DESC`, [request.authUser.id],
      );
      return response.json({ data: result.rows.map(view) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được lịch tập'); }
  });

  router.get('/coach/training-sessions', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được xem');
    try {
      const result = await database.query(
        `SELECT s.* FROM training_sessions s JOIN coach_relationships r
         ON r.id = s.relationship_id WHERE r.coach_id = $1
         ORDER BY s.scheduled_start_at DESC, s.id DESC`, [request.authUser.id],
      );
      return response.json({ data: result.rows.map(view) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được lịch tập'); }
  });

  router.get('/training-sessions/:sessionId', async (request, response) => {
    if (!uuid.safeParse(request.params.sessionId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã buổi tập không hợp lệ');
    try {
      const found = await database.query(
        `SELECT s.*, r.coach_id FROM training_sessions s JOIN coach_relationships r
         ON r.id = s.relationship_id WHERE s.id = $1`, [request.params.sessionId],
      );
      const row = found.rows[0];
      return row && (row.member_id === request.authUser.id || row.coach_id === request.authUser.id)
        ? response.json({ data: view(row) })
        : fail(response, 404, 'NOT_FOUND', 'Không tìm thấy buổi tập');
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được buổi tập'); }
  });

  router.post('/coach/training-sessions', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được tạo');
    const parsed = input.safeParse(request.body);
    if (!parsed.success || (parsed.data.scheduledEndAt &&
      new Date(parsed.data.scheduledEndAt) <= new Date(parsed.data.scheduledStartAt))) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Lịch tập không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const relationship = await client.query(
        `SELECT id FROM coach_relationships WHERE coach_id = $1 AND member_id = $2
         AND status = 'ACTIVE' FOR UPDATE`, [request.authUser.id, parsed.data.memberId],
      );
      if (!relationship.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 403, 'RELATIONSHIP_REQUIRED', 'Quan hệ Coach–Member không hoạt động');
      }
      const id = randomUUID();
      const data = parsed.data;
      const result = await client.query(
        `INSERT INTO training_sessions
         (id, relationship_id, member_id, title, scheduled_start_at,
          scheduled_end_at, notes) VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING *`,
        [id, relationship.rows[0].id, data.memberId, data.title,
          data.scheduledStartAt, data.scheduledEndAt ?? null, data.notes ?? null],
      );
      await client.query('COMMIT');
      return response.status(201).json({ data: view(result.rows[0]) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tạo được lịch tập');
    } finally { client.release(); }
  });

  router.patch('/coach/training-sessions/:sessionId', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được sửa');
    if (!uuid.safeParse(request.params.sessionId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã buổi tập không hợp lệ');
    const parsed = patch.safeParse(request.body);
    if (!parsed.success || !Object.keys(parsed.data ?? {}).length ||
      (parsed.data.status === 'CANCELLED' && !parsed.data.cancellationReason) ||
      (parsed.data.status !== 'CANCELLED' && parsed.data.cancellationReason)) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Lịch tập không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const found = await client.query(
        `SELECT s.*, r.coach_id, r.status AS relationship_status
         FROM training_sessions s JOIN coach_relationships r ON r.id = s.relationship_id
         WHERE s.id = $1 AND r.coach_id = $2 FOR UPDATE OF s`,
        [request.params.sessionId, request.authUser.id],
      );
      if (!found.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy buổi tập');
      }
      const row = found.rows[0];
      if (row.status !== 'SCHEDULED' || row.relationship_status !== 'ACTIVE') {
        await client.query('ROLLBACK');
        return fail(response, 409, 'SESSION_NOT_EDITABLE', 'Không thể sửa buổi tập');
      }
      const data = parsed.data;
      const start = data.scheduledStartAt ?? row.scheduled_start_at;
      const end = 'scheduledEndAt' in data ? data.scheduledEndAt : row.scheduled_end_at;
      if (end && new Date(end) <= new Date(start)) {
        await client.query('ROLLBACK');
        return fail(response, 422, 'VALIDATION_ERROR', 'Giờ kết thúc phải sau giờ bắt đầu');
      }
      if (data.status && Object.keys(data).some((key) =>
        !['status', 'cancellationReason'].includes(key))) {
        await client.query('ROLLBACK');
        return fail(response, 422, 'VALIDATION_ERROR', 'Không đổi lịch khi kết thúc buổi tập');
      }
      const result = await client.query(
        `UPDATE training_sessions SET title = $1, scheduled_start_at = $2,
         scheduled_end_at = $3, notes = $4, status = $5,
         cancellation_reason = $6, cancelled_at = $7,
         completed_at = $8, absent_at = $9 WHERE id = $10 RETURNING *`,
        [data.title ?? row.title, start, end,
          'notes' in data ? data.notes : row.notes,
          data.status ?? 'SCHEDULED', data.cancellationReason ?? null,
          data.status === 'CANCELLED' ? new Date() : null,
          data.status === 'COMPLETED' ? new Date() : null,
          data.status === 'MEMBER_ABSENT' ? new Date() : null, row.id],
      );
      await client.query('COMMIT');
      return response.json({ data: view(result.rows[0]) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không sửa được lịch tập');
    } finally { client.release(); }
  });
  return router;
}
