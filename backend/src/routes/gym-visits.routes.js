import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { awardGymCheckinPoints } from '../services/loyalty.js';
import { createAuthentication } from './users.routes.js';

const monthQuery = z.strictObject({ month: z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/) });
const scanBody = z.strictObject({ code: z.string().max(100) });

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, message, details: {} } });
}

export function createGymVisitsRouter({ database, jwtSecret }) {
  const router = Router();
  router.use(createAuthentication({ database, jwtSecret }));

  router.get('/admin/gym-checkin-code', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Chỉ Admin được xem mã điểm danh');
    try {
      const { rows: [row] } = await database.query('SELECT code, updated_at FROM gym_checkin_code WHERE id = 1');
      if (!row) return fail(response, 503, 'CHECKIN_NOT_CONFIGURED', 'Chưa cấu hình mã điểm danh');
      return response.json({ data: { payload: `metagym://gym-checkin/${row.code}`, updatedAt: row.updated_at } });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được mã điểm danh'); }
  });

  router.post('/admin/gym-checkin-code/rotate', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Chỉ Admin được đổi mã điểm danh');
    let client;
    try {
      client = await database.connect();
      await client.query('BEGIN');
      const admin = await client.query(
        `SELECT u.id FROM users u WHERE u.id = $1 AND u.role = 'ADMIN' AND u.status = 'ACTIVE'
         AND u.session_version = $2 FOR SHARE`,
        [request.authUser.id, request.authUser.session_version],
      );
      if (admin.rows.length !== 1) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const code = randomUUID();
      const { rows: [row] } = await client.query(
        'UPDATE gym_checkin_code SET code = $1, updated_at = now() WHERE id = 1 RETURNING updated_at', [code],
      );
      if (!row) { await client.query('ROLLBACK'); return fail(response, 503, 'CHECKIN_NOT_CONFIGURED', 'Chưa cấu hình mã điểm danh'); }
      await client.query(
        `INSERT INTO admin_audit_logs (id, admin_id, action, entity_type, entity_id, summary)
         VALUES ($1, $2, 'GYM_CHECKIN_CODE_ROTATED', 'GYM_CHECKIN_CODE', '1',
           'Đổi mã điểm danh QR tại quầy')`, [randomUUID(), request.authUser.id],
      );
      await client.query('COMMIT');
      return response.json({ data: { payload: `metagym://gym-checkin/${code}`, updatedAt: row.updated_at } });
    } catch {
      if (client) await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không đổi được mã điểm danh');
    } finally { client?.release(); }
  });

  router.get('/gym-visits/me', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ hội viên được xem lịch sử đến gym');
    const parsed = monthQuery.safeParse(request.query);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Tháng không hợp lệ');
    const from = `${parsed.data.month}-01`;
    try {
      const { rows } = await database.query(
        `SELECT id, visit_day::text AS day, checked_in_at, gym_name, gym_address
         FROM gym_visits WHERE member_id = $1 AND visit_day >= $2::date
           AND visit_day < ($2::date + interval '1 month')
         ORDER BY checked_in_at DESC, id DESC`, [request.authUser.id, from],
      );
      const { rows: [coverage] } = await database.query(
        `SELECT count(DISTINCT d.day)::int AS eligible_days
         FROM member_memberships m
         CROSS JOIN LATERAL generate_series(
           greatest(m.start_date, $2::date),
           least(m.end_date, ($2::date + interval '1 month - 1 day')::date,
             (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date),
           interval '1 day') AS d(day)
         WHERE m.member_id = $1 AND m.status IN ('ACTIVE', 'EXPIRED')`,
        [request.authUser.id, from],
      );
      return response.json({ data: {
        month: parsed.data.month,
        visitedDays: new Set(rows.map((row) => row.day)).size,
        entryCount: rows.length,
        eligibleDays: coverage.eligible_days,
        visits: rows.map((row) => ({ id: row.id, day: row.day,
          checkedInAt: row.checked_in_at, gymName: row.gym_name,
          gymAddress: row.gym_address })),
      } });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được lịch sử đến gym'); }
  });

  router.post('/gym-visits/check-in', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ hội viên được điểm danh');
    const parsed = scanBody.safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã QR không hợp lệ');
    const match = /^metagym:\/\/gym-checkin\/([0-9a-f-]{36})$/i.exec(parsed.data.code);
    if (!match || !z.uuid().safeParse(match[1]).success) return fail(response, 422, 'INVALID_QR', 'Đây không phải mã điểm danh Meta Gym');
    let client;
    try {
      client = await database.connect();
      await client.query('BEGIN');
      const { rows: [valid] } = await client.query(
        'SELECT 1 FROM gym_checkin_code WHERE id = 1 AND code = $1::uuid FOR SHARE', [match[1]],
      );
      if (!valid) { await client.query('ROLLBACK'); return fail(response, 422, 'INVALID_QR', 'Mã điểm danh đã hết hiệu lực'); }
      const { rows: [membership] } = await client.query(
        `SELECT 1 FROM member_memberships WHERE member_id = $1 AND status = 'ACTIVE'
         AND start_date <= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
         AND end_date >= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date LIMIT 1`,
        [request.authUser.id],
      );
      if (!membership) { await client.query('ROLLBACK'); return fail(response, 403, 'GYM_PACKAGE_REQUIRED', 'Cần gói tập còn hiệu lực để điểm danh'); }
      const { rows: [visit] } = await client.query(
        `INSERT INTO gym_visits (id, member_id, visit_day, gym_name, gym_address)
         SELECT $1, $2, (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date, name, address
         FROM gym_profile WHERE id = 1
         RETURNING id, visit_day::text AS day, checked_in_at, gym_name, gym_address`,
        [randomUUID(), request.authUser.id],
      );
      if (!visit) {
        await client.query('ROLLBACK');
        return fail(response, 503, 'GYM_NOT_CONFIGURED', 'Chưa cấu hình phòng gym');
      }
      const loyalty = await awardGymCheckinPoints(client, {
        memberId: request.authUser.id,
        visitId: visit.id,
      });
      await client.query('COMMIT');
      return response.status(201).json({ data: { id: visit.id, day: visit.day,
        checkedInAt: visit.checked_in_at, gymName: visit.gym_name,
        gymAddress: visit.gym_address,
        ...(loyalty?.pointsEarned ? { loyaltyPointsEarned: loyalty.pointsEarned } : {}) } });
    } catch {
      if (client) await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không ghi được lượt đến gym');
    } finally { client?.release(); }
  });

  return router;
}
