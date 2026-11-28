import { esc } from './format.js';
import { icon } from './icons.js';

let activeViewerCleanup = null;

function ensureViewerOverlay() {
  let overlay = document.getElementById('meta-image-viewer-overlay');
  if (!overlay) {
    overlay = document.createElement('div');
    overlay.id = 'meta-image-viewer-overlay';
    overlay.className = 'meta-image-viewer-overlay';
    overlay.hidden = true;
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-label', 'Xem ảnh phóng to');
    document.body.appendChild(overlay);
  }
  return overlay;
}

export function closeImageViewer() {
  const overlay = document.getElementById('meta-image-viewer-overlay');
  if (overlay) {
    overlay.hidden = true;
    overlay.classList.remove('open');
    overlay.innerHTML = '';
  }
  if (typeof activeViewerCleanup === 'function') {
    activeViewerCleanup();
    activeViewerCleanup = null;
  }
}

export function openImageViewer({ src, title = 'Ảnh đại diện', alt = 'Ảnh đại diện' } = {}) {
  if (!src) return null;

  closeImageViewer();

  const overlay = ensureViewerOverlay();
  overlay.innerHTML = `
    <div class="meta-image-viewer-dialog" role="document">
      <div class="meta-image-viewer-header">
        <div class="image-viewer-title-row">
          <span class="image-viewer-icon">${icon('image', 18)}</span>
          <span class="image-viewer-title">${esc(title)}</span>
        </div>
        <button type="button" class="btn btn-icon btn-ghost" data-viewer-close aria-label="Đóng xem ảnh">
          ${icon('close', 18)}
        </button>
      </div>
      <div class="meta-image-viewer-body">
        <div class="image-viewer-stage">
          <img src="${esc(src)}" alt="${esc(alt)}" class="image-viewer-img" />
        </div>
      </div>
      <div class="meta-image-viewer-footer">
        <a href="${esc(src)}" target="_blank" rel="noopener noreferrer" class="btn btn-secondary btn-sm" download>
          ${icon('download', 14)} <span>Tải ảnh</span>
        </a>
        <button type="button" class="btn btn-primary btn-sm" data-viewer-close>
          <span>Đóng</span>
        </button>
      </div>
    </div>
  `;

  overlay.hidden = false;
  overlay.classList.add('open');

  const onKeyDown = (e) => {
    if (e.key === 'Escape') {
      e.preventDefault();
      closeImageViewer();
    }
  };

  const onOverlayClick = (e) => {
    if (e.target === overlay) {
      closeImageViewer();
    }
  };

  overlay.querySelectorAll('[data-viewer-close]').forEach((btn) => {
    btn.onclick = () => closeImageViewer();
  });

  overlay.addEventListener('click', onOverlayClick);
  if (typeof window?.addEventListener === 'function') {
    window.addEventListener('keydown', onKeyDown);
  }

  activeViewerCleanup = () => {
    overlay.removeEventListener?.('click', onOverlayClick);
    if (typeof window?.removeEventListener === 'function') {
      window.removeEventListener('keydown', onKeyDown);
    }
  };

  return {
    overlay,
    close: closeImageViewer,
  };
}
