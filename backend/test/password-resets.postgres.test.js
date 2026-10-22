import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'password-reset-integration-secret-32-characters';

async function call(app, path, body, bearer) {
  const server = app.listen(0);
  try {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/api/v1${path}`, {
      method: 'POST', headers: { 'content-type': 'application/json',
        ...(bearer ? { authorization: `Bearer ${bearer}` } : {}) },
      body: JSON.stringify(body),
    });
    return { status: response.status, body: await response.json() };
  } finally { await new Promise((resolve) => server.close(resolve)); }
}

test('PostgreSQL password reset codes expire by use, limit attempts, and revoke JWTs',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const userId = randomUUID();
    let delivery;
    const app = createApp({ database, jwtSecret: secret,
      sendPasswordResetCode: async (message) => { delivery = message; } });
    const withoutEmail = createApp({ database, jwtSecret: secret });
    try {
      const oldHash = await bcrypt.hash('OldPassword1', 12);
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, $3, 'MEMBER', 'Password Member')`,
        [userId, `${userId}@example.com`, oldHash],
      );
      const oldToken = jwt.sign({ role: 'MEMBER', sessionVersion: 0 }, secret, {
        algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
        subject: userId, expiresIn: 3600,
      });
      let result = await call(withoutEmail, '/password-reset-requests',
        { email: `${userId}@example.com` });
      assert.equal(result.status, 503);
      result = await call(app, '/password-reset-requests',
        { email: ` ${userId.toUpperCase()}@EXAMPLE.COM ` });
      assert.equal(result.status, 202);
      const requestId = result.body.data.requestId;
      assert.equal(delivery.requestId, requestId);
      assert.equal(JSON.stringify(result.body).includes(delivery.code), false);
      assert.equal((await call(app, '/password-reset-verifications',
        { requestId, code: 'xxxxxx' })).status, 422);
      const wrong = delivery.code === '000000' ? '000001' : '000000';
      assert.equal((await call(app, '/password-reset-verifications',
        { requestId, code: wrong })).status, 401);
      assert.equal((await call(app, '/password-reset-verifications',
        { requestId, code: delivery.code })).body.data.valid, true);
      result = await call(app, '/password-resets',
        { requestId, code: delivery.code, newPassword: 'NewPassword1' });
      assert.equal(result.status, 200);
      assert.equal((await call(app, '/password-resets',
        { requestId, code: delivery.code, newPassword: 'AnotherPass1' })).status, 401);
      const stored = await database.query(
        'SELECT password_hash, session_version FROM users WHERE id = $1', [userId],
      );
      assert.equal(await bcrypt.compare('NewPassword1', stored.rows[0].password_hash), true);
      assert.equal(stored.rows[0].session_version, 1);
      const server = app.listen(0);
      try {
        const me = await fetch(`http://127.0.0.1:${server.address().port}/api/v1/users/me`, {
          headers: { authorization: `Bearer ${oldToken}` },
        });
        assert.equal(me.status, 401);
      } finally { await new Promise((resolve) => server.close(resolve)); }
      result = await call(app, '/password-reset-requests',
        { email: `${randomUUID()}@example.com` });
      assert.equal(result.status, 202);
      assert.ok(result.body.data.requestId);
      result = await call(app, '/password-reset-requests',
        { email: `${userId}@example.com` });
      assert.equal(result.status, 202);
      const secondRequestId = result.body.data.requestId;
      const secondWrong = delivery.code === '000000' ? '000001' : '000000';
      for (let attempt = 0; attempt < 5; attempt += 1) {
        assert.equal((await call(app, '/password-reset-verifications',
          { requestId: secondRequestId, code: secondWrong })).status, 401);
      }
      assert.equal((await call(app, '/password-reset-verifications',
        { requestId: secondRequestId, code: delivery.code })).status, 401);
      assert.equal((await call(app, '/password-reset-requests',
        { email: `${userId}@example.com` })).status, 429);
    } finally {
      await database.query('DELETE FROM password_reset_codes WHERE user_id = $1', [userId]);
      await database.query('DELETE FROM auth_password_reset_rate_limits');
      await database.query('DELETE FROM users WHERE id = $1', [userId]);
      await database.end();
    }
  });
