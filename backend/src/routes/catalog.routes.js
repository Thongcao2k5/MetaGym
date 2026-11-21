import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const idSchema = z.uuid();
const text = (max) => z.string().trim().min(1).max(max);
const optionalText = (max) => text(max).nullable().optional();
const url = z.url().max(2000).nullable().optional();
const muscles = z.array(text(80)).max(30).default([]);
const gymSchema = z.strictObject({
  name: text(150), address: text(2000), phone: optionalText(20),
  email: z.email().max(255).nullable().optional(),
  description: optionalText(5000), openingHours: z.record(z.string(), z.unknown()),
  rules: optionalText(5000), coverMediaId: idSchema.nullable().optional(),
}).partial();
const equipmentSchema = z.strictObject({
  name: text(120), category: text(80), targetMuscles: muscles,
  imageMediaId: idSchema.nullable().optional(), description: optionalText(5000),
  usageSteps: z.array(text(2000)).min(1).max(30), safetyNotes: optionalText(5000),
  videoUrl: url, status: z.enum(['ACTIVE', 'HIDDEN']).default('ACTIVE'),
});
const exerciseSchema = z.strictObject({
  equipmentId: idSchema.nullable().optional(), name: text(120),
  description: optionalText(5000), targetMuscles: muscles,
  instructions: text(10000), safetyNotes: optionalText(5000),
  difficulty: z.enum(['BEGINNER', 'INTERMEDIATE', 'ADVANCED']).nullable().optional(),
  videoUrl: url, status: z.enum(['ACTIVE', 'HIDDEN']).default('ACTIVE'),
});
const columns = {
  gym: { name: 'name', address: 'address', phone: 'phone', email: 'email',
    description: 'description', openingHours: 'opening_hours', rules: 'rules',
    coverMediaId: 'cover_media_id' },
  equipment: { name: 'name', category: 'category', targetMuscles: 'target_muscles',
    imageMediaId: 'image_media_id', description: 'description', usageSteps: 'usage_steps',
    safetyNotes: 'safety_notes', videoUrl: 'video_url', status: 'status' },
  exercises: { equipmentId: 'equipment_id', name: 'name', description: 'description',
    targetMuscles: 'target_muscles', instructions: 'instructions',
    safetyNotes: 'safety_notes', difficulty: 'difficulty', videoUrl: 'video_url',
    status: 'status' },
};

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, message, details: {} } });
}

function publicRow(row, mapping) {
  return Object.fromEntries(Object.entries(mapping).map(([key, col]) => [key, row[col]]).concat([['id', row.id]]));
}

function values(data, mapping) {
  return Object.entries(mapping).filter(([key]) => key in data);
}

function serialize(key, value) {
  return ['openingHours', 'usageSteps'].includes(key) ? JSON.stringify(value) : value;
}

async function activeAdmin(client, user) {
  const result = await client.query(
    `SELECT u.id FROM users u WHERE u.id = $1 AND u.role = 'ADMIN' AND u.status = 'ACTIVE'
     AND u.session_version = $2 FOR SHARE`,
    [user.id, user.session_version],
  );
  return result.rows.length === 1;
}

export function createCatalogRouter({ database, jwtSecret }) {
  const router = Router();
  router.get('/gym-profile', async (_request, response) => {
    try {
      const result = await database.query('SELECT * FROM gym_profile WHERE id = 1');
      return result.rows.length ? response.json({ data: publicRow(result.rows[0], columns.gym) })
        : fail(response, 404, 'NOT_FOUND', 'Chưa có thông tin phòng gym');
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được thông tin phòng gym'); }
  });

  for (const [table, basePath, mapping, schema, publicCatalog] of [
    ['equipment', 'equipment', columns.equipment, equipmentSchema, true],
    ['exercises', 'exercises', columns.exercises, exerciseSchema, false],
  ]) {
    if (!publicCatalog) router.use(`/${basePath}`, createAuthentication({ database, jwtSecret }));
    router.get(`/${basePath}`, async (request, response) => {
      const parsed = z.strictObject({
        page: z.coerce.number().int().min(1).default(1),
        pageSize: z.coerce.number().int().min(1).max(100).default(20),
        search: z.string().trim().max(120).optional(),
        category: z.string().trim().max(80).optional(),
      }).safeParse(request.query);
      if (!parsed.success || (table === 'exercises' && parsed.data.category)) {
        return fail(response, 422, 'VALIDATION_ERROR', 'Bộ lọc không hợp lệ');
      }
      const { page, pageSize, search, category } = parsed.data;
      const args = [];
      const isExercise = table === 'exercises';
      const source = isExercise ? 'exercises x LEFT JOIN equipment e ON e.id = x.equipment_id' : table;
      const prefix = isExercise ? 'x.' : '';
      let where = `${prefix}status = 'ACTIVE'`;
      if (search) { args.push(`%${search}%`); where += ` AND ${prefix}name ILIKE $${args.length}`; }
      if (category) { args.push(category); where += ` AND category = $${args.length}`; }
      try {
        const total = await database.query(`SELECT count(*)::int AS count FROM ${source} WHERE ${where}`, args);
        const result = await database.query(
          `SELECT ${isExercise ? 'x.*, e.video_url AS equipment_video_url' : '*'} FROM ${source} WHERE ${where} ORDER BY ${prefix}created_at DESC, ${prefix}id DESC LIMIT $${args.length + 1} OFFSET $${args.length + 2}`,
          [...args, pageSize, (page - 1) * pageSize],
        );
        const totalItems = total.rows[0].count;
        return response.json({ data: result.rows.map((row) => publicRow(
          isExercise ? { ...row, video_url: row.video_url || row.equipment_video_url } : row, mapping)),
          pagination: { page, pageSize, totalItems, totalPages: Math.ceil(totalItems / pageSize) } });
      } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được danh mục'); }
    });
    router.get(`/${basePath}/:itemId`, async (request, response) => {
      if (!idSchema.safeParse(request.params.itemId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã không hợp lệ');
      try {
        const isExercise = table === 'exercises';
        const result = await database.query(isExercise
          ? `SELECT x.*, e.video_url AS equipment_video_url FROM exercises x
             LEFT JOIN equipment e ON e.id = x.equipment_id
             WHERE x.id = $1 AND x.status = 'ACTIVE'`
          : `SELECT * FROM ${table} WHERE id = $1 AND status = 'ACTIVE'`, [request.params.itemId]);
        const row = result.rows[0];
        return row ? response.json({ data: publicRow(
          isExercise ? { ...row, video_url: row.video_url || row.equipment_video_url } : row, mapping) })
          : fail(response, 404, 'NOT_FOUND', 'Không tìm thấy mục');
      } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được mục'); }
    });
    router.use(`/admin/${basePath}`, createAuthentication({ database, jwtSecret }));
    router.use(`/admin/${basePath}`, (request, response, next) =>
      request.authUser.role === 'ADMIN' ? next() : fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị'));
    router.get(`/admin/${basePath}`, async (request, response) => {
      const parsed = z.strictObject({
        page: z.coerce.number().int().min(1).default(1),
        pageSize: z.coerce.number().int().min(1).max(100).default(20),
      }).safeParse(request.query);
      if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Phân trang không hợp lệ');
      const { page, pageSize } = parsed.data;
      try {
        const total = await database.query(`SELECT count(*)::int AS count FROM ${table}`);
        const result = await database.query(
          `SELECT * FROM ${table} ORDER BY created_at DESC, id DESC LIMIT $1 OFFSET $2`,
          [pageSize, (page - 1) * pageSize],
        );
        const totalItems = total.rows[0].count;
        return response.json({ data: result.rows.map((row) => publicRow(row, mapping)),
          pagination: { page, pageSize, totalItems,
            totalPages: Math.ceil(totalItems / pageSize) } });
      } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được danh mục'); }
    });
    router.post(`/admin/${basePath}`, async (request, response) => {
      const parsed = schema.safeParse(request.body);
      if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu không hợp lệ');
      const entries = values(parsed.data, mapping);
      const id = randomUUID();
      const client = await database.connect().catch(() => null);
      if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
      try {
        await client.query('BEGIN');
        if (!await activeAdmin(client, request.authUser)) {
          await client.query('ROLLBACK');
          return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
        }
        await client.query(
          `INSERT INTO ${table} (id, created_by, ${entries.map(([, col]) => col).join(', ')}) VALUES ($1, $2, ${entries.map((_, index) => `$${index + 3}`).join(', ')})`,
          [id, request.authUser.id, ...entries.map(([key]) => serialize(key, parsed.data[key]))],
        );
        await client.query(
          `INSERT INTO admin_audit_logs (id, admin_id, action, entity_type, entity_id, summary, metadata)
           VALUES ($1, $2, $3, $4, $5, 'Catalog item created', $6)`,
          [randomUUID(), request.authUser.id, `${table.toUpperCase()}_CREATED`, table.toUpperCase(), id, JSON.stringify({ name: parsed.data.name })],
        );
        const result = await client.query(`SELECT * FROM ${table} WHERE id = $1`, [id]);
        await client.query('COMMIT');
        return response.status(201).json({ data: publicRow(result.rows[0], mapping) });
      } catch {
        await client.query('ROLLBACK').catch(() => {});
        return fail(response, 422, 'VALIDATION_ERROR', 'Không tạo được mục');
      } finally { client.release(); }
    });
    router.patch(`/admin/${basePath}/:itemId`, async (request, response) => {
      if (!idSchema.safeParse(request.params.itemId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã không hợp lệ');
      const parsed = schema.partial().safeParse(request.body);
      if (!parsed.success || !Object.keys(parsed.data ?? {}).length) return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu không hợp lệ');
      const entries = values(parsed.data, mapping);
      const client = await database.connect().catch(() => null);
      if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
      try {
        await client.query('BEGIN');
        if (!await activeAdmin(client, request.authUser)) {
          await client.query('ROLLBACK');
          return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
        }
        const result = await client.query(
          `UPDATE ${table} SET ${entries.map(([, col], index) => `${col} = $${index + 1}`).join(', ')} WHERE id = $${entries.length + 1} RETURNING *`,
          [...entries.map(([key]) => serialize(key, parsed.data[key])), request.params.itemId],
        );
        if (!result.rows.length) {
          await client.query('ROLLBACK');
          return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy mục');
        }
        await client.query(
          `INSERT INTO admin_audit_logs (id, admin_id, action, entity_type, entity_id, summary, metadata)
           VALUES ($1, $2, $3, $4, $5, 'Catalog item updated', $6)`,
          [randomUUID(), request.authUser.id, `${table.toUpperCase()}_UPDATED`, table.toUpperCase(), request.params.itemId, JSON.stringify({ fields: entries.map(([key]) => key) })],
        );
        await client.query('COMMIT');
        return response.json({ data: publicRow(result.rows[0], mapping) });
      } catch {
        await client.query('ROLLBACK').catch(() => {});
        return fail(response, 422, 'VALIDATION_ERROR', 'Không cập nhật được mục');
      } finally { client.release(); }
    });
  }

  router.use('/admin/gym-profile', createAuthentication({ database, jwtSecret }));
  router.patch('/admin/gym-profile', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    const parsed = gymSchema.safeParse(request.body);
    if (!parsed.success || !Object.keys(parsed.data ?? {}).length) return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu không hợp lệ');
    const entries = values(parsed.data, columns.gym);
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      if (!await activeAdmin(client, request.authUser)) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const result = await client.query(
        `UPDATE gym_profile SET ${entries.map(([, col], index) => `${col} = $${index + 1}`).join(', ')}, updated_by = $${entries.length + 1} WHERE id = 1 RETURNING *`,
        [...entries.map(([key]) => serialize(key, parsed.data[key])), request.authUser.id],
      );
      if (!result.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Chưa có thông tin phòng gym');
      }
      await client.query(
        `INSERT INTO admin_audit_logs (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'GYM_PROFILE_UPDATED', 'GYM_PROFILE', '1', 'Gym profile updated', $3)`,
        [randomUUID(), request.authUser.id, JSON.stringify({ fields: entries.map(([key]) => key) })],
      );
      await client.query('COMMIT');
      return response.json({ data: publicRow(result.rows[0], columns.gym) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 422, 'VALIDATION_ERROR', 'Không cập nhật được phòng gym');
    } finally { client.release(); }
  });
  return router;
}
