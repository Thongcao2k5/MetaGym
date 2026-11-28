import assert from 'node:assert/strict';
import test from 'node:test';

import { renderEquipmentPage } from '../src/pages/equipment.js';
import { setCurrentUser, setToken } from '../src/services/api.js';
import { createDomEnvironment, flush } from './helpers/dom-harness.js';

function jsonResponse(body, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => body,
  };
}

function makeShell(root) {
  return ({ contentHtml, topbarActionsHtml = '' }) => {
    root.innerHTML = `<div class="topbar-actions">${topbarActionsHtml}</div><div class="main-body">${contentHtml}</div>`;
  };
}

test('Equipment tab renders Icon column, supports preset icon selection, SYSTEM_ICON upload, and Preview Drawer', async () => {
  const env = createDomEnvironment({ hash: '#/admin/equipment', token: 'tok-eq-icon' });
  setToken('tok-eq-icon');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Admin' });

  const iconId = '88888888-8888-4888-8888-888888888888';
  const requests = [];

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    const isMedia = parsed.pathname === '/api/v1/media/images';
    const body = isMedia ? options.body : (options.body ? JSON.parse(options.body) : undefined);
    requests.push({
      path: parsed.pathname,
      method: options.method || 'GET',
      headers: options.headers || {},
      body,
    });

    if (parsed.pathname === '/api/v1/admin/equipment' && (!options.method || options.method === 'GET')) {
      return jsonResponse({
        data: [
          {
            id: 'eq-1',
            name: 'Máy chạy bộ Technogym',
            category: 'Cardio',
            targetMuscles: ['Chân'],
            usageSteps: ['Khởi động 5 phút'],
            imageMediaId: null,
            iconKey: 'treadmill',
            iconMediaId: null,
            status: 'ACTIVE',
          },
          {
            id: 'eq-2',
            name: 'Khung gánh tạ Power Rack',
            category: 'Strength',
            targetMuscles: ['Đùi', 'Lưng'],
            usageSteps: ['Kiểm tra chốt an toàn'],
            imageMediaId: null,
            iconKey: null,
            iconMediaId: iconId,
            iconThumbnailUrl: `/api/v1/media/public/${iconId}?size=120&v=${iconId}`,
            status: 'ACTIVE',
          },
        ],
        pagination: { page: 1, pageSize: 10, totalItems: 2, totalPages: 1 },
      });
    }
    if (isMedia && options.method === 'POST') {
      return jsonResponse({
        data: {
          id: iconId,
          purpose: 'SYSTEM_ICON',
          accessScope: 'PUBLIC',
          publicUrl: `/api/v1/media/public/${iconId}?v=${iconId}`,
          thumbnailUrl: `/api/v1/media/public/${iconId}?size=120&v=${iconId}`,
        },
      }, 201);
    }
    if (parsed.pathname === '/api/v1/admin/equipment/eq-1' && options.method === 'PATCH') {
      return jsonResponse({ data: { id: 'eq-1', ...body } });
    }
    if (parsed.pathname === '/api/v1/admin/equipment' && options.method === 'POST') {
      return jsonResponse({ data: { id: 'eq-3', ...body } }, 201);
    }
    throw new Error(`Unexpected ${options.method || 'GET'} ${parsed.pathname}`);
  };

  await renderEquipmentPage({ root: env.root, params: new URLSearchParams(), shell: makeShell(env.root) });

  const tableHtml = env.root.querySelector('table').innerHTML;
  assert.equal(tableHtml.includes('Máy chạy bộ / Cardio'), true);
  assert.equal(tableHtml.includes('Icon tải lên'), true);
  assert.equal(tableHtml.includes(`/api/v1/media/public/${iconId}?size=120&amp;v=${iconId}`), true);

  // Preview Drawer includes Icon thiết bị
  env.root.querySelector('.preview-eq[data-id="eq-1"]').click();
  await flush();
  assert.equal(env.drawerPanel.innerHTML.includes('Icon thiết bị'), true);
  assert.equal(env.drawerPanel.innerHTML.includes('Máy chạy bộ / Cardio'), true);

  // Edit eq-1 -> verify horizontal modal layout + dropdown, switch preset icon from treadmill to bike and save
  env.root.querySelector('.edit-eq[data-id="eq-1"]').click();
  await flush();
  assert.ok(env.modalDialog.querySelector('.meta-modal-horizontal-layout'));
  assert.ok(env.modalDialog.querySelector('.modal-col-left'));
  assert.ok(env.modalDialog.querySelector('.modal-col-right'));
  assert.ok(env.modalDialog.querySelector('.modal-section-card'));
  assert.ok(env.modalDialog.querySelector('.meta-form-section-header'));
  const photoDropdownBtn = env.modalDialog.querySelector('#btn-eq-photo-dropdown');
  const photoDropdownMenu = env.modalDialog.querySelector('#eq-photo-dropdown-menu');
  assert.ok(photoDropdownBtn && photoDropdownMenu);
  assert.equal(photoDropdownMenu.hidden, true);
  photoDropdownBtn.click();
  assert.equal(photoDropdownMenu.hidden, false);

  const bikeBtn = env.modalDialog.querySelector('[data-eq-icon-key="bike"]');
  assert.ok(bikeBtn);
  bikeBtn.click();
  await flush();
  assert.equal(bikeBtn.classList.contains('active'), true);

  env.modalDialog.querySelector('#equipment-form').dispatchEvent({ type: 'submit' });
  await flush();

  const patchReq = requests.find((r) => r.path === '/api/v1/admin/equipment/eq-1' && r.method === 'PATCH');
  assert.ok(patchReq);
  assert.equal(patchReq.body.iconKey, 'bike');
  assert.equal(patchReq.body.iconMediaId, null);

  // Create new equipment -> upload custom WebP icon via SYSTEM_ICON
  env.root.querySelector('#create-item').click();
  await flush();
  const iconFileInput = env.modalDialog.querySelector('#eq-icon-file');
  const webpBytes = new Uint8Array([82, 73, 70, 70]);
  iconFileInput.files = [{
    name: 'custom-icon.webp',
    type: 'image/webp',
    size: webpBytes.byteLength,
    arrayBuffer: async () => webpBytes.buffer,
  }];
  iconFileInput.dispatchEvent({ type: 'change' });
  await flush();

  const iconUploadReq = requests.find((r) => r.path === '/api/v1/media/images' && r.method === 'POST');
  assert.ok(iconUploadReq);
  assert.equal(iconUploadReq.headers['x-image-purpose'], 'SYSTEM_ICON');
  assert.ok(env.modalDialog.querySelector('#eq-icon-preview-img'));

  env.modalDialog.querySelector('[name="name"]').value = 'Xe đạp AirBike';
  env.modalDialog.querySelector('[name="category"]').value = 'Cardio';
  env.modalDialog.querySelector('[name="steps"]').value = 'Điều chỉnh yên xe\nĐạp đều nhịp';
  env.modalDialog.querySelector('#equipment-form').dispatchEvent({ type: 'submit' });
  await flush();

  const postReq = requests.find((r) => r.path === '/api/v1/admin/equipment' && r.method === 'POST');
  assert.ok(postReq);
  assert.equal(postReq.body.iconMediaId, iconId);
});
