import { api, buildQuery } from '../services/api.js';
import { debounce, esc, formatDateTimeVN } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderActionButton } from '../components/action-button.js';
import { bindDataTableSelection, renderDataTable } from '../components/data-table.js';
import { openDrawer } from '../components/drawer.js';
import { exportToExcel } from '../components/export.js';
import { bindPagination, renderPagination } from '../components/pagination.js';
import {
  renderEmptyState,
  renderErrorState,
  renderFilterEmptyState,
  renderTableSkeleton,
} from '../components/states.js';
import { toast } from '../components/toast.js';
import { updateQuery } from '../state/router.js';

const ACTION_BADGE_MAP = {
  USER_DISABLED: 'meta-badge-danger',
  USER_ENABLED: 'meta-badge-success',
  COACH_CREATED: 'meta-badge-info',
  COACH_PASSWORD_RESET: 'meta-badge-warning',
  COACH_TRANSFERRED: 'meta-badge-info',
  SIMULATED_REFUND_CREATED: 'meta-badge-danger',
  PAYMENT_VOID_REVERSED: 'meta-badge-danger',
  FRONT_DESK_PAYMENT_CONFIRMED: 'meta-badge-success',
  TERMINATION_DISPUTE_DECIDED: 'meta-badge-coral',
  MEMBERSHIP_PLAN_CREATED: 'meta-badge-info',
  MEMBERSHIP_PLAN_UPDATED: 'meta-badge-info',
  COACH_PACKAGE_CREATED: 'meta-badge-info',
  COACH_PACKAGE_UPDATED: 'meta-badge-info',
  NUTRITION_FOOD_CREATED: 'meta-badge-info',
  NUTRITION_FOOD_UPDATED: 'meta-badge-info',
  EQUIPMENT_CREATED: 'meta-badge-info',
  EQUIPMENT_UPDATED: 'meta-badge-info',
  EXERCISES_CREATED: 'meta-badge-info',
  EXERCISES_UPDATED: 'meta-badge-info',
  GYM_PROFILE_UPDATED: 'meta-badge-info',
  GYM_CHECKIN_CODE_ROTATED: 'meta-badge-warning',
};

const KNOWN_ACTIONS = [
  'USER_DISABLED',
  'USER_ENABLED',
  'COACH_CREATED',
  'USER_UPDATED',
  'COACH_PASSWORD_RESET',
  'MEMBERSHIP_PLAN_CREATED',
  'MEMBERSHIP_PLAN_UPDATED',
  'COACH_PACKAGE_CREATED',
  'COACH_PACKAGE_UPDATED',
  'FRONT_DESK_PAYMENT_CONFIRMED',
  'PAYMENT_VOID_REVERSED',
  'COACH_TRANSFERRED',
  'SIMULATED_REFUND_CREATED',
  'TERMINATION_DISPUTE_DECIDED',
  'NUTRITION_FOOD_CREATED',
  'NUTRITION_FOOD_UPDATED',
  'EQUIPMENT_CREATED',
  'EQUIPMENT_UPDATED',
  'EXERCISES_CREATED',
  'EXERCISES_UPDATED',
  'GYM_PROFILE_UPDATED',
  'GYM_CHECKIN_CODE_ROTATED',
];

export async function renderAuditLogsPage({ root, params, shell }) {
  const search = params?.get('search') || '';
  const action = params?.get('action') || '';
  const from = params?.get('from') || '';
  const to = params?.get('to') || '';
  const page = Math.max(1, Number(params?.get('page')) || 1);
  const pageSize = Math.max(1, Number(params?.get('pageSize')) || 10);
  const hasFilter = Boolean(search || action || from || to);

  const buildFilterHtml = (canExport = false) => `<form class="filter-bar" id="audit-filter-form">
    <input type="search" id="audit-search" class="form-control filter-grow" placeholder="Tìm theo mô tả, hành động hoặc đối tượng…" value="${esc(search)}" aria-label="Tìm nhật ký" />
    <select id="audit-action" class="form-select filter-fixed" aria-label="Lọc loại hành động">
      <option value="">Tất cả hành động</option>
      ${KNOWN_ACTIONS.map((code) => `<option value="${code}" ${action === code ? 'selected' : ''}>${code}</option>`).join('')}
    </select>
    <input type="date" id="audit-from" class="form-control tabular" style="max-width:160px" value="${esc(from)}" aria-label="Từ ngày" />
    <input type="date" id="audit-to" class="form-control tabular" style="max-width:160px" value="${esc(to)}" aria-label="Đến ngày" />
    ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm" id="audit-reset">Xóa lọc</button>' : ''}
    <button type="button" class="btn btn-graphite btn-sm" id="audit-export-excel" ${canExport ? '' : 'disabled'}>
      ${icon('download', 16)} <span id="audit-export-label">Xuất Excel</span>
    </button>
  </form>`;

  shell({
    section: 'audit-logs',
    contentHtml: `<div class="stack-20">${buildFilterHtml(false)}${renderTableSkeleton(6)}</div>`,
  });

  try {
    const query = buildQuery({ search, action, from, to, page, pageSize });
    const result = await api(`/admin/audit-logs${query}`);
    const rows = result?.data || [];
    const pagination = result?.pagination || {
      page,
      pageSize,
      totalItems: rows.length,
      totalPages: Math.max(1, Math.ceil(rows.length / pageSize)),
    };

    const contentHtml = `<div class="stack-20">
      ${buildFilterHtml(rows.length > 0)}

      ${renderDataTable({
        columns: [
          {
            label: 'Thời gian (VN)',
            render: (row) => `<span class="tabular">${formatDateTimeVN(row.createdAt, { withSeconds: true })}</span>`,
          },
          {
            label: 'Người thao tác',
            render: (row) => `<span class="person-name">${esc(row.adminName || 'Admin')}</span>`,
          },
          {
            label: 'Hành động',
            render: (row) => `<span class="meta-badge ${ACTION_BADGE_MAP[row.action] || 'meta-badge-neutral'}">${esc(row.action)}</span>`,
          },
          {
            label: 'Đối tượng & Tóm tắt',
            render: (row) => `<span class="person-name">${esc(row.summary || row.entityType || '—')}</span><span class="person-sub">${esc(row.entityType || '')}</span>`,
          },
          {
            label: 'Chi tiết',
            align: 'right',
            render: (row) => `<div class="cell-actions">
              ${renderActionButton({
                iconName: 'eye',
                label: 'Chi tiết JSON',
                className: 'view-audit',
                permission: 'audit_logs:read',
                attrs: `data-id="${esc(row.id)}"`,
              })}
            </div>`,
          },
        ],
        rows,
        selectable: true,
        rowId: (_row, idx) => String(idx),
        emptyHtml: hasFilter
          ? renderFilterEmptyState({ resetId: 'audit-empty-reset' })
          : renderEmptyState({ iconName: 'audit', title: 'Chưa có bản ghi nhật ký hệ thống', description: 'Mọi thao tác quản trị sẽ tự động được ghi nhận tại đây.' }),
        paginationHtml: renderPagination({ ...pagination, prefix: 'aud' }),
        ariaLabel: 'Nhật ký hệ thống',
      })}
    </div>`;

    shell({ section: 'audit-logs', contentHtml });

    const applyFilters = (patch = {}) => {
      const next = {
        search: root.querySelector('#audit-search')?.value?.trim() || '',
        action: root.querySelector('#audit-action')?.value || '',
        from: root.querySelector('#audit-from')?.value || '',
        to: root.querySelector('#audit-to')?.value || '',
        page: 1,
        pageSize,
        ...patch,
      };
      const nextParams = new URLSearchParams();
      for (const [k, v] of Object.entries(next)) {
        if (k === 'page' && Number(v) <= 1) continue;
        if (k === 'pageSize' && Number(v) === 10) continue;
        if (v) nextParams.set(k, String(v));
      }
      updateQuery({
        search: next.search || null,
        action: next.action || null,
        from: next.from || null,
        to: next.to || null,
        page: next.page > 1 ? next.page : null,
        pageSize: next.pageSize !== 10 ? next.pageSize : null,
      }, { replace: true });
      return renderAuditLogsPage({ root, params: nextParams, shell });
    };

    const debouncedSearch = debounce(() => applyFilters({ page: 1 }), 280);
    const searchInput = root.querySelector('#audit-search');
    if (searchInput) searchInput.oninput = debouncedSearch;
    const filterForm = root.querySelector('#audit-filter-form');
    if (filterForm) {
      filterForm.onsubmit = (ev) => {
        ev.preventDefault();
        debouncedSearch.cancel();
        applyFilters({ page: 1 });
      };
    }
    const actionSelect = root.querySelector('#audit-action');
    if (actionSelect) actionSelect.onchange = () => applyFilters({ page: 1 });
    const fromInput = root.querySelector('#audit-from');
    if (fromInput) fromInput.onchange = () => applyFilters({ page: 1 });
    const toInput = root.querySelector('#audit-to');
    if (toInput) toInput.onchange = () => applyFilters({ page: 1 });

    [root.querySelector('#audit-reset'), root.querySelector('#audit-empty-reset')].filter(Boolean).forEach((btn) => {
      btn.onclick = () => applyFilters({ search: '', action: '', from: '', to: '', page: 1 });
    });

    bindPagination(root, {
      page: pagination.page,
      totalPages: pagination.totalPages,
      prefix: 'aud',
      onChange: (nextPage) => applyFilters({ page: nextPage }),
      onPageSizeChange: (nextSize) => applyFilters({ pageSize: nextSize, page: 1 }),
    });

    const exportLabel = root.querySelector('#audit-export-label');
    const getSelectedIndices = bindDataTableSelection(root, {
      onSelectionChange: (ids) => {
        if (exportLabel) {
          exportLabel.textContent = ids.length > 0 ? `Xuất Excel (${ids.length})` : 'Xuất Excel';
        }
      },
    });

    const exportBtn = root.querySelector('#audit-export-excel');
    if (exportBtn) {
      exportBtn.onclick = () => {
        const selected = getSelectedIndices();
        const targetRows = selected.length > 0
          ? selected.map((idx) => rows[Number(idx)]).filter(Boolean)
          : rows;
        if (!targetRows.length) {
          toast('Chưa có bản ghi nhật ký để xuất Excel.', 'warn');
          return;
        }
        const ok = exportToExcel({
          filename: 'metagym-audit-logs.csv',
          columns: [
            { label: 'Thời gian (VN)', value: (r) => formatDateTimeVN(r.createdAt, { withSeconds: true }) },
            { label: 'Người thao tác', value: (r) => r.adminName || 'Admin' },
            { label: 'Hành động', value: (r) => r.action || '' },
            { label: 'Loại thực thể', value: (r) => r.entityType || '' },
            { label: 'Tóm tắt', value: (r) => r.summary || '' },
          ],
          rows: targetRows,
        });
        if (ok) toast(`Đã xuất ${targetRows.length} bản ghi nhật ký ra file Excel (.csv).`);
      };
    }

    root.querySelectorAll('.view-audit').forEach((btn) => {
      btn.onclick = () => {
        const entry = rows.find((r) => r.id === btn.dataset.id);
        if (!entry) return;
        openDrawer({
          title: entry.action,
          subtitle: `Audit UUID: ${entry.id}`,
          bodyHtml: `<div class="impact-box">
            <div class="impact-row"><span class="impact-key">Thời gian (VN)</span><span class="impact-val tabular">${formatDateTimeVN(entry.createdAt, { withSeconds: true })}</span></div>
            <div class="impact-row"><span class="impact-key">Người thao tác</span><span class="impact-val">${esc(entry.adminName || 'Admin')}</span></div>
            <div class="impact-row"><span class="impact-key">Loại thực thể</span><span class="impact-val">${esc(entry.entityType || '—')}</span></div>
            <div class="impact-row"><span class="impact-key">Target UUID</span><span class="impact-val tabular" style="font-size:12px">${esc(entry.entityId || '—')}</span></div>
            <div class="impact-row"><span class="impact-key">Tóm tắt</span><span class="impact-val">${esc(entry.summary || '—')}</span></div>
          </div>
          <span class="meta-badge meta-badge-success">${icon('shield', 14)} Metadata đã lọc dữ liệu nhạy cảm</span>
          <div class="field">
            <span class="field-label">Metadata (Safe JSON)</span>
            <pre class="code-block">${esc(JSON.stringify(entry.metadata ?? {}, null, 2))}</pre>
          </div>`,
        });
      };
    });
  } catch (error) {
    shell({ section: 'audit-logs', contentHtml: renderErrorState({ title: 'Không tải được nhật ký hệ thống', message: error.message }) });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderAuditLogsPage({ root, params, shell });
  }
}
