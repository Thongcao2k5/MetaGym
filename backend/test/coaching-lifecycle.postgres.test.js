import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'coaching-lifecycle-test-secret-32-chars';

function token(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, secret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
    subject: id, expiresIn: 3600,
  });
}

async function call(base, path, bearer, method = 'GET', body) {
  const response = await fetch(`${base}/api/v1${path}`, {
    method,
    headers: { authorization: `Bearer ${bearer}`,
      ...(body === undefined ? {} : { 'content-type': 'application/json' }) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: response.status, body: await response.json() };
}

test('Coach requests enforce ownership, membership, capacity and lifecycle under concurrency',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const app = createApp({ database, jwtSecret: secret, enableLegacyWrites: true });
    const server = app.listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;
    const adminId = randomUUID();
    const members = Array.from({ length: 3 }, () => randomUUID());
    const coaches = Array.from({ length: 2 }, () => randomUUID());
    const planId = randomUUID();
    const m = members.map((id) => token(id, 'MEMBER'));
    const c = coaches.map((id) => token(id, 'COACH'));
    try {
      for (const [id, role] of [
        [adminId, 'ADMIN'], ...members.map((id) => [id, 'MEMBER']),
        ...coaches.map((id) => [id, 'COACH']),
      ]) {
        await database.query(
          `INSERT INTO users (id, email, password_hash, role, full_name)
           VALUES ($1, $2, 'hash', $3, $4)`,
          [id, `${id}@example.com`, role, role],
        );
      }
      for (const id of coaches) {
        await database.query(
          'INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 1)', [id],
        );
      }
      await database.query(
        `INSERT INTO membership_plans
         (id, name, price, duration_days, status, created_by)
         VALUES ($1, 'Coaching test', 0, 30, 'ACTIVE', $2)`, [planId, adminId],
      );
      assert.equal((await call(base, '/coach-requests', m[0], 'POST',
        { coachId: coaches[0] })).body.error.code, 'MEMBERSHIP_REQUIRED');
      assert.equal((await call(base, '/coach-requests', c[0], 'POST',
        { coachId: coaches[1] })).status, 403);

      for (const memberId of members) {
        const paymentId = randomUUID();
        await database.query(
          `INSERT INTO payments
           (id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
            amount, method, transaction_code, idempotency_key, request_hash,
            created_by, status, confirmed_at, decided_at)
           VALUES ($1, $2, $3, 'Coaching test', 30, 0, 'MOCK_QR', $4, $5,
                   $6, $2, 'SUCCESS', now(), now())`,
          [paymentId, memberId, planId, randomUUID(), randomUUID(), 'a'.repeat(64)],
        );
        await database.query(
          `INSERT INTO member_memberships
           (id, member_id, plan_id, source_payment_id, start_date, end_date,
            status, activated_at)
           VALUES ($1, $2, $3, $4,
                   (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
                   (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 30,
                   'ACTIVE', now())`,
          [randomUUID(), memberId, planId, paymentId],
        );
      }

      const parallel = await Promise.all(Array.from({ length: 2 }, () =>
        call(base, '/coach-requests', m[0], 'POST', { coachId: coaches[0] })));
      assert.deepEqual(parallel.map((item) => item.status).sort(), [201, 409]);
      const firstId = parallel.find((item) => item.status === 201).body.data.id;
      assert.equal((await call(base, `/coach-requests/${firstId}`, m[1], 'DELETE')).status, 404);
      assert.equal((await call(base, `/coach/requests/${firstId}`, c[1])).status, 404);
      assert.equal((await call(base, `/coach/requests/${firstId}`, c[1], 'PATCH',
        { decision: 'ACCEPTED' })).status, 404);
      assert.equal((await call(base, `/coach-requests/${firstId}`, m[0], 'DELETE'))
        .body.data.status, 'CANCELLED');
      assert.equal((await call(base, `/coach-requests/${firstId}`, m[0], 'DELETE')).status, 404);

      const second = await call(base, '/coach-requests', m[0], 'POST',
        { coachId: coaches[0] });
      assert.equal(second.status, 201);
      const secondId = second.body.data.id;
      assert.equal((await call(base, `/coach/requests/${secondId}`, c[0], 'PATCH',
        { decision: 'REJECTED' })).status, 422);
      const rejected = await call(base, `/coach/requests/${secondId}`, c[0], 'PATCH',
        { decision: 'REJECTED', reason: 'Unavailable' });
      assert.equal(rejected.body.data.rejectionReason, 'Unavailable');
      assert.equal((await call(base, `/coach/requests/${secondId}`, c[0], 'PATCH',
        { decision: 'ACCEPTED' })).status, 404);

      const acceptedRequest = await call(base, '/coach-requests', m[0], 'POST',
        { coachId: coaches[0] });
      const accepted = await call(base, `/coach/requests/${acceptedRequest.body.data.id}`,
        c[0], 'PATCH', { decision: 'ACCEPTED' });
      assert.equal(accepted.status, 200, JSON.stringify(accepted.body));
      const relationshipId = accepted.body.data.relationship.id;
      assert.equal((await call(base, '/coach-requests', m[0], 'POST',
        { coachId: coaches[1] })).body.error.code, 'COACH_REQUEST_CONFLICT');
      assert.equal((await call(base, '/coaches', m[0])).body.data.find(
        (item) => item.id === coaches[0]).availableSlots, 0);
      assert.equal((await call(base, '/relationships/me', m[0])).body.data.id,
        relationshipId);
      assert.equal((await call(base, '/relationships/me', m[1])).body.data, null);
      assert.equal((await call(base, `/relationships/${relationshipId}/terminations`,
        m[1], 'POST', { reason: 'Not my relationship' })).status, 404);

      const fullRequest = await call(base, '/coach-requests', m[1], 'POST',
        { coachId: coaches[0] });
      await database.query(
        `UPDATE member_memberships SET status = 'EXPIRED', expired_at = now()
         WHERE member_id = $1`, [members[1]],
      );
      assert.equal((await call(base, `/coach/requests/${fullRequest.body.data.id}`,
        c[0], 'PATCH', { decision: 'ACCEPTED' })).body.error.code,
      'MEMBERSHIP_REQUIRED');
      await database.query(
        `UPDATE member_memberships SET status = 'ACTIVE', expired_at = NULL
         WHERE member_id = $1`, [members[1]],
      );
      assert.equal((await call(base, `/coach/requests/${fullRequest.body.data.id}`,
        c[0], 'PATCH', { decision: 'ACCEPTED' })).body.error.code, 'COACH_FULL');
      assert.equal((await call(base, `/coach/requests/${fullRequest.body.data.id}`,
        c[0])).body.data.status, 'PENDING');
      assert.equal((await call(base, `/coach-requests/${fullRequest.body.data.id}`,
        m[1], 'DELETE')).status, 200);

      const ended = await call(base, `/relationships/${relationshipId}/terminations`,
        m[0], 'POST', { reason: 'Try another Coach' });
      assert.equal(ended.body.data.status, 'ENDED');
      assert.equal((await call(base, '/relationships/me', m[0])).body.data, null);
      assert.equal((await call(base, '/relationships/me/history', m[0]))
        .body.data[0].id, relationshipId);
      assert.equal((await call(base, '/coaches', m[0])).body.data.find(
        (item) => item.id === coaches[0]).availableSlots, 1);

      const pending = await Promise.all([m[1], m[2]].map((bearer) =>
        call(base, '/coach-requests', bearer, 'POST', { coachId: coaches[0] })));
      assert.deepEqual(pending.map((item) => item.status), [201, 201]);
      const decisions = await Promise.all(pending.map((item) =>
        call(base, `/coach/requests/${item.body.data.id}`, c[0], 'PATCH',
          { decision: 'ACCEPTED' })));
      assert.deepEqual(decisions.map((item) => item.status).sort(), [200, 409]);
      assert.equal(decisions.find((item) => item.status === 409).body.error.code,
        'COACH_FULL');
      assert.equal((await database.query(
        `SELECT count(*)::int AS count FROM coach_relationships
         WHERE coach_id = $1 AND status IN ('ACTIVE', 'PAUSED')`,
        [coaches[0]])).rows[0].count, 1);
      assert.equal((await call(base, '/coach-requests/me', m[0])).body.data.length, 3);
      assert.equal((await call(base, '/coach-requests/me', c[0])).status, 403);
    } finally {
      await database.query(
        `DELETE FROM conversation_participants WHERE conversation_id IN
         (SELECT c.id FROM conversations c JOIN coach_relationships r
          ON r.id = c.relationship_id WHERE r.member_id = ANY($1::uuid[]))`, [members],
      );
      await database.query(
        `DELETE FROM conversations WHERE relationship_id IN
         (SELECT id FROM coach_relationships WHERE member_id = ANY($1::uuid[]))`, [members],
      );
      await database.query(
        'DELETE FROM coach_relationships WHERE member_id = ANY($1::uuid[])', [members],
      );
      await database.query('DELETE FROM coach_requests WHERE member_id = ANY($1::uuid[])',
        [members]);
      await database.query(
        'DELETE FROM member_memberships WHERE member_id = ANY($1::uuid[])', [members],
      );
      await database.query('DELETE FROM payments WHERE member_id = ANY($1::uuid[])',
        [members]);
      await database.query('DELETE FROM membership_plans WHERE id = $1', [planId]);
      await database.query('DELETE FROM coach_profiles WHERE user_id = ANY($1::uuid[])',
        [coaches]);
      await database.query('DELETE FROM users WHERE id = ANY($1::uuid[])',
        [[adminId, ...members, ...coaches]]);
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });
