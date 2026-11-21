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
import { updateQuery } from '../state/router.js';

const SNAPSHOT_BANNER_TEXT = 'Thay đổi chỉ áp dụng cho giao dịch mới; gói đã mua giữ nguyên snapshot về giá bán và số ngày hiệu lực.';

function openGymPlanModal(row, onSaved) {
  openModal({
    title: row ? `Sửa gói Gym: ${row.name}` : 'Tạo gói Gym mới',
    subtitle: 'Quản lý danh mục gói tập phòng gym (cho phép sửa trực tiếp giá và số ngày)',
    bodyHtml: `<form id="plan-form" novalidate>
      <div class="meta-modal-body">
        ${renderBanner({
          kind: 'info',
          iconName: 'info',
          title: 'Quy tắc Snapshot gói Gym',
          text: SNAPSHOT_BANNER_TEXT,
        })}
        <div class="field">
          <label class="field-label" for="plan-name">Tên gói Gym</label>
          <input id="plan-name" class="form-control" name="name" maxlength="100" value="${esc(row?.name || '')}" placeholder="Ví dụ: Gói Gym 90 ngày" required />
        </div>
        <div class="field">
          <label class="field-label" for="plan-desc">Mô tả</label>
          <textarea id="plan-desc" class="form-control" name="description" maxlength="1000" placeholder="Quyền lợi và ghi chú gói Gym…">${esc(row?.description || '')}</textarea>
        </div>
        <div class="grid-2">
          <div class="field">
            <label class="field-label" for="plan-days">Số ngày hiệu lực (1–3650)</label>
            <input id="plan-days" class="form-control tabular" name="durationDays" type="number" min="1" max="3650" step="1" value="${esc(row?.durationDays ?? 30)}" required />
          </div>
          <div class="field">
            <label class="field-label" for="plan-price">Giá bán (VND)</label>
            <input id="plan-price" class="form-control tabular" name="price" type="number" min="0" step="1" value="${esc(row?.price ?? '')}" placeholder="650000" required />
          </div>
        </div>
        <div class="field">
          <label class="field-label" for="plan-status">Trạng thái mở bán</label>
          <select id="plan-status" class="form-select" name="status">
            <option value="ACTIVE" ${row?.status !== 'INACTIVE' ? 'selected' : ''}>Đang bán (ACTIVE)</option>
            <option value="INACTIVE" ${row?.status === 'INACTIVE' ? 'selected' : ''}>Ngừng bán (INACTIVE)</option>
          </select>
        </div>
      </div>
      <div class="meta-modal-footer">
        <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
        <button type="submit" class="btn btn-primary" data-modal-submit>${icon('check', 16)} ${row ? 'Lưu thay đổi' : 'Tạo gói Gym'}</button>
      </div>
    </form>`,
    onMount(ctrl) {
      const form = ctrl.dialog.querySelector('#plan-form');
      form.onsubmit = async (event) => {
        event.preventDefault();
        ctrl.showError('');
        const name = (form.querySelector('[name="name"]')?.value || '').trim();
        const description = (form.querySelector('[name="description"]')?.value || '').trim() || null;
        const durationDays = Number(form.querySelector('[name="durationDays"]')?.value);
        const priceRaw = form.querySelector('[name="price"]')?.value;
        const price = Number(priceRaw);
        const status = form.querySelector('[name="status"]')?.value || 'ACTIVE';

        if (!name || name.length > 100) {
          ctrl.showError('Tên gói Gym phải có từ 1 đến 100 ký tự.');
          return;
        }
        if (!Number.isInteger(durationDays) || durationDays < 1 || durationDays > 3650) {
          ctrl.showError('Số ngày hiệu lực phải là số nguyên từ 1 đến 3650.');
          return;
        }
        if (priceRaw === '' || !Number.isInteger(price) || price < 0) {
          ctrl.showError('Giá bán phải là số nguyên lớn hơn hoặc bằng 0.');
          return;
        }

        ctrl.setBusy(true);
        try {
          await api(
            row ? `/admin/membership-plans/${encodeURIComponent(row.id)}` : '/admin/membership-plans',
            row ? 'PATCH' : 'POST',
            { name, description, price, durationDays, status },
          );
          ctrl.close();
          await onSaved();
          notice(row
            ? 'Đã cập nhật gói Gym. Thay đổi chỉ áp dụng cho giao dịch mới.'
            : 'Đã tạo gói Gym mới.');
        } catch (error) {
          ctrl.setBusy(false);
          ctrl.showError(error.message);
        }
      };
    },
  });
}

export async function renderPlansPage({ root, params, shell }) {
  const tab = params?.get('tab') === 'entitlements' ? 'entitlements' : 'catalog';
  const search = params?.get('search') || '';
  const statusFilter = params?.get('status') || '';
  const page = Math.max(1, Number(params?.get('page')) || 1);
  const hasFilter = Boolean(search || statusFilter);

  shell({ section: 'plans', contentHtml: renderSkeletonPage({ cards: 0, rows: 5 }) });

  const reloadWith = (patch = {}) => {
    const nextTab = patch.tab !== undefined ? patch.tab : tab;
    const nextSearch = patch.search !== undefined ? patch.search : (root.querySelector('#plans-search')?.value?.trim() || '');
    const nextStatus = patch.status !== undefined ? patch.status : (root.querySelector('#plans-status')?.value || '');
    const nextPage = patch.page !== undefined ? patch.page : page;

    const nextParams = new URLSearchParams();
    if (nextTab !== 'catalog') nextParams.set('tab', nextTab);
    if (nextSearch) nextParams.set('search', nextSearch);
    if (nextStatus) nextParams.set('status', nextStatus);
    if (nextPage > 1) nextParams.set('page', String(nextPage));

    updateQuery({
      tab: nextTab !== 'catalog' ? nextTab : null,
      search: nextSearch || null,
      status: nextStatus || null,
      page: nextPage > 1 ? nextPage : null,
    }, { replace: true });

    return renderPlansPage({ root, params: nextParams, shell });
  };

  try {
    const endpoint = tab === 'entitlements' ? '/admin/memberships' : '/admin/membership-plans';
    const query = buildQuery({ status: statusFilter, search, page, pageSize: 20 });
    const result = await api(`${endpoint}${query}`);
    const rows = result?.data || [];
    const pagination = result?.pagination || { page, pageSize: 20, totalItems: rows.length, totalPages: 1 };

    const tabsHtml = `<div class="meta-tabs" role="tablist" aria-label="Quản lý gói Gym">
      <button type="button" class="meta-tab-btn" role="tab" aria-selected="${tab === 'catalog'}" data-plans-tab="catalog">Danh mục gói Gym</button>
      <button type="button" class="meta-tab-btn" role="tab" aria-selected="${tab === 'entitlements'}" data-plans-tab="entitlements">Quyền sử dụng gói Gym</button>
    </div>`;

    const filterHtml = tab === 'catalog'
      ? `<form class="filter-bar" id="plans-filter-form">
        <input type="search" id="plans-search" class="form-control filter-grow" placeholder="Tìm tên hoặc mô tả gói Gym…" value="${esc(search)}" aria-label="Tìm gói Gym" />
        <select id="plans-status" class="form-select filter-fixed" aria-label="Lọc trạng thái gói Gym">
          <option value="" ${!statusFilter ? 'selected' : ''}>Tất cả trạng thái</option>
          <option value="ACTIVE" ${statusFilter === 'ACTIVE' ? 'selected' : ''}>Đang bán (ACTIVE)</option>
          <option value="INACTIVE" ${statusFilter === 'INACTIVE' ? 'selected' : ''}>Ngừng bán (INACTIVE)</option>
        </select>
        ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm" id="plans-clear">Xóa bộ lọc</button>' : ''}
      </form>`
      : `<form class="filter-bar" id="plans-filter-form">
        <input type="search" id="plans-search" class="form-control filter-grow" placeholder="Tìm theo tên hội viên, email hoặc tên gói…" value="${esc(search)}" aria-label="Tìm quyền sử dụng gói Gym" />
        <select id="plans-status" class="form-select filter-fixed" aria-label="Lọc trạng thái quyền sử dụng">
          <option value="" ${!statusFilter ? 'selected' : ''}>Tất cả trạng thái</option>
          <option value="ACTIVE" ${statusFilter === 'ACTIVE' ? 'selected' : ''}>ACTIVE · Đang hiệu lực</option>
          <option value="SCHEDULED" ${statusFilter === 'SCHEDULED' ? 'selected' : ''}>SCHEDULED · Đã xếp lịch</option>
          <option value="EXPIRED" ${statusFilter === 'EXPIRED' ? 'selected' : ''}>EXPIRED · Hết hạn</option>
          <option value="CANCELLED" ${statusFilter === 'CANCELLED' ? 'selected' : ''}>CANCELLED · Đã hủy</option>
        </select>
        ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm" id="plans-clear">Xóa bộ lọc</button>' : ''}
      </form>`;

    const tableHtml = tab === 'catalog'
      ? renderDataTable({
        columns: [
          {
            label: 'Tên gói Gym',
            render: (row) => `<span class="person-name">${esc(row.name)}</span><span class="person-sub">${esc(row.description || 'Chưa có mô tả')}</span>`,
          },
          {
            label: 'Thời hạn',
            render: (row) => `<strong class="tabular">${esc(row.durationDays)} ngày</strong>`,
          },
          {
            label: 'Giá bán (VND)',
            align: 'right',
            render: (row) => `<strong class="tabular">${vnd(row.price)}</strong>`,
          },
          {
            label: 'Hội viên đang dùng',
            render: (row) => {
              const activeCount = Number(row.activeMembershipCount ?? 0);
              const schedCount = Number(row.scheduledMembershipCount ?? 0);
              return `<span class="tabular"><strong>${activeCount}</strong> hiệu lực</span><span class="person-sub tabular">${schedCount} đã xếp lịch</span>`;
            },
          },
          {
            label: 'Trạng thái',
            render: (row) => statusBadge(row.status, row.status === 'ACTIVE' ? 'Đang bán' : 'Ngừng bán'),
          },
          {
            label: 'Thao tác',
            align: 'right',
            render: (row) => `<div class="cell-actions"><button type="button" class="btn btn-ghost btn-sm edit-plan" data-id="${esc(row.id)}">${icon('edit', 14)} Sửa giá / ngày</button></div>`,
          },
        ],
        rows,
        emptyHtml: hasFilter
          ? renderFilterEmptyState({ resetId: 'plans-filter-reset' })
          : renderEmptyState({
            iconName: 'card',
            title: 'Chưa có gói Gym nào',
            description: 'Tạo gói Gym đầu tiên để mở bán trên ứng dụng và tại quầy lễ tân.',
            ctaLabel: 'Tạo gói Gym',
            ctaId: 'create-plan-empty',
          }),
        paginationHtml: renderPagination({ ...pagination, prefix: 'gp' }),
        ariaLabel: 'Danh mục gói Gym',
      })
      : renderDataTable({
        columns: [
          {
            label: 'Hội viên',
            render: (row) => `<div class="person-cell">
              <span class="meta-avatar">${esc(initials(row.memberName || 'M'))}</span>
              <div>
                <span class="person-name">${esc(row.memberName || 'Hội viên')}</span>
                ${row.memberEmail ? `<span class="person-sub">${esc(row.memberEmail)}</span>` : ''}
              </div>
            </div>`,
          },
          {
            label: 'Gói Gym (Snapshot)',
            render: (row) => `<span class="person-name">${esc(row.planName || 'Gói Gym')}</span>${row.amount != null ? `<span class="person-sub tabular">${vnd(row.amount)}</span>` : ''}`,
          },
          {
            label: 'Thời hạn (GMT+7)',
            render: (row) => `<span class="tabular">${formatDateVN(row.startDate)} → ${formatDateVN(row.endDate)}</span>`,
          },
          {
            label: 'Trạng thái',
            render: (row) => statusBadge(row.status),
          },
        ],
        rows,
        emptyHtml: hasFilter
          ? renderFilterEmptyState({ resetId: 'plans-filter-reset' })
          : renderEmptyState({
            iconName: 'card',
            title: 'Chưa có quyền sử dụng gói Gym nào',
            description: 'Quyền sử dụng (ACTIVE / SCHEDULED / EXPIRED) sẽ xuất hiện sau khi hội viên đăng ký hoặc thanh toán tại quầy.',
          }),
        paginationHtml: renderPagination({ ...pagination, prefix: 'ge' }),
        ariaLabel: 'Quyền sử dụng gói Gym',
      });

    const contentHtml = `<div class="stack-20">
      ${tabsHtml}
      ${renderBanner({
        kind: 'info',
        iconName: 'info',
        title: 'Quy tắc Snapshot gói Gym',
        text: SNAPSHOT_BANNER_TEXT,
      })}
      ${filterHtml}
      ${tableHtml}
    </div>`;

    shell({
      section: 'plans',
      contentHtml,
      topbarActionsHtml: `<button type="button" class="btn btn-primary" id="create-plan">${icon('plus', 16)} Tạo gói Gym</button>`,
    });

    root.querySelectorAll('[data-plans-tab]').forEach((btn) => {
      btn.onclick = () => reloadWith({ tab: btn.dataset.plansTab, search: '', status: '', page: 1 });
    });

    const debouncedSearch = debounce(() => reloadWith({ page: 1 }), 280);
    const searchInput = root.querySelector('#plans-search');
    if (searchInput) searchInput.oninput = debouncedSearch;

    const filterForm = root.querySelector('#plans-filter-form');
    if (filterForm) {
      filterForm.onsubmit = (ev) => {
        ev.preventDefault();
        debouncedSearch.cancel();
        reloadWith({ page: 1 });
      };
    }

    const statusSelect = root.querySelector('#plans-status');
    if (statusSelect) statusSelect.onchange = () => reloadWith({ page: 1 });

    [root.querySelector('#plans-clear'), root.querySelector('#plans-filter-reset')].filter(Boolean).forEach((btn) => {
      btn.onclick = () => reloadWith({ search: '', status: '', page: 1 });
    });

    bindPagination(root, {
      page: pagination.page,
      totalPages: pagination.totalPages,
      prefix: tab === 'catalog' ? 'gp' : 'ge',
      onChange: (nextPage) => reloadWith({ page: nextPage }),
    });

    const createBtns = [root.querySelector('#create-plan'), root.querySelector('#create-plan-empty')].filter(Boolean);
    createBtns.forEach((btn) => {
      btn.onclick = () => openGymPlanModal(null, () => reloadWith({ tab: 'catalog', page: 1 }));
    });

    root.querySelectorAll('.edit-plan').forEach((btn) => {
      btn.onclick = () => {
        const plan = rows.find((r) => r.id === btn.dataset.id);
        if (plan) openGymPlanModal(plan, () => reloadWith({ page }));
      };
    });
  } catch (error) {
    shell({
      section: 'plans',
      contentHtml: renderErrorState({
        title: tab === 'entitlements' ? 'Không tải được quyền sử dụng gói Gym' : 'Không tải được danh mục gói Gym',
        message: error.message,
      }),
    });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderPlansPage({ root, params, shell });
  }
}
