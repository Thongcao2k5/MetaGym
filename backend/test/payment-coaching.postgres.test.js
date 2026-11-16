import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'payment-coaching-integration-secret-32-chars';

function token(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, secret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
    subject: id, expiresIn: 3600,
  });
}

async function call(base, path, bearer, method = 'GET', body, key) {
  const response = await fetch(`${base}/api/v1${path}`, {
    method,
    headers: { authorization: `Bearer ${bearer}`,
      ...(key ? { 'idempotency-key': key } : {}),
      ...(body === undefined ? {} : { 'content-type': 'application/json' }) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: response.status, body: await response.json() };
}

test('PostgreSQL payment and coaching flow preserves ownership, capacity and history',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const app = createApp({ database, jwtSecret: secret, enableLegacyWrites: true });
    const server = app.listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;
    const adminId = randomUUID();
    const memberId = randomUUID();
    const otherId = randomUUID();
    const coachId = randomUUID();
    const planId = randomUUID();
    const dayPlanId = randomUUID();
    const yearPlanId = randomUUID();
    const admin = token(adminId, 'ADMIN');
    const member = token(memberId, 'MEMBER');
    const other = token(otherId, 'MEMBER');
    const coach = token(coachId, 'COACH');
    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Admin'),
                ($3, $4, 'hash', 'MEMBER', 'Member'),
                ($5, $6, 'hash', 'MEMBER', 'Other'),
                ($7, $8, 'hash', 'COACH', 'Coach')`,
        [adminId, `${adminId}@example.com`, memberId, `${memberId}@example.com`,
          otherId, `${otherId}@example.com`, coachId, `${coachId}@example.com`],
      );
      await database.query(
        `INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 1)`, [coachId],
      );
      await database.query(
        `INSERT INTO membership_plans
         (id, name, price, duration_days, status, created_by)
         VALUES ($1, 'Monthly', 100000, 30, 'ACTIVE', $2)`, [planId, adminId],
      );
      assert.equal((await call(base, '/admin/membership-plans', member)).status, 403);
      assert.equal((await call(base, '/admin/membership-plans', admin)).body.data[0].id,
        planId);
      assert.equal((await call(base, '/coach-requests', member, 'POST',
        { coachId })).status, 403);
      assert.equal((await call(base, '/payments', coach, 'POST',
        { planId }, randomUUID())).status, 403);
      const quote = await call(base, `/membership-plans/${planId}/quote`, member);
      assert.equal(quote.status, 200, JSON.stringify(quote.body));
      assert.equal(quote.body.data.price, 100000);
      assert.equal(quote.body.data.durationDays, 30);
      const key = randomUUID();
      const created = await call(base, '/payments', member, 'POST', { planId }, key);
      assert.equal(created.status, 201, JSON.stringify(created.body));
      const paymentId = created.body.data.id;
      assert.equal(created.body.data.status, 'PENDING');
      assert.equal((await call(base, '/payments', member, 'POST', { planId }, key))
        .body.data.id, paymentId);
      const abandoned = await call(base, '/payments', member, 'POST', { planId }, randomUUID());
      assert.equal(abandoned.status, 201);
      const cancelPath = `/payments/${abandoned.body.data.id}/cancellations`;
      assert.equal((await call(base, cancelPath, other, 'POST')).status, 404);
      for (let attempt = 0; attempt < 2; attempt += 1) {
        const cancellation = await call(base, cancelPath, member, 'POST');
        assert.equal(cancellation.status, 200);
        assert.equal(cancellation.body.data.status, 'CANCELLED');
      }
      assert.equal((await call(base, `/payments/${abandoned.body.data.id}/mock-confirmations`,
        member, 'POST')).status, 409);
      assert.equal((await call(base, `/payments/${paymentId}`, other)).status, 404);
      assert.equal((await call(base, `/payments/${paymentId}/mock-confirmations`, other,
        'POST', {})).status, 404);
      assert.equal((await call(base, `/admin/membership-plans/${planId}`, admin,
        'PATCH', { price: 200000 })).status, 200);
      const confirmations = await Promise.all(Array.from({ length: 2 }, () =>
        call(base, `/payments/${paymentId}/mock-confirmations`, member, 'POST', {})));
      assert.deepEqual(confirmations.map((r) => r.status), [200, 200]);
      assert.equal(confirmations[0].body.data.membership.id,
        confirmations[1].body.data.membership.id);
      assert.equal(confirmations[0].body.data.payment.amount, 100000);
      assert.deepEqual(
        [confirmations[0].body.data.membership.startDate, confirmations[0].body.data.membership.endDate],
        [quote.body.data.startDate, quote.body.data.endDate],
      );
      assert.equal((await database.query(
        'SELECT count(*)::int AS count FROM member_memberships WHERE source_payment_id = $1',
        [paymentId])).rows[0].count, 1);
      const second = await call(base, '/payments', member, 'POST', { planId }, randomUUID());
      assert.equal(second.status, 201);
      assert.equal(second.body.data.amount, 200000);
      const extended = await call(base, `/payments/${second.body.data.id}/mock-confirmations`,
        member, 'POST', {});
      assert.equal(extended.status, 200);
      assert.equal(extended.body.data.membership.status, 'SCHEDULED');
      const dates = (await database.query(
        `SELECT start_date::text, end_date::text FROM member_memberships
         WHERE member_id = $1 ORDER BY start_date`, [memberId])).rows;
      const dayAfter = new Date(`${dates[0].end_date}T00:00:00Z`);
      dayAfter.setUTCDate(dayAfter.getUTCDate() + 1);
      assert.equal(dates[1].start_date, dayAfter.toISOString().slice(0, 10));
      await database.query(
        `INSERT INTO membership_plans (id, name, price, duration_days, status, created_by)
         VALUES ($1, 'Day', 60000, 1, 'ACTIVE', $3), ($2, 'Year', 5000000, 365, 'ACTIVE', $3)`,
        [dayPlanId, yearPlanId, adminId],
      );
      const dayQuote = await call(base, `/membership-plans/${dayPlanId}/quote`, member);
      assert.equal(dayQuote.status, 200);
      assert.equal(dayQuote.body.data.startDate, dayQuote.body.data.endDate);
      const intents = await Promise.all([dayPlanId, yearPlanId].map((planId) =>
        call(base, '/payments', member, 'POST', { planId }, randomUUID())));
      assert.deepEqual(intents.map((intent) => intent.status), [201, 201]);
      const renewals = await Promise.all(intents.map(({ body }) =>
        call(base, `/payments/${body.data.id}/mock-confirmations`, member, 'POST', {})));
      assert.deepEqual(renewals.map((renewal) => renewal.status), [200, 200]);
      const queued = (await call(base, '/memberships/me', member)).body.data;
      assert.equal(queued.length, 4);
      for (let i = 1; i < queued.length; i += 1) {
        const nextDay = new Date(`${queued[i - 1].endDate}T00:00:00Z`);
        nextDay.setUTCDate(nextDay.getUTCDate() + 1);
        assert.equal(queued[i].startDate, nextDay.toISOString().slice(0, 10));
      }
      for (const [i, duration] of [1, 365].entries()) {
        const { startDate, endDate } = renewals[i].body.data.membership;
        assert.equal((Date.parse(endDate) - Date.parse(startDate)) / 86400000 + 1, duration);
      }
      const requested = await call(base, '/coach-requests', member, 'POST', { coachId });
      assert.equal(requested.status, 201, JSON.stringify(requested.body));
      assert.equal((await call(base, '/coach-requests', member, 'POST',
        { coachId })).status, 409);
      assert.equal((await call(base, `/coach/requests/${requested.body.data.id}`, other)).status,
        403);
      const accepted = await call(base, `/coach/requests/${requested.body.data.id}`,
        coach, 'PATCH', { decision: 'ACCEPTED' });
      assert.equal(accepted.status, 200, JSON.stringify(accepted.body));
      const relationshipId = accepted.body.data.relationship.id;
      assert.equal((await call(base, `/coach/requests/${requested.body.data.id}`, coach,
        'PATCH', { decision: 'ACCEPTED' })).status, 404);
      assert.equal((await call(base, '/coaches', member)).body.data.find(
        (item) => item.id === coachId).availableSlots, 0);
      assert.equal((await call(base, '/coach-requests', member, 'POST',
        { coachId })).status, 409);
      const ended = await call(base, `/relationships/${relationshipId}/terminations`,
        member, 'POST', { reason: 'Changing goals' });
      assert.equal(ended.status, 200, JSON.stringify(ended.body));
      assert.equal(ended.body.data.status, 'ENDED');
      assert.equal((await call(base, '/relationships/me/history', member)).body.data[0].id,
        relationshipId);
      assert.equal((await call(base, '/coaches', member)).body.data.find(
        (item) => item.id === coachId).availableSlots, 1);
    } finally {
      await database.query('DELETE FROM conversation_participants WHERE user_id IN ($1, $2)',
        [memberId, coachId]);
      await database.query(`DELETE FROM conversations WHERE relationship_id IN
        (SELECT id FROM coach_relationships WHERE member_id = $1)`, [memberId]);
      await database.query('DELETE FROM coach_relationships WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM coach_requests WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM member_memberships WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM payments WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM membership_plans WHERE id IN ($1, $2, $3)', [planId, dayPlanId, yearPlanId]);
      await database.query('DELETE FROM coach_profiles WHERE user_id = $1', [coachId]);
      await database.query('DELETE FROM admin_audit_logs WHERE admin_id = $1', [adminId]);
      await database.query('DELETE FROM users WHERE id IN ($1, $2, $3, $4)',
        [adminId, memberId, otherId, coachId]);
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });
