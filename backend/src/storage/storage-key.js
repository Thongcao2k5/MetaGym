const BARE_UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

const FOLDER_KEY_PATTERN =
  /^(?:[a-z0-9_-]{2,32}\/)+[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}(\.[a-z0-9]{2,5})?$/;

export const MEDIA_PURPOSE_FOLDERS = Object.freeze({
  AVATAR: 'users/avatars',
  GYM: 'gym',
  EQUIPMENT: 'equipment',
  EXERCISE: 'exercises',
  COACH_OUTCOME: 'coaching/outcomes',
  PACKAGE: 'packages',
  SYSTEM_ICON: 'system/icons',
  VOUCHER: 'marketing/vouchers',
  BANNER: 'marketing/banners',
  SLIDE: 'marketing/slides',
  PROGRESS_PHOTO: 'tracking/progress',
  MEAL_PHOTO: 'nutrition/meals',
  MESSAGE: 'communication/messages',
});

/**
 * Validates that a storage key is either a legacy bare UUID or a safe `<folder>/.../<uuid>[.<ext>]` key.
 * Rejects path traversal (`..`), backslashes, double slashes, leading slashes, and null bytes.
 */
export function isValidStorageKey(key) {
  if (typeof key !== 'string' || !key) return false;
  if (key.includes('\0') || key.includes('..') || key.includes('\\') || key.includes('//')) {
    return false;
  }
  return BARE_UUID_PATTERN.test(key) || FOLDER_KEY_PATTERN.test(key);
}

/**
 * Asserts that `key` matches the allowed storage key patterns.
 */
export function assertValidStorageKey(key) {
  if (!isValidStorageKey(key)) {
    throw new Error('Invalid image storage key');
  }
}

/**
 * Returns domain-scoped storage keys for user avatar full (512px) and thumbnail (120px) images.
 */
export function buildAvatarStorageKeys(id) {
  return {
    storageKey: `users/avatars/${id}.webp`,
    thumbKey: `users/avatars/thumbs/${id}.webp`,
  };
}

/**
 * Resolves thumbnail key candidates from an avatar `storage_key` (supports both nested `users/avatars/` and legacy root UUIDs).
 */
export function resolveAvatarThumbKeys(storageKey) {
  if (!storageKey) return [];
  const clean = String(storageKey);
  if (clean.startsWith('users/avatars/')) {
    const fileName = clean.slice('users/avatars/'.length);
    const base = fileName.replace(/\.[a-z0-9]+$/i, '');
    return [`users/avatars/thumbs/${base}.webp`];
  }
  const base = clean.replace(/\.[a-z0-9]+$/i, '');
  return [`users/avatars/thumbs/${base}.webp`, `thumbnails/${base}.webp`];
}

/**
 * Builds domain-scoped storage keys for membership/coach package full (WebP) and thumbnail (240px fit inside) images.
 */
export function buildPackageStorageKeys(id) {
  return {
    storageKey: `packages/${id}.webp`,
    thumbKey: `packages/thumbs/${id}.webp`,
  };
}

/**
 * Resolves thumbnail key candidates from a package image `storage_key`.
 */
export function resolvePackageThumbKeys(storageKey) {
  if (!storageKey) return [];
  const clean = String(storageKey);
  if (!clean.startsWith('packages/')) return [];
  const fileName = clean.slice('packages/'.length).replace(/^thumbs\//, '');
  const base = fileName.replace(/\.[a-z0-9]+$/i, '');
  return [`packages/thumbs/${base}.webp`];
}

/**
 * Builds domain-scoped storage keys for system icon full (WebP) and thumbnail (240px fit inside) images.
 */
export function buildSystemIconStorageKeys(id) {
  return {
    storageKey: `system/icons/${id}.webp`,
    thumbKey: `system/icons/thumbs/${id}.webp`,
  };
}

/**
 * Resolves thumbnail key candidates from a system icon `storage_key`.
 */
export function resolveSystemIconThumbKeys(storageKey) {
  if (!storageKey) return [];
  const clean = String(storageKey);
  if (!clean.startsWith('system/icons/')) return [];
  const fileName = clean.slice('system/icons/'.length).replace(/^thumbs\//, '');
  const base = fileName.replace(/\.[a-z0-9]+$/i, '');
  return [`system/icons/thumbs/${base}.webp`];
}

/**
 * Builds domain-scoped storage keys for voucher full (WebP) and thumbnail (240px) images.
 */
export function buildVoucherStorageKeys(id) {
  return {
    storageKey: `marketing/vouchers/${id}.webp`,
    thumbKey: `marketing/vouchers/thumbs/${id}.webp`,
  };
}

/**
 * Resolves thumbnail key candidates from a voucher image `storage_key`.
 */
export function resolveVoucherThumbKeys(storageKey) {
  if (!storageKey) return [];
  const clean = String(storageKey);
  if (!clean.startsWith('marketing/vouchers/')) return [];
  const fileName = clean.slice('marketing/vouchers/'.length).replace(/^thumbs\//, '');
  const base = fileName.replace(/\.[a-z0-9]+$/i, '');
  return [`marketing/vouchers/thumbs/${base}.webp`];
}

/**
 * Resolves any known secondary thumbnail key candidates for an image `storage_key`.
 */
export function resolveThumbKeys(storageKey) {
  if (!storageKey) return [];
  const clean = String(storageKey);
  if (clean.startsWith('packages/')) {
    return resolvePackageThumbKeys(clean);
  }
  if (clean.startsWith('system/icons/')) {
    return resolveSystemIconThumbKeys(clean);
  }
  if (clean.startsWith('marketing/vouchers/')) {
    return resolveVoucherThumbKeys(clean);
  }
  return resolveAvatarThumbKeys(clean);
}

/**
 * Builds a domain-scoped storage key for media uploads mapped by `purpose`.
 */
export function buildMediaStorageKey(purpose, id, extension) {
  const folder = MEDIA_PURPOSE_FOLDERS[purpose] || 'misc';
  const ext = String(extension || 'webp').replace(/^\./, '').toLowerCase();
  return `${folder}/${id}.${ext === 'jpeg' ? 'jpg' : ext}`;
}

/**
 * Builds a storage key under `library/` for Image Server assets (`original`, `thumbnails`, `variants`).
 */
export function buildLibraryStorageKey(kind, id, extension) {
  const ext = String(extension || 'webp').replace(/^\./, '').toLowerCase();
  return `library/${kind}/${id}.${ext === 'jpeg' ? 'jpg' : ext}`;
}
