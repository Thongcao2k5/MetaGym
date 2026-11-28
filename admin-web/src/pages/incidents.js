import { api, buildQuery } from '../services/api.js';
import {
  debounce,
  esc,
  formatDateTimeVN,
  formatDateVN,
  initials,
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
import { notice, toast } from '../components/toast.js';
import { updateQuery } from '../state/router.js';
import { createIdempotencyManager } from './payments.js';

const INELIGIBLE_REASON_LABELS = {
  COACH_FULL: 'COACH_FULL · Đã đủ trần 8 suất',
  SCHEDULE_REQUIRED: 'SCHEDULE_REQUIRED · Chưa cấu hình lịch tuần',
  CAPACITY_UNAVAILABLE: 'CAPACITY_UNAVAILABLE · Không đủ công suất cho gói ACTIVE + QUEUED',
};

function formatIneligibleReason(code) {
  return INELIGIBLE_REASON_LABELS[code] || code || 'Không đủ điều kiện';
}

function renderEntitlementSummaryCell(row) {
  const parts = [];
  if (row.activeEntitlement) {
    const ae = row.activeEntitlement;
    parts.push(`<div>
      <span class="person-name">${esc(ae.planName || ae.planCode || 'Gói Coach')}</span>
      <span class="person-sub tabular">ACTIVE · còn ${Number(ae.remainingSessions ?? 0)}/${Number(ae.totalSessions ?? 0)} buổi</span>
    </div>`);
  }
  if (row.queuedEntitlement) {
    const qe = row.queuedEntitlement;
    parts.push(`<div style="margin-top:4px">
      <span class="meta-badge meta-badge-info tabular">+ Chờ: ${esc(qe.planName || qe.planCode || 'Gói chờ')} (${Number(qe.totalSessions ?? 0)} buổi · 100%)</span>
    </div>`);
  }
  return parts.length ? parts.join('') : '<span class="person-sub">Không có gói đang hoạt động</span>';
}

function renderIncidentDetailHtml(row) {
  const frozenDays = Number(row.frozenDaysCurrent ?? row.frozenDaysApplied ?? 0);
  const ae = row.activeEntitlement;
  const qe = row.queuedEntitlement;

  return `<div class="stack-16">
    <div class="impact-box">
      <div class="impact-row"><span class="impact-key">UUID sự cố</span><span class="impact-val tabular" style="font-size:12px">${esc(row.id)}</span></div>
      <div class="impact-row"><span class="impact-key">UUID quan hệ</span><span class="impact-val tabular" style="font-size:12px">${esc(row.relationshipId || '—')}</span></div>
      <div class="impact-row"><span class="impact-key">Hội viên</span><span class="impact-val">${esc(row.memberName || 'Hội viên')}${row.memberEmail ? ` (${esc(row.memberEmail)})` : ''}</span></div>
      <div class="impact-row"><span class="impact-key">Coach bị khóa</span><span class="impact-val">${esc(row.coachName || 'Coach')}${row.coachEmail ? ` (${esc(row.coachEmail)})` : ''}</span></div>
      <div class="impact-row"><span class="impact-key">Trạng thái sự cố</span><span class="impact-val">${statusBadge(row.status || 'OPEN')}</span></div>
      <div class="impact-row"><span class="impact-key">Lựa chọn Member</span><span class="impact-val">${statusBadge(row.memberChoice || 'WAIT')}</span></div>
      ${row.memberChoiceNote ? `<div class="impact-row"><span class="impact-key">Ghi chú Member</span><span class="impact-val">${esc(row.memberChoiceNote)}</span></div>` : ''}
      <div class="impact-row"><span class="impact-key">Gói Gym của Member</span><span class="impact-val">${statusBadge(row.memberGymMembershipStatus || 'NONE')}${row.memberGymMembershipEndDate ? ` · đến ${formatDateVN(row.memberGymMembershipEndDate)}` : ''}</span></div>
      <div class="impact-divider"></div>
      <div class="impact-row"><span class="impact-key">Thời điểm khóa Coach</span><span class="impact-val tabular">${formatDateTimeVN(row.lockedAt)}</span></div>
      <div class="impact-row"><span class="impact-key">Số ngày đang đóng băng</span><span class="impact-val tabular">${frozenDays} ngày</span></div>
      <div class="impact-row"><span class="impact-key">Lý do khóa Coach</span><span class="impact-val">${esc(row.lockReason || '—')}</span></div>
      ${row.resolvedAt ? `<div class="impact-row"><span class="impact-key">Xử lý lúc</span><span class="impact-val tabular">${formatDateTimeVN(row.resolvedAt)}${row.resolvedByName ? ` · ${esc(row.resolvedByName)}` : ''}</span></div>` : ''}
    </div>

    <div class="field">
      <span class="field-label">Chi tiết gói Coach & Ước tính hoàn mô phỏng (D3)</span>
      <div class="impact-box tabular">
        ${ae ? `
          <div class="impact-row"><span class="impact-key">Gói ACTIVE</span><span class="impact-val">${esc(ae.planName || ae.planCode || 'Gói Coach')} · còn ${Number(ae.remainingSessions ?? 0)}/${Number(ae.totalSessions ?? 0)} buổi</span></div>
          <div class="impact-row"><span class="impact-key">Giá gốc gói ACTIVE</span><span class="impact-val">${vnd(ae.snapshotPrice ?? 0)}</span></div>
          <div class="impact-row"><span class="impact-key">Ước tính hoàn ACTIVE</span><span class="impact-val">${vnd(row.estimatedActiveRefund ?? 0)}</span></div>
        ` : '<div class="impact-row"><span class="impact-key">Gói ACTIVE</span><span class="impact-val">Không có</span></div>'}
        ${qe ? `
          <div class="impact-divider"></div>
          <div class="impact-row"><span class="impact-key">Gói QUEUED</span><span class="impact-val">${esc(qe.planName || qe.planCode || 'Gói chờ')} · ${Number(qe.totalSessions ?? 0)} buổi</span></div>
          <div class="impact-row"><span class="impact-key">Ước tính hoàn QUEUED (100%)</span><span class="impact-val">${vnd(row.estimatedQueuedRefund ?? 0)}</span></div>
        ` : ''}
        <div class="impact-divider"></div>
        <div class="impact-row"><span class="impact-key"><strong>Tổng ước tính hoàn mô phỏng</strong></span><span class="impact-val" style="color:var(--meta-danger-text)"><strong>${vnd(row.estimatedTotalRefund ?? 0)}</strong></span></div>
      </div>
    </div>
  </div>`;
}

function openIncidentTransferModal(row, onDone) {
  const idem = createIdempotencyManager();
  let selectedCoachId = '';
  let coaches = [];

  openModal({
    title: `Chuyển Coach thay thế (D2) · ${row.memberName || 'Hội viên'}`,
    subtitle: 'Kiểm tra đồng thời trần 8 suất, lịch tuần và công suất cho cả gói ACTIVE + QUEUED',
    maxWidth: '600px',
    bodyHtml: `<form id="inc-transfer-form" novalidate>
      <div class="meta-modal-body">
        <div class="impact-box tabular">
          <div class="impact-row"><span class="impact-key">Hội viên</span><span class="impact-val">${esc(row.memberName || 'Hội viên')}</span></div>
          <div class="impact-row"><span class="impact-key">Coach bị khóa</span><span class="impact-val">${esc(row.coachName || 'Coach')}</span></div>
          <div class="impact-row"><span class="impact-key">Ngày đóng băng dự kiến cộng</span><span class="impact-val">+${Number(row.frozenDaysCurrent ?? 0)} ngày (cộng 1 lần)</span></div>
          <div class="impact-row"><span class="impact-key">Gói chuyển sang Coach mới</span><span class="impact-val">${row.activeEntitlement ? esc(row.activeEntitlement.planName || 'ACTIVE') : '—'}${row.queuedEntitlement ? ` + ${esc(row.queuedEntitlement.planName || 'QUEUED')} (QUEUED)` : ''}</span></div>
        </div>

        <div class="field">
          <span class="field-label">Chọn Coach thay thế (tải từ /eligible-coaches)</span>
          <div id="inc-eligible-list" class="stack-12">${renderSkeletonPage({ cards: 0, rows: 3 })}</div>
        </div>

        <div class="field">
          <label class="field-label" for="inc-transfer-reason">
            <span>Lý do chuyển Coach (bắt buộc 1–1000 ký tự)</span>
            <span id="inc-transfer-count" class="tabular">0/1000</span>
          </label>
          <textarea id="inc-transfer-reason" name="reason" class="form-control" maxlength="1000" required placeholder="Ví dụ: Chuyển sang Coach thay thế còn suất và đủ lịch trống cho gói ACTIVE + QUEUED…"></textarea>
        </div>

        <div class="impact-box">
          <div class="impact-row">
            <span class="impact-key">Idempotency-Key</span>
            <span class="impact-val tabular" id="inc-transfer-idem" style="font-size:11.5px;color:var(--meta-reflection)">Chưa chọn Coach mới</span>
          </div>
        </div>
      </div>
      <div class="meta-modal-footer">
        <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
        <button type="submit" class="btn btn-primary" id="inc-transfer-submit" data-modal-submit disabled>${icon('swap', 16)} Xác nhận chuyển Coach (D2)</button>
      </div>
    </form>`,
    onMount(ctrl) {
      const form = ctrl.dialog.querySelector('#inc-transfer-form');
      const listEl = ctrl.dialog.querySelector('#inc-eligible-list');
      const reasonEl = ctrl.dialog.querySelector('#inc-transfer-reason');
      const countEl = ctrl.dialog.querySelector('#inc-transfer-count');
      const idemEl = ctrl.dialog.querySelector('#inc-transfer-idem');
      const submitBtn = ctrl.dialog.querySelector('#inc-transfer-submit');

      const getSig = () => {
        const reason = (reasonEl?.value || '').trim();
        return selectedCoachId ? `${row.id}:${selectedCoachId}:${reason}` : '';
      };

      const syncState = () => {
        const raw = reasonEl?.value || '';
        const trimmed = raw.trim();
        if (countEl) countEl.textContent = `${raw.length}/1000`;
        if (idemEl) {
          idemEl.textContent = selectedCoachId ? idem.getKey(getSig()) : 'Chưa chọn Coach mới';
        }
        if (submitBtn) {
          submitBtn.disabled = !(selectedCoachId && trimmed.length >= 1 && raw.length <= 1000);
        }
      };

      const renderCoaches = () => {
        if (!listEl) return;
        if (!coaches.length) {
          listEl.innerHTML = renderEmptyState({
            iconName: 'users',
            title: 'Không có Coach thay thế nào đang hoạt động',
            description: 'Bạn có thể tạo thêm Coach hoặc thực hiện hoàn tiền mô phỏng (D3).',
          });
          return;
        }
        listEl.innerHTML = coaches.map((c) => {
          const cid = c.id || c.coachId;
          const isEligible = Boolean(c.eligible && !c.ineligibleReason);
          const isSelected = selectedCoachId === cid;
          const reasonLabel = c.ineligibleReason ? formatIneligibleReason(c.ineligibleReason) : '';
          return `<label class="impact-box${isSelected ? ' is-selected' : ''}" data-coach-option="${esc(cid)}" data-eligible="${isEligible ? '1' : '0'}" style="cursor:${isEligible ? 'pointer' : 'not-allowed'};opacity:${isEligible ? '1' : '0.62'};border-color:${isSelected ? 'var(--meta-primary)' : ''}">
            <div style="display:flex;align-items:flex-start;gap:12px">
              <input type="radio" name="newCoachId" value="${esc(cid)}" ${isSelected ? 'checked' : ''} ${isEligible ? '' : 'disabled'} style="margin-top:4px;min-width:18px;min-height:18px" />
              <div style="flex:1;min-width:0">
                <div style="display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap">
                  <span class="person-name">${esc(c.fullName || 'Coach')}</span>
                  ${isEligible
                    ? '<span class="meta-badge meta-badge-success">Đủ điều kiện (D2)</span>'
                    : `<span class="meta-badge meta-badge-danger" data-ineligible-reason="${esc(c.ineligibleReason || '')}">${esc(reasonLabel)}</span>`}
                </div>
                ${c.email ? `<span class="person-sub">${esc(c.email)}</span>` : ''}
                <div style="margin-top:8px">${seatMeterHtml(c.usedSlots ?? 0, c.memberLimit ?? 8)}</div>
              </div>
            </div>
          </label>`;
        }).join('');

        listEl.querySelectorAll('input[name="newCoachId"]').forEach((radio) => {
          radio.onchange = () => {
            if (radio.disabled) return;
            selectedCoachId = radio.value;
            // Re-render highlight without losing focus or state
            listEl.querySelectorAll('[data-coach-option]').forEach((card) => {
              const active = card.dataset.coachOption === selectedCoachId;
              card.classList?.toggle('is-selected', active);
              if (card.style) card.style.borderColor = active ? 'var(--meta-primary)' : '';
            });
            syncState();
          };
        });
      };

      if (reasonEl) {
        reasonEl.oninput = syncState;
        reasonEl.addEventListener?.('input', syncState);
      }

      api(`/admin/coach-incidents/${encodeURIComponent(row.id)}/eligible-coaches`)
        .then((res) => {
          coaches = res?.data || [];
          renderCoaches();
          syncState();
        })
        .catch((error) => {
          if (listEl) {
            listEl.innerHTML = renderErrorState({
              title: 'Không kiểm tra được danh sách Coach đủ điều kiện',
              message: error?.message || 'Lỗi máy chủ',
            });
          }
        });

      if (form) {
        form.onsubmit = async (event) => {
          event.preventDefault();
          ctrl.showError('');
          const reason = (reasonEl?.value || '').trim();
          if (!selectedCoachId || !reason) {
            ctrl.showError('Vui lòng chọn Coach mới đủ điều kiện và nhập lý do chuyển.');
            return;
          }
          const key = idem.getKey(getSig());
          ctrl.setBusy(true);
          try {
            const res = await api(
              `/admin/coach-incidents/${encodeURIComponent(row.id)}/transfer`,
              'POST',
              { newCoachId: selectedCoachId, reason },
              key,
            );
            idem.reset();
            ctrl.close();
            const added = Number(res?.data?.frozenDaysAdded ?? 0);
            toast(`Đã chuyển Coach thành công${added > 0 ? ` (+${added} ngày đóng băng)` : ''}.`);
            await onDone();
          } catch (error) {
            ctrl.setBusy(false);
            ctrl.showError(error?.message || 'Không thể chuyển Coach. Vui lòng kiểm tra lại.');
            syncState();
          }
        };
      }
    },
  });
}

function openSimulatedRefundModal(row, onDone) {
  const idem = createIdempotencyManager();
  const ae = row.activeEntitlement;
  const qe = row.queuedEntitlement;
  const activeRefund = Number(row.estimatedActiveRefund ?? 0);
  const queuedRefund = Number(row.estimatedQueuedRefund ?? 0);
  const totalRefund = Number(row.estimatedTotalRefund ?? (activeRefund + queuedRefund));

  const activeFormulaText = ae
    ? `⌊(${vnd(ae.snapshotPrice ?? 0)} × ${Number(ae.remainingSessions ?? 0)} / ${Number(ae.totalSessions ?? 0)}) / 1.000⌋ × 1.000`
    : 'Không có gói ACTIVE';

  openConfirmModal({
    title: `Hoàn tiền mô phỏng (D3) · ${row.memberName || 'Hội viên'}`,
    subtitle: 'Tạo bút toán hoàn tiền mô phỏng, đóng gói ACTIVE/QUEUED và giải phóng suất Coach',
    bannerHtml: renderBanner({
      kind: 'danger',
      iconName: 'alert',
      title: 'Thao tác không thể hoàn tác',
      textHtml: 'Gói Coach <code>ACTIVE</code> được tính theo công thức tỷ lệ làm tròn xuống 1.000 ₫; gói <code>QUEUED</code> (nếu có) được hoàn 100% giá gốc snapshot. Quan hệ sẽ chuyển sang <code>ENDED</code>.',
    }),
    impactHtml: `<div class="impact-box tabular">
      <div class="impact-row"><span class="impact-key">Hội viên</span><span class="impact-val">${esc(row.memberName || 'Hội viên')}</span></div>
      <div class="impact-row"><span class="impact-key">Coach bị khóa</span><span class="impact-val">${esc(row.coachName || 'Coach')}</span></div>
      <div class="impact-divider"></div>
      <div class="impact-row">
        <span class="impact-key">Gói ACTIVE (${ae ? esc(ae.planName || ae.planCode || 'ACTIVE') : 'Không có'})</span>
        <span class="impact-val">${vnd(activeRefund)}</span>
      </div>
      ${ae ? `<div class="impact-row"><span class="impact-key" style="font-size:12px">Công thức D3</span><span class="impact-val" style="font-size:12px;color:var(--meta-text-secondary)">${esc(activeFormulaText)}</span></div>` : ''}
      ${qe ? `
        <div class="impact-row">
          <span class="impact-key">Gói QUEUED (${esc(qe.planName || qe.planCode || 'QUEUED')} · 100%)</span>
          <span class="impact-val">${vnd(queuedRefund)}</span>
        </div>
      ` : ''}
      <div class="impact-divider"></div>
      <div class="impact-row">
        <span class="impact-key"><strong>Tổng hoàn tiền mô phỏng</strong></span>
        <span class="impact-val" style="font-size:18px;color:var(--meta-danger-text)"><strong>${vnd(totalRefund)}</strong></span>
      </div>
    </div>`,
    requireReason: true,
    reasonLabel: 'Lý do hoàn tiền mô phỏng (bắt buộc 1–500 ký tự)',
    reasonPlaceholder: 'Ví dụ: Chưa có Coach thay thế phù hợp; Member chọn nhận hoàn tiền mô phỏng…',
    reasonMaxLength: 500,
    confirmLabel: 'Xác nhận hoàn mô phỏng (D3)',
    confirmVariant: 'danger-solid',
    confirmIcon: 'refund',
    onConfirm: async ({ reason }) => {
      const key = idem.getKey(`${row.id}:${reason}`);
      const res = await api(
        `/admin/coach-incidents/${encodeURIComponent(row.id)}/simulated-refunds`,
        'POST',
        { reason },
        key,
      );
      idem.reset();
      const amount = Number(res?.data?.totalRefundAmount ?? totalRefund);
      await onDone();
      notice(`Đã hoàn tiền mô phỏng ${vnd(amount)} cho ${row.memberName || 'hội viên'} (sự cố chuyển RESOLVED_REFUNDED).`, 'warn');
    },
  });
}

function renderRefundDetailHtml(row) {
  return `<div class="stack-16">
    <div class="impact-box">
      <div class="impact-row"><span class="impact-key">UUID bút toán hoàn</span><span class="impact-val tabular" style="font-size:12px">${esc(row.id)}</span></div>
      <div class="impact-row"><span class="impact-key">Batch UUID</span><span class="impact-val tabular" style="font-size:12px">${esc(row.refundBatchId || '—')}</span></div>
      <div class="impact-row"><span class="impact-key">Incident UUID</span><span class="impact-val tabular" style="font-size:12px">${esc(row.incidentId || '—')}</span></div>
      <div class="impact-row"><span class="impact-key">Entitlement UUID</span><span class="impact-val tabular" style="font-size:12px">${esc(row.coachEntitlementId || '—')}</span></div>
      <div class="impact-divider"></div>
      <div class="impact-row"><span class="impact-key">Hội viên</span><span class="impact-val">${esc(row.memberName || 'Hội viên')}${row.memberEmail ? ` (${esc(row.memberEmail)})` : ''}</span></div>
      <div class="impact-row"><span class="impact-key">Coach bị khóa</span><span class="impact-val">${esc(row.coachName || 'Coach')}</span></div>
      <div class="impact-row"><span class="impact-key">Loại gói</span><span class="impact-val">${statusBadge(row.entitlementKind || 'ACTIVE')} · ${esc(row.planName || row.planCode || 'Gói Coach')}</span></div>
      <div class="impact-row"><span class="impact-key">Buổi còn lại / Tổng</span><span class="impact-val tabular">${Number(row.remainingSessions ?? 0)} / ${Number(row.totalSessions ?? 0)} buổi</span></div>
      <div class="impact-row"><span class="impact-key">Giá gốc (Snapshot)</span><span class="impact-val tabular">${vnd(row.snapshotPrice ?? 0)}</span></div>
      <div class="impact-row"><span class="impact-key">Tiền hoàn mô phỏng</span><span class="impact-val tabular" style="color:var(--meta-danger-text)"><strong>${vnd(row.refundAmount ?? 0)}</strong></span></div>
      <div class="impact-row"><span class="impact-key">Lý do</span><span class="impact-val">${esc(row.reason || '—')}</span></div>
      <div class="impact-row"><span class="impact-key">Người thực hiện</span><span class="impact-val">${esc(row.createdByName || 'Admin')}</span></div>
      <div class="impact-row"><span class="impact-key">Thời điểm tạo (VN)</span><span class="impact-val tabular">${formatDateTimeVN(row.createdAt, { withSeconds: true })}</span></div>
    </div>
  </div>`;
}

export async function renderIncidentsPage({ root, params, shell }) {
  const tab = params?.get('tab') === 'refunds' ? 'refunds' : 'incidents';
  const section = tab === 'refunds' ? 'simulated-refunds' : 'coach-incidents';
  const page = Math.max(1, Number(params?.get('page')) || 1);
  const pageSize = Math.max(1, Number(params?.get('pageSize')) || 10);
  const search = params?.get('search') || '';

  // Tab-specific filters
  const status = params?.has('status') ? (params.get('status') || '') : 'OPEN';
  const memberChoice = params?.get('memberChoice') || '';
  const fromDate = params?.get('from') || '';
  const toDate = params?.get('to') || '';

  const hasFilter = tab === 'incidents'
    ? Boolean(search || memberChoice || (status && status !== 'OPEN'))
    : Boolean(search || fromDate || toDate);

  const incidentFilterCount = [memberChoice, status && status !== 'OPEN'].filter(Boolean).length;
  const refundFilterCount = [fromDate || toDate].filter(Boolean).length;

  const buildFilterHtml = (canExport = false) => {
    if (tab === 'refunds') {
      return `<form class="filter-bar" id="inc-filter-form">
        <input type="search" id="inc-search" class="form-control filter-grow" placeholder="Tìm theo tên hội viên, Coach, tên gói hoặc lý do hoàn…" value="${esc(search)}" aria-label="Tìm lịch sử hoàn tiền mô phỏng" />
        <button type="button" class="btn btn-graphite btn-sm filter-trigger-btn" id="inc-filter-btn" aria-label="Mở bộ lọc ngày" title="Bộ lọc">
          ${icon('filter', 16)} <span>Bộ lọc</span>${refundFilterCount > 0 ? `<span class="mobile-filter-count tabular">${refundFilterCount}</span>` : ''}
        </button>
        ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm desktop-filters" id="inc-clear-filters">Xóa bộ lọc</button>' : ''}
        <button type="button" class="btn btn-graphite btn-sm" id="inc-export-excel" ${canExport ? '' : 'disabled'}>
          ${icon('download', 16)} <span id="inc-export-label">Xuất Excel</span>
        </button>
      </form>`;
    }

    return `<form class="filter-bar" id="inc-filter-form">
      <input type="search" id="inc-search" class="form-control filter-grow" placeholder="Tìm theo tên hội viên, Coach, email hoặc lý do khóa…" value="${esc(search)}" aria-label="Tìm kiếm sự cố khóa Coach" />
      <div class="desktop-filters" style="display:contents">
        <select id="inc-status" class="form-select filter-fixed" aria-label="Lọc trạng thái sự cố">
          <option value="OPEN" ${status === 'OPEN' ? 'selected' : ''}>Đang mở (OPEN)</option>
          <option value="ALL" ${!status || status === 'ALL' ? 'selected' : ''}>Tất cả trạng thái</option>
          <option value="RESOLVED_COACH_UNLOCKED" ${status === 'RESOLVED_COACH_UNLOCKED' ? 'selected' : ''}>Đã mở khóa Coach</option>
          <option value="RESOLVED_TRANSFERRED" ${status === 'RESOLVED_TRANSFERRED' ? 'selected' : ''}>Đã chuyển Coach</option>
          <option value="RESOLVED_REFUNDED" ${status === 'RESOLVED_REFUNDED' ? 'selected' : ''}>Đã hoàn mô phỏng</option>
          <option value="RESOLVED_ENDED" ${status === 'RESOLVED_ENDED' ? 'selected' : ''}>Đã kết thúc</option>
        </select>
        <select id="inc-choice" class="form-select filter-fixed" aria-label="Lọc lựa chọn hội viên">
          <option value="" ${!memberChoice ? 'selected' : ''}>Tất cả lựa chọn</option>
          <option value="REFUND" ${memberChoice === 'REFUND' ? 'selected' : ''}>Chọn hoàn mô phỏng</option>
          <option value="WAIT" ${memberChoice === 'WAIT' ? 'selected' : ''}>Chờ mở khóa Coach</option>
        </select>
      </div>
      <button type="button" class="btn btn-graphite btn-sm filter-trigger-btn" id="inc-filter-btn" aria-label="Mở bộ lọc nâng cao" title="Bộ lọc">
        ${icon('filter', 16)} <span>Bộ lọc</span>${incidentFilterCount > 0 ? `<span class="mobile-filter-count tabular">${incidentFilterCount}</span>` : ''}
      </button>
      ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm desktop-filters" id="inc-clear-filters">Xóa bộ lọc</button>' : ''}
      <button type="button" class="btn btn-graphite btn-sm" id="inc-export-excel" ${canExport ? '' : 'disabled'}>
        ${icon('download', 16)} <span id="inc-export-label">Xuất Excel</span>
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
      : (isTabSwitch ? '' : (root.querySelector('#inc-search')?.value?.trim() || ''));
    const nextStatus = patch.status !== undefined
      ? patch.status
      : (isTabSwitch ? 'OPEN' : (root.querySelector('#inc-status')?.value ?? status));
    const nextChoice = patch.memberChoice !== undefined
      ? patch.memberChoice
      : (isTabSwitch ? '' : (root.querySelector('#inc-choice')?.value ?? memberChoice));
    const nextFrom = patch.from !== undefined ? patch.from : (isTabSwitch ? '' : fromDate);
    const nextTo = patch.to !== undefined ? patch.to : (isTabSwitch ? '' : toDate);
    const nextPage = patch.page !== undefined ? patch.page : (isTabSwitch ? 1 : page);
    const nextPageSize = patch.pageSize !== undefined ? patch.pageSize : pageSize;

    const nextParams = new URLSearchParams();
    if (nextTab === 'refunds') nextParams.set('tab', 'refunds');
    if (nextSearch) nextParams.set('search', nextSearch);
    if (nextTab === 'incidents') {
      if (nextStatus && nextStatus !== 'OPEN') nextParams.set('status', nextStatus);
      else if (nextStatus === 'ALL') nextParams.set('status', 'ALL');
      if (nextChoice) nextParams.set('memberChoice', nextChoice);
    } else {
      if (nextFrom) nextParams.set('from', nextFrom);
      if (nextTo) nextParams.set('to', nextTo);
    }
    if (nextPage > 1) nextParams.set('page', String(nextPage));
    if (nextPageSize !== 10) nextParams.set('pageSize', String(nextPageSize));

    updateQuery({
      tab: nextTab === 'refunds' ? 'refunds' : null,
      search: nextSearch || null,
      status: nextTab === 'incidents' && nextStatus && nextStatus !== 'OPEN' ? nextStatus : null,
      memberChoice: nextTab === 'incidents' && nextChoice ? nextChoice : null,
      from: nextTab === 'refunds' && nextFrom ? nextFrom : null,
      to: nextTab === 'refunds' && nextTo ? nextTo : null,
      page: nextPage > 1 ? nextPage : null,
      pageSize: nextPageSize !== 10 ? nextPageSize : null,
    }, { replace: true });

    return renderIncidentsPage({ root, params: nextParams, shell });
  };

  try {
    if (tab === 'refunds') {
      const query = buildQuery({
        search,
        from: fromDate,
        to: toDate,
        page,
        pageSize,
      });
      const result = await api(`/admin/simulated-refunds${query}`);
      const rows = result?.data || result?.items || [];
      const summary = result?.summary || {
        totalRefundAmount: rows.reduce((sum, r) => sum + Number(r.refundAmount || 0), 0),
        count: result?.pagination?.totalItems ?? rows.length,
      };
      const pagination = result?.pagination || { page, pageSize, totalItems: rows.length, totalPages: 1 };

      const kpiHtml = `<div class="grid-2">
        <div class="kpi-card">
          <div class="kpi-top"><span class="kpi-label">Tổng tiền hoàn mô phỏng</span><span class="kpi-icon" style="color:var(--meta-danger)">${icon('refund', 17)}</span></div>
          <div class="kpi-val tabular" style="color:var(--meta-danger-text)">${vnd(summary.totalRefundAmount ?? 0)}</div>
          <div class="kpi-meta"><span>Tính theo bộ lọc hiện tại (ACTIVE + QUEUED)</span></div>
        </div>
        <div class="kpi-card">
          <div class="kpi-top"><span class="kpi-label">Số bút toán hoàn mô phỏng</span><span class="kpi-icon">${icon('receipt', 17)}</span></div>
          <div class="kpi-val tabular">${Number(summary.count ?? pagination.totalItems ?? 0)}</div>
          <div class="kpi-meta"><span>Chỉ phát sinh từ sự cố khóa Coach (D3)</span></div>
        </div>
      </div>`;

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
          label: 'Coach cũ',
          render: (row) => `<span class="person-name">${esc(row.coachName || 'Coach')}</span>`,
        },
        {
          label: 'Gói & Loại',
          render: (row) => `<div>
            <span class="person-name">${esc(row.planName || row.planCode || 'Gói Coach')}</span>
            <div style="margin-top:4px;display:flex;gap:6px;align-items:center;flex-wrap:wrap">
              ${statusBadge(row.entitlementKind || 'ACTIVE')}
              <span class="person-sub tabular">${Number(row.remainingSessions ?? 0)}/${Number(row.totalSessions ?? 0)} buổi</span>
            </div>
          </div>`,
        },
        {
          label: 'Giá gốc / Hoàn (D3)',
          align: 'right',
          render: (row) => `<strong class="tabular" style="color:var(--meta-danger-text)">${vnd(row.refundAmount ?? 0)}</strong>
            <span class="person-sub tabular">Gốc: ${vnd(row.snapshotPrice ?? 0)}</span>`,
        },
        {
          label: 'Lý do & Thời gian',
          render: (row) => `<div>
            <span>${esc(row.reason || '—')}</span>
            <span class="person-sub tabular">${formatDateTimeVN(row.createdAt)}${row.createdByName ? ` · ${esc(row.createdByName)}` : ''}</span>
          </div>`,
        },
        {
          label: 'Thao tác',
          align: 'right',
          render: (row) => `<div class="cell-actions">
            ${renderActionButton({ iconName: 'eye', label: 'Chi tiết bút toán', className: 'detail-ref', permission: 'incidents:read', attrs: `data-id="${esc(row.id)}"` })}
          </div>`,
        },
      ];

      const emptyHtml = hasFilter
        ? renderFilterEmptyState({ resetId: 'inc-filter-reset' })
        : renderEmptyState({
          iconName: 'refund',
          title: 'Chưa có lịch sử hoàn tiền mô phỏng',
          description: 'Mọi bút toán hoàn tiền mô phỏng (D3) thực hiện từ hàng chờ sự cố Coach sẽ hiển thị tại đây.',
        });

      const contentHtml = `<div class="stack-20">
        ${kpiHtml}
        ${buildFilterHtml(rows.length > 0)}
        ${renderDataTable({
          columns,
          rows,
          selectable: true,
          emptyHtml,
          paginationHtml: renderPagination({
            ...pagination,
            prefix: 'ref',
            summaryNote: 'Hiển thị họ tên · UUID nằm trong Drawer chi tiết',
          }),
          ariaLabel: 'Lịch sử hoàn tiền mô phỏng',
        })}
      </div>`;

      shell({ section, contentHtml });

      wireCommonHandlers({
        root,
        tab,
        rows,
        pagination,
        prefix: 'ref',
        reloadWith,
        onOpenFilterModal: () => openRefundFilterModal({ fromDate, toDate, reloadWith }),
        onExport: (targetRows) => {
          const ok = exportToExcel({
            filename: 'metagym-simulated-refunds.csv',
            columns: [
              { label: 'Hội viên', value: (r) => r.memberName || '' },
              { label: 'Coach cũ', value: (r) => r.coachName || '' },
              { label: 'Gói Coach', value: (r) => r.planName || r.planCode || '' },
              { label: 'Loại gói', value: (r) => r.entitlementKind || '' },
              { label: 'Buổi còn/Tổng', value: (r) => `${r.remainingSessions ?? 0}/${r.totalSessions ?? 0}` },
              { label: 'Giá gốc (VND)', value: (r) => Number(r.snapshotPrice ?? 0) },
              { label: 'Tiền hoàn (VND)', value: (r) => Number(r.refundAmount ?? 0) },
              { label: 'Lý do', value: (r) => r.reason || '' },
              { label: 'Thời gian', value: (r) => formatDateTimeVN(r.createdAt) },
            ],
            rows: targetRows,
          });
          if (ok) toast(`Đã xuất ${targetRows.length} dòng lịch sử hoàn mô phỏng ra file Excel (.csv).`);
        },
      });

      root.querySelectorAll('.detail-ref').forEach((btn) => {
        btn.onclick = () => {
          const row = rows.find((r) => String(r.id) === String(btn.dataset.id));
          if (!row) return;
          openDrawer({
            title: `Hoàn mô phỏng · ${row.memberName || 'Hội viên'}`,
            subtitle: 'Chi tiết bút toán hoàn tiền mô phỏng (D3)',
            bodyHtml: renderRefundDetailHtml(row),
          });
        };
      });

      return;
    }

    // Tab: incidents
    const query = buildQuery({
      status: status && status !== 'ALL' ? status : undefined,
      memberChoice: memberChoice || undefined,
      search,
      page,
      pageSize,
    });
    const result = await api(`/admin/coach-incidents${query}`);
    const rows = result?.data || [];
    const pagination = result?.pagination || { page, pageSize, totalItems: rows.length, totalPages: 1 };

    const columns = [
      {
        label: 'Hội viên bị ảnh hưởng',
        render: (row) => `<div class="person-cell">
          <span class="meta-avatar">${esc(initials(row.memberName || 'M'))}</span>
          <div>
            <span class="person-name">${esc(row.memberName || 'Hội viên')}</span>
            <span class="person-sub">Coach cũ: ${esc(row.coachName || 'Coach')}</span>
          </div>
        </div>`,
      },
      {
        label: 'Đóng băng',
        render: (row) => `<span class="meta-badge meta-badge-warning tabular">${Number(row.frozenDaysCurrent ?? row.frozenDaysApplied ?? 0)} ngày</span>
          <span class="person-sub tabular">${formatDateTimeVN(row.lockedAt)}</span>`,
      },
      {
        label: 'Gói Coach (ACTIVE / QUEUED)',
        render: (row) => renderEntitlementSummaryCell(row),
      },
      {
        label: 'Ước tính hoàn (D3)',
        align: 'right',
        render: (row) => `<strong class="tabular">${vnd(row.estimatedTotalRefund ?? 0)}</strong>
          ${row.queuedEntitlement ? '<span class="person-sub">Gồm gói QUEUED 100%</span>' : ''}`,
      },
      {
        label: 'Lựa chọn Member',
        render: (row) => `${statusBadge(row.memberChoice || 'WAIT')}${row.memberChoiceNote ? `<span class="person-sub">${esc(row.memberChoiceNote)}</span>` : ''}`,
      },
      {
        label: 'Trạng thái',
        render: (row) => statusBadge(row.status || 'OPEN'),
      },
      {
        label: 'Thao tác',
        align: 'right',
        render: (row) => {
          const isOpen = (row.status || 'OPEN') === 'OPEN';
          return `<div class="cell-actions">
            ${renderActionButton({
              iconName: 'eye',
              label: 'Chi tiết sự cố',
              className: 'detail-inc',
              permission: 'incidents:read',
              attrs: `data-id="${esc(row.id)}"`,
            })}
            ${renderActionButton({
              iconName: 'swap',
              label: 'Chuyển Coach (D2)',
              className: 'transfer-inc',
              variant: 'graphite',
              permission: 'incidents:transfer',
              disabled: !isOpen,
              disabledReason: !isOpen ? 'Sự cố đã được xử lý' : undefined,
              attrs: `data-id="${esc(row.id)}"`,
            })}
            ${renderActionButton({
              iconName: 'refund',
              label: 'Hoàn tiền mô phỏng (D3)',
              className: 'refund-inc',
              variant: 'danger',
              permission: 'incidents:refund',
              disabled: !isOpen,
              disabledReason: !isOpen ? 'Sự cố đã được xử lý' : undefined,
              attrs: `data-id="${esc(row.id)}"`,
            })}
          </div>`;
        },
      },
    ];

    const emptyHtml = hasFilter
      ? renderFilterEmptyState({ resetId: 'inc-filter-reset' })
      : renderEmptyState({
        iconName: 'check',
        title: 'Không có sự cố khóa Coach nào đang chờ',
        description: 'Mọi hội viên bị ảnh hưởng do COACH_LOCKED đều đã được xử lý hoặc chưa phát sinh sự cố mới.',
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
          prefix: 'inc',
          summaryNote: 'Đóng băng gói Coach · Gói Gym vẫn chạy bình thường',
        }),
        ariaLabel: 'Hàng chờ sự cố khóa Coach',
      })}
    </div>`;

    shell({ section, contentHtml });

    wireCommonHandlers({
      root,
      tab,
      rows,
      pagination,
      prefix: 'inc',
      reloadWith,
      onOpenFilterModal: () => openIncidentFilterModal({ status, memberChoice, reloadWith }),
      onExport: (targetRows) => {
        const ok = exportToExcel({
          filename: 'metagym-coach-incidents.csv',
          columns: [
            { label: 'Hội viên', value: (r) => r.memberName || '' },
            { label: 'Coach cũ', value: (r) => r.coachName || '' },
            { label: 'Ngày đóng băng', value: (r) => Number(r.frozenDaysCurrent ?? r.frozenDaysApplied ?? 0) },
            { label: 'Gói ACTIVE', value: (r) => r.activeEntitlement ? `${r.activeEntitlement.planName || ''} (${r.activeEntitlement.remainingSessions}/${r.activeEntitlement.totalSessions})` : '' },
            { label: 'Gói QUEUED', value: (r) => r.queuedEntitlement ? `${r.queuedEntitlement.planName || ''} (${r.queuedEntitlement.totalSessions})` : '' },
            { label: 'Ước tính hoàn (VND)', value: (r) => Number(r.estimatedTotalRefund ?? 0) },
            { label: 'Lựa chọn Member', value: (r) => r.memberChoice || 'WAIT' },
            { label: 'Trạng thái', value: (r) => r.status || 'OPEN' },
          ],
          rows: targetRows,
        });
        if (ok) toast(`Đã xuất ${targetRows.length} dòng sự cố khóa Coach ra file Excel (.csv).`);
      },
    });

    root.querySelectorAll('.detail-inc').forEach((btn) => {
      btn.onclick = () => {
        const row = rows.find((r) => String(r.id) === String(btn.dataset.id));
        if (!row) return;
        openDrawer({
          title: `Sự cố Coach · ${row.memberName || 'Hội viên'}`,
          subtitle: 'Chi tiết vận hành sự cố COACH_LOCKED',
          bodyHtml: renderIncidentDetailHtml(row),
        });
      };
    });

    root.querySelectorAll('.transfer-inc').forEach((btn) => {
      btn.onclick = () => {
        if (btn.disabled) return;
        const row = rows.find((r) => String(r.id) === String(btn.dataset.id));
        if (row) openIncidentTransferModal(row, () => reloadWith({ page }));
      };
    });

    root.querySelectorAll('.refund-inc').forEach((btn) => {
      btn.onclick = () => {
        if (btn.disabled) return;
        const row = rows.find((r) => String(r.id) === String(btn.dataset.id));
        if (row) openSimulatedRefundModal(row, () => reloadWith({ page }));
      };
    });
  } catch (error) {
    shell({
      section,
      contentHtml: `<div class="stack-20">${renderErrorState({ title: 'Không tải được dữ liệu sự cố Coach', message: error?.message || 'Lỗi kết nối máy chủ' })}</div>`,
    });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderIncidentsPage({ root, params, shell });
  }
}

function wireCommonHandlers({ root, tab, rows, pagination, prefix, reloadWith, onOpenFilterModal, onExport }) {
  const debouncedSearch = debounce(() => reloadWith({ page: 1 }), 280);
  const searchInput = root.querySelector('#inc-search');
  if (searchInput) searchInput.oninput = () => debouncedSearch();

  const filterForm = root.querySelector('#inc-filter-form');
  if (filterForm) {
    filterForm.onsubmit = (ev) => {
      ev.preventDefault();
      debouncedSearch.cancel();
      reloadWith({ page: 1 });
    };
  }

  const statusSelect = root.querySelector('#inc-status');
  if (statusSelect) statusSelect.onchange = () => reloadWith({ status: statusSelect.value, page: 1 });

  const choiceSelect = root.querySelector('#inc-choice');
  if (choiceSelect) choiceSelect.onchange = () => reloadWith({ memberChoice: choiceSelect.value, page: 1 });

  [root.querySelector('#inc-clear-filters'), root.querySelector('#inc-filter-reset')].filter(Boolean).forEach((btn) => {
    btn.onclick = () => reloadWith({ search: '', status: 'OPEN', memberChoice: '', from: '', to: '', page: 1 });
  });

  const filterBtn = root.querySelector('#inc-filter-btn');
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

  const exportLabel = root.querySelector('#inc-export-label');
  const getSelectedIds = bindDataTableSelection(root, {
    onSelectionChange: (ids) => {
      if (exportLabel) {
        exportLabel.textContent = ids.length > 0 ? `Xuất Excel (${ids.length})` : 'Xuất Excel';
      }
    },
  });

  const exportBtn = root.querySelector('#inc-export-excel');
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

function openIncidentFilterModal({ status, memberChoice, reloadWith }) {
  openModal({
    title: 'Bộ lọc sự cố khóa Coach',
    maxWidth: '460px',
    bodyHtml: `<div class="meta-modal-body">
      <div class="field">
        <label class="field-label" for="imf-status">Trạng thái sự cố</label>
        <select id="imf-status" class="form-select">
          <option value="OPEN" ${status === 'OPEN' ? 'selected' : ''}>Đang mở (OPEN)</option>
          <option value="ALL" ${!status || status === 'ALL' ? 'selected' : ''}>Tất cả trạng thái</option>
          <option value="RESOLVED_COACH_UNLOCKED" ${status === 'RESOLVED_COACH_UNLOCKED' ? 'selected' : ''}>Đã mở khóa Coach</option>
          <option value="RESOLVED_TRANSFERRED" ${status === 'RESOLVED_TRANSFERRED' ? 'selected' : ''}>Đã chuyển Coach</option>
          <option value="RESOLVED_REFUNDED" ${status === 'RESOLVED_REFUNDED' ? 'selected' : ''}>Đã hoàn mô phỏng</option>
          <option value="RESOLVED_ENDED" ${status === 'RESOLVED_ENDED' ? 'selected' : ''}>Đã kết thúc</option>
        </select>
      </div>
      <div class="field">
        <label class="field-label" for="imf-choice">Lựa chọn của Hội viên</label>
        <select id="imf-choice" class="form-select">
          <option value="" ${!memberChoice ? 'selected' : ''}>Tất cả lựa chọn</option>
          <option value="REFUND" ${memberChoice === 'REFUND' ? 'selected' : ''}>Chọn hoàn mô phỏng (REFUND)</option>
          <option value="WAIT" ${memberChoice === 'WAIT' ? 'selected' : ''}>Chờ mở khóa Coach (WAIT)</option>
        </select>
      </div>
    </div>`,
    footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Đóng</button>
      <button type="button" class="btn btn-graphite" id="imf-reset">Đặt lại</button>
      <button type="button" class="btn btn-primary" id="imf-apply">Áp dụng</button>`,
    onMount(modal) {
      const dlg = modal.dialog;
      const resetBtn = dlg.querySelector('#imf-reset');
      if (resetBtn) {
        resetBtn.onclick = () => {
          modal.close();
          reloadWith({ search: '', status: 'OPEN', memberChoice: '', page: 1 });
        };
      }
      const applyBtn = dlg.querySelector('#imf-apply');
      if (applyBtn) {
        applyBtn.onclick = () => {
          const nextStatus = dlg.querySelector('#imf-status')?.value || 'ALL';
          const nextChoice = dlg.querySelector('#imf-choice')?.value || '';
          modal.close();
          reloadWith({ status: nextStatus, memberChoice: nextChoice, page: 1 });
        };
      }
    },
  });
}

function openRefundFilterModal({ fromDate, toDate, reloadWith }) {
  openModal({
    title: 'Bộ lọc lịch sử hoàn tiền mô phỏng',
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
              <label class="date-range-label" for="rmf-from-trigger">Từ ngày</label>
              ${renderDateInput({ id: 'rmf-from', value: fromDate, ariaLabel: 'Từ ngày' })}
            </div>
            <div class="date-range-field" style="min-width:0">
              <label class="date-range-label" for="rmf-to-trigger">Đến ngày</label>
              ${renderDateInput({ id: 'rmf-to', value: toDate, ariaLabel: 'Đến ngày' })}
            </div>
          </div>
        </div>
        <div class="mobile-filters">
          ${renderDateRangePicker({ id: 'rmf-range', from: fromDate, to: toDate })}
        </div>
      </div>
    </div>`,
    footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Đóng</button>
      <button type="button" class="btn btn-graphite" id="rmf-reset">Đặt lại</button>
      <button type="button" class="btn btn-primary" id="rmf-apply">Áp dụng</button>`,
    onMount(modal) {
      const dlg = modal.dialog;
      let activeFrom = fromDate;
      let activeTo = toDate;

      bindDatePickers(dlg, {
        onChange: (id, val) => {
          if (id === 'rmf-from') activeFrom = val;
          if (id === 'rmf-to') activeTo = val;
        },
      });
      bindDateRangePicker(dlg, {
        id: 'rmf-range',
        onChange: ({ from, to }) => {
          activeFrom = from;
          activeTo = to;
          setDatePickerValue(dlg, 'rmf-from', from);
          setDatePickerValue(dlg, 'rmf-to', to);
        },
      });

      dlg.querySelectorAll('[data-preset]').forEach((pBtn) => {
        pBtn.onclick = () => {
          dlg.querySelectorAll('[data-preset]').forEach((b) => b.classList?.remove('active'));
          pBtn.classList?.add('active');
          const range = computeDatePreset(pBtn.dataset.preset);
          activeFrom = range.from;
          activeTo = range.to;
          setDatePickerValue(dlg, 'rmf-from', range.from);
          setDatePickerValue(dlg, 'rmf-to', range.to);
        };
      });

      const resetBtn = dlg.querySelector('#rmf-reset');
      if (resetBtn) {
        resetBtn.onclick = () => {
          modal.close();
          reloadWith({ search: '', from: '', to: '', page: 1 });
        };
      }
      const applyBtn = dlg.querySelector('#rmf-apply');
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
