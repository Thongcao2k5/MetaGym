import assert from 'node:assert/strict';
import test from 'node:test';

import { canFitCoachSessions, isCoachScheduleConfigured } from '../src/services/coach-capacity.js';

const monday = '2026-11-16';
const tuesday = '2026-11-17';
const wednesday = '2026-11-18';
const days = [{ date: monday, available: 1 }, { date: tuesday, available: 1 }];

function demand(from, through, remaining, bookedDates = [], memberId) {
  return { from, through, remaining, bookedDates: new Set(bookedDates), ...(memberId ? { memberId } : {}) };
}

test('assigns the flexible package to a different day to keep a narrow commitment', () => {
  assert.equal(canFitCoachSessions(days, [demand(monday, tuesday, 1), demand(monday, monday, 1)]), true);
});

test('rejects commitments that fit the slot count but violate one session per member per day', () => {
  const sameDay = [{ date: monday, available: 4 }];
  assert.equal(canFitCoachSessions(sameDay, [demand(monday, monday, 2)]), false);
  assert.equal(canFitCoachSessions(days, [demand(monday, tuesday, 2, [monday])]), false);
});

test('enforces one session per member per day across overlapping ACTIVE + QUEUED proposals for the same member', () => {
  const twoDays = [{ date: monday, available: 4 }, { date: tuesday, available: 4 }];
  // Same member with 2 ACTIVE + 1 QUEUED = 3 sessions cannot fit into 2 distinct days
  assert.equal(
    canFitCoachSessions(twoDays, [
      demand(monday, tuesday, 2, [], 'member-1'),
      demand(tuesday, tuesday, 1, [], 'member-1'),
    ]),
    false,
  );
  // Across 3 distinct days, augmenting path moves ACTIVE off Tuesday so QUEUED fits on Tuesday
  const threeDays = [
    { date: monday, available: 1 },
    { date: tuesday, available: 2 },
    { date: wednesday, available: 1 },
  ];
  assert.equal(
    canFitCoachSessions(threeDays, [
      demand(monday, tuesday, 1, [], 'member-2'),
      demand(monday, tuesday, 1, [], 'member-1'),
      demand(tuesday, tuesday, 1, [], 'member-1'),
      demand(monday, wednesday, 1, [], 'member-3'),
    ]),
    true,
  );
  // Empty / inverted window with remaining > 0 is rejected
  assert.equal(canFitCoachSessions(threeDays, [demand(wednesday, monday, 1, [], 'member-1')]), false);
});

test('isCoachScheduleConfigured requires >= 6 weekdays with >= 4 contiguous 90-minute slots each', () => {
  const valid = [];
  for (let d = 1; d <= 6; d += 1) {
    for (const m of [360, 450, 540, 630]) valid.push({ weekday: d, start_minute: m });
  }
  assert.equal(isCoachScheduleConfigured(valid), true);
  // Only 5 weekdays -> false
  assert.equal(isCoachScheduleConfigured(valid.filter((r) => r.weekday <= 5)), false);
  // 6 weekdays, but day 6 has a gap (non-contiguous 4 slots) -> false
  const gapped = valid.map((r) => (r.weekday === 6 && r.start_minute === 540 ? { weekday: 6, start_minute: 720 } : r));
  assert.equal(isCoachScheduleConfigured(gapped), false);
});
