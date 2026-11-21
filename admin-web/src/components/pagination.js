import { esc } from './format.js';

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100];

function buildPageList(current, total) {
  if (total <= 7) {
    return Array.from({ length: total }, (_, idx) => idx + 1);
  }
  const pages = new Set([1, total, current - 1, current, current + 1]);
  const sorted = [...pages].filter((p) => p >= 1 && p <= total).sort((a, b) => a - b);
  const result = [];
  for (let i = 0; i < sorted.length; i += 1) {
    if (i > 0 && sorted[i] - sorted[i - 1] > 1) {
      result.push('...');
    }
    result.push(sorted[i]);
  }
  return result;
}

export function renderPagination({
  page = 1,
  pageSize = 10,
  totalItems = 0,
  totalPages = 1,
  summaryNote = '',
  prefix = 'pg',
  pageSizeOptions = PAGE_SIZE_OPTIONS,
} = {}) {
  const safeSize = Math.max(1, Number(pageSize) || 10);
  const safeTotalPages = Math.max(1, Number(totalPages) || 1);
  const safePage = Math.min(Math.max(1, Number(page) || 1), safeTotalPages);
  const start = totalItems === 0 ? 0 : ((safePage - 1) * safeSize) + 1;
  const end = Math.min(totalItems, safePage * safeSize);

  const optionsList = pageSizeOptions.includes(safeSize)
    ? pageSizeOptions
    : [...pageSizeOptions, safeSize].sort((a, b) => a - b);

  const pageItems = buildPageList(safePage, safeTotalPages);
  const pageButtonsHtml = pageItems.map((item) => {
    if (item === '...') {
      return '<span class="pagination-ellipsis" aria-hidden="true">…</span>';
    }
    const isCurrent = item === safePage;
    return `<button type="button" class="btn ${isCurrent ? 'btn-primary' : 'btn-ghost'} btn-sm pagination-page-btn tabular${isCurrent ? ' active' : ''}" data-page-num="${item}" ${isCurrent ? 'aria-current="page"' : ''} aria-label="Trang ${item}">${item}</button>`;
  }).join('');

  return `<div class="pagination-bar" data-pagination="${esc(prefix)}">
    <span class="pagination-summary tabular">Hiển thị ${start}–${end} / ${totalItems} kết quả${summaryNote ? ` · ${esc(summaryNote)}` : ''}</span>
    <div class="pagination-controls">
      <button type="button" class="btn btn-ghost btn-sm" id="${esc(prefix)}-prev" data-page-nav="prev" ${safePage <= 1 ? 'disabled' : ''}>Trước</button>
      <div class="pagination-pages" aria-label="Danh sách trang">${pageButtonsHtml}</div>
      <span class="meta-badge meta-badge-neutral tabular pagination-mobile-badge">Trang ${safePage} / ${safeTotalPages}</span>
      <button type="button" class="btn btn-ghost btn-sm" id="${esc(prefix)}-next" data-page-nav="next" ${safePage >= safeTotalPages ? 'disabled' : ''}>Sau</button>
    </div>
    <div class="pagination-size-wrap">
      <label class="pagination-size-label" for="${esc(prefix)}-page-size">Hiển thị</label>
      <select class="form-select pagination-size-select tabular" id="${esc(prefix)}-page-size" data-page-size aria-label="Số dòng mỗi trang">
        ${optionsList.map((size) => `<option value="${size}" ${size === safeSize ? 'selected' : ''}>${size} / trang</option>`).join('')}
      </select>
    </div>
  </div>`;
}

export function bindPagination(container, { page = 1, totalPages = 1, prefix = 'pg', onChange, onPageSizeChange }) {
  if (!container) return;
  const prevBtn = container.querySelector?.(`#${prefix}-prev`) || container.querySelector?.('[data-page-nav="prev"]');
  const nextBtn = container.querySelector?.(`#${prefix}-next`) || container.querySelector?.('[data-page-nav="next"]');
  const sizeSelect = container.querySelector?.(`#${prefix}-page-size`) || container.querySelector?.('[data-page-size]');
  const pageBtns = container.querySelectorAll?.('[data-page-num]') || [];
  const safeTotal = Math.max(1, Number(totalPages) || 1);

  if (typeof onChange === 'function') {
    if (prevBtn) {
      prevBtn.onclick = () => {
        if (page > 1) onChange(page - 1);
      };
    }
    if (nextBtn) {
      nextBtn.onclick = () => {
        if (page < safeTotal) onChange(page + 1);
      };
    }
    pageBtns.forEach((btn) => {
      btn.onclick = () => {
        const targetPage = Number(btn.dataset?.pageNum || btn.getAttribute?.('data-page-num'));
        if (Number.isFinite(targetPage) && targetPage >= 1 && targetPage <= safeTotal && targetPage !== page) {
          onChange(targetPage);
        }
      };
    });
  }

  if (sizeSelect && typeof onPageSizeChange === 'function') {
    sizeSelect.onchange = () => {
      const nextSize = Number(sizeSelect.value);
      if (Number.isFinite(nextSize) && nextSize > 0) {
        onPageSizeChange(nextSize);
      }
    };
  }
}
