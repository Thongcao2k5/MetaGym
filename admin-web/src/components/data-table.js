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
} = {}) {
  if (!rows.length) return emptyHtml;

  const head = columns.map((col) => `<th${col.align === 'right' ? ' class="text-right"' : ''}>${esc(col.label)}</th>`).join('');

  const body = rows.map((row, idx) => {
    const attrs = typeof rowAttr === 'function' ? rowAttr(row, idx) : '';
    const cells = columns.map((col) => {
      const html = typeof col.render === 'function' ? col.render(row, idx) : esc(row[col.key] ?? '—');
      const alignCls = col.align === 'right' ? ' class="text-right"' : '';
      return `<td data-label="${esc(col.label)}"${alignCls}>${html}</td>`;
    }).join('');
    return `<tr${attrs ? ` ${attrs}` : ''}>${cells}</tr>`;
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
