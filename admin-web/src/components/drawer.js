import { esc } from './format.js';
import { icon } from './icons.js';

let keyBound = false;

function ensureDrawer() {
  let overlay = document.getElementById?.('meta-drawer-overlay')
    || document.querySelector?.('#meta-drawer-overlay');
  let panel = document.getElementById?.('meta-drawer-panel')
    || document.querySelector?.('#meta-drawer-panel');

  if (!overlay && document.body && document.createElement) {
    overlay = document.createElement('div');
    overlay.id = 'meta-drawer-overlay';
    overlay.className = 'meta-drawer-overlay';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-labelledby', 'meta-drawer-title');
    overlay.hidden = true;
    panel = document.createElement('div');
    panel.id = 'meta-drawer-panel';
    panel.className = 'meta-drawer-panel';
    overlay.appendChild(panel);
    document.body.appendChild(overlay);
  }
  return { overlay, panel };
}

function bindEsc() {
  if (keyBound || !document.addEventListener) return;
  keyBound = true;
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') closeDrawer();
  });
}

export function closeDrawer() {
  const { overlay, panel } = ensureDrawer();
  if (overlay) {
    overlay.classList?.remove('open');
    overlay.hidden = true;
  }
  if (panel) panel.innerHTML = '';
  document.documentElement?.classList?.remove?.('meta-scroll-locked');
  document.body?.classList?.remove?.('meta-scroll-locked');
}

export function openDrawer({
  title = '',
  subtitle = '',
  bodyHtml = '',
  footerHtml = '',
  onMount = null,
} = {}) {
  bindEsc();
  const { overlay, panel } = ensureDrawer();
  if (!overlay || !panel) return null;

  panel.innerHTML = `
    <div class="meta-modal-header">
      <div>
        <h2 class="meta-modal-title" id="meta-drawer-title">${esc(title)}</h2>
        ${subtitle ? `<p class="meta-modal-sub">${esc(subtitle)}</p>` : ''}
      </div>
      <button type="button" class="btn btn-ghost btn-icon" data-close-drawer aria-label="Đóng chi tiết">${icon('close', 18)}</button>
    </div>
    <div class="meta-modal-body">${bodyHtml}</div>
    <div class="meta-modal-footer">
      ${footerHtml || '<button type="button" class="btn btn-ghost" data-close-drawer>Đóng</button>'}
    </div>
  `;

  overlay.hidden = false;
  overlay.classList?.add('open');
  document.documentElement?.classList?.add?.('meta-scroll-locked');
  document.body?.classList?.add?.('meta-scroll-locked');
  overlay.onclick = (event) => {
    if (event.target === overlay) closeDrawer();
  };
  panel.querySelectorAll?.('[data-close-drawer]').forEach((btn) => {
    btn.onclick = closeDrawer;
  });

  const controller = {
    overlay,
    panel,
    close: closeDrawer,
    setBody(html) {
      const body = panel.querySelector?.('.meta-modal-body');
      if (body) body.innerHTML = html;
    },
  };

  if (typeof onMount === 'function') onMount(controller);
  return controller;
}
