import { getCurrentUser } from './api.js';

export const NO_PERMISSION_REASON = 'Tài khoản chưa được phân quyền cho thao tác này.';

export const FRONTEND_POSITION_PERMISSIONS = Object.freeze({
  ADMIN: ['*'],
  MANAGER: [
    'dashboard:read', 'incidents:read', 'incidents:manage', 'disputes:read', 'disputes:manage',
    'refunds:read', 'refunds:manage', 'payments:read', 'payments:frontdesk', 'payments:void',
    'gym:read', 'gym:manage', 'members:read', 'members:manage', 'coaches:read', 'coaches:manage',
    'relationships:read', 'relationships:manage', 'transfers:read', 'transfers:manage',
    'plans:read', 'plans:manage', 'coach-packages:read', 'coach-packages:manage',
    'staff:read', 'staff:manage', 'equipment:manage', 'foods:manage',
    'media:read', 'media:manage', 'system:read', 'audit:read',
  ],
  RECEPTIONIST: [
    'dashboard:read', 'payments:read', 'payments:frontdesk',
    'gym:read', 'members:read', 'members:manage',
    'coaches:read', 'relationships:read', 'plans:read', 'coach-packages:read',
  ],
  COACH: ['mobile:coach'],
  TECHNICIAN: [
    'gym:read', 'equipment:manage', 'foods:manage', 'media:read', 'media:manage', 'system:read',
  ],
});

export const POSITION_LABELS = Object.freeze({
  ADMIN: 'Quản trị viên',
  MANAGER: 'Quản lý vận hành',
  RECEPTIONIST: 'Lễ tân & Thu ngân',
  COACH: 'Huấn luyện viên',
  TECHNICIAN: 'Kỹ thuật viên',
});

export function getUserPositionCode(user = getCurrentUser()) {
  if (!user) return 'ADMIN';
  if (user.role === 'ADMIN') return 'ADMIN';
  if (user.role === 'COACH') return 'COACH';
  if (user.role === 'STAFF') return user.staffPosition || 'RECEPTIONIST';
  return null;
}

export function getUserPositionLabel(user = getCurrentUser()) {
  const code = getUserPositionCode(user);
  return POSITION_LABELS[code] || 'Quản trị viên';
}

/**
 * Checks whether the current backoffice user has a given operational permission.
 * Preserves full access for mock/unscoped ADMIN sessions and filters STAFF sessions cleanly.
 */
export function hasPermission(permission, user = getCurrentUser()) {
  if (!permission) return true;
  if (!user || !user.role) return true;
  if (user.role === 'ADMIN' && !Array.isArray(user.permissions)) return true;
  if (Array.isArray(user.permissions)) {
    return user.permissions.includes('*') || user.permissions.includes(permission);
  }
  const pos = getUserPositionCode(user);
  const fallbackPerms = FRONTEND_POSITION_PERMISSIONS[pos] || [];
  return fallbackPerms.includes('*') || fallbackPerms.includes(permission);
}
