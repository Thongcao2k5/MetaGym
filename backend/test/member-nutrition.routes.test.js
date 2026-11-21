import assert from 'node:assert/strict';
import test from 'node:test';
import express from 'express';
import jwt from 'jsonwebtoken';
import { createMemberNutritionRouter, vietnamDate } from '../src/routes/member-nutrition.routes.js';

const member = '11111111-1111-4111-8111-111111111111';
const foodA = '22222222-2222-4222-8222-222222222222';
const foodB = '33333333-3333-4333-8333-333333333333';
const secret = 'nutrition-test-secret-with-32-characters';
async function fixture(t, {
  role = 'MEMBER', active = false, failSave = false, failFoods = false,
  editable = true, owned = true, existingFoodId = null, foods = {},
} = {}) {
  const calls = [];
  const database = {
    async query(sql, args = []) {
      calls.push({ sql, args });
      if (sql.includes('FROM users u')) return { rows: [{ id: member, role, status: 'ACTIVE', session_version: 0 }] };
      if (sql.includes('FROM nutrition_foods WHERE active')) {
        if (failFoods) throw Error('db unavailable');
        return { rows: Object.values(foods).filter(f => f.active) };
      }
      if (sql.includes('FROM nutrition_foods') && sql.includes('WHERE id=$1')) {
        const found = foods[args[0]];
        return { rows: found ? [found] : [] };
      }
      if (sql.startsWith('SELECT plan_snapshot')) return { rows: [{ plan_snapshot: null }] };
      if (sql.startsWith('SELECT 1 FROM member_memberships')) return { rows: active ? [{ yes: 1 }] : [] };
      if (sql.startsWith('INSERT INTO meal_logs') && failSave) throw Error('disk failure');
      if (sql.startsWith('SELECT *,') && sql.includes('FROM meal_logs')) return { rows: owned ? [{ editable, food_id: existingFoodId }] : [] };
      if (/^(INSERT INTO meal_logs|UPDATE meal_logs|DELETE FROM meal_logs)/.test(sql)) return { rows: [{id:member}] };
      return { rows: [] };
    },
    async connect() { return { query: this.query.bind(this), release() {} }; },
  };
  const app = express();
  app.use(express.json(), createMemberNutritionRouter({ database, jwtSecret: secret }));
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const bearer = jwt.sign({ role, sessionVersion: 0 }, secret, {
    subject: member, audience: 'meta-gym-clients', issuer: 'meta-gym-api', expiresIn: 60,
  });
  return { calls, async call(path, body, method = body ? 'POST' : 'GET') {
    const res = await fetch(`http://127.0.0.1:${server.address().port}/member/nutrition/${path}`, {
      method, headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    return { status: res.status, body: await res.json() };
  } };
}
for (const role of ['COACH', 'ADMIN']) test(`${role} cannot read diary, comparison or foods`, async t => {
  const api = await fixture(t, { role });
  assert.equal((await api.call('day')).status, 403);
  assert.equal((await api.call('foods')).status, 403);
  assert.equal(api.calls.some(c => c.sql.includes('FROM meal_logs')), false);
});
test('today can be edited/deleted; past and other owners are locked on server', async t => {
  const payload = { eatenAt: `${vietnamDate()}T09:00:00+07:00`, mealType: 'BREAKFAST', mealName: 'Rice', quantity: 2, unit: 'portion' };
  const today = await fixture(t,{active:true});
  assert.equal((await today.call(`entries/${member}`,payload,'PATCH')).status,200);
  assert.equal((await today.call(`entries/${member}`,undefined,'DELETE')).status,200);
  const past = await fixture(t,{active:true,editable:false});
  for (const method of ['PATCH','DELETE']) {
    const result=await past.call(`entries/${member}`,method==='PATCH' ? payload : undefined,method);
    assert.equal(result.status,409);
    assert.equal(result.body.error.code,'DAY_LOCKED');
  }
  assert.equal(past.calls.some(c=>/^(UPDATE meal_logs|DELETE FROM meal_logs)/.test(c.sql)),false);
  const outsider = await fixture(t,{active:true,owned:false});
  assert.equal((await outsider.call(`entries/${member}`,payload,'PATCH')).status,404);
  assert.equal((await outsider.call(`entries/${member}`,undefined,'DELETE')).status,404);
  assert.equal((await today.call('entries',{...payload,eatenAt:'2020-01-01T09:00:00+07:00'})).status,409);
  const expired = await fixture(t);
  assert.equal((await expired.call(`entries/${member}`,payload,'PATCH')).status,403);
  assert.equal((await expired.call(`entries/${member}`,undefined,'DELETE')).status,403);
});
test('expired membership retains owner-only history and rejects write', async t => {
  const api = await fixture(t);
  const day = await api.call('day');
  assert.equal(day.status, 200);
  assert.equal(day.body.data.canWrite, false);
  assert.equal(day.body.data.plan, null);
  assert(api.calls.filter(c => c.sql.includes('FROM meal_logs')).every(c => c.args[0] === member));
  const date = vietnamDate();
  assert.equal((await api.call('entries', { eatenAt: `${date}T09:00:00+07:00`, mealType: 'BREAKFAST', mealName: 'Rice', quantity: 1, unit: 'portion' })).status, 403);
  assert.equal((await api.call(`day?date=${date}&memberId=${member}`)).status, 422);
});
test('free text saves without invented calories; storage errors remain retryable', async t => {
  const api = await fixture(t, { active: true });
  const payload = { eatenAt: `${vietnamDate()}T09:00:00+07:00`, mealType: 'BREAKFAST', mealName: 'Rice', quantity: 1, unit: 'portion' };
  assert.equal((await api.call('entries', payload)).status, 201);
  const insert = api.calls.find(c => c.sql.startsWith('INSERT INTO meal_logs'));
  assert.equal(insert.args[1], member);
  assert.equal(insert.args[8], null);
  const failing = await fixture(t, { active: true, failSave: true });
  assert.equal((await failing.call('entries', payload)).body.error.code, 'SAVE_FAILED');
  assert(failing.calls.some(c => c.sql === 'ROLLBACK'));
});
test('quantity below 0.01 fails cleanly with 422 instead of 500', async t => {
  const api = await fixture(t, { active: true });
  const base = { eatenAt: `${vietnamDate()}T09:00:00+07:00`, mealType: 'BREAKFAST', mealName: 'Rice', unit: 'g' };
  for (const quantity of [0, 0.001, 0.004, 10000.01]) {
    const post = await api.call('entries', { ...base, quantity });
    assert.equal(post.status, 422);
    assert.equal(post.body.error.code, 'VALIDATION_ERROR');
    const patch = await api.call(`entries/${member}`, { ...base, quantity }, 'PATCH');
    assert.equal(patch.status, 422);
    assert.equal(patch.body.error.code, 'VALIDATION_ERROR');
  }
  assert.equal(api.calls.some(c => /^(INSERT INTO meal_logs|UPDATE meal_logs)/.test(c.sql)), false);
  assert.equal((await api.call('entries', { ...base, quantity: 0.01 })).status, 201);
});
test('PATCH preserves already-attached deactivated foodId while POST and foodId switch require active', async t => {
  const foods = {
    [foodA]: { id: foodA, name: 'Yến mạch cũ', kcal_per_100g: 380, active: false },
    [foodB]: { id: foodB, name: 'Ức gà', kcal_per_100g: 165, active: true },
  };
  const base = { eatenAt: `${vietnamDate()}T09:00:00+07:00`, mealType: 'BREAKFAST', mealName: 'ignored', quantity: 120, unit: 'g' };
  const api = await fixture(t, { active: true, existingFoodId: foodA, foods });
  assert.equal((await api.call('entries', { ...base, foodId: foodA })).status, 422);
  assert.equal((await api.call('entries', { ...base, foodId: foodB })).status, 201);
  assert.equal((await api.call(`entries/${member}`, { ...base, foodId: foodA, unit: 'phần' }, 'PATCH')).status, 422);
  const kept = await api.call(`entries/${member}`, { ...base, foodId: foodA }, 'PATCH');
  assert.equal(kept.status, 200);
  const update = api.calls.find(c => c.sql.startsWith('UPDATE meal_logs'));
  assert.equal(update.args[4], 'Yến mạch cũ');
  assert.equal(update.args[8], 380);
  const switched = await fixture(t, { active: true, existingFoodId: foodB, foods });
  assert.equal((await switched.call(`entries/${member}`, { ...base, foodId: foodA }, 'PATCH')).status, 422);
});
test('GET /member/nutrition/foods returns standard 500 JSON envelope on DB failure', async t => {
  const api = await fixture(t, { failFoods: true });
  const res = await api.call('foods');
  assert.equal(res.status, 500);
  assert.equal(res.body.error.code, 'INTERNAL_SERVER_ERROR');
  assert.equal(typeof res.body.error.message, 'string');
  assert.deepEqual(res.body.error.details, {});
});
