import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { prepareMediaAssetCleanup } from '../media/media-cleanup.js';
import { createAuthentication } from '../users/users.routes.js';
import { DEFAULT_SYSTEM_INFO, SYSTEM_INFO_KEYS } from './system-info-defaults.js';

const uuid = z.uuid();

const sectionSchema = z.strictObject({
  id: z.string().trim().min(1).max(60),
  heading: z.string().trim().min(1, 'Tiêu đề mục không được trống').max(200),
  body: z.string().trim().min(1, 'Nội dung mục không được trống').max(8000),
});

const privacyPolicySchema = z.strictObject({
  title: z.string().trim().min(1).max(150),
  badge: z.string().trim().max(120).default('BẢO VỆ DỮ LIỆU CÁ NHÂN'),
  version: z.string().trim().min(1).max(40),
  effectiveDate: z.string().trim().regex(/^\d{4}-\d{2}-\d{2}$/, 'Ngày hiệu lực phải có định dạng YYYY-MM-DD'),
  contactEmail: z.email().max(255),
  summary: z.string().trim().min(1).max(500),
  sections: z.array(sectionSchema).min(1, 'Cần ít nhất 1 mục nội dung').max(30),
});

const termsOfUseSchema = z.strictObject({
  title: z.string().trim().min(1).max(150),
  subtitle: z.string().trim().min(1).max(250),
  version: z.string().trim().min(1).max(40),
  effectiveDate: z.string().trim().regex(/^\d{4}-\d{2}-\d{2}$/, 'Ngày hiệu lực phải có định dạng YYYY-MM-DD'),
  contactEmail: z.email().max(255),
  sections: z.array(sectionSchema).min(1, 'Cần ít nhất 1 mục nội dung').max(30),
});

const homeIconItemSchema = z.strictObject({
  key: z.string().trim().regex(/^[a-z0-9_]{2,50}$/, 'Mã icon chỉ gồm chữ thường, số và dấu gạch dưới'),
  label: z.string().trim().min(1, 'Nhãn hiển thị không được trống').max(60),
  subtitle: z.string().trim().max(160).default(''),
  roleTarget: z.enum(['MEMBER', 'COACH', 'ALL']).default('MEMBER'),
  route: z.string().trim().min(1).max(120),
  assetFile: z.string().trim().max(120).nullable().optional(),
  mediaId: uuid.nullable().optional(),
  accentColor: z.string().trim().regex(/^#[0-9a-fA-F]{6}$/).default('#FF5E36'),
  sortOrder: z.coerce.number().int().min(1).max(99).default(1),
  enabled: z.boolean().default(true),
});

const homeIconsSchema = z.strictObject({
  items: z.array(homeIconItemSchema).min(1, 'Cần ít nhất 1 icon màn hình chính').max(24),
});

const paymentMethodItemSchema = z.strictObject({
  code: z.string().trim().regex(/^[A-Z0-9_]{2,30}$/, 'Mã phương thức chỉ gồm chữ hoa, số và dấu gạch dưới'),
  name: z.string().trim().min(1, 'Tên phương thức không được trống').max(120),
  channelLabel: z.string().trim().min(1).max(80),
  providerNote: z.string().trim().max(200).default(''),
  minAmount: z.coerce.number().int().min(0).max(1_000_000_000).default(0),
  maxAmount: z.coerce.number().int().min(0).max(1_000_000_000).default(50_000_000),
  feeNote: z.string().trim().max(120).default(''),
  instructions: z.string().trim().max(500).default(''),
  supportsGymPlans: z.boolean().default(true),
  supportsCoachPackages: z.boolean().default(true),
  sortOrder: z.coerce.number().int().min(1).max(99).default(1),
  enabled: z.boolean().default(true),
}).refine((item) => item.maxAmount >= item.minAmount, {
  message: 'Hạn mức tối đa phải lớn hơn hoặc bằng hạn mức tối thiểu',
});

const paymentMethodsSchema = z.strictObject({
  methods: z.array(paymentMethodItemSchema).min(1, 'Cần ít nhất 1 phương thức thanh toán').max(20),
});

function fail(response, status, code, message, details = {}) {
  return response.status(status).json({ error: { code, message, details } });
}

function hydrateHomeIcon(item) {
  const mediaId = item.mediaId || null;
  return {
    ...item,
    mediaId,
    imageUrl: mediaId ? `/api/v1/media/public/${mediaId}?v=${mediaId}` : null,
    thumbnailUrl: mediaId ? `/api/v1/media/public/${mediaId}?size=120&v=${mediaId}` : null,
  };
}

function hydrateHomeIconsPayload(value) {
  const rawItems = Array.isArray(value?.items) ? value.items : DEFAULT_SYSTEM_INFO.home_quick_icons.items;
  return {
    items: [...rawItems]
      .sort((a, b) => Number(a.sortOrder ?? 99) - Number(b.sortOrder ?? 99))
      .map(hydrateHomeIcon),
  };
}

function hydratePaymentMethodsPayload(value) {
  const rawMethods = Array.isArray(value?.methods) ? value.methods : DEFAULT_SYSTEM_INFO.payment_methods.methods;
  return {
    methods: [...rawMethods].sort((a, b) => Number(a.sortOrder ?? 99) - Number(b.sortOrder ?? 99)),
  };
}

async function readSettingsMap(database) {
  const keys = Object.values(SYSTEM_INFO_KEYS);
  const res = await database.query(
    `SELECT key, value, updated_at
     FROM system_settings
     WHERE key = ANY($1::text[])`,
    [keys],
  );
  const map = new Map();
  const updatedAtByKey = {};
  for (const row of res.rows) {
    map.set(row.key, row.value);
    updatedAtByKey[row.key] = row.updated_at || null;
  }
  return {
    privacyPolicy: map.get(SYSTEM_INFO_KEYS.privacyPolicy) || DEFAULT_SYSTEM_INFO.legal_privacy_policy,
    termsOfUse: map.get(SYSTEM_INFO_KEYS.termsOfUse) || DEFAULT_SYSTEM_INFO.legal_terms_of_service,
    homeIcons: hydrateHomeIconsPayload(map.get(SYSTEM_INFO_KEYS.homeIcons)),
    paymentMethods: hydratePaymentMethodsPayload(map.get(SYSTEM_INFO_KEYS.paymentMethods)),
    updatedAtByKey,
  };
}

async function activeAdmin(client, user) {
  const res = await client.query(
    `SELECT id FROM users WHERE id = $1 AND role = 'ADMIN' AND status = 'ACTIVE' AND session_version = $2 FOR SHARE`,
    [user.id, user.session_version],
  );
  return res.rows.length === 1;
}

async function verifySystemIconMedia(client, mediaIds) {
  const unique = [...new Set(mediaIds.filter(Boolean))];
  if (!unique.length) return true;
  const res = await client.query(
    `SELECT id FROM media_assets
     WHERE id = ANY($1::uuid[]) AND status = 'READY' AND access_scope = 'PUBLIC' AND purpose = 'SYSTEM_ICON'`,
    [unique],
  );
  return res.rows.length === unique.length;
}

async function saveSystemSetting({
  database,
  imageStorage,
  adminUser,
  key,
  value,
  auditSummary,
  previousMediaIds = [],
  nextMediaIds = [],
}) {
  const client = await database.connect().catch(() => null);
  if (!client) throw Object.assign(new Error('Không kết nối được cơ sở dữ liệu'), { status: 500, code: 'INTERNAL_SERVER_ERROR' });

  const nextSet = new Set(nextMediaIds.filter(Boolean));
  const staleMediaIds = [...new Set(previousMediaIds.filter((id) => id && !nextSet.has(id)))];
  const cleanups = [];

  try {
    await client.query('BEGIN');
    if (!await activeAdmin(client, adminUser)) {
      await client.query('ROLLBACK');
      throw Object.assign(new Error('Phiên đăng nhập đã hết hiệu lực'), { status: 401, code: 'UNAUTHORIZED' });
    }
    if (!await verifySystemIconMedia(client, [...nextSet])) {
      await client.query('ROLLBACK');
      throw Object.assign(new Error('Ảnh icon màn hình chính không hợp lệ'), { status: 422, code: 'VALIDATION_ERROR' });
    }

    const beforeRes = await client.query(`SELECT value FROM system_settings WHERE key = $1 FOR UPDATE`, [key]);
    const beforeValue = beforeRes.rows[0]?.value ?? DEFAULT_SYSTEM_INFO[key] ?? null;

    const savedRes = await client.query(
      `INSERT INTO system_settings (key, value, updated_by)
       VALUES ($1, $2::jsonb, $3)
       ON CONFLICT (key) DO UPDATE
         SET value = EXCLUDED.value,
             updated_by = EXCLUDED.updated_by,
             updated_at = now()
       RETURNING value, updated_at`,
      [key, JSON.stringify(value), adminUser.id],
    );

    for (const staleId of staleMediaIds) {
      const cleanup = await prepareMediaAssetCleanup(client, staleId, { purpose: 'SYSTEM_ICON' });
      await cleanup.deleteDbRow();
      cleanups.push(cleanup);
    }

    await client.query(
      `INSERT INTO admin_audit_logs (id, admin_id, action, entity_type, entity_id, summary, metadata)
       VALUES ($1, $2, 'SYSTEM_INFO_UPDATED', 'SYSTEM_SETTINGS', $3, $4, $5)`,
      [
        randomUUID(),
        adminUser.id,
        key,
        auditSummary,
        JSON.stringify({ key, before: beforeValue, after: value }),
      ],
    );

    await client.query('COMMIT');
    await Promise.all(cleanups.map((cleanup) => cleanup.removeStorageObjects(imageStorage)));
    return savedRes.rows[0];
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}

export function createSystemInfoRouter({ database, jwtSecret, imageStorage }) {
  const router = Router();
  const authenticate = createAuthentication({ database, jwtSecret });
  const requireAdmin = (request, response, next) => (
    request.authUser.role === 'ADMIN'
      ? next()
      : fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị')
  );

  // Public system information endpoints for mobile & landing clients
  router.get('/system-info/privacy-policy', async (_request, response) => {
    try {
      const data = await readSettingsMap(database);
      return response.json({ data: data.privacyPolicy });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được chính sách bảo mật');
    }
  });

  router.get('/system-info/terms-of-use', async (_request, response) => {
    try {
      const data = await readSettingsMap(database);
      return response.json({ data: data.termsOfUse });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được điều khoản sử dụng');
    }
  });

  router.get('/system-info/home-icons', async (_request, response) => {
    try {
      const data = await readSettingsMap(database);
      return response.json({
        data: { items: data.homeIcons.items.filter((item) => item.enabled !== false) },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được bộ icon màn hình chính');
    }
  });

  router.get('/system-info/payment-methods', async (_request, response) => {
    try {
      const data = await readSettingsMap(database);
      return response.json({
        data: { methods: data.paymentMethods.methods.filter((item) => item.enabled !== false) },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được thông tin thanh toán');
    }
  });

  // Admin endpoints
  router.use('/admin/system-info', authenticate, requireAdmin);

  router.get('/admin/system-info', async (_request, response) => {
    try {
      const data = await readSettingsMap(database);
      return response.json({ data });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được thông tin hệ thống');
    }
  });

  router.put('/admin/system-info/privacy-policy', async (request, response) => {
    const parsed = privacyPolicySchema.safeParse(request.body);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', parsed.error.issues[0]?.message || 'Dữ liệu chính sách bảo mật không hợp lệ');
    }
    try {
      const saved = await saveSystemSetting({
        database,
        imageStorage,
        adminUser: request.authUser,
        key: SYSTEM_INFO_KEYS.privacyPolicy,
        value: parsed.data,
        auditSummary: `Cập nhật Chính sách bảo mật (v${parsed.data.version})`,
      });
      return response.json({ data: saved.value, updatedAt: saved.updated_at });
    } catch (err) {
      return fail(response, err.status || 500, err.code || 'INTERNAL_SERVER_ERROR', err.message || 'Không lưu được chính sách bảo mật');
    }
  });

  router.put('/admin/system-info/terms-of-use', async (request, response) => {
    const parsed = termsOfUseSchema.safeParse(request.body);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', parsed.error.issues[0]?.message || 'Dữ liệu điều khoản sử dụng không hợp lệ');
    }
    try {
      const saved = await saveSystemSetting({
        database,
        imageStorage,
        adminUser: request.authUser,
        key: SYSTEM_INFO_KEYS.termsOfUse,
        value: parsed.data,
        auditSummary: `Cập nhật Điều khoản sử dụng (v${parsed.data.version})`,
      });
      return response.json({ data: saved.value, updatedAt: saved.updated_at });
    } catch (err) {
      return fail(response, err.status || 500, err.code || 'INTERNAL_SERVER_ERROR', err.message || 'Không lưu được điều khoản sử dụng');
    }
  });

  router.put('/admin/system-info/home-icons', async (request, response) => {
    const parsed = homeIconsSchema.safeParse(request.body);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', parsed.error.issues[0]?.message || 'Dữ liệu bộ icon màn hình chính không hợp lệ');
    }
    const keys = parsed.data.items.map((item) => item.key);
    if (new Set(keys).size !== keys.length) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã icon (key) không được trùng nhau');
    }
    try {
      const current = await readSettingsMap(database);
      const previousMediaIds = current.homeIcons.items.map((item) => item.mediaId);
      const nextMediaIds = parsed.data.items.map((item) => item.mediaId);
      const saved = await saveSystemSetting({
        database,
        imageStorage,
        adminUser: request.authUser,
        key: SYSTEM_INFO_KEYS.homeIcons,
        value: parsed.data,
        auditSummary: `Cập nhật Bộ icon màn hình chính (${parsed.data.items.length} mục)`,
        previousMediaIds,
        nextMediaIds,
      });
      return response.json({ data: hydrateHomeIconsPayload(saved.value), updatedAt: saved.updated_at });
    } catch (err) {
      return fail(response, err.status || 500, err.code || 'INTERNAL_SERVER_ERROR', err.message || 'Không lưu được bộ icon màn hình chính');
    }
  });

  router.put('/admin/system-info/payment-methods', async (request, response) => {
    const parsed = paymentMethodsSchema.safeParse(request.body);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', parsed.error.issues[0]?.message || 'Dữ liệu phương thức thanh toán không hợp lệ');
    }
    const codes = parsed.data.methods.map((item) => item.code);
    if (new Set(codes).size !== codes.length) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã phương thức thanh toán không được trùng nhau');
    }
    try {
      const saved = await saveSystemSetting({
        database,
        imageStorage,
        adminUser: request.authUser,
        key: SYSTEM_INFO_KEYS.paymentMethods,
        value: parsed.data,
        auditSummary: `Cập nhật Thông tin phương thức thanh toán (${parsed.data.methods.length} kênh)`,
      });
      return response.json({ data: hydratePaymentMethodsPayload(saved.value), updatedAt: saved.updated_at });
    } catch (err) {
      return fail(response, err.status || 500, err.code || 'INTERNAL_SERVER_ERROR', err.message || 'Không lưu được thông tin thanh toán');
    }
  });

  return router;
}
