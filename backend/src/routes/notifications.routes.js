import { randomUUID } from 'node:crypto';
import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';
import {
  DEFAULT_NOTIFICATION_PREFERENCES,
  deliverPushAndRealtime,
  formatNotificationRow,
  loadPreferencesMap,
} from '../services/notification-dispatcher.js';

const categoryEnum = z.enum(['ALL', 'COACH', 'TRAINING', 'MESSAGE', 'SYSTEM']);
const listQuerySchema = z.strictObject({
  category: categoryEnum.optional(),
  unreadOnly: z.enum(['true', 'false']).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
});

const readAllBodySchema = z.strictObject({
  category: categoryEnum.optional(),
});

const preferencesSchema = z.strictObject({
  workoutRemindersEnabled: z.boolean(),
  reminderTime: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
  ptBeforeMinutes: z.union([z.literal(0), z.literal(15), z.literal(30), z.literal(60)]),
  nutritionRemindersEnabled: z.boolean(),
  coachUpdatesEnabled: z.boolean(),
  messagesEnabled: z.boolean(),
  callsEnabled: z.boolean(),
  adminBroadcastsEnabled: z.boolean(),
});

const deviceTokenRegisterSchema = z.strictObject({
  token: z.string().trim().min(10).max(4096),
  platform: z.enum(['ANDROID', 'IOS', 'WEB']),
  deviceLabel: z.string().trim().max(150).optional().nullable(),
});

const deviceTokenDeleteSchema = z.strictObject({
  token: z.string().trim().min(10).max(4096),
});

const broadcastCreateSchema = z.strictObject({
  title: z.string().trim().min(1).max(120),
  body: z.string().trim().min(1).max(1000),
  audience: z.enum(['ALL', 'MEMBER', 'COACH']),
  actionRoute: z.string().trim().max(255).optional().nullable(),
});

const broadcastListQuerySchema = z.strictObject({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});

function fail(response, status, code, message, details = {}) {
  return response.status(status).json({ error: { code, message, details } });
}

async function activeAdmin(client, user) {
  const result = await client.query(
    `SELECT id FROM users WHERE id = $1 AND role = 'ADMIN' AND status = 'ACTIVE'
     AND session_version = $2 FOR SHARE`,
    [user.id, user.session_version],
  );
  return result.rows.length === 1;
}

export function createNotificationsRouter({ database, jwtSecret, realtime, fcm }) {
  const router = Router();
  router.use(
    ['/notifications', '/admin/notifications'],
    createAuthentication({ database, jwtSecret }),
  );

  router.get('/notifications', async (request, response) => {
    const parsed = listQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Tham số lọc thông báo không hợp lệ');
    }
    const { category, unreadOnly, limit } = parsed.data;
    const client = await database.connect().catch(() => null);
    if (!client) {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    }
    try {
      await client.query('BEGIN');
      if (request.authUser.role === 'MEMBER') {
        await client.query(
          `INSERT INTO coach_notifications (user_id, kind, subject_id)
           SELECT member_id, 'PACKAGE_EXPIRING', id FROM coach_entitlements
           WHERE member_id = $1 AND status = 'ACTIVE'
             AND ends_on BETWEEN (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
               AND (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 7
           ON CONFLICT DO NOTHING`,
          [request.authUser.id],
        );
      }

      const filters = ['user_id = $1'];
      const values = [request.authUser.id];
      if (category && category !== 'ALL') {
        values.push(category);
        filters.push(`category = $${values.length}`);
      }
      if (unreadOnly === 'true') {
        filters.push('read_at IS NULL');
      }

      const [rowsResult, unreadResult] = await Promise.all([
        client.query(
          `SELECT id, kind, category, subject_id, title, body, action_route, metadata, event_at, read_at
           FROM coach_notifications
           WHERE ${filters.join(' AND ')}
           ORDER BY id DESC
           LIMIT $${values.length + 1}`,
          [...values, limit],
        ),
        client.query(
          `SELECT count(*)::int AS count FROM coach_notifications
           WHERE user_id = $1 AND read_at IS NULL`,
          [request.authUser.id],
        ),
      ]);

      await client.query('COMMIT');
      return response.json({
        data: rowsResult.rows.map(formatNotificationRow),
        meta: {
          unreadCount: unreadResult.rows[0]?.count ?? 0,
        },
      });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được thông báo');
    } finally {
      client.release();
    }
  });

  router.get('/notifications/unread-count', async (request, response) => {
    try {
      const { rows } = await database.query(
        `SELECT count(*)::int AS count FROM coach_notifications
         WHERE user_id = $1 AND read_at IS NULL`,
        [request.authUser.id],
      );
      return response.json({ data: { unreadCount: rows[0]?.count ?? 0 } });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được số thông báo chưa đọc');
    }
  });

  router.patch('/notifications/read-all', async (request, response) => {
    const parsed = readAllBodySchema.safeParse(request.body ?? {});
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu đánh dấu đã đọc không hợp lệ');
    }
    const { category } = parsed.data;
    const filters = ['user_id = $1', 'read_at IS NULL'];
    const values = [request.authUser.id];
    if (category && category !== 'ALL') {
      values.push(category);
      filters.push(`category = $${values.length}`);
    }
    try {
      const result = await database.query(
        `UPDATE coach_notifications
         SET read_at = statement_timestamp()
         WHERE ${filters.join(' AND ')}
         RETURNING id`,
        values,
      );
      return response.json({ data: { updatedCount: result.rowCount ?? result.rows.length } });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không cập nhật được trạng thái đã đọc');
    }
  });

  router.patch('/notifications/:id/read', async (request, response) => {
    const id = request.params.id;
    if (!/^\d{1,18}$/.test(id)) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã thông báo không hợp lệ');
    }
    try {
      const { rows } = await database.query(
        `UPDATE coach_notifications
         SET read_at = COALESCE(read_at, statement_timestamp())
         WHERE id = $1 AND user_id = $2
         RETURNING id, read_at AS "readAt"`,
        [id, request.authUser.id],
      );
      if (!rows.length) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy thông báo');
      }
      return response.json({
        data: { id: String(rows[0].id), readAt: rows[0].readAt },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không cập nhật được trạng thái đã đọc');
    }
  });

  router.get('/notifications/preferences', async (request, response) => {
    try {
      const { rows } = await database.query(
        `SELECT workout_reminders_enabled AS "workoutRemindersEnabled",
                reminder_time AS "reminderTime",
                pt_before_minutes AS "ptBeforeMinutes",
                nutrition_reminders_enabled AS "nutritionRemindersEnabled",
                coach_updates_enabled AS "coachUpdatesEnabled",
                messages_enabled AS "messagesEnabled",
                calls_enabled AS "callsEnabled",
                admin_broadcasts_enabled AS "adminBroadcastsEnabled"
         FROM user_notification_preferences
         WHERE user_id = $1`,
        [request.authUser.id],
      );
      return response.json({
        data: rows[0] ?? { ...DEFAULT_NOTIFICATION_PREFERENCES },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được cài đặt thông báo');
    }
  });

  router.put('/notifications/preferences', async (request, response) => {
    const parsed = preferencesSchema.safeParse(request.body);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Cài đặt thông báo không hợp lệ');
    }
    const p = parsed.data;
    try {
      const { rows } = await database.query(
        `INSERT INTO user_notification_preferences (
           user_id, workout_reminders_enabled, reminder_time, pt_before_minutes,
           nutrition_reminders_enabled, coach_updates_enabled, messages_enabled,
           calls_enabled, admin_broadcasts_enabled, updated_at
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, now())
         ON CONFLICT (user_id) DO UPDATE SET
           workout_reminders_enabled = EXCLUDED.workout_reminders_enabled,
           reminder_time = EXCLUDED.reminder_time,
           pt_before_minutes = EXCLUDED.pt_before_minutes,
           nutrition_reminders_enabled = EXCLUDED.nutrition_reminders_enabled,
           coach_updates_enabled = EXCLUDED.coach_updates_enabled,
           messages_enabled = EXCLUDED.messages_enabled,
           calls_enabled = EXCLUDED.calls_enabled,
           admin_broadcasts_enabled = EXCLUDED.admin_broadcasts_enabled,
           updated_at = now()
         RETURNING workout_reminders_enabled AS "workoutRemindersEnabled",
                   reminder_time AS "reminderTime",
                   pt_before_minutes AS "ptBeforeMinutes",
                   nutrition_reminders_enabled AS "nutritionRemindersEnabled",
                   coach_updates_enabled AS "coachUpdatesEnabled",
                   messages_enabled AS "messagesEnabled",
                   calls_enabled AS "callsEnabled",
                   admin_broadcasts_enabled AS "adminBroadcastsEnabled"`,
        [
          request.authUser.id,
          p.workoutRemindersEnabled,
          p.reminderTime,
          p.ptBeforeMinutes,
          p.nutritionRemindersEnabled,
          p.coachUpdatesEnabled,
          p.messagesEnabled,
          p.callsEnabled,
          p.adminBroadcastsEnabled,
        ],
      );
      return response.json({ data: rows[0] ?? p });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không lưu được cài đặt thông báo');
    }
  });

  router.post('/notifications/device-tokens', async (request, response) => {
    const parsed = deviceTokenRegisterSchema.safeParse(request.body);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Device token không hợp lệ');
    }
    const { token, platform, deviceLabel } = parsed.data;
    try {
      const { rows } = await database.query(
        `INSERT INTO user_device_tokens (id, user_id, token, platform, device_label, is_active, last_seen_at)
         VALUES ($1, $2, $3, $4, $5, true, now())
         ON CONFLICT (token) DO UPDATE SET
           user_id = EXCLUDED.user_id,
           platform = EXCLUDED.platform,
           device_label = COALESCE(EXCLUDED.device_label, user_device_tokens.device_label),
           is_active = true,
           last_seen_at = now()
         RETURNING id, platform, is_active AS "isActive"`,
        [randomUUID(), request.authUser.id, token, platform, deviceLabel ?? null],
      );
      return response.status(201).json({
        data: rows[0] ?? { platform, isActive: true },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không đăng ký được thiết bị nhận thông báo');
    }
  });

  router.delete('/notifications/device-tokens', async (request, response) => {
    const parsed = deviceTokenDeleteSchema.safeParse(request.body ?? {});
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Device token không hợp lệ');
    }
    try {
      await database.query(
        `UPDATE user_device_tokens SET is_active = false
         WHERE token = $1 AND user_id = $2`,
        [parsed.data.token, request.authUser.id],
      );
      return response.json({ data: { removed: true } });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không hủy đăng ký được thiết bị');
    }
  });

  router.get('/admin/notifications/broadcasts', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') {
      return fail(response, 403, 'FORBIDDEN', 'Chỉ Admin được xem lịch sử thông báo');
    }
    const parsed = broadcastListQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Tham số phân trang không hợp lệ');
    }
    const { page, pageSize } = parsed.data;
    try {
      const [totalResult, rowsResult] = await Promise.all([
        database.query(`SELECT count(*)::int AS count FROM admin_notification_broadcasts`),
        database.query(
          `SELECT b.id, b.admin_id AS "adminId", u.full_name AS "adminName",
                  b.title, b.body, b.audience, b.action_route AS "actionRoute",
                  b.recipient_count AS "recipientCount", b.created_at AS "createdAt"
           FROM admin_notification_broadcasts b
           LEFT JOIN users u ON u.id = b.admin_id
           ORDER BY b.created_at DESC, b.id DESC
           LIMIT $1 OFFSET $2`,
          [pageSize, (page - 1) * pageSize],
        ),
      ]);
      const totalItems = totalResult.rows[0]?.count ?? 0;
      return response.json({
        data: rowsResult.rows,
        pagination: {
          page,
          pageSize,
          totalItems,
          totalPages: Math.ceil(totalItems / pageSize),
        },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được lịch sử thông báo');
    }
  });

  router.post('/admin/notifications/broadcast', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') {
      return fail(response, 403, 'FORBIDDEN', 'Chỉ Admin được gửi thông báo hệ thống');
    }
    const parsed = broadcastCreateSchema.safeParse(request.body);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Nội dung thông báo không hợp lệ');
    }
    const { title, body, audience } = parsed.data;
    const actionRoute = parsed.data.actionRoute?.trim() || null;
    if (actionRoute && !actionRoute.startsWith('/')) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Đường dẫn điều hướng phải bắt đầu bằng /');
    }

    const client = await database.connect().catch(() => null);
    if (!client) {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    }

    const broadcastId = randomUUID();
    let insertedNotifications = [];
    let broadcastRow = null;

    try {
      await client.query('BEGIN');
      if (!(await activeAdmin(client, request.authUser))) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }

      const roles = audience === 'ALL' ? ['MEMBER', 'COACH'] : [audience];
      const { rows: recipients } = await client.query(
        `SELECT id FROM users WHERE role = ANY($1::text[]) AND status = 'ACTIVE'`,
        [roles],
      );
      const recipientIds = recipients.map((r) => r.id);

      const { rows: [createdBroadcast] } = await client.query(
        `INSERT INTO admin_notification_broadcasts
           (id, admin_id, title, body, audience, action_route, recipient_count)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING id, admin_id AS "adminId", title, body, audience,
                   action_route AS "actionRoute", recipient_count AS "recipientCount",
                   created_at AS "createdAt"`,
        [broadcastId, request.authUser.id, title, body, audience, actionRoute, recipientIds.length],
      );
      broadcastRow = createdBroadcast;

      if (recipientIds.length) {
        const metadataJson = JSON.stringify({ broadcastId, audience });
        const { rows: createdNotifications } = await client.query(
          `INSERT INTO coach_notifications
             (user_id, kind, category, subject_id, title, body, action_route, metadata)
           SELECT u_id, 'ADMIN_BROADCAST', 'SYSTEM', $2::uuid, $3, $4, $5, $6::jsonb
           FROM unnest($1::uuid[]) AS u_id
           RETURNING id, user_id, kind, category, subject_id, title, body, action_route, metadata, event_at, read_at`,
          [recipientIds, broadcastId, title, body, actionRoute, metadataJson],
        );
        insertedNotifications = createdNotifications;
      }

      await client.query(
        `INSERT INTO admin_audit_logs
           (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'NOTIFICATION_BROADCAST_SENT', 'NOTIFICATION_BROADCAST', $3, $4, $5)`,
        [
          randomUUID(),
          request.authUser.id,
          broadcastId,
          `Gửi thông báo tới ${audience}: ${title}`,
          JSON.stringify({
            broadcastId,
            audience,
            recipientCount: recipientIds.length,
            actionRoute,
          }),
        ],
      );

      await client.query('COMMIT');
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không gửi được thông báo hệ thống');
    } finally {
      client.release();
    }

    if (insertedNotifications.length && (realtime || fcm)) {
      void (async () => {
        const prefsMap = await loadPreferencesMap(
          database,
          insertedNotifications.map((r) => r.user_id),
        );
        for (const row of insertedNotifications) {
          await deliverPushAndRealtime({
            database,
            realtime,
            fcm,
            userId: row.user_id,
            notification: formatNotificationRow(row),
            prefs: prefsMap.get(row.user_id),
          });
        }
      })();
    }

    return response.status(201).json({
      data: broadcastRow ?? {
        id: broadcastId,
        adminId: request.authUser.id,
        title,
        body,
        audience,
        actionRoute,
        recipientCount: insertedNotifications.length,
      },
    });
  });

  return router;
}
