import { api, buildQuery, getApiBaseUrl, uploadRaw } from '../services/api.js';
import { debounce, esc, formatDateTimeVN, statusBadge, vnd } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderActionButton } from '../components/action-button.js';
import { renderDataTable } from '../components/data-table.js';
import { openDrawer } from '../components/drawer.js';
import { openImageViewer } from '../components/image-viewer.js';
import { openModal } from '../components/modal.js';
import {
  renderBanner,
  renderEmptyState,
  renderErrorState,
  renderFilterEmptyState,
  renderTableSkeleton,
} from '../components/states.js';
import { renderToggle } from '../components/toggle.js';
import { toast } from '../components/toast.js';
import { updateQuery } from '../state/router.js';

const SYSTEM_TABS = [
  { id: 'privacy', label: 'Chính sách bảo mật', iconName: 'shield' },
  { id: 'terms', label: 'Điều khoản sử dụng', iconName: 'audit' },
  { id: 'home-icons', label: 'Bộ icon màn hình chính', iconName: 'grid' },
  { id: 'payments', label: 'Thông tin thanh toán', iconName: 'card' },
  { id: 'equipment', label: 'Danh mục thiết bị', iconName: 'dumbbell' },
  { id: 'equipment-guides', label: 'Hướng dẫn sử dụng thiết bị', iconName: 'sliders' },
];

const VALID_TAB_IDS = new Set(SYSTEM_TABS.map((t) => t.id));
const ROLE_TARGET_LABELS = {
  MEMBER: 'Hội viên',
  COACH: 'Huấn luyện viên',
  ALL: 'Dùng chung',
};

const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const ALLOWED_ICON_MIMES = new Set(['image/jpeg', 'image/png', 'image/webp']);
const ALLOWED_EQUIP_MIMES = new Set(['image/jpeg', 'image/png']);

function publicMediaUrl(pathOrId, { thumb = false } = {}) {
  if (!pathOrId) return '';
  const base = getApiBaseUrl();
  if (typeof pathOrId === 'string' && pathOrId.startsWith('/api/v1')) {
    return `${base}${pathOrId.slice('/api/v1'.length)}`;
  }
  if (typeof pathOrId === 'string' && pathOrId.startsWith('/')) {
    return pathOrId;
  }
  return `${base}/media/public/${encodeURIComponent(pathOrId)}${thumb ? `?size=120&v=${encodeURIComponent(pathOrId)}` : `?v=${encodeURIComponent(pathOrId)}`}`;
}

function renderSectionEditorRows(sections = [], prefix) {
  return sections.map((sec, idx) => `
    <article class="sysinfo-section-card" data-section-idx="${idx}">
      <div class="sysinfo-section-head">
        <span class="badge-count tabular">Mục ${idx + 1}</span>
        <button type="button" class="btn btn-ghost btn-sm text-danger sysinfo-remove-section" data-prefix="${esc(prefix)}" data-idx="${idx}" ${sections.length <= 1 ? 'disabled title="Cần giữ lại ít nhất 1 mục"' : ''}>
          ${icon('trash', 14)} Xóa mục
        </button>
      </div>
      <div class="field">
        <label class="field-label" for="${esc(prefix)}-sec-head-${idx}">Tiêu đề mục</label>
        <input id="${esc(prefix)}-sec-head-${idx}" class="form-control sysinfo-sec-heading" maxlength="200" value="${esc(sec.heading || '')}" required />
      </div>
      <div class="field">
        <label class="field-label" for="${esc(prefix)}-sec-body-${idx}">Nội dung chi tiết</label>
        <textarea id="${esc(prefix)}-sec-body-${idx}" class="form-control sysinfo-sec-body" rows="3" maxlength="8000" required>${esc(sec.body || '')}</textarea>
      </div>
    </article>
  `).join('');
}

function collectSectionsFromDom(container, fallbackPrefix = 'sec') {
  const cards = [...container.querySelectorAll('.sysinfo-section-card')];
  return cards.map((card, idx) => {
    const heading = (card.querySelector('.sysinfo-sec-heading')?.value || '').trim();
    const body = (card.querySelector('.sysinfo-sec-body')?.value || '').trim();
    return {
      id: `${fallbackPrefix}-${idx + 1}`,
      heading,
      body,
    };
  });
}

function renderLegalTab({ tabId, bodyEl, sysData, onSaved }) {
  const isPrivacy = tabId === 'privacy';
  const doc = isPrivacy ? (sysData.privacyPolicy || {}) : (sysData.termsOfUse || {});
  const sections = Array.isArray(doc.sections) && doc.sections.length
    ? doc.sections.map((s) => ({ ...s }))
    : [{ id: 'sec-1', heading: '1. Nội dung chung', body: '' }];
  const updatedAt = sysData.updatedAtByKey?.[isPrivacy ? 'legal_privacy_policy' : 'legal_terms_of_service'];

  bodyEl.innerHTML = `<div class="sysinfo-split-grid">
    <form class="meta-card sysinfo-form-card" id="sysinfo-legal-form" novalidate>
      <div class="sysinfo-card-header">
        <div>
          <h2 class="title-md mb-1">${isPrivacy ? 'Biên tập Chính sách bảo mật' : 'Biên tập Điều khoản sử dụng'}</h2>
          <p class="field-hint mb-0">Đồng bộ trực tiếp xuống màn hình pháp lý trên ứng dụng Hội viên & Huấn luyện viên.${updatedAt ? ` · Cập nhật gần nhất: ${formatDateTimeVN(updatedAt)}` : ''}</p>
        </div>
        <button type="submit" class="btn btn-primary" id="sysinfo-legal-save">${icon('check', 16)} Lưu thay đổi</button>
      </div>

      <div class="grid-2">
        <div class="field">
          <label class="field-label" for="legal-title">Tiêu đề tài liệu</label>
          <input id="legal-title" class="form-control" name="title" maxlength="150" value="${esc(doc.title || '')}" required />
        </div>
        <div class="field">
          <label class="field-label" for="legal-version">Phiên bản</label>
          <input id="legal-version" class="form-control tabular" name="version" maxlength="40" value="${esc(doc.version || '1.0')}" required />
        </div>
      </div>

      <div class="grid-2">
        <div class="field">
          <label class="field-label" for="legal-effective">Ngày hiệu lực</label>
          <input id="legal-effective" class="form-control tabular" name="effectiveDate" type="date" value="${esc(doc.effectiveDate || '2026-11-01')}" required />
        </div>
        <div class="field">
          <label class="field-label" for="legal-email">Email liên hệ pháp lý</label>
          <input id="legal-email" class="form-control" name="contactEmail" type="email" maxlength="255" value="${esc(doc.contactEmail || '')}" required />
        </div>
      </div>

      ${isPrivacy
        ? `<div class="grid-2">
            <div class="field">
              <label class="field-label" for="legal-badge">Nhãn tiêu đề phụ</label>
              <input id="legal-badge" class="form-control" name="badge" maxlength="120" value="${esc(doc.badge || 'BẢO VỆ DỮ LIỆU CÁ NHÂN')}" />
            </div>
            <div class="field">
              <label class="field-label" for="legal-summary">Tóm tắt chuẩn bảo mật</label>
              <input id="legal-summary" class="form-control" name="summary" maxlength="500" value="${esc(doc.summary || '')}" required />
            </div>
          </div>`
        : `<div class="field">
            <label class="field-label" for="legal-subtitle">Mô tả áp dụng</label>
            <input id="legal-subtitle" class="form-control" name="subtitle" maxlength="250" value="${esc(doc.subtitle || '')}" required />
          </div>`}

      <div class="sysinfo-sections-bar">
        <strong>Danh sách điều mục (${sections.length})</strong>
        <button type="button" class="btn btn-graphite btn-sm" id="sysinfo-add-section">${icon('plus', 15)} Thêm mục</button>
      </div>
      <div class="sysinfo-sections-stack" id="sysinfo-sections-list">
        ${renderSectionEditorRows(sections, tabId)}
      </div>
      <div class="field-error" id="sysinfo-legal-error" aria-live="polite"></div>
    </form>

    <aside class="meta-card sysinfo-preview-card" aria-label="Xem trước hiển thị trên ứng dụng">
      <div class="sysinfo-preview-eyebrow">${esc(isPrivacy ? (doc.badge || 'BẢO VỆ DỮ LIỆU CÁ NHÂN') : 'PHÁP LÝ & QUY ĐỊNH')}</div>
      <h3 class="title-lg mt-1 mb-1" id="preview-legal-title">${esc(doc.title || '')}</h3>
      <p class="field-hint mb-3 tabular" id="preview-legal-meta">Phiên bản ${esc(doc.version || '1.0')} · Hiệu lực ${esc(doc.effectiveDate || '2026-11-01')}</p>
      <div class="impact-box mb-3" id="preview-legal-banner">${esc(isPrivacy ? (doc.summary || '') : (doc.subtitle || ''))}</div>
      <div class="sysinfo-preview-sections" id="preview-legal-sections">
        ${sections.map((s) => `
          <div class="sysinfo-preview-item">
            <div class="sysinfo-preview-heading">${esc(s.heading)}</div>
            <div class="sysinfo-preview-body">${esc(s.body).replaceAll('\n', '<br>')}</div>
          </div>
        `).join('')}
      </div>
    </aside>
  </div>`;

  const form = bodyEl.querySelector('#sysinfo-legal-form');
  const sectionsWrap = bodyEl.querySelector('#sysinfo-sections-list');
  const errorEl = bodyEl.querySelector('#sysinfo-legal-error');
  const saveBtn = bodyEl.querySelector('#sysinfo-legal-save');

  const syncPreview = () => {
    const titleEl = bodyEl.querySelector('#preview-legal-title');
    const metaEl = bodyEl.querySelector('#preview-legal-meta');
    const bannerEl = bodyEl.querySelector('#preview-legal-banner');
    const listPreviewEl = bodyEl.querySelector('#preview-legal-sections');
    const title = form.querySelector('[name="title"]')?.value?.trim() || '';
    const version = form.querySelector('[name="version"]')?.value?.trim() || '1.0';
    const eff = form.querySelector('[name="effectiveDate"]')?.value?.trim() || '';
    const subVal = isPrivacy
      ? form.querySelector('[name="summary"]')?.value?.trim() || ''
      : form.querySelector('[name="subtitle"]')?.value?.trim() || '';
    if (titleEl) titleEl.textContent = title;
    if (metaEl) metaEl.textContent = `Phiên bản ${version} · Hiệu lực ${eff}`;
    if (bannerEl) bannerEl.textContent = subVal;
    const currentSecs = collectSectionsFromDom(sectionsWrap, tabId);
    if (listPreviewEl) {
      listPreviewEl.innerHTML = currentSecs.map((s) => `
        <div class="sysinfo-preview-item">
          <div class="sysinfo-preview-heading">${esc(s.heading)}</div>
          <div class="sysinfo-preview-body">${esc(s.body).replaceAll('\n', '<br>')}</div>
        </div>
      `).join('');
    }
  };

  const rebindSectionEvents = () => {
    sectionsWrap.querySelectorAll('.sysinfo-remove-section').forEach((btn) => {
      btn.onclick = () => {
        const list = collectSectionsFromDom(sectionsWrap, tabId);
        if (list.length <= 1) return;
        list.splice(Number(btn.dataset.idx), 1);
        sectionsWrap.innerHTML = renderSectionEditorRows(list, tabId);
        rebindSectionEvents();
        syncPreview();
      };
    });
    sectionsWrap.querySelectorAll('input, textarea').forEach((inp) => {
      inp.oninput = syncPreview;
    });
  };

  form.querySelectorAll('input').forEach((inp) => {
    inp.oninput = syncPreview;
  });
  rebindSectionEvents();

  bodyEl.querySelector('#sysinfo-add-section').onclick = () => {
    const list = collectSectionsFromDom(sectionsWrap, tabId);
    list.push({ id: `${tabId}-${list.length + 1}`, heading: `${list.length + 1}. Mục mới`, body: '' });
    sectionsWrap.innerHTML = renderSectionEditorRows(list, tabId);
    rebindSectionEvents();
    syncPreview();
  };

  form.onsubmit = async (event) => {
    event.preventDefault();
    if (errorEl) errorEl.textContent = '';
    const collectedSections = collectSectionsFromDom(sectionsWrap, tabId);
    if (!collectedSections.length || collectedSections.some((s) => !s.heading || !s.body)) {
      if (errorEl) errorEl.textContent = 'Mỗi điều mục phải có đầy đủ tiêu đề và nội dung.';
      return;
    }

    const payload = isPrivacy
      ? {
          title: form.querySelector('[name="title"]')?.value?.trim() || '',
          badge: form.querySelector('[name="badge"]')?.value?.trim() || 'BẢO VỆ DỮ LIỆU CÁ NHÂN',
          version: form.querySelector('[name="version"]')?.value?.trim() || '1.0',
          effectiveDate: form.querySelector('[name="effectiveDate"]')?.value?.trim() || '',
          contactEmail: form.querySelector('[name="contactEmail"]')?.value?.trim() || '',
          summary: form.querySelector('[name="summary"]')?.value?.trim() || '',
          sections: collectedSections,
        }
      : {
          title: form.querySelector('[name="title"]')?.value?.trim() || '',
          subtitle: form.querySelector('[name="subtitle"]')?.value?.trim() || '',
          version: form.querySelector('[name="version"]')?.value?.trim() || '1.0',
          effectiveDate: form.querySelector('[name="effectiveDate"]')?.value?.trim() || '',
          contactEmail: form.querySelector('[name="contactEmail"]')?.value?.trim() || '',
          sections: collectedSections,
        };

    if (!payload.title || !payload.contactEmail) {
      if (errorEl) errorEl.textContent = 'Vui lòng nhập đầy đủ tiêu đề và email liên hệ.';
      return;
    }

    if (saveBtn) saveBtn.disabled = true;
    try {
      await api(
        isPrivacy ? '/admin/system-info/privacy-policy' : '/admin/system-info/terms-of-use',
        'PUT',
        payload,
      );
      toast(isPrivacy ? 'Đã cập nhật Chính sách bảo mật.' : 'Đã cập nhật Điều khoản sử dụng.', 'success');
      await onSaved?.();
    } catch (err) {
      if (errorEl) errorEl.textContent = err.message || 'Không thể lưu nội dung.';
    } finally {
      if (saveBtn) saveBtn.disabled = false;
    }
  };
}

function openHomeIconModal({ item, existingItems, onSaveAll }) {
  let currentMediaId = item?.mediaId || null;
  let currentPreviewUrl = publicMediaUrl(item?.thumbnailUrl || item?.imageUrl || currentMediaId, { thumb: !item?.thumbnailUrl });
  let currentFullUrl = publicMediaUrl(item?.imageUrl || currentMediaId);
  const isNew = !item;

  const renderIconPreviewHtml = () => (currentPreviewUrl
    ? `<div class="sysinfo-icon-upload-preview">
        <img src="${esc(currentPreviewUrl)}" alt="Icon xem trước" width="64" height="64" class="sysinfo-icon-preview-img" id="sys-icon-zoom" />
        <div class="d-flex gap-2">
          <button type="button" class="btn btn-graphite btn-sm" id="sys-icon-pick">${icon('upload', 14)} Đổi ảnh</button>
          <button type="button" class="btn btn-ghost btn-sm text-danger" id="sys-icon-remove">${icon('trash', 14)} Gỡ ảnh</button>
        </div>
      </div>`
    : `<div class="sysinfo-icon-upload-preview">
        <span class="meta-avatar">${icon('image', 18)}</span>
        <button type="button" class="btn btn-graphite btn-sm" id="sys-icon-pick">${icon('upload', 14)} Tải ảnh icon (WebP/PNG/JPG)</button>
      </div>`);

  openModal({
    maxWidth: '620px',
    title: isNew ? 'Thêm icon màn hình chính' : `Sửa icon: ${item.label}`,
    subtitle: 'Quản lý biểu tượng thao tác nhanh trên màn hình chính ứng dụng Meta Gym',
    bodyHtml: `<form id="sysinfo-icon-form" novalidate>
      <div class="meta-modal-body">
        <div class="field">
          <span class="field-label">Hình ảnh Icon (nền trong suốt WebP / PNG, tối đa 5 MB)</span>
          <input type="file" id="sys-icon-file" accept="image/webp,image/png,image/jpeg" hidden />
          <div id="sys-icon-preview-wrap">${renderIconPreviewHtml()}</div>
          <span class="field-error" id="sys-icon-upload-error" aria-live="polite"></span>
        </div>
        <div class="grid-2">
          <div class="field">
            <label class="field-label" for="sys-icon-key">Mã định danh (key)</label>
            <input id="sys-icon-key" class="form-control" name="key" maxlength="50" value="${esc(item?.key || '')}" placeholder="vd: action_checkin" ${isNew ? 'required' : 'readonly'} />
          </div>
          <div class="field">
            <label class="field-label" for="sys-icon-label">Nhãn hiển thị</label>
            <input id="sys-icon-label" class="form-control" name="label" maxlength="60" value="${esc(item?.label || '')}" placeholder="vd: Điểm danh QR" required />
          </div>
        </div>
        <div class="field">
          <label class="field-label" for="sys-icon-sub">Mô tả ngắn</label>
          <input id="sys-icon-sub" class="form-control" name="subtitle" maxlength="160" value="${esc(item?.subtitle || '')}" placeholder="Gợi ý chức năng cho người dùng…" />
        </div>
        <div class="grid-3">
          <div class="field">
            <label class="field-label" for="sys-icon-role">Đối tượng hiển thị</label>
            <select id="sys-icon-role" class="form-select" name="roleTarget">
              <option value="MEMBER" ${item?.roleTarget !== 'COACH' && item?.roleTarget !== 'ALL' ? 'selected' : ''}>Hội viên</option>
              <option value="COACH" ${item?.roleTarget === 'COACH' ? 'selected' : ''}>Huấn luyện viên</option>
              <option value="ALL" ${item?.roleTarget === 'ALL' ? 'selected' : ''}>Dùng chung</option>
            </select>
          </div>
          <div class="field">
            <label class="field-label" for="sys-icon-route">Đường dẫn màn hình</label>
            <input id="sys-icon-route" class="form-control" name="route" maxlength="120" value="${esc(item?.route || '/')}" required />
          </div>
          <div class="field">
            <label class="field-label" for="sys-icon-order">Thứ tự</label>
            <input id="sys-icon-order" class="form-control tabular" name="sortOrder" type="number" min="1" max="99" value="${esc(item?.sortOrder ?? (existingItems.length + 1))}" required />
          </div>
        </div>
        <div class="grid-2">
          <div class="field">
            <label class="field-label" for="sys-icon-color">Màu viền nhấn (Hex)</label>
            <input id="sys-icon-color" class="form-control tabular" name="accentColor" value="${esc(item?.accentColor || '#FF5E36')}" />
          </div>
          <div class="field" style="justify-content:flex-end">
            ${renderToggle({ id: 'sys-icon-enabled', label: 'Hiển thị trên màn hình chính', checked: item?.enabled !== false })}
          </div>
        </div>
      </div>
      <div class="meta-modal-footer">
        <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
        <button type="submit" class="btn btn-primary" data-modal-submit>${icon('check', 16)} Lưu icon</button>
      </div>
    </form>`,
    onMount(ctrl) {
      const form = ctrl.dialog.querySelector('#sysinfo-icon-form');
      const fileInput = form.querySelector('#sys-icon-file');
      const wrap = form.querySelector('#sys-icon-preview-wrap');
      const errEl = form.querySelector('#sys-icon-upload-error');
      let uploading = false;

      const bindPreview = () => {
        if (!wrap) return;
        wrap.innerHTML = renderIconPreviewHtml();
        wrap.querySelector('#sys-icon-pick')?.addEventListener('click', () => !uploading && fileInput?.click());
        wrap.querySelector('#sys-icon-remove')?.addEventListener('click', () => {
          currentMediaId = null;
          currentPreviewUrl = '';
          currentFullUrl = '';
          bindPreview();
        });
        wrap.querySelector('#sys-icon-zoom')?.addEventListener('click', () => {
          if (currentFullUrl || currentPreviewUrl) {
            openImageViewer({ src: currentFullUrl || currentPreviewUrl, title: item?.label || 'Icon màn hình chính' });
          }
        });
      };
      bindPreview();

      if (fileInput) {
        fileInput.onchange = async () => {
          const file = fileInput.files?.[0];
          fileInput.value = '';
          if (!file) return;
          if (errEl) errEl.textContent = '';
          const mime = String(file.type || '').toLowerCase();
          if (!ALLOWED_ICON_MIMES.has(mime)) {
            if (errEl) errEl.textContent = 'Chỉ hỗ trợ WebP, PNG hoặc JPEG.';
            return;
          }
          if (Number(file.size || 0) > MAX_IMAGE_BYTES) {
            if (errEl) errEl.textContent = 'Tệp ảnh vượt quá 5 MB.';
            return;
          }
          uploading = true;
          ctrl.setBusy(true);
          try {
            const uploaded = await uploadRaw('/media/images', file, mime, {
              headers: {
                'x-image-purpose': 'SYSTEM_ICON',
                'x-file-name': encodeURIComponent(file.name || 'home-icon').slice(0, 200),
              },
            });
            const id = uploaded?.data?.id;
            if (!id) throw new Error('Máy chủ không trả về mã ảnh.');
            currentMediaId = id;
            currentPreviewUrl = publicMediaUrl(uploaded?.data?.thumbnailUrl || id, { thumb: true });
            currentFullUrl = publicMediaUrl(uploaded?.data?.publicUrl || id);
            bindPreview();
            toast('Đã tải icon lên và nén WebP.', 'success');
          } catch (err) {
            if (errEl) errEl.textContent = err.message || 'Không tải được ảnh icon.';
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
        const key = (form.querySelector('[name="key"]')?.value || '').trim();
        const label = (form.querySelector('[name="label"]')?.value || '').trim();
        const subtitle = (form.querySelector('[name="subtitle"]')?.value || '').trim();
        const roleTarget = form.querySelector('[name="roleTarget"]')?.value || 'MEMBER';
        const route = (form.querySelector('[name="route"]')?.value || '').trim();
        const sortOrder = Number(form.querySelector('[name="sortOrder"]')?.value || 1);
        const accentColor = (form.querySelector('[name="accentColor"]')?.value || '#FF5E36').trim();
        const enabled = Boolean(form.querySelector('#sys-icon-enabled')?.checked);

        if (!/^[a-z0-9_]{2,50}$/.test(key)) {
          ctrl.showError('Mã định danh chỉ gồm chữ thường a-z, số 0-9 và dấu gạch dưới.');
          return;
        }
        if (!label) {
          ctrl.showError('Nhãn hiển thị không được trống.');
          return;
        }
        if (!/^#[0-9a-fA-F]{6}$/.test(accentColor)) {
          ctrl.showError('Mã màu viền phải là định dạng Hex 6 ký tự (ví dụ #FF5E36).');
          return;
        }

        const nextEntry = {
          key,
          label,
          subtitle,
          roleTarget,
          route: route || '/',
          assetFile: item?.assetFile || null,
          mediaId: currentMediaId,
          accentColor,
          sortOrder: Number.isInteger(sortOrder) ? sortOrder : 1,
          enabled,
        };

        const nextItems = isNew
          ? [...existingItems, nextEntry]
          : existingItems.map((it) => (it.key === item.key ? nextEntry : it));

        ctrl.setBusy(true);
        try {
          await onSaveAll(nextItems);
          ctrl.close();
        } catch (err) {
          ctrl.setBusy(false);
          ctrl.showError(err.message || 'Không lưu được cấu hình icon.');
        }
      };
    },
  });
}

function renderHomeIconsTab({ bodyEl, sysData, onSaved }) {
  const items = Array.isArray(sysData.homeIcons?.items) ? sysData.homeIcons.items : [];

  const saveIcons = async (nextItems) => {
    const cleaned = nextItems.map(({ imageUrl, thumbnailUrl, ...rest }) => rest);
    await api('/admin/system-info/home-icons', 'PUT', { items: cleaned });
    toast('Đã lưu Bộ icon màn hình chính.', 'success');
    await onSaved?.();
  };

  const tableHtml = renderDataTable({
    columns: [
      {
        label: 'Icon & Tên nút',
        render: (row) => {
          const thumb = row.thumbnailUrl || row.imageUrl || (row.mediaId ? publicMediaUrl(row.mediaId, { thumb: true }) : '');
          return `<div class="person-cell">
            <span class="sysinfo-home-icon-box" style="border-color:${esc(row.accentColor || '#FF5E36')}">
              ${thumb
                ? `<img src="${esc(publicMediaUrl(thumb))}" alt="${esc(row.label)}" width="36" height="36" loading="lazy" decoding="async" style="width:36px;height:36px;object-fit:contain" />`
                : icon('image', 18)}
            </span>
            <div>
              <span class="person-name">${esc(row.label)}</span>
              <span class="person-sub">${esc(row.subtitle || row.key)}</span>
            </div>
          </div>`;
        },
      },
      {
        label: 'Vai trò & Điều hướng',
        render: (row) => `<span>${esc(ROLE_TARGET_LABELS[row.roleTarget] || row.roleTarget)}</span><span class="person-sub tabular">${esc(row.route)} · #${Number(row.sortOrder || 1)}</span>`,
      },
      {
        label: 'Trạng thái',
        render: (row) => statusBadge(row.enabled !== false ? 'ACTIVE' : 'HIDDEN', row.enabled !== false ? 'Hiển thị' : 'Đang ẩn'),
      },
      {
        label: 'Thao tác',
        align: 'right',
        render: (row) => `<div class="cell-actions">
          ${renderActionButton({
            iconName: 'edit',
            label: 'Sửa icon',
            className: 'sysinfo-edit-icon',
            permission: 'system:update',
            attrs: `data-key="${esc(row.key)}"`,
          })}
          ${renderActionButton({
            iconName: 'trash',
            label: 'Xóa icon',
            className: 'sysinfo-delete-icon text-danger',
            permission: 'system:update',
            attrs: `data-key="${esc(row.key)}"`,
          })}
        </div>`,
      },
    ],
    rows: items,
    emptyHtml: renderEmptyState({
      iconName: 'grid',
      title: 'Chưa có icon màn hình chính nào',
      description: 'Thêm nút thao tác nhanh cho màn hình chính của Hội viên và Coach.',
      ctaLabel: 'Thêm icon',
      ctaId: 'sysinfo-add-icon-empty',
    }),
    ariaLabel: 'Bộ icon màn hình chính',
  });

  bodyEl.innerHTML = `<div class="stack-20">
    ${renderBanner({
      kind: 'info',
      iconName: 'info',
      title: 'Bộ icon thao tác nhanh trên màn hình chính',
      text: 'Hỗ trợ tải ảnh WebP nền trong suốt, sắp xếp thứ tự hiển thị và bật/tắt từng nút điều hướng trên ứng dụng.',
    })}
    ${tableHtml}
  </div>`;

  bodyEl.querySelectorAll('.sysinfo-edit-icon').forEach((btn) => {
    btn.onclick = () => {
      const target = items.find((it) => it.key === btn.dataset.key);
      if (target) openHomeIconModal({ item: target, existingItems: items, onSaveAll: saveIcons });
    };
  });

  bodyEl.querySelectorAll('.sysinfo-delete-icon').forEach((btn) => {
    btn.onclick = () => {
      const target = items.find((it) => it.key === btn.dataset.key);
      if (!target || items.length <= 1) {
        toast('Cần giữ lại ít nhất 1 icon màn hình chính.', 'warn');
        return;
      }
      openModal({
        title: `Xóa icon: ${target.label}`,
        maxWidth: '460px',
        bodyHtml: `<div class="meta-modal-body">
          <p class="mb-0">Xóa nút <strong>${esc(target.label)}</strong> khỏi danh sách? Ảnh lưu trữ trên Supabase (nếu có) cũng sẽ được dọn sạch.</p>
        </div>
        <div class="meta-modal-footer">
          <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
          <button type="button" class="btn btn-danger" id="sysinfo-confirm-del-icon">${icon('trash', 15)} Xác nhận xóa</button>
        </div>`,
        onMount(ctrl) {
          ctrl.dialog.querySelector('#sysinfo-confirm-del-icon').onclick = async () => {
            ctrl.setBusy(true);
            try {
              await saveIcons(items.filter((it) => it.key !== target.key));
              ctrl.close();
            } catch (err) {
              ctrl.setBusy(false);
              ctrl.showError(err.message);
            }
          };
        },
      });
    };
  });

  bodyEl.querySelector('#sysinfo-add-icon-empty')?.addEventListener('click', () => {
    openHomeIconModal({ item: null, existingItems: items, onSaveAll: saveIcons });
  });

  return {
    addNew: () => openHomeIconModal({ item: null, existingItems: items, onSaveAll: saveIcons }),
  };
}

function openPaymentMethodModal({ method, existingMethods, onSaveAll }) {
  const isNew = !method;
  openModal({
    maxWidth: '640px',
    title: isNew ? 'Thêm phương thức thanh toán' : `Cấu hình: ${method.name}`,
    subtitle: 'Thiết lập kênh thanh toán, hạn mức VND và phạm vi áp dụng cho Gói Gym / Gói Coach',
    bodyHtml: `<form id="sysinfo-pay-form" novalidate>
      <div class="meta-modal-body">
        <div class="grid-2">
          <div class="field">
            <label class="field-label" for="pm-code">Mã phương thức</label>
            <input id="pm-code" class="form-control" name="code" maxlength="30" value="${esc(method?.code || '')}" placeholder="MOMO / VNPAY / ZALOPAY" ${isNew ? 'required' : 'readonly'} />
          </div>
          <div class="field">
            <label class="field-label" for="pm-name">Tên hiển thị</label>
            <input id="pm-name" class="form-control" name="name" maxlength="120" value="${esc(method?.name || '')}" required />
          </div>
        </div>
        <div class="grid-2">
          <div class="field">
            <label class="field-label" for="pm-channel">Loại kênh</label>
            <input id="pm-channel" class="form-control" name="channelLabel" maxlength="80" value="${esc(method?.channelLabel || 'Trực tuyến (App)')}" required />
          </div>
          <div class="field">
            <label class="field-label" for="pm-fee">Chính sách phí</label>
            <input id="pm-fee" class="form-control" name="feeNote" maxlength="120" value="${esc(method?.feeNote || '')}" placeholder="Miễn phí giao dịch" />
          </div>
        </div>
        <div class="grid-3">
          <div class="field">
            <label class="field-label" for="pm-min">Tối thiểu (VND)</label>
            <input id="pm-min" class="form-control tabular" name="minAmount" type="number" min="0" value="${esc(method?.minAmount ?? 1000)}" required />
          </div>
          <div class="field">
            <label class="field-label" for="pm-max">Tối đa (VND)</label>
            <input id="pm-max" class="form-control tabular" name="maxAmount" type="number" min="0" value="${esc(method?.maxAmount ?? 50000000)}" required />
          </div>
          <div class="field">
            <label class="field-label" for="pm-order">Thứ tự</label>
            <input id="pm-order" class="form-control tabular" name="sortOrder" type="number" min="1" max="99" value="${esc(method?.sortOrder ?? (existingMethods.length + 1))}" required />
          </div>
        </div>
        <div class="field">
          <label class="field-label" for="pm-provider">Thông tin cổng kết nối</label>
          <input id="pm-provider" class="form-control" name="providerNote" maxlength="200" value="${esc(method?.providerNote || '')}" />
        </div>
        <div class="field">
          <label class="field-label" for="pm-inst">Hướng dẫn thanh toán</label>
          <textarea id="pm-inst" class="form-control" name="instructions" maxlength="500" rows="2">${esc(method?.instructions || '')}</textarea>
        </div>
        <div class="sysinfo-toggle-row">
          ${renderToggle({ id: 'pm-gym', label: 'Áp dụng cho Gói Gym', checked: method?.supportsGymPlans !== false })}
          ${renderToggle({ id: 'pm-coach', label: 'Áp dụng cho Gói Coach', checked: method?.supportsCoachPackages !== false })}
          ${renderToggle({ id: 'pm-enabled', label: 'Đang kích hoạt', checked: method?.enabled !== false })}
        </div>
      </div>
      <div class="meta-modal-footer">
        <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
        <button type="submit" class="btn btn-primary" data-modal-submit>${icon('check', 16)} Lưu phương thức</button>
      </div>
    </form>`,
    onMount(ctrl) {
      const form = ctrl.dialog.querySelector('#sysinfo-pay-form');
      form.onsubmit = async (event) => {
        event.preventDefault();
        ctrl.showError('');
        const code = (form.querySelector('[name="code"]')?.value || '').trim().toUpperCase();
        const name = (form.querySelector('[name="name"]')?.value || '').trim();
        const channelLabel = (form.querySelector('[name="channelLabel"]')?.value || '').trim();
        const providerNote = (form.querySelector('[name="providerNote"]')?.value || '').trim();
        const feeNote = (form.querySelector('[name="feeNote"]')?.value || '').trim();
        const instructions = (form.querySelector('[name="instructions"]')?.value || '').trim();
        const minAmount = Number(form.querySelector('[name="minAmount"]')?.value || 0);
        const maxAmount = Number(form.querySelector('[name="maxAmount"]')?.value || 0);
        const sortOrder = Number(form.querySelector('[name="sortOrder"]')?.value || 1);

        if (!/^[A-Z0-9_]{2,30}$/.test(code)) {
          ctrl.showError('Mã phương thức chỉ gồm chữ hoa A-Z, số 0-9 và dấu gạch dưới.');
          return;
        }
        if (!name || !channelLabel) {
          ctrl.showError('Vui lòng nhập đầy đủ tên phương thức và loại kênh.');
          return;
        }
        if (!Number.isInteger(minAmount) || !Number.isInteger(maxAmount) || maxAmount < minAmount) {
          ctrl.showError('Hạn mức tối đa phải lớn hơn hoặc bằng hạn mức tối thiểu.');
          return;
        }

        const nextEntry = {
          code,
          name,
          channelLabel,
          providerNote,
          minAmount,
          maxAmount,
          feeNote,
          instructions,
          supportsGymPlans: Boolean(form.querySelector('#pm-gym')?.checked),
          supportsCoachPackages: Boolean(form.querySelector('#pm-coach')?.checked),
          sortOrder: Number.isInteger(sortOrder) ? sortOrder : 1,
          enabled: Boolean(form.querySelector('#pm-enabled')?.checked),
        };

        const nextMethods = isNew
          ? [...existingMethods, nextEntry]
          : existingMethods.map((m) => (m.code === method.code ? nextEntry : m));

        ctrl.setBusy(true);
        try {
          await onSaveAll(nextMethods);
          ctrl.close();
        } catch (err) {
          ctrl.setBusy(false);
          ctrl.showError(err.message || 'Không lưu được phương thức thanh toán.');
        }
      };
    },
  });
}

function renderPaymentsInfoTab({ bodyEl, sysData, onSaved }) {
  const methods = Array.isArray(sysData.paymentMethods?.methods) ? sysData.paymentMethods.methods : [];

  const saveMethods = async (nextMethods) => {
    await api('/admin/system-info/payment-methods', 'PUT', { methods: nextMethods });
    toast('Đã cập nhật Thông tin phương thức thanh toán.', 'success');
    await onSaved?.();
  };

  const tableHtml = renderDataTable({
    columns: [
      {
        label: 'Phương thức thanh toán',
        render: (row) => `<span class="person-name">${esc(row.name)} <code class="ms-1" style="font-size:11px">${esc(row.code)}</code></span><span class="person-sub">${esc(row.providerNote || row.instructions || '')}</span>`,
      },
      {
        label: 'Kênh & Hạn mức',
        render: (row) => `<span>${esc(row.channelLabel)}</span><span class="person-sub tabular">${vnd(row.minAmount)} → ${vnd(row.maxAmount)}</span>`,
      },
      {
        label: 'Phạm vi áp dụng',
        render: (row) => `<div class="d-flex flex-wrap gap-1">
          ${row.supportsGymPlans ? '<span class="meta-badge meta-badge-success">Gói Gym</span>' : ''}
          ${row.supportsCoachPackages ? '<span class="meta-badge meta-badge-info">Gói Coach</span>' : '<span class="meta-badge">Không bán Coach</span>'}
        </div>`,
      },
      {
        label: 'Trạng thái',
        render: (row) => statusBadge(row.enabled !== false ? 'ACTIVE' : 'HIDDEN', row.enabled !== false ? 'Đang bật' : 'Đang tắt'),
      },
      {
        label: 'Thao tác',
        align: 'right',
        render: (row) => `<div class="cell-actions">
          ${renderActionButton({
            iconName: 'edit',
            label: 'Sửa phương thức',
            className: 'sysinfo-edit-pay',
            permission: 'system:update',
            attrs: `data-code="${esc(row.code)}"`,
          })}
        </div>`,
      },
    ],
    rows: methods,
    emptyHtml: renderEmptyState({
      iconName: 'card',
      title: 'Chưa có phương thức thanh toán nào',
      description: 'Thêm phương thức thanh toán để hiển thị cho Hội viên.',
      ctaLabel: 'Thêm phương thức',
      ctaId: 'sysinfo-add-pay-empty',
    }),
    ariaLabel: 'Danh sách phương thức thanh toán',
  });

  bodyEl.innerHTML = `<div class="stack-20">
    ${renderBanner({
      kind: 'info',
      iconName: 'info',
      title: 'Quy chuẩn thanh toán Meta Gym',
      text: 'Gói Coach chỉ bán trực tuyến (MoMo / ZaloPay / VNPay). Giao dịch tại quầy (FRONT_DESK) chỉ thu tiền gói Gym.',
    })}
    ${tableHtml}
  </div>`;

  bodyEl.querySelectorAll('.sysinfo-edit-pay').forEach((btn) => {
    btn.onclick = () => {
      const target = methods.find((m) => m.code === btn.dataset.code);
      if (target) openPaymentMethodModal({ method: target, existingMethods: methods, onSaveAll: saveMethods });
    };
  });

  bodyEl.querySelector('#sysinfo-add-pay-empty')?.addEventListener('click', () => {
    openPaymentMethodModal({ method: null, existingMethods: methods, onSaveAll: saveMethods });
  });

  return {
    addNew: () => openPaymentMethodModal({ method: null, existingMethods: methods, onSaveAll: saveMethods }),
  };
}

function openEquipmentEditModal(row, onSaved) {
  let currentMediaId = row?.imageMediaId || null;

  const renderImgPreview = (mediaId) => (mediaId
    ? `<div class="d-flex align-items-center gap-2 mt-2">
        <img src="${esc(publicMediaUrl(mediaId, { thumb: true }))}" alt="Ảnh thiết bị" width="64" height="64" class="rounded" style="object-fit:cover;border:1px solid var(--meta-border)" />
        <button type="button" class="btn btn-ghost btn-sm text-danger" id="sys-eq-rm-img">Gỡ ảnh</button>
      </div>`
    : '<span class="field-hint">Hỗ trợ JPEG / PNG tối đa 5 MB.</span>');

  openModal({
    maxWidth: '660px',
    title: row ? `Sửa thiết bị: ${row.name}` : 'Thêm thiết bị phòng tập',
    subtitle: 'Quản lý danh mục thiết bị và hướng dẫn sử dụng an toàn',
    bodyHtml: `<form id="sys-eq-form" novalidate>
      <div class="meta-modal-body">
        <div class="grid-2">
          <div class="field"><label class="field-label" for="sys-eq-name">Tên thiết bị</label><input id="sys-eq-name" class="form-control" name="name" maxlength="120" value="${esc(row?.name || '')}" required /></div>
          <div class="field"><label class="field-label" for="sys-eq-cat">Danh mục</label><input id="sys-eq-cat" class="form-control" name="category" maxlength="80" value="${esc(row?.category || '')}" placeholder="Cardio / Machine / Free Weight" required /></div>
        </div>
        <div class="field">
          <label class="field-label" for="sys-eq-file">Ảnh thiết bị công khai</label>
          <input id="sys-eq-file" class="form-control" type="file" accept="image/jpeg,image/png" />
          <div id="sys-eq-preview-wrap">${renderImgPreview(currentMediaId)}</div>
        </div>
        <div class="field"><label class="field-label" for="sys-eq-muscles">Nhóm cơ mục tiêu (phân tách bằng dấu phẩy)</label><input id="sys-eq-muscles" class="form-control" name="targetMuscles" value="${esc((row?.targetMuscles || []).join(', '))}" /></div>
        <div class="field"><label class="field-label" for="sys-eq-steps">Các bước sử dụng (mỗi dòng 1 bước)</label><textarea id="sys-eq-steps" class="form-control" name="steps" required>${esc((row?.usageSteps || []).join('\n'))}</textarea></div>
        <div class="field"><label class="field-label" for="sys-eq-safety">Lưu ý an toàn</label><textarea id="sys-eq-safety" class="form-control" name="safetyNotes" maxlength="5000">${esc(row?.safetyNotes || '')}</textarea></div>
        <div class="grid-2">
          <div class="field"><label class="field-label" for="sys-eq-video">Video hướng dẫn URL</label><input id="sys-eq-video" class="form-control" name="videoUrl" type="url" value="${esc(row?.videoUrl || '')}" /></div>
          <div class="field"><label class="field-label" for="sys-eq-status">Trạng thái</label><select id="sys-eq-status" class="form-select" name="status"><option value="ACTIVE" ${row?.status !== 'HIDDEN' ? 'selected' : ''}>Hiển thị</option><option value="HIDDEN" ${row?.status === 'HIDDEN' ? 'selected' : ''}>Đang ẩn</option></select></div>
        </div>
      </div>
      <div class="meta-modal-footer">
        <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
        <button type="submit" class="btn btn-primary" data-modal-submit>${icon('check', 16)} Lưu thiết bị</button>
      </div>
    </form>`,
    onMount(ctrl) {
      const form = ctrl.dialog.querySelector('#sys-eq-form');
      const fileInput = form.querySelector('#sys-eq-file');
      const previewWrap = form.querySelector('#sys-eq-preview-wrap');
      let uploading = false;

      const syncPreview = () => {
        if (!previewWrap) return;
        previewWrap.innerHTML = renderImgPreview(currentMediaId);
        previewWrap.querySelector('#sys-eq-rm-img')?.addEventListener('click', () => {
          currentMediaId = null;
          syncPreview();
        });
      };
      syncPreview();

      if (fileInput) {
        fileInput.onchange = async () => {
          const file = fileInput.files?.[0];
          fileInput.value = '';
          if (!file) return;
          const mime = String(file.type || '').toLowerCase();
          if (!ALLOWED_EQUIP_MIMES.has(mime)) {
            ctrl.showError('Chỉ hỗ trợ ảnh JPEG hoặc PNG cho thiết bị.');
            return;
          }
          if (Number(file.size || 0) > MAX_IMAGE_BYTES) {
            ctrl.showError('Ảnh vượt quá 5 MB.');
            return;
          }
          uploading = true;
          ctrl.setBusy(true);
          try {
            const uploaded = await uploadRaw('/media/images', file, mime, {
              headers: {
                'x-image-purpose': 'EQUIPMENT',
                'x-file-name': encodeURIComponent(file.name || 'equipment').slice(0, 200),
              },
            });
            currentMediaId = uploaded?.data?.id || null;
            syncPreview();
            toast('Đã tải ảnh thiết bị lên thành công.', 'success');
          } catch (err) {
            ctrl.showError(err.message);
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
        const category = (form.querySelector('[name="category"]')?.value || '').trim();
        const targetMuscles = (form.querySelector('[name="targetMuscles"]')?.value || '').split(',').map((s) => s.trim()).filter(Boolean);
        const usageSteps = (form.querySelector('[name="steps"]')?.value || '').split('\n').map((s) => s.trim()).filter(Boolean);
        const safetyNotes = (form.querySelector('[name="safetyNotes"]')?.value || '').trim() || null;
        const videoUrl = (form.querySelector('[name="videoUrl"]')?.value || '').trim() || null;
        const status = form.querySelector('[name="status"]')?.value || 'ACTIVE';

        if (!name || !category || !usageSteps.length) {
          ctrl.showError('Tên thiết bị, danh mục và ít nhất 1 bước sử dụng là bắt buộc.');
          return;
        }
        ctrl.setBusy(true);
        try {
          await api(
            row ? `/admin/equipment/${encodeURIComponent(row.id)}` : '/admin/equipment',
            row ? 'PATCH' : 'POST',
            { name, category, imageMediaId: currentMediaId, targetMuscles, description: row?.description || null, usageSteps, safetyNotes, videoUrl, status },
          );
          ctrl.close();
          toast(row ? 'Đã cập nhật thiết bị.' : 'Đã thêm thiết bị mới.', 'success');
          await onSaved?.();
        } catch (err) {
          ctrl.setBusy(false);
          ctrl.showError(err.message);
        }
      };
    },
  });
}

function openEquipmentGuideEditModal(row, onSaved) {
  openModal({
    maxWidth: '620px',
    title: `Hướng dẫn sử dụng: ${row.name}`,
    subtitle: `Danh mục: ${row.category} · Cập nhật từng bước vận hành & lưu ý an toàn`,
    bodyHtml: `<form id="sys-guide-form" novalidate>
      <div class="meta-modal-body">
        <div class="field">
          <label class="field-label" for="guide-steps">Các bước sử dụng thiết bị (mỗi dòng 1 bước)</label>
          <textarea id="guide-steps" class="form-control" name="usageSteps" rows="5" required>${esc((row.usageSteps || []).join('\n'))}</textarea>
        </div>
        <div class="field">
          <label class="field-label" for="guide-safety">Lưu ý an toàn bắt buộc</label>
          <textarea id="guide-safety" class="form-control" name="safetyNotes" rows="3" maxlength="5000" placeholder="Kiểm tra chốt khóa, mức tạ phù hợp trước khi tập…">${esc(row.safetyNotes || '')}</textarea>
        </div>
        <div class="field">
          <label class="field-label" for="guide-video">Video hướng dẫn URL (tùy chọn)</label>
          <input id="guide-video" class="form-control" name="videoUrl" type="url" value="${esc(row.videoUrl || '')}" placeholder="https://…" />
        </div>
      </div>
      <div class="meta-modal-footer">
        <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
        <button type="submit" class="btn btn-primary" data-modal-submit>${icon('check', 16)} Lưu hướng dẫn</button>
      </div>
    </form>`,
    onMount(ctrl) {
      const form = ctrl.dialog.querySelector('#sys-guide-form');
      form.onsubmit = async (event) => {
        event.preventDefault();
        ctrl.showError('');
        const usageSteps = (form.querySelector('[name="usageSteps"]')?.value || '').split('\n').map((s) => s.trim()).filter(Boolean);
        const safetyNotes = (form.querySelector('[name="safetyNotes"]')?.value || '').trim() || null;
        const videoUrl = (form.querySelector('[name="videoUrl"]')?.value || '').trim() || null;
        if (!usageSteps.length) {
          ctrl.showError('Cần ít nhất 1 bước hướng dẫn sử dụng.');
          return;
        }
        ctrl.setBusy(true);
        try {
          await api(`/admin/equipment/${encodeURIComponent(row.id)}`, 'PATCH', {
            usageSteps,
            safetyNotes,
            videoUrl,
          });
          ctrl.close();
          toast(`Đã cập nhật hướng dẫn sử dụng cho ${row.name}.`, 'success');
          await onSaved?.();
        } catch (err) {
          ctrl.setBusy(false);
          ctrl.showError(err.message);
        }
      };
    },
  });
}

function openEquipmentGuideDrawer(row) {
  const steps = Array.isArray(row.usageSteps) ? row.usageSteps : [];
  openDrawer({
    title: `Hướng dẫn · ${row.name}`,
    subtitle: `${row.category} · Hiển thị công khai trên ứng dụng`,
    bodyHtml: `<div class="stack-20">
      <div class="impact-box">
        <div class="impact-row"><span class="impact-key">Danh mục</span><span class="impact-val">${esc(row.category)}</span></div>
        <div class="impact-row"><span class="impact-key">Nhóm cơ</span><span class="impact-val">${esc((row.targetMuscles || []).join(', ') || 'Đang cập nhật')}</span></div>
        <div class="impact-row"><span class="impact-key">Trạng thái</span><span class="impact-val">${statusBadge(row.status, row.status === 'ACTIVE' ? 'Hiển thị' : 'Đang ẩn')}</span></div>
      </div>
      <div class="field">
        <span class="field-label">Trình tự các bước tập (${steps.length} bước)</span>
        <ol class="sysinfo-guide-ol">
          ${steps.map((step) => `<li>${esc(step)}</li>`).join('')}
        </ol>
      </div>
      <div class="field">
        <span class="field-label">Lưu ý an toàn</span>
        <div class="impact-box">${esc(row.safetyNotes || 'Chưa có lưu ý an toàn riêng.')}</div>
      </div>
    </div>`,
  });
}

async function renderEquipmentSubTab({ tabId, bodyEl, params, onFilterChange, onSaved }) {
  const isGuide = tabId === 'equipment-guides';
  const search = params?.get('search') || '';
  const statusFilter = params?.get('status') || '';
  const hasFilter = Boolean(search || statusFilter);

  const eqRes = await api(`/admin/equipment${buildQuery({ search, status: statusFilter, page: 1, pageSize: 50 })}`);
  const rows = eqRes?.data || [];

  const filterHtml = `<form class="filter-bar" id="sys-eq-filter">
    <input type="search" id="sys-eq-search" class="form-control filter-grow" placeholder="${isGuide ? 'Tìm thiết bị cần xem hoặc sửa hướng dẫn…' : 'Tìm tên thiết bị, danh mục…'}" value="${esc(search)}" aria-label="Tìm thiết bị" />
    <select id="sys-eq-status-filter" class="form-select filter-fixed" aria-label="Lọc trạng thái">
      <option value="" ${!statusFilter ? 'selected' : ''}>Tất cả trạng thái</option>
      <option value="ACTIVE" ${statusFilter === 'ACTIVE' ? 'selected' : ''}>Hiển thị</option>
      <option value="HIDDEN" ${statusFilter === 'HIDDEN' ? 'selected' : ''}>Đang ẩn</option>
    </select>
    ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm" id="sys-eq-clear">Xóa lọc</button>' : ''}
  </form>`;

  const tableHtml = isGuide
    ? renderDataTable({
      columns: [
        {
          label: 'Thiết bị',
          render: (row) => `<span class="person-name">${esc(row.name)}</span><span class="person-sub">${esc(row.category)}</span>`,
        },
        {
          label: 'Hướng dẫn từng bước',
          render: (row) => `<ol class="sysinfo-guide-ol is-compact">${(row.usageSteps || []).slice(0, 3).map((s) => `<li>${esc(s)}</li>`).join('')}</ol>`,
        },
        {
          label: 'Lưu ý an toàn',
          render: (row) => `<span class="person-sub">${esc(row.safetyNotes || 'Chưa ghi nhận lưu ý')}</span>`,
        },
        {
          label: 'Thao tác',
          align: 'right',
          render: (row) => `<div class="cell-actions">
            ${renderActionButton({
              iconName: 'eye',
              label: 'Xem hướng dẫn',
              className: 'sys-guide-view',
              permission: 'catalog:read',
              attrs: `data-id="${esc(row.id)}"`,
            })}
            ${renderActionButton({
              iconName: 'edit',
              label: 'Sửa hướng dẫn',
              className: 'sys-guide-edit',
              permission: 'catalog:update',
              attrs: `data-id="${esc(row.id)}"`,
            })}
          </div>`,
        },
      ],
      rows,
      emptyHtml: hasFilter
        ? renderFilterEmptyState({ resetId: 'sys-eq-empty-reset' })
        : renderEmptyState({ iconName: 'sliders', title: 'Chưa có hướng dẫn thiết bị', description: 'Thêm thiết bị ở tab Danh mục thiết bị để soạn hướng dẫn.' }),
      ariaLabel: 'Hướng dẫn sử dụng thiết bị',
    })
    : renderDataTable({
      columns: [
        {
          label: 'Thiết bị',
          render: (row) => `<div class="person-cell">
            ${row.imageMediaId
              ? `<img src="${esc(publicMediaUrl(row.imageMediaId, { thumb: true }))}" alt="${esc(row.name)}" width="40" height="40" loading="lazy" decoding="async" style="width:40px;height:40px;object-fit:cover;border-radius:10px;border:1px solid var(--meta-border);flex-shrink:0" />`
              : `<span class="meta-avatar">${icon('dumbbell', 16)}</span>`}
            <div>
              <span class="person-name">${esc(row.name)}</span>
              <span class="person-sub">${esc(row.safetyNotes || row.description || '—')}</span>
            </div>
          </div>`,
        },
        {
          label: 'Danh mục & Nhóm cơ',
          render: (row) => `<span>${esc(row.category)}</span><span class="person-sub">${esc((row.targetMuscles || []).join(', ') || '—')}</span>`,
        },
        {
          label: 'Hướng dẫn',
          render: (row) => `<span class="tabular">${(row.usageSteps || []).length} bước</span>`,
        },
        {
          label: 'Trạng thái',
          render: (row) => statusBadge(row.status, row.status === 'ACTIVE' ? 'Hiển thị' : 'Đang ẩn'),
        },
        {
          label: 'Thao tác',
          align: 'right',
          render: (row) => `<div class="cell-actions">
            ${renderActionButton({
              iconName: 'edit',
              label: 'Sửa thiết bị',
              className: 'sys-eq-edit',
              permission: 'catalog:update',
              attrs: `data-id="${esc(row.id)}"`,
            })}
          </div>`,
        },
      ],
      rows,
      emptyHtml: hasFilter
        ? renderFilterEmptyState({ resetId: 'sys-eq-empty-reset' })
        : renderEmptyState({
          iconName: 'dumbbell',
          title: 'Chưa có thiết bị nào',
          description: 'Thêm thiết bị phòng tập kèm hướng dẫn sử dụng an toàn.',
          ctaLabel: 'Thêm thiết bị',
          ctaId: 'sys-eq-add-empty',
        }),
      ariaLabel: 'Danh mục thiết bị hệ thống',
    });

  bodyEl.innerHTML = `<div class="stack-20">${filterHtml}${tableHtml}</div>`;

  const searchEl = bodyEl.querySelector('#sys-eq-search');
  const statusEl = bodyEl.querySelector('#sys-eq-status-filter');
  const applyFilter = () => onFilterChange({
    search: searchEl?.value?.trim() || '',
    status: statusEl?.value || '',
  });
  if (searchEl) searchEl.oninput = debounce(applyFilter, 280);
  if (statusEl) statusEl.onchange = applyFilter;
  bodyEl.querySelector('#sys-eq-filter')?.addEventListener('submit', (e) => {
    e.preventDefault();
    applyFilter();
  });
  [bodyEl.querySelector('#sys-eq-clear'), bodyEl.querySelector('#sys-eq-empty-reset')].filter(Boolean).forEach((btn) => {
    btn.onclick = () => onFilterChange({ search: '', status: '' });
  });

  bodyEl.querySelectorAll('.sys-eq-edit').forEach((btn) => {
    btn.onclick = () => {
      const target = rows.find((r) => r.id === btn.dataset.id);
      if (target) openEquipmentEditModal(target, onSaved);
    };
  });
  bodyEl.querySelector('#sys-eq-add-empty')?.addEventListener('click', () => openEquipmentEditModal(null, onSaved));

  bodyEl.querySelectorAll('.sys-guide-view').forEach((btn) => {
    btn.onclick = () => {
      const target = rows.find((r) => r.id === btn.dataset.id);
      if (target) openEquipmentGuideDrawer(target);
    };
  });
  bodyEl.querySelectorAll('.sys-guide-edit').forEach((btn) => {
    btn.onclick = () => {
      const target = rows.find((r) => r.id === btn.dataset.id);
      if (target) openEquipmentGuideEditModal(target, onSaved);
    };
  });

  return {
    addNew: () => openEquipmentEditModal(null, onSaved),
  };
}

export async function renderSystemInfoPage({ root, params, shell }) {
  const rawTab = params?.get('tab') || 'privacy';
  const tab = VALID_TAB_IDS.has(rawTab) ? rawTab : 'privacy';

  const topbarBtnLabel = ({
    'home-icons': 'Thêm icon',
    payments: 'Thêm phương thức',
    equipment: 'Thêm thiết bị',
  })[tab] || null;

  const topbarActionsHtml = topbarBtnLabel
    ? `<button type="button" class="btn btn-primary" id="sysinfo-topbar-add">${icon('plus', 16)} ${esc(topbarBtnLabel)}</button>`
    : '';

  const tabsHtml = `<div class="media-subnav" role="tablist" aria-label="Quản lý thông tin hệ thống">
    ${SYSTEM_TABS.map((t) => `
      <button type="button" class="media-subnav-btn" role="tab" aria-selected="${tab === t.id}" data-sys-tab="${esc(t.id)}">
        ${icon(t.iconName, 15)} <span>${esc(t.label)}</span>
      </button>
    `).join('')}
  </div>`;

  shell({
    section: 'system-info',
    topbarActionsHtml,
    contentHtml: `${tabsHtml}<div id="sysinfo-tab-body">${renderTableSkeleton(5)}</div>`,
  });

  const bodyEl = root.querySelector('#sysinfo-tab-body');

  root.querySelectorAll('[data-sys-tab]').forEach((btn) => {
    btn.onclick = () => {
      const nextTab = btn.getAttribute('data-sys-tab');
      const nextParams = new URLSearchParams();
      if (nextTab && nextTab !== 'privacy') nextParams.set('tab', nextTab);
      updateQuery({ tab: nextTab !== 'privacy' ? nextTab : null, search: null, status: null }, { replace: false });
      renderSystemInfoPage({ root, params: nextParams, shell });
    };
  });

  const reloadCurrentTab = () => renderSystemInfoPage({ root, params, shell });

  try {
    let tabController = null;
    if (tab === 'equipment' || tab === 'equipment-guides') {
      tabController = await renderEquipmentSubTab({
        tabId: tab,
        bodyEl,
        params,
        onFilterChange: ({ search, status }) => {
          const nextParams = new URLSearchParams();
          nextParams.set('tab', tab);
          if (search) nextParams.set('search', search);
          if (status) nextParams.set('status', status);
          updateQuery({ tab, search: search || null, status: status || null }, { replace: true });
          renderSystemInfoPage({ root, params: nextParams, shell });
        },
        onSaved: reloadCurrentTab,
      });
    } else {
      const res = await api('/admin/system-info');
      const sysData = res?.data || {};
      if (tab === 'privacy' || tab === 'terms') {
        renderLegalTab({ tabId: tab, bodyEl, sysData, onSaved: reloadCurrentTab });
      } else if (tab === 'home-icons') {
        tabController = renderHomeIconsTab({ bodyEl, sysData, onSaved: reloadCurrentTab });
      } else if (tab === 'payments') {
        tabController = renderPaymentsInfoTab({ bodyEl, sysData, onSaved: reloadCurrentTab });
      }
    }

    const addBtn = root.querySelector('#sysinfo-topbar-add');
    if (addBtn && tabController?.addNew) {
      addBtn.onclick = () => tabController.addNew();
    }
  } catch (err) {
    if (bodyEl) {
      bodyEl.innerHTML = renderErrorState({
        title: 'Không tải được thông tin hệ thống',
        message: err.message,
      });
      bodyEl.querySelector('#retry-load-btn')?.addEventListener('click', reloadCurrentTab);
    }
  }
}
