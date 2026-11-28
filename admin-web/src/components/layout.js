import { esc, emailInitial } from './format.js';
import { icon } from './icons.js';
import { openModal } from './modal.js';
import { bindNotificationBell } from './notifications.js';
import { getTheme, toggleTheme } from '../services/theme.js';
import { getUserPositionLabel, hasPermission } from '../services/permissions.js';

export const NAV_GROUPS = [
  {
    label: 'Ưu tiên xử lý',
    items: [
      { id: 'dashboard', href: '#/admin/dashboard', label: 'Tổng quan', icon: 'dashboard', permission: 'dashboard:read', desc: 'KPI doanh thu, hội viên, cảnh báo vận hành và so sánh kỳ.' },
      { id: 'coach-incidents', href: '#/admin/incidents', label: 'Sự cố Coach', icon: 'alert', badgeKey: 'incidents', permission: 'incidents:read', desc: 'Xử lý ca đóng băng COACH_LOCKED, chuyển Coach hoặc hoàn tiền.' },
      { id: 'terminations', href: '#/admin/relationships?tab=terminations', label: 'Tranh chấp & Kết thúc sớm', icon: 'shield', badgeKey: 'disputes', permission: 'disputes:read', desc: 'Phân xử yêu cầu kết thúc sớm quá hạn 72 giờ (D5).' },
      { id: 'simulated-refunds', href: '#/admin/incidents?tab=refunds', label: 'Hoàn tiền mô phỏng', icon: 'refund', permission: 'refunds:read', desc: 'Tra cứu và đối soát bút toán hoàn tiền gói Coach (D3).' },
    ],
  },
  {
    label: 'Quầy lễ tân & Hội viên',
    items: [
      { id: 'payments', href: '#/admin/payments', label: 'Giao dịch & Thu tại quầy', icon: 'receipt', permission: 'payments:read', desc: 'Thu tiền gói Gym tại quầy, áp voucher và đảo giao dịch D6.' },
      { id: 'gym', href: '#/admin/gym', label: 'Phòng gym & QR điểm danh', icon: 'building', permission: 'gym:read', desc: 'Cập nhật hồ sơ phòng tập, ảnh bìa và in/đổi mã QR quầy.' },
      { id: 'members', href: '#/admin/members', label: 'Hội viên', icon: 'users', permission: 'members:read', desc: 'Quản lý hồ sơ hội viên, ảnh đại diện WebP và khóa/mở D4.' },
      { id: 'plan-entitlements', href: '#/admin/plans?tab=entitlements', label: 'Quyền sử dụng gói Gym', icon: 'checkDouble', permission: 'plans:read', desc: 'Theo dõi các gói Gym đang hiệu lực, đã xếp lịch hoặc hết hạn.' },
    ],
  },
  {
    label: 'Nhân sự & Vị trí nhân viên',
    items: [
      { id: 'staff', href: '#/admin/staff', label: 'Nhân sự & Vị trí nhân viên', icon: 'user', permission: 'staff:read', desc: 'Phân cấp 5 vị trí nhân viên, tài khoản vận hành và phân quyền.' },
      { id: 'coaches', href: '#/admin/coaches', label: 'Huấn luyện viên (Coach)', icon: 'award', permission: 'coaches:read', desc: 'Quản lý hồ sơ Coach, ảnh WebP, trần cứng 8 suất và khóa D1.' },
      { id: 'coach-schedule', href: '#/admin/coach-schedule', label: 'Lịch trực & Ca Coach', icon: 'calendar', permission: 'coaches:read', desc: 'Xem tổng hợp số Coach trong ca, đang rảnh hoặc bận theo Ngày/Tuần/Tháng.' },
      { id: 'relationships', href: '#/admin/relationships', label: 'Quan hệ Member–Coach', icon: 'link', permission: 'relationships:read', desc: 'Theo dõi trạng thái ACTIVE/PAUSED/ENDED và điều chuyển Coach.' },
      { id: 'coach-transfers', href: '#/admin/relationships?tab=transfers', label: 'Lịch sử chuyển Coach', icon: 'swap', permission: 'transfers:read', desc: 'Truy vết lịch sử chuyển đổi Coach và ngày cộng bù đóng băng.' },
      { id: 'coach-entitlements', href: '#/admin/coach-packages?tab=entitlements', label: 'Quyền lợi gói Coach', icon: 'calendar', permission: 'coach-packages:read', desc: 'Giám sát gói buổi Coach ACTIVE, QUEUED và đóng băng.' },
    ],
  },
  {
    label: 'Gói dịch vụ & Bảng giá',
    items: [
      { id: 'plans', href: '#/admin/plans', label: 'Danh mục gói Gym', icon: 'card', permission: 'plans:manage', desc: 'Thiết lập giá, thời hạn, đợt mở bán và ảnh thẻ 2 mặt.' },
      { id: 'coach-packages', href: '#/admin/coach-packages', label: 'Danh mục gói Coach', icon: 'dumbbell', permission: 'coach-packages:manage', desc: 'Tạo/sửa các gói huấn luyện kèm số buổi và giá niêm yết.' },
      { id: 'vouchers', href: '#/admin/vouchers', label: 'Voucher khuyến mãi', icon: 'tag', permission: 'plans:read', desc: 'Phát hành mã giảm VND/%, thời hạn, điều kiện và banner WebP.' },
    ],
  },
  {
    label: 'Thiết bị & Chuyên môn',
    items: [
      { id: 'equipment', href: '#/admin/equipment', label: 'Thiết bị phòng tập', icon: 'dumbbell', permission: 'equipment:manage', desc: 'Quản lý danh mục máy tập, hình ảnh và trạng thái sử dụng.' },
      { id: 'exercises', href: '#/admin/equipment?tab=exercises', label: 'Thư viện bài tập', icon: 'layers', permission: 'equipment:manage', desc: 'Quản lý bài tập, nhóm cơ mục tiêu và thiết bị liên kết.' },
      { id: 'nutrition-foods', href: '#/admin/foods', label: 'Thực phẩm dinh dưỡng', icon: 'food', permission: 'foods:manage', desc: 'Quản lý dữ liệu thực phẩm kcal/100g cho thực đơn Coach.' },
    ],
  },
  {
    label: 'Kho Media & Image Server',
    items: [
      { id: 'media-library', href: '#/admin/media-library', label: 'Thư viện ảnh', icon: 'image', permission: 'media:read', desc: 'Đồng bộ Supabase Storage, upload/cắt ảnh theo từng thư mục.' },
      { id: 'media-sharing', href: '#/admin/media-sharing', label: 'Chia sẻ & API Key', icon: 'share', permission: 'media:manage', desc: 'Tạo link chia sẻ ảnh bảo mật và cấp API Key tích hợp.' },
      { id: 'media-analytics', href: '#/admin/media-analytics', label: 'Phân tích & Lưu trữ', icon: 'hardDrive', permission: 'media:manage', desc: 'Theo dõi băng thông, dung lượng bucket và dọn file dư.' },
      { id: 'media-settings', href: '#/admin/media-settings', label: 'Cấu hình Image Server', icon: 'settings', permission: 'system:manage', desc: 'Thiết lập tối ưu WebP, giới hạn dung lượng và rate limit.' },
    ],
  },
  {
    label: 'Hệ thống & Kiểm soát',
    items: [
      { id: 'system-info', href: '#/admin/system-info', label: 'Thông tin hệ thống', icon: 'info', permission: 'system:read', desc: 'Chính sách bảo mật, điều khoản, icon 3D, thanh toán & thiết bị.' },
      { id: 'audit-logs', href: '#/admin/audit-logs', label: 'Nhật ký hệ thống', icon: 'audit', permission: 'audit:read', desc: 'Truy vết thao tác quản trị (Audit Log) bảo vệ quyền riêng tư.' },
      { id: 'design-system', href: '#/admin/design', label: 'Thư viện thiết kế', icon: 'layers', permission: 'system:manage', desc: 'Tra cứu token màu sắc, nút bấm, thẻ và mẫu giao diện.' },
    ],
  },
];

export const PAGE_META = {
  dashboard: {
    title: 'Tổng quan',
    subtitle: '',
  },
  'coach-incidents': {
    title: 'Sự cố Coach (COACH_LOCKED)',
    subtitle: 'Theo dõi hội viên đóng băng gói Coach: chờ mở khóa (D1), chuyển Coach (D2) hoặc hoàn mô phỏng (D3).',
  },
  'simulated-refunds': {
    title: 'Lịch sử hoàn tiền mô phỏng',
    subtitle: 'Theo dõi các bút toán hoàn tiền mô phỏng phát sinh từ sự cố khóa Coach (D3).',
  },
  members: {
    title: 'Quản lý Hội viên (Member)',
    subtitle: 'Tìm kiếm server-side, hồ sơ vận hành (không lộ dữ liệu riêng tư) và khóa/mở theo quy tắc D4.',
  },
  coaches: {
    title: 'Quản lý Huấn luyện viên (Coach)',
    subtitle: 'Trần suất cứng 8 hội viên/Coach, cấp mật khẩu tạm 1 lần và khóa/mở theo quy tắc D1.',
  },
  'coach-schedule': {
    title: 'Lịch làm việc & Ca trực Coach',
    subtitle: 'Theo dõi nhanh số Coach đang trong ca, đang rảnh hoặc đang bận theo từng khung giờ Ngày / Tuần / Tháng.',
  },
  accounts: {
    title: 'Quản lý Tài khoản',
    subtitle: 'Hội viên & Huấn luyện viên — trần cứng 8 suất và khóa/mở có xem trước tác động.',
  },
  staff: {
    title: 'Nhân sự & Vị trí nhân viên',
    subtitle: 'Quản lý đầy đủ 5 vị trí nhân viên (Quản trị viên, Quản lý, Lễ tân/Thu ngân, Coach, Kỹ thuật viên) và phân quyền menu.',
  },
  relationships: {
    title: 'Quan hệ Member–Coach',
    subtitle: 'Theo dõi trạng thái ACTIVE / PAUSED / ENDED, phân biệt lý do tạm ngưng và chuyển Coach trực tiếp.',
  },
  terminations: {
    title: 'Kết thúc sớm & Tranh chấp (D5)',
    subtitle: 'Hàng chờ yêu cầu kết thúc sớm và tranh chấp quá 72 giờ cần Admin phân xử.',
  },
  'coach-transfers': {
    title: 'Lịch sử chuyển Coach',
    subtitle: 'Truy vết các lượt chuyển Coach cùng số ngày đóng băng đã cộng bù và lý do xử lý.',
  },
  plans: {
    title: 'Danh mục gói Gym',
    subtitle: 'Chỉnh sửa giá/số ngày trực tiếp cho giao dịch mới; gói đã mua giữ nguyên snapshot.',
  },
  vouchers: {
    title: 'Quản lý Voucher khuyến mãi',
    subtitle: 'Phát hành mã giảm giá (tiền cố định VND hoặc %), thời gian áp dụng, điều kiện đơn hàng và ảnh WebP.',
  },
  'plan-entitlements': {
    title: 'Quyền sử dụng gói Gym',
    subtitle: 'Theo dõi gói Gym hội viên đang hiệu lực, đã xếp lịch, hết hạn hoặc đã hủy.',
  },
  'coach-packages': {
    title: 'Danh mục gói Coach',
    subtitle: 'Danh mục Full CRUD không giới hạn 3 mã; giá và số buổi áp dụng cho giao dịch mới.',
  },
  'coach-entitlements': {
    title: 'Quyền lợi gói Coach',
    subtitle: 'Theo dõi quyền lợi gói Coach ACTIVE / QUEUED / ENDED và các gói đang đóng băng (COACH_LOCKED).',
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
    title: 'Thiết bị phòng tập',
    subtitle: 'Quản lý thiết bị phòng tập, ảnh công khai và hướng dẫn sử dụng an toàn.',
  },
  exercises: {
    title: 'Thư viện bài tập (exercises)',
    subtitle: 'Quản lý danh mục bài tập, độ khó, nhóm cơ mục tiêu và liên kết thiết bị.',
  },
  'audit-logs': {
    title: 'Nhật ký Hệ thống (Audit Log)',
    subtitle: 'Truy vết thao tác quản trị với metadata đã qua bộ lọc an toàn quyền riêng tư.',
  },
  'system-info': {
    title: 'Quản lý Thông tin Hệ thống',
    subtitle: 'Chính sách bảo mật, Điều khoản sử dụng, Bộ icon màn hình chính, Phương thức thanh toán và Thiết bị.',
  },
  profile: {
    title: 'Hồ sơ Quản trị viên',
    subtitle: 'Thông tin tài khoản Admin hiện hành và đổi mật khẩu (tự động thu hồi phiên cũ).',
  },
  notification: {
    title: 'Thông báo vận hành',
    subtitle: 'Theo dõi sự cố Coach và tranh chấp 72h cần Admin xử lý.',
  },
  'design-system': {
    title: 'Thư viện Thiết kế',
    subtitle: 'Tổng hợp các component dùng chung trên Desktop và Mobile để dev xem và tái sử dụng.',
  },
  'media-library': {
    title: 'Image Library & Albums',
    subtitle: 'Upload đa tệp, Paste Clipboard, Import URL, quản lý Folder/Album/Tag và chỉnh sửa biến thể ảnh.',
  },
  'media-sharing': {
    title: 'Chia sẻ & Quản lý API Key',
    subtitle: 'Tạo liên kết chia sẻ có mật khẩu/hết hạn và cấp phát API Key tích hợp ngoài (/api/v1/*).',
  },
  'media-analytics': {
    title: 'Analytics & Quản lý Lưu trữ',
    subtitle: 'Thống kê lượt xem thật vs bot, băng thông, quota từng tài khoản, dọn file mồ côi & backup metadata.',
  },
  'media-settings': {
    title: 'Cấu hình Hệ thống Image Server',
    subtitle: 'Thiết lập thương hiệu, giới hạn upload, tối ưu Sharp (WebP/AVIF), SMTP, rate limit và bảo trì.',
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

function openCommandGridModal({ visibleGroups, activeKey, badges = {}, positionLabel }) {
  const totalItems = visibleGroups.reduce((acc, g) => acc + g.items.length, 0);
  const renderGroupsHtml = (queryText = '') => {
    const q = queryText.trim().toLowerCase();
    const filtered = visibleGroups.map((group) => ({
      ...group,
      items: group.items.filter((item) => {
        if (!q) return true;
        return item.label.toLowerCase().includes(q)
          || (item.desc || '').toLowerCase().includes(q)
          || group.label.toLowerCase().includes(q);
      }),
    })).filter((g) => g.items.length > 0);

    if (!filtered.length) {
      return `<div class="cmd-grid-empty">Không tìm thấy chức năng khớp "${esc(queryText)}".</div>`;
    }

    return filtered.map((group, idx) => `
      <section class="cmd-grid-section">
        <div class="cmd-grid-group-head">
          <span class="cmd-grid-group-num tabular">${String(idx + 1).padStart(2, '0')}</span>
          <h3 class="cmd-grid-group-title">${esc(group.label)}</h3>
          <span class="cmd-grid-group-count tabular">${group.items.length}</span>
        </div>
        <div class="cmd-grid-cards">
          ${group.items.map((item) => {
            const isCurrent = item.id === activeKey;
            const badgeVal = item.badgeKey ? Number(badges[item.badgeKey] || 0) : 0;
            const badgeCls = item.badgeKey === 'disputes' ? 'danger' : 'warn';
            return `<a class="cmd-grid-card ${isCurrent ? 'is-current' : ''}" href="${item.href}">
              <div class="cmd-grid-card-top">
                <span class="cmd-grid-icon">${icon(item.icon, 20)}</span>
                <div class="cmd-grid-badges">
                  ${badgeVal > 0 ? `<span class="nav-count ${badgeCls}">${badgeVal}</span>` : ''}
                  ${isCurrent ? '<span class="meta-badge meta-badge-coral">Đang mở</span>' : ''}
                </div>
              </div>
              <div class="cmd-grid-card-title">${esc(item.label)}</div>
              <p class="cmd-grid-card-desc">${esc(item.desc || '')}</p>
            </a>`;
          }).join('')}
        </div>
      </section>
    `).join('');
  };

  openModal({
    maxWidth: '1080px',
    title: 'Bảng điều khiển hệ thống',
    subtitle: `Toàn bộ ${totalItems} chức năng được sắp theo thứ tự ưu tiên cho vị trí ${positionLabel}`,
    bodyHtml: `<div class="meta-modal-body cmd-grid-modal-body">
      <div class="cmd-grid-search-bar">
        <span class="cmd-grid-search-icon">${icon('search', 16)}</span>
        <input id="cmd-grid-search" class="form-control cmd-grid-search-input" type="search" placeholder="Tìm nhanh chức năng (VD: voucher, sự cố, hội viên, coach, ảnh...)" autocomplete="off" />
      </div>
      <div class="cmd-grid-container" id="cmd-grid-container">
        ${renderGroupsHtml('')}
      </div>
    </div>`,
    onMount(ctrl) {
      const searchEl = ctrl.dialog.querySelector('#cmd-grid-search');
      const containerEl = ctrl.dialog.querySelector('#cmd-grid-container');
      const bindLinks = () => {
        containerEl?.querySelectorAll('.cmd-grid-card').forEach((card) => {
          card.addEventListener('click', () => ctrl.close());
        });
      };
      bindLinks();
      if (searchEl && containerEl) {
        searchEl.oninput = () => {
          containerEl.innerHTML = renderGroupsHtml(searchEl.value);
          bindLinks();
        };
        setTimeout?.(() => searchEl.focus?.(), 20);
      }
    },
  });
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
  const activeKey = section === 'accounts' ? 'coaches' : section;
  const meta = PAGE_META[section] || { title: section, subtitle: '' };
  const resolvedTitle = title || meta.title;
  const resolvedSub = subtitle !== undefined ? subtitle : meta.subtitle;

  const visibleGroups = NAV_GROUPS.map((group) => ({
    ...group,
    items: group.items.filter((item) => hasPermission(item.permission, user)),
  })).filter((group) => group.items.length > 0);

  const navHtml = visibleGroups.map((group) => `
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

  const positionLabel = getUserPositionLabel(user);
  const footHtml = `<a class="sidebar-position-pill" href="#/admin/staff?tab=positions" title="${esc(`${user?.fullName || 'Meta Admin'} · ${positionLabel}`)}">
    <span class="meta-avatar">${esc(emailInitial(user?.email, 'A'))}</span>
    <span class="sidebar-pos-text">
      <strong>${esc(user?.fullName || user?.email || 'Meta Admin')}</strong>
      <span>${esc(positionLabel)}</span>
    </span>
  </a>`;

  const currentTheme = getTheme();
  const nextThemeLabel = currentTheme === 'dark' ? 'Chuyển sang giao diện sáng' : 'Chuyển sang giao diện tối';
  const themeBtnHtml = `<button type="button" class="btn btn-ghost btn-icon" id="theme-toggle-btn" aria-label="${nextThemeLabel}" title="${nextThemeLabel}">
    ${icon(currentTheme === 'dark' ? 'sun' : 'moon', 18)}
  </button>`;
  const notifHtml = `<div class="notif-wrap" id="admin-notif-wrap">
    <button type="button" class="btn btn-ghost btn-icon notif-bell-btn" id="admin-bell-btn" aria-label="Thông báo" aria-haspopup="dialog" aria-expanded="false" title="Thông báo">
      ${icon('bell', 18)}
      <span class="notif-badge" id="admin-bell-badge" hidden>0</span>
    </button>
    <div class="notif-popover" id="admin-notif-popover" role="dialog" aria-label="Thông báo vận hành" hidden></div>
  </div>`;
  const commandGridBtnHtml = `<button type="button" class="btn btn-graphite btn-sm command-grid-trigger" id="open-command-grid-btn" aria-label="Mở bảng điều khiển nhanh" title="Bảng điều khiển toàn bộ chức năng">
    ${icon('grid', 16)} <span class="cmd-grid-btn-label">Bảng điều khiển</span>
  </button>`;
  const accountHtml = `<div class="topbar-account">
    ${commandGridBtnHtml}
    ${themeBtnHtml}
    ${notifHtml}
    <a class="admin-user-link topbar-user-link" href="#/admin/profile" ${section === 'profile' ? 'aria-current="page"' : ''} aria-label="Hồ sơ quản trị viên" title="Hồ sơ quản trị viên">
      <span class="meta-avatar">${esc(emailInitial(user?.email, 'A'))}</span>
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
      <div class="sidebar-foot">${footHtml}</div>
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

  const commandGridBtn = root.querySelector?.('#open-command-grid-btn');
  if (commandGridBtn) {
    commandGridBtn.onclick = () => openCommandGridModal({ visibleGroups, activeKey, badges, positionLabel });
  }

  bindNotificationBell(root);

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
