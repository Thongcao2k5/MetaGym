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

export function getApiBaseUrl() {
  return apiBase;
}

/**
 * Resolves a backend-returned API asset path (e.g. `/api/v1/media/...` or `/api/v1/users/.../avatar`)
 * against the configured `getApiBaseUrl()` so cross-origin Admin hosts (Cloudflare Pages / localhost)
 * load images from the actual backend server instead of their own origin.
 */
export function resolveApiAssetUrl(pathOrUrl) {
  if (!pathOrUrl) return '';
  const raw = String(pathOrUrl).trim();
  if (!raw) return '';
  if (raw.startsWith('http://') || raw.startsWith('https://') || raw.startsWith('data:') || raw.startsWith('blob:')) {
    return raw;
  }
  if (raw.startsWith('/api/v1')) {
    return `${apiBase}${raw.slice('/api/v1'.length)}`;
  }
  return raw;
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
      ...(options.signal ? { signal: options.signal } : {}),
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
  } catch (err) {
    if (err?.name === 'AbortError') {
      throw new ApiError('Yêu cầu đã bị hủy.', {
        status: 0,
        code: 'ABORTED',
        details: {},
      });
    }
    throw new ApiError('Không thể kết nối máy chủ. Kiểm tra mạng và bấm Thử lại.', {
      status: 0,
      code: 'NETWORK_ERROR',
      details: {},
    });
  }

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
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

export async function uploadFormData(path, formData, { onProgress } = {}) {
  const token = getToken();
  const url = `${apiBase}${path}`;

  if (typeof globalThis.XMLHttpRequest === 'function') {
    return new Promise((resolve, reject) => {
      const xhr = new globalThis.XMLHttpRequest();
      xhr.open('POST', url, true);
      if (token) xhr.setRequestHeader('Authorization', `Bearer ${token}`);
      if (xhr.upload && typeof onProgress === 'function') {
        xhr.upload.onprogress = (event) => {
          if (event.lengthComputable && event.total > 0) {
            onProgress(Math.min(100, Math.round((event.loaded / event.total) * 100)));
          }
        };
      }
      xhr.onload = () => {
        let payload = {};
        try { payload = JSON.parse(xhr.responseText || '{}'); } catch { payload = {}; }
        if (xhr.status >= 200 && xhr.status < 300) {
          onProgress?.(100);
          resolve(payload);
        } else {
          if (xhr.status === 401 && token) {
            const currentHash = globalThis.location?.hash || '#/admin/media-library';
            clearSession({ expired: true, returnHash: currentHash });
            if (unauthorizedHandler) unauthorizedHandler(currentHash);
          }
          reject(new ApiError(payload?.error?.message || `Tải lên thất bại (HTTP ${xhr.status})`, {
            status: xhr.status,
            code: payload?.error?.code || `HTTP_${xhr.status}`,
            details: payload?.error?.details || {},
          }));
        }
      };
      xhr.onerror = () => {
        reject(new ApiError('Không thể kết nối máy chủ khi tải ảnh.', { status: 0, code: 'NETWORK_ERROR' }));
      };
      xhr.send(formData);
    });
  }

  const response = await globalThis.fetch(url, {
    method: 'POST',
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    body: formData,
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new ApiError(payload?.error?.message || `Tải lên thất bại (HTTP ${response.status})`, {
      status: response.status,
      code: payload?.error?.code || `HTTP_${response.status}`,
      details: payload?.error?.details || {},
    });
  }
  onProgress?.(100);
  return payload;
}

export async function uploadRaw(path, body, mimeType = 'image/jpeg', options = {}) {
  const token = getToken();
  const url = `${apiBase}${path}`;
  const binaryBody = (body && typeof body.arrayBuffer === 'function') ? await body.arrayBuffer() : body;
  let response;
  try {
    response = await globalThis.fetch(url, {
      method: 'POST',
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        'Content-Type': mimeType,
        ...(options.headers || {}),
      },
      body: binaryBody,
    });
  } catch (err) {
    if (err?.name === 'AbortError') {
      throw new ApiError('Yêu cầu đã bị hủy.', { status: 0, code: 'ABORTED', details: {} });
    }
    throw new ApiError('Không thể kết nối máy chủ. Kiểm tra mạng và bấm Thử lại.', {
      status: 0,
      code: 'NETWORK_ERROR',
      details: {},
    });
  }

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const code = payload?.error?.code || `HTTP_${response.status}`;
    const message = payload?.error?.message || `Tải lên thất bại (HTTP ${response.status})`;
    const details = payload?.error?.details || {};

    if (response.status === 401 && token) {
      const currentHash = globalThis.location?.hash || '#/admin/dashboard';
      clearSession({ expired: true, returnHash: currentHash });
      if (unauthorizedHandler) unauthorizedHandler(currentHash);
    }

    throw new ApiError(message, { status: response.status, code, details });
  }

  return payload;
}

