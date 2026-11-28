import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';
import sharp from 'sharp';

import { createApp } from '../src/app.js';
import { reconcileMembershipLifecycles } from '../src/services/membership-lifecycle.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'web-admin-t18-security-privacy-invariants-32c';

const FORBIDDEN_ADMIN_KEYS = new Set([
  'password',
  'passwordhash',
  'temporarypassword',
  'codehash',
  'accesstoken',
  'jwt',
  'healthnotes',
  'injurynotes',
  'heightcm',
  'weightkg',
  'bodyfatpercent',
  'fitnessgoal',
  'dietarypreferences',
  'dateofbirth',
  'healthdeclarationcompletedat',
  'journal',
  'chestcm',
  'waistcm',
  'hipscm',
  'achievements',
  'messages',
  'messagecontent',
  'aimessages',
  'meallogs',
  'membernutritiondays',
  'progressphotos',
  'storagekey',
  'privatenotes',
  'chatmessages',
]);

function signToken(id, role, sessionVersion = 0) {
  return jwt.sign({ role, sessionVersion }, secret, {
    algorithm: 'HS256',
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    subject: id,
    expiresIn: 3600,
  });
}

async function api(base, path, bearer, method = 'GET', body, headers = {}) {
  const response = await fetch(`${base}/api/v1${path}`, {
    method,
    headers: {
      ...(bearer ? { authorization: `Bearer ${bearer}` } : {}),
      ...headers,
      ...(body === undefined ? {} : { 'content-type': 'application/json' }),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const text = await response.text();
  let parsed = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    parsed = text;
  }
  return { status: response.status, body: parsed };
}

function createMemoryImageStorage() {
  const store = new Map();
  return {
    async put(key, bytes) {
      store.set(key, Buffer.from(bytes));
    },
    async get(key) {
      return store.get(key) ?? null;
    },
    async remove(key) {
      store.delete(key);
    },
  };
}

function collectObjectKeys(value, out = []) {
  if (Array.isArray(value)) {
    for (const item of value) collectObjectKeys(item, out);
    return out;
  }
  if (value && typeof value === 'object') {
    for (const [key, entry] of Object.entries(value)) {
      out.push(key);
      collectObjectKeys(entry, out);
    }
  }
  return out;
}

function assertNoForbiddenAdminLeak(label, payload, secretStrings = []) {
  const keys = collectObjectKeys(payload);
  for (const key of keys) {
    const normalized = key.toLowerCase().replaceAll('_', '');
    assert.equal(
      FORBIDDEN_ADMIN_KEYS.has(normalized),
      false,
      `${label} must not expose forbidden key "${key}"`,
    );
  }
  const serialized = JSON.stringify(payload);
  for (const needle of secretStrings) {
    assert.equal(
      serialized.includes(needle),
      false,
      `${label} must not leak sensitive value "${needle}"`,
    );
  }
}

async function insertWeeklySchedule(database, coachId, weekdays = [1, 2, 3, 4, 5, 6, 7]) {
  await database.query(
    `INSERT INTO coach_weekly_slots (id, coach_id, weekday, start_minute)
     SELECT gen_random_uuid(), $1, day, minute
     FROM unnest($2::int[]) AS day
     CROSS JOIN generate_series(360, 1170, 90) AS minute`,
    [coachId, weekdays],
  );
}

async function insertActiveGymMembership(database, memberId, planId, amount = 500000, durationDays = 30) {
  const paymentId = randomUUID();
  const membershipId = randomUUID();
  await database.query(
    `INSERT INTO payments (
       id, member_id, plan_id, plan_name_snapshot, duration_days_snapshot,
       amount, method, status, transaction_code, idempotency_key,
       request_hash, created_by, confirmed_at, decided_at
     ) VALUES (
       $1, $2, $3, 'Gym T18 Plan', $4,
       $5, 'MOCK_QR', 'SUCCESS', $1::uuid::text, $1::uuid::text,
       repeat('a', 64), $2, now(), now()
     )`,
    [paymentId, memberId, planId, durationDays, amount],
  );
  await database.query(
    `INSERT INTO member_memberships (
       id, member_id, plan_id, source_payment_id,
       start_date, end_date, status, activated_at
     ) VALUES (
       $1, $2, $3, $4,
       (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
       (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + ($5::int - 1),
       'ACTIVE', now()
     )`,
    [membershipId, memberId, planId, paymentId, durationDays],
  );
  return { paymentId, membershipId };
}

async function cleanupUsers(database, userIds) {
  if (!userIds.length) return;
  await database.query('DELETE FROM simulated_refunds WHERE member_id = ANY($1::uuid[]) OR coach_id = ANY($1::uuid[]) OR created_by = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM payment_adjustments WHERE member_id = ANY($1::uuid[]) OR created_by = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM coach_lock_incidents WHERE member_id = ANY($1::uuid[]) OR coach_id = ANY($1::uuid[]) OR locked_by = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM coach_notifications WHERE user_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM coach_bookings WHERE member_id = ANY($1::uuid[]) OR coach_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM coach_slot_blocks WHERE coach_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM coach_entitlements WHERE member_id = ANY($1::uuid[]) OR coach_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM coach_payment_holds WHERE member_id = ANY($1::uuid[]) OR coach_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM coach_weekly_slots WHERE coach_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM coach_termination_requests WHERE requested_by_user_id = ANY($1::uuid[]) OR counterparty_user_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM coach_transfer_history WHERE member_id = ANY($1::uuid[]) OR old_coach_id = ANY($1::uuid[]) OR new_coach_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM coach_outcome_cases WHERE member_id = ANY($1::uuid[]) OR coach_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM messages WHERE sender_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM conversation_participants WHERE user_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM conversations WHERE member_id = ANY($1::uuid[]) OR coach_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM ai_messages WHERE conversation_id IN (SELECT id FROM ai_conversations WHERE user_id = ANY($1::uuid[]))', [userIds]);
  await database.query('DELETE FROM ai_conversations WHERE user_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM member_journal_photos WHERE member_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM member_journal_entries WHERE member_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM member_nutrition_days WHERE member_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM meal_logs WHERE member_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM member_self_training_days WHERE member_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM body_measurements WHERE member_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM workout_logs WHERE member_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM progress_photos WHERE member_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM training_plans WHERE member_id = ANY($1::uuid[]) OR coach_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM nutrition_guides WHERE member_id = ANY($1::uuid[]) OR coach_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM coach_relationships WHERE member_id = ANY($1::uuid[]) OR coach_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM member_memberships WHERE member_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM payments WHERE member_id = ANY($1::uuid[]) OR created_by = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM admin_audit_logs WHERE admin_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM media_assets WHERE owner_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM exercises WHERE created_by = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM equipment WHERE created_by = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM membership_plans WHERE created_by = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM coach_profiles WHERE user_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM member_profiles WHERE user_id = ANY($1::uuid[])', [userIds]);
  await database.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [userIds]);
}

// ============================================================================
// GROUP 1: Role Privacy Matrix (T3 §3.1 & §3.2)
// ============================================================================
test('T18 Group 1: Role Privacy Matrix — ADMIN blocks, zero field leakage, COACH D4/unrelated blocks, MEMBER/COACH admin blocks',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const imageStorage = createMemoryImageStorage();
    const server = createApp({ database, jwtSecret: secret, imageStorage }).listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;

    const adminId = randomUUID();
    const coachId = randomUUID();
    const memberId = randomUUID();
    const unrelatedMemberId = randomUUID();
    const allUsers = [adminId, coachId, memberId, unrelatedMemberId];

    const planId = randomUUID();
    const relationshipId = randomUUID();
    const entitlementId = randomUUID();
    const holdId = randomUUID();
    const conversationId = randomUUID();
    const aiConversationId = randomUUID();
    const sensitiveAuditId = randomUUID();

    const adminToken = signToken(adminId, 'ADMIN');
    const coachToken = signToken(coachId, 'COACH');
    const memberToken = signToken(memberId, 'MEMBER');

    const sensitiveTokens = [
      'SECRET_INJURY_T18_KNEE',
      'SECRET_HEALTH_T18_ASTHMA',
      'SECRET_GOAL_T18_SHRED',
      'SECRET_DIET_T18_KETO',
      'SECRET_JOURNAL_T18_NOTE',
      'SECRET_MEAL_T18_SALMON',
      'SECRET_CHAT_T18_DM',
      'SECRET_AI_T18_PROMPT',
      'TempPassT18Secret!',
      '$2b$12$T18SecretHashValue',
    ];

    try {
      for (const [id, role, name] of [
        [adminId, 'ADMIN', 'Admin T18 Privacy'],
        [coachId, 'COACH', 'Coach T18 Privacy'],
        [memberId, 'MEMBER', 'Member T18 Privacy'],
        [unrelatedMemberId, 'MEMBER', 'Unrelated Member T18'],
      ]) {
        await database.query(
          `INSERT INTO users (id, email, password_hash, role, full_name)
           VALUES ($1, $2, '$2b$12$T18SecretHashValue', $3, $4)`,
          [id, `${id}@example.com`, role, name],
        );
      }

      await database.query('INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 8)', [coachId]);
      await database.query(
        `INSERT INTO member_profiles (
           user_id, date_of_birth, height_cm, weight_kg, body_fat_percent,
           fitness_goal, health_notes, injury_notes, dietary_preferences,
           health_declaration_completed_at
         ) VALUES (
           $1, '1996-05-15', 176.5, 73.2, 17.4,
           'SECRET_GOAL_T18_SHRED', 'SECRET_HEALTH_T18_ASTHMA',
           'SECRET_INJURY_T18_KNEE', 'SECRET_DIET_T18_KETO', now()
         )`,
        [memberId],
      );
      await database.query(
        `INSERT INTO member_profiles (
           user_id, height_cm, weight_kg, health_notes, injury_notes, health_declaration_completed_at
         ) VALUES ($1, 168, 60, 'UNRELATED_HEALTH_T18', 'UNRELATED_INJURY_T18', now())`,
        [unrelatedMemberId],
      );

      await database.query(
        `INSERT INTO membership_plans (id, name, price, duration_days, status, created_by)
         VALUES ($1, 'Gym T18 Privacy', 500000, 30, 'ACTIVE', $2)`,
        [planId, adminId],
      );
      await insertActiveGymMembership(database, memberId, planId);

      await database.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id, status)
         VALUES ($1, $2, $3, 'ACTIVE')`,
        [relationshipId, memberId, coachId],
      );
      await database.query(
        `INSERT INTO coach_payment_holds (
           id, member_id, coach_id, plan_code, plan_name, session_count,
           duration_days, amount, status, request_key, created_at, expires_at, settled_at
         ) VALUES (
           $1, $2, $3, 'BASIC', 'Cơ bản', 10, 30, 1950000,
           'CONSUMED', $4, now(), now() + interval '15 minutes', now()
         )`,
        [holdId, memberId, coachId, randomUUID()],
      );
      await database.query(
        `INSERT INTO coach_entitlements (
           id, relationship_id, member_id, coach_id, hold_id, original_hold_id,
           plan_code, plan_name, snapshot_price, total_sessions, remaining_sessions,
           duration_days, status, starts_on, original_ends_on, ends_on
         ) VALUES (
           $1, $2, $3, $4, $5, $5,
           'BASIC', 'Cơ bản', 1950000, 10, 8, 30, 'ACTIVE',
           (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
           (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 29,
           (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 29
         )`,
        [entitlementId, relationshipId, memberId, coachId, holdId],
      );

      // Seed private journal, meal log, 1-1 chat, AI conversation, and private media
      await database.query(
        `INSERT INTO member_journal_entries (id, member_id, journal_date, notes, chest_cm, waist_cm, hips_cm)
         VALUES ($1, $2, (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date, 'SECRET_JOURNAL_T18_NOTE', 98, 76, 95)`,
        [randomUUID(), memberId],
      );
      await database.query(
        `INSERT INTO meal_logs (id, member_id, eaten_at, meal_type, meal_name, notes)
         VALUES ($1, $2, now(), 'LUNCH', 'SECRET_MEAL_T18_SALMON', 'Private meal note')`,
        [randomUUID(), memberId],
      );
      await database.query(
        `INSERT INTO conversations (id, relationship_id, member_id, coach_id)
         VALUES ($1, $2, $3, $4)`,
        [conversationId, relationshipId, memberId, coachId],
      );
      await database.query(
        `INSERT INTO conversation_participants (conversation_id, user_id)
         VALUES ($1, $2), ($1, $3)`,
        [conversationId, memberId, coachId],
      );
      await database.query(
        `INSERT INTO messages (id, conversation_id, sender_id, client_message_id, message_type, content)
         VALUES ($1, $2, $3, $4, 'TEXT', 'SECRET_CHAT_T18_DM')`,
        [randomUUID(), conversationId, memberId, randomUUID()],
      );
      await database.query(
        `INSERT INTO ai_conversations (id, user_id, title) VALUES ($1, $2, 'Private AI')`,
        [aiConversationId, memberId],
      );
      await database.query(
        `INSERT INTO ai_messages (id, conversation_id, role, content, client_request_id, request_hash, status, completed_at)
         VALUES ($1, $2, 'USER', 'SECRET_AI_T18_PROMPT', $3, repeat('d', 64), 'COMPLETED', now())`,
        [randomUUID(), aiConversationId, randomUUID()],
      );
      await database.query(
        `INSERT INTO admin_audit_logs (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'T18_REDACTION_CHECK', 'USER', $3, 'Check metadata redaction', $4::jsonb)`,
        [
          sensitiveAuditId,
          adminId,
          memberId,
          JSON.stringify({
            safeOperation: 'ok',
            temporaryPassword: 'TempPassT18Secret!',
            passwordHash: '$2b$12$T18SecretHashValue',
            injuryNotes: 'SECRET_INJURY_T18_KNEE',
            bodyFatPercent: 17.4,
            weightKg: 73.2,
            mealLogs: ['SECRET_MEAL_T18_SALMON'],
            messages: ['SECRET_CHAT_T18_DM'],
          }),
        ],
      );

      // Seed 4 private media assets (PROGRESS_PHOTO, MEAL_PHOTO, MESSAGE, COACH_OUTCOME)
      const tinyPng = await sharp({
        create: { width: 2, height: 2, channels: 3, background: { r: 20, g: 120, b: 220 } },
      }).png().toBuffer();

      const privateMediaIds = [];
      for (const [ownerId, purpose] of [
        [memberId, 'PROGRESS_PHOTO'],
        [memberId, 'MEAL_PHOTO'],
        [memberId, 'MESSAGE'],
        [coachId, 'COACH_OUTCOME'],
      ]) {
        const mediaId = randomUUID();
        const key = randomUUID();
        await imageStorage.put(key, tinyPng, 'image/png');
        await database.query(
          `INSERT INTO media_assets (
             id, owner_id, purpose, access_scope, storage_key, original_name,
             status, mime_type, size_bytes, width, height, ready_at, expires_at
           ) VALUES (
             $1, $2, $3, 'PRIVATE', $4, 'private.png',
             'READY', 'image/png', $5, 2, 2, now(), now() + interval '15 minutes'
           )`,
          [mediaId, ownerId, purpose, key, tinyPng.length],
        );
        privateMediaIds.push({ mediaId, purpose });
      }

      // 1A. ADMIN is strictly blocked from private Member/Coach endpoints (403/404)
      const adminBlockedRoutes = [
        ['GET', '/journal'],
        ['GET', '/journal/charts'],
        ['GET', '/member/nutrition/day'],
        ['GET', '/member/nutrition/foods'],
        ['GET', '/member/self-training-days?from=2026-11-01&to=2026-11-21'],
        ['GET', '/conversations'],
        ['GET', `/conversations/${conversationId}/messages`],
        ['GET', '/calls'],
        ['GET', '/ai-conversations'],
        ['GET', `/ai-conversations/${aiConversationId}/messages`],
        ['GET', `/coach/members/${memberId}`],
        ['GET', '/body-measurements'],
        ['GET', '/workout-logs'],
        ['GET', '/meal-logs'],
        ['GET', '/progress-photos'],
        ['PATCH', '/users/me/health-declaration', {
          heightCm: 170, weightKg: 70, hasCondition: false, hasInjury: false,
        }],
      ];
      for (const [method, path, body] of adminBlockedRoutes) {
        const res = await api(base, path, adminToken, method, body);
        assert.ok(
          [403, 404].includes(res.status),
          `ADMIN must be blocked from ${method} ${path}, got ${res.status}`,
        );
      }

      // ADMIN blocked from accessing or uploading private media
      for (const { mediaId, purpose } of privateMediaIds) {
        const accessUrlRes = await api(base, `/media/images/${mediaId}/access-url`, adminToken);
        assert.equal(accessUrlRes.status, 404, `ADMIN must not get signed URL for ${purpose}`);
        const publicRes = await fetch(`${base}/api/v1/media/public/${mediaId}`);
        assert.equal(publicRes.status, 404, `Private media ${purpose} must not be served via /media/public`);
        const uploadRes = await fetch(`${base}/api/v1/media/images`, {
          method: 'POST',
          headers: {
            authorization: `Bearer ${adminToken}`,
            'content-type': 'image/png',
            'x-image-purpose': purpose,
            'x-file-name': 'blocked.png',
          },
          body: tinyPng,
        });
        assert.equal(uploadRes.status, 403, `ADMIN must be blocked from uploading ${purpose}`);
      }

      // 1B. ADMIN read endpoints NEVER leak forbidden private fields
      const adminReadEndpoints = [
        '/admin/users?page=1&pageSize=20',
        `/admin/users/${memberId}`,
        `/admin/users/${coachId}`,
        `/admin/users/${memberId}/lock-preview`,
        `/admin/users/${coachId}/lock-preview`,
        '/admin/relationships?page=1&pageSize=20',
        `/admin/relationships/${relationshipId}`,
        '/admin/coach-incidents?page=1&pageSize=20',
        '/admin/simulated-refunds?page=1&pageSize=20',
        '/admin/dashboard',
        '/admin/audit-logs?action=T18_REDACTION_CHECK&page=1&pageSize=10',
        `/admin/audit-logs/${sensitiveAuditId}`,
      ];
      for (const endpoint of adminReadEndpoints) {
        const res = await api(base, endpoint, adminToken);
        assert.equal(res.status, 200, `${endpoint} failed: ${JSON.stringify(res.body)}`);
        assertNoForbiddenAdminLeak(`GET ${endpoint}`, res.body, sensitiveTokens);
      }

      // 1C. COACH privacy: ACTIVE -> can read health profile; MEMBER_LOCKED (D4) -> null; unrelated -> 404
      const coachBeforeLock = await api(base, `/coach/members/${memberId}`, coachToken);
      assert.equal(coachBeforeLock.status, 200);
      assert.equal(coachBeforeLock.body.data.member.injuryNotes, 'SECRET_INJURY_T18_KNEE');
      assert.equal(coachBeforeLock.body.data.member.weightKg, 73.2);

      // Lock Member (D4)
      const lockMemberRes = await api(base, `/admin/users/${memberId}/status`, adminToken, 'PATCH', {
        status: 'DISABLED',
        reason: 'Kiểm thử khóa Member D4 T18',
      });
      assert.equal(lockMemberRes.status, 200, JSON.stringify(lockMemberRes.body));
      assert.equal(lockMemberRes.body.data.effects.pauseReason, 'MEMBER_LOCKED');

      const coachWhileLocked = await api(base, `/coach/members/${memberId}`, coachToken);
      assert.equal(coachWhileLocked.status, 200);
      assert.equal(coachWhileLocked.body.data.status, 'PAUSED');
      assert.equal(coachWhileLocked.body.data.pauseReason, 'MEMBER_LOCKED');
      for (const field of [
        'fitnessGoal', 'healthNotes', 'injuryNotes', 'heightCm',
        'weightKg', 'bodyFatPercent', 'healthDeclarationCompletedAt',
      ]) {
        assert.equal(
          coachWhileLocked.body.data.member[field],
          null,
          `COACH must not see ${field} while Member is MEMBER_LOCKED`,
        );
      }

      // Coach cannot read unrelated Member or Member private journal/nutrition
      assert.equal((await api(base, `/coach/members/${unrelatedMemberId}`, coachToken)).status, 404);
      assert.equal((await api(base, '/journal', coachToken)).status, 403);
      assert.equal((await api(base, '/member/nutrition/day', coachToken)).status, 403);
      assert.equal((await api(base, '/member/self-training-days?from=2026-11-01&to=2026-11-21', coachToken)).status, 403);

      // Unlock Member and sign token with current session_version
      const unlockMemberRes = await api(base, `/admin/users/${memberId}/status`, adminToken, 'PATCH', {
        status: 'ACTIVE',
      });
      assert.equal(unlockMemberRes.status, 200);
      const { rows: [{ session_version: memberSessionVersion }] } = await database.query(
        'SELECT session_version FROM users WHERE id = $1',
        [memberId],
      );
      const refreshedMemberToken = signToken(memberId, 'MEMBER', memberSessionVersion);

      // 1D. MEMBER & COACH are strictly blocked (403) from all /api/v1/admin/* routes
      const adminOnlyRoutes = [
        '/admin/dashboard',
        '/admin/users',
        '/admin/audit-logs',
        '/admin/membership-plans',
        '/admin/coach-packages',
        '/admin/coach-entitlements',
        '/admin/payments',
        '/admin/memberships',
        '/admin/relationships',
        '/admin/coach-transfers',
        '/admin/termination-requests',
        '/admin/coach-incidents',
        '/admin/simulated-refunds',
        '/admin/nutrition-foods',
        '/admin/equipment',
        '/admin/exercises',
        '/admin/gym-checkin-code',
      ];
      for (const route of adminOnlyRoutes) {
        const memberRes = await api(base, route, refreshedMemberToken);
        assert.equal(memberRes.status, 403, `MEMBER must get 403 on ${route}, got ${memberRes.status}`);
        const coachRes = await api(base, route, coachToken);
        assert.equal(coachRes.status, 403, `COACH must get 403 on ${route}, got ${coachRes.status}`);
      }
      // Verify old revoked memberToken before unlock gets 401
      assert.equal((await api(base, '/users/me', memberToken)).status, 401);
    } finally {
      server.close();
      await cleanupUsers(database, allUsers);
      await database.end();
    }
  });

// ============================================================================
// GROUP 2: Seat #8 Concurrency Race (Holds vs Holds & Hold vs Incident Transfer)
// ============================================================================
test('T18 Group 2: Seat #8 concurrency race enforces hard cap <= 8 across concurrent holds and incident transfer',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const server = createApp({ database, jwtSecret: secret }).listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;

    const adminId = randomUUID();
    const coachAId = randomUUID(); // Locked coach whose member will transfer to coachB
    const coachBId = randomUUID(); // Target coach at 7/8 seats
    const existingSeven = Array.from({ length: 7 }, randomUUID);
    const racers = [randomUUID(), randomUUID(), randomUUID()];
    const transferMemberId = randomUUID();
    const allUsers = [adminId, coachAId, coachBId, transferMemberId, ...existingSeven, ...racers];

    const planId = randomUUID();
    const adminToken = signToken(adminId, 'ADMIN');

    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Admin T18 Race'),
                ($3, $4, 'hash', 'COACH', 'Coach A Locked T18'),
                ($5, $6, 'hash', 'COACH', 'Coach B Cap7 T18'),
                ($7, $8, 'hash', 'MEMBER', 'Transfer Member T18')`,
        [
          adminId, `${adminId}@example.com`,
          coachAId, `${coachAId}@example.com`,
          coachBId, `${coachBId}@example.com`,
          transferMemberId, `${transferMemberId}@example.com`,
        ],
      );
      for (const cid of [coachAId, coachBId]) {
        await database.query('INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 8)', [cid]);
        await insertWeeklySchedule(database, cid);
      }

      await database.query(
        `INSERT INTO membership_plans (id, name, price, duration_days, status, created_by)
         VALUES ($1, 'Gym T18 Race', 500000, 60, 'ACTIVE', $2)`,
        [planId, adminId],
      );

      for (const mid of [...existingSeven, ...racers]) {
        await database.query(
          `INSERT INTO users (id, email, password_hash, role, full_name)
           VALUES ($1, $2, 'hash', 'MEMBER', 'Member T18 Race')`,
          [mid, `${mid}@example.com`],
        );
        await database.query(
          `INSERT INTO member_profiles (user_id, height_cm, weight_kg, health_declaration_completed_at)
           VALUES ($1, 170, 65, now())`,
          [mid],
        );
      }
      await database.query(
        `INSERT INTO member_profiles (user_id, height_cm, weight_kg, health_declaration_completed_at)
         VALUES ($1, 170, 65, now())`,
        [transferMemberId],
      );

      // Seed 7 occupied seats on Coach B (6 ACTIVE + 1 PAUSED)
      for (const [idx, mid] of existingSeven.entries()) {
        await database.query(
          `INSERT INTO coach_relationships (id, member_id, coach_id, status, paused_at, pause_reason)
           VALUES ($1, $2, $3, $4::varchar, CASE WHEN $4 = 'PAUSED' THEN now() END,
                   CASE WHEN $4 = 'PAUSED' THEN 'MEMBERSHIP_EXPIRED' END)`,
          [randomUUID(), mid, coachBId, idx === 0 ? 'PAUSED' : 'ACTIVE'],
        );
      }

      // Active Gym memberships for racers and transferMember
      for (const mid of [...racers, transferMemberId]) {
        await insertActiveGymMembership(database, mid, planId, 500000, 60);
      }

      // Ensure BASIC package is ACTIVE
      await database.query(`UPDATE coach_package_plans SET status = 'ACTIVE' WHERE code = 'BASIC'`);

      // Race A: 3 Members concurrently request seat #8 on Coach B via POST /coach-payment-holds
      const holdRace = await Promise.all(
        racers.map((mid) =>
          api(
            base,
            '/coach-payment-holds',
            signToken(mid, 'MEMBER'),
            'POST',
            { coachId: coachBId, planCode: 'BASIC' },
            { 'idempotency-key': randomUUID() },
          )),
      );
      const holdWinners = holdRace.filter((r) => r.status === 201);
      const holdLosers = holdRace.filter((r) => r.status === 409 && r.body.error.code === 'COACH_FULL');
      assert.equal(holdWinners.length, 1, `Expected exactly 1 winner, got ${JSON.stringify(holdRace)}`);
      assert.equal(holdLosers.length, 2, `Expected 2 COACH_FULL losers, got ${JSON.stringify(holdRace)}`);

      const seatsAfterRaceA = (await database.query(
        'SELECT coach_occupied_seats($1) AS count',
        [coachBId],
      )).rows[0].count;
      assert.equal(Number(seatsAfterRaceA), 8);

      // Cancel winning hold so Coach B is back to 7 seats
      const winnerIdx = holdRace.findIndex((r) => r.status === 201);
      const cancelRes = await api(
        base,
        `/coach-payment-holds/${holdWinners[0].body.data.id}/cancel`,
        signToken(racers[winnerIdx], 'MEMBER'),
        'POST',
      );
      assert.equal(cancelRes.status, 200);

      // Setup Coach A with transferMember, then lock Coach A to create an OPEN incident
      const relAId = randomUUID();
      const holdAId = randomUUID();
      const entAId = randomUUID();
      await database.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id, status)
         VALUES ($1, $2, $3, 'ACTIVE')`,
        [relAId, transferMemberId, coachAId],
      );
      await database.query(
        `INSERT INTO coach_payment_holds (
           id, member_id, coach_id, plan_code, plan_name, session_count,
           duration_days, amount, status, request_key, created_at, expires_at, settled_at
         ) VALUES (
           $1, $2, $3, 'BASIC', 'Cơ bản', 10, 30, 1950000,
           'CONSUMED', $4, now(), now() + interval '15 minutes', now()
         )`,
        [holdAId, transferMemberId, coachAId, randomUUID()],
      );
      await database.query(
        `INSERT INTO coach_entitlements (
           id, relationship_id, member_id, coach_id, hold_id, original_hold_id,
           plan_code, plan_name, snapshot_price, total_sessions, remaining_sessions,
           duration_days, status, starts_on, original_ends_on, ends_on
         ) VALUES (
           $1, $2, $3, $4, $5, $5,
           'BASIC', 'Cơ bản', 1950000, 10, 6, 30, 'ACTIVE',
           (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
           (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 29,
           (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 29
         )`,
        [entAId, relAId, transferMemberId, coachAId, holdAId],
      );

      const lockCoachA = await api(base, `/admin/users/${coachAId}/status`, adminToken, 'PATCH', {
        status: 'DISABLED',
        reason: 'Khóa Coach A để đua suất #8 sang Coach B',
      });
      assert.equal(lockCoachA.status, 200);
      const incidentId = lockCoachA.body.data.effects.incidentsCreated[0].incidentId;

      // Race B: Member hold vs Admin incident transfer racing for seat #8 on Coach B
      const [holdAttempt, transferAttempt] = await Promise.all([
        api(
          base,
          '/coach-payment-holds',
          signToken(racers[0], 'MEMBER'),
          'POST',
          { coachId: coachBId, planCode: 'BASIC' },
          { 'idempotency-key': randomUUID() },
        ),
        api(
          base,
          `/admin/coach-incidents/${incidentId}/transfer`,
          adminToken,
          'POST',
          { newCoachId: coachBId, reason: 'Chuyển sang Coach B tranh suất 8' },
          { 'idempotency-key': randomUUID() },
        ),
      ]);

      const raceBResults = [holdAttempt, transferAttempt];
      const raceBWinners = raceBResults.filter((r) => r.status === 201);
      const raceBLosers = raceBResults.filter((r) => r.status === 409 && r.body.error.code === 'COACH_FULL');
      assert.equal(raceBWinners.length, 1, `Expected exactly 1 winner in Race B, got ${JSON.stringify(raceBResults)}`);
      assert.equal(raceBLosers.length, 1, `Expected 1 COACH_FULL loser in Race B, got ${JSON.stringify(raceBResults)}`);

      const seatsAfterRaceB = (await database.query(
        'SELECT coach_occupied_seats($1) AS count',
        [coachBId],
      )).rows[0].count;
      assert.ok(Number(seatsAfterRaceB) <= 8, `Occupied seats must never exceed 8, got ${seatsAfterRaceB}`);
      assert.equal(Number(seatsAfterRaceB), 8);
    } finally {
      server.close();
      await cleanupUsers(database, allUsers);
      await database.end();
    }
  });

// ============================================================================
// GROUP 3: 12-Hour Cancellation & Single-Charge Invariant
// ============================================================================
test('T18 Group 3: 12-hour cancellation rule (>=12h free, <12h charges 1 session, never double-charged)',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const server = createApp({ database, jwtSecret: secret }).listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;

    const adminId = randomUUID();
    const coachId = randomUUID();
    const memberId = randomUUID();
    const allUsers = [adminId, coachId, memberId];
    const planId = randomUUID();
    const relationshipId = randomUUID();
    const holdId = randomUUID();
    const entitlementId = randomUUID();
    const memberToken = signToken(memberId, 'MEMBER');

    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Admin T18 Cancel'),
                ($3, $4, 'hash', 'COACH', 'Coach T18 Cancel'),
                ($5, $6, 'hash', 'MEMBER', 'Member T18 Cancel')`,
        [
          adminId, `${adminId}@example.com`,
          coachId, `${coachId}@example.com`,
          memberId, `${memberId}@example.com`,
        ],
      );
      await database.query('INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 8)', [coachId]);
      await database.query('INSERT INTO member_profiles (user_id, health_declaration_completed_at) VALUES ($1, now())', [memberId]);
      await insertWeeklySchedule(database, coachId);

      await database.query(
        `INSERT INTO membership_plans (id, name, price, duration_days, status, created_by)
         VALUES ($1, 'Gym T18 Cancel', 500000, 30, 'ACTIVE', $2)`,
        [planId, adminId],
      );
      await insertActiveGymMembership(database, memberId, planId);

      await database.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id, status)
         VALUES ($1, $2, $3, 'ACTIVE')`,
        [relationshipId, memberId, coachId],
      );
      await database.query(
        `INSERT INTO coach_payment_holds (
           id, member_id, coach_id, plan_code, plan_name, session_count,
           duration_days, amount, status, request_key, created_at, expires_at, settled_at
         ) VALUES (
           $1, $2, $3, 'BASIC', 'Cơ bản', 10, 30, 1950000,
           'CONSUMED', $4, now(), now() + interval '15 minutes', now()
         )`,
        [holdId, memberId, coachId, randomUUID()],
      );
      await database.query(
        `INSERT INTO coach_entitlements (
           id, relationship_id, member_id, coach_id, hold_id, original_hold_id,
           plan_code, plan_name, snapshot_price, total_sessions, remaining_sessions,
           duration_days, status, starts_on, original_ends_on, ends_on
         ) VALUES (
           $1, $2, $3, $4, $5, $5,
           'BASIC', 'Cơ bản', 1950000, 10, 10, 30, 'ACTIVE',
           (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
           (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 29,
           (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 29
         )`,
        [entitlementId, relationshipId, memberId, coachId, holdId],
      );

      // Case A: Booking >= 12 hours away (2 days ahead at 09:00 VN) -> free cancel
      const { rows: [{ early_start: earlyStart }] } = await database.query(
        `SELECT ((((statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 2)
                 + make_interval(mins => 540)) AT TIME ZONE 'Asia/Ho_Chi_Minh') AS early_start`,
      );
      const earlyBooking = await api(base, '/coach-bookings', memberToken, 'POST', {
        entitlementId,
        startsAt: earlyStart.toISOString(),
      });
      assert.equal(earlyBooking.status, 201, JSON.stringify(earlyBooking.body));

      const earlyCancel = await api(
        base,
        `/coach-bookings/${earlyBooking.body.data.id}`,
        memberToken,
        'PATCH',
        { action: 'CANCEL', reason: 'Hủy sớm trên 12 giờ' },
      );
      assert.equal(earlyCancel.status, 200, JSON.stringify(earlyCancel.body));
      assert.equal(earlyCancel.body.data.status, 'CANCELLED');
      assert.equal(earlyCancel.body.data.chargedAt, null);

      let remaining = (await database.query(
        'SELECT remaining_sessions FROM coach_entitlements WHERE id = $1',
        [entitlementId],
      )).rows[0].remaining_sessions;
      assert.equal(remaining, 10, 'Early cancel (>=12h) must NOT consume a session');

      // Case B: Booking < 12 hours away (3 hours from now) -> late cancel consumes exactly 1 session
      const lateBookingId = randomUUID();
      await database.query(
        `INSERT INTO coach_bookings (id, entitlement_id, member_id, coach_id, starts_at, ends_at, status)
         VALUES ($1, $2, $3, $4, statement_timestamp() + interval '3 hours',
                 statement_timestamp() + interval '4 hours 30 minutes', 'BOOKED')`,
        [lateBookingId, entitlementId, memberId, coachId],
      );

      // Fire 2 concurrent CANCEL calls on the same <12h booking to verify single-charge invariant
      const [lateCancel1, lateCancel2] = await Promise.all([
        api(base, `/coach-bookings/${lateBookingId}`, memberToken, 'PATCH', {
          action: 'CANCEL',
          reason: 'Hủy muộn dưới 12 giờ lần 1',
        }),
        api(base, `/coach-bookings/${lateBookingId}`, memberToken, 'PATCH', {
          action: 'CANCEL',
          reason: 'Hủy muộn dưới 12 giờ lần 2',
        }),
      ]);
      assert.equal(lateCancel1.status, 200);
      assert.equal(lateCancel2.status, 200);
      assert.equal(lateCancel1.body.data.status, 'CANCELLED');
      assert.ok(lateCancel1.body.data.chargedAt, 'Late cancel (<12h) must set chargedAt');

      remaining = (await database.query(
        'SELECT remaining_sessions FROM coach_entitlements WHERE id = $1',
        [entitlementId],
      )).rows[0].remaining_sessions;
      assert.equal(remaining, 9, 'Late cancel (<12h) must consume exactly 1 session, never double-charged');

      // Third sequential replay must still not double-charge
      const lateCancel3 = await api(base, `/coach-bookings/${lateBookingId}`, memberToken, 'PATCH', {
        action: 'CANCEL',
      });
      assert.equal(lateCancel3.status, 200);
      remaining = (await database.query(
        'SELECT remaining_sessions FROM coach_entitlements WHERE id = $1',
        [entitlementId],
      )).rows[0].remaining_sessions;
      assert.equal(remaining, 9);
    } finally {
      server.close();
      await cleanupUsers(database, allUsers);
      await database.end();
    }
  });

// ============================================================================
// GROUP 4: 7-Day Non-Stacking Grace Cap Invariant
// ============================================================================
test('T18 Group 4: 7-day non-stacking grace cap invariant (DB CHECK + lifecycle reconciliation)',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const coachId = randomUUID();
    const member1Id = randomUUID();
    const member2Id = randomUUID();
    const allUsers = [coachId, member1Id, member2Id];
    const rel1Id = randomUUID();
    const rel2Id = randomUUID();
    const hold1Id = randomUUID();
    const hold2Id = randomUUID();
    const ent1Id = randomUUID();
    const ent2Id = randomUUID();

    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'COACH', 'Coach T18 Grace'),
                ($3, $4, 'hash', 'MEMBER', 'Member 1 T18 Grace'),
                ($5, $6, 'hash', 'MEMBER', 'Member 2 T18 Grace')`,
        [
          coachId, `${coachId}@example.com`,
          member1Id, `${member1Id}@example.com`,
          member2Id, `${member2Id}@example.com`,
        ],
      );
      await database.query('INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 8)', [coachId]);
      await database.query('INSERT INTO member_profiles (user_id) VALUES ($1), ($2)', [member1Id, member2Id]);
      await database.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id, status)
         VALUES ($1, $2, $3, 'ACTIVE'), ($4, $5, $3, 'ACTIVE')`,
        [rel1Id, member1Id, coachId, rel2Id, member2Id],
      );
      await database.query(
        `INSERT INTO coach_payment_holds (
           id, member_id, coach_id, plan_code, plan_name, session_count,
           duration_days, amount, status, request_key, created_at, expires_at, settled_at
         ) VALUES
           ($1, $2, $3, 'BASIC', 'Cơ bản', 10, 30, 1950000, 'CONSUMED', $4, now(), now() + interval '15 minutes', now()),
           ($5, $6, $3, 'BASIC', 'Cơ bản', 10, 30, 1950000, 'CONSUMED', $7, now(), now() + interval '15 minutes', now())`,
        [hold1Id, member1Id, coachId, randomUUID(), hold2Id, member2Id, randomUUID()],
      );

      // ent1: original_ends_on = today - 2, grace_days_added = 0, remaining_sessions = 4 -> eligible for 1x 7-day grace
      await database.query(
        `INSERT INTO coach_entitlements (
           id, relationship_id, member_id, coach_id, hold_id, original_hold_id,
           plan_code, plan_name, snapshot_price, total_sessions, remaining_sessions,
           duration_days, status, starts_on, original_ends_on, ends_on,
           frozen_days_total, grace_days_added
         ) VALUES (
           $1, $2, $3, $4, $5, $5,
           'BASIC', 'Cơ bản', 1950000, 10, 4, 30, 'ACTIVE',
           (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date - 31,
           (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date - 2,
           (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date - 2,
           0, 0
         )`,
        [ent1Id, rel1Id, member1Id, coachId, hold1Id],
      );

      // ent2: already received 7-day grace and now past ends_on (original_ends_on = today - 10, ends_on = today - 3) -> MUST expire, NOT stack another +7
      await database.query(
        `INSERT INTO coach_entitlements (
           id, relationship_id, member_id, coach_id, hold_id, original_hold_id,
           plan_code, plan_name, snapshot_price, total_sessions, remaining_sessions,
           duration_days, status, starts_on, original_ends_on, ends_on,
           frozen_days_total, grace_days_added
         ) VALUES (
           $1, $2, $3, $4, $5, $5,
           'BASIC', 'Cơ bản', 1950000, 10, 2, 30, 'ACTIVE',
           (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date - 39,
           (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date - 10,
           (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date - 3,
           0, 7
         )`,
        [ent2Id, rel2Id, member2Id, coachId, hold2Id],
      );

      // DB CHECK constraint must reject grace_days_added = 14 or mismatched ends_on formula
      await assert.rejects(
        () => database.query(
          `UPDATE coach_entitlements
           SET grace_days_added = 14, ends_on = original_ends_on + frozen_days_total + 14
           WHERE id = $1`,
          [ent1Id],
        ),
        (err) => err.code === '23514',
      );
      await assert.rejects(
        () => database.query(
          `UPDATE coach_entitlements
           SET ends_on = original_ends_on + frozen_days_total + 8
           WHERE id = $1`,
          [ent1Id],
        ),
        (err) => err.code === '23514',
      );

      // Run reconciliation twice (fresh pools to bypass 60s WeakMap throttle)
      const poolRun1 = new pg.Pool({ connectionString: databaseUrl });
      const poolRun2 = new pg.Pool({ connectionString: databaseUrl });
      try {
        await reconcileMembershipLifecycles(poolRun1);
        await reconcileMembershipLifecycles(poolRun2);
      } finally {
        await poolRun1.end();
        await poolRun2.end();
      }

      const { rows: [e1] } = await database.query(
        `SELECT status, grace_days_added, frozen_days_total,
                (ends_on - (original_ends_on + frozen_days_total))::int AS delta_from_base
         FROM coach_entitlements WHERE id = $1`,
        [ent1Id],
      );
      assert.equal(e1.status, 'ACTIVE');
      assert.equal(e1.grace_days_added, 7);
      assert.equal(e1.delta_from_base, 7, 'ends_on must equal original_ends_on + frozen_days_total + 7');

      const { rows: [e2] } = await database.query(
        `SELECT status, close_reason, grace_days_added
         FROM coach_entitlements WHERE id = $1`,
        [ent2Id],
      );
      assert.equal(e2.status, 'ENDED');
      assert.equal(e2.close_reason, 'EXPIRED');
      assert.equal(e2.grace_days_added, 7, 'Must never stack grace beyond 7 days');
    } finally {
      await cleanupUsers(database, allUsers);
      await database.end();
    }
  });

// ============================================================================
// GROUP 5: >100-Row Pagination & Filtering Invariant
// ============================================================================
test('T18 Group 5: >100-row pagination, totalItems/totalPages accuracy, search filter, and max pageSize cap',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const server = createApp({ database, jwtSecret: secret }).listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;

    const adminId = randomUUID();
    const adminToken = signToken(adminId, 'ADMIN');
    const tag = `T18PG_${randomUUID().slice(0, 8)}`;
    const seededMemberIds = [];

    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Admin T18 Pagination')`,
        [adminId, `${adminId}@example.com`],
      );

      // Seed 105 users
      const insertedUsers = await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         SELECT gen_random_uuid(),
                lower($1 || '_' || gs || '@example.com'),
                'hash',
                'MEMBER',
                $1 || ' Member ' || lpad(gs::text, 3, '0')
         FROM generate_series(1, 105) AS gs
         RETURNING id`,
        [tag],
      );
      for (const row of insertedUsers.rows) seededMemberIds.push(row.id);

      // Seed 105 audit logs
      await database.query(
        `INSERT INTO admin_audit_logs (id, admin_id, action, entity_type, entity_id, summary, metadata)
         SELECT gen_random_uuid(), $1::uuid, $2::varchar, 'USER', $3::text, $2::text || ' log ' || gs, '{}'::jsonb
         FROM generate_series(1, 105) AS gs`,
        [adminId, tag, adminId],
      );

      // Seed 105 nutrition_foods
      await database.query(
        `INSERT INTO nutrition_foods (id, name, kcal_per_100g, active)
         SELECT gen_random_uuid(), $1 || ' Food ' || lpad(gs::text, 3, '0'), 150, true
         FROM generate_series(1, 105) AS gs`,
        [tag],
      );

      // Seed 105 equipment
      await database.query(
        `INSERT INTO equipment (id, created_by, name, category, target_muscles, usage_steps, status)
         SELECT gen_random_uuid(), $1, $2 || ' Equip ' || lpad(gs::text, 3, '0'),
                'Strength', ARRAY['Legs'], '["Step 1"]'::jsonb, 'ACTIVE'
         FROM generate_series(1, 105) AS gs`,
        [adminId, tag],
      );

      // Seed 105 exercises
      await database.query(
        `INSERT INTO exercises (id, created_by, name, target_muscles, instructions, status)
         SELECT gen_random_uuid(), $1, $2 || ' Exercise ' || lpad(gs::text, 3, '0'),
                ARRAY['Back'], 'Pull with control', 'ACTIVE'
         FROM generate_series(1, 105) AS gs`,
        [adminId, tag],
      );

      const endpoints = [
        { name: 'users', path: `/admin/users?search=${tag}` },
        { name: 'audit-logs', path: `/admin/audit-logs?action=${tag}` },
        { name: 'nutrition-foods', path: `/admin/nutrition-foods?search=${tag}` },
        { name: 'equipment', path: `/admin/equipment?search=${tag}` },
        { name: 'exercises', path: `/admin/exercises?search=${tag}` },
      ];

      for (const ep of endpoints) {
        const page1 = await api(base, `${ep.path}&page=1&pageSize=25`, adminToken);
        assert.equal(page1.status, 200, `${ep.name} page 1 failed: ${JSON.stringify(page1.body)}`);
        assert.equal(page1.body.data.length, 25, `${ep.name} page 1 should have 25 rows`);
        assert.equal(page1.body.pagination.totalItems, 105, `${ep.name} totalItems should be 105`);
        assert.equal(page1.body.pagination.totalPages, 5, `${ep.name} totalPages should be 5`);

        const page5 = await api(base, `${ep.path}&page=5&pageSize=25`, adminToken);
        assert.equal(page5.status, 200, `${ep.name} page 5 failed`);
        assert.equal(page5.body.data.length, 5, `${ep.name} page 5 should have 5 remaining rows`);
        assert.equal(page5.body.pagination.totalItems, 105);

        // No overlap between page 1 and page 5 IDs
        const p1Ids = new Set(page1.body.data.map((r) => r.id));
        for (const row of page5.body.data) {
          assert.equal(p1Ids.has(row.id), false, `${ep.name} page 5 overlapped page 1`);
        }

        // Uncapped pageSize (>100) must be rejected with 422
        const uncapped = await api(base, `${ep.path}&page=1&pageSize=101`, adminToken);
        assert.equal(uncapped.status, 422, `${ep.name} must reject pageSize=101`);
      }
    } finally {
      server.close();
      await database.query(`DELETE FROM nutrition_foods WHERE name LIKE $1`, [`${tag}%`]);
      await cleanupUsers(database, [adminId, ...seededMemberIds]);
      await database.end();
    }
  });

// ============================================================================
// GROUP 6: Immutability & Anti-Double-Mutation Invariants (D6 + D3 + Idempotency)
// ============================================================================
test('T18 Group 6: D6 payment immutability, payment_adjustments uniqueness, D3 simulated_refunds uniqueness, and Idempotency-Key 409 conflicts',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const server = createApp({ database, jwtSecret: secret }).listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;

    const adminId = randomUUID();
    const coachId = randomUUID();
    const memberId = randomUUID();
    const allUsers = [adminId, coachId, memberId];
    const planAId = randomUUID();
    const planBId = randomUUID();
    const adminToken = signToken(adminId, 'ADMIN');
    const memberToken = signToken(memberId, 'MEMBER');

    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Admin T18 Immut'),
                ($3, $4, 'hash', 'COACH', 'Coach T18 Immut'),
                ($5, $6, 'hash', 'MEMBER', 'Member T18 Immut')`,
        [
          adminId, `${adminId}@example.com`,
          coachId, `${coachId}@example.com`,
          memberId, `${memberId}@example.com`,
        ],
      );
      await database.query('INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 8)', [coachId]);
      await database.query('INSERT INTO member_profiles (user_id, health_declaration_completed_at) VALUES ($1, now())', [memberId]);
      await insertWeeklySchedule(database, coachId);

      await database.query(
        `INSERT INTO membership_plans (id, name, price, duration_days, status, created_by)
         VALUES ($1, 'Gym 90d T18', 1500000, 90, 'ACTIVE', $3),
                ($2, 'Gym 30d T18', 600000, 30, 'ACTIVE', $3)`,
        [planAId, planBId, adminId],
      );

      // 6A. D6 Front-desk payment + idempotency conflict + VOID_REVERSAL immutability
      const fdKey = randomUUID();
      const fdCreated = await api(
        base,
        '/admin/front-desk-payments',
        adminToken,
        'POST',
        { memberId, planId: planAId },
        { 'idempotency-key': fdKey },
      );
      assert.equal(fdCreated.status, 201, JSON.stringify(fdCreated.body));
      const paymentId = fdCreated.body.data.payment.id;

      // Same Idempotency-Key with different payload -> conflict (409 or 422 IDEMPOTENCY_KEY_CONFLICT)
      const fdConflict = await api(
        base,
        '/admin/front-desk-payments',
        adminToken,
        'POST',
        { memberId, planId: planBId },
        { 'idempotency-key': fdKey },
      );
      assert.ok([409, 422].includes(fdConflict.status));
      assert.equal(fdConflict.body.error.code, 'IDEMPOTENCY_KEY_CONFLICT');

      const paymentBefore = (await database.query(
        'SELECT status, amount, plan_name_snapshot, duration_days_snapshot, confirmed_at FROM payments WHERE id = $1',
        [paymentId],
      )).rows[0];

      const voidKey = randomUUID();
      const voidRes = await api(
        base,
        `/admin/payments/${paymentId}/void-reversal`,
        adminToken,
        'POST',
        { reason: 'Thu ngân chọn nhầm gói 90 ngày' },
        { 'idempotency-key': voidKey },
      );
      assert.equal(voidRes.status, 201, JSON.stringify(voidRes.body));

      // Verify original payments row is immutable under D6
      const paymentAfter = (await database.query(
        'SELECT status, amount, plan_name_snapshot, duration_days_snapshot, confirmed_at FROM payments WHERE id = $1',
        [paymentId],
      )).rows[0];
      assert.deepEqual(paymentAfter, paymentBefore, 'Original SUCCESS payment row must remain immutable');

      // Idempotent replay -> 200
      const voidReplay = await api(
        base,
        `/admin/payments/${paymentId}/void-reversal`,
        adminToken,
        'POST',
        { reason: 'Thu ngân chọn nhầm gói 90 ngày' },
        { 'idempotency-key': voidKey },
      );
      assert.equal(voidReplay.status, 200);

      // Same Idempotency-Key + different payload -> 409 IDEMPOTENCY_KEY_CONFLICT
      const voidKeyConflict = await api(
        base,
        `/admin/payments/${paymentId}/void-reversal`,
        adminToken,
        'POST',
        { reason: 'Lý do khác để kiểm tra xung đột khóa' },
        { 'idempotency-key': voidKey },
      );
      assert.equal(voidKeyConflict.status, 409);
      assert.equal(voidKeyConflict.body.error.code, 'IDEMPOTENCY_KEY_CONFLICT');

      // New Idempotency-Key on already reversed payment -> 409 PAYMENT_ALREADY_REVERSED
      const voidDuplicate = await api(
        base,
        `/admin/payments/${paymentId}/void-reversal`,
        adminToken,
        'POST',
        { reason: 'Thử đảo lần 2' },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(voidDuplicate.status, 409);
      assert.equal(voidDuplicate.body.error.code, 'PAYMENT_ALREADY_REVERSED');

      // DB UNIQUE(payment_id) constraint on payment_adjustments rejects direct second insert
      const adjRow = (await database.query(
        'SELECT affected_membership_id, previous_end_date FROM payment_adjustments WHERE payment_id = $1',
        [paymentId],
      )).rows[0];
      await assert.rejects(
        () => database.query(
          `INSERT INTO payment_adjustments (
             id, payment_id, member_id, affected_membership_id, adjustment_type,
             reversed_amount, previous_membership_status, previous_end_date,
             reason, idempotency_key, request_hash, created_by
           ) VALUES (
             $1, $2, $3, $4, 'VOID_REVERSAL',
             1500000, 'ACTIVE', $5,
             'Direct duplicate', $6, repeat('b', 64), $7
           )`,
          [randomUUID(), paymentId, memberId, adjRow.affected_membership_id, adjRow.previous_end_date, randomUUID(), adminId],
        ),
        (err) => err.code === '23505',
      );

      // 6B. Coach payment hold Idempotency-Key conflict -> 409
      await insertActiveGymMembership(database, memberId, planBId, 600000, 30);
      await database.query(`UPDATE coach_package_plans SET status = 'ACTIVE' WHERE code IN ('BASIC', 'STANDARD')`);
      const holdKey = randomUUID();
      const holdRes = await api(
        base,
        '/coach-payment-holds',
        memberToken,
        'POST',
        { coachId, planCode: 'BASIC' },
        { 'idempotency-key': holdKey },
      );
      assert.equal(holdRes.status, 201, JSON.stringify(holdRes.body));

      const holdConflict = await api(
        base,
        '/coach-payment-holds',
        memberToken,
        'POST',
        { coachId, planCode: 'STANDARD' },
        { 'idempotency-key': holdKey },
      );
      assert.equal(holdConflict.status, 409);
      assert.equal(holdConflict.body.error.code, 'IDEMPOTENCY_KEY_CONFLICT');

      // Settle hold to create relationship + entitlement, then lock Coach for D3 simulated refund check
      const settleRes = await api(
        base,
        `/coach-payment-holds/${holdRes.body.data.id}/mock-confirmations`,
        memberToken,
        'POST',
      );
      assert.equal(settleRes.status, 200, JSON.stringify(settleRes.body));
      const entitlementId = settleRes.body.data.entitlementId;

      const lockCoachRes = await api(base, `/admin/users/${coachId}/status`, adminToken, 'PATCH', {
        status: 'DISABLED',
        reason: 'Khóa Coach kiểm thử D3 uniqueness T18',
      });
      assert.equal(lockCoachRes.status, 200);
      const incidentId = lockCoachRes.body.data.effects.incidentsCreated[0].incidentId;

      // 6C. D3 simulated_refunds uniqueness + Idempotency-Key 409 conflict
      const refundKey = randomUUID();
      const refund1 = await api(
        base,
        `/admin/coach-incidents/${incidentId}/simulated-refunds`,
        adminToken,
        'POST',
        { reason: 'Hoàn tiền mô phỏng T18' },
        { 'idempotency-key': refundKey },
      );
      assert.equal(refund1.status, 201, JSON.stringify(refund1.body));

      // Same key + same payload -> 200 idempotent replay
      const refundReplay = await api(
        base,
        `/admin/coach-incidents/${incidentId}/simulated-refunds`,
        adminToken,
        'POST',
        { reason: 'Hoàn tiền mô phỏng T18' },
        { 'idempotency-key': refundKey },
      );
      assert.equal(refundReplay.status, 200);

      // Same key + different payload -> 409 IDEMPOTENCY_KEY_CONFLICT
      const refundKeyConflict = await api(
        base,
        `/admin/coach-incidents/${incidentId}/simulated-refunds`,
        adminToken,
        'POST',
        { reason: 'Lý do hoàn tiền khác' },
        { 'idempotency-key': refundKey },
      );
      assert.equal(refundKeyConflict.status, 409);
      assert.equal(refundKeyConflict.body.error.code, 'IDEMPOTENCY_KEY_CONFLICT');

      // New key on already refunded incident -> 409
      const refundAgain = await api(
        base,
        `/admin/coach-incidents/${incidentId}/simulated-refunds`,
        adminToken,
        'POST',
        { reason: 'Thử hoàn tiền lần 2' },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(refundAgain.status, 409);
      assert.ok(['INCIDENT_ALREADY_RESOLVED', 'ALREADY_REFUNDED'].includes(refundAgain.body.error.code));

      // DB UNIQUE(coach_entitlement_id) on simulated_refunds rejects direct second insert
      const refRow = (await database.query(
        'SELECT relationship_id, snapshot_price, total_sessions, remaining_sessions, refund_amount FROM simulated_refunds WHERE coach_entitlement_id = $1',
        [entitlementId],
      )).rows[0];
      await assert.rejects(
        () => database.query(
          `INSERT INTO simulated_refunds (
             id, refund_batch_id, incident_id, coach_entitlement_id, relationship_id,
             member_id, coach_id, entitlement_kind, snapshot_price, total_sessions,
             remaining_sessions, refund_amount, status, reason, idempotency_key,
             request_hash, created_by
           ) VALUES (
             $1, $2, $3, $4, $5,
             $6, $7, 'ACTIVE', $8, $9,
             $10, $11, 'COMPLETED', 'Direct duplicate', $12,
             repeat('c', 64), $13
           )`,
          [
            randomUUID(), randomUUID(), incidentId, entitlementId, refRow.relationship_id,
            memberId, coachId, refRow.snapshot_price, refRow.total_sessions,
            refRow.remaining_sessions, refRow.refund_amount, randomUUID(), adminId,
          ],
        ),
        (err) => err.code === '23505',
      );
    } finally {
      server.close();
      await cleanupUsers(database, allUsers);
      await database.end();
    }
  });

// ============================================================================
// GROUP 7: Database Schema (75 Tables), 0033 Indexes & REVOKE ALL Privilege Guard
// ============================================================================
test('T18 Group 7: DB schema integrity (75 public tables, 0033 indexes, hard cap 8, REVOKE ALL privilege guard)',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });

    try {
      // 7A. Verify exactly 75 public tables
      const { rows: [{ table_count: tableCount }] } = await database.query(
        `SELECT count(*)::int AS table_count FROM pg_tables WHERE schemaname = 'public'`,
      );
      assert.equal(tableCount, 75, `Expected 75 public tables, found ${tableCount}`);

      // 7B. Verify all 9 indexes from 0033_web_admin_reporting_and_audit_indexes.up.sql exist
      const expectedIndexes = [
        'ix_audit_created_desc',
        'ix_audit_action_created',
        'ix_payments_confirmed_success',
        'ix_coach_holds_consumed_settled',
        'ix_coach_incidents_status_created',
        'ix_simulated_refunds_created_at',
        'ix_payment_adjustments_created_at',
        'ix_termination_disputed_created',
        'ix_nutrition_foods_name_lower',
      ];
      const { rows: foundIndexes } = await database.query(
        `SELECT indexname FROM pg_indexes
         WHERE schemaname = 'public' AND indexname = ANY($1::text[])`,
        [expectedIndexes],
      );
      const foundSet = new Set(foundIndexes.map((r) => r.indexname));
      for (const idx of expectedIndexes) {
        assert.ok(foundSet.has(idx), `Missing 0033 index: ${idx}`);
      }

      // 7C. Verify coach_profiles.member_limit = 8 hard cap constraint
      const { rows: [capConstraint] } = await database.query(
        `SELECT conname FROM pg_constraint WHERE conname = 'ck_coach_profiles_member_limit_fixed'`,
      );
      assert.ok(capConstraint, 'Missing ck_coach_profiles_member_limit_fixed constraint');

      // 7D. Verify PUBLIC has no table privileges on sensitive tables & REVOKE ALL blocks non-privileged roles
      const sensitiveTables = [
        'users',
        'member_profiles',
        'member_journal_entries',
        'member_nutrition_days',
        'messages',
        'ai_messages',
        'admin_audit_logs',
        'payments',
        'simulated_refunds',
        'payment_adjustments',
      ];
      for (const tbl of sensitiveTables) {
        const { rows: [priv] } = await database.query(
          `SELECT has_table_privilege('public', $1, 'SELECT') AS can_select,
                  has_table_privilege('public', $1, 'INSERT') AS can_insert,
                  has_table_privilege('public', $1, 'UPDATE') AS can_update,
                  has_table_privilege('public', $1, 'DELETE') AS can_delete`,
          [`public.${tbl}`],
        );
        assert.equal(priv.can_select, false, `PUBLIC must not have SELECT on ${tbl}`);
        assert.equal(priv.can_insert, false, `PUBLIC must not have INSERT on ${tbl}`);
        assert.equal(priv.can_update, false, `PUBLIC must not have UPDATE on ${tbl}`);
        assert.equal(priv.can_delete, false, `PUBLIC must not have DELETE on ${tbl}`);
      }

      // Verify REVOKE ALL enforcement using a transactional ephemeral non-privileged role (rolled back cleanly)
      const { rows: [roleCaps] } = await database.query(
        `SELECT rolsuper, rolcreaterole FROM pg_roles WHERE rolname = current_user`,
      );
      if (roleCaps?.rolsuper || roleCaps?.rolcreaterole) {
        const client = await database.connect();
        const roleName = `t18_nonpriv_${randomUUID().replaceAll('-', '').slice(0, 12)}`;
        try {
          await client.query('BEGIN');
          await client.query(`CREATE ROLE ${roleName} NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE`);
          await client.query(`REVOKE ALL ON ALL TABLES IN SCHEMA public FROM ${roleName}`);
          await client.query(`REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM ${roleName}`);
          await client.query(`REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM ${roleName}`);
          await client.query(`SET LOCAL ROLE ${roleName}`);
          await assert.rejects(
            () => client.query('SELECT count(*) FROM public.users'),
            (err) => err.code === '42501',
            'Non-privileged role after REVOKE ALL must receive 42501 permission denied',
          );
        } finally {
          await client.query('ROLLBACK').catch(() => {});
          client.release();
        }
      }
    } finally {
      await database.end();
    }
  });
