import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';

import { createApp } from '../src/app.js';
import { computeCoachCalendarOverview } from '../src/modules/coaching/coach-calendar.routes.js';

const SECRET = 'coach-calendar-test-secret-with-32-chars';

function tokenFor(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, SECRET, {
    algorithm: 'HS256',
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    subject: id,
    expiresIn: 3600,
  });
}

test('computeCoachCalendarOverview computes in-shift, available, busy, and blocked across day/week/month', () => {
  const c1 = randomUUID();
  const c2 = randomUUID();
  const coaches = [
    { id: c1, full_name: 'Coach An', email: 'an@metagym.vn', avatar_media_id: null },
    { id: c2, full_name: 'Coach Bình', email: 'binh@metagym.vn', avatar_media_id: null },
  ];

  // Monday = weekday 1 (2026-11-30 is Monday)
  const weeklySlots = [
    { coach_id: c1, weekday: 1, start_minute: 420 }, // 07:00
    { coach_id: c1, weekday: 1, start_minute: 510 }, // 08:30
    { coach_id: c2, weekday: 1, start_minute: 420 }, // 07:00
    { coach_id: c2, weekday: 1, start_minute: 510 }, // 08:30
  ];

  const bookings = [
    {
      id: randomUUID(),
      coach_id: c1,
      member_id: randomUUID(),
      member_name: 'Hội viên Minh',
      starts_at: '2026-11-30T07:00:00+07:00',
      ends_at: '2026-11-30T08:30:00+07:00',
      status: 'BOOKED',
    },
  ];
  const blocks = [
    {
      coach_id: c2,
      starts_at: '2026-11-30T08:30:00+07:00',
      reason: 'Họp chuyên môn',
    },
  ];

  const dayView = computeCoachCalendarOverview({
    view: 'day',
    dateIso: '2026-11-30',
    monthStr: '2026-11',
    coaches,
    weeklySlots,
    bookings,
    blocks,
  });

  assert.equal(dayView.totals.inShiftSlots, 4);
  assert.equal(dayView.totals.availableSlots, 2);
  assert.equal(dayView.totals.busySlots, 1);
  assert.equal(dayView.totals.blockedSlots, 1);
  assert.equal(dayView.operatingRule.startClock, '05:00');
  assert.equal(dayView.operatingRule.endClock, '22:00');
  assert.deepEqual(dayView.operatingRule.weekdays, [1, 2, 3, 4, 5, 6]);
  assert.equal(dayView.day.slots.length, 2);
  assert.equal(dayView.day.slots[0].availableCount, 1);
  assert.equal(dayView.day.slots[0].busyCount, 1);
  assert.equal(dayView.day.slots[0].coaches.find((c) => c.coachId === c1).memberName, 'Hội viên Minh');
  assert.equal(dayView.day.slots[1].blockedCount, 1);
  assert.equal(dayView.day.slots[1].coaches.find((c) => c.coachId === c2).reason, 'Họp chuyên môn');

  const weekView = computeCoachCalendarOverview({
    view: 'week',
    dateIso: '2026-11-30',
    monthStr: '2026-11',
    coaches,
    weeklySlots,
    bookings,
    blocks,
  });
  assert.equal(weekView.week.days.length, 7);
  assert.equal(weekView.week.cells['2026-11-30:420'].busyCount, 1);

  const monthView = computeCoachCalendarOverview({
    view: 'month',
    dateIso: '2026-11-30',
    monthStr: '2026-11',
    coaches,
    weeklySlots,
    bookings,
    blocks,
  });
  assert.equal(monthView.monthGrid.days.length, 30);
  const nov30 = monthView.monthGrid.days.find((d) => d.date === '2026-11-30');
  assert.equal(nov30.inShiftCoachCount, 2);
  assert.equal(nov30.busySlots, 1);
});

test('GET /api/v1/admin/coach-schedule/overview enforces RBAC and omits private health notes', async () => {
  const adminId = randomUUID();
  const memberId = randomUUID();
  const coachId = randomUUID();

  const runQuery = async (sql, params = []) => {
    const text = String(sql).replace(/\s+/g, ' ').trim();
    if (text.includes('FROM users u') && text.includes('WHERE u.id = $1')) {
      const id = params[0];
      const role = id === adminId ? 'ADMIN' : id === coachId ? 'COACH' : 'MEMBER';
      return { rows: [{ id, email: `${role}@metagym.vn`, full_name: role, role, status: 'ACTIVE', session_version: 0 }] };
    }
    if (text.includes('FROM users') && text.includes("role = 'COACH'")) {
      return { rows: [{ id: coachId, full_name: 'HLV Hùng', email: 'hung@metagym.vn', avatar_media_id: null }] };
    }
    if (text.includes('FROM coach_weekly_slots')) {
      return { rows: [{ coach_id: coachId, weekday: 6, start_minute: 420 }] };
    }
    if (text.includes('FROM coach_bookings')) {
      return { rows: [] };
    }
    if (text.includes('FROM coach_slot_blocks')) {
      return { rows: [] };
    }
    return { rows: [] };
  };

  const app = createApp({
    database: { query: runQuery, connect: async () => ({ query: runQuery, release() {} }) },
    jwtSecret: SECRET,
  });

  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    assert.equal((await fetch(`${base}/api/v1/admin/coach-schedule/overview`, {
      headers: { authorization: `Bearer ${tokenFor(memberId, 'MEMBER')}` },
    })).status, 403);
    assert.equal((await fetch(`${base}/api/v1/admin/coach-schedule/overview`, {
      headers: { authorization: `Bearer ${tokenFor(coachId, 'COACH')}` },
    })).status, 403);

    const okRes = await fetch(`${base}/api/v1/admin/coach-schedule/overview?view=week&date=2026-11-28`, {
      headers: { authorization: `Bearer ${tokenFor(adminId, 'ADMIN')}` },
    });
    assert.equal(okRes.status, 200);
    const json = await okRes.json();
    assert.equal(json.data.view, 'week');
    assert.equal(json.data.coaches.length, 1);
    assert.equal(JSON.stringify(json).includes('healthNotes'), false);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
