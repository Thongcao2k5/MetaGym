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
