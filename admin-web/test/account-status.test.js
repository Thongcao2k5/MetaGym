import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../src/main.js', import.meta.url), 'utf8')
  .replace(/^import .*;\r?\n/gm, '')
  .replace('import.meta.env.VITE_API_BASE_URL', 'undefined');

async function openAccounts({ initialStatus, promptedReason }) {
  let status = initialStatus;
  const requests = [];
  const toggle = { dataset: { id: 'member-test-id', status }, onclick: null };
  const nodes = {
    '#app': { innerHTML: '' },
    '#logout': {},
    '#prev': {},
    '#next': {},
    '#notice': { innerHTML: '' },
  };
  let promptCalls = 0;
  const context = {
    document: {
      querySelector: (selector) => nodes[selector] ?? null,
      querySelectorAll: (selector) => selector === '.toggle' ? [toggle] : [],
    },
    window: { addEventListener() {} },
    location: { hash: '#/admin/members' },
    sessionStorage: {
      getItem: () => 'test-admin-token',
      removeItem() {},
    },
    confirm: () => true,
    prompt: () => { promptCalls += 1; return promptedReason; },
    fetch: async (url, options = {}) => {
      const path = new URL(url, 'http://localhost').pathname;
      const body = options.body && JSON.parse(options.body);
      requests.push({ path, method: options.method, body });
      if (path === '/api/v1/users/me') {
        return { ok: true, json: async () => ({ data: { role: 'ADMIN', fullName: 'Admin' } }) };
      }
      if (path === '/api/v1/admin/users' && options.method === 'GET') {
        return { ok: true, json: async () => ({ data: [{
          id: 'member-test-id', fullName: 'Member Test', email: 'member@test.local', status,
        }], pagination: { totalItems: 1, totalPages: 1 } }) };
      }
      if (path === '/api/v1/admin/users/member-test-id/status') {
        if (body.status === 'DISABLED' && !body.reason?.trim()) {
          return { ok: false, status: 422, json: async () => ({
            error: { message: 'Trạng thái hoặc lý do không hợp lệ' },
          }) };
        }
        status = body.status;
        return { ok: true, json: async () => ({ data: { status } }) };
      }
      throw new Error(`Unexpected request: ${options.method} ${path}`);
    },
    Chart: class {},
    console,
  };
  vm.runInNewContext(source, context, { filename: 'admin-web/src/main.js' });
  for (let attempt = 0; attempt < 20 && !toggle.onclick; attempt += 1) {
    await new Promise((resolve) => setImmediate(resolve));
  }
  assert.equal(typeof toggle.onclick, 'function', 'accounts page should bind the toggle');
  return { toggle, requests, getStatus: () => status, getPromptCalls: () => promptCalls };
}

test('Admin khóa tài khoản gửi lý do đã chuẩn hóa và cập nhật trạng thái', async () => {
  const page = await openAccounts({ initialStatus: 'ACTIVE', promptedReason: '  Vi phạm quy định  ' });
  await page.toggle.onclick();
  const patches = page.requests.filter((request) => request.method === 'PATCH');
  assert.deepEqual(patches, [{
    path: '/api/v1/admin/users/member-test-id/status',
    method: 'PATCH',
    body: { status: 'DISABLED', reason: 'Vi phạm quy định' },
  }]);
  assert.equal(page.getStatus(), 'DISABLED');
});

test('Admin hủy nhập lý do thì không gửi yêu cầu khóa', async () => {
  const page = await openAccounts({ initialStatus: 'ACTIVE', promptedReason: '   ' });
  await page.toggle.onclick();
  assert.equal(page.requests.some((request) => request.method === 'PATCH'), false);
  assert.equal(page.getStatus(), 'ACTIVE');
});

test('Admin đóng hộp nhập lý do thì không gửi yêu cầu khóa', async () => {
  const page = await openAccounts({ initialStatus: 'ACTIVE', promptedReason: null });
  await page.toggle.onclick();
  assert.equal(page.requests.some((request) => request.method === 'PATCH'), false);
});

test('Admin nhập lý do quá 500 ký tự thì không gửi yêu cầu khóa', async () => {
  const page = await openAccounts({ initialStatus: 'ACTIVE', promptedReason: 'x'.repeat(501) });
  await page.toggle.onclick();
  assert.equal(page.requests.some((request) => request.method === 'PATCH'), false);
});

test('Admin mở tài khoản không bị hỏi hoặc gửi lý do khóa', async () => {
  const page = await openAccounts({ initialStatus: 'DISABLED', promptedReason: 'ignored' });
  await page.toggle.onclick();
  const patches = page.requests.filter((request) => request.method === 'PATCH');
  assert.deepEqual(patches, [{
    path: '/api/v1/admin/users/member-test-id/status',
    method: 'PATCH',
    body: { status: 'ACTIVE' },
  }]);
  assert.equal(page.getPromptCalls(), 0);
  assert.equal(page.getStatus(), 'ACTIVE');
});

test('Admin dashboard không hiển thị thẻ Yêu cầu chọn Coach', async () => {
  const nodes = {
    '#app': { innerHTML: '' },
    '#logout': {},
    '#notice': { innerHTML: '' },
    '#revenue-chart': {},
  };
  const context = {
    document: {
      querySelector: (selector) => nodes[selector] ?? null,
      querySelectorAll: () => [],
    },
    window: { addEventListener() {} },
    location: { hash: '#/admin/dashboard' },
    sessionStorage: { getItem: () => 'test-admin-token', removeItem() {} },
    fetch: async (url) => {
      const path = new URL(url, 'http://localhost').pathname;
      if (path === '/api/v1/users/me') {
        return { ok: true, json: async () => ({ data: { role: 'ADMIN', fullName: 'Admin' } }) };
      }
      if (path === '/api/v1/admin/dashboard') {
        return {
          ok: true,
          json: async () => ({
            data: {
              from: '2026-11-01',
              to: '2026-11-17',
              members: { active: 10 },
              coaches: { active: 3 },
              activeMemberships: 8,
              pendingCoachRequests: 4,
              pendingTerminationRequests: 1,
              revenue: { amount: '5000000', byDay: [] },
            },
          }),
        };
      }
      throw new Error(`Unexpected request: ${path}`);
    },
    Chart: class {},
    console,
  };
  vm.runInNewContext(source, context, { filename: 'admin-web/src/main.js' });
  for (let attempt = 0; attempt < 20 && !nodes['#app'].innerHTML.includes('Doanh thu'); attempt += 1) {
    await new Promise((resolve) => setImmediate(resolve));
  }
  assert.equal(nodes['#app'].innerHTML.includes('Yêu cầu chọn Coach'), false);
  assert.equal(nodes['#app'].innerHTML.includes('Yêu cầu kết thúc'), true);
});

test('Admin danh sách Coach không hiển thị cột Giới hạn và không cho sửa memberLimit', async () => {
  const editBtn = { dataset: { id: 'coach-1' }, onclick: null };
  const editorNode = { innerHTML: '' };
  const accountForm = { onsubmit: null };
  const nodes = {
    '#app': { innerHTML: '' },
    '#logout': {},
    '#prev': {},
    '#next': {},
    '#notice': { innerHTML: '' },
    '#editor': editorNode,
    '#account-form': accountForm,
  };
  const requests = [];
  const context = {
    FormData: class {
      get(key) {
        return { fullName: 'Coach Mới', phone: '0901234567' }[key] ?? null;
      }
    },
    document: {
      querySelector: (selector) => nodes[selector] ?? null,
      querySelectorAll: (selector) => selector === '.edit' ? [editBtn] : [],
    },
    window: { addEventListener() {} },
    location: { hash: '#/admin/coaches' },
    sessionStorage: { getItem: () => 'test-admin-token', removeItem() {} },
    fetch: async (url, options = {}) => {
      const path = new URL(url, 'http://localhost').pathname;
      const body = options.body && JSON.parse(options.body);
      requests.push({ path, method: options.method ?? 'GET', body });
      if (path === '/api/v1/users/me') {
        return { ok: true, json: async () => ({ data: { role: 'ADMIN', fullName: 'Admin' } }) };
      }
      if (path === '/api/v1/admin/users' && (!options.method || options.method === 'GET')) {
        return {
          ok: true,
          json: async () => ({
            data: [{
              id: 'coach-1',
              fullName: 'Coach Một',
              email: 'coach@test.local',
              phone: '0900000000',
              status: 'ACTIVE',
              memberLimit: 8,
            }],
            pagination: { totalItems: 1, totalPages: 1 },
          }),
        };
      }
      if (path === '/api/v1/admin/users/coach-1' && options.method === 'PATCH') {
        return { ok: true, json: async () => ({ data: { id: 'coach-1' } }) };
      }
      throw new Error(`Unexpected request: ${options.method} ${path}`);
    },
    Chart: class {},
    console,
  };
  vm.runInNewContext(source, context, { filename: 'admin-web/src/main.js' });
  for (let attempt = 0; attempt < 20 && !editBtn.onclick; attempt += 1) {
    await new Promise((resolve) => setImmediate(resolve));
  }
  assert.equal(nodes['#app'].innerHTML.includes('<th>Giới hạn</th>'), false);
  editBtn.onclick();
  assert.equal(editorNode.innerHTML.includes('name="memberLimit"'), false);
  await accountForm.onsubmit({ preventDefault() {}, currentTarget: {} });
  const patch = requests.find((r) => r.method === 'PATCH');
  assert.deepEqual(patch.body, { fullName: 'Coach Mới', phone: '0901234567' });
});
