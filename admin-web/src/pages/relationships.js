import { api } from '../services/api.js';
import { esc, formatDateTimeVN, generateUuid, initials, relationshipStatusBadge, statusBadge } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderDataTable } from '../components/data-table.js';
import { openDrawer } from '../components/drawer.js';
import { openConfirmModal, openModal } from '../components/modal.js';
import { renderEmptyState, renderErrorState, renderSkeletonPage } from '../components/states.js';
import { toast } from '../components/toast.js';
import { updateQuery } from '../state/router.js';

export async function renderRelationshipsPage({ root, params, shell }) {
  const tab = params?.get('tab') || 'list';

  shell({ section: 'relationships', contentHtml: renderSkeletonPage({ cards: 0, rows: 6 }) });

  try {
    const [relsRes, coachesRes, membersRes, transfersRes, termsRes] = await Promise.all([
      api('/admin/relationships'),
      api('/admin/users?role=COACH&pageSize=100'),
      api('/admin/users?role=MEMBER&pageSize=100'),
      api('/admin/coach-transfers'),
      api('/admin/termination-requests'),
    ]);

    const relationships = relsRes?.data || [];
    const coaches = coachesRes?.data || [];
    const members = membersRes?.data || [];
    const transfers = transfersRes?.data || [];
    const terminations = termsRes?.data || [];

    const nameById = new Map();
    for (const u of [...coaches, ...members]) nameById.set(u.id, u.fullName);

    const resolveMember = (row) => row.memberName || nameById.get(row.memberId || row.member_id) || 'Hội viên';
    const resolveCoach = (row, idField = 'coachId') => row.coachName || nameById.get(row[idField] || row.coach_id) || 'Huấn luyện viên';

    let tabBody = '';
    if (tab === 'terminations') {
      tabBody = renderDataTable({
        columns: [
          {
            label: 'Quan hệ (Member ↔ Coach)',
            render: (row) => `<span class="person-name">${esc(row.memberName || resolveMember(row))} ↔ ${esc(row.coachName || resolveCoach(row, 'coach_id'))}</span><span class="person-sub">${esc(row.reason || '—')}</span>`,
          },
          {
            label: 'Người gửi / Thời gian',
            render: (row) => `<span>${esc(row.requestedByRole || 'COACH')}</span><span class="person-sub tabular">${formatDateTimeVN(row.createdAt || row.created_at)}</span>`,
          },
          { label: 'Trạng thái', render: (row) => statusBadge(row.status) },
          {
            label: 'Thao tác',
            align: 'right',
            render: (row) => {
              const actionable = row.status === 'DISPUTED' || row.status === 'PENDING';
              return `<div class="cell-actions">
                ${actionable ? `<button type="button" class="btn btn-primary btn-sm decide" data-id="${esc(row.id)}" data-value="APPROVED">Duyệt kết thúc</button>
                <button type="button" class="btn btn-danger btn-sm decide" data-id="${esc(row.id)}" data-value="REJECTED">Từ chối</button>` : '—'}
              </div>`;
            },
          },
        ],
        rows: terminations,
        emptyHtml: renderEmptyState({ iconName: 'link', title: 'Chưa có yêu cầu kết thúc sớm', description: 'Các yêu cầu kết thúc sớm và tranh chấp quá 72 giờ sẽ xuất hiện tại đây.' }),
      });
    } else if (tab === 'transfers') {
      tabBody = renderDataTable({
        columns: [
          { label: 'Hội viên', render: (row) => `<span class="person-name">${esc(row.memberName || nameById.get(row.memberId || row.member_id) || 'Hội viên')}</span>` },
          {
            label: 'Coach cũ → Coach mới',
            render: (row) => `${esc(row.oldCoachName || nameById.get(row.oldCoachId || row.old_coach_id) || 'Coach cũ')} → <strong>${esc(row.newCoachName || nameById.get(row.newCoachId || row.new_coach_id) || 'Coach mới')}</strong>`,
          },
          { label: 'Thời gian (VN)', render: (row) => `<span class="tabular">${formatDateTimeVN(row.createdAt || row.created_at)}</span>` },
          { label: 'Lý do', render: (row) => esc(row.reason || '—') },
        ],
        rows: transfers,
        emptyHtml: renderEmptyState({ iconName: 'swap', title: 'Chưa có lịch sử chuyển Coach', description: 'Mọi lần chuyển Coach (D2) sẽ được ghi nhận đầy đủ tại đây.' }),
      });
    } else {
      tabBody = renderDataTable({
        columns: [
          {
            label: 'Hội viên',
            render: (row) => `<div class="person-cell"><span class="meta-avatar">${esc(initials(resolveMember(row)))}</span><span class="person-name">${esc(resolveMember(row))}</span></div>`,
          },
          {
            label: 'Huấn luyện viên',
            render: (row) => `<div class="person-cell"><span class="meta-avatar meta-avatar-coach">${esc(initials(resolveCoach(row)))}</span><span>${esc(resolveCoach(row))}</span></div>`,
          },
          { label: 'Trạng thái', render: (row) => relationshipStatusBadge(row) },
          { label: 'Bắt đầu', render: (row) => `<span class="tabular">${formatDateTimeVN(row.startedAt)}</span>` },
          {
            label: 'Thao tác',
            align: 'right',
            render: (row) => `<div class="cell-actions">
              <button type="button" class="btn btn-ghost btn-sm detail-rel" data-id="${esc(row.id)}">Chi tiết</button>
              ${row.status === 'ACTIVE' || row.status === 'PAUSED'
                ? `<button type="button" class="btn btn-graphite btn-sm transfer" data-member="${esc(row.memberId)}" data-coach="${esc(row.coachId)}">${icon('swap', 14)} Chuyển Coach</button>`
                : ''}
            </div>`,
          },
        ],
        rows: relationships,
        emptyHtml: renderEmptyState({ iconName: 'link', title: 'Chưa có quan hệ Member–Coach nào', description: 'Khi hội viên đăng ký gói Coach trên app, quan hệ sẽ hiển thị tại đây.' }),
      });
    }

    const contentHtml = `<div class="stack-20">
      <div class="meta-tabs" role="tablist">
        <button type="button" class="meta-tab-btn" role="tab" aria-selected="${tab === 'list'}" data-rel-tab="list">Quan hệ Member–Coach (${relationships.length})</button>
        <button type="button" class="meta-tab-btn" role="tab" aria-selected="${tab === 'terminations'}" data-rel-tab="terminations">Kết thúc sớm & Tranh chấp (${terminations.length})</button>
        <button type="button" class="meta-tab-btn" role="tab" aria-selected="${tab === 'transfers'}" data-rel-tab="transfers">Lịch sử chuyển Coach (${transfers.length})</button>
      </div>
      ${tabBody}
    </div>`;

    shell({ section: 'relationships', contentHtml });

    root.querySelectorAll('[data-rel-tab]').forEach((btn) => {
      btn.onclick = () => {
        const nextTab = btn.dataset.relTab;
        const nextParams = new URLSearchParams(params);
        nextParams.set('tab', nextTab);
        updateQuery({ tab: nextTab }, { replace: true });
        renderRelationshipsPage({ root, params: nextParams, shell });
      };
    });

    root.querySelectorAll('.detail-rel').forEach((btn) => {
      btn.onclick = () => {
        const rel = relationships.find((r) => r.id === btn.dataset.id);
        if (!rel) return;
        openDrawer({
          title: `${resolveMember(rel)} ↔ ${resolveCoach(rel)}`,
          subtitle: 'Chi tiết vận hành quan hệ Member–Coach',
          bodyHtml: `<div class="impact-box">
            <div class="impact-row"><span class="impact-key">UUID quan hệ</span><span class="impact-val tabular" style="font-size:12px">${esc(rel.id)}</span></div>
            <div class="impact-row"><span class="impact-key">Hội viên</span><span class="impact-val">${esc(resolveMember(rel))}</span></div>
            <div class="impact-row"><span class="impact-key">Huấn luyện viên</span><span class="impact-val">${esc(resolveCoach(rel))}</span></div>
            <div class="impact-row"><span class="impact-key">Trạng thái</span><span class="impact-val">${relationshipStatusBadge(rel)}</span></div>
            <div class="impact-row"><span class="impact-key">Ngày bắt đầu</span><span class="impact-val tabular">${formatDateTimeVN(rel.startedAt)}</span></div>
            ${rel.pausedAt ? `<div class="impact-row"><span class="impact-key">Tạm ngưng lúc</span><span class="impact-val tabular">${formatDateTimeVN(rel.pausedAt)}</span></div>` : ''}
            ${rel.endedAt ? `<div class="impact-row"><span class="impact-key">Kết thúc lúc</span><span class="impact-val tabular">${formatDateTimeVN(rel.endedAt)}</span></div>` : ''}
          </div>`,
        });
      };
    });

    root.querySelectorAll('.transfer').forEach((btn) => {
      btn.onclick = () => {
        const memberId = btn.dataset.member;
        const oldCoachId = btn.dataset.coach;
        const memberName = nameById.get(memberId) || 'Hội viên';
        const candidates = coaches.filter((c) => c.status === 'ACTIVE' && c.id !== oldCoachId);
        let transferKey = generateUuid();

        openModal({
          title: `Chuyển Coach cho ${memberName}`,
          subtitle: 'Kết thúc quan hệ cũ, bảo toàn gói và chuyển sang Coach mới đủ suất (< 8)',
          bodyHtml: `<form id="transfer-form" novalidate>
            <div class="meta-modal-body">
              <div class="field">
                <label class="field-label" for="trf-coach">Coach mới</label>
                <select id="trf-coach" class="form-select" name="newCoachId" required>
                  <option value="">Chọn Coach mới</option>
                  ${candidates.map((c) => `<option value="${esc(c.id)}">${esc(c.fullName)} (${Number(c.usedSlots ?? 0)}/8 suất)</option>`).join('')}
                </select>
              </div>
              <div class="field">
                <label class="field-label" for="trf-reason">Lý do chuyển Coach (bắt buộc)</label>
                <textarea id="trf-reason" class="form-control" name="reason" maxlength="1000" required placeholder="Nhập lý do chuyển Coach…"></textarea>
              </div>
            </div>
            <div class="meta-modal-footer">
              <button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
              <button type="submit" class="btn btn-primary" data-modal-submit>${icon('swap', 16)} Xác nhận chuyển Coach</button>
            </div>
          </form>`,
          onMount(ctrl) {
            const form = ctrl.dialog.querySelector('#transfer-form');
            const selectEl = form.querySelector('#trf-coach');
            if (selectEl) selectEl.onchange = () => { transferKey = generateUuid(); };
            form.onsubmit = async (event) => {
              event.preventDefault();
              ctrl.showError('');
              const newCoachId = form.querySelector('[name="newCoachId"]')?.value;
              const reason = (form.querySelector('[name="reason"]')?.value || '').trim();
              if (!newCoachId || !reason) {
                ctrl.showError('Vui lòng chọn Coach mới và nhập lý do chuyển.');
                return;
              }
              ctrl.setBusy(true);
              try {
                await api('/admin/coach-transfers', 'POST', { memberId, newCoachId, reason }, transferKey);
                ctrl.close();
                toast('Đã chuyển Coach thành công.');
                await renderRelationshipsPage({ root, params, shell });
              } catch (error) {
                ctrl.setBusy(false);
                ctrl.showError(error.message);
              }
            };
          },
        });
      };
    });

    root.querySelectorAll('.decide').forEach((btn) => {
      btn.onclick = () => {
        const decision = btn.dataset.value;
        const isApprove = decision === 'APPROVED';
        openConfirmModal({
          title: isApprove ? 'Chấp thuận kết thúc sớm quan hệ' : 'Từ chối yêu cầu kết thúc sớm',
          subtitle: 'Bắt buộc ghi rõ lý do phán quyết để lưu nhật ký hệ thống',
          requireReason: true,
          reasonLabel: 'Lý do phân xử (1–1000 ký tự)',
          reasonMaxLength: 1000,
          confirmLabel: isApprove ? 'Chấp thuận kết thúc' : 'Từ chối yêu cầu',
          confirmVariant: isApprove ? 'danger-solid' : 'primary',
          onConfirm: async ({ reason }) => {
            await api(`/admin/termination-requests/${btn.dataset.id}`, 'PATCH', { decision, reason });
            toast('Đã xử lý yêu cầu kết thúc sớm.');
            await renderRelationshipsPage({ root, params, shell });
          },
        });
      };
    });
  } catch (error) {
    shell({ section: 'relationships', contentHtml: renderErrorState({ title: 'Không tải được quan hệ', message: error.message }) });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderRelationshipsPage({ root, params, shell });
  }
}
