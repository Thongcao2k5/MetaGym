import dotenv from 'dotenv';
import jwt from 'jsonwebtoken';
import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import path from 'node:path';
import { createDatabasePool } from '../src/config/database.js';

dotenv.config({ quiet: true });
const base = `http://127.0.0.1:${process.env.PORT || 3000}/api/v1`;
const directory = path.join(homedir(), 'Documents', 'MetaGym-Coach-Test');
const credentials = JSON.parse(await readFile(path.join(directory, 'accounts.json'), 'utf8'));
const pool = createDatabasePool();
const checks = [];
const members = Object.fromEntries(credentials.members.map((m) => [m.email.split('@')[0], m]));
async function tokenFor(email) {
  const user = (await pool.query('SELECT id,role,session_version FROM users WHERE email=$1', [email])).rows[0];
  assert(user, `Missing account ${email}`);
  return jwt.sign({ role: user.role, sessionVersion: user.session_version }, process.env.JWT_SECRET,
    { algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api', subject: user.id, expiresIn: '10m' });
}
async function check(label, route, token, { expected = 200, validate = () => {}, method = 'GET', body } = {}) {
  const response = await fetch(`${base}${route}`, { method, signal: AbortSignal.timeout(10000),
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}), 'Content-Type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
  const json = await response.json();
  assert.equal(response.status, expected, `${label}: ${response.status} ${json.error?.code || ''}`);
  validate(json);
  checks.push({ label, status: response.status, passed: true });
  return json;
}
try {
  await check('Backend health', '/health');
  const login = await check('New Coach credentials', '/auth/sessions', null, { method: 'POST',
    body: { email: credentials.setupCoach.email, password: credentials.password },
    validate: (j) => assert(j.data?.accessToken) });
  const setup = login.data.accessToken;
  const coach = await tokenFor('coach@metagym.local');
  await check('Coach profile', '/users/me', coach);
  await check('Setup Coach empty roster', '/coach/members', setup, { validate: (j) => assert.equal(j.data.length, 0) });
  await check('Setup Coach empty schedule', `/coaches/${credentials.setupCoach.id}/work-slots`, setup,
    { validate: (j) => assert.equal(j.data.days.length, 0) });
  await check('Main Coach roster with five new current students', '/coach/members', coach,
    { validate: (j) => assert.equal(j.data.filter((m) => m.memberId?.startsWith('c0ac2026-')).length, 5) });
  const requests = await check('Request list and states', '/coach/requests', coach,
    { validate: (j) => {
      assert.equal(j.data.filter((r) => r.id.startsWith('c0ac2026-') && r.status === 'PENDING').length, 3);
      for (const state of ['ACCEPTED', 'REJECTED', 'CANCELLED']) assert(j.data.some((r) => r.id.startsWith('c0ac2026-') && r.status === state));
    } });
  const pending = requests.data.find((r) => r.status === 'PENDING' && r.id.startsWith('c0ac2026-'));
  await check('Request detail', `/coach/requests/${pending.id}`, coach);
  if (process.env.ENABLE_COACH_WORKFLOWS === 'true') {
    await check('Coach approval is enabled and validates input', `/coach/requests/${pending.id}`, coach,
      { method: 'PATCH', body: { decision: 'INVALID' }, expected: 422 });
    await check('Other Coach cannot approve the fixture request', `/coach/requests/${pending.id}`, setup,
      { method: 'PATCH', body: { decision: 'ACCEPTED' }, expected: 404 });
  } else {
    await check('Legacy approval is explicitly retired', `/coach/requests/${pending.id}`, coach,
      { method: 'PATCH', body: { status: 'ACCEPTED' }, expected: 410,
        validate: (j) => assert.equal(j.error.code, 'LEGACY_WORKFLOW_RETIRED') });
  }
  await check('Coach booking states', '/coach-bookings', coach, { validate: (j) => {
    const fixture = j.data.filter((r) => r.id.startsWith('c0ac2026-'));
    assert.equal(fixture.length, 28);
    for (const state of ['BOOKED', 'COMPLETED', 'CANCELLED']) assert(fixture.some((r) => r.status === state));
    assert(fixture.some((r) => r.status === 'CANCELLED' && r.chargedAt));
    assert(fixture.some((r) => r.status === 'CANCELLED' && !r.chargedAt));
  } });
  await check('Coach blocked slot', '/coach-bookings/blocks', coach, { validate: (j) => assert(j.data.some((b) => b.reason.startsWith('[COACH_TEST]'))) });
  await check('Coach notifications', '/coach-notifications', coach, { validate: (j) => {
    assert(j.data.some((n) => n.subjectId.startsWith('c0ac2026-') && n.readAt));
    assert(j.data.some((n) => n.subjectId.startsWith('c0ac2026-') && !n.readAt));
  } });
  await check('Work schedule', '/coaches/10000000-0000-4000-8000-000000000002/work-slots', coach,
    { validate: (j) => assert(j.data.days.length === 7 && j.data.days.every((d) => d.starts.length >= 4)) });
  await check('PT catalog', '/coach-packages', coach, { validate: (j) => assert.equal(j.data.length, 3) });
  await check('Coach conversations', '/conversations', coach);
  await check('Coach call history', '/calls', coach, { validate: (j) => assert(j.data.filter((c) => c.id.startsWith('c0ac2026-')).length >= 6) });
  await check('Training session states', '/coach/training-sessions', coach, { validate: (j) => {
    for (const state of ['SCHEDULED', 'COMPLETED', 'MEMBER_ABSENT', 'CANCELLED']) {
      assert(j.data.some((s) => s.id.startsWith('c0ac2026-') && s.status === state));
    }
  } });
  for (const key of ['gain', 'lose', 'expiry', 'new', 'paused']) {
    await check(`${key} student profile`, `/coach/members/${members[key].id}`, coach, { validate: (j) => {
      if (key === 'paused') assert.equal(j.data.member.heightCm, null);
      else assert(j.data.member.heightCm > 0);
    } });
    const plans = await check(`${key} training plans`, `/coach/members/${members[key].id}/training-plans`, coach,
      { validate: (j) => assert.equal(j.data.length, key === 'new' ? 0 : key === 'paused' ? 1 : 3) });
    if (key === 'gain') {
      const active = plans.data.find((p) => p.status === 'ACTIVE');
      await check('Training plan detail includes scheduled days', `/training-plans/${active.id}`, coach,
        { validate: (j) => assert.equal(j.data.days.length, 3) });
    }
    await check(`${key} meal plan`, `/coach/meal-plans/${members[key].id}`, coach, { validate: (j) =>
      assert.equal(j.data.items.length, ['new', 'paused'].includes(key) ? 0 : 42) });
  }
  await check('Coach cannot read private journal', `/coach/members/${members.gain.id}/progress/summary`, coach, { expected: 403 });
  await check('Coach cannot read another Coach roster', `/coach/members/${members.gain.id}`, setup, { expected: 404 });
  await check('Coach outcome consent cases', `/coach/members/${members.gain.id}/outcomes`, coach,
    { validate: (j) => assert.equal(j.data.length, 2) });
  const memberToken = await tokenFor(members.gain.email);
  await check('Member current and renewal packages', '/coach-entitlements', memberToken, { validate: (j) => {
    assert(j.data.some((e) => e.status === 'ACTIVE'));
    assert(j.data.some((e) => e.status === 'QUEUED'));
  } });
  await check('Member sees published training plan', '/training-plans/me/active', memberToken);
  await check('Member sees published meal plans', '/meal-plans/me', memberToken,
    { validate: (j) => assert.equal(j.data.find((p) => p.status === 'ACTIVE').items.length, 42) });
  const current = (await pool.query("SELECT e.id,r.id AS relationship_id FROM coach_entitlements e JOIN coach_relationships r ON r.id=e.relationship_id WHERE e.member_id=$1 AND e.status='ACTIVE'", [members.gain.id])).rows[0];
  await check('Five demo chat messages', `/conversations/${current.relationship_id}/messages`, coach,
    { validate: (j) => assert.equal(j.data.length, 5) });
  await check('Member sees private progress', '/progress/me/summary', memberToken);
  const fresh = await tokenFor(members.new.email);
  const date = (await pool.query("SELECT ((now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date+6)::text AS day")).rows[0].day;
  const entitlement = (await pool.query("SELECT id FROM coach_entitlements WHERE member_id=$1 AND status='ACTIVE'", [members.new.id])).rows[0];
  await check('New student can find available PT slots', `/coach-bookings/available-slots?entitlementId=${entitlement.id}&date=${date}`, fresh,
    { validate: (j) => assert(j.data.length > 0) });
  const consistency = (await pool.query(
    `SELECT e.id FROM coach_entitlements e LEFT JOIN coach_bookings b ON b.entitlement_id=e.id
     WHERE e.id::text LIKE 'c0ac2026-%' GROUP BY e.id
     HAVING e.remaining_sessions<>e.total_sessions-count(b.id) FILTER (WHERE b.charged_at IS NOT NULL)
       OR count(b.id) FILTER (WHERE b.status='BOOKED')>e.remaining_sessions`,
  )).rows;
  assert.equal(consistency.length, 0);
  checks.push({ label: 'All fixture session balances match charged bookings', passed: true });
  const overlap = (await pool.query(
    `SELECT a.id FROM training_sessions a JOIN coach_relationships ar ON ar.id=a.relationship_id
     JOIN training_sessions b ON b.id>a.id JOIN coach_relationships br ON br.id=b.relationship_id
     WHERE ar.coach_id=br.coach_id AND a.status='SCHEDULED' AND b.status='SCHEDULED'
       AND (a.id::text LIKE 'c0ac2026-%' OR b.id::text LIKE 'c0ac2026-%')
       AND a.scheduled_start_at<coalesce(b.scheduled_end_at,b.scheduled_start_at+interval '90 minutes')
       AND b.scheduled_start_at<coalesce(a.scheduled_end_at,a.scheduled_start_at+interval '90 minutes')`,
  )).rows;
  assert.equal(overlap.length, 0);
  checks.push({ label: 'No scheduled training session overlaps', passed: true });
  const report = { verifiedAt: new Date().toISOString(), base, passed: checks.length, checks,
    scope: 'Data/API read verification, new account login, workflow gate validation and privacy checks. No payment or external call executed.' };
  await writeFile(path.join(directory, 'verification.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
} catch (error) {
  console.error(JSON.stringify({ passedBeforeFailure: checks.length, error: error.message }));
  process.exitCode = 1;
} finally { await pool.end(); }
