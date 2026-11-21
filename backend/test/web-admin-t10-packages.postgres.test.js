import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';
import { settleCoachHold } from '../src/services/coach-entitlements.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'web-admin-t10-packages-secret-32-characters';

function token(id, role, sessionVersion = 0) {
  return jwt.sign({ role, sessionVersion }, secret, {
    algorithm: 'HS256',
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    subject: id,
    expiresIn: 3600,
  });
}

async function call(base, path, bearer, method = 'GET', body, headers = {}) {
  const response = await fetch(`${base}/api/v1${path}`, {
    method,
    headers: {
      ...(bearer ? { authorization: `Bearer ${bearer}` } : {}),
      ...headers,
      ...(body === undefined ? {} : { 'content-type': 'application/json' }),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: response.status, body: await response.json() };
}

test('T10: Gym plan editable after purchase, Coach package full CRUD, snapshot entitlements, QUEUED horizon >190d, admin memberships/entitlements',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const app = createApp({ database, jwtSecret: secret });
    const server = app.listen(0);
    const base = `http://127.0.0.1:${server.address().port}`;

    const adminId = randomUUID();
    const coachId = randomUUID();
    const memberId = randomUUID();
    const adminToken = token(adminId, 'ADMIN');
    const memberToken = token(memberId, 'MEMBER');
    let gymPlanId;
    const createdPackageCodes = [];

    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'ADMIN', 'Admin T10'),
                ($3, $4, 'hash', 'COACH', 'Coach T10'),
                ($5, $6, 'hash', 'MEMBER', 'Nguyễn Lan Anh')`,
        [
          adminId, `${adminId}@example.com`,
          coachId, `${coachId}@example.com`,
          memberId, `lananh-${memberId}@example.com`,
        ],
      );
      await database.query('INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 8)', [coachId]);
      await database.query(
        `INSERT INTO member_profiles (user_id, height_cm, weight_kg, health_declaration_completed_at)
         VALUES ($1, 165, 58, now())`,
        [memberId],
      );
      // 6 workdays x 4 slots/day for Coach
      await database.query(
        `INSERT INTO coach_weekly_slots (id, coach_id, weekday, start_minute)
         SELECT gen_random_uuid(), $1, d, m
         FROM generate_series(1, 6) d CROSS JOIN generate_series(360, 630, 90) m`,
        [coachId],
      );

      // 1. Gym plan CRUD: editable price & durationDays even after SUCCESS payment (S2)
      const gymCreate = await call(base, '/admin/membership-plans', adminToken, 'POST', {
        name: 'Gói T10 Cơ Bản', description: 'Mô tả ban đầu', price: 500000, durationDays: 30, status: 'ACTIVE',
      });
      assert.equal(gymCreate.status, 201);
      gymPlanId = gymCreate.body.data.id;

      const deskPay1 = await call(
        base,
        '/admin/front-desk-payments',
        adminToken,
        'POST',
        { memberId, planId: gymPlanId },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(deskPay1.status, 201);
      assert.equal(deskPay1.body.data.payment.amount, 500000);
      assert.equal(deskPay1.body.data.payment.durationDays, 30);

      // Edit price & durationDays after SUCCESS payment -> MUST succeed (no 409 PLAN_TERMS_LOCKED)
      const gymPatch = await call(base, `/admin/membership-plans/${gymPlanId}`, adminToken, 'PATCH', {
        name: 'Gói T10 Nâng Cấp', price: 650000, durationDays: 45,
      });
      assert.equal(gymPatch.status, 200, JSON.stringify(gymPatch.body));
      assert.equal(gymPatch.body.data.price, 650000);
      assert.equal(gymPatch.body.data.durationDays, 45);

      // Old payment retains original snapshot
      const oldPayRow = (await database.query(
        'SELECT plan_name_snapshot, duration_days_snapshot, amount FROM payments WHERE id = $1',
        [deskPay1.body.data.payment.id],
      )).rows[0];
      assert.equal(oldPayRow.plan_name_snapshot, 'Gói T10 Cơ Bản');
      assert.equal(oldPayRow.duration_days_snapshot, 30);
      assert.equal(Number(oldPayRow.amount), 500000);

      // GET /admin/membership-plans filters & returns activeMembershipCount / scheduledMembershipCount
      const gymPlansList = await call(base, '/admin/membership-plans?status=ACTIVE&search=N%C3%A2ng%20C%E1%BA%A5p', adminToken);
      assert.equal(gymPlansList.status, 200);
      assert.equal(gymPlansList.body.pagination.totalItems, 1);
      assert.equal(gymPlansList.body.data[0].activeMembershipCount, 1);
      assert.equal(gymPlansList.body.data[0].scheduledMembershipCount, 0);

      // GET /admin/memberships upgraded with pagination, status, memberId, search, memberName, memberEmail, planName
      const adminMemberships = await call(
        base,
        `/admin/memberships?status=ACTIVE&memberId=${memberId}&search=Lan%20Anh&page=1&pageSize=10`,
        adminToken,
      );
      assert.equal(adminMemberships.status, 200);
      assert.equal(adminMemberships.body.pagination.totalItems, 1);
      assert.equal(adminMemberships.body.data[0].memberName, 'Nguyễn Lan Anh');
      assert.equal(adminMemberships.body.data[0].memberEmail, `lananh-${memberId}@example.com`);
      assert.equal(adminMemberships.body.data[0].planName, 'Gói T10 Cơ Bản');

      // 2. Coach packages full CRUD (POST + PATCH any code + GET with counts)
      const badCode = await call(base, '/admin/coach-packages', adminToken, 'POST', {
        code: 'invalid lowercase', name: 'Bad', sessionCount: 5, durationDays: 15, price: 1000000,
      });
      assert.equal(badCode.status, 422);

      const pro40 = await call(base, '/admin/coach-packages', adminToken, 'POST', {
        code: 'PRO_40',
        name: 'Chuyên sâu 40 buổi',
        description: 'Lộ trình 120 ngày tăng cơ',
        sessionCount: 40,
        durationDays: 120,
        price: 7200000,
        status: 'ACTIVE',
      });
      assert.equal(pro40.status, 201, JSON.stringify(pro40.body));
      createdPackageCodes.push('PRO_40');
      assert.equal(pro40.body.data.code, 'PRO_40');
      assert.equal(pro40.body.data.description, 'Lộ trình 120 ngày tăng cơ');
      assert.ok(pro40.body.data.createdAt);

      // Duplicate code -> 409 COACH_PACKAGE_CODE_EXISTS
      const dupPro40 = await call(base, '/admin/coach-packages', adminToken, 'POST', {
        code: 'PRO_40', name: 'Trùng mã', sessionCount: 10, durationDays: 30, price: 1000000, status: 'ACTIVE',
      });
      assert.equal(dupPro40.status, 409);
      assert.equal(dupPro40.body.error.code, 'COACH_PACKAGE_CODE_EXISTS');

      // Long custom package (> 190 days!) to prove dynamic horizon + QUEUED capacity window fix!
      const long210 = await call(base, '/admin/coach-packages', adminToken, 'POST', {
        code: 'LONG_210',
        name: 'Lộ trình dài hạn 210 ngày',
        description: 'Kiểm thử horizon vượt quá 190 ngày',
        sessionCount: 20,
        durationDays: 210,
        price: 9000000,
        status: 'ACTIVE',
      });
      assert.equal(long210.status, 201);
      createdPackageCodes.push('LONG_210');

      // Public GET /coach-packages lists active custom packages with description
      const publicOffers = await call(base, '/coach-packages');
      assert.equal(publicOffers.status, 200);
      assert.ok(publicOffers.body.data.some((p) => p.code === 'PRO_40' && p.description === 'Lộ trình 120 ngày tăng cơ'));
      assert.ok(publicOffers.body.data.some((p) => p.code === 'LONG_210'));

      // 3. Member purchases LONG_210 (ACTIVE) -> then queues PRO_40 (QUEUED starting day 218..337!)
      const holdActiveRes = await call(
        base,
        '/coach-payment-holds',
        memberToken,
        'POST',
        { coachId, planCode: 'LONG_210' },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(holdActiveRes.status, 201, JSON.stringify(holdActiveRes.body));
      const settleActive = await settleCoachHold(database, holdActiveRes.body.data.id, {
        paid: true,
        amount: 9000000,
      });
      assert.equal(settleActive.status, 'CONSUMED', JSON.stringify(settleActive));

      // Verify settled_at and entitlement snapshot fields populated
      const activeHoldRow = (await database.query(
        'SELECT status, settled_at FROM coach_payment_holds WHERE id = $1',
        [holdActiveRes.body.data.id],
      )).rows[0];
      assert.equal(activeHoldRow.status, 'CONSUMED');
      assert.ok(activeHoldRow.settled_at);

      const activeEntRow = (await database.query(
        'SELECT plan_code, plan_name, snapshot_price, original_hold_id FROM coach_entitlements WHERE id = $1',
        [settleActive.entitlementId],
      )).rows[0];
      assert.equal(activeEntRow.plan_code, 'LONG_210');
      assert.equal(activeEntRow.plan_name, 'Lộ trình dài hạn 210 ngày');
      assert.equal(Number(activeEntRow.snapshot_price), 9000000);
      assert.equal(activeEntRow.original_hold_id, holdActiveRes.body.data.id);

      // Now Member queues PRO_40 on top of LONG_210 (starts after 210+8 = 218 days, ends day 337 — well past old 190d cap!)
      const holdQueuedRes = await call(
        base,
        '/coach-payment-holds',
        memberToken,
        'POST',
        { coachId, planCode: 'PRO_40' },
        { 'idempotency-key': randomUUID() },
      );
      assert.equal(holdQueuedRes.status, 201, JSON.stringify(holdQueuedRes.body));
      const settleQueued = await settleCoachHold(database, holdQueuedRes.body.data.id, {
        paid: true,
        amount: 7200000,
      });
      assert.equal(settleQueued.status, 'CONSUMED', JSON.stringify(settleQueued));

      // Admin edits PRO_40 price, sessionCount, durationDays -> existing QUEUED entitlement snapshot MUST remain untouched!
      const patchPro40 = await call(base, '/admin/coach-packages/PRO_40', adminToken, 'PATCH', {
        name: 'Chuyên sâu 45 buổi mới',
        description: 'Mô tả mới',
        sessionCount: 45,
        durationDays: 150,
        price: 8500000,
      });
      assert.equal(patchPro40.status, 200);
      assert.equal(patchPro40.body.data.sessionCount, 45);
      assert.equal(patchPro40.body.data.price, 8500000);

      // GET /admin/coach-packages shows active & queued counts
      const adminPkgs = await call(base, '/admin/coach-packages?status=ACTIVE&search=PRO_40', adminToken);
      assert.equal(adminPkgs.status, 200);
      assert.equal(adminPkgs.body.data.length, 1);
      assert.equal(adminPkgs.body.data[0].queuedEntitlementCount, 1);
      assert.equal(adminPkgs.body.data[0].activeEntitlementCount, 0);

      // 4. GET /admin/coach-entitlements returns snapshot + human names + supports filters
      const entList = await call(
        base,
        `/admin/coach-entitlements?memberId=${memberId}&coachId=${coachId}&page=1&pageSize=10`,
        adminToken,
      );
      assert.equal(entList.status, 200);
      assert.equal(entList.body.pagination.totalItems, 2);
      const queuedView = entList.body.data.find((item) => item.status === 'QUEUED');
      assert.equal(queuedView.memberName, 'Nguyễn Lan Anh');
      assert.equal(queuedView.coachName, 'Coach T10');
      assert.equal(queuedView.planCode, 'PRO_40');
      assert.equal(queuedView.planName, 'Chuyên sâu 40 buổi'); // old snapshot name preserved!
      assert.equal(queuedView.snapshotPrice, 7200000); // old snapshot price preserved!
      assert.equal(queuedView.totalSessions, 40); // old snapshot sessions preserved!
      assert.equal(queuedView.durationDays, 120); // old snapshot duration preserved!

      const frozenList = await call(base, `/admin/coach-entitlements?memberId=${memberId}&frozenOnly=true`, adminToken);
      assert.equal(frozenList.status, 200);
      assert.equal(frozenList.body.pagination.totalItems, 0);
    } finally {
      await database.query('DELETE FROM coach_notifications WHERE user_id IN ($1, $2)', [memberId, coachId]);
      await database.query('DELETE FROM coach_entitlements WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM coach_payment_holds WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM coach_relationships WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM coach_weekly_slots WHERE coach_id = $1', [coachId]);
      for (const code of createdPackageCodes) {
        await database.query('DELETE FROM coach_package_plans WHERE code = $1', [code]);
      }
      await database.query('DELETE FROM member_memberships WHERE member_id = $1', [memberId]);
      await database.query('DELETE FROM payments WHERE member_id = $1', [memberId]);
      if (gymPlanId) await database.query('DELETE FROM membership_plans WHERE id = $1', [gymPlanId]);
      await database.query('DELETE FROM admin_audit_logs WHERE admin_id = $1', [adminId]);
      await database.query('DELETE FROM coach_profiles WHERE user_id = $1', [coachId]);
      await database.query('DELETE FROM member_profiles WHERE user_id = $1', [memberId]);
      await database.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [[adminId, coachId, memberId]]);
      await new Promise((resolve) => server.close(resolve));
      await database.end();
    }
  });
