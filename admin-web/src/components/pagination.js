import { esc } from './format.js';

export function renderPagination({
  page = 1,
  pageSize = 20,
  totalItems = 0,
  totalPages = 1,
  summaryNote = '',
  prefix = 'pg',
} = {}) {
  const safeTotalPages = Math.max(1, Number(totalPages) || 1);
  const safePage = Math.min(Math.max(1, Number(page) || 1), safeTotalPages);
  const start = totalItems === 0 ? 0 : ((safePage - 1) * pageSize) + 1;
  const end = Math.min(totalItems, safePage * pageSize);

  return `<div class="pagination-bar" data-pagination="${esc(prefix)}">
    <span class="tabular">Hiển thị ${start}–${end} / ${totalItems} kết quả${summaryNote ? ` · ${esc(summaryNote)}` : ''}</span>
    <div class="pagination-controls">
      <button type="button" class="btn btn-ghost btn-sm" id="${esc(prefix)}-prev" data-page-nav="prev" ${safePage <= 1 ? 'disabled' : ''}>Trước</button>
      <span class="meta-badge meta-badge-neutral tabular">Trang ${safePage} / ${safeTotalPages}</span>
      <button type="button" class="btn btn-ghost btn-sm" id="${esc(prefix)}-next" data-page-nav="next" ${safePage >= safeTotalPages ? 'disabled' : ''}>Sau</button>
    </div>
  </div>`;
}

export function bindPagination(container, { page = 1, totalPages = 1, prefix = 'pg', onChange }) {
  if (!container || typeof onChange !== 'function') return;
  const prevBtn = container.querySelector?.(`#${prefix}-prev`) || container.querySelector?.('[data-page-nav="prev"]');
  const nextBtn = container.querySelector?.(`#${prefix}-next`) || container.querySelector?.('[data-page-nav="next"]');
  const safeTotal = Math.max(1, Number(totalPages) || 1);
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
}
