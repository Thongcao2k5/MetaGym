import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import pg from 'pg';

import { createApp } from '../src/app.js';
import { settleCoachHold } from '../src/services/coach-entitlements.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'coach-hold-integration-secret-32-characters';

test('Coach holds serialize the final seat and release it on expiry or cancellation',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const server = createApp({ database, jwtSecret: secret }).listen(0);
    const [admin, coach, first, second, outsider, ...existing] =
      Array.from({ length: 12 }, randomUUID);
    const members = [first, second, outsider, ...existing];
    const planId = randomUUID();
    const endpoint = '/coach-payment-holds';
    const tokens = new Map();
    async function call(member, path, method = 'GET', body, key) {
      const role = member === coach ? 'COACH' : member === admin ? 'ADMIN' : 'MEMBER';
      const bearer = jwt.sign({ role, sessionVersion: 0 }, secret, {
        algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
        subject: member, expiresIn: 3600,
      });
      const response = await fetch(`http://127.0.0.1:${server.address().port}/api/v1${path}`, {
        method,
        headers: { authorization: `Bearer ${tokens.get(member) ?? bearer}`,
          ...(key && { 'idempotency-key': key }),
          ...(body && { 'content-type': 'application/json' }) },
        body: body && JSON.stringify(body),
      });
      return { status: response.status, body: await response.json() };
    }
    try {
      const password = 'MobileFixture!928';
      const hash = await bcrypt.hash(password, 10);
      for (const [id, role] of [[admin, 'ADMIN'], [coach, 'COACH'],
        ...members.map((member) => [member, 'MEMBER'])]) {
        await database.query(
          `INSERT INTO users (id, email, password_hash, role, full_name)
           VALUES ($1, $2, $4, $3, 'Hold test')`, [id, `${id}@example.com`, role, hash],
        );
      }
      for (const member of members) {
        await database.query(
          'INSERT INTO member_profiles (user_id) VALUES ($1)', [member],
        );
      }
      for (const account of [admin, coach, first, second]) {
        const login = await call(account, '/auth/sessions', 'POST', {
          email: `${account}@example.com`, password,
        });
        assert.equal(login.status, 200, JSON.stringify(login.body));
        tokens.set(account, login.body.data.accessToken);
      }
      await database.query('INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 20)', [coach]);
      await database.query(
        `INSERT INTO membership_plans (id, name, price, duration_days, status, created_by)
         VALUES ($1, 'Gym fixture', 1, 30, 'ACTIVE', $2)`, [planId, admin],
      );
      for (const member of [first, second]) {
        const payment = randomUUID();
        await database.query(
          `INSERT INTO payments (id, member_id, plan_id, plan_name_snapshot,
           duration_days_snapshot, amount, method, status, transaction_code,
           idempotency_key, request_hash, created_by, confirmed_at, decided_at)
           VALUES ($1, $2, $3, 'Gym fixture', 30, 1, 'MOCK_QR', 'SUCCESS',
                   $1::uuid::text, $1::uuid::text, repeat('a', 64), $2, now(), now())`,
          [payment, member, planId],
        );
        await database.query(
          `INSERT INTO member_memberships (id, member_id, plan_id, source_payment_id,
           start_date, end_date, status, activated_at)
           VALUES ($1, $2, $3, $4, (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
             (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 29, 'ACTIVE', now())`,
          [randomUUID(), member, planId, payment],
        );
      }
      for (const [index, member] of existing.entries()) {
        await database.query(
          `INSERT INTO coach_relationships (id, member_id, coach_id, status, paused_at, pause_reason)
           VALUES ($1, $2, $3, $4::varchar, CASE WHEN $4 = 'PAUSED' THEN now() END,
             CASE WHEN $4 = 'PAUSED' THEN 'MEMBERSHIP_EXPIRED' END)`,
          [randomUUID(), member, coach, index === 0 ? 'PAUSED' : 'ACTIVE'],
        );
      }
      const offer = { coachId: coach, planCode: 'BASIC' };
      assert.equal((await call(first, '/coach-requests', 'POST', { coachId: coach })).status, 410);
      assert.equal((await call(first, '/meal-logs', 'POST', { mealName: 'Cũ' })).status, 410);
      assert.equal((await call(outsider, endpoint, 'POST', offer, randomUUID())).body.error.code,
        'MEMBERSHIP_REQUIRED');
      assert.equal((await call(first, endpoint, 'POST', offer, randomUUID())).body.error.code,
        'SCHEDULE_REQUIRED');
      await database.query(
        `INSERT INTO coach_weekly_slots (id, coach_id, weekday, start_minute)
         SELECT gen_random_uuid(), $1, day, minute
         FROM generate_series(1, 6) day CROSS JOIN generate_series(360, 630, 90) minute`, [coach],
      );
      assert.equal((await call(first, endpoint, 'POST', offer, randomUUID())).body.error.code,
        'HEALTH_DECLARATION_REQUIRED');
      for (const member of [first, second]) {
        const declaration = await call(member, '/users/me/health-declaration', 'PATCH', {
          heightCm: 172, weightKg: 70, bodyFatPercent: null,
          hasCondition: false, hasInjury: false,
        });
        assert.equal(declaration.status, 200, JSON.stringify(declaration.body));
        assert.ok(declaration.body.data.profile.healthDeclarationCompletedAt);
      }
      assert.equal((await call(first, '/users/me', 'PATCH', { weightKg: null })).status, 422);
      await database.query("UPDATE coach_package_plans SET status = 'ACTIVE', price = 123000 WHERE code = 'BASIC'");
      const keys = [randomUUID(), randomUUID()];
      const contenders = [first, second];
      const results = await Promise.all(contenders.map((id, i) =>
        call(id, endpoint, 'POST', offer, keys[i])));
      assert.deepEqual(results.map(({ status }) => status).sort(), [201, 409]);
      const winnerIndex = results.findIndex(({ status }) => status === 201);
      const winner = contenders[winnerIndex];
      const loser = contenders[1 - winnerIndex];
      assert.equal(results[1 - winnerIndex].body.error.code, 'COACH_FULL');
      const hold = results[winnerIndex].body.data;
      assert.equal((await call(loser, `/coaches/${coach}`)).body.data.usedSlots, 8);
      await database.query("UPDATE coach_package_plans SET price = 456000 WHERE code = 'BASIC'");
      const retry = await call(winner, endpoint, 'POST', offer, keys[winnerIndex]);
      assert.equal(retry.body.data.id, hold.id);
      assert.equal(retry.body.data.amount, 123000);
      assert.equal((await call(loser, `${endpoint}/${hold.id}/cancel`, 'POST')).status, 404);

      await database.query(
        `UPDATE coach_payment_holds SET created_at = now() - interval '16 minutes',
          expires_at = now() - interval '1 minute' WHERE id = $1`, [hold.id],
      );
      const expired = await call(winner, endpoint, 'POST', offer, keys[winnerIndex]);
      assert.equal(expired.body.data.status, 'EXPIRED');
      const secondHold = await call(loser, endpoint, 'POST', offer, randomUUID());
      assert.equal(secondHold.status, 201);
      assert.equal(secondHold.body.data.amount, 456000);
      const cancel = `${endpoint}/${secondHold.body.data.id}/cancel`;
      assert.equal((await call(loser, cancel, 'POST')).body.data.status, 'CANCELLED');
      assert.equal((await call(loser, cancel, 'POST')).body.data.status, 'CANCELLED');
      const lastHold = await call(winner, endpoint, 'POST', offer, randomUUID());
      assert.equal(lastHold.status, 201);
      const settled = await Promise.all([1, 2].map(() =>
        settleCoachHold(database, lastHold.body.data.id, { paid: true, amount: 456000 })));
      assert.equal(settled[0].status, 'CONSUMED');
      assert.deepEqual(settled[0], settled[1]);
      const foodCreate = await call(admin, '/admin/nutrition-foods', 'POST', {
        name: 'Fixture food', kcalPer100g: 100, active: true,
      });
      assert.equal(foodCreate.status, 201, JSON.stringify(foodCreate.body));
      const foodId = foodCreate.body.data.id;
      const mealPath = `/coach/meal-plans/${winner}`;
      const savedMeal = await call(coach, mealPath, 'PUT', {
        title: 'Thực đơn V2', items: [{ day: 1, meal: 'BREAKFAST', foodId, grams: 120 }],
      });
      assert.equal(savedMeal.status, 200, JSON.stringify(savedMeal.body));
      assert.deepEqual((await call(loser, '/meal-plans/me')).body.data, []);
      assert.equal((await call(admin, `/admin/nutrition-foods/${foodId}`, 'PATCH', {
        name: 'Fixture food', kcalPer100g: 150, active: false,
      })).status, 200);
      assert.equal((await call(winner, '/meal-plans/me')).body.data[0].items[0].kcalPer100g, 150);
      await database.query(
        `UPDATE nutrition_guides SET status = 'ARCHIVED', archived_at = now() WHERE id = $1`,
        [savedMeal.body.data.id],
      );
      await database.query('UPDATE nutrition_foods SET kcal_per_100g = 200 WHERE id = $1', [foodId]);
      assert.equal((await call(winner, '/meal-plans/me')).body.data[0].items[0].kcalPer100g, 150);
      const { rows: [slot] } = await database.query(
        `SELECT ((now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + day
           + time '06:00') AT TIME ZONE 'Asia/Ho_Chi_Minh' AS starts_at
         FROM generate_series(2, 8) day
         WHERE EXTRACT(ISODOW FROM (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + day) <= 6
         ORDER BY day LIMIT 1`,
      );
      const bookingPath = '/coach-bookings';
      const localDate = new Date(slot.starts_at.getTime() + 7 * 3600000).toISOString().slice(0, 10);
      const free = await call(winner,
        `${bookingPath}/available-slots?entitlementId=${settled[0].entitlementId}&date=${localDate}`);
      assert.equal(free.body.data.length, 4);
      const blocks = `${bookingPath}/blocks`;
      const startsAt = slot.starts_at.toISOString();
      assert.equal((await call(coach, blocks, 'PUT', { startsAt, blocked: true, reason: 'Bận' })).status, 200);
      assert.equal((await call(winner, bookingPath, 'POST', {
        entitlementId: settled[0].entitlementId, startsAt,
      })).body.error.code, 'SLOT_UNAVAILABLE');
      assert.equal((await call(coach, blocks, 'PUT', { startsAt, blocked: false })).status, 200);
      const bookingAttempts = await Promise.all([1, 2].map(() => call(winner, bookingPath, 'POST', {
        entitlementId: settled[0].entitlementId, startsAt: slot.starts_at.toISOString(),
      })));
      assert.deepEqual(bookingAttempts.map((entry) => entry.status).sort(), [201, 409]);
      const booked = bookingAttempts.find((entry) => entry.status === 201);
      assert.equal(booked.status, 201, JSON.stringify(booked.body));
      const inbox = await call(coach, '/coach-notifications');
      const bookingNotice = inbox.body.data.find((row) => row.subjectId === booked.body.data.id);
      assert.equal(bookingNotice.kind, 'BOOKED');
      const markRead = `/coach-notifications/${bookingNotice.id}/read`;
      assert.equal((await call(loser, markRead, 'PATCH')).status, 404);
      assert.ok((await call(coach, markRead, 'PATCH')).body.data.readAt);
      const duplicate = await call(winner, bookingPath, 'POST', {
        entitlementId: settled[0].entitlementId, startsAt: slot.starts_at.toISOString(),
      });
      assert.equal(duplicate.status, 409);
      assert.equal((await call(loser, bookingPath)).body.data.length, 0);
      const alternatives = await call(winner,
        `${bookingPath}/available-slots?entitlementId=${settled[0].entitlementId}&date=${localDate}&bookingId=${booked.body.data.id}`);
      assert.equal(alternatives.body.data.length, 3);
      const moved = await call(winner, `${bookingPath}/${booked.body.data.id}`, 'PATCH', {
        action: 'RESCHEDULE', startsAt: alternatives.body.data[0].startsAt,
      });
      assert.equal(moved.status, 200, JSON.stringify(moved.body));
      const cancelled = await call(winner, `${bookingPath}/${moved.body.data.id}`, 'PATCH',
        { action: 'CANCEL' });
      assert.equal(cancelled.body.data.status, 'CANCELLED');
      assert.equal(cancelled.body.data.chargedAt, null);
      const completedFixture = await call(winner, bookingPath, 'POST', {
        entitlementId: settled[0].entitlementId, startsAt: slot.starts_at.toISOString(),
      });
      assert.equal(completedFixture.status, 201);
      await database.query(
        `UPDATE coach_bookings SET starts_at = now() - interval '2 hours',
           ends_at = now() - interval '30 minutes' WHERE id = $1`, [completedFixture.body.data.id],
      );
      const completions = await Promise.all(Array.from({length: 2}, () =>
        call(coach, `${bookingPath}/${completedFixture.body.data.id}`, 'PATCH', { action: 'COMPLETE' })));
      assert.deepEqual(completions.map(({ status }) => status), [200, 200]);
      const { rows: [balance] } = await database.query(
        'SELECT remaining_sessions FROM coach_entitlements WHERE id = $1', [settled[0].entitlementId],
      );
      assert.equal(balance.remaining_sessions, 9);
      await database.query(
        `UPDATE coach_entitlements SET remaining_sessions = 1,
           starts_on = (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date - 27,
           original_ends_on = (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 2,
           ends_on = (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date + 2 WHERE id = $1`,
        [settled[0].entitlementId],
      );
      const renewal = await call(winner, endpoint, 'POST', offer, randomUUID());
      for (let attempt = 0; attempt < 2; attempt++) {
        const reminders = (await call(winner, '/coach-notifications')).body.data
          .filter((item) => item.kind === 'PACKAGE_EXPIRING');
        assert.equal(reminders.length, 1);
      }
      assert.equal(renewal.status, 201);
      assert.equal((await call(loser, `/coaches/${coach}`)).body.data.usedSlots, 8);
      assert.ok('avatarUrl' in (await call(loser, `/coaches/${coach}`)).body.data);
      assert.equal((await call(loser, `${endpoint}/${renewal.body.data.id}/mock-confirmations`, 'POST')).status, 404);
      const mockConfirmations = await Promise.all([1, 2].map(() =>
        call(winner, `${endpoint}/${renewal.body.data.id}/mock-confirmations`, 'POST')));
      assert.deepEqual(mockConfirmations.map((entry) => entry.status), [200, 200]);
      assert.equal(mockConfirmations[0].body.data.hold.status, 'CONSUMED');
      assert.equal(mockConfirmations[0].body.data.entitlementId, mockConfirmations[1].body.data.entitlementId);
      const queued = mockConfirmations[0].body.data;
      const myRel = await call(winner, '/relationships/me');
      assert.equal(myRel.status, 200);
      assert.equal(myRel.body.data.coachName, 'Hold test');
      assert.equal((await call(winner, endpoint, 'POST', offer, randomUUID())).body.error.code, 'QUEUED_EXISTS');
      await database.query(
        `UPDATE coach_entitlements SET starts_on = CURRENT_DATE - 38,
           original_ends_on = CURRENT_DATE - 9, ends_on = CURRENT_DATE - 2 WHERE id = $1`,
        [settled[0].entitlementId],
      );
      const { reconcileMembershipLifecycles } = await import('../src/services/membership-lifecycle.js');
      const lifecyclePool = new pg.Pool({ connectionString: databaseUrl });
      try {
        await reconcileMembershipLifecycles(lifecyclePool);
      } finally {
        await lifecyclePool.end();
      }
      const { rows: [ended] } = await database.query('SELECT status FROM coach_entitlements WHERE id = $1',
        [settled[0].entitlementId]);
      assert.equal(ended.status, 'ENDED');
      const { rows: [activated] } = await database.query('SELECT status FROM coach_entitlements WHERE id = $1',
        [queued.entitlementId]);
      assert.equal(activated.status, 'ACTIVE');
    } finally {
      await database.query('DELETE FROM nutrition_guides WHERE coach_id = $1', [coach]);
      await database.query("DELETE FROM nutrition_foods WHERE name = 'Fixture food'");
      await database.query('DELETE FROM coach_notifications WHERE user_id = ANY($1::uuid[])',
        [[coach, ...members]]);
      await database.query("UPDATE coach_package_plans SET status = 'INACTIVE', price = 0 WHERE code = 'BASIC'");
      await database.query('DELETE FROM coach_bookings WHERE coach_id = $1', [coach]);
      await database.query('DELETE FROM coach_slot_blocks WHERE coach_id = $1', [coach]);
      await database.query('DELETE FROM coach_entitlements WHERE coach_id = $1', [coach]);
      await database.query('DELETE FROM coach_payment_holds WHERE coach_id = $1', [coach]);
      await database.query('DELETE FROM coach_weekly_slots WHERE coach_id = $1', [coach]);
      await database.query('DELETE FROM coach_relationships WHERE coach_id = $1', [coach]);
      await database.query('DELETE FROM member_memberships WHERE plan_id = $1', [planId]);
      await database.query('DELETE FROM payments WHERE plan_id = $1', [planId]);
      await database.query('DELETE FROM membership_plans WHERE id = $1', [planId]);
      await database.query('DELETE FROM coach_profiles WHERE user_id = $1', [coach]);
      await database.query('DELETE FROM member_profiles WHERE user_id = ANY($1::uuid[])', [members]);
      await database.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [[admin, coach, ...members]]);
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });
