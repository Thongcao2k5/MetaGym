import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, details: {}, message } });
}

function coachView(row) {
  return {
    id: row.id, fullName: row.full_name, biography: row.biography,
    specialties: row.specialties, qualifications: row.qualifications,
    experienceYears: row.experience_years, availabilityNote: row.availability_note,
    memberLimit: row.member_limit, usedSlots: Number(row.used_slots),
    availableSlots: Math.max(0, row.member_limit - Number(row.used_slots)),
  };
}

function requestView(row) {
  return {
    id: row.id, memberId: row.member_id, coachId: row.coach_id,
    message: row.message, status: row.status,
    rejectionReason: row.rejection_reason,
    requestedAt: row.requested_at, decidedAt: row.decided_at,
  };
}

function relationshipView(row) {
  return {
    id: row.id, memberId: row.member_id, coachId: row.coach_id,
    status: row.status, startedAt: row.started_at,
    pausedAt: row.paused_at, endedAt: row.ended_at,
  };
}

async function activeMembership(client, memberId) {
  const result = await client.query(
    `SELECT 1 FROM member_memberships WHERE member_id = $1
     AND status = 'ACTIVE'
     AND start_date <= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
     AND end_date >= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date LIMIT 1`,
    [memberId],
  );
  return result.rows.length === 1;
}

export function createCoachingRouter({ database, jwtSecret }) {
  const router = Router();
  router.use(createAuthentication({ database, jwtSecret }));

  router.get('/coaches', async (_request, response) => {
    try {
      const result = await database.query(
        `SELECT u.id, u.full_name, c.biography, c.specialties,
                c.qualifications, c.experience_years, c.availability_note,
                c.member_limit,
                (SELECT count(*)::int FROM coach_relationships r
                 WHERE r.coach_id = u.id AND r.status IN ('ACTIVE', 'PAUSED')) AS used_slots
         FROM users u JOIN coach_profiles c ON c.user_id = u.id
         WHERE u.role = 'COACH' AND u.status = 'ACTIVE'
         ORDER BY u.full_name, u.id`,
      );
      return response.json({ data: result.rows.map(coachView) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được Coach'); }
  });

  router.get('/coaches/:coachId', async (request, response) => {
    if (!uuid.safeParse(request.params.coachId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã Coach không hợp lệ');
    try {
      const result = await database.query(
        `SELECT u.id, u.full_name, c.biography, c.specialties,
                c.qualifications, c.experience_years, c.availability_note,
                c.member_limit,
                (SELECT count(*)::int FROM coach_relationships r
                 WHERE r.coach_id = u.id AND r.status IN ('ACTIVE', 'PAUSED')) AS used_slots
         FROM users u JOIN coach_profiles c ON c.user_id = u.id
         WHERE u.id = $1 AND u.role = 'COACH' AND u.status = 'ACTIVE'`,
        [request.params.coachId],
      );
      return result.rows.length ? response.json({ data: coachView(result.rows[0]) })
        : fail(response, 404, 'NOT_FOUND', 'Không tìm thấy Coach');
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được Coach'); }
  });

  router.post('/coach-requests', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được chọn Coach');
    const parsed = z.strictObject({
      coachId: uuid, message: z.string().trim().max(2000).nullable().optional(),
    }).safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu yêu cầu không hợp lệ');
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const member = await client.query(
        `SELECT id FROM users WHERE id = $1 AND role = 'MEMBER' AND status = 'ACTIVE'
         AND session_version = $2 FOR UPDATE`,
        [request.authUser.id, request.authUser.session_version],
      );
      if (!member.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      if (!await activeMembership(client, request.authUser.id)) {
        await client.query('ROLLBACK');
        return fail(response, 403, 'MEMBERSHIP_REQUIRED', 'Cần gói tập đang hoạt động');
      }
      const coach = await client.query(
        `SELECT id FROM users WHERE id = $1 AND role = 'COACH' AND status = 'ACTIVE'`,
        [parsed.data.coachId],
      );
      if (!coach.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy Coach');
      }
      const existing = await client.query(
        `SELECT 1 FROM coach_relationships WHERE member_id = $1
         AND status IN ('ACTIVE', 'PAUSED')
         UNION ALL SELECT 1 FROM coach_requests WHERE member_id = $1
         AND status = 'PENDING' LIMIT 1`, [request.authUser.id],
      );
      if (existing.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'COACH_REQUEST_CONFLICT', 'Đã có Coach hoặc yêu cầu đang chờ');
      }
      const created = await client.query(
        `INSERT INTO coach_requests (id, member_id, coach_id, message)
         VALUES ($1, $2, $3, $4) RETURNING *`,
        [randomUUID(), request.authUser.id, parsed.data.coachId,
          parsed.data.message ?? null],
      );
      await client.query('COMMIT');
      return response.status(201).json({ data: requestView(created.rows[0]) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tạo được yêu cầu Coach');
    } finally { client.release(); }
  });

  router.get('/coach-requests/me', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem yêu cầu');
    try {
      const result = await database.query(
        `SELECT * FROM coach_requests WHERE member_id = $1
         ORDER BY requested_at DESC, id DESC`, [request.authUser.id],
      );
      return response.json({ data: result.rows.map(requestView) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được yêu cầu'); }
  });

  router.delete('/coach-requests/:requestId', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được hủy yêu cầu');
    if (!uuid.safeParse(request.params.requestId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã yêu cầu không hợp lệ');
    try {
      const result = await database.query(
        `UPDATE coach_requests SET status = 'CANCELLED', decided_at = now()
         WHERE id = $1 AND member_id = $2 AND status = 'PENDING' RETURNING *`,
        [request.params.requestId, request.authUser.id],
      );
      return result.rows.length ? response.json({ data: requestView(result.rows[0]) })
        : fail(response, 404, 'NOT_FOUND', 'Không tìm thấy yêu cầu đang chờ');
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không hủy được yêu cầu'); }
  });

  router.get('/coach/requests', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được xem yêu cầu');
    try {
      const result = await database.query(
        `SELECT * FROM coach_requests WHERE coach_id = $1
         ORDER BY requested_at DESC, id DESC`, [request.authUser.id],
      );
      return response.json({ data: result.rows.map(requestView) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được yêu cầu'); }
  });

  router.get('/coach/requests/:requestId', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được xem yêu cầu');
    if (!uuid.safeParse(request.params.requestId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã yêu cầu không hợp lệ');
    try {
      const result = await database.query(
        'SELECT * FROM coach_requests WHERE id = $1 AND coach_id = $2',
        [request.params.requestId, request.authUser.id],
      );
      return result.rows.length ? response.json({ data: requestView(result.rows[0]) })
        : fail(response, 404, 'NOT_FOUND', 'Không tìm thấy yêu cầu');
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được yêu cầu'); }
  });

  router.patch('/coach/requests/:requestId', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được xử lý yêu cầu');
    if (!uuid.safeParse(request.params.requestId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã yêu cầu không hợp lệ');
    const parsed = z.strictObject({
      decision: z.enum(['ACCEPTED', 'REJECTED']),
      reason: z.string().trim().min(1).max(1000).optional(),
    }).safeParse(request.body);
    if (!parsed.success || (parsed.data.decision === 'REJECTED' && !parsed.data.reason)) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Quyết định hoặc lý do không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const coach = await client.query(
        `SELECT u.id, c.member_limit FROM users u
         JOIN coach_profiles c ON c.user_id = u.id
         WHERE u.id = $1 AND u.role = 'COACH' AND u.status = 'ACTIVE'
         AND u.session_version = $2 FOR UPDATE OF u`,
        [request.authUser.id, request.authUser.session_version],
      );
      if (!coach.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const pending = await client.query(
        `SELECT * FROM coach_requests WHERE id = $1 AND coach_id = $2 FOR UPDATE`,
        [request.params.requestId, request.authUser.id],
      );
      if (!pending.rows.length || pending.rows[0].status !== 'PENDING') {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy yêu cầu đang chờ');
      }
      const item = pending.rows[0];
      if (parsed.data.decision === 'REJECTED') {
        const updated = await client.query(
          `UPDATE coach_requests SET status = 'REJECTED',
           rejection_reason = $1, decided_at = now() WHERE id = $2 RETURNING *`,
          [parsed.data.reason, item.id],
        );
        await client.query('COMMIT');
        return response.json({ data: requestView(updated.rows[0]) });
      }
      const member = await client.query(
        `SELECT id FROM users WHERE id = $1 AND role = 'MEMBER'
         AND status = 'ACTIVE' FOR UPDATE`, [item.member_id],
      );
      if (!member.rows.length || !await activeMembership(client, item.member_id)) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'MEMBERSHIP_REQUIRED', 'Member không còn gói đang hoạt động');
      }
      const occupied = await client.query(
        `SELECT count(*)::int AS count FROM coach_relationships
         WHERE coach_id = $1 AND status IN ('ACTIVE', 'PAUSED')`,
        [request.authUser.id],
      );
      if (occupied.rows[0].count >= coach.rows[0].member_limit) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'COACH_FULL', 'Coach đã đủ Member');
      }
      const other = await client.query(
        `SELECT 1 FROM coach_relationships WHERE member_id = $1
         AND status IN ('ACTIVE', 'PAUSED') LIMIT 1`, [item.member_id],
      );
      if (other.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'RELATIONSHIP_EXISTS', 'Member đã có Coach');
      }
      await client.query(
        `UPDATE coach_requests SET status = 'ACCEPTED', decided_at = now()
         WHERE id = $1`, [item.id],
      );
      const relationshipId = randomUUID();
      await client.query(
        `INSERT INTO coach_relationships
         (id, member_id, coach_id, source_request_id)
         VALUES ($1, $2, $3, $4)`,
        [relationshipId, item.member_id, request.authUser.id, item.id],
      );
      const conversationId = randomUUID();
      await client.query(
        `INSERT INTO conversations (id, relationship_id) VALUES ($1, $2)`,
        [conversationId, relationshipId],
      );
      await client.query(
        `INSERT INTO conversation_participants (conversation_id, user_id)
         VALUES ($1, $2), ($1, $3)`,
        [conversationId, item.member_id, request.authUser.id],
      );
      await client.query('COMMIT');
      return response.json({ data: {
        request: requestView({ ...item, status: 'ACCEPTED', decided_at: new Date() }),
        relationship: { id: relationshipId, memberId: item.member_id,
          coachId: request.authUser.id, status: 'ACTIVE' },
      } });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không xử lý được yêu cầu');
    } finally { client.release(); }
  });

  router.get('/relationships/me', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem Coach');
    try {
      const result = await database.query(
        `SELECT * FROM coach_relationships WHERE member_id = $1
         AND status IN ('ACTIVE', 'PAUSED') LIMIT 1`, [request.authUser.id],
      );
      return response.json({ data: result.rows.length ? relationshipView(result.rows[0]) : null });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được quan hệ'); }
  });

  router.get('/relationships/me/history', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem Coach');
    try {
      const result = await database.query(
        `SELECT * FROM coach_relationships WHERE member_id = $1
         ORDER BY started_at DESC, id DESC`, [request.authUser.id],
      );
      return response.json({ data: result.rows.map(relationshipView) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được quan hệ'); }
  });

  router.get('/coach/members', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được xem Member');
    try {
      const result = await database.query(
        `SELECT r.*, u.full_name FROM coach_relationships r
         JOIN users u ON u.id = r.member_id WHERE r.coach_id = $1
         AND r.status IN ('ACTIVE', 'PAUSED')
         ORDER BY u.full_name, r.id`, [request.authUser.id],
      );
      return response.json({ data: result.rows.map((row) => ({
        ...relationshipView(row), memberFullName: row.full_name,
      })) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được Member'); }
  });

  router.get('/coach/members/:memberId', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được xem Member');
    if (!uuid.safeParse(request.params.memberId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã Member không hợp lệ');
    try {
      const result = await database.query(
        `SELECT r.*, u.full_name, u.email::text,
                CASE WHEN r.status = 'ACTIVE' THEN m.fitness_goal END AS fitness_goal,
                CASE WHEN r.status = 'ACTIVE' THEN m.health_notes END AS health_notes,
                CASE WHEN r.status = 'ACTIVE' THEN m.injury_notes END AS injury_notes
         FROM coach_relationships r JOIN users u ON u.id = r.member_id
         JOIN member_profiles m ON m.user_id = r.member_id
         WHERE r.coach_id = $1 AND r.member_id = $2
         AND r.status IN ('ACTIVE', 'PAUSED') LIMIT 1`,
        [request.authUser.id, request.params.memberId],
      );
      if (!result.rows.length) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy Member đang phụ trách');
      const row = result.rows[0];
      return response.json({ data: {
        ...relationshipView(row), member: {
          id: row.member_id, fullName: row.full_name, email: row.email,
          fitnessGoal: row.fitness_goal, healthNotes: row.health_notes,
          injuryNotes: row.injury_notes,
        },
      } });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được Member'); }
  });

  router.post('/relationships/:relationshipId/terminations', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được kết thúc quan hệ');
    if (!uuid.safeParse(request.params.relationshipId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã quan hệ không hợp lệ');
    const parsed = z.strictObject({
      reason: z.string().trim().min(1).max(1000),
    }).safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Cần lý do kết thúc');
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const member = await client.query(
        `SELECT id FROM users WHERE id = $1 AND role = 'MEMBER' AND status = 'ACTIVE'
         AND session_version = $2 FOR UPDATE`,
        [request.authUser.id, request.authUser.session_version],
      );
      if (!member.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const result = await client.query(
        `SELECT * FROM coach_relationships WHERE id = $1 AND member_id = $2
         AND status IN ('ACTIVE', 'PAUSED') FOR UPDATE`,
        [request.params.relationshipId, request.authUser.id],
      );
      if (!result.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy quan hệ hiện tại');
      }
      await client.query(
        `UPDATE coach_relationships SET status = 'ENDED', ended_at = now(),
         ended_by = $1, end_reason = $2 WHERE id = $3`,
        [request.authUser.id, parsed.data.reason, result.rows[0].id],
      );
      await client.query(
        `UPDATE coach_termination_requests SET status = 'CANCELLED', decided_at = now()
         WHERE relationship_id = $1 AND status = 'PENDING'`, [result.rows[0].id],
      );
      await client.query(
        `UPDATE training_sessions SET status = 'CANCELLED', cancelled_at = now(),
         cancellation_reason = 'Quan hệ Coach đã kết thúc'
         WHERE relationship_id = $1 AND status = 'SCHEDULED'
         AND scheduled_start_at > now()`, [result.rows[0].id],
      );
      const ended = await client.query('SELECT * FROM coach_relationships WHERE id = $1', [result.rows[0].id]);
      await client.query('COMMIT');
      return response.json({ data: relationshipView(ended.rows[0]) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết thúc được quan hệ');
    } finally { client.release(); }
  });

  router.post('/coach/termination-requests', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được gửi yêu cầu');
    const parsed = z.strictObject({
      relationshipId: uuid, reason: z.string().trim().min(1).max(1000),
    }).safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu không hợp lệ');
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const relationship = await client.query(
        `SELECT id FROM coach_relationships WHERE id = $1 AND coach_id = $2
         AND status IN ('ACTIVE', 'PAUSED') FOR UPDATE`,
        [parsed.data.relationshipId, request.authUser.id],
      );
      if (!relationship.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy quan hệ hiện tại');
      }
      const created = await client.query(
        `INSERT INTO coach_termination_requests
         (id, relationship_id, coach_id, reason)
         VALUES ($1, $2, $3, $4) RETURNING *`,
        [randomUUID(), parsed.data.relationshipId, request.authUser.id,
          parsed.data.reason],
      );
      await client.query('COMMIT');
      return response.status(201).json({ data: created.rows[0] });
    } catch (cause) {
      await client.query('ROLLBACK').catch(() => {});
      return cause.code === '23505'
        ? fail(response, 409, 'REQUEST_EXISTS', 'Đã có yêu cầu đang chờ')
        : fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không gửi được yêu cầu');
    } finally { client.release(); }
  });

  router.get('/coach/termination-requests', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được xem yêu cầu');
    try {
      const result = await database.query(
        `SELECT id, relationship_id, coach_id, reason, status, admin_note,
                decided_at, created_at FROM coach_termination_requests
         WHERE coach_id = $1 ORDER BY created_at DESC, id DESC`,
        [request.authUser.id],
      );
      return response.json({ data: result.rows });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được yêu cầu'); }
  });

  router.get('/admin/relationships', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    try {
      const result = await database.query(
        `SELECT * FROM coach_relationships ORDER BY started_at DESC, id DESC`,
      );
      return response.json({ data: result.rows.map(relationshipView) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được quan hệ'); }
  });

  router.get('/admin/relationships/:relationshipId', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    if (!uuid.safeParse(request.params.relationshipId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã quan hệ không hợp lệ');
    try {
      const result = await database.query(
        'SELECT * FROM coach_relationships WHERE id = $1', [request.params.relationshipId],
      );
      return result.rows.length ? response.json({ data: relationshipView(result.rows[0]) })
        : fail(response, 404, 'NOT_FOUND', 'Không tìm thấy quan hệ');
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được quan hệ'); }
  });

  router.get('/admin/termination-requests', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    try {
      const result = await database.query(
        `SELECT id, relationship_id, coach_id, reason, status, admin_note,
                decided_at, created_at FROM coach_termination_requests
         ORDER BY created_at DESC, id DESC`,
      );
      return response.json({ data: result.rows });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được yêu cầu'); }
  });

  router.patch('/admin/termination-requests/:requestId', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    if (!uuid.safeParse(request.params.requestId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã yêu cầu không hợp lệ');
    const parsed = z.strictObject({
      decision: z.enum(['APPROVED', 'REJECTED']),
      note: z.string().trim().max(1000).nullable().optional(),
    }).safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Quyết định không hợp lệ');
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const admin = await client.query(
        `SELECT id FROM users WHERE id = $1 AND role = 'ADMIN' AND status = 'ACTIVE'
         AND session_version = $2 FOR SHARE`,
        [request.authUser.id, request.authUser.session_version],
      );
      if (!admin.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const lookup = await client.query(
        `SELECT relationship_id FROM coach_termination_requests WHERE id = $1`,
        [request.params.requestId],
      );
      if (!lookup.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy yêu cầu đang chờ');
      }
      const relationship = await client.query(
        `SELECT * FROM coach_relationships WHERE id = $1 FOR UPDATE`,
        [lookup.rows[0].relationship_id],
      );
      const item = await client.query(
        `SELECT * FROM coach_termination_requests WHERE id = $1 FOR UPDATE`,
        [request.params.requestId],
      );
      if (!item.rows.length || item.rows[0].status !== 'PENDING') {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy yêu cầu đang chờ');
      }
      if (!relationship.rows.length || relationship.rows[0].status === 'ENDED') {
        await client.query('ROLLBACK');
        return fail(response, 409, 'RELATIONSHIP_ENDED', 'Quan hệ đã kết thúc');
      }
      const updated = await client.query(
        `UPDATE coach_termination_requests SET status = $1, admin_note = $2,
         decided_by = $3, decided_at = now() WHERE id = $4 RETURNING *`,
        [parsed.data.decision, parsed.data.note ?? null,
          request.authUser.id, item.rows[0].id],
      );
      if (parsed.data.decision === 'APPROVED') {
        await client.query(
          `UPDATE coach_relationships SET status = 'ENDED', ended_at = now(),
           ended_by = $1, end_reason = $2 WHERE id = $3`,
          [request.authUser.id, item.rows[0].reason,
            relationship.rows[0].id],
        );
        await client.query(
          `UPDATE training_sessions SET status = 'CANCELLED', cancelled_at = now(),
           cancellation_reason = 'Quan hệ Coach đã kết thúc'
           WHERE relationship_id = $1 AND status = 'SCHEDULED'
           AND scheduled_start_at > now()`, [relationship.rows[0].id],
        );
      }
      await client.query(
        `INSERT INTO admin_audit_logs
         (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'TERMINATION_DECIDED', 'COACH_RELATIONSHIP', $3,
                 'Coach termination decided', $4)`,
        [randomUUID(), request.authUser.id, relationship.rows[0].id,
          JSON.stringify({ decision: parsed.data.decision })],
      );
      await client.query('COMMIT');
      return response.json({ data: updated.rows[0] });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không xử lý được yêu cầu');
    } finally { client.release(); }
  });

  router.post('/admin/coach-transfers', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    const parsed = z.strictObject({
      memberId: uuid, newCoachId: uuid,
      reason: z.string().trim().min(1).max(1000),
    }).safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu chuyển Coach không hợp lệ');
    const { memberId, newCoachId, reason } = parsed.data;
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const admin = await client.query(
        `SELECT id FROM users WHERE id = $1 AND role = 'ADMIN' AND status = 'ACTIVE'
         AND session_version = $2 FOR SHARE`,
        [request.authUser.id, request.authUser.session_version],
      );
      if (!admin.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const coach = await client.query(
        `SELECT u.id, c.member_limit FROM users u JOIN coach_profiles c
         ON c.user_id = u.id WHERE u.id = $1 AND u.role = 'COACH'
         AND u.status = 'ACTIVE' FOR UPDATE OF u`, [newCoachId],
      );
      if (!coach.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy Coach mới');
      }
      const member = await client.query(
        `SELECT id FROM users WHERE id = $1 AND role = 'MEMBER'
         AND status = 'ACTIVE' FOR UPDATE`, [memberId],
      );
      if (!member.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy Member');
      }
      const current = await client.query(
        `SELECT * FROM coach_relationships WHERE member_id = $1
         AND status IN ('ACTIVE', 'PAUSED') FOR UPDATE`, [memberId],
      );
      if (!current.rows.length || current.rows[0].coach_id === newCoachId) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'TRANSFER_NOT_ALLOWED', 'Quan hệ hoặc Coach mới không hợp lệ');
      }
      const used = await client.query(
        `SELECT count(*)::int AS count FROM coach_relationships
         WHERE coach_id = $1 AND status IN ('ACTIVE', 'PAUSED')`, [newCoachId],
      );
      if (used.rows[0].count >= coach.rows[0].member_limit) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'COACH_FULL', 'Coach mới đã đủ Member');
      }
      const old = current.rows[0];
      await client.query(
        `UPDATE coach_relationships SET status = 'ENDED', ended_at = now(),
         ended_by = $1, end_reason = $2 WHERE id = $3`,
        [request.authUser.id, reason, old.id],
      );
      await client.query(
        `UPDATE coach_termination_requests SET status = 'CANCELLED', decided_at = now()
         WHERE relationship_id = $1 AND status = 'PENDING'`, [old.id],
      );
      await client.query(
        `UPDATE training_sessions SET status = 'CANCELLED', cancelled_at = now(),
         cancellation_reason = 'Member được chuyển Coach'
         WHERE relationship_id = $1 AND status = 'SCHEDULED'
         AND scheduled_start_at > now()`, [old.id],
      );
      await client.query(
        `UPDATE training_plans SET status = 'ARCHIVED', archived_at = now()
         WHERE relationship_id = $1 AND status = 'ACTIVE'`, [old.id],
      );
      await client.query(
        `UPDATE nutrition_guides SET status = 'ARCHIVED', archived_at = now()
         WHERE relationship_id = $1 AND status = 'ACTIVE'`, [old.id],
      );
      const newId = randomUUID();
      const paused = old.status === 'PAUSED';
      await client.query(
        `INSERT INTO coach_relationships
         (id, member_id, coach_id, status, paused_at, pause_reason)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [newId, memberId, newCoachId, paused ? 'PAUSED' : 'ACTIVE',
          paused ? new Date() : null, paused ? old.pause_reason : null],
      );
      const conversationId = randomUUID();
      await client.query(
        `INSERT INTO conversations (id, relationship_id) VALUES ($1, $2)`,
        [conversationId, newId],
      );
      await client.query(
        `INSERT INTO conversation_participants (conversation_id, user_id)
         VALUES ($1, $2), ($1, $3)`,
        [conversationId, memberId, newCoachId],
      );
      await client.query(
        `INSERT INTO coach_transfer_history
         (id, member_id, old_relationship_id, new_relationship_id,
          old_coach_id, new_coach_id, reason, admin_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [randomUUID(), memberId, old.id, newId, old.coach_id,
          newCoachId, reason, request.authUser.id],
      );
      await client.query(
        `INSERT INTO admin_audit_logs
         (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'COACH_TRANSFERRED', 'COACH_RELATIONSHIP', $3,
                 'Member transferred to new Coach', $4)`,
        [randomUUID(), request.authUser.id, old.id,
          JSON.stringify({ memberId, oldCoachId: old.coach_id, newCoachId, reason })],
      );
      await client.query('COMMIT');
      return response.status(201).json({ data: {
        oldRelationshipId: old.id, newRelationshipId: newId,
        memberId, oldCoachId: old.coach_id, newCoachId,
      } });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không chuyển được Coach');
    } finally { client.release(); }
  });

  router.get('/admin/coach-transfers', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    try {
      const result = await database.query(
        `SELECT id, member_id, old_relationship_id, new_relationship_id,
                old_coach_id, new_coach_id, reason, admin_id, created_at
         FROM coach_transfer_history ORDER BY created_at DESC, id DESC`,
      );
      return response.json({ data: result.rows });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được lịch sử chuyển Coach'); }
  });

  return router;
}
