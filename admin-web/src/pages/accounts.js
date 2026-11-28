import { api, buildQuery, uploadRaw } from '../services/api.js';
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
import { openImageCropper } from '../components/image-cropper.js';
import { openImageViewer } from '../components/image-viewer.js';
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
const ACCOUNT_EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const ACCOUNT_PHONE_PATTERN = /^[+]?[0-9][0-9\s.-]{7,19}$/;

function validateAccountFullName(raw) {
  const value = String(raw || '').trim();
  if (value.length < 2 || value.length > 120) {
    return { valid: false, value, error: 'Họ và tên phải có từ 2 đến 120 ký tự.' };
  }
  return { valid: true, value, error: '' };
}

function validateAccountEmail(raw) {
  const value = String(raw || '').trim().toLowerCase();
  if (!value) {
    return { valid: false, value, error: 'Email đăng nhập không được để trống.' };
  }
  if (value.length > 255 || !ACCOUNT_EMAIL_PATTERN.test(value)) {
    return { valid: false, value, error: 'Email đăng nhập không hợp lệ.' };
  }
  return { valid: true, value, error: '' };
}

function validateAccountPhone(raw) {
  const trimmed = String(raw || '').trim();
  if (!trimmed) {
    return { valid: true, value: null, error: '' };
  }
  const digits = trimmed.replace(/\D/g, '');
  if (trimmed.length > 20 || !ACCOUNT_PHONE_PATTERN.test(trimmed) || digits.length < 8 || digits.length > 15) {
    return {
      valid: false,
      value: trimmed,
      error: 'Số điện thoại không hợp lệ (8–15 chữ số, ví dụ: 0901234567 hoặc +84901234567).',
    };
  }
  return { valid: true, value: trimmed, error: '' };
}

const GENDER_LABELS = Object.freeze({
  MALE: 'Nam',
  FEMALE: 'Nữ',
  OTHER: 'Khác',
  PREFER_NOT_TO_SAY: 'Không tiết lộ',
});

const EXPERIENCE_LABELS = Object.freeze({
  BEGINNER: 'Mới bắt đầu',
  INTERMEDIATE: 'Trung cấp',
  ADVANCED: 'Nâng cao',
});

const ACTIVITY_LABELS = Object.freeze({
  LOW: 'Thấp / Ít vận động',
  MODERATE: 'Vừa phải',
  HIGH: 'Cao / Vận động nhiều',
});

function renderSelectOptions(labelMap, selectedValue) {
  const current = selectedValue || '';
  return Object.entries(labelMap)
    .map(([val, label]) => `<option value="${esc(val)}" ${current === val ? 'selected' : ''}>${esc(label)}</option>`)
    .join('');
}

function resolveAvatarUrl(url, mediaId, { size = null } = {}) {
  if (!url) return '';
  const [base, query] = url.split('?');
  const params = new URLSearchParams(query || '');
  if (size) params.set('size', size);
  if (mediaId && !params.has('v')) params.set('v', mediaId);
  const qs = params.toString();
  return qs ? `${base}?${qs}` : base;
}

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
  // EXPLICIT PRIVACY ALLOWLIST: NEVER read or display healthNotes, injuryNotes, weightKg,
  // bodyFatPercent, journal, messages, aiMessages, etc.
  const prof = detail.profile || detail;

  const directAvatarUrl = resolveAvatarUrl(detail.avatarUrl, detail.avatarMediaId);
  const thumbAvatarUrl = resolveAvatarUrl(detail.avatarThumbnailUrl || detail.avatarUrl, detail.avatarMediaId, { size: '120' });
  const avatarContent = thumbAvatarUrl
    ? `<img src="${esc(thumbAvatarUrl)}" alt="${esc(detail.fullName)}" class="meta-avatar-img" />`
    : `<span class="meta-avatar-text">${esc(initials(detail.fullName))}</span>`;

  const identityRows = `
    <div class="impact-row" style="align-items:center;">
      <span class="impact-key">Ảnh đại diện</span>
      <span class="impact-val">
        <span class="meta-avatar ${role === 'COACH' ? 'meta-avatar-coach' : ''} ${directAvatarUrl ? 'clickable-avatar' : ''}" style="width:40px; height:40px;" ${directAvatarUrl ? `data-view-avatar="${esc(directAvatarUrl)}" data-avatar-title="${esc(detail.fullName)}" title="Nhấp để xem ảnh phóng to"` : ''}>${avatarContent}</span>
      </span>
    </div>
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
    const specialties = Array.isArray(prof.specialties) ? prof.specialties : [];
    const expYears = Number(prof.experienceYears ?? 0);
    opsBlock = `<div class="impact-box">
      <div class="impact-row"><span class="impact-key">Trần suất học viên</span><span class="impact-val"><span class="meta-badge meta-badge-info tabular">Trần cứng 8 hội viên / Coach</span></span></div>
      <div class="impact-row"><span class="impact-key">Suất đang chiếm</span><span class="impact-val tabular">${usedSlots} / 8 suất</span></div>
      <div class="impact-row"><span class="impact-key">Quan hệ đang hoạt động</span><span class="impact-val tabular">${activeRels}</span></div>
      <div class="impact-row"><span class="impact-key">Suất giữ chỗ 15 phút</span><span class="impact-val tabular">${openHolds}</span></div>
      <div class="impact-row"><span class="impact-key">Lịch tuần cố định</span><span class="impact-val">${scheduleConfigured === true ? statusBadge('ACTIVE', 'Đã cấu hình') : scheduleConfigured === false ? statusBadge('HIDDEN', 'Chưa cấu hình') : '—'}</span></div>
      <div class="impact-divider"></div>
      <div style="font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:0.5px; color:var(--meta-accent,#FF5E36); margin-bottom:8px;">Hồ sơ chuyên môn Coach (CSDL)</div>
      <div class="impact-row"><span class="impact-key">Kinh nghiệm</span><span class="impact-val tabular">${expYears} năm</span></div>
      <div class="impact-row"><span class="impact-key">Chuyên môn</span><span class="impact-val">${specialties.length ? esc(specialties.join(', ')) : 'Chưa cập nhật'}</span></div>
      <div class="impact-row"><span class="impact-key">Bằng cấp / Chứng chỉ</span><span class="impact-val">${prof.qualifications ? esc(prof.qualifications) : 'Chưa cập nhật'}</span></div>
      <div class="impact-row"><span class="impact-key">Lịch trực / Khả dụng</span><span class="impact-val">${prof.availabilityNote ? esc(prof.availabilityNote) : 'Chưa cập nhật'}</span></div>
      <div class="impact-row"><span class="impact-key">Giới thiệu</span><span class="impact-val">${prof.biography ? esc(prof.biography) : 'Chưa cập nhật'}</span></div>
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
      <div class="impact-divider"></div>
      <div style="font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:0.5px; color:var(--meta-accent,#FF5E36); margin-bottom:8px;">Hồ sơ hội viên (CSDL)</div>
      <div class="impact-row"><span class="impact-key">Giới tính</span><span class="impact-val">${prof.gender ? (GENDER_LABELS[prof.gender] || esc(prof.gender)) : 'Chưa thiết lập'}</span></div>
      <div class="impact-row"><span class="impact-key">Ngày sinh</span><span class="impact-val tabular">${prof.dateOfBirth ? formatDateVN(prof.dateOfBirth) : 'Chưa thiết lập'}</span></div>
      <div class="impact-row"><span class="impact-key">Chiều cao</span><span class="impact-val tabular">${prof.heightCm ? `${prof.heightCm} cm` : 'Chưa thiết lập'}</span></div>
      <div class="impact-row"><span class="impact-key">Trình độ</span><span class="impact-val">${prof.experienceLevel ? (EXPERIENCE_LABELS[prof.experienceLevel] || esc(prof.experienceLevel)) : 'Chưa thiết lập'}</span></div>
      <div class="impact-row"><span class="impact-key">Mức vận động</span><span class="impact-val">${prof.activityLevel ? (ACTIVITY_LABELS[prof.activityLevel] || esc(prof.activityLevel)) : 'Chưa thiết lập'}</span></div>
      <div class="impact-row"><span class="impact-key">Mục tiêu</span><span class="impact-val">${prof.fitnessGoal ? esc(prof.fitnessGoal) : 'Chưa thiết lập'}</span></div>
      <div class="impact-row"><span class="impact-key">Dinh dưỡng</span><span class="impact-val">${prof.dietaryPreferences ? esc(prof.dietaryPreferences) : 'Chưa thiết lập'}</span></div>
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

  const renderPersonCell = (row, isCoach = false) => {
    const directAvatarUrl = resolveAvatarUrl(row.avatarUrl, row.avatarMediaId);
    const thumbAvatarUrl = resolveAvatarUrl(row.avatarThumbnailUrl || row.avatarUrl, row.avatarMediaId, { size: '120' });
    const avatarContent = thumbAvatarUrl
      ? `<img src="${esc(thumbAvatarUrl)}" alt="${esc(row.fullName)}" class="meta-avatar-img" onerror="this.remove();" />`
      : esc(initials(row.fullName));
    return `<div class="person-cell">
      <span class="meta-avatar ${isCoach ? 'meta-avatar-coach' : ''} ${directAvatarUrl ? 'clickable-avatar' : ''}" ${directAvatarUrl ? `data-view-avatar="${esc(directAvatarUrl)}" data-avatar-title="${esc(row.fullName)}" title="Nhấp để xem ảnh phóng to"` : ''}>${avatarContent}</span>
      <div>
        <span class="person-name">${esc(row.fullName)}</span>
        <span class="person-sub">${esc(row.email)}</span>
      </div>
    </div>`;
  };

  const columns = activeRole === 'COACH' ? [
      {
        label: 'Huấn luyện viên',
        render: (row) => renderPersonCell(row, true),
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
        render: (row) => renderPersonCell(row, false),
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
          drawer?.dialog?.querySelectorAll?.('[data-view-avatar]')?.forEach((el) => {
            el.onclick = (e) => {
              e.stopPropagation();
              openImageViewer({ src: el.dataset.viewAvatar, title: `Ảnh đại diện: ${el.dataset.avatarTitle || ''}` });
            };
          });
        } catch (error) {
          drawer?.setBody(renderErrorState({ title: 'Không tải được hồ sơ chi tiết', message: error.message }));
        }
      };
    });

    root.querySelectorAll('[data-view-avatar]').forEach((el) => {
      el.onclick = (e) => {
        e.stopPropagation();
        openImageViewer({
          src: el.dataset.viewAvatar,
          title: `Ảnh đại diện: ${el.dataset.avatarTitle || ''}`,
        });
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
              toast(`Đã tạo tài khoản Coach ${fullName} với trần cứng 8 hội viên.`, 'success');
            } catch (error) {
              ctrl.setBusy(false);
              ctrl.showError(error.message);
            }
          };
        },
      });
    };

    // 3. Edit Account Modal (Shared 2-col layout: avatar + basic account info on left; Member or Coach profile on right — NEVER memberLimit edit)
    const openEditModal = (row) => {
      if (!row) return;
      const isMember = activeRole === 'MEMBER';
      const prof = row.profile || row;
      const todayIso = new Date().toISOString().slice(0, 10);
      const currentAvatarUrl = resolveAvatarUrl(row.avatarUrl, row.avatarMediaId);
      const initialSpecialtiesArr = Array.isArray(prof.specialties) ? prof.specialties : [];

      openModal({
        maxWidth: '960px',
        title: isMember ? `Cập nhật hội viên: ${row.fullName}` : `Cập nhật Huấn luyện viên: ${row.fullName}`,
        subtitle: isMember
          ? 'Cập nhật ảnh đại diện, thông tin tài khoản và hồ sơ hội viên theo CSDL (Audit Log)'
          : 'Cập nhật ảnh đại diện, thông tin tài khoản và hồ sơ chuyên môn Coach · Trần cứng 8 suất giữ nguyên',
        bodyHtml: `<form id="account-form" novalidate>
          <div class="meta-modal-body">
            <div class="meta-modal-horizontal-layout">
              <!-- Cột trái: Avatar và Thông tin tài khoản -->
              <div class="modal-col-left">
                <div class="edit-avatar-horizontal">
                  <div class="edit-avatar-preview-wrap" id="avatar-preview-wrap" role="button" tabindex="0" title="${currentAvatarUrl ? 'Nhấp để xem ảnh phóng to' : ''}">
                    <div class="meta-avatar meta-avatar-xl ${!isMember ? 'meta-avatar-coach' : ''}" id="edit-avatar-preview">
                      ${currentAvatarUrl
                        ? `<img src="${esc(currentAvatarUrl)}" alt="${esc(row.fullName)}" class="meta-avatar-img" />`
                        : `<span class="meta-avatar-text">${esc(initials(row.fullName))}</span>`}
                    </div>
                    <div class="avatar-zoom-badge" id="avatar-zoom-badge" title="Xem ảnh" ${!currentAvatarUrl ? 'style="display:none;"' : ''}>
                      ${icon('zoomIn', 14)}
                    </div>
                  </div>
                  <input type="file" id="edit-avatar-file" accept="image/png,image/jpeg,image/webp" style="display:none;" />
                  <div class="meta-avatar-dropdown-wrap">
                    <button type="button" class="btn btn-graphite btn-sm meta-avatar-trigger-btn" id="btn-avatar-dropdown" aria-haspopup="true" aria-expanded="false">
                      ${icon('camera', 15)} <span>Tùy chọn ảnh</span> ${icon('chevronDown', 13)}
                    </button>
                    <div class="meta-avatar-dropdown-menu" id="avatar-dropdown-menu" hidden>
                      <button type="button" class="meta-dropdown-item" id="btn-view-avatar" ${!currentAvatarUrl ? 'style="display:none;"' : ''}>
                        ${icon('eye', 15)} <span>Xem ảnh phóng to</span>
                      </button>
                      <button type="button" class="meta-dropdown-item" id="btn-pick-avatar">
                        ${icon('upload', 15)} <span>Tải ảnh mới...</span>
                      </button>
                      <button type="button" class="meta-dropdown-item" id="btn-crop-avatar" ${!currentAvatarUrl ? 'style="display:none;"' : ''}>
                        ${icon('crop', 15)} <span>Cắt lại ảnh</span>
                      </button>
                      <div class="meta-dropdown-divider" id="avatar-menu-divider" ${!currentAvatarUrl ? 'style="display:none;"' : ''}></div>
                      <button type="button" class="meta-dropdown-item text-danger" id="btn-remove-avatar" ${!currentAvatarUrl ? 'style="display:none;"' : ''}>
                        ${icon('trash', 15)} <span>Gỡ ảnh</span>
                      </button>
                    </div>
                  </div>
                  <div class="field-hint" style="font-size:11px; margin-top:4px;">JPG, PNG, WebP tối đa 5MB.</div>
                  <div class="field-error" id="edit-avatar-error" aria-live="polite"></div>
                </div>

                <div class="field">
                  <label class="field-label" for="edit-fullName">Họ và tên <span class="text-danger">*</span></label>
                  <input id="edit-fullName" class="form-control" name="fullName" value="${esc(row.fullName || '')}" required minlength="2" maxlength="120" />
                  <span class="field-error" id="edit-fullName-error" aria-live="polite"></span>
                </div>

                <div class="field">
                  <label class="field-label" for="edit-email">Email đăng nhập <span class="text-danger">*</span></label>
                  <input id="edit-email" class="form-control" name="email" type="email" value="${esc(row.email || '')}" required maxlength="255" placeholder="${isMember ? 'member@metagym.vn' : 'coach@metagym.vn'}" />
                  <span class="field-hint">Dùng để đăng nhập ứng dụng Meta Gym.</span>
                  <span class="field-error" id="edit-email-error" aria-live="polite"></span>
                </div>

                <div class="field">
                  <label class="field-label" for="edit-phone">Số điện thoại</label>
                  <input id="edit-phone" class="form-control tabular" name="phone" type="tel" value="${esc(row.phone || '')}" maxlength="20" placeholder="Ví dụ: 0901234567" />
                  <span class="field-hint">Để trống hoặc nhập 8–15 chữ số hợp lệ.</span>
                  <span class="field-error" id="edit-phone-error" aria-live="polite"></span>
                </div>
              </div>

              <!-- Cột phải: Hồ sơ theo vai trò -->
              <div class="modal-col-right">
                ${isMember ? `
                <div class="modal-section-card">
                  <div class="meta-form-section-header">
                    <span class="meta-form-section-title">Hồ sơ hội viên (CSDL)</span>
                    <span class="meta-form-section-desc">Thông tin cá nhân, thể chất và mục tiêu từ bảng member_profiles</span>
                  </div>

                  <div class="meta-form-grid-2">
                    <div class="field">
                      <label class="field-label" for="edit-gender">Giới tính</label>
                      <select id="edit-gender" class="form-control" name="gender">
                        <option value="">-- Chưa thiết lập --</option>
                        ${renderSelectOptions(GENDER_LABELS, prof.gender)}
                      </select>
                      <span class="field-error" id="edit-gender-error" aria-live="polite"></span>
                    </div>

                    <div class="field">
                      <label class="field-label" for="edit-dateOfBirth">Ngày sinh</label>
                      <input id="edit-dateOfBirth" class="form-control tabular" name="dateOfBirth" type="date" value="${esc(prof.dateOfBirth ? String(prof.dateOfBirth).slice(0, 10) : '')}" min="1900-01-01" max="${todayIso}" />
                      <span class="field-error" id="edit-dateOfBirth-error" aria-live="polite"></span>
                    </div>
                  </div>

                  <div class="meta-form-grid-2">
                    <div class="field">
                      <label class="field-label" for="edit-heightCm">Chiều cao (cm)</label>
                      <input id="edit-heightCm" class="form-control tabular" name="heightCm" type="number" step="0.5" min="30" max="300" value="${prof.heightCm ?? ''}" placeholder="Ví dụ: 172.5" />
                      <span class="field-error" id="edit-heightCm-error" aria-live="polite"></span>
                    </div>

                    <div class="field">
                      <label class="field-label" for="edit-experienceLevel">Trình độ tập luyện</label>
                      <select id="edit-experienceLevel" class="form-control" name="experienceLevel">
                        <option value="">-- Chưa thiết lập --</option>
                        ${renderSelectOptions(EXPERIENCE_LABELS, prof.experienceLevel)}
                      </select>
                      <span class="field-error" id="edit-experienceLevel-error" aria-live="polite"></span>
                    </div>
                  </div>

                  <div class="meta-form-grid-2">
                    <div class="field">
                      <label class="field-label" for="edit-activityLevel">Mức độ vận động</label>
                      <select id="edit-activityLevel" class="form-control" name="activityLevel">
                        <option value="">-- Chưa thiết lập --</option>
                        ${renderSelectOptions(ACTIVITY_LABELS, prof.activityLevel)}
                      </select>
                      <span class="field-error" id="edit-activityLevel-error" aria-live="polite"></span>
                    </div>

                    <div class="field">
                      <label class="field-label" for="edit-fitnessGoal">Mục tiêu tập luyện</label>
                      <input id="edit-fitnessGoal" class="form-control" name="fitnessGoal" value="${esc(prof.fitnessGoal || '')}" maxlength="500" placeholder="Ví dụ: Giảm mỡ, tăng cơ, cải thiện sức bền" />
                      <span class="field-error" id="edit-fitnessGoal-error" aria-live="polite"></span>
                    </div>
                  </div>

                  <div class="field">
                    <label class="field-label" for="edit-dietaryPreferences">Chế độ dinh dưỡng</label>
                    <input id="edit-dietaryPreferences" class="form-control" name="dietaryPreferences" value="${esc(prof.dietaryPreferences || '')}" maxlength="500" placeholder="Ví dụ: Eat clean, Keto, Không đường, Ăn chay..." />
                    <span class="field-error" id="edit-dietaryPreferences-error" aria-live="polite"></span>
                  </div>
                </div>` : `
                <div class="modal-section-card">
                  <div class="meta-form-section-header">
                    <span class="meta-form-section-title">Hồ sơ Huấn luyện viên (CSDL)</span>
                    <span class="meta-form-section-desc">Thông tin chuyên môn và giới thiệu từ bảng coach_profiles</span>
                  </div>

                  <div class="impact-box" style="margin-bottom:12px;">
                    <div class="impact-row">
                      <span class="impact-key">Trần suất học viên</span>
                      <span class="impact-val"><span class="meta-badge meta-badge-info tabular">Cố định 8 hội viên / Coach</span></span>
                    </div>
                  </div>

                  <div class="meta-form-grid-2">
                    <div class="field">
                      <label class="field-label" for="edit-experienceYears">Số năm kinh nghiệm</label>
                      <input id="edit-experienceYears" class="form-control tabular" name="experienceYears" type="number" step="1" min="0" max="80" value="${prof.experienceYears ?? 0}" placeholder="Ví dụ: 5" />
                      <span class="field-error" id="edit-experienceYears-error" aria-live="polite"></span>
                    </div>

                    <div class="field">
                      <label class="field-label" for="edit-qualifications">Bằng cấp / Chứng chỉ</label>
                      <input id="edit-qualifications" class="form-control" name="qualifications" value="${esc(prof.qualifications || '')}" maxlength="500" placeholder="Ví dụ: NASM-CPT, HLV Thể hình Quốc gia" />
                      <span class="field-error" id="edit-qualifications-error" aria-live="polite"></span>
                    </div>
                  </div>

                  <div class="field">
                    <label class="field-label" for="edit-specialties">Chuyên môn (ngăn cách bằng dấu phẩy)</label>
                    <input id="edit-specialties" class="form-control" name="specialties" value="${esc(initialSpecialtiesArr.join(', '))}" maxlength="600" placeholder="Ví dụ: Tăng cơ, Giảm mỡ, Calisthenics, Phục hồi chức năng" />
                    <span class="field-error" id="edit-specialties-error" aria-live="polite"></span>
                  </div>

                  <div class="field">
                    <label class="field-label" for="edit-availabilityNote">Ghi chú lịch trực / Khả dụng</label>
                    <input id="edit-availabilityNote" class="form-control" name="availabilityNote" value="${esc(prof.availabilityNote || '')}" maxlength="500" placeholder="Ví dụ: Thứ 2 – Thứ 7 · 06:00 – 20:00" />
                    <span class="field-error" id="edit-availabilityNote-error" aria-live="polite"></span>
                  </div>

                  <div class="field">
                    <label class="field-label" for="edit-biography">Giới thiệu bản thân</label>
                    <textarea id="edit-biography" class="form-control" name="biography" rows="4" maxlength="2000" placeholder="Kinh nghiệm huấn luyện, thành tích thi đấu, phong cách hướng dẫn hội viên...">${esc(prof.biography || '')}</textarea>
                    <span class="field-error" id="edit-biography-error" aria-live="polite"></span>
                  </div>
                </div>`}
              </div>
            </div>
          </div>
          <div class="meta-modal-footer">
            <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
            <button type="submit" class="btn btn-primary" data-modal-submit style="min-width:140px;">
              ${icon('check')} <span>Lưu thay đổi</span>
            </button>
          </div>
        </form>`,
        onMount(ctrl) {
          const form = ctrl.dialog.querySelector('#account-form');
          const fullNameInput = form.querySelector('[name="fullName"]');
          const emailInput = form.querySelector('[name="email"]');
          const phoneInput = form.querySelector('[name="phone"]');

          const avatarDropdownBtn = form.querySelector('#btn-avatar-dropdown');
          const avatarDropdownMenu = form.querySelector('#avatar-dropdown-menu');
          const viewAvatarBtn = form.querySelector('#btn-view-avatar');
          const pickAvatarBtn = form.querySelector('#btn-pick-avatar');
          const cropAvatarBtn = form.querySelector('#btn-crop-avatar');
          const fileInput = form.querySelector('#edit-avatar-file');
          const removeAvatarBtn = form.querySelector('#btn-remove-avatar');
          const previewWrap = form.querySelector('#avatar-preview-wrap');
          const previewEl = form.querySelector('#edit-avatar-preview');
          const avatarErrorEl = form.querySelector('#edit-avatar-error');
          const zoomBadge = form.querySelector('#avatar-zoom-badge');
          const menuDivider = form.querySelector('#avatar-menu-divider');

          const genderInput = isMember ? form.querySelector('[name="gender"]') : null;
          const dobInput = isMember ? form.querySelector('[name="dateOfBirth"]') : null;
          const expInput = isMember ? form.querySelector('[name="experienceLevel"]') : null;
          const actInput = isMember ? form.querySelector('[name="activityLevel"]') : null;
          const heightInput = isMember ? form.querySelector('[name="heightCm"]') : null;
          const fitnessGoalInput = isMember ? form.querySelector('[name="fitnessGoal"]') : null;
          const dietaryInput = isMember ? form.querySelector('[name="dietaryPreferences"]') : null;

          const expYearsInput = !isMember ? form.querySelector('[name="experienceYears"]') : null;
          const qualificationsInput = !isMember ? form.querySelector('[name="qualifications"]') : null;
          const specialtiesInput = !isMember ? form.querySelector('[name="specialties"]') : null;
          const availabilityNoteInput = !isMember ? form.querySelector('[name="availabilityNote"]') : null;
          const biographyInput = !isMember ? form.querySelector('[name="biography"]') : null;

          let pendingAvatarFile = null;
          let removeAvatarFlag = false;
          let currentRawFile = null;
          let activeAvatarUrl = currentAvatarUrl || null;

          const closeDropdown = () => {
            if (avatarDropdownMenu) {
              avatarDropdownMenu.hidden = true;
              if (avatarDropdownBtn) avatarDropdownBtn.setAttribute('aria-expanded', 'false');
            }
          };

          const openDropdown = () => {
            if (avatarDropdownMenu) {
              avatarDropdownMenu.hidden = false;
              if (avatarDropdownBtn) avatarDropdownBtn.setAttribute('aria-expanded', 'true');
            }
          };

          const toggleDropdown = () => {
            if (!avatarDropdownMenu) return;
            if (avatarDropdownMenu.hidden) openDropdown();
            else closeDropdown();
          };

          if (avatarDropdownBtn) {
            avatarDropdownBtn.onclick = (e) => {
              e.preventDefault();
              e.stopPropagation();
              toggleDropdown();
            };
          }

          const onDocClick = (e) => {
            if (!document.body.contains(form)) {
              document.removeEventListener('click', onDocClick);
              return;
            }
            if (!avatarDropdownMenu || avatarDropdownMenu.hidden) return;
            if (!avatarDropdownBtn?.contains?.(e.target) && !avatarDropdownMenu?.contains?.(e.target)) {
              closeDropdown();
            }
          };
          document.addEventListener('click', onDocClick);

          const updateAvatarUi = (hasImage, displayUrl) => {
            activeAvatarUrl = hasImage ? displayUrl : null;
            if (viewAvatarBtn) viewAvatarBtn.style.display = hasImage ? 'flex' : 'none';
            if (cropAvatarBtn) cropAvatarBtn.style.display = hasImage ? 'flex' : 'none';
            if (removeAvatarBtn) removeAvatarBtn.style.display = hasImage ? 'flex' : 'none';
            if (menuDivider) menuDivider.style.display = hasImage ? 'block' : 'none';
            if (zoomBadge) zoomBadge.style.display = hasImage ? 'flex' : 'none';
            if (previewWrap) {
              previewWrap.title = hasImage ? 'Nhấp để xem ảnh phóng to' : '';
              previewWrap.style.cursor = hasImage ? 'pointer' : 'default';
            }
          };

          const viewCurrentAvatar = () => {
            if (!activeAvatarUrl) return;
            openImageViewer({
              src: activeAvatarUrl,
              title: `Ảnh đại diện: ${fullNameInput?.value?.trim() || row.fullName}`,
            });
          };

          if (previewWrap) {
            previewWrap.onclick = () => {
              if (activeAvatarUrl) viewCurrentAvatar();
            };
            previewWrap.onkeydown = (e) => {
              if ((e.key === 'Enter' || e.key === ' ') && activeAvatarUrl) {
                e.preventDefault();
                viewCurrentAvatar();
              }
            };
          }

          if (viewAvatarBtn) {
            viewAvatarBtn.onclick = () => {
              closeDropdown();
              viewCurrentAvatar();
            };
          }

          const triggerCrop = (fileToCrop) => {
            if (!fileToCrop) return;
            openImageCropper({
              file: fileToCrop,
              outputSize: 512,
              circular: true,
              onApply: ({ blob, dataUrl, file: croppedFile }) => {
                pendingAvatarFile = croppedFile || blob;
                removeAvatarFlag = false;
                const src = dataUrl || (blob ? (typeof URL?.createObjectURL === 'function' ? URL.createObjectURL(blob) : '') : '');
                if (previewEl && src) {
                  previewEl.innerHTML = `<img src="${src}" alt="Preview" class="meta-avatar-img" />`;
                }
                updateAvatarUi(true, src);
                if (avatarErrorEl) avatarErrorEl.textContent = '';
              },
            });
          };

          if (pickAvatarBtn && fileInput) {
            pickAvatarBtn.onclick = () => {
              closeDropdown();
              fileInput.value = '';
              fileInput.click();
            };
            fileInput.onchange = (e) => {
              const file = e.target?.files?.[0];
              if (!file) return;
              if (avatarErrorEl) avatarErrorEl.textContent = '';
              if (file.size > 5 * 1024 * 1024) {
                if (avatarErrorEl) avatarErrorEl.textContent = 'Dung lượng ảnh tối đa 5MB.';
                fileInput.value = '';
                return;
              }
              const isAllowed = file.type?.startsWith('image/')
                || ['image/png', 'image/jpeg', 'image/webp', 'image/jpg', 'image/pjpeg', 'image/x-png'].includes((file.type || '').toLowerCase())
                || /\.(jpe?g|png|webp)$/i.test(file.name || '');
              if (!isAllowed) {
                if (avatarErrorEl) avatarErrorEl.textContent = 'Chỉ chấp nhận ảnh PNG, JPG hoặc WebP.';
                fileInput.value = '';
                return;
              }
              currentRawFile = file;
              triggerCrop(file);
            };
          }

          if (cropAvatarBtn) {
            cropAvatarBtn.onclick = () => {
              closeDropdown();
              const fileToCrop = currentRawFile || pendingAvatarFile || currentAvatarUrl;
              if (fileToCrop) triggerCrop(fileToCrop);
            };
          }

          if (removeAvatarBtn) {
            removeAvatarBtn.onclick = () => {
              closeDropdown();
              pendingAvatarFile = null;
              currentRawFile = null;
              removeAvatarFlag = Boolean(row.avatarMediaId || currentAvatarUrl);
              if (fileInput) fileInput.value = '';
              if (previewEl) {
                previewEl.innerHTML = `<span class="meta-avatar-text">${esc(initials(fullNameInput?.value || row.fullName))}</span>`;
              }
              updateAvatarUi(false, null);
              if (avatarErrorEl) avatarErrorEl.textContent = '';
            };
          }

          const setFieldError = (fieldName, message) => {
            const input = form.querySelector(`[name="${fieldName}"]`);
            const errEl = form.querySelector(`#edit-${fieldName}-error`);
            if (errEl) errEl.textContent = message || '';
            if (input) {
              if (message) input.setAttribute?.('aria-invalid', 'true');
              else input.removeAttribute?.('aria-invalid');
            }
          };

          const validators = {
            fullName: () => validateAccountFullName(fullNameInput?.value),
            email: () => validateAccountEmail(emailInput?.value),
            phone: () => validateAccountPhone(phoneInput?.value),
            ...(isMember ? {
              dateOfBirth: () => {
                const val = dobInput?.value?.trim();
                if (!val) return { valid: true, value: null, error: '' };
                const d = new Date(val);
                const now = new Date();
                if (Number.isNaN(d.getTime()) || d > now || d.getUTCFullYear() < 1900) {
                  return { valid: false, value: val, error: 'Ngày sinh không hợp lệ (từ 1900 đến hiện tại).' };
                }
                return { valid: true, value: val, error: '' };
              },
              heightCm: () => {
                const val = heightInput?.value?.trim();
                if (!val) return { valid: true, value: null, error: '' };
                const num = Number(val);
                if (Number.isNaN(num) || num < 30 || num > 300) {
                  return { valid: false, value: num, error: 'Chiều cao phải từ 30 đến 300 cm.' };
                }
                return { valid: true, value: num, error: '' };
              },
            } : {
              experienceYears: () => {
                const val = expYearsInput?.value?.trim();
                if (!val) return { valid: true, value: 0, error: '' };
                const num = Number(val);
                if (!Number.isInteger(num) || num < 0 || num > 80) {
                  return { valid: false, value: num, error: 'Số năm kinh nghiệm phải là số nguyên từ 0 đến 80.' };
                }
                return { valid: true, value: num, error: '' };
              },
            }),
          };

          [
            ['fullName', fullNameInput],
            ['email', emailInput],
            ...(isMember ? [
              ['dateOfBirth', dobInput],
              ['heightCm', heightInput],
            ] : [
              ['experienceYears', expYearsInput],
            ]),
            ['phone', phoneInput],
          ].forEach(([fieldName, input]) => {
            if (!input) return;
            input.oninput = () => {
              setFieldError(fieldName, '');
              ctrl.showError('');
            };
            input.onblur = () => {
              const check = validators[fieldName]();
              setFieldError(fieldName, check.valid ? '' : check.error);
            };
          });

          form.onsubmit = async (event) => {
            event.preventDefault();
            ctrl.showError('');

            const nameCheck = validators.fullName();
            const emailCheck = validators.email();
            const phoneCheck = validators.phone();
            const dobCheck = isMember ? validators.dateOfBirth() : { valid: true, value: null, error: '' };
            const heightCheck = isMember ? validators.heightCm() : { valid: true, value: null, error: '' };
            const expYearsCheck = !isMember ? validators.experienceYears() : { valid: true, value: 0, error: '' };

            setFieldError('fullName', nameCheck.valid ? '' : nameCheck.error);
            setFieldError('email', emailCheck.valid ? '' : emailCheck.error);
            if (isMember) {
              setFieldError('dateOfBirth', dobCheck.valid ? '' : dobCheck.error);
              setFieldError('heightCm', heightCheck.valid ? '' : heightCheck.error);
            } else {
              setFieldError('experienceYears', expYearsCheck.valid ? '' : expYearsCheck.error);
            }
            setFieldError('phone', phoneCheck.valid ? '' : phoneCheck.error);

            const invalidEntry = [
              ['fullName', nameCheck, fullNameInput],
              ['email', emailCheck, emailInput],
              ...(isMember ? [
                ['dateOfBirth', dobCheck, dobInput],
                ['heightCm', heightCheck, heightInput],
              ] : [
                ['experienceYears', expYearsCheck, expYearsInput],
              ]),
              ['phone', phoneCheck, phoneInput],
            ].find(([, check]) => !check.valid);

            if (invalidEntry) {
              invalidEntry[2]?.focus?.();
              return;
            }

            const initialFullName = String(row.fullName || '').trim();
            const initialEmail = String(row.email || '').trim().toLowerCase();
            const initialPhone = String(row.phone || '').trim() || null;

            const initialGender = prof.gender || null;
            const currentGender = genderInput?.value || null;

            const initialDob = (prof.dateOfBirth ? String(prof.dateOfBirth).slice(0, 10) : '') || null;
            const currentDob = dobCheck.value;

            const initialExp = prof.experienceLevel || null;
            const currentExp = expInput?.value || null;

            const initialAct = prof.activityLevel || null;
            const currentAct = actInput?.value || null;

            const initialHeight = prof.heightCm !== undefined && prof.heightCm !== null ? Number(prof.heightCm) : null;
            const currentHeight = heightCheck.value;

            const initialGoal = (prof.fitnessGoal || '').trim() || null;
            const currentGoal = fitnessGoalInput?.value ? fitnessGoalInput.value.trim() : null;

            const initialDiet = (prof.dietaryPreferences || '').trim() || null;
            const currentDiet = dietaryInput?.value ? dietaryInput.value.trim() : null;

            const initialExpYears = Number(prof.experienceYears ?? 0);
            const currentExpYears = Number(expYearsCheck.value ?? 0);

            const initialQual = (prof.qualifications || '').trim() || null;
            const currentQual = qualificationsInput?.value ? qualificationsInput.value.trim() : null;

            const initialAvail = (prof.availabilityNote || '').trim() || null;
            const currentAvail = availabilityNoteInput?.value ? availabilityNoteInput.value.trim() : null;

            const initialBio = (prof.biography || '').trim() || null;
            const currentBio = biographyInput?.value ? biographyInput.value.trim() : null;

            const currentSpecsArr = String(specialtiesInput?.value || '')
              .split(',')
              .map((s) => s.trim())
              .filter(Boolean);

            const avatarChanged = Boolean(pendingAvatarFile) || removeAvatarFlag;
            const basicUnchanged = nameCheck.value === initialFullName
              && phoneCheck.value === initialPhone
              && emailCheck.value === initialEmail;

            const profileUnchanged = isMember
              ? (
                currentGender === initialGender
                && currentDob === initialDob
                && currentExp === initialExp
                && currentAct === initialAct
                && currentHeight === initialHeight
                && currentGoal === initialGoal
                && currentDiet === initialDiet
              )
              : (
                currentExpYears === initialExpYears
                && currentQual === initialQual
                && currentAvail === initialAvail
                && currentBio === initialBio
                && JSON.stringify(currentSpecsArr) === JSON.stringify(initialSpecialtiesArr)
              );

            if (basicUnchanged && profileUnchanged && !avatarChanged) {
              ctrl.showError('Chưa có thay đổi nào để lưu.');
              return;
            }

            const payload = { fullName: nameCheck.value, phone: phoneCheck.value };
            if (emailCheck.value !== initialEmail) payload.email = emailCheck.value;
            if (removeAvatarFlag) payload.avatarMediaId = null;

            if (isMember) {
              if (currentGender !== initialGender) payload.gender = currentGender;
              if (currentDob !== initialDob) payload.dateOfBirth = currentDob;
              if (currentExp !== initialExp) payload.experienceLevel = currentExp;
              if (currentAct !== initialAct) payload.activityLevel = currentAct;
              if (currentHeight !== initialHeight) payload.heightCm = currentHeight;
              if (currentGoal !== initialGoal) payload.fitnessGoal = currentGoal;
              if (currentDiet !== initialDiet) payload.dietaryPreferences = currentDiet;
            } else {
              if (currentExpYears !== initialExpYears) payload.experienceYears = currentExpYears;
              if (currentQual !== initialQual) payload.qualifications = currentQual;
              if (currentAvail !== initialAvail) payload.availabilityNote = currentAvail;
              if (currentBio !== initialBio) payload.biography = currentBio;
              if (JSON.stringify(currentSpecsArr) !== JSON.stringify(initialSpecialtiesArr)) payload.specialties = currentSpecsArr;
            }

            ctrl.setBusy(true);
            try {
              if (pendingAvatarFile) {
                const uploadRes = await uploadRaw(
                  `/admin/users/${encodeURIComponent(row.id)}/avatar`,
                  pendingAvatarFile,
                  pendingAvatarFile.type || 'image/jpeg',
                );
                if (uploadRes?.data?.avatarUrl) {
                  row.avatarUrl = uploadRes.data.avatarUrl;
                  row.avatarMediaId = uploadRes.data.avatarMediaId;
                }
                pendingAvatarFile = null;
              }

              if (!basicUnchanged || !profileUnchanged || removeAvatarFlag) {
                await api(`/admin/users/${encodeURIComponent(row.id)}`, 'PATCH', payload);
              }

              ctrl.close();
              await reloadWith({ page: state.page });
              const emailChanged = emailCheck.value !== initialEmail;
              const roleTitle = isMember ? 'hội viên' : 'Huấn luyện viên';
              toast(emailChanged
                ? `Đã cập nhật thông tin ${roleTitle} ${nameCheck.value} (bao gồm email đăng nhập).`
                : `Đã cập nhật thông tin ${roleTitle} ${nameCheck.value}.`, 'success');
            } catch (error) {
              ctrl.setBusy(false);
              ctrl.showError(error.message);
              const fieldErrors = error?.details?.fields;
              if (fieldErrors && typeof fieldErrors === 'object') {
                for (const fieldName of [
                  'fullName', 'email', 'phone',
                  'dateOfBirth', 'heightCm', 'gender', 'fitnessGoal', 'experienceLevel', 'activityLevel', 'dietaryPreferences',
                  'experienceYears', 'qualifications', 'specialties', 'availabilityNote', 'biography',
                ]) {
                  const msgs = fieldErrors[fieldName];
                  if (Array.isArray(msgs) && msgs.length) {
                    setFieldError(fieldName, msgs[0]);
                  }
                }
              }
              if (error?.code === 'EMAIL_ALREADY_EXISTS' && !fieldErrors?.email?.length) {
                setFieldError('email', error.message || 'Email đã được sử dụng.');
              }
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
