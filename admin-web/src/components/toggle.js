import { esc } from './format.js';

/**
 * Reusable accessible Toggle Switch for boolean inputs and filters.
 * Uses native <input type="checkbox" role="switch"> so .checked and onchange work seamlessly.
 */
export function renderToggle({
  id = '',
  name = '',
  label = '',
  checked = false,
  disabled = false,
  className = '',
  attrs = '',
} = {}) {
  const idAttr = id ? ` id="${esc(id)}"` : '';
  const nameAttr = name ? ` name="${esc(name)}"` : '';
  const forAttr = id ? ` for="${esc(id)}"` : '';
  const cls = ['meta-switch', className].filter(Boolean).join(' ');

  return `<label class="${esc(cls)}"${forAttr}>
    <input type="checkbox" role="switch" class="meta-switch-input"${idAttr}${nameAttr}${checked ? ' checked' : ''}${disabled ? ' disabled' : ''}${attrs ? ` ${attrs}` : ''} />
    <span class="meta-switch-track" aria-hidden="true"><span class="meta-switch-thumb"></span></span>
    ${label ? `<span class="meta-switch-label">${esc(label)}</span>` : ''}
  </label>`;
}
