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
import { renderToggle } from '../components/toggle.js';
import { getTheme, toggleTheme } from '../services/theme.js';

const REMEMBER_CREDS_KEY = 'meta-admin-remember-creds';
const LEGACY_REMEMBER_EMAIL_KEY = 'meta-admin-remember-email';

function getStorage() {
  return typeof window !== 'undefined' ? window.localStorage : null;
}

function encodeCreds(data) {
  const json = JSON.stringify(data);
  if (typeof btoa === 'function' && typeof TextEncoder === 'function') {
    const bytes = new TextEncoder().encode(json);
    let bin = '';
    bytes.forEach((b) => { bin += String.fromCharCode(b); });
    return btoa(bin);
  }
  return json;
}

function decodeCreds(raw) {
  if (!raw) return null;
  try {
    if (raw.startsWith('{')) return JSON.parse(raw);
    if (typeof atob === 'function' && typeof TextDecoder === 'function') {
      const bin = atob(raw);
      const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
      return JSON.parse(new TextDecoder().decode(bytes));
    }
  } catch {
    // Ignore malformed saved credentials
  }
  return null;
}

function readRememberedCreds() {
  try {
    const storage = getStorage();
    const raw = storage?.getItem?.(REMEMBER_CREDS_KEY);
    const parsed = decodeCreds(raw);
    if (parsed && typeof parsed.email === 'string') {
      return { email: parsed.email, password: typeof parsed.password === 'string' ? parsed.password : '' };
    }
    const legacyEmail = storage?.getItem?.(LEGACY_REMEMBER_EMAIL_KEY) || '';
    return legacyEmail ? { email: legacyEmail, password: '' } : { email: '', password: '' };
  } catch {
    return { email: '', password: '' };
  }
}

function saveRememberedCreds(email, password) {
  try {
    const storage = getStorage();
    if (!storage) return;
    storage.removeItem?.(LEGACY_REMEMBER_EMAIL_KEY);
    if (email) {
      storage.setItem?.(REMEMBER_CREDS_KEY, encodeCreds({ email, password: password || '' }));
    } else {
      storage.removeItem?.(REMEMBER_CREDS_KEY);
    }
  } catch {
    // Ignore storage access errors
  }
}

export function renderLoginPage({ root, params, onLoginSuccess }) {
  const expired = isSessionExpiredFlag() || params?.get('expired') === '1';
  const returnUrl = params?.get('returnUrl') || getReturnUrl();
  const savedCreds = readRememberedCreds();
  const hasSaved = Boolean(savedCreds.email);
  const currentTheme = getTheme();
  const nextThemeLabel = currentTheme === 'dark' ? 'Chuyển sang giao diện sáng' : 'Chuyển sang giao diện tối';

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
      <div style="display:flex;align-items:center;justify-content:space-between;gap:12px">
        <div style="display:flex;align-items:center;gap:12px">
          <span class="brand-mark">MG</span>
          <div>
            <h1 style="margin:0;font-size:22px;font-weight:800;color:var(--meta-text-strong)">Meta Gym Admin</h1>
            <p style="margin:2px 0 0;font-size:13px;color:var(--meta-text-secondary)">Cổng quản trị vận hành phòng gym</p>
          </div>
        </div>
        <button type="button" class="btn btn-ghost btn-icon" id="login-theme-toggle" aria-label="${nextThemeLabel}" title="${nextThemeLabel}">
          ${icon(currentTheme === 'dark' ? 'sun' : 'moon', 18)}
        </button>
      </div>

      ${expiredBanner}
      <div id="login-error" aria-live="assertive"></div>

      <div class="field">
        <label class="field-label" for="login-email">Email quản trị</label>
        <input id="login-email" class="form-control" name="email" type="email" autocomplete="username" placeholder="admin@metagym.vn" value="${esc(savedCreds.email)}" required />
      </div>

      <div class="field">
        <label class="field-label" for="login-password">Mật khẩu</label>
        <div class="password-field">
          <input id="login-password" class="form-control" name="password" type="password" autocomplete="current-password" placeholder="Nhập mật khẩu quản trị" value="${esc(savedCreds.password)}" required />
          <button type="button" class="password-toggle" id="toggle-login-password" aria-label="Hiện mật khẩu" aria-pressed="false" title="Hiện mật khẩu">
            ${icon('eye', 18)}
          </button>
        </div>
        <span class="field-hint">Cấp phiên cho Quản trị viên (Admin) và Nhân sự vận hành (Quản lý, Lễ tân/Thu ngân, Kỹ thuật viên).</span>
      </div>

      <div class="login-remember-row">
        ${renderToggle({
          id: 'login-remember',
          checked: hasSaved,
          label: 'Lưu email & mật khẩu trên trình duyệt này',
        })}
      </div>

      <button type="submit" class="btn btn-primary" id="login-submit" style="width:100%">
        ${icon('lock', 16)} Đăng nhập
      </button>
    </form>
  </main>`;

  const form = root.querySelector('#login');
  const emailInput = root.querySelector('#login-email');
  const passwordInput = root.querySelector('#login-password');
  const togglePwdBtn = root.querySelector('#toggle-login-password');
  const rememberCheck = root.querySelector('#login-remember');
  const themeBtn = root.querySelector('#login-theme-toggle');
  const errorBox = root.querySelector('#login-error');
  const submitBtn = root.querySelector('#login-submit');

  if (themeBtn) {
    themeBtn.onclick = () => {
      const next = toggleTheme();
      const label = next === 'dark' ? 'Chuyển sang giao diện sáng' : 'Chuyển sang giao diện tối';
      themeBtn.innerHTML = icon(next === 'dark' ? 'sun' : 'moon', 18);
      themeBtn.setAttribute?.('aria-label', label);
      themeBtn.setAttribute?.('title', label);
    };
  }

  if (togglePwdBtn && passwordInput) {
    togglePwdBtn.onclick = () => {
      const show = passwordInput.type === 'password';
      passwordInput.type = show ? 'text' : 'password';
      togglePwdBtn.innerHTML = icon(show ? 'eyeOff' : 'eye', 18);
      togglePwdBtn.setAttribute?.('aria-pressed', String(show));
      const label = show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu';
      togglePwdBtn.setAttribute?.('aria-label', label);
      togglePwdBtn.setAttribute?.('title', label);
    };
  }

  if (rememberCheck && passwordInput) {
    rememberCheck.onchange = () => {
      passwordInput.setAttribute?.('autocomplete', rememberCheck.checked ? 'current-password' : 'off');
      if (!rememberCheck.checked) saveRememberedCreds('', '');
    };
  }

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
      if (!user || !['ADMIN', 'STAFF'].includes(user.role)) {
        showLoginError('Không có quyền quản trị', 'Tài khoản này không thuộc nhân sự vận hành Cổng quản trị.');
        return;
      }
      if (rememberCheck?.checked) {
        saveRememberedCreds(email, password);
      } else {
        saveRememberedCreds('', '');
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
