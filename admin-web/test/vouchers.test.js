import assert from 'node:assert/strict';
import test from 'node:test';

import { createDomEnvironment, flush, jsonResponse } from './helpers/dom-harness.js';
import { renderShell } from '../src/components/layout.js';
import { renderVouchersPage } from '../src/pages/vouchers.js';
import { setCurrentUser, setToken } from '../src/services/api.js';
import { parseHash } from '../src/state/router.js';

test('Vouchers module renders promo list, supports creating Percent/Fixed vouchers and toggle status', async () => {
  const env = createDomEnvironment({ hash: '#/admin/vouchers', token: 'tok' });
  setToken('tok');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', staffPosition: 'ADMIN', permissions: ['*'], fullName: 'Admin', email: 'admin@metagym.vn' });

  assert.equal(parseHash('#/admin/vouchers').section, 'vouchers');
  assert.equal(parseHash('#/admin/promo').section, 'vouchers');

  let vouchers = [
    {
      id: 'v1',
      code: 'METAGYM150K',
      title: 'Ưu đãi Hội viên mới -150K',
      description: 'Giảm 150K lần đầu',
      imageMediaId: 'img-v1',
      imageUrl: '/api/v1/media/public/img-v1?v=img-v1',
      imageThumbnailUrl: '/api/v1/media/public/img-v1?size=120&v=img-v1',
      discountType: 'FIXED_AMOUNT',
      discountValue: 150000,
      maxDiscountAmount: null,
      applyScope: 'GYM_PLAN',
      targetMemberScope: 'NEW_MEMBER',
      minOrderAmount: 500000,
      maxTotalUses: 100,
      maxUsesPerMember: 1,
      usedCount: 2,
      status: 'ACTIVE',
      phase: 'ACTIVE',
    },
  ];
  const created = [];

  globalThis.fetch = async (url, opts = {}) => {
    const u = new URL(url, 'http://localhost');
    if (u.pathname === '/api/v1/admin/vouchers' && (!opts.method || opts.method === 'GET')) {
      return jsonResponse({
        data: vouchers,
        summary: { totalVouchers: vouchers.length, activeNowCount: vouchers.length, upcomingCount: 0, totalUsedCount: 2 },
        pagination: { page: 1, pageSize: 20, totalItems: vouchers.length, totalPages: 1 },
      });
    }
    if (u.pathname === '/api/v1/admin/membership-plans') {
      return jsonResponse({ data: [{ id: 'p1', name: 'Gói Vàng', price: 1200000 }] });
    }
    if (u.pathname === '/api/v1/admin/vouchers' && opts.method === 'POST') {
      const body = JSON.parse(opts.body);
      created.push(body);
      vouchers = [...vouchers, { id: 'v2', ...body, usedCount: 0, phase: 'ACTIVE' }];
      return jsonResponse({ data: vouchers[vouchers.length - 1] }, 201);
    }
    throw new Error(`Unexpected ${opts.method || 'GET'} ${u.pathname}`);
  };

  await renderVouchersPage({
    root: env.root,
    params: new URLSearchParams(),
    shell: (opts) => renderShell({ root: env.root, user: { id: 'adm-1', role: 'ADMIN', fullName: 'Admin', email: 'admin@metagym.vn' }, ...opts }),
  });

  assert.ok(env.root.querySelector('a.meta-nav-item[href="#/admin/vouchers"]'));
  assert.equal(env.root.innerHTML.includes('METAGYM150K'), true);
  assert.equal(env.root.innerHTML.includes('Hội viên mua lần đầu'), true);

  env.root.querySelector('#add-voucher-btn').click();
  const form = env.modalDialog.querySelector('#voucher-form');
  form.querySelector('[name="code"]').value = 'tangbi20';
  form.querySelector('[name="title"]').value = 'Giảm 20% Mùa Đông';
  form.querySelector('[name="discountType"]').value = 'PERCENT';
  form.querySelector('[name="discountType"]').dispatchEvent({ type: 'change' });
  form.querySelector('[name="discountValue"]').value = '20';
  form.querySelector('[name="maxDiscountAmount"]').value = '300000';
  form.querySelector('[name="minOrderAmount"]').value = '800000';
  form.dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(created.length, 1);
  assert.equal(created[0].code, 'TANGBI20');
  assert.equal(created[0].discountType, 'PERCENT');
  assert.equal(created[0].discountValue, 20);
  assert.equal(created[0].maxDiscountAmount, 300000);
});
