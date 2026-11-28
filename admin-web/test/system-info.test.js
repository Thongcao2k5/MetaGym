import assert from 'node:assert/strict';
import test from 'node:test';

import { createDomEnvironment, flush, jsonResponse } from './helpers/dom-harness.js';
import { setCurrentUser, setToken } from '../src/services/api.js';
import { renderShell } from '../src/components/layout.js';
import { renderSystemInfoPage } from '../src/pages/system-info.js';

function makeShell(root) {
  return (opts) => renderShell({
    root,
    user: { id: 'adm-1', role: 'ADMIN', fullName: 'Meta Admin', email: 'admin@metagym.vn' },
    ...opts,
  });
}

function mockSystemData() {
  return {
    privacyPolicy: {
      title: 'Chính sách bảo mật',
      badge: 'BẢO VỆ DỮ LIỆU CÁ NHÂN',
      version: '1.0',
      effectiveDate: '2026-11-01',
      contactEmail: 'privacy@metagym.vn',
      summary: 'Mã hóa chuẩn AES-256 · Tuân thủ Nghị định 13/2023/NĐ-CP',
      sections: [
        { id: 's1', heading: '1. Dữ liệu thu thập', body: 'Họ tên, email và chỉ số tập luyện.' },
      ],
    },
    termsOfUse: {
      title: 'Điều khoản sử dụng',
      subtitle: 'Meta Gym Member Agreement',
      version: '1.0',
      effectiveDate: '2026-11-01',
      contactEmail: 'legal@metagym.vn',
      sections: [
        { id: 't1', heading: '1. Tài khoản NFC', body: 'Không chuyển nhượng thẻ.' },
      ],
    },
    homeIcons: {
      items: [
        {
          key: 'action_schedule',
          label: 'Lịch tập tuần',
          subtitle: 'Xem lịch buổi tập',
          roleTarget: 'MEMBER',
          route: '/schedule',
          mediaId: '11111111-1111-4111-8111-111111111111',
          thumbnailUrl: '/api/v1/media/public/11111111-1111-4111-8111-111111111111?size=120',
          accentColor: '#FF5E36',
          sortOrder: 1,
          enabled: true,
        },
      ],
    },
    paymentMethods: {
      methods: [
        {
          code: 'MOMO',
          name: 'Ví điện tử MoMo',
          channelLabel: 'Trực tuyến (App)',
          providerNote: 'Cổng thanh toán MoMo QR',
          minAmount: 1000,
          maxAmount: 50000000,
          feeNote: 'Miễn phí',
          instructions: 'Quét mã QR MoMo.',
          supportsGymPlans: true,
          supportsCoachPackages: true,
          sortOrder: 1,
          enabled: true,
        },
      ],
    },
    updatedAtByKey: {},
  };
}

test('System Info module renders 6 tabs, saves Privacy Policy & Terms, edits Home Icons & Payment Methods, and manages Equipment Guides', async () => {
  const sysData = mockSystemData();
  const equipmentRows = [
    {
      id: 'eq-1',
      name: 'Máy chạy bộ Technogym Run',
      category: 'Cardio',
      targetMuscles: ['Tim mạch', 'Chân'],
      usageSteps: ['Kẹp khóa an toàn', 'Bấm Start tăng tốc từ từ'],
      safetyNotes: 'Không bước xuống khi băng tải chưa dừng.',
      videoUrl: null,
      imageMediaId: null,
      status: 'ACTIVE',
    },
  ];
  const calls = [];

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    const method = options.method || 'GET';
    const body = typeof options.body === 'string' ? JSON.parse(options.body) : undefined;
    calls.push({ path: parsed.pathname, method, body, headers: options.headers });

    if (parsed.pathname === '/api/v1/admin/system-info' && method === 'GET') {
      return jsonResponse({ data: sysData });
    }
    if (parsed.pathname === '/api/v1/admin/system-info/privacy-policy' && method === 'PUT') {
      sysData.privacyPolicy = body;
      return jsonResponse({ data: body });
    }
    if (parsed.pathname === '/api/v1/admin/system-info/terms-of-use' && method === 'PUT') {
      sysData.termsOfUse = body;
      return jsonResponse({ data: body });
    }
    if (parsed.pathname === '/api/v1/admin/system-info/home-icons' && method === 'PUT') {
      sysData.homeIcons = body;
      return jsonResponse({ data: body });
    }
    if (parsed.pathname === '/api/v1/admin/system-info/payment-methods' && method === 'PUT') {
      sysData.paymentMethods = body;
      return jsonResponse({ data: body });
    }
    if (parsed.pathname === '/api/v1/admin/equipment' && method === 'GET') {
      return jsonResponse({ data: equipmentRows, pagination: { page: 1, pageSize: 50, totalItems: 1, totalPages: 1 } });
    }
    if (parsed.pathname === '/api/v1/admin/equipment/eq-1' && method === 'PATCH') {
      Object.assign(equipmentRows[0], body);
      return jsonResponse({ data: equipmentRows[0] });
    }
    throw new Error(`Unexpected ${method} ${parsed.pathname}`);
  };

  // 1. Privacy Policy tab
  const env = createDomEnvironment({ hash: '#/admin/system-info', token: 'tok' });
  setToken('tok');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Meta Admin' });

  await renderSystemInfoPage({ root: env.root, params: new URLSearchParams(), shell: makeShell(env.root) });
  assert.ok(env.root.querySelector('a.meta-nav-item[href="#/admin/system-info"].active'));
  assert.equal(env.root.querySelectorAll('[data-sys-tab]').length, 6);

  env.root.querySelector('[name="version"]').value = '2.1';
  env.root.querySelector('#sysinfo-legal-form').dispatchEvent({ type: 'submit' });
  await flush();
  assert.equal(calls.find((c) => c.path.endsWith('/privacy-policy')).body.version, '2.1');

  // 2. Payment Methods tab
  await renderSystemInfoPage({ root: env.root, params: new URLSearchParams({ tab: 'payments' }), shell: makeShell(env.root) });
  assert.equal(env.root.innerHTML.includes('Ví điện tử MoMo'), true);
  env.root.querySelector('.sysinfo-edit-pay').click();
  await flush();
  env.modalDialog.querySelector('[name="feeNote"]').value = 'Miễn phí hoàn toàn';
  env.modalDialog.querySelector('#sysinfo-pay-form').dispatchEvent({ type: 'submit' });
  await flush();
  assert.equal(calls.find((c) => c.path.endsWith('/payment-methods')).body.methods[0].feeNote, 'Miễn phí hoàn toàn');

  // 3. Home Icons tab
  await renderSystemInfoPage({ root: env.root, params: new URLSearchParams({ tab: 'home-icons' }), shell: makeShell(env.root) });
  assert.equal(env.root.innerHTML.includes('Lịch tập tuần'), true);
  env.root.querySelector('.sysinfo-edit-icon').click();
  await flush();
  env.modalDialog.querySelector('[name="label"]').value = 'Lịch tập hàng tuần';
  env.modalDialog.querySelector('#sysinfo-icon-form').dispatchEvent({ type: 'submit' });
  await flush();
  assert.equal(calls.find((c) => c.path.endsWith('/home-icons')).body.items[0].label, 'Lịch tập hàng tuần');

  // 4. Equipment Guides tab
  await renderSystemInfoPage({ root: env.root, params: new URLSearchParams({ tab: 'equipment-guides' }), shell: makeShell(env.root) });
  assert.equal(env.root.innerHTML.includes('Kẹp khóa an toàn'), true);
  env.root.querySelector('.sys-guide-edit').click();
  await flush();
  env.modalDialog.querySelector('[name="usageSteps"]').value = 'Kẹp khóa an toàn\nKhởi động tốc độ 3 km/h';
  env.modalDialog.querySelector('#sys-guide-form').dispatchEvent({ type: 'submit' });
  await flush();
  assert.deepEqual(
    calls.find((c) => c.path === '/api/v1/admin/equipment/eq-1' && c.method === 'PATCH').body.usageSteps,
    ['Kẹp khóa an toàn', 'Khởi động tốc độ 3 km/h'],
  );
});
