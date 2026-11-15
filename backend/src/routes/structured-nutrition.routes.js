import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();
const food = z.strictObject({
  name: z.string().trim().min(1).max(150),
  kcalPer100g: z.number().min(0).max(1000),
  active: z.boolean(),
});
const plan = z.strictObject({
  title: z.string().trim().min(1).max(150),
  items: z.array(z.strictObject({
    day: z.number().int().min(1).max(7),
    meal: z.enum(['BREAKFAST', 'LUNCH', 'DINNER']),
    foodId: uuid,
    grams: z.number().int().min(1).max(10000),
  })).max(210),
});

function fail(response, status, message) {
  return response.status(status).json({ error: { code: ({
    403: 'FORBIDDEN', 404: 'NOT_FOUND', 422: 'VALIDATION_ERROR',
  })[status] ?? 'INTERNAL_SERVER_ERROR', message, details: {} } });
}

async function renderPlan(db, row) {
  if (row.meal_items == null) return { ...row, items: [] };
  if (row.status === 'ARCHIVED') return { ...row, items: row.meal_items };
  const ids = [...new Set(row.meal_items.map(({ foodId }) => foodId))];
  const { rows } = await db.query(
    'SELECT id, name, kcal_per_100g::float8 AS kcal FROM nutrition_foods WHERE id = ANY($1::uuid[])', [ids],
  );
  const foods = new Map(rows.map((entry) => [entry.id, entry]));
  return { ...row, items: row.meal_items.map((item) => ({
    ...item, foodName: foods.get(item.foodId)?.name ?? item.foodName,
    kcalPer100g: foods.get(item.foodId)?.kcal ?? item.kcalPer100g,
  })) };
}

export function createStructuredNutritionRouter({ database, jwtSecret }) {
  const router = Router();
  router.use(['/nutrition-foods', '/admin/nutrition-foods', '/meal-plans', '/coach/meal-plans'],
    createAuthentication({ database, jwtSecret }));

  router.get(['/nutrition-foods', '/admin/nutrition-foods'], async (request, response) => {
    const admin = request.path.startsWith('/admin/');
    if (request.authUser.role !== (admin ? 'ADMIN' : 'COACH')) {
      return fail(response, 403, 'Không có quyền xem danh mục thực phẩm');
    }
    const { rows } = await database.query(
      `SELECT id, name, kcal_per_100g::float8 AS "kcalPer100g", active
       FROM nutrition_foods WHERE $1::boolean OR active ORDER BY name, id`, [admin],
    );
    return response.json({ data: rows });
  });

  router.post('/admin/nutrition-foods', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'Chỉ Admin được thêm thực phẩm');
    const parsed = food.safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'Thông tin thực phẩm không hợp lệ');
    const { name, kcalPer100g, active } = parsed.data;
    const { rows: [item] } = await database.query(
      `INSERT INTO nutrition_foods (id, name, kcal_per_100g, active) VALUES ($1, $2, $3, $4)
       RETURNING id, name, kcal_per_100g::float8 AS "kcalPer100g", active`, [randomUUID(), name, kcalPer100g, active],
    );
    return response.status(201).json({ data: item });
  });

  router.patch('/admin/nutrition-foods/:id', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'Chỉ Admin được cập nhật thực phẩm');
    const parsed = food.safeParse(request.body);
    if (!parsed.success || !uuid.safeParse(request.params.id).success) {
      return fail(response, 422, 'Thông tin thực phẩm không hợp lệ');
    }
    const { name, kcalPer100g, active } = parsed.data;
    const { rows: [item] } = await database.query(
      `UPDATE nutrition_foods SET name = $2, kcal_per_100g = $3, active = $4 WHERE id = $1
       RETURNING id, name, kcal_per_100g::float8 AS "kcalPer100g", active`,
      [request.params.id, name, kcalPer100g, active],
    );
    return item ? response.json({ data: item }) : fail(response, 404, 'Không tìm thấy thực phẩm');
  });

  router.get('/meal-plans/me', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'Chỉ Member được xem thực đơn của mình');
    const { rows } = await database.query(
      `SELECT id, relationship_id AS "relationshipId", title, content, status, meal_items
       FROM nutrition_guides WHERE member_id = $1
       AND status IN ('ACTIVE', 'ARCHIVED') ORDER BY (status = 'ACTIVE') DESC, version DESC LIMIT 100`,
      [request.authUser.id],
    );
    return response.json({ data: await Promise.all(rows.map((row) => renderPlan(database, row))) });
  });

  router.get('/coach/meal-plans/:memberId', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'Chỉ Coach được xem thực đơn hội viên');
    if (!uuid.safeParse(request.params.memberId).success) return fail(response, 422, 'Mã hội viên không hợp lệ');
    const { rows: [row] } = await database.query(
      `SELECT g.id, g.title, g.content, g.status, g.meal_items FROM nutrition_guides g
       JOIN coach_relationships r ON r.id = g.relationship_id
       WHERE r.member_id = $1 AND r.coach_id = $2 AND r.status IN ('ACTIVE','PAUSED') AND g.status = 'ACTIVE'`,
      [request.params.memberId, request.authUser.id],
    );
    return response.json({ data: row ? await renderPlan(database, row) : { items: [] } });
  });

  router.put('/coach/meal-plans/:memberId', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'Chỉ Coach được lưu thực đơn');
    const memberId = request.params.memberId;
    const parsed = plan.safeParse(request.body);
    if (!parsed.success || !uuid.safeParse(memberId).success) return fail(response, 422, 'Thực đơn không hợp lệ');
    const client = await database.connect();
    try {
      await client.query('BEGIN');
      await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [memberId]);
      const coachId = request.authUser.id;
      const { rows: [relationship] } = await client.query(
        `SELECT id FROM coach_relationships WHERE member_id = $1 AND coach_id = $2
         AND status = 'ACTIVE' FOR UPDATE`, [memberId, coachId],
      );
      if (!relationship) {
        await client.query('ROLLBACK');
        return fail(response, 403, 'Hội viên chưa có quan hệ đang hoạt động với Coach');
      }
      const { rows: [current] } = await client.query(
        "SELECT id, meal_items FROM nutrition_guides WHERE relationship_id = $1 AND status = 'ACTIVE' FOR UPDATE",
        [relationship.id],
      );
      const { title, items } = parsed.data;
      const ids = [...new Set(items.map(({ foodId }) => foodId))];
      const { rows } = await client.query(
        `SELECT id, name, active, kcal_per_100g::float8 AS kcal
         FROM nutrition_foods WHERE id = ANY($1::uuid[]) FOR SHARE`, [ids],
      );
      const foods = new Map(rows.map((item) => [item.id, item]));
      const savedItems = items.map((item) => {
        const entry = foods.get(item.foodId);
        if (entry && (entry.active || current?.meal_items?.some((old) =>
          old.foodId === item.foodId && old.day === item.day && old.meal === item.meal))) {
          return { ...item, foodName: entry.name, kcalPer100g: entry.kcal };
        }
        return null;
      });
      if (savedItems.includes(null)) {
        await client.query('ROLLBACK');
        return fail(response, 422, 'Có thực phẩm đã ngừng sử dụng hoặc không tồn tại');
      }
      const labels = { BREAKFAST: 'Sáng', LUNCH: 'Trưa', DINNER: 'Tối' };
      const content = savedItems.map((item) =>
        `Ngày ${item.day} · ${labels[item.meal]} · ${item.foodName} ${item.grams} g`).join('\n') || 'Chưa có món';
      const json = JSON.stringify(savedItems);
      const id = current?.id ?? randomUUID();
      if (current) {
        await client.query('UPDATE nutrition_guides SET title = $2, content = $3, meal_items = $4 WHERE id = $1',
          [id, title, content, json]);
      } else {
        await client.query(
          "UPDATE nutrition_guides SET status = 'ARCHIVED', archived_at = now() WHERE member_id = $1 AND status = 'ACTIVE'",
          [memberId],
        );
        await client.query(
          `INSERT INTO nutrition_guides (id, relationship_id, member_id, coach_id, title,
             content, version, status, published_at, meal_items)
           SELECT $1, $2, $3, $4, $5, $6, COALESCE(max(version),0)+1, 'ACTIVE', now(), $7
           FROM nutrition_guides WHERE member_id = $3`, [id, relationship.id, memberId, coachId, title, content, json],
        );
      }
      await client.query('COMMIT');
      return response.json({ data: { id, title, items: savedItems } });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'Không lưu được thực đơn');
    } finally {
      client.release();
    }
  });

  return router;
}
