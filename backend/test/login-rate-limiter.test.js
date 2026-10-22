import assert from 'node:assert/strict';
import test from 'node:test';

import { createDatabaseLoginRateLimiter } from '../src/security/login-rate-limiter.js';

function createClient(query) {
  let released = false;
  return {
    query,
    release: () => { released = true; },
    wasReleased: () => released,
  };
}

test('database login limiter holds advisory locks around the attempt', async () => {
  const calls = [];
  const client = createClient(async (text, values) => {
    calls.push({ text, values });
    return { rows: text.includes('bool_or') ? [{ blocked: false }] : [] };
  });
  const limiter = createDatabaseLoginRateLimiter({ database: { connect: async () => client } });

  const result = await limiter.run(
    { email: 'member@example.com', ip: '127.0.0.1' },
    async ({ blocked }) => {
      assert.equal(blocked, false);
      assert.equal(calls.filter(({ text }) => text.includes('pg_advisory_lock')).length, 2);
      return 'completed';
    },
  );

  assert.equal(result, 'completed');
  assert.equal(calls.filter(({ text }) => text.includes('pg_advisory_unlock')).length, 2);
  assert.equal(client.wasReleased(), true);
});

test('database login limiter records failures atomically while locks are held', async () => {
  const client = createClient(async (text) => {
    if (text.includes('bool_or')) return { rows: [{ blocked: false }] };
    if (text.includes('INSERT INTO auth_login_rate_limits')) {
      assert.match(text, /ON CONFLICT/i);
      return { rows: [{ blocked: false }, { blocked: true }] };
    }
    return { rows: [] };
  });
  const limiter = createDatabaseLoginRateLimiter({ database: { connect: async () => client } });

  const blocked = await limiter.run(
    { email: 'member@example.com', ip: '127.0.0.1' },
    ({ registerFailure }) => registerFailure(),
  );

  assert.equal(blocked, true);
});

test('database login limiter clears the account bucket after success', async () => {
  let deleteValues;
  const client = createClient(async (text, values) => {
    if (text.includes('bool_or')) return { rows: [{ blocked: false }] };
    if (text.includes('DELETE FROM auth_login_rate_limits')) deleteValues = values;
    return { rows: [] };
  });
  const limiter = createDatabaseLoginRateLimiter({ database: { connect: async () => client } });

  await limiter.run(
    { email: 'member@example.com', ip: '127.0.0.1' },
    ({ resetAccount }) => resetAccount(),
  );

  assert.equal(deleteValues.length, 1);
  assert.match(deleteValues[0], /^[0-9a-f]{64}$/);
});
