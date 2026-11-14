import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';
import sharp from 'sharp';

import { createApp } from '../src/app.js';
import { createImageStorageFromEnv } from '../src/storage/image-storage.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const hasSupabase = ['SUPABASE_URL', 'SUPABASE_SECRET_KEY',
  'SUPABASE_STORAGE_BUCKET'].every((name) => process.env[name]);
const secret = 'supabase-media-integration-secret-32-chars';

test('media API stores and serves a private image through Supabase Storage',
  { skip: !databaseUrl || !hasSupabase }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const imageStorage = createImageStorageFromEnv(process.env);
    const memberId = randomUUID();
    let storageKey;
    const app = createApp({ database, jwtSecret: secret, imageStorage });
    const server = app.listen(0);
    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'MEMBER', 'Supabase Media Test')`,
        [memberId, `${memberId}@example.com`],
      );
      const token = jwt.sign({ role: 'MEMBER', sessionVersion: 0 }, secret, {
        algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
        subject: memberId, expiresIn: 3600,
      });
      const bytes = await sharp({ create: { width: 3, height: 2,
        channels: 3, background: '#ff5e3a' } }).png().toBuffer();
      const base = `http://127.0.0.1:${server.address().port}`;
      let response = await fetch(`${base}/api/v1/media/images`, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${token}`,
          'content-type': 'image/png',
          'x-image-purpose': 'PROGRESS_PHOTO',
          'x-file-name': 'supabase-integration.png',
        },
        body: bytes,
      });
      assert.equal(response.status, 201);
      const media = (await response.json()).data;
      const stored = await database.query(
        'SELECT storage_key FROM media_assets WHERE id = $1', [media.id],
      );
      storageKey = stored.rows[0].storage_key;

      response = await fetch(`${base}/api/v1/media/images/${media.id}/access-url`, {
        headers: { authorization: `Bearer ${token}` },
      });
      assert.equal(response.status, 200);
      const { url } = (await response.json()).data;
      response = await fetch(`${base}${url}`);
      assert.equal(response.status, 200);
      assert.equal(response.headers.get('content-type'), 'image/png');
      assert.deepEqual(Buffer.from(await response.arrayBuffer()),
        await imageStorage.get(storageKey));
    } finally {
      await new Promise((resolve) => server.close(resolve));
      if (storageKey) await imageStorage.remove(storageKey).catch(() => {});
      await database.query('DELETE FROM media_assets WHERE owner_id = $1',
        [memberId]).catch(() => {});
      await database.query('DELETE FROM users WHERE id = $1',
        [memberId]).catch(() => {});
      await database.end();
    }
  });
