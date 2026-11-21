import { api } from '../services/api.js';
import { esc, statusBadge, vnd } from '../components/format.js';
import { renderDataTable } from '../components/data-table.js';
import { openModal } from '../components/modal.js';
import { renderBanner, renderEmptyState, renderErrorState, renderSkeletonPage } from '../components/states.js';
import { toast } from '../components/toast.js';

export async function renderCoachPackagesPage({ root, params, shell }) {
  shell({ section: 'coach-packages', contentHtml: renderSkeletonPage({ cards: 0, rows: 4 }) });
  try {
    const { data } = await api('/admin/coach-packages');
    const rows = data || [];

    const contentHtml = `<div class="stack-20">
      ${renderBanner({
        kind: 'info',
        iconName: 'award',
        title: 'Danh mục gói Coach (90 phút/buổi)',
        text: 'Thay đổi chỉ áp dụng cho giao dịch mới; gói đã mua/QUEUED giữ nguyên snapshot.',
      })}
      ${renderDataTable({
        columns: [
          {
            label: 'Tên gói Coach',
            render: (row) => `<span class="person-name">${esc(row.name)}</span><span class="person-sub tabular">${esc(row.code)}</span>`,
          },
          { label: 'Số buổi', render: (row) => `<strong class="tabular">${esc(row.sessionCount)} buổi</strong>` },
          { label: 'Thời hạn', render: (row) => `<span class="tabular">${esc(row.durationDays)} ngày</span>` },
          { label: 'Giá (VND)', align: 'right', render: (row) => `<strong class="tabular">${vnd(row.price)}</strong>` },
          { label: 'Trạng thái', render: (row) => statusBadge(row.status) },
          {
            label: 'Thao tác',
            align: 'right',
            render: (row) => `<div class="cell-actions"><button type="button" class="btn btn-ghost btn-sm edit" data-code="${esc(row.code)}">Sửa</button></div>`,
          },
        ],
        rows,
        emptyHtml: renderEmptyState({ iconName: 'award', title: 'Chưa có gói Coach nào', description: 'Chưa có gói Coach trong danh mục.' }),
      })}
    </div>`;

    shell({ section: 'coach-packages', contentHtml });

    root.querySelectorAll('.edit').forEach((btn) => {
      btn.onclick = () => {
        const row = rows.find((r) => r.code === btn.dataset.code);
        if (!row) return;
        openModal({
          title: `Sửa gói Coach: ${row.name}`,
          subtitle: `Mã gói ${row.code} · Thay đổi chỉ áp dụng cho giao dịch mới`,
          bodyHtml: `<form id="coach-pkg-form" novalidate>
            <div class="meta-modal-body">
              <div class="field"><label class="field-label" for="cp-price">Giá (VND)</label><input id="cp-price" class="form-control tabular" name="price" type="number" min="0" value="${esc(row.price)}" required /></div>
              <div class="field"><label class="field-label" for="cp-status">Trạng thái</label><select id="cp-status" class="form-select" name="status"><option value="ACTIVE" ${row.status === 'ACTIVE' ? 'selected' : ''}>Đang bán</option><option value="INACTIVE" ${row.status === 'INACTIVE' ? 'selected' : ''}>Ngừng bán</option></select></div>
            </div>
            <div class="meta-modal-footer"><button type="button" class="btn btn-ghost" data-close-modal>Hủy</button><button type="submit" class="btn btn-primary" data-modal-submit>Lưu gói</button></div>
          </form>`,
          onMount(ctrl) {
            const form = ctrl.dialog.querySelector('#coach-pkg-form');
            form.onsubmit = async (event) => {
              event.preventDefault();
              ctrl.showError('');
              ctrl.setBusy(true);
              try {
                await api(`/admin/coach-packages/${encodeURIComponent(row.code)}`, 'PATCH', {
                  price: Number(form.querySelector('[name="price"]')?.value),
                  status: form.querySelector('[name="status"]')?.value || 'ACTIVE',
                });
                ctrl.close();
                toast('Đã lưu gói Coach.');
                await renderCoachPackagesPage({ root, params, shell });
              } catch (error) {
                ctrl.setBusy(false);
                ctrl.showError(error.message);
              }
            };
          },
        });
      };
    });
  } catch (error) {
    shell({ section: 'coach-packages', contentHtml: renderErrorState({ title: 'Không tải được gói Coach', message: error.message }) });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderCoachPackagesPage({ root, params, shell });
  }
}
