import assert from 'node:assert/strict';
import test from 'node:test';
import { createApp } from '../src/app.js';

const testSecret = 'ping-route-test-secret-with-32-chars';
const mockDatabase = {
  async query() {
    throw new Error('ping should not query database');
  },
  async connect() {
    throw new Error('ping should not connect database');
  },
};

test('GET /ping returns 200 ok without hitting database', async (t) => {
  const app = createApp({
    database: mockDatabase,
    jwtSecret: testSecret,
    nodeEnv: 'test',
  });
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const { port } = server.address();
  const response = await fetch(`http://127.0.0.1:${port}/ping`);
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.data.status, 'ok');
  assert.equal(typeof body.data.uptimeSeconds, 'number');
});
