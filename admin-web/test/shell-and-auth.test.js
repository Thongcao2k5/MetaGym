import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { createDomEnvironment, flush, jsonResponse } from './helpers/dom-harness.js';
import { api, clearSession, setCurrentUser, setToken } from '../src/services/api.js';
import { buildHash, parseHash } from '../src/state/router.js';
import { renderShell } from '../src/components/layout.js';
import { closeModal, openConfirmModal } from '../src/components/modal.js';
import { closeDrawer, openDrawer } from '../src/components/drawer.js';
import { renderLoginPage } from '../src/pages/login.js';
import { renderDashboardPage } from '../src/pages/dashboard.js';
import { renderAuditLogsPage } from '../src/pages/audit-logs.js';

function collectJsFiles(dir) {
  const files = [];
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) files.push(...collectJsFiles(full));
    else if (full.endsWith('.js')) files.push(full);
  }
  return files;
}

test('T8 Static Gate: ZERO native confirm()/prompt()/alert() and ZERO backdrop-filter blur on data surfaces', () => {
  const srcDir = fileURLToPath(new URL('../src', import.meta.url));
  const jsFiles = collectJsFiles(srcDir);
  assert.ok(jsFiles.length >= 12, 'Modular ESM architecture should split src into >= 12 files');

  for (const file of jsFiles) {
    const raw = readFileSync(file, 'utf8');
    const codeOnly = raw.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
    assert.equal(/\b(?:window\.)?(?:confirm|prompt|alert)\s*\(/.test(codeOnly), false, `Forbidden native dialog in ${file}`);
  }

  const css = readFileSync(new URL('../src/style.css', import.meta.url), 'utf8');
  assert.equal(/backdrop-filter\s*:\s*blur/i.test(css), false, 'style.css must not use backdrop-filter blur on Admin surfaces');
  assert.equal(css.includes('#0F1115'), true, 'Must include Dark Graphite canvas #0F1115');
  assert.equal(css.includes('#181B22'), true, 'Must include Solid Card #181B22');
  assert.equal(css.includes('#FF5E36'), true, 'Must include Coral Orange #FF5E36');
  assert.equal(css.includes('Be Vietnam Pro'), true, 'Must use Be Vietnam Pro font');
  assert.equal(css.includes('tabular-nums'), true, 'Must include tabular-nums');
  assert.equal(css.includes('@media print'), true, 'Must preserve @media print for Counter QR');

  const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
  assert.equal(html.includes('data-bs-theme="dark"'), true, 'index.html must default to Dark Graphite Operate Mode');
  assert.equal(html.includes('Be+Vietnam+Pro'), true, 'index.html must load Be Vietnam Pro');
});

test('T8 Router preserves query params and resolves route aliases cleanly', () => {
  const parsed = parseHash('#/admin/gym-plans?tab=entitlements&status=ACTIVE&page=2');
  assert.equal(parsed.section, 'plans');
  assert.equal(parsed.params.get('tab'), 'entitlements');
  assert.equal(parsed.params.get('status'), 'ACTIVE');
  assert.equal(parsed.params.get('page'), '2');

  const rebuilt = buildHash('accounts', { role: 'COACH', status: 'ACTIVE', search: 'Nam', page: 2 });
  assert.equal(rebuilt, '#/admin/accounts?role=COACH&status=ACTIVE&search=Nam&page=2');
});

test('T8 401 session expired preserves returnUrl in sessionStorage and re-login navigates back', async () => {
  const env = createDomEnvironment({
    hash: '#/admin/payments?status=SUCCESS&page=2',
    token: 'expired-token',
  });
  let unauthorizedReturn = null;
  const { configureApi } = await import('../src/services/api.js');
  configureApi({ onUnauthorized: (hash) => { unauthorizedReturn = hash; } });

  globalThis.fetch = async (url, options = {}) => {
    const path = new URL(url, 'http://localhost').pathname;
    if (path === '/api/v1/admin/payments') {
      return jsonResponse({ error: { code: 'UNAUTHORIZED', message: 'Phiên hết hạn' } }, 401);
    }
    if (path === '/api/v1/auth/sessions' && options.method === 'POST') {
      return jsonResponse({
        data: {
          accessToken: 'fresh-token',
          user: { id: 'adm-1', role: 'ADMIN', fullName: 'Admin One', email: 'admin@metagym.vn' },
        },
      });
    }
    throw new Error(`Unexpected ${path}`);
  };

  await assert.rejects(() => api('/admin/payments'), (err) => err.status === 401 && err.code === 'UNAUTHORIZED');
  assert.equal(unauthorizedReturn, '#/admin/payments?status=SUCCESS&page=2');
  assert.equal(env.sessionStorage.getItem('metagym_admin_return_url'), '#/admin/payments?status=SUCCESS&page=2');
  assert.equal(env.sessionStorage.getItem('metagym_admin_session_expired'), '1');

  let navigatedTarget = null;
  renderLoginPage({
    root: env.root,
    params: new URLSearchParams(),
    onLoginSuccess: async (target) => { navigatedTarget = target; },
  });

  assert.equal(env.root.innerHTML.includes('Phiên đăng nhập đã hết hạn'), true);
  assert.equal(env.root.innerHTML.includes('#/admin/payments?status=SUCCESS&amp;page=2'), true);

  env.root.querySelector('#login-email').value = 'admin@metagym.vn';
  env.root.querySelector('#login-password').value = 'Admin123!';
  env.root.querySelector('#login').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(navigatedTarget, '#/admin/payments?status=SUCCESS&page=2');
  assert.equal(env.sessionStorage.getItem('metagym_admin_token'), 'fresh-token');
  clearSession();
});

test('T8 Login preserves email on 401 error and rejects non-ADMIN accounts', async () => {
  const env = createDomEnvironment({ hash: '#/admin/login', token: null });
  clearSession();

  globalThis.fetch = async () => jsonResponse({
    error: { code: 'INVALID_CREDENTIALS', message: 'Sai email hoặc mật khẩu' },
  }, 401);

  renderLoginPage({ root: env.root, params: new URLSearchParams(), onLoginSuccess: async () => {} });
  env.root.querySelector('#login-email').value = 'admin@metagym.vn';
  env.root.querySelector('#login-password').value = 'wrong';
  env.root.querySelector('#login').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(env.root.querySelector('#login-email').value, 'admin@metagym.vn', 'Email must be preserved on error');
  assert.equal(env.root.innerHTML.includes('Sai email hoặc mật khẩu'), true);
});

test('T8 Dashboard & Shell contain ZERO legacy PENDING Coach Request KPI and deep-link to real queues', async () => {
  const env = createDomEnvironment({ hash: '#/admin/dashboard', token: 'tok' });
  setToken('tok');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Meta Admin', email: 'admin@metagym.vn' });

  globalThis.fetch = async (url) => {
    const path = new URL(url, 'http://localhost').pathname;
    if (path === '/api/v1/admin/dashboard') {
      return jsonResponse({
        data: {
          from: '2026-10-23',
          to: '2026-11-21',
          timezone: 'Asia/Ho_Chi_Minh',
          members: { active: 142, disabled: 5 },
          coaches: { active: 8, disabled: 1 },
          activeMemberships: 96,
          activeCoachRelationships: 38,
          pausedCoachRelationships: { total: 3, membershipExpired: 1, coachLocked: 2, memberLocked: 0 },
          actionQueue: { coachLockedWaitingCount: 2, coachLockedRefundRequestedCount: 1, disputedTerminationCount: 1 },
          revenue: {
            grossRevenue: 45000000,
            totalSimulatedRefunds: 3783000,
            netRevenue: 41217000,
            byDay: [{ day: '2026-11-21', grossRevenue: 5000000, simulatedRefunds: 0, netRevenue: 5000000 }],
          },
        },
      });
    }
    throw new Error(`Unexpected ${path}`);
  };

  await renderDashboardPage({
    root: env.root,
    params: new URLSearchParams(),
    shell: (opts) => renderShell({ root: env.root, user: { fullName: 'Meta Admin', email: 'admin@metagym.vn' }, ...opts }),
    ChartCtor: class { destroy() {} },
  });

  const html = env.root.innerHTML;
  assert.equal(html.includes('Yêu cầu chọn Coach'), false);
  assert.equal(html.includes('pendingCoachRequests'), false);
  assert.equal(html.includes('Tổng thu'), true);
  assert.equal(html.includes('Tiền đã hoàn'), true);
  assert.equal(html.includes('Doanh thu thực nhận'), true);
  assert.equal(html.includes('Hội viên hoạt động'), true);
  assert.equal(html.includes('Gói Gym đang sử dụng'), true);
  assert.equal(html.includes('Đang tập cùng Coach'), false);
  assert.equal(html.includes('Chờ xử lý sự cố Coach'), false);
  assert.equal(html.includes('Tranh chấp cần phân xử'), false);
});

test('T8 Custom modal preserves entered reason on API error and Escape closes modal/drawer', async () => {
  const env = createDomEnvironment();
  let calls = 0;

  openConfirmModal({
    title: 'Xác nhận thao tác rủi ro cao',
    requireReason: true,
    onConfirm: async () => {
      calls += 1;
      throw new Error('Lỗi xung đột 409');
    },
  });

  const textarea = env.modalDialog.querySelector('#meta-confirm-reason');
  const submit = env.modalDialog.querySelector('#meta-confirm-submit');
  assert.equal(submit.disabled, true);

  textarea.value = 'Lý do quan trọng cần giữ lại';
  textarea.dispatchEvent({ type: 'input' });
  assert.equal(submit.disabled, false);

  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(calls, 1);
  assert.equal(env.modalOverlay.hidden, false, 'Modal remains open on error');
  assert.equal(textarea.value, 'Lý do quan trọng cần giữ lại', 'Input text preserved on error');
  assert.equal(env.modalDialog.innerHTML.includes('Lỗi xung đột 409'), true);

  env.document.dispatchEvent({ type: 'keydown', key: 'Escape' });
  assert.equal(env.modalOverlay.hidden, true, 'Escape closes modal');

  openDrawer({ title: 'Drawer Test', bodyHtml: '<p>Chi tiết kỹ thuật</p>' });
  assert.equal(env.drawerOverlay.hidden, false);
  env.document.dispatchEvent({ type: 'keydown', key: 'Escape' });
  assert.equal(env.drawerOverlay.hidden, true, 'Escape closes drawer');

  closeModal();
  closeDrawer();
});

test('T8 Audit Logs page loads GET /admin/audit-logs and displays technical UUID only in Detail Drawer', async () => {
  const env = createDomEnvironment({ hash: '#/admin/audit-logs', token: 'tok' });
  setToken('tok');

  globalThis.fetch = async (url) => {
    const parsed = new URL(url, 'http://localhost');
    if (parsed.pathname === '/api/v1/admin/audit-logs') {
      return jsonResponse({
        data: [{
          id: 'aud-uuid-9999',
          adminId: 'adm-1',
          adminName: 'Meta Gym Admin',
          action: 'PAYMENT_VOID_REVERSED',
          entityType: 'PAYMENT',
          entityId: 'pay-uuid-8888',
          summary: 'Đảo giao dịch tại quầy MG-001',
          metadata: { reason: 'Nhập nhầm gói' },
          createdAt: '2026-11-21T07:10:00.000Z',
        }],
        pagination: { page: 1, pageSize: 20, totalItems: 1, totalPages: 1 },
      });
    }
    throw new Error(`Unexpected ${parsed.pathname}`);
  };

  await renderAuditLogsPage({
    root: env.root,
    params: new URLSearchParams(),
    shell: (opts) => renderShell({ root: env.root, user: { fullName: 'Meta Gym Admin' }, ...opts }),
  });

  const tableHtml = env.root.querySelector('table')?.innerHTML || '';
  assert.equal(tableHtml.includes('Meta Gym Admin'), true);
  assert.equal(tableHtml.includes('PAYMENT_VOID_REVERSED'), true);
  assert.equal(tableHtml.includes('pay-uuid-8888'), false, 'List table must not show raw target UUID');

  env.root.querySelector('.view-audit').click();
  assert.equal(env.drawerOverlay.hidden, false);
  assert.equal(env.drawerPanel.innerHTML.includes('aud-uuid-9999'), true);
  assert.equal(env.drawerPanel.innerHTML.includes('pay-uuid-8888'), true);
  assert.equal(env.drawerPanel.innerHTML.includes('Nhập nhầm gói'), true);
});

test('Dashboard supports 7/30/60/90 quick ranges and period comparison with card trend percentages', async () => {
  const env = createDomEnvironment({ hash: '#/admin/dashboard', token: 'tok' });
  setToken('tok');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Meta Admin', email: 'admin@metagym.vn' });

  const requestedUrls = [];
  const baseDashboardData = {
    from: '2026-10-24',
    to: '2026-11-22',
    timezone: 'Asia/Ho_Chi_Minh',
    members: { active: 120, disabled: 4 },
    coaches: { active: 10, disabled: 1 },
    activeMemberships: 90,
    activeCoachRelationships: 30,
    pausedCoachRelationships: { total: 2, membershipExpired: 1, coachLocked: 1, memberLocked: 0 },
    actionQueue: { coachLockedWaitingCount: 1, coachLockedRefundRequestedCount: 0, disputedTerminationCount: 2 },
    revenue: {
      grossRevenue: 20000000,
      totalSimulatedRefunds: 1000000,
      netRevenue: 19000000,
      byDay: [{ day: '2026-11-22', grossRevenue: 5000000, simulatedRefunds: 0, netRevenue: 5000000 }],
    },
  };

  globalThis.fetch = async (url) => {
    const parsed = new URL(url, 'http://localhost');
    requestedUrls.push(parsed.pathname + parsed.search);
    if (parsed.pathname === '/api/v1/admin/dashboard') {
      return jsonResponse({ data: baseDashboardData });
    }
    if (parsed.pathname === '/api/v1/admin/dashboard/compare') {
      return jsonResponse({
        data: {
          current: { from: '2026-10-24', to: '2026-11-22', dashboard: baseDashboardData },
          previous: { from: '2026-09-24', to: '2026-10-23' },
          comparison: {
            grossRevenue: { current: 20000000, previous: 15000000, delta: 5000000, percentChange: 33.3, direction: 'up' },
            totalSimulatedRefunds: { current: 1000000, previous: 2000000, delta: -1000000, percentChange: -50, direction: 'down' },
            netRevenue: { current: 19000000, previous: 13000000, delta: 6000000, percentChange: 46.2, direction: 'up' },
            membersActive: { current: 120, previous: 100, delta: 20, percentChange: 20, direction: 'up' },
            coachesActive: { current: 10, previous: 8, delta: 2, percentChange: 25, direction: 'up' },
            activeMemberships: { current: 90, previous: 75, delta: 15, percentChange: 20, direction: 'up' },
            activeCoachRelationships: { current: 30, previous: 30, delta: 0, percentChange: 0, direction: 'flat' },
            coachLockedWaiting: { current: 1, previous: 2, delta: -1, percentChange: -50, direction: 'down' },
            disputedTerminations: { current: 2, previous: 1, delta: 1, percentChange: 100, direction: 'up' },
          },
        },
      });
    }
    throw new Error(`Unexpected ${parsed.pathname}`);
  };

  const shell = (opts) => renderShell({ root: env.root, user: { fullName: 'Meta Admin', email: 'admin@metagym.vn' }, ...opts });

  await renderDashboardPage({
    root: env.root,
    params: new URLSearchParams({ from: '2026-10-24', to: '2026-11-22' }),
    shell,
    ChartCtor: class { destroy() {} },
  });

  assert.equal(env.root.innerHTML.includes('60 ngày'), true);
  assert.equal(env.root.innerHTML.includes('90 ngày'), true);
  const compareBtn = env.root.querySelector('#dash-compare-btn');
  assert.ok(compareBtn);
  assert.equal(compareBtn.getAttribute('aria-pressed'), 'false');

  compareBtn.click();
  await flush();

  assert.equal(
    requestedUrls.some((u) => u.startsWith('/api/v1/admin/dashboard/compare?') && u.includes('compareFrom=2026-09-24') && u.includes('compareTo=2026-10-23')),
    true,
  );
  assert.equal(env.root.querySelector('#dash-compare-btn').getAttribute('aria-pressed'), 'true');
  assert.equal(env.root.innerHTML.includes('Tăng 33.3%'), true);
  assert.equal(env.root.innerHTML.includes('Giảm 50%'), true);
  assert.equal(env.root.innerHTML.includes('Tăng 46.2%'), true);
  assert.equal(env.root.innerHTML.includes('Tăng 20%'), true);

  const trends = env.root.querySelectorAll('.kpi-trend');
  assert.equal(trends.length, 6);
  assert.equal(trends[0].classList.contains('is-positive'), true, 'Gross revenue up is positive');
  assert.equal(trends[1].classList.contains('is-positive'), true, 'Refunds down is positive');
  assert.equal(trends[3].classList.contains('is-positive'), true, 'Members active up is positive');

  env.root.querySelector('#dash-compare-btn').click();
  await flush();
  assert.equal(env.root.querySelectorAll('.kpi-trend').length, 0);
});
