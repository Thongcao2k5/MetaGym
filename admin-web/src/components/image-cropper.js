import { esc } from './format.js';
import { icon } from './icons.js';

let activeCropperCleanup = null;

function ensureCropperOverlay() {
  let overlay = document.getElementById?.('meta-cropper-overlay')
    || document.querySelector?.('#meta-cropper-overlay');
  let dialog = document.getElementById?.('meta-cropper-dialog')
    || document.querySelector?.('#meta-cropper-dialog');

  if (!overlay && document.body && document.createElement) {
    overlay = document.createElement('div');
    overlay.id = 'meta-cropper-overlay';
    overlay.className = 'meta-overlay meta-cropper-overlay';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-labelledby', 'meta-cropper-title');
    overlay.hidden = true;

    dialog = document.createElement('div');
    dialog.id = 'meta-cropper-dialog';
    dialog.className = 'meta-modal-dialog meta-cropper-dialog';
    overlay.appendChild(dialog);
    document.body.appendChild(overlay);
  }
  return { overlay, dialog };
}

export function closeImageCropper() {
  const { overlay, dialog } = ensureCropperOverlay();
  if (overlay) {
    overlay.classList?.remove('open');
    overlay.hidden = true;
  }
  if (dialog) dialog.innerHTML = '';
  if (typeof activeCropperCleanup === 'function') {
    const fn = activeCropperCleanup;
    activeCropperCleanup = null;
    fn();
  }
}

/**
 * Mở hộp thoại Cắt & Căn chỉnh ảnh đại diện (Canvas 1:1 circular/square cropper).
 * @param {Object} options
 * @param {File|Blob|string} options.file - Tệp ảnh hoặc data URL cần cắt
 * @param {number} [options.outputSize=512] - Kích thước vuông xuất ra (pixels)
 * @param {boolean} [options.circular=true] - Khung tròn (Avatar) hay vuông
 * @param {Function} options.onApply - Callback khi bấm Áp dụng ({ blob, dataUrl, file })
 * @param {Function} [options.onCancel] - Callback khi bấm Hủy
 */
export function openImageCropper({
  file,
  outputSize = 512,
  circular = true,
  onApply,
  onCancel,
}) {
  const { overlay, dialog } = ensureCropperOverlay();
  if (!overlay || !dialog) return null;

  activeCropperCleanup = onCancel || null;

  dialog.innerHTML = `
    <div class="meta-modal-header">
      <div>
        <h2 class="meta-modal-title" id="meta-cropper-title">Cắt ảnh đại diện</h2>
        <p class="meta-modal-sub">Kéo và phóng to để căn chỉnh khuôn mặt vào giữa khung tròn</p>
      </div>
      <button type="button" class="btn btn-ghost btn-icon" data-cropper-close aria-label="Đóng">${icon('close', 18)}</button>
    </div>
    <div class="meta-modal-body meta-cropper-body">
      <div class="cropper-viewport-wrap">
        <canvas id="meta-cropper-canvas" width="340" height="340" class="cropper-canvas"></canvas>
      </div>
      <div class="cropper-controls">
        <div class="cropper-zoom-row">
          <button type="button" class="btn btn-ghost btn-icon btn-sm" id="btn-zoom-out" title="Thu nhỏ">${icon('minus', 16) || '—'}</button>
          <input type="range" id="cropper-zoom-range" min="1" max="3" step="0.05" value="1" class="form-range cropper-slider" />
          <button type="button" class="btn btn-ghost btn-icon btn-sm" id="btn-zoom-in" title="Phóng to">${icon('plus', 16) || '+'}</button>
        </div>
        <div class="cropper-actions-row">
          <button type="button" class="btn btn-graphite btn-sm" id="btn-rotate-cw">
            ${icon('rotateCw') || icon('arrowPath') || '↺'} <span>Xoay 90°</span>
          </button>
          <button type="button" class="btn btn-ghost btn-sm" id="btn-reset-crop">
            <span>Đặt lại</span>
          </button>
        </div>
      </div>
    </div>
    <div class="meta-modal-footer">
      <button type="button" class="btn btn-ghost" data-cropper-cancel>Hủy</button>
      <button type="button" class="btn btn-primary" data-cropper-apply>
        ${icon('check')} <span>Cắt ảnh & Áp dụng</span>
      </button>
    </div>
  `;

  overlay.hidden = false;
  overlay.classList?.add('open');

  const canvas = dialog.querySelector('#meta-cropper-canvas');
  const zoomSlider = dialog.querySelector('#cropper-zoom-range');
  const zoomInBtn = dialog.querySelector('#btn-zoom-in');
  const zoomOutBtn = dialog.querySelector('#btn-zoom-out');
  const rotateBtn = dialog.querySelector('#btn-rotate-cw');
  const resetBtn = dialog.querySelector('#btn-reset-crop');
  const applyBtn = dialog.querySelector('[data-cropper-apply]');
  const cancelBtn = dialog.querySelector('[data-cropper-cancel]');
  const closeBtn = dialog.querySelector('[data-cropper-close]');

  let image = null;
  let scale = 1;
  let baseScale = 1;
  let rotation = 0;
  let panX = 0;
  let panY = 0;
  let isDragging = false;
  let dragStartX = 0;
  let dragStartY = 0;
  let dragStartPanX = 0;
  let dragStartPanY = 0;

  const viewWidth = 340;
  const viewHeight = 340;
  const cropRadius = 140; // 280px diameter circle

  const drawCropper = () => {
    if (!canvas || typeof canvas.getContext !== 'function') return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    ctx.clearRect(0, 0, viewWidth, viewHeight);

    // Draw Image
    if (image && image.width && image.height) {
      ctx.save();
      ctx.translate(viewWidth / 2 + panX, viewHeight / 2 + panY);
      ctx.rotate((rotation * Math.PI) / 180);
      const curScale = baseScale * scale;
      ctx.scale(curScale, curScale);
      ctx.drawImage(image, -image.width / 2, -image.height / 2);
      ctx.restore();
    }

    // Draw Overlay Scrim with Cutout Hole
    ctx.save();
    ctx.fillStyle = 'rgba(10, 13, 18, 0.72)';
    ctx.beginPath();
    ctx.rect(0, 0, viewWidth, viewHeight);

    if (circular) {
      ctx.arc(viewWidth / 2, viewHeight / 2, cropRadius, 0, Math.PI * 2, true);
    } else {
      const cropSize = cropRadius * 2;
      ctx.rect(viewWidth / 2 + cropRadius, viewHeight / 2 - cropRadius, -cropSize, cropSize);
    }
    ctx.closePath();
    ctx.fill();

    // Draw Crop Ring & Grid
    ctx.beginPath();
    if (circular) {
      ctx.arc(viewWidth / 2, viewHeight / 2, cropRadius, 0, Math.PI * 2);
    } else {
      ctx.strokeRect(viewWidth / 2 - cropRadius, viewHeight / 2 - cropRadius, cropRadius * 2, cropRadius * 2);
    }
    ctx.strokeStyle = '#FF5E36';
    ctx.lineWidth = 2;
    ctx.stroke();

    // Rule of thirds subtle grid lines inside circle
    ctx.beginPath();
    const third = (cropRadius * 2) / 3;
    const left = viewWidth / 2 - cropRadius;
    const top = viewHeight / 2 - cropRadius;

    ctx.strokeStyle = 'rgba(255, 255, 255, 0.2)';
    ctx.lineWidth = 1;
    ctx.setLineDash([4, 4]);

    ctx.moveTo(left + third, top + 20);
    ctx.lineTo(left + third, top + cropRadius * 2 - 20);
    ctx.moveTo(left + third * 2, top + 20);
    ctx.lineTo(left + third * 2, top + cropRadius * 2 - 20);

    ctx.moveTo(left + 20, top + third);
    ctx.lineTo(left + cropRadius * 2 - 20, top + third);
    ctx.moveTo(left + 20, top + third * 2);
    ctx.lineTo(left + cropRadius * 2 - 20, top + third * 2);

    ctx.stroke();
    ctx.restore();
  };

  const initImage = (img) => {
    image = img;
    const cropDiameter = cropRadius * 2;
    // Initial scale covers the entire crop hole
    baseScale = Math.max(cropDiameter / img.width, cropDiameter / img.height);
    scale = 1;
    rotation = 0;
    panX = 0;
    panY = 0;
    if (zoomSlider) zoomSlider.value = '1';
    drawCropper();
  };

  // Load File
  if (file instanceof (globalThis.Blob || Object) || file instanceof (globalThis.File || Object)) {
    if (typeof FileReader === 'function') {
      const reader = new FileReader();
      reader.onload = (e) => {
        if (typeof globalThis.Image === 'function') {
          const img = new globalThis.Image();
          img.onload = () => initImage(img);
          img.onerror = () => closeImageCropper();
          img.src = e.target.result;
        }
      };
      reader.readAsDataURL(file);
    }
  } else if (typeof file === 'string') {
    if (typeof globalThis.Image === 'function') {
      const img = new globalThis.Image();
      img.crossOrigin = 'anonymous';
      img.onload = () => initImage(img);
      img.onerror = () => closeImageCropper();
      img.src = file;
    }
  }

  // Drag Interactions
  const onPointerDown = (clientX, clientY) => {
    isDragging = true;
    dragStartX = clientX;
    dragStartY = clientY;
    dragStartPanX = panX;
    dragStartPanY = panY;
    if (canvas) canvas.style.cursor = 'grabbing';
  };

  const onPointerMove = (clientX, clientY) => {
    if (!isDragging) return;
    panX = dragStartPanX + (clientX - dragStartX);
    panY = dragStartPanY + (clientY - dragStartY);
    drawCropper();
  };

  const onPointerUp = () => {
    isDragging = false;
    if (canvas) canvas.style.cursor = 'grab';
  };

  if (canvas) {
    canvas.onmousedown = (e) => onPointerDown(e.clientX, e.clientY);
    globalThis.addEventListener?.('mousemove', (e) => onPointerMove(e.clientX, e.clientY));
    globalThis.addEventListener?.('mouseup', onPointerUp);

    canvas.ontouchstart = (e) => {
      const touch = e.touches?.[0];
      if (touch) onPointerDown(touch.clientX, touch.clientY);
    };
    canvas.ontouchmove = (e) => {
      const touch = e.touches?.[0];
      if (touch) onPointerMove(touch.clientX, touch.clientY);
    };
    canvas.ontouchend = onPointerUp;

    canvas.onwheel = (e) => {
      e.preventDefault();
      const delta = e.deltaY < 0 ? 0.08 : -0.08;
      scale = Math.min(3, Math.max(1, scale + delta));
      if (zoomSlider) zoomSlider.value = String(scale);
      drawCropper();
    };
  }

  // Zoom Controls
  if (zoomSlider) {
    zoomSlider.oninput = (e) => {
      scale = Number(e.target.value || 1);
      drawCropper();
    };
  }

  if (zoomInBtn) {
    zoomInBtn.onclick = () => {
      scale = Math.min(3, scale + 0.15);
      if (zoomSlider) zoomSlider.value = String(scale);
      drawCropper();
    };
  }

  if (zoomOutBtn) {
    zoomOutBtn.onclick = () => {
      scale = Math.max(1, scale - 0.15);
      if (zoomSlider) zoomSlider.value = String(scale);
      drawCropper();
    };
  }

  if (rotateBtn) {
    rotateBtn.onclick = () => {
      rotation = (rotation + 90) % 360;
      drawCropper();
    };
  }

  if (resetBtn) {
    resetBtn.onclick = () => {
      scale = 1;
      rotation = 0;
      panX = 0;
      panY = 0;
      if (zoomSlider) zoomSlider.value = '1';
      drawCropper();
    };
  }

  // Export Output
  const generateOutput = async () => {
    // If not in a browser with full canvas support, fallback to original file/blob
    if (!image || typeof document.createElement !== 'function' || !canvas || typeof canvas.getContext !== 'function') {
      const fallbackBlob = file instanceof Blob ? file : new Blob([String(file)], { type: 'image/jpeg' });
      return {
        blob: fallbackBlob,
        dataUrl: typeof file === 'string' ? file : '',
        file: fallbackBlob,
      };
    }

    const outCanvas = document.createElement('canvas');
    outCanvas.width = outputSize;
    outCanvas.height = outputSize;
    const outCtx = outCanvas.getContext?.('2d');
    if (!outCtx) {
      const fallbackBlob = file instanceof Blob ? file : new Blob([], { type: 'image/jpeg' });
      return { blob: fallbackBlob, dataUrl: '', file: fallbackBlob };
    }

    const cropDiameter = cropRadius * 2;
    const ratio = outputSize / cropDiameter;

    outCtx.save();
    outCtx.translate(outputSize / 2 + panX * ratio, outputSize / 2 + panY * ratio);
    outCtx.rotate((rotation * Math.PI) / 180);
    const finalScale = baseScale * scale * ratio;
    outCtx.scale(finalScale, finalScale);
    outCtx.drawImage(image, -image.width / 2, -image.height / 2);
    outCtx.restore();

    const hasWebp = Boolean(outCanvas.toDataURL?.('image/webp')?.startsWith('data:image/webp'));
    const exportMime = hasWebp ? 'image/webp' : 'image/jpeg';
    const exportExt = hasWebp ? 'webp' : 'jpg';
    const dataUrl = outCanvas.toDataURL?.(exportMime, 0.8) || '';
    const blob = await new Promise((resolve) => {
      if (typeof outCanvas.toBlob === 'function') {
        outCanvas.toBlob((b) => resolve(b), exportMime, 0.8);
      } else {
        resolve(new Blob([], { type: exportMime }));
      }
    });

    const croppedFile = new File([blob], `avatar-cropped.${exportExt}`, { type: exportMime });
    return { blob, dataUrl, file: croppedFile };
  };

  const handleApply = async () => {
    if (applyBtn) applyBtn.disabled = true;
    try {
      const result = await generateOutput();
      closeImageCropper();
      if (typeof onApply === 'function') {
        onApply(result);
      }
    } catch {
      closeImageCropper();
    }
  };

  const handleCancel = () => {
    closeImageCropper();
    if (typeof onCancel === 'function') {
      onCancel();
    }
  };

  if (applyBtn) applyBtn.onclick = handleApply;
  if (cancelBtn) cancelBtn.onclick = handleCancel;
  if (closeBtn) closeBtn.onclick = handleCancel;

  overlay.onclick = (e) => {
    if (e.target === overlay) handleCancel();
  };

  return {
    overlay,
    dialog,
    close: handleCancel,
  };
}
