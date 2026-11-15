import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'self-training-integration-secret-32-chars';

function token(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, secret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
    subject: id, expiresIn: 3600,
  });
}

async function call(app, path, method, bearer, body) {
  const server = app.listen(0);
  try {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/api/v1${path}`, {
      method,
      headers: { authorization: `Bearer ${bearer}`,
        ...(body === undefined ? {} : { 'content-type': 'application/json' }) },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    return { status: response.status, body: await response.json() };
  } finally { await new Promise((resolve) => server.close(resolve)); }
}

test('Member self schedule is private, editable today and locked for past days',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const memberId = randomUUID();
    const otherId = randomUUID();
    const adminId = randomUUID();
    const exerciseId = randomUUID();
    const app = createApp({ database, jwtSecret: secret });
    const date = (offset) => new Date(Date.now() + offset * 86400000)
      .toLocaleDateString('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' });
    const today = date(0);
    const past = date(-1);
    const member = token(memberId, 'MEMBER');
    const other = token(otherId, 'MEMBER');
    const admin = token(adminId, 'ADMIN');
    const payload = { title: 'Ngực và vai', startTime: '17:30', notes: 'Khởi động',
      exerciseIds: [exerciseId] };
    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'MEMBER', 'Member'),
                ($3, $4, 'hash', 'MEMBER', 'Other'),
                ($5, $6, 'hash', 'ADMIN', 'Admin')`,
        [memberId, `${memberId}@example.com`, otherId, `${otherId}@example.com`,
          adminId, `${adminId}@example.com`],
      );
      await database.query(
        `INSERT INTO exercises (id, name, instructions, status, created_by)
         VALUES ($1, 'Đẩy ngực', 'Hướng dẫn', 'ACTIVE', $2)`, [exerciseId, adminId],
      );
      assert.equal((await call(app, `/member/self-training-days/${today}`, 'PUT',
        admin, payload)).status, 403);
      assert.equal((await call(app, `/member/self-training-days/${past}`, 'PUT',
        member, payload)).status, 409);
      assert.equal((await call(app, `/member/self-training-days/${today}`, 'PUT',
        member, { ...payload, exerciseIds: [] })).status, 422);
      let result = await call(app, `/member/self-training-days/${today}`, 'PUT',
        member, payload);
      assert.equal(result.status, 200);
      assert.equal(result.body.data.title, payload.title);
      assert.deepEqual(result.body.data.exercises,
        [{ id: exerciseId, name: 'Đẩy ngực' }]);
      result = await call(app, `/member/self-training-days?from=${today}&to=${today}`,
        'GET', other);
      assert.deepEqual(result.body.data, []);
      result = await call(app, `/member/self-training-days/${today}`, 'PUT', member,
        { ...payload, title: 'Tập thân trên' });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.title, 'Tập thân trên');
      result = await call(app, `/member/self-training-days?from=${today}&to=${today}`,
        'GET', member);
      assert.equal(result.body.data.length, 1);
      assert.equal(result.body.data[0].title, 'Tập thân trên');
      assert.equal((await call(app, `/member/self-training-days/${past}`, 'DELETE',
        member)).status, 409);
      assert.equal((await call(app, `/member/self-training-days/${today}`, 'DELETE',
        member)).status, 200);
    } finally {
      await database.query('DELETE FROM member_self_training_days WHERE member_id = $1',
        [memberId]);
      await database.query('DELETE FROM exercises WHERE id = $1', [exerciseId]);
      await database.query('DELETE FROM users WHERE id IN ($1, $2, $3)',
        [memberId, otherId, adminId]);
      await database.end();
    }
  });
