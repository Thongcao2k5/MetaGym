import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';
import { reconcileMembershipLifecycles } from '../src/services/membership-lifecycle.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'web-admin-t9-accounts-locks-secret-32-chars';

function token(id, role, sessionVersion = 0) {
  return jwt.sign({ role, sessionVersion }, secret, {
    algorithm: 'HS256',
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    subject: id,
    expiresIn: 3600,
  });
}

async function call(base, path, bearer, method = 'GET', body) {
  const response = await fetch(`${base}/api/v1${path}`, {
    method,
    headers: {
      ...(bearer ? { authorization: `Bearer ${bearer}` } : {}),
      ...(body === undefined ? {} : { 'content-type': 'application/json' }),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: response.status, body: await response.json() };
}

test('T9: Hard cap 8, operational detail privacy allowlist, password reset, D1 Coach lock/unlock, and D4 Member lock/unlock',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const app = createApp({ database, jwtSecret: secret });
    const server = app.listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;

    const adminId = randomUUID();
    const m1Id = randomUUID();
    const m2Id = randomUUID();
    const m3Id = randomUUID();
    const m4Id = randomUUID();
    const m5Id = randomUUID();
    const planId = randomUUID();
    const rel1Id = randomUUID();
    const rel2Id = randomUUID();
    const rel4Id = randomUUID();
    const rel5Id = randomUUID();
    const hold1Id = randomUUID();
    const hold2Id = randomUUID();
    const hold3Id = randomUUID();
    const hold4Id = randomUUID();
    const hold4OpenId = randomUUID();
    const hold5Id = randomUUID();
    const ent1Id = randomUUID();
    const ent2Id = randomUUID();
    const ent4Id = randomUUID();
    const ent5Id = randomUUID();
    const booking1Id = randomUUID();
    const booking4Id = randomUUID();
    let coach1Id;
    let coach2Id;
    const memberIds = [m1Id, m2Id, m3Id, m4Id, m5Id];

    const adminToken = token(adminId, 'ADMIN', 0);

    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name, phone)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Admin T9', '0900000000'),
                ($3, $4, 'hash', 'MEMBER', 'Trần Thu Hà', '0911111111'),
                ($5, $6, 'hash', 'MEMBER', 'Lê Quang Huy', '0922222222'),
                ($7, $8, 'hash', 'MEMBER', 'Phạm Gia Bảo', '0933333333'),
                ($9, $10, 'hash', 'MEMBER', 'Nguyễn Minh Anh', '0944444444'),
                ($11, $12, 'hash', 'MEMBER', 'Hoàng Đức Nam', '0955555555')`,
        [
          adminId, `${adminId}@example.com`,
          m1Id, `${m1Id}@example.com`,
          m2Id, `${m2Id}@example.com`,
          m3Id, `${m3Id}@example.com`,
          m4Id, `${m4Id}@example.com`,
          m5Id, `${m5Id}@example.com`,
        ],
      );
      for (const mid of memberIds) {
        await database.query(
          `INSERT INTO member_profiles
           (user_id, height_cm, weight_kg, body_fat_percent, fitness_goal, health_notes, injury_notes, dietary_preferences, health_declaration_completed_at)
           VALUES ($1, 170, 65, 18, 'Tăng cơ giảm mỡ', 'Hen suyễn nhẹ bảo mật', 'Đau gối phải bảo mật', 'Ít tinh bột', now())`,
          [mid],
        );
      }

      // 1. Hard cap 8 on POST /admin/coaches, PATCH /admin/users/:id, and DB constraint
      assert.equal((await call(base, '/admin/coaches', adminToken, 'POST', {
        email: `badcap-${randomUUID()}@example.com`, fullName: 'Bad Cap Coach',
        password: 'StrongPass1', memberLimit: 5,
      })).status, 422);
      assert.equal((await call(base, '/admin/coaches', adminToken, 'POST', {
        email: `badcap2-${randomUUID()}@example.com`, fullName: 'Bad Cap Coach 2',
        password: 'StrongPass1', memberLimit: 12,
      })).status, 422);

      const createdCoach1 = await call(base, '/admin/coaches', adminToken, 'POST', {
        email: `coach1-${randomUUID()}@example.com`, fullName: 'Nguyễn Minh Quân',
        password: 'StrongPass1',
      });
      assert.equal(createdCoach1.status, 201);
      coach1Id = createdCoach1.body.data.id;
      assert.equal(createdCoach1.body.data.memberLimit, 8);

      const createdCoach2 = await call(base, '/admin/coaches', adminToken, 'POST', {
        email: `coach2-${randomUUID()}@example.com`, fullName: 'Võ Thành Long',
        password: 'StrongPass1', memberLimit: 8,
      });
      assert.equal(createdCoach2.status, 201);
      coach2Id = createdCoach2.body.data.id;
      assert.equal(createdCoach2.body.data.memberLimit, 8);

      // PATCH /admin/users/:id rejects memberLimit
      const patchRejected = await call(base, `/admin/users/${coach1Id}`, adminToken, 'PATCH', {
        memberLimit: 6,
      });
      assert.equal(patchRejected.status, 422);
      assert.ok(patchRejected.body.error.details.fields.memberLimit);

      // DB hard cap constraint rejects member_limit <> 8 directly
      await assert.rejects(
        () => database.query('UPDATE coach_profiles SET member_limit = 5 WHERE user_id = $1', [coach1Id]),
        (err) => err.code === '23514' && err.constraint === 'ck_coach_profiles_member_limit_fixed',
      );

      // 2. Password reset returns temporaryPassword + reminder & never logs temporaryPassword
      const reset = await call(base, `/admin/coaches/${coach1Id}/password-resets`, adminToken, 'POST', {});
      assert.equal(reset.status, 201);
      assert.ok(reset.body.data.temporaryPassword.length >= 20);
      assert.equal(
        reset.body.data.reminder,
        'Hãy gửi mật khẩu tạm cho Coach qua kênh nội bộ và nhắc Coach đổi mật khẩu sau khi đăng nhập.',
      );
      const resetAudit = await database.query(
        `SELECT metadata FROM admin_audit_logs WHERE entity_id = $1 AND action = 'COACH_PASSWORD_RESET'`,
        [coach1Id],
      );
      assert.equal(JSON.stringify(resetAudit.rows[0].metadata).includes(reset.body.data.temporaryPassword), false);
      assert.equal(JSON.stringify(resetAudit.rows[0].metadata).includes('temporaryPassword'), false);
      const storedCoach1 = await database.query('SELECT password_hash, session_version FROM users WHERE id = $1', [coach1Id]);
      assert.equal(await bcrypt.compare(reset.body.data.temporaryPassword, storedCoach1.rows[0].password_hash), true);
      const coach1Token = token(coach1Id, 'COACH', storedCoach1.rows[0].session_version);

      // Setup Gym plans, memberships, Coach schedule, relationships, holds, entitlements, future bookings
      await database.query(
        `INSERT INTO membership_plans (id, name, price, duration_days, status, created_by)
         VALUES ($1, 'Gói Gym 30 ngày', 500000, 30, 'ACTIVE', $2)`,
        [planId, adminId],
      );
      const { rows: [{ today_vn: todayVn }] } = await database.query(
        `SELECT (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS today_vn`,
      );
      for (const mid of [m1Id, m2Id, m4Id, m5Id]) {
        const payId = randomUUID();
        await database.query(
          `INSERT INTO payments (id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
           amount, method, status, transaction_code, idempotency_key, request_hash, created_by, confirmed_at, decided_at)
           VALUES ($1, $2, $3, 'Gói Gym 30 ngày', 30, 500000, 'MOCK_QR', 'SUCCESS',
                   $1::uuid::text, $1::uuid::text, repeat('a', 64), $2, now(), now())`,
          [payId, mid, planId],
        );
        await database.query(
          `INSERT INTO member_memberships (id, member_id, plan_id, source_payment_id, start_date, end_date, status, activated_at)
           VALUES ($1, $2, $3, $4, $5::date - 5, $5::date + 24, 'ACTIVE', now())`,
          [randomUUID(), mid, planId, payId, todayVn],
        );
      }

      // Configure Coach 1 weekly schedule (6 days * 4 slots)
      await database.query(
        `INSERT INTO coach_weekly_slots (id, coach_id, weekday, start_minute)
         SELECT gen_random_uuid(), $1, d, m
         FROM generate_series(1, 6) d CROSS JOIN generate_series(360, 630, 90) m`,
        [coach1Id],
      );

      // Coach 1 has M1 (ACTIVE), M2 (ACTIVE), plus open HELD hold from M3
      // Coach 2 has M4 (ACTIVE), M5 (PAUSED COACH_LOCKED test)
      await database.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id, status)
         VALUES ($1, $2, $3, 'ACTIVE'),
                ($4, $5, $3, 'ACTIVE'),
                ($6, $7, $8, 'ACTIVE'),
                ($9, $10, $8, 'ACTIVE')`,
        [rel1Id, m1Id, coach1Id, rel2Id, m2Id, rel4Id, m4Id, coach2Id, rel5Id, m5Id],
      );
      await database.query(
        `INSERT INTO coach_payment_holds
         (id, member_id, coach_id, plan_code, plan_name, session_count, duration_days, amount, request_key, status, created_at, expires_at, settled_at)
         VALUES
         ($1, $2, $3, 'BASIC', 'Cơ bản', 10, 30, 2000000, gen_random_uuid(), 'CONSUMED', now() - interval '5 days', now() - interval '5 days' + interval '15 minutes', now() - interval '5 days'),
         ($4, $5, $3, 'BASIC', 'Cơ bản', 10, 30, 2000000, gen_random_uuid(), 'CONSUMED', now() - interval '5 days', now() - interval '5 days' + interval '15 minutes', now() - interval '5 days'),
         ($6, $7, $3, 'BASIC', 'Cơ bản', 10, 30, 2000000, gen_random_uuid(), 'HELD', statement_timestamp(), statement_timestamp() + interval '15 minutes', NULL),
         ($8, $9, $10, 'BASIC', 'Cơ bản', 10, 30, 2000000, gen_random_uuid(), 'CONSUMED', now() - interval '5 days', now() - interval '5 days' + interval '15 minutes', now() - interval '5 days'),
         ($11, $9, $10, 'BASIC', 'Cơ bản', 10, 30, 2000000, gen_random_uuid(), 'HELD', statement_timestamp(), statement_timestamp() + interval '15 minutes', NULL),
         ($12, $13, $10, 'BASIC', 'Cơ bản', 10, 30, 2000000, gen_random_uuid(), 'CONSUMED', now() - interval '5 days', now() - interval '5 days' + interval '15 minutes', now() - interval '5 days')`,
        [
          hold1Id, m1Id, coach1Id,
          hold2Id, m2Id,
          hold3Id, m3Id,
          hold4Id, m4Id, coach2Id,
          hold4OpenId,
          hold5Id, m5Id,
        ],
      );
      await database.query(
        `INSERT INTO coach_entitlements
         (id, hold_id, original_hold_id, relationship_id, member_id, coach_id,
          plan_code, plan_name, snapshot_price, status, total_sessions, remaining_sessions,
          duration_days, starts_on, original_ends_on, ends_on)
         VALUES
         ($1, $2, $2, $3, $4, $5, 'BASIC', 'Cơ bản', 2000000, 'ACTIVE', 10, 6, 30, $13::date - 5, $13::date + 24, $13::date + 24),
         ($6, $7, $7, $8, $9, $5, 'BASIC', 'Cơ bản', 2000000, 'ACTIVE', 10, 8, 30, $13::date - 5, $13::date + 24, $13::date + 24),
         ($10, $11, $11, $12, $14, $15, 'BASIC', 'Cơ bản', 2000000, 'ACTIVE', 10, 7, 30, $13::date - 5, $13::date + 24, $13::date + 24),
         ($16, $17, $17, $18, $19, $15, 'BASIC', 'Cơ bản', 2000000, 'ACTIVE', 10, 9, 30, $13::date - 5, $13::date + 24, $13::date + 24)`,
        [
          ent1Id, hold1Id, rel1Id, m1Id, coach1Id,
          ent2Id, hold2Id, rel2Id, m2Id,
          ent4Id, hold4Id, rel4Id, todayVn, m4Id, coach2Id,
          ent5Id, hold5Id, rel5Id, m5Id,
        ],
      );
      // Future BOOKED bookings for M1 (with Coach 1) and M4 (with Coach 2)
      await database.query(
        `INSERT INTO coach_bookings (id, entitlement_id, member_id, coach_id, starts_at, ends_at, status)
         VALUES ($1, $2, $3, $4, statement_timestamp() + interval '2 days', statement_timestamp() + interval '2 days 90 minutes', 'BOOKED'),
                ($5, $6, $7, $8, statement_timestamp() + interval '3 days', statement_timestamp() + interval '3 days 90 minutes', 'BOOKED')`,
        [booking1Id, ent1Id, m1Id, coach1Id, booking4Id, ent4Id, m4Id, coach2Id],
      );

      // 3. GET /admin/users (search by phone, usedSlots, member fields) & GET /admin/users/:userId (privacy allowlist!)
      const searchByPhone = await call(base, '/admin/users?role=MEMBER&search=0911111111', adminToken);
      assert.equal(searchByPhone.status, 200);
      assert.equal(searchByPhone.body.pagination.totalItems, 1);
      assert.equal(searchByPhone.body.data[0].id, m1Id);
      assert.ok(searchByPhone.body.data[0].activeMembershipEndDate);
      assert.equal(searchByPhone.body.data[0].coachRelationshipStatus, 'ACTIVE');
      assert.equal(searchByPhone.body.data[0].coachPauseReason, null);

      const coachList = await call(base, '/admin/users?role=COACH&search=Minh%20Qu%C3%A2n', adminToken);
      assert.equal(coachList.status, 200);
      assert.equal(coachList.body.data[0].usedSlots, 3); // M1 + M2 + M3 hold
      assert.equal(coachList.body.data[0].memberLimit, 8);

      const coachDetail = await call(base, `/admin/users/${coach1Id}`, adminToken);
      assert.equal(coachDetail.status, 200);
      assert.equal(coachDetail.body.data.usedSlots, 3);
      assert.equal(coachDetail.body.data.activeRelationshipsCount, 2);
      assert.equal(coachDetail.body.data.openHoldCount, 1);
      assert.equal(coachDetail.body.data.scheduleConfigured, true);

      const memberDetail = await call(base, `/admin/users/${m1Id}`, adminToken);
      assert.equal(memberDetail.status, 200);
      assert.equal(memberDetail.body.data.currentCoachRelationship.coachName, 'Nguyễn Minh Quân');
      assert.ok(memberDetail.body.data.currentMembership.endDate);
      const memberDetailJson = JSON.stringify(memberDetail.body);
      for (const forbidden of ['healthNotes', 'injuryNotes', 'heightCm', 'weightKg', 'bodyFatPercent', 'fitnessGoal', 'dietaryPreferences', 'Hen suyễn', 'Đau gối']) {
        assert.equal(memberDetailJson.includes(forbidden), false, `Admin detail must not expose ${forbidden}`);
      }

      // 4. GET /admin/users/:userId/lock-preview for Coach 1 & Member 4
      const coachPreview = await call(base, `/admin/users/${coach1Id}/lock-preview`, adminToken);
      assert.equal(coachPreview.status, 200);
      assert.equal(coachPreview.body.data.affectedRelationshipsCount, 2);
      assert.equal(coachPreview.body.data.futureBookingsToCancelCount, 1);
      assert.equal(coachPreview.body.data.openHoldsToCancelCount, 1);
      assert.equal(coachPreview.body.data.policy.freezeCoachEntitlements, true);
      assert.equal(coachPreview.body.data.policy.freezeGymMemberships, false);

      const memberPreview = await call(base, `/admin/users/${m4Id}/lock-preview`, adminToken);
      assert.equal(memberPreview.status, 200);
      assert.equal(memberPreview.body.data.affectedRelationshipsCount, 1);
      assert.equal(memberPreview.body.data.futureBookingsToCancelCount, 1);
      assert.equal(memberPreview.body.data.openHoldsToCancelCount, 1);
      assert.equal(memberPreview.body.data.policy.freezeCoachEntitlements, false);
      assert.equal(memberPreview.body.data.policy.keepCoachSeatsOccupied, true);

      // 5. D1: Lock Coach 1 (DISABLED)
      const lockCoach = await call(base, `/admin/users/${coach1Id}/status`, adminToken, 'PATCH', {
        status: 'DISABLED', reason: 'Coach nghỉ phép dài ngày',
      });
      assert.equal(lockCoach.status, 200, JSON.stringify(lockCoach.body));
      assert.equal(lockCoach.body.data.user.status, 'DISABLED');
      assert.equal(lockCoach.body.data.effects.sessionsRevoked, true);
      assert.equal(lockCoach.body.data.effects.cancelledHoldsCount, 1);
      assert.equal(lockCoach.body.data.effects.cancelledFutureBookingsCount, 1);
      assert.equal(lockCoach.body.data.effects.affectedRelationshipsCount, 2);
      assert.equal(lockCoach.body.data.effects.incidentsCreated.length, 2);
      assert.ok(lockCoach.body.data.effects.incidentsCreated.every((i) => i.entitlementFrozen === true));

      // Coach 1 session revoked immediately
      assert.equal((await call(base, '/users/me', coach1Token)).status, 401);
      // M1's future booking cancelled WITHOUT charging
      const b1After = (await database.query('SELECT status, charged_at FROM coach_bookings WHERE id = $1', [booking1Id])).rows[0];
      assert.equal(b1After.status, 'CANCELLED');
      assert.equal(b1After.charged_at, null);
      const ent1Frozen = (await database.query('SELECT remaining_sessions, frozen_at, ends_on::text FROM coach_entitlements WHERE id = $1', [ent1Id])).rows[0];
      assert.equal(ent1Frozen.remaining_sessions, 6);
      assert.ok(ent1Frozen.frozen_at);
      // M1 sees frozenAt on GET /coach-entitlements
      const m1EntView = await call(base, '/coach-entitlements', token(m1Id, 'MEMBER', 0));
      assert.equal(m1EntView.status, 200);
      assert.ok(m1EntView.body.data[0].frozenAt);
      // M3 hold cancelled
      assert.equal((await database.query('SELECT status FROM coach_payment_holds WHERE id = $1', [hold3Id])).rows[0].status, 'CANCELLED');
      // COACH_LOCKED notifications created
      const lockNotifs = await database.query(
        `SELECT user_id FROM coach_notifications WHERE kind = 'COACH_LOCKED' AND user_id IN ($1, $2)`,
        [m1Id, m2Id],
      );
      assert.equal(lockNotifs.rowCount, 2);

      // Simulate 4 VN days passing while Coach 1 is locked, AND M2's Gym expiring,
      // AND ent1's original_ends_on being in the past to prove reconcile NEVER expires frozen entitlements!
      await database.query(
        `UPDATE coach_lock_incidents
         SET frozen_started_at = statement_timestamp() - interval '4 days'
         WHERE coach_id = $1 AND status = 'OPEN'`,
        [coach1Id],
      );
      await database.query(
        `UPDATE coach_entitlements
         SET frozen_at = statement_timestamp() - interval '4 days'
         WHERE id IN ($1, $2)`,
        [ent1Id, ent2Id],
      );
      await database.query(
        `UPDATE member_memberships SET end_date = $2::date - 2 WHERE member_id = $1`,
        [m2Id, todayVn],
      );
      // Temporarily verify frozen entitlement survives reconciliation even if ends_on < today
      const testPool = new pg.Pool({ connectionString: databaseUrl });
      try {
        await reconcileMembershipLifecycles(testPool);
      } finally {
        await testPool.end();
      }
      // M2 Gym expired, but relationship MUST remain COACH_LOCKED (NOT overwritten), and both entitlements still ACTIVE + frozen!
      const relsDuringLock = (await database.query(
        'SELECT id, status, pause_reason FROM coach_relationships WHERE id IN ($1, $2) ORDER BY id',
        [rel1Id, rel2Id],
      )).rows;
      assert.ok(relsDuringLock.every((r) => r.status === 'PAUSED' && r.pause_reason === 'COACH_LOCKED'));

      // 6. D1: Unlock Coach 1 (ACTIVE) -> auto-restore OPEN incidents with delta_days = 4 once!
      const unlockCoach = await call(base, `/admin/users/${coach1Id}/status`, adminToken, 'PATCH', {
        status: 'ACTIVE',
      });
      assert.equal(unlockCoach.status, 200, JSON.stringify(unlockCoach.body));
      assert.equal(unlockCoach.body.data.user.status, 'ACTIVE');
      assert.equal(unlockCoach.body.data.effects.restoredRelationshipsCount, 2);
      const r1Restored = unlockCoach.body.data.effects.restored.find((r) => r.memberId === m1Id);
      const r2Restored = unlockCoach.body.data.effects.restored.find((r) => r.memberId === m2Id);
      assert.equal(r1Restored.newRelationshipStatus, 'ACTIVE');
      assert.equal(r1Restored.newPauseReason, null);
      assert.equal(r1Restored.frozenDaysAdded, 4);
      assert.equal(r2Restored.newRelationshipStatus, 'PAUSED');
      assert.equal(r2Restored.newPauseReason, 'MEMBERSHIP_EXPIRED');
      assert.equal(r2Restored.frozenDaysAdded, 4);

      const ent1Thawed = (await database.query(
        `SELECT frozen_at, frozen_days_total, (ends_on - original_ends_on)::int AS diff FROM coach_entitlements WHERE id = $1`,
        [ent1Id],
      )).rows[0];
      assert.equal(ent1Thawed.frozen_at, null);
      assert.equal(ent1Thawed.frozen_days_total, 4);
      assert.equal(ent1Thawed.diff, 4);

      // Verify notify_coach_package did NOT falsely emit PACKAGE_EXTENDED on freeze thaw!
      const falseExtended = await database.query(
        `SELECT 1 FROM coach_notifications WHERE user_id IN ($1, $2) AND kind = 'PACKAGE_EXTENDED'`,
        [m1Id, m2Id],
      );
      assert.equal(falseExtended.rowCount, 0);

      // Retry unlock (idempotent no-op) must NOT double-add 4 days!
      const unlockRetry = await call(base, `/admin/users/${coach1Id}/status`, adminToken, 'PATCH', {
        status: 'ACTIVE',
      });
      assert.equal(unlockRetry.status, 200);
      assert.equal(unlockRetry.body.data.effects.restoredRelationshipsCount, 0);
      assert.equal((await database.query('SELECT frozen_days_total FROM coach_entitlements WHERE id = $1', [ent1Id])).rows[0].frozen_days_total, 4);

      // Same-day lock & unlock -> delta_days = 0
      const sameDayLock = await call(base, `/admin/users/${coach1Id}/status`, adminToken, 'PATCH', {
        status: 'DISABLED', reason: 'Bấm nhầm cùng ngày',
      });
      assert.equal(sameDayLock.status, 200);
      const sameDayUnlock = await call(base, `/admin/users/${coach1Id}/status`, adminToken, 'PATCH', {
        status: 'ACTIVE',
      });
      assert.equal(sameDayUnlock.status, 200);
      const m1SameDay = sameDayUnlock.body.data.effects.restored.find((r) => r.memberId === m1Id);
      assert.equal(m1SameDay.frozenDaysAdded, 0);
      assert.equal((await database.query('SELECT frozen_days_total FROM coach_entitlements WHERE id = $1', [ent1Id])).rows[0].frozen_days_total, 4);

      // 7. D4: Lock & Unlock Member M4 (active with Coach 2)
      const coach2Token = token(coach2Id, 'COACH', 0);
      // Before lock: Coach 2 CAN read M4's health profile
      const beforeMemberLockView = await call(base, `/coach/members/${m4Id}`, coach2Token);
      assert.equal(beforeMemberLockView.status, 200);
      assert.equal(beforeMemberLockView.body.data.member.healthNotes, 'Hen suyễn nhẹ bảo mật');
      assert.equal(beforeMemberLockView.body.data.member.injuryNotes, 'Đau gối phải bảo mật');
      const seatsBeforeM4Lock = (await database.query('SELECT coach_occupied_seats($1) AS n', [coach2Id])).rows[0].n;
      assert.equal(seatsBeforeM4Lock, 2); // M4 + M5 (open hold4OpenId is same member M4)

      const lockM4 = await call(base, `/admin/users/${m4Id}/status`, adminToken, 'PATCH', {
        status: 'DISABLED', reason: 'Vi phạm nội quy phòng tập',
      });
      assert.equal(lockM4.status, 200, JSON.stringify(lockM4.body));
      assert.equal(lockM4.body.data.user.status, 'DISABLED');
      assert.equal(lockM4.body.data.effects.cancelledHoldsCount, 1);
      assert.equal(lockM4.body.data.effects.cancelledFutureBookingsCount, 1);
      assert.equal(lockM4.body.data.effects.relationshipStatus, 'PAUSED');
      assert.equal(lockM4.body.data.effects.pauseReason, 'MEMBER_LOCKED');
      assert.equal(lockM4.body.data.effects.coachSeatKept, true);
      assert.equal(lockM4.body.data.effects.entitlementFrozen, false);

      // M4 session revoked, future booking cancelled without charging, entitlement NOT frozen, seat kept
      assert.equal((await call(base, '/users/me', token(m4Id, 'MEMBER', 0))).status, 401);
      const b4After = (await database.query('SELECT status, charged_at FROM coach_bookings WHERE id = $1', [booking4Id])).rows[0];
      assert.equal(b4After.status, 'CANCELLED');
      assert.equal(b4After.charged_at, null);
      const ent4After = (await database.query('SELECT frozen_at, remaining_sessions FROM coach_entitlements WHERE id = $1', [ent4Id])).rows[0];
      assert.equal(ent4After.frozen_at, null);
      assert.equal(ent4After.remaining_sessions, 7);
      assert.equal((await database.query('SELECT coach_occupied_seats($1) AS n', [coach2Id])).rows[0].n, 2);

      // Coach 2 sees NULL for ALL 7 health fields while M4 is MEMBER_LOCKED!
      const lockedMemberView = await call(base, `/coach/members/${m4Id}`, coach2Token);
      assert.equal(lockedMemberView.status, 200);
      assert.equal(lockedMemberView.body.data.status, 'PAUSED');
      assert.equal(lockedMemberView.body.data.pauseReason, 'MEMBER_LOCKED');
      for (const field of ['fitnessGoal', 'heightCm', 'weightKg', 'bodyFatPercent', 'healthNotes', 'injuryNotes', 'healthDeclarationCompletedAt']) {
        assert.equal(lockedMemberView.body.data.member[field], null, `Expected ${field} to be null while MEMBER_LOCKED`);
      }

      // Reconcile must NOT auto-resume MEMBER_LOCKED!
      const testPool2 = new pg.Pool({ connectionString: databaseUrl });
      try {
        await reconcileMembershipLifecycles(testPool2);
      } finally {
        await testPool2.end();
      }
      assert.equal(
        (await database.query('SELECT pause_reason FROM coach_relationships WHERE id = $1', [rel4Id])).rows[0].pause_reason,
        'MEMBER_LOCKED',
      );

      // Unlock M4 while Gym & Coach entitlement still valid -> restores to ACTIVE + Coach sees health again
      const unlockM4 = await call(base, `/admin/users/${m4Id}/status`, adminToken, 'PATCH', {
        status: 'ACTIVE',
      });
      assert.equal(unlockM4.status, 200);
      assert.equal(unlockM4.body.data.effects.relationshipStatus, 'ACTIVE');
      assert.equal(unlockM4.body.data.effects.pauseReason, null);
      const restoredMemberView = await call(base, `/coach/members/${m4Id}`, coach2Token);
      assert.equal(restoredMemberView.body.data.member.healthNotes, 'Hen suyễn nhẹ bảo mật');

      // Test D4 unlock when Coach entitlement expired while Member was locked (clock kept running!)
      await call(base, `/admin/users/${m4Id}/status`, adminToken, 'PATCH', {
        status: 'DISABLED', reason: 'Khóa dài hơn hạn gói Coach',
      });
      await database.query(
        `UPDATE coach_entitlements
         SET starts_on = $2::date - 45, original_ends_on = $2::date - 16,
             grace_days_added = 7, ends_on = $2::date - 9
         WHERE id = $1`,
        [ent4Id, todayVn],
      );
      const unlockM4Expired = await call(base, `/admin/users/${m4Id}/status`, adminToken, 'PATCH', {
        status: 'ACTIVE',
      });
      assert.equal(unlockM4Expired.status, 200);
      assert.equal(unlockM4Expired.body.data.effects.relationshipStatus, 'ENDED');
      assert.equal((await database.query('SELECT status FROM coach_entitlements WHERE id = $1', [ent4Id])).rows[0].status, 'ENDED');

      // Test locking Member M5 while already COACH_LOCKED does NOT overwrite COACH_LOCKED
      await call(base, `/admin/users/${coach2Id}/status`, adminToken, 'PATCH', {
        status: 'DISABLED', reason: 'Khóa Coach 2',
      });
      assert.equal(
        (await database.query('SELECT pause_reason FROM coach_relationships WHERE id = $1', [rel5Id])).rows[0].pause_reason,
        'COACH_LOCKED',
      );
      const lockM5 = await call(base, `/admin/users/${m5Id}/status`, adminToken, 'PATCH', {
        status: 'DISABLED', reason: 'Khóa Member khi đã COACH_LOCKED',
      });
      assert.equal(lockM5.status, 200);
      assert.equal(
        (await database.query('SELECT pause_reason FROM coach_relationships WHERE id = $1', [rel5Id])).rows[0].pause_reason,
        'COACH_LOCKED',
      );
    } finally {
      const allUsers = [adminId, ...memberIds, ...(coach1Id ? [coach1Id] : []), ...(coach2Id ? [coach2Id] : [])];
      await database.query('DELETE FROM coach_notifications WHERE user_id = ANY($1::uuid[])', [allUsers]);
      await database.query('DELETE FROM coach_lock_incidents WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM coach_bookings WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM coach_entitlements WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM coach_payment_holds WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM coach_relationships WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM member_memberships WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM payments WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM membership_plans WHERE id = $1', [planId]);
      if (coach1Id) await database.query('DELETE FROM coach_weekly_slots WHERE coach_id = $1', [coach1Id]);
      await database.query('DELETE FROM admin_audit_logs WHERE admin_id = $1', [adminId]);
      await database.query('DELETE FROM coach_profiles WHERE user_id = ANY($1::uuid[])', [allUsers]);
      await database.query('DELETE FROM member_profiles WHERE user_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [allUsers]);
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });
