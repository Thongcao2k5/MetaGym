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
