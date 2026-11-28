import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import jwt from 'jsonwebtoken';

import { createApp } from '../src/app.js';
import { isSecondaryVariantKey } from '../src/modules/media/supabase-sync.js';
import { createLocalImageStorage } from '../src/storage/local-image-storage.js';
import { buildExerciseVideoStorageKey, isValidStorageKey } from '../src/storage/storage-key.js';

const SECRET = 'exercise-video-test-secret-32-chars!!';

function tokenFor(id, role, staffPosition = null) {
  return jwt.sign(
    { role, sessionVersion: 0, ...(staffPosition ? { staffPosition } : {}) },
    SECRET,
    {
      algorithm: 'HS256',
      audience: 'meta-gym-clients',
      issuer: 'meta-gym-api',
      subject: id,
      expiresIn: 3600,
    },
  );
}

function makeFakeMp4(size = 64) {
  const buf = Buffer.alloc(size, 0xaa);
  Buffer.from([0x00, 0x00, 0x00, 0x18]).copy(buf, 0);
  buf.write('ftypisom', 4, 'ascii');
  return buf;
}

function createFakeCatalogDb({ adminId, techId, memberId, equipmentId }) {
  const mediaAssets = new Map();
  const exercises = new Map();

  async function runQuery(sql, params = []) {
    const q = sql.replace(/\s+/g, ' ').trim();

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
      if (id === techId) {
        return { rows: [{ id, email: 'tech@metagym.vn', full_name: 'Tech', role: 'STAFF', status: 'ACTIVE', session_version: 0 }] };
      }
      if (id === memberId) {
        return { rows: [{ id, email: 'member@metagym.vn', full_name: 'Member', role: 'MEMBER', status: 'ACTIVE', session_version: 0 }] };
      }
      return { rows: [] };
    }

    if (q.includes('FROM staff_profiles sp') && q.includes('WHERE sp.user_id = $1')) {
      if (params[0] === techId) {
        return { rows: [{ position_code: 'TECHNICIAN', department: 'Thiết bị', shift_note: null, role_permissions: null }] };
      }
      return { rows: [] };
    }

    if (q.includes('SELECT u.id FROM users u') && q.includes('FOR SHARE')) {
      const id = params[0];
      if (id === adminId || id === techId) return { rows: [{ id }], rowCount: 1 };
      return { rows: [], rowCount: 0 };
    }

    if (q.startsWith('INSERT INTO media_assets')) {
      const [id, ownerId, storageKey, originalName] = params;
      mediaAssets.set(id, {
        id,
        owner_id: ownerId,
        purpose: 'EXERCISE',
        access_scope: 'PUBLIC',
        storage_key: storageKey,
        original_name: originalName,
        mime_type: null,
        size_bytes: null,
        status: 'UPLOADING',
      });
      return { rows: [], rowCount: 1 };
    }

    if (q.startsWith("UPDATE media_assets SET status = 'READY'")) {
      const [mimeType, sizeBytes, id] = params;
      const row = mediaAssets.get(id);
      if (row) {
        row.status = 'READY';
        row.mime_type = mimeType;
        row.size_bytes = sizeBytes;
      }
      return { rows: [], rowCount: row ? 1 : 0 };
    }

    if (q.startsWith("UPDATE media_assets SET status = 'FAILED'")) {
      const row = mediaAssets.get(params[0]);
      if (row) row.status = 'FAILED';
      return { rows: [], rowCount: 1 };
    }

    if (q.includes('FROM media_assets') && q.includes("purpose = 'EXERCISE'") && q.includes("mime_type LIKE 'video/%'")) {
      const row = mediaAssets.get(params[0]);
      if (row && row.status === 'READY' && row.access_scope === 'PUBLIC'
        && row.purpose === 'EXERCISE' && String(row.mime_type || '').startsWith('video/')) {
        return { rows: [row], rowCount: 1 };
      }
      return { rows: [], rowCount: 0 };
    }

    if (q.startsWith('SELECT id FROM media_assets WHERE id = $1 AND status = \'READY\'')) {
      const [id, purpose] = params;
      const row = mediaAssets.get(id);
      if (row && row.status === 'READY' && row.access_scope === 'PUBLIC'
        && row.purpose === purpose && (!q.includes("mime_type LIKE 'video/%'") || String(row.mime_type || '').startsWith('video/'))) {
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

    if (q.startsWith('DELETE FROM images WHERE storage_key = $1')) {
      return { rows: [], rowCount: 0 };
    }

    if (q.startsWith('DELETE FROM media_assets WHERE id = $1')) {
      mediaAssets.delete(params[0]);
      return { rows: [], rowCount: 1 };
    }

    if (q.startsWith('SELECT id FROM equipment WHERE id = $1')) {
      return params[0] === equipmentId ? { rows: [{ id: equipmentId }], rowCount: 1 } : { rows: [], rowCount: 0 };
    }

    if (q.startsWith('INSERT INTO exercises')) {
      const colMatch = /\(([^)]+)\)\s+VALUES/i.exec(q);
      const cols = colMatch[1].split(',').map((s) => s.trim());
      const row = {
        id: params[0],
        created_by: params[1],
        equipment_id: null,
        name: null,
        description: null,
        target_muscles: [],
        instructions: '',
        safety_notes: null,
        difficulty: null,
        video_url: null,
        video_media_id: null,
        status: 'ACTIVE',
      };
      cols.forEach((col, i) => {
        row[col] = params[i];
      });
      exercises.set(row.id, row);
      return { rows: [], rowCount: 1 };
    }

    if (q.startsWith('SELECT id FROM exercises WHERE id = $1 FOR UPDATE')) {
      const row = exercises.get(params[0]);
      return row ? { rows: [{ id: row.id }], rowCount: 1 } : { rows: [], rowCount: 0 };
    }

    if (q.startsWith('SELECT 1 FROM exercises WHERE video_media_id = $1 AND id <> $2')) {
      const [mId, exId] = params;
      const found = [...exercises.values()].some((r) => r.video_media_id === mId && r.id !== exId);
      return { rows: found ? [{ '?column?': 1 }] : [], rowCount: found ? 1 : 0 };
    }

    if (q.startsWith('UPDATE exercises SET')) {
      const setPart = q.slice('UPDATE exercises SET'.length, q.lastIndexOf('WHERE id ='));
      const assignments = setPart.split(',').map((s) => s.trim());
      const id = params.at(-1);
      const row = exercises.get(id);
      if (row) {
        assignments.forEach((assign, idx) => {
          const col = assign.split('=')[0].trim();
          row[col] = params[idx];
        });
      }
      return { rows: [], rowCount: row ? 1 : 0 };
    }

    if (q.includes('FROM exercises x') && q.includes('WHERE x.id = $1')) {
      const row = exercises.get(params[0]);
      if (!row) return { rows: [], rowCount: 0 };
      if (q.includes("x.status = 'ACTIVE'") && row.status !== 'ACTIVE') return { rows: [], rowCount: 0 };
      const vm = row.video_media_id ? mediaAssets.get(row.video_media_id) : null;
      return {
        rows: [{
          ...row,
          equipment_name: row.equipment_id === equipmentId ? 'Power Rack' : null,
          equipment_video_url: null,
          video_original_name: vm?.original_name ?? null,
          video_mime_type: vm?.mime_type ?? null,
          video_size_bytes: vm?.size_bytes ?? null,
        }],
        rowCount: 1,
      };
    }

    if (q.startsWith('SELECT count(*)::int AS count FROM exercises x')) {
      const list = [...exercises.values()].filter((r) => !q.includes("x.status = 'ACTIVE'") || r.status === 'ACTIVE');
      return { rows: [{ count: list.length }], rowCount: 1 };
    }

    if (q.includes('FROM exercises x') && q.includes('ORDER BY x.created_at DESC')) {
      const list = [...exercises.values()]
        .filter((r) => !q.includes("x.status = 'ACTIVE'") || r.status === 'ACTIVE')
        .map((row) => {
          const vm = row.video_media_id ? mediaAssets.get(row.video_media_id) : null;
          return {
            ...row,
            equipment_name: row.equipment_id === equipmentId ? 'Power Rack' : null,
            equipment_video_url: null,
            video_original_name: vm?.original_name ?? null,
            video_mime_type: vm?.mime_type ?? null,
            video_size_bytes: vm?.size_bytes ?? null,
          };
        });
      return { rows: list, rowCount: list.length };
    }

    if (q.startsWith('INSERT INTO admin_audit_logs')) {
      return { rows: [], rowCount: 1 };
    }

    return { rows: [], rowCount: 0 };
  }

  return {
    mediaAssets,
    exercises,
    async query(sql, params) {
      return runQuery(sql, params);
    },
    async connect() {
      return {
        query: runQuery,
        release() {},
      };
    },
  };
}

test('storage-key and supabase-sync isolate exercise videos under exercises/videos/', () => {
  const id = randomUUID();
  const key = buildExerciseVideoStorageKey(id, 'mp4');
  assert.equal(key, `exercises/videos/${id}.mp4`);
  assert.equal(isValidStorageKey(key), true);
  assert.equal(isSecondaryVariantKey(key), true);
});

test('POST /media/videos, Range streaming, exercise binding, and DB+Storage cleanup on replacement', async () => {
  const storageDir = await mkdtemp(path.join(os.tmpdir(), 'metagym-video-test-'));
  const imageStorage = createLocalImageStorage(storageDir);
  const adminId = randomUUID();
  const techId = randomUUID();
  const memberId = randomUUID();
  const equipmentId = randomUUID();
  const database = createFakeCatalogDb({ adminId, techId, memberId, equipmentId });

  const app = createApp({ database, jwtSecret: SECRET, imageStorage });
  const server = app.listen(0);
  const baseUrl = `http://127.0.0.1:${server.address().port}/api/v1`;

  try {
    const adminToken = tokenFor(adminId, 'ADMIN');
    const techToken = tokenFor(techId, 'STAFF', 'TECHNICIAN');
    const memberToken = tokenFor(memberId, 'MEMBER');

    // 1. Member cannot upload video (403)
    const forbiddenForm = new FormData();
    forbiddenForm.append('file', new Blob([makeFakeMp4()], { type: 'video/mp4' }), 'demo.mp4');
    const forbiddenRes = await fetch(`${baseUrl}/media/videos`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${memberToken}` },
      body: forbiddenForm,
    });
    assert.equal(forbiddenRes.status, 403);

    // 2. Reject invalid video bytes (422)
    const badForm = new FormData();
    badForm.append('file', new Blob([Buffer.from('not-a-video-payload')], { type: 'video/mp4' }), 'bad.mp4');
    const badRes = await fetch(`${baseUrl}/media/videos`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: badForm,
    });
    assert.equal(badRes.status, 422);

    // 3. Technician uploads valid MP4 video (201)
    const mp4Bytes = makeFakeMp4(64);
    const okForm = new FormData();
    okForm.append('purpose', 'EXERCISE');
    okForm.append('file', new Blob([mp4Bytes], { type: 'video/mp4' }), 'squat-guide.mp4');
    const uploadRes = await fetch(`${baseUrl}/media/videos`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${techToken}` },
      body: okForm,
    });
    assert.equal(uploadRes.status, 201);
    const uploadBody = await uploadRes.json();
    const videoId1 = uploadBody.data.id;
    assert.equal(uploadBody.data.mimeType, 'video/mp4');
    assert.equal(uploadBody.data.publicUrl, `/api/v1/media/videos/public/${videoId1}?v=${videoId1}`);

    const keysAfterUpload1 = await imageStorage.list('exercises/videos/');
    assert.deepEqual(keysAfterUpload1, [`exercises/videos/${videoId1}.mp4`]);

    // 4. Public streaming supports 200 and 206 Partial Content
    const fullStream = await fetch(`${baseUrl}/media/videos/public/${videoId1}`);
    assert.equal(fullStream.status, 200);
    assert.equal(fullStream.headers.get('accept-ranges'), 'bytes');
    assert.equal(Buffer.from(await fullStream.arrayBuffer()).length, 64);

    const rangeStream = await fetch(`${baseUrl}/media/videos/public/${videoId1}`, {
      headers: { Range: 'bytes=4-11' },
    });
    assert.equal(rangeStream.status, 206);
    assert.equal(rangeStream.headers.get('content-range'), 'bytes 4-11/64');
    assert.equal(Buffer.from(await rangeStream.arrayBuffer()).toString('ascii'), 'ftypisom');

    const badRange = await fetch(`${baseUrl}/media/videos/public/${videoId1}`, {
      headers: { Range: 'bytes=999-1000' },
    });
    assert.equal(badRange.status, 416);

    // 5. Reject simultaneous videoMediaId + videoUrl on POST /admin/exercises
    const conflictRes = await fetch(`${baseUrl}/admin/exercises`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        name: 'Back Squat',
        instructions: 'Hạ hông song song mặt sàn.',
        videoMediaId: videoId1,
        videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      }),
    });
    assert.equal(conflictRes.status, 422);

    // 6. Create exercise with uploaded videoMediaId -> member GET /exercises receives full http:// stream URL
    const createExRes = await fetch(`${baseUrl}/admin/exercises`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        name: 'Back Squat',
        equipmentId,
        instructions: 'Giữ lưng thẳng, hạ hông song song mặt sàn.',
        targetMuscles: ['Đùi trước', 'Mông'],
        difficulty: 'INTERMEDIATE',
        videoMediaId: videoId1,
      }),
    });
    assert.equal(createExRes.status, 201);
    const createdEx = (await createExRes.json()).data;
    assert.equal(createdEx.videoMediaId, videoId1);
    assert.equal(createdEx.videoStreamUrl, `/api/v1/media/videos/public/${videoId1}?v=${videoId1}`);

    const memberListRes = await fetch(`${baseUrl}/exercises`, {
      headers: { Authorization: `Bearer ${memberToken}` },
    });
    assert.equal(memberListRes.status, 200);
    const memberList = (await memberListRes.json()).data;
    assert.match(memberList[0].videoUrl, new RegExp(`^http://127\\.0\\.0\\.1:\\d+/api/v1/media/videos/public/${videoId1}\\?v=${videoId1}$`));

    // 7. Switching to YouTube URL cleans up old uploaded video from DB + Storage
    const patchRes = await fetch(`${baseUrl}/admin/exercises/${createdEx.id}`, {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      }),
    });
    assert.equal(patchRes.status, 200);
    const patchedEx = (await patchRes.json()).data;
    assert.equal(patchedEx.videoMediaId, null);
    assert.equal(patchedEx.videoUrl, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    assert.equal(database.mediaAssets.has(videoId1), false);
    const keysAfterCleanup = await imageStorage.list('exercises/videos/');
    assert.deepEqual(keysAfterCleanup, []);
  } finally {
    await new Promise((resolve) => server.close(resolve));
    await rm(storageDir, { recursive: true, force: true });
  }
});
