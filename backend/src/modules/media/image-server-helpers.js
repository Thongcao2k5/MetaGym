import { createHash, createHmac, randomUUID, timingSafeEqual } from 'node:crypto';

import { isBotUserAgent } from './image-validation.js';

export const DEFAULT_SYSTEM_SETTINGS = {
  site_branding: { siteName: 'Meta Gym Image Server', logoUrl: '', faviconUrl: '' },
  upload_limits: {
    maxFileSizeMb: 10,
    maxFilesPerUpload: 20,
    allowedFormats: ['jpeg', 'png', 'webp', 'avif', 'gif', 'svg'],
    defaultVisibility: 'private',
    allowUrlImport: true,
  },
  image_processing: {
    thumbnailSize: 320,
    autoWebp: true,
    autoAvif: false,
    defaultQuality: 75,
    stripGpsExif: true,
  },
  smtp: { enabled: false, host: '', port: 587, secure: false, fromEmail: '' },
  rate_limits: { publicApiPerMinute: 60, uploadPerMinute: 30 },
  maintenance_mode: {
    enabled: false,
    message: 'Hệ thống đang bảo trì định kỳ, vui lòng quay lại sau.',
  },
  backup_policy: { autoBackupEnabled: false, retentionDays: 30 },
};

export function ok(response, data, { status = 200, meta } = {}) {
  const body = { success: true, data, error: null };
  if (meta !== undefined) body.meta = meta;
  return response.status(status).json(body);
}

export function fail(response, status, code, message, details = {}) {
  return response.status(status).json({
    success: false,
    data: null,
    error: { code, message, details },
  });
}

export function zodValidationError(response, issue, message = 'Dữ liệu không hợp lệ.') {
  const fields = {};
  for (const item of issue.issues) {
    if (item.code === 'unrecognized_keys') {
      for (const key of item.keys) {
        fields[key] = [...(fields[key] ?? []), 'Trường này không được phép'];
      }
    } else {
      const key = item.path.join('.') || '_';
      fields[key] = [...(fields[key] ?? []), item.message];
    }
  }
  return fail(response, 422, 'VALIDATION_ERROR', message, { fields });
}

export function escapeLike(value) {
  return String(value).replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
}

export async function loadSystemSettings(database) {
  const merged = structuredClone(DEFAULT_SYSTEM_SETTINGS);
  try {
    const res = await database.query('SELECT key, value FROM system_settings');
    for (const row of res.rows) {
      if (row.key && row.value && typeof row.value === 'object') {
        merged[row.key] = { ...(merged[row.key] || {}), ...row.value };
      }
    }
  } catch {
    // Fall back to defaults when running against minimal mock DBs
  }
  return merged;
}

export async function resolveStorageProviderId(database, imageStorage) {
  const preferredType = imageStorage?.providerType || 'local';
  try {
    const res = await database.query(
      `SELECT id, type FROM storage_providers
       WHERE is_active = true
       ORDER BY (type = $1) DESC, is_default DESC, created_at ASC
       LIMIT 1`,
      [preferredType],
    );
    if (res.rows[0]?.id) return res.rows[0].id;
    const fallback = await database.query(
      `INSERT INTO storage_providers (id, name, type, config, is_default, is_active, health_status)
       VALUES ($1, 'Active Storage', $2, '{}'::jsonb, true, true, 'healthy')
       RETURNING id`,
      [randomUUID(), preferredType],
    );
    return fallback.rows[0].id;
  } catch {
    return '00000000-0000-4000-8000-000000000201';
  }
}

export function signShareAccessToken(secret, shareToken, expiresUnix) {
  return createHmac('sha256', `${secret}:image-share`)
    .update(`${shareToken}:${expiresUnix}`)
    .digest('hex');
}

export function createShareAccessToken(secret, shareToken, ttlSeconds = 3600) {
  const expires = Math.floor(Date.now() / 1000) + ttlSeconds;
  const sig = signShareAccessToken(secret, shareToken, expires);
  return `${expires}.${sig}`;
}

export function verifyShareAccessToken(secret, shareToken, rawToken) {
  if (typeof rawToken !== 'string' || !rawToken.includes('.')) return false;
  const [expStr, sigHex] = rawToken.split('.');
  const expires = Number(expStr);
  if (!Number.isInteger(expires) || expires < Math.floor(Date.now() / 1000)) return false;
  if (!/^[0-9a-f]{64}$/.test(sigHex || '')) return false;
  const expected = Buffer.from(signShareAccessToken(secret, shareToken, expires), 'hex');
  const provided = Buffer.from(sigHex, 'hex');
  return expected.length === provided.length && timingSafeEqual(expected, provided);
}

export async function recordImageAudit(database, adminId, action, entityType, entityId, summary, metadata = {}) {
  try {
    await database.query(
      `INSERT INTO admin_audit_logs
       (id, admin_id, action, entity_type, entity_id, summary, metadata)
       VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)`,
      [randomUUID(), adminId, action, entityType, entityId, summary, JSON.stringify(metadata)],
    );
  } catch {
    // Non-blocking audit logging
  }
}

export function hashIp(ip) {
  if (!ip) return null;
  return createHash('sha256').update(String(ip)).digest('hex');
}

export function recordImageView(database, { imageId, eventType = 'view', request, bytesServed = 0 }) {
  const ua = request.get('user-agent') || '';
  const referer = request.get('referer') || null;
  const ip = request.ip || request.socket?.remoteAddress || null;
  const isBot = isBotUserAgent(ua);
  const column = eventType === 'download' ? 'download_count' : 'view_count';

  database.query(
    `INSERT INTO image_views (image_id, event_type, is_bot, referer, ip_hash, user_agent, bytes_served)
     VALUES ($1, $2, $3, $4, $5, $6, $7)`,
    [imageId, eventType, isBot, referer ? referer.slice(0, 500) : null, hashIp(ip), ua.slice(0, 500), bytesServed],
  ).catch(() => {});

  database.query(
    `UPDATE images SET ${column} = ${column} + 1 WHERE id = $1`,
    [imageId],
  ).catch(() => {});
}

export function serializeImageRow(row, { variants = [], tags = [], shareToken = null } = {}) {
  const suffix = shareToken ? `?shareToken=${encodeURIComponent(shareToken)}` : '';
  return {
    id: row.id,
    ownerId: row.owner_id,
    ownerName: row.owner_name ?? null,
    ownerEmail: row.owner_email ?? null,
    folderId: row.folder_id ?? null,
    folderName: row.folder_name ?? null,
    storageProviderId: row.storage_provider_id,
    filename: row.filename,
    originalFilename: row.original_filename,
    extension: row.extension,
    mimeType: row.mime_type,
    sizeBytes: Number(row.size_bytes ?? 0),
    size: Number(row.size_bytes ?? 0),
    width: row.width !== null && row.width !== undefined ? Number(row.width) : null,
    height: row.height !== null && row.height !== undefined ? Number(row.height) : null,
    sha256Hash: row.sha256_hash,
    exifData: row.exif_data ?? null,
    description: row.description ?? '',
    visibility: row.visibility,
    viewCount: Number(row.view_count ?? 0),
    downloadCount: Number(row.download_count ?? 0),
    originalUrl: `/api/v1/images/${row.id}/file${suffix}`,
    thumbnailUrl: `/api/v1/images/${row.id}/thumbnail${suffix}`,
    downloadUrl: `/api/v1/images/${row.id}/download${suffix}`,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    deletedAt: row.deleted_at ?? null,
    variants: variants.map((v) => ({
      id: v.id,
      imageId: v.image_id,
      variantType: v.variant_type,
      label: v.label ?? null,
      extension: v.extension,
      mimeType: v.mime_type,
      sizeBytes: Number(v.size_bytes ?? 0),
      width: v.width !== null && v.width !== undefined ? Number(v.width) : null,
      height: v.height !== null && v.height !== undefined ? Number(v.height) : null,
      transformParams: v.transform_params ?? null,
      url: `/api/v1/images/${row.id}/variants/${v.id}/file${suffix}`,
      createdAt: v.created_at,
    })),
    tags: tags.map((t) => ({
      id: t.id,
      name: t.name,
      slug: t.slug,
      color: t.color ?? null,
    })),
  };
}
