import { api, buildQuery, getToken } from '../services/api.js';
import { debounce, esc, statusBadge } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderActionButton } from '../components/action-button.js';
import { bindDataTableSelection, renderDataTable } from '../components/data-table.js';
import { openDrawer } from '../components/drawer.js';
import { exportToExcel } from '../components/export.js';
import { openModal } from '../components/modal.js';
import { bindPagination, renderPagination } from '../components/pagination.js';
import {
  renderEmptyState,
  renderErrorState,
  renderFilterEmptyState,
  renderTableSkeleton,
} from '../components/states.js';
import { toast } from '../components/toast.js';
import { updateQuery } from '../state/router.js';

const DIFFICULTY_LABELS = {
  BEGINNER: 'Cơ bản',
  INTERMEDIATE: 'Trung bình',
  ADVANCED: 'Nâng cao',
};
const VALID_DIFFICULTIES = new Set(['BEGINNER', 'INTERMEDIATE', 'ADVANCED']);
const ALLOWED_IMAGE_TYPES = new Set(['image/jpeg', 'image/png']);
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

function getApiBase() {
  try {
    return (import.meta.env?.VITE_API_BASE_URL || '/api/v1').replace(/\/$/, '');
  } catch {
    return '/api/v1';
  }
}

function publicMediaUrl(mediaId) {
  if (!mediaId) return '';
  return `${getApiBase()}/media/public/${encodeURIComponent(mediaId)}`;
}

async function uploadPublicImage(file, purpose) {
  if (!file) throw new Error('Vui lòng chọn tệp ảnh để tải lên.');
  const mimeType = String(file.type || '').toLowerCase();
  if (!ALLOWED_IMAGE_TYPES.has(mimeType)) {
    throw new Error('Chỉ hỗ trợ ảnh định dạng JPEG (.jpg, .jpeg) hoặc PNG (.png).');
  }
  if (Number(file.size || 0) > MAX_IMAGE_BYTES) {
    throw new Error('Ảnh vượt quá giới hạn tối đa 5 MB.');
  }

  const token = getToken();
  const binaryBody = typeof file.arrayBuffer === 'function' ? await file.arrayBuffer() : file;
  const response = await globalThis.fetch(`${getApiBase()}/media/images`, {
    method: 'POST',
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      'Content-Type': mimeType,
      'x-image-purpose': purpose,
      'x-file-name': encodeURIComponent(file.name || 'image').slice(0, 200),
    },
    body: binaryBody,
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(payload?.error?.message || `Tải ảnh thất bại (HTTP ${response.status})`);
  }
  const mediaId = payload?.data?.id;
  if (!mediaId) {
    throw new Error('Máy chủ không trả về mã ảnh hợp lệ.');
  }
  return {
    id: mediaId,
    publicUrl: payload?.data?.publicUrl || publicMediaUrl(mediaId),
  };
}

export async function renderEquipmentPage({ root, params, shell }) {
  const tab = params?.get('tab') === 'exercises' ? 'exercises' : 'equipment';
  const section = tab === 'exercises' ? 'exercises' : 'equipment';
  const search = params?.get('search') || '';
  const statusFilter = params?.get('status') || '';
  const categoryFilter = params?.get('category') || '';
  const difficultyFilter = params?.get('difficulty') || '';
  const equipmentIdFilter = params?.get('equipmentId') || '';
  const page = Math.max(1, Number(params?.get('page')) || 1);
  const pageSize = Math.max(1, Number(params?.get('pageSize')) || 10);

  const hasFilter = tab === 'equipment'
    ? Boolean(search || statusFilter || categoryFilter)
    : Boolean(search || statusFilter || difficultyFilter || equipmentIdFilter);

  const buildFilterHtml = (allEquipment = [], canExport = false) => (tab === 'equipment'
    ? `<form class="filter-bar" id="cat-filter-form">
      <input type="search" id="cat-search" class="form-control filter-grow" placeholder="Tìm tên thiết bị, danh mục hoặc mô tả…" value="${esc(search)}" aria-label="Tìm thiết bị" />
      <input type="text" id="cat-category" class="form-control filter-fixed" placeholder="Danh mục (vd: Cardio)…" value="${esc(categoryFilter)}" aria-label="Lọc danh mục thiết bị" />
      <select id="cat-status" class="form-select filter-fixed" aria-label="Lọc trạng thái thiết bị">
        <option value="" ${!statusFilter ? 'selected' : ''}>Tất cả trạng thái</option>
        <option value="ACTIVE" ${statusFilter === 'ACTIVE' ? 'selected' : ''}>Hiển thị (ACTIVE)</option>
        <option value="HIDDEN" ${statusFilter === 'HIDDEN' ? 'selected' : ''}>Đang ẩn (HIDDEN)</option>
      </select>
      ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm" id="cat-clear">Xóa lọc</button>' : ''}
      <button type="button" class="btn btn-graphite btn-sm" id="cat-export-excel" ${canExport ? '' : 'disabled'}>
        ${icon('download', 16)} <span id="cat-export-label">Xuất Excel</span>
      </button>
    </form>`
    : `<form class="filter-bar" id="cat-filter-form">
      <input type="search" id="cat-search" class="form-control filter-grow" placeholder="Tìm tên bài tập, mô tả hoặc tên thiết bị…" value="${esc(search)}" aria-label="Tìm bài tập" />
      <select id="cat-difficulty" class="form-select filter-fixed" aria-label="Lọc độ khó bài tập">
        <option value="" ${!difficultyFilter ? 'selected' : ''}>Tất cả độ khó</option>
        <option value="BEGINNER" ${difficultyFilter === 'BEGINNER' ? 'selected' : ''}>Cơ bản (BEGINNER)</option>
        <option value="INTERMEDIATE" ${difficultyFilter === 'INTERMEDIATE' ? 'selected' : ''}>Trung bình (INTERMEDIATE)</option>
        <option value="ADVANCED" ${difficultyFilter === 'ADVANCED' ? 'selected' : ''}>Nâng cao (ADVANCED)</option>
      </select>
      <select id="cat-equipment" class="form-select filter-fixed" aria-label="Lọc theo thiết bị liên kết">
        <option value="" ${!equipmentIdFilter ? 'selected' : ''}>Tất cả thiết bị</option>
        ${allEquipment.map((eq) => `<option value="${esc(eq.id)}" ${equipmentIdFilter === eq.id ? 'selected' : ''}>${esc(eq.name)}</option>`).join('')}
      </select>
      <select id="cat-status" class="form-select filter-fixed" aria-label="Lọc trạng thái bài tập">
        <option value="" ${!statusFilter ? 'selected' : ''}>Tất cả trạng thái</option>
        <option value="ACTIVE" ${statusFilter === 'ACTIVE' ? 'selected' : ''}>Hiển thị (ACTIVE)</option>
        <option value="HIDDEN" ${statusFilter === 'HIDDEN' ? 'selected' : ''}>Đang ẩn (HIDDEN)</option>
      </select>
      ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm" id="cat-clear">Xóa lọc</button>' : ''}
      <button type="button" class="btn btn-graphite btn-sm" id="cat-export-excel" ${canExport ? '' : 'disabled'}>
        ${icon('download', 16)} <span id="cat-export-label">Xuất Excel</span>
      </button>
    </form>`);

  const topbarActionsHtml = `<button type="button" class="btn btn-primary" id="create-item">${icon('plus', 16)} ${tab === 'equipment' ? 'Thêm thiết bị' : 'Thêm bài tập'}</button>`;

  shell({
    section,
    topbarActionsHtml,
    contentHtml: `<div class="stack-20">${buildFilterHtml([], false)}${renderTableSkeleton(5)}</div>`,
  });

  const reloadWith = (patch = {}) => {
    const nextTab = patch.tab !== undefined ? patch.tab : tab;
    const nextSearch = patch.search !== undefined ? patch.search : (root.querySelector('#cat-search')?.value?.trim() || '');
    const nextStatus = patch.status !== undefined ? patch.status : (root.querySelector('#cat-status')?.value || '');
    const nextCategory = patch.category !== undefined ? patch.category : (root.querySelector('#cat-category')?.value?.trim() || '');
    const nextDifficulty = patch.difficulty !== undefined ? patch.difficulty : (root.querySelector('#cat-difficulty')?.value || '');
    const nextEquipmentId = patch.equipmentId !== undefined ? patch.equipmentId : (root.querySelector('#cat-equipment')?.value || '');
    const nextPage = patch.page !== undefined ? patch.page : page;
    const nextPageSize = patch.pageSize !== undefined ? patch.pageSize : pageSize;

    const nextParams = new URLSearchParams();
    if (nextTab !== 'equipment') nextParams.set('tab', nextTab);
    if (nextSearch) nextParams.set('search', nextSearch);
    if (nextStatus) nextParams.set('status', nextStatus);
    if (nextTab === 'equipment' && nextCategory) nextParams.set('category', nextCategory);
    if (nextTab === 'exercises' && nextDifficulty) nextParams.set('difficulty', nextDifficulty);
    if (nextTab === 'exercises' && nextEquipmentId) nextParams.set('equipmentId', nextEquipmentId);
    if (nextPage > 1) nextParams.set('page', String(nextPage));
    if (nextPageSize !== 10) nextParams.set('pageSize', String(nextPageSize));

    updateQuery({
      tab: nextTab !== 'equipment' ? nextTab : null,
      search: nextSearch || null,
      status: nextStatus || null,
      category: nextTab === 'equipment' && nextCategory ? nextCategory : null,
      difficulty: nextTab === 'exercises' && nextDifficulty ? nextDifficulty : null,
      equipmentId: nextTab === 'exercises' && nextEquipmentId ? nextEquipmentId : null,
      page: nextPage > 1 ? nextPage : null,
      pageSize: nextPageSize !== 10 ? nextPageSize : null,
    }, { replace: true });

    return renderEquipmentPage({ root, params: nextParams, shell });
  };

  try {
    let rows = [];
    let pagination = { page, pageSize, totalItems: 0, totalPages: 1 };
    let allEquipment = [];

    if (tab === 'equipment') {
      const query = buildQuery({
        search,
        category: categoryFilter,
        status: statusFilter,
        page,
        pageSize,
      });
      const eqRes = await api(`/admin/equipment${query}`);
      rows = eqRes?.data || [];
      pagination = eqRes?.pagination || {
        page,
        pageSize,
        totalItems: rows.length,
        totalPages: Math.max(1, Math.ceil(rows.length / pageSize)),
      };
      allEquipment = rows;
    } else {
      const exQuery = buildQuery({
        search,
        status: statusFilter,
        difficulty: difficultyFilter,
        equipmentId: equipmentIdFilter,
        page,
        pageSize,
      });
      const [exRes, eqCatalogRes] = await Promise.all([
        api(`/admin/exercises${exQuery}`),
        api('/admin/equipment?pageSize=100').catch(() => ({ data: [] })),
      ]);
      rows = exRes?.data || [];
      pagination = exRes?.pagination || {
        page,
        pageSize,
        totalItems: rows.length,
        totalPages: Math.max(1, Math.ceil(rows.length / pageSize)),
      };
      allEquipment = eqCatalogRes?.data || [];
    }

    const eqNameById = new Map(allEquipment.map((item) => [item.id, item.name]));

    const tableHtml = tab === 'equipment'
      ? renderDataTable({
        columns: [
          {
            label: 'Thiết bị',
            render: (row) => `<div class="person-cell">
              ${row.imageMediaId
                ? `<img src="${esc(publicMediaUrl(row.imageMediaId))}" alt="${esc(row.name)}" width="40" height="40" loading="lazy" decoding="async" style="width:40px;height:40px;object-fit:cover;border-radius:10px;border:1px solid var(--meta-border);flex-shrink:0" />`
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
                iconName: 'eye',
                label: 'Xem trước công khai',
                className: 'preview-eq',
                permission: 'catalog:read',
                attrs: `data-id="${esc(row.id)}"`,
              })}
              ${renderActionButton({
                iconName: 'edit',
                label: 'Sửa thiết bị',
                className: 'edit-eq',
                permission: 'catalog:update',
                attrs: `data-id="${esc(row.id)}"`,
              })}
            </div>`,
          },
        ],
        rows,
        selectable: true,
        rowId: (_row, idx) => String(idx),
        emptyHtml: hasFilter
          ? renderFilterEmptyState({ resetId: 'cat-filter-reset' })
          : renderEmptyState({
            iconName: 'dumbbell',
            title: 'Chưa có thiết bị nào',
            description: 'Thêm thiết bị phòng tập kèm ảnh công khai, các bước sử dụng và lưu ý an toàn.',
            ctaLabel: 'Thêm thiết bị',
            ctaId: 'create-item-empty',
          }),
        paginationHtml: renderPagination({ ...pagination, prefix: 'eq' }),
        ariaLabel: 'Danh sách thiết bị phòng tập',
      })
      : renderDataTable({
        columns: [
          {
            label: 'Tên bài tập',
            render: (row) => `<span class="person-name">${esc(row.name)}</span><span class="person-sub">${esc((row.instructions || '').slice(0, 80))}</span>`,
          },
          {
            label: 'Thiết bị liên kết',
            render: (row) => esc(row.equipmentName || eqNameById.get(row.equipmentId) || 'Không gắn thiết bị'),
          },
          {
            label: 'Độ khó & Nhóm cơ',
            render: (row) => `<span class="meta-badge meta-badge-info">${esc(DIFFICULTY_LABELS[row.difficulty] || row.difficulty || 'Chưa phân loại')}</span><span class="person-sub">${esc((row.targetMuscles || []).join(', ') || '—')}</span>`,
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
                label: 'Sửa bài tập',
                className: 'edit-ex',
                permission: 'catalog:update',
                attrs: `data-id="${esc(row.id)}"`,
              })}
            </div>`,
          },
        ],
        rows,
        selectable: true,
        rowId: (_row, idx) => String(idx),
        emptyHtml: hasFilter
          ? renderFilterEmptyState({ resetId: 'cat-filter-reset' })
          : renderEmptyState({
            iconName: 'dumbbell',
            title: 'Chưa có bài tập nào',
            description: 'Thêm bài tập vào thư viện exercises để đồng bộ cho Coach và Member.',
            ctaLabel: 'Thêm bài tập',
            ctaId: 'create-item-empty',
          }),
        paginationHtml: renderPagination({ ...pagination, prefix: 'ex' }),
        ariaLabel: 'Thư viện bài tập exercises',
      });

    const contentHtml = `<div class="stack-20">
      ${buildFilterHtml(allEquipment, rows.length > 0)}
      ${tableHtml}
    </div>`;

    shell({
      section,
      contentHtml,
      topbarActionsHtml,
    });

    const debouncedSearch = debounce(() => reloadWith({ page: 1 }), 280);
    const searchEl = root.querySelector('#cat-search');
    if (searchEl) searchEl.oninput = debouncedSearch;

    const categoryEl = root.querySelector('#cat-category');
    if (categoryEl) categoryEl.oninput = debouncedSearch;

    const filterForm = root.querySelector('#cat-filter-form');
    if (filterForm) {
      filterForm.onsubmit = (ev) => {
        ev.preventDefault();
        debouncedSearch.cancel();
        reloadWith({ page: 1 });
      };
    }

    ['#cat-status', '#cat-difficulty', '#cat-equipment'].forEach((sel) => {
      const el = root.querySelector(sel);
      if (el) el.onchange = () => reloadWith({ page: 1 });
    });

    [root.querySelector('#cat-clear'), root.querySelector('#cat-filter-reset')].filter(Boolean).forEach((btn) => {
      btn.onclick = () => reloadWith({
        search: '',
        status: '',
        category: '',
        difficulty: '',
        equipmentId: '',
        page: 1,
      });
    });

    bindPagination(root, {
      page: pagination.page,
      totalPages: pagination.totalPages,
      prefix: tab === 'equipment' ? 'eq' : 'ex',
      onChange: (nextPage) => reloadWith({ page: nextPage }),
      onPageSizeChange: (nextSize) => reloadWith({ pageSize: nextSize, page: 1 }),
    });

    const exportLabel = root.querySelector('#cat-export-label');
    const getSelectedIndices = bindDataTableSelection(root, {
      onSelectionChange: (ids) => {
        if (exportLabel) {
          exportLabel.textContent = ids.length > 0 ? `Xuất Excel (${ids.length})` : 'Xuất Excel';
        }
      },
    });

    const exportBtn = root.querySelector('#cat-export-excel');
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
        const ok = tab === 'equipment'
          ? exportToExcel({
            filename: 'metagym-equipment.csv',
            columns: [
              { label: 'Tên thiết bị', value: (r) => r.name || '' },
              { label: 'Danh mục', value: (r) => r.category || '' },
              { label: 'Nhóm cơ mục tiêu', value: (r) => (r.targetMuscles || []).join(', ') },
              { label: 'Số bước sử dụng', value: (r) => (r.usageSteps || []).length },
              { label: 'Trạng thái', value: (r) => (r.status === 'ACTIVE' ? 'Hiển thị' : 'Đang ẩn') },
            ],
            rows: targetRows,
          })
          : exportToExcel({
            filename: 'metagym-exercises.csv',
            columns: [
              { label: 'Tên bài tập', value: (r) => r.name || '' },
              { label: 'Thiết bị liên kết', value: (r) => r.equipmentName || eqNameById.get(r.equipmentId) || 'Không gắn thiết bị' },
              { label: 'Độ khó', value: (r) => DIFFICULTY_LABELS[r.difficulty] || r.difficulty || '' },
              { label: 'Nhóm cơ mục tiêu', value: (r) => (r.targetMuscles || []).join(', ') },
              { label: 'Trạng thái', value: (r) => (r.status === 'ACTIVE' ? 'Hiển thị' : 'Đang ẩn') },
            ],
            rows: targetRows,
          });
        if (ok) toast(`Đã xuất ${targetRows.length} dòng ra file Excel (.csv).`);
      };
    }

    const openEquipmentModal = (row) => {
      let currentMediaId = row?.imageMediaId || null;

      const renderImagePreviewHtml = (mediaId) => (mediaId
        ? `<div style="display:flex;align-items:center;gap:12px;margin-top:8px">
          <img id="eq-image-preview" src="${esc(publicMediaUrl(mediaId))}" alt="Ảnh xem trước thiết bị" width="88" height="88" loading="lazy" decoding="async" style="width:88px;height:88px;object-fit:cover;border-radius:12px;border:1px solid var(--meta-border)" />
          <div style="display:flex;flex-direction:column;gap:6px">
            <span class="meta-badge meta-badge-success">Đã gắn ảnh công khai</span>
            <button type="button" class="btn btn-ghost btn-sm" id="eq-image-remove">Gỡ ảnh</button>
          </div>
        </div>`
        : '<span class="field-hint">Chưa có ảnh thiết bị. Hỗ trợ JPEG/PNG tối đa 5 MB.</span>');

      openModal({
        title: row ? `Sửa thiết bị: ${row.name}` : 'Thêm thiết bị phòng tập',
        subtitle: 'Ảnh công khai, hướng dẫn sử dụng và lưu ý an toàn hiển thị trên ứng dụng',
        bodyHtml: `<form id="equipment-form" novalidate>
          <div class="meta-modal-body">
            <div class="grid-2">
              <div class="field"><label class="field-label" for="eq-name">Tên thiết bị</label><input id="eq-name" class="form-control" name="name" maxlength="120" value="${esc(row?.name || '')}" required /></div>
              <div class="field"><label class="field-label" for="eq-cat">Danh mục</label><input id="eq-cat" class="form-control" name="category" maxlength="80" value="${esc(row?.category || '')}" required /></div>
            </div>
            <div class="field">
              <label class="field-label" for="eq-image-file">Ảnh thiết bị công khai (JPEG / PNG, tối đa 5 MB)</label>
              <input id="eq-image-file" class="form-control" type="file" accept="image/jpeg,image/png" />
              <span class="field-hint" id="eq-image-status"></span>
              <div id="eq-image-preview-wrap">${renderImagePreviewHtml(currentMediaId)}</div>
            </div>
            <div class="field"><label class="field-label" for="eq-muscles">Nhóm cơ mục tiêu (phân tách bằng dấu phẩy)</label><input id="eq-muscles" class="form-control" name="targetMuscles" value="${esc((row?.targetMuscles || []).join(', '))}" /></div>
            <div class="field"><label class="field-label" for="eq-desc">Mô tả thiết bị</label><textarea id="eq-desc" class="form-control" name="description" maxlength="5000">${esc(row?.description || '')}</textarea></div>
            <div class="field"><label class="field-label" for="eq-steps">Các bước sử dụng (mỗi dòng 1 bước)</label><textarea id="eq-steps" class="form-control" name="steps" required>${esc((row?.usageSteps || []).join('\n'))}</textarea></div>
            <div class="field"><label class="field-label" for="eq-safety">Lưu ý an toàn</label><textarea id="eq-safety" class="form-control" name="safetyNotes" maxlength="5000">${esc(row?.safetyNotes || '')}</textarea></div>
            <div class="grid-2">
              <div class="field"><label class="field-label" for="eq-video">Video URL</label><input id="eq-video" class="form-control" name="videoUrl" type="url" value="${esc(row?.videoUrl || '')}" /></div>
              <div class="field"><label class="field-label" for="eq-status">Trạng thái</label><select id="eq-status" class="form-select" name="status"><option value="ACTIVE" ${row?.status !== 'HIDDEN' ? 'selected' : ''}>Hiển thị</option><option value="HIDDEN" ${row?.status === 'HIDDEN' ? 'selected' : ''}>Ẩn</option></select></div>
            </div>
          </div>
          <div class="meta-modal-footer"><button type="button" class="btn btn-ghost" data-close-modal>Hủy</button><button type="submit" class="btn btn-primary" data-modal-submit>${icon('check', 16)} Lưu thiết bị</button></div>
        </form>`,
        onMount(ctrl) {
          const form = ctrl.dialog.querySelector('#equipment-form');
          const fileInput = form.querySelector('#eq-image-file');
          const statusEl = form.querySelector('#eq-image-status');
          const previewWrap = form.querySelector('#eq-image-preview-wrap');
          let uploading = false;

          const syncPreview = () => {
            if (!previewWrap) return;
            previewWrap.innerHTML = renderImagePreviewHtml(currentMediaId);
            const removeBtn = previewWrap.querySelector('#eq-image-remove');
            if (removeBtn) {
              removeBtn.onclick = () => {
                currentMediaId = null;
                if (fileInput) fileInput.value = '';
                if (statusEl) statusEl.textContent = 'Đã gỡ ảnh khỏi thiết bị.';
                syncPreview();
              };
            }
          };

          syncPreview();

          if (fileInput) {
            fileInput.onchange = async () => {
              const file = fileInput.files?.[0];
              if (!file) return;
              ctrl.showError('');
              uploading = true;
              if (statusEl) statusEl.textContent = 'Đang tải ảnh lên máy chủ…';
              try {
                const uploaded = await uploadPublicImage(file, 'EQUIPMENT');
                currentMediaId = uploaded.id;
                if (statusEl) statusEl.textContent = 'Đã tải ảnh thành công.';
                syncPreview();
              } catch (error) {
                if (statusEl) statusEl.textContent = '';
                ctrl.showError(error.message);
              } finally {
                uploading = false;
              }
            };
          }

          form.onsubmit = async (event) => {
            event.preventDefault();
            ctrl.showError('');
            if (uploading) {
              ctrl.showError('Ảnh đang được tải lên, vui lòng đợi hoàn tất.');
              return;
            }
            const name = (form.querySelector('[name="name"]')?.value || '').trim();
            const category = (form.querySelector('[name="category"]')?.value || '').trim();
            const usageSteps = (form.querySelector('[name="steps"]')?.value || '').split('\n').map((s) => s.trim()).filter(Boolean);
            const targetMuscles = (form.querySelector('[name="targetMuscles"]')?.value || '').split(',').map((s) => s.trim()).filter(Boolean);

            if (!name || name.length > 120) {
              ctrl.showError('Tên thiết bị không được trống (tối đa 120 ký tự).');
              return;
            }
            if (!category || category.length > 80) {
              ctrl.showError('Danh mục thiết bị không được trống (tối đa 80 ký tự).');
              return;
            }
            if (!usageSteps.length) {
              ctrl.showError('Cần nhập ít nhất 1 bước sử dụng thiết bị.');
              return;
            }

            ctrl.setBusy(true);
            try {
              await api(row ? `/admin/equipment/${encodeURIComponent(row.id)}` : '/admin/equipment', row ? 'PATCH' : 'POST', {
                name,
                category,
                targetMuscles,
                imageMediaId: currentMediaId || null,
                description: (form.querySelector('[name="description"]')?.value || '').trim() || null,
                usageSteps,
                safetyNotes: (form.querySelector('[name="safetyNotes"]')?.value || '').trim() || null,
                videoUrl: (form.querySelector('[name="videoUrl"]')?.value || '').trim() || null,
                status: form.querySelector('[name="status"]')?.value || 'ACTIVE',
              });
              ctrl.close();
              toast(row ? 'Đã cập nhật thiết bị.' : 'Đã thêm thiết bị mới.');
              await reloadWith({ page: row ? page : 1 });
            } catch (error) {
              ctrl.setBusy(false);
              ctrl.showError(error.message);
            }
          };
        },
      });
    };

    const openExerciseModal = (row) => {
      openModal({
        title: row ? `Sửa bài tập: ${row.name}` : 'Thêm bài tập mới (exercises)',
        subtitle: 'Liên kết thiết bị, độ khó, nhóm cơ mục tiêu và hướng dẫn kỹ thuật chuẩn',
        bodyHtml: `<form id="exercise-form" novalidate>
          <div class="meta-modal-body">
            <div class="grid-2">
              <div class="field"><label class="field-label" for="ex-name">Tên bài tập</label><input id="ex-name" class="form-control" name="name" maxlength="120" value="${esc(row?.name || '')}" required /></div>
              <div class="field"><label class="field-label" for="ex-eq">Thiết bị liên kết</label><select id="ex-eq" class="form-select" name="equipmentId"><option value="">Không gắn thiết bị</option>${allEquipment.map((e) => `<option value="${esc(e.id)}" ${row?.equipmentId === e.id ? 'selected' : ''}>${esc(e.name)}</option>`).join('')}</select></div>
            </div>
            <div class="grid-2">
              <div class="field"><label class="field-label" for="ex-diff">Độ khó</label><select id="ex-diff" class="form-select" name="difficulty"><option value="">Chưa chọn</option><option value="BEGINNER" ${row?.difficulty === 'BEGINNER' ? 'selected' : ''}>Cơ bản (BEGINNER)</option><option value="INTERMEDIATE" ${row?.difficulty === 'INTERMEDIATE' ? 'selected' : ''}>Trung bình (INTERMEDIATE)</option><option value="ADVANCED" ${row?.difficulty === 'ADVANCED' ? 'selected' : ''}>Nâng cao (ADVANCED)</option></select></div>
              <div class="field"><label class="field-label" for="ex-status">Trạng thái</label><select id="ex-status" class="form-select" name="status"><option value="ACTIVE" ${row?.status !== 'HIDDEN' ? 'selected' : ''}>Hiển thị</option><option value="HIDDEN" ${row?.status === 'HIDDEN' ? 'selected' : ''}>Ẩn</option></select></div>
            </div>
            <div class="field"><label class="field-label" for="ex-muscles">Nhóm cơ mục tiêu (phân tách bằng dấu phẩy)</label><input id="ex-muscles" class="form-control" name="targetMuscles" value="${esc((row?.targetMuscles || []).join(', '))}" placeholder="Ví dụ: Ngực, Vai trước, Tay sau" /></div>
            <div class="field"><label class="field-label" for="ex-desc">Mô tả ngắn</label><textarea id="ex-desc" class="form-control" name="description" maxlength="5000">${esc(row?.description || '')}</textarea></div>
            <div class="field"><label class="field-label" for="ex-inst">Hướng dẫn kỹ thuật</label><textarea id="ex-inst" class="form-control" name="instructions" maxlength="10000" required>${esc(row?.instructions || '')}</textarea></div>
            <div class="field"><label class="field-label" for="ex-safety">Lưu ý an toàn</label><textarea id="ex-safety" class="form-control" name="safetyNotes" maxlength="5000">${esc(row?.safetyNotes || '')}</textarea></div>
            <div class="field"><label class="field-label" for="ex-video">Video hướng dẫn URL</label><input id="ex-video" class="form-control" name="videoUrl" type="url" value="${esc(row?.videoUrl || '')}" /></div>
          </div>
          <div class="meta-modal-footer"><button type="button" class="btn btn-ghost" data-close-modal>Hủy</button><button type="submit" class="btn btn-primary" data-modal-submit>${icon('check', 16)} Lưu bài tập</button></div>
        </form>`,
        onMount(ctrl) {
          const form = ctrl.dialog.querySelector('#exercise-form');
          form.onsubmit = async (event) => {
            event.preventDefault();
            ctrl.showError('');
            const name = (form.querySelector('[name="name"]')?.value || '').trim();
            const equipmentId = form.querySelector('[name="equipmentId"]')?.value || null;
            const difficultyRaw = form.querySelector('[name="difficulty"]')?.value || '';
            const difficulty = difficultyRaw || null;
            const targetMuscles = (form.querySelector('[name="targetMuscles"]')?.value || '').split(',').map((s) => s.trim()).filter(Boolean);
            const description = (form.querySelector('[name="description"]')?.value || '').trim() || null;
            const instructions = (form.querySelector('[name="instructions"]')?.value || '').trim();
            const safetyNotes = (form.querySelector('[name="safetyNotes"]')?.value || '').trim() || null;
            const videoUrl = (form.querySelector('[name="videoUrl"]')?.value || '').trim() || null;
            const status = form.querySelector('[name="status"]')?.value || 'ACTIVE';

            if (!name || name.length > 120) {
              ctrl.showError('Tên bài tập không được trống (tối đa 120 ký tự).');
              return;
            }
            if (!instructions || instructions.length > 10000) {
              ctrl.showError('Hướng dẫn kỹ thuật không được trống.');
              return;
            }
            if (difficulty && !VALID_DIFFICULTIES.has(difficulty)) {
              ctrl.showError('Độ khó bài tập không hợp lệ.');
              return;
            }
            if (targetMuscles.length > 30 || targetMuscles.some((m) => m.length > 80)) {
              ctrl.showError('Nhóm cơ mục tiêu tối đa 30 mục, mỗi mục không quá 80 ký tự.');
              return;
            }
            if (safetyNotes && safetyNotes.length > 5000) {
              ctrl.showError('Lưu ý an toàn không được vượt quá 5000 ký tự.');
              return;
            }

            ctrl.setBusy(true);
            try {
              await api(row ? `/admin/exercises/${encodeURIComponent(row.id)}` : '/admin/exercises', row ? 'PATCH' : 'POST', {
                name,
                equipmentId,
                difficulty,
                targetMuscles,
                description,
                instructions,
                safetyNotes,
                videoUrl,
                status,
              });
              ctrl.close();
              toast(row ? 'Đã cập nhật bài tập.' : 'Đã thêm bài tập mới.');
              await reloadWith({ page: row ? page : 1 });
            } catch (error) {
              ctrl.setBusy(false);
              ctrl.showError(error.message);
            }
          };
        },
      });
    };

    [root.querySelector('#create-item'), root.querySelector('#create-item-empty')].filter(Boolean).forEach((btn) => {
      btn.onclick = () => (tab === 'equipment' ? openEquipmentModal(null) : openExerciseModal(null));
    });
    root.querySelectorAll('.edit-eq').forEach((btn) => {
      btn.onclick = () => {
        const item = rows.find((r) => r.id === btn.dataset.id);
        if (item) openEquipmentModal(item);
      };
    });
    root.querySelectorAll('.edit-ex').forEach((btn) => {
      btn.onclick = () => {
        const item = rows.find((r) => r.id === btn.dataset.id);
        if (item) openExerciseModal(item);
      };
    });
    root.querySelectorAll('.preview-eq').forEach((btn) => {
      btn.onclick = () => {
        const item = rows.find((r) => r.id === btn.dataset.id);
        if (!item) return;
        openDrawer({
          title: item.name,
          subtitle: 'Xem trước hiển thị công khai trên App',
          bodyHtml: `<div class="stack-16">
            ${item.imageMediaId ? `<img src="${esc(publicMediaUrl(item.imageMediaId))}" alt="${esc(item.name)}" loading="lazy" decoding="async" style="width:100%;max-height:220px;object-fit:cover;border-radius:14px;border:1px solid var(--meta-border)" />` : ''}
            <div class="impact-box">
              <div class="impact-row"><span class="impact-key">Danh mục</span><span class="impact-val">${esc(item.category)}</span></div>
              <div class="impact-row"><span class="impact-key">Nhóm cơ</span><span class="impact-val">${esc((item.targetMuscles || []).join(', ') || '—')}</span></div>
              <div class="impact-divider"></div>
              <div><strong>Các bước sử dụng:</strong><ol class="rule-list" style="margin-top:6px">${(item.usageSteps || []).map((s) => `<li>${esc(s)}</li>`).join('')}</ol></div>
              ${item.safetyNotes ? `<div class="impact-divider"></div><div><strong>Lưu ý an toàn:</strong><p class="card-sub">${esc(item.safetyNotes)}</p></div>` : ''}
            </div>
          </div>`,
        });
      };
    });
  } catch (error) {
    shell({
      section,
      topbarActionsHtml,
      contentHtml: renderErrorState({ title: 'Không tải được thiết bị & bài tập', message: error.message }),
    });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderEquipmentPage({ root, params, shell });
  }
}
