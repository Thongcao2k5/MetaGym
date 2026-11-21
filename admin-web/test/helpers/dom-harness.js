const VOID_TAGS = new Set([
  'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'param', 'source', 'track', 'wbr',
]);

function decodeEntities(str) {
  return String(str)
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, '&');
}

function escapeHtml(str) {
  return String(str ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[c]);
}

function kebabToCamel(str) {
  return str.replace(/-([a-z0-9])/gi, (_, ch) => ch.toUpperCase());
}

function camelToKebab(str) {
  return str.replace(/[A-Z]/g, (ch) => `-${ch.toLowerCase()}`);
}

class TextNode {
  constructor(text) {
    this.nodeType = 3;
    this._text = String(text ?? '');
    this.parentElement = null;
  }

  get textContent() { return this._text; }
  set textContent(v) { this._text = String(v ?? ''); }
  toHTML() { return escapeHtml(this._text); }
}

export class MiniElement {
  constructor(tagName, ownerDocument) {
    this.nodeType = 1;
    this.tagName = String(tagName || 'div').toUpperCase();
    this.ownerDocument = ownerDocument;
    this.parentElement = null;
    this.childNodes = [];
    this.attributes = new Map();
    this.listeners = new Map();
    this.style = {};
    this._value = undefined;
    this._checked = undefined;
    this.onclick = null;
    this.onsubmit = null;
    this.oninput = null;
    this.onchange = null;
    this.onfocus = null;
    this.onblur = null;

    this.classList = {
      add: (...names) => {
        const set = new Set(this.className.split(/\s+/).filter(Boolean));
        names.forEach((n) => n && set.add(n));
        this.className = [...set].join(' ');
      },
      remove: (...names) => {
        const set = new Set(this.className.split(/\s+/).filter(Boolean));
        names.forEach((n) => set.delete(n));
        this.className = [...set].join(' ');
      },
      toggle: (name, force) => {
        const has = this.classList.contains(name);
        const next = force === undefined ? !has : Boolean(force);
        if (next) this.classList.add(name);
        else this.classList.remove(name);
        return next;
      },
      contains: (name) => this.className.split(/\s+/).filter(Boolean).includes(name),
    };

    this.dataset = new Proxy({}, {
      get: (_t, prop) => {
        if (typeof prop !== 'string') return undefined;
        return this.attributes.get(`data-${camelToKebab(prop)}`);
      },
      set: (_t, prop, val) => {
        if (typeof prop === 'string') {
          this.attributes.set(`data-${camelToKebab(prop)}`, String(val));
        }
        return true;
      },
    });
  }

  get children() {
    return this.childNodes.filter((n) => n.nodeType === 1);
  }

  get id() { return this.attributes.get('id') || ''; }
  set id(v) { this.setAttribute('id', v); }

  get className() { return this.attributes.get('class') || ''; }
  set className(v) { this.setAttribute('class', v); }

  get name() { return this.attributes.get('name') || ''; }
  set name(v) { this.setAttribute('name', v); }

  get type() { return this.attributes.get('type') || ''; }
  set type(v) { this.setAttribute('type', v); }

  get hidden() { return this.attributes.has('hidden'); }
  set hidden(v) {
    if (v) this.setAttribute('hidden', '');
    else this.removeAttribute('hidden');
  }

  get disabled() { return this.attributes.has('disabled'); }
  set disabled(v) {
    if (v) this.setAttribute('disabled', '');
    else this.removeAttribute('disabled');
  }

  get checked() {
    if (this._checked !== undefined) return this._checked;
    return this.attributes.has('checked');
  }
  set checked(v) {
    this._checked = Boolean(v);
    if (this._checked) this.setAttribute('checked', '');
    else this.removeAttribute('checked');
  }

  get value() {
    if (this._value !== undefined) return this._value;
    if (this.tagName === 'TEXTAREA') return this.textContent;
    if (this.tagName === 'SELECT') {
      const options = this.querySelectorAll('option');
      const selected = options.find((opt) => opt.attributes.has('selected')) || options[0];
      return selected ? (selected.attributes.get('value') ?? selected.textContent) : '';
    }
    return this.attributes.get('value') ?? '';
  }

  set value(v) {
    const str = String(v ?? '');
    this._value = str;
    if (this.tagName === 'TEXTAREA') {
      this.childNodes = [new TextNode(str)];
    } else if (this.tagName === 'SELECT') {
      for (const opt of this.querySelectorAll('option')) {
        const optVal = opt.attributes.get('value') ?? opt.textContent;
        if (optVal === str) opt.setAttribute('selected', '');
        else opt.removeAttribute('selected');
      }
    } else {
      this.attributes.set('value', str);
    }
  }

  setAttribute(name, value = '') {
    this.attributes.set(String(name).toLowerCase(), String(value));
  }

  getAttribute(name) {
    const key = String(name).toLowerCase();
    return this.attributes.has(key) ? this.attributes.get(key) : null;
  }

  removeAttribute(name) {
    this.attributes.delete(String(name).toLowerCase());
  }

  hasAttribute(name) {
    return this.attributes.has(String(name).toLowerCase());
  }

  appendChild(node) {
    if (!node) return node;
    node.parentElement = this;
    this.childNodes.push(node);
    return node;
  }

  remove() {
    if (!this.parentElement) return;
    const idx = this.parentElement.childNodes.indexOf(this);
    if (idx >= 0) this.parentElement.childNodes.splice(idx, 1);
    this.parentElement = null;
  }

  get textContent() {
    return this.childNodes.map((n) => n.textContent).join('');
  }

  set textContent(val) {
    this.childNodes = [new TextNode(val)];
  }

  get innerHTML() {
    return this.childNodes.map((n) => n.toHTML()).join('');
  }

  set innerHTML(html) {
    this.childNodes = [];
    parseHtmlInto(String(html ?? ''), this, this.ownerDocument);
  }

  toHTML() {
    const tag = this.tagName.toLowerCase();
    const attrs = [...this.attributes.entries()]
      .map(([k, v]) => (v === '' ? ` ${k}` : ` ${k}="${escapeHtml(v)}"`))
      .join('');
    if (VOID_TAGS.has(tag)) return `<${tag}${attrs}>`;
    return `<${tag}${attrs}>${this.innerHTML}</${tag}>`;
  }

  focus() {
    if (this.ownerDocument) this.ownerDocument.activeElement = this;
    this.dispatchEvent({ type: 'focus', target: this, currentTarget: this });
  }

  addEventListener(type, fn) {
    if (!this.listeners.has(type)) this.listeners.set(type, new Set());
    this.listeners.get(type).add(fn);
  }

  removeEventListener(type, fn) {
    this.listeners.get(type)?.delete(fn);
  }

  dispatchEvent(event) {
    const ev = {
      type: event?.type || '',
      target: event?.target || this,
      currentTarget: this,
      key: event?.key,
      defaultPrevented: false,
      preventDefault() { this.defaultPrevented = true; },
      stopPropagation() {},
      ...event,
    };
    const prop = `on${ev.type}`;
    if (typeof this[prop] === 'function') {
      this[prop](ev);
    }
    const set = this.listeners.get(ev.type);
    if (set) {
      for (const fn of [...set]) fn(ev);
    }
    return !ev.defaultPrevented;
  }

  click() {
    if (this.disabled) return;
    this.dispatchEvent({ type: 'click', target: this, currentTarget: this });
  }

  matches(selector) {
    return matchesSelectorList(this, selector);
  }

  closest(selector) {
    let cur = this;
    while (cur && cur.nodeType === 1) {
      if (cur.matches(selector)) return cur;
      cur = cur.parentElement;
    }
    return null;
  }

  querySelectorAll(selector) {
    const out = [];
    const walk = (node) => {
      for (const child of node.childNodes) {
        if (child.nodeType === 1) {
          if (matchesSelectorList(child, selector)) out.push(child);
          walk(child);
        }
      }
    };
    walk(this);
    return out;
  }

  querySelector(selector) {
    return this.querySelectorAll(selector)[0] ?? null;
  }
}

function matchesSimple(el, simple) {
  let rest = simple.trim();
  if (!rest) return false;

  // Handle :not(...) clauses
  const notMatches = [];
  rest = rest.replace(/:not\(([^)]+)\)/g, (_m, inner) => {
    notMatches.push(inner.trim());
    return '';
  });

  // Handle :disabled / :checked
  if (rest.includes(':disabled')) {
    if (!el.disabled) return false;
    rest = rest.replace(/:disabled/g, '');
  }
  if (rest.includes(':checked')) {
    if (!el.checked) return false;
    rest = rest.replace(/:checked/g, '');
  }

  // Attribute selectors
  const attrRegex = /\[([^\]]+)\]/g;
  let m;
  while ((m = attrRegex.exec(rest)) !== null) {
    const body = m[1];
    const eqIdx = body.indexOf('=');
    if (eqIdx === -1) {
      if (!el.hasAttribute(body.trim())) return false;
    } else {
      const key = body.slice(0, eqIdx).trim();
      const expected = body.slice(eqIdx + 1).trim().replace(/^["']|["']$/g, '');
      if (el.getAttribute(key) !== expected) return false;
    }
  }
  rest = rest.replace(attrRegex, '');

  // IDs and classes and tag
  const tokens = rest.match(/(?:#[^.#\s]+|\.[^.#\s]+|[^.#\s]+)/g) || [];
  for (const tok of tokens) {
    if (tok.startsWith('#')) {
      if (el.id !== tok.slice(1)) return false;
    } else if (tok.startsWith('.')) {
      if (!el.classList.contains(tok.slice(1))) return false;
    } else if (tok !== '*') {
      if (el.tagName !== tok.toUpperCase()) return false;
    }
  }

  for (const inner of notMatches) {
    if (matchesSimple(el, inner)) return false;
  }
  return true;
}

function matchesComplex(el, selector) {
  const parts = selector.trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return false;
  if (!matchesSimple(el, parts[parts.length - 1])) return false;
  let cur = el.parentElement;
  for (let i = parts.length - 2; i >= 0; i -= 1) {
    const part = parts[i];
    if (part === '>') {
      i -= 1;
      if (!cur || !matchesSimple(cur, parts[i])) return false;
      cur = cur.parentElement;
    } else {
      let found = false;
      while (cur && cur.nodeType === 1) {
        if (matchesSimple(cur, part)) {
          found = true;
          cur = cur.parentElement;
          break;
        }
        cur = cur.parentElement;
      }
      if (!found) return false;
    }
  }
  return true;
}

function matchesSelectorList(el, selector) {
  return String(selector || '')
    .split(',')
    .some((part) => matchesComplex(el, part));
}

function parseAttributes(raw) {
  const attrs = [];
  const re = /([a-zA-Z0-9_:@-]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/g;
  let match;
  while ((match = re.exec(raw)) !== null) {
    const name = match[1];
    const val = match[2] ?? match[3] ?? match[4] ?? '';
    attrs.push([name, decodeEntities(val)]);
  }
  return attrs;
}

function parseHtmlInto(html, rootEl, ownerDocument) {
  const stack = [rootEl];
  const tokenRe = /<!--[\s\S]*?-->|<\/([a-zA-Z0-9-]+)\s*>|<([a-zA-Z0-9-]+)((?:\s+[^<>]*?)?)\s*(\/?)>|([^<]+)/g;
  let match;
  while ((match = tokenRe.exec(html)) !== null) {
    const [full, closeTag, openTag, rawAttrs, selfClose, text] = match;
    const parent = stack[stack.length - 1];
    if (full.startsWith('<!--')) continue;
    if (closeTag) {
      const target = closeTag.toUpperCase();
      for (let i = stack.length - 1; i >= 1; i -= 1) {
        if (stack[i].tagName === target) {
          stack.length = i;
          break;
        }
      }
    } else if (openTag) {
      const el = new MiniElement(openTag, ownerDocument);
      if (rawAttrs) {
        for (const [k, v] of parseAttributes(rawAttrs)) {
          el.setAttribute(k, v);
        }
      }
      parent.appendChild(el);
      if (!selfClose && !VOID_TAGS.has(openTag.toLowerCase())) {
        stack.push(el);
      }
    } else if (text) {
      parent.appendChild(new TextNode(decodeEntities(text)));
    }
  }
}

export function createDomEnvironment({ hash = '#/admin/dashboard', token = 'test-admin-token' } = {}) {
  const store = new Map();
  if (token) store.set('metagym_admin_token', token);

  const docListeners = new Map();
  const winListeners = new Map();

  const document = {
    activeElement: null,
    createElement(tag) { return new MiniElement(tag, document); },
    addEventListener(type, fn) {
      if (!docListeners.has(type)) docListeners.set(type, new Set());
      docListeners.get(type).add(fn);
    },
    removeEventListener(type, fn) { docListeners.get(type)?.delete(fn); },
    dispatchEvent(event) {
      for (const fn of [...(docListeners.get(event.type) || [])]) fn(event);
    },
    getElementById(id) { return document.body.querySelector(`#${id}`); },
    querySelector(sel) { return document.body.querySelector(sel); },
    querySelectorAll(sel) { return document.body.querySelectorAll(sel); },
  };
  document.body = new MiniElement('body', document);
  document.body.innerHTML = `
    <div id="app"></div>
    <div class="meta-overlay" id="meta-modal-overlay" hidden><div class="meta-modal-dialog" id="meta-modal-dialog"></div></div>
    <div class="meta-drawer-overlay" id="meta-drawer-overlay" hidden><div class="meta-drawer-panel" id="meta-drawer-panel"></div></div>
    <div class="meta-toast-region" id="meta-toast-region"></div>
  `;

  const location = { hash };
  const history = {
    replaceState(_s, _t, url) {
      if (typeof url === 'string') location.hash = url.startsWith('#') ? url : `#${url}`;
    },
  };
  const sessionStorage = {
    getItem: (k) => (store.has(k) ? store.get(k) : null),
    setItem: (k, v) => { store.set(k, String(v)); },
    removeItem: (k) => { store.delete(k); },
    clear: () => store.clear(),
  };
  const window = {
    location,
    history,
    printCalled: 0,
    print() { window.printCalled += 1; },
    addEventListener(type, fn) {
      if (!winListeners.has(type)) winListeners.set(type, new Set());
      winListeners.get(type).add(fn);
    },
    dispatchEvent(event) {
      for (const fn of [...(winListeners.get(event.type) || [])]) fn(event);
    },
  };

  // Install globals for ESM module execution
  globalThis.document = document;
  globalThis.window = window;
  globalThis.location = location;
  globalThis.history = history;
  globalThis.sessionStorage = sessionStorage;

  return {
    document,
    window,
    location,
    history,
    sessionStorage,
    root: document.getElementById('app'),
    modalOverlay: document.getElementById('meta-modal-overlay'),
    modalDialog: document.getElementById('meta-modal-dialog'),
    drawerOverlay: document.getElementById('meta-drawer-overlay'),
    drawerPanel: document.getElementById('meta-drawer-panel'),
    toastRegion: document.getElementById('meta-toast-region'),
  };
}

export async function flush(turns = 12) {
  for (let i = 0; i < turns; i += 1) {
    await new Promise((resolve) => setImmediate(resolve));
  }
}

export function jsonResponse(data, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => data,
  };
}
