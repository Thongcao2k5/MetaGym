import assert from 'node:assert/strict';
import test from 'node:test';

import { createDomEnvironment, flush, jsonResponse } from './helpers/dom-harness.js';
import { setCurrentUser, setToken } from '../src/services/api.js';
import { renderShell } from '../src/components/layout.js';
import { createIdempotencyManager, renderPaymentsPage } from '../src/pages/payments.js';

function makeShell(root) {
  return (opts) => renderShell({ root, user: { fullName: 'Admin' }, ...opts });
}

test('T11 Idempotency-Key manager reuses same UUID on identical payload retry and rotates on selection change', () => {
  let seq = 0;
  const manager = createIdempotencyManager(() => `uuid-000${++seq}`);

  const k1 = manager.getKey('mem-1:plan-30');
  const k1Retry = manager.getKey('mem-1:plan-30');
  assert.equal(k1, 'uuid-0001');
  assert.equal(k1Retry, k1, 'Retry of identical (memberId, planId) must reuse exact same UUID');

  const k2 = manager.getKey('mem-1:plan-90');
  assert.notEqual(k2, k1, 'Changing planId must generate a brand-new UUID');
  assert.equal(k2, 'uuid-0002');

  const k3 = manager.getKey('mem-2:plan-90');
  assert.notEqual(k3, k2, 'Changing memberId must generate a brand-new UUID');

  manager.reset();
  const k4 = manager.getKey('mem-2:plan-90');
  assert.notEqual(k4, k3, 'Reset after success generates a fresh UUID for new purchase');
});

test('T11 Counter Gym payment supports >100 Member server-side search, reuses Idempotency-Key on retry, and changes key on plan change', async () => {
  const env = createDomEnvironment({ hash: '#/admin/payments', token: 'tok' });
  setToken('tok');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Admin' });

  const requests = [];
  let failFrontDeskOnce = true;

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    const body = options.body ? JSON.parse(options.body) : undefined;
    const idemHeader = options.headers?.['Idempotency-Key'] || null;
    requests.push({ path: parsed.pathname, method: options.method || 'GET', search: parsed.search, body, idemHeader });

    if (parsed.pathname === '/api/v1/admin/payments') {
      return jsonResponse({ data: [], pagination: { page: 1, pageSize: 20, totalItems: 0, totalPages: 1 } });
    }
    if (parsed.pathname === '/api/v1/admin/membership-plans') {
      return jsonResponse({
        data: [
          { id: 'plan-30', name: 'Gói Gym 30 ngày', price: 650000, durationDays: 30, status: 'ACTIVE' },
          { id: 'plan-90', name: 'Gói Gym 90 ngày', price: 1650000, durationDays: 90, status: 'ACTIVE' },
        ],
      });
    }
    if (parsed.pathname === '/api/v1/admin/users') {
      const q = parsed.searchParams.get('search') || '';
      if (q.toLowerCase().includes('đăng')) {
        return jsonResponse({
          data: [{
            id: 'mem-155',
            fullName: 'Trịnh Hải Đăng',
            email: 'dang155@metagym.vn',
            phone: '0904998312',
            status: 'ACTIVE',
            activeMembershipEndDate: '2026-12-30',
          }],
          pagination: { page: 1, pageSize: 20, totalItems: 1, totalPages: 1 },
        });
      }
      return jsonResponse({
        data: [{ id: 'mem-01', fullName: 'Nguyễn An', email: 'an@metagym.vn', status: 'ACTIVE' }],
        pagination: { page: 1, pageSize: 20, totalItems: 180, totalPages: 9 },
      });
    }
    if (parsed.pathname === '/api/v1/admin/front-desk-payments' && options.method === 'POST') {
      if (failFrontDeskOnce) {
        failFrontDeskOnce = false;
        return jsonResponse({ error: { code: 'SERVICE_UNAVAILABLE', message: 'Máy chủ tạm bận' } }, 503);
      }
      return jsonResponse({
        data: {
          payment: { id: 'pay-new', transactionCode: 'MG-20261121-0100', amount: 1650000, status: 'SUCCESS' },
          membership: { id: 'ms-new', status: 'SCHEDULED' },
        },
      }, 201);
    }
    throw new Error(`Unexpected ${options.method || 'GET'} ${parsed.pathname}`);
  };

  await renderPaymentsPage({ root: env.root, params: new URLSearchParams(), shell: makeShell(env.root) });

  assert.equal(env.root.innerHTML.includes('CHỈ áp dụng cho Gói Gym'), true);
  assert.equal(env.root.innerHTML.includes('180 hội viên'), true);

  // Server-side search for member #155 beyond initial 20/100 page
  const searchInput = env.root.querySelector('#fd-member-search');
  searchInput.value = 'Đăng';
  searchInput.dispatchEvent({ type: 'input' });
  await new Promise((r) => setTimeout(r, 320));
  await flush();

  const memberSearchReq = requests.find((r) => r.path === '/api/v1/admin/users' && r.search.includes('search='));
  assert.ok(memberSearchReq, 'Must issue server-side search GET /admin/users');
  assert.equal(memberSearchReq.search.includes('role=MEMBER'), true);
  assert.equal(memberSearchReq.search.includes('status=ACTIVE'), true);
  assert.equal(memberSearchReq.search.includes('pageSize=20'), true);

  // Pick member #155
  env.root.querySelector('[data-pick-member="mem-155"]').click();
  await flush();

  const keyForPlan30 = env.root.querySelector('#fd-idem-display').textContent;
  assert.ok(keyForPlan30.length >= 32, 'UUID Idempotency-Key should be generated');

  // Switch plan from plan-30 -> plan-90 => must rotate Idempotency-Key!
  const planSelect = env.root.querySelector('#fd-plan-select');
  planSelect.value = 'plan-90';
  planSelect.dispatchEvent({ type: 'change' });
  await flush();

  const keyForPlan90 = env.root.querySelector('#fd-idem-display').textContent;
  assert.notEqual(keyForPlan90, keyForPlan30, 'Switching planId MUST generate a new Idempotency-Key');

  // Open confirmation modal -> verify Member name, email, Plan name, VND amount
  env.root.querySelector('#fd-confirm-btn').click();
  await flush();
  assert.equal(env.modalDialog.innerHTML.includes('Trịnh Hải Đăng'), true);
  assert.equal(env.modalDialog.innerHTML.includes('dang155@metagym.vn'), true);
  assert.equal(env.modalDialog.innerHTML.includes('Gói Gym 90 ngày'), true);
  assert.equal(env.modalDialog.innerHTML.includes('1.650.000 ₫'), true);

  // First attempt fails 503 -> modal stays open; retry MUST reuse EXACT SAME Idempotency-Key!
  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();
  assert.equal(env.modalOverlay.hidden, false, 'Modal stays open on 503 for retry');

  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();
  assert.equal(env.modalOverlay.hidden, true, 'Modal closes after successful retry');

  const fdPosts = requests.filter((r) => r.path === '/api/v1/admin/front-desk-payments');
  assert.equal(fdPosts.length, 2);
  assert.equal(fdPosts[0].idemHeader, keyForPlan90);
  assert.equal(fdPosts[1].idemHeader, keyForPlan90, 'Retry of same payload MUST send exact same Idempotency-Key');
  assert.deepEqual(fdPosts[1].body, { memberId: 'mem-155', planId: 'plan-90' });
});

test('T11 Payment History displays human names (ZERO raw UUIDs), D6 disabled tooltip, Detail Drawer, and VOID_REVERSAL modal preserving reason on 409', async () => {
  const env = createDomEnvironment({ hash: '#/admin/payments', token: 'tok' });
  setToken('tok');

  const requests = [];
  let failVoidOnce = true;

  const paymentRows = [
    {
      id: 'pay-uuid-eligible-1',
      memberId: 'mem-uuid-secret-1',
      memberName: 'Ngô Phương Anh',
      memberEmail: 'anh@metagym.vn',
      planName: 'Gói Gym 90 ngày',
      durationDays: 90,
      amount: 1650000,
      method: 'FRONT_DESK',
      status: 'SUCCESS',
      transactionCode: 'MG-20261121-0001',
      confirmedAt: '2026-11-21T02:00:00.000Z',
      createdAt: '2026-11-21T02:00:00.000Z',
      adjustment: null,
      canVoidReversal: true,
      voidBlockedReason: null,
    },
    {
      id: 'pay-uuid-blocked-2',
      memberId: 'mem-uuid-secret-2',
      memberName: 'Lê Khánh Linh',
      memberEmail: 'linh@metagym.vn',
      planName: 'Gói Gym 30 ngày',
      durationDays: 30,
      amount: 650000,
      method: 'FRONT_DESK',
      status: 'SUCCESS',
      transactionCode: 'MG-20261118-0002',
      confirmedAt: '2026-11-18T02:00:00.000Z',
      createdAt: '2026-11-18T02:00:00.000Z',
      adjustment: null,
      canVoidReversal: false,
      voidBlockedReason: 'Đã qua ngày làm việc VN và đã phát sinh điểm danh sử dụng',
    },
    {
      id: 'pay-uuid-reversed-3',
      memberId: 'mem-uuid-secret-3',
      memberName: 'Vũ Đức Anh',
      memberEmail: 'ducanh@metagym.vn',
      planName: 'Gói Gym 30 ngày',
      durationDays: 30,
      amount: 650000,
      method: 'FRONT_DESK',
      status: 'SUCCESS',
      transactionCode: 'MG-20261120-0003',
      confirmedAt: '2026-11-20T02:00:00.000Z',
      createdAt: '2026-11-20T02:00:00.000Z',
      adjustment: {
        id: 'adj-uuid-3',
        adjustmentType: 'VOID_REVERSAL',
        reversedAmount: 650000,
        previousMembershipStatus: 'ACTIVE',
        newMembershipStatus: 'CANCELLED',
        previousEndDate: '2026-12-20',
        restoredEndDate: null,
        reason: 'Nhập nhầm gói',
        createdAt: '2026-11-20T02:30:00.000Z',
      },
      canVoidReversal: false,
      voidBlockedReason: 'Giao dịch đã được đảo',
    },
  ];

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    const body = options.body ? JSON.parse(options.body) : undefined;
    const idemHeader = options.headers?.['Idempotency-Key'] || null;
    requests.push({ path: parsed.pathname, method: options.method || 'GET', search: parsed.search, body, idemHeader });

    if (parsed.pathname === '/api/v1/admin/payments') {
      return jsonResponse({ data: paymentRows, pagination: { page: 1, pageSize: 20, totalItems: 3, totalPages: 1 } });
    }
    if (parsed.pathname === '/api/v1/admin/membership-plans') {
      return jsonResponse({ data: [{ id: 'plan-30', name: 'Gói Gym 30 ngày', price: 650000, durationDays: 30, status: 'ACTIVE' }] });
    }
    if (parsed.pathname === '/api/v1/admin/users') {
      return jsonResponse({ data: [], pagination: { page: 1, pageSize: 20, totalItems: 0, totalPages: 1 } });
    }
    if (parsed.pathname === '/api/v1/admin/payments/pay-uuid-reversed-3') {
      return jsonResponse({
        data: {
          ...paymentRows[2],
          membership: { id: 'ms-uuid-3', status: 'CANCELLED', startDate: '2026-11-20', endDate: '2026-12-20' },
        },
      });
    }
    if (parsed.pathname === '/api/v1/admin/payments/pay-uuid-eligible-1/void-reversal' && options.method === 'POST') {
      if (failVoidOnce) {
        failVoidOnce = false;
        return jsonResponse({ error: { code: 'PAYMENT_HAS_COACH_DEPENDENCY', message: 'Gói Gym đang có gói Coach phụ thuộc' } }, 409);
      }
      return jsonResponse({
        data: {
          adjustment: {
            id: 'adj-new-1',
            paymentId: 'pay-uuid-eligible-1',
            adjustmentType: 'VOID_REVERSAL',
            reversedAmount: 1650000,
            newMembershipStatus: 'CANCELLED',
            reason: body.reason,
          },
          payment: paymentRows[0],
        },
      }, 201);
    }
    throw new Error(`Unexpected ${options.method || 'GET'} ${parsed.pathname}`);
  };

  await renderPaymentsPage({ root: env.root, params: new URLSearchParams(), shell: makeShell(env.root) });

  const tableHtml = env.root.querySelector('table').innerHTML;
  assert.equal(tableHtml.includes('Ngô Phương Anh'), true);
  assert.equal(tableHtml.includes('Lê Khánh Linh'), true);
  assert.equal(tableHtml.includes('Đã đảo VOID_REVERSAL'), true);
  assert.equal(tableHtml.includes('mem-uuid-secret-1'), false, 'List table MUST NOT show raw member UUID');
  assert.equal(tableHtml.includes('mem-uuid-secret-2'), false, 'List table MUST NOT show raw member UUID');

  // Verify enabled vs disabled D6 buttons with voidBlockedReason tooltip
  const eligibleVoidBtn = env.root.querySelector('.void-pay[data-id="pay-uuid-eligible-1"]');
  const blockedVoidBtn = env.root.querySelector('.void-pay[data-id="pay-uuid-blocked-2"]');
  assert.equal(eligibleVoidBtn.disabled, false);
  assert.equal(blockedVoidBtn.disabled, true);
  assert.equal(blockedVoidBtn.getAttribute('title'), 'Đã qua ngày làm việc VN và đã phát sinh điểm danh sử dụng');

  // Open Payment Detail Drawer for reversed payment -> shows UUIDs + membership + adjustment
  env.root.querySelector('.detail-pay[data-id="pay-uuid-reversed-3"]').click();
  await flush();
  assert.equal(env.drawerOverlay.hidden, false);
  const drawerHtml = env.drawerPanel.innerHTML;
  assert.equal(drawerHtml.includes('pay-uuid-reversed-3'), true);
  assert.equal(drawerHtml.includes('ms-uuid-3'), true);
  assert.equal(drawerHtml.includes('adj-uuid-3'), true);
  assert.equal(drawerHtml.includes('Nhập nhầm gói'), true);

  // Open D6 VOID_REVERSAL modal -> 409 preserves input -> retry reuses same Idempotency-Key & succeeds
  eligibleVoidBtn.click();
  await flush();
  const reasonEl = env.modalDialog.querySelector('#meta-confirm-reason');
  reasonEl.value = 'Thu ngân chọn nhầm gói 90 ngày thay vì 30 ngày';
  reasonEl.dispatchEvent({ type: 'input' });

  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();
  assert.equal(env.modalOverlay.hidden, false, '409 keeps D6 modal open');
  assert.equal(reasonEl.value, 'Thu ngân chọn nhầm gói 90 ngày thay vì 30 ngày', 'Preserves reason on 409 error');
  assert.equal(env.modalDialog.innerHTML.includes('Gói Gym đang có gói Coach phụ thuộc'), true);

  // Retry succeeds with same Idempotency-Key
  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();
  assert.equal(env.modalOverlay.hidden, true);

  const voidPosts = requests.filter((r) => r.path === '/api/v1/admin/payments/pay-uuid-eligible-1/void-reversal');
  assert.equal(voidPosts.length, 2);
  assert.ok(voidPosts[0].idemHeader, 'Must send Idempotency-Key header on D6 void-reversal');
  assert.equal(voidPosts[1].idemHeader, voidPosts[0].idemHeader, 'Retry with identical reason reuses Idempotency-Key');
  assert.deepEqual(voidPosts[1].body, { reason: 'Thu ngân chọn nhầm gói 90 ngày thay vì 30 ngày' });

  // Filter adjusted=true updates hash URL and refetches
  const adjSelect = env.root.querySelector('#pay-adjusted');
  adjSelect.value = 'true';
  adjSelect.dispatchEvent({ type: 'change' });
  await flush();
  const lastHistoryGet = [...requests].reverse().find((r) => r.path === '/api/v1/admin/payments');
  assert.equal(lastHistoryGet.search.includes('adjusted=true'), true);
  assert.equal(env.location.hash.includes('adjusted=true'), true);
});
