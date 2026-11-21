import { esc, initials } from './format.js';
import { icon } from './icons.js';

export const NAV_GROUPS = [
  {
    label: 'Vận hành',
    items: [
      { id: 'dashboard', href: '#/admin/dashboard', label: 'Tổng quan', icon: 'dashboard' },
      { id: 'coach-incidents', href: '#/admin/coach-incidents', label: 'Sự cố Coach', icon: 'alert', badgeKey: 'incidents' },
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
      { id: 'nutrition-foods', href: '#/admin/nutrition-foods', label: 'Thực phẩm & kcal', icon: 'food' },
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
          return `<a class="meta-nav-item ${isCurrent ? 'active' : ''}" href="${item.href}" ${isCurrent ? 'aria-current="page"' : ''}>
            ${icon(item.icon, 17)}
            <span class="nav-item-label">${esc(item.label)}</span>
            ${badgeVal > 0 ? `<span class="nav-count ${badgeCls}">${badgeVal}</span>` : ''}
          </a>`;
        }).join('')}
      </div>
    </div>
  `).join('');

  root.innerHTML = `<div class="admin-shell">
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
        <button type="button" class="btn btn-ghost btn-icon sidebar-close" id="sidebar-close-btn" aria-label="Đóng menu">
          ${icon('close', 18)}
        </button>
      </div>
      <nav class="sidebar-nav" aria-label="Quản trị">${navHtml}</nav>
      <div class="sidebar-foot">
        <a class="admin-user-link" href="#/admin/profile" ${section === 'profile' ? 'aria-current="page"' : ''}>
          <span class="meta-avatar">${esc(initials(user?.fullName || 'Admin'))}</span>
          <span class="admin-user-meta">
            <span class="admin-user-name">${esc(user?.fullName || 'Quản trị viên')}</span>
            <span class="admin-user-role">${esc(user?.email || 'ADMIN')}</span>
          </span>
        </a>
        <button type="button" class="btn btn-ghost btn-sm" id="logout" style="width:100%">
          ${icon('logout', 16)} Đăng xuất
        </button>
      </div>
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
        ${topbarActionsHtml ? `<div class="topbar-actions">${topbarActionsHtml}</div>` : ''}
      </header>

      <main class="page-content" id="main-content">
        <div id="notice" aria-live="polite"></div>
        ${contentHtml}
      </main>
    </div>
  </div>`;

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
}
