import { api, buildQuery, getApiBaseUrl, getToken, uploadFormData } from '../services/api.js';
import { debounce, esc, formatBytes, formatDateTimeVN, statusBadge } from '../components/format.js';
import { icon } from '../components/icons.js';
import { openDrawer } from '../components/drawer.js';
import { openConfirmModal, openModal } from '../components/modal.js';
import { bindPagination, renderPagination } from '../components/pagination.js';
import {
  renderEmptyState,
  renderErrorState,
  renderFilterEmptyState,
  renderTableSkeleton,
} from '../components/states.js';
import { renderToggle } from '../components/toggle.js';
import { toast } from '../components/toast.js';
import { updateQuery } from '../state/router.js';

function resolveAssetUrl(path) {
  if (!path) return '';
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  const base = getApiBaseUrl();
  if (path.startsWith('/api/v1')) {
    return `${base}${path.slice('/api/v1'.length)}`;
  }
  return `${base}${path.startsWith('/') ? path : `/${path}`}`;
}

function absoluteShareUrl(relativeApiUrl) {
  const origin = globalThis.window?.location?.origin || '';
  return `${origin}${resolveAssetUrl(relativeApiUrl)}`;
}

async function copyText(text, label = 'URL') {
  try {
    if (globalThis.navigator?.clipboard?.writeText) {
      await globalThis.navigator.clipboard.writeText(text);
    }
    toast(`Đã sao chép ${label}.`, 'success');
  } catch {
    toast(`Không thể tự động sao chép ${label}.`, 'warning');
  }
}

function flattenFolderOptions(nodes = [], depth = 0, out = []) {
  for (const node of nodes) {
    out.push({ id: node.id, label: `${'— '.repeat(depth)}${node.name}`, imageCount: node.imageCount || 0 });
    if (Array.isArray(node.children) && node.children.length) {
      flattenFolderOptions(node.children, depth + 1, out);
    }
  }
  return out;
}

function renderFolderTreeHtml(nodes = [], activeFolderId = '') {
  if (!nodes.length) {
    return '<div class="meta-empty-inline">Chưa có thư mục nào.</div>';
  }
  return `<ul class="media-folder-tree">${nodes.map((node) => `
    <li>
      <div class="media-folder-row ${activeFolderId === node.id ? 'active' : ''}">
        <button type="button" class="media-folder-btn" data-folder-select="${esc(node.id)}">
          ${icon('folder', 15)}
          <span>${esc(node.name)}</span>
          <span class="badge-count tabular">${Number(node.imageCount ?? 0)}</span>
        </button>
        <div class="media-folder-actions">
          <button type="button" class="btn btn-ghost btn-icon btn-xs" data-folder-rename="${esc(node.id)}" data-folder-name="${esc(node.name)}" aria-label="Đổi tên thư mục" title="Đổi tên">
            ${icon('edit', 14)}
          </button>
          <button type="button" class="btn btn-ghost btn-icon btn-xs" data-folder-delete="${esc(node.id)}" data-folder-name="${esc(node.name)}" aria-label="Xóa thư mục" title="Xóa">
            ${icon('trash', 14)}
          </button>
        </div>
      </div>
      ${node.children?.length ? renderFolderTreeHtml(node.children, activeFolderId) : ''}
    </li>
  `).join('')}</ul>`;
}

function openShareCreateModal({ targetType, imageId, albumId, titleLabel }) {
  openModal({
    title: `Tạo liên kết chia sẻ — ${titleLabel}`,
    maxWidth: '500px',
    bodyHtml: `<form id="create-share-form" class="meta-form-stack">
      <div class="mb-3">
        <label class="form-label" for="share-expiry">Thời hạn hết hạn</label>
        <select id="share-expiry" class="form-select">
          <option value="24h">24 giờ</option>
          <option value="7d" selected>7 ngày</option>
          <option value="30d">30 ngày</option>
          <option value="never">Không hết hạn</option>
        </select>
      </div>
      <div class="mb-3">
        <label class="form-label" for="share-password">Mật khẩu bảo vệ (tùy chọn)</label>
        <input type="password" id="share-password" class="form-control" minlength="4" maxlength="72" placeholder="Để trống nếu không đặt mật khẩu…" />
      </div>
      <div class="mb-2">
        ${renderToggle({ id: 'share-allow-download', label: 'Cho phép tải xuống tệp gốc', checked: true })}
      </div>
      <div id="share-result-box" hidden class="media-share-result"></div>
    </form>`,
    footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Đóng</button>
      <button type="submit" form="create-share-form" class="btn btn-primary" id="share-submit-btn">${icon('share', 16)} Tạo liên kết</button>`,
    onMount: (modal) => {
      const form = modal.dialog.querySelector('#create-share-form');
      const resultBox = modal.dialog.querySelector('#share-result-box');
      const submitBtn = modal.dialog.querySelector('#share-submit-btn');

      form?.addEventListener('submit', async (event) => {
        event.preventDefault();
        const expiryChoice = modal.dialog.querySelector('#share-expiry')?.value || '7d';
        const passwordVal = modal.dialog.querySelector('#share-password')?.value?.trim() || '';
        const allowDownload = Boolean(modal.dialog.querySelector('#share-allow-download')?.checked);

        let expiresAt = null;
        const now = Date.now();
        if (expiryChoice === '24h') expiresAt = new Date(now + 24 * 3600 * 1000).toISOString();
        else if (expiryChoice === '7d') expiresAt = new Date(now + 7 * 24 * 3600 * 1000).toISOString();
        else if (expiryChoice === '30d') expiresAt = new Date(now + 30 * 24 * 3600 * 1000).toISOString();

        if (submitBtn) submitBtn.disabled = true;
        try {
          const res = await api('/shares', 'POST', {
            targetType,
            ...(targetType === 'image' ? { imageId } : { albumId }),
            expiresAt,
            password: passwordVal || null,
            allowDownload,
          });
          const fullUrl = absoluteShareUrl(res.data.shareUrl);
          if (resultBox) {
            resultBox.hidden = false;
            resultBox.innerHTML = `<div class="mb-2"><strong>Liên kết đã sẵn sàng:</strong></div>
              <div class="d-flex gap-2 align-items-center">
                <input type="text" class="form-control form-control-sm" readonly value="${esc(fullUrl)}" id="created-share-url" />
                <button type="button" class="btn btn-graphite btn-sm" id="copy-created-share">${icon('copy', 15)} Copy</button>
              </div>`;
            resultBox.querySelector('#copy-created-share')?.addEventListener('click', () => copyText(fullUrl, 'link chia sẻ'));
          }
          toast('Đã tạo liên kết chia sẻ.', 'success');
        } catch (err) {
          toast(err.message || 'Không thể tạo liên kết chia sẻ.', 'danger');
        } finally {
          if (submitBtn) submitBtn.disabled = false;
        }
      });
    },
  });
}

function openImageEditorModal(image, { onSaved }) {
  const originalUrl = resolveAssetUrl(image.originalUrl);
  openModal({
    title: `Image Editor — ${image.filename}`,
    maxWidth: '860px',
    bodyHtml: `<div class="media-editor-grid">
      <div class="media-editor-preview-panel">
        <div class="media-editor-stage">
          <img src="${esc(originalUrl)}" alt="${esc(image.filename)}" id="editor-preview-img" class="media-editor-img" />
        </div>
        <div class="media-editor-meta tabular">
          Gốc: ${image.width || '?'} × ${image.height || '?'} px · ${formatBytes(image.sizeBytes)} · ${esc((image.extension || '').toUpperCase())}
        </div>
        <div id="editor-variant-result" class="media-share-result" hidden></div>
      </div>
      <form id="image-editor-form" class="media-editor-controls">
        <div class="mb-2">
          <label class="form-label" for="ed-label">Tên phiên bản (Variant Label)</label>
          <input type="text" id="ed-label" class="form-control" placeholder="Ví dụ: Banner WebP 80%" maxlength="100" />
        </div>
        <div class="row g-2 mb-2">
          <div class="col-6">
            <label class="form-label" for="ed-format">Định dạng xuất</label>
            <select id="ed-format" class="form-select">
              <option value="webp" selected>WebP (Khuyên dùng)</option>
              <option value="jpeg">JPEG</option>
              <option value="png">PNG</option>
              <option value="avif">AVIF</option>
            </select>
          </div>
          <div class="col-6">
            <label class="form-label" for="ed-quality">Chất lượng: <span id="ed-quality-val" class="tabular">75</span>%</label>
            <input type="range" id="ed-quality" class="form-range" min="10" max="100" value="75" />
          </div>
        </div>
        <div class="row g-2 mb-2">
          <div class="col-4">
            <label class="form-label" for="ed-width">Resize Rộng (px)</label>
            <input type="number" id="ed-width" class="form-control tabular" min="1" max="10000" placeholder="${esc(image.width || '')}" />
          </div>
          <div class="col-4">
            <label class="form-label" for="ed-height">Resize Cao (px)</label>
            <input type="number" id="ed-height" class="form-control tabular" min="1" max="10000" placeholder="${esc(image.height || '')}" />
          </div>
          <div class="col-4">
            <label class="form-label" for="ed-fit">Chế độ Fit</label>
            <select id="ed-fit" class="form-select">
              <option value="inside">Inside</option>
              <option value="cover">Cover</option>
              <option value="contain">Contain</option>
              <option value="fill">Fill</option>
            </select>
          </div>
        </div>
        <div class="row g-2 mb-2">
          <div class="col-3">
            <label class="form-label" for="ed-crop-left">Crop X</label>
            <input type="number" id="ed-crop-left" class="form-control tabular" min="0" placeholder="0" />
          </div>
          <div class="col-3">
            <label class="form-label" for="ed-crop-top">Crop Y</label>
            <input type="number" id="ed-crop-top" class="form-control tabular" min="0" placeholder="0" />
          </div>
          <div class="col-3">
            <label class="form-label" for="ed-crop-w">Crop W</label>
            <input type="number" id="ed-crop-w" class="form-control tabular" min="1" placeholder="—" />
          </div>
          <div class="col-3">
            <label class="form-label" for="ed-crop-h">Crop H</label>
            <input type="number" id="ed-crop-h" class="form-control tabular" min="1" placeholder="—" />
          </div>
        </div>
        <div class="d-flex flex-wrap gap-2 align-items-center mb-3">
          <button type="button" class="btn btn-graphite btn-sm" id="ed-rotate-btn">${icon('rotateCw', 15)} Xoay +90° (<span id="ed-rotate-deg" class="tabular">0</span>°)</button>
          <button type="button" class="btn btn-graphite btn-sm" id="ed-fliph-btn">Lật ngang</button>
          <button type="button" class="btn btn-graphite btn-sm" id="ed-flipv-btn">Lật dọc</button>
          <button type="button" class="btn btn-ghost btn-sm" id="ed-reset-btn">Đặt lại</button>
        </div>
        <p class="form-hint">Thao tác lưu thành phiên bản mới trong <code>image_variants</code> — tuyệt đối không ghi đè ảnh gốc.</p>
      </form>
    </div>`,
    footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Đóng</button>
      <button type="submit" form="image-editor-form" class="btn btn-primary" id="ed-save-btn">${icon('check', 16)} Lưu thành Variant mới</button>`,
    onMount: (modal) => {
      let rotate = 0;
      let flipH = false;
      let flipV = false;

      const previewImg = modal.dialog.querySelector('#editor-preview-img');
      const qualityInput = modal.dialog.querySelector('#ed-quality');
      const qualityVal = modal.dialog.querySelector('#ed-quality-val');
      const degLabel = modal.dialog.querySelector('#ed-rotate-deg');
      const resultBox = modal.dialog.querySelector('#editor-variant-result');
      const saveBtn = modal.dialog.querySelector('#ed-save-btn');

      const updateLivePreview = () => {
        if (previewImg) {
          previewImg.style.transform = `rotate(${rotate}deg) scaleX(${flipH ? -1 : 1}) scaleY(${flipV ? -1 : 1})`;
        }
        if (degLabel) degLabel.textContent = String(rotate);
      };

      qualityInput?.addEventListener('input', () => {
        if (qualityVal) qualityVal.textContent = String(qualityInput.value);
      });

      modal.dialog.querySelector('#ed-rotate-btn')?.addEventListener('click', () => {
        rotate = (rotate + 90) % 360;
        updateLivePreview();
      });
      modal.dialog.querySelector('#ed-fliph-btn')?.addEventListener('click', () => {
        flipH = !flipH;
        updateLivePreview();
      });
      modal.dialog.querySelector('#ed-flipv-btn')?.addEventListener('click', () => {
        flipV = !flipV;
        updateLivePreview();
      });
      modal.dialog.querySelector('#ed-reset-btn')?.addEventListener('click', () => {
        rotate = 0;
        flipH = false;
        flipV = false;
        if (previewImg) previewImg.src = originalUrl;
        updateLivePreview();
      });

      modal.dialog.querySelector('#image-editor-form')?.addEventListener('submit', async (event) => {
        event.preventDefault();
        const payload = {
          format: modal.dialog.querySelector('#ed-format')?.value || 'webp',
          quality: Number(qualityInput?.value || 75),
          rotate,
          flipHorizontal: flipH,
          flipVertical: flipV,
          saveAsVariant: true,
        };
        const label = modal.dialog.querySelector('#ed-label')?.value?.trim();
        if (label) payload.label = label;

        const w = Number(modal.dialog.querySelector('#ed-width')?.value || 0);
        const h = Number(modal.dialog.querySelector('#ed-height')?.value || 0);
        const fit = modal.dialog.querySelector('#ed-fit')?.value || 'inside';
        if (w > 0 || h > 0) {
          payload.resize = { ...(w > 0 ? { width: w } : {}), ...(h > 0 ? { height: h } : {}), fit };
        }

        const cw = Number(modal.dialog.querySelector('#ed-crop-w')?.value || 0);
        const ch = Number(modal.dialog.querySelector('#ed-crop-h')?.value || 0);
        if (cw > 0 && ch > 0) {
          payload.crop = {
            left: Math.max(0, Number(modal.dialog.querySelector('#ed-crop-left')?.value || 0)),
            top: Math.max(0, Number(modal.dialog.querySelector('#ed-crop-top')?.value || 0)),
            width: cw,
            height: ch,
          };
        }

        if (saveBtn) saveBtn.disabled = true;
        try {
          const res = await api(`/images/${image.id}/transform`, 'POST', payload);
          const v = res.data;
          if (previewImg) {
            previewImg.style.transform = '';
            previewImg.src = resolveAssetUrl(v.url);
          }
          if (resultBox) {
            resultBox.hidden = false;
            resultBox.innerHTML = `Đã lưu variant <strong>${esc(v.label || v.variantType)}</strong>: <span class="tabular">${v.width}×${v.height} px · ${formatBytes(v.sizeBytes)}</span>`;
          }
          toast('Đã tạo biến thể ảnh mới (ảnh gốc được giữ nguyên).', 'success');
          await onSaved?.();
        } catch (err) {
          toast(err.message || 'Không thể xử lý chỉnh sửa ảnh.', 'danger');
        } finally {
          if (saveBtn) saveBtn.disabled = false;
        }
      });
    },
  });
}

async function openImageDetailDrawer(imageId, { folderOptions, onChanged }) {
  openDrawer({
    title: 'Chi tiết Hình ảnh',
    bodyHtml: renderTableSkeleton(4),
  });

  try {
    const res = await api(`/images/${imageId}`);
    const img = res.data;
    const origUrl = resolveAssetUrl(img.originalUrl);
    const fullOrigUrl = absoluteShareUrl(img.originalUrl);

    openDrawer({
      title: img.filename || 'Chi tiết Hình ảnh',
      bodyHtml: `<div class="media-detail-stack">
        <div class="media-detail-preview">
          <img src="${esc(origUrl)}" alt="${esc(img.filename)}" decoding="async" />
        </div>
        <div class="d-flex flex-wrap gap-2">
          <button type="button" class="btn btn-primary btn-sm" id="drawer-edit-image">${icon('sliders', 15)} Chỉnh sửa (Editor)</button>
          <button type="button" class="btn btn-graphite btn-sm" id="drawer-share-image">${icon('share', 15)} Chia sẻ</button>
          <button type="button" class="btn btn-graphite btn-sm" id="drawer-copy-url">${icon('copy', 15)} Copy URL</button>
          <a class="btn btn-graphite btn-sm" href="${esc(resolveAssetUrl(img.downloadUrl))}" target="_blank" rel="noopener">${icon('download', 15)} Tải về</a>
        </div>

        <form id="drawer-meta-form" class="meta-card p-3">
          <h4 class="card-title mb-2">Thông tin & Phân loại</h4>
          <div class="mb-2">
            <label class="form-label" for="dm-filename">Tên hiển thị</label>
            <input type="text" id="dm-filename" class="form-control" value="${esc(img.filename)}" required />
          </div>
          <div class="row g-2 mb-2">
            <div class="col-6">
              <label class="form-label" for="dm-visibility">Quyền truy cập</label>
              <select id="dm-visibility" class="form-select">
                <option value="private" ${img.visibility === 'private' ? 'selected' : ''}>Private</option>
                <option value="public" ${img.visibility === 'public' ? 'selected' : ''}>Public</option>
              </select>
            </div>
            <div class="col-6">
              <label class="form-label" for="dm-folder">Thư mục</label>
              <select id="dm-folder" class="form-select">
                <option value="">(Thư mục gốc)</option>
                ${folderOptions.map((f) => `<option value="${esc(f.id)}" ${img.folderId === f.id ? 'selected' : ''}>${esc(f.label)}</option>`).join('')}
              </select>
            </div>
          </div>
          <div class="mb-2">
            <label class="form-label" for="dm-tags">Tags (cách nhau bởi dấu phẩy)</label>
            <input type="text" id="dm-tags" class="form-control" value="${esc((img.tags || []).map((t) => t.name).join(', '))}" placeholder="banner, gym, promo" />
          </div>
          <div class="mb-3">
            <label class="form-label" for="dm-desc">Mô tả</label>
            <textarea id="dm-desc" class="form-control" rows="2">${esc(img.description || '')}</textarea>
          </div>
          <button type="submit" class="btn btn-primary btn-sm">${icon('check', 15)} Lưu thay đổi</button>
        </form>

        <div class="meta-card p-3">
          <h4 class="card-title mb-2">Metadata kỹ thuật</h4>
          <dl class="detail-kv tabular">
            <div><dt>ID</dt><dd><code>${esc(img.id)}</code></dd></div>
            <div><dt>Tên gốc</dt><dd>${esc(img.originalFilename)}</dd></div>
            <div><dt>Định dạng / MIME</dt><dd>${esc(img.extension?.toUpperCase())} · ${esc(img.mimeType)}</dd></div>
            <div><dt>Kích thước</dt><dd>${img.width || '?'} × ${img.height || '?'} px · ${formatBytes(img.sizeBytes)}</dd></div>
            <div><dt>Lượt xem / Tải</dt><dd>${Number(img.viewCount || 0)} xem · ${Number(img.downloadCount || 0)} tải</dd></div>
            <div><dt>SHA-256</dt><dd><code class="text-break">${esc(img.sha256Hash)}</code></dd></div>
            <div><dt>Ngày tạo</dt><dd>${formatDateTimeVN(img.createdAt, { withSeconds: true })}</dd></div>
          </dl>
          <details class="mt-2">
            <summary class="text-secondary" style="cursor:pointer;font-size:12px">Xem EXIF Metadata (JSON)</summary>
            <pre class="audit-json mt-2">${esc(JSON.stringify(img.exifData || {}, null, 2))}</pre>
          </details>
        </div>

        <div class="meta-card p-3">
          <h4 class="card-title mb-2">Biến thể (Variants: ${img.variants?.length || 0})</h4>
          ${!img.variants?.length
            ? '<p class="text-secondary mb-0" style="font-size:13px">Chưa có biến thể nào.</p>'
            : `<div class="d-flex flex-column gap-2">${img.variants.map((v) => `
              <div class="variant-row">
                <div>
                  <strong>${esc(v.label || v.variantType)}</strong>
                  <div class="text-secondary tabular" style="font-size:12px">${esc(v.mimeType)} · ${v.width || '?'}×${v.height || '?'} · ${formatBytes(v.sizeBytes)}</div>
                </div>
                <div class="d-flex gap-1">
                  <button type="button" class="btn btn-ghost btn-icon btn-xs copy-variant-url" data-url="${esc(absoluteShareUrl(v.url))}" title="Copy URL">${icon('copy', 14)}</button>
                  <button type="button" class="btn btn-ghost btn-icon btn-xs delete-variant-btn" data-variant-id="${esc(v.id)}" title="Xóa biến thể">${icon('trash', 14)}</button>
                </div>
              </div>
            `).join('')}</div>`}
        </div>
      </div>`,
      onMount: (drawer) => {
        drawer.panel.querySelector('#drawer-copy-url')?.addEventListener('click', () => copyText(fullOrigUrl, 'URL ảnh'));
        drawer.panel.querySelector('#drawer-share-image')?.addEventListener('click', () => {
          openShareCreateModal({ targetType: 'image', imageId: img.id, titleLabel: img.filename });
        });
        drawer.panel.querySelector('#drawer-edit-image')?.addEventListener('click', () => {
          openImageEditorModal(img, {
            onSaved: async () => {
              await onChanged?.();
              await openImageDetailDrawer(img.id, { folderOptions, onChanged });
            },
          });
        });

        drawer.panel.querySelectorAll('.copy-variant-url').forEach((btn) => {
          btn.addEventListener('click', () => copyText(btn.getAttribute('data-url'), 'URL biến thể'));
        });
        drawer.panel.querySelectorAll('.delete-variant-btn').forEach((btn) => {
          btn.addEventListener('click', () => {
            const variantId = btn.getAttribute('data-variant-id');
            openConfirmModal({
              title: 'Xóa biến thể ảnh',
              message: 'Xác nhận xóa biến thể này? Ảnh gốc vẫn được giữ nguyên.',
              confirmLabel: 'Xóa biến thể',
              confirmClass: 'btn-danger',
              onConfirm: async () => {
                await api(`/images/${img.id}/variants/${variantId}`, 'DELETE');
                toast('Đã xóa biến thể.', 'success');
                await onChanged?.();
                await openImageDetailDrawer(img.id, { folderOptions, onChanged });
              },
            });
          });
        });

        drawer.panel.querySelector('#drawer-meta-form')?.addEventListener('submit', async (event) => {
          event.preventDefault();
          try {
            const tagsRaw = drawer.panel.querySelector('#dm-tags')?.value || '';
            const tags = tagsRaw.split(',').map((t) => t.trim()).filter(Boolean);
            await api(`/images/${img.id}`, 'PATCH', {
              filename: drawer.panel.querySelector('#dm-filename')?.value?.trim(),
              visibility: drawer.panel.querySelector('#dm-visibility')?.value,
              folderId: drawer.panel.querySelector('#dm-folder')?.value || null,
              description: drawer.panel.querySelector('#dm-desc')?.value || '',
              tags,
            });
            toast('Đã cập nhật thông tin ảnh.', 'success');
            await onChanged?.();
          } catch (err) {
            toast(err.message || 'Không thể lưu thông tin ảnh.', 'danger');
          }
        });
      },
    });
  } catch (err) {
    openDrawer({
      title: 'Chi tiết Hình ảnh',
      bodyHtml: renderErrorState({ title: 'Không tải được chi tiết ảnh', message: err.message }),
    });
  }
}

export async function renderMediaLibraryPage({ root, params, shell }) {
  const tab = ['library', 'collections', 'tags', 'supabase'].includes(params?.get('tab')) ? params.get('tab') : 'library';
  const q = params?.get('q') || '';
  const format = params?.get('format') || '';
  const visibility = params?.get('visibility') || '';
  const folderId = params?.get('folderId') || '';
  const albumId = params?.get('albumId') || '';
  const tag = params?.get('tag') || '';
  const prefix = params?.get('prefix') || '';
  const sortBy = params?.get('sortBy') || 'created_at';
  const order = params?.get('order') || 'desc';
  const viewMode = params?.get('view') === 'grid' ? 'grid' : 'list';
  const page = Math.max(1, Number(params?.get('page')) || 1);
  const limit = Math.max(1, Number(params?.get('limit')) || 12);

  const tabsHtml = `<div class="media-subnav" role="tablist" aria-label="Quản lý Image Server">
    <button type="button" class="media-subnav-btn" role="tab" aria-selected="${tab === 'library'}" data-media-tab="library">${icon('image', 15)} Thư viện ảnh</button>
    <button type="button" class="media-subnav-btn" role="tab" aria-selected="${tab === 'collections'}" data-media-tab="collections">${icon('folder', 15)} Album & Thư mục</button>
    <button type="button" class="media-subnav-btn" role="tab" aria-selected="${tab === 'tags'}" data-media-tab="tags">${icon('tag', 15)} Tags</button>
    <button type="button" class="media-subnav-btn" role="tab" aria-selected="${tab === 'supabase'}" data-media-tab="supabase">${icon('database', 15)} Kho Supabase</button>
  </div>`;

  const topbarActionsHtml = `<button type="button" class="btn btn-graphite btn-sm" id="media-sync-supabase-btn">${icon('refresh', 15)} Đồng bộ Supabase</button>
    <button type="button" class="btn btn-graphite btn-sm" id="media-import-url-btn">${icon('globe', 15)} Nhập từ URL</button>
    <button type="button" class="btn btn-primary btn-sm" id="media-trigger-upload-btn">${icon('upload', 15)} Tải ảnh lên</button>`;

  shell({
    section: 'media-library',
    topbarActionsHtml,
    contentHtml: `${tabsHtml}<div id="media-tab-body">${renderTableSkeleton(6)}</div>`,
  });

  const bodyEl = root.querySelector('#media-tab-body');

  root.querySelectorAll('[data-media-tab]').forEach((btn) => {
    btn.addEventListener('click', () => {
      updateQuery({ tab: btn.getAttribute('data-media-tab'), page: 1 }, { replace: false });
    });
  });

  async function runSupabaseSync(onDone) {
    const syncBtn = root.querySelector('#media-sync-supabase-btn');
    if (syncBtn) syncBtn.disabled = true;
    try {
      const res = await api('/admin/storage/sync-supabase', 'POST', {});
      const s = res.data || {};
      toast(
        `Đồng bộ ${s.bucket || 'Supabase'} thành công: +${Number(s.syncedCount || 0)} ảnh mới, ${Number(s.totalStorageObjects || 0)} tệp đang lưu (${formatBytes(s.totalStorageBytes || 0)}).`,
        'success',
      );
      await onDone?.();
    } catch (err) {
      toast(err.message || 'Không thể đồng bộ từ Supabase Storage.', 'danger');
    } finally {
      if (syncBtn) syncBtn.disabled = false;
    }
  }

  async function loadAllCollections() {
    const [foldersRes, albumsRes, tagsRes] = await Promise.all([
      api('/folders').catch(() => ({ data: { items: [], tree: [] } })),
      api('/albums').catch(() => ({ data: [] })),
      api('/tags').catch(() => ({ data: [] })),
    ]);
    return {
      folders: foldersRes.data?.items || [],
      folderTree: foldersRes.data?.tree || [],
      albums: albumsRes.data || [],
      tags: tagsRes.data || [],
    };
  }

  function openUrlImportModal(collections, onDone) {
    const folderOptions = flattenFolderOptions(collections.folderTree);
    openModal({
      title: 'Nhập ảnh từ URL bên ngoài',
      maxWidth: '520px',
      bodyHtml: `<form id="import-url-form" class="meta-form-stack">
        <div class="mb-3">
          <label class="form-label" for="imp-url">URL hình ảnh (HTTP/HTTPS)</label>
          <input type="url" id="imp-url" class="form-control" placeholder="https://example.com/photo.jpg" required />
        </div>
        <div class="mb-3">
          <label class="form-label" for="imp-filename">Tên hiển thị (tùy chọn)</label>
          <input type="text" id="imp-filename" class="form-control" placeholder="hero-banner.jpg" />
        </div>
        <div class="row g-2 mb-3">
          <div class="col-6">
            <label class="form-label" for="imp-visibility">Quyền truy cập</label>
            <select id="imp-visibility" class="form-select">
              <option value="private">Private</option>
              <option value="public">Public</option>
            </select>
          </div>
          <div class="col-6">
            <label class="form-label" for="imp-folder">Thư mục</label>
            <select id="imp-folder" class="form-select">
              <option value="">(Thư mục gốc)</option>
              ${folderOptions.map((f) => `<option value="${esc(f.id)}">${esc(f.label)}</option>`).join('')}
            </select>
          </div>
        </div>
        <div class="mb-2">
          <label class="form-label" for="imp-tags">Tags</label>
          <input type="text" id="imp-tags" class="form-control" placeholder="banner, cloud" />
        </div>
      </form>`,
      footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
        <button type="submit" form="import-url-form" class="btn btn-primary" id="imp-submit">${icon('download', 15)} Nhập ảnh</button>`,
      onMount: (modal) => {
        const submitBtn = modal.dialog.querySelector('#imp-submit');
        modal.dialog.querySelector('#import-url-form')?.addEventListener('submit', async (event) => {
          event.preventDefault();
          if (submitBtn) submitBtn.disabled = true;
          try {
            const tagsRaw = modal.dialog.querySelector('#imp-tags')?.value || '';
            await api('/images/import-url', 'POST', {
              url: modal.dialog.querySelector('#imp-url')?.value?.trim(),
              filename: modal.dialog.querySelector('#imp-filename')?.value?.trim() || undefined,
              visibility: modal.dialog.querySelector('#imp-visibility')?.value,
              folderId: modal.dialog.querySelector('#imp-folder')?.value || null,
              tags: tagsRaw.split(',').map((t) => t.trim()).filter(Boolean),
            });
            toast('Đã nhập ảnh từ URL thành công.', 'success');
            modal.close();
            await onDone?.();
          } catch (err) {
            toast(err.message || 'Không thể nhập ảnh từ URL.', 'danger');
          } finally {
            if (submitBtn) submitBtn.disabled = false;
          }
        });
      },
    });
  }

  let pasteCleanup = null;

  async function renderLibraryTab() {
    if (pasteCleanup) { pasteCleanup(); pasteCleanup = null; }
    try {
      const [statsRes, collections, imagesRes] = await Promise.all([
        api('/stats'),
        loadAllCollections(),
        api(`/images${buildQuery({
          q,
          format,
          visibility,
          folderId,
          albumId,
          tag,
          sortBy,
          order,
          page,
          limit,
        })}`),
      ]);

      const stats = statsRes.data || {};
      const items = imagesRes.data || [];
      const meta = imagesRes.meta || { page: 1, limit, total: items.length, totalPages: 1 };
      const folderOptions = flattenFolderOptions(collections.folderTree);
      const hasFilter = Boolean(q || format || visibility || folderId || albumId || tag);
      const selectedIds = new Set();
      let queuedFiles = [];

      root.querySelector('#media-sync-supabase-btn').onclick = () => runSupabaseSync(renderLibraryTab);
      root.querySelector('#media-import-url-btn').onclick = () => openUrlImportModal(collections, renderLibraryTab);
      root.querySelector('#media-trigger-upload-btn').onclick = () => bodyEl.querySelector('#media-file-input')?.click();

      const kpiHtml = `<section class="media-kpi-strip">
        <article class="kpi-card">
          <div class="kpi-label">Tổng hình ảnh</div>
          <div class="kpi-value tabular">${Number(stats.totalImages || 0)}</div>
        </article>
        <article class="kpi-card">
          <div class="kpi-label">Dung lượng đang lưu</div>
          <div class="kpi-value tabular">${formatBytes(stats.totalStorageBytes || 0)}</div>
        </article>
        <article class="kpi-card">
          <div class="kpi-label">Upload hôm nay</div>
          <div class="kpi-value tabular">${Number(stats.uploadsToday || 0)}</div>
        </article>
        <article class="kpi-card">
          <div class="kpi-label">Tổng lượt xem</div>
          <div class="kpi-value tabular">${Number(stats.totalViews || 0)}</div>
        </article>
      </section>`;

      const uploadZoneHtml = `<section class="meta-card media-upload-card mb-3">
        <div class="media-dropzone" id="media-dropzone" tabindex="0" role="button" aria-label="Kéo thả hoặc chọn ảnh để tải lên">
          <input type="file" id="media-file-input" multiple accept="image/jpeg,image/png,image/webp,image/avif,image/gif,image/svg+xml" hidden />
          <div class="media-dropzone-icon">${icon('upload', 26)}</div>
          <div>
            <strong>Kéo & thả ảnh vào đây</strong>, bấm chọn tệp hoặc nhấn <kbd>Ctrl+V</kbd> để dán ảnh từ Clipboard
          </div>
          <div class="text-secondary" style="font-size:12px">Hỗ trợ JPEG, PNG, WebP, AVIF, GIF, SVG · Kiểm tra magic-bytes & tạo thumbnail WebP tự động</div>
        </div>
        <div id="media-upload-queue" class="media-upload-queue" hidden></div>
      </section>`;

      const filterHtml = `<form class="filter-bar mb-3" id="media-filter-form">
        <input type="search" id="mf-q" class="form-control filter-grow" placeholder="Tìm tên ảnh hoặc mô tả…" value="${esc(q)}" aria-label="Tìm ảnh" />
        <select id="mf-format" class="form-select filter-fixed" aria-label="Lọc định dạng">
          <option value="" ${!format ? 'selected' : ''}>Tất cả định dạng</option>
          <option value="jpeg" ${format === 'jpeg' ? 'selected' : ''}>JPEG</option>
          <option value="png" ${format === 'png' ? 'selected' : ''}>PNG</option>
          <option value="webp" ${format === 'webp' ? 'selected' : ''}>WebP</option>
          <option value="avif" ${format === 'avif' ? 'selected' : ''}>AVIF</option>
          <option value="gif" ${format === 'gif' ? 'selected' : ''}>GIF</option>
          <option value="svg" ${format === 'svg' ? 'selected' : ''}>SVG</option>
        </select>
        <select id="mf-visibility" class="form-select filter-fixed" aria-label="Lọc quyền truy cập">
          <option value="" ${!visibility ? 'selected' : ''}>Public & Private</option>
          <option value="public" ${visibility === 'public' ? 'selected' : ''}>Public</option>
          <option value="private" ${visibility === 'private' ? 'selected' : ''}>Private</option>
        </select>
        <select id="mf-folder" class="form-select filter-fixed" aria-label="Lọc thư mục">
          <option value="" ${!folderId ? 'selected' : ''}>Tất cả thư mục</option>
          ${folderOptions.map((f) => `<option value="${esc(f.id)}" ${folderId === f.id ? 'selected' : ''}>${esc(f.label)}</option>`).join('')}
        </select>
        <select id="mf-sort" class="form-select filter-fixed" aria-label="Sắp xếp">
          <option value="created_at:desc" ${sortBy === 'created_at' && order === 'desc' ? 'selected' : ''}>Mới nhất</option>
          <option value="size_bytes:desc" ${sortBy === 'size_bytes' && order === 'desc' ? 'selected' : ''}>Dung lượng lớn</option>
          <option value="view_count:desc" ${sortBy === 'view_count' && order === 'desc' ? 'selected' : ''}>Xem nhiều nhất</option>
          <option value="filename:asc" ${sortBy === 'filename' && order === 'asc' ? 'selected' : ''}>Tên A-Z</option>
        </select>
        <div class="btn-group" role="group" aria-label="Chế độ hiển thị">
          <button type="button" class="btn ${viewMode === 'list' ? 'btn-primary' : 'btn-graphite'} btn-sm" id="mf-view-list" title="Danh sách">${icon('list', 15)}</button>
          <button type="button" class="btn ${viewMode === 'grid' ? 'btn-primary' : 'btn-graphite'} btn-sm" id="mf-view-grid" title="Lưới">${icon('grid', 15)}</button>
        </div>
        ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm" id="mf-clear">Xóa lọc</button>' : ''}
        <button type="button" class="btn btn-danger btn-sm" id="mf-bulk-delete" hidden>${icon('trash', 15)} Xóa đã chọn (<span id="mf-selected-count" class="tabular">0</span>)</button>
      </form>`;

      let galleryHtml = '';
      if (!items.length) {
        galleryHtml = hasFilter
          ? renderFilterEmptyState({
              title: 'Không có ảnh nào khớp bộ lọc',
              message: 'Thử thay đổi từ khóa, định dạng hoặc thư mục để xem thêm ảnh.',
              clearBtnId: 'media-empty-clear',
            })
          : renderEmptyState({
              title: 'Thư viện chưa có hình ảnh nào',
              message: 'Kéo thả tệp, dán từ clipboard hoặc bấm "Tải ảnh lên" để bắt đầu.',
            });
      } else if (viewMode === 'list') {
        galleryHtml = `<div class="meta-card p-0 overflow-hidden"><div class="table-responsive"><table class="table table-hover align-middle mb-0">
          <thead><tr>
            <th style="width:40px"><input type="checkbox" id="media-select-all" aria-label="Chọn tất cả" /></th>
            <th>Ảnh</th>
            <th>Tên tệp</th>
            <th>Kích thước</th>
            <th>Quyền</th>
            <th>Lượt xem</th>
            <th>Thao tác</th>
          </tr></thead>
          <tbody>${items.map((img) => `
            <tr>
              <td><input type="checkbox" class="media-select-item" data-id="${esc(img.id)}" aria-label="Chọn ${esc(img.filename)}" /></td>
              <td><img class="media-list-thumb" src="${esc(resolveAssetUrl(img.thumbnailUrl))}" alt="${esc(img.filename)}" loading="lazy" decoding="async" /></td>
              <td>
                <div class="fw-semibold">${esc(img.filename)}</div>
                <div class="text-secondary" style="font-size:12px">${esc(img.extension?.toUpperCase())} · ${esc(img.folderName || 'Gốc')}</div>
              </td>
              <td class="tabular">${img.width || '?'}×${img.height || '?'}<br><span class="text-secondary">${formatBytes(img.sizeBytes)}</span></td>
              <td>${statusBadge(img.visibility === 'public' ? 'ACTIVE' : 'HIDDEN', img.visibility === 'public' ? 'Public' : 'Private')}</td>
              <td class="tabular">${Number(img.viewCount || 0)}</td>
              <td>
                <div class="d-flex gap-1">
                  <button type="button" class="btn btn-graphite btn-icon btn-sm media-act-detail" data-id="${esc(img.id)}" title="Chi tiết">${icon('eye', 15)}</button>
                  <button type="button" class="btn btn-graphite btn-icon btn-sm media-act-edit" data-id="${esc(img.id)}" title="Chỉnh sửa">${icon('sliders', 15)}</button>
                  <button type="button" class="btn btn-graphite btn-icon btn-sm media-act-share" data-id="${esc(img.id)}" data-name="${esc(img.filename)}" title="Chia sẻ">${icon('share', 15)}</button>
                  <button type="button" class="btn btn-graphite btn-icon btn-sm media-act-copy" data-url="${esc(absoluteShareUrl(img.originalUrl))}" title="Copy URL">${icon('copy', 15)}</button>
                  <button type="button" class="btn btn-graphite btn-icon btn-sm media-act-delete" data-id="${esc(img.id)}" data-name="${esc(img.filename)}" title="Xóa">${icon('trash', 15)}</button>
                </div>
              </td>
            </tr>
          `).join('')}</tbody>
        </table></div></div>`;
      } else {
        galleryHtml = `<div class="media-grid">${items.map((img) => `
          <article class="meta-card media-card">
            <div class="media-card-thumb-wrap">
              <input type="checkbox" class="media-card-check media-select-item" data-id="${esc(img.id)}" aria-label="Chọn ${esc(img.filename)}" />
              <span class="media-card-fmt">${esc(img.extension?.toUpperCase())}</span>
              <img src="${esc(resolveAssetUrl(img.thumbnailUrl))}" alt="${esc(img.filename)}" class="media-card-thumb media-act-detail" data-id="${esc(img.id)}" loading="lazy" decoding="async" />
            </div>
            <div class="media-card-body">
              <div class="media-card-title" title="${esc(img.filename)}">${esc(img.filename)}</div>
              <div class="media-card-meta tabular">
                <span>${img.width || '?'}×${img.height || '?'} · ${formatBytes(img.sizeBytes)}</span>
                <span>${img.visibility === 'public' ? 'Public' : 'Private'}</span>
              </div>
              <div class="media-card-actions">
                <button type="button" class="btn btn-graphite btn-icon btn-xs media-act-detail" data-id="${esc(img.id)}" title="Chi tiết" aria-label="Chi tiết">${icon('eye', 14)}</button>
                <button type="button" class="btn btn-graphite btn-icon btn-xs media-act-edit" data-id="${esc(img.id)}" title="Image Editor" aria-label="Chỉnh sửa">${icon('sliders', 14)}</button>
                <button type="button" class="btn btn-graphite btn-icon btn-xs media-act-share" data-id="${esc(img.id)}" data-name="${esc(img.filename)}" title="Chia sẻ" aria-label="Chia sẻ">${icon('share', 14)}</button>
                <button type="button" class="btn btn-graphite btn-icon btn-xs media-act-copy" data-url="${esc(absoluteShareUrl(img.originalUrl))}" title="Copy URL" aria-label="Copy URL">${icon('copy', 14)}</button>
                <button type="button" class="btn btn-graphite btn-icon btn-xs media-act-delete" data-id="${esc(img.id)}" data-name="${esc(img.filename)}" title="Xóa" aria-label="Xóa">${icon('trash', 14)}</button>
              </div>
            </div>
          </article>
        `).join('')}</div>`;
      }

      const paginationHtml = items.length
        ? renderPagination({
            page: meta.page,
            pageSize: meta.limit,
            totalItems: meta.total,
            totalPages: meta.totalPages,
          })
        : '';

      bodyEl.innerHTML = `${kpiHtml}${uploadZoneHtml}${filterHtml}${galleryHtml}${paginationHtml}`;

      // Upload Queue helpers
      const queueEl = bodyEl.querySelector('#media-upload-queue');
      const fileInput = bodyEl.querySelector('#media-file-input');
      const dropzone = bodyEl.querySelector('#media-dropzone');

      const renderUploadQueue = () => {
        if (!queueEl) return;
        if (!queuedFiles.length) {
          queueEl.hidden = true;
          queueEl.innerHTML = '';
          return;
        }
        queueEl.hidden = false;
        queueEl.innerHTML = `<div class="media-queue-controls mb-2">
          <select id="uq-folder" class="form-select form-select-sm" aria-label="Thư mục đích">
            <option value="">(Thư mục gốc)</option>
            ${folderOptions.map((f) => `<option value="${esc(f.id)}" ${folderId === f.id ? 'selected' : ''}>${esc(f.label)}</option>`).join('')}
          </select>
          <select id="uq-album" class="form-select form-select-sm" aria-label="Album đích">
            <option value="">(Không thêm vào Album)</option>
            ${collections.albums.map((a) => `<option value="${esc(a.id)}">${esc(a.title)}</option>`).join('')}
          </select>
          <select id="uq-visibility" class="form-select form-select-sm" aria-label="Quyền truy cập">
            <option value="private">Private</option>
            <option value="public">Public</option>
          </select>
          <input type="text" id="uq-tags" class="form-control form-control-sm" placeholder="Tags (vd: banner, gym)" />
          <button type="button" class="btn btn-primary btn-sm" id="uq-start-btn">${icon('upload', 15)} Tải lên ${queuedFiles.length} ảnh</button>
          <button type="button" class="btn btn-ghost btn-sm" id="uq-clear-btn">Hủy hàng đợi</button>
        </div>
        <div class="media-queue-list">${queuedFiles.map((entry, idx) => `
          <div class="media-queue-item">
            ${entry.previewUrl ? `<img src="${esc(entry.previewUrl)}" alt="${esc(entry.file.name)}" class="media-queue-thumb" />` : ''}
            <div class="flex-grow-1">
              <div class="d-flex justify-content-between"><strong style="font-size:13px">${esc(entry.file.name)}</strong><span class="tabular text-secondary" style="font-size:12px">${formatBytes(entry.file.size)}</span></div>
              <div class="seat-track mt-1"><div class="seat-fill" id="uq-bar-${idx}" style="width:${entry.progress}%"></div></div>
            </div>
          </div>
        `).join('')}</div>`;

        queueEl.querySelector('#uq-clear-btn')?.addEventListener('click', () => {
          queuedFiles.forEach((e) => e.previewUrl && globalThis.URL?.revokeObjectURL?.(e.previewUrl));
          queuedFiles = [];
          renderUploadQueue();
        });

        queueEl.querySelector('#uq-start-btn')?.addEventListener('click', async () => {
          const btn = queueEl.querySelector('#uq-start-btn');
          if (btn) btn.disabled = true;
          const targetFolder = queueEl.querySelector('#uq-folder')?.value || '';
          const targetAlbum = queueEl.querySelector('#uq-album')?.value || '';
          const targetVisibility = queueEl.querySelector('#uq-visibility')?.value || 'private';
          const targetTags = queueEl.querySelector('#uq-tags')?.value || '';

          let successCount = 0;
          for (let i = 0; i < queuedFiles.length; i += 1) {
            const entry = queuedFiles[i];
            const fd = new globalThis.FormData();
            fd.append('files', entry.file, entry.file.name || `paste-${Date.now()}.png`);
            if (targetFolder) fd.append('folderId', targetFolder);
            if (targetAlbum) fd.append('albumId', targetAlbum);
            fd.append('visibility', targetVisibility);
            if (targetTags.trim()) fd.append('tags', targetTags.trim());

            try {
              await uploadFormData('/images/upload', fd, {
                onProgress: (pct) => {
                  entry.progress = pct;
                  const bar = queueEl.querySelector(`#uq-bar-${i}`);
                  if (bar) bar.style.width = `${pct}%`;
                },
              });
              successCount += 1;
            } catch (err) {
              toast(`${entry.file.name}: ${err.message}`, 'danger');
            }
          }

          if (successCount > 0) {
            toast(`Đã tải lên thành công ${successCount} ảnh.`, 'success');
            queuedFiles.forEach((e) => e.previewUrl && globalThis.URL?.revokeObjectURL?.(e.previewUrl));
            queuedFiles = [];
            await renderLibraryTab();
          } else if (btn) {
            btn.disabled = false;
          }
        });
      };

      const enqueueFiles = (fileList) => {
        const arr = [...(fileList || [])].filter((f) => f && f.size > 0);
        if (!arr.length) return;
        for (const f of arr) {
          const previewUrl = globalThis.URL?.createObjectURL ? globalThis.URL.createObjectURL(f) : '';
          queuedFiles.push({ file: f, previewUrl, progress: 0 });
        }
        renderUploadQueue();
      };

      dropzone?.addEventListener('click', () => fileInput?.click());
      dropzone?.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          fileInput?.click();
        }
      });
      dropzone?.addEventListener('dragover', (e) => {
        e.preventDefault();
        dropzone.classList.add('is-dragover');
      });
      dropzone?.addEventListener('dragleave', () => dropzone.classList.remove('is-dragover'));
      dropzone?.addEventListener('drop', (e) => {
        e.preventDefault();
        dropzone.classList.remove('is-dragover');
        enqueueFiles(e.dataTransfer?.files);
      });
      fileInput?.addEventListener('change', () => {
        enqueueFiles(fileInput.files);
        fileInput.value = '';
      });

      const onPaste = (event) => {
        const itemsClip = event.clipboardData?.items || [];
        const pasted = [];
        for (const it of itemsClip) {
          if (it.kind === 'file' && it.type.startsWith('image/')) {
            const file = it.getAsFile();
            if (file) pasted.push(file);
          }
        }
        if (pasted.length) {
          enqueueFiles(pasted);
          toast(`Đã nhận ${pasted.length} ảnh từ Clipboard.`, 'info');
        }
      };
      globalThis.document?.addEventListener?.('paste', onPaste);
      pasteCleanup = () => globalThis.document?.removeEventListener?.('paste', onPaste);

      // Filter events
      const qInput = bodyEl.querySelector('#mf-q');
      qInput?.addEventListener('input', debounce(() => updateQuery({ q: qInput.value.trim(), page: 1 })));
      bodyEl.querySelector('#mf-format')?.addEventListener('change', (e) => updateQuery({ format: e.target.value, page: 1 }));
      bodyEl.querySelector('#mf-visibility')?.addEventListener('change', (e) => updateQuery({ visibility: e.target.value, page: 1 }));
      bodyEl.querySelector('#mf-folder')?.addEventListener('change', (e) => updateQuery({ folderId: e.target.value, page: 1 }));
      bodyEl.querySelector('#mf-sort')?.addEventListener('change', (e) => {
        const [sb, ord] = String(e.target.value).split(':');
        updateQuery({ sortBy: sb, order: ord, page: 1 });
      });
      bodyEl.querySelector('#mf-view-grid')?.addEventListener('click', () => updateQuery({ view: 'grid' }));
      bodyEl.querySelector('#mf-view-list')?.addEventListener('click', () => updateQuery({ view: 'list' }));
      bodyEl.querySelector('#mf-clear')?.addEventListener('click', () => {
        updateQuery({ q: '', format: '', visibility: '', folderId: '', albumId: '', tag: '', page: 1 });
      });
      bodyEl.querySelector('#media-empty-clear')?.addEventListener('click', () => {
        updateQuery({ q: '', format: '', visibility: '', folderId: '', albumId: '', tag: '', page: 1 });
      });

      // Selection & Bulk delete
      const bulkBtn = bodyEl.querySelector('#mf-bulk-delete');
      const countSpan = bodyEl.querySelector('#mf-selected-count');
      const syncSelectionUi = () => {
        if (countSpan) countSpan.textContent = String(selectedIds.size);
        if (bulkBtn) bulkBtn.hidden = selectedIds.size === 0;
      };
      bodyEl.querySelector('#media-select-all')?.addEventListener('change', (e) => {
        const checked = Boolean(e.target.checked);
        bodyEl.querySelectorAll('.media-select-item').forEach((cb) => {
          cb.checked = checked;
          const id = cb.getAttribute('data-id');
          if (checked) selectedIds.add(id);
          else selectedIds.delete(id);
        });
        syncSelectionUi();
      });
      bodyEl.querySelectorAll('.media-select-item').forEach((cb) => {
        cb.addEventListener('change', () => {
          const id = cb.getAttribute('data-id');
          if (cb.checked) selectedIds.add(id);
          else selectedIds.delete(id);
          syncSelectionUi();
        });
      });

      bulkBtn?.addEventListener('click', () => {
        const ids = [...selectedIds];
        if (!ids.length) return;
        openConfirmModal({
          title: `Xóa ${ids.length} hình ảnh đã chọn`,
          message: 'Ảnh sẽ bị xóa vĩnh viễn khỏi Storage và cập nhật lại dung lượng sử dụng.',
          confirmLabel: `Xóa ${ids.length} ảnh`,
          confirmClass: 'btn-danger',
          onConfirm: async () => {
            await api('/images/bulk-delete', 'POST', { ids, permanent: true });
            toast(`Đã xóa ${ids.length} hình ảnh.`, 'success');
            await renderLibraryTab();
          },
        });
      });

      // Card/row actions
      const itemMap = new Map(items.map((it) => [it.id, it]));
      bodyEl.querySelectorAll('.media-act-detail').forEach((el) => {
        el.addEventListener('click', () => openImageDetailDrawer(el.getAttribute('data-id'), { folderOptions, onChanged: renderLibraryTab }));
      });
      bodyEl.querySelectorAll('.media-act-edit').forEach((el) => {
        el.addEventListener('click', () => {
          const item = itemMap.get(el.getAttribute('data-id'));
          if (item) openImageEditorModal(item, { onSaved: renderLibraryTab });
        });
      });
      bodyEl.querySelectorAll('.media-act-share').forEach((el) => {
        el.addEventListener('click', () => openShareCreateModal({
          targetType: 'image',
          imageId: el.getAttribute('data-id'),
          titleLabel: el.getAttribute('data-name') || 'Ảnh',
        }));
      });
      bodyEl.querySelectorAll('.media-act-copy').forEach((el) => {
        el.addEventListener('click', () => copyText(el.getAttribute('data-url'), 'URL ảnh'));
      });
      bodyEl.querySelectorAll('.media-act-delete').forEach((el) => {
        el.addEventListener('click', () => {
          const id = el.getAttribute('data-id');
          const name = el.getAttribute('data-name') || 'ảnh này';
          openConfirmModal({
            title: 'Xóa vĩnh viễn hình ảnh',
            message: `Bạn có chắc muốn xóa "${name}" khỏi Database và Storage?`,
            confirmLabel: 'Xóa vĩnh viễn',
            confirmClass: 'btn-danger',
            onConfirm: async () => {
              await api(`/images/${id}?permanent=true`, 'DELETE');
              toast('Đã xóa hình ảnh.', 'success');
              await renderLibraryTab();
            },
          });
        });
      });

      bindPagination(bodyEl, {
        onPageChange: (nextPage) => updateQuery({ page: nextPage }),
        onPageSizeChange: (nextSize) => updateQuery({ limit: nextSize, page: 1 }),
      });
    } catch (err) {
      bodyEl.innerHTML = renderErrorState({ title: 'Không tải được thư viện ảnh', message: err.message });
      bodyEl.querySelector('#retry-load-btn')?.addEventListener('click', renderLibraryTab);
    }
  }

  async function renderCollectionsTab() {
    if (pasteCleanup) { pasteCleanup(); pasteCleanup = null; }
    try {
      const collections = await loadAllCollections();
      const folderOptions = flattenFolderOptions(collections.folderTree);

      bodyEl.innerHTML = `<div class="media-collections-grid">
        <section class="meta-card p-3">
          <div class="d-flex justify-content-between align-items-center mb-3">
            <h3 class="card-title mb-0">${icon('folder', 17)} Thư mục (Folders)</h3>
            <button type="button" class="btn btn-primary btn-sm" id="btn-new-folder">${icon('plus', 15)} Tạo thư mục</button>
          </div>
          ${renderFolderTreeHtml(collections.folderTree, folderId)}
        </section>

        <section class="meta-card p-3">
          <div class="d-flex justify-content-between align-items-center mb-3">
            <h3 class="card-title mb-0">${icon('layers', 17)} Albums (${collections.albums.length})</h3>
            <button type="button" class="btn btn-primary btn-sm" id="btn-new-album">${icon('plus', 15)} Tạo Album</button>
          </div>
          ${!collections.albums.length
            ? renderEmptyState({ title: 'Chưa có Album nào', message: 'Tạo Album để gom nhóm và chia sẻ nhiều ảnh cùng lúc.' })
            : `<div class="media-album-grid">${collections.albums.map((alb) => `
              <article class="media-album-card">
                <div class="media-album-cover">
                  ${alb.coverThumbnailUrl
                    ? `<img src="${esc(resolveAssetUrl(alb.coverThumbnailUrl))}" alt="${esc(alb.title)}" loading="lazy" decoding="async" />`
                    : `<div class="media-album-placeholder">${icon('image', 28)}</div>`}
                </div>
                <div class="p-3">
                  <div class="d-flex justify-content-between align-items-start gap-2">
                    <strong>${esc(alb.title)}</strong>
                    ${statusBadge(alb.visibility === 'public' ? 'ACTIVE' : 'HIDDEN', alb.visibility === 'public' ? 'Public' : 'Private')}
                  </div>
                  <p class="text-secondary mt-1 mb-2" style="font-size:12px">${esc(alb.description || 'Không có mô tả')}</p>
                  <div class="d-flex justify-content-between align-items-center">
                    <span class="tabular text-secondary" style="font-size:12px">${Number(alb.imageCount || 0)} ảnh</span>
                    <div class="d-flex gap-1">
                      <button type="button" class="btn btn-graphite btn-xs alb-open" data-id="${esc(alb.id)}">Xem ảnh</button>
                      <button type="button" class="btn btn-graphite btn-icon btn-xs alb-share" data-id="${esc(alb.id)}" data-title="${esc(alb.title)}" title="Chia sẻ">${icon('share', 14)}</button>
                      <button type="button" class="btn btn-graphite btn-icon btn-xs alb-delete" data-id="${esc(alb.id)}" data-title="${esc(alb.title)}" title="Xóa">${icon('trash', 14)}</button>
                    </div>
                  </div>
                </div>
              </article>
            `).join('')}</div>`}
        </section>
      </div>`;

      root.querySelector('#media-sync-supabase-btn').onclick = () => runSupabaseSync(renderCollectionsTab);
      root.querySelector('#media-import-url-btn').onclick = () => openUrlImportModal(collections, renderCollectionsTab);
      root.querySelector('#media-trigger-upload-btn').onclick = () => updateQuery({ tab: 'library' }, { replace: false });

      bodyEl.querySelector('#btn-new-folder')?.addEventListener('click', () => {
        openModal({
          title: 'Tạo thư mục mới',
          maxWidth: '440px',
          bodyHtml: `<form id="new-folder-form">
            <div class="mb-3">
              <label class="form-label" for="nf-name">Tên thư mục</label>
              <input type="text" id="nf-name" class="form-control" required maxlength="150" placeholder="Ví dụ: Thiết bị Cardio" />
            </div>
            <div class="mb-2">
              <label class="form-label" for="nf-parent">Thư mục cha (tùy chọn)</label>
              <select id="nf-parent" class="form-select">
                <option value="">(Thư mục gốc)</option>
                ${folderOptions.map((f) => `<option value="${esc(f.id)}">${esc(f.label)}</option>`).join('')}
              </select>
            </div>
          </form>`,
          footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
            <button type="submit" form="new-folder-form" class="btn btn-primary">Tạo thư mục</button>`,
          onMount: (modal) => {
            modal.dialog.querySelector('#new-folder-form')?.addEventListener('submit', async (e) => {
              e.preventDefault();
              try {
                await api('/folders', 'POST', {
                  name: modal.dialog.querySelector('#nf-name')?.value?.trim(),
                  parentId: modal.dialog.querySelector('#nf-parent')?.value || null,
                });
                toast('Đã tạo thư mục.', 'success');
                modal.close();
                await renderCollectionsTab();
              } catch (err) {
                toast(err.message || 'Không thể tạo thư mục.', 'danger');
              }
            });
          },
        });
      });

      bodyEl.querySelectorAll('[data-folder-select]').forEach((btn) => {
        btn.addEventListener('click', () => {
          updateQuery({ tab: 'library', folderId: btn.getAttribute('data-folder-select'), page: 1 }, { replace: false });
        });
      });
      bodyEl.querySelectorAll('[data-folder-rename]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const id = btn.getAttribute('data-folder-rename');
          const curName = btn.getAttribute('data-folder-name') || '';
          openModal({
            title: 'Đổi tên thư mục',
            maxWidth: '420px',
            bodyHtml: `<form id="rename-folder-form">
              <label class="form-label" for="rf-name">Tên mới</label>
              <input type="text" id="rf-name" class="form-control" value="${esc(curName)}" required maxlength="150" />
            </form>`,
            footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
              <button type="submit" form="rename-folder-form" class="btn btn-primary">Lưu tên</button>`,
            onMount: (modal) => {
              modal.dialog.querySelector('#rename-folder-form')?.addEventListener('submit', async (e) => {
                e.preventDefault();
                try {
                  await api(`/folders/${id}`, 'PATCH', { name: modal.dialog.querySelector('#rf-name')?.value?.trim() });
                  toast('Đã đổi tên thư mục.', 'success');
                  modal.close();
                  await renderCollectionsTab();
                } catch (err) {
                  toast(err.message || 'Không thể đổi tên thư mục.', 'danger');
                }
              });
            },
          });
        });
      });
      bodyEl.querySelectorAll('[data-folder-delete]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const id = btn.getAttribute('data-folder-delete');
          const name = btn.getAttribute('data-folder-name') || '';
          openConfirmModal({
            title: 'Xóa thư mục',
            message: `Xác nhận xóa thư mục "${name}"? Các ảnh bên trong sẽ được đưa về thư mục gốc.`,
            confirmLabel: 'Xóa thư mục',
            confirmClass: 'btn-danger',
            onConfirm: async () => {
              await api(`/folders/${id}`, 'DELETE');
              toast('Đã xóa thư mục.', 'success');
              await renderCollectionsTab();
            },
          });
        });
      });

      bodyEl.querySelector('#btn-new-album')?.addEventListener('click', () => {
        openModal({
          title: 'Tạo Album mới',
          maxWidth: '460px',
          bodyHtml: `<form id="new-album-form">
            <div class="mb-3">
              <label class="form-label" for="na-title">Tên Album</label>
              <input type="text" id="na-title" class="form-control" required maxlength="180" placeholder="Ví dụ: Bộ ảnh Phòng tập Q1" />
            </div>
            <div class="mb-3">
              <label class="form-label" for="na-visibility">Quyền truy cập</label>
              <select id="na-visibility" class="form-select">
                <option value="private">Private</option>
                <option value="public">Public</option>
              </select>
            </div>
            <div class="mb-2">
              <label class="form-label" for="na-desc">Mô tả</label>
              <textarea id="na-desc" class="form-control" rows="2"></textarea>
            </div>
          </form>`,
          footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
            <button type="submit" form="new-album-form" class="btn btn-primary">Tạo Album</button>`,
          onMount: (modal) => {
            modal.dialog.querySelector('#new-album-form')?.addEventListener('submit', async (e) => {
              e.preventDefault();
              try {
                await api('/albums', 'POST', {
                  title: modal.dialog.querySelector('#na-title')?.value?.trim(),
                  visibility: modal.dialog.querySelector('#na-visibility')?.value,
                  description: modal.dialog.querySelector('#na-desc')?.value?.trim() || null,
                });
                toast('Đã tạo Album.', 'success');
                modal.close();
                await renderCollectionsTab();
              } catch (err) {
                toast(err.message || 'Không thể tạo Album.', 'danger');
              }
            });
          },
        });
      });

      bodyEl.querySelectorAll('.alb-open').forEach((btn) => {
        btn.addEventListener('click', () => {
          updateQuery({ tab: 'library', albumId: btn.getAttribute('data-id'), page: 1 }, { replace: false });
        });
      });
      bodyEl.querySelectorAll('.alb-share').forEach((btn) => {
        btn.addEventListener('click', () => {
          openShareCreateModal({
            targetType: 'album',
            albumId: btn.getAttribute('data-id'),
            titleLabel: btn.getAttribute('data-title') || 'Album',
          });
        });
      });
      bodyEl.querySelectorAll('.alb-delete').forEach((btn) => {
        btn.addEventListener('click', () => {
          const id = btn.getAttribute('data-id');
          const title = btn.getAttribute('data-title') || 'Album';
          openConfirmModal({
            title: 'Xóa Album',
            message: `Xác nhận xóa Album "${title}"? Hình ảnh bên trong không bị xóa khỏi thư viện.`,
            confirmLabel: 'Xóa Album',
            confirmClass: 'btn-danger',
            onConfirm: async () => {
              await api(`/albums/${id}`, 'DELETE');
              toast('Đã xóa Album.', 'success');
              await renderCollectionsTab();
            },
          });
        });
      });
    } catch (err) {
      bodyEl.innerHTML = renderErrorState({ title: 'Không tải được Album & Thư mục', message: err.message });
    }
  }

  async function renderTagsTab() {
    if (pasteCleanup) { pasteCleanup(); pasteCleanup = null; }
    try {
      const collections = await loadAllCollections();
      bodyEl.innerHTML = `<section class="meta-card p-3">
        <form id="create-tag-form" class="d-flex flex-wrap gap-2 align-items-end mb-3">
          <div>
            <label class="form-label" for="tag-name-input">Tên Tag mới</label>
            <input type="text" id="tag-name-input" class="form-control" required maxlength="80" placeholder="Ví dụ: cardio-banner" />
          </div>
          <div>
            <label class="form-label" for="tag-color-input">Màu nhãn</label>
            <input type="color" id="tag-color-input" class="form-control form-control-color" value="#FF5E36" />
          </div>
          <button type="submit" class="btn btn-primary">${icon('plus', 15)} Thêm Tag</button>
        </form>
        ${!collections.tags.length
          ? renderEmptyState({ title: 'Chưa có Tag nào', message: 'Tạo Tag hoặc gắn trực tiếp khi upload/chỉnh sửa ảnh.' })
          : `<div class="media-tags-wrap">${collections.tags.map((t) => `
            <div class="media-tag-pill">
              <span class="tag-dot" style="background:${esc(t.color || '#FF5E36')}"></span>
              <button type="button" class="btn-link-plain tag-filter-btn" data-tag="${esc(t.slug)}">${esc(t.name)}</button>
              <span class="badge-count tabular">${Number(t.imageCount || 0)}</span>
              <button type="button" class="btn btn-ghost btn-icon btn-xs tag-delete-btn" data-id="${esc(t.id)}" data-name="${esc(t.name)}" title="Xóa tag">${icon('close', 13)}</button>
            </div>
          `).join('')}</div>`}
      </section>`;

      bodyEl.querySelector('#create-tag-form')?.addEventListener('submit', async (e) => {
        e.preventDefault();
        try {
          await api('/tags', 'POST', {
            name: bodyEl.querySelector('#tag-name-input')?.value?.trim(),
            color: bodyEl.querySelector('#tag-color-input')?.value || '#FF5E36',
          });
          toast('Đã tạo Tag mới.', 'success');
          await renderTagsTab();
        } catch (err) {
          toast(err.message || 'Không thể tạo Tag.', 'danger');
        }
      });

      bodyEl.querySelectorAll('.tag-filter-btn').forEach((btn) => {
        btn.addEventListener('click', () => {
          updateQuery({ tab: 'library', tag: btn.getAttribute('data-tag'), page: 1 }, { replace: false });
        });
      });
      bodyEl.querySelectorAll('.tag-delete-btn').forEach((btn) => {
        btn.addEventListener('click', () => {
          const id = btn.getAttribute('data-id');
          const name = btn.getAttribute('data-name');
          openConfirmModal({
            title: 'Xóa Tag',
            message: `Xác nhận xóa tag "${name}" khỏi hệ thống?`,
            confirmLabel: 'Xóa Tag',
            confirmClass: 'btn-danger',
            onConfirm: async () => {
              await api(`/tags/${id}`, 'DELETE');
              toast('Đã xóa Tag.', 'success');
              await renderTagsTab();
            },
          });
        });
      });
    } catch (err) {
      bodyEl.innerHTML = renderErrorState({ title: 'Không tải được danh sách Tag', message: err.message });
    }
  }

  async function renderSupabaseTab() {
    if (pasteCleanup) { pasteCleanup(); pasteCleanup = null; }
    root.querySelector('#media-sync-supabase-btn').onclick = () => runSupabaseSync(renderSupabaseTab);
    root.querySelector('#media-import-url-btn').onclick = async () => {
      const collections = await loadAllCollections();
      openUrlImportModal(collections, renderSupabaseTab);
    };
    root.querySelector('#media-trigger-upload-btn').onclick = () => updateQuery({ tab: 'library' }, { replace: false });

    try {
      const res = await api(`/admin/storage/supabase-objects${buildQuery({ prefix, q })}`);
      const data = res.data || {};
      const folders = data.folders || [];
      const objects = data.objects || [];
      const statusLabels = {
        SYNCED: { kind: 'ACTIVE', text: 'Đã đồng bộ' },
        VARIANT: { kind: 'INFO', text: 'Bản thu nhỏ' },
        MEDIA_ONLY: { kind: 'WARN', text: 'Chưa đồng bộ' },
        ORPHAN: { kind: 'DANGER', text: 'File mồ côi' },
      };

      const kpiHtml = `<section class="media-kpi-strip">
        <article class="kpi-card">
          <div class="kpi-label">Bucket Supabase</div>
          <div class="kpi-value" style="font-size:18px">${esc(data.bucket || 'meta-gym-media')}</div>
        </article>
        <article class="kpi-card">
          <div class="kpi-label">Tổng tệp đang lưu</div>
          <div class="kpi-value tabular">${Number(data.totalObjects || 0)}</div>
        </article>
        <article class="kpi-card">
          <div class="kpi-label">Tổng dung lượng thật</div>
          <div class="kpi-value tabular">${formatBytes(data.totalBytes || 0)}</div>
        </article>
        <article class="kpi-card">
          <div class="kpi-label">File mồ côi</div>
          <div class="kpi-value tabular">${Number(data.orphanCount || 0)}</div>
        </article>
      </section>`;

      const folderChipsHtml = folders.length
        ? `<div class="d-flex flex-wrap gap-2 mb-3">
            <button type="button" class="btn ${!prefix ? 'btn-primary' : 'btn-graphite'} btn-xs sb-prefix-btn" data-prefix="">Tất cả thư mục (${Number(data.totalObjects || 0)})</button>
            ${folders.map((f) => `<button type="button" class="btn ${prefix === f.folder ? 'btn-primary' : 'btn-graphite'} btn-xs sb-prefix-btn" data-prefix="${esc(f.folder === '(Gốc bucket)' ? '' : f.folder)}">${icon('folder', 13)} ${esc(f.folder)} · ${Number(f.fileCount)} (${formatBytes(f.totalBytes)})</button>`).join('')}
          </div>`
        : '';

      const filterHtml = `<form class="filter-bar mb-3" id="sb-filter-form">
        <input type="search" id="sb-q" class="form-control filter-grow" placeholder="Tìm đường dẫn file, phân hệ hoặc chủ sở hữu…" value="${esc(q)}" aria-label="Tìm tệp Supabase" />
        <button type="button" class="btn btn-primary btn-sm" id="sb-sync-now">${icon('refresh', 15)} Đồng bộ về Thư viện</button>
        ${(prefix || q) ? '<button type="button" class="btn btn-ghost btn-sm" id="sb-clear">Xóa lọc</button>' : ''}
      </form>`;

      const tableHtml = !objects.length
        ? renderEmptyState({
            title: 'Không có tệp nào trên Supabase Storage',
            message: prefix || q ? 'Không có tệp nào khớp điều kiện lọc.' : 'Bucket chưa có tệp ảnh nào.',
          })
        : `<div class="meta-card p-0 overflow-hidden"><div class="table-responsive"><table class="table table-hover align-middle mb-0">
            <thead><tr>
              <th>Xem trước</th>
              <th>Đường dẫn trên Supabase</th>
              <th>Phân hệ / Chủ sở hữu</th>
              <th>Dung lượng</th>
              <th>Trạng thái</th>
              <th>Thao tác</th>
            </tr></thead>
            <tbody>${objects.map((obj) => {
              const st = statusLabels[obj.syncStatus] || { kind: 'HIDDEN', text: obj.syncStatus };
              return `<tr>
                <td>${obj.thumbnailUrl
                  ? `<img class="media-list-thumb" src="${esc(resolveAssetUrl(obj.thumbnailUrl))}" alt="${esc(obj.name)}" loading="lazy" decoding="async" />`
                  : `<span class="meta-avatar">${icon('image', 16)}</span>`}</td>
                <td>
                  <div class="fw-semibold text-break" style="font-size:13px"><code>${esc(obj.key)}</code></div>
                  <div class="text-secondary" style="font-size:12px">${esc(obj.mimeType || 'image/webp')} · ${obj.createdAt ? formatDateTimeVN(obj.createdAt) : '—'}</div>
                </td>
                <td>
                  <div>${esc(obj.domainLabel || '—')}</div>
                  <div class="text-secondary" style="font-size:12px">${esc(obj.ownerName || 'Hệ thống')}</div>
                </td>
                <td class="tabular">${formatBytes(obj.sizeBytes)}</td>
                <td>${statusBadge(st.kind, st.text)}</td>
                <td>
                  <div class="d-flex gap-1">
                    ${obj.imageId ? `<button type="button" class="btn btn-graphite btn-icon btn-xs sb-view-img" data-id="${esc(obj.imageId)}" title="Chi tiết trong thư viện">${icon('eye', 14)}</button>` : ''}
                    ${obj.syncStatus === 'ORPHAN' ? `<button type="button" class="btn btn-graphite btn-icon btn-xs text-danger sb-delete-orphan" data-key="${esc(obj.key)}" title="Xóa file mồ côi">${icon('trash', 14)}</button>` : ''}
                  </div>
                </td>
              </tr>`;
            }).join('')}</tbody>
          </table></div></div>`;

      bodyEl.innerHTML = `${kpiHtml}${folderChipsHtml}${filterHtml}${tableHtml}`;

      bodyEl.querySelectorAll('.sb-prefix-btn').forEach((btn) => {
        btn.addEventListener('click', () => updateQuery({ tab: 'supabase', prefix: btn.getAttribute('data-prefix') || '', page: 1 }));
      });
      const sbQ = bodyEl.querySelector('#sb-q');
      sbQ?.addEventListener('input', debounce(() => updateQuery({ tab: 'supabase', q: sbQ.value.trim(), page: 1 })));
      bodyEl.querySelector('#sb-clear')?.addEventListener('click', () => updateQuery({ tab: 'supabase', prefix: '', q: '', page: 1 }));
      bodyEl.querySelector('#sb-sync-now')?.addEventListener('click', () => runSupabaseSync(renderSupabaseTab));

      bodyEl.querySelectorAll('.sb-view-img').forEach((btn) => {
        btn.addEventListener('click', async () => {
          const collections = await loadAllCollections();
          const folderOptions = flattenFolderOptions(collections.folderTree);
          await openImageDetailDrawer(btn.getAttribute('data-id'), { folderOptions, onChanged: renderSupabaseTab });
        });
      });
      bodyEl.querySelectorAll('.sb-delete-orphan').forEach((btn) => {
        btn.addEventListener('click', () => {
          const key = btn.getAttribute('data-key');
          openConfirmModal({
            title: 'Xóa file mồ côi trên Supabase',
            message: `Xác nhận xóa vĩnh viễn tệp "${key}" khỏi bucket?`,
            confirmLabel: 'Xóa tệp',
            confirmClass: 'btn-danger',
            onConfirm: async () => {
              await api('/admin/storage/cleanup-orphans', 'POST', { keys: [key] });
              toast('Đã xóa tệp mồ côi trên Supabase Storage.', 'success');
              await renderSupabaseTab();
            },
          });
        });
      });
    } catch (err) {
      bodyEl.innerHTML = renderErrorState({ title: 'Không tải được dữ liệu Supabase Storage', message: err.message });
    }
  }

  root.querySelector('#media-sync-supabase-btn').onclick = () => runSupabaseSync(tab === 'supabase' ? renderSupabaseTab : renderLibraryTab);

  if (tab === 'collections') await renderCollectionsTab();
  else if (tab === 'tags') await renderTagsTab();
  else if (tab === 'supabase') await renderSupabaseTab();
  else await renderLibraryTab();
}
