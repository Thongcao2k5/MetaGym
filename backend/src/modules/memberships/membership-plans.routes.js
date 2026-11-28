import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { prepareMediaAssetCleanup } from '../media/media-cleanup.js';
import { createAuthentication } from '../users/users.routes.js';

const uuid = z.uuid();
const CARD_TIERS = ['BRONZE', 'SILVER', 'GOLD', 'DIAMOND'];
const highlightItem = z.string().trim().min(1, 'Dòng thông tin không được để trống').max(120, 'Mỗi dòng thông tin tối đa 120 ký tự');
const saleTimestamp = z.iso.datetime({ offset: true }).nullable().optional();
const createSchema = z.strictObject({
  name: z.string().trim().min(1).max(100),
  description: z.string().nullable().optional(),
  price: z.number().int().min(0).max(Number.MAX_SAFE_INTEGER),
  durationDays: z.number().int().min(1).max(3650),
  status: z.enum(['ACTIVE', 'INACTIVE']).default('ACTIVE'),
  cardTier: z.enum(CARD_TIERS).nullable().optional(),
  frontMediaId: uuid.nullable().optional(),
  backMediaId: uuid.nullable().optional(),
  cardHighlights: z.array(highlightItem).max(3, 'Mỗi thẻ chỉ chứa tối đa 3 dòng thông tin').optional(),
  salesStartAt: saleTimestamp,
  salesEndAt: saleTimestamp,
});
const patchSchema = createSchema.partial();

/**
 * Evaluates whether a Gym membership plan is currently within its active sale window.
 */
export function evaluatePlanSaleWindow(row, nowMs = Date.now()) {
  if (!row || row.status !== 'ACTIVE') {
    return {
      salePhase: 'INACTIVE',
      isOnSale: false,
      reasonCode: 'NOT_FOUND',
      reasonMessage: 'Không tìm thấy gói tập đang bán',
    };
  }
  const startMs = row.sales_start_at ? Date.parse(row.sales_start_at) : null;
  const endMs = row.sales_end_at ? Date.parse(row.sales_end_at) : null;
  if (Number.isFinite(startMs) && nowMs < startMs) {
    return {
      salePhase: 'UPCOMING',
      isOnSale: false,
      reasonCode: 'PLAN_OUTSIDE_SALE_WINDOW',
      reasonMessage: 'Gói tập chưa tới thời gian mở bán',
    };
  }
  if (Number.isFinite(endMs) && nowMs > endMs) {
    return {
      salePhase: 'ENDED',
      isOnSale: false,
      reasonCode: 'PLAN_OUTSIDE_SALE_WINDOW',
      reasonMessage: 'Gói tập đã hết thời gian mở bán',
    };
  }
  return {
    salePhase: 'ON_SALE',
    isOnSale: true,
    reasonCode: null,
    reasonMessage: null,
  };
}

function validSaleRange(startValue, endValue) {
  if (!startValue || !endValue) return true;
  return Date.parse(endValue) >= Date.parse(startValue);
}

function error(response, status, code, message) {
  return response.status(status).json({ error: { code, details: {}, message } });
}

function escapeLike(value) {
  return value.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
}

function publicPlan(row) {
  const frontMediaId = row.front_media_id ?? null;
  const backMediaId = row.back_media_id ?? null;
  const sale = evaluatePlanSaleWindow(row);
  return {
    id: row.id,
    name: row.name,
    description: row.description,
    price: Number(row.price),
    durationDays: row.duration_days,
    status: row.status,
    salesStartAt: row.sales_start_at ? new Date(row.sales_start_at).toISOString() : null,
    salesEndAt: row.sales_end_at ? new Date(row.sales_end_at).toISOString() : null,
    salePhase: sale.salePhase,
    isOnSale: sale.isOnSale,
    cardTier: row.card_tier ?? null,
    frontMediaId,
    backMediaId,
    frontImageUrl: frontMediaId ? `/api/v1/media/public/${frontMediaId}?v=${frontMediaId}` : null,
    frontThumbnailUrl: frontMediaId ? `/api/v1/media/public/${frontMediaId}?size=120&v=${frontMediaId}` : null,
    backImageUrl: backMediaId ? `/api/v1/media/public/${backMediaId}?v=${backMediaId}` : null,
    backThumbnailUrl: backMediaId ? `/api/v1/media/public/${backMediaId}?size=120&v=${backMediaId}` : null,
    cardHighlights: Array.isArray(row.card_highlights) ? row.card_highlights : [],
    ...(row.active_membership_count !== undefined
      ? { activeMembershipCount: Number(row.active_membership_count) }
      : {}),
    ...(row.scheduled_membership_count !== undefined
      ? { scheduledMembershipCount: Number(row.scheduled_membership_count) }
      : {}),
  };
}

async function planById(database, id, lock = false) {
  const result = await database.query(
    `SELECT id, name, description, price, duration_days, status,
            sales_start_at, sales_end_at,
            card_tier, front_media_id, back_media_id, card_highlights
     FROM membership_plans
     WHERE id = $1 ${lock ? 'FOR UPDATE' : ''}`, [id],
  );
  return result.rows[0];
}

async function verifyPackageMedia(client, mediaId) {
  if (!mediaId) return true;
  const res = await client.query(
    `SELECT id FROM media_assets
     WHERE id = $1 AND status = 'READY' AND access_scope = 'PUBLIC' AND purpose = 'PACKAGE'`,
    [mediaId],
  );
  return res.rows.length === 1;
}

async function isPackageMediaReferencedElsewhere(client, mediaId) {
  const res = await client.query(
    `SELECT 1 FROM membership_plans WHERE front_media_id = $1 OR back_media_id = $1 LIMIT 1`,
    [mediaId],
  );
  return res.rows.length > 0;
}

export function createMembershipPlansRouter({ database, jwtSecret, imageStorage }) {
  const router = Router();
  router.get('/membership-plans', async (request, response) => {
    const parsed = z.strictObject({
      page: z.coerce.number().int().min(1).default(1),
      pageSize: z.coerce.number().int().min(1).max(100).default(20),
    }).safeParse(request.query);
    if (!parsed.success) return error(response, 422, 'VALIDATION_ERROR', 'Bộ lọc không hợp lệ');
    const { page, pageSize } = parsed.data;
    const activeSaleSql = `status = 'ACTIVE'
      AND (sales_start_at IS NULL OR sales_start_at <= now())
      AND (sales_end_at IS NULL OR sales_end_at >= now())`;
    try {
      const total = await database.query(
        `SELECT count(*)::int AS count FROM membership_plans WHERE ${activeSaleSql}`,
      );
      const result = await database.query(
        `SELECT id, name, description, price, duration_days, status,
                sales_start_at, sales_end_at,
                card_tier, front_media_id, back_media_id, card_highlights
         FROM membership_plans WHERE ${activeSaleSql}
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
      status: z.enum(['ACTIVE', 'INACTIVE']).optional(),
      onSaleNow: z.enum(['true', 'false']).optional(),
      search: z.string().trim().max(120).optional(),
      page: z.coerce.number().int().min(1).default(1),
      pageSize: z.coerce.number().int().min(1).max(100).default(20),
    }).safeParse(request.query);
    if (!parsed.success) return error(response, 422, 'VALIDATION_ERROR', 'Bộ lọc không hợp lệ');
    const { status, onSaleNow, search, page, pageSize } = parsed.data;
    const filters = [];
    const values = [];
    if (status) {
      values.push(status);
      filters.push(`p.status = $${values.length}`);
    }
    if (onSaleNow === 'true') {
      filters.push(`p.status = 'ACTIVE' AND (p.sales_start_at IS NULL OR p.sales_start_at <= now()) AND (p.sales_end_at IS NULL OR p.sales_end_at >= now())`);
    }
    if (search) {
      values.push(`%${escapeLike(search)}%`);
      const param = `$${values.length}`;
      filters.push(`(p.name ILIKE ${param} ESCAPE '\\' OR COALESCE(p.description, '') ILIKE ${param} ESCAPE '\\')`);
    }
    const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    try {
      const total = await database.query(
        `SELECT count(*)::int AS count FROM membership_plans p ${whereClause}`,
        values,
      );
      const result = await database.query(
        `SELECT p.id, p.name, p.description, p.price, p.duration_days, p.status,
                p.sales_start_at, p.sales_end_at,
                p.card_tier, p.front_media_id, p.back_media_id, p.card_highlights,
                (SELECT count(*)::int FROM member_memberships m
                 WHERE m.plan_id = p.id AND m.status = 'ACTIVE') AS active_membership_count,
                (SELECT count(*)::int FROM member_memberships m
                 WHERE m.plan_id = p.id AND m.status = 'SCHEDULED') AS scheduled_membership_count
         FROM membership_plans p
         ${whereClause}
         ORDER BY p.created_at DESC, p.id DESC
         LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
        [...values, pageSize, (page - 1) * pageSize],
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
    const p = parsed.data;
    if (!validSaleRange(p.salesStartAt, p.salesEndAt)) {
      return error(response, 422, 'VALIDATION_ERROR', 'Thời điểm kết thúc mở bán phải sau hoặc bằng thời điểm bắt đầu');
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
      if (!await verifyPackageMedia(client, p.frontMediaId) || !await verifyPackageMedia(client, p.backMediaId)) {
        await client.query('ROLLBACK');
        return error(response, 422, 'VALIDATION_ERROR', 'Ảnh thẻ gói tập không hợp lệ');
      }
      const id = randomUUID();
      await client.query(
        `INSERT INTO membership_plans
         (id, name, description, price, duration_days, status, created_by,
          sales_start_at, sales_end_at, card_tier, front_media_id, back_media_id, card_highlights)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`,
        [
          id,
          p.name,
          p.description ?? null,
          p.price,
          p.durationDays,
          p.status,
          request.authUser.id,
          p.salesStartAt ?? null,
          p.salesEndAt ?? null,
          p.cardTier ?? null,
          p.frontMediaId ?? null,
          p.backMediaId ?? null,
          p.cardHighlights ?? [],
        ],
      );
      await client.query(
        `INSERT INTO admin_audit_logs
         (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'MEMBERSHIP_PLAN_CREATED', 'MEMBERSHIP_PLAN', $3, $4, $5)`,
        [randomUUID(), request.authUser.id, id, `Tạo gói Gym: ${p.name}`, JSON.stringify({ after: p })],
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
      const effectiveStart = 'salesStartAt' in parsed.data ? parsed.data.salesStartAt : before.sales_start_at;
      const effectiveEnd = 'salesEndAt' in parsed.data ? parsed.data.salesEndAt : before.sales_end_at;
      if (!validSaleRange(effectiveStart, effectiveEnd)) {
        await client.query('ROLLBACK');
        return error(response, 422, 'VALIDATION_ERROR', 'Thời điểm kết thúc mở bán phải sau hoặc bằng thời điểm bắt đầu');
      }
      if (('frontMediaId' in parsed.data && !await verifyPackageMedia(client, parsed.data.frontMediaId))
        || ('backMediaId' in parsed.data && !await verifyPackageMedia(client, parsed.data.backMediaId))) {
        await client.query('ROLLBACK');
        return error(response, 422, 'VALIDATION_ERROR', 'Ảnh thẻ gói tập không hợp lệ');
      }

      const staleMediaIds = [];
      if ('frontMediaId' in parsed.data && before.front_media_id && parsed.data.frontMediaId !== before.front_media_id) {
        staleMediaIds.push(before.front_media_id);
      }
      if ('backMediaId' in parsed.data && before.back_media_id && parsed.data.backMediaId !== before.back_media_id) {
        staleMediaIds.push(before.back_media_id);
      }

      const fields = Object.entries({
        name: 'name',
        description: 'description',
        price: 'price',
        durationDays: 'duration_days',
        status: 'status',
        salesStartAt: 'sales_start_at',
        salesEndAt: 'sales_end_at',
        cardTier: 'card_tier',
        frontMediaId: 'front_media_id',
        backMediaId: 'back_media_id',
        cardHighlights: 'card_highlights',
      }).filter(([key]) => key in parsed.data);
      await client.query(
        `UPDATE membership_plans SET ${fields.map(([, col], index) => `${col} = $${index + 1}`).join(', ')}
         WHERE id = $${fields.length + 1}`,
        [...fields.map(([key]) => parsed.data[key]), before.id],
      );

      const cleanups = [];
      for (const oldMediaId of [...new Set(staleMediaIds)]) {
        const cleanup = await prepareMediaAssetCleanup(client, oldMediaId, {
          purpose: 'PACKAGE',
          refCheck: isPackageMediaReferencedElsewhere,
        });
        await cleanup.deleteDbRow();
        cleanups.push(cleanup);
      }

      const after = await planById(client, before.id);
      await client.query(
        `INSERT INTO admin_audit_logs
         (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'MEMBERSHIP_PLAN_UPDATED', 'MEMBERSHIP_PLAN', $3, $4, $5)`,
        [
          randomUUID(),
          request.authUser.id,
          before.id,
          `Cập nhật gói Gym: ${after.name}`,
          JSON.stringify({ before: publicPlan(before), after: publicPlan(after) }),
        ],
      );
      await client.query('COMMIT');
      await Promise.all(cleanups.map((cleanup) => cleanup.removeStorageObjects(imageStorage)));
      return response.json({ data: publicPlan(after) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return error(response, 500, 'INTERNAL_SERVER_ERROR', 'Không cập nhật được gói tập');
    } finally { client.release(); }
  });
  return router;
}
