import assert from 'node:assert/strict';
import test from 'node:test';

import express from 'express';
import jwt from 'jsonwebtoken';

import { createAdminUsersRouter } from '../src/routes/admin-users.routes.js';
import { createUsersRouter } from '../src/routes/users.routes.js';

const JWT_SECRET = 'admin-member-update-unit-test-secret-32chars';
const ADMIN_ID = '11111111-1111-4111-8111-111111111111';
const MEMBER_ID = '22222222-2222-4222-8222-222222222222';
const COACH_ID = '33333333-3333-4333-8333-333333333333';
const OTHER_USER_ID = '44444444-4444-4444-8444-444444444444';

// T18 Explicit Privacy Guard: Health & injury notes, passwords, and raw body composition MUST NOT be exposed
const FORBIDDEN_PRIVACY_KEYS = new Set([
  'password',
  'passwordhash',
  'healthnotes',
  'injurynotes',
  'healthdeclarationcompletedat',
]);

function createMockDb() {
  const users = new Map([
    [ADMIN_ID, {
      id: ADMIN_ID,
      email: 'admin@metagym.vn',
      full_name: 'Meta Admin',
      phone: null,
      role: 'ADMIN',
      status: 'ACTIVE',
      avatar_media_id: null,
      session_version: 0,
      disabled_at: null,
      disabled_reason: null,
      last_login_at: null,
      created_at: '2026-11-01T00:00:00.000Z',
      member_limit: null,
    }],
    [MEMBER_ID, {
      id: MEMBER_ID,
      email: 'member@metagym.vn',
      full_name: 'Nguyễn Văn A',
      phone: '0901112223',
      role: 'MEMBER',
      status: 'ACTIVE',
      avatar_media_id: null,
      session_version: 0,
      disabled_at: null,
      disabled_reason: null,
      last_login_at: null,
      created_at: '2026-11-02T00:00:00.000Z',
      member_limit: null,
    }],
    [COACH_ID, {
      id: COACH_ID,
      email: 'coach@metagym.vn',
      full_name: 'Trần Huấn Luyện',
      phone: '0912345678',
      role: 'COACH',
      status: 'ACTIVE',
      avatar_media_id: null,
      session_version: 0,
      disabled_at: null,
      disabled_reason: null,
      last_login_at: null,
      created_at: '2026-11-02T12:00:00.000Z',
      member_limit: 8,
    }],
    [OTHER_USER_ID, {
      id: OTHER_USER_ID,
      email: 'taken@metagym.vn',
      full_name: 'Trần Thị B',
      phone: '0988777666',
      role: 'MEMBER',
      status: 'ACTIVE',
      avatar_media_id: null,
      session_version: 0,
      disabled_at: null,
      disabled_reason: null,
      last_login_at: null,
      created_at: '2026-11-03T00:00:00.000Z',
      member_limit: null,
    }],
  ]);

  const profiles = new Map([
    [MEMBER_ID, {
      user_id: MEMBER_ID,
      date_of_birth: '1995-05-15',
      gender: 'MALE',
      height_cm: 175,
      fitness_goal: 'Giảm cân',
      experience_level: 'BEGINNER',
      activity_level: 'MODERATE',
      dietary_preferences: 'Ăn kiêng ít tinh bột',
    }],
  ]);

  const coachProfiles = new Map([
    [COACH_ID, {
      user_id: COACH_ID,
      biography: 'HLV 3 năm kinh nghiệm',
      specialties: ['Tăng cơ'],
      qualifications: 'PT Chứng chỉ Quốc gia',
      experience_years: 3,
      availability_note: 'Sáng thứ 2-6',
    }],
  ]);

  const mediaAssets = new Map();
  const auditLogs = [];

  async function runQuery(sql, params = [], state = { snapshot: null }) {
    const text = String(sql).replace(/\s+/g, ' ').trim();
    if (text === 'BEGIN') {
      state.snapshot = {
        users: new Map(Array.from(users.entries(), ([id, row]) => [id, { ...row }])),
        profiles: new Map(Array.from(profiles.entries(), ([id, row]) => [id, { ...row }])),
      };
      return { rows: [] };
    }
    if (text === 'COMMIT') {
      state.snapshot = null;
      return { rows: [] };
    }
    if (text === 'ROLLBACK') {
      if (state.snapshot) {
        users.clear();
        for (const [id, row] of state.snapshot.users.entries()) users.set(id, row);
        profiles.clear();
        for (const [id, row] of state.snapshot.profiles.entries()) profiles.set(id, row);
        state.snapshot = null;
      }
      return { rows: [] };
    }
    if (text.startsWith('SELECT pg_advisory_xact_lock')) {
      return { rows: [] };
    }
    if (text.includes("WHERE id = $1 AND role = 'ADMIN'")) {
      const user = users.get(params[0]);
      if (user && user.role === 'ADMIN' && user.status === 'ACTIVE' && user.session_version === params[1]) {
        return { rows: [{ id: user.id }] };
      }
      return { rows: [] };
    }
    if (text.includes('LEFT JOIN media_assets m')) {
      const user = users.get(params[0]);
      if (!user) return { rows: [] };
      const asset = user.avatar_media_id ? mediaAssets.get(user.avatar_media_id) : null;
      return {
        rows: [{
          avatar_media_id: user.avatar_media_id || null,
          storage_key: asset?.storage_key || null,
          mime_type: asset?.mime_type || null,
        }],
      };
    }
    if (text.includes('FROM users u')) {
      const user = users.get(params[0]);
      if (!user) return { rows: [] };
      const prof = profiles.get(params[0]) || {};
      const cProf = coachProfiles.get(params[0]) || {};
      return {
        rows: [{
          ...user,
          date_of_birth: prof.date_of_birth ?? null,
          gender: prof.gender ?? null,
          height_cm: prof.height_cm ?? null,
          fitness_goal: prof.fitness_goal ?? null,
          experience_level: prof.experience_level ?? null,
          activity_level: prof.activity_level ?? null,
          dietary_preferences: prof.dietary_preferences ?? null,
          biography: cProf.biography ?? null,
          specialties: cProf.specialties ?? [],
          qualifications: cProf.qualifications ?? null,
          experience_years: cProf.experience_years ?? 0,
          availability_note: cProf.availability_note ?? null,
        }],
      };
    }
    if (text.startsWith('SELECT id FROM media_assets')) {
      const asset = mediaAssets.get(params[0]);
      if (asset && asset.status === 'READY') return { rows: [{ id: asset.id }] };
      return { rows: [] };
    }
    if (text.startsWith('SELECT id, storage_key, purpose FROM media_assets')) {
      const asset = mediaAssets.get(params[0]);
      if (asset && asset.purpose === 'AVATAR') return { rows: [asset] };
      return { rows: [] };
    }
    if (text.startsWith('DELETE FROM media_assets')) {
      const asset = mediaAssets.get(params[0]);
      if (asset && asset.purpose === 'AVATAR') mediaAssets.delete(params[0]);
      return { rows: [] };
    }
    if (text.startsWith('SELECT user_id FROM member_profiles')) {
      const prof = profiles.get(params[0]);
      return { rows: prof ? [{ user_id: prof.user_id }] : [] };
    }
    if (text.startsWith('UPDATE users SET ')) {
      const targetId = params[params.length - 1];
      const user = users.get(targetId);
      if (!user) return { rows: [] };

      // Parse assignments
      const setMatch = text.match(/^UPDATE users SET (.+) WHERE id = \$\d+$/);
      if (setMatch) {
        const assignments = setMatch[1].split(',').map((part) => part.trim());
        const nextUser = { ...user };
        assignments.forEach((assign) => {
          const [col, rhs] = assign.split('=').map((s) => s.trim());
          if (col !== 'updated_at') {
            if (rhs === 'NULL') {
              nextUser[col] = null;
            } else if (rhs.startsWith('$')) {
              const paramIdx = parseInt(rhs.slice(1), 10) - 1;
              nextUser[col] = params[paramIdx];
            }
          }
        });
        const duplicateEmail = Array.from(users.values()).some(
          (other) => other.id !== targetId && String(other.email).toLowerCase() === String(nextUser.email).toLowerCase(),
        );
        if (duplicateEmail) {
          const err = new Error('duplicate key value violates unique constraint "users_email_key"');
          err.code = '23505';
          err.constraint = 'users_email_key';
          throw err;
        }
        users.set(targetId, nextUser);
      }
      return { rows: [] };
    }
    if (text.startsWith('UPDATE member_profiles SET ')) {
      const targetId = params[params.length - 1];
      const current = profiles.get(targetId) || { user_id: targetId };
      const setMatch = text.match(/^UPDATE member_profiles SET (.+) WHERE user_id = \$\d+$/);
      if (setMatch) {
        const assignments = setMatch[1].split(',').map((part) => part.trim());
        const next = { ...current };
        assignments.forEach((assign, idx) => {
          const col = assign.split('=')[0].trim();
          if (col !== 'updated_at') {
            next[col] = params[idx];
          }
        });
        profiles.set(targetId, next);
      }
      return { rows: [] };
    }
    if (text.startsWith('INSERT INTO member_profiles')) {
      const targetId = params[0];
      const next = {
        user_id: targetId,
        date_of_birth: params[1],
        gender: params[2],
        height_cm: params[3],
        fitness_goal: params[4],
        experience_level: params[5],
        activity_level: params[6],
        dietary_preferences: params[7],
      };
      profiles.set(targetId, next);
      return { rows: [] };
    }
    if (text.startsWith('INSERT INTO media_assets')) {
      mediaAssets.set(params[0], {
        id: params[0],
        owner_id: params[1],
        purpose: 'AVATAR',
        access_scope: 'PUBLIC',
        storage_key: params[2],
        original_name: 'avatar.webp',
        mime_type: params[3],
        size_bytes: params[4],
        width: params[5],
        height: params[6],
        status: 'READY',
      });
      return { rows: [] };
    }
    if (text.startsWith('SELECT user_id FROM coach_profiles')) {
      const prof = coachProfiles.get(params[0]);
      return { rows: prof ? [{ user_id: prof.user_id }] : [] };
    }
    if (text.startsWith('UPDATE coach_profiles SET ')) {
      const targetId = params[params.length - 1];
      const current = coachProfiles.get(targetId) || { user_id: targetId };
      const setMatch = text.match(/^UPDATE coach_profiles SET (.+) WHERE user_id = \$\d+$/);
      if (setMatch) {
        const assignments = setMatch[1].split(',').map((part) => part.trim());
        const next = { ...current };
        assignments.forEach((assign, idx) => {
          const col = assign.split('=')[0].trim();
          if (col !== 'updated_at') {
            next[col] = params[idx];
          }
        });
        coachProfiles.set(targetId, next);
      }
      return { rows: [] };
    }
    if (text.startsWith('INSERT INTO coach_profiles')) {
      const targetId = params[0];
      coachProfiles.set(targetId, { user_id: targetId, member_limit: 8 });
      return { rows: [] };
    }
    if (text.startsWith('INSERT INTO admin_audit_logs')) {
      auditLogs.push({
        id: params[0],
        adminId: params[1],
        action: params[2],
        entityId: params[3],
        summary: params[4],
        metadata: JSON.parse(params[5]),
      });
      return { rows: [] };
    }
    return { rows: [] };
  }

  return {
    users,
    profiles,
    mediaAssets,
    auditLogs,
    query: (sql, params) => runQuery(sql, params),
    async connect() {
      const txState = { snapshot: null };
      return {
        query: (sql, params) => runQuery(sql, params, txState),
        release() {},
      };
    },
  };
}

function createMockImageStorage() {
  const store = new Map();
  return {
    store,
    async put(key, buffer, mimeType) {
      store.set(key, { buffer, mimeType });
    },
    async get(key) {
      return store.get(key)?.buffer ?? null;
    },
    async remove(key) {
      store.delete(key);
    },
  };
}

async function withServer(database, fn, { imageStorage = createMockImageStorage() } = {}) {
  const app = express();
  app.use(express.json());
  app.use('/api/v1/admin', createAdminUsersRouter({ database, jwtSecret: JWT_SECRET, imageStorage }));
  app.use('/api/v1/users', createUsersRouter({ database, jwtSecret: JWT_SECRET, imageStorage }));
  const server = await new Promise((resolve) => {
    const s = app.listen(0, '127.0.0.1', () => resolve(s));
  });
  const addr = server.address();
  const baseUrl = `http://127.0.0.1:${addr.port}/api/v1`;
  const token = jwt.sign({ role: 'ADMIN', sessionVersion: 0 }, JWT_SECRET, {
    algorithm: 'HS256',
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    subject: ADMIN_ID,
    expiresIn: 3600,
  });
  try {
    await fn({ baseUrl, token, imageStorage });
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

async function patchUser(baseUrl, token, userId, body) {
  const res = await fetch(`${baseUrl}/admin/users/${userId}`, {
    method: 'PATCH',
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  return { status: res.status, body: await res.json() };
}

test('PATCH /admin/users/:userId updates Member fullName, email, phone, and DB profile fields with USER_UPDATED audit log', async () => {
  const db = createMockDb();
  await withServer(db, async ({ baseUrl, token }) => {
    const res = await patchUser(baseUrl, token, MEMBER_ID, {
      fullName: '  Nguyễn Văn An  ',
      email: '  Member.New@MetaGym.VN ',
      phone: '+84 901 234 567',
      dateOfBirth: '1996-08-20',
      gender: 'FEMALE',
      heightCm: 168.5,
      fitnessGoal: 'Tăng cơ và tăng thể lực',
      experienceLevel: 'INTERMEDIATE',
      activityLevel: 'HIGH',
      dietaryPreferences: 'Chế độ ăn giàu đạm',
    });

    assert.equal(res.status, 200);
    const data = res.body.data;
    assert.equal(data.fullName, 'Nguyễn Văn An');
    assert.equal(data.email, 'member.new@metagym.vn');
    assert.equal(data.phone, '+84 901 234 567');
    assert.equal(data.dateOfBirth, '1996-08-20');
    assert.equal(data.gender, 'FEMALE');
    assert.equal(data.heightCm, 168.5);
    assert.equal(data.fitnessGoal, 'Tăng cơ và tăng thể lực');
    assert.equal(data.experienceLevel, 'INTERMEDIATE');
    assert.equal(data.activityLevel, 'HIGH');
    assert.equal(data.dietaryPreferences, 'Chế độ ăn giàu đạm');

    // Profile object structure
    assert.ok(data.profile);
    assert.equal(data.profile.dateOfBirth, '1996-08-20');
    assert.equal(data.profile.gender, 'FEMALE');

    // T18 Privacy compliance: must NOT expose health/injury notes or passwords
    for (const key of Object.keys(data)) {
      assert.equal(FORBIDDEN_PRIVACY_KEYS.has(key.toLowerCase()), false, `Forbidden privacy key ${key}`);
    }

    assert.equal(db.auditLogs.length, 1);
    assert.equal(db.auditLogs[0].action, 'USER_UPDATED');
    assert.ok(db.auditLogs[0].metadata.changedFields.includes('fullName'));
    assert.ok(db.auditLogs[0].metadata.changedFields.includes('email'));
    assert.ok(db.auditLogs[0].metadata.changedFields.includes('dateOfBirth'));
    assert.ok(db.auditLogs[0].metadata.changedFields.includes('gender'));
    assert.equal(db.auditLogs[0].metadata.before.email, 'member@metagym.vn');
    assert.equal(db.auditLogs[0].metadata.after.email, 'member.new@metagym.vn');

    // Empty string phone clears phone to null
    const clearPhone = await patchUser(baseUrl, token, MEMBER_ID, { phone: '   ' });
    assert.equal(clearPhone.status, 200);
    assert.equal(clearPhone.body.data.phone, null);
  });
});

test('PATCH /admin/users/:userId returns 409 EMAIL_ALREADY_EXISTS on duplicate email without mutating member', async () => {
  const db = createMockDb();
  await withServer(db, async ({ baseUrl, token }) => {
    const res = await patchUser(baseUrl, token, MEMBER_ID, {
      fullName: 'Nguyễn Văn An',
      email: 'TAKEN@metagym.vn',
      phone: '0901234567',
    });

    assert.equal(res.status, 409);
    assert.equal(res.body.error.code, 'EMAIL_ALREADY_EXISTS');
    assert.ok(res.body.error.details.fields.email?.length);
    assert.equal(db.users.get(MEMBER_ID).email, 'member@metagym.vn', 'Rollback must preserve original email');
    assert.equal(db.users.get(MEMBER_ID).full_name, 'Nguyễn Văn A', 'Rollback must preserve original fullName');
  });
});

test('PATCH /admin/users/:userId rejects COACH updating member profile fields, rejects T18 healthNotes', async () => {
  const db = createMockDb();
  await withServer(db, async ({ baseUrl, token }) => {
    // Coach cannot update member_profiles fields
    const coachUpdate = await patchUser(baseUrl, token, COACH_ID, {
      fitnessGoal: 'Mục tiêu của hội viên',
    });
    assert.equal(coachUpdate.status, 422);

    // Forbidden T18 fields return 422
    const privateField = await patchUser(baseUrl, token, MEMBER_ID, { healthNotes: 'bí mật' });
    assert.equal(privateField.status, 422);
    assert.ok(privateField.body.error.details.fields.healthNotes);

    const injuryField = await patchUser(baseUrl, token, MEMBER_ID, { injuryNotes: 'chấn thương' });
    assert.equal(injuryField.status, 422);
    assert.ok(injuryField.body.error.details.fields.injuryNotes);

    // Invalid gender enum
    const badGender = await patchUser(baseUrl, token, MEMBER_ID, { gender: 'UNKNOWN' });
    assert.equal(badGender.status, 422);
    assert.ok(badGender.body.error.details.fields.gender);

    // Invalid height (< 30 or > 300)
    const badHeight = await patchUser(baseUrl, token, MEMBER_ID, { heightCm: 400 });
    assert.equal(badHeight.status, 422);
    assert.ok(badHeight.body.error.details.fields.heightCm);

    // Invalid date of birth format
    const badDob = await patchUser(baseUrl, token, MEMBER_ID, { dateOfBirth: 'invalid-date' });
    assert.equal(badDob.status, 422);
    assert.ok(badDob.body.error.details.fields.dateOfBirth);
  });
});

test('Admin Avatar Management: POST/DELETE /admin/users/:userId/avatar and clear via PATCH avatarMediaId: null', async () => {
  const db = createMockDb();
  await withServer(db, async ({ baseUrl, token, imageStorage }) => {
    // Create a 1x1 valid PNG image buffer
    const pngBuffer = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==', 'base64');

    // 1. Upload Avatar via POST /admin/users/:userId/avatar
    const uploadRes = await fetch(`${baseUrl}/admin/users/${MEMBER_ID}/avatar`, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'image/png',
      },
      body: pngBuffer,
    });

    assert.equal(uploadRes.status, 200);
    const uploadedData = (await uploadRes.json()).data;
    assert.ok(uploadedData.avatarMediaId);
    assert.equal(uploadedData.avatarUrl, `/api/v1/users/${MEMBER_ID}/avatar`);
    assert.equal(uploadedData.avatarThumbnailUrl, `/api/v1/users/${MEMBER_ID}/avatar?size=120`);
    assert.equal(db.users.get(MEMBER_ID).avatar_media_id, uploadedData.avatarMediaId);
    assert.equal(db.auditLogs.some((l) => l.metadata.changedFields.includes('avatarMediaId')), true);

    // Verify media_asset stored with image/webp
    const asset = Array.from(db.mediaAssets.values()).find((a) => a.id === uploadedData.avatarMediaId);
    assert.ok(asset);
    assert.equal(asset.mime_type, 'image/webp');
    assert.equal(asset.original_name, 'avatar.webp');

    // Verify domain-scoped storage keys (users/avatars/... and users/avatars/thumbs/...)
    assert.ok(asset.storage_key.startsWith('users/avatars/'));
    assert.ok(asset.storage_key.endsWith('.webp'));
    assert.ok(imageStorage.store.has(asset.storage_key));
    assert.ok(imageStorage.store.has(asset.storage_key.replace('users/avatars/', 'users/avatars/thumbs/')));

    // Test GET full avatar (512x512 max webp)
    const getFullRes = await fetch(`${baseUrl}/users/${MEMBER_ID}/avatar`);
    assert.equal(getFullRes.status, 200);
    assert.equal(getFullRes.headers.get('content-type'), 'image/webp');
    assert.equal(getFullRes.headers.get('etag'), `"${uploadedData.avatarMediaId}"`);

    // Test GET thumbnail avatar (120x120 webp)
    const getThumbRes = await fetch(`${baseUrl}/users/${MEMBER_ID}/avatar?size=120`);
    assert.equal(getThumbRes.status, 200);
    assert.equal(getThumbRes.headers.get('content-type'), 'image/webp');
    assert.equal(getThumbRes.headers.get('etag'), `"${uploadedData.avatarMediaId}-120"`);

    // Test 304 Not Modified
    const notModifiedRes = await fetch(`${baseUrl}/users/${MEMBER_ID}/avatar?size=120`, {
      headers: { 'if-none-match': `"${uploadedData.avatarMediaId}-120"` },
    });
    assert.equal(notModifiedRes.status, 304);

    // 2. Delete Avatar via DELETE /admin/users/:userId/avatar -> purges DB row AND Storage objects
    const thumbKey1 = asset.storage_key.replace('users/avatars/', 'users/avatars/thumbs/');
    const deleteRes = await fetch(`${baseUrl}/admin/users/${MEMBER_ID}/avatar`, {
      method: 'DELETE',
      headers: { authorization: `Bearer ${token}` },
    });
    assert.equal(deleteRes.status, 200);
    const deletedData = (await deleteRes.json()).data;
    assert.equal(deletedData.avatarMediaId, null);
    assert.equal(deletedData.avatarUrl, null);
    assert.equal(db.users.get(MEMBER_ID).avatar_media_id, null);
    assert.equal(db.mediaAssets.has(asset.id), false, 'Old avatar DB row must be deleted');
    assert.equal(imageStorage.store.has(asset.storage_key), false, 'Old full avatar must be deleted from storage');
    assert.equal(imageStorage.store.has(thumbKey1), false, 'Old thumbnail must be deleted from storage');

    // 3. Re-upload new avatar, then replace with another avatar -> old files & DB row must be purged automatically
    const upload2Res = await fetch(`${baseUrl}/admin/users/${MEMBER_ID}/avatar`, {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'image/png' },
      body: pngBuffer,
    });
    assert.equal(upload2Res.status, 200);
    const asset2 = Array.from(db.mediaAssets.values()).find((a) => a.id === (db.users.get(MEMBER_ID).avatar_media_id));
    assert.ok(asset2);

    const upload3Res = await fetch(`${baseUrl}/admin/users/${MEMBER_ID}/avatar`, {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'image/png' },
      body: pngBuffer,
    });
    assert.equal(upload3Res.status, 200);
    const asset3 = Array.from(db.mediaAssets.values()).find((a) => a.id === (db.users.get(MEMBER_ID).avatar_media_id));
    assert.ok(asset3);
    assert.equal(db.mediaAssets.has(asset2.id), false, 'Replaced avatar DB row must be deleted');
    assert.equal(imageStorage.store.has(asset2.storage_key), false, 'Replaced full avatar must be removed from storage');
    assert.equal(imageStorage.store.has(asset2.storage_key.replace('users/avatars/', 'users/avatars/thumbs/')), false);
    assert.equal(imageStorage.store.has(asset3.storage_key), true);

    // 4. Clear avatar via PATCH avatarMediaId: null ("Gỡ ảnh" + "Lưu thay đổi") -> purges DB row AND Storage objects
    const clearAvatar = await patchUser(baseUrl, token, MEMBER_ID, { avatarMediaId: null });
    assert.equal(clearAvatar.status, 200);
    assert.equal(clearAvatar.body.data.avatarMediaId, null);
    assert.equal(clearAvatar.body.data.avatarUrl, null);
    assert.equal(db.mediaAssets.has(asset3.id), false, 'PATCH null must delete AVATAR row from media_assets');
    assert.equal(imageStorage.store.has(asset3.storage_key), false, 'PATCH null must delete full avatar from storage');
    assert.equal(imageStorage.store.has(asset3.storage_key.replace('users/avatars/', 'users/avatars/thumbs/')), false);
    assert.equal(imageStorage.store.size, 0, 'Storage must have zero leftover avatar files');
  });
});

test('PATCH /admin/users/:coachId updates Coach email, phone, and coach_profiles fields while rejecting member fields', async () => {
  const db = createMockDb();
  await withServer(db, async ({ baseUrl, token, imageStorage }) => {
    const res = await patchUser(baseUrl, token, COACH_ID, {
      fullName: 'Trần Hoàng HLV',
      email: 'coach.updated@metagym.vn',
      phone: '0911223344',
      experienceYears: 7,
      qualifications: 'NASM-CPT, HLV Quốc gia',
      specialties: ['Tăng cơ', 'Calisthenics', 'Giảm mỡ'],
      availabilityNote: 'Thứ 2 – Thứ 7 · 06:00 – 20:00',
      biography: 'Chuyên gia huấn luyện sức mạnh và phục hồi tư thế.',
    });

    assert.equal(res.status, 200);
    const data = res.body.data;
    assert.equal(data.fullName, 'Trần Hoàng HLV');
    assert.equal(data.email, 'coach.updated@metagym.vn');
    assert.equal(data.phone, '0911223344');
    assert.equal(data.memberLimit, 8);
    assert.equal(data.experienceYears, 7);
    assert.equal(data.qualifications, 'NASM-CPT, HLV Quốc gia');
    assert.deepEqual(data.specialties, ['Tăng cơ', 'Calisthenics', 'Giảm mỡ']);
    assert.equal(data.availabilityNote, 'Thứ 2 – Thứ 7 · 06:00 – 20:00');
    assert.equal(data.biography, 'Chuyên gia huấn luyện sức mạnh và phục hồi tư thế.');
    assert.equal(data.profile.memberLimit, 8);

    // Audit log records changed Coach fields
    const latestAudit = db.auditLogs[db.auditLogs.length - 1];
    assert.equal(latestAudit.action, 'USER_UPDATED');
    assert.ok(latestAudit.metadata.changedFields.includes('experienceYears'));
    assert.ok(latestAudit.metadata.changedFields.includes('specialties'));

    // Rejects unknown memberLimit mutation and coach field on MEMBER
    assert.equal((await patchUser(baseUrl, token, COACH_ID, { memberLimit: 12 })).status, 422);
    assert.equal((await patchUser(baseUrl, token, MEMBER_ID, { biography: 'Không hợp lệ cho Member' })).status, 422);

    // Coach Avatar upload & removal cleans DB + Storage
    const pngBuffer = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==', 'base64');
    const up = await fetch(`${baseUrl}/admin/users/${COACH_ID}/avatar`, {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'image/png' },
      body: pngBuffer,
    });
    assert.equal(up.status, 200);
    assert.equal(imageStorage.store.size, 2);

    const rm = await patchUser(baseUrl, token, COACH_ID, { avatarMediaId: null });
    assert.equal(rm.status, 200);
    assert.equal(rm.body.data.avatarMediaId, null);
    assert.equal(imageStorage.store.size, 0);
  });
});
