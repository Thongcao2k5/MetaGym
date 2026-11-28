import 'dotenv/config';
import { randomUUID } from 'node:crypto';
import pg from 'pg';

import { processPackageImages } from '../src/modules/media/image-processor.js';
import { prepareMediaAssetCleanup } from '../src/modules/media/media-cleanup.js';
import { syncSupabaseToImageLibrary } from '../src/modules/media/supabase-sync.js';
import { createImageStorageFromEnv } from '../src/storage/image-storage.js';
import { buildVoucherStorageKeys } from '../src/storage/storage-key.js';

function escapeXml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
}

function buildVoucherSvg({ code, title, discountBadge, subtitle, accent, accentSoft, conditionTag }) {
  const safeCode = escapeXml(code);
  const safeTitle = escapeXml(title);
  const safeBadge = escapeXml(discountBadge);
  const safeSub = escapeXml(subtitle);
  const safeCond = escapeXml(conditionTag);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="800" height="440" viewBox="0 0 800 440">
    <defs>
      <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0%" stop-color="#141820"/>
        <stop offset="55%" stop-color="#1B212D"/>
        <stop offset="100%" stop-color="${accentSoft}"/>
      </linearGradient>
      <linearGradient id="pill" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0%" stop-color="${accent}"/>
        <stop offset="100%" stop-color="#E84E27"/>
      </linearGradient>
    </defs>
    <rect width="800" height="440" rx="28" fill="url(#bg)"/>
    <circle cx="705" cy="95" r="145" fill="${accent}" opacity="0.14"/>
    <circle cx="95" cy="390" r="110" fill="${accent}" opacity="0.09"/>
    <rect x="28" y="28" width="744" height="384" rx="22" fill="none" stroke="rgba(255,255,255,0.12)" stroke-width="1.5"/>
    <line x1="535" y1="52" x2="535" y2="388" stroke="rgba(255,255,255,0.16)" stroke-width="2" stroke-dasharray="9 9"/>
    <circle cx="535" cy="28" r="16" fill="#0F1115"/>
    <circle cx="535" cy="412" r="16" fill="#0F1115"/>

    <rect x="56" y="56" width="160" height="32" rx="16" fill="rgba(255,94,54,0.16)" stroke="${accent}" stroke-opacity="0.5"/>
    <text x="136" y="77" text-anchor="middle" font-family="Arial, sans-serif" font-size="13" font-weight="700" fill="#F7F9FC" letter-spacing="1.4">META GYM VOUCHER</text>

    <text x="56" y="150" font-family="Arial, sans-serif" font-size="30" font-weight="800" fill="#F7F9FC">${safeTitle}</text>
    <text x="56" y="192" font-family="Arial, sans-serif" font-size="18" font-weight="500" fill="#A9B3C4">${safeSub}</text>

    <rect x="56" y="246" width="248" height="40" rx="10" fill="#0F1115" stroke="rgba(255,255,255,0.18)"/>
    <text x="180" y="272" text-anchor="middle" font-family="monospace" font-size="18" font-weight="700" fill="${accent}" letter-spacing="1.6">${safeCode}</text>

    <text x="56" y="344" font-family="Arial, sans-serif" font-size="15" font-weight="600" fill="#D5DFEE">${safeCond}</text>

    <rect x="565" y="112" width="184" height="90" rx="18" fill="url(#pill)"/>
    <text x="657" y="152" text-anchor="middle" font-family="Arial, sans-serif" font-size="13" font-weight="700" fill="#FFFFFF" opacity="0.9">ƯU ĐÃI GIẢM</text>
    <text x="657" y="185" text-anchor="middle" font-family="Arial, sans-serif" font-size="28" font-weight="800" fill="#FFFFFF">${safeBadge}</text>

    <text x="657" y="264" text-anchor="middle" font-family="Arial, sans-serif" font-size="13" font-weight="600" fill="#A9B3C4">Áp dụng tại App</text>
    <text x="657" y="288" text-anchor="middle" font-family="Arial, sans-serif" font-size="13" font-weight="600" fill="#A9B3C4">&amp; Quầy lễ tân</text>
  </svg>`;
}

const now = Date.now();
const daysFromNow = (d) => new Date(now + d * 86400000).toISOString();

const SAMPLE_VOUCHERS = [
  {
    code: 'METAGYM150K',
    title: 'Ưu đãi Hội viên mới -150K',
    description: 'Giảm trực tiếp 150.000 ₫ cho hội viên đăng ký gói Gym lần đầu tại MetaGym.',
    discountType: 'FIXED_AMOUNT',
    discountValue: 150000,
    maxDiscountAmount: null,
    applyScope: 'GYM_PLAN',
    targetMemberScope: 'NEW_MEMBER',
    minOrderAmount: 500000,
    maxTotalUses: 100,
    maxUsesPerMember: 1,
    startsAt: daysFromNow(-1),
    endsAt: daysFromNow(60),
    status: 'ACTIVE',
    artwork: {
      discountBadge: '-150.000₫',
      subtitle: 'Dành cho hội viên mua gói Gym đầu tiên',
      conditionTag: 'Đơn từ 500.000₫ · Tối đa 1 lần / hội viên',
      accent: '#FF5E36',
      accentSoft: '#2E1815',
    },
  },
  {
    code: 'TANGBI20',
    title: 'Giảm 20% Gói Tập Toàn Hệ Thống',
    description: 'Áp dụng mức giảm 20% (tối đa 400.000 ₫) cho Gói Gym hoặc Gói Huấn luyện viên cá nhân.',
    discountType: 'PERCENT',
    discountValue: 20,
    maxDiscountAmount: 400000,
    applyScope: 'ALL',
    targetMemberScope: 'ALL',
    minOrderAmount: 800000,
    maxTotalUses: 200,
    maxUsesPerMember: 2,
    startsAt: daysFromNow(-1),
    endsAt: daysFromNow(45),
    status: 'ACTIVE',
    artwork: {
      discountBadge: '-20%',
      subtitle: 'Giảm tối đa 400.000₫ · Gym & Coach',
      conditionTag: 'Đơn tối thiểu 800.000₫ · 2 lượt / hội viên',
      accent: '#2ECC71',
      accentSoft: '#132A22',
    },
  },
  {
    code: 'GIAHAN15',
    title: 'Tri ân Hội viên Gia hạn -15%',
    description: 'Ưu đãi 15% (tối đa 300.000 ₫) dành riêng cho hội viên gia hạn gói tập hiện hành.',
    discountType: 'PERCENT',
    discountValue: 15,
    maxDiscountAmount: 300000,
    applyScope: 'GYM_PLAN',
    targetMemberScope: 'RENEWAL',
    minOrderAmount: 600000,
    maxTotalUses: 150,
    maxUsesPerMember: 3,
    startsAt: daysFromNow(-2),
    endsAt: daysFromNow(90),
    status: 'ACTIVE',
    artwork: {
      discountBadge: '-15%',
      subtitle: 'Gia hạn nối tiếp · Giảm tối đa 300.000₫',
      conditionTag: 'Hội viên gia hạn · Đơn từ 600.000₫',
      accent: '#70AEE8',
      accentSoft: '#142333',
    },
  },
  {
    code: 'COACHPRO250K',
    title: 'Trợ giá 250K Gói HLV Cá Nhân',
    description: 'Giảm thẳng 250.000 ₫ khi đăng ký kèm Huấn luyện viên cá nhân tại MetaGym.',
    discountType: 'FIXED_AMOUNT',
    discountValue: 250000,
    maxDiscountAmount: null,
    applyScope: 'COACH_PACKAGE',
    targetMemberScope: 'ALL',
    minOrderAmount: 2000000,
    maxTotalUses: 50,
    maxUsesPerMember: 1,
    startsAt: daysFromNow(-1),
    endsAt: daysFromNow(30),
    status: 'ACTIVE',
    artwork: {
      discountBadge: '-250.000₫',
      subtitle: 'Áp dụng riêng cho Gói Huấn luyện viên',
      conditionTag: 'Đơn tối thiểu 2.000.000₫ · Giới hạn 50 lượt',
      accent: '#F39C12',
      accentSoft: '#2E2212',
    },
  },
  {
    code: 'FLASHVIP30',
    title: 'Flash Sale Cuối Tuần -30%',
    description: 'Chương trình ưu đãi đặc biệt cuối tuần giảm 30% tối đa 500.000 ₫ cho đơn cao cấp.',
    discountType: 'PERCENT',
    discountValue: 30,
    maxDiscountAmount: 500000,
    applyScope: 'ALL',
    targetMemberScope: 'ALL',
    minOrderAmount: 1500000,
    maxTotalUses: 30,
    maxUsesPerMember: 1,
    startsAt: daysFromNow(2),
    endsAt: daysFromNow(7),
    status: 'ACTIVE',
    artwork: {
      discountBadge: '-30%',
      subtitle: 'Flash Sale giới hạn 30 suất (Sắp mở bán)',
      conditionTag: 'Đơn từ 1.500.000₫ · Giảm tối đa 500.000₫',
      accent: '#F15B64',
      accentSoft: '#30141C',
    },
  },
];

async function main() {
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');
  const imageStorage = createImageStorageFromEnv(process.env);
  if (!imageStorage) throw new Error('Supabase Storage env variables are required');

  const database = new pg.Pool({ connectionString: process.env.DATABASE_URL });
  try {
    const adminRes = await database.query(
      `SELECT id FROM users WHERE role = 'ADMIN' AND status = 'ACTIVE' ORDER BY created_at ASC LIMIT 1`,
    );
    const adminId = adminRes.rows[0]?.id;
    if (!adminId) throw new Error('No ACTIVE ADMIN user found');

    let seededCount = 0;
    for (const item of SAMPLE_VOUCHERS) {
      const svg = buildVoucherSvg({
        code: item.code,
        title: item.title,
        ...item.artwork,
      });
      const processed = await processPackageImages(Buffer.from(svg, 'utf8'));
      const mediaId = randomUUID();
      const { storageKey, thumbKey } = buildVoucherStorageKeys(mediaId);

      await imageStorage.put(storageKey, processed.full.data, processed.mimeType);
      await imageStorage.put(thumbKey, processed.thumb.data, processed.mimeType);

      const client = await database.connect();
      let oldCleanup = null;
      try {
        await client.query('BEGIN');
        await client.query(
          `INSERT INTO media_assets
           (id, owner_id, purpose, access_scope, storage_key, original_name, mime_type, size_bytes, width, height, status, expires_at, ready_at)
           VALUES ($1, $2, 'VOUCHER', 'PUBLIC', $3, $4, $5, $6, $7, $8, 'READY', now() + interval '100 years', now())`,
          [
            mediaId,
            adminId,
            storageKey,
            `${item.code.toLowerCase()}.webp`,
            processed.mimeType,
            processed.full.data.length,
            processed.full.width,
            processed.full.height,
          ],
        );

        const prevRes = await client.query(`SELECT id, image_media_id FROM vouchers WHERE upper(code) = $1 FOR UPDATE`, [item.code]);
        if (prevRes.rows.length) {
          const existing = prevRes.rows[0];
          oldCleanup = existing.image_media_id
            ? await prepareMediaAssetCleanup(client, existing.image_media_id, { purpose: 'VOUCHER' })
            : null;
          await client.query(
            `UPDATE vouchers SET
               title = $1, description = $2, image_media_id = $3,
               discount_type = $4, discount_value = $5, max_discount_amount = $6,
               apply_scope = $7, target_member_scope = $8, min_order_amount = $9,
               max_total_uses = $10, max_uses_per_member = $11,
               starts_at = $12, ends_at = $13, status = $14, updated_at = now()
             WHERE id = $15`,
            [
              item.title, item.description, mediaId,
              item.discountType, item.discountValue, item.maxDiscountAmount,
              item.applyScope, item.targetMemberScope, item.minOrderAmount,
              item.maxTotalUses, item.maxUsesPerMember,
              item.startsAt, item.endsAt, item.status, existing.id,
            ],
          );
          if (oldCleanup) await oldCleanup.deleteDbRow();
        } else {
          await client.query(
            `INSERT INTO vouchers (
               id, code, title, description, image_media_id, discount_type, discount_value,
               max_discount_amount, apply_scope, target_member_scope, min_order_amount,
               max_total_uses, max_uses_per_member, starts_at, ends_at, status, created_by
             ) VALUES (
               $1, $2, $3, $4, $5, $6, $7,
               $8, $9, $10, $11,
               $12, $13, $14, $15, $16, $17
             )`,
            [
              randomUUID(), item.code, item.title, item.description, mediaId, item.discountType, item.discountValue,
              item.maxDiscountAmount, item.applyScope, item.targetMemberScope, item.minOrderAmount,
              item.maxTotalUses, item.maxUsesPerMember, item.startsAt, item.endsAt, item.status, adminId,
            ],
          );
        }
        await client.query('COMMIT');
        if (oldCleanup) await oldCleanup.removeStorageObjects(imageStorage);
        seededCount += 1;
      } catch (err) {
        await client.query('ROLLBACK').catch(() => {});
        await Promise.all([
          imageStorage.remove(storageKey).catch(() => {}),
          imageStorage.remove(thumbKey).catch(() => {}),
        ]);
        throw err;
      } finally {
        client.release();
      }
    }

    const syncSummary = await syncSupabaseToImageLibrary(database, imageStorage, { adminUserId: adminId, force: true });
    console.log(JSON.stringify({ ok: true, seededVouchers: seededCount, syncSummary }));
  } finally {
    await database.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
