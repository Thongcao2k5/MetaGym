import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { prepareMediaAssetCleanup } from '../media/media-cleanup.js';
import { hasBackofficePermission } from '../users/staff-positions.js';
import { createAuthentication } from '../users/users.routes.js';
import { computeVoucherDiscount, serializeVoucher } from './voucher-calculator.js';

const uuid = z.uuid();
const timestampSchema = z.iso.datetime({ offset: true }).nullable().optional();

const voucherPayloadSchema = z.strictObject({
  code: z.string().trim().min(3, 'Mã voucher tối thiểu 3 ký tự').max(40, 'Mã voucher tối đa 40 ký tự')
    .regex(/^[A-Za-z0-9_-]+$/, 'Mã voucher chỉ gồm chữ, số, gạch ngang (-) hoặc gạch dưới (_)')
    .transform((v) => v.toUpperCase()),
  title: z.string().trim().min(2, 'Tiêu đề voucher tối thiểu 2 ký tự').max(120, 'Tiêu đề tối đa 120 ký tự'),
  description: z.union([z.null(), z.string().trim().max(500)]).optional().transform((v) => (v === '' ? null : v)),
  imageMediaId: uuid.nullable().optional(),
  discountType: z.enum(['FIXED_AMOUNT', 'PERCENT']),
  discountValue: z.coerce.number().int('Giá trị giảm phải là số nguyên dương').min(1, 'Giá trị giảm phải lớn hơn 0'),
  maxDiscountAmount: z.union([
    z.null(),
    z.coerce.number().int().min(1000, 'Giảm tối đa phải từ 1.000 ₫'),
  ]).optional(),
  applyScope: z.enum(['ALL', 'GYM_PLAN', 'COACH_PACKAGE']).default('ALL'),
  targetPlanId: uuid.nullable().optional(),
  targetMemberScope: z.enum(['ALL', 'NEW_MEMBER', 'RENEWAL']).default('ALL'),
  minOrderAmount: z.coerce.number().int().min(0, 'Đơn tối thiểu không được âm').default(0),
  maxTotalUses: z.union([
    z.null(),
    z.coerce.number().int().min(1, 'Tổng lượt dùng tối đa >= 1'),
  ]).optional(),
  maxUsesPerMember: z.coerce.number().int().min(1, 'Lượt dùng mỗi hội viên >= 1').max(100).default(1),
  startsAt: timestampSchema,
  endsAt: timestampSchema,
  status: z.enum(['ACTIVE', 'PAUSED', 'ARCHIVED']).default('ACTIVE'),
});

const patchVoucherSchema = voucherPayloadSchema.partial();

const previewSchema = z.strictObject({
  code: z.string().trim().min(1).max(40).transform((v) => v.toUpperCase()),
  planId: uuid.optional(),
  amount: z.coerce.number().int().min(0).optional(),
  memberId: uuid.optional(),
  scope: z.enum(['GYM_PLAN', 'COACH_PACKAGE']).default('GYM_PLAN'),
});

function fail(response, status, code, message, details = {}) {
  return response.status(status).json({ error: { code, details, message } });
}

function escapeLike(value) {
  return value.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
}

function validateVoucherBusinessRules(data) {
  if (data.discountType === 'PERCENT' && (data.discountValue < 1 || data.discountValue > 100)) {
    return 'Mức giảm theo % phải nằm trong khoảng 1 đến 100%.';
  }
  if (data.startsAt && data.endsAt && Date.parse(data.endsAt) < Date.parse(data.startsAt)) {
    return 'Thời gian kết thúc phải lớn hơn hoặc bằng thời gian bắt đầu.';
  }
  if (data.applyScope === 'COACH_PACKAGE' && data.targetPlanId) {
    return 'Chỉ chọn gói Gym cụ thể khi phạm vi là Gói Gym hoặc Tất cả.';
  }
  return null;
}

async function verifyVoucherMedia(client, mediaId) {
  if (!mediaId) return true;
  const res = await client.query(
    `SELECT id FROM media_assets
     WHERE id = $1 AND status = 'READY' AND access_scope = 'PUBLIC' AND purpose = 'VOUCHER'`,
    [mediaId],
  );
  return res.rows.length === 1;
}

async function verifyActiveActor(client, authUser) {
  if (authUser.role === 'ADMIN') {
    const r = await client.query(
      `SELECT id FROM users WHERE id = $1 AND role = 'ADMIN' AND status = 'ACTIVE' AND session_version = $2 FOR SHARE`,
      [authUser.id, authUser.session_version],
    );
    return r.rows.length === 1;
  }
  const r = await client.query(
    `SELECT u.id FROM users u WHERE u.id = $1 AND u.role = 'STAFF' AND u.status = 'ACTIVE' AND u.session_version = $2 FOR SHARE`,
    [authUser.id, authUser.session_version],
  );
  return r.rows.length === 1;
}

async function fetchVoucherById(database, id, lock = false) {
  const res = await database.query(
    `SELECT v.*, mp.name AS target_plan_name
     FROM vouchers v
     LEFT JOIN membership_plans mp ON mp.id = v.target_plan_id
     WHERE v.id = $1
     ${lock ? 'FOR UPDATE OF v' : ''}`,
    [id],
  );
  return res.rows[0] ?? null;
}

export function createVouchersRouter({ database, jwtSecret, imageStorage }) {
  const router = Router();
  const authenticate = createAuthentication({ database, jwtSecret });

  // Public list of currently claimable/upcoming promotional vouchers
  router.get('/vouchers', async (request, response) => {
    const scope = request.query.scope ? String(request.query.scope).toUpperCase() : null;
    try {
      const filters = [`v.status = 'ACTIVE'`, `(v.ends_at IS NULL OR v.ends_at >= now())`];
      const values = [];
      if (scope && ['GYM_PLAN', 'COACH_PACKAGE'].includes(scope)) {
        values.push(scope);
        filters.push(`(v.apply_scope = 'ALL' OR v.apply_scope = $${values.length})`);
      }
      const res = await database.query(
        `SELECT v.*, mp.name AS target_plan_name
         FROM vouchers v
         LEFT JOIN membership_plans mp ON mp.id = v.target_plan_id
         WHERE ${filters.join(' AND ')}
         ORDER BY COALESCE(v.starts_at, v.created_at) DESC, v.created_at DESC`,
        values,
      );
      return response.json({ data: res.rows.map(serializeVoucher) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được danh sách voucher');
    }
  });

  // Preview discount before payment creation (authenticated Member or Counter Staff/Admin)
  router.post('/vouchers/preview', authenticate, async (request, response) => {
    const parsed = previewSchema.safeParse(request.body);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', parsed.error.issues[0]?.message || 'Thông tin kiểm tra voucher không hợp lệ');
    }
    const { code, planId, amount, memberId, scope } = parsed.data;
    const effectiveMemberId = request.authUser.role === 'MEMBER'
      ? request.authUser.id
      : (memberId || null);

    try {
      let orderAmount = amount ?? 0;
      if (planId && amount === undefined) {
        const planRes = await database.query(`SELECT price FROM membership_plans WHERE id = $1`, [planId]);
        if (!planRes.rows.length) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy gói tập');
        orderAmount = Number(planRes.rows[0].price);
      }

      const vRes = await database.query(
        `SELECT v.*, mp.name AS target_plan_name
         FROM vouchers v
         LEFT JOIN membership_plans mp ON mp.id = v.target_plan_id
         WHERE upper(v.code) = $1 LIMIT 1`,
        [code],
      );
      const voucher = vRes.rows[0] ?? null;

      let memberHasPriorSuccessPayment = false;
      let memberRedemptionCount = 0;
      if (effectiveMemberId && voucher) {
        const [priorRes, redemRes] = await Promise.all([
          database.query(
            `SELECT 1 FROM payments WHERE member_id = $1 AND status = 'SUCCESS' LIMIT 1`,
            [effectiveMemberId],
          ),
          database.query(
            `SELECT count(*)::int AS count FROM voucher_redemptions
             WHERE voucher_id = $1 AND member_id = $2 AND status <> 'RELEASED'`,
            [voucher.id, effectiveMemberId],
          ),
        ]);
        memberHasPriorSuccessPayment = priorRes.rows.length > 0;
        memberRedemptionCount = Number(redemRes.rows[0]?.count ?? 0);
      }

      const calc = computeVoucherDiscount({
        voucher,
        orderAmount,
        scope,
        planId: planId ?? null,
        memberHasPriorSuccessPayment,
        memberRedemptionCount,
      });

      if (!calc.valid) {
        return fail(response, 422, calc.code, calc.message);
      }

      return response.json({
        data: {
          voucher: serializeVoucher(voucher),
          originalAmount: calc.originalAmount,
          discountAmount: calc.discountAmount,
          finalAmount: calc.finalAmount,
        },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kiểm tra được mã voucher');
    }
  });

  // Backoffice Admin / Authorized Staff routes
  router.use('/admin/vouchers', authenticate);

  router.get('/admin/vouchers', async (request, response) => {
    if (!hasBackofficePermission(request.authUser, 'plans:read') && !hasBackofficePermission(request.authUser, 'payments:frontdesk')) {
      return fail(response, 403, 'FORBIDDEN', 'Không có quyền xem danh sách voucher');
    }

    const parsed = z.strictObject({
      status: z.enum(['ALL', 'ACTIVE', 'PAUSED', 'ARCHIVED']).default('ALL'),
      discountType: z.enum(['ALL', 'FIXED_AMOUNT', 'PERCENT']).default('ALL'),
      applyScope: z.enum(['ALL', 'GYM_PLAN', 'COACH_PACKAGE']).default('ALL'),
      search: z.string().trim().max(120).optional(),
      page: z.coerce.number().int().min(1).default(1),
      pageSize: z.coerce.number().int().min(1).max(100).default(20),
    }).safeParse(request.query);

    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Bộ lọc voucher không hợp lệ');
    }

    const { status, discountType, applyScope, search, page, pageSize } = parsed.data;
    const filters = [];
    const values = [];

    if (status !== 'ALL') {
      values.push(status);
      filters.push(`v.status = $${values.length}`);
    }
    if (discountType !== 'ALL') {
      values.push(discountType);
      filters.push(`v.discount_type = $${values.length}`);
    }
    if (applyScope !== 'ALL') {
      values.push(applyScope);
      filters.push(`v.apply_scope = $${values.length}`);
    }
    if (search) {
      values.push(`%${escapeLike(search)}%`);
      const p = `$${values.length}`;
      filters.push(`(v.code ILIKE ${p} ESCAPE '\\' OR v.title ILIKE ${p} ESCAPE '\\')`);
    }

    const whereSql = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    try {
      const [countRes, rowsRes, summaryRes] = await Promise.all([
        database.query(`SELECT count(*)::int AS count FROM vouchers v ${whereSql}`, values),
        database.query(
          `SELECT v.*, mp.name AS target_plan_name
           FROM vouchers v
           LEFT JOIN membership_plans mp ON mp.id = v.target_plan_id
           ${whereSql}
           ORDER BY v.created_at DESC, v.id DESC
           LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
          [...values, pageSize, (page - 1) * pageSize],
        ),
        database.query(
          `SELECT count(*)::int AS total_vouchers,
                  count(*) FILTER (
                    WHERE status = 'ACTIVE'
                      AND (starts_at IS NULL OR starts_at <= now())
                      AND (ends_at IS NULL OR ends_at >= now())
                      AND (max_total_uses IS NULL OR used_count < max_total_uses)
                  )::int AS active_now_count,
                  count(*) FILTER (
                    WHERE status = 'ACTIVE' AND starts_at > now()
                  )::int AS upcoming_count,
                  COALESCE(SUM(used_count), 0)::int AS total_used_count
           FROM vouchers`,
        ),
      ]);

      const totalItems = Number(countRes.rows[0]?.count ?? 0);
      const sum = summaryRes.rows[0] || {};
      return response.json({
        data: rowsRes.rows.map(serializeVoucher),
        summary: {
          totalVouchers: Number(sum.total_vouchers ?? 0),
          activeNowCount: Number(sum.active_now_count ?? 0),
          upcomingCount: Number(sum.upcoming_count ?? 0),
          totalUsedCount: Number(sum.total_used_count ?? 0),
        },
        pagination: {
          page,
          pageSize,
          totalItems,
          totalPages: Math.max(1, Math.ceil(totalItems / pageSize)),
        },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được danh sách voucher');
    }
  });

  router.post('/admin/vouchers', async (request, response) => {
    if (!hasBackofficePermission(request.authUser, 'plans:manage')) {
      return fail(response, 403, 'FORBIDDEN', 'Không có quyền tạo voucher');
    }
    const parsed = voucherPayloadSchema.safeParse(request.body);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', parsed.error.issues[0]?.message || 'Dữ liệu voucher không hợp lệ');
    }
    const v = parsed.data;
    const ruleErr = validateVoucherBusinessRules(v);
    if (ruleErr) return fail(response, 422, 'VALIDATION_ERROR', ruleErr);

    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được cơ sở dữ liệu');
    const id = randomUUID();

    try {
      await client.query('BEGIN');
      if (!await verifyActiveActor(client, request.authUser)) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      if (!await verifyVoucherMedia(client, v.imageMediaId)) {
        await client.query('ROLLBACK');
        return fail(response, 422, 'VALIDATION_ERROR', 'Ảnh voucher không tồn tại hoặc không hợp lệ');
      }

      const maxDiscountAmount = v.discountType === 'PERCENT' ? (v.maxDiscountAmount ?? null) : null;
      await client.query(
        `INSERT INTO vouchers (
           id, code, title, description, image_media_id, discount_type, discount_value,
           max_discount_amount, apply_scope, target_plan_id, target_member_scope,
           min_order_amount, max_total_uses, max_uses_per_member, starts_at, ends_at,
           status, created_by
         ) VALUES (
           $1, $2, $3, $4, $5, $6, $7,
           $8, $9, $10, $11,
           $12, $13, $14, $15, $16,
           $17, $18
         )`,
        [
          id, v.code, v.title, v.description ?? null, v.imageMediaId ?? null, v.discountType, v.discountValue,
          maxDiscountAmount, v.applyScope, v.targetPlanId ?? null, v.targetMemberScope,
          v.minOrderAmount, v.maxTotalUses ?? null, v.maxUsesPerMember, v.startsAt ?? null, v.endsAt ?? null,
          v.status, request.authUser.id,
        ],
      );

      await client.query(
        `INSERT INTO admin_audit_logs (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'VOUCHER_CREATED', 'VOUCHER', $3, $4, $5)`,
        [
          randomUUID(),
          request.authUser.id,
          id,
          `Tạo voucher ${v.code} (${v.title})`,
          JSON.stringify({ code: v.code, discountType: v.discountType, discountValue: v.discountValue }),
        ],
      );

      const created = await fetchVoucherById(client, id);
      await client.query('COMMIT');
      return response.status(201).json({ data: serializeVoucher(created) });
    } catch (error) {
      await client.query('ROLLBACK').catch(() => {});
      if (error.code === '23505') {
        return fail(response, 409, 'VOUCHER_CODE_EXISTS', 'Mã voucher này đã tồn tại trên hệ thống');
      }
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tạo được voucher');
    } finally {
      client.release();
    }
  });

  router.patch('/admin/vouchers/:voucherId', async (request, response) => {
    if (!hasBackofficePermission(request.authUser, 'plans:manage')) {
      return fail(response, 403, 'FORBIDDEN', 'Không có quyền cập nhật voucher');
    }
    if (!uuid.safeParse(request.params.voucherId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã định danh voucher không hợp lệ');
    }
    const parsed = patchVoucherSchema.safeParse(request.body);
    if (!parsed.success || !Object.keys(parsed.data).length) {
      return fail(response, 422, 'VALIDATION_ERROR', parsed.error?.issues[0]?.message || 'Dữ liệu cập nhật voucher không hợp lệ');
    }

    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được cơ sở dữ liệu');

    try {
      await client.query('BEGIN');
      if (!await verifyActiveActor(client, request.authUser)) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const before = await fetchVoucherById(client, request.params.voucherId, true);
      if (!before) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy voucher');
      }

      const patch = parsed.data;
      const merged = {
        code: patch.code ?? before.code,
        title: patch.title ?? before.title,
        description: patch.description === undefined ? before.description : patch.description,
        imageMediaId: patch.imageMediaId === undefined ? before.image_media_id : patch.imageMediaId,
        discountType: patch.discountType ?? before.discount_type,
        discountValue: patch.discountValue ?? Number(before.discount_value),
        maxDiscountAmount: patch.maxDiscountAmount === undefined
          ? (before.max_discount_amount ? Number(before.max_discount_amount) : null)
          : patch.maxDiscountAmount,
        applyScope: patch.applyScope ?? before.apply_scope,
        targetPlanId: patch.targetPlanId === undefined ? before.target_plan_id : patch.targetPlanId,
        targetMemberScope: patch.targetMemberScope ?? before.target_member_scope,
        minOrderAmount: patch.minOrderAmount ?? Number(before.min_order_amount ?? 0),
        maxTotalUses: patch.maxTotalUses === undefined
          ? (before.max_total_uses ? Number(before.max_total_uses) : null)
          : patch.maxTotalUses,
        maxUsesPerMember: patch.maxUsesPerMember ?? Number(before.max_uses_per_member ?? 1),
        startsAt: patch.startsAt === undefined
          ? (before.starts_at ? new Date(before.starts_at).toISOString() : null)
          : patch.startsAt,
        endsAt: patch.endsAt === undefined
          ? (before.ends_at ? new Date(before.ends_at).toISOString() : null)
          : patch.endsAt,
        status: patch.status ?? before.status,
      };

      const ruleErr = validateVoucherBusinessRules(merged);
      if (ruleErr) {
        await client.query('ROLLBACK');
        return fail(response, 422, 'VALIDATION_ERROR', ruleErr);
      }
      if (!await verifyVoucherMedia(client, merged.imageMediaId)) {
        await client.query('ROLLBACK');
        return fail(response, 422, 'VALIDATION_ERROR', 'Ảnh voucher không hợp lệ');
      }

      const isImageChanging = patch.imageMediaId !== undefined && patch.imageMediaId !== before.image_media_id;
      const oldCleanup = isImageChanging && before.image_media_id
        ? await prepareMediaAssetCleanup(client, before.image_media_id, { purpose: 'VOUCHER' })
        : null;

      await client.query(
        `UPDATE vouchers SET
           code = $1, title = $2, description = $3, image_media_id = $4,
           discount_type = $5, discount_value = $6, max_discount_amount = $7,
           apply_scope = $8, target_plan_id = $9, target_member_scope = $10,
           min_order_amount = $11, max_total_uses = $12, max_uses_per_member = $13,
           starts_at = $14, ends_at = $15, status = $16, updated_at = now()
         WHERE id = $17`,
        [
          merged.code, merged.title, merged.description, merged.imageMediaId,
          merged.discountType, merged.discountValue, merged.discountType === 'PERCENT' ? merged.maxDiscountAmount : null,
          merged.applyScope, merged.applyScope === 'COACH_PACKAGE' ? null : merged.targetPlanId, merged.targetMemberScope,
          merged.minOrderAmount, merged.maxTotalUses, merged.maxUsesPerMember,
          merged.startsAt, merged.endsAt, merged.status, before.id,
        ],
      );

      if (oldCleanup) {
        await oldCleanup.deleteDbRow();
      }

      const after = await fetchVoucherById(client, before.id);
      await client.query(
        `INSERT INTO admin_audit_logs (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'VOUCHER_UPDATED', 'VOUCHER', $3, $4, $5)`,
        [
          randomUUID(),
          request.authUser.id,
          before.id,
          `Cập nhật voucher ${after.code}`,
          JSON.stringify({ code: after.code, status: after.status }),
        ],
      );

      await client.query('COMMIT');
      if (oldCleanup) {
        await oldCleanup.removeStorageObjects(imageStorage);
      }
      return response.json({ data: serializeVoucher(after) });
    } catch (error) {
      await client.query('ROLLBACK').catch(() => {});
      if (error.code === '23505') {
        return fail(response, 409, 'VOUCHER_CODE_EXISTS', 'Mã voucher này đã tồn tại trên hệ thống');
      }
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không cập nhật được voucher');
    } finally {
      client.release();
    }
  });

  router.delete('/admin/vouchers/:voucherId', async (request, response) => {
    if (!hasBackofficePermission(request.authUser, 'plans:manage')) {
      return fail(response, 403, 'FORBIDDEN', 'Không có quyền xóa voucher');
    }
    if (!uuid.safeParse(request.params.voucherId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã định danh voucher không hợp lệ');
    }

    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được cơ sở dữ liệu');

    try {
      await client.query('BEGIN');
      if (!await verifyActiveActor(client, request.authUser)) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const existing = await fetchVoucherById(client, request.params.voucherId, true);
      if (!existing) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy voucher');
      }
      if (Number(existing.used_count ?? 0) > 0) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'VOUCHER_ALREADY_USED', 'Voucher đã phát sinh giao dịch nên không thể xóa vĩnh viễn. Hãy chuyển sang trạng thái Lưu trữ.');
      }

      const cleanup = existing.image_media_id
        ? await prepareMediaAssetCleanup(client, existing.image_media_id, { purpose: 'VOUCHER' })
        : null;

      await client.query(`DELETE FROM vouchers WHERE id = $1`, [existing.id]);
      if (cleanup) {
        await cleanup.deleteDbRow();
      }
      await client.query(
        `INSERT INTO admin_audit_logs (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'VOUCHER_DELETED', 'VOUCHER', $3, $4, $5)`,
        [randomUUID(), request.authUser.id, existing.id, `Xóa voucher ${existing.code}`, JSON.stringify({ code: existing.code })],
      );

      await client.query('COMMIT');
      if (cleanup) {
        await cleanup.removeStorageObjects(imageStorage);
      }
      return response.json({ data: { deleted: true, id: existing.id } });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không xóa được voucher');
    } finally {
      client.release();
    }
  });

  return router;
}
