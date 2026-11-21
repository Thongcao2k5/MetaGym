import assert from 'node:assert/strict';
import test from 'node:test';

import { createDomEnvironment, flush, jsonResponse } from './helpers/dom-harness.js';
import { setCurrentUser, setToken } from '../src/services/api.js';
import { renderShell } from '../src/components/layout.js';
import { closeModal } from '../src/components/modal.js';
import { closeDrawer } from '../src/components/drawer.js';
import { renderIncidentsPage } from '../src/pages/incidents.js';
import { renderRelationshipsPage } from '../src/pages/relationships.js';
import { renderDashboardPage } from '../src/pages/dashboard.js';

function makeShell(env) {
  return (opts) => renderShell({
    root: env.root,
    user: { id: 'adm-1', role: 'ADMIN', fullName: 'Meta Admin', email: 'admin@metagym.vn' },
    ...opts,
  });
}

test('T13 Incidents tab displays frozenDaysCurrent, ACTIVE+QUEUED packages, zero raw UUIDs, and D2 eligible-coaches transfer with Idempotency-Key retry/rotation', async () => {
  const env = createDomEnvironment({ hash: '#/admin/incidents', token: 'tok' });
  setToken('tok');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Meta Admin', email: 'admin@metagym.vn' });

  const incidentId = '11111111-1111-4111-8111-111111111111';
  const coachOk1 = '22222222-2222-4222-8222-222222222221';
  const coachOk2 = '22222222-2222-4222-8222-222222222222';
  const coachFull = '22222222-2222-4222-8222-222222222223';
  const coachNoSched = '22222222-2222-4222-8222-222222222224';
  const coachCap = '22222222-2222-4222-8222-222222222225';

  const transferRequests = [];
  let failFirstTransfer = true;

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    if (parsed.pathname === '/api/v1/admin/coach-incidents') {
      return jsonResponse({
        data: [{
          id: incidentId,
          coachId: 'c-old-uuid',
          coachName: 'Coach Nguyễn Quân',
          memberId: 'm-1-uuid',
          memberName: 'Trần Thu Hà',
          memberEmail: 'ha@metagym.vn',
          relationshipId: 'rel-1-uuid',
          lockReason: 'Nghỉ phép đột xuất',
          lockedAt: '2026-11-17T03:00:00.000Z',
          frozenDaysCurrent: 4,
          memberChoice: 'WAIT',
          status: 'OPEN',
          memberGymMembershipStatus: 'ACTIVE',
          activeEntitlement: {
            id: 'ent-a-1',
            planCode: 'ADV_30',
            planName: 'Nâng cao 30 buổi',
            snapshotPrice: 5000000,
            totalSessions: 30,
            remainingSessions: 11,
          },
          queuedEntitlement: {
            id: 'ent-q-1',
            planCode: 'BASIC_10',
            planName: 'Cơ bản 10 buổi',
            snapshotPrice: 1950000,
            totalSessions: 10,
            remainingSessions: 10,
          },
          estimatedActiveRefund: 1833000,
          estimatedQueuedRefund: 1950000,
          estimatedTotalRefund: 3783000,
        }],
        pagination: { page: 1, pageSize: 10, totalItems: 1, totalPages: 1 },
      });
    }
    if (parsed.pathname === `/api/v1/admin/coach-incidents/${incidentId}/eligible-coaches`) {
      return jsonResponse({
        data: [
          { id: coachOk1, fullName: 'Coach Lê Bảo', email: 'bao@metagym.vn', usedSlots: 3, memberLimit: 8, eligible: true, ineligibleReason: null },
          { id: coachOk2, fullName: 'Coach Phạm Dũng', email: 'dung@metagym.vn', usedSlots: 5, memberLimit: 8, eligible: true, ineligibleReason: null },
          { id: coachFull, fullName: 'Coach Đầy Suất', email: 'full@metagym.vn', usedSlots: 8, memberLimit: 8, eligible: false, ineligibleReason: 'COACH_FULL' },
          { id: coachNoSched, fullName: 'Coach Chưa Lịch', email: 'nosched@metagym.vn', usedSlots: 2, memberLimit: 8, eligible: false, ineligibleReason: 'SCHEDULE_REQUIRED' },
          { id: coachCap, fullName: 'Coach Hết Công Suất', email: 'cap@metagym.vn', usedSlots: 4, memberLimit: 8, eligible: false, ineligibleReason: 'CAPACITY_UNAVAILABLE' },
        ],
      });
    }
    if (parsed.pathname === `/api/v1/admin/coach-incidents/${incidentId}/transfer` && options.method === 'POST') {
      transferRequests.push({
        body: JSON.parse(options.body),
        idempotencyKey: options.headers['Idempotency-Key'] || options.headers['idempotency-key'],
      });
      if (failFirstTransfer) {
        failFirstTransfer = false;
        return jsonResponse({ error: { code: 'INTERNAL_SERVER_ERROR', message: 'Lỗi mạng tạm thời' } }, 500);
      }
      return jsonResponse({ data: { transferId: 'trf-1', frozenDaysAdded: 4, incidentStatus: 'RESOLVED_TRANSFERRED' } }, 201);
    }
    throw new Error(`Unexpected ${options.method || 'GET'} ${parsed.pathname}`);
  };

  await renderIncidentsPage({ root: env.root, params: new URLSearchParams(), shell: makeShell(env) });

  const tableEl = env.root.querySelector('table');
  const tableHtml = tableEl?.innerHTML || '';
  const tableText = tableEl?.textContent || '';
  assert.equal(tableHtml.includes('Trần Thu Hà'), true);
  assert.equal(tableHtml.includes('Coach Nguyễn Quân'), true);
  assert.equal(tableHtml.includes('4 ngày'), true, 'Must render frozenDaysCurrent (4 ngày)');
  assert.equal(tableHtml.includes('Nâng cao 30 buổi'), true);
  assert.equal(tableHtml.includes('Cơ bản 10 buổi'), true);
  assert.equal(tableHtml.includes('3.783.000'), true);
  assert.equal(tableText.includes(incidentId), false, 'Table visible text must not show raw incident UUID');
  assert.ok(env.root.querySelector('[data-select-all]'), 'Table must have selectable checkboxes');
  assert.ok(env.root.querySelector('#inc-page-size'), 'Pagination must have pageSize selector');

  // Open D2 transfer modal
  env.root.querySelector('.transfer-inc').click();
  await flush();

  const dlgHtml = env.modalDialog.innerHTML;
  assert.equal(dlgHtml.includes('Coach Lê Bảo'), true);
  assert.equal(dlgHtml.includes('3 / 8 suất'), true);
  assert.equal(dlgHtml.includes('COACH_FULL'), true);
  assert.equal(dlgHtml.includes('SCHEDULE_REQUIRED'), true);
  assert.equal(dlgHtml.includes('CAPACITY_UNAVAILABLE'), true);

  const fullRadio = env.modalDialog.querySelector(`input[value="${coachFull}"]`);
  assert.equal(fullRadio.disabled, true, 'Ineligible coach radio must be disabled');

  const okRadio1 = env.modalDialog.querySelector(`input[value="${coachOk1}"]`);
  const okRadio2 = env.modalDialog.querySelector(`input[value="${coachOk2}"]`);
  const reasonInput = env.modalDialog.querySelector('#inc-transfer-reason');
  const form = env.modalDialog.querySelector('#inc-transfer-form');

  // Select coach 1 & enter reason -> first submit fails with 500
  okRadio1.checked = true;
  okRadio1.dispatchEvent({ type: 'change' });
  reasonInput.value = 'Chuyển sang Coach Lê Bảo có lịch phù hợp';
  reasonInput.dispatchEvent({ type: 'input' });

  form.dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(transferRequests.length, 1);
  assert.equal(env.modalOverlay.hidden, false, 'Modal stays open on error');
  assert.equal(reasonInput.value, 'Chuyển sang Coach Lê Bảo có lịch phù hợp', 'Reason preserved on error');
  const keyFirstAttempt = transferRequests[0].idempotencyKey;
  assert.ok(keyFirstAttempt, 'Idempotency-Key must be sent');

  // Retry identical selection -> MUST preserve exact same Idempotency-Key
  form.dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(transferRequests.length, 2);
  assert.equal(transferRequests[1].idempotencyKey, keyFirstAttempt, 'Retry with identical selection must reuse Idempotency-Key');
  assert.equal(env.modalOverlay.hidden, true, 'Modal closes on success');

  // Re-open modal and verify selecting coach 2 rotates Idempotency-Key
  env.root.querySelector('.transfer-inc').click();
  await flush();
  const r1 = env.modalDialog.querySelector(`input[value="${coachOk1}"]`);
  const r2 = env.modalDialog.querySelector(`input[value="${coachOk2}"]`);
  r1.checked = true;
  r1.dispatchEvent({ type: 'change' });
  const keyCoach1 = env.modalDialog.querySelector('#inc-transfer-idem').textContent;
  r2.checked = true;
  r2.dispatchEvent({ type: 'change' });
  const keyCoach2 = env.modalDialog.querySelector('#inc-transfer-idem').textContent;
  assert.notEqual(keyCoach1, keyCoach2, 'Changing coach selection must rotate Idempotency-Key');

  closeModal();
});

test('T14 Simulated Refund modal shows ACTIVE + QUEUED breakdown, requires reason, sends Idempotency-Key, and Refunds history tab renders KPIs & human names', async () => {
  const env = createDomEnvironment({ hash: '#/admin/incidents', token: 'tok' });
  setToken('tok');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Meta Admin', email: 'admin@metagym.vn' });

  const incidentId = '33333333-3333-4333-8333-333333333333';
  const refundUuid = '44444444-4444-4444-8444-444444444444';
  const refundPosts = [];

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    if (parsed.pathname === '/api/v1/admin/coach-incidents') {
      return jsonResponse({
        data: [{
          id: incidentId,
          coachName: 'Coach A',
          memberName: 'Lê Minh Anh',
          lockedAt: '2026-11-18T03:00:00.000Z',
          frozenDaysCurrent: 3,
          memberChoice: 'REFUND',
          status: 'OPEN',
          activeEntitlement: { planName: 'Nâng cao', snapshotPrice: 5000000, totalSessions: 30, remainingSessions: 11 },
          queuedEntitlement: { planName: 'Cơ bản', snapshotPrice: 1950000, totalSessions: 10, remainingSessions: 10 },
          estimatedActiveRefund: 1833000,
          estimatedQueuedRefund: 1950000,
          estimatedTotalRefund: 3783000,
        }],
        pagination: { page: 1, pageSize: 10, totalItems: 1, totalPages: 1 },
      });
    }
    if (parsed.pathname === `/api/v1/admin/coach-incidents/${incidentId}/simulated-refunds` && options.method === 'POST') {
      refundPosts.push({
        body: JSON.parse(options.body),
        idempotencyKey: options.headers['Idempotency-Key'] || options.headers['idempotency-key'],
      });
      return jsonResponse({ data: { totalRefundAmount: 3783000, incidentStatus: 'RESOLVED_REFUNDED' } }, 201);
    }
    if (parsed.pathname === '/api/v1/admin/simulated-refunds') {
      return jsonResponse({
        data: [{
          id: refundUuid,
          refundBatchId: 'batch-1',
          incidentId,
          coachEntitlementId: 'ent-1',
          memberName: 'Lê Minh Anh',
          memberEmail: 'anh@metagym.vn',
          coachName: 'Coach A',
          entitlementKind: 'ACTIVE',
          planName: 'Nâng cao',
          snapshotPrice: 5000000,
          totalSessions: 30,
          remainingSessions: 11,
          refundAmount: 1833000,
          reason: 'Member chọn hoàn tiền mô phỏng',
          createdByName: 'Meta Admin',
          createdAt: '2026-11-21T07:00:00.000Z',
        }],
        summary: { totalRefundAmount: 3783000, count: 2 },
        pagination: { page: 1, pageSize: 10, totalItems: 2, totalPages: 1 },
      });
    }
    throw new Error(`Unexpected ${parsed.pathname}`);
  };

  await renderIncidentsPage({ root: env.root, params: new URLSearchParams(), shell: makeShell(env) });

  // Open D3 refund modal
  env.root.querySelector('.refund-inc').click();
  await flush();

  const modalHtml = env.modalDialog.innerHTML;
  assert.equal(modalHtml.includes('1.833.000'), true, 'Must display estimatedActiveRefund');
  assert.equal(modalHtml.includes('1.950.000'), true, 'Must display estimatedQueuedRefund');
  assert.equal(modalHtml.includes('3.783.000'), true, 'Must display estimatedTotalRefund');

  const submitBtn = env.modalDialog.querySelector('#meta-confirm-submit');
  assert.equal(submitBtn.disabled, true, 'Submit disabled until mandatory reason entered');

  const reasonEl = env.modalDialog.querySelector('#meta-confirm-reason');
  reasonEl.value = 'Member chọn nhận hoàn tiền mô phỏng D3';
  reasonEl.dispatchEvent({ type: 'input' });
  assert.equal(submitBtn.disabled, false);

  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(refundPosts.length, 1);
  assert.equal(refundPosts[0].body.reason, 'Member chọn nhận hoàn tiền mô phỏng D3');
  assert.ok(refundPosts[0].idempotencyKey, 'Simulated refund must send Idempotency-Key');

  // Switch to refunds history tab
  env.root.querySelector('[data-inc-tab="refunds"]').click();
  await flush();

  const pageHtml = env.root.innerHTML;
  assert.equal(pageHtml.includes('Tổng tiền hoàn mô phỏng'), true);
  assert.equal(pageHtml.includes('3.783.000'), true);
  const tableEl = env.root.querySelector('table');
  const tableHtml = tableEl?.innerHTML || '';
  const tableText = tableEl?.textContent || '';
  assert.equal(tableHtml.includes('Lê Minh Anh'), true);
  assert.equal(tableHtml.includes('Coach A'), true);
  assert.equal(tableText.includes(refundUuid), false, 'Refunds table visible text must not display raw UUID');

  // Detail drawer displays UUID
  env.root.querySelector('.detail-ref').click();
  assert.equal(env.drawerOverlay.hidden, false);
  assert.equal(env.drawerPanel.innerHTML.includes(refundUuid), true);

  closeModal();
  closeDrawer();
});

test('T12 Relationships D5 terminations tab shows 72h countdown, DISPUTED adjudication modal with mandatory reason, and List tab detail drawer without private health fields', async () => {
  const env = createDomEnvironment({ hash: '#/admin/relationships?tab=terminations', token: 'tok' });
  setToken('tok');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Meta Admin', email: 'admin@metagym.vn' });

  const termDisputedId = '55555555-5555-4555-8555-555555555551';
  const termPendingId = '55555555-5555-4555-8555-555555555552';
  const relId = '66666666-6666-4666-8666-666666666661';
  const fetchedUrls = [];
  const patchCalls = [];

  globalThis.fetch = async (url, options = {}) => {
    const parsed = new URL(url, 'http://localhost');
    fetchedUrls.push(`${options.method || 'GET'} ${parsed.pathname}${parsed.search}`);

    if (parsed.pathname === '/api/v1/admin/termination-requests') {
      const futureDeadline = new Date(Date.now() + 25 * 3600 * 1000).toISOString();
      return jsonResponse({
        data: [
          {
            id: termDisputedId,
            relationshipId: relId,
            memberName: 'Nguyễn Thảo Vy',
            coachName: 'Coach Hoàng Long',
            requestedByRole: 'MEMBER',
            requestedByName: 'Nguyễn Thảo Vy',
            reason: 'Đổi lịch công tác không thể tập tiếp',
            status: 'DISPUTED',
            escalationReason: 'TIMEOUT_72H',
            disputedAt: '2026-11-21T03:00:00.000Z',
            createdAt: '2026-11-18T03:00:00.000Z',
          },
          {
            id: termPendingId,
            relationshipId: 'rel-2',
            memberName: 'Phạm Quốc Bảo',
            coachName: 'Coach Minh Đức',
            requestedByRole: 'COACH',
            requestedByName: 'Coach Minh Đức',
            reason: 'Tạm nghỉ ngắn hạn',
            status: 'PENDING_COUNTERPARTY',
            responseDeadlineAt: futureDeadline,
            createdAt: '2026-11-21T01:00:00.000Z',
          },
        ],
        pagination: { page: 1, pageSize: 10, totalItems: 2, totalPages: 1 },
      });
    }
    if (parsed.pathname === `/api/v1/admin/termination-requests/${termDisputedId}` && options.method === 'PATCH') {
      patchCalls.push(JSON.parse(options.body));
      return jsonResponse({ data: { id: termDisputedId, status: 'ADMIN_APPROVED' } });
    }
    if (parsed.pathname === '/api/v1/admin/relationships') {
      return jsonResponse({
        data: [{
          id: relId,
          memberId: 'm-1',
          memberName: 'Nguyễn Thảo Vy',
          coachId: 'c-1',
          coachName: 'Coach Hoàng Long',
          status: 'ACTIVE',
          pauseReason: null,
          startedAt: '2026-11-01T02:00:00.000Z',
          activeEntitlement: { planName: 'Tiêu chuẩn 20 buổi', remainingSessions: 14, totalSessions: 20, endsOn: '2026-12-30' },
          hasQueuedPackage: true,
        }],
        pagination: { page: 1, pageSize: 10, totalItems: 1, totalPages: 1 },
      });
    }
    if (parsed.pathname === `/api/v1/admin/relationships/${relId}`) {
      return jsonResponse({
        data: {
          id: relId,
          memberName: 'Nguyễn Thảo Vy',
          coachName: 'Coach Hoàng Long',
          status: 'ACTIVE',
          startedAt: '2026-11-01T02:00:00.000Z',
          upcomingBookingsCount: 2,
          openHoldsCount: 0,
          activeEntitlement: { planName: 'Tiêu chuẩn 20 buổi', remainingSessions: 14, totalSessions: 20, startsOn: '2026-11-01', endsOn: '2026-12-30', snapshotPrice: 3500000 },
          queuedEntitlement: { planName: 'Cơ bản 10 buổi', totalSessions: 10, durationDays: 30, snapshotPrice: 1900000 },
          transferHistory: [],
          terminationRequests: [],
          lockIncidents: [],
        },
      });
    }
    throw new Error(`Unexpected ${parsed.pathname}`);
  };

  await renderRelationshipsPage({
    root: env.root,
    params: new URLSearchParams({ tab: 'terminations' }),
    shell: makeShell(env),
  });

  const tableHtml = env.root.querySelector('table')?.innerHTML || '';
  assert.equal(tableHtml.includes('Nguyễn Thảo Vy'), true);
  assert.equal(tableHtml.includes('DISPUTED'), true);
  assert.equal(tableHtml.includes('Còn 2'), true, 'PENDING_COUNTERPARTY must show live 72h countdown');

  const pendingApproveBtn = env.root.querySelector(`.decide-term[data-id="${termPendingId}"][data-decision="APPROVED"]`);
  assert.equal(pendingApproveBtn.disabled, true, 'PENDING_COUNTERPARTY cannot be adjudicated by Admin');

  const disputedApproveBtn = env.root.querySelector(`.decide-term[data-id="${termDisputedId}"][data-decision="APPROVED"]`);
  assert.equal(disputedApproveBtn.disabled, false, 'DISPUTED row can be adjudicated');

  // Open adjudication modal
  disputedApproveBtn.click();
  await flush();

  const submitBtn = env.modalDialog.querySelector('#meta-confirm-submit');
  assert.equal(submitBtn.disabled, true, 'Adjudication requires mandatory reason');

  const reasonEl = env.modalDialog.querySelector('#meta-confirm-reason');
  reasonEl.value = 'Quá 72 giờ không phản hồi; chấp thuận kết thúc sớm theo D5';
  reasonEl.dispatchEvent({ type: 'input' });
  assert.equal(submitBtn.disabled, false);

  env.modalDialog.querySelector('#meta-confirm-form').dispatchEvent({ type: 'submit' });
  await flush();

  assert.equal(patchCalls.length, 1);
  assert.deepEqual(patchCalls[0], {
    decision: 'APPROVED',
    reason: 'Quá 72 giờ không phản hồi; chấp thuận kết thúc sớm theo D5',
  });

  // Switch to list tab and verify pagination/filter + Detail Drawer (GET /admin/relationships/:id)
  env.root.querySelector('[data-rel-tab="list"]').click();
  await flush();

  const statusSel = env.root.querySelector('#rel-status');
  statusSel.value = 'PAUSED';
  statusSel.dispatchEvent({ type: 'change' });
  await flush();

  assert.equal(
    fetchedUrls.some((u) => u.includes('/api/v1/admin/relationships') && u.includes('status=PAUSED') && u.includes('pageSize=10')),
    true,
    'Filter must trigger server-side GET /admin/relationships with status & pageSize',
  );

  env.root.querySelector('.detail-rel').click();
  await flush();

  assert.equal(env.drawerOverlay.hidden, false);
  const drawerHtml = env.drawerPanel.innerHTML;
  assert.equal(drawerHtml.includes('Tiêu chuẩn 20 buổi'), true);
  assert.equal(drawerHtml.includes('Cơ bản 10 buổi'), true);
  assert.equal(drawerHtml.includes('healthNotes'), false);
  assert.equal(drawerHtml.includes('injuryNotes'), false);

  closeModal();
  closeDrawer();
});

test('T15 Dashboard aligns incident links to #/admin/incidents and renders totalVoidReversals + totalSimulatedRefunds + netRevenue', async () => {
  const env = createDomEnvironment({ hash: '#/admin/dashboard', token: 'tok' });
  setToken('tok');
  setCurrentUser({ id: 'adm-1', role: 'ADMIN', fullName: 'Meta Admin', email: 'admin@metagym.vn' });

  globalThis.fetch = async (url) => {
    const parsed = new URL(url, 'http://localhost');
    if (parsed.pathname === '/api/v1/admin/dashboard') {
      return jsonResponse({
        data: {
          from: '2026-10-23',
          to: '2026-11-21',
          timezone: 'Asia/Ho_Chi_Minh',
          members: { active: 142, disabled: 5 },
          coaches: { active: 8, disabled: 1 },
          activeMemberships: 96,
          activeCoachRelationships: 38,
          pausedCoachRelationships: { total: 3, membershipExpired: 1, coachLocked: 2, memberLocked: 0 },
          actionQueue: { coachLockedWaitingCount: 2, coachLockedRefundRequestedCount: 1, disputedTerminationCount: 1 },
          revenue: {
            gymGrossPayments: 28500000,
            totalVoidReversals: 1500000,
            voidReversalCount: 1,
            coachGrossPayments: 18000000,
            grossRevenue: 45000000,
            totalSimulatedRefunds: 3783000,
            simulatedRefundCount: 2,
            netRevenue: 41217000,
            byDay: [{ day: '2026-11-21', grossRevenue: 5000000, simulatedRefunds: 3783000, netRevenue: 1217000 }],
          },
        },
      });
    }
    throw new Error(`Unexpected ${parsed.pathname}`);
  };

  await renderDashboardPage({
    root: env.root,
    params: new URLSearchParams(),
    shell: makeShell(env),
    ChartCtor: class { destroy() {} },
  });

  const html = env.root.innerHTML;
  assert.equal(html.includes('#/admin/coach-incidents'), false, 'Must not contain legacy #/admin/coach-incidents links');
  assert.equal(html.includes('#/admin/incidents?status=OPEN'), true, 'Must link incident queue to #/admin/incidents?status=OPEN');
  assert.equal(html.includes('#/admin/incidents?tab=refunds'), true, 'Must link refunds KPI to #/admin/incidents?tab=refunds');
  assert.equal(html.includes('1.500.000'), true, 'Must display totalVoidReversals');
  assert.equal(html.includes('3.783.000'), true, 'Must display totalSimulatedRefunds');
  assert.equal(html.includes('41.217.000'), true, 'Must display netRevenue');
});
