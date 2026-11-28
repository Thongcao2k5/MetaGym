import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from '../users/users.routes.js';

const uuid = z.uuid();
const codeSchema = z.string().trim().regex(/^[A-Z0-9][A-Z0-9_-]{1,39}$/);

const createSchema = z.strictObject({
  code: codeSchema,
  name: z.string().trim().min(1).max(100),
  description: z.string().trim().max(1000).nullable().optional(),
  sessionCount: z.number().int().min(1).max(365),
  durationDays: z.number().int().min(1).max(730),
  price: z.number().int().min(0).max(Number.MAX_SAFE_INTEGER),
  status: z.enum(['ACTIVE', 'INACTIVE']).default('ACTIVE'),
});

const patchSchema = z.strictObject({
  name: z.string().trim().min(1).max(100).optional(),
  description: z.string().trim().max(1000).nullable().optional(),
  sessionCount: z.number().int().min(1).max(365).optional(),
  durationDays: z.number().int().min(1).max(730).optional(),
  price: z.number().int().min(0).max(Number.MAX_SAFE_INTEGER).optional(),
  status: z.enum(['ACTIVE', 'INACTIVE']).optional(),
});

const entitlementQuerySchema = z.strictObject({
  memberId: uuid.optional(),
  coachId: uuid.optional(),
  status: z.enum(['ACTIVE', 'QUEUED', 'ENDED']).optional(),
  frozenOnly: z.enum(['true', 'false']).optional(),
  search: z.string().trim().max(120).optional(),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});

function fail(response, status, code, message, details = {}) {
  return response.status(status).json({ error: { code, details, message } });
}

function escapeLike(value) {
  return value.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
}

function view(row, includeAdminFields = false) {
  const base = {
    code: row.code,
    name: row.name,
    description: row.description ?? null,
    sessionCount: row.session_count,
    durationDays: row.duration_days,
    price: Number(row.price),
    status: row.status,
  };
  if (includeAdminFields) {
    base.createdAt = row.created_at ?? null;
    if (row.updated_at !== undefined) base.updatedAt = row.updated_at;
    if (row.active_entitlement_count !== undefined) {
      base.activeEntitlementCount = Number(row.active_entitlement_count);
    }
    if (row.queued_entitlement_count !== undefined) {
      base.queuedEntitlementCount = Number(row.queued_entitlement_count);
    }
  }
  return base;
}

function entitlementView(row) {
  return {
    id: row.id,
    relationshipId: row.relationship_id,
    relationshipStatus: row.relationship_status,
    memberId: row.member_id,
    memberName: row.member_name,
    coachId: row.coach_id,
    coachName: row.coach_name,
    planCode: row.plan_code ?? null,
    planName: row.plan_name ?? null,
    snapshotPrice: row.snapshot_price === null || row.snapshot_price === undefined
      ? null
      : Number(row.snapshot_price),
    status: row.status,
    totalSessions: row.total_sessions,
    remainingSessions: row.remaining_sessions,
    durationDays: row.duration_days,
    startsOn: row.starts_on ?? null,
    originalEndsOn: row.original_ends_on ?? null,
    endsOn: row.ends_on ?? null,
    frozenAt: row.frozen_at ?? null,
    frozenDaysTotal: row.frozen_days_total ?? 0,
    graceDaysAdded: row.grace_days_added ?? 0,
    closeReason: row.close_reason ?? null,
    endedAt: row.ended_at ?? null,
  };
}

export function createCoachPackagesRouter({ database, jwtSecret }) {
  const router = Router();

  router.get('/coach-packages', async (_request, response) => {
    try {
      const result = await database.query(
        `SELECT code, name, description, session_count, duration_days, price, status
         FROM coach_package_plans
         WHERE status = 'ACTIVE'
         ORDER BY session_count ASC, price ASC, code ASC`,
      );
      return response.json({ data: result.rows.map((row) => view(row, false)) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được gói Coach');
    }
  });

  router.use(['/admin/coach-packages', '/admin/coach-entitlements'],
    createAuthentication({ database, jwtSecret }));
  router.use(['/admin/coach-packages', '/admin/coach-entitlements'], (request, response, next) =>
    request.authUser.role === 'ADMIN' ? next()
      : fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị'));

  router.get('/admin/coach-packages', async (request, response) => {
    const parsed = z.strictObject({
      status: z.enum(['ACTIVE', 'INACTIVE']).optional(),
      search: z.string().trim().max(120).optional(),
    }).safeParse(request.query);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Bộ lọc không hợp lệ');
    const { status, search } = parsed.data;
    const filters = [];
    const values = [];
    if (status) {
      values.push(status);
      filters.push(`p.status = $${values.length}`);
    }
    if (search) {
      values.push(`%${escapeLike(search)}%`);
      const param = `$${values.length}`;
      filters.push(
        `(p.code ILIKE ${param} ESCAPE '\\' OR p.name ILIKE ${param} ESCAPE '\\' OR COALESCE(p.description, '') ILIKE ${param} ESCAPE '\\')`,
      );
    }
    const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    try {
      const result = await database.query(
        `SELECT p.*,
                (SELECT count(*)::int FROM coach_entitlements e
                 LEFT JOIN coach_payment_holds h ON h.id = COALESCE(e.original_hold_id, e.hold_id)
                 WHERE COALESCE(e.plan_code, h.plan_code) = p.code
                   AND e.status = 'ACTIVE') AS active_entitlement_count,
                (SELECT count(*)::int FROM coach_entitlements e
                 LEFT JOIN coach_payment_holds h ON h.id = COALESCE(e.original_hold_id, e.hold_id)
                 WHERE COALESCE(e.plan_code, h.plan_code) = p.code
                   AND e.status = 'QUEUED') AS queued_entitlement_count
         FROM coach_package_plans p
         ${whereClause}
         ORDER BY p.session_count ASC, p.price ASC, p.code ASC`,
        values,
      );
      return response.json({ data: result.rows.map((row) => view(row, true)) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được gói Coach');
    }
  });

  router.post('/admin/coach-packages', async (request, response) => {
    const parsed = createSchema.safeParse(request.body);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu gói Coach không hợp lệ');
    }
    const data = parsed.data;
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const admin = await client.query(
        `SELECT 1 FROM users WHERE id = $1 AND role = 'ADMIN'
         AND status = 'ACTIVE' AND session_version = $2 FOR SHARE`,
        [request.authUser.id, request.authUser.session_version],
      );
      if (!admin.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const inserted = await client.query(
        `INSERT INTO coach_package_plans
         (code, name, description, session_count, duration_days, price, status, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING *`,
        [
          data.code,
          data.name,
          data.description ?? null,
          data.sessionCount,
          data.durationDays,
          data.price,
          data.status,
          request.authUser.id,
        ],
      );
      const created = inserted.rows[0];
      await client.query(
        `INSERT INTO admin_audit_logs
         (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'COACH_PACKAGE_CREATED', 'COACH_PACKAGE', $3, $4, $5)`,
        [
          randomUUID(),
          request.authUser.id,
          created.code,
          `Tạo gói Coach: ${created.name} (${created.code})`,
          JSON.stringify({ before: null, after: view(created, true) }),
        ],
      );
      await client.query('COMMIT');
      return response.status(201).json({ data: view(created, true) });
    } catch (cause) {
      await client.query('ROLLBACK').catch(() => {});
      if (cause.code === '23505') {
        return fail(response, 409, 'COACH_PACKAGE_CODE_EXISTS', 'Mã gói Coach đã tồn tại');
      }
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tạo được gói Coach');
    } finally { client.release(); }
  });

  router.patch('/admin/coach-packages/:code', async (request, response) => {
    const code = codeSchema.safeParse(request.params.code);
    const body = patchSchema.safeParse(request.body);
    if (!code.success || !body.success || !Object.keys(body.data).length) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu gói Coach không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const admin = await client.query(
        `SELECT 1 FROM users WHERE id = $1 AND role = 'ADMIN'
         AND status = 'ACTIVE' AND session_version = $2 FOR SHARE`,
        [request.authUser.id, request.authUser.session_version],
      );
      if (!admin.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const before = await client.query(
        'SELECT * FROM coach_package_plans WHERE code = $1 FOR UPDATE',
        [code.data],
      );
      if (!before.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy gói Coach');
      }
      const old = before.rows[0];
      const fields = Object.entries({
        name: 'name',
        description: 'description',
        sessionCount: 'session_count',
        durationDays: 'duration_days',
        price: 'price',
        status: 'status',
      }).filter(([key]) => key in body.data);
      const updated = await client.query(
        `UPDATE coach_package_plans
         SET ${fields.map(([, col], index) => `${col} = $${index + 1}`).join(', ')}
         WHERE code = $${fields.length + 1}
         RETURNING *`,
        [...fields.map(([key]) => body.data[key]), code.data],
      );
      const after = updated.rows[0];
      await client.query(
        `INSERT INTO admin_audit_logs
         (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'COACH_PACKAGE_UPDATED', 'COACH_PACKAGE', $3, $4, $5)`,
        [
          randomUUID(),
          request.authUser.id,
          code.data,
          `Cập nhật gói Coach: ${after.name} (${after.code})`,
          JSON.stringify({ before: view(old, false), after: view(after, false) }),
        ],
      );
      await client.query('COMMIT');
      return response.json({ data: view(after, true) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không cập nhật được gói Coach');
    } finally { client.release(); }
  });

  router.get('/admin/coach-entitlements', async (request, response) => {
    const parsed = entitlementQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Bộ lọc quyền lợi gói Coach không hợp lệ');
    }
    const { memberId, coachId, status, frozenOnly, search, page, pageSize } = parsed.data;
    const filters = [];
    const values = [];
    if (memberId) {
      values.push(memberId);
      filters.push(`e.member_id = $${values.length}`);
    }
    if (coachId) {
      values.push(coachId);
      filters.push(`e.coach_id = $${values.length}`);
    }
    if (status) {
      values.push(status);
      filters.push(`e.status = $${values.length}`);
    }
    if (frozenOnly === 'true') {
      filters.push('e.frozen_at IS NOT NULL');
    }
    if (search) {
      values.push(`%${escapeLike(search)}%`);
      const param = `$${values.length}`;
      filters.push(
        `(m.full_name ILIKE ${param} ESCAPE '\\' OR c.full_name ILIKE ${param} ESCAPE '\\' OR COALESCE(e.plan_code, h.plan_code, '') ILIKE ${param} ESCAPE '\\' OR COALESCE(e.plan_name, h.plan_name, '') ILIKE ${param} ESCAPE '\\')`,
      );
    }
    const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    try {
      const [totalRes, rowsRes] = await Promise.all([
        database.query(
          `SELECT count(*)::int AS count
           FROM coach_entitlements e
           JOIN coach_relationships r ON r.id = e.relationship_id
           JOIN users m ON m.id = e.member_id
           JOIN users c ON c.id = e.coach_id
           LEFT JOIN coach_payment_holds h ON h.id = COALESCE(e.original_hold_id, e.hold_id)
           ${whereClause}`,
          values,
        ),
        database.query(
          `SELECT e.id, e.relationship_id, r.status AS relationship_status,
                  e.member_id, m.full_name AS member_name,
                  e.coach_id, c.full_name AS coach_name,
                  COALESCE(e.plan_code, h.plan_code) AS plan_code,
                  COALESCE(e.plan_name, h.plan_name) AS plan_name,
                  COALESCE(e.snapshot_price, h.amount) AS snapshot_price,
                  e.status, e.total_sessions, e.remaining_sessions, e.duration_days,
                  e.starts_on::text AS starts_on,
                  e.original_ends_on::text AS original_ends_on,
                  e.ends_on::text AS ends_on,
                  e.frozen_at, e.frozen_days_total, e.grace_days_added,
                  e.close_reason, e.ended_at
           FROM coach_entitlements e
           JOIN coach_relationships r ON r.id = e.relationship_id
           JOIN users m ON m.id = e.member_id
           JOIN users c ON c.id = e.coach_id
           LEFT JOIN coach_payment_holds h ON h.id = COALESCE(e.original_hold_id, e.hold_id)
           ${whereClause}
           ORDER BY (e.status = 'ACTIVE') DESC, (e.status = 'QUEUED') DESC,
                    COALESCE(e.starts_on, CURRENT_DATE) DESC, e.id DESC
           LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
          [...values, pageSize, (page - 1) * pageSize],
        ),
      ]);
      const totalItems = totalRes.rows[0].count;
      return response.json({
        data: rowsRes.rows.map(entitlementView),
        pagination: {
          page,
          pageSize,
          totalItems,
          totalPages: Math.ceil(totalItems / pageSize),
        },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được quyền lợi gói Coach');
    }
  });

  return router;
}
