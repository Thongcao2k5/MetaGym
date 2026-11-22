export const VN_TIMEZONE = 'Asia/Ho_Chi_Minh';

export function esc(value) {
  return String(value ?? '').replace(/[&<>"']/g, (char) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  })[char]);
}

export function vnd(amount) {
  const num = Number(amount ?? 0);
  if (!Number.isFinite(num)) return '0 ₫';
  const sign = num < 0 ? '-' : '';
  return `${sign}${new Intl.NumberFormat('vi-VN').format(Math.abs(Math.round(num)))} ₫`;
}

export function formatDateVN(value) {
  if (!value) return '—';
  if (/^\d{4}-\d{2}-\d{2}$/.test(String(value))) {
    const [y, m, d] = String(value).split('-');
    return `${d}/${m}/${y}`;
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return new Intl.DateTimeFormat('vi-VN', {
    timeZone: VN_TIMEZONE,
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(date);
}

export function formatDateTimeVN(value, { withSeconds = false } = {}) {
  if (!value) return '—';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return new Intl.DateTimeFormat('vi-VN', {
    timeZone: VN_TIMEZONE,
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    ...(withSeconds ? { second: '2-digit' } : {}),
    hour12: false,
  }).format(date);
}

export function isoDateVN(date = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: VN_TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
}

export function daysAgoVN(days) {
  return isoDateVN(new Date(Date.now() - days * 86400000));
}

export function initials(name) {
  const parts = String(name || '').trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return 'MG';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

export function emailInitial(email, fallback = 'A') {
  const trimmed = String(email || '').trim();
  return trimmed ? trimmed[0].toUpperCase() : fallback;
}

const BADGE_MAP = {
  ACTIVE: ['meta-badge-success', 'Đang hoạt động'],
  SUCCESS: ['meta-badge-success', 'Thành công'],
  COMPLETED: ['meta-badge-success', 'Hoàn tất'],
  ACCEPTED: ['meta-badge-success', 'Hai bên đồng ý'],
  ADMIN_APPROVED: ['meta-badge-success', 'Admin chấp thuận'],
  APPROVED: ['meta-badge-success', 'Đã duyệt'],
  SCHEDULED: ['meta-badge-info', 'Đã xếp lịch'],
  QUEUED: ['meta-badge-info', 'Chờ nối tiếp'],
  PENDING_COUNTERPARTY: ['meta-badge-info', 'Chờ đồng ý 72h'],
  PENDING: ['meta-badge-warning', 'Đang chờ'],
  COACH_LOCKED: ['meta-badge-warning', 'Coach bị khóa'],
  PAUSED_COACH_LOCKED: ['meta-badge-warning', 'Tạm ngưng · Coach bị khóa'],
  WAIT: ['meta-badge-warning', 'Chờ Coach'],
  OPEN: ['meta-badge-warning', 'Đang mở'],
  REFUND: ['meta-badge-coral', 'Chọn hoàn mô phỏng'],
  MEMBER_LOCKED: ['meta-badge-danger', 'Member bị khóa'],
  PAUSED_MEMBER_LOCKED: ['meta-badge-danger', 'Tạm ngưng · Member bị khóa'],
  DISPUTED: ['meta-badge-danger', 'Tranh chấp · DISPUTED'],
  DISABLED: ['meta-badge-danger', 'Bị khóa'],
  FAILED: ['meta-badge-danger', 'Thất bại'],
  CANCELLED: ['meta-badge-neutral', 'Đã hủy'],
  REJECTED: ['meta-badge-danger', 'Từ chối'],
  ADMIN_REJECTED: ['meta-badge-neutral', 'Admin từ chối'],
  SIMULATED_REFUND: ['meta-badge-danger', 'Hoàn mô phỏng'],
  VOID_REVERSAL: ['meta-badge-danger', 'Đã đảo VOID_REVERSAL'],
  PAUSED_MEMBERSHIP_EXPIRED: ['meta-badge-neutral', 'Tạm ngưng · Hết gói Gym'],
  MEMBERSHIP_EXPIRED: ['meta-badge-neutral', 'Hết gói Gym'],
  PAUSED: ['meta-badge-warning', 'Tạm ngưng'],
  EXPIRED: ['meta-badge-neutral', 'Hết hạn'],
  ENDED: ['meta-badge-neutral', 'Đã kết thúc'],
  INACTIVE: ['meta-badge-neutral', 'Ngừng bán'],
  HIDDEN: ['meta-badge-neutral', 'Đang ẩn'],
  NONE: ['meta-badge-neutral', 'Chưa thuê Coach'],
  RESOLVED_COACH_UNLOCKED: ['meta-badge-success', 'Đã mở khóa Coach'],
  RESOLVED_TRANSFERRED: ['meta-badge-info', 'Đã chuyển Coach'],
  RESOLVED_REFUNDED: ['meta-badge-danger', 'Đã hoàn mô phỏng'],
  RESOLVED_ENDED: ['meta-badge-neutral', 'Đã kết thúc'],
};

export function statusBadge(code, customLabel) {
  const [cls, defaultLabel] = BADGE_MAP[code] || ['meta-badge-neutral', code || '—'];
  const label = customLabel ?? defaultLabel;
  return `<span class="meta-badge ${cls}"><span class="badge-dot"></span>${esc(label)}</span>`;
}

export function relationshipStatusBadge(rel) {
  if (!rel) return statusBadge('NONE');
  if (rel.status === 'ACTIVE') return statusBadge('ACTIVE');
  if (rel.status === 'ENDED') return statusBadge('ENDED');
  if (rel.status === 'DISPUTED') return statusBadge('DISPUTED');
  if (rel.pauseReason === 'COACH_LOCKED') return statusBadge('PAUSED_COACH_LOCKED');
  if (rel.pauseReason === 'MEMBER_LOCKED') return statusBadge('PAUSED_MEMBER_LOCKED');
  if (rel.pauseReason === 'MEMBERSHIP_EXPIRED') return statusBadge('PAUSED_MEMBERSHIP_EXPIRED');
  return statusBadge(rel.status);
}

export function seatMeterHtml(usedSlots = 0, memberLimit = 8, openHoldCount = 0) {
  const limit = 8; // Hard cap 8 per S4 (never editable)
  const used = Math.max(0, Number(usedSlots ?? 0));
  const holds = Math.max(0, Number(openHoldCount ?? 0));
  const pct = Math.min(100, Math.round((used / limit) * 100));
  const cls = used >= limit ? 'full' : used >= 6 ? 'near' : '';
  return `<div class="seat-meter">
    <div class="seat-meter-row">
      <span class="tabular" style="color:var(--meta-text-strong)">${used} / ${limit} suất</span>
      <span style="color:var(--meta-text-secondary);font-size:11px">${holds > 0 ? `+${holds} giữ 15p` : 'Trần cứng 8'}</span>
    </div>
    <div class="seat-track" role="progressbar" aria-valuenow="${used}" aria-valuemin="0" aria-valuemax="${limit}" aria-label="Suất Coach ${used} trên ${limit}">
      <div class="seat-fill ${cls}" style="width:${pct}%"></div>
    </div>
  </div>`;
}

export function debounce(fn, delayMs = 280) {
  let timer = null;
  const debounced = (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), delayMs);
  };
  debounced.cancel = () => clearTimeout(timer);
  return debounced;
}

export function generateUuid() {
  if (globalThis.crypto?.randomUUID) {
    return globalThis.crypto.randomUUID();
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

export function methodLabel(method) {
  return ({
    FRONT_DESK: 'Tại quầy (Gym)',
    MOCK_QR: 'App (Mô phỏng QR)',
    VNPAY: 'VNPay Sandbox',
    MOMO: 'MoMo Sandbox',
    ZALOPAY: 'ZaloPay Sandbox',
  })[method] || method || '—';
}
