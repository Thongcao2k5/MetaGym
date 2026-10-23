import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'messaging-integration-secret-32-characters';

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

test('PostgreSQL messaging enforces participants, retries, media and relationship state',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const app = createApp({ database, jwtSecret: secret });
    const server = app.listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;
    const memberId = randomUUID();
    const coachId = randomUUID();
    const outsiderId = randomUUID();
    const adminId = randomUUID();
    const relationshipId = randomUUID();
    const conversationId = randomUUID();
    const imageId = randomUUID();
    const foreignImageId = randomUUID();
    const pendingImageId = randomUUID();
    const member = token(memberId, 'MEMBER');
    const coach = token(coachId, 'COACH');
    const outsider = token(outsiderId, 'MEMBER');
    const admin = token(adminId, 'ADMIN');
    try {
      for (const [id, role] of [[memberId, 'MEMBER'], [coachId, 'COACH'],
        [outsiderId, 'MEMBER'], [adminId, 'ADMIN']]) {
        await database.query(
          `INSERT INTO users (id, email, password_hash, role, full_name)
           VALUES ($1, $2, 'hash', $3, $4)`,
          [id, `${id}@example.com`, role, role],
        );
      }
      await database.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id)
         VALUES ($1, $2, $3)`, [relationshipId, memberId, coachId],
      );
      await database.query(
        'INSERT INTO conversations (id, relationship_id) VALUES ($1, $2)',
        [conversationId, relationshipId],
      );
      await database.query(
        `INSERT INTO conversation_participants (conversation_id, user_id)
         VALUES ($1, $2), ($1, $3)`, [conversationId, memberId, coachId],
      );
      await database.query(
        `INSERT INTO media_assets
         (id, owner_id, purpose, access_scope, storage_key, original_name,
          expires_at, status, mime_type, size_bytes, width, height, ready_at)
         VALUES ($1, $2, 'MESSAGE', 'PRIVATE', $3, 'message.png',
                 now() + interval '15 minutes', 'READY', 'image/png', 10, 2, 2, now()),
                ($4, $5, 'MESSAGE', 'PRIVATE', $6, 'other.png',
                 now() + interval '15 minutes', 'READY', 'image/png', 10, 2, 2, now())`,
        [imageId, memberId, randomUUID(), foreignImageId, outsiderId, randomUUID()],
      );
      await database.query(
        `INSERT INTO media_assets
         (id, owner_id, purpose, access_scope, storage_key, original_name, expires_at)
         VALUES ($1, $2, 'MESSAGE', 'PRIVATE', $3, 'pending.png',
                 now() + interval '15 minutes')`,
        [pendingImageId, memberId, randomUUID()],
      );

      const messagesPath = `/conversations/${relationshipId}/messages`;
      const readPath = `/conversations/${relationshipId}/read-state`;
      assert.equal((await call(base, messagesPath, outsider)).status, 404);
      assert.equal((await call(base, messagesPath, admin)).status, 403);
      assert.equal((await call(base, '/conversations', admin)).status, 403);
      const firstPayload = { messageType: 'TEXT', clientMessageId: randomUUID(),
        content: 'Hello Coach' };
      const first = await Promise.all(Array.from({ length: 2 }, () =>
        call(base, messagesPath, member, 'POST', firstPayload)));
      assert.deepEqual(first.map((item) => item.status).sort(), [200, 201]);
      assert.equal(first[0].body.data.id, first[1].body.data.id);
      const firstId = first[0].body.data.id;
      assert.equal((await database.query(
        `SELECT count(*)::int AS count FROM messages
         WHERE sender_id = $1 AND client_message_id = $2`,
        [memberId, firstPayload.clientMessageId])).rows[0].count, 1);
      assert.equal((await call(base, messagesPath, member, 'POST',
        { ...firstPayload, content: 'Changed' })).body.error.code,
      'MESSAGE_ID_CONFLICT');
      assert.equal((await call(base, '/conversations', coach)).body.data[0]
        .unreadCount, 1);

      const reply = await call(base, messagesPath, coach, 'POST', {
        messageType: 'TEXT', clientMessageId: randomUUID(), content: 'Hi Member',
      });
      assert.equal(reply.status, 201);
      for (const mediaId of [foreignImageId, pendingImageId]) {
        assert.equal((await call(base, messagesPath, member, 'POST', {
          messageType: 'IMAGE', clientMessageId: randomUUID(), mediaId,
        })).status, 422);
      }
      const image = await call(base, messagesPath, member, 'POST', {
        messageType: 'IMAGE', clientMessageId: randomUUID(), mediaId: imageId,
      });
      assert.equal(image.status, 201);
      assert.equal(image.body.data.mediaId, imageId);
      assert.equal((await call(base, '/conversations', member)).body.data[0]
        .unreadCount, 1);
      assert.equal((await call(base, readPath, member, 'PATCH',
        { messageId: image.body.data.id })).status, 422);
      assert.equal((await call(base, '/conversations', member)).body.data[0]
        .unreadCount, 1);
      const pages = await Promise.all([1, 2].map((page) =>
        call(base, `${messagesPath}?page=${page}&pageSize=2`, member)));
      assert.deepEqual(pages.map((item) => item.body.data.length), [2, 1]);
      assert.equal(pages[0].body.pagination.totalItems, 3);
      assert.equal(new Set(pages.flatMap((item) => item.body.data.map(
        (entry) => entry.id))).size, 3);
      assert.equal((await call(base, `${messagesPath}?page=0`, member)).status, 422);
      assert.equal((await call(base, readPath, outsider, 'PATCH',
        { messageId: firstId })).status, 404);
      assert.equal((await call(base, readPath, member, 'PATCH',
        { messageId: randomUUID() })).status, 404);
      assert.equal((await call(base, readPath, coach, 'PATCH',
        { messageId: image.body.data.id })).body.data.lastReadMessageId,
      image.body.data.id);
      assert.equal((await call(base, readPath, coach, 'PATCH',
        { messageId: firstId })).body.data.lastReadMessageId,
      image.body.data.id);
      assert.equal((await call(base, '/conversations', coach)).body.data[0]
        .unreadCount, 0);

      await database.query(
        `UPDATE coach_relationships SET status = 'PAUSED', paused_at = now(),
         pause_reason = 'MEMBERSHIP_EXPIRED' WHERE id = $1`, [relationshipId],
      );
      assert.equal((await call(base, messagesPath, member)).status, 200);
      assert.equal((await call(base, messagesPath, member, 'POST', {
        messageType: 'TEXT', clientMessageId: randomUUID(), content: 'Paused',
      })).body.error.code, 'RELATIONSHIP_INACTIVE');
      await database.query(
        `UPDATE coach_relationships SET status = 'ACTIVE', paused_at = NULL,
         pause_reason = NULL WHERE id = $1`, [relationshipId],
      );

      const locked = await database.connect();
      let lateSend;
      let settledWhileLocked;
      try {
        await locked.query('BEGIN');
        await locked.query(
          `UPDATE coach_relationships SET status = 'ENDED', ended_at = now(),
           ended_by = $1, end_reason = 'Finished' WHERE id = $2`,
          [memberId, relationshipId],
        );
        lateSend = call(base, messagesPath, member, 'POST', {
          messageType: 'TEXT', clientMessageId: randomUUID(), content: 'Too late',
        });
        settledWhileLocked = await Promise.race([
          lateSend.then(() => true),
          new Promise((resolve) => setTimeout(() => resolve(false), 100)),
        ]);
        await locked.query('COMMIT');
      } catch (error) {
        await locked.query('ROLLBACK').catch(() => {});
        throw error;
      } finally { locked.release(); }
      assert.equal(settledWhileLocked, false,
        'Sending must wait for the relationship state transaction');
      assert.equal((await lateSend).body.error.code, 'RELATIONSHIP_INACTIVE');
      assert.equal((await call(base, messagesPath, coach)).status, 200);
      assert.equal((await call(base, messagesPath, coach, 'POST', {
        messageType: 'TEXT', clientMessageId: randomUUID(), content: 'Ended',
      })).status, 403);
    } finally {
      await database.query(
        `UPDATE conversation_participants SET last_read_message_id = NULL
         WHERE conversation_id = $1`, [conversationId],
      );
      await database.query('DELETE FROM messages WHERE conversation_id = $1',
        [conversationId]);
      await database.query(
        'DELETE FROM conversation_participants WHERE conversation_id = $1',
        [conversationId]);
      await database.query('DELETE FROM conversations WHERE id = $1',
        [conversationId]);
      await database.query('DELETE FROM coach_relationships WHERE id = $1',
        [relationshipId]);
      await database.query(
        'DELETE FROM media_assets WHERE id IN ($1, $2, $3)',
        [imageId, foreignImageId, pendingImageId],
      );
      await database.query(
        'DELETE FROM users WHERE id IN ($1, $2, $3, $4)',
        [memberId, coachId, outsiderId, adminId],
      );
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });
