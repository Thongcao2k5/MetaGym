import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { settleCoachHold } from '../services/coach-entitlements.js';
import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();
const holdSchema = z.strictObject({
  coachId: uuid,
  planCode: z.string().trim().regex(/^[A-Z0-9][A-Z0-9_-]{1,39}$/),
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
        `SELECT (
           SELECT coach_id FROM coach_relationships WHERE member_id = $1
             AND status IN ('ACTIVE', 'PAUSED')
         ) AS current_coach, EXISTS (
           SELECT 1 FROM coach_entitlements WHERE member_id = $1 AND status = 'ACTIVE'
         ) AS has_package, EXISTS (
           SELECT 1 FROM coach_entitlements WHERE member_id = $1 AND status = 'QUEUED'
         ) AS has_queued, EXISTS (
           SELECT 1 FROM coach_payment_holds WHERE member_id = $1 AND status = 'HELD'
             AND expires_at > statement_timestamp()
         ) AS has_hold`, [memberId],
      )).rows[0];
      const renewal = unavailable.current_coach === coachId && unavailable.has_package;
      if (unavailable.current_coach && !renewal) return fail(response, 409, 'RELATIONSHIP_EXISTS', 'Member đã có Coach');
      if (unavailable.has_queued) return fail(response, 409, 'QUEUED_EXISTS', 'Member đã có gói Coach đang chờ');
      if (unavailable.has_hold) return fail(response, 409, 'HOLD_EXISTS', 'Member đã có suất đang giữ');

      const occupied = (await client.query(
        'SELECT coach_occupied_seats($1) AS count', [coachId],
      )).rows[0].count;
      if (!renewal && occupied >= Math.min(8, coach.member_limit)) {
        return fail(response, 409, 'COACH_FULL', 'Coach đã đủ Member');
      }
      const workdays = (await client.query(
        `SELECT weekday FROM coach_weekly_slots WHERE coach_id = $1
         GROUP BY weekday HAVING count(*) >= 4`, [coachId],
      )).rows.length;
      if (workdays < 6) {
        return fail(response, 409, 'SCHEDULE_REQUIRED', 'Coach chưa cấu hình đủ lịch làm việc');
      }
      const declaration = (await client.query(
        `SELECT health_declaration_completed_at FROM member_profiles
         WHERE user_id = $1`, [memberId],
      )).rows[0];
      if (!declaration?.health_declaration_completed_at) {
        return fail(response, 409, 'HEALTH_DECLARATION_REQUIRED',
          'Cần khai báo thể trạng trước khi thanh toán gói Coach');
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

  router.get('/coach-payment-holds', async (request, response) => {
    try {
      const { rows } = await database.query(
        `SELECT * FROM coach_payment_holds WHERE member_id = $1
         AND status = 'HELD' AND expires_at > statement_timestamp()`,
        [request.authUser.id],
      );
      return response.json({ data: rows.map(view) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được suất đang giữ');
    }
  });

  router.get('/coach-payment-holds/:id', async (request, response) => {
    const id = uuid.safeParse(request.params.id);
    if (!id.success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã giữ suất không hợp lệ');
    try {
      const { rows: [hold] } = await database.query(
        `SELECT *, CASE WHEN status = 'HELD' AND expires_at <= statement_timestamp()
                         THEN 'EXPIRED' ELSE status END AS effective_status
         FROM coach_payment_holds WHERE id = $1 AND member_id = $2`,
        [id.data, request.authUser.id],
      );
      if (!hold) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy suất đang giữ');
      return response.json({ data: view(hold) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không đọc được trạng thái giữ suất');
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

  router.post('/coach-payment-holds/:id/mock-confirmations', async (request, response) => {
    if (process.env.NODE_ENV === 'production' && process.env.ALLOW_MOCK_PAYMENTS !== 'true') {
      return fail(
        response,
        403,
        'MOCK_PAYMENT_DISABLED',
        'Thanh toán mô phỏng không khả dụng trên môi trường production',
      );
    }
    const id = uuid.safeParse(request.params.id);
    if (!id.success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã giữ suất không hợp lệ');
    try {
      const existing = (await database.query(
        `SELECT *, CASE WHEN status = 'HELD' AND expires_at <= statement_timestamp()
                        THEN 'EXPIRED' ELSE status END AS effective_status
         FROM coach_payment_holds WHERE id = $1 AND member_id = $2`,
        [id.data, request.authUser.id],
      )).rows[0];
      if (!existing) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy suất đang giữ');
      const settlement = await settleCoachHold(database, existing.id, {
        paid: true,
        amount: Number(existing.amount),
      });
      const updated = (await database.query(
        `SELECT *, CASE WHEN status = 'HELD' AND expires_at <= statement_timestamp()
                        THEN 'EXPIRED' ELSE status END AS effective_status
         FROM coach_payment_holds WHERE id = $1 AND member_id = $2`,
        [id.data, request.authUser.id],
      )).rows[0];
      if (settlement.status === 'CONSUMED') {
        const entitlement = (await database.query(
          'SELECT * FROM coach_entitlements WHERE id = $1',
          [settlement.entitlementId],
        )).rows[0];
        return response.json({
          data: {
            hold: view(updated ?? existing),
            entitlementId: settlement.entitlementId,
            entitlement,
          },
        });
      }
      const code = settlement.reason ?? settlement.status;
      const message = switchHoldSettlementMessage(code);
      return fail(response, 409, code, message);
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không xác nhận được thanh toán gói Coach');
    }
  });

  return router;
}

function switchHoldSettlementMessage(code) {
  switch (code) {
    case 'EXPIRED':
    case 'HOLD_EXPIRED':
      return 'Suất giữ đã hết hạn. Hãy chọn gói để giữ suất lại.';
    case 'CANCELLED':
      return 'Suất giữ đã được hủy trước đó.';
    case 'COACH_FULL':
      return 'Coach vừa đủ 8 Member. Hãy chọn Coach khác.';
    case 'CAPACITY_UNAVAILABLE':
      return 'Lịch Coach không còn đủ khung giờ trống cho gói này.';
    case 'MEMBERSHIP_REQUIRED':
    case 'PARTICIPANT_INELIGIBLE':
      return 'Cần có gói Gym đang hoạt động và tài khoản hợp lệ.';
    case 'QUEUED_UNAVAILABLE':
      return 'Bạn đã có gói Coach chờ kích hoạt.';
    case 'RELATIONSHIP_EXISTS':
      return 'Bạn đang có quan hệ với Coach khác.';
    default:
      return 'Không thể hoàn tất thanh toán cho suất giữ này.';
  }
}
