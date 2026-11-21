import { api } from '../services/api.js';
import { esc, statusBadge } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderDataTable } from '../components/data-table.js';
import { openModal } from '../components/modal.js';
import { renderEmptyState, renderErrorState, renderFilterEmptyState, renderSkeletonPage } from '../components/states.js';
import { toast } from '../components/toast.js';

export async function renderNutritionFoodsPage({ root, params, shell }) {
  let search = params?.get('search') || '';
  let statusFilter = params?.get('status') || 'ALL';

  shell({ section: 'nutrition-foods', contentHtml: renderSkeletonPage({ cards: 0, rows: 6 }) });

  try {
    const { data } = await api('/admin/nutrition-foods');
    const allRows = data || [];

    const draw = () => {
      const q = search.trim().toLowerCase();
      const filtered = allRows.filter((item) => {
        const matchQ = !q || String(item.name || '').toLowerCase().includes(q);
        const matchS = statusFilter === 'ALL'
          || (statusFilter === 'ACTIVE' ? Boolean(item.active) : !item.active);
        return matchQ && matchS;
      });

      const hasFilter = Boolean(q) || statusFilter !== 'ALL';
      const contentHtml = `<div class="stack-20">
        <div class="filter-bar">
          <input type="search" id="food-search" class="form-control filter-grow" placeholder="Tìm tên thực phẩm…" value="${esc(search)}" aria-label="Tìm thực phẩm" />
          <select id="food-status" class="form-select filter-fixed" aria-label="Lọc trạng thái thực phẩm">
            <option value="ALL" ${statusFilter === 'ALL' ? 'selected' : ''}>Tất cả trạng thái</option>
            <option value="ACTIVE" ${statusFilter === 'ACTIVE' ? 'selected' : ''}>Hiển thị</option>
            <option value="HIDDEN" ${statusFilter === 'HIDDEN' ? 'selected' : ''}>Đang ẩn</option>
          </select>
          ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm" id="food-reset">Xóa lọc</button>' : ''}
        </div>
        ${renderDataTable({
          columns: [
            { label: 'Tên thực phẩm', render: (row) => `<span class="person-name">${esc(row.name)}</span>` },
            { label: 'Năng lượng (kcal / 100g)', align: 'right', render: (row) => `<strong class="tabular" style="color:var(--meta-success)">${Number(row.kcalPer100g ?? 0).toFixed(2)} kcal</strong>` },
            { label: 'Trạng thái', render: (row) => statusBadge(row.active ? 'ACTIVE' : 'HIDDEN', row.active ? 'Hiển thị' : 'Đang ẩn') },
            {
              label: 'Thao tác',
              align: 'right',
              render: (row) => `<div class="cell-actions"><button type="button" class="btn btn-ghost btn-sm edit-food" data-id="${esc(row.id)}">Sửa</button></div>`,
            },
          ],
          rows: filtered,
          emptyHtml: hasFilter
            ? renderFilterEmptyState({ resetId: 'food-filter-reset' })
            : renderEmptyState({ iconName: 'food', title: 'Chưa có thực phẩm nào', description: 'Thêm thực phẩm kèm kcal/100g để Coach soạn thực đơn 7 ngày.', ctaLabel: 'Thêm thực phẩm', ctaId: 'create-food-empty' }),
        })}
      </div>`;

      shell({
        section: 'nutrition-foods',
        contentHtml,
        topbarActionsHtml: `<button type="button" class="btn btn-primary" id="create-food">${icon('plus', 16)} Thêm thực phẩm</button>`,
      });

      const openEditor = (row) => {
        openModal({
          title: row ? `Sửa thực phẩm: ${row.name}` : 'Thêm thực phẩm mới',
          subtitle: 'Việc ẩn thực phẩm không làm mất dữ liệu các thực đơn 7 ngày đã lưu',
          bodyHtml: `<form id="food-form" novalidate>
            <div class="meta-modal-body">
              <div class="field"><label class="field-label" for="fd-name">Tên thực phẩm (<= 150 ký tự)</label><input id="fd-name" class="form-control" name="name" maxlength="150" value="${esc(row?.name || '')}" required /></div>
              <div class="grid-2">
                <div class="field"><label class="field-label" for="fd-kcal">kcal / 100g (0–1000)</label><input id="fd-kcal" class="form-control tabular" name="kcal" type="number" min="0" max="1000" step="0.01" value="${esc(row?.kcalPer100g ?? '')}" required /></div>
                <div class="field"><label class="field-label" for="fd-active">Trạng thái</label><select id="fd-active" class="form-select" name="active"><option value="1" ${!row || row.active ? 'selected' : ''}>Cho phép chọn</option><option value="0" ${row && !row.active ? 'selected' : ''}>Ẩn</option></select></div>
              </div>
            </div>
            <div class="meta-modal-footer"><button type="button" class="btn btn-ghost" data-close-modal>Hủy</button><button type="submit" class="btn btn-primary" data-modal-submit>Lưu thực phẩm</button></div>
          </form>`,
          onMount(ctrl) {
            const form = ctrl.dialog.querySelector('#food-form');
            form.onsubmit = async (event) => {
              event.preventDefault();
              ctrl.showError('');
              const name = (form.querySelector('[name="name"]')?.value || '').trim();
              const kcalPer100g = Number(form.querySelector('[name="kcal"]')?.value);
              const active = form.querySelector('[name="active"]')?.value === '1';
              if (!name || Number.isNaN(kcalPer100g) || kcalPer100g < 0 || kcalPer100g > 1000) {
                ctrl.showError('Tên không được trống và kcal/100g phải trong khoảng 0 đến 1000.');
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
                toast('Đã lưu thực phẩm.');
                await renderNutritionFoodsPage({ root, params, shell });
              } catch (error) {
                ctrl.setBusy(false);
                ctrl.showError(error.message);
              }
            };
          },
        });
      };

      const searchEl = root.querySelector('#food-search');
      if (searchEl) {
        searchEl.oninput = (ev) => {
          search = ev.target.value;
          draw();
          const nextEl = root.querySelector('#food-search');
          nextEl?.focus?.();
        };
      }
      const statusEl = root.querySelector('#food-status');
      if (statusEl) statusEl.onchange = (ev) => { statusFilter = ev.target.value; draw(); };
      const resetBtns = [root.querySelector('#food-reset'), root.querySelector('#food-filter-reset')].filter(Boolean);
      resetBtns.forEach((btn) => { btn.onclick = () => { search = ''; statusFilter = 'ALL'; draw(); }; });
      const createBtn = root.querySelector('#create-food') || root.querySelector('#create-food-empty');
      if (createBtn) createBtn.onclick = () => openEditor(null);
      root.querySelectorAll('.edit-food').forEach((btn) => {
        btn.onclick = () => openEditor(allRows.find((r) => r.id === btn.dataset.id));
      });
    };

    draw();
  } catch (error) {
    shell({ section: 'nutrition-foods', contentHtml: renderErrorState({ title: 'Không tải được thực phẩm', message: error.message }) });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderNutritionFoodsPage({ root, params, shell });
  }
}
