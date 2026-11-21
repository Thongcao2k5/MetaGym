import { handleMockApi } from './mock-members.js';

const TOKEN_KEY = 'metagym_admin_token';
const RETURN_URL_KEY = 'metagym_admin_return_url';
const SESSION_EXPIRED_KEY = 'metagym_admin_session_expired';

export class ApiError extends Error {
  constructor(message, { status = 0, code = 'NETWORK_ERROR', details = {} } = {}) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

function defaultBaseUrl() {
  try {
    return (import.meta.env?.VITE_API_BASE_URL || '/api/v1').replace(/\/$/, '');
  } catch {
    return '/api/v1';
  }
}

let apiBase = defaultBaseUrl();
let unauthorizedHandler = null;
let currentUser = null;

function storage() {
  return globalThis.sessionStorage;
}

export function configureApi({ baseUrl, onUnauthorized } = {}) {
  if (typeof baseUrl === 'string') apiBase = baseUrl.replace(/\/$/, '');
  if (typeof onUnauthorized === 'function' || onUnauthorized === null) {
    unauthorizedHandler = onUnauthorized;
  }
}

export function getToken() {
  return storage()?.getItem(TOKEN_KEY) || null;
}

export function setToken(token) {
  if (!storage()) return;
  if (token) storage().setItem(TOKEN_KEY, token);
  else storage().removeItem(TOKEN_KEY);
}

export function getCurrentUser() {
  return currentUser;
}

export function setCurrentUser(user) {
  currentUser = user ?? null;
}

export function saveReturnUrl(hash) {
  const clean = String(hash || '').trim();
  if (!clean || clean.startsWith('#/admin/login') || clean.startsWith('/admin/login')) return;
  storage()?.setItem(RETURN_URL_KEY, clean.startsWith('#') ? clean : `#${clean}`);
}

export function getReturnUrl() {
  return storage()?.getItem(RETURN_URL_KEY) || null;
}

export function consumeReturnUrl() {
  const url = getReturnUrl();
  storage()?.removeItem(RETURN_URL_KEY);
  return url;
}

export function markSessionExpired(returnHash) {
  saveReturnUrl(returnHash);
  storage()?.setItem(SESSION_EXPIRED_KEY, '1');
}

export function isSessionExpiredFlag() {
  return storage()?.getItem(SESSION_EXPIRED_KEY) === '1';
}

export function clearSessionExpiredFlag() {
  storage()?.removeItem(SESSION_EXPIRED_KEY);
}

export function clearSession({ expired = false, returnHash = null } = {}) {
  setToken(null);
  currentUser = null;
  if (expired) {
    markSessionExpired(returnHash || globalThis.location?.hash || '#/admin/dashboard');
  } else {
    clearSessionExpiredFlag();
    storage()?.removeItem(RETURN_URL_KEY);
  }
}

export function buildQuery(params = {}) {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value === undefined || value === null || value === '' || value === 'ALL') continue;
    search.set(key, String(value));
  }
  const qs = search.toString();
  return qs ? `?${qs}` : '';
}

function isDevBrowserRuntime() {
  try {
    return Boolean(import.meta.env?.DEV) && typeof window !== 'undefined';
  } catch {
    return false;
  }
}

export async function api(path, method = 'GET', body, idempotencyKeyOrOptions) {
  const options = typeof idempotencyKeyOrOptions === 'string'
    ? { idempotencyKey: idempotencyKeyOrOptions }
    : (idempotencyKeyOrOptions || {});

  const token = getToken();
  const headers = {
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
    ...(options.idempotencyKey ? { 'Idempotency-Key': options.idempotencyKey } : {}),
    ...(options.headers || {}),
  };

  let response;
  try {
    response = await globalThis.fetch(`${apiBase}${path}`, {
      method,
      headers,
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
  } catch {
    if (isDevBrowserRuntime()) {
      const mockPayload = handleMockApi(path, method, body);
      if (mockPayload) return mockPayload;
    }
    throw new ApiError('Không thể kết nối máy chủ. Kiểm tra mạng và bấm Thử lại.', {
      status: 0,
      code: 'NETWORK_ERROR',
      details: {},
    });
  }

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    if (isDevBrowserRuntime() && response.status >= 500) {
      const mockPayload = handleMockApi(path, method, body);
      if (mockPayload) return mockPayload;
    }
    const code = payload?.error?.code || `HTTP_${response.status}`;
    const message = payload?.error?.message || `Yêu cầu thất bại (HTTP ${response.status})`;
    const details = payload?.error?.details || {};

    if (response.status === 401 && token && !options.skipAuthRedirect && !path.startsWith('/auth/sessions')) {
      const currentHash = globalThis.location?.hash || '#/admin/dashboard';
      clearSession({ expired: true, returnHash: currentHash });
      if (unauthorizedHandler) unauthorizedHandler(currentHash);
    }

    throw new ApiError(message, { status: response.status, code, details });
  }

  return payload;
}
