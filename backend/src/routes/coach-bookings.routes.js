import { randomUUID } from 'node:crypto';
import { Router } from 'express';
import { z } from 'zod';

import { hasCoachCapacity } from '../services/coach-capacity.js';
import { notifyExistingUserNotifications } from '../services/notification-dispatcher.js';
import { createAuthentication } from './users.routes.js';

const timestamp = z.iso.datetime({ offset: true });
const uuid = z.uuid();

function error(response, status, code, message) {
  return response.status(status).json({ error: { code, message, details: {} } });
}

function view(row) {
  return {
    id: row.id, entitlementId: row.entitlement_id, memberId: row.member_id,
    coachId: row.coach_id, startsAt: row.starts_at, endsAt: row.ends_at,
    status: row.status, chargedAt: row.charged_at, reason: row.reason,
    memberName: row.member_name, coachName: row.coach_name,
  };
}

async function transact(database, response, work) {
  let client;
  try {
    client = await database.connect();
    await client.query('BEGIN');
    const { status = 200, data } = await work(client);
    await client.query('COMMIT');
    return response.status(status).json({ data });
  } catch (cause) {
    if (client) await client.query('ROLLBACK').catch(() => {});
    if (cause.status) return error(response, cause.status, cause.code, cause.message);
    if (['23P01', '23505'].includes(cause.code)) {
      return error(response, 409, 'BOOKING_CONFLICT', 'Giờ tập hoặc ngày tập đã được đặt');
    }
    return error(response, 500, 'INTERNAL_SERVER_ERROR', 'Không xử lý được lịch Coach');
  } finally {
    client?.release();
  }
}

function reject(status, code, message) {
  throw Object.assign(new Error(message), { status, code });
}

const REST_DAY_TITLE_PATTERN =
  /nghỉ|phục hồi|hồi phục|\brest\b|recovery|off\s*day/i;

function isRestOrRecoveryDayRow(day) {
  if (!day) return true;
  if (Number(day.exercise_count ?? 0) <= 0) return true;
  return REST_DAY_TITLE_PATTERN.test(day.title || '');
}

async function isRestOrRecoveryDateForMember(
  client,
  memberId,
  isoDate,
  isoWeekday,
) {
  const { rows: days } = await client.query(
    `SELECT d.day_number,
            to_char(d.scheduled_date, 'YYYY-MM-DD') AS scheduled_date,
            d.title,
            COUNT(e.id)::int AS exercise_count
     FROM training_plans p
     JOIN training_plan_days d ON d.plan_id = p.id
     LEFT JOIN training_plan_exercises e ON e.plan_day_id = d.id
     WHERE p.member_id = $1 AND p.status = 'ACTIVE'
     GROUP BY d.id, d.day_number, d.scheduled_date, d.title
     ORDER BY d.day_number`,
    [memberId],
  );
  if (!days.length) return false;

  let matched = days.find((d) => d.scheduled_date === isoDate);
  if (!matched) {
    matched = days.find((d) => {
      if (d.scheduled_date) {
        const dt = new Date(`${d.scheduled_date}T00:00:00Z`);
        const wd = dt.getUTCDay() || 7;
        return wd === isoWeekday;
      }
      return (((d.day_number - 1) % 7) + 1) === isoWeekday;
    });
  }
  return isRestOrRecoveryDayRow(matched);
}

async function createBooking(client, entitlement, startsAt) {
  const { rows: [bookingTime] } = await client.query(
    `SELECT to_char($1::timestamptz AT TIME ZONE 'Asia/Ho_Chi_Minh', 'YYYY-MM-DD') AS local_date,
            EXTRACT(ISODOW FROM $1::timestamptz AT TIME ZONE 'Asia/Ho_Chi_Minh')::int AS iso_weekday`,
    [startsAt],
  );
  if (bookingTime && await isRestOrRecoveryDateForMember(
    client,
    entitlement.member_id,
    bookingTime.local_date,
    bookingTime.iso_weekday,
  )) {
    reject(
      409,
      'REST_DAY_BOOKING_NOT_ALLOWED',
      'Ngày đã chọn là ngày nghỉ ngơi hồi phục. Lịch hẹn với Coach bắt buộc phải là ngày tập luyện.',
    );
  }
  const { rows: [slot] } = await client.query(
    `WITH desired AS (
       SELECT $1::timestamptz AS ts, $1::timestamptz AT TIME ZONE 'Asia/Ho_Chi_Minh' AS local
     )
     SELECT 1 FROM desired d JOIN coach_weekly_slots s ON s.coach_id = $2
       AND EXTRACT(ISODOW FROM d.local) = s.weekday
       AND date_trunc('day', d.local) + make_interval(mins => s.start_minute) = d.local
     WHERE d.ts > statement_timestamp() AND d.local::date BETWEEN $3 AND $4
       AND NOT EXISTS (
         SELECT 1 FROM coach_slot_blocks WHERE coach_id = $2 AND starts_at = d.ts
       )
       AND NOT EXISTS (
         SELECT 1 FROM training_sessions t JOIN coach_relationships r ON r.id = t.relationship_id
         WHERE r.coach_id = $2 AND t.status = 'SCHEDULED'
           AND t.scheduled_start_at < d.ts + interval '90 minutes'
           AND COALESCE(t.scheduled_end_at, t.scheduled_start_at + interval '90 minutes') > d.ts
       )`, [startsAt, entitlement.coach_id, entitlement.starts_on, entitlement.ends_on],
  );
  if (!slot) reject(409, 'SLOT_UNAVAILABLE', 'Giờ tập không khả dụng hoặc ngoài hạn gói Coach');
  const { rows: [{ count }] } = await client.query(
    `SELECT count(*)::int AS count FROM coach_bookings
     WHERE entitlement_id = $1 AND status = 'BOOKED'`, [entitlement.id],
  );
  if (count >= entitlement.remaining_sessions) reject(409, 'NO_SESSIONS', 'Không còn lượt để đặt');
  const { rows: [booking] } = await client.query(
    `INSERT INTO coach_bookings (id, entitlement_id, member_id, coach_id, starts_at, ends_at)
     VALUES ($1, $2, $3, $4, $5::timestamptz, $5::timestamptz + interval '90 minutes')
     RETURNING *`, [randomUUID(), entitlement.id, entitlement.member_id, entitlement.coach_id, startsAt],
  );
  if (!await hasCoachCapacity(client, entitlement.coach_id)) {
    reject(409, 'CAPACITY_UNAVAILABLE', 'Khung này ảnh hưởng đến các buổi Coach đã cam kết');
  }
  return booking;
}

async function lockCoach(client, coachId) {
  await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [coachId]);
}

async function lockEntitlement(client, entitlementId, memberId) {
  const { rows: [item] } = await client.query(
    `SELECT e.*, r.status AS relationship_status FROM coach_entitlements e
     JOIN coach_relationships r ON r.id = e.relationship_id
     WHERE e.id = $1 AND e.member_id = $2 FOR UPDATE OF r, e`,
    [entitlementId, memberId],
  );
  if (!item || item.status !== 'ACTIVE' || item.relationship_status !== 'ACTIVE') {
    reject(409, 'COACH_PACKAGE_REQUIRED', 'Cần có gói Coach đang hoạt động');
  }
  return item;
}

async function charge(client, entitlementId, actorId) {
  const { rows: [item] } = await client.query(
    `UPDATE coach_entitlements SET remaining_sessions = remaining_sessions - 1,
       status = CASE WHEN remaining_sessions = 1 THEN 'ENDED' ELSE status END,
       ended_at = CASE WHEN remaining_sessions = 1 THEN statement_timestamp() ELSE ended_at END,
       close_reason = CASE WHEN remaining_sessions = 1 THEN 'COMPLETED_SESSIONS' ELSE close_reason END
     WHERE id = $1 AND status = 'ACTIVE' RETURNING *`, [entitlementId],
  );
  if (!item) reject(409, 'COACH_PACKAGE_REQUIRED', 'Gói Coach không còn hiệu lực');
  if (item.status === 'ENDED') {
    const queued = await client.query(
      `UPDATE coach_entitlements SET status = 'ACTIVE',
        starts_on = (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
        original_ends_on = (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + duration_days - 1,
        ends_on = (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + duration_days - 1
       WHERE relationship_id = $1 AND status = 'QUEUED' RETURNING id`, [item.relationship_id],
    );
    if (!queued.rowCount) {
      await client.query(
        `UPDATE coach_relationships SET status = 'ENDED', ended_at = statement_timestamp(),
           ended_by = $2, end_reason = 'Đã dùng hết số buổi Coach'
         WHERE id = $1 AND status IN ('ACTIVE', 'PAUSED')`, [item.relationship_id, actorId],
      );
    }
  }
}

export function createCoachBookingsRouter({ database, jwtSecret, realtime, fcm }) {
  const router = Router();
  router.use(['/coach-bookings', '/coach-entitlements', '/coach-notifications'],
    createAuthentication({ database, jwtSecret }));

  router.get('/coach-notifications', async (request, response) => {
    return transact(database, response, async (client) => {
      await client.query(
        `INSERT INTO coach_notifications (user_id, kind, subject_id)
         SELECT member_id, 'PACKAGE_EXPIRING', id FROM coach_entitlements
         WHERE member_id = $1 AND status = 'ACTIVE'
           AND ends_on BETWEEN (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
             AND (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 7
         ON CONFLICT DO NOTHING`, [request.authUser.id],
      );
      const { rows } = await client.query(
        `SELECT id, kind, subject_id AS "subjectId", event_at AS "eventAt", read_at AS "readAt"
         FROM coach_notifications WHERE user_id = $1 ORDER BY id DESC LIMIT 100`,
        [request.authUser.id],
      );
      return { data: rows };
    });
  });

  router.patch('/coach-notifications/:id/read', async (request, response) => {
    const id = request.params.id;
    if (!/^\d{1,18}$/.test(id)) return error(response, 422, 'VALIDATION_ERROR', 'Mã thông báo không hợp lệ');
    return transact(database, response, async (client) => {
      const { rows: [item] } = await client.query(
        `UPDATE coach_notifications SET read_at = COALESCE(read_at, statement_timestamp())
         WHERE id = $1 AND user_id = $2 RETURNING id, read_at AS "readAt"`, [id, request.authUser.id],
      );
      if (!item) reject(404, 'NOT_FOUND', 'Không tìm thấy thông báo');
      return { data: item };
    });
  });

  router.get('/coach-entitlements', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return error(response, 403, 'FORBIDDEN', 'Chỉ Member xem gói của mình');
    return transact(database, response, async (client) => {
      const { rows } = await client.query(
        `SELECT e.id, e.coach_id AS "coachId", COALESCE(e.plan_name, h.plan_name) AS "planName", e.status,
           r.status AS "relationshipStatus",
           e.remaining_sessions AS "remainingSessions", e.total_sessions AS "totalSessions",
           e.starts_on::text AS "startsOn", e.ends_on::text AS "endsOn",
           e.frozen_at AS "frozenAt", e.frozen_days_total AS "frozenDaysTotal"
         FROM coach_entitlements e LEFT JOIN coach_payment_holds h ON h.id = e.hold_id
         JOIN coach_relationships r ON r.id = e.relationship_id
         WHERE e.member_id = $1 ORDER BY COALESCE(h.created_at, r.started_at) DESC LIMIT 100`, [request.authUser.id],
      );
      return { data: rows };
    });
  });

  router.get('/coach-bookings', async (request, response) => {
    if (!['MEMBER', 'COACH'].includes(request.authUser.role)) return error(response, 403, 'FORBIDDEN', 'Không có quyền xem lịch Coach');
    return transact(database, response, async (client) => {
      const { rows } = await client.query(
        `SELECT b.*, m.full_name AS member_name, c.full_name AS coach_name
         FROM coach_bookings b JOIN users m ON m.id = b.member_id JOIN users c ON c.id = b.coach_id
         WHERE b.member_id = $1 OR b.coach_id = $1 ORDER BY b.starts_at DESC LIMIT 100`,
        [request.authUser.id],
      );
      return { data: rows.map(view) };
    });
  });

  router.get('/coach-bookings/available-slots', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return error(response, 403, 'FORBIDDEN', 'Chỉ Member xem giờ đặt');
    const parsed = z.strictObject({ entitlementId: uuid, date: z.iso.date(), bookingId: uuid.optional() }).safeParse(request.query);
    if (!parsed.success) return error(response, 422, 'VALIDATION_ERROR', 'Gói hoặc ngày tập không hợp lệ');
    return transact(database, response, async (client) => {
      const { entitlementId, date, bookingId } = parsed.data;
      const isoWeekday = new Date(`${date}T00:00:00Z`).getUTCDay() || 7;
      if (await isRestOrRecoveryDateForMember(client, request.authUser.id, date, isoWeekday)) {
        return { data: [] };
      }
      const { rows } = await client.query(
        `WITH replacement AS (
           SELECT id, starts_at, starts_at < statement_timestamp() + interval '12 hours' AS late
           FROM coach_bookings WHERE id = $4 AND entitlement_id = $1 AND member_id = $2
             AND status = 'BOOKED' AND starts_at > statement_timestamp()
         )
         SELECT slot.starts_at AS "startsAt",
           slot.starts_at + interval '90 minutes' AS "endsAt"
         FROM coach_entitlements e JOIN coach_relationships r ON r.id = e.relationship_id
         JOIN coach_weekly_slots s ON s.coach_id = e.coach_id AND s.weekday = EXTRACT(ISODOW FROM $3::date)
         CROSS JOIN LATERAL (
           SELECT ($3::date + make_interval(mins => s.start_minute)) AT TIME ZONE
             'Asia/Ho_Chi_Minh' AS starts_at
         ) slot
         WHERE e.id = $1 AND e.member_id = $2 AND e.status = 'ACTIVE' AND r.status = 'ACTIVE'
           AND $3::date BETWEEN e.starts_on AND e.ends_on AND slot.starts_at > statement_timestamp()
           AND NOT EXISTS (
             SELECT 1 FROM coach_slot_blocks WHERE coach_id = e.coach_id AND starts_at = slot.starts_at
           )
           AND ($4::uuid IS NULL OR EXISTS (SELECT 1 FROM replacement))
           AND NOT EXISTS (SELECT 1 FROM replacement x WHERE x.starts_at = slot.starts_at)
           AND e.remaining_sessions - COALESCE((SELECT late::int FROM replacement), 0) > (
             SELECT count(*) FROM coach_bookings b WHERE b.entitlement_id = e.id AND b.status = 'BOOKED'
               AND NOT EXISTS (SELECT 1 FROM replacement x WHERE x.id = b.id)
           )
           AND NOT EXISTS (
             SELECT 1 FROM coach_bookings b WHERE NOT EXISTS (
               SELECT 1 FROM replacement x WHERE x.id = b.id AND NOT x.late
             ) AND (
               (b.member_id = e.member_id AND b.booking_date = $3::date
                 AND (b.status IN ('BOOKED', 'COMPLETED') OR b.charged_at IS NOT NULL))
               OR (b.coach_id = e.coach_id AND b.status IN ('BOOKED', 'COMPLETED')
                 AND b.starts_at < slot.starts_at + interval '90 minutes' AND b.ends_at > slot.starts_at))
           ) AND NOT EXISTS (
             SELECT 1 FROM training_sessions t JOIN coach_relationships old ON old.id = t.relationship_id
             WHERE old.coach_id = e.coach_id AND t.status = 'SCHEDULED'
               AND t.scheduled_start_at < slot.starts_at + interval '90 minutes'
               AND COALESCE(t.scheduled_end_at, t.scheduled_start_at + interval '90 minutes') > slot.starts_at
           )
         ORDER BY slot.starts_at`, [entitlementId, request.authUser.id, date, bookingId ?? null],
      );
      return { data: rows };
    });
  });

  router.get('/coach-bookings/blocks', async (request, response) => {
    if (request.authUser.role !== 'COACH') return error(response, 403, 'FORBIDDEN', 'Chỉ Coach quản lý giờ khóa');
    return transact(database, response, async (client) => {
      const { rows } = await client.query(
        `SELECT starts_at AS "startsAt", reason FROM coach_slot_blocks
          WHERE coach_id = $1 AND starts_at > statement_timestamp() ORDER BY starts_at LIMIT 200`,
        [request.authUser.id],
      );
      return { data: rows };
    });
  });

  router.put('/coach-bookings/blocks', async (request, response) => {
    if (request.authUser.role !== 'COACH') return error(response, 403, 'FORBIDDEN', 'Chỉ Coach quản lý giờ khóa');
    const parsed = z.strictObject({
      startsAt: timestamp, blocked: z.boolean(),
      reason: z.string().trim().min(1).max(500).optional(),
    }).safeParse(request.body);
    if (!parsed.success || (parsed.data.blocked && !parsed.data.reason)) {
      return error(response, 422, 'VALIDATION_ERROR', 'Cần cung cấp giờ và lý do khóa');
    }
    return transact(database, response, async (client) => {
      const coachId = request.authUser.id;
      const { startsAt, blocked, reason } = parsed.data;
      await lockCoach(client, coachId);
      if (!blocked) {
        await client.query('DELETE FROM coach_slot_blocks WHERE coach_id = $1 AND starts_at = $2', [coachId, startsAt]);
        return { data: { startsAt, blocked } };
      }
      const { rowCount } = await client.query(
        `WITH desired AS (
           SELECT $2::timestamptz AS ts, $2::timestamptz AT TIME ZONE 'Asia/Ho_Chi_Minh' AS local
         )
         INSERT INTO coach_slot_blocks (coach_id, starts_at, reason)
         SELECT $1, d.ts, $3 FROM desired d JOIN coach_weekly_slots s ON s.coach_id = $1
           AND s.weekday = EXTRACT(ISODOW FROM d.local)
           AND date_trunc('day', d.local) + make_interval(mins => s.start_minute) = d.local
         WHERE d.ts > statement_timestamp() AND NOT EXISTS (
           SELECT 1 FROM coach_bookings b WHERE b.coach_id = $1 AND b.status = 'BOOKED' AND b.starts_at = d.ts
         ) ON CONFLICT (coach_id, starts_at) DO UPDATE SET reason = EXCLUDED.reason`,
        [coachId, startsAt, reason],
      );
      if (!rowCount) reject(409, 'SLOT_UNAVAILABLE', 'Khung ngoài lịch làm việc hoặc đã được đặt');
      if (!await hasCoachCapacity(client, coachId)) {
        reject(409, 'CAPACITY_UNAVAILABLE', 'Khóa giờ này sẽ ảnh hưởng đến các buổi đã cam kết');
      }
      return { data: { startsAt, blocked, reason } };
    });
  });

  router.post('/coach-bookings', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return error(response, 403, 'FORBIDDEN', 'Chỉ Member được đặt lịch');
    const parsed = z.strictObject({ entitlementId: uuid, startsAt: timestamp }).safeParse(request.body);
    if (!parsed.success) return error(response, 422, 'VALIDATION_ERROR', 'Gói hoặc giờ tập không hợp lệ');
    const startedAt = new Date(Date.now() - 2000).toISOString();
    let coachIdToNotify = null;
    const result = await transact(database, response, async (client) => {
      const memberId = request.authUser.id;
      const { entitlementId, startsAt } = parsed.data;
      const { rows: [identity] } = await client.query(
        'SELECT coach_id FROM coach_entitlements WHERE id = $1 AND member_id = $2',
        [entitlementId, memberId],
      );
      if (!identity) reject(404, 'NOT_FOUND', 'Không tìm thấy gói Coach');
      coachIdToNotify = identity.coach_id;
      await lockCoach(client, identity.coach_id);
      const entitlement = await lockEntitlement(client, entitlementId, memberId);
      const booking = await createBooking(client, entitlement, startsAt);
      return { status: 201, data: view(booking) };
    });
    if (coachIdToNotify && (realtime || fcm)) {
      void notifyExistingUserNotifications({
        database,
        realtime,
        fcm,
        userIds: [coachIdToNotify],
        sinceEventAt: startedAt,
      });
    }
    return result;
  });

  router.patch('/coach-bookings/:id', async (request, response) => {
    const id = uuid.safeParse(request.params.id);
    const parsed = z.strictObject({
      action: z.enum(['CANCEL', 'RESCHEDULE', 'COMPLETE', 'NO_SHOW']),
      startsAt: timestamp.optional(),
      reason: z.string().trim().min(1).max(500).optional(),
    }).safeParse(request.body);
    if (!id.success || !parsed.success) return error(response, 422, 'VALIDATION_ERROR', 'Yêu cầu lịch không hợp lệ');
    const { action, startsAt, reason } = parsed.data;
    const isMember = request.authUser.role === 'MEMBER';
    const isCoach = request.authUser.role === 'COACH';
    if (!(action === 'CANCEL' ? isMember || isCoach : action === 'RESCHEDULE' ? isMember : isCoach)) {
      return error(response, 403, 'FORBIDDEN', 'Không có quyền thực hiện thao tác này');
    }
    if ((action === 'RESCHEDULE' && !startsAt) || (action === 'CANCEL' && isCoach && !reason)) {
      return error(response, 422, 'VALIDATION_ERROR', 'Cần nhập giờ mới hoặc lý do hủy');
    }
    const startedAt = new Date(Date.now() - 2000).toISOString();
    let notifyTargets = [];
    const result = await transact(database, response, async (client) => {
      const actorId = request.authUser.id;
      const { rows: [identity] } = await client.query(
        'SELECT * FROM coach_bookings WHERE id = $1 AND (member_id = $2 OR coach_id = $2)',
        [id.data, actorId],
      );
      if (!identity) reject(404, 'NOT_FOUND', 'Không tìm thấy lịch Coach');
      notifyTargets = [identity.member_id, identity.coach_id].filter((uid) => uid && uid !== actorId);
      await lockCoach(client, identity.coach_id);
      await client.query(
        `SELECT r.id FROM coach_relationships r JOIN coach_entitlements e ON e.relationship_id = r.id
         WHERE e.id = $1 FOR UPDATE OF r`, [identity.entitlement_id],
      );
      const { rows: [booking] } = await client.query(
        `SELECT *, starts_at > statement_timestamp() AS future,
           starts_at < statement_timestamp() + interval '12 hours' AS late,
           ends_at <= statement_timestamp() AS finished
         FROM coach_bookings WHERE id = $1 FOR UPDATE`, [id.data],
      );
      if (booking.status !== 'BOOKED') {
        if (action === 'RESCHEDULE') reject(409, 'BOOKING_RESOLVED', 'Lịch cũ đã được xử lý');
        return { data: view(booking) };
      }
      if (action === 'RESCHEDULE' && Date.parse(startsAt) === booking.starts_at.getTime()) {
        reject(422, 'VALIDATION_ERROR', 'Giờ mới phải khác giờ đã đặt');
      }
      const completion = ['COMPLETE', 'NO_SHOW'].includes(action);
      if ((completion && !booking.finished) || (!completion && !booking.future)) {
        reject(409, 'BOOKING_TIME', 'Thao tác chưa phù hợp với thời điểm của buổi tập');
      }
      const charged = completion || (isMember && booking.late);
      const { rows: [resolved] } = await client.query(
        `UPDATE coach_bookings SET status = $2, resolved_at = statement_timestamp(),
           resolved_by = $3, reason = $4,
           charged_at = CASE WHEN $5 THEN statement_timestamp() END WHERE id = $1 RETURNING *`,
        [id.data, action === 'COMPLETE' ? 'COMPLETED' : 'CANCELLED', actorId,
          action === 'NO_SHOW' ? 'Member vắng không lý do' : reason ?? null, charged],
      );
      if (charged) await charge(client, booking.entitlement_id, actorId);
      if (action !== 'RESCHEDULE') return { data: view(resolved) };
      const entitlement = await lockEntitlement(client, booking.entitlement_id, actorId);
      const replacement = await createBooking(client, entitlement, startsAt);
      return { data: view(replacement) };
    });
    if (notifyTargets.length && (realtime || fcm)) {
      void notifyExistingUserNotifications({
        database,
        realtime,
        fcm,
        userIds: notifyTargets,
        sinceEventAt: startedAt,
      });
    }
    return result;
  });
  return router;
}
