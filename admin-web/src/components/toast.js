import { esc } from './format.js';
import { icon } from './icons.js';

function ensureRegion() {
  let region = document.getElementById?.('meta-toast-region')
    || document.querySelector?.('#meta-toast-region');
  if (!region && document.body && document.createElement) {
    region = document.createElement('div');
    region.id = 'meta-toast-region';
    region.className = 'meta-toast-region';
    region.setAttribute('aria-live', 'polite');
    region.setAttribute('aria-atomic', 'true');
    document.body.appendChild(region);
  }
  return region;
}

const activeToasts = new Map();

export function toast(message, kind = 'success', { duration = 3500 } = {}) {
  const region = ensureRegion();
  if (!region || !document.createElement) return null;
  const tone = kind === 'warning' ? 'warn' : kind;
  const key = `${tone}::${message}`;

  const existing = activeToasts.get(key);
  if (existing && existing.el && existing.el.parentElement) {
    existing.count += 1;
    if (existing.timer) clearTimeout(existing.timer);
    if (existing.removeTimer) clearTimeout(existing.removeTimer);
    existing.el.classList?.remove('leaving');
    const countEl = existing.el.querySelector?.('.toast-repeat-count');
    if (countEl) countEl.textContent = `×${existing.count}`;
    if (duration > 0 && typeof setTimeout === 'function') {
      existing.timer = setTimeout(() => dismissToast(key, existing.el), duration);
    }
    return existing.el;
  }

  const el = document.createElement('div');
  el.className = `meta-toast ${tone === 'warn' || tone === 'danger' || tone === 'info' ? tone : ''}`.trim();
  el.setAttribute('role', tone === 'danger' ? 'alert' : 'status');
  el.innerHTML = `<span class="toast-msg">${esc(message)} <span class="toast-repeat-count tabular" aria-hidden="true"></span></span><button type="button" class="btn btn-ghost btn-icon" aria-label="Đóng thông báo">${icon('close', 16)}</button>`;

  const entry = { el, count: 1, timer: null, removeTimer: null };
  activeToasts.set(key, entry);

  const closeBtn = el.querySelector?.('button');
  if (closeBtn) closeBtn.onclick = () => dismissToast(key, el, true);
  region.appendChild(el);
  if (duration > 0 && typeof setTimeout === 'function') {
    entry.timer = setTimeout(() => dismissToast(key, el), duration);
  }
  return el;
}

function dismissToast(key, el, immediate = false) {
  const entry = activeToasts.get(key);
  if (entry?.timer) clearTimeout(entry.timer);
  activeToasts.delete(key);
  if (immediate || !el?.classList) {
    el?.remove?.();
    return;
  }
  el.classList.add('leaving');
  setTimeout(() => el.remove?.(), 180);
}

export function notice(text, kind = 'success') {
  toast(text, kind);
  const box = document.querySelector?.('#notice');
  if (box) {
    const cls = kind === 'danger' ? 'banner-danger'
      : kind === 'warn' || kind === 'warning' ? 'banner-warn'
        : kind === 'info' ? 'banner-info' : 'banner-success';
    const iconName = kind === 'danger' || kind === 'warn' || kind === 'warning' ? 'alert'
      : kind === 'info' ? 'info' : 'check';
    box.innerHTML = `<div class="meta-banner ${cls} mb-3" role="${kind === 'danger' ? 'alert' : 'status'}">
      <div class="banner-body">
        <span class="banner-icon">${icon(iconName, 18)}</span>
        <div><p class="banner-title mb-0">${esc(text)}</p></div>
      </div>
    </div>`;
  }
}
