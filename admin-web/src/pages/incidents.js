import { api, buildQuery } from '../services/api.js';
import { esc, formatDateTimeVN, initials, statusBadge, vnd } from '../components/format.js';
import { renderDataTable } from '../components/data-table.js';
import { bindPagination, renderPagination } from '../components/pagination.js';
import { renderBanner, renderEmptyState, renderErrorState, renderSkeletonPage } from '../components/states.js';
import { updateQuery } from '../state/router.js';

export async function renderIncidentsPage({ root, params, shell }) {
  const status = params?.get('status') || 'OPEN';
  const page = Math.max(1, Number(params?.get('page')) || 1);

  shell({ section: 'coach-incidents', contentHtml: renderSkeletonPage({ cards: 0, rows: 5 }) });

  try {
    const query = buildQuery({ status, page, pageSize: 20 });
    const result = await api(`/admin/coach-incidents${query}`);
    const rows = result?.data || [];
    const pagination = result?.pagination || { page, pageSize: 20, totalItems: rows.length, totalPages: 1 };

    const contentHtml = `<div class="stack-20">
      ${renderBanner({
        kind: 'warn',
        iconName: 'alert',
        title: 'Hàng chờ sự cố khóa Coach (COACH_LOCKED)',
        text: 'Khi Coach bị khóa, gói Coach của hội viên được đóng băng (gói Gym vẫn chạy). Admin có thể mở khóa Coach (D1), chuyển Coach thay thế (D2) hoặc hoàn tiền mô phỏng (D3).',
      })}
      <div class="filter-bar">
        <select id="inc-status" class="form-select filter-fixed" aria-label="Lọc trạng thái sự cố">
          <option value="OPEN" ${status === 'OPEN' ? 'selected' : ''}>Đang mở (OPEN)</option>
          <option value="ALL" ${status === 'ALL' ? 'selected' : ''}>Tất cả sự cố</option>
        </select>
      </div>
      ${renderDataTable({
        columns: [
          {
            label: 'Hội viên bị ảnh hưởng',
            render: (row) => `<div class="person-cell">
              <span class="meta-avatar">${esc(initials(row.memberName || 'M'))}</span>
              <div><span class="person-name">${esc(row.memberName || 'Hội viên')}</span><span class="person-sub">Coach cũ: ${esc(row.coachName || 'Coach')}</span></div>
            </div>`,
          },
          {
            label: 'Đóng băng',
            render: (row) => `<span class="meta-badge meta-badge-warning tabular">${Number(row.frozenDays ?? 0)} ngày</span><span class="person-sub tabular">${formatDateTimeVN(row.lockedAt)}</span>`,
          },
          {
            label: 'Ước tính hoàn mô phỏng',
            align: 'right',
            render: (row) => `<strong class="tabular">${vnd(row.estimatedTotalRefund ?? 0)}</strong>`,
          },
          {
            label: 'Lựa chọn Member',
            render: (row) => statusBadge(row.memberChoice || 'WAIT'),
          },
          {
            label: 'Trạng thái',
            render: (row) => statusBadge(row.status || 'OPEN'),
          },
        ],
        rows,
        emptyHtml: renderEmptyState({
          iconName: 'check',
          title: 'Không có sự cố khóa Coach nào đang chờ',
          description: 'Mọi hội viên bị ảnh hưởng do COACH_LOCKED đều đã được xử lý hoặc chưa phát sinh sự cố mới.',
        }),
        paginationHtml: renderPagination({ ...pagination, prefix: 'inc' }),
      })}
    </div>`;

    shell({ section: 'coach-incidents', contentHtml });

    const select = root.querySelector('#inc-status');
    if (select) {
      select.onchange = () => {
        const next = new URLSearchParams(params);
        if (select.value && select.value !== 'ALL') next.set('status', select.value);
        else next.delete('status');
        next.delete('page');
        updateQuery({ status: select.value, page: null }, { replace: true });
        renderIncidentsPage({ root, params: next, shell });
      };
    }

    bindPagination(root, {
      page: pagination.page,
      totalPages: pagination.totalPages,
      prefix: 'inc',
      onChange: (nextPage) => {
        const next = new URLSearchParams(params);
        next.set('page', String(nextPage));
        updateQuery({ page: nextPage }, { replace: true });
        renderIncidentsPage({ root, params: next, shell });
      },
    });
  } catch (error) {
    if (error?.status === 404) {
      shell({
        section: 'coach-incidents',
        contentHtml: renderEmptyState({
          iconName: 'alert',
          title: 'Hàng chờ sự cố Coach chưa có dữ liệu',
          description: 'API sự cố Coach (T12) sẽ cung cấp danh sách hội viên COACH_LOCKED và luồng chuyển/hoàn mô phỏng tại đây.',
        }),
      });
      return;
    }
    shell({
      section: 'coach-incidents',
      contentHtml: renderErrorState({ title: 'Không tải được sự cố Coach', message: error.message }),
    });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderIncidentsPage({ root, params, shell });
  }
}
