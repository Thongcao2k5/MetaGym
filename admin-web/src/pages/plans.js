import { api } from '../services/api.js';
import { esc, statusBadge, vnd } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderDataTable } from '../components/data-table.js';
import { openModal } from '../components/modal.js';
import { renderBanner, renderEmptyState, renderErrorState, renderSkeletonPage } from '../components/states.js';
import { toast } from '../components/toast.js';

export async function renderPlansPage({ root, params, shell }) {
  shell({ section: 'plans', contentHtml: renderSkeletonPage({ cards: 0, rows: 5 }) });
  try {
    const { data } = await api('/admin/membership-plans?pageSize=100');
    const rows = data || [];

    const contentHtml = `<div class="stack-20">
      ${renderBanner({
        kind: 'info',
        iconName: 'info',
        title: 'Quy tắc Snapshot gói Gym',
        text: 'Thay đổi chỉ áp dụng cho giao dịch mới; gói đã mua giữ nguyên snapshot giá và số ngày.',
      })}
      ${renderDataTable({
        columns: [
          {
            label: 'Tên gói Gym',
            render: (row) => `<span class="person-name">${esc(row.name)}</span><span class="person-sub">${esc(row.description || '—')}</span>`,
          },
          { label: 'Số ngày', render: (row) => `<strong class="tabular">${esc(row.durationDays)} ngày</strong>` },
          { label: 'Giá bán (VND)', align: 'right', render: (row) => `<strong class="tabular">${vnd(row.price)}</strong>` },
          { label: 'Trạng thái', render: (row) => statusBadge(row.status) },
          {
            label: 'Thao tác',
            align: 'right',
            render: (row) => `<div class="cell-actions"><button type="button" class="btn btn-ghost btn-sm edit" data-id="${esc(row.id)}">Sửa</button></div>`,
          },
        ],
        rows,
        emptyHtml: renderEmptyState({ iconName: 'card', title: 'Chưa có gói Gym nào', description: 'Tạo gói Gym mới để mở bán cho hội viên.', ctaLabel: 'Tạo gói Gym', ctaId: 'create-empty' }),
      })}
    </div>`;

    shell({
      section: 'plans',
      contentHtml,
      topbarActionsHtml: `<button type="button" class="btn btn-primary" id="create">${icon('plus', 16)} Tạo gói Gym</button>`,
    });

    const openEditor = (row) => {
      openModal({
        title: row ? `Sửa gói Gym: ${row.name}` : 'Tạo gói Gym mới',
        subtitle: 'Thay đổi chỉ áp dụng cho giao dịch mới; gói đã mua giữ nguyên snapshot',
        bodyHtml: `<form id="plan-form" novalidate>
          <div class="meta-modal-body">
            <div class="field"><label class="field-label" for="plan-name">Tên gói</label><input id="plan-name" class="form-control" name="name" value="${esc(row?.name || '')}" required /></div>
            <div class="field"><label class="field-label" for="plan-desc">Mô tả</label><textarea id="plan-desc" class="form-control" name="description">${esc(row?.description || '')}</textarea></div>
            <div class="grid-2">
              <div class="field"><label class="field-label" for="plan-days">Số ngày</label><input id="plan-days" class="form-control tabular" name="durationDays" type="number" min="1" max="3650" value="${esc(row?.durationDays ?? 30)}" required /></div>
              <div class="field"><label class="field-label" for="plan-price">Giá (VND)</label><input id="plan-price" class="form-control tabular" name="price" type="number" min="0" value="${esc(row?.price ?? '')}" required /></div>
            </div>
            <div class="field"><label class="field-label" for="plan-status">Trạng thái</label><select id="plan-status" class="form-select" name="status"><option value="ACTIVE" ${row?.status !== 'INACTIVE' ? 'selected' : ''}>Đang bán</option><option value="INACTIVE" ${row?.status === 'INACTIVE' ? 'selected' : ''}>Ngừng bán</option></select></div>
          </div>
          <div class="meta-modal-footer"><button type="button" class="btn btn-ghost" data-close-modal>Hủy</button><button type="submit" class="btn btn-primary" data-modal-submit>Lưu gói Gym</button></div>
        </form>`,
        onMount(ctrl) {
          const form = ctrl.dialog.querySelector('#plan-form');
          form.onsubmit = async (event) => {
            event.preventDefault();
            ctrl.showError('');
            ctrl.setBusy(true);
            try {
              await api(row ? `/admin/membership-plans/${row.id}` : '/admin/membership-plans', row ? 'PATCH' : 'POST', {
                name: (form.querySelector('[name="name"]')?.value || '').trim(),
                description: (form.querySelector('[name="description"]')?.value || '').trim() || null,
                price: Number(form.querySelector('[name="price"]')?.value),
                durationDays: Number(form.querySelector('[name="durationDays"]')?.value),
                status: form.querySelector('[name="status"]')?.value || 'ACTIVE',
              });
              ctrl.close();
              toast('Đã lưu gói Gym.');
              await renderPlansPage({ root, params, shell });
            } catch (error) {
              ctrl.setBusy(false);
              ctrl.showError(error.message);
            }
          };
        },
      });
    };

    const createBtn = root.querySelector('#create') || root.querySelector('#create-empty');
    if (createBtn) createBtn.onclick = () => openEditor(null);
    root.querySelectorAll('.edit').forEach((btn) => {
      btn.onclick = () => openEditor(rows.find((r) => r.id === btn.dataset.id));
    });
  } catch (error) {
    shell({ section: 'plans', contentHtml: renderErrorState({ title: 'Không tải được gói Gym', message: error.message }) });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderPlansPage({ root, params, shell });
  }
}
