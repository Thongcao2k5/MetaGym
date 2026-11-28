import { createHash, randomUUID } from 'node:crypto';
import path from 'node:path';

import sharp from 'sharp';

import { resolveThumbKeys } from '../../storage/storage-key.js';
import { resolveStorageProviderId } from './image-server-helpers.js';
import { slugify } from './image-validation.js';

const DOMAIN_FOLDER_META = Object.freeze({
  AVATAR: { name: 'Ảnh đại diện', slug: 'users-avatars' },
  GYM: { name: 'Phòng tập', slug: 'gym' },
  EQUIPMENT: { name: 'Thiết bị', slug: 'equipment' },
  EXERCISE: { name: 'Bài tập', slug: 'exercises' },
  COACH_OUTCOME: { name: 'Kết quả huấn luyện', slug: 'coaching-outcomes' },
  PACKAGE: { name: 'Gói tập', slug: 'packages' },
  SYSTEM_ICON: { name: 'Icon hệ thống', slug: 'system-icons' },
  VOUCHER: { name: 'Voucher khuyến mãi', slug: 'marketing-vouchers' },
  BANNER: { name: 'Banner', slug: 'marketing-banners' },
  SLIDE: { name: 'Slide', slug: 'marketing-slides' },
  PROGRESS_PHOTO: { name: 'Tiến độ hội viên', slug: 'tracking-progress' },
  MEAL_PHOTO: { name: 'Bữa ăn', slug: 'nutrition-meals' },
  MESSAGE: { name: 'Tin nhắn', slug: 'communication-messages' },
});

const PUBLIC_PURPOSES = new Set([
  'AVATAR',
  'GYM',
  'EQUIPMENT',
  'EXERCISE',
  'PACKAGE',
  'SYSTEM_ICON',
  'VOUCHER',
  'BANNER',
  'SLIDE',
  'COACH_OUTCOME',
]);

const EXT_TO_MIME = Object.freeze({
  webp: 'image/webp',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  avif: 'image/avif',
  gif: 'image/gif',
  svg: 'image/svg+xml',
});

let inFlightSync = null;
let lastSyncAt = 0;
let lastSyncSummary = null;

/**
 * Infers domain folder metadata from a storage key prefix or media purpose.
 */
export function inferDomainFolder(key, purpose) {
  if (purpose && DOMAIN_FOLDER_META[purpose]) {
    return DOMAIN_FOLDER_META[purpose];
  }
  const clean = String(key || '').toLowerCase();
  if (clean.startsWith('users/avatars/')) return DOMAIN_FOLDER_META.AVATAR;
  if (clean.startsWith('gym/')) return DOMAIN_FOLDER_META.GYM;
  if (clean.startsWith('equipment/')) return DOMAIN_FOLDER_META.EQUIPMENT;
  if (clean.startsWith('exercises/')) return DOMAIN_FOLDER_META.EXERCISE;
  if (clean.startsWith('coaching/')) return DOMAIN_FOLDER_META.COACH_OUTCOME;
  if (clean.startsWith('packages/')) return DOMAIN_FOLDER_META.PACKAGE;
  if (clean.startsWith('system/icons/')) return DOMAIN_FOLDER_META.SYSTEM_ICON;
  if (clean.startsWith('marketing/vouchers/')) return DOMAIN_FOLDER_META.VOUCHER;
  if (clean.startsWith('marketing/banners/')) return DOMAIN_FOLDER_META.BANNER;
  if (clean.startsWith('marketing/slides/')) return DOMAIN_FOLDER_META.SLIDE;
  if (clean.startsWith('tracking/')) return DOMAIN_FOLDER_META.PROGRESS_PHOTO;
  if (clean.startsWith('nutrition/')) return DOMAIN_FOLDER_META.MEAL_PHOTO;
  if (clean.startsWith('communication/')) return DOMAIN_FOLDER_META.MESSAGE;
  if (clean.startsWith('library/') || clean.startsWith('original/')) {
    return { name: 'Thư viện tải lên', slug: 'library-uploads' };
  }
  return { name: 'Supabase Storage', slug: 'supabase-storage' };
}

/**
 * Returns true if the key is a secondary thumbnail or variant file rather than a primary image.
 */
export function isSecondaryVariantKey(key) {
  const clean = String(key || '');
  return (
    clean.startsWith('users/avatars/thumbs/')
    || clean.startsWith('packages/thumbs/')
    || clean.startsWith('system/icons/thumbs/')
    || clean.startsWith('marketing/vouchers/thumbs/')
    || clean.startsWith('thumbnails/')
    || clean.startsWith('library/thumbnails/')
    || clean.startsWith('library/variants/')
    || clean.startsWith('variants/')
  );
}

/**
 * Lists all objects from Supabase Storage (recursively) with fallback to `.list()`.
 */
export async function listStorageObjects(imageStorage) {
  if (!imageStorage) return [];
  if (typeof imageStorage.listDetailed === 'function') {
    return imageStorage.listDetailed();
  }
  if (typeof imageStorage.list === 'function') {
    const keys = await imageStorage.list();
    return keys.map((key) => ({
      key,
      name: path.posix.basename(key),
      sizeBytes: 0,
      mimeType: null,
      createdAt: null,
      updatedAt: null,
    }));
  }
  return [];
}

async function ensureFolderId(client, ownerId, meta, folderCache) {
  if (!meta?.name) return null;
  const cacheKey = meta.name.toLowerCase();
  if (folderCache.has(cacheKey)) return folderCache.get(cacheKey);

  const existing = await client.query(
    `SELECT id FROM folders WHERE lower(name) = lower($1) AND parent_id IS NULL AND deleted_at IS NULL LIMIT 1`,
    [meta.name],
  );
  if (existing.rows[0]?.id) {
    folderCache.set(cacheKey, existing.rows[0].id);
    return existing.rows[0].id;
  }

  const folderId = randomUUID();
  const baseSlug = slugify(meta.slug || meta.name) || 'supabase-folder';
  const inserted = await client.query(
    `INSERT INTO folders (id, owner_id, parent_id, name, slug)
     VALUES ($1, $2, NULL, $3, $4)
     ON CONFLICT DO NOTHING
     RETURNING id`,
    [folderId, ownerId, meta.name, `${baseSlug}-${folderId.slice(0, 6)}`],
  );
  if (inserted.rows[0]?.id) {
    folderCache.set(cacheKey, inserted.rows[0].id);
    return inserted.rows[0].id;
  }

  const retry = await client.query(
    `SELECT id FROM folders WHERE lower(name) = lower($1) AND parent_id IS NULL AND deleted_at IS NULL LIMIT 1`,
    [meta.name],
  );
  const resolvedId = retry.rows[0]?.id || null;
  if (resolvedId) folderCache.set(cacheKey, resolvedId);
  return resolvedId;
}

function buildDisplayName(key, mediaRow, extension) {
  const cleanExt = extension || 'webp';
  if (mediaRow?.purpose === 'AVATAR' && mediaRow?.owner_name) {
    const cleanName = slugify(mediaRow.owner_name);
    if (cleanName) return `avatar-${cleanName}.${cleanExt}`;
  }
  if (mediaRow?.original_name && mediaRow.original_name !== 'avatar.webp' && mediaRow.original_name !== 'avatar.jpg') {
    return String(mediaRow.original_name).slice(0, 255);
  }
  const base = path.posix.basename(String(key || 'image')).replace(/\.[a-z0-9]+$/i, '');
  if (mediaRow?.purpose) {
    return `${mediaRow.purpose.toLowerCase()}-${base.slice(0, 8)}.${cleanExt}`;
  }
  return `${base}.${cleanExt}`;
}

function resolveExtension(key, mimeType) {
  const fromKey = path.posix.extname(String(key || '')).replace(/^\./, '').toLowerCase();
  if (fromKey && EXT_TO_MIME[fromKey]) return fromKey === 'jpeg' ? 'jpg' : fromKey;
  if (mimeType) {
    const clean = String(mimeType).toLowerCase();
    if (clean.includes('webp')) return 'webp';
    if (clean.includes('png')) return 'png';
    if (clean.includes('avif')) return 'avif';
    if (clean.includes('gif')) return 'gif';
    if (clean.includes('svg')) return 'svg';
    if (clean.includes('jpeg') || clean.includes('jpg')) return 'jpg';
  }
  return 'webp';
}

async function runSync({ database, imageStorage, fallbackOwnerId }) {
  const storageEntries = await listStorageObjects(imageStorage);
  const storageMap = new Map(storageEntries.map((entry) => [entry.key, entry]));

  const [mediaRes, imagesRes, variantsRes, adminRes] = await Promise.all([
    database.query(
      `SELECT m.id, m.owner_id, m.purpose, m.access_scope, m.storage_key,
              m.original_name, m.mime_type, m.size_bytes, m.width, m.height, m.created_at,
              u.full_name AS owner_name
       FROM media_assets m
       LEFT JOIN users u ON u.id = m.owner_id
       WHERE m.status = 'READY'`,
    ),
    database.query(
      `SELECT id, storage_key, storage_provider_id, deleted_at FROM images`,
    ),
    database.query(
      `SELECT image_id, storage_key, variant_type FROM image_variants`,
    ),
    database.query(
      `SELECT id FROM users WHERE role = 'ADMIN' AND status = 'ACTIVE' ORDER BY created_at ASC LIMIT 1`,
    ),
  ]);

  const defaultOwnerId = fallbackOwnerId || adminRes.rows[0]?.id;
  const mediaByKey = new Map(mediaRes.rows.map((r) => [r.storage_key, r]));
  const imageByKey = new Map(imagesRes.rows.map((r) => [r.storage_key, r]));
  const variantByKey = new Set(variantsRes.rows.map((r) => r.storage_key));
  const providerId = await resolveStorageProviderId(database, imageStorage);

  const folderCache = new Map();
  let syncedCount = 0;
  let variantsLinkedCount = 0;
  let removedStaleCount = 0;

  const client = await database.connect();
  try {
    await client.query('BEGIN');

    for (const entry of storageEntries) {
      if (isSecondaryVariantKey(entry.key)) continue;

      let existingImg = imageByKey.get(entry.key);
      const mediaRow = mediaByKey.get(entry.key) || null;
      const ownerId = mediaRow?.owner_id || defaultOwnerId;
      if (!ownerId) continue;

      if (!existingImg) {
        let mimeType = mediaRow?.mime_type || entry.mimeType;
        let sizeBytes = Number(mediaRow?.size_bytes ?? entry.sizeBytes ?? 0);
        let width = mediaRow?.width ?? null;
        let height = mediaRow?.height ?? null;
        let sha256Hash = null;

        try {
          const buf = await imageStorage.get(entry.key);
          if (Buffer.isBuffer(buf) && buf.length > 0) {
            sizeBytes = sizeBytes || buf.length;
            sha256Hash = createHash('sha256').update(buf).digest('hex');
            if (!width || !height || !mimeType) {
              const meta = await sharp(buf).metadata().catch(() => null);
              if (meta) {
                width = width || meta.width || null;
                height = height || meta.height || null;
                if (!mimeType && meta.format) {
                  mimeType = EXT_TO_MIME[meta.format] || 'image/webp';
                }
              }
            }
          }
        } catch {
          // If reading bytes fails temporarily, still index using metadata
        }

        const ext = resolveExtension(entry.key, mimeType);
        mimeType = mimeType || EXT_TO_MIME[ext] || 'image/webp';
        sha256Hash = sha256Hash || createHash('sha256').update(entry.key).digest('hex');

        const folderMeta = inferDomainFolder(entry.key, mediaRow?.purpose);
        const folderId = await ensureFolderId(client, defaultOwnerId || ownerId, folderMeta, folderCache);
        const displayFilename = buildDisplayName(entry.key, mediaRow, ext);
        const isPublic = mediaRow
          ? (mediaRow.access_scope === 'PUBLIC' || PUBLIC_PURPOSES.has(mediaRow.purpose))
          : true;
        const visibility = isPublic ? 'public' : 'private';
        const imageId = randomUUID();
        const createdAt = mediaRow?.created_at || entry.createdAt || new Date();

        const inserted = await client.query(
          `INSERT INTO images (
             id, owner_id, folder_id, storage_provider_id, filename, original_filename,
             storage_key, extension, mime_type, size_bytes, width, height, sha256_hash,
             exif_data, description, visibility, created_at
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14::jsonb, $15, $16, $17)
           ON CONFLICT (storage_key) DO NOTHING
           RETURNING id, storage_key`,
          [
            imageId,
            ownerId,
            folderId,
            providerId,
            displayFilename,
            displayFilename,
            entry.key,
            ext,
            mimeType,
            sizeBytes,
            width,
            height,
            sha256Hash,
            JSON.stringify({ source: 'supabase-sync', purpose: mediaRow?.purpose || null, storageKey: entry.key }),
            mediaRow?.purpose ? `Đồng bộ từ Supabase (${folderMeta.name})` : 'Đồng bộ từ Supabase Storage',
            visibility,
            createdAt,
          ],
        );

        if (inserted.rows[0]) {
          existingImg = inserted.rows[0];
          imageByKey.set(entry.key, existingImg);
          syncedCount += 1;
        }
      } else if (existingImg.deleted_at) {
        await client.query('UPDATE images SET deleted_at = NULL, updated_at = now() WHERE id = $1', [existingImg.id]);
        syncedCount += 1;
      }

      // Attach thumbnail variant if present on Supabase Storage
      if (existingImg) {
        const thumbCandidates = resolveThumbKeys(entry.key);
        for (const thumbKey of thumbCandidates) {
          const thumbEntry = storageMap.get(thumbKey);
          if (!thumbEntry || variantByKey.has(thumbKey)) continue;

          let thumbSize = thumbEntry.sizeBytes || 0;
          let thumbWidth = 120;
          let thumbHeight = 120;
          if (!thumbSize) {
            try {
              const tBuf = await imageStorage.get(thumbKey);
              if (Buffer.isBuffer(tBuf)) {
                thumbSize = tBuf.length;
                const tMeta = await sharp(tBuf).metadata().catch(() => null);
                if (tMeta?.width) thumbWidth = tMeta.width;
                if (tMeta?.height) thumbHeight = tMeta.height;
              }
            } catch {
              // ignore temporary read failure
            }
          }

          await client.query(
            `INSERT INTO image_variants (
               id, image_id, variant_type, label, storage_key, extension, mime_type, size_bytes, width, height
             )
             VALUES ($1, $2, 'thumbnail', 'Thumbnail 120px WebP', $3, 'webp', 'image/webp', $4, $5, $6)
             ON CONFLICT (storage_key) DO NOTHING`,
            [randomUUID(), existingImg.id, thumbKey, thumbSize, thumbWidth, thumbHeight],
          );
          variantByKey.add(thumbKey);
          variantsLinkedCount += 1;
          break;
        }
      }
    }

    // Prune active Supabase-backed image records whose objects no longer exist in the bucket
    const staleImageIds = [];
    for (const row of imagesRes.rows) {
      if (row.deleted_at) continue;
      if (row.storage_provider_id === providerId && !storageMap.has(row.storage_key)) {
        staleImageIds.push(row.id);
      }
    }
    if (staleImageIds.length > 0) {
      await client.query('DELETE FROM images WHERE id = ANY($1::uuid[])', [staleImageIds]);
      removedStaleCount = staleImageIds.length;
    }

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }

  const totalStorageBytes = storageEntries.reduce((sum, e) => sum + Number(e.sizeBytes || 0), 0);
  return {
    bucket: imageStorage?.bucket || process.env.SUPABASE_STORAGE_BUCKET || 'meta-gym-media',
    syncedCount,
    variantsLinkedCount,
    removedStaleCount,
    totalStorageObjects: storageEntries.length,
    totalStorageBytes,
  };
}

/**
 * Syncs objects from Supabase Storage into `images`, `image_variants`, and `folders`.
 * Coalesces concurrent calls and throttles automatic refreshes unless `force: true`.
 */
export async function syncSupabaseToImageLibrary({
  database,
  imageStorage,
  fallbackOwnerId = null,
  force = false,
  ttlMs = 15000,
} = {}) {
  if (!imageStorage || imageStorage.providerType !== 'supabase') {
    return null;
  }
  const now = Date.now();
  if (!force && lastSyncSummary && now - lastSyncAt < ttlMs) {
    return lastSyncSummary;
  }
  if (inFlightSync) {
    return inFlightSync;
  }

  inFlightSync = runSync({ database, imageStorage, fallbackOwnerId })
    .then((summary) => {
      lastSyncAt = Date.now();
      lastSyncSummary = summary;
      return summary;
    })
    .finally(() => {
      inFlightSync = null;
    });

  return inFlightSync;
}

/**
 * Resets internal sync throttle cache (used for unit tests or after explicit mutations).
 */
export function resetSupabaseSyncCache() {
  lastSyncAt = 0;
  lastSyncSummary = null;
}
