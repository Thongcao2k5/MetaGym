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
    const app = createApp({ database, jwtSecret: secret, enableLegacyWrites: true });
    const server = app.listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;
    const adminId = randomUUID();
    const memberId = randomUUID();
    const secondMemberId = randomUUID();
    const coachId = randomUUID();
    const outsiderId = randomUUID();
    const planId = randomUUID();
    const paymentId = randomUUID();
    const membershipId = randomUUID();
    const secondPaymentId = randomUUID();
    const secondMembershipId = randomUUID();
    const relationshipId = randomUUID();
    const photoMediaId = randomUUID();
    const wrongPurposeMediaId = randomUUID();
    const pendingMediaId = randomUUID();
    const foreignMediaId = randomUUID();
    const admin = token(adminId, 'ADMIN');
    const member = token(memberId, 'MEMBER');
    const secondMember = token(secondMemberId, 'MEMBER');
    const coach = token(coachId, 'COACH');
    const outsider = token(outsiderId, 'COACH');
    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Admin'),
                ($3, $4, 'hash', 'MEMBER', 'Member'),
                ($5, $6, 'hash', 'COACH', 'Coach'),
                ($7, $8, 'hash', 'COACH', 'Outsider'),
                ($9, $10, 'hash', 'MEMBER', 'Second member')`,
        [adminId, `${adminId}@example.com`, memberId, `${memberId}@example.com`,
          coachId, `${coachId}@example.com`, outsiderId, `${outsiderId}@example.com`,
          secondMemberId, `${secondMemberId}@example.com`],
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
        `INSERT INTO payments
         (id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
          amount, method, status, transaction_code, idempotency_key,
          request_hash, created_by, confirmed_at, decided_at)
         VALUES ($1, $2, $3, 'Monthly', 30, 100000, 'MOCK_QR', 'SUCCESS',
                 $4, $5, repeat('a', 64), $2, now(), now())`,
        [secondPaymentId, secondMemberId, planId,
          `MG-${secondPaymentId.slice(0, 18)}`, randomUUID()],
      );
      await database.query(
        `INSERT INTO member_memberships
         (id, member_id, plan_id, source_payment_id, start_date, end_date,
          status, activated_at)
         VALUES ($1, $2, $3, $4,
          (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
          (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 29,
          'ACTIVE', now())`,
        [secondMembershipId, secondMemberId, planId, secondPaymentId],
      );
      await database.query(
        'INSERT INTO coach_relationships (id, member_id, coach_id) VALUES ($1, $2, $3)',
        [relationshipId, memberId, coachId],
      );
      await database.query(
        `INSERT INTO media_assets
         (id, owner_id, purpose, access_scope, storage_key, original_name,
          expires_at, status, mime_type, size_bytes, width, height, ready_at)
         VALUES ($1, $2, 'PROGRESS_PHOTO', 'PRIVATE', $3, 'photo.png',
                 now() + interval '15 minutes', 'READY', 'image/png', 10, 2, 2, now()),
                ($4, $2, 'MEAL_PHOTO', 'PRIVATE', $5, 'meal.png',
                 now() + interval '15 minutes', 'READY', 'image/png', 10, 2, 2, now()),
                ($6, $7, 'PROGRESS_PHOTO', 'PRIVATE', $8, 'other.png',
                 now() + interval '15 minutes', 'READY', 'image/png', 10, 2, 2, now())`,
        [photoMediaId, memberId, randomUUID(), wrongPurposeMediaId,
          randomUUID(), foreignMediaId, secondMemberId, randomUUID()],
      );
      await database.query(
        `INSERT INTO media_assets
         (id, owner_id, purpose, access_scope, storage_key, original_name, expires_at)
         VALUES ($1, $2, 'PROGRESS_PHOTO', 'PRIVATE', $3, 'pending.png',
                 now() + interval '15 minutes')`,
        [pendingMediaId, memberId, randomUUID()],
      );
      assert.deepEqual((await call(base, '/progress/me/charts', member)).body.data, []);
      const log = await call(base, '/workout-logs', member, 'POST', {
        performedAt: '2026-10-20T08:00:00+07:00', durationMinutes: 45,
        exercises: [{ exerciseName: 'Squat', displayOrder: 1, setsCompleted: 3 }],
      });
      assert.equal(log.status, 201, JSON.stringify(log.body));
      const logId = log.body.data.id;
      assert.equal(log.body.data.exercises[0].exerciseName, 'Squat');
      assert.equal((await call(base, '/workout-logs', member, 'POST', {
        performedAt: 'not-a-date', durationMinutes: 30,
      })).status, 422);
      assert.equal((await call(base, '/workout-logs', member, 'POST', {
        performedAt: '2026-10-20T08:00:00+07:00', durationMinutes: 0,
      })).status, 422);
      assert.equal((await call(base, '/workout-logs', member, 'POST', {
        performedAt: '2026-10-20T08:00:00+07:00',
        exercises: [
          { exerciseName: 'Squat', displayOrder: 1 },
          { exerciseName: 'Row', displayOrder: 1 },
        ],
      })).status, 422);
      assert.equal((await call(base, `/workout-logs/${logId}`, secondMember,
        'PATCH', { durationMinutes: 20 })).status, 404);
      const extraWorkoutIds = [];
      for (const name of ['Row', 'Press']) {
        const created = await call(base, '/workout-logs', member, 'POST', {
          performedAt: '2026-10-20T08:00:00+07:00',
          exercises: [{ exerciseName: name, displayOrder: 1 }],
        });
        assert.equal(created.status, 201, JSON.stringify(created.body));
        extraWorkoutIds.push(created.body.data.id);
      }
      const workoutPages = await Promise.all([1, 2].map((page) =>
        call(base, `/workout-logs?page=${page}&pageSize=2`, member)));
      assert.deepEqual(workoutPages.map((item) => item.body.data.length), [2, 1]);
      assert.equal(workoutPages[0].body.pagination.totalItems, 3);
      assert.equal(new Set(workoutPages.flatMap((item) => item.body.data.map(
        (entry) => entry.id))).size, 3);
      assert.deepEqual(workoutPages.flatMap((item) => item.body.data.map(
        (entry) => entry.id)), [logId, ...extraWorkoutIds].sort().reverse());
      assert.equal((await call(base, '/workout-logs?page=0', member)).status, 422);
      assert.equal((await call(base, '/workout-logs', admin)).status, 403);
      const changedWorkout = await call(base, `/workout-logs/${extraWorkoutIds[0]}`,
        member, 'PATCH', { exercises: [
          { exerciseName: 'Deadlift', displayOrder: 1, setsCompleted: 4 },
        ] });
      assert.equal(changedWorkout.body.data.exercises[0].exerciseName, 'Deadlift');
      assert.equal(changedWorkout.body.data.exercises[0].setsCompleted, 4);
      assert.equal((await call(base, `/workout-logs/${extraWorkoutIds[0]}`,
        member, 'PATCH', { exercises: [
          { exerciseId: randomUUID(), displayOrder: 1 },
        ] })).status, 422);
      assert.equal((await call(base, '/workout-logs', member)).body.data.find(
        (entry) => entry.id === extraWorkoutIds[0]).exercises[0].exerciseName,
      'Deadlift');
      assert.equal((await call(base, '/workout-logs', undefined)).status, 401);

      assert.equal((await call(base, '/meal-logs', member, 'POST', {
        eatenAt: '2026-10-20T12:00:00+07:00', mealName: 'Lunch',
        mealType: 'BRUNCH',
      })).status, 422);
      assert.equal((await call(base, '/meal-logs', member, 'POST', {
        eatenAt: '2026-10-20T12:00:00+07:00', mealName: 'Lunch',
        imageMediaId: randomUUID(),
      })).status, 422);
      const mealIds = [];
      for (const mealName of ['Rice', 'Chicken', 'Fruit']) {
        const created = await call(base, '/meal-logs', member, 'POST', {
          eatenAt: '2026-10-20T12:00:00+07:00', mealName,
          mealType: 'LUNCH', estimatedCalories: 300,
        });
        assert.equal(created.status, 201, JSON.stringify(created.body));
        mealIds.push(created.body.data.id);
      }
      assert.equal((await call(base, `/meal-logs/${mealIds[0]}`, secondMember,
        'PATCH', { mealName: 'Stolen' })).status, 404);
      assert.equal((await call(base, `/meal-logs/${mealIds[0]}`, member, 'PATCH',
        { mealType: 'SNACK', estimatedCalories: 150 })).body.data.mealType, 'SNACK');
      const mealPages = await Promise.all([1, 2].map((page) =>
        call(base, `/meal-logs?page=${page}&pageSize=2`, member)));
      assert.deepEqual(mealPages.map((item) => item.body.data.length), [2, 1]);
      assert.equal(new Set(mealPages.flatMap((item) => item.body.data.map(
        (entry) => entry.id))).size, 3);
      assert.deepEqual(mealPages.flatMap((item) => item.body.data.map(
        (entry) => entry.id)), mealIds.sort().reverse());
      assert.equal((await call(base, '/workout-logs?page=1&pageSize=1', member))
        .body.pagination.totalItems, 3);
      assert.equal((await call(base, `/coach/members/${memberId}/workout-logs`, coach))
        .status, 403);
      assert.equal((await call(base, `/coach/members/${memberId}/workout-logs`, outsider))
        .status, 403);
      assert.equal((await call(base, `/coach/members/${memberId}/workout-logs`, admin))
        .status, 403);
      const measurement = await call(base, '/body-measurements', member, 'POST', {
        measuredAt: '2026-10-20T09:00:00+07:00', weightKg: 72.5,
      });
      assert.equal(measurement.status, 201, JSON.stringify(measurement.body));
      assert.equal((await call(base, '/body-measurements', member, 'POST', {
        measuredAt: '2026-10-21T09:00:00+07:00', weightKg: -1,
      })).status, 422);
      const secondMeasurement = await call(base, '/body-measurements', member, 'POST', {
        measuredAt: '2026-10-21T09:00:00+07:00', weightKg: 71.5,
      });
      assert.equal(secondMeasurement.status, 201);
      assert.equal((await call(base, `/body-measurements/${measurement.body.data.id}`,
        secondMember, 'PATCH', { weightKg: 50 })).status, 404);
      assert.equal((await call(base, `/body-measurements/${secondMeasurement.body.data.id}`,
        member, 'PATCH', { weightKg: 71 })).status, 200);
      const charts = await call(base, '/progress/me/charts?from=2026-10-20&to=2026-10-20', member);
      assert.equal(charts.status, 200);
      assert.equal(charts.body.data.length, 1);
      assert.equal(Number(charts.body.data[0].weightKg), 72.5);
      const allCharts = await call(base, '/progress/me/charts', member);
      assert.deepEqual(allCharts.body.data.map((item) => Number(item.weightKg)),
        [72.5, 71]);
      assert.equal((await call(base, '/progress/me/charts?from=2026-10-22&to=2026-10-20',
        member)).status, 422);
      assert.deepEqual((await call(base, '/progress/me/charts', secondMember)).body.data, []);
      for (const invalidId of [wrongPurposeMediaId, pendingMediaId, foreignMediaId]) {
        assert.equal((await call(base, '/progress-photos', member, 'POST', {
          mediaId: invalidId, takenAt: '2026-10-20T10:00:00+07:00',
        })).status, 422);
      }
      const photo = await call(base, '/progress-photos', member, 'POST', {
        mediaId: photoMediaId, takenAt: '2026-10-20T10:00:00+07:00',
        pose: 'FRONT',
      });
      assert.equal(photo.status, 201, JSON.stringify(photo.body));
      assert.equal((await call(base, '/progress-photos', member)).body.data[0].id,
        photo.body.data.id);
      assert.equal((await call(base, `/coach/members/${memberId}/progress-photos`,
        coach)).status, 403);
      assert.equal((await call(base, `/coach/members/${memberId}/progress-photos`,
        outsider)).status, 403);
      assert.equal((await call(base, `/progress-photos/${photo.body.data.id}`,
        secondMember, 'PATCH', { pose: 'SIDE' })).status, 404);
      assert.equal((await call(base, `/progress-photos/${photo.body.data.id}`,
        member, 'PATCH', { pose: 'SIDE' })).body.data.pose, 'SIDE');
      assert.equal((await call(base, '/progress/me/summary', member)).body.data.workoutCount, 3);
      assert.equal((await call(base, '/progress/me/summary', member)).body.data.mealCount, 3);
      const comment = await call(base, '/coach/progress-comments', coach, 'POST', {
        memberId, workoutLogId: logId, content: 'Good form',
      });
      assert.equal(comment.status, 403);
      assert.deepEqual((await call(base, '/progress-comments', member)).body.data, []);
      const reviewedUpdate = await call(base, `/workout-logs/${logId}`, member, 'PATCH', {
        durationMinutes: 60,
      });
      assert.equal(reviewedUpdate.status, 200, JSON.stringify(reviewedUpdate.body));
      assert.equal((await call(base, '/workout-logs', member)).body.data.find(
        (entry) => entry.id === logId).durationMinutes, 60);
      await database.query(
        `UPDATE member_memberships SET status = 'EXPIRED', expired_at = now()
         WHERE id = $1`, [membershipId],
      );
      assert.equal((await call(base, '/meal-logs', member, 'POST', {
        eatenAt: '2026-10-20T12:00:00+07:00', mealName: 'After expiry',
      })).body.error.code, 'MEMBERSHIP_REQUIRED');
      assert.equal((await call(base, `/workout-logs/${extraWorkoutIds[0]}`,
        member, 'PATCH', { durationMinutes: 20 })).body.error.code,
      'MEMBERSHIP_REQUIRED');
      await database.query(
        `UPDATE coach_relationships SET status = 'ENDED', ended_at = now(),
         ended_by = $1, end_reason = 'Test ending' WHERE id = $2`,
        [memberId, relationshipId],
      );
      assert.equal((await call(base, `/coach/members/${memberId}/workout-logs`, coach))
        .status, 403);
      assert.equal((await call(base, '/coach/progress-comments', coach, 'POST', {
        memberId, workoutLogId: logId, content: 'Too late',
      })).status, 403);
      assert.equal((await call(base, '/progress-comments', member)).body.data.length, 0);
    } finally {
      await database.query('DELETE FROM progress_comments WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM workout_log_exercises WHERE workout_log_id IN (SELECT id FROM workout_logs WHERE member_id = $1)', [memberId]);
      await database.query('DELETE FROM workout_logs WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM meal_logs WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM body_measurements WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM progress_photos WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM media_assets WHERE owner_id IN ($1, $2)',
        [memberId, secondMemberId]);
      await database.query('DELETE FROM coach_relationships WHERE id = $1', [relationshipId]);
      await database.query('DELETE FROM member_memberships WHERE id = $1', [membershipId]);
      await database.query('DELETE FROM member_memberships WHERE id = $1',
        [secondMembershipId]);
      await database.query('DELETE FROM payments WHERE id = $1', [paymentId]);
      await database.query('DELETE FROM payments WHERE id = $1', [secondPaymentId]);
      await database.query('DELETE FROM membership_plans WHERE id = $1', [planId]);
      await database.query('DELETE FROM users WHERE id IN ($1, $2, $3, $4, $5)',
        [adminId, memberId, coachId, outsiderId, secondMemberId]);
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });
