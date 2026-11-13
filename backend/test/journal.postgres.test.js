import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'journal-integration-test-secret-32-characters';

function token(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, secret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
    subject: id, expiresIn: 3600,
  });
}

async function call(base, path, bearer, method = 'GET', body) {
  const result = await fetch(`${base}/api/v1${path}`, {
    method, headers: { authorization: `Bearer ${bearer}`,
      ...(body === undefined ? {} : { 'content-type': 'application/json' }) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: result.status, body: result.status === 204 ? null : await result.json() };
}

test('PostgreSQL journal is private, unique per day and read-only after gym expiry',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const server = createApp({ database, jwtSecret: secret }).listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;
    const adminId = randomUUID();
    const memberId = randomUUID();
    const otherId = randomUUID();
    const coachId = randomUUID();
    const planId = randomUUID();
    const paymentId = randomUUID();
    const membershipId = randomUUID();
    const photoIds = [randomUUID(), randomUUID()];
    const member = token(memberId, 'MEMBER');
    const other = token(otherId, 'MEMBER');
    const coach = token(coachId, 'COACH');
    const admin = token(adminId, 'ADMIN');
    try {
      for (const [id, role] of [[adminId, 'ADMIN'], [memberId, 'MEMBER'],
        [otherId, 'MEMBER'], [coachId, 'COACH']]) {
        await database.query(
          `INSERT INTO users (id, email, password_hash, role, full_name)
           VALUES ($1, $2, 'hash', $3, 'Journal fixture')`,
          [id, `${id}@example.com`, role],
        );
      }
      await database.query(
        `INSERT INTO membership_plans (id, name, price, duration_days, status, created_by)
         VALUES ($1, 'Journal', 100000, 30, 'ACTIVE', $2)`, [planId, adminId],
      );
      await database.query(
        `INSERT INTO payments
         (id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
          amount, method, status, transaction_code, idempotency_key,
          request_hash, created_by, confirmed_at, decided_at)
         VALUES ($1, $2, $3, 'Journal', 30, 100000, 'MOCK_QR', 'SUCCESS',
                 $4, $5, repeat('a', 64), $2, now(), now())`,
        [paymentId, memberId, planId, randomUUID(), randomUUID()],
      );
      await database.query(
        `INSERT INTO member_memberships
         (id, member_id, plan_id, source_payment_id, start_date, end_date,
          status, activated_at)
         VALUES ($1, $2, $3, $4,
          (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
          (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 29,
          'ACTIVE', now())`,
        [membershipId, memberId, planId, paymentId],
      );
      for (const id of photoIds) {
        await database.query(
          `INSERT INTO media_assets
           (id, owner_id, purpose, access_scope, storage_key, original_name,
            expires_at, status, mime_type, size_bytes, width, height, ready_at)
           VALUES ($1, $2, 'PROGRESS_PHOTO', 'PRIVATE', $3, 'journal.png',
                   now() + interval '15 minutes', 'READY', 'image/png', 10, 2, 2, now())`,
          [id, memberId, randomUUID()],
        );
      }
      assert.equal((await call(base, '/journal', coach)).status, 403);
      assert.equal((await call(base, '/journal', admin)).status, 403);
      assert.equal((await call(base, '/journal', other)).body.data.length, 0);
      assert.equal((await call(base, '/journal', other, 'POST', {})).status, 403);
      assert.equal((await call(base, '/journal', member, 'POST', {
        photoMediaIds: [photoIds[0], photoIds[0]],
      })).status, 422);
      assert.equal((await call(base, '/journal', member, 'POST', {
        photoMediaIds: [randomUUID()],
      })).status, 422);
      const created = await call(base, '/journal', member, 'POST', {
        notes: 'Tập thân trên', chestCm: 90.5,
        achievements: [{ title: 'Hít đất', result: '20 lần' }],
        photoMediaIds: photoIds,
      });
      assert.equal(created.status, 201, JSON.stringify(created.body));
      const id = created.body.data.id;
      const today = (await database.query(
        "SELECT (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS today",
      )).rows[0].today;
      assert.equal(created.body.data.journalDate, today);
      assert.deepEqual(created.body.data.photoMediaIds, photoIds);
      assert.equal((await call(base, '/journal', member, 'POST', {})).body.error.code,
        'JOURNAL_EXISTS');
      assert.equal((await call(base, `/journal/${id}`, other)).status, 404);
      assert.equal((await call(base, `/journal/${id}`, coach)).status, 403);
      const updated = await call(base, `/journal/${id}`, member, 'PATCH', {
        waistCm: 75, photoMediaIds: [photoIds[0]],
      });
      assert.equal(updated.status, 200, JSON.stringify(updated.body));
      assert.equal(Number(updated.body.data.waistCm), 75);
      assert.deepEqual(updated.body.data.photoMediaIds, [photoIds[0]]);
      assert.equal((await call(base, `/journal/${id}`, other, 'PATCH',
        { notes: 'No' })).status, 403);
      const chart = await call(base, '/journal/charts', member);
      assert.equal(chart.status, 200);
      assert.equal(chart.body.data.length, 1);
      assert.equal(Number(chart.body.data[0].chestCm), 90.5);
      await database.query(
        `UPDATE member_memberships SET status = 'EXPIRED', expired_at = now()
         WHERE id = $1`, [membershipId],
      );
      assert.equal((await call(base, `/journal/${id}`, member)).status, 200);
      assert.equal((await call(base, `/journal/${id}`, member, 'PATCH',
        { notes: 'No' })).status, 403);
      assert.equal((await call(base, `/journal/${id}`, member, 'DELETE')).status, 403);
      await database.query(
        `UPDATE member_memberships SET status = 'ACTIVE', expired_at = NULL
         WHERE id = $1`, [membershipId],
      );
      assert.equal((await call(base, `/journal/${id}`, member, 'DELETE')).status, 200);
      assert.equal((await call(base, `/journal/${id}`, member)).status, 404);
    } finally {
      await database.query('DELETE FROM member_journal_entries WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM media_assets WHERE owner_id = $1', [memberId]);
      await database.query('DELETE FROM member_memberships WHERE id = $1', [membershipId]);
      await database.query('DELETE FROM payments WHERE id = $1', [paymentId]);
      await database.query('DELETE FROM membership_plans WHERE id = $1', [planId]);
      await database.query('DELETE FROM users WHERE id IN ($1, $2, $3, $4)',
        [adminId, memberId, otherId, coachId]);
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });
