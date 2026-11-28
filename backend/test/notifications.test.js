import assert from 'node:assert/strict';
import { generateKeyPairSync, randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';

import { createApp } from '../src/app.js';
import { createFcmFromEnv } from '../src/config/fcm.js';
import {
  DEFAULT_NOTIFICATION_PREFERENCES,
  dispatchNotification,
  formatNotificationRow,
  inferCategoryForKind,
} from '../src/services/notification-dispatcher.js';

const secret = 'notifications-test-secret-at-least-32-chars';

function signToken(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, secret, {
    algorithm: 'HS256',
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    subject: id,
    expiresIn: 3600,
  });
}

test('createFcmFromEnv handles unset, partial, and OAuth + HTTP v1 token delivery', async () => {
  assert.equal(createFcmFromEnv({}), undefined);
  assert.throws(() => createFcmFromEnv({ FCM_PROJECT_ID: 'proj' }), /Invalid FCM configuration/);

  const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const pem = privateKey.export({ type: 'pkcs8', format: 'pem' }).replaceAll('\n', '\\n');

  const calls = [];
  const fcm = createFcmFromEnv(
    {
      FCM_PROJECT_ID: 'metagym-test',
      FCM_CLIENT_EMAIL: 'firebase@metagym-test.iam.gserviceaccount.com',
      FCM_PRIVATE_KEY: pem,
    },
    async (url, options) => {
      calls.push({ url: String(url), options });
      if (String(url).includes('oauth2.googleapis.com/token')) {
        return new Response(JSON.stringify({ access_token: 'oauth-token-1', expires_in: 3600 }), {
          status: 200,
          headers: { 'content-type': 'application/json' },
        });
      }
      const body = JSON.parse(options.body);
      if (body.message.token === 'dead-token') {
        return new Response(
          JSON.stringify({ error: { status: 'UNREGISTERED', details: [{ errorCode: 'UNREGISTERED' }] } }),
          { status: 404, headers: { 'content-type': 'application/json' } },
        );
      }
      return new Response(JSON.stringify({ name: 'projects/metagym-test/messages/1' }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      });
    },
  );

  const result = await fcm.sendToTokens(['live-token', 'dead-token', 'live-token'], {
    title: 'Nhắc lịch tập',
    body: 'Đến giờ tập rồi',
    channelId: 'metagym_reminders',
    highPriority: true,
    data: { kind: 'BOOKED', count: 1 },
  });

  assert.equal(result.sent, 1);
  assert.equal(result.failed, 1);
  assert.deepEqual(result.invalidTokens, ['dead-token']);
  assert.equal(calls.length, 3);
  assert.match(calls[1].url, /projects\/metagym-test\/messages:send$/);
});

test('notification-dispatcher categorizes, formats, respects preferences, and deactivates invalid tokens', async () => {
  assert.equal(inferCategoryForKind('BOOKED'), 'COACH');
  assert.equal(inferCategoryForKind('TRAINING_PLAN_UPDATED'), 'TRAINING');
  assert.equal(inferCategoryForKind('NEW_MESSAGE'), 'MESSAGE');
  assert.equal(inferCategoryForKind('ADMIN_BROADCAST'), 'SYSTEM');

  const userId = randomUUID();
  const realtimeEvents = [];
  const deactivatedTokens = [];
  const insertedRows = [];
  const fcmSent = [];

  const database = {
    async query(sql, values) {
      if (sql.includes('INSERT INTO coach_notifications')) {
        const row = {
          id: insertedRows.length + 1,
          user_id: values[0],
          kind: values[1],
          category: values[2],
          subject_id: values[3],
          title: values[4],
          body: values[5],
          action_route: values[6],
          metadata: JSON.parse(values[7]),
          event_at: new Date('2026-11-28T10:00:00Z'),
          read_at: null,
        };
        insertedRows.push(row);
        return { rows: [row] };
      }
      if (sql.includes('FROM user_notification_preferences')) {
        return {
          rows: [{
            user_id: userId,
            ...DEFAULT_NOTIFICATION_PREFERENCES,
            messagesEnabled: false,
            coachUpdatesEnabled: true,
          }],
        };
      }
      if (sql.includes('FROM user_device_tokens')) {
        return { rows: [{ token: 'device-token-1' }, { token: 'stale-token' }] };
      }
      if (sql.includes('UPDATE user_device_tokens SET is_active = false')) {
        deactivatedTokens.push(...values[0]);
        return { rows: [] };
      }
      return { rows: [] };
    },
  };

  const realtime = {
    async publish(targetUserId, event, payload) {
      realtimeEvents.push({ targetUserId, event, payload });
    },
  };
  const fcm = {
    async sendToTokens(tokens, message) {
      fcmSent.push({ tokens, message });
      return { sent: 1, failed: 1, invalidTokens: ['stale-token'] };
    },
  };

  // Muted category (messagesEnabled = false) still inserts DB row, skips push/realtime
  const muted = await dispatchNotification({
    database,
    realtime,
    fcm,
    userId,
    kind: 'NEW_MESSAGE',
    category: 'MESSAGE',
    title: 'Tin nhắn mới',
    body: 'Xin chào',
    actionRoute: '/member/features/messages',
  });
  assert.equal(muted.id, '1');
  assert.equal(realtimeEvents.length, 0);
  assert.equal(fcmSent.length, 0);

  // Enabled category publishes Realtime + sends FCM + cleans up invalidTokens
  const enabled = await dispatchNotification({
    database,
    realtime,
    fcm,
    userId,
    kind: 'TRAINING_PLAN_UPDATED',
    category: 'TRAINING',
    subjectId: randomUUID(),
    title: 'Giáo trình mới',
    body: 'Coach vừa cập nhật',
    actionRoute: '/member/features/training',
  });
  assert.equal(enabled.id, '2');
  assert.equal(realtimeEvents.length, 1);
  assert.equal(realtimeEvents[0].event, 'notification');
  assert.equal(fcmSent.length, 1);
  assert.deepEqual(deactivatedTokens, ['stale-token']);

  const formatted = formatNotificationRow({
    id: 99,
    kind: 'PACKAGE_ACTIVE',
    event_at: '2026-11-28T09:00:00Z',
    read_at: null,
  });
  assert.equal(formatted.id, '99');
  assert.equal(formatted.category, 'COACH');
  assert.equal(formatted.title, 'Gói Coach đã kích hoạt');
});

test('notifications REST endpoints handle list, unread-count, read-all, preferences, device tokens, and admin broadcast', async () => {
  const adminId = randomUUID();
  const memberId = randomUUID();
  const coachId = randomUUID();

  const users = new Map([
    [adminId, { id: adminId, role: 'ADMIN', status: 'ACTIVE', session_version: 0, full_name: 'Admin' }],
    [memberId, { id: memberId, role: 'MEMBER', status: 'ACTIVE', session_version: 0, full_name: 'Member' }],
    [coachId, { id: coachId, role: 'COACH', status: 'ACTIVE', session_version: 0, full_name: 'Coach' }],
  ]);

  let nextId = 10;
  const notifications = [
    {
      id: 1,
      user_id: memberId,
      kind: 'BOOKED',
      category: 'COACH',
      subject_id: randomUUID(),
      title: null,
      body: null,
      action_route: null,
      metadata: {},
      event_at: new Date('2026-11-28T08:00:00Z'),
      read_at: null,
    },
    {
      id: 2,
      user_id: memberId,
      kind: 'TRAINING_PLAN_UPDATED',
      category: 'TRAINING',
      subject_id: randomUUID(),
      title: 'Giáo trình tuần 1',
      body: 'Đã cập nhật',
      action_route: '/member/features/training',
      metadata: {},
      event_at: new Date('2026-11-28T09:00:00Z'),
      read_at: null,
    },
  ];
  const prefs = new Map();
  const deviceTokens = new Map();
  const broadcasts = [];
  const auditLogs = [];
  const realtimePublished = [];

  async function runQuery(sql, values = []) {
    if (sql.startsWith('BEGIN') || sql.startsWith('COMMIT') || sql.startsWith('ROLLBACK')) {
      return { rows: [] };
    }
    if (sql.includes('FROM users u WHERE u.id = $1') || sql.includes('FROM users u\n')) {
      const u = users.get(values[0]);
      return { rows: u ? [u] : [] };
    }
    if (sql.includes("FROM users WHERE id = $1 AND role = 'ADMIN'")) {
      const u = users.get(values[0]);
      return { rows: u && u.role === 'ADMIN' ? [{ id: u.id }] : [] };
    }
    if (sql.includes('INSERT INTO coach_notifications') && sql.includes('PACKAGE_EXPIRING')) {
      return { rows: [] };
    }
    if (sql.includes('SELECT id, kind, category, subject_id, title, body, action_route, metadata, event_at, read_at')) {
      const uid = values[0];
      let rows = notifications.filter((n) => n.user_id === uid);
      if (sql.includes('category = $')) {
        const cat = values[1];
        rows = rows.filter((n) => n.category === cat);
      }
      if (sql.includes('read_at IS NULL')) {
        rows = rows.filter((n) => n.read_at === null);
      }
      rows = [...rows].sort((a, b) => b.id - a.id);
      return { rows };
    }
    if (sql.includes('SELECT count(*)::int AS count FROM coach_notifications')) {
      const uid = values[0];
      const count = notifications.filter((n) => n.user_id === uid && n.read_at === null).length;
      return { rows: [{ count }] };
    }
    if (sql.includes('UPDATE coach_notifications') && sql.includes('WHERE user_id = $1 AND read_at IS NULL')) {
      const uid = values[0];
      const cat = values[1];
      const updated = [];
      for (const n of notifications) {
        if (n.user_id === uid && n.read_at === null && (!cat || n.category === cat)) {
          n.read_at = new Date();
          updated.push({ id: n.id });
        }
      }
      return { rows: updated, rowCount: updated.length };
    }
    if (sql.includes('UPDATE coach_notifications') && sql.includes('WHERE id = $1 AND user_id = $2')) {
      const id = Number(values[0]);
      const uid = values[1];
      const item = notifications.find((n) => n.id === id && n.user_id === uid);
      if (!item) return { rows: [] };
      item.read_at ??= new Date();
      return { rows: [{ id: item.id, readAt: item.read_at }] };
    }
    if (sql.includes('FROM user_notification_preferences')) {
      const p = prefs.get(values[0]);
      return { rows: p ? [p] : [] };
    }
    if (sql.includes('INSERT INTO user_notification_preferences')) {
      const record = {
        workoutRemindersEnabled: values[1],
        reminderTime: values[2],
        ptBeforeMinutes: values[3],
        nutritionRemindersEnabled: values[4],
        coachUpdatesEnabled: values[5],
        messagesEnabled: values[6],
        callsEnabled: values[7],
        adminBroadcastsEnabled: values[8],
      };
      prefs.set(values[0], record);
      return { rows: [record] };
    }
    if (sql.includes('INSERT INTO user_device_tokens')) {
      const entry = { id: values[0], user_id: values[1], token: values[2], platform: values[3], device_label: values[4], isActive: true };
      deviceTokens.set(values[2], entry);
      return { rows: [entry] };
    }
    if (sql.includes('UPDATE user_device_tokens SET is_active = false')) {
      const entry = deviceTokens.get(values[0]);
      if (entry && entry.user_id === values[1]) entry.isActive = false;
      return { rows: [] };
    }
    if (sql.includes('SELECT token FROM user_device_tokens')) {
      const tokens = [...deviceTokens.values()]
        .filter((d) => d.user_id === values[0] && d.isActive)
        .map((d) => ({ token: d.token }));
      return { rows: tokens };
    }
    if (sql.includes('SELECT id FROM users WHERE role = ANY')) {
      const roles = values[0];
      return { rows: [...users.values()].filter((u) => roles.includes(u.role)).map((u) => ({ id: u.id })) };
    }
    if (sql.includes('INSERT INTO admin_notification_broadcasts')) {
      const row = {
        id: values[0],
        adminId: values[1],
        title: values[2],
        body: values[3],
        audience: values[4],
        actionRoute: values[5],
        recipientCount: values[6],
        createdAt: new Date(),
      };
      broadcasts.unshift(row);
      return { rows: [row] };
    }
    if (sql.includes('FROM unnest($1::uuid[])')) {
      const [recipientIds, broadcastId, title, body, actionRoute, metadataJson] = values;
      const created = [];
      for (const uid of recipientIds) {
        const row = {
          id: ++nextId,
          user_id: uid,
          kind: 'ADMIN_BROADCAST',
          category: 'SYSTEM',
          subject_id: broadcastId,
          title,
          body,
          action_route: actionRoute,
          metadata: JSON.parse(metadataJson),
          event_at: new Date(),
          read_at: null,
        };
        notifications.push(row);
        created.push(row);
      }
      return { rows: created };
    }
    if (sql.includes('INSERT INTO admin_audit_logs')) {
      auditLogs.push({ id: values[0], action: values[2] });
      return { rows: [] };
    }
    if (sql.includes('SELECT count(*)::int AS count FROM admin_notification_broadcasts')) {
      return { rows: [{ count: broadcasts.length }] };
    }
    if (sql.includes('FROM admin_notification_broadcasts b')) {
      return { rows: broadcasts };
    }
    return { rows: [] };
  }

  const database = {
    query: runQuery,
    async connect() {
      return { query: runQuery, release() {} };
    },
  };

  const realtime = {
    async publish(uid, event, payload) {
      realtimePublished.push({ uid, event, payload });
    },
  };

  const server = createApp({ database, jwtSecret: secret, realtime }).listen(0);
  try {
    const baseUrl = `http://127.0.0.1:${server.address().port}/api/v1`;
    const memberHeader = { authorization: `Bearer ${signToken(memberId, 'MEMBER')}` };
    const adminHeader = { authorization: `Bearer ${signToken(adminId, 'ADMIN')}` };

    // 1. List notifications + unread count
    const listRes = await fetch(`${baseUrl}/notifications?category=TRAINING`, { headers: memberHeader });
    assert.equal(listRes.status, 200);
    const listJson = await listRes.json();
    assert.equal(listJson.data.length, 1);
    assert.equal(listJson.data[0].kind, 'TRAINING_PLAN_UPDATED');
    assert.equal(listJson.meta.unreadCount, 2);

    const countRes = await fetch(`${baseUrl}/notifications/unread-count`, { headers: memberHeader });
    assert.equal((await countRes.json()).data.unreadCount, 2);

    // 2. Preferences GET + PUT
    const prefGet = await fetch(`${baseUrl}/notifications/preferences`, { headers: memberHeader });
    assert.equal((await prefGet.json()).data.reminderTime, '17:30');

    const prefPut = await fetch(`${baseUrl}/notifications/preferences`, {
      method: 'PUT',
      headers: { ...memberHeader, 'content-type': 'application/json' },
      body: JSON.stringify({
        ...DEFAULT_NOTIFICATION_PREFERENCES,
        reminderTime: '19:00',
        ptBeforeMinutes: 15,
      }),
    });
    assert.equal(prefPut.status, 200);
    assert.equal((await prefPut.json()).data.reminderTime, '19:00');

    // 3. Device token register + unregister
    const regToken = await fetch(`${baseUrl}/notifications/device-tokens`, {
      method: 'POST',
      headers: { ...memberHeader, 'content-type': 'application/json' },
      body: JSON.stringify({ token: 'fcm-token-android-12345', platform: 'ANDROID', deviceLabel: 'Pixel' }),
    });
    assert.equal(regToken.status, 201);
    assert.equal(deviceTokens.get('fcm-token-android-12345')?.isActive, true);

    const delToken = await fetch(`${baseUrl}/notifications/device-tokens`, {
      method: 'DELETE',
      headers: { ...memberHeader, 'content-type': 'application/json' },
      body: JSON.stringify({ token: 'fcm-token-android-12345' }),
    });
    assert.equal(delToken.status, 200);
    assert.equal(deviceTokens.get('fcm-token-android-12345')?.isActive, false);

    // 4. Member forbidden from Admin broadcast
    const forbiddenBroadcast = await fetch(`${baseUrl}/admin/notifications/broadcast`, {
      method: 'POST',
      headers: { ...memberHeader, 'content-type': 'application/json' },
      body: JSON.stringify({ title: 'Test', body: 'Hello', audience: 'ALL' }),
    });
    assert.equal(forbiddenBroadcast.status, 403);

    // 5. Admin broadcast to ALL -> Member + Coach receive notifications & audit logged
    const adminBroadcast = await fetch(`${baseUrl}/admin/notifications/broadcast`, {
      method: 'POST',
      headers: { ...adminHeader, 'content-type': 'application/json' },
      body: JSON.stringify({
        title: 'Bảo trì hệ thống',
        body: 'Meta Gym nâng cấp vào 23:00 tối nay.',
        audience: 'ALL',
        actionRoute: '/member/features/sessions',
      }),
    });
    assert.equal(adminBroadcast.status, 201);
    const broadcastJson = await adminBroadcast.json();
    assert.equal(broadcastJson.data.recipientCount, 2);
    assert.equal(auditLogs.length, 1);

    // Wait briefly for async post-commit Realtime fan-out
    await new Promise((r) => setTimeout(r, 30));
    assert.equal(realtimePublished.length, 2);

    const broadcastsList = await fetch(`${baseUrl}/admin/notifications/broadcasts`, { headers: adminHeader });
    assert.equal(broadcastsList.status, 200);
    assert.equal((await broadcastsList.json()).data.length, 1);

    // 6. Read-all marks remaining unread notifications read
    const readAllRes = await fetch(`${baseUrl}/notifications/read-all`, {
      method: 'PATCH',
      headers: { ...memberHeader, 'content-type': 'application/json' },
      body: JSON.stringify({}),
    });
    assert.equal(readAllRes.status, 200);
    assert.equal((await readAllRes.json()).data.updatedCount, 3);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
