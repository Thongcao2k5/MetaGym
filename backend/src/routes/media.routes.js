import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';

import { Router, raw } from 'express';
import sharp from 'sharp';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();
const MAX_BYTES = 5 * 1024 * 1024;

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, message, details: {} } });
}

function signature(secret, id, expires) {
  return createHmac('sha256', `${secret}:media-url`)
    .update(`${id}:${expires}`).digest('hex');
}

async function allowed(database, user, media) {
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
    raw({ type: ['image/png', 'image/jpeg'], limit: MAX_BYTES }),
    async (request, response) => {
      if (!['MEMBER', 'COACH'].includes(request.authUser.role)) {
        return fail(response, 403, 'FORBIDDEN', 'Chỉ Member và Coach được tải ảnh');
      }
      if (!imageStorage || typeof imageStorage.put !== 'function' ||
        typeof imageStorage.get !== 'function') {
        return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Lưu ảnh chưa được cấu hình');
      }
      const purpose = request.get('x-image-purpose');
      const mimeType = request.get('content-type')?.split(';')[0]?.toLowerCase();
      const fileName = request.get('x-file-name') ?? 'image';
      const bytes = request.body;
      if (!['MESSAGE', 'PROGRESS_PHOTO', 'MEAL_PHOTO'].includes(purpose) ||
        !['image/png', 'image/jpeg'].includes(mimeType) ||
        !Buffer.isBuffer(bytes) || !bytes.length || bytes.length > MAX_BYTES ||
        fileName.length > 255) {
        return fail(response, 422, 'VALIDATION_ERROR', 'Ảnh không hợp lệ');
      }
      let normalized;
      let image;
      try {
        const format = mimeType === 'image/png' ? 'png' : 'jpeg';
        const source = sharp(bytes, { limitInputPixels: 20000000 });
        const metadata = await source.metadata();
        if (metadata.format !== format || (metadata.pages ?? 1) !== 1) {
          throw new Error('INVALID_FORMAT');
        }
        const output = await source.rotate().toFormat(format).toBuffer({ resolveWithObject: true });
        normalized = output.data;
        image = output.info;
        if (!normalized.length || normalized.length > MAX_BYTES ||
          image.width < 1 || image.height < 1 ||
          image.width > 10000 || image.height > 10000) throw new Error('INVALID_SIZE');
      } catch { return fail(response, 422, 'VALIDATION_ERROR', 'Ảnh không hợp lệ'); }
      const size = normalized.length;
      const id = randomUUID();
      const key = randomUUID();
      try {
        await database.query(
          `INSERT INTO media_assets
           (id, owner_id, purpose, access_scope, storage_key,
            original_name, expires_at)
           VALUES ($1, $2, $3, 'PRIVATE', $4, $5,
                   now() + interval '15 minutes')`,
          [id, request.authUser.id, purpose, key, fileName],
        );
        await imageStorage.put(key, normalized, mimeType);
        await database.query(
          `UPDATE media_assets SET status = 'READY', mime_type = $1,
           size_bytes = $2, width = $3, height = $4, ready_at = now()
           WHERE id = $5`,
          [mimeType, size, image.width, image.height, id],
        );
        return response.status(201).json({ data: {
          id, purpose, mimeType, sizeBytes: size,
          width: image.width, height: image.height,
        } });
      } catch {
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
