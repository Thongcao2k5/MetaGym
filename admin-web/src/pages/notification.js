import {
  getNotificationPageHtml,
  bindNotificationPageEvents,
  refreshNotifications,
} from '../components/notifications.js';
import { api } from '../services/api.js';
import { esc, formatDateTimeVN } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderEmptyState } from '../components/states.js';
import { toast } from '../components/toast.js';

const AUDIENCE_LABELS = {
  ALL: 'Tất cả (Hội viên & Coach)',
  MEMBER: 'Chỉ Hội viên',
  COACH: 'Chỉ Coach',
};

const ROUTE_OPTIONS = [
  { value: '', label: 'Không điều hướng (mở chi tiết thông báo)' },
  { value: '/member/features/sessions', label: 'Lịch tập / Lịch hẹn' },
  { value: '/member/features/training', label: 'Giáo trình tập luyện' },
  { value: '/member/features/nutrition', label: 'Dinh dưỡng & Thực đơn' },
  { value: '/member/features/membership', label: 'Gói hội viên' },
];

function renderBroadcastComposerHtml() {
  return `
    <div class="meta-card stack-16" id="broadcast-composer-card">
      <div class="d-flex align-items-center justify-content-between gap-2 flex-wrap">
        <div>
          <h2 class="h5 mb-1">Gửi thông báo tới App (Broadcast)</h2>
          <p class="text-secondary small mb-0">Phát thông báo Realtime + Push FCM tới Hội viên và/hoặc Coach.</p>
        </div>
        <span class="meta-badge meta-badge-coral">Hệ thống</span>
      </div>
      <form id="admin-broadcast-form" class="row g-3" novalidate>
        <div class="col-12 col-lg-6">
          <label class="form-label" for="broadcast-title">Tiêu đề thông báo</label>
          <input
            type="text"
            class="form-control"
            id="broadcast-title"
            name="title"
            maxlength="120"
            required
            placeholder="Ví dụ: Bảo trì hệ thống 23:00 tối nay"
          />
        </div>
        <div class="col-12 col-md-6 col-lg-3">
          <label class="form-label" for="broadcast-audience">Đối tượng nhận</label>
          <select class="form-select" id="broadcast-audience" name="audience">
            <option value="ALL">Tất cả (Hội viên &amp; Coach)</option>
            <option value="MEMBER">Chỉ Hội viên</option>
            <option value="COACH">Chỉ Coach</option>
          </select>
        </div>
        <div class="col-12 col-md-6 col-lg-3">
          <label class="form-label" for="broadcast-route">Điều hướng khi chạm</label>
          <select class="form-select" id="broadcast-route" name="actionRoute">
            ${ROUTE_OPTIONS.map((opt) => `<option value="${esc(opt.value)}">${esc(opt.label)}</option>`).join('')}
          </select>
        </div>
        <div class="col-12">
          <label class="form-label" for="broadcast-body">Nội dung thông báo</label>
          <textarea
            class="form-control"
            id="broadcast-body"
            name="body"
            rows="3"
            maxlength="1000"
            required
            placeholder="Nhập nội dung ngắn gọn, rõ ràng hiển thị trên App và thanh thông báo..."
          ></textarea>
        </div>
        <div class="col-12 d-flex align-items-center justify-content-between gap-2 flex-wrap">
          <div class="small text-secondary" id="broadcast-status-msg" role="status" aria-live="polite"></div>
          <button type="submit" class="btn btn-primary" id="broadcast-submit-btn">
            ${icon('bell', 16)} Gửi thông báo ngay
          </button>
        </div>
      </form>
    </div>
  `;
}

function renderBroadcastHistoryHtml(items = [], errorMsg = null) {
  if (errorMsg) {
    return `<div class="text-danger small">${esc(errorMsg)}</div>`;
  }
  if (!items.length) {
    return renderEmptyState({
      iconName: 'bell',
      title: 'Chưa có lịch sử gửi thông báo',
      description: 'Các thông báo broadcast bạn gửi tới App sẽ được lưu vết tại đây.',
    });
  }
  return `
    <div class="notif-list">
      ${items.map((item) => {
        const audienceLabel = AUDIENCE_LABELS[item.audience] || item.audience || 'Tất cả';
        const timeText = item.createdAt ? formatDateTimeVN(item.createdAt) : '';
        return `
          <div class="notif-item is-read">
            <div class="notif-item-top">
              <div class="d-flex align-items-center gap-2 flex-wrap">
                <span class="meta-badge meta-badge-info">${esc(audienceLabel)}</span>
                <span class="meta-badge meta-badge-neutral tabular">${esc(String(item.recipientCount ?? 0))} người nhận</span>
              </div>
              <span class="notif-item-time tabular">${esc(timeText)}</span>
            </div>
            <div class="notif-item-title">${esc(item.title || '')}</div>
            <div class="notif-item-sub">${esc(item.body || '')}</div>
          </div>
        `;
      }).join('')}
    </div>
  `;
}

export async function renderNotificationPage({ root, shell }) {
  shell({
    section: 'notification',
    topbarActionsHtml: `<button type="button" class="btn btn-graphite btn-sm" id="notif-page-refresh">${icon('refresh', 16)} Làm mới</button>`,
    contentHtml: `
      <div class="stack-16">
        ${renderBroadcastComposerHtml()}
        <div class="meta-card stack-16" id="broadcast-history-card">
          <div class="d-flex align-items-center justify-content-between gap-2 flex-wrap">
            <h2 class="h5 mb-0">Lịch sử thông báo đã gửi</h2>
            <button type="button" class="btn btn-graphite btn-sm" id="broadcast-history-refresh">${icon('refresh', 15)} Tải lại</button>
          </div>
          <div id="broadcast-history-list"><div class="notif-empty">Đang tải lịch sử...</div></div>
        </div>
        <div class="meta-card stack-16" id="notif-page-root">${getNotificationPageHtml()}</div>
      </div>
    `,
  });

  bindNotificationPageEvents(root);

  const loadHistory = async () => {
    const historyEl = root.querySelector?.('#broadcast-history-list');
    if (!historyEl) return;
    try {
      const res = await api('/admin/notifications/broadcasts?page=1&pageSize=20');
      historyEl.innerHTML = renderBroadcastHistoryHtml(Array.isArray(res?.data) ? res.data : []);
    } catch (err) {
      historyEl.innerHTML = renderBroadcastHistoryHtml([], err?.message || 'Không tải được lịch sử gửi.');
    }
  };

  const form = root.querySelector?.('#admin-broadcast-form');
  if (form) {
    form.onsubmit = async (event) => {
      event?.preventDefault?.();
      const titleEl = root.querySelector?.('#broadcast-title');
      const bodyEl = root.querySelector?.('#broadcast-body');
      const audienceEl = root.querySelector?.('#broadcast-audience');
      const routeEl = root.querySelector?.('#broadcast-route');
      const statusEl = root.querySelector?.('#broadcast-status-msg');
      const submitBtn = root.querySelector?.('#broadcast-submit-btn');

      const title = String(titleEl?.value || '').trim();
      const body = String(bodyEl?.value || '').trim();
      const audience = String(audienceEl?.value || 'ALL').trim() || 'ALL';
      const actionRoute = String(routeEl?.value || '').trim() || null;

      if (!title || !body) {
        if (statusEl) statusEl.textContent = 'Vui lòng nhập đầy đủ tiêu đề và nội dung.';
        toast('Vui lòng nhập đầy đủ tiêu đề và nội dung.', 'warning');
        return;
      }

      if (submitBtn) submitBtn.disabled = true;
      if (statusEl) statusEl.textContent = 'Đang gửi thông báo...';
      try {
        const res = await api('/admin/notifications/broadcast', 'POST', {
          title,
          body,
          audience,
          ...(actionRoute ? { actionRoute } : {}),
        });
        const count = res?.data?.recipientCount ?? 0;
        if (titleEl) titleEl.value = '';
        if (bodyEl) bodyEl.value = '';
        if (routeEl) routeEl.value = '';
        if (statusEl) statusEl.textContent = `Đã gửi tới ${count} người nhận.`;
        toast(`Đã gửi thông báo tới ${count} người nhận.`, 'success');
        await loadHistory();
      } catch (err) {
        const message = err?.message || 'Không gửi được thông báo.';
        if (statusEl) statusEl.textContent = message;
        toast(message, 'danger');
      } finally {
        if (submitBtn) submitBtn.disabled = false;
      }
    };
  }

  const historyRefresh = root.querySelector?.('#broadcast-history-refresh');
  if (historyRefresh) {
    historyRefresh.onclick = () => loadHistory();
  }

  const topRefresh = root.querySelector?.('#notif-page-refresh');
  if (topRefresh) {
    topRefresh.onclick = async () => {
      await Promise.all([refreshNotifications({ force: true }), loadHistory()]);
    };
  }

  await Promise.all([refreshNotifications({ force: true }), loadHistory()]);
}
