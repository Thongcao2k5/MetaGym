import { api } from '../services/api.js';
import { esc, initials, statusBadge } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderBanner, renderErrorState, renderSkeletonPage } from '../components/states.js';
import { toast } from '../components/toast.js';

export async function renderProfilePage({ root, shell, onSignOut }) {
  shell({ section: 'profile', contentHtml: renderSkeletonPage({ cards: 0, rows: 3 }) });

  try {
    const { data } = await api('/users/me');

    const contentHtml = `<div class="grid-split">
      <section class="meta-card stack-16">
        <div style="display:flex;align-items:center;gap:14px">
          <span class="meta-avatar" style="width:52px;height:52px;font-size:18px">${esc(initials(data.fullName))}</span>
          <div>
            <h2 class="card-title-text">${esc(data.fullName)}</h2>
            <p class="card-sub">${esc(data.email)}</p>
          </div>
        </div>
        <div class="impact-box">
          <div class="impact-row"><span class="impact-key">Vai trò</span><span class="impact-val"><span class="meta-badge meta-badge-coral">ADMIN</span></span></div>
          <div class="impact-row"><span class="impact-key">Trạng thái</span><span class="impact-val">${statusBadge(data.status || 'ACTIVE')}</span></div>
          <div class="impact-row"><span class="impact-key">Múi giờ vận hành</span><span class="impact-val tabular">Asia/Ho_Chi_Minh (GMT+7)</span></div>
        </div>
      </section>

      <form id="password-form" class="meta-card stack-16" novalidate>
        <div>
          <h2 class="card-title-text">Đổi mật khẩu quản trị</h2>
          <p class="card-sub">Đổi mật khẩu thành công sẽ tự động thu hồi toàn bộ phiên cũ và yêu cầu đăng nhập lại.</p>
        </div>
        <div id="pw-error" aria-live="assertive"></div>
        <div class="field">
          <label class="field-label" for="pw-current">Mật khẩu hiện tại</label>
          <input id="pw-current" class="form-control" name="currentPassword" type="password" autocomplete="current-password" required />
        </div>
        <div class="field">
          <label class="field-label" for="pw-new">Mật khẩu mới</label>
          <input id="pw-new" class="form-control" name="newPassword" type="password" autocomplete="new-password" minlength="8" required />
          <span class="field-hint">Tối thiểu 8 ký tự, bao gồm chữ hoa, chữ thường và chữ số.</span>
        </div>
        <div class="field">
          <label class="field-label" for="pw-confirm">Xác nhận mật khẩu mới</label>
          <input id="pw-confirm" class="form-control" name="confirmPassword" type="password" autocomplete="new-password" minlength="8" required />
        </div>
        <div style="display:flex;justify-content:flex-end">
          <button type="submit" class="btn btn-primary" id="pw-submit">${icon('key', 16)} Đổi mật khẩu</button>
        </div>
      </form>
    </div>`;

    shell({ section: 'profile', contentHtml });

    const form = root.querySelector('#password-form');
    const errorBox = root.querySelector('#pw-error');
    const submitBtn = root.querySelector('#pw-submit');
    if (form) {
      form.onsubmit = async (event) => {
        event.preventDefault();
        errorBox.innerHTML = '';
        const currentPassword = form.querySelector('[name="currentPassword"]')?.value || '';
        const newPassword = form.querySelector('[name="newPassword"]')?.value || '';
        const confirmPassword = form.querySelector('[name="confirmPassword"]')?.value || '';
        if (newPassword !== confirmPassword) {
          errorBox.innerHTML = renderBanner({ kind: 'danger', title: 'Mật khẩu xác nhận không khớp', text: 'Vui lòng nhập trùng khớp mật khẩu mới.' });
          return;
        }
        if (newPassword.length < 8 || !/[a-z]/.test(newPassword) || !/[A-Z]/.test(newPassword) || !/[0-9]/.test(newPassword)) {
          errorBox.innerHTML = renderBanner({ kind: 'danger', title: 'Mật khẩu mới chưa đủ mạnh', text: 'Cần tối thiểu 8 ký tự gồm chữ hoa, chữ thường và chữ số.' });
          return;
        }
        submitBtn.disabled = true;
        try {
          await api('/users/me/password', 'PATCH', { currentPassword, newPassword });
          toast('Đã đổi mật khẩu. Vui lòng đăng nhập lại.', 'info');
          if (typeof onSignOut === 'function') onSignOut();
        } catch (error) {
          errorBox.innerHTML = renderBanner({ kind: 'danger', title: 'Đổi mật khẩu thất bại', text: error.message });
          submitBtn.disabled = false;
        }
      };
    }
  } catch (error) {
    shell({ section: 'profile', contentHtml: renderErrorState({ title: 'Không tải được hồ sơ', message: error.message }) });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderProfilePage({ root, shell, onSignOut });
  }
}
