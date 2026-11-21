import 'dotenv/config';
import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';
import pg from 'pg';

const migrationDirectory = fileURLToPath(new URL('../../database/migrations/', import.meta.url));

export async function migrate({
  connectionString = process.env.DATABASE_URL,
  directory = migrationDirectory,
  baseline,
  log = console.log,
} = {}) {
  if (!connectionString) throw new Error('DATABASE_URL is required');
  const names = (await readdir(directory)).filter((name) => name.endsWith('.up.sql')).sort();
  if (!names.length) throw new Error('No migrations found');
  const versions = new Set();
  const files = await Promise.all(names.map(async (name) => {
    const version = /^(\d{4})_.+\.up\.sql$/.exec(name)?.[1];
    if (!version || versions.has(version)) throw new Error(`Invalid or duplicate migration version: ${name}`);
    versions.add(version);
    // Normalize checkout line endings for identical checksums on Windows/Linux.
    const sql = (await readFile(path.join(directory, name), 'utf8')).replace(/\r\n/g, '\n').trim();
    const checksum = createHash('sha256').update(sql).digest('hex');
    // Existing SQL files own BEGIN/COMMIT; the runner must also atomically record history.
    const wrapped = /^BEGIN\s*;([\s\S]*)COMMIT\s*;\s*$/i.exec(sql);
    if (/^BEGIN\s*;/i.test(sql) && !wrapped) {
      throw new Error(`Migration must end with COMMIT;: ${name}`);
    }
    const body = wrapped ? wrapped[1] : sql;
    return { name, version, checksum, body };
  }));
  if (baseline && (!/^\d{4}$/.test(baseline) || !versions.has(baseline))) {
    throw new Error('Baseline must be an existing four-digit migration version');
  }
  const client = new pg.Client({ connectionString, connectionTimeoutMillis: 15000 });
  await client.connect();
  try {
    await client.query("SET lock_timeout = '60s'");
    // Session lock also covers ledger creation and separate per-file transactions.
    await client.query('SELECT pg_advisory_lock(764219830112::bigint)');
    await client.query(`CREATE SCHEMA IF NOT EXISTS metagym_ops;
      REVOKE ALL ON SCHEMA metagym_ops FROM PUBLIC;
      CREATE TABLE IF NOT EXISTS metagym_ops.schema_migrations (
        name text PRIMARY KEY,
        checksum text NOT NULL,
        applied_at timestamptz NOT NULL DEFAULT now()
      )`);
    const { rows } = await client.query('SELECT name, checksum FROM metagym_ops.schema_migrations ORDER BY name');
    const applied = new Map(rows.map((row) => [row.name, row.checksum]));
    for (const row of rows) {
      const file = files.find((item) => item.name === row.name);
      if (!file) throw new Error(`Applied migration missing from repository: ${row.name}`);
      if (file.checksum !== row.checksum) throw new Error(`Migration checksum changed: ${row.name}`);
    }
    if (baseline) {
      if (rows.length) throw new Error('Cannot baseline a database with migration history');
      await client.query('BEGIN');
      for (const file of files.filter((item) => item.version <= baseline)) {
        await client.query('INSERT INTO metagym_ops.schema_migrations (name, checksum) VALUES ($1, $2)',
          [file.name, file.checksum]);
      }
      await client.query('COMMIT');
      log(`Recorded baseline through ${baseline}; no migration SQL executed. Run db:migrate next.`);
      return;
    }
    if (!rows.length) {
      const existing = await client.query("SELECT 1 FROM pg_tables WHERE schemaname = 'public' LIMIT 1");
      if (existing.rowCount) throw new Error('Existing database has no migration history. Verify its applied version and run db:migrate -- --baseline=NNNN once.');
    }
    const pending = files.filter((file) => !applied.has(file.name));
    if (pending.some((file) => file.name < rows.at(-1)?.name)) {
      throw new Error('Out of order migration: append a new version after the latest applied migration');
    }
    for (const file of pending) {
      log(`Applying ${file.name}`);
      await client.query('BEGIN');
      try {
        await client.query(file.body);
        await client.query('INSERT INTO metagym_ops.schema_migrations (name, checksum) VALUES ($1, $2)',
          [file.name, file.checksum]);
        await client.query('COMMIT');
      } catch (error) {
        await client.query('ROLLBACK');
        // Do not print connection strings, SQL, or row data in deployment logs.
        throw new Error(`Migration failed: ${file.name} (PostgreSQL ${error.code ?? 'unknown'})`);
      }
    }
    log(`Database ready: ${pending.length} migration(s) applied.`);
  } finally {
    // Closing the session also releases the advisory lock on all failure paths.
    await client.end();
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const args = process.argv.slice(2);
  if (args.length > 1 || (args[0] && !/^--baseline=\d{4}$/.test(args[0]))) {
    console.error('Usage: npm run db:migrate -- [--baseline=NNNN]');
    process.exitCode = 1;
  } else {
    try {
      await migrate({ baseline: args[0]?.split('=')[1] });
    } catch (error) {
      // Connection errors may contain credentials; only known runner errors are safe to log.
      console.error(error.message.startsWith('Migration') || /^(Existing database|Applied migration|Out of order|Cannot baseline|Baseline|DATABASE_URL|No migrations|Invalid or duplicate)/.test(error.message)
        ? error.message : `Database migration connection/read failure (${error.code ?? 'unknown'}).`);
      process.exitCode = 1;
    }
  }
}
