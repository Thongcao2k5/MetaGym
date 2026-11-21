import { esc } from './format.js';

/**
 * Renders a Dark Graphite Operate Mode data table that automatically transforms
 * into stacked vertical cards on viewports <= 767px (375px safe, zero horizontal overflow).
 *
 * columns: [{ key, label, align?: 'left'|'right', render?: (row) => html }]
 */
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
    const cells = columns.map((col) => {
      const html = typeof col.render === 'function' ? col.render(row, idx) : esc(row[col.key] ?? '—');
      const alignCls = col.align === 'right' ? ' class="text-right"' : '';
      return `<td data-label="${esc(col.label)}"${alignCls}>${html}</td>`;
    }).join('');
    return `<tr${attrs ? ` ${attrs}` : ''}>${selectCell}${cells}</tr>`;
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
