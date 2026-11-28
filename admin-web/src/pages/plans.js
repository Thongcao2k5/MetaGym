import { api, buildQuery, getApiBaseUrl, uploadRaw } from '../services/api.js';
import {
  debounce,
  esc,
  formatDateTimeVN,
  formatDateVN,
  fromDateTimeLocalVN,
  initials,
  statusBadge,
  toDateTimeLocalVN,
  vnd,
} from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderActionButton } from '../components/action-button.js';
import { bindDataTableSelection, renderDataTable } from '../components/data-table.js';
import { exportToExcel } from '../components/export.js';
import { openImageViewer } from '../components/image-viewer.js';
import { openModal } from '../components/modal.js';
import { bindPagination, renderPagination } from '../components/pagination.js';
import {
  renderBanner,
  renderEmptyState,
  renderErrorState,
  renderFilterEmptyState,
  renderTableSkeleton,
} from '../components/states.js';
import { notice, toast } from '../components/toast.js';
import { updateQuery } from '../state/router.js';

const SNAPSHOT_BANNER_TEXT = 'Thay đổi chỉ áp dụng cho giao dịch mới; gói đã mua giữ nguyên snapshot về giá bán và số ngày hiệu lực.';
const MAX_CARD_IMAGE_BYTES = 5 * 1024 * 1024;
const ALLOWED_CARD_IMAGE_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);
const CARD_TIER_LABELS = {
  BRONZE: 'Hạng Đồng',
  SILVER: 'Hạng Bạc',
  GOLD: 'Hạng Vàng',
  DIAMOND: 'Hạng Kim Cương',
};

function resolvePlanMediaUrl(pathOrId, { thumb = false } = {}) {
  if (!pathOrId) return '';
  const base = getApiBaseUrl();
  if (typeof pathOrId === 'string' && pathOrId.startsWith('/api/v1')) {
    return `${base}${pathOrId.slice('/api/v1'.length)}`;
  }
  if (typeof pathOrId === 'string' && (pathOrId.startsWith('http://') || pathOrId.startsWith('https://') || pathOrId.startsWith('/'))) {
    return pathOrId;
  }
  return `${base}/media/public/${encodeURIComponent(pathOrId)}${thumb ? `?size=120&v=${encodeURIComponent(pathOrId)}` : `?v=${encodeURIComponent(pathOrId)}`}`;
}

function tierBadgeHtml(tier) {
  if (!tier || !CARD_TIER_LABELS[tier]) return '';
  const cls = `plan-tier-badge plan-tier-${tier.toLowerCase()}`;
  return `<span class="${cls}">${esc(CARD_TIER_LABELS[tier])}</span>`;
}

function renderSaleWindowCell(row) {
  const start = row.salesStartAt ? formatDateTimeVN(row.salesStartAt) : null;
  const end = row.salesEndAt ? formatDateTimeVN(row.salesEndAt) : null;
  const nowMs = Date.now();
  const startMs = row.salesStartAt ? Date.parse(row.salesStartAt) : null;
  const endMs = row.salesEndAt ? Date.parse(row.salesEndAt) : null;

  let phase = row.salePhase;
  if (!phase) {
    if (row.status !== 'ACTIVE') phase = 'INACTIVE';
    else if (Number.isFinite(startMs) && nowMs < startMs) phase = 'UPCOMING';
    else if (Number.isFinite(endMs) && nowMs > endMs) phase = 'ENDED';
    else phase = 'ON_SALE';
  }

  let badge = statusBadge('ACTIVE', 'Đang bán');
  if (phase === 'INACTIVE') badge = statusBadge('INACTIVE', 'Ngừng bán');
  else if (phase === 'UPCOMING') badge = statusBadge('SCHEDULED', 'Sắp mở bán');
  else if (phase === 'ENDED') badge = statusBadge('EXPIRED', 'Hết đợt mở bán');
  else if (start || end) badge = statusBadge('ACTIVE', 'Đang mở bán');

  let rangeText = 'Không giới hạn đợt';
  if (start && end) rangeText = `${start} → ${end}`;
  else if (start) rangeText = `Từ ${start}`;
  else if (end) rangeText = `Đến ${end}`;

  return `${badge}<span class="person-sub tabular">${esc(rangeText)}</span>`;
}

function openPlanCardsModal(plan) {
  const frontFull = resolvePlanMediaUrl(plan.frontImageUrl || plan.frontMediaId);
  const backFull = resolvePlanMediaUrl(plan.backImageUrl || plan.backMediaId);
  const highlights = Array.isArray(plan.cardHighlights) ? plan.cardHighlights.filter(Boolean).slice(0, 3) : [];
  const tierLabel = CARD_TIER_LABELS[plan.cardTier] || 'Thẻ hội viên';
  const tierAttr = plan.cardTier ? ` data-tier="${esc(plan.cardTier.toLowerCase())}"` : '';

  openModal({
    maxWidth: '820px',
    title: `${plan.name} — ${tierLabel}`,
    subtitle: `${plan.durationDays} ngày · ${vnd(plan.price)}`,
    bodyHtml: `<div class="meta-modal-body"${tierAttr}>
      <div class="plan-card-showcase-stage"${tierAttr}>
        <div class="plan-card-showcase-top">
          <div class="plan-showcase-identity">
            ${tierBadgeHtml(plan.cardTier)}
            <span class="plan-showcase-metric tabular">${esc(plan.durationDays)} ngày · ${vnd(plan.price)}</span>
          </div>
          <span class="plan-showcase-hint">${icon('zoomIn', 14)} Bấm vào mặt thẻ để phóng to</span>
        </div>
        <div class="plan-card-duo-preview">
          <div class="plan-card-face-box is-front">
            <div class="plan-card-face-frame is-front"${tierAttr}>
              ${frontFull
                ? `<img src="${esc(frontFull)}" alt="${esc(plan.name)} — Mặt trước" class="plan-card-full-img is-front" data-zoom-src="${esc(frontFull)}" data-zoom-title="${esc(plan.name)} — Mặt trước" />`
                : `<div class="plan-card-empty-box is-front">Chưa có ảnh mặt trước</div>`}
            </div>
            <div class="plan-card-face-label">Mặt trước (Dọc)</div>
          </div>
          <div class="plan-card-face-box is-back">
            <div class="plan-card-face-frame is-back"${tierAttr}>
              ${backFull
                ? `<img src="${esc(backFull)}" alt="${esc(plan.name)} — Mặt sau" class="plan-card-full-img is-back" data-zoom-src="${esc(backFull)}" data-zoom-title="${esc(plan.name)} — Mặt sau" />`
                : `<div class="plan-card-empty-box is-back">Chưa có ảnh mặt sau</div>`}
            </div>
            <div class="plan-card-face-label">Mặt sau (Ngang)</div>
          </div>
        </div>
      </div>
      ${highlights.length ? `<div class="modal-section-card mt-3">
        <div class="meta-form-section-title mb-2">Thông tin nổi bật (3 dòng)</div>
        <ul class="plan-card-highlights is-modal">
          ${highlights.map((line) => `<li>${esc(line)}</li>`).join('')}
        </ul>
      </div>` : ''}
    </div>
    <div class="meta-modal-footer">
      <button type="button" class="btn btn-ghost" data-close-modal>Đóng</button>
    </div>`,
    onMount(ctrl) {
      ctrl.dialog.querySelectorAll('[data-zoom-src]').forEach((img) => {
        img.onclick = () => openImageViewer({
          src: img.getAttribute('data-zoom-src'),
          title: img.getAttribute('data-zoom-title') || plan.name,
        });
      });
    },
  });
}

function openGymPlanModal(row, onSaved) {
  let currentTier = row?.cardTier || '';
  let currentFrontMediaId = row?.frontMediaId || null;
  let currentBackMediaId = row?.backMediaId || null;
  let currentFrontPreview = resolvePlanMediaUrl(row?.frontThumbnailUrl || row?.frontImageUrl || currentFrontMediaId, { thumb: !row?.frontThumbnailUrl });
  let currentBackPreview = resolvePlanMediaUrl(row?.backThumbnailUrl || row?.backImageUrl || currentBackMediaId, { thumb: !row?.backThumbnailUrl });
  let currentFrontFull = resolvePlanMediaUrl(row?.frontImageUrl || currentFrontMediaId);
  let currentBackFull = resolvePlanMediaUrl(row?.backImageUrl || currentBackMediaId);
  const initialHighlights = Array.isArray(row?.cardHighlights) ? row.cardHighlights : [];

  const renderSlotBody = (side) => {
    const isFront = side === 'front';
    const mediaId = isFront ? currentFrontMediaId : currentBackMediaId;
    const previewUrl = isFront ? currentFrontPreview : currentBackPreview;
    const fullUrl = isFront ? currentFrontFull : currentBackFull;
    const label = isFront ? 'Mặt trước (Dọc)' : 'Mặt sau (Ngang)';
    const specHint = isFront ? 'Tỷ lệ đứng 900×1426' : 'Tỷ lệ ngang 1426×900';
    const tierAttr = currentTier ? ` data-tier="${esc(currentTier.toLowerCase())}"` : '';
    return `<div class="plan-card-slot-row">
        <div class="plan-card-slot-stage ${isFront ? 'is-front' : 'is-back'}"${tierAttr}>
          ${previewUrl
            ? `<img src="${esc(previewUrl)}" alt="${esc(label)}" class="plan-card-slot-img" data-slot-zoom="${side}" data-full-src="${esc(fullUrl || previewUrl)}" />
               <span class="plan-card-slot-zoom-chip" aria-hidden="true">${icon('zoomIn', 12)}</span>`
            : `<span class="plan-card-slot-placeholder">${icon('image', 18)}</span>`}
        </div>
        <div class="plan-card-slot-meta">
          <div class="plan-card-slot-head">
            <span>${label}</span>
            ${mediaId ? '<span class="meta-badge meta-badge-success">Đã gắn</span>' : '<span class="meta-badge">Chưa có</span>'}
          </div>
          <span class="field-hint" style="font-size:11.5px">${specHint}</span>
          <div class="plan-card-slot-actions">
            <button type="button" class="btn btn-graphite btn-sm" data-slot-upload="${side}">${icon('upload', 14)} ${mediaId ? 'Đổi ảnh' : 'Tải ảnh'}</button>
            ${mediaId ? `<button type="button" class="btn btn-ghost btn-sm text-danger" data-slot-remove="${side}">${icon('trash', 14)} Gỡ</button>` : ''}
          </div>
        </div>
      </div>`;
  };

  openModal({
    maxWidth: '900px',
    title: row ? `Sửa gói Gym: ${row.name}` : 'Tạo gói Gym mới',
    subtitle: 'Quản lý giá, thời hạn, hình ảnh thẻ 2 mặt (WebP) và 3 dòng thông tin thẻ',
    bodyHtml: `<form id="plan-form" novalidate>
      <div class="meta-modal-body">
        ${renderBanner({
          kind: 'info',
          iconName: 'info',
          title: 'Quy tắc Snapshot gói Gym',
          text: SNAPSHOT_BANNER_TEXT,
        })}
        <div class="meta-modal-horizontal-layout">
          <div class="modal-col-left">
            <div class="field">
              <label class="field-label" for="plan-tier">Hạng thẻ hội viên</label>
              <select id="plan-tier" class="form-select" name="cardTier">
                <option value="" ${!currentTier ? 'selected' : ''}>-- Chưa gắn hạng thẻ --</option>
                ${Object.entries(CARD_TIER_LABELS).map(([k, v]) => `<option value="${k}" ${currentTier === k ? 'selected' : ''}>${v}</option>`).join('')}
              </select>
            </div>
            <div class="plan-card-slots">
              <div class="plan-card-slot" id="plan-slot-front">${renderSlotBody('front')}</div>
              <div class="plan-card-slot" id="plan-slot-back">${renderSlotBody('back')}</div>
            </div>
            <input type="file" id="plan-card-file-input" accept="image/jpeg,image/png,image/webp" hidden />
            <span class="field-hint">JPEG, PNG hoặc WebP tối đa 5 MB · Tự nén WebP + thumbnail.</span>
            <span class="field-error" id="plan-card-upload-error" aria-live="polite"></span>
          </div>

          <div class="modal-col-right">
            <div class="field">
              <label class="field-label" for="plan-name">Tên gói Gym</label>
              <input id="plan-name" class="form-control" name="name" maxlength="100" value="${esc(row?.name || '')}" placeholder="Ví dụ: Gói Gym 90 ngày" required />
            </div>
            <div class="grid-2">
              <div class="field">
                <label class="field-label" for="plan-days">Số ngày hiệu lực (1–3650)</label>
                <input id="plan-days" class="form-control tabular" name="durationDays" type="number" min="1" max="3650" step="1" value="${esc(row?.durationDays ?? 30)}" required />
              </div>
              <div class="field">
                <label class="field-label" for="plan-price">Giá bán (VND)</label>
                <input id="plan-price" class="form-control tabular" name="price" type="number" min="0" step="1" value="${esc(row?.price ?? '')}" placeholder="650000" required />
              </div>
            </div>
            <div class="field">
              <label class="field-label" for="plan-status">Trạng thái mở bán</label>
              <select id="plan-status" class="form-select" name="status">
                <option value="ACTIVE" ${row?.status !== 'INACTIVE' ? 'selected' : ''}>Đang bán</option>
                <option value="INACTIVE" ${row?.status === 'INACTIVE' ? 'selected' : ''}>Ngừng bán</option>
              </select>
            </div>
            <div class="field">
              <span class="field-label">
                <span>Thời gian mở bán (GMT+7)</span>
                <button type="button" class="btn-link-plain" id="plan-clear-sale-window" style="font-size:12px">Luôn mở bán</button>
              </span>
              <div class="grid-2">
                <div class="field">
                  <label class="field-hint" for="plan-sales-start">Mở bán từ</label>
                  <input id="plan-sales-start" class="form-control tabular" name="salesStartAt" type="datetime-local" value="${esc(toDateTimeLocalVN(row?.salesStartAt))}" />
                </div>
                <div class="field">
                  <label class="field-hint" for="plan-sales-end">Kết thúc mở bán</label>
                  <input id="plan-sales-end" class="form-control tabular" name="salesEndAt" type="datetime-local" value="${esc(toDateTimeLocalVN(row?.salesEndAt))}" />
                </div>
              </div>
              <span class="field-hint">Để trống cả 2 ô nếu mở bán không giới hạn thời gian; có hạn thì chỉ mua được trong đợt.</span>
            </div>
            <div class="field">
              <span class="field-label">Thông tin thẻ (tối đa 3 dòng ngắn gọn)</span>
              <input id="plan-hl-1" class="form-control" name="highlight1" maxlength="120" value="${esc(initialHighlights[0] || '')}" placeholder="Dòng 1: Quyền lợi thẻ & khu vực tập…" />
              <input id="plan-hl-2" class="form-control" name="highlight2" maxlength="120" value="${esc(initialHighlights[1] || '')}" placeholder="Dòng 2: Đo InBody & tư vấn lộ trình…" />
              <input id="plan-hl-3" class="form-control" name="highlight3" maxlength="120" value="${esc(initialHighlights[2] || '')}" placeholder="Dòng 3: Ưu đãi Coach & điểm thưởng…" />
            </div>
            <div class="field">
              <label class="field-label" for="plan-desc">Mô tả bổ sung</label>
              <textarea id="plan-desc" class="form-control" name="description" maxlength="1000" placeholder="Quyền lợi và ghi chú gói Gym…">${esc(row?.description || '')}</textarea>
            </div>
          </div>
        </div>
      </div>
      <div class="meta-modal-footer">
        <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
        <button type="submit" class="btn btn-primary" data-modal-submit>${icon('check', 16)} ${row ? 'Lưu thay đổi' : 'Tạo gói Gym'}</button>
      </div>
    </form>`,
    onMount(ctrl) {
      const form = ctrl.dialog.querySelector('#plan-form');
      const fileInput = form.querySelector('#plan-card-file-input');
      const uploadErr = form.querySelector('#plan-card-upload-error');
      const tierSelect = form.querySelector('[name="cardTier"]');
      let activeUploadSide = 'front';
      let uploading = false;

      if (tierSelect) {
        tierSelect.onchange = () => {
          currentTier = tierSelect.value || '';
          bindSlotEvents('front');
          bindSlotEvents('back');
        };
      }

      const clearSaleBtn = form.querySelector('#plan-clear-sale-window');
      if (clearSaleBtn) {
        clearSaleBtn.onclick = () => {
          const sEl = form.querySelector('[name="salesStartAt"]');
          const eEl = form.querySelector('[name="salesEndAt"]');
          if (sEl) sEl.value = '';
          if (eEl) eEl.value = '';
        };
      }

      const bindSlotEvents = (side) => {
        const slotEl = form.querySelector(`#plan-slot-${side}`);
        if (!slotEl) return;
        slotEl.innerHTML = renderSlotBody(side);

        const zoomImg = slotEl.querySelector(`[data-slot-zoom="${side}"]`);
        if (zoomImg) {
          zoomImg.onclick = () => openImageViewer({
            src: zoomImg.getAttribute('data-full-src'),
            title: `${form.querySelector('[name="name"]')?.value?.trim() || row?.name || 'Thẻ gói Gym'} — ${side === 'front' ? 'Mặt trước' : 'Mặt sau'}`,
          });
        }

        const upBtn = slotEl.querySelector(`[data-slot-upload="${side}"]`);
        if (upBtn) {
          upBtn.onclick = () => {
            if (uploading) return;
            activeUploadSide = side;
            if (uploadErr) uploadErr.textContent = '';
            fileInput?.click();
          };
        }

        const rmBtn = slotEl.querySelector(`[data-slot-remove="${side}"]`);
        if (rmBtn) {
          rmBtn.onclick = () => {
            if (side === 'front') {
              currentFrontMediaId = null;
              currentFrontPreview = '';
              currentFrontFull = '';
            } else {
              currentBackMediaId = null;
              currentBackPreview = '';
              currentBackFull = '';
            }
            bindSlotEvents(side);
          };
        }
      };

      bindSlotEvents('front');
      bindSlotEvents('back');

      if (fileInput) {
        fileInput.onchange = async () => {
          const file = fileInput.files?.[0];
          fileInput.value = '';
          if (!file) return;
          if (uploadErr) uploadErr.textContent = '';
          const mimeType = String(file.type || '').toLowerCase();
          if (!ALLOWED_CARD_IMAGE_TYPES.has(mimeType)) {
            if (uploadErr) uploadErr.textContent = 'Chỉ hỗ trợ ảnh JPEG, PNG hoặc WebP.';
            return;
          }
          if (Number(file.size || 0) > MAX_CARD_IMAGE_BYTES) {
            if (uploadErr) uploadErr.textContent = 'Ảnh vượt quá giới hạn tối đa 5 MB.';
            return;
          }

          uploading = true;
          ctrl.setBusy(true);
          try {
            const uploaded = await uploadRaw('/media/images', file, mimeType, {
              headers: {
                'x-image-purpose': 'PACKAGE',
                'x-file-name': encodeURIComponent(file.name || `card-${activeUploadSide}`).slice(0, 200),
              },
            });
            const mediaId = uploaded?.data?.id;
            if (!mediaId) throw new Error('Máy chủ không trả về mã ảnh hợp lệ.');
            const thumbUrl = resolvePlanMediaUrl(uploaded?.data?.thumbnailUrl || mediaId, { thumb: true });
            const fullUrl = resolvePlanMediaUrl(uploaded?.data?.publicUrl || mediaId);
            if (activeUploadSide === 'front') {
              currentFrontMediaId = mediaId;
              currentFrontPreview = thumbUrl;
              currentFrontFull = fullUrl;
            } else {
              currentBackMediaId = mediaId;
              currentBackPreview = thumbUrl;
              currentBackFull = fullUrl;
            }
            bindSlotEvents(activeUploadSide);
            toast('Đã tải ảnh thẻ lên và nén WebP.', 'success');
          } catch (err) {
            if (uploadErr) uploadErr.textContent = err.message || 'Không thể tải ảnh thẻ.';
          } finally {
            uploading = false;
            ctrl.setBusy(false);
          }
        };
      }

      form.onsubmit = async (event) => {
        event.preventDefault();
        if (uploading) return;
        ctrl.showError('');
        const name = (form.querySelector('[name="name"]')?.value || '').trim();
        const description = (form.querySelector('[name="description"]')?.value || '').trim() || null;
        const durationDays = Number(form.querySelector('[name="durationDays"]')?.value);
        const priceRaw = form.querySelector('[name="price"]')?.value;
        const price = Number(priceRaw);
        const status = form.querySelector('[name="status"]')?.value || 'ACTIVE';
        const salesStartRaw = form.querySelector('[name="salesStartAt"]')?.value || '';
        const salesEndRaw = form.querySelector('[name="salesEndAt"]')?.value || '';
        const salesStartAt = fromDateTimeLocalVN(salesStartRaw);
        const salesEndAt = fromDateTimeLocalVN(salesEndRaw);
        const cardTier = (form.querySelector('[name="cardTier"]')?.value || '').trim() || null;
        const cardHighlights = [
          form.querySelector('[name="highlight1"]')?.value,
          form.querySelector('[name="highlight2"]')?.value,
          form.querySelector('[name="highlight3"]')?.value,
        ].map((line) => String(line || '').trim()).filter(Boolean).slice(0, 3);

        if (!name || name.length > 100) {
          ctrl.showError('Tên gói Gym phải có từ 1 đến 100 ký tự.');
          return;
        }
        if (!Number.isInteger(durationDays) || durationDays < 1 || durationDays > 3650) {
          ctrl.showError('Số ngày hiệu lực phải là số nguyên từ 1 đến 3650.');
          return;
        }
        if (priceRaw === '' || !Number.isInteger(price) || price < 0) {
          ctrl.showError('Giá bán phải là số nguyên lớn hơn hoặc bằng 0.');
          return;
        }
        if (salesStartAt && salesEndAt && Date.parse(salesEndAt) < Date.parse(salesStartAt)) {
          ctrl.showError('Thời điểm kết thúc mở bán phải sau hoặc bằng thời điểm bắt đầu.');
          return;
        }

        const payload = { name, description, price, durationDays, status };
        const initialTier = row?.cardTier ?? null;
        const initialFront = row?.frontMediaId ?? null;
        const initialBack = row?.backMediaId ?? null;
        const initialSalesStart = row?.salesStartAt ? new Date(row.salesStartAt).toISOString() : null;
        const initialSalesEnd = row?.salesEndAt ? new Date(row.salesEndAt).toISOString() : null;
        const initialHlKey = JSON.stringify(initialHighlights);
        const nextHlKey = JSON.stringify(cardHighlights);

        if (salesStartAt !== initialSalesStart || salesStartAt !== null) {
          payload.salesStartAt = salesStartAt;
        }
        if (salesEndAt !== initialSalesEnd || salesEndAt !== null) {
          payload.salesEndAt = salesEndAt;
        }
        if (cardTier !== initialTier || cardTier !== null) {
          payload.cardTier = cardTier;
        }
        if (currentFrontMediaId !== initialFront || currentFrontMediaId !== null) {
          payload.frontMediaId = currentFrontMediaId;
        }
        if (currentBackMediaId !== initialBack || currentBackMediaId !== null) {
          payload.backMediaId = currentBackMediaId;
        }
        if (nextHlKey !== initialHlKey || cardHighlights.length > 0) {
          payload.cardHighlights = cardHighlights;
        }

        ctrl.setBusy(true);
        try {
          await api(
            row ? `/admin/membership-plans/${encodeURIComponent(row.id)}` : '/admin/membership-plans',
            row ? 'PATCH' : 'POST',
            payload,
          );
          ctrl.close();
          await onSaved();
          notice(row
            ? 'Đã cập nhật gói Gym. Thay đổi chỉ áp dụng cho giao dịch mới.'
            : 'Đã tạo gói Gym mới.');
        } catch (error) {
          ctrl.setBusy(false);
          ctrl.showError(error.message);
        }
      };
    },
  });
}

export async function renderPlansPage({ root, params, shell }) {
  const tab = params?.get('tab') === 'entitlements' ? 'entitlements' : 'catalog';
  const section = tab === 'entitlements' ? 'plan-entitlements' : 'plans';
  const search = params?.get('search') || '';
  const statusFilter = params?.get('status') || '';
  const page = Math.max(1, Number(params?.get('page')) || 1);
  const pageSize = Math.max(1, Number(params?.get('pageSize')) || 10);
  const hasFilter = Boolean(search || statusFilter);

  const snapshotBannerHtml = renderBanner({
    kind: 'info',
    iconName: 'info',
    title: 'Quy tắc Snapshot gói Gym',
    text: SNAPSHOT_BANNER_TEXT,
  });

  const buildFilterHtml = (canExport = false) => (tab === 'catalog'
    ? `<form class="filter-bar" id="plans-filter-form">
      <input type="search" id="plans-search" class="form-control filter-grow" placeholder="Tìm tên hoặc mô tả gói Gym…" value="${esc(search)}" aria-label="Tìm gói Gym" />
      <select id="plans-status" class="form-select filter-fixed" aria-label="Lọc trạng thái gói Gym">
        <option value="" ${!statusFilter ? 'selected' : ''}>Tất cả trạng thái</option>
        <option value="ACTIVE" ${statusFilter === 'ACTIVE' ? 'selected' : ''}>Đang bán (ACTIVE)</option>
        <option value="INACTIVE" ${statusFilter === 'INACTIVE' ? 'selected' : ''}>Ngừng bán (INACTIVE)</option>
      </select>
      ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm" id="plans-clear">Xóa bộ lọc</button>' : ''}
      <button type="button" class="btn btn-graphite btn-sm" id="plans-export-excel" ${canExport ? '' : 'disabled'}>
        ${icon('download', 16)} <span id="plans-export-label">Xuất Excel</span>
      </button>
    </form>`
    : `<form class="filter-bar" id="plans-filter-form">
      <input type="search" id="plans-search" class="form-control filter-grow" placeholder="Tìm theo tên hội viên, email hoặc tên gói…" value="${esc(search)}" aria-label="Tìm quyền sử dụng gói Gym" />
      <select id="plans-status" class="form-select filter-fixed" aria-label="Lọc trạng thái quyền sử dụng">
        <option value="" ${!statusFilter ? 'selected' : ''}>Tất cả trạng thái</option>
        <option value="ACTIVE" ${statusFilter === 'ACTIVE' ? 'selected' : ''}>ACTIVE · Đang hiệu lực</option>
        <option value="SCHEDULED" ${statusFilter === 'SCHEDULED' ? 'selected' : ''}>SCHEDULED · Đã xếp lịch</option>
        <option value="EXPIRED" ${statusFilter === 'EXPIRED' ? 'selected' : ''}>EXPIRED · Hết hạn</option>
        <option value="CANCELLED" ${statusFilter === 'CANCELLED' ? 'selected' : ''}>CANCELLED · Đã hủy</option>
      </select>
      ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm" id="plans-clear">Xóa bộ lọc</button>' : ''}
      <button type="button" class="btn btn-graphite btn-sm" id="plans-export-excel" ${canExport ? '' : 'disabled'}>
        ${icon('download', 16)} <span id="plans-export-label">Xuất Excel</span>
      </button>
    </form>`);

  const topbarActionsHtml = tab === 'catalog'
    ? `<button type="button" class="btn btn-primary" id="create-plan">${icon('plus', 16)} Tạo gói Gym</button>`
    : '';

  shell({
    section,
    topbarActionsHtml,
    contentHtml: `<div class="stack-20">${tab === 'catalog' ? snapshotBannerHtml : ''}${buildFilterHtml(false)}${renderTableSkeleton(5)}</div>`,
  });

  const reloadWith = (patch = {}) => {
    const nextTab = patch.tab !== undefined ? patch.tab : tab;
    const nextSearch = patch.search !== undefined ? patch.search : (root.querySelector('#plans-search')?.value?.trim() || '');
    const nextStatus = patch.status !== undefined ? patch.status : (root.querySelector('#plans-status')?.value || '');
    const nextPage = patch.page !== undefined ? patch.page : page;
    const nextPageSize = patch.pageSize !== undefined ? patch.pageSize : pageSize;

    const nextParams = new URLSearchParams();
    if (nextTab !== 'catalog') nextParams.set('tab', nextTab);
    if (nextSearch) nextParams.set('search', nextSearch);
    if (nextStatus) nextParams.set('status', nextStatus);
    if (nextPage > 1) nextParams.set('page', String(nextPage));
    if (nextPageSize !== 10) nextParams.set('pageSize', String(nextPageSize));

    updateQuery({
      tab: nextTab !== 'catalog' ? nextTab : null,
      search: nextSearch || null,
      status: nextStatus || null,
      page: nextPage > 1 ? nextPage : null,
      pageSize: nextPageSize !== 10 ? nextPageSize : null,
    }, { replace: true });

    return renderPlansPage({ root, params: nextParams, shell });
  };

  try {
    const endpoint = tab === 'entitlements' ? '/admin/memberships' : '/admin/membership-plans';
    const query = buildQuery({ status: statusFilter, search, page, pageSize });
    const result = await api(`${endpoint}${query}`);
    const rows = result?.data || [];
    const pagination = result?.pagination || {
      page,
      pageSize,
      totalItems: rows.length,
      totalPages: Math.max(1, Math.ceil(rows.length / pageSize)),
    };

    const tableHtml = tab === 'catalog'
      ? renderDataTable({
        columns: [
          {
            label: 'Thẻ & Tên gói Gym',
            render: (row) => {
              const frontThumb = resolvePlanMediaUrl(row.frontThumbnailUrl || row.frontImageUrl || row.frontMediaId, { thumb: !row.frontThumbnailUrl });
              const backThumb = resolvePlanMediaUrl(row.backThumbnailUrl || row.backImageUrl || row.backMediaId, { thumb: !row.backThumbnailUrl });
              const highlights = Array.isArray(row.cardHighlights) ? row.cardHighlights.filter(Boolean).slice(0, 3) : [];
              const hasCards = Boolean(frontThumb || backThumb);
              const tierAttr = row.cardTier ? ` data-tier="${esc(row.cardTier.toLowerCase())}"` : '';
              const thumbsHtml = hasCards
                ? `<button type="button" class="plan-card-thumbs ${frontThumb && backThumb ? 'is-duo' : 'is-single'} view-plan-cards" data-id="${esc(row.id)}"${tierAttr} title="Xem thẻ 2 mặt" aria-label="Xem thẻ 2 mặt ${esc(row.name)}">
                    ${frontThumb ? `<span class="plan-thumb-frame is-front"><img src="${esc(frontThumb)}" alt="${esc(row.name)} mặt trước" class="plan-card-thumb is-front" loading="lazy" decoding="async" /></span>` : ''}
                    ${backThumb ? `<span class="plan-thumb-frame is-back"><img src="${esc(backThumb)}" alt="${esc(row.name)} mặt sau" class="plan-card-thumb is-back" loading="lazy" decoding="async" /></span>` : ''}
                  </button>`
                : `<span class="meta-avatar">${icon('card', 16)}</span>`;
              const infoHtml = highlights.length
                ? `<ul class="plan-card-highlights">${highlights.map((line) => `<li>${esc(line)}</li>`).join('')}</ul>`
                : `<span class="person-sub">${esc(row.description || 'Chưa có mô tả')}</span>`;
              return `<div class="plan-catalog-cell">
                ${thumbsHtml}
                <div class="plan-catalog-info">
                  <div class="plan-catalog-title-row">
                    <span class="person-name">${esc(row.name)}</span>
                    ${tierBadgeHtml(row.cardTier)}
                  </div>
                  ${infoHtml}
                </div>
              </div>`;
            },
          },
          {
            label: 'Thời hạn',
            render: (row) => `<strong class="tabular">${esc(row.durationDays)} ngày</strong>`,
          },
          {
            label: 'Giá bán (VND)',
            align: 'right',
            render: (row) => `<strong class="tabular">${vnd(row.price)}</strong>`,
          },
          {
            label: 'Hội viên đang dùng',
            render: (row) => {
              const activeCount = Number(row.activeMembershipCount ?? 0);
              const schedCount = Number(row.scheduledMembershipCount ?? 0);
              return `<span class="tabular"><strong>${activeCount}</strong> hiệu lực</span><span class="person-sub tabular">${schedCount} đã xếp lịch</span>`;
            },
          },
          {
            label: 'Mở bán (GMT+7)',
            render: (row) => renderSaleWindowCell(row),
          },
          {
            label: 'Thao tác',
            align: 'right',
            render: (row) => `<div class="cell-actions">
              ${(row.frontMediaId || row.backMediaId || row.frontImageUrl || row.backImageUrl)
                ? renderActionButton({
                  iconName: 'eye',
                  label: 'Xem thẻ 2 mặt',
                  className: 'view-plan-cards',
                  permission: 'plans:read',
                  attrs: `data-id="${esc(row.id)}"`,
                })
                : ''}
              ${renderActionButton({
                iconName: 'edit',
                label: 'Sửa gói & thẻ',
                className: 'edit-plan',
                permission: 'plans:update',
                attrs: `data-id="${esc(row.id)}"`,
              })}
            </div>`,
          },
        ],
        rows,
        selectable: true,
        rowId: (_row, idx) => String(idx),
        emptyHtml: hasFilter
          ? renderFilterEmptyState({ resetId: 'plans-filter-reset' })
          : renderEmptyState({
            iconName: 'card',
            title: 'Chưa có gói Gym nào',
            description: 'Tạo gói Gym đầu tiên để mở bán trên ứng dụng và tại quầy lễ tân.',
            ctaLabel: 'Tạo gói Gym',
            ctaId: 'create-plan-empty',
          }),
        paginationHtml: renderPagination({ ...pagination, prefix: 'gp' }),
        ariaLabel: 'Danh mục gói Gym',
      })
      : renderDataTable({
        columns: [
          {
            label: 'Hội viên',
            render: (row) => `<div class="person-cell">
              <span class="meta-avatar">${esc(initials(row.memberName || 'M'))}</span>
              <div>
                <span class="person-name">${esc(row.memberName || 'Hội viên')}</span>
                ${row.memberEmail ? `<span class="person-sub">${esc(row.memberEmail)}</span>` : ''}
              </div>
            </div>`,
          },
          {
            label: 'Gói Gym (Snapshot)',
            render: (row) => `<span class="person-name">${esc(row.planName || 'Gói Gym')}</span>${row.amount != null ? `<span class="person-sub tabular">${vnd(row.amount)}</span>` : ''}`,
          },
          {
            label: 'Thời hạn (GMT+7)',
            render: (row) => `<span class="tabular">${formatDateVN(row.startDate)} → ${formatDateVN(row.endDate)}</span>`,
          },
          {
            label: 'Trạng thái',
            render: (row) => statusBadge(row.status),
          },
        ],
        rows,
        selectable: true,
        rowId: (_row, idx) => String(idx),
        emptyHtml: hasFilter
          ? renderFilterEmptyState({ resetId: 'plans-filter-reset' })
          : renderEmptyState({
            iconName: 'card',
            title: 'Chưa có quyền sử dụng gói Gym nào',
            description: 'Quyền sử dụng (ACTIVE / SCHEDULED / EXPIRED) sẽ xuất hiện sau khi hội viên đăng ký hoặc thanh toán tại quầy.',
          }),
        paginationHtml: renderPagination({ ...pagination, prefix: 'ge' }),
        ariaLabel: 'Quyền sử dụng gói Gym',
      });

    const contentHtml = `<div class="stack-20">
      ${tab === 'catalog' ? snapshotBannerHtml : ''}
      ${buildFilterHtml(rows.length > 0)}
      ${tableHtml}
    </div>`;

    shell({
      section,
      contentHtml,
      topbarActionsHtml,
    });

    const debouncedSearch = debounce(() => reloadWith({ page: 1 }), 280);
    const searchInput = root.querySelector('#plans-search');
    if (searchInput) searchInput.oninput = debouncedSearch;

    const filterForm = root.querySelector('#plans-filter-form');
    if (filterForm) {
      filterForm.onsubmit = (ev) => {
        ev.preventDefault();
        debouncedSearch.cancel();
        reloadWith({ page: 1 });
      };
    }

    const statusSelect = root.querySelector('#plans-status');
    if (statusSelect) statusSelect.onchange = () => reloadWith({ page: 1 });

    [root.querySelector('#plans-clear'), root.querySelector('#plans-filter-reset')].filter(Boolean).forEach((btn) => {
      btn.onclick = () => reloadWith({ search: '', status: '', page: 1 });
    });

    bindPagination(root, {
      page: pagination.page,
      totalPages: pagination.totalPages,
      prefix: tab === 'catalog' ? 'gp' : 'ge',
      onChange: (nextPage) => reloadWith({ page: nextPage }),
      onPageSizeChange: (nextSize) => reloadWith({ pageSize: nextSize, page: 1 }),
    });

    const exportLabel = root.querySelector('#plans-export-label');
    const getSelectedIndices = bindDataTableSelection(root, {
      onSelectionChange: (ids) => {
        if (exportLabel) {
          exportLabel.textContent = ids.length > 0 ? `Xuất Excel (${ids.length})` : 'Xuất Excel';
        }
      },
    });

    const exportBtn = root.querySelector('#plans-export-excel');
    if (exportBtn) {
      exportBtn.onclick = () => {
        const selected = getSelectedIndices();
        const targetRows = selected.length > 0
          ? selected.map((idx) => rows[Number(idx)]).filter(Boolean)
          : rows;
        if (!targetRows.length) {
          toast('Chưa có dữ liệu để xuất Excel.', 'warn');
          return;
        }
        const ok = tab === 'catalog'
          ? exportToExcel({
            filename: 'metagym-gym-plans.csv',
            columns: [
              { label: 'Tên gói Gym', value: (r) => r.name || '' },
              { label: 'Thời hạn (ngày)', value: (r) => r.durationDays ?? '' },
              { label: 'Giá bán (VND)', value: (r) => r.price ?? 0 },
              { label: 'Đang hiệu lực', value: (r) => r.activeMembershipCount ?? 0 },
              { label: 'Đã xếp lịch', value: (r) => r.scheduledMembershipCount ?? 0 },
              { label: 'Mở bán từ (VN)', value: (r) => (r.salesStartAt ? formatDateTimeVN(r.salesStartAt) : 'Không giới hạn') },
              { label: 'Kết thúc mở bán (VN)', value: (r) => (r.salesEndAt ? formatDateTimeVN(r.salesEndAt) : 'Không giới hạn') },
              { label: 'Trạng thái', value: (r) => r.status || '' },
            ],
            rows: targetRows,
          })
          : exportToExcel({
            filename: 'metagym-gym-memberships.csv',
            columns: [
              { label: 'Hội viên', value: (r) => r.memberName || '' },
              { label: 'Email', value: (r) => r.memberEmail || '' },
              { label: 'Gói Gym', value: (r) => r.planName || '' },
              { label: 'Ngày bắt đầu', value: (r) => formatDateVN(r.startDate) },
              { label: 'Ngày kết thúc', value: (r) => formatDateVN(r.endDate) },
              { label: 'Mở bán từ (VN)', value: (r) => (r.salesStartAt ? formatDateTimeVN(r.salesStartAt) : 'Không giới hạn') },
              { label: 'Kết thúc mở bán (VN)', value: (r) => (r.salesEndAt ? formatDateTimeVN(r.salesEndAt) : 'Không giới hạn') },
              { label: 'Trạng thái', value: (r) => r.status || '' },
            ],
            rows: targetRows,
          });
        if (ok) toast(`Đã xuất ${targetRows.length} dòng ra file Excel (.csv).`);
      };
    }

    const createBtns = [root.querySelector('#create-plan'), root.querySelector('#create-plan-empty')].filter(Boolean);
    createBtns.forEach((btn) => {
      btn.onclick = () => openGymPlanModal(null, () => reloadWith({ tab: 'catalog', page: 1 }));
    });

    root.querySelectorAll('.edit-plan').forEach((btn) => {
      btn.onclick = () => {
        const plan = rows.find((r) => r.id === btn.dataset.id);
        if (plan) openGymPlanModal(plan, () => reloadWith({ page }));
      };
    });

    root.querySelectorAll('.view-plan-cards').forEach((btn) => {
      btn.onclick = () => {
        const plan = rows.find((r) => r.id === btn.dataset.id);
        if (plan) openPlanCardsModal(plan);
      };
    });
  } catch (error) {
    shell({
      section,
      topbarActionsHtml,
      contentHtml: renderErrorState({
        title: tab === 'entitlements' ? 'Không tải được quyền sử dụng gói Gym' : 'Không tải được danh mục gói Gym',
        message: error.message,
      }),
    });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderPlansPage({ root, params, shell });
  }
}
