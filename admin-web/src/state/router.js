const SECTION_ALIASES = {
  'gym-plans': 'plans',
  'gym-profile': 'gym',
  'catalog-training': 'equipment',
  incidents: 'coach-incidents',
  foods: 'nutrition-foods',
  notifications: 'notification',
  design: 'design-system',
  'ui-kit': 'design-system',
  images: 'media-library',
  library: 'media-library',
  sharing: 'media-sharing',
  'api-keys': 'media-sharing',
  storage: 'media-analytics',
  analytics: 'media-analytics',
  settings: 'media-settings',
  system: 'system-info',
  nhansu: 'staff',
  'staff-positions': 'staff',
  positions: 'staff',
  voucher: 'vouchers',
  promo: 'vouchers',
  schedule: 'coach-schedule',
  calendar: 'coach-schedule',
};

export function normalizeSection(rawSection) {
  const key = String(rawSection || '').trim().toLowerCase();
  if (!key) return 'dashboard';
  return SECTION_ALIASES[key] || key;
}

export function parseHash(hash = globalThis.location?.hash || '') {
  const cleaned = String(hash || '').replace(/^#/, '');
  const [rawPath, rawQuery = ''] = cleaned.split('?');
  const pathPart = rawPath.replace(/^\/?admin\/?/, '').split('/')[0] || 'dashboard';
  const section = normalizeSection(pathPart);
  const params = new URLSearchParams(rawQuery);
  return { section, rawSection: pathPart, params, raw: hash || '#/admin/dashboard' };
}

export function buildHash(section, params = {}) {
  const search = params instanceof URLSearchParams ? new URLSearchParams(params) : new URLSearchParams();
  if (!(params instanceof URLSearchParams)) {
    for (const [key, value] of Object.entries(params || {})) {
      if (value === undefined || value === null || value === '' || value === 'ALL') continue;
      search.set(key, String(value));
    }
  }
  const qs = search.toString();
  const cleanSection = normalizeSection(section);
  return `#/admin/${cleanSection}${qs ? `?${qs}` : ''}`;
}

export function navigate(section, params = {}, { replace = false } = {}) {
  const target = buildHash(section, params);
  if (!globalThis.location) return target;
  if (replace && globalThis.history?.replaceState) {
    globalThis.history.replaceState(null, '', target);
    return target;
  }
  if (globalThis.location.hash !== target) {
    globalThis.location.hash = target;
  }
  return target;
}

export function updateQuery(patch = {}, { replace = true } = {}) {
  const current = parseHash();
  const next = new URLSearchParams(current.params);
  for (const [key, value] of Object.entries(patch)) {
    if (value === undefined || value === null || value === '' || value === 'ALL') {
      next.delete(key);
    } else {
      next.set(key, String(value));
    }
  }
  const target = buildHash(current.rawSection || current.section, next);
  if (replace && globalThis.history?.replaceState) {
    globalThis.history.replaceState(null, '', target);
  } else if (globalThis.location) {
    globalThis.location.hash = target;
  }
  return target;
}
