import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const codeSchema = z.enum(['BASIC', 'STANDARD', 'ADVANCED']);
const patchSchema = z.strictObject({
  price: z.number().int().min(0).max(Number.MAX_SAFE_INTEGER).optional(),
  status: z.enum(['ACTIVE', 'INACTIVE']).optional(),
});

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, details: {}, message } });
}

function view(row) {
  return { code: row.code, name: row.name, sessionCount: row.session_count,
    durationDays: row.duration_days, price: Number(row.price), status: row.status };
}

export function createCoachPackagesRouter({ database, jwtSecret }) {
  const router = Router();

  router.get('/coach-packages', async (_request, response) => {
    try {
      const result = await database.query(
        `SELECT * FROM coach_package_plans WHERE status = 'ACTIVE'
         ORDER BY session_count`,
      );
      return response.json({ data: result.rows.map(view) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được gói Coach'); }
  });

  router.use('/admin/coach-packages', createAuthentication({ database, jwtSecret }));
  router.use('/admin/coach-packages', (request, response, next) =>
    request.authUser.role === 'ADMIN' ? next()
      : fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị'));

  router.get('/admin/coach-packages', async (_request, response) => {
    try {
      const result = await database.query(
        'SELECT * FROM coach_package_plans ORDER BY session_count',
      );
      return response.json({ data: result.rows.map(view) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được gói Coach'); }
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
      const old = before.rows[0];
      const price = body.data.price ?? Number(old.price);
      const status = body.data.status ?? old.status;
      const updated = await client.query(
        `UPDATE coach_package_plans SET price = $1, status = $2
         WHERE code = $3 RETURNING *`, [price, status, code.data],
      );
      const after = updated.rows[0];
      await client.query(
        `INSERT INTO admin_audit_logs
         (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'COACH_PACKAGE_UPDATED', 'COACH_PACKAGE', $3,
           'Updated Coach package', $4)`,
        [randomUUID(), request.authUser.id, code.data,
          JSON.stringify({ before: view(old), after: view(after) })],
      );
      await client.query('COMMIT');
      return response.json({ data: view(after) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không cập nhật được gói Coach');
    } finally { client.release(); }
  });
  return router;
}
