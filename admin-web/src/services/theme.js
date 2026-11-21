const THEME_STORAGE_KEY = 'meta-admin-theme';

function getStorage() {
  return typeof window !== 'undefined' ? window.localStorage : null;
}

export function getTheme() {
  try {
    const saved = getStorage()?.getItem?.(THEME_STORAGE_KEY);
    if (saved === 'light' || saved === 'dark') return saved;
  } catch {
    // Ignore storage access errors in restricted environments or tests
  }
  const attr = globalThis.document?.documentElement?.getAttribute?.('data-bs-theme');
  return attr === 'light' ? 'light' : 'dark';
}

export function applyTheme(theme) {
  const next = theme === 'light' ? 'light' : 'dark';
  globalThis.document?.documentElement?.setAttribute?.('data-bs-theme', next);
  try {
    getStorage()?.setItem?.(THEME_STORAGE_KEY, next);
  } catch {
    // Ignore storage access errors
  }
  return next;
}

export function toggleTheme() {
  const next = getTheme() === 'dark' ? 'light' : 'dark';
  return applyTheme(next);
}

export function initTheme() {
  return applyTheme(getTheme());
}
