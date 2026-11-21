import assert from 'node:assert/strict';
import { createHmac, randomInt, randomUUID } from 'node:crypto';
import test from 'node:test';
import jwt from 'jsonwebtoken';
import pg from 'pg';
import { createApp } from '../src/app.js';
import { createZalopayFromEnv } from '../src/config/zalopay.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const jwtSecret = 'zalopay-integration-jwt-secret-32-characters';
const key = 'local-zalopay-test-key';
const callbackKey = 'local-zalopay-callback-test-key';
const sign = (parts) => createHmac('sha256', key).update(parts.join('|')).digest('hex');

test('ZaloPay requires a provider query with the expected amount and renews once', { skip: !databaseUrl }, async (t) => {
  const database = new pg.Pool({ connectionString: databaseUrl });
  let providerResult = { return_code: 3, is_processing: true };
  const providerOrders = new Set();
  let queries = 0;
  const zalopay = createZalopayFromEnv({ ZALOPAY_APP_ID: '2554', ZALOPAY_KEY1: key,
    ZALOPAY_KEY2: callbackKey, ZALOPAY_PUBLIC_ORIGIN: 'https://gateway-test.example.com' },
    async (url, { body, redirect }) => {
      assert.equal(redirect, 'error');
      const data = JSON.parse(body);
      assert.equal(data.app_id, 2554);
      if (url.endsWith('/create')) {
        assert.equal(url, 'https://sb-openapi.zalopay.vn/v2/create');
        assert.match(data.app_trans_id, /^\d{6}_[0-9a-f]{32}$/);
        assert.equal(data.amount, 150000);
        assert.equal(data.bank_code, 'zalopayapp');
        assert.equal(data.callback_url, 'https://gateway-test.example.com/api/v1/payments/zalopay/callback');
        assert.equal(data.mac, sign([data.app_id, data.app_trans_id, data.app_user, data.amount,
          data.app_time, data.embed_data, data.item]));
        providerOrders.add(data.app_trans_id);
        return Response.json({ return_code: 1, order_url: 'https://qcgateway.zalopay.vn/pay/v2/?order=' + data.app_trans_id });
      }
      assert.equal(url, 'https://sb-openapi.zalopay.vn/v2/query');
      assert.ok(providerOrders.has(data.app_trans_id));
      assert.equal(data.mac, sign([data.app_id, data.app_trans_id, key]));
      queries++;
      return Response.json(providerResult);
    });

  const server = createApp({ database, jwtSecret, zalopay }).listen(0);
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const api = `http://127.0.0.1:${server.address().port}/api/v1`;
  const [admin, member, other, plan] = Array.from({ length: 4 }, () => randomUUID());
  const insertedAdmin = await database.query(
    `INSERT INTO users (id,email,password_hash,role,full_name)
     VALUES ($1,$2,'hash','ADMIN','Admin') ON CONFLICT DO NOTHING RETURNING id`, [admin, admin + '@example.com'],
  );
  t.after(async () => {
    try {
      await database.query('DELETE FROM member_memberships WHERE member_id IN ($1, $2)', [member, other]);
      await database.query('DELETE FROM payments WHERE member_id IN ($1, $2)', [member, other]);
      await database.query('DELETE FROM membership_plans WHERE id = $1', [plan]);
      await database.query('DELETE FROM users WHERE id IN ($1, $2)', [member, other]);
      if (insertedAdmin.rowCount > 0) {
        await database.query('DELETE FROM users WHERE id = $1', [admin]);
      }
    } finally {
      await database.end();
    }
  });
  await database.query(
    `INSERT INTO users (id,email,password_hash,role,full_name)
     VALUES ($1,$2,'hash','MEMBER','Member'), ($3,$4,'hash','MEMBER','Other')`,
    [member, member + '@example.com', other, other + '@example.com'],
  );
  await database.query(
    `INSERT INTO membership_plans (id,name,price,duration_days,status,created_by)
     SELECT $1,'ZaloPay test plan',150000,30,'ACTIVE',id FROM users WHERE role = 'ADMIN'`, [plan],
  );

  function call(path, { body, id = member, orderKey } = {}) {
    const token = jwt.sign({ role: 'MEMBER', sessionVersion: 0 }, jwtSecret, {
      algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api', subject: id, expiresIn: 300,
    });
    return fetch(api + path, {
      method: body ? 'POST' : 'GET',
      headers: { authorization: 'Bearer ' + token, ...(body ? { 'content-type': 'application/json' } : {}),
        ...(orderKey ? { 'idempotency-key': orderKey } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
  }
  const create = (orderKey = randomUUID()) => call('/payments', { body: { planId: plan, method: 'ZALOPAY' }, orderKey });
  const status = (id, user = member) => call('/payments/' + id + '/zalopay-status', { body: {}, id: user });
  const memberships = async () => (await (await call('/memberships/me')).json()).data;
  const expireThrottle = (id) => database.query('UPDATE payments SET zalopay_last_query_at = NULL WHERE id = $1', [id]);
  const transId = randomInt(1_000_000_000, 9_999_999_998);
  function signedNotice(order, overrides = {}) {
    const data = JSON.stringify({ app_id: 2554, app_trans_id: order.transactionCode,
      amount: 150000, zp_trans_id: transId, ...overrides });
    return { data, mac: createHmac('sha256', callbackKey).update(data).digest('hex'), type: 1 };
  }
  async function callback(body) {
    const response = await fetch(api + '/payments/zalopay/callback', {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    assert.equal(response.status, 200);
    return (await response.json()).return_code;
  }

  const orderKey = randomUUID();
  const response = await create(orderKey);
  const { data: first } = await response.json();
  assert.equal(response.status, 201);
  assert.equal(first.status, 'PENDING');
  assert.match(first.paymentUrl, /^https:\/\/qcgateway\.zalopay\.vn\//);
  assert.equal((await (await create(orderKey)).json()).data.id, first.id);
  assert.equal((await create()).status, 409);
  assert.equal(providerOrders.size, 1);
  assert.equal(await callback({ ...signedNotice(first), mac: '0'.repeat(64) }), 2);
  assert.equal(await callback(signedNotice(first, { amount: 149999 })), 2);
  assert.equal(queries, 0);
  assert.equal(await callback(signedNotice(first)), 0);
  assert.equal((await memberships()).length, 0);
  assert.equal((await status(first.id, other)).status, 404);
  assert.equal((await (await status(first.id)).json()).data.status, 'PENDING');
  assert.equal((await status(first.id)).status, 200);
  assert.equal(queries, 1);

  providerResult = { return_code: 1, is_processing: false, amount: 150001, zp_trans_id: transId };
  await expireThrottle(first.id);
  assert.equal((await (await status(first.id)).json()).data.status, 'PENDING');
  assert.equal((await memberships()).length, 0);

  providerResult.amount = 150000;
  await expireThrottle(first.id);
  assert.equal(await callback(signedNotice(first)), 1);
  assert.deepEqual(await Promise.all([callback(signedNotice(first)), callback(signedNotice(first))]), [1, 1]);
  assert.equal(await callback(signedNotice(first, { zp_trans_id: transId + 2 })), 2);
  assert.equal((await (await status(first.id)).json()).data.status, 'SUCCESS');
  const [active] = await memberships();

  providerResult = { return_code: 2, sub_return_code: -54, is_processing: true };
  const { data: expired } = await (await create()).json();
  assert.equal((await (await status(expired.id)).json()).data.status, 'PENDING');
  await database.query(
    "UPDATE payments SET created_at = now() - interval '16 minutes', zalopay_last_query_at = NULL WHERE id = $1",
    [expired.id],
  );
  assert.equal((await (await status(expired.id)).json()).data.status, 'CANCELLED');
  assert.equal((await memberships())[0].endDate, active.endDate);

  providerResult = { return_code: 1, is_processing: false, amount: 150000, zp_trans_id: transId + 1 };
  const { data: renewal } = await (await create()).json();
  const renewalNotice = signedNotice(renewal, { zp_trans_id: transId + 1 });
  assert.equal(await callback(renewalNotice), 1);
  assert.equal(await callback(renewalNotice), 1);
  const [extended] = await memberships();
  assert.equal(extended.id, active.id);
  assert.equal((Date.parse(extended.endDate) - Date.parse(active.endDate)) / 86400000, 30);
  const history = (await (await call('/payments/me')).json()).data;
  assert.deepEqual(history.map(({ status }) => status).sort(), ['CANCELLED', 'SUCCESS', 'SUCCESS']);
});
