import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();
const when = z.iso.datetime({ offset: true });
const note = z.string().trim().max(5000).nullable().optional();
const positive = z.number().positive();
const workoutExercise = z.strictObject({
  exerciseId: uuid.nullable().optional(),
  exerciseName: z.string().trim().min(1).max(120).optional(),
  displayOrder: z.number().int().min(1).max(32767),
  setsCompleted: z.number().int().min(0).max(32767).nullable().optional(),
  repsSummary: z.string().trim().max(100).nullable().optional(),
  weightKg: z.number().min(0).max(9999.99).nullable().optional(),
  durationSeconds: z.number().int().min(1).nullable().optional(),
  notes: note,
}).refine((value) => value.exerciseId || value.exerciseName,
  'Cần bài tập hoặc tên bài tập');
const workoutSchema = z.strictObject({
  trainingSessionId: uuid.nullable().optional(),
  trainingPlanId: uuid.nullable().optional(),
  performedAt: when,
  durationMinutes: z.number().int().min(1).max(32767).nullable().optional(),
  completionLevel: z.number().int().min(0).max(100).nullable().optional(), notes: note,
  exercises: z.array(workoutExercise).max(100).optional(),
});
const mealSchema = z.strictObject({
  eatenAt: when, mealType: z.enum(['BREAKFAST', 'LUNCH', 'DINNER', 'SNACK', 'OTHER']).nullable().optional(),
  mealName: z.string().trim().min(1).max(150), description: note,
  estimatedCalories: z.number().int().min(0).nullable().optional(),
  imageMediaId: uuid.nullable().optional(), notes: note,
});
const measurementSchema = z.strictObject({
  measuredAt: when, weightKg: positive.max(999.99),
  bodyFatPercent: z.number().min(0).max(100).nullable().optional(),
  chestCm: positive.max(999.99).nullable().optional(),
  waistCm: positive.max(999.99).nullable().optional(),
  hipsCm: positive.max(999.99).nullable().optional(),
  armCm: positive.max(999.99).nullable().optional(),
  thighCm: positive.max(999.99).nullable().optional(), notes: note,
});
const photoSchema = z.strictObject({
  mediaId: uuid, takenAt: when,
  pose: z.enum(['FRONT', 'SIDE', 'BACK', 'OTHER']).nullable().optional(), notes: note,
});
const types = [
  { path: 'workout-logs', table: 'workout_logs', idParam: 'logId', time: 'performed_at',
    commentColumn: 'workout_log_id',
    schema: workoutSchema, columns: { trainingSessionId: 'training_session_id',
      trainingPlanId: 'training_plan_id', performedAt: 'performed_at',
      durationMinutes: 'duration_minutes', completionLevel: 'completion_level', notes: 'notes' } },
  { path: 'meal-logs', table: 'meal_logs', idParam: 'logId', time: 'eaten_at',
    commentColumn: 'meal_log_id',
    schema: mealSchema, columns: { eatenAt: 'eaten_at', mealType: 'meal_type',
      mealName: 'meal_name', description: 'description',
      estimatedCalories: 'estimated_calories', imageMediaId: 'image_media_id', notes: 'notes' } },
  { path: 'body-measurements', table: 'body_measurements', idParam: 'measurementId',
    commentColumn: 'measurement_id',
    time: 'measured_at', schema: measurementSchema,
    columns: { measuredAt: 'measured_at', weightKg: 'weight_kg',
      bodyFatPercent: 'body_fat_percent', chestCm: 'chest_cm', waistCm: 'waist_cm',
      hipsCm: 'hips_cm', armCm: 'arm_cm', thighCm: 'thigh_cm', notes: 'notes' } },
  { path: 'progress-photos', table: 'progress_photos', idParam: 'photoId', time: 'taken_at',
    commentColumn: 'progress_photo_id',
    schema: photoSchema, columns: { mediaId: 'media_id', takenAt: 'taken_at',
      pose: 'pose', notes: 'notes' } },
];
const paging = z.strictObject({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, message, details: {} } });
}

function view(row, config) {
  return { id: row.id, memberId: row.member_id,
    ...Object.fromEntries(Object.entries(config.columns).map(([key, column]) => [key, row[column]])) };
}

function exerciseView(row) {
  return { id: row.id, exerciseId: row.exercise_id,
    exerciseName: row.exercise_name_snapshot, displayOrder: row.display_order,
    setsCompleted: row.sets_completed, repsSummary: row.reps_summary,
    weightKg: row.weight_kg, durationSeconds: row.duration_seconds,
    notes: row.notes };
}

async function workoutDetails(database, rows, config) {
  const data = rows.map((row) => view(row, config));
  if (config.table !== 'workout_logs' || !rows.length) return data;
  const exercises = await database.query(
    `SELECT * FROM workout_log_exercises WHERE workout_log_id = ANY($1::uuid[])
     ORDER BY display_order`, [rows.map((row) => row.id)],
  );
  const byLog = new Map(data.map((item) => [item.id, item]));
  for (const item of data) item.exercises = [];
  for (const row of exercises.rows) byLog.get(row.workout_log_id).exercises.push(exerciseView(row));
  return data;
}

async function replaceWorkoutExercises(client, logId, entries) {
  await client.query('DELETE FROM workout_log_exercises WHERE workout_log_id = $1', [logId]);
  for (const item of entries) {
    let name = item.exerciseName;
    if (item.exerciseId) {
      const found = await client.query(
        `SELECT name FROM exercises WHERE id = $1 AND status = 'ACTIVE'`,
        [item.exerciseId],
      );
      if (!found.rows.length) throw new Error('INVALID_EXERCISE');
      name = found.rows[0].name;
    }
    await client.query(
      `INSERT INTO workout_log_exercises
       (id, workout_log_id, exercise_id, exercise_name_snapshot,
        display_order, sets_completed, reps_summary, weight_kg,
        duration_seconds, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [randomUUID(), logId, item.exerciseId ?? null, name,
        item.displayOrder, item.setsCompleted ?? null,
        item.repsSummary ?? null, item.weightKg ?? null,
        item.durationSeconds ?? null, item.notes ?? null],
    );
  }
}

async function activeMembership(database, memberId) {
  const result = await database.query(
    `SELECT 1 FROM member_memberships WHERE member_id = $1 AND status = 'ACTIVE'
     AND start_date <= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
     AND end_date >= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date LIMIT 1`,
    [memberId],
  );
  return result.rows.length > 0;
}

async function validMedia(database, mediaId, memberId, purpose) {
  if (!mediaId) return true;
  const result = await database.query(
    `SELECT 1 FROM media_assets WHERE id = $1 AND owner_id = $2
     AND purpose = $3 AND status = 'READY'`, [mediaId, memberId, purpose],
  );
  return result.rows.length > 0;
}

async function list(database, config, memberId, page, pageSize) {
  const total = await database.query(
    `SELECT count(*)::int AS count FROM ${config.table} WHERE member_id = $1`, [memberId],
  );
  const result = await database.query(
    `SELECT * FROM ${config.table} WHERE member_id = $1
     ORDER BY ${config.time} DESC, id DESC LIMIT $2 OFFSET $3`,
    [memberId, pageSize, (page - 1) * pageSize],
  );
  const totalItems = total.rows[0].count;
  return { data: await workoutDetails(database, result.rows, config),
    pagination: { page, pageSize, totalItems,
      totalPages: Math.ceil(totalItems / pageSize) } };
}

async function summary(database, memberId) {
  const [workouts, meals, latest, photos] = await Promise.all([
    database.query('SELECT count(*)::int AS count FROM workout_logs WHERE member_id = $1', [memberId]),
    database.query('SELECT count(*)::int AS count FROM meal_logs WHERE member_id = $1', [memberId]),
    database.query('SELECT measured_at, weight_kg, body_fat_percent FROM body_measurements WHERE member_id = $1 ORDER BY measured_at DESC, id DESC LIMIT 1', [memberId]),
    database.query('SELECT count(*)::int AS count FROM progress_photos WHERE member_id = $1', [memberId]),
  ]);
  return { workoutCount: workouts.rows[0].count, mealCount: meals.rows[0].count,
    progressPhotoCount: photos.rows[0].count,
    latestMeasurement: latest.rows[0] ? {
      measuredAt: latest.rows[0].measured_at,
      weightKg: latest.rows[0].weight_kg,
      bodyFatPercent: latest.rows[0].body_fat_percent,
    } : null };
}

export function createProgressRouter({ database, jwtSecret }) {
  const router = Router();
  router.use(createAuthentication({ database, jwtSecret }));

  router.get('/progress/me/summary', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem');
    try { return response.json({ data: await summary(database, request.authUser.id) }); }
    catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được tiến độ'); }
  });

  router.get('/progress/me/charts', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem');
    const parsed = z.strictObject({ from: z.iso.date().optional(), to: z.iso.date().optional() })
      .safeParse(request.query);
    if (!parsed.success || (parsed.data.from && parsed.data.to && parsed.data.from > parsed.data.to)) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Khoảng ngày không hợp lệ');
    }
    try {
      const args = [request.authUser.id, parsed.data.from ?? '0001-01-01', parsed.data.to ?? '9999-12-31'];
      const result = await database.query(
        `SELECT measured_at, weight_kg, body_fat_percent
         FROM body_measurements WHERE member_id = $1
         AND (measured_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date BETWEEN $2::date AND $3::date
         ORDER BY measured_at, id`, args,
      );
      return response.json({ data: result.rows.map((row) => ({
        measuredAt: row.measured_at, weightKg: row.weight_kg,
        bodyFatPercent: row.body_fat_percent,
      })) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được biểu đồ'); }
  });

  // The personal journal and its chart are private even from the current Coach.
  router.get('/coach/members/:memberId/progress/summary', (_request, response) =>
    fail(response, 403, 'FORBIDDEN', 'Nhật ký cá nhân chỉ Member được xem'));

  for (const config of types) {
    router.get(`/${config.path}`, async (request, response) => {
      if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem');
      const parsed = paging.safeParse(request.query);
      if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Phân trang không hợp lệ');
      try { return response.json(await list(database, config, request.authUser.id,
        parsed.data.page, parsed.data.pageSize)); }
      catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được nhật ký'); }
    });

    router.get(`/coach/members/:memberId/${config.path}`, (_request, response) =>
      fail(response, 403, 'FORBIDDEN', 'Nhật ký cá nhân chỉ Member được xem'));

    router.post(`/${config.path}`, async (request, response) => {
      if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được ghi');
      const parsed = config.schema.safeParse(request.body);
      if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Nhật ký không hợp lệ');
      try {
        if (!await activeMembership(database, request.authUser.id)) {
          return fail(response, 403, 'MEMBERSHIP_REQUIRED', 'Cần gói tập đang hoạt động');
        }
        const mediaId = config.table === 'progress_photos' ? parsed.data.mediaId
          : config.table === 'meal_logs' ? parsed.data.imageMediaId : null;
        if (mediaId && !await validMedia(database, mediaId, request.authUser.id,
          config.table === 'progress_photos' ? 'PROGRESS_PHOTO' : 'MEAL_PHOTO')) {
          return fail(response, 422, 'VALIDATION_ERROR', 'Ảnh không hợp lệ');
        }
        const entries = Object.entries(config.columns).filter(([key]) => key in parsed.data);
        const id = randomUUID();
        const client = await database.connect();
        try {
          await client.query('BEGIN');
          const result = await client.query(
          `INSERT INTO ${config.table} (id, member_id, ${entries.map(([, column]) => column).join(', ')})
           VALUES ($1, $2, ${entries.map((_, index) => `$${index + 3}`).join(', ')}) RETURNING *`,
          [id, request.authUser.id, ...entries.map(([key]) => parsed.data[key])],
          );
          if (config.table === 'workout_logs' && parsed.data.exercises) {
            await replaceWorkoutExercises(client, id, parsed.data.exercises);
          }
          const data = (await workoutDetails(client, result.rows, config))[0];
          await client.query('COMMIT');
          return response.status(201).json({ data });
        } catch (error) {
          await client.query('ROLLBACK').catch(() => {});
          if (error.message === 'INVALID_EXERCISE' || error.code === '23505' ||
            error.code === '23503') {
            return fail(response, 422, 'VALIDATION_ERROR', 'Bài tập không hợp lệ');
          }
          throw error;
        } finally { client.release(); }
      } catch { return fail(response, 422, 'VALIDATION_ERROR', 'Không ghi được nhật ký'); }
    });

    router.patch(`/${config.path}/:${config.idParam}`, async (request, response) => {
      if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được sửa');
      const id = request.params[config.idParam];
      if (!uuid.safeParse(id).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã nhật ký không hợp lệ');
      const parsed = config.schema.partial().safeParse(request.body);
      if (!parsed.success || !Object.keys(parsed.data ?? {}).length) {
        return fail(response, 422, 'VALIDATION_ERROR', 'Nhật ký không hợp lệ');
      }
      try {
        if (!await activeMembership(database, request.authUser.id)) {
          return fail(response, 403, 'MEMBERSHIP_REQUIRED', 'Cần gói tập đang hoạt động');
        }
        const mediaId = config.table === 'progress_photos' ? parsed.data.mediaId
          : config.table === 'meal_logs' ? parsed.data.imageMediaId : null;
        if (mediaId && !await validMedia(database, mediaId, request.authUser.id,
          config.table === 'progress_photos' ? 'PROGRESS_PHOTO' : 'MEAL_PHOTO')) {
          return fail(response, 422, 'VALIDATION_ERROR', 'Ảnh không hợp lệ');
        }
        const entries = Object.entries(config.columns).filter(([key]) => key in parsed.data);
        const client = await database.connect();
        try {
          await client.query('BEGIN');
          await client.query('SELECT pg_advisory_xact_lock(hashtext($1))', [id]);
          const existing = await client.query(
            `SELECT * FROM ${config.table} WHERE id = $1 AND member_id = $2 FOR UPDATE`,
            [id, request.authUser.id],
          );
          if (!existing.rows.length) {
            await client.query('ROLLBACK');
            return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy nhật ký');
          }
          const result = entries.length ? await client.query(
            `UPDATE ${config.table} SET ${entries.map(([, column], index) => `${column} = $${index + 1}`).join(', ')}
             WHERE id = $${entries.length + 1} AND member_id = $${entries.length + 2} RETURNING *`,
            [...entries.map(([key]) => parsed.data[key]), id, request.authUser.id],
          ) : existing;
          if (config.table === 'workout_logs' && parsed.data.exercises) {
            await replaceWorkoutExercises(client, id, parsed.data.exercises);
          }
          const data = (await workoutDetails(client, result.rows, config))[0];
          await client.query('COMMIT');
          return response.json({ data });
        } catch (error) {
          await client.query('ROLLBACK').catch(() => {});
          if (error.message === 'INVALID_EXERCISE' || error.code === '23505' ||
            error.code === '23503') {
            return fail(response, 422, 'VALIDATION_ERROR', 'Bài tập không hợp lệ');
          }
          throw error;
        } finally { client.release(); }
      } catch { return fail(response, 422, 'VALIDATION_ERROR', 'Không sửa được nhật ký'); }
    });
  }

  router.get('/progress-comments', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') {
      return fail(response, 403, 'FORBIDDEN', 'Nhật ký cá nhân chỉ Member được xem');
    }
    const parsed = paging.extend({
      memberId: uuid.optional(), workoutLogId: uuid.optional(),
      mealLogId: uuid.optional(), measurementId: uuid.optional(),
      progressPhotoId: uuid.optional(),
    }).safeParse(request.query);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Bộ lọc không hợp lệ');
    const memberId = request.authUser.id;
    if (parsed.data.memberId && parsed.data.memberId !== memberId) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã Member không hợp lệ');
    }
    try {
      const filters = { workoutLogId: 'workout_log_id', mealLogId: 'meal_log_id',
        measurementId: 'measurement_id', progressPhotoId: 'progress_photo_id' };
      const args = [memberId];
      let where = 'member_id = $1';
      for (const [key, column] of Object.entries(filters)) {
        if (parsed.data[key]) {
          args.push(parsed.data[key]);
          where += ` AND ${column} = $${args.length}`;
        }
      }
      const total = await database.query(
        `SELECT count(*)::int AS count FROM progress_comments WHERE ${where}`, args,
      );
      const { page, pageSize } = parsed.data;
      const result = await database.query(
        `SELECT * FROM progress_comments WHERE ${where}
         ORDER BY created_at DESC, id DESC LIMIT $${args.length + 1} OFFSET $${args.length + 2}`,
        [...args, pageSize, (page - 1) * pageSize],
      );
      const totalItems = total.rows[0].count;
      return response.json({ data: result.rows.map((row) => ({
        id: row.id, memberId: row.member_id, coachId: row.coach_id,
        relationshipId: row.relationship_id, workoutLogId: row.workout_log_id,
        mealLogId: row.meal_log_id, measurementId: row.measurement_id,
        progressPhotoId: row.progress_photo_id, content: row.content,
        createdAt: row.created_at,
      })), pagination: { page, pageSize, totalItems,
        totalPages: Math.ceil(totalItems / pageSize) } });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được nhận xét'); }
  });

  router.post('/coach/progress-comments', (_request, response) =>
    fail(response, 403, 'FORBIDDEN', 'Coach không có quyền nhận xét nhật ký cá nhân'));
  return router;
}
