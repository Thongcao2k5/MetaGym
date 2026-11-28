import assert from 'node:assert/strict';
import test from 'node:test';

import { createDomEnvironment, flush, jsonResponse } from './helpers/dom-harness.js';
import { renderShell } from '../src/components/layout.js';
import { renderCoachSchedulePage } from '../src/pages/coach-schedule.js';
import { setCurrentUser, setToken } from '../src/services/api.js';
import { parseHash } from '../src/state/router.js';

test('Coach Schedule renders Day/Week/Month views, opens slot detail drawer, and integrates into Sidebar', async () => {
  const env = createDomEnvironment({ hash: '#/admin/coach-schedule?view=week&date=2026-11-28', token: 'tok' });
  setToken('tok');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', staffPosition: 'ADMIN', permissions: ['*'], fullName: 'Admin', email: 'admin@metagym.vn' });

  assert.equal(parseHash('#/admin/coach-schedule').section, 'coach-schedule');
  assert.equal(parseHash('#/admin/schedule').section, 'coach-schedule');

  const slotData = {
    startMinute: 420,
    endMinute: 510,
    label: '07:00 – 08:30',
    inShiftCount: 2,
    availableCount: 1,
    busyCount: 1,
    blockedCount: 0,
    coaches: [
      { coachId: 'c1', coachName: 'Coach An', state: 'AVAILABLE' },
      { coachId: 'c2', coachName: 'Coach Bình', state: 'BUSY', memberName: 'Nguyễn Minh', bookingStatus: 'BOOKED' },
    ],
  };

  globalThis.fetch = async (url) => {
    const u = new URL(url, 'http://localhost');
    if (u.pathname === '/api/v1/admin/coach-schedule/overview') {
      const view = u.searchParams.get('view') || 'week';
      const base = {
        view,
        date: '2026-11-28',
        month: '2026-11',
        coaches: [
          { id: 'c1', fullName: 'Coach An', scheduleConfigured: true },
          { id: 'c2', fullName: 'Coach Bình', scheduleConfigured: true },
        ],
        totals: { activeCoachCount: 2, configuredCoachCount: 2, inShiftSlots: 2, availableSlots: 1, busySlots: 1, blockedSlots: 0, busyRatePercent: 50 },
      };
      if (view === 'day') {
        return jsonResponse({ data: { ...base, day: { date: '2026-11-28', weekday: 6, slots: [slotData] } } });
      }
      if (view === 'month') {
        return jsonResponse({
          data: {
            ...base,
            monthGrid: {
              month: '2026-11',
              firstWeekday: 7,
              daysInMonth: 30,
              days: [{ date: '2026-11-28', weekday: 6, inShiftCoachCount: 2, inShiftSlots: 2, availableSlots: 1, busySlots: 1, blockedSlots: 0, busyRatePercent: 50 }],
            },
          },
        });
      }
      return jsonResponse({
        data: {
          ...base,
          week: {
            startDate: '2026-11-23',
            endDate: '2026-11-29',
            days: [
              { date: '2026-11-28', weekday: 6 },
              { date: '2026-11-29', weekday: 7 },
            ],
            slotMinutes: [{ startMinute: 420, endMinute: 510, label: '07:00 – 08:30' }],
            cells: { '2026-11-28:420': slotData },
          },
        },
      });
    }
    throw new Error(`Unexpected GET ${u.pathname}`);
  };

  const shell = (opts) => renderShell({ root: env.root, user: { id: 'adm-1', role: 'ADMIN', fullName: 'Admin', email: 'admin@metagym.vn' }, ...opts });

  // 1. Week view + scoped skeleton only inside .cs-week-scroll + drawer + coach roster strip
  const pendingRender = renderCoachSchedulePage({ root: env.root, params: new URLSearchParams({ view: 'week', date: '2026-11-28' }), shell });
  assert.ok(env.root.querySelector('#cs-controls-slot .cs-toolbar'), 'Toolbar should mount immediately without full-page skeleton');
  assert.ok(env.root.querySelector('#cs-view-body > .table-responsive.cs-week-scroll[aria-busy="true"]'), 'Skeleton should scope to .cs-week-scroll only');
  await pendingRender;
  assert.ok(env.root.querySelector('a.meta-nav-item[href="#/admin/coach-schedule"]'));
  assert.ok(env.root.querySelector('[data-cs-coach-chip="c1"]'));
  assert.equal(env.root.innerHTML.includes('05:00 – 22:00'), true);
  assert.equal(env.root.innerHTML.includes('Thứ 2 – Thứ 7'), true);
  assert.equal(env.root.innerHTML.includes('07:00 – 08:30'), true);
  assert.equal(env.root.innerHTML.includes('1 rảnh'), true);

  env.root.querySelector('[data-week-cell="2026-11-28:420"]').click();
  await flush();
  assert.equal(env.drawerOverlay.hidden, false);
  assert.equal(env.drawerPanel.innerHTML.includes('Coach An'), true);
  assert.equal(env.drawerPanel.innerHTML.includes('Nguyễn Minh'), true);

  // 2. Day view
  await renderCoachSchedulePage({ root: env.root, params: new URLSearchParams({ view: 'day', date: '2026-11-28' }), shell });
  assert.equal(env.root.innerHTML.includes('Rảnh 1'), true);
  assert.equal(env.root.innerHTML.includes('Bận 1'), true);
  assert.equal(env.root.innerHTML.includes('Bận · Nguyễn Minh'), true);

  // 3. Month view
  await renderCoachSchedulePage({ root: env.root, params: new URLSearchParams({ view: 'month', month: '2026-11' }), shell });
  assert.equal(env.root.innerHTML.includes('2 Coach'), true);
});
