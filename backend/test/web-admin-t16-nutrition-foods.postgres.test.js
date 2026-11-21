import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { once } from 'node:events';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'web-admin-t16-nutrition-foods-secret-32chars';

function token(id, role, sessionVersion = 0) {
  return jwt.sign({ role, sessionVersion }, secret, {
    algorithm: 'HS256',
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    subject: id,
    expiresIn: 3600,
  });
}

async function call(base, path, bearer, method = 'GET', body) {
  const response = await fetch(`${base}/api/v1${path}`, {
    method,
    headers: {
      ...(bearer ? { authorization: `Bearer ${bearer}` } : {}),
      ...(body === undefined ? {} : { 'content-type': 'application/json' }),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: response.status, body: await response.json() };
}

test('T16: Admin nutrition-foods search/filter/pagination, trg_freeze_nutrition_calories, audit logs, and privacy guard',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const app = createApp({ database, jwtSecret: secret });
    const server = app.listen(0, '127.0.0.1');

    const adminId = randomUUID();
    const memberId = randomUUID();
    const coachId = randomUUID();
    const relationshipId = randomUUID();
    const prefix = `T16F_${randomUUID().slice(0, 8)}`;
    const createdFoodIds = [];
    const guideIds = [];

    const adminToken = token(adminId, 'ADMIN', 0);
    const staleAdminToken = token(adminId, 'ADMIN', 99);
    const memberToken = token(memberId, 'MEMBER', 0);
    const coachToken = token(coachId, 'COACH', 0);

    try {
      await once(server, 'listening');
      const base = `http://127.0.0.1:${server.address().port}`;
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Meta Gym Admin T16'),
                ($3, $4, 'hash', 'MEMBER', 'Member T16'),
                ($5, $6, 'hash', 'COACH', 'Coach T16')`,
        [
          adminId, `${adminId}@example.com`,
          memberId, `${memberId}@example.com`,
          coachId, `${coachId}@example.com`,
        ],
      );
      await database.query('INSERT INTO member_profiles (user_id) VALUES ($1)', [memberId]);
      await database.query('INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 8)', [coachId]);
      await database.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id, status)
         VALUES ($1, $2, $3, 'ACTIVE')`,
        [relationshipId, memberId, coachId],
      );

      // 1. Role guards & query/body validation
      assert.equal((await call(base, '/admin/nutrition-foods', memberToken)).status, 403);
      assert.equal((await call(base, '/admin/nutrition-foods', coachToken)).status, 403);
      assert.equal((await call(base, '/nutrition-foods', adminToken)).status, 403);
      assert.equal((await call(base, '/nutrition-foods', memberToken)).status, 403);
      assert.equal((await call(base, '/admin/nutrition-foods?active=maybe', adminToken)).status, 422);
      assert.equal((await call(base, '/admin/nutrition-foods?page=0', adminToken)).status, 422);
      assert.equal((await call(base, '/admin/nutrition-foods?pageSize=101', adminToken)).status, 422);
      assert.equal((await call(base, '/admin/nutrition-foods?unknownParam=1', adminToken)).status, 422);

      assert.equal((await call(base, '/admin/nutrition-foods', adminToken, 'POST', {
        name: '   ', kcalPer100g: 100, active: true,
      })).status, 422);
      assert.equal((await call(base, '/admin/nutrition-foods', adminToken, 'POST', {
        name: 'Invalid Kcal', kcalPer100g: 1001, active: true,
      })).status, 422);
      assert.equal((await call(base, '/admin/nutrition-foods', adminToken, 'POST', {
        name: 'Extra Field', kcalPer100g: 100, active: true, category: 'protein',
      })).status, 422);
      assert.equal((await call(base, '/admin/nutrition-foods', staleAdminToken, 'POST', {
        name: 'Stale Admin Food', kcalPer100g: 100, active: true,
      })).status, 401);
      assert.equal((await call(base, '/admin/nutrition-foods/not-a-uuid', adminToken, 'PATCH', {
        active: false,
      })).status, 422);
      assert.equal((await call(base, `/admin/nutrition-foods/${randomUUID()}`, adminToken, 'PATCH', {
        active: false,
      })).status, 404);
      assert.equal((await call(base, `/admin/nutrition-foods/${randomUUID()}`, adminToken, 'PATCH', {})).status, 422);

      // 2. Seed 28 foods (>25) for search, active filter, and pagination testing
      for (let i = 1; i <= 28; i += 1) {
        const id = randomUUID();
        const isActive = i <= 20;
        const suffix = i === 1 ? '100%_Special' : `Item_${String(i).padStart(2, '0')}`;
        const name = `${prefix}_${suffix}`;
        const kcal = 50 + i * 10;
        await database.query(
          'INSERT INTO nutrition_foods (id, name, kcal_per_100g, active) VALUES ($1, $2, $3, $4)',
          [id, name, kcal, isActive],
        );
        createdFoodIds.push(id);
      }

      // Default page=1, pageSize=20
      const pageDefault = await call(base, `/admin/nutrition-foods?search=${encodeURIComponent(prefix)}`, adminToken);
      assert.equal(pageDefault.status, 200);
      assert.equal(pageDefault.body.data.length, 20);
      assert.deepEqual(pageDefault.body.pagination, {
        page: 1, pageSize: 20, totalItems: 28, totalPages: 2,
      });

      // Custom page=1..3, pageSize=10
      const page1 = await call(
        base, `/admin/nutrition-foods?search=${encodeURIComponent(prefix)}&page=1&pageSize=10`, adminToken,
      );
      const page3 = await call(
        base, `/admin/nutrition-foods?search=${encodeURIComponent(prefix)}&page=3&pageSize=10`, adminToken,
      );
      assert.equal(page1.status, 200);
      assert.equal(page1.body.data.length, 10);
      assert.deepEqual(page1.body.pagination, { page: 1, pageSize: 10, totalItems: 28, totalPages: 3 });
      assert.equal(page3.status, 200);
      assert.equal(page3.body.data.length, 8);
      assert.deepEqual(page3.body.pagination, { page: 3, pageSize: 10, totalItems: 28, totalPages: 3 });

      // active=true and active=false filters
      const activeOnly = await call(
        base, `/admin/nutrition-foods?search=${encodeURIComponent(prefix)}&active=true&page=1&pageSize=50`, adminToken,
      );
      assert.equal(activeOnly.status, 200);
      assert.equal(activeOnly.body.data.length, 20);
      assert.equal(activeOnly.body.pagination.totalItems, 20);
      assert.ok(activeOnly.body.data.every((item) => item.active === true));

      const inactiveOnly = await call(
        base, `/admin/nutrition-foods?search=${encodeURIComponent(prefix)}&active=false&page=1&pageSize=50`, adminToken,
      );
      assert.equal(inactiveOnly.status, 200);
      assert.equal(inactiveOnly.body.data.length, 8);
      assert.equal(inactiveOnly.body.pagination.totalItems, 8);
      assert.ok(inactiveOnly.body.data.every((item) => item.active === false));

      // Case-insensitive search + LIKE metacharacter escaping (% and _)
      const caseInsensitive = await call(
        base,
        `/admin/nutrition-foods?search=${encodeURIComponent(`${prefix.toLowerCase()}_item_05`)}`,
        adminToken,
      );
      assert.equal(caseInsensitive.status, 200);
      assert.equal(caseInsensitive.body.pagination.totalItems, 1);
      assert.equal(caseInsensitive.body.data[0].name, `${prefix}_Item_05`);

      const escapedLike = await call(
        base,
        `/admin/nutrition-foods?search=${encodeURIComponent(`${prefix}_100%_Special`)}`,
        adminToken,
      );
      assert.equal(escapedLike.status, 200);
      assert.equal(escapedLike.body.pagination.totalItems, 1);
      assert.equal(escapedLike.body.data[0].name, `${prefix}_100%_Special`);

      // Coach GET /nutrition-foods remains backward-compatible (active foods only)
      const coachFoods = await call(base, '/nutrition-foods', coachToken);
      assert.equal(coachFoods.status, 200);
      const coachPrefixFoods = coachFoods.body.data.filter((item) => item.name.startsWith(prefix));
      assert.equal(coachPrefixFoods.length, 20);
      assert.ok(coachPrefixFoods.every((item) => item.active === true));

      // 3. trg_freeze_nutrition_calories invariant:
      //    LIVE/ACTIVE guides update dynamically; ARCHIVED guides remain frozen at historical kcal.
      const createdFood = await call(base, '/admin/nutrition-foods', adminToken, 'POST', {
        name: `${prefix}_ChickenBreast`,
        kcalPer100g: 165,
        active: true,
      });
      assert.equal(createdFood.status, 201);
      const liveFoodId = createdFood.body.data.id;
      createdFoodIds.push(liveFoodId);

      const firstPlan = await call(base, `/coach/meal-plans/${memberId}`, coachToken, 'PUT', {
        title: 'Thực đơn Tuần 1',
        items: [{ day: 1, meal: 'LUNCH', foodId: liveFoodId, grams: 200 }],
      });
      assert.equal(firstPlan.status, 200, JSON.stringify(firstPlan.body));
      const archivedGuideId = firstPlan.body.data.id;
      guideIds.push(archivedGuideId);

      // Update food kcal from 165 -> 210 while guide is ACTIVE
      const update1 = await call(base, `/admin/nutrition-foods/${liveFoodId}`, adminToken, 'PATCH', {
        name: `${prefix}_ChickenBreast`,
        kcalPer100g: 210,
        active: true,
      });
      assert.equal(update1.status, 200);

      // ACTIVE guide must reflect live 210 kcal/100g for both Member & Coach
      const memberLive1 = await call(base, '/meal-plans/me', memberToken);
      assert.equal(memberLive1.status, 200);
      assert.equal(memberLive1.body.data[0].status, 'ACTIVE');
      assert.equal(memberLive1.body.data[0].items[0].kcalPer100g, 210);

      const coachLive1 = await call(base, `/coach/meal-plans/${memberId}`, coachToken);
      assert.equal(coachLive1.status, 200);
      assert.equal(coachLive1.body.data.items[0].kcalPer100g, 210);

      // Archive the first guide -> triggers trg_freeze_nutrition_calories (freezes at 210)
      await database.query(
        "UPDATE nutrition_guides SET status = 'ARCHIVED', archived_at = now() WHERE id = $1",
        [archivedGuideId],
      );

      // Create a second ACTIVE guide referencing the same food
      const secondPlan = await call(base, `/coach/meal-plans/${memberId}`, coachToken, 'PUT', {
        title: 'Thực đơn Tuần 2',
        items: [{ day: 2, meal: 'DINNER', foodId: liveFoodId, grams: 150 }],
      });
      assert.equal(secondPlan.status, 200, JSON.stringify(secondPlan.body));
      const activeGuideId = secondPlan.body.data.id;
      guideIds.push(activeGuideId);

      // Update food kcal again from 210 -> 300 via Admin PATCH
      const update2 = await call(base, `/admin/nutrition-foods/${liveFoodId}`, adminToken, 'PATCH', {
        kcalPer100g: 300,
      });
      assert.equal(update2.status, 200);
      assert.equal(update2.body.data.kcalPer100g, 300);
      assert.equal(update2.body.data.name, `${prefix}_ChickenBreast`);
      assert.equal(update2.body.data.active, true);

      // Verify Member sees: ACTIVE guide at live 300 kcal/100g, ARCHIVED guide frozen at 210 kcal/100g
      const memberPlansAfter = await call(base, '/meal-plans/me', memberToken);
      assert.equal(memberPlansAfter.status, 200);
      const activeGuide = memberPlansAfter.body.data.find((g) => g.id === activeGuideId);
      const archivedGuide = memberPlansAfter.body.data.find((g) => g.id === archivedGuideId);
      assert.equal(activeGuide.status, 'ACTIVE');
      assert.equal(activeGuide.items[0].kcalPer100g, 300);
      assert.equal(archivedGuide.status, 'ARCHIVED');
      assert.equal(archivedGuide.items[0].kcalPer100g, 210);

      // Confirm DB meal_items column on ARCHIVED guide was frozen by trigger at 210
      const { rows: [archivedDb] } = await database.query(
        'SELECT meal_items FROM nutrition_guides WHERE id = $1',
        [archivedGuideId],
      );
      assert.equal(Number(archivedDb.meal_items[0].kcalPer100g), 210);

      // 4. Deactivate food (partial PATCH) & verify full before/after admin_audit_logs
      const deactivate = await call(base, `/admin/nutrition-foods/${liveFoodId}`, adminToken, 'PATCH', {
        active: false,
      });
      assert.equal(deactivate.status, 200);
      assert.equal(deactivate.body.data.active, false);
      assert.equal(deactivate.body.data.kcalPer100g, 300);

      const audits = await call(
        base,
        `/admin/audit-logs?entityType=NUTRITION_FOOD&entityId=${liveFoodId}&page=1&pageSize=10`,
        adminToken,
      );
      assert.equal(audits.status, 200);
      assert.equal(audits.body.pagination.totalItems, 4);
      // Ordered DESC: deactivate -> update2 (210->300) -> update1 (165->210) -> create (165)
      assert.equal(audits.body.data[0].action, 'NUTRITION_FOOD_UPDATED');
      assert.deepEqual(audits.body.data[0].metadata.before, {
        id: liveFoodId, name: `${prefix}_ChickenBreast`, kcalPer100g: 300, active: true,
      });
      assert.deepEqual(audits.body.data[0].metadata.after, {
        id: liveFoodId, name: `${prefix}_ChickenBreast`, kcalPer100g: 300, active: false,
      });

      assert.equal(audits.body.data[1].action, 'NUTRITION_FOOD_UPDATED');
      assert.equal(audits.body.data[1].metadata.before.kcalPer100g, 210);
      assert.equal(audits.body.data[1].metadata.after.kcalPer100g, 300);

      assert.equal(audits.body.data[2].action, 'NUTRITION_FOOD_UPDATED');
      assert.equal(audits.body.data[2].metadata.before.kcalPer100g, 165);
      assert.equal(audits.body.data[2].metadata.after.kcalPer100g, 210);

      assert.equal(audits.body.data[3].action, 'NUTRITION_FOOD_CREATED');
      assert.equal(audits.body.data[3].metadata.before, null);
      assert.deepEqual(audits.body.data[3].metadata.after, {
        id: liveFoodId, name: `${prefix}_ChickenBreast`, kcalPer100g: 165, active: true,
      });

      // 5. Privacy invariant: Admin CANNOT access member_nutrition_tracking or member private meal-plans
      assert.equal((await call(base, '/member/nutrition/day?date=2026-11-21', adminToken)).status, 403);
      assert.equal((await call(base, '/member/nutrition/foods', adminToken)).status, 403);
      assert.equal((await call(base, '/member/nutrition/entries', adminToken, 'POST', {
        eatenAt: '2026-11-21T07:00:00+07:00',
        mealType: 'BREAKFAST',
        mealName: 'Test',
        quantity: 100,
        unit: 'g',
      })).status, 403);
      assert.equal((await call(base, '/meal-plans/me', adminToken)).status, 403);
      assert.equal((await call(base, '/member/nutrition/day?date=2026-11-21', coachToken)).status, 403);
    } finally {
      try {
        await database.query('BEGIN');
        await database.query('DELETE FROM admin_audit_logs WHERE admin_id = $1', [adminId]);
        if (guideIds.length) {
          await database.query('DELETE FROM nutrition_guide_revisions WHERE guide_id = ANY($1::uuid[])', [guideIds]);
          await database.query('DELETE FROM nutrition_guides WHERE id = ANY($1::uuid[])', [guideIds]);
        }
        if (createdFoodIds.length) {
          await database.query('DELETE FROM nutrition_foods WHERE id = ANY($1::uuid[])', [createdFoodIds]);
        }
        await database.query('DELETE FROM coach_relationships WHERE id = $1', [relationshipId]);
        await database.query('DELETE FROM member_profiles WHERE user_id = $1', [memberId]);
        await database.query('DELETE FROM coach_profiles WHERE user_id = $1', [coachId]);
        await database.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [[adminId, memberId, coachId]]);
        await database.query('COMMIT');
      } catch (error) {
        await database.query('ROLLBACK').catch(() => {});
        throw error;
      } finally {
        await new Promise((resolve) => server.close(resolve));
        await database.end();
      }
    }
  });
