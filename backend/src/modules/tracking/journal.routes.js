import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from '../users/users.routes.js';

const uuid = z.uuid();
const measurement = z.number().positive().max(9999.99).nullable().optional();
const fields = z.strictObject({
  notes: z.string().trim().max(5000).nullable().optional(),
  chestCm: measurement, waistCm: measurement, hipsCm: measurement,
  achievements: z.array(z.strictObject({
    title: z.string().trim().min(1).max(150),
    result: z.string().trim().min(1).max(1000),
  })).optional(),
  photoMediaIds: z.array(uuid).max(3)
    .refine((ids) => new Set(ids).size === ids.length).optional(),
});
const paging = z.strictObject({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});
const dateRange = z.strictObject({
  from: z.iso.date().optional(), to: z.iso.date().optional(),
});
const columns = { notes: 'notes', chestCm: 'chest_cm', waistCm: 'waist_cm',
  hipsCm: 'hips_cm', achievements: 'achievements' };

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, message, details: {} } });
}

async function mayWrite(client, memberId) {
  const membership = await client.query(
    `SELECT 1 FROM member_memberships WHERE member_id = $1 AND status = 'ACTIVE'
     AND start_date <= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
     AND end_date >= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
     LIMIT 1 FOR SHARE`, [memberId],
  );
  return membership.rows.length > 0;
}

async function validPhotos(client, memberId, ids) {
  if (!ids.length) return true;
  const photos = await client.query(
    `SELECT id FROM media_assets WHERE id = ANY($1::uuid[]) AND owner_id = $2
     AND purpose = 'PROGRESS_PHOTO' AND status = 'READY' FOR SHARE`,
    [ids, memberId],
  );
  return photos.rows.length === ids.length;
}

async function replacePhotos(client, journalId, memberId, ids) {
  await client.query('DELETE FROM member_journal_photos WHERE journal_id = $1', [journalId]);
  for (const [index, mediaId] of ids.entries()) {
    await client.query(
      `INSERT INTO member_journal_photos (journal_id, member_id, media_id, display_order)
       VALUES ($1, $2, $3, $4)`, [journalId, memberId, mediaId, index + 1],
    );
  }
}

async function decorate(database, rows) {
  if (!rows.length) return [];
  const found = await database.query(
    `SELECT journal_id, media_id FROM member_journal_photos
     WHERE journal_id = ANY($1::uuid[]) ORDER BY journal_id, display_order`,
    [rows.map((row) => row.id)],
  );
  const photos = new Map(rows.map((row) => [row.id, []]));
  for (const row of found.rows) photos.get(row.journal_id).push(row.media_id);
  return rows.map((row) => ({
    id: row.id, journalDate: row.journal_day, notes: row.notes,
    chestCm: row.chest_cm, waistCm: row.waist_cm, hipsCm: row.hips_cm,
    achievements: row.achievements, photoMediaIds: photos.get(row.id),
    createdAt: row.created_at, updatedAt: row.updated_at,
  }));
}

function databaseError(response, error) {
  if (error.code === '23505' && error.constraint === 'uq_member_journal_day') {
    return fail(response, 409, 'JOURNAL_EXISTS', 'Hôm nay đã có nhật ký tập');
  }
  if (error.code === '23505' || error.code === '23503') {
    return fail(response, 422, 'VALIDATION_ERROR', 'Ảnh đã được dùng hoặc không hợp lệ');
  }
  return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không lưu được nhật ký tập');
}

export function createJournalRouter({ database, jwtSecret }) {
  const router = Router();
  router.use('/journal', createAuthentication({ database, jwtSecret }));
  router.use('/journal', (request, response, next) =>
    request.authUser.role === 'MEMBER' ? next()
      : fail(response, 403, 'FORBIDDEN', 'Nhật ký chỉ Member được xem'));

  router.get('/journal', async (request, response) => {
    const parsed = paging.safeParse(request.query);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Phân trang không hợp lệ');
    try {
      const { page, pageSize } = parsed.data;
      const total = await database.query(
        'SELECT count(*)::int AS count FROM member_journal_entries WHERE member_id = $1',
        [request.authUser.id],
      );
      const result = await database.query(
        `SELECT *, journal_date::text AS journal_day
         FROM member_journal_entries WHERE member_id = $1
         ORDER BY journal_date DESC, id DESC LIMIT $2 OFFSET $3`,
        [request.authUser.id, pageSize, (page - 1) * pageSize],
      );
      const totalItems = total.rows[0].count;
      return response.json({ data: await decorate(database, result.rows),
        pagination: { page, pageSize, totalItems,
          totalPages: Math.ceil(totalItems / pageSize) } });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được nhật ký tập'); }
  });

  router.get('/journal/charts', async (request, response) => {
    const parsed = dateRange.safeParse(request.query);
    if (!parsed.success || (parsed.data.from && parsed.data.to &&
      parsed.data.from > parsed.data.to)) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Khoảng ngày không hợp lệ');
    }
    try {
      const result = await database.query(
        `SELECT journal_date::text AS journal_day, chest_cm, waist_cm, hips_cm
         FROM member_journal_entries WHERE member_id = $1
         AND journal_date BETWEEN $2::date AND $3::date
         AND num_nonnulls(chest_cm, waist_cm, hips_cm) > 0
         ORDER BY journal_date`,
        [request.authUser.id, parsed.data.from ?? '0001-01-01',
          parsed.data.to ?? '9999-12-31'],
      );
      return response.json({ data: result.rows.map((row) => ({
        journalDate: row.journal_day, chestCm: row.chest_cm,
        waistCm: row.waist_cm, hipsCm: row.hips_cm,
      })) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được biểu đồ'); }
  });

  router.get('/journal/:id', async (request, response) => {
    if (!uuid.safeParse(request.params.id).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã nhật ký không hợp lệ');
    }
    try {
      const result = await database.query(
        `SELECT *, journal_date::text AS journal_day
         FROM member_journal_entries WHERE id = $1 AND member_id = $2`,
        [request.params.id, request.authUser.id],
      );
      if (!result.rows.length) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy nhật ký');
      return response.json({ data: (await decorate(database, result.rows))[0] });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được nhật ký tập'); }
  });

  router.post('/journal', async (request, response) => {
    const parsed = fields.safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Nhật ký không hợp lệ');
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      if (!await mayWrite(client, request.authUser.id)) {
        await client.query('ROLLBACK');
        return fail(response, 403, 'MEMBERSHIP_REQUIRED', 'Cần gói tập đang hoạt động');
      }
      const photos = parsed.data.photoMediaIds ?? [];
      if (!await validPhotos(client, request.authUser.id, photos)) {
        await client.query('ROLLBACK');
        return fail(response, 422, 'VALIDATION_ERROR', 'Ảnh không hợp lệ');
      }
      const id = randomUUID();
      const result = await client.query(
        `INSERT INTO member_journal_entries
         (id, member_id, notes, chest_cm, waist_cm, hips_cm, achievements)
         VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)
         RETURNING *, journal_date::text AS journal_day`,
        [id, request.authUser.id, parsed.data.notes ?? null,
          parsed.data.chestCm ?? null, parsed.data.waistCm ?? null,
          parsed.data.hipsCm ?? null, JSON.stringify(parsed.data.achievements ?? [])],
      );
      await replacePhotos(client, id, request.authUser.id, photos);
      const data = (await decorate(client, result.rows))[0];
      await client.query('COMMIT');
      return response.status(201).json({ data });
    } catch (error) {
      await client.query('ROLLBACK').catch(() => {});
      return databaseError(response, error);
    } finally { client.release(); }
  });

  router.patch('/journal/:id', async (request, response) => {
    if (!uuid.safeParse(request.params.id).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã nhật ký không hợp lệ');
    }
    const parsed = fields.safeParse(request.body);
    if (!parsed.success || !Object.keys(parsed.data).length) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Nhật ký không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      if (!await mayWrite(client, request.authUser.id)) {
        await client.query('ROLLBACK');
        return fail(response, 403, 'MEMBERSHIP_REQUIRED', 'Cần gói tập đang hoạt động');
      }
      const existing = await client.query(
        `SELECT *, journal_date::text AS journal_day
         FROM member_journal_entries WHERE id = $1 AND member_id = $2 FOR UPDATE`,
        [request.params.id, request.authUser.id],
      );
      if (!existing.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy nhật ký');
      }
      const photos = parsed.data.photoMediaIds;
      if (photos && !await validPhotos(client, request.authUser.id, photos)) {
        await client.query('ROLLBACK');
        return fail(response, 422, 'VALIDATION_ERROR', 'Ảnh không hợp lệ');
      }
      const changes = Object.entries(columns).filter(([key]) => key in parsed.data);
      const values = changes.map(([key]) => key === 'achievements'
        ? JSON.stringify(parsed.data[key]) : parsed.data[key]);
      const result = changes.length ? await client.query(
        `UPDATE member_journal_entries SET ${changes.map(([key, column], index) =>
          `${column} = $${index + 1}${key === 'achievements' ? '::jsonb' : ''}`).join(', ')}
         WHERE id = $${values.length + 1} AND member_id = $${values.length + 2}
         RETURNING *, journal_date::text AS journal_day`,
        [...values, request.params.id, request.authUser.id],
      ) : existing;
      if (photos) await replacePhotos(client, request.params.id, request.authUser.id, photos);
      const data = (await decorate(client, result.rows))[0];
      await client.query('COMMIT');
      return response.json({ data });
    } catch (error) {
      await client.query('ROLLBACK').catch(() => {});
      return databaseError(response, error);
    } finally { client.release(); }
  });

  router.delete('/journal/:id', async (request, response) => {
    if (!uuid.safeParse(request.params.id).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã nhật ký không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      if (!await mayWrite(client, request.authUser.id)) {
        await client.query('ROLLBACK');
        return fail(response, 403, 'MEMBERSHIP_REQUIRED', 'Cần gói tập đang hoạt động');
      }
      const result = await client.query(
        'DELETE FROM member_journal_entries WHERE id = $1 AND member_id = $2 RETURNING id',
        [request.params.id, request.authUser.id],
      );
      if (!result.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy nhật ký');
      }
      await client.query('COMMIT');
      return response.json({ data: { id: request.params.id } });
    } catch (error) {
      await client.query('ROLLBACK').catch(() => {});
      return databaseError(response, error);
    } finally { client.release(); }
  });

  return router;
}
