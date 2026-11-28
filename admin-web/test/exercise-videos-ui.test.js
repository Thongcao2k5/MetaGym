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

test('Exercises tab renders video column, hasVideo filter, and Video Preview Drawer', async () => {
  const env = createDomEnvironment({ hash: '#/admin/equipment?tab=exercises', token: 'tok-ex-vid' });
  setToken('tok-ex-vid');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Admin' });

  const eqId = '11111111-1111-4111-8111-111111111111';
  const vidId = '99999999-9999-4999-8999-999999999999';
  const requests = [];

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    requests.push({ path: parsed.pathname, search: parsed.search, method: options.method || 'GET' });
    if (parsed.pathname === '/api/v1/admin/equipment') {
      return jsonResponse({
        data: [{ id: eqId, name: 'Power Rack', category: 'Strength', videoUrl: null, status: 'ACTIVE' }],
        pagination: { page: 1, pageSize: 100, totalItems: 1, totalPages: 1 },
      });
    }
    if (parsed.pathname === '/api/v1/admin/exercises') {
      return jsonResponse({
        data: [
          {
            id: 'ex-1',
            name: 'Squat Uploaded',
            equipmentId: eqId,
            equipmentName: 'Power Rack',
            difficulty: 'INTERMEDIATE',
            targetMuscles: ['Đùi trước'],
            instructions: 'Hạ hông song song sàn.',
            videoMediaId: vidId,
            videoStreamUrl: `/api/v1/media/videos/public/${vidId}?v=${vidId}`,
            videoMeta: { id: vidId, originalName: 'squat.mp4', mimeType: 'video/mp4', sizeBytes: 2097152 },
            videoUrl: null,
            status: 'ACTIVE',
          },
          {
            id: 'ex-2',
            name: 'Deadlift YouTube',
            equipmentId: null,
            equipmentName: null,
            difficulty: 'ADVANCED',
            targetMuscles: ['Lưng dưới'],
            instructions: 'Kéo thanh tạ sát ống chân.',
            videoMediaId: null,
            videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
            status: 'ACTIVE',
          },
          {
            id: 'ex-3',
            name: 'Plank No Video',
            equipmentId: null,
            equipmentName: null,
            difficulty: 'BEGINNER',
            targetMuscles: ['Core'],
            instructions: 'Giữ thân thẳng.',
            videoMediaId: null,
            videoUrl: null,
            status: 'ACTIVE',
          },
        ],
        pagination: { page: 1, pageSize: 10, totalItems: 3, totalPages: 1 },
      });
    }
    throw new Error(`Unexpected ${parsed.pathname}`);
  };

  await renderEquipmentPage({
    root: env.root,
    params: new URLSearchParams({ tab: 'exercises' }),
    shell: makeShell(env.root),
  });

  const tableHtml = env.root.querySelector('table').innerHTML;
  assert.equal(tableHtml.includes('Video tải lên'), true);
  assert.equal(tableHtml.includes('2.0 MB'), true);
  assert.equal(tableHtml.includes('YouTube'), true);
  assert.equal(tableHtml.includes('Chưa có'), true);

  // Filter by hasVideo=WITH_VIDEO triggers server query
  const hasVideoSel = env.root.querySelector('#cat-has-video');
  assert.ok(hasVideoSel, 'Must render hasVideo filter select');
  hasVideoSel.value = 'WITH_VIDEO';
  hasVideoSel.dispatchEvent({ type: 'change' });
  await flush();
  const filteredReq = [...requests].reverse().find((r) => r.path === '/api/v1/admin/exercises');
  assert.equal(filteredReq.search.includes('hasVideo=WITH_VIDEO'), true);

  // Preview drawer renders <video> for uploaded video and YouTube iframe for YouTube URL
  const previewBtns = env.root.querySelectorAll('.preview-ex');
  assert.equal(previewBtns.length, 3);
  previewBtns[0].click();
  await flush();
  assert.equal(env.drawerPanel.innerHTML.includes('<video controls'), true);
  assert.equal(env.drawerPanel.innerHTML.includes(`/api/v1/media/videos/public/${vidId}`), true);

  previewBtns[1].click();
  await flush();
  assert.equal(env.drawerPanel.innerHTML.includes('https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ'), true);
});

test('Exercise modal supports uploading MP4 video, switching to YouTube URL with inline validation, and saving', async () => {
  const env = createDomEnvironment({ hash: '#/admin/equipment?tab=exercises', token: 'tok-ex-upload' });
  setToken('tok-ex-upload');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Admin' });

  const uploadedVideoId = '77777777-7777-4777-8777-777777777777';
  const requests = [];

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    const isUpload = parsed.pathname === '/api/v1/media/videos';
    const body = isUpload ? options.body : (options.body ? JSON.parse(options.body) : undefined);
    requests.push({ path: parsed.pathname, method: options.method || 'GET', body });

    if (parsed.pathname === '/api/v1/admin/equipment') {
      return jsonResponse({ data: [], pagination: { page: 1, pageSize: 100, totalItems: 0, totalPages: 1 } });
    }
    if (parsed.pathname === '/api/v1/admin/exercises' && (!options.method || options.method === 'GET')) {
      return jsonResponse({ data: [], pagination: { page: 1, pageSize: 10, totalItems: 0, totalPages: 1 } });
    }
    if (isUpload && options.method === 'POST') {
      return jsonResponse({
        data: {
          id: uploadedVideoId,
          purpose: 'EXERCISE',
          accessScope: 'PUBLIC',
          mimeType: 'video/mp4',
          sizeBytes: 1024,
          originalName: 'pushup-demo.mp4',
          publicUrl: `/api/v1/media/videos/public/${uploadedVideoId}?v=${uploadedVideoId}`,
        },
      }, 201);
    }
    if (parsed.pathname === '/api/v1/admin/exercises' && options.method === 'POST') {
      return jsonResponse({ data: { id: 'ex-new-1', ...body } }, 201);
    }
    throw new Error(`Unexpected ${options.method || 'GET'} ${parsed.pathname}`);
  };

  await renderEquipmentPage({
    root: env.root,
    params: new URLSearchParams({ tab: 'exercises' }),
    shell: makeShell(env.root),
  });

  // Open Create Exercise modal
  env.root.querySelector('#create-item').click();
  await flush();

  // Switch to UPLOAD mode and upload an MP4 file
  env.modalDialog.querySelector('#ex-mode-upload').click();
  await flush();
  const fileInput = env.modalDialog.querySelector('#ex-video-file');
  fileInput.files = [new File([new Uint8Array(1024)], 'pushup-demo.mp4', { type: 'video/mp4' })];
  fileInput.dispatchEvent({ type: 'change' });
  await flush();

  const uploadReq = requests.find((r) => r.path === '/api/v1/media/videos' && r.method === 'POST');
  assert.ok(uploadReq, 'Must POST uploaded video to /api/v1/media/videos');
  assert.equal(env.modalDialog.querySelector('#ex-video-upload-meta').innerHTML.includes('pushup-demo.mp4'), true);
  assert.equal(env.modalDialog.querySelector('#ex-video-preview-wrap').innerHTML.includes('<video controls'), true);

  // Fill required exercise fields and save with uploaded videoMediaId
  env.modalDialog.querySelector('[name="name"]').value = 'Push Up';
  env.modalDialog.querySelector('[name="instructions"]').value = 'Chống đẩy giữ thân thẳng.';
  env.modalDialog.querySelector('#exercise-form').dispatchEvent({ type: 'submit' });
  await flush();

  const postUploadEx = requests.find((r) => r.path === '/api/v1/admin/exercises' && r.method === 'POST');
  assert.ok(postUploadEx);
  assert.equal(postUploadEx.body.videoMediaId, uploadedVideoId);
  assert.equal(postUploadEx.body.videoUrl, null);

  // Re-open modal and test URL mode + validation + YouTube embed preview
  env.root.querySelector('#create-item').click();
  await flush();
  env.modalDialog.querySelector('#ex-mode-url').click();
  await flush();
  env.modalDialog.querySelector('[name="name"]').value = 'Pull Up';
  env.modalDialog.querySelector('[name="instructions"]').value = 'Kéo xà đơn qua cằm.';
  env.modalDialog.querySelector('[name="videoUrl"]').value = 'javascript:alert(1)';
  env.modalDialog.querySelector('#exercise-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(requests.filter((r) => r.path === '/api/v1/admin/exercises' && r.method === 'POST').length, 1, 'Invalid URL must block submit');
  assert.equal(env.modalDialog.querySelector('#ex-video-url-error').textContent.includes('http://'), true);

  env.modalDialog.querySelector('[name="videoUrl"]').value = 'https://youtu.be/abc123XYZ';
  env.modalDialog.querySelector('[name="videoUrl"]').dispatchEvent({ type: 'blur' });
  await flush();
  assert.equal(env.modalDialog.querySelector('#ex-video-preview-wrap').innerHTML.includes('https://www.youtube-nocookie.com/embed/abc123XYZ'), true);

  env.modalDialog.querySelector('#exercise-form').dispatchEvent({ type: 'submit' });
  await flush();

  const postUrlEx = requests.filter((r) => r.path === '/api/v1/admin/exercises' && r.method === 'POST')[1];
  assert.ok(postUrlEx);
  assert.equal(postUrlEx.body.videoUrl, 'https://youtu.be/abc123XYZ');
  assert.equal(postUrlEx.body.videoMediaId, null);
});
