import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'web-admin-t7-auth-audit-chat-secret-32-chars';

function token(id, role, sessionVersion = 0) {
  return jwt.sign({ role, sessionVersion }, secret, {
    algorithm: 'HS256',
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    subject: id,
    expiresIn: 3600,
  });
}

async function call(base, path, bearer, method = 'GET', body) {
  const response = await fetch(`${base}/api/v1${path}`, {
    method,
    headers: {
      ...(bearer ? { authorization: `Bearer ${bearer}` } : {}),
      ...(body === undefined ? {} : { 'content-type': 'application/json' }),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: response.status, body: await response.json() };
}

test('T7: Admin audit logs API, privacy redaction, activeAdmin locks, nutrition audit, and disabled chat block',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const app = createApp({ database, jwtSecret: secret });
    const server = app.listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;
    const adminId = randomUUID();
    const memberId = randomUUID();
    const coachId = randomUUID();
    const conversationId = randomUUID();
    const relationshipId = randomUUID();
    const sensitiveAuditId = randomUUID();
    let foodId;
    let equipmentId;
    let exerciseId;
    const adminToken = token(adminId, 'ADMIN', 0);
    const memberToken = token(memberId, 'MEMBER', 0);
    const coachToken = token(coachId, 'COACH', 0);

    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Meta Gym Admin T7'),
                ($3, $4, 'hash', 'MEMBER', 'Member T7'),
                ($5, $6, 'hash', 'COACH', 'Coach T7')`,
        [
          adminId, `${adminId}@example.com`,
          memberId, `${memberId}@example.com`,
          coachId, `${coachId}@example.com`,
        ],
      );
      await database.query('INSERT INTO member_profiles (user_id) VALUES ($1)', [memberId]);
      await database.query('INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 8)', [coachId]);
      await database.query(
        `INSERT INTO gym_profile (id, name, address, opening_hours, updated_by)
         VALUES (1, 'Meta Gym T7', 'Hanoi', '{}'::jsonb, $1)
         ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, updated_by = EXCLUDED.updated_by`,
        [adminId],
      );
      await database.query(
        `INSERT INTO gym_checkin_code (id, code)
         VALUES (1, $1)
         ON CONFLICT (id) DO UPDATE SET code = EXCLUDED.code`,
        [randomUUID()],
      );

      // 1. Role guards on audit-logs
      assert.equal((await call(base, '/admin/audit-logs', memberToken)).status, 403);
      assert.equal((await call(base, '/admin/audit-logs', coachToken)).status, 403);
      assert.equal((await call(base, '/admin/audit-logs?from=2026-11-22&to=2026-11-21', adminToken)).status, 422);
      assert.equal((await call(base, '/admin/audit-logs/not-a-uuid', adminToken)).status, 422);
      assert.equal((await call(base, `/admin/audit-logs/${randomUUID()}`, adminToken)).status, 404);

      // 2. Nutrition foods POST & PATCH write safe audit logs inside transaction
      const createdFood = await call(base, '/admin/nutrition-foods', adminToken, 'POST', {
        name: 'Ức gà T7', kcalPer100g: 165, active: true,
      });
      assert.equal(createdFood.status, 201);
      foodId = createdFood.body.data.id;

      const updatedFood = await call(base, `/admin/nutrition-foods/${foodId}`, adminToken, 'PATCH', {
        name: 'Ức gà luộc T7', kcalPer100g: 170, active: false,
      });
      assert.equal(updatedFood.status, 200);

      const foodAudits = await call(
        base,
        `/admin/audit-logs?entityType=NUTRITION_FOOD&entityId=${foodId}&page=1&pageSize=10`,
        adminToken,
      );
      assert.equal(foodAudits.status, 200);
      assert.equal(foodAudits.body.pagination.totalItems, 2);
      assert.equal(foodAudits.body.data[0].action, 'NUTRITION_FOOD_UPDATED');
      assert.equal(foodAudits.body.data[0].adminName, 'Meta Gym Admin T7');
      assert.equal(foodAudits.body.data[0].metadata.before.kcalPer100g, 165);
      assert.equal(foodAudits.body.data[0].metadata.after.kcalPer100g, 170);
      assert.equal(foodAudits.body.data[1].action, 'NUTRITION_FOOD_CREATED');
      assert.equal(foodAudits.body.data[1].metadata.after.name, 'Ức gà T7');

      // 3. Privacy redaction on GET /admin/audit-logs and GET /admin/audit-logs/:logId
      await database.query(
        `INSERT INTO admin_audit_logs
         (id, admin_id, action, entity_type, entity_id, summary, metadata, created_at)
         VALUES ($1, $2, 'PRIVACY_REDACTION_TEST', 'USER', $3, 'Test redaction', $4::jsonb,
           '2026-11-21T17:30:00Z'::timestamptz)`,
        [
          sensitiveAuditId,
          adminId,
          memberId,
          JSON.stringify({
            safeNote: 'kept',
            temporaryPassword: 'TempPass123!',
            passwordHash: '$2b$12$secret',
            password_hash: '$2b$12$secret2',
            healthNotes: 'Sensitive health note',
            injury_notes: 'Knee injury',
            messages: ['private dm'],
            journal: { chestCm: 90 },
            nested: {
              ok: true,
              temporaryPassword: 'NestedSecret',
              fitnessGoal: 'Hidden goal',
              storageKey: 'private/key',
            },
          }),
        ],
      );
      // 2026-11-21T17:30:00Z is 2026-11-22 00:30:00 +07:00 (Asia/Ho_Chi_Minh)
      const vnDateFiltered = await call(
        base,
        '/admin/audit-logs?action=PRIVACY_REDACTION_TEST&from=2026-11-22&to=2026-11-22&search=Meta%20Gym%20Admin',
        adminToken,
      );
      assert.equal(vnDateFiltered.status, 200);
      assert.equal(vnDateFiltered.body.pagination.totalItems, 1);
      const listItem = vnDateFiltered.body.data[0];
      assert.equal(listItem.id, sensitiveAuditId);
      assert.equal(listItem.adminName, 'Meta Gym Admin T7');
      assert.deepEqual(listItem.metadata, { safeNote: 'kept', nested: { ok: true } });

      // Filtering on 2026-11-21 VN must NOT include 2026-11-21T17:30:00Z (= 2026-11-22 VN)
      const wrongDay = await call(
        base,
        '/admin/audit-logs?action=PRIVACY_REDACTION_TEST&from=2026-11-21&to=2026-11-21',
        adminToken,
      );
      assert.equal(wrongDay.body.pagination.totalItems, 0);

      const detail = await call(base, `/admin/audit-logs/${sensitiveAuditId}`, adminToken);
      assert.equal(detail.status, 200);
      assert.deepEqual(detail.body.data.metadata, { safeNote: 'kept', nested: { ok: true } });
      const rawDetailJson = JSON.stringify(detail.body);
      for (const forbidden of [
        'temporaryPassword', 'passwordHash', 'password_hash',
        'healthNotes', 'injury_notes', 'messages', 'journal', 'fitnessGoal', 'storageKey',
      ]) {
        assert.equal(rawDetailJson.includes(forbidden), false, `Must redact ${forbidden}`);
      }

      // 4. activeAdmin FOR SHARE check on catalog, gym-visits, nutrition-foods
      const eq = await call(base, '/admin/equipment', adminToken, 'POST', {
        name: 'Rack T7', category: 'Strength', targetMuscles: ['Legs'],
        usageSteps: ['Set safety pins'], status: 'ACTIVE',
      });
      assert.equal(eq.status, 201);
      equipmentId = eq.body.data.id;

      const ex = await call(base, '/admin/exercises', adminToken, 'POST', {
        equipmentId, name: 'Squat T7', instructions: 'Squat with control', status: 'ACTIVE',
      });
      assert.equal(ex.status, 201);
      exerciseId = ex.body.data.id;

      const rotatedOk = await call(base, '/admin/gym-checkin-code/rotate', adminToken, 'POST', {});
      assert.equal(rotatedOk.status, 200);

      // Revoke admin session via session_version bump and verify writes fail 401 cleanly
      await database.query('UPDATE users SET session_version = session_version + 1 WHERE id = $1', [adminId]);
      assert.equal((await call(base, '/admin/nutrition-foods', adminToken, 'POST', {
        name: 'Should Fail', kcalPer100g: 50, active: true,
      })).status, 401);
      assert.equal((await call(base, `/admin/nutrition-foods/${foodId}`, adminToken, 'PATCH', {
        name: 'Should Fail', kcalPer100g: 50, active: true,
      })).status, 401);
      assert.equal((await call(base, '/admin/gym-profile', adminToken, 'PATCH', {
        name: 'Should Fail',
      })).status, 401);
      assert.equal((await call(base, `/admin/equipment/${equipmentId}`, adminToken, 'PATCH', {
        status: 'HIDDEN',
      })).status, 401);
      assert.equal((await call(base, `/admin/exercises/${exerciseId}`, adminToken, 'PATCH', {
        status: 'HIDDEN',
      })).status, 401);
      assert.equal((await call(base, '/admin/gym-checkin-code/rotate', adminToken, 'POST', {})).status, 401);

      // 5. Messaging S5: block POST messages when recipient is DISABLED, keep GET readable
      await database.query(
        'INSERT INTO coach_relationships (id, member_id, coach_id) VALUES ($1, $2, $3)',
        [relationshipId, memberId, coachId],
      );
      await database.query(
        'INSERT INTO conversations (id, relationship_id, member_id, coach_id) VALUES ($1, $2, $3, $4)',
        [conversationId, relationshipId, memberId, coachId],
      );
      await database.query(
        'INSERT INTO conversation_participants (conversation_id, user_id) VALUES ($1, $2), ($1, $3)',
        [conversationId, memberId, coachId],
      );

      const sentBeforeLock = await call(base, `/conversations/${relationshipId}/messages`, memberToken, 'POST', {
        messageType: 'TEXT', clientMessageId: randomUUID(), content: 'Chào Coach trước khi khóa',
      });
      assert.equal(sentBeforeLock.status, 201);

      // Lock Coach -> Member tries to send message -> 403 RECIPIENT_ACCOUNT_DISABLED
      await database.query(
        `UPDATE users SET status = 'DISABLED', disabled_at = now(), disabled_reason = 'Tạm khóa Coach'
         WHERE id = $1`,
        [coachId],
      );
      const blockedSend = await call(base, `/conversations/${relationshipId}/messages`, memberToken, 'POST', {
        messageType: 'TEXT', clientMessageId: randomUUID(), content: 'Gửi khi Coach bị khóa',
      });
      assert.equal(blockedSend.status, 403);
      assert.equal(blockedSend.body.error.code, 'RECIPIENT_ACCOUNT_DISABLED');
      assert.equal(
        blockedSend.body.error.message,
        'Không thể gửi tin nhắn vì tài khoản người nhận đang bị khóa',
      );
      // Opening a new conversation with disabled Coach is blocked
      assert.equal((await call(base, '/conversations', memberToken, 'POST', { coachId })).status, 404);
      // History remains readable
      const convList = await call(base, '/conversations', memberToken);
      assert.equal(convList.status, 200);
      assert.equal(convList.body.data.length, 1);
      const history = await call(base, `/conversations/${relationshipId}/messages`, memberToken);
      assert.equal(history.status, 200);
      assert.equal(history.body.data.length, 1);
      assert.equal(history.body.data[0].content, 'Chào Coach trước khi khóa');

      // Re-enable Coach, disable Member -> Coach blocked from sending, history readable
      await database.query(
        `UPDATE users SET status = 'ACTIVE', disabled_at = NULL, disabled_reason = NULL WHERE id = $1`,
        [coachId],
      );
      await database.query(
        `UPDATE users SET status = 'DISABLED', disabled_at = now(), disabled_reason = 'Tạm khóa Member'
         WHERE id = $1`,
        [memberId],
      );
      const coachBlockedSend = await call(base, `/conversations/${relationshipId}/messages`, coachToken, 'POST', {
        messageType: 'TEXT', clientMessageId: randomUUID(), content: 'Gửi khi Member bị khóa',
      });
      assert.equal(coachBlockedSend.status, 403);
      assert.equal(coachBlockedSend.body.error.code, 'RECIPIENT_ACCOUNT_DISABLED');
      assert.equal((await call(base, `/conversations/${relationshipId}/messages`, coachToken)).body.data.length, 1);
    } finally {
      await database.query('UPDATE conversation_participants SET last_read_message_id = NULL WHERE conversation_id = $1', [conversationId]);
      await database.query('DELETE FROM messages WHERE conversation_id = $1', [conversationId]);
      await database.query('DELETE FROM conversation_participants WHERE conversation_id = $1', [conversationId]);
      await database.query('DELETE FROM conversations WHERE id = $1', [conversationId]);
      await database.query('DELETE FROM coach_relationships WHERE id = $1', [relationshipId]);
      await database.query('DELETE FROM admin_audit_logs WHERE admin_id = $1', [adminId]);
      if (foodId) await database.query('DELETE FROM nutrition_foods WHERE id = $1', [foodId]);
      if (exerciseId) await database.query('DELETE FROM exercises WHERE id = $1', [exerciseId]);
      if (equipmentId) await database.query('DELETE FROM equipment WHERE id = $1', [equipmentId]);
      await database.query('DELETE FROM gym_profile WHERE updated_by = $1', [adminId]);
      await database.query('DELETE FROM coach_profiles WHERE user_id = $1', [coachId]);
      await database.query('DELETE FROM member_profiles WHERE user_id = $1', [memberId]);
      await database.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [[adminId, memberId, coachId]]);
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });
