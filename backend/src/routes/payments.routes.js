import { createHash, randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { vnpayAmount } from '../config/vnpay.js';
import { zalopayReference } from '../config/zalopay.js';
import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();
const paymentIntentSchema = z.strictObject({
  planId: uuid, method: z.enum(['ZALOPAY', 'MOMO', 'VNPAY', 'MOCK_QR']).default('MOCK_QR'),
});
const gatewayPrefixes = { VNPAY: 'vnpay', MOMO: 'momo', ZALOPAY: 'zalopay' };

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
    ...(row.renewed_membership_id ? { membershipId: row.renewed_membership_id } : {}),
    ...(row.method === 'MOCK_QR' && row.status === 'PENDING'
      ? { qrPayload: `META-GYM-MOCK:${row.transaction_code}` } : {}),
    confirmedAt: row.confirmed_at, createdAt: row.created_at,
  };
}

function checkoutPayment(row, vnpay, ip) {
  const url = row.status !== 'PENDING' ? undefined
    : row.method === 'ZALOPAY' ? row.zalopay_checkout_url
    : row.method === 'MOMO' ? row.momo_checkout_url
    : row.method === 'VNPAY' ? vnpay?.checkoutUrl(row, ip) : undefined;
  return { ...publicPayment(row), ...(url ? { paymentUrl: url } : {}) };
}

function publicMembership(row) {
  return {
    id: row.id, memberId: row.member_id, planId: row.plan_id,
    sourcePaymentId: row.source_payment_id,
    startDate: row.start_date, endDate: row.end_date,
    status: row.status,
    planName: row.plan_name_snapshot ?? null,
    ...(row.member_name !== undefined ? { memberName: row.member_name } : {}),
    ...(row.member_email !== undefined ? { memberEmail: row.member_email } : {}),
    ...(row.activated_at !== undefined ? { activatedAt: row.activated_at } : {}),
    ...(row.expired_at !== undefined ? { expiredAt: row.expired_at } : {}),
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
    `WITH business_day AS (
       SELECT (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS today
     ), period AS (
       SELECT today, GREATEST(today, max(end_date) + 1) AS start_date
       FROM business_day LEFT JOIN member_memberships
         ON member_id = $1 AND status <> 'CANCELLED'
       GROUP BY today
     )
     SELECT period.today::text, period.start_date::text,
            (period.start_date + $2::int - 1)::text AS end_date,
            m.id AS renewal_membership_id
     FROM period LEFT JOIN member_memberships m
       ON m.member_id = $1 AND m.status IN ('ACTIVE', 'SCHEDULED')
       AND period.today BETWEEN m.start_date AND m.end_date
       AND m.end_date = period.start_date - 1`,
    [memberId, durationDays],
  );
  const { today, start_date: startDate, end_date: endDate,
    renewal_membership_id: renewalMembershipId } = dates.rows[0];
  return { today, startDate, endDate, renewalMembershipId };
}

async function membershipForPayment(client, payment) {
  const { rows: [membership] } = await client.query(
    `SELECT m.id, m.member_id, m.plan_id, m.source_payment_id,
            m.start_date::text, m.end_date::text, m.status, original.plan_name_snapshot
     FROM member_memberships m JOIN payments original ON original.id = m.source_payment_id
     WHERE CASE WHEN $2::uuid IS NULL THEN m.source_payment_id = $1 ELSE m.id = $2 END`,
    [payment.id, payment.renewed_membership_id ?? null],
  );
  if (!membership) throw new Error('Confirmed payment has no membership');
  return publicMembership(membership);
}

async function applyMembershipPayment(client, payment) {
  // Both payment paths lock the member's user row before applying a payment.
  await client.query(`SELECT pg_advisory_xact_lock(hashtext('meta-gym-membership-lifecycle'))`);
  const { today, startDate, endDate, renewalMembershipId } =
    await membershipDates(client, payment.member_id, payment.duration_days_snapshot);
  await client.query(
    `UPDATE member_memberships SET status = 'EXPIRED', expired_at = now()
     WHERE member_id = $1 AND status = 'ACTIVE' AND end_date < $2::date`,
    [payment.member_id, today],
  );
  if (renewalMembershipId) {
    await client.query(
      `UPDATE member_memberships SET end_date = $2::date, status = 'ACTIVE',
       activated_at = COALESCE(activated_at, now()) WHERE id = $1`,
      [renewalMembershipId, endDate],
    );
    payment.renewed_membership_id = renewalMembershipId;
    await client.query('UPDATE payments SET renewed_membership_id = $2 WHERE id = $1',
      [payment.id, renewalMembershipId]);
    await resumeCoachRelationship(client, payment.member_id);
    return membershipForPayment(client, payment);
  }
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
  if (status === 'ACTIVE') await resumeCoachRelationship(client, payment.member_id);
  return publicMembership({ ...created.rows[0], plan_name_snapshot: payment.plan_name_snapshot });
}

async function resumeCoachRelationship(client, memberId) {
  await client.query(
    `UPDATE coach_relationships SET status = 'ACTIVE', paused_at = NULL,
     pause_reason = NULL WHERE member_id = $1 AND status = 'PAUSED'
     AND pause_reason = 'MEMBERSHIP_EXPIRED'`, [memberId],
  );
  // T2 §2 D1 edge case: if Member renews Gym while under COACH_LOCKED with un-frozen entitlement, start freeze now.
  await client.query(
    `WITH newly_frozen AS (
       UPDATE coach_entitlements e
       SET frozen_at = statement_timestamp()
       FROM coach_relationships r
       JOIN coach_lock_incidents i ON i.relationship_id = r.id AND i.status = 'OPEN'
       WHERE e.relationship_id = r.id
         AND r.member_id = $1
         AND r.status = 'PAUSED'
         AND r.pause_reason = 'COACH_LOCKED'
         AND e.status = 'ACTIVE'
         AND e.frozen_at IS NULL
         AND i.frozen_started_at IS NULL
       RETURNING i.id AS incident_id, e.frozen_at
     )
     UPDATE coach_lock_incidents i
     SET frozen_started_at = nf.frozen_at
     FROM newly_frozen nf
     WHERE i.id = nf.incident_id AND i.frozen_started_at IS NULL`,
    [memberId],
  );
}

async function gatewayPaymentByReference(client, reference, method) {
  const { rows: [payment] } = await client.query(
    'SELECT * FROM payments WHERE method = $1 AND transaction_code = $2', [method, reference],
  );
  return payment;
}

function matchesGatewayAmount(payment, gatewayResult) {
  const amount = payment.method === 'VNPAY' ? vnpayAmount(payment.amount) : payment.amount;
  return BigInt(gatewayResult.amount) === BigInt(amount);
}

async function applyGatewayResult(database, gatewayResult, method) {
  const vnPay = method === 'VNPAY';
  const prefix = gatewayPrefixes[method];
  const statusUpdate = vnPay ? ', vnpay_transaction_status = $7' : '';
  const client = await database.connect();
  try {
    await client.query('BEGIN');
    const existing = await gatewayPaymentByReference(client, gatewayResult.reference, method);
    if (!existing) {
      await client.query('ROLLBACK');
      return '01';
    }
    // Match the order of locks used by the member and front desk payment paths.
    await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [existing.member_id]);
    const payment = await paymentById(client, existing.id, true);
    if (!payment || !matchesGatewayAmount(payment, gatewayResult)) {
      await client.query('ROLLBACK');
      return payment ? '04' : '01';
    }
    if (payment.status !== 'PENDING') {
      await client.query('COMMIT');
      if (gatewayResult.result === 'SUCCESS' &&
          (payment.status !== 'SUCCESS' || payment[prefix + '_transaction_no'] !== gatewayResult.transactionNo)) {
        return '99';
      }
      return '02';
    }
    if (gatewayResult.result === 'PENDING') {
      await client.query('COMMIT');
      return '99';
    }
    const succeeded = gatewayResult.result === 'SUCCESS';
    const { rows: [updated] } = await client.query(
      `UPDATE payments SET status = $2, decided_at = now(),
         confirmed_at = CASE WHEN $6 THEN now() END,
         failure_reason = $3, ${prefix}_transaction_no = $4,
         ${prefix}_response_code = $5 ${statusUpdate}
       WHERE id = $1 RETURNING *`,
      [payment.id, gatewayResult.result, succeeded ? null : `${method} Sandbox: ${gatewayResult.responseCode}`,
        succeeded ? gatewayResult.transactionNo : null, gatewayResult.responseCode,
        succeeded, ...(vnPay ? [gatewayResult.providerStatus] : [])],
    );
    if (succeeded) await applyMembershipPayment(client, updated);
    await client.query('COMMIT');
    return '00';
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally { client.release(); }
}

async function reconcileGatewayPayment(database, gateway, payment, ip) {
  if (!gateway || payment.status !== 'PENDING') return payment;
  const column = gatewayPrefixes[payment.method] + '_last_query_at';
  const queryInterval = payment.method === 'ZALOPAY' ? '1 minute' : '30 seconds';
  const { rowCount } = await database.query(
    `UPDATE payments SET ${column} = now()
     WHERE id = $1 AND status = 'PENDING'
       AND (${column} IS NULL OR ${column} < now() - $2::interval)`,
    [payment.id, queryInterval],
  );
  if (rowCount) {
    const result = await gateway.queryPayment(payment, ip).catch(() => null);
    if (result) await applyGatewayResult(database, result, payment.method);
  }
  return paymentById(database, payment.id);
}

async function startRemoteCheckout(database, gateway, payment) {
  if (!gateway?.createCheckout || payment.status !== 'PENDING') return payment;
  const prefix = gatewayPrefixes[payment.method];
  const urlColumn = prefix + '_checkout_url';
  if (payment[urlColumn]) return payment;
  // Retries reuse the same provider request and order IDs, including after a network timeout.
  const checkout = await gateway.createCheckout(payment).catch(() => null);
  if (checkout?.url) {
    await database.query(
      `UPDATE payments SET ${urlColumn} = $2 WHERE id = $1 AND status = 'PENDING' AND ${urlColumn} IS NULL`,
      [payment.id, checkout.url],
    );
  } else if (checkout?.errorCode) {
    await database.query(
      `UPDATE payments SET status = 'FAILED', decided_at = now(), failure_reason = $2,
         ${prefix}_response_code = $3 WHERE id = $1 AND status = 'PENDING' AND ${urlColumn} IS NULL`,
      [payment.id, `${payment.method} Sandbox: ${checkout.errorCode}`, String(checkout.errorCode)],
    );
  }
  return paymentById(database, payment.id);
}

const ipnMessages = {
  '00': 'Confirm Success', '01': 'Order not found', '02': 'Order already confirmed',
  '04': 'Invalid amount', '97': 'Invalid checksum', '99': 'Unable to confirm',
};
const returnMessages = {
  SUCCESS: 'Thanh toán thành công', FAILED: 'Thanh toán thất bại',
  CANCELLED: 'Giao dịch đã hủy', PENDING: 'Đang chờ VNPay xác nhận',
};
const escapeAttribute = (value) => value.replace(/[&"<>]/g, (char) =>
  ({ '&': '&amp;', '"': '&quot;', '<': '&lt;', '>': '&gt;' })[char]);

export function createVnpayCallbacksRouter({ database, vnpay }) {
  const router = Router();
  router.use((_request, response, next) => {
    response.set('Cache-Control', 'no-store');
    next();
  });
  router.get('/ipn', async (request, response) => {
    let code = '99';
    if (vnpay) {
      try {
        const result = vnpay.verifyCallback(request.query);
        code = result ? await applyGatewayResult(database, result, 'VNPAY') : '97';
      } catch (error) {
        console.error('VNPay IPN could not be processed:', error.code ?? error.name);
      }
    }
    return response.json({ RspCode: code, Message: ipnMessages[code] });
  });
  router.get('/return', async (request, response) => {
    response.set('Referrer-Policy', 'no-referrer');
    if (!vnpay) return response.status(503).type('text/plain').send('VNPay Sandbox chưa được cấu hình.');
    const result = vnpay.verifyCallback(request.query);
    if (!result) return response.status(400).type('text/plain').send('Không xác thực được kết quả VNPay.');
    try {
      const order = await gatewayPaymentByReference(database, result.reference, 'VNPAY');
      if (!order) return response.status(404).type('text/plain').send('Không tìm thấy giao dịch.');
      if (!matchesGatewayAmount(order, result)) {
        return response.status(400).type('text/plain').send('Số tiền không khớp với giao dịch.');
      }
      // The browser result is only a hint. Settlement requires IPN or a signed server-side query.
      const payment = await reconcileGatewayPayment(database, vnpay, order, request.ip);
      return sendGatewayReturn(response, payment, vnpay.webReturnUrl, 'VNPay', 'vnpayPaymentId');
    } catch {
      return response.status(503).type('text/plain').send('Chưa kiểm tra được giao dịch. Hãy quay về MetaGym để thử lại.');
    }
  });
  return router;
}

function sendGatewayReturn(response, payment, webReturnUrl, gatewayName, hintKey) {
      const title = returnMessages[payment.status];
      const hint = hintKey + '=' + encodeURIComponent(payment.id);
      const appUrl = 'intent://payment-return/member/features/membership?' +
        hint + '#Intent;scheme=metagym;package=com.metagym.meta_gym_app;end';
      const webUrl = webReturnUrl ? new URL(webReturnUrl) : null;
      if (webUrl?.hash) {
        const route = new URL(webUrl.hash.slice(1), webUrl.origin);
        route.searchParams.set(hintKey, payment.id);
        webUrl.hash = route.pathname + route.search;
      } else if (webUrl) {
        webUrl.searchParams.set(hintKey, payment.id);
      }
      return response.type('html').send(
        `<!doctype html><html lang="vi"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
         <title>MetaGym · ${gatewayName} Sandbox</title><main><h1>${payment.status === 'PENDING'
           ? `Đang chờ ${gatewayName} xác nhận` : title}</h1>
         <p>Quay về MetaGym để xem trạng thái mới nhất của giao dịch.</p>
         <p><a href="${escapeAttribute(appUrl)}">Mở ứng dụng MetaGym</a></p>
         ${webUrl ? `<p><a href="${escapeAttribute(webUrl.href)}">Mở MetaGym Web</a></p>`
           : '<p>Nếu bạn trả tiền từ MetaGym Web, mở lại MetaGym và vào Gói tập hoặc Lịch sử thanh toán.</p>'}</main></html>`,
      );
}

export function createMomoCallbacksRouter({ database, momo }) {
  const router = Router();
  router.use((_request, response, next) => {
    response.set('Cache-Control', 'no-store');
    next();
  });
  router.post('/ipn', async (request, response) => {
    if (!momo) return response.sendStatus(503);
    const result = momo.verifyCallback(request.body);
    if (!result) return response.sendStatus(400);
    try {
      const code = await applyGatewayResult(database, result, 'MOMO');
      if (['00', '02'].includes(code) || (code === '99' && result.result === 'PENDING')) {
        return response.status(204).end();
      }
      return response.sendStatus(code === '01' ? 404 : code === '04' ? 400 : 409);
    } catch (error) {
      console.error('MoMo IPN could not be processed:', error.code ?? error.name);
      return response.sendStatus(500);
    }
  });
  router.get('/return', async (request, response) => {
    response.set('Referrer-Policy', 'no-referrer');
    if (!momo) return response.status(503).type('text/plain').send('MoMo Sandbox chưa được cấu hình.');
    const result = momo.verifyCallback(request.query);
    if (!result) return response.status(400).type('text/plain').send('Không xác thực được kết quả MoMo.');
    try {
      const order = await gatewayPaymentByReference(database, result.reference, 'MOMO');
      if (!order) return response.sendStatus(404);
      if (!matchesGatewayAmount(order, result)) return response.sendStatus(400);
      // IPN and the authenticated status endpoint settle the order. Browser redirects only display it.
      return sendGatewayReturn(response, order, momo.webReturnUrl, 'MoMo', 'momoPaymentId');
    } catch {
      return response.sendStatus(503);
    }
  });
  return router;
}

export function createZalopayCallbacksRouter({ database, zalopay }) {
  const router = Router();
  router.post('/callback', async (request, response) => {
    response.set('Cache-Control', 'no-store');
    const reply = (return_code, return_message) => response.json({ return_code, return_message });
    if (!zalopay) return reply(0, 'ZaloPay Sandbox unavailable');
    const notice = zalopay.verifyCallback(request.body);
    if (!notice) return reply(2, 'Invalid payment notification');
    try {
      const order = await gatewayPaymentByReference(database, notice.reference, 'ZALOPAY');
      if (!order || !matchesGatewayAmount(order, notice)) return reply(2, 'Order or amount mismatch');
      // The shared Sandbox Key2 is public. Only a trusted query may settle the order.
      const latest = await reconcileGatewayPayment(database, zalopay, order);
      if (latest?.status === 'SUCCESS' && latest.zalopay_transaction_no === notice.transactionNo) {
        return reply(1, 'Payment verified');
      }
      if (latest?.status === 'PENDING') return reply(0, 'Payment verification pending');
      return reply(2, 'Transaction mismatch');
    } catch (error) {
      console.error('ZaloPay callback could not be processed:', error.code ?? error.name);
      return reply(0, 'Payment verification unavailable');
    }
  });
  return router;
}

export function createPaymentsRouter({ database, jwtSecret, vnpay, momo, zalopay,
  allowMockPayments = !vnpay && !momo && !zalopay }) {
  const router = Router();
  const gateways = { VNPAY: vnpay, MOMO: momo, ZALOPAY: zalopay };
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
      const { startDate, endDate, renewalMembershipId } =
        await membershipDates(database, request.authUser.id, plan.duration_days);
      return response.json({ data: { price: Number(plan.price), durationDays: plan.duration_days,
        startDate, endDate, isRenewal: Boolean(renewalMembershipId) } });
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
    const { planId, method } = parsed.data;
    if (method === 'ZALOPAY' && !zalopay) {
      return fail(response, 503, 'ZALOPAY_NOT_CONFIGURED', 'ZaloPay Sandbox chưa được cấu hình.');
    }
    if (zalopay && ['MOMO', 'VNPAY'].includes(method)) {
      return fail(response, 409, 'CHECKOUT_METHOD_CHANGED', 'Hãy chọn ZaloPay Sandbox để thanh toán gói tập.');
    }
    if (method === 'MOMO' && !momo) {
      return fail(response, 503, 'MOMO_NOT_CONFIGURED', 'MoMo Sandbox chưa được cấu hình.');
    }
    if (method === 'VNPAY' && momo) {
      return fail(response, 409, 'VNPAY_CHECKOUT_DISABLED', 'Hãy chọn MoMo Sandbox để thanh toán gói tập.');
    }
    if (method === 'VNPAY' && !vnpay) {
      return fail(response, 503, 'VNPAY_NOT_CONFIGURED', 'VNPay Sandbox chưa được cấu hình.');
    }
    if (method === 'MOCK_QR' && !allowMockPayments) {
      return fail(response, 403, 'MOCK_PAYMENT_DISABLED', 'Hãy dùng VNPay Sandbox để thanh toán.');
    }
    response.set('Cache-Control', 'no-store');
    const intent = method === 'MOCK_QR' ? { planId } : { planId, method };
    const hash = createHash('sha256').update(JSON.stringify(intent)).digest('hex');
    let client = await database.connect().catch(() => null);
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
        client.release();
        client = null;
        const prior = previous.rows[0];
        return prior.request_hash === hash
          ? response.json({ data: checkoutPayment(
            await startRemoteCheckout(database, gateways[method], prior), vnpay, request.ip) })
          : fail(response, 422, 'IDEMPOTENCY_KEY_CONFLICT', 'Khóa đã dùng với nội dung khác');
      }
      if (Object.hasOwn(gateways, method)) {
        const pending = await client.query(
          "SELECT 1 FROM payments WHERE member_id = $1 AND method = $2 AND status = 'PENDING'",
          [request.authUser.id, method],
        );
        if (pending.rowCount) {
          await client.query('ROLLBACK');
          return fail(response, 409, method + '_PAYMENT_PENDING', 'Bạn có giao dịch đang chờ. Hãy kiểm tra giao dịch đó trước.');
        }
      }
      const plan = await client.query(
        `SELECT id, name, price, duration_days FROM membership_plans
         WHERE id = $1 AND status = 'ACTIVE'`, [planId],
      );
      if (!plan.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy gói tập đang bán');
      }
      const p = plan.rows[0];
      if (method === 'ZALOPAY' && (!Number.isSafeInteger(Number(p.price)) || Number(p.price) <= 0)) {
        await client.query('ROLLBACK');
        return fail(response, 422, 'ZALOPAY_INVALID_AMOUNT', 'Giá gói này không hợp lệ cho ZaloPay Sandbox.');
      }
      if (method === 'MOMO' && (Number(p.price) < 1000 || Number(p.price) > 50_000_000)) {
        await client.query('ROLLBACK');
        return fail(response, 422, 'MOMO_INVALID_AMOUNT', 'Giá gói này nằm ngoài mức thanh toán MoMo Sandbox.');
      }
      if (method === 'VNPAY' && !/^[1-9][0-9]{0,11}$/.test(vnpayAmount(p.price))) {
        await client.query('ROLLBACK');
        return fail(response, 422, 'VNPAY_INVALID_AMOUNT', 'Giá gói này nằm ngoài mức thanh toán VNPay Sandbox.');
      }
      const id = randomUUID();
      const code = method === 'ZALOPAY' ? zalopayReference(id)
        : method === 'MOMO' ? `MM${id.replaceAll('-', '')}`
        : method === 'VNPAY' ? `MG${id.replaceAll('-', '')}` : `MG-${id.slice(0, 18)}`;
      await client.query(
        `INSERT INTO payments
         (id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
          amount, method, transaction_code, idempotency_key, request_hash,
          created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $2)`,
        [id, request.authUser.id, p.id, p.name, p.duration_days, p.price,
          method, code, key, hash],
      );
      const payment = await paymentById(client, id);
      await client.query('COMMIT');
      client.release();
      client = null;
      return response.status(201).json({ data: checkoutPayment(
        await startRemoteCheckout(database, gateways[method], payment), vnpay, request.ip) });
    } catch {
      await client?.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tạo được thanh toán');
    } finally { client?.release(); }
  });

  router.post('/payments/:paymentId/mock-confirmations', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xác nhận thanh toán');
    if (!allowMockPayments) return fail(response, 403, 'MOCK_PAYMENT_DISABLED', 'Xác nhận giả lập đã được tắt.');
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
        const membership = await membershipForPayment(client, payment);
        await client.query('COMMIT');
        return response.json({ data: {
          payment: publicPayment(payment), membership,
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
      const membership = await applyMembershipPayment(client, updated.rows[0]);
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
      response.set('Cache-Control', 'no-store');
      return response.json({ data: result.rows.map((row) => checkoutPayment(row, vnpay, request.ip)) });
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
      response.set('Cache-Control', 'no-store');
      return response.json({ data: checkoutPayment(payment, vnpay, request.ip) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được giao dịch'); }
  });

  router.post('/payments/:paymentId/vnpay-status', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được kiểm tra thanh toán');
    if (!uuid.safeParse(request.params.paymentId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã giao dịch không hợp lệ');
    try {
      const payment = await paymentById(database, request.params.paymentId);
      if (!payment || payment.member_id !== request.authUser.id || payment.method !== 'VNPAY') {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy giao dịch VNPay');
      }
      const latest = await reconcileGatewayPayment(database, vnpay, payment, request.ip);
      response.set('Cache-Control', 'no-store');
      return response.json({ data: checkoutPayment(latest, vnpay, request.ip) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kiểm tra được giao dịch VNPay');
    }
  });

  router.post('/payments/:paymentId/momo-status', async (request, response) => {
    const id = uuid.safeParse(request.params.paymentId);
    if (!id.success || request.authUser.role !== 'MEMBER') return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy giao dịch');
    try {
      const payment = await paymentById(database, id.data);
      if (!payment || payment.member_id !== request.authUser.id || payment.method !== 'MOMO') {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy giao dịch');
      }
      const latest = await reconcileGatewayPayment(database, momo, payment, request.ip);
      const ready = await startRemoteCheckout(database, momo, latest);
      response.set('Cache-Control', 'no-store');
      return response.json({ data: checkoutPayment(ready, vnpay, request.ip) });
    } catch {
      return fail(response, 503, 'MOMO_STATUS_UNAVAILABLE', 'Chưa kiểm tra được giao dịch MoMo. Hãy thử lại.');
    }
  });

  router.post('/payments/:paymentId/zalopay-status', async (request, response) => {
    const id = uuid.safeParse(request.params.paymentId);
    if (!id.success || request.authUser.role !== 'MEMBER') return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy giao dịch');
    try {
      const payment = await paymentById(database, id.data);
      if (!payment || payment.member_id !== request.authUser.id || payment.method !== 'ZALOPAY') {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy giao dịch');
      }
      const latest = await reconcileGatewayPayment(database, zalopay, payment);
      const ready = await startRemoteCheckout(database, zalopay, latest);
      response.set('Cache-Control', 'no-store');
      return response.json({ data: checkoutPayment(ready, vnpay, request.ip) });
    } catch {
      return fail(response, 503, 'ZALOPAY_STATUS_UNAVAILABLE', 'Chưa kiểm tra được giao dịch ZaloPay. Hãy thử lại.');
    }
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
         AND NOT EXISTS (SELECT 1 FROM payments WHERE id = source_payment_id
                         AND renewed_membership_id IS NOT NULL)
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
        const membership = await membershipForPayment(client, previous.rows[0]);
        await client.query('COMMIT');
        return response.json({ data: {
          payment: publicPayment(previous.rows[0]),
          membership,
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
      const membership = await applyMembershipPayment(client, inserted.rows[0]);
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
      if (Object.hasOwn(gateways, payment.method)) {
        await client.query('ROLLBACK');
        return fail(response, 409, payment.method + '_CONTROLLED_PAYMENT', 'Giao dịch chỉ được cập nhật từ cổng thanh toán.');
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
    const parsed = z.strictObject({
      status: z.enum(['SCHEDULED', 'ACTIVE', 'EXPIRED', 'CANCELLED']).optional(),
      memberId: uuid.optional(),
      search: z.string().trim().max(120).optional(),
      page: z.coerce.number().int().min(1).default(1),
      pageSize: z.coerce.number().int().min(1).max(100).default(20),
    }).safeParse(request.query);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Bộ lọc không hợp lệ');
    const { status, memberId, search, page, pageSize } = parsed.data;
    const filters = [
      'p.renewed_membership_id IS NULL',
    ];
    const values = [];
    if (status) {
      values.push(status);
      filters.push(`m.status = $${values.length}`);
    }
    if (memberId) {
      values.push(memberId);
      filters.push(`m.member_id = $${values.length}`);
    }
    if (search) {
      const escaped = search.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
      values.push(`%${escaped}%`);
      const param = `$${values.length}`;
      filters.push(
        `(u.full_name ILIKE ${param} ESCAPE '\\' OR u.email::text ILIKE ${param} ESCAPE '\\' OR p.plan_name_snapshot ILIKE ${param} ESCAPE '\\')`,
      );
    }
    const whereClause = `WHERE ${filters.join(' AND ')}`;
    try {
      const [totalRes, result] = await Promise.all([
        database.query(
          `SELECT count(*)::int AS count
           FROM member_memberships m
           JOIN users u ON u.id = m.member_id
           JOIN payments p ON p.id = m.source_payment_id
           ${whereClause}`,
          values,
        ),
        database.query(
          `SELECT m.id, m.member_id, u.full_name AS member_name, u.email::text AS member_email,
                  m.plan_id, m.source_payment_id, p.plan_name_snapshot,
                  m.start_date::text, m.end_date::text, m.status,
                  m.activated_at, m.expired_at
           FROM member_memberships m
           JOIN users u ON u.id = m.member_id
           JOIN payments p ON p.id = m.source_payment_id
           ${whereClause}
           ORDER BY m.start_date DESC, m.id DESC
           LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
          [...values, pageSize, (page - 1) * pageSize],
        ),
      ]);
      const totalItems = totalRes.rows[0].count;
      return response.json({
        data: result.rows.map(publicMembership),
        pagination: {
          page,
          pageSize,
          totalItems,
          totalPages: Math.ceil(totalItems / pageSize),
        },
      });
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
         AND NOT EXISTS (SELECT 1 FROM payments WHERE id = source_payment_id
                         AND renewed_membership_id IS NOT NULL)
         ORDER BY start_date DESC, id DESC`, [request.params.memberId],
      );
      return response.json({ data: result.rows.map(publicMembership) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được gói tập'); }
  });

  return router;
}
