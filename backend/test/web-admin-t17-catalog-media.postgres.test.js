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
const secret = 't17-catalog-media-secret-with-32-chars';

function token(id, role, sessionVersion = 0) {
  return jwt.sign({ role, sessionVersion }, secret, {
    algorithm: 'HS256',
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    subject: id,
    expiresIn: 3600,
  });
}

async function callJson(base, urlPath, { method = 'GET', bearer, body } = {}) {
  const response = await fetch(`${base}/api/v1${urlPath}`, {
    method,
    headers: {
      ...(bearer ? { authorization: `Bearer ${bearer}` } : {}),
      ...(body === undefined ? {} : { 'content-type': 'application/json' }),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: response.status, body: await response.json() };
}

test('T17: Admin equipment & exercise filters, equipmentName join, before/after audit, gym-profile & QR',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const adminId = randomUUID();
    const memberId = randomUUID();
    const storageDir = await mkdtemp(path.join(tmpdir(), 'metagym-t17-cat-'));
    const storage = createLocalImageStorage(storageDir);
    const app = createApp({ database, jwtSecret: secret, imageStorage: storage });
    const server = app.listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;
    const pngBytes = await sharp({
      create: { width: 4, height: 4, channels: 3, background: '#11aa55' },
    }).png().toBuffer();

    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'ADMIN', 'T17 Admin'),
                ($3, $4, 'hash', 'MEMBER', 'T17 Member')`,
        [adminId, `${adminId}@example.com`, memberId, `${memberId}@example.com`],
      );
      await database.query(
        `INSERT INTO gym_profile (id, name, address, phone, email, description, opening_hours, rules, updated_by)
         VALUES (1, 'Meta Gym Old', '123 Main', '0901234567', 'old@metagym.vn', 'Old desc',
                 '{"mon":"06:00-21:00"}'::jsonb, 'Bring towel', $1)
         ON CONFLICT (id) DO UPDATE
           SET name = EXCLUDED.name, address = EXCLUDED.address, updated_by = EXCLUDED.updated_by`,
        [adminId],
      );
      await database.query(
        `INSERT INTO gym_checkin_code (id, code) VALUES (1, $1)
         ON CONFLICT (id) DO NOTHING`,
        [randomUUID()],
      );

      const adminToken = token(adminId, 'ADMIN');
      const memberToken = token(memberId, 'MEMBER');

      // Upload PUBLIC GYM and EQUIPMENT images for linking
      const gymImgRes = await fetch(`${base}/api/v1/media/images`, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${adminToken}`,
          'content-type': 'image/png',
          'x-image-purpose': 'GYM',
          'x-file-name': 'cover.png',
        },
        body: pngBytes,
      });
      assert.equal(gymImgRes.status, 201);
      const gymMediaId = (await gymImgRes.json()).data.id;

      const eqImgRes = await fetch(`${base}/api/v1/media/images`, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${adminToken}`,
          'content-type': 'image/png',
          'x-image-purpose': 'EQUIPMENT',
          'x-file-name': 'rack.png',
        },
        body: pngBytes,
      });
      assert.equal(eqImgRes.status, 201);
      const eqMediaId = (await eqImgRes.json()).data.id;

      // 1. Equipment CRUD + filters + pagination + before/after audit
      const eq1Res = await callJson(base, '/admin/equipment', {
        method: 'POST',
        bearer: adminToken,
        body: {
          name: 'T17 Power Rack',
          category: 'Strength',
          targetMuscles: ['Legs', 'Back'],
          imageMediaId: eqMediaId,
          description: 'Heavy duty squat rack',
          usageSteps: ['Adjust pins', 'Load plates'],
          safetyNotes: 'Always set safety bars',
          status: 'ACTIVE',
        },
      });
      assert.equal(eq1Res.status, 201);
      const eq1 = eq1Res.body.data;
      assert.equal(eq1.imageMediaId, eqMediaId);

      const eq2Res = await callJson(base, '/admin/equipment', {
        method: 'POST',
        bearer: adminToken,
        body: {
          name: 'T17 Air Bike',
          category: 'Cardio',
          targetMuscles: ['Full Body'],
          usageSteps: ['Adjust seat', 'Pedal'],
          status: 'HIDDEN',
        },
      });
      assert.equal(eq2Res.status, 201);
      const eq2 = eq2Res.body.data;

      // Filter equipment by search, category, status, pagination
      const eqSearch = await callJson(base, '/admin/equipment?search=Power%20Rack&category=Strength&status=ACTIVE&page=1&pageSize=10', {
        bearer: adminToken,
      });
      assert.equal(eqSearch.status, 200);
      assert.equal(eqSearch.body.pagination.totalItems, 1);
      assert.equal(eqSearch.body.pagination.page, 1);
      assert.equal(eqSearch.body.pagination.pageSize, 10);
      assert.equal(eqSearch.body.data[0].id, eq1.id);

      const eqHidden = await callJson(base, '/admin/equipment?search=T17&status=HIDDEN', {
        bearer: adminToken,
      });
      assert.equal(eqHidden.status, 200);
      assert.equal(eqHidden.body.pagination.totalItems, 1);
      assert.equal(eqHidden.body.data[0].id, eq2.id);

      const eqPage1 = await callJson(base, '/admin/equipment?search=T17&page=1&pageSize=1', {
        bearer: adminToken,
      });
      assert.equal(eqPage1.status, 200);
      assert.equal(eqPage1.body.data.length, 1);
      assert.equal(eqPage1.body.pagination.totalItems, 2);
      assert.equal(eqPage1.body.pagination.totalPages, 2);

      // Invalid pageSize > 100 -> 422
      assert.equal((await callJson(base, '/admin/equipment?pageSize=101', { bearer: adminToken })).status, 422);

      // PATCH equipment status & name -> verify full before/after audit
      const eqPatch = await callJson(base, `/admin/equipment/${eq1.id}`, {
        method: 'PATCH',
        bearer: adminToken,
        body: { name: 'T17 Power Rack Pro', status: 'HIDDEN', safetyNotes: 'Lock J-hooks tightly' },
      });
      assert.equal(eqPatch.status, 200);
      assert.equal(eqPatch.body.data.status, 'HIDDEN');

      const eqAudits = await database.query(
        `SELECT action, metadata FROM admin_audit_logs
         WHERE admin_id = $1 AND entity_type = 'EQUIPMENT' AND entity_id = $2
         ORDER BY created_at ASC`,
        [adminId, eq1.id],
      );
      assert.equal(eqAudits.rows.length, 2);
      assert.equal(eqAudits.rows[0].action, 'EQUIPMENT_CREATED');
      assert.equal(eqAudits.rows[0].metadata.before, null);
      assert.equal(eqAudits.rows[0].metadata.after.name, 'T17 Power Rack');
      assert.equal(eqAudits.rows[1].action, 'EQUIPMENT_UPDATED');
      assert.equal(eqAudits.rows[1].metadata.before.name, 'T17 Power Rack');
      assert.equal(eqAudits.rows[1].metadata.before.status, 'ACTIVE');
      assert.equal(eqAudits.rows[1].metadata.after.name, 'T17 Power Rack Pro');
      assert.equal(eqAudits.rows[1].metadata.after.status, 'HIDDEN');
      assert.equal(eqAudits.rows[1].metadata.after.safetyNotes, 'Lock J-hooks tightly');

      // 2. Exercises CRUD + validation + equipmentName join + filters + before/after audit
      // Invalid difficulty -> 422
      assert.equal((await callJson(base, '/admin/exercises', {
        method: 'POST',
        bearer: adminToken,
        body: { name: 'Bad Diff', instructions: 'Do it', difficulty: 'EXPERT' },
      })).status, 422);

      // Empty safetyNotes -> 422
      assert.equal((await callJson(base, '/admin/exercises', {
        method: 'POST',
        bearer: adminToken,
        body: { name: 'Bad Safety', instructions: 'Do it', safetyNotes: '   ' },
      })).status, 422);

      // Non-existent equipmentId -> 422
      assert.equal((await callJson(base, '/admin/exercises', {
        method: 'POST',
        bearer: adminToken,
        body: { name: 'Bad Eq', instructions: 'Do it', equipmentId: randomUUID() },
      })).status, 422);

      const ex1Res = await callJson(base, '/admin/exercises', {
        method: 'POST',
        bearer: adminToken,
        body: {
          equipmentId: eq1.id,
          name: 'T17 Back Squat',
          description: 'Compound lower body movement',
          targetMuscles: ['Quads', 'Glutes'],
          instructions: 'Brace core and squat to parallel',
          safetyNotes: 'Keep knees tracking toes',
          difficulty: 'INTERMEDIATE',
          status: 'ACTIVE',
        },
      });
      assert.equal(ex1Res.status, 201);
      const ex1 = ex1Res.body.data;
      assert.equal(ex1.equipmentName, 'T17 Power Rack Pro');
      assert.equal(ex1.safetyNotes, 'Keep knees tracking toes');

      const ex2Res = await callJson(base, '/admin/exercises', {
        method: 'POST',
        bearer: adminToken,
        body: {
          equipmentId: null,
          name: 'T17 Bodyweight Plank',
          targetMuscles: ['Core'],
          instructions: 'Hold straight body line',
          difficulty: 'BEGINNER',
          status: 'HIDDEN',
        },
      });
      assert.equal(ex2Res.status, 201);
      const ex2 = ex2Res.body.data;
      assert.equal(ex2.equipmentName, null);

      // Filter exercises by search, status, difficulty, equipmentId, pagination
      const exFilter = await callJson(
        base,
        `/admin/exercises?search=Squat&status=ACTIVE&difficulty=INTERMEDIATE&equipmentId=${eq1.id}&page=1&pageSize=10`,
        { bearer: adminToken },
      );
      assert.equal(exFilter.status, 200);
      assert.equal(exFilter.body.pagination.totalItems, 1);
      assert.equal(exFilter.body.data[0].id, ex1.id);
      assert.equal(exFilter.body.data[0].equipmentName, 'T17 Power Rack Pro');

      const exHidden = await callJson(base, '/admin/exercises?search=T17&status=HIDDEN&difficulty=BEGINNER', {
        bearer: adminToken,
      });
      assert.equal(exHidden.status, 200);
      assert.equal(exHidden.body.pagination.totalItems, 1);
      assert.equal(exHidden.body.data[0].id, ex2.id);
      assert.equal(exHidden.body.data[0].equipmentName, null);

      const exPage = await callJson(base, '/admin/exercises?search=T17&page=2&pageSize=1', {
        bearer: adminToken,
      });
      assert.equal(exPage.status, 200);
      assert.equal(exPage.body.data.length, 1);
      assert.equal(exPage.body.pagination.totalItems, 2);
      assert.equal(exPage.body.pagination.totalPages, 2);

      // PATCH exercise safetyNotes + difficulty -> verify before/after audit
      const exPatch = await callJson(base, `/admin/exercises/${ex1.id}`, {
        method: 'PATCH',
        bearer: adminToken,
        body: { safetyNotes: 'Use spotter on heavy sets', difficulty: 'ADVANCED' },
      });
      assert.equal(exPatch.status, 200);
      assert.equal(exPatch.body.data.safetyNotes, 'Use spotter on heavy sets');
      assert.equal(exPatch.body.data.difficulty, 'ADVANCED');
      assert.equal(exPatch.body.data.equipmentName, 'T17 Power Rack Pro');

      const exAudits = await database.query(
        `SELECT action, metadata FROM admin_audit_logs
         WHERE admin_id = $1 AND entity_type = 'EXERCISES' AND entity_id = $2
         ORDER BY created_at ASC`,
        [adminId, ex1.id],
      );
      assert.equal(exAudits.rows.length, 2);
      assert.equal(exAudits.rows[0].action, 'EXERCISES_CREATED');
      assert.equal(exAudits.rows[0].metadata.before, null);
      assert.equal(exAudits.rows[0].metadata.after.safetyNotes, 'Keep knees tracking toes');
      assert.equal(exAudits.rows[1].action, 'EXERCISES_UPDATED');
      assert.equal(exAudits.rows[1].metadata.before.safetyNotes, 'Keep knees tracking toes');
      assert.equal(exAudits.rows[1].metadata.before.difficulty, 'INTERMEDIATE');
      assert.equal(exAudits.rows[1].metadata.after.safetyNotes, 'Use spotter on heavy sets');
      assert.equal(exAudits.rows[1].metadata.after.difficulty, 'ADVANCED');

      // 3. GET/PATCH /admin/gym-profile + Counter Check-in QR intact & audited
      assert.equal((await callJson(base, '/admin/gym-profile', { bearer: memberToken })).status, 403);
      const gymGet = await callJson(base, '/admin/gym-profile', { bearer: adminToken });
      assert.equal(gymGet.status, 200);
      assert.equal(gymGet.body.data.name, 'Meta Gym Old');

      const gymPatch = await callJson(base, '/admin/gym-profile', {
        method: 'PATCH',
        bearer: adminToken,
        body: { name: 'Meta Gym Flagship', coverMediaId: gymMediaId },
      });
      assert.equal(gymPatch.status, 200);
      assert.equal(gymPatch.body.data.name, 'Meta Gym Flagship');
      assert.equal(gymPatch.body.data.coverMediaId, gymMediaId);

      const gymAudit = await database.query(
        `SELECT action, metadata FROM admin_audit_logs
         WHERE admin_id = $1 AND action = 'GYM_PROFILE_UPDATED'
         ORDER BY created_at DESC LIMIT 1`,
        [adminId],
      );
      assert.equal(gymAudit.rows.length, 1);
      assert.equal(gymAudit.rows[0].metadata.before.name, 'Meta Gym Old');
      assert.equal(gymAudit.rows[0].metadata.after.name, 'Meta Gym Flagship');
      assert.equal(gymAudit.rows[0].metadata.after.coverMediaId, gymMediaId);

      const qrGet = await callJson(base, '/admin/gym-checkin-code', { bearer: adminToken });
      assert.equal(qrGet.status, 200);
      assert.match(qrGet.body.data.payload, /^metagym:\/\/gym-checkin\//);

      const qrRotate = await callJson(base, '/admin/gym-checkin-code/rotate', {
        method: 'POST',
        bearer: adminToken,
      });
      assert.equal(qrRotate.status, 200);
      assert.notEqual(qrRotate.body.data.payload, qrGet.body.data.payload);

      const qrAudit = await database.query(
        `SELECT count(*)::int AS n FROM admin_audit_logs
         WHERE admin_id = $1 AND action = 'GYM_CHECKIN_CODE_ROTATED'`,
        [adminId],
      );
      assert.equal(qrAudit.rows[0].n, 1);
    } finally {
      await new Promise((resolve) => server.close(resolve));
      await database.query('DELETE FROM admin_audit_logs WHERE admin_id = $1', [adminId]);
      await database.query('DELETE FROM exercises WHERE created_by = $1', [adminId]);
      await database.query('DELETE FROM equipment WHERE created_by = $1', [adminId]);
      await database.query('UPDATE gym_profile SET cover_media_id = NULL, updated_by = NULL WHERE updated_by = $1', [adminId]);
      await database.query('DELETE FROM media_assets WHERE owner_id IN ($1, $2)', [adminId, memberId]);
      await database.query('DELETE FROM users WHERE id IN ($1, $2)', [adminId, memberId]);
      await database.end();
      await rm(storageDir, { recursive: true, force: true });
    }
  });

test('T17: Admin public media upload (GYM/EQUIPMENT) and strict privacy isolation for private media',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const adminId = randomUUID();
    const memberId = randomUUID();
    const coachId = randomUUID();
    const storageDir = await mkdtemp(path.join(tmpdir(), 'metagym-t17-media-'));
    const storage = createLocalImageStorage(storageDir);
    const app = createApp({ database, jwtSecret: secret, imageStorage: storage });
    const server = app.listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;
    const pngBytes = await sharp({
      create: { width: 3, height: 3, channels: 3, background: '#3366ff' },
    }).png().toBuffer();

    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Media Admin'),
                ($3, $4, 'hash', 'MEMBER', 'Media Member'),
                ($5, $6, 'hash', 'COACH', 'Media Coach')`,
        [
          adminId, `${adminId}@example.com`,
          memberId, `${memberId}@example.com`,
          coachId, `${coachId}@example.com`,
        ],
      );
      const adminToken = token(adminId, 'ADMIN');
      const memberToken = token(memberId, 'MEMBER');
      const coachToken = token(coachId, 'COACH');

      // 1. Admin succeeds for GYM and EQUIPMENT -> access_scope = 'PUBLIC'
      for (const purpose of ['GYM', 'EQUIPMENT']) {
        const upload = await fetch(`${base}/api/v1/media/images`, {
          method: 'POST',
          headers: {
            authorization: `Bearer ${adminToken}`,
            'content-type': 'image/png',
            'x-image-purpose': purpose,
            'x-file-name': `${purpose.toLowerCase()}.png`,
          },
          body: pngBytes,
        });
        assert.equal(upload.status, 201);
        const body = (await upload.json()).data;
        assert.equal(body.purpose, purpose);
        assert.equal(body.accessScope, 'PUBLIC');
        assert.equal(body.publicUrl, `/api/v1/media/public/${body.id}`);

        const dbRow = await database.query(
          'SELECT purpose, access_scope, status, storage_key FROM media_assets WHERE id = $1',
          [body.id],
        );
        assert.equal(dbRow.rows[0].purpose, purpose);
        assert.equal(dbRow.rows[0].access_scope, 'PUBLIC');
        assert.equal(dbRow.rows[0].status, 'READY');

        // Publicly readable via GET /api/v1/media/public/:mediaId
        const publicRead = await fetch(`${base}/api/v1/media/public/${body.id}`);
        assert.equal(publicRead.status, 200);
        assert.equal(publicRead.headers.get('content-type'), 'image/png');
        assert.match(publicRead.headers.get('cache-control') ?? '', /public/);
        assert.deepEqual(
          Buffer.from(await publicRead.arrayBuffer()),
          await storage.get(dbRow.rows[0].storage_key),
        );
      }

      // 2. Admin rejected with 403 FORBIDDEN for all private purposes
      for (const forbiddenPurpose of ['PROGRESS_PHOTO', 'MEAL_PHOTO', 'MESSAGE', 'COACH_OUTCOME', 'AVATAR']) {
        const res = await fetch(`${base}/api/v1/media/images`, {
          method: 'POST',
          headers: {
            authorization: `Bearer ${adminToken}`,
            'content-type': 'image/png',
            'x-image-purpose': forbiddenPurpose,
          },
          body: pngBytes,
        });
        assert.equal(res.status, 403, `Expected 403 for ADMIN uploading ${forbiddenPurpose}`);
        assert.equal((await res.json()).error.code, 'FORBIDDEN');
      }

      // 3. Privacy invariant: Member uploads PROGRESS_PHOTO & MEAL_PHOTO, Coach uploads COACH_OUTCOME
      const uploadPrivate = async (bearer, purpose) => {
        const res = await fetch(`${base}/api/v1/media/images`, {
          method: 'POST',
          headers: {
            authorization: `Bearer ${bearer}`,
            'content-type': 'image/png',
            'x-image-purpose': purpose,
          },
          body: pngBytes,
        });
        assert.equal(res.status, 201);
        return (await res.json()).data.id;
      };

      const progressMediaId = await uploadPrivate(memberToken, 'PROGRESS_PHOTO');
      const mealMediaId = await uploadPrivate(memberToken, 'MEAL_PHOTO');
      const outcomeMediaId = await uploadPrivate(coachToken, 'COACH_OUTCOME');

      // Admin MUST be blocked from reading any private media via access-url, public, or raw endpoint
      for (const privateId of [progressMediaId, mealMediaId, outcomeMediaId]) {
        const accessUrlRes = await fetch(`${base}/api/v1/media/images/${privateId}/access-url`, {
          headers: { authorization: `Bearer ${adminToken}` },
        });
        assert.ok(
          [403, 404].includes(accessUrlRes.status),
          `Expected 403/404 for ADMIN access-url on ${privateId}, got ${accessUrlRes.status}`,
        );

        const publicRes = await fetch(`${base}/api/v1/media/public/${privateId}`, {
          headers: { authorization: `Bearer ${adminToken}` },
        });
        assert.equal(publicRes.status, 404);

        const rawRes = await fetch(`${base}/api/v1/media/images/${privateId}`, {
          headers: { authorization: `Bearer ${adminToken}` },
        });
        assert.equal(rawRes.status, 404);
      }

      // Admin also cannot link Member's private PROGRESS_PHOTO to equipment or gym_profile
      const badEq = await callJson(base, '/admin/equipment', {
        method: 'POST',
        bearer: adminToken,
        body: {
          name: 'Bad Media Eq',
          category: 'Strength',
          imageMediaId: progressMediaId,
          usageSteps: ['Step 1'],
        },
      });
      assert.equal(badEq.status, 422);
    } finally {
      await new Promise((resolve) => server.close(resolve));
      await database.query('DELETE FROM media_assets WHERE owner_id IN ($1, $2, $3)', [adminId, memberId, coachId]);
      await database.query('DELETE FROM users WHERE id IN ($1, $2, $3)', [adminId, memberId, coachId]);
      await database.end();
      await rm(storageDir, { recursive: true, force: true });
    }
  });
