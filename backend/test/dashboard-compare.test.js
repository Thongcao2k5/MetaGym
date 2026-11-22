import assert from 'node:assert/strict';
import test from 'node:test';
import express from 'express';
import jwt from 'jsonwebtoken';

import { createDashboardRouter } from '../src/routes/dashboard.routes.js';

const adminId = '11111111-1111-4111-8111-111111111111';
const secret = 'dashboard-compare-test-secret-32-chars';

async function createTestServer(t, { role = 'ADMIN' } = {}) {
  const database = {
    async query(sql, args = []) {
      if (sql.includes('FROM users u')) {
        return { rows: [{ id: adminId, role, status: 'ACTIVE', session_version: 0 }] };
      }
      if (sql.includes('UPDATE coach_termination_requests')) {
        return { rows: [] };
      }
      if (sql.includes('GROUP BY role, status')) {
        return {
          rows: [
            { role: 'MEMBER', status: 'ACTIVE', count: 120 },
            { role: 'MEMBER', status: 'DISABLED', count: 4 },
            { role: 'COACH', status: 'ACTIVE', count: 10 },
          ],
        };
      }
      if (sql.includes('GROUP BY role') && sql.includes('disabled_at')) {
        const asOf = args[0];
        const isCurrent = asOf >= '2026-11-16';
        return {
          rows: [
            { role: 'MEMBER', count: isCurrent ? 120 : 100 },
            { role: 'COACH', count: isCurrent ? 10 : 8 },
          ],
        };
      }
      if (sql.includes('FROM member_memberships')) {
        const asOf = args[0];
        if (!asOf) return { rows: [{ count: 90 }] };
        return { rows: [{ count: asOf >= '2026-11-16' ? 90 : 75 }] };
      }
      if (sql.includes('FROM gym_visits')) {
        return { rows: [{ count: 42 }] };
      }
      if (sql.includes('FROM coach_relationships') && sql.includes('GROUP BY status')) {
        return { rows: [{ status: 'ACTIVE', pause_reason: null, count: 30 }] };
      }
      if (sql.includes('FROM coach_relationships')) {
        const asOf = args[0];
        return { rows: [{ count: asOf >= '2026-11-16' ? 30 : 25 }] };
      }
      if (sql.includes('FROM coach_lock_incidents') && sql.includes('GROUP BY member_choice')) {
        return { rows: [{ member_choice: 'WAIT', count: 1 }] };
      }
      if (sql.includes('FROM coach_lock_incidents')) {
        const asOf = args[0];
        return { rows: [{ count: asOf >= '2026-11-16' ? 1 : 2 }] };
      }
      if (sql.includes('FROM coach_termination_requests') && !sql.includes('disputed_at IS NOT NULL')) {
        return { rows: [{ count: 2 }] };
      }
      if (sql.includes('FROM coach_termination_requests')) {
        assert.equal(sql.includes('resolved_at'), false, 'coach_termination_requests uses decided_at, not resolved_at');
        const asOf = args[0];
        return { rows: [{ count: asOf >= '2026-11-16' ? 2 : 2 }] };
      }
      if (sql.includes('FROM payments') && sql.includes('GROUP BY day')) {
        return { rows: [{ day: '2026-11-20', amount: '15000000', count: 5 }] };
      }
      if (sql.includes('FROM payments')) {
        const from = args[0];
        return { rows: [{ amount: from >= '2026-11-16' ? '15000000' : '10000000' }] };
      }
      if (sql.includes('FROM payment_adjustments') && sql.includes('GROUP BY day')) {
        return { rows: [] };
      }
      if (sql.includes('FROM payment_adjustments')) {
        return { rows: [{ amount: '0' }] };
      }
      if (sql.includes('FROM coach_payment_holds') && sql.includes('GROUP BY day')) {
        return { rows: [{ day: '2026-11-20', amount: '5000000', count: 2 }] };
      }
      if (sql.includes('FROM coach_payment_holds')) {
        const from = args[0];
        return { rows: [{ amount: from >= '2026-11-16' ? '5000000' : '5000000' }] };
      }
      if (sql.includes('FROM simulated_refunds') && sql.includes('GROUP BY day')) {
        return { rows: [{ day: '2026-11-21', amount: '1000000', count: 1 }] };
      }
      if (sql.includes('FROM simulated_refunds')) {
        const from = args[0];
        return { rows: [{ amount: from >= '2026-11-16' ? '1000000' : '2000000' }] };
      }
      if (sql.includes('FROM users') && sql.includes('GROUP BY day')) {
        return { rows: [] };
      }
      return { rows: [] };
    },
  };

  const app = express();
  app.use('/api/v1', createDashboardRouter({ database, jwtSecret: secret }));
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const bearer = jwt.sign({ role, sessionVersion: 0 }, secret, {
    subject: adminId,
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    expiresIn: 60,
  });

  return {
    async call(path) {
      const res = await fetch(`http://127.0.0.1:${server.address().port}/api/v1${path}`, {
        headers: { authorization: `Bearer ${bearer}` },
      });
      return { status: res.status, body: await res.json() };
    },
  };
}

test('GET /admin/dashboard/compare rejects non-ADMIN and invalid date ranges', async (t) => {
  const memberApi = await createTestServer(t, { role: 'MEMBER' });
  const forbidden = await memberApi.call('/admin/dashboard/compare?from=2026-11-16&to=2026-11-22');
  assert.equal(forbidden.status, 403);

  const adminApi = await createTestServer(t, { role: 'ADMIN' });
  const missingTo = await adminApi.call('/admin/dashboard/compare?from=2026-11-16');
  assert.equal(missingTo.status, 422);

  const partialCompare = await adminApi.call('/admin/dashboard/compare?from=2026-11-16&to=2026-11-22&compareFrom=2026-11-01');
  assert.equal(partialCompare.status, 422);

  const invertedCompare = await adminApi.call('/admin/dashboard/compare?from=2026-11-16&to=2026-11-22&compareFrom=2026-11-10&compareTo=2026-11-01');
  assert.equal(invertedCompare.status, 422);
});

test('GET /admin/dashboard/compare auto-computes previous period and returns percentage deltas', async (t) => {
  const adminApi = await createTestServer(t, { role: 'ADMIN' });
  const res = await adminApi.call('/admin/dashboard/compare?from=2026-11-16&to=2026-11-22');
  assert.equal(res.status, 200);

  const { current, previous, comparison } = res.body.data;
  assert.equal(current.from, '2026-11-16');
  assert.equal(current.to, '2026-11-22');
  assert.equal(previous.from, '2026-11-09');
  assert.equal(previous.to, '2026-11-15');

  // grossRevenue: 20,000,000 vs 15,000,000 -> +33.3%
  assert.equal(comparison.grossRevenue.current, 20000000);
  assert.equal(comparison.grossRevenue.previous, 15000000);
  assert.equal(comparison.grossRevenue.delta, 5000000);
  assert.equal(comparison.grossRevenue.percentChange, 33.3);
  assert.equal(comparison.grossRevenue.direction, 'up');

  // totalSimulatedRefunds: 1,000,000 vs 2,000,000 -> -50%
  assert.equal(comparison.totalSimulatedRefunds.delta, -1000000);
  assert.equal(comparison.totalSimulatedRefunds.percentChange, -50);
  assert.equal(comparison.totalSimulatedRefunds.direction, 'down');

  // membersActive: 120 vs 100 -> +20%
  assert.equal(comparison.membersActive.percentChange, 20);
  assert.equal(comparison.membersActive.direction, 'up');

  // disputedTerminations: 2 vs 2 -> 0% flat
  assert.equal(comparison.disputedTerminations.percentChange, 0);
  assert.equal(comparison.disputedTerminations.direction, 'flat');

  // revenueChart: 6-month independent window
  assert.ok(current.dashboard.revenueChart.from);
  assert.ok(current.dashboard.revenueChart.to);
  assert.ok(Array.isArray(current.dashboard.revenueChart.byDay));
});
