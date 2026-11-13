import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import express from 'express';
import jwt from 'jsonwebtoken';

import { createGymVisitsRouter } from '../src/routes/gym-visits.routes.js';

const secret = 'gym-checkin-test-secret-with-at-least-32-chars';
const code = randomUUID();
const memberId = randomUUID();
const adminId = randomUUID();
const coachId = randomUUID();

function bearer(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, secret, {
    algorithm: 'HS256', audience: 'meta-gym-clients',
    issuer: 'meta-gym-api', subject: id, expiresIn: 3600,
  });
}

test('QR visits allow repeat entries while calendar counts unique days and protects Admin code', async () => {
  const visits = [];
  let activeCode = code;
  let hasMembership = true;
  let auditWrites = 0;
  const database = {
    async query(sql, args = []) {
      if (sql.includes('FROM users u')) {
        const role = args[0] === memberId ? 'MEMBER' : args[0] === adminId ? 'ADMIN' : 'COACH';
        return { rows: [{ id: args[0], role, status: 'ACTIVE', session_version: 0 }] };
      }
      if (sql.includes('SELECT code, updated_at FROM gym_checkin_code')) {
        return { rows: [{ code: activeCode, updated_at: new Date() }] };
      }
      if (sql.includes('UPDATE gym_checkin_code SET code')) {
        activeCode = args[0];
        return { rows: [{ updated_at: new Date() }] };
      }
      if (sql.includes('INSERT INTO admin_audit_logs')) {
        auditWrites++;
        assert.equal(args.length, 2);
        return { rows: [] };
      }
      if (sql.includes('SELECT 1 FROM gym_checkin_code')) {
        return { rows: args[0] === activeCode ? [{ '?column?': 1 }] : [] };
      }
      if (sql.includes('SELECT 1 FROM member_memberships')) {
        return { rows: hasMembership ? [{ '?column?': 1 }] : [] };
      }
      if (sql.includes('INSERT INTO gym_visits')) {
        const row = { id: args[0], day: '2026-11-13', checked_in_at: new Date(),
          gym_name: 'Meta Gym', gym_address: 'Quầy lễ tân' };
        visits.push(row);
        return { rows: [row] };
      }
      if (sql.includes('FROM gym_visits WHERE')) return { rows: visits };
      if (sql.includes('eligible_days')) return { rows: [{ eligible_days: 13 }] };
      return { rows: [] };
    },
    async connect() { return { query: this.query.bind(this), release() {} }; },
  };
  const app = express();
  app.use(express.json());
  app.use('/api/v1', createGymVisitsRouter({ database, jwtSecret: secret }));
  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}/api/v1`;
  async function call(path, id, role, body) {
    const response = await fetch(base + path, {
      method: body ? 'POST' : 'GET',
      headers: { authorization: `Bearer ${bearer(id, role)}`,
        ...(body ? { 'content-type': 'application/json' } : {}) },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    return { status: response.status, body: await response.json() };
  }
  try {
    assert.equal((await call('/admin/gym-checkin-code', memberId, 'MEMBER')).status, 403);
    assert.equal((await call('/admin/gym-checkin-code', adminId, 'ADMIN')).body.data.payload,
      `metagym://gym-checkin/${code}`);
    assert.equal((await call('/gym-visits/check-in', coachId, 'COACH', { code: `metagym://gym-checkin/${code}` })).status, 403);
    assert.equal((await call('/gym-visits/check-in', memberId, 'MEMBER', { code: 'https://other.example' })).status, 422);
    hasMembership = false;
    assert.equal((await call('/gym-visits/check-in', memberId, 'MEMBER', { code: `metagym://gym-checkin/${code}` })).status, 403);
    hasMembership = true;
    assert.equal((await call('/gym-visits/check-in', memberId, 'MEMBER', { code: `metagym://gym-checkin/${code}` })).status, 201);
    assert.equal((await call('/gym-visits/check-in', memberId, 'MEMBER', { code: `metagym://gym-checkin/${code}` })).status, 201);
    const month = await call('/gym-visits/me?month=2026-11', memberId, 'MEMBER');
    assert.equal(month.status, 200);
    assert.equal(month.body.data.entryCount, 2);
    assert.equal(month.body.data.visitedDays, 1);
    assert.equal(month.body.data.eligibleDays, 13);
    const rotated = await call('/admin/gym-checkin-code/rotate', adminId, 'ADMIN', {});
    assert.equal(rotated.status, 200);
    assert.equal(auditWrites, 1);
    assert.equal((await call('/gym-visits/check-in', memberId, 'MEMBER',
      { code: `metagym://gym-checkin/${code}` })).status, 422);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
