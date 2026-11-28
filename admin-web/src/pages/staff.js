import { api, buildQuery } from '../services/api.js';
import { esc, formatDateTimeVN, initials, statusBadge } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderDataTable } from '../components/data-table.js';
import { openConfirmModal, openModal } from '../components/modal.js';
import { bindPagination, renderPagination } from '../components/pagination.js';
import { renderBanner, renderEmptyState, renderErrorState, renderSkeletonPage } from '../components/states.js';
import { toast } from '../components/toast.js';
import { NAV_GROUPS } from '../components/layout.js';
import { FRONTEND_POSITION_PERMISSIONS, POSITION_LABELS, hasPermission } from '../services/permissions.js';
import { updateQuery } from '../state/router.js';

const POSITION_BADGE_MAP = Object.freeze({
  ADMIN: 'meta-badge-coral',
  MANAGER: 'meta-badge-warning',
  RECEPTIONIST: 'meta-badge-info',
  COACH: 'meta-badge-success',
  TECHNICIAN: 'meta-badge-neutral',
});

const POSITION_KPI_ACCENT = Object.freeze({
  ADMIN: 'is-coral',
  MANAGER: 'is-warning',
  RECEPTIONIST: 'is-info',
  COACH: 'is-success',
  TECHNICIAN: 'is-neutral',
});

function positionBadgeHtml(code, label = null) {
  const cls = POSITION_BADGE_MAP[code] || 'meta-badge-neutral';
  return `<span class="meta-badge ${cls}">${esc(label || POSITION_LABELS[code] || code)}</span>`;
}

function renderStaffSubnav(activeTab) {
  const tabs = [
    { key: 'directory', label: 'Danh sách nhân sự', icon: 'users' },
    { key: 'positions', label: 'Vị trí & Phân quyền Sidebar', icon: 'shield' },
  ];
  return `<nav class="media-subnav" role="tablist" aria-label="Phân mục nhân sự">
    ${tabs.map((t) => {
      const selected = activeTab === t.key;
      return `<button type="button" class="media-subnav-btn" role="tab" aria-selected="${selected ? 'true' : 'false'}" data-staff-tab="${esc(t.key)}">
        ${icon(t.icon, 16)} <span>${esc(t.label)}</span>
      </button>`;
    }).join('')}
  </nav>`;
}

export async function renderStaffPage({ root, params, shell }) {
  const canManage = hasPermission('staff:manage');
  const activeTab = params.get('tab') === 'positions' ? 'positions' : 'directory';
  const positionFilter = (params.get('position') || 'ALL').toUpperCase();
  const statusFilter = (params.get('status') || 'ALL').toUpperCase();
  const searchQuery = params.get('search') || '';
  const page = Math.max(1, Number(params.get('page') || 1));
  const previewPos = (params.get('preview') || 'MANAGER').toUpperCase();

  shell({
    section: 'staff',
    topbarActionsHtml: canManage
      ? `<button type="button" class="btn btn-primary btn-sm" id="add-staff-btn">${icon('plus', 15)} Thêm nhân sự</button>`
      : '',
    contentHtml: renderSkeletonPage({ cards: 5, rows: 6 }),
  });

  const refresh = () => renderStaffPage({ root, params, shell });

  const openCreateModal = () => {
    openModal({
      title: 'Thêm nhân sự phòng tập',
      maxWidth: '540px',
      bodyHtml: `<form id="create-staff-form" class="stack-16" novalidate>
        <div id="create-staff-error"></div>
        <div class="field">
          <label class="field-label" for="staff-pos">Vị trí công việc</label>
          <select id="staff-pos" class="form-select" name="position">
            <option value="MANAGER">Quản lý vận hành / Trưởng ca</option>
            <option value="RECEPTIONIST" selected>Lễ tân & Thu ngân</option>
            <option value="COACH">Huấn luyện viên (Coach)</option>
            <option value="TECHNICIAN">Kỹ thuật viên & Nội dung</option>
          </select>
        </div>
        <div class="grid-2">
          <div class="field">
            <label class="field-label" for="staff-name">Họ và tên</label>
            <input id="staff-name" class="form-control" name="fullName" required placeholder="Nguyễn Văn A" />
          </div>
          <div class="field">
            <label class="field-label" for="staff-phone">Số điện thoại</label>
            <input id="staff-phone" class="form-control" name="phone" placeholder="0901234567" />
          </div>
        </div>
        <div class="grid-2">
          <div class="field">
            <label class="field-label" for="staff-email">Email đăng nhập</label>
            <input id="staff-email" class="form-control" type="email" name="email" required placeholder="nhanvien@metagym.vn" />
          </div>
          <div class="field">
            <label class="field-label" for="staff-pass">Mật khẩu khởi tạo</label>
            <input id="staff-pass" class="form-control" type="password" name="password" required placeholder="Tối thiểu 8 ký tự có hoa, số" />
          </div>
        </div>
        <div class="grid-2">
          <div class="field">
            <label class="field-label" for="staff-dept">Bộ phận</label>
            <input id="staff-dept" class="form-control" name="department" placeholder="Quầy lễ tân / Điều hành" />
          </div>
          <div class="field">
            <label class="field-label" for="staff-shift">Ca làm việc / Ghi chú</label>
            <input id="staff-shift" class="form-control" name="shiftNote" placeholder="Ca sáng 06:00 – 14:00" />
          </div>
        </div>
      </form>`,
      footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
        <button type="submit" form="create-staff-form" class="btn btn-primary" id="create-staff-submit">${icon('check', 16)} Tạo tài khoản</button>`,
      onMount: (modal) => {
        const form = modal.dialog.querySelector('#create-staff-form');
        const errBox = modal.dialog.querySelector('#create-staff-error');
        const submitBtn = modal.dialog.querySelector('#create-staff-submit');
        form.onsubmit = async (e) => {
          e.preventDefault();
          errBox.innerHTML = '';
          const payload = {
            position: form.querySelector('[name="position"]').value,
            fullName: form.querySelector('[name="fullName"]').value.trim(),
            phone: form.querySelector('[name="phone"]').value.trim() || null,
            email: form.querySelector('[name="email"]').value.trim(),
            password: form.querySelector('[name="password"]').value,
            ...(form.querySelector('[name="department"]').value.trim() ? { department: form.querySelector('[name="department"]').value.trim() } : {}),
            ...(form.querySelector('[name="shiftNote"]').value.trim() ? { shiftNote: form.querySelector('[name="shiftNote"]').value.trim() } : {}),
          };
          submitBtn.disabled = true;
          try {
            await api('/admin/staff', 'POST', payload);
            toast('Đã thêm tài khoản nhân sự mới.');
            modal.close();
            await refresh();
          } catch (err) {
            errBox.innerHTML = renderBanner({ kind: 'danger', title: 'Không tạo được nhân sự', text: err.message });
          } finally {
            submitBtn.disabled = false;
          }
        };
      },
    });
  };

  try {
    const posRes = await api('/admin/staff-positions');
    const positions = posRes?.data?.positions || [];

    const summaryCardsHtml = `<div class="kpi-grid staff-kpi-grid">
      ${positions.map((p) => {
        const accent = POSITION_KPI_ACCENT[p.code] || 'is-neutral';
        const isCoachApp = p.code === 'COACH';
        return `<button type="button" class="kpi-card ${accent} staff-pos-kpi ${positionFilter === p.code && activeTab === 'directory' ? 'is-selected' : ''}" data-filter-pos="${esc(p.code)}" title="${esc(`${p.title} · ${p.portal}`)}">
          <div class="staff-kpi-info">
            <span class="staff-kpi-dot" aria-hidden="true"></span>
            <span class="staff-kpi-name">${esc(p.shortTitle)}</span>
            <span class="staff-kpi-portal">${isCoachApp ? 'Mobile' : 'Web'}</span>
          </div>
          <span class="staff-kpi-count tabular">${p.activeCount ?? 0}<small>/${p.totalCount ?? 0}</small></span>
        </button>`;
      }).join('')}
    </div>`;

    let bodyHtml = '';

    if (activeTab === 'positions') {
      const previewPerms = FRONTEND_POSITION_PERMISSIONS[previewPos] || [];
      const previewMockUser = previewPos === 'ADMIN'
        ? { role: 'ADMIN', permissions: ['*'] }
        : previewPos === 'COACH'
          ? { role: 'COACH', permissions: ['mobile:coach'] }
          : { role: 'STAFF', staffPosition: previewPos, permissions: previewPerms };

      const previewGroups = NAV_GROUPS.map((group) => ({
        ...group,
        items: group.items.filter((item) => hasPermission(item.permission, previewMockUser)),
      })).filter((g) => g.items.length > 0);

      bodyHtml = `<div class="stack-20">
        <section class="meta-card stack-16">
          <div class="card-header-row" style="margin-bottom:0">
            <div>
              <h2 class="card-title-text">Phân cấp 5 vị trí nhân viên MetaGym</h2>
              <p class="card-sub">Thứ tự ưu tiên menu Sidebar thay đổi tự động theo đúng quyền hạn và cổng làm việc của từng vị trí.</p>
            </div>
            <span class="meta-badge meta-badge-neutral tabular">${positions.length} vị trí chính thức</span>
          </div>
          <div class="staff-positions-grid">
            ${positions.map((p) => {
              const accent = POSITION_KPI_ACCENT[p.code] || 'is-neutral';
              return `<article class="staff-position-card ${accent}">
                <div class="staff-pos-card-head">
                  <div class="staff-pos-card-badges">
                    <span class="staff-step-num tabular">0${p.priority}</span>
                    ${positionBadgeHtml(p.code, p.shortTitle)}
                  </div>
                  <span class="staff-active-count tabular"><strong>${p.activeCount ?? 0}</strong> hoạt động</span>
                </div>
                <div class="staff-pos-card-body">
                  <h3 class="staff-pos-card-title">${esc(p.title)}</h3>
                  <div class="staff-portal-chip">${icon('globe', 13)} <span>${esc(p.portal)}</span></div>
                  <p class="staff-pos-card-desc">${esc(p.description)}</p>
                </div>
                <div class="staff-pos-card-foot">
                  <div class="staff-pos-foot-label">Phạm vi chính</div>
                  <ul class="staff-highlight-list">
                    ${(p.sidebarHighlights || []).map((line) => `<li>${esc(line)}</li>`).join('')}
                  </ul>
                </div>
              </article>`;
            }).join('')}
          </div>
        </section>

        <section class="meta-card stack-16">
          <div class="card-header-row" style="margin-bottom:0">
            <div>
              <h2 class="card-title-text">Xem trước thứ tự Sidebar theo vị trí</h2>
              <p class="card-sub">Chọn vị trí để kiểm tra các nhóm menu hiển thị theo mức độ ưu tiên từ trên xuống dưới.</p>
            </div>
            <div class="chart-segmented staff-preview-seg" role="group" aria-label="Chọn vị trí xem trước Sidebar">
              ${positions.map((p) => `<button type="button" class="chart-seg-btn ${previewPos === p.code ? 'active' : ''}" data-preview-pos="${esc(p.code)}">${esc(p.shortTitle)}</button>`).join('')}
            </div>
          </div>
          ${previewPos === 'COACH'
            ? renderBanner({
                kind: 'info',
                iconName: 'award',
                title: 'Huấn luyện viên (Coach) sử dụng ứng dụng Mobile riêng',
                text: 'Tài khoản Coach bị chặn đăng nhập Web Admin và được quản lý trực tiếp bởi Quản trị viên / Quản lý tại mục Nhân sự & Huấn luyện viên.',
              })
            : `<div class="staff-preview-grid">
                ${previewGroups.map((group, idx) => `<div class="staff-preview-card">
                  <div class="staff-preview-head">
                    <span class="staff-step-num tabular">${String(idx + 1).padStart(2, '0')}</span>
                    <span class="staff-preview-group-title">${esc(group.label)}</span>
                    <span class="staff-preview-count tabular">${group.items.length}</span>
                  </div>
                  <div class="staff-preview-list">
                    ${group.items.map((item) => `<div class="staff-preview-item">
                      ${icon(item.icon, 15)}
                      <span class="nav-item-label">${esc(item.label)}</span>
                    </div>`).join('')}
                  </div>
                </div>`).join('')}
              </div>`}
        </section>
      </div>`;
    } else {
      const listRes = await api(`/admin/staff${buildQuery({
        position: positionFilter,
        status: statusFilter,
        search: searchQuery,
        page,
        pageSize: 20,
      })}`);
      const rows = listRes?.data || [];
      const pagination = listRes?.pagination || { page: 1, pageSize: 20, totalItems: rows.length, totalPages: 1 };

      const filterBarHtml = `<section class="meta-card stack-16">
        <div class="filter-bar">
          <div class="field" style="flex:1 1 240px">
            <label class="field-label" for="staff-search">Tìm kiếm nhân sự</label>
            <input id="staff-search" class="form-control" placeholder="Họ tên, email, SĐT, bộ phận..." value="${esc(searchQuery)}" />
          </div>
          <div class="field" style="min-width:190px">
            <label class="field-label" for="staff-pos-filter">Vị trí nhân viên</label>
            <select id="staff-pos-filter" class="form-select">
              <option value="ALL" ${positionFilter === 'ALL' ? 'selected' : ''}>Tất cả vị trí</option>
              ${positions.map((p) => `<option value="${esc(p.code)}" ${positionFilter === p.code ? 'selected' : ''}>${esc(p.shortTitle)}</option>`).join('')}
            </select>
          </div>
          <div class="field" style="min-width:150px">
            <label class="field-label" for="staff-status-filter">Trạng thái</label>
            <select id="staff-status-filter" class="form-select">
              <option value="ALL" ${statusFilter === 'ALL' ? 'selected' : ''}>Tất cả</option>
              <option value="ACTIVE" ${statusFilter === 'ACTIVE' ? 'selected' : ''}>Đang hoạt động</option>
              <option value="DISABLED" ${statusFilter === 'DISABLED' ? 'selected' : ''}>Đã khóa</option>
            </select>
          </div>
          <div style="display:flex;align-items:flex-end;gap:8px">
            <button type="button" class="btn btn-graphite" id="staff-filter-apply">${icon('search', 16)} Lọc</button>
          </div>
        </div>
      </section>`;

      const tableHtml = rows.length
        ? renderDataTable({
            columns: [
              {
                label: 'Nhân viên',
                render: (row) => `<div class="person-cell">
                  <span class="meta-avatar">${esc(initials(row.fullName, 'NV'))}</span>
                  <div>
                    <div class="person-name">${esc(row.fullName)}</div>
                    <div class="person-sub">${esc(row.email)}${row.phone ? ` · ${esc(row.phone)}` : ''}</div>
                  </div>
                </div>`,
              },
              {
                label: 'Vị trí & Bộ phận',
                render: (row) => `<div class="stack-4">
                  <div>${positionBadgeHtml(row.position, row.positionShortTitle)}</div>
                  <span class="person-sub">${esc(row.department || row.portal)}</span>
                </div>`,
              },
              {
                label: 'Ca làm / Phân công',
                render: (row) => row.role === 'COACH'
                  ? `<span class="tabular" style="font-size:13px">${row.usedSlots ?? 0}/8 hội viên</span>`
                  : `<span style="font-size:13px;color:var(--meta-text-secondary)">${esc(row.shiftNote || row.portal)}</span>`,
              },
              {
                label: 'Trạng thái',
                render: (row) => `${statusBadge(row.status)}<div class="person-sub tabular">${row.lastLoginAt ? `Đăng nhập ${formatDateTimeVN(row.lastLoginAt)}` : 'Chưa đăng nhập'}</div>`,
              },
              {
                label: 'Thao tác',
                align: 'right',
                render: (row) => {
                  if (row.role === 'ADMIN') {
                    return `<span class="person-sub">Chủ hệ thống</span>`;
                  }
                  if (row.role === 'COACH') {
                    return `<a class="btn btn-graphite btn-sm" href="#/admin/coaches?search=${encodeURIComponent(row.email)}">${icon('award', 14)} Quản lý Coach</a>`;
                  }
                  if (!canManage) return `<span class="person-sub">Chỉ xem</span>`;
                  return `<div class="row-actions">
                    <button type="button" class="btn btn-graphite btn-sm edit-staff-btn" data-id="${esc(row.id)}">${icon('edit', 14)} Sửa</button>
                    <button type="button" class="btn btn-graphite btn-sm reset-staff-pw-btn" data-id="${esc(row.id)}" title="Cấp mật khẩu tạm">${icon('key', 14)}</button>
                    <button type="button" class="btn ${row.status === 'ACTIVE' ? 'btn-danger' : 'btn-success'} btn-sm toggle-staff-status-btn" data-id="${esc(row.id)}">${row.status === 'ACTIVE' ? 'Khóa' : 'Mở'}</button>
                  </div>`;
                },
              },
            ],
            rows,
          })
        : renderEmptyState({
            iconName: 'users',
            title: 'Chưa có nhân sự khớp bộ lọc',
            message: 'Nhấn "Thêm nhân sự" để tạo tài khoản Quản lý vận hành, Lễ tân / Thu ngân hoặc Kỹ thuật viên.',
            actionHtml: canManage ? `<button type="button" class="btn btn-primary btn-sm" id="staff-empty-add">${icon('plus', 15)} Thêm nhân sự</button>` : '',
          });

      bodyHtml = `<div class="stack-20">
        ${filterBarHtml}
        <section class="meta-card stack-12">
          ${tableHtml}
          ${renderPagination(pagination)}
        </section>
      </div>`;

      // Bind handlers cleanly after shell renders
      setTimeout(() => {}, 0);
      shell({
        section: 'staff',
        topbarActionsHtml: canManage
          ? `<button type="button" class="btn btn-primary btn-sm" id="add-staff-btn">${icon('plus', 15)} Thêm nhân sự</button>`
          : '',
        contentHtml: `<div class="stack-20">
          ${renderStaffSubnav(activeTab)}
          ${summaryCardsHtml}
          ${bodyHtml}
        </div>`,
      });

      const byId = new Map(rows.map((r) => [r.id, r]));
      root.querySelectorAll('.edit-staff-btn').forEach((btn) => {
        btn.onclick = () => {
          const item = byId.get(btn.dataset.id);
          if (!item) return;
          openModal({
            title: `Cập nhật nhân sự · ${item.fullName}`,
            maxWidth: '500px',
            bodyHtml: `<form id="edit-staff-form" class="stack-16" novalidate>
              <div id="edit-staff-error"></div>
              <div class="field">
                <label class="field-label" for="edit-staff-pos">Vị trí nhân viên</label>
                <select id="edit-staff-pos" class="form-select" name="position">
                  <option value="MANAGER" ${item.position === 'MANAGER' ? 'selected' : ''}>Quản lý vận hành / Trưởng ca</option>
                  <option value="RECEPTIONIST" ${item.position === 'RECEPTIONIST' ? 'selected' : ''}>Lễ tân & Thu ngân</option>
                  <option value="TECHNICIAN" ${item.position === 'TECHNICIAN' ? 'selected' : ''}>Kỹ thuật viên & Nội dung</option>
                </select>
              </div>
              <div class="grid-2">
                <div class="field">
                  <label class="field-label" for="edit-staff-name">Họ và tên</label>
                  <input id="edit-staff-name" class="form-control" name="fullName" value="${esc(item.fullName)}" required />
                </div>
                <div class="field">
                  <label class="field-label" for="edit-staff-phone">Số điện thoại</label>
                  <input id="edit-staff-phone" class="form-control" name="phone" value="${esc(item.phone || '')}" />
                </div>
              </div>
              <div class="field">
                <label class="field-label" for="edit-staff-dept">Bộ phận</label>
                <input id="edit-staff-dept" class="form-control" name="department" value="${esc(item.department || '')}" />
              </div>
              <div class="field">
                <label class="field-label" for="edit-staff-shift">Ca làm việc / Ghi chú</label>
                <input id="edit-staff-shift" class="form-control" name="shiftNote" value="${esc(item.shiftNote || '')}" />
              </div>
            </form>`,
            footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
              <button type="submit" form="edit-staff-form" class="btn btn-primary" id="edit-staff-save">${icon('check', 16)} Lưu thay đổi</button>`,
            onMount: (modal) => {
              const form = modal.dialog.querySelector('#edit-staff-form');
              const errBox = modal.dialog.querySelector('#edit-staff-error');
              const saveBtn = modal.dialog.querySelector('#edit-staff-save');
              form.onsubmit = async (e) => {
                e.preventDefault();
                errBox.innerHTML = '';
                saveBtn.disabled = true;
                try {
                  await api(`/admin/staff/${item.id}`, 'PATCH', {
                    position: form.querySelector('[name="position"]').value,
                    fullName: form.querySelector('[name="fullName"]').value.trim(),
                    phone: form.querySelector('[name="phone"]').value.trim() || null,
                    department: form.querySelector('[name="department"]').value.trim(),
                    shiftNote: form.querySelector('[name="shiftNote"]').value.trim() || null,
                  });
                  toast('Đã cập nhật vị trí và thông tin nhân sự.');
                  modal.close();
                  await refresh();
                } catch (err) {
                  errBox.innerHTML = renderBanner({ kind: 'danger', title: 'Cập nhật thất bại', text: err.message });
                } finally {
                  saveBtn.disabled = false;
                }
              };
            },
          });
        };
      });

      root.querySelectorAll('.reset-staff-pw-btn').forEach((btn) => {
        btn.onclick = () => {
          const item = byId.get(btn.dataset.id);
          if (!item) return;
          openConfirmModal({
            title: `Cấp mật khẩu tạm cho ${item.fullName}`,
            message: 'Phiên đăng nhập hiện tại của nhân viên sẽ bị thu hồi ngay lập tức.',
            confirmLabel: 'Cấp mật khẩu tạm',
            confirmVariant: 'btn-primary',
            onConfirm: async () => {
              const res = await api(`/admin/staff/${item.id}/password-resets`, 'POST', {});
              openModal({
                title: 'Mật khẩu tạm một lần',
                maxWidth: '460px',
                bodyHtml: `<div class="stack-12">
                  <p style="margin:0;color:var(--meta-text-secondary)">${esc(res.data.reminder)}</p>
                  <div class="meta-card-raised" style="padding:14px;font-family:monospace;font-size:18px;font-weight:700;text-align:center;letter-spacing:0.06em">${esc(res.data.temporaryPassword)}</div>
                </div>`,
                footerHtml: `<button type="button" class="btn btn-primary" data-close-modal>Đã lưu</button>`,
              });
            },
          });
        };
      });

      root.querySelectorAll('.toggle-staff-status-btn').forEach((btn) => {
        btn.onclick = () => {
          const item = byId.get(btn.dataset.id);
          if (!item) return;
          const isLock = item.status === 'ACTIVE';
          openConfirmModal({
            title: isLock ? `Khóa tài khoản ${item.fullName}` : `Mở khóa tài khoản ${item.fullName}`,
            message: isLock
              ? 'Nhân sự sẽ bị thu hồi phiên đăng nhập Web Admin ngay lập tức.'
              : 'Khôi phục quyền đăng nhập Web Admin theo đúng vị trí đã phân công.',
            requireReason: isLock,
            reasonLabel: 'Lý do khóa tài khoản',
            confirmLabel: isLock ? 'Xác nhận khóa' : 'Mở khóa',
            confirmVariant: isLock ? 'btn-danger' : 'btn-success',
            onConfirm: async ({ reason }) => {
              await api(`/admin/staff/${item.id}`, 'PATCH', {
                status: isLock ? 'DISABLED' : 'ACTIVE',
                ...(isLock ? { reason } : {}),
              });
              toast(isLock ? 'Đã khóa tài khoản nhân sự.' : 'Đã mở khóa tài khoản nhân sự.');
              await refresh();
            },
          });
        };
      });

      const applySearch = () => {
        updateQuery({
          tab: activeTab === 'positions' ? 'positions' : '',
          position: root.querySelector('#staff-pos-filter')?.value || 'ALL',
          status: root.querySelector('#staff-status-filter')?.value || 'ALL',
          search: root.querySelector('#staff-search')?.value?.trim() || '',
          page: 1,
        }, { replace: false });
      };
      const applyBtn = root.querySelector('#staff-filter-apply');
      if (applyBtn) applyBtn.onclick = applySearch;
      root.querySelector('#staff-pos-filter')?.addEventListener('change', applySearch);
      root.querySelector('#staff-status-filter')?.addEventListener('change', applySearch);
      root.querySelector('#staff-search')?.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          e.preventDefault();
          applySearch();
        }
      });
      bindPagination(root, (nextPage) => updateQuery({ page: nextPage }, { replace: false }));
      const emptyAdd = root.querySelector('#staff-empty-add');
      if (emptyAdd) emptyAdd.onclick = openCreateModal;
    }

    if (activeTab === 'positions') {
      shell({
        section: 'staff',
        topbarActionsHtml: canManage
          ? `<button type="button" class="btn btn-primary btn-sm" id="add-staff-btn">${icon('plus', 15)} Thêm nhân sự</button>`
          : '',
        contentHtml: `<div class="stack-20">
          ${renderStaffSubnav(activeTab)}
          ${summaryCardsHtml}
          ${bodyHtml}
        </div>`,
      });
      root.querySelectorAll('[data-preview-pos]').forEach((btn) => {
        btn.onclick = () => updateQuery({ tab: 'positions', preview: btn.dataset.previewPos }, { replace: false });
      });
    }

    root.querySelectorAll('[data-staff-tab]').forEach((btn) => {
      btn.onclick = () => {
        const nextTab = btn.dataset.staffTab;
        updateQuery({ tab: nextTab === 'positions' ? 'positions' : '', page: '' }, { replace: false });
      };
    });
    root.querySelectorAll('[data-filter-pos]').forEach((btn) => {
      btn.onclick = () => {
        updateQuery({ tab: '', position: btn.dataset.filterPos, page: 1 }, { replace: false });
      };
    });
    const addBtn = root.querySelector('#add-staff-btn');
    if (addBtn) addBtn.onclick = openCreateModal;
  } catch (error) {
    shell({
      section: 'staff',
      contentHtml: renderErrorState({ title: 'Không tải được dữ liệu nhân sự', message: error.message }),
    });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = refresh;
  }
}
