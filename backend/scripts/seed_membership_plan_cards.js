import 'dotenv/config';
import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

import { processPackageImages } from '../src/modules/media/image-processor.js';
import { syncSupabaseToImageLibrary } from '../src/modules/media/supabase-sync.js';
import { createImageStorageFromEnv } from '../src/storage/image-storage.js';
import { buildPackageStorageKeys } from '../src/storage/storage-key.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DESIGN_CARD_DIR = path.resolve(__dirname, '../../design-system/meta-gym/assets/images/membership');

const PLAN_CARD_SPECS = [
  {
    planId: 'a3000001-0000-4000-8000-000000000001',
    durationDays: 30,
    cardTier: 'BRONZE',
    frontFile: 'card_bronze.jpg',
    backFile: 'card_bronze_horizontal.jpg',
    frontName: 'card-dong-mat-truoc.webp',
    backName: 'card-dong-mat-sau.webp',
    highlights: [
      'Thẻ Đồng NFC · Full khu máy & Locker',
      'Hỗ trợ hướng dẫn thiết bị cơ bản',
      'Tích điểm Meta Points hệ số x1.0',
    ],
  },
  {
    planId: 'a3000001-0000-4000-8000-000000000002',
    durationDays: 90,
    cardTier: 'SILVER',
    frontFile: 'card_silver.jpg',
    backFile: 'card_silver_horizontal.jpg',
    frontName: 'card-bac-mat-truoc.webp',
    backName: 'card-bac-mat-sau.webp',
    highlights: [
      'Thẻ Bạc NFC · Tập full khung giờ',
      'Miễn phí 1 lần đo InBody & lộ trình',
      'Giảm 3% phí Coach 1:1 · x1.2 điểm',
    ],
  },
  {
    planId: 'a3000001-0000-4000-8000-000000000003',
    durationDays: 180,
    cardTier: 'GOLD',
    frontFile: 'card_gold.jpg',
    backFile: 'card_gold_horizontal.jpg',
    frontName: 'card-vang-mat-truoc.webp',
    backName: 'card-vang-mat-sau.webp',
    highlights: [
      'Thẻ Vàng NFC · Khăn tập mỗi ngày',
      'Miễn phí đo InBody hàng tháng',
      'Giảm 5% phí Coach · Tặng 2 buổi PT 1:1',
    ],
  },
  {
    planId: 'a3000001-0000-4000-8000-000000000004',
    durationDays: 365,
    cardTier: 'DIAMOND',
    frontFile: 'card_diamond.jpg',
    backFile: 'card_diamond_horizontal.jpg',
    frontName: 'card-kim-cuong-mat-truoc.webp',
    backName: 'card-kim-cuong-mat-sau.webp',
    highlights: [
      'Thẻ Kim Cương NFC · Nước điện giải miễn phí',
      'Đo InBody không giới hạn · Ưu tiên lịch',
      'Giảm 10% phí Coach · Tặng 6 buổi PT 1:1',
    ],
  },
];

async function uploadCardAsset(client, { imageStorage, adminId, sourceFile, displayName }) {
  const rawBytes = await readFile(path.join(DESIGN_CARD_DIR, sourceFile));
  const processed = await processPackageImages(rawBytes);
  const mediaId = randomUUID();
  const { storageKey, thumbKey } = buildPackageStorageKeys(mediaId);

  await imageStorage.put(storageKey, processed.full.data, processed.mimeType);
  await imageStorage.put(thumbKey, processed.thumb.data, processed.mimeType);

  await client.query(
    `INSERT INTO media_assets
     (id, owner_id, purpose, access_scope, storage_key, original_name, mime_type, size_bytes, width, height, status, expires_at, ready_at)
     VALUES ($1, $2, 'PACKAGE', 'PUBLIC', $3, $4, $5, $6, $7, $8, 'READY', now() + interval '100 years', now())`,
    [
      mediaId,
      adminId,
      storageKey,
      displayName,
      processed.mimeType,
      processed.full.data.length,
      processed.full.width,
      processed.full.height,
    ],
  );

  return {
    mediaId,
    storageKey,
    fullBytes: processed.full.data.length,
    thumbBytes: processed.thumb.data.length,
  };
}

async function main() {
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');
  const imageStorage = createImageStorageFromEnv(process.env);
  if (!imageStorage) {
    throw new Error('Image storage env variables (SUPABASE_URL, SUPABASE_SECRET_KEY) are required');
  }

  const database = new pg.Pool({ connectionString: process.env.DATABASE_URL });

  try {
    const adminRes = await database.query(
      `SELECT id FROM users WHERE role = 'ADMIN' AND status = 'ACTIVE' ORDER BY created_at ASC LIMIT 1`,
    );
    const adminId = adminRes.rows[0]?.id;
    if (!adminId) throw new Error('No ACTIVE ADMIN user found');

    const summary = [];
    for (const spec of PLAN_CARD_SPECS) {
      const planRes = await database.query(
        `SELECT id, name, front_media_id, back_media_id, card_tier, card_highlights
         FROM membership_plans
         WHERE id = $1 OR (status = 'ACTIVE' AND duration_days = $2)
         ORDER BY (id = $1) DESC
         LIMIT 1`,
        [spec.planId, spec.durationDays],
      );
      const plan = planRes.rows[0];
      if (!plan) {
        summary.push({ tier: spec.cardTier, skipped: 'Plan not found' });
        continue;
      }

      let frontMediaId = plan.front_media_id;
      let backMediaId = plan.back_media_id;
      let uploadedFront = null;
      let uploadedBack = null;

      if (!frontMediaId) {
        uploadedFront = await uploadCardAsset(database, {
          imageStorage,
          adminId,
          sourceFile: spec.frontFile,
          displayName: spec.frontName,
        });
        frontMediaId = uploadedFront.mediaId;
      }

      if (!backMediaId) {
        uploadedBack = await uploadCardAsset(database, {
          imageStorage,
          adminId,
          sourceFile: spec.backFile,
          displayName: spec.backName,
        });
        backMediaId = uploadedBack.mediaId;
      }

      const nextHighlights = Array.isArray(plan.card_highlights) && plan.card_highlights.length >= 3
        ? plan.card_highlights
        : spec.highlights;

      await database.query(
        `UPDATE membership_plans
         SET card_tier = COALESCE(card_tier, $1),
             front_media_id = $2,
             back_media_id = $3,
             card_highlights = $4,
             updated_at = now()
         WHERE id = $5`,
        [spec.cardTier, frontMediaId, backMediaId, nextHighlights, plan.id],
      );

      summary.push({
        planName: plan.name,
        tier: spec.cardTier,
        frontMediaId,
        backMediaId,
        frontKB: uploadedFront ? Math.round(uploadedFront.fullBytes / 1024) : 'kept',
        backKB: uploadedBack ? Math.round(uploadedBack.fullBytes / 1024) : 'kept',
        highlights: nextHighlights,
      });
    }

    const syncResult = await syncSupabaseToImageLibrary({ database, imageStorage, force: true });
    console.log('Seeded 4 membership plan cards:', JSON.stringify(summary, null, 2));
    console.log('Image library sync:', JSON.stringify(syncResult));
  } finally {
    await database.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
