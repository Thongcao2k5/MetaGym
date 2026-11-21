import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const migrationsDir = path.resolve(__dirname, '../../database/migrations');

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'web-admin-t12-relationships-d5-secret-32-chars';

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

test('T12: D5 72h mutual early termination, dispute adjudication, relationships V2 privacy allowlist, legacy 410, and 0032 invariants',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const app = createApp({ database, jwtSecret: secret });
    const server = app.listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;

    const adminId = randomUUID();
    const coach1Id = randomUUID();
    const coach2Id = randomUUID();
    const m1Id = randomUUID(); // Mutual ACCEPT (ACTIVE + QUEUED + bookings + plan/guide + chat)
    const m2Id = randomUUID(); // WITHDRAW -> re-submit -> REJECT -> ADMIN_REJECTED -> re-submit -> REJECT -> ADMIN_APPROVED
    const m3Id = randomUUID(); // PAUSED (MEMBERSHIP_EXPIRED) + 72h timeout via respond 409 TERMINATION_DEADLINE_EXPIRED
    const m4Id = randomUUID(); // 72h timeout via GET /me & Admin direct inline escalation
    const m5Id = randomUUID(); // PAUSED (COACH_LOCKED) -> 409 USE_COACH_INCIDENT_FLOW + admin detail/privacy/transfer
    const memberIds = [m1Id, m2Id, m3Id, m4Id, m5Id];
    const coachIds = [coach1Id, coach2Id];
    const allUsers = [adminId, ...coachIds, ...memberIds];

    const planId = randomUUID();
    const rel1Id = randomUUID();
    const rel2Id = randomUUID();
    const rel3Id = randomUUID();
    const rel4Id = randomUUID();
    const rel5Id = randomUUID();
    const rel5OldId = randomUUID();
    const conv1Id = randomUUID();
    const conv2Id = randomUUID();

    const adminToken = token(adminId, 'ADMIN');
    const coach1Token = token(coach1Id, 'COACH');
    const coach2Token = token(coach2Id, 'COACH');
    const m1Token = token(m1Id, 'MEMBER');
    const m2Token = token(m2Id, 'MEMBER');
    const m3Token = token(m3Id, 'MEMBER');
    const m4Token = token(m4Id, 'MEMBER');
    const m5Token = token(m5Id, 'MEMBER');

    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Quản trị T12'),
                ($3, $4, 'hash', 'COACH', 'Huấn luyện viên Một'),
                ($5, $6, 'hash', 'COACH', 'Huấn luyện viên Hai'),
                ($7, $8, 'hash', 'MEMBER', 'Nguyễn Thị Mai'),
                ($9, $10, 'hash', 'MEMBER', 'Trần Quốc Bảo'),
                ($11, $12, 'hash', 'MEMBER', 'Lê Minh Châu'),
                ($13, $14, 'hash', 'MEMBER', 'Phạm Anh Dũng'),
                ($15, $16, 'hash', 'MEMBER', 'Hoàng Gia Huy')`,
        [
          adminId, `${adminId}@example.com`,
          coach1Id, `${coach1Id}@example.com`,
          coach2Id, `${coach2Id}@example.com`,
          m1Id, `mai-${m1Id}@example.com`,
          m2Id, `bao-${m2Id}@example.com`,
          m3Id, `chau-${m3Id}@example.com`,
          m4Id, `dung-${m4Id}@example.com`,
          m5Id, `huy-${m5Id}@example.com`,
        ],
      );
      for (const cid of coachIds) {
        await database.query('INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 8)', [cid]);
      }
      for (const mid of memberIds) {
        await database.query(
          `INSERT INTO member_profiles
           (user_id, height_cm, weight_kg, body_fat_percent, fitness_goal,
            health_notes, injury_notes, dietary_preferences, health_declaration_completed_at)
           VALUES ($1, 172, 66, 17.5, 'SECRET_GOAL_T12',
                   'SECRET_HEALTH_T12', 'SECRET_INJURY_T12', 'SECRET_DIET_T12', now())`,
          [mid],
        );
      }

      await database.query(
        `INSERT INTO membership_plans (id, name, price, duration_days, status, created_by)
         VALUES ($1, 'Gym T12 30d', 500000, 30, 'ACTIVE', $2)`,
        [planId, adminId],
      );
      const { rows: [{ today_vn: todayVn }] } = await database.query(
        `SELECT (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS today_vn`,
      );
      // Active Gym for M1, M2, M4, M5; Expired Gym for M3
      for (const mid of [m1Id, m2Id, m4Id, m5Id]) {
        const payId = randomUUID();
        await database.query(
          `INSERT INTO payments (id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
           amount, method, status, transaction_code, idempotency_key, request_hash, created_by, decided_by, confirmed_at, decided_at)
           VALUES ($1, $2, $3, 'Gym T12 30d', 30, 500000, 'FRONT_DESK', 'SUCCESS',
                   $1::uuid::text, $1::uuid::text, repeat('a', 64), $4, $4, now(), now())`,
          [payId, mid, planId, adminId],
        );
        await database.query(
          `INSERT INTO member_memberships (id, member_id, plan_id, source_payment_id, start_date, end_date, status, activated_at)
           VALUES ($1, $2, $3, $4, $5::date - 2, $5::date + 27, 'ACTIVE', now())`,
          [randomUUID(), mid, planId, payId, todayVn],
        );
      }
      {
        const m3PayId = randomUUID();
        await database.query(
          `INSERT INTO payments (id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
           amount, method, status, transaction_code, idempotency_key, request_hash, created_by, decided_by, confirmed_at, decided_at)
           VALUES ($1, $2, $3, 'Gym T12 30d', 30, 500000, 'FRONT_DESK', 'SUCCESS',
                   $1::uuid::text, $1::uuid::text, repeat('a', 64), $4, $4, now() - interval '40 days', now() - interval '40 days')`,
          [m3PayId, m3Id, planId, adminId],
        );
        await database.query(
          `INSERT INTO member_memberships (id, member_id, plan_id, source_payment_id, start_date, end_date, status, activated_at, expired_at)
           VALUES ($1, $2, $3, $4, $5::date - 40, $5::date - 11, 'EXPIRED', now() - interval '40 days', now() - interval '10 days')`,
          [randomUUID(), m3Id, planId, m3PayId, todayVn],
        );
      }

      // Relationships:
      // M1..M4 with Coach 1; M5 transferred from Coach 1 (rel5OldId ENDED) -> Coach 2 (rel5Id ACTIVE)
      await database.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id, status, paused_at, pause_reason, ended_at, ended_by, end_reason)
         VALUES ($1, $2, $3, 'ACTIVE', NULL, NULL, NULL, NULL, NULL),
                ($4, $5, $3, 'ACTIVE', NULL, NULL, NULL, NULL, NULL),
                ($6, $7, $3, 'PAUSED', now() - interval '2 days', 'MEMBERSHIP_EXPIRED', NULL, NULL, NULL),
                ($8, $9, $3, 'ACTIVE', NULL, NULL, NULL, NULL, NULL),
                ($10, $11, $3, 'ENDED', NULL, NULL, now() - interval '5 days', $13, 'Chuyển Coach mẫu'),
                ($12, $11, $14, 'ACTIVE', NULL, NULL, NULL, NULL, NULL)`,
        [
          rel1Id, m1Id, coach1Id,
          rel2Id, m2Id,
          rel3Id, m3Id,
          rel4Id, m4Id,
          rel5OldId, m5Id,
          rel5Id, adminId, coach2Id,
        ],
      );
      // Record transfer history for M5 (Coach 1 -> Coach 2)
      const transferId = randomUUID();
      await database.query(
        `INSERT INTO coach_transfer_history
         (id, member_id, old_relationship_id, new_relationship_id, old_coach_id, new_coach_id, reason, admin_id)
         VALUES ($1, $2, $3, $4, $5, $6, 'Đổi lịch phù hợp buổi tối', $7)`,
        [transferId, m5Id, rel5OldId, rel5Id, coach1Id, coach2Id, adminId],
      );

      // Entitlements + holds
      const hold1Active = randomUUID();
      const hold1Queued = randomUUID();
      const hold2Active = randomUUID();
      const hold3Active = randomUUID();
      const hold4Active = randomUUID();
      const hold5Active = randomUUID();
      const ent1Active = randomUUID();
      const ent1Queued = randomUUID();
      const ent2Active = randomUUID();
      const ent3Active = randomUUID();
      const ent4Active = randomUUID();
      const ent5Active = randomUUID();

      await database.query(
        `INSERT INTO coach_payment_holds
         (id, member_id, coach_id, plan_code, plan_name, session_count, duration_days, amount, request_key, status, created_at, expires_at, settled_at)
         VALUES
         ($1, $7, $12, 'STANDARD', 'Tiêu chuẩn', 20, 60, 4000000, gen_random_uuid(), 'CONSUMED', now() - interval '3 days', now() - interval '3 days' + interval '15 minutes', now() - interval '3 days'),
         ($2, $7, $12, 'BASIC', 'Cơ bản', 10, 30, 2000000, gen_random_uuid(), 'CONSUMED', now() - interval '2 days', now() - interval '2 days' + interval '15 minutes', now() - interval '2 days'),
         ($3, $8, $12, 'BASIC', 'Cơ bản', 10, 30, 2000000, gen_random_uuid(), 'CONSUMED', now() - interval '3 days', now() - interval '3 days' + interval '15 minutes', now() - interval '3 days'),
         ($4, $9, $12, 'BASIC', 'Cơ bản', 10, 30, 2000000, gen_random_uuid(), 'CONSUMED', now() - interval '3 days', now() - interval '3 days' + interval '15 minutes', now() - interval '3 days'),
         ($5, $10, $12, 'BASIC', 'Cơ bản', 10, 30, 2000000, gen_random_uuid(), 'CONSUMED', now() - interval '3 days', now() - interval '3 days' + interval '15 minutes', now() - interval '3 days'),
         ($6, $11, $13, 'BASIC', 'Cơ bản', 10, 30, 2000000, gen_random_uuid(), 'CONSUMED', now() - interval '3 days', now() - interval '3 days' + interval '15 minutes', now() - interval '3 days')`,
        [
          hold1Active, hold1Queued, hold2Active, hold3Active, hold4Active, hold5Active,
          m1Id, m2Id, m3Id, m4Id, m5Id, coach1Id, coach2Id,
        ],
      );
      await database.query(
        `INSERT INTO coach_entitlements
         (id, hold_id, original_hold_id, relationship_id, member_id, coach_id,
          plan_code, plan_name, snapshot_price, status, total_sessions, remaining_sessions,
          duration_days, starts_on, original_ends_on, ends_on)
         VALUES
         ($1, $7, $7, $13, $18, $23, 'STANDARD', 'Tiêu chuẩn', 4000000, 'ACTIVE', 20, 9, 60, $25::date - 3, $25::date + 56, $25::date + 56),
         ($2, $8, $8, $13, $18, $23, 'BASIC', 'Cơ bản', 2000000, 'QUEUED', 10, 10, 30, NULL, NULL, NULL),
         ($3, $9, $9, $14, $19, $23, 'BASIC', 'Cơ bản', 2000000, 'ACTIVE', 10, 7, 30, $25::date - 3, $25::date + 26, $25::date + 26),
         ($4, $10, $10, $15, $20, $23, 'BASIC', 'Cơ bản', 2000000, 'ACTIVE', 10, 8, 30, $25::date - 3, $25::date + 26, $25::date + 26),
         ($5, $11, $11, $16, $21, $23, 'BASIC', 'Cơ bản', 2000000, 'ACTIVE', 10, 6, 30, $25::date - 3, $25::date + 26, $25::date + 26),
         ($6, $12, $12, $17, $22, $24, 'BASIC', 'Cơ bản', 2000000, 'ACTIVE', 10, 10, 30, $25::date - 3, $25::date + 26, $25::date + 26)`,
        [
          ent1Active, ent1Queued, ent2Active, ent3Active, ent4Active, ent5Active,
          hold1Active, hold1Queued, hold2Active, hold3Active, hold4Active, hold5Active,
          rel1Id, rel2Id, rel3Id, rel4Id, rel5Id,
          m1Id, m2Id, m3Id, m4Id, m5Id,
          coach1Id, coach2Id, todayVn,
        ],
      );

      // Future BOOKED coach_bookings for M1 (2 bookings) and M2 (1 booking)
      const b1a = randomUUID();
      const b1b = randomUUID();
      const b2a = randomUUID();
      await database.query(
        `INSERT INTO coach_bookings (id, entitlement_id, member_id, coach_id, starts_at, ends_at, status)
         VALUES ($1, $4, $6, $8, statement_timestamp() + interval '2 days', statement_timestamp() + interval '2 days 90 minutes', 'BOOKED'),
                ($2, $4, $6, $8, statement_timestamp() + interval '4 days', statement_timestamp() + interval '4 days 90 minutes', 'BOOKED'),
                ($3, $5, $7, $8, statement_timestamp() + interval '3 days', statement_timestamp() + interval '3 days 90 minutes', 'BOOKED')`,
        [b1a, b1b, b2a, ent1Active, ent2Active, m1Id, m2Id, coach1Id],
      );

      // Active training plans & nutrition guides for M1, M2, M5 (with secret content strings to verify privacy allowlist!)
      const plan1Id = randomUUID();
      const guide1Id = randomUUID();
      const plan2Id = randomUUID();
      const guide2Id = randomUUID();
      const plan5Id = randomUUID();
      const guide5Id = randomUUID();
      await database.query(
        `INSERT INTO training_plans (id, relationship_id, member_id, coach_id, title, goal, status, version, published_at)
         VALUES ($1, $4, $7, $10, 'SECRET_PLAN_M1', 'SECRET_PLAN_NOTES_M1', 'ACTIVE', 1, now()),
                ($2, $5, $8, $10, 'SECRET_PLAN_M2', 'SECRET_PLAN_NOTES_M2', 'ACTIVE', 1, now()),
                ($3, $6, $9, $11, 'SECRET_PLAN_M5', 'SECRET_PLAN_NOTES_M5', 'ACTIVE', 1, now())`,
        [plan1Id, plan2Id, plan5Id, rel1Id, rel2Id, rel5Id, m1Id, m2Id, m5Id, coach1Id, coach2Id],
      );
      await database.query(
        `INSERT INTO nutrition_guides (id, relationship_id, member_id, coach_id, title, content, status, version, published_at)
         VALUES ($1, $4, $7, $10, 'SECRET_GUIDE_M1', 'SECRET_GUIDE_CONTENT_M1', 'ACTIVE', 1, now()),
                ($2, $5, $8, $10, 'SECRET_GUIDE_M2', 'SECRET_GUIDE_CONTENT_M2', 'ACTIVE', 1, now()),
                ($3, $6, $9, $11, 'SECRET_GUIDE_M5', 'SECRET_GUIDE_CONTENT_M5', 'ACTIVE', 1, now())`,
        [guide1Id, guide2Id, guide5Id, rel1Id, rel2Id, rel5Id, m1Id, m2Id, m5Id, coach1Id, coach2Id],
      );

      // Chat conversations for M1<->C1 and M2<->C1 (plus M5<->C2 with secret chat content)
      const conv5Id = randomUUID();
      await database.query(
        `INSERT INTO conversations (id, relationship_id, member_id, coach_id)
         VALUES ($1, $4, $7, $10), ($2, $5, $8, $10), ($3, $6, $9, $11)`,
        [conv1Id, conv2Id, conv5Id, rel1Id, rel2Id, rel5Id, m1Id, m2Id, m5Id, coach1Id, coach2Id],
      );
      await database.query(
        `INSERT INTO conversation_participants (conversation_id, user_id)
         VALUES ($1, $4), ($1, $7), ($2, $5), ($2, $7), ($3, $6), ($3, $8)`,
        [conv1Id, conv2Id, conv5Id, m1Id, m2Id, m5Id, coach1Id, coach2Id],
      );
      await database.query(
        `INSERT INTO messages (id, conversation_id, sender_id, client_message_id, message_type, content)
         VALUES ($1, $2, $3, $4, 'TEXT', 'SECRET_CHAT_MESSAGE_T12')`,
        [randomUUID(), conv5Id, m5Id, randomUUID()],
      );

      // =====================================================================
      // 1. Legacy V1 retirement checks (default enableLegacyWrites = false)
      // =====================================================================
      const legacyMemberTerm = await call(base, `/relationships/${rel1Id}/terminations`, m1Token, 'POST', { reason: 'Legacy' });
      assert.equal(legacyMemberTerm.status, 410);
      assert.equal(legacyMemberTerm.body.error.code, 'LEGACY_WORKFLOW_RETIRED');

      const legacyCoachTerm = await call(base, '/coach/termination-requests', coach1Token, 'POST', {
        relationshipId: rel1Id, reason: 'Legacy',
      });
      assert.equal(legacyCoachTerm.status, 410);
      assert.equal(legacyCoachTerm.body.error.code, 'LEGACY_WORKFLOW_RETIRED');

      const legacyDeleteReq = await call(base, `/coach-requests/${randomUUID()}`, m1Token, 'DELETE');
      assert.equal(legacyDeleteReq.status, 410);
      assert.equal(legacyDeleteReq.body.error.code, 'LEGACY_WORKFLOW_RETIRED');

      // Role guards
      assert.equal((await call(base, '/admin/relationships', m1Token)).status, 403);
      assert.equal((await call(base, `/admin/relationships/${rel1Id}`, coach1Token)).status, 403);
      assert.equal((await call(base, '/admin/coach-transfers', m1Token)).status, 403);
      assert.equal((await call(base, '/admin/termination-requests', coach1Token)).status, 403);
      assert.equal((await call(base, `/relationships/${rel1Id}/early-termination-requests`, adminToken, 'POST', {
        reason: 'Admin cannot initiate',
      })).status, 403);
      assert.equal((await call(base, '/early-termination-requests/me', adminToken)).status, 403);

      // =====================================================================
      // 2. Flow A: Mutual Accept (Member M1 requests -> Coach 1 accepts)
      // =====================================================================
      const seatsBeforeM1 = (await database.query('SELECT coach_occupied_seats($1) AS n', [coach1Id])).rows[0].n;
      assert.equal(seatsBeforeM1, 4); // M1, M2, M3, M4

      const m1Req = await call(base, `/relationships/${rel1Id}/early-termination-requests`, m1Token, 'POST', {
        reason: 'Không sắp xếp được lịch tập cố định',
      });
      assert.equal(m1Req.status, 201, JSON.stringify(m1Req.body));
      const m1TermId = m1Req.body.data.id;
      assert.equal(m1Req.body.data.status, 'PENDING_COUNTERPARTY');
      assert.equal(m1Req.body.data.requestedByRole, 'MEMBER');
      assert.equal(m1Req.body.data.requestedByUserId, m1Id);
      assert.equal(m1Req.body.data.counterpartyUserId, coach1Id);
      assert.equal(m1Req.body.data.coachId, coach1Id);
      assert.equal(m1Req.body.data.memberName, 'Nguyễn Thị Mai');
      assert.equal(m1Req.body.data.coachName, 'Huấn luyện viên Một');
      const deadlineDiffHours = (Date.parse(m1Req.body.data.responseDeadlineAt) - Date.parse(m1Req.body.data.createdAt)) / 3_600_000;
      assert.ok(Math.abs(deadlineDiffHours - 72) < 0.01, `Expected 72h window, got ${deadlineDiffHours}`);

      // Notification TERMINATION_REQUESTED sent to Coach 1
      const reqNotif = await database.query(
        `SELECT 1 FROM coach_notifications WHERE user_id = $1 AND kind = 'TERMINATION_REQUESTED' AND subject_id = $2`,
        [coach1Id, m1TermId],
      );
      assert.equal(reqNotif.rowCount, 1);

      // Duplicate open request rejected with 409 REQUEST_EXISTS
      const dupReq = await call(base, `/relationships/${rel1Id}/early-termination-requests`, coach1Token, 'POST', {
        reason: 'Trùng yêu cầu',
      });
      assert.equal(dupReq.status, 409);
      assert.equal(dupReq.body.error.code, 'REQUEST_EXISTS');

      // Requester cannot ACCEPT/REJECT own request; Counterparty cannot WITHDRAW
      assert.equal((await call(base, `/early-termination-requests/${m1TermId}/respond`, m1Token, 'PATCH', {
        decision: 'ACCEPT',
      })).status, 403);
      assert.equal((await call(base, `/early-termination-requests/${m1TermId}/respond`, coach1Token, 'PATCH', {
        decision: 'WITHDRAW',
      })).status, 403);

      // Admin cannot jump the 72h gun on PENDING_COUNTERPARTY -> 409 NOT_DISPUTED
      const earlyAdminDecide = await call(base, `/admin/termination-requests/${m1TermId}`, adminToken, 'PATCH', {
        decision: 'APPROVED', reason: 'Duyệt sớm chưa hết 72h',
      });
      assert.equal(earlyAdminDecide.status, 409);
      assert.equal(earlyAdminDecide.body.error.code, 'NOT_DISPUTED');

      // Admin relationships list shows operational summary, hasQueuedPackage, openTerminationStatus
      const adminRelList = await call(
        base,
        `/admin/relationships?status=ACTIVE&coachId=${coach1Id}&search=Nguy%E1%BB%85n%20Th%E1%BB%8B%20Mai&page=1&pageSize=10`,
        adminToken,
      );
      assert.equal(adminRelList.status, 200);
      assert.equal(adminRelList.body.pagination.totalItems, 1);
      const rel1Row = adminRelList.body.data[0];
      assert.equal(rel1Row.id, rel1Id);
      assert.equal(rel1Row.memberName, 'Nguyễn Thị Mai');
      assert.equal(rel1Row.coachName, 'Huấn luyện viên Một');
      assert.equal(rel1Row.activeEntitlement.planName, 'Tiêu chuẩn');
      assert.equal(rel1Row.activeEntitlement.remainingSessions, 9);
      assert.equal(rel1Row.activeEntitlement.totalSessions, 20);
      assert.equal(rel1Row.hasQueuedPackage, true);
      assert.equal(rel1Row.openTerminationStatus, 'PENDING_COUNTERPARTY');

      // Coach 1 ACCEPTS mutual early termination
      const m1Accept = await call(base, `/early-termination-requests/${m1TermId}/respond`, coach1Token, 'PATCH', {
        decision: 'ACCEPT',
      });
      assert.equal(m1Accept.status, 200, JSON.stringify(m1Accept.body));
      assert.equal(m1Accept.body.data.status, 'ACCEPTED');
      assert.equal(m1Accept.body.data.counterpartyDecision, 'ACCEPTED');
      assert.deepEqual(m1Accept.body.data.effects, {
        relationshipStatus: 'ENDED',
        forfeitedActiveSessions: 9,
        forfeitedQueuedPackage: true,
        cancelledFutureBookingsCount: 2,
        plansArchived: true,
        coachSeatReleased: true,
      });

      // Verify atomic DB effects of ACCEPT
      assert.equal((await database.query('SELECT status FROM coach_relationships WHERE id = $1', [rel1Id])).rows[0].status, 'ENDED');
      const m1EntsAfter = (await database.query(
        'SELECT status, close_reason, remaining_sessions FROM coach_entitlements WHERE relationship_id = $1 ORDER BY total_sessions DESC',
        [rel1Id],
      )).rows;
      assert.equal(m1EntsAfter.length, 2);
      assert.ok(m1EntsAfter.every((e) => e.status === 'ENDED' && e.close_reason === 'EARLY_TERMINATION'));
      assert.equal((await database.query('SELECT count(*)::int AS c FROM simulated_refunds WHERE relationship_id = $1', [rel1Id])).rows[0].c, 0);
      const m1BookingsAfter = (await database.query(
        'SELECT status, charged_at FROM coach_bookings WHERE id IN ($1, $2)',
        [b1a, b1b],
      )).rows;
      assert.ok(m1BookingsAfter.every((b) => b.status === 'CANCELLED' && b.charged_at === null));
      assert.equal((await database.query('SELECT status FROM training_plans WHERE id = $1', [plan1Id])).rows[0].status, 'ARCHIVED');
      assert.equal((await database.query('SELECT status FROM nutrition_guides WHERE id = $1', [guide1Id])).rows[0].status, 'ARCHIVED');
      assert.equal((await database.query('SELECT coach_occupied_seats($1) AS n', [coach1Id])).rows[0].n, 3);

      // Chat STILL works normally after ENDED!
      const postEndMsgMember = await call(base, `/conversations/${rel1Id}/messages`, m1Token, 'POST', {
        messageType: 'TEXT', clientMessageId: randomUUID(), content: 'Cảm ơn Coach nhiều nhé!',
      });
      assert.equal(postEndMsgMember.status, 201, JSON.stringify(postEndMsgMember.body));
      const postEndMsgCoach = await call(base, `/conversations/${rel1Id}/messages`, coach1Token, 'POST', {
        messageType: 'TEXT', clientMessageId: randomUUID(), content: 'Chúc bạn tập luyện tốt!',
      });
      assert.equal(postEndMsgCoach.status, 201);

      // =====================================================================
      // 3. Flow B + C: WITHDRAW -> Re-submit -> REJECT -> ADMIN_REJECTED -> Re-submit -> REJECT -> ADMIN_APPROVED
      // =====================================================================
      const m2WithdrawReq = await call(base, `/relationships/${rel2Id}/early-termination-requests`, m2Token, 'POST', {
        reason: 'Gửi nhầm muốn rút lại',
      });
      assert.equal(m2WithdrawReq.status, 201);
      const m2WithdrawRes = await call(
        base,
        `/early-termination-requests/${m2WithdrawReq.body.data.id}/respond`,
        m2Token,
        'PATCH',
        { decision: 'WITHDRAW' },
      );
      assert.equal(m2WithdrawRes.status, 200);
      assert.equal(m2WithdrawRes.body.data.status, 'CANCELLED');
      assert.equal((await database.query('SELECT status FROM coach_relationships WHERE id = $1', [rel2Id])).rows[0].status, 'ACTIVE');

      // Re-submit allowed after CANCELLED; now Coach 1 submits -> M2 REJECTS -> DISPUTED -> Admin REJECTS
      const c1ReqM2 = await call(base, `/relationships/${rel2Id}/early-termination-requests`, coach1Token, 'POST', {
        reason: 'Coach bận lịch công tác đột xuất',
      });
      assert.equal(c1ReqM2.status, 201);
      const c1TermId = c1ReqM2.body.data.id;

      // REJECT requires mandatory reason -> 422
      assert.equal((await call(base, `/early-termination-requests/${c1TermId}/respond`, m2Token, 'PATCH', {
        decision: 'REJECT',
      })).status, 422);

      const m2Reject = await call(base, `/early-termination-requests/${c1TermId}/respond`, m2Token, 'PATCH', {
        decision: 'REJECT', reason: 'Tôi vẫn muốn tiếp tục theo lộ trình đã đóng tiền',
      });
      assert.equal(m2Reject.status, 200);
      assert.equal(m2Reject.body.data.status, 'DISPUTED');
      assert.equal(m2Reject.body.data.counterpartyDecision, 'REJECTED');
      assert.equal(m2Reject.body.data.escalationReason, 'COUNTERPARTY_REJECTED');
      assert.ok(m2Reject.body.data.disputedAt);

      // Admin decision without reason -> 422
      assert.equal((await call(base, `/admin/termination-requests/${c1TermId}`, adminToken, 'PATCH', {
        decision: 'REJECTED',
      })).status, 422);

      const adminReject = await call(base, `/admin/termination-requests/${c1TermId}`, adminToken, 'PATCH', {
        decision: 'REJECTED', reason: 'Chưa đủ căn cứ chấm dứt; hai bên tiếp tục phối hợp sắp lịch',
      });
      assert.equal(adminReject.status, 200, JSON.stringify(adminReject.body));
      assert.equal(adminReject.body.data.status, 'ADMIN_REJECTED');
      assert.equal(adminReject.body.data.adminNote, 'Chưa đủ căn cứ chấm dứt; hai bên tiếp tục phối hợp sắp lịch');
      assert.equal(adminReject.body.data.effects.relationshipStatus, 'ACTIVE');
      assert.equal((await database.query('SELECT status FROM coach_relationships WHERE id = $1', [rel2Id])).rows[0].status, 'ACTIVE');
      assert.equal((await database.query('SELECT status FROM coach_bookings WHERE id = $1', [b2a])).rows[0].status, 'BOOKED');
      assert.equal((await database.query('SELECT coach_occupied_seats($1) AS n', [coach1Id])).rows[0].n, 3);

      // Second dispute on M2 -> Admin APPROVES -> ends relationship, forfeits sessions, archives plans, frees seat, keeps chat
      const m2Req2 = await call(base, `/relationships/${rel2Id}/early-termination-requests`, m2Token, 'POST', {
        reason: 'Hai bên không thống nhất được phương pháp tập luyện',
      });
      assert.equal(m2Req2.status, 201);
      const m2Term2Id = m2Req2.body.data.id;
      const c1Reject2 = await call(base, `/early-termination-requests/${m2Term2Id}/respond`, coach1Token, 'PATCH', {
        decision: 'REJECT', reason: 'Coach không đồng ý chấm dứt sớm',
      });
      assert.equal(c1Reject2.status, 200);
      assert.equal(c1Reject2.body.data.status, 'DISPUTED');

      const adminApprove = await call(base, `/admin/termination-requests/${m2Term2Id}`, adminToken, 'PATCH', {
        decision: 'APPROVED', reason: 'Xác minh hai bên không còn hợp tác hiệu quả; chấp thuận kết thúc sớm theo D5',
      });
      assert.equal(adminApprove.status, 200, JSON.stringify(adminApprove.body));
      assert.equal(adminApprove.body.data.status, 'ADMIN_APPROVED');
      assert.deepEqual(adminApprove.body.data.effects, {
        relationshipStatus: 'ENDED',
        forfeitedActiveSessions: 7,
        forfeitedQueuedPackage: false,
        cancelledFutureBookingsCount: 1,
        plansArchived: true,
        coachSeatReleased: true,
      });
      assert.equal((await database.query('SELECT status FROM coach_relationships WHERE id = $1', [rel2Id])).rows[0].status, 'ENDED');
      assert.equal((await database.query('SELECT status, close_reason FROM coach_entitlements WHERE id = $1', [ent2Active])).rows[0].close_reason, 'EARLY_TERMINATION');
      assert.equal((await database.query('SELECT status, charged_at FROM coach_bookings WHERE id = $1', [b2a])).rows[0].charged_at, null);
      assert.equal((await database.query('SELECT status FROM training_plans WHERE id = $1', [plan2Id])).rows[0].status, 'ARCHIVED');
      assert.equal((await database.query('SELECT status FROM nutrition_guides WHERE id = $1', [guide2Id])).rows[0].status, 'ARCHIVED');
      assert.equal((await database.query('SELECT coach_occupied_seats($1) AS n', [coach1Id])).rows[0].n, 2); // M3 + M4 remain

      // Chat on rel2 STILL works after ADMIN_APPROVED
      assert.equal((await call(base, `/conversations/${rel2Id}/messages`, m2Token, 'POST', {
        messageType: 'TEXT', clientMessageId: randomUUID(), content: 'Tin nhắn sau khi Admin duyệt kết thúc',
      })).status, 201);

      // Audit logs recorded TERMINATION_DISPUTE_DECIDED for both Admin decisions on rel2
      const disputeAudits = await database.query(
        `SELECT action, metadata FROM admin_audit_logs WHERE entity_id = $1 AND action = 'TERMINATION_DISPUTE_DECIDED' ORDER BY created_at ASC`,
        [rel2Id],
      );
      assert.equal(disputeAudits.rowCount, 2);
      assert.equal(disputeAudits.rows[0].metadata.resultingStatus, 'ADMIN_REJECTED');
      assert.equal(disputeAudits.rows[1].metadata.resultingStatus, 'ADMIN_APPROVED');

      // =====================================================================
      // 4. Flow D: 72h Timeout Auto-Escalation (on PAUSED MEMBERSHIP_EXPIRED & ACTIVE)
      // =====================================================================
      // M3 is PAUSED (MEMBERSHIP_EXPIRED) -> ALLOWED to submit early termination request!
      const m3Req = await call(base, `/relationships/${rel3Id}/early-termination-requests`, m3Token, 'POST', {
        reason: 'Gói Gym đã hết hạn, muốn dừng gói Coach sớm',
      });
      assert.equal(m3Req.status, 201, JSON.stringify(m3Req.body));
      const m3TermId = m3Req.body.data.id;

      // Backdate M3's response_deadline_at past now() -> Coach 1 tries to ACCEPT -> 409 TERMINATION_DEADLINE_EXPIRED + persisted DISPUTED (TIMEOUT_72H)
      await database.query(
        `UPDATE coach_termination_requests
         SET created_at = statement_timestamp() - interval '73 hours',
             response_deadline_at = statement_timestamp() - interval '1 hour'
         WHERE id = $1`,
        [m3TermId],
      );
      const lateAccept = await call(base, `/early-termination-requests/${m3TermId}/respond`, coach1Token, 'PATCH', {
        decision: 'ACCEPT',
      });
      assert.equal(lateAccept.status, 409, JSON.stringify(lateAccept.body));
      assert.equal(lateAccept.body.error.code, 'TERMINATION_DEADLINE_EXPIRED');

      const m3RowAfterTimeout = (await database.query(
        'SELECT status, escalation_reason, disputed_at = response_deadline_at AS matched_deadline FROM coach_termination_requests WHERE id = $1',
        [m3TermId],
      )).rows[0];
      assert.equal(m3RowAfterTimeout.status, 'DISPUTED');
      assert.equal(m3RowAfterTimeout.escalation_reason, 'TIMEOUT_72H');
      assert.equal(m3RowAfterTimeout.matched_deadline, true);

      // M4: test inline auto-escalation on GET /early-termination-requests/me AND GET /admin/termination-requests
      const m4Req = await call(base, `/relationships/${rel4Id}/early-termination-requests`, m4Token, 'POST', {
        reason: 'Quá hạn 72 giờ không thấy Coach phản hồi',
      });
      assert.equal(m4Req.status, 201);
      const m4TermId = m4Req.body.data.id;
      await database.query(
        `UPDATE coach_termination_requests
         SET created_at = statement_timestamp() - interval '74 hours',
             response_deadline_at = statement_timestamp() - interval '2 hours'
         WHERE id = $1`,
        [m4TermId],
      );

      const m4MeList = await call(base, '/early-termination-requests/me', m4Token);
      assert.equal(m4MeList.status, 200);
      const m4MeItem = m4MeList.body.data.find((x) => x.id === m4TermId);
      assert.equal(m4MeItem.status, 'DISPUTED');
      assert.equal(m4MeItem.escalationReason, 'TIMEOUT_72H');
      assert.equal(m4MeItem.memberName, 'Phạm Anh Dũng');
      assert.equal(m4MeItem.coachName, 'Huấn luyện viên Một');

      // GET /admin/termination-requests?status=DISPUTED shows both M3 and M4 disputes
      const adminDisputes = await call(base, '/admin/termination-requests?status=DISPUTED&page=1&pageSize=20', adminToken);
      assert.equal(adminDisputes.status, 200);
      assert.ok(adminDisputes.body.data.some((x) => x.id === m3TermId && x.escalationReason === 'TIMEOUT_72H'));
      assert.ok(adminDisputes.body.data.some((x) => x.id === m4TermId && x.escalationReason === 'TIMEOUT_72H'));

      // Admin rejects M3 timeout dispute -> re-submit M3 -> backdate >72h -> Admin directly adjudicates overdue PENDING_COUNTERPARTY inline!
      const m3AdminReject = await call(base, `/admin/termination-requests/${m3TermId}`, adminToken, 'PATCH', {
        decision: 'REJECTED', reason: 'Gia hạn thêm thời gian trao đổi',
      });
      assert.equal(m3AdminReject.status, 200);
      assert.equal(m3AdminReject.body.data.status, 'ADMIN_REJECTED');

      const m3Req2 = await call(base, `/relationships/${rel3Id}/early-termination-requests`, m3Token, 'POST', {
        reason: 'Lần 2: quá hạn 72h để Admin duyệt trực tiếp inline',
      });
      assert.equal(m3Req2.status, 201);
      const m3Term2Id = m3Req2.body.data.id;
      await database.query(
        `UPDATE coach_termination_requests
         SET created_at = statement_timestamp() - interval '75 hours',
             response_deadline_at = statement_timestamp() - interval '3 hours'
         WHERE id = $1`,
        [m3Term2Id],
      );
      // Do NOT call GET first; PATCH /admin/termination-requests/:id must escalate inline and approve!
      const m3DirectApprove = await call(base, `/admin/termination-requests/${m3Term2Id}`, adminToken, 'PATCH', {
        decision: 'APPROVED', reason: 'Coach không phản hồi quá 72 giờ; chấp thuận kết thúc sớm',
      });
      assert.equal(m3DirectApprove.status, 200, JSON.stringify(m3DirectApprove.body));
      assert.equal(m3DirectApprove.body.data.status, 'ADMIN_APPROVED');
      assert.equal(m3DirectApprove.body.data.escalationReason, 'TIMEOUT_72H');
      assert.equal(m3DirectApprove.body.data.effects.relationshipStatus, 'ENDED');
      assert.equal((await database.query('SELECT status FROM coach_relationships WHERE id = $1', [rel3Id])).rows[0].status, 'ENDED');

      // =====================================================================
      // 5. Flow E: COACH_LOCKED rejected with 409 USE_COACH_INCIDENT_FLOW
      // =====================================================================
      const lockCoach2 = await call(base, `/admin/users/${coach2Id}/status`, adminToken, 'PATCH', {
        status: 'DISABLED', reason: 'Coach 2 tạm nghỉ dài ngày',
      });
      assert.equal(lockCoach2.status, 200);
      const lockedEarlyTerm = await call(base, `/relationships/${rel5Id}/early-termination-requests`, m5Token, 'POST', {
        reason: 'Thử gửi kết thúc sớm khi Coach đang bị khóa',
      });
      assert.equal(lockedEarlyTerm.status, 409);
      assert.equal(lockedEarlyTerm.body.error.code, 'USE_COACH_INCIDENT_FLOW');

      // =====================================================================
      // 6. Admin Relationship Detail Privacy Allowlist & Admin Coach Transfers V2
      // =====================================================================
      const rel5Detail = await call(base, `/admin/relationships/${rel5Id}`, adminToken);
      assert.equal(rel5Detail.status, 200, JSON.stringify(rel5Detail.body));
      assert.equal(rel5Detail.body.data.memberName, 'Hoàng Gia Huy');
      assert.equal(rel5Detail.body.data.coachName, 'Huấn luyện viên Hai');
      assert.equal(rel5Detail.body.data.status, 'PAUSED');
      assert.equal(rel5Detail.body.data.pauseReason, 'COACH_LOCKED');
      assert.equal(rel5Detail.body.data.activeEntitlement.planName, 'Cơ bản');
      assert.equal(rel5Detail.body.data.transferHistory.length, 1);
      assert.equal(rel5Detail.body.data.transferHistory[0].oldCoachName, 'Huấn luyện viên Một');
      assert.equal(rel5Detail.body.data.transferHistory[0].newCoachName, 'Huấn luyện viên Hai');
      assert.equal(rel5Detail.body.data.transferHistory[0].adminName, 'Quản trị T12');
      assert.equal(rel5Detail.body.data.lockIncidents.length, 1);
      assert.equal(rel5Detail.body.data.lockIncidents[0].status, 'OPEN');

      // STRICT PRIVACY CHECK: zero health/plan/nutrition/chat keys or values!
      const rel5DetailJson = JSON.stringify(rel5Detail.body);
      for (const forbidden of [
        'healthNotes', 'injuryNotes', 'heightCm', 'weightKg', 'bodyFatPercent',
        'fitnessGoal', 'dietaryPreferences', 'healthDeclarationCompletedAt',
        'SECRET_GOAL_T12', 'SECRET_HEALTH_T12', 'SECRET_INJURY_T12', 'SECRET_DIET_T12',
        'SECRET_PLAN_M5', 'SECRET_PLAN_NOTES_M5', 'SECRET_GUIDE_M5', 'SECRET_GUIDE_CONTENT_M5',
        'SECRET_CHAT_MESSAGE_T12',
      ]) {
        assert.equal(rel5DetailJson.includes(forbidden), false, `Admin relationship detail leaked ${forbidden}`);
      }

      // GET /admin/coach-transfers pagination + joined names + filters
      const transfersRes = await call(
        base,
        `/admin/coach-transfers?memberId=${m5Id}&oldCoachId=${coach1Id}&newCoachId=${coach2Id}&from=${todayVn}&to=${todayVn}&search=Ho%C3%A0ng%20Gia%20Huy&page=1&pageSize=10`,
        adminToken,
      );
      assert.equal(transfersRes.status, 200);
      assert.equal(transfersRes.body.pagination.totalItems, 1);
      assert.equal(transfersRes.body.data[0].id, transferId);
      assert.equal(transfersRes.body.data[0].memberName, 'Hoàng Gia Huy');
      assert.equal(transfersRes.body.data[0].oldCoachName, 'Huấn luyện viên Một');
      assert.equal(transfersRes.body.data[0].newCoachName, 'Huấn luyện viên Hai');
      assert.equal(transfersRes.body.data[0].adminName, 'Quản trị T12');

      // =====================================================================
      // 7. Direct 0032 DB constraint verification
      // =====================================================================
      // ADMIN_APPROVED without non-empty admin_note MUST fail ck_termination_state_details
      await assert.rejects(
        () => database.query(
          `INSERT INTO coach_termination_requests
           (id, relationship_id, coach_id, reason, status,
            requested_by_user_id, requested_by_role, counterparty_user_id,
            response_deadline_at, disputed_at, escalation_reason,
            admin_note, decided_by, decided_at)
           VALUES ($1, $2, $3, 'Test', 'ADMIN_APPROVED',
                   $4, 'MEMBER', $3,
                   now() + interval '72 hours', now(), 'TIMEOUT_72H',
                   '   ', $5, now())`,
          [randomUUID(), rel4Id, coach1Id, m4Id, adminId],
        ),
        (err) => err.code === '23514' && err.constraint === 'ck_termination_state_details',
      );
      // Duplicate open request (DISPUTED already exists on rel4Id) MUST fail uq_termination_open_relationship
      await assert.rejects(
        () => database.query(
          `INSERT INTO coach_termination_requests
           (id, relationship_id, coach_id, reason, status,
            requested_by_user_id, requested_by_role, counterparty_user_id,
            response_deadline_at)
           VALUES ($1, $2, $3, 'Duplicate open', 'PENDING_COUNTERPARTY',
                   $4, 'MEMBER', $3, now() + interval '72 hours')`,
          [randomUUID(), rel4Id, coach1Id, m4Id],
        ),
        (err) => err.code === '23505' && err.constraint === 'uq_termination_open_relationship',
      );

      // Ending a relationship via another path (trigger close_coach_entitlements) auto-cancels open DISPUTED request
      await database.query(
        `UPDATE coach_relationships
         SET status = 'ENDED', ended_at = statement_timestamp(), ended_by = $1, end_reason = 'Gói Coach đã hết hạn'
         WHERE id = $2`,
        [coach1Id, rel4Id],
      );
      const m4AutoCancelled = (await database.query(
        'SELECT status, decided_at FROM coach_termination_requests WHERE id = $1',
        [m4TermId],
      )).rows[0];
      assert.equal(m4AutoCancelled.status, 'CANCELLED');
      assert.ok(m4AutoCancelled.decided_at);
    } finally {
      await database.query('DELETE FROM coach_notifications WHERE user_id = ANY($1::uuid[])', [allUsers]);
      await database.query('DELETE FROM coach_lock_incidents WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM coach_termination_requests WHERE coach_id = ANY($1::uuid[])', [coachIds]);
      await database.query('DELETE FROM coach_transfer_history WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM coach_bookings WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM coach_entitlements WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM coach_payment_holds WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM nutrition_guides WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM training_plans WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query(
        `UPDATE conversation_participants SET last_read_message_id = NULL
         WHERE conversation_id IN (SELECT id FROM conversations WHERE member_id = ANY($1::uuid[]))`,
        [memberIds],
      );
      await database.query(
        `DELETE FROM messages WHERE conversation_id IN (SELECT id FROM conversations WHERE member_id = ANY($1::uuid[]))`,
        [memberIds],
      );
      await database.query(
        `DELETE FROM conversation_participants WHERE conversation_id IN (SELECT id FROM conversations WHERE member_id = ANY($1::uuid[]))`,
        [memberIds],
      );
      await database.query('DELETE FROM conversations WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM coach_relationships WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM member_memberships WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM payments WHERE member_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM admin_audit_logs WHERE admin_id = $1', [adminId]);
      await database.query('DELETE FROM membership_plans WHERE id = $1', [planId]);
      await database.query('DELETE FROM coach_profiles WHERE user_id = ANY($1::uuid[])', [coachIds]);
      await database.query('DELETE FROM member_profiles WHERE user_id = ANY($1::uuid[])', [memberIds]);
      await database.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [allUsers]);
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });

test('T12: migration 0032 down/up rollback and historical PENDING/APPROVED backfill',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const stripTx = (sql) => sql.replace(/^\s*BEGIN;\s*/i, '').replace(/\s*COMMIT;\s*$/i, '');
    const downSql = stripTx(await readFile(path.join(migrationsDir, '0032_early_termination_v2_disputes.down.sql'), 'utf8'));
    const upSql = stripTx(await readFile(path.join(migrationsDir, '0032_early_termination_v2_disputes.up.sql'), 'utf8'));

    const client = await database.connect();
    try {
      await client.query('BEGIN');
      // 1. Roll back 0032 inside transactional DDL sandbox
      await client.query(downSql);
      const oldIdx = await client.query(
        `SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'uq_termination_pending_relationship'`,
      );
      assert.equal(oldIdx.rowCount, 1);

      // 2. Seed legacy 0002 rows (1 PENDING, 1 APPROVED)
      const adm = randomUUID();
      const coach = randomUUID();
      const memberA = randomUUID();
      const memberB = randomUUID();
      const relA = randomUUID();
      const relB = randomUUID();
      const legacyPendingId = randomUUID();
      const legacyApprovedId = randomUUID();
      await client.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Hist Admin'),
                ($3, $4, 'hash', 'COACH', 'Hist Coach'),
                ($5, $6, 'hash', 'MEMBER', 'Hist Member A'),
                ($7, $8, 'hash', 'MEMBER', 'Hist Member B')`,
        [adm, `${adm}@example.com`, coach, `${coach}@example.com`, memberA, `${memberA}@example.com`, memberB, `${memberB}@example.com`],
      );
      await client.query('INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 8)', [coach]);
      await client.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id, status, ended_at, ended_by, end_reason)
         VALUES ($1, $3, $5, 'ACTIVE', NULL, NULL, NULL),
                ($2, $4, $5, 'ENDED', now() - interval '1 day', $6, 'Legacy approved')`,
        [relA, relB, memberA, memberB, coach, adm],
      );
      await client.query(
        `INSERT INTO coach_termination_requests (id, relationship_id, coach_id, reason, status, decided_by, decided_at)
         VALUES ($1, $3, $5, 'Legacy pending request', 'PENDING', NULL, NULL),
                ($2, $4, $5, 'Legacy approved request', 'APPROVED', $6, now() - interval '1 day')`,
        [legacyPendingId, legacyApprovedId, relA, relB, coach, adm],
      );

      // 3. Re-apply 0032.up.sql and verify historical backfill + index/FK invariants
      await client.query(upSql);
      const newIdx = await client.query(
        `SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'uq_termination_open_relationship'`,
      );
      assert.equal(newIdx.rowCount, 1);

      const pendingBackfilled = (await client.query(
        `SELECT status, requested_by_user_id, requested_by_role, counterparty_user_id,
                coach_id, escalation_reason, disputed_at, response_deadline_at
         FROM coach_termination_requests WHERE id = $1`,
        [legacyPendingId],
      )).rows[0];
      assert.equal(pendingBackfilled.status, 'DISPUTED');
      assert.equal(pendingBackfilled.requested_by_user_id, coach);
      assert.equal(pendingBackfilled.requested_by_role, 'COACH');
      assert.equal(pendingBackfilled.counterparty_user_id, memberA);
      assert.equal(pendingBackfilled.coach_id, coach);
      assert.equal(pendingBackfilled.escalation_reason, 'TIMEOUT_72H');
      assert.ok(pendingBackfilled.disputed_at);
      assert.ok(pendingBackfilled.response_deadline_at);

      const approvedBackfilled = (await client.query(
        `SELECT status, requested_by_role, counterparty_user_id FROM coach_termination_requests WHERE id = $1`,
        [legacyApprovedId],
      )).rows[0];
      assert.equal(approvedBackfilled.status, 'APPROVED');
      assert.equal(approvedBackfilled.requested_by_role, 'COACH');
      assert.equal(approvedBackfilled.counterparty_user_id, memberB);
    } finally {
      await client.query('ROLLBACK').catch(() => {});
      client.release();
      await database.end();
    }
  });
