import { esc } from './format.js';
import { icon } from './icons.js';

let activeCleanup = null;
let modalBusy = false;
let keyHandlerBound = false;

function ensureOverlay() {
  let overlay = document.getElementById?.('meta-modal-overlay')
    || document.querySelector?.('#meta-modal-overlay');
  let dialog = document.getElementById?.('meta-modal-dialog')
    || document.querySelector?.('#meta-modal-dialog');

  if (!overlay && document.body && document.createElement) {
    overlay = document.createElement('div');
    overlay.id = 'meta-modal-overlay';
    overlay.className = 'meta-overlay';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-labelledby', 'meta-modal-title');
    overlay.hidden = true;
    dialog = document.createElement('div');
    dialog.id = 'meta-modal-dialog';
    dialog.className = 'meta-modal-dialog';
    overlay.appendChild(dialog);
    document.body.appendChild(overlay);
  }
  return { overlay, dialog };
}

function bindGlobalEsc() {
  if (keyHandlerBound || !document.addEventListener) return;
  keyHandlerBound = true;
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !modalBusy) {
      closeModal();
    }
  });
}

export function closeModal() {
  const { overlay, dialog } = ensureOverlay();
  if (overlay) {
    overlay.classList?.remove('open');
    overlay.hidden = true;
  }
  if (dialog) dialog.innerHTML = '';
  modalBusy = false;
  if (typeof activeCleanup === 'function') {
    const fn = activeCleanup;
    activeCleanup = null;
    fn();
  }
}

/**
 * Opens an accessible Dark Graphite custom modal.
 * Preserves form values on error when onSubmit returns false or throws.
 */
export function openModal({
  title = '',
  subtitle = '',
  bodyHtml = '',
  footerHtml = '',
  onMount = null,
  onClose = null,
  maxWidth = null,
} = {}) {
  bindGlobalEsc();
  const { overlay, dialog } = ensureOverlay();
  if (!overlay || !dialog) return null;

  modalBusy = false;
  activeCleanup = onClose || null;

  if (maxWidth && dialog.style) {
    dialog.style.maxWidth = maxWidth;
  } else if (dialog.style) {
    dialog.style.maxWidth = '';
  }

  dialog.innerHTML = `
    <div class="meta-modal-header">
      <div>
        <h2 class="meta-modal-title" id="meta-modal-title">${esc(title)}</h2>
        ${subtitle ? `<p class="meta-modal-sub">${esc(subtitle)}</p>` : ''}
      </div>
      <button type="button" class="btn btn-ghost btn-icon" data-close-modal aria-label="Đóng hộp thoại">${icon('close', 18)}</button>
    </div>
    <div id="meta-modal-inline-error" aria-live="assertive"></div>
    ${bodyHtml}
    ${footerHtml ? `<div class="meta-modal-footer">${footerHtml}</div>` : ''}
  `;

  overlay.hidden = false;
  overlay.classList?.add('open');

  overlay.onclick = (event) => {
    if (event.target === overlay && !modalBusy) closeModal();
  };

  dialog.querySelectorAll?.('[data-close-modal]').forEach((btn) => {
    btn.onclick = () => {
      if (!modalBusy) closeModal();
    };
  });

  const controller = {
    overlay,
    dialog,
    close: closeModal,
    setBusy(isBusy) {
      modalBusy = Boolean(isBusy);
      dialog.querySelectorAll?.('button[type="submit"], [data-modal-submit]').forEach((btn) => {
        btn.disabled = modalBusy;
      });
    },
    showError(message) {
      const box = dialog.querySelector?.('#meta-modal-inline-error');
      if (!box) return;
      if (!message) {
        box.innerHTML = '';
        return;
      }
      box.innerHTML = `<div class="meta-banner banner-danger" style="margin:14px 20px 0;border-radius:var(--meta-radius-sm)" role="alert">
        <div class="banner-body">
          <span class="banner-icon">${icon('alert', 18)}</span>
          <div><p class="banner-title mb-0">${esc(message)}</p></div>
        </div>
      </div>`;
    },
  };

  if (typeof onMount === 'function') {
    onMount(controller);
  }

  const firstInput = dialog.querySelector?.('input:not([type="hidden"]), select, textarea, button:not([data-close-modal])');
  firstInput?.focus?.();

  return controller;
}

/**
 * Accessible custom confirmation modal replacing native browser dialogs.
 * Supports optional mandatory reason field with live char counter (1..maxLength).
 */
export function openConfirmModal({
  title,
  subtitle = '',
  bannerHtml = '',
  impactHtml = '',
  requireReason = false,
  reasonLabel = 'Lý do thực hiện (bắt buộc)',
  reasonPlaceholder = 'Nhập lý do chi tiết (1–500 ký tự)…',
  reasonMaxLength = 500,
  confirmLabel = 'Xác nhận',
  confirmVariant = 'primary', // primary | danger-solid | success
  confirmIcon = 'check',
  cancelLabel = 'Hủy',
  onConfirm,
} = {}) {
  const btnCls = confirmVariant === 'danger-solid'
    ? 'btn-danger-solid'
    : confirmVariant === 'success' ? 'btn-success' : 'btn-primary';

  const bodyHtml = `<form id="meta-confirm-form" novalidate>
    <div class="meta-modal-body">
      ${bannerHtml}
      ${impactHtml}
      ${requireReason ? `<div class="field">
        <label class="field-label" for="meta-confirm-reason">
          <span>${esc(reasonLabel)}</span>
          <span id="meta-reason-count" class="tabular">0/${reasonMaxLength}</span>
        </label>
        <textarea id="meta-confirm-reason" name="reason" class="form-control" maxlength="${reasonMaxLength}" placeholder="${esc(reasonPlaceholder)}" required></textarea>
        <span id="meta-reason-error" class="field-error" aria-live="polite"></span>
      </div>` : ''}
    </div>
    <div class="meta-modal-footer">
      <button type="button" class="btn btn-ghost" data-close-modal>${esc(cancelLabel)}</button>
      <button type="submit" class="btn ${btnCls}" id="meta-confirm-submit" data-modal-submit ${requireReason ? 'disabled' : ''}>
        ${icon(confirmIcon, 16)} ${esc(confirmLabel)}
      </button>
    </div>
  </form>`;

  return openModal({
    title,
    subtitle,
    bodyHtml,
    onMount(ctrl) {
      const form = ctrl.dialog.querySelector('#meta-confirm-form');
      const textarea = ctrl.dialog.querySelector('#meta-confirm-reason');
      const countEl = ctrl.dialog.querySelector('#meta-reason-count');
      const errEl = ctrl.dialog.querySelector('#meta-reason-error');
      const submitBtn = ctrl.dialog.querySelector('#meta-confirm-submit');

      const syncReason = () => {
        if (!textarea || !submitBtn) return true;
        const raw = textarea.value || '';
        const trimmed = raw.trim();
        if (countEl) countEl.textContent = `${raw.length}/${reasonMaxLength}`;
        const valid = trimmed.length >= 1 && trimmed.length <= reasonMaxLength && raw.length <= reasonMaxLength;
        submitBtn.disabled = !valid;
        if (errEl) {
          if (raw.length > reasonMaxLength) {
            errEl.textContent = `Lý do không được vượt quá ${reasonMaxLength} ký tự.`;
          } else {
            errEl.textContent = '';
          }
        }
        return valid;
      };

      if (textarea) {
        textarea.addEventListener?.('input', syncReason);
        textarea.oninput = syncReason;
        syncReason();
      }

      if (form) {
        form.onsubmit = async (event) => {
          event.preventDefault();
          ctrl.showError('');
          const reason = textarea ? (textarea.value || '').trim() : '';
          if (requireReason && (!reason || reason.length > reasonMaxLength)) {
            if (errEl) errEl.textContent = `Lý do phải có từ 1 đến ${reasonMaxLength} ký tự.`;
            return;
          }
          ctrl.setBusy(true);
          try {
            const shouldClose = await onConfirm?.({ reason, controller: ctrl });
            if (shouldClose !== false) ctrl.close();
            else ctrl.setBusy(false);
          } catch (error) {
            ctrl.setBusy(false);
            ctrl.showError(error?.message || 'Thao tác không thành công. Vui lòng thử lại.');
            if (textarea) syncReason();
          }
        };
      }
    },
  });
}
