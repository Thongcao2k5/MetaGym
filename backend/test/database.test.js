import assert from 'node:assert/strict';
import test from 'node:test';

import { createDatabasePool } from '../src/config/database.js';

test('createDatabasePool rejects a missing DATABASE_URL at startup', () => {
  assert.throws(
    () => createDatabasePool({ connectionString: '' }),
    /DATABASE_URL is required/,
  );
});
