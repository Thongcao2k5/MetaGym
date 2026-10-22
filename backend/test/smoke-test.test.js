import assert from 'node:assert/strict';
import test from 'node:test';

import {
  loadSmokeConfig,
  runSmokeTest,
} from '../scripts/smoke-test-lib.js';

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

const accounts = {
  ADMIN: { email: 'admin@metagym.local', password: 'admin-password' },
  COACH: { email: 'coach@metagym.local', password: 'coach-password' },
  MEMBER: { email: 'member@metagym.local', password: 'member-password' },
};

test('runSmokeTest checks health, three logins, and one protected route per role', async () => {
  const requests = [];
  const rolesByEmail = new Map(Object.entries(accounts)
    .map(([role, account]) => [account.email, role]));
  const expectedTokens = new Map();

  const fetchImpl = async (url, options = {}) => {
    const parsedUrl = new URL(url);
    const method = options.method ?? 'GET';
    requests.push({ path: parsedUrl.pathname, method, authorization: options.headers?.authorization });

    if (parsedUrl.pathname === '/api/v1/health') {
      return jsonResponse({ data: { api: 'AVAILABLE', database: 'AVAILABLE' } });
    }

    if (parsedUrl.pathname === '/api/v1/auth/sessions') {
      const input = JSON.parse(options.body);
      const role = rolesByEmail.get(input.email);
      const accessToken = `${role.toLowerCase()}-token`;
      expectedTokens.set(role, accessToken);
      return jsonResponse({ data: { accessToken, user: { role } } });
    }

    const roleByPath = new Map([
      ['/api/v1/admin/dashboard', 'ADMIN'],
      ['/api/v1/coach/members', 'COACH'],
      ['/api/v1/memberships/me', 'MEMBER'],
    ]);
    const role = roleByPath.get(parsedUrl.pathname);
    assert.equal(options.headers.authorization, `Bearer ${expectedTokens.get(role)}`);
    return jsonResponse({ data: role === 'ADMIN' ? {} : [] });
  };

  const steps = await runSmokeTest({
    baseUrl: 'https://api.example.test/api/v1/',
    accounts,
    fetchImpl,
  });

  assert.deepEqual(steps, [
    'health',
    'login:ADMIN', 'business:ADMIN',
    'login:COACH', 'business:COACH',
    'login:MEMBER', 'business:MEMBER',
  ]);
  assert.equal(requests.length, 7);
});

test('runSmokeTest rejects a non-success response with the failing step', async () => {
  await assert.rejects(
    runSmokeTest({
      baseUrl: 'https://api.example.test/api/v1',
      accounts,
      fetchImpl: async () => jsonResponse({
        error: { code: 'DATABASE_UNAVAILABLE', message: 'database unavailable' },
      }, 503),
    }),
    /health failed with HTTP 503.*DATABASE_UNAVAILABLE/,
  );
});

test('runSmokeTest rejects a successful health response when a dependency is unavailable', async () => {
  await assert.rejects(
    runSmokeTest({
      baseUrl: 'https://api.example.test/api/v1',
      accounts,
      fetchImpl: async () => jsonResponse({
        data: { api: 'AVAILABLE', database: 'UNAVAILABLE' },
      }),
    }),
    /health returned an unavailable API or database/,
  );
});

test('loadSmokeConfig requires the API URL and all three demo credentials', () => {
  assert.throws(() => loadSmokeConfig({}), /SMOKE_API_BASE_URL/);
  assert.throws(() => loadSmokeConfig({
    SMOKE_API_BASE_URL: 'http://localhost:3000/api/v1',
  }), /SMOKE_ADMIN_EMAIL/);

  const config = loadSmokeConfig({
    SMOKE_API_BASE_URL: 'http://localhost:3000/api/v1/',
    SMOKE_ADMIN_EMAIL: 'admin@example.test',
    SMOKE_ADMIN_PASSWORD: 'admin-password',
    SMOKE_COACH_EMAIL: 'coach@example.test',
    SMOKE_COACH_PASSWORD: 'coach-password',
    SMOKE_MEMBER_EMAIL: 'member@example.test',
    SMOKE_MEMBER_PASSWORD: 'member-password',
  });

  assert.equal(config.baseUrl, 'http://localhost:3000/api/v1');
  assert.equal(config.accounts.COACH.email, 'coach@example.test');
});
