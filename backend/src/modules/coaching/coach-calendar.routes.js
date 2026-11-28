import { Router } from 'express';
import { z } from 'zod';

import { isCoachScheduleConfigured } from './coach-capacity.js';
import { hasBackofficePermission } from '../users/staff-positions.js';
import { createAuthentication } from '../users/users.routes.js';

const OPERATING_RULE = Object.freeze({
  startClock: '05:00',
  endClock: '22:00',
  slotDurationMinutes: 90,
  weekdays: [1, 2, 3, 4, 5, 6],
});

const uuid = z.uuid();

const querySchema = z.strictObject({
  view: z.enum(['day', 'week', 'month']).default('day'),
  date: z.iso.date().optional(),
  month: z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/, 'Tháng phải có định dạng YYYY-MM').optional(),
  coachId: uuid.optional(),
  onlyAvailable: z.enum(['1', 'true', '0', 'false']).optional(),
});

function fail(response, status, code, message, details = {}) {
  return response.status(status).json({ error: { code, details, message } });
}

export function todayVnIso(now = new Date()) {
  const vn = new Date(now.getTime() + 7 * 3600000);
  return vn.toISOString().slice(0, 10);
}

export function shiftVnDate(dateIso, deltaDays) {
  const [y, m, d] = dateIso.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d + deltaDays)).toISOString().slice(0, 10);
}

export function isoWeekday(dateIso) {
  const [y, m, d] = dateIso.split('-').map(Number);
  const day = new Date(Date.UTC(y, m - 1, d)).getUTCDay();
  return day === 0 ? 7 : day; // 1 = Monday .. 7 = Sunday
}

export function minuteToClock(mins) {
  const h = String(Math.floor(mins / 60)).padStart(2, '0');
  const m = String(mins % 60).padStart(2, '0');
  return `${h}:${m}`;
}

export function getWeekDates(anchorDateIso) {
  const wd = isoWeekday(anchorDateIso);
  const monday = shiftVnDate(anchorDateIso, -(wd - 1));
  return Array.from({ length: 7 }, (_, i) => shiftVnDate(monday, i));
}

export function getMonthDates(monthStr) {
  const [y, m] = monthStr.split('-').map(Number);
  const daysInMonth = new Date(Date.UTC(y, m, 0)).getUTCDate();
  return Array.from({ length: daysInMonth }, (_, i) => {
    const d = String(i + 1).padStart(2, '0');
    return `${monthStr}-${d}`;
  });
}

function slotTimestampRange(dateIso, startMinute) {
  const startsAtIso = `${dateIso}T${minuteToClock(startMinute)}:00+07:00`;
  const startMs = Date.parse(startsAtIso);
  const endMs = startMs + 90 * 60000;
  return {
    startMs,
    endMs,
    startsAt: new Date(startMs).toISOString(),
    endsAt: new Date(endMs).toISOString(),
  };
}

function buildCoachesMap(coaches) {
  return new Map(coaches.map((c) => [c.id, c]));
}

function indexWeeklySlotsByWeekday(weeklySlots) {
  const byWeekday = new Map();
  for (const row of weeklySlots) {
    const wd = Number(row.weekday);
    if (!byWeekday.has(wd)) byWeekday.set(wd, []);
    byWeekday.get(wd).push({
      coachId: row.coach_id,
      weekday: wd,
      startMinute: Number(row.start_minute),
    });
  }
  return byWeekday;
}

function evaluateDaySlots({
  dateIso,
  targetCoaches,
  weeklyByWeekday,
  bookings,
  blocks,
}) {
  const wd = isoWeekday(dateIso);
  const targetCoachIds = new Set(targetCoaches.map((c) => c.id));
  const coachById = buildCoachesMap(targetCoaches);

  const daySlotRows = (weeklyByWeekday.get(wd) || []).filter((s) => targetCoachIds.has(s.coachId));
  const minuteSet = new Set(daySlotRows.map((s) => s.startMinute));
  const sortedMinutes = [...minuteSet].sort((a, b) => a - b);

  const bookingsByCoach = new Map();
  for (const b of bookings) {
    if (!targetCoachIds.has(b.coach_id)) continue;
    const bStart = Date.parse(b.starts_at);
    const bEnd = b.ends_at ? Date.parse(b.ends_at) : bStart + 90 * 60000;
    if (!bookingsByCoach.has(b.coach_id)) bookingsByCoach.set(b.coach_id, []);
    bookingsByCoach.get(b.coach_id).push({
      id: b.id,
      memberName: b.member_name || 'Hội viên',
      status: b.status,
      startMs: bStart,
      endMs: bEnd,
    });
  }

  const blocksByCoach = new Map();
  for (const bl of blocks) {
    if (!targetCoachIds.has(bl.coach_id)) continue;
    const blStart = Date.parse(bl.starts_at);
    const blEnd = blStart + 90 * 60000;
    if (!blocksByCoach.has(bl.coach_id)) blocksByCoach.set(bl.coach_id, []);
    blocksByCoach.get(bl.coach_id).push({
      startMs: blStart,
      endMs: blEnd,
      reason: bl.reason || 'Tạm nghỉ / bận đột xuất',
    });
  }

  const slots = sortedMinutes.map((startMinute) => {
    const endMinute = startMinute + 90;
    const { startMs, endMs, startsAt, endsAt } = slotTimestampRange(dateIso, startMinute);
    const coachesInSlot = [];

    const assignedCoachIds = [...new Set(
      daySlotRows.filter((s) => s.startMinute === startMinute).map((s) => s.coachId),
    )];

    let availableCount = 0;
    let busyCount = 0;
    let blockedCount = 0;

    for (const cid of assignedCoachIds) {
      const coach = coachById.get(cid);
      if (!coach) continue;
      const coachBlock = (blocksByCoach.get(cid) || []).find((bl) => bl.startMs < endMs && bl.endMs > startMs);
      if (coachBlock) {
        blockedCount += 1;
        coachesInSlot.push({
          coachId: coach.id,
          coachName: coach.full_name,
          avatarThumbnailUrl: coach.avatar_media_id ? `/api/v1/users/${coach.id}/avatar?size=120&v=${coach.avatar_media_id}` : null,
          state: 'BLOCKED',
          reason: coachBlock.reason,
        });
        continue;
      }

      const coachBooking = (bookingsByCoach.get(cid) || []).find((bk) => bk.startMs < endMs && bk.endMs > startMs);
      if (coachBooking) {
        busyCount += 1;
        coachesInSlot.push({
          coachId: coach.id,
          coachName: coach.full_name,
          avatarThumbnailUrl: coach.avatar_media_id ? `/api/v1/users/${coach.id}/avatar?size=120&v=${coach.avatar_media_id}` : null,
          state: 'BUSY',
          memberName: coachBooking.memberName,
          bookingStatus: coachBooking.status,
          bookingId: coachBooking.id,
        });
        continue;
      }

      availableCount += 1;
      coachesInSlot.push({
        coachId: coach.id,
        coachName: coach.full_name,
        avatarThumbnailUrl: coach.avatar_media_id ? `/api/v1/users/${coach.id}/avatar?size=120&v=${coach.avatar_media_id}` : null,
        state: 'AVAILABLE',
      });
    }

    const orderRank = { AVAILABLE: 1, BUSY: 2, BLOCKED: 3 };
    coachesInSlot.sort((a, b) => (orderRank[a.state] - orderRank[b.state]) || a.coachName.localeCompare(b.coachName, 'vi'));

    return {
      startMinute,
      endMinute,
      label: `${minuteToClock(startMinute)} – ${minuteToClock(endMinute)}`,
      startClock: minuteToClock(startMinute),
      endClock: minuteToClock(endMinute),
      startsAt,
      endsAt,
      inShiftCount: coachesInSlot.length,
      availableCount,
      busyCount,
      blockedCount,
      coaches: coachesInSlot,
    };
  });

  return {
    date: dateIso,
    weekday: wd,
    slots,
  };
}

export function computeCoachCalendarOverview({
  view,
  dateIso,
  monthStr,
  coaches,
  weeklySlots,
  bookings,
  blocks,
  coachId = null,
  onlyAvailable = false,
}) {
  const targetCoaches = coachId ? coaches.filter((c) => c.id === coachId) : coaches;
  const weeklyByWeekday = indexWeeklySlotsByWeekday(weeklySlots);

  // Per-coach schedule stats
  const weeklySlotsByCoach = new Map();
  const slotCountByCoach = new Map();
  for (const s of weeklySlots) {
    if (!weeklySlotsByCoach.has(s.coach_id)) weeklySlotsByCoach.set(s.coach_id, []);
    weeklySlotsByCoach.get(s.coach_id).push(s);
    slotCountByCoach.set(s.coach_id, (slotCountByCoach.get(s.coach_id) || 0) + 1);
  }

  const coachSummaries = coaches.map((c) => {
    const coachSlots = weeklySlotsByCoach.get(c.id) || [];
    return {
      id: c.id,
      fullName: c.full_name,
      email: c.email,
      avatarThumbnailUrl: c.avatar_media_id ? `/api/v1/users/${c.id}/avatar?size=120&v=${c.avatar_media_id}` : null,
      weeklySlotCount: slotCountByCoach.get(c.id) || 0,
      scheduleConfigured: isCoachScheduleConfigured(coachSlots),
    };
  });

  const sumTotals = (dayObjects) => {
    let inShiftSlots = 0;
    let availableSlots = 0;
    let busySlots = 0;
    let blockedSlots = 0;
    for (const d of dayObjects) {
      for (const s of d.slots) {
        inShiftSlots += s.inShiftCount;
        availableSlots += s.availableCount;
        busySlots += s.busyCount;
        blockedSlots += s.blockedCount;
      }
    }
    const busyRatePercent = inShiftSlots > 0 ? Math.round((busySlots / inShiftSlots) * 100) : 0;
    return {
      activeCoachCount: targetCoaches.length,
      configuredCoachCount: coachSummaries.filter((c) => (!coachId || c.id === coachId) && c.scheduleConfigured).length,
      inShiftSlots,
      availableSlots,
      busySlots,
      blockedSlots,
      busyRatePercent,
    };
  };

  if (view === 'day') {
    const dayObj = evaluateDaySlots({ dateIso, targetCoaches, weeklyByWeekday, bookings, blocks });
    const totals = sumTotals([dayObj]);
    const filteredSlots = onlyAvailable ? dayObj.slots.filter((s) => s.availableCount > 0) : dayObj.slots;
    return {
      view,
      date: dateIso,
      month: dateIso.slice(0, 7),
      range: { from: dateIso, to: dateIso },
      timezone: 'Asia/Ho_Chi_Minh',
      operatingRule: OPERATING_RULE,
      coaches: coachSummaries,
      totals,
      day: { ...dayObj, slots: filteredSlots },
    };
  }

  if (view === 'week') {
    const weekDates = getWeekDates(dateIso);
    const dayResults = weekDates.map((d) => evaluateDaySlots({
      dateIso: d,
      targetCoaches,
      weeklyByWeekday,
      bookings,
      blocks,
    }));
    const totals = sumTotals(dayResults);

    const minuteSet = new Set();
    const cells = {};
    for (const d of dayResults) {
      for (const s of d.slots) {
        if (onlyAvailable && s.availableCount === 0) continue;
        minuteSet.add(s.startMinute);
        cells[`${d.date}:${s.startMinute}`] = s;
      }
    }
    const slotMinutes = [...minuteSet].sort((a, b) => a - b).map((m) => ({
      startMinute: m,
      endMinute: m + 90,
      label: `${minuteToClock(m)} – ${minuteToClock(m + 90)}`,
    }));

    return {
      view,
      date: dateIso,
      month: dateIso.slice(0, 7),
      range: { from: weekDates[0], to: weekDates[weekDates.length - 1] },
      timezone: 'Asia/Ho_Chi_Minh',
      operatingRule: OPERATING_RULE,
      coaches: coachSummaries,
      totals,
      week: {
        startDate: weekDates[0],
        endDate: weekDates[weekDates.length - 1],
        days: dayResults.map((d) => ({
          date: d.date,
          weekday: d.weekday,
          isWorkday: d.weekday >= 1 && d.weekday <= 6,
          inShiftCount: d.slots.reduce((acc, s) => acc + s.inShiftCount, 0),
        })),
        slotMinutes,
        cells,
      },
    };
  }

  // view === 'month'
  const monthDates = getMonthDates(monthStr);
  const monthResults = monthDates.map((d) => evaluateDaySlots({
    dateIso: d,
    targetCoaches,
    weeklyByWeekday,
    bookings,
    blocks,
  }));
  const totals = sumTotals(monthResults);

  const monthDays = monthResults.map((d) => {
    const inShiftSlots = d.slots.reduce((acc, s) => acc + s.inShiftCount, 0);
    const availableSlots = d.slots.reduce((acc, s) => acc + s.availableCount, 0);
    const busySlots = d.slots.reduce((acc, s) => acc + s.busyCount, 0);
    const blockedSlots = d.slots.reduce((acc, s) => acc + s.blockedCount, 0);
    const uniqueCoachIds = new Set();
    for (const s of d.slots) {
      for (const c of s.coaches) uniqueCoachIds.add(c.coachId);
    }
    return {
      date: d.date,
      weekday: d.weekday,
      inShiftCoachCount: uniqueCoachIds.size,
      inShiftSlots,
      availableSlots,
      busySlots,
      blockedSlots,
      busyRatePercent: inShiftSlots > 0 ? Math.round((busySlots / inShiftSlots) * 100) : 0,
    };
  });

  return {
    view: 'month',
    date: dateIso,
    month: monthStr,
    range: { from: monthDates[0], to: monthDates[monthDates.length - 1] },
    timezone: 'Asia/Ho_Chi_Minh',
    operatingRule: OPERATING_RULE,
    coaches: coachSummaries,
    totals,
    monthGrid: {
      month: monthStr,
      firstWeekday: isoWeekday(monthDates[0]),
      daysInMonth: monthDates.length,
      days: onlyAvailable ? monthDays.filter((d) => d.availableSlots > 0) : monthDays,
    },
  };
}

export function createCoachCalendarRouter({ database, jwtSecret }) {
  const router = Router();
  const authenticate = createAuthentication({ database, jwtSecret });

  router.get('/coach-schedule/overview', authenticate, async (request, response) => {
    if (!hasBackofficePermission(request.authUser, 'coaches:read')) {
      return fail(response, 403, 'FORBIDDEN', 'Không có quyền xem lịch làm việc Coach');
    }

    const parsed = querySchema.safeParse(request.query);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', parsed.error.issues[0]?.message || 'Tham số lịch Coach không hợp lệ');
    }

    const { view, coachId } = parsed.data;
    const onlyAvailable = parsed.data.onlyAvailable === '1' || parsed.data.onlyAvailable === 'true';
    const dateIso = parsed.data.date || todayVnIso();
    const monthStr = parsed.data.month || dateIso.slice(0, 7);

    let rangeFrom = dateIso;
    let rangeTo = dateIso;
    if (view === 'week') {
      const weekDates = getWeekDates(dateIso);
      rangeFrom = weekDates[0];
      rangeTo = weekDates[weekDates.length - 1];
    } else if (view === 'month') {
      const monthDates = getMonthDates(monthStr);
      rangeFrom = monthDates[0];
      rangeTo = monthDates[monthDates.length - 1];
    }

    const fromTs = `${rangeFrom}T00:00:00+07:00`;
    const toTs = `${shiftVnDate(rangeTo, 1)}T00:00:00+07:00`;

    try {
      const [coachesRes, weeklyRes, bookingsRes, blocksRes] = await Promise.all([
        database.query(
          `SELECT id, full_name, email::text, avatar_media_id
           FROM users
           WHERE role = 'COACH' AND status = 'ACTIVE'
           ORDER BY full_name ASC`,
        ),
        database.query(
          `SELECT coach_id, weekday, start_minute
           FROM coach_weekly_slots
           ORDER BY weekday ASC, start_minute ASC`,
        ),
        database.query(
          `SELECT b.id, b.coach_id, b.member_id, u.full_name AS member_name,
                  b.starts_at, b.ends_at, b.status
           FROM coach_bookings b
           JOIN users u ON u.id = b.member_id
           WHERE b.status IN ('BOOKED', 'COMPLETED')
             AND b.ends_at > $1::timestamptz
             AND b.starts_at < $2::timestamptz`,
          [fromTs, toTs],
        ),
        database.query(
          `SELECT coach_id, starts_at, reason
           FROM coach_slot_blocks
           WHERE starts_at >= $1::timestamptz
             AND starts_at < $2::timestamptz`,
          [fromTs, toTs],
        ),
      ]);

      const overview = computeCoachCalendarOverview({
        view,
        dateIso,
        monthStr,
        coaches: coachesRes.rows,
        weeklySlots: weeklyRes.rows,
        bookings: bookingsRes.rows,
        blocks: blocksRes.rows,
        coachId: coachId ?? null,
        onlyAvailable,
      });

      return response.json({ data: overview });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được tổng hợp lịch Coach');
    }
  });

  return router;
}
