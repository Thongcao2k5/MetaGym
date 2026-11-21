import assert from 'node:assert/strict';
import test from 'node:test';
import { createApp } from '../src/app.js';

const testSecret = 'swagger-docs-test-secret-with-32-chars';
const mockDatabase = {
  async query() {
    return { rows: [] };
  },
  async connect() {
    return { query: async () => ({ rows: [] }), release() {} };
  },
};

test('GET /api-docs/ serves Swagger UI HTML and /api-docs/openapi.json returns OpenAPI spec', async (t) => {
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

  const uiResponse = await fetch(`${baseUrl}/api-docs/`);
  assert.equal(uiResponse.status, 200);
  const html = await uiResponse.text();
  assert.match(html, /Meta Gym API — Swagger UI/);
  assert.equal(uiResponse.headers.get('content-security-policy'), null);

  const jsonResponse = await fetch(`${baseUrl}/api-docs/openapi.json`);
  assert.equal(jsonResponse.status, 200);
  const spec = await jsonResponse.json();
  assert.equal(spec.openapi, '3.0.3');
  assert.equal(spec.info.title, 'Meta Gym REST API');
  assert.ok(spec.paths['/health']);
  assert.equal(spec.servers[0].url, '/api/v1');
});
