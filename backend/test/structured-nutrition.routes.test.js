import assert from 'node:assert/strict';
import test from 'node:test';
import express from 'express';
import jwt from 'jsonwebtoken';
import { createStructuredNutritionRouter } from '../src/routes/structured-nutrition.routes.js';

const coachId = '11111111-1111-4111-8111-111111111111';
const memberId = '22222222-2222-4222-8222-222222222222';
const relId = '33333333-3333-4333-8333-333333333333';
const foodId = '44444444-4444-4444-8444-444444444444';
const secret = 'structured-nutrition-test-secret-32c';

async function fixture(t) {
  let guideRow = null;
  const foods = [{ id: foodId, name: 'Ức gà áp chảo', kcal: 165, active: true }];

  const database = {
    async query(sql, args = []) {
      if (sql.includes('FROM users u')) {
        return {
          rows: [{
            id: args[0],
            role: args[0] === memberId ? 'MEMBER' : 'COACH',
            status: 'ACTIVE',
            session_version: 0,
          }],
        };
      }
      if (sql.includes('FROM coach_relationships') && sql.includes('FOR UPDATE')) {
        return { rows: [{ id: relId }] };
      }
      if (sql.includes('SELECT id, content, meal_items FROM nutrition_guides')) {
        return { rows: guideRow ? [guideRow] : [] };
      }
      if (sql.includes('FROM nutrition_foods WHERE id = ANY')) {
        return { rows: foods.filter((f) => args[0].includes(f.id)) };
      }
      if (sql.startsWith('UPDATE nutrition_guides SET title')) {
        guideRow = {
          ...guideRow,
          id: args[0],
          title: args[1],
          content: args[2],
          meal_items: JSON.parse(args[3]),
        };
        return { rows: [] };
      }
      if (sql.includes('INSERT INTO nutrition_guides')) {
        guideRow = {
          id: args[0],
          relationshipId: args[1],
          title: args[4],
          content: args[5],
          status: 'ACTIVE',
          meal_items: JSON.parse(args[6]),
        };
        return { rows: [] };
      }
      if (sql.includes('SELECT g.id, g.title, g.content, g.status, g.meal_items')) {
        return { rows: guideRow ? [guideRow] : [] };
      }
      if (sql.includes('FROM nutrition_guides WHERE member_id')) {
        return { rows: guideRow ? [guideRow] : [] };
      }
      return { rows: [] };
    },
    async connect() {
      return {
        query: this.query.bind(this),
        release() {},
      };
    },
  };

  const app = express();
  app.use(express.json(), createStructuredNutritionRouter({ database, jwtSecret: secret }));
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const token = (id, role) =>
    jwt.sign({ role, sessionVersion: 0 }, secret, {
      subject: id,
      audience: 'meta-gym-clients',
      issuer: 'meta-gym-api',
      expiresIn: 60,
    });

  return {
    async call(path, { id = coachId, role = 'COACH', method = 'GET', body } = {}) {
      const res = await fetch(`http://127.0.0.1:${server.address().port}${path}`, {
        method,
        headers: {
          authorization: `Bearer ${token(id, role)}`,
          'content-type': 'application/json',
        },
        ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
      });
      return { status: res.status, body: await res.json() };
    },
  };
}

test('PUT and GET /coach/meal-plans & /meal-plans/me support notes and SNACK meals', async (t) => {
  const api = await fixture(t);

  const saved = await api.call(`/coach/meal-plans/${memberId}`, {
    method: 'PUT',
    body: {
      title: 'Thực đơn Tuần 4',
      notes: 'Uống tối thiểu 2,5L nước/ngày.\nƯu tiên hấp hoặc luộc.',
      items: [
        { day: 1, meal: 'LUNCH', foodId, grams: 200 },
        { day: 1, meal: 'SNACK', foodId, grams: 100 },
      ],
    },
  });
  assert.equal(saved.status, 200, JSON.stringify(saved.body));
  assert.equal(saved.body.data.notes, 'Uống tối thiểu 2,5L nước/ngày.\nƯu tiên hấp hoặc luộc.');
  assert.equal(saved.body.data.items.length, 2);

  // Subsequent item-only update omits notes -> preserves existing notes
  const itemUpdate = await api.call(`/coach/meal-plans/${memberId}`, {
    method: 'PUT',
    body: {
      title: 'Thực đơn Tuần 4 (cập nhật)',
      items: [{ day: 1, meal: 'DINNER', foodId, grams: 180 }],
    },
  });
  assert.equal(itemUpdate.status, 200);
  assert.equal(itemUpdate.body.data.notes, 'Uống tối thiểu 2,5L nước/ngày.\nƯu tiên hấp hoặc luộc.');

  const coachView = await api.call(`/coach/meal-plans/${memberId}`);
  assert.equal(coachView.status, 200);
  assert.equal(coachView.body.data.notes, 'Uống tối thiểu 2,5L nước/ngày.\nƯu tiên hấp hoặc luộc.');

  const memberView = await api.call('/meal-plans/me', { id: memberId, role: 'MEMBER' });
  assert.equal(memberView.status, 200);
  assert.equal(memberView.body.data[0].notes, 'Uống tối thiểu 2,5L nước/ngày.\nƯu tiên hấp hoặc luộc.');

  // Clearing notes explicitly sets null
  const cleared = await api.call(`/coach/meal-plans/${memberId}`, {
    method: 'PUT',
    body: {
      title: 'Thực đơn Tuần 4 (không ghi chú)',
      notes: '',
      items: [{ day: 1, meal: 'BREAKFAST', foodId, grams: 150 }],
    },
  });
  assert.equal(cleared.status, 200);
  assert.equal(cleared.body.data.notes, null);
});
