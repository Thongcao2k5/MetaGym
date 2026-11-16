import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();
const createSchema = z.strictObject({
  name: z.string().trim().min(1).max(100),
  description: z.string().nullable().optional(),
  price: z.number().int().min(0).max(Number.MAX_SAFE_INTEGER),
  durationDays: z.number().int().min(1).max(3650),
  status: z.enum(['ACTIVE', 'INACTIVE']).default('ACTIVE'),
});
const patchSchema = createSchema.partial();

function error(response, status, code, message) {
  return response.status(status).json({ error: { code, details: {}, message } });
}

function publicPlan(row) {
  return {
    id: row.id, name: row.name, description: row.description,
    price: Number(row.price), durationDays: row.duration_days,
    status: row.status,
  };
}

async function planById(database, id, lock = false) {
  const result = await database.query(
    `SELECT id, name, description, price, duration_days, status FROM membership_plans
     WHERE id = $1 ${lock ? 'FOR UPDATE' : ''}`, [id],
  );
  return result.rows[0];
}

export function createMembershipPlansRouter({ database, jwtSecret }) {
  const router = Router();
  router.get('/membership-plans', async (request, response) => {
    const parsed = z.strictObject({
      page: z.coerce.number().int().min(1).default(1),
      pageSize: z.coerce.number().int().min(1).max(100).default(20),
    }).safeParse(request.query);
    if (!parsed.success) return error(response, 422, 'VALIDATION_ERROR', 'Bộ lọc không hợp lệ');
    const { page, pageSize } = parsed.data;
    try {
      const total = await database.query(
        `SELECT count(*)::int AS count FROM membership_plans WHERE status = 'ACTIVE'`,
      );
      const result = await database.query(
        `SELECT id, name, description, price, duration_days, status
         FROM membership_plans WHERE status = 'ACTIVE'
         ORDER BY created_at DESC, id DESC LIMIT $1 OFFSET $2`,
        [pageSize, (page - 1) * pageSize],
      );
      const totalItems = total.rows[0].count;
      return response.json({ data: result.rows.map(publicPlan), pagination: {
        page, pageSize, totalItems, totalPages: Math.ceil(totalItems / pageSize),
      } });
    } catch {
      return error(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được gói tập');
    }
  });

  router.get('/membership-plans/:planId', async (request, response) => {
    if (!uuid.safeParse(request.params.planId).success) return error(response, 422, 'VALIDATION_ERROR', 'Mã gói không hợp lệ');
    try {
      const plan = await planById(database, request.params.planId);
      return plan?.status === 'ACTIVE' ? response.json({ data: publicPlan(plan) })
        : error(response, 404, 'NOT_FOUND', 'Không tìm thấy gói tập');
    } catch {
      return error(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được gói tập');
    }
  });

  router.use('/admin/membership-plans', createAuthentication({ database, jwtSecret }));
  router.use('/admin/membership-plans', (request, response, next) =>
    request.authUser.role === 'ADMIN' ? next()
      : error(response, 403, 'FORBIDDEN', 'Không có quyền quản trị'));

  router.get('/admin/membership-plans', async (request, response) => {
    const parsed = z.strictObject({
      page: z.coerce.number().int().min(1).default(1),
      pageSize: z.coerce.number().int().min(1).max(100).default(20),
    }).safeParse(request.query);
    if (!parsed.success) return error(response, 422, 'VALIDATION_ERROR', 'Phân trang không hợp lệ');
    const { page, pageSize } = parsed.data;
    try {
      const total = await database.query('SELECT count(*)::int AS count FROM membership_plans');
      const result = await database.query(
        `SELECT id, name, description, price, duration_days, status
         FROM membership_plans ORDER BY created_at DESC, id DESC LIMIT $1 OFFSET $2`,
        [pageSize, (page - 1) * pageSize],
      );
      const totalItems = total.rows[0].count;
      return response.json({ data: result.rows.map(publicPlan), pagination: {
        page, pageSize, totalItems, totalPages: Math.ceil(totalItems / pageSize),
      } });
    } catch { return error(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được gói tập'); }
  });

  router.post('/admin/membership-plans', async (request, response) => {
    const parsed = createSchema.safeParse(request.body);
    if (!parsed.success) return error(response, 422, 'VALIDATION_ERROR', 'Dữ liệu gói tập không hợp lệ');
    const client = await database.connect().catch(() => null);
    if (!client) return error(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const admin = await client.query(
        `SELECT id FROM users WHERE id = $1 AND role = 'ADMIN' AND status = 'ACTIVE'
         AND session_version = $2 FOR SHARE`,
        [request.authUser.id, request.authUser.session_version],
      );
      if (admin.rows.length !== 1) {
        await client.query('ROLLBACK');
        return error(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const id = randomUUID();
      const p = parsed.data;
      await client.query(
        `INSERT INTO membership_plans
         (id, name, description, price, duration_days, status, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [id, p.name, p.description ?? null, p.price, p.durationDays, p.status, request.authUser.id],
      );
      await client.query(
        `INSERT INTO admin_audit_logs
         (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'MEMBERSHIP_PLAN_CREATED', 'MEMBERSHIP_PLAN', $3, 'Created plan', $4)`,
        [randomUUID(), request.authUser.id, id, JSON.stringify({ after: p })],
      );
      const plan = await planById(client, id);
      await client.query('COMMIT');
      return response.status(201).json({ data: publicPlan(plan) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return error(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tạo được gói tập');
    } finally { client.release(); }
  });

  router.patch('/admin/membership-plans/:planId', async (request, response) => {
    if (!uuid.safeParse(request.params.planId).success) return error(response, 422, 'VALIDATION_ERROR', 'Mã gói không hợp lệ');
    const parsed = patchSchema.safeParse(request.body);
    if (!parsed.success || !Object.keys(parsed.data ?? {}).length) {
      return error(response, 422, 'VALIDATION_ERROR', 'Dữ liệu cập nhật không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return error(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const admin = await client.query(
        `SELECT id FROM users WHERE id = $1 AND role = 'ADMIN' AND status = 'ACTIVE'
         AND session_version = $2 FOR SHARE`,
        [request.authUser.id, request.authUser.session_version],
      );
      if (admin.rows.length !== 1) {
        await client.query('ROLLBACK');
        return error(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const before = await planById(client, request.params.planId, true);
      if (!before) {
        await client.query('ROLLBACK');
        return error(response, 404, 'NOT_FOUND', 'Không tìm thấy gói tập');
      }
      const fields = Object.entries({
        name: 'name', description: 'description', price: 'price',
        durationDays: 'duration_days', status: 'status',
      }).filter(([key]) => key in parsed.data);
      await client.query(
        `UPDATE membership_plans SET ${fields.map(([, col], index) => `${col} = $${index + 1}`).join(', ')}
         WHERE id = $${fields.length + 1}`,
        [...fields.map(([key]) => parsed.data[key]), before.id],
      );
      const after = await planById(client, before.id);
      await client.query(
        `INSERT INTO admin_audit_logs
         (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'MEMBERSHIP_PLAN_UPDATED', 'MEMBERSHIP_PLAN', $3, 'Updated plan', $4)`,
        [randomUUID(), request.authUser.id, before.id,
          JSON.stringify({ before: publicPlan(before), after: publicPlan(after) })],
      );
      await client.query('COMMIT');
      return response.json({ data: publicPlan(after) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return error(response, 500, 'INTERNAL_SERVER_ERROR', 'Không cập nhật được gói tập');
    } finally { client.release(); }
  });
  return router;
}
