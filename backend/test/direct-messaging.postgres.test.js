import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'direct-messaging-test-secret-32-characters';

function token(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, secret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
    subject: id, expiresIn: 3600,
  });
}

async function call(base, path, bearer, method = 'GET', body) {
  const response = await fetch(`${base}/api/v1${path}`, {
    method,
    headers: { authorization: `Bearer ${bearer}`,
      ...(body === undefined ? {} : { 'content-type': 'application/json' }) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: response.status, body: await response.json() };
}

test('Member and Coach can start one private chat without a relationship',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const server = createApp({ database, jwtSecret: secret }).listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;
    const memberId = randomUUID();
    const coachId = randomUUID();
    const strangerId = randomUUID();
    const adminId = randomUUID();
    const member = token(memberId, 'MEMBER');
    const coach = token(coachId, 'COACH');
    const stranger = token(strangerId, 'MEMBER');
    const admin = token(adminId, 'ADMIN');
    let conversationId;
    try {
      for (const [id, role] of [[memberId, 'MEMBER'], [coachId, 'COACH'],
        [strangerId, 'MEMBER'], [adminId, 'ADMIN']]) {
        await database.query(
          `INSERT INTO users (id, email, password_hash, role, full_name)
           VALUES ($1, $2, 'hash', $3, $4)`, [id, `${id}@example.com`, role, role],
        );
      }
      assert.equal((await call(base, '/conversations', admin, 'POST',
        { coachId })).status, 403);
      assert.equal((await call(base, '/conversations', member, 'POST',
        { coachId: strangerId })).status, 404);
      const started = await Promise.all(Array.from({ length: 2 }, () =>
        call(base, '/conversations', member, 'POST', { coachId })));
      assert.deepEqual(started.map((item) => item.status).sort(), [200, 201]);
      conversationId = started[0].body.data.id;
      assert.equal(started[1].body.data.id, conversationId);
      assert.equal(started[0].body.data.relationshipId, null);
      assert.equal((await call(base, '/conversations', coach, 'POST',
        { memberId })).body.data.id, conversationId);
      const path = `/conversations/${conversationId}/messages`;
      assert.equal((await call(base, path, stranger)).status, 404);
      assert.equal((await call(base, path, admin)).status, 403);
      assert.equal((await call(base, path, member, 'POST', {
        messageType: 'TEXT', clientMessageId: randomUUID(), content: 'Xin chào Coach',
      })).status, 201);
      const reply = await call(base, path, coach, 'POST', {
        messageType: 'TEXT', clientMessageId: randomUUID(), content: 'Xin chào Member',
      });
      assert.equal(reply.status, 201);
      assert.equal((await call(base, path, member)).body.data.length, 2);
      assert.equal((await call(base, '/conversations', member)).body.data[0].id,
        conversationId);
      assert.equal((await call(base, '/conversations', member)).body.data[0]
        .unreadCount, 1);
      assert.equal((await call(base,
        `/conversations/${conversationId}/read-state`, member, 'PATCH',
        { messageId: reply.body.data.id })).status, 200);
    } finally {
      if (conversationId) {
        await database.query('UPDATE conversation_participants SET last_read_message_id = NULL WHERE conversation_id = $1', [conversationId]);
        await database.query('DELETE FROM messages WHERE conversation_id = $1', [conversationId]);
        await database.query('DELETE FROM conversation_participants WHERE conversation_id = $1', [conversationId]);
        await database.query('DELETE FROM conversations WHERE id = $1', [conversationId]);
      }
      await database.query('DELETE FROM users WHERE id = ANY($1::uuid[])',
        [[memberId, coachId, strangerId, adminId]]);
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });
