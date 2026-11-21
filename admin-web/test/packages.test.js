import assert from 'node:assert/strict';
import test from 'node:test';

import { createDomEnvironment, flush, jsonResponse } from './helpers/dom-harness.js';
import { setCurrentUser, setToken } from '../src/services/api.js';
import { renderShell } from '../src/components/layout.js';
import { renderPlansPage } from '../src/pages/plans.js';
import { renderCoachPackagesPage } from '../src/pages/coach-packages.js';

function makeShell(root) {
  return (opts) => renderShell({ root, user: { fullName: 'Admin' }, ...opts });
}

test('T10 Gym Plans catalog allows direct editing of price & durationDays with snapshot warning banner', async () => {
  const env = createDomEnvironment({ hash: '#/admin/plans', token: 'tok' });
  setToken('tok');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Admin' });

  const requests = [];
  let plan = {
    id: 'plan-90',
    name: 'Gói Gym 90 ngày',
    description: 'Ưu đãi quý',
    price: 1650000,
    durationDays: 90,
    status: 'ACTIVE',
    activeMembershipCount: 39,
    scheduledMembershipCount: 5,
  };

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    const body = options.body ? JSON.parse(options.body) : undefined;
    requests.push({ path: parsed.pathname, method: options.method || 'GET', body, search: parsed.search });

    if (parsed.pathname === '/api/v1/admin/membership-plans' && (!options.method || options.method === 'GET')) {
      return jsonResponse({ data: [plan], pagination: { page: 1, pageSize: 20, totalItems: 1, totalPages: 1 } });
    }
    if (parsed.pathname === '/api/v1/admin/membership-plans/plan-90' && options.method === 'PATCH') {
      plan = { ...plan, ...body };
      return jsonResponse({ data: plan });
    }
    throw new Error(`Unexpected ${options.method || 'GET'} ${parsed.pathname}`);
  };

  await renderPlansPage({ root: env.root, params: new URLSearchParams(), shell: makeShell(env.root) });

  assert.equal(env.root.innerHTML.includes('Thay đổi chỉ áp dụng cho giao dịch mới; gói đã mua giữ nguyên snapshot'), true);
  assert.equal(env.root.innerHTML.includes('39'), true);
  assert.equal(env.root.innerHTML.includes('5 đã xếp lịch'), true);

  env.root.querySelector('.edit-plan').click();
  await flush();
  assert.equal(env.modalDialog.innerHTML.includes('Thay đổi chỉ áp dụng cho giao dịch mới; gói đã mua giữ nguyên snapshot'), true);

  env.modalDialog.querySelector('[name="price"]').value = '1790000';
  env.modalDialog.querySelector('[name="durationDays"]').value = '95';
  env.modalDialog.querySelector('#plan-form').dispatchEvent({ type: 'submit' });
  await flush();

  const patch = requests.find((r) => r.method === 'PATCH');
  assert.deepEqual(patch.body, {
    name: 'Gói Gym 90 ngày',
    description: 'Ưu đãi quý',
    price: 1790000,
    durationDays: 95,
    status: 'ACTIVE',
  });
});

test('T10 Gym Plans entitlements tab calls GET /admin/memberships with human names and zero raw UUIDs', async () => {
  const env = createDomEnvironment({ hash: '#/admin/plans?tab=entitlements', token: 'tok' });
  setToken('tok');

  const requests = [];
  globalThis.fetch = async (url) => {
    const parsed = new URL(url, 'http://localhost');
    requests.push({ path: parsed.pathname, search: parsed.search });
    if (parsed.pathname === '/api/v1/admin/memberships') {
      return jsonResponse({
        data: [{
          id: 'memship-uuid-1234',
          memberId: 'member-uuid-5678',
          memberName: 'Nguyễn Thảo Vy',
          memberEmail: 'vy@metagym.vn',
          planName: 'Gói Gym 90 ngày',
          startDate: '2026-10-04',
          endDate: '2027-01-02',
          status: 'ACTIVE',
        }],
        pagination: { page: 1, pageSize: 20, totalItems: 1, totalPages: 1 },
      });
    }
    throw new Error(`Unexpected ${parsed.pathname}`);
  };

  await renderPlansPage({
    root: env.root,
    params: new URLSearchParams({ tab: 'entitlements' }),
    shell: makeShell(env.root),
  });

  assert.equal(requests[0].path, '/api/v1/admin/memberships');
  const tableHtml = env.root.querySelector('table').innerHTML;
  assert.equal(tableHtml.includes('Nguyễn Thảo Vy'), true);
  assert.equal(tableHtml.includes('Gói Gym 90 ngày'), true);
  assert.equal(tableHtml.includes('04/10/2026'), true);
  assert.equal(tableHtml.includes('member-uuid-5678'), false, 'Table must not show raw member UUID');
  assert.equal(tableHtml.includes('memship-uuid-1234'), false, 'Table must not show raw membership UUID');

  const statusSel = env.root.querySelector('#plans-status');
  statusSel.value = 'SCHEDULED';
  statusSel.dispatchEvent({ type: 'change' });
  await flush();
  assert.equal(requests[requests.length - 1].search.includes('status=SCHEDULED'), true);
});

test('T10 Coach Packages supports creating custom package PRO_40, preserves input on 409, and edits all fields', async () => {
  const env = createDomEnvironment({ hash: '#/admin/coach-packages', token: 'tok' });
  setToken('tok');

  const requests = [];
  const packages = [{
    code: 'BASIC',
    name: 'Cơ bản',
    description: '10 buổi nền tảng',
    sessionCount: 10,
    durationDays: 30,
    price: 3000000,
    status: 'ACTIVE',
    activeEntitlementCount: 12,
    queuedEntitlementCount: 3,
  }];
  let failOnce = true;

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    const body = options.body ? JSON.parse(options.body) : undefined;
    requests.push({ path: parsed.pathname, method: options.method || 'GET', body });

    if (parsed.pathname === '/api/v1/admin/coach-packages' && (!options.method || options.method === 'GET')) {
      return jsonResponse({ data: packages });
    }
    if (parsed.pathname === '/api/v1/admin/coach-packages' && options.method === 'POST') {
      if (failOnce) {
        failOnce = false;
        return jsonResponse({ error: { code: 'COACH_PACKAGE_CODE_EXISTS', message: 'Mã gói đã tồn tại' } }, 409);
      }
      packages.push({ ...body, activeEntitlementCount: 0, queuedEntitlementCount: 0 });
      return jsonResponse({ data: body }, 201);
    }
    if (parsed.pathname === '/api/v1/admin/coach-packages/BASIC' && options.method === 'PATCH') {
      Object.assign(packages[0], body);
      return jsonResponse({ data: packages[0] });
    }
    throw new Error(`Unexpected ${options.method || 'GET'} ${parsed.pathname}`);
  };

  await renderCoachPackagesPage({ root: env.root, params: new URLSearchParams(), shell: makeShell(env.root) });

  assert.equal(env.root.innerHTML.includes('12'), true);
  assert.equal(env.root.innerHTML.includes('3 chờ nối tiếp'), true);

  // Create PRO_40 -> first fails 409 preserving values -> retry succeeds
  env.root.querySelector('#create-cp').click();
  await flush();

  env.modalDialog.querySelector('[name="code"]').value = 'PRO_40';
  env.modalDialog.querySelector('[name="name"]').value = 'Chuyên sâu 40 buổi';
  env.modalDialog.querySelector('[name="description"]').value = 'Lộ trình 120 ngày thi đấu';
  env.modalDialog.querySelector('[name="sessionCount"]').value = '40';
  env.modalDialog.querySelector('[name="durationDays"]').value = '120';
  env.modalDialog.querySelector('[name="price"]').value = '7200000';
  env.modalDialog.querySelector('#coach-pkg-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(env.modalOverlay.hidden, false, 'Modal stays open on 409 error');
  assert.equal(env.modalDialog.querySelector('[name="code"]').value, 'PRO_40', 'Preserves code on 409');
  assert.equal(env.modalDialog.innerHTML.includes('Mã gói đã tồn tại'), true);

  // Retry submit succeeds
  env.modalDialog.querySelector('#coach-pkg-form').dispatchEvent({ type: 'submit' });
  await flush();
  assert.equal(env.modalOverlay.hidden, true);
  assert.equal(env.root.innerHTML.includes('PRO_40'), true);
  assert.equal(env.root.innerHTML.includes('Chuyên sâu 40 buổi'), true);

  // Edit BASIC updating ALL fields (name, description, sessionCount, durationDays, price, status)
  env.root.querySelector('.edit-cp[data-code="BASIC"]').click();
  await flush();
  assert.equal(env.modalDialog.innerHTML.includes('Thay đổi chỉ áp dụng cho giao dịch mới'), true);
  env.modalDialog.querySelector('[name="name"]').value = 'Cơ bản Nâng cấp';
  env.modalDialog.querySelector('[name="description"]').value = 'Mô tả mới';
  env.modalDialog.querySelector('[name="sessionCount"]').value = '12';
  env.modalDialog.querySelector('[name="durationDays"]').value = '35';
  env.modalDialog.querySelector('[name="price"]').value = '3400000';
  env.modalDialog.querySelector('#coach-pkg-form').dispatchEvent({ type: 'submit' });
  await flush();

  const patch = requests.find((r) => r.method === 'PATCH');
  assert.deepEqual(patch.body, {
    name: 'Cơ bản Nâng cấp',
    description: 'Mô tả mới',
    sessionCount: 12,
    durationDays: 35,
    price: 3400000,
    status: 'ACTIVE',
  });
});

test('T10 Coach Entitlements tab supports ACTIVE/QUEUED/ENDED + frozenOnly filter and displays frozen days', async () => {
  const env = createDomEnvironment({ hash: '#/admin/coach-packages?tab=entitlements', token: 'tok' });
  setToken('tok');

  const requests = [];
  globalThis.fetch = async (url) => {
    const parsed = new URL(url, 'http://localhost');
    requests.push({ path: parsed.pathname, search: parsed.search });
    if (parsed.pathname === '/api/v1/admin/coach-entitlements') {
      return jsonResponse({
        data: [{
          id: 'ent-uuid-01',
          memberId: 'mem-uuid-01',
          memberName: 'Nguyễn Thảo Vy',
          coachId: 'coach-uuid-01',
          coachName: 'Trần Quốc Bảo',
          planCode: 'STANDARD',
          planName: 'Tiêu chuẩn 20 buổi',
          snapshotPrice: 5400000,
          totalSessions: 20,
          remainingSessions: 14,
          endsOn: '2026-12-20',
          frozenAt: '2026-11-17T03:15:00.000Z',
          frozenDaysTotal: 4,
          graceDaysAdded: 0,
          status: 'ACTIVE',
          closeReason: null,
        }],
        pagination: { page: 1, pageSize: 20, totalItems: 1, totalPages: 1 },
      });
    }
    throw new Error(`Unexpected ${parsed.pathname}`);
  };

  await renderCoachPackagesPage({
    root: env.root,
    params: new URLSearchParams({ tab: 'entitlements' }),
    shell: makeShell(env.root),
  });

  const tableHtml = env.root.querySelector('table').innerHTML;
  assert.equal(tableHtml.includes('Nguyễn Thảo Vy'), true);
  assert.equal(tableHtml.includes('Trần Quốc Bảo'), true);
  assert.equal(tableHtml.includes('14/20 buổi'), true);
  assert.equal(tableHtml.includes('5.400.000 ₫'), true);
  assert.equal(tableHtml.includes('Đang đóng băng'), true);
  assert.equal(tableHtml.includes('ent-uuid-01'), false);
  assert.equal(tableHtml.includes('mem-uuid-01'), false);

  const frozenChk = env.root.querySelector('#cp-frozen-only');
  frozenChk.checked = true;
  frozenChk.dispatchEvent({ type: 'change' });
  await flush();

  const last = requests[requests.length - 1];
  assert.equal(last.search.includes('frozenOnly=true'), true);
  assert.equal(env.location.hash.includes('frozenOnly=true'), true);
});
