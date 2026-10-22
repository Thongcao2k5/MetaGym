import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
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

function token(id) {
  return jwt.sign({ role: 'MEMBER', sessionVersion: 0 }, secret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
    subject: id, expiresIn: 3600,
  });
}

test('PostgreSQL media API validates images and issues short-lived owner URLs',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const memberId = randomUUID();
    const otherId = randomUUID();
    const storageDir = await mkdtemp(path.join(tmpdir(), 'metagym-media-'));
    const storage = createLocalImageStorage(storageDir);
    const app = createApp({ database, jwtSecret: secret, imageStorage: storage });
    const noStorage = createApp({ database, jwtSecret: secret });
    const bytes = await sharp({ create: { width: 2, height: 2,
      channels: 3, background: '#00ff00' } }).png().toBuffer();
    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'MEMBER', 'Member'),
                ($3, $4, 'hash', 'MEMBER', 'Other')`,
        [memberId, `${memberId}@example.com`, otherId, `${otherId}@example.com`],
      );
      const server = app.listen(0);
      const missingServer = noStorage.listen(0);
      try {
        const base = `http://127.0.0.1:${server.address().port}`;
        const missingBase = `http://127.0.0.1:${missingServer.address().port}`;
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
          method: 'POST', headers, body: bytes,
        });
        assert.equal(result.status, 201);
        const image = (await result.json()).data;
        assert.equal(image.width, 2);
        assert.equal(image.height, 2);
        const otherAccess = await fetch(`${base}/api/v1/media/images/${image.id}/access-url`, {
          headers: { authorization: `Bearer ${token(otherId)}` },
        });
        assert.equal(otherAccess.status, 404);
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
      } finally {
        await new Promise((resolve) => server.close(resolve));
        await new Promise((resolve) => missingServer.close(resolve));
      }
    } finally {
      await database.query('DELETE FROM media_assets WHERE owner_id = $1', [memberId]);
      await database.query('DELETE FROM users WHERE id IN ($1, $2)', [memberId, otherId]);
      await database.end();
      await rm(storageDir, { recursive: true, force: true });
    }
  });
