import assert from 'node:assert/strict';
import test from 'node:test';

import { createDomEnvironment, flush, jsonResponse } from './helpers/dom-harness.js';
import { setCurrentUser, setToken } from '../src/services/api.js';
import { renderShell } from '../src/components/layout.js';
import { renderAccountsPage } from '../src/pages/accounts.js';
import { renderDashboardPage } from '../src/pages/dashboard.js';

async function setupAccounts({ role = 'MEMBER', initialStatus = 'ACTIVE' } = {}) {
  const env = createDomEnvironment({ hash: `#/admin/${role === 'COACH' ? 'coaches' : 'members'}`, token: 'test-admin-token' });
  setToken('test-admin-token');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Admin' });

  let status = initialStatus;
  const requests = [];

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    const path = parsed.pathname;
    const body = options.body ? JSON.parse(options.body) : undefined;
    requests.push({ path, method: options.method || 'GET', body, search: parsed.search });

    if (path === '/api/v1/admin/users' && (!options.method || options.method === 'GET')) {
      return jsonResponse({
        data: [{
          id: role === 'COACH' ? 'coach-1' : 'member-test-id',
          fullName: role === 'COACH' ? 'Coach Một' : 'Member Test',
          email: role === 'COACH' ? 'coach@test.local' : 'member@test.local',
          phone: '0900000000',
          role,
          status,
          memberLimit: role === 'COACH' ? 8 : null,
          usedSlots: role === 'COACH' ? 3 : 0,
        }],
        pagination: { page: 1, pageSize: 20, totalItems: 1, totalPages: 1 },
      });
    }
    if (path === '/api/v1/admin/users/member-test-id/status' && options.method === 'PATCH') {
      if (body.status === 'DISABLED' && !body.reason?.trim()) {
        return jsonResponse({ error: { message: 'Trạng thái hoặc lý do không hợp lệ' } }, 422);
      }
      status = body.status;
      return jsonResponse({ data: { user: { id: 'member-test-id', status } } });
    }
    if (path === '/api/v1/admin/users/coach-1' && options.method === 'PATCH') {
      return jsonResponse({ data: { id: 'coach-1', ...body } });
    }
    throw new Error(`Unexpected request: ${options.method || 'GET'} ${path}`);
  };

  await renderAccountsPage({
    root: env.root,
    role,
    params: new URLSearchParams(),
    shell: (opts) => renderShell({ root: env.root, user: { fullName: 'Admin' }, ...opts }),
  });

  return { env, requests, getStatus: () => status };
}

test('Admin khóa tài khoản gửi lý do đã chuẩn hóa và cập nhật trạng thái qua custom modal', async () => {
  const { env, requests, getStatus } = await setupAccounts({ role: 'MEMBER', initialStatus: 'ACTIVE' });
  env.root.querySelector('.toggle').click();
  await flush();

  const textarea = env.modalDialog.querySelector('#meta-confirm-reason');
  const submit = env.modalDialog.querySelector('#meta-confirm-submit');
  assert.equal(submit.disabled, true);

  textarea.value = '  Vi phạm quy định  ';
  textarea.dispatchEvent({ type: 'input' });
  assert.equal(submit.disabled, false);

  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();

  const patches = requests.filter((r) => r.method === 'PATCH');
  assert.deepEqual(patches.map(({ path, method, body }) => ({ path, method, body })), [{
    path: '/api/v1/admin/users/member-test-id/status',
    method: 'PATCH',
    body: { status: 'DISABLED', reason: 'Vi phạm quy định' },
  }]);
  assert.equal(getStatus(), 'DISABLED');
});

test('Admin nhập lý do trống thì không gửi yêu cầu khóa', async () => {
  const { env, requests, getStatus } = await setupAccounts({ role: 'MEMBER', initialStatus: 'ACTIVE' });
  env.root.querySelector('.toggle').click();
  await flush();

  const textarea = env.modalDialog.querySelector('#meta-confirm-reason');
  textarea.value = '   ';
  textarea.dispatchEvent({ type: 'input' });
  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(requests.some((r) => r.method === 'PATCH'), false);
  assert.equal(getStatus(), 'ACTIVE');
});

test('Admin đóng modal khóa thì không gửi yêu cầu khóa', async () => {
  const { env, requests } = await setupAccounts({ role: 'MEMBER', initialStatus: 'ACTIVE' });
  env.root.querySelector('.toggle').click();
  await flush();

  env.modalDialog.querySelector('[data-close-modal]').click();
  await flush();
  assert.equal(requests.some((r) => r.method === 'PATCH'), false);
});

test('Admin nhập lý do quá 500 ký tự thì không gửi yêu cầu khóa', async () => {
  const { env, requests } = await setupAccounts({ role: 'MEMBER', initialStatus: 'ACTIVE' });
  env.root.querySelector('.toggle').click();
  await flush();

  const textarea = env.modalDialog.querySelector('#meta-confirm-reason');
  textarea.value = 'x'.repeat(501);
  textarea.dispatchEvent({ type: 'input' });
  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(requests.some((r) => r.method === 'PATCH'), false);
});

test('Admin mở tài khoản không yêu cầu hoặc gửi lý do khóa', async () => {
  const { env, requests, getStatus } = await setupAccounts({ role: 'MEMBER', initialStatus: 'DISABLED' });
  env.root.querySelector('.toggle').click();
  await flush();

  assert.equal(env.modalDialog.querySelector('#meta-confirm-reason'), null, 'Unlock modal must not require lock reason');
  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();

  const patches = requests.filter((r) => r.method === 'PATCH');
  assert.deepEqual(patches.map(({ path, method, body }) => ({ path, method, body })), [{
    path: '/api/v1/admin/users/member-test-id/status',
    method: 'PATCH',
    body: { status: 'ACTIVE' },
  }]);
  assert.equal(getStatus(), 'ACTIVE');
});

test('Admin dashboard không hiển thị thẻ Yêu cầu chọn Coach', async () => {
  const env = createDomEnvironment({ hash: '#/admin/dashboard', token: 'test-admin-token' });
  setToken('test-admin-token');

  globalThis.fetch = async () => jsonResponse({
    data: {
      from: '2026-11-01',
      to: '2026-11-17',
      members: { active: 10, disabled: 0 },
      coaches: { active: 3, disabled: 0 },
      activeMemberships: 8,
      pendingCoachRequests: 4,
      pendingTerminationRequests: 1,
      revenue: { amount: '5000000', byDay: [] },
    },
  });

  await renderDashboardPage({
    root: env.root,
    params: new URLSearchParams(),
    shell: (opts) => renderShell({ root: env.root, user: { fullName: 'Admin' }, ...opts }),
    ChartCtor: class { destroy() {} },
  });

  assert.equal(env.root.innerHTML.includes('Yêu cầu chọn Coach'), false);
  assert.equal(env.root.innerHTML.includes('Yêu cầu kết thúc'), true);
});

test('Admin danh sách Coach không cho sửa memberLimit và luôn hiển thị trần cứng 8', async () => {
  const { env, requests } = await setupAccounts({ role: 'COACH', initialStatus: 'ACTIVE' });
  assert.equal(env.root.innerHTML.includes('<th>Giới hạn</th>'), false);
  assert.equal(env.root.innerHTML.includes('3 / 8 suất'), true);

  env.root.querySelector('.edit').click();
  await flush();
  assert.equal(env.modalDialog.innerHTML.includes('name="memberLimit"'), false);

  env.modalDialog.querySelector('[name="fullName"]').value = 'Coach Mới';
  env.modalDialog.querySelector('[name="phone"]').value = '0901234567';
  env.modalDialog.querySelector('#account-form').dispatchEvent({ type: 'submit' });
  await flush();

  const patch = requests.find((r) => r.method === 'PATCH');
  assert.deepEqual(patch.body, { fullName: 'Coach Mới', phone: '0901234567' });
});
