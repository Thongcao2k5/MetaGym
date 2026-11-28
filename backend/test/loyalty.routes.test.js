import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import express from 'express';
import jwt from 'jsonwebtoken';

import { createLoyaltyRouter } from '../src/routes/loyalty.routes.js';
import { bonusPointsForDurationDays, resolveTierFromPoints } from '../src/services/loyalty.js';

const secret = 'loyalty-routes-test-secret-with-32-chars';
const memberId = '11111111-1111-4111-8111-111111111111';
const adminId = '22222222-2222-4222-8222-222222222222';
const rewardVoucherId = 'a0000000-0000-4000-8000-000000000001';
const rewardInbodyId = 'a0000000-0000-4000-8000-000000000002';
const rewardSoldOutId = 'a0000000-0000-4000-8000-000000000005';

function makeToken(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, secret, {
    algorithm: 'HS256',
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    subject: id,
    expiresIn: 3600,
  });
}

function createMemoryLoyaltyDb() {
  const accounts = new Map([[memberId, { member_id: memberId, available_points: 1240, tier_points: 2150 }]]);
  const rewards = [
    {
      id: rewardVoucherId,
      code: 'rw-voucher-100',
      category: 'VOUCHER',
      title: 'Voucher giảm 100.000đ',
      description: 'Giảm 100.000đ hóa đơn.',
      points_cost: 300,
      discount_amount: 100000,
      requires_staff_confirm: false,
      stock_remaining: null,
      valid_days: 30,
      terms: ['Dùng 1 lần'],
      status: 'ACTIVE',
      sort_order: 1,
      created_at: new Date(),
    },
    {
      id: rewardInbodyId,
      code: 'rw-inbody',
      category: 'SERVICE',
      title: 'Một lần đo InBody',
      description: 'Đo InBody tại quầy.',
      points_cost: 400,
      discount_amount: 0,
      requires_staff_confirm: true,
      stock_remaining: null,
      valid_days: 30,
      terms: ['Cần nhân viên xác nhận'],
      status: 'ACTIVE',
      sort_order: 2,
      created_at: new Date(),
    },
    {
      id: rewardSoldOutId,
      code: 'rw-sold-out',
      category: 'VOUCHER',
      title: 'Quà tặng bình giữ nhiệt',
      description: 'Hết lượt.',
      points_cost: 600,
      discount_amount: 0,
      requires_staff_confirm: true,
      stock_remaining: 0,
      valid_days: 30,
      terms: [],
      status: 'ACTIVE',
      sort_order: 5,
      created_at: new Date(),
    },
  ];
  const redemptions = [];
  const transactions = [];

  return {
    accounts,
    async query(sql, args = []) {
      const normalized = sql.replace(/\s+/g, ' ').trim();
      if (normalized === 'BEGIN' || normalized === 'COMMIT' || normalized === 'ROLLBACK') {
        return { rows: [] };
      }
      if (normalized.includes('FROM users u')) {
        const id = args[0];
        const role = id === adminId ? 'ADMIN' : 'MEMBER';
        return { rows: [{ id, role, status: 'ACTIVE', session_version: 0 }] };
      }
      if (normalized.startsWith('SELECT id FROM users')) {
        return { rows: [{ id: args[0] }] };
      }
      if (normalized.startsWith("UPDATE loyalty_redemptions SET status = 'EXPIRED'")) {
        const now = Date.now();
        for (const r of redemptions) {
          if (r.member_id === args[0] && r.status === 'UNUSED' && new Date(r.expires_at).getTime() < now) {
            r.status = 'EXPIRED';
          }
        }
        return { rows: [] };
      }
      if (normalized.startsWith('INSERT INTO loyalty_accounts')) {
        if (!accounts.has(args[0])) {
          accounts.set(args[0], { member_id: args[0], available_points: 0, tier_points: 0 });
        }
        return { rows: [] };
      }
      if (normalized.includes('FROM loyalty_accounts WHERE member_id')) {
        const row = accounts.get(args[0]);
        return { rows: row ? [{ ...row }] : [] };
      }
      if (normalized.includes('SELECT count(*)::int AS unused_count FROM loyalty_redemptions')) {
        const count = redemptions.filter((r) => r.member_id === args[0] && r.status === 'UNUSED').length;
        return { rows: [{ unused_count: count }] };
      }
      if (normalized.includes('FROM loyalty_rewards WHERE')) {
        const catIdx = normalized.includes('category = $1') ? args[0] : null;
        if (normalized.includes('WHERE id = $1')) {
          const found = rewards.find((r) => r.id === args[0]);
          return { rows: found ? [{ ...found }] : [] };
        }
        const rows = rewards.filter((r) => r.status === 'ACTIVE' && (!catIdx || r.category === catIdx));
        return { rows };
      }
      if (normalized.includes('FROM loyalty_redemptions WHERE member_id = $1 AND idempotency_key = $2')) {
        return { rows: redemptions.filter((r) => r.member_id === args[0] && r.idempotency_key === args[1]) };
      }
      if (normalized.includes('SELECT * FROM loyalty_redemptions WHERE member_id = $1')) {
        const statusFilter = args.length > 1 ? args[1] : null;
        return {
          rows: redemptions
            .filter((r) => r.member_id === args[0] && (!statusFilter || r.status === statusFilter))
            .slice()
            .reverse(),
        };
      }
      if (normalized.includes('FROM loyalty_redemptions WHERE id = $1 FOR UPDATE')) {
        const found = redemptions.find((r) => r.id === args[0]);
        return { rows: found ? [found] : [] };
      }
      if (normalized.startsWith('UPDATE loyalty_accounts SET available_points = available_points - $2')) {
        const acc = accounts.get(args[0]);
        acc.available_points -= args[1];
        return { rows: [] };
      }
      if (normalized.startsWith('INSERT INTO loyalty_redemptions')) {
        const now = new Date();
        const expiresAt = new Date(now.getTime() + args[12] * 86400_000);
        const row = {
          id: args[0],
          member_id: args[1],
          reward_id: args[2],
          reward_code_snapshot: args[3],
          category_snapshot: args[4],
          title_snapshot: args[5],
          points_spent: args[6],
          discount_amount_snapshot: args[7],
          voucher_code: args[8],
          requires_staff_confirm: args[9],
          condition_text: args[10],
          status: 'UNUSED',
          idempotency_key: args[11],
          redeemed_at: now.toISOString(),
          expires_at: expiresAt.toISOString(),
          used_at: null,
        };
        redemptions.push(row);
        return { rows: [row] };
      }
      if (normalized.startsWith('INSERT INTO loyalty_point_transactions')) {
        const row = {
          id: args[0],
          member_id: args[1],
          tx_type: 'SPEND',
          points_delta: args[2],
          tier_points_delta: 0,
          title: args[3],
          detail: args[4],
          reference_type: 'REWARD_REDEMPTION',
          reference_id: args[5],
          status_label: 'Đã đổi ưu đãi',
          created_at: new Date().toISOString(),
        };
        transactions.push(row);
        return { rows: [row] };
      }
      if (normalized.includes('FROM loyalty_point_transactions WHERE member_id = $1 AND reference_type')) {
        return {
          rows: transactions.filter((t) => t.member_id === args[0] && t.reference_id === args[1]),
        };
      }
      if (normalized.includes('FROM loyalty_point_transactions WHERE member_id = $1')) {
        const txFilter = args.length > 1 ? args[1] : null;
        return {
          rows: transactions
            .filter((t) => t.member_id === args[0] && (!txFilter || t.tx_type === txFilter))
            .slice()
            .reverse(),
        };
      }
      if (normalized.startsWith("UPDATE loyalty_redemptions SET status = 'USED'")) {
        const found = redemptions.find((r) => r.id === args[0]);
        found.status = 'USED';
        found.used_at = new Date().toISOString();
        return { rows: [found] };
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
}

test('Loyalty tier threshold calculation & bonus point rules are decoupled cleanly', () => {
  assert.equal(resolveTierFromPoints(0).current.code, 'BRONZE');
  assert.equal(resolveTierFromPoints(799).next.code, 'SILVER');
  assert.equal(resolveTierFromPoints(800).current.code, 'SILVER');
  assert.equal(resolveTierFromPoints(2150).current.code, 'GOLD');
  assert.equal(resolveTierFromPoints(2150).next.code, 'DIAMOND');
  assert.equal(resolveTierFromPoints(2150).remainingToNextTier, 3850);
  assert.equal(resolveTierFromPoints(6000).current.code, 'DIAMOND');
  assert.equal(resolveTierFromPoints(6000).next, null);

  assert.equal(bonusPointsForDurationDays(30), 100);
  assert.equal(bonusPointsForDurationDays(180), 650);
  assert.equal(bonusPointsForDurationDays(365), 1500);
  assert.equal(bonusPointsForDurationDays(1095), 5000);
});

test('Loyalty router redemptions deduct available points ONLY, preserve tier points, and enforce guards', async (t) => {
  const database = createMemoryLoyaltyDb();
  const app = express();
  app.use(express.json());
  app.use('/api/v1', createLoyaltyRouter({ database, jwtSecret: secret }));
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const base = `http://127.0.0.1:${server.address().port}/api/v1`;
  async function api(path, { role = 'MEMBER', id = memberId, method = 'GET', body, headers = {} } = {}) {
    const res = await fetch(`${base}${path}`, {
      method,
      headers: {
        authorization: `Bearer ${makeToken(id, role)}`,
        ...(body !== undefined ? { 'content-type': 'application/json' } : {}),
        ...headers,
      },
      ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
    });
    return { status: res.status, body: await res.json() };
  }

  // 1. Initial loyalty summary matches seeded 1240 available / 2150 tier (GOLD)
  const initial = await api('/loyalty/me');
  assert.equal(initial.status, 200);
  assert.equal(initial.body.data.availablePoints, 1240);
  assert.equal(initial.body.data.tierPoints, 2150);
  assert.equal(initial.body.data.tier, 'GOLD');
  assert.equal(initial.body.data.remainingToNextTier, 3850);

  // 2. Redeem 300-point voucher -> availablePoints becomes 940, tierPoints STAYS 2150!
  const idemKey = `redeem-${randomUUID()}`;
  const redeemRes = await api('/loyalty/redemptions', {
    method: 'POST',
    headers: { 'idempotency-key': idemKey },
    body: { rewardId: rewardVoucherId },
  });
  assert.equal(redeemRes.status, 201);
  assert.equal(redeemRes.body.data.summary.availablePoints, 940);
  assert.equal(redeemRes.body.data.summary.tierPoints, 2150);
  assert.equal(redeemRes.body.data.summary.tier, 'GOLD');
  assert.equal(redeemRes.body.data.redemption.status, 'UNUSED');
  assert.equal(redeemRes.body.data.transaction.pointsDelta, -300);
  assert.equal(redeemRes.body.data.transaction.tierPointsDelta, 0);

  // 3. Replaying same idempotency-key does NOT double-deduct points
  const replay = await api('/loyalty/redemptions', {
    method: 'POST',
    headers: { 'idempotency-key': idemKey },
    body: { rewardId: rewardVoucherId },
  });
  assert.equal(replay.status, 200);
  assert.equal(replay.body.data.summary.availablePoints, 940);

  // 4. Out-of-stock reward returns 409 REWARD_OUT_OF_STOCK
  const soldOut = await api('/loyalty/redemptions', {
    method: 'POST',
    body: { rewardId: rewardSoldOutId },
  });
  assert.equal(soldOut.status, 409);
  assert.equal(soldOut.body.error.code, 'REWARD_OUT_OF_STOCK');

  // 5. Redeem 400-pt InBody service (remaining: 540) -> Member cannot self-use service requiring staff confirmation
  const redeemInbody = await api('/loyalty/redemptions', {
    method: 'POST',
    body: { rewardId: rewardInbodyId },
  });
  assert.equal(redeemInbody.status, 201);
  assert.equal(redeemInbody.body.data.summary.availablePoints, 540);
  assert.equal(redeemInbody.body.data.summary.tierPoints, 2150);

  const memberSelfUseService = await api(
    `/loyalty/redemptions/${redeemInbody.body.data.redemption.id}/use`,
    { method: 'POST' },
  );
  assert.equal(memberSelfUseService.status, 403);
  assert.equal(memberSelfUseService.body.error.code, 'STAFF_CONFIRM_REQUIRED');

  // Admin confirms service redemption cleanly
  const adminConfirm = await api(
    `/loyalty/redemptions/${redeemInbody.body.data.redemption.id}/use`,
    { role: 'ADMIN', id: adminId, method: 'POST' },
  );
  assert.equal(adminConfirm.status, 200);
  assert.equal(adminConfirm.body.data.status, 'USED');

  // 6. Insufficient points guard (trying 400pt InBody again? Wait: balance is 540, try twice!)
  await api('/loyalty/redemptions', { method: 'POST', body: { rewardId: rewardInbodyId } }); // -> 140
  const insufficient = await api('/loyalty/redemptions', {
    method: 'POST',
    body: { rewardId: rewardVoucherId }, // costs 300 > 140
  });
  assert.equal(insufficient.status, 409);
  assert.equal(insufficient.body.error.code, 'INSUFFICIENT_POINTS');

  // 7. Point history records all 3 spends with tierPointsDelta = 0
  const txList = await api('/loyalty/transactions/me?type=SPEND');
  assert.equal(txList.status, 200);
  assert.equal(txList.body.data.length, 3);
  assert.ok(txList.body.data.every((tx) => tx.tierPointsDelta === 0));
});
