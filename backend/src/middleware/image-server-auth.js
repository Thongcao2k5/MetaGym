import { createHash } from 'node:crypto';

import { createAuthentication } from '../routes/users.routes.js';

function fail(response, status, code, message, details = {}) {
  return response.status(status).json({
    success: false,
    data: null,
    error: { code, message, details },
  });
}

export function hashApiKey(rawKey) {
  return createHash('sha256').update(String(rawKey || '')).digest('hex');
}

/**
 * Dual authentication middleware supporting JWT Bearer tokens and `X-API-Key` headers
 * with per-key sliding-window rate limiting and scope metadata.
 */
export function createImageServerAuth({ database, jwtSecret }) {
  const authenticateJwt = createAuthentication({ database, jwtSecret });
  const rateWindows = new Map();

  return async function authenticateImageServer(request, response, next) {
    const rawApiKey = request.get('x-api-key')?.trim();
    if (!rawApiKey) {
      return authenticateJwt(request, response, next);
    }

    try {
      const keyHash = hashApiKey(rawApiKey);
      const result = await database.query(
        `SELECT k.id AS key_id, k.user_id, k.name AS key_name, k.scopes,
                k.rate_limit_per_minute, k.expires_at, k.revoked_at,
                u.id, u.email::text, u.full_name, u.role, u.status,
                u.storage_quota_bytes, u.storage_used_bytes, u.is_locked
         FROM api_keys k
         JOIN users u ON u.id = k.user_id
         WHERE k.key_hash = $1
         LIMIT 1`,
        [keyHash],
      );
      const row = result.rows[0];
      if (!row || row.revoked_at) {
        return fail(response, 401, 'INVALID_API_KEY', 'API Key không hợp lệ hoặc đã bị thu hồi.');
      }
      if (row.expires_at && new Date(row.expires_at).getTime() <= Date.now()) {
        return fail(response, 401, 'API_KEY_EXPIRED', 'API Key đã hết hạn.');
      }
      if (row.status !== 'ACTIVE' || row.is_locked) {
        return fail(response, 403, 'ACCOUNT_LOCKED', 'Tài khoản sở hữu API Key đã bị khóa.');
      }

      const now = Date.now();
      const windowMs = 60_000;
      const entries = (rateWindows.get(row.key_id) || []).filter((ts) => now - ts < windowMs);
      if (entries.length >= Number(row.rate_limit_per_minute || 60)) {
        return fail(response, 429, 'RATE_LIMITED', 'Vượt quá giới hạn tốc độ gọi API của API Key.');
      }
      entries.push(now);
      rateWindows.set(row.key_id, entries);

      request.authUser = {
        id: row.id,
        email: row.email,
        full_name: row.full_name,
        role: row.role,
        status: row.status,
        storage_quota_bytes: Number(row.storage_quota_bytes ?? 1073741824),
        storage_used_bytes: Number(row.storage_used_bytes ?? 0),
      };
      request.apiKey = {
        id: row.key_id,
        name: row.key_name,
        scopes: Array.isArray(row.scopes) ? row.scopes : [],
        rateLimitPerMinute: Number(row.rate_limit_per_minute || 60),
      };

      database.query(
        `UPDATE api_keys SET request_count = request_count + 1, last_used_at = now() WHERE id = $1`,
        [row.key_id],
      ).catch(() => {});

      return next();
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể xác thực API Key.');
    }
  };
}

export function requireScope(scope) {
  return (request, response, next) => {
    if (!request.apiKey) return next();
    const scopes = request.apiKey.scopes || [];
    if (scopes.includes('*') || scopes.includes(scope)) return next();
    return fail(response, 403, 'INSUFFICIENT_SCOPE', `API Key thiếu quyền '${scope}'.`);
  };
}

export function requireAdminRole(request, response, next) {
  if (request.authUser?.role === 'ADMIN') return next();
  return fail(response, 403, 'FORBIDDEN', 'Chỉ quản trị viên mới có quyền thực hiện thao tác này.');
}

/**
 * Logs requests under Image Server endpoints to `api_logs`.
 */
export function createApiLogMiddleware({ database }) {
  return (request, response, next) => {
    const startNs = process.hrtime.bigint();
    response.on('finish', () => {
      const elapsedMs = Math.max(0, Math.round(Number(process.hrtime.bigint() - startNs) / 1e6));
      const lengthHeader = Number(response.getHeader('content-length') || 0);
      const endpoint = (request.originalUrl || request.url || '').split('?')[0].slice(0, 255);
      const ip = request.ip || request.socket?.remoteAddress || null;
      const ua = request.get('user-agent') || null;
      database.query(
        `INSERT INTO api_logs
         (api_key_id, user_id, method, endpoint, status_code, response_time_ms, bytes_transferred, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8::inet, $9)`,
        [
          request.apiKey?.id ?? null,
          request.authUser?.id ?? null,
          request.method.slice(0, 10),
          endpoint,
          response.statusCode,
          elapsedMs,
          Number.isFinite(lengthHeader) ? lengthHeader : 0,
          ip && /^[\da-fA-F:.]+$/.test(ip) ? ip : null,
          ua ? ua.slice(0, 500) : null,
        ],
      ).catch(() => {});
    });
    next();
  };
}
