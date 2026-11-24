import assert from 'node:assert/strict';
import test from 'node:test';
import { createApp } from '../src/app.js';

const testSecret = 'database-ui-test-secret-with-32-chars-ok';

function createMockDatabase() {
  const rows = [
    { id: 1, name: 'Basic Plan', active: true },
    { id: 2, name: 'Pro Plan', active: false },
  ];
  let nextId = 3;

  return {
    rows,
    async query(sql, params = []) {
      const text = String(sql).trim();

      if (text.includes('FROM information_schema.tables t')) {
        return { rows: [{ name: 'plans', row_estimate: rows.length }] };
      }
      if (text.includes('FROM information_schema.tables') && text.includes('table_name = $1')) {
        return params[0] === 'plans' ? { rows: [{ table_name: 'plans' }] } : { rows: [] };
      }
      if (text.includes('FROM information_schema.columns')) {
        return {
          rows: [
            {
              column_name: 'id',
              data_type: 'integer',
              udt_name: 'int4',
              is_nullable: 'NO',
              column_default: "nextval('plans_id_seq'::regclass)",
              character_maximum_length: null,
              is_identity: 'NO',
              ordinal_position: 1,
            },
            {
              column_name: 'name',
              data_type: 'text',
              udt_name: 'text',
              is_nullable: 'NO',
              column_default: null,
              character_maximum_length: null,
              is_identity: 'NO',
              ordinal_position: 2,
            },
            {
              column_name: 'active',
              data_type: 'boolean',
              udt_name: 'bool',
              is_nullable: 'YES',
              column_default: 'true',
              character_maximum_length: null,
              is_identity: 'NO',
              ordinal_position: 3,
            },
          ],
        };
      }
      if (text.includes("constraint_type = 'PRIMARY KEY'")) {
        return { rows: [{ column_name: 'id' }] };
      }
      if (text.includes("constraint_type = 'FOREIGN KEY'")) {
        return { rows: [] };
      }
      if (text.includes('FROM pg_type t')) {
        return { rows: [] };
      }
      if (text.startsWith('SELECT COUNT(*)')) {
        return { rows: [{ total: rows.length }] };
      }
      if (text.startsWith('SELECT * FROM "public"."plans"')) {
        return { rows: [...rows] };
      }
      if (text.startsWith('INSERT INTO "public"."plans"')) {
        const created = { id: nextId++, name: params[0], active: params[1] ?? true };
        rows.push(created);
        return { rows: [created] };
      }
      if (text.startsWith('UPDATE "public"."plans"')) {
        const id = Number(params[params.length - 1]);
        const target = rows.find((r) => r.id === id);
        if (!target) return { rows: [] };
        target.name = params[0];
        return { rows: [target] };
      }
      if (text.startsWith('DELETE FROM "public"."plans"')) {
        const id = Number(params[0]);
        const idx = rows.findIndex((r) => r.id === id);
        if (idx === -1) return { rows: [] };
        const [removed] = rows.splice(idx, 1);
        return { rows: [removed] };
      }
      return { rows: [] };
    },
    async connect() {
      return { query: this.query.bind(this), release() {} };
    },
  };
}

test('Database UI serves HTML, requires admin/admin login, and supports table CRUD', async (t) => {
  const mockDatabase = createMockDatabase();
  const app = createApp({
    database: mockDatabase,
    jwtSecret: testSecret,
    nodeEnv: 'test',
  });

  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const { port } = server.address();
  const baseUrl = `http://127.0.0.1:${port}`;

  // 1. HTML UI served without CSP
  const htmlRes = await fetch(`${baseUrl}/database`);
  assert.equal(htmlRes.status, 200);
  const html = await htmlRes.text();
  assert.match(html, /Meta Gym — Database Studio/);
  assert.equal(htmlRes.headers.get('content-security-policy'), null);

  // 2. Unauthenticated API request rejected
  const unauthRes = await fetch(`${baseUrl}/database/api/tables`);
  assert.equal(unauthRes.status, 401);

  // 3. Wrong credentials rejected
  const badLogin = await fetch(`${baseUrl}/database/api/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'wrong' }),
  });
  assert.equal(badLogin.status, 401);

  // 4. Correct admin/admin login succeeds
  const loginRes = await fetch(`${baseUrl}/database/api/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'admin' }),
  });
  assert.equal(loginRes.status, 200);
  const loginJson = await loginRes.json();
  assert.equal(loginJson.data.username, 'admin');
  assert.ok(loginJson.data.token);
  const authHeaders = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${loginJson.data.token}`,
  };

  // 5. List tables
  const tablesRes = await fetch(`${baseUrl}/database/api/tables`, { headers: authHeaders });
  assert.equal(tablesRes.status, 200);
  const tablesJson = await tablesRes.json();
  assert.deepEqual(tablesJson.data.tables, [{ name: 'plans', rowEstimate: 2 }]);

  // 6. Reject unknown table
  const unknownRes = await fetch(`${baseUrl}/database/api/tables/users;DROP/rows`, {
    headers: authHeaders,
  });
  assert.equal(unknownRes.status, 404);

  // 7. Browse rows
  const rowsRes = await fetch(`${baseUrl}/database/api/tables/plans/rows?page=1&pageSize=10`, {
    headers: authHeaders,
  });
  assert.equal(rowsRes.status, 200);
  const rowsJson = await rowsRes.json();
  assert.equal(rowsJson.data.rows.length, 2);
  assert.deepEqual(rowsJson.data.primaryKeys, ['id']);

  // 8. Insert row
  const insertRes = await fetch(`${baseUrl}/database/api/tables/plans/rows`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({ values: { name: 'VIP Plan', active: true } }),
  });
  assert.equal(insertRes.status, 201);
  const insertJson = await insertRes.json();
  assert.equal(insertJson.data.row.id, 3);
  assert.equal(insertJson.data.row.name, 'VIP Plan');

  // 9. Update row
  const updateRes = await fetch(`${baseUrl}/database/api/tables/plans/rows`, {
    method: 'PATCH',
    headers: authHeaders,
    body: JSON.stringify({ primaryKey: { id: 3 }, values: { name: 'VIP Plus' } }),
  });
  assert.equal(updateRes.status, 200);
  const updateJson = await updateRes.json();
  assert.equal(updateJson.data.row.name, 'VIP Plus');

  // 10. Reject unknown column on update
  const badColRes = await fetch(`${baseUrl}/database/api/tables/plans/rows`, {
    method: 'PATCH',
    headers: authHeaders,
    body: JSON.stringify({ primaryKey: { id: 3 }, values: { hacked_col: 'x' } }),
  });
  assert.equal(badColRes.status, 400);

  // 11. Delete row
  const deleteRes = await fetch(`${baseUrl}/database/api/tables/plans/rows`, {
    method: 'DELETE',
    headers: authHeaders,
    body: JSON.stringify({ primaryKey: { id: 3 } }),
  });
  assert.equal(deleteRes.status, 200);
  const deleteJson = await deleteRes.json();
  assert.equal(deleteJson.data.deleted.id, 3);
});

test('Database UI is disabled by default in production unless enableDatabaseUi is true', async (t) => {
  const mockDatabase = createMockDatabase();
  const app = createApp({
    database: mockDatabase,
    jwtSecret: testSecret,
    nodeEnv: 'production',
    corsAllowedOrigins: 'https://metagym.example.com',
  });

  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const { port } = server.address();
  const response = await fetch(`http://127.0.0.1:${port}/database`);
  assert.equal(response.status, 404);
});
