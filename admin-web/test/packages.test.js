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

test('T10 Gym Plans renders 2-sided card thumbnails, 3 card highlights, and edits card media & highlights cleanly', async () => {
  const env = createDomEnvironment({ hash: '#/admin/plans', token: 'tok' });
  setToken('tok');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Admin' });

  const uploadedMediaId = '44444444-4444-4444-8444-444444444444';
  const requests = [];
  let plan = {
    id: 'plan-gold',
    name: 'Gói Pro 6 Tháng',
    description: 'Ưu đãi gói Vàng',
    price: 2600000,
    durationDays: 180,
    status: 'ACTIVE',
    cardTier: 'GOLD',
    frontMediaId: '11111111-1111-4111-8111-111111111111',
    backMediaId: '22222222-2222-4222-8222-222222222222',
    frontImageUrl: '/api/v1/media/public/11111111-1111-4111-8111-111111111111?v=1',
    frontThumbnailUrl: '/api/v1/media/public/11111111-1111-4111-8111-111111111111?size=120&v=1',
    backImageUrl: '/api/v1/media/public/22222222-2222-4222-8222-222222222222?v=2',
    backThumbnailUrl: '/api/v1/media/public/22222222-2222-4222-8222-222222222222?size=120&v=2',
    cardHighlights: [
      'Thẻ Vàng NFC · Khăn tập mỗi ngày',
      'Miễn phí đo InBody hàng tháng',
      'Giảm 5% phí Coach · Tặng 2 buổi PT 1:1',
    ],
    activeMembershipCount: 5,
    scheduledMembershipCount: 1,
  };

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    if (parsed.pathname === '/api/v1/admin/membership-plans' && (!options.method || options.method === 'GET')) {
      return jsonResponse({ data: [plan], pagination: { page: 1, pageSize: 10, totalItems: 1, totalPages: 1 } });
    }
    if (parsed.pathname === '/api/v1/media/images' && options.method === 'POST') {
      requests.push({
        path: parsed.pathname,
        method: 'POST',
        purpose: options.headers['x-image-purpose'],
      });
      return jsonResponse({
        data: {
          id: uploadedMediaId,
          publicUrl: `/api/v1/media/public/${uploadedMediaId}?v=${uploadedMediaId}`,
          thumbnailUrl: `/api/v1/media/public/${uploadedMediaId}?size=120&v=${uploadedMediaId}`,
        },
      }, 201);
    }
    if (parsed.pathname === '/api/v1/admin/membership-plans/plan-gold' && options.method === 'PATCH') {
      const body = JSON.parse(options.body);
      requests.push({ path: parsed.pathname, method: 'PATCH', body });
      plan = { ...plan, ...body };
      return jsonResponse({ data: plan });
    }
    throw new Error(`Unexpected ${options.method || 'GET'} ${parsed.pathname}`);
  };

  await renderPlansPage({ root: env.root, params: new URLSearchParams(), shell: makeShell(env.root) });

  assert.equal(env.root.innerHTML.includes('Hạng Vàng'), true);
  assert.equal(env.root.innerHTML.includes('Thẻ Vàng NFC · Khăn tập mỗi ngày'), true);
  assert.equal(env.root.innerHTML.includes('Miễn phí đo InBody hàng tháng'), true);
  assert.equal(env.root.innerHTML.includes('Giảm 5% phí Coach · Tặng 2 buổi PT 1:1'), true);
  assert.equal(env.root.querySelectorAll('.plan-card-thumb').length, 2);

  // Open 2-sided card modal
  env.root.querySelector('.view-plan-cards').click();
  await flush();
  assert.equal(env.modalOverlay.hidden, false);
  assert.equal(env.modalDialog.innerHTML.includes('Mặt trước (Dọc)'), true);
  assert.equal(env.modalDialog.innerHTML.includes('Mặt sau (Ngang)'), true);
  env.modalDialog.querySelector('[data-close-modal]').click();
  await flush();

  // Open edit modal, upload new front card image, remove back card image, and update highlight line 1
  env.root.querySelector('.edit-plan').click();
  await flush();
  assert.equal(env.modalOverlay.hidden, false);

  env.modalDialog.querySelector('[data-slot-upload="front"]').click();
  const fileInput = env.modalDialog.querySelector('#plan-card-file-input');
  Object.defineProperty(fileInput, 'files', {
    configurable: true,
    value: [{
      name: 'gold-front.webp',
      type: 'image/webp',
      size: 12000,
      arrayBuffer: async () => new Uint8Array([82, 73, 70, 70]).buffer,
    }],
  });
  fileInput.dispatchEvent({ type: 'change' });
  await flush();

  env.modalDialog.querySelector('[data-slot-remove="back"]').click();
  env.modalDialog.querySelector('#plan-hl-1').value = 'Thẻ Vàng NFC · Tập full dịch vụ';
  env.modalDialog.querySelector('#plan-form').dispatchEvent({ type: 'submit' });
  await flush();

  const uploadReq = requests.find((r) => r.path === '/api/v1/media/images');
  assert.equal(uploadReq?.purpose, 'PACKAGE');
  const patchReq = requests.find((r) => r.method === 'PATCH');
  assert.equal(patchReq.body.cardTier, 'GOLD');
  assert.equal(patchReq.body.frontMediaId, uploadedMediaId);
  assert.equal(patchReq.body.backMediaId, null);
  assert.deepEqual(patchReq.body.cardHighlights, [
    'Thẻ Vàng NFC · Tập full dịch vụ',
    'Miễn phí đo InBody hàng tháng',
    'Giảm 5% phí Coach · Tặng 2 buổi PT 1:1',
  ]);
});

test('T10 Gym Plans sale window renders phase badges, validates end >= start, and converts GMT+7 to ISO UTC', async () => {
  const env = createDomEnvironment({ hash: '#/admin/plans', token: 'tok' });
  setToken('tok');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Admin' });

  const requests = [];
  let plan = {
    id: 'plan-tet',
    name: 'Gói Ưu Đãi Đợt Mở Bán',
    description: 'Mở bán theo đợt',
    price: 990000,
    durationDays: 60,
    status: 'ACTIVE',
    salesStartAt: '2026-12-01T01:00:00.000Z',
    salesEndAt: '2026-12-15T16:59:00.000Z',
    salePhase: 'UPCOMING',
    isOnSale: false,
    cardTier: 'SILVER',
    cardHighlights: ['Mở bán giới hạn', 'Ưu đãi hội viên sớm', 'Giữ nguyên quyền lợi'],
    activeMembershipCount: 0,
    scheduledMembershipCount: 0,
  };

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    if (parsed.pathname === '/api/v1/admin/membership-plans' && (!options.method || options.method === 'GET')) {
      return jsonResponse({ data: [plan], pagination: { page: 1, pageSize: 10, totalItems: 1, totalPages: 1 } });
    }
    if (parsed.pathname === '/api/v1/admin/membership-plans/plan-tet' && options.method === 'PATCH') {
      const body = JSON.parse(options.body);
      requests.push(body);
      plan = { ...plan, ...body, salePhase: 'ON_SALE', isOnSale: true };
      return jsonResponse({ data: plan });
    }
    throw new Error(`Unexpected ${options.method || 'GET'} ${parsed.pathname}`);
  };

  await renderPlansPage({ root: env.root, params: new URLSearchParams(), shell: makeShell(env.root) });

  assert.equal(env.root.innerHTML.includes('Sắp mở bán'), true);
  assert.equal(env.root.innerHTML.includes('01/12/2026'), true);

  env.root.querySelector('.edit-plan').click();
  await flush();
  assert.equal(env.modalDialog.querySelector('[name="salesStartAt"]').value, '2026-12-01T08:00');
  assert.equal(env.modalDialog.querySelector('[name="salesEndAt"]').value, '2026-12-15T23:59');

  // Invalid range (end < start) blocked inline
  env.modalDialog.querySelector('[name="salesStartAt"]').value = '2026-12-20T09:00';
  env.modalDialog.querySelector('[name="salesEndAt"]').value = '2026-12-10T18:00';
  env.modalDialog.querySelector('#plan-form').dispatchEvent({ type: 'submit' });
  await flush();
  assert.equal(requests.length, 0);
  assert.equal(env.modalDialog.innerHTML.includes('Thời điểm kết thúc mở bán phải sau hoặc bằng thời điểm bắt đầu'), true);

  // Fix valid range -> submits UTC ISO converted from GMT+7
  env.modalDialog.querySelector('[name="salesStartAt"]').value = '2026-11-28T08:00';
  env.modalDialog.querySelector('[name="salesEndAt"]').value = '2026-12-10T23:59';
  env.modalDialog.querySelector('#plan-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(requests.length, 1);
  assert.equal(requests[0].salesStartAt, '2026-11-28T01:00:00.000Z');
  assert.equal(requests[0].salesEndAt, '2026-12-10T16:59:00.000Z');
});
