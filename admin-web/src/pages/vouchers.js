import { api, buildQuery, uploadRaw } from '../services/api.js';
import { debounce, esc, formatDateTimeVN, vnd } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderDataTable } from '../components/data-table.js';
import { openConfirmModal, openModal } from '../components/modal.js';
import { openImageCropper } from '../components/image-cropper.js';
import { openImageViewer } from '../components/image-viewer.js';
import { bindPagination, renderPagination } from '../components/pagination.js';
import { renderBanner, renderEmptyState, renderErrorState, renderSkeletonPage } from '../components/states.js';
import { toast } from '../components/toast.js';
import { hasPermission } from '../services/permissions.js';
import { updateQuery } from '../state/router.js';

const SCOPE_LABELS = Object.freeze({
  ALL: 'Tất cả gói (Gym & Coach)',
  GYM_PLAN: 'Chỉ gói Gym',
  COACH_PACKAGE: 'Chỉ gói Coach',
});

const MEMBER_SCOPE_LABELS = Object.freeze({
  ALL: 'Mọi hội viên',
  NEW_MEMBER: 'Hội viên mua lần đầu',
  RENEWAL: 'Hội viên gia hạn gói',
});

const PHASE_BADGE = Object.freeze({
  ACTIVE: ['meta-badge-success', 'Đang áp dụng'],
  UPCOMING: ['meta-badge-info', 'Sắp diễn ra'],
  PAUSED: ['meta-badge-warning', 'Tạm ngưng'],
  EXPIRED: ['meta-badge-neutral', 'Hết hạn'],
  DEPLETED: ['meta-badge-danger', 'Hết lượt'],
  ARCHIVED: ['meta-badge-neutral', 'Đã lưu trữ'],
});

function voucherPhaseBadge(phase) {
  const [cls, label] = PHASE_BADGE[phase] || ['meta-badge-neutral', phase || '—'];
  return `<span class="meta-badge ${cls}">${esc(label)}</span>`;
}

function isoToVnDatetimeLocal(iso) {
  if (!iso) return '';
  const ms = Date.parse(iso);
  if (!Number.isFinite(ms)) return '';
  const vn = new Date(ms + 7 * 3600000);
  return vn.toISOString().slice(0, 16);
}

function vnDatetimeLocalToIso(localStr) {
  const trimmed = String(localStr || '').trim();
  if (!trimmed) return null;
  const parsed = new Date(`${trimmed}:00+07:00`);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

function formatDiscountLabel(row) {
  if (row.discountType === 'PERCENT') {
    const cap = row.maxDiscountAmount ? ` · Tối đa ${vnd(row.maxDiscountAmount)}` : '';
    return `<strong style="color:var(--meta-primary)">-${row.discountValue}%</strong><span class="person-sub tabular">${esc(cap)}</span>`;
  }
  return `<strong style="color:var(--meta-primary)" class="tabular">-${vnd(row.discountValue)}</strong><span class="person-sub">Giảm trực tiếp</span>`;
}

export async function renderVouchersPage({ root, params, shell }) {
  const canManage = hasPermission('plans:manage');
  const statusFilter = (params?.get('status') || 'ALL').toUpperCase();
  const discountTypeFilter = (params?.get('discountType') || 'ALL').toUpperCase();
  const applyScopeFilter = (params?.get('applyScope') || 'ALL').toUpperCase();
  const searchQuery = params?.get('search') || '';
  const page = Math.max(1, Number(params?.get('page') || 1));

  shell({
    section: 'vouchers',
    topbarActionsHtml: canManage
      ? `<button type="button" class="btn btn-primary btn-sm" id="add-voucher-btn">${icon('plus', 15)} Tạo Voucher</button>`
      : '',
    contentHtml: renderSkeletonPage({ cards: 4, rows: 6 }),
  });

  const refresh = () => renderVouchersPage({ root, params, shell });

  try {
    const [voucherRes, plansRes] = await Promise.all([
      api(`/admin/vouchers${buildQuery({
        status: statusFilter,
        discountType: discountTypeFilter,
        applyScope: applyScopeFilter,
        search: searchQuery,
        page,
        pageSize: 20,
      })}`),
      api('/admin/membership-plans').catch(() => ({ data: [] })),
    ]);

    const rows = voucherRes?.data || [];
    const summary = voucherRes?.summary || {};
    const pagination = voucherRes?.pagination || { page: 1, pageSize: 20, totalItems: rows.length, totalPages: 1 };
    const gymPlans = plansRes?.data || [];

    const openVoucherModal = (existingRow = null) => {
      const isEdit = Boolean(existingRow);
      const item = existingRow || {
        code: '',
        title: '',
        description: '',
        imageMediaId: null,
        imageUrl: null,
        discountType: 'FIXED_AMOUNT',
        discountValue: 100000,
        maxDiscountAmount: 300000,
        applyScope: 'ALL',
        targetPlanId: null,
        targetMemberScope: 'ALL',
        minOrderAmount: 0,
        maxTotalUses: 100,
        maxUsesPerMember: 1,
        startsAt: null,
        endsAt: null,
        status: 'ACTIVE',
      };

      const initialUrl = item.imageUrl || (item.imageMediaId ? `/api/v1/media/public/${item.imageMediaId}?v=${item.imageMediaId}` : '');

      openModal({
        maxWidth: '960px',
        title: isEdit ? `Cập nhật Voucher · ${item.code}` : 'Tạo Voucher khuyến mãi mới',
        subtitle: 'Cấu hình hình ảnh WebP, chế độ giảm giá (VND / %), thời gian hiệu lực và điều kiện áp dụng',
        bodyHtml: `<form id="voucher-form" novalidate>
          <div class="meta-modal-body">
            <div class="meta-modal-horizontal-layout">
              <div class="modal-col-left">
                <div class="voucher-banner-preview-box">
                  <div class="voucher-banner-frame" id="voucher-img-preview">
                    ${initialUrl
                      ? `<img src="${esc(initialUrl)}" alt="${esc(item.code || 'Voucher')}" class="voucher-banner-img" />`
                      : `<div class="voucher-banner-empty">${icon('tag', 28)}<span>Chưa có ảnh Voucher (800×440 WebP)</span></div>`}
                  </div>
                  <input type="file" id="voucher-file-input" accept="image/png,image/jpeg,image/webp" style="display:none;" />
                  <div class="row-actions" style="margin-top:10px;justify-content:center;flex-wrap:wrap">
                    <button type="button" class="btn btn-graphite btn-sm" id="btn-voucher-pick-img">${icon('upload', 15)} Tải / Đổi ảnh</button>
                    <button type="button" class="btn btn-ghost btn-sm text-danger" id="btn-voucher-remove-img" ${!initialUrl ? 'style="display:none;"' : ''}>${icon('trash', 15)} Gỡ ảnh</button>
                  </div>
                  <div class="field-error" id="voucher-image-error" aria-live="polite"></div>
                </div>

                <div class="field">
                  <label class="field-label" for="vf-code">Mã Voucher <span class="text-danger">*</span></label>
                  <input id="vf-code" class="form-control" name="code" value="${esc(item.code)}" required minlength="3" maxlength="40" placeholder="VD: METAGYM150K" style="text-transform:uppercase;font-family:monospace;font-weight:700" />
                  <span class="field-hint">Chữ không dấu viết liền, số, dấu gạch ngang (-) hoặc gạch dưới (_).</span>
                </div>

                <div class="field">
                  <label class="field-label" for="vf-title">Tên / Tiêu đề ưu đãi <span class="text-danger">*</span></label>
                  <input id="vf-title" class="form-control" name="title" value="${esc(item.title)}" required maxlength="120" placeholder="VD: Ưu đãi Hội viên mới -150K" />
                </div>

                <div class="field">
                  <label class="field-label" for="vf-desc">Mô tả chi tiết</label>
                  <textarea id="vf-desc" class="form-control" name="description" rows="3" maxlength="500" placeholder="Ghi chú ngắn gọn cho hội viên khi xem mã ưu đãi...">${esc(item.description || '')}</textarea>
                </div>
              </div>

              <div class="modal-col-right">
                <div class="modal-section-card stack-12">
                  <div class="meta-form-section-header">
                    <span class="meta-form-section-title">Chế độ giảm giá & Phạm vi</span>
                    <span class="meta-form-section-desc">Hỗ trợ giảm tiền cố định (VND) hoặc giảm theo phần trăm (%) có trần tối đa</span>
                  </div>

                  <div class="meta-form-grid-2">
                    <div class="field">
                      <label class="field-label" for="vf-discount-type">Chế độ áp dụng</label>
                      <select id="vf-discount-type" class="form-select" name="discountType">
                        <option value="FIXED_AMOUNT" ${item.discountType === 'FIXED_AMOUNT' ? 'selected' : ''}>Giảm theo số tiền cố định (VND)</option>
                        <option value="PERCENT" ${item.discountType === 'PERCENT' ? 'selected' : ''}>Giảm theo phần trăm (%)</option>
                      </select>
                    </div>
                    <div class="field">
                      <label class="field-label" for="vf-discount-val" id="vf-val-label">${item.discountType === 'PERCENT' ? 'Mức giảm (%)' : 'Số tiền giảm (VND)'}</label>
                      <input id="vf-discount-val" class="form-control tabular" type="number" name="discountValue" min="1" value="${item.discountValue}" required />
                    </div>
                  </div>

                  <div class="meta-form-grid-2">
                    <div class="field" id="vf-max-discount-wrap" ${item.discountType === 'FIXED_AMOUNT' ? 'style="opacity:0.5"' : ''}>
                      <label class="field-label" for="vf-max-discount">Giảm tối đa (VND, chỉ cho %)</label>
                      <input id="vf-max-discount" class="form-control tabular" type="number" name="maxDiscountAmount" min="1000" step="1000" value="${item.maxDiscountAmount ?? ''}" placeholder="Để trống nếu không giới hạn" ${item.discountType === 'FIXED_AMOUNT' ? 'disabled' : ''} />
                    </div>
                    <div class="field">
                      <label class="field-label" for="vf-min-order">Đơn hàng tối thiểu (VND)</label>
                      <input id="vf-min-order" class="form-control tabular" type="number" name="minOrderAmount" min="0" step="1000" value="${item.minOrderAmount ?? 0}" />
                    </div>
                  </div>

                  <div class="meta-form-grid-2">
                    <div class="field">
                      <label class="field-label" for="vf-scope">Phạm vi áp dụng</label>
                      <select id="vf-scope" class="form-select" name="applyScope">
                        ${Object.entries(SCOPE_LABELS).map(([k, lbl]) => `<option value="${k}" ${item.applyScope === k ? 'selected' : ''}>${esc(lbl)}</option>`).join('')}
                      </select>
                    </div>
                    <div class="field">
                      <label class="field-label" for="vf-member-scope">Đối tượng hội viên</label>
                      <select id="vf-member-scope" class="form-select" name="targetMemberScope">
                        ${Object.entries(MEMBER_SCOPE_LABELS).map(([k, lbl]) => `<option value="${k}" ${item.targetMemberScope === k ? 'selected' : ''}>${esc(lbl)}</option>`).join('')}
                      </select>
                    </div>
                  </div>

                  <div class="meta-form-grid-2">
                    <div class="field" id="vf-plan-wrap" ${item.applyScope === 'COACH_PACKAGE' ? 'style="opacity:0.5"' : ''}>
                      <label class="field-label" for="vf-target-plan">Áp dụng gói Gym cụ thể (tùy chọn)</label>
                      <select id="vf-target-plan" class="form-select" name="targetPlanId" ${item.applyScope === 'COACH_PACKAGE' ? 'disabled' : ''}>
                        <option value="">Tất cả các gói Gym</option>
                        ${gymPlans.map((pl) => `<option value="${esc(pl.id)}" ${item.targetPlanId === pl.id ? 'selected' : ''}>${esc(pl.name)} (${vnd(pl.price)})</option>`).join('')}
                      </select>
                    </div>
                    <div class="field">
                      <label class="field-label" for="vf-status">Trạng thái phát hành</label>
                      <select id="vf-status" class="form-select" name="status">
                        <option value="ACTIVE" ${item.status === 'ACTIVE' ? 'selected' : ''}>Đang áp dụng</option>
                        <option value="PAUSED" ${item.status === 'PAUSED' ? 'selected' : ''}>Tạm ngưng</option>
                        <option value="ARCHIVED" ${item.status === 'ARCHIVED' ? 'selected' : ''}>Lưu trữ</option>
                      </select>
                    </div>
                  </div>

                  <div class="meta-form-grid-2">
                    <div class="field">
                      <label class="field-label" for="vf-max-total">Tổng lượt toàn hệ thống</label>
                      <input id="vf-max-total" class="form-control tabular" type="number" name="maxTotalUses" min="1" value="${item.maxTotalUses ?? ''}" placeholder="Không giới hạn" />
                    </div>
                    <div class="field">
                      <label class="field-label" for="vf-max-member">Giới hạn lượt / hội viên</label>
                      <input id="vf-max-member" class="form-control tabular" type="number" name="maxUsesPerMember" min="1" max="100" value="${item.maxUsesPerMember ?? 1}" required />
                    </div>
                  </div>

                  <div class="meta-form-grid-2">
                    <div class="field">
                      <label class="field-label" for="vf-starts">Thời gian bắt đầu (GMT+7)</label>
                      <input id="vf-starts" class="form-control tabular" type="datetime-local" name="startsAt" value="${esc(isoToVnDatetimeLocal(item.startsAt))}" />
                    </div>
                    <div class="field">
                      <label class="field-label" for="vf-ends">Thời gian kết thúc (GMT+7)</label>
                      <input id="vf-ends" class="form-control tabular" type="datetime-local" name="endsAt" value="${esc(isoToVnDatetimeLocal(item.endsAt))}" />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="meta-modal-footer">
            <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
            <button type="submit" class="btn btn-primary" data-modal-submit>${icon('check', 16)} ${isEdit ? 'Lưu Voucher' : 'Tạo Voucher'}</button>
          </div>
        </form>`,
        onMount(ctrl) {
          const form = ctrl.dialog.querySelector('#voucher-form');
          const fileInput = form.querySelector('#voucher-file-input');
          const pickImgBtn = form.querySelector('#btn-voucher-pick-img');
          const removeImgBtn = form.querySelector('#btn-voucher-remove-img');
          const previewBox = form.querySelector('#voucher-img-preview');
          const imgError = form.querySelector('#voucher-image-error');
          const discountTypeEl = form.querySelector('[name="discountType"]');
          const valLabelEl = form.querySelector('#vf-val-label');
          const maxDiscountEl = form.querySelector('[name="maxDiscountAmount"]');
          const maxDiscountWrap = form.querySelector('#vf-max-discount-wrap');
          const scopeEl = form.querySelector('[name="applyScope"]');
          const planEl = form.querySelector('[name="targetPlanId"]');
          const planWrap = form.querySelector('#vf-plan-wrap');

          let pendingImageBlob = null;
          let removeImageFlag = false;

          const syncModeUi = () => {
            const isPercent = discountTypeEl.value === 'PERCENT';
            if (valLabelEl) valLabelEl.textContent = isPercent ? 'Mức giảm (%)' : 'Số tiền giảm (VND)';
            if (maxDiscountEl) maxDiscountEl.disabled = !isPercent;
            if (maxDiscountWrap) maxDiscountWrap.style.opacity = isPercent ? '1' : '0.5';

            const isCoachOnly = scopeEl.value === 'COACH_PACKAGE';
            if (planEl) {
              planEl.disabled = isCoachOnly;
              if (isCoachOnly) planEl.value = '';
            }
            if (planWrap) planWrap.style.opacity = isCoachOnly ? '0.5' : '1';
          };

          discountTypeEl.onchange = syncModeUi;
          scopeEl.onchange = syncModeUi;

          pickImgBtn.onclick = () => {
            fileInput.value = '';
            fileInput.click();
          };
          fileInput.onchange = (e) => {
            const file = e.target?.files?.[0];
            if (!file) return;
            imgError.textContent = '';
            if (file.size > 5 * 1024 * 1024) {
              imgError.textContent = 'Ảnh tối đa 5MB.';
              return;
            }
            openImageCropper({
              file,
              aspectRatio: 16 / 9,
              outputSize: 800,
              circular: false,
              onApply: ({ blob, dataUrl, file: cropped }) => {
                pendingImageBlob = cropped || blob;
                removeImageFlag = false;
                const src = dataUrl || (blob && typeof URL?.createObjectURL === 'function' ? URL.createObjectURL(blob) : '');
                if (src) previewBox.innerHTML = `<img src="${src}" alt="Preview Voucher" class="voucher-banner-img" />`;
                if (removeImgBtn) removeImgBtn.style.display = 'inline-flex';
              },
            });
          };

          if (removeImgBtn) {
            removeImgBtn.onclick = () => {
              pendingImageBlob = null;
              removeImageFlag = Boolean(item.imageMediaId);
              previewBox.innerHTML = `<div class="voucher-banner-empty">${icon('tag', 28)}<span>Chưa có ảnh Voucher (800×440 WebP)</span></div>`;
              removeImgBtn.style.display = 'none';
            };
          }

          form.onsubmit = async (e) => {
            e.preventDefault();
            ctrl.showError('');

            const code = form.querySelector('[name="code"]').value.trim().toUpperCase();
            const title = form.querySelector('[name="title"]').value.trim();
            const discountType = discountTypeEl.value;
            const discountValue = Number(form.querySelector('[name="discountValue"]').value);
            const maxDiscountRaw = form.querySelector('[name="maxDiscountAmount"]').value.trim();
            const startsIso = vnDatetimeLocalToIso(form.querySelector('[name="startsAt"]').value);
            const endsIso = vnDatetimeLocalToIso(form.querySelector('[name="endsAt"]').value);

            if (!code || code.length < 3 || !/^[A-Z0-9_-]+$/.test(code)) {
              ctrl.showError('Mã Voucher tối thiểu 3 ký tự (chữ in hoa, số, -, _).');
              return;
            }
            if (!title || title.length < 2) {
              ctrl.showError('Vui lòng nhập tiêu đề voucher.');
              return;
            }
            if (discountType === 'PERCENT' && (discountValue < 1 || discountValue > 100)) {
              ctrl.showError('Mức giảm theo % phải từ 1 đến 100.');
              return;
            }
            if (startsIso && endsIso && Date.parse(endsIso) < Date.parse(startsIso)) {
              ctrl.showError('Thời gian kết thúc phải lớn hơn hoặc bằng thời gian bắt đầu.');
              return;
            }

            ctrl.setBusy(true);
            try {
              let nextMediaId = removeImageFlag ? null : item.imageMediaId;
              if (pendingImageBlob) {
                const uploaded = await uploadRaw(
                  '/media/images',
                  pendingImageBlob,
                  pendingImageBlob.type || 'image/webp',
                  {
                    headers: {
                      'x-image-purpose': 'VOUCHER',
                      'x-file-name': `${code.toLowerCase()}.webp`,
                    },
                  },
                );
                nextMediaId = uploaded?.data?.id || nextMediaId;
              }

              const payload = {
                code,
                title,
                description: form.querySelector('[name="description"]').value.trim() || null,
                imageMediaId: nextMediaId ?? null,
                discountType,
                discountValue,
                maxDiscountAmount: discountType === 'PERCENT' && maxDiscountRaw ? Number(maxDiscountRaw) : null,
                applyScope: scopeEl.value,
                targetPlanId: scopeEl.value === 'COACH_PACKAGE' ? null : (planEl.value || null),
                targetMemberScope: form.querySelector('[name="targetMemberScope"]').value,
                minOrderAmount: Number(form.querySelector('[name="minOrderAmount"]').value || 0),
                maxTotalUses: form.querySelector('[name="maxTotalUses"]').value.trim()
                  ? Number(form.querySelector('[name="maxTotalUses"]').value)
                  : null,
                maxUsesPerMember: Number(form.querySelector('[name="maxUsesPerMember"]').value || 1),
                startsAt: startsIso,
                endsAt: endsIso,
                status: form.querySelector('[name="status"]').value,
              };

              if (isEdit) {
                await api(`/admin/vouchers/${encodeURIComponent(item.id)}`, 'PATCH', payload);
                toast(`Đã cập nhật voucher ${code}.`, 'success');
              } else {
                await api('/admin/vouchers', 'POST', payload);
                toast(`Đã tạo voucher mới ${code}.`, 'success');
              }
              ctrl.close();
              await refresh();
            } catch (err) {
              ctrl.setBusy(false);
              ctrl.showError(err.message);
            }
          };
        },
      });
    };

    const kpiHtml = `<div class="kpi-grid staff-kpi-grid" style="grid-template-columns:repeat(4,minmax(0,1fr))">
      <div class="kpi-card is-coral staff-pos-kpi">
        <div class="staff-kpi-info"><span class="staff-kpi-dot"></span><span class="staff-kpi-name">Tổng Voucher</span></div>
        <span class="staff-kpi-count tabular">${summary.totalVouchers ?? rows.length}</span>
      </div>
      <div class="kpi-card is-success staff-pos-kpi">
        <div class="staff-kpi-info"><span class="staff-kpi-dot"></span><span class="staff-kpi-name">Đang áp dụng</span></div>
        <span class="staff-kpi-count tabular">${summary.activeNowCount ?? 0}</span>
      </div>
      <div class="kpi-card is-info staff-pos-kpi">
        <div class="staff-kpi-info"><span class="staff-kpi-dot"></span><span class="staff-kpi-name">Sắp diễn ra</span></div>
        <span class="staff-kpi-count tabular">${summary.upcomingCount ?? 0}</span>
      </div>
      <div class="kpi-card is-warning staff-pos-kpi">
        <div class="staff-kpi-info"><span class="staff-kpi-dot"></span><span class="staff-kpi-name">Lượt đã sử dụng</span></div>
        <span class="staff-kpi-count tabular">${summary.totalUsedCount ?? 0}</span>
      </div>
    </div>`;

    const filterHtml = `<section class="meta-card stack-12">
      <div class="filter-bar">
        <div class="field" style="flex:1 1 220px">
          <label class="field-label" for="voucher-search">Tìm mã hoặc tiêu đề Voucher</label>
          <input id="voucher-search" class="form-control" placeholder="VD: METAGYM150K, Giảm 20%..." value="${esc(searchQuery)}" />
        </div>
        <div class="field" style="min-width:170px">
          <label class="field-label" for="voucher-type-filter">Chế độ giảm</label>
          <select id="voucher-type-filter" class="form-select">
            <option value="ALL" ${discountTypeFilter === 'ALL' ? 'selected' : ''}>Tất cả chế độ</option>
            <option value="FIXED_AMOUNT" ${discountTypeFilter === 'FIXED_AMOUNT' ? 'selected' : ''}>Tiền cố định (VND)</option>
            <option value="PERCENT" ${discountTypeFilter === 'PERCENT' ? 'selected' : ''}>Phần trăm (%)</option>
          </select>
        </div>
        <div class="field" style="min-width:170px">
          <label class="field-label" for="voucher-scope-filter">Phạm vi</label>
          <select id="voucher-scope-filter" class="form-select">
            <option value="ALL" ${applyScopeFilter === 'ALL' ? 'selected' : ''}>Tất cả phạm vi</option>
            <option value="GYM_PLAN" ${applyScopeFilter === 'GYM_PLAN' ? 'selected' : ''}>Chỉ gói Gym</option>
            <option value="COACH_PACKAGE" ${applyScopeFilter === 'COACH_PACKAGE' ? 'selected' : ''}>Chỉ gói Coach</option>
          </select>
        </div>
        <div class="field" style="min-width:160px">
          <label class="field-label" for="voucher-status-filter">Trạng thái</label>
          <select id="voucher-status-filter" class="form-select">
            <option value="ALL" ${statusFilter === 'ALL' ? 'selected' : ''}>Tất cả</option>
            <option value="ACTIVE" ${statusFilter === 'ACTIVE' ? 'selected' : ''}>Đang áp dụng</option>
            <option value="PAUSED" ${statusFilter === 'PAUSED' ? 'selected' : ''}>Tạm ngưng</option>
            <option value="ARCHIVED" ${statusFilter === 'ARCHIVED' ? 'selected' : ''}>Lưu trữ</option>
          </select>
        </div>
      </div>
    </section>`;

    const tableHtml = rows.length
      ? renderDataTable({
          columns: [
            {
              label: 'Voucher & Hình ảnh',
              render: (row) => `<div class="voucher-row-cell">
                ${row.imageThumbnailUrl
                  ? `<img src="${esc(row.imageThumbnailUrl)}" alt="${esc(row.code)}" class="voucher-thumb-img" loading="lazy" decoding="async" data-view-img="${esc(row.imageUrl || row.imageThumbnailUrl)}" data-view-title="${esc(row.code)}" />`
                  : `<span class="voucher-thumb-placeholder">${icon('tag', 18)}</span>`}
                <div>
                  <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap">
                    <code class="voucher-code-pill">${esc(row.code)}</code>
                    <span class="person-name">${esc(row.title)}</span>
                  </div>
                  ${row.description ? `<span class="person-sub">${esc(row.description)}</span>` : ''}
                </div>
              </div>`,
            },
            {
              label: 'Mức giảm',
              render: (row) => `<div class="stack-4">${formatDiscountLabel(row)}</div>`,
            },
            {
              label: 'Điều kiện áp dụng',
              render: (row) => `<div class="stack-4">
                <span style="font-size:12.5px;color:var(--meta-text-strong)">${esc(SCOPE_LABELS[row.applyScope] || row.applyScope)}${row.targetPlanName ? ` (${esc(row.targetPlanName)})` : ''}</span>
                <span class="person-sub tabular">${esc(MEMBER_SCOPE_LABELS[row.targetMemberScope] || '')} · Đơn từ ${vnd(row.minOrderAmount)} · Lượt: ${row.usedCount}/${row.maxTotalUses ?? '∞'}</span>
              </div>`,
            },
            {
              label: 'Thời gian hiệu lực',
              render: (row) => `<div class="stack-4">
                <div>${voucherPhaseBadge(row.phase)}</div>
                <span class="person-sub tabular">${row.startsAt ? formatDateTimeVN(row.startsAt) : 'Ngay lập tức'} → ${row.endsAt ? formatDateTimeVN(row.endsAt) : 'Không giới hạn'}</span>
              </div>`,
            },
            {
              label: 'Thao tác',
              align: 'right',
              render: (row) => canManage
                ? `<div class="row-actions">
                    <button type="button" class="btn btn-graphite btn-sm edit-voucher-btn" data-id="${esc(row.id)}">${icon('edit', 14)} Sửa</button>
                    <button type="button" class="btn ${row.status === 'ACTIVE' ? 'btn-warning' : 'btn-success'} btn-sm toggle-voucher-btn" data-id="${esc(row.id)}">${row.status === 'ACTIVE' ? 'Tạm ngưng' : 'Kích hoạt'}</button>
                    <button type="button" class="btn btn-danger btn-sm delete-voucher-btn" data-id="${esc(row.id)}" title="Xóa voucher">${icon('trash', 14)}</button>
                  </div>`
                : '<span class="person-sub">Chỉ xem</span>',
            },
          ],
          rows,
        })
      : renderEmptyState({
          iconName: 'tag',
          title: 'Chưa có Voucher nào',
          message: 'Tạo voucher đầu tiên với hình ảnh WebP, mức giảm VND/% và điều kiện áp dụng.',
          ctaLabel: canManage ? 'Tạo Voucher' : '',
          ctaId: 'empty-add-voucher',
        });

    shell({
      section: 'vouchers',
      topbarActionsHtml: canManage
        ? `<button type="button" class="btn btn-primary btn-sm" id="add-voucher-btn">${icon('plus', 15)} Tạo Voucher</button>`
        : '',
      contentHtml: `<div class="stack-20">
        ${kpiHtml}
        ${filterHtml}
        <section class="meta-card stack-12">
          ${tableHtml}
          ${renderPagination(pagination)}
        </section>
      </div>`,
    });

    const byId = new Map(rows.map((r) => [r.id, r]));
    root.querySelectorAll('[data-view-img]').forEach((img) => {
      img.onclick = () => openImageViewer({ src: img.dataset.viewImg, title: `Voucher ${img.dataset.viewTitle || ''}` });
    });

    const addBtn = root.querySelector('#add-voucher-btn');
    if (addBtn) addBtn.onclick = () => openVoucherModal(null);
    const emptyAdd = root.querySelector('#empty-add-voucher');
    if (emptyAdd) emptyAdd.onclick = () => openVoucherModal(null);

    root.querySelectorAll('.edit-voucher-btn').forEach((btn) => {
      btn.onclick = () => {
        const item = byId.get(btn.dataset.id);
        if (item) openVoucherModal(item);
      };
    });

    root.querySelectorAll('.toggle-voucher-btn').forEach((btn) => {
      btn.onclick = async () => {
        const item = byId.get(btn.dataset.id);
        if (!item) return;
        const nextStatus = item.status === 'ACTIVE' ? 'PAUSED' : 'ACTIVE';
        try {
          await api(`/admin/vouchers/${encodeURIComponent(item.id)}`, 'PATCH', { status: nextStatus });
          toast(nextStatus === 'ACTIVE' ? `Đã kích hoạt voucher ${item.code}.` : `Đã tạm ngưng voucher ${item.code}.`, 'success');
          await refresh();
        } catch (err) {
          toast(err.message, 'danger');
        }
      };
    });

    root.querySelectorAll('.delete-voucher-btn').forEach((btn) => {
      btn.onclick = () => {
        const item = byId.get(btn.dataset.id);
        if (!item) return;
        openConfirmModal({
          title: `Xóa voucher ${item.code}`,
          message: 'Ảnh voucher trên Supabase Storage và dữ liệu chưa phát sinh giao dịch sẽ bị xóa vĩnh viễn.',
          confirmLabel: 'Xóa voucher',
          confirmVariant: 'danger-solid',
          onConfirm: async () => {
            await api(`/admin/vouchers/${encodeURIComponent(item.id)}`, 'DELETE');
            toast(`Đã xóa voucher ${item.code} (và dọn sạch ảnh Storage).`, 'success');
            await refresh();
          },
        });
      };
    });

    const applyFilter = () => {
      updateQuery({
        status: root.querySelector('#voucher-status-filter')?.value || 'ALL',
        discountType: root.querySelector('#voucher-type-filter')?.value || 'ALL',
        applyScope: root.querySelector('#voucher-scope-filter')?.value || 'ALL',
        search: root.querySelector('#voucher-search')?.value?.trim() || '',
        page: 1,
      }, { replace: false });
    };
    const debouncedSearch = debounce(applyFilter, 350);
    root.querySelector('#voucher-search')?.addEventListener('input', debouncedSearch);
    root.querySelector('#voucher-type-filter')?.addEventListener('change', applyFilter);
    root.querySelector('#voucher-scope-filter')?.addEventListener('change', applyFilter);
    root.querySelector('#voucher-status-filter')?.addEventListener('change', applyFilter);
    bindPagination(root, (nextPage) => updateQuery({ page: nextPage }, { replace: false }));
  } catch (err) {
    shell({
      section: 'vouchers',
      contentHtml: renderErrorState({ title: 'Không tải được danh sách Voucher', message: err.message }),
    });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = refresh;
  }
}
