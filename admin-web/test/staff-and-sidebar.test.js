import assert from 'node:assert/strict';
import test from 'node:test';

import { createDomEnvironment, flush, jsonResponse } from './helpers/dom-harness.js';
import { NAV_GROUPS, renderShell } from '../src/components/layout.js';
import { renderStaffPage } from '../src/pages/staff.js';
import { setCurrentUser, setToken } from '../src/services/api.js';
import { parseHash } from '../src/state/router.js';

test('Sidebar is prioritized top-to-bottom and filters per staff position', () => {
  assert.deepEqual(
    NAV_GROUPS.map((g) => g.label),
    [
      'Ưu tiên xử lý',
      'Quầy lễ tân & Hội viên',
      'Nhân sự & Vị trí nhân viên',
      'Gói dịch vụ & Bảng giá',
      'Thiết bị & Chuyên môn',
      'Kho Media & Image Server',
      'Hệ thống & Kiểm soát',
    ],
  );
  assert.equal(NAV_GROUPS[0].items[0].id, 'dashboard');
  assert.equal(NAV_GROUPS[1].items[0].id, 'payments');
  assert.equal(NAV_GROUPS[2].items[0].id, 'staff');
  assert.equal(parseHash('#/admin/nhansu').section, 'staff');

  // Receptionist sees Reception & Dashboard, never Admin Audit Logs or Staff Management
  const recEnv = createDomEnvironment({ hash: '#/admin/payments', token: 'tok' });
  renderShell({
    root: recEnv.root,
    section: 'payments',
    user: { role: 'STAFF', staffPosition: 'RECEPTIONIST', fullName: 'Nguyễn Lễ Tân', email: 'letan@metagym.vn' },
    contentHtml: '<p>ok</p>',
  });
  assert.ok(recEnv.root.querySelector('a.meta-nav-item[href="#/admin/payments"]'));
  assert.ok(recEnv.root.querySelector('a.meta-nav-item[href="#/admin/gym"]'));
  assert.equal(recEnv.root.querySelector('a.meta-nav-item[href="#/admin/audit-logs"]'), null);
  assert.equal(recEnv.root.querySelector('a.meta-nav-item[href="#/admin/staff"]'), null);
  assert.equal(recEnv.root.innerHTML.includes('Lễ tân &amp; Thu ngân'), true);
});

test('Staff module renders 5 employee positions, creates new staff, and previews Sidebar by position', async () => {
  const env = createDomEnvironment({ hash: '#/admin/staff', token: 'tok' });
  setToken('tok');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', staffPosition: 'ADMIN', permissions: ['*'], fullName: 'Meta Admin', email: 'admin@metagym.vn' });

  const createdPayloads = [];
  const positionsData = [
    { code: 'ADMIN', priority: 1, title: 'Quản trị viên (Admin)', shortTitle: 'Quản trị viên', portal: 'Web Admin (Toàn quyền)', activeCount: 1, totalCount: 1, description: 'Owner', sidebarHighlights: ['Full'] },
    { code: 'MANAGER', priority: 2, title: 'Quản lý vận hành / Trưởng ca', shortTitle: 'Quản lý vận hành', portal: 'Web Admin (Điều hành)', activeCount: 1, totalCount: 1, description: 'Manager', sidebarHighlights: ['Ops'] },
    { code: 'RECEPTIONIST', priority: 3, title: 'Lễ tân & Thu ngân', shortTitle: 'Lễ tân & Thu ngân', portal: 'Web Admin (Quầy)', activeCount: 1, totalCount: 1, description: 'Front desk', sidebarHighlights: ['POS'] },
    { code: 'COACH', priority: 4, title: 'Huấn luyện viên (Coach)', shortTitle: 'Huấn luyện viên', portal: 'Ứng dụng Coach (Mobile)', activeCount: 3, totalCount: 3, description: 'Coach', sidebarHighlights: ['App'] },
    { code: 'TECHNICIAN', priority: 5, title: 'Kỹ thuật viên & Nội dung', shortTitle: 'Kỹ thuật viên', portal: 'Web Admin (Cơ sở & Media)', activeCount: 1, totalCount: 1, description: 'Tech', sidebarHighlights: ['Eq'] },
  ];

  globalThis.fetch = async (url, opts = {}) => {
    const u = new URL(url, 'http://localhost');
    if (u.pathname === '/api/v1/admin/staff-positions') {
      return jsonResponse({ data: { positions: positionsData, currentActorPosition: 'ADMIN' } });
    }
    if (u.pathname === '/api/v1/admin/staff' && (!opts.method || opts.method === 'GET')) {
      return jsonResponse({
        data: [
          { id: 'u1', fullName: 'Trần Minh Quân', email: 'manager@metagym.vn', phone: '0903112233', role: 'STAFF', position: 'MANAGER', positionShortTitle: 'Quản lý vận hành', department: 'Điều hành', shiftNote: 'Trưởng ca', status: 'ACTIVE' },
          { id: 'u2', fullName: 'Nguyễn Thảo Vy', email: 'letan@metagym.vn', phone: '0904223344', role: 'STAFF', position: 'RECEPTIONIST', positionShortTitle: 'Lễ tân & Thu ngân', department: 'Quầy lễ tân', shiftNote: 'Ca sáng', status: 'ACTIVE' },
        ],
        pagination: { page: 1, pageSize: 20, totalItems: 2, totalPages: 1 },
      });
    }
    if (u.pathname === '/api/v1/admin/staff' && opts.method === 'POST') {
      createdPayloads.push(JSON.parse(opts.body));
      return jsonResponse({ data: { id: 'u-new' } }, 201);
    }
    throw new Error(`Unexpected ${opts.method || 'GET'} ${u.pathname}`);
  };

  await renderStaffPage({
    root: env.root,
    params: new URLSearchParams(),
    shell: (opts) => renderShell({
      root: env.root,
      user: { id: 'adm-1', role: 'ADMIN', staffPosition: 'ADMIN', permissions: ['*'], fullName: 'Meta Admin', email: 'admin@metagym.vn' },
      ...opts,
    }),
  });

  assert.equal(env.root.innerHTML.includes('Trần Minh Quân'), true);
  assert.equal(env.root.innerHTML.includes('Nguyễn Thảo Vy'), true);
  assert.equal(env.root.querySelectorAll('.staff-pos-kpi').length, 5);

  env.root.querySelector('#add-staff-btn').click();
  const form = env.modalDialog.querySelector('#create-staff-form');
  form.querySelector('[name="position"]').value = 'RECEPTIONIST';
  form.querySelector('[name="fullName"]').value = 'Lễ Tân Ca Tối';
  form.querySelector('[name="email"]').value = 'letan2@metagym.vn';
  form.querySelector('[name="password"]').value = 'MetaGym123!';
  form.dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(createdPayloads.length, 1);
  assert.equal(createdPayloads[0].position, 'RECEPTIONIST');

  await renderStaffPage({
    root: env.root,
    params: new URLSearchParams({ tab: 'positions', preview: 'RECEPTIONIST' }),
    shell: (opts) => renderShell({
      root: env.root,
      user: { id: 'adm-1', role: 'ADMIN', staffPosition: 'ADMIN', permissions: ['*'], fullName: 'Meta Admin', email: 'admin@metagym.vn' },
      ...opts,
    }),
  });

  assert.equal(env.root.querySelectorAll('.staff-position-card').length, 5);
  assert.ok(env.root.querySelectorAll('.staff-preview-card').length >= 3);
  assert.ok(env.root.querySelector('.media-subnav-btn[aria-selected="true"]'));
});
