import { randomBytes, randomUUID } from 'node:crypto';

import bcrypt from 'bcryptjs';
import { Router } from 'express';
import { z } from 'zod';

import {
  createApiLogMiddleware,
  createImageServerAuth,
  hashApiKey,
  requireAdminRole,
} from './image-server-auth.js';
import {
  createShareAccessToken,
  fail,
  loadSystemSettings,
  ok,
  recordImageAudit,
  verifyShareAccessToken,
  zodValidationError,
} from './image-server-helpers.js';
import { resolveThumbKeys } from '../../storage/storage-key.js';
import {
  inferDomainFolder,
  isSecondaryVariantKey,
  listStorageObjects,
  syncSupabaseToImageLibrary,
} from './supabase-sync.js';

const uuid = z.uuid();

const createShareSchema = z.strictObject({
  targetType: z.enum(['image', 'album']),
  imageId: uuid.optional(),
  albumId: uuid.optional(),
  expiresAt: z.iso.datetime().nullable().optional(),
  password: z.string().min(4).max(72).nullable().optional(),
  allowDownload: z.boolean().default(true),
}).superRefine((val, ctx) => {
  if (val.targetType === 'image' && !val.imageId) {
    ctx.addIssue({ code: 'custom', path: ['imageId'], message: 'Cần chọn ảnh cần chia sẻ.' });
  }
  if (val.targetType === 'album' && !val.albumId) {
    ctx.addIssue({ code: 'custom', path: ['albumId'], message: 'Cần chọn album cần chia sẻ.' });
  }
});

const verifySharePasswordSchema = z.strictObject({
  password: z.string().min(1).max(72),
});

const createApiKeySchema = z.strictObject({
  name: z.string().trim().min(2).max(120),
  scopes: z.array(z.string().trim().min(1)).min(1).default(['images:read']),
  rateLimitPerMinute: z.coerce.number().int().min(1).max(10000).default(60),
  expiresAt: z.iso.datetime().nullable().optional(),
});

const cleanupOrphansSchema = z.strictObject({
  keys: z.array(z.string().trim().min(1).max(500)).min(1).max(500),
});

const restoreMetadataSchema = z.strictObject({
  systemSettings: z.record(z.string(), z.record(z.string(), z.unknown())).optional(),
  tags: z.array(z.object({
    id: uuid,
    name: z.string().min(1).max(80),
    slug: z.string().min(1).max(100),
    color: z.string().max(20).nullable().optional(),
  })).optional(),
  folders: z.array(z.object({
    id: uuid,
    owner_id: uuid.optional(),
    ownerId: uuid.optional(),
    parent_id: uuid.nullable().optional(),
    parentId: uuid.nullable().optional(),
    name: z.string().min(1).max(150),
    slug: z.string().min(1).max(180),
  })).optional(),
  albums: z.array(z.object({
    id: uuid,
    owner_id: uuid.optional(),
    ownerId: uuid.optional(),
    title: z.string().min(1).max(180),
    description: z.string().nullable().optional(),
    visibility: z.enum(['public', 'private']).default('private'),
    share_slug: z.string().nullable().optional(),
    shareSlug: z.string().nullable().optional(),
  })).optional(),
});

const updateSettingsSchema = z.strictObject({
  site_branding: z.strictObject({
    siteName: z.string().trim().min(1).max(120),
    logoUrl: z.string().trim().max(500),
    faviconUrl: z.string().trim().max(500),
  }).optional(),
  upload_limits: z.strictObject({
    maxFileSizeMb: z.coerce.number().int().min(1).max(100),
    maxFilesPerUpload: z.coerce.number().int().min(1).max(50),
    allowedFormats: z.array(z.enum(['jpeg', 'png', 'webp', 'avif', 'gif', 'svg'])).min(1),
    defaultVisibility: z.enum(['public', 'private']),
    allowUrlImport: z.boolean(),
  }).optional(),
  image_processing: z.strictObject({
    thumbnailSize: z.coerce.number().int().min(100).max(1200),
    autoWebp: z.boolean(),
    autoAvif: z.boolean(),
    defaultQuality: z.coerce.number().int().min(10).max(100),
    stripGpsExif: z.boolean(),
  }).optional(),
  smtp: z.strictObject({
    enabled: z.boolean(),
    host: z.string().trim().max(200),
    port: z.coerce.number().int().min(1).max(65535),
    secure: z.boolean(),
    fromEmail: z.string().trim().max(200),
  }).optional(),
  rate_limits: z.strictObject({
    publicApiPerMinute: z.coerce.number().int().min(1).max(10000),
    uploadPerMinute: z.coerce.number().int().min(1).max(1000),
  }).optional(),
  maintenance_mode: z.strictObject({
    enabled: z.boolean(),
    message: z.string().trim().max(500),
  }).optional(),
  backup_policy: z.strictObject({
    autoBackupEnabled: z.boolean(),
    retentionDays: z.coerce.number().int().min(1).max(3650),
  }).optional(),
});

const quotaPatchSchema = z.strictObject({
  storageQuotaBytes: z.coerce.number().int().min(1024 * 1024).max(1024 * 1024 * 1024 * 1024),
  roleCode: z.enum(['super_admin', 'admin', 'user']).optional(),
});

export function createImageAdminRouter({ database, jwtSecret, imageStorage }) {
  const router = Router();
  const authenticate = createImageServerAuth({ database, jwtSecret });
  const apiLogger = createApiLogMiddleware({ database });

  // ---------------- PUBLIC SHARE ENDPOINTS ----------------
  router.get('/public/shares/:token', async (request, response) => {
    const token = String(request.params.token || '').trim();
    try {
      const res = await database.query(
        `SELECT s.*, i.filename AS image_filename, i.mime_type, i.size_bytes, i.width, i.height, i.deleted_at AS image_deleted,
                a.title AS album_title, a.description AS album_description, a.deleted_at AS album_deleted
         FROM share_links s
         LEFT JOIN images i ON i.id = s.image_id
         LEFT JOIN albums a ON a.id = s.album_id
         WHERE s.token = $1 LIMIT 1`,
        [token],
      );
      const share = res.rows[0];
      if (!share || share.revoked_at) {
        return fail(response, 410, 'SHARE_REVOKED', 'Liên kết chia sẻ không tồn tại hoặc đã bị thu hồi.');
      }
      if (share.expires_at && new Date(share.expires_at).getTime() <= Date.now()) {
        return fail(response, 410, 'SHARE_EXPIRED', 'Liên kết chia sẻ đã hết hạn.');
      }
      if ((share.target_type === 'image' && share.image_deleted) || (share.target_type === 'album' && share.album_deleted)) {
        return fail(response, 404, 'NOT_FOUND', 'Nội dung được chia sẻ không còn tồn tại.');
      }

      if (share.password_hash) {
        const providedAccess = request.get('x-share-access-token') || request.query?.shareAccess;
        if (!verifyShareAccessToken(jwtSecret, token, String(providedAccess || ''))) {
          return ok(response, {
            requiresPassword: true,
            targetType: share.target_type,
            allowDownload: Boolean(share.allow_download),
            expiresAt: share.expires_at,
          });
        }
      }

      await database.query('UPDATE share_links SET access_count = access_count + 1 WHERE id = $1', [share.id]);
      const accessQs = request.get('x-share-access-token') || request.query?.shareAccess
        ? `&shareAccess=${encodeURIComponent(String(request.get('x-share-access-token') || request.query?.shareAccess))}`
        : '';

      if (share.target_type === 'image') {
        return ok(response, {
          requiresPassword: false,
          targetType: 'image',
          allowDownload: Boolean(share.allow_download),
          expiresAt: share.expires_at,
          image: {
            id: share.image_id,
            filename: share.image_filename,
            mimeType: share.mime_type,
            sizeBytes: Number(share.size_bytes ?? 0),
            width: share.width,
            height: share.height,
            originalUrl: `/api/v1/images/${share.image_id}/file?shareToken=${encodeURIComponent(token)}${accessQs}`,
            thumbnailUrl: `/api/v1/images/${share.image_id}/thumbnail?shareToken=${encodeURIComponent(token)}${accessQs}`,
            downloadUrl: share.allow_download
              ? `/api/v1/images/${share.image_id}/download?shareToken=${encodeURIComponent(token)}${accessQs}`
              : null,
          },
        });
      }

      const albumImages = await database.query(
        `SELECT i.id, i.filename, i.mime_type, i.size_bytes, i.width, i.height
         FROM album_images ai
         JOIN images i ON i.id = ai.image_id
         WHERE ai.album_id = $1 AND i.deleted_at IS NULL
         ORDER BY ai.sort_order ASC, ai.added_at DESC`,
        [share.album_id],
      );
      return ok(response, {
        requiresPassword: false,
        targetType: 'album',
        allowDownload: Boolean(share.allow_download),
        expiresAt: share.expires_at,
        album: {
          id: share.album_id,
          title: share.album_title,
          description: share.album_description ?? '',
          images: albumImages.rows.map((img) => ({
            id: img.id,
            filename: img.filename,
            mimeType: img.mime_type,
            sizeBytes: Number(img.size_bytes ?? 0),
            width: img.width,
            height: img.height,
            originalUrl: `/api/v1/images/${img.id}/file?shareToken=${encodeURIComponent(token)}${accessQs}`,
            thumbnailUrl: `/api/v1/images/${img.id}/thumbnail?shareToken=${encodeURIComponent(token)}${accessQs}`,
            downloadUrl: share.allow_download
              ? `/api/v1/images/${img.id}/download?shareToken=${encodeURIComponent(token)}${accessQs}`
              : null,
          })),
        },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể mở liên kết chia sẻ.');
    }
  });

  router.post('/public/shares/:token/verify', async (request, response) => {
    const token = String(request.params.token || '').trim();
    const parsed = verifySharePasswordSchema.safeParse(request.body);
    if (!parsed.success) return zodValidationError(response, parsed.error);
    try {
      const res = await database.query(
        'SELECT id, password_hash, expires_at, revoked_at FROM share_links WHERE token = $1 LIMIT 1',
        [token],
      );
      const share = res.rows[0];
      if (!share || share.revoked_at) {
        return fail(response, 410, 'SHARE_REVOKED', 'Liên kết chia sẻ đã bị thu hồi.');
      }
      if (share.expires_at && new Date(share.expires_at).getTime() <= Date.now()) {
        return fail(response, 410, 'SHARE_EXPIRED', 'Liên kết chia sẻ đã hết hạn.');
      }
      if (!share.password_hash) {
        return ok(response, { accessToken: createShareAccessToken(jwtSecret, token) });
      }
      const matched = await bcrypt.compare(parsed.data.password, share.password_hash);
      if (!matched) {
        return fail(response, 401, 'INVALID_SHARE_PASSWORD', 'Mật khẩu chia sẻ không đúng.');
      }
      return ok(response, { accessToken: createShareAccessToken(jwtSecret, token) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể xác thực mật khẩu chia sẻ.');
    }
  });

  // ---------------- AUTHENTICATED SHARING ----------------
  router.get('/shares', apiLogger, authenticate, async (request, response) => {
    try {
      const isAdmin = request.authUser.role === 'ADMIN';
      const values = isAdmin ? [] : [request.authUser.id];
      const whereSql = isAdmin ? '' : 'WHERE s.created_by = $1';
      const res = await database.query(
        `SELECT s.*, i.filename AS image_filename, a.title AS album_title, u.full_name AS creator_name
         FROM share_links s
         LEFT JOIN images i ON i.id = s.image_id
         LEFT JOIN albums a ON a.id = s.album_id
         LEFT JOIN users u ON u.id = s.created_by
         ${whereSql}
         ORDER BY s.created_at DESC`,
        values,
      );
      return ok(response, res.rows.map((s) => ({
        id: s.id,
        createdBy: s.created_by,
        creatorName: s.creator_name ?? null,
        targetType: s.target_type,
        imageId: s.image_id,
        albumId: s.album_id,
        targetLabel: s.target_type === 'image' ? (s.image_filename || 'Ảnh') : (s.album_title || 'Album'),
        token: s.token,
        shareUrl: `/api/v1/public/shares/${s.token}`,
        hasPassword: Boolean(s.password_hash),
        allowDownload: Boolean(s.allow_download),
        expiresAt: s.expires_at,
        revokedAt: s.revoked_at,
        accessCount: Number(s.access_count ?? 0),
        createdAt: s.created_at,
      })));
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tải danh sách liên kết chia sẻ.');
    }
  });

  router.post('/shares', apiLogger, authenticate, async (request, response) => {
    const parsed = createShareSchema.safeParse(request.body);
    if (!parsed.success) return zodValidationError(response, parsed.error);
    const { targetType, imageId = null, albumId = null, expiresAt = null, password = null, allowDownload } = parsed.data;
    try {
      if (targetType === 'image') {
        const res = await database.query('SELECT id, owner_id FROM images WHERE id = $1 AND deleted_at IS NULL', [imageId]);
        const img = res.rows[0];
        if (!img || (request.authUser.role !== 'ADMIN' && img.owner_id !== request.authUser.id)) {
          return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh để chia sẻ.');
        }
      } else {
        const res = await database.query('SELECT id, owner_id FROM albums WHERE id = $1 AND deleted_at IS NULL', [albumId]);
        const alb = res.rows[0];
        if (!alb || (request.authUser.role !== 'ADMIN' && alb.owner_id !== request.authUser.id)) {
          return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy album để chia sẻ.');
        }
      }

      const token = randomBytes(24).toString('hex');
      const passwordHash = password ? await bcrypt.hash(password, 10) : null;
      const inserted = await database.query(
        `INSERT INTO share_links (id, created_by, target_type, image_id, album_id, token, password_hash, allow_download, expires_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         RETURNING *`,
        [
          randomUUID(),
          request.authUser.id,
          targetType,
          targetType === 'image' ? imageId : null,
          targetType === 'album' ? albumId : null,
          token,
          passwordHash,
          allowDownload,
          expiresAt,
        ],
      );
      const s = inserted.rows[0];
      return ok(response, {
        id: s.id,
        targetType: s.target_type,
        imageId: s.image_id,
        albumId: s.album_id,
        token: s.token,
        shareUrl: `/api/v1/public/shares/${s.token}`,
        hasPassword: Boolean(s.password_hash),
        allowDownload: Boolean(s.allow_download),
        expiresAt: s.expires_at,
        createdAt: s.created_at,
      }, { status: 201 });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tạo liên kết chia sẻ.');
    }
  });

  router.delete('/shares/:id', apiLogger, authenticate, async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã chia sẻ không hợp lệ.');
    try {
      const existing = await database.query('SELECT * FROM share_links WHERE id = $1', [id]);
      const share = existing.rows[0];
      if (!share || (request.authUser.role !== 'ADMIN' && share.created_by !== request.authUser.id)) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy liên kết chia sẻ.');
      }
      await database.query('UPDATE share_links SET revoked_at = COALESCE(revoked_at, now()), updated_at = now() WHERE id = $1', [id]);
      return ok(response, { id, revoked: true });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể thu hồi liên kết chia sẻ.');
    }
  });

  // ---------------- API KEYS ----------------
  router.get('/api-keys', apiLogger, authenticate, async (request, response) => {
    try {
      const isAdmin = request.authUser.role === 'ADMIN';
      const values = isAdmin ? [] : [request.authUser.id];
      const whereSql = isAdmin ? '' : 'WHERE k.user_id = $1';
      const res = await database.query(
        `SELECT k.id, k.user_id, k.name, k.key_prefix, k.scopes, k.rate_limit_per_minute,
                k.request_count, k.last_used_at, k.expires_at, k.revoked_at, k.created_at,
                u.full_name AS owner_name, u.email::text AS owner_email
         FROM api_keys k
         LEFT JOIN users u ON u.id = k.user_id
         ${whereSql}
         ORDER BY k.created_at DESC`,
        values,
      );
      return ok(response, res.rows.map((k) => ({
        id: k.id,
        userId: k.user_id,
        ownerName: k.owner_name ?? null,
        ownerEmail: k.owner_email ?? null,
        name: k.name,
        keyPrefix: k.key_prefix,
        scopes: Array.isArray(k.scopes) ? k.scopes : [],
        rateLimitPerMinute: Number(k.rate_limit_per_minute ?? 60),
        requestCount: Number(k.request_count ?? 0),
        lastUsedAt: k.last_used_at,
        expiresAt: k.expires_at,
        revokedAt: k.revoked_at,
        createdAt: k.created_at,
      })));
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tải danh sách API Key.');
    }
  });

  router.post('/api-keys', apiLogger, authenticate, async (request, response) => {
    const parsed = createApiKeySchema.safeParse(request.body);
    if (!parsed.success) return zodValidationError(response, parsed.error);
    try {
      const rawKey = `mg_live_${randomBytes(24).toString('hex')}`;
      const keyPrefix = rawKey.slice(0, 14);
      const keyHash = hashApiKey(rawKey);
      const id = randomUUID();
      const inserted = await database.query(
        `INSERT INTO api_keys (id, user_id, name, key_prefix, key_hash, scopes, rate_limit_per_minute, expires_at)
         VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7, $8)
         RETURNING id, user_id, name, key_prefix, scopes, rate_limit_per_minute, request_count, expires_at, created_at`,
        [
          id,
          request.authUser.id,
          parsed.data.name,
          keyPrefix,
          keyHash,
          JSON.stringify(parsed.data.scopes),
          parsed.data.rateLimitPerMinute,
          parsed.data.expiresAt ?? null,
        ],
      );
      if (request.authUser.role === 'ADMIN') {
        await recordImageAudit(database, request.authUser.id, 'API_KEY_CREATED', 'API_KEY', id, `Tạo API Key ${parsed.data.name}`, {
          name: parsed.data.name,
          keyPrefix,
          scopes: parsed.data.scopes,
        });
      }
      const k = inserted.rows[0];
      return ok(response, {
        id: k.id,
        name: k.name,
        keyPrefix: k.key_prefix,
        apiKey: rawKey,
        scopes: k.scopes,
        rateLimitPerMinute: Number(k.rate_limit_per_minute),
        expiresAt: k.expires_at,
        createdAt: k.created_at,
      }, { status: 201 });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tạo API Key.');
    }
  });

  router.delete('/api-keys/:id', apiLogger, authenticate, async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã API Key không hợp lệ.');
    try {
      const existing = await database.query('SELECT * FROM api_keys WHERE id = $1', [id]);
      const keyRow = existing.rows[0];
      if (!keyRow || (request.authUser.role !== 'ADMIN' && keyRow.user_id !== request.authUser.id)) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy API Key.');
      }
      await database.query('UPDATE api_keys SET revoked_at = COALESCE(revoked_at, now()), updated_at = now() WHERE id = $1', [id]);
      if (request.authUser.role === 'ADMIN') {
        await recordImageAudit(database, request.authUser.id, 'API_KEY_REVOKED', 'API_KEY', id, `Thu hồi API Key ${keyRow.name}`, {
          name: keyRow.name,
          keyPrefix: keyRow.key_prefix,
        });
      }
      return ok(response, { id, revoked: true });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể thu hồi API Key.');
    }
  });

  router.get('/api-keys/:id/usage', apiLogger, authenticate, async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã API Key không hợp lệ.');
    try {
      const existing = await database.query(
        'SELECT id, user_id, name, key_prefix, request_count, last_used_at, rate_limit_per_minute FROM api_keys WHERE id = $1',
        [id],
      );
      const keyRow = existing.rows[0];
      if (!keyRow || (request.authUser.role !== 'ADMIN' && keyRow.user_id !== request.authUser.id)) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy API Key.');
      }
      const [logsRes, summaryRes] = await Promise.all([
        database.query(
          `SELECT method, endpoint, status_code, response_time_ms, bytes_transferred, created_at
           FROM api_logs WHERE api_key_id = $1 ORDER BY created_at DESC LIMIT 30`,
          [id],
        ),
        database.query(
          `SELECT COUNT(*) FILTER (WHERE status_code < 400)::int AS ok_count,
                  COUNT(*) FILTER (WHERE status_code >= 400 AND status_code < 500)::int AS client_err_count,
                  COUNT(*) FILTER (WHERE status_code >= 500)::int AS server_err_count,
                  COALESCE(AVG(response_time_ms), 0)::float8 AS avg_ms
           FROM api_logs WHERE api_key_id = $1`,
          [id],
        ),
      ]);
      return ok(response, {
        id: keyRow.id,
        name: keyRow.name,
        keyPrefix: keyRow.key_prefix,
        requestCount: Number(keyRow.request_count ?? 0),
        lastUsedAt: keyRow.last_used_at,
        rateLimitPerMinute: Number(keyRow.rate_limit_per_minute ?? 60),
        summary: summaryRes.rows[0] || { ok_count: 0, client_err_count: 0, server_err_count: 0, avg_ms: 0 },
        recentLogs: logsRes.rows,
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tải thống kê sử dụng API Key.');
    }
  });

  // ---------------- STATS & ANALYTICS ----------------
  router.get('/stats', apiLogger, authenticate, async (request, response) => {
    try {
      const isAdmin = request.authUser.role === 'ADMIN';
      if (isAdmin && imageStorage?.providerType === 'supabase') {
        await syncSupabaseToImageLibrary({
          database,
          imageStorage,
          fallbackOwnerId: request.authUser.id,
        }).catch(() => null);
      }
      const ownerFilter = isAdmin ? '' : 'AND owner_id = $1';
      const values = isAdmin ? [] : [request.authUser.id];
      const [totalsRes, albumsRes, foldersRes, dailyRes, recentRes] = await Promise.all([
        database.query(
          `SELECT COUNT(*)::int AS total_images,
                  COALESCE(SUM(size_bytes), 0)::bigint AS total_storage_bytes,
                  COALESCE(SUM(view_count), 0)::bigint AS total_views,
                  COALESCE(SUM(download_count), 0)::bigint AS total_downloads,
                  COUNT(*) FILTER (WHERE (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date = (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date)::int AS uploads_today
           FROM images WHERE deleted_at IS NULL ${ownerFilter}`,
          values,
        ),
        database.query(`SELECT COUNT(*)::int AS total_albums FROM albums WHERE deleted_at IS NULL ${ownerFilter}`, values),
        database.query(`SELECT COUNT(*)::int AS total_folders FROM folders WHERE deleted_at IS NULL ${ownerFilter}`, values),
        database.query(
          `SELECT to_char((created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date, 'YYYY-MM-DD') AS day,
                  COUNT(*)::int AS uploads,
                  COALESCE(SUM(size_bytes), 0)::bigint AS bytes
           FROM images
           WHERE deleted_at IS NULL
             AND created_at >= now() - interval '14 days'
             ${ownerFilter}
           GROUP BY 1
           ORDER BY 1 ASC`,
          values,
        ),
        database.query(
          `SELECT id, filename, extension, mime_type, size_bytes, width, height, visibility, created_at
           FROM images WHERE deleted_at IS NULL ${ownerFilter}
           ORDER BY created_at DESC LIMIT 8`,
          values,
        ),
      ]);
      const t = totalsRes.rows[0] || {};
      return ok(response, {
        totalImages: Number(t.total_images ?? 0),
        totalStorageBytes: Number(t.total_storage_bytes ?? 0),
        totalViews: Number(t.total_views ?? 0),
        totalDownloads: Number(t.total_downloads ?? 0),
        uploadsToday: Number(t.uploads_today ?? 0),
        totalAlbums: Number(albumsRes.rows[0]?.total_albums ?? 0),
        totalFolders: Number(foldersRes.rows[0]?.total_folders ?? 0),
        uploadsByDay: dailyRes.rows.map((r) => ({
          day: r.day,
          uploads: Number(r.uploads ?? 0),
          bytes: Number(r.bytes ?? 0),
        })),
        recentImages: recentRes.rows.map((r) => ({
          id: r.id,
          filename: r.filename,
          extension: r.extension,
          mimeType: r.mime_type,
          sizeBytes: Number(r.size_bytes ?? 0),
          width: r.width,
          height: r.height,
          visibility: r.visibility,
          thumbnailUrl: `/api/v1/images/${r.id}/thumbnail`,
          createdAt: r.created_at,
        })),
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tải thống kê tổng quan Image Server.');
    }
  });

  router.get('/analytics/overview', apiLogger, authenticate, async (request, response) => {
    try {
      const isAdmin = request.authUser.role === 'ADMIN';
      const imgOwnerJoin = isAdmin ? '' : 'JOIN images i ON i.id = iv.image_id AND i.owner_id = $1';
      const ownerWhere = isAdmin ? '' : 'AND owner_id = $1';
      const values = isAdmin ? [] : [request.authUser.id];

      const [viewsSummary, viewsByDay, topViewed, topDownloaded, apiStatus] = await Promise.all([
        database.query(
          `SELECT COUNT(*) FILTER (WHERE iv.event_type = 'view' AND iv.is_bot = false)::int AS real_views,
                  COUNT(*) FILTER (WHERE iv.event_type = 'view' AND iv.is_bot = true)::int AS bot_views,
                  COUNT(*) FILTER (WHERE iv.event_type = 'download')::int AS downloads,
                  COALESCE(SUM(iv.bytes_served), 0)::bigint AS bandwidth_bytes
           FROM image_views iv ${imgOwnerJoin}`,
          values,
        ),
        database.query(
          `SELECT to_char((iv.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date, 'YYYY-MM-DD') AS day,
                  COUNT(*) FILTER (WHERE iv.is_bot = false)::int AS real_views,
                  COUNT(*) FILTER (WHERE iv.is_bot = true)::int AS bot_views,
                  COALESCE(SUM(iv.bytes_served), 0)::bigint AS bytes_served
           FROM image_views iv ${imgOwnerJoin}
           WHERE iv.created_at >= now() - interval '14 days'
           GROUP BY 1 ORDER BY 1 ASC`,
          values,
        ),
        database.query(
          `SELECT id, filename, mime_type, size_bytes, view_count, download_count
           FROM images WHERE deleted_at IS NULL ${ownerWhere}
           ORDER BY view_count DESC, created_at DESC LIMIT 10`,
          values,
        ),
        database.query(
          `SELECT id, filename, mime_type, size_bytes, view_count, download_count
           FROM images WHERE deleted_at IS NULL ${ownerWhere}
           ORDER BY download_count DESC, created_at DESC LIMIT 10`,
          values,
        ),
        database.query(
          `SELECT COUNT(*)::int AS total_requests,
                  COUNT(*) FILTER (WHERE status_code >= 200 AND status_code < 300)::int AS status_2xx,
                  COUNT(*) FILTER (WHERE status_code >= 300 AND status_code < 400)::int AS status_3xx,
                  COUNT(*) FILTER (WHERE status_code >= 400 AND status_code < 500)::int AS status_4xx,
                  COUNT(*) FILTER (WHERE status_code >= 500)::int AS status_5xx,
                  COALESCE(ROUND(AVG(response_time_ms)), 0)::int AS avg_response_ms
           FROM api_logs
           ${isAdmin ? '' : 'WHERE user_id = $1'}`,
          values,
        ),
      ]);

      const vs = viewsSummary.rows[0] || {};
      const apiStats = apiStatus.rows[0] || {};
      return ok(response, {
        realViews: Number(vs.real_views ?? 0),
        botViews: Number(vs.bot_views ?? 0),
        downloads: Number(vs.downloads ?? 0),
        totalBandwidthBytes: Number(vs.bandwidth_bytes ?? 0),
        viewsByDay: viewsByDay.rows.map((r) => ({
          day: r.day,
          realViews: Number(r.real_views ?? 0),
          botViews: Number(r.bot_views ?? 0),
          bytesServed: Number(r.bytes_served ?? 0),
        })),
        topViewed: topViewed.rows.map((r) => ({
          id: r.id,
          filename: r.filename,
          mimeType: r.mime_type,
          sizeBytes: Number(r.size_bytes ?? 0),
          viewCount: Number(r.view_count ?? 0),
          downloadCount: Number(r.download_count ?? 0),
          thumbnailUrl: `/api/v1/images/${r.id}/thumbnail`,
        })),
        topDownloaded: topDownloaded.rows.map((r) => ({
          id: r.id,
          filename: r.filename,
          mimeType: r.mime_type,
          sizeBytes: Number(r.size_bytes ?? 0),
          viewCount: Number(r.view_count ?? 0),
          downloadCount: Number(r.download_count ?? 0),
          thumbnailUrl: `/api/v1/images/${r.id}/thumbnail`,
        })),
        apiRequests: {
          totalRequests: Number(apiStats.total_requests ?? 0),
          status2xx: Number(apiStats.status_2xx ?? 0),
          status3xx: Number(apiStats.status_3xx ?? 0),
          status4xx: Number(apiStats.status_4xx ?? 0),
          status5xx: Number(apiStats.status_5xx ?? 0),
          avgResponseMs: Number(apiStats.avg_response_ms ?? 0),
        },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tải dữ liệu phân tích.');
    }
  });

  // ---------------- ADMIN STORAGE MANAGEMENT & SETTINGS ----------------
  router.get('/admin/storage/summary', apiLogger, authenticate, requireAdminRole, async (_request, response) => {
    try {
      let providerHealth = { status: imageStorage ? 'healthy' : 'unconfigured', provider: imageStorage?.providerType || 'none' };
      if (imageStorage && typeof imageStorage.healthCheck === 'function') {
        try {
          providerHealth = await imageStorage.healthCheck();
        } catch {
          providerHealth = { status: 'error', provider: imageStorage.providerType || 'unknown' };
        }
      }

      const [totalsRes, byFormatRes, byUserRes, providersRes, variantsBytesRes] = await Promise.all([
        database.query(
          `SELECT COUNT(*)::int AS image_count,
                  COALESCE(SUM(size_bytes), 0)::bigint AS original_bytes
           FROM images WHERE deleted_at IS NULL`,
        ),
        database.query(
          `SELECT extension, mime_type, COUNT(*)::int AS count, COALESCE(SUM(size_bytes), 0)::bigint AS total_bytes
           FROM images WHERE deleted_at IS NULL
           GROUP BY extension, mime_type ORDER BY total_bytes DESC`,
        ),
        database.query(
          `SELECT u.id, u.full_name, u.email::text, u.role, u.status,
                  u.storage_quota_bytes, u.storage_used_bytes,
                  (SELECT COUNT(*)::int FROM images i WHERE i.owner_id = u.id AND i.deleted_at IS NULL) AS image_count
           FROM users u
           ORDER BY u.storage_used_bytes DESC, u.created_at ASC`,
        ),
        database.query('SELECT id, name, type, is_default, is_active, health_status, last_checked_at FROM storage_providers ORDER BY is_default DESC, name ASC'),
        database.query('SELECT COUNT(*)::int AS variant_count, COALESCE(SUM(size_bytes), 0)::bigint AS variant_bytes FROM image_variants'),
      ]);

      const origBytes = Number(totalsRes.rows[0]?.original_bytes ?? 0);
      const varBytes = Number(variantsBytesRes.rows[0]?.variant_bytes ?? 0);
      return ok(response, {
        providerHealth,
        imageCount: Number(totalsRes.rows[0]?.image_count ?? 0),
        variantCount: Number(variantsBytesRes.rows[0]?.variant_count ?? 0),
        originalBytes: origBytes,
        variantBytes: varBytes,
        totalBytes: origBytes + varBytes,
        byFormat: byFormatRes.rows.map((r) => ({
          extension: r.extension,
          mimeType: r.mime_type,
          count: Number(r.count ?? 0),
          totalBytes: Number(r.total_bytes ?? 0),
        })),
        byUser: byUserRes.rows.map((u) => ({
          id: u.id,
          fullName: u.full_name,
          email: u.email,
          role: u.role,
          status: u.status,
          imageCount: Number(u.image_count ?? 0),
          storageUsedBytes: Number(u.storage_used_bytes ?? 0),
          storageQuotaBytes: Number(u.storage_quota_bytes ?? 1073741824),
        })),
        providers: providersRes.rows,
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tải thông tin lưu trữ.');
    }
  });

  router.post('/admin/storage/scan-orphans', apiLogger, authenticate, requireAdminRole, async (_request, response) => {
    if (!imageStorage || typeof imageStorage.list !== 'function') {
      return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Storage provider hiện tại không hỗ trợ liệt kê file.');
    }
    try {
      const [storageKeys, imagesRes, variantsRes, mediaRes] = await Promise.all([
        imageStorage.list(),
        database.query('SELECT id, storage_key, filename FROM images'),
        database.query('SELECT id, storage_key FROM image_variants'),
        database.query('SELECT id, purpose, storage_key FROM media_assets'),
      ]);

      const dbKeySet = new Set([
        ...imagesRes.rows.map((r) => r.storage_key),
        ...variantsRes.rows.map((r) => r.storage_key),
        ...mediaRes.rows.flatMap((r) => (
          r.purpose === 'AVATAR'
            ? [r.storage_key, ...resolveAvatarThumbKeys(r.storage_key)]
            : [r.storage_key]
        )),
      ]);
      const storageKeySet = new Set(storageKeys);

      const orphanFiles = storageKeys.filter((key) => !dbKeySet.has(key));
      const missingInStorage = imagesRes.rows
        .filter((r) => !storageKeySet.has(r.storage_key))
        .map((r) => ({ id: r.id, filename: r.filename }));

      return ok(response, {
        scannedStorageCount: storageKeys.length,
        scannedDbCount: dbKeySet.size,
        orphanFiles,
        missingInStorage,
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể quét file mồ côi.');
    }
  });

  router.post('/admin/storage/cleanup-orphans', apiLogger, authenticate, requireAdminRole, async (request, response) => {
    const parsed = cleanupOrphansSchema.safeParse(request.body);
    if (!parsed.success) return zodValidationError(response, parsed.error);
    if (!imageStorage || typeof imageStorage.remove !== 'function') {
      return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Storage provider chưa hỗ trợ xóa.');
    }
    let removedCount = 0;
    for (const key of parsed.data.keys) {
      try {
        await imageStorage.remove(key);
        removedCount += 1;
      } catch {
        // continue removing remaining keys
      }
    }
    await recordImageAudit(
      database,
      request.authUser.id,
      'ORPHAN_FILES_CLEANED',
      'STORAGE',
      request.authUser.id,
      `Dọn dẹp ${removedCount} file mồ côi trên storage`,
      { removedCount },
    );
    return ok(response, { removedCount });
  });

  router.post('/admin/storage/sync-supabase', apiLogger, authenticate, requireAdminRole, async (request, response) => {
    if (!imageStorage || imageStorage.providerType !== 'supabase') {
      return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Supabase Storage chưa được kích hoạt làm kho lưu trữ chính.');
    }
    try {
      const summary = await syncSupabaseToImageLibrary({
        database,
        imageStorage,
        fallbackOwnerId: request.authUser.id,
        force: true,
      });
      await recordImageAudit(
        database,
        request.authUser.id,
        'SUPABASE_STORAGE_SYNCED',
        'STORAGE',
        request.authUser.id,
        `Đồng bộ Supabase Storage (${summary.bucket}): +${summary.syncedCount} ảnh mới`,
        summary,
      );
      return ok(response, summary);
    } catch (err) {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', err.message || 'Không thể đồng bộ dữ liệu từ Supabase Storage.');
    }
  });

  router.get('/admin/storage/supabase-objects', apiLogger, authenticate, requireAdminRole, async (request, response) => {
    if (!imageStorage || typeof imageStorage.list !== 'function') {
      return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Storage hiện tại không hỗ trợ liệt kê file.');
    }
    try {
      const prefix = typeof request.query?.prefix === 'string' ? request.query.prefix.trim() : '';
      const q = typeof request.query?.q === 'string' ? request.query.q.trim().toLowerCase() : '';
      const [entries, imagesRes, variantsRes, mediaRes] = await Promise.all([
        listStorageObjects(imageStorage),
        database.query('SELECT id, filename, storage_key, mime_type, size_bytes, width, height, visibility, created_at FROM images WHERE deleted_at IS NULL'),
        database.query('SELECT id, image_id, variant_type, storage_key, size_bytes FROM image_variants'),
        database.query(
          `SELECT m.id, m.owner_id, m.purpose, m.access_scope, m.storage_key, m.size_bytes, m.width, m.height, m.created_at,
                  u.full_name AS owner_name, u.email AS owner_email
           FROM media_assets m
           LEFT JOIN users u ON u.id = m.owner_id
           WHERE m.status = 'READY'`,
        ),
      ]);

      const imageMap = new Map(imagesRes.rows.map((r) => [r.storage_key, r]));
      const variantMap = new Map(variantsRes.rows.map((r) => [r.storage_key, r]));
      const mediaMap = new Map(mediaRes.rows.map((r) => [r.storage_key, r]));
      const avatarThumbSet = new Set(
        mediaRes.rows
          .filter((m) => m.purpose === 'AVATAR' || m.purpose === 'PACKAGE' || m.purpose === 'SYSTEM_ICON')
          .flatMap((m) => resolveThumbKeys(m.storage_key)),
      );

      const folderStats = new Map();
      const objects = [];
      let totalBytes = 0;
      let syncedCount = 0;
      let orphanCount = 0;

      for (const entry of entries) {
        const sizeBytes = Number(entry.sizeBytes || imageMap.get(entry.key)?.size_bytes || mediaMap.get(entry.key)?.size_bytes || 0);
        totalBytes += sizeBytes;

        const slashIdx = entry.key.lastIndexOf('/');
        const folderPath = slashIdx > 0 ? entry.key.slice(0, slashIdx) : '(Gốc bucket)';
        const fStat = folderStats.get(folderPath) || { folder: folderPath, fileCount: 0, totalBytes: 0 };
        fStat.fileCount += 1;
        fStat.totalBytes += sizeBytes;
        folderStats.set(folderPath, fStat);

        const imgRow = imageMap.get(entry.key) || null;
        const varRow = variantMap.get(entry.key) || null;
        const medRow = mediaMap.get(entry.key) || null;
        const isThumb = avatarThumbSet.has(entry.key) || isSecondaryVariantKey(entry.key);

        let syncStatus = 'ORPHAN';
        if (imgRow) {
          syncStatus = 'SYNCED';
          syncedCount += 1;
        } else if (varRow || isThumb) {
          syncStatus = 'VARIANT';
        } else if (medRow) {
          syncStatus = 'MEDIA_ONLY';
        } else {
          orphanCount += 1;
        }

        const folderMeta = inferDomainFolder(entry.key, medRow?.purpose);
        const row = {
          key: entry.key,
          name: entry.name || entry.key.split('/').pop(),
          folder: folderPath,
          domainLabel: folderMeta.name,
          sizeBytes,
          mimeType: entry.mimeType || imgRow?.mime_type || (medRow?.purpose ? 'image/webp' : null),
          syncStatus,
          purpose: medRow?.purpose || null,
          ownerName: medRow?.owner_name || null,
          imageId: imgRow?.id || varRow?.image_id || null,
          thumbnailUrl: imgRow?.id ? `/api/v1/images/${imgRow.id}/thumbnail` : null,
          originalUrl: imgRow?.id ? `/api/v1/images/${imgRow.id}/file` : null,
          createdAt: entry.createdAt || imgRow?.created_at || medRow?.created_at || null,
          updatedAt: entry.updatedAt || null,
        };

        if (prefix && !row.key.startsWith(prefix)) continue;
        if (q && !row.key.toLowerCase().includes(q) && !String(row.ownerName || '').toLowerCase().includes(q) && !row.domainLabel.toLowerCase().includes(q)) {
          continue;
        }
        objects.push(row);
      }

      return ok(response, {
        providerType: imageStorage.providerType || 'supabase',
        bucket: imageStorage.bucket || process.env.SUPABASE_STORAGE_BUCKET || 'meta-gym-media',
        totalObjects: entries.length,
        totalBytes,
        syncedCount,
        orphanCount,
        folders: [...folderStats.values()].sort((a, b) => a.folder.localeCompare(b.folder)),
        objects: objects.sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || ''))),
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tải danh sách tệp từ Supabase Storage.');
    }
  });

  router.post('/admin/storage/backup-metadata', apiLogger, authenticate, requireAdminRole, async (_request, response) => {
    try {
      const [settingsRes, tagsRes, foldersRes, albumsRes, imagesRes, variantsRes] = await Promise.all([
        database.query('SELECT key, value FROM system_settings ORDER BY key ASC'),
        database.query('SELECT id, name, slug, color, created_at FROM tags ORDER BY name ASC'),
        database.query('SELECT id, owner_id, parent_id, name, slug, created_at FROM folders WHERE deleted_at IS NULL'),
        database.query('SELECT id, owner_id, title, description, cover_image_id, visibility, share_slug, created_at FROM albums WHERE deleted_at IS NULL'),
        database.query('SELECT id, owner_id, folder_id, storage_provider_id, filename, original_filename, extension, mime_type, size_bytes, width, height, sha256_hash, visibility, view_count, download_count, created_at FROM images WHERE deleted_at IS NULL'),
        database.query('SELECT id, image_id, variant_type, label, extension, mime_type, size_bytes, width, height, transform_params, created_at FROM image_variants'),
      ]);
      const systemSettings = {};
      for (const row of settingsRes.rows) systemSettings[row.key] = row.value;

      return ok(response, {
        exportedAt: new Date().toISOString(),
        version: '1.0',
        systemSettings,
        tags: tagsRes.rows,
        folders: foldersRes.rows,
        albums: albumsRes.rows,
        images: imagesRes.rows,
        imageVariants: variantsRes.rows,
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể sao lưu metadata.');
    }
  });

  router.post('/admin/storage/restore-metadata', apiLogger, authenticate, requireAdminRole, async (request, response) => {
    const parsed = restoreMetadataSchema.safeParse(request.body);
    if (!parsed.success) return zodValidationError(response, parsed.error);

    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Lỗi kết nối cơ sở dữ liệu.');
    try {
      await client.query('BEGIN');
      let restoredCounts = { settings: 0, tags: 0, folders: 0, albums: 0 };

      for (const [key, value] of Object.entries(parsed.data.systemSettings || {})) {
        await client.query(
          `INSERT INTO system_settings (key, value, updated_by)
           VALUES ($1, $2::jsonb, $3)
           ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_by = EXCLUDED.updated_by, updated_at = now()`,
          [key, JSON.stringify(value), request.authUser.id],
        );
        restoredCounts.settings += 1;
      }

      for (const tag of parsed.data.tags || []) {
        await client.query(
          `INSERT INTO tags (id, name, slug, color)
           VALUES ($1, $2, $3, $4)
           ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, color = COALESCE(EXCLUDED.color, tags.color)`,
          [tag.id, tag.name, tag.slug, tag.color ?? '#FF5E36'],
        );
        restoredCounts.tags += 1;
      }

      for (const folder of parsed.data.folders || []) {
        const ownerId = folder.owner_id || folder.ownerId || request.authUser.id;
        const parentId = folder.parent_id ?? folder.parentId ?? null;
        await client.query(
          `INSERT INTO folders (id, owner_id, parent_id, name, slug)
           VALUES ($1, $2, $3, $4, $5)
           ON CONFLICT (id) DO NOTHING`,
          [folder.id, ownerId, parentId, folder.name, folder.slug],
        );
        restoredCounts.folders += 1;
      }

      for (const album of parsed.data.albums || []) {
        const ownerId = album.owner_id || album.ownerId || request.authUser.id;
        await client.query(
          `INSERT INTO albums (id, owner_id, title, description, visibility, share_slug)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (id) DO NOTHING`,
          [album.id, ownerId, album.title, album.description ?? null, album.visibility, album.share_slug ?? album.shareSlug ?? null],
        );
        restoredCounts.albums += 1;
      }

      await client.query('COMMIT');
      await recordImageAudit(
        database,
        request.authUser.id,
        'METADATA_RESTORED',
        'STORAGE',
        request.authUser.id,
        'Khôi phục metadata Image Server từ bản sao lưu JSON',
        restoredCounts,
      );
      return ok(response, { restoredCounts });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể khôi phục metadata.');
    } finally {
      client.release();
    }
  });

  router.get('/admin/settings', apiLogger, authenticate, requireAdminRole, async (_request, response) => {
    const settings = await loadSystemSettings(database);
    return ok(response, settings);
  });

  router.patch('/admin/settings', apiLogger, authenticate, requireAdminRole, async (request, response) => {
    const parsed = updateSettingsSchema.safeParse(request.body);
    if (!parsed.success) return zodValidationError(response, parsed.error);
    const entries = Object.entries(parsed.data).filter(([, val]) => val !== undefined);
    if (!entries.length) return fail(response, 422, 'VALIDATION_ERROR', 'Cần ít nhất một mục cấu hình.');

    try {
      for (const [key, value] of entries) {
        await database.query(
          `INSERT INTO system_settings (key, value, updated_by)
           VALUES ($1, $2::jsonb, $3)
           ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_by = EXCLUDED.updated_by, updated_at = now()`,
          [key, JSON.stringify(value), request.authUser.id],
        );
      }
      await recordImageAudit(
        database,
        request.authUser.id,
        'SYSTEM_SETTINGS_UPDATED',
        'SETTINGS',
        request.authUser.id,
        `Cập nhật cấu hình Image Server (${entries.map(([k]) => k).join(', ')})`,
        { updatedKeys: entries.map(([k]) => k) },
      );
      const settings = await loadSystemSettings(database);
      return ok(response, settings);
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể lưu cấu hình hệ thống.');
    }
  });

  router.get('/admin/image-users', apiLogger, authenticate, requireAdminRole, async (_request, response) => {
    try {
      const res = await database.query(
        `SELECT u.id, u.full_name, u.email::text, u.role, u.status, u.is_locked,
                u.storage_quota_bytes, u.storage_used_bytes, r.code AS role_code,
                (SELECT COUNT(*)::int FROM images i WHERE i.owner_id = u.id AND i.deleted_at IS NULL) AS image_count
         FROM users u
         LEFT JOIN roles r ON r.id = u.role_id
         ORDER BY u.storage_used_bytes DESC, u.created_at ASC`,
      );
      return ok(response, res.rows.map((u) => ({
        id: u.id,
        fullName: u.full_name,
        email: u.email,
        role: u.role,
        roleCode: u.role_code || (u.role === 'ADMIN' ? 'super_admin' : 'user'),
        status: u.status,
        isLocked: Boolean(u.is_locked || u.status === 'DISABLED'),
        imageCount: Number(u.image_count ?? 0),
        storageUsedBytes: Number(u.storage_used_bytes ?? 0),
        storageQuotaBytes: Number(u.storage_quota_bytes ?? 1073741824),
      })));
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tải danh sách quota người dùng.');
    }
  });

  router.patch('/admin/image-users/:id/quota', apiLogger, authenticate, requireAdminRole, async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã người dùng không hợp lệ.');
    const parsed = quotaPatchSchema.safeParse(request.body);
    if (!parsed.success) return zodValidationError(response, parsed.error);

    try {
      let roleId = null;
      if (parsed.data.roleCode) {
        const rRes = await database.query('SELECT id FROM roles WHERE code = $1 LIMIT 1', [parsed.data.roleCode]);
        roleId = rRes.rows[0]?.id ?? null;
      }
      const res = await database.query(
        `UPDATE users
         SET storage_quota_bytes = $1,
             role_id = COALESCE($2, role_id),
             updated_at = now()
         WHERE id = $3
         RETURNING id, full_name, email::text, storage_quota_bytes, storage_used_bytes`,
        [parsed.data.storageQuotaBytes, roleId, id],
      );
      if (!res.rows.length) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy người dùng.');
      const user = res.rows[0];
      await recordImageAudit(
        database,
        request.authUser.id,
        'USER_QUOTA_UPDATED',
        'USER',
        id,
        `Cập nhật quota lưu trữ cho ${user.full_name}`,
        { storageQuotaBytes: Number(user.storage_quota_bytes), roleCode: parsed.data.roleCode ?? null },
      );
      return ok(response, {
        id: user.id,
        fullName: user.full_name,
        email: user.email,
        storageQuotaBytes: Number(user.storage_quota_bytes),
        storageUsedBytes: Number(user.storage_used_bytes),
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể cập nhật quota lưu trữ.');
    }
  });

  return router;
}
