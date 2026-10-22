import assert from 'node:assert/strict';
import test from 'node:test';

import { createApp } from '../src/app.js';

const database = { query: async () => ({ rows: [] }) };

test('createApp rejects a missing JWT secret at startup', () => {
  assert.throws(
    () => createApp({ database, jwtSecret: undefined }),
    /JWT_SECRET is required/,
  );
});

test('createApp rejects weak and placeholder JWT secrets at startup', () => {
  for (const jwtSecret of [
    'short-secret',
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'replace-with-a-random-secret-of-at-least-32-characters',
  ]) {
    assert.throws(
      () => createApp({ database, jwtSecret }),
      /JWT_SECRET must be a strong non-placeholder secret/,
    );
  }
});

test('createApp accepts a strong JWT secret', () => {
  assert.doesNotThrow(() =>
    createApp({
      database,
      jwtSecret: 'A7$secure-test-secret-with-32-plus-chars',
    }),
  );
});

test('production requires HTTPS CORS origins and only permits configured origins',
  async () => {
    const jwtSecret = 'A7$secure-test-secret-with-32-plus-chars';
    for (const corsAllowedOrigins of [undefined, '*', 'http://app.example.com',
      'https://app.example.com/path']) {
      assert.throws(() => createApp({ database, jwtSecret,
        nodeEnv: 'production', corsAllowedOrigins }), /CORS_ALLOWED_ORIGINS/);
    }
    const app = createApp({ database, jwtSecret, nodeEnv: 'production',
      corsAllowedOrigins: 'https://app.example.com,https://admin.example.com' });
    const server = app.listen(0);
    try {
      const base = `http://127.0.0.1:${server.address().port}`;
      for (const [origin, expectedHeader] of [
        ['https://app.example.com', 'https://app.example.com'],
        ['https://admin.example.com', 'https://admin.example.com'],
        ['https://untrusted.example.com', null],
      ]) {
        const response = await fetch(`${base}/api/v1/health`, {
          method: 'OPTIONS', headers: { origin,
            'access-control-request-method': 'GET' },
        });
        assert.equal(response.headers.get('access-control-allow-origin'),
          expectedHeader);
      }
    } finally { await new Promise((resolve) => server.close(resolve)); }
  });
