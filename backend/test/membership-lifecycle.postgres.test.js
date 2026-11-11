import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';
import { reconcileMembershipLifecycles } from '../src/services/membership-lifecycle.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'membership-lifecycle-secret-at-least-32-chars';

function token(id, role = 'MEMBER') {
  return jwt.sign({ role, sessionVersion: 0 }, secret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
    subject: id, expiresIn: 3600,
  });
}

async function getMe(base, bearer) {
  const response = await fetch(`${base}/api/v1/users/me`, {
    headers: { authorization: `Bearer ${bearer}` },
  });
  return { status: response.status, body: await response.json() };
}

test('expiry pauses Coach access while preserving future sessions and plans until renewal',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const app = createApp({ database, jwtSecret: secret });
    const server = app.listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;
    const adminId = randomUUID();
    const coachId = randomUUID();
    const renewedMemberId = randomUUID();
    const expiredMemberId = randomUUID();
    const planId = randomUUID();
    const renewedRelationshipId = randomUUID();
    const expiredRelationshipId = randomUUID();
    const futureSessionId = randomUUID();
    const futurePlanId = randomUUID();
    const futureDayId = randomUUID();
    const paymentIds = Array.from({ length: 4 }, () => randomUUID());
    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Admin'),
                ($3, $4, 'hash', 'COACH', 'Coach'),
                ($5, $6, 'hash', 'MEMBER', 'Renewed Member'),
                ($7, $8, 'hash', 'MEMBER', 'Expired Member')`,
        [adminId, `${adminId}@example.com`, coachId, `${coachId}@example.com`,
          renewedMemberId, `${renewedMemberId}@example.com`,
          expiredMemberId, `${expiredMemberId}@example.com`],
      );
      await database.query(
        'INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 2)',
        [coachId],
      );
      await database.query(
        `INSERT INTO member_profiles (user_id, health_notes) VALUES ($1, 'Private health note')`,
        [expiredMemberId],
      );
      await database.query(
        `INSERT INTO membership_plans
         (id, name, price, duration_days, status, created_by)
         VALUES ($1, 'Lifecycle Plan', 100000, 30, 'ACTIVE', $2)`,
        [planId, adminId],
      );

      await database.query(
        `INSERT INTO payments
         (id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
          amount, method, status, transaction_code, idempotency_key,
          request_hash, created_by, confirmed_at, decided_at)
         VALUES
         ($1, $2, $6, 'Lifecycle Plan', 30, 100000, 'MOCK_QR', 'SUCCESS',
          $7, $8, repeat('a', 64), $2, now(), now()),
         ($3, $2, $6, 'Lifecycle Plan', 30, 100000, 'MOCK_QR', 'SUCCESS',
          $9, $10, repeat('b', 64), $2, now(), now()),
         ($4, $5, $6, 'Lifecycle Plan', 30, 100000, 'MOCK_QR', 'SUCCESS',
          $11, $12, repeat('c', 64), $5, now(), now())`,
        [paymentIds[0], renewedMemberId, paymentIds[1], paymentIds[2],
          expiredMemberId, planId,
          `MG-${paymentIds[0]}`, randomUUID(), `MG-${paymentIds[1]}`, randomUUID(),
          `MG-${paymentIds[2]}`, randomUUID()],
      );
      await database.query(
        `INSERT INTO member_memberships
         (id, member_id, plan_id, source_payment_id, start_date, end_date,
          status, activated_at)
         VALUES
         ($1, $2, $9, $3, current_date - 30, current_date - 1, 'ACTIVE', now()),
         ($4, $2, $9, $5, current_date, current_date + 29, 'SCHEDULED', NULL),
         ($6, $7, $9, $8, current_date - 30, current_date - 1, 'ACTIVE', now())`,
        [randomUUID(), renewedMemberId, paymentIds[0], randomUUID(), paymentIds[1],
          randomUUID(), expiredMemberId, paymentIds[2], planId],
      );
      await database.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id)
         VALUES ($1, $2, $5), ($3, $4, $5)`,
        [renewedRelationshipId, renewedMemberId, expiredRelationshipId,
          expiredMemberId, coachId],
      );
      await database.query(
        `INSERT INTO training_sessions
         (id, relationship_id, member_id, title, scheduled_start_at)
         VALUES ($1, $2, $3, 'Future session', now() + interval '1 day')`,
        [futureSessionId, expiredRelationshipId, expiredMemberId],
      );
      await database.query(
        `INSERT INTO training_plans
         (id, relationship_id, member_id, coach_id, title, version, status, published_at)
         VALUES ($1, $2, $3, $4, 'Future plan', 1, 'ACTIVE', now())`,
        [futurePlanId, expiredRelationshipId, expiredMemberId, coachId],
      );
      await database.query(
        `INSERT INTO training_plan_days (id, plan_id, day_number, scheduled_date, title)
         VALUES ($1, $2, 1, current_date + 2, 'Future training day')`,
        [futureDayId, futurePlanId],
      );

      const response = await getMe(base, token(renewedMemberId));
      assert.equal(response.status, 200, JSON.stringify(response.body));

      const renewedMemberships = (await database.query(
        `SELECT status, activated_at, expired_at FROM member_memberships
         WHERE member_id = $1 ORDER BY start_date`, [renewedMemberId])).rows;
      assert.equal(renewedMemberships[0].status, 'EXPIRED');
      assert.ok(renewedMemberships[0].expired_at);
      assert.equal(renewedMemberships[1].status, 'ACTIVE');
      assert.ok(renewedMemberships[1].activated_at);
      assert.equal((await database.query(
        'SELECT status FROM coach_relationships WHERE id = $1',
        [renewedRelationshipId])).rows[0].status, 'ACTIVE');

      const expiredRelationship = (await database.query(
        `SELECT status, pause_reason FROM coach_relationships WHERE id = $1`,
        [expiredRelationshipId])).rows[0];
      assert.deepEqual(expiredRelationship,
        { status: 'PAUSED', pause_reason: 'MEMBERSHIP_EXPIRED' });
      const pausedCoachDetail = await fetch(`${base}/api/v1/coach/members/${expiredMemberId}`, {
        headers: { authorization: `Bearer ${token(coachId, 'COACH')}` },
      });
      assert.equal(pausedCoachDetail.status, 200);
      assert.equal((await pausedCoachDetail.json()).data.member.healthNotes, null);
      const futureSession = (await database.query(
        `SELECT status, cancellation_reason, cancelled_at FROM training_sessions WHERE id = $1`,
        [futureSessionId])).rows[0];
      assert.deepEqual(futureSession, {
        status: 'SCHEDULED', cancellation_reason: null, cancelled_at: null,
      });
      assert.equal((await database.query(
        `SELECT status FROM training_plans WHERE id = $1`,
        [futurePlanId])).rows[0].status, 'ACTIVE');
      assert.equal((await database.query(
        `SELECT count(*)::int AS count FROM training_plan_days WHERE plan_id = $1`,
        [futurePlanId])).rows[0].count, 1);
      const pausedSessions = await fetch(`${base}/api/v1/training-sessions/me`, {
        headers: { authorization: `Bearer ${token(expiredMemberId)}` },
      });
      assert.equal(pausedSessions.status, 200);
      assert.deepEqual((await pausedSessions.json()).data
        .filter((session) => session.id === futureSessionId)
        .map(({ status, accessLocked }) => ({ status, accessLocked })),
      [{ status: 'SCHEDULED', accessLocked: true }]);
      const pausedPlan = await fetch(`${base}/api/v1/training-plans/me/active`, {
        headers: { authorization: `Bearer ${token(expiredMemberId)}` },
      });
      assert.equal(pausedPlan.status, 200);
      assert.equal((await pausedPlan.json()).data.accessLocked, true);

      await database.query(
        `INSERT INTO payments
         (id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
          amount, method, status, transaction_code, idempotency_key,
          request_hash, created_by, confirmed_at, decided_at)
         VALUES ($1, $2, $3, 'Lifecycle Plan', 30, 100000, 'MOCK_QR', 'SUCCESS',
          $4, $5, repeat('d', 64), $2, now(), now())`,
        [paymentIds[3], expiredMemberId, planId, `MG-${paymentIds[3]}`, randomUUID()],
      );
      await database.query(
        `INSERT INTO member_memberships
         (id, member_id, plan_id, source_payment_id, start_date, end_date, status)
         VALUES ($1, $2, $3, $4, current_date, current_date + 29, 'SCHEDULED')`,
        [randomUUID(), expiredMemberId, planId, paymentIds[3]],
      );
      await reconcileMembershipLifecycles({ connect: () => database.connect() });
      assert.equal((await database.query(
        `SELECT status FROM coach_relationships WHERE id = $1`,
        [expiredRelationshipId])).rows[0].status, 'ACTIVE');
      const resumedCoachDetail = await fetch(`${base}/api/v1/coach/members/${expiredMemberId}`, {
        headers: { authorization: `Bearer ${token(coachId, 'COACH')}` },
      });
      assert.equal(resumedCoachDetail.status, 200);
      assert.equal((await resumedCoachDetail.json()).data.member.healthNotes, 'Private health note');
      assert.equal((await database.query(
        `SELECT status FROM training_sessions WHERE id = $1`,
        [futureSessionId])).rows[0].status, 'SCHEDULED');
      assert.equal((await database.query(
        `SELECT status FROM training_plans WHERE id = $1`,
        [futurePlanId])).rows[0].status, 'ACTIVE');
      const resumedSessions = await fetch(`${base}/api/v1/training-sessions/me`, {
        headers: { authorization: `Bearer ${token(expiredMemberId)}` },
      });
      assert.equal(resumedSessions.status, 200);
      assert.deepEqual((await resumedSessions.json()).data
        .filter((session) => session.id === futureSessionId)
        .map(({ status, accessLocked }) => ({ status, accessLocked })),
      [{ status: 'SCHEDULED', accessLocked: false }]);
      const resumedPlan = await fetch(`${base}/api/v1/training-plans/me/active`, {
        headers: { authorization: `Bearer ${token(expiredMemberId)}` },
      });
      assert.equal(resumedPlan.status, 200);
      assert.equal((await resumedPlan.json()).data.accessLocked, false);
    } finally {
      await database.query('DELETE FROM training_plan_days WHERE id = $1', [futureDayId]);
      await database.query('DELETE FROM training_plans WHERE id = $1', [futurePlanId]);
      await database.query('DELETE FROM training_sessions WHERE id = $1', [futureSessionId]);
      await database.query('DELETE FROM coach_relationships WHERE id IN ($1, $2)',
        [renewedRelationshipId, expiredRelationshipId]);
      await database.query('DELETE FROM member_memberships WHERE member_id IN ($1, $2)',
        [renewedMemberId, expiredMemberId]);
      await database.query('DELETE FROM payments WHERE id = ANY($1)', [paymentIds]);
      await database.query('DELETE FROM membership_plans WHERE id = $1', [planId]);
      await database.query('DELETE FROM coach_profiles WHERE user_id = $1', [coachId]);
      await database.query('DELETE FROM member_profiles WHERE user_id = $1', [expiredMemberId]);
      await database.query('DELETE FROM users WHERE id IN ($1, $2, $3, $4)',
        [adminId, coachId, renewedMemberId, expiredMemberId]);
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });
