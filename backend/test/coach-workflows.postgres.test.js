import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';
import jwt from 'jsonwebtoken';
import pg from 'pg';
import { createApp } from '../src/app.js';
import { settleCoachHold } from '../src/services/coach-entitlements.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'coach-workflow-compatibility-test-secret-2026';

test('Coach compatibility restores authenticated workflows and coexists with V2 packages',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const admin = randomUUID();
    const coach = randomUUID();
    const otherCoach = randomUUID();
    const members = Array.from({ length: 3 }, randomUUID);
    const everyone = [admin, coach, otherCoach, ...members];
    const gymPlan = randomUUID();
    const exercise = randomUUID();
    let originalPackage;
    const servers = [
      createApp({ database, jwtSecret: secret, enableCoachWorkflows: true }).listen(0),
      createApp({ database, jwtSecret: secret }).listen(0),
    ];
    function token(user) {
      return jwt.sign({ role: [coach, otherCoach].includes(user) ? 'COACH' : 'MEMBER', sessionVersion: 0 }, secret,
        { algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api', subject: user, expiresIn: '10m' });
    }
    async function call(user, route, method = 'GET', body, { server = servers[0], key } = {}) {
      const response = await fetch(`http://127.0.0.1:${server.address().port}/api/v1${route}`, {
        method, headers: { ...(user ? { Authorization: `Bearer ${token(user)}` } : {}),
          'Content-Type': 'application/json', ...(key ? { 'Idempotency-Key': key } : {}) },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
      return { status: response.status, body: await response.json() };
    }
    const day = (offset, time) => {
      const d = new Date();
      d.setUTCDate(d.getUTCDate() + offset);
      return `${d.toISOString().slice(0, 10)}T${time}:00+07:00`;
    };
    try {
      originalPackage = (await database.query("SELECT status,price FROM coach_package_plans WHERE code='BASIC'")).rows[0];
      await database.query("UPDATE coach_package_plans SET status='ACTIVE',price=123000 WHERE code='BASIC'");
      for (const [user, role] of [[admin, 'ADMIN'], [coach, 'COACH'], [otherCoach, 'COACH'], ...members.map((m) => [m, 'MEMBER'])]) {
        await database.query('INSERT INTO users (id,email,password_hash,role,full_name) VALUES ($1,$2,\'hash\',$3,$3)',
          [user, `${user}@example.com`, role]);
      }
      for (const user of [coach, otherCoach]) await database.query(
        'INSERT INTO coach_profiles (user_id,member_limit) VALUES ($1,2)', [user]);
      await database.query(`INSERT INTO coach_weekly_slots (id,coach_id,weekday,start_minute)
        SELECT gen_random_uuid(),$1,d,m FROM generate_series(1,7) d CROSS JOIN generate_series(480,750,90) m`, [coach]);
      await database.query(`INSERT INTO membership_plans (id,name,price,duration_days,status,created_by)
        VALUES ($1,'Workflow fixture',100,30,'ACTIVE',$2)`, [gymPlan, admin]);
      await database.query(`INSERT INTO exercises (id,name,instructions,status,created_by)
        VALUES ($1,'Workflow squat','Controlled movement','ACTIVE',$2)`, [exercise, admin]);
      for (const member of members) {
        await database.query(`INSERT INTO member_profiles (user_id,health_declaration_completed_at)
          VALUES ($1,now())`, [member]);
        const payment = randomUUID();
        await database.query(`INSERT INTO payments (id,member_id,plan_id,plan_name_snapshot,duration_days_snapshot,
          amount,method,status,transaction_code,idempotency_key,request_hash,created_by,confirmed_at,decided_at)
          VALUES ($1,$2,$3,'Fixture',30,100,'MOCK_QR','SUCCESS',$1::uuid::text,$1::uuid::text,repeat('a',64),$2,now(),now())`,
        [payment, member, gymPlan]);
        await database.query(`INSERT INTO member_memberships (id,member_id,plan_id,source_payment_id,
          start_date,end_date,status,activated_at) VALUES ($1,$2,$3,$4,
          (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
          (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date+29,'ACTIVE',now())`,
        [randomUUID(), member, gymPlan, payment]);
      }
      assert.equal((await call(members[0], '/coach-requests', 'POST', { coachId: coach }, { server: servers[1] })).status, 410);
      assert.equal((await call(null, '/coach-requests', 'POST', { coachId: coach })).status, 401);
      assert.equal((await call(members[0], '/workout-logs', 'POST', {})).status, 410);
      assert.equal((await call(coach, '/coach-requests', 'POST', { coachId: otherCoach })).status, 403);

      const submitted = await call(members[0], '/coach-requests', 'POST', { coachId: coach, message: 'Workflow fixture' });
      assert.equal(submitted.status, 201, JSON.stringify(submitted.body));
      const requestId = submitted.body.data.id;
      assert.equal((await call(otherCoach, `/coach/requests/${requestId}`, 'PATCH', { decision: 'ACCEPTED' })).status, 404);
      const accepted = await call(coach, `/coach/requests/${requestId}`, 'PATCH', { decision: 'ACCEPTED' });
      assert.equal(accepted.status, 200, JSON.stringify(accepted.body));
      const relationship = accepted.body.data.relationship.id;
      assert.equal((await call(coach, `/coach/requests/${requestId}`, 'PATCH', { decision: 'ACCEPTED' })).status, 404);
      assert.equal((await database.query('SELECT count(*)::int AS n FROM coach_relationships WHERE member_id=$1', [members[0]])).rows[0].n, 1);
      const second = await call(members[1], '/coach-requests', 'POST', { coachId: coach });
      const secondId = second.body.data.id;
      assert.equal((await call(coach, `/coach/requests/${secondId}`, 'PATCH', { decision: 'REJECTED' })).status, 422);
      assert.equal((await call(coach, `/coach/requests/${secondId}`, 'PATCH', { decision: 'REJECTED', reason: 'Schedule mismatch' })).status, 200);
      const again = await call(members[1], '/coach-requests', 'POST', { coachId: coach });
      assert.equal((await call(coach, `/coach/requests/${again.body.data.id}`, 'PATCH', { decision: 'ACCEPTED' })).status, 200);
      const third = await call(members[2], '/coach-requests', 'POST', { coachId: coach });
      assert.equal((await call(coach, `/coach/requests/${third.body.data.id}`, 'PATCH', { decision: 'ACCEPTED' })).body.error.code, 'COACH_FULL');

      const payload = { title: 'Draft workflow', days: [{ dayNumber: 1, title: 'Day 1', exercises: [
        { exerciseId: exercise, displayOrder: 1, sets: 3, reps: '10', restSeconds: 60 },
      ] }] };
      assert.equal((await call(otherCoach, `/coach/members/${members[0]}/training-plans`, 'POST', payload)).status, 403);
      const draft = await call(coach, `/coach/members/${members[0]}/training-plans`, 'POST', payload);
      assert.equal(draft.status, 201, JSON.stringify(draft.body));
      const planId = draft.body.data.id;
      assert.equal((await call(members[0], `/training-plans/${planId}`)).status, 404);
      assert.equal((await call(coach, `/coach/training-plans/${planId}`, 'PATCH', { title: 'Edited draft' })).status, 200);
      assert.equal((await call(otherCoach, `/coach/training-plans/${planId}/publications`, 'POST', {})).status, 404);
      const published = await call(coach, `/coach/training-plans/${planId}/publications`, 'POST', {});
      assert.equal(published.status, 200, JSON.stringify(published.body));
      assert.equal(published.body.data.status, 'ACTIVE');
      assert.equal((await call(members[0], '/training-plans/me/active')).body.data.id, planId);
      assert.equal((await call(coach, `/coach/training-plans/${planId}`, 'PATCH', { title: 'Change published' })).status, 409);

      const guide = await call(coach, `/coach/members/${members[0]}/nutrition-guides`, 'POST', { title: 'Draft meals', content: 'Fixture nutrition' });
      assert.equal(guide.status, 201, JSON.stringify(guide.body));
      const guideId = guide.body.data.id;
      assert.equal((await call(otherCoach, `/coach/nutrition-guides/${guideId}`, 'PATCH', { publish: true })).status, 404);
      const guidePublished = await call(coach, `/coach/nutrition-guides/${guideId}`, 'PATCH', { content: 'Published fixture', publish: true });
      assert.equal(guidePublished.status, 200, JSON.stringify(guidePublished.body));
      assert.equal((await call(members[0], '/nutrition-guides/me/active')).body.data.id, guideId);
      assert.equal((await call(coach, `/coach/nutrition-guides/${guideId}`, 'PATCH', { content: 'Invalid published edit' })).status, 409);

      const sessionPayload = { memberId: members[0], title: 'Scheduled fixture', scheduledStartAt: day(1, '10:00'), scheduledEndAt: day(1, '11:30') };
      assert.equal((await call(otherCoach, '/coach/training-sessions', 'POST', sessionPayload)).status, 403);
      const session = await call(coach, '/coach/training-sessions', 'POST', sessionPayload);
      assert.equal(session.status, 201, JSON.stringify(session.body));
      const sessionId = session.body.data.id;
      const changed = await call(coach, `/coach/training-sessions/${sessionId}`, 'PATCH', {
        scheduledStartAt: day(2, '10:00'), scheduledEndAt: day(2, '11:30') });
      assert.equal(changed.status, 200, JSON.stringify(changed.body));
      const overlap = await call(coach, '/coach/training-sessions', 'POST', {
        ...sessionPayload, memberId: members[1], scheduledStartAt: day(2, '10:30'), scheduledEndAt: day(2, '12:00') });
      assert.equal(overlap.status, 409, JSON.stringify(overlap.body));
      assert.equal((await call(coach, `/coach/training-sessions/${sessionId}`, 'PATCH', { status: 'COMPLETED' })).status, 200);
      assert.equal((await call(coach, `/coach/training-sessions/${sessionId}`, 'PATCH', { title: 'Already complete' })).status, 409);

      // An accepted member already occupies a seat even at full capacity. Their first paid PT
      // package must become ACTIVE on that relationship, not be rejected or queued forever.
      const createHold = () => call(members[0], '/coach-payment-holds', 'POST', { coachId: coach, planCode: 'BASIC' }, { key: randomUUID() });
      const wrongAmountHold = await createHold();
      assert.equal(wrongAmountHold.status, 201, JSON.stringify(wrongAmountHold.body));
      const failed = await settleCoachHold(database, wrongAmountHold.body.data.id, {
        paid: true, amount: wrongAmountHold.body.data.amount + 1 });
      assert.equal(failed.reason, 'AMOUNT_MISMATCH');
      assert.equal((await database.query('SELECT count(*)::int AS n FROM coach_entitlements WHERE member_id=$1', [members[0]])).rows[0].n, 0);
      const hold = await createHold();
      assert.equal(hold.status, 201, JSON.stringify(hold.body));
      const settled = await settleCoachHold(database, hold.body.data.id, { paid: true, amount: hold.body.data.amount });
      assert.equal(settled.status, 'CONSUMED');
      const entitlement = (await database.query('SELECT * FROM coach_entitlements WHERE id=$1', [settled.entitlementId])).rows[0];
      assert.equal(entitlement.status, 'ACTIVE');
      assert.equal(entitlement.relationship_id, relationship);
      assert.equal((await settleCoachHold(database, hold.body.data.id, { paid: true, amount: hold.body.data.amount })).entitlementId, entitlement.id);
      assert.equal((await database.query('SELECT count(*)::int AS n FROM coach_relationships WHERE member_id=$1', [members[0]])).rows[0].n, 1);
      assert.equal((await database.query('SELECT count(*)::int AS n FROM coach_entitlements WHERE member_id=$1', [members[0]])).rows[0].n, 1);
      assert.equal((await call(members[0], '/coach-payment-holds', 'POST', { coachId: otherCoach, planCode: 'BASIC' }, { key: randomUUID() })).body.error.code, 'RELATIONSHIP_EXISTS');
      const date = day(5, '08:00').slice(0, 10);
      const available = await call(members[0], `/coach-bookings/available-slots?entitlementId=${entitlement.id}&date=${date}`);
      assert.equal(available.status, 200);
      assert(available.body.data.length > 0);
      const ptSlot = available.body.data[0];
      const booked = await call(members[0], '/coach-bookings', 'POST', { entitlementId: entitlement.id, startsAt: ptSlot.startsAt });
      assert.equal(booked.status, 201, JSON.stringify(booked.body));
      const ptConflict = await call(coach, '/coach/training-sessions', 'POST', {
        memberId: members[1], title: 'Must not overlap PT', scheduledStartAt: ptSlot.startsAt, scheduledEndAt: ptSlot.endsAt });
      assert.equal(ptConflict.status, 409, JSON.stringify(ptConflict.body));
      const movable = await call(coach, '/coach/training-sessions', 'POST', {
        ...sessionPayload, scheduledStartAt: day(4, '17:00'), scheduledEndAt: day(4, '18:30') });
      assert.equal(movable.status, 201, JSON.stringify(movable.body));
      const moveConflict = await call(coach, `/coach/training-sessions/${movable.body.data.id}`, 'PATCH', {
        scheduledStartAt: ptSlot.startsAt, scheduledEndAt: ptSlot.endsAt });
      assert.equal(moveConflict.status, 409, JSON.stringify(moveConflict.body));
      const unchanged = await call(coach, `/training-sessions/${movable.body.data.id}`);
      assert.equal(new Date(unchanged.body.data.scheduledStartAt).getTime(), new Date(day(4, '17:00')).getTime());
    } finally {
      await Promise.all(servers.map((server) => new Promise((resolve) => server.close(resolve))));
      await database.query('DELETE FROM coach_notifications WHERE user_id=ANY($1::uuid[])', [everyone]);
      await database.query('DELETE FROM coach_bookings WHERE member_id=ANY($1::uuid[])', [members]);
      await database.query('DELETE FROM coach_entitlements WHERE member_id=ANY($1::uuid[])', [members]);
      await database.query('DELETE FROM coach_payment_holds WHERE member_id=ANY($1::uuid[])', [members]);
      await database.query('DELETE FROM training_sessions WHERE member_id=ANY($1::uuid[])', [members]);
      await database.query('DELETE FROM nutrition_guides WHERE member_id=ANY($1::uuid[])', [members]);
      for (const table of ['training_plan_day_meals', 'training_plan_exercises']) await database.query(
        `DELETE FROM ${table} WHERE plan_day_id IN (SELECT d.id FROM training_plan_days d JOIN training_plans p ON p.id=d.plan_id WHERE p.member_id=ANY($1::uuid[]))`, [members]);
      await database.query('DELETE FROM training_plan_days WHERE plan_id IN (SELECT id FROM training_plans WHERE member_id=ANY($1::uuid[]))', [members]);
      await database.query('DELETE FROM training_plans WHERE member_id=ANY($1::uuid[])', [members]);
      await database.query('DELETE FROM conversation_participants WHERE user_id=ANY($1::uuid[])', [everyone]);
      await database.query('DELETE FROM conversations WHERE member_id=ANY($1::uuid[])', [members]);
      await database.query('DELETE FROM coach_relationships WHERE member_id=ANY($1::uuid[])', [members]);
      await database.query('DELETE FROM coach_requests WHERE member_id=ANY($1::uuid[])', [members]);
      await database.query('DELETE FROM member_memberships WHERE member_id=ANY($1::uuid[])', [members]);
      await database.query('DELETE FROM payments WHERE member_id=ANY($1::uuid[])', [members]);
      await database.query('DELETE FROM member_profiles WHERE user_id=ANY($1::uuid[])', [members]);
      await database.query('DELETE FROM coach_weekly_slots WHERE coach_id=ANY($1::uuid[])', [[coach, otherCoach]]);
      await database.query('DELETE FROM coach_profiles WHERE user_id=ANY($1::uuid[])', [[coach, otherCoach]]);
      await database.query('DELETE FROM exercises WHERE id=$1', [exercise]);
      await database.query('DELETE FROM membership_plans WHERE id=$1', [gymPlan]);
      await database.query('DELETE FROM users WHERE id=ANY($1::uuid[])', [everyone]);
      if (originalPackage) await database.query("UPDATE coach_package_plans SET status=$1,price=$2 WHERE code='BASIC'", [originalPackage.status, originalPackage.price]);
      await database.end();
    }
  });
