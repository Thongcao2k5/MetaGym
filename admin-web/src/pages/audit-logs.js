import { api, buildQuery } from '../services/api.js';
import { debounce, esc, formatDateTimeVN } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderDataTable } from '../components/data-table.js';
import { openDrawer } from '../components/drawer.js';
import { bindPagination, renderPagination } from '../components/pagination.js';
import {
  renderBanner,
  renderEmptyState,
  renderErrorState,
  renderFilterEmptyState,
  renderSkeletonPage,
} from '../components/states.js';
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
  'GYM_CHECKIN_CODE_ROTATED',
];

export async function renderAuditLogsPage({ root, params, shell }) {
  const search = params?.get('search') || '';
  const action = params?.get('action') || '';
  const from = params?.get('from') || '';
  const to = params?.get('to') || '';
  const page = Math.max(1, Number(params?.get('page')) || 1);

  shell({ section: 'audit-logs', contentHtml: renderSkeletonPage({ cards: 0, rows: 6 }) });

  try {
    const query = buildQuery({ search, action, from, to, page, pageSize: 20 });
    const result = await api(`/admin/audit-logs${query}`);
    const rows = result?.data || [];
    const pagination = result?.pagination || { page, pageSize: 20, totalItems: rows.length, totalPages: 1 };
    const hasFilter = Boolean(search || action || from || to);

    const contentHtml = `<div class="stack-20">
      <form class="filter-bar" id="audit-filter-form">
        <input type="search" id="audit-search" class="form-control filter-grow" placeholder="Tìm theo mô tả, hành động hoặc đối tượng…" value="${esc(search)}" aria-label="Tìm nhật ký" />
        <select id="audit-action" class="form-select filter-fixed" aria-label="Lọc loại hành động">
          <option value="">Tất cả hành động</option>
          ${KNOWN_ACTIONS.map((code) => `<option value="${code}" ${action === code ? 'selected' : ''}>${code}</option>`).join('')}
        </select>
        <input type="date" id="audit-from" class="form-control tabular" style="max-width:160px" value="${esc(from)}" aria-label="Từ ngày" />
        <input type="date" id="audit-to" class="form-control tabular" style="max-width:160px" value="${esc(to)}" aria-label="Đến ngày" />
        ${hasFilter ? '<button type="button" class="btn btn-ghost btn-sm" id="audit-reset">Xóa lọc</button>' : ''}
      </form>

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
            render: (row) => `<div class="cell-actions"><button type="button" class="btn btn-ghost btn-sm view-audit" data-id="${esc(row.id)}">${icon('eye', 14)} Chi tiết JSON</button></div>`,
          },
        ],
        rows,
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
        ...patch,
      };
      const nextParams = new URLSearchParams();
      for (const [k, v] of Object.entries(next)) {
        if (v && !(k === 'page' && Number(v) <= 1)) nextParams.set(k, String(v));
      }
      updateQuery({
        search: next.search || null,
        action: next.action || null,
        from: next.from || null,
        to: next.to || null,
        page: next.page > 1 ? next.page : null,
      }, { replace: true });
      return renderAuditLogsPage({ root, params: nextParams, shell });
    };

    const debouncedSearch = debounce(() => applyFilters({ page: 1 }), 280);
    const searchInput = root.querySelector('#audit-search');
    if (searchInput) searchInput.oninput = debouncedSearch;
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
    });

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
