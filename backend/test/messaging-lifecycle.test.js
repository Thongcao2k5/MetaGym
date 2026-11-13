import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';

import { createApp } from '../src/app.js';

const secret = 'messaging-lifecycle-test-secret-32-characters';

function token(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, secret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
    subject: id, expiresIn: 3600,
  });
}

test('existing Member–Coach chat accepts messages while paused and ended', async () => {
  const memberId = randomUUID();
  const coachId = randomUUID();
  const relationshipId = randomUUID();
  const conversationId = randomUUID();
  let status = 'PAUSED';
  const messages = [];
  const client = {
    async query(sql, values) {
      if (sql.includes('FROM conversations c LEFT JOIN coach_relationships r')) {
        return { rows: [{ id: conversationId, relationship_id: relationshipId,
          status, member_id: memberId, coach_id: coachId }] };
      }
      if (sql.includes('FROM messages m') && sql.includes('client_message_id')) {
        return { rows: messages.filter((item) => item.sender_id === values[0] &&
          item.client_message_id === values[1]) };
      }
      if (sql.includes('INSERT INTO messages')) {
        const row = { id: values[0], conversation_id: values[1], sender_id: values[2],
          client_message_id: values[3], message_type: values[4], content: values[5],
          media_id: values[6], relationship_id: values[7], sent_at: new Date() };
        messages.push(row);
        return { rows: [row] };
      }
      return { rows: [] };
    },
    release() {},
  };
  const database = {
    async query(sql, values) {
      if (sql.includes('FROM users u')) {
        const id = values[0];
        if (id === memberId || id === coachId) return { rows: [{
          id, role: id === memberId ? 'MEMBER' : 'COACH',
          status: 'ACTIVE', session_version: 0,
        }] };
      }
      return { rows: [] };
    },
    async connect() { return client; },
  };
  const server = createApp({ database, jwtSecret: secret }).listen(0);
  try {
    const url = `http://127.0.0.1:${server.address().port}/api/v1/conversations/` +
      `${relationshipId}/messages`;
    for (const [state, id, role] of [
      ['PAUSED', memberId, 'MEMBER'], ['ENDED', coachId, 'COACH'],
    ]) {
      status = state;
      const result = await fetch(url, {
        method: 'POST', headers: { authorization: `Bearer ${token(id, role)}`,
          'content-type': 'application/json' },
        body: JSON.stringify({ messageType: 'TEXT', clientMessageId: randomUUID(),
          content: `Message during ${state}` }),
      });
      assert.equal(result.status, 201, await result.text());
    }
    assert.equal(messages.length, 2);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
