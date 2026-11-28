import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import sharp from 'sharp';

import { createApp } from '../src/app.js';
import { hashApiKey } from '../src/middleware/image-server-auth.js';
import { processUploadedImage, transformImage } from '../src/services/image-processor.js';
import { assertSafeRemoteUrl, detectImageType, isBotUserAgent, sanitizeSvg } from '../src/services/image-validation.js';
import { createLocalImageStorage } from '../src/storage/local-image-storage.js';
import { assertValidStorageKey, isValidStorageKey } from '../src/storage/storage-key.js';

const JWT_SECRET = 'image-server-integration-test-secret-32chars';

test('Storage key validation accepts legacy bare UUID and folder/uuid.ext while blocking traversal', () => {
  assert.equal(isValidStorageKey('f47ac10b-58cc-4372-a567-0e02b2c3d479'), true);
  assert.equal(isValidStorageKey('original/f47ac10b-58cc-4372-a567-0e02b2c3d479.webp'), true);
  assert.equal(isValidStorageKey('thumbnails/f47ac10b-58cc-4372-a567-0e02b2c3d479.webp'), true);

  assert.equal(isValidStorageKey('../f47ac10b-58cc-4372-a567-0e02b2c3d479'), false);
  assert.equal(isValidStorageKey('original/../../secret.png'), false);
  assert.equal(isValidStorageKey('original\\f47ac10b-58cc-4372-a567-0e02b2c3d479.png'), false);
  assert.equal(isValidStorageKey('/original/f47ac10b-58cc-4372-a567-0e02b2c3d479.png'), false);
  assert.throws(() => assertValidStorageKey('original//bad'), /Invalid image storage key/);
});

test('Magic-bytes detector rejects spoofed text bytes labeled as PNG and recognizes valid formats', async () => {
  const spoofed = Buffer.from('not really a png file');
  assert.equal(detectImageType(spoofed), null);

  const realPng = await sharp({
    create: { width: 40, height: 30, channels: 3, background: { r: 255, g: 94, b: 54 } },
  }).png().toBuffer();
  assert.deepEqual(detectImageType(realPng), { mimeType: 'image/png', extension: 'png', format: 'png' });

  const realWebp = await sharp(realPng).webp().toBuffer();
  assert.deepEqual(detectImageType(realWebp), { mimeType: 'image/webp', extension: 'webp', format: 'webp' });
});

test('SVG sanitizer strips script tags, event handlers, foreignObject, and javascript URIs', () => {
  const dirtySvg = Buffer.from(
    `<!DOCTYPE svg SYSTEM "http://evil.com/xxe.dtd">
     <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" onload="alert(1)">
       <script>alert('xss')</script>
       <foreignObject><div>bad</div></foreignObject>
       <a href="javascript:alert(2)"><rect width="50" height="50" onclick="steal()" /></a>
     </svg>`,
  );
  const clean = sanitizeSvg(dirtySvg).toString('utf8');
  assert.equal(clean.includes('<script'), false);
  assert.equal(clean.includes('onload='), false);
  assert.equal(clean.includes('onclick='), false);
  assert.equal(clean.includes('foreignObject'), false);
  assert.equal(clean.includes('javascript:'), false);
  assert.equal(clean.includes('<!DOCTYPE'), false);
  assert.equal(clean.includes('<svg'), true);
});

test('SSRF URL validator blocks localhost, private IPs, and non-HTTP protocols', async () => {
  await assert.rejects(assertSafeRemoteUrl('file:///etc/passwd'), /UNSAFE_URL_PROTOCOL/);
  await assert.rejects(assertSafeRemoteUrl('http://localhost:3000/secret.png'), /UNSAFE_URL_HOST/);
  await assert.rejects(assertSafeRemoteUrl('http://127.0.0.1/img.png'), /UNSAFE_URL_HOST/);
  await assert.rejects(assertSafeRemoteUrl('http://169.254.169.254/latest/meta-data/'), /UNSAFE_URL_HOST/);
  await assert.rejects(assertSafeRemoteUrl('http://10.0.0.5/internal.png'), /UNSAFE_URL_HOST/);

  const okUrl = await assertSafeRemoteUrl('https://cdn.example.com/photo.png', {
    lookup: async () => [{ address: '93.184.216.34', family: 4 }],
  });
  assert.equal(okUrl.hostname, 'cdn.example.com');
  assert.equal(isBotUserAgent('Googlebot/2.1 (+http://www.google.com/bot.html)'), true);
  assert.equal(isBotUserAgent('Mozilla/5.0 Chrome/126.0'), false);
});

test('Sharp upload processor and non-destructive transformImage create thumbnail and edited variants', async () => {
  const pngBuffer = await sharp({
    create: { width: 800, height: 600, channels: 3, background: { r: 30, g: 40, b: 60 } },
  }).png().toBuffer();

  const processed = await processUploadedImage(pngBuffer, {
    originalFilename: 'hero.png',
    generateWebp: true,
    thumbnailSize: 300,
    quality: 80,
  });

  assert.equal(processed.width, 800);
  assert.equal(processed.height, 600);
  assert.equal(processed.sha256Hash.length, 64);
  assert.equal(processed.thumbnail.mimeType, 'image/webp');
  assert.equal(processed.thumbnail.width, 300);
  assert.equal(processed.variants.length, 1);
  assert.equal(processed.variants[0].variantType, 'webp');

  const edited = await transformImage(pngBuffer, {
    crop: { left: 100, top: 50, width: 400, height: 300 },
    rotate: 90,
    flipHorizontal: true,
    resize: { width: 200, fit: 'inside' },
    format: 'webp',
    quality: 75,
  });
  assert.equal(edited.mimeType, 'image/webp');
  assert.equal(edited.width, 200);
  assert.ok(edited.sizeBytes > 0);
});

test('Image Server HTTP endpoints: API Key auth, rate limit 429, scope 403, share link password verify, stats & settings', async (t) => {
  const tempDir = await mkdtemp(path.join(os.tmpdir(), 'metagym-img-'));
  t.after(async () => { await rm(tempDir, { recursive: true, force: true }); });
  const localStorage = createLocalImageStorage(tempDir);

  const adminId = '11111111-1111-4111-8111-111111111111';
  const imageId = '22222222-2222-4222-8222-222222222222';
  const shareToken = 'sharetokensecret123456';
  const rawApiKey = 'mg_live_testkey1234567890abcdef';
  const apiKeyHash = hashApiKey(rawApiKey);
  const sharePwHash = await bcrypt.hash('Secret99', 4);
  let rateCounter = 0;

  const samplePng = await sharp({
    create: { width: 120, height: 80, channels: 3, background: { r: 255, g: 94, b: 54 } },
  }).png().toBuffer();
  await localStorage.put(`original/${imageId}.png`, samplePng, 'image/png');

  const mockDb = {
    async connect() {
      return {
        async query(sql, params) { return mockDb.query(sql, params); },
        release() {},
      };
    },
    async query(sql, params = []) {
      const q = String(sql).replace(/\s+/g, ' ').trim();
      if (q.startsWith('SELECT u.id, u.email::text')) {
        return {
          rows: [{
            id: adminId,
            email: 'admin@metagym.local',
            full_name: 'Meta Admin',
            role: 'ADMIN',
            status: 'ACTIVE',
            session_version: 0,
          }],
        };
      }
      if (q.includes('FROM api_keys k JOIN users u')) {
        if (params[0] !== apiKeyHash) return { rows: [] };
        rateCounter += 1;
        return {
          rows: [{
            key_id: '33333333-3333-4333-8333-333333333333',
            user_id: adminId,
            key_name: 'CI Key',
            scopes: ['images:read'],
            rate_limit_per_minute: 2,
            expires_at: null,
            revoked_at: null,
            id: adminId,
            email: 'admin@metagym.local',
            full_name: 'Meta Admin',
            role: 'ADMIN',
            status: 'ACTIVE',
            storage_quota_bytes: 1073741824,
            storage_used_bytes: 1024,
            is_locked: false,
          }],
        };
      }
      if (q.includes('FROM system_settings')) {
        return { rows: [{ key: 'site_branding', value: { siteName: 'Meta Gym Test', logoUrl: '', faviconUrl: '' } }] };
      }
      if (q.includes('SELECT COUNT(*)::int AS total FROM images')) {
        return { rows: [{ total: 1 }] };
      }
      if (q.includes('FROM images i LEFT JOIN users u')) {
        return {
          rows: [{
            id: imageId,
            owner_id: adminId,
            owner_name: 'Meta Admin',
            owner_email: 'admin@metagym.local',
            folder_id: null,
            folder_name: null,
            storage_provider_id: '00000000-0000-4000-8000-000000000201',
            filename: 'banner.png',
            original_filename: 'banner.png',
            storage_key: `original/${imageId}.png`,
            extension: 'png',
            mime_type: 'image/png',
            size_bytes: samplePng.length,
            width: 120,
            height: 80,
            sha256_hash: 'a'.repeat(64),
            exif_data: { format: 'png' },
            description: 'Test banner',
            visibility: 'private',
            view_count: 3,
            download_count: 1,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
            deleted_at: null,
          }],
        };
      }
      if (q.includes('FROM image_variants WHERE image_id = ANY')) return { rows: [] };
      if (q.includes('FROM image_tags it JOIN tags t')) return { rows: [] };
      if (q.includes('FROM share_links s LEFT JOIN images i')) {
        if (params[0] !== shareToken) return { rows: [] };
        return {
          rows: [{
            id: '44444444-4444-4444-8444-444444444444',
            target_type: 'image',
            image_id: imageId,
            album_id: null,
            token: shareToken,
            password_hash: sharePwHash,
            allow_download: true,
            expires_at: null,
            revoked_at: null,
            image_filename: 'banner.png',
            mime_type: 'image/png',
            size_bytes: samplePng.length,
            width: 120,
            height: 80,
            image_deleted: null,
          }],
        };
      }
      if (q.includes('SELECT id, password_hash, expires_at, revoked_at FROM share_links')) {
        return {
          rows: [{
            id: '44444444-4444-4444-8444-444444444444',
            password_hash: sharePwHash,
            expires_at: null,
            revoked_at: null,
          }],
        };
      }
      return { rows: [] };
    },
  };

  const app = createApp({
    database: mockDb,
    jwtSecret: JWT_SECRET,
    imageStorage: localStorage,
    nodeEnv: 'test',
  });
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const { port } = server.address();
  const baseUrl = `http://127.0.0.1:${port}/api/v1`;

  // 1. API Key with images:read succeeds on GET /images
  const listRes = await fetch(`${baseUrl}/images`, { headers: { 'X-API-Key': rawApiKey } });
  assert.equal(listRes.status, 200);
  const listJson = await listRes.json();
  assert.equal(listJson.success, true);
  assert.equal(listJson.data[0].filename, 'banner.png');

  // 2. API Key lacking images:delete gets 403 INSUFFICIENT_SCOPE
  const delRes = await fetch(`${baseUrl}/images/${imageId}`, {
    method: 'DELETE',
    headers: { 'X-API-Key': rawApiKey },
  });
  assert.equal(delRes.status, 403);
  const delJson = await delRes.json();
  assert.equal(delJson.error.code, 'INSUFFICIENT_SCOPE');

  // 3. Third request within minute exceeds rate_limit_per_minute=2 -> 429 RATE_LIMITED
  const rateRes = await fetch(`${baseUrl}/images`, { headers: { 'X-API-Key': rawApiKey } });
  assert.equal(rateRes.status, 429);
  assert.ok(rateCounter >= 2);

  // 4. Password-protected public share link prompts for password first, then verifies
  const sharePrompt = await fetch(`${baseUrl}/public/shares/${shareToken}`);
  assert.equal(sharePrompt.status, 200);
  const promptJson = await sharePrompt.json();
  assert.equal(promptJson.data.requiresPassword, true);
  assert.equal(promptJson.data.image, undefined);

  const wrongPw = await fetch(`${baseUrl}/public/shares/${shareToken}/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ password: 'WrongPassword' }),
  });
  assert.equal(wrongPw.status, 401);

  const okPw = await fetch(`${baseUrl}/public/shares/${shareToken}/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ password: 'Secret99' }),
  });
  assert.equal(okPw.status, 200);
  const { data: { accessToken } } = await okPw.json();
  assert.ok(accessToken);

  const unlockedShare = await fetch(`${baseUrl}/public/shares/${shareToken}`, {
    headers: { 'x-share-access-token': accessToken },
  });
  assert.equal(unlockedShare.status, 200);
  const unlockedJson = await unlockedShare.json();
  assert.equal(unlockedJson.data.requiresPassword, false);
  assert.equal(unlockedJson.data.image.filename, 'banner.png');

  // 5. JWT Admin settings read
  const adminJwt = jwt.sign({ sub: adminId, role: 'ADMIN', sessionVersion: 0 }, JWT_SECRET, {
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    expiresIn: '1h',
  });
  const settingsRes = await fetch(`${baseUrl}/admin/settings`, {
    headers: { Authorization: `Bearer ${adminJwt}` },
  });
  assert.equal(settingsRes.status, 200);
  const settingsJson = await settingsRes.json();
  assert.equal(settingsJson.data.site_branding.siteName, 'Meta Gym Test');
});
