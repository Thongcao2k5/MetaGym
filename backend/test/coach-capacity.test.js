import assert from 'node:assert/strict';
import test from 'node:test';

import { canFitCoachSessions } from '../src/services/coach-capacity.js';

const monday = '2026-11-16';
const tuesday = '2026-11-17';
const days = [{ date: monday, available: 1 }, { date: tuesday, available: 1 }];

function demand(from, through, remaining, bookedDates = []) {
  return { from, through, remaining, bookedDates: new Set(bookedDates) };
}

test('assigns the flexible package to a different day to keep a narrow commitment', () => {
  assert.equal(canFitCoachSessions(days, [demand(monday, tuesday, 1), demand(monday, monday, 1)]), true);
});

test('rejects commitments that fit the slot count but violate one session per member per day', () => {
  const sameDay = [{ date: monday, available: 4 }];
  assert.equal(canFitCoachSessions(sameDay, [demand(monday, monday, 2)]), false);
  assert.equal(canFitCoachSessions(days, [demand(monday, tuesday, 2, [monday])]), false);
});
