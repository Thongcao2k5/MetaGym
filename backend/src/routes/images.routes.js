import { randomUUID } from 'node:crypto';
import path from 'node:path';

import { Router } from 'express';
import multer from 'multer';
import { z } from 'zod';

import {
  createApiLogMiddleware,
  createImageServerAuth,
  requireScope,
} from '../middleware/image-server-auth.js';
import { processUploadedImage, transformImage } from '../services/image-processor.js';
import {
  escapeLike,
  fail,
  loadSystemSettings,
  ok,
  recordImageAudit,
  recordImageView,
  resolveStorageProviderId,
  serializeImageRow,
  verifyShareAccessToken,
  zodValidationError,
} from '../services/image-server-helpers.js';
import { assertSafeRemoteUrl, slugify } from '../services/image-validation.js';

const uuid = z.uuid();

const listQuerySchema = z.strictObject({
  q: z.string().trim().max(120).optional(),
  format: z.string().trim().max(20).optional(),
  visibility: z.enum(['public', 'private']).optional(),
  minSize: z.coerce.number().int().min(0).optional(),
  maxSize: z.coerce.number().int().min(0).optional(),
  fromDate: z.iso.date().optional(),
  toDate: z.iso.date().optional(),
  tag: z.string().trim().max(100).optional(),
  albumId: uuid.optional(),
  folderId: uuid.optional(),
  includeDeleted: z.enum(['true', 'false']).optional(),
  sortBy: z.enum(['created_at', 'size_bytes', 'view_count', 'filename']).default('created_at'),
  order: z.enum(['asc', 'desc']).default('desc'),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(24),
});

const patchImageSchema = z.strictObject({
  filename: z.string().trim().min(1).max(255).optional(),
  description: z.string().trim().max(2000).nullable().optional(),
  visibility: z.enum(['public', 'private']).optional(),
  folderId: uuid.nullable().optional(),
  tags: z.array(z.string().trim().min(1).max(80)).max(30).optional(),
});

const bulkDeleteSchema = z.strictObject({
  ids: z.array(uuid).min(1).max(100),
  permanent: z.boolean().optional(),
});

const importUrlSchema = z.strictObject({
  url: z.string().trim().url().max(2000),
  filename: z.string().trim().min(1).max(255).optional(),
  folderId: uuid.nullable().optional(),
  albumId: uuid.nullable().optional(),
  visibility: z.enum(['public', 'private']).optional(),
  tags: z.array(z.string().trim().min(1).max(80)).max(30).optional(),
});

const transformSchema = z.strictObject({
  crop: z.strictObject({
    left: z.number().int().min(0),
    top: z.number().int().min(0),
    width: z.number().int().min(1),
    height: z.number().int().min(1),
  }).optional(),
  resize: z.strictObject({
    width: z.number().int().min(1).max(10000).optional(),
    height: z.number().int().min(1).max(10000).optional(),
    fit: z.enum(['cover', 'contain', 'fill', 'inside', 'outside']).default('inside'),
  }).optional(),
  rotate: z.number().min(-360).max(360).optional(),
  flipHorizontal: z.boolean().optional(),
  flipVertical: z.boolean().optional(),
  format: z.enum(['jpeg', 'png', 'webp', 'avif']).default('webp'),
  quality: z.number().int().min(1).max(100).default(82),
  label: z.string().trim().min(1).max(100).optional(),
  saveAsVariant: z.boolean().default(true),
});

function parseTagList(raw) {
  if (!raw) return [];
  if (Array.isArray(raw)) return raw.map((t) => String(t).trim()).filter(Boolean);
  const str = String(raw).trim();
  if (!str) return [];
  if (str.startsWith('[')) {
    try {
      const parsed = JSON.parse(str);
      if (Array.isArray(parsed)) return parsed.map((t) => String(t).trim()).filter(Boolean);
    } catch {
      // fallback to comma split
    }
  }
  return str.split(',').map((t) => t.trim()).filter(Boolean);
}

async function syncImageTags(client, imageId, tagNames) {
  await client.query('DELETE FROM image_tags WHERE image_id = $1', [imageId]);
  const cleanNames = [...new Set(tagNames.map((n) => n.trim()).filter(Boolean))].slice(0, 30);
  const attached = [];
  for (const name of cleanNames) {
    const slug = slugify(name);
    const existing = await client.query('SELECT id, name, slug, color FROM tags WHERE slug = $1 LIMIT 1', [slug]);
    let tag = existing.rows[0];
    if (!tag) {
      const inserted = await client.query(
        `INSERT INTO tags (id, name, slug, color)
         VALUES ($1, $2, $3, '#FF5E36')
         ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
         RETURNING id, name, slug, color`,
        [randomUUID(), name.slice(0, 80), slug],
      );
      tag = inserted.rows[0];
    }
    await client.query(
      'INSERT INTO image_tags (image_id, tag_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
      [imageId, tag.id],
    );
    attached.push(tag);
  }
  return attached;
}

async function loadImageRelations(database, imageIds) {
  if (!imageIds.length) return { variantsByImage: new Map(), tagsByImage: new Map() };
  const [variantsRes, tagsRes] = await Promise.all([
    database.query(
      `SELECT id, image_id, variant_type, label, storage_key, extension, mime_type,
              size_bytes, width, height, transform_params, created_at
       FROM image_variants
       WHERE image_id = ANY($1::uuid[])
       ORDER BY created_at ASC`,
      [imageIds],
    ),
    database.query(
      `SELECT it.image_id, t.id, t.name, t.slug, t.color
       FROM image_tags it
       JOIN tags t ON t.id = it.tag_id
       WHERE it.image_id = ANY($1::uuid[])
       ORDER BY t.name ASC`,
      [imageIds],
    ),
  ]);

  const variantsByImage = new Map();
  for (const row of variantsRes.rows) {
    const list = variantsByImage.get(row.image_id) || [];
    list.push(row);
    variantsByImage.set(row.image_id, list);
  }

  const tagsByImage = new Map();
  for (const row of tagsRes.rows) {
    const list = tagsByImage.get(row.image_id) || [];
    list.push(row);
    tagsByImage.set(row.image_id, list);
  }

  return { variantsByImage, tagsByImage };
}

async function persistProcessedImage({
  database,
  imageStorage,
  user,
  processed,
  displayFilename,
  folderId,
  albumId,
  visibility,
  tagNames,
}) {
  const settings = await loadSystemSettings(database);
  const uploadLimits = settings.upload_limits || {};
  const finalVisibility = visibility || uploadLimits.defaultVisibility || 'private';

  const totalNewBytes =
    processed.sizeBytes +
    (processed.thumbnail?.sizeBytes || 0) +
    processed.variants.reduce((sum, v) => sum + Number(v.sizeBytes || 0), 0);

  const userRes = await database.query(
    'SELECT storage_quota_bytes, storage_used_bytes FROM users WHERE id = $1',
    [user.id],
  );
  const quota = Number(userRes.rows[0]?.storage_quota_bytes ?? user.storage_quota_bytes ?? 1073741824);
  const used = Number(userRes.rows[0]?.storage_used_bytes ?? user.storage_used_bytes ?? 0);
  if (used + totalNewBytes > quota) {
    throw Object.assign(new Error('Dung lượng lưu trữ của tài khoản đã vượt quota cho phép.'), {
      code: 'QUOTA_EXCEEDED',
      status: 413,
    });
  }

  const providerId = await resolveStorageProviderId(database, imageStorage);
  const imageId = randomUUID();
  const originalKey = `original/${imageId}.${processed.extension}`;
  const storedKeys = [];

  try {
    await imageStorage.put(originalKey, processed.buffer, processed.mimeType);
    storedKeys.push(originalKey);

    let thumbRecord = null;
    if (processed.thumbnail) {
      const thumbId = randomUUID();
      const thumbKey = `thumbnails/${thumbId}.${processed.thumbnail.extension}`;
      await imageStorage.put(thumbKey, processed.thumbnail.buffer, processed.thumbnail.mimeType);
      storedKeys.push(thumbKey);
      thumbRecord = { ...processed.thumbnail, id: thumbId, storageKey: thumbKey };
    }

    const variantRecords = [];
    for (const v of processed.variants) {
      const variantId = randomUUID();
      const variantKey = `variants/${variantId}.${v.extension}`;
      await imageStorage.put(variantKey, v.buffer, v.mimeType);
      storedKeys.push(variantKey);
      variantRecords.push({ ...v, id: variantId, storageKey: variantKey });
    }

    const client = await database.connect();
    try {
      await client.query('BEGIN');

      if (folderId) {
        const fCheck = await client.query(
          'SELECT id FROM folders WHERE id = $1 AND deleted_at IS NULL',
          [folderId],
        );
        if (!fCheck.rows.length) {
          throw Object.assign(new Error('Thư mục đích không tồn tại.'), { code: 'NOT_FOUND', status: 404 });
        }
      }

      const safeDisplayName = String(displayFilename || processed.originalFilename || `image.${processed.extension}`).slice(0, 255);
      const inserted = await client.query(
        `INSERT INTO images (
           id, owner_id, folder_id, storage_provider_id, filename, original_filename,
           storage_key, extension, mime_type, size_bytes, width, height, sha256_hash,
           exif_data, visibility
         )
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14::jsonb, $15)
         RETURNING *`,
        [
          imageId,
          user.id,
          folderId ?? null,
          providerId,
          safeDisplayName,
          processed.originalFilename,
          originalKey,
          processed.extension,
          processed.mimeType,
          processed.sizeBytes,
          processed.width,
          processed.height,
          processed.sha256Hash,
          JSON.stringify(processed.exifData || {}),
          finalVisibility,
        ],
      );

      const allVariants = [thumbRecord, ...variantRecords].filter(Boolean);
      const insertedVariants = [];
      for (const v of allVariants) {
        const vRes = await client.query(
          `INSERT INTO image_variants (
             id, image_id, variant_type, label, storage_key, extension, mime_type,
             size_bytes, width, height, transform_params
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb)
           RETURNING *`,
          [
            v.id,
            imageId,
            v.variantType,
            v.label ?? null,
            v.storageKey,
            v.extension,
            v.mimeType,
            v.sizeBytes,
            v.width ?? null,
            v.height ?? null,
            v.transformParams ? JSON.stringify(v.transformParams) : null,
          ],
        );
        insertedVariants.push(vRes.rows[0]);
      }

      if (albumId) {
        const aCheck = await client.query(
          'SELECT id FROM albums WHERE id = $1 AND deleted_at IS NULL',
          [albumId],
        );
        if (!aCheck.rows.length) {
          throw Object.assign(new Error('Album đích không tồn tại.'), { code: 'NOT_FOUND', status: 404 });
        }
        await client.query(
          'INSERT INTO album_images (album_id, image_id, sort_order) VALUES ($1, $2, 0) ON CONFLICT DO NOTHING',
          [albumId, imageId],
        );
      }

      const tags = await syncImageTags(client, imageId, tagNames);

      await client.query(
        'UPDATE users SET storage_used_bytes = storage_used_bytes + $1, updated_at = now() WHERE id = $2',
        [totalNewBytes, user.id],
      );

      await client.query('COMMIT');

      const row = inserted.rows[0];
      row.owner_name = user.full_name;
      row.owner_email = user.email;
      return serializeImageRow(row, { variants: insertedVariants, tags });
    } catch (dbErr) {
      await client.query('ROLLBACK').catch(() => {});
      throw dbErr;
    } finally {
      client.release();
    }
  } catch (err) {
    for (const key of storedKeys) {
      await imageStorage.remove?.(key).catch(() => {});
    }
    throw err;
  }
}

async function checkImageAccess({ database, jwtSecret, request, image }) {
  if (image.visibility === 'public' && !image.deleted_at) {
    return { allowed: true, allowDownload: true, viaShare: false };
  }

  // Check optional shareToken
  const shareToken = request.query?.shareToken ? String(request.query.shareToken).trim() : '';
  if (shareToken && !image.deleted_at) {
    const shareRes = await database.query(
      `SELECT s.*, ai.image_id AS album_has_image
       FROM share_links s
       LEFT JOIN album_images ai ON s.target_type = 'album' AND ai.album_id = s.album_id AND ai.image_id = $2
       WHERE s.token = $1
       LIMIT 1`,
      [shareToken, image.id],
    );
    const share = shareRes.rows[0];
    const matchesImage = share && ((share.target_type === 'image' && share.image_id === image.id) || (share.target_type === 'album' && share.album_has_image));
    if (matchesImage && !share.revoked_at && (!share.expires_at || new Date(share.expires_at).getTime() > Date.now())) {
      if (!share.password_hash) {
        return { allowed: true, allowDownload: Boolean(share.allow_download), viaShare: true };
      }
      const accessToken = request.get('x-share-access-token') || request.query?.shareAccess;
      if (verifyShareAccessToken(jwtSecret, shareToken, String(accessToken || ''))) {
        return { allowed: true, allowDownload: Boolean(share.allow_download), viaShare: true };
      }
    }
  }

  return { allowed: false, allowDownload: false, viaShare: false };
}

function sendBinaryImage(response, bytes, mimeType, { isSvg = false, downloadName = null } = {}) {
  response.set('X-Content-Type-Options', 'nosniff');
  if (isSvg) {
    response.set('Content-Security-Policy', "default-src 'none'; sandbox");
  }
  if (downloadName) {
    const safeName = path.basename(downloadName).replace(/["\r\n]/g, '_');
    response.set('Content-Disposition', `attachment; filename="${safeName}"`);
  } else {
    response.set('Cache-Control', 'public, max-age=300');
  }
  response.type(mimeType);
  return response.send(bytes);
}

export function createImagesRouter({ database, jwtSecret, imageStorage }) {
  const router = Router();
  const authenticate = createImageServerAuth({ database, jwtSecret });
  const apiLogger = createApiLogMiddleware({ database });

  const uploadMiddleware = multer({
    storage: multer.memoryStorage(),
    limits: { files: 20, fileSize: 50 * 1024 * 1024 },
  });

  function optionalAuth(request, response, next) {
    const hasCreds = Boolean(request.get('authorization') || request.get('x-api-key'));
    if (!hasCreds) return next();
    return authenticate(request, response, next);
  }

  router.use('/images', apiLogger);

  router.post(
    '/images/upload',
    authenticate,
    requireScope('images:write'),
    (request, response, next) => {
      uploadMiddleware.fields([
        { name: 'files', maxCount: 20 },
        { name: 'file', maxCount: 1 },
      ])(request, response, (err) => {
        if (err) {
          return fail(response, 422, 'UPLOAD_ERROR', err.message || 'Không thể đọc tệp tải lên.');
        }
        return next();
      });
    },
    async (request, response) => {
      if (!imageStorage || typeof imageStorage.put !== 'function') {
        return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Lưu trữ ảnh chưa được cấu hình.');
      }
      const files = [
        ...(request.files?.files || []),
        ...(request.files?.file || []),
      ];
      if (!files.length) {
        return fail(response, 422, 'VALIDATION_ERROR', 'Vui lòng chọn ít nhất một tệp ảnh.');
      }

      const settings = await loadSystemSettings(database);
      if (settings.maintenance_mode?.enabled && request.authUser.role !== 'ADMIN') {
        return fail(response, 503, 'MAINTENANCE_MODE', settings.maintenance_mode.message || 'Hệ thống đang bảo trì.');
      }

      const limits = settings.upload_limits || {};
      const proc = settings.image_processing || {};
      const maxFiles = Number(limits.maxFilesPerUpload || 20);
      if (files.length > maxFiles) {
        return fail(response, 422, 'VALIDATION_ERROR', `Chỉ được tải lên tối đa ${maxFiles} ảnh mỗi lần.`);
      }

      const maxFileSizeBytes = Number(limits.maxFileSizeMb || 10) * 1024 * 1024;
      const folderId = request.body?.folderId && uuid.safeParse(request.body.folderId).success
        ? request.body.folderId
        : null;
      const albumId = request.body?.albumId && uuid.safeParse(request.body.albumId).success
        ? request.body.albumId
        : null;
      const visibility = ['public', 'private'].includes(request.body?.visibility)
        ? request.body.visibility
        : undefined;
      const tagNames = parseTagList(request.body?.tags);

      const uploaded = [];
      const errors = [];
      for (const file of files) {
        try {
          const processed = await processUploadedImage(file.buffer, {
            originalFilename: file.originalname,
            allowedFormats: limits.allowedFormats,
            maxFileSizeBytes,
            thumbnailSize: Number(proc.thumbnailSize || 400),
            generateWebp: Boolean(proc.autoWebp),
            generateAvif: Boolean(proc.autoAvif),
            quality: Number(proc.defaultQuality || 82),
            stripGpsExif: Boolean(proc.stripGpsExif),
          });
          const item = await persistProcessedImage({
            database,
            imageStorage,
            user: request.authUser,
            processed,
            displayFilename: request.body?.filename && files.length === 1
              ? request.body.filename
              : file.originalname,
            folderId,
            albumId,
            visibility,
            tagNames,
          });
          uploaded.push(item);
        } catch (err) {
          errors.push({
            filename: file.originalname,
            code: err.code || 'UPLOAD_FAILED',
            message: err.message || 'Tải ảnh thất bại.',
          });
        }
      }

      if (!uploaded.length) {
        const firstErr = errors[0];
        return fail(
          response,
          firstErr?.code === 'QUOTA_EXCEEDED' ? 413 : 422,
          firstErr?.code || 'UPLOAD_FAILED',
          firstErr?.message || 'Không thể tải ảnh lên.',
          { errors },
        );
      }

      if (files.length === 1 && uploaded.length === 1) {
        return ok(response, uploaded[0], { status: 201 });
      }
      return ok(response, { items: uploaded, errors }, {
        status: 201,
        meta: { uploadedCount: uploaded.length, failedCount: errors.length },
      });
    },
  );

  router.post(
    '/images/import-url',
    authenticate,
    requireScope('images:write'),
    async (request, response) => {
      if (!imageStorage || typeof imageStorage.put !== 'function') {
        return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Lưu trữ ảnh chưa được cấu hình.');
      }
      const parsed = importUrlSchema.safeParse(request.body);
      if (!parsed.success) return zodValidationError(response, parsed.error);

      const settings = await loadSystemSettings(database);
      const limits = settings.upload_limits || {};
      const proc = settings.image_processing || {};
      if (limits.allowUrlImport === false) {
        return fail(response, 403, 'URL_IMPORT_DISABLED', 'Chức năng nhập ảnh từ URL đang bị tắt.');
      }

      let safeUrl;
      try {
        safeUrl = await assertSafeRemoteUrl(parsed.data.url);
      } catch {
        return fail(response, 422, 'UNSAFE_URL', 'URL không hợp lệ hoặc không được phép truy cập.');
      }

      const maxFileSizeBytes = Number(limits.maxFileSizeMb || 10) * 1024 * 1024;
      let buffer;
      try {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), 12000);
        const res = await fetch(safeUrl.href, { signal: controller.signal, redirect: 'follow' });
        clearTimeout(timer);
        if (!res.ok) {
          return fail(response, 422, 'URL_FETCH_FAILED', `Không thể tải ảnh từ URL (HTTP ${res.status}).`);
        }
        const ab = await res.arrayBuffer();
        buffer = Buffer.from(ab);
        if (buffer.length > maxFileSizeBytes) {
          return fail(response, 413, 'PAYLOAD_TOO_LARGE', 'Ảnh từ URL vượt quá giới hạn dung lượng.');
        }
      } catch {
        return fail(response, 422, 'URL_FETCH_FAILED', 'Không thể tải ảnh từ URL đã cung cấp.');
      }

      try {
        const fallbackName = path.basename(safeUrl.pathname) || 'imported-image';
        const processed = await processUploadedImage(buffer, {
          originalFilename: parsed.data.filename || fallbackName,
          allowedFormats: limits.allowedFormats,
          maxFileSizeBytes,
          thumbnailSize: Number(proc.thumbnailSize || 400),
          generateWebp: Boolean(proc.autoWebp),
          generateAvif: Boolean(proc.autoAvif),
          quality: Number(proc.defaultQuality || 82),
          stripGpsExif: Boolean(proc.stripGpsExif),
        });
        const item = await persistProcessedImage({
          database,
          imageStorage,
          user: request.authUser,
          processed,
          displayFilename: parsed.data.filename || fallbackName,
          folderId: parsed.data.folderId ?? null,
          albumId: parsed.data.albumId ?? null,
          visibility: parsed.data.visibility,
          tagNames: parsed.data.tags || [],
        });
        return ok(response, item, { status: 201 });
      } catch (err) {
        return fail(response, err.status || 422, err.code || 'UPLOAD_FAILED', err.message || 'Không thể nhập ảnh từ URL.');
      }
    },
  );

  router.get('/images', authenticate, requireScope('images:read'), async (request, response) => {
    const parsed = listQuerySchema.safeParse(request.query);
    if (!parsed.success) return zodValidationError(response, parsed.error, 'Bộ lọc ảnh không hợp lệ.');
    const {
      q, format, visibility, minSize, maxSize, fromDate, toDate,
      tag, albumId, folderId, includeDeleted, sortBy, order, page, limit,
    } = parsed.data;

    const filters = [];
    const values = [];
    if (includeDeleted !== 'true') {
      filters.push('i.deleted_at IS NULL');
    }
    if (request.authUser.role !== 'ADMIN') {
      values.push(request.authUser.id);
      filters.push(`i.owner_id = $${values.length}`);
    }
    if (q) {
      values.push(`%${escapeLike(q)}%`);
      const p = `$${values.length}`;
      filters.push(`(i.filename ILIKE ${p} OR i.original_filename ILIKE ${p} OR COALESCE(i.description, '') ILIKE ${p})`);
    }
    if (format) {
      values.push(format.toLowerCase());
      filters.push(`(lower(i.extension) = $${values.length} OR lower(i.mime_type) LIKE '%' || $${values.length} || '%')`);
    }
    if (visibility) {
      values.push(visibility);
      filters.push(`i.visibility = $${values.length}`);
    }
    if (minSize !== undefined) {
      values.push(minSize);
      filters.push(`i.size_bytes >= $${values.length}`);
    }
    if (maxSize !== undefined) {
      values.push(maxSize);
      filters.push(`i.size_bytes <= $${values.length}`);
    }
    if (fromDate) {
      values.push(fromDate);
      filters.push(`i.created_at >= ($${values.length}::date)::timestamptz`);
    }
    if (toDate) {
      values.push(toDate);
      filters.push(`i.created_at < (($${values.length}::date + 1)::timestamptz)`);
    }
    if (folderId) {
      values.push(folderId);
      filters.push(`i.folder_id = $${values.length}`);
    }
    if (albumId) {
      values.push(albumId);
      filters.push(`EXISTS (SELECT 1 FROM album_images ai WHERE ai.album_id = $${values.length} AND ai.image_id = i.id)`);
    }
    if (tag) {
      values.push(tag.toLowerCase());
      filters.push(`EXISTS (SELECT 1 FROM image_tags it JOIN tags t ON t.id = it.tag_id WHERE it.image_id = i.id AND (lower(t.slug) = $${values.length} OR lower(t.name) = $${values.length}))`);
    }

    const whereSql = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    const sortCol = {
      created_at: 'i.created_at',
      size_bytes: 'i.size_bytes',
      view_count: 'i.view_count',
      filename: 'lower(i.filename)',
    }[sortBy] || 'i.created_at';
    const sortDir = order === 'asc' ? 'ASC' : 'DESC';

    try {
      const countRes = await database.query(`SELECT COUNT(*)::int AS total FROM images i ${whereSql}`, values);
      const total = Number(countRes.rows[0]?.total ?? 0);
      const offset = (page - 1) * limit;
      const listRes = await database.query(
        `SELECT i.*, u.full_name AS owner_name, u.email::text AS owner_email, f.name AS folder_name
         FROM images i
         LEFT JOIN users u ON u.id = i.owner_id
         LEFT JOIN folders f ON f.id = i.folder_id
         ${whereSql}
         ORDER BY ${sortCol} ${sortDir}, i.id DESC
         LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
        [...values, limit, offset],
      );
      const { variantsByImage, tagsByImage } = await loadImageRelations(
        database,
        listRes.rows.map((r) => r.id),
      );
      const items = listRes.rows.map((row) =>
        serializeImageRow(row, {
          variants: variantsByImage.get(row.id) || [],
          tags: tagsByImage.get(row.id) || [],
        }),
      );
      return ok(response, items, {
        meta: { page, limit, total, totalPages: Math.max(1, Math.ceil(total / limit)) },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tải danh sách hình ảnh.');
    }
  });

  router.get('/images/:id', authenticate, requireScope('images:read'), async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã ảnh không hợp lệ.');

    try {
      const res = await database.query(
        `SELECT i.*, u.full_name AS owner_name, u.email::text AS owner_email, f.name AS folder_name
         FROM images i
         LEFT JOIN users u ON u.id = i.owner_id
         LEFT JOIN folders f ON f.id = i.folder_id
         WHERE i.id = $1 LIMIT 1`,
        [id],
      );
      const image = res.rows[0];
      if (!image || (request.authUser.role !== 'ADMIN' && image.owner_id !== request.authUser.id)) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh.');
      }

      const [{ variantsByImage, tagsByImage }, albumsRes, sharesRes] = await Promise.all([
        loadImageRelations(database, [image.id]),
        database.query(
          `SELECT a.id, a.title FROM album_images ai JOIN albums a ON a.id = ai.album_id
           WHERE ai.image_id = $1 AND a.deleted_at IS NULL ORDER BY a.title ASC`,
          [image.id],
        ),
        database.query(
          `SELECT id, token, allow_download, expires_at, revoked_at, access_count, created_at,
                  (password_hash IS NOT NULL) AS has_password
           FROM share_links WHERE image_id = $1 ORDER BY created_at DESC`,
          [image.id],
        ),
      ]);

      const serialized = serializeImageRow(image, {
        variants: variantsByImage.get(image.id) || [],
        tags: tagsByImage.get(image.id) || [],
      });
      serialized.albums = albumsRes.rows;
      serialized.shareLinks = sharesRes.rows.map((s) => ({
        id: s.id,
        token: s.token,
        allowDownload: s.allow_download,
        hasPassword: Boolean(s.has_password),
        expiresAt: s.expires_at,
        revokedAt: s.revoked_at,
        accessCount: Number(s.access_count ?? 0),
        createdAt: s.created_at,
      }));
      return ok(response, serialized);
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tải chi tiết ảnh.');
    }
  });

  router.patch('/images/:id', authenticate, requireScope('images:write'), async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã ảnh không hợp lệ.');
    const parsed = patchImageSchema.safeParse(request.body);
    if (!parsed.success) return zodValidationError(response, parsed.error);

    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Lỗi kết nối cơ sở dữ liệu.');

    try {
      await client.query('BEGIN');
      const existing = await client.query('SELECT * FROM images WHERE id = $1 AND deleted_at IS NULL FOR UPDATE', [id]);
      const image = existing.rows[0];
      if (!image || (request.authUser.role !== 'ADMIN' && image.owner_id !== request.authUser.id)) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh.');
      }

      const updates = [];
      const values = [];
      if (parsed.data.filename !== undefined) {
        values.push(parsed.data.filename);
        updates.push(`filename = $${values.length}`);
      }
      if (parsed.data.description !== undefined) {
        values.push(parsed.data.description);
        updates.push(`description = $${values.length}`);
      }
      if (parsed.data.visibility !== undefined) {
        values.push(parsed.data.visibility);
        updates.push(`visibility = $${values.length}`);
      }
      if (parsed.data.folderId !== undefined) {
        if (parsed.data.folderId !== null) {
          const fRes = await client.query('SELECT id FROM folders WHERE id = $1 AND deleted_at IS NULL', [parsed.data.folderId]);
          if (!fRes.rows.length) {
            await client.query('ROLLBACK');
            return fail(response, 404, 'NOT_FOUND', 'Thư mục không tồn tại.');
          }
        }
        values.push(parsed.data.folderId);
        updates.push(`folder_id = $${values.length}`);
      }

      let updatedRow = image;
      if (updates.length) {
        values.push(id);
        const upd = await client.query(
          `UPDATE images SET ${updates.join(', ')}, updated_at = now() WHERE id = $${values.length} RETURNING *`,
          values,
        );
        updatedRow = upd.rows[0];
      }

      if (parsed.data.tags !== undefined) {
        await syncImageTags(client, id, parsed.data.tags);
      }

      await client.query('COMMIT');
      const { variantsByImage, tagsByImage } = await loadImageRelations(database, [id]);
      return ok(response, serializeImageRow(updatedRow, {
        variants: variantsByImage.get(id) || [],
        tags: tagsByImage.get(id) || [],
      }));
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể cập nhật thông tin ảnh.');
    } finally {
      client.release();
    }
  });

  async function deleteSingleImage({ id, permanent, authUser }) {
    const client = await database.connect();
    try {
      await client.query('BEGIN');
      const res = await client.query('SELECT * FROM images WHERE id = $1 FOR UPDATE', [id]);
      const image = res.rows[0];
      if (!image || (authUser.role !== 'ADMIN' && image.owner_id !== authUser.id)) {
        await client.query('ROLLBACK');
        return { notFound: true };
      }

      const variantsRes = await client.query('SELECT id, storage_key, size_bytes FROM image_variants WHERE image_id = $1', [id]);
      const variantBytes = variantsRes.rows.reduce((s, v) => s + Number(v.size_bytes || 0), 0);
      const totalBytes = Number(image.size_bytes || 0) + variantBytes;

      if (permanent) {
        const keys = [image.storage_key, ...variantsRes.rows.map((v) => v.storage_key)].filter(Boolean);
        await client.query('DELETE FROM images WHERE id = $1', [id]);
        await client.query(
          'UPDATE users SET storage_used_bytes = GREATEST(0, storage_used_bytes - $1), updated_at = now() WHERE id = $2',
          [totalBytes, image.owner_id],
        );
        await client.query('COMMIT');
        for (const key of keys) {
          await imageStorage?.remove?.(key).catch(() => {});
        }
        if (authUser.role === 'ADMIN') {
          await recordImageAudit(database, authUser.id, 'IMAGE_DELETED_PERMANENT', 'IMAGE', id, `Xóa vĩnh viễn ảnh ${image.filename}`, {
            filename: image.filename,
            sizeBytes: totalBytes,
          });
        }
        return { deleted: true, permanent: true };
      }

      await client.query('UPDATE images SET deleted_at = now(), updated_at = now() WHERE id = $1', [id]);
      await client.query('COMMIT');
      return { deleted: true, permanent: false };
    } catch (err) {
      await client.query('ROLLBACK').catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  }

  router.delete('/images/:id', authenticate, requireScope('images:delete'), async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã ảnh không hợp lệ.');
    const permanent = request.query?.permanent === 'true';
    try {
      const outcome = await deleteSingleImage({ id, permanent, authUser: request.authUser });
      if (outcome.notFound) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh.');
      return ok(response, { id, ...outcome });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể xóa ảnh.');
    }
  });

  router.post('/images/bulk-delete', authenticate, requireScope('images:delete'), async (request, response) => {
    const parsed = bulkDeleteSchema.safeParse(request.body);
    if (!parsed.success) return zodValidationError(response, parsed.error);
    const permanent = Boolean(parsed.data.permanent);

    let deletedCount = 0;
    for (const id of parsed.data.ids) {
      const res = await deleteSingleImage({ id, permanent, authUser: request.authUser }).catch(() => null);
      if (res?.deleted) deletedCount += 1;
    }
    return ok(response, { deletedCount, permanent });
  });

  router.get('/images/:id/file', optionalAuth, async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh.');
    if (!imageStorage || typeof imageStorage.get !== 'function') {
      return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Lưu trữ ảnh chưa được cấu hình.');
    }
    try {
      const res = await database.query('SELECT * FROM images WHERE id = $1 LIMIT 1', [id]);
      const image = res.rows[0];
      if (!image || image.deleted_at) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh.');
      const isOwnerOrAdmin = request.authUser && (request.authUser.role === 'ADMIN' || request.authUser.id === image.owner_id);
      if (!isOwnerOrAdmin) {
        const access = await checkImageAccess({ database, jwtSecret, request, image });
        if (!access.allowed) return fail(response, 403, 'FORBIDDEN', 'Bạn không có quyền xem ảnh này.');
      }
      const bytes = await imageStorage.get(image.storage_key);
      recordImageView(database, { imageId: image.id, eventType: 'view', request, bytesServed: bytes.length });
      return sendBinaryImage(response, bytes, image.mime_type, { isSvg: image.extension === 'svg' });
    } catch {
      return fail(response, 502, 'STORAGE_ERROR', 'Không thể tải tệp ảnh từ storage.');
    }
  });

  router.get('/images/:id/thumbnail', optionalAuth, async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh.');
    if (!imageStorage || typeof imageStorage.get !== 'function') {
      return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Lưu trữ ảnh chưa được cấu hình.');
    }
    try {
      const res = await database.query('SELECT * FROM images WHERE id = $1 LIMIT 1', [id]);
      const image = res.rows[0];
      if (!image || image.deleted_at) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh.');
      const isOwnerOrAdmin = request.authUser && (request.authUser.role === 'ADMIN' || request.authUser.id === image.owner_id);
      if (!isOwnerOrAdmin) {
        const access = await checkImageAccess({ database, jwtSecret, request, image });
        if (!access.allowed) return fail(response, 403, 'FORBIDDEN', 'Bạn không có quyền xem ảnh này.');
      }
      const thumbRes = await database.query(
        `SELECT storage_key, mime_type, extension FROM image_variants
         WHERE image_id = $1 AND variant_type = 'thumbnail' ORDER BY created_at DESC LIMIT 1`,
        [id],
      );
      const target = thumbRes.rows[0] || image;
      const bytes = await imageStorage.get(target.storage_key);
      return sendBinaryImage(response, bytes, target.mime_type, { isSvg: target.extension === 'svg' });
    } catch {
      return fail(response, 502, 'STORAGE_ERROR', 'Không thể tải thumbnail ảnh.');
    }
  });

  router.get('/images/:id/download', optionalAuth, async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh.');
    if (!imageStorage || typeof imageStorage.get !== 'function') {
      return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Lưu trữ ảnh chưa được cấu hình.');
    }
    try {
      const res = await database.query('SELECT * FROM images WHERE id = $1 LIMIT 1', [id]);
      const image = res.rows[0];
      if (!image || image.deleted_at) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh.');
      const isOwnerOrAdmin = request.authUser && (request.authUser.role === 'ADMIN' || request.authUser.id === image.owner_id);
      if (!isOwnerOrAdmin) {
        const access = await checkImageAccess({ database, jwtSecret, request, image });
        if (!access.allowed) return fail(response, 403, 'FORBIDDEN', 'Bạn không có quyền tải ảnh này.');
        if (!access.allowDownload) return fail(response, 403, 'DOWNLOAD_DISABLED', 'Liên kết chia sẻ này đã tắt quyền tải xuống.');
      }
      const bytes = await imageStorage.get(image.storage_key);
      recordImageView(database, { imageId: image.id, eventType: 'download', request, bytesServed: bytes.length });
      return sendBinaryImage(response, bytes, image.mime_type, {
        isSvg: image.extension === 'svg',
        downloadName: image.filename || `image.${image.extension}`,
      });
    } catch {
      return fail(response, 502, 'STORAGE_ERROR', 'Không thể tải xuống ảnh.');
    }
  });

  router.get('/images/:id/variants/:variantId/file', optionalAuth, async (request, response) => {
    const { id, variantId } = request.params;
    if (!uuid.safeParse(id).success || !uuid.safeParse(variantId).success) {
      return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy phiên bản ảnh.');
    }
    if (!imageStorage || typeof imageStorage.get !== 'function') {
      return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Lưu trữ ảnh chưa được cấu hình.');
    }
    try {
      const res = await database.query(
        `SELECT i.*, v.storage_key AS v_key, v.mime_type AS v_mime, v.extension AS v_ext
         FROM images i
         JOIN image_variants v ON v.image_id = i.id
         WHERE i.id = $1 AND v.id = $2 LIMIT 1`,
        [id, variantId],
      );
      const row = res.rows[0];
      if (!row || row.deleted_at) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy phiên bản ảnh.');
      const isOwnerOrAdmin = request.authUser && (request.authUser.role === 'ADMIN' || request.authUser.id === row.owner_id);
      if (!isOwnerOrAdmin) {
        const access = await checkImageAccess({ database, jwtSecret, request, image: row });
        if (!access.allowed) return fail(response, 403, 'FORBIDDEN', 'Bạn không có quyền xem phiên bản ảnh này.');
      }
      const bytes = await imageStorage.get(row.v_key);
      recordImageView(database, { imageId: row.id, eventType: 'view', request, bytesServed: bytes.length });
      return sendBinaryImage(response, bytes, row.v_mime, { isSvg: row.v_ext === 'svg' });
    } catch {
      return fail(response, 502, 'STORAGE_ERROR', 'Không thể tải tệp phiên bản ảnh.');
    }
  });

  router.get('/images/:id/variants', authenticate, requireScope('images:read'), async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã ảnh không hợp lệ.');
    try {
      const imgRes = await database.query('SELECT id, owner_id FROM images WHERE id = $1 LIMIT 1', [id]);
      const image = imgRes.rows[0];
      if (!image || (request.authUser.role !== 'ADMIN' && image.owner_id !== request.authUser.id)) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh.');
      }
      const variants = await database.query(
        'SELECT * FROM image_variants WHERE image_id = $1 ORDER BY created_at DESC',
        [id],
      );
      return ok(response, variants.rows.map((v) => ({
        id: v.id,
        imageId: v.image_id,
        variantType: v.variant_type,
        label: v.label,
        extension: v.extension,
        mimeType: v.mime_type,
        sizeBytes: Number(v.size_bytes ?? 0),
        width: v.width,
        height: v.height,
        transformParams: v.transform_params,
        url: `/api/v1/images/${id}/variants/${v.id}/file`,
        createdAt: v.created_at,
      })));
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tải danh sách biến thể.');
    }
  });

  router.post('/images/:id/transform', authenticate, requireScope('images:write'), async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã ảnh không hợp lệ.');
    const parsed = transformSchema.safeParse(request.body);
    if (!parsed.success) return zodValidationError(response, parsed.error);
    if (!imageStorage || typeof imageStorage.get !== 'function' || typeof imageStorage.put !== 'function') {
      return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Lưu trữ ảnh chưa được cấu hình.');
    }

    try {
      const imgRes = await database.query('SELECT * FROM images WHERE id = $1 AND deleted_at IS NULL LIMIT 1', [id]);
      const image = imgRes.rows[0];
      if (!image || (request.authUser.role !== 'ADMIN' && image.owner_id !== request.authUser.id)) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh.');
      }
      if (image.extension === 'svg') {
        return fail(response, 422, 'UNSUPPORTED_TRANSFORM', 'Chỉnh sửa crop/resize chưa hỗ trợ trực tiếp cho vector SVG.');
      }

      const sourceBuffer = await imageStorage.get(image.storage_key);
      const output = await transformImage(sourceBuffer, parsed.data);
      const variantId = randomUUID();
      const variantKey = `variants/${variantId}.${output.extension}`;
      await imageStorage.put(variantKey, output.data, output.mimeType);

      try {
        const label = parsed.data.label || `Chỉnh sửa ${output.extension.toUpperCase()} (${output.width}×${output.height})`;
        const vRes = await database.query(
          `INSERT INTO image_variants (
             id, image_id, variant_type, label, storage_key, extension, mime_type,
             size_bytes, width, height, transform_params
           )
           VALUES ($1, $2, 'edited', $3, $4, $5, $6, $7, $8, $9, $10::jsonb)
           RETURNING *`,
          [
            variantId,
            image.id,
            label,
            variantKey,
            output.extension,
            output.mimeType,
            output.sizeBytes,
            output.width,
            output.height,
            JSON.stringify(parsed.data),
          ],
        );
        await database.query(
          'UPDATE users SET storage_used_bytes = storage_used_bytes + $1, updated_at = now() WHERE id = $2',
          [output.sizeBytes, image.owner_id],
        );
        const v = vRes.rows[0];
        return ok(response, {
          id: v.id,
          imageId: v.image_id,
          variantType: v.variant_type,
          label: v.label,
          extension: v.extension,
          mimeType: v.mime_type,
          sizeBytes: Number(v.size_bytes),
          width: v.width,
          height: v.height,
          transformParams: v.transform_params,
          url: `/api/v1/images/${image.id}/variants/${v.id}/file`,
          createdAt: v.created_at,
        }, { status: 201 });
      } catch (dbErr) {
        await imageStorage.remove?.(variantKey).catch(() => {});
        throw dbErr;
      }
    } catch (err) {
      return fail(response, err.status || 422, err.code || 'TRANSFORM_FAILED', err.message || 'Không thể chỉnh sửa ảnh.');
    }
  });

  router.delete('/images/:id/variants/:variantId', authenticate, requireScope('images:delete'), async (request, response) => {
    const { id, variantId } = request.params;
    if (!uuid.safeParse(id).success || !uuid.safeParse(variantId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã ảnh hoặc biến thể không hợp lệ.');
    }
    try {
      const res = await database.query(
        `SELECT v.id, v.storage_key, v.size_bytes, i.owner_id
         FROM image_variants v
         JOIN images i ON i.id = v.image_id
         WHERE v.id = $1 AND v.image_id = $2 LIMIT 1`,
        [variantId, id],
      );
      const row = res.rows[0];
      if (!row || (request.authUser.role !== 'ADMIN' && row.owner_id !== request.authUser.id)) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy biến thể ảnh.');
      }
      await database.query('DELETE FROM image_variants WHERE id = $1', [variantId]);
      await database.query(
        'UPDATE users SET storage_used_bytes = GREATEST(0, storage_used_bytes - $1), updated_at = now() WHERE id = $2',
        [Number(row.size_bytes || 0), row.owner_id],
      );
      await imageStorage?.remove?.(row.storage_key).catch(() => {});
      return ok(response, { id: variantId, deleted: true });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể xóa biến thể ảnh.');
    }
  });

  return router;
}
