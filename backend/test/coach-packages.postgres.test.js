import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'coach-package-test-secret-32-characters';

function token(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, secret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
    subject: id, expiresIn: 3600,
  });
}

async function call(base, path, bearer, method = 'GET', body) {
  const response = await fetch(`${base}/api/v1${path}`, {
    method,
    headers: { ...(bearer ? { authorization: `Bearer ${bearer}` } : {}),
      ...(body === undefined ? {} : { 'content-type': 'application/json' }) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: response.status, body: await response.json() };
}

test('Admin prices three fixed Coach packages; public sees active offers only',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const server = createApp({ database, jwtSecret: secret }).listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;
    const adminId = randomUUID();
    const memberId = randomUUID();
    const admin = token(adminId, 'ADMIN');
    const member = token(memberId, 'MEMBER');
    try {
      for (const [id, role] of [[adminId, 'ADMIN'], [memberId, 'MEMBER']]) {
        await database.query(
          `INSERT INTO users (id, email, password_hash, role, full_name)
           VALUES ($1, $2, 'hash', $3, $4)`,
          [id, `${id}@example.com`, role, role],
        );
      }
      assert.equal((await call(base, '/admin/coach-packages', member)).status, 403);
      const all = await call(base, '/admin/coach-packages', admin);
      assert.equal(all.status, 200);
      assert.deepEqual(all.body.data.map((item) =>
        [item.code, item.sessionCount, item.durationDays]), [
        ['BASIC', 10, 30], ['STANDARD', 20, 60], ['ADVANCED', 30, 90],
      ]);
      assert.equal((await call(base, '/coach-packages')).body.data.length, 0);
      const path = '/admin/coach-packages/BASIC';
      assert.equal((await call(base, path, admin, 'PATCH',
        { sessionCount: 0 })).status, 422);
      const updated = await call(base, path, admin, 'PATCH',
        { price: 1500000, status: 'ACTIVE', sessionCount: 12 });
      assert.equal(updated.status, 200);
      assert.equal(updated.body.data.price, 1500000);
      assert.equal(updated.body.data.sessionCount, 12);
      assert.equal((await call(base, '/coach-packages')).body.data[0].code, 'BASIC');
      const audit = await database.query(
        `SELECT metadata FROM admin_audit_logs
         WHERE admin_id = $1 AND action = 'COACH_PACKAGE_UPDATED'`, [adminId],
      );
      assert.equal(audit.rows[0].metadata.after.price, 1500000);
    } finally {
      await database.query(
        `UPDATE coach_package_plans SET price = 0, status = 'INACTIVE', session_count = 10
         WHERE code = 'BASIC'`,
      );
      await database.query('DELETE FROM admin_audit_logs WHERE admin_id = $1',
        [adminId]);
      await database.query('DELETE FROM users WHERE id = ANY($1::uuid[])',
        [[adminId, memberId]]);
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });
