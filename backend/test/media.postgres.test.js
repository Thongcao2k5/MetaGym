import assert from 'node:assert/strict';
import { createHmac, randomUUID } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';
import sharp from 'sharp';

import { createApp } from '../src/app.js';
import { createLocalImageStorage } from '../src/storage/local-image-storage.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'media-integration-secret-with-32-characters';

function token(id, role = 'MEMBER') {
  return jwt.sign({ role, sessionVersion: 0 }, secret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
    subject: id, expiresIn: 3600,
  });
}

test('PostgreSQL media API validates images and issues short-lived owner URLs',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const memberId = randomUUID();
    const otherId = randomUUID();
    const coachId = randomUUID();
    const relationshipId = randomUUID();
    const storageDir = await mkdtemp(path.join(tmpdir(), 'metagym-media-'));
    const storage = createLocalImageStorage(storageDir);
    const app = createApp({ database, jwtSecret: secret, imageStorage: storage });
    const noStorage = createApp({ database, jwtSecret: secret });
    const failingStorage = createApp({ database, jwtSecret: secret,
      imageStorage: { put: async () => { throw new Error('Storage unavailable'); },
        get: storage.get } });
    const bytes = await sharp({ create: { width: 2, height: 2,
      channels: 3, background: '#00ff00' } }).png().toBuffer();
    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'MEMBER', 'Member'),
                ($3, $4, 'hash', 'MEMBER', 'Other'),
                ($5, $6, 'hash', 'COACH', 'Coach')`,
        [memberId, `${memberId}@example.com`, otherId, `${otherId}@example.com`,
          coachId, `${coachId}@example.com`],
      );
      await database.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id)
         VALUES ($1, $2, $3)`, [relationshipId, memberId, coachId],
      );
      const server = app.listen(0);
      const missingServer = noStorage.listen(0);
      const failingServer = failingStorage.listen(0);
      try {
        const base = `http://127.0.0.1:${server.address().port}`;
        const missingBase = `http://127.0.0.1:${missingServer.address().port}`;
        const failingBase = `http://127.0.0.1:${failingServer.address().port}`;
        const headers = { authorization: `Bearer ${token(memberId)}`,
          'content-type': 'image/png', 'x-image-purpose': 'PROGRESS_PHOTO' };
        let result = await fetch(`${missingBase}/api/v1/media/images`, {
          method: 'POST', headers, body: bytes,
        });
        assert.equal(result.status, 503);
        result = await fetch(`${base}/api/v1/media/images`, {
          method: 'POST', headers, body: Buffer.from('not an image'),
        });
        assert.equal(result.status, 422);
        result = await fetch(`${base}/api/v1/media/images`, {
          method: 'POST', headers, body: Buffer.alloc(5 * 1024 * 1024 + 1),
        });
        assert.equal(result.status, 413);
        assert.equal((await result.json()).error.code, 'PAYLOAD_TOO_LARGE');
        result = await fetch(`${base}/api/v1/media/images`, {
          method: 'POST', headers: { ...headers, 'x-image-purpose': 'AVATAR' }, body: bytes,
        });
        assert.equal(result.status, 422);
        result = await fetch(`${base}/api/v1/media/images`, {
          method: 'POST', headers, body: bytes,
        });
        assert.equal(result.status, 201);
        const image = (await result.json()).data;
        assert.equal(image.width, 2);
        assert.equal(image.height, 2);
        const jpeg = await sharp(bytes).jpeg().toBuffer();
        result = await fetch(`${base}/api/v1/media/images`, {
          method: 'POST', headers: { ...headers, 'content-type': 'image/jpeg' },
          body: jpeg,
        });
        assert.equal(result.status, 201);
        assert.equal((await result.json()).data.mimeType, 'image/jpeg');
        result = await fetch(`${failingBase}/api/v1/media/images`, {
          method: 'POST', headers, body: bytes,
        });
        assert.equal(result.status, 502);
        assert.equal((await result.json()).error.code, 'STORAGE_ERROR');
        assert.equal((await database.query(
          `SELECT count(*)::int AS count FROM media_assets
           WHERE owner_id = $1 AND status = 'FAILED'`, [memberId]))
          .rows[0].count, 1);
        const otherAccess = await fetch(`${base}/api/v1/media/images/${image.id}/access-url`, {
          headers: { authorization: `Bearer ${token(otherId)}` },
        });
        assert.equal(otherAccess.status, 404);
        assert.equal((await fetch(`${base}/api/v1/media/images/${image.id}/access-url`, {
          headers: { authorization: `Bearer ${token(coachId, 'COACH')}` },
        })).status, 404);
        const access = await fetch(`${base}/api/v1/media/images/${image.id}/access-url`, {
          headers: { authorization: `Bearer ${token(memberId)}` },
        });
        assert.equal(access.status, 200);
        const url = (await access.json()).data.url;
        result = await fetch(`${base}${url}`);
        assert.equal(result.status, 200);
        assert.equal(result.headers.get('content-type'), 'image/png');
        const stored = await database.query('SELECT storage_key FROM media_assets WHERE id = $1', [image.id]);
        assert.deepEqual(Buffer.from(await result.arrayBuffer()),
          await storage.get(stored.rows[0].storage_key));
        const tampered = url.replace('signature=', 'signature=0');
        assert.equal((await fetch(`${base}${tampered}`)).status, 404);
        const expired = Math.floor(Date.now() / 1000) - 1;
        const expiredSignature = createHmac('sha256', `${secret}:media-url`)
          .update(`${image.id}:${expired}`).digest('hex');
        assert.equal((await fetch(`${base}/api/v1/media/images/${image.id}` +
          `?expires=${expired}&signature=${expiredSignature}`)).status, 404);
        await database.query(
          `UPDATE coach_relationships SET status = 'ENDED', ended_at = now(),
           ended_by = $1, end_reason = 'Finished coaching' WHERE id = $2`,
          [memberId, relationshipId],
        );
        assert.equal((await fetch(`${base}/api/v1/media/images/${image.id}/access-url`, {
          headers: { authorization: `Bearer ${token(coachId, 'COACH')}` },
        })).status, 404);
        assert.equal((await fetch(`${base}/api/v1/media/images/${image.id}/access-url`, {
          headers: { authorization: `Bearer ${token(memberId)}` },
        })).status, 200);
      } finally {
        await new Promise((resolve) => server.close(resolve));
        await new Promise((resolve) => missingServer.close(resolve));
        await new Promise((resolve) => failingServer.close(resolve));
      }
    } finally {
      await database.query('DELETE FROM media_assets WHERE owner_id = $1', [memberId]);
      await database.query('DELETE FROM coach_relationships WHERE id = $1',
        [relationshipId]);
      await database.query('DELETE FROM users WHERE id IN ($1, $2, $3)',
        [memberId, otherId, coachId]);
      await database.end();
      await rm(storageDir, { recursive: true, force: true });
    }
  });
