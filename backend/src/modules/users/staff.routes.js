import { randomBytes, randomUUID } from 'node:crypto';

import bcrypt from 'bcryptjs';
import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';
import {
  CREATABLE_STAFF_POSITIONS,
  STAFF_POSITION_DEFINITIONS,
  STAFF_ROLE_CODES,
  getPositionDefinition,
  hasBackofficePermission,
  resolveUserStaffPosition,
} from './staff-positions.js';

const uuid = z.uuid();
const STAFF_TEMP_PW_REMINDER =
  'Hãy gửi mật khẩu tạm cho nhân sự qua kênh nội bộ và nhắc đổi mật khẩu ngay sau khi đăng nhập.';

const phoneOptionalSchema = z.union([
  z.null(),
  z.string().trim().max(20, 'Số điện thoại tối đa 20 ký tự'),
]).optional().transform((val) => (val === '' ? null : val)).refine((val) => {
  if (val === undefined || val === null) return true;
  const digits = val.replace(/\D/g, '');
  return /^[+]?[0-9][0-9\s.-]{7,19}$/.test(val) && digits.length >= 8 && digits.length <= 15;
}, 'Số điện thoại không hợp lệ (8–15 chữ số)');

const createStaffSchema = z.strictObject({
  fullName: z.string().trim().min(2, 'Họ và tên phải có 2–120 ký tự').max(120),
  email: z.string().trim().toLowerCase().email('Email không hợp lệ').max(255),
  phone: phoneOptionalSchema,
  position: z.enum(CREATABLE_STAFF_POSITIONS, {
    errorMap: () => ({ message: 'Vị trí nhân viên không hợp lệ' }),
  }),
  department: z.string().trim().min(1).max(80).optional(),
  shiftNote: z.union([z.null(), z.string().trim().max(200)]).optional().transform((v) => (v === '' ? null : v)),
  password: z.string().min(8, 'Mật khẩu tối thiểu 8 ký tự').refine(
    (v) => Buffer.byteLength(v, 'utf8') <= 72 && /[a-z]/.test(v) && /[A-Z]/.test(v) && /[0-9]/.test(v),
    'Mật khẩu phải dài 8–72 byte và có chữ hoa, chữ thường, chữ số',
  ),
});

const patchStaffSchema = z.strictObject({
  fullName: z.string().trim().min(2, 'Họ và tên phải có 2–120 ký tự').max(120).optional(),
  phone: phoneOptionalSchema,
  position: z.enum(STAFF_ROLE_CODES).optional(),
  department: z.string().trim().min(1).max(80).optional(),
  shiftNote: z.union([z.null(), z.string().trim().max(200)]).optional().transform((v) => (v === '' ? null : v)),
  status: z.enum(['ACTIVE', 'DISABLED']).optional(),
  reason: z.string().trim().min(1).max(500).optional(),
});

function fail(response, status, code, message, details = {}) {
  return response.status(status).json({ error: { code, details, message } });
}

function escapeLike(value) {
  return value.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
}

function serializeStaffRow(row) {
  const position = row.role === 'ADMIN'
    ? 'ADMIN'
    : row.role === 'COACH'
      ? 'COACH'
      : (row.position_code || 'RECEPTIONIST');
  const def = getPositionDefinition(position);
  return {
    id: row.id,
    fullName: row.full_name,
    email: row.email,
    phone: row.phone ?? null,
    role: row.role,
    position,
    positionTitle: def?.title || position,
    positionShortTitle: def?.shortTitle || position,
    portal: def?.portal || 'Web Admin',
    badgeKind: def?.badgeKind || 'neutral',
    department: row.department || def?.departmentDefault || 'Vận hành',
    shiftNote: row.shift_note ?? null,
    status: row.status,
    disabledAt: row.disabled_at ?? null,
    disabledReason: row.disabled_reason ?? null,
    lastLoginAt: row.last_login_at ?? null,
    createdAt: row.created_at,
    usedSlots: row.role === 'COACH' && row.used_slots !== undefined ? Number(row.used_slots) : null,
    memberLimit: row.role === 'COACH' ? 8 : null,
    avatarUrl: row.avatar_media_id ? `/api/v1/users/${row.id}/avatar` : null,
    avatarThumbnailUrl: row.avatar_media_id ? `/api/v1/users/${row.id}/avatar?size=120` : null,
  };
}

async function verifyActiveActor(client, authUser, requiredPermission) {
  if (!hasBackofficePermission(authUser, requiredPermission)) return false;
  if (authUser.role === 'ADMIN') {
    const res = await client.query(
      `SELECT id FROM users WHERE id = $1 AND role = 'ADMIN' AND status = 'ACTIVE' AND session_version = $2 FOR SHARE`,
      [authUser.id, authUser.session_version],
    );
    return res.rows.length === 1;
  }
  const res = await client.query(
    `SELECT u.id FROM users u WHERE u.id = $1 AND u.role = 'STAFF' AND u.status = 'ACTIVE' AND u.session_version = $2 FOR SHARE`,
    [authUser.id, authUser.session_version],
  );
  return res.rows.length === 1;
}

export function createStaffRouter({ database, jwtSecret }) {
  const router = Router();
  router.use('/staff-positions', createAuthentication({ database, jwtSecret }));
  router.use('/staff', createAuthentication({ database, jwtSecret }));

  router.get('/staff-positions', async (request, response) => {
    if (!hasBackofficePermission(request.authUser, 'staff:read')) {
      return fail(response, 403, 'FORBIDDEN', 'Không có quyền xem danh mục vị trí nhân viên');
    }
    try {
      const countsRes = await database.query(
        `SELECT CASE
                  WHEN u.role = 'ADMIN' THEN 'ADMIN'
                  WHEN u.role = 'COACH' THEN 'COACH'
                  ELSE sp.position_code
                END AS position,
                COUNT(*)::int AS total_count,
                COUNT(*) FILTER (WHERE u.status = 'ACTIVE')::int AS active_count
         FROM users u
         LEFT JOIN staff_profiles sp ON sp.user_id = u.id
         WHERE u.role IN ('ADMIN', 'STAFF', 'COACH')
         GROUP BY 1`,
      );
      const countMap = new Map(countsRes.rows.map((r) => [r.position, {
        totalCount: Number(r.total_count ?? 0),
        activeCount: Number(r.active_count ?? 0),
      }]));

      const positions = STAFF_POSITION_DEFINITIONS.map((def) => ({
        ...def,
        ...(countMap.get(def.code) || { totalCount: 0, activeCount: 0 }),
      }));

      return response.json({
        data: {
          positions,
          currentActorPosition: resolveUserStaffPosition(request.authUser),
        },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được danh sách vị trí nhân viên');
    }
  });

  router.get('/staff', async (request, response) => {
    if (!hasBackofficePermission(request.authUser, 'staff:read')) {
      return fail(response, 403, 'FORBIDDEN', 'Không có quyền xem danh sách nhân sự');
    }

    const parsed = z.strictObject({
      position: z.enum(['ALL', 'ADMIN', 'MANAGER', 'RECEPTIONIST', 'COACH', 'TECHNICIAN']).default('ALL'),
      status: z.enum(['ALL', 'ACTIVE', 'DISABLED']).default('ALL'),
      search: z.string().trim().max(120).optional(),
      page: z.coerce.number().int().min(1).default(1),
      pageSize: z.coerce.number().int().min(1).max(100).default(20),
    }).safeParse(request.query);

    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Bộ lọc nhân sự không hợp lệ');
    }

    const { position, status, search, page, pageSize } = parsed.data;
    const filters = [`u.role IN ('ADMIN', 'STAFF', 'COACH')`];
    const values = [];

    if (position === 'ADMIN') {
      filters.push(`u.role = 'ADMIN'`);
    } else if (position === 'COACH') {
      filters.push(`u.role = 'COACH'`);
    } else if (position !== 'ALL') {
      values.push(position);
      filters.push(`u.role = 'STAFF' AND sp.position_code = $${values.length}`);
    }

    if (status !== 'ALL') {
      values.push(status);
      filters.push(`u.status = $${values.length}`);
    }

    if (search) {
      values.push(`%${escapeLike(search)}%`);
      const p = `$${values.length}`;
      filters.push(
        `(u.full_name ILIKE ${p} ESCAPE '\\' OR u.email::text ILIKE ${p} ESCAPE '\\' OR COALESCE(u.phone, '') ILIKE ${p} ESCAPE '\\' OR COALESCE(sp.department, '') ILIKE ${p} ESCAPE '\\')`,
      );
    }

    const whereClause = filters.join(' AND ');
    try {
      const [countRes, listRes] = await Promise.all([
        database.query(
          `SELECT count(*)::int AS count
           FROM users u
           LEFT JOIN staff_profiles sp ON sp.user_id = u.id
           WHERE ${whereClause}`,
          values,
        ),
        database.query(
          `SELECT u.id, u.email::text, u.full_name, u.phone, u.avatar_media_id, u.role, u.status,
                  u.disabled_at, u.disabled_reason, u.last_login_at, u.created_at,
                  sp.position_code, sp.department, sp.shift_note,
                  CASE WHEN u.role = 'COACH' THEN coach_occupied_seats(u.id) ELSE NULL END AS used_slots
           FROM users u
           LEFT JOIN staff_profiles sp ON sp.user_id = u.id
           WHERE ${whereClause}
           ORDER BY CASE u.role WHEN 'ADMIN' THEN 1 WHEN 'STAFF' THEN 2 WHEN 'COACH' THEN 3 ELSE 4 END ASC,
                    CASE sp.position_code WHEN 'MANAGER' THEN 1 WHEN 'RECEPTIONIST' THEN 2 WHEN 'TECHNICIAN' THEN 3 ELSE 4 END ASC,
                    u.created_at DESC
           LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
          [...values, pageSize, (page - 1) * pageSize],
        ),
      ]);

      const totalItems = Number(countRes.rows[0]?.count ?? 0);
      return response.json({
        data: listRes.rows.map(serializeStaffRow),
        pagination: {
          page,
          pageSize,
          totalItems,
          totalPages: Math.max(1, Math.ceil(totalItems / pageSize)),
        },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được danh sách nhân sự');
    }
  });

  router.post('/staff', async (request, response) => {
    if (!hasBackofficePermission(request.authUser, 'staff:manage')) {
      return fail(response, 403, 'FORBIDDEN', 'Không có quyền tạo tài khoản nhân sự');
    }

    const parsed = createStaffSchema.safeParse(request.body);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', parsed.error.issues[0]?.message || 'Dữ liệu nhân sự không hợp lệ');
    }

    const { fullName, email, phone, position, department, shiftNote, password } = parsed.data;
    if (position === 'MANAGER' && request.authUser.role !== 'ADMIN') {
      return fail(response, 403, 'FORBIDDEN', 'Chỉ Quản trị viên (Admin) mới được bổ nhiệm Quản lý vận hành');
    }

    const def = getPositionDefinition(position);
    const targetUserRole = position === 'COACH' ? 'COACH' : 'STAFF';
    const hash = await bcrypt.hash(password, 12);
    const userId = randomUUID();
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được cơ sở dữ liệu');

    try {
      await client.query('BEGIN');
      if (!await verifyActiveActor(client, request.authUser, 'staff:manage')) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }

      const roleRes = await client.query(`SELECT id FROM roles WHERE code = $1 LIMIT 1`, [def.roleCode]);
      const roleId = roleRes.rows[0]?.id ?? null;

      await client.query(
        `INSERT INTO users (id, email, password_hash, role, full_name, phone, role_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [userId, email, hash, targetUserRole, fullName, phone ?? null, roleId],
      );

      if (targetUserRole === 'COACH') {
        await client.query(
          `INSERT INTO coach_profiles (user_id, member_limit, availability_note) VALUES ($1, 8, $2)`,
          [userId, shiftNote ?? null],
        );
      } else {
        await client.query(
          `INSERT INTO staff_profiles (user_id, position_code, department, shift_note)
           VALUES ($1, $2, $3, $4)`,
          [userId, position, department || def.departmentDefault, shiftNote ?? null],
        );
      }

      await client.query(
        `INSERT INTO admin_audit_logs (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'STAFF_CREATED', 'USER', $3, $4, $5)`,
        [
          randomUUID(),
          request.authUser.id,
          userId,
          `Tạo tài khoản nhân sự ${fullName} (${def.shortTitle})`,
          JSON.stringify({ position, role: targetUserRole, department: department || def.departmentDefault }),
        ],
      );

      const createdRes = await client.query(
        `SELECT u.id, u.email::text, u.full_name, u.phone, u.avatar_media_id, u.role, u.status,
                u.disabled_at, u.disabled_reason, u.last_login_at, u.created_at,
                sp.position_code, sp.department, sp.shift_note
         FROM users u
         LEFT JOIN staff_profiles sp ON sp.user_id = u.id
         WHERE u.id = $1`,
        [userId],
      );

      await client.query('COMMIT');
      return response.status(201).json({ data: serializeStaffRow(createdRes.rows[0]) });
    } catch (error) {
      await client.query('ROLLBACK').catch(() => {});
      if (error.code === '23505' && error.constraint === 'users_email_key') {
        return fail(response, 409, 'EMAIL_ALREADY_EXISTS', 'Email đã được sử dụng cho tài khoản khác');
      }
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tạo được tài khoản nhân sự');
    } finally {
      client.release();
    }
  });

  router.patch('/staff/:userId', async (request, response) => {
    if (!hasBackofficePermission(request.authUser, 'staff:manage')) {
      return fail(response, 403, 'FORBIDDEN', 'Không có quyền cập nhật nhân sự');
    }
    if (!uuid.safeParse(request.params.userId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã nhân sự không hợp lệ');
    }
    const parsed = patchStaffSchema.safeParse(request.body);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', parsed.error.issues[0]?.message || 'Dữ liệu cập nhật không hợp lệ');
    }
    const patch = parsed.data;
    if (patch.status === 'DISABLED' && !patch.reason) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Vui lòng nhập lý do khóa tài khoản nhân sự');
    }

    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được cơ sở dữ liệu');

    try {
      await client.query('BEGIN');
      if (!await verifyActiveActor(client, request.authUser, 'staff:manage')) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }

      const existingRes = await client.query(
        `SELECT u.*, sp.position_code, sp.department, sp.shift_note
         FROM users u
         LEFT JOIN staff_profiles sp ON sp.user_id = u.id
         WHERE u.id = $1 AND u.role IN ('ADMIN', 'STAFF')
         FOR UPDATE OF u`,
        [request.params.userId],
      );
      const existing = existingRes.rows[0];
      if (!existing) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy tài khoản nhân viên văn phòng/vận hành');
      }
      if (existing.role === 'ADMIN') {
        if (patch.position || patch.status === 'DISABLED') {
          await client.query('ROLLBACK');
          return fail(response, 409, 'ADMIN_PROTECTED', 'Không thể khóa hoặc đổi vị trí tài khoản Quản trị viên duy nhất');
        }
      }
      if ((existing.position_code === 'MANAGER' || patch.position === 'MANAGER') && request.authUser.role !== 'ADMIN') {
        await client.query('ROLLBACK');
        return fail(response, 403, 'FORBIDDEN', 'Chỉ Quản trị viên (Admin) mới được chỉnh sửa Quản lý vận hành');
      }

      const nextFullName = patch.fullName ?? existing.full_name;
      const nextPhone = patch.phone === undefined ? existing.phone : patch.phone;
      const nextStatus = patch.status ?? existing.status;
      const nextDisabledAt = patch.status === 'DISABLED'
        ? new Date().toISOString()
        : (patch.status === 'ACTIVE' ? null : existing.disabled_at);
      const nextDisabledReason = patch.status === 'DISABLED'
        ? patch.reason
        : (patch.status === 'ACTIVE' ? null : existing.disabled_reason);
      const revokeSession = patch.status === 'DISABLED' || (patch.position && patch.position !== existing.position_code);

      let nextRoleId = existing.role_id;
      if (existing.role === 'STAFF' && patch.position) {
        const def = getPositionDefinition(patch.position);
        const rRes = await client.query(`SELECT id FROM roles WHERE code = $1 LIMIT 1`, [def.roleCode]);
        nextRoleId = rRes.rows[0]?.id ?? existing.role_id;
      }

      await client.query(
        `UPDATE users
         SET full_name = $1,
             phone = $2,
             status = $3,
             disabled_at = $4,
             disabled_reason = $5,
             role_id = $6,
             session_version = session_version + $7,
             is_locked = ($3 = 'DISABLED'),
             updated_at = now()
         WHERE id = $8`,
        [nextFullName, nextPhone, nextStatus, nextDisabledAt, nextDisabledReason, nextRoleId, revokeSession ? 1 : 0, existing.id],
      );

      if (existing.role === 'STAFF') {
        const nextPos = patch.position ?? existing.position_code;
        const nextDept = patch.department ?? existing.department ?? getPositionDefinition(nextPos)?.departmentDefault ?? 'Vận hành';
        const nextShift = patch.shiftNote === undefined ? existing.shift_note : patch.shiftNote;
        await client.query(
          `INSERT INTO staff_profiles (user_id, position_code, department, shift_note)
           VALUES ($1, $2, $3, $4)
           ON CONFLICT (user_id) DO UPDATE
             SET position_code = EXCLUDED.position_code,
                 department = EXCLUDED.department,
                 shift_note = EXCLUDED.shift_note,
                 updated_at = now()`,
          [existing.id, nextPos, nextDept, nextShift],
        );
      }

      await client.query(
        `INSERT INTO admin_audit_logs (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'STAFF_UPDATED', 'USER', $3, $4, $5)`,
        [
          randomUUID(),
          request.authUser.id,
          existing.id,
          `Cập nhật nhân sự ${nextFullName}${patch.position ? ` · Vị trí ${patch.position}` : ''}`,
          JSON.stringify({ status: nextStatus, position: patch.position ?? existing.position_code, reason: patch.reason ?? null }),
        ],
      );

      const updatedRes = await client.query(
        `SELECT u.id, u.email::text, u.full_name, u.phone, u.avatar_media_id, u.role, u.status,
                u.disabled_at, u.disabled_reason, u.last_login_at, u.created_at,
                sp.position_code, sp.department, sp.shift_note
         FROM users u
         LEFT JOIN staff_profiles sp ON sp.user_id = u.id
         WHERE u.id = $1`,
        [existing.id],
      );
      await client.query('COMMIT');
      return response.json({ data: serializeStaffRow(updatedRes.rows[0]) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không cập nhật được thông tin nhân sự');
    } finally {
      client.release();
    }
  });

  router.post('/staff/:userId/password-resets', async (request, response) => {
    if (!hasBackofficePermission(request.authUser, 'staff:manage')) {
      return fail(response, 403, 'FORBIDDEN', 'Không có quyền cấp mật khẩu tạm');
    }
    if (!uuid.safeParse(request.params.userId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã nhân sự không hợp lệ');
    }
    const temporaryPassword = `Mg!${randomBytes(6).toString('base64url')}9`;
    const hash = await bcrypt.hash(temporaryPassword, 12);
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được cơ sở dữ liệu');

    try {
      await client.query('BEGIN');
      if (!await verifyActiveActor(client, request.authUser, 'staff:manage')) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const res = await client.query(
        `UPDATE users
         SET password_hash = $1, session_version = session_version + 1, updated_at = now()
         WHERE id = $2 AND role IN ('STAFF', 'COACH')
         RETURNING id, full_name, role`,
        [hash, request.params.userId],
      );
      if (!res.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy nhân viên hoặc không áp dụng cho Admin');
      }
      await client.query(
        `INSERT INTO admin_audit_logs (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'STAFF_TEMP_PASSWORD_ISSUED', 'USER', $3, $4, '{}'::jsonb)`,
        [randomUUID(), request.authUser.id, request.params.userId, `Cấp mật khẩu tạm cho ${res.rows[0].full_name}`],
      );
      await client.query('COMMIT');
      return response.json({
        data: {
          userId: res.rows[0].id,
          temporaryPassword,
          reminder: STAFF_TEMP_PW_REMINDER,
          sessionRevoked: true,
        },
      });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không cấp được mật khẩu tạm');
    } finally {
      client.release();
    }
  });

  return router;
}
