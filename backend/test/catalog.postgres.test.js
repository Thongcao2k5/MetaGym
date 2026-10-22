import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'catalog-integration-secret-with-32-characters';

function token(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, secret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
    subject: id, expiresIn: 3600,
  });
}

async function call(app, path, method = 'GET', bearer, body) {
  const server = app.listen(0);
  try {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/api/v1${path}`, {
      method,
      headers: { ...(bearer ? { authorization: `Bearer ${bearer}` } : {}),
        ...(body === undefined ? {} : { 'content-type': 'application/json' }) },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    return { status: response.status, body: await response.json() };
  } finally { await new Promise((resolve) => server.close(resolve)); }
}

test('PostgreSQL catalog API filters hidden items and protects admin mutations',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const adminId = randomUUID();
    const memberId = randomUUID();
    const app = createApp({ database, jwtSecret: secret });
    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Admin'),
                ($3, $4, 'hash', 'MEMBER', 'Member')`,
        [adminId, `${adminId}@example.com`, memberId, `${memberId}@example.com`],
      );
      const admin = token(adminId, 'ADMIN');
      const member = token(memberId, 'MEMBER');
      await database.query(
        `INSERT INTO gym_profile (id, name, address, opening_hours, updated_by)
         VALUES (1, 'Meta Gym', 'Hanoi', '{}'::jsonb, $1)`, [adminId],
      );
      assert.equal((await call(app, '/gym-profile')).body.data.name, 'Meta Gym');
      assert.equal((await call(app, '/admin/gym-profile', 'PATCH', member,
        { name: 'Wrong' })).status, 403);
      let result = await call(app, '/admin/gym-profile', 'PATCH', admin,
        { openingHours: { monday: '06:00-21:00' } });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.openingHours.monday, '06:00-21:00');
      result = await call(app, '/admin/equipment', 'POST', admin, {
        name: 'Treadmill', category: 'Cardio', targetMuscles: ['Legs'],
        usageSteps: ['Warm up', 'Walk'], status: 'ACTIVE',
      });
      assert.equal(result.status, 201);
      const equipmentId = result.body.data.id;
      assert.deepEqual(result.body.data.targetMuscles, ['Legs']);
      result = await call(app, '/equipment?search=Tread&category=Cardio');
      assert.equal(result.status, 200);
      assert.equal(result.body.pagination.totalItems, 1);
      assert.equal(result.body.data[0].id, equipmentId);
      result = await call(app, '/admin/exercises', 'POST', admin, {
        equipmentId, name: 'Walk', instructions: 'Walk safely',
        targetMuscles: ['Legs'], difficulty: 'BEGINNER',
      });
      assert.equal(result.status, 201);
      const exerciseId = result.body.data.id;
      assert.equal((await call(app, '/exercises')).status, 401);
      assert.equal((await call(app, '/exercises', 'GET', member)).body.data.length, 1);
      assert.equal((await call(app, `/admin/exercises/${exerciseId}`, 'PATCH', member,
        { status: 'HIDDEN' })).status, 403);
      assert.equal((await call(app, `/admin/exercises/${exerciseId}`, 'PATCH', admin,
        { status: 'HIDDEN' })).status, 200);
      assert.equal((await call(app, '/exercises', 'GET', member)).body.data.length, 0);
      assert.equal((await call(app, '/admin/exercises', 'GET', member)).status, 403);
      const adminExercises = await call(app, '/admin/exercises', 'GET', admin);
      assert.equal(adminExercises.status, 200);
      assert.equal(adminExercises.body.data[0].id, exerciseId);
      assert.equal(adminExercises.body.data[0].status, 'HIDDEN');
      assert.equal((await call(app, `/exercises/${exerciseId}`, 'GET', member)).status, 404);
      assert.equal((await call(app, '/admin/equipment', 'POST', admin,
        { name: 'Invalid', category: 'Cardio', usageSteps: [] })).status, 422);
      assert.equal((await database.query('SELECT count(*)::int AS n FROM admin_audit_logs WHERE admin_id = $1',
        [adminId])).rows[0].n, 4);
    } finally {
      await database.query('DELETE FROM admin_audit_logs WHERE admin_id = $1', [adminId]);
      await database.query('DELETE FROM exercises WHERE created_by = $1', [adminId]);
      await database.query('DELETE FROM equipment WHERE created_by = $1', [adminId]);
      await database.query('DELETE FROM gym_profile WHERE updated_by = $1', [adminId]);
      await database.query('DELETE FROM users WHERE id IN ($1, $2)', [adminId, memberId]);
      await database.end();
    }
  });
