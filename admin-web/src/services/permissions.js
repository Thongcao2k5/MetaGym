import { getCurrentUser } from './api.js';

export const NO_PERMISSION_REASON = 'Tài khoản chưa được phân quyền cho thao tác này.';

/**
 * Checks whether the current Admin user has a given operational permission.
 * If `user.permissions` is not explicitly scoped, ADMIN defaults to full access.
 */
export function hasPermission(permission, user = getCurrentUser()) {
  if (!permission) return true;
  if (!user) return true;
  if (Array.isArray(user.permissions)) {
    return user.permissions.includes('*') || user.permissions.includes(permission);
  }
  return user.role === 'ADMIN';
}
