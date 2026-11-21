import { api } from '../services/api.js';
import { esc, statusBadge } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderDataTable } from '../components/data-table.js';
import { openDrawer } from '../components/drawer.js';
import { openModal } from '../components/modal.js';
import { renderEmptyState, renderErrorState, renderSkeletonPage } from '../components/states.js';
import { toast } from '../components/toast.js';
import { updateQuery } from '../state/router.js';

const DIFFICULTY_LABELS = {
  BEGINNER: 'Cơ bản',
  INTERMEDIATE: 'Trung bình',
  ADVANCED: 'Nâng cao',
};

export async function renderEquipmentPage({ root, params, shell }) {
  const tab = params?.get('tab') === 'exercises' ? 'exercises' : 'equipment';

  shell({ section: 'equipment', contentHtml: renderSkeletonPage({ cards: 0, rows: 6 }) });

  try {
    const [eqRes, exRes] = await Promise.all([
      api('/admin/equipment?pageSize=100'),
      api('/admin/exercises?pageSize=100').catch(() => ({ data: [] })),
    ]);

    const equipmentRows = eqRes?.data || [];
    const exerciseRows = exRes?.data || [];
    const eqNameById = new Map(equipmentRows.map((item) => [item.id, item.name]));

    const tableHtml = tab === 'equipment'
      ? renderDataTable({
        columns: [
          {
            label: 'Thiết bị',
            render: (row) => `<span class="person-name">${esc(row.name)}</span><span class="person-sub">${esc(row.safetyNotes || row.description || '—')}</span>`,
          },
          {
            label: 'Danh mục & Nhóm cơ',
            render: (row) => `<span>${esc(row.category)}</span><span class="person-sub">${esc((row.targetMuscles || []).join(', ') || '—')}</span>`,
          },
          { label: 'Hướng dẫn', render: (row) => `<span class="tabular">${(row.usageSteps || []).length} bước</span>` },
          { label: 'Trạng thái', render: (row) => statusBadge(row.status, row.status === 'ACTIVE' ? 'Hiển thị' : 'Đang ẩn') },
          {
            label: 'Thao tác',
            align: 'right',
            render: (row) => `<div class="cell-actions">
              <button type="button" class="btn btn-ghost btn-sm preview-eq" data-id="${esc(row.id)}">Xem trước</button>
              <button type="button" class="btn btn-ghost btn-sm edit-eq" data-id="${esc(row.id)}">Sửa</button>
            </div>`,
          },
        ],
        rows: equipmentRows,
        emptyHtml: renderEmptyState({ iconName: 'dumbbell', title: 'Chưa có thiết bị nào', description: 'Thêm thiết bị phòng tập kèm các bước sử dụng và lưu ý an toàn.', ctaLabel: 'Thêm thiết bị', ctaId: 'create-item-empty' }),
      })
      : renderDataTable({
        columns: [
          {
            label: 'Tên bài tập',
            render: (row) => `<span class="person-name">${esc(row.name)}</span><span class="person-sub">${esc((row.instructions || '').slice(0, 80))}</span>`,
          },
          {
            label: 'Thiết bị liên kết',
            render: (row) => esc(row.equipmentName || eqNameById.get(row.equipmentId) || 'Không gắn thiết bị'),
          },
          {
            label: 'Độ khó & Nhóm cơ',
            render: (row) => `<span class="meta-badge meta-badge-info">${esc(DIFFICULTY_LABELS[row.difficulty] || row.difficulty || 'Chưa phân loại')}</span><span class="person-sub">${esc((row.targetMuscles || []).join(', ') || '—')}</span>`,
          },
          { label: 'Trạng thái', render: (row) => statusBadge(row.status, row.status === 'ACTIVE' ? 'Hiển thị' : 'Đang ẩn') },
          {
            label: 'Thao tác',
            align: 'right',
            render: (row) => `<div class="cell-actions"><button type="button" class="btn btn-ghost btn-sm edit-ex" data-id="${esc(row.id)}">Sửa</button></div>`,
          },
        ],
        rows: exerciseRows,
        emptyHtml: renderEmptyState({ iconName: 'dumbbell', title: 'Chưa có bài tập nào', description: 'Thêm bài tập vào thư viện exercises để đồng bộ cho Coach và Member.', ctaLabel: 'Thêm bài tập', ctaId: 'create-item-empty' }),
      });

    const contentHtml = `<div class="stack-20">
      <div class="meta-tabs" role="tablist">
        <button type="button" class="meta-tab-btn" role="tab" aria-selected="${tab === 'equipment'}" data-cat-tab="equipment">Thiết bị phòng tập (${equipmentRows.length})</button>
        <button type="button" class="meta-tab-btn" role="tab" aria-selected="${tab === 'exercises'}" data-cat-tab="exercises">Thư viện bài tập · exercises (${exerciseRows.length})</button>
      </div>
      ${tableHtml}
    </div>`;

    shell({
      section: 'equipment',
      contentHtml,
      topbarActionsHtml: `<button type="button" class="btn btn-primary" id="create-item">${icon('plus', 16)} ${tab === 'equipment' ? 'Thêm thiết bị' : 'Thêm bài tập'}</button>`,
    });

    root.querySelectorAll('[data-cat-tab]').forEach((btn) => {
      btn.onclick = () => {
        const nextTab = btn.dataset.catTab;
        const nextParams = new URLSearchParams(params);
        nextParams.set('tab', nextTab);
        updateQuery({ tab: nextTab }, { replace: true });
        renderEquipmentPage({ root, params: nextParams, shell });
      };
    });

    const openEquipmentModal = (row) => {
      openModal({
        title: row ? `Sửa thiết bị: ${row.name}` : 'Thêm thiết bị phòng tập',
        subtitle: 'Hướng dẫn sử dụng và lưu ý an toàn hiển thị công khai trên ứng dụng',
        bodyHtml: `<form id="equipment-form" novalidate>
          <div class="meta-modal-body">
            <div class="grid-2">
              <div class="field"><label class="field-label" for="eq-name">Tên thiết bị</label><input id="eq-name" class="form-control" name="name" value="${esc(row?.name || '')}" required /></div>
              <div class="field"><label class="field-label" for="eq-cat">Danh mục</label><input id="eq-cat" class="form-control" name="category" value="${esc(row?.category || '')}" required /></div>
            </div>
            <div class="field"><label class="field-label" for="eq-muscles">Nhóm cơ mục tiêu (phân tách bằng dấu phẩy)</label><input id="eq-muscles" class="form-control" name="targetMuscles" value="${esc((row?.targetMuscles || []).join(', '))}" /></div>
            <div class="field"><label class="field-label" for="eq-steps">Các bước sử dụng (mỗi dòng 1 bước)</label><textarea id="eq-steps" class="form-control" name="steps" required>${esc((row?.usageSteps || []).join('\n'))}</textarea></div>
            <div class="field"><label class="field-label" for="eq-safety">Lưu ý an toàn</label><textarea id="eq-safety" class="form-control" name="safetyNotes">${esc(row?.safetyNotes || '')}</textarea></div>
            <div class="grid-2">
              <div class="field"><label class="field-label" for="eq-video">Video URL</label><input id="eq-video" class="form-control" name="videoUrl" type="url" value="${esc(row?.videoUrl || '')}" /></div>
              <div class="field"><label class="field-label" for="eq-status">Trạng thái</label><select id="eq-status" class="form-select" name="status"><option value="ACTIVE" ${row?.status !== 'HIDDEN' ? 'selected' : ''}>Hiển thị</option><option value="HIDDEN" ${row?.status === 'HIDDEN' ? 'selected' : ''}>Ẩn</option></select></div>
            </div>
          </div>
          <div class="meta-modal-footer"><button type="button" class="btn btn-ghost" data-close-modal>Hủy</button><button type="submit" class="btn btn-primary" data-modal-submit>Lưu thiết bị</button></div>
        </form>`,
        onMount(ctrl) {
          const form = ctrl.dialog.querySelector('#equipment-form');
          form.onsubmit = async (event) => {
            event.preventDefault();
            ctrl.showError('');
            const usageSteps = (form.querySelector('[name="steps"]')?.value || '').split('\n').map((s) => s.trim()).filter(Boolean);
            if (!usageSteps.length) {
              ctrl.showError('Cần nhập ít nhất 1 bước sử dụng thiết bị.');
              return;
            }
            const targetMuscles = (form.querySelector('[name="targetMuscles"]')?.value || '').split(',').map((s) => s.trim()).filter(Boolean);
            ctrl.setBusy(true);
            try {
              await api(row ? `/admin/equipment/${row.id}` : '/admin/equipment', row ? 'PATCH' : 'POST', {
                name: (form.querySelector('[name="name"]')?.value || '').trim(),
                category: (form.querySelector('[name="category"]')?.value || '').trim(),
                targetMuscles,
                usageSteps,
                safetyNotes: (form.querySelector('[name="safetyNotes"]')?.value || '').trim() || null,
                videoUrl: (form.querySelector('[name="videoUrl"]')?.value || '').trim() || null,
                status: form.querySelector('[name="status"]')?.value || 'ACTIVE',
              });
              ctrl.close();
              toast('Đã lưu thiết bị.');
              await renderEquipmentPage({ root, params, shell });
            } catch (error) {
              ctrl.setBusy(false);
              ctrl.showError(error.message);
            }
          };
        },
      });
    };

    const openExerciseModal = (row) => {
      openModal({
        title: row ? `Sửa bài tập: ${row.name}` : 'Thêm bài tập mới (exercises)',
        subtitle: 'Liên kết thiết bị, độ khó và hướng dẫn kỹ thuật chuẩn',
        bodyHtml: `<form id="exercise-form" novalidate>
          <div class="meta-modal-body">
            <div class="grid-2">
              <div class="field"><label class="field-label" for="ex-name">Tên bài tập</label><input id="ex-name" class="form-control" name="name" value="${esc(row?.name || '')}" required /></div>
              <div class="field"><label class="field-label" for="ex-eq">Thiết bị liên kết</label><select id="ex-eq" class="form-select" name="equipmentId"><option value="">Không gắn thiết bị</option>${equipmentRows.map((e) => `<option value="${esc(e.id)}" ${row?.equipmentId === e.id ? 'selected' : ''}>${esc(e.name)}</option>`).join('')}</select></div>
            </div>
            <div class="grid-2">
              <div class="field"><label class="field-label" for="ex-diff">Độ khó</label><select id="ex-diff" class="form-select" name="difficulty"><option value="">Chưa chọn</option><option value="BEGINNER" ${row?.difficulty === 'BEGINNER' ? 'selected' : ''}>Cơ bản</option><option value="INTERMEDIATE" ${row?.difficulty === 'INTERMEDIATE' ? 'selected' : ''}>Trung bình</option><option value="ADVANCED" ${row?.difficulty === 'ADVANCED' ? 'selected' : ''}>Nâng cao</option></select></div>
              <div class="field"><label class="field-label" for="ex-status">Trạng thái</label><select id="ex-status" class="form-select" name="status"><option value="ACTIVE" ${row?.status !== 'HIDDEN' ? 'selected' : ''}>Hiển thị</option><option value="HIDDEN" ${row?.status === 'HIDDEN' ? 'selected' : ''}>Ẩn</option></select></div>
            </div>
            <div class="field"><label class="field-label" for="ex-muscles">Nhóm cơ (phân tách bằng dấu phẩy)</label><input id="ex-muscles" class="form-control" name="targetMuscles" value="${esc((row?.targetMuscles || []).join(', '))}" /></div>
            <div class="field"><label class="field-label" for="ex-inst">Hướng dẫn kỹ thuật</label><textarea id="ex-inst" class="form-control" name="instructions" required>${esc(row?.instructions || '')}</textarea></div>
            <div class="field"><label class="field-label" for="ex-safety">Lưu ý an toàn</label><textarea id="ex-safety" class="form-control" name="safetyNotes">${esc(row?.safetyNotes || '')}</textarea></div>
            <div class="field"><label class="field-label" for="ex-video">Video hướng dẫn URL</label><input id="ex-video" class="form-control" name="videoUrl" type="url" value="${esc(row?.videoUrl || '')}" /></div>
          </div>
          <div class="meta-modal-footer"><button type="button" class="btn btn-ghost" data-close-modal>Hủy</button><button type="submit" class="btn btn-primary" data-modal-submit>Lưu bài tập</button></div>
        </form>`,
        onMount(ctrl) {
          const form = ctrl.dialog.querySelector('#exercise-form');
          form.onsubmit = async (event) => {
            event.preventDefault();
            ctrl.showError('');
            const targetMuscles = (form.querySelector('[name="targetMuscles"]')?.value || '').split(',').map((s) => s.trim()).filter(Boolean);
            ctrl.setBusy(true);
            try {
              await api(row ? `/admin/exercises/${row.id}` : '/admin/exercises', row ? 'PATCH' : 'POST', {
                name: (form.querySelector('[name="name"]')?.value || '').trim(),
                equipmentId: form.querySelector('[name="equipmentId"]')?.value || null,
                difficulty: form.querySelector('[name="difficulty"]')?.value || null,
                targetMuscles,
                instructions: (form.querySelector('[name="instructions"]')?.value || '').trim(),
                safetyNotes: (form.querySelector('[name="safetyNotes"]')?.value || '').trim() || null,
                videoUrl: (form.querySelector('[name="videoUrl"]')?.value || '').trim() || null,
                status: form.querySelector('[name="status"]')?.value || 'ACTIVE',
              });
              ctrl.close();
              toast('Đã lưu bài tập.');
              await renderEquipmentPage({ root, params, shell });
            } catch (error) {
              ctrl.setBusy(false);
              ctrl.showError(error.message);
            }
          };
        },
      });
    };

    const createBtn = root.querySelector('#create-item') || root.querySelector('#create-item-empty');
    if (createBtn) createBtn.onclick = () => (tab === 'equipment' ? openEquipmentModal(null) : openExerciseModal(null));
    root.querySelectorAll('.edit-eq').forEach((btn) => { btn.onclick = () => openEquipmentModal(equipmentRows.find((r) => r.id === btn.dataset.id)); });
    root.querySelectorAll('.edit-ex').forEach((btn) => { btn.onclick = () => openExerciseModal(exerciseRows.find((r) => r.id === btn.dataset.id)); });
    root.querySelectorAll('.preview-eq').forEach((btn) => {
      btn.onclick = () => {
        const item = equipmentRows.find((r) => r.id === btn.dataset.id);
        if (!item) return;
        openDrawer({
          title: item.name,
          subtitle: 'Xem trước hiển thị công khai trên App',
          bodyHtml: `<div class="impact-box">
            <div class="impact-row"><span class="impact-key">Danh mục</span><span class="impact-val">${esc(item.category)}</span></div>
            <div class="impact-row"><span class="impact-key">Nhóm cơ</span><span class="impact-val">${esc((item.targetMuscles || []).join(', ') || '—')}</span></div>
            <div class="impact-divider"></div>
            <div><strong>Các bước sử dụng:</strong><ol class="rule-list" style="margin-top:6px">${(item.usageSteps || []).map((s) => `<li>${esc(s)}</li>`).join('')}</ol></div>
            ${item.safetyNotes ? `<div class="impact-divider"></div><div><strong>Lưu ý an toàn:</strong><p class="card-sub">${esc(item.safetyNotes)}</p></div>` : ''}
          </div>`,
        });
      };
    });
  } catch (error) {
    shell({ section: 'equipment', contentHtml: renderErrorState({ title: 'Không tải được thiết bị & bài tập', message: error.message }) });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderEquipmentPage({ root, params, shell });
  }
}
