import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';
import sharp from 'sharp';

import { createApp } from '../src/app.js';
import { createLocalImageStorage } from '../src/storage/local-image-storage.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'end-to-end-api-journey-secret-32-characters';

function token(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, secret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
    subject: id, expiresIn: 3600,
  });
}

async function call(base, route, bearer, method = 'GET', body, extraHeaders = {}) {
  const response = await fetch(`${base}/api/v1${route}`, {
    method, headers: { ...(bearer ? { authorization: `Bearer ${bearer}` } : {}),
      ...(body === undefined ? {} : { 'content-type': 'application/json' }),
      ...extraHeaders },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: response.status, body: await response.json() };
}

function expected(result, status = 200) {
  assert.equal(result.status, status, JSON.stringify(result.body));
  return result.body.data;
}

test('PostgreSQL API journey from registration through coaching and termination',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const storageDir = await mkdtemp(path.join(tmpdir(), 'metagym-journey-'));
    const app = createApp({ database, jwtSecret: secret,
      imageStorage: createLocalImageStorage(storageDir) });
    const server = app.listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;
    const adminId = randomUUID();
    const suffix = randomUUID();
    const memberEmail = `journey-member-${suffix}@example.com`;
    const coachEmail = `journey-coach-${suffix}@example.com`;
    const password = 'StrongPass1';
    let memberId;
    let coachId;
    let planId;
    let relationshipId;
    let exerciseId;
    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'test-admin-token', 'ADMIN', 'Journey Admin')`,
        [adminId, `journey-admin-${suffix}@example.com`],
      );
      const admin = token(adminId, 'ADMIN');
      const registered = expected(await call(base, '/auth/registrations', undefined,
        'POST', { email: memberEmail, fullName: 'Journey Member', password }), 201);
      memberId = registered.id;
      assert.equal((await call(base, '/auth/registrations', undefined,
        'POST', { email: memberEmail, fullName: 'Journey Member', password })).status, 409);
      const member = expected(await call(base, '/auth/sessions', undefined,
        'POST', { email: memberEmail, password }), 200).accessToken;
      assert.equal((await call(base, '/coach-requests', member, 'POST',
        { coachId: randomUUID() })).body.error.code, 'MEMBERSHIP_REQUIRED');

      coachId = expected(await call(base, '/admin/coaches', admin, 'POST', {
        email: coachEmail, fullName: 'Journey Coach', password, memberLimit: 1,
      }), 201).id;
      const coach = expected(await call(base, '/auth/sessions', undefined,
        'POST', { email: coachEmail, password }), 200).accessToken;
      planId = expected(await call(base, '/admin/membership-plans', admin, 'POST', {
        name: 'Journey monthly', price: 100000, durationDays: 30,
      }), 201).id;
      const key = randomUUID();
      const payment = expected(await call(base, '/payments', member, 'POST',
        { planId }, { 'idempotency-key': key }), 201);
      assert.equal(expected(await call(base, '/payments', member, 'POST',
        { planId }, { 'idempotency-key': key }), 200).id, payment.id);
      const confirmation = expected(await call(base,
        `/payments/${payment.id}/mock-confirmations`, member, 'POST', {}), 200);
      assert.equal(confirmation.membership.status, 'ACTIVE');
      assert.equal(expected(await call(base,
        `/payments/${payment.id}/mock-confirmations`, member, 'POST', {}), 200)
        .membership.id, confirmation.membership.id);
      assert.equal((await database.query(
        `SELECT count(*)::int AS count FROM member_memberships
         WHERE source_payment_id = $1`, [payment.id])).rows[0].count, 1);

      const request = expected(await call(base, '/coach-requests', member, 'POST',
        { coachId, message: 'Help me train' }), 201);
      const accepted = expected(await call(base, `/coach/requests/${request.id}`,
        coach, 'PATCH', { decision: 'ACCEPTED' }), 200);
      relationshipId = accepted.relationship.id;
      assert.equal(expected(await call(base, '/relationships/me', member)).id,
        relationshipId);
      exerciseId = randomUUID();
      await database.query(
        `INSERT INTO exercises (id, name, instructions, status, created_by)
         VALUES ($1, 'Journey squat', 'Stand upright', 'ACTIVE', $2)`,
        [exerciseId, coachId],
      );
      const training = expected(await call(base,
        `/coach/members/${memberId}/training-plans`, coach, 'POST', {
          title: 'Strength plan', days: [{ dayNumber: 1, title: 'Day one',
            exercises: [{ exerciseId, displayOrder: 1, reps: '10', sets: 3 }] }],
        }), 201);
      assert.equal(expected(await call(base,
        `/coach/training-plans/${training.id}/publications`, coach, 'POST', {}),
      200).status, 'ACTIVE');
      assert.equal(expected(await call(base, '/training-plans/me/active', member)).id,
        training.id);
      const guide = expected(await call(base,
        `/coach/members/${memberId}/nutrition-guides`, coach, 'POST', {
          title: 'Nutrition plan', content: 'Eat a balanced meal.',
        }), 201);
      assert.equal(expected(await call(base, `/coach/nutrition-guides/${guide.id}`,
        coach, 'PATCH', { publish: true }), 200).status, 'ACTIVE');
      assert.equal(expected(await call(base, '/nutrition-guides/me/active', member)).id,
        guide.id);
      const session = expected(await call(base, '/coach/training-sessions', coach,
        'POST', { memberId, title: 'First session',
          scheduledStartAt: '2026-11-01T08:00:00+07:00',
          scheduledEndAt: '2026-11-01T09:00:00+07:00' }), 201);
      assert.equal(expected(await call(base, '/training-sessions/me', member))[0].id,
        session.id);

      const workout = expected(await call(base, '/workout-logs', member, 'POST', {
        trainingPlanId: training.id, trainingSessionId: session.id,
        performedAt: '2026-10-22T08:00:00+07:00', durationMinutes: 45,
        exercises: [{ exerciseId, displayOrder: 1, setsCompleted: 3 }],
      }), 201);
      assert.equal(workout.exercises[0].exerciseName, 'Journey squat');
      expected(await call(base, '/meal-logs', member, 'POST', {
        eatenAt: '2026-10-22T12:00:00+07:00', mealName: 'Lunch',
        mealType: 'LUNCH', estimatedCalories: 500,
      }), 201);
      expected(await call(base, '/body-measurements', member, 'POST', {
        measuredAt: '2026-10-22T07:00:00+07:00', weightKg: 72,
      }), 201);
      const imageBytes = await sharp({ create: { width: 2, height: 2,
        channels: 3, background: '#0088ff' } }).png().toBuffer();
      const imageResponse = await fetch(`${base}/api/v1/media/images`, {
        method: 'POST', headers: { authorization: `Bearer ${member}`,
          'content-type': 'image/png', 'x-image-purpose': 'PROGRESS_PHOTO' },
        body: imageBytes,
      });
      assert.equal(imageResponse.status, 201);
      const image = (await imageResponse.json()).data;
      expected(await call(base, '/progress-photos', member, 'POST', {
        mediaId: image.id, takenAt: '2026-10-22T07:00:00+07:00',
        pose: 'FRONT',
      }), 201);
      const progress = expected(await call(base, '/progress/me/summary', member));
      assert.equal(progress.workoutCount, 1);
      assert.equal(progress.mealCount, 1);
      assert.equal(progress.progressPhotoCount, 1);
      assert.equal((await call(base, '/coach/progress-comments', coach,
        'POST', { memberId, workoutLogId: workout.id,
          content: 'Good work on your first session.' })).status, 403);
      assert.deepEqual(expected(await call(base, '/progress-comments', member)), []);
      assert.equal((await call(base, '/coach/progress-comments', member, 'POST',
        { memberId, content: 'Not a coach' })).status, 403);

      const message = { messageType: 'TEXT', clientMessageId: randomUUID(),
        content: 'How did I do?' };
      const sent = expected(await call(base,
        `/conversations/${relationshipId}/messages`, member, 'POST', message), 201);
      const reply = expected(await call(base,
        `/conversations/${relationshipId}/messages`, coach, 'POST', {
          messageType: 'TEXT', clientMessageId: randomUUID(),
          content: 'I left feedback on your workout.',
        }), 201);
      assert.equal(reply.senderId, coachId);
      assert.equal(expected(await call(base,
        `/conversations/${relationshipId}/messages`, member, 'POST', message), 200)
        .id, sent.id);
      assert.equal(expected(await call(base, '/conversations', coach))[0]
        .unreadCount, 1);
      expected(await call(base, `/conversations/${relationshipId}/read-state`,
        coach, 'PATCH', { messageId: sent.id }), 200);
      assert.equal(expected(await call(base, '/conversations', coach))[0]
        .unreadCount, 0);
      assert.equal(expected(await call(base,
        `/relationships/${relationshipId}/terminations`, member, 'POST',
        { reason: 'Finished program' }), 200).status, 'ENDED');
      assert.equal(expected(await call(base, '/relationships/me', member)), null);
      assert.equal(expected(await call(base, '/relationships/me/history', member))[0]
        .id, relationshipId);
      assert.equal((await call(base,
        `/conversations/${relationshipId}/messages`, coach, 'POST', {
          ...message, clientMessageId: randomUUID(), content: 'After ending',
        })).status, 201);
    } finally {
      if (relationshipId) {
        await database.query(
          `UPDATE conversation_participants SET last_read_message_id = NULL
           WHERE conversation_id IN
           (SELECT id FROM conversations WHERE relationship_id = $1)`,
          [relationshipId],
        );
        await database.query(
          `DELETE FROM messages WHERE conversation_id IN
           (SELECT id FROM conversations WHERE relationship_id = $1)`,
          [relationshipId],
        );
        await database.query(
          `DELETE FROM conversation_participants WHERE conversation_id IN
           (SELECT id FROM conversations WHERE relationship_id = $1)`,
          [relationshipId],
        );
        await database.query('DELETE FROM conversations WHERE relationship_id = $1',
          [relationshipId]);
      }
      if (memberId) {
        await database.query('DELETE FROM progress_comments WHERE member_id = $1',
          [memberId]);
        await database.query('DELETE FROM progress_photos WHERE member_id = $1',
          [memberId]);
        await database.query('DELETE FROM media_assets WHERE owner_id = $1',
          [memberId]);
        await database.query(
          `DELETE FROM workout_log_exercises WHERE workout_log_id IN
           (SELECT id FROM workout_logs WHERE member_id = $1)`, [memberId],
        );
        await database.query('DELETE FROM workout_logs WHERE member_id = $1',
          [memberId]);
        await database.query('DELETE FROM meal_logs WHERE member_id = $1',
          [memberId]);
        await database.query('DELETE FROM body_measurements WHERE member_id = $1',
          [memberId]);
        await database.query('DELETE FROM training_sessions WHERE member_id = $1',
          [memberId]);
        await database.query('DELETE FROM nutrition_guides WHERE member_id = $1',
          [memberId]);
        await database.query(
          `DELETE FROM training_plan_exercises WHERE plan_day_id IN
           (SELECT id FROM training_plan_days WHERE plan_id IN
            (SELECT id FROM training_plans WHERE member_id = $1))`, [memberId],
        );
        await database.query(
          `DELETE FROM training_plan_days WHERE plan_id IN
           (SELECT id FROM training_plans WHERE member_id = $1)`, [memberId],
        );
        await database.query('DELETE FROM training_plans WHERE member_id = $1',
          [memberId]);
        if (exerciseId) await database.query('DELETE FROM exercises WHERE id = $1',
          [exerciseId]);
        await database.query('DELETE FROM coach_relationships WHERE member_id = $1',
          [memberId]);
        await database.query('DELETE FROM coach_requests WHERE member_id = $1',
          [memberId]);
        await database.query('DELETE FROM member_memberships WHERE member_id = $1',
          [memberId]);
        await database.query('DELETE FROM payments WHERE member_id = $1',
          [memberId]);
        await database.query('DELETE FROM member_profiles WHERE user_id = $1',
          [memberId]);
      }
      await database.query('DELETE FROM admin_audit_logs WHERE admin_id = $1',
        [adminId]);
      if (planId) await database.query('DELETE FROM membership_plans WHERE id = $1',
        [planId]);
      if (coachId) await database.query('DELETE FROM coach_profiles WHERE user_id = $1',
        [coachId]);
      await database.query(
        'DELETE FROM users WHERE id IN ($1, $2, $3)',
        [adminId, memberId ?? adminId, coachId ?? adminId],
      );
      await new Promise((resolve) => server.close(resolve));
      await database.end();
      await rm(storageDir, { recursive: true, force: true });
    }
  });
