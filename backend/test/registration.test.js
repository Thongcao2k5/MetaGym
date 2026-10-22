import assert from 'node:assert/strict';
import test from 'node:test';

import bcrypt from 'bcryptjs';

import { createApp } from '../src/app.js';

const JWT_SECRET = 'test-only-secret-with-at-least-32-characters';

async function postRegistration(app, body) {
  const server = app.listen(0);

  try {
    const address = server.address();
    const response = await fetch(
      `http://127.0.0.1:${address.port}/api/v1/auth/registrations`,
      {
        body: JSON.stringify(body),
        headers: { 'content-type': 'application/json' },
        method: 'POST',
      },
    );

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

test('POST /api/v1/auth/registrations creates an active Member with normalized email', async () => {
  let capturedQuery;
  const createdAt = new Date('2026-10-21T08:00:00.000Z');
  const database = {
    query: async (text, values) => {
      capturedQuery = { text, values };
      return {
        rows: [
          {
            created_at: createdAt,
            email: values[1],
            full_name: values[3],
            id: values[0],
            role: 'MEMBER',
            status: 'ACTIVE',
          },
        ],
      };
    },
  };
  const app = createApp({ database, jwtSecret: JWT_SECRET });

  const response = await postRegistration(app, {
    email: '  MEMBER@Example.COM  ',
    fullName: '  Nguyen Van A  ',
    password: 'StrongPass1',
  });

  assert.equal(response.status, 201);
  assert.deepEqual(response.body, {
    data: {
      createdAt: createdAt.toISOString(),
      email: 'member@example.com',
      fullName: 'Nguyen Van A',
      id: capturedQuery.values[0],
      role: 'MEMBER',
      status: 'ACTIVE',
    },
  });
  assert.match(capturedQuery.values[0], /^[0-9a-f-]{36}$/i);
  assert.equal(capturedQuery.values[1], 'member@example.com');
  assert.equal(capturedQuery.values[3], 'Nguyen Van A');
  assert.match(capturedQuery.text, /INSERT INTO users/i);
  assert.match(capturedQuery.text, /INSERT INTO member_profiles/i);
  assert.equal(await bcrypt.compare('StrongPass1', capturedQuery.values[2]), true);
  assert.equal(JSON.stringify(response.body).includes('password'), false);
});

test('POST /api/v1/auth/registrations rejects invalid input before querying the database', async () => {
  let queryCount = 0;
  const database = {
    query: async () => {
      queryCount += 1;
      return { rows: [] };
    },
  };
  const app = createApp({ database, jwtSecret: JWT_SECRET });

  const response = await postRegistration(app, {
    email: 'not-an-email',
    fullName: '',
    password: 'weak',
  });

  assert.equal(response.status, 422);
  assert.equal(response.body.error.code, 'VALIDATION_ERROR');
  assert.equal(response.body.error.message, 'Dữ liệu đăng ký không hợp lệ');
  assert.ok(response.body.error.details.fields.email);
  assert.ok(response.body.error.details.fields.fullName);
  assert.ok(response.body.error.details.fields.password);
  assert.equal(queryCount, 0);
});

test('POST /api/v1/auth/registrations rejects a client-supplied role', async () => {
  let queryCount = 0;
  const database = {
    query: async () => {
      queryCount += 1;
      return { rows: [] };
    },
  };
  const app = createApp({ database, jwtSecret: JWT_SECRET });

  const response = await postRegistration(app, {
    email: 'member@example.com',
    fullName: 'Nguyen Van A',
    password: 'StrongPass1',
    role: 'ADMIN',
  });

  assert.equal(response.status, 422);
  assert.equal(response.body.error.code, 'VALIDATION_ERROR');
  assert.ok(response.body.error.details.fields.role);
  assert.equal(queryCount, 0);
});

test('POST /api/v1/auth/registrations returns 409 when the normalized email already exists', async () => {
  const database = {
    query: async () => {
      const error = new Error('duplicate key value violates unique constraint');
      error.code = '23505';
      error.constraint = 'users_email_key';
      throw error;
    },
  };
  const app = createApp({ database, jwtSecret: JWT_SECRET });

  const response = await postRegistration(app, {
    email: 'member@example.com',
    fullName: 'Nguyen Van A',
    password: 'StrongPass1',
  });

  assert.equal(response.status, 409);
  assert.deepEqual(response.body, {
    error: {
      code: 'EMAIL_ALREADY_EXISTS',
      details: {},
      message: 'Email đã được sử dụng',
    },
  });
});

test('POST /api/v1/auth/registrations does not expose unexpected database errors', async () => {
  const database = {
    query: async () => {
      throw new Error('password authentication failed for secret-user');
    },
  };
  const app = createApp({ database, jwtSecret: JWT_SECRET });

  const response = await postRegistration(app, {
    email: 'member@example.com',
    fullName: 'Nguyen Van A',
    password: 'StrongPass1',
  });

  assert.equal(response.status, 500);
  assert.deepEqual(response.body, {
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      details: {},
      message: 'Đã xảy ra lỗi, vui lòng thử lại sau',
    },
  });
  assert.equal(JSON.stringify(response.body).includes('secret-user'), false);
});
