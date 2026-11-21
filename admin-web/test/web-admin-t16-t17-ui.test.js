import assert from 'node:assert/strict';
import test from 'node:test';

import { createDomEnvironment, flush, jsonResponse } from './helpers/dom-harness.js';
import { setCurrentUser, setToken } from '../src/services/api.js';
import { renderShell } from '../src/components/layout.js';
import { renderNutritionFoodsPage } from '../src/pages/nutrition-foods.js';
import { renderEquipmentPage } from '../src/pages/equipment.js';
import { renderGymPage } from '../src/pages/gym.js';

function makeShell(root) {
  return (opts) => renderShell({ root, user: { fullName: 'Admin', role: 'ADMIN' }, ...opts });
}

test('T16 Nutrition Foods supports server-side search/active/pageSize, selectable export, status toggle, and trg_freeze_nutrition_calories note', async () => {
  const env = createDomEnvironment({ hash: '#/admin/nutrition-foods', token: 'tok-foods' });
  setToken('tok-foods');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Admin' });

  const requests = [];
  let foodRow = {
    id: 'food-uuid-01',
    name: 'Ức gà áp chảo',
    kcalPer100g: 165,
    active: true,
  };
  let failPatchOnce = true;

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    const body = options.body ? JSON.parse(options.body) : undefined;
    requests.push({ path: parsed.pathname, method: options.method || 'GET', search: parsed.search, body });

    if (parsed.pathname === '/api/v1/admin/nutrition-foods' && (!options.method || options.method === 'GET')) {
      const page = Number(parsed.searchParams.get('page') || 1);
      const pageSize = Number(parsed.searchParams.get('pageSize') || 10);
      return jsonResponse({
        data: [foodRow],
        pagination: { page, pageSize, totalItems: 1, totalPages: 1 },
      });
    }
    if (parsed.pathname === '/api/v1/admin/nutrition-foods/food-uuid-01' && options.method === 'PATCH') {
      if (failPatchOnce && body.kcalPer100g !== undefined) {
        failPatchOnce = false;
        return jsonResponse({ error: { code: 'CONFLICT', message: 'Lỗi xung đột tạm thời' } }, 409);
      }
      foodRow = { ...foodRow, ...body };
      return jsonResponse({ data: foodRow });
    }
    throw new Error(`Unexpected ${options.method || 'GET'} ${parsed.pathname}`);
  };

  await renderNutritionFoodsPage({ root: env.root, params: new URLSearchParams(), shell: makeShell(env.root) });

  assert.equal(requests[0].path, '/api/v1/admin/nutrition-foods');
  assert.equal(requests[0].search.includes('pageSize=10'), true);
  assert.ok(env.root.querySelector('[data-select-all]'), 'Table must render selectable checkboxes');
  assert.ok(env.root.querySelector('#food-export-excel'), 'Filter bar must render Export Excel button');
  assert.ok(env.root.querySelector('#food-page-size'), 'Pagination must render pageSize selector');

  // Filter active=true triggers server-side GET
  const activeSel = env.root.querySelector('#food-active');
  activeSel.value = 'true';
  activeSel.dispatchEvent({ type: 'change' });
  await flush();
  assert.equal(requests[requests.length - 1].search.includes('active=true'), true);

  // Change pageSize to 50 triggers server-side GET with pageSize=50
  const sizeSel = env.root.querySelector('#food-page-size');
  sizeSel.value = '50';
  sizeSel.dispatchEvent({ type: 'change' });
  await flush();
  assert.equal(requests[requests.length - 1].search.includes('pageSize=50'), true);

  // Debounced search triggers server-side GET with search=
  const searchEl = env.root.querySelector('#food-search');
  searchEl.value = 'gà';
  searchEl.dispatchEvent({ type: 'input' });
  await new Promise((r) => setTimeout(r, 320));
  await flush();
  assert.equal(requests[requests.length - 1].search.includes('search='), true);

  // Open Edit Modal -> verify trg_freeze_nutrition_calories note + preserve input on 409 + retry succeeds
  env.root.querySelector('.edit-food[data-id="food-uuid-01"]').click();
  await flush();
  assert.equal(env.modalDialog.innerHTML.includes('trg_freeze_nutrition_calories'), true);

  env.modalDialog.querySelector('[name="kcal"]').value = '172.5';
  env.modalDialog.querySelector('#food-form').dispatchEvent({ type: 'submit' });
  await flush();
  assert.equal(env.modalOverlay.hidden, false, 'Modal stays open on 409 error');
  assert.equal(env.modalDialog.querySelector('[name="kcal"]').value, '172.5', 'Preserves kcal input on error');

  env.modalDialog.querySelector('#food-form').dispatchEvent({ type: 'submit' });
  await flush();
  assert.equal(env.modalOverlay.hidden, true, 'Modal closes after retry succeeds');
  const patchReq = requests.find((r) => r.method === 'PATCH' && r.body?.kcalPer100g === 172.5);
  assert.ok(patchReq, 'Must send PATCH /admin/nutrition-foods/:id with updated kcalPer100g');

  // Toggle status switch -> confirm modal -> PATCH { active: false }
  env.root.querySelector('.toggle-food-active[data-id="food-uuid-01"]').click();
  await flush();
  assert.equal(env.modalOverlay.hidden, false);
  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();
  const togglePatch = [...requests].reverse().find((r) => r.method === 'PATCH');
  assert.deepEqual(togglePatch.body, { active: false });
});

test('T17 Equipment tab supports server-side filters, public EQUIPMENT image upload, preview URL, and saving imageMediaId', async () => {
  const env = createDomEnvironment({ hash: '#/admin/equipment', token: 'tok-eq' });
  setToken('tok-eq');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Admin' });

  const requests = [];
  const uploadedMediaId = '11111111-1111-4111-8111-111111111111';

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    const isMedia = parsed.pathname === '/api/v1/media/images';
    const body = isMedia ? options.body : (options.body ? JSON.parse(options.body) : undefined);
    requests.push({
      path: parsed.pathname,
      method: options.method || 'GET',
      search: parsed.search,
      headers: options.headers || {},
      body,
    });

    if (parsed.pathname === '/api/v1/admin/equipment' && (!options.method || options.method === 'GET')) {
      return jsonResponse({
        data: [{
          id: 'eq-uuid-1',
          name: 'Máy chạy bộ Technogym',
          category: 'Cardio',
          targetMuscles: ['Chân', 'Tim mạch'],
          usageSteps: ['Khởi động 5 phút'],
          safetyNotes: 'Kẹp dây an toàn',
          imageMediaId: null,
          status: 'ACTIVE',
        }],
        pagination: { page: 1, pageSize: 10, totalItems: 1, totalPages: 1 },
      });
    }
    if (isMedia && options.method === 'POST') {
      return jsonResponse({
        data: {
          id: uploadedMediaId,
          purpose: 'EQUIPMENT',
          accessScope: 'PUBLIC',
          publicUrl: `/api/v1/media/public/${uploadedMediaId}`,
        },
      }, 201);
    }
    if (parsed.pathname === '/api/v1/admin/equipment/eq-uuid-1' && options.method === 'PATCH') {
      return jsonResponse({ data: { id: 'eq-uuid-1', ...body } });
    }
    throw new Error(`Unexpected ${options.method || 'GET'} ${parsed.pathname}`);
  };

  await renderEquipmentPage({ root: env.root, params: new URLSearchParams(), shell: makeShell(env.root) });

  assert.ok(env.root.querySelector('[data-select-all]'));
  assert.ok(env.root.querySelector('#cat-export-excel'));
  assert.ok(env.root.querySelector('#eq-page-size'));

  // Open Edit Equipment Modal
  env.root.querySelector('.edit-eq[data-id="eq-uuid-1"]').click();
  await flush();

  const fileInput = env.modalDialog.querySelector('#eq-image-file');
  assert.equal(fileInput.getAttribute('accept'), 'image/jpeg,image/png');

  // Reject unsupported image/webp before upload
  fileInput.files = [{
    name: 'bad.webp',
    type: 'image/webp',
    size: 1200,
    arrayBuffer: async () => new Uint8Array([1, 2, 3]).buffer,
  }];
  fileInput.dispatchEvent({ type: 'change' });
  await flush();
  assert.equal(requests.filter((r) => r.path === '/api/v1/media/images').length, 0, 'Must reject image/webp');
  assert.equal(env.modalDialog.innerHTML.includes('JPEG'), true);

  // Upload valid PNG -> POST /api/v1/media/images with x-image-purpose: EQUIPMENT
  const pngBytes = new Uint8Array([137, 80, 78, 71]);
  fileInput.files = [{
    name: 'treadmill.png',
    type: 'image/png',
    size: pngBytes.byteLength,
    arrayBuffer: async () => pngBytes.buffer,
  }];
  fileInput.dispatchEvent({ type: 'change' });
  await flush();

  const mediaReq = requests.find((r) => r.path === '/api/v1/media/images');
  assert.ok(mediaReq, 'Must upload image to POST /api/v1/media/images');
  assert.equal(mediaReq.headers['x-image-purpose'], 'EQUIPMENT');
  assert.equal(mediaReq.headers['Content-Type'], 'image/png');
  assert.equal(mediaReq.headers.Authorization, 'Bearer tok-eq');

  const previewImg = env.modalDialog.querySelector('#eq-image-preview');
  assert.ok(previewImg, 'Must render live image preview');
  assert.equal(previewImg.getAttribute('src'), `/api/v1/media/public/${uploadedMediaId}`);

  // Save equipment -> sends imageMediaId
  env.modalDialog.querySelector('#equipment-form').dispatchEvent({ type: 'submit' });
  await flush();
  const patchReq = requests.find((r) => r.path === '/api/v1/admin/equipment/eq-uuid-1' && r.method === 'PATCH');
  assert.ok(patchReq, 'Must PATCH equipment');
  assert.equal(patchReq.body.imageMediaId, uploadedMediaId);
});

test('T17 Exercises tab renders equipmentName (never raw UUID), server-side filters, and submits targetMuscles[]', async () => {
  const env = createDomEnvironment({ hash: '#/admin/equipment?tab=exercises', token: 'tok-ex' });
  setToken('tok-ex');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Admin' });

  const requests = [];
  const eqId = '22222222-2222-4222-8222-222222222222';

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    const body = options.body ? JSON.parse(options.body) : undefined;
    requests.push({ path: parsed.pathname, method: options.method || 'GET', search: parsed.search, body });

    if (parsed.pathname === '/api/v1/admin/equipment') {
      return jsonResponse({
        data: [{ id: eqId, name: 'Khung gánh tạ Power Rack', category: 'Strength', status: 'ACTIVE' }],
        pagination: { page: 1, pageSize: 100, totalItems: 1, totalPages: 1 },
      });
    }
    if (parsed.pathname === '/api/v1/admin/exercises' && (!options.method || options.method === 'GET')) {
      return jsonResponse({
        data: [{
          id: 'ex-uuid-1',
          name: 'Barbell Back Squat',
          equipmentId: eqId,
          equipmentName: 'Khung gánh tạ Power Rack',
          difficulty: 'INTERMEDIATE',
          targetMuscles: ['Đùi trước', 'Mông'],
          instructions: 'Giữ lưng thẳng, hạ hông song song mặt sàn.',
          safetyNotes: 'Cài chốt an toàn trước khi nâng tạ.',
          status: 'ACTIVE',
        }],
        pagination: { page: 1, pageSize: 10, totalItems: 1, totalPages: 1 },
      });
    }
    if (parsed.pathname === '/api/v1/admin/exercises' && options.method === 'POST') {
      return jsonResponse({ data: { id: 'ex-uuid-2', ...body } }, 201);
    }
    throw new Error(`Unexpected ${options.method || 'GET'} ${parsed.pathname}`);
  };

  await renderEquipmentPage({
    root: env.root,
    params: new URLSearchParams({ tab: 'exercises' }),
    shell: makeShell(env.root),
  });

  const tableHtml = env.root.querySelector('table').innerHTML;
  assert.equal(tableHtml.includes('Khung gánh tạ Power Rack'), true, 'Exercises table must show equipmentName');
  assert.equal(tableHtml.includes(eqId), false, 'Exercises table must NEVER show raw equipment UUID');

  // Filter by difficulty=INTERMEDIATE -> server-side query
  const diffSel = env.root.querySelector('#cat-difficulty');
  diffSel.value = 'INTERMEDIATE';
  diffSel.dispatchEvent({ type: 'change' });
  await flush();
  const lastExGet = [...requests].reverse().find((r) => r.path === '/api/v1/admin/exercises' && r.method === 'GET');
  assert.equal(lastExGet.search.includes('difficulty=INTERMEDIATE'), true);

  // Create exercise -> sends targetMuscles[] (NOT muscleGroup)
  env.root.querySelector('#create-item').click();
  await flush();
  env.modalDialog.querySelector('[name="name"]').value = 'Bench Press';
  env.modalDialog.querySelector('[name="equipmentId"]').value = eqId;
  env.modalDialog.querySelector('[name="difficulty"]').value = 'BEGINNER';
  env.modalDialog.querySelector('[name="targetMuscles"]').value = 'Ngực, Tay sau';
  env.modalDialog.querySelector('[name="instructions"]').value = 'Hạ thanh tạ chạm nhẹ giữa ngực rồi đẩy lên.';
  env.modalDialog.querySelector('[name="safetyNotes"]').value = 'Luôn khóa kẹp tạ 2 đầu.';
  env.modalDialog.querySelector('#exercise-form').dispatchEvent({ type: 'submit' });
  await flush();

  const postReq = requests.find((r) => r.path === '/api/v1/admin/exercises' && r.method === 'POST');
  assert.ok(postReq);
  assert.deepEqual(postReq.body.targetMuscles, ['Ngực', 'Tay sau']);
  assert.equal('muscleGroup' in postReq.body, false, 'Must use targetMuscles[] per backend schema');
  assert.equal(postReq.body.equipmentId, eqId);
  assert.equal(postReq.body.difficulty, 'BEGINNER');
  assert.equal(postReq.body.safetyNotes, 'Luôn khóa kẹp tạ 2 đầu.');
});

test('T17 Gym Profile supports public GYM cover upload + saves coverMediaId while keeping Counter QR print & rotate intact', async () => {
  const env = createDomEnvironment({ hash: '#/admin/gym', token: 'tok-gym' });
  setToken('tok-gym');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Admin' });

  const requests = [];
  const coverId = '33333333-3333-4333-8333-333333333333';
  let gymData = {
    id: 1,
    name: 'Meta Gym Flagship',
    address: '123 Nguyễn Huệ, Q1, TP.HCM',
    phone: '0901234567',
    email: 'contact@metagym.vn',
    description: 'Phòng tập hiện đại',
    rules: 'Mang giày thể thao sạch',
    coverMediaId: null,
  };

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

    if (parsed.pathname === '/api/v1/gym-profile') {
      return jsonResponse({ data: gymData });
    }
    if (parsed.pathname === '/api/v1/admin/gym-checkin-code') {
      return jsonResponse({ data: { payload: 'METAGYM:CHECKIN:V1' } });
    }
    if (parsed.pathname === '/api/v1/admin/gym-checkin-code/rotate' && options.method === 'POST') {
      return jsonResponse({ data: { payload: 'METAGYM:CHECKIN:V2' } });
    }
    if (isMedia && options.method === 'POST') {
      return jsonResponse({
        data: { id: coverId, purpose: 'GYM', accessScope: 'PUBLIC', publicUrl: `/api/v1/media/public/${coverId}` },
      }, 201);
    }
    if (parsed.pathname === '/api/v1/admin/gym-profile' && options.method === 'PATCH') {
      gymData = { ...gymData, ...body };
      return jsonResponse({ data: gymData });
    }
    throw new Error(`Unexpected ${options.method || 'GET'} ${parsed.pathname}`);
  };

  await renderGymPage({
    root: env.root,
    params: new URLSearchParams(),
    shell: makeShell(env.root),
    QRCodeLib: { toDataURL: async (payload) => `data:image/png;base64,${Buffer.from(payload).toString('base64')}` },
  });

  // Counter QR rendered & Print enabled
  const printBtn = env.root.querySelector('#print-checkin');
  assert.equal(printBtn.disabled, false);
  printBtn.click();
  assert.equal(env.window.printCalled, 1, 'Print button must trigger window.print()');

  // Rotate QR via custom confirm modal
  env.root.querySelector('#rotate-checkin').click();
  await flush();
  assert.equal(env.modalOverlay.hidden, false);
  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();
  assert.ok(requests.some((r) => r.path === '/api/v1/admin/gym-checkin-code/rotate' && r.method === 'POST'));

  // Upload public GYM cover image
  const coverInput = env.root.querySelector('#gym-cover-file');
  const jpgBytes = new Uint8Array([255, 216, 255, 224]);
  coverInput.files = [{
    name: 'gym-cover.jpg',
    type: 'image/jpeg',
    size: jpgBytes.byteLength,
    arrayBuffer: async () => jpgBytes.buffer,
  }];
  coverInput.dispatchEvent({ type: 'change' });
  await flush();

  const mediaReq = requests.find((r) => r.path === '/api/v1/media/images');
  assert.ok(mediaReq);
  assert.equal(mediaReq.headers['x-image-purpose'], 'GYM');
  assert.equal(mediaReq.headers['Content-Type'], 'image/jpeg');
  assert.equal(mediaReq.headers.Authorization, 'Bearer tok-gym');

  const previewImg = env.root.querySelector('#gym-cover-preview');
  assert.ok(previewImg);
  assert.equal(previewImg.getAttribute('src'), `/api/v1/media/public/${coverId}`);

  // Submit Gym Profile -> saves coverMediaId
  env.root.querySelector('#gym-form').dispatchEvent({ type: 'submit' });
  await flush();
  const patchReq = requests.find((r) => r.path === '/api/v1/admin/gym-profile' && r.method === 'PATCH');
  assert.ok(patchReq);
  assert.equal(patchReq.body.coverMediaId, coverId);
});
