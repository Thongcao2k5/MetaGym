import { api, getToken } from '../services/api.js';
import { esc, formatDateTimeVN } from './format.js';
import { icon } from './icons.js';
import { renderEmptyState } from './states.js';

const READ_STORAGE_KEY = 'metagym_admin_read_notifs_v1';
const POLL_INTERVAL_MS = 20000;

let state = {
  items: [],
  loading: false,
  loadedOnce: false,
  error: null,
  filter: 'ALL', // ALL | UNREAD | READ
  open: false,
};

let pollTimer = null;
let lastLoadedAt = 0;

function getReadSet() {
  try {
    const raw = globalThis.localStorage?.getItem?.(READ_STORAGE_KEY);
    const parsed = raw ? JSON.parse(raw) : [];
    return new Set(Array.isArray(parsed) ? parsed : []);
  } catch {
    return new Set();
  }
}

function saveReadSet(set) {
  try {
    const trimmed = Array.from(set).slice(-300);
    globalThis.localStorage?.setItem?.(READ_STORAGE_KEY, JSON.stringify(trimmed));
  } catch {
    // Ignore storage quota/access errors
  }
}

export function getNotificationSummary() {
  const readSet = getReadSet();
  const pendingCount = state.items.length;
  let readCount = 0;
  for (const item of state.items) {
    if (readSet.has(item.key)) readCount += 1;
  }
  const unreadCount = Math.max(0, pendingCount - readCount);
  return { pendingCount, readCount, unreadCount };
}

function mapIncident(row) {
  const member = row.memberName || 'Hội viên';
  const coach = row.coachName || 'Coach';
  const subtitle = row.memberChoice === 'REFUND'
    ? 'Yêu cầu hoàn mô phỏng (D3) · Chờ Admin xử lý'
    : row.memberChoice === 'WAIT'
      ? 'Chọn chờ Coach mở khóa (D1)'
      : 'Gói Coach tạm đóng băng (COACH_LOCKED)';
  return {
    key: `incident:${row.id}`,
    id: row.id,
    kind: 'INCIDENT',
    kindLabel: 'Sự cố Coach',
    title: `${member} · ${coach}`,
    subtitle,
    href: `#/admin/incidents?status=OPEN&id=${encodeURIComponent(row.id)}`,
    createdAt: row.createdAt || row.lockedAt || null,
    urgent: row.memberChoice === 'REFUND',
  };
}

function mapDispute(row) {
  const member = row.memberName || 'Hội viên';
  const coach = row.coachName || 'Coach';
  return {
    key: `termination:${row.id}`,
    id: row.id,
    kind: 'DISPUTE',
    kindLabel: 'Tranh chấp 72h',
    title: `${member} ↔ ${coach}`,
    subtitle: 'Quá hạn 72h · Cần Admin phân xử (D5)',
    href: `#/admin/relationships?tab=terminations&status=DISPUTED&id=${encodeURIComponent(row.id)}`,
    createdAt: row.disputedAt || row.createdAt || null,
    urgent: true,
  };
}

export async function refreshNotifications({ force = false } = {}) {
  if (!getToken()) return;
  const now = Date.now();
  if (!force && state.loading) return;
  if (!force && state.loadedOnce && now - lastLoadedAt < 5000) return;

  state.loading = true;
  if (!state.loadedOnce) renderNotificationCenter();

  try {
    const [incRes, termRes] = await Promise.allSettled([
      api('/admin/coach-incidents?status=OPEN&page=1&pageSize=20'),
      api('/admin/termination-requests?status=DISPUTED&page=1&pageSize=20'),
    ]);

    const incidents = incRes.status === 'fulfilled' && Array.isArray(incRes.value?.data)
      ? incRes.value.data.map(mapIncident)
      : [];
    const disputes = termRes.status === 'fulfilled' && Array.isArray(termRes.value?.data)
      ? termRes.value.data.map(mapDispute)
      : [];

    if (incRes.status === 'rejected' && termRes.status === 'rejected') {
      state.error = incRes.reason?.message || 'Không thể tải thông báo.';
    } else {
      state.error = null;
      const merged = [...incidents, ...disputes].sort((a, b) => {
        const ta = a.createdAt ? new Date(a.createdAt).getTime() : 0;
        const tb = b.createdAt ? new Date(b.createdAt).getTime() : 0;
        return tb - ta;
      });
      state.items = merged;
      state.loadedOnce = true;
      lastLoadedAt = Date.now();
    }
  } catch (err) {
    state.error = err?.message || 'Không thể tải thông báo.';
  } finally {
    state.loading = false;
    renderNotificationCenter();
  }
}

export function markNotificationRead(key) {
  if (!key) return;
  const set = getReadSet();
  set.add(key);
  saveReadSet(set);
  renderNotificationCenter();
}

export function markAllNotificationsRead() {
  const set = getReadSet();
  for (const item of state.items) set.add(item.key);
  saveReadSet(set);
  renderNotificationCenter();
}

export function stopNotificationPolling() {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
  state = {
    items: [],
    loading: false,
    loadedOnce: false,
    error: null,
    filter: 'ALL',
    open: false,
  };
  lastLoadedAt = 0;
}

function buildNotificationBodyHtml() {
  const readSet = getReadSet();
  const { pendingCount, readCount, unreadCount } = getNotificationSummary();
  const filtered = state.items.filter((item) => {
    const isRead = readSet.has(item.key);
    if (state.filter === 'UNREAD') return !isRead;
    if (state.filter === 'READ') return isRead;
    return true;
  });

  const emptyDesc = state.filter === 'UNREAD'
    ? 'Không có thông báo chưa đọc.'
    : state.filter === 'READ'
      ? 'Chưa có thông báo đã đọc nào.'
      : 'Chưa có sự cố hay tranh chấp nào cần xử lý.';

  const listHtml = state.loading && !state.loadedOnce
    ? `<div class="notif-empty">Đang tải thông báo...</div>`
    : state.error && !state.items.length
      ? `<div class="notif-empty">
          <p>${esc(state.error)}</p>
          <button type="button" class="btn btn-graphite btn-sm" data-notif-retry>Thử lại</button>
        </div>`
      : filtered.length === 0
        ? renderEmptyState({
          iconName: 'bell',
          title: 'Chưa có dữ liệu',
          description: emptyDesc,
        })
        : `<div class="notif-list">
            ${filtered.map((item) => {
          const isRead = readSet.has(item.key);
          const badgeCls = item.kind === 'DISPUTE' ? 'meta-badge-danger' : (item.urgent ? 'meta-badge-coral' : 'meta-badge-warning');
          return `<a class="notif-item ${isRead ? 'is-read' : 'is-unread'}" href="${esc(item.href)}" data-notif-key="${esc(item.key)}">
                <div class="notif-item-top">
                  <span class="meta-badge ${badgeCls}">${esc(item.kindLabel)}</span>
                  <span class="notif-item-time tabular">${esc(item.createdAt ? formatDateTimeVN(item.createdAt) : 'Mới')}</span>
                </div>
                <div class="notif-item-title">${!isRead ? '<span class="notif-unread-dot" aria-hidden="true"></span>' : ''}${esc(item.title)}</div>
                <div class="notif-item-sub">${esc(item.subtitle)}</div>
              </a>`;
        }).join('')}
          </div>`;

  return { pendingCount, readCount, unreadCount, listHtml };
}

export function getNotificationPageHtml() {
  const { pendingCount, readCount, unreadCount, listHtml } = buildNotificationBodyHtml();
  return `
    <div class="notif-page-header">
      <div class="notif-tabs notif-tabs-page" role="tablist" aria-label="Lọc thông báo">
        <button type="button" class="notif-tab ${state.filter === 'ALL' ? 'active' : ''}" data-notif-filter="ALL">Chưa xử lý (${pendingCount})</button>
        <button type="button" class="notif-tab ${state.filter === 'UNREAD' ? 'active' : ''}" data-notif-filter="UNREAD">Chưa đọc (${unreadCount})</button>
        <button type="button" class="notif-tab ${state.filter === 'READ' ? 'active' : ''}" data-notif-filter="READ">Đã đọc (${readCount})</button>
      </div>
      <button type="button" class="btn btn-ghost btn-icon notif-mark-all-icon" data-notif-mark-all aria-label="Đánh dấu đã đọc hết" title="Đánh dấu đã đọc hết"${unreadCount === 0 ? ' disabled' : ''}>
        ${icon('checkDouble', 18)}
      </button>
    </div>
    <div class="notif-page-list-wrap">${listHtml}</div>
  `;
}

export function bindNotificationPageEvents(root = globalThis.document) {
  const pageRoot = root?.querySelector?.('#notif-page-root');
  if (!pageRoot) return;

  pageRoot.querySelector?.('[data-notif-mark-all]')?.addEventListener?.('click', () => markAllNotificationsRead());
  pageRoot.querySelector?.('[data-notif-retry]')?.addEventListener?.('click', () => refreshNotifications({ force: true }));

  pageRoot.querySelectorAll?.('[data-notif-filter]')?.forEach?.((btn) => {
    btn.addEventListener?.('click', () => {
      state.filter = btn.getAttribute('data-notif-filter') || 'ALL';
      renderNotificationCenter(root);
    });
  });

  pageRoot.querySelectorAll?.('[data-notif-key]')?.forEach?.((link) => {
    link.addEventListener?.('click', () => {
      const key = link.getAttribute('data-notif-key');
      markNotificationRead(key);
    });
  });
}

export function renderNotificationCenter(root = globalThis.document) {
  const pageRoot = root?.querySelector?.('#notif-page-root');
  if (pageRoot) {
    pageRoot.innerHTML = getNotificationPageHtml();
    bindNotificationPageEvents(root);
  }

  const wrap = root?.querySelector?.('#admin-notif-wrap');
  if (!wrap) return;

  const badgeEl = wrap.querySelector?.('#admin-bell-badge');
  const bellBtn = wrap.querySelector?.('#admin-bell-btn');
  const popover = wrap.querySelector?.('#admin-notif-popover');
  const { pendingCount, readCount, unreadCount, listHtml } = buildNotificationBodyHtml();

  if (badgeEl) {
    const countToShow = unreadCount > 0 ? unreadCount : 0;
    badgeEl.textContent = countToShow > 99 ? '99+' : String(countToShow);
    badgeEl.hidden = countToShow === 0;
  }
  if (bellBtn) {
    bellBtn.setAttribute?.('aria-expanded', String(state.open));
    const titleText = pendingCount > 0
      ? `Thông báo (${unreadCount} chưa đọc / ${pendingCount} chưa xử lý)`
      : 'Thông báo';
    bellBtn.setAttribute?.('title', titleText);
    bellBtn.setAttribute?.('aria-label', titleText);
  }
  if (!popover) return;
  popover.hidden = !state.open;
  if (!state.open) return;

  popover.innerHTML = `
    <div class="notif-head">
      <div class="notif-head-title">Thông báo</div>
      <div class="notif-head-actions">
        ${unreadCount > 0 ? `<button type="button" class="btn btn-ghost btn-icon notif-mark-all-icon" id="notif-mark-all" aria-label="Đánh dấu đã đọc hết" title="Đánh dấu đã đọc hết">${icon('checkDouble', 16)}</button>` : ''}
        <button type="button" class="btn btn-ghost btn-icon" id="notif-refresh-btn" aria-label="Làm mới thông báo" title="Làm mới">${icon('refresh', 15)}</button>
      </div>
    </div>
    <div class="notif-tabs" role="tablist" aria-label="Lọc thông báo">
      <button type="button" class="notif-tab ${state.filter === 'ALL' ? 'active' : ''}" data-notif-filter="ALL">Chưa xử lý (${pendingCount})</button>
      <button type="button" class="notif-tab ${state.filter === 'UNREAD' ? 'active' : ''}" data-notif-filter="UNREAD">Chưa đọc (${unreadCount})</button>
      <button type="button" class="notif-tab ${state.filter === 'READ' ? 'active' : ''}" data-notif-filter="READ">Đã đọc (${readCount})</button>
    </div>
    ${listHtml}
    <div class="notif-foot">
      <a class="notif-foot-link" href="#/admin/notification" id="notif-view-all">Xem tất cả thông báo</a>
    </div>
  `;

  popover.querySelector?.('#notif-mark-all')?.addEventListener?.('click', () => markAllNotificationsRead());
  popover.querySelector?.('#notif-refresh-btn')?.addEventListener?.('click', () => refreshNotifications({ force: true }));
  popover.querySelector?.('[data-notif-retry]')?.addEventListener?.('click', () => refreshNotifications({ force: true }));
  popover.querySelector?.('#notif-view-all')?.addEventListener?.('click', () => {
    state.open = false;
    renderNotificationCenter();
  });

  popover.querySelectorAll?.('[data-notif-filter]')?.forEach?.((btn) => {
    btn.addEventListener?.('click', () => {
      state.filter = btn.getAttribute('data-notif-filter') || 'ALL';
      renderNotificationCenter();
    });
  });

  popover.querySelectorAll?.('[data-notif-key]')?.forEach?.((link) => {
    link.addEventListener?.('click', () => {
      const key = link.getAttribute('data-notif-key');
      state.open = false;
      markNotificationRead(key);
    });
  });
}

function isMobileViewport() {
  if (typeof globalThis.window === 'undefined') return false;
  if (typeof globalThis.window.matchMedia === 'function') {
    return globalThis.window.matchMedia('(max-width: 767px)').matches;
  }
  return Number(globalThis.window.innerWidth || 0) <= 767;
}

export function bindNotificationBell(root = globalThis.document) {
  const wrap = root?.querySelector?.('#admin-notif-wrap');
  const bellBtn = wrap?.querySelector?.('#admin-bell-btn');
  if (!wrap || !bellBtn) return;

  bellBtn.onclick = (event) => {
    event?.stopPropagation?.();
    if (isMobileViewport()) {
      state.open = false;
      renderNotificationCenter(root);
      if (globalThis.location) {
        globalThis.location.hash = '#/admin/notification';
      }
      return;
    }
    state.open = !state.open;
    renderNotificationCenter(root);
    if (state.open) refreshNotifications({ force: true });
  };

  renderNotificationCenter(root);

  if (globalThis.document?.addEventListener) {
    if (globalThis.__metaNotifOutsideHandler) {
      globalThis.document.removeEventListener('click', globalThis.__metaNotifOutsideHandler);
    }
    globalThis.__metaNotifOutsideHandler = (event) => {
      if (!state.open) return;
      const currentWrap = globalThis.document?.querySelector?.('#admin-notif-wrap');
      if (currentWrap && !currentWrap.contains?.(event.target)) {
        state.open = false;
        renderNotificationCenter();
      }
    };
    globalThis.document.addEventListener('click', globalThis.__metaNotifOutsideHandler);
  }

  // Only start background polling in real browser runtime (not unit test DOM harness)
  if (!pollTimer && typeof globalThis.document?.hidden === 'boolean' && getToken()) {
    refreshNotifications();
    pollTimer = setInterval(() => {
      if (!globalThis.document?.hidden && getToken()) {
        refreshNotifications({ force: true });
      }
    }, POLL_INTERVAL_MS);
    pollTimer?.unref?.();
  }
}
