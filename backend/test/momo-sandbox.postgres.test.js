import assert from 'node:assert/strict';
import { createHmac, randomInt, randomUUID } from 'node:crypto';
import test from 'node:test';
import jwt from 'jsonwebtoken';
import pg from 'pg';
import { createApp } from '../src/app.js';
import { createMomoFromEnv } from '../src/config/momo.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const partner = 'MOMO_TEST_META';
const accessKey = 'local-momo-access-key';
const merchantSecret = 'local-momo-secret';
const jwtSecret = 'momo-integration-jwt-secret-32-characters';
const sign = (fields) => createHmac('sha256', merchantSecret)
  .update(Object.entries({ ...fields, accessKey }).sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => key + '=' + value).join('&')).digest('hex');

test('MoMo validates payment, renews once and preserves failures in history', { skip: !databaseUrl }, async (t) => {
  const database = new pg.Pool({ connectionString: databaseUrl });
  const providerOrders = new Map();
  let queries = 0;
  let queryCode = 1000;
  const transactionId = randomInt(1_000_000_000, 9_999_999_998);
  const momo = createMomoFromEnv({
    MOMO_PARTNER_CODE: partner, MOMO_ACCESS_KEY: accessKey, MOMO_SECRET_KEY: merchantSecret,
    MOMO_PUBLIC_ORIGIN: 'https://sandbox-api.example.com',
    MOMO_WEB_RETURN_URL: 'https://app.example.com/#/member/features/membership',
  }, async (url, { body, redirect }) => {
    const { signature, lang, autoCapture, ...signed } = JSON.parse(body);
    const { partnerCode, orderId, requestId, amount } = signed;
    assert.equal(signature, sign(signed));
    assert.equal(redirect, 'error');
    if (url.endsWith('/create')) {
      assert.equal(url, 'https://test-payment.momo.vn/v2/gateway/api/create');
      assert.equal(signed.ipnUrl, 'https://sandbox-api.example.com/api/v1/payments/momo/ipn');
      assert.equal(signed.redirectUrl, 'https://sandbox-api.example.com/api/v1/payments/momo/return');
      assert.equal(signed.requestType, 'captureWallet');
      assert.equal(autoCapture, true);
      assert.equal(amount, 150000);
      providerOrders.set(orderId, signed);
      return Response.json({ partnerCode, orderId, requestId, amount, resultCode: 0,
        payUrl: 'https://test-payment.momo.vn/v2/gateway/pay?t=' + orderId });
    }
    assert.equal(url, 'https://test-payment.momo.vn/v2/gateway/api/query');
    queries++;
    return Response.json({ partnerCode, orderId, requestId, amount: providerOrders.get(orderId).amount,
      resultCode: queryCode, transId: transactionId + 1 });
  });
  const app = createApp({ database, jwtSecret, momo });
  const server = app.listen(0);
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const api = `http://127.0.0.1:${server.address().port}/api/v1`;
  const [member, plan, fixtureAdmin] = Array.from({ length: 3 }, () => randomUUID());
  const insertedAdmin = await database.query(
    `INSERT INTO users (id,email,password_hash,role,full_name)
     VALUES ($1,$2,'hash','ADMIN','Admin') ON CONFLICT DO NOTHING RETURNING id`,
    [fixtureAdmin, fixtureAdmin + '@example.com'],
  );
  t.after(async () => {
    try {
      await database.query('DELETE FROM member_memberships WHERE member_id = $1', [member]);
      await database.query('DELETE FROM payments WHERE member_id = $1', [member]);
      await database.query('DELETE FROM membership_plans WHERE id = $1', [plan]);
      await database.query('DELETE FROM users WHERE id = $1', [member]);
      if (insertedAdmin.rowCount > 0) {
        await database.query('DELETE FROM users WHERE id = $1', [fixtureAdmin]);
      }
    } finally {
      await database.end();
    }
  });
  await database.query(
    "INSERT INTO users (id,email,password_hash,role,full_name) VALUES ($1,$2,'hash','MEMBER','Member')",
    [member, member + '@example.com'],
  );
  await database.query(
    `INSERT INTO membership_plans (id,name,price,duration_days,status,created_by)
     SELECT $1,'MoMo test plan',150000,30,'ACTIVE',id FROM users WHERE role = 'ADMIN'`, [plan],
  );
  const token = jwt.sign({ role: 'MEMBER', sessionVersion: 0 }, jwtSecret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api', subject: member, expiresIn: 300,
  });
  const memberCall = (path, body, key) => fetch(api + path, {
    method: body ? 'POST' : 'GET',
    headers: { authorization: 'Bearer ' + token, ...(body ? { 'content-type': 'application/json' } : {}),
      ...(key ? { 'idempotency-key': key } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const create = (key = randomUUID()) => memberCall('/payments', { planId: plan, method: 'MOMO' }, key);
  const memberships = async () => (await (await memberCall('/memberships/me')).json()).data;
  function callback(payment, overrides = {}) {
    const orderId = payment.transactionCode;
    const fields = { amount: 150000, extraData: '', message: 'fixture', orderId,
      orderInfo: providerOrders.get(orderId).orderInfo, orderType: 'momo_wallet', partnerCode: partner,
      payType: 'qr', requestId: orderId, responseTime: 1760000000000, resultCode: 0,
      transId: transactionId, ...overrides };
    return { ...fields, signature: sign(fields) };
  }
  const ipn = (body) => fetch(api + '/payments/momo/ipn', {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body),
  });

  const key = randomUUID();
  const created = await create(key);
  const { data: payment } = await created.json();
  assert.equal(created.status, 201);
  assert.equal(payment.status, 'PENDING');
  assert.match(payment.paymentUrl, /^https:\/\/test-payment\.momo\.vn\/v2\/gateway\/pay/);
  assert.equal((await (await create(key)).json()).data.id, payment.id);
  assert.equal((await create()).status, 409);
  assert.equal(providerOrders.size, 1);
  const signed = callback(payment);
  assert.equal((await ipn({ ...signed, transId: transactionId + 1 })).status, 400);
  assert.equal((await ipn(callback(payment, { amount: 150001 }))).status, 400);
  const resultPage = await fetch(api + '/payments/momo/return?' + new URLSearchParams(signed));
  assert.match(await resultPage.text(), /Đang chờ MoMo xác nhận/);
  assert.equal((await memberships()).length, 0);
  const receipts = await Promise.all([ipn(signed), ipn(signed)]);
  assert.deepEqual(receipts.map((receipt) => receipt.status), [204, 204]);
  const [first] = await memberships();
  assert.ok(first);

  const { data: cancelled } = await (await create()).json();
  assert.equal((await ipn(callback(cancelled, { resultCode: 1006, transId: 0 }))).status, 204);
  assert.equal((await memberships())[0].endDate, first.endDate);
  const { data: failed } = await (await create()).json();
  assert.equal((await ipn(callback(failed, { resultCode: 1002, transId: 0 }))).status, 204);
  assert.equal((await memberships())[0].endDate, first.endDate);

  const { data: renewal } = await (await create()).json();
  queryCode = 0;
  const latest = await memberCall('/payments/' + renewal.id + '/momo-status', {});
  assert.equal((await latest.json()).data.status, 'SUCCESS');
  assert.equal(queries, 1);
  assert.equal((await ipn(callback(renewal, { transId: transactionId + 1 }))).status, 204);
  const [extended] = await memberships();
  assert.equal(extended.id, first.id);
  assert.equal((Date.parse(extended.endDate) - Date.parse(first.endDate)) / 86400000, 30);
  const { data: history } = await (await memberCall('/payments/me')).json();
  assert.deepEqual(history.map(({ status }) => status).sort(), ['CANCELLED', 'FAILED', 'SUCCESS', 'SUCCESS']);
  assert.ok(history.every(({ method, paymentUrl }) => method === 'MOMO' && !paymentUrl));
});
