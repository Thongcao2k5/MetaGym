import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'web-admin-t11-payments-d6-secret-32-chars';

function token(id, role, sessionVersion = 0) {
  return jwt.sign({ role, sessionVersion }, secret, {
    algorithm: 'HS256',
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    subject: id,
    expiresIn: 3600,
  });
}

async function call(base, path, bearer, method = 'GET', body, headers = {}) {
  const response = await fetch(`${base}/api/v1${path}`, {
    method,
    headers: {
      ...(bearer ? { authorization: `Bearer ${bearer}` } : {}),
      ...headers,
      ...(body === undefined ? {} : { 'content-type': 'application/json' }),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: response.status, body: await response.json() };
}

test('T11: Admin payments search/detail, D6 VOID_REVERSAL immutability & 5 error codes, LIFO renewals, and 0031 formula check',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const app = createApp({ database, jwtSecret: secret });
    const server = app.listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;

    const adminId = randomUUID();
    const coachId = randomUUID();
    const m1Id = randomUUID(); // same-day standalone void + replacement + mock-qr reject
    const m2Id = randomUUID(); // past-day unused SCHEDULED vs past-day used gym_visits
    const m3Id = randomUUID(); // coach dependency block
    const m4Id = randomUUID(); // renewal extension LIFO + shrink end_date + EXPIRED transition
    const memberIds = [m1Id, m2Id, m3Id, m4Id];
    const adminToken = token(adminId, 'ADMIN');
    const m1Token = token(m1Id, 'MEMBER');
    const m3Token = token(m3Id, 'MEMBER');
    let plan30Id;
    let plan60Id;
    let plan90Id;

    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Admin T11'),
                ($3, $4, 'hash', 'COACH', 'Coach T11'),
                ($5, $6, 'hash', 'MEMBER', 'Trần Văn An'),
                ($7, $8, 'hash', 'MEMBER', 'Lê Thị Bình'),
                ($9, $10, 'hash', 'MEMBER', 'Phạm Quốc Cường'),
                ($11, $12, 'hash', 'MEMBER', 'Vũ Minh Dũng')`,
        [
          adminId, `${adminId}@example.com`,
          coachId, `${coachId}@example.com`,
          m1Id, `an-${m1Id}@example.com`,
          m2Id, `binh-${m2Id}@example.com`,
          m3Id, `cuong-${m3Id}@example.com`,
          m4Id, `dung-${m4Id}@example.com`,
        ],
      );
      await database.query('INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 8)', [coachId]);
      for (const mid of memberIds) {
        await database.query(
          `INSERT INTO member_profiles (user_id, height_cm, weight_kg, health_declaration_completed_at)
           VALUES ($1, 170, 68, now())`,
          [mid],
        );
      }
      await database.query(
        `INSERT INTO coach_weekly_slots (id, coach_id, weekday, start_minute)
         SELECT gen_random_uuid(), $1, d, m
         FROM generate_series(1, 6) d CROSS JOIN generate_series(360, 630, 90) m`,
        [coachId],
      );
      await database.query("UPDATE coach_package_plans SET status = 'ACTIVE', price = 2000000 WHERE code = 'BASIC'");

      // Create Gym plans
      plan30Id = (await call(base, '/admin/membership-plans', adminToken, 'POST', {
        name: 'Gym 30 ngày', price: 600000, durationDays: 30, status: 'ACTIVE',
      })).body.data.id;
      plan60Id = (await call(base, '/admin/membership-plans', adminToken, 'POST', {
        name: 'Gym 60 ngày', price: 1100000, durationDays: 60, status: 'ACTIVE',
      })).body.data.id;
      plan90Id = (await call(base, '/admin/membership-plans', adminToken, 'POST', {
        name: 'Gym 90 ngày', price: 1500000, durationDays: 90, status: 'ACTIVE',
      })).body.data.id;

      // 1. D6 Case 1: Same VN day standalone FRONT_DESK payment -> VOID_REVERSAL + idempotency + replacement
      const wrongPayRes = await call(
        base,
        '/admin/front-desk-payments',
        adminToken,
        'POST',
        { memberId: m1Id, planId: plan90Id },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(wrongPayRes.status, 201);
      const wrongPayId = wrongPayRes.body.data.payment.id;
      const wrongMemId = wrongPayRes.body.data.membership.id;

      // Missing/invalid Idempotency-Key -> 422
      assert.equal((await call(
        base,
        `/admin/payments/${wrongPayId}/void-reversal`,
        adminToken,
        'POST',
        { reason: 'Nhập nhầm gói 90 ngày thay vì 30 ngày' },
      )).status, 422);

      // GET /admin/payments list shows memberName, canVoidReversal: true
      const listBefore = await call(base, `/admin/payments?memberId=${m1Id}&method=FRONT_DESK&adjusted=false&search=Tr%E1%BA%A7n%20V%C4%83n%20An`, adminToken);
      assert.equal(listBefore.status, 200);
      assert.equal(listBefore.body.pagination.totalItems, 1);
      assert.equal(listBefore.body.data[0].memberName, 'Trần Văn An');
      assert.equal(listBefore.body.data[0].canVoidReversal, true);
      assert.equal(listBefore.body.data[0].voidBlockedReason, null);
      assert.equal(listBefore.body.data[0].adjustment, null);

      const voidKey1 = randomUUID();
      const voidRes = await call(
        base,
        `/admin/payments/${wrongPayId}/void-reversal`,
        adminToken,
        'POST',
        { reason: 'Thu ngân chọn nhầm gói 90 ngày thay vì gói 30 ngày' },
        { 'idempotency-key': voidKey1 },
      );
      assert.equal(voidRes.status, 201, JSON.stringify(voidRes.body));
      assert.equal(voidRes.body.data.adjustment.adjustmentType, 'VOID_REVERSAL');
      assert.equal(voidRes.body.data.adjustment.reversedAmount, 1500000);
      assert.equal(voidRes.body.data.adjustment.previousMembershipStatus, 'ACTIVE');
      assert.equal(voidRes.body.data.adjustment.newMembershipStatus, 'CANCELLED');
      assert.equal(voidRes.body.data.adjustment.restoredEndDate, null);
      assert.equal(voidRes.body.data.payment.status, 'SUCCESS');
      assert.equal(voidRes.body.data.payment.amount, 1500000);

      // Verify payments row is IMMUTABLE and membership is CANCELLED (expired_at IS NULL)
      const payRow = (await database.query('SELECT status, amount FROM payments WHERE id = $1', [wrongPayId])).rows[0];
      assert.equal(payRow.status, 'SUCCESS');
      assert.equal(Number(payRow.amount), 1500000);
      const memRow = (await database.query('SELECT status, expired_at FROM member_memberships WHERE id = $1', [wrongMemId])).rows[0];
      assert.equal(memRow.status, 'CANCELLED');
      assert.equal(memRow.expired_at, null);

      // Idempotent retry same key + same reason -> 200 OK
      const voidReplay = await call(
        base,
        `/admin/payments/${wrongPayId}/void-reversal`,
        adminToken,
        'POST',
        { reason: 'Thu ngân chọn nhầm gói 90 ngày thay vì gói 30 ngày' },
        { 'idempotency-key': voidKey1 },
      );
      assert.equal(voidReplay.status, 200);
      assert.equal(voidReplay.body.data.adjustment.id, voidRes.body.data.adjustment.id);

      // Same key + different reason -> 409 IDEMPOTENCY_KEY_CONFLICT
      const voidConflict = await call(
        base,
        `/admin/payments/${wrongPayId}/void-reversal`,
        adminToken,
        'POST',
        { reason: 'Lý do khác' },
        { 'idempotency-key': voidKey1 },
      );
      assert.equal(voidConflict.status, 409);
      assert.equal(voidConflict.body.error.code, 'IDEMPOTENCY_KEY_CONFLICT');

      // New key on already reversed payment -> 409 PAYMENT_ALREADY_REVERSED
      const voidAgain = await call(
        base,
        `/admin/payments/${wrongPayId}/void-reversal`,
        adminToken,
        'POST',
        { reason: 'Đảo lần 2' },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(voidAgain.status, 409);
      assert.equal(voidAgain.body.error.code, 'PAYMENT_ALREADY_REVERSED');

      // Audit PAYMENT_VOID_REVERSED written
      const voidAudit = await database.query(
        `SELECT action, metadata FROM admin_audit_logs WHERE entity_id = $1 AND action = 'PAYMENT_VOID_REVERSED'`,
        [wrongPayId],
      );
      assert.equal(voidAudit.rowCount, 1);
      assert.equal(voidAudit.rows[0].metadata.reversedAmount, 1500000);

      // GET /admin/payments/:paymentId detail shows linked membership & adjustment
      const payDetail = await call(base, `/admin/payments/${wrongPayId}`, adminToken);
      assert.equal(payDetail.status, 200);
      assert.equal(payDetail.body.data.adjustment.id, voidRes.body.data.adjustment.id);
      assert.equal(payDetail.body.data.membership.status, 'CANCELLED');
      assert.equal(payDetail.body.data.canVoidReversal, false);

      // Replacement clean front-desk payment succeeds
      const replacementPay = await call(
        base,
        '/admin/front-desk-payments',
        adminToken,
        'POST',
        { memberId: m1Id, planId: plan30Id },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(replacementPay.status, 201);
      assert.equal(replacementPay.body.data.membership.status, 'ACTIVE');

      // 2. D6 Error 1: ONLY_FRONT_DESK_ADJUSTABLE (MOCK_QR payment cannot be void-reversed)
      const qrPayCreate = await call(
        base,
        '/payments',
        m1Token,
        'POST',
        { planId: plan30Id },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(qrPayCreate.status, 201);
      const qrPayId = qrPayCreate.body.data.id;
      await call(base, `/payments/${qrPayId}/mock-confirmations`, m1Token, 'POST');
      const voidQr = await call(
        base,
        `/admin/payments/${qrPayId}/void-reversal`,
        adminToken,
        'POST',
        { reason: 'Thử đảo giao dịch online' },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(voidQr.status, 409);
      assert.equal(voidQr.body.error.code, 'ONLY_FRONT_DESK_ADJUSTABLE');

      // 3. D6 Error 3: PAYMENT_ADJUSTMENT_WINDOW_EXPIRED (prior VN day + gym_visits usage) vs unused prior-day allowed
      const m2Pay = await call(
        base,
        '/admin/front-desk-payments',
        adminToken,
        'POST',
        { memberId: m2Id, planId: plan30Id },
        { 'idempotency-key': randomUUID() },
      );
      const m2PayId = m2Pay.body.data.payment.id;
      const m2MemId = m2Pay.body.data.membership.id;
      // Backdate payment and membership start by 3 days (prior VN day, ZERO visits yet -> still allowed!)
      await database.query(
        `UPDATE payments SET confirmed_at = now() - interval '3 days', decided_at = now() - interval '3 days' WHERE id = $1`,
        [m2PayId],
      );
      await database.query(
        `UPDATE member_memberships SET start_date = start_date - 3, end_date = end_date - 3 WHERE id = $1`,
        [m2MemId],
      );
      const m2DetailUnused = await call(base, `/admin/payments/${m2PayId}`, adminToken);
      assert.equal(m2DetailUnused.body.data.canVoidReversal, true);

      // Now add a gym_visit 2 days ago inside the membership period -> MUST block with PAYMENT_ADJUSTMENT_WINDOW_EXPIRED!
      await database.query(
        `INSERT INTO gym_visits (id, member_id, visit_day, checked_in_at, gym_name, gym_address)
         VALUES ($1, $2, ((now() - interval '2 days') AT TIME ZONE 'Asia/Ho_Chi_Minh')::date, now() - interval '2 days', 'Meta Gym', 'Hanoi')`,
        [randomUUID(), m2Id],
      );
      const voidExpired = await call(
        base,
        `/admin/payments/${m2PayId}/void-reversal`,
        adminToken,
        'POST',
        { reason: 'Đã dùng rồi vẫn thử đảo' },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(voidExpired.status, 409);
      assert.equal(voidExpired.body.error.code, 'PAYMENT_ADJUSTMENT_WINDOW_EXPIRED');

      // 4. D6 Error 4: PAYMENT_HAS_COACH_DEPENDENCY
      const m3Pay = await call(
        base,
        '/admin/front-desk-payments',
        adminToken,
        'POST',
        { memberId: m3Id, planId: plan30Id },
        { 'idempotency-key': randomUUID() },
      );
      const m3PayId = m3Pay.body.data.payment.id;
      // Member creates a Coach payment hold after Gym payment confirmed
      const m3Hold = await call(
        base,
        '/coach-payment-holds',
        m3Token,
        'POST',
        { coachId, planCode: 'BASIC' },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(m3Hold.status, 201);
      const voidCoachDep = await call(
        base,
        `/admin/payments/${m3PayId}/void-reversal`,
        adminToken,
        'POST',
        { reason: 'Thử đảo khi có hold Coach' },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(voidCoachDep.status, 409);
      assert.equal(voidCoachDep.body.error.code, 'PAYMENT_HAS_COACH_DEPENDENCY');

      // 5. D6 Walkthrough 4 + Error 5: RENEWAL_LIFO_REQUIRED & end_date shrink on renewal extension
      const m4Base = await call(
        base,
        '/admin/front-desk-payments',
        adminToken,
        'POST',
        { memberId: m4Id, planId: plan30Id },
        { 'idempotency-key': randomUUID() },
      );
      const m4BasePayId = m4Base.body.data.payment.id;
      const m4MemId = m4Base.body.data.membership.id;
      const baseEndDate = m4Base.body.data.membership.endDate;

      const m4Ren1 = await call(
        base,
        '/admin/front-desk-payments',
        adminToken,
        'POST',
        { memberId: m4Id, planId: plan30Id },
        { 'idempotency-key': randomUUID() },
      );
      const m4Ren1PayId = m4Ren1.body.data.payment.id;
      const ren1EndDate = m4Ren1.body.data.membership.endDate;
      assert.equal(m4Ren1.body.data.membership.id, m4MemId);

      const m4Ren2 = await call(
        base,
        '/admin/front-desk-payments',
        adminToken,
        'POST',
        { memberId: m4Id, planId: plan60Id },
        { 'idempotency-key': randomUUID() },
      );
      const m4Ren2PayId = m4Ren2.body.data.payment.id;
      const ren2EndDate = m4Ren2.body.data.membership.endDate;
      assert.equal(m4Ren2.body.data.membership.id, m4MemId);

      // Trying to reverse Base or Renewal 1 while Renewal 2 is unreversed -> 409 RENEWAL_LIFO_REQUIRED
      const lifoBase = await call(
        base,
        `/admin/payments/${m4BasePayId}/void-reversal`,
        adminToken,
        'POST',
        { reason: 'Đảo sai thứ tự base' },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(lifoBase.status, 409);
      assert.equal(lifoBase.body.error.code, 'RENEWAL_LIFO_REQUIRED');

      const lifoRen1 = await call(
        base,
        `/admin/payments/${m4Ren1PayId}/void-reversal`,
        adminToken,
        'POST',
        { reason: 'Đảo sai thứ tự renewal 1' },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(lifoRen1.status, 409);
      assert.equal(lifoRen1.body.error.code, 'RENEWAL_LIFO_REQUIRED');

      // Backdate chronologically: Base (-5d) < Renewal 1 (-4d) < Renewal 2 (-2d),
      // and add a check-in TODAY (in base period, NOT in Renewal 2's tail!).
      // Renewal 2 tail is still unused -> MUST succeed and shrink end_date back to ren1EndDate!
      await database.query(
        `UPDATE payments SET confirmed_at = now() - interval '5 days', decided_at = now() - interval '5 days' WHERE id = $1`,
        [m4BasePayId],
      );
      await database.query(
        `UPDATE payments SET confirmed_at = now() - interval '4 days', decided_at = now() - interval '4 days' WHERE id = $1`,
        [m4Ren1PayId],
      );
      await database.query(
        `UPDATE payments SET confirmed_at = now() - interval '2 days', decided_at = now() - interval '2 days' WHERE id = $1`,
        [m4Ren2PayId],
      );
      await database.query(
        `INSERT INTO gym_visits (id, member_id, visit_day, checked_in_at, gym_name, gym_address)
         VALUES ($1, $2, (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date, now(), 'Meta Gym', 'Hanoi')`,
        [randomUUID(), m4Id],
      );

      const voidRen2 = await call(
        base,
        `/admin/payments/${m4Ren2PayId}/void-reversal`,
        adminToken,
        'POST',
        { reason: 'Nhập nhầm gia hạn 60 ngày thay vì 30 ngày' },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(voidRen2.status, 201, JSON.stringify(voidRen2.body));
      assert.equal(voidRen2.body.data.adjustment.previousEndDate, ren2EndDate);
      assert.equal(voidRen2.body.data.adjustment.restoredEndDate, ren1EndDate);
      assert.equal(voidRen2.body.data.adjustment.newMembershipStatus, 'ACTIVE');

      const m4AfterRen2 = (await database.query(
        'SELECT end_date::text, status FROM member_memberships WHERE id = $1',
        [m4MemId],
      )).rows[0];
      assert.equal(m4AfterRen2.end_date, ren1EndDate);
      assert.equal(m4AfterRen2.status, 'ACTIVE');

      // Now Renewal 1 IS at top of LIFO stack -> voiding Renewal 1 shrinks end_date back to baseEndDate
      const voidRen1 = await call(
        base,
        `/admin/payments/${m4Ren1PayId}/void-reversal`,
        adminToken,
        'POST',
        { reason: 'Đảo gia hạn 1 theo đúng thứ tự LIFO' },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(voidRen1.status, 201);
      assert.equal(voidRen1.body.data.adjustment.restoredEndDate, baseEndDate);

      // Verify GET /admin/payments?adjusted=true returns all 3 adjusted payments with joined adjustment details
      const adjustedList = await call(base, '/admin/payments?adjusted=true&page=1&pageSize=20', adminToken);
      assert.equal(adjustedList.status, 200);
      assert.equal(adjustedList.body.pagination.totalItems, 3);
      assert.ok(adjustedList.body.data.every((p) => p.adjustment?.adjustmentType === 'VOID_REVERSAL'));

      // 6. Verify 0031 simulated_refunds DB constraint ck_simulated_refund_formula (D3 rounding cases)
      const relSimId = randomUUID();
      const holdSimA = randomUUID();
      const holdSimB = randomUUID();
      const holdSimC = randomUUID();
      const holdSimQ = randomUUID();
      const entSimA = randomUUID();
      const entSimB = randomUUID();
      const entSimC = randomUUID();
      const entSimQ = randomUUID();
      const incSimId = randomUUID();
      const batchId = randomUUID();
      const { rows: [{ today_vn: todayVn }] } = await database.query(
        `SELECT (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS today_vn`,
      );
      await database.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id, status, paused_at, pause_reason)
         VALUES ($1, $2, $3, 'PAUSED', now(), 'COACH_LOCKED')`,
        [relSimId, m1Id, coachId],
      );
      await database.query(
        `INSERT INTO coach_payment_holds
         (id, member_id, coach_id, plan_code, plan_name, session_count, duration_days, amount, request_key, status, created_at, expires_at, settled_at)
         VALUES
         ($1, $5, $6, 'ADVANCED', 'Nâng cao', 30, 90, 5000000, gen_random_uuid(), 'CONSUMED', now() - interval '1 day', now() - interval '1 day' + interval '15 minutes', now()),
         ($2, $5, $6, 'BASIC', 'Cơ bản', 10, 30, 2999000, gen_random_uuid(), 'CONSUMED', now() - interval '1 day', now() - interval '1 day' + interval '15 minutes', now()),
         ($3, $5, $6, 'BASIC', 'Cơ bản', 10, 30, 5000, gen_random_uuid(), 'CONSUMED', now() - interval '1 day', now() - interval '1 day' + interval '15 minutes', now()),
         ($4, $5, $6, 'BASIC', 'Cơ bản', 10, 30, 1950000, gen_random_uuid(), 'CONSUMED', now() - interval '1 day', now() - interval '1 day' + interval '15 minutes', now())`,
        [holdSimA, holdSimB, holdSimC, holdSimQ, m1Id, coachId],
      );
      await database.query(
        `INSERT INTO coach_entitlements
         (id, hold_id, original_hold_id, relationship_id, member_id, coach_id,
          plan_code, plan_name, snapshot_price, status, total_sessions, remaining_sessions,
          duration_days, starts_on, original_ends_on, ends_on, ended_at, close_reason)
         VALUES
         ($1, $5, $5, $9, $10, $11, 'ADVANCED', 'Nâng cao', 5000000, 'ENDED', 30, 11, 90, $12::date, $12::date + 89, $12::date + 89, now(), 'SIMULATED_REFUND'),
         ($2, $6, $6, $9, $10, $11, 'BASIC', 'Cơ bản', 2999000, 'ENDED', 10, 3, 30, $12::date, $12::date + 29, $12::date + 29, now(), 'SIMULATED_REFUND'),
         ($3, $7, $7, $9, $10, $11, 'BASIC', 'Cơ bản', 5000, 'ENDED', 10, 1, 30, $12::date, $12::date + 29, $12::date + 29, now(), 'SIMULATED_REFUND'),
         ($4, $8, $8, $9, $10, $11, 'BASIC', 'Cơ bản', 1950000, 'ENDED', 10, 10, 30, NULL, NULL, NULL, now(), 'SIMULATED_REFUND')`,
        [entSimA, entSimB, entSimC, entSimQ, holdSimA, holdSimB, holdSimC, holdSimQ, relSimId, m1Id, coachId, todayVn],
      );
      await database.query(
        `INSERT INTO coach_lock_incidents (id, coach_id, member_id, relationship_id, lock_reason, locked_by, status)
         VALUES ($1, $2, $3, $4, 'Formula check', $5, 'OPEN')`,
        [incSimId, coachId, m1Id, relSimId, adminId],
      );
      // Wrong rounded-up amount (1834000 instead of floor 1833000) MUST fail ck_simulated_refund_formula!
      await assert.rejects(
        () => database.query(
          `INSERT INTO simulated_refunds
           (id, refund_batch_id, incident_id, coach_entitlement_id, relationship_id, member_id, coach_id,
            entitlement_kind, snapshot_price, total_sessions, remaining_sessions, refund_amount,
            reason, idempotency_key, request_hash, created_by)
           VALUES ($1, $2, $3, $4, $5, $6, $7, 'ACTIVE', 5000000, 30, 11, 1834000, 'Wrong round up', $8, repeat('a', 64), $9)`,
          [randomUUID(), batchId, incSimId, entSimA, relSimId, m1Id, coachId, randomUUID(), adminId],
        ),
        (err) => err.code === '23514' && err.constraint === 'ck_simulated_refund_formula',
      );
      // Exact floor-to-1000 VND cases A (1833000), B (899000), C (0), and QUEUED (1950000) MUST pass!
      for (const [entId, kind, price, total, rem, expectedRefund] of [
        [entSimA, 'ACTIVE', 5000000, 30, 11, 1833000],
        [entSimB, 'ACTIVE', 2999000, 10, 3, 899000],
        [entSimC, 'ACTIVE', 5000, 10, 1, 0],
        [entSimQ, 'QUEUED', 1950000, 10, 10, 1950000],
      ]) {
        await database.query(
          `INSERT INTO simulated_refunds
           (id, refund_batch_id, incident_id, coach_entitlement_id, relationship_id, member_id, coach_id,
            entitlement_kind, snapshot_price, total_sessions, remaining_sessions, refund_amount,
            reason, idempotency_key, request_hash, created_by)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, 'Exact formula', $13, repeat('b', 64), $14)`,
          [randomUUID(), batchId, incSimId, entId, relSimId, m1Id, coachId, kind, price, total, rem, expectedRefund, randomUUID(), adminId],
        );
      }
    } finally {
      await database.query('DELETE FROM simulated_refunds WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM coach_lock_incidents WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM coach_notifications WHERE user_id = ANY($1::uuid[])', [[coachId, ...memberIds]]);
      await database.query('DELETE FROM coach_entitlements WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM coach_payment_holds WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM coach_relationships WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM coach_weekly_slots WHERE coach_id = $1', [coachId]);
      await database.query("UPDATE coach_package_plans SET status = 'INACTIVE', price = 0 WHERE code = 'BASIC'");
      await database.query('DELETE FROM gym_visits WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM payment_adjustments WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM member_memberships WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM payments WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM admin_audit_logs WHERE admin_id = $1', [adminId]);
      for (const pid of [plan30Id, plan60Id, plan90Id].filter(Boolean)) {
        await database.query('DELETE FROM membership_plans WHERE id = $1', [pid]);
      }
      await database.query('DELETE FROM coach_profiles WHERE user_id = $1', [coachId]);
      await database.query('DELETE FROM member_profiles WHERE user_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [[adminId, coachId, ...memberIds]]);
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });
