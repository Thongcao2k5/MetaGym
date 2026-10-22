import { randomBytes, randomUUID } from 'node:crypto';

import bcrypt from 'bcryptjs';
import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();
const coachCreate = z.strictObject({
  email: z.string().trim().toLowerCase().email(),
  fullName: z.string().trim().min(2).max(120),
  password: z.string().min(8).refine((value) =>
    Buffer.byteLength(value, 'utf8') <= 72 && /[a-z]/.test(value) &&
    /[A-Z]/.test(value) && /[0-9]/.test(value)),
  memberLimit: z.number().int().min(1).max(32767),
});
const accountPatch = z.strictObject({
  fullName: z.string().trim().min(2).max(120).optional(),
  phone: z.string().trim().max(20).nullable().optional(),
  memberLimit: z.number().int().min(1).max(32767).optional(),
});
const statusPatch = z.strictObject({
  status: z.enum(['ACTIVE', 'DISABLED']),
  reason: z.string().trim().min(1).max(500).optional(),
});

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, details: {}, message } });
}

function publicAccount(row) {
  return {
    id: row.id, email: row.email, fullName: row.full_name,
    phone: row.phone, role: row.role, status: row.status,
    memberLimit: row.role === 'COACH' ? row.member_limit : null,
    createdAt: row.created_at,
  };
}

async function audit(client, adminId, action, entityId, before, after) {
  await client.query(
    `INSERT INTO admin_audit_logs
     (id, admin_id, action, entity_type, entity_id, summary, metadata)
     VALUES ($1, $2, $3, 'USER', $4, $5, $6)`,
    [randomUUID(), adminId, action, entityId, action,
      JSON.stringify({ before, after })],
  );
}

async function fetchAccount(database, id, lock = false) {
  const result = await database.query(
    `SELECT u.id, u.email::text, u.full_name, u.phone, u.role,
            u.status, u.created_at, c.member_limit
     FROM users u LEFT JOIN coach_profiles c ON c.user_id = u.id
     WHERE u.id = $1 AND u.role IN ('MEMBER', 'COACH')
     ${lock ? 'FOR UPDATE OF u' : ''}`, [id],
  );
  return result.rows[0];
}

async function activeAdmin(client, user) {
  const result = await client.query(
    `SELECT id FROM users WHERE id = $1 AND role = 'ADMIN' AND status = 'ACTIVE'
     AND session_version = $2 FOR SHARE`, [user.id, user.session_version],
  );
  return result.rows.length === 1;
}

export function createAdminUsersRouter({ database, jwtSecret }) {
  const router = Router();
  router.use(createAuthentication({ database, jwtSecret }));
  router.use((request, response, next) => request.authUser.role === 'ADMIN'
    ? next() : fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị'));

  router.get('/users', async (request, response) => {
    const parsed = z.strictObject({
      role: z.enum(['MEMBER', 'COACH']).optional(),
      status: z.enum(['ACTIVE', 'DISABLED']).optional(),
      search: z.string().trim().max(120).optional(),
      page: z.coerce.number().int().min(1).default(1),
      pageSize: z.coerce.number().int().min(1).max(100).default(20),
    }).safeParse(request.query);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Bộ lọc không hợp lệ');
    const { role, status, search, page, pageSize } = parsed.data;
    const filters = [`u.role IN ('MEMBER', 'COACH')`];
    const values = [];
    if (role) { values.push(role); filters.push(`u.role = $${values.length}`); }
    if (status) { values.push(status); filters.push(`u.status = $${values.length}`); }
    if (search) {
      values.push(`%${search.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%`);
      filters.push(`(u.email::text ILIKE $${values.length} ESCAPE '\\' OR u.full_name ILIKE $${values.length} ESCAPE '\\')`);
    }
    try {
      const total = await database.query(`SELECT count(*)::int AS count FROM users u WHERE ${filters.join(' AND ')}`, values);
      const rows = await database.query(
        `SELECT u.id, u.email::text, u.full_name, u.phone, u.role, u.status,
                u.created_at, c.member_limit
         FROM users u LEFT JOIN coach_profiles c ON c.user_id = u.id
         WHERE ${filters.join(' AND ')} ORDER BY u.created_at DESC, u.id DESC
         LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
        [...values, pageSize, (page - 1) * pageSize],
      );
      const totalItems = total.rows[0].count;
      return response.json({ data: rows.rows.map(publicAccount), pagination: {
        page, pageSize, totalItems, totalPages: Math.ceil(totalItems / pageSize),
      } });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được tài khoản');
    }
  });

  router.get('/users/:userId', async (request, response) => {
    if (!uuid.safeParse(request.params.userId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã tài khoản không hợp lệ');
    }
    try {
      const account = await fetchAccount(database, request.params.userId);
      return account ? response.json({ data: publicAccount(account) })
        : fail(response, 404, 'NOT_FOUND', 'Không tìm thấy tài khoản');
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được tài khoản');
    }
  });

  router.post('/coaches', async (request, response) => {
    const parsed = coachCreate.safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu Coach không hợp lệ');
    const { email, fullName, password, memberLimit } = parsed.data;
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      const hash = await bcrypt.hash(password, 12);
      const id = randomUUID();
      await client.query('BEGIN');
      if (!await activeAdmin(client, request.authUser)) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      await client.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, $3, 'COACH', $4)`, [id, email, hash, fullName],
      );
      await client.query(
        'INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, $2)',
        [id, memberLimit],
      );
      await audit(client, request.authUser.id, 'COACH_CREATED', id, null,
        { email, fullName, memberLimit });
      const coach = await fetchAccount(client, id);
      await client.query('COMMIT');
      return response.status(201).json({ data: publicAccount(coach) });
    } catch (cause) {
      await client.query('ROLLBACK').catch(() => {});
      if (cause.code === '23505' && cause.constraint === 'users_email_key') {
        return fail(response, 409, 'EMAIL_ALREADY_EXISTS', 'Email đã được sử dụng');
      }
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tạo được Coach');
    } finally { client.release(); }
  });

  router.post('/coaches/:coachId/password-resets', async (request, response) => {
    if (!uuid.safeParse(request.params.coachId).success ||
      !z.strictObject({}).safeParse(request.body ?? {}).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu không hợp lệ');
    }
    const temporaryPassword = `A1a${randomBytes(18).toString('base64url')}`;
    const hash = await bcrypt.hash(temporaryPassword, 12);
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      if (!await activeAdmin(client, request.authUser)) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const coach = await client.query(
        `SELECT id FROM users WHERE id = $1 AND role = 'COACH' FOR UPDATE`,
        [request.params.coachId],
      );
      if (!coach.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy Coach');
      }
      await client.query(
        `UPDATE users SET password_hash = $1, session_version = session_version + 1
         WHERE id = $2`, [hash, request.params.coachId],
      );
      await audit(client, request.authUser.id, 'COACH_PASSWORD_RESET',
        request.params.coachId, null, { sessionRevoked: true });
      await client.query('COMMIT');
      return response.status(201).json({ data: { temporaryPassword } });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không đặt lại được mật khẩu Coach');
    } finally { client.release(); }
  });

  router.patch('/users/:userId', async (request, response) => {
    if (!uuid.safeParse(request.params.userId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã tài khoản không hợp lệ');
    const parsed = accountPatch.safeParse(request.body);
    if (!parsed.success || !Object.keys(parsed.data ?? {}).length) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu cập nhật không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      if (!await activeAdmin(client, request.authUser)) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const before = await fetchAccount(client, request.params.userId, true);
      if (!before) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy tài khoản');
      }
      if ('memberLimit' in parsed.data && before.role !== 'COACH') {
        await client.query('ROLLBACK');
        return fail(response, 422, 'VALIDATION_ERROR', 'Chỉ Coach có giới hạn Member');
      }
      const fields = [['fullName', 'full_name'], ['phone', 'phone']]
        .filter(([key]) => key in parsed.data);
      if (fields.length) {
        await client.query(
          `UPDATE users SET ${fields.map(([, column], index) => `${column} = $${index + 1}`).join(', ')} WHERE id = $${fields.length + 1}`,
          [...fields.map(([key]) => parsed.data[key]), before.id],
        );
      }
      if ('memberLimit' in parsed.data) {
        await client.query('UPDATE coach_profiles SET member_limit = $1 WHERE user_id = $2',
          [parsed.data.memberLimit, before.id]);
      }
      const after = await fetchAccount(client, before.id);
      await audit(client, request.authUser.id, 'USER_UPDATED', before.id,
        publicAccount(before), publicAccount(after));
      await client.query('COMMIT');
      return response.json({ data: publicAccount(after) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không cập nhật được tài khoản');
    } finally { client.release(); }
  });

  router.patch('/users/:userId/status', async (request, response) => {
    if (!uuid.safeParse(request.params.userId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã tài khoản không hợp lệ');
    const parsed = statusPatch.safeParse(request.body);
    if (!parsed.success || (parsed.data.status === 'DISABLED' && !parsed.data.reason)) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Trạng thái hoặc lý do không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      if (!await activeAdmin(client, request.authUser)) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const before = await fetchAccount(client, request.params.userId, true);
      if (!before) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy tài khoản');
      }
      if (before.status === parsed.data.status) {
        await client.query('ROLLBACK');
        return response.json({ data: publicAccount(before) });
      }
      await client.query(
        `UPDATE users SET status = $1, disabled_at = $2, disabled_reason = $3,
         session_version = session_version + 1 WHERE id = $4`,
        [parsed.data.status, parsed.data.status === 'DISABLED' ? new Date() : null,
          parsed.data.status === 'DISABLED' ? parsed.data.reason : null, before.id],
      );
      const after = await fetchAccount(client, before.id);
      await audit(client, request.authUser.id,
        parsed.data.status === 'DISABLED' ? 'USER_DISABLED' : 'USER_ENABLED',
        before.id, publicAccount(before), publicAccount(after));
      await client.query('COMMIT');
      return response.json({ data: publicAccount(after) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không cập nhật được trạng thái');
    } finally { client.release(); }
  });

  return router;
}
