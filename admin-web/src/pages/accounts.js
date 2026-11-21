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
import { renderDataTable } from '../components/data-table.js';
import { openDrawer } from '../components/drawer.js';
import { openConfirmModal, openModal } from '../components/modal.js';
import { bindPagination, renderPagination } from '../components/pagination.js';
import {
  renderBanner,
  renderEmptyState,
  renderErrorState,
  renderFilterEmptyState,
  renderSkeletonPage,
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

  const privacyBanner = renderBanner({
    kind: 'info',
    iconName: 'shield',
    title: 'Phạm vi vận hành (Privacy Allowlist)',
    text: 'Không hiển thị nhật ký tập, ảnh tiến độ, số đo cá nhân, tin nhắn 1–1, ghi chú sức khỏe nhạy cảm hay hội thoại AI Coach.',
  });

  return `<div class="stack-16">
    <div class="impact-box">${identityRows}</div>
    ${opsBlock}
    ${auditBlock}
    ${privacyBanner}
  </div>`;
}

export async function renderAccountsPage({ root, role = 'MEMBER', params, shell }) {
  const activeRole = role === 'COACH' ? 'COACH' : 'MEMBER';
  const section = activeRole === 'COACH' ? 'coaches' : 'members';

  const page = Math.max(1, Number(params?.get('page')) || 1);
  const statusFilter = params?.get('status') || '';
  const search = params?.get('search') || '';
  const hasFilter = Boolean(search || statusFilter);

  shell({
    section,
    contentHtml: renderSkeletonPage({ cards: 0, rows: 6 }),
  });

  try {
    const query = buildQuery({ role: activeRole, status: statusFilter, search, page, pageSize: 20 });
    const result = await api(`/admin/users${query}`);
    const rows = result?.data || [];
    const pagination = result?.pagination || { page, pageSize: 20, totalItems: rows.length, totalPages: 1 };

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
        render: (row) => statusBadge(row.status),
      },
      {
        label: 'Thao tác',
        align: 'right',
        render: (row) => `<div class="cell-actions">
          <button type="button" class="btn btn-ghost btn-sm detail" data-id="${esc(row.id)}">Chi tiết</button>
          <button type="button" class="btn btn-ghost btn-sm edit" data-id="${esc(row.id)}">Sửa</button>
          <button type="button" class="btn btn-ghost btn-sm reset" data-id="${esc(row.id)}">${icon('key', 14)} MK tạm</button>
          <button type="button" class="btn ${row.status === 'ACTIVE' ? 'btn-danger' : 'btn-success'} btn-sm toggle" data-id="${esc(row.id)}" data-status="${esc(row.status)}">
            ${row.status === 'ACTIVE' ? `${icon('lock', 14)} Khóa` : `${icon('unlock', 14)} Mở khóa`}
          </button>
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
        render: (row) => statusBadge(row.status),
      },
      {
        label: 'Thao tác',
        align: 'right',
        render: (row) => `<div class="cell-actions">
          <button type="button" class="btn btn-ghost btn-sm detail" data-id="${esc(row.id)}">Chi tiết</button>
          <button type="button" class="btn btn-ghost btn-sm edit" data-id="${esc(row.id)}">Sửa</button>
          <button type="button" class="btn ${row.status === 'ACTIVE' ? 'btn-danger' : 'btn-success'} btn-sm toggle" data-id="${esc(row.id)}" data-status="${esc(row.status)}">
            ${row.status === 'ACTIVE' ? `${icon('lock', 14)} Khóa` : `${icon('unlock', 14)} Mở khóa`}
          </button>
        </div>`,
      },
    ];

    const emptyHtml = hasFilter
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

    const contentHtml = `<div class="stack-20">
      <div class="meta-tabs" role="tablist" aria-label="Phân loại tài khoản">
        <a class="meta-tab-btn ${activeRole === 'COACH' ? 'active' : ''}" role="tab" aria-selected="${activeRole === 'COACH'}" href="#/admin/coaches">Huấn luyện viên (Coach)</a>
        <a class="meta-tab-btn ${activeRole === 'MEMBER' ? 'active' : ''}" role="tab" aria-selected="${activeRole === 'MEMBER'}" href="#/admin/members">Hội viên (Member)</a>
      </div>

      ${renderBanner({
        kind: 'info',
        iconName: 'shield',
        title: 'Ranh giới riêng tư & Trần suất cứng',
        text: 'Danh sách chỉ hiển thị thông tin vận hành bằng họ tên (UUID kỹ thuật nằm trong Drawer chi tiết). Trần 8 hội viên / Coach là cố định không chỉnh sửa được.',
      })}

      <form class="filter-bar" id="acc-filter-form">
        <input type="search" id="acc-search" class="form-control filter-grow" placeholder="Tìm theo họ tên, email hoặc số điện thoại…" value="${esc(search)}" aria-label="Tìm kiếm tài khoản" />
        <select id="acc-status" class="form-select filter-fixed" aria-label="Lọc trạng thái tài khoản">
          <option value="" ${!statusFilter ? 'selected' : ''}>Tất cả trạng thái</option>
          <option value="ACTIVE" ${statusFilter === 'ACTIVE' ? 'selected' : ''}>Đang hoạt động (ACTIVE)</option>
          <option value="DISABLED" ${statusFilter === 'DISABLED' ? 'selected' : ''}>Bị khóa (DISABLED)</option>
        </select>
        ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm" id="acc-clear-filters">Xóa bộ lọc</button>' : ''}
      </form>

      ${renderDataTable({
        columns,
        rows,
        emptyHtml,
        paginationHtml: renderPagination({
          ...pagination,
          prefix: 'acc',
          summaryNote: activeRole === 'COACH' ? 'Trần cứng 8 hội viên / Coach' : 'Tìm kiếm server-side an toàn >100 hội viên',
        }),
        ariaLabel: activeRole === 'COACH' ? 'Danh sách Huấn luyện viên' : 'Danh sách Hội viên',
      })}
    </div>`;

    shell({
      section,
      contentHtml,
      topbarActionsHtml: activeRole === 'COACH'
        ? `<button type="button" class="btn btn-primary" id="create">${icon('plus', 16)} Tạo Coach</button>`
        : '',
    });

    const reloadWith = (patch = {}) => {
      const nextSearch = patch.search !== undefined ? patch.search : (root.querySelector('#acc-search')?.value?.trim() || '');
      const nextStatus = patch.status !== undefined ? patch.status : (root.querySelector('#acc-status')?.value || '');
      const nextPage = patch.page !== undefined ? patch.page : page;

      const nextParams = new URLSearchParams();
      if (nextSearch) nextParams.set('search', nextSearch);
      if (nextStatus) nextParams.set('status', nextStatus);
      if (nextPage > 1) nextParams.set('page', String(nextPage));

      updateQuery({
        search: nextSearch || null,
        status: nextStatus || null,
        page: nextPage > 1 ? nextPage : null,
      }, { replace: true });

      return renderAccountsPage({ root, role: activeRole, params: nextParams, shell });
    };

    const debouncedSearch = debounce(() => reloadWith({ page: 1 }), 280);
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
    [root.querySelector('#acc-clear-filters'), root.querySelector('#acc-filter-reset')].filter(Boolean).forEach((btn) => {
      btn.onclick = () => reloadWith({ search: '', status: '', page: 1 });
    });

    bindPagination(root, {
      page: pagination.page,
      totalPages: pagination.totalPages,
      prefix: 'acc',
      onChange: (nextPage) => reloadWith({ page: nextPage }),
    });

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
              await reloadWith({ page });
              notice('Đã lưu thông tin tài khoản.');
            } catch (error) {
              ctrl.setBusy(false);
              ctrl.showError(error.message);
            }
          };
        },
      });
    };

    const createBtn = root.querySelector('#create') || root.querySelector('#create-empty');
    if (createBtn) createBtn.onclick = openCreateCoachModal;

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
              await reloadWith({ page });
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
            await reloadWith({ page });
            notice(summary, 'success');
          },
        });
      };
    });
  } catch (error) {
    shell({
      section,
      contentHtml: renderErrorState({ title: 'Không tải được danh sách tài khoản', message: error.message }),
    });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderAccountsPage({ root, role: activeRole, params, shell });
  }
}

export { buildHash };
