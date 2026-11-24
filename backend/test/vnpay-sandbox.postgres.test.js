import assert from 'node:assert/strict';
import { createHmac, randomInt, randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';
import { createVnpayFromEnv } from '../src/config/vnpay.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const jwtSecret = 'vnpay-integration-jwt-secret-32-characters';
const merchant = 'TEST1234';
const hashSecret = 'local-integration-test-key';
const sign = (payload) => createHmac('sha512', hashSecret).update(payload).digest('hex');
const initialTransaction = String(randomInt(1_000_000_000, 9_999_999_998));
const renewalTransaction = String(Number(initialTransaction) + 1);

function signedCallback(checkout, overrides = {}) {
  const fields = {
    vnp_Amount: checkout.searchParams.get('vnp_Amount'),
    vnp_ResponseCode: '00',
    vnp_TmnCode: merchant,
    vnp_TransactionNo: initialTransaction,
    vnp_TransactionStatus: '00',
    vnp_TxnRef: checkout.searchParams.get('vnp_TxnRef'),
    ...overrides,
  };
  const params = new URLSearchParams(Object.entries(fields).sort());
  params.set('vnp_SecureHash', sign(params.toString()));
  return params;
}

test('VNPay settles membership only from a verified server result and renews once', {
  skip: !databaseUrl,
}, async (t) => {
  const database = new pg.Pool({ connectionString: databaseUrl });
  let queryStatus = '01';
  let signQueryResponse = false;
  const gateway = createVnpayFromEnv({
    VNPAY_TMN_CODE: merchant,
    VNPAY_HASH_SECRET: hashSecret,
    VNPAY_PUBLIC_ORIGIN: 'https://api.example.com',
    VNPAY_WEB_RETURN_URL: 'https://app.example.com/#/member/features/membership',
  }, async (url, { body, redirect }) => {
    assert.equal(url, 'https://sandbox.vnpayment.vn/merchant_webapi/api/transaction');
    assert.equal(redirect, 'error');
    const request = JSON.parse(body);
    const ref = request.vnp_TxnRef;
    assert.equal(request.vnp_SecureHash, sign([
      request.vnp_RequestId, '2.1.0', 'querydr', merchant, ref, request.vnp_TransactionDate,
      request.vnp_CreateDate, request.vnp_IpAddr, request.vnp_OrderInfo,
    ].join('|')));
    const result = {
      vnp_ResponseId: '123', vnp_Command: 'querydr', vnp_ResponseCode: '00',
      vnp_Message: 'Success', vnp_TmnCode: merchant, vnp_TxnRef: ref, vnp_Amount: '15000000',
      vnp_BankCode: 'NCB', vnp_PayDate: '20261117153200', vnp_TransactionNo: renewalTransaction,
      vnp_TransactionType: '01', vnp_TransactionStatus: queryStatus,
      vnp_OrderInfo: request.vnp_OrderInfo, vnp_PromotionCode: '', vnp_PromotionAmount: '',
    };
    result.vnp_SecureHash = signQueryResponse ? sign(Object.values(result).join('|')) : '0'.repeat(128);
    return Response.json(result);
  });
  const app = createApp({ database, jwtSecret, vnpay: gateway,
    zalopay: {}, preferredPaymentGateway: 'VNPAY' });
  const server = app.listen(0);
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const api = `http://127.0.0.1:${server.address().port}/api/v1`;
  const [memberId, strangerId, planId] = Array.from({ length: 3 }, () => randomUUID());
  const fixtureAdmin = randomUUID();
  const insertedAdmin = await database.query(
    `INSERT INTO users (id, email, password_hash, role, full_name)
     VALUES ($1, $2, 'hash', 'ADMIN', 'Admin') ON CONFLICT DO NOTHING RETURNING id`,
    [fixtureAdmin, `${fixtureAdmin}@example.com`],
  );
  t.after(async () => {
    try {
      await database.query('DELETE FROM member_memberships WHERE member_id IN ($1, $2)', [memberId, strangerId]);
      await database.query('DELETE FROM payments WHERE member_id IN ($1, $2)', [memberId, strangerId]);
      await database.query('DELETE FROM membership_plans WHERE id = $1', [planId]);
      await database.query('DELETE FROM users WHERE id IN ($1, $2)', [memberId, strangerId]);
      if (insertedAdmin.rowCount > 0) {
        await database.query('DELETE FROM users WHERE id = $1', [fixtureAdmin]);
      }
    } finally {
      await database.end();
    }
  });
  const { rows: [{ id: adminId }] } = await database.query("SELECT id FROM users WHERE role = 'ADMIN'");
  await database.query(
    `INSERT INTO users (id, email, password_hash, role, full_name)
     VALUES ($1, $2, 'hash', 'MEMBER', 'Member'), ($3, $4, 'hash', 'MEMBER', 'Stranger')`,
    [memberId, `${memberId}@example.com`, strangerId, `${strangerId}@example.com`],
  );
  await database.query(
    `INSERT INTO membership_plans (id, name, price, duration_days, status, created_by)
     VALUES ($1, 'Sandbox integration plan', 150000, 30, 'ACTIVE', $2)`, [planId, adminId],
  );
  const auth = (user) => `Bearer ${jwt.sign({ role: 'MEMBER', sessionVersion: 0 }, jwtSecret, {
    algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
    subject: user, expiresIn: 300,
  })}`;
  function call(path, method = 'GET', { user = memberId, ...options } = {}) {
    return fetch(api + path, {
      ...options, method, headers: { authorization: auth(user), ...options.headers },
    });
  }
  async function create(key = randomUUID(), method = 'VNPAY') {
    const res = await call('/payments', 'POST', {
      body: JSON.stringify({ planId, method }),
      headers: { 'content-type': 'application/json', 'idempotency-key': key },
    });
    return { status: res.status, ...await res.json() };
  }
  async function ipn(params) {
    const res = await fetch(`${api}/payments/vnpay/ipn?${params}`);
    assert.equal(res.status, 200);
    return (await res.json()).RspCode;
  }
  const memberships = async () => (await (await call('/memberships/me')).json()).data;

  const key = randomUUID();
  const created = await create(key);
  assert.equal(created.status, 201, JSON.stringify(created));
  const payment = created.data;
  assert.equal(payment.amount, 150000);
  const checkout = new URL(payment.paymentUrl);
  assert.equal(checkout.origin + checkout.pathname, 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html');
  assert.equal(checkout.searchParams.get('vnp_Amount'), '15000000');
  assert.equal(checkout.searchParams.get('vnp_ReturnUrl'), 'https://api.example.com/api/v1/payments/vnpay/return');
  const [signedRequest, signature] = checkout.search.slice(1).split('&vnp_SecureHash=');
  assert.equal(signature, sign(signedRequest));
  assert.equal((await create(key)).data.id, payment.id);
  assert.equal((await create()).status, 409);
  assert.equal((await create(randomUUID(), 'MOCK_QR')).status, 403);
  assert.equal((await call(`/payments/${payment.id}/vnpay-status`, 'POST', { user: strangerId })).status, 404);

  const forged = signedCallback(checkout);
  forged.set('vnp_TransactionStatus', '02');
  assert.equal(await ipn(forged), '97');
  assert.equal(await ipn(signedCallback(checkout, { vnp_Amount: '15000001' })), '04');
  assert.equal(await ipn(signedCallback(checkout, { vnp_TxnRef: 'MG' + 'f'.repeat(32) })), '01');
  queryStatus = '00';
  const browserReturn = await fetch(`${api}/payments/vnpay/return?${signedCallback(checkout)}`);
  const html = await browserReturn.text();
  assert.match(html, /Đang chờ VNPay xác nhận/);
  assert.ok(html.includes(`https://app.example.com/#/member/features/membership?vnpayPaymentId=${payment.id}`));
  assert.equal((await memberships()).length, 0);
  const duplicates = await Promise.all([ipn(signedCallback(checkout)), ipn(signedCallback(checkout))]);
  assert.deepEqual(duplicates.sort(), ['00', '02']);
  const [activated] = await memberships();
  assert.ok(activated);

  const cancelled = (await create()).data;
  assert.equal(await ipn(signedCallback(new URL(cancelled.paymentUrl), {
    vnp_ResponseCode: '24', vnp_TransactionStatus: '02', vnp_TransactionNo: '0',
  })), '00');
  assert.equal((await memberships())[0].endDate, activated.endDate);

  const failed = (await create()).data;
  assert.equal(await ipn(signedCallback(new URL(failed.paymentUrl), {
    vnp_ResponseCode: '51', vnp_TransactionStatus: '02', vnp_TransactionNo: '0',
  })), '00');
  assert.equal((await memberships())[0].endDate, activated.endDate);

  const renewal = (await create()).data;
  const renewalUrl = new URL(renewal.paymentUrl);
  assert.equal(await ipn(signedCallback(renewalUrl, { vnp_TransactionStatus: '01' })), '99');
  assert.equal(await ipn(signedCallback(renewalUrl)), '99');
  assert.equal((await memberships())[0].endDate, activated.endDate);
  signQueryResponse = true;
  const reconciled = await call(`/payments/${renewal.id}/vnpay-status`, 'POST');
  const reconciledData = await reconciled.json();
  assert.equal(reconciledData.data.status, 'SUCCESS', JSON.stringify(reconciledData));
  assert.equal(await ipn(signedCallback(renewalUrl, { vnp_TransactionNo: renewalTransaction })), '02');
  const [extended] = await memberships();
  assert.equal(extended.id, activated.id);
  assert.equal((Date.parse(extended.endDate) - Date.parse(activated.endDate)) / 86400000, 30);
  const history = (await (await call('/payments/me')).json()).data;
  assert.deepEqual(history.map(({ status }) => status).sort(), ['CANCELLED', 'FAILED', 'SUCCESS', 'SUCCESS']);
  assert.ok(history.every(({ method, paymentUrl }) => method === 'VNPAY' && !paymentUrl));
});
