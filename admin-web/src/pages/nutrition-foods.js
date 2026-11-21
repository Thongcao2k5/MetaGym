import { api, buildQuery } from '../services/api.js';
import { debounce, esc } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderActionButton } from '../components/action-button.js';
import { bindDataTableSelection, renderDataTable } from '../components/data-table.js';
import { exportToExcel } from '../components/export.js';
import { openConfirmModal, openModal } from '../components/modal.js';
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
import { hasPermission, NO_PERMISSION_REASON } from '../services/permissions.js';
import { updateQuery } from '../state/router.js';

const FREEZE_SNAPSHOT_NOTE = 'Thay đổi kcal/100g cập nhật trực tiếp cho thực đơn đang hoạt động (ACTIVE); các thực đơn đã lưu trữ (ARCHIVED) giữ nguyên giá trị kcal đã đóng băng (trg_freeze_nutrition_calories).';

function renderFoodStatusSwitch(row) {
  const isActive = Boolean(row.active);
  const canUpdate = hasPermission('nutrition_foods:update');
  const label = isActive ? 'Đang dùng' : 'Đã ẩn';
  const title = !canUpdate
    ? NO_PERMISSION_REASON
    : (isActive ? 'Đang dùng · Bấm để ẩn khỏi danh mục chọn' : 'Đã ẩn · Bấm để cho phép chọn lại');

  return `<button type="button" role="switch" aria-checked="${isActive}" class="meta-switch-btn toggle-food-active${isActive ? ' is-on' : ''}" data-id="${esc(row.id)}" aria-label="${label}" title="${esc(title)}"${!canUpdate ? ' disabled aria-disabled="true" data-perm-disabled="1"' : ''}>
    <span class="meta-switch-track" aria-hidden="true"><span class="meta-switch-thumb"></span></span>
    <span>${label}</span>
  </button>`;
}

export async function renderNutritionFoodsPage({ root, params, shell }) {
  const search = params?.get('search') || '';
  const activeParam = params?.get('active') || '';
  const activeFilter = activeParam === 'true' || activeParam === 'false' ? activeParam : '';
  const page = Math.max(1, Number(params?.get('page')) || 1);
  const pageSize = Math.max(1, Number(params?.get('pageSize')) || 10);
  const hasFilter = Boolean(search || activeFilter);

  const buildFilterHtml = (canExport = false) => `<form class="filter-bar" id="food-filter-form">
    <input type="search" id="food-search" class="form-control filter-grow" placeholder="Tìm tên thực phẩm…" value="${esc(search)}" aria-label="Tìm thực phẩm" />
    <select id="food-active" class="form-select filter-fixed" aria-label="Lọc trạng thái thực phẩm">
      <option value="" ${!activeFilter ? 'selected' : ''}>Tất cả</option>
      <option value="true" ${activeFilter === 'true' ? 'selected' : ''}>Đang dùng</option>
      <option value="false" ${activeFilter === 'false' ? 'selected' : ''}>Đã ẩn</option>
    </select>
    ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm" id="food-clear">Xóa lọc</button>' : ''}
    <button type="button" class="btn btn-graphite btn-sm" id="food-export-excel" ${canExport ? '' : 'disabled'}>
      ${icon('download', 16)} <span id="food-export-label">Xuất Excel</span>
    </button>
  </form>`;

  const topbarActionsHtml = `<button type="button" class="btn btn-primary" id="create-food">${icon('plus', 16)} Thêm thực phẩm</button>`;

  shell({
    section: 'nutrition-foods',
    topbarActionsHtml,
    contentHtml: `<div class="stack-20">${buildFilterHtml(false)}${renderTableSkeleton(5)}</div>`,
  });

  const reloadWith = (patch = {}) => {
    const nextSearch = patch.search !== undefined ? patch.search : (root.querySelector('#food-search')?.value?.trim() || '');
    const nextActive = patch.active !== undefined ? patch.active : (root.querySelector('#food-active')?.value || '');
    const nextPage = patch.page !== undefined ? patch.page : page;
    const nextPageSize = patch.pageSize !== undefined ? patch.pageSize : pageSize;

    const nextParams = new URLSearchParams();
    if (nextSearch) nextParams.set('search', nextSearch);
    if (nextActive === 'true' || nextActive === 'false') nextParams.set('active', nextActive);
    if (nextPage > 1) nextParams.set('page', String(nextPage));
    if (nextPageSize !== 10) nextParams.set('pageSize', String(nextPageSize));

    updateQuery({
      search: nextSearch || null,
      active: nextActive === 'true' || nextActive === 'false' ? nextActive : null,
      page: nextPage > 1 ? nextPage : null,
      pageSize: nextPageSize !== 10 ? nextPageSize : null,
    }, { replace: true });

    return renderNutritionFoodsPage({ root, params: nextParams, shell });
  };

  try {
    const query = buildQuery({
      search,
      active: activeFilter,
      page,
      pageSize,
    });
    const result = await api(`/admin/nutrition-foods${query}`);
    const rows = result?.data || [];
    const pagination = result?.pagination || {
      page,
      pageSize,
      totalItems: rows.length,
      totalPages: Math.max(1, Math.ceil(rows.length / pageSize)),
    };

    const contentHtml = `<div class="stack-20">
      ${buildFilterHtml(rows.length > 0)}
      ${renderDataTable({
        columns: [
          {
            label: 'Tên thực phẩm',
            render: (row) => `<span class="person-name">${esc(row.name)}</span>`,
          },
          {
            label: 'Năng lượng (kcal / 100g)',
            align: 'right',
            render: (row) => `<strong class="tabular" style="color:var(--meta-success)">${Number(row.kcalPer100g ?? 0).toFixed(2)} kcal</strong>`,
          },
          {
            label: 'Trạng thái',
            render: (row) => renderFoodStatusSwitch(row),
          },
          {
            label: 'Thao tác',
            align: 'right',
            render: (row) => `<div class="cell-actions">
              ${renderActionButton({
                iconName: 'edit',
                label: 'Sửa thực phẩm',
                className: 'edit-food',
                permission: 'nutrition_foods:update',
                attrs: `data-id="${esc(row.id)}"`,
              })}
            </div>`,
          },
        ],
        rows,
        selectable: true,
        rowId: (_row, idx) => String(idx),
        emptyHtml: hasFilter
          ? renderFilterEmptyState({ resetId: 'food-filter-reset' })
          : renderEmptyState({
            iconName: 'food',
            title: 'Chưa có thực phẩm nào',
            description: 'Thêm thực phẩm kèm kcal/100g để Coach soạn thực đơn 7 ngày.',
            ctaLabel: 'Thêm thực phẩm',
            ctaId: 'create-food-empty',
          }),
        paginationHtml: renderPagination({
          ...pagination,
          prefix: 'food',
        }),
        ariaLabel: 'Danh mục thực phẩm và năng lượng kcal',
      })}
    </div>`;

    shell({
      section: 'nutrition-foods',
      contentHtml,
      topbarActionsHtml,
    });

    const openEditor = (row) => {
      openModal({
        title: row ? `Sửa thực phẩm: ${row.name}` : 'Thêm thực phẩm mới',
        subtitle: 'Danh mục thực phẩm dùng chung cho thực đơn 7 ngày của Coach',
        bodyHtml: `<form id="food-form" novalidate>
          <div class="meta-modal-body">
            ${row ? renderBanner({
              kind: 'info',
              iconName: 'info',
              title: 'Quy tắc đóng băng kcal (trg_freeze_nutrition_calories)',
              text: FREEZE_SNAPSHOT_NOTE,
            }) : ''}
            <div class="field">
              <label class="field-label" for="fd-name">Tên thực phẩm (tối đa 150 ký tự)</label>
              <input id="fd-name" class="form-control" name="name" maxlength="150" value="${esc(row?.name || '')}" placeholder="Ví dụ: Ức gà áp chảo" required />
            </div>
            <div class="field">
              <label class="field-label" for="fd-kcal">kcal / 100g (0–1000)</label>
              <input id="fd-kcal" class="form-control tabular" name="kcal" type="number" min="0" max="1000" step="0.01" value="${esc(row?.kcalPer100g ?? '')}" placeholder="165" required />
            </div>
            <div class="field">
              <span class="field-label">Trạng thái sử dụng</span>
              ${renderToggle({
                id: 'fd-active',
                name: 'active',
                checked: row ? Boolean(row.active) : true,
                label: 'Đang dùng (cho phép Coach chọn vào thực đơn mới)',
              })}
            </div>
          </div>
          <div class="meta-modal-footer">
            <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
            <button type="submit" class="btn btn-primary" data-modal-submit>${icon('check', 16)} Lưu thực phẩm</button>
          </div>
        </form>`,
        onMount(ctrl) {
          const form = ctrl.dialog.querySelector('#food-form');
          form.onsubmit = async (event) => {
            event.preventDefault();
            ctrl.showError('');
            const name = (form.querySelector('[name="name"]')?.value || '').trim();
            const kcalRaw = form.querySelector('[name="kcal"]')?.value;
            const kcalPer100g = Number(kcalRaw);
            const active = Boolean(form.querySelector('[name="active"]')?.checked);
            if (!name || name.length > 150 || kcalRaw === '' || Number.isNaN(kcalPer100g) || kcalPer100g < 0 || kcalPer100g > 1000) {
              ctrl.showError('Tên thực phẩm không được trống (tối đa 150 ký tự) và kcal/100g phải trong khoảng 0 đến 1000.');
              return;
            }
            ctrl.setBusy(true);
            try {
              await api(
                row ? `/admin/nutrition-foods/${encodeURIComponent(row.id)}` : '/admin/nutrition-foods',
                row ? 'PATCH' : 'POST',
                { name, kcalPer100g, active },
              );
              ctrl.close();
              toast(row ? 'Đã cập nhật thực phẩm.' : 'Đã thêm thực phẩm mới.');
              await reloadWith({ page: row ? page : 1 });
            } catch (error) {
              ctrl.setBusy(false);
              ctrl.showError(error.message);
            }
          };
        },
      });
    };

    const debouncedSearch = debounce(() => reloadWith({ page: 1 }), 280);
    const searchEl = root.querySelector('#food-search');
    if (searchEl) searchEl.oninput = debouncedSearch;

    const filterForm = root.querySelector('#food-filter-form');
    if (filterForm) {
      filterForm.onsubmit = (ev) => {
        ev.preventDefault();
        debouncedSearch.cancel();
        reloadWith({ page: 1 });
      };
    }

    const activeEl = root.querySelector('#food-active');
    if (activeEl) activeEl.onchange = () => reloadWith({ page: 1 });

    [root.querySelector('#food-clear'), root.querySelector('#food-filter-reset')].filter(Boolean).forEach((btn) => {
      btn.onclick = () => reloadWith({ search: '', active: '', page: 1 });
    });

    bindPagination(root, {
      page: pagination.page,
      totalPages: pagination.totalPages,
      prefix: 'food',
      onChange: (nextPage) => reloadWith({ page: nextPage }),
      onPageSizeChange: (nextSize) => reloadWith({ pageSize: nextSize, page: 1 }),
    });

    const exportLabel = root.querySelector('#food-export-label');
    const getSelectedIndices = bindDataTableSelection(root, {
      onSelectionChange: (ids) => {
        if (exportLabel) {
          exportLabel.textContent = ids.length > 0 ? `Xuất Excel (${ids.length})` : 'Xuất Excel';
        }
      },
    });

    const exportBtn = root.querySelector('#food-export-excel');
    if (exportBtn) {
      exportBtn.onclick = () => {
        const selected = getSelectedIndices();
        const targetRows = selected.length > 0
          ? selected.map((idx) => rows[Number(idx)]).filter(Boolean)
          : rows;
        if (!targetRows.length) {
          toast('Chưa có dữ liệu thực phẩm để xuất Excel.', 'warn');
          return;
        }
        const ok = exportToExcel({
          filename: 'metagym-nutrition-foods.csv',
          columns: [
            { label: 'Tên thực phẩm', value: (r) => r.name || '' },
            { label: 'kcal / 100g', value: (r) => Number(r.kcalPer100g ?? 0).toFixed(2) },
            { label: 'Trạng thái', value: (r) => (r.active ? 'Đang dùng' : 'Đã ẩn') },
          ],
          rows: targetRows,
        });
        if (ok) toast(`Đã xuất ${targetRows.length} thực phẩm ra file Excel (.csv).`);
      };
    }

    [root.querySelector('#create-food'), root.querySelector('#create-food-empty')].filter(Boolean).forEach((btn) => {
      btn.onclick = () => openEditor(null);
    });

    root.querySelectorAll('.edit-food').forEach((btn) => {
      btn.onclick = () => {
        const row = rows.find((r) => r.id === btn.dataset.id);
        if (row) openEditor(row);
      };
    });

    root.querySelectorAll('.toggle-food-active').forEach((btn) => {
      btn.onclick = () => {
        if (btn.disabled) return;
        const row = rows.find((r) => r.id === btn.dataset.id);
        if (!row) return;
        const nextActive = !row.active;
        openConfirmModal({
          title: nextActive ? `Hiển thị lại thực phẩm: ${row.name}` : `Ẩn thực phẩm: ${row.name}`,
          subtitle: nextActive
            ? 'Coach sẽ có thể chọn thực phẩm này khi tạo hoặc cập nhật thực đơn mới'
            : 'Thực phẩm bị ẩn khỏi danh mục chọn nhưng không làm hỏng thực đơn cũ đã lưu',
          bannerHtml: renderBanner({
            kind: 'info',
            iconName: 'info',
            title: 'Quy tắc đóng băng kcal (trg_freeze_nutrition_calories)',
            text: FREEZE_SNAPSHOT_NOTE,
          }),
          confirmLabel: nextActive ? 'Cho phép chọn lại' : 'Ẩn thực phẩm',
          confirmVariant: nextActive ? 'primary' : 'danger-solid',
          confirmIcon: 'check',
          onConfirm: async () => {
            await api(`/admin/nutrition-foods/${encodeURIComponent(row.id)}`, 'PATCH', { active: nextActive });
            toast(nextActive ? `Đã bật lại "${row.name}".` : `Đã ẩn "${row.name}".`);
            await reloadWith({ page });
          },
        });
      };
    });
  } catch (error) {
    shell({
      section: 'nutrition-foods',
      topbarActionsHtml,
      contentHtml: renderErrorState({ title: 'Không tải được thực phẩm', message: error.message }),
    });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderNutritionFoodsPage({ root, params, shell });
  }
}
