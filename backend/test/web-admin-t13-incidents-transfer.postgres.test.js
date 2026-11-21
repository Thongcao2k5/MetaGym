import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';
import { hasCoachCapacity } from '../src/services/coach-capacity.js';
import { reconcileMembershipLifecycles } from '../src/services/membership-lifecycle.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'web-admin-t13-incidents-transfer-secret-32-chars';

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

async function configureFullSchedule(database, coachId, daysCount = 6, starts = [360, 450, 540, 630]) {
  for (let d = 1; d <= daysCount; d += 1) {
    for (const m of starts) {
      await database.query(
        `INSERT INTO coach_weekly_slots (id, coach_id, weekday, start_minute)
         VALUES ($1, $2, $3, $4)`,
        [randomUUID(), coachId, d, m],
      );
    }
  }
}

test('T13: Coach lock incident queue, Member WAIT/REFUND choice, eligible coaches D2 capacity check, atomic D2 transfer, idempotency, and concurrency',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const app = createApp({ database, jwtSecret: secret });
    const server = app.listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;

    const adminId = randomUUID();
    const coachAId = randomUUID(); // Locked Coach
    const coachBId = randomUUID(); // Eligible target Coach
    const coachCId = randomUUID(); // Full Coach (7 relationships + 1 live 15-min hold = 8)
    const coachDId = randomUUID(); // Unconfigured schedule Coach (only 5 weekdays)
    const coachEId = randomUUID(); // Active Coach for proactive POST /admin/coach-transfers
    const coachFId = randomUUID(); // ACTIVE fits alone, but ACTIVE + QUEUED overflows!
    const coachGId = randomUUID(); // Concurrency Coach (7 relationships -> transfer vs 15-min hold race for seat #8)

    const m1Id = randomUUID(); // Coach A -> active Gym + ACTIVE + QUEUED + plans + chat -> D2 transfer to Coach B
    const m2Id = randomUUID(); // Coach A -> expired Gym + ACTIVE + QUEUED -> D3+D2 refund est + transfer as PAUSED (MEMBERSHIP_EXPIRED)
    const m3Id = randomUUID(); // Coach A -> active Gym + ACTIVE -> races with M9 hold for Coach G seat #8
    const m4Id = randomUUID(); // Coach E (ACTIVE) -> proactive /admin/coach-transfers with future bookings + QUEUED + open termination
    const m9Id = randomUUID(); // Free Member with active Gym + health declaration -> races for Coach G seat #8
    const cHoldMemberId = randomUUID(); // Holds seat #8 on Coach C
    const cFillers = Array.from({ length: 7 }, () => randomUUID());
    const gFillers = Array.from({ length: 7 }, () => randomUUID());

    const coachIds = [coachAId, coachBId, coachCId, coachDId, coachEId, coachFId, coachGId];
    const primaryMembers = [m1Id, m2Id, m3Id, m4Id, m9Id, cHoldMemberId];
    const allMembers = [...primaryMembers, ...cFillers, ...gFillers];
    const allUsers = [adminId, ...coachIds, ...allMembers];

    const planId = randomUUID();
    const relM1Id = randomUUID();
    const relM2Id = randomUUID();
    const relM3Id = randomUUID();
    const relM4Id = randomUUID();

    const adminToken = token(adminId, 'ADMIN');
    const coachAToken = token(coachAId, 'COACH');
    const coachBToken = token(coachBId, 'COACH');
    const m1Token = token(m1Id, 'MEMBER');
    const m2Token = token(m2Id, 'MEMBER');
    const m4Token = token(m4Id, 'MEMBER');
    const m9Token = token(m9Id, 'MEMBER');

    let originalBasicPrice;
    let originalStandardPrice;
    let originalAdvancedPrice;

    try {
      // Snapshot original package catalog prices to restore in finally
      const origPlans = (await database.query(
        `SELECT code, price FROM coach_package_plans WHERE code IN ('BASIC', 'STANDARD', 'ADVANCED')`,
      )).rows;
      const origByCode = Object.fromEntries(origPlans.map((p) => [p.code, Number(p.price)]));
      originalBasicPrice = origByCode.BASIC;
      originalStandardPrice = origByCode.STANDARD;
      originalAdvancedPrice = origByCode.ADVANCED;

      await database.query(
        `UPDATE coach_package_plans SET status = 'ACTIVE' WHERE code IN ('BASIC', 'STANDARD', 'ADVANCED')`,
      );

      // Insert users
      const userTuples = [
        [adminId, 'ADMIN', 'Quản trị T13'],
        [coachAId, 'COACH', 'HLV An Khóa'],
        [coachBId, 'COACH', 'HLV Bình Đủ Chuẩn'],
        [coachCId, 'COACH', 'HLV Cường Đầy Suất'],
        [coachDId, 'COACH', 'HLV Dũng Thiếu Lịch'],
        [coachEId, 'COACH', 'HLV Em Chủ Động'],
        [coachFId, 'COACH', 'HLV Phong Thiếu Công Suất'],
        [coachGId, 'COACH', 'HLV Giang Cạnh Tranh'],
        [m1Id, 'MEMBER', 'Trần Thu Hà'],
        [m2Id, 'MEMBER', 'Lê Quang Huy'],
        [m3Id, 'MEMBER', 'Phạm Gia Bảo'],
        [m4Id, 'MEMBER', 'Nguyễn Minh Anh'],
        [m9Id, 'MEMBER', 'Vũ Hoàng Long'],
        [cHoldMemberId, 'MEMBER', 'Đỗ Thị Lan'],
        ...cFillers.map((id, idx) => [id, 'MEMBER', `Filler C ${idx + 1}`]),
        ...gFillers.map((id, idx) => [id, 'MEMBER', `Filler G ${idx + 1}`]),
      ];
      for (const [id, role, fullName] of userTuples) {
        await database.query(
          `INSERT INTO users (id, email, password_hash, role, full_name)
           VALUES ($1, $2, 'hash', $3, $4)`,
          [id, `${id}@example.com`, role, fullName],
        );
      }
      for (const cid of coachIds) {
        await database.query('INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 8)', [cid]);
      }
      for (const mid of primaryMembers) {
        await database.query(
          `INSERT INTO member_profiles
           (user_id, height_cm, weight_kg, body_fat_percent, fitness_goal,
            health_notes, injury_notes, dietary_preferences, health_declaration_completed_at)
           VALUES ($1, 171, 64, 18.2, 'SECRET_GOAL_T13',
                   'SECRET_HEALTH_T13', 'SECRET_INJURY_T13', 'SECRET_DIET_T13', now())`,
          [mid],
        );
      }

      // Schedules:
      // Coach A, B, C, E, F, G: 6 weekdays * 4 contiguous 90-min slots
      // Coach D: only 5 weekdays -> SCHEDULE_REQUIRED
      for (const cid of [coachAId, coachBId, coachCId, coachEId, coachFId, coachGId]) {
        await configureFullSchedule(database, cid, 6);
      }
      await configureFullSchedule(database, coachDId, 5);

      await database.query(
        `INSERT INTO membership_plans (id, name, price, duration_days, status, created_by)
         VALUES ($1, 'Gym T13 30d', 500000, 30, 'ACTIVE', $2)`,
        [planId, adminId],
      );
      const { rows: [{ today_vn: todayVn }] } = await database.query(
        `SELECT (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS today_vn`,
      );

      // Active Gym for M1, M2 (will expire during lock), M3, M4, M9
      for (const mid of [m1Id, m2Id, m3Id, m4Id, m9Id]) {
        const payId = randomUUID();
        await database.query(
          `INSERT INTO payments (id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
           amount, method, status, transaction_code, idempotency_key, request_hash, created_by, decided_by, confirmed_at, decided_at)
           VALUES ($1, $2, $3, 'Gym T13 30d', 30, 500000, 'FRONT_DESK', 'SUCCESS',
                   $1::uuid::text, $1::uuid::text, repeat('a', 64), $4, $4, now(), now())`,
          [payId, mid, planId, adminId],
        );
        await database.query(
          `INSERT INTO member_memberships (id, member_id, plan_id, source_payment_id, start_date, end_date, status, activated_at)
           VALUES ($1, $2, $3, $4, $5::date - 5, $5::date + 24, 'ACTIVE', now())`,
          [randomUUID(), mid, planId, payId, todayVn],
        );
      }

      // Fill Coach C with 7 ACTIVE relationships + 1 live 15-min HELD hold = 8 seats
      for (const fid of cFillers) {
        await database.query(
          `INSERT INTO coach_relationships (id, member_id, coach_id, status)
           VALUES ($1, $2, $3, 'ACTIVE')`,
          [randomUUID(), fid, coachCId],
        );
      }
      const coachCHoldId = randomUUID();
      await database.query(
        `INSERT INTO coach_payment_holds
         (id, member_id, coach_id, plan_code, plan_name, session_count, duration_days,
          amount, request_key, status, created_at, expires_at)
         VALUES ($1, $2, $3, 'BASIC', 'Cơ bản', 10, 30, 2000000, gen_random_uuid(),
                 'HELD', statement_timestamp(), statement_timestamp() + interval '15 minutes')`,
        [coachCHoldId, cHoldMemberId, coachCId],
      );

      // Fill Coach G with 7 ACTIVE relationships (leaving exactly 1 seat #8 open for race!)
      for (const fid of gFillers) {
        await database.query(
          `INSERT INTO coach_relationships (id, member_id, coach_id, status)
           VALUES ($1, $2, $3, 'ACTIVE')`,
          [randomUUID(), fid, coachGId],
        );
      }

      // Primary relationships: M1, M2, M3 on Coach A; M4 on Coach E
      await database.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id, status)
         VALUES ($1, $5, $9, 'ACTIVE'),
                ($2, $6, $9, 'ACTIVE'),
                ($3, $7, $9, 'ACTIVE'),
                ($4, $8, $10, 'ACTIVE')`,
        [relM1Id, relM2Id, relM3Id, relM4Id, m1Id, m2Id, m3Id, m4Id, coachAId, coachEId],
      );

      // Holds & entitlements:
      // M1: ACTIVE (STANDARD 20/60, snapshot 4,000,000, rem 12) + QUEUED (BASIC 10/30, snapshot 2,200,000)
      // M2: ACTIVE (ADVANCED 30/90, snapshot 5,000,000, rem 11) + QUEUED (BASIC 10/30, snapshot 1,950,000)
      // M3: ACTIVE (BASIC 10/30, snapshot 2,000,000, rem 8)
      // M4: ACTIVE (STANDARD 20/60, snapshot 4,000,000, rem 14) + QUEUED (BASIC 10/30, snapshot 2,100,000)
      const hM1Active = randomUUID();
      const hM1Queued = randomUUID();
      const hM2Active = randomUUID();
      const hM2Queued = randomUUID();
      const hM3Active = randomUUID();
      const hM4Active = randomUUID();
      const hM4Queued = randomUUID();
      const entM1Active = randomUUID();
      const entM1Queued = randomUUID();
      const entM2Active = randomUUID();
      const entM2Queued = randomUUID();
      const entM3Active = randomUUID();
      const entM4Active = randomUUID();
      const entM4Queued = randomUUID();

      await database.query(
        `INSERT INTO coach_payment_holds
         (id, member_id, coach_id, plan_code, plan_name, session_count, duration_days,
          amount, request_key, status, created_at, expires_at, settled_at)
         VALUES
         ($1, $8, $12, 'STANDARD', 'Tiêu chuẩn', 20, 60, 4000000, gen_random_uuid(), 'CONSUMED', now() - interval '10 days', now() - interval '10 days' + interval '15 minutes', now() - interval '10 days'),
         ($2, $8, $12, 'BASIC', 'Cơ bản', 10, 30, 2200000, gen_random_uuid(), 'CONSUMED', now() - interval '5 days', now() - interval '5 days' + interval '15 minutes', now() - interval '5 days'),
         ($3, $9, $12, 'ADVANCED', 'Nâng cao', 30, 90, 5000000, gen_random_uuid(), 'CONSUMED', now() - interval '10 days', now() - interval '10 days' + interval '15 minutes', now() - interval '10 days'),
         ($4, $9, $12, 'BASIC', 'Cơ bản', 10, 30, 1950000, gen_random_uuid(), 'CONSUMED', now() - interval '5 days', now() - interval '5 days' + interval '15 minutes', now() - interval '5 days'),
         ($5, $10, $12, 'BASIC', 'Cơ bản', 10, 30, 2000000, gen_random_uuid(), 'CONSUMED', now() - interval '4 days', now() - interval '4 days' + interval '15 minutes', now() - interval '4 days'),
         ($6, $11, $13, 'STANDARD', 'Tiêu chuẩn', 20, 60, 4000000, gen_random_uuid(), 'CONSUMED', now() - interval '6 days', now() - interval '6 days' + interval '15 minutes', now() - interval '6 days'),
         ($7, $11, $13, 'BASIC', 'Cơ bản', 10, 30, 2100000, gen_random_uuid(), 'CONSUMED', now() - interval '2 days', now() - interval '2 days' + interval '15 minutes', now() - interval '2 days')`,
        [
          hM1Active, hM1Queued, hM2Active, hM2Queued, hM3Active, hM4Active, hM4Queued,
          m1Id, m2Id, m3Id, m4Id, coachAId, coachEId,
        ],
      );

      await database.query(
        `INSERT INTO coach_entitlements
         (id, hold_id, original_hold_id, relationship_id, member_id, coach_id,
          plan_code, plan_name, snapshot_price, status, total_sessions, remaining_sessions,
          duration_days, starts_on, original_ends_on, ends_on)
         VALUES
         ($1, $8, $8, $15, $19, $23, 'STANDARD', 'Tiêu chuẩn', 4000000, 'ACTIVE', 20, 12, 60, $25::date - 10, $25::date + 49, $25::date + 49),
         ($2, $9, $9, $15, $19, $23, 'BASIC', 'Cơ bản', 2200000, 'QUEUED', 10, 10, 30, NULL, NULL, NULL),
         ($3, $10, $10, $16, $20, $23, 'ADVANCED', 'Nâng cao', 5000000, 'ACTIVE', 30, 11, 90, $25::date - 10, $25::date + 79, $25::date + 79),
         ($4, $11, $11, $16, $20, $23, 'BASIC', 'Cơ bản', 1950000, 'QUEUED', 10, 10, 30, NULL, NULL, NULL),
         ($5, $12, $12, $17, $21, $23, 'BASIC', 'Cơ bản', 2000000, 'ACTIVE', 10, 8, 30, $25::date - 4, $25::date + 25, $25::date + 25),
         ($6, $13, $13, $18, $22, $24, 'STANDARD', 'Tiêu chuẩn', 4000000, 'ACTIVE', 20, 14, 60, $25::date - 6, $25::date + 53, $25::date + 53),
         ($7, $14, $14, $18, $22, $24, 'BASIC', 'Cơ bản', 2100000, 'QUEUED', 10, 10, 30, NULL, NULL, NULL)`,
        [
          entM1Active, entM1Queued, entM2Active, entM2Queued, entM3Active, entM4Active, entM4Queued,
          hM1Active, hM1Queued, hM2Active, hM2Queued, hM3Active, hM4Active, hM4Queued,
          relM1Id, relM2Id, relM3Id, relM4Id,
          m1Id, m2Id, m3Id, m4Id,
          coachAId, coachEId, todayVn,
        ],
      );

      // Change catalog prices AFTER purchase to prove transfer & refund estimation preserve snapshot prices!
      await database.query(`UPDATE coach_package_plans SET price = 2500000 WHERE code = 'BASIC'`);
      await database.query(`UPDATE coach_package_plans SET price = 4500000 WHERE code = 'STANDARD'`);

      // Training plans, nutrition guides, and chat conversation for M1 (Coach A) and M4 (Coach E)
      const planM1Id = randomUUID();
      const guideM1Id = randomUUID();
      const planM4Id = randomUUID();
      const guideM4Id = randomUUID();
      const convM1AId = randomUUID();
      const convM4EId = randomUUID();

      await database.query(
        `INSERT INTO training_plans (id, relationship_id, member_id, coach_id, title, goal, status, version, published_at)
         VALUES ($1, $3, $5, $7, 'SECRET_PLAN_M1_T13', 'Giáo án cũ của HLV An', 'ACTIVE', 1, now()),
                ($2, $4, $6, $8, 'SECRET_PLAN_M4_T13', 'Giáo án cũ của HLV Em', 'ACTIVE', 1, now())`,
        [planM1Id, planM4Id, relM1Id, relM4Id, m1Id, m4Id, coachAId, coachEId],
      );
      await database.query(
        `INSERT INTO nutrition_guides (id, relationship_id, member_id, coach_id, title, content, status, version, published_at)
         VALUES ($1, $3, $5, $7, 'SECRET_GUIDE_M1_T13', 'SECRET_GUIDE_BODY_M1', 'ACTIVE', 1, now()),
                ($2, $4, $6, $8, 'SECRET_GUIDE_M4_T13', 'SECRET_GUIDE_BODY_M4', 'ACTIVE', 1, now())`,
        [guideM1Id, guideM4Id, relM1Id, relM4Id, m1Id, m4Id, coachAId, coachEId],
      );
      await database.query(
        `INSERT INTO conversations (id, relationship_id, member_id, coach_id)
         VALUES ($1, $3, $5, $7), ($2, $4, $6, $8)`,
        [convM1AId, convM4EId, relM1Id, relM4Id, m1Id, m4Id, coachAId, coachEId],
      );
      await database.query(
        `INSERT INTO conversation_participants (conversation_id, user_id)
         VALUES ($1, $3), ($1, $5), ($2, $4), ($2, $6)`,
        [convM1AId, convM4EId, m1Id, m4Id, coachAId, coachEId],
      );
      await database.query(
        `INSERT INTO messages (id, conversation_id, sender_id, client_message_id, message_type, content)
         VALUES ($1, $2, $3, $4, 'TEXT', 'SECRET_CHAT_MSG_T13')`,
        [randomUUID(), convM1AId, m1Id, randomUUID()],
      );

      // Future BOOKED bookings for M4 (2 bookings on Coach E — will be cancelled without charging on proactive transfer!)
      const bM4a = randomUUID();
      const bM4b = randomUUID();
      await database.query(
        `INSERT INTO coach_bookings (id, entitlement_id, member_id, coach_id, starts_at, ends_at, status)
         VALUES ($1, $3, $4, $5, statement_timestamp() + interval '3 days', statement_timestamp() + interval '3 days 90 minutes', 'BOOKED'),
                ($2, $3, $4, $5, statement_timestamp() + interval '5 days', statement_timestamp() + interval '5 days 90 minutes', 'BOOKED')`,
        [bM4a, bM4b, entM4Active, m4Id, coachEId],
      );
      // Open early-termination request on M4 (must be cancelled on transfer)
      const termM4Id = randomUUID();
      await database.query(
        `INSERT INTO coach_termination_requests
         (id, relationship_id, coach_id, reason, status,
          requested_by_user_id, requested_by_role, counterparty_user_id, response_deadline_at)
         VALUES ($1, $2, $3, 'Muốn đổi HLV', 'PENDING_COUNTERPARTY',
                 $4, 'MEMBER', $3, statement_timestamp() + interval '72 hours')`,
        [termM4Id, relM4Id, coachEId, m4Id],
      );

      // Block Coach F's slots across M1's QUEUED late window [today + 49 + 3 + 8 .. +29] = [today + 60 .. today + 89]
      // so M1's ACTIVE package fits Coach F alone, but ACTIVE + QUEUED overflows!
      await database.query(
        `INSERT INTO coach_slot_blocks (coach_id, starts_at, reason)
         SELECT $1,
                ((d.day + make_interval(mins => s.start_minute)) AT TIME ZONE 'Asia/Ho_Chi_Minh'),
                'Chặn lịch dài ngày trong cửa sổ gói chờ'
         FROM generate_series($2::date + 60, $2::date + 89, interval '1 day') AS d(day)
         JOIN coach_weekly_slots s ON s.coach_id = $1 AND s.weekday = EXTRACT(ISODOW FROM d.day)
         ON CONFLICT DO NOTHING`,
        [coachFId, todayVn],
      );

      // =====================================================================
      // 1. Role guards & rejection when Member is NOT COACH_LOCKED
      // =====================================================================
      assert.equal((await call(base, '/admin/coach-incidents', m1Token)).status, 403);
      assert.equal((await call(base, '/admin/coach-incidents', coachAToken)).status, 403);
      assert.equal((await call(base, '/relationships/me/coach-lock-choice', coachAToken, 'POST', { choice: 'WAIT' })).status, 403);
      assert.equal((await call(base, '/relationships/me/coach-lock-choice', adminToken, 'POST', { choice: 'WAIT' })).status, 403);

      // M1 is still ACTIVE (Coach A not locked yet) -> 409 NO_OPEN_COACH_LOCK_INCIDENT
      const notLockedChoice = await call(base, '/relationships/me/coach-lock-choice', m1Token, 'POST', {
        choice: 'REFUND', note: 'Thử gửi khi chưa bị khóa Coach',
      });
      assert.equal(notLockedChoice.status, 409);
      assert.equal(notLockedChoice.body.error.code, 'NO_OPEN_COACH_LOCK_INCIDENT');

      // =====================================================================
      // 2. Lock Coach A -> opens 3 incidents (M1, M2, M3), then simulate 3 VN days passing + M2 Gym expiring
      // =====================================================================
      const lockCoachA = await call(base, `/admin/users/${coachAId}/status`, adminToken, 'PATCH', {
        status: 'DISABLED', reason: 'HLV An nghỉ đột xuất 2 tuần',
      });
      assert.equal(lockCoachA.status, 200, JSON.stringify(lockCoachA.body));
      assert.equal(lockCoachA.body.data.effects.incidentsCreated.length, 3);
      const m1IncidentId = lockCoachA.body.data.effects.incidentsCreated.find((i) => i.memberId === m1Id).incidentId;
      const m2IncidentId = lockCoachA.body.data.effects.incidentsCreated.find((i) => i.memberId === m2Id).incidentId;
      const m3IncidentId = lockCoachA.body.data.effects.incidentsCreated.find((i) => i.memberId === m3Id).incidentId;

      // Simulate 3 VN midnights passing while Coach A is locked, and M2's Gym expiring
      await database.query(
        `UPDATE coach_lock_incidents
         SET frozen_started_at = statement_timestamp() - interval '3 days'
         WHERE id IN ($1, $2)`,
        [m1IncidentId, m2IncidentId],
      );
      await database.query(
        `UPDATE coach_entitlements
         SET frozen_at = statement_timestamp() - interval '3 days'
         WHERE id IN ($1, $2)`,
        [entM1Active, entM2Active],
      );
      await database.query(
        `UPDATE member_memberships SET end_date = $2::date - 1 WHERE member_id = $1`,
        [m2Id, todayVn],
      );
      const reconcilePool = new pg.Pool({ connectionString: databaseUrl });
      try {
        await reconcileMembershipLifecycles(reconcilePool);
      } finally {
        await reconcilePool.end();
      }

      // =====================================================================
      // 3. Member WAIT / REFUND choice on OPEN COACH_LOCKED incidents
      // =====================================================================
      assert.equal((await call(base, '/relationships/me/coach-lock-choice', m1Token, 'POST', {
        choice: 'INVALID',
      })).status, 422);

      const m1RefundChoice = await call(base, '/relationships/me/coach-lock-choice', m1Token, 'POST', {
        choice: 'REFUND', note: 'Muốn xem xét hoàn tiền',
      });
      assert.equal(m1RefundChoice.status, 200, JSON.stringify(m1RefundChoice.body));
      assert.equal(m1RefundChoice.body.data.memberChoice, 'REFUND');
      assert.equal(m1RefundChoice.body.data.memberChoiceNote, 'Muốn xem xét hoàn tiền');
      assert.ok(m1RefundChoice.body.data.memberChoiceAt);

      // M1 switches back to WAIT while incident is still OPEN
      const m1WaitChoice = await call(base, '/relationships/me/coach-lock-choice', m1Token, 'POST', {
        choice: 'WAIT', note: 'Đổi ý chờ chuyển sang Coach mới',
      });
      assert.equal(m1WaitChoice.status, 200);
      assert.equal(m1WaitChoice.body.data.memberChoice, 'WAIT');
      assert.equal(m1WaitChoice.body.data.memberChoiceNote, 'Đổi ý chờ chuyển sang Coach mới');

      // M2 selects REFUND
      const m2RefundChoice = await call(base, '/relationships/me/coach-lock-choice', m2Token, 'POST', {
        choice: 'REFUND', note: 'Muốn nhận hoàn tiền mô phỏng',
      });
      assert.equal(m2RefundChoice.status, 200);
      assert.equal(m2RefundChoice.body.data.memberChoice, 'REFUND');

      // =====================================================================
      // 4. GET /admin/coach-incidents queue, filtering, VN frozenDaysCurrent, D3+D2 refund math, privacy allowlist
      // =====================================================================
      const queueAll = await call(
        base,
        `/admin/coach-incidents?status=OPEN&coachId=${coachAId}&page=1&pageSize=10`,
        adminToken,
      );
      assert.equal(queueAll.status, 200, JSON.stringify(queueAll.body));
      assert.equal(queueAll.body.pagination.totalItems, 3);

      // REFUND choice surfaced first by sorting
      assert.equal(queueAll.body.data[0].id, m2IncidentId);

      const m1Queue = queueAll.body.data.find((x) => x.id === m1IncidentId);
      assert.equal(m1Queue.memberName, 'Trần Thu Hà');
      assert.equal(m1Queue.coachName, 'HLV An Khóa');
      assert.equal(m1Queue.lockedByName, 'Quản trị T13');
      assert.equal(m1Queue.frozenDaysCurrent, 3);
      assert.equal(m1Queue.memberChoice, 'WAIT');
      assert.equal(m1Queue.memberGymMembershipStatus, 'ACTIVE');
      assert.equal(m1Queue.activeEntitlement.snapshotPrice, 4000000);
      assert.equal(m1Queue.activeEntitlement.remainingSessions, 12);
      assert.equal(m1Queue.queuedEntitlement.snapshotPrice, 2200000);
      // D3 + D2: floor(4,000,000 * 12 / 20 / 1000) * 1000 = 2,400,000 + 2,200,000 = 4,600,000
      assert.equal(m1Queue.estimatedActiveRefund, 2400000);
      assert.equal(m1Queue.estimatedQueuedRefund, 2200000);
      assert.equal(m1Queue.estimatedTotalRefund, 4600000);

      const m2Queue = queueAll.body.data.find((x) => x.id === m2IncidentId);
      assert.equal(m2Queue.memberName, 'Lê Quang Huy');
      assert.equal(m2Queue.frozenDaysCurrent, 3);
      assert.equal(m2Queue.memberChoice, 'REFUND');
      assert.equal(m2Queue.memberGymMembershipStatus, 'EXPIRED');
      // D3 + D2 Walkthrough 3 math: floor(5,000,000 * 11 / 30 / 1000) * 1000 = 1,833,000 + 1,950,000 = 3,783,000
      assert.equal(m2Queue.estimatedActiveRefund, 1833000);
      assert.equal(m2Queue.estimatedQueuedRefund, 1950000);
      assert.equal(m2Queue.estimatedTotalRefund, 3783000);

      // Filter by memberChoice=REFUND & search
      const queueFiltered = await call(
        base,
        `/admin/coach-incidents?status=OPEN&memberChoice=REFUND&search=L%C3%AA%20Quang%20Huy`,
        adminToken,
      );
      assert.equal(queueFiltered.status, 200);
      assert.equal(queueFiltered.body.pagination.totalItems, 1);
      assert.equal(queueFiltered.body.data[0].id, m2IncidentId);

      // STRICT PRIVACY ALLOWLIST CHECK on queue
      const queueJson = JSON.stringify(queueAll.body);
      for (const forbidden of [
        'healthNotes', 'injuryNotes', 'heightCm', 'weightKg', 'bodyFatPercent',
        'fitnessGoal', 'dietaryPreferences', 'healthDeclarationCompletedAt',
        'SECRET_GOAL_T13', 'SECRET_HEALTH_T13', 'SECRET_INJURY_T13', 'SECRET_DIET_T13',
        'SECRET_PLAN_M1_T13', 'SECRET_GUIDE_M1_T13', 'SECRET_GUIDE_BODY_M1', 'SECRET_CHAT_MSG_T13',
      ]) {
        assert.equal(queueJson.includes(forbidden), false, `Incident queue leaked ${forbidden}`);
      }

      // =====================================================================
      // 5. GET /admin/coach-incidents/:incidentId/eligible-coaches
      //    Verify COACH_FULL (7 rels + 1 live 15-min hold = 8), SCHEDULE_REQUIRED,
      //    and CAPACITY_UNAVAILABLE (ACTIVE fits alone, ACTIVE+QUEUED overflows!)
      // =====================================================================
      // Sanity-check: Coach F DOES fit M1's ACTIVE proposal alone!
      const checkClient = await database.connect();
      try {
        const activeOnlyFitsF = await hasCoachCapacity(checkClient, coachFId, {
          memberId: m1Id,
          from: todayVn,
          through: (await checkClient.query(`SELECT ($1::date + 52)::text AS d`, [todayVn])).rows[0].d,
          remaining: 12,
        });
        assert.equal(activeOnlyFitsF, true, 'Coach F must fit ACTIVE alone so test proves D2 ACTIVE+QUEUED rejection');
      } finally {
        checkClient.release();
      }

      const eligibleRes = await call(
        base,
        `/admin/coach-incidents/${m1IncidentId}/eligible-coaches`,
        adminToken,
      );
      assert.equal(eligibleRes.status, 200, JSON.stringify(eligibleRes.body));
      const byCoachId = new Map(eligibleRes.body.data.map((c) => [c.coachId, c]));

      // Old locked Coach A is excluded (not active and is old coach)
      assert.equal(byCoachId.has(coachAId), false);

      const evalB = byCoachId.get(coachBId);
      assert.equal(evalB.usedSlots, 0);
      assert.equal(evalB.memberLimit, 8);
      assert.equal(evalB.seatAvailable, true);
      assert.equal(evalB.scheduleConfigured, true);
      assert.equal(evalB.capacityEligibleForActiveAndQueued, true);
      assert.equal(evalB.eligible, true);
      assert.equal(evalB.ineligibleReason, null);

      const evalC = byCoachId.get(coachCId);
      assert.equal(evalC.usedSlots, 8); // 7 relationships + 1 live 15-min hold!
      assert.equal(evalC.memberLimit, 8);
      assert.equal(evalC.seatAvailable, false);
      assert.equal(evalC.scheduleConfigured, true);
      assert.equal(evalC.eligible, false);
      assert.equal(evalC.ineligibleReason, 'COACH_FULL');

      const evalD = byCoachId.get(coachDId);
      assert.equal(evalD.seatAvailable, true);
      assert.equal(evalD.scheduleConfigured, false);
      assert.equal(evalD.capacityEligibleForActiveAndQueued, false);
      assert.equal(evalD.eligible, false);
      assert.equal(evalD.ineligibleReason, 'SCHEDULE_REQUIRED');

      const evalF = byCoachId.get(coachFId);
      assert.equal(evalF.seatAvailable, true);
      assert.equal(evalF.scheduleConfigured, true);
      assert.equal(evalF.capacityEligibleForActiveAndQueued, false);
      assert.equal(evalF.eligible, false);
      assert.equal(evalF.ineligibleReason, 'CAPACITY_UNAVAILABLE');
      assert.deepEqual(evalF.checkedEntitlements, ['ACTIVE', 'QUEUED']);

      // =====================================================================
      // 6. Transfer validation & 409 rejection guards (full rollback verified)
      // =====================================================================
      // Missing Idempotency-Key on incident transfer -> 422
      assert.equal((await call(
        base,
        `/admin/coach-incidents/${m1IncidentId}/transfer`,
        adminToken,
        'POST',
        { newCoachId: coachBId, reason: 'Thiếu header idempotency' },
      )).status, 422);

      // Coach C (COACH_FULL due to 7 rels + 1 live hold) -> 409 COACH_FULL
      const transferFull = await call(
        base,
        `/admin/coach-incidents/${m1IncidentId}/transfer`,
        adminToken,
        'POST',
        { newCoachId: coachCId, reason: 'Thử chuyển sang Coach đầy suất' },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(transferFull.status, 409);
      assert.equal(transferFull.body.error.code, 'COACH_FULL');

      // Coach D (unconfigured schedule) -> 409 SCHEDULE_REQUIRED
      const transferNoSched = await call(
        base,
        `/admin/coach-incidents/${m1IncidentId}/transfer`,
        adminToken,
        'POST',
        { newCoachId: coachDId, reason: 'Thử chuyển sang Coach chưa cấu hình lịch' },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(transferNoSched.status, 409);
      assert.equal(transferNoSched.body.error.code, 'SCHEDULE_REQUIRED');

      // Coach F (ACTIVE fits alone, ACTIVE+QUEUED overflows) -> 409 CAPACITY_UNAVAILABLE + checkedEntitlements
      const transferOverflow = await call(
        base,
        `/admin/coach-incidents/${m1IncidentId}/transfer`,
        adminToken,
        'POST',
        { newCoachId: coachFId, reason: 'Thử chuyển sang Coach thiếu công suất gói chờ' },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(transferOverflow.status, 409);
      assert.equal(transferOverflow.body.error.code, 'CAPACITY_UNAVAILABLE');
      assert.deepEqual(transferOverflow.body.error.details.checkedEntitlements, ['ACTIVE', 'QUEUED']);

      // Verify full rollback: M1 incident still OPEN, M1 still on Coach A!
      assert.equal(
        (await database.query('SELECT status FROM coach_lock_incidents WHERE id = $1', [m1IncidentId])).rows[0].status,
        'OPEN',
      );
      assert.equal(
        (await database.query('SELECT status FROM coach_relationships WHERE id = $1', [relM1Id])).rows[0].status,
        'PAUSED',
      );

      // =====================================================================
      // 7. Full D2 Incident Transfer for M1 -> Coach B + Idempotency Retry & Conflict
      // =====================================================================
      const m1TransferKey = randomUUID();
      const m1TransferPayload = {
        newCoachId: coachBId,
        reason: 'Chuyển sang HLV Bình còn suất và đủ công suất cho cả gói đang dùng lẫn gói chờ',
      };
      const m1Transfer = await call(
        base,
        `/admin/coach-incidents/${m1IncidentId}/transfer`,
        adminToken,
        'POST',
        m1TransferPayload,
        { 'idempotency-key': m1TransferKey },
      );
      assert.equal(m1Transfer.status, 201, JSON.stringify(m1Transfer.body));
      const t1 = m1Transfer.body.data;
      assert.ok(t1.transferId);
      assert.equal(t1.oldRelationshipId, relM1Id);
      assert.ok(t1.newRelationshipId && t1.newRelationshipId !== relM1Id);
      assert.equal(t1.newRelationshipStatus, 'ACTIVE');
      assert.equal(t1.newPauseReason, null);
      assert.equal(t1.frozenDaysAdded, 3);
      assert.equal(t1.incidentStatus, 'RESOLVED_TRANSFERRED');
      assert.equal(t1.transferredEntitlements.length, 2);

      const newM1ActiveSummary = t1.transferredEntitlements.find((e) => e.kind === 'ACTIVE');
      const newM1QueuedSummary = t1.transferredEntitlements.find((e) => e.kind === 'QUEUED');
      assert.equal(newM1ActiveSummary.oldId, entM1Active);
      assert.equal(newM1ActiveSummary.remainingSessions, 12);
      assert.equal(newM1ActiveSummary.totalSessions, 20);
      assert.equal(newM1ActiveSummary.snapshotPrice, 4000000);
      const expectedM1NewEndsOn = (await database.query(`SELECT ($1::date + 49 + 3)::text AS d`, [todayVn])).rows[0].d;
      assert.equal(newM1ActiveSummary.endsOn, expectedM1NewEndsOn);

      assert.equal(newM1QueuedSummary.oldId, entM1Queued);
      assert.equal(newM1QueuedSummary.remainingSessions, 10);
      assert.equal(newM1QueuedSummary.totalSessions, 10);
      assert.equal(newM1QueuedSummary.snapshotPrice, 2200000);
      assert.equal(newM1QueuedSummary.endsOn, null);

      // Verify DB rows of old & new entitlements
      const oldM1Ents = (await database.query(
        `SELECT id, status, close_reason, frozen_at FROM coach_entitlements WHERE id IN ($1, $2)`,
        [entM1Active, entM1Queued],
      )).rows;
      assert.ok(oldM1Ents.every((e) => e.status === 'ENDED' && e.close_reason === 'TRANSFERRED' && e.frozen_at === null));

      const newM1ActiveRow = (await database.query(
        `SELECT hold_id, original_hold_id, source_entitlement_id, coach_id,
                plan_code, plan_name, snapshot_price, total_sessions, remaining_sessions,
                frozen_at, frozen_days_total, grace_days_added, ends_on::text AS ends_on
         FROM coach_entitlements WHERE id = $1`,
        [newM1ActiveSummary.newId],
      )).rows[0];
      assert.equal(newM1ActiveRow.hold_id, null);
      assert.equal(newM1ActiveRow.original_hold_id, hM1Active);
      assert.equal(newM1ActiveRow.source_entitlement_id, entM1Active);
      assert.equal(newM1ActiveRow.coach_id, coachBId);
      assert.equal(newM1ActiveRow.plan_code, 'STANDARD');
      assert.equal(Number(newM1ActiveRow.snapshot_price), 4000000);
      assert.equal(newM1ActiveRow.remaining_sessions, 12);
      assert.equal(newM1ActiveRow.frozen_at, null);
      assert.equal(newM1ActiveRow.frozen_days_total, 3);
      assert.equal(newM1ActiveRow.grace_days_added, 0);
      assert.equal(newM1ActiveRow.ends_on, expectedM1NewEndsOn);

      const newM1QueuedRow = (await database.query(
        `SELECT hold_id, original_hold_id, source_entitlement_id, coach_id,
                plan_code, snapshot_price, total_sessions, remaining_sessions,
                starts_on, original_ends_on, ends_on, frozen_days_total
         FROM coach_entitlements WHERE id = $1`,
        [newM1QueuedSummary.newId],
      )).rows[0];
      assert.equal(newM1QueuedRow.hold_id, null);
      assert.equal(newM1QueuedRow.original_hold_id, hM1Queued);
      assert.equal(newM1QueuedRow.source_entitlement_id, entM1Queued);
      assert.equal(newM1QueuedRow.coach_id, coachBId);
      assert.equal(Number(newM1QueuedRow.snapshot_price), 2200000);
      assert.equal(newM1QueuedRow.starts_on, null);
      assert.equal(newM1QueuedRow.ends_on, null);
      assert.equal(newM1QueuedRow.frozen_days_total, 0);

      // Old training plan & nutrition guide archived read-only; Coach B does NOT inherit them
      assert.equal((await database.query('SELECT status FROM training_plans WHERE id = $1', [planM1Id])).rows[0].status, 'ARCHIVED');
      assert.equal((await database.query('SELECT status FROM nutrition_guides WHERE id = $1', [guideM1Id])).rows[0].status, 'ARCHIVED');
      assert.equal(
        (await database.query('SELECT count(*)::int AS c FROM training_plans WHERE coach_id = $1 AND member_id = $2', [coachBId, m1Id])).rows[0].c,
        0,
      );
      assert.equal(
        (await database.query('SELECT count(*)::int AS c FROM nutrition_guides WHERE coach_id = $1 AND member_id = $2', [coachBId, m1Id])).rows[0].c,
        0,
      );

      // Chat NOT locked & NOT force-created for M1 <-> Coach B; M1 <-> Coach A history remains readable
      assert.equal(
        (await database.query(
          `SELECT count(*)::int AS c FROM conversations WHERE member_id = $1 AND coach_id = $2`,
          [m1Id, coachBId],
        )).rows[0].c,
        0,
      );
      const oldChatMessages = await call(base, `/conversations/${relM1Id}/messages`, m1Token);
      assert.equal(oldChatMessages.status, 200);
      assert.equal(oldChatMessages.body.data.length, 1);

      // Notifications: COACH_TRANSFERRED sent to M1, Coach A, Coach B; NO bogus PACKAGE_ENDED or PACKAGE_ACTIVE/QUEUED on transfer!
      const transferNotifs = await database.query(
        `SELECT user_id FROM coach_notifications WHERE kind = 'COACH_TRANSFERRED' AND subject_id = $1`,
        [t1.newRelationshipId],
      );
      assert.equal(transferNotifs.rowCount, 3);
      const bogusPackageEnded = await database.query(
        `SELECT 1 FROM coach_notifications WHERE user_id = $1 AND kind = 'PACKAGE_ENDED' AND subject_id IN ($2, $3)`,
        [m1Id, entM1Active, entM1Queued],
      );
      assert.equal(bogusPackageEnded.rowCount, 0);
      const bogusClonedInsert = await database.query(
        `SELECT 1 FROM coach_notifications WHERE user_id = $1 AND kind IN ('PACKAGE_ACTIVE', 'PACKAGE_QUEUED') AND subject_id IN ($2, $3)`,
        [m1Id, newM1ActiveSummary.newId, newM1QueuedSummary.newId],
      );
      assert.equal(bogusClonedInsert.rowCount, 0);

      // Incident updated to RESOLVED_TRANSFERRED with exact audit fields
      const m1IncAfter = (await database.query(
        `SELECT status, frozen_days_applied, frozen_ended_at, transfer_history_id, resolved_by, resolved_at
         FROM coach_lock_incidents WHERE id = $1`,
        [m1IncidentId],
      )).rows[0];
      assert.equal(m1IncAfter.status, 'RESOLVED_TRANSFERRED');
      assert.equal(m1IncAfter.frozen_days_applied, 3);
      assert.ok(m1IncAfter.frozen_ended_at);
      assert.equal(m1IncAfter.transfer_history_id, t1.transferId);
      assert.equal(m1IncAfter.resolved_by, adminId);
      assert.ok(m1IncAfter.resolved_at);

      // Member can no longer submit coach-lock-choice after transfer
      assert.equal(
        (await call(base, '/relationships/me/coach-lock-choice', m1Token, 'POST', { choice: 'REFUND' })).status,
        409,
      );

      // Idempotency retry with SAME key + SAME payload -> 200 OK with exact same transferId & NO double freeze!
      const m1TransferRetry = await call(
        base,
        `/admin/coach-incidents/${m1IncidentId}/transfer`,
        adminToken,
        'POST',
        m1TransferPayload,
        { 'idempotency-key': m1TransferKey },
      );
      assert.equal(m1TransferRetry.status, 200, JSON.stringify(m1TransferRetry.body));
      assert.equal(m1TransferRetry.body.data.transferId, t1.transferId);
      assert.equal(m1TransferRetry.body.data.newRelationshipId, t1.newRelationshipId);
      assert.equal(m1TransferRetry.body.data.frozenDaysAdded, 3);
      assert.equal(
        (await database.query('SELECT frozen_days_total FROM coach_entitlements WHERE id = $1', [newM1ActiveSummary.newId])).rows[0].frozen_days_total,
        3,
      );

      // Idempotency conflict: SAME key + DIFFERENT payload -> 409 IDEMPOTENCY_KEY_CONFLICT
      const m1TransferConflict = await call(
        base,
        `/admin/coach-incidents/${m1IncidentId}/transfer`,
        adminToken,
        'POST',
        { newCoachId: coachBId, reason: 'Lý do khác với lần gửi trước' },
        { 'idempotency-key': m1TransferKey },
      );
      assert.equal(m1TransferConflict.status, 409);
      assert.equal(m1TransferConflict.body.error.code, 'IDEMPOTENCY_KEY_CONFLICT');

      // Different key on already-resolved incident -> 409 INCIDENT_ALREADY_RESOLVED
      const m1TransferAgain = await call(
        base,
        `/admin/coach-incidents/${m1IncidentId}/transfer`,
        adminToken,
        'POST',
        m1TransferPayload,
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(m1TransferAgain.status, 409);
      assert.equal(m1TransferAgain.body.error.code, 'INCIDENT_ALREADY_RESOLVED');

      // =====================================================================
      // 8. Gym-expired Member M2 transferred to Coach B -> PAUSED (MEMBERSHIP_EXPIRED)
      // =====================================================================
      const m2Transfer = await call(
        base,
        `/admin/coach-incidents/${m2IncidentId}/transfer`,
        adminToken,
        'POST',
        { newCoachId: coachBId, reason: 'Chuyển M2 sang Coach B dù gói Gym đã hết hạn' },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(m2Transfer.status, 201, JSON.stringify(m2Transfer.body));
      assert.equal(m2Transfer.body.data.newRelationshipStatus, 'PAUSED');
      assert.equal(m2Transfer.body.data.newPauseReason, 'MEMBERSHIP_EXPIRED');
      assert.equal(m2Transfer.body.data.frozenDaysAdded, 3);
      assert.equal(m2Transfer.body.data.transferredEntitlements.length, 2);

      // Verify M2's relationship is PAUSED (MEMBERSHIP_EXPIRED) and Coach B sees NULL health profile while paused!
      const m2OnCoachB = await call(base, `/coach/members/${m2Id}`, coachBToken);
      assert.equal(m2OnCoachB.status, 200);
      assert.equal(m2OnCoachB.body.data.status, 'PAUSED');
      assert.equal(m2OnCoachB.body.data.pauseReason, 'MEMBERSHIP_EXPIRED');
      assert.equal(m2OnCoachB.body.data.member.healthNotes, null);

      // =====================================================================
      // 9. Proactive transfer via POST /admin/coach-transfers (M4: Coach E -> Coach B)
      //    Cancels 2 future bookings WITHOUT charging, archives plans, cancels open termination,
      //    preserves ACTIVE + QUEUED, leaves chat untouched, supports Idempotency-Key!
      // =====================================================================
      const m4Key = randomUUID();
      const m4Transfer = await call(
        base,
        '/admin/coach-transfers',
        adminToken,
        'POST',
        { memberId: m4Id, newCoachId: coachBId, reason: 'Chuyển chủ động theo nguyện vọng lịch tập' },
        { 'idempotency-key': m4Key },
      );
      assert.equal(m4Transfer.status, 201, JSON.stringify(m4Transfer.body));
      const t4 = m4Transfer.body.data;
      assert.equal(t4.oldRelationshipId, relM4Id);
      assert.equal(t4.memberId, m4Id);
      assert.equal(t4.oldCoachId, coachEId);
      assert.equal(t4.newCoachId, coachBId);
      assert.equal(t4.newRelationshipStatus, 'ACTIVE');
      assert.equal(t4.frozenDaysAdded, 0);
      assert.equal(t4.cancelledOldBookingsCount, 2);
      assert.equal(t4.transferredEntitlements.length, 2);
      assert.equal(t4.transferredEntitlements.find((e) => e.kind === 'ACTIVE').remainingSessions, 14);
      assert.equal(t4.transferredEntitlements.find((e) => e.kind === 'QUEUED').remainingSessions, 10);

      // Both future bookings cancelled with charged_at = NULL
      const bM4After = (await database.query(
        `SELECT status, charged_at FROM coach_bookings WHERE id IN ($1, $2)`,
        [bM4a, bM4b],
      )).rows;
      assert.equal(bM4After.length, 2);
      assert.ok(bM4After.every((b) => b.status === 'CANCELLED' && b.charged_at === null));
      assert.equal((await database.query('SELECT status FROM training_plans WHERE id = $1', [planM4Id])).rows[0].status, 'ARCHIVED');
      assert.equal((await database.query('SELECT status FROM nutrition_guides WHERE id = $1', [guideM4Id])).rows[0].status, 'ARCHIVED');
      assert.equal((await database.query('SELECT status FROM coach_termination_requests WHERE id = $1', [termM4Id])).rows[0].status, 'CANCELLED');
      assert.equal(
        (await database.query(`SELECT count(*)::int AS c FROM conversations WHERE member_id = $1 AND coach_id = $2`, [m4Id, coachBId])).rows[0].c,
        0,
      );
      // Old conversation with active Coach E STILL works!
      assert.equal(
        (await call(base, `/conversations/${relM4Id}/messages`, m4Token, 'POST', {
          messageType: 'TEXT', clientMessageId: randomUUID(), content: 'Cảm ơn HLV Em đã đồng hành!',
        })).status,
        201,
      );

      // Idempotency retry & conflict on /admin/coach-transfers
      const m4Retry = await call(
        base,
        '/admin/coach-transfers',
        adminToken,
        'POST',
        { memberId: m4Id, newCoachId: coachBId, reason: 'Chuyển chủ động theo nguyện vọng lịch tập' },
        { 'idempotency-key': m4Key },
      );
      assert.equal(m4Retry.status, 200);
      assert.equal(m4Retry.body.data.transferId, t4.transferId);

      const m4Conflict = await call(
        base,
        '/admin/coach-transfers',
        adminToken,
        'POST',
        { memberId: m4Id, newCoachId: coachBId, reason: 'Lý do khác' },
        { 'idempotency-key': m4Key },
      );
      assert.equal(m4Conflict.status, 409);
      assert.equal(m4Conflict.body.error.code, 'IDEMPOTENCY_KEY_CONFLICT');

      // =====================================================================
      // 10. Concurrency: Incident transfer (M3 -> Coach G) vs 15-min hold (M9 -> Coach G)
      //     contesting seat #8 simultaneously!
      // =====================================================================
      assert.equal(
        (await database.query('SELECT coach_occupied_seats($1) AS n', [coachGId])).rows[0].n,
        7,
      );

      const [raceTransfer, raceHold] = await Promise.all([
        call(
          base,
          `/admin/coach-incidents/${m3IncidentId}/transfer`,
          adminToken,
          'POST',
          { newCoachId: coachGId, reason: 'Cạnh tranh suất #8 với hold 15 phút' },
          { 'idempotency-key': randomUUID() },
        ),
        call(
          base,
          '/coach-payment-holds',
          m9Token,
          'POST',
          { coachId: coachGId, planCode: 'BASIC' },
          { 'idempotency-key': randomUUID() },
        ),
      ]);

      assert.deepEqual(
        [raceTransfer.status, raceHold.status].sort((a, b) => a - b),
        [201, 409],
        `Expected exactly one 201 and one 409 COACH_FULL, got transfer=${raceTransfer.status} (${JSON.stringify(raceTransfer.body)}) hold=${raceHold.status} (${JSON.stringify(raceHold.body)})`,
      );
      const loser = raceTransfer.status === 409 ? raceTransfer : raceHold;
      assert.equal(loser.body.error.code, 'COACH_FULL');
      assert.equal(
        (await database.query('SELECT coach_occupied_seats($1) AS n', [coachGId])).rows[0].n,
        8,
      );

      // Unlock Coach A afterward -> M1 and M2 (already transferred) MUST NOT be re-touched or re-added frozen days!
      const unlockCoachA = await call(base, `/admin/users/${coachAId}/status`, adminToken, 'PATCH', {
        status: 'ACTIVE',
      });
      assert.equal(unlockCoachA.status, 200);
      assert.equal(
        (await database.query('SELECT frozen_days_total FROM coach_entitlements WHERE id = $1', [newM1ActiveSummary.newId])).rows[0].frozen_days_total,
        3,
      );
    } finally {
      if (originalBasicPrice !== undefined) {
        await database.query(`UPDATE coach_package_plans SET price = $1 WHERE code = 'BASIC'`, [originalBasicPrice]).catch(() => {});
      }
      if (originalStandardPrice !== undefined) {
        await database.query(`UPDATE coach_package_plans SET price = $1 WHERE code = 'STANDARD'`, [originalStandardPrice]).catch(() => {});
      }
      if (originalAdvancedPrice !== undefined) {
        await database.query(`UPDATE coach_package_plans SET price = $1 WHERE code = 'ADVANCED'`, [originalAdvancedPrice]).catch(() => {});
      }
      await database.query('DELETE FROM coach_notifications WHERE user_id = ANY($1::uuid[])', [allUsers]);
      await database.query('DELETE FROM coach_lock_incidents WHERE member_id = ANY($1::uuid[])', [allMembers]);
      await database.query('DELETE FROM coach_termination_requests WHERE coach_id = ANY($1::uuid[])', [coachIds]);
      await database.query('DELETE FROM coach_transfer_history WHERE member_id = ANY($1::uuid[])', [allMembers]);
      await database.query('DELETE FROM coach_bookings WHERE member_id = ANY($1::uuid[])', [allMembers]);
      await database.query('DELETE FROM coach_entitlements WHERE member_id = ANY($1::uuid[])', [allMembers]);
      await database.query('DELETE FROM coach_payment_holds WHERE member_id = ANY($1::uuid[])', [allMembers]);
      await database.query('DELETE FROM coach_slot_blocks WHERE coach_id = ANY($1::uuid[])', [coachIds]);
      await database.query('DELETE FROM coach_weekly_slots WHERE coach_id = ANY($1::uuid[])', [coachIds]);
      await database.query('DELETE FROM training_plans WHERE member_id = ANY($1::uuid[])', [allMembers]);
      await database.query('DELETE FROM nutrition_guides WHERE member_id = ANY($1::uuid[])', [allMembers]);
      await database.query(
        `DELETE FROM messages WHERE conversation_id IN
         (SELECT id FROM conversations WHERE member_id = ANY($1::uuid[]))`,
        [allMembers],
      );
      await database.query(
        `DELETE FROM conversation_participants WHERE conversation_id IN
         (SELECT id FROM conversations WHERE member_id = ANY($1::uuid[]))`,
        [allMembers],
      );
      await database.query('DELETE FROM conversations WHERE member_id = ANY($1::uuid[])', [allMembers]);
      await database.query('DELETE FROM coach_relationships WHERE member_id = ANY($1::uuid[])', [allMembers]);
      await database.query('DELETE FROM member_memberships WHERE member_id = ANY($1::uuid[])', [allMembers]);
      await database.query('DELETE FROM payments WHERE member_id = ANY($1::uuid[])', [allMembers]);
      await database.query('DELETE FROM membership_plans WHERE id = $1', [planId]);
      await database.query('DELETE FROM admin_audit_logs WHERE admin_id = $1', [adminId]);
      await database.query('DELETE FROM coach_profiles WHERE user_id = ANY($1::uuid[])', [coachIds]);
      await database.query('DELETE FROM member_profiles WHERE user_id = ANY($1::uuid[])', [allMembers]);
      await database.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [allUsers]);
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });
