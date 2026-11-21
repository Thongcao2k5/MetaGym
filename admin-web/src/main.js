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
import { esc } from './components/format.js';
import { icon } from './components/icons.js';
import { renderShell } from './components/layout.js';
import { closeModal, openModal } from './components/modal.js';
import { renderDashboardSkeleton, renderErrorState } from './components/states.js';
import { toast } from './components/toast.js';
import { playAppSplash } from './components/splash.js';
import { initTheme } from './services/theme.js';

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
  initTheme();
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
      const errMsg = error?.message || 'Không thể kết nối tới máy chủ hoặc hệ thống đang gặp sự cố.';

      if (getToken() && parsed.section === 'dashboard') {
        makeShell()({
          section: 'dashboard',
          topbarActionsHtml: `<button type="button" class="btn btn-graphite btn-sm" id="retry-load-btn">${icon('refresh', 16)} Thử lại</button>`,
          contentHtml: renderDashboardSkeleton(),
        });
        const retry = root.querySelector('#retry-load-btn');
        if (retry) retry.onclick = route;
        toast(errMsg, 'danger');
        return;
      }

      const errHtml = renderErrorState({
        title: 'Lỗi kết nối hệ thống',
        message: errMsg,
      });
      if (getToken()) {
        makeShell()({
          section: parsed.section,
          contentHtml: errHtml,
        });
      } else {
        root.innerHTML = `<div class="page-content">${errHtml}</div>`;
      }
      const retry = root.querySelector('#retry-load-btn');
      if (retry) retry.onclick = route;

      openModal({
        title: 'Lỗi kết nối hệ thống',
        maxWidth: '460px',
        bodyHtml: `<div class="system-error-modal">
          <div class="system-error-badge" aria-hidden="true">${icon('alert', 26)}</div>
          <h3 class="system-error-heading">Không thể khởi chạy trang quản trị</h3>
          <p class="system-error-message">${esc(errMsg)}</p>
          <p class="system-error-hint">Kiểm tra lại kết nối máy chủ hoặc thử tải lại dữ liệu.</p>
        </div>`,
        footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Đóng</button>
          <button type="button" class="btn btn-primary" id="system-error-retry">${icon('refresh', 16)} Thử lại kết nối</button>`,
        onMount: (modal) => {
          const modalRetry = modal.dialog.querySelector?.('#system-error-retry');
          if (modalRetry) {
            modalRetry.onclick = () => {
              modal.close();
              route();
            };
          }
        },
      });
    }
  }

  return { route, signOut };
}

if (typeof document !== 'undefined' && document.querySelector?.('#app')) {
  if (globalThis.window?.location?.pathname === '/admin' || globalThis.window?.location?.pathname === '/admin/') {
    globalThis.window.history?.replaceState?.(null, '', `/${globalThis.window.location.hash || '#/admin/dashboard'}`);
  }
  const app = createApp();
  if (getToken() && !getCurrentUser()) {
    api('/users/me')
      .then((res) => {
        if (res?.data?.role === 'ADMIN') setCurrentUser(res.data);
      })
      .catch(() => {});
  }
  playAppSplash(() => {
    globalThis.window?.addEventListener?.('hashchange', () => app.route());
    app.route();
  });
}
