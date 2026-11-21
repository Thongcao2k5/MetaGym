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

export function toast(message, kind = 'success', { duration = 4500 } = {}) {
  const region = ensureRegion();
  if (!region || !document.createElement) return null;
  const el = document.createElement('div');
  const tone = kind === 'warning' ? 'warn' : kind;
  el.className = `meta-toast ${tone === 'warn' || tone === 'danger' || tone === 'info' ? tone : ''}`.trim();
  el.setAttribute('role', tone === 'danger' ? 'alert' : 'status');
  el.innerHTML = `<span>${esc(message)}</span><button type="button" class="btn btn-ghost btn-icon" aria-label="Đóng thông báo">${icon('close', 16)}</button>`;
  const closeBtn = el.querySelector?.('button');
  if (closeBtn) closeBtn.onclick = () => el.remove?.();
  region.appendChild(el);
  if (duration > 0 && typeof setTimeout === 'function') {
    setTimeout(() => el.remove?.(), duration);
  }
  return el;
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
