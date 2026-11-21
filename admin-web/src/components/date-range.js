import { daysAgoVN, esc, isoDateVN } from './format.js';
import { toast } from './toast.js';

export const DATE_PRESETS = [
  { id: '7d', label: '7 ngày qua' },
  { id: '30d', label: '30 ngày qua' },
  { id: '60d', label: '60 ngày qua' },
  { id: '90d', label: '90 ngày qua' },
  { id: 'this_month', label: 'Tháng này' },
  { id: 'last_month', label: 'Tháng trước' },
];

export function computeDatePreset(presetId) {
  const today = isoDateVN();
  if (presetId === '7d') return { from: daysAgoVN(6), to: today };
  if (presetId === '30d') return { from: daysAgoVN(29), to: today };
  if (presetId === '60d') return { from: daysAgoVN(59), to: today };
  if (presetId === '90d') return { from: daysAgoVN(89), to: today };
  if (presetId === 'this_month') return { from: `${today.slice(0, 8)}01`, to: today };
  if (presetId === 'last_month') {
    const [y, m] = today.split('-').map(Number);
    const firstPrev = new Date(Date.UTC(y, m - 2, 1));
    const lastPrev = new Date(Date.UTC(y, m - 1, 0));
    return {
      from: firstPrev.toISOString().slice(0, 10),
      to: lastPrev.toISOString().slice(0, 10),
    };
  }
  return { from: '', to: '' };
}

export function renderDateRangeFilter({
  prefix = 'dr',
  from = '',
  to = '',
  fromLabel = 'Từ ngày',
  toLabel = 'Đến ngày',
  applyLabel = 'Áp dụng',
  cancelLabel = 'Hủy',
  showCancel = true,
} = {}) {
  return `<div class="date-range-bar" id="${esc(prefix)}-range-bar">
    <div class="date-range-field">
      <label class="date-range-label" for="${esc(prefix)}-from">${esc(fromLabel)}</label>
      <input type="date" id="${esc(prefix)}-from" name="from" class="form-control tabular" value="${esc(from)}" />
    </div>
    <div class="date-range-field">
      <label class="date-range-label" for="${esc(prefix)}-to">${esc(toLabel)}</label>
      <input type="date" id="${esc(prefix)}-to" name="to" class="form-control tabular" value="${esc(to)}" />
    </div>
    <div class="date-range-actions">
      <button type="button" class="btn btn-primary" id="${esc(prefix)}-apply">${esc(applyLabel)}</button>
      ${showCancel ? `<button type="button" class="btn btn-ghost" id="${esc(prefix)}-cancel">${esc(cancelLabel)}</button>` : ''}
    </div>
  </div>`;
}

export function bindDateRangeFilter(container, { prefix = 'dr', onApply, onCancel } = {}) {
  if (!container) return;
  const fromEl = container.querySelector?.(`#${prefix}-from`);
  const toEl = container.querySelector?.(`#${prefix}-to`);
  const applyBtn = container.querySelector?.(`#${prefix}-apply`);
  const cancelBtn = container.querySelector?.(`#${prefix}-cancel`);

  if (applyBtn && typeof onApply === 'function') {
    applyBtn.onclick = () => {
      const from = fromEl?.value || '';
      const to = toEl?.value || '';
      if (from && to && from > to) {
        toast('Ngày bắt đầu không được lớn hơn ngày kết thúc.', 'warn');
        return;
      }
      onApply({ from, to });
    };
  }

  if (cancelBtn) {
    cancelBtn.onclick = () => {
      if (fromEl) fromEl.value = '';
      if (toEl) toEl.value = '';
      if (typeof onCancel === 'function') onCancel();
    };
  }
}
