import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';

import { createApp } from '../src/app.js';
import { STAFF_POSITION_DEFINITIONS, hasBackofficePermission } from '../src/modules/users/staff-positions.js';

const SECRET = 'staff-positions-test-secret-with-32-chars';

function tokenFor(id, role) {
  return jwt.sign({ role, sessionVersion: 0 }, SECRET, {
    algorithm: 'HS256',
    audience: 'meta-gym-clients',
    issuer: 'meta-gym-api',
    subject: id,
    expiresIn: 3600,
  });
}

test('Staff positions cover all 5 MetaGym positions and enforce RBAC for STAFF/ADMIN/MEMBER', async () => {
  assert.deepEqual(
    STAFF_POSITION_DEFINITIONS.map((p) => p.code),
    ['ADMIN', 'MANAGER', 'RECEPTIONIST', 'COACH', 'TECHNICIAN'],
  );

  const adminId = randomUUID();
  const managerId = randomUUID();
  const recepId = randomUUID();
  const memberId = randomUUID();

  const users = new Map([
    [adminId, { id: adminId, email: 'admin@metagym.vn', full_name: 'Meta Admin', phone: null, role: 'ADMIN', status: 'ACTIVE', session_version: 0 }],
    [managerId, { id: managerId, email: 'manager@metagym.vn', full_name: 'Trần Quản Lý', phone: '0903112233', role: 'STAFF', status: 'ACTIVE', session_version: 0, position_code: 'MANAGER', department: 'Điều hành' }],
    [recepId, { id: recepId, email: 'letan@metagym.vn', full_name: 'Nguyễn Lễ Tân', phone: '0904223344', role: 'STAFF', status: 'ACTIVE', session_version: 0, position_code: 'RECEPTIONIST', department: 'Quầy lễ tân' }],
    [memberId, { id: memberId, email: 'member@metagym.vn', full_name: 'Hội viên A', phone: null, role: 'MEMBER', status: 'ACTIVE', session_version: 0 }],
  ]);

  const roleIds = new Map([
    ['super_admin', '00000000-0000-4000-8000-000000000101'],
    ['manager', '00000000-0000-4000-8000-000000000104'],
    ['receptionist', '00000000-0000-4000-8000-000000000105'],
    ['coach', '00000000-0000-4000-8000-000000000106'],
    ['technician', '00000000-0000-4000-8000-000000000107'],
  ]);

  const runQuery = async (sql, params = []) => {
    const text = String(sql).replace(/\s+/g, ' ').trim();
    if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(text)) return { rows: [], rowCount: 0 };
    if (text.includes('FROM users u') && text.includes('WHERE u.id = $1')) {
      const u = users.get(params[0]);
      return { rows: u ? [u] : [] };
    }
    if (text.includes('FROM staff_profiles sp') && text.includes('WHERE sp.user_id = $1')) {
      const u = users.get(params[0]);
      if (!u || u.role !== 'STAFF') return { rows: [] };
      const def = STAFF_POSITION_DEFINITIONS.find((p) => p.code === u.position_code);
      return { rows: [{ position_code: u.position_code, department: u.department, shift_note: u.shift_note || null, role_permissions: def.permissions }] };
    }
    if (text.includes('WHERE id = $1 AND role = \'ADMIN\'')) {
      const u = users.get(params[0]);
      return { rows: u?.role === 'ADMIN' ? [{ id: u.id }] : [] };
    }
    if (text.includes('WHERE u.id = $1 AND u.role = \'STAFF\'')) {
      const u = users.get(params[0]);
      return { rows: u?.role === 'STAFF' ? [{ id: u.id }] : [] };
    }
    if (text.includes('GROUP BY 1')) {
      return {
        rows: [
          { position: 'ADMIN', total_count: 1, active_count: 1 },
          { position: 'MANAGER', total_count: 1, active_count: 1 },
          { position: 'RECEPTIONIST', total_count: 1, active_count: 1 },
        ],
      };
    }
    if (text.startsWith('SELECT count(*)::int AS count FROM users u')) {
      return { rows: [{ count: users.size - 1 }] };
    }
    if (text.includes('FROM users u LEFT JOIN staff_profiles sp') && text.includes('ORDER BY CASE')) {
      return {
        rows: [...users.values()].filter((u) => u.role !== 'MEMBER'),
      };
    }
    if (text.startsWith('SELECT id FROM roles WHERE code = $1')) {
      const id = roleIds.get(params[0]);
      return { rows: id ? [{ id }] : [] };
    }
    if (text.startsWith('INSERT INTO users')) {
      const [id, email, , role, fullName, phone] = params;
      users.set(id, { id, email, full_name: fullName, phone, role, status: 'ACTIVE', session_version: 0 });
      return { rows: [], rowCount: 1 };
    }
    if (text.startsWith('INSERT INTO staff_profiles')) {
      const [id, position, department, shiftNote] = params;
      const u = users.get(id);
      if (u) Object.assign(u, { position_code: position, department, shift_note: shiftNote });
      return { rows: [], rowCount: 1 };
    }
    if (text.includes('LEFT JOIN staff_profiles sp ON sp.user_id = u.id WHERE u.id = $1')) {
      const u = users.get(params[0]);
      return { rows: u ? [u] : [] };
    }
    if (text.includes('WHERE u.id = $1 AND u.role IN (\'ADMIN\', \'STAFF\')')) {
      const u = users.get(params[0]);
      return { rows: u ? [u] : [] };
    }
    if (text.startsWith('UPDATE users SET full_name =')) {
      const [fullName, phone, status, disabledAt, disabledReason, , inc, id] = params;
      const u = users.get(id);
      if (u) Object.assign(u, { full_name: fullName, phone, status, disabled_at: disabledAt, disabled_reason: disabledReason, session_version: u.session_version + inc });
      return { rows: [], rowCount: 1 };
    }
    return { rows: [] };
  };

  assert.equal(hasBackofficePermission({ role: 'STAFF', position_code: 'RECEPTIONIST' }, 'payments:frontdesk'), true);
  assert.equal(hasBackofficePermission({ role: 'STAFF', position_code: 'RECEPTIONIST' }, 'staff:manage'), false);
  assert.equal(hasBackofficePermission({ role: 'STAFF', position_code: 'TECHNICIAN' }, 'equipment:manage'), true);

  const app = createApp({
    database: { query: runQuery, connect: async () => ({ query: runQuery, release() {} }) },
    jwtSecret: SECRET,
  });
  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  const adminTok = tokenFor(adminId, 'ADMIN');
  const managerTok = tokenFor(managerId, 'STAFF');
  const recepTok = tokenFor(recepId, 'STAFF');
  const memberTok = tokenFor(memberId, 'MEMBER');

  try {
    // Member and Receptionist cannot view or mutate staff directory
    assert.equal((await fetch(`${base}/api/v1/admin/staff-positions`, { headers: { authorization: `Bearer ${memberTok}` } })).status, 403);
    assert.equal((await fetch(`${base}/api/v1/admin/staff`, { headers: { authorization: `Bearer ${recepTok}` } })).status, 403);

    // Manager can view positions and create Technician, but cannot appoint another Manager
    const posRes = await fetch(`${base}/api/v1/admin/staff-positions`, { headers: { authorization: `Bearer ${managerTok}` } });
    assert.equal(posRes.status, 200);
    assert.equal((await posRes.json()).data.positions.length, 5);

    const denyMgr = await fetch(`${base}/api/v1/admin/staff`, {
      method: 'POST',
      headers: { authorization: `Bearer ${managerTok}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        fullName: 'Another Manager',
        email: 'mgr2@metagym.vn',
        position: 'MANAGER',
        password: 'Password123!',
      }),
    });
    assert.equal(denyMgr.status, 403);

    // Admin can create Technician and promote them to Manager
    const createdTech = await fetch(`${base}/api/v1/admin/staff`, {
      method: 'POST',
      headers: { authorization: `Bearer ${adminTok}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        fullName: 'Kỹ Thuật Viên Mới',
        email: 'tech2@metagym.vn',
        position: 'TECHNICIAN',
        shiftNote: 'Ca chiều',
        password: 'Password123!',
      }),
    });
    assert.equal(createdTech.status, 201);
    const createdJson = await createdTech.json();
    assert.equal(createdJson.data.position, 'TECHNICIAN');

    const promoted = await fetch(`${base}/api/v1/admin/staff/${createdJson.data.id}`, {
      method: 'PATCH',
      headers: { authorization: `Bearer ${adminTok}`, 'content-type': 'application/json' },
      body: JSON.stringify({ position: 'MANAGER' }),
    });
    assert.equal(promoted.status, 200);
    assert.equal((await promoted.json()).data.position, 'MANAGER');
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
