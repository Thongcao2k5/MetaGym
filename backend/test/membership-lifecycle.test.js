import assert from 'node:assert/strict';
import test from 'node:test';

import { reconcileMembershipLifecycles } from '../src/services/membership-lifecycle.js';

test('membership reconciliation coalesces concurrent calls and throttles repeats', async () => {
  let connections = 0;
  let releases = 0;
  const client = {
    async query(sql) {
      await new Promise((resolve) => setImmediate(resolve));
      return sql.includes('RETURNING r.id') ? { rows: [] } : { rows: [] };
    },
    release() { releases += 1; },
  };
  const database = {
    async connect() { connections += 1; return client; },
  };

  await Promise.all([
    reconcileMembershipLifecycles(database),
    reconcileMembershipLifecycles(database),
  ]);
  await reconcileMembershipLifecycles(database);

  assert.equal(connections, 1);
  assert.equal(releases, 1);
});

test('membership reconciliation runs again when the gym-local date advances', async () => {
  const originalNow = Date.now;
  let now = Date.parse('2026-10-21T16:59:50.000Z');
  let connections = 0;
  const client = {
    async query(sql) {
      return sql.includes('RETURNING r.id') ? { rows: [] } : { rows: [] };
    },
    release() {},
  };
  const database = {
    async connect() { connections += 1; return client; },
  };

  try {
    Date.now = () => now;
    await reconcileMembershipLifecycles(database);
    now = Date.parse('2026-10-21T17:00:10.000Z');
    await reconcileMembershipLifecycles(database);
  } finally {
    Date.now = originalNow;
  }

  assert.equal(connections, 2);
});

test('a new gym-local date waits for an older in-flight run and reconciles again', async () => {
  const originalNow = Date.now;
  let now = Date.parse('2026-10-21T16:59:59.000Z');
  let connections = 0;
  let signalFirstRun;
  let releaseFirstRun;
  const firstRunStarted = new Promise((resolve) => { signalFirstRun = resolve; });
  const firstRunRelease = new Promise((resolve) => { releaseFirstRun = resolve; });
  const database = {
    async connect() {
      connections += 1;
      const connectionNumber = connections;
      return {
        async query(sql) {
          if (connectionNumber === 1 && sql === 'BEGIN') {
            signalFirstRun();
            await firstRunRelease;
          }
          return { rows: [] };
        },
        release() {},
      };
    },
  };

  try {
    Date.now = () => now;
    const first = reconcileMembershipLifecycles(database);
    await firstRunStarted;
    now = Date.parse('2026-10-21T17:00:01.000Z');
    const second = reconcileMembershipLifecycles(database);
    releaseFirstRun();
    await Promise.all([first, second]);
  } finally {
    Date.now = originalNow;
  }

  assert.equal(connections, 2);
});
