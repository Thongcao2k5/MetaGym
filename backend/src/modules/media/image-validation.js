import dns from 'node:dns/promises';
import net from 'node:net';

const BOT_UA_PATTERN =
  /(bot|crawl|spider|slurp|curl|wget|python-requests|postman|insomnia|headless|lighthouse|bingpreview|facebookexternalhit|whatsapp)/i;

/**
 * Detects real image format using file magic bytes (ignores filename extensions).
 * Supports JPEG, PNG, GIF, WebP, AVIF, and SVG.
 */
export function detectImageType(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 4) return null;

  // JPEG: FF D8 FF
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return { mimeType: 'image/jpeg', extension: 'jpg', format: 'jpeg' };
  }

  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (
    buffer.length >= 8 &&
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47 &&
    buffer[4] === 0x0d &&
    buffer[5] === 0x0a &&
    buffer[6] === 0x1a &&
    buffer[7] === 0x0a
  ) {
    return { mimeType: 'image/png', extension: 'png', format: 'png' };
  }

  // GIF: GIF87a / GIF89a
  if (
    buffer.length >= 6 &&
    (buffer.subarray(0, 6).toString('ascii') === 'GIF87a' ||
      buffer.subarray(0, 6).toString('ascii') === 'GIF89a')
  ) {
    return { mimeType: 'image/gif', extension: 'gif', format: 'gif' };
  }

  // WebP: RIFF....WEBP
  if (
    buffer.length >= 12 &&
    buffer.subarray(0, 4).toString('ascii') === 'RIFF' &&
    buffer.subarray(8, 12).toString('ascii') === 'WEBP'
  ) {
    return { mimeType: 'image/webp', extension: 'webp', format: 'webp' };
  }

  // AVIF: ISO BMFF ....ftypavif or ....ftypavis
  if (buffer.length >= 12 && buffer.subarray(4, 8).toString('ascii') === 'ftyp') {
    const brand = buffer.subarray(8, 12).toString('ascii');
    if (brand === 'avif' || brand === 'avis') {
      return { mimeType: 'image/avif', extension: 'avif', format: 'avif' };
    }
  }

  // SVG: UTF-8 text starting with <svg or <?xml ... <svg
  const head = buffer.subarray(0, Math.min(buffer.length, 4096)).toString('utf8').replace(/^\uFEFF/, '').trimStart();
  if (/^(?:<\?xml[\s\S]*?\?>\s*)?(?:<!--[\s\S]*?-->\s*)*<svg\b/i.test(head)) {
    return { mimeType: 'image/svg+xml', extension: 'svg', format: 'svg' };
  }

  return null;
}

/**
 * Sanitizes an SVG buffer by stripping active scripts, dangerous tags, event handlers,
 * external entities/DOCTYPE, and dangerous URI schemes (`javascript:`, `vbscript:`).
 */
export function sanitizeSvg(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length === 0) {
    throw new Error('UNSAFE_SVG');
  }
  let svg = buffer.toString('utf8').replace(/^\uFEFF/, '').trim();
  if (!/<svg\b[\s\S]*<\/svg>\s*$/i.test(svg)) {
    throw new Error('UNSAFE_SVG');
  }

  svg = svg
    .replace(/<!DOCTYPE[\s\S]*?>/gi, '')
    .replace(/<!ENTITY[\s\S]*?>/gi, '')
    .replace(/<\?xml-stylesheet[\s\S]*?\?>/gi, '')
    .replace(/<\s*(script|foreignObject|iframe|object|embed|applet)\b[\s\S]*?<\s*\/\s*\1\s*>/gi, '')
    .replace(/<\s*(script|foreignObject|iframe|object|embed|applet)\b[^>]*\/\s*>/gi, '')
    .replace(/\s+on[a-z]+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)/gi, '')
    .replace(/(href|xlink:href|src)\s*=\s*(?:"\s*(?:javascript|vbscript|data:text\/html)[^"]*"|'\s*(?:javascript|vbscript|data:text\/html)[^']*')/gi, '$1="#"')
    .replace(/<\s*use\b[^>]*?(?:href|xlink:href)\s*=\s*(?:"https?:\/\/[^"]*"|'https?:\/\/[^']*')[^>]*\/?>/gi, '')
    .replace(/url\(\s*['"]?\s*javascript:[^)]*\)/gi, 'none');

  if (!/<svg\b/i.test(svg)) {
    throw new Error('UNSAFE_SVG');
  }

  return Buffer.from(svg, 'utf8');
}

export function isPrivateIpAddress(ip) {
  if (!net.isIP(ip)) return true;
  if (net.isIPv4(ip)) {
    const parts = ip.split('.').map(Number);
    const [a, b] = parts;
    if (a === 0 || a === 10 || a === 127) return true;
    if (a === 169 && b === 254) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
    if (a === 192 && b === 168) return true;
    if (a === 100 && b >= 64 && b <= 127) return true;
    return false;
  }
  const normalized = ip.toLowerCase();
  if (normalized === '::1' || normalized === '::') return true;
  if (normalized.startsWith('fe80:') || normalized.startsWith('fc') || normalized.startsWith('fd')) {
    return true;
  }
  if (normalized.startsWith('::ffff:')) {
    return isPrivateIpAddress(normalized.slice(7));
  }
  return false;
}

/**
 * Validates that a remote import URL is HTTP/HTTPS and does not target localhost/private networks (SSRF guard).
 */
export async function assertSafeRemoteUrl(rawUrl, { lookup = dns.lookup } = {}) {
  let parsed;
  try {
    parsed = new URL(String(rawUrl || '').trim());
  } catch {
    throw new Error('INVALID_URL');
  }
  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    throw new Error('UNSAFE_URL_PROTOCOL');
  }
  const hostname = parsed.hostname.replace(/^\[|\]$/g, '').toLowerCase();
  if (
    !hostname ||
    hostname === 'localhost' ||
    hostname.endsWith('.local') ||
    hostname.endsWith('.internal')
  ) {
    throw new Error('UNSAFE_URL_HOST');
  }
  if (net.isIP(hostname)) {
    if (isPrivateIpAddress(hostname)) throw new Error('UNSAFE_URL_HOST');
    return parsed;
  }
  const records = await lookup(hostname, { all: true }).catch(() => []);
  if (!records.length || records.some((r) => isPrivateIpAddress(r.address))) {
    throw new Error('UNSAFE_URL_HOST');
  }
  return parsed;
}

export function isBotUserAgent(userAgent = '') {
  return BOT_UA_PATTERN.test(String(userAgent || ''));
}

export function slugify(value, fallback = 'item') {
  const clean = String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80);
  return clean || fallback;
}
