export const DEFAULT_NOTIFICATION_PREFERENCES = {
  workoutRemindersEnabled: true,
  reminderTime: '17:30',
  ptBeforeMinutes: 30,
  nutritionRemindersEnabled: true,
  coachUpdatesEnabled: true,
  messagesEnabled: true,
  callsEnabled: true,
  adminBroadcastsEnabled: true,
};

export function inferCategoryForKind(kind) {
  const k = String(kind ?? '').toUpperCase();
  if (k === 'TRAINING_PLAN_UPDATED' || k === 'NUTRITION_UPDATED' || k === 'MEAL_PLAN_UPDATED') {
    return 'TRAINING';
  }
  if (k === 'NEW_MESSAGE' || k === 'MISSED_CALL' || k === 'INCOMING_CALL') {
    return 'MESSAGE';
  }
  if (
    k === 'ADMIN_BROADCAST' ||
    k === 'COACH_LOCKED' ||
    k === 'COACH_UNLOCKED_RESTORED' ||
    k === 'MEMBER_LOCKED' ||
    k === 'MEMBER_UNLOCKED_RESTORED'
  ) {
    return 'SYSTEM';
  }
  return 'COACH';
}

const DEFAULT_COPY_BY_KIND = {
  BOOKED: {
    title: 'Có lịch tập mới với Coach',
    body: 'Buổi tập 1:1 với Coach đã được ghi nhận. Kiểm tra khung giờ trong mục Lịch hẹn.',
  },
  COMPLETED: {
    title: 'Coach đã xác nhận buổi tập',
    body: 'Buổi tập đã hoàn tất và cập nhật vào số buổi còn lại trong gói Coach.',
  },
  CANCELLED: {
    title: 'Lịch tập đã hủy hoặc thay đổi',
    body: 'Một buổi tập với Coach đã hủy hoặc thay đổi. Bạn có thể đặt lại khung giờ phù hợp.',
  },
  NO_SHOW: {
    title: 'Buổi tập ghi nhận vắng mặt',
    body: 'Buổi tập đã qua giờ hẹn và được ghi nhận vắng mặt theo quy định gói tập.',
  },
  RESCHEDULED: {
    title: 'Lịch tập đã được dời giờ',
    body: 'Khung giờ buổi tập 1:1 vừa được cập nhật. Xem chi tiết trong mục Lịch hẹn.',
  },
  TRAINING_PLAN_UPDATED: {
    title: 'Coach đã cập nhật giáo trình tập',
    body: 'Giáo trình tập luyện mới đã sẵn sàng trong mục Tập luyện.',
  },
  NUTRITION_UPDATED: {
    title: 'Coach đã cập nhật thực đơn',
    body: 'Thực đơn dinh dưỡng cá nhân hóa đã sẵn sàng trong mục Dinh dưỡng.',
  },
  MEAL_PLAN_UPDATED: {
    title: 'Coach đã cập nhật thực đơn',
    body: 'Thực đơn dinh dưỡng cá nhân hóa đã sẵn sàng trong mục Dinh dưỡng.',
  },
  PACKAGE_ACTIVE: {
    title: 'Gói Coach đã kích hoạt',
    body: 'Gói huấn luyện 1:1 đã kích hoạt. Bạn có thể bắt đầu đặt lịch tập cùng Coach.',
  },
  PACKAGE_QUEUED: {
    title: 'Gói Coach đang chờ kích hoạt',
    body: 'Gói mới đã được xếp hàng và sẽ tự kích hoạt ngay sau khi gói hiện tại kết thúc.',
  },
  PACKAGE_EXTENDED: {
    title: 'Gói Coach được thêm 7 ngày',
    body: 'Thời hạn sử dụng gói Coach của bạn vừa được cộng thêm 7 ngày.',
  },
  PACKAGE_LAST_SESSION: {
    title: 'Gói Coach còn 1 buổi',
    body: 'Bạn còn 1 buổi trong gói hiện tại. Cân nhắc gia hạn để giữ nhịp tập luyện.',
  },
  PACKAGE_ENDED: {
    title: 'Gói Coach đã kết thúc',
    body: 'Gói huấn luyện 1:1 đã sử dụng hết số buổi hoặc kết thúc thời hạn.',
  },
  PACKAGE_EXPIRING: {
    title: 'Gói Coach còn tối đa 7 ngày',
    body: 'Gói tập của bạn sắp hết hạn trong 7 ngày tới. Hãy hoàn thành các buổi còn lại.',
  },
  COACH_LOCKED: {
    title: 'Tài khoản Coach đang tạm khóa',
    body: 'Gói tập đã được đóng băng tự động. Vào Coach & Lịch hẹn để chọn phương án xử lý.',
  },
  COACH_UNLOCKED_RESTORED: {
    title: 'Coach đã hoạt động trở lại',
    body: 'Quan hệ huấn luyện và gói tập của bạn đã được khôi phục bình thường.',
  },
  MEMBER_LOCKED: {
    title: 'Tài khoản hội viên đang tạm khóa',
    body: 'Quan hệ huấn luyện đang tạm ngưng trong thời gian tài khoản tạm khóa.',
  },
  MEMBER_UNLOCKED_RESTORED: {
    title: 'Tài khoản đã được mở khóa',
    body: 'Quan hệ huấn luyện đã được khôi phục và có thể tiếp tục đặt lịch.',
  },
  TERMINATION_REQUESTED: {
    title: 'Có yêu cầu kết thúc sớm',
    body: 'Yêu cầu kết thúc sớm quan hệ Coach đang chờ phản hồi trong vòng 72 giờ.',
  },
  TERMINATION_ACCEPTED: {
    title: 'Đã đồng ý kết thúc sớm',
    body: 'Hai bên đã xác nhận kết thúc sớm quan hệ huấn luyện 1:1.',
  },
  TERMINATION_WITHDRAWN: {
    title: 'Yêu cầu kết thúc sớm đã rút',
    body: 'Yêu cầu kết thúc sớm đã được rút lại; quan hệ Coach tiếp tục bình thường.',
  },
  TERMINATION_DISPUTED: {
    title: 'Yêu cầu đang chờ Admin phân xử',
    body: 'Yêu cầu kết thúc sớm đang được bộ phận quản trị xem xét và phản hồi.',
  },
  TERMINATION_ADMIN_APPROVED: {
    title: 'Admin đã duyệt kết thúc sớm',
    body: 'Quản trị viên đã phê duyệt yêu cầu kết thúc sớm quan hệ huấn luyện.',
  },
  TERMINATION_ADMIN_REJECTED: {
    title: 'Admin từ chối yêu cầu kết thúc sớm',
    body: 'Quản trị viên không chấp thuận kết thúc sớm; quan hệ Coach được giữ nguyên.',
  },
  COACH_TRANSFERRED: {
    title: 'Đã chuyển đổi Coach đồng hành',
    body: 'Gói tập và lịch trình của bạn đã được chuyển sang Coach mới thành công.',
  },
  SIMULATED_REFUND_COMPLETED: {
    title: 'Hoàn tiền mô phỏng hoàn tất',
    body: 'Yêu cầu hoàn giá trị các buổi tập chưa sử dụng đã được xử lý xong.',
  },
  NEW_MESSAGE: {
    title: 'Bạn có tin nhắn mới',
    body: 'Mở mục Tin nhắn để xem và phản hồi ngay.',
  },
  MISSED_CALL: {
    title: 'Cuộc gọi nhỡ',
    body: 'Bạn có một cuộc gọi nhỡ. Mở mục Cuộc gọi để xem chi tiết.',
  },
  INCOMING_CALL: {
    title: 'Cuộc gọi đến',
    body: 'Bạn có cuộc gọi đến trên Meta Gym.',
  },
  ADMIN_BROADCAST: {
    title: 'Thông báo từ Meta Gym',
    body: 'Hệ thống vừa gửi một thông báo mới dành cho bạn.',
  },
};

export function defaultCopyForKind(kind) {
  const k = String(kind ?? '').toUpperCase();
  return DEFAULT_COPY_BY_KIND[k] ?? {
    title: 'Có cập nhật về Coach',
    body: 'Kiểm tra mục Coach & Lịch hẹn để xem thông tin chi tiết mới nhất.',
  };
}

export function defaultRouteForKind(kind, role = 'MEMBER') {
  const k = String(kind ?? '').toUpperCase();
  const isCoach = String(role).toUpperCase() === 'COACH';
  if (['BOOKED', 'COMPLETED', 'CANCELLED', 'NO_SHOW', 'RESCHEDULED'].includes(k)) {
    return isCoach ? '/coach/features/sessions' : '/member/features/sessions';
  }
  if (k === 'TRAINING_PLAN_UPDATED') {
    return isCoach ? '/coach/features/training' : '/member/features/training';
  }
  if (k === 'NUTRITION_UPDATED' || k === 'MEAL_PLAN_UPDATED') {
    return isCoach ? '/coach/features/nutrition' : '/member/features/nutrition';
  }
  if (k === 'NEW_MESSAGE') {
    return isCoach ? '/coach/features/messages' : '/member/features/messages';
  }
  if (k === 'MISSED_CALL' || k === 'INCOMING_CALL') {
    return isCoach ? '/coach/features/calls' : '/member/features/calls';
  }
  if (k.startsWith('PACKAGE_') || k.startsWith('TERMINATION_') || k.startsWith('COACH_') || k.startsWith('MEMBER_') || k === 'SIMULATED_REFUND_COMPLETED') {
    return isCoach ? '/coach/features/members' : '/member/features/my-coach';
  }
  return null;
}

export function formatNotificationRow(row) {
  const kind = row.kind;
  const defaults = defaultCopyForKind(kind);
  const category = row.category || inferCategoryForKind(kind);
  const eventAt = row.event_at ?? row.eventAt ?? null;
  return {
    id: row.id == null ? null : String(row.id),
    kind,
    category,
    subjectId: row.subject_id ?? row.subjectId ?? null,
    title: row.title ?? defaults.title,
    body: row.body ?? defaults.body,
    actionRoute: row.action_route ?? row.actionRoute ?? null,
    metadata: row.metadata ?? {},
    eventAt,
    createdAt: eventAt,
    readAt: row.read_at ?? row.readAt ?? null,
  };
}

export function isDeliveryEnabledForPreferences(prefs, { kind, category, bypassPreferences = false }) {
  if (bypassPreferences) return true;
  const k = String(kind ?? '').toUpperCase();
  if (['COACH_LOCKED', 'COACH_UNLOCKED_RESTORED', 'MEMBER_LOCKED', 'MEMBER_UNLOCKED_RESTORED'].includes(k)) {
    return true;
  }
  const effective = { ...DEFAULT_NOTIFICATION_PREFERENCES, ...(prefs ?? {}) };
  if (k === 'INCOMING_CALL' || k === 'MISSED_CALL') {
    return effective.callsEnabled !== false;
  }
  if (k === 'NEW_MESSAGE') {
    return effective.messagesEnabled !== false;
  }
  const cat = category || inferCategoryForKind(k);
  if (cat === 'SYSTEM') {
    return effective.adminBroadcastsEnabled !== false;
  }
  if (cat === 'MESSAGE') {
    return effective.messagesEnabled !== false;
  }
  return effective.coachUpdatesEnabled !== false;
}

function channelIdFor({ kind, category }) {
  const k = String(kind ?? '').toUpperCase();
  if (k === 'INCOMING_CALL') return 'metagym_calls';
  if (k === 'NEW_MESSAGE' || k === 'MISSED_CALL' || category === 'MESSAGE') return 'metagym_messages';
  if (category === 'TRAINING') return 'metagym_reminders';
  return 'metagym_general';
}

export async function loadPreferencesMap(database, userIds) {
  const uniqueIds = [...new Set((userIds ?? []).filter(Boolean))];
  const map = new Map();
  if (!uniqueIds.length) return map;
  try {
    const { rows } = await database.query(
      `SELECT user_id,
              workout_reminders_enabled AS "workoutRemindersEnabled",
              reminder_time AS "reminderTime",
              pt_before_minutes AS "ptBeforeMinutes",
              nutrition_reminders_enabled AS "nutritionRemindersEnabled",
              coach_updates_enabled AS "coachUpdatesEnabled",
              messages_enabled AS "messagesEnabled",
              calls_enabled AS "callsEnabled",
              admin_broadcasts_enabled AS "adminBroadcastsEnabled"
       FROM user_notification_preferences
       WHERE user_id = ANY($1::uuid[])`,
      [uniqueIds],
    );
    for (const row of rows) {
      map.set(row.user_id, row);
    }
  } catch {
    // Degrade silently to default preferences if table/query is unavailable in mocked tests.
  }
  return map;
}

export async function deliverPushAndRealtime({
  database,
  realtime,
  fcm,
  userId,
  notification,
  prefs,
  bypassPreferences = false,
  highPriority = false,
}) {
  if (!userId || !notification) return;
  const enabled = isDeliveryEnabledForPreferences(prefs, {
    kind: notification.kind,
    category: notification.category,
    bypassPreferences,
  });
  if (!enabled) return;

  try {
    await realtime?.publish(userId, 'notification', notification);
  } catch {
    // Non-blocking realtime publish.
  }

  if (!fcm) return;
  try {
    const { rows } = await database.query(
      `SELECT token FROM user_device_tokens WHERE user_id = $1 AND is_active = true`,
      [userId],
    );
    const tokens = rows.map((r) => r.token).filter(Boolean);
    if (!tokens.length) return;
    const result = await fcm.sendToTokens(tokens, {
      title: notification.title,
      body: notification.body,
      channelId: channelIdFor(notification),
      highPriority,
      data: {
        notificationId: notification.id ?? '',
        kind: notification.kind ?? '',
        category: notification.category ?? 'COACH',
        subjectId: notification.subjectId ?? '',
        actionRoute: notification.actionRoute ?? '',
      },
    });
    if (result?.invalidTokens?.length) {
      await database.query(
        `UPDATE user_device_tokens SET is_active = false WHERE token = ANY($1::text[])`,
        [result.invalidTokens],
      ).catch(() => {});
    }
  } catch {
    // Non-blocking FCM delivery.
  }
}

export async function dispatchNotification({
  database,
  client,
  realtime,
  fcm,
  userId,
  kind,
  category,
  subjectId = null,
  title = null,
  body = null,
  actionRoute = null,
  metadata = {},
  insert = true,
  bypassPreferences = false,
  highPriority = false,
}) {
  const resolvedCategory = category || inferCategoryForKind(kind);
  const defaults = defaultCopyForKind(kind);
  const resolvedTitle = title ?? defaults.title;
  const resolvedBody = body ?? defaults.body;
  let formatted;

  if (insert) {
    const db = client ?? database;
    const { rows: [inserted] } = await db.query(
      `INSERT INTO coach_notifications
         (user_id, kind, category, subject_id, title, body, action_route, metadata)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)
       RETURNING id, user_id, kind, category, subject_id, title, body, action_route, metadata, event_at, read_at`,
      [
        userId,
        kind,
        resolvedCategory,
        subjectId,
        resolvedTitle,
        resolvedBody,
        actionRoute,
        JSON.stringify(metadata ?? {}),
      ],
    );
    formatted = inserted
      ? formatNotificationRow(inserted)
      : formatNotificationRow({
          id: null,
          kind,
          category: resolvedCategory,
          subject_id: subjectId,
          title: resolvedTitle,
          body: resolvedBody,
          action_route: actionRoute,
          metadata,
          event_at: new Date().toISOString(),
          read_at: null,
        });
  } else {
    formatted = formatNotificationRow({
      id: null,
      kind,
      category: resolvedCategory,
      subject_id: subjectId,
      title: resolvedTitle,
      body: resolvedBody,
      action_route: actionRoute,
      metadata,
      event_at: new Date().toISOString(),
      read_at: null,
    });
  }

  // When inside a caller-managed transaction (`client` passed), still allow caller to skip
  // or deliver after commit; if called with `database` (post-commit) or without `client`, deliver immediately.
  if (!client && (realtime || fcm)) {
    const prefsMap = await loadPreferencesMap(database, [userId]);
    await deliverPushAndRealtime({
      database,
      realtime,
      fcm,
      userId,
      notification: formatted,
      prefs: prefsMap.get(userId),
      bypassPreferences,
      highPriority,
    });
  }

  return formatted;
}

export async function notifyExistingUserNotifications({
  database,
  realtime,
  fcm,
  userIds,
  sinceEventAt,
}) {
  if (!realtime && !fcm) return;
  const uniqueIds = [...new Set((userIds ?? []).filter(Boolean))];
  if (!uniqueIds.length) return;
  try {
    const { rows } = await database.query(
      `SELECT id, user_id, kind, category, subject_id, title, body, action_route, metadata, event_at, read_at
       FROM coach_notifications
       WHERE user_id = ANY($1::uuid[])
         AND ($2::timestamptz IS NULL OR event_at >= $2::timestamptz)
       ORDER BY id DESC
       LIMIT 20`,
      [uniqueIds, sinceEventAt ?? null],
    );
    if (!rows.length) return;
    const prefsMap = await loadPreferencesMap(database, uniqueIds);
    for (const row of rows) {
      const formatted = formatNotificationRow(row);
      await deliverPushAndRealtime({
        database,
        realtime,
        fcm,
        userId: row.user_id,
        notification: formatted,
        prefs: prefsMap.get(row.user_id),
      });
    }
  } catch {
    // Non-blocking best-effort broadcast.
  }
}
