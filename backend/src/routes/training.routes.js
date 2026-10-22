import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();
const date = z.iso.date();
const title = z.string().trim().min(1).max(150);
const exercise = z.strictObject({
  exerciseId: uuid, displayOrder: z.number().int().min(1).max(32767),
  sets: z.number().int().min(1).max(32767).nullable().optional(),
  reps: z.string().trim().min(1).max(50).nullable().optional(),
  durationSeconds: z.number().int().positive().nullable().optional(),
  restSeconds: z.number().int().min(0).nullable().optional(),
  weightGuidance: z.string().trim().max(100).nullable().optional(),
  notes: z.string().trim().max(2000).nullable().optional(),
}).refine((value) => value.reps || value.durationSeconds,
  'Cần số lần lặp hoặc thời lượng');
const day = z.strictObject({
  dayNumber: z.number().int().min(1).max(32767),
  title: z.string().trim().min(1).max(120),
  notes: z.string().trim().max(2000).nullable().optional(),
  exercises: z.array(exercise).max(50),
});
const planFields = {
  title, goal: z.string().trim().max(5000).nullable().optional(),
  startDate: date.nullable().optional(), endDate: date.nullable().optional(),
  days: z.array(day).min(1).max(30),
};
const planSchema = z.strictObject(planFields).refine(
  (value) => !value.startDate || !value.endDate || value.endDate >= value.startDate,
  'Ngày kết thúc phải sau ngày bắt đầu');
const planPatchSchema = z.strictObject(planFields).partial();
const guideSchema = z.strictObject({
  title, content: z.string().trim().min(1).max(20000),
});

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, message, details: {} } });
}

function planView(row, days) {
  return { id: row.id, relationshipId: row.relationship_id, memberId: row.member_id,
    coachId: row.coach_id, title: row.title, goal: row.goal,
    startDate: row.start_date, endDate: row.end_date,
    version: row.version, status: row.status, publishedAt: row.published_at,
    archivedAt: row.archived_at, days };
}

function guideView(row) {
  return { id: row.id, relationshipId: row.relationship_id,
    memberId: row.member_id, coachId: row.coach_id,
    title: row.title, content: row.content, version: row.version,
    status: row.status, publishedAt: row.published_at, archivedAt: row.archived_at };
}

async function loadPlan(database, id) {
  const found = await database.query('SELECT * FROM training_plans WHERE id = $1', [id]);
  if (!found.rows.length) return null;
  const rows = await database.query(
    `SELECT d.id AS day_id, d.day_number, d.title AS day_title, d.notes AS day_notes,
            e.id AS item_id, e.exercise_id, e.exercise_name_snapshot,
            e.instructions_snapshot, e.safety_notes_snapshot, e.display_order,
            e.sets, e.reps, e.duration_seconds, e.rest_seconds,
            e.weight_guidance, e.notes AS item_notes
     FROM training_plan_days d LEFT JOIN training_plan_exercises e ON e.plan_day_id = d.id
     WHERE d.plan_id = $1 ORDER BY d.day_number, e.display_order`, [id],
  );
  const days = [];
  for (const row of rows.rows) {
    let current = days.at(-1);
    if (current?.id !== row.day_id) {
      current = { id: row.day_id, dayNumber: row.day_number,
        title: row.day_title, notes: row.day_notes, exercises: [] };
      days.push(current);
    }
    if (row.item_id) current.exercises.push({
      id: row.item_id, exerciseId: row.exercise_id,
      exerciseName: row.exercise_name_snapshot,
      instructions: row.instructions_snapshot,
      safetyNotes: row.safety_notes_snapshot,
      displayOrder: row.display_order, sets: row.sets, reps: row.reps,
      durationSeconds: row.duration_seconds, restSeconds: row.rest_seconds,
      weightGuidance: row.weight_guidance, notes: row.item_notes,
    });
  }
  return planView(found.rows[0], days);
}

async function activeRelationship(client, coachId, memberId, lock = false) {
  const found = await client.query(
    `SELECT id FROM coach_relationships WHERE coach_id = $1 AND member_id = $2
     AND status = 'ACTIVE' ${lock ? 'FOR UPDATE' : ''}`,
    [coachId, memberId],
  );
  return found.rows[0];
}

async function replaceDays(client, planId, days) {
  await client.query(
    `DELETE FROM training_plan_exercises WHERE plan_day_id IN
     (SELECT id FROM training_plan_days WHERE plan_id = $1)`, [planId],
  );
  await client.query('DELETE FROM training_plan_days WHERE plan_id = $1', [planId]);
  for (const item of days) {
    const dayId = randomUUID();
    await client.query(
      `INSERT INTO training_plan_days (id, plan_id, day_number, title, notes)
       VALUES ($1, $2, $3, $4, $5)`,
      [dayId, planId, item.dayNumber, item.title, item.notes ?? null],
    );
    for (const detail of item.exercises) {
      const catalog = await client.query(
        `SELECT name, instructions, safety_notes FROM exercises
         WHERE id = $1 AND status = 'ACTIVE'`, [detail.exerciseId],
      );
      if (!catalog.rows.length) throw new Error('INVALID_EXERCISE');
      await client.query(
        `INSERT INTO training_plan_exercises
         (id, plan_day_id, exercise_id, exercise_name_snapshot,
          instructions_snapshot, safety_notes_snapshot, display_order,
          sets, reps, duration_seconds, rest_seconds, weight_guidance, notes)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`,
        [randomUUID(), dayId, detail.exerciseId, catalog.rows[0].name,
          catalog.rows[0].instructions, catalog.rows[0].safety_notes,
          detail.displayOrder, detail.sets ?? null, detail.reps ?? null,
          detail.durationSeconds ?? null, detail.restSeconds ?? null,
          detail.weightGuidance ?? null, detail.notes ?? null],
      );
    }
  }
}

export function createTrainingRouter({ database, jwtSecret }) {
  const router = Router();
  router.use(createAuthentication({ database, jwtSecret }));

  router.get('/training-plans/me/active', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem');
    try {
      const found = await database.query(
        `SELECT id FROM training_plans WHERE member_id = $1 AND status = 'ACTIVE'`,
        [request.authUser.id],
      );
      return response.json({ data: found.rows.length ? await loadPlan(database, found.rows[0].id) : null });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được giáo trình'); }
  });

  router.get('/training-plans/me/history', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem');
    try {
      const result = await database.query(
        `SELECT * FROM training_plans WHERE member_id = $1 AND status <> 'DRAFT'
         ORDER BY version DESC`, [request.authUser.id],
      );
      return response.json({ data: result.rows.map((row) => planView(row, undefined)) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được giáo trình'); }
  });

  router.get('/training-plans/:planId', async (request, response) => {
    if (!uuid.safeParse(request.params.planId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã giáo trình không hợp lệ');
    try {
      const found = await database.query('SELECT * FROM training_plans WHERE id = $1', [request.params.planId]);
      const row = found.rows[0];
      const ownPublished = row && request.authUser.role === 'MEMBER' &&
        row.member_id === request.authUser.id && row.status !== 'DRAFT';
      const currentCoach = row && request.authUser.role === 'COACH' &&
        row.coach_id === request.authUser.id && (await database.query(
          `SELECT 1 FROM coach_relationships WHERE id = $1 AND coach_id = $2
           AND status IN ('ACTIVE', 'PAUSED')`,
          [row.relationship_id, request.authUser.id],
        )).rows.length > 0;
      if (!ownPublished && !currentCoach) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy giáo trình');
      }
      return response.json({ data: await loadPlan(database, row.id) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được giáo trình'); }
  });

  router.get('/coach/members/:memberId/training-plans', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được xem');
    if (!uuid.safeParse(request.params.memberId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã Member không hợp lệ');
    try {
      const related = await database.query(
        `SELECT id FROM coach_relationships WHERE member_id = $1 AND coach_id = $2
         AND status IN ('ACTIVE', 'PAUSED') LIMIT 1`,
        [request.params.memberId, request.authUser.id],
      );
      if (!related.rows.length) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy Member');
      const result = await database.query(
        `SELECT * FROM training_plans WHERE relationship_id = $1 ORDER BY version DESC`,
        [related.rows[0].id],
      );
      return response.json({ data: result.rows.map((row) => planView(row, undefined)) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được giáo trình'); }
  });

  router.post('/coach/members/:memberId/training-plans', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được tạo');
    if (!uuid.safeParse(request.params.memberId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã Member không hợp lệ');
    const parsed = planSchema.safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Giáo trình không hợp lệ');
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [request.params.memberId]);
      const relationship = await activeRelationship(client, request.authUser.id, request.params.memberId, true);
      if (!relationship) {
        await client.query('ROLLBACK');
        return fail(response, 403, 'RELATIONSHIP_REQUIRED', 'Quan hệ Coach–Member không hoạt động');
      }
      const version = await client.query(
        `SELECT coalesce(max(version), 0)::int + 1 AS next FROM training_plans WHERE member_id = $1`,
        [request.params.memberId],
      );
      const id = randomUUID();
      const data = parsed.data;
      await client.query(
        `INSERT INTO training_plans
         (id, relationship_id, member_id, coach_id, title, goal, start_date, end_date, version)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        [id, relationship.id, request.params.memberId, request.authUser.id,
          data.title, data.goal ?? null, data.startDate ?? null,
          data.endDate ?? null, version.rows[0].next],
      );
      await replaceDays(client, id, data.days);
      await client.query('COMMIT');
      return response.status(201).json({ data: await loadPlan(database, id) });
    } catch (error) {
      await client.query('ROLLBACK').catch(() => {});
      return error.message === 'INVALID_EXERCISE' || error.code === '23505'
        ? fail(response, 422, 'VALIDATION_ERROR', 'Ngày tập hoặc bài tập không hợp lệ')
        : fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tạo được giáo trình');
    } finally { client.release(); }
  });

  router.patch('/coach/training-plans/:planId', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được sửa');
    if (!uuid.safeParse(request.params.planId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã giáo trình không hợp lệ');
    const parsed = planPatchSchema.safeParse(request.body);
    if (!parsed.success || !Object.keys(parsed.data ?? {}).length) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Giáo trình không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const found = await client.query(
        `SELECT * FROM training_plans WHERE id = $1 AND coach_id = $2 FOR UPDATE`,
        [request.params.planId, request.authUser.id],
      );
      if (!found.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy giáo trình');
      }
      if (found.rows[0].status !== 'DRAFT') {
        await client.query('ROLLBACK');
        return fail(response, 409, 'PLAN_PUBLISHED', 'Chỉ sửa được bản nháp');
      }
      const relationship = await activeRelationship(client, request.authUser.id, found.rows[0].member_id);
      if (!relationship || relationship.id !== found.rows[0].relationship_id) {
        await client.query('ROLLBACK');
        return fail(response, 403, 'RELATIONSHIP_REQUIRED', 'Quan hệ Coach–Member không hoạt động');
      }
      const data = parsed.data;
      const startDate = 'startDate' in data ? data.startDate : found.rows[0].start_date;
      const endDate = 'endDate' in data ? data.endDate : found.rows[0].end_date;
      if (startDate && endDate && new Date(endDate) < new Date(startDate)) {
        await client.query('ROLLBACK');
        return fail(response, 422, 'VALIDATION_ERROR', 'Ngày kết thúc trước ngày bắt đầu');
      }
      await client.query(
        `UPDATE training_plans SET title = $1, goal = $2, start_date = $3, end_date = $4 WHERE id = $5`,
        [data.title ?? found.rows[0].title,
          'goal' in data ? data.goal : found.rows[0].goal,
          startDate, endDate, request.params.planId],
      );
      if (data.days) await replaceDays(client, request.params.planId, data.days);
      await client.query('COMMIT');
      return response.json({ data: await loadPlan(database, request.params.planId) });
    } catch (error) {
      await client.query('ROLLBACK').catch(() => {});
      return error.message === 'INVALID_EXERCISE' || error.code === '23505'
        ? fail(response, 422, 'VALIDATION_ERROR', 'Ngày tập hoặc bài tập không hợp lệ')
        : fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không sửa được giáo trình');
    } finally { client.release(); }
  });

  router.post('/coach/training-plans/:planId/publications', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được công bố');
    if (!uuid.safeParse(request.params.planId).success ||
      request.body == null || typeof request.body !== 'object' ||
      Array.isArray(request.body) || Object.keys(request.body).length) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const owner = await client.query(
        'SELECT member_id FROM training_plans WHERE id = $1 AND coach_id = $2',
        [request.params.planId, request.authUser.id],
      );
      if (!owner.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy giáo trình');
      }
      await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE',
        [owner.rows[0].member_id]);
      const found = await client.query(
        `SELECT * FROM training_plans WHERE id = $1 AND coach_id = $2 FOR UPDATE`,
        [request.params.planId, request.authUser.id],
      );
      if (!found.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy giáo trình');
      }
      const row = found.rows[0];
      const relationship = await activeRelationship(client, request.authUser.id,
        row.member_id, true);
      if (row.status !== 'DRAFT' || relationship?.id !== row.relationship_id) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'PUBLICATION_NOT_ALLOWED', 'Không thể công bố giáo trình');
      }
      const count = await client.query('SELECT count(*)::int AS n FROM training_plan_days WHERE plan_id = $1', [row.id]);
      if (!count.rows[0].n) {
        await client.query('ROLLBACK');
        return fail(response, 422, 'VALIDATION_ERROR', 'Giáo trình cần ít nhất một ngày tập');
      }
      await client.query(
        `UPDATE training_plans SET status = 'ARCHIVED', archived_at = now()
         WHERE member_id = $1 AND status = 'ACTIVE'`, [row.member_id],
      );
      await client.query(
        `UPDATE training_plans SET status = 'ACTIVE', published_at = now() WHERE id = $1`, [row.id],
      );
      await client.query('COMMIT');
      return response.json({ data: await loadPlan(database, row.id) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không công bố được giáo trình');
    } finally { client.release(); }
  });

  router.get('/nutrition-guides/me/active', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem');
    try {
      const found = await database.query(
        `SELECT * FROM nutrition_guides WHERE member_id = $1 AND status = 'ACTIVE'`,
        [request.authUser.id],
      );
      return response.json({ data: found.rows.length ? guideView(found.rows[0]) : null });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được dinh dưỡng'); }
  });

  router.get('/nutrition-guides/me/history', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem');
    try {
      const result = await database.query(
        `SELECT * FROM nutrition_guides WHERE member_id = $1 AND status <> 'DRAFT'
         ORDER BY version DESC`, [request.authUser.id],
      );
      return response.json({ data: result.rows.map(guideView) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được dinh dưỡng'); }
  });

  router.get('/coach/members/:memberId/nutrition-guides', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được xem');
    if (!uuid.safeParse(request.params.memberId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã Member không hợp lệ');
    try {
      const related = await database.query(
        `SELECT id FROM coach_relationships WHERE member_id = $1 AND coach_id = $2
         AND status IN ('ACTIVE', 'PAUSED') LIMIT 1`,
        [request.params.memberId, request.authUser.id],
      );
      if (!related.rows.length) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy Member');
      const result = await database.query(
        `SELECT * FROM nutrition_guides WHERE relationship_id = $1 ORDER BY version DESC`,
        [related.rows[0].id],
      );
      return response.json({ data: result.rows.map(guideView) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được dinh dưỡng'); }
  });

  router.post('/coach/members/:memberId/nutrition-guides', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được tạo');
    if (!uuid.safeParse(request.params.memberId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã Member không hợp lệ');
    const parsed = guideSchema.safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Hướng dẫn không hợp lệ');
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [request.params.memberId]);
      const relationship = await activeRelationship(client, request.authUser.id, request.params.memberId, true);
      if (!relationship) {
        await client.query('ROLLBACK');
        return fail(response, 403, 'RELATIONSHIP_REQUIRED', 'Quan hệ Coach–Member không hoạt động');
      }
      const version = await client.query(
        `SELECT coalesce(max(version), 0)::int + 1 AS next FROM nutrition_guides WHERE member_id = $1`,
        [request.params.memberId],
      );
      const id = randomUUID();
      const result = await client.query(
        `INSERT INTO nutrition_guides
         (id, relationship_id, member_id, coach_id, title, content, version)
         VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
        [id, relationship.id, request.params.memberId, request.authUser.id,
          parsed.data.title, parsed.data.content, version.rows[0].next],
      );
      await client.query('COMMIT');
      return response.status(201).json({ data: guideView(result.rows[0]) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tạo được hướng dẫn');
    } finally { client.release(); }
  });

  router.patch('/coach/nutrition-guides/:guideId', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được sửa');
    if (!uuid.safeParse(request.params.guideId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã hướng dẫn không hợp lệ');
    const parsed = guideSchema.partial().extend({
      publish: z.boolean().optional(),
    }).safeParse(request.body);
    if (!parsed.success || !Object.keys(parsed.data ?? {}).length) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Hướng dẫn không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const owner = await client.query(
        'SELECT member_id FROM nutrition_guides WHERE id = $1 AND coach_id = $2',
        [request.params.guideId, request.authUser.id],
      );
      if (!owner.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy hướng dẫn');
      }
      await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE',
        [owner.rows[0].member_id]);
      const found = await client.query(
        `SELECT * FROM nutrition_guides WHERE id = $1 AND coach_id = $2 FOR UPDATE`,
        [request.params.guideId, request.authUser.id],
      );
      if (!found.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy hướng dẫn');
      }
      const row = found.rows[0];
      if (row.status !== 'DRAFT') {
        await client.query('ROLLBACK');
        return fail(response, 409, 'GUIDE_PUBLISHED', 'Chỉ sửa được bản nháp');
      }
      const relationship = await activeRelationship(client, request.authUser.id, row.member_id);
      if (!relationship || relationship.id !== row.relationship_id) {
        await client.query('ROLLBACK');
        return fail(response, 403, 'RELATIONSHIP_REQUIRED', 'Quan hệ Coach–Member không hoạt động');
      }
      if (parsed.data.publish) {
        await client.query(
          `UPDATE nutrition_guides SET status = 'ARCHIVED', archived_at = now()
           WHERE member_id = $1 AND status = 'ACTIVE'`, [row.member_id],
        );
      }
      const updated = await client.query(
        `UPDATE nutrition_guides SET title = $1, content = $2,
         status = $3, published_at = $4 WHERE id = $5 RETURNING *`,
        [parsed.data.title ?? row.title, parsed.data.content ?? row.content,
          parsed.data.publish ? 'ACTIVE' : 'DRAFT',
          parsed.data.publish ? new Date() : null, row.id],
      );
      await client.query('COMMIT');
      return response.json({ data: guideView(updated.rows[0]) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không sửa được hướng dẫn');
    } finally { client.release(); }
  });

  return router;
}
