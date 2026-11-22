import assert from 'node:assert/strict';
import test from 'node:test';

import { createDomEnvironment, flush, jsonResponse } from './helpers/dom-harness.js';
import { setCurrentUser, setToken } from '../src/services/api.js';
import { renderShell } from '../src/components/layout.js';
import { renderAccountsPage } from '../src/pages/accounts.js';
import { renderDashboardPage } from '../src/pages/dashboard.js';

async function setupAccounts({
  role = 'MEMBER',
  initialStatus = 'ACTIVE',
  params = new URLSearchParams(),
  previewPayload = null,
  detailPayload = null,
  statusEffects = null,
  createCoachError = null,
} = {}) {
  const env = createDomEnvironment({
    hash: `#/admin/${role === 'COACH' ? 'coaches' : 'members'}`,
    token: 'test-admin-token',
  });
  setToken('test-admin-token');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Admin' });

  let status = initialStatus;
  const requests = [];
  const userId = role === 'COACH' ? 'coach-1' : 'member-test-id';

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    const path = parsed.pathname;
    const body = options.body ? JSON.parse(options.body) : undefined;
    requests.push({ path, method: options.method || 'GET', body, search: parsed.search });

    if (path === '/api/v1/admin/users' && (!options.method || options.method === 'GET')) {
      const searchQ = parsed.searchParams.get('search') || '';
      const statusQ = parsed.searchParams.get('status') || '';
      const matchesFilter = (!searchQ || (role === 'COACH' ? 'Coach Một' : 'Member Test').toLowerCase().includes(searchQ.toLowerCase()))
        && (!statusQ || statusQ === status);
      return jsonResponse({
        data: matchesFilter ? [{
          id: userId,
          fullName: role === 'COACH' ? 'Coach Một' : 'Member Test',
          email: role === 'COACH' ? 'coach@test.local' : 'member@test.local',
          phone: '0900000000',
          role,
          status,
          memberLimit: role === 'COACH' ? 8 : null,
          usedSlots: role === 'COACH' ? 5 : 0,
          openHoldCount: role === 'COACH' ? 1 : 0,
          activeMembershipEndDate: role === 'MEMBER' ? '2027-01-15' : null,
          coachRelationshipStatus: role === 'MEMBER' ? 'ACTIVE' : null,
          coachName: role === 'MEMBER' ? 'Lê Hoàng Nam' : null,
        }] : [],
        pagination: { page: Number(parsed.searchParams.get('page') || 1), pageSize: 20, totalItems: matchesFilter ? 1 : 0, totalPages: 1 },
      });
    }

    if (path === `/api/v1/admin/users/${userId}` && (!options.method || options.method === 'GET')) {
      return jsonResponse({
        data: detailPayload || {
          id: userId,
          fullName: role === 'COACH' ? 'Coach Một' : 'Member Test',
          email: role === 'COACH' ? 'coach@test.local' : 'member@test.local',
          phone: '0900000000',
          role,
          status,
          memberLimit: role === 'COACH' ? 8 : null,
          usedSlots: role === 'COACH' ? 5 : 0,
          activeRelationshipsCount: role === 'COACH' ? 4 : 0,
          openHoldCount: role === 'COACH' ? 1 : 0,
          scheduleConfigured: true,
          currentMembership: role === 'MEMBER' ? { planName: 'Gói Gym 90 ngày', status: 'ACTIVE', startDate: '2026-10-15', endDate: '2027-01-15' } : null,
          currentCoachRelationship: role === 'MEMBER' ? { id: 'rel-1', coachId: 'coach-1', coachName: 'Lê Hoàng Nam', status: 'ACTIVE', pauseReason: null } : null,
          // Even if an unexpected private key existed, UI must NEVER render it:
          healthNotes: 'SECRET_HEALTH_NOTE_MUST_NOT_SHOW',
          injuryNotes: 'SECRET_INJURY_NOTE_MUST_NOT_SHOW',
          recentLockHistory: [{ id: 'aud-1', action: 'USER_DISABLED', summary: 'Khóa tài khoản do vi phạm', reason: 'Vi phạm nội quy', createdAt: '2026-11-20T09:00:00.000Z' }],
        },
      });
    }

    if (path === `/api/v1/admin/users/${userId}/lock-preview`) {
      return jsonResponse({
        data: previewPayload || (role === 'COACH'
          ? {
            affectedRelationshipsCount: 2,
            affectedMembers: [{ memberName: 'Trần Thu Hà' }, { memberName: 'Lê Quang Huy' }],
            currentCoachRelationship: null,
            futureBookingsToCancelCount: 4,
            openHoldsToCancelCount: 2,
          }
          : {
            affectedRelationshipsCount: 1,
            affectedMembers: [],
            currentCoachRelationship: { relationshipId: 'rel-1', coachId: 'coach-1', coachName: 'Lê Hoàng Nam', status: 'ACTIVE', pauseReason: null },
            futureBookingsToCancelCount: 3,
            openHoldsToCancelCount: 1,
          }),
      });
    }

    if (path === `/api/v1/admin/users/${userId}/status` && options.method === 'PATCH') {
      if (body.status === 'DISABLED' && !body.reason?.trim()) {
        return jsonResponse({ error: { message: 'Trạng thái hoặc lý do không hợp lệ' } }, 422);
      }
      status = body.status;
      return jsonResponse({
        data: {
          user: { id: userId, status, memberLimit: role === 'COACH' ? 8 : null },
          effects: statusEffects || (body.status === 'DISABLED'
            ? {
              sessionsRevoked: true,
              cancelledHoldsCount: 1,
              cancelledFutureBookingsCount: 4,
              affectedRelationshipsCount: role === 'COACH' ? 2 : 1,
              incidentsCreated: role === 'COACH' ? [{ memberName: 'Trần Thu Hà' }] : [],
            }
            : role === 'COACH'
              ? {
                restoredRelationshipsCount: 1,
                restored: [{ memberName: 'Trần Thu Hà', frozenDaysAdded: 4, newEndsOn: '2026-12-04', newRelationshipStatus: 'ACTIVE' }],
              }
              : { relationshipStatus: 'PAUSED', pauseReason: 'MEMBERSHIP_EXPIRED' }),
        },
      });
    }

    if (path === '/api/v1/admin/coaches' && options.method === 'POST') {
      if (createCoachError) {
        return jsonResponse({ error: { code: createCoachError.code, message: createCoachError.message } }, createCoachError.status);
      }
      return jsonResponse({ data: { id: 'coach-new', ...body, role: 'COACH', status: 'ACTIVE', memberLimit: 8 } }, 201);
    }

    if (path === `/api/v1/admin/users/${userId}` && options.method === 'PATCH') {
      return jsonResponse({ data: { id: userId, ...body } });
    }

    if (path === `/api/v1/admin/coaches/${userId}/password-resets` && options.method === 'POST') {
      return jsonResponse({
        data: {
          temporaryPassword: 'TempPass99A!',
          reminder: 'Hãy gửi mật khẩu tạm cho Coach qua kênh nội bộ và nhắc Coach đổi mật khẩu sau khi đăng nhập.',
        },
      }, 201);
    }

    throw new Error(`Unexpected request: ${options.method || 'GET'} ${path}`);
  };

  await renderAccountsPage({
    root: env.root,
    role,
    params,
    shell: (opts) => renderShell({ root: env.root, user: { fullName: 'Admin' }, ...opts }),
  });

  return { env, requests, getStatus: () => status };
}

test('Admin khóa tài khoản Member gửi lý do đã chuẩn hóa và hiển thị preview D4', async () => {
  const { env, requests, getStatus } = await setupAccounts({ role: 'MEMBER', initialStatus: 'ACTIVE' });
  env.root.querySelector('.toggle').click();
  await flush();

  assert.equal(requests.some((r) => r.path === '/api/v1/admin/users/member-test-id/lock-preview'), true);
  assert.equal(env.modalDialog.innerHTML.includes('Lê Hoàng Nam'), true);
  assert.equal(env.modalDialog.innerHTML.includes('3 buổi (KHÔNG trừ buổi)'), true);
  assert.equal(env.modalDialog.innerHTML.includes('1 hold'), true);
  assert.equal(env.modalDialog.innerHTML.includes('TIẾP TỤC CHẠY'), true);

  const textarea = env.modalDialog.querySelector('#meta-confirm-reason');
  const submit = env.modalDialog.querySelector('#meta-confirm-submit');
  assert.equal(submit.disabled, true);

  textarea.value = '  Vi phạm quy định  ';
  textarea.dispatchEvent({ type: 'input' });
  assert.equal(submit.disabled, false);

  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();

  const patches = requests.filter((r) => r.method === 'PATCH');
  assert.deepEqual(patches.map(({ path, method, body }) => ({ path, method, body })), [{
    path: '/api/v1/admin/users/member-test-id/status',
    method: 'PATCH',
    body: { status: 'DISABLED', reason: 'Vi phạm quy định' },
  }]);
  assert.equal(getStatus(), 'DISABLED');
});

test('Admin nhập lý do trống thì không gửi yêu cầu khóa', async () => {
  const { env, requests, getStatus } = await setupAccounts({ role: 'MEMBER', initialStatus: 'ACTIVE' });
  env.root.querySelector('.toggle').click();
  await flush();

  const textarea = env.modalDialog.querySelector('#meta-confirm-reason');
  textarea.value = '   ';
  textarea.dispatchEvent({ type: 'input' });
  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(requests.some((r) => r.method === 'PATCH'), false);
  assert.equal(getStatus(), 'ACTIVE');
});

test('Admin đóng modal khóa thì không gửi yêu cầu khóa', async () => {
  const { env, requests } = await setupAccounts({ role: 'MEMBER', initialStatus: 'ACTIVE' });
  env.root.querySelector('.toggle').click();
  await flush();

  env.modalDialog.querySelector('[data-close-modal]').click();
  await flush();
  assert.equal(requests.some((r) => r.method === 'PATCH'), false);
});

test('Admin nhập lý do quá 500 ký tự thì không gửi yêu cầu khóa', async () => {
  const { env, requests } = await setupAccounts({ role: 'MEMBER', initialStatus: 'ACTIVE' });
  env.root.querySelector('.toggle').click();
  await flush();

  const textarea = env.modalDialog.querySelector('#meta-confirm-reason');
  textarea.value = 'x'.repeat(501);
  textarea.dispatchEvent({ type: 'input' });
  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(requests.some((r) => r.method === 'PATCH'), false);
});

test('Admin mở khóa Member (D4) không yêu cầu hoặc gửi lý do khóa và hiển thị effects summary', async () => {
  const { env, requests, getStatus } = await setupAccounts({ role: 'MEMBER', initialStatus: 'DISABLED' });
  env.root.querySelector('.toggle').click();
  await flush();

  assert.equal(env.modalDialog.querySelector('#meta-confirm-reason'), null, 'Unlock modal must not require lock reason');
  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();

  const patches = requests.filter((r) => r.method === 'PATCH');
  assert.deepEqual(patches.map(({ path, method, body }) => ({ path, method, body })), [{
    path: '/api/v1/admin/users/member-test-id/status',
    method: 'PATCH',
    body: { status: 'ACTIVE' },
  }]);
  assert.equal(getStatus(), 'ACTIVE');
  assert.equal(env.root.querySelector('#notice').innerHTML.includes('PAUSED (MEMBERSHIP_EXPIRED)'), true);
});

test('T9 Lock Coach calls lock-preview showing affected Members + D1 freeze rules; Unlock Coach renders D1 auto-restore effects', async () => {
  const { env, requests } = await setupAccounts({ role: 'COACH', initialStatus: 'ACTIVE' });

  // Lock Coach flow
  env.root.querySelector('.toggle').click();
  await flush();

  assert.equal(requests.some((r) => r.path === '/api/v1/admin/users/coach-1/lock-preview'), true);
  assert.equal(env.modalDialog.innerHTML.includes('Trần Thu Hà'), true);
  assert.equal(env.modalDialog.innerHTML.includes('Lê Quang Huy'), true);
  assert.equal(env.modalDialog.innerHTML.includes('4 buổi (KHÔNG trừ buổi)'), true);
  assert.equal(env.modalDialog.innerHTML.includes('2 hold'), true);
  assert.equal(env.modalDialog.innerHTML.includes('Đóng băng gói Coach (D1)'), true);

  const textarea = env.modalDialog.querySelector('#meta-confirm-reason');
  textarea.value = 'Coach nghỉ phép dài ngày';
  textarea.dispatchEvent({ type: 'input' });
  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();

  // Now Coach is DISABLED -> click Unlock (D1)
  env.root.querySelector('.toggle').click();
  await flush();
  assert.equal(env.modalDialog.innerHTML.includes('D1'), true);
  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(env.root.querySelector('#notice').innerHTML.includes('Trần Thu Hà (+4 ngày'), true);
});

test('T9 Coach list shows usedSlots/8 hard cap, NO raw UUID in table, NO memberLimit edit, and Create Coach preserves input on 409', async () => {
  const { env, requests } = await setupAccounts({
    role: 'COACH',
    initialStatus: 'ACTIVE',
    createCoachError: { status: 409, code: 'EMAIL_ALREADY_EXISTS', message: 'Email đã được sử dụng' },
  });

  const tableHtml = env.root.querySelector('table').innerHTML;
  assert.equal(tableHtml.includes('<th>Giới hạn</th>'), false);
  assert.equal(tableHtml.includes('5 / 8 suất'), true);
  assert.equal(tableHtml.includes('coach-1'), true); // data-id attribute only, not raw UUID text cell
  assert.equal(tableHtml.includes('>coach-1<'), false);

  // Edit Coach sends ONLY fullName & phone (never memberLimit)
  env.root.querySelector('.edit').click();
  await flush();
  assert.equal(env.modalDialog.innerHTML.includes('name="memberLimit"'), false);
  env.modalDialog.querySelector('[name="fullName"]').value = 'Coach Mới';
  env.modalDialog.querySelector('[name="phone"]').value = '0901234567';
  env.modalDialog.querySelector('#account-form').dispatchEvent({ type: 'submit' });
  await flush();
  const patch = requests.find((r) => r.method === 'PATCH');
  assert.deepEqual(patch.body, { fullName: 'Coach Mới', phone: '0901234567' });

  // Create Coach modal: NO memberLimit field, preserves input on 409 error
  env.root.querySelector('#create').click();
  await flush();
  assert.equal(env.modalDialog.innerHTML.includes('name="memberLimit"'), false);
  env.modalDialog.querySelector('[name="fullName"]').value = 'Võ Thành Đạt';
  env.modalDialog.querySelector('[name="email"]').value = 'dat@metagym.vn';
  env.modalDialog.querySelector('[name="password"]').value = 'StrongPass1';
  env.modalDialog.querySelector('#create-coach-form').dispatchEvent({ type: 'submit' });
  await flush();

  const post = requests.find((r) => r.method === 'POST' && r.path === '/api/v1/admin/coaches');
  assert.deepEqual(post.body, { email: 'dat@metagym.vn', fullName: 'Võ Thành Đạt', password: 'StrongPass1' });
  assert.equal(env.modalOverlay.hidden, false, 'Modal stays open on 409 error');
  assert.equal(env.modalDialog.querySelector('[name="email"]').value, 'dat@metagym.vn', 'Preserves entered email on 409');
  assert.equal(env.modalDialog.innerHTML.includes('Email đã được sử dụng'), true);
});

test('T9 Operational Detail Drawer shows operating metrics + audit history and ZERO private health fields', async () => {
  const { env, requests } = await setupAccounts({ role: 'MEMBER', initialStatus: 'ACTIVE' });

  env.root.querySelector('.detail').click();
  await flush();

  assert.equal(requests.some((r) => r.path === '/api/v1/admin/users/member-test-id'), true);
  assert.equal(env.drawerOverlay.hidden, false);
  const drawerHtml = env.drawerPanel.innerHTML;
  assert.equal(drawerHtml.includes('member-test-id'), true, 'UUID appears inside Detail Drawer');
  assert.equal(drawerHtml.includes('Gói Gym 90 ngày'), true);
  assert.equal(drawerHtml.includes('Lê Hoàng Nam'), true);
  assert.equal(drawerHtml.includes('Khóa tài khoản do vi phạm'), true);
  assert.equal(drawerHtml.includes('SECRET_HEALTH_NOTE'), false, 'Private healthNotes MUST NEVER render');
  assert.equal(drawerHtml.includes('SECRET_INJURY_NOTE'), false, 'Private injuryNotes MUST NEVER render');
});

test('T9 Temporary Password modal calls POST /admin/coaches/:id/password-resets and shows one-time password + reminder', async () => {
  const { env, requests } = await setupAccounts({ role: 'COACH', initialStatus: 'ACTIVE' });

  env.root.querySelector('.reset').click();
  await flush();
  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(requests.some((r) => r.path === '/api/v1/admin/coaches/coach-1/password-resets' && r.method === 'POST'), true);
  assert.equal(env.modalOverlay.hidden, false, 'One-time password reveal modal remains open');
  assert.equal(env.modalDialog.innerHTML.includes('TempPass99A!'), true);
  assert.equal(env.modalDialog.innerHTML.includes('Sao chép'), true);
  assert.equal(env.modalDialog.innerHTML.includes('đổi mật khẩu'), true);
});

test('T9 Search & status filter update hash URL and trigger filtered GET /admin/users request', async () => {
  const { env, requests } = await setupAccounts({ role: 'MEMBER', initialStatus: 'ACTIVE' });

  const statusSel = env.root.querySelector('#acc-status');
  statusSel.value = 'DISABLED';
  statusSel.dispatchEvent({ type: 'change' });
  await flush();

  const lastGet = [...requests].reverse().find((r) => r.path === '/api/v1/admin/users');
  assert.equal(lastGet.search.includes('status=DISABLED'), true);
  assert.equal(env.location.hash.includes('status=DISABLED'), true);
  assert.equal(env.root.innerHTML.includes('Không tìm thấy kết quả khớp bộ lọc'), true);
});

test('Admin dashboard không hiển thị thẻ Yêu cầu chọn Coach', async () => {
  const env = createDomEnvironment({ hash: '#/admin/dashboard', token: 'test-admin-token' });
  setToken('test-admin-token');

  globalThis.fetch = async () => jsonResponse({
    data: {
      from: '2026-11-01',
      to: '2026-11-17',
      members: { active: 10, disabled: 0 },
      coaches: { active: 3, disabled: 0 },
      activeMemberships: 8,
      pendingCoachRequests: 4,
      pendingTerminationRequests: 1,
      revenue: { amount: '5000000', byDay: [] },
    },
  });

  await renderDashboardPage({
    root: env.root,
    params: new URLSearchParams(),
    shell: (opts) => renderShell({ root: env.root, user: { fullName: 'Admin' }, ...opts }),
    ChartCtor: class { destroy() {} },
  });

  assert.equal(env.root.innerHTML.includes('Yêu cầu chọn Coach'), false);
  assert.equal(env.root.innerHTML.includes('Gói Gym đang sử dụng'), true);
});
