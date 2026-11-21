import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();

const FORBIDDEN_METADATA_KEYS = new Set([
  'password',
  'passwordhash',
  'temporarypassword',
  'codehash',
  'accesstoken',
  'jwt',
  'healthnotes',
  'injurynotes',
  'heightcm',
  'weightkg',
  'bodyfatpercent',
  'fitnessgoal',
  'dietarypreferences',
  'dateofbirth',
  'healthdeclarationcompletedat',
  'journal',
  'chestcm',
  'waistcm',
  'hipscm',
  'achievements',
  'messages',
  'messagecontent',
  'aimessages',
  'meallogs',
  'membernutritiondays',
  'progressphotos',
  'storagekey',
]);

const listQuerySchema = z.strictObject({
  action: z.string().trim().min(1).max(80).optional(),
  entityType: z.string().trim().min(1).max(50).optional(),
  entityId: z.string().trim().min(1).max(120).optional(),
  from: z.iso.date().optional(),
  to: z.iso.date().optional(),
  search: z.string().trim().max(120).optional(),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});

function fail(response, status, code, message, details = {}) {
  return response.status(status).json({ error: { code, message, details } });
}

function escapeLike(value) {
  return value.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
}

function isForbiddenKey(key) {
  const normalized = String(key).toLowerCase().replaceAll('_', '');
  return FORBIDDEN_METADATA_KEYS.has(normalized);
}

export function sanitizeAuditMetadata(value) {
  if (Array.isArray(value)) {
    return value.map((item) => sanitizeAuditMetadata(item));
  }
  if (value && typeof value === 'object') {
    const clean = {};
    for (const [key, entry] of Object.entries(value)) {
      if (isForbiddenKey(key)) continue;
      clean[key] = sanitizeAuditMetadata(entry);
    }
    return clean;
  }
  return value;
}

function auditLogView(row) {
  return {
    id: row.id,
    adminId: row.admin_id,
    adminName: row.admin_name ?? null,
    action: row.action,
    entityType: row.entity_type,
    entityId: row.entity_id,
    summary: row.summary,
    metadata: sanitizeAuditMetadata(row.metadata ?? {}),
    createdAt: row.created_at,
  };
}

export function createAdminAuditRouter({ database, jwtSecret }) {
  const router = Router();
  router.use('/admin/audit-logs', createAuthentication({ database, jwtSecret }));
  router.use('/admin/audit-logs', (request, response, next) =>
    request.authUser.role === 'ADMIN'
      ? next()
      : fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị'));

  router.get('/admin/audit-logs', async (request, response) => {
    const parsed = listQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Bộ lọc nhật ký không hợp lệ');
    }
    const { action, entityType, entityId, from, to, search, page, pageSize } = parsed.data;
    if (from && to && from > to) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Khoảng ngày lọc không hợp lệ');
    }
    const filters = [];
    const values = [];
    if (action) {
      values.push(action);
      filters.push(`l.action = $${values.length}`);
    }
    if (entityType) {
      values.push(entityType);
      filters.push(`l.entity_type = $${values.length}`);
    }
    if (entityId) {
      values.push(entityId);
      filters.push(`l.entity_id = $${values.length}`);
    }
    if (from) {
      values.push(from);
      filters.push(`l.created_at >= ($${values.length}::date::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh')`);
    }
    if (to) {
      values.push(to);
      filters.push(`l.created_at < (($${values.length}::date + 1)::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh')`);
    }
    if (search) {
      values.push(`%${escapeLike(search)}%`);
      const param = `$${values.length}`;
      filters.push(
        `(l.action ILIKE ${param} ESCAPE '\\' OR l.entity_type ILIKE ${param} ESCAPE '\\' OR l.entity_id ILIKE ${param} ESCAPE '\\' OR l.summary ILIKE ${param} ESCAPE '\\' OR COALESCE(u.full_name, '') ILIKE ${param} ESCAPE '\\')`,
      );
    }
    const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    try {
      const [totalResult, rowsResult] = await Promise.all([
        database.query(
          `SELECT count(*)::int AS count
           FROM admin_audit_logs l
           LEFT JOIN users u ON u.id = l.admin_id
           ${whereClause}`,
          values,
        ),
        database.query(
          `SELECT l.id, l.admin_id, u.full_name AS admin_name, l.action,
                  l.entity_type, l.entity_id, l.summary, l.metadata, l.created_at
           FROM admin_audit_logs l
           LEFT JOIN users u ON u.id = l.admin_id
           ${whereClause}
           ORDER BY l.created_at DESC, l.id DESC
           LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
          [...values, pageSize, (page - 1) * pageSize],
        ),
      ]);
      const totalItems = totalResult.rows[0].count;
      return response.json({
        data: rowsResult.rows.map(auditLogView),
        pagination: {
          page,
          pageSize,
          totalItems,
          totalPages: Math.ceil(totalItems / pageSize),
        },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được nhật ký hệ thống');
    }
  });

  router.get('/admin/audit-logs/:logId', async (request, response) => {
    if (!uuid.safeParse(request.params.logId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã nhật ký không hợp lệ');
    }
    try {
      const result = await database.query(
        `SELECT l.id, l.admin_id, u.full_name AS admin_name, l.action,
                l.entity_type, l.entity_id, l.summary, l.metadata, l.created_at
         FROM admin_audit_logs l
         LEFT JOIN users u ON u.id = l.admin_id
         WHERE l.id = $1`,
        [request.params.logId],
      );
      if (!result.rows.length) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy bản ghi nhật ký');
      }
      return response.json({ data: auditLogView(result.rows[0]) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được nhật ký hệ thống');
    }
  });

  return router;
}
