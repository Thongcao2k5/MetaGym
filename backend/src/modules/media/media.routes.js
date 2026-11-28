import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';

import { Router, raw } from 'express';
import sharp from 'sharp';
import { z } from 'zod';

import {
  generatePackageThumbnail,
  optimizeUploadedMedia,
  processPackageImages,
} from './image-processor.js';
import { resetSupabaseSyncCache } from './supabase-sync.js';
import { createAuthentication } from '../users/users.routes.js';
import {
  buildMediaStorageKey,
  buildPackageStorageKeys,
  buildSystemIconStorageKeys,
  buildVoucherStorageKeys,
  resolveThumbKeys,
} from '../../storage/storage-key.js';

const uuid = z.uuid();
const MAX_BYTES = 5 * 1024 * 1024;
const PUBLIC_PURPOSES = ['GYM', 'EQUIPMENT', 'PACKAGE', 'SYSTEM_ICON', 'VOUCHER'];
const WEBP_THUMB_PURPOSES = new Set(['PACKAGE', 'SYSTEM_ICON', 'VOUCHER']);

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, message, details: {} } });
}

function signature(secret, id, expires) {
  return createHmac('sha256', `${secret}:media-url`)
    .update(`${id}:${expires}`).digest('hex');
}

async function allowed(database, user, media) {
  if (user.role === 'ADMIN') {
    return media.access_scope === 'PUBLIC' && PUBLIC_PURPOSES.includes(media.purpose);
  }
  if (media.owner_id === user.id) return true;
  if (media.purpose === 'MESSAGE') {
    const found = await database.query(
      `SELECT 1 FROM messages m JOIN conversation_participants p
       ON p.conversation_id = m.conversation_id
       WHERE m.media_id = $1 AND p.user_id = $2 LIMIT 1`,
      [media.id, user.id],
    );
    return found.rows.length > 0;
  }
  return false;
}

export function createMediaRouter({ database, jwtSecret, imageStorage }) {
  const router = Router();
  const authenticate = createAuthentication({ database, jwtSecret });
  router.post('/media/images', authenticate,
    raw({ type: ['image/png', 'image/jpeg', 'image/webp'], limit: MAX_BYTES }),
    async (request, response) => {
      const role = request.authUser.role;
      if (!['MEMBER', 'COACH', 'ADMIN'].includes(role)) {
        return fail(response, 403, 'FORBIDDEN', 'Không có quyền tải ảnh');
      }
      if (!imageStorage || typeof imageStorage.put !== 'function' ||
        typeof imageStorage.get !== 'function') {
        return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Lưu ảnh chưa được cấu hình');
      }
      const purpose = request.get('x-image-purpose');
      const mimeType = request.get('content-type')?.split(';')[0]?.toLowerCase();
      const fileName = request.get('x-file-name') ?? 'image';
      const bytes = request.body;
      let accessScope = 'PRIVATE';
      if (role === 'ADMIN') {
        if (!PUBLIC_PURPOSES.includes(purpose)) {
          return fail(
            response,
            403,
            'FORBIDDEN',
            'Admin chỉ được tải ảnh công khai cho phòng gym, thiết bị, gói tập hoặc icon hệ thống',
          );
        }
        accessScope = 'PUBLIC';
      } else {
        const validPurpose =
          ['MESSAGE', 'PROGRESS_PHOTO', 'MEAL_PHOTO'].includes(purpose) ||
          (purpose === 'COACH_OUTCOME' && role === 'COACH');
        if (!validPurpose) {
          return fail(response, 422, 'VALIDATION_ERROR', 'Ảnh không hợp lệ');
        }
      }
      const allowedMimes = WEBP_THUMB_PURPOSES.has(purpose)
        ? ['image/png', 'image/jpeg', 'image/webp']
        : ['image/png', 'image/jpeg'];
      if (!allowedMimes.includes(mimeType) ||
        !Buffer.isBuffer(bytes) || !bytes.length || bytes.length > MAX_BYTES ||
        fileName.length > 255) {
        return fail(response, 422, 'VALIDATION_ERROR', 'Ảnh không hợp lệ');
      }
      let normalized;
      let thumbNormalized = null;
      let outputMimeType = mimeType;
      let image;
      try {
        if (WEBP_THUMB_PURPOSES.has(purpose)) {
          const processed = await processPackageImages(bytes);
          normalized = processed.full.data;
          thumbNormalized = processed.thumb.data;
          outputMimeType = processed.mimeType;
          image = { width: processed.full.width, height: processed.full.height };
        } else {
          const format = mimeType === 'image/png' ? 'png' : 'jpeg';
          const source = sharp(bytes, { limitInputPixels: 20000000 });
          const metadata = await source.metadata();
          if (metadata.format !== format || (metadata.pages ?? 1) !== 1) {
            throw new Error('INVALID_FORMAT');
          }
          const output = await optimizeUploadedMedia(bytes, format);
          normalized = output.data;
          image = output.info;
        }
        if (!normalized.length || normalized.length > MAX_BYTES ||
          image.width < 1 || image.height < 1 ||
          image.width > 10000 || image.height > 10000) throw new Error('INVALID_SIZE');
      } catch { return fail(response, 422, 'VALIDATION_ERROR', 'Ảnh không hợp lệ'); }
      const size = normalized.length;
      const id = randomUUID();
      const nestedKeys = purpose === 'PACKAGE'
        ? buildPackageStorageKeys(id)
        : purpose === 'SYSTEM_ICON'
          ? buildSystemIconStorageKeys(id)
          : purpose === 'VOUCHER'
            ? buildVoucherStorageKeys(id)
            : null;
      const key = nestedKeys
        ? nestedKeys.storageKey
        : buildMediaStorageKey(purpose, id, mimeType === 'image/png' ? 'png' : 'jpg');
      const thumbKey = nestedKeys?.thumbKey || null;
      let objectStored = false;
      try {
        await database.query(
          `INSERT INTO media_assets
           (id, owner_id, purpose, access_scope, storage_key,
            original_name, expires_at)
           VALUES ($1, $2, $3, $4, $5, $6,
                   now() + interval '15 minutes')`,
          [id, request.authUser.id, purpose, accessScope, key, fileName],
        );
        await imageStorage.put(key, normalized, outputMimeType);
        objectStored = true;
        if (thumbKey && thumbNormalized) {
          await imageStorage.put(thumbKey, thumbNormalized, outputMimeType).catch(() => {});
        }
        await database.query(
          `UPDATE media_assets SET status = 'READY', mime_type = $1,
           size_bytes = $2, width = $3, height = $4, ready_at = now()
           WHERE id = $5`,
          [outputMimeType, size, image.width, image.height, id],
        );
        resetSupabaseSyncCache();
        return response.status(201).json({ data: {
          id, purpose, accessScope, mimeType: outputMimeType, sizeBytes: size,
          width: image.width, height: image.height,
          ...(accessScope === 'PUBLIC'
            ? {
                publicUrl: `/api/v1/media/public/${id}?v=${id}`,
                thumbnailUrl: `/api/v1/media/public/${id}?size=120&v=${id}`,
              }
            : {}),
        } });
      } catch {
        if (objectStored && typeof imageStorage.remove === 'function') {
          await imageStorage.remove(key).catch(() => {});
          if (thumbKey) await imageStorage.remove(thumbKey).catch(() => {});
        }
        await database.query(
          `UPDATE media_assets SET status = 'FAILED', failed_at = now(),
           failure_reason = 'Storage operation failed' WHERE id = $1
           AND status = 'UPLOADING'`, [id],
        ).catch(() => {});
        return fail(response, 502, 'STORAGE_ERROR', 'Không lưu được ảnh');
      }
    });

  router.use((error, _request, response, next) => {
    if (error.type === 'entity.too.large') {
      return fail(response, 413, 'PAYLOAD_TOO_LARGE', 'Ảnh vượt giới hạn 5 MB');
    }
    return next(error);
  });

  router.get('/media/public/:mediaId', async (request, response) => {
    const { mediaId } = request.params;
    if (!uuid.safeParse(mediaId).success) {
      return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh');
    }
    if (!imageStorage || typeof imageStorage.get !== 'function') {
      return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Lưu ảnh chưa được cấu hình');
    }
    const isThumb = request.query.size === 'thumb'
      || request.query.size === '120'
      || request.query.thumb === '1'
      || request.query.thumb === 'true';
    try {
      const found = await database.query(
        `SELECT storage_key, mime_type
         FROM media_assets
         WHERE id = $1
           AND status = 'READY'
           AND access_scope = 'PUBLIC'
           AND purpose = ANY($2::text[])`,
        [mediaId, PUBLIC_PURPOSES],
      );
      if (!found.rows.length) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh');
      }
      const etag = isThumb ? `"${mediaId}-120"` : `"${mediaId}"`;
      response.set('ETag', etag);
      if (request.headers['if-none-match'] === etag) {
        return response.status(304).end();
      }

      const storageKey = found.rows[0].storage_key;
      let mimeType = found.rows[0].mime_type || 'image/webp';
      let bytes = null;

      if (isThumb) {
        const thumbCandidates = resolveThumbKeys(storageKey);
        for (const candidateKey of thumbCandidates) {
          try {
            const candidateBytes = await imageStorage.get(candidateKey);
            if (Buffer.isBuffer(candidateBytes)) {
              bytes = candidateBytes;
              mimeType = 'image/webp';
              break;
            }
          } catch {
            // Try next candidate or lazy-generate from original
          }
        }
        if (!Buffer.isBuffer(bytes)) {
          const originalBytes = await imageStorage.get(storageKey);
          if (!Buffer.isBuffer(originalBytes)) throw new Error('INVALID_STORAGE_RESPONSE');
          const thumbOut = await generatePackageThumbnail(originalBytes);
          bytes = thumbOut.data;
          mimeType = 'image/webp';
          if (typeof imageStorage.put === 'function' && thumbCandidates[0]) {
            await imageStorage.put(thumbCandidates[0], bytes, 'image/webp').catch(() => {});
          }
        }
      } else {
        bytes = await imageStorage.get(storageKey);
      }

      if (!Buffer.isBuffer(bytes)) throw new Error('INVALID_STORAGE_RESPONSE');
      response.set('Cache-Control', 'public, max-age=3600');
      response.type(mimeType);
      return response.send(bytes);
    } catch { return fail(response, 502, 'STORAGE_ERROR', 'Không tải được ảnh'); }
  });

  router.get('/media/images/:mediaId/access-url', authenticate,
    async (request, response) => {
      if (!uuid.safeParse(request.params.mediaId).success) {
        return fail(response, 422, 'VALIDATION_ERROR', 'Mã ảnh không hợp lệ');
      }
      if (!imageStorage || typeof imageStorage.get !== 'function') {
        return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Lưu ảnh chưa được cấu hình');
      }
      try {
        const found = await database.query(
          `SELECT * FROM media_assets WHERE id = $1 AND status = 'READY'`,
          [request.params.mediaId],
        );
        const media = found.rows[0];
        if (!media || !await allowed(database, request.authUser, media)) {
          return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh');
        }
        const expires = Math.floor(Date.now() / 1000) + 300;
        const sig = signature(jwtSecret, media.id, expires);
        const url = `/api/v1/media/images/${media.id}?expires=${expires}&signature=${sig}`;
        return response.json({ data: { url, expiresAt: new Date(expires * 1000).toISOString() } });
      } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không cấp được URL ảnh'); }
    });

  router.get('/media/images/:mediaId', async (request, response) => {
    const { mediaId } = request.params;
    const parsed = z.strictObject({
      expires: z.coerce.number().int().positive(),
      signature: z.string().regex(/^[0-9a-f]{64}$/),
    }).safeParse(request.query);
    if (!uuid.safeParse(mediaId).success || !parsed.success) {
      return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh');
    }
    const expires = parsed.data.expires;
    const now = Math.floor(Date.now() / 1000);
    if (expires < now || expires > now + 300) {
      return fail(response, 404, 'NOT_FOUND', 'URL ảnh đã hết hạn');
    }
    const expected = Buffer.from(signature(jwtSecret, mediaId, expires), 'hex');
    const provided = Buffer.from(parsed.data.signature, 'hex');
    if (!timingSafeEqual(expected, provided)) {
      return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh');
    }
    if (!imageStorage || typeof imageStorage.get !== 'function') {
      return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Lưu ảnh chưa được cấu hình');
    }
    try {
      const found = await database.query(
        `SELECT storage_key, mime_type FROM media_assets
         WHERE id = $1 AND status = 'READY'`, [mediaId],
      );
      if (!found.rows.length) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh');
      const bytes = await imageStorage.get(found.rows[0].storage_key);
      if (!Buffer.isBuffer(bytes)) throw new Error('INVALID_STORAGE_RESPONSE');
      response.set('Cache-Control', 'private, max-age=300');
      response.type(found.rows[0].mime_type);
      return response.send(bytes);
    } catch { return fail(response, 502, 'STORAGE_ERROR', 'Không tải được ảnh'); }
  });
  return router;
}
