import { esc } from './format.js';

export function renderSelectDropdown({
  id = '',
  name = '',
  options = [],
  value = '',
  placeholder = 'Chọn mục',
  ariaLabel = 'Chọn một mục',
} = {}) {
  const current = String(value ?? '');
  const activeOpt = options.find((o) => String(o.value) === current) || options[0];
  const displayLabel = activeOpt ? activeOpt.label : placeholder;

  return `<div class="meta-select" data-select-dropdown="${esc(id)}">
    <input type="hidden" id="${esc(id)}"${name ? ` name="${esc(name)}"` : ''} value="${esc(activeOpt ? activeOpt.value : current)}" />
    <button type="button" class="form-control meta-select-trigger" id="${esc(id)}-trigger" aria-label="${esc(ariaLabel)}" aria-haspopup="listbox" aria-expanded="false">
      <span class="meta-select-label">${esc(displayLabel)}</span>
      <svg class="meta-select-chevron" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="6 9 12 15 18 9"/></svg>
    </button>
    <div class="meta-select-popover" id="${esc(id)}-popover" role="listbox" hidden>
      ${options.map((opt) => {
        const val = String(opt.value);
        const selected = val === String(activeOpt ? activeOpt.value : current);
        return `<button type="button" class="meta-select-opt ${selected ? 'active' : ''}" role="option" aria-selected="${selected}" data-select-opt="${esc(val)}" data-label="${esc(opt.label)}">${esc(opt.label)}</button>`;
      }).join('')}
    </div>
  </div>`;
}

export function bindSelectDropdowns(container, { onChange } = {}) {
  if (!container) return;
  const wraps = Array.from(container.querySelectorAll?.('[data-select-dropdown]') || []);
  if (!wraps.length) return;

  const closeAll = (except = null) => {
    wraps.forEach((wrap) => {
      if (wrap === except) return;
      const pop = wrap.querySelector?.('.meta-select-popover');
      const trig = wrap.querySelector?.('.meta-select-trigger');
      if (pop) pop.hidden = true;
      trig?.setAttribute?.('aria-expanded', 'false');
      wrap.classList?.remove('is-open');
    });
  };

  wraps.forEach((wrap) => {
    const id = wrap.getAttribute('data-select-dropdown') || '';
    const hiddenInput = wrap.querySelector?.('input[type="hidden"]');
    const trigger = wrap.querySelector?.('.meta-select-trigger');
    const labelEl = wrap.querySelector?.('.meta-select-label');
    const popover = wrap.querySelector?.('.meta-select-popover');
    const optBtns = Array.from(wrap.querySelectorAll?.('[data-select-opt]') || []);
    if (!trigger || !popover) return;

    trigger.onclick = (event) => {
      event?.stopPropagation?.();
      const willOpen = Boolean(popover.hidden);
      closeAll(willOpen ? wrap : null);
      popover.hidden = !willOpen;
      trigger.setAttribute?.('aria-expanded', String(willOpen));
      wrap.classList?.toggle('is-open', willOpen);
    };

    optBtns.forEach((btn) => {
      btn.onclick = (event) => {
        event?.stopPropagation?.();
        const val = btn.getAttribute('data-select-opt') ?? '';
        const lbl = btn.getAttribute('data-label') || btn.textContent || val;
        if (hiddenInput) hiddenInput.value = val;
        if (labelEl) labelEl.textContent = lbl;
        optBtns.forEach((o) => {
          const isSel = o === btn;
          o.classList?.toggle('active', isSel);
          o.setAttribute?.('aria-selected', String(isSel));
        });
        closeAll();
        if (typeof onChange === 'function') {
          onChange({ id, value: val, label: lbl });
        }
      };
    });
  });

  if (globalThis.document?.addEventListener) {
    if (globalThis.__metaSelectDropDocHandler) {
      globalThis.document.removeEventListener('click', globalThis.__metaSelectDropDocHandler);
    }
    globalThis.__metaSelectDropDocHandler = (event) => {
      if (!event.target?.closest?.('[data-select-dropdown]')) {
        closeAll();
      }
    };
    globalThis.document.addEventListener('click', globalThis.__metaSelectDropDocHandler);
  }
}
