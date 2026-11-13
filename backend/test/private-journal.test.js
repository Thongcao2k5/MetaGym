import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';

import { createApp } from '../src/app.js';

const secret = 'private-journal-test-secret-with-32-characters';

function bearer(id, role) {
  return `Bearer ${jwt.sign({ role, sessionVersion: 0 }, secret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
    subject: id, expiresIn: 3600,
  })}`;
}

test('Coach and Admin cannot read the Member journal or obtain its photo URL', async () => {
  const memberId = randomUUID();
  const coachId = randomUUID();
  const adminId = randomUUID();
  const mediaId = randomUUID();
  const mealMediaId = randomUUID();
  const users = new Map([
    [memberId, { id: memberId, role: 'MEMBER' }],
    [coachId, { id: coachId, role: 'COACH' }],
    [adminId, { id: adminId, role: 'ADMIN' }],
  ]);
  const database = {
    async query(sql, values) {
      if (sql.includes('FROM users u')) {
        const user = users.get(values[0]);
        return { rows: user ? [{ ...user, status: 'ACTIVE', session_version: 0 }] : [] };
      }
      if (sql.includes('FROM media_assets')) {
        const purpose = values[0] === mediaId ? 'PROGRESS_PHOTO'
          : values[0] === mealMediaId ? 'MEAL_PHOTO' : null;
        return { rows: purpose ? [{
          id: values[0], owner_id: memberId, purpose, status: 'READY',
        }] : [] };
      }
      throw new Error(`Unexpected query: ${sql}`);
    },
  };
  const app = createApp({ database, jwtSecret: secret,
    imageStorage: { get: async () => Buffer.from('image') } });
  const server = app.listen(0);
  try {
    const base = `http://127.0.0.1:${server.address().port}/api/v1`;
    for (const [id, role] of [[coachId, 'COACH'], [adminId, 'ADMIN']]) {
      const headers = { authorization: bearer(id, role) };
      for (const path of [
        `/coach/members/${memberId}/progress/summary`,
        `/coach/members/${memberId}/workout-logs`,
        `/coach/members/${memberId}/meal-logs`,
        `/coach/members/${memberId}/body-measurements`,
        `/coach/members/${memberId}/progress-photos`,
        '/progress/me/charts',
      ]) {
        assert.equal((await fetch(`${base}${path}`, { headers })).status, 403);
      }
      assert.equal((await fetch(`${base}/progress-comments`, { headers })).status, 403);
      assert.equal((await fetch(`${base}/coach/progress-comments`, {
        method: 'POST', headers: { ...headers, 'content-type': 'application/json' },
        body: JSON.stringify({ memberId, content: 'Private' }),
      })).status, 403);
      for (const id of [mediaId, mealMediaId]) {
        assert.equal((await fetch(`${base}/media/images/${id}/access-url`,
          { headers })).status, 404);
      }
    }
    assert.equal((await fetch(`${base}/media/images/${mediaId}/access-url`, {
      headers: { authorization: bearer(memberId, 'MEMBER') },
    })).status, 200);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
