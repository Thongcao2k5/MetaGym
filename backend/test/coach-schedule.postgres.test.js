import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'coach-schedule-test-secret-32-characters';

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

test('Coach weekly schedule requires six days of contiguous 90-minute slots',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const server = createApp({ database, jwtSecret: secret }).listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;
    const coachId = randomUUID();
    const memberId = randomUUID();
    const coach = token(coachId, 'COACH');
    const member = token(memberId, 'MEMBER');
    const schedule = { days: Array.from({ length: 6 }, (_, index) => ({
      weekday: index + 1, starts: ['06:00', '07:30', '09:00', '10:30'],
    })) };
    try {
      for (const [id, role] of [[coachId, 'COACH'], [memberId, 'MEMBER']]) {
        await database.query(
          `INSERT INTO users (id, email, password_hash, role, full_name)
           VALUES ($1, $2, 'hash', $3, $4)`,
          [id, `${id}@example.com`, role, role],
        );
      }
      const path = `/coaches/${coachId}/work-slots`;
      assert.deepEqual((await call(base, path)).body.data,
        { days: [], configured: false });
      assert.equal((await call(base, '/coach/work-slots', member, 'PUT', schedule))
        .status, 403);
      assert.equal((await call(base, '/coach/work-slots', coach, 'PUT',
        { days: schedule.days.slice(0, 5) })).status, 422);
      assert.equal((await call(base, '/coach/work-slots', coach, 'PUT',
        { days: [...schedule.days.slice(0, 5), schedule.days[0]] })).status, 422);
      assert.equal((await call(base, '/coach/work-slots', coach, 'PUT',
        { days: schedule.days.map((day) => ({ ...day,
          starts: ['06:00', '07:30', '09:30', '11:00'] })) })).status, 422);
      const saved = await call(base, '/coach/work-slots', coach, 'PUT', schedule);
      assert.equal(saved.status, 200);
      assert.equal(saved.body.data.configured, true);
      assert.equal(saved.body.data.days.length, 6);
      assert.deepEqual((await call(base, path)).body.data.days[0].starts,
        schedule.days[0].starts);
      const count = await database.query(
        'SELECT count(*)::int AS count FROM coach_weekly_slots WHERE coach_id = $1',
        [coachId],
      );
      assert.equal(count.rows[0].count, 24);
      await assert.rejects(database.query(
        `INSERT INTO coach_weekly_slots (id, coach_id, weekday, start_minute)
         VALUES ($1, $2, 1, 405)`, [randomUUID(), coachId],
      ), { code: '23P01' });
    } finally {
      await database.query('DELETE FROM coach_weekly_slots WHERE coach_id = $1',
        [coachId]);
      await database.query('DELETE FROM users WHERE id = ANY($1::uuid[])',
        [[coachId, memberId]]);
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });
