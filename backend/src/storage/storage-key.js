const BARE_UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

const FOLDER_KEY_PATTERN =
  /^[a-z0-9_-]{2,32}\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}(\.[a-z0-9]{2,5})?$/;

/**
 * Validates that a storage key is either a legacy bare UUID or a safe `<folder>/<uuid>[.<ext>]` key.
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
