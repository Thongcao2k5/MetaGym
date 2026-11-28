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
} from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderActionButton } from '../components/action-button.js';
import { bindDataTableSelection, renderDataTable } from '../components/data-table.js';
import { bindDatePickers, bindDateRangePicker, renderDateInput, renderDateRangePicker, setDatePickerValue } from '../components/date-picker.js';
import { computeDatePreset, DATE_PRESETS } from '../components/date-range.js';
import { exportToExcel } from '../components/export.js';
import { hasPermission, NO_PERMISSION_REASON } from '../services/permissions.js';
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
import { buildHash, updateQuery } from '../state/router.js';

const DEFAULT_TEMP_PW_REMINDER = 'Hãy gửi mật khẩu tạm cho Coach qua kênh nội bộ và nhắc Coach đổi mật khẩu sau khi đăng nhập.';

function extractMemberGymBadge(row) {
  if (row.activeMembershipEndDate) {
    return `<div>${statusBadge('ACTIVE', 'Gym hiệu lực')}<span class="person-sub tabular">Đến ${formatDateVN(row.activeMembershipEndDate)}</span></div>`;
  }
  if (row.activeMembership?.endDate) {
    return `<div>${statusBadge(row.activeMembership.status || 'ACTIVE')}<span class="person-sub tabular">Đến ${formatDateVN(row.activeMembership.endDate)}</span></div>`;
  }
  if (row.membershipStatus) {
    return statusBadge(row.membershipStatus);
  }
  return statusBadge('EXPIRED', 'Chưa có / Hết hạn');
}

function extractMemberCoachBadge(row) {
  const relObj = row.currentCoachRelationship || row.coachRelationship || row.activeRelationship || null;
  const relStatus = row.coachRelationshipStatus || relObj?.status;
  const pauseReason = row.coachPauseReason ?? relObj?.pauseReason ?? null;
  const coachName = row.coachName || relObj?.coachName;
  if (!relStatus || relStatus === 'NONE') {
    return statusBadge('NONE');
  }
  const badge = relationshipStatusBadge({ status: relStatus, pauseReason });
  return coachName
    ? `<div><span class="person-name">${esc(coachName)}</span><div style="margin-top:4px">${badge}</div></div>`
    : badge;
}

function formatEffectsSummary(role, isLock, effects) {
  if (!effects || typeof effects !== 'object') {
    return isLock
      ? `Đã khóa tài khoản ${role === 'COACH' ? 'Coach' : 'Member'}.`
      : `Đã mở khóa tài khoản ${role === 'COACH' ? 'Coach' : 'Member'}.`;
  }

  if (isLock) {
    const parts = [];
    if (effects.sessionsRevoked) parts.push('đã thu hồi phiên');
    if (Number(effects.affectedRelationshipsCount ?? 0) > 0) {
      parts.push(`${effects.affectedRelationshipsCount} quan hệ bị ảnh hưởng`);
    }
    if (Number(effects.cancelledFutureBookingsCount ?? 0) > 0) {
      parts.push(`hủy ${effects.cancelledFutureBookingsCount} lịch tương lai (không trừ buổi)`);
    }
    if (Number(effects.cancelledHoldsCount ?? 0) > 0) {
      parts.push(`hủy ${effects.cancelledHoldsCount} suất giữ 15p`);
    }
    if (Array.isArray(effects.incidentsCreated) && effects.incidentsCreated.length > 0) {
      parts.push(`tạo ${effects.incidentsCreated.length} sự cố COACH_LOCKED`);
    }
    return parts.length
      ? `Đã khóa tài khoản (${parts.join(' · ')}).`
      : 'Đã khóa tài khoản và cập nhật trạng thái vận hành.';
  }

  // Unlock summary (D1 Coach / D4 Member)
  if (role === 'COACH') {
    const restoredList = Array.isArray(effects.restored) ? effects.restored : [];
    const count = Number(effects.restoredRelationshipsCount ?? restoredList.length ?? 0);
    if (count > 0) {
      const details = restoredList.slice(0, 3).map((item) => {
        const name = item.memberName || 'Hội viên';
        const days = Number(item.frozenDaysAdded ?? 0);
        const ends = item.newEndsOn ? ` → hạn ${formatDateVN(item.newEndsOn)}` : '';
        return `${name} (+${days} ngày${ends})`;
      }).join(', ');
      return `Đã mở khóa Coach (D1): tự động khôi phục ${count} hội viên${details ? ` — ${details}` : ''}.`;
    }
    return 'Đã mở khóa Coach (D1). Không có hội viên chờ nào cần khôi phục.';
  }

  const newStatus = effects.relationshipStatus ?? effects.newRelationshipStatus ?? effects.restoredRelationshipStatus;
  if (newStatus) {
    const pauseReason = effects.pauseReason ?? effects.newPauseReason;
    const pauseNote = pauseReason ? ` (${pauseReason})` : '';
    return `Đã mở khóa Member (D4): quan hệ Coach chuyển sang ${newStatus}${pauseNote}.`;
  }
  return 'Đã mở khóa tài khoản Member (D4).';
}

function buildLockPreviewImpactHtml(role, target, preview) {
  const affectedList = Array.isArray(preview?.affectedMembers)
    ? preview.affectedMembers
    : Array.isArray(preview?.affectedRelationships)
      ? preview.affectedRelationships
      : Array.isArray(preview?.members)
        ? preview.members
        : [];

  const affectedNames = affectedList.map((item) => (
    typeof item === 'string' ? item : (item.memberName || item.fullName || 'Hội viên')
  )).filter(Boolean);

  const affectedCount = Number(
    preview?.affectedRelationshipsCount
    ?? preview?.affectedMembersCount
    ?? affectedNames.length
    ?? 0,
  );
  const cancelledBookings = Number(
    preview?.futureBookingsToCancelCount
    ?? preview?.cancelledFutureBookingsCount
    ?? preview?.futureBookingsCount
    ?? preview?.futureBookings
    ?? 0,
  );
  const cancelledHolds = Number(
    preview?.openHoldsToCancelCount
    ?? preview?.cancelledHoldsCount
    ?? preview?.openHoldCount
    ?? preview?.openHoldsCount
    ?? 0,
  );

  if (role === 'COACH') {
    return {
      bannerHtml: renderBanner({
        kind: 'danger',
        iconName: 'alert',
        title: affectedCount > 0
          ? `Khóa ngay dù còn ${affectedCount} hội viên đang thuê Coach`
          : 'Khóa tài khoản Huấn luyện viên (COACH_LOCKED)',
        textHtml: 'Phiên đăng nhập Coach bị thu hồi ngay lập tức. Toàn bộ quan hệ đang hoạt động chuyển sang <code>PAUSED (COACH_LOCKED)</code>.',
      }),
      impactHtml: `<div class="impact-box">
        <div class="impact-row">
          <span class="impact-key">Hội viên bị ảnh hưởng</span>
          <span class="impact-val tabular">${affectedCount} hội viên${affectedNames.length ? ` (${esc(affectedNames.join(', '))})` : ''}</span>
        </div>
        <div class="impact-row">
          <span class="impact-key">Lịch tập tương lai bị hủy</span>
          <span class="impact-val tabular">${cancelledBookings} buổi (KHÔNG trừ buổi)</span>
        </div>
        <div class="impact-row">
          <span class="impact-key">Suất giữ chỗ 15 phút bị hủy</span>
          <span class="impact-val tabular">${cancelledHolds} hold</span>
        </div>
        <div class="impact-divider"></div>
        <ul class="rule-list">
          <li><strong>Đóng băng gói Coach (D1):</strong> thời hạn gói Coach dừng từ thời điểm khóa, giữ nguyên số buổi còn lại.</li>
          <li><strong>Gói Gym vẫn chạy bình thường:</strong> không đóng băng hay tự gia hạn gói Gym.</li>
          <li>Hội viên được đưa vào hàng chờ <strong>Sự cố Coach</strong> để Chờ mở khóa, Chuyển Coach (D2) hoặc Hoàn mô phỏng (D3).</li>
        </ul>
      </div>`,
    };
  }

  const activeCoachName = preview?.currentCoachRelationship?.coachName
    || preview?.coachName
    || preview?.activeRelationship?.coachName
    || target?.coachName
    || null;
  const hasCoachRel = Boolean(
    activeCoachName
    || preview?.currentCoachRelationship
    || affectedCount > 0
    || preview?.hasActiveRelationship,
  );

  return {
    bannerHtml: renderBanner({
      kind: 'danger',
      iconName: 'lock',
      title: hasCoachRel
        ? `Tác động khóa Hội viên đang thuê Coach${activeCoachName ? ` (${activeCoachName})` : ''} — D4`
        : 'Khóa tài khoản Hội viên — Quy tắc D4 (MEMBER_LOCKED)',
      text: 'Khác với COACH_LOCKED: thời hạn gói Gym & gói Coach vẫn tiếp tục chạy và suất của Coach được giữ nguyên.',
    }),
    impactHtml: `<div class="impact-box">
      ${activeCoachName ? `<div class="impact-row"><span class="impact-key">Coach đang phụ trách</span><span class="impact-val">${esc(activeCoachName)}</span></div>` : ''}
      <div class="impact-row">
        <span class="impact-key">Lịch tập tương lai bị hủy</span>
        <span class="impact-val tabular">${cancelledBookings} buổi (KHÔNG trừ buổi)</span>
      </div>
      <div class="impact-row">
        <span class="impact-key">Suất giữ chỗ thanh toán 15p bị hủy</span>
        <span class="impact-val tabular">${cancelledHolds} hold</span>
      </div>
      <div class="impact-divider"></div>
      <ul class="rule-list">
        <li><strong>Thu hồi phiên ngay</strong> và chặn nhắn tin mới tới tài khoản bị khóa (S5).</li>
        <li><strong>Ẩn hồ sơ sức khỏe khỏi Coach</strong> ngay lập tức; quan hệ chuyển <code>PAUSED (MEMBER_LOCKED)</code>.</li>
        <li><strong>Giữ nguyên suất Coach</strong> trong trần cứng 8 hội viên.</li>
        <li><strong>Đồng hồ gói Gym & gói Coach TIẾP TỤC CHẠY</strong> (không đóng băng).</li>
      </ul>
    </div>`,
  };
}

function buildDetailDrawerHtml(role, detail) {
  // EXPLICIT PRIVACY ALLOWLIST: NEVER read or display healthNotes, injuryNotes, heightCm, weightKg,
  // bodyFatPercent, fitnessGoal, dietaryPreferences, journal, messages, aiMessages, etc.
  const identityRows = `
    <div class="impact-row"><span class="impact-key">UUID kỹ thuật</span><span class="impact-val tabular" style="font-size:12px">${esc(detail.id)}</span></div>
    <div class="impact-row"><span class="impact-key">Họ và tên</span><span class="impact-val">${esc(detail.fullName)}</span></div>
    <div class="impact-row"><span class="impact-key">Email</span><span class="impact-val">${esc(detail.email)}</span></div>
    <div class="impact-row"><span class="impact-key">Số điện thoại</span><span class="impact-val tabular">${esc(detail.phone || 'Chưa cập nhật')}</span></div>
    <div class="impact-row"><span class="impact-key">Trạng thái</span><span class="impact-val">${statusBadge(detail.status)}</span></div>
    <div class="impact-row"><span class="impact-key">Ngày tạo</span><span class="impact-val tabular">${formatDateTimeVN(detail.createdAt)}</span></div>
    ${detail.lastLoginAt ? `<div class="impact-row"><span class="impact-key">Đăng nhập gần nhất</span><span class="impact-val tabular">${formatDateTimeVN(detail.lastLoginAt)}</span></div>` : ''}
    ${detail.disabledAt ? `<div class="impact-row"><span class="impact-key">Thời điểm khóa</span><span class="impact-val tabular">${formatDateTimeVN(detail.disabledAt)}</span></div>` : ''}
    ${detail.disabledReason ? `<div class="impact-row"><span class="impact-key">Lý do khóa</span><span class="impact-val">${esc(detail.disabledReason)}</span></div>` : ''}
  `;

  let opsBlock = '';
  if (role === 'COACH') {
    const usedSlots = Number(detail.usedSlots ?? detail.operationalSummary?.usedSlots ?? 0);
    const activeRels = Number(detail.activeRelationshipsCount ?? detail.operationalSummary?.activeRelationshipsCount ?? 0);
    const openHolds = Number(detail.openHoldCount ?? detail.operationalSummary?.openHoldCount ?? 0);
    const scheduleConfigured = detail.scheduleConfigured ?? detail.operationalSummary?.scheduleConfigured;
    opsBlock = `<div class="impact-box">
      <div class="impact-row"><span class="impact-key">Trần suất học viên</span><span class="impact-val"><span class="meta-badge meta-badge-info tabular">Trần cứng 8 hội viên / Coach</span></span></div>
      <div class="impact-row"><span class="impact-key">Suất đang chiếm</span><span class="impact-val tabular">${usedSlots} / 8 suất</span></div>
      <div class="impact-row"><span class="impact-key">Quan hệ đang hoạt động</span><span class="impact-val tabular">${activeRels}</span></div>
      <div class="impact-row"><span class="impact-key">Suất giữ chỗ 15 phút</span><span class="impact-val tabular">${openHolds}</span></div>
      <div class="impact-row"><span class="impact-key">Lịch tuần cố định</span><span class="impact-val">${scheduleConfigured === true ? statusBadge('ACTIVE', 'Đã cấu hình') : scheduleConfigured === false ? statusBadge('HIDDEN', 'Chưa cấu hình') : '—'}</span></div>
    </div>`;
  } else {
    const membership = detail.currentMembership || detail.activeMembership || detail.gymMembership || null;
    const rel = detail.currentCoachRelationship || detail.coachRelationship || detail.activeRelationship || null;
    opsBlock = `<div class="impact-box">
      <div class="impact-row">
        <span class="impact-key">Gói Gym hiện hành</span>
        <span class="impact-val">${membership
          ? `${esc(membership.planName || 'Gói Gym')} · ${statusBadge(membership.status || 'ACTIVE')}`
          : (detail.activeMembershipEndDate ? `Hiệu lực đến ${formatDateVN(detail.activeMembershipEndDate)}` : 'Chưa có gói Gym hiệu lực')}</span>
      </div>
      ${membership?.endDate ? `<div class="impact-row"><span class="impact-key">Hạn gói Gym (VN)</span><span class="impact-val tabular">${formatDateVN(membership.startDate)} → ${formatDateVN(membership.endDate)}</span></div>` : ''}
      <div class="impact-divider"></div>
      <div class="impact-row">
        <span class="impact-key">Quan hệ Coach hiện tại</span>
        <span class="impact-val">${rel ? `${esc(rel.coachName || 'Coach')} · ${relationshipStatusBadge(rel)}` : extractMemberCoachBadge(detail)}</span>
      </div>
    </div>`;
  }

  const audits = Array.isArray(detail.recentLockHistory)
    ? detail.recentLockHistory
    : Array.isArray(detail.auditHistory)
      ? detail.auditHistory
      : Array.isArray(detail.lockHistory)
        ? detail.lockHistory
        : Array.isArray(detail.recentAudits)
          ? detail.recentAudits
          : [];

  const auditBlock = `<div class="field">
    <span class="field-label">Lịch sử khóa / mở khóa gần đây</span>
    ${audits.length === 0
      ? '<div class="impact-box"><span class="field-hint">Chưa có lịch sử khóa/mở khóa hoặc thay đổi quản trị.</span></div>'
      : `<div class="stack-12">${audits.slice(0, 8).map((entry) => `<div class="impact-box">
        <div class="impact-row">
          <span class="meta-badge ${entry.action === 'USER_DISABLED' ? 'meta-badge-danger' : 'meta-badge-success'}">${esc(entry.action)}</span>
          <span class="field-hint tabular">${formatDateTimeVN(entry.createdAt)}</span>
        </div>
        <div class="field-hint">${esc(entry.summary || entry.reason || entry.metadata?.reason || '—')}</div>
      </div>`).join('')}</div>`}
  </div>`;

  return `<div class="stack-16">
    <div class="impact-box">${identityRows}</div>
    ${opsBlock}
    ${auditBlock}
  </div>`;
}

function renderStatusSwitch(row) {
  const isActive = row.status === 'ACTIVE';
  const canLock = hasPermission('users:lock');
  const label = isActive ? 'Đang hoạt động' : 'Bị khóa';
  const title = !canLock
    ? NO_PERMISSION_REASON
    : (isActive ? 'Đang hoạt động · Bấm để khóa tài khoản' : 'Bị khóa · Bấm để mở khóa tài khoản');

  return `<button type="button" role="switch" aria-checked="${isActive}" class="meta-switch-btn toggle${isActive ? ' is-on' : ''}" data-id="${esc(row.id)}" data-status="${esc(row.status)}" aria-label="${label}" title="${esc(title)}"${!canLock ? ' disabled aria-disabled="true" data-perm-disabled="1"' : ''}>
    <span class="meta-switch-track" aria-hidden="true"><span class="meta-switch-thumb"></span></span>
    <span>${label}</span>
  </button>`;
}

export async function renderAccountsPage({ root, role = 'MEMBER', params, shell }) {
  const activeRole = role === 'COACH' ? 'COACH' : 'MEMBER';
  const section = activeRole === 'COACH' ? 'coaches' : 'members';

  const state = {
    page: Math.max(1, Number(params?.get('page')) || 1),
    pageSize: Math.max(1, Number(params?.get('pageSize')) || 10),
    statusFilter: params?.get('status') || '',
    search: params?.get('search') || '',
    hasGym: params?.get('hasGym') === '1',
    hasCoach: params?.get('hasCoach') === '1',
    hasAvailableSlots: params?.get('hasAvailableSlots') === '1',
    fromDate: params?.get('from') || '',
    toDate: params?.get('to') || '',
  };

  const computeHasFilter = () => Boolean(
    state.search
    || state.statusFilter
    || state.hasGym
    || state.hasCoach
    || state.hasAvailableSlots
    || state.fromDate
    || state.toDate,
  );

  const activeFilterCount = [state.hasGym, state.hasCoach, state.hasAvailableSlots, state.fromDate || state.toDate].filter(Boolean).length;
  const mobileExtraCount = [state.statusFilter, state.hasGym, state.hasCoach, state.hasAvailableSlots, state.fromDate || state.toDate].filter(Boolean).length;

  const filterHtml = `<form class="filter-bar" id="acc-filter-form">
    <input type="search" id="acc-search" class="form-control filter-grow" placeholder="Tìm theo họ tên, email hoặc số điện thoại…" value="${esc(state.search)}" aria-label="Tìm kiếm tài khoản" />
    <div class="desktop-filters" style="display:contents">
      <select id="acc-status" class="form-select filter-fixed" aria-label="Lọc trạng thái tài khoản">
        <option value="" ${!state.statusFilter ? 'selected' : ''}>Tất cả trạng thái</option>
        <option value="ACTIVE" ${state.statusFilter === 'ACTIVE' ? 'selected' : ''}>Đang hoạt động (ACTIVE)</option>
        <option value="DISABLED" ${state.statusFilter === 'DISABLED' ? 'selected' : ''}>Bị khóa (DISABLED)</option>
      </select>
    </div>
    <button type="button" class="btn btn-graphite btn-sm filter-trigger-btn" id="acc-filter-btn" aria-label="Mở bộ lọc nâng cao" title="Bộ lọc">
      ${icon('filter', 16)} <span>Bộ lọc</span><span class="mobile-filter-count tabular" id="acc-filter-badge"${activeFilterCount > 0 || mobileExtraCount > 0 ? '' : ' hidden'}>${activeFilterCount > 0 ? activeFilterCount : mobileExtraCount}</span>
    </button>
    <button type="button" class="btn btn-ghost btn-sm desktop-filters" id="acc-clear-filters"${computeHasFilter() ? '' : ' hidden'}>Xóa bộ lọc</button>
    <button type="button" class="btn btn-graphite btn-sm" id="acc-export-excel" disabled>
      ${icon('download', 16)} <span id="acc-export-label">Xuất Excel</span>
    </button>
  </form>`;

  shell({
    section,
    topbarActionsHtml: activeRole === 'COACH'
      ? `<button type="button" class="btn btn-primary" id="create">${icon('plus', 16)} Tạo Coach</button>`
      : `<button type="button" class="btn btn-primary" id="create-member">${icon('plus', 16)} Tạo hội viên</button>`,
    contentHtml: `<div class="stack-20">${filterHtml}<div id="acc-table-region">${renderTableSkeleton(6)}</div></div>`,
  });

  let currentRows = [];
  let requestSeq = 0;
  let activeController = null;

  const getSelectedIdsRef = { fn: () => [] };

  const syncFilterControls = () => {
    const clearBtn = root.querySelector('#acc-clear-filters');
    if (clearBtn) clearBtn.hidden = !computeHasFilter();
    const statusEl = root.querySelector('#acc-status');
    if (statusEl && statusEl.value !== state.statusFilter) statusEl.value = state.statusFilter;
    const badgeEl = root.querySelector('#acc-filter-badge');
    if (badgeEl) {
      const desktopCount = [state.hasGym, state.hasCoach, state.hasAvailableSlots, state.fromDate || state.toDate].filter(Boolean).length;
      const allCount = [state.statusFilter, state.hasGym, state.hasCoach, state.hasAvailableSlots, state.fromDate || state.toDate].filter(Boolean).length;
      const count = desktopCount || allCount;
      badgeEl.hidden = count === 0;
      badgeEl.textContent = count > 0 ? String(count) : '';
    }
  };

  const columns = activeRole === 'COACH' ? [
      {
        label: 'Huấn luyện viên',
        render: (row) => `<div class="person-cell">
          <span class="meta-avatar meta-avatar-coach">${esc(initials(row.fullName))}</span>
          <div>
            <span class="person-name">${esc(row.fullName)}</span>
            <span class="person-sub">${esc(row.email)}</span>
          </div>
        </div>`,
      },
      {
        label: 'Liên hệ',
        render: (row) => `<span class="tabular">${esc(row.phone || 'Chưa cập nhật')}</span>`,
      },
      {
        label: 'Suất học viên (Trần 8)',
        render: (row) => seatMeterHtml(row.usedSlots ?? 0, 8, row.openHoldCount ?? 0),
      },
      {
        label: 'Trạng thái',
        render: (row) => renderStatusSwitch(row),
      },
      {
        label: 'Thao tác',
        align: 'right',
        render: (row) => `<div class="cell-actions">
          ${renderActionButton({ iconName: 'eye', label: 'Chi tiết', className: 'detail', permission: 'users:read', attrs: `data-id="${esc(row.id)}"` })}
          ${renderActionButton({ iconName: 'edit', label: 'Sửa', className: 'edit', permission: 'users:update', attrs: `data-id="${esc(row.id)}"` })}
          ${renderActionButton({ iconName: 'key', label: 'Cấp mật khẩu tạm', className: 'reset', permission: 'users:reset_password', attrs: `data-id="${esc(row.id)}"` })}
        </div>`,
      },
    ] : [
      {
        label: 'Hội viên',
        render: (row) => `<div class="person-cell">
          <span class="meta-avatar">${esc(initials(row.fullName))}</span>
          <div>
            <span class="person-name">${esc(row.fullName)}</span>
            <span class="person-sub">${esc(row.email)}</span>
          </div>
        </div>`,
      },
      {
        label: 'Liên hệ',
        render: (row) => `<span class="tabular">${esc(row.phone || 'Chưa cập nhật')}</span>`,
      },
      {
        label: 'Gói Gym',
        render: (row) => extractMemberGymBadge(row),
      },
      {
        label: 'Coach & Quan hệ',
        render: (row) => extractMemberCoachBadge(row),
      },
      {
        label: 'Trạng thái',
        render: (row) => renderStatusSwitch(row),
      },
      {
        label: 'Thao tác',
        align: 'right',
        render: (row) => `<div class="cell-actions">
          ${renderActionButton({ iconName: 'eye', label: 'Chi tiết', className: 'detail', permission: 'users:read', attrs: `data-id="${esc(row.id)}"` })}
          ${renderActionButton({ iconName: 'edit', label: 'Sửa', className: 'edit', permission: 'users:update', attrs: `data-id="${esc(row.id)}"` })}
        </div>`,
      },
    ];

    const buildTableHtml = (rows, pagination) => {
      const emptyHtml = computeHasFilter()
        ? renderFilterEmptyState({ resetId: 'acc-filter-reset' })
        : renderEmptyState({
          iconName: 'users',
          title: activeRole === 'COACH' ? 'Chưa có Huấn luyện viên nào' : 'Chưa có Hội viên nào',
          description: activeRole === 'COACH'
            ? 'Tạo tài khoản Coach mới với giới hạn trần cứng 8 hội viên / Coach.'
            : 'Hội viên đăng ký mới trên ứng dụng sẽ hiển thị tại đây.',
          ctaLabel: activeRole === 'COACH' ? 'Tạo Coach' : '',
          ctaId: 'create-empty',
        });

      return renderDataTable({
        columns,
        rows,
        selectable: true,
        emptyHtml,
        paginationHtml: renderPagination({
          ...pagination,
          prefix: 'acc',
          summaryNote: activeRole === 'COACH' ? 'Trần cứng 8 hội viên / Coach' : '',
        }),
        ariaLabel: activeRole === 'COACH' ? 'Danh sách Huấn luyện viên' : 'Danh sách Hội viên',
      });
    };

    const reloadWith = async (patch = {}) => {
      const nextSearch = patch.search !== undefined
        ? patch.search
        : (root.querySelector('#acc-search')?.value?.trim() || '');
      const nextStatus = patch.status !== undefined
        ? patch.status
        : (root.querySelector('#acc-status')?.value ?? state.statusFilter);
      const nextGym = patch.hasGym !== undefined ? patch.hasGym : state.hasGym;
      const nextCoach = patch.hasCoach !== undefined ? patch.hasCoach : state.hasCoach;
      const nextSlots = patch.hasAvailableSlots !== undefined ? patch.hasAvailableSlots : state.hasAvailableSlots;
      const nextFrom = patch.from !== undefined ? patch.from : state.fromDate;
      const nextTo = patch.to !== undefined ? patch.to : state.toDate;
      const nextPage = patch.page !== undefined ? patch.page : state.page;
      const nextPageSize = patch.pageSize !== undefined ? patch.pageSize : state.pageSize;

      state.search = nextSearch;
      state.statusFilter = nextStatus;
      state.hasGym = nextGym;
      state.hasCoach = nextCoach;
      state.hasAvailableSlots = nextSlots;
      state.fromDate = nextFrom;
      state.toDate = nextTo;
      state.page = nextPage;
      state.pageSize = nextPageSize;

      if (patch.search !== undefined) {
        const searchEl = root.querySelector('#acc-search');
        if (searchEl && searchEl.value !== nextSearch) searchEl.value = nextSearch;
      }

      syncFilterControls();

      updateQuery({
        search: nextSearch || null,
        status: nextStatus || null,
        from: nextFrom || null,
        to: nextTo || null,
        hasGym: activeRole === 'MEMBER' && nextGym ? 1 : null,
        hasCoach: activeRole === 'MEMBER' && nextCoach ? 1 : null,
        hasAvailableSlots: activeRole === 'COACH' && nextSlots ? 1 : null,
        page: nextPage > 1 ? nextPage : null,
        pageSize: nextPageSize !== 10 ? nextPageSize : null,
      }, { replace: true });

      return loadTable();
    };

    const debouncedSearch = debounce(() => {
      const nextSearch = root.querySelector('#acc-search')?.value?.trim() || '';
      if (nextSearch === state.search) return;
      reloadWith({ search: nextSearch, page: 1 });
    }, 350);

    const searchInput = root.querySelector('#acc-search');
    if (searchInput) {
      searchInput.oninput = () => debouncedSearch();
    }
    const filterForm = root.querySelector('#acc-filter-form');
    if (filterForm) {
      filterForm.onsubmit = (ev) => {
        ev.preventDefault();
        debouncedSearch.cancel();
        reloadWith({ page: 1 });
      };
    }
    const statusSelect = root.querySelector('#acc-status');
    if (statusSelect) {
      statusSelect.onchange = () => reloadWith({ page: 1 });
    }
    ['#acc-filter-gym', '#acc-filter-coach', '#acc-filter-slots'].forEach((sel) => {
      const el = root.querySelector(sel);
      if (el) el.onchange = () => reloadWith({ page: 1 });
    });
    const clearBtn = root.querySelector('#acc-clear-filters');
    if (clearBtn) {
      clearBtn.onclick = () => reloadWith({ search: '', status: '', from: '', to: '', hasGym: false, hasCoach: false, hasAvailableSlots: false, page: 1 });
    }

    const filterBtn = root.querySelector('#acc-filter-btn');
    if (filterBtn) {
      filterBtn.onclick = () => {
        const currentStatus = root.querySelector('#acc-status')?.value ?? state.statusFilter;
        const currentFrom = state.fromDate;
        const currentTo = state.toDate;
        const currentGym = state.hasGym;
        const currentCoach = state.hasCoach;
        const currentSlots = state.hasAvailableSlots;

        openModal({
          title: 'Bộ lọc',
          maxWidth: '480px',
          bodyHtml: `<div class="meta-modal-body">
            <div class="field">
              <label class="field-label" for="mf-status">Trạng thái</label>
              <select id="mf-status" class="form-select">
                <option value="" ${!currentStatus ? 'selected' : ''}>Tất cả trạng thái</option>
                <option value="ACTIVE" ${currentStatus === 'ACTIVE' ? 'selected' : ''}>Đang hoạt động (ACTIVE)</option>
                <option value="DISABLED" ${currentStatus === 'DISABLED' ? 'selected' : ''}>Bị khóa (DISABLED)</option>
              </select>
            </div>

            <div class="field">
              <span class="field-label">Thời gian</span>
              <div class="desktop-filters">
                <div class="date-preset-grid" style="grid-template-columns:repeat(3,minmax(0,1fr));margin-bottom:10px">
                  ${DATE_PRESETS.map((p) => `<button type="button" class="date-preset-btn" data-preset="${p.id}">${esc(p.label)}</button>`).join('')}
                </div>
                <div class="grid-2">
                  <div class="date-range-field" style="min-width:0">
                    <label class="date-range-label" for="mf-from-trigger">Từ ngày</label>
                    ${renderDateInput({ id: 'mf-from', value: currentFrom, ariaLabel: 'Từ ngày' })}
                  </div>
                  <div class="date-range-field" style="min-width:0">
                    <label class="date-range-label" for="mf-to-trigger">Đến ngày</label>
                    ${renderDateInput({ id: 'mf-to', value: currentTo, ariaLabel: 'Đến ngày' })}
                  </div>
                </div>
              </div>
              <div class="mobile-filters">
                ${renderDateRangePicker({ id: 'mf-range', from: currentFrom, to: currentTo })}
              </div>
            </div>

            <div class="field">
              <span class="field-label">Tùy chọn nhanh</span>
              ${activeRole === 'COACH'
                ? `<label class="filter-check" for="mf-slots"><input type="checkbox" id="mf-slots" ${currentSlots ? 'checked' : ''} /><span>Còn suất nhận (&lt; 8)</span></label>`
                : `<div class="filter-check-group">
                    <label class="filter-check" for="mf-gym"><input type="checkbox" id="mf-gym" ${currentGym ? 'checked' : ''} /><span>Có gói Gym</span></label>
                    <label class="filter-check" for="mf-coach"><input type="checkbox" id="mf-coach" ${currentCoach ? 'checked' : ''} /><span>Đang thuê Coach</span></label>
                  </div>`}
            </div>
          </div>`,
          footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Đóng</button>
            <button type="button" class="btn btn-graphite" id="mf-reset">Đặt lại</button>
            <button type="button" class="btn btn-primary" id="mf-apply">Áp dụng</button>`,
          onMount: (modal) => {
            const dlg = modal.dialog;
            let activeFrom = currentFrom;
            let activeTo = currentTo;

            bindDatePickers(dlg, {
              onChange: (id, val) => {
                if (id === 'mf-from') activeFrom = val;
                if (id === 'mf-to') activeTo = val;
              },
            });
            bindDateRangePicker(dlg, {
              id: 'mf-range',
              onChange: ({ from, to }) => {
                activeFrom = from;
                activeTo = to;
                setDatePickerValue(dlg, 'mf-from', from);
                setDatePickerValue(dlg, 'mf-to', to);
              },
            });

            dlg.querySelectorAll('[data-preset]').forEach((pBtn) => {
              pBtn.onclick = () => {
                dlg.querySelectorAll('[data-preset]').forEach((b) => b.classList?.remove('active'));
                pBtn.classList?.add('active');
                const range = computeDatePreset(pBtn.dataset.preset);
                activeFrom = range.from;
                activeTo = range.to;
                setDatePickerValue(dlg, 'mf-from', range.from);
                setDatePickerValue(dlg, 'mf-to', range.to);
              };
            });

            const resetBtn = dlg.querySelector('#mf-reset');
            if (resetBtn) {
              resetBtn.onclick = () => {
                modal.close();
                reloadWith({ search: '', status: '', from: '', to: '', hasGym: false, hasCoach: false, hasAvailableSlots: false, page: 1 });
              };
            }
            const applyBtn = dlg.querySelector('#mf-apply');
            if (applyBtn) {
              applyBtn.onclick = () => {
                const nextFrom = activeFrom || '';
                const nextTo = activeTo || '';
                if (nextFrom && nextTo && nextFrom > nextTo) {
                  toast('Ngày bắt đầu không được lớn hơn ngày kết thúc.', 'warn');
                  return;
                }
                const nextStatus = dlg.querySelector('#mf-status')?.value || '';
                const nextGym = Boolean(dlg.querySelector('#mf-gym')?.checked);
                const nextCoach = Boolean(dlg.querySelector('#mf-coach')?.checked);
                const nextSlots = Boolean(dlg.querySelector('#mf-slots')?.checked);
                modal.close();
                reloadWith({
                  status: nextStatus,
                  from: nextFrom,
                  to: nextTo,
                  hasGym: nextGym,
                  hasCoach: nextCoach,
                  hasAvailableSlots: nextSlots,
                  page: 1,
                });
              };
            }
          },
        });
      };
    }

    const exportLabel = root.querySelector('#acc-export-label');
    const exportBtn = root.querySelector('#acc-export-excel');
    if (exportBtn) {
      exportBtn.onclick = () => {
        const selectedIds = getSelectedIdsRef.fn();
        const targetRows = selectedIds.length > 0
          ? currentRows.filter((r) => selectedIds.includes(String(r.id)))
          : currentRows;
        if (!targetRows.length) {
          toast('Chưa có dữ liệu để xuất Excel.', 'warn');
          return;
        }
        const exportCols = activeRole === 'COACH'
          ? [
            { label: 'Họ và tên', value: (r) => r.fullName || '' },
            { label: 'Email', value: (r) => r.email || '' },
            { label: 'Số điện thoại', value: (r) => r.phone || '' },
            { label: 'Suất học viên', value: (r) => `${Number(r.usedSlots ?? r.activeRelationshipsCount ?? 0)}/8` },
            { label: 'Trạng thái', value: (r) => r.status || '' },
          ]
          : [
            { label: 'Họ và tên', value: (r) => r.fullName || '' },
            { label: 'Email', value: (r) => r.email || '' },
            { label: 'Số điện thoại', value: (r) => r.phone || '' },
            { label: 'Gói Gym', value: (r) => r.activeMembershipEndDate ? `Hiệu lực đến ${r.activeMembershipEndDate}` : (r.membershipStatus || 'EXPIRED') },
            { label: 'Coach phụ trách', value: (r) => r.coachName || 'Chưa có' },
            { label: 'Trạng thái', value: (r) => r.status || '' },
          ];
        const ok = exportToExcel({
          filename: activeRole === 'COACH' ? 'metagym-coaches.csv' : 'metagym-members.csv',
          columns: exportCols,
          rows: targetRows,
        });
        if (ok) {
          toast(`Đã xuất ${targetRows.length} dòng ra file Excel (.csv).`);
        }
      };
    }

    const bindTableEvents = (rows, pagination) => {
      bindPagination(root, {
        page: pagination.page,
        totalPages: pagination.totalPages,
        prefix: 'acc',
        onChange: (nextPage) => reloadWith({ page: nextPage }),
        onPageSizeChange: (nextSize) => reloadWith({ pageSize: nextSize, page: 1 }),
      });

      if (exportLabel) exportLabel.textContent = 'Xuất Excel';
      getSelectedIdsRef.fn = bindDataTableSelection(root, {
        onSelectionChange: (ids) => {
          if (exportLabel) {
            exportLabel.textContent = ids.length > 0 ? `Xuất Excel (${ids.length})` : 'Xuất Excel';
          }
        },
      });

      const emptyResetBtn = root.querySelector('#acc-filter-reset');
      if (emptyResetBtn) {
        emptyResetBtn.onclick = () => reloadWith({ search: '', status: '', from: '', to: '', hasGym: false, hasCoach: false, hasAvailableSlots: false, page: 1 });
      }

      const createEmptyBtn = root.querySelector('#create-empty');
      if (createEmptyBtn) createEmptyBtn.onclick = openCreateCoachModal;

    // 1. Operational Detail Drawer (GET /admin/users/:id)
    root.querySelectorAll('.detail').forEach((btn) => {
      btn.onclick = async () => {
        const row = rows.find((r) => r.id === btn.dataset.id);
        const drawer = openDrawer({
          title: row?.fullName || 'Chi tiết tài khoản',
          subtitle: activeRole === 'COACH' ? 'Hồ sơ vận hành Huấn luyện viên' : 'Hồ sơ vận hành Hội viên',
          bodyHtml: renderSkeletonPage({ cards: 0, rows: 4 }),
        });
        try {
          const res = await api(`/admin/users/${encodeURIComponent(btn.dataset.id)}`);
          const detail = res?.data || row;
          drawer?.setBody(buildDetailDrawerHtml(activeRole, detail));
        } catch (error) {
          drawer?.setBody(renderErrorState({ title: 'Không tải được hồ sơ chi tiết', message: error.message }));
        }
      };
    });

    // 2. Create Coach Modal (NO memberLimit field; preserves input on 409/422)
    const openCreateCoachModal = () => {
      openModal({
        title: 'Tạo tài khoản Huấn luyện viên mới',
        subtitle: 'Trần suất cứng 8 hội viên / Coach được áp dụng tự động (không thể chỉnh sửa)',
        bodyHtml: `<form id="create-coach-form" novalidate>
          <div class="meta-modal-body">
            <div class="field">
              <label class="field-label" for="cc-fullName">Họ và tên</label>
              <input id="cc-fullName" class="form-control" name="fullName" required minlength="2" maxlength="120" placeholder="Ví dụ: Lê Hoàng Nam" />
            </div>
            <div class="field">
              <label class="field-label" for="cc-email">Email đăng nhập</label>
              <input id="cc-email" class="form-control" name="email" type="email" required placeholder="coach@metagym.vn" />
            </div>
            <div class="field">
              <label class="field-label" for="cc-password">Mật khẩu ban đầu</label>
              <input id="cc-password" class="form-control" name="password" type="password" required minlength="8" placeholder="Tối thiểu 8 ký tự (hoa, thường, số)" />
              <span class="field-hint">Yêu cầu: tối thiểu 8 ký tự, chứa ít nhất 1 chữ hoa (A–Z), 1 chữ thường (a–z) và 1 chữ số (0–9).</span>
            </div>
            <div class="impact-box">
              <div class="impact-row">
                <span class="impact-key">Giới hạn học viên</span>
                <span class="impact-val"><span class="meta-badge meta-badge-info tabular">Trần cứng 8 hội viên / Coach</span></span>
              </div>
            </div>
          </div>
          <div class="meta-modal-footer">
            <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
            <button type="submit" class="btn btn-primary" data-modal-submit>${icon('plus', 16)} Tạo tài khoản Coach</button>
          </div>
        </form>`,
        onMount(ctrl) {
          const form = ctrl.dialog.querySelector('#create-coach-form');
          form.onsubmit = async (event) => {
            event.preventDefault();
            ctrl.showError('');
            const fullName = (form.querySelector('[name="fullName"]')?.value || '').trim();
            const email = (form.querySelector('[name="email"]')?.value || '').trim();
            const password = form.querySelector('[name="password"]')?.value || '';

            if (fullName.length < 2) {
              ctrl.showError('Họ và tên phải có ít nhất 2 ký tự.');
              return;
            }
            if (!email || !email.includes('@')) {
              ctrl.showError('Email đăng nhập không hợp lệ.');
              return;
            }
            if (password.length < 8 || !/[a-z]/.test(password) || !/[A-Z]/.test(password) || !/[0-9]/.test(password)) {
              ctrl.showError('Mật khẩu cần ít nhất 8 ký tự gồm chữ hoa, chữ thường và chữ số.');
              return;
            }

            ctrl.setBusy(true);
            try {
              // Strictly sends ONLY { email, fullName, password } — NEVER memberLimit!
              await api('/admin/coaches', 'POST', { email, fullName, password });
              ctrl.close();
              await reloadWith({ page: 1 });
              notice(`Đã tạo tài khoản Coach ${fullName} với trần cứng 8 hội viên.`);
            } catch (error) {
              ctrl.setBusy(false);
              ctrl.showError(error.message);
            }
          };
        },
      });
    };

    // 3. Edit Account Modal (fullName & phone ONLY — NEVER memberLimit)
    const openEditModal = (row) => {
      if (!row) return;
      openModal({
        title: `Sửa tài khoản: ${row.fullName}`,
        subtitle: activeRole === 'COACH'
          ? 'Chỉ cập nhật họ tên và số điện thoại · Trần cứng 8 suất không thể chỉnh sửa'
          : 'Cập nhật họ tên và số điện thoại vận hành',
        bodyHtml: `<form id="account-form" novalidate>
          <div class="meta-modal-body">
            <div class="field">
              <label class="field-label" for="edit-fullName">Họ và tên</label>
              <input id="edit-fullName" class="form-control" name="fullName" value="${esc(row.fullName || '')}" required minlength="2" maxlength="120" />
            </div>
            <div class="field">
              <label class="field-label" for="edit-phone">Số điện thoại</label>
              <input id="edit-phone" class="form-control tabular" name="phone" value="${esc(row.phone || '')}" maxlength="20" placeholder="Ví dụ: 0901234567" />
            </div>
          </div>
          <div class="meta-modal-footer">
            <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
            <button type="submit" class="btn btn-primary" data-modal-submit>Lưu thay đổi</button>
          </div>
        </form>`,
        onMount(ctrl) {
          const form = ctrl.dialog.querySelector('#account-form');
          form.onsubmit = async (event) => {
            event.preventDefault();
            ctrl.showError('');
            const fullName = (form.querySelector('[name="fullName"]')?.value || '').trim();
            const phoneRaw = (form.querySelector('[name="phone"]')?.value || '').trim();
            if (fullName.length < 2) {
              ctrl.showError('Họ và tên phải có ít nhất 2 ký tự.');
              return;
            }
            ctrl.setBusy(true);
            try {
              await api(`/admin/users/${encodeURIComponent(row.id)}`, 'PATCH', {
                fullName,
                phone: phoneRaw || null,
              });
              ctrl.close();
              await reloadWith({ page: state.page });
              notice('Đã lưu thông tin tài khoản.');
            } catch (error) {
              ctrl.setBusy(false);
              ctrl.showError(error.message);
            }
          };
        },
      });
    };

    const openCreateMemberModal = () => {
      openModal({
        title: 'Tạo tài khoản Hội viên mới',
        subtitle: 'Giao diện mẫu — sẵn sàng để kết nối API tạo hội viên',
        bodyHtml: `<form id="create-member-form" novalidate>
          <div class="meta-modal-body">
            ${renderBanner({
              kind: 'info',
              iconName: 'info',
              title: 'Chế độ giao diện (UI)',
              text: 'Biểu mẫu đã dựng sẵn các trường thông tin cơ bản để gắn API tạo hội viên.',
            })}
            <div class="field">
              <label class="field-label" for="cm-fullName">Họ và tên</label>
              <input id="cm-fullName" class="form-control" name="fullName" required minlength="2" maxlength="120" placeholder="Ví dụ: Nguyễn Minh Anh" />
            </div>
            <div class="field">
              <label class="field-label" for="cm-email">Email đăng nhập</label>
              <input id="cm-email" class="form-control" name="email" type="email" required placeholder="member@metagym.vn" />
            </div>
            <div class="field">
              <label class="field-label" for="cm-phone">Số điện thoại</label>
              <input id="cm-phone" class="form-control tabular" name="phone" type="tel" maxlength="20" placeholder="Ví dụ: 0901234567" />
            </div>
            <div class="field">
              <label class="field-label" for="cm-password">Mật khẩu ban đầu</label>
              <input id="cm-password" class="form-control" name="password" type="password" required minlength="8" placeholder="Tối thiểu 8 ký tự (hoa, thường, số)" />
              <span class="field-hint">Yêu cầu: tối thiểu 8 ký tự, chứa ít nhất 1 chữ hoa (A–Z), 1 chữ thường (a–z) và 1 chữ số (0–9).</span>
            </div>
          </div>
          <div class="meta-modal-footer">
            <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
            <button type="submit" class="btn btn-primary" data-modal-submit>${icon('plus', 16)} Tạo hội viên</button>
          </div>
        </form>`,
        onMount(ctrl) {
          const form = ctrl.dialog.querySelector('#create-member-form');
          form.onsubmit = (event) => {
            event.preventDefault();
            ctrl.showError('');
            const fullName = (form.querySelector('[name="fullName"]')?.value || '').trim();
            const email = (form.querySelector('[name="email"]')?.value || '').trim();
            const password = form.querySelector('[name="password"]')?.value || '';

            if (fullName.length < 2) {
              ctrl.showError('Họ và tên phải có ít nhất 2 ký tự.');
              return;
            }
            if (!email || !email.includes('@')) {
              ctrl.showError('Email đăng nhập không hợp lệ.');
              return;
            }
            if (password.length < 8 || !/[a-z]/.test(password) || !/[A-Z]/.test(password) || !/[0-9]/.test(password)) {
              ctrl.showError('Mật khẩu cần ít nhất 8 ký tự gồm chữ hoa, chữ thường và chữ số.');
              return;
            }

            ctrl.close();
            toast(`UI mẫu: Đã kiểm tra thông tin hội viên ${fullName} (chưa kết nối API).`, 'info');
          };
        },
      });
    };

    const createBtn = root.querySelector('#create');
    if (createBtn) createBtn.onclick = openCreateCoachModal;

    const createMemberBtn = root.querySelector('#create-member');
    if (createMemberBtn) createMemberBtn.onclick = openCreateMemberModal;

    root.querySelectorAll('.edit').forEach((btn) => {
      btn.onclick = () => openEditModal(rows.find((r) => r.id === btn.dataset.id));
    });

    // 4. Temporary Password Modal (POST /admin/coaches/:id/password-resets)
    root.querySelectorAll('.reset').forEach((btn) => {
      btn.onclick = () => {
        const target = rows.find((r) => r.id === btn.dataset.id);
        openConfirmModal({
          title: `Cấp mật khẩu tạm cho Coach: ${target?.fullName || ''}`,
          subtitle: 'Thu hồi toàn bộ phiên cũ và cấp mật khẩu tạm hiển thị một lần duy nhất',
          bannerHtml: renderBanner({
            kind: 'warn',
            iconName: 'key',
            title: 'Thu hồi phiên ngay lập tức (S5)',
            text: 'Coach đăng nhập bằng mật khẩu tạm và sẽ được nhắc đổi mật khẩu trong ứng dụng. Mật khẩu tạm không được ghi vào Audit Log.',
          }),
          confirmLabel: 'Cấp mật khẩu tạm',
          confirmVariant: 'primary',
          confirmIcon: 'key',
          onConfirm: async () => {
            const res = await api(`/admin/coaches/${encodeURIComponent(btn.dataset.id)}/password-resets`, 'POST', {});
            const tempPw = res?.data?.temporaryPassword || '';
            const reminder = res?.data?.reminder || DEFAULT_TEMP_PW_REMINDER;

            // Replace modal contents with one-time password reveal modal
            openModal({
              title: `Mật khẩu tạm (1 lần) · ${target?.fullName || ''}`,
              subtitle: 'Chỉ hiển thị một lần duy nhất — vui lòng bàn giao qua kênh nội bộ',
              bodyHtml: `<div class="meta-modal-body">
                ${renderBanner({
                  kind: 'warn',
                  iconName: 'key',
                  title: 'Lưu ý bảo mật',
                  text: reminder,
                })}
                <div class="impact-box" style="flex-direction:row;align-items:center;justify-content:space-between;gap:12px">
                  <div>
                    <div class="field-hint">Mật khẩu tạm (1 lần)</div>
                    <code id="temp-pw-value" class="tabular" style="font-size:20px;font-weight:800;letter-spacing:0.04em;color:var(--meta-text-strong)">${esc(tempPw)}</code>
                  </div>
                  <button type="button" class="btn btn-primary btn-sm" id="copy-temp-pw">${icon('copy', 15)} Sao chép</button>
                </div>
              </div>`,
              footerHtml: '<button type="button" class="btn btn-ghost" data-close-modal>Đã bàn giao · Đóng</button>',
              onMount(revealCtrl) {
                const copyBtn = revealCtrl.dialog.querySelector('#copy-temp-pw');
                if (copyBtn) {
                  copyBtn.onclick = () => {
                    globalThis.navigator?.clipboard?.writeText?.(tempPw).catch?.(() => {});
                    toast('Đã sao chép mật khẩu tạm vào clipboard.');
                  };
                }
              },
            });
            return false; // We already replaced the modal; don't close the new reveal modal!
          },
        });
      };
    });

    // 5. Lock Impact Modal (GET /admin/users/:id/lock-preview + D1/D4) & Unlock Modal (D1/D4)
    root.querySelectorAll('.toggle').forEach((btn) => {
      btn.onclick = async () => {
        const target = rows.find((r) => r.id === btn.dataset.id);
        const isLock = btn.dataset.status === 'ACTIVE';

        if (isLock) {
          let preview = null;
          try {
            const previewRes = await api(`/admin/users/${encodeURIComponent(btn.dataset.id)}/lock-preview`);
            preview = previewRes?.data || null;
          } catch {
            preview = null;
          }

          const { bannerHtml, impactHtml } = buildLockPreviewImpactHtml(activeRole, target, preview);
          openConfirmModal({
            title: activeRole === 'COACH'
              ? `Khóa tài khoản Coach: ${target?.fullName || ''}`
              : `Khóa tài khoản Hội viên: ${target?.fullName || ''}`,
            subtitle: activeRole === 'COACH'
              ? 'Hành động rủi ro cao · Kiểm tra tác động COACH_LOCKED trước khi xác nhận'
              : 'Hành động rủi ro cao · Quy tắc D4 (MEMBER_LOCKED)',
            bannerHtml,
            impactHtml,
            requireReason: true,
            reasonLabel: 'Lý do khóa tài khoản (bắt buộc 1–500 ký tự)',
            reasonPlaceholder: activeRole === 'COACH'
              ? 'Ví dụ: Coach nghỉ phép đột xuất dài ngày / vi phạm quy chuẩn…'
              : 'Ví dụ: Vi phạm nội quy phòng tập…',
            confirmLabel: activeRole === 'COACH' ? 'Xác nhận khóa Coach' : 'Xác nhận khóa Member (D4)',
            confirmVariant: 'danger-solid',
            confirmIcon: 'lock',
            onConfirm: async ({ reason }) => {
              const res = await api(`/admin/users/${encodeURIComponent(btn.dataset.id)}/status`, 'PATCH', {
                status: 'DISABLED',
                reason,
              });
              const summary = formatEffectsSummary(activeRole, true, res?.data?.effects);
              await reloadWith({ page: state.page });
              notice(summary, 'warn');
            },
          });
          return;
        }

        // Unlock Modal (D1 auto-restore for Coach / D4 restore for Member — NO lock reason sent)
        let unlockPreview = null;
        if (activeRole === 'COACH') {
          try {
            const detailRes = await api(`/admin/users/${encodeURIComponent(btn.dataset.id)}`);
            unlockPreview = detailRes?.data || null;
          } catch {
            unlockPreview = null;
          }
        }

        const waitingCount = Number(
          unlockPreview?.openIncidentsCount
          ?? unlockPreview?.coachLockedCount
          ?? unlockPreview?.pausedRelationshipsCount
          ?? 0,
        );
        const bannerHtml = activeRole === 'COACH'
          ? renderBanner({
            kind: 'success',
            iconName: 'unlock',
            title: 'Quy tắc D1: Tự động khôi phục hội viên đang chờ',
            textHtml: 'Mọi hội viên còn ở trạng thái <code>COACH_LOCKED</code> (chưa chuyển Coach, chưa hoàn mô phỏng) sẽ được tự động khôi phục và cộng bù ngày đóng băng <strong>đúng 1 lần</strong>.',
          })
          : renderBanner({
            kind: 'success',
            iconName: 'unlock',
            title: 'Quy tắc D4: Khôi phục tài khoản Hội viên',
            textHtml: 'Hệ thống đối soát hạn gói Gym và gói Coach ngay lập tức: khôi phục <code>ACTIVE</code> nếu còn hạn, hoặc chuyển <code>MEMBERSHIP_EXPIRED</code> / <code>ENDED</code> tương ứng (không cộng bù ngày).',
          });

        const impactHtml = activeRole === 'COACH'
          ? `<div class="impact-box">
            <div class="impact-row"><span class="impact-key">Huấn luyện viên</span><span class="impact-val">${esc(target?.fullName || '')}</span></div>
            ${waitingCount > 0 ? `<div class="impact-row"><span class="impact-key">Hội viên chờ khôi phục</span><span class="impact-val tabular">${waitingCount} hội viên</span></div>` : ''}
            <div class="impact-row"><span class="impact-key">Bù đóng băng</span><span class="impact-val" style="color:var(--meta-success)">Cộng đúng 1 lần theo ngày lịch VN</span></div>
            <div class="impact-row"><span class="impact-key">Không ảnh hưởng</span><span class="impact-val">Hội viên đã chuyển Coach hoặc đã hoàn tiền mô phỏng</span></div>
          </div>`
          : `<div class="impact-box">
            <div class="impact-row"><span class="impact-key">Hội viên</span><span class="impact-val">${esc(target?.fullName || '')}</span></div>
            <div class="impact-row"><span class="impact-key">Trạng thái sau mở khóa</span><span class="impact-val">${statusBadge('ACTIVE')}</span></div>
          </div>`;

        openConfirmModal({
          title: activeRole === 'COACH'
            ? `Mở khóa Coach: ${target?.fullName || ''} (D1 Auto-restore)`
            : `Mở khóa Hội viên: ${target?.fullName || ''} (D4)`,
          subtitle: 'Xác nhận khôi phục quyền hoạt động cho tài khoản này',
          bannerHtml,
          impactHtml,
          requireReason: false,
          confirmLabel: activeRole === 'COACH' ? 'Xác nhận mở khóa (D1)' : 'Xác nhận mở khóa (D4)',
          confirmVariant: 'success',
          confirmIcon: 'unlock',
          onConfirm: async () => {
            const res = await api(`/admin/users/${encodeURIComponent(btn.dataset.id)}/status`, 'PATCH', {
              status: 'ACTIVE',
            });
            const summary = formatEffectsSummary(activeRole, false, res?.data?.effects);
            await reloadWith({ page: state.page });
            notice(summary, 'success');
          },
        });
      };
    });
    };

    const loadTable = async () => {
      const seq = ++requestSeq;
      if (activeController) activeController.abort();
      activeController = typeof globalThis.AbortController === 'function' ? new globalThis.AbortController() : null;

      const tableRegion = root.querySelector('#acc-table-region');
      if (tableRegion?.style) tableRegion.style.opacity = '0.6';

      try {
        const query = buildQuery({
          role: activeRole,
          status: state.statusFilter,
          search: state.search,
          page: state.page,
          pageSize: state.pageSize,
          ...(state.fromDate ? { from: state.fromDate } : {}),
          ...(state.toDate ? { to: state.toDate } : {}),
          ...(activeRole === 'MEMBER' && state.hasGym ? { hasGym: 1 } : {}),
          ...(activeRole === 'MEMBER' && state.hasCoach ? { hasCoach: 1 } : {}),
          ...(activeRole === 'COACH' && state.hasAvailableSlots ? { hasAvailableSlots: 1 } : {}),
        });
        const result = await api(`/admin/users${query}`, 'GET', undefined, { signal: activeController?.signal });
        if (seq !== requestSeq) return;

        const rows = result?.data || [];
        const pagination = result?.pagination || {
          page: state.page,
          pageSize: state.pageSize,
          totalItems: rows.length,
          totalPages: 1,
        };
        currentRows = rows;
        if (exportBtn) exportBtn.disabled = rows.length === 0;
        if (tableRegion) {
          tableRegion.innerHTML = buildTableHtml(rows, pagination);
          if (tableRegion.style) tableRegion.style.opacity = '';
        }
        bindTableEvents(rows, pagination);
      } catch (error) {
        if (error?.code === 'ABORTED' || seq !== requestSeq) return;
        if (tableRegion?.style) tableRegion.style.opacity = '';
        if (tableRegion) {
          tableRegion.innerHTML = renderErrorState({ title: 'Không tải được danh sách tài khoản', message: error.message });
          const retry = tableRegion.querySelector('#retry-load-btn');
          if (retry) retry.onclick = () => loadTable();
        }
      }
    };

    await loadTable();
}

export { buildHash };
