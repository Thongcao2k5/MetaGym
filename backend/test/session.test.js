import assert from 'node:assert/strict';
import test from 'node:test';

import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

import { createApp } from '../src/app.js';

const JWT_SECRET = 'test-only-secret-with-at-least-32-characters';
const allowingLoginRateLimiter = {
  run: async (_context, handler) =>
    handler({
      blocked: false,
      registerFailure: async () => false,
      resetAccount: async () => {},
    }),
};

function createSessionApp({ database, loginRateLimiter = allowingLoginRateLimiter }) {
  return createApp({ database, jwtSecret: JWT_SECRET, loginRateLimiter });
}

async function postSession(app, body) {
  const server = app.listen(0);

  try {
    const address = server.address();
    const response = await fetch(
      `http://127.0.0.1:${address.port}/api/v1/auth/sessions`,
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

test('POST /api/v1/auth/sessions authenticates an active user and returns a scoped JWT', async () => {
  const passwordHash = await bcrypt.hash('CorrectPass1', 4);
  const queries = [];
  const database = {
    query: async (text, values) => {
      queries.push({ text, values });

      if (/^\s*SELECT/i.test(text)) {
        return {
          rows: [
            {
              email: 'member@example.com',
              full_name: 'Nguyen Van A',
              id: '10000000-0000-4000-8000-000000000001',
              password_hash: passwordHash,
              role: 'MEMBER',
              session_version: 3,
              status: 'ACTIVE',
            },
          ],
        };
      }

      return { rows: [{ id: values[0] }] };
    },
  };
  const app = createSessionApp({ database });

  const response = await postSession(app, {
    email: '  MEMBER@Example.COM ',
    password: 'CorrectPass1',
  });

  assert.equal(response.status, 200);
  assert.equal(response.body.data.tokenType, 'Bearer');
  assert.equal(response.body.data.expiresIn, 3600);
  assert.deepEqual(response.body.data.user, {
    email: 'member@example.com',
    fullName: 'Nguyen Van A',
    id: '10000000-0000-4000-8000-000000000001',
    role: 'MEMBER',
    status: 'ACTIVE',
  });
  assert.equal(JSON.stringify(response.body).includes('password'), false);
  assert.equal(queries[0].values[0], 'member@example.com');
  assert.match(queries[0].text, /password_hash/i);
  assert.match(queries[1].text, /last_login_at/i);
  assert.deepEqual(queries[1].values, [
    '10000000-0000-4000-8000-000000000001',
    3,
  ]);

  const payload = jwt.verify(response.body.data.accessToken, JWT_SECRET, {
    algorithms: ['HS256'],
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
  });
  assert.equal(payload.sub, '10000000-0000-4000-8000-000000000001');
  assert.equal(payload.role, 'MEMBER');
  assert.equal(payload.sessionVersion, 3);
  assert.equal(payload.exp - payload.iat, 3600);
});

test('POST /api/v1/auth/sessions rejects invalid input before querying the database', async () => {
  let queryCount = 0;
  const database = {
    query: async () => {
      queryCount += 1;
      return { rows: [] };
    },
  };
  const app = createSessionApp({ database });

  const response = await postSession(app, {
    email: 'not-an-email',
    password: '',
    role: 'ADMIN',
  });

  assert.equal(response.status, 422);
  assert.equal(response.body.error.code, 'VALIDATION_ERROR');
  assert.ok(response.body.error.details.fields.email);
  assert.ok(response.body.error.details.fields.password);
  assert.ok(response.body.error.details.fields.role);
  assert.equal(queryCount, 0);
});

test('POST /api/v1/auth/sessions returns the same 401 for an unknown email and a wrong password', async () => {
  const passwordHash = await bcrypt.hash('CorrectPass1', 4);
  const expectedError = {
    error: {
      code: 'INVALID_CREDENTIALS',
      details: {},
      message: 'Email hoặc mật khẩu không đúng',
    },
  };

  for (const scenario of [
    { email: 'missing@example.com', rows: [] },
    {
      email: 'member@example.com',
      rows: [
        {
          email: 'member@example.com',
          full_name: 'Nguyen Van A',
          id: '10000000-0000-4000-8000-000000000001',
          password_hash: passwordHash,
          role: 'MEMBER',
          session_version: 0,
          status: 'ACTIVE',
        },
      ],
    },
  ]) {
    const database = {
      query: async () => ({ rows: scenario.rows }),
    };
    const app = createSessionApp({ database });

    const response = await postSession(app, {
      email: scenario.email,
      password: 'WrongPass1',
    });

    assert.equal(response.status, 401);
    assert.deepEqual(response.body, expectedError);
  }
});

test('POST /api/v1/auth/sessions rejects a disabled account after validating its password', async () => {
  const passwordHash = await bcrypt.hash('CorrectPass1', 4);
  let queryCount = 0;
  const database = {
    query: async () => {
      queryCount += 1;
      return {
        rows: [
          {
            email: 'member@example.com',
            full_name: 'Nguyen Van A',
            id: '10000000-0000-4000-8000-000000000001',
            password_hash: passwordHash,
            role: 'MEMBER',
            session_version: 0,
            status: 'DISABLED',
          },
        ],
      };
    },
  };
  const app = createSessionApp({ database });

  const response = await postSession(app, {
    email: 'member@example.com',
    password: 'CorrectPass1',
  });

  assert.equal(response.status, 403);
  assert.deepEqual(response.body, {
    error: {
      code: 'ACCOUNT_DISABLED',
      details: {},
      message: 'Tài khoản đã bị khóa',
    },
  });
  assert.equal(queryCount, 1);
});

test('POST /api/v1/auth/sessions does not expose unexpected database errors', async () => {
  const database = {
    query: async () => {
      throw new Error('SELECT password_hash FROM users with secret connection');
    },
  };
  const app = createSessionApp({ database });

  const response = await postSession(app, {
    email: 'member@example.com',
    password: 'CorrectPass1',
  });

  assert.equal(response.status, 500);
  assert.deepEqual(response.body, {
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      details: {},
      message: 'Đã xảy ra lỗi, vui lòng thử lại sau',
    },
  });
  assert.equal(JSON.stringify(response.body).includes('password_hash'), false);
});

test('POST /api/v1/auth/sessions returns 429 before password lookup when a bucket is blocked', async () => {
  let queryCount = 0;
  const database = {
    query: async () => {
      queryCount += 1;
      return { rows: [] };
    },
  };
  const loginRateLimiter = {
    run: async ({ email, ip }, handler) => {
      assert.equal(email, 'member@example.com');
      assert.ok(ip);
      return handler({
        blocked: true,
        registerFailure: async () => false,
        resetAccount: async () => {},
      });
    },
  };
  const app = createSessionApp({ database, loginRateLimiter });

  const response = await postSession(app, {
    email: 'member@example.com',
    password: 'WrongPass1',
  });

  assert.equal(response.status, 429);
  assert.equal(response.body.error.code, 'TOO_MANY_REQUESTS');
  assert.equal(queryCount, 0);
});

test('POST /api/v1/auth/sessions records invalid credentials and blocks the threshold attempt', async () => {
  const calls = [];
  const database = { query: async () => ({ rows: [] }) };
  const loginRateLimiter = {
    run: async (context, handler) => {
      calls.push(context);
      return handler({
        blocked: false,
        registerFailure: async () => true,
        resetAccount: async () => {},
      });
    },
  };
  const app = createSessionApp({ database, loginRateLimiter });

  const response = await postSession(app, {
    email: 'member@example.com',
    password: 'WrongPass1',
  });

  assert.equal(response.status, 429);
  assert.equal(response.body.error.code, 'TOO_MANY_REQUESTS');
  assert.equal(calls.length, 1);
  assert.equal(calls[0].email, 'member@example.com');
  assert.ok(calls[0].ip);
});

test('POST /api/v1/auth/sessions rejects a concurrent status change without issuing a token', async () => {
  const passwordHash = await bcrypt.hash('CorrectPass1', 4);
  let queryCount = 0;
  const database = {
    query: async () => {
      queryCount += 1;
      if (queryCount === 1) {
        return {
          rows: [{
            email: 'member@example.com',
            full_name: 'Nguyen Van A',
            id: '10000000-0000-4000-8000-000000000001',
            password_hash: passwordHash,
            role: 'MEMBER',
            session_version: 0,
            status: 'ACTIVE',
          }],
        };
      }
      return { rows: [] };
    },
  };
  const app = createSessionApp({ database });

  const response = await postSession(app, {
    email: 'member@example.com',
    password: 'CorrectPass1',
  });

  assert.equal(response.status, 403);
  assert.equal(response.body.error.code, 'ACCOUNT_DISABLED');
  assert.equal('data' in response.body, false);
});

test('POST /api/v1/auth/sessions rejects a concurrent session version change', async () => {
  const passwordHash = await bcrypt.hash('CorrectPass1', 4);
  let queryCount = 0;
  const database = {
    query: async () => {
      queryCount += 1;
      return queryCount === 1
        ? {
            rows: [{
              email: 'member@example.com',
              full_name: 'Nguyen Van A',
              id: '10000000-0000-4000-8000-000000000001',
              password_hash: passwordHash,
              role: 'MEMBER',
              session_version: 4,
              status: 'ACTIVE',
            }],
          }
        : { rows: [] };
    },
  };
  const app = createSessionApp({ database });

  const response = await postSession(app, {
    email: 'member@example.com',
    password: 'CorrectPass1',
  });

  assert.equal(response.status, 403);
  assert.equal('data' in response.body, false);
});

test('POST /api/v1/auth/sessions hides database errors raised during last-login update', async () => {
  const passwordHash = await bcrypt.hash('CorrectPass1', 4);
  let queryCount = 0;
  const database = {
    query: async () => {
      queryCount += 1;
      if (queryCount === 1) {
        return {
          rows: [{
            email: 'member@example.com',
            full_name: 'Nguyen Van A',
            id: '10000000-0000-4000-8000-000000000001',
            password_hash: passwordHash,
            role: 'MEMBER',
            session_version: 0,
            status: 'ACTIVE',
          }],
        };
      }
      throw new Error('UPDATE users leaked database details');
    },
  };
  const app = createSessionApp({ database });

  const response = await postSession(app, {
    email: 'member@example.com',
    password: 'CorrectPass1',
  });

  assert.equal(response.status, 500);
  assert.equal(response.body.error.code, 'INTERNAL_SERVER_ERROR');
  assert.equal(JSON.stringify(response.body).includes('UPDATE users'), false);
});
