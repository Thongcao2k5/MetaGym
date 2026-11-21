import { esc, initials } from './format.js';
import { icon } from './icons.js';
import { getTheme, toggleTheme } from '../services/theme.js';

export const NAV_GROUPS = [
  {
    label: 'Vận hành',
    items: [
      { id: 'dashboard', href: '#/admin/dashboard', label: 'Tổng quan', icon: 'dashboard' },
      { id: 'coach-incidents', href: '#/admin/incidents', label: 'Sự cố Coach', icon: 'alert', badgeKey: 'incidents' },
    ],
  },
  {
    label: 'Khách hàng & Quan hệ',
    items: [
      { id: 'members', href: '#/admin/members', label: 'Hội viên (Member)', icon: 'users' },
      { id: 'coaches', href: '#/admin/coaches', label: 'Huấn luyện viên (Coach)', icon: 'award' },
      { id: 'relationships', href: '#/admin/relationships', label: 'Quan hệ & Kết thúc sớm', icon: 'link', badgeKey: 'disputes' },
    ],
  },
  {
    label: 'Gói dịch vụ & Tiền',
    items: [
      { id: 'plans', href: '#/admin/plans', label: 'Gói Gym & Quyền sử dụng', icon: 'card' },
      { id: 'coach-packages', href: '#/admin/coach-packages', label: 'Gói Coach & Quyền lợi', icon: 'dumbbell' },
      { id: 'payments', href: '#/admin/payments', label: 'Giao dịch quầy & Lịch sử', icon: 'receipt' },
    ],
  },
  {
    label: 'Nội dung vận hành',
    items: [
      { id: 'nutrition-foods', href: '#/admin/foods', label: 'Thực phẩm & kcal', icon: 'food' },
      { id: 'gym', href: '#/admin/gym', label: 'Phòng gym & QR điểm danh', icon: 'building' },
      { id: 'equipment', href: '#/admin/equipment', label: 'Thiết bị & Bài tập', icon: 'dumbbell' },
    ],
  },
  {
    label: 'Kiểm soát',
    items: [
      { id: 'audit-logs', href: '#/admin/audit-logs', label: 'Nhật ký hệ thống', icon: 'audit' },
    ],
  },
];

export const PAGE_META = {
  dashboard: {
    title: 'Tổng quan vận hành',
    subtitle: 'Doanh thu gộp/hoàn/ròng, ngoại lệ COACH_LOCKED và tranh chấp kết thúc sớm (GMT+7).',
  },
  'coach-incidents': {
    title: 'Sự cố Coach (COACH_LOCKED)',
    subtitle: 'Theo dõi hội viên đóng băng gói Coach: chờ mở khóa (D1), chuyển Coach (D2) hoặc hoàn mô phỏng (D3).',
  },
  members: {
    title: 'Quản lý Hội viên (Member)',
    subtitle: 'Tìm kiếm server-side, hồ sơ vận hành (không lộ dữ liệu riêng tư) và khóa/mở theo quy tắc D4.',
  },
  coaches: {
    title: 'Quản lý Huấn luyện viên (Coach)',
    subtitle: 'Trần suất cứng 8 hội viên/Coach, cấp mật khẩu tạm 1 lần và khóa/mở theo quy tắc D1.',
  },
  accounts: {
    title: 'Quản lý Tài khoản',
    subtitle: 'Hội viên & Huấn luyện viên — trần cứng 8 suất và khóa/mở có xem trước tác động.',
  },
  relationships: {
    title: 'Quan hệ & Kết thúc sớm',
    subtitle: 'Phân biệt lý do tạm ngưng, phân xử tranh chấp 72h (D5) và lịch sử chuyển Coach.',
  },
  terminations: {
    title: 'Kết thúc sớm & Tranh chấp (D5)',
    subtitle: 'Hàng chờ yêu cầu kết thúc sớm và tranh chấp quá 72 giờ cần Admin phân xử.',
  },
  plans: {
    title: 'Gói Gym & Quyền sử dụng',
    subtitle: 'Chỉnh sửa giá/số ngày trực tiếp cho giao dịch mới; gói đã mua giữ nguyên snapshot.',
  },
  'coach-packages': {
    title: 'Gói Coach & Quyền lợi',
    subtitle: 'Danh mục Full CRUD không giới hạn 3 mã; theo dõi quyền lợi ACTIVE / QUEUED / ENDED.',
  },
  payments: {
    title: 'Giao dịch tại quầy & Lịch sử',
    subtitle: 'Thu tiền gói Gym tại quầy có Idempotency-Key và điều chỉnh VOID_REVERSAL (D6).',
  },
  'nutrition-foods': {
    title: 'Danh mục Thực phẩm & kcal',
    subtitle: 'Quản lý chỉ số kcal/100g phục vụ thực đơn 7 ngày của Coach.',
  },
  gym: {
    title: 'Hồ sơ Phòng gym & QR điểm danh',
    subtitle: 'Cập nhật thông tin công khai và in/đổi mã QR điểm danh tại quầy.',
  },
  equipment: {
    title: 'Thiết bị & Thư viện Bài tập',
    subtitle: 'Quản lý thiết bị phòng tập, hướng dẫn an toàn và danh mục bài tập (exercises).',
  },
  'audit-logs': {
    title: 'Nhật ký Hệ thống (Audit Log)',
    subtitle: 'Truy vết thao tác quản trị với metadata đã qua bộ lọc an toàn quyền riêng tư.',
  },
  profile: {
    title: 'Hồ sơ Quản trị viên',
    subtitle: 'Thông tin tài khoản Admin hiện hành và đổi mật khẩu (tự động thu hồi phiên cũ).',
  },
};

const SIDEBAR_COLLAPSE_KEY = 'meta-admin-sidebar-collapsed';

function isSidebarCollapsed() {
  try {
    return typeof window !== 'undefined' && window.localStorage?.getItem?.(SIDEBAR_COLLAPSE_KEY) === '1';
  } catch {
    return false;
  }
}

function setSidebarCollapsedStorage(collapsed) {
  try {
    if (typeof window !== 'undefined') {
      if (collapsed) window.localStorage?.setItem?.(SIDEBAR_COLLAPSE_KEY, '1');
      else window.localStorage?.removeItem?.(SIDEBAR_COLLAPSE_KEY);
    }
  } catch {
    // Ignore storage errors
  }
}

export function renderShell({
  root,
  section,
  user,
  contentHtml,
  title,
  subtitle,
  topbarActionsHtml = '',
  badges = {},
  onSignOut,
}) {
  const activeKey = section === 'terminations' ? 'relationships'
    : section === 'accounts' ? 'coaches' : section;
  const meta = PAGE_META[section] || { title: section, subtitle: '' };
  const resolvedTitle = title || meta.title;
  const resolvedSub = subtitle !== undefined ? subtitle : meta.subtitle;

  const navHtml = NAV_GROUPS.map((group) => `
    <div>
      <div class="nav-group-label">${esc(group.label)}</div>
      <div class="nav-list">
        ${group.items.map((item) => {
          const isCurrent = item.id === activeKey;
          const badgeVal = item.badgeKey ? Number(badges[item.badgeKey] || 0) : 0;
          const badgeCls = item.badgeKey === 'disputes' ? 'danger' : 'warn';
          return `<a class="meta-nav-item ${isCurrent ? 'active' : ''}" href="${item.href}" title="${esc(item.label)}" ${isCurrent ? 'aria-current="page"' : ''}>
            ${icon(item.icon, 17)}
            <span class="nav-item-label">${esc(item.label)}</span>
            ${badgeVal > 0 ? `<span class="nav-count ${badgeCls}">${badgeVal}</span>` : ''}
          </a>`;
        }).join('')}
      </div>
    </div>
  `).join('');

  const currentTheme = getTheme();
  const nextThemeLabel = currentTheme === 'dark' ? 'Chuyển sang giao diện sáng' : 'Chuyển sang giao diện tối';
  const themeBtnHtml = `<button type="button" class="btn btn-ghost btn-icon" id="theme-toggle-btn" aria-label="${nextThemeLabel}" title="${nextThemeLabel}">
    ${icon(currentTheme === 'dark' ? 'sun' : 'moon', 18)}
  </button>`;
  const accountHtml = `<div class="topbar-account">
    ${themeBtnHtml}
    <a class="admin-user-link topbar-user-link" href="#/admin/profile" ${section === 'profile' ? 'aria-current="page"' : ''} title="Hồ sơ quản trị viên">
      <span class="meta-avatar">${esc(initials(user?.fullName || 'Admin'))}</span>
      <span class="admin-user-meta">
        <span class="admin-user-name">${esc(user?.fullName || 'Quản trị viên')}</span>
        <span class="admin-user-role">${esc(user?.email || 'ADMIN')}</span>
      </span>
    </a>
    <button type="button" class="btn btn-ghost btn-sm" id="logout" aria-label="Đăng xuất">
      ${icon('logout', 16)} <span class="logout-label">Đăng xuất</span>
    </button>
  </div>`;

  const existingShell = root.querySelector?.('.admin-shell');
  const existingMain = existingShell ? root.querySelector?.('#main-content') : null;
  const existingNav = existingShell ? root.querySelector?.('.sidebar-nav') : null;

  if (existingShell && existingMain && existingNav) {
    const prevScroll = existingNav.scrollTop || 0;
    existingNav.innerHTML = navHtml;
    existingNav.scrollTop = prevScroll;

    const headingEl = root.querySelector?.('.page-heading');
    if (headingEl) headingEl.textContent = resolvedTitle;

    const titleWrap = headingEl?.parentElement;
    let subEl = root.querySelector?.('.page-subtitle');
    if (resolvedSub) {
      if (!subEl && titleWrap && document.createElement) {
        subEl = document.createElement('p');
        subEl.className = 'page-subtitle';
        titleWrap.appendChild(subEl);
      }
      if (subEl) subEl.textContent = resolvedSub;
    } else if (subEl) {
      subEl.textContent = '';
    }

    const actionsEl = root.querySelector?.('.topbar-actions');
    if (actionsEl) actionsEl.innerHTML = `${topbarActionsHtml}${accountHtml}`;

    existingMain.innerHTML = `<div id="notice" aria-live="polite"></div>${contentHtml}`;
  } else {
    const collapsed = isSidebarCollapsed();
    root.innerHTML = `<div class="admin-shell${collapsed ? ' sidebar-collapsed' : ''}">
    <div class="sidebar-backdrop no-print" id="sidebar-backdrop"></div>
    <aside class="admin-sidebar no-print" id="admin-sidebar" aria-label="Điều hướng quản trị">
      <div class="sidebar-head">
        <a class="brand" href="#/admin/dashboard">
          <span class="brand-mark">MG</span>
          <span>
            <span class="brand-title">META GYM</span>
            <span class="brand-sub">Admin Operate</span>
          </span>
        </a>
        <button type="button" class="btn btn-ghost btn-icon sidebar-collapse-btn" id="sidebar-collapse-btn" aria-label="${collapsed ? 'Mở rộng menu' : 'Thu gọn menu'}" aria-expanded="${!collapsed}" title="${collapsed ? 'Mở rộng menu' : 'Thu gọn menu'}">
          ${icon('menu', 18)}
        </button>
        <button type="button" class="btn btn-ghost btn-icon sidebar-close" id="sidebar-close-btn" aria-label="Đóng menu">
          ${icon('menu', 18)}
        </button>
      </div>
      <nav class="sidebar-nav" aria-label="Quản trị">${navHtml}</nav>
    </aside>

    <div class="admin-main">
      <header class="admin-topbar no-print">
        <div class="topbar-left">
          <button type="button" class="menu-toggle" id="menu-open-btn" aria-label="Mở menu điều hướng" aria-controls="admin-sidebar" aria-expanded="false">
            ${icon('menu', 20)}
          </button>
          <div>
            <h1 class="page-heading">${esc(resolvedTitle)}</h1>
            ${resolvedSub ? `<p class="page-subtitle">${esc(resolvedSub)}</p>` : ''}
          </div>
        </div>
        <div class="topbar-actions">${topbarActionsHtml}${accountHtml}</div>
      </header>

      <main class="page-content" id="main-content">
        <div id="notice" aria-live="polite"></div>
        ${contentHtml}
      </main>
    </div>
  </div>`;
  }

  const logoutBtn = root.querySelector?.('#logout');
  if (logoutBtn && typeof onSignOut === 'function') {
    logoutBtn.onclick = onSignOut;
  }

  const sidebar = root.querySelector?.('#admin-sidebar');
  const backdrop = root.querySelector?.('#sidebar-backdrop');
  const openBtn = root.querySelector?.('#menu-open-btn');
  const closeBtn = root.querySelector?.('#sidebar-close-btn');

  const setSidebarOpen = (open) => {
    sidebar?.classList?.toggle('open', open);
    backdrop?.classList?.toggle('open', open);
    openBtn?.setAttribute?.('aria-expanded', String(open));
  };

  if (openBtn) openBtn.onclick = () => setSidebarOpen(true);
  if (closeBtn) closeBtn.onclick = () => setSidebarOpen(false);
  if (backdrop) backdrop.onclick = () => setSidebarOpen(false);
  root.querySelectorAll?.('.meta-nav-item, .admin-user-link').forEach((link) => {
    link.addEventListener?.('click', () => setSidebarOpen(false));
  });

  const collapseBtn = root.querySelector?.('#sidebar-collapse-btn');
  if (collapseBtn) {
    collapseBtn.onclick = () => {
      const shellEl = root.querySelector?.('.admin-shell');
      if (!shellEl) return;
      const next = !shellEl.classList?.contains('sidebar-collapsed');
      shellEl.classList?.toggle('sidebar-collapsed', next);
      setSidebarCollapsedStorage(next);
      const label = next ? 'Mở rộng menu' : 'Thu gọn menu';
      collapseBtn.setAttribute?.('aria-label', label);
      collapseBtn.setAttribute?.('title', label);
      collapseBtn.setAttribute?.('aria-expanded', String(!next));
    };
  }

  const themeBtn = root.querySelector?.('#theme-toggle-btn');
  if (themeBtn) {
    themeBtn.onclick = () => {
      const next = toggleTheme();
      const label = next === 'dark' ? 'Chuyển sang giao diện sáng' : 'Chuyển sang giao diện tối';
      themeBtn.innerHTML = icon(next === 'dark' ? 'sun' : 'moon', 18);
      themeBtn.setAttribute?.('aria-label', label);
      themeBtn.setAttribute?.('title', label);
    };
  }

  if (globalThis.document?.addEventListener) {
    if (globalThis.__metaShellEscHandler) {
      globalThis.document.removeEventListener('keydown', globalThis.__metaShellEscHandler);
    }
    globalThis.__metaShellEscHandler = (event) => {
      if (event.key === 'Escape' && sidebar?.classList?.contains('open')) {
        setSidebarOpen(false);
        openBtn?.focus?.();
      }
    };
    globalThis.document.addEventListener('keydown', globalThis.__metaShellEscHandler);
  }
}
