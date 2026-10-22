import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'membership-lifecycle-secret-at-least-32-chars';

function token(id) {
  return jwt.sign({ role: 'MEMBER', sessionVersion: 0 }, secret, {
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

test('authenticated requests reconcile expired and scheduled memberships',
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
    const paymentIds = Array.from({ length: 3 }, () => randomUUID());
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
      const futureSession = (await database.query(
        `SELECT status, cancellation_reason FROM training_sessions WHERE id = $1`,
        [futureSessionId])).rows[0];
      assert.deepEqual(futureSession, {
        status: 'CANCELLED', cancellation_reason: 'Gói tập của Member đã hết hạn',
      });
    } finally {
      await database.query('DELETE FROM training_sessions WHERE id = $1', [futureSessionId]);
      await database.query('DELETE FROM coach_relationships WHERE id IN ($1, $2)',
        [renewedRelationshipId, expiredRelationshipId]);
      await database.query('DELETE FROM member_memberships WHERE member_id IN ($1, $2)',
        [renewedMemberId, expiredMemberId]);
      await database.query('DELETE FROM payments WHERE id = ANY($1)', [paymentIds]);
      await database.query('DELETE FROM membership_plans WHERE id = $1', [planId]);
      await database.query('DELETE FROM coach_profiles WHERE user_id = $1', [coachId]);
      await database.query('DELETE FROM users WHERE id IN ($1, $2, $3, $4)',
        [adminId, coachId, renewedMemberId, expiredMemberId]);
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });
