import assert from 'node:assert/strict';
import test from 'node:test';

import { createApp } from '../src/app.js';

const JWT_SECRET = 'test-only-secret-with-at-least-32-characters';

async function requestHealth(app) {
  const server = app.listen(0);

  try {
    const address = server.address();
    const response = await fetch(`http://127.0.0.1:${address.port}/api/v1/health`);

    return {
      body: await response.json(),
      status: response.status,
    };
  } finally {
    await new Promise((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  }
}

test('GET /api/v1/health reports that the API and database are available', async () => {
  const database = {
    query: async () => ({ rows: [{ connected: true }] }),
  };
  const app = createApp({ database, jwtSecret: JWT_SECRET });

  const response = await requestHealth(app);

  assert.equal(response.status, 200);
  assert.deepEqual(response.body, {
    data: {
      api: 'AVAILABLE',
      database: 'AVAILABLE',
    },
  });
});

test('GET /api/v1/health returns a safe error when the database is unavailable', async () => {
  const database = {
    query: async () => {
      throw new Error('password authentication failed for secret-user');
    },
  };
  const app = createApp({ database, jwtSecret: JWT_SECRET });

  const response = await requestHealth(app);

  assert.equal(response.status, 503);
  assert.deepEqual(response.body, {
    error: {
      code: 'DATABASE_UNAVAILABLE',
      message: 'Cơ sở dữ liệu tạm thời không khả dụng',
    },
  });
});
