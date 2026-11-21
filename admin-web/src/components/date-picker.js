import { esc, formatDateVN, isoDateVN } from './format.js';
import { icon } from './icons.js';
import { computeDatePreset, DATE_PRESETS } from './date-range.js';

const WEEKDAYS = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

function parseIso(iso) {
  const match = String(iso || '').match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return null;
  return { year: Number(match[1]), month: Number(match[2]), day: Number(match[3]) };
}

function toIso(year, month, day) {
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

function formatRangeSummary(from, to) {
  if (!from && !to) return 'Chọn khoảng thời gian';
  if (from && to) {
    const f = formatDateVN(from);
    const t = formatDateVN(to);
    return `${f.slice(0, 5)} - ${t}`;
  }
  return from ? `Từ ${formatDateVN(from)}` : `Đến ${formatDateVN(to)}`;
}

/* ==========================================================================
   1. DESKTOP: Two separate date inputs (Từ ngày / Đến ngày) + Calendar Popover
   ========================================================================== */
export function renderDateInput({
  id = '',
  name = '',
  value = '',
  placeholder = 'DD/MM/YYYY',
  ariaLabel = 'Chọn ngày',
} = {}) {
  const displayVal = value ? formatDateVN(value) : '';
  return `<div class="meta-date-field" data-date-field="${esc(id)}">
    <input type="hidden" id="${esc(id)}"${name ? ` name="${esc(name)}"` : ''} value="${esc(value)}" />
    <button type="button" class="form-control meta-date-trigger tabular" id="${esc(id)}-trigger" aria-label="${esc(ariaLabel)}" aria-expanded="false">
      <span class="meta-date-display${displayVal ? '' : ' is-placeholder'}">${esc(displayVal || placeholder)}</span>
      <span class="meta-date-icon">${icon('calendar', 16)}</span>
    </button>
    <div class="meta-date-popover" id="${esc(id)}-popover" hidden></div>
  </div>`;
}

export function bindDatePickers(container, { onChange } = {}) {
  if (!container) return;
  const fields = Array.from(container.querySelectorAll?.('[data-date-field]') || []);
  if (!fields.length) return;

  const closeAll = (exceptPopover = null) => {
    fields.forEach((field) => {
      const pop = field.querySelector?.('.meta-date-popover');
      const trig = field.querySelector?.('.meta-date-trigger');
      if (pop && pop !== exceptPopover) {
        pop.hidden = true;
        trig?.setAttribute?.('aria-expanded', 'false');
      }
    });
  };

  fields.forEach((field) => {
    const hiddenInput = field.querySelector?.('input[type="hidden"]');
    const trigger = field.querySelector?.('.meta-date-trigger');
    const display = field.querySelector?.('.meta-date-display');
    const popover = field.querySelector?.('.meta-date-popover');
    if (!hiddenInput || !trigger || !popover) return;

    const todayIso = isoDateVN();
    const initial = parseIso(hiddenInput.value) || parseIso(todayIso);
    let viewYear = initial.year;
    let viewMonth = initial.month;

    const syncDisplay = (iso) => {
      hiddenInput.value = iso || '';
      if (display) {
        display.textContent = iso ? formatDateVN(iso) : 'DD/MM/YYYY';
        display.classList?.toggle('is-placeholder', !iso);
      }
    };

    field.__syncDateValue = (iso) => {
      syncDisplay(iso);
      const parsed = parseIso(iso);
      if (parsed) {
        viewYear = parsed.year;
        viewMonth = parsed.month;
      }
    };

    const positionPopover = () => {
      if (!trigger.getBoundingClientRect || !popover.style) return;
      const rect = trigger.getBoundingClientRect();
      const popW = 288;
      const left = Math.max(12, Math.min(rect.left, (globalThis.window?.innerWidth || 1280) - popW - 12));
      const spaceBelow = (globalThis.window?.innerHeight || 800) - rect.bottom;
      popover.style.position = 'fixed';
      popover.style.left = `${left}px`;
      if (spaceBelow >= 310 || spaceBelow >= rect.top) {
        popover.style.top = `${rect.bottom + 6}px`;
        popover.style.bottom = 'auto';
      } else {
        popover.style.bottom = `${(globalThis.window?.innerHeight || 800) - rect.top + 6}px`;
        popover.style.top = 'auto';
      }
    };

    const renderCalendar = () => {
      const firstDayJs = new Date(Date.UTC(viewYear, viewMonth - 1, 1)).getUTCDay();
      const offset = (firstDayJs + 6) % 7;
      const daysInMonth = new Date(Date.UTC(viewYear, viewMonth, 0)).getUTCDate();
      const selectedIso = hiddenInput.value || '';

      const cells = [];
      for (let i = 0; i < offset; i += 1) {
        cells.push('<span class="meta-cal-empty"></span>');
      }
      for (let d = 1; d <= daysInMonth; d += 1) {
        const cellIso = toIso(viewYear, viewMonth, d);
        const isSelected = cellIso === selectedIso;
        const isToday = cellIso === todayIso;
        const cls = [
          'meta-cal-day',
          'tabular',
          isSelected ? 'is-selected' : '',
          isToday ? 'is-today' : '',
        ].filter(Boolean).join(' ');
        cells.push(`<button type="button" class="${cls}" data-cal-iso="${cellIso}">${d}</button>`);
      }

      popover.innerHTML = `
        <div class="meta-cal-head">
          <button type="button" class="btn btn-ghost btn-icon meta-cal-nav" data-cal-nav="-1" aria-label="Tháng trước">${icon('chevronLeft', 16)}</button>
          <span class="meta-cal-title tabular">Tháng ${String(viewMonth).padStart(2, '0')}/${viewYear}</span>
          <button type="button" class="btn btn-ghost btn-icon meta-cal-nav" data-cal-nav="1" aria-label="Tháng sau">${icon('chevronRight', 16)}</button>
        </div>
        <div class="meta-cal-weekdays">${WEEKDAYS.map((w) => `<span>${w}</span>`).join('')}</div>
        <div class="meta-cal-grid">${cells.join('')}</div>
      `;

      popover.querySelectorAll('[data-cal-nav]').forEach((navBtn) => {
        navBtn.onclick = (e) => {
          e.stopPropagation();
          const delta = Number(navBtn.dataset.calNav);
          viewMonth += delta;
          if (viewMonth < 1) {
            viewMonth = 12;
            viewYear -= 1;
          } else if (viewMonth > 12) {
            viewMonth = 1;
            viewYear += 1;
          }
          renderCalendar();
        };
      });

      popover.querySelectorAll('[data-cal-iso]').forEach((dayBtn) => {
        dayBtn.onclick = (e) => {
          e.stopPropagation();
          const picked = dayBtn.dataset.calIso;
          syncDisplay(picked);
          popover.hidden = true;
          trigger.setAttribute('aria-expanded', 'false');
          if (typeof onChange === 'function') onChange(hiddenInput.id, picked);
        };
      });
    };

    trigger.onclick = (e) => {
      e.stopPropagation();
      const willOpen = popover.hidden;
      closeAll(willOpen ? popover : null);
      if (willOpen) {
        const current = parseIso(hiddenInput.value) || parseIso(todayIso);
        viewYear = current.year;
        viewMonth = current.month;
        renderCalendar();
        positionPopover();
        popover.hidden = false;
        trigger.setAttribute('aria-expanded', 'true');
      } else {
        popover.hidden = true;
        trigger.setAttribute('aria-expanded', 'false');
      }
    };
  });

  if (container.addEventListener) {
    container.addEventListener('click', (e) => {
      if (!e.target?.closest?.('[data-date-field]')) {
        closeAll();
      }
    });
  }
}

export function setDatePickerValue(container, id, isoValue) {
  const field = container?.querySelector?.(`[data-date-field="${id}"]`);
  if (field?.__syncDateValue) {
    field.__syncDateValue(isoValue);
  }
}

/* ==========================================================================
   2. MOBILE: Unified single-button Range Picker + Top-layer Calendar Dialog
   ========================================================================== */
export function renderDateRangePicker({
  id = 'drp',
  from = '',
  to = '',
} = {}) {
  return `<div class="meta-drp" data-drp="${esc(id)}">
    <input type="hidden" id="${esc(id)}-from" value="${esc(from)}" />
    <input type="hidden" id="${esc(id)}-to" value="${esc(to)}" />
    <button type="button" class="form-control meta-drp-trigger tabular" id="${esc(id)}-trigger" aria-expanded="false">
      <span class="meta-drp-trigger-left">
        <span class="meta-date-icon">${icon('calendar', 16)}</span>
        <span class="meta-drp-summary${from || to ? '' : ' is-placeholder'}">${esc(formatRangeSummary(from, to))}</span>
      </span>
      <span class="meta-drp-chevron">${icon('chevronRight', 16)}</span>
    </button>
    <div class="meta-drp-panel" id="${esc(id)}-panel" hidden></div>
  </div>`;
}

export function bindDateRangePicker(container, { id = 'drp', onChange } = {}) {
  const rootEl = container?.querySelector?.(`[data-drp="${id}"]`);
  if (!rootEl) return;

  const fromInput = rootEl.querySelector?.(`#${id}-from`);
  const toInput = rootEl.querySelector?.(`#${id}-to`);
  const trigger = rootEl.querySelector?.(`#${id}-trigger`);
  const summaryEl = rootEl.querySelector?.('.meta-drp-summary');
  const panel = rootEl.querySelector?.(`#${id}-panel`);
  if (!fromInput || !toInput || !trigger || !panel) return;

  const todayIso = isoDateVN();
  let draftFrom = fromInput.value || '';
  let draftTo = toInput.value || '';
  let activePreset = 'custom';
  const initParsed = parseIso(draftFrom) || parseIso(todayIso);
  let viewYear = initParsed.year;
  let viewMonth = initParsed.month;
  let pickingSecond = false;

  const syncCommitted = (nextFrom, nextTo) => {
    fromInput.value = nextFrom || '';
    toInput.value = nextTo || '';
    draftFrom = nextFrom || '';
    draftTo = nextTo || '';
    if (summaryEl) {
      summaryEl.textContent = formatRangeSummary(draftFrom, draftTo);
      summaryEl.classList?.toggle('is-placeholder', !draftFrom && !draftTo);
    }
    if (typeof onChange === 'function') {
      onChange({ from: draftFrom, to: draftTo });
    }
  };

  const renderPanel = () => {
    const firstDayJs = new Date(Date.UTC(viewYear, viewMonth - 1, 1)).getUTCDay();
    const offset = (firstDayJs + 6) % 7;
    const daysInMonth = new Date(Date.UTC(viewYear, viewMonth, 0)).getUTCDate();

    const cells = [];
    for (let i = 0; i < offset; i += 1) {
      cells.push('<span class="meta-cal-empty"></span>');
    }
    for (let d = 1; d <= daysInMonth; d += 1) {
      const iso = toIso(viewYear, viewMonth, d);
      const isStart = iso === draftFrom;
      const isEnd = iso === draftTo;
      const inRange = Boolean(draftFrom && draftTo && iso > draftFrom && iso < draftTo);
      const isToday = iso === todayIso;
      const cls = [
        'meta-cal-day',
        'tabular',
        isStart || isEnd ? 'is-selected' : '',
        inRange ? 'is-in-range' : '',
        isToday ? 'is-today' : '',
      ].filter(Boolean).join(' ');
      cells.push(`<button type="button" class="${cls}" data-drp-day="${iso}">${d}</button>`);
    }

    const presetsHtml = [
      ...DATE_PRESETS,
      { id: 'custom', label: 'Tùy chọn' },
    ].map((p) => `<button type="button" class="meta-drp-preset${activePreset === p.id ? ' active' : ''}" data-drp-preset="${p.id}">${esc(p.label)}</button>`).join('');

    panel.innerHTML = `
      <div class="meta-drp-card" role="dialog" aria-modal="true" aria-label="Chọn khoảng thời gian">
        <div class="meta-drp-body">
          <div class="meta-drp-presets">${presetsHtml}</div>
          <div class="meta-drp-cal">
            <div class="meta-cal-head">
              <button type="button" class="btn btn-ghost btn-icon meta-cal-nav" data-drp-nav="-1" aria-label="Tháng trước">${icon('chevronLeft', 16)}</button>
              <span class="meta-cal-title tabular">Tháng ${String(viewMonth).padStart(2, '0')}/${viewYear}</span>
              <button type="button" class="btn btn-ghost btn-icon meta-cal-nav" data-drp-nav="1" aria-label="Tháng sau">${icon('chevronRight', 16)}</button>
            </div>
            <div class="meta-cal-weekdays">${WEEKDAYS.map((w) => `<span>${w}</span>`).join('')}</div>
            <div class="meta-cal-grid">${cells.join('')}</div>
          </div>
        </div>
        <div class="meta-drp-inputs">
          <span class="meta-drp-pill tabular">${icon('calendar', 14)} ${esc(draftFrom ? formatDateVN(draftFrom) : 'Từ ngày')}</span>
          <span style="color:var(--meta-text-secondary);font-size:12.5px">đến</span>
          <span class="meta-drp-pill tabular">${icon('calendar', 14)} ${esc(draftTo ? formatDateVN(draftTo) : 'Đến ngày')}</span>
        </div>
        <div class="meta-drp-foot">
          <button type="button" class="btn btn-ghost btn-sm" data-drp-reset>Đặt lại</button>
          <button type="button" class="btn btn-primary btn-sm" data-drp-apply>Áp dụng</button>
        </div>
      </div>
    `;

    panel.onclick = (e) => {
      if (e.target === panel) {
        panel.hidden = true;
        trigger.setAttribute('aria-expanded', 'false');
        rootEl.classList?.remove('is-open');
      }
    };

    panel.querySelectorAll('[data-drp-preset]').forEach((btn) => {
      btn.onclick = (e) => {
        e.stopPropagation();
        const key = btn.dataset.drpPreset;
        activePreset = key;
        if (key !== 'custom') {
          const range = computeDatePreset(key);
          draftFrom = range.from;
          draftTo = range.to;
          pickingSecond = false;
          const p = parseIso(draftFrom);
          if (p) {
            viewYear = p.year;
            viewMonth = p.month;
          }
        }
        renderPanel();
      };
    });

    panel.querySelectorAll('[data-drp-nav]').forEach((btn) => {
      btn.onclick = (e) => {
        e.stopPropagation();
        viewMonth += Number(btn.dataset.drpNav);
        if (viewMonth < 1) {
          viewMonth = 12;
          viewYear -= 1;
        } else if (viewMonth > 12) {
          viewMonth = 1;
          viewYear += 1;
        }
        renderPanel();
      };
    });

    panel.querySelectorAll('[data-drp-day]').forEach((btn) => {
      btn.onclick = (e) => {
        e.stopPropagation();
        const picked = btn.dataset.drpDay;
        activePreset = 'custom';
        if (!pickingSecond || !draftFrom || picked < draftFrom) {
          draftFrom = picked;
          draftTo = '';
          pickingSecond = true;
        } else {
          draftTo = picked;
          pickingSecond = false;
        }
        renderPanel();
      };
    });

    const resetBtn = panel.querySelector('[data-drp-reset]');
    if (resetBtn) {
      resetBtn.onclick = (e) => {
        e.stopPropagation();
        activePreset = 'custom';
        pickingSecond = false;
        syncCommitted('', '');
        panel.hidden = true;
        trigger.setAttribute('aria-expanded', 'false');
        rootEl.classList?.remove('is-open');
      };
    }

    const applyBtn = panel.querySelector('[data-drp-apply]');
    if (applyBtn) {
      applyBtn.onclick = (e) => {
        e.stopPropagation();
        syncCommitted(draftFrom, draftTo || draftFrom);
        panel.hidden = true;
        trigger.setAttribute('aria-expanded', 'false');
        rootEl.classList?.remove('is-open');
      };
    }
  };

  trigger.onclick = (e) => {
    e.stopPropagation();
    const willOpen = panel.hidden;
    if (willOpen) {
      draftFrom = fromInput.value || '';
      draftTo = toInput.value || '';
      const parsed = parseIso(draftFrom) || parseIso(todayIso);
      viewYear = parsed.year;
      viewMonth = parsed.month;
      renderPanel();
      panel.hidden = false;
      trigger.setAttribute('aria-expanded', 'true');
      rootEl.classList?.add('is-open');
    } else {
      panel.hidden = true;
      trigger.setAttribute('aria-expanded', 'false');
      rootEl.classList?.remove('is-open');
    }
  };
}
