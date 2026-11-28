import assert from 'node:assert/strict';
import test from 'node:test';

import { createDomEnvironment, flush, jsonResponse } from './helpers/dom-harness.js';
import { setCurrentUser, setToken } from '../src/services/api.js';
import { renderShell } from '../src/components/layout.js';
import { renderMediaLibraryPage } from '../src/pages/media-library.js';
import { renderMediaSharingPage } from '../src/pages/media-sharing.js';
import { renderMediaAnalyticsPage } from '../src/pages/media-analytics.js';
import { renderMediaSettingsPage } from '../src/pages/media-settings.js';

function makeShell(root) {
  return (opts) => renderShell({
    root,
    user: { id: 'adm-1', role: 'ADMIN', fullName: 'Meta Admin', email: 'admin@metagym.vn' },
    ...opts,
  });
}

test('Image Library renders KPIs, images, Detail Drawer, and Image Editor modal', async () => {
  const env = createDomEnvironment({ hash: '#/admin/media-library', token: 'tok' });
  setToken('tok');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Meta Admin', email: 'admin@metagym.vn' });

  const sampleImage = {
    id: '22222222-2222-4222-8222-222222222222',
    filename: 'gym-hero.webp',
    originalFilename: 'gym-hero.png',
    extension: 'webp',
    mimeType: 'image/webp',
    sizeBytes: 245000,
    width: 1920,
    height: 1080,
    visibility: 'public',
    viewCount: 18,
    downloadCount: 4,
    sha256Hash: 'a'.repeat(64),
    exifData: { format: 'webp' },
    originalUrl: '/api/v1/images/22222222-2222-4222-8222-222222222222/file',
    thumbnailUrl: '/api/v1/images/22222222-2222-4222-8222-222222222222/thumbnail',
    downloadUrl: '/api/v1/images/22222222-2222-4222-8222-222222222222/download',
    variants: [],
    tags: [{ id: 't-1', name: 'banner', slug: 'banner', color: '#FF5E36' }],
    createdAt: '2026-11-28T02:00:00.000Z',
  };

  let transformBody = null;
  globalThis.fetch = async (url, options = {}) => {
    const path = new URL(url, 'http://localhost').pathname;
    if (path === '/api/v1/stats') {
      return jsonResponse({ success: true, data: { totalImages: 1, totalStorageBytes: 245000, uploadsToday: 1, totalViews: 18 } });
    }
    if (path === '/api/v1/folders') return jsonResponse({ success: true, data: { items: [], tree: [] } });
    if (path === '/api/v1/albums') return jsonResponse({ success: true, data: [] });
    if (path === '/api/v1/tags') return jsonResponse({ success: true, data: [] });
    if (path === '/api/v1/images') {
      return jsonResponse({ success: true, data: [sampleImage], meta: { page: 1, limit: 12, total: 1, totalPages: 1 } });
    }
    if (path === `/api/v1/images/${sampleImage.id}` && (!options.method || options.method === 'GET')) {
      return jsonResponse({ success: true, data: sampleImage });
    }
    if (path === `/api/v1/images/${sampleImage.id}/transform` && options.method === 'POST') {
      transformBody = JSON.parse(options.body);
      return jsonResponse({
        success: true,
        data: {
          id: 'var-1',
          variantType: 'edited',
          label: 'Banner 80%',
          width: 1280,
          height: 720,
          sizeBytes: 98000,
          url: `/api/v1/images/${sampleImage.id}/variants/var-1/file`,
        },
      }, 201);
    }
    throw new Error(`Unexpected ${path}`);
  };

  await renderMediaLibraryPage({ root: env.root, params: new URLSearchParams(), shell: makeShell(env.root) });

  assert.equal(env.root.innerHTML.includes('gym-hero.webp'), true);
  assert.equal(env.root.innerHTML.includes('239 KB'), true);
  assert.ok(env.root.querySelector('#media-select-all'));
  assert.equal(env.root.querySelector('#mf-view-list').classList.contains('btn-primary'), true);

  env.root.querySelector('.media-act-detail').click();
  await flush();
  assert.equal(env.drawerOverlay.hidden, false);
  assert.equal(env.drawerPanel.innerHTML.includes(sampleImage.sha256Hash), true);

  env.root.querySelector('.media-act-edit').click();
  assert.equal(env.modalOverlay.hidden, false);
  env.modalDialog.querySelector('#ed-label').value = 'Banner 80%';
  env.modalDialog.querySelector('#image-editor-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(transformBody.label, 'Banner 80%');
  assert.equal(transformBody.saveAsVariant, true);
});

test('Media Sharing creates API key and reveals one-time key banner', async () => {
  const env = createDomEnvironment({ hash: '#/admin/media-sharing?tab=api-keys', token: 'tok' });
  setToken('tok');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Meta Admin', email: 'admin@metagym.vn' });

  let createdPayload = null;
  globalThis.fetch = async (url, options = {}) => {
    const path = new URL(url, 'http://localhost').pathname;
    if (path === '/api/v1/api-keys' && (!options.method || options.method === 'GET')) {
      return jsonResponse({ success: true, data: [] });
    }
    if (path === '/api/v1/api-keys' && options.method === 'POST') {
      createdPayload = JSON.parse(options.body);
      return jsonResponse({
        success: true,
        data: {
          id: 'ak-1',
          name: createdPayload.name,
          keyPrefix: 'mg_live_1234',
          apiKey: 'mg_live_1234567890secret',
          scopes: createdPayload.scopes,
          rateLimitPerMinute: createdPayload.rateLimitPerMinute,
        },
      }, 201);
    }
    throw new Error(`Unexpected ${path}`);
  };

  await renderMediaSharingPage({
    root: env.root,
    params: new URLSearchParams({ tab: 'api-keys' }),
    shell: makeShell(env.root),
  });

  env.root.querySelector('#btn-create-apikey').click();
  assert.equal(env.modalOverlay.hidden, false);
  env.modalDialog.querySelector('#ak-name').value = 'Flutter App';
  env.modalDialog.querySelector('#create-apikey-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(createdPayload.name, 'Flutter App');
  assert.equal(env.root.innerHTML.includes('mg_live_1234567890secret'), true);
});

test('Media Analytics & Settings render real stats and persist PATCH /admin/settings', async () => {
  const env = createDomEnvironment({ hash: '#/admin/media-analytics', token: 'tok' });
  setToken('tok');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Meta Admin', email: 'admin@metagym.vn' });

  let savedSettings = null;
  globalThis.fetch = async (url, options = {}) => {
    const path = new URL(url, 'http://localhost').pathname;
    if (path === '/api/v1/stats') {
      return jsonResponse({ success: true, data: { uploadsByDay: [{ day: '2026-11-28', uploads: 4 }] } });
    }
    if (path === '/api/v1/analytics/overview') {
      return jsonResponse({
        success: true,
        data: {
          realViews: 42,
          botViews: 5,
          totalBandwidthBytes: 1048576,
          viewsByDay: [{ day: '2026-11-28', realViews: 42, botViews: 5 }],
          topViewed: [],
          topDownloaded: [],
          apiRequests: { totalRequests: 12, status2xx: 10, status3xx: 0, status4xx: 2, status5xx: 0, avgResponseMs: 18 },
        },
      });
    }
    if (path === '/api/v1/admin/settings' && (!options.method || options.method === 'GET')) {
      return jsonResponse({
        success: true,
        data: {
          site_branding: { siteName: 'Meta Gym Image Server', logoUrl: '', faviconUrl: '' },
          upload_limits: { maxFileSizeMb: 10, maxFilesPerUpload: 20, allowedFormats: ['jpeg', 'png', 'webp'], defaultVisibility: 'private', allowUrlImport: true },
          image_processing: { thumbnailSize: 400, autoWebp: true, autoAvif: false, defaultQuality: 82, stripGpsExif: false },
          smtp: { enabled: false, host: '', port: 587, secure: false, fromEmail: '' },
          rate_limits: { publicApiPerMinute: 60, uploadPerMinute: 30 },
          maintenance_mode: { enabled: false, message: 'Bảo trì' },
        },
      });
    }
    if (path === '/api/v1/admin/settings' && options.method === 'PATCH') {
      savedSettings = JSON.parse(options.body);
      return jsonResponse({ success: true, data: savedSettings });
    }
    throw new Error(`Unexpected ${path}`);
  };

  await renderMediaAnalyticsPage({
    root: env.root,
    params: new URLSearchParams(),
    shell: makeShell(env.root),
    ChartCtor: class { destroy() {} },
  });
  assert.equal(env.root.innerHTML.includes('42'), true);
  assert.equal(env.root.innerHTML.includes('1.0 MB'), true);

  await renderMediaSettingsPage({
    root: env.root,
    params: new URLSearchParams(),
    shell: makeShell(env.root),
  });
  env.root.querySelector('#set-site-name').value = 'Meta Gym Media Cloud';
  env.root.querySelector('#media-settings-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(savedSettings.site_branding.siteName, 'Meta Gym Media Cloud');
});

test('Image Library Kho Supabase tab loads live Supabase bucket summary and syncs cleanly', async () => {
  const env = createDomEnvironment({ hash: '#/admin/media-library?tab=supabase', token: 'tok' });
  setToken('tok');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Meta Admin', email: 'admin@metagym.vn' });

  let syncedCalled = false;
  globalThis.fetch = async (url, options = {}) => {
    const path = new URL(url, 'http://localhost').pathname;
    if (path === '/api/v1/admin/storage/supabase-objects') {
      return jsonResponse({
        success: true,
        data: {
          bucket: 'meta-gym-media',
          totalObjects: 2,
          totalBytes: 18500,
          syncedCount: 1,
          orphanCount: 0,
          folders: [
            { folder: 'users/avatars', fileCount: 1, totalBytes: 16500 },
            { folder: 'users/avatars/thumbs', fileCount: 1, totalBytes: 2000 },
          ],
          objects: [
            {
              key: 'users/avatars/a.webp',
              name: 'a.webp',
              folder: 'users/avatars',
              domainLabel: 'Ảnh đại diện',
              sizeBytes: 16500,
              mimeType: 'image/webp',
              syncStatus: 'SYNCED',
              ownerName: 'Nguyễn Trung Hậu',
              imageId: 'img-1',
              thumbnailUrl: '/api/v1/images/img-1/thumbnail',
              createdAt: '2026-11-28T06:50:00.000Z',
            },
          ],
        },
      });
    }
    if (path === '/api/v1/admin/storage/sync-supabase' && options.method === 'POST') {
      syncedCalled = true;
      return jsonResponse({
        success: true,
        data: { bucket: 'meta-gym-media', syncedCount: 1, totalStorageObjects: 2, totalStorageBytes: 18500 },
      });
    }
    throw new Error(`Unexpected ${path}`);
  };

  await renderMediaLibraryPage({
    root: env.root,
    params: new URLSearchParams({ tab: 'supabase' }),
    shell: makeShell(env.root),
  });

  assert.equal(env.root.innerHTML.includes('meta-gym-media'), true);
  assert.equal(env.root.innerHTML.includes('users/avatars/a.webp'), true);
  assert.equal(env.root.innerHTML.includes('Nguyễn Trung Hậu'), true);
  assert.equal(env.root.innerHTML.includes('Đã đồng bộ'), true);

  env.root.querySelector('#sb-sync-now').click();
  await flush();
  assert.equal(syncedCalled, true);
});
