import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import bcrypt from 'bcryptjs';
import pg from 'pg';

import { createApp } from '../src/app.js';

const { Pool } = pg;
const TEST_DATABASE_URL = process.env.TEST_DATABASE_URL;
const JWT_SECRET = 'A7$postgres-integration-secret-with-32-plus-chars';

async function postSession(app, body) {
  const server = app.listen(0);

  try {
    const { port } = server.address();
    const response = await fetch(
      `http://127.0.0.1:${port}/api/v1/auth/sessions`,
      {
        body: JSON.stringify(body),
        headers: { 'content-type': 'application/json' },
        method: 'POST',
      },
    );

    return { body: await response.json(), status: response.status };
  } finally {
    await new Promise((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  }
}

async function postSessions(app, bodies) {
  const server = app.listen(0);

  try {
    const { port } = server.address();
    return await Promise.all(
      bodies.map(async (body) => {
        const response = await fetch(
          `http://127.0.0.1:${port}/api/v1/auth/sessions`,
          {
            body: JSON.stringify(body),
            headers: { 'content-type': 'application/json' },
            method: 'POST',
          },
        );
        return { body: await response.json(), status: response.status };
      }),
    );
  } finally {
    await new Promise((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  }
}

test(
  'PostgreSQL integration: login succeeds and persists last_login_at',
  { skip: !TEST_DATABASE_URL },
  async () => {
    const database = new Pool({ connectionString: TEST_DATABASE_URL });
    const id = randomUUID();
    const email = `integration-${id}@example.com`;
    const password = 'CorrectPass1';
    const passwordHash = await bcrypt.hash(password, 12);

    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, $3, 'MEMBER', 'Integration Member')`,
        [id, email, passwordHash],
      );
      await database.query(
        'INSERT INTO member_profiles (user_id) VALUES ($1)',
        [id],
      );

      const app = createApp({ database, jwtSecret: JWT_SECRET });
      const response = await postSession(app, { email, password });

      assert.equal(response.status, 200);
      const persisted = await database.query(
        'SELECT last_login_at FROM users WHERE id = $1',
        [id],
      );
      assert.ok(persisted.rows[0].last_login_at instanceof Date);
    } finally {
      await database.query('DELETE FROM member_profiles WHERE user_id = $1', [id]);
      await database.query('DELETE FROM users WHERE id = $1', [id]);
      await database.end();
    }
  },
);

test(
  'PostgreSQL integration: parallel failures cannot exceed the login limit',
  { skip: !TEST_DATABASE_URL },
  async () => {
    const database = new Pool({ connectionString: TEST_DATABASE_URL });
    const id = randomUUID();
    const email = `parallel-${id}@example.com`;
    const passwordHash = await bcrypt.hash('CorrectPass1', 4);

    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, $3, 'MEMBER', 'Parallel Member')`,
        [id, email, passwordHash],
      );
      await database.query(
        'INSERT INTO member_profiles (user_id) VALUES ($1)',
        [id],
      );

      const app = createApp({ database, jwtSecret: JWT_SECRET });
      const responses = await postSessions(
        app,
        Array.from({ length: 6 }, () => ({ email, password: 'WrongPass1' })),
      );

      assert.equal(responses.filter(({ status }) => status === 401).length, 4);
      assert.equal(responses.filter(({ status }) => status === 429).length, 2);
      const buckets = await database.query(
        `SELECT failure_count
         FROM auth_login_rate_limits
         WHERE failure_count = 5`,
      );
      assert.equal(buckets.rows.length, 2);
    } finally {
      await database.query('DELETE FROM auth_login_rate_limits');
      await database.query('DELETE FROM member_profiles WHERE user_id = $1', [id]);
      await database.query('DELETE FROM users WHERE id = $1', [id]);
      await database.end();
    }
  },
);

test(
  'PostgreSQL integration: concurrent account disable prevents token issuance',
  { skip: !TEST_DATABASE_URL },
  async () => {
    const pool = new Pool({ connectionString: TEST_DATABASE_URL });
    const id = randomUUID();
    const email = `concurrent-${id}@example.com`;
    const password = 'CorrectPass1';
    const passwordHash = await bcrypt.hash(password, 12);

    try {
      await pool.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, $3, 'MEMBER', 'Concurrent Member')`,
        [id, email, passwordHash],
      );
      await pool.query(
        'INSERT INTO member_profiles (user_id) VALUES ($1)',
        [id],
      );

      let releaseLastLoginUpdate;
      const lastLoginUpdateReached = new Promise((resolve) => {
        releaseLastLoginUpdate = resolve;
      });
      let continueLastLoginUpdate;
      const lastLoginUpdateMayContinue = new Promise((resolve) => {
        continueLastLoginUpdate = resolve;
      });
      const database = {
        connect: async () => {
          const client = await pool.connect();
          return {
            query: async (text, values) => {
              if (/^\s*UPDATE users\s+SET last_login_at/i.test(text)) {
                releaseLastLoginUpdate();
                await lastLoginUpdateMayContinue;
              }
              return client.query(text, values);
            },
            release: () => client.release(),
          };
        },
        query: (...args) => pool.query(...args),
      };
      const app = createApp({ database, jwtSecret: JWT_SECRET });
      const responsePromise = postSession(app, { email, password });

      await lastLoginUpdateReached;
      await pool.query(
        `UPDATE users
         SET status = 'DISABLED', disabled_at = now(),
             disabled_reason = 'Integration test', session_version = session_version + 1
         WHERE id = $1`,
        [id],
      );
      continueLastLoginUpdate();

      const response = await responsePromise;
      assert.equal(response.status, 403);
      assert.equal(response.body.error.code, 'ACCOUNT_DISABLED');
      assert.equal('data' in response.body, false);
    } finally {
      await pool.query('DELETE FROM auth_login_rate_limits');
      await pool.query('DELETE FROM member_profiles WHERE user_id = $1', [id]);
      await pool.query('DELETE FROM users WHERE id = $1', [id]);
      await pool.end();
    }
  },
);
