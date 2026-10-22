import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'progress-integration-secret-with-32-characters';

function token(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, secret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
    subject: id, expiresIn: 3600,
  });
}

async function call(base, path, bearer, method = 'GET', body) {
  const response = await fetch(`${base}/api/v1${path}`, {
    method, headers: { authorization: `Bearer ${bearer}`,
      ...(body === undefined ? {} : { 'content-type': 'application/json' }) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: response.status, body: await response.json() };
}

test('PostgreSQL progress logs stay private, paginate and survive relationship end',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const app = createApp({ database, jwtSecret: secret });
    const server = app.listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;
    const adminId = randomUUID();
    const memberId = randomUUID();
    const coachId = randomUUID();
    const outsiderId = randomUUID();
    const planId = randomUUID();
    const paymentId = randomUUID();
    const membershipId = randomUUID();
    const relationshipId = randomUUID();
    const admin = token(adminId, 'ADMIN');
    const member = token(memberId, 'MEMBER');
    const coach = token(coachId, 'COACH');
    const outsider = token(outsiderId, 'COACH');
    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Admin'),
                ($3, $4, 'hash', 'MEMBER', 'Member'),
                ($5, $6, 'hash', 'COACH', 'Coach'),
                ($7, $8, 'hash', 'COACH', 'Outsider')`,
        [adminId, `${adminId}@example.com`, memberId, `${memberId}@example.com`,
          coachId, `${coachId}@example.com`, outsiderId, `${outsiderId}@example.com`],
      );
      await database.query(
        `INSERT INTO membership_plans
         (id, name, price, duration_days, status, created_by)
         VALUES ($1, 'Monthly', 100000, 30, 'ACTIVE', $2)`, [planId, adminId],
      );
      await database.query(
        `INSERT INTO payments
         (id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
          amount, method, status, transaction_code, idempotency_key,
          request_hash, created_by, confirmed_at, decided_at)
         VALUES ($1, $2, $3, 'Monthly', 30, 100000, 'MOCK_QR', 'SUCCESS',
                 $4, $5, repeat('a', 64), $2, now(), now())`,
        [paymentId, memberId, planId, `MG-${paymentId.slice(0, 18)}`, randomUUID()],
      );
      await database.query(
        `INSERT INTO member_memberships
         (id, member_id, plan_id, source_payment_id, start_date, end_date,
          status, activated_at)
         VALUES ($1, $2, $3, $4,
          (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
          (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 29,
          'ACTIVE', now())`, [membershipId, memberId, planId, paymentId],
      );
      await database.query(
        'INSERT INTO coach_relationships (id, member_id, coach_id) VALUES ($1, $2, $3)',
        [relationshipId, memberId, coachId],
      );
      const log = await call(base, '/workout-logs', member, 'POST', {
        performedAt: '2026-10-20T08:00:00+07:00', durationMinutes: 45,
        exercises: [{ exerciseName: 'Squat', displayOrder: 1, setsCompleted: 3 }],
      });
      assert.equal(log.status, 201, JSON.stringify(log.body));
      const logId = log.body.data.id;
      assert.equal(log.body.data.exercises[0].exerciseName, 'Squat');
      assert.equal((await call(base, '/workout-logs?page=1&pageSize=1', member))
        .body.pagination.totalItems, 1);
      assert.equal((await call(base, `/coach/members/${memberId}/workout-logs`, coach))
        .body.data[0].id, logId);
      assert.equal((await call(base, `/coach/members/${memberId}/workout-logs`, outsider))
        .status, 404);
      assert.equal((await call(base, `/coach/members/${memberId}/workout-logs`, admin))
        .status, 403);
      const measurement = await call(base, '/body-measurements', member, 'POST', {
        measuredAt: '2026-10-20T09:00:00+07:00', weightKg: 72.5,
      });
      assert.equal(measurement.status, 201, JSON.stringify(measurement.body));
      const charts = await call(base, '/progress/me/charts?from=2026-10-20&to=2026-10-20', member);
      assert.equal(charts.status, 200);
      assert.equal(charts.body.data.length, 1);
      assert.equal(Number(charts.body.data[0].weightKg), 72.5);
      assert.equal((await call(base, '/progress/me/summary', member)).body.data.workoutCount, 1);
      const comment = await call(base, '/coach/progress-comments', coach, 'POST', {
        memberId, workoutLogId: logId, content: 'Good form',
      });
      assert.equal(comment.status, 201, JSON.stringify(comment.body));
      assert.equal((await call(base, '/progress-comments', member)).body.data[0].id,
        comment.body.data.id);
      const reviewedUpdate = await call(base, `/workout-logs/${logId}`, member, 'PATCH', {
        durationMinutes: 60,
      });
      assert.equal(reviewedUpdate.status, 409, JSON.stringify(reviewedUpdate.body));
      assert.equal(reviewedUpdate.body.error.code, 'PROGRESS_ALREADY_REVIEWED');
      assert.equal((await call(base, '/workout-logs', member)).body.data[0].durationMinutes, 45);
      await database.query(
        `UPDATE coach_relationships SET status = 'ENDED', ended_at = now(),
         ended_by = $1, end_reason = 'Test ending' WHERE id = $2`,
        [memberId, relationshipId],
      );
      assert.equal((await call(base, `/coach/members/${memberId}/workout-logs`, coach))
        .status, 404);
      assert.equal((await call(base, '/coach/progress-comments', coach, 'POST', {
        memberId, workoutLogId: logId, content: 'Too late',
      })).status, 403);
      assert.equal((await call(base, '/progress-comments', member)).body.data.length, 1);
    } finally {
      await database.query('DELETE FROM progress_comments WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM workout_log_exercises WHERE workout_log_id IN (SELECT id FROM workout_logs WHERE member_id = $1)', [memberId]);
      await database.query('DELETE FROM workout_logs WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM body_measurements WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM coach_relationships WHERE id = $1', [relationshipId]);
      await database.query('DELETE FROM member_memberships WHERE id = $1', [membershipId]);
      await database.query('DELETE FROM payments WHERE id = $1', [paymentId]);
      await database.query('DELETE FROM membership_plans WHERE id = $1', [planId]);
      await database.query('DELETE FROM users WHERE id IN ($1, $2, $3, $4)',
        [adminId, memberId, coachId, outsiderId]);
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });
