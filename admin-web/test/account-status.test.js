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

test('Member Edit Modal validates fullName/email/phone inline, blocks unchanged submit, and sends PATCH with normalized fields', async () => {
  const { env, requests } = await setupAccounts({ role: 'MEMBER', initialStatus: 'ACTIVE' });

  env.root.querySelector('.edit').click();
  await flush();

  const dlg = env.modalDialog;
  assert.equal(dlg.innerHTML.includes('name="memberLimit"'), false);
  assert.equal(dlg.innerHTML.includes('healthNotes'), false);

  const nameInput = dlg.querySelector('[name="fullName"]');
  const emailInput = dlg.querySelector('[name="email"]');
  const phoneInput = dlg.querySelector('[name="phone"]');
  const form = dlg.querySelector('#account-form');

  assert.equal(nameInput.value, 'Member Test');
  assert.equal(emailInput.value, 'member@test.local');
  assert.equal(phoneInput.value, '0900000000');

  // Unchanged submit does not send PATCH
  form.dispatchEvent({ type: 'submit' });
  await flush();
  assert.equal(requests.some((r) => r.method === 'PATCH'), false);
  assert.equal(dlg.innerHTML.includes('Chưa có thay đổi nào để lưu'), true);

  // Invalid email & phone show inline errors and block PATCH
  emailInput.value = 'invalid-email';
  phoneInput.value = '1234';
  form.dispatchEvent({ type: 'submit' });
  await flush();
  assert.equal(requests.some((r) => r.method === 'PATCH'), false);
  assert.equal(dlg.querySelector('#edit-email-error').textContent.includes('không hợp lệ'), true);
  assert.equal(dlg.querySelector('#edit-phone-error').textContent.includes('8–15 chữ số'), true);
  assert.equal(emailInput.getAttribute('aria-invalid'), 'true');
  assert.equal(phoneInput.getAttribute('aria-invalid'), 'true');

  // Input event clears inline error
  emailInput.value = '  Member.Updated@Test.Local ';
  emailInput.dispatchEvent({ type: 'input' });
  assert.equal(dlg.querySelector('#edit-email-error').textContent, '');
  assert.equal(emailInput.getAttribute('aria-invalid'), null);

  // Valid update clearing phone to null
  nameInput.value = '  Nguyễn Minh Anh  ';
  phoneInput.value = '   ';
  form.dispatchEvent({ type: 'submit' });
  await flush();

  const patch = requests.find((r) => r.method === 'PATCH' && r.path === '/api/v1/admin/users/member-test-id');
  assert.ok(patch);
  assert.deepEqual(patch.body, {
    fullName: 'Nguyễn Minh Anh',
    email: 'member.updated@test.local',
    phone: null,
  });
  assert.equal(env.modalOverlay.hidden, true);
});

test('Member Edit Modal preserves inputs and displays inline email error on 409 EMAIL_ALREADY_EXISTS', async () => {
  const env = createDomEnvironment({ hash: '#/admin/members', token: 'test-admin-token' });
  setToken('test-admin-token');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Admin' });

  let member = {
    id: 'member-409',
    fullName: 'Lê Thị Hoa',
    email: 'hoa@metagym.vn',
    phone: '0901234567',
    role: 'MEMBER',
    status: 'ACTIVE',
  };
  let failOnce = true;

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    const body = options.body ? JSON.parse(options.body) : undefined;
    if (parsed.pathname === '/api/v1/admin/users' && (!options.method || options.method === 'GET')) {
      return jsonResponse({ data: [member], pagination: { page: 1, pageSize: 10, totalItems: 1, totalPages: 1 } });
    }
    if (parsed.pathname === '/api/v1/admin/users/member-409' && options.method === 'PATCH') {
      if (failOnce) {
        failOnce = false;
        return jsonResponse({
          error: {
            code: 'EMAIL_ALREADY_EXISTS',
            message: 'Email đã được sử dụng',
            details: { fields: { email: ['Email này đã tồn tại trên hệ thống'] } },
          },
        }, 409);
      }
      member = { ...member, ...body };
      return jsonResponse({ data: member });
    }
    throw new Error(`Unexpected ${options.method || 'GET'} ${parsed.pathname}`);
  };

  await renderAccountsPage({
    root: env.root,
    role: 'MEMBER',
    params: new URLSearchParams(),
    shell: (opts) => renderShell({ root: env.root, user: { fullName: 'Admin' }, ...opts }),
  });

  env.root.querySelector('.edit').click();
  await flush();

  const emailInput = env.modalDialog.querySelector('[name="email"]');
  const phoneInput = env.modalDialog.querySelector('[name="phone"]');
  emailInput.value = 'taken@metagym.vn';
  phoneInput.value = '+84 912 345 678';
  env.modalDialog.querySelector('#account-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(env.modalOverlay.hidden, false, 'Modal must stay open on 409');
  assert.equal(emailInput.value, 'taken@metagym.vn', 'Preserves email on 409');
  assert.equal(phoneInput.value, '+84 912 345 678', 'Preserves phone on 409');
  assert.equal(env.modalDialog.querySelector('#edit-email-error').textContent, 'Email này đã tồn tại trên hệ thống');
  assert.equal(env.modalDialog.innerHTML.includes('Email đã được sử dụng'), true);

  emailInput.value = 'hoa.new@metagym.vn';
  env.modalDialog.querySelector('#account-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(env.modalOverlay.hidden, true);
  assert.equal(env.root.innerHTML.includes('hoa.new@metagym.vn'), true);
});

test('Member Edit Modal supports Avatar removal and editing full member_profiles DB fields with T18 privacy guard', async () => {
  const env = createDomEnvironment({ hash: '#/admin/members', token: 'test-admin-token' });
  setToken('test-admin-token');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Admin' });

  const member = {
    id: 'member-full-db',
    fullName: 'Hoàng Thùy Linh',
    email: 'linh@metagym.vn',
    phone: '0909888999',
    avatarMediaId: 'media-avatar-111',
    avatarUrl: '/api/v1/users/member-full-db/avatar',
    role: 'MEMBER',
    status: 'ACTIVE',
    dateOfBirth: '1998-12-25',
    gender: 'FEMALE',
    heightCm: 165,
    fitnessGoal: 'Giữ dáng và tăng thể lực',
    experienceLevel: 'BEGINNER',
    activityLevel: 'MODERATE',
    dietaryPreferences: 'Ăn ít tinh bột',
  };

  let patchSent = null;

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    const body = options.body ? JSON.parse(options.body) : undefined;
    if (parsed.pathname === '/api/v1/admin/users' && (!options.method || options.method === 'GET')) {
      return jsonResponse({ data: [member], pagination: { page: 1, pageSize: 10, totalItems: 1, totalPages: 1 } });
    }
    if (parsed.pathname === '/api/v1/admin/users/member-full-db' && options.method === 'PATCH') {
      patchSent = body;
      return jsonResponse({ data: { ...member, ...body } });
    }
    throw new Error(`Unexpected ${options.method || 'GET'} ${parsed.pathname}`);
  };

  await renderAccountsPage({
    root: env.root,
    role: 'MEMBER',
    params: new URLSearchParams(),
    shell: (opts) => renderShell({ root: env.root, user: { fullName: 'Admin' }, ...opts }),
  });

  // Table displays real avatar image
  assert.equal(env.root.innerHTML.includes('/api/v1/users/member-full-db/avatar'), true);

  env.root.querySelector('.edit').click();
  await flush();

  const dlg = env.modalDialog;
  // T18 Privacy compliance: NO health or injury notes anywhere
  assert.equal(dlg.innerHTML.includes('healthNotes'), false);
  assert.equal(dlg.innerHTML.includes('injuryNotes'), false);

  // Avatar UI elements
  const removeAvatarBtn = dlg.querySelector('#btn-remove-avatar');
  const pickAvatarBtn = dlg.querySelector('#btn-pick-avatar');
  assert.ok(removeAvatarBtn);
  assert.ok(pickAvatarBtn);
  assert.equal(removeAvatarBtn.style.display !== 'none', true);

  // Profile fields exist and are populated
  const genderInput = dlg.querySelector('[name="gender"]');
  const dobInput = dlg.querySelector('[name="dateOfBirth"]');
  const heightInput = dlg.querySelector('[name="heightCm"]');
  const goalInput = dlg.querySelector('[name="fitnessGoal"]');
  const expInput = dlg.querySelector('[name="experienceLevel"]');
  const actInput = dlg.querySelector('[name="activityLevel"]');
  const dietInput = dlg.querySelector('[name="dietaryPreferences"]');

  assert.equal(genderInput.value, 'FEMALE');
  assert.equal(dobInput.value, '1998-12-25');
  assert.equal(heightInput.value, '165');
  assert.equal(goalInput.value, 'Giữ dáng và tăng thể lực');
  assert.equal(expInput.value, 'BEGINNER');
  assert.equal(actInput.value, 'MODERATE');
  assert.equal(dietInput.value, 'Ăn ít tinh bột');

  // Trigger avatar removal
  removeAvatarBtn.click();
  assert.equal(removeAvatarBtn.style.display, 'none');

  // Mutate profile fields
  heightInput.value = '167';
  goalInput.value = 'Tăng cơ toàn diện và chạy 10km';
  expInput.value = 'INTERMEDIATE';

  // Submit modal
  dlg.querySelector('#account-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.ok(patchSent, 'PATCH request must be sent');
  assert.equal(patchSent.avatarMediaId, null, 'Must request removal of avatarMediaId');
  assert.equal(patchSent.heightCm, 167);
  assert.equal(patchSent.fitnessGoal, 'Tăng cơ toàn diện và chạy 10km');
  assert.equal(patchSent.experienceLevel, 'INTERMEDIATE');
  assert.equal(env.modalOverlay.hidden, true);
});

test('Member Edit Modal uploads avatar file via uploadRaw and saves successfully', async () => {
  const env = createDomEnvironment({ hash: '#/admin/members', token: 'test-admin-token' });
  setToken('test-admin-token');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Admin' });

  const member = {
    id: 'member-upload-avatar',
    fullName: 'Nguyễn Trung Hậu',
    email: 'nthau.22022006@gmail.com',
    phone: '0901234567',
    avatarMediaId: null,
    avatarUrl: null,
    role: 'MEMBER',
    status: 'ACTIVE',
    profile: {
      dateOfBirth: '2000-02-22',
      gender: 'MALE',
      heightCm: 170,
      fitnessGoal: 'Giảm mỡ',
      experienceLevel: 'BEGINNER',
      activityLevel: 'LIGHT',
      dietaryPreferences: 'Eat clean',
    },
  };

  let avatarUploaded = false;

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    if (parsed.pathname === '/api/v1/admin/users' && (!options.method || options.method === 'GET')) {
      return jsonResponse({ data: [member], pagination: { page: 1, pageSize: 10, totalItems: 1, totalPages: 1 } });
    }
    if (parsed.pathname === '/api/v1/admin/users/member-upload-avatar/avatar' && options.method === 'POST') {
      avatarUploaded = true;
      assert.equal(options.headers?.Authorization, 'Bearer test-admin-token');
      return jsonResponse({ data: { ...member, avatarMediaId: 'new-media-id-123' } });
    }
    if (parsed.pathname === '/api/v1/admin/users/member-upload-avatar' && options.method === 'PATCH') {
      let body;
      try { body = typeof options.body === 'string' ? JSON.parse(options.body) : options.body; } catch {}
      return jsonResponse({ data: { ...member, ...body } });
    }
    throw new Error(`Unexpected ${options.method || 'GET'} ${parsed.pathname}`);
  };

  await renderAccountsPage({
    root: env.root,
    role: 'MEMBER',
    params: new URLSearchParams(),
    shell: (opts) => renderShell({ root: env.root, user: { fullName: 'Admin' }, ...opts }),
  });
  await flush();

  env.root.querySelector('.edit').click();
  await flush();

  const dlg = env.modalDialog;
  const fileInput = dlg.querySelector('#edit-avatar-file');
  assert.ok(fileInput);

  // Simulate file selection
  const fakeFile = new Blob(['fake-image-bytes'], { type: 'image/jpeg' });
  fakeFile.name = 'avatar.jpg';
  fileInput.dispatchEvent({ type: 'change', target: { files: [fakeFile] } });
  await flush();

  // Confirm crop in the cropper modal
  const cropperApplyBtn = env.document.querySelector('[data-cropper-apply]');
  assert.ok(cropperApplyBtn, 'Cropper modal Apply button must exist');
  cropperApplyBtn.click();
  await flush();

  // Submit modal form
  dlg.querySelector('#account-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(avatarUploaded, true, 'Avatar file must be uploaded to server');
  assert.equal(env.modalOverlay.hidden, true, 'Modal should be closed on success');
});

test('Member Edit Modal renders compact avatar dropdown button, toggles menu, and opens Image Viewer on demand', async () => {
  const env = createDomEnvironment({ hash: '#/admin/members', token: 'test-admin-token' });
  setToken('test-admin-token');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Admin' });

  const member = {
    id: 'member-view-avatar',
    fullName: 'Nguyễn Trung Hậu',
    email: 'nthau.22022006@gmail.com',
    phone: '0901234567',
    avatarMediaId: 'media-avatar-999',
    avatarUrl: '/api/v1/users/member-view-avatar/avatar',
    role: 'MEMBER',
    status: 'ACTIVE',
    profile: {
      dateOfBirth: '2000-02-22',
      gender: 'MALE',
      heightCm: 170,
      fitnessGoal: 'Giảm mỡ',
      experienceLevel: 'BEGINNER',
      activityLevel: 'LIGHT',
      dietaryPreferences: 'Eat clean',
    },
  };

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    if (parsed.pathname === '/api/v1/admin/users' && (!options.method || options.method === 'GET')) {
      return jsonResponse({ data: [member], pagination: { page: 1, pageSize: 10, totalItems: 1, totalPages: 1 } });
    }
    throw new Error(`Unexpected ${options.method || 'GET'} ${parsed.pathname}`);
  };

  await renderAccountsPage({
    root: env.root,
    role: 'MEMBER',
    params: new URLSearchParams(),
    shell: (opts) => renderShell({ root: env.root, user: { fullName: 'Admin' }, ...opts }),
  });
  await flush();

  // 1. Table row avatar has data-view-avatar and clicking opens Image Viewer
  const tableAvatar = env.root.querySelector('[data-view-avatar]');
  assert.ok(tableAvatar, 'Table avatar should have data-view-avatar');
  tableAvatar.click();
  await flush();

  let viewerOverlay = env.document.getElementById('meta-image-viewer-overlay');
  assert.ok(viewerOverlay, 'Image Viewer overlay should exist in DOM');
  assert.equal(viewerOverlay.hidden, false, 'Viewer overlay should be visible');
  assert.equal(viewerOverlay.innerHTML.includes('Nguyễn Trung Hậu'), true);

  // Close viewer
  viewerOverlay.querySelector('[data-viewer-close]').click();
  assert.equal(viewerOverlay.hidden, true, 'Viewer overlay should be hidden on close');

  // 2. Open Member Edit Modal
  env.root.querySelector('.edit').click();
  await flush();

  const dlg = env.modalDialog;

  // Single collapsed dropdown button exists
  const dropdownBtn = dlg.querySelector('#btn-avatar-dropdown');
  const dropdownMenu = dlg.querySelector('#avatar-dropdown-menu');
  assert.ok(dropdownBtn, 'Compact avatar dropdown button must exist');
  assert.ok(dropdownMenu, 'Avatar dropdown menu must exist');
  assert.equal(dropdownMenu.hidden, true, 'Dropdown menu should be initially hidden');
  assert.equal(dropdownBtn.getAttribute('aria-expanded'), 'false');

  // Click dropdown button to toggle open
  dropdownBtn.click();
  assert.equal(dropdownMenu.hidden, false, 'Dropdown menu should be open');
  assert.equal(dropdownBtn.getAttribute('aria-expanded'), 'true');

  // All actions are grouped into this dropdown menu
  const viewItem = dlg.querySelector('#btn-view-avatar');
  const pickItem = dlg.querySelector('#btn-pick-avatar');
  const cropItem = dlg.querySelector('#btn-crop-avatar');
  const removeItem = dlg.querySelector('#btn-remove-avatar');

  assert.ok(viewItem, 'View avatar item must exist in menu');
  assert.ok(pickItem, 'Upload avatar item must exist in menu');
  assert.ok(cropItem, 'Crop avatar item must exist in menu');
  assert.ok(removeItem, 'Remove avatar item must exist in menu');

  // Clicking "Xem ảnh phóng to" inside menu opens Image Viewer
  viewItem.click();
  await flush();

  assert.equal(dropdownMenu.hidden, true, 'Dropdown menu should close after action click');
  viewerOverlay = env.document.getElementById('meta-image-viewer-overlay');
  assert.equal(viewerOverlay.hidden, false, 'Viewer overlay should be opened from dropdown menu');
  assert.equal(viewerOverlay.innerHTML.includes('/api/v1/users/member-view-avatar/avatar'), true);

  // Close viewer
  viewerOverlay.querySelector('[data-viewer-close]').click();
  assert.equal(viewerOverlay.hidden, true);

  // Clicking the avatar preview circle directly also opens Image Viewer
  const previewWrap = dlg.querySelector('#avatar-preview-wrap');
  assert.ok(previewWrap);
  previewWrap.click();
  await flush();
  assert.equal(viewerOverlay.hidden, false, 'Direct avatar preview click should open Image Viewer');
  viewerOverlay.querySelector('[data-viewer-close]').click();
});

test('Coach Edit Modal updates avatar removal, email, phone, and coach_profiles fields without memberLimit input', async () => {
  const env = createDomEnvironment({ hash: '#/admin/coaches', token: 'test-admin-token' });
  setToken('test-admin-token');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Admin' });

  const coach = {
    id: 'coach-edit-1',
    fullName: 'Lê Hoàng Nam',
    email: 'nam.coach@metagym.vn',
    phone: '0912345678',
    avatarMediaId: 'coach-av-1',
    avatarUrl: '/api/v1/users/coach-edit-1/avatar',
    role: 'COACH',
    status: 'ACTIVE',
    usedSlots: 3,
    memberLimit: 8,
    experienceYears: 4,
    qualifications: 'PT Quốc gia',
    specialties: ['Tăng cơ'],
    availabilityNote: 'Thứ 2 – Thứ 6',
    biography: 'HLV cá nhân.',
  };

  let patchSent = null;
  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    if (parsed.pathname === '/api/v1/admin/users' && (!options.method || options.method === 'GET')) {
      return jsonResponse({ data: [coach], pagination: { page: 1, pageSize: 10, totalItems: 1, totalPages: 1 } });
    }
    if (parsed.pathname === '/api/v1/admin/users/coach-edit-1' && options.method === 'PATCH') {
      patchSent = JSON.parse(options.body);
      Object.assign(coach, patchSent);
      if (patchSent.avatarMediaId === null) coach.avatarUrl = null;
      return jsonResponse({ data: coach });
    }
    throw new Error(`Unexpected ${options.method || 'GET'} ${parsed.pathname}`);
  };

  await renderAccountsPage({
    root: env.root,
    role: 'COACH',
    params: new URLSearchParams(),
    shell: (opts) => renderShell({ root: env.root, user: { fullName: 'Admin' }, ...opts }),
  });

  env.root.querySelector('.edit').click();
  await flush();

  const dlg = env.modalDialog;
  assert.equal(dlg.querySelector('[name="memberLimit"]'), null, 'Coach edit modal must NEVER expose editable memberLimit');
  assert.equal(dlg.innerHTML.includes('Cập nhật Huấn luyện viên: Lê Hoàng Nam'), true);

  dlg.querySelector('#btn-remove-avatar').click();
  dlg.querySelector('[name="fullName"]').value = 'Lê Hoàng Nam Pro';
  dlg.querySelector('[name="email"]').value = 'nam.pro@metagym.vn';
  dlg.querySelector('[name="phone"]').value = '0987654321';
  dlg.querySelector('[name="experienceYears"]').value = '6';
  dlg.querySelector('[name="qualifications"]').value = 'NASM-CPT, Rehab Specialist';
  dlg.querySelector('[name="specialties"]').value = 'Tăng cơ, Giảm mỡ, Calisthenics';
  dlg.querySelector('[name="availabilityNote"]').value = 'Thứ 2 – Thứ 7 · 06:00 – 21:00';
  dlg.querySelector('[name="biography"]').value = '6 năm huấn luyện vận động viên và thể hình.';

  dlg.querySelector('#account-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.deepEqual(patchSent, {
    fullName: 'Lê Hoàng Nam Pro',
    email: 'nam.pro@metagym.vn',
    phone: '0987654321',
    avatarMediaId: null,
    experienceYears: 6,
    qualifications: 'NASM-CPT, Rehab Specialist',
    specialties: ['Tăng cơ', 'Giảm mỡ', 'Calisthenics'],
    availabilityNote: 'Thứ 2 – Thứ 7 · 06:00 – 21:00',
    biography: '6 năm huấn luyện vận động viên và thể hình.',
  });
  assert.equal(env.modalOverlay.hidden, true);
});
