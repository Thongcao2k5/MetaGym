import 'bootstrap/dist/css/bootstrap.min.css';
import 'bootstrap/dist/js/bootstrap.bundle.min.js';
import Chart from 'chart.js/auto';
import QRCode from 'qrcode';
import './style.css';

import {
  api,
  clearSession,
  configureApi,
  getCurrentUser,
  getToken,
  saveReturnUrl,
  setCurrentUser,
} from './services/api.js';
import { parseHash } from './state/router.js';
import { closeDrawer } from './components/drawer.js';
import { renderShell } from './components/layout.js';
import { closeModal } from './components/modal.js';
import { renderErrorState } from './components/states.js';

import { renderLoginPage } from './pages/login.js';
import { destroyDashboardChart, renderDashboardPage } from './pages/dashboard.js';
import { renderAccountsPage } from './pages/accounts.js';
import { renderPlansPage } from './pages/plans.js';
import { renderCoachPackagesPage } from './pages/coach-packages.js';
import { renderPaymentsPage } from './pages/payments.js';
import { renderIncidentsPage } from './pages/incidents.js';
import { renderRelationshipsPage } from './pages/relationships.js';
import { renderTerminationsPage } from './pages/terminations.js';
import { renderNutritionFoodsPage } from './pages/nutrition-foods.js';
import { renderGymPage } from './pages/gym.js';
import { renderEquipmentPage } from './pages/equipment.js';
import { renderAuditLogsPage } from './pages/audit-logs.js';
import { renderProfilePage } from './pages/profile.js';

export function createApp({
  root = document.querySelector('#app'),
  ChartCtor = Chart,
  QRCodeLib = QRCode,
} = {}) {
  let routingId = 0;

  function signOut({ expired = false, returnHash = null } = {}) {
    destroyDashboardChart();
    closeModal();
    closeDrawer();
    clearSession({ expired, returnHash });
    if (globalThis.location) {
      globalThis.location.hash = '#/admin/login';
    }
    return route();
  }

  configureApi({
    onUnauthorized: (returnHash) => {
      destroyDashboardChart();
      closeModal();
      closeDrawer();
      if (globalThis.location) {
        globalThis.location.hash = '#/admin/login';
      }
      renderLoginPage({
        root,
        params: new URLSearchParams({ expired: '1', ...(returnHash ? { returnUrl: returnHash } : {}) }),
        onLoginSuccess: async (targetHash) => {
          if (globalThis.location) globalThis.location.hash = targetHash;
          await route();
        },
      });
    },
  });

  function makeShell() {
    return (opts) => renderShell({
      root,
      user: getCurrentUser(),
      onSignOut: () => signOut({ expired: false }),
      ...opts,
    });
  }

  async function route() {
    const currentId = ++routingId;
    const parsed = parseHash(globalThis.location?.hash || '');

    if (!getToken() || parsed.section === 'login') {
      if (!getToken() && parsed.section !== 'login') {
        saveReturnUrl(parsed.raw);
      }
      destroyDashboardChart();
      closeModal();
      closeDrawer();
      renderLoginPage({
        root,
        params: parsed.params,
        onLoginSuccess: async (targetHash) => {
          if (globalThis.location) globalThis.location.hash = targetHash;
          await route();
        },
      });
      return;
    }

    try {
      if (!getCurrentUser()) {
        const res = await api('/users/me');
        if (currentId !== routingId) return;
        if (res?.data?.role !== 'ADMIN') {
          await signOut({ expired: false });
          return;
        }
        setCurrentUser(res.data);
      }

      destroyDashboardChart();
      const shell = makeShell();
      const ctx = { root, params: parsed.params, shell, ChartCtor, QRCodeLib, onSignOut: () => signOut({ expired: false }) };

      const roleFromAccounts = (parsed.params.get('role') || 'COACH').toUpperCase() === 'MEMBER' ? 'MEMBER' : 'COACH';
      const pages = {
        dashboard: () => renderDashboardPage(ctx),
        'coach-incidents': () => renderIncidentsPage(ctx),
        members: () => renderAccountsPage({ ...ctx, role: 'MEMBER' }),
        coaches: () => renderAccountsPage({ ...ctx, role: 'COACH' }),
        accounts: () => renderAccountsPage({ ...ctx, role: roleFromAccounts }),
        plans: () => renderPlansPage(ctx),
        'coach-packages': () => renderCoachPackagesPage(ctx),
        payments: () => renderPaymentsPage(ctx),
        relationships: () => renderRelationshipsPage(ctx),
        terminations: () => renderTerminationsPage(ctx),
        'nutrition-foods': () => renderNutritionFoodsPage(ctx),
        gym: () => renderGymPage(ctx),
        equipment: () => renderEquipmentPage(ctx),
        'audit-logs': () => renderAuditLogsPage(ctx),
        profile: () => renderProfilePage(ctx),
      };

      const handler = pages[parsed.section];
      if (!handler) {
        if (globalThis.location) globalThis.location.hash = '#/admin/dashboard';
        await renderDashboardPage(ctx);
        return;
      }

      await handler();
    } catch (error) {
      if (currentId !== routingId) return;
      if (error?.status === 401) return;
      root.innerHTML = `<div class="page-content">${renderErrorState({ title: 'Không thể khởi chạy trang quản trị', message: error?.message || 'Lỗi kết nối máy chủ.' })}</div>`;
      const retry = root.querySelector('#retry-load-btn');
      if (retry) retry.onclick = route;
    }
  }

  return { route, signOut };
}

if (typeof document !== 'undefined' && document.querySelector?.('#app')) {
  const app = createApp();
  globalThis.window?.addEventListener?.('hashchange', () => app.route());
  app.route();
}
