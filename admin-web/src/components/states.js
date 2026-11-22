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

export function renderDashboardSkeleton() {
  const kpiSkeleton = () => `<div class="kpi-card">
    <div class="kpi-top">
      <div class="skel" style="height:13px;width:52%"></div>
      <div class="skel" style="height:20px;width:20px;border-radius:6px"></div>
    </div>
    <div class="skel" style="height:30px;width:58%;margin:6px 0"></div>
    <div class="skel" style="height:12px;width:74%"></div>
  </div>`;

  const barHeights = [42, 68, 54, 82, 60, 90, 48, 74, 86, 58, 70, 64];

  return `<div class="stack-20" aria-busy="true" aria-label="Đang tải tổng quan vận hành">
    <div class="filter-bar">
      <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;flex:1">
        <div class="skel" style="height:28px;width:170px;border-radius:999px"></div>
        <div class="skel" style="height:40px;width:150px"></div>
        <div class="skel" style="height:40px;width:150px"></div>
        <div class="skel" style="height:36px;width:86px"></div>
      </div>
      <div style="display:flex;gap:6px">
        <div class="skel" style="height:34px;width:68px;border-radius:999px"></div>
        <div class="skel" style="height:34px;width:74px;border-radius:999px"></div>
        <div class="skel" style="height:34px;width:84px;border-radius:999px"></div>
      </div>
    </div>

    <div class="grid-3">
      ${Array.from({ length: 3 }).map(kpiSkeleton).join('')}
    </div>

    <div class="grid-3">
      ${Array.from({ length: 3 }).map(kpiSkeleton).join('')}
    </div>

    <section class="meta-card">
      <div class="skel" style="height:20px;width:260px;margin-bottom:8px"></div>
      <div class="skel" style="height:14px;width:360px;max-width:100%;margin-bottom:18px"></div>
      <div class="skel-chart">
        ${barHeights.map((h) => `<span class="skel skel-chart-bar" style="height:${h}%"></span>`).join('')}
      </div>
    </section>
  </div>`;
}

export function renderTableSkeleton(rowsOrOptions = 5) {
  const opts = typeof rowsOrOptions === 'object' && rowsOrOptions !== null
    ? rowsOrOptions
    : { rows: Number(rowsOrOptions) || 5 };
  const rows = opts.rows ?? 5;
  const columns = opts.columns ?? 5;
  const selectable = Boolean(opts.selectable);
  const hasActions = opts.hasActions !== false;

  const middleCount = Math.max(0, columns - (hasActions ? 2 : 1));
  const middleWidths = ['96px', '84px', '72px', '110px'];

  const rowHtml = () => {
    const checkBlock = selectable
      ? '<div class="skel skel-check"></div>'
      : '';
    const primaryBlock = `<div class="skel-col-primary">
      <div class="skel skel-avatar"></div>
      <div class="skel-lines">
        <div class="skel" style="height:13px;width:128px;max-width:100%"></div>
        <div class="skel" style="height:11px;width:88px;max-width:80%"></div>
      </div>
    </div>`;
    const middleBlocks = Array.from({ length: middleCount })
      .map((_, i) => `<div class="skel-col-secondary"><div class="skel" style="height:14px;width:${middleWidths[i % middleWidths.length]}"></div></div>`)
      .join('');
    const actionBlock = hasActions
      ? `<div class="skel-col-actions">
          <div class="skel skel-btn"></div>
          <div class="skel skel-btn"></div>
        </div>`
      : '';
    const mobileToggle = middleCount > 0
      ? '<div class="skel-mobile-expand"><div class="skel" style="height:32px;width:100%"></div></div>'
      : '';
    return `<div class="skel-table-row">${checkBlock}${primaryBlock}${middleBlocks}${actionBlock}${mobileToggle}</div>`;
  };

  return `<div class="meta-card" aria-busy="true" aria-label="Đang tải danh sách">
    <div class="skel-table-list">
      ${Array.from({ length: rows }).map(rowHtml).join('')}
    </div>
  </div>`;
}

function emptyIllustrationSvg(variant = 'data') {
  const accent = variant === 'filter' ? 'var(--meta-info)' : 'var(--meta-primary)';
  return `<svg class="empty-illustration" width="176" height="136" viewBox="0 0 176 136" fill="none" aria-hidden="true">
    <circle cx="88" cy="68" r="52" fill="var(--meta-surface-raised)" opacity="0.85"/>
    <circle cx="136" cy="24" r="5" fill="var(--meta-surface-raised)"/>
    <circle cx="34" cy="108" r="4" fill="var(--meta-surface-raised)"/>
    <rect x="26" y="22" width="76" height="68" rx="8" fill="var(--meta-surface)" stroke="var(--meta-border-strong)" stroke-width="1.2"/>
    <path d="M26 30a8 8 0 0 1 8-8h60a8 8 0 0 1 8 8v6H26v-6z" fill="var(--meta-surface-raised)"/>
    <circle cx="35" cy="29" r="2" fill="var(--meta-text-secondary)" opacity="0.6"/>
    <circle cx="42" cy="29" r="2" fill="var(--meta-text-secondary)" opacity="0.6"/>
    <circle cx="49" cy="29" r="2" fill="var(--meta-text-secondary)" opacity="0.6"/>
    <rect x="36" y="46" width="12" height="34" rx="3" fill="var(--meta-surface-raised)"/>
    <rect x="36" y="58" width="12" height="22" rx="3" fill="var(--meta-border-strong)"/>
    <rect x="54" y="46" width="12" height="34" rx="3" fill="var(--meta-surface-raised)"/>
    <rect x="54" y="66" width="12" height="14" rx="3" fill="var(--meta-border-strong)"/>
    <rect x="72" y="46" width="12" height="34" rx="3" fill="var(--meta-surface-raised)"/>
    <rect x="72" y="52" width="12" height="28" rx="3" fill="var(--meta-border-strong)"/>
    <rect x="70" y="38" width="80" height="78" rx="8" fill="var(--meta-surface)" stroke="var(--meta-border-strong)" stroke-width="1.4"/>
    <path d="M70 46a8 8 0 0 1 8-8h64a8 8 0 0 1 8 8v6H70v-6z" fill="var(--meta-surface-raised)"/>
    <circle cx="79" cy="45" r="2" fill="var(--meta-text-secondary)" opacity="0.65"/>
    <circle cx="86" cy="45" r="2" fill="var(--meta-text-secondary)" opacity="0.65"/>
    <circle cx="93" cy="45" r="2" fill="var(--meta-text-secondary)" opacity="0.65"/>
    <circle cx="110" cy="76" r="16" stroke="var(--meta-border-strong)" stroke-width="7"/>
    <path d="M110 60a16 16 0 0 1 16 16" stroke="${accent}" stroke-width="7" stroke-linecap="round"/>
    <rect x="86" y="100" width="48" height="4" rx="2" fill="var(--meta-border-strong)"/>
    <rect x="94" y="107" width="32" height="3.5" rx="1.75" fill="var(--meta-surface-raised)"/>
  </svg>`;
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
    <div class="empty-illustration-wrap" data-empty-icon="${esc(iconName)}">${emptyIllustrationSvg('data')}</div>
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
    <div class="empty-illustration-wrap">${emptyIllustrationSvg('filter')}</div>
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
