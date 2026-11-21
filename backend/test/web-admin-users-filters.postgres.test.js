import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'web-admin-users-filters-secret-32-chars!!';

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

test('GET /api/v1/admin/users supports from/to (VN timezone), hasGym, hasCoach, hasAvailableSlots, combined filters, and 422 on from > to',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const app = createApp({ database, jwtSecret: secret });
    const server = app.listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;

    const tag = `flt-${randomUUID().slice(0, 8)}`;
    const adminId = randomUUID();
    const planId = randomUUID();

    // 4 members positioned around VN date 2026-04-10 (UTC+7):
    // mPrev:  2026-04-09 23:59:59+07 (2026-04-09T16:59:59Z) -> VN date 2026-04-09
    // mDay1:  2026-04-10 00:00:00+07 (2026-04-09T17:00:00Z) -> VN date 2026-04-10 (active gym + active coach)
    // mDay2:  2026-04-10 23:59:59+07 (2026-04-10T16:59:59Z) -> VN date 2026-04-10 (expired gym + paused coach)
    // mNext:  2026-04-11 00:00:00+07 (2026-04-10T17:00:00Z) -> VN date 2026-04-11 (scheduled gym + ended coach)
    const mPrev = randomUUID();
    const mDay1 = randomUUID();
    const mDay2 = randomUUID();
    const mNext = randomUUID();

    // 2 coaches:
    // coachFull: 8 occupied seats (7 ACTIVE relationships + 1 open HELD hold)
    // coachAvail: 7 occupied seats (6 ACTIVE relationships + 1 PAUSED relationship)
    const coachFull = randomUUID();
    const coachAvail = randomUUID();

    // Extra filler members to occupy coach seats (not matching `tag` search)
    const extraMembers = Array.from({ length: 13 }, () => randomUUID());
    const allUserIds = [adminId, mPrev, mDay1, mDay2, mNext, coachFull, coachAvail, ...extraMembers];
    const adminToken = token(adminId, 'ADMIN', 0);

    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name, phone, created_at)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Admin Filter Test', '0900000099', '2026-04-01T00:00:00Z'),
                ($3, $4, 'hash', 'MEMBER', $5, '0910000001', '2026-04-09T16:59:59Z'),
                ($6, $7, 'hash', 'MEMBER', $8, '0910000002', '2026-04-09T17:00:00Z'),
                ($9, $10, 'hash', 'MEMBER', $11, '0910000003', '2026-04-10T16:59:59Z'),
                ($12, $13, 'hash', 'MEMBER', $14, '0910000004', '2026-04-10T17:00:00Z'),
                ($15, $16, 'hash', 'COACH', $17, '0920000001', '2026-04-10T05:00:00Z'),
                ($18, $19, 'hash', 'COACH', $20, '0920000002', '2026-04-10T06:00:00Z')`,
        [
          adminId, `${adminId}@example.com`,
          mPrev, `${mPrev}@example.com`, `${tag} Member Prev`,
          mDay1, `${mDay1}@example.com`, `${tag} Member Day1`,
          mDay2, `${mDay2}@example.com`, `${tag} Member Day2`,
          mNext, `${mNext}@example.com`, `${tag} Member Next`,
          coachFull, `${coachFull}@example.com`, `${tag} Coach Full`,
          coachAvail, `${coachAvail}@example.com`, `${tag} Coach Avail`,
        ],
      );

      for (const uid of [coachFull, coachAvail]) {
        await database.query(
          `INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 8)`,
          [uid],
        );
      }

      for (let i = 0; i < extraMembers.length; i += 1) {
        const eid = extraMembers[i];
        await database.query(
          `INSERT INTO users (id, email, password_hash, role, full_name, created_at)
           VALUES ($1, $2, 'hash', 'MEMBER', $3, '2026-03-01T00:00:00Z')`,
          [eid, `${eid}@example.com`, `Seat Filler ${i + 1}`],
        );
      }

      // Membership plan & memberships
      await database.query(
        `INSERT INTO membership_plans (id, name, price, duration_days, status, created_by)
         VALUES ($1, 'Gói Gym Filter Test', 500000, 30, 'ACTIVE', $2)`,
        [planId, adminId],
      );
      const { rows: [{ today_vn: todayVn }] } = await database.query(
        `SELECT (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS today_vn`,
      );

      async function insertMembership(memberId, startOffsetDays, endOffsetDays, status) {
        const payId = randomUUID();
        await database.query(
          `INSERT INTO payments (id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
           amount, method, status, transaction_code, idempotency_key, request_hash, created_by, confirmed_at, decided_at)
           VALUES ($1, $2, $3, 'Gói Gym Filter Test', 30, 500000, 'MOCK_QR', 'SUCCESS',
                   $1::uuid::text, $1::uuid::text, repeat('b', 64), $2, now(), now())`,
          [payId, memberId, planId],
        );
        const activatedAt = status === 'SCHEDULED' ? null : new Date().toISOString();
        const expiredAt = status === 'EXPIRED' ? new Date().toISOString() : null;
        await database.query(
          `INSERT INTO member_memberships (id, member_id, plan_id, source_payment_id, start_date, end_date, status, activated_at, expired_at)
           VALUES ($1, $2, $3, $4, $5::date + $6::int, $5::date + $7::int, $8, $9, $10)`,
          [randomUUID(), memberId, planId, payId, todayVn, startOffsetDays, endOffsetDays, status, activatedAt, expiredAt],
        );
      }

      // mDay1: ACTIVE covering today
      await insertMembership(mDay1, -5, 24, 'ACTIVE');
      // mDay2: EXPIRED (ended yesterday)
      await insertMembership(mDay2, -35, -1, 'EXPIRED');
      // mNext: SCHEDULED (starts tomorrow)
      await insertMembership(mNext, 1, 30, 'SCHEDULED');

      // Coach relationships:
      // mDay1 -> coachFull (ACTIVE)
      // mDay2 -> coachAvail (PAUSED with MEMBERSHIP_EXPIRED)
      // mNext -> coachAvail (ENDED)
      await database.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id, status, paused_at, pause_reason, ended_at, ended_by, end_reason)
         VALUES ($1, $2, $3, 'ACTIVE', NULL, NULL, NULL, NULL, NULL),
                ($4, $5, $6, 'PAUSED', now(), 'MEMBERSHIP_EXPIRED', NULL, NULL, NULL),
                ($7, $8, $6, 'ENDED', NULL, NULL, now(), $9, 'Đã kết thúc')`,
        [
          randomUUID(), mDay1, coachFull,
          randomUUID(), mDay2, coachAvail,
          randomUUID(), mNext, adminId,
        ],
      );

      // Fill coachFull to 8 occupied seats: mDay1 (1) + 6 ACTIVE relationships (7) + 1 open HELD hold (8)
      for (let i = 0; i < 6; i += 1) {
        await database.query(
          `INSERT INTO coach_relationships (id, member_id, coach_id, status)
           VALUES ($1, $2, $3, 'ACTIVE')`,
          [randomUUID(), extraMembers[i], coachFull],
        );
      }
      await database.query(
        `INSERT INTO coach_payment_holds
         (id, member_id, coach_id, plan_code, plan_name, session_count, duration_days, amount, request_key, status, created_at, expires_at)
         VALUES ($1, $2, $3, 'BASIC', 'Cơ bản', 10, 30, 2000000, gen_random_uuid(), 'HELD', statement_timestamp(), statement_timestamp() + interval '15 minutes')`,
        [randomUUID(), extraMembers[6], coachFull],
      );

      // Fill coachAvail to 7 occupied seats: mDay2 PAUSED (1) + 6 ACTIVE relationships (7)
      for (let i = 7; i < 13; i += 1) {
        await database.query(
          `INSERT INTO coach_relationships (id, member_id, coach_id, status)
           VALUES ($1, $2, $3, 'ACTIVE')`,
          [randomUUID(), extraMembers[i], coachAvail],
        );
      }

      // Sanity-check occupied seat counts in DB
      assert.equal((await database.query('SELECT coach_occupied_seats($1) AS n', [coachFull])).rows[0].n, 8);
      assert.equal((await database.query('SELECT coach_occupied_seats($1) AS n', [coachAvail])).rows[0].n, 7);

      // 1. Validation: from > to -> 422 VALIDATION_ERROR
      const badRange = await call(base, `/admin/users?from=2026-04-11&to=2026-04-10`, adminToken);
      assert.equal(badRange.status, 422);
      assert.equal(badRange.body.error.code, 'VALIDATION_ERROR');

      // Invalid date format or enum -> 422
      assert.equal((await call(base, `/admin/users?from=not-a-date`, adminToken)).status, 422);
      assert.equal((await call(base, `/admin/users?hasGym=yes`, adminToken)).status, 422);

      // 2. VN timezone boundary on from & to
      const onDay10 = await call(
        base,
        `/admin/users?role=MEMBER&search=${encodeURIComponent(tag)}&from=2026-04-10&to=2026-04-10`,
        adminToken,
      );
      assert.equal(onDay10.status, 200);
      assert.deepEqual(
        onDay10.body.data.map((u) => u.id).sort(),
        [mDay1, mDay2].sort(),
      );
      assert.deepEqual(onDay10.body.pagination, {
        page: 1,
        pageSize: 20,
        totalItems: 2,
        totalPages: 1,
      });

      const fromDay10 = await call(
        base,
        `/admin/users?role=MEMBER&search=${encodeURIComponent(tag)}&from=2026-04-10`,
        adminToken,
      );
      assert.equal(fromDay10.status, 200);
      assert.deepEqual(
        fromDay10.body.data.map((u) => u.id).sort(),
        [mDay1, mDay2, mNext].sort(),
      );

      const toDay10 = await call(
        base,
        `/admin/users?role=MEMBER&search=${encodeURIComponent(tag)}&to=2026-04-10`,
        adminToken,
      );
      assert.equal(toDay10.status, 200);
      assert.deepEqual(
        toDay10.body.data.map((u) => u.id).sort(),
        [mPrev, mDay1, mDay2].sort(),
      );

      // 3. hasGym=1 and hasGym=true
      for (const flag of ['1', 'true']) {
        const res = await call(
          base,
          `/admin/users?search=${encodeURIComponent(tag)}&hasGym=${flag}`,
          adminToken,
        );
        assert.equal(res.status, 200);
        assert.deepEqual(res.body.data.map((u) => u.id), [mDay1]);
        assert.ok(res.body.data[0].activeMembershipEndDate);
      }

      // hasGym=0 / false accepted without restricting
      const gymFalse = await call(
        base,
        `/admin/users?role=MEMBER&search=${encodeURIComponent(tag)}&hasGym=false`,
        adminToken,
      );
      assert.equal(gymFalse.status, 200);
      assert.equal(gymFalse.body.pagination.totalItems, 4);

      // 4. hasCoach=1 and hasCoach=true (includes ACTIVE and PAUSED, excludes ENDED and none)
      for (const flag of ['1', 'true']) {
        const res = await call(
          base,
          `/admin/users?search=${encodeURIComponent(tag)}&hasCoach=${flag}`,
          adminToken,
        );
        assert.equal(res.status, 200);
        assert.deepEqual(
          res.body.data.map((u) => u.id).sort(),
          [mDay1, mDay2].sort(),
        );
        const byId = Object.fromEntries(res.body.data.map((u) => [u.id, u]));
        assert.equal(byId[mDay1].coachRelationshipStatus, 'ACTIVE');
        assert.equal(byId[mDay1].coachPauseReason, null);
        assert.equal(byId[mDay2].coachRelationshipStatus, 'PAUSED');
        assert.equal(byId[mDay2].coachPauseReason, 'MEMBERSHIP_EXPIRED');
      }

      // 5. hasAvailableSlots=1 and hasAvailableSlots=true (coach with 7 seats included, coach with 8 seats excluded, members excluded)
      const allCoaches = await call(
        base,
        `/admin/users?role=COACH&search=${encodeURIComponent(tag)}`,
        adminToken,
      );
      assert.equal(allCoaches.status, 200);
      const coachById = Object.fromEntries(allCoaches.body.data.map((u) => [u.id, u]));
      assert.equal(coachById[coachFull].usedSlots, 8);
      assert.equal(coachById[coachAvail].usedSlots, 7);

      for (const flag of ['1', 'true']) {
        const res = await call(
          base,
          `/admin/users?search=${encodeURIComponent(tag)}&hasAvailableSlots=${flag}`,
          adminToken,
        );
        assert.equal(res.status, 200);
        assert.deepEqual(res.body.data.map((u) => u.id), [coachAvail]);
        assert.equal(res.body.data[0].usedSlots, 7);
      }

      // 6. Combined filters: role + from + to + hasGym + hasCoach
      const combined = await call(
        base,
        `/admin/users?role=MEMBER&search=${encodeURIComponent(tag)}&from=2026-04-10&to=2026-04-10&hasGym=1&hasCoach=true`,
        adminToken,
      );
      assert.equal(combined.status, 200);
      assert.deepEqual(combined.body.data.map((u) => u.id), [mDay1]);
      assert.deepEqual(combined.body.pagination, {
        page: 1,
        pageSize: 20,
        totalItems: 1,
        totalPages: 1,
      });
    } finally {
      await database.query('DELETE FROM coach_payment_holds WHERE coach_id = ANY($1::uuid[])', [[coachFull, coachAvail]]);
      await database.query('DELETE FROM coach_relationships WHERE coach_id = ANY($1::uuid[])', [[coachFull, coachAvail]]);
      await database.query('DELETE FROM member_memberships WHERE member_id = ANY($1::uuid[])', [[mPrev, mDay1, mDay2, mNext]]);
      await database.query('DELETE FROM payments WHERE member_id = ANY($1::uuid[])', [[mPrev, mDay1, mDay2, mNext]]);
      await database.query('DELETE FROM membership_plans WHERE id = $1', [planId]);
      await database.query('DELETE FROM coach_profiles WHERE user_id = ANY($1::uuid[])', [[coachFull, coachAvail]]);
      await database.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [allUserIds]);
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });
