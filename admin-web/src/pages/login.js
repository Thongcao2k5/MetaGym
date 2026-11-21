import {
  api,
  clearSessionExpiredFlag,
  consumeReturnUrl,
  getReturnUrl,
  isSessionExpiredFlag,
  setCurrentUser,
  setToken,
} from '../services/api.js';
import { esc } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderBanner } from '../components/states.js';
import { toast } from '../components/toast.js';

export function renderLoginPage({ root, params, onLoginSuccess }) {
  const expired = isSessionExpiredFlag() || params?.get('expired') === '1';
  const returnUrl = params?.get('returnUrl') || getReturnUrl();

  const expiredBanner = expired ? renderBanner({
    kind: 'warn',
    iconName: 'alert',
    title: 'Phiên đăng nhập đã hết hạn',
    textHtml: returnUrl
      ? `Vui lòng đăng nhập lại. Hệ thống sẽ đưa bạn quay lại trang trước đó: <code style="color:var(--meta-reflection)">${esc(returnUrl)}</code>`
      : 'Vui lòng đăng nhập lại bằng tài khoản Quản trị viên.',
    role: 'status',
  }) : '';

  root.innerHTML = `<main class="login-screen" id="main-content">
    <form class="login-card" id="login" novalidate>
      <div style="display:flex;align-items:center;gap:12px">
        <span class="brand-mark">MG</span>
        <div>
          <h1 style="margin:0;font-size:22px;font-weight:800;color:var(--meta-text-strong)">Meta Gym Admin</h1>
          <p style="margin:2px 0 0;font-size:13px;color:var(--meta-text-secondary)">Cổng quản trị vận hành phòng gym · Dark Graphite</p>
        </div>
      </div>

      ${expiredBanner}
      <div id="login-error" aria-live="assertive"></div>

      <div class="field">
        <label class="field-label" for="login-email">Email quản trị</label>
        <input id="login-email" class="form-control" name="email" type="email" autocomplete="username" placeholder="admin@metagym.vn" required />
      </div>

      <div class="field">
        <label class="field-label" for="login-password">Mật khẩu</label>
        <input id="login-password" class="form-control" name="password" type="password" autocomplete="current-password" placeholder="Nhập mật khẩu quản trị" required />
        <span class="field-hint">Phiên chỉ cấp cho vai trò ADMIN; tự động thu hồi khi đổi mật khẩu hoặc tài khoản bị khóa.</span>
      </div>

      <button type="submit" class="btn btn-primary" id="login-submit" style="width:100%">
        ${icon('lock', 16)} ${expired && returnUrl ? 'Đăng nhập & quay lại trang trước' : 'Đăng nhập cổng quản trị'}
      </button>

      <div style="padding-top:8px;border-top:1px solid var(--meta-border);font-size:12px;color:var(--meta-text-secondary)">
        Múi giờ vận hành: Asia/Ho_Chi_Minh (GMT+7)
      </div>
    </form>
  </main>`;

  const form = root.querySelector('#login');
  const emailInput = root.querySelector('#login-email');
  const passwordInput = root.querySelector('#login-password');
  const errorBox = root.querySelector('#login-error');
  const submitBtn = root.querySelector('#login-submit');

  const showLoginError = (title, message) => {
    errorBox.innerHTML = renderBanner({
      kind: 'danger',
      iconName: 'alert',
      title,
      text: message,
      role: 'alert',
    });
  };

  form.onsubmit = async (event) => {
    event.preventDefault();
    errorBox.innerHTML = '';
    const email = (emailInput?.value || '').trim();
    const password = passwordInput?.value || '';

    if (!email || !password) {
      showLoginError('Thiếu thông tin đăng nhập', 'Vui lòng nhập đầy đủ email và mật khẩu.');
      return;
    }

    submitBtn.disabled = true;
    try {
      const result = await api('/auth/sessions', 'POST', { email, password }, { skipAuthRedirect: true });
      const user = result?.data?.user;
      if (!user || user.role !== 'ADMIN') {
        showLoginError('Không có quyền quản trị', 'Tài khoản này không thuộc vai trò Quản trị viên (ADMIN).');
        return;
      }
      setToken(result.data.accessToken);
      setCurrentUser(user);
      clearSessionExpiredFlag();
      const target = params?.get('returnUrl') || consumeReturnUrl() || '#/admin/dashboard';
      toast(expired ? 'Đã khôi phục phiên và quay lại trang trước.' : 'Đăng nhập Quản trị viên thành công.');
      if (typeof onLoginSuccess === 'function') {
        await onLoginSuccess(target);
      }
    } catch (error) {
      if (error?.status === 403) {
        showLoginError('Tài khoản đã bị vô hiệu hóa (403)', error.message || 'Tài khoản quản trị này đang bị khóa.');
      } else if (error?.status === 401) {
        showLoginError('Sai email hoặc mật khẩu (401)', error.message || 'Kiểm tra lại thông tin tài khoản Admin.');
      } else {
        showLoginError('Đăng nhập không thành công', error?.message || 'Không thể kết nối máy chủ.');
      }
      // Preserve email value intentionally; only keep inputs intact for quick retry
    } finally {
      submitBtn.disabled = false;
    }
  };
}
