import { api, buildQuery } from '../services/api.js';
import {
  debounce,
  esc,
  formatDateTimeVN,
  formatDateVN,
  generateUuid,
  initials,
  isoDateVN,
  methodLabel,
  statusBadge,
  vnd,
} from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderActionButton } from '../components/action-button.js';
import { bindDataTableSelection, renderDataTable } from '../components/data-table.js';
import { openDrawer } from '../components/drawer.js';
import { exportToExcel } from '../components/export.js';
import { openConfirmModal } from '../components/modal.js';
import { bindPagination, renderPagination } from '../components/pagination.js';
import {
  renderBanner,
  renderEmptyState,
  renderErrorState,
  renderFilterEmptyState,
  renderSkeletonPage,
  renderTableSkeleton,
} from '../components/states.js';
import { notice, toast } from '../components/toast.js';
import { updateQuery } from '../state/router.js';

/**
 * Manages Idempotency-Key lifecycle for financial mutations:
 * - Generates a fresh UUID whenever the payload signature changes.
 * - Reuses the exact same UUID when retrying an identical payload after a network/5xx error.
 * - Resets to a fresh UUID after a confirmed success.
 */
export function createIdempotencyManager(uuidFn = generateUuid) {
  let activeSignature = null;
  let activeKey = null;

  return {
    getKey(signature) {
      if (!activeKey || activeSignature !== signature) {
        activeSignature = signature;
        activeKey = uuidFn();
      }
      return activeKey;
    },
    peekKey() {
      return activeKey;
    },
    reset() {
      activeSignature = null;
      activeKey = null;
    },
  };
}

function predictGymOutcome(member) {
  const endDate = member?.activeMembershipEndDate || member?.activeMembership?.endDate || null;
  if (!endDate) {
    return { status: 'ACTIVE', label: 'Kích hoạt ngay hôm nay (VN)' };
  }
  const today = isoDateVN();
  if (String(endDate) >= today) {
    return {
      status: 'SCHEDULED',
      label: `Gia hạn / nối tiếp sau ${formatDateVN(endDate)}`,
    };
  }
  return { status: 'ACTIVE', label: 'Kích hoạt ngay hôm nay (VN)' };
}

function renderAdjustmentPill(adjustment) {
  if (!adjustment) return '';
  return `<span class="meta-badge meta-badge-danger"><span class="badge-dot"></span>Đã đảo VOID_REVERSAL</span>`;
}

function openVoidReversalModal(paymentRow, onReversed) {
  const idem = createIdempotencyManager();
  const isRenewal = Boolean(paymentRow.renewedMembershipId || paymentRow.membershipId);

  openConfirmModal({
    title: `Đảo giao dịch tại quầy (D6) · ${paymentRow.transactionCode}`,
    subtitle: 'Tuyệt đối không sửa hoặc xóa bản ghi gốc payments — tạo bút toán điều chỉnh VOID_REVERSAL riêng',
    bannerHtml: renderBanner({
      kind: 'warn',
      iconName: 'alert',
      title: 'Bản gốc giao dịch giữ nguyên bất biến',
      textHtml: 'Hệ thống tạo bản ghi <code>payment_adjustments (VOID_REVERSAL)</code>, cập nhật quyền gói Gym tương ứng và ghi Nhật ký Audit.',
    }),
    impactHtml: `<div class="impact-box tabular">
      <div class="impact-row"><span class="impact-key">Mã giao dịch gốc</span><span class="impact-val">${esc(paymentRow.transactionCode)}</span></div>
      <div class="impact-row"><span class="impact-key">Hội viên</span><span class="impact-val">${esc(paymentRow.memberName || 'Hội viên')}${paymentRow.memberEmail ? ` (${esc(paymentRow.memberEmail)})` : ''}</span></div>
      <div class="impact-row"><span class="impact-key">Gói Gym (Snapshot)</span><span class="impact-val">${esc(paymentRow.planName)} (${esc(paymentRow.durationDays)} ngày)</span></div>
      <div class="impact-row"><span class="impact-key">Số tiền gốc</span><span class="impact-val">${vnd(paymentRow.amount)}</span></div>
      <div class="impact-row"><span class="impact-key">Giá trị đảo bút toán</span><span class="impact-val" style="color:var(--meta-danger-text)">${vnd(-Math.abs(Number(paymentRow.amount || 0)))}</span></div>
      <div class="impact-divider"></div>
      <div class="impact-row">
        <span class="impact-key">Tác động gói Gym</span>
        <span class="impact-val">${isRenewal
          ? `Thu hẹp hạn gói gia hạn đi ${esc(paymentRow.durationDays)} ngày (LIFO)`
          : 'Chuyển gói member_memberships tương ứng sang CANCELLED'}</span>
      </div>
    </div>`,
    requireReason: true,
    reasonLabel: 'Lý do đảo giao dịch (bắt buộc 1–500 ký tự)',
    reasonPlaceholder: 'Ví dụ: Thu ngân chọn nhầm gói 90 ngày thay vì gói 30 ngày…',
    reasonMaxLength: 500,
    confirmLabel: 'Xác nhận VOID_REVERSAL (D6)',
    confirmVariant: 'danger-solid',
    confirmIcon: 'refund',
    onConfirm: async ({ reason }) => {
      const key = idem.getKey(`${paymentRow.id}:${reason}`);
      const res = await api(
        `/admin/payments/${encodeURIComponent(paymentRow.id)}/void-reversal`,
        'POST',
        { reason },
        key,
      );
      idem.reset();
      const adj = res?.data?.adjustment;
      const msg = adj
        ? `Đã đảo giao dịch ${paymentRow.transactionCode} (${vnd(-Math.abs(adj.reversedAmount))}). Gói Gym chuyển sang ${adj.newMembershipStatus}.`
        : `Đã tạo bút toán đảo VOID_REVERSAL cho giao dịch ${paymentRow.transactionCode}.`;
      await onReversed();
      notice(msg, 'warn');
    },
  });
}

async function openPaymentDetailDrawer(paymentId, fallbackRow, onReversed) {
  const drawer = openDrawer({
    title: fallbackRow?.transactionCode || 'Chi tiết giao dịch',
    subtitle: 'Chi tiết bút toán Gym, quyền sử dụng & điều chỉnh D6',
    bodyHtml: renderSkeletonPage({ cards: 0, rows: 4 }),
  });

  try {
    const res = await api(`/admin/payments/${encodeURIComponent(paymentId)}`);
    const raw = res?.data || {};
    const payment = raw.payment || raw;
    const membership = raw.membership || payment.membership || null;
    const adjustment = raw.adjustment || payment.adjustment || fallbackRow?.adjustment || null;
    const canVoid = Boolean((payment.canVoidReversal ?? fallbackRow?.canVoidReversal) && !adjustment);
    const blockedReason = payment.voidBlockedReason || fallbackRow?.voidBlockedReason || '';

    const bodyHtml = `<div class="stack-16">
      <div class="impact-box">
        <div class="impact-row"><span class="impact-key">UUID giao dịch</span><span class="impact-val tabular" style="font-size:12px">${esc(payment.id)}</span></div>
        <div class="impact-row"><span class="impact-key">Mã giao dịch</span><span class="impact-val tabular">${esc(payment.transactionCode)}</span></div>
        <div class="impact-row"><span class="impact-key">Hội viên</span><span class="impact-val">${esc(payment.memberName || fallbackRow?.memberName || 'Hội viên')}</span></div>
        ${(payment.memberEmail || fallbackRow?.memberEmail) ? `<div class="impact-row"><span class="impact-key">Email</span><span class="impact-val">${esc(payment.memberEmail || fallbackRow?.memberEmail)}</span></div>` : ''}
        <div class="impact-row"><span class="impact-key">Member UUID</span><span class="impact-val tabular" style="font-size:12px">${esc(payment.memberId || '—')}</span></div>
        <div class="impact-divider"></div>
        <div class="impact-row"><span class="impact-key">Gói Gym (Snapshot)</span><span class="impact-val">${esc(payment.planName)} (${esc(payment.durationDays)} ngày)</span></div>
        <div class="impact-row"><span class="impact-key">Kênh thanh toán</span><span class="impact-val">${esc(methodLabel(payment.method))}</span></div>
        <div class="impact-row"><span class="impact-key">Số tiền</span><span class="impact-val tabular" style="font-size:16px">${vnd(payment.amount)}</span></div>
        <div class="impact-row"><span class="impact-key">Trạng thái</span><span class="impact-val">${statusBadge(payment.status)}</span></div>
        <div class="impact-row"><span class="impact-key">Thời điểm tạo (VN)</span><span class="impact-val tabular">${formatDateTimeVN(payment.createdAt, { withSeconds: true })}</span></div>
        ${payment.confirmedAt ? `<div class="impact-row"><span class="impact-key">Xác nhận lúc (VN)</span><span class="impact-val tabular">${formatDateTimeVN(payment.confirmedAt, { withSeconds: true })}</span></div>` : ''}
      </div>

      <div class="field">
        <span class="field-label">Quyền sử dụng gắn kèm (member_memberships)</span>
        ${membership ? `<div class="impact-box">
          <div class="impact-row"><span class="impact-key">Membership UUID</span><span class="impact-val tabular" style="font-size:12px">${esc(membership.id)}</span></div>
          <div class="impact-row"><span class="impact-key">Trạng thái gói</span><span class="impact-val">${statusBadge(membership.status)}</span></div>
          <div class="impact-row"><span class="impact-key">Thời hạn (GMT+7)</span><span class="impact-val tabular">${formatDateVN(membership.startDate)} → ${formatDateVN(membership.endDate)}</span></div>
        </div>` : '<div class="impact-box"><span class="field-hint">Chưa có bản ghi member_memberships gắn kèm giao dịch này.</span></div>'}
      </div>

      <div class="field">
        <span class="field-label">Điều chỉnh kế toán (payment_adjustments · D6)</span>
        ${adjustment ? `<div class="impact-box">
          <div class="impact-row"><span class="impact-key">Loại điều chỉnh</span><span class="impact-val">${renderAdjustmentPill(adjustment)}</span></div>
          <div class="impact-row"><span class="impact-key">Adjustment UUID</span><span class="impact-val tabular" style="font-size:12px">${esc(adjustment.id)}</span></div>
          <div class="impact-row"><span class="impact-key">Số tiền đảo</span><span class="impact-val tabular" style="color:var(--meta-danger-text)">${vnd(-Math.abs(adjustment.reversedAmount))}</span></div>
          <div class="impact-row"><span class="impact-key">Trạng thái gói trước → sau</span><span class="impact-val">${esc(adjustment.previousMembershipStatus)} → ${esc(adjustment.newMembershipStatus || 'CANCELLED')}</span></div>
          <div class="impact-row"><span class="impact-key">Hạn gói trước → sau</span><span class="impact-val tabular">${formatDateVN(adjustment.previousEndDate)} → ${adjustment.restoredEndDate ? formatDateVN(adjustment.restoredEndDate) : 'Đã hủy'}</span></div>
          <div class="impact-row"><span class="impact-key">Lý do đảo</span><span class="impact-val">${esc(adjustment.reason)}</span></div>
          <div class="impact-row"><span class="impact-key">Thời điểm đảo (VN)</span><span class="impact-val tabular">${formatDateTimeVN(adjustment.createdAt, { withSeconds: true })}</span></div>
        </div>` : `<div class="impact-box">
          <span class="field-hint">${canVoid
            ? 'Giao dịch đủ điều kiện đảo bút toán VOID_REVERSAL (D6).'
            : (blockedReason || 'Chưa có điều chỉnh kế toán cho giao dịch này.')}</span>
          ${canVoid ? `<button type="button" class="btn btn-danger btn-sm" id="drawer-void-btn" style="align-self:flex-start">${icon('refund', 15)} Đảo giao dịch (D6)</button>` : ''}
        </div>`}
      </div>
    </div>`;

    drawer?.setBody(bodyHtml);
    const drawerVoidBtn = drawer?.panel?.querySelector('#drawer-void-btn');
    if (drawerVoidBtn) {
      drawerVoidBtn.onclick = () => {
        drawer.close();
        openVoidReversalModal({ ...fallbackRow, ...payment }, onReversed);
      };
    }
  } catch (error) {
    drawer?.setBody(renderErrorState({ title: 'Không tải được chi tiết giao dịch', message: error.message }));
  }
}

export async function renderPaymentsPage({ root, params, shell }) {
  const statusFilter = params?.get('status') || '';
  const methodFilter = params?.get('method') || '';
  const search = params?.get('search') || '';
  const from = params?.get('from') || '';
  const to = params?.get('to') || '';
  const adjusted = params?.get('adjusted') || '';
  const page = Math.max(1, Number(params?.get('page')) || 1);
  const pageSize = Math.max(1, Number(params?.get('pageSize')) || 10);
  const hasFilter = Boolean(statusFilter || methodFilter || search || from || to || adjusted);

  const buildFilterHtml = (canExport = false) => `<form class="filter-bar" id="pay-filter-form">
    <input type="search" id="pay-search" class="form-control filter-grow" placeholder="Tìm theo mã giao dịch, tên hội viên hoặc email…" value="${esc(search)}" aria-label="Tìm lịch sử giao dịch" />
    <select id="pay-status" class="form-select filter-fixed" aria-label="Lọc trạng thái giao dịch">
      <option value="" ${!statusFilter ? 'selected' : ''}>Tất cả trạng thái</option>
      <option value="SUCCESS" ${statusFilter === 'SUCCESS' ? 'selected' : ''}>Thành công (SUCCESS)</option>
      <option value="PENDING" ${statusFilter === 'PENDING' ? 'selected' : ''}>Đang chờ (PENDING)</option>
      <option value="FAILED" ${statusFilter === 'FAILED' ? 'selected' : ''}>Thất bại (FAILED)</option>
      <option value="CANCELLED" ${statusFilter === 'CANCELLED' ? 'selected' : ''}>Đã hủy (CANCELLED)</option>
    </select>
    <select id="pay-method" class="form-select filter-fixed" aria-label="Lọc phương thức thanh toán">
      <option value="" ${!methodFilter ? 'selected' : ''}>Tất cả phương thức</option>
      <option value="FRONT_DESK" ${methodFilter === 'FRONT_DESK' ? 'selected' : ''}>Tại quầy (FRONT_DESK)</option>
      <option value="MOCK_QR" ${methodFilter === 'MOCK_QR' ? 'selected' : ''}>App QR (MOCK_QR)</option>
      <option value="VNPAY" ${methodFilter === 'VNPAY' ? 'selected' : ''}>VNPay</option>
      <option value="MOMO" ${methodFilter === 'MOMO' ? 'selected' : ''}>MoMo</option>
      <option value="ZALOPAY" ${methodFilter === 'ZALOPAY' ? 'selected' : ''}>ZaloPay</option>
    </select>
    <select id="pay-adjusted" class="form-select filter-fixed" aria-label="Lọc trạng thái điều chỉnh D6">
      <option value="" ${!adjusted ? 'selected' : ''}>Mọi bút toán D6</option>
      <option value="true" ${adjusted === 'true' ? 'selected' : ''}>Đã đảo VOID_REVERSAL</option>
      <option value="false" ${adjusted === 'false' ? 'selected' : ''}>Chưa đảo</option>
    </select>
    <input type="date" id="pay-from" class="form-control tabular" style="max-width:160px" value="${esc(from)}" aria-label="Từ ngày" />
    <input type="date" id="pay-to" class="form-control tabular" style="max-width:160px" value="${esc(to)}" aria-label="Đến ngày" />
    ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm" id="pay-clear">Xóa bộ lọc</button>' : ''}
    <button type="button" class="btn btn-graphite btn-sm" id="pay-export-excel" ${canExport ? '' : 'disabled'}>
      ${icon('download', 16)} <span id="pay-export-label">Xuất Excel</span>
    </button>
  </form>`;

  shell({
    section: 'payments',
    contentHtml: `<div class="stack-20">${buildFilterHtml(false)}${renderTableSkeleton(6)}</div>`,
  });

  const reloadWith = (patch = {}) => {
    const next = {
      status: patch.status !== undefined ? patch.status : (root.querySelector('#pay-status')?.value || ''),
      method: patch.method !== undefined ? patch.method : (root.querySelector('#pay-method')?.value || ''),
      search: patch.search !== undefined ? patch.search : (root.querySelector('#pay-search')?.value?.trim() || ''),
      from: patch.from !== undefined ? patch.from : (root.querySelector('#pay-from')?.value || ''),
      to: patch.to !== undefined ? patch.to : (root.querySelector('#pay-to')?.value || ''),
      adjusted: patch.adjusted !== undefined ? patch.adjusted : (root.querySelector('#pay-adjusted')?.value || ''),
      page: patch.page !== undefined ? patch.page : page,
      pageSize: patch.pageSize !== undefined ? patch.pageSize : pageSize,
    };

    const nextParams = new URLSearchParams();
    for (const [key, val] of Object.entries(next)) {
      if (key === 'page' && Number(val) <= 1) continue;
      if (key === 'pageSize' && Number(val) === 10) continue;
      if (val) nextParams.set(key, String(val));
    }

    updateQuery({
      status: next.status || null,
      method: next.method || null,
      search: next.search || null,
      from: next.from || null,
      to: next.to || null,
      adjusted: next.adjusted || null,
      page: next.page > 1 ? next.page : null,
      pageSize: next.pageSize !== 10 ? next.pageSize : null,
    }, { replace: true });

    return renderPaymentsPage({ root, params: nextParams, shell });
  };

  try {
    const historyQuery = buildQuery({
      status: statusFilter,
      method: methodFilter,
      search,
      from,
      to,
      adjusted,
      page,
      pageSize,
    });

    const [paymentsRes, plansRes, initialMembersRes] = await Promise.all([
      api(`/admin/payments${historyQuery}`),
      api('/admin/membership-plans?status=ACTIVE&pageSize=100'),
      api('/admin/users?role=MEMBER&status=ACTIVE&pageSize=20'),
    ]);

    const rows = paymentsRes?.data || [];
    const pagination = paymentsRes?.pagination || {
      page,
      pageSize,
      totalItems: rows.length,
      totalPages: Math.max(1, Math.ceil(rows.length / pageSize)),
    };
    const activePlans = (plansRes?.data || []).filter((p) => p.status === 'ACTIVE');
    let memberOptions = initialMembersRes?.data || [];
    const totalActiveMembers = Number(initialMembersRes?.pagination?.totalItems ?? memberOptions.length);

    let selectedMember = null;
    let selectedPlan = activePlans[0] || null;
    const frontDeskIdem = createIdempotencyManager();

    const getSelectionSignature = () => (selectedMember && selectedPlan ? `${selectedMember.id}:${selectedPlan.id}` : '');
    const getActiveKey = () => {
      const sig = getSelectionSignature();
      return sig ? frontDeskIdem.getKey(sig) : 'Chưa chọn đủ hội viên & gói';
    };

    const renderFrontDeskPreviewHtml = () => {
      const key = getActiveKey();
      if (!selectedMember || !selectedPlan) {
        return `<div class="impact-box">
          <div class="impact-row"><span class="impact-key">Hội viên</span><span class="impact-val">${selectedMember ? esc(selectedMember.fullName) : 'Chưa chọn hội viên'}</span></div>
          <div class="impact-row"><span class="impact-key">Gói Gym</span><span class="impact-val">${selectedPlan ? esc(selectedPlan.name) : 'Chưa có gói Gym đang bán'}</span></div>
          <div class="impact-divider"></div>
          <div class="impact-row"><span class="impact-key">Số tiền thu tại quầy</span><span class="impact-val tabular" style="font-size:20px">${selectedPlan ? vnd(selectedPlan.price) : '0 ₫'}</span></div>
          <button type="button" class="btn btn-primary" id="fd-confirm-btn" style="width:100%;margin-top:4px" disabled>${icon('check', 16)} Xác nhận thu tiền gói Gym</button>
        </div>`;
      }
      const outcome = predictGymOutcome(selectedMember);
      return `<div class="impact-box">
        <div class="impact-row"><span class="impact-key">Hội viên</span><span class="impact-val">${esc(selectedMember.fullName)}</span></div>
        <div class="impact-row"><span class="impact-key">Email</span><span class="impact-val">${esc(selectedMember.email)}</span></div>
        <div class="impact-row"><span class="impact-key">Gói Gym chọn</span><span class="impact-val">${esc(selectedPlan.name)} (${esc(selectedPlan.durationDays)} ngày)</span></div>
        <div class="impact-row"><span class="impact-key">Trạng thái dự kiến</span><span class="impact-val">${statusBadge(outcome.status)}</span></div>
        <div class="impact-row"><span class="impact-key">Hiệu lực dự kiến (VN)</span><span class="impact-val tabular">${esc(outcome.label)}</span></div>
        <div class="impact-row"><span class="impact-key">Idempotency-Key</span><span class="impact-val tabular" id="fd-idem-display" style="font-size:11.5px;color:var(--meta-reflection)">${esc(key)}</span></div>
        <div class="impact-divider"></div>
        <div class="impact-row"><span class="impact-key">Số tiền thu tại quầy</span><span class="impact-val tabular" style="font-size:20px;color:var(--meta-success)">${vnd(selectedPlan.price)}</span></div>
        <button type="button" class="btn btn-primary" id="fd-confirm-btn" style="width:100%;margin-top:4px">${icon('check', 16)} Xác nhận thu tiền gói Gym</button>
      </div>`;
    };

    const renderComboOptionsHtml = (list, loading = false) => {
      if (loading) {
        return '<div style="padding:12px;color:var(--meta-text-secondary)">Đang tìm kiếm hội viên trên máy chủ…</div>';
      }
      if (!list.length) {
        return '<div style="padding:12px;color:var(--meta-text-secondary)">Không tìm thấy hội viên ACTIVE khớp từ khóa.</div>';
      }
      return list.map((m) => `<button type="button" class="combo-opt ${selectedMember?.id === m.id ? 'selected' : ''}" data-pick-member="${esc(m.id)}" role="option" aria-selected="${selectedMember?.id === m.id}">
        <div>
          <span class="person-name">${esc(m.fullName)}</span>
          <span class="person-sub tabular">${esc(m.email)}${m.phone ? ` · ${esc(m.phone)}` : ''}</span>
        </div>
        ${m.activeMembershipEndDate ? statusBadge('ACTIVE', `Đến ${formatDateVN(m.activeMembershipEndDate)}`) : statusBadge('EXPIRED', 'Chưa có gói')}
      </button>`).join('');
    };

    const tableHtml = renderDataTable({
      columns: [
        {
          label: 'Mã GD / Thời gian',
          render: (row) => `<span class="person-name tabular">${esc(row.transactionCode)}</span><span class="person-sub tabular">${formatDateTimeVN(row.confirmedAt || row.createdAt)}</span>`,
        },
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
          label: 'Gói & Kênh',
          render: (row) => `<span class="person-name">${esc(row.planName)}${row.durationDays ? ` (${esc(row.durationDays)} ngày)` : ''}</span>
            <span class="person-sub">${esc(methodLabel(row.method))}</span>`,
        },
        {
          label: 'Số tiền (VND)',
          align: 'right',
          render: (row) => `<strong class="tabular">${vnd(row.amount)}</strong>${row.adjustment ? `<span class="person-sub tabular" style="color:var(--meta-danger-text)">Đảo ${vnd(-Math.abs(row.adjustment.reversedAmount ?? row.amount))}</span>` : ''}`,
        },
        {
          label: 'Trạng thái',
          render: (row) => `<div style="display:flex;flex-direction:column;gap:4px;align-items:flex-start">
            ${statusBadge(row.status)}
            ${renderAdjustmentPill(row.adjustment)}
          </div>`,
        },
        {
          label: 'Thao tác',
          align: 'right',
          render: (row) => {
            const showCancel = row.status === 'PENDING';
            const isFrontDeskSuccess = row.method === 'FRONT_DESK' && row.status === 'SUCCESS';
            const hasVoidSignal = isFrontDeskSuccess || row.canVoidReversal !== undefined || Boolean(row.voidBlockedReason);
            const canVoid = Boolean(row.canVoidReversal && !row.adjustment);
            const blockedTitle = row.adjustment
              ? 'Giao dịch đã được đảo bút toán (VOID_REVERSAL)'
              : (row.voidBlockedReason || 'Giao dịch không đủ điều kiện đảo D6');

            return `<div class="cell-actions">
              ${renderActionButton({
                iconName: 'eye',
                label: 'Chi tiết',
                className: 'detail-pay',
                permission: 'payments:read',
                attrs: `data-id="${esc(row.id)}"`,
              })}
              ${showCancel ? renderActionButton({
                iconName: 'close',
                label: 'Hủy',
                variant: 'danger',
                iconOnly: false,
                className: 'cancel-pay',
                permission: 'payments:update',
                attrs: `data-id="${esc(row.id)}"`,
              }) : ''}
              ${hasVoidSignal && !row.adjustment ? renderActionButton({
                iconName: 'refund',
                iconSize: 14,
                label: 'Đảo giao dịch (D6)',
                variant: 'danger',
                iconOnly: false,
                className: 'void-pay',
                permission: 'payments:void',
                disabled: !canVoid,
                disabledReason: blockedTitle,
                attrs: `data-id="${esc(row.id)}"`,
              }) : ''}
            </div>`;
          },
        },
      ],
      rows,
      selectable: true,
      rowId: (_row, idx) => String(idx),
      emptyHtml: hasFilter
        ? renderFilterEmptyState({ resetId: 'pay-filter-reset' })
        : renderEmptyState({
          iconName: 'receipt',
          title: 'Chưa có giao dịch Gym nào',
          description: 'Sử dụng khung Thu tiền gói Gym tại quầy phía trên để tạo giao dịch đầu tiên.',
        }),
      paginationHtml: renderPagination({
        ...pagination,
        prefix: 'pay',
        summaryNote: 'Hiển thị họ tên hội viên · UUID chỉ nằm trong Drawer chi tiết',
      }),
      ariaLabel: 'Lịch sử giao dịch Gym',
    });

    const contentHtml = `<div class="stack-20">
      <section class="meta-card stack-16" aria-label="Ghi nhận thanh toán gói Gym tại quầy">
        <div class="card-header-row" style="margin-bottom:0">
          <div>
            <h2 class="card-title-text">Ghi nhận thanh toán gói Gym tại quầy</h2>
            <p class="card-sub">CHỈ áp dụng cho Gói Gym · Tìm kiếm hội viên ACTIVE trực tiếp trên máy chủ (hỗ trợ danh sách &gt;100 hội viên).</p>
          </div>
          <span class="meta-badge meta-badge-info">Chỉ gói Gym đang mở bán</span>
        </div>

        <div class="grid-split">
          <div class="stack-16">
            <div class="field combo-wrap">
              <label class="field-label" for="fd-member-search">
                <span>Chọn hội viên ACTIVE (tìm kiếm server-side${totalActiveMembers ? ` · ${totalActiveMembers} hội viên` : ''})</span>
              </label>
              <input id="fd-member-search" class="form-control" type="search" placeholder="Gõ họ tên, email hoặc SĐT để tìm hội viên…" autocomplete="off" aria-autocomplete="list" aria-controls="fd-member-listbox" />
              <div class="combo-list" id="fd-member-listbox" role="listbox" aria-label="Kết quả tìm kiếm hội viên">
                ${renderComboOptionsHtml(memberOptions)}
              </div>
              <span class="field-hint" id="fd-member-selected-hint">Chưa chọn hội viên nào.</span>
            </div>

            <div class="field">
              <label class="field-label" for="fd-plan-select">Chọn gói Gym đang mở bán</label>
              <select id="fd-plan-select" class="form-select" aria-label="Chọn gói Gym đang mở bán">
                ${activePlans.length
                  ? activePlans.map((p) => `<option value="${esc(p.id)}">${esc(p.name)} · ${esc(p.durationDays)} ngày · ${vnd(p.price)}</option>`).join('')
                  : '<option value="">Không có gói Gym nào đang mở bán</option>'}
              </select>
            </div>
          </div>

          <div id="fd-preview-box">${renderFrontDeskPreviewHtml()}</div>
        </div>
      </section>

      ${buildFilterHtml(rows.length > 0)}

      ${tableHtml}
    </div>`;

    shell({ section: 'payments', contentHtml });

    // --- Wire Counter Gym Payment Combobox & Idempotency-Key Manager ---
    const memberInput = root.querySelector('#fd-member-search');
    const listbox = root.querySelector('#fd-member-listbox');
    const hintEl = root.querySelector('#fd-member-selected-hint');
    const planSelect = root.querySelector('#fd-plan-select');
    const previewBox = root.querySelector('#fd-preview-box');

    const syncPreview = () => {
      if (!previewBox) return;
      previewBox.innerHTML = renderFrontDeskPreviewHtml();
      const confirmBtn = previewBox.querySelector('#fd-confirm-btn');
      if (confirmBtn) {
        confirmBtn.onclick = () => {
          if (!selectedMember || !selectedPlan) return;
          const sig = getSelectionSignature();
          const idemKey = frontDeskIdem.getKey(sig);
          const outcome = predictGymOutcome(selectedMember);

          openConfirmModal({
            title: 'Xác nhận đã thu tiền gói Gym tại quầy',
            subtitle: 'Kiểm tra kỹ hội viên, gói Gym và số tiền VND trước khi gửi',
            impactHtml: `<div class="impact-box tabular">
              <div class="impact-row"><span class="impact-key">Hội viên</span><span class="impact-val">${esc(selectedMember.fullName)}</span></div>
              <div class="impact-row"><span class="impact-key">Email</span><span class="impact-val">${esc(selectedMember.email)}</span></div>
              <div class="impact-row"><span class="impact-key">Gói Gym</span><span class="impact-val">${esc(selectedPlan.name)} (${esc(selectedPlan.durationDays)} ngày)</span></div>
              <div class="impact-row"><span class="impact-key">Trạng thái gói</span><span class="impact-val">${statusBadge(outcome.status)}</span></div>
              <div class="impact-row"><span class="impact-key">Idempotency-Key</span><span class="impact-val" style="font-size:11.5px;color:var(--meta-reflection)">${esc(idemKey)}</span></div>
              <div class="impact-divider"></div>
              <div class="impact-row"><span class="impact-key"><strong>Tổng tiền thu</strong></span><span class="impact-val" style="font-size:20px;color:var(--meta-success)">${vnd(selectedPlan.price)}</span></div>
            </div>`,
            confirmLabel: 'Xác nhận ghi nhận',
            confirmVariant: 'primary',
            confirmIcon: 'check',
            onConfirm: async () => {
              const requestKey = frontDeskIdem.getKey(sig);
              const res = await api(
                '/admin/front-desk-payments',
                'POST',
                { memberId: selectedMember.id, planId: selectedPlan.id },
                requestKey,
              );
              frontDeskIdem.reset();
              const txCode = res?.data?.payment?.transactionCode || '';
              const msStatus = res?.data?.membership?.status || outcome.status;
              await reloadWith({ page: 1 });
              notice(`Đã ghi nhận giao dịch ${txCode} (${vnd(selectedPlan.price)}) · Gói Gym ${msStatus}.`);
            },
          });
        };
      }
    };

    const bindComboOptions = () => {
      listbox?.querySelectorAll('[data-pick-member]').forEach((btn) => {
        btn.onclick = () => {
          const picked = memberOptions.find((m) => m.id === btn.dataset.pickMember);
          if (!picked) return;
          selectedMember = picked;
          if (memberInput) memberInput.value = `${picked.fullName} (${picked.email})`;
          if (hintEl) hintEl.textContent = `Đã chọn: ${picked.fullName} · ${picked.email}`;
          listbox.classList.remove('open');
          syncPreview();
        };
      });
    };

    const runMemberSearch = async (queryText) => {
      if (listbox) {
        listbox.classList.add('open');
        listbox.innerHTML = renderComboOptionsHtml([], true);
      }
      try {
        const qs = buildQuery({
          role: 'MEMBER',
          status: 'ACTIVE',
          search: queryText.trim(),
          pageSize: 20,
        });
        const res = await api(`/admin/users${qs}`);
        memberOptions = res?.data || [];
        if (listbox) {
          listbox.innerHTML = renderComboOptionsHtml(memberOptions, false);
          bindComboOptions();
        }
      } catch (error) {
        if (listbox) {
          listbox.innerHTML = `<div style="padding:12px;color:var(--meta-danger-text)">Lỗi tìm hội viên: ${esc(error.message)}</div>`;
        }
      }
    };

    const debouncedMemberSearch = debounce((val) => runMemberSearch(val), 250);
    if (memberInput) {
      memberInput.onfocus = () => {
        listbox?.classList.add('open');
        bindComboOptions();
      };
      memberInput.oninput = (ev) => {
        debouncedMemberSearch(ev.target.value || '');
      };
    }

    if (planSelect) {
      planSelect.onchange = () => {
        selectedPlan = activePlans.find((p) => p.id === planSelect.value) || null;
        syncPreview();
      };
    }

    bindComboOptions();
    syncPreview();

    // --- Wire History Filters & Pagination ---
    const debouncedHistorySearch = debounce(() => reloadWith({ page: 1 }), 280);
    const paySearchEl = root.querySelector('#pay-search');
    if (paySearchEl) paySearchEl.oninput = debouncedHistorySearch;
    const payFilterForm = root.querySelector('#pay-filter-form');
    if (payFilterForm) {
      payFilterForm.onsubmit = (ev) => {
        ev.preventDefault();
        debouncedHistorySearch.cancel();
        reloadWith({ page: 1 });
      };
    }
    ['#pay-status', '#pay-method', '#pay-adjusted', '#pay-from', '#pay-to'].forEach((sel) => {
      const el = root.querySelector(sel);
      if (el) el.onchange = () => reloadWith({ page: 1 });
    });

    [root.querySelector('#pay-clear'), root.querySelector('#pay-filter-reset')].filter(Boolean).forEach((btn) => {
      btn.onclick = () => reloadWith({ status: '', method: '', search: '', from: '', to: '', adjusted: '', page: 1 });
    });

    bindPagination(root, {
      page: pagination.page,
      totalPages: pagination.totalPages,
      prefix: 'pay',
      onChange: (nextPage) => reloadWith({ page: nextPage }),
      onPageSizeChange: (nextSize) => reloadWith({ pageSize: nextSize, page: 1 }),
    });

    const exportLabel = root.querySelector('#pay-export-label');
    const getSelectedIndices = bindDataTableSelection(root, {
      onSelectionChange: (ids) => {
        if (exportLabel) {
          exportLabel.textContent = ids.length > 0 ? `Xuất Excel (${ids.length})` : 'Xuất Excel';
        }
      },
    });

    const exportBtn = root.querySelector('#pay-export-excel');
    if (exportBtn) {
      exportBtn.onclick = () => {
        const selected = getSelectedIndices();
        const targetRows = selected.length > 0
          ? selected.map((idx) => rows[Number(idx)]).filter(Boolean)
          : rows;
        if (!targetRows.length) {
          toast('Chưa có giao dịch để xuất Excel.', 'warn');
          return;
        }
        const ok = exportToExcel({
          filename: 'metagym-payments.csv',
          columns: [
            { label: 'Mã giao dịch', value: (r) => r.transactionCode || '' },
            { label: 'Thời gian', value: (r) => formatDateTimeVN(r.confirmedAt || r.createdAt) },
            { label: 'Hội viên', value: (r) => r.memberName || '' },
            { label: 'Email', value: (r) => r.memberEmail || '' },
            { label: 'Gói Gym', value: (r) => r.planName || '' },
            { label: 'Phương thức', value: (r) => methodLabel(r.method) },
            { label: 'Số tiền (VND)', value: (r) => r.amount ?? 0 },
            { label: 'Trạng thái', value: (r) => r.status || '' },
            { label: 'Điều chỉnh D6', value: (r) => (r.adjustment ? 'VOID_REVERSAL' : '') },
          ],
          rows: targetRows,
        });
        if (ok) toast(`Đã xuất ${targetRows.length} giao dịch ra file Excel (.csv).`);
      };
    }

    // --- Wire Row Actions (Detail Drawer, Cancel PENDING, D6 VOID_REVERSAL) ---
    root.querySelectorAll('.detail-pay').forEach((btn) => {
      btn.onclick = () => {
        const row = rows.find((r) => r.id === btn.dataset.id);
        openPaymentDetailDrawer(btn.dataset.id, row, () => reloadWith({ page }));
      };
    });

    root.querySelectorAll('.cancel-pay').forEach((btn) => {
      btn.onclick = () => {
        const row = rows.find((r) => r.id === btn.dataset.id);
        openConfirmModal({
          title: `Hủy giao dịch đang chờ · ${row?.transactionCode || ''}`,
          subtitle: 'Đánh dấu giao dịch PENDING sang trạng thái CANCELLED',
          requireReason: true,
          reasonLabel: 'Lý do hủy giao dịch (bắt buộc 1–500 ký tự)',
          confirmLabel: 'Xác nhận hủy giao dịch',
          confirmVariant: 'danger-solid',
          onConfirm: async ({ reason }) => {
            await api(`/admin/payments/${encodeURIComponent(btn.dataset.id)}`, 'PATCH', {
              status: 'CANCELLED',
              reason,
            });
            toast('Đã hủy giao dịch.');
            await reloadWith({ page });
          },
        });
      };
    });

    root.querySelectorAll('.void-pay').forEach((btn) => {
      btn.onclick = () => {
        if (btn.disabled) return;
        const row = rows.find((r) => r.id === btn.dataset.id);
        if (row) openVoidReversalModal(row, () => reloadWith({ page }));
      };
    });
  } catch (error) {
    shell({
      section: 'payments',
      contentHtml: renderErrorState({ title: 'Không tải được giao dịch thanh toán', message: error.message }),
    });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderPaymentsPage({ root, params, shell });
  }
}
