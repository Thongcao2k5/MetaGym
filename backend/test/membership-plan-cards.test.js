import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import sharp from 'sharp';

import { createApp } from '../src/app.js';
import { processPackageImages } from '../src/modules/media/image-processor.js';
import { evaluatePlanSaleWindow } from '../src/modules/memberships/membership-plans.routes.js';
import { isSecondaryVariantKey } from '../src/modules/media/supabase-sync.js';
import {
  buildPackageStorageKeys,
  resolvePackageThumbKeys,
  resolveThumbKeys,
} from '../src/storage/storage-key.js';

const SECRET = 'membership-plan-cards-test-secret-32chars';

function adminToken(id) {
  return jwt.sign({ role: 'ADMIN', sessionVersion: 0 }, SECRET, {
    algorithm: 'HS256',
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    subject: id,
    expiresIn: 3600,
  });
}

test('Package storage keys, thumbnail resolvers, and WebP processor work cleanly', async () => {
  const mediaId = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';
  assert.deepEqual(buildPackageStorageKeys(mediaId), {
    storageKey: `packages/${mediaId}.webp`,
    thumbKey: `packages/thumbs/${mediaId}.webp`,
  });
  assert.deepEqual(resolvePackageThumbKeys(`packages/${mediaId}.webp`), [
    `packages/thumbs/${mediaId}.webp`,
  ]);
  assert.deepEqual(resolveThumbKeys(`packages/${mediaId}.webp`), [
    `packages/thumbs/${mediaId}.webp`,
  ]);
  assert.equal(isSecondaryVariantKey(`packages/thumbs/${mediaId}.webp`), true);
  assert.equal(isSecondaryVariantKey(`packages/${mediaId}.webp`), false);

  const sampleCard = await sharp({
    create: { width: 900, height: 1426, channels: 3, background: { r: 180, g: 120, b: 60 } },
  }).jpeg().toBuffer();

  const processed = await processPackageImages(sampleCard);
  assert.equal(processed.mimeType, 'image/webp');
  assert.ok(processed.full.width <= 960 && processed.full.height <= 960);
  assert.ok(processed.thumb.width <= 240 && processed.thumb.height <= 240);
  assert.ok(processed.thumb.height > processed.thumb.width, 'Portrait card keeps portrait aspect');
});

test('Membership plan card routes upload WebP PACKAGE media, serve ?size=120 thumbnails, enforce max 3 highlights, and clean DB+Storage on replace/remove', async () => {
  const adminId = randomUUID();
  const planId = randomUUID();
  const oldBackId = randomUUID();
  const newFrontIdRef = { id: null };

  const stored = new Map();
  const removedKeys = [];
  const deletedMediaIds = [];
  const deletedImageKeys = [];

  const oldBackKey = `packages/${oldBackId}.webp`;
  const oldBackThumbKey = `packages/thumbs/${oldBackId}.webp`;
  stored.set(oldBackKey, { bytes: Buffer.from('old-back'), contentType: 'image/webp' });
  stored.set(oldBackThumbKey, { bytes: Buffer.from('old-thumb'), contentType: 'image/webp' });

  const mediaRows = new Map([
    [oldBackId, {
      id: oldBackId,
      owner_id: adminId,
      purpose: 'PACKAGE',
      access_scope: 'PUBLIC',
      storage_key: oldBackKey,
      mime_type: 'image/webp',
      status: 'READY',
    }],
  ]);

  let planRow = {
    id: planId,
    name: 'Gói Đồng 1 Tháng',
    description: 'Gói phòng tập cơ bản',
    price: 550000,
    duration_days: 30,
    status: 'ACTIVE',
    card_tier: 'BRONZE',
    front_media_id: null,
    back_media_id: oldBackId,
    card_highlights: ['Dòng 1', 'Dòng 2', 'Dòng 3'],
    active_membership_count: 2,
    scheduled_membership_count: 0,
  };

  const runQuery = async (sql, params = []) => {
    const text = String(sql).replace(/\s+/g, ' ').trim();
    if (text === 'BEGIN' || text === 'COMMIT' || text === 'ROLLBACK' || text.startsWith('SAVEPOINT') || text.startsWith('RELEASE SAVEPOINT') || text.startsWith('ROLLBACK TO SAVEPOINT')) {
      return { rows: [], rowCount: 0 };
    }
    if (text.includes('FROM users u') && text.includes('WHERE u.id = $1')) {
      return {
        rows: [{
          id: adminId,
          email: 'admin@metagym.vn',
          full_name: 'Meta Admin',
          phone: null,
          role: 'ADMIN',
          status: 'ACTIVE',
          avatar_media_id: null,
          session_version: 0,
        }],
      };
    }
    if (text.includes('SELECT id FROM users WHERE id = $1 AND role = \'ADMIN\'')) {
      return { rows: [{ id: adminId }] };
    }
    if (text.includes('FROM membership_plans') && text.includes('WHERE id = $1')) {
      if (params[0] === planId) return { rows: [{ ...planRow }] };
      return { rows: [] };
    }
    if (text.includes('INSERT INTO media_assets')) {
      const [id, ownerId, purpose, accessScope, storageKey] = params;
      mediaRows.set(id, {
        id,
        owner_id: ownerId,
        purpose,
        access_scope: accessScope,
        storage_key: storageKey,
        status: 'UPLOADING',
      });
      return { rows: [], rowCount: 1 };
    }
    if (text.includes('UPDATE media_assets SET status = \'READY\'')) {
      const [mimeType, sizeBytes, width, height, id] = params;
      const item = mediaRows.get(id);
      if (item) {
        item.status = 'READY';
        item.mime_type = mimeType;
        item.size_bytes = sizeBytes;
        item.width = width;
        item.height = height;
      }
      return { rows: [], rowCount: 1 };
    }
    if (text.startsWith('SELECT ') && text.includes('FROM media_assets') && text.includes('status = \'READY\'') && text.includes('purpose = ANY')) {
      const item = mediaRows.get(params[0]);
      if (item && item.status === 'READY' && item.access_scope === 'PUBLIC') {
        return { rows: [{ storage_key: item.storage_key, mime_type: item.mime_type }] };
      }
      return { rows: [] };
    }
    if (text.startsWith('SELECT ') && text.includes('FROM media_assets') && text.includes('purpose = \'PACKAGE\'')) {
      const item = mediaRows.get(params[0]);
      if (item && item.status === 'READY' && item.access_scope === 'PUBLIC' && item.purpose === 'PACKAGE') {
        return { rows: [item] };
      }
      return { rows: [] };
    }
    if (text.startsWith('SELECT ') && text.includes('FROM media_assets') && text.includes('WHERE id = $1')) {
      const item = mediaRows.get(params[0]);
      if (item && item.purpose === params[1]) return { rows: [item] };
      return { rows: [] };
    }
    if (text.includes('SELECT 1 FROM membership_plans WHERE front_media_id = $1 OR back_media_id = $1')) {
      const targetId = params[0];
      const used = planRow.front_media_id === targetId || planRow.back_media_id === targetId;
      return { rows: used ? [{ '?column?': 1 }] : [] };
    }
    if (text.startsWith('UPDATE membership_plans SET')) {
      const colMatch = text.slice('UPDATE membership_plans SET '.length, text.indexOf(' WHERE ')).split(',').map((s) => s.trim().split(' = ')[0]);
      colMatch.forEach((col, i) => {
        planRow[col] = params[i];
      });
      return { rows: [], rowCount: 1 };
    }
    if (text.startsWith('DELETE FROM images WHERE storage_key = $1')) {
      deletedImageKeys.push(params[0]);
      return { rows: [], rowCount: 1 };
    }
    if (text.startsWith('DELETE FROM media_assets WHERE id = $1')) {
      deletedMediaIds.push(params[0]);
      mediaRows.delete(params[0]);
      return { rows: [], rowCount: 1 };
    }
    if (text.includes('INSERT INTO admin_audit_logs')) {
      return { rows: [], rowCount: 1 };
    }
    return { rows: [] };
  };

  const database = {
    query: runQuery,
    connect: async () => ({ query: runQuery, release() {} }),
  };

  const imageStorage = {
    async put(key, bytes, contentType) {
      stored.set(key, { bytes, contentType });
    },
    async get(key) {
      const entry = stored.get(key);
      if (!entry) throw new Error('ENOENT');
      return entry.bytes;
    },
    async remove(key) {
      removedKeys.push(key);
      stored.delete(key);
    },
  };

  const app = createApp({ database, jwtSecret: SECRET, imageStorage });
  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  const bearer = adminToken(adminId);

  try {
    const samplePng = await sharp({
      create: { width: 400, height: 640, channels: 3, background: { r: 220, g: 140, b: 70 } },
    }).png().toBuffer();

    const uploadRes = await fetch(`${base}/api/v1/media/images`, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${bearer}`,
        'content-type': 'image/png',
        'x-image-purpose': 'PACKAGE',
        'x-file-name': 'card-bronze-front.png',
      },
      body: samplePng,
    });
    assert.equal(uploadRes.status, 201);
    const uploadJson = await uploadRes.json();
    newFrontIdRef.id = uploadJson.data.id;
    assert.equal(uploadJson.data.mimeType, 'image/webp');
    assert.ok(stored.has(`packages/${newFrontIdRef.id}.webp`));
    assert.ok(stored.has(`packages/thumbs/${newFrontIdRef.id}.webp`));

    const thumbRes = await fetch(`${base}/api/v1/media/public/${newFrontIdRef.id}?size=120`);
    assert.equal(thumbRes.status, 200);
    assert.equal(thumbRes.headers.get('etag'), `"${newFrontIdRef.id}-120"`);

    const tooManyHlRes = await fetch(`${base}/api/v1/admin/membership-plans/${planId}`, {
      method: 'PATCH',
      headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' },
      body: JSON.stringify({ cardHighlights: ['1', '2', '3', '4'] }),
    });
    assert.equal(tooManyHlRes.status, 422);

    const patchRes = await fetch(`${base}/api/v1/admin/membership-plans/${planId}`, {
      method: 'PATCH',
      headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        frontMediaId: newFrontIdRef.id,
        backMediaId: null,
        cardHighlights: ['Thẻ Đồng NFC', 'Full khu máy', 'x1.0 điểm thưởng'],
      }),
    });
    assert.equal(patchRes.status, 200);
    const patched = await patchRes.json();
    assert.equal(patched.data.frontMediaId, newFrontIdRef.id);
    assert.equal(patched.data.backMediaId, null);
    assert.deepEqual(patched.data.cardHighlights, ['Thẻ Đồng NFC', 'Full khu máy', 'x1.0 điểm thưởng']);

    assert.equal(deletedMediaIds.includes(oldBackId), true);
    assert.equal(deletedImageKeys.includes(oldBackKey), true);
    assert.equal(removedKeys.includes(oldBackKey), true);
    assert.equal(removedKeys.includes(oldBackThumbKey), true);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('Membership plan sale window blocks invalid date ranges, upcoming plans, and ended plans at quote/checkout/front-desk', async () => {
  const now = Date.parse('2026-11-28T07:00:00.000Z');
  assert.equal(evaluatePlanSaleWindow({ status: 'INACTIVE' }, now).salePhase, 'INACTIVE');
  assert.equal(evaluatePlanSaleWindow({ status: 'ACTIVE', sales_start_at: '2026-11-29T00:00:00.000Z' }, now).salePhase, 'UPCOMING');
  assert.equal(evaluatePlanSaleWindow({ status: 'ACTIVE', sales_end_at: '2026-11-27T23:59:59.000Z' }, now).salePhase, 'ENDED');
  assert.equal(evaluatePlanSaleWindow({
    status: 'ACTIVE',
    sales_start_at: '2026-11-28T00:00:00.000Z',
    sales_end_at: '2026-11-30T00:00:00.000Z',
  }, now).isOnSale, true);

  const adminId = randomUUID();
  const memberId = randomUUID();
  const upcomingPlanId = randomUUID();
  const endedPlanId = randomUUID();

  const plans = new Map([
    [upcomingPlanId, {
      id: upcomingPlanId,
      name: 'Đợt Noel Sắp Mở',
      description: 'Mở bán tháng 12',
      price: 490000,
      duration_days: 30,
      status: 'ACTIVE',
      sales_start_at: new Date(Date.now() + 86400_000).toISOString(),
      sales_end_at: new Date(Date.now() + 7 * 86400_000).toISOString(),
      card_tier: 'GOLD',
      front_media_id: null,
      back_media_id: null,
      card_highlights: [],
    }],
    [endedPlanId, {
      id: endedPlanId,
      name: 'Đợt Black Friday Đã Đóng',
      description: 'Hết hạn mua',
      price: 390000,
      duration_days: 30,
      status: 'ACTIVE',
      sales_start_at: new Date(Date.now() - 7 * 86400_000).toISOString(),
      sales_end_at: new Date(Date.now() - 60_000).toISOString(),
      card_tier: 'BRONZE',
      front_media_id: null,
      back_media_id: null,
      card_highlights: [],
    }],
  ]);

  let publicQuerySql = '';
  const runQuery = async (sql, params = []) => {
    const text = String(sql).replace(/\s+/g, ' ').trim();
    if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(text)) return { rows: [], rowCount: 0 };
    if (text.includes('FROM users u') && text.includes('WHERE u.id = $1')) {
      const id = params[0];
      const role = id === adminId ? 'ADMIN' : 'MEMBER';
      return {
        rows: [{ id, email: `${role}@metagym.vn`, full_name: role, phone: null, role, status: 'ACTIVE', avatar_media_id: null, session_version: 0 }],
      };
    }
    if (text.includes('SELECT id FROM users WHERE id = $1 AND role =')) {
      return { rows: [{ id: params[0] }] };
    }
    if (text.includes('SELECT * FROM payments WHERE created_by = $1')) {
      return { rows: [] };
    }
    if (text.includes('SELECT count(*)::int AS count FROM membership_plans WHERE')) {
      publicQuerySql = text;
      return { rows: [{ count: 0 }] };
    }
    if (text.includes('FROM membership_plans WHERE status = \'ACTIVE\'') && text.includes('sales_start_at <= now()')) {
      publicQuerySql = text;
      return { rows: [] };
    }
    if (text.includes('FROM membership_plans') && text.includes('WHERE id = $1')) {
      const p = plans.get(params[0]);
      return { rows: p ? [p] : [] };
    }
    return { rows: [] };
  };

  const app = createApp({
    database: { query: runQuery, connect: async () => ({ query: runQuery, release() {} }) },
    jwtSecret: SECRET,
  });
  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  const admBearer = adminToken(adminId);
  const memBearer = jwt.sign({ role: 'MEMBER', sessionVersion: 0 }, SECRET, {
    algorithm: 'HS256',
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    subject: memberId,
    expiresIn: 3600,
  });

  try {
    const publicList = await fetch(`${base}/api/v1/membership-plans`);
    assert.equal(publicList.status, 200);
    assert.equal(publicQuerySql.includes('sales_start_at <= now()'), true);
    assert.equal(publicQuerySql.includes('sales_end_at >= now()'), true);

    const badRange = await fetch(`${base}/api/v1/admin/membership-plans/${upcomingPlanId}`, {
      method: 'PATCH',
      headers: { authorization: `Bearer ${admBearer}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        salesStartAt: '2026-12-10T00:00:00.000Z',
        salesEndAt: '2026-12-01T00:00:00.000Z',
      }),
    });
    assert.equal(badRange.status, 422);

    const quoteUpcoming = await fetch(`${base}/api/v1/membership-plans/${upcomingPlanId}/quote`, {
      headers: { authorization: `Bearer ${memBearer}` },
    });
    assert.equal(quoteUpcoming.status, 409);
    assert.equal((await quoteUpcoming.json()).error.code, 'PLAN_OUTSIDE_SALE_WINDOW');

    const payEnded = await fetch(`${base}/api/v1/payments`, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${memBearer}`,
        'content-type': 'application/json',
        'idempotency-key': randomUUID(),
      },
      body: JSON.stringify({ planId: endedPlanId, method: 'MOCK_QR' }),
    });
    assert.equal(payEnded.status, 409);
    assert.equal((await payEnded.json()).error.code, 'PLAN_OUTSIDE_SALE_WINDOW');

    const deskEnded = await fetch(`${base}/api/v1/admin/front-desk-payments`, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${admBearer}`,
        'content-type': 'application/json',
        'idempotency-key': randomUUID(),
      },
      body: JSON.stringify({ memberId, planId: endedPlanId }),
    });
    assert.equal(deskEnded.status, 409);
    assert.equal((await deskEnded.json()).error.code, 'PLAN_OUTSIDE_SALE_WINDOW');
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
