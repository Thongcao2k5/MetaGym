import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const { Pool } = pg;
const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'test-only-users-route-secret-with-32-plus-characters';

async function request(app, path, token, method = 'GET', body) {
  const server = app.listen(0);
  try {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/api/v1${path}`, {
      method,
      headers: {
        authorization: `Bearer ${token}`,
        ...(body === undefined ? {} : { 'content-type': 'application/json' }),
      },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    return { status: response.status, body: await response.json() };
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

function token(id, role = 'MEMBER', version = 0) {
  return jwt.sign({ role, sessionVersion: version }, secret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
    subject: id, expiresIn: 3600,
  });
}

test('PostgreSQL users API: profile ownership, role fields, and password revocation',
  { skip: !databaseUrl }, async () => {
    const database = new Pool({ connectionString: databaseUrl });
    const memberId = randomUUID();
    const coachId = randomUUID();
    const initialHash = await bcrypt.hash('InitialPass1', 4);
    const app = createApp({ database, jwtSecret: secret });
    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, $3, 'MEMBER', 'Member'),
                ($4, $5, $3, 'COACH', 'Coach')`,
        [memberId, `${memberId}@example.com`, initialHash, coachId, `${coachId}@example.com`],
      );
      await database.query('INSERT INTO member_profiles (user_id) VALUES ($1)', [memberId]);
      await database.query(
        'INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 8)', [coachId],
      );

      const memberToken = token(memberId);
      const coachToken = token(coachId, 'COACH');
      let response = await request(app, '/users/me', memberToken);
      assert.equal(response.status, 200);
      assert.equal(response.body.data.id, memberId);
      assert.equal(response.body.data.profile.fitnessGoal, null);
      assert.equal(JSON.stringify(response.body).includes('password_hash'), false);

      response = await request(app, '/users/me', memberToken, 'PATCH', {
        fullName: '  Updated Member  ', phone: null,
        dateOfBirth: '2001-07-04', heightCm: 178.5,
        fitnessGoal: 'Strength', healthNotes: 'Private note',
      });
      assert.equal(response.status, 200);
      assert.equal(response.body.data.fullName, 'Updated Member');
      assert.equal(response.body.data.profile.dateOfBirth, '2001-07-04');
      assert.equal(response.body.data.profile.heightCm, 178.5);
      assert.equal(response.body.data.profile.healthNotes, 'Private note');

      response = await request(app, '/users/me', coachToken, 'PATCH', {
        biography: 'Coach biography', specialties: ['Strength'], experienceYears: 4,
      });
      assert.equal(response.status, 200);
      assert.deepEqual(response.body.data.profile.specialties, ['Strength']);
      assert.equal(response.body.data.profile.experienceYears, 4);
      assert.equal(JSON.stringify(response.body).includes('healthNotes'), false);

      response = await request(app, '/users/me', memberToken, 'PATCH', { role: 'ADMIN' });
      assert.equal(response.status, 422);
      response = await request(app, '/users/me', coachToken, 'PATCH', { memberLimit: 100 });
      assert.equal(response.status, 422);
      response = await request(app, '/users/me/password', memberToken, 'PATCH', {
        currentPassword: 'WrongPass1', newPassword: 'ReplacementPass1',
      });
      assert.equal(response.status, 401);
      assert.equal((await request(app, '/users/me', memberToken)).status, 200);

      response = await request(app, '/users/me/password', memberToken, 'PATCH', {
        currentPassword: 'InitialPass1', newPassword: 'ReplacementPass1',
      });
      assert.equal(response.status, 200);
      assert.deepEqual(response.body, { data: { changed: true } });
      assert.equal((await request(app, '/users/me', memberToken)).status, 401);
      assert.equal((await request(app, '/users/me', token(memberId, 'MEMBER', 1))).status, 200);
      const saved = await database.query('SELECT password_hash, session_version FROM users WHERE id = $1', [memberId]);
      assert.equal(saved.rows[0].session_version, 1);
      assert.equal(await bcrypt.compare('ReplacementPass1', saved.rows[0].password_hash), true);
      assert.equal(await bcrypt.compare('InitialPass1', saved.rows[0].password_hash), false);

      await database.query(
        `UPDATE users SET status = 'DISABLED', disabled_at = now(),
         disabled_reason = 'Test account lock' WHERE id = $1`, [memberId],
      );
      assert.equal((await request(app, '/users/me', token(memberId, 'MEMBER', 1))).status, 401);
      assert.equal((await request(app, '/users/me', token(coachId, 'ADMIN'))).status, 401);
      assert.equal((await request(app, '/users/me', 'not-a-jwt')).status, 401);
    } finally {
      await database.query('DELETE FROM member_profiles WHERE user_id = $1', [memberId]);
      await database.query('DELETE FROM coach_profiles WHERE user_id = $1', [coachId]);
      await database.query('DELETE FROM users WHERE id IN ($1, $2)', [memberId, coachId]);
      await database.end();
    }
  });

test('PostgreSQL users API: simultaneous password changes only update once',
  { skip: !databaseUrl }, async () => {
    const database = new Pool({ connectionString: databaseUrl });
    const id = randomUUID();
    const app = createApp({ database, jwtSecret: secret });
    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, $3, 'MEMBER', 'Concurrent Member')`,
        [id, `${id}@example.com`, await bcrypt.hash('InitialPass1', 4)],
      );
      await database.query('INSERT INTO member_profiles (user_id) VALUES ($1)', [id]);
      const oldToken = token(id);
      const responses = await Promise.all([
        request(app, '/users/me/password', oldToken, 'PATCH', {
          currentPassword: 'InitialPass1', newPassword: 'FirstReplacement1',
        }),
        request(app, '/users/me/password', oldToken, 'PATCH', {
          currentPassword: 'InitialPass1', newPassword: 'SecondReplacement1',
        }),
      ]);
      assert.deepEqual(responses.map(({ status }) => status).sort(), [200, 401]);
      const saved = await database.query('SELECT password_hash, session_version FROM users WHERE id = $1', [id]);
      assert.equal(saved.rows[0].session_version, 1);
      assert.equal((await request(app, '/users/me', oldToken)).status, 401);
      assert.equal((await request(app, '/users/me', token(id, 'MEMBER', 1))).status, 200);
    } finally {
      await database.query('DELETE FROM member_profiles WHERE user_id = $1', [id]);
      await database.query('DELETE FROM users WHERE id = $1', [id]);
      await database.end();
    }
  });
