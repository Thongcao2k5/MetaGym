import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import sharp from 'sharp';

import { createApp } from '../src/app.js';
import { DEFAULT_SYSTEM_INFO } from '../src/modules/system/system-info-defaults.js';
import { isSecondaryVariantKey } from '../src/modules/media/supabase-sync.js';
import { buildSystemIconStorageKeys, resolveThumbKeys } from '../src/storage/storage-key.js';

const SECRET = 'system-info-test-secret-with-32-characters';

function tokenFor(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, SECRET, {
    algorithm: 'HS256',
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    subject: id,
    expiresIn: 3600,
  });
}

test('System info endpoints enforce ADMIN access, manage 4 configs, and clean up replaced SYSTEM_ICON media', async () => {
  const adminId = randomUUID();
  const memberId = randomUUID();
  const oldIconMediaId = randomUUID();
  const oldKey = `system/icons/${oldIconMediaId}.webp`;
  const oldThumbKey = `system/icons/thumbs/${oldIconMediaId}.webp`;

  assert.deepEqual(buildSystemIconStorageKeys(oldIconMediaId), {
    storageKey: oldKey,
    thumbKey: oldThumbKey,
  });
  assert.deepEqual(resolveThumbKeys(oldKey), [oldThumbKey]);
  assert.equal(isSecondaryVariantKey(oldThumbKey), true);

  const stored = new Map([
    [oldKey, { bytes: Buffer.from('old-icon'), contentType: 'image/webp' }],
    [oldThumbKey, { bytes: Buffer.from('old-icon-thumb'), contentType: 'image/webp' }],
  ]);
  const removedKeys = [];
  const deletedMediaIds = [];
  const auditLogs = [];

  const settings = new Map([
    ['legal_privacy_policy', { value: DEFAULT_SYSTEM_INFO.legal_privacy_policy, updated_at: '2026-11-28T00:00:00.000Z' }],
    ['legal_terms_of_service', { value: DEFAULT_SYSTEM_INFO.legal_terms_of_service, updated_at: '2026-11-28T00:00:00.000Z' }],
    ['home_quick_icons', {
      value: {
        items: [
          { ...DEFAULT_SYSTEM_INFO.home_quick_icons.items[0], mediaId: oldIconMediaId },
          { ...DEFAULT_SYSTEM_INFO.home_quick_icons.items[1], enabled: false },
        ],
      },
      updated_at: '2026-11-28T00:00:00.000Z',
    }],
    ['payment_methods', {
      value: {
        methods: [
          DEFAULT_SYSTEM_INFO.payment_methods.methods[0],
          { ...DEFAULT_SYSTEM_INFO.payment_methods.methods[4], enabled: false },
        ],
      },
      updated_at: '2026-11-28T00:00:00.000Z',
    }],
  ]);

  const mediaRows = new Map([
    [oldIconMediaId, {
      id: oldIconMediaId,
      owner_id: adminId,
      purpose: 'SYSTEM_ICON',
      access_scope: 'PUBLIC',
      storage_key: oldKey,
      mime_type: 'image/webp',
      status: 'READY',
    }],
  ]);

  const runQuery = async (sql, params = []) => {
    const text = String(sql).replace(/\s+/g, ' ').trim();
    if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(text) || text.startsWith('SAVEPOINT') || text.startsWith('RELEASE SAVEPOINT') || text.startsWith('ROLLBACK TO SAVEPOINT')) {
      return { rows: [], rowCount: 0 };
    }
    if (text.includes('FROM users u') && text.includes('WHERE u.id = $1')) {
      const id = params[0];
      const role = id === adminId ? 'ADMIN' : 'MEMBER';
      return {
        rows: [{ id, email: `${role}@metagym.vn`, full_name: role, phone: null, role, status: 'ACTIVE', avatar_media_id: null, session_version: 0 }],
      };
    }
    if (text.includes('SELECT id FROM users WHERE id = $1 AND role = \'ADMIN\'')) {
      return { rows: [{ id: adminId }] };
    }
    if (text.includes('FROM system_settings WHERE key = ANY')) {
      const rows = [];
      for (const k of params[0]) {
        const entry = settings.get(k);
        if (entry) rows.push({ key: k, value: entry.value, updated_at: entry.updated_at });
      }
      return { rows };
    }
    if (text.startsWith('SELECT value FROM system_settings WHERE key = $1')) {
      const entry = settings.get(params[0]);
      return { rows: entry ? [{ value: entry.value }] : [] };
    }
    if (text.startsWith('INSERT INTO system_settings')) {
      const [key, jsonStr] = params;
      const value = JSON.parse(jsonStr);
      const updated_at = new Date().toISOString();
      settings.set(key, { value, updated_at });
      return { rows: [{ value, updated_at }], rowCount: 1 };
    }
    if (text.includes('INSERT INTO media_assets')) {
      const [id, ownerId, purpose, accessScope, storageKey] = params;
      mediaRows.set(id, { id, owner_id: ownerId, purpose, access_scope: accessScope, storage_key: storageKey, status: 'UPLOADING' });
      return { rows: [], rowCount: 1 };
    }
    if (text.includes('UPDATE media_assets SET status = \'READY\'')) {
      const [mimeType, sizeBytes, width, height, id] = params;
      const item = mediaRows.get(id);
      if (item) Object.assign(item, { status: 'READY', mime_type: mimeType, size_bytes: sizeBytes, width, height });
      return { rows: [], rowCount: 1 };
    }
    if (text.startsWith('SELECT id FROM media_assets WHERE id = ANY')) {
      const validIds = (params[0] || []).filter((id) => {
        const m = mediaRows.get(id);
        return m && m.status === 'READY' && m.access_scope === 'PUBLIC' && m.purpose === 'SYSTEM_ICON';
      });
      return { rows: validIds.map((id) => ({ id })) };
    }
    if (text.startsWith('SELECT id, storage_key, purpose FROM media_assets WHERE id = $1')) {
      const m = mediaRows.get(params[0]);
      return { rows: m && m.purpose === params[1] ? [m] : [] };
    }
    if (text.startsWith('DELETE FROM images WHERE storage_key = $1')) {
      return { rows: [], rowCount: 1 };
    }
    if (text.startsWith('DELETE FROM media_assets WHERE id = $1')) {
      deletedMediaIds.push(params[0]);
      mediaRows.delete(params[0]);
      return { rows: [], rowCount: 1 };
    }
    if (text.includes('INSERT INTO admin_audit_logs')) {
      auditLogs.push({
        action: text.includes("'SYSTEM_INFO_UPDATED'") ? 'SYSTEM_INFO_UPDATED' : params[2],
        key: params[2],
        summary: params[3],
      });
      return { rows: [], rowCount: 1 };
    }
    return { rows: [] };
  };

  const app = createApp({
    database: { query: runQuery, connect: async () => ({ query: runQuery, release() {} }) },
    jwtSecret: SECRET,
    imageStorage: {
      async put(key, bytes, contentType) { stored.set(key, { bytes, contentType }); },
      async get(key) {
        const v = stored.get(key);
        if (!v) throw new Error('ENOENT');
        return v.bytes;
      },
      async remove(key) {
        removedKeys.push(key);
        stored.delete(key);
      },
    },
  });

  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  const admBearer = tokenFor(adminId, 'ADMIN');
  const memBearer = tokenFor(memberId, 'MEMBER');

  try {
    // Public endpoints filter out disabled items
    const pubIcons = await (await fetch(`${base}/api/v1/system-info/home-icons`)).json();
    assert.equal(pubIcons.data.items.length, 1);
    const pubPay = await (await fetch(`${base}/api/v1/system-info/payment-methods`)).json();
    assert.equal(pubPay.data.methods.length, 1);

    // Member blocked from Admin endpoint
    const forbid = await fetch(`${base}/api/v1/admin/system-info`, {
      headers: { authorization: `Bearer ${memBearer}` },
    });
    assert.equal(forbid.status, 403);

    // Admin updates Privacy Policy
    const putPrivacy = await fetch(`${base}/api/v1/admin/system-info/privacy-policy`, {
      method: 'PUT',
      headers: { authorization: `Bearer ${admBearer}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        ...DEFAULT_SYSTEM_INFO.legal_privacy_policy,
        version: '2.0',
      }),
    });
    assert.equal(putPrivacy.status, 200);
    assert.equal((await putPrivacy.json()).data.version, '2.0');

    // Admin updates Terms of Use
    const putTerms = await fetch(`${base}/api/v1/admin/system-info/terms-of-use`, {
      method: 'PUT',
      headers: { authorization: `Bearer ${admBearer}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        ...DEFAULT_SYSTEM_INFO.legal_terms_of_service,
        version: '1.5',
      }),
    });
    assert.equal(putTerms.status, 200);

    // Upload new SYSTEM_ICON WebP and replace old icon -> cleans DB + Storage
    const pngBytes = await sharp({
      create: { width: 128, height: 128, channels: 4, background: { r: 255, g: 94, b: 54, alpha: 1 } },
    }).png().toBuffer();
    const uploadIcon = await fetch(`${base}/api/v1/media/images`, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${admBearer}`,
        'content-type': 'image/png',
        'x-image-purpose': 'SYSTEM_ICON',
        'x-file-name': 'schedule-3d.png',
      },
      body: pngBytes,
    });
    assert.equal(uploadIcon.status, 201);
    const newIconId = (await uploadIcon.json()).data.id;
    assert.ok(stored.has(`system/icons/${newIconId}.webp`));

    const putIcons = await fetch(`${base}/api/v1/admin/system-info/home-icons`, {
      method: 'PUT',
      headers: { authorization: `Bearer ${admBearer}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        items: [{ ...DEFAULT_SYSTEM_INFO.home_quick_icons.items[0], mediaId: newIconId }],
      }),
    });
    assert.equal(putIcons.status, 200);
    assert.equal(deletedMediaIds.includes(oldIconMediaId), true);
    assert.equal(removedKeys.includes(oldKey), true);
    assert.equal(removedKeys.includes(oldThumbKey), true);

    // Payment method invalid range rejected 422, valid saved 200
    const badPay = await fetch(`${base}/api/v1/admin/system-info/payment-methods`, {
      method: 'PUT',
      headers: { authorization: `Bearer ${admBearer}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        methods: [{ ...DEFAULT_SYSTEM_INFO.payment_methods.methods[0], minAmount: 500000, maxAmount: 100000 }],
      }),
    });
    assert.equal(badPay.status, 422);

    const goodPay = await fetch(`${base}/api/v1/admin/system-info/payment-methods`, {
      method: 'PUT',
      headers: { authorization: `Bearer ${admBearer}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        methods: [DEFAULT_SYSTEM_INFO.payment_methods.methods[0]],
      }),
    });
    assert.equal(goodPay.status, 200);
    assert.equal(auditLogs.filter((l) => l.action === 'SYSTEM_INFO_UPDATED').length, 4);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
