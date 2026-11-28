import { api, buildQuery, getToken, uploadFormData, uploadRaw } from '../services/api.js';
import { debounce, esc, formatBytes, statusBadge } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderActionButton } from '../components/action-button.js';
import { bindDataTableSelection, renderDataTable } from '../components/data-table.js';
import { openDrawer } from '../components/drawer.js';
import { exportToExcel } from '../components/export.js';
import { openImageViewer } from '../components/image-viewer.js';
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
const ALLOWED_ICON_TYPES = new Set(['image/webp', 'image/png', 'image/jpeg']);
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const ALLOWED_VIDEO_TYPES = new Set(['video/mp4', 'video/webm', 'video/quicktime']);
const ALLOWED_VIDEO_EXTS = ['.mp4', '.webm', '.mov'];
const MAX_VIDEO_BYTES = 30 * 1024 * 1024;

const EQUIPMENT_ICON_PRESETS = Object.freeze([
  { key: 'dumbbell', label: 'Tạ đơn / Máy tập' },
  { key: 'barbell', label: 'Tạ đòn / Khung gánh' },
  { key: 'treadmill', label: 'Máy chạy bộ / Cardio' },
  { key: 'bike', label: 'Xe đạp tập' },
  { key: 'cable', label: 'Máy kéo cáp' },
  { key: 'bench', label: 'Ghế tập tạ' },
  { key: 'kettlebell', label: 'Tạ chuông' },
  { key: 'heartPulse', label: 'Tim mạch / HIIT' },
  { key: 'core', label: 'Thảm & Core' },
  { key: 'sliders', label: 'Phụ kiện / Hỗ trợ' },
]);
const EQUIPMENT_ICON_LABEL_MAP = new Map(EQUIPMENT_ICON_PRESETS.map((item) => [item.key, item.label]));

function getEquipmentIconLabel(key) {
  return EQUIPMENT_ICON_LABEL_MAP.get(key) || key || 'Mặc định';
}

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

function publicMediaThumbUrl(mediaId) {
  if (!mediaId) return '';
  return `${getApiBase()}/media/public/${encodeURIComponent(mediaId)}?size=120&v=${encodeURIComponent(mediaId)}`;
}

function renderEquipmentIconCellHtml(row) {
  if (row?.iconMediaId) {
    const thumb = resolveApiAssetUrl(row.iconThumbnailUrl) || publicMediaThumbUrl(row.iconMediaId);
    return `<div style="display:inline-flex;align-items:center;gap:8px">
      <span class="eq-icon-chip" style="overflow:hidden;padding:2px">
        <img src="${esc(thumb)}" alt="Icon ${esc(row.name || '')}" width="28" height="28" loading="lazy" decoding="async" style="width:100%;height:100%;object-fit:contain;border-radius:6px" />
      </span>
      <span class="person-sub">Icon tải lên</span>
    </div>`;
  }
  if (row?.iconKey) {
    return `<div style="display:inline-flex;align-items:center;gap:8px">
      <span class="eq-icon-chip">${icon(row.iconKey, 16)}</span>
      <span class="person-sub">${esc(getEquipmentIconLabel(row.iconKey))}</span>
    </div>`;
  }
  return `<div style="display:inline-flex;align-items:center;gap:8px">
    <span class="eq-icon-chip is-muted">${icon('dumbbell', 16)}</span>
    <span class="person-sub">Mặc định</span>
  </div>`;
}

async function uploadPublicEquipmentIcon(file) {
  if (!file) throw new Error('Vui lòng chọn tệp icon để tải lên.');
  const mimeType = String(file.type || '').toLowerCase();
  if (!ALLOWED_ICON_TYPES.has(mimeType)) {
    throw new Error('Chỉ hỗ trợ icon định dạng WebP (.webp), PNG (.png) hoặc JPEG (.jpg).');
  }
  if (Number(file.size || 0) > MAX_IMAGE_BYTES) {
    throw new Error('Tệp icon vượt quá giới hạn tối đa 5 MB.');
  }
  const payload = await uploadRaw('/media/images', file, mimeType, {
    headers: {
      'x-image-purpose': 'SYSTEM_ICON',
      'x-file-name': encodeURIComponent(file.name || 'equipment-icon').slice(0, 200),
    },
  });
  const id = payload?.data?.id;
  if (!id) throw new Error('Máy chủ không trả về mã icon hợp lệ.');
  return {
    id,
    publicUrl: resolveApiAssetUrl(payload?.data?.publicUrl) || publicMediaUrl(id),
    thumbnailUrl: resolveApiAssetUrl(payload?.data?.thumbnailUrl) || publicMediaThumbUrl(id),
  };
}

function publicExerciseVideoUrl(mediaId) {
  if (!mediaId) return '';
  return `${getApiBase()}/media/videos/public/${encodeURIComponent(mediaId)}?v=${encodeURIComponent(mediaId)}`;
}

function resolveApiAssetUrl(pathOrUrl) {
  const clean = String(pathOrUrl || '').trim();
  if (!clean) return '';
  if (clean.startsWith('/api/v1')) {
    return `${getApiBase()}${clean.slice('/api/v1'.length)}`;
  }
  return clean;
}

function isValidHttpUrl(value) {
  const clean = String(value || '').trim();
  if (!clean) return false;
  try {
    const parsed = new URL(clean);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch {
    return false;
  }
}

function extractYouTubeId(rawUrl) {
  const clean = String(rawUrl || '').trim();
  if (!clean) return null;
  try {
    const parsed = new URL(clean);
    const host = parsed.hostname.toLowerCase();
    if (host === 'youtu.be') {
      const id = parsed.pathname.split('/').filter(Boolean)[0] || '';
      return /^[A-Za-z0-9_-]{6,20}$/.test(id) ? id : null;
    }
    if (host === 'youtube.com' || host.endsWith('.youtube.com')
      || host === 'youtube-nocookie.com' || host.endsWith('.youtube-nocookie.com')) {
      const vParam = parsed.searchParams.get('v');
      if (vParam && /^[A-Za-z0-9_-]{6,20}$/.test(vParam)) return vParam;
      const parts = parsed.pathname.split('/').filter(Boolean);
      const markerIdx = parts.findIndex((p) => p === 'embed' || p === 'shorts' || p === 'live');
      if (markerIdx >= 0 && parts[markerIdx + 1] && /^[A-Za-z0-9_-]{6,20}$/.test(parts[markerIdx + 1])) {
        return parts[markerIdx + 1];
      }
    }
  } catch {
    return null;
  }
  return null;
}

function isDirectPlayableVideoUrl(rawUrl) {
  const clean = String(rawUrl || '').trim();
  if (!clean) return false;
  if (clean.includes('/media/videos/public/')) return true;
  try {
    const parsed = new URL(clean, 'http://localhost');
    return /\.(mp4|webm|mov|m4v)(?:$|\?)/i.test(parsed.pathname);
  } catch {
    return false;
  }
}

function resolveExerciseVideoInfo(row, eqVideoById = new Map()) {
  if (row?.videoMediaId) {
    const streamUrl = resolveApiAssetUrl(row.videoStreamUrl) || publicExerciseVideoUrl(row.videoMediaId);
    return {
      source: 'UPLOAD',
      url: streamUrl,
      label: 'Video tải lên',
      badgeClass: 'meta-badge-success',
      iconName: 'video',
      subtext: row.videoMeta?.sizeBytes ? formatBytes(row.videoMeta.sizeBytes) : (row.videoMeta?.originalName || 'MP4 / WebM'),
    };
  }
  if (row?.videoUrl) {
    const ytId = extractYouTubeId(row.videoUrl);
    return {
      source: ytId ? 'YOUTUBE' : 'URL',
      url: row.videoUrl,
      label: ytId ? 'YouTube' : 'Link video',
      badgeClass: 'meta-badge-info',
      iconName: 'play',
      subtext: ytId ? 'Nhúng trực tiếp' : 'Liên kết ngoài',
    };
  }
  const eqVideo = row?.equipmentVideoUrl || eqVideoById.get(row?.equipmentId) || '';
  if (eqVideo) {
    return {
      source: 'EQUIPMENT',
      url: eqVideo,
      label: 'Theo thiết bị',
      badgeClass: 'meta-badge-neutral',
      iconName: 'video',
      subtext: 'Dùng video máy tập',
    };
  }
  return {
    source: 'NONE',
    url: '',
    label: 'Chưa có',
    badgeClass: 'meta-badge-neutral',
    iconName: '',
    subtext: '',
  };
}

function renderVideoPlayerHtml(sourceUrl, { title = 'Video hướng dẫn động tác', emptyText = 'Chưa có video hướng dẫn cho bài tập này.' } = {}) {
  const resolved = resolveApiAssetUrl(sourceUrl);
  if (!resolved) {
    return `<div class="ex-video-preview-frame">
      <div class="ex-video-empty">
        ${icon('video', 28)}
        <span>${esc(emptyText)}</span>
      </div>
    </div>`;
  }
  const ytId = extractYouTubeId(resolved);
  if (ytId) {
    const embedUrl = `https://www.youtube-nocookie.com/embed/${encodeURIComponent(ytId)}?rel=0`;
    return `<div class="stack-8">
      <div class="ex-video-preview-frame">
        <iframe src="${esc(embedUrl)}" title="${esc(title)}" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen loading="lazy"></iframe>
      </div>
      <div style="display:flex;justify-content:flex-end">
        <a class="btn btn-ghost btn-sm" href="${esc(resolved)}" target="_blank" rel="noopener noreferrer">${icon('externalLink', 14)} Mở trên YouTube</a>
      </div>
    </div>`;
  }
  if (isDirectPlayableVideoUrl(resolved)) {
    return `<div class="stack-8">
      <div class="ex-video-preview-frame">
        <video controls preload="metadata" playsinline src="${esc(resolved)}">
          Trình duyệt của bạn không hỗ trợ phát video trực tiếp.
        </video>
      </div>
      <div style="display:flex;justify-content:flex-end">
        <a class="btn btn-ghost btn-sm" href="${esc(resolved)}" target="_blank" rel="noopener noreferrer">${icon('externalLink', 14)} Mở video trong tab mới</a>
      </div>
    </div>`;
  }
  return `<div class="ex-video-preview-frame">
    <div class="ex-video-external-card">
      ${icon('play', 26)}
      <span>Liên kết video bên ngoài (không hỗ trợ nhúng trực tiếp)</span>
      <a class="btn btn-graphite btn-sm" href="${esc(resolved)}" target="_blank" rel="noopener noreferrer">${icon('externalLink', 14)} Mở video hướng dẫn</a>
    </div>
  </div>`;
}

async function uploadExerciseVideo(file, { onProgress } = {}) {
  if (!file) throw new Error('Vui lòng chọn tệp video để tải lên.');
  const mimeType = String(file.type || '').toLowerCase();
  const lowerName = String(file.name || '').toLowerCase();
  const hasAllowedExt = ALLOWED_VIDEO_EXTS.some((ext) => lowerName.endsWith(ext));
  if (!ALLOWED_VIDEO_TYPES.has(mimeType) && !hasAllowedExt) {
    throw new Error('Chỉ hỗ trợ video định dạng MP4 (.mp4), WebM (.webm) hoặc MOV (.mov).');
  }
  if (Number(file.size || 0) <= 0) {
    throw new Error('Tệp video trống hoặc không đọc được.');
  }
  if (Number(file.size || 0) > MAX_VIDEO_BYTES) {
    throw new Error('Video vượt quá giới hạn tối đa 30 MB.');
  }

  const formData = new FormData();
  formData.append('purpose', 'EXERCISE');
  formData.append('file', file, file.name || 'exercise-video.mp4');

  const payload = await uploadFormData('/media/videos', formData, { onProgress });
  const data = payload?.data;
  if (!data?.id) {
    throw new Error('Máy chủ không trả về mã video hợp lệ.');
  }
  return {
    id: data.id,
    publicUrl: resolveApiAssetUrl(data.publicUrl) || publicExerciseVideoUrl(data.id),
    originalName: data.originalName || file.name || 'exercise-video.mp4',
    mimeType: data.mimeType || mimeType || 'video/mp4',
    sizeBytes: Number(data.sizeBytes ?? file.size ?? 0),
  };
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
  const hasVideoFilter = params?.get('hasVideo') || '';
  const page = Math.max(1, Number(params?.get('page')) || 1);
  const pageSize = Math.max(1, Number(params?.get('pageSize')) || 10);

  const hasFilter = tab === 'equipment'
    ? Boolean(search || statusFilter || categoryFilter)
    : Boolean(search || statusFilter || difficultyFilter || equipmentIdFilter || hasVideoFilter);

  const buildFilterHtml = (allEquipment = [], canExport = false) => (tab === 'equipment'
    ? `<form class="filter-bar" id="cat-filter-form">
      <input type="search" id="cat-search" class="form-control filter-grow" placeholder="Tìm tên thiết bị, danh mục hoặc mô tả…" value="${esc(search)}" aria-label="Tìm thiết bị" />
      <input type="text" id="cat-category" class="form-control filter-fixed" placeholder="Danh mục (vd: Cardio)…" value="${esc(categoryFilter)}" aria-label="Lọc danh mục thiết bị" />
      <select id="cat-status" class="form-select filter-fixed" aria-label="Lọc trạng thái thiết bị">
        <option value="" ${!statusFilter ? 'selected' : ''}>Tất cả trạng thái</option>
        <option value="ACTIVE" ${statusFilter === 'ACTIVE' ? 'selected' : ''}>Hiển thị</option>
        <option value="HIDDEN" ${statusFilter === 'HIDDEN' ? 'selected' : ''}>Đang ẩn</option>
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
        <option value="BEGINNER" ${difficultyFilter === 'BEGINNER' ? 'selected' : ''}>Cơ bản</option>
        <option value="INTERMEDIATE" ${difficultyFilter === 'INTERMEDIATE' ? 'selected' : ''}>Trung bình</option>
        <option value="ADVANCED" ${difficultyFilter === 'ADVANCED' ? 'selected' : ''}>Nâng cao</option>
      </select>
      <select id="cat-equipment" class="form-select filter-fixed" aria-label="Lọc theo thiết bị liên kết">
        <option value="" ${!equipmentIdFilter ? 'selected' : ''}>Tất cả thiết bị</option>
        ${allEquipment.map((eq) => `<option value="${esc(eq.id)}" ${equipmentIdFilter === eq.id ? 'selected' : ''}>${esc(eq.name)}</option>`).join('')}
      </select>
      <select id="cat-has-video" class="form-select filter-fixed" aria-label="Lọc bài tập theo video hướng dẫn">
        <option value="" ${!hasVideoFilter ? 'selected' : ''}>Tất cả video</option>
        <option value="WITH_VIDEO" ${hasVideoFilter === 'WITH_VIDEO' ? 'selected' : ''}>Đã có video</option>
        <option value="WITHOUT_VIDEO" ${hasVideoFilter === 'WITHOUT_VIDEO' ? 'selected' : ''}>Chưa có video</option>
      </select>
      <select id="cat-status" class="form-select filter-fixed" aria-label="Lọc trạng thái bài tập">
        <option value="" ${!statusFilter ? 'selected' : ''}>Tất cả trạng thái</option>
        <option value="ACTIVE" ${statusFilter === 'ACTIVE' ? 'selected' : ''}>Hiển thị</option>
        <option value="HIDDEN" ${statusFilter === 'HIDDEN' ? 'selected' : ''}>Đang ẩn</option>
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
    const nextHasVideo = patch.hasVideo !== undefined ? patch.hasVideo : (root.querySelector('#cat-has-video')?.value || '');
    const nextPage = patch.page !== undefined ? patch.page : page;
    const nextPageSize = patch.pageSize !== undefined ? patch.pageSize : pageSize;

    const nextParams = new URLSearchParams();
    if (nextTab !== 'equipment') nextParams.set('tab', nextTab);
    if (nextSearch) nextParams.set('search', nextSearch);
    if (nextStatus) nextParams.set('status', nextStatus);
    if (nextTab === 'equipment' && nextCategory) nextParams.set('category', nextCategory);
    if (nextTab === 'exercises' && nextDifficulty) nextParams.set('difficulty', nextDifficulty);
    if (nextTab === 'exercises' && nextEquipmentId) nextParams.set('equipmentId', nextEquipmentId);
    if (nextTab === 'exercises' && nextHasVideo) nextParams.set('hasVideo', nextHasVideo);
    if (nextPage > 1) nextParams.set('page', String(nextPage));
    if (nextPageSize !== 10) nextParams.set('pageSize', String(nextPageSize));

    updateQuery({
      tab: nextTab !== 'equipment' ? nextTab : null,
      search: nextSearch || null,
      status: nextStatus || null,
      category: nextTab === 'equipment' && nextCategory ? nextCategory : null,
      difficulty: nextTab === 'exercises' && nextDifficulty ? nextDifficulty : null,
      equipmentId: nextTab === 'exercises' && nextEquipmentId ? nextEquipmentId : null,
      hasVideo: nextTab === 'exercises' && nextHasVideo ? nextHasVideo : null,
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
        hasVideo: hasVideoFilter,
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
    const eqVideoById = new Map(allEquipment.map((item) => [item.id, item.videoUrl || null]));

    const tableHtml = tab === 'equipment'
      ? renderDataTable({
        columns: [
          {
            label: 'Thiết bị',
            render: (row) => `<div class="person-cell">
              ${row.imageMediaId
                ? `<img src="${esc(publicMediaUrl(row.imageMediaId))}" alt="${esc(row.name)}" width="40" height="40" loading="lazy" decoding="async" style="width:40px;height:40px;object-fit:cover;border-radius:10px;border:1px solid var(--meta-border);flex-shrink:0" />`
                : row.iconMediaId
                  ? `<img src="${esc(resolveApiAssetUrl(row.iconThumbnailUrl) || publicMediaThumbUrl(row.iconMediaId))}" alt="${esc(row.name)}" width="40" height="40" loading="lazy" decoding="async" style="width:40px;height:40px;object-fit:contain;padding:4px;border-radius:10px;background:var(--meta-surface-raised);border:1px solid var(--meta-border);flex-shrink:0" />`
                  : `<span class="meta-avatar">${icon(row.iconKey || 'dumbbell', 16)}</span>`}
              <div>
                <span class="person-name">${esc(row.name)}</span>
                <span class="person-sub">${esc(row.safetyNotes || row.description || '—')}</span>
              </div>
            </div>`,
          },
          {
            label: 'Icon',
            render: (row) => renderEquipmentIconCellHtml(row),
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
            label: 'Video hướng dẫn',
            render: (row) => {
              const video = resolveExerciseVideoInfo(row, eqVideoById);
              if (video.source === 'NONE') {
                return '<span class="meta-badge meta-badge-neutral">Chưa có</span>';
              }
              return `<span class="meta-badge ${video.badgeClass}">${video.iconName ? icon(video.iconName, 13) : ''} ${esc(video.label)}</span>${video.subtext ? `<span class="person-sub">${esc(video.subtext)}</span>` : ''}`;
            },
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
              label: 'Xem trước bài tập & Video',
              className: 'preview-ex',
              permission: 'catalog:read',
              attrs: `data-id="${esc(row.id)}"`,
            })}
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
            description: 'Thêm bài tập vào thư viện động tác kèm video hướng dẫn để đồng bộ cho Coach và Member.',
            ctaLabel: 'Thêm bài tập',
            ctaId: 'create-item-empty',
          }),
        paginationHtml: renderPagination({ ...pagination, prefix: 'ex' }),
        ariaLabel: 'Thư viện bài tập',
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

    ['#cat-status', '#cat-difficulty', '#cat-equipment', '#cat-has-video'].forEach((sel) => {
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
        hasVideo: '',
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
              { label: 'Icon thiết bị', value: (r) => (r.iconMediaId ? (resolveApiAssetUrl(r.iconUrl) || publicMediaUrl(r.iconMediaId)) : (r.iconKey ? getEquipmentIconLabel(r.iconKey) : 'Mặc định')) },
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
              { label: 'Video hướng dẫn', value: (r) => resolveExerciseVideoInfo(r, eqVideoById).url || 'Chưa có' },
              { label: 'Trạng thái', value: (r) => (r.status === 'ACTIVE' ? 'Hiển thị' : 'Đang ẩn') },
            ],
            rows: targetRows,
          });
        if (ok) toast(`Đã xuất ${targetRows.length} dòng ra file Excel (.csv).`);
      };
    }

    const openEquipmentModal = (row) => {
      let currentMediaId = row?.imageMediaId || null;
      let currentIconMediaId = row?.iconMediaId || null;
      let currentIconKey = row?.iconKey || '';
      let uploadingImage = false;
      let uploadingIcon = false;

      const renderImagePreviewHtml = (mediaId) => {
        if (mediaId) {
          return `<img id="eq-image-preview" class="eq-photo-preview-box" src="${esc(publicMediaUrl(mediaId))}" alt="Ảnh xem trước thiết bị" width="96" height="96" loading="lazy" decoding="async" />`;
        }
        const fallbackThumb = currentIconMediaId
          ? (row?.iconMediaId === currentIconMediaId && row?.iconThumbnailUrl
            ? resolveApiAssetUrl(row.iconThumbnailUrl)
            : publicMediaThumbUrl(currentIconMediaId))
          : '';
        return `<div class="eq-photo-preview-box is-empty" aria-hidden="true">${fallbackThumb
          ? `<img src="${esc(fallbackThumb)}" alt="" width="44" height="44" style="width:44px;height:44px;object-fit:contain;border-radius:10px" />`
          : icon(currentIconKey || 'dumbbell', 30)}</div>`;
      };

      const renderIconPreviewHtml = () => {
        const iconThumb = currentIconMediaId
          ? (row?.iconMediaId === currentIconMediaId && row?.iconThumbnailUrl
            ? resolveApiAssetUrl(row.iconThumbnailUrl)
            : publicMediaThumbUrl(currentIconMediaId))
          : '';
        const visualHtml = iconThumb
          ? `<img id="eq-icon-preview-img" src="${esc(iconThumb)}" alt="Icon thiết bị" width="48" height="48" style="cursor:pointer" />`
          : icon(currentIconKey || 'dumbbell', 22);
        const titleText = currentIconMediaId
          ? 'Icon ảnh tải lên (WebP)'
          : currentIconKey
            ? getEquipmentIconLabel(currentIconKey)
            : 'Icon mặc định';
        const subText = currentIconMediaId
          ? 'Ưu tiên hiển thị ảnh icon này'
          : currentIconKey
            ? 'Icon vector có sẵn'
            : 'Chọn icon có sẵn hoặc tải ảnh icon lên';
        return `<div class="eq-icon-preview-row">
          <div class="eq-icon-preview-box">${visualHtml}</div>
          <div class="ex-video-meta-info" style="flex:1">
            <span class="ex-video-meta-name">${esc(titleText)}</span>
            <span class="ex-video-meta-sub">${esc(subText)}</span>
          </div>
          ${currentIconMediaId
            ? `<button type="button" class="btn btn-ghost btn-sm text-danger" id="eq-icon-remove" aria-label="Gỡ ảnh icon">${icon('trash', 14)} Gỡ</button>`
            : currentIconKey
              ? `<button type="button" class="btn btn-ghost btn-sm" id="eq-icon-reset-key" aria-label="Đặt lại icon mặc định">Mặc định</button>`
              : ''}
        </div>`;
      };

      openModal({
        maxWidth: '960px',
        title: row ? `Sửa thiết bị: ${row.name}` : 'Thêm thiết bị phòng tập',
        subtitle: 'Ảnh công khai, icon hiển thị, hướng dẫn sử dụng và lưu ý an toàn',
        bodyHtml: `<form id="equipment-form" novalidate>
          <div class="meta-modal-body">
            <div class="meta-modal-horizontal-layout">
              <div class="modal-col-left">
                <div class="edit-avatar-horizontal">
                  <div class="edit-avatar-preview-wrap" id="eq-photo-trigger" title="Xem ảnh thiết bị">
                    <div id="eq-image-preview-wrap">${renderImagePreviewHtml(currentMediaId)}</div>
                    <span class="avatar-zoom-badge" id="eq-photo-zoom-badge" ${currentMediaId ? '' : 'hidden'}>${icon('eye', 12)}</span>
                  </div>
                  <div class="meta-avatar-dropdown-wrap" id="eq-photo-dropdown-wrap">
                    <input id="eq-image-file" type="file" accept="image/jpeg,image/png" hidden />
                    <button type="button" class="btn btn-graphite btn-sm meta-avatar-trigger-btn" id="btn-eq-photo-dropdown" aria-expanded="false">
                      ${icon('image', 14)}
                      <span>Tùy chọn ảnh</span>
                      ${icon('chevronDown', 13)}
                    </button>
                    <div class="meta-avatar-dropdown-menu" id="eq-photo-dropdown-menu" hidden>
                      <button type="button" class="meta-dropdown-item" id="btn-eq-view-photo" ${currentMediaId ? '' : 'hidden'}>
                        ${icon('eye', 14)} <span>Xem ảnh đầy đủ</span>
                      </button>
                      <button type="button" class="meta-dropdown-item" id="btn-eq-pick-photo">
                        ${icon('upload', 14)} <span id="eq-pick-photo-text">${currentMediaId ? 'Đổi ảnh thiết bị' : 'Tải ảnh mới'}</span>
                      </button>
                      <div class="meta-dropdown-divider" id="eq-photo-divider" ${currentMediaId ? '' : 'hidden'}></div>
                      <button type="button" class="meta-dropdown-item text-danger" id="eq-image-remove" ${currentMediaId ? '' : 'hidden'}>
                        ${icon('trash', 14)} <span>Gỡ ảnh hiện tại</span>
                      </button>
                    </div>
                    <div class="text-xs text-muted mt-1">JPEG / PNG tối đa 5 MB</div>
                    <div class="field-hint mt-1" id="eq-image-status" aria-live="polite"></div>
                  </div>
                </div>

                <div class="field">
                  <label class="field-label" for="eq-name">Tên thiết bị <span class="text-danger">*</span></label>
                  <input id="eq-name" class="form-control" name="name" maxlength="120" value="${esc(row?.name || '')}" placeholder="Ví dụ: Máy chạy bộ Technogym" required />
                </div>

                <div class="field">
                  <label class="field-label" for="eq-cat">Danh mục <span class="text-danger">*</span></label>
                  <input id="eq-cat" class="form-control" name="category" maxlength="80" value="${esc(row?.category || '')}" placeholder="Cardio / Machine / Free Weight" required />
                </div>

                <div class="field">
                  <label class="field-label" for="eq-status">Trạng thái hiển thị</label>
                  <select id="eq-status" class="form-select" name="status">
                    <option value="ACTIVE" ${row?.status !== 'HIDDEN' ? 'selected' : ''}>Hiển thị</option>
                    <option value="HIDDEN" ${row?.status === 'HIDDEN' ? 'selected' : ''}>Ẩn</option>
                  </select>
                </div>
              </div>

              <div class="modal-col-right">
                <div class="modal-section-card">
                  <div class="meta-form-section-header">
                    <span class="meta-form-section-title">Icon hiển thị, hướng dẫn & an toàn</span>
                    <span class="meta-form-section-desc">Cấu hình icon đại diện, nhóm cơ mục tiêu, các bước vận hành và lưu ý an toàn</span>
                  </div>

                  <div class="stack-12" style="margin-bottom:14px">
                    <div style="display:flex;align-items:center;justify-content:space-between;gap:8px;flex-wrap:wrap">
                      <span class="field-label" style="margin:0">Icon thiết bị</span>
                      <div style="display:flex;align-items:center;gap:8px">
                        <input id="eq-icon-file" type="file" accept="image/webp,image/png,image/jpeg" hidden />
                        <button type="button" class="btn btn-graphite btn-sm" id="eq-icon-pick">
                          ${icon('upload', 14)} ${currentIconMediaId ? 'Đổi ảnh icon' : 'Tải ảnh icon (WebP/PNG/JPG)'}
                        </button>
                      </div>
                    </div>
                    <div id="eq-icon-preview-wrap">${renderIconPreviewHtml()}</div>
                    <span class="field-error" id="eq-icon-error" aria-live="polite"></span>

                    <div class="field">
                      <span class="field-label">Hoặc chọn icon vector có sẵn</span>
                      <div class="eq-icon-preset-grid" id="eq-icon-presets" role="group" aria-label="Chọn icon thiết bị có sẵn">
                        ${EQUIPMENT_ICON_PRESETS.map((p) => `
                          <button type="button" class="eq-icon-preset-btn ${!currentIconMediaId && currentIconKey === p.key ? 'active' : ''}" data-eq-icon-key="${esc(p.key)}" title="${esc(p.label)}" aria-label="${esc(p.label)}" aria-pressed="${!currentIconMediaId && currentIconKey === p.key ? 'true' : 'false'}">
                            ${icon(p.key, 18)}
                          </button>
                        `).join('')}
                      </div>
                    </div>
                  </div>

                  <hr class="meta-form-divider" />

                  <div class="meta-form-grid-2">
                    <div class="field">
                      <label class="field-label" for="eq-muscles">Nhóm cơ mục tiêu (phân tách bằng dấu phẩy)</label>
                      <input id="eq-muscles" class="form-control" name="targetMuscles" value="${esc((row?.targetMuscles || []).join(', '))}" placeholder="Ví dụ: Ngực, Tay sau" />
                    </div>
                    <div class="field">
                      <label class="field-label" for="eq-video">Video URL</label>
                      <input id="eq-video" class="form-control" name="videoUrl" type="url" value="${esc(row?.videoUrl || '')}" placeholder="https://…" />
                    </div>
                  </div>

                  <div class="field">
                    <label class="field-label" for="eq-desc">Mô tả thiết bị</label>
                    <textarea id="eq-desc" class="form-control" name="description" rows="2" maxlength="5000" placeholder="Công năng chính và đặc điểm kỹ thuật của máy…">${esc(row?.description || '')}</textarea>
                  </div>

                  <div class="field">
                    <label class="field-label" for="eq-steps">Các bước sử dụng (mỗi dòng 1 bước) <span class="text-danger">*</span></label>
                    <textarea id="eq-steps" class="form-control" name="steps" rows="4" required placeholder="Bước 1: Điều chỉnh ghế ngồi&#10;Bước 2: Chọn mức tạ phù hợp">${esc((row?.usageSteps || []).join('\n'))}</textarea>
                  </div>

                  <div class="field">
                    <label class="field-label" for="eq-safety">Lưu ý an toàn</label>
                    <textarea id="eq-safety" class="form-control" name="safetyNotes" rows="2" maxlength="5000" placeholder="Cảnh báo tư thế, khóa chốt an toàn…">${esc(row?.safetyNotes || '')}</textarea>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="meta-modal-footer">
            <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
            <button type="submit" class="btn btn-primary" data-modal-submit style="min-width:140px;">${icon('check', 16)} ${row ? 'Lưu thiết bị' : 'Tạo thiết bị'}</button>
          </div>
        </form>`,
        onMount(ctrl) {
          const form = ctrl.dialog.querySelector('#equipment-form');
          const fileInput = form.querySelector('#eq-image-file');
          const statusEl = form.querySelector('#eq-image-status');
          const previewWrap = form.querySelector('#eq-image-preview-wrap');
          const photoTrigger = form.querySelector('#eq-photo-trigger');
          const zoomBadge = form.querySelector('#eq-photo-zoom-badge');
          const dropdownWrap = form.querySelector('#eq-photo-dropdown-wrap');
          const dropdownBtn = form.querySelector('#btn-eq-photo-dropdown');
          const dropdownMenu = form.querySelector('#eq-photo-dropdown-menu');
          const viewPhotoBtn = form.querySelector('#btn-eq-view-photo');
          const pickPhotoBtn = form.querySelector('#btn-eq-pick-photo');
          const pickPhotoText = form.querySelector('#eq-pick-photo-text');
          const photoDivider = form.querySelector('#eq-photo-divider');
          const removePhotoBtn = form.querySelector('#eq-image-remove');
          const iconFileInput = form.querySelector('#eq-icon-file');
          const iconPickBtn = form.querySelector('#eq-icon-pick');
          const iconPreviewWrap = form.querySelector('#eq-icon-preview-wrap');
          const iconErrorEl = form.querySelector('#eq-icon-error');
          const presetBtns = form.querySelectorAll('[data-eq-icon-key]');

          const closePhotoDropdown = () => {
            if (dropdownMenu) {
              dropdownMenu.hidden = true;
              if (dropdownBtn) dropdownBtn.setAttribute('aria-expanded', 'false');
            }
          };

          const openCurrentPhoto = () => {
            if (!currentMediaId) return;
            openImageViewer({
              src: publicMediaUrl(currentMediaId),
              title: (form.querySelector('[name="name"]')?.value || '').trim() || 'Ảnh thiết bị',
            });
          };

          const syncPreview = () => {
            const hasPhoto = Boolean(currentMediaId);
            if (previewWrap) {
              previewWrap.innerHTML = renderImagePreviewHtml(currentMediaId);
            }
            if (zoomBadge) zoomBadge.hidden = !hasPhoto;
            if (viewPhotoBtn) viewPhotoBtn.hidden = !hasPhoto;
            if (photoDivider) photoDivider.hidden = !hasPhoto;
            if (removePhotoBtn) removePhotoBtn.hidden = !hasPhoto;
            if (pickPhotoText) pickPhotoText.textContent = hasPhoto ? 'Đổi ảnh thiết bị' : 'Tải ảnh mới';
          };

          if (photoTrigger) {
            photoTrigger.onclick = () => {
              if (!currentMediaId) return;
              closePhotoDropdown();
              openCurrentPhoto();
            };
          }

          if (dropdownBtn && dropdownMenu) {
            dropdownBtn.onclick = (e) => {
              e?.stopPropagation?.();
              const willOpen = Boolean(dropdownMenu.hidden);
              dropdownMenu.hidden = !willOpen;
              dropdownBtn.setAttribute('aria-expanded', willOpen ? 'true' : 'false');
            };
            ctrl.dialog.addEventListener?.('click', (e) => {
              if (!dropdownMenu.hidden && !dropdownWrap?.contains?.(e?.target)) {
                closePhotoDropdown();
              }
            });
          }

          if (viewPhotoBtn) {
            viewPhotoBtn.onclick = () => {
              closePhotoDropdown();
              openCurrentPhoto();
            };
          }

          if (pickPhotoBtn) {
            pickPhotoBtn.onclick = () => {
              closePhotoDropdown();
              fileInput?.click();
            };
          }

          if (removePhotoBtn) {
            removePhotoBtn.onclick = () => {
              closePhotoDropdown();
              currentMediaId = null;
              if (fileInput) fileInput.value = '';
              if (statusEl) statusEl.textContent = 'Đã gỡ ảnh khỏi thiết bị.';
              syncPreview();
            };
          }

          const syncIconPreview = () => {
            if (iconPreviewWrap) {
              iconPreviewWrap.innerHTML = renderIconPreviewHtml();
              const iconImgEl = iconPreviewWrap.querySelector('#eq-icon-preview-img');
              if (iconImgEl && currentIconMediaId) {
                iconImgEl.onclick = () => openImageViewer({
                  src: publicMediaUrl(currentIconMediaId),
                  title: `Icon · ${(form.querySelector('[name="name"]')?.value || '').trim() || 'Thiết bị'}`,
                });
              }
              const removeIconBtn = iconPreviewWrap.querySelector('#eq-icon-remove');
              if (removeIconBtn) {
                removeIconBtn.onclick = () => {
                  currentIconMediaId = null;
                  if (iconFileInput) iconFileInput.value = '';
                  if (iconErrorEl) iconErrorEl.textContent = '';
                  syncIconPreview();
                  if (!currentMediaId) syncPreview();
                };
              }
              const resetKeyBtn = iconPreviewWrap.querySelector('#eq-icon-reset-key');
              if (resetKeyBtn) {
                resetKeyBtn.onclick = () => {
                  currentIconKey = '';
                  syncIconPreview();
                  if (!currentMediaId) syncPreview();
                };
              }
            }
            if (iconPickBtn) {
              iconPickBtn.innerHTML = `${icon('upload', 14)} ${currentIconMediaId ? 'Đổi ảnh icon' : 'Tải ảnh icon (WebP/PNG/JPG)'}`;
            }
            presetBtns.forEach((btn) => {
              const isSelected = !currentIconMediaId && currentIconKey === btn.dataset.eqIconKey;
              btn.classList.toggle('active', isSelected);
              btn.setAttribute('aria-pressed', isSelected ? 'true' : 'false');
            });
          };

          syncPreview();
          syncIconPreview();

          presetBtns.forEach((btn) => {
            btn.onclick = () => {
              const key = btn.dataset.eqIconKey || '';
              currentIconMediaId = null;
              currentIconKey = currentIconKey === key ? '' : key;
              if (iconErrorEl) iconErrorEl.textContent = '';
              syncIconPreview();
              if (!currentMediaId) syncPreview();
            };
          });

          if (iconPickBtn && iconFileInput) {
            iconPickBtn.onclick = () => {
              if (!uploadingIcon) iconFileInput.click();
            };
          }

          if (iconFileInput) {
            iconFileInput.onchange = async () => {
              const file = iconFileInput.files?.[0];
              iconFileInput.value = '';
              if (!file) return;
              if (iconErrorEl) iconErrorEl.textContent = '';
              ctrl.showError('');
              uploadingIcon = true;
              ctrl.setBusy(true);
              try {
                const uploaded = await uploadPublicEquipmentIcon(file);
                currentIconMediaId = uploaded.id;
                syncIconPreview();
                if (!currentMediaId) syncPreview();
                toast('Đã tải icon thiết bị lên thành công.', 'success');
              } catch (err) {
                if (iconErrorEl) iconErrorEl.textContent = err.message;
                ctrl.showError(err.message);
              } finally {
                uploadingIcon = false;
                ctrl.setBusy(false);
              }
            };
          }

          if (fileInput) {
            fileInput.onchange = async () => {
              const file = fileInput.files?.[0];
              if (!file) return;
              ctrl.showError('');
              uploadingImage = true;
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
                uploadingImage = false;
              }
            };
          }

          form.onsubmit = async (event) => {
            event.preventDefault();
            ctrl.showError('');
            if (uploadingImage || uploadingIcon) {
              ctrl.showError('Tệp hình ảnh đang được tải lên, vui lòng đợi hoàn tất.');
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
                iconKey: currentIconKey || null,
                iconMediaId: currentIconMediaId || null,
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
      let currentVideoMediaId = row?.videoMediaId || null;
      let currentVideoMeta = row?.videoMeta || null;
      let currentVideoUrl = row?.videoUrl || '';
      let videoMode = currentVideoMediaId ? 'UPLOAD' : 'URL';
      let uploadingVideo = false;

      openModal({
        maxWidth: '960px',
        title: row ? `Sửa bài tập: ${row.name}` : 'Thêm bài tập mới',
        subtitle: 'Cấu hình video hướng dẫn động tác (tải file lên hoặc nhập link YouTube/MP4), thiết bị liên kết và hướng dẫn kỹ thuật',
        bodyHtml: `<form id="exercise-form" novalidate>
          <div class="meta-modal-body">
            <div class="meta-modal-horizontal-layout">
              <!-- Cột trái: Video hướng dẫn & Thông tin nhận diện cơ bản -->
              <div class="modal-col-left">
                <div class="ex-video-panel">
                  <div style="display:flex;align-items:center;justify-content:space-between;gap:8px">
                    <span class="field-label" style="margin:0">Video hướng dẫn động tác</span>
                    <span class="meta-badge meta-badge-neutral">MP4 / WebM / YouTube</span>
                  </div>

                  <div class="ex-video-mode-tabs" role="tablist" aria-label="Nguồn video hướng dẫn">
                    <button type="button" class="ex-video-mode-btn ${videoMode === 'UPLOAD' ? 'active' : ''}" id="ex-mode-upload" data-video-mode="UPLOAD" role="tab" aria-selected="${videoMode === 'UPLOAD' ? 'true' : 'false'}">
                      ${icon('upload', 15)} Tải video lên
                    </button>
                    <button type="button" class="ex-video-mode-btn ${videoMode === 'URL' ? 'active' : ''}" id="ex-mode-url" data-video-mode="URL" role="tab" aria-selected="${videoMode === 'URL' ? 'true' : 'false'}">
                      ${icon('link', 15)} Nhập link URL
                    </button>
                  </div>

                  <div id="ex-video-preview-wrap"></div>

                  <div id="ex-video-upload-box" ${videoMode === 'UPLOAD' ? '' : 'hidden'}>
                    <input id="ex-video-file" type="file" accept="video/mp4,video/webm,video/quicktime,.mp4,.webm,.mov" style="display:none" />
                    <div id="ex-video-upload-meta"></div>
                    <div class="ex-video-upload-progress" id="ex-video-progress-wrap" hidden>
                      <div style="display:flex;justify-content:space-between;font-size:12px;color:var(--meta-text-secondary)">
                        <span id="ex-video-progress-label">Đang tải video lên…</span>
                        <span id="ex-video-progress-pct" class="tabular">0%</span>
                      </div>
                      <div class="ex-video-progress-track">
                        <div class="ex-video-progress-fill" id="ex-video-progress-fill"></div>
                      </div>
                    </div>
                    <div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:8px">
                      <button type="button" class="btn btn-graphite btn-sm" id="ex-video-pick-btn">
                        ${icon('upload', 15)} ${currentVideoMediaId ? 'Đổi tệp video' : 'Chọn tệp video…'}
                      </button>
                      <button type="button" class="btn btn-ghost btn-sm text-danger" id="ex-video-remove-btn" ${currentVideoMediaId ? '' : 'hidden'}>
                        ${icon('trash', 15)} Gỡ video
                      </button>
                    </div>
                    <span class="field-hint">Hỗ trợ MP4, WebM hoặc MOV (tối đa 30 MB). Video lưu trực tiếp trên hệ thống Storage.</span>
                  </div>

                  <div id="ex-video-url-box" ${videoMode === 'URL' ? '' : 'hidden'}>
                    <div class="field">
                      <label class="field-label" for="ex-video">Liên kết video (YouTube hoặc URL MP4)</label>
                      <div style="display:flex;gap:8px;align-items:center">
                        <input id="ex-video" class="form-control" name="videoUrl" type="url" value="${esc(currentVideoUrl)}" placeholder="https://www.youtube.com/watch?v=... hoặc https://.../dong-tac.mp4" />
                        <button type="button" class="btn btn-ghost btn-sm" id="ex-video-clear-url" ${currentVideoUrl ? '' : 'hidden'} aria-label="Xóa liên kết video">${icon('close', 15)}</button>
                      </div>
                      <span class="field-error" id="ex-video-url-error" aria-live="polite"></span>
                      <span class="field-hint">Hỗ trợ liên kết YouTube (youtube.com, youtu.be) hoặc đường dẫn tệp video trực tiếp (http:// hoặc https://).</span>
                    </div>
                  </div>

                  <div id="ex-video-eq-hint" class="field-hint" hidden></div>
                </div>

                <div class="meta-form-divider"></div>

                <div class="field">
                  <label class="field-label" for="ex-name">Tên bài tập <span class="text-danger">*</span></label>
                  <input id="ex-name" class="form-control" name="name" maxlength="120" value="${esc(row?.name || '')}" required />
                </div>

                <div class="field">
                  <label class="field-label" for="ex-eq">Thiết bị liên kết</label>
                  <select id="ex-eq" class="form-select" name="equipmentId">
                    <option value="">Không gắn thiết bị</option>
                    ${allEquipment.map((e) => `<option value="${esc(e.id)}" ${row?.equipmentId === e.id ? 'selected' : ''}>${esc(e.name)}</option>`).join('')}
                  </select>
                </div>

                <div class="field">
                  <label class="field-label" for="ex-status">Trạng thái hiển thị</label>
                  <select id="ex-status" class="form-select" name="status">
                    <option value="ACTIVE" ${row?.status !== 'HIDDEN' ? 'selected' : ''}>Hiển thị</option>
                    <option value="HIDDEN" ${row?.status === 'HIDDEN' ? 'selected' : ''}>Đang ẩn</option>
                  </select>
                </div>
              </div>

              <!-- Cột phải: Thông tin chuyên môn & Hướng dẫn kỹ thuật -->
              <div class="modal-col-right">
                <div class="modal-section-card">
                  <div class="meta-form-section-header">
                    <span class="meta-form-section-title">Hồ sơ bài tập & Hướng dẫn kỹ thuật</span>
                    <span class="meta-form-section-desc">Độ khó, nhóm cơ mục tiêu, mô tả và kỹ thuật tập chuẩn cho Coach & Hội viên</span>
                  </div>

                  <div class="meta-form-grid-2">
                    <div class="field">
                      <label class="field-label" for="ex-diff">Độ khó</label>
                      <select id="ex-diff" class="form-select" name="difficulty">
                        <option value="">Chưa chọn</option>
                        <option value="BEGINNER" ${row?.difficulty === 'BEGINNER' ? 'selected' : ''}>Cơ bản</option>
                        <option value="INTERMEDIATE" ${row?.difficulty === 'INTERMEDIATE' ? 'selected' : ''}>Trung bình</option>
                        <option value="ADVANCED" ${row?.difficulty === 'ADVANCED' ? 'selected' : ''}>Nâng cao</option>
                      </select>
                    </div>
                    <div class="field">
                      <label class="field-label" for="ex-muscles">Nhóm cơ mục tiêu (dấu phẩy)</label>
                      <input id="ex-muscles" class="form-control" name="targetMuscles" value="${esc((row?.targetMuscles || []).join(', '))}" placeholder="Ví dụ: Ngực, Vai trước, Tay sau" />
                    </div>
                  </div>

                  <div class="field">
                    <label class="field-label" for="ex-desc">Mô tả ngắn</label>
                    <textarea id="ex-desc" class="form-control" name="description" rows="2" maxlength="5000">${esc(row?.description || '')}</textarea>
                  </div>

                  <div class="field">
                    <label class="field-label" for="ex-inst">Hướng dẫn kỹ thuật <span class="text-danger">*</span></label>
                    <textarea id="ex-inst" class="form-control" name="instructions" rows="5" maxlength="10000" required>${esc(row?.instructions || '')}</textarea>
                  </div>

                  <div class="field">
                    <label class="field-label" for="ex-safety">Lưu ý an toàn</label>
                    <textarea id="ex-safety" class="form-control" name="safetyNotes" rows="3" maxlength="5000">${esc(row?.safetyNotes || '')}</textarea>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="meta-modal-footer">
            <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
            <button type="submit" class="btn btn-primary" data-modal-submit style="min-width:140px;">${icon('check', 16)} Lưu bài tập</button>
          </div>
        </form>`,
        onMount(ctrl) {
          const form = ctrl.dialog.querySelector('#exercise-form');
          const uploadModeBtn = form.querySelector('#ex-mode-upload');
          const urlModeBtn = form.querySelector('#ex-mode-url');
          const uploadBox = form.querySelector('#ex-video-upload-box');
          const urlBox = form.querySelector('#ex-video-url-box');
          const previewWrap = form.querySelector('#ex-video-preview-wrap');
          const fileInput = form.querySelector('#ex-video-file');
          const pickBtn = form.querySelector('#ex-video-pick-btn');
          const removeBtn = form.querySelector('#ex-video-remove-btn');
          const uploadMetaWrap = form.querySelector('#ex-video-upload-meta');
          const progressWrap = form.querySelector('#ex-video-progress-wrap');
          const progressPct = form.querySelector('#ex-video-progress-pct');
          const progressFill = form.querySelector('#ex-video-progress-fill');
          const urlInput = form.querySelector('#ex-video');
          const urlError = form.querySelector('#ex-video-url-error');
          const clearUrlBtn = form.querySelector('#ex-video-clear-url');
          const eqSelect = form.querySelector('#ex-eq');
          const eqHint = form.querySelector('#ex-video-eq-hint');

          const syncVideoUi = () => {
            if (uploadModeBtn) {
              uploadModeBtn.classList.toggle('active', videoMode === 'UPLOAD');
              uploadModeBtn.setAttribute('aria-selected', videoMode === 'UPLOAD' ? 'true' : 'false');
            }
            if (urlModeBtn) {
              urlModeBtn.classList.toggle('active', videoMode === 'URL');
              urlModeBtn.setAttribute('aria-selected', videoMode === 'URL' ? 'true' : 'false');
            }
            if (uploadBox) uploadBox.hidden = videoMode !== 'UPLOAD';
            if (urlBox) urlBox.hidden = videoMode !== 'URL';

            const trimmedUrl = (urlInput?.value || '').trim();
            if (clearUrlBtn) clearUrlBtn.hidden = !trimmedUrl;
            if (removeBtn) removeBtn.hidden = !currentVideoMediaId;
            if (pickBtn) {
              pickBtn.innerHTML = `${icon('upload', 15)} ${currentVideoMediaId ? 'Đổi tệp video' : 'Chọn tệp video…'}`;
            }

            if (uploadMetaWrap) {
              uploadMetaWrap.innerHTML = currentVideoMediaId
                ? `<div class="ex-video-meta-card">
                    <div class="ex-video-meta-info">
                      <span class="ex-video-meta-name">${esc(currentVideoMeta?.originalName || 'Video đã tải lên')}</span>
                      <span class="ex-video-meta-sub">${esc(currentVideoMeta?.sizeBytes ? formatBytes(currentVideoMeta.sizeBytes) : 'Sẵn sàng phát trên App')}</span>
                    </div>
                    <span class="meta-badge meta-badge-success">Đã tải lên</span>
                  </div>`
                : '';
            }

            let previewSrc = '';
            if (videoMode === 'UPLOAD' && currentVideoMediaId) {
              previewSrc = resolveApiAssetUrl(row?.videoStreamUrl) || publicExerciseVideoUrl(currentVideoMediaId);
            } else if (videoMode === 'URL' && isValidHttpUrl(trimmedUrl)) {
              previewSrc = trimmedUrl;
            }
            if (previewWrap) {
              previewWrap.innerHTML = renderVideoPlayerHtml(previewSrc, {
                title: (form.querySelector('[name="name"]')?.value || '').trim() || 'Xem trước video bài tập',
                emptyText: videoMode === 'UPLOAD'
                  ? 'Chưa có tệp video. Chọn MP4/WebM/MOV để tải lên.'
                  : 'Nhập link YouTube hoặc URL MP4 để xem trước.',
              });
            }

            const selectedEqId = eqSelect?.value || '';
            const eqFallbackUrl = eqVideoById.get(selectedEqId) || '';
            if (eqHint) {
              if (!previewSrc && eqFallbackUrl) {
                eqHint.hidden = false;
                eqHint.textContent = 'Nếu bỏ trống, App sẽ tự dùng video hướng dẫn của thiết bị liên kết.';
              } else {
                eqHint.hidden = true;
                eqHint.textContent = '';
              }
            }
          };

          syncVideoUi();

          if (uploadModeBtn) {
            uploadModeBtn.onclick = () => {
              videoMode = 'UPLOAD';
              if (urlError) urlError.textContent = '';
              syncVideoUi();
            };
          }
          if (urlModeBtn) {
            urlModeBtn.onclick = () => {
              videoMode = 'URL';
              syncVideoUi();
            };
          }

          if (pickBtn && fileInput) {
            pickBtn.onclick = () => {
              if (!uploadingVideo) fileInput.click();
            };
          }

          if (fileInput) {
            fileInput.onchange = async () => {
              const file = fileInput.files?.[0];
              fileInput.value = '';
              if (!file) return;
              ctrl.showError('');
              uploadingVideo = true;
              ctrl.setBusy(true);
              if (progressWrap) progressWrap.hidden = false;
              if (progressPct) progressPct.textContent = '0%';
              if (progressFill?.style) progressFill.style.width = '0%';
              try {
                const uploaded = await uploadExerciseVideo(file, {
                  onProgress: (pct) => {
                    if (progressPct) progressPct.textContent = `${pct}%`;
                    if (progressFill?.style) progressFill.style.width = `${pct}%`;
                  },
                });
                currentVideoMediaId = uploaded.id;
                currentVideoMeta = {
                  id: uploaded.id,
                  originalName: uploaded.originalName,
                  mimeType: uploaded.mimeType,
                  sizeBytes: uploaded.sizeBytes,
                };
                if (urlInput) urlInput.value = '';
                currentVideoUrl = '';
                videoMode = 'UPLOAD';
                syncVideoUi();
                toast('Đã tải video hướng dẫn lên thành công.', 'success');
              } catch (err) {
                ctrl.showError(err.message);
              } finally {
                uploadingVideo = false;
                ctrl.setBusy(false);
                if (progressWrap) progressWrap.hidden = true;
              }
            };
          }

          if (removeBtn) {
            removeBtn.onclick = () => {
              currentVideoMediaId = null;
              currentVideoMeta = null;
              if (fileInput) fileInput.value = '';
              syncVideoUi();
            };
          }

          if (clearUrlBtn && urlInput) {
            clearUrlBtn.onclick = () => {
              urlInput.value = '';
              currentVideoUrl = '';
              if (urlError) urlError.textContent = '';
              syncVideoUi();
            };
          }

          if (urlInput) {
            const onUrlChange = debounce(() => {
              const val = (urlInput.value || '').trim();
              currentVideoUrl = val;
              if (val) {
                videoMode = 'URL';
                if (urlError) {
                  urlError.textContent = isValidHttpUrl(val)
                    ? ''
                    : 'Liên kết video phải bắt đầu bằng http:// hoặc https://';
                }
              } else if (urlError) {
                urlError.textContent = '';
              }
              syncVideoUi();
            }, 220);
            urlInput.oninput = onUrlChange;
            urlInput.onblur = () => {
              onUrlChange.cancel();
              const val = (urlInput.value || '').trim();
              currentVideoUrl = val;
              if (val && !isValidHttpUrl(val)) {
                if (urlError) urlError.textContent = 'Liên kết video phải bắt đầu bằng http:// hoặc https://';
              } else if (urlError) {
                urlError.textContent = '';
              }
              syncVideoUi();
            };
          }

          if (eqSelect) {
            eqSelect.onchange = () => syncVideoUi();
          }

          form.onsubmit = async (event) => {
            event.preventDefault();
            ctrl.showError('');
            if (urlError) urlError.textContent = '';
            if (uploadingVideo) {
              ctrl.showError('Video đang được tải lên, vui lòng đợi hoàn tất.');
              return;
            }
            const name = (form.querySelector('[name="name"]')?.value || '').trim();
            const equipmentId = form.querySelector('[name="equipmentId"]')?.value || null;
            const difficultyRaw = form.querySelector('[name="difficulty"]')?.value || '';
            const difficulty = difficultyRaw || null;
            const targetMuscles = (form.querySelector('[name="targetMuscles"]')?.value || '').split(',').map((s) => s.trim()).filter(Boolean);
            const description = (form.querySelector('[name="description"]')?.value || '').trim() || null;
            const instructions = (form.querySelector('[name="instructions"]')?.value || '').trim();
            const safetyNotes = (form.querySelector('[name="safetyNotes"]')?.value || '').trim() || null;
            const rawVideoUrl = (form.querySelector('[name="videoUrl"]')?.value || '').trim();
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

            let videoMediaId = null;
            let videoUrl = null;
            if (videoMode === 'UPLOAD' && currentVideoMediaId) {
              videoMediaId = currentVideoMediaId;
            } else if (rawVideoUrl) {
              if (!isValidHttpUrl(rawVideoUrl) || rawVideoUrl.length > 2000) {
                if (urlError) urlError.textContent = 'Liên kết video phải bắt đầu bằng http:// hoặc https:// (tối đa 2000 ký tự).';
                ctrl.showError('Liên kết video hướng dẫn không hợp lệ.');
                return;
              }
              videoUrl = rawVideoUrl;
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
                videoMediaId,
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
    root.querySelectorAll('.preview-ex').forEach((btn) => {
      btn.onclick = () => {
        const item = rows.find((r) => r.id === btn.dataset.id);
        if (!item) return;
        const video = resolveExerciseVideoInfo(item, eqVideoById);
        const drawerCtrl = openDrawer({
          title: item.name,
          subtitle: 'Xem trước bài tập & video hướng dẫn trên App',
          bodyHtml: `<div class="stack-16">
            ${renderVideoPlayerHtml(video.url, {
              title: item.name,
              emptyText: 'Bài tập này chưa có video hướng dẫn động tác.',
            })}
            <div class="impact-box">
              <div class="impact-row"><span class="impact-key">Nguồn video</span><span class="impact-val"><span class="meta-badge ${video.badgeClass}">${esc(video.label)}</span></span></div>
              <div class="impact-row"><span class="impact-key">Thiết bị liên kết</span><span class="impact-val">${esc(item.equipmentName || eqNameById.get(item.equipmentId) || 'Không gắn thiết bị')}</span></div>
              <div class="impact-row"><span class="impact-key">Độ khó</span><span class="impact-val">${esc(DIFFICULTY_LABELS[item.difficulty] || 'Chưa phân loại')}</span></div>
              <div class="impact-row"><span class="impact-key">Nhóm cơ</span><span class="impact-val">${esc((item.targetMuscles || []).join(', ') || '—')}</span></div>
              ${item.description ? `<div class="impact-divider"></div><div><strong>Mô tả:</strong><p class="card-sub" style="margin-top:4px">${esc(item.description)}</p></div>` : ''}
              <div class="impact-divider"></div>
              <div><strong>Hướng dẫn kỹ thuật:</strong><p class="card-sub" style="margin-top:4px;white-space:pre-line">${esc(item.instructions || '—')}</p></div>
              ${item.safetyNotes ? `<div class="impact-divider"></div><div><strong>Lưu ý an toàn:</strong><p class="card-sub" style="margin-top:4px;white-space:pre-line">${esc(item.safetyNotes)}</p></div>` : ''}
            </div>
          </div>`,
          footerHtml: `<button type="button" class="btn btn-ghost" data-close-drawer>Đóng</button>
            <button type="button" class="btn btn-primary" id="ex-drawer-edit-btn">${icon('edit', 15)} Chỉnh sửa bài tập</button>`,
        });
        const editFromDrawer = drawerCtrl?.panel?.querySelector('#ex-drawer-edit-btn');
        if (editFromDrawer) {
          editFromDrawer.onclick = () => {
            drawerCtrl.close();
            openExerciseModal(item);
          };
        }
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
              <div class="impact-row"><span class="impact-key">Icon thiết bị</span><span class="impact-val">${renderEquipmentIconCellHtml(item)}</span></div>
              <div class="impact-row"><span class="impact-key">Danh mục</span><span class="impact-val">${esc(item.category)}</span></div>
              <div class="impact-row"><span class="impact-key">Nhóm cơ</span><span class="impact-val">${esc((item.targetMuscles || []).join(', ') || '—')}</span></div>
              <div class="impact-divider"></div>
              <div><strong>Các bước sử dụng:</strong><ol class="rule-list" style="margin-top:6px">${(item.usageSteps || []).map((s) => `<li>${esc(s)}</li>`).join('')}</ol></div>
              ${item.safetyNotes ? `<div class="impact-divider"></div><div><strong>Lưu ý an toàn:</strong><p class="card-sub">${esc(item.safetyNotes)}</p></div>` : ''}
            </div>
            ${item.videoUrl ? renderVideoPlayerHtml(item.videoUrl, { title: item.name }) : ''}
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
