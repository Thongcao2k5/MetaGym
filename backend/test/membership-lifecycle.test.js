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
