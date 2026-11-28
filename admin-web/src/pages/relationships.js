import { api, buildQuery } from '../services/api.js';
import {
  debounce,
  esc,
  formatDateTimeVN,
  formatDateVN,
  initials,
  relationshipStatusBadge,
  seatMeterHtml,
  statusBadge,
  vnd,
} from '../components/format.js';
import { icon } from '../components/icons.js';
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
import { exportToExcel } from '../components/export.js';
import { openDrawer } from '../components/drawer.js';
import { openConfirmModal, openModal } from '../components/modal.js';
import { bindPagination, renderPagination } from '../components/pagination.js';
import {
  renderBanner,
  renderEmptyState,
  renderErrorState,
  renderFilterEmptyState,
  renderSkeletonPage,
  renderTableSkeleton,
} from '../components/states.js';
import { toast } from '../components/toast.js';
import { updateQuery } from '../state/router.js';
import { createIdempotencyManager } from './payments.js';

function formatCountdown72h(deadlineIso, nowMs = Date.now()) {
  if (!deadlineIso) return '—';
  const targetMs = new Date(deadlineIso).getTime();
  if (Number.isNaN(targetMs)) return formatDateTimeVN(deadlineIso);
  const diffMs = targetMs - nowMs;
  if (diffMs <= 0) {
    return '<span class="meta-badge meta-badge-danger tabular">Đã quá hạn 72h</span>';
  }
  const totalMinutes = Math.floor(diffMs / 60000);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  const tone = hours < 12 ? 'meta-badge-warning' : 'meta-badge-info';
  return `<span class="meta-badge ${tone} tabular">Còn ${hours}g ${String(minutes).padStart(2, '0')}p</span>
    <span class="person-sub tabular">Hạn: ${formatDateTimeVN(deadlineIso)}</span>`;
}

function formatEscalationReason(reason) {
  if (reason === 'TIMEOUT_72H') return 'Quá hạn phản hồi 72h';
  if (reason === 'COUNTERPARTY_REJECTED') return 'Đối tác từ chối';
  return reason || 'Tranh chấp D5';
}

function buildRelationshipDetailHtml(detail) {
  // STRICT PRIVACY ALLOWLIST: NEVER read or render member_profiles health fields, journal, chat, or training/nutrition content
  const ae = detail.activeEntitlement || null;
  const qe = detail.queuedEntitlement || null;
  const transfers = Array.isArray(detail.transferHistory) ? detail.transferHistory : [];
  const terminations = Array.isArray(detail.terminationRequests) ? detail.terminationRequests : [];
  const incidents = Array.isArray(detail.lockIncidents) ? detail.lockIncidents : [];

  return `<div class="stack-16">
    <div class="impact-box">
      <div class="impact-row"><span class="impact-key">UUID quan hệ</span><span class="impact-val tabular" style="font-size:12px">${esc(detail.id)}</span></div>
      <div class="impact-row"><span class="impact-key">Hội viên</span><span class="impact-val">${esc(detail.memberName || 'Hội viên')}${detail.memberEmail ? ` (${esc(detail.memberEmail)})` : ''}</span></div>
      <div class="impact-row"><span class="impact-key">Huấn luyện viên</span><span class="impact-val">${esc(detail.coachName || 'Coach')}${detail.coachEmail ? ` (${esc(detail.coachEmail)})` : ''}</span></div>
      <div class="impact-row"><span class="impact-key">Trạng thái</span><span class="impact-val">${relationshipStatusBadge(detail)}</span></div>
      <div class="impact-row"><span class="impact-key">Bắt đầu</span><span class="impact-val tabular">${formatDateTimeVN(detail.startedAt)}</span></div>
      ${detail.pausedAt ? `<div class="impact-row"><span class="impact-key">Tạm ngưng lúc</span><span class="impact-val tabular">${formatDateTimeVN(detail.pausedAt)}</span></div>` : ''}
      ${detail.endedAt ? `<div class="impact-row"><span class="impact-key">Kết thúc lúc</span><span class="impact-val tabular">${formatDateTimeVN(detail.endedAt)}</span></div>` : ''}
      ${detail.endReason ? `<div class="impact-row"><span class="impact-key">Lý do kết thúc</span><span class="impact-val">${esc(detail.endReason)}</span></div>` : ''}
      <div class="impact-divider"></div>
      <div class="impact-row"><span class="impact-key">Lịch tập tương lai (BOOKED)</span><span class="impact-val tabular">${Number(detail.upcomingBookingsCount ?? 0)} buổi</span></div>
      <div class="impact-row"><span class="impact-key">Suất giữ chỗ 15p (HELD)</span><span class="impact-val tabular">${Number(detail.openHoldsCount ?? 0)} hold</span></div>
    </div>

    <div class="field">
      <span class="field-label">Quyền lợi gói Coach (ACTIVE / QUEUED)</span>
      <div class="impact-box tabular">
        ${ae ? `
          <div class="impact-row"><span class="impact-key">Gói ACTIVE</span><span class="impact-val">${esc(ae.planName || ae.planCode || 'Gói Coach')} · ${statusBadge('ACTIVE')}</span></div>
          <div class="impact-row"><span class="impact-key">Buổi còn lại</span><span class="impact-val">${Number(ae.remainingSessions ?? 0)} / ${Number(ae.totalSessions ?? 0)} buổi</span></div>
          <div class="impact-row"><span class="impact-key">Thời hạn (VN)</span><span class="impact-val">${formatDateVN(ae.startsOn)} → ${formatDateVN(ae.endsOn)}</span></div>
          ${ae.snapshotPrice !== null && ae.snapshotPrice !== undefined ? `<div class="impact-row"><span class="impact-key">Giá gốc (Snapshot)</span><span class="impact-val">${vnd(ae.snapshotPrice)}</span></div>` : ''}
          ${ae.frozenAt ? `<div class="impact-row"><span class="impact-key">Đang đóng băng từ</span><span class="impact-val">${formatDateTimeVN(ae.frozenAt)}</span></div>` : ''}
        ` : '<div class="impact-row"><span class="impact-key">Gói ACTIVE</span><span class="impact-val">Không có</span></div>'}
        <div class="impact-divider"></div>
        ${qe ? `
          <div class="impact-row"><span class="impact-key">Gói QUEUED</span><span class="impact-val">${esc(qe.planName || qe.planCode || 'Gói chờ')} · ${statusBadge('QUEUED')}</span></div>
          <div class="impact-row"><span class="impact-key">Số buổi chờ</span><span class="impact-val">${Number(qe.totalSessions ?? 0)} buổi (${Number(qe.durationDays ?? 0)} ngày)</span></div>
          ${qe.snapshotPrice !== null && qe.snapshotPrice !== undefined ? `<div class="impact-row"><span class="impact-key">Giá gốc (Snapshot)</span><span class="impact-val">${vnd(qe.snapshotPrice)}</span></div>` : ''}
        ` : '<div class="impact-row"><span class="impact-key">Gói QUEUED</span><span class="impact-val">Không có gói chờ</span></div>'}
      </div>
    </div>

    ${terminations.length ? `<div class="field">
      <span class="field-label">Yêu cầu kết thúc sớm (${terminations.length})</span>
      <div class="stack-12">${terminations.slice(0, 5).map((t) => `<div class="impact-box">
        <div class="impact-row">${statusBadge(t.status)}<span class="field-hint tabular">${formatDateTimeVN(t.createdAt)}</span></div>
        <div class="field-hint">${esc(t.requestedByRole || '')}: ${esc(t.reason || '—')}</div>
        ${t.adminNote ? `<div class="field-hint">Phán quyết Admin: ${esc(t.adminNote)}</div>` : ''}
      </div>`).join('')}</div>
    </div>` : ''}

    ${incidents.length ? `<div class="field">
      <span class="field-label">Sự cố khóa Coach (${incidents.length})</span>
      <div class="stack-12">${incidents.slice(0, 5).map((inc) => `<div class="impact-box">
        <div class="impact-row">${statusBadge(inc.status)}<span class="field-hint tabular">${formatDateTimeVN(inc.lockedAt)}</span></div>
        <div class="field-hint">${esc(inc.lockReason || '—')}</div>
      </div>`).join('')}</div>
    </div>` : ''}

    ${transfers.length ? `<div class="field">
      <span class="field-label">Lịch sử chuyển Coach (${transfers.length})</span>
      <div class="stack-12">${transfers.slice(0, 5).map((tr) => `<div class="impact-box">
        <div class="impact-row"><span class="impact-val">${esc(tr.oldCoachName || 'Coach cũ')} → ${esc(tr.newCoachName || 'Coach mới')}</span><span class="field-hint tabular">${formatDateTimeVN(tr.createdAt)}</span></div>
        <div class="field-hint">${esc(tr.reason || '—')}</div>
      </div>`).join('')}</div>
    </div>` : ''}
  </div>`;
}

function buildTerminationDetailHtml(row) {
  return `<div class="stack-16">
    <div class="impact-box">
      <div class="impact-row"><span class="impact-key">UUID yêu cầu</span><span class="impact-val tabular" style="font-size:12px">${esc(row.id)}</span></div>
      <div class="impact-row"><span class="impact-key">UUID quan hệ</span><span class="impact-val tabular" style="font-size:12px">${esc(row.relationshipId || '—')}</span></div>
      <div class="impact-row"><span class="impact-key">Hội viên</span><span class="impact-val">${esc(row.memberName || 'Hội viên')}</span></div>
      <div class="impact-row"><span class="impact-key">Huấn luyện viên</span><span class="impact-val">${esc(row.coachName || 'Coach')}</span></div>
      <div class="impact-row"><span class="impact-key">Trạng thái</span><span class="impact-val">${statusBadge(row.status)}</span></div>
      <div class="impact-divider"></div>
      <div class="impact-row"><span class="impact-key">Người gửi</span><span class="impact-val">${esc(row.requestedByName || '—')} (${esc(row.requestedByRole || '—')})</span></div>
      <div class="impact-row"><span class="impact-key">Lý do gửi</span><span class="impact-val">${esc(row.reason || '—')}</span></div>
      <div class="impact-row"><span class="impact-key">Thời điểm gửi</span><span class="impact-val tabular">${formatDateTimeVN(row.createdAt)}</span></div>
      ${row.responseDeadlineAt ? `<div class="impact-row"><span class="impact-key">Hạn phản hồi 72h</span><span class="impact-val tabular">${formatDateTimeVN(row.responseDeadlineAt)}</span></div>` : ''}
      ${row.counterpartyDecision ? `<div class="impact-row"><span class="impact-key">Phản hồi đối tác</span><span class="impact-val">${esc(row.counterpartyDecision)}${row.counterpartyReason ? ` — ${esc(row.counterpartyReason)}` : ''}</span></div>` : ''}
      ${row.disputedAt ? `<div class="impact-row"><span class="impact-key">Leo thang DISPUTED</span><span class="impact-val tabular">${formatDateTimeVN(row.disputedAt)} (${esc(formatEscalationReason(row.escalationReason))})</span></div>` : ''}
      ${row.adminNote ? `<div class="impact-row"><span class="impact-key">Phán quyết Admin</span><span class="impact-val">${esc(row.adminNote)}</span></div>` : ''}
      ${row.decidedAt ? `<div class="impact-row"><span class="impact-key">Thời điểm phán quyết</span><span class="impact-val tabular">${formatDateTimeVN(row.decidedAt)}${row.decidedByName ? ` · ${esc(row.decidedByName)}` : ''}</span></div>` : ''}
    </div>
  </div>`;
}

function buildTransferDetailHtml(row) {
  return `<div class="stack-16">
    <div class="impact-box">
      <div class="impact-row"><span class="impact-key">UUID chuyển Coach</span><span class="impact-val tabular" style="font-size:12px">${esc(row.id)}</span></div>
      <div class="impact-row"><span class="impact-key">Quan hệ cũ UUID</span><span class="impact-val tabular" style="font-size:12px">${esc(row.oldRelationshipId || '—')}</span></div>
      <div class="impact-row"><span class="impact-key">Quan hệ mới UUID</span><span class="impact-val tabular" style="font-size:12px">${esc(row.newRelationshipId || '—')}</span></div>
      <div class="impact-divider"></div>
      <div class="impact-row"><span class="impact-key">Hội viên</span><span class="impact-val">${esc(row.memberName || 'Hội viên')}</span></div>
      <div class="impact-row"><span class="impact-key">Coach cũ</span><span class="impact-val">${esc(row.oldCoachName || 'Coach cũ')}</span></div>
      <div class="impact-row"><span class="impact-key">Coach mới</span><span class="impact-val"><strong>${esc(row.newCoachName || 'Coach mới')}</strong></span></div>
      <div class="impact-row"><span class="impact-key">Admin thực hiện</span><span class="impact-val">${esc(row.adminName || 'Admin')}</span></div>
      <div class="impact-row"><span class="impact-key">Lý do chuyển</span><span class="impact-val">${esc(row.reason || '—')}</span></div>
      <div class="impact-row"><span class="impact-key">Thời gian (VN)</span><span class="impact-val tabular">${formatDateTimeVN(row.createdAt, { withSeconds: true })}</span></div>
    </div>
  </div>`;
}

function openDirectTransferModal(rel, onDone) {
  const idem = createIdempotencyManager();
  let candidates = [];

  openModal({
    title: `Chuyển Coach · ${rel.memberName || 'Hội viên'}`,
    subtitle: 'Bảo toàn gói ACTIVE + QUEUED, kiểm tra trần 8 suất & công suất Coach mới (D2)',
    maxWidth: '520px',
    bodyHtml: `<form id="rel-transfer-form" novalidate>
      <div class="meta-modal-body">
        <div class="impact-box">
          <div class="impact-row"><span class="impact-key">Hội viên</span><span class="impact-val">${esc(rel.memberName || 'Hội viên')}</span></div>
          <div class="impact-row"><span class="impact-key">Coach hiện tại</span><span class="impact-val">${esc(rel.coachName || 'Coach')}</span></div>
          <div class="impact-row"><span class="impact-key">Trạng thái quan hệ</span><span class="impact-val">${relationshipStatusBadge(rel)}</span></div>
        </div>
        <div class="field">
          <label class="field-label" for="trf-coach">Chọn Coach mới (ACTIVE)</label>
          <select id="trf-coach" class="form-select" name="newCoachId" required>
            <option value="">Đang tải danh sách Coach…</option>
          </select>
          <div id="trf-coach-meter" style="margin-top:8px"></div>
        </div>
        <div class="field">
          <label class="field-label" for="trf-reason">
            <span>Lý do chuyển Coach (bắt buộc 1–1000 ký tự)</span>
            <span id="trf-reason-count" class="tabular">0/1000</span>
          </label>
          <textarea id="trf-reason" class="form-control" name="reason" maxlength="1000" required placeholder="Nhập lý do chuyển Coach…"></textarea>
        </div>
        <div class="impact-box">
          <div class="impact-row">
            <span class="impact-key">Idempotency-Key</span>
            <span class="impact-val tabular" id="trf-idem-display" style="font-size:11.5px;color:var(--meta-reflection)">Chưa chọn Coach mới</span>
          </div>
        </div>
      </div>
      <div class="meta-modal-footer">
        <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
        <button type="submit" class="btn btn-primary" id="trf-submit" data-modal-submit disabled>${icon('swap', 16)} Xác nhận chuyển Coach</button>
      </div>
    </form>`,
    onMount(ctrl) {
      const form = ctrl.dialog.querySelector('#rel-transfer-form');
      const selectEl = ctrl.dialog.querySelector('#trf-coach');
      const meterEl = ctrl.dialog.querySelector('#trf-coach-meter');
      const reasonEl = ctrl.dialog.querySelector('#trf-reason');
      const countEl = ctrl.dialog.querySelector('#trf-reason-count');
      const idemEl = ctrl.dialog.querySelector('#trf-idem-display');
      const submitBtn = ctrl.dialog.querySelector('#trf-submit');

      const getSig = () => {
        const newCoachId = selectEl?.value || '';
        const reason = (reasonEl?.value || '').trim();
        return newCoachId ? `${rel.memberId}:${newCoachId}:${reason}` : '';
      };

      const syncState = () => {
        const newCoachId = selectEl?.value || '';
        const raw = reasonEl?.value || '';
        const trimmed = raw.trim();
        if (countEl) countEl.textContent = `${raw.length}/1000`;
        if (idemEl) idemEl.textContent = newCoachId ? idem.getKey(getSig()) : 'Chưa chọn Coach mới';
        if (meterEl) {
          const picked = candidates.find((c) => c.id === newCoachId);
          meterEl.innerHTML = picked ? seatMeterHtml(picked.usedSlots ?? 0, 8, picked.openHoldCount ?? 0) : '';
        }
        if (submitBtn) {
          submitBtn.disabled = !(newCoachId && trimmed.length >= 1 && raw.length <= 1000);
        }
      };

      if (selectEl) selectEl.onchange = syncState;
      if (reasonEl) {
        reasonEl.oninput = syncState;
        reasonEl.addEventListener?.('input', syncState);
      }

      api('/admin/users?role=COACH&status=ACTIVE&pageSize=100')
        .then((res) => {
          candidates = (res?.data || []).filter((c) => c.status === 'ACTIVE' && c.id !== rel.coachId);
          if (selectEl) {
            selectEl.innerHTML = `<option value="">Chọn Coach mới</option>${candidates.map((c) => {
              const used = Number(c.usedSlots ?? 0);
              const full = used >= 8;
              return `<option value="${esc(c.id)}" ${full ? 'disabled' : ''}>${esc(c.fullName)} (${used}/8 suất${full ? ' · Đã đủ trần' : ''})</option>`;
            }).join('')}`;
          }
          syncState();
        })
        .catch((error) => {
          ctrl.showError(error?.message || 'Không tải được danh sách Coach.');
        });

      if (form) {
        form.onsubmit = async (event) => {
          event.preventDefault();
          ctrl.showError('');
          const newCoachId = selectEl?.value || '';
          const reason = (reasonEl?.value || '').trim();
          if (!newCoachId || !reason) {
            ctrl.showError('Vui lòng chọn Coach mới và nhập lý do chuyển.');
            return;
          }
          const key = idem.getKey(getSig());
          ctrl.setBusy(true);
          try {
            await api('/admin/coach-transfers', 'POST', { memberId: rel.memberId, newCoachId, reason }, key);
            idem.reset();
            ctrl.close();
            toast('Đã chuyển Coach thành công.');
            await onDone();
          } catch (error) {
            ctrl.setBusy(false);
            ctrl.showError(error?.message || 'Không thể chuyển Coach.');
            syncState();
          }
        };
      }
    },
  });
}

function openAdjudicationModal(row, decision, onDone) {
  const isApprove = decision === 'APPROVED';
  const targetStatus = isApprove ? 'ADMIN_APPROVED' : 'ADMIN_REJECTED';

  openConfirmModal({
    title: isApprove
      ? `Phán quyết chấp thuận kết thúc sớm (${targetStatus})`
      : `Phán quyết từ chối kết thúc sớm (${targetStatus})`,
    subtitle: 'Bắt buộc ghi rõ lý do phán quyết (D5) để lưu Nhật ký Hệ thống',
    bannerHtml: renderBanner({
      kind: isApprove ? 'danger' : 'info',
      iconName: isApprove ? 'alert' : 'info',
      title: isApprove
        ? 'Quan hệ sẽ kết thúc ngay · Không hoàn tiền'
        : 'Quan hệ tiếp tục duy trì hoạt động',
      textHtml: isApprove
        ? 'Chấp thuận sẽ chuyển trạng thái sang <code>ADMIN_APPROVED</code>, hủy lịch tương lai (không trừ buổi), lưu trữ giáo án/thực đơn chỉ đọc, hủy số buổi còn lại và giải phóng suất Coach.'
        : 'Từ chối sẽ chuyển yêu cầu sang <code>ADMIN_REJECTED</code>; quan hệ Member–Coach và gói hiện tại giữ nguyên.',
    }),
    impactHtml: `<div class="impact-box">
      <div class="impact-row"><span class="impact-key">Quan hệ</span><span class="impact-val">${esc(row.memberName || 'Hội viên')} ↔ ${esc(row.coachName || 'Coach')}</span></div>
      <div class="impact-row"><span class="impact-key">Người gửi yêu cầu</span><span class="impact-val">${esc(row.requestedByName || '—')} (${esc(row.requestedByRole || '—')})</span></div>
      <div class="impact-row"><span class="impact-key">Lý do gửi</span><span class="impact-val">${esc(row.reason || '—')}</span></div>
      ${row.counterpartyReason ? `<div class="impact-row"><span class="impact-key">Lý do đối tác từ chối</span><span class="impact-val">${esc(row.counterpartyReason)}</span></div>` : ''}
      ${row.escalationReason ? `<div class="impact-row"><span class="impact-key">Lý do leo thang</span><span class="impact-val">${esc(formatEscalationReason(row.escalationReason))}</span></div>` : ''}
    </div>`,
    requireReason: true,
    reasonLabel: 'Lý do phân xử của Admin (bắt buộc 1–1000 ký tự)',
    reasonPlaceholder: isApprove
      ? 'Ví dụ: Coach không phản hồi quá 72 giờ; xác nhận kết thúc sớm theo quy định D5…'
      : 'Ví dụ: Chưa đủ căn cứ kết thúc sớm; hai bên tiếp tục lộ trình đã cam kết…',
    reasonMaxLength: 1000,
    confirmLabel: isApprove ? 'Xác nhận ADMIN_APPROVED' : 'Xác nhận ADMIN_REJECTED',
    confirmVariant: isApprove ? 'danger-solid' : 'primary',
    confirmIcon: isApprove ? 'check' : 'close',
    onConfirm: async ({ reason }) => {
      await api(`/admin/termination-requests/${encodeURIComponent(row.id)}`, 'PATCH', {
        decision,
        reason,
      });
      toast(`Đã ghi nhận phán quyết ${targetStatus}.`);
      await onDone();
    },
  });
}

export async function renderRelationshipsPage({ root, params, shell }) {
  const rawTab = params?.get('tab') || 'list';
  const tab = ['list', 'terminations', 'transfers'].includes(rawTab) ? rawTab : 'list';
  const section = tab === 'terminations' ? 'terminations' : tab === 'transfers' ? 'coach-transfers' : 'relationships';
  const page = Math.max(1, Number(params?.get('page')) || 1);
  const pageSize = Math.max(1, Number(params?.get('pageSize')) || 10);
  const search = params?.get('search') || '';
  const statusFilter = params?.get('status') || '';
  const pauseReasonFilter = params?.get('pauseReason') || '';
  const fromDate = params?.get('from') || '';
  const toDate = params?.get('to') || '';

  const hasFilter = tab === 'list'
    ? Boolean(search || statusFilter || pauseReasonFilter)
    : tab === 'terminations'
      ? Boolean(search || statusFilter)
      : Boolean(search || fromDate || toDate);

  const listFilterCount = [statusFilter, pauseReasonFilter].filter(Boolean).length;
  const termFilterCount = [statusFilter].filter(Boolean).length;
  const transferFilterCount = [fromDate || toDate].filter(Boolean).length;

  const buildFilterHtml = (canExport = false) => {
    if (tab === 'terminations') {
      return `<form class="filter-bar" id="rel-filter-form">
        <input type="search" id="rel-search" class="form-control filter-grow" placeholder="Tìm theo tên hội viên, Coach hoặc lý do kết thúc sớm…" value="${esc(search)}" aria-label="Tìm yêu cầu kết thúc sớm" />
        <div class="desktop-filters" style="display:contents">
          <select id="rel-status" class="form-select filter-fixed" aria-label="Lọc trạng thái yêu cầu">
            <option value="" ${!statusFilter ? 'selected' : ''}>Tất cả trạng thái</option>
            <option value="DISPUTED" ${statusFilter === 'DISPUTED' ? 'selected' : ''}>Tranh chấp (DISPUTED)</option>
            <option value="PENDING_COUNTERPARTY" ${statusFilter === 'PENDING_COUNTERPARTY' ? 'selected' : ''}>Chờ đồng ý 72h</option>
            <option value="ACCEPTED" ${statusFilter === 'ACCEPTED' ? 'selected' : ''}>Hai bên đồng ý</option>
            <option value="ADMIN_APPROVED" ${statusFilter === 'ADMIN_APPROVED' ? 'selected' : ''}>Admin chấp thuận</option>
            <option value="ADMIN_REJECTED" ${statusFilter === 'ADMIN_REJECTED' ? 'selected' : ''}>Admin từ chối</option>
            <option value="CANCELLED" ${statusFilter === 'CANCELLED' ? 'selected' : ''}>Đã hủy</option>
          </select>
        </div>
        <button type="button" class="btn btn-graphite btn-sm filter-trigger-btn" id="rel-filter-btn" aria-label="Mở bộ lọc" title="Bộ lọc">
          ${icon('filter', 16)} <span>Bộ lọc</span>${termFilterCount > 0 ? `<span class="mobile-filter-count tabular">${termFilterCount}</span>` : ''}
        </button>
        ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm desktop-filters" id="rel-clear-filters">Xóa bộ lọc</button>' : ''}
        <button type="button" class="btn btn-graphite btn-sm" id="rel-export-excel" ${canExport ? '' : 'disabled'}>
          ${icon('download', 16)} <span id="rel-export-label">Xuất Excel</span>
        </button>
      </form>`;
    }

    if (tab === 'transfers') {
      return `<form class="filter-bar" id="rel-filter-form">
        <input type="search" id="rel-search" class="form-control filter-grow" placeholder="Tìm theo tên hội viên, Coach cũ, Coach mới hoặc lý do…" value="${esc(search)}" aria-label="Tìm lịch sử chuyển Coach" />
        <button type="button" class="btn btn-graphite btn-sm filter-trigger-btn" id="rel-filter-btn" aria-label="Mở bộ lọc ngày" title="Bộ lọc">
          ${icon('filter', 16)} <span>Bộ lọc</span>${transferFilterCount > 0 ? `<span class="mobile-filter-count tabular">${transferFilterCount}</span>` : ''}
        </button>
        ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm desktop-filters" id="rel-clear-filters">Xóa bộ lọc</button>' : ''}
        <button type="button" class="btn btn-graphite btn-sm" id="rel-export-excel" ${canExport ? '' : 'disabled'}>
          ${icon('download', 16)} <span id="rel-export-label">Xuất Excel</span>
        </button>
      </form>`;
    }

    return `<form class="filter-bar" id="rel-filter-form">
      <input type="search" id="rel-search" class="form-control filter-grow" placeholder="Tìm theo tên hoặc email hội viên, Coach…" value="${esc(search)}" aria-label="Tìm quan hệ Member Coach" />
      <div class="desktop-filters" style="display:contents">
        <select id="rel-status" class="form-select filter-fixed" aria-label="Lọc trạng thái quan hệ">
          <option value="" ${!statusFilter ? 'selected' : ''}>Tất cả trạng thái</option>
          <option value="ACTIVE" ${statusFilter === 'ACTIVE' ? 'selected' : ''}>Đang hoạt động (ACTIVE)</option>
          <option value="PAUSED" ${statusFilter === 'PAUSED' ? 'selected' : ''}>Tạm ngưng (PAUSED)</option>
          <option value="ENDED" ${statusFilter === 'ENDED' ? 'selected' : ''}>Đã kết thúc (ENDED)</option>
        </select>
        <select id="rel-pause-reason" class="form-select filter-fixed" aria-label="Lọc lý do tạm ngưng">
          <option value="" ${!pauseReasonFilter ? 'selected' : ''}>Mọi lý do tạm ngưng</option>
          <option value="COACH_LOCKED" ${pauseReasonFilter === 'COACH_LOCKED' ? 'selected' : ''}>Coach bị khóa</option>
          <option value="MEMBER_LOCKED" ${pauseReasonFilter === 'MEMBER_LOCKED' ? 'selected' : ''}>Member bị khóa</option>
          <option value="MEMBERSHIP_EXPIRED" ${pauseReasonFilter === 'MEMBERSHIP_EXPIRED' ? 'selected' : ''}>Hết gói Gym</option>
        </select>
      </div>
      <button type="button" class="btn btn-graphite btn-sm filter-trigger-btn" id="rel-filter-btn" aria-label="Mở bộ lọc" title="Bộ lọc">
        ${icon('filter', 16)} <span>Bộ lọc</span>${listFilterCount > 0 ? `<span class="mobile-filter-count tabular">${listFilterCount}</span>` : ''}
      </button>
      ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm desktop-filters" id="rel-clear-filters">Xóa bộ lọc</button>' : ''}
      <button type="button" class="btn btn-graphite btn-sm" id="rel-export-excel" ${canExport ? '' : 'disabled'}>
        ${icon('download', 16)} <span id="rel-export-label">Xuất Excel</span>
      </button>
    </form>`;
  };

  // Keep .filter-bar mounted during loading (guidelines §2)
  shell({
    section,
    contentHtml: `<div class="stack-20">${buildFilterHtml(false)}${renderTableSkeleton(6)}</div>`,
  });

  const reloadWith = (patch = {}) => {
    const nextTab = patch.tab !== undefined ? patch.tab : tab;
    const isTabSwitch = nextTab !== tab;
    const nextSearch = patch.search !== undefined
      ? patch.search
      : (isTabSwitch ? '' : (root.querySelector('#rel-search')?.value?.trim() || ''));
    const nextStatus = patch.status !== undefined
      ? patch.status
      : (isTabSwitch ? '' : (root.querySelector('#rel-status')?.value ?? statusFilter));
    const nextPause = patch.pauseReason !== undefined
      ? patch.pauseReason
      : (isTabSwitch ? '' : (root.querySelector('#rel-pause-reason')?.value ?? pauseReasonFilter));
    const nextFrom = patch.from !== undefined ? patch.from : (isTabSwitch ? '' : fromDate);
    const nextTo = patch.to !== undefined ? patch.to : (isTabSwitch ? '' : toDate);
    const nextPage = patch.page !== undefined ? patch.page : (isTabSwitch ? 1 : page);
    const nextPageSize = patch.pageSize !== undefined ? patch.pageSize : pageSize;

    const nextParams = new URLSearchParams();
    if (nextTab !== 'list') nextParams.set('tab', nextTab);
    if (nextSearch) nextParams.set('search', nextSearch);
    if ((nextTab === 'list' || nextTab === 'terminations') && nextStatus) nextParams.set('status', nextStatus);
    if (nextTab === 'list' && nextPause) nextParams.set('pauseReason', nextPause);
    if (nextTab === 'transfers') {
      if (nextFrom) nextParams.set('from', nextFrom);
      if (nextTo) nextParams.set('to', nextTo);
    }
    if (nextPage > 1) nextParams.set('page', String(nextPage));
    if (nextPageSize !== 10) nextParams.set('pageSize', String(nextPageSize));

    updateQuery({
      tab: nextTab !== 'list' ? nextTab : null,
      search: nextSearch || null,
      status: (nextTab === 'list' || nextTab === 'terminations') && nextStatus ? nextStatus : null,
      pauseReason: nextTab === 'list' && nextPause ? nextPause : null,
      from: nextTab === 'transfers' && nextFrom ? nextFrom : null,
      to: nextTab === 'transfers' && nextTo ? nextTo : null,
      page: nextPage > 1 ? nextPage : null,
      pageSize: nextPageSize !== 10 ? nextPageSize : null,
    }, { replace: true });

    return renderRelationshipsPage({ root, params: nextParams, shell });
  };

  try {
    if (tab === 'terminations') {
      const query = buildQuery({
        status: statusFilter || undefined,
        search,
        page,
        pageSize,
      });
      const res = await api(`/admin/termination-requests${query}`);
      const rows = res?.data || [];
      const pagination = res?.pagination || { page, pageSize, totalItems: rows.length, totalPages: 1 };

      const columns = [
        {
          label: 'Quan hệ (Member ↔ Coach)',
          render: (row) => `<div>
            <span class="person-name">${esc(row.memberName || 'Hội viên')} ↔ ${esc(row.coachName || 'Coach')}</span>
            <span class="person-sub">${esc(row.reason || '—')}</span>
            ${row.counterpartyReason ? `<span class="person-sub">Đối tác: ${esc(row.counterpartyReason)}</span>` : ''}
          </div>`,
        },
        {
          label: 'Người gửi / Thời gian',
          render: (row) => `<div>
            <span class="person-name">${esc(row.requestedByName || row.requestedByRole || '—')}</span>
            <span class="person-sub tabular">${esc(row.requestedByRole || '')} · ${formatDateTimeVN(row.createdAt)}</span>
          </div>`,
        },
        {
          label: 'Hạn 72h / Leo thang',
          render: (row) => {
            if (row.status === 'PENDING_COUNTERPARTY') {
              return formatCountdown72h(row.responseDeadlineAt);
            }
            if (row.status === 'DISPUTED') {
              return `<div>
                <span class="meta-badge meta-badge-danger">${esc(formatEscalationReason(row.escalationReason))}</span>
                ${row.disputedAt ? `<span class="person-sub tabular">${formatDateTimeVN(row.disputedAt)}</span>` : ''}
              </div>`;
            }
            return row.decidedAt
              ? `<span class="tabular">${formatDateTimeVN(row.decidedAt)}</span>`
              : '—';
          },
        },
        {
          label: 'Trạng thái',
          render: (row) => statusBadge(row.status),
        },
        {
          label: 'Thao tác',
          align: 'right',
          render: (row) => {
            const actionable = row.status === 'DISPUTED' || row.status === 'PENDING';
            return `<div class="cell-actions">
              ${renderActionButton({
                iconName: 'eye',
                label: 'Chi tiết yêu cầu',
                className: 'detail-term',
                permission: 'relationships:read',
                attrs: `data-id="${esc(row.id)}"`,
              })}
              ${renderActionButton({
                iconName: 'check',
                label: 'Chấp thuận kết thúc (ADMIN_APPROVED)',
                className: 'decide-term',
                variant: 'danger',
                permission: 'relationships:adjudicate',
                disabled: !actionable,
                disabledReason: !actionable ? 'Chỉ phân xử khi yêu cầu ở trạng thái DISPUTED' : undefined,
                attrs: `data-id="${esc(row.id)}" data-decision="APPROVED"`,
              })}
              ${renderActionButton({
                iconName: 'close',
                label: 'Từ chối yêu cầu (ADMIN_REJECTED)',
                className: 'decide-term',
                variant: 'ghost',
                permission: 'relationships:adjudicate',
                disabled: !actionable,
                disabledReason: !actionable ? 'Chỉ phân xử khi yêu cầu ở trạng thái DISPUTED' : undefined,
                attrs: `data-id="${esc(row.id)}" data-decision="REJECTED"`,
              })}
            </div>`;
          },
        },
      ];

      const emptyHtml = hasFilter
        ? renderFilterEmptyState({ resetId: 'rel-filter-reset' })
        : renderEmptyState({
          iconName: 'link',
          title: 'Chưa có yêu cầu kết thúc sớm',
          description: 'Các yêu cầu kết thúc sớm chờ 72h và tranh chấp DISPUTED (D5) sẽ hiển thị tại đây.',
        });

      const contentHtml = `<div class="stack-20">
        ${buildFilterHtml(rows.length > 0)}
        ${renderDataTable({
          columns,
          rows,
          selectable: true,
          emptyHtml,
          paginationHtml: renderPagination({
            ...pagination,
            prefix: 'term',
            summaryNote: 'Tự động leo thang DISPUTED sau 72 giờ không phản hồi',
          }),
          ariaLabel: 'Danh sách yêu cầu kết thúc sớm và tranh chấp D5',
        })}
      </div>`;

      shell({ section, contentHtml });

      wireRelCommonHandlers({
        root,
        tab,
        rows,
        pagination,
        prefix: 'term',
        reloadWith,
        onOpenFilterModal: () => openTermFilterModal({ statusFilter, reloadWith }),
        onExport: (targetRows) => {
          const ok = exportToExcel({
            filename: 'metagym-termination-requests.csv',
            columns: [
              { label: 'Hội viên', value: (r) => r.memberName || '' },
              { label: 'Coach', value: (r) => r.coachName || '' },
              { label: 'Người gửi', value: (r) => `${r.requestedByName || ''} (${r.requestedByRole || ''})` },
              { label: 'Lý do', value: (r) => r.reason || '' },
              { label: 'Hạn 72h', value: (r) => formatDateTimeVN(r.responseDeadlineAt) },
              { label: 'Trạng thái', value: (r) => r.status || '' },
              { label: 'Phán quyết Admin', value: (r) => r.adminNote || '' },
            ],
            rows: targetRows,
          });
          if (ok) toast(`Đã xuất ${targetRows.length} dòng yêu cầu kết thúc sớm ra file Excel (.csv).`);
        },
      });

      root.querySelectorAll('.detail-term').forEach((btn) => {
        btn.onclick = () => {
          const row = rows.find((r) => String(r.id) === String(btn.dataset.id));
          if (!row) return;
          openDrawer({
            title: `${row.memberName || 'Hội viên'} ↔ ${row.coachName || 'Coach'}`,
            subtitle: 'Chi tiết yêu cầu kết thúc sớm & tranh chấp (D5)',
            bodyHtml: buildTerminationDetailHtml(row),
          });
        };
      });

      root.querySelectorAll('.decide-term').forEach((btn) => {
        btn.onclick = () => {
          if (btn.disabled) return;
          const row = rows.find((r) => String(r.id) === String(btn.dataset.id));
          if (row) openAdjudicationModal(row, btn.dataset.decision, () => reloadWith({ page }));
        };
      });

      return;
    }

    if (tab === 'transfers') {
      const query = buildQuery({
        search,
        from: fromDate,
        to: toDate,
        page,
        pageSize,
      });
      const res = await api(`/admin/coach-transfers${query}`);
      const rows = res?.data || [];
      const pagination = res?.pagination || { page, pageSize, totalItems: rows.length, totalPages: 1 };

      const columns = [
        {
          label: 'Hội viên',
          render: (row) => `<div class="person-cell">
            <span class="meta-avatar">${esc(initials(row.memberName || 'M'))}</span>
            <span class="person-name">${esc(row.memberName || 'Hội viên')}</span>
          </div>`,
        },
        {
          label: 'Coach cũ → Coach mới',
          render: (row) => `${esc(row.oldCoachName || 'Coach cũ')} → <strong>${esc(row.newCoachName || 'Coach mới')}</strong>`,
        },
        {
          label: 'Admin thực hiện',
          render: (row) => esc(row.adminName || 'Admin'),
        },
        {
          label: 'Lý do',
          render: (row) => esc(row.reason || '—'),
        },
        {
          label: 'Thời gian (VN)',
          render: (row) => `<span class="tabular">${formatDateTimeVN(row.createdAt)}</span>`,
        },
        {
          label: 'Thao tác',
          align: 'right',
          render: (row) => `<div class="cell-actions">
            ${renderActionButton({
              iconName: 'eye',
              label: 'Chi tiết chuyển Coach',
              className: 'detail-trf',
              permission: 'relationships:read',
              attrs: `data-id="${esc(row.id)}"`,
            })}
          </div>`,
        },
      ];

      const emptyHtml = hasFilter
        ? renderFilterEmptyState({ resetId: 'rel-filter-reset' })
        : renderEmptyState({
          iconName: 'swap',
          title: 'Chưa có lịch sử chuyển Coach',
          description: 'Mọi lần chuyển Coach (D2) sẽ được ghi nhận đầy đủ tại đây.',
        });

      const contentHtml = `<div class="stack-20">
        ${buildFilterHtml(rows.length > 0)}
        ${renderDataTable({
          columns,
          rows,
          selectable: true,
          emptyHtml,
          paginationHtml: renderPagination({
            ...pagination,
            prefix: 'trf',
            summaryNote: 'Hiển thị họ tên · UUID nằm trong Drawer chi tiết',
          }),
          ariaLabel: 'Lịch sử chuyển Coach',
        })}
      </div>`;

      shell({ section, contentHtml });

      wireRelCommonHandlers({
        root,
        tab,
        rows,
        pagination,
        prefix: 'trf',
        reloadWith,
        onOpenFilterModal: () => openTransferFilterModal({ fromDate, toDate, reloadWith }),
        onExport: (targetRows) => {
          const ok = exportToExcel({
            filename: 'metagym-coach-transfers.csv',
            columns: [
              { label: 'Hội viên', value: (r) => r.memberName || '' },
              { label: 'Coach cũ', value: (r) => r.oldCoachName || '' },
              { label: 'Coach mới', value: (r) => r.newCoachName || '' },
              { label: 'Admin thực hiện', value: (r) => r.adminName || '' },
              { label: 'Lý do', value: (r) => r.reason || '' },
              { label: 'Thời gian', value: (r) => formatDateTimeVN(r.createdAt) },
            ],
            rows: targetRows,
          });
          if (ok) toast(`Đã xuất ${targetRows.length} dòng lịch sử chuyển Coach ra file Excel (.csv).`);
        },
      });

      root.querySelectorAll('.detail-trf').forEach((btn) => {
        btn.onclick = () => {
          const row = rows.find((r) => String(r.id) === String(btn.dataset.id));
          if (!row) return;
          openDrawer({
            title: `Chuyển Coach · ${row.memberName || 'Hội viên'}`,
            subtitle: 'Chi tiết lịch sử chuyển Coach (D2)',
            bodyHtml: buildTransferDetailHtml(row),
          });
        };
      });

      return;
    }

    // Tab: list (GET /admin/relationships)
    const query = buildQuery({
      status: statusFilter || undefined,
      pauseReason: pauseReasonFilter || undefined,
      search,
      page,
      pageSize,
    });
    const res = await api(`/admin/relationships${query}`);
    const rows = res?.data || [];
    const pagination = res?.pagination || { page, pageSize, totalItems: rows.length, totalPages: 1 };

    const columns = [
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
        label: 'Huấn luyện viên',
        render: (row) => `<div class="person-cell">
          <span class="meta-avatar meta-avatar-coach">${esc(initials(row.coachName || 'C'))}</span>
          <div>
            <span class="person-name">${esc(row.coachName || 'Coach')}</span>
            ${row.coachEmail ? `<span class="person-sub">${esc(row.coachEmail)}</span>` : ''}
          </div>
        </div>`,
      },
      {
        label: 'Trạng thái',
        render: (row) => `<div style="display:flex;flex-direction:column;gap:4px;align-items:flex-start">
          ${relationshipStatusBadge(row)}
          ${row.openTerminationStatus ? statusBadge(row.openTerminationStatus) : ''}
        </div>`,
      },
      {
        label: 'Gói Coach hiện tại',
        render: (row) => {
          const ae = row.activeEntitlement;
          const parts = [];
          if (ae) {
            parts.push(`<span class="person-name">${esc(ae.planName || ae.planCode || 'Gói Coach')}</span>`);
            parts.push(`<span class="person-sub tabular">Còn ${Number(ae.remainingSessions ?? 0)}/${Number(ae.totalSessions ?? 0)} buổi${ae.endsOn ? ` · đến ${formatDateVN(ae.endsOn)}` : ''}</span>`);
          } else {
            parts.push('<span class="person-sub">Chưa có gói ACTIVE</span>');
          }
          if (row.hasQueuedPackage) {
            parts.push('<span class="meta-badge meta-badge-info" style="margin-top:4px">+ Có gói chờ (QUEUED)</span>');
          }
          return `<div>${parts.join('')}</div>`;
        },
      },
      {
        label: 'Bắt đầu',
        render: (row) => `<span class="tabular">${formatDateTimeVN(row.startedAt)}</span>`,
      },
      {
        label: 'Thao tác',
        align: 'right',
        render: (row) => {
          const canTransfer = row.status === 'ACTIVE' || row.status === 'PAUSED';
          return `<div class="cell-actions">
            ${renderActionButton({
              iconName: 'eye',
              label: 'Chi tiết quan hệ',
              className: 'detail-rel',
              permission: 'relationships:read',
              attrs: `data-id="${esc(row.id)}"`,
            })}
            ${renderActionButton({
              iconName: 'swap',
              label: 'Chuyển Coach',
              className: 'transfer-rel',
              variant: 'graphite',
              permission: 'relationships:transfer',
              disabled: !canTransfer,
              disabledReason: !canTransfer ? 'Chỉ chuyển Coach khi quan hệ ACTIVE hoặc PAUSED' : undefined,
              attrs: `data-id="${esc(row.id)}"`,
            })}
          </div>`;
        },
      },
    ];

    const emptyHtml = hasFilter
      ? renderFilterEmptyState({ resetId: 'rel-filter-reset' })
      : renderEmptyState({
        iconName: 'link',
        title: 'Chưa có quan hệ Member–Coach nào',
        description: 'Khi hội viên đăng ký gói Coach trên ứng dụng, quan hệ sẽ hiển thị tại đây.',
      });

    const contentHtml = `<div class="stack-20">
      ${buildFilterHtml(rows.length > 0)}
      ${renderDataTable({
        columns,
        rows,
        selectable: true,
        emptyHtml,
        paginationHtml: renderPagination({
          ...pagination,
          prefix: 'rel',
          summaryNote: 'Chỉ hiển thị dữ liệu vận hành · bảo vệ quyền riêng tư',
        }),
        ariaLabel: 'Danh sách quan hệ Member Coach',
      })}
    </div>`;

    shell({ section, contentHtml });

    wireRelCommonHandlers({
      root,
      tab,
      rows,
      pagination,
      prefix: 'rel',
      reloadWith,
      onOpenFilterModal: () => openListFilterModal({ statusFilter, pauseReasonFilter, reloadWith }),
      onExport: (targetRows) => {
        const ok = exportToExcel({
          filename: 'metagym-relationships.csv',
          columns: [
            { label: 'Hội viên', value: (r) => r.memberName || '' },
            { label: 'Coach', value: (r) => r.coachName || '' },
            { label: 'Trạng thái', value: (r) => r.pauseReason ? `${r.status} (${r.pauseReason})` : (r.status || '') },
            { label: 'Gói ACTIVE', value: (r) => r.activeEntitlement ? `${r.activeEntitlement.planName || ''} (${r.activeEntitlement.remainingSessions}/${r.activeEntitlement.totalSessions})` : '' },
            { label: 'Có gói chờ', value: (r) => (r.hasQueuedPackage ? 'Có' : 'Không') },
            { label: 'Bắt đầu', value: (r) => formatDateTimeVN(r.startedAt) },
          ],
          rows: targetRows,
        });
        if (ok) toast(`Đã xuất ${targetRows.length} dòng quan hệ Member–Coach ra file Excel (.csv).`);
      },
    });

    // Detail Drawer calling GET /admin/relationships/:id
    root.querySelectorAll('.detail-rel').forEach((btn) => {
      btn.onclick = async () => {
        const rel = rows.find((r) => String(r.id) === String(btn.dataset.id));
        const drawer = openDrawer({
          title: `${rel?.memberName || 'Hội viên'} ↔ ${rel?.coachName || 'Coach'}`,
          subtitle: 'Chi tiết vận hành quan hệ Member–Coach',
          bodyHtml: renderSkeletonPage({ cards: 0, rows: 4 }),
        });
        try {
          const detailRes = await api(`/admin/relationships/${encodeURIComponent(btn.dataset.id)}`);
          const detail = detailRes?.data || rel;
          drawer?.setBody(buildRelationshipDetailHtml(detail));
        } catch (error) {
          drawer?.setBody(renderErrorState({ title: 'Không tải được chi tiết quan hệ', message: error?.message || 'Lỗi máy chủ' }));
        }
      };
    });

    root.querySelectorAll('.transfer-rel').forEach((btn) => {
      btn.onclick = () => {
        if (btn.disabled) return;
        const rel = rows.find((r) => String(r.id) === String(btn.dataset.id));
        if (rel) openDirectTransferModal(rel, () => reloadWith({ page }));
      };
    });
  } catch (error) {
    shell({
      section,
      contentHtml: `<div class="stack-20">${renderErrorState({ title: 'Không tải được dữ liệu quan hệ', message: error?.message || 'Lỗi kết nối máy chủ' })}</div>`,
    });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderRelationshipsPage({ root, params, shell });
  }
}

function wireRelCommonHandlers({ root, tab, rows, pagination, prefix, reloadWith, onOpenFilterModal, onExport }) {
  const debouncedSearch = debounce(() => reloadWith({ page: 1 }), 280);
  const searchInput = root.querySelector('#rel-search');
  if (searchInput) searchInput.oninput = () => debouncedSearch();

  const filterForm = root.querySelector('#rel-filter-form');
  if (filterForm) {
    filterForm.onsubmit = (ev) => {
      ev.preventDefault();
      debouncedSearch.cancel();
      reloadWith({ page: 1 });
    };
  }

  const statusSelect = root.querySelector('#rel-status');
  if (statusSelect) statusSelect.onchange = () => reloadWith({ status: statusSelect.value, page: 1 });

  const pauseSelect = root.querySelector('#rel-pause-reason');
  if (pauseSelect) pauseSelect.onchange = () => reloadWith({ pauseReason: pauseSelect.value, page: 1 });

  [root.querySelector('#rel-clear-filters'), root.querySelector('#rel-filter-reset')].filter(Boolean).forEach((btn) => {
    btn.onclick = () => reloadWith({ search: '', status: '', pauseReason: '', from: '', to: '', page: 1 });
  });

  const filterBtn = root.querySelector('#rel-filter-btn');
  if (filterBtn && typeof onOpenFilterModal === 'function') {
    filterBtn.onclick = onOpenFilterModal;
  }

  bindPagination(root, {
    page: pagination.page,
    totalPages: pagination.totalPages,
    prefix,
    onChange: (nextPage) => reloadWith({ page: nextPage }),
    onPageSizeChange: (nextSize) => reloadWith({ pageSize: nextSize, page: 1 }),
  });

  const exportLabel = root.querySelector('#rel-export-label');
  const getSelectedIds = bindDataTableSelection(root, {
    onSelectionChange: (ids) => {
      if (exportLabel) {
        exportLabel.textContent = ids.length > 0 ? `Xuất Excel (${ids.length})` : 'Xuất Excel';
      }
    },
  });

  const exportBtn = root.querySelector('#rel-export-excel');
  if (exportBtn) {
    exportBtn.onclick = () => {
      const selectedIds = getSelectedIds();
      const targetRows = selectedIds.length > 0
        ? rows.filter((r) => selectedIds.includes(String(r.id)))
        : rows;
      if (!targetRows.length) {
        toast('Chưa có dữ liệu để xuất Excel.', 'warn');
        return;
      }
      onExport(targetRows);
    };
  }
}

function openListFilterModal({ statusFilter, pauseReasonFilter, reloadWith }) {
  openModal({
    title: 'Bộ lọc quan hệ Member–Coach',
    maxWidth: '460px',
    bodyHtml: `<div class="meta-modal-body">
      <div class="field">
        <label class="field-label" for="rlf-status">Trạng thái quan hệ</label>
        <select id="rlf-status" class="form-select">
          <option value="" ${!statusFilter ? 'selected' : ''}>Tất cả trạng thái</option>
          <option value="ACTIVE" ${statusFilter === 'ACTIVE' ? 'selected' : ''}>Đang hoạt động (ACTIVE)</option>
          <option value="PAUSED" ${statusFilter === 'PAUSED' ? 'selected' : ''}>Tạm ngưng (PAUSED)</option>
          <option value="ENDED" ${statusFilter === 'ENDED' ? 'selected' : ''}>Đã kết thúc (ENDED)</option>
        </select>
      </div>
      <div class="field">
        <label class="field-label" for="rlf-pause">Lý do tạm ngưng</label>
        <select id="rlf-pause" class="form-select">
          <option value="" ${!pauseReasonFilter ? 'selected' : ''}>Mọi lý do</option>
          <option value="COACH_LOCKED" ${pauseReasonFilter === 'COACH_LOCKED' ? 'selected' : ''}>Coach bị khóa (COACH_LOCKED)</option>
          <option value="MEMBER_LOCKED" ${pauseReasonFilter === 'MEMBER_LOCKED' ? 'selected' : ''}>Member bị khóa (MEMBER_LOCKED)</option>
          <option value="MEMBERSHIP_EXPIRED" ${pauseReasonFilter === 'MEMBERSHIP_EXPIRED' ? 'selected' : ''}>Hết gói Gym (MEMBERSHIP_EXPIRED)</option>
        </select>
      </div>
    </div>`,
    footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Đóng</button>
      <button type="button" class="btn btn-graphite" id="rlf-reset">Đặt lại</button>
      <button type="button" class="btn btn-primary" id="rlf-apply">Áp dụng</button>`,
    onMount(modal) {
      const dlg = modal.dialog;
      const resetBtn = dlg.querySelector('#rlf-reset');
      if (resetBtn) {
        resetBtn.onclick = () => {
          modal.close();
          reloadWith({ search: '', status: '', pauseReason: '', page: 1 });
        };
      }
      const applyBtn = dlg.querySelector('#rlf-apply');
      if (applyBtn) {
        applyBtn.onclick = () => {
          const nextStatus = dlg.querySelector('#rlf-status')?.value || '';
          const nextPause = dlg.querySelector('#rlf-pause')?.value || '';
          modal.close();
          reloadWith({ status: nextStatus, pauseReason: nextPause, page: 1 });
        };
      }
    },
  });
}

function openTermFilterModal({ statusFilter, reloadWith }) {
  openModal({
    title: 'Bộ lọc yêu cầu kết thúc sớm (D5)',
    maxWidth: '460px',
    bodyHtml: `<div class="meta-modal-body">
      <div class="field">
        <label class="field-label" for="tmf-status">Trạng thái yêu cầu</label>
        <select id="tmf-status" class="form-select">
          <option value="" ${!statusFilter ? 'selected' : ''}>Tất cả trạng thái</option>
          <option value="DISPUTED" ${statusFilter === 'DISPUTED' ? 'selected' : ''}>Tranh chấp (DISPUTED)</option>
          <option value="PENDING_COUNTERPARTY" ${statusFilter === 'PENDING_COUNTERPARTY' ? 'selected' : ''}>Chờ đồng ý 72h (PENDING_COUNTERPARTY)</option>
          <option value="ACCEPTED" ${statusFilter === 'ACCEPTED' ? 'selected' : ''}>Hai bên đồng ý (ACCEPTED)</option>
          <option value="ADMIN_APPROVED" ${statusFilter === 'ADMIN_APPROVED' ? 'selected' : ''}>Admin chấp thuận (ADMIN_APPROVED)</option>
          <option value="ADMIN_REJECTED" ${statusFilter === 'ADMIN_REJECTED' ? 'selected' : ''}>Admin từ chối (ADMIN_REJECTED)</option>
          <option value="CANCELLED" ${statusFilter === 'CANCELLED' ? 'selected' : ''}>Đã hủy (CANCELLED)</option>
        </select>
      </div>
    </div>`,
    footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Đóng</button>
      <button type="button" class="btn btn-graphite" id="tmf-reset">Đặt lại</button>
      <button type="button" class="btn btn-primary" id="tmf-apply">Áp dụng</button>`,
    onMount(modal) {
      const dlg = modal.dialog;
      const resetBtn = dlg.querySelector('#tmf-reset');
      if (resetBtn) {
        resetBtn.onclick = () => {
          modal.close();
          reloadWith({ search: '', status: '', page: 1 });
        };
      }
      const applyBtn = dlg.querySelector('#tmf-apply');
      if (applyBtn) {
        applyBtn.onclick = () => {
          const nextStatus = dlg.querySelector('#tmf-status')?.value || '';
          modal.close();
          reloadWith({ status: nextStatus, page: 1 });
        };
      }
    },
  });
}

function openTransferFilterModal({ fromDate, toDate, reloadWith }) {
  openModal({
    title: 'Bộ lọc lịch sử chuyển Coach',
    maxWidth: '480px',
    bodyHtml: `<div class="meta-modal-body">
      <div class="field">
        <span class="field-label">Khoảng thời gian (GMT+7)</span>
        <div class="desktop-filters">
          <div class="date-preset-grid" style="grid-template-columns:repeat(3,minmax(0,1fr));margin-bottom:10px">
            ${DATE_PRESETS.map((p) => `<button type="button" class="date-preset-btn" data-preset="${p.id}">${esc(p.label)}</button>`).join('')}
          </div>
          <div class="grid-2">
            <div class="date-range-field" style="min-width:0">
              <label class="date-range-label" for="trf-from-trigger">Từ ngày</label>
              ${renderDateInput({ id: 'trf-from', value: fromDate, ariaLabel: 'Từ ngày' })}
            </div>
            <div class="date-range-field" style="min-width:0">
              <label class="date-range-label" for="trf-to-trigger">Đến ngày</label>
              ${renderDateInput({ id: 'trf-to', value: toDate, ariaLabel: 'Đến ngày' })}
            </div>
          </div>
        </div>
        <div class="mobile-filters">
          ${renderDateRangePicker({ id: 'trf-range', from: fromDate, to: toDate })}
        </div>
      </div>
    </div>`,
    footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Đóng</button>
      <button type="button" class="btn btn-graphite" id="trf-reset">Đặt lại</button>
      <button type="button" class="btn btn-primary" id="trf-apply">Áp dụng</button>`,
    onMount(modal) {
      const dlg = modal.dialog;
      let activeFrom = fromDate;
      let activeTo = toDate;

      bindDatePickers(dlg, {
        onChange: (id, val) => {
          if (id === 'trf-from') activeFrom = val;
          if (id === 'trf-to') activeTo = val;
        },
      });
      bindDateRangePicker(dlg, {
        id: 'trf-range',
        onChange: ({ from, to }) => {
          activeFrom = from;
          activeTo = to;
          setDatePickerValue(dlg, 'trf-from', from);
          setDatePickerValue(dlg, 'trf-to', to);
        },
      });

      dlg.querySelectorAll('[data-preset]').forEach((pBtn) => {
        pBtn.onclick = () => {
          dlg.querySelectorAll('[data-preset]').forEach((b) => b.classList?.remove('active'));
          pBtn.classList?.add('active');
          const range = computeDatePreset(pBtn.dataset.preset);
          activeFrom = range.from;
          activeTo = range.to;
          setDatePickerValue(dlg, 'trf-from', range.from);
          setDatePickerValue(dlg, 'trf-to', range.to);
        };
      });

      const resetBtn = dlg.querySelector('#trf-reset');
      if (resetBtn) {
        resetBtn.onclick = () => {
          modal.close();
          reloadWith({ search: '', from: '', to: '', page: 1 });
        };
      }
      const applyBtn = dlg.querySelector('#trf-apply');
      if (applyBtn) {
        applyBtn.onclick = () => {
          if (activeFrom && activeTo && activeFrom > activeTo) {
            toast('Ngày bắt đầu không được lớn hơn ngày kết thúc.', 'warn');
            return;
          }
          modal.close();
          reloadWith({ from: activeFrom || '', to: activeTo || '', page: 1 });
        };
      }
    },
  });
}
