import assert from 'node:assert/strict';
import { mkdir, mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import pg from 'pg';
import { migrate } from '../scripts/migrate.js';

// This URL must point to a disposable, dedicated database: fixtures reset public.
const connectionString = process.env.MIGRATION_TEST_DATABASE_URL;
test('migration runner on PostgreSQL', { skip: !connectionString }, async (t) => {
  const client = new pg.Client({ connectionString });
  await client.connect();
  const directory = await mkdtemp(path.join(tmpdir(), 'metagym-migrations-'));
  const options = { connectionString, directory, log: () => {} };
  const first = '0001_fixture.up.sql';
  const second = '0002_next.up.sql';
  async function reset() {
    await client.query('DROP SCHEMA IF EXISTS metagym_ops CASCADE; DROP SCHEMA public CASCADE; CREATE SCHEMA public');
    await rm(directory, { recursive: true, force: true });
    await mkdir(directory);
    await writeFile(path.join(directory, first), 'BEGIN;\nCREATE TABLE fixture (id integer);\nCOMMIT;');
  }
  try {
    await t.test('applies once and serializes concurrent runners', async () => {
      await reset();
      await Promise.all([migrate(options), migrate(options)]);
      await writeFile(path.join(directory, first), 'BEGIN;\r\nCREATE TABLE fixture (id integer);\r\nCOMMIT;');
      await migrate(options);
      assert.equal((await client.query('SELECT * FROM metagym_ops.schema_migrations')).rowCount, 1);
    });
    await t.test('rolls back a failed file and does not record it', async () => {
      await reset();
      await writeFile(path.join(directory, second), 'BEGIN; CREATE TABLE failed_fixture (id int); SELECT missing_column; COMMIT;');
      await assert.rejects(migrate(options), /0002_next/);
      assert.equal((await client.query("SELECT to_regclass('public.failed_fixture') AS name")).rows[0].name, null);
      assert.equal((await client.query('SELECT * FROM metagym_ops.schema_migrations')).rowCount, 1);
    });
    await t.test('rejects an edited or missing applied migration', async () => {
      await reset();
      await migrate(options);
      await writeFile(path.join(directory, first), 'SELECT 1;');
      await assert.rejects(migrate(options), /checksum/);
      await rm(path.join(directory, first));
      await writeFile(path.join(directory, second), 'SELECT 1;');
      await assert.rejects(migrate(options), /missing/i);
    });
    await t.test('requires explicit baseline for an existing untracked database', async () => {
      await reset();
      await client.query('CREATE TABLE fixture (id integer)');
      await assert.rejects(migrate(options), /baseline/i);
      await writeFile(path.join(directory, second), 'ALTER TABLE fixture ADD COLUMN name text;');
      await migrate({ ...options, baseline: '0001' });
      assert.equal((await client.query('SELECT * FROM metagym_ops.schema_migrations')).rowCount, 1);
      await migrate(options);
      assert.equal((await client.query('SELECT name FROM fixture')).rowCount, 0);
      await assert.rejects(migrate({ ...options, baseline: '0001' }), /history/i);
    });
    await t.test('rejects duplicate versions and out of order insertions', async () => {
      await reset();
      await writeFile(path.join(directory, '0001_duplicate.up.sql'), 'SELECT 1;');
      await assert.rejects(migrate(options), /duplicate/i);
      await rm(path.join(directory, '0001_duplicate.up.sql'));
      await migrate(options);
      await writeFile(path.join(directory, '0000_late.up.sql'), 'SELECT 1;');
      await assert.rejects(migrate(options), /order/i);
    });
  } finally {
    await client.query('DROP SCHEMA IF EXISTS metagym_ops CASCADE; DROP SCHEMA public CASCADE; CREATE SCHEMA public');
    await client.end();
    await rm(directory, { recursive: true, force: true });
  }
});
