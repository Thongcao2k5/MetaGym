import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import sharp from 'sharp';

import { createApp } from '../src/app.js';
import { computeVoucherDiscount } from '../src/modules/payments/voucher-calculator.js';
import { buildVoucherStorageKeys, resolveThumbKeys } from '../src/storage/storage-key.js';

const SECRET = 'vouchers-test-secret-with-32-characters';

function tokenFor(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, SECRET, {
    algorithm: 'HS256',
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    subject: id,
    expiresIn: 3600,
  });
}

test('computeVoucherDiscount enforces fixed VND, percent with cap, conditions, and time window', () => {
  const fixedVoucher = {
    code: 'FIXED150',
    discount_type: 'FIXED_AMOUNT',
    discount_value: 150000,
    max_discount_amount: null,
    apply_scope: 'GYM_PLAN',
    target_member_scope: 'NEW_MEMBER',
    min_order_amount: 500000,
    max_total_uses: 100,
    max_uses_per_member: 1,
    used_count: 10,
    starts_at: new Date(Date.now() - 60000).toISOString(),
    ends_at: new Date(Date.now() + 86400000).toISOString(),
    status: 'ACTIVE',
  };

  assert.deepEqual(
    computeVoucherDiscount({ voucher: fixedVoucher, orderAmount: 1000000, scope: 'GYM_PLAN', memberHasPriorSuccessPayment: false }),
    { valid: true, originalAmount: 1000000, discountAmount: 150000, finalAmount: 850000 },
  );

  // Rejects renewal member on NEW_MEMBER voucher
  assert.equal(
    computeVoucherDiscount({ voucher: fixedVoucher, orderAmount: 1000000, scope: 'GYM_PLAN', memberHasPriorSuccessPayment: true }).code,
    'VOUCHER_NEW_MEMBER_ONLY',
  );

  // Rejects Coach package scope on GYM_PLAN voucher
  assert.equal(
    computeVoucherDiscount({ voucher: fixedVoucher, orderAmount: 1000000, scope: 'COACH_PACKAGE' }).code,
    'VOUCHER_SCOPE_MISMATCH',
  );

  const percentVoucher = {
    code: 'SALE20',
    discount_type: 'PERCENT',
    discount_value: 20,
    max_discount_amount: 300000,
    apply_scope: 'ALL',
    target_member_scope: 'ALL',
    min_order_amount: 800000,
    max_total_uses: 50,
    max_uses_per_member: 2,
    used_count: 5,
    status: 'ACTIVE',
  };

  // 20% of 2,000,000 = 400,000 -> capped at 300,000
  assert.deepEqual(
    computeVoucherDiscount({ voucher: percentVoucher, orderAmount: 2000000, scope: 'COACH_PACKAGE' }),
    { valid: true, originalAmount: 2000000, discountAmount: 300000, finalAmount: 1700000 },
  );
  // Below minimum order -> rejected
  assert.equal(
    computeVoucherDiscount({ voucher: percentVoucher, orderAmount: 500000, scope: 'GYM_PLAN' }).code,
    'VOUCHER_MIN_ORDER_NOT_MET',
  );
});

test('Voucher routes manage VOUCHER WebP images, CRUD, preview, and DB+Storage delete cleanup', async () => {
  const adminId = randomUUID();
  const memberId = randomUUID();
  const planId = randomUUID();

  const stored = new Map();
  const removedKeys = [];
  const mediaRows = new Map();
  const voucherRows = new Map();

  assert.deepEqual(buildVoucherStorageKeys('abc'), {
    storageKey: 'marketing/vouchers/abc.webp',
    thumbKey: 'marketing/vouchers/thumbs/abc.webp',
  });
  assert.deepEqual(resolveThumbKeys('marketing/vouchers/abc.webp'), ['marketing/vouchers/thumbs/abc.webp']);

  const runQuery = async (sql, params = []) => {
    const text = String(sql).replace(/\s+/g, ' ').trim();
    if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(text) || text.startsWith('SAVEPOINT') || text.startsWith('RELEASE SAVEPOINT') || text.startsWith('ROLLBACK TO SAVEPOINT')) {
      return { rows: [], rowCount: 0 };
    }
    if (text.includes('FROM users u') && text.includes('WHERE u.id = $1')) {
      const id = params[0];
      const role = id === adminId ? 'ADMIN' : 'MEMBER';
      return { rows: [{ id, email: `${role}@metagym.vn`, full_name: role, role, status: 'ACTIVE', session_version: 0 }] };
    }
    if (text.includes('WHERE id = $1 AND role = \'ADMIN\'')) {
      return { rows: params[0] === adminId ? [{ id: adminId }] : [] };
    }
    if (text.includes('INSERT INTO media_assets')) {
      const [id, ownerId, purpose, accessScope, storageKey] = params;
      mediaRows.set(id, { id, owner_id: ownerId, purpose, access_scope: accessScope, storage_key: storageKey, status: 'UPLOADING' });
      return { rows: [], rowCount: 1 };
    }
    if (text.includes('UPDATE media_assets SET status = \'READY\'')) {
      const [mimeType, sizeBytes, width, height, id] = params;
      const m = mediaRows.get(id);
      if (m) Object.assign(m, { status: 'READY', mime_type: mimeType, size_bytes: sizeBytes, width, height });
      return { rows: [], rowCount: 1 };
    }
    if (text.startsWith('SELECT id FROM media_assets WHERE id = $1')) {
      const m = mediaRows.get(params[0]);
      return { rows: m && m.purpose === 'VOUCHER' && m.status === 'READY' ? [{ id: m.id }] : [] };
    }
    if (text.startsWith('SELECT id, storage_key, purpose FROM media_assets WHERE id = $1')) {
      const m = mediaRows.get(params[0]);
      return { rows: m && m.purpose === params[1] ? [m] : [] };
    }
    if (text.startsWith('DELETE FROM images WHERE storage_key = $1')) return { rows: [], rowCount: 1 };
    if (text.startsWith('DELETE FROM media_assets WHERE id = $1')) {
      mediaRows.delete(params[0]);
      return { rows: [], rowCount: 1 };
    }
    if (text.startsWith('INSERT INTO vouchers')) {
      const [
        id, code, title, description, imageMediaId, discountType, discountValue,
        maxDiscountAmount, applyScope, targetPlanId, targetMemberScope,
        minOrderAmount, maxTotalUses, maxUsesPerMember, startsAt, endsAt, status, createdBy,
      ] = params;
      voucherRows.set(id, {
        id, code, title, description, image_media_id: imageMediaId, discount_type: discountType,
        discount_value: discountValue, max_discount_amount: maxDiscountAmount,
        apply_scope: applyScope, target_plan_id: targetPlanId, target_member_scope: targetMemberScope,
        min_order_amount: minOrderAmount, max_total_uses: maxTotalUses, max_uses_per_member: maxUsesPerMember,
        used_count: 0, starts_at: startsAt, ends_at: endsAt, status, created_by: createdBy,
        created_at: new Date().toISOString(), updated_at: new Date().toISOString(),
      });
      return { rows: [], rowCount: 1 };
    }
    if (text.includes('FROM vouchers v LEFT JOIN membership_plans mp') && text.includes('WHERE v.id = $1')) {
      const v = voucherRows.get(params[0]);
      return { rows: v ? [v] : [] };
    }
    if (text.includes('FROM vouchers v LEFT JOIN membership_plans mp') && text.includes('WHERE upper(v.code) = $1')) {
      const found = [...voucherRows.values()].find((v) => v.code === params[0]);
      return { rows: found ? [found] : [] };
    }
    if (text.startsWith('SELECT price FROM membership_plans WHERE id = $1')) {
      return { rows: params[0] === planId ? [{ price: 1000000 }] : [] };
    }
    if (text.startsWith('DELETE FROM vouchers WHERE id = $1')) {
      voucherRows.delete(params[0]);
      return { rows: [], rowCount: 1 };
    }
    if (text.includes('FROM vouchers') && text.includes('total_vouchers')) {
      return { rows: [{ total_vouchers: voucherRows.size, active_now_count: voucherRows.size, upcoming_count: 0, total_used_count: 0 }] };
    }
    if (text.startsWith('SELECT count(*)::int AS count FROM vouchers')) {
      return { rows: [{ count: voucherRows.size }] };
    }
    if (text.includes('FROM vouchers v') && text.includes('LIMIT')) {
      return { rows: [...voucherRows.values()] };
    }
    return { rows: [] };
  };

  const app = createApp({
    database: { query: runQuery, connect: async () => ({ query: runQuery, release() {} }) },
    jwtSecret: SECRET,
    imageStorage: {
      async put(key, bytes, ct) { stored.set(key, { bytes, ct }); },
      async get(key) {
        const v = stored.get(key);
        if (!v) throw new Error('ENOENT');
        return v.bytes;
      },
      async remove(key) { removedKeys.push(key); stored.delete(key); },
    },
  });

  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  const adminTok = tokenFor(adminId, 'ADMIN');
  const memberTok = tokenFor(memberId, 'MEMBER');

  try {
    // Upload VOUCHER WebP image
    const pngBytes = await sharp({ create: { width: 400, height: 220, channels: 4, background: { r: 255, g: 94, b: 54, alpha: 1 } } }).png().toBuffer();
    const upRes = await fetch(`${base}/api/v1/media/images`, {
      method: 'POST',
      headers: { authorization: `Bearer ${adminTok}`, 'content-type': 'image/png', 'x-image-purpose': 'VOUCHER', 'x-file-name': 'promo.png' },
      body: pngBytes,
    });
    assert.equal(upRes.status, 201);
    const mediaId = (await upRes.json()).data.id;
    assert.equal(stored.has(`marketing/vouchers/${mediaId}.webp`), true);
    assert.equal(stored.has(`marketing/vouchers/thumbs/${mediaId}.webp`), true);

    // Create PERCENT voucher
    const createRes = await fetch(`${base}/api/v1/admin/vouchers`, {
      method: 'POST',
      headers: { authorization: `Bearer ${adminTok}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        code: 'tangbi20',
        title: 'Giảm 20% gói Gym',
        imageMediaId: mediaId,
        discountType: 'PERCENT',
        discountValue: 20,
        maxDiscountAmount: 150000,
        applyScope: 'GYM_PLAN',
        minOrderAmount: 500000,
      }),
    });
    assert.equal(createRes.status, 201);
    const created = (await createRes.json()).data;
    assert.equal(created.code, 'TANGBI20');

    // Member previews voucher -> 20% of 1,000,000 = 200,000 capped at 150,000 -> final 850,000
    const prevRes = await fetch(`${base}/api/v1/vouchers/preview`, {
      method: 'POST',
      headers: { authorization: `Bearer ${memberTok}`, 'content-type': 'application/json' },
      body: JSON.stringify({ code: 'TANGBI20', planId, scope: 'GYM_PLAN' }),
    });
    assert.equal(prevRes.status, 200);
    const prevJson = (await prevRes.json()).data;
    assert.equal(prevJson.discountAmount, 150000);
    assert.equal(prevJson.finalAmount, 850000);

    // Delete unused voucher -> purges DB + Supabase Storage original & thumb
    const delRes = await fetch(`${base}/api/v1/admin/vouchers/${created.id}`, {
      method: 'DELETE',
      headers: { authorization: `Bearer ${adminTok}` },
    });
    assert.equal(delRes.status, 200);
    assert.equal(stored.size, 0);
    assert.equal(removedKeys.includes(`marketing/vouchers/${mediaId}.webp`), true);
    assert.equal(removedKeys.includes(`marketing/vouchers/thumbs/${mediaId}.webp`), true);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
