import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'training-integration-secret-with-32-characters';

function token(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, secret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
    subject: id, expiresIn: 3600,
  });
}

async function call(app, path, bearer, method = 'GET', body) {
  const server = app.listen(0);
  try {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/api/v1${path}`, {
      method, headers: { authorization: `Bearer ${bearer}`,
        ...(body === undefined ? {} : { 'content-type': 'application/json' }) },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    return { status: response.status, body: await response.json() };
  } finally { await new Promise((resolve) => server.close(resolve)); }
}

test('PostgreSQL training plans stay private until published and preserve snapshots',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const memberId = randomUUID();
    const secondMemberId = randomUUID();
    const coachId = randomUUID();
    const relationshipId = randomUUID();
    const returnRelationshipId = randomUUID();
    const conversationId = randomUUID();
    const exerciseId = randomUUID();
    const app = createApp({ database, jwtSecret: secret });
    const aiApp = createApp({ database, jwtSecret: secret,
      aiResponder: async ({ content }) => ({
        content: `Test reply: ${content}`, provider: 'TEST', modelName: 'mock',
      }) });
    const callApp = createApp({ database, jwtSecret: secret,
      callTokenProvider: async ({ callId }) => ({
        accessToken: 'test-token', providerCallId: callId,
        channelId: callId,
        expiresAt: new Date(Date.now() + 5 * 60 * 1000).toISOString(),
      }) });
    const racingCallApp = createApp({ database, jwtSecret: secret,
      callTokenProvider: async ({ callId, relationshipId: activeRelationshipId }) => {
        await database.query(
          `UPDATE coach_relationships SET status = 'PAUSED', paused_at = now(),
           pause_reason = 'MEMBERSHIP_EXPIRED' WHERE id = $1`,
          [activeRelationshipId],
        );
        return { accessToken: 'must-not-be-returned', providerCallId: callId,
          channelId: callId,
          expiresAt: new Date(Date.now() + 5 * 60 * 1000).toISOString() };
      } });
    let signalProviderStarted;
    let releaseProvider;
    const providerStarted = new Promise((resolve) => { signalProviderStarted = resolve; });
    const providerRelease = new Promise((resolve) => { releaseProvider = resolve; });
    const revocationCallApp = createApp({ database, jwtSecret: secret,
      callTokenProvider: async ({ callId }) => {
        signalProviderStarted();
        await providerRelease;
        return { accessToken: 'must-not-be-returned', providerCallId: callId,
          channelId: callId,
          expiresAt: new Date(Date.now() + 5 * 60 * 1000).toISOString() };
      } });
    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'MEMBER', 'Member'),
                ($3, $4, 'hash', 'MEMBER', 'Other'),
                ($5, $6, 'hash', 'COACH', 'Coach')`,
        [memberId, `${memberId}@example.com`, secondMemberId,
          `${secondMemberId}@example.com`, coachId, `${coachId}@example.com`],
      );
      await database.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id)
         VALUES ($1, $2, $3)`, [relationshipId, memberId, coachId],
      );
      await database.query('INSERT INTO conversations (id, relationship_id) VALUES ($1, $2)',
        [conversationId, relationshipId]);
      await database.query(
        `INSERT INTO conversation_participants (conversation_id, user_id)
         VALUES ($1, $2), ($1, $3)`, [conversationId, memberId, coachId],
      );
      await database.query(
        `INSERT INTO exercises (id, name, instructions, status, created_by)
         VALUES ($1, 'Squat', 'Keep your back straight', 'ACTIVE', $2)`,
        [exerciseId, coachId],
      );
      const coach = token(coachId, 'COACH');
      const member = token(memberId, 'MEMBER');
      const other = token(secondMemberId, 'MEMBER');
      let ai = await call(app, '/ai-conversations', member, 'POST',
        { title: 'Training questions' });
      assert.equal(ai.status, 201);
      const aiId = ai.body.data.id;
      assert.equal((await call(app, '/ai-conversations', other)).body.data.length, 0);
      assert.equal((await call(app, `/ai-conversations/${aiId}`, other)).status, 404);
      ai = await call(app, `/ai-conversations/${aiId}`, member, 'PATCH',
        { title: 'Nutrition questions' });
      assert.equal(ai.status, 200);
      assert.equal(ai.body.data.title, 'Nutrition questions');
      assert.equal((await call(app, `/ai-conversations/${aiId}/messages`, member)).body.data.length, 0);
      const aiRequest = { clientRequestId: randomUUID(), content: 'How to train?' };
      assert.equal((await call(app, `/ai-conversations/${aiId}/messages`, member,
        'POST', aiRequest)).status, 503);
      ai = await call(aiApp, `/ai-conversations/${aiId}/messages`, member,
        'POST', aiRequest);
      assert.equal(ai.status, 201);
      assert.equal(ai.body.data.reply.content, 'Test reply: How to train?');
      assert.equal((await call(aiApp, `/ai-conversations/${aiId}/messages`, member,
        'POST', aiRequest)).status, 200);
      assert.equal((await call(aiApp, `/ai-conversations/${aiId}/messages`, member,
        'POST', { ...aiRequest, content: 'Different' })).status, 409);
      assert.equal((await call(app, `/ai-conversations/${aiId}/messages`, member)).body.data.length, 2);
      assert.equal((await call(app, `/ai-conversations/${aiId}`, member, 'DELETE')).status, 200);
      assert.equal((await call(app, `/ai-conversations/${aiId}`, member)).status, 404);
      const body = { title: 'Strength basics', goal: 'Improve strength', days: [
        { dayNumber: 1, title: 'Monday', exercises: [
          { exerciseId, displayOrder: 1, sets: 3, reps: '10' },
        ] },
      ] };
      assert.equal((await call(app, `/coach/members/${memberId}/training-plans`, member,
        'POST', body)).status, 403);
      assert.equal((await call(app, `/coach/members/${secondMemberId}/training-plans`, coach,
        'POST', body)).status, 403);
      let result = await call(app, `/coach/members/${memberId}/training-plans`, coach,
        'POST', body);
      assert.equal(result.status, 201);
      const planId = result.body.data.id;
      assert.equal(result.body.data.status, 'DRAFT');
      assert.equal(result.body.data.days[0].exercises[0].exerciseName, 'Squat');
      result = await call(app, `/coach/training-plans/${planId}`, coach,
        'PATCH', { goal: 'Build consistency' });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.goal, 'Build consistency');
      assert.equal(result.body.data.days.length, 1);
      assert.equal((await call(app, `/training-plans/${planId}`, member)).status, 404);
      assert.equal((await call(app, '/training-plans/me/active', member)).body.data, null);
      assert.equal((await call(app, `/training-plans/${planId}`, other)).status, 404);
      result = await call(app, `/coach/training-plans/${planId}/publications`, coach, 'POST', {});
      assert.equal(result.status, 200);
      assert.equal(result.body.data.status, 'ACTIVE');
      assert.equal((await call(app, `/training-plans/${planId}`, member)).status, 200);
      assert.equal((await call(app, '/training-plans/me/active', member)).body.data.id, planId);
      assert.equal((await call(app, `/coach/training-plans/${planId}`, coach,
        'PATCH', body)).status, 409);
      await database.query("UPDATE exercises SET name = 'Renamed Squat' WHERE id = $1", [exerciseId]);
      assert.equal((await call(app, `/training-plans/${planId}`, member)).body.data.days[0]
        .exercises[0].exerciseName, 'Squat');
      const planDrafts = await Promise.all(['Second plan', 'Third plan'].map((title) =>
        call(app, `/coach/members/${memberId}/training-plans`, coach,
          'POST', { ...body, title })));
      assert.deepEqual(planDrafts.map((item) => item.status), [201, 201]);
      const planPublications = await Promise.all(planDrafts.map((item) =>
        call(app, `/coach/training-plans/${item.body.data.id}/publications`, coach,
          'POST', {})));
      assert.deepEqual(planPublications.map((item) => item.status), [200, 200]);
      assert.equal((await database.query(
        `SELECT count(*)::int AS count FROM training_plans
         WHERE member_id = $1 AND status = 'ACTIVE'`, [memberId])).rows[0].count, 1);
      assert.equal((await call(app, '/training-plans/me/history', member)).body.data.length, 3);
      result = await call(app, `/coach/members/${memberId}/nutrition-guides`, coach,
        'POST', { title: 'Balanced meals', content: 'Eat sufficient protein.' });
      assert.equal(result.status, 201);
      const guideId = result.body.data.id;
      assert.equal((await call(app, '/nutrition-guides/me/active', member)).body.data, null);
      result = await call(app, `/coach/nutrition-guides/${guideId}`, coach,
        'PATCH', { publish: true });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.status, 'ACTIVE');
      assert.equal((await call(app, '/nutrition-guides/me/active', member)).body.data.id, guideId);
      assert.equal((await call(app, '/nutrition-guides/me/history', other)).body.data.length, 0);
      assert.equal((await call(app, `/coach/nutrition-guides/${guideId}`, coach,
        'PATCH', { content: 'Changed' })).status, 409);
      const guideDrafts = await Promise.all(['Second guide', 'Third guide'].map((title) =>
        call(app, `/coach/members/${memberId}/nutrition-guides`, coach,
          'POST', { title, content: 'Eat well.' })));
      assert.deepEqual(guideDrafts.map((item) => item.status), [201, 201]);
      const guidePublications = await Promise.all(guideDrafts.map((item) =>
        call(app, `/coach/nutrition-guides/${item.body.data.id}`, coach,
          'PATCH', { publish: true })));
      assert.deepEqual(guidePublications.map((item) => item.status), [200, 200]);
      assert.equal((await database.query(
        `SELECT count(*)::int AS count FROM nutrition_guides
         WHERE member_id = $1 AND status = 'ACTIVE'`, [memberId])).rows[0].count, 1);
      assert.equal((await call(app, '/nutrition-guides/me/history', member)).body.data.length, 3);
      assert.equal((await call(app, '/coach/training-sessions', coach, 'POST', {
        memberId, title: 'Invalid time',
        scheduledStartAt: '2026-11-01T09:00:00+07:00',
        scheduledEndAt: '2026-11-01T08:00:00+07:00',
      })).status, 422);
      result = await call(app, '/coach/training-sessions', coach, 'POST', {
        memberId, title: 'Session one', scheduledStartAt: '2026-11-01T08:00:00+07:00',
        scheduledEndAt: '2026-11-01T09:00:00+07:00',
      });
      assert.equal(result.status, 201);
      const sessionId = result.body.data.id;
      assert.equal((await call(app, `/training-sessions/${sessionId}`, other)).status, 404);
      assert.equal((await call(app, '/training-sessions/me', member)).body.data.length, 1);
      assert.equal((await call(app, '/coach/training-sessions', coach)).body.data.length, 1);
      assert.equal((await call(app, `/coach/training-sessions/${sessionId}`, coach,
        'PATCH', { status: 'CANCELLED' })).status, 422);
      assert.equal((await call(app, `/coach/training-sessions/${sessionId}`, coach,
        'PATCH', { scheduledEndAt: '2026-11-01T07:00:00+07:00' })).status, 422);
      assert.equal((await call(app, `/coach/training-sessions/${sessionId}`, member,
        'PATCH', { status: 'COMPLETED' })).status, 403);
      result = await call(app, `/coach/training-sessions/${sessionId}`, coach,
        'PATCH', { status: 'COMPLETED' });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.status, 'COMPLETED');
      assert.equal((await call(app, `/coach/training-sessions/${sessionId}`, coach,
        'PATCH', { title: 'Late edit' })).status, 409);
      const clientMessageId = randomUUID();
      const message = { messageType: 'TEXT', clientMessageId, content: 'How is training?' };
      result = await call(app, `/conversations/${relationshipId}/messages`, coach,
        'POST', message);
      assert.equal(result.status, 201);
      const messageId = result.body.data.id;
      assert.equal((await call(app, `/conversations/${relationshipId}/messages`, coach,
        'POST', message)).body.data.id, messageId);
      assert.equal((await call(app, `/conversations/${relationshipId}/messages`, coach,
        'POST', { ...message, content: 'Different' })).status, 409);
      assert.equal((await call(app, `/conversations/${relationshipId}/messages`, other)).status, 404);
      assert.equal((await call(app, '/conversations', member)).body.data[0].unreadCount, 1);
      result = await call(app, `/conversations/${relationshipId}/read-state`, member,
        'PATCH', { messageId });
      assert.equal(result.status, 200);
      assert.equal(result.body.data.lastReadMessageId, messageId);
      assert.equal((await call(app, '/conversations', member)).body.data[0].unreadCount, 0);
      result = await call(app, '/calls', member, 'POST', {
        relationshipId, callType: 'VOICE',
      });
      assert.equal(result.status, 201);
      const callId = result.body.data.id;
      assert.equal(result.body.data.receiverId, coachId);
      assert.equal((await call(app, `/calls/${callId}/access-tokens`, member,
        'POST', {})).status, 503);
      assert.equal((await call(callApp, `/calls/${callId}/access-tokens`, other,
        'POST', {})).status, 404);
      result = await call(racingCallApp, `/calls/${callId}/access-tokens`, member,
        'POST', {});
      assert.equal(result.status, 409, JSON.stringify(result.body));
      assert.equal((await database.query(
        'SELECT provider_call_id FROM call_logs WHERE id = $1', [callId]))
        .rows[0].provider_call_id, null);
      await database.query(
        `UPDATE coach_relationships SET status = 'ACTIVE', paused_at = NULL,
         pause_reason = NULL WHERE id = $1`, [relationshipId],
      );
      result = await call(callApp, `/calls/${callId}/access-tokens`, member,
        'POST', {});
      assert.equal(result.status, 200);
      assert.equal(result.body.data.channelId, callId);
      assert.equal((await call(app, `/calls/${callId}`, member,
        'PATCH', { status: 'ANSWERED' })).status, 409);
      assert.equal((await call(app, `/calls/${callId}`, coach,
        'PATCH', { status: 'ANSWERED' })).status, 409);
      assert.equal((await call(app, `/calls/${callId}`, member,
        'PATCH', { status: 'RINGING' })).status, 200);
      assert.equal((await call(app, `/calls/${callId}`, coach,
        'PATCH', { status: 'ANSWERED' })).status, 200);
      assert.equal((await call(app, `/calls/${callId}`, member,
        'PATCH', { status: 'ENDED' })).status, 200);
      assert.equal((await call(app, '/calls', other)).body.data.length, 0);
      assert.equal((await call(app, '/calls', coach)).body.data.length, 1);
      const pausedPlan = await call(app, `/coach/members/${memberId}/training-plans`,
        coach, 'POST', { ...body, title: 'Pending plan' });
      const pausedGuide = await call(app, `/coach/members/${memberId}/nutrition-guides`,
        coach, 'POST', { title: 'Pending guide', content: 'Pending content' });
      assert.equal(pausedPlan.status, 201);
      assert.equal(pausedGuide.status, 201);
      await database.query(
        `UPDATE coach_relationships SET status = 'PAUSED', paused_at = now(),
         pause_reason = 'MEMBERSHIP_EXPIRED' WHERE id = $1`, [relationshipId],
      );
      assert.equal((await call(app, `/coach/training-plans/${pausedPlan.body.data.id}`,
        coach, 'PATCH', { title: 'Edit after pause' })).status, 403);
      assert.equal((await call(app,
        `/coach/training-plans/${pausedPlan.body.data.id}/publications`,
        coach, 'POST', {})).status, 409);
      assert.equal((await call(app, `/coach/nutrition-guides/${pausedGuide.body.data.id}`,
        coach, 'PATCH', { publish: true })).status, 403);
      assert.equal((await call(app, `/coach/members/${memberId}/training-plans`, coach,
        'POST', body)).status, 403);
      assert.equal((await call(app, '/coach/training-sessions', coach, 'POST', {
        memberId, title: 'Denied', scheduledStartAt: '2026-11-02T08:00:00+07:00',
      })).status, 403);
      assert.equal((await call(app, `/conversations/${relationshipId}/messages`, coach,
        'POST', { ...message, clientMessageId: randomUUID() })).status, 403);
      assert.equal((await call(app, '/calls', member, 'POST', {
        relationshipId, callType: 'VIDEO',
      })).status, 404);
      await database.query(
        `UPDATE coach_relationships SET status = 'ACTIVE', paused_at = NULL,
         pause_reason = NULL WHERE id = $1`, [relationshipId],
      );
      result = await call(app, '/calls', member, 'POST', {
        relationshipId, callType: 'VOICE',
      });
      assert.equal(result.status, 201);
      const revokedCallId = result.body.data.id;
      const pendingToken = call(revocationCallApp,
        `/calls/${revokedCallId}/access-tokens`, member, 'POST', {});
      await providerStarted;
      const revocation = await database.connect();
      try {
        await revocation.query('BEGIN');
        await revocation.query(
          `UPDATE users SET status = 'DISABLED', disabled_at = now(),
           disabled_reason = 'Integration test',
           session_version = session_version + 1 WHERE id = $1`, [memberId],
        );
        releaseProvider();
        await new Promise((resolve) => setTimeout(resolve, 25));
        assert.equal(await Promise.race([
          pendingToken.then(() => 'settled'),
          new Promise((resolve) => setTimeout(() => resolve('blocked'), 25)),
        ]), 'blocked');
        await revocation.query('COMMIT');
      } catch (error) {
        await revocation.query('ROLLBACK').catch(() => {});
        throw error;
      } finally {
        revocation.release();
      }
      result = await pendingToken;
      assert.equal(result.status, 409, JSON.stringify(result.body));
      assert.equal((await database.query(
        'SELECT provider_call_id FROM call_logs WHERE id = $1', [revokedCallId]))
        .rows[0].provider_call_id, null);
      await database.query(
        `UPDATE users SET status = 'ACTIVE', disabled_at = NULL,
         disabled_reason = NULL, session_version = 0 WHERE id = $1`, [memberId],
      );
      await database.query(
        `UPDATE coach_relationships SET status = 'ENDED', ended_at = now(),
         ended_by = $2, end_reason = 'Return later' WHERE id = $1`,
        [relationshipId, memberId],
      );
      await database.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id)
         VALUES ($1, $2, $3)`, [returnRelationshipId, memberId, coachId],
      );
      assert.equal((await call(app,
        `/coach/training-plans/${pausedPlan.body.data.id}/publications`,
        coach, 'POST', {})).status, 409);
      assert.equal((await call(app, `/coach/nutrition-guides/${pausedGuide.body.data.id}`,
        coach, 'PATCH', { publish: true })).status, 403);
    } finally {
      await database.query('DELETE FROM call_logs WHERE relationship_id = $1', [relationshipId]);
      await database.query(
        `DELETE FROM ai_messages WHERE conversation_id IN
         (SELECT id FROM ai_conversations WHERE user_id = $1) AND role = 'ASSISTANT'`,
        [memberId],
      );
      await database.query(
        `DELETE FROM ai_messages WHERE conversation_id IN
         (SELECT id FROM ai_conversations WHERE user_id = $1)`, [memberId],
      );
      await database.query('DELETE FROM ai_conversations WHERE user_id = $1', [memberId]);
      await database.query('UPDATE conversation_participants SET last_read_message_id = NULL WHERE conversation_id = $1',
        [conversationId]);
      await database.query('DELETE FROM messages WHERE conversation_id = $1', [conversationId]);
      await database.query('DELETE FROM conversation_participants WHERE conversation_id = $1', [conversationId]);
      await database.query('DELETE FROM conversations WHERE id = $1', [conversationId]);
      await database.query('DELETE FROM training_sessions WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM nutrition_guides WHERE member_id = $1', [memberId]);
      await database.query(
        `DELETE FROM training_plan_exercises WHERE plan_day_id IN
         (SELECT id FROM training_plan_days WHERE plan_id IN
          (SELECT id FROM training_plans WHERE member_id = $1))`, [memberId],
      );
      await database.query(
        `DELETE FROM training_plan_days WHERE plan_id IN
         (SELECT id FROM training_plans WHERE member_id = $1)`, [memberId],
      );
      await database.query('DELETE FROM training_plans WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM exercises WHERE id = $1', [exerciseId]);
      await database.query('DELETE FROM coach_relationships WHERE id IN ($1, $2)',
        [relationshipId, returnRelationshipId]);
      await database.query('DELETE FROM users WHERE id IN ($1, $2, $3)',
        [memberId, secondMemberId, coachId]);
      await database.end();
    }
  });
