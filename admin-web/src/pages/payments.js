import { api } from '../services/api.js';
import { esc, formatDateTimeVN, generateUuid, methodLabel, statusBadge, vnd } from '../components/format.js';
import { renderDataTable } from '../components/data-table.js';
import { openConfirmModal } from '../components/modal.js';
import { renderBanner, renderEmptyState, renderErrorState, renderSkeletonPage } from '../components/states.js';
import { toast } from '../components/toast.js';

export async function renderPaymentsPage({ root, params, shell }) {
  shell({ section: 'payments', contentHtml: renderSkeletonPage({ cards: 0, rows: 6 }) });
  try {
    const [paymentsRes, plansRes, usersRes] = await Promise.all([
      api('/admin/payments'),
      api('/admin/membership-plans?pageSize=100'),
      api('/admin/users?role=MEMBER&status=ACTIVE&pageSize=100'),
    ]);
    const rows = paymentsRes?.data || [];
    const activePlans = (plansRes?.data || []).filter((p) => p.status === 'ACTIVE');
    const activeMembers = (usersRes?.data || []).filter((u) => u.status === 'ACTIVE');
    const memberMap = new Map(activeMembers.map((m) => [m.id, m]));

    const contentHtml = `<div class="stack-20">
      ${renderBanner({
        kind: 'info',
        iconName: 'receipt',
        title: 'Tại quầy chỉ ghi nhận thanh toán gói Gym',
        text: 'Gói Coach được hội viên đăng ký và thanh toán mô phỏng trực tiếp trên ứng dụng.',
      })}
      <form id="front-desk" class="meta-card stack-16">
        <div>
          <h2 class="card-title-text">Ghi nhận thanh toán gói Gym tại quầy</h2>
          <p class="card-sub">Chọn hội viên và gói Gym đang mở bán.</p>
        </div>
        <div class="grid-3">
          <select class="form-select" name="memberId" required aria-label="Chọn hội viên">
            <option value="">Chọn Member</option>
            ${activeMembers.map((m) => `<option value="${esc(m.id)}">${esc(m.fullName)} · ${esc(m.email)}</option>`).join('')}
          </select>
          <select class="form-select" name="planId" required aria-label="Chọn gói Gym">
            <option value="">Chọn gói Gym</option>
            ${activePlans.map((p) => `<option value="${esc(p.id)}">${esc(p.name)} · ${vnd(p.price)}</option>`).join('')}
          </select>
          <button type="submit" class="btn btn-primary">Ghi nhận thanh toán</button>
        </div>
      </form>
      ${renderDataTable({
        columns: [
          {
            label: 'Mã giao dịch',
            render: (row) => `<span class="person-name tabular">${esc(row.transactionCode)}</span><span class="person-sub tabular">${formatDateTimeVN(row.createdAt)}</span>`,
          },
          {
            label: 'Hội viên',
            render: (row) => `<span class="person-name">${esc(row.memberName || memberMap.get(row.memberId)?.fullName || 'Hội viên')}</span>`,
          },
          {
            label: 'Gói & Kênh',
            render: (row) => `<span>${esc(row.planName)}</span><span class="person-sub">${esc(methodLabel(row.method))}</span>`,
          },
          { label: 'Số tiền', align: 'right', render: (row) => `<strong class="tabular">${vnd(row.amount)}</strong>` },
          { label: 'Trạng thái', render: (row) => statusBadge(row.status) },
          {
            label: 'Thao tác',
            align: 'right',
            render: (row) => `<div class="cell-actions">${row.status === 'PENDING' ? `<button type="button" class="btn btn-danger btn-sm cancel" data-id="${esc(row.id)}">Hủy</button>` : '—'}</div>`,
          },
        ],
        rows,
        emptyHtml: renderEmptyState({ iconName: 'receipt', title: 'Chưa có giao dịch nào', description: 'Lịch sử thanh toán gói Gym sẽ hiển thị tại đây.' }),
      })}
    </div>`;

    shell({ section: 'payments', contentHtml });

    let submissionKey = generateUuid();
    let lastSignature = '';
    const form = root.querySelector('#front-desk');
    if (form) {
      form.onsubmit = (event) => {
        event.preventDefault();
        const memberId = form.querySelector('[name="memberId"]')?.value;
        const planId = form.querySelector('[name="planId"]')?.value;
        if (!memberId || !planId) return;
        const sig = `${memberId}:${planId}`;
        if (sig !== lastSignature) {
          submissionKey = generateUuid();
          lastSignature = sig;
        }
        const m = memberMap.get(memberId);
        const p = activePlans.find((item) => item.id === planId);
        openConfirmModal({
          title: 'Xác nhận đã thu tiền gói Gym tại quầy',
          impactHtml: `<div class="impact-box tabular">
            <div class="impact-row"><span class="impact-key">Hội viên</span><span class="impact-val">${esc(m?.fullName || '')}</span></div>
            <div class="impact-row"><span class="impact-key">Gói Gym</span><span class="impact-val">${esc(p?.name || '')}</span></div>
            <div class="impact-row"><span class="impact-key">Số tiền</span><span class="impact-val">${vnd(p?.price)}</span></div>
          </div>`,
          confirmLabel: 'Xác nhận ghi nhận',
          onConfirm: async () => {
            await api('/admin/front-desk-payments', 'POST', { memberId, planId }, submissionKey);
            toast('Đã ghi nhận thanh toán tại quầy.');
            await renderPaymentsPage({ root, params, shell });
          },
        });
      };
    }

    root.querySelectorAll('.cancel').forEach((btn) => {
      btn.onclick = () => {
        openConfirmModal({
          title: 'Hủy giao dịch đang chờ',
          requireReason: true,
          reasonLabel: 'Lý do hủy giao dịch (1–500 ký tự)',
          confirmLabel: 'Xác nhận hủy',
          confirmVariant: 'danger-solid',
          onConfirm: async ({ reason }) => {
            await api(`/admin/payments/${btn.dataset.id}`, 'PATCH', { status: 'CANCELLED', reason });
            toast('Đã hủy giao dịch.');
            await renderPaymentsPage({ root, params, shell });
          },
        });
      };
    });
  } catch (error) {
    shell({ section: 'payments', contentHtml: renderErrorState({ title: 'Không tải được giao dịch', message: error.message }) });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderPaymentsPage({ root, params, shell });
  }
}
