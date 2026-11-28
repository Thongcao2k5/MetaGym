import assert from 'node:assert/strict';
import test from 'node:test';

import { createDomEnvironment, flush, jsonResponse } from './helpers/dom-harness.js';
import { setCurrentUser, setToken } from '../src/services/api.js';
import { renderNotificationPage } from '../src/pages/notification.js';

test('Admin Notification page renders broadcast composer, submits POST /admin/notifications/broadcast, and refreshes history', async () => {
  const calls = [];
  const broadcasts = [
    {
      id: 'b-1',
      title: 'Thông báo cũ',
      body: 'Nội dung cũ',
      audience: 'ALL',
      recipientCount: 12,
      createdAt: '2026-11-28T08:00:00Z',
    },
  ];

  const env = createDomEnvironment({ hash: '#/admin/notification', token: 'admin-token' });
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url, init = {}) => {
    const parsedUrl = new URL(url, 'http://localhost');
    calls.push({ method: init.method || 'GET', path: parsedUrl.pathname });
    if (parsedUrl.pathname === '/api/v1/admin/notifications/broadcasts') {
      return jsonResponse({ data: broadcasts });
    }
    if (parsedUrl.pathname === '/api/v1/admin/notifications/broadcast' && init.method === 'POST') {
      const payload = JSON.parse(init.body);
      const created = {
        id: 'b-2',
        ...payload,
        recipientCount: 25,
        createdAt: '2026-11-28T10:00:00Z',
      };
      broadcasts.unshift(created);
      return jsonResponse({ data: created }, 201);
    }
    return jsonResponse({ data: [] });
  };

  try {
    setToken('admin-token');
    setCurrentUser({ id: 'admin-1', role: 'ADMIN', fullName: 'Admin' });
    const root = env.root;

    await renderNotificationPage({
      root,
      shell: ({ contentHtml }) => {
        root.innerHTML = contentHtml;
      },
    });
    await flush();

    assert.ok(root.querySelector('#admin-broadcast-form'), 'Broadcast form must render');
    assert.ok(root.querySelector('#broadcast-history-list').innerHTML.includes('Thông báo cũ'));

    root.querySelector('#broadcast-title').value = 'Bảo trì 23:00';
    root.querySelector('#broadcast-body').value = 'Hệ thống bảo trì 15 phút.';
    root.querySelector('#broadcast-audience').value = 'MEMBER';

    await root.querySelector('#admin-broadcast-form').onsubmit({ preventDefault() {} });
    await flush();

    assert.ok(
      calls.some((c) => c.method === 'POST' && c.path === '/api/v1/admin/notifications/broadcast'),
      'Broadcast POST endpoint should be called',
    );
    assert.ok(root.querySelector('#broadcast-history-list').innerHTML.includes('Bảo trì 23:00'));
    assert.ok(root.querySelector('#broadcast-status-msg').textContent.includes('25'));
  } finally {
    globalThis.fetch = originalFetch;
  }
});
