import { createHash, randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();
const paymentIntentSchema = z.strictObject({ planId: uuid });

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, details: {}, message } });
}

function publicPayment(row) {
  return {
    id: row.id, memberId: row.member_id, planId: row.plan_id,
    planName: row.plan_name_snapshot,
    durationDays: row.duration_days_snapshot,
    amount: Number(row.amount), method: row.method, status: row.status,
    transactionCode: row.transaction_code,
    ...(row.method === 'MOCK_QR' && row.status === 'PENDING'
      ? { qrPayload: `META-GYM-MOCK:${row.transaction_code}` } : {}),
    confirmedAt: row.confirmed_at, createdAt: row.created_at,
  };
}

function publicMembership(row) {
  return {
    id: row.id, memberId: row.member_id, planId: row.plan_id,
    sourcePaymentId: row.source_payment_id,
    startDate: row.start_date, endDate: row.end_date,
    status: row.status,
    planName: row.plan_name_snapshot ?? null,
  };
}

async function currentActor(client, user, role) {
  const result = await client.query(
    `SELECT id FROM users WHERE id = $1 AND role = $2 AND status = 'ACTIVE'
     AND session_version = $3 FOR UPDATE`,
    [user.id, role, user.session_version],
  );
  return result.rows.length === 1;
}

async function paymentById(client, id, lock = false) {
  const result = await client.query(
    `SELECT * FROM payments WHERE id = $1 ${lock ? 'FOR UPDATE' : ''}`, [id],
  );
  return result.rows[0];
}

async function membershipDates(client, memberId, durationDays) {
  const dates = await client.query(
    `WITH period AS (
       SELECT (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS today,
              GREATEST((now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
                (SELECT max(end_date) + 1 FROM member_memberships
                 WHERE member_id = $1 AND status <> 'CANCELLED')) AS start_date
     )
     SELECT today::text, start_date::text,
            (start_date + $2::int - 1)::text AS end_date FROM period`,
    [memberId, durationDays],
  );
  const { today, start_date: startDate, end_date: endDate } = dates.rows[0];
  return { today, startDate, endDate };
}

async function createMembership(client, payment) {
  const { today, startDate } = await membershipDates(client, payment.member_id, payment.duration_days_snapshot);
  const status = startDate === today ? 'ACTIVE' : 'SCHEDULED';
  const id = randomUUID();
  const created = await client.query(
    `INSERT INTO member_memberships
     (id, member_id, plan_id, source_payment_id, start_date, end_date,
      status, activated_at)
     VALUES ($1, $2, $3, $4, $5::date,
       $5::date + $6::int - 1, $7::varchar,
       CASE WHEN $7::varchar = 'ACTIVE' THEN now() END)
     RETURNING id, member_id, plan_id, source_payment_id,
               start_date::text, end_date::text, status`,
    [id, payment.member_id, payment.plan_id, payment.id,
      startDate, payment.duration_days_snapshot, status],
  );
  if (status === 'ACTIVE') {
    await client.query(
      `UPDATE coach_relationships SET status = 'ACTIVE', paused_at = NULL,
       pause_reason = NULL WHERE member_id = $1 AND status = 'PAUSED'
       AND pause_reason = 'MEMBERSHIP_EXPIRED'`, [payment.member_id],
    );
  }
  return publicMembership({ ...created.rows[0], plan_name_snapshot: payment.plan_name_snapshot });
}

export function createPaymentsRouter({ database, jwtSecret }) {
  const router = Router();
  router.use(createAuthentication({ database, jwtSecret }));

  router.get('/membership-plans/:planId/quote', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem dự kiến mua gói');
    const parsed = uuid.safeParse(request.params.planId);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã gói không hợp lệ');
    try {
      const { rows: [plan] } = await database.query(
        "SELECT price, duration_days FROM membership_plans WHERE id = $1 AND status = 'ACTIVE'",
        [parsed.data],
      );
      if (!plan) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy gói tập đang bán');
      const { startDate, endDate } = await membershipDates(database, request.authUser.id, plan.duration_days);
      return response.json({ data: { price: Number(plan.price), durationDays: plan.duration_days, startDate, endDate } });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được thông tin mua gói');
    }
  });

  router.post('/payments', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được tạo thanh toán');
    const parsed = paymentIntentSchema.safeParse(request.body);
    const key = request.get('idempotency-key');
    if (!parsed.success || !key || key.length > 100) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Gói tập hoặc Idempotency-Key không hợp lệ');
    }
    const hash = createHash('sha256').update(JSON.stringify(parsed.data)).digest('hex');
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      if (!await currentActor(client, request.authUser, 'MEMBER')) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const previous = await client.query(
        'SELECT * FROM payments WHERE created_by = $1 AND idempotency_key = $2',
        [request.authUser.id, key],
      );
      if (previous.rows.length) {
        await client.query('COMMIT');
        return previous.rows[0].request_hash === hash
          ? response.json({ data: publicPayment(previous.rows[0]) })
          : fail(response, 422, 'IDEMPOTENCY_KEY_CONFLICT', 'Khóa đã dùng với nội dung khác');
      }
      const plan = await client.query(
        `SELECT id, name, price, duration_days FROM membership_plans
         WHERE id = $1 AND status = 'ACTIVE'`, [parsed.data.planId],
      );
      if (!plan.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy gói tập đang bán');
      }
      const p = plan.rows[0];
      const id = randomUUID();
      const code = `MG-${id.slice(0, 18)}`;
      await client.query(
        `INSERT INTO payments
         (id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
          amount, method, transaction_code, idempotency_key, request_hash,
          created_by)
         VALUES ($1, $2, $3, $4, $5, $6, 'MOCK_QR', $7, $8, $9, $2)`,
        [id, request.authUser.id, p.id, p.name, p.duration_days, p.price,
          code, key, hash],
      );
      const payment = await paymentById(client, id);
      await client.query('COMMIT');
      return response.status(201).json({ data: publicPayment(payment) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tạo được thanh toán');
    } finally { client.release(); }
  });

  router.post('/payments/:paymentId/mock-confirmations', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xác nhận thanh toán');
    if (!uuid.safeParse(request.params.paymentId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã giao dịch không hợp lệ');
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      if (!await currentActor(client, request.authUser, 'MEMBER')) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const payment = await paymentById(client, request.params.paymentId, true);
      if (!payment || payment.member_id !== request.authUser.id || payment.method !== 'MOCK_QR') {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy giao dịch');
      }
      if (payment.status === 'SUCCESS') {
        const existing = await client.query(
          `SELECT id, member_id, plan_id, source_payment_id,
                  start_date::text, end_date::text, status
           FROM member_memberships WHERE source_payment_id = $1`, [payment.id],
        );
        if (!existing.rows[0]) throw new Error('Confirmed payment has no membership');
        await client.query('COMMIT');
        return response.json({ data: {
          payment: publicPayment(payment),
          membership: publicMembership({ ...existing.rows[0], plan_name_snapshot: payment.plan_name_snapshot }),
        } });
      }
      if (payment.status !== 'PENDING') {
        await client.query('ROLLBACK');
        return fail(response, 409, 'PAYMENT_NOT_PENDING', 'Giao dịch đã kết thúc');
      }
      const updated = await client.query(
        `UPDATE payments SET status = 'SUCCESS', confirmed_at = now(),
         decided_at = now() WHERE id = $1 AND status = 'PENDING' RETURNING *`,
        [payment.id],
      );
      if (!updated.rows.length) throw new Error('Payment state changed');
      const membership = await createMembership(client, updated.rows[0]);
      await client.query('COMMIT');
      return response.json({ data: {
        payment: publicPayment(updated.rows[0]), membership,
      } });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không xác nhận được thanh toán');
    } finally { client.release(); }
  });

  router.get('/payments/me', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem giao dịch');
    try {
      const result = await database.query(
        'SELECT * FROM payments WHERE member_id = $1 ORDER BY created_at DESC, id DESC',
        [request.authUser.id],
      );
      return response.json({ data: result.rows.map(publicPayment) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được giao dịch'); }
  });

  router.post('/payments/:paymentId/cancellations', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được hủy giao dịch');
    const { paymentId } = request.params;
    if (!uuid.safeParse(paymentId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã giao dịch không hợp lệ');
    try {
      const { rows: [payment] } = await database.query(
        `UPDATE payments SET status = 'CANCELLED', decided_at = now(),
           failure_reason = 'Member hủy thanh toán mô phỏng'
         WHERE id = $1 AND member_id = $2 AND method = 'MOCK_QR'
           AND status = 'PENDING'
         RETURNING *`,
        [paymentId, request.authUser.id],
      );
      if (payment) return response.json({ data: publicPayment(payment) });
      const existing = await paymentById(database, paymentId);
      if (existing?.member_id !== request.authUser.id || existing.method !== 'MOCK_QR') {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy giao dịch');
      }
      if (existing.status === 'CANCELLED') return response.json({ data: publicPayment(existing) });
      return fail(response, 409, 'PAYMENT_NOT_PENDING', 'Giao dịch đã kết thúc. Hãy kiểm tra lại trạng thái.');
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không hủy được giao dịch');
    }
  });

  router.get('/payments/:paymentId', async (request, response) => {
    if (!uuid.safeParse(request.params.paymentId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã giao dịch không hợp lệ');
    try {
      const payment = await paymentById(database, request.params.paymentId);
      if (!payment || (request.authUser.role !== 'ADMIN' && payment.member_id !== request.authUser.id)) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy giao dịch');
      }
      return response.json({ data: publicPayment(payment) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được giao dịch'); }
  });

  router.get('/memberships/me', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem gói tập');
    try {
      const result = await database.query(
        `SELECT id, member_id, plan_id, source_payment_id,
                start_date::text, end_date::text, status,
                (SELECT plan_name_snapshot FROM payments WHERE id = source_payment_id)
         FROM member_memberships WHERE member_id = $1
         AND status IN ('ACTIVE', 'SCHEDULED') ORDER BY start_date`,
        [request.authUser.id],
      );
      return response.json({ data: result.rows.map(publicMembership) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được gói tập'); }
  });

  router.get('/memberships/me/history', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem gói tập');
    try {
      const result = await database.query(
        `SELECT id, member_id, plan_id, source_payment_id,
                start_date::text, end_date::text, status,
                (SELECT plan_name_snapshot FROM payments WHERE id = source_payment_id)
         FROM member_memberships WHERE member_id = $1
         ORDER BY start_date DESC, id DESC`, [request.authUser.id],
      );
      return response.json({ data: result.rows.map(publicMembership) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được gói tập'); }
  });

  router.post('/admin/front-desk-payments', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    const parsed = z.strictObject({ memberId: uuid, planId: uuid }).safeParse(request.body);
    const key = request.get('idempotency-key');
    if (!parsed.success || !key || key.length > 100) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu thanh toán không hợp lệ');
    }
    const hash = createHash('sha256').update(JSON.stringify(parsed.data)).digest('hex');
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      if (!await currentActor(client, request.authUser, 'ADMIN')) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const previous = await client.query(
        'SELECT * FROM payments WHERE created_by = $1 AND idempotency_key = $2',
        [request.authUser.id, key],
      );
      if (previous.rows.length) {
        if (previous.rows[0].request_hash !== hash) {
          await client.query('ROLLBACK');
          return fail(response, 422, 'IDEMPOTENCY_KEY_CONFLICT', 'Khóa đã dùng với nội dung khác');
        }
        const membership = await client.query(
          `SELECT id, member_id, plan_id, source_payment_id,
                  start_date::text, end_date::text, status
           FROM member_memberships WHERE source_payment_id = $1`, [previous.rows[0].id],
        );
        await client.query('COMMIT');
        return response.json({ data: {
          payment: publicPayment(previous.rows[0]),
          membership: publicMembership(membership.rows[0]),
        } });
      }
      const member = await client.query(
        `SELECT id FROM users WHERE id = $1 AND role = 'MEMBER' AND status = 'ACTIVE'
         FOR UPDATE`, [parsed.data.memberId],
      );
      const plan = await client.query(
        `SELECT id, name, price, duration_days FROM membership_plans
         WHERE id = $1 AND status = 'ACTIVE'`, [parsed.data.planId],
      );
      if (!member.rows.length || !plan.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy Member hoặc gói tập');
      }
      const p = plan.rows[0];
      const id = randomUUID();
      const code = `MG-${id.slice(0, 18)}`;
      const inserted = await client.query(
        `INSERT INTO payments
         (id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
          amount, method, status, transaction_code, idempotency_key,
          request_hash, created_by, decided_by, confirmed_at, decided_at)
         VALUES ($1, $2, $3, $4, $5, $6, 'FRONT_DESK', 'SUCCESS',
                 $7, $8, $9, $10, $10, now(), now()) RETURNING *`,
        [id, parsed.data.memberId, p.id, p.name, p.duration_days, p.price,
          code, key, hash, request.authUser.id],
      );
      const membership = await createMembership(client, inserted.rows[0]);
      await client.query(
        `INSERT INTO admin_audit_logs
         (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'FRONT_DESK_PAYMENT_CONFIRMED', 'PAYMENT', $3,
                 'Front desk payment confirmed', $4)`,
        [randomUUID(), request.authUser.id, id,
          JSON.stringify({ memberId: parsed.data.memberId, planId: p.id })],
      );
      await client.query('COMMIT');
      return response.status(201).json({ data: {
        payment: publicPayment(inserted.rows[0]), membership,
      } });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không ghi nhận được thanh toán');
    } finally { client.release(); }
  });

  router.patch('/admin/payments/:paymentId', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    if (!uuid.safeParse(request.params.paymentId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã giao dịch không hợp lệ');
    const parsed = z.strictObject({
      status: z.enum(['FAILED', 'CANCELLED']), reason: z.string().trim().min(1).max(500),
    }).safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu không hợp lệ');
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      if (!await currentActor(client, request.authUser, 'ADMIN')) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const payment = await paymentById(client, request.params.paymentId, true);
      if (!payment) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy giao dịch');
      }
      if (payment.status !== 'PENDING') {
        await client.query('ROLLBACK');
        return fail(response, 409, 'PAYMENT_NOT_PENDING', 'Giao dịch đã kết thúc');
      }
      const updated = await client.query(
        `UPDATE payments SET status = $1, failure_reason = $2,
         decided_by = $3, decided_at = now() WHERE id = $4 AND status = 'PENDING'
         RETURNING *`,
        [parsed.data.status, parsed.data.reason, request.authUser.id, payment.id],
      );
      await client.query(
        `INSERT INTO admin_audit_logs
         (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'PAYMENT_DECIDED', 'PAYMENT', $3,
                 'Payment marked failed or cancelled', $4)`,
        [randomUUID(), request.authUser.id, payment.id,
          JSON.stringify({ status: parsed.data.status, reason: parsed.data.reason })],
      );
      await client.query('COMMIT');
      return response.json({ data: publicPayment(updated.rows[0]) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không cập nhật được giao dịch');
    } finally { client.release(); }
  });

  router.get('/admin/payments', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    try {
      const result = await database.query('SELECT * FROM payments ORDER BY created_at DESC, id DESC');
      return response.json({ data: result.rows.map(publicPayment) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được giao dịch'); }
  });

  router.get('/admin/memberships', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    try {
      const result = await database.query(
        `SELECT id, member_id, plan_id, source_payment_id,
                start_date::text, end_date::text, status
         FROM member_memberships ORDER BY start_date DESC, id DESC`,
      );
      return response.json({ data: result.rows.map(publicMembership) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được gói tập'); }
  });

  router.get('/admin/members/:memberId/memberships', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    if (!uuid.safeParse(request.params.memberId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã Member không hợp lệ');
    try {
      const result = await database.query(
        `SELECT id, member_id, plan_id, source_payment_id,
                start_date::text, end_date::text, status
         FROM member_memberships WHERE member_id = $1
         ORDER BY start_date DESC, id DESC`, [request.params.memberId],
      );
      return response.json({ data: result.rows.map(publicMembership) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được gói tập'); }
  });

  return router;
}
