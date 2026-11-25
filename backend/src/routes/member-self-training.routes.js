import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const date = z.iso.date();
const range = z.strictObject({ from: date, to: date });
const manualExercise = z.strictObject({
  id: z.string().trim().min(1).max(120).optional(),
  name: z.string().trim().min(1).max(120),
  sets: z.number().int().min(1).max(99).optional(),
  reps: z.string().trim().min(1).max(20).optional(),
});
const payload = z.strictObject({
  title: z.string().trim().min(1).max(120),
  startTime: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
  notes: z.string().trim().max(2000),
  exercises: z.array(manualExercise).min(1).max(20).optional(),
  exerciseIds: z.array(z.uuid()).min(1).max(20).refine((ids) =>
    new Set(ids).size === ids.length).optional(),
}).refine((data) => (data.exercises?.length ?? 0) > 0 || (data.exerciseIds?.length ?? 0) > 0);

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, message, details: {} } });
}

function present(row) {
  return {
    id: row.id,
    planDate: row.plan_day,
    title: row.title,
    startTime: row.start_time?.slice(0, 5) ?? null,
    notes: row.notes ?? '',
    exercises: row.exercises,
  };
}

export function createMemberSelfTrainingRouter({ database, jwtSecret }) {
  const router = Router();
  router.use('/member/self-training-days', createAuthentication({ database, jwtSecret }));
  router.use('/member/self-training-days', (request, response, next) =>
    request.authUser.role === 'MEMBER' ? next()
      : fail(response, 403, 'FORBIDDEN', 'Lịch tự tập chỉ dành cho hội viên'));

  router.get('/member/self-training-days', async (request, response) => {
    const parsed = range.safeParse(request.query);
    if (!parsed.success || parsed.data.from > parsed.data.to ||
        (Date.parse(parsed.data.to) - Date.parse(parsed.data.from)) > 62 * 86400000) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Khoảng ngày không hợp lệ');
    }
    try {
      const result = await database.query(
        `SELECT id, plan_date::text AS plan_day, title, start_time::text,
                notes, exercises FROM member_self_training_days
         WHERE member_id = $1 AND plan_date BETWEEN $2 AND $3
         ORDER BY plan_date`,
        [request.authUser.id, parsed.data.from, parsed.data.to],
      );
      return response.json({ data: result.rows.map(present) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được lịch tự tập');
    }
  });

  router.put('/member/self-training-days/:date', async (request, response) => {
    const day = date.safeParse(request.params.date);
    const body = payload.safeParse(request.body);
    if (!day.success || !body.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Kế hoạch không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const today = await client.query(
        "SELECT (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS today",
      );
      if (day.data < today.rows[0].today) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'DAY_LOCKED', 'Không thể sửa lịch của ngày đã qua');
      }
      let exercises;
      if (body.data.exercises?.length) {
        exercises = body.data.exercises.map((item) => ({
          id: item.id || randomUUID(),
          name: item.name,
          ...(item.sets != null ? { sets: item.sets } : {}),
          ...(item.reps ? { reps: item.reps } : {}),
        }));
      } else {
        const ids = body.data.exerciseIds ?? [];
        const found = ids.length ? await client.query(
          `SELECT id, name FROM exercises WHERE id = ANY($1::uuid[])
           AND status = 'ACTIVE' FOR SHARE`, [ids],
        ) : { rows: [] };
        if (found.rows.length !== ids.length) {
          await client.query('ROLLBACK');
          return fail(response, 422, 'VALIDATION_ERROR', 'Có bài tập không còn khả dụng');
        }
        const names = new Map(found.rows.map((row) => [row.id, row.name]));
        exercises = ids.map((id) => ({ id, name: names.get(id) }));
      }
      const saved = await client.query(
        `INSERT INTO member_self_training_days
         (id, member_id, plan_date, title, start_time, notes, exercises)
         SELECT $1, $2, $3, $4, $5, $6, $7::jsonb
         WHERE $3::date >= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
         ON CONFLICT (member_id, plan_date) DO UPDATE SET
           title = EXCLUDED.title, start_time = EXCLUDED.start_time,
           notes = EXCLUDED.notes, exercises = EXCLUDED.exercises,
           updated_at = now()
         WHERE member_self_training_days.plan_date >=
           (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
         RETURNING id, plan_date::text AS plan_day, title,
                   start_time::text, notes, exercises`,
        [randomUUID(), request.authUser.id, day.data, body.data.title,
          body.data.startTime, body.data.notes, JSON.stringify(exercises)],
      );
      if (!saved.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'DAY_LOCKED', 'Không thể sửa lịch của ngày đã qua');
      }
      await client.query('COMMIT');
      return response.json({ data: present(saved.rows[0]) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không lưu được lịch tự tập');
    } finally { client.release(); }
  });

  router.delete('/member/self-training-days/:date', async (request, response) => {
    const day = date.safeParse(request.params.date);
    if (!day.success) return fail(response, 422, 'VALIDATION_ERROR', 'Ngày không hợp lệ');
    try {
      const today = await database.query(
        "SELECT (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS today",
      );
      if (day.data < today.rows[0].today) {
        return fail(response, 409, 'DAY_LOCKED', 'Không thể xóa lịch của ngày đã qua');
      }
      const result = await database.query(
        `DELETE FROM member_self_training_days
         WHERE member_id = $1 AND plan_date = $2 AND plan_date >=
           (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date RETURNING id`,
        [request.authUser.id, day.data],
      );
      return result.rows.length ? response.json({ data: { deleted: true } })
        : fail(response, 404, 'NOT_FOUND', 'Không có kế hoạch có thể xóa');
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không xóa được lịch tự tập');
    }
  });
  return router;
}
