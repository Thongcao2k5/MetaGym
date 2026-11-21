function csvEscape(value) {
  const str = String(value ?? '');
  if (/[",\r\n]/.test(str)) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return str;
}

/**
 * Exports tabular data to an Excel-compatible UTF-8 BOM CSV file.
 */
export function exportToExcel({
  filename = 'meta-gym-export.csv',
  columns = [],
  rows = [],
} = {}) {
  if (!columns.length || !rows.length) return false;
  const header = columns.map((col) => csvEscape(col.label)).join(',');
  const lines = rows.map((row) => columns.map((col) => {
    const val = typeof col.value === 'function' ? col.value(row) : row[col.key];
    return csvEscape(val);
  }).join(','));

  const csvContent = `\uFEFF${[header, ...lines].join('\r\n')}`;
  if (typeof Blob === 'undefined' || typeof URL === 'undefined' || !document?.createElement) {
    return false;
  }

  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.setAttribute('download', filename.endsWith('.csv') ? filename : `${filename}.csv`);
  link.style.display = 'none';
  document.body?.appendChild?.(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
  return true;
}
