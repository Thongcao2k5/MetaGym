import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import sharp from 'sharp';

import { createApp } from '../src/app.js';
import { createLocalImageStorage } from '../src/storage/local-image-storage.js';

const SECRET = 'equipment-icon-test-secret-32-chars!';

function tokenFor(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, SECRET, {
    algorithm: 'HS256',
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    subject: id,
    expiresIn: 3600,
  });
}

function createFakeEquipmentDb({ adminId }) {
  const mediaAssets = new Map();
  const equipment = new Map();

  async function runQuery(sql, params = []) {
    const q = String(sql).replace(/\s+/g, ' ').trim();

    if (q.startsWith('BEGIN') || q.startsWith('COMMIT') || q.startsWith('ROLLBACK')
      || q.startsWith('SAVEPOINT') || q.startsWith('RELEASE SAVEPOINT')
      || q.startsWith('ROLLBACK TO SAVEPOINT')) {
      return { rows: [], rowCount: 0 };
    }

    if (q.includes('FROM users u') && q.includes('WHERE u.id = $1')) {
      const id = params[0];
      if (id === adminId) {
        return { rows: [{ id, email: 'admin@metagym.vn', full_name: 'Admin', role: 'ADMIN', status: 'ACTIVE', session_version: 0 }] };
      }
      return { rows: [] };
    }

    if (q.includes('SELECT u.id FROM users u') && q.includes('FOR SHARE')) {
      return params[0] === adminId ? { rows: [{ id: adminId }], rowCount: 1 } : { rows: [], rowCount: 0 };
    }

    if (q.startsWith('INSERT INTO media_assets')) {
      const [id, ownerId, purpose, accessScope, storageKey, originalName] = params;
      mediaAssets.set(id, {
        id,
        owner_id: ownerId,
        purpose,
        access_scope: accessScope,
        storage_key: storageKey,
        original_name: originalName,
        mime_type: null,
        size_bytes: null,
        status: 'UPLOADING',
      });
      return { rows: [], rowCount: 1 };
    }

    if (q.startsWith("UPDATE media_assets SET status = 'READY'")) {
      const [mimeType, sizeBytes, width, height, id] = params;
      const row = mediaAssets.get(id);
      if (row) {
        row.status = 'READY';
        row.mime_type = mimeType;
        row.size_bytes = sizeBytes;
        row.width = width;
        row.height = height;
      }
      return { rows: [], rowCount: row ? 1 : 0 };
    }

    if (q.startsWith('SELECT id FROM media_assets WHERE id = $1')) {
      const [id, purpose] = params;
      const row = mediaAssets.get(id);
      if (row && row.status === 'READY' && row.access_scope === 'PUBLIC' && row.purpose === purpose) {
        return { rows: [{ id: row.id }], rowCount: 1 };
      }
      return { rows: [], rowCount: 0 };
    }

    if (q.startsWith('SELECT id, storage_key, purpose FROM media_assets WHERE id = $1')) {
      const [id, purpose] = params;
      const row = mediaAssets.get(id);
      if (row && (!purpose || row.purpose === purpose)) return { rows: [row], rowCount: 1 };
      return { rows: [], rowCount: 0 };
    }

    if (q.startsWith('DELETE FROM images WHERE storage_key = $1')) return { rows: [], rowCount: 0 };

    if (q.startsWith('DELETE FROM media_assets WHERE id = $1')) {
      mediaAssets.delete(params[0]);
      return { rows: [], rowCount: 1 };
    }

    if (q.startsWith('INSERT INTO equipment')) {
      const colMatch = /\(([^)]+)\)\s+VALUES/i.exec(q);
      const cols = colMatch[1].split(',').map((s) => s.trim());
      const row = {
        id: params[0],
        created_by: params[1],
        name: null,
        category: null,
        target_muscles: [],
        image_media_id: null,
        icon_key: null,
        icon_media_id: null,
        description: null,
        usage_steps: '[]',
        safety_notes: null,
        video_url: null,
        status: 'ACTIVE',
      };
      cols.forEach((col, i) => {
        row[col] = params[i];
      });
      equipment.set(row.id, {
        ...row,
        usage_steps: typeof row.usage_steps === 'string' ? JSON.parse(row.usage_steps) : row.usage_steps,
      });
      return { rows: [], rowCount: 1 };
    }

    if (q.startsWith('SELECT id FROM equipment WHERE id = $1 FOR UPDATE')) {
      const row = equipment.get(params[0]);
      return row ? { rows: [{ id: row.id }], rowCount: 1 } : { rows: [], rowCount: 0 };
    }

    if (q.startsWith('SELECT 1 FROM equipment WHERE')) {
      const [mId, eqId] = params;
      const col = q.includes('icon_media_id') ? 'icon_media_id' : 'image_media_id';
      const found = [...equipment.values()].some((r) => r[col] === mId && r.id !== eqId);
      return { rows: found ? [{ '?column?': 1 }] : [], rowCount: found ? 1 : 0 };
    }

    if (q.startsWith('UPDATE equipment SET')) {
      const setPart = q.slice('UPDATE equipment SET'.length, q.lastIndexOf('WHERE id ='));
      const assignments = setPart.split(',').map((s) => s.trim());
      const id = params.at(-1);
      const row = equipment.get(id);
      if (row) {
        assignments.forEach((assign, idx) => {
          const col = assign.split('=')[0].trim();
          const val = params[idx];
          row[col] = col === 'usage_steps' && typeof val === 'string' ? JSON.parse(val) : val;
        });
      }
      return { rows: [], rowCount: row ? 1 : 0 };
    }

    if (q.startsWith('SELECT * FROM equipment WHERE id = $1')) {
      const row = equipment.get(params[0]);
      if (!row) return { rows: [], rowCount: 0 };
      if (q.includes("status = 'ACTIVE'") && row.status !== 'ACTIVE') return { rows: [], rowCount: 0 };
      return { rows: [row], rowCount: 1 };
    }

    if (q.startsWith('SELECT count(*)::int AS count FROM equipment')) {
      const list = [...equipment.values()].filter((r) => !q.includes("status = 'ACTIVE'") || r.status === 'ACTIVE');
      return { rows: [{ count: list.length }], rowCount: 1 };
    }

    if (q.startsWith('SELECT * FROM equipment')) {
      const list = [...equipment.values()].filter((r) => !q.includes("status = 'ACTIVE'") || r.status === 'ACTIVE');
      return { rows: list, rowCount: list.length };
    }

    return { rows: [], rowCount: 0 };
  }

  return {
    mediaAssets,
    equipment,
    async query(sql, params) {
      return runQuery(sql, params);
    },
    async connect() {
      return { query: runQuery, release() {} };
    },
  };
}

test('Equipment supports iconKey, SYSTEM_ICON WebP upload, public iconUrl, and DB+Storage cleanup on removal', async () => {
  const storageDir = await mkdtemp(path.join(os.tmpdir(), 'metagym-eq-icon-test-'));
  const imageStorage = createLocalImageStorage(storageDir);
  const adminId = randomUUID();
  const database = createFakeEquipmentDb({ adminId });

  const app = createApp({ database, jwtSecret: SECRET, imageStorage });
  const server = app.listen(0);
  const baseUrl = `http://127.0.0.1:${server.address().port}/api/v1`;

  try {
    const adminToken = tokenFor(adminId, 'ADMIN');

    // 1. Upload SYSTEM_ICON (WebP compressed + 240px thumbnail in system/icons/)
    const pngBytes = await sharp({
      create: { width: 128, height: 128, channels: 4, background: { r: 255, g: 94, b: 54, alpha: 1 } },
    }).png().toBuffer();

    const upRes = await fetch(`${baseUrl}/media/images`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'Content-Type': 'image/png',
        'x-image-purpose': 'SYSTEM_ICON',
        'x-file-name': 'treadmill-icon.png',
      },
      body: pngBytes,
    });
    assert.equal(upRes.status, 201);
    const iconMediaId = (await upRes.json()).data.id;

    const storedBefore = await imageStorage.list('system/icons/');
    assert.equal(storedBefore.includes(`system/icons/${iconMediaId}.webp`), true);
    assert.equal(storedBefore.includes(`system/icons/thumbs/${iconMediaId}.webp`), true);

    // 2. Create equipment with iconKey + iconMediaId
    const createRes = await fetch(`${baseUrl}/admin/equipment`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        name: 'Máy chạy bộ Technogym',
        category: 'Cardio',
        targetMuscles: ['Chân', 'Tim mạch'],
        usageSteps: ['Khởi động 5 phút'],
        iconKey: 'treadmill',
        iconMediaId,
        status: 'ACTIVE',
      }),
    });
    assert.equal(createRes.status, 201);
    const created = (await createRes.json()).data;
    assert.equal(created.iconKey, 'treadmill');
    assert.equal(created.iconMediaId, iconMediaId);
    assert.equal(created.iconUrl, `/api/v1/media/public/${iconMediaId}?v=${iconMediaId}`);
    assert.equal(created.iconThumbnailUrl, `/api/v1/media/public/${iconMediaId}?size=120&v=${iconMediaId}`);

    // 3. Public GET /equipment exposes icon fields cleanly
    const pubRes = await fetch(`${baseUrl}/equipment`);
    assert.equal(pubRes.status, 200);
    const pubItem = (await pubRes.json()).data[0];
    assert.equal(pubItem.iconKey, 'treadmill');
    assert.equal(pubItem.iconMediaId, iconMediaId);
    assert.equal(pubItem.iconThumbnailUrl, `/api/v1/media/public/${iconMediaId}?size=120&v=${iconMediaId}`);

    // 4. PATCH removing iconMediaId purges old SYSTEM_ICON from DB and Storage
    const patchRes = await fetch(`${baseUrl}/admin/equipment/${created.id}`, {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ iconMediaId: null, iconKey: 'bike' }),
    });
    assert.equal(patchRes.status, 200);
    const patched = (await patchRes.json()).data;
    assert.equal(patched.iconMediaId, null);
    assert.equal(patched.iconKey, 'bike');
    assert.equal(patched.iconUrl, null);
    assert.equal(database.mediaAssets.has(iconMediaId), false);
    assert.deepEqual(await imageStorage.list('system/icons/'), []);
  } finally {
    await new Promise((resolve) => server.close(resolve));
    await rm(storageDir, { recursive: true, force: true });
  }
});
