import { esc } from './format.js';
import { icon } from './icons.js';
import { hasPermission, NO_PERMISSION_REASON } from '../services/permissions.js';

/**
 * Renders an action button that ALWAYS stays visible in disabled state when
 * restricted by permission or policy (never hidden).
 */
export function renderActionButton({
  iconName = '',
  iconSize = 16,
  label = '',
  variant = 'ghost',
  iconOnly = true,
  className = '',
  id = '',
  permission = '',
  disabled = false,
  disabledReason = NO_PERMISSION_REASON,
  title = '',
  attrs = '',
} = {}) {
  const permDenied = permission ? !hasPermission(permission) : false;
  const isDisabled = Boolean(disabled || permDenied);
  const resolvedTitle = isDisabled ? (disabledReason || NO_PERMISSION_REASON) : (title || label);
  const sizeCls = iconOnly ? 'btn-icon' : 'btn-sm';
  const cls = ['btn', `btn-${variant}`, sizeCls, className].filter(Boolean).join(' ');
  const idAttr = id ? ` id="${esc(id)}"` : '';
  const ariaLabel = label || resolvedTitle;
  const iconHtml = iconName ? icon(iconName, iconSize) : '';
  const textHtml = !iconOnly && label ? ` ${esc(label)}` : '';

  return `<button type="button" class="${esc(cls)}"${idAttr}${attrs ? ` ${attrs}` : ''} aria-label="${esc(ariaLabel)}" title="${esc(resolvedTitle)}"${isDisabled ? ' disabled aria-disabled="true" data-perm-disabled="1"' : ''}>${iconHtml}${textHtml}</button>`;
}
