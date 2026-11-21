import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'web-admin-t15-dashboard-secret-32-chars';

function token(id, role, sessionVersion = 0) {
  return jwt.sign({ role, sessionVersion }, secret, {
    algorithm: 'HS256',
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    subject: id,
    expiresIn: 3600,
  });
}

async function call(base, path, bearer) {
  const response = await fetch(`${base}/api/v1${path}`, {
    method: 'GET',
    headers: bearer ? { authorization: `Bearer ${bearer}` } : {},
  });
  return { status: response.status, body: await response.json() };
}

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

const FORBIDDEN_PRIVACY_KEYS = [
  'healthNotes',
  'health_notes',
  'injuryNotes',
  'injury_notes',
  'heightCm',
  'weightKg',
  'bodyFatPercent',
  'fitnessGoal',
  'dietaryPreferences',
  'dateOfBirth',
  'healthDeclarationCompletedAt',
  'journal',
  'messages',
  'aiMessages',
  'mealLogs',
  'memberNutritionDays',
  'progressPhotos',
  'passwordHash',
  'password_hash',
  'pendingCoachRequests',
];

test('T15: Real-data admin dashboard — revenue reconciliation (D3+D6), VN timezone buckets, actionQueue, paused breakdown, 72h inline escalation, and privacy allowlist',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const app = createApp({ database, jwtSecret: secret });
    const server = app.listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;

    const adminId = randomUUID();
    const activeCoachId = randomUUID();
    const lockedCoachId = randomUUID();
    const m1Id = randomUUID(); // ACTIVE rel + gym payment + coach hold + check-in
    const m2Id = randomUUID(); // PAUSED (MEMBERSHIP_EXPIRED) + overdue termination (escalates to DISPUTED)
    const m3Id = randomUUID(); // PAUSED (COACH_LOCKED) + OPEN incident (WAIT)
    const m4Id = randomUUID(); // PAUSED (COACH_LOCKED) + OPEN incident (REFUND)
    const m5Id = randomUUID(); // PAUSED (MEMBER_LOCKED) + disabled member
    const m6Id = randomUUID(); // ENDED rel + simulated refunds (ACTIVE + QUEUED) + VOID_REVERSAL payment

    const allMembers = [m1Id, m2Id, m3Id, m4Id, m5Id, m6Id];
    const allUsers = [adminId, activeCoachId, lockedCoachId, ...allMembers];

    const planId = randomUUID();
    const gymPay1Id = randomUUID(); // 2026-11-20 23:30+07 (UTC 2026-11-20T16:30:00Z) -> VN 2026-11-20, 2,000,000
    const gymPay2Id = randomUUID(); // 2026-11-21 00:30+07 (UTC 2026-11-20T17:30:00Z) -> VN 2026-11-21, 1,500,000 (VOID_REVERSAL)
    const gymPay3Id = randomUUID(); // 2026-11-21 09:00+07 (UTC 2026-11-21T02:00:00Z) -> VN 2026-11-21, 1,000,000
    const mem1Id = randomUUID();
    const mem2Id = randomUUID();
    const mem3Id = randomUUID();
    const adj1Id = randomUUID();

    const relActiveId = randomUUID();
    const relExpiredId = randomUUID();
    const relCoachLockedWaitId = randomUUID();
    const relCoachLockedRefundId = randomUUID();
    const relMemberLockedId = randomUUID();
    const relEndedRefundedId = randomUUID();

    const hold1Id = randomUUID(); // 2026-11-20 23:45+07 (UTC 2026-11-20T16:45:00Z) -> VN 2026-11-20, 5,000,000
    const hold2Id = randomUUID(); // 2026-11-21 00:15+07 (UTC 2026-11-20T17:15:00Z) -> VN 2026-11-21, 1,950,000
    const hold3Id = randomUUID(); // 2026-11-21 10:00+07 -> VN 2026-11-21, 3,000,000
    const entActiveRefundedId = randomUUID();
    const entQueuedRefundedId = randomUUID();
    const entOriginActiveId = randomUUID();
    const entTransferredCopyId = randomUUID(); // transferred entitlement (hold_id IS NULL) — must NOT double-count!

    const incWaitId = randomUUID();
    const incRefundReqId = randomUUID();
    const incResolvedRefundId = randomUUID();
    const refundBatchId = randomUUID();
    const simRefundActiveId = randomUUID();
    const simRefundQueuedId = randomUUID();

    const termDisputedId = randomUUID();
    const termOverdueId = randomUUID();
    const visitTodayId = randomUUID();

    const adminToken = token(adminId, 'ADMIN');
    const memberToken = token(m1Id, 'MEMBER');
    const coachToken = token(activeCoachId, 'COACH');

    try {
      const userTuples = [
        [adminId, 'ADMIN', 'ACTIVE', 'Admin T15'],
        [activeCoachId, 'COACH', 'ACTIVE', 'HLV Hoat Dong T15'],
        [lockedCoachId, 'COACH', 'DISABLED', 'HLV Bi Khoa T15'],
        [m1Id, 'MEMBER', 'ACTIVE', 'Hoi Vien Mot T15'],
        [m2Id, 'MEMBER', 'ACTIVE', 'Hoi Vien Hai T15'],
        [m3Id, 'MEMBER', 'ACTIVE', 'Hoi Vien Ba T15'],
        [m4Id, 'MEMBER', 'ACTIVE', 'Hoi Vien Bon T15'],
        [m5Id, 'MEMBER', 'DISABLED', 'Hoi Vien Nam Bi Khoa T15'],
        [m6Id, 'MEMBER', 'ACTIVE', 'Hoi Vien Sau T15'],
      ];
      for (const [id, role, status, fullName] of userTuples) {
        const isDisabled = status === 'DISABLED';
        await database.query(
          `INSERT INTO users (id, email, password_hash, role, status, full_name, disabled_at, disabled_reason)
           VALUES ($1, $2, 'hash', $3, $4, $5, $6, $7)`,
          [
            id,
            `${id}@example.com`,
            role,
            status,
            fullName,
            isDisabled ? new Date().toISOString() : null,
            isDisabled ? 'Khoa kiem thu T15' : null,
          ],
        );
      }

      await database.query(
        `INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 8), ($2, 8)`,
        [activeCoachId, lockedCoachId],
      );

      for (const mid of allMembers) {
        await database.query(
          `INSERT INTO member_profiles
           (user_id, height_cm, weight_kg, body_fat_percent, fitness_goal,
            health_notes, injury_notes, dietary_preferences, health_declaration_completed_at)
           VALUES ($1, 172, 68, 17.5, 'SECRET_GOAL_T15',
                   'SECRET_HEALTH_T15', 'SECRET_INJURY_T15', 'SECRET_DIET_T15', now())`,
          [mid],
        );
      }

      // Membership plan + 3 SUCCESS Gym payments across VN midnight boundary (2026-11-20 vs 2026-11-21)
      await database.query(
        `INSERT INTO membership_plans (id, name, price, duration_days, status, created_by)
         VALUES ($1, 'Gym T15 Plan', 1000000, 30, 'ACTIVE', $2)`,
        [planId, adminId],
      );

      await database.query(
        `INSERT INTO payments
         (id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot, amount, method, status,
          transaction_code, idempotency_key, request_hash, created_by, decided_by,
          confirmed_at, decided_at, created_at)
         VALUES
         ($1, $4, $7, 'Gym T15 Plan', 30, 2000000, 'FRONT_DESK', 'SUCCESS',
          $8, $11, $14, $17, $17,
          '2026-11-20T16:30:00Z'::timestamptz, '2026-11-20T16:30:00Z'::timestamptz, '2026-11-20T16:30:00Z'::timestamptz),
         ($2, $5, $7, 'Gym T15 Plan', 30, 1500000, 'FRONT_DESK', 'SUCCESS',
          $9, $12, $15, $17, $17,
          '2026-11-20T17:30:00Z'::timestamptz, '2026-11-20T17:30:00Z'::timestamptz, '2026-11-20T17:30:00Z'::timestamptz),
         ($3, $6, $7, 'Gym T15 Plan', 30, 1000000, 'MOCK_QR', 'SUCCESS',
          $10, $13, $16, $6, NULL,
          '2026-11-21T02:00:00Z'::timestamptz, '2026-11-21T02:00:00Z'::timestamptz, '2026-11-21T02:00:00Z'::timestamptz)`,
        [
          gymPay1Id, gymPay2Id, gymPay3Id,
          m1Id, m6Id, m3Id,
          planId,
          `T15-${gymPay1Id.slice(0, 8)}`, `T15-${gymPay2Id.slice(0, 8)}`, `T15-${gymPay3Id.slice(0, 8)}`,
          randomUUID(), randomUUID(), randomUUID(),
          sha256('t15-pay-1'), sha256('t15-pay-2'), sha256('t15-pay-3'),
          adminId,
        ],
      );

      // Memberships: 2 ACTIVE covering today VN + 1 CANCELLED (voided)
      await database.query(
        `INSERT INTO member_memberships
         (id, member_id, plan_id, source_payment_id, start_date, end_date, status, activated_at)
         VALUES
         ($1, $4, $7, $8,
          (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date - 5,
          (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 25,
          'ACTIVE', now() - interval '5 days'),
         ($2, $5, $7, $9,
          (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date - 5,
          (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 25,
          'CANCELLED', now() - interval '5 days'),
         ($3, $6, $7, $10,
          (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date - 2,
          (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 28,
          'ACTIVE', now() - interval '2 days')`,
        [mem1Id, mem2Id, mem3Id, m1Id, m6Id, m3Id, planId, gymPay1Id, gymPay2Id, gymPay3Id],
      );

      // D6 VOID_REVERSAL on gymPay2Id (VN 2026-11-21: 2026-11-21T01:00:00Z = 08:00+07)
      await database.query(
        `INSERT INTO payment_adjustments
         (id, payment_id, member_id, affected_membership_id, adjustment_type,
          reversed_amount, previous_membership_status, previous_end_date, restored_end_date,
          reason, idempotency_key, request_hash, created_by, created_at)
         VALUES ($1, $2, $3, $4, 'VOID_REVERSAL',
                 1500000, 'ACTIVE', '2026-12-20', NULL,
                 'Nhap nham goi tai quay', $5, $6, $7, '2026-11-21T01:00:00Z'::timestamptz)`,
        [adj1Id, gymPay2Id, m6Id, mem2Id, randomUUID(), sha256('t15-void-1'), adminId],
      );

      // Today VN check-in
      await database.query(
        `INSERT INTO gym_visits (id, member_id, visit_day, checked_in_at, gym_name, gym_address)
         VALUES ($1, $2, (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date, now(), 'Meta Gym', 'Ha Noi')`,
        [visitTodayId, m1Id],
      );

      // Relationships:
      // 1 ACTIVE, 1 PAUSED(MEMBERSHIP_EXPIRED), 2 PAUSED(COACH_LOCKED), 1 PAUSED(MEMBER_LOCKED), 1 ENDED
      await database.query(
        `INSERT INTO coach_relationships
         (id, member_id, coach_id, status, started_at, paused_at, pause_reason, ended_at, ended_by, end_reason)
         VALUES
         ($1, $7, $13, 'ACTIVE', now() - interval '10 days', NULL, NULL, NULL, NULL, NULL),
         ($2, $8, $13, 'PAUSED', now() - interval '10 days', now() - interval '2 days', 'MEMBERSHIP_EXPIRED', NULL, NULL, NULL),
         ($3, $9, $14, 'PAUSED', now() - interval '10 days', now() - interval '2 days', 'COACH_LOCKED', NULL, NULL, NULL),
         ($4, $10, $14, 'PAUSED', now() - interval '10 days', now() - interval '2 days', 'COACH_LOCKED', NULL, NULL, NULL),
         ($5, $11, $13, 'PAUSED', now() - interval '10 days', now() - interval '1 day', 'MEMBER_LOCKED', NULL, NULL, NULL),
         ($6, $12, $14, 'ENDED', now() - interval '15 days', NULL, NULL, now() - interval '1 day', $15, 'Hoan tien mo phong')`,
        [
          relActiveId, relExpiredId, relCoachLockedWaitId,
          relCoachLockedRefundId, relMemberLockedId, relEndedRefundedId,
          m1Id, m2Id, m3Id, m4Id, m5Id, m6Id,
          activeCoachId, lockedCoachId, adminId,
        ],
      );

      // 3 CONSUMED coach_payment_holds across VN midnight boundary:
      // hold1: 5,000,000 at 2026-11-20T16:45:00Z -> VN 2026-11-20
      // hold2: 1,950,000 at 2026-11-20T17:15:00Z -> VN 2026-11-21
      // hold3: 3,000,000 at 2026-11-21T03:00:00Z -> VN 2026-11-21
      await database.query(
        `INSERT INTO coach_payment_holds
         (id, member_id, coach_id, plan_code, plan_name, session_count, duration_days, amount,
          status, request_key, expires_at, settled_at, created_at)
         VALUES
         ($1, $4, $6, 'ADVANCED', 'Nang cao', 30, 90, 5000000, 'CONSUMED', $8,
          '2026-11-20T16:55:00Z'::timestamptz, '2026-11-20T16:45:00Z'::timestamptz, '2026-11-20T16:40:00Z'::timestamptz),
         ($2, $4, $6, 'BASIC', 'Co ban', 10, 30, 1950000, 'CONSUMED', $9,
          '2026-11-20T17:25:00Z'::timestamptz, '2026-11-20T17:15:00Z'::timestamptz, '2026-11-20T17:10:00Z'::timestamptz),
         ($3, $5, $7, 'STANDARD', 'Tieu chuan', 20, 60, 3000000, 'CONSUMED', $10,
          '2026-11-21T03:10:00Z'::timestamptz, '2026-11-21T03:00:00Z'::timestamptz, '2026-11-21T02:55:00Z'::timestamptz)`,
        [
          hold1Id, hold2Id, hold3Id,
          m6Id, m1Id,
          lockedCoachId, activeCoachId,
          randomUUID(), randomUUID(), randomUUID(),
        ],
      );

      // Coach entitlements: 2 ended (refunded) + 1 transferred pair (must NOT double-count!)
      await database.query(
        `INSERT INTO coach_entitlements
         (id, relationship_id, member_id, coach_id, hold_id, original_hold_id, source_entitlement_id,
          plan_code, plan_name, snapshot_price, total_sessions, remaining_sessions, duration_days,
          status, starts_on, original_ends_on, ends_on, ended_at, close_reason)
         VALUES
         ($1, $4, $6, $8, $10, $10, NULL, 'ADVANCED', 'Nang cao', 5000000, 30, 11, 90,
          'ENDED', '2026-11-01', '2027-01-29', '2027-01-29', now() - interval '1 day', 'SIMULATED_REFUND'),
         ($2, $4, $6, $8, $11, $11, NULL, 'BASIC', 'Co ban', 1950000, 10, 10, 30,
          'ENDED', NULL, NULL, NULL, now() - interval '1 day', 'SIMULATED_REFUND'),
         ($3, $5, $7, $9, $12, $12, NULL, 'STANDARD', 'Tieu chuan', 3000000, 20, 15, 60,
          'ENDED', '2026-11-01', '2026-12-30', '2026-12-30', now() - interval '1 day', 'TRANSFERRED')`,
        [
          entActiveRefundedId, entQueuedRefundedId, entOriginActiveId,
          relEndedRefundedId, relActiveId,
          m6Id, m1Id,
          lockedCoachId, activeCoachId,
          hold1Id, hold2Id, hold3Id,
        ],
      );
      await database.query(
        `INSERT INTO coach_entitlements
         (id, relationship_id, member_id, coach_id, hold_id, original_hold_id, source_entitlement_id,
          plan_code, plan_name, snapshot_price, total_sessions, remaining_sessions, duration_days,
          status, starts_on, original_ends_on, ends_on)
         VALUES
         ($1, $2, $3, $4, NULL, $5, $6, 'STANDARD', 'Tieu chuan', 3000000, 20, 15, 60,
          'ACTIVE', '2026-11-01', '2026-12-30', '2026-12-30')`,
        [entTransferredCopyId, relActiveId, m1Id, activeCoachId, hold3Id, entOriginActiveId],
      );

      // Coach lock incidents: 1 OPEN (WAIT), 1 OPEN (REFUND), 1 RESOLVED_REFUNDED
      await database.query(
        `INSERT INTO coach_lock_incidents
         (id, coach_id, member_id, relationship_id, active_entitlement_id, queued_entitlement_id,
          lock_reason, locked_by, member_choice, status, refund_batch_id, resolved_by, resolved_at)
         VALUES
         ($1, $4, $5, $8, NULL, NULL, 'HLV nghi dot xuat', $11, 'WAIT', 'OPEN', NULL, NULL, NULL),
         ($2, $4, $6, $9, NULL, NULL, 'HLV nghi dot xuat', $11, 'REFUND', 'OPEN', NULL, NULL, NULL),
         ($3, $4, $7, $10, $12, $13, 'HLV nghi dot xuat', $11, 'REFUND', 'RESOLVED_REFUNDED', $14, $11, now() - interval '1 day')`,
        [
          incWaitId, incRefundReqId, incResolvedRefundId,
          lockedCoachId, m3Id, m4Id, m6Id,
          relCoachLockedWaitId, relCoachLockedRefundId, relEndedRefundedId,
          adminId, entActiveRefundedId, entQueuedRefundedId, refundBatchId,
        ],
      );

      // D2+D3 simulated_refunds on VN 2026-11-21 (UTC 2026-11-21T04:00:00Z = 11:00+07):
      // ACTIVE: floor((5,000,000 * 11 / 30) / 1000) * 1000 = 1,833,000
      // QUEUED: 1,950,000
      // Total simulated refunds = 3,783,000
      const refundIdempKey = randomUUID();
      await database.query(
        `INSERT INTO simulated_refunds
         (id, refund_batch_id, incident_id, coach_entitlement_id, relationship_id,
          member_id, coach_id, entitlement_kind, snapshot_price, total_sessions, remaining_sessions,
          refund_amount, status, reason, idempotency_key, request_hash, created_by, created_at)
         VALUES
         ($1, $3, $4, $5, $7, $8, $9, 'ACTIVE', 5000000, 30, 11, 1833000, 'COMPLETED',
          'Hoan tien mo phong T15', $10, $11, $12, '2026-11-21T04:00:00Z'::timestamptz),
         ($2, $3, $4, $6, $7, $8, $9, 'QUEUED', 1950000, 10, 10, 1950000, 'COMPLETED',
          'Hoan tien mo phong T15', $10, $11, $12, '2026-11-21T04:00:00Z'::timestamptz)`,
        [
          simRefundActiveId, simRefundQueuedId, refundBatchId, incResolvedRefundId,
          entActiveRefundedId, entQueuedRefundedId, relEndedRefundedId,
          m6Id, lockedCoachId, refundIdempKey, sha256('t15-refund-1'), adminId,
        ],
      );

      // D5 termination requests:
      // 1 already DISPUTED on relActiveId
      // 1 PENDING_COUNTERPARTY past 72h deadline on relExpiredId (must escalate inline to DISPUTED!)
      await database.query(
        `INSERT INTO coach_termination_requests
         (id, relationship_id, coach_id, requested_by_user_id, requested_by_role, counterparty_user_id,
          reason, status, counterparty_decision, counterparty_reason, counterparty_decided_at,
          response_deadline_at, disputed_at, escalation_reason)
         VALUES
         ($1, $3, $5, $6, 'MEMBER', $5, 'Khong phu hop lich', 'DISPUTED',
          'REJECTED', 'Con 15 buoi', now() - interval '2 hours',
          now() + interval '48 hours', now() - interval '2 hours', 'COUNTERPARTY_REJECTED'),
         ($2, $4, $5, $7, 'MEMBER', $5, 'Qua han 72h', 'PENDING_COUNTERPARTY',
          NULL, NULL, NULL,
          now() - interval '1 hour', NULL, NULL)`,
        [termDisputedId, termOverdueId, relActiveId, relExpiredId, activeCoachId, m1Id, m2Id],
      );

      // 1. Auth & validation guards
      assert.equal((await call(base, '/admin/dashboard', memberToken)).status, 403);
      assert.equal((await call(base, '/admin/dashboard', coachToken)).status, 403);
      assert.equal((await call(base, '/admin/dashboard?from=2026-11-22&to=2026-11-21', adminToken)).status, 422);
      assert.equal((await call(base, '/admin/dashboard?unknown=1', adminToken)).status, 422);

      // 2. Real-data dashboard query for [2026-11-20, 2026-11-21] VN
      const res = await call(base, '/admin/dashboard?from=2026-11-20&to=2026-11-21', adminToken);
      assert.equal(res.status, 200);
      const data = res.body.data;

      assert.equal(data.from, '2026-11-20');
      assert.equal(data.to, '2026-11-21');
      assert.equal(data.timezone, 'Asia/Ho_Chi_Minh');
      assert.equal(data.pendingCoachRequests, undefined);

      // Members / Coaches / Active Memberships / Today check-ins
      assert.equal(data.members.active, 5);
      assert.equal(data.members.disabled, 1);
      assert.equal(data.coaches.active, 1);
      assert.equal(data.coaches.disabled, 1);
      assert.equal(data.activeMemberships, 2);
      assert.equal(data.todayCheckins, 1);

      // Active & Paused Coach relationships breakdown
      assert.equal(data.activeCoachRelationships, 1);
      assert.deepEqual(data.pausedCoachRelationships, {
        total: 4,
        membershipExpired: 1,
        coachLocked: 2,
        memberLocked: 1,
      });

      // Action queue (including inline-escalated 72h overdue termination!)
      assert.deepEqual(data.actionQueue, {
        coachLockedWaitingCount: 1,
        coachLockedRefundRequestedCount: 1,
        disputedTerminationCount: 2,
      });

      // Verify overdue termination row was persisted as DISPUTED (TIMEOUT_72H)
      const escalatedRow = (await database.query(
        `SELECT status, escalation_reason FROM coach_termination_requests WHERE id = $1`,
        [termOverdueId],
      )).rows[0];
      assert.equal(escalatedRow.status, 'DISPUTED');
      assert.equal(escalatedRow.escalation_reason, 'TIMEOUT_72H');

      // Revenue reconciliation totals:
      // gymGrossPayments = 2,000,000 + 1,500,000 + 1,000,000 = 4,500,000 (3 payments)
      // totalVoidReversals = 1,500,000 (1 void reversal)
      // coachGrossPayments = 5,000,000 + 1,950,000 + 3,000,000 = 9,950,000 (3 holds; transferred copy NOT double-counted)
      // grossRevenue = 4,500,000 - 1,500,000 + 9,950,000 = 12,950,000
      // totalSimulatedRefunds = 1,833,000 + 1,950,000 = 3,783,000 (2 refund rows)
      // netRevenue = 12,950,000 - 3,783,000 = 9,167,000
      assert.equal(data.revenue.gymGrossPayments, 4500000);
      assert.equal(data.revenue.totalVoidReversals, 1500000);
      assert.equal(data.revenue.coachGrossPayments, 9950000);
      assert.equal(data.revenue.grossRevenue, 12950000);
      assert.equal(data.revenue.totalSimulatedRefunds, 3783000);
      assert.equal(data.revenue.netRevenue, 9167000);
      assert.equal(data.revenue.gymPaymentCount, 3);
      assert.equal(data.revenue.paymentCount, 3);
      assert.equal(data.revenue.coachPackageCount, 3);
      assert.equal(data.revenue.voidReversalCount, 1);
      assert.equal(data.revenue.simulatedRefundCount, 2);

      // VN timezone byDay buckets:
      // 2026-11-20: gymGross = 2,000,000 (UTC 16:30 = 23:30+07), void = 0, coachGross = 5,000,000 (UTC 16:45 = 23:45+07)
      //             -> grossRevenue = 7,000,000, simulatedRefunds = 0, netRevenue = 7,000,000
      // 2026-11-21: gymGross = 2,500,000 (1,500,000 at UTC 17:30 prev day = 00:30+07 + 1,000,000 at 09:00+07),
      //             voidReversals = 1,500,000,
      //             coachGross = 4,950,000 (1,950,000 at UTC 17:15 prev day = 00:15+07 + 3,000,000 at 10:00+07),
      //             grossRevenue = 2,500,000 - 1,500,000 + 4,950,000 = 5,950,000,
      //             simulatedRefunds = 3,783,000,
      //             netRevenue = 5,950,000 - 3,783,000 = 2,167,000
      assert.deepEqual(data.revenue.byDay, [
        {
          day: '2026-11-20',
          gymGross: 2000000,
          voidReversals: 0,
          coachGross: 5000000,
          grossRevenue: 7000000,
          simulatedRefunds: 0,
          netRevenue: 7000000,
        },
        {
          day: '2026-11-21',
          gymGross: 2500000,
          voidReversals: 1500000,
          coachGross: 4950000,
          grossRevenue: 5950000,
          simulatedRefunds: 3783000,
          netRevenue: 2167000,
        },
      ]);

      // 3. Default date range (no from/to params) returns 200 with 30-day VN range
      const defaultRes = await call(base, '/admin/dashboard', adminToken);
      assert.equal(defaultRes.status, 200);
      assert.equal(defaultRes.body.data.timezone, 'Asia/Ho_Chi_Minh');
      assert.ok(defaultRes.body.data.from <= defaultRes.body.data.to);

      // 4. Privacy allowlist check — zero sensitive keys or member health data leaked
      const serialized = JSON.stringify(res.body);
      for (const forbiddenKey of FORBIDDEN_PRIVACY_KEYS) {
        assert.ok(!serialized.includes(`"${forbiddenKey}"`), `Forbidden key leaked: ${forbiddenKey}`);
      }
      for (const secretText of ['SECRET_GOAL_T15', 'SECRET_HEALTH_T15', 'SECRET_INJURY_T15', 'SECRET_DIET_T15']) {
        assert.ok(!serialized.includes(secretText), `Sensitive value leaked: ${secretText}`);
      }
    } finally {
      await database.query('DELETE FROM coach_notifications WHERE user_id = ANY($1::uuid[])', [allUsers]);
      await database.query('DELETE FROM simulated_refunds WHERE id = ANY($1::uuid[])', [[simRefundActiveId, simRefundQueuedId]]);
      await database.query('DELETE FROM coach_lock_incidents WHERE id = ANY($1::uuid[])', [[incWaitId, incRefundReqId, incResolvedRefundId]]);
      await database.query('DELETE FROM coach_termination_requests WHERE id = ANY($1::uuid[])', [[termDisputedId, termOverdueId]]);
      await database.query('DELETE FROM coach_entitlements WHERE id = ANY($1::uuid[])', [[entTransferredCopyId, entOriginActiveId, entQueuedRefundedId, entActiveRefundedId]]);
      await database.query('DELETE FROM coach_payment_holds WHERE id = ANY($1::uuid[])', [[hold1Id, hold2Id, hold3Id]]);
      await database.query('DELETE FROM coach_relationships WHERE id = ANY($1::uuid[])', [[
        relActiveId, relExpiredId, relCoachLockedWaitId,
        relCoachLockedRefundId, relMemberLockedId, relEndedRefundedId,
      ]]);
      await database.query('DELETE FROM gym_visits WHERE id = $1', [visitTodayId]);
      await database.query('DELETE FROM payment_adjustments WHERE id = $1', [adj1Id]);
      await database.query('DELETE FROM member_memberships WHERE id = ANY($1::uuid[])', [[mem1Id, mem2Id, mem3Id]]);
      await database.query('DELETE FROM payments WHERE id = ANY($1::uuid[])', [[gymPay1Id, gymPay2Id, gymPay3Id]]);
      await database.query('DELETE FROM membership_plans WHERE id = $1', [planId]);
      await database.query('DELETE FROM member_profiles WHERE user_id = ANY($1::uuid[])', [allMembers]);
      await database.query('DELETE FROM coach_profiles WHERE user_id = ANY($1::uuid[])', [[activeCoachId, lockedCoachId]]);
      await database.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [allUsers]);
      server.close();
      await database.end();
    }
  });
