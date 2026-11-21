import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const { Pool } = pg;
const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'admin-users-integration-secret-with-32-characters';

function token(id, role = 'ADMIN') {
  return jwt.sign({ role, sessionVersion: 0 }, secret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
    subject: id, expiresIn: 3600,
  });
}

async function request(app, path, auth, method = 'GET', body, headers = {}) {
  const server = app.listen(0);
  try {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/api/v1${path}`, {
      method,
      headers: { authorization: `Bearer ${auth}`, ...headers,
        ...(body === undefined ? {} : { 'content-type': 'application/json' }) },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    return { status: response.status, body: await response.json() };
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

test('PostgreSQL admin API creates and manages Coach with role checks and audit',
  { skip: !databaseUrl }, async () => {
    const database = new Pool({ connectionString: databaseUrl });
    const adminId = randomUUID();
    const memberId = randomUUID();
    let coachId;
    let secondCoachId;
    let planId;
    let paymentId;
    const app = createApp({ database, jwtSecret: secret, enableLegacyWrites: true });
    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Admin'),
                ($3, $4, 'hash', 'MEMBER', 'Member')`,
        [adminId, `${adminId}@example.com`, memberId, `${memberId}@example.com`],
      );
      await database.query('INSERT INTO member_profiles (user_id) VALUES ($1)', [memberId]);
      const adminToken = token(adminId);
      const memberToken = token(memberId, 'MEMBER');
      let result = await request(app, '/admin/users', memberToken);
      assert.equal(result.status, 403);
      result = await request(app, '/admin/coaches', adminToken, 'POST', {
        email: ' COACH@EXAMPLE.COM ', fullName: 'Coach One',
        password: 'StrongPass1',
      });
      assert.equal(result.status, 201);
      coachId = result.body.data.id;
      assert.equal(result.body.data.email, 'coach@example.com');
      assert.equal(result.body.data.memberLimit, 8);
      assert.equal(JSON.stringify(result.body).includes('password'), false);
      const stored = await database.query('SELECT password_hash FROM users WHERE id = $1', [coachId]);
      assert.equal(await bcrypt.compare('StrongPass1', stored.rows[0].password_hash), true);

      result = await request(app, '/admin/coaches', adminToken, 'POST', {
        email: 'coach@example.com', fullName: 'Coach Two',
        password: 'StrongPass1', memberLimit: 8,
      });
      assert.equal(result.status, 409);
      result = await request(app, '/admin/users?role=COACH&search=coach%40example.com', adminToken);
      assert.equal(result.status, 200);
      assert.equal(result.body.pagination.totalItems, 1);
      assert.equal(result.body.data[0].id, coachId);
      result = await request(app, `/admin/users/${coachId}`, adminToken);
      assert.equal(result.status, 200);

      result = await request(app, '/admin/membership-plans', adminToken, 'POST', {
        name: 'Monthly', price: 100000, durationDays: 30,
      });
      assert.equal(result.status, 201);
      planId = result.body.data.id;
      assert.equal(result.body.data.price, 100000);
      result = await request(app, '/membership-plans', memberToken);
      assert.equal(result.status, 200);
      assert.equal(result.body.pagination.totalItems, 1);
      assert.equal(result.body.data[0].id, planId);
      result = await request(app, `/membership-plans/${planId}`, memberToken);
      assert.equal(result.status, 200);
      result = await request(app, `/admin/membership-plans/${planId}`, memberToken,
        'PATCH', { price: 5 });
      assert.equal(result.status, 403);

      const key1 = randomUUID();
      result = await request(app, '/payments', memberToken, 'POST',
        { planId }, { 'idempotency-key': key1 });
      assert.equal(result.status, 201);
      const firstPaymentId = result.body.data.id;
      assert.match(result.body.data.qrPayload, /^META-GYM-MOCK:/);
      result = await request(app, '/payments', memberToken, 'POST',
        { planId }, { 'idempotency-key': key1 });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.id, firstPaymentId);
      result = await request(app, '/payments', memberToken, 'POST',
        { planId: randomUUID() }, { 'idempotency-key': key1 });
      assert.equal(result.status, 422);
      const confirmations = await Promise.all([
        request(app, `/payments/${firstPaymentId}/mock-confirmations`, memberToken, 'POST'),
        request(app, `/payments/${firstPaymentId}/mock-confirmations`, memberToken, 'POST'),
      ]);
      assert.deepEqual(confirmations.map((entry) => entry.status), [200, 200]);
      const firstMembership = confirmations[0].body.data.membership;
      assert.equal(firstMembership.status, 'ACTIVE');
      assert.equal(confirmations[1].body.data.membership.id, firstMembership.id);

      result = await request(app, '/payments', memberToken, 'POST',
        { planId }, { 'idempotency-key': randomUUID() });
      assert.equal(result.status, 201);
      result = await request(app, `/payments/${result.body.data.id}/mock-confirmations`, memberToken, 'POST');
      assert.equal(result.status, 200);
      const secondMembership = result.body.data.membership;
      assert.equal(secondMembership.status, 'ACTIVE');
      assert.equal(secondMembership.id, firstMembership.id);
      assert.ok(secondMembership.endDate > firstMembership.endDate);
      result = await request(app, '/memberships/me', memberToken);
      assert.equal(result.status, 200);
      assert.equal(result.body.data.length, 1);
      assert.equal((await request(app, '/payments/me', memberToken)).body.data.length, 2);
      assert.equal((await request(app, `/payments/${firstPaymentId}`, token(coachId, 'COACH'))).status, 404);

      const deskKey = randomUUID();
      result = await request(app, '/admin/front-desk-payments', adminToken, 'POST',
        { memberId, planId }, { 'idempotency-key': deskKey });
      assert.equal(result.status, 201);
      assert.equal(result.body.data.payment.method, 'FRONT_DESK');
      assert.equal(result.body.data.membership.status, 'ACTIVE');
      assert.equal(result.body.data.membership.id, firstMembership.id);
      assert.ok(result.body.data.membership.endDate > secondMembership.endDate);
      const deskPaymentId = result.body.data.payment.id;
      result = await request(app, '/admin/front-desk-payments', adminToken, 'POST',
        { memberId, planId }, { 'idempotency-key': deskKey });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.payment.id, deskPaymentId);
      assert.equal((await request(app, '/admin/memberships', adminToken)).body.data.length, 1);
      result = await request(app, '/admin/dashboard?from=2020-01-01&to=2030-01-01', adminToken);
      assert.equal(result.status, 200);
      assert.equal(result.body.data.members.active, 1);
      assert.equal(result.body.data.activeMemberships, 1);
      assert.equal(result.body.data.revenue.paymentCount, 3);
      assert.equal((await request(app, '/admin/dashboard', memberToken)).status, 403);
      assert.equal((await request(app, '/admin/dashboard?from=2026-10-22&to=2026-10-21',
        adminToken)).status, 422);

      result = await request(app, '/body-measurements', memberToken, 'POST', {
        measuredAt: '2026-10-21T07:00:00+07:00', weightKg: 70.5,
        waistCm: 80,
      });
      assert.equal(result.status, 201);
      const measurementId = result.body.data.id;
      assert.equal((await request(app, `/body-measurements/${measurementId}`, adminToken,
        'PATCH', { weightKg: 60 })).status, 403);
      result = await request(app, `/body-measurements/${measurementId}`, memberToken,
        'PATCH', { weightKg: 70 });
      assert.equal(result.status, 200);
      assert.equal(Number(result.body.data.weightKg), 70);
      assert.equal((await request(app, '/body-measurements', memberToken)).body.pagination.totalItems, 1);
      result = await request(app, '/meal-logs', memberToken, 'POST', {
        eatenAt: '2026-10-21T12:00:00+07:00', mealName: 'Lunch',
        mealType: 'LUNCH', estimatedCalories: 600,
      });
      assert.equal(result.status, 201);
      result = await request(app, '/workout-logs', memberToken, 'POST', {
        performedAt: '2026-10-21T18:00:00+07:00', durationMinutes: 45,
        completionLevel: 90, exercises: [
          { exerciseName: 'Push-up', displayOrder: 1, setsCompleted: 3, repsSummary: '10 each' },
        ],
      });
      assert.equal(result.status, 201);
      const workoutId = result.body.data.id;
      assert.equal(result.body.data.exercises[0].exerciseName, 'Push-up');
      result = await request(app, `/workout-logs/${workoutId}`, memberToken,
        'PATCH', { exercises: [
          { exerciseName: 'Push-up', displayOrder: 1, setsCompleted: 4 },
        ] });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.exercises[0].setsCompleted, 4);
      assert.equal((await request(app, '/workout-logs', memberToken)).body.data[0]
        .exercises.length, 1);
      assert.equal((await request(app, '/progress/me/summary', memberToken)).body.data.workoutCount, 1);
      assert.equal((await request(app, '/progress/me/charts', memberToken)).body.data.length, 1);
      assert.equal((await request(app, '/progress/me/summary', adminToken)).status, 403);

      result = await request(app, '/coaches', memberToken);
      assert.equal(result.status, 200);
      assert.equal(result.body.data[0].id, coachId);
      result = await request(app, '/coach-requests', memberToken, 'POST', {
        coachId, message: 'Please coach me',
      });
      assert.equal(result.status, 201);
      const requestId = result.body.data.id;
      assert.equal((await request(app, '/coach-requests', memberToken, 'POST',
        { coachId })).status, 409);
      assert.equal((await request(app, '/coach/requests', token(coachId, 'COACH'))).body.data.length, 1);
      result = await request(app, `/coach/requests/${requestId}`, token(coachId, 'COACH'),
        'PATCH', { decision: 'ACCEPTED' });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.relationship.status, 'ACTIVE');
      const firstRelationshipId = result.body.data.relationship.id;
      assert.equal((await request(app, '/relationships/me', memberToken)).body.data.coachId, coachId);
      assert.equal((await request(app, '/coach/members', token(coachId, 'COACH'))).body.data.length, 1);
      assert.equal((await request(app, `/coach/members/${memberId}/progress/summary`,
        token(coachId, 'COACH'))).status, 403);
      assert.equal((await request(app, `/coach/members/${memberId}/body-measurements`,
        token(coachId, 'COACH'))).status, 403);
      result = await request(app, '/coach/progress-comments', token(coachId, 'COACH'),
        'POST', { memberId, measurementId, content: 'Good progress' });
      assert.equal(result.status, 403);
      assert.equal((await request(app, '/progress-comments', memberToken)).body.data.length, 0);
      assert.equal((await request(app, '/progress-comments', adminToken)).status, 403);
      const conversation = await database.query(
        `SELECT c.id FROM conversations c JOIN coach_relationships r
         ON r.id = c.relationship_id WHERE r.member_id = $1`, [memberId],
      );
      assert.equal(conversation.rows.length, 1);
      assert.equal((await database.query(
        'SELECT count(*)::int AS count FROM conversation_participants WHERE conversation_id = $1',
        [conversation.rows[0].id],
      )).rows[0].count, 2);
      result = await request(app, `/relationships/${firstRelationshipId}/early-termination-requests`,
        token(coachId, 'COACH'), 'POST', { reason: 'Schedule change' });
      assert.equal(result.status, 201);
      const terminationId = result.body.data.id;
      result = await request(app, `/early-termination-requests/${terminationId}/respond`,
        memberToken, 'PATCH', { decision: 'REJECT', reason: 'Want to keep training' });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.status, 'DISPUTED');
      result = await request(app, `/admin/termination-requests/${terminationId}`,
        adminToken, 'PATCH', { decision: 'REJECTED', reason: 'Continue coaching' });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.status, 'ADMIN_REJECTED');
      assert.equal((await request(app, '/relationships/me', memberToken)).body.data.status, 'ACTIVE');
      result = await request(app,
        `/relationships/${firstRelationshipId}/terminations`, memberToken,
        'POST', { reason: 'Changing coach' });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.status, 'ENDED');
      assert.equal((await request(app, '/coach/members', token(coachId, 'COACH'))).body.data.length, 0);
      result = await request(app, '/coach-requests', memberToken, 'POST', { coachId });
      assert.equal(result.status, 201);
      result = await request(app, `/coach/requests/${result.body.data.id}`,
        token(coachId, 'COACH'), 'PATCH', { decision: 'ACCEPTED' });
      assert.equal(result.status, 200);
      const secondRelationshipId = result.body.data.relationship.id;
      result = await request(app, `/relationships/${secondRelationshipId}/early-termination-requests`,
        token(coachId, 'COACH'), 'POST', { reason: 'Coach leaving' });
      assert.equal(result.status, 201);
      const secondTermId = result.body.data.id;
      result = await request(app, `/early-termination-requests/${secondTermId}/respond`,
        memberToken, 'PATCH', { decision: 'REJECT', reason: 'Disagree with ending early' });
      assert.equal(result.status, 200);
      result = await request(app, `/admin/termination-requests/${secondTermId}`,
        adminToken, 'PATCH', { decision: 'APPROVED', reason: 'Approved after dispute review' });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.status, 'ADMIN_APPROVED');
      assert.equal((await request(app, '/relationships/me', memberToken)).body.data, null);
      result = await request(app, '/coach-requests', memberToken, 'POST', { coachId });
      assert.equal(result.status, 201);
      result = await request(app, `/coach/requests/${result.body.data.id}`,
        token(coachId, 'COACH'), 'PATCH', { decision: 'ACCEPTED' });
      assert.equal(result.status, 200);
      result = await request(app, '/admin/coaches', adminToken, 'POST', {
        email: 'second-coach@example.com', fullName: 'Second Coach',
        password: 'StrongPass1',
      });
      assert.equal(result.status, 201);
      secondCoachId = result.body.data.id;
      result = await request(app, '/admin/coach-transfers', adminToken, 'POST', {
        memberId, newCoachId: secondCoachId, reason: 'Coach availability',
      });
      assert.equal(result.status, 201);
      assert.equal(result.body.data.newCoachId, secondCoachId);
      assert.equal((await request(app, '/relationships/me', memberToken)).body.data.coachId, secondCoachId);
      assert.equal((await request(app, '/admin/coach-transfers', adminToken)).body.data.length, 1);
      assert.equal((await request(app, `/coach/members/${memberId}/workout-logs`,
        token(coachId, 'COACH'))).status, 403);
      assert.equal((await request(app, `/coach/members/${memberId}/progress/summary`,
        token(coachId, 'COACH'))).status, 403);
      const transferredLogs = await request(app, `/coach/members/${memberId}/workout-logs`,
        token(secondCoachId, 'COACH'));
      assert.equal(transferredLogs.status, 403);
      assert.equal((await request(app, `/coach/members/${memberId}/progress/summary`,
        token(secondCoachId, 'COACH'))).status, 403);
      assert.equal((await request(app, '/workout-logs', memberToken)).body.data
        .some((entry) => entry.id === workoutId), true);

      paymentId = randomUUID();
      await database.query(
        `INSERT INTO payments
         (id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
          amount, method, transaction_code, idempotency_key, request_hash, created_by)
         VALUES ($1, $2, $3, 'Monthly', 30, 100000, 'MOCK_QR', $4, $5, $6, $2)`,
        [paymentId, memberId, planId, `TX-${paymentId}`, `key-${paymentId}`, 'a'.repeat(64)],
      );
      result = await request(app, `/admin/payments/${paymentId}`, adminToken,
        'PATCH', { status: 'FAILED', reason: 'Test cancellation' });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.status, 'FAILED');
      assert.equal((await request(app, `/payments/${paymentId}/mock-confirmations`, memberToken,
        'POST')).status, 409);
      assert.equal((await request(app, '/admin/payments', memberToken)).status, 403);
      result = await request(app, `/admin/membership-plans/${planId}`, adminToken,
        'PATCH', { price: 200000 });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.price, 200000);
      const updatedPlan = await database.query(
        'SELECT price, duration_days FROM membership_plans WHERE id = $1', [planId],
      );
      assert.equal(Number(updatedPlan.rows[0].price), 200000);
      assert.equal(updatedPlan.rows[0].duration_days, 30);
      // Prior payment snapshot remains immutable at 100000 / 30 days
      const firstPaymentSnapshot = await database.query(
        'SELECT amount, duration_days_snapshot FROM payments WHERE id = $1', [firstPaymentId],
      );
      assert.equal(Number(firstPaymentSnapshot.rows[0].amount), 100000);
      assert.equal(firstPaymentSnapshot.rows[0].duration_days_snapshot, 30);
      result = await request(app, `/admin/membership-plans/${planId}`, adminToken,
        'PATCH', { durationDays: 60 });
      assert.equal(result.status, 200);
      const updatedDuration = await database.query(
        'SELECT duration_days FROM membership_plans WHERE id = $1', [planId],
      );
      assert.equal(updatedDuration.rows[0].duration_days, 60);
      result = await request(app, `/admin/membership-plans/${planId}`, adminToken,
        'PATCH', { status: 'INACTIVE' });
      assert.equal(result.status, 200);
      assert.equal((await request(app, `/membership-plans/${planId}`, memberToken)).status, 404);

      result = await request(app, `/admin/users/${coachId}`, adminToken, 'PATCH', {
        fullName: 'Coach Updated', memberLimit: 2,
      });
      assert.equal(result.status, 422);
      result = await request(app, `/admin/users/${coachId}`, adminToken, 'PATCH', {
        fullName: 'Coach Updated',
      });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.memberLimit, 8);
      result = await request(app, `/admin/users/${memberId}`, adminToken, 'PATCH', { memberLimit: 1 });
      assert.equal(result.status, 422);
      result = await request(app, `/admin/users/${coachId}/status`, adminToken, 'PATCH', {
        status: 'DISABLED', reason: 'Policy test',
      });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.user.status, 'DISABLED');
      assert.equal((await request(app, '/users/me', token(coachId, 'COACH'))).status, 401);
      result = await request(app, `/admin/users/${coachId}/status`, adminToken, 'PATCH', {
        status: 'ACTIVE',
      });
      assert.equal(result.status, 200);
      assert.equal((await request(app, '/users/me', token(coachId, 'COACH'))).status, 401);
      const audit = await database.query(
        'SELECT action FROM admin_audit_logs WHERE entity_id = $1 ORDER BY created_at', [coachId],
      );
      assert.deepEqual(audit.rows.map((row) => row.action).sort(),
        ['COACH_CREATED', 'USER_DISABLED', 'USER_ENABLED', 'USER_UPDATED']);
      result = await request(app, `/admin/coaches/${coachId}/password-resets`,
        adminToken, 'POST', {});
      assert.equal(result.status, 201);
      assert.ok(result.body.data.temporaryPassword.length >= 20);
      assert.ok(result.body.data.reminder);
      const resetHash = await database.query('SELECT password_hash FROM users WHERE id = $1', [coachId]);
      assert.equal(await bcrypt.compare(result.body.data.temporaryPassword,
        resetHash.rows[0].password_hash), true);
      assert.equal((await request(app, '/users/me', token(coachId, 'COACH'))).status, 401);

      result = await request(app, `/admin/users/${memberId}/status`, adminToken,
        'PATCH', { status: 'DISABLED', reason: 'Security regression' });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.user.status, 'DISABLED');
      for (const path of ['/users/me', '/workout-logs', '/progress/me/summary',
        '/payments/me']) {
        assert.equal((await request(app, path, memberToken)).status, 401, path);
      }
      result = await request(app, `/admin/users/${memberId}/status`, adminToken,
        'PATCH', { status: 'ACTIVE' });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.user.status, 'ACTIVE');
      assert.equal((await request(app, '/workout-logs', memberToken)).status, 401);
    } finally {
      await database.query('DELETE FROM coach_notifications WHERE user_id IN ($1, $2, $3)',
        [memberId, coachId ?? adminId, secondCoachId ?? adminId]);
      await database.query('DELETE FROM coach_lock_incidents WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM progress_comments WHERE member_id = $1', [memberId]);
      await database.query(
        `DELETE FROM workout_log_exercises WHERE workout_log_id IN
         (SELECT id FROM workout_logs WHERE member_id = $1)`, [memberId],
      );
      await database.query('DELETE FROM workout_logs WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM meal_logs WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM body_measurements WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM coach_transfer_history WHERE member_id = $1', [memberId]);
      await database.query(
        `DELETE FROM admin_audit_logs WHERE entity_type = 'COACH_RELATIONSHIP'
         AND entity_id IN (SELECT id::text FROM coach_relationships WHERE member_id = $1)`,
        [memberId],
      );
      await database.query('DELETE FROM coach_termination_requests WHERE coach_id = $1', [coachId]);
      await database.query(
        `DELETE FROM conversation_participants WHERE conversation_id IN
         (SELECT c.id FROM conversations c JOIN coach_relationships r
          ON r.id = c.relationship_id WHERE r.member_id = $1)`, [memberId],
      );
      await database.query(
        `DELETE FROM conversations WHERE relationship_id IN
         (SELECT id FROM coach_relationships WHERE member_id = $1)`, [memberId],
      );
      await database.query('DELETE FROM coach_relationships WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM coach_requests WHERE member_id = $1', [memberId]);
      await database.query(
        `DELETE FROM admin_audit_logs WHERE entity_type = 'PAYMENT'
         AND entity_id IN (SELECT id::text FROM payments WHERE member_id = $1)`, [memberId],
      );
      await database.query('DELETE FROM member_memberships WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM payments WHERE member_id = $1', [memberId]);
      if (planId) {
        await database.query('DELETE FROM admin_audit_logs WHERE entity_id = $1', [planId]);
        await database.query('DELETE FROM membership_plans WHERE id = $1', [planId]);
      }
      if (coachId) {
        await database.query('DELETE FROM admin_audit_logs WHERE entity_id = $1', [coachId]);
        await database.query('DELETE FROM coach_profiles WHERE user_id = $1', [coachId]);
        await database.query('DELETE FROM users WHERE id = $1', [coachId]);
      }
      if (secondCoachId) {
        await database.query('DELETE FROM admin_audit_logs WHERE entity_id = $1', [secondCoachId]);
        await database.query('DELETE FROM coach_profiles WHERE user_id = $1', [secondCoachId]);
        await database.query('DELETE FROM users WHERE id = $1', [secondCoachId]);
      }
      await database.query('DELETE FROM admin_audit_logs WHERE entity_id = $1', [memberId]);
      await database.query('DELETE FROM member_profiles WHERE user_id = $1', [memberId]);
      await database.query('DELETE FROM users WHERE id IN ($1, $2)', [adminId, memberId]);
      await database.end();
    }
  });
