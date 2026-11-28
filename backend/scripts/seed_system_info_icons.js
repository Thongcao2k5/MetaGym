import 'dotenv/config';
import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

import { processPackageImages } from '../src/modules/media/image-processor.js';
import { syncSupabaseToImageLibrary } from '../src/modules/media/supabase-sync.js';
import { DEFAULT_SYSTEM_INFO, SYSTEM_INFO_KEYS } from '../src/modules/system/system-info-defaults.js';
import { createImageStorageFromEnv } from '../src/storage/image-storage.js';
import { buildSystemIconStorageKeys } from '../src/storage/storage-key.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ICONS_3D_DIR = path.resolve(__dirname, '../../design-system/meta-gym/assets/images/icons_3d');

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

    const currentRes = await database.query(
      `SELECT value FROM system_settings WHERE key = $1`,
      [SYSTEM_INFO_KEYS.homeIcons],
    );
    const currentPayload = currentRes.rows[0]?.value || DEFAULT_SYSTEM_INFO.home_quick_icons;
    const items = Array.isArray(currentPayload.items)
      ? currentPayload.items
      : DEFAULT_SYSTEM_INFO.home_quick_icons.items;

    const updatedItems = [];
    for (const item of items) {
      if (item.mediaId || !item.assetFile) {
        updatedItems.push(item);
        continue;
      }
      const rawBytes = await readFile(path.join(ICONS_3D_DIR, item.assetFile));
      const processed = await processPackageImages(rawBytes);
      const mediaId = randomUUID();
      const { storageKey, thumbKey } = buildSystemIconStorageKeys(mediaId);

      await imageStorage.put(storageKey, processed.full.data, processed.mimeType);
      await imageStorage.put(thumbKey, processed.thumb.data, processed.mimeType);
      await database.query(
        `INSERT INTO media_assets
         (id, owner_id, purpose, access_scope, storage_key, original_name, mime_type, size_bytes, width, height, status, expires_at, ready_at)
         VALUES ($1, $2, 'SYSTEM_ICON', 'PUBLIC', $3, $4, $5, $6, $7, $8, 'READY', now() + interval '100 years', now())`,
        [
          mediaId,
          adminId,
          storageKey,
          item.assetFile,
          processed.mimeType,
          processed.full.data.length,
          processed.full.width,
          processed.full.height,
        ],
      );
      updatedItems.push({ ...item, mediaId });
    }

    await database.query(
      `INSERT INTO system_settings (key, value, updated_by)
       VALUES ($1, $2::jsonb, $3)
       ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_by = EXCLUDED.updated_by, updated_at = now()`,
      [SYSTEM_INFO_KEYS.homeIcons, JSON.stringify({ items: updatedItems }), adminId],
    );

    const syncResult = await syncSupabaseToImageLibrary({ database, imageStorage, force: true });
    console.log('Seeded home quick icons:', updatedItems.map((i) => ({ key: i.key, mediaId: i.mediaId })));
    console.log('Image library sync:', JSON.stringify(syncResult));
  } finally {
    await database.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
