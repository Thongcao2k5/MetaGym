import { api, buildQuery } from '../services/api.js';
import { esc, initials, seatMeterHtml, statusBadge } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderDataTable } from '../components/data-table.js';
import { openConfirmModal, openModal } from '../components/modal.js';
import { bindPagination, renderPagination } from '../components/pagination.js';
import { renderEmptyState, renderErrorState, renderSkeletonPage } from '../components/states.js';
import { notice, toast } from '../components/toast.js';
import { updateQuery } from '../state/router.js';

export async function renderAccountsPage({ root, role = 'MEMBER', params, shell }) {
  const section = role === 'COACH' ? 'coaches' : 'members';
  const page = Math.max(1, Number(params?.get('page')) || 1);
  const statusFilter = params?.get('status') || '';
  const search = params?.get('search') || '';

  shell({
    section,
    contentHtml: renderSkeletonPage({ cards: 0, rows: 6 }),
  });

  try {
    const query = buildQuery({ role, status: statusFilter, search, page, pageSize: 20 });
    const result = await api(`/admin/users${query}`);
    const rows = result?.data || [];
    const pagination = result?.pagination || { page, pageSize: 20, totalItems: rows.length, totalPages: 1 };

    const columns = role === 'COACH' ? [
      {
        label: 'Huấn luyện viên',
        render: (row) => `<div class="person-cell">
          <span class="meta-avatar meta-avatar-coach">${esc(initials(row.fullName))}</span>
          <div><span class="person-name">${esc(row.fullName)}</span><span class="person-sub">${esc(row.email)}</span></div>
        </div>`,
      },
      {
        label: 'Liên hệ',
        render: (row) => `<span class="tabular">${esc(row.phone || 'Chưa cập nhật')}</span>`,
      },
      {
        label: 'Suất học viên',
        render: (row) => seatMeterHtml(row.usedSlots ?? 0, 8, row.openHoldCount ?? 0),
      },
      {
        label: 'Trạng thái',
        render: (row) => statusBadge(row.status),
      },
      {
        label: 'Thao tác',
        align: 'right',
        render: (row) => `<div class="cell-actions">
          <button type="button" class="btn btn-ghost btn-sm edit" data-id="${esc(row.id)}">Sửa</button>
          <button type="button" class="btn btn-ghost btn-sm reset" data-id="${esc(row.id)}">${icon('key', 14)} Mật khẩu tạm</button>
          <button type="button" class="btn ${row.status === 'ACTIVE' ? 'btn-danger' : 'btn-success'} btn-sm toggle" data-id="${esc(row.id)}" data-status="${esc(row.status)}">
            ${row.status === 'ACTIVE' ? `${icon('lock', 14)} Khóa` : `${icon('unlock', 14)} Mở`}
          </button>
        </div>`,
      },
    ] : [
      {
        label: 'Hội viên',
        render: (row) => `<div class="person-cell">
          <span class="meta-avatar">${esc(initials(row.fullName))}</span>
          <div><span class="person-name">${esc(row.fullName)}</span><span class="person-sub">${esc(row.email)}</span></div>
        </div>`,
      },
      {
        label: 'Liên hệ',
        render: (row) => `<span class="tabular">${esc(row.phone || 'Chưa cập nhật')}</span>`,
      },
      {
        label: 'Trạng thái',
        render: (row) => statusBadge(row.status),
      },
      {
        label: 'Thao tác',
        align: 'right',
        render: (row) => `<div class="cell-actions">
          <button type="button" class="btn btn-ghost btn-sm edit" data-id="${esc(row.id)}">Sửa</button>
          <button type="button" class="btn ${row.status === 'ACTIVE' ? 'btn-danger' : 'btn-success'} btn-sm toggle" data-id="${esc(row.id)}" data-status="${esc(row.status)}">
            ${row.status === 'ACTIVE' ? `${icon('lock', 14)} Khóa` : `${icon('unlock', 14)} Mở`}
          </button>
        </div>`,
      },
    ];

    const contentHtml = `<div class="stack-20">
      <div class="table-section">
        ${renderDataTable({
          columns,
          rows,
          emptyHtml: renderEmptyState({
            iconName: 'users',
            title: role === 'COACH' ? 'Chưa có Huấn luyện viên nào' : 'Chưa có Hội viên nào',
            description: 'Dữ liệu tài khoản sẽ hiển thị tại đây.',
            ctaLabel: role === 'COACH' ? 'Tạo Coach' : '',
            ctaId: 'create-empty',
          }),
          paginationHtml: renderPagination({ ...pagination, prefix: 'acc' }),
          ariaLabel: role === 'COACH' ? 'Danh sách Huấn luyện viên' : 'Danh sách Hội viên',
        })}
      </div>
    </div>`;

    shell({
      section,
      contentHtml,
      topbarActionsHtml: role === 'COACH'
        ? `<button type="button" class="btn btn-primary" id="create">${icon('plus', 16)} Tạo Coach</button>`
        : '',
    });

    const reload = (nextPage = page) => {
      const nextParams = new URLSearchParams(params);
      if (nextPage > 1) nextParams.set('page', String(nextPage));
      else nextParams.delete('page');
      updateQuery({ page: nextPage > 1 ? nextPage : null }, { replace: true });
      return renderAccountsPage({ root, role, params: nextParams, shell });
    };

    bindPagination(root, {
      page: pagination.page,
      totalPages: pagination.totalPages,
      prefix: 'acc',
      onChange: (nextPage) => reload(nextPage),
    });

    const openEditor = (row) => {
      openModal({
        title: row ? `Sửa tài khoản: ${row.fullName}` : 'Tạo tài khoản Coach mới',
        subtitle: row ? 'Cập nhật họ tên và số điện thoại vận hành' : 'Trần suất cứng 8 hội viên/Coach được áp dụng tự động',
        bodyHtml: `<form id="account-form" novalidate>
          <div class="meta-modal-body">
            <div class="field">
              <label class="field-label" for="acc-fullName">Họ và tên</label>
              <input id="acc-fullName" class="form-control" name="fullName" value="${esc(row?.fullName || '')}" required minlength="2" maxlength="120" />
            </div>
            ${row ? `<div class="field">
              <label class="field-label" for="acc-phone">Số điện thoại</label>
              <input id="acc-phone" class="form-control tabular" name="phone" value="${esc(row.phone || '')}" maxlength="20" />
            </div>` : `<div class="field">
              <label class="field-label" for="acc-email">Email đăng nhập</label>
              <input id="acc-email" class="form-control" name="email" type="email" required />
            </div>
            <div class="field">
              <label class="field-label" for="acc-password">Mật khẩu ban đầu</label>
              <input id="acc-password" class="form-control" name="password" type="password" required minlength="8" placeholder="Tối thiểu 8 ký tự gồm hoa, thường, số" />
            </div>`}
          </div>
          <div class="meta-modal-footer">
            <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
            <button type="submit" class="btn btn-primary" data-modal-submit>Lưu tài khoản</button>
          </div>
        </form>`,
        onMount(ctrl) {
          const form = ctrl.dialog.querySelector('#account-form');
          form.onsubmit = async (event) => {
            event.preventDefault();
            ctrl.showError('');
            const fullName = (form.querySelector('[name="fullName"]')?.value || '').trim();
            const body = row
              ? { fullName, phone: (form.querySelector('[name="phone"]')?.value || '').trim() || null }
              : {
                fullName,
                email: (form.querySelector('[name="email"]')?.value || '').trim(),
                password: form.querySelector('[name="password"]')?.value || '',
              };
            ctrl.setBusy(true);
            try {
              await api(row ? `/admin/users/${row.id}` : '/admin/coaches', row ? 'PATCH' : 'POST', body);
              ctrl.close();
              await reload(page);
              notice('Đã lưu tài khoản.');
            } catch (error) {
              ctrl.setBusy(false);
              ctrl.showError(error.message);
            }
          };
        },
      });
    };

    const createBtn = root.querySelector('#create') || root.querySelector('#create-empty');
    if (createBtn) createBtn.onclick = () => openEditor(null);

    root.querySelectorAll('.edit').forEach((btn) => {
      btn.onclick = () => openEditor(rows.find((r) => r.id === btn.dataset.id));
    });

    root.querySelectorAll('.toggle').forEach((btn) => {
      btn.onclick = () => {
        const target = rows.find((r) => r.id === btn.dataset.id);
        const nextStatus = btn.dataset.status === 'ACTIVE' ? 'DISABLED' : 'ACTIVE';
        const isLock = nextStatus === 'DISABLED';
        openConfirmModal({
          title: isLock ? `Khóa tài khoản: ${target?.fullName || ''}` : `Mở khóa tài khoản: ${target?.fullName || ''}`,
          subtitle: isLock ? 'Thu hồi phiên làm việc ngay lập tức' : 'Khôi phục quyền đăng nhập của tài khoản',
          requireReason: isLock,
          reasonLabel: 'Lý do khóa tài khoản (bắt buộc 1–500 ký tự)',
          confirmLabel: isLock ? 'Xác nhận khóa' : 'Xác nhận mở khóa',
          confirmVariant: isLock ? 'danger-solid' : 'success',
          confirmIcon: isLock ? 'lock' : 'unlock',
          onConfirm: async ({ reason }) => {
            const body = isLock ? { status: 'DISABLED', reason } : { status: 'ACTIVE' };
            await api(`/admin/users/${btn.dataset.id}/status`, 'PATCH', body);
            await reload(page);
            toast('Đã cập nhật trạng thái tài khoản.');
          },
        });
      };
    });

    root.querySelectorAll('.reset').forEach((btn) => {
      btn.onclick = () => {
        const target = rows.find((r) => r.id === btn.dataset.id);
        openConfirmModal({
          title: `Cấp mật khẩu tạm cho Coach: ${target?.fullName || ''}`,
          subtitle: 'Mật khẩu tạm chỉ hiển thị một lần và thu hồi toàn bộ phiên cũ của Coach',
          confirmLabel: 'Tạo mật khẩu tạm',
          confirmVariant: 'primary',
          confirmIcon: 'key',
          onConfirm: async () => {
            const res = await api(`/admin/coaches/${btn.dataset.id}/password-resets`, 'POST', {});
            const tempPw = res?.data?.temporaryPassword || '';
            setTimeout(() => {
              openModal({
                title: `Mật khẩu tạm (1 lần) · ${target?.fullName || ''}`,
                subtitle: 'Không lưu dạng văn bản thuần trong nhật ký hệ thống',
                bodyHtml: `<div class="meta-modal-body">
                  <div class="impact-box" style="flex-direction:row;align-items:center;justify-content:space-between">
                    <div>
                      <div class="field-hint">Mật khẩu tạm</div>
                      <code style="font-size:20px;font-weight:800;color:var(--meta-text-strong)">${esc(tempPw)}</code>
                    </div>
                    <button type="button" class="btn btn-primary btn-sm" id="copy-temp-pw">${icon('copy', 15)} Sao chép</button>
                  </div>
                </div>`,
                footerHtml: '<button type="button" class="btn btn-ghost" data-close-modal>Đã bàn giao · Đóng</button>',
                onMount(ctrl) {
                  const copyBtn = ctrl.dialog.querySelector('#copy-temp-pw');
                  if (copyBtn) {
                    copyBtn.onclick = () => {
                      globalThis.navigator?.clipboard?.writeText?.(tempPw).catch?.(() => {});
                      toast('Đã sao chép mật khẩu tạm.');
                    };
                  }
                },
              });
            }, 0);
          },
        });
      };
    });
  } catch (error) {
    shell({
      section,
      contentHtml: renderErrorState({ title: 'Không tải được danh sách tài khoản', message: error.message }),
    });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderAccountsPage({ root, role, params, shell });
  }
}
