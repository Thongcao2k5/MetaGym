import {
  daysAgoVN,
  emailInitial,
  esc,
  initials,
  isoDateVN,
  relationshipStatusBadge,
  seatMeterHtml,
  statusBadge,
  vnd,
} from '../components/format.js';
import { renderActionButton } from '../components/action-button.js';
import { bindDataTableSelection, renderDataTable } from '../components/data-table.js';
import {
  bindDatePickers,
  bindDateRangePicker,
  renderDateInput,
  renderDateRangePicker,
  setDatePickerValue,
} from '../components/date-picker.js';
import { computeDatePreset, DATE_PRESETS } from '../components/date-range.js';
import { openDrawer } from '../components/drawer.js';
import { exportToExcel } from '../components/export.js';
import { icon } from '../components/icons.js';
import { openAlertModal, openConfirmModal, openModal } from '../components/modal.js';
import { bindMultiSelects, renderMultiSelect } from '../components/multi-select.js';
import { bindSelectDropdowns, renderSelectDropdown } from '../components/select-dropdown.js';
import { bindPagination, renderPagination } from '../components/pagination.js';
import {
  renderBanner,
  renderEmptyState,
  renderErrorState,
  renderFilterEmptyState,
  renderTableSkeleton,
} from '../components/states.js';
import { toast } from '../components/toast.js';
import { renderToggle } from '../components/toggle.js';

const COLOR_TOKENS = [
  { name: 'Primary', token: '--meta-primary', hex: '#FF5E36' },
  { name: 'Primary Hover', token: '--meta-primary-hover', hex: '#E84E27' },
  { name: 'Success', token: '--meta-success', hex: '#2ECC71' },
  { name: 'Warning', token: '--meta-warning', hex: '#F39C12' },
  { name: 'Danger', token: '--meta-danger', hex: '#F15B64' },
  { name: 'Info', token: '--meta-info', hex: '#70AEE8' },
  { name: 'Coach Avatar', token: '--meta-coach-avatar', hex: '#F5B041' },
];

const INITIAL_ROWS = [
  { id: '1', name: 'Nguyễn Minh Quân', email: 'quan.nm@metagym.vn', role: 'MEMBER', status: 'ACTIVE', slots: null, amount: 1200000 },
  { id: '2', name: 'Lê Hoàng Nam', email: 'nam.lh@metagym.vn', role: 'COACH', status: 'ACTIVE', slots: 6, amount: 4500000 },
  { id: '3', name: 'Trần Bảo Ngọc', email: 'ngoc.tb@metagym.vn', role: 'MEMBER', status: 'DISABLED', slots: null, amount: 850000 },
];

export async function renderDesignSystemPage({ root, shell }) {
  const today = isoDateVN();
  const weekAgo = daysAgoVN(6);
  let viewMode = 'both'; // both | desktop | mobile
  let activeTab = 'ALL';
  let statePreview = 'empty'; // empty | filter | skeleton | error
  let samplePage = 1;
  let samplePageSize = 10;
  let selectedRows = [];
  let toggleChecked = true;
  let rowsState = INITIAL_ROWS.map((r) => ({ ...r }));

  const tableColumns = [
    {
      label: 'Người dùng',
      render: (row) => `<div class="person-cell">
        <span class="meta-avatar ${row.role === 'COACH' ? 'meta-avatar-coach' : ''}">${row.role === 'COACH' ? initials(row.name) : emailInitial(row.email)}</span>
        <div><span class="person-name">${esc(row.name)}</span><span class="person-sub">${esc(row.email)}</span></div>
      </div>`,
    },
    {
      label: 'Suất Coach',
      render: (row) => (row.slots !== null ? seatMeterHtml(row.slots, 8) : '—'),
    },
    {
      label: 'Số tiền',
      align: 'right',
      render: (row) => `<span class="tabular">${vnd(row.amount)}</span>`,
    },
    {
      label: 'Trạng thái',
      render: (row) => {
        const isActive = row.status === 'ACTIVE';
        return `<div class="status-switch-cell">
          <button type="button" class="meta-switch-btn ${isActive ? 'is-on' : 'is-off'}" data-ds-switch="${esc(row.id)}" role="switch" aria-checked="${isActive}" aria-label="Đổi trạng thái ${esc(row.name)}">
            <span class="meta-switch-track"><span class="meta-switch-thumb"></span></span>
            <span class="meta-switch-text">${isActive ? 'Hoạt động' : 'Bị khóa'}</span>
          </button>
        </div>`;
      },
    },
    {
      label: 'Thao tác',
      align: 'right',
      render: (row) => `<div class="cell-actions">
        ${renderActionButton({ iconName: 'eye', label: 'Chi tiết', className: 'detail', attrs: `data-ds-detail="${esc(row.id)}"` })}
        ${renderActionButton({ iconName: 'key', label: 'Khóa quyền mẫu', className: 'reset', permission: false, disabledReason: 'Tài khoản không có quyền thao tác này' })}
      </div>`,
    },
  ];

  const renderStatePreviewHtml = () => {
    if (statePreview === 'skeleton') {
      return `<div class="ds-compare-grid ${viewMode !== 'both' ? 'is-single' : ''}">
        ${viewMode !== 'mobile' ? `<div class="ds-preview-box">
          <div class="ds-preview-label">Desktop · <code>renderTableSkeleton</code></div>
          ${renderTableSkeleton({ rows: 3, columns: 5, selectable: true, hasActions: true })}
        </div>` : ''}
        ${viewMode !== 'desktop' ? `<div class="ds-preview-box">
          <div class="ds-preview-label">Mobile (375px) · <code>renderTableSkeleton</code></div>
          <div class="ds-mobile-frame ds-mobile-skeleton">
            ${renderTableSkeleton({ rows: 3, columns: 5, selectable: true, hasActions: true })}
          </div>
        </div>` : ''}
      </div>`;
    }
    if (statePreview === 'filter') return renderFilterEmptyState({ resetId: 'ds-reset-filter-sample' });
    if (statePreview === 'error') return renderErrorState({ title: 'Không thể kết nối máy chủ', message: 'Mẫu hiển thị khi API gặp lỗi hoặc mất mạng.', retryId: 'ds-retry-sample' });
    return renderEmptyState({
      iconName: 'bell',
      title: 'Chưa có dữ liệu',
      description: 'Component trạng thái rỗng dùng chung cho bảng, biểu đồ và thông báo.',
      ctaLabel: 'Tạo mới mẫu',
      ctaId: 'ds-empty-cta',
    });
  };

  const renderContent = () => {
    const filteredRows = activeTab === 'ALL' ? rowsState : rowsState.filter((r) => r.status === activeTab);
    const tableHtml = renderDataTable({
      columns: tableColumns,
      rows: filteredRows,
      selectable: true,
      paginationHtml: renderPagination({
        page: samplePage,
        pageSize: samplePageSize,
        totalItems: 28,
        totalPages: Math.max(1, Math.ceil(28 / samplePageSize)),
      }),
    });

    return `
      <div class="stack-20">
        <div class="filter-bar">
          <div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;flex:1">
            <strong style="color:var(--meta-text-strong);font-size:13.5px">Chế độ xem trước:</strong>
            <div class="chart-segmented" role="group" aria-label="Chế độ xem trước component">
              <button type="button" class="chart-seg-btn ${viewMode === 'both' ? 'active' : ''}" data-ds-mode="both">Desktop & Mobile</button>
              <button type="button" class="chart-seg-btn ${viewMode === 'desktop' ? 'active' : ''}" data-ds-mode="desktop">Desktop</button>
              <button type="button" class="chart-seg-btn ${viewMode === 'mobile' ? 'active' : ''}" data-ds-mode="mobile">Mobile (375px)</button>
            </div>
          </div>
          <span class="meta-badge meta-badge-info">Be Vietnam Pro · 4/8px Grid · 44px Touch</span>
        </div>

        <section class="meta-card stack-16">
          <div>
            <h2 class="card-title-text">1. Bảng màu & Token hệ thống</h2>
            <p class="card-sub">Dùng biến CSS <code>--meta-*</code> trong <code>style.css</code> để tự động hỗ trợ Dark/Light mode.</p>
          </div>
          <div class="ds-swatch-grid">
            ${COLOR_TOKENS.map((c) => `<div class="ds-swatch">
              <span class="ds-swatch-dot" style="background:${c.hex}"></span>
              <div>
                <div class="ds-swatch-name">${c.name}</div>
                <code class="ds-swatch-code">${c.token} · ${c.hex}</code>
              </div>
            </div>`).join('')}
          </div>
        </section>

        <section class="meta-card stack-16">
          <div>
            <h2 class="card-title-text">2. Nút bấm, Toggle, Badge & Avatar</h2>
            <p class="card-sub">Touch target tối thiểu <code>44px</code>; chỉ 1 nút cam chính mỗi vùng; nút thiếu quyền hiển thị <code>disabled</code> kèm tooltip.</p>
          </div>
          <div style="display:flex;flex-wrap:wrap;gap:10px;align-items:center">
            <button type="button" class="btn btn-primary">${icon('plus', 16)} Nút chính (.btn-primary)</button>
            <button type="button" class="btn btn-graphite">${icon('filter', 16)} Phụ (.btn-graphite)</button>
            <button type="button" class="btn btn-ghost">${icon('refresh', 16)} Ghost (.btn-ghost)</button>
            <button type="button" class="btn btn-danger">${icon('lock', 16)} Cảnh báo (.btn-danger)</button>
            <button type="button" class="btn btn-ghost btn-icon" aria-label="Thông báo">${icon('bell', 18)}</button>
            <button type="button" class="btn btn-ghost btn-icon" aria-label="Đọc hết">${icon('checkDouble', 18)}</button>
          </div>
          <div class="ds-state-table">
            <div class="ds-state-grid">
              <div class="ds-state-head">Loại nút</div>
              <div class="ds-state-head">Default</div>
              <div class="ds-state-head">Hover</div>
              <div class="ds-state-head">Clicked</div>
              <div class="ds-state-head">Loading</div>
              <div class="ds-state-head">Disabled</div>
              ${[
                { name: 'Chính', cls: 'btn-primary', iconName: 'plus', label: 'Lưu' },
                { name: 'Phụ', cls: 'btn-graphite', iconName: 'filter', label: 'Bộ lọc' },
                { name: 'Ghost', cls: 'btn-ghost', iconName: 'refresh', label: 'Làm mới' },
                { name: 'Cảnh báo', cls: 'btn-danger', iconName: 'lock', label: 'Khóa' },
              ].map((v) => `
                <div class="ds-state-variant">${v.name}</div>
                <div class="ds-state-cell"><button type="button" class="btn ${v.cls} btn-sm">${icon(v.iconName, 14)} ${v.label}</button></div>
                <div class="ds-state-cell"><button type="button" class="btn ${v.cls} btn-sm is-hover">${icon(v.iconName, 14)} ${v.label}</button></div>
                <div class="ds-state-cell"><button type="button" class="btn ${v.cls} btn-sm is-hover is-active">${icon(v.iconName, 14)} ${v.label}</button></div>
                <div class="ds-state-cell"><button type="button" class="btn ${v.cls} btn-sm" disabled><span class="btn-spinner" aria-hidden="true"></span> Đang xử lý</button></div>
                <div class="ds-state-cell"><button type="button" class="btn ${v.cls} btn-sm" disabled title="Chưa đủ quyền">${icon(v.iconName, 14)} ${v.label}</button></div>
              `).join('')}
            </div>
          </div>
          <div style="display:flex;flex-wrap:wrap;gap:12px;align-items:center">
            ${statusBadge('ACTIVE')}
            ${statusBadge('PAUSED')}
            ${statusBadge('DISABLED')}
            ${statusBadge('DISPUTED')}
            ${relationshipStatusBadge('ACTIVE')}
            ${seatMeterHtml(6, 8)}
            ${seatMeterHtml(8, 8)}
            <span class="meta-avatar">A</span>
            <span class="meta-avatar meta-avatar-coach">LN</span>
            ${renderToggle({ id: 'ds-toggle-sample', checked: toggleChecked, label: 'Switch mẫu (renderToggle)' })}
          </div>
        </section>

        <section class="meta-card stack-16">
          <div>
            <h2 class="card-title-text">3. Tabs, Thanh lọc chuẩn & Bộ chọn ngày (Desktop vs Mobile)</h2>
            <p class="card-sub">Chuẩn theo <code>admin-web-data-page-guidelines.md</code>: Tabs + Thanh lọc <code>.filter-bar</code> + Date Picker tách theo thiết bị.</p>
          </div>
          <div class="meta-tabs" role="tablist" aria-label="Tabs mẫu">
            <button type="button" class="meta-tab-btn ${activeTab === 'ALL' ? 'active' : ''}" role="tab" aria-selected="${activeTab === 'ALL'}" data-ds-tab="ALL">Tất cả (${rowsState.length})</button>
            <button type="button" class="meta-tab-btn ${activeTab === 'ACTIVE' ? 'active' : ''}" role="tab" aria-selected="${activeTab === 'ACTIVE'}" data-ds-tab="ACTIVE">Hoạt động</button>
            <button type="button" class="meta-tab-btn ${activeTab === 'DISABLED' ? 'active' : ''}" role="tab" aria-selected="${activeTab === 'DISABLED'}" data-ds-tab="DISABLED">Bị khóa</button>
          </div>
          <div class="filter-bar">
            <div style="display:flex;align-items:center;gap:8px;flex:1;min-width:200px">
              <input type="search" class="form-control" id="ds-search-sample" placeholder="Tìm tên, email, SĐT..." aria-label="Tìm kiếm mẫu" />
            </div>
            <div style="width:190px;max-width:100%">
              ${renderSelectDropdown({
                id: 'ds-select-sample',
                value: '',
                options: [
                  { value: '', label: 'Tất cả trạng thái' },
                  { value: 'ACTIVE', label: 'Đang hoạt động' },
                  { value: 'PAUSED', label: 'Tạm ngưng' },
                  { value: 'DISABLED', label: 'Đã khóa' },
                ],
              })}
            </div>
            <div style="width:220px;max-width:100%">
              ${renderMultiSelect({
                id: 'ds-multi-sample',
                allLabel: 'Tất cả loại gói',
                options: [
                  { value: 'GYM_1M', label: 'Gói Gym 1 tháng' },
                  { value: 'GYM_3M', label: 'Gói Gym 3 tháng' },
                  { value: 'COACH_12', label: 'Gói Coach 12 buổi' },
                  { value: 'COACH_24', label: 'Gói Coach 24 buổi' },
                ],
              })}
            </div>
            <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap">
              <button type="button" class="btn btn-graphite btn-sm" id="ds-filter-modal-btn">
                ${icon('filter', 15)} Bộ lọc <span class="meta-badge meta-badge-coral" style="margin-left:2px">2</span>
              </button>
              <button type="button" class="btn btn-graphite btn-sm" id="ds-export-btn">
                ${icon('download', 15)} Xuất Excel${selectedRows.length ? ` (${selectedRows.length})` : ''}
              </button>
            </div>
          </div>
          <div class="ds-compare-grid ${viewMode !== 'both' ? 'is-single' : ''}">
            ${viewMode !== 'mobile' ? `<div class="ds-preview-box">
              <div class="ds-preview-label">Desktop · <code>renderDateInput</code> + <code>DATE_PRESETS</code></div>
              <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap">
                ${renderDateInput({ id: 'ds-from', value: weekAgo, ariaLabel: 'Từ ngày mẫu' })}
                <span style="color:var(--meta-text-secondary)">đến</span>
                ${renderDateInput({ id: 'ds-to', value: today, ariaLabel: 'Đến ngày mẫu' })}
              </div>
              <div style="display:flex;gap:6px;flex-wrap:wrap">
                ${DATE_PRESETS.filter((p) => p.id !== 'CUSTOM').map((p) => `<button type="button" class="pill-toggle" data-ds-preset="${p.id}">${p.label}</button>`).join('')}
              </div>
            </div>` : ''}
            ${viewMode !== 'desktop' ? `<div class="ds-preview-box">
              <div class="ds-preview-label">Mobile (375px) · <code>renderDateRangePicker</code></div>
              <div class="ds-mobile-frame">
                ${renderDateRangePicker({ id: 'ds-range', from: weekAgo, to: today })}
              </div>
            </div>` : ''}
          </div>
        </section>

        <section class="meta-card stack-16">
          <div>
            <h2 class="card-title-text">4. Bảng dữ liệu, Checkbox, Switch & Phân trang (Desktop vs Mobile)</h2>
            <p class="card-sub">Tick chọn dòng để xuất Excel chọn lọc; Desktop hiện số trang, Mobile thu gọn <code>Trước | 1 / 3 | Sau</code>.</p>
          </div>
          <div class="ds-compare-grid ${viewMode !== 'both' ? 'is-single' : ''}">
            ${viewMode !== 'mobile' ? `<div class="ds-preview-box">
              <div class="ds-preview-label">Desktop Table · <code>renderDataTable</code> + <code>renderPagination</code></div>
              ${tableHtml}
            </div>` : ''}
            ${viewMode !== 'desktop' ? `<div class="ds-preview-box">
              <div class="ds-preview-label">Mobile Card View (375px)</div>
              <div class="ds-mobile-frame ds-mobile-table">
                ${tableHtml}
              </div>
            </div>` : ''}
          </div>
        </section>

        <section class="meta-card stack-16">
          <div>
            <h2 class="card-title-text">5. Overlay tương tác (Modal, Confirm, Drawer, Toast)</h2>
            <p class="card-sub">Bấm để mở thử trực tiếp component thật đang dùng trên hệ thống.</p>
          </div>
          <div style="display:flex;flex-wrap:wrap;gap:10px">
            <button type="button" class="btn btn-graphite btn-sm" id="ds-open-modal">${icon('info', 16)} Modal chuẩn</button>
            <button type="button" class="btn btn-danger btn-sm" id="ds-open-confirm">${icon('lock', 16)} Confirm Modal (có lý do)</button>
            <button type="button" class="btn btn-graphite btn-sm" id="ds-open-drawer">${icon('eye', 16)} Detail Drawer</button>
            <button type="button" class="btn btn-success btn-sm" id="ds-alert-success">${icon('check', 16)} Modal Thành công</button>
            <button type="button" class="btn btn-warning btn-sm" id="ds-alert-warn">${icon('alert', 16)} Modal Cảnh báo</button>
            <button type="button" class="btn btn-danger btn-sm" id="ds-alert-danger">${icon('alert', 16)} Modal Lỗi</button>
            <button type="button" class="btn btn-graphite btn-sm" id="ds-alert-info">${icon('info', 16)} Modal Thông tin</button>
            <button type="button" class="btn btn-ghost btn-sm" id="ds-open-toast">${icon('check', 16)} Toast Success</button>
            <button type="button" class="btn btn-ghost btn-sm" id="ds-open-toast-warn">${icon('alert', 16)} Toast Warn</button>
            <button type="button" class="btn btn-ghost btn-sm" id="ds-open-toast-danger">${icon('alert', 16)} Toast Danger</button>
            <button type="button" class="btn btn-ghost btn-sm" id="ds-open-toast-info">${icon('info', 16)} Toast Info</button>
          </div>
        </section>

        <section class="meta-card stack-16">
          <div class="card-header-row">
            <div>
              <h2 class="card-title-text">6. Trạng thái Loading / Empty / Filter Empty / Error & Banner</h2>
              <p class="card-sub">Chuyển tab bên dưới để xem từng trạng thái chuẩn từ <code>states.js</code>.</p>
            </div>
            <div class="chart-segmented" role="group" aria-label="Chọn trạng thái mẫu">
              <button type="button" class="chart-seg-btn ${statePreview === 'empty' ? 'active' : ''}" data-ds-state="empty">Empty</button>
              <button type="button" class="chart-seg-btn ${statePreview === 'filter' ? 'active' : ''}" data-ds-state="filter">Filter Empty</button>
              <button type="button" class="chart-seg-btn ${statePreview === 'skeleton' ? 'active' : ''}" data-ds-state="skeleton">Skeleton</button>
              <button type="button" class="chart-seg-btn ${statePreview === 'error' ? 'active' : ''}" data-ds-state="error">Error</button>
            </div>
          </div>
          ${renderStatePreviewHtml()}
          <div class="stack-12">
            ${renderBanner({ kind: 'info', title: 'Banner thông tin', text: 'Mẫu banner thông tin dùng trên các trang cấu hình.' })}
            ${renderBanner({ kind: 'warn', title: 'Banner cảnh báo', text: 'Mẫu banner cảnh báo nghiệp vụ (ví dụ snapshot gói).' })}
          </div>
        </section>
      </div>
    `;
  };

  const mount = () => {
    shell({
      section: 'design-system',
      contentHtml: renderContent(),
    });

    root.querySelectorAll('[data-ds-mode]').forEach((btn) => {
      btn.onclick = () => {
        viewMode = btn.dataset.dsMode || 'both';
        mount();
      };
    });

    root.querySelectorAll('[data-ds-tab]').forEach((btn) => {
      btn.onclick = () => {
        activeTab = btn.dataset.dsTab || 'ALL';
        mount();
      };
    });

    root.querySelectorAll('[data-ds-state]').forEach((btn) => {
      btn.onclick = () => {
        statePreview = btn.dataset.dsState || 'empty';
        mount();
      };
    });

    const toggleEl = root.querySelector('#ds-toggle-sample');
    if (toggleEl) {
      toggleEl.onchange = () => {
        toggleChecked = Boolean(toggleEl.checked);
      };
    }

    bindDatePickers(root, {});
    bindDateRangePicker(root, { id: 'ds-range' });
    bindMultiSelects(root, {
      onChange: ({ values }) => {
        toast(`Đã chọn ${values.length} loại gói`, 'info');
      },
    });
    bindSelectDropdowns(root, {
      onChange: ({ label }) => {
        toast(`Trạng thái đã chọn: ${label}`, 'info');
      },
    });

    root.querySelectorAll('[data-ds-preset]').forEach((btn) => {
      btn.onclick = () => {
        root.querySelectorAll('[data-ds-preset]').forEach((b) => b.classList?.remove('active'));
        btn.classList?.add('active');
        const range = computeDatePreset(btn.dataset.dsPreset);
        setDatePickerValue(root, 'ds-from', range.from);
        setDatePickerValue(root, 'ds-to', range.to);
      };
    });

    bindDataTableSelection(root, {
      onSelectionChange: (ids) => {
        selectedRows = rowsState.filter((r) => ids.includes(r.id));
        const expBtn = root.querySelector('#ds-export-btn');
        if (expBtn) {
          expBtn.innerHTML = `${icon('download', 15)} Xuất Excel${selectedRows.length ? ` (${selectedRows.length})` : ''}`;
        }
      },
    });

    bindPagination(root, {
      onPageChange: (nextPage) => {
        samplePage = nextPage;
        mount();
      },
      onPageSizeChange: (nextSize) => {
        samplePageSize = nextSize;
        samplePage = 1;
        mount();
      },
    });

    root.querySelectorAll('[data-ds-switch]').forEach((btn) => {
      btn.onclick = () => {
        const target = rowsState.find((r) => r.id === btn.dataset.dsSwitch);
        if (!target) return;
        target.status = target.status === 'ACTIVE' ? 'DISABLED' : 'ACTIVE';
        toast(`Đã đổi trạng thái ${target.name} thành ${target.status}`, 'success');
        mount();
      };
    });

    root.querySelectorAll('[data-ds-detail]').forEach((btn) => {
      btn.onclick = () => {
        const target = rowsState.find((r) => r.id === btn.dataset.dsDetail);
        if (!target) return;
        openDrawer({
          title: target.name,
          subtitle: target.email,
          bodyHtml: `<div class="impact-box">
            <div class="impact-row"><span class="impact-key">Vai trò</span><span class="impact-val">${esc(target.role)}</span></div>
            <div class="impact-row"><span class="impact-key">Trạng thái</span><span class="impact-val">${statusBadge(target.status)}</span></div>
            <div class="impact-row"><span class="impact-key">Số tiền</span><span class="impact-val tabular">${vnd(target.amount)}</span></div>
          </div>`,
        });
      };
    });

    const filterModalBtn = root.querySelector('#ds-filter-modal-btn');
    if (filterModalBtn) {
      filterModalBtn.onclick = () => {
        openModal({
          title: 'Bộ lọc nâng cao (Mẫu)',
          maxWidth: '480px',
          bodyHtml: `<div class="meta-modal-body">
            <div class="field">
              <label class="field-label" for="ds-mf-status">Trạng thái</label>
              <select id="ds-mf-status" class="form-select">
                <option value="">Tất cả trạng thái</option>
                <option value="ACTIVE">Đang hoạt động (ACTIVE)</option>
                <option value="DISABLED">Bị khóa (DISABLED)</option>
              </select>
            </div>
            <div class="field">
              <span class="field-label">Thời gian</span>
              <div class="desktop-filters">
                <div class="date-preset-grid" style="grid-template-columns:repeat(3,minmax(0,1fr));margin-bottom:10px">
                  ${DATE_PRESETS.map((p) => `<button type="button" class="date-preset-btn" data-preset="${p.id}">${esc(p.label)}</button>`).join('')}
                </div>
                <div class="grid-2">
                  <div class="date-range-field" style="min-width:0">
                    <label class="date-range-label" for="ds-mf-from-trigger">Từ ngày</label>
                    ${renderDateInput({ id: 'ds-mf-from', value: weekAgo, ariaLabel: 'Từ ngày' })}
                  </div>
                  <div class="date-range-field" style="min-width:0">
                    <label class="date-range-label" for="ds-mf-to-trigger">Đến ngày</label>
                    ${renderDateInput({ id: 'ds-mf-to', value: today, ariaLabel: 'Đến ngày' })}
                  </div>
                </div>
              </div>
              <div class="mobile-filters">
                ${renderDateRangePicker({ id: 'ds-mf-range', from: weekAgo, to: today })}
              </div>
            </div>
            <div class="field">
              <span class="field-label">Tùy chọn nhanh</span>
              <div class="filter-check-group">
                <label class="filter-check"><input type="checkbox" checked /><span>Có gói Gym</span></label>
                <label class="filter-check"><input type="checkbox" /><span>Đang thuê Coach</span></label>
              </div>
            </div>
          </div>`,
          footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Đóng</button>
            <button type="button" class="btn btn-primary" data-close-modal>Áp dụng</button>`,
          onMount: (modal) => {
            const dlg = modal?.dialog;
            if (!dlg) return;
            bindDatePickers(dlg, {});
            bindDateRangePicker(dlg, {
              id: 'ds-mf-range',
              onChange: ({ from, to }) => {
                setDatePickerValue(dlg, 'ds-mf-from', from);
                setDatePickerValue(dlg, 'ds-mf-to', to);
              },
            });
            dlg.querySelectorAll('[data-preset]').forEach((pBtn) => {
              pBtn.onclick = () => {
                dlg.querySelectorAll('[data-preset]').forEach((b) => b.classList?.remove('active'));
                pBtn.classList?.add('active');
                const range = computeDatePreset(pBtn.dataset.preset);
                setDatePickerValue(dlg, 'ds-mf-from', range.from);
                setDatePickerValue(dlg, 'ds-mf-to', range.to);
              };
            });
          },
        });
      };
    }

    const exportBtn = root.querySelector('#ds-export-btn');
    if (exportBtn) {
      exportBtn.onclick = () => {
        const list = selectedRows.length ? selectedRows : rowsState;
        exportToExcel({
          filename: 'metagym-design-sample',
          columns: [
            { label: 'Họ tên', value: (r) => r.name },
            { label: 'Email', value: (r) => r.email },
            { label: 'Trạng thái', value: (r) => r.status },
            { label: 'Số tiền', value: (r) => r.amount },
          ],
          rows: list,
        });
        toast(`Đã xuất ${list.length} dòng ra CSV/Excel.`, 'success');
      };
    }

    const modalBtn = root.querySelector('#ds-open-modal');
    if (modalBtn) {
      modalBtn.onclick = () => openModal({
        title: 'Mẫu Modal chuẩn Meta Gym',
        subtitle: 'Hỗ trợ phím Escape để đóng và giữ dữ liệu khi có lỗi.',
        maxWidth: '480px',
        bodyHtml: `<div class="meta-modal-body">
          <p style="margin:0;font-size:13.5px;color:var(--meta-text-secondary);line-height:1.5">Đây là khung Modal tiêu chuẩn dùng cho các biểu mẫu thêm/sửa dữ liệu trên hệ thống.</p>
          <div class="field">
            <label class="field-label" for="ds-modal-sample-input">Tên mẫu</label>
            <input id="ds-modal-sample-input" class="form-control" type="text" placeholder="Nhập nội dung mẫu..." />
          </div>
        </div>`,
        footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Đóng</button>
          <button type="button" class="btn btn-primary" data-close-modal>Đã hiểu</button>`,
      });
    }

    const confirmBtn = root.querySelector('#ds-open-confirm');
    if (confirmBtn) {
      confirmBtn.onclick = () => openConfirmModal({
        title: 'Xác nhận thao tác mẫu',
        message: 'Component bắt buộc nhập lý do trước khi thực thi hành động quan trọng.',
        requireReason: true,
        confirmLabel: 'Xác nhận mẫu',
        onConfirm: async (reason) => {
          toast(`Đã gửi thử nghiệm: ${reason}`, 'success');
        },
      });
    }

    const drawerBtn = root.querySelector('#ds-open-drawer');
    if (drawerBtn) {
      drawerBtn.onclick = () => openDrawer({
        title: 'Chi tiết hồ sơ mẫu',
        subtitle: 'Detail Drawer dùng chung',
        bodyHtml: `<div class="impact-box">
          <div class="impact-row"><span class="impact-key">Hội viên</span><span class="impact-val">Nguyễn Minh Quân</span></div>
          <div class="impact-row"><span class="impact-key">Trạng thái</span><span class="impact-val">${statusBadge('ACTIVE')}</span></div>
        </div>`,
      });
    }

    const alertSuccessBtn = root.querySelector('#ds-alert-success');
    if (alertSuccessBtn) {
      alertSuccessBtn.onclick = () => openAlertModal({
        kind: 'success',
        title: 'Hoàn tất thao tác',
        heading: 'Cập nhật gói tập thành công',
        message: 'Các giao dịch mới từ thời điểm này sẽ áp dụng mức giá và thời hạn vừa lưu.',
        hint: 'Gói hội viên đã mua trước đó vẫn giữ nguyên quyền lợi cũ.',
        confirmLabel: 'Hoàn tất',
      });
    }
    const alertWarnBtn = root.querySelector('#ds-alert-warn');
    if (alertWarnBtn) {
      alertWarnBtn.onclick = () => openAlertModal({
        kind: 'warn',
        title: 'Cảnh báo nghiệp vụ',
        heading: 'Coach đang có hội viên hoạt động',
        message: 'Thao tác này sẽ tạm đóng băng lịch tập sắp tới của 3 hội viên đang theo học.',
        hint: 'Bạn có thể chuyển Coach hoặc hoàn tiền cho hội viên ở mục Sự cố Coach.',
        cancelLabel: 'Hủy',
        confirmLabel: 'Đã hiểu',
      });
    }
    const alertDangerBtn = root.querySelector('#ds-alert-danger');
    if (alertDangerBtn) {
      alertDangerBtn.onclick = () => openAlertModal({
        kind: 'danger',
        title: 'Lỗi hệ thống',
        heading: 'Không thể kết nối máy chủ',
        message: 'Yêu cầu tạm thời bị gián đoạn hoặc phiên làm việc đã hết hạn.',
        hint: 'Kiểm tra lại kết nối mạng rồi bấm Thử lại.',
        cancelLabel: 'Đóng',
        confirmLabel: 'Thử lại',
        onConfirm: () => toast('Đang thử kết nối lại...', 'info'),
      });
    }
    const alertInfoBtn = root.querySelector('#ds-alert-info');
    if (alertInfoBtn) {
      alertInfoBtn.onclick = () => openAlertModal({
        kind: 'info',
        title: 'Thông báo hệ thống',
        heading: 'Đã đồng bộ dữ liệu vận hành',
        message: 'Toàn bộ số liệu doanh thu và quyền lợi gói đã được cập nhật theo thời gian thực.',
        confirmLabel: 'Đóng',
      });
    }

    const toastBtn = root.querySelector('#ds-open-toast');
    if (toastBtn) {
      toastBtn.onclick = () => toast('Thao tác thành công (tự gom lặp ×2, ×3).', 'success');
    }
    const toastWarnBtn = root.querySelector('#ds-open-toast-warn');
    if (toastWarnBtn) {
      toastWarnBtn.onclick = () => toast('Cảnh báo: Gói sắp hết hạn hoặc đang tạm ngưng.', 'warn');
    }
    const toastDangerBtn = root.querySelector('#ds-open-toast-danger');
    if (toastDangerBtn) {
      toastDangerBtn.onclick = () => toast('Lỗi: Không thể thực hiện thao tác.', 'danger');
    }
    const toastInfoBtn = root.querySelector('#ds-open-toast-info');
    if (toastInfoBtn) {
      toastInfoBtn.onclick = () => toast('Thông tin: Đã đồng bộ dữ liệu mới nhất.', 'info');
    }
  };

  mount();
}
