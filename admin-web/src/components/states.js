import { esc } from './format.js';
import { icon } from './icons.js';

export function renderBanner({
  kind = 'info',
  iconName,
  title = '',
  text = '',
  textHtml = '',
  actionsHtml = '',
  role = 'region',
  ariaLabel = '',
} = {}) {
  const tone = kind === 'warning' ? 'warn' : kind;
  const resolvedIcon = iconName || (tone === 'danger' || tone === 'warn' ? 'alert'
    : tone === 'success' ? 'check' : 'info');
  return `<div class="meta-banner banner-${esc(tone)}" role="${esc(role)}"${ariaLabel ? ` aria-label="${esc(ariaLabel)}"` : ''}>
    <div class="banner-body">
      <span class="banner-icon">${icon(resolvedIcon, 18)}</span>
      <div>
        ${title ? `<p class="banner-title">${esc(title)}</p>` : ''}
        ${textHtml ? `<p class="banner-text">${textHtml}</p>` : (text ? `<p class="banner-text">${esc(text)}</p>` : '')}
      </div>
    </div>
    ${actionsHtml ? `<div class="banner-actions">${actionsHtml}</div>` : ''}
  </div>`;
}

export function renderSkeletonPage({ cards = 3, rows = 5 } = {}) {
  const cardBlocks = cards > 0 ? `<div class="grid-${cards >= 4 ? 4 : cards}">
    ${Array.from({ length: cards }).map(() => `<div class="meta-card">
      <div class="skel" style="height:14px;width:55%;margin-bottom:14px"></div>
      <div class="skel" style="height:30px;width:45%;margin-bottom:10px"></div>
      <div class="skel" style="height:12px;width:70%"></div>
    </div>`).join('')}
  </div>` : '';

  return `<div class="stack-20" aria-busy="true" aria-label="Đang tải dữ liệu">
    ${cardBlocks}
    <div class="meta-card">
      <div class="skel" style="height:20px;width:240px;margin-bottom:16px"></div>
      <div class="stack-12">
        ${Array.from({ length: rows }).map(() => '<div class="skel" style="height:46px;width:100%"></div>').join('')}
      </div>
    </div>
  </div>`;
}

export function renderTableSkeleton(rows = 5) {
  return `<div class="meta-card" aria-busy="true" aria-label="Đang tải danh sách">
    <div class="stack-12">
      ${Array.from({ length: rows }).map(() => '<div class="skel" style="height:48px;width:100%"></div>').join('')}
    </div>
  </div>`;
}

export function renderEmptyState({
  iconName = 'info',
  title = 'Chưa có dữ liệu',
  description = 'Chưa có bản ghi nào trong mục này.',
  ctaLabel = '',
  ctaId = '',
  ctaAttr = '',
} = {}) {
  const button = ctaLabel
    ? `<button type="button" class="btn btn-primary"${ctaId ? ` id="${esc(ctaId)}"` : ''}${ctaAttr ? ` ${ctaAttr}` : ''}>${icon('plus', 16)} ${esc(ctaLabel)}</button>`
    : '';
  return `<div class="empty-state">
    <div class="empty-icon">${icon(iconName, 26)}</div>
    <h2 class="card-title-text">${esc(title)}</h2>
    <p class="card-sub" style="max-width:460px">${esc(description)}</p>
    ${button}
  </div>`;
}

export function renderFilterEmptyState({
  title = 'Không tìm thấy kết quả khớp bộ lọc',
  description = 'Không có bản ghi nào thỏa mãn từ khóa hoặc bộ lọc đang chọn. Xóa bộ lọc để xem toàn bộ danh sách.',
  resetId = 'reset-filters-btn',
} = {}) {
  return `<div class="empty-state">
    <div class="empty-icon">${icon('search', 26)}</div>
    <h2 class="card-title-text">${esc(title)}</h2>
    <p class="card-sub" style="max-width:460px">${esc(description)}</p>
    <button type="button" class="btn btn-primary" id="${esc(resetId)}" data-action="reset-filters">${icon('refresh', 16)} Xóa bộ lọc</button>
  </div>`;
}

export function renderErrorState({
  title = 'Không tải được dữ liệu',
  message = 'Đã xảy ra lỗi khi kết nối máy chủ.',
  retryId = 'retry-load-btn',
} = {}) {
  return `<div class="meta-banner banner-danger" role="alert">
    <div class="banner-body">
      <span class="banner-icon">${icon('alert', 20)}</span>
      <div>
        <p class="banner-title">${esc(title)}</p>
        <p class="banner-text">${esc(message)}</p>
      </div>
    </div>
    <div class="banner-actions">
      <button type="button" class="btn btn-primary btn-sm" id="${esc(retryId)}" data-action="retry-load">${icon('refresh', 16)} Thử lại</button>
    </div>
  </div>`;
}
