import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';
import {
  computeActiveSimulatedRefundBigInt,
  computeQueuedSimulatedRefundBigInt,
} from '../src/services/simulated-refunds.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'web-admin-t14-simulated-refunds-secret-32-chars';

test('T14 unit: D2+D3 BigInt simulated refund formula rounding & edge cases', () => {
  assert.equal(computeActiveSimulatedRefundBigInt(5000000, 11, 30), 1833000n);
  assert.equal(computeActiveSimulatedRefundBigInt(2999000, 3, 10), 899000n);
  assert.equal(computeActiveSimulatedRefundBigInt(5000, 1, 10), 0n);
  assert.equal(computeActiveSimulatedRefundBigInt(5000000, 0, 30), 0n);
  assert.equal(computeQueuedSimulatedRefundBigInt(1950000), 1950000n);
});

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

test('T14: D2+D3 simulated refunds — Walkthrough 3 math, rounding edge cases, idempotency, anti-double-refund, side effects, and GET history allowlist',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const app = createApp({ database, jwtSecret: secret });
    const server = app.listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;

    const adminId = randomUUID();
    const coachAId = randomUUID(); // Locked Coach with M6 (Walkthrough 3), M7 (Case B rounding), M8 (Case C 0-remaining), M9 (no refundable), M10 (already refunded)
    const m6Id = randomUUID(); // Walkthrough 3: ACTIVE 5M * 11 / 30 -> 1,833,000 + QUEUED 1,950,000 = 3,783,000
    const m7Id = randomUUID(); // Rounding Case B: 2,999,000 * 3 / 10 -> 899,000
    const m8Id = randomUUID(); // Rounding Case C: remaining 0 -> 0 VND
    const m9Id = randomUUID(); // Open incident with 0 refundable entitlements -> 409 NO_REFUNDABLE_ENTITLEMENT
    const m10Id = randomUUID(); // Open incident whose entitlement already has a simulated_refunds row -> 409 ALREADY_REFUNDED

    const allMembers = [m6Id, m7Id, m8Id, m9Id, m10Id];
    const allUsers = [adminId, coachAId, ...allMembers];

    const planId = randomUUID();
    const relM6Id = randomUUID();
    const relM7Id = randomUUID();
    const relM8Id = randomUUID();
    const relM9Id = randomUUID();
    const relM10Id = randomUUID();

    const adminToken = token(adminId, 'ADMIN');
    const m6Token = token(m6Id, 'MEMBER');
    const coachAToken = token(coachAId, 'COACH');

    let originalBasicPrice;
    let originalAdvancedPrice;

    try {
      const origPlans = (await database.query(
        `SELECT code, price FROM coach_package_plans WHERE code IN ('BASIC', 'ADVANCED')`,
      )).rows;
      const origByCode = Object.fromEntries(origPlans.map((p) => [p.code, Number(p.price)]));
      originalBasicPrice = origByCode.BASIC;
      originalAdvancedPrice = origByCode.ADVANCED;

      // Insert users
      const userTuples = [
        [adminId, 'ADMIN', 'Quản trị T14'],
        [coachAId, 'COACH', 'HLV Minh Khóa T14'],
        [m6Id, 'MEMBER', 'Nguyễn Minh Sáu'],
        [m7Id, 'MEMBER', 'Trần Thị Bảy'],
        [m8Id, 'MEMBER', 'Lê Văn Tám'],
        [m9Id, 'MEMBER', 'Phạm Thị Chín'],
        [m10Id, 'MEMBER', 'Hoàng Văn Mười'],
      ];
      for (const [id, role, fullName] of userTuples) {
        await database.query(
          `INSERT INTO users (id, email, password_hash, role, full_name)
           VALUES ($1, $2, 'hash', $3, $4)`,
          [id, `${id}@example.com`, role, fullName],
        );
      }
      await database.query('INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 8)', [coachAId]);
      for (const mid of allMembers) {
        await database.query(
          `INSERT INTO member_profiles
           (user_id, height_cm, weight_kg, body_fat_percent, fitness_goal,
            health_notes, injury_notes, dietary_preferences, health_declaration_completed_at)
           VALUES ($1, 175, 70, 16.5, 'SECRET_GOAL_T14',
                   'SECRET_HEALTH_T14', 'SECRET_INJURY_T14', 'SECRET_DIET_T14', now())`,
          [mid],
        );
      }

      // Active Gym memberships
      await database.query(
        `INSERT INTO membership_plans (id, name, price, duration_days, status, created_by)
         VALUES ($1, 'Gym T14 30d', 500000, 30, 'ACTIVE', $2)`,
        [planId, adminId],
      );
      const { rows: [{ today_vn: todayVn }] } = await database.query(
        `SELECT (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS today_vn`,
      );
      for (const mid of allMembers) {
        const payId = randomUUID();
        await database.query(
          `INSERT INTO payments (id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
           amount, method, status, transaction_code, idempotency_key, request_hash, created_by, decided_by, confirmed_at, decided_at)
           VALUES ($1, $2, $3, 'Gym T14 30d', 30, 500000, 'FRONT_DESK', 'SUCCESS',
                   $1::uuid::text, $1::uuid::text, repeat('b', 64), $4, $4, now(), now())`,
          [payId, mid, planId, adminId],
        );
        await database.query(
          `INSERT INTO member_memberships (id, member_id, plan_id, source_payment_id, start_date, end_date, status, activated_at)
           VALUES ($1, $2, $3, $4, $5::date - 5, $5::date + 24, 'ACTIVE', now())`,
          [randomUUID(), mid, planId, payId, todayVn],
        );
      }

      // Create ACTIVE relationships for M6, M7, M8, M9, M10 with Coach A
      await database.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id, status)
         VALUES ($1, $6, $11, 'ACTIVE'),
                ($2, $7, $11, 'ACTIVE'),
                ($3, $8, $11, 'ACTIVE'),
                ($4, $9, $11, 'ACTIVE'),
                ($5, $10, $11, 'ACTIVE')`,
        [relM6Id, relM7Id, relM8Id, relM9Id, relM10Id, m6Id, m7Id, m8Id, m9Id, m10Id, coachAId],
      );

      // Holds & entitlements
      const hM6Active = randomUUID();
      const hM6Queued = randomUUID();
      const hM7Active = randomUUID();
      const hM8Active = randomUUID();
      const hM10Active = randomUUID();
      const entM6Active = randomUUID();
      const entM6Queued = randomUUID();
      const entM7Active = randomUUID();
      const entM8Active = randomUUID();
      const entM10Active = randomUUID();

      await database.query(
        `INSERT INTO coach_payment_holds
         (id, member_id, coach_id, plan_code, plan_name, session_count, duration_days,
          amount, request_key, status, created_at, expires_at, settled_at)
         VALUES
         ($1, $6, $10, 'ADVANCED', 'Nâng cao', 30, 90, 5000000, gen_random_uuid(), 'CONSUMED', now() - interval '10 days', now() - interval '10 days' + interval '15 minutes', now() - interval '10 days'),
         ($2, $6, $10, 'BASIC', 'Cơ bản', 10, 30, 1950000, gen_random_uuid(), 'CONSUMED', now() - interval '5 days', now() - interval '5 days' + interval '15 minutes', now() - interval '5 days'),
         ($3, $7, $10, 'BASIC', 'Cơ bản', 10, 30, 2999000, gen_random_uuid(), 'CONSUMED', now() - interval '8 days', now() - interval '8 days' + interval '15 minutes', now() - interval '8 days'),
         ($4, $8, $10, 'BASIC', 'Cơ bản', 10, 30, 5000, gen_random_uuid(), 'CONSUMED', now() - interval '8 days', now() - interval '8 days' + interval '15 minutes', now() - interval '8 days'),
         ($5, $9, $10, 'BASIC', 'Cơ bản', 10, 30, 2000000, gen_random_uuid(), 'CONSUMED', now() - interval '8 days', now() - interval '8 days' + interval '15 minutes', now() - interval '8 days')`,
        [hM6Active, hM6Queued, hM7Active, hM8Active, hM10Active, m6Id, m7Id, m8Id, m10Id, coachAId],
      );

      await database.query(
        `INSERT INTO coach_entitlements
         (id, hold_id, original_hold_id, relationship_id, member_id, coach_id,
          plan_code, plan_name, snapshot_price, status, total_sessions, remaining_sessions,
          duration_days, starts_on, original_ends_on, ends_on)
         VALUES
         ($1, $6, $6, $11, $15, $19, 'ADVANCED', 'Nâng cao', 5000000, 'ACTIVE', 30, 11, 90, $20::date - 10, $20::date + 79, $20::date + 79),
         ($2, $7, $7, $11, $15, $19, 'BASIC', 'Cơ bản', 1950000, 'QUEUED', 10, 10, 30, NULL, NULL, NULL),
         ($3, $8, $8, $12, $16, $19, 'BASIC', 'Cơ bản', 2999000, 'ACTIVE', 10, 3, 30, $20::date - 5, $20::date + 24, $20::date + 24),
         ($4, $9, $9, $13, $17, $19, 'BASIC', 'Cơ bản', 5000, 'ACTIVE', 10, 1, 30, $20::date - 5, $20::date + 24, $20::date + 24),
         ($5, $10, $10, $14, $18, $19, 'BASIC', 'Cơ bản', 2000000, 'ACTIVE', 10, 5, 30, $20::date - 5, $20::date + 24, $20::date + 24)`,
        [
          entM6Active, entM6Queued, entM7Active, entM8Active, entM10Active,
          hM6Active, hM6Queued, hM7Active, hM8Active, hM10Active,
          relM6Id, relM7Id, relM8Id, relM10Id,
          m6Id, m7Id, m8Id, m10Id, coachAId, todayVn,
        ],
      );

      // Change catalog price AFTER purchase to prove snapshot immutability on QUEUED & ACTIVE
      await database.query(`UPDATE coach_package_plans SET price = 9999000 WHERE code = 'BASIC'`);
      await database.query(`UPDATE coach_package_plans SET price = 8888000 WHERE code = 'ADVANCED'`);

      // Add training_plan, nutrition_guide, chat conversation + message, and open termination request for M6
      const m6PlanId = randomUUID();
      const m6GuideId = randomUUID();
      const m6ConvId = randomUUID();
      const m6MsgId = randomUUID();
      const m6TermId = randomUUID();

      await database.query(
        `INSERT INTO training_plans (id, relationship_id, member_id, coach_id, title, goal, status, version, published_at)
         VALUES ($1, $2, $3, $4, 'Giáo án T14 M6', 'Mục tiêu T14', 'ACTIVE', 1, now())`,
        [m6PlanId, relM6Id, m6Id, coachAId],
      );
      await database.query(
        `INSERT INTO nutrition_guides (id, relationship_id, member_id, coach_id, title, content, status, version, published_at)
         VALUES ($1, $2, $3, $4, 'Thực đơn T14 M6', 'Nội dung thực đơn T14', 'ACTIVE', 1, now())`,
        [m6GuideId, relM6Id, m6Id, coachAId],
      );
      await database.query(
        `INSERT INTO conversations (id, relationship_id, member_id, coach_id)
         VALUES ($1, $2, $3, $4)`,
        [m6ConvId, relM6Id, m6Id, coachAId],
      );
      await database.query(
        `INSERT INTO conversation_participants (conversation_id, user_id)
         VALUES ($1, $2), ($1, $3)`,
        [m6ConvId, m6Id, coachAId],
      );
      await database.query(
        `INSERT INTO messages (id, conversation_id, sender_id, client_message_id, message_type, content)
         VALUES ($1, $2, $3, $4, 'TEXT', 'Tin nhắn lịch sử T14 không bị xóa')`,
        [m6MsgId, m6ConvId, m6Id, randomUUID()],
      );
      await database.query(
        `INSERT INTO coach_termination_requests
         (id, relationship_id, coach_id, reason, status, requested_by_user_id, requested_by_role,
          counterparty_user_id, response_deadline_at)
         VALUES ($1, $2, $3, 'Yêu cầu cũ trước khi hoàn tiền', 'PENDING_COUNTERPARTY', $4, 'MEMBER', $3, now() + interval '72 hours')`,
        [m6TermId, relM6Id, coachAId, m6Id],
      );

      // Lock Coach A via D1 endpoint to create OPEN coach_lock_incidents for M6..M10
      const lockRes = await call(base, `/admin/users/${coachAId}/status`, adminToken, 'PATCH', {
        status: 'DISABLED',
        reason: 'Coach nghỉ đột xuất T14',
      });
      assert.equal(lockRes.status, 200);
      assert.equal(lockRes.body.data.effects.incidentsCreated.length, 5);

      const incidentsRes = await database.query(
        `SELECT id, member_id, relationship_id FROM coach_lock_incidents WHERE coach_id = $1 AND status = 'OPEN'`,
        [coachAId],
      );
      const incidentByMember = Object.fromEntries(incidentsRes.rows.map((r) => [r.member_id, r.id]));
      const incM6 = incidentByMember[m6Id];
      const incM7 = incidentByMember[m7Id];
      const incM8 = incidentByMember[m8Id];
      const incM9 = incidentByMember[m9Id];
      const incM10 = incidentByMember[m10Id];
      assert.ok(incM6 && incM7 && incM8 && incM9 && incM10);

      // Insert a future BOOKED booking & a live HELD payment hold on M6 AFTER lock to verify refund cancels them too
      const m6FutureBookingId = randomUUID();
      const m6LiveHoldId = randomUUID();
      await database.query(
        `INSERT INTO coach_bookings
         (id, entitlement_id, member_id, coach_id, starts_at, ends_at, status)
         VALUES ($1, $2, $3, $4,
                 statement_timestamp() + interval '3 days',
                 statement_timestamp() + interval '3 days 90 minutes',
                 'BOOKED')`,
        [m6FutureBookingId, entM6Active, m6Id, coachAId],
      );
      await database.query(
        `INSERT INTO coach_payment_holds
         (id, member_id, coach_id, plan_code, plan_name, session_count, duration_days,
          amount, request_key, status, created_at, expires_at)
         VALUES ($1, $2, $3, 'BASIC', 'Cơ bản', 10, 30, 2000000, gen_random_uuid(),
                 'HELD', statement_timestamp(), statement_timestamp() + interval '15 minutes')`,
        [m6LiveHoldId, m6Id, coachAId],
      );

      const seatsBeforeM6 = Number((await database.query(
        'SELECT coach_occupied_seats($1) AS count',
        [coachAId],
      )).rows[0].count);
      assert.equal(seatsBeforeM6, 5);

      // =========================================================================
      // 1. Validation & Auth Guards
      // =========================================================================
      const nonAdminPost = await call(
        base,
        `/admin/coach-incidents/${incM6}/simulated-refunds`,
        m6Token,
        'POST',
        { reason: 'Member thử hoàn tiền' },
        { 'Idempotency-Key': randomUUID() },
      );
      assert.equal(nonAdminPost.status, 403);

      const nonAdminGet = await call(base, '/admin/simulated-refunds', m6Token, 'GET');
      assert.equal(nonAdminGet.status, 403);

      const missingKey = await call(
        base,
        `/admin/coach-incidents/${incM6}/simulated-refunds`,
        adminToken,
        'POST',
        { reason: 'Thiếu key' },
      );
      assert.equal(missingKey.status, 422);

      const badKey = await call(
        base,
        `/admin/coach-incidents/${incM6}/simulated-refunds`,
        adminToken,
        'POST',
        { reason: 'Sai định dạng key' },
        { 'Idempotency-Key': 'not-a-uuid' },
      );
      assert.equal(badKey.status, 422);

      const emptyReason = await call(
        base,
        `/admin/coach-incidents/${incM6}/simulated-refunds`,
        adminToken,
        'POST',
        { reason: '   ' },
        { 'Idempotency-Key': randomUUID() },
      );
      assert.equal(emptyReason.status, 422);

      const missingIncident = await call(
        base,
        `/admin/coach-incidents/${randomUUID()}/simulated-refunds`,
        adminToken,
        'POST',
        { reason: 'Không tồn tại' },
        { 'Idempotency-Key': randomUUID() },
      );
      assert.equal(missingIncident.status, 404);
      assert.equal(missingIncident.body.error.code, 'NOT_FOUND');

      // =========================================================================
      // 2. Walkthrough 3 Exact Math + Atomic Side Effects (M6)
      // =========================================================================
      const m6IdemKey = randomUUID();
      const m6Reason = 'Chưa có Coach thay thế phù hợp; Member chọn nhận hoàn tiền mô phỏng';
      const refundM6 = await call(
        base,
        `/admin/coach-incidents/${incM6}/simulated-refunds`,
        adminToken,
        'POST',
        { reason: m6Reason },
        { 'Idempotency-Key': m6IdemKey },
      );
      assert.equal(refundM6.status, 201);
      const batchM6 = refundM6.body.data;
      assert.equal(batchM6.incidentId, incM6);
      assert.equal(batchM6.relationshipId, relM6Id);
      assert.equal(batchM6.totalRefundAmount, 3783000);
      assert.equal(batchM6.relationshipStatus, 'ENDED');
      assert.equal(batchM6.incidentStatus, 'RESOLVED_REFUNDED');
      assert.equal(batchM6.items.length, 2);

      const activeItem = batchM6.items.find((i) => i.entitlementKind === 'ACTIVE');
      const queuedItem = batchM6.items.find((i) => i.entitlementKind === 'QUEUED');
      assert.deepEqual(
        {
          coachEntitlementId: activeItem.coachEntitlementId,
          planName: activeItem.planName,
          snapshotPrice: activeItem.snapshotPrice,
          totalSessions: activeItem.totalSessions,
          remainingSessions: activeItem.remainingSessions,
          refundAmount: activeItem.refundAmount,
          status: activeItem.status,
        },
        {
          coachEntitlementId: entM6Active,
          planName: 'Nâng cao',
          snapshotPrice: 5000000,
          totalSessions: 30,
          remainingSessions: 11,
          refundAmount: 1833000,
          status: 'COMPLETED',
        },
      );
      assert.deepEqual(
        {
          coachEntitlementId: queuedItem.coachEntitlementId,
          planName: queuedItem.planName,
          snapshotPrice: queuedItem.snapshotPrice,
          totalSessions: queuedItem.totalSessions,
          remainingSessions: queuedItem.remainingSessions,
          refundAmount: queuedItem.refundAmount,
          status: queuedItem.status,
        },
        {
          coachEntitlementId: entM6Queued,
          planName: 'Cơ bản',
          snapshotPrice: 1950000,
          totalSessions: 10,
          remainingSessions: 10,
          refundAmount: 1950000,
          status: 'COMPLETED',
        },
      );

      // Verify entitlements closed with SIMULATED_REFUND and frozen_at = NULL
      const m6EntsAfter = (await database.query(
        `SELECT id, status, close_reason, frozen_at, ended_at FROM coach_entitlements WHERE relationship_id = $1`,
        [relM6Id],
      )).rows;
      assert.equal(m6EntsAfter.length, 2);
      for (const e of m6EntsAfter) {
        assert.equal(e.status, 'ENDED');
        assert.equal(e.close_reason, 'SIMULATED_REFUND');
        assert.equal(e.frozen_at, null);
        assert.ok(e.ended_at);
      }

      // Verify NO bogus PACKAGE_ENDED notification emitted; SIMULATED_REFUND_COMPLETED emitted
      const m6Notifs = (await database.query(
        `SELECT user_id, kind, subject_id FROM coach_notifications WHERE user_id IN ($1, $2)`,
        [m6Id, coachAId],
      )).rows;
      assert.equal(
        m6Notifs.filter((n) => n.user_id === m6Id && n.kind === 'PACKAGE_ENDED').length,
        0,
        'Must not emit bogus PACKAGE_ENDED when closing entitlements for SIMULATED_REFUND',
      );
      assert.equal(
        m6Notifs.filter((n) => n.user_id === m6Id && n.kind === 'SIMULATED_REFUND_COMPLETED' && n.subject_id === batchM6.refundBatchId).length,
        1,
      );

      // Verify relationship ENDED, future booking cancelled uncharged, live hold cancelled, plans archived, term cancelled
      const relM6After = (await database.query(
        `SELECT status, ended_by, end_reason FROM coach_relationships WHERE id = $1`,
        [relM6Id],
      )).rows[0];
      assert.equal(relM6After.status, 'ENDED');
      assert.equal(relM6After.ended_by, adminId);
      assert.equal(relM6After.end_reason, m6Reason);

      const bookingAfter = (await database.query(
        `SELECT status, charged_at FROM coach_bookings WHERE id = $1`,
        [m6FutureBookingId],
      )).rows[0];
      assert.equal(bookingAfter.status, 'CANCELLED');
      assert.equal(bookingAfter.charged_at, null);

      const holdAfter = (await database.query(
        `SELECT status FROM coach_payment_holds WHERE id = $1`,
        [m6LiveHoldId],
      )).rows[0];
      assert.equal(holdAfter.status, 'CANCELLED');

      const planAfter = (await database.query(
        `SELECT status, archived_at FROM training_plans WHERE id = $1`,
        [m6PlanId],
      )).rows[0];
      assert.equal(planAfter.status, 'ARCHIVED');
      assert.ok(planAfter.archived_at);

      const guideAfter = (await database.query(
        `SELECT status, archived_at FROM nutrition_guides WHERE id = $1`,
        [m6GuideId],
      )).rows[0];
      assert.equal(guideAfter.status, 'ARCHIVED');
      assert.ok(guideAfter.archived_at);

      const termAfter = (await database.query(
        `SELECT status FROM coach_termination_requests WHERE id = $1`,
        [m6TermId],
      )).rows[0];
      assert.equal(termAfter.status, 'CANCELLED');

      // Verify Coach seat freed ONCE (5 -> 4)
      const seatsAfterM6 = Number((await database.query(
        'SELECT coach_occupied_seats($1) AS count',
        [coachAId],
      )).rows[0].count);
      assert.equal(seatsAfterM6, 4);

      // Verify chat history untouched and still readable by Member
      const msgsAfter = await call(base, `/conversations/${relM6Id}/messages`, m6Token, 'GET');
      assert.equal(msgsAfter.status, 200);
      assert.equal(msgsAfter.body.data.length, 1);
      assert.equal(msgsAfter.body.data[0].content, 'Tin nhắn lịch sử T14 không bị xóa');

      // Verify incident updated to RESOLVED_REFUNDED
      const incM6After = (await database.query(
        `SELECT status, refund_batch_id, frozen_ended_at, resolved_by, resolved_at
         FROM coach_lock_incidents WHERE id = $1`,
        [incM6],
      )).rows[0];
      assert.equal(incM6After.status, 'RESOLVED_REFUNDED');
      assert.equal(incM6After.refund_batch_id, batchM6.refundBatchId);
      assert.ok(incM6After.frozen_ended_at);
      assert.equal(incM6After.resolved_by, adminId);
      assert.ok(incM6After.resolved_at);

      // Verify SIMULATED_REFUND_CREATED audit log & strict privacy
      const auditRows = (await database.query(
        `SELECT action, entity_type, entity_id, summary, metadata
         FROM admin_audit_logs WHERE action = 'SIMULATED_REFUND_CREATED' AND entity_id = $1`,
        [incM6],
      )).rows;
      assert.equal(auditRows.length, 1);
      assert.equal(auditRows[0].entity_type, 'COACH_LOCK_INCIDENT');
      assert.equal(auditRows[0].metadata.totalRefundAmount, 3783000);
      assert.equal(auditRows[0].metadata.refundBatchId, batchM6.refundBatchId);
      const auditJson = JSON.stringify(auditRows[0]);
      assert.ok(!auditJson.includes('SECRET_HEALTH_T14'));
      assert.ok(!auditJson.includes('SECRET_INJURY_T14'));
      assert.ok(!auditJson.includes('SECRET_GOAL_T14'));

      // =========================================================================
      // 3. Idempotency Retry (200), Payload Conflict (409), Already Resolved (409)
      // =========================================================================
      const retrySame = await call(
        base,
        `/admin/coach-incidents/${incM6}/simulated-refunds`,
        adminToken,
        'POST',
        { reason: m6Reason },
        { 'Idempotency-Key': m6IdemKey },
      );
      assert.equal(retrySame.status, 200);
      assert.deepEqual(retrySame.body.data, batchM6);

      const m6RefundRowCount = Number((await database.query(
        `SELECT count(*)::int AS count FROM simulated_refunds WHERE incident_id = $1`,
        [incM6],
      )).rows[0].count);
      assert.equal(m6RefundRowCount, 2, 'Idempotent retry must not create duplicate rows');

      const conflictDiffReason = await call(
        base,
        `/admin/coach-incidents/${incM6}/simulated-refunds`,
        adminToken,
        'POST',
        { reason: 'Lý do khác trên cùng Idempotency-Key' },
        { 'Idempotency-Key': m6IdemKey },
      );
      assert.equal(conflictDiffReason.status, 409);
      assert.equal(conflictDiffReason.body.error.code, 'IDEMPOTENCY_KEY_CONFLICT');

      const alreadyResolved = await call(
        base,
        `/admin/coach-incidents/${incM6}/simulated-refunds`,
        adminToken,
        'POST',
        { reason: m6Reason },
        { 'Idempotency-Key': randomUUID() },
      );
      assert.equal(alreadyResolved.status, 409);
      assert.equal(alreadyResolved.body.error.code, 'INCIDENT_ALREADY_RESOLVED');

      // Verify DB-level UNIQUE (coach_entitlement_id) anti-double-refund
      await assert.rejects(
        () => database.query(
          `INSERT INTO simulated_refunds (
             id, refund_batch_id, incident_id, coach_entitlement_id,
             relationship_id, member_id, coach_id, entitlement_kind,
             snapshot_price, total_sessions, remaining_sessions, refund_amount,
             status, reason, idempotency_key, request_hash, created_by
           ) VALUES (
             gen_random_uuid(), gen_random_uuid(), $1, $2,
             $3, $4, $5, 'ACTIVE',
             5000000, 30, 11, 1833000,
             'COMPLETED', 'Duplicate attempt', gen_random_uuid()::text, repeat('c', 64), $6
           )`,
          [incM6, entM6Active, relM6Id, m6Id, coachAId, adminId],
        ),
        (err) => err.code === '23505',
      );

      // =========================================================================
      // 4. Rounding Edge Cases (M7: 899,000; M8: 0 VND) & 409 Guards (M9, M10)
      // =========================================================================
      const refundM7 = await call(
        base,
        `/admin/coach-incidents/${incM7}/simulated-refunds`,
        adminToken,
        'POST',
        { reason: 'Hoàn tiền biên làm tròn xuống 1.000 VND' },
        { 'Idempotency-Key': randomUUID() },
      );
      assert.equal(refundM7.status, 201);
      assert.equal(refundM7.body.data.totalRefundAmount, 899000);
      assert.equal(refundM7.body.data.items.length, 1);
      assert.equal(refundM7.body.data.items[0].refundAmount, 899000);

      const refundM8 = await call(
        base,
        `/admin/coach-incidents/${incM8}/simulated-refunds`,
        adminToken,
        'POST',
        { reason: 'Hoàn tiền gói còn 0 buổi' },
        { 'Idempotency-Key': randomUUID() },
      );
      assert.equal(refundM8.status, 201);
      assert.equal(refundM8.body.data.totalRefundAmount, 0);
      assert.equal(refundM8.body.data.items.length, 1);
      assert.equal(refundM8.body.data.items[0].refundAmount, 0);

      // M9 has OPEN incident with zero ACTIVE/QUEUED entitlements -> 409 NO_REFUNDABLE_ENTITLEMENT
      const refundM9 = await call(
        base,
        `/admin/coach-incidents/${incM9}/simulated-refunds`,
        adminToken,
        'POST',
        { reason: 'Không có gói để hoàn' },
        { 'Idempotency-Key': randomUUID() },
      );
      assert.equal(refundM9.status, 409);
      assert.equal(refundM9.body.error.code, 'NO_REFUNDABLE_ENTITLEMENT');

      // M10 has an existing simulated_refunds row on its entitlement -> 409 ALREADY_REFUNDED
      await database.query(
        `INSERT INTO simulated_refunds (
           id, refund_batch_id, incident_id, coach_entitlement_id,
           relationship_id, member_id, coach_id, entitlement_kind,
           snapshot_price, total_sessions, remaining_sessions, refund_amount,
           status, reason, idempotency_key, request_hash, created_by
         ) VALUES (
           gen_random_uuid(), gen_random_uuid(), $1, $2,
           $3, $4, $5, 'ACTIVE',
           2000000, 10, 5, 1000000,
           'COMPLETED', 'Đã hoàn trước', gen_random_uuid()::text, repeat('d', 64), $6
         )`,
        [incM10, entM10Active, relM10Id, m10Id, coachAId, adminId],
      );
      const refundM10 = await call(
        base,
        `/admin/coach-incidents/${incM10}/simulated-refunds`,
        adminToken,
        'POST',
        { reason: 'Thử hoàn lại lần 2' },
        { 'Idempotency-Key': randomUUID() },
      );
      assert.equal(refundM10.status, 409);
      assert.equal(refundM10.body.error.code, 'ALREADY_REFUNDED');

      // =========================================================================
      // 5. GET /api/v1/admin/simulated-refunds — Filters, VN Dates, Pagination, Privacy
      // =========================================================================
      const invalidDateRange = await call(
        base,
        '/admin/simulated-refunds?from=2026-12-01&to=2026-11-01',
        adminToken,
        'GET',
      );
      assert.equal(invalidDateRange.status, 422);

      const listAllCoachA = await call(
        base,
        `/admin/simulated-refunds?coachId=${coachAId}&from=${todayVn}&to=${todayVn}&page=1&pageSize=2`,
        adminToken,
        'GET',
      );
      assert.equal(listAllCoachA.status, 200);
      assert.equal(listAllCoachA.body.items.length, 2);
      assert.equal(listAllCoachA.body.data.length, 2);
      assert.equal(listAllCoachA.body.pagination.totalItems, 5); // M6 (2) + M7 (1) + M8 (1) + M10 (1)
      assert.equal(listAllCoachA.body.pagination.totalPages, 3);
      assert.equal(listAllCoachA.body.summary.count, 5);
      assert.equal(listAllCoachA.body.summary.totalRefundAmount, 3783000 + 899000 + 0 + 1000000);

      // Filter by incidentId & memberId & search
      const listM6 = await call(
        base,
        `/admin/simulated-refunds?memberId=${m6Id}&incidentId=${incM6}&search=${encodeURIComponent('Nguyễn Minh Sáu')}`,
        adminToken,
        'GET',
      );
      assert.equal(listM6.status, 200);
      assert.equal(listM6.body.items.length, 2);
      assert.equal(listM6.body.summary.count, 2);
      assert.equal(listM6.body.summary.totalRefundAmount, 3783000);

      const firstItem = listM6.body.items[0];
      assert.equal(firstItem.memberName, 'Nguyễn Minh Sáu');
      assert.equal(firstItem.memberEmail, `${m6Id}@example.com`);
      assert.equal(firstItem.coachName, 'HLV Minh Khóa T14');
      assert.equal(firstItem.coachEmail, `${coachAId}@example.com`);
      assert.equal(firstItem.createdByName, 'Quản trị T14');

      // VN date out-of-range returns empty
      const listOutOfRange = await call(
        base,
        `/admin/simulated-refunds?coachId=${coachAId}&from=2020-01-01&to=2020-01-02`,
        adminToken,
        'GET',
      );
      assert.equal(listOutOfRange.status, 200);
      assert.equal(listOutOfRange.body.items.length, 0);
      assert.equal(listOutOfRange.body.summary.count, 0);
      assert.equal(listOutOfRange.body.summary.totalRefundAmount, 0);

      // Strict privacy allowlist check
      const listPayloadText = JSON.stringify(listM6.body);
      for (const forbidden of [
        'SECRET_GOAL_T14',
        'SECRET_HEALTH_T14',
        'SECRET_INJURY_T14',
        'SECRET_DIET_T14',
        'healthNotes',
        'injuryNotes',
        'heightCm',
        'weightKg',
        'bodyFatPercent',
        'fitnessGoal',
        'passwordHash',
      ]) {
        assert.ok(!listPayloadText.includes(forbidden), `Forbidden field leaked: ${forbidden}`);
      }
    } finally {
      server.close();
      if (originalBasicPrice !== undefined) {
        await database.query(`UPDATE coach_package_plans SET price = $1 WHERE code = 'BASIC'`, [originalBasicPrice]).catch(() => {});
      }
      if (originalAdvancedPrice !== undefined) {
        await database.query(`UPDATE coach_package_plans SET price = $1 WHERE code = 'ADVANCED'`, [originalAdvancedPrice]).catch(() => {});
      }
      await database.query('DELETE FROM admin_audit_logs WHERE admin_id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.query('DELETE FROM simulated_refunds WHERE coach_id = ANY($1::uuid[]) OR member_id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.query('DELETE FROM coach_notifications WHERE user_id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.query('DELETE FROM messages WHERE sender_id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.query('DELETE FROM conversation_participants WHERE user_id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.query('DELETE FROM conversations WHERE member_id = ANY($1::uuid[]) OR coach_id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.query('DELETE FROM training_plans WHERE member_id = ANY($1::uuid[]) OR coach_id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.query('DELETE FROM nutrition_guides WHERE member_id = ANY($1::uuid[]) OR coach_id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.query('DELETE FROM coach_termination_requests WHERE coach_id = ANY($1::uuid[]) OR requested_by_user_id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.query('DELETE FROM coach_lock_incidents WHERE coach_id = ANY($1::uuid[]) OR member_id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.query('DELETE FROM coach_bookings WHERE member_id = ANY($1::uuid[]) OR coach_id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.query('DELETE FROM coach_entitlements WHERE member_id = ANY($1::uuid[]) OR coach_id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.query('DELETE FROM coach_payment_holds WHERE member_id = ANY($1::uuid[]) OR coach_id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.query('DELETE FROM coach_relationships WHERE member_id = ANY($1::uuid[]) OR coach_id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.query('DELETE FROM member_memberships WHERE member_id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.query('DELETE FROM payments WHERE member_id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.query('DELETE FROM membership_plans WHERE id = $1', [planId]).catch(() => {});
      await database.query('DELETE FROM member_profiles WHERE user_id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.query('DELETE FROM coach_profiles WHERE user_id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [allUsers]).catch(() => {});
      await database.end();
    }
  });
