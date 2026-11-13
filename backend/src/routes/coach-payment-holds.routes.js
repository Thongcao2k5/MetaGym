import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();
const holdSchema = z.strictObject({
  coachId: uuid,
  planCode: z.enum(['BASIC', 'STANDARD', 'ADVANCED']),
});

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, message, details: {} } });
}

function view(row) {
  return {
    id: row.id,
    coachId: row.coach_id,
    planCode: row.plan_code,
    planName: row.plan_name,
    sessionCount: row.session_count,
    durationDays: row.duration_days,
    amount: Number(row.amount),
    status: row.effective_status ?? row.status,
    expiresAt: row.expires_at,
  };
}

export function createCoachPaymentHoldsRouter({ database, jwtSecret }) {
  const router = Router();
  router.use('/coach-payment-holds', createAuthentication({ database, jwtSecret }));
  router.use('/coach-payment-holds', (request, response, next) =>
    request.authUser.role === 'MEMBER' ? next()
      : fail(response, 403, 'FORBIDDEN', 'Chỉ Member được giữ suất thuê Coach'));

  router.post('/coach-payment-holds', async (request, response) => {
    const parsed = holdSchema.safeParse(request.body);
    const requestKey = uuid.safeParse(request.get('idempotency-key'));
    if (!parsed.success || !requestKey.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Gói Coach hoặc Idempotency-Key không hợp lệ');
    }
    const { coachId, planCode } = parsed.data;
    const memberId = request.authUser.id;
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    let transactionOpen = false;
    try {
      await client.query('BEGIN');
      transactionOpen = true;
      // Use the same lock order as acceptance and Admin transfer in the legacy flow.
      const coach = (await client.query(
        `SELECT u.status, c.member_limit FROM users u
         JOIN coach_profiles c ON c.user_id = u.id
         WHERE u.id = $1 AND u.role = 'COACH' FOR UPDATE OF u`, [coachId],
      )).rows[0];
      const member = (await client.query(
        `SELECT id FROM users WHERE id = $1 AND status = 'ACTIVE' AND role = 'MEMBER'
         AND session_version = $2 FOR UPDATE`, [memberId, request.authUser.session_version],
      )).rows[0];
      if (!member) return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');

      const previous = (await client.query(
        `SELECT *, CASE WHEN status = 'HELD' AND expires_at <= statement_timestamp()
                        THEN 'EXPIRED' ELSE status END AS effective_status
         FROM coach_payment_holds WHERE member_id = $1 AND request_key = $2`,
        [memberId, requestKey.data],
      )).rows[0];
      if (previous) {
        if (previous.coach_id !== coachId || previous.plan_code !== planCode) {
          return fail(response, 409, 'IDEMPOTENCY_KEY_CONFLICT', 'Khóa đã dùng với nội dung khác');
        }
        return response.json({ data: view(previous) });
      }
      if (coach?.status !== 'ACTIVE') return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy Coach');

      const eligible = (await client.query(
        `SELECT 1 FROM member_memberships WHERE member_id = $1 AND status = 'ACTIVE'
          AND (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
              BETWEEN start_date AND end_date FOR SHARE`, [memberId],
      )).rows.length;
      if (!eligible) return fail(response, 409, 'MEMBERSHIP_REQUIRED', 'Cần có gói Gym đang hoạt động');

      const unavailable = (await client.query(
        `SELECT EXISTS (
           SELECT 1 FROM coach_relationships WHERE member_id = $1
             AND status IN ('ACTIVE', 'PAUSED')
         ) AS has_coach, EXISTS (
           SELECT 1 FROM coach_payment_holds WHERE member_id = $1 AND status = 'HELD'
             AND expires_at > statement_timestamp()
         ) AS has_hold`, [memberId],
      )).rows[0];
      if (unavailable.has_coach) return fail(response, 409, 'RELATIONSHIP_EXISTS', 'Member đã có Coach');
      if (unavailable.has_hold) return fail(response, 409, 'HOLD_EXISTS', 'Member đã có suất đang giữ');

      const occupied = (await client.query(
        'SELECT coach_occupied_seats($1) AS count', [coachId],
      )).rows[0].count;
      if (occupied >= Math.min(8, coach.member_limit)) {
        return fail(response, 409, 'COACH_FULL', 'Coach đã đủ Member');
      }
      const workdays = (await client.query(
        `SELECT weekday FROM coach_weekly_slots WHERE coach_id = $1
         GROUP BY weekday HAVING count(*) >= 4`, [coachId],
      )).rows.length;
      if (workdays < 6) {
        return fail(response, 409, 'SCHEDULE_REQUIRED', 'Coach chưa cấu hình đủ lịch làm việc');
      }
      const plan = (await client.query(
        "SELECT * FROM coach_package_plans WHERE code = $1 AND status = 'ACTIVE'",
        [planCode],
      )).rows[0];
      if (!plan) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy gói Coach đang bán');

      await client.query(
        `UPDATE coach_payment_holds SET status = 'EXPIRED'
         WHERE member_id = $1 AND status = 'HELD' AND expires_at <= statement_timestamp()`,
        [memberId],
      );
      const saved = await client.query(
        `INSERT INTO coach_payment_holds (
           id, member_id, coach_id, plan_code, plan_name, session_count, duration_days,
           amount, request_key, created_at, expires_at
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9,
           statement_timestamp(), statement_timestamp() + interval '15 minutes')
         RETURNING *`,
        [randomUUID(), memberId, coachId, planCode, plan.name, plan.session_count,
          plan.duration_days, plan.price, requestKey.data],
      );
      await client.query('COMMIT');
      transactionOpen = false;
      return response.status(201).json({ data: view(saved.rows[0]) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không giữ được suất Coach');
    } finally {
      if (transactionOpen) await client.query('ROLLBACK').catch(() => {});
      client.release();
    }
  });

  router.post('/coach-payment-holds/:id/cancel', async (request, response) => {
    const id = uuid.safeParse(request.params.id);
    if (!id.success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã giữ suất không hợp lệ');
    try {
      const result = await database.query(
        `UPDATE coach_payment_holds
         SET status = CASE WHEN expires_at <= statement_timestamp()
                           THEN 'EXPIRED' ELSE 'CANCELLED' END
         WHERE id = $1 AND member_id = $2 AND status = 'HELD' RETURNING *`,
        [id.data, request.authUser.id],
      );
      const hold = result.rows[0] ?? (await database.query(
        'SELECT * FROM coach_payment_holds WHERE id = $1 AND member_id = $2',
        [id.data, request.authUser.id],
      )).rows[0];
      if (!hold) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy suất đang giữ');
      return response.json({ data: view(hold) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không hủy được suất Coach');
    }
  });

  return router;
}
