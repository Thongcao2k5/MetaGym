import { esc } from './format.js';

function summarizeSelection(options, selectedSet, allLabel, placeholder) {
  if (!options.length || selectedSet.size === options.length) return allLabel;
  if (selectedSet.size === 0) return placeholder;
  if (selectedSet.size === 1) {
    const onlyVal = Array.from(selectedSet)[0];
    return options.find((o) => String(o.value) === String(onlyVal))?.label || onlyVal;
  }
  return `Đã chọn ${selectedSet.size}/${options.length}`;
}

export function renderMultiSelect({
  id = '',
  allLabel = 'Tất cả',
  placeholder = 'Chọn mục',
  options = [],
  selected = null,
  ariaLabel = 'Chọn nhiều mục',
} = {}) {
  const allValues = options.map((o) => String(o.value));
  const selectedSet = new Set(
    Array.isArray(selected) ? selected.map((v) => String(v)) : allValues,
  );
  const allChecked = options.length > 0 && selectedSet.size === options.length;
  const summary = summarizeSelection(options, selectedSet, allLabel, placeholder);

  return `<div class="meta-multiselect" data-multiselect="${esc(id)}" data-all-label="${esc(allLabel)}" data-placeholder="${esc(placeholder)}">
    <button type="button" class="form-control meta-multiselect-trigger" id="${esc(id)}-trigger" aria-label="${esc(ariaLabel)}" aria-haspopup="listbox" aria-expanded="false">
      <span class="meta-multiselect-summary">${esc(summary)}</span>
      <svg class="meta-multiselect-chevron" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="6 9 12 15 18 9"/></svg>
    </button>
    <div class="meta-multiselect-popover" id="${esc(id)}-popover" role="listbox" aria-multiselectable="true" hidden>
      <label class="meta-multiselect-opt is-all">
        <span>${esc(allLabel)}</span>
        <input type="checkbox" class="meta-multiselect-check" data-ms-all ${allChecked ? 'checked' : ''} />
      </label>
      ${options.map((opt) => {
        const val = String(opt.value);
        const checked = selectedSet.has(val);
        return `<label class="meta-multiselect-opt">
          <span>${esc(opt.label)}</span>
          <input type="checkbox" class="meta-multiselect-check" data-ms-item value="${esc(val)}" data-label="${esc(opt.label)}" ${checked ? 'checked' : ''} />
        </label>`;
      }).join('')}
    </div>
  </div>`;
}

export function bindMultiSelects(container, { onChange } = {}) {
  if (!container) return;
  const wraps = Array.from(container.querySelectorAll?.('[data-multiselect]') || []);
  if (!wraps.length) return;

  const closeAll = (except = null) => {
    wraps.forEach((wrap) => {
      if (wrap === except) return;
      const pop = wrap.querySelector?.('.meta-multiselect-popover');
      const trig = wrap.querySelector?.('.meta-multiselect-trigger');
      if (pop) pop.hidden = true;
      trig?.setAttribute?.('aria-expanded', 'false');
      wrap.classList?.remove('is-open');
    });
  };

  wraps.forEach((wrap) => {
    const id = wrap.getAttribute('data-multiselect') || '';
    const allLabel = wrap.getAttribute('data-all-label') || 'Tất cả';
    const placeholder = wrap.getAttribute('data-placeholder') || 'Chọn mục';
    const trigger = wrap.querySelector?.('.meta-multiselect-trigger');
    const summaryEl = wrap.querySelector?.('.meta-multiselect-summary');
    const popover = wrap.querySelector?.('.meta-multiselect-popover');
    const allCb = wrap.querySelector?.('[data-ms-all]');
    const itemCbs = Array.from(wrap.querySelectorAll?.('[data-ms-item]') || []);
    if (!trigger || !popover) return;

    const options = itemCbs.map((cb) => ({
      value: cb.value,
      label: cb.getAttribute('data-label') || cb.value,
    }));

    const sync = (emit = false) => {
      const checkedVals = itemCbs.filter((cb) => cb.checked).map((cb) => cb.value);
      const selectedSet = new Set(checkedVals);
      if (allCb) {
        allCb.checked = itemCbs.length > 0 && checkedVals.length === itemCbs.length;
        allCb.indeterminate = checkedVals.length > 0 && checkedVals.length < itemCbs.length;
      }
      if (summaryEl) {
        summaryEl.textContent = summarizeSelection(options, selectedSet, allLabel, placeholder);
      }
      if (emit && typeof onChange === 'function') {
        onChange({ id, values: checkedVals, isAll: checkedVals.length === itemCbs.length });
      }
    };

    sync(false);

    trigger.onclick = (event) => {
      event?.stopPropagation?.();
      const willOpen = Boolean(popover.hidden);
      closeAll(willOpen ? wrap : null);
      popover.hidden = !willOpen;
      trigger.setAttribute?.('aria-expanded', String(willOpen));
      wrap.classList?.toggle('is-open', willOpen);
    };

    if (allCb) {
      allCb.onchange = () => {
        const next = Boolean(allCb.checked);
        itemCbs.forEach((cb) => { cb.checked = next; });
        sync(true);
      };
    }

    itemCbs.forEach((cb) => {
      cb.onchange = () => sync(true);
    });
  });

  if (globalThis.document?.addEventListener) {
    if (globalThis.__metaMultiSelectDocHandler) {
      globalThis.document.removeEventListener('click', globalThis.__metaMultiSelectDocHandler);
    }
    globalThis.__metaMultiSelectDocHandler = (event) => {
      if (!event.target?.closest?.('[data-multiselect]')) {
        closeAll();
      }
    };
    globalThis.document.addEventListener('click', globalThis.__metaMultiSelectDocHandler);
  }
}
