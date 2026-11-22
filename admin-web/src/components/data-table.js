import { esc } from './format.js';

/**
 * Renders a Dark Graphite Operate Mode data table that automatically transforms
 * into stacked vertical cards on viewports <= 767px (375px safe, zero horizontal overflow).
 *
 * columns: [{ key, label, align?: 'left'|'right', render?: (row) => html }]
 */
function ensureExpandDelegation() {
  if (typeof globalThis.document?.addEventListener !== 'function') return;
  if (globalThis.__metaTableExpandBound) return;
  globalThis.__metaTableExpandBound = true;
  globalThis.document.addEventListener('click', (event) => {
    const btn = event.target?.closest?.('[data-row-expand]');
    if (!btn) return;
    const tr = btn.closest?.('tr');
    if (!tr) return;
    const expanded = tr.classList.toggle('is-expanded');
    btn.setAttribute?.('aria-expanded', String(expanded));
    const count = btn.getAttribute?.('data-secondary-count') || '';
    const labelEl = btn.querySelector?.('span');
    if (labelEl) {
      labelEl.textContent = expanded ? 'Thu gọn' : `Xem thêm (${count})`;
    }
  });
}

export function renderDataTable({
  columns = [],
  rows = [],
  emptyHtml = '',
  paginationHtml = '',
  ariaLabel = '',
  rowAttr = null,
  selectable = false,
  rowId = (row, idx) => row?.id ?? String(idx),
} = {}) {
  if (!rows.length) return emptyHtml;
  ensureExpandDelegation();

  const hasSecondary = columns.length >= 3;
  const secondaryCount = Math.max(0, columns.length - 2);
  const selectHead = selectable
    ? '<th class="col-check"><input type="checkbox" class="table-check" data-select-all aria-label="Chọn tất cả" title="Chọn tất cả" /></th>'
    : '';
  const head = `${selectHead}${columns.map((col) => `<th${col.align === 'right' ? ' class="text-right"' : ''}>${esc(col.label)}</th>`).join('')}`;

  const body = rows.map((row, idx) => {
    const attrs = typeof rowAttr === 'function' ? rowAttr(row, idx) : '';
    const id = String(rowId(row, idx));
    const selectCell = selectable
      ? `<td class="col-check" data-label="Chọn"><input type="checkbox" class="table-check" data-select-row="${esc(id)}" aria-label="Chọn dòng" /></td>`
      : '';
    const cells = columns.map((col, colIdx) => {
      const html = typeof col.render === 'function' ? col.render(row, idx) : esc(row[col.key] ?? '—');
      const classes = [];
      if (col.align === 'right') classes.push('text-right');
      if (colIdx === 0) classes.push('col-primary');
      else if (colIdx === columns.length - 1) classes.push('col-last');
      else classes.push('col-secondary');
      const clsAttr = classes.length ? ` class="${classes.join(' ')}"` : '';
      return `<td data-label="${esc(col.label)}"${clsAttr}>${html}</td>`;
    }).join('');
    const toggleCell = hasSecondary
      ? `<td class="mobile-row-toggle-cell"><button type="button" class="mobile-row-toggle-btn" data-row-expand data-secondary-count="${secondaryCount}" aria-expanded="false"><span>Xem thêm (${secondaryCount})</span></button></td>`
      : '';
    return `<tr${attrs ? ` ${attrs}` : ''}>${selectCell}${cells}${toggleCell}</tr>`;
  }).join('');

  return `<div class="table-card">
    <div class="table-wrap">
      <table class="meta-data-table"${ariaLabel ? ` aria-label="${esc(ariaLabel)}"` : ''}>
        <thead><tr>${head}</tr></thead>
        <tbody>${body}</tbody>
      </table>
    </div>
    ${paginationHtml || ''}
  </div>`;
}

export function bindDataTableSelection(container, { onSelectionChange } = {}) {
  if (!container) return () => [];
  const selectAll = container.querySelector?.('[data-select-all]');
  const rowChecks = Array.from(container.querySelectorAll?.('[data-select-row]') || []);

  const getSelectedIds = () => rowChecks
    .filter((cb) => cb.checked)
    .map((cb) => cb.dataset?.selectRow || cb.getAttribute?.('data-select-row'))
    .filter(Boolean);

  const syncSelectAll = () => {
    if (selectAll) {
      const total = rowChecks.length;
      const checkedCount = rowChecks.filter((cb) => cb.checked).length;
      selectAll.checked = total > 0 && checkedCount === total;
      selectAll.indeterminate = checkedCount > 0 && checkedCount < total;
    }
    if (typeof onSelectionChange === 'function') {
      onSelectionChange(getSelectedIds());
    }
  };

  if (selectAll) {
    selectAll.onchange = () => {
      const next = Boolean(selectAll.checked);
      rowChecks.forEach((cb) => { cb.checked = next; });
      syncSelectAll();
    };
  }

  rowChecks.forEach((cb) => {
    cb.onchange = syncSelectAll;
  });

  return getSelectedIds;
}
