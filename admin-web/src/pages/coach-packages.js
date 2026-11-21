import { api, buildQuery } from '../services/api.js';
import { debounce, esc, formatDateVN, initials, statusBadge, vnd } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderDataTable } from '../components/data-table.js';
import { openModal } from '../components/modal.js';
import { bindPagination, renderPagination } from '../components/pagination.js';
import {
  renderBanner,
  renderEmptyState,
  renderErrorState,
  renderFilterEmptyState,
  renderSkeletonPage,
} from '../components/states.js';
import { notice } from '../components/toast.js';
import { renderToggle } from '../components/toggle.js';
import { updateQuery } from '../state/router.js';

const CODE_REGEX = /^[A-Z0-9][A-Z0-9_-]{1,39}$/;
const COACH_SNAPSHOT_BANNER = 'Thay đổi chỉ áp dụng cho giao dịch mới; gói đã mua/QUEUED giữ nguyên snapshot. Mỗi buổi chuẩn 90 phút; tối đa 1 gói QUEUED nối tiếp mỗi hội viên.';

const CLOSE_REASON_LABELS = {
  COMPLETED_SESSIONS: 'Hoàn thành đủ buổi',
  EXPIRED: 'Hết hạn sử dụng',
  EARLY_TERMINATION: 'Kết thúc sớm (D5)',
  TRANSFERRED: 'Đã chuyển Coach (D2)',
  SIMULATED_REFUND: 'Hoàn tiền mô phỏng (D3)',
};

function openCoachPackageModal(row, onSaved) {
  const isEdit = Boolean(row);
  openModal({
    title: isEdit ? `Sửa gói Coach: ${row.name}` : 'Tạo gói Coach mới (Danh mục mở)',
    subtitle: isEdit
      ? `Mã gói ${row.code} · Sửa đầy đủ tên, mô tả, số buổi, số ngày, giá VND và trạng thái`
      : 'Không giới hạn 3 mã cố định · Mã gói dạng chữ in hoa, số, gạch dưới hoặc gạch nối',
    bodyHtml: `<form id="coach-pkg-form" novalidate>
      <div class="meta-modal-body">
        ${renderBanner({
          kind: 'info',
          iconName: 'award',
          title: 'Quy tắc Snapshot gói Coach',
          text: COACH_SNAPSHOT_BANNER,
        })}
        ${isEdit ? `<div class="impact-box">
          <div class="impact-row"><span class="impact-key">Mã gói (bất biến)</span><span class="impact-val"><span class="meta-badge meta-badge-info tabular">${esc(row.code)}</span></span></div>
        </div>` : `<div class="field">
          <label class="field-label" for="cp-code">Mã gói (Code)</label>
          <input id="cp-code" class="form-control tabular" name="code" maxlength="40" placeholder="Ví dụ: PRO_40" required />
          <span class="field-hint">Định dạng 2–40 ký tự: bắt đầu bằng chữ in hoa/số, chỉ gồm A–Z, 0–9, _ hoặc - (ví dụ PRO_40).</span>
        </div>`}
        <div class="field">
          <label class="field-label" for="cp-name">Tên gói Coach</label>
          <input id="cp-name" class="form-control" name="name" maxlength="100" value="${esc(row?.name || '')}" placeholder="Ví dụ: Chuyên sâu 40 buổi" required />
        </div>
        <div class="field">
          <label class="field-label" for="cp-desc">Mô tả lộ trình</label>
          <textarea id="cp-desc" class="form-control" name="description" maxlength="1000" placeholder="Mô tả quyền lợi, giáo án 1–1, thực đơn 7 ngày…">${esc(row?.description || '')}</textarea>
        </div>
        <div class="grid-3">
          <div class="field">
            <label class="field-label" for="cp-sessions">Số buổi (1–365)</label>
            <input id="cp-sessions" class="form-control tabular" name="sessionCount" type="number" min="1" max="365" step="1" value="${esc(row?.sessionCount ?? 10)}" required />
          </div>
          <div class="field">
            <label class="field-label" for="cp-days">Thời hạn (1–730 ngày)</label>
            <input id="cp-days" class="form-control tabular" name="durationDays" type="number" min="1" max="730" step="1" value="${esc(row?.durationDays ?? 30)}" required />
          </div>
          <div class="field">
            <label class="field-label" for="cp-price">Giá bán (VND)</label>
            <input id="cp-price" class="form-control tabular" name="price" type="number" min="0" step="1" value="${esc(row?.price ?? '')}" placeholder="3000000" required />
          </div>
        </div>
        <div class="field">
          <label class="field-label" for="cp-status">Trạng thái mở bán</label>
          <select id="cp-status" class="form-select" name="status">
            <option value="ACTIVE" ${row?.status !== 'INACTIVE' ? 'selected' : ''}>Đang bán (ACTIVE)</option>
            <option value="INACTIVE" ${row?.status === 'INACTIVE' ? 'selected' : ''}>Ngừng bán (INACTIVE)</option>
          </select>
        </div>
      </div>
      <div class="meta-modal-footer">
        <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
        <button type="submit" class="btn btn-primary" data-modal-submit>${icon('check', 16)} ${isEdit ? 'Lưu thay đổi' : 'Tạo gói Coach'}</button>
      </div>
    </form>`,
    onMount(ctrl) {
      const form = ctrl.dialog.querySelector('#coach-pkg-form');
      const codeInput = form.querySelector('[name="code"]');
      if (codeInput) {
        codeInput.oninput = () => {
          codeInput.value = codeInput.value.toUpperCase().replace(/\s+/g, '_');
        };
      }

      form.onsubmit = async (event) => {
        event.preventDefault();
        ctrl.showError('');

        const code = isEdit ? row.code : (form.querySelector('[name="code"]')?.value || '').trim().toUpperCase();
        const name = (form.querySelector('[name="name"]')?.value || '').trim();
        const description = (form.querySelector('[name="description"]')?.value || '').trim() || null;
        const sessionCount = Number(form.querySelector('[name="sessionCount"]')?.value);
        const durationDays = Number(form.querySelector('[name="durationDays"]')?.value);
        const priceRaw = form.querySelector('[name="price"]')?.value;
        const price = Number(priceRaw);
        const status = form.querySelector('[name="status"]')?.value || 'ACTIVE';

        if (!isEdit && !CODE_REGEX.test(code)) {
          ctrl.showError('Mã gói không hợp lệ. Cần 2–40 ký tự gồm chữ in hoa A–Z, số 0–9, _ hoặc - (ví dụ PRO_40).');
          return;
        }
        if (!name || name.length > 100) {
          ctrl.showError('Tên gói Coach phải có từ 1 đến 100 ký tự.');
          return;
        }
        if (!Number.isInteger(sessionCount) || sessionCount < 1 || sessionCount > 365) {
          ctrl.showError('Số buổi phải là số nguyên từ 1 đến 365.');
          return;
        }
        if (!Number.isInteger(durationDays) || durationDays < 1 || durationDays > 730) {
          ctrl.showError('Thời hạn phải là số nguyên từ 1 đến 730 ngày.');
          return;
        }
        if (priceRaw === '' || !Number.isInteger(price) || price < 0) {
          ctrl.showError('Giá bán phải là số nguyên lớn hơn hoặc bằng 0.');
          return;
        }

        ctrl.setBusy(true);
        try {
          if (isEdit) {
            await api(`/admin/coach-packages/${encodeURIComponent(row.code)}`, 'PATCH', {
              name,
              description,
              sessionCount,
              durationDays,
              price,
              status,
            });
          } else {
            await api('/admin/coach-packages', 'POST', {
              code,
              name,
              description,
              sessionCount,
              durationDays,
              price,
              status,
            });
          }
          ctrl.close();
          await onSaved();
          notice(isEdit
            ? `Đã cập nhật gói Coach ${code}. Gói đã mua giữ nguyên snapshot.`
            : `Đã tạo gói Coach mới (${code}).`);
        } catch (error) {
          ctrl.setBusy(false);
          ctrl.showError(error.message);
        }
      };
    },
  });
}

export async function renderCoachPackagesPage({ root, params, shell }) {
  const tab = params?.get('tab') === 'entitlements' ? 'entitlements' : 'catalog';
  const search = params?.get('search') || '';
  const statusFilter = params?.get('status') || '';
  const frozenOnly = params?.get('frozenOnly') === 'true';
  const page = Math.max(1, Number(params?.get('page')) || 1);
  const hasFilter = Boolean(search || statusFilter || frozenOnly);

  shell({ section: 'coach-packages', contentHtml: renderSkeletonPage({ cards: 0, rows: 5 }) });

  const reloadWith = (patch = {}) => {
    const nextTab = patch.tab !== undefined ? patch.tab : tab;
    const nextSearch = patch.search !== undefined ? patch.search : (root.querySelector('#cp-search')?.value?.trim() || '');
    const nextStatus = patch.status !== undefined ? patch.status : (root.querySelector('#cp-status-filter')?.value || '');
    const nextFrozen = patch.frozenOnly !== undefined
      ? patch.frozenOnly
      : Boolean(root.querySelector('#cp-frozen-only')?.checked);
    const nextPage = patch.page !== undefined ? patch.page : page;

    const nextParams = new URLSearchParams();
    if (nextTab !== 'catalog') nextParams.set('tab', nextTab);
    if (nextSearch) nextParams.set('search', nextSearch);
    if (nextStatus) nextParams.set('status', nextStatus);
    if (nextTab === 'entitlements' && nextFrozen) nextParams.set('frozenOnly', 'true');
    if (nextPage > 1) nextParams.set('page', String(nextPage));

    updateQuery({
      tab: nextTab !== 'catalog' ? nextTab : null,
      search: nextSearch || null,
      status: nextStatus || null,
      frozenOnly: nextTab === 'entitlements' && nextFrozen ? 'true' : null,
      page: nextPage > 1 ? nextPage : null,
    }, { replace: true });

    return renderCoachPackagesPage({ root, params: nextParams, shell });
  };

  try {
    const endpoint = tab === 'entitlements' ? '/admin/coach-entitlements' : '/admin/coach-packages';
    const query = tab === 'entitlements'
      ? buildQuery({
        status: statusFilter,
        frozenOnly: frozenOnly ? 'true' : '',
        search,
        page,
        pageSize: 20,
      })
      : buildQuery({ status: statusFilter, search });

    const result = await api(`${endpoint}${query}`);
    const rows = result?.data || [];
    const pagination = result?.pagination || { page, pageSize: 20, totalItems: rows.length, totalPages: 1 };

    const tabsHtml = `<div class="meta-tabs" role="tablist" aria-label="Quản lý gói Coach">
      <button type="button" class="meta-tab-btn" role="tab" aria-selected="${tab === 'catalog'}" data-cp-tab="catalog">Danh mục gói Coach</button>
      <button type="button" class="meta-tab-btn" role="tab" aria-selected="${tab === 'entitlements'}" data-cp-tab="entitlements">Quyền lợi gói Coach</button>
    </div>`;

    const filterHtml = tab === 'catalog'
      ? `<form class="filter-bar" id="cp-filter-form">
        <input type="search" id="cp-search" class="form-control filter-grow" placeholder="Tìm theo mã gói, tên hoặc mô tả…" value="${esc(search)}" aria-label="Tìm gói Coach" />
        <select id="cp-status-filter" class="form-select filter-fixed" aria-label="Lọc trạng thái gói Coach">
          <option value="" ${!statusFilter ? 'selected' : ''}>Tất cả trạng thái</option>
          <option value="ACTIVE" ${statusFilter === 'ACTIVE' ? 'selected' : ''}>Đang bán (ACTIVE)</option>
          <option value="INACTIVE" ${statusFilter === 'INACTIVE' ? 'selected' : ''}>Ngừng bán (INACTIVE)</option>
        </select>
        ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm" id="cp-clear">Xóa bộ lọc</button>' : ''}
      </form>`
      : `<form class="filter-bar" id="cp-filter-form">
        <select id="cp-status-filter" class="form-select filter-fixed" aria-label="Lọc trạng thái quyền lợi Coach">
          <option value="" ${!statusFilter ? 'selected' : ''}>Tất cả trạng thái</option>
          <option value="ACTIVE" ${statusFilter === 'ACTIVE' ? 'selected' : ''}>ACTIVE · Đang hiệu lực</option>
          <option value="QUEUED" ${statusFilter === 'QUEUED' ? 'selected' : ''}>QUEUED · Chờ nối tiếp</option>
          <option value="ENDED" ${statusFilter === 'ENDED' ? 'selected' : ''}>ENDED · Đã kết thúc</option>
        </select>
        ${renderToggle({
          id: 'cp-frozen-only',
          checked: frozenOnly,
          label: 'Chỉ gói đang đóng băng (COACH_LOCKED)',
        })}
        ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm" id="cp-clear">Xóa bộ lọc</button>' : ''}
      </form>`;

    const tableHtml = tab === 'catalog'
      ? renderDataTable({
        columns: [
          {
            label: 'Gói Coach',
            render: (row) => `<div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap">
              <span class="person-name">${esc(row.name)}</span>
              <span class="meta-badge meta-badge-neutral tabular">${esc(row.code)}</span>
            </div>
            <span class="person-sub">${esc(row.description || 'Chưa có mô tả')}</span>`,
          },
          {
            label: 'Số buổi (90p)',
            render: (row) => `<strong class="tabular">${esc(row.sessionCount)} buổi</strong>`,
          },
          {
            label: 'Thời hạn',
            render: (row) => `<span class="tabular">${esc(row.durationDays)} ngày</span>`,
          },
          {
            label: 'Giá bán (VND)',
            align: 'right',
            render: (row) => `<strong class="tabular">${vnd(row.price)}</strong>`,
          },
          {
            label: 'Đang dùng / Chờ',
            render: (row) => {
              const activeCount = Number(row.activeEntitlementCount ?? 0);
              const queuedCount = Number(row.queuedEntitlementCount ?? 0);
              return `<span class="tabular"><strong>${activeCount}</strong> đang dùng</span><span class="person-sub tabular">${queuedCount} chờ nối tiếp</span>`;
            },
          },
          {
            label: 'Trạng thái',
            render: (row) => statusBadge(row.status, row.status === 'ACTIVE' ? 'Đang bán' : 'Ngừng bán'),
          },
          {
            label: 'Thao tác',
            align: 'right',
            render: (row) => `<div class="cell-actions"><button type="button" class="btn btn-ghost btn-sm edit-cp" data-code="${esc(row.code)}">${icon('edit', 14)} Sửa cấu hình</button></div>`,
          },
        ],
        rows,
        emptyHtml: hasFilter
          ? renderFilterEmptyState({ resetId: 'cp-filter-reset' })
          : renderEmptyState({
            iconName: 'award',
            title: 'Chưa có gói Coach nào',
            description: 'Tạo gói Coach mới trong danh mục mở để hội viên đăng ký trên ứng dụng.',
            ctaLabel: 'Tạo gói Coach',
            ctaId: 'create-cp-empty',
          }),
        ariaLabel: 'Danh mục gói Coach',
      })
      : renderDataTable({
        columns: [
          {
            label: 'Hội viên',
            render: (row) => `<div class="person-cell">
              <span class="meta-avatar">${esc(initials(row.memberName || 'M'))}</span>
              <span class="person-name">${esc(row.memberName || 'Hội viên')}</span>
            </div>`,
          },
          {
            label: 'Huấn luyện viên',
            render: (row) => `<div class="person-cell">
              <span class="meta-avatar meta-avatar-coach">${esc(initials(row.coachName || 'C'))}</span>
              <span>${esc(row.coachName || 'Huấn luyện viên')}</span>
            </div>`,
          },
          {
            label: 'Gói (Snapshot)',
            render: (row) => `<span class="person-name">${esc(row.planName || row.planCode || 'Gói Coach')}</span>
              <span class="person-sub tabular">${vnd(row.snapshotPrice)}${row.planCode ? ` · ${esc(row.planCode)}` : ''}</span>`,
          },
          {
            label: 'Số buổi còn',
            render: (row) => `<strong class="tabular">${esc(row.remainingSessions)}/${esc(row.totalSessions)} buổi</strong>`,
          },
          {
            label: 'Hạn dùng / Đóng băng',
            render: (row) => {
              const isFrozen = Boolean(row.frozenAt);
              const frozenDays = Number(row.frozenDaysTotal ?? 0);
              const graceDays = Number(row.graceDaysAdded ?? 0);
              const endText = row.endsOn ? formatDateVN(row.endsOn) : 'Kích hoạt sau gói hiện tại';
              return `<div class="stack-12" style="gap:4px">
                <span class="tabular">${esc(endText)}</span>
                ${isFrozen ? `<span class="meta-badge meta-badge-warning tabular">Đang đóng băng${frozenDays ? ` (${frozenDays} ngày đã bù)` : ''}</span>` : (frozenDays > 0 ? `<span class="person-sub tabular">Đã bù đóng băng: +${frozenDays} ngày</span>` : '')}
                ${graceDays > 0 ? `<span class="person-sub tabular">Đã gia hạn bổ sung +${graceDays} ngày</span>` : ''}
              </div>`;
            },
          },
          {
            label: 'Trạng thái',
            render: (row) => `<div>${statusBadge(row.status)}${row.closeReason ? `<span class="person-sub">${esc(CLOSE_REASON_LABELS[row.closeReason] || row.closeReason)}</span>` : ''}</div>`,
          },
        ],
        rows,
        emptyHtml: hasFilter
          ? renderFilterEmptyState({ resetId: 'cp-filter-reset' })
          : renderEmptyState({
            iconName: 'award',
            title: 'Chưa có quyền lợi gói Coach nào',
            description: 'Các gói Coach ACTIVE, QUEUED và ENDED của hội viên sẽ hiển thị tại đây.',
          }),
        paginationHtml: renderPagination({ ...pagination, prefix: 'ce' }),
        ariaLabel: 'Quyền lợi gói Coach',
      });

    const contentHtml = `<div class="stack-20">
      ${tabsHtml}
      ${filterHtml}
      ${tableHtml}
    </div>`;

    shell({
      section: 'coach-packages',
      contentHtml,
      topbarActionsHtml: `<button type="button" class="btn btn-primary" id="create-cp">${icon('plus', 16)} Tạo gói Coach</button>`,
    });

    root.querySelectorAll('[data-cp-tab]').forEach((btn) => {
      btn.onclick = () => reloadWith({ tab: btn.dataset.cpTab, search: '', status: '', frozenOnly: false, page: 1 });
    });

    const debouncedSearch = debounce(() => reloadWith({ page: 1 }), 280);
    const searchInput = root.querySelector('#cp-search');
    if (searchInput) searchInput.oninput = debouncedSearch;

    const filterForm = root.querySelector('#cp-filter-form');
    if (filterForm) {
      filterForm.onsubmit = (ev) => {
        ev.preventDefault();
        debouncedSearch.cancel();
        reloadWith({ page: 1 });
      };
    }

    const statusSelect = root.querySelector('#cp-status-filter');
    if (statusSelect) statusSelect.onchange = () => reloadWith({ page: 1 });

    const frozenCheckbox = root.querySelector('#cp-frozen-only');
    if (frozenCheckbox) frozenCheckbox.onchange = () => reloadWith({ frozenOnly: frozenCheckbox.checked, page: 1 });

    [root.querySelector('#cp-clear'), root.querySelector('#cp-filter-reset')].filter(Boolean).forEach((btn) => {
      btn.onclick = () => reloadWith({ search: '', status: '', frozenOnly: false, page: 1 });
    });

    if (tab === 'entitlements') {
      bindPagination(root, {
        page: pagination.page,
        totalPages: pagination.totalPages,
        prefix: 'ce',
        onChange: (nextPage) => reloadWith({ page: nextPage }),
      });
    }

    const createBtns = [root.querySelector('#create-cp'), root.querySelector('#create-cp-empty')].filter(Boolean);
    createBtns.forEach((btn) => {
      btn.onclick = () => openCoachPackageModal(null, () => reloadWith({ tab: 'catalog', page: 1 }));
    });

    root.querySelectorAll('.edit-cp').forEach((btn) => {
      btn.onclick = () => {
        const pkg = rows.find((r) => r.code === btn.dataset.code);
        if (pkg) openCoachPackageModal(pkg, () => reloadWith({ tab: 'catalog' }));
      };
    });
  } catch (error) {
    shell({
      section: 'coach-packages',
      contentHtml: renderErrorState({
        title: tab === 'entitlements' ? 'Không tải được quyền lợi gói Coach' : 'Không tải được danh mục gói Coach',
        message: error.message,
      }),
    });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderCoachPackagesPage({ root, params, shell });
  }
}
