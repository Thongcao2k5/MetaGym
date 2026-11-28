import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from '../users/users.routes.js';
import { executeCoachTransfer } from './coach-transfer.js';

const uuid = z.uuid();

const adminRelationshipsQuerySchema = z.strictObject({
  status: z.enum(['ACTIVE', 'PAUSED', 'ENDED']).optional(),
  pauseReason: z.enum(['MEMBERSHIP_EXPIRED', 'COACH_LOCKED', 'MEMBER_LOCKED']).optional(),
  coachId: uuid.optional(),
  memberId: uuid.optional(),
  search: z.string().trim().max(120).optional(),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});

const adminTransfersQuerySchema = z.strictObject({
  memberId: uuid.optional(),
  oldCoachId: uuid.optional(),
  newCoachId: uuid.optional(),
  from: z.iso.date().optional(),
  to: z.iso.date().optional(),
  search: z.string().trim().max(120).optional(),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});

const terminationStatusEnum = z.enum([
  'DISPUTED',
  'PENDING_COUNTERPARTY',
  'ACCEPTED',
  'ADMIN_APPROVED',
  'ADMIN_REJECTED',
  'CANCELLED',
  'APPROVED',
  'REJECTED',
]);

const adminTerminationsQuerySchema = z.strictObject({
  status: terminationStatusEnum.optional(),
  search: z.string().trim().max(120).optional(),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});

const myTerminationsQuerySchema = z.strictObject({
  status: terminationStatusEnum.optional(),
});

const earlyTerminationCreateSchema = z.strictObject({
  reason: z.string().trim().min(1).max(1000),
});

const earlyTerminationRespondSchema = z.strictObject({
  decision: z.enum(['ACCEPT', 'REJECT', 'WITHDRAW']),
  reason: z.string().trim().min(1).max(1000).optional(),
});

const adminTerminationDecisionSchema = z.strictObject({
  decision: z.enum(['APPROVED', 'REJECTED']),
  reason: z.string().trim().min(1).max(1000),
});

function fail(response, status, code, message, details = {}) {
  return response.status(status).json({ error: { code, details, message } });
}

function escapeLike(value) {
  return value.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
}

function coachView(row) {
  return {
    id: row.id, fullName: row.full_name, biography: row.biography,
    specialties: row.specialties, qualifications: row.qualifications,
    experienceYears: row.experience_years, availabilityNote: row.availability_note,
    avatarUrl: row.avatar_media_id ? `/api/v1/users/${row.id}/avatar` : null,
    memberLimit: row.member_limit, usedSlots: Number(row.used_slots),
    availableSlots: Math.max(0, row.member_limit - Number(row.used_slots)),
  };
}

function requestView(row) {
  return {
    id: row.id, memberId: row.member_id, coachId: row.coach_id,
    message: row.message, status: row.status,
    rejectionReason: row.rejection_reason,
    requestedAt: row.requested_at, decidedAt: row.decided_at,
  };
}

function relationshipView(row) {
  return {
    id: row.id, memberId: row.member_id, coachId: row.coach_id,
    status: row.status, pauseReason: row.pause_reason ?? null,
    coachName: row.coach_name ?? null,
    coachAvatarUrl: row.coach_avatar_media_id ? `/api/v1/users/${row.coach_id}/avatar` : null,
    startedAt: row.started_at,
    pausedAt: row.paused_at, endedAt: row.ended_at,
  };
}

function adminRelationshipListView(row) {
  return {
    id: row.id,
    memberId: row.member_id,
    memberName: row.member_name ?? null,
    memberEmail: row.member_email ?? null,
    coachId: row.coach_id,
    coachName: row.coach_name ?? null,
    coachEmail: row.coach_email ?? null,
    status: row.status,
    pauseReason: row.pause_reason ?? null,
    startedAt: row.started_at,
    pausedAt: row.paused_at ?? null,
    endedAt: row.ended_at ?? null,
    endReason: row.end_reason ?? null,
    activeEntitlement: row.active_entitlement_id ? {
      id: row.active_entitlement_id,
      planCode: row.active_plan_code ?? null,
      planName: row.active_plan_name ?? null,
      totalSessions: row.active_total_sessions,
      remainingSessions: row.active_remaining_sessions,
      startsOn: row.active_starts_on ?? null,
      endsOn: row.active_ends_on ?? null,
      frozenAt: row.active_frozen_at ?? null,
      frozenDaysTotal: row.active_frozen_days_total ?? 0,
      graceDaysAdded: row.active_grace_days_added ?? 0,
    } : null,
    hasQueuedPackage: Boolean(row.has_queued_package),
    openTerminationStatus: row.open_termination_status ?? null,
    openTerminationRequestId: row.open_termination_request_id ?? null,
    openIncidentId: row.open_incident_id ?? null,
  };
}

function operationalEntitlementView(row) {
  return {
    id: row.id,
    planCode: row.plan_code ?? null,
    planName: row.plan_name ?? null,
    snapshotPrice: row.snapshot_price === null || row.snapshot_price === undefined
      ? null
      : Number(row.snapshot_price),
    status: row.status,
    totalSessions: row.total_sessions,
    remainingSessions: row.remaining_sessions,
    durationDays: row.duration_days,
    startsOn: row.starts_on ?? null,
    originalEndsOn: row.original_ends_on ?? null,
    endsOn: row.ends_on ?? null,
    frozenAt: row.frozen_at ?? null,
    frozenDaysTotal: row.frozen_days_total ?? 0,
    graceDaysAdded: row.grace_days_added ?? 0,
    closeReason: row.close_reason ?? null,
    endedAt: row.ended_at ?? null,
  };
}

function transferHistoryView(row) {
  return {
    id: row.id,
    memberId: row.member_id,
    memberName: row.member_name ?? null,
    oldRelationshipId: row.old_relationship_id,
    newRelationshipId: row.new_relationship_id,
    oldCoachId: row.old_coach_id,
    oldCoachName: row.old_coach_name ?? null,
    newCoachId: row.new_coach_id,
    newCoachName: row.new_coach_name ?? null,
    reason: row.reason,
    adminId: row.admin_id,
    adminName: row.admin_name ?? null,
    createdAt: row.created_at,
  };
}

function terminationView(row) {
  return {
    id: row.id,
    relationshipId: row.relationship_id,
    relationshipStatus: row.relationship_status ?? null,
    memberId: row.member_id,
    memberName: row.member_name ?? null,
    coachId: row.coach_id,
    coachName: row.coach_name ?? null,
    requestedByUserId: row.requested_by_user_id,
    requestedByRole: row.requested_by_role,
    requestedByName: row.requested_by_name ?? null,
    counterpartyUserId: row.counterparty_user_id,
    counterpartyName: row.counterparty_name ?? null,
    reason: row.reason,
    status: row.status,
    counterpartyDecision: row.counterparty_decision ?? null,
    counterpartyReason: row.counterparty_reason ?? null,
    counterpartyDecidedAt: row.counterparty_decided_at ?? null,
    responseDeadlineAt: row.response_deadline_at,
    disputedAt: row.disputed_at ?? null,
    escalationReason: row.escalation_reason ?? null,
    adminNote: row.admin_note ?? null,
    decidedBy: row.decided_by ?? null,
    decidedByName: row.decided_by_name ?? null,
    decidedAt: row.decided_at ?? null,
    createdAt: row.created_at,
  };
}

function lockIncidentSummaryView(row) {
  return {
    id: row.id,
    coachId: row.coach_id,
    memberId: row.member_id,
    relationshipId: row.relationship_id,
    activeEntitlementId: row.active_entitlement_id ?? null,
    queuedEntitlementId: row.queued_entitlement_id ?? null,
    lockReason: row.lock_reason,
    lockedBy: row.locked_by,
    lockedByName: row.locked_by_name ?? null,
    lockedAt: row.locked_at,
    frozenStartedAt: row.frozen_started_at ?? null,
    frozenEndedAt: row.frozen_ended_at ?? null,
    frozenDaysApplied: row.frozen_days_applied ?? null,
    memberChoice: row.member_choice,
    memberChoiceAt: row.member_choice_at ?? null,
    memberChoiceNote: row.member_choice_note ?? null,
    status: row.status,
    transferHistoryId: row.transfer_history_id ?? null,
    refundBatchId: row.refund_batch_id ?? null,
    resolvedBy: row.resolved_by ?? null,
    resolvedByName: row.resolved_by_name ?? null,
    resolvedAt: row.resolved_at ?? null,
    createdAt: row.created_at,
  };
}

async function activeAdmin(client, user) {
  const result = await client.query(
    `SELECT id FROM users WHERE id = $1 AND role = 'ADMIN' AND status = 'ACTIVE'
     AND session_version = $2 FOR SHARE`,
    [user.id, user.session_version],
  );
  return result.rows.length === 1;
}

async function activeMembership(client, memberId) {
  const result = await client.query(
    `SELECT 1 FROM member_memberships WHERE member_id = $1
     AND status = 'ACTIVE'
     AND start_date <= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
     AND end_date >= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date LIMIT 1`,
    [memberId],
  );
  return result.rows.length === 1;
}

async function escalateOverdueTerminations(executor, filterSql = '', params = []) {
  await executor.query(
    `WITH escalated AS (
       UPDATE coach_termination_requests
       SET status = 'DISPUTED',
           disputed_at = response_deadline_at,
           escalation_reason = 'TIMEOUT_72H'
       WHERE status = 'PENDING_COUNTERPARTY'
         AND response_deadline_at <= statement_timestamp()
         ${filterSql}
       RETURNING id, requested_by_user_id, counterparty_user_id
     )
     INSERT INTO coach_notifications (user_id, kind, subject_id)
     SELECT recipient.user_id, 'TERMINATION_DISPUTED', escalated.id
     FROM escalated
     CROSS JOIN LATERAL (
       VALUES (escalated.requested_by_user_id), (escalated.counterparty_user_id)
     ) AS recipient(user_id)`,
    params,
  );
}

const TERMINATION_SELECT_SQL = `
  SELECT t.*,
         r.member_id,
         r.status AS relationship_status,
         m.full_name AS member_name,
         c.full_name AS coach_name,
         req_u.full_name AS requested_by_name,
         cp_u.full_name AS counterparty_name,
         dec_u.full_name AS decided_by_name
  FROM coach_termination_requests t
  JOIN coach_relationships r ON r.id = t.relationship_id
  JOIN users m ON m.id = r.member_id
  JOIN users c ON c.id = r.coach_id
  JOIN users req_u ON req_u.id = t.requested_by_user_id
  JOIN users cp_u ON cp_u.id = t.counterparty_user_id
  LEFT JOIN users dec_u ON dec_u.id = t.decided_by
`;

async function fetchTerminationRow(executor, requestId) {
  const { rows } = await executor.query(
    `${TERMINATION_SELECT_SQL} WHERE t.id = $1`,
    [requestId],
  );
  return rows[0] ?? null;
}

async function executeEarlyTermination(client, { relationship, lockedEntitlements, endedBy, endReason }) {
  const activeEnt = lockedEntitlements.find((e) => e.status === 'ACTIVE') ?? null;
  const queuedEnt = lockedEntitlements.find((e) => e.status === 'QUEUED') ?? null;
  const forfeitedActiveSessions = activeEnt ? Number(activeEnt.remaining_sessions) : 0;
  const forfeitedQueuedPackage = Boolean(queuedEnt);

  // Canonical lock order steps 6-7: holds then future bookings
  await client.query(
    `SELECT id FROM coach_payment_holds
     WHERE member_id = $1 AND coach_id = $2 AND status = 'HELD'
     ORDER BY id ASC FOR UPDATE`,
    [relationship.member_id, relationship.coach_id],
  );
  await client.query(
    `SELECT b.id FROM coach_bookings b
     JOIN coach_entitlements e ON e.id = b.entitlement_id
     WHERE e.relationship_id = $1 AND b.status = 'BOOKED'
       AND b.starts_at > statement_timestamp()
     ORDER BY b.id ASC FOR UPDATE OF b`,
    [relationship.id],
  );

  // Close ACTIVE + QUEUED entitlements explicitly as EARLY_TERMINATION (forfeit unused sessions, 0 refund)
  await client.query(
    `UPDATE coach_entitlements
     SET status = 'ENDED',
         ended_at = statement_timestamp(),
         frozen_at = NULL,
         close_reason = 'EARLY_TERMINATION'
     WHERE relationship_id = $1
       AND status IN ('ACTIVE', 'QUEUED')`,
    [relationship.id],
  );

  // Cancel future Coach bookings WITHOUT charging sessions
  const cancelledBookings = await client.query(
    `UPDATE coach_bookings b
     SET status = 'CANCELLED',
         resolved_at = statement_timestamp(),
         resolved_by = $2,
         reason = 'Quan hệ Coach kết thúc sớm'
     FROM coach_entitlements e
     WHERE e.relationship_id = $1
       AND b.entitlement_id = e.id
       AND b.status = 'BOOKED'
       AND b.starts_at > statement_timestamp()`,
    [relationship.id, endedBy],
  );

  // Also cancel any legacy scheduled training_sessions
  await client.query(
    `UPDATE training_sessions
     SET status = 'CANCELLED',
         cancelled_at = statement_timestamp(),
         cancellation_reason = 'Quan hệ Coach kết thúc sớm'
     WHERE relationship_id = $1
       AND status = 'SCHEDULED'
       AND scheduled_start_at > statement_timestamp()`,
    [relationship.id],
  );

  // Archive active training plans and nutrition guides read-only
  await client.query(
    `UPDATE training_plans
     SET status = 'ARCHIVED', archived_at = statement_timestamp()
     WHERE relationship_id = $1 AND status = 'ACTIVE'`,
    [relationship.id],
  );
  await client.query(
    `UPDATE nutrition_guides
     SET status = 'ARCHIVED', archived_at = statement_timestamp()
     WHERE relationship_id = $1 AND status = 'ACTIVE'`,
    [relationship.id],
  );

  // Cancel any open payment holds for this pair so the Coach seat is cleanly released
  await client.query(
    `UPDATE coach_payment_holds
     SET status = 'CANCELLED'
     WHERE member_id = $1 AND coach_id = $2 AND status = 'HELD'`,
    [relationship.member_id, relationship.coach_id],
  );

  // End the relationship (releases Coach seat once; chat conversations stay intact and active)
  await client.query(
    `UPDATE coach_relationships
     SET status = 'ENDED',
         ended_at = statement_timestamp(),
         ended_by = $1,
         end_reason = $2
     WHERE id = $3`,
    [endedBy, endReason, relationship.id],
  );

  return {
    relationshipStatus: 'ENDED',
    forfeitedActiveSessions,
    forfeitedQueuedPackage,
    cancelledFutureBookingsCount: cancelledBookings.rowCount,
    plansArchived: true,
    coachSeatReleased: true,
  };
}

async function ensureConversation(client, memberId, coachId, relationshipId) {
  await client.query('SELECT pg_advisory_xact_lock(hashtext($1::text), hashtext($2::text))',
    [memberId, coachId]);
  const existing = await client.query(
    `SELECT c.id FROM conversations c
     LEFT JOIN coach_relationships r ON r.id = c.relationship_id
     WHERE COALESCE(c.member_id, r.member_id) = $1
       AND COALESCE(c.coach_id, r.coach_id) = $2 LIMIT 1`,
    [memberId, coachId],
  );
  if (existing.rows.length) return existing.rows[0].id;
  const id = randomUUID();
  await client.query(
    `INSERT INTO conversations (id, relationship_id, member_id, coach_id)
     VALUES ($1, $2, $3, $4)`, [id, relationshipId, memberId, coachId],
  );
  await client.query(
    `INSERT INTO conversation_participants (conversation_id, user_id)
     VALUES ($1, $2), ($1, $3)`, [id, memberId, coachId],
  );
  return id;
}

export function createCoachingRouter({ database, jwtSecret }) {
  const router = Router();
  router.use(createAuthentication({ database, jwtSecret }));

  router.get('/coaches', async (_request, response) => {
    try {
      const result = await database.query(
        `SELECT u.id, u.full_name, u.avatar_media_id, c.biography, c.specialties,
                c.qualifications, c.experience_years, c.availability_note,
                LEAST(c.member_limit, 8) AS member_limit,
                coach_occupied_seats(u.id) AS used_slots
         FROM users u JOIN coach_profiles c ON c.user_id = u.id
         WHERE u.role = 'COACH' AND u.status = 'ACTIVE'
         ORDER BY u.full_name, u.id`,
      );
      return response.json({ data: result.rows.map(coachView) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được Coach'); }
  });

  router.get('/coaches/:coachId', async (request, response) => {
    if (!uuid.safeParse(request.params.coachId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã Coach không hợp lệ');
    try {
      const result = await database.query(
        `SELECT u.id, u.full_name, u.avatar_media_id, c.biography, c.specialties,
                c.qualifications, c.experience_years, c.availability_note,
                LEAST(c.member_limit, 8) AS member_limit,
                coach_occupied_seats(u.id) AS used_slots
         FROM users u JOIN coach_profiles c ON c.user_id = u.id
         WHERE u.id = $1 AND u.role = 'COACH' AND u.status = 'ACTIVE'`,
        [request.params.coachId],
      );
      return result.rows.length ? response.json({ data: coachView(result.rows[0]) })
        : fail(response, 404, 'NOT_FOUND', 'Không tìm thấy Coach');
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được Coach'); }
  });

  router.post('/coach-requests', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được chọn Coach');
    const parsed = z.strictObject({
      coachId: uuid, message: z.string().trim().max(2000).nullable().optional(),
    }).safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu yêu cầu không hợp lệ');
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const member = await client.query(
        `SELECT id FROM users WHERE id = $1 AND role = 'MEMBER' AND status = 'ACTIVE'
         AND session_version = $2 FOR UPDATE`,
        [request.authUser.id, request.authUser.session_version],
      );
      if (!member.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      if (!await activeMembership(client, request.authUser.id)) {
        await client.query('ROLLBACK');
        return fail(response, 403, 'MEMBERSHIP_REQUIRED', 'Cần gói tập đang hoạt động');
      }
      const coach = await client.query(
        `SELECT id FROM users WHERE id = $1 AND role = 'COACH' AND status = 'ACTIVE'`,
        [parsed.data.coachId],
      );
      if (!coach.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy Coach');
      }
      const existing = await client.query(
        `SELECT 1 FROM coach_relationships WHERE member_id = $1
         AND status IN ('ACTIVE', 'PAUSED')
         UNION ALL SELECT 1 FROM coach_requests WHERE member_id = $1
         AND status = 'PENDING' LIMIT 1`, [request.authUser.id],
      );
      if (existing.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'COACH_REQUEST_CONFLICT', 'Đã có Coach hoặc yêu cầu đang chờ');
      }
      const created = await client.query(
        `INSERT INTO coach_requests (id, member_id, coach_id, message)
         VALUES ($1, $2, $3, $4) RETURNING *`,
        [randomUUID(), request.authUser.id, parsed.data.coachId,
          parsed.data.message ?? null],
      );
      await client.query('COMMIT');
      return response.status(201).json({ data: requestView(created.rows[0]) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tạo được yêu cầu Coach');
    } finally { client.release(); }
  });

  router.get('/coach-requests/me', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem yêu cầu');
    try {
      const result = await database.query(
        `SELECT * FROM coach_requests WHERE member_id = $1
         ORDER BY requested_at DESC, id DESC`, [request.authUser.id],
      );
      return response.json({ data: result.rows.map(requestView) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được yêu cầu'); }
  });

  router.delete('/coach-requests/:requestId', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được hủy yêu cầu');
    if (!uuid.safeParse(request.params.requestId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã yêu cầu không hợp lệ');
    try {
      const result = await database.query(
        `UPDATE coach_requests SET status = 'CANCELLED', decided_at = now()
         WHERE id = $1 AND member_id = $2 AND status = 'PENDING' RETURNING *`,
        [request.params.requestId, request.authUser.id],
      );
      return result.rows.length ? response.json({ data: requestView(result.rows[0]) })
        : fail(response, 404, 'NOT_FOUND', 'Không tìm thấy yêu cầu đang chờ');
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không hủy được yêu cầu'); }
  });

  router.get('/coach/requests', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được xem yêu cầu');
    try {
      const result = await database.query(
        `SELECT * FROM coach_requests WHERE coach_id = $1
         ORDER BY requested_at DESC, id DESC`, [request.authUser.id],
      );
      return response.json({ data: result.rows.map(requestView) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được yêu cầu'); }
  });

  router.get('/coach/requests/:requestId', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được xem yêu cầu');
    if (!uuid.safeParse(request.params.requestId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã yêu cầu không hợp lệ');
    try {
      const result = await database.query(
        'SELECT * FROM coach_requests WHERE id = $1 AND coach_id = $2',
        [request.params.requestId, request.authUser.id],
      );
      return result.rows.length ? response.json({ data: requestView(result.rows[0]) })
        : fail(response, 404, 'NOT_FOUND', 'Không tìm thấy yêu cầu');
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được yêu cầu'); }
  });

  router.patch('/coach/requests/:requestId', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được xử lý yêu cầu');
    if (!uuid.safeParse(request.params.requestId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã yêu cầu không hợp lệ');
    const parsed = z.strictObject({
      decision: z.enum(['ACCEPTED', 'REJECTED']),
      reason: z.string().trim().min(1).max(1000).optional(),
    }).safeParse(request.body);
    if (!parsed.success || (parsed.data.decision === 'REJECTED' && !parsed.data.reason)) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Quyết định hoặc lý do không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const coach = await client.query(
        `SELECT u.id, c.member_limit FROM users u
         JOIN coach_profiles c ON c.user_id = u.id
         WHERE u.id = $1 AND u.role = 'COACH' AND u.status = 'ACTIVE'
         AND u.session_version = $2 FOR UPDATE OF u`,
        [request.authUser.id, request.authUser.session_version],
      );
      if (!coach.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const pending = await client.query(
        `SELECT * FROM coach_requests WHERE id = $1 AND coach_id = $2 FOR UPDATE`,
        [request.params.requestId, request.authUser.id],
      );
      if (!pending.rows.length || pending.rows[0].status !== 'PENDING') {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy yêu cầu đang chờ');
      }
      const item = pending.rows[0];
      if (parsed.data.decision === 'REJECTED') {
        const updated = await client.query(
          `UPDATE coach_requests SET status = 'REJECTED',
           rejection_reason = $1, decided_at = now() WHERE id = $2 RETURNING *`,
          [parsed.data.reason, item.id],
        );
        await client.query('COMMIT');
        return response.json({ data: requestView(updated.rows[0]) });
      }
      const member = await client.query(
        `SELECT id FROM users WHERE id = $1 AND role = 'MEMBER'
         AND status = 'ACTIVE' FOR UPDATE`, [item.member_id],
      );
      if (!member.rows.length || !await activeMembership(client, item.member_id)) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'MEMBERSHIP_REQUIRED', 'Member không còn gói đang hoạt động');
      }
      const occupied = await client.query(
        'SELECT coach_occupied_seats($1) AS count',
        [request.authUser.id],
      );
      if (occupied.rows[0].count >= Math.min(8, coach.rows[0].member_limit)) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'COACH_FULL', 'Coach đã đủ Member');
      }
      const held = await client.query(
        `SELECT 1 FROM coach_payment_holds WHERE member_id = $1
         AND status = 'HELD' AND expires_at > statement_timestamp()`, [item.member_id],
      );
      if (held.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'HOLD_EXISTS', 'Member đang giữ suất thanh toán');
      }
      const other = await client.query(
        `SELECT 1 FROM coach_relationships WHERE member_id = $1
         AND status IN ('ACTIVE', 'PAUSED') LIMIT 1`, [item.member_id],
      );
      if (other.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'RELATIONSHIP_EXISTS', 'Member đã có Coach');
      }
      await client.query(
        `UPDATE coach_requests SET status = 'ACCEPTED', decided_at = now()
         WHERE id = $1`, [item.id],
      );
      const relationshipId = randomUUID();
      await client.query(
        `INSERT INTO coach_relationships
         (id, member_id, coach_id, source_request_id)
         VALUES ($1, $2, $3, $4)`,
        [relationshipId, item.member_id, request.authUser.id, item.id],
      );
      await ensureConversation(client, item.member_id, request.authUser.id,
        relationshipId);
      await client.query('COMMIT');
      return response.json({ data: {
        request: requestView({ ...item, status: 'ACCEPTED', decided_at: new Date() }),
        relationship: { id: relationshipId, memberId: item.member_id,
          coachId: request.authUser.id, status: 'ACTIVE' },
      } });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không xử lý được yêu cầu');
    } finally { client.release(); }
  });

  router.get('/relationships/me', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem Coach');
    try {
      const result = await database.query(
        `SELECT r.*, u.full_name AS coach_name, u.avatar_media_id AS coach_avatar_media_id
         FROM coach_relationships r
         JOIN users u ON u.id = r.coach_id
         WHERE r.member_id = $1
         AND r.status IN ('ACTIVE', 'PAUSED') LIMIT 1`, [request.authUser.id],
      );
      return response.json({ data: result.rows.length ? relationshipView(result.rows[0]) : null });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được quan hệ'); }
  });

  router.get('/relationships/me/history', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem Coach');
    try {
      const result = await database.query(
        `SELECT r.*, u.full_name AS coach_name, u.avatar_media_id AS coach_avatar_media_id
         FROM coach_relationships r
         JOIN users u ON u.id = r.coach_id
         WHERE r.member_id = $1
         ORDER BY r.started_at DESC, r.id DESC`, [request.authUser.id],
      );
      return response.json({ data: result.rows.map(relationshipView) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được quan hệ'); }
  });

  router.get('/coach/members', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được xem Member');
    try {
      const result = await database.query(
        `SELECT r.*, u.full_name FROM coach_relationships r
         JOIN users u ON u.id = r.member_id WHERE r.coach_id = $1
         AND r.status IN ('ACTIVE', 'PAUSED')
         ORDER BY u.full_name, r.id`, [request.authUser.id],
      );
      return response.json({ data: result.rows.map((row) => ({
        ...relationshipView(row), memberFullName: row.full_name,
      })) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được Member'); }
  });

  router.get('/coach/members/:memberId', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được xem Member');
    if (!uuid.safeParse(request.params.memberId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã Member không hợp lệ');
    try {
      const result = await database.query(
        `SELECT r.*, u.full_name, u.email::text,
                CASE WHEN r.status = 'ACTIVE' THEN m.fitness_goal END AS fitness_goal,
                CASE WHEN r.status = 'ACTIVE' THEN m.height_cm::float8 END AS height_cm,
                CASE WHEN r.status = 'ACTIVE' THEN m.weight_kg::float8 END AS weight_kg,
                CASE WHEN r.status = 'ACTIVE' THEN m.body_fat_percent::float8 END AS body_fat_percent,
                CASE WHEN r.status = 'ACTIVE' THEN m.health_notes END AS health_notes,
                CASE WHEN r.status = 'ACTIVE' THEN m.injury_notes END AS injury_notes,
                CASE WHEN r.status = 'ACTIVE' THEN m.health_declaration_completed_at END AS health_declaration_completed_at
         FROM coach_relationships r JOIN users u ON u.id = r.member_id
         JOIN member_profiles m ON m.user_id = r.member_id
         WHERE r.coach_id = $1 AND r.member_id = $2
         AND r.status IN ('ACTIVE', 'PAUSED') LIMIT 1`,
        [request.authUser.id, request.params.memberId],
      );
      if (!result.rows.length) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy Member đang phụ trách');
      const row = result.rows[0];
      return response.json({ data: {
        ...relationshipView(row), member: {
          id: row.member_id, fullName: row.full_name, email: row.email,
          fitnessGoal: row.fitness_goal, healthNotes: row.health_notes,
          injuryNotes: row.injury_notes, heightCm: row.height_cm,
          weightKg: row.weight_kg, bodyFatPercent: row.body_fat_percent,
          healthDeclarationCompletedAt: row.health_declaration_completed_at,
        },
      } });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được Member'); }
  });

  // =========================================================================
  // D5: Two-party 72h Early Termination Requests & Dispute Adjudication (V2)
  // =========================================================================

  router.post('/relationships/:relationshipId/early-termination-requests', async (request, response) => {
    if (!['MEMBER', 'COACH'].includes(request.authUser.role)) {
      return fail(response, 403, 'FORBIDDEN', 'Chỉ Member hoặc Coach được gửi yêu cầu kết thúc sớm');
    }
    if (!uuid.safeParse(request.params.relationshipId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã quan hệ không hợp lệ');
    }
    const parsed = earlyTerminationCreateSchema.safeParse(request.body);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Lý do kết thúc sớm không hợp lệ');
    }

    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      // Non-locking peek to acquire canonical user locks (Coach BEFORE Member)
      const peek = await client.query(
        'SELECT id, member_id, coach_id FROM coach_relationships WHERE id = $1',
        [request.params.relationshipId],
      );
      if (!peek.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy quan hệ Coach');
      }
      const target = peek.rows[0];
      const isMemberCaller = request.authUser.role === 'MEMBER' && target.member_id === request.authUser.id;
      const isCoachCaller = request.authUser.role === 'COACH' && target.coach_id === request.authUser.id;
      if (!isMemberCaller && !isCoachCaller) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy quan hệ Coach');
      }

      // Canonical lock order: Coach FIRST, Member SECOND
      const coachUser = (await client.query(
        'SELECT id, status, session_version FROM users WHERE id = $1 FOR UPDATE',
        [target.coach_id],
      )).rows[0];
      const memberUser = (await client.query(
        'SELECT id, status, session_version FROM users WHERE id = $1 FOR UPDATE',
        [target.member_id],
      )).rows[0];
      const callerUser = isCoachCaller ? coachUser : memberUser;
      if (!callerUser || callerUser.status !== 'ACTIVE' ||
          callerUser.session_version !== request.authUser.session_version) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }

      // Lock relationship
      const rel = (await client.query(
        'SELECT * FROM coach_relationships WHERE id = $1 FOR UPDATE',
        [target.id],
      )).rows[0];
      if (!rel || rel.status === 'ENDED') {
        await client.query('ROLLBACK');
        return fail(response, 409, 'RELATIONSHIP_ENDED', 'Quan hệ Coach đã kết thúc');
      }
      if (rel.status === 'PAUSED' && rel.pause_reason === 'COACH_LOCKED') {
        await client.query('ROLLBACK');
        return fail(
          response,
          409,
          'USE_COACH_INCIDENT_FLOW',
          'Quan hệ đang tạm ngưng do Coach bị khóa; vui lòng xử lý qua luồng sự cố khóa Coach',
        );
      }
      if (rel.status === 'PAUSED' && rel.pause_reason !== 'MEMBERSHIP_EXPIRED') {
        await client.query('ROLLBACK');
        return fail(
          response,
          409,
          'RELATIONSHIP_NOT_ELIGIBLE',
          'Không thể gửi yêu cầu kết thúc sớm trong trạng thái tạm ngưng hiện tại',
        );
      }

      await escalateOverdueTerminations(client, 'AND relationship_id = $1', [rel.id]);

      const existingOpen = await client.query(
        `SELECT id FROM coach_termination_requests
         WHERE relationship_id = $1 AND status IN ('PENDING_COUNTERPARTY', 'DISPUTED')
         LIMIT 1 FOR UPDATE`,
        [rel.id],
      );
      if (existingOpen.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 409, 'REQUEST_EXISTS', 'Quan hệ này đã có yêu cầu kết thúc sớm đang mở');
      }

      const requestId = randomUUID();
      const counterpartyUserId = isMemberCaller ? rel.coach_id : rel.member_id;
      await client.query(
        `INSERT INTO coach_termination_requests (
           id, relationship_id, coach_id, reason, status,
           requested_by_user_id, requested_by_role, counterparty_user_id,
           response_deadline_at, created_at
         ) VALUES (
           $1, $2, $3, $4, 'PENDING_COUNTERPARTY',
           $5, $6, $7,
           statement_timestamp() + interval '72 hours',
           statement_timestamp()
         )`,
        [
          requestId,
          rel.id,
          rel.coach_id,
          parsed.data.reason,
          request.authUser.id,
          request.authUser.role,
          counterpartyUserId,
        ],
      );

      await client.query(
        `INSERT INTO coach_notifications (user_id, kind, subject_id)
         VALUES ($1, 'TERMINATION_REQUESTED', $2)`,
        [counterpartyUserId, requestId],
      );

      const fullRow = await fetchTerminationRow(client, requestId);
      await client.query('COMMIT');
      return response.status(201).json({ data: terminationView(fullRow) });
    } catch (cause) {
      await client.query('ROLLBACK').catch(() => {});
      if (cause.code === '23505') {
        return fail(response, 409, 'REQUEST_EXISTS', 'Quan hệ này đã có yêu cầu kết thúc sớm đang mở');
      }
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không gửi được yêu cầu kết thúc sớm');
    } finally { client.release(); }
  });

  router.get('/early-termination-requests/me', async (request, response) => {
    if (!['MEMBER', 'COACH'].includes(request.authUser.role)) {
      return fail(response, 403, 'FORBIDDEN', 'Chỉ Member hoặc Coach được xem yêu cầu kết thúc sớm');
    }
    const parsed = myTerminationsQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Bộ lọc yêu cầu kết thúc sớm không hợp lệ');
    }
    try {
      await escalateOverdueTerminations(
        database,
        'AND (requested_by_user_id = $1 OR counterparty_user_id = $1)',
        [request.authUser.id],
      );
      const values = [request.authUser.id];
      const filters = ['(t.requested_by_user_id = $1 OR t.counterparty_user_id = $1)'];
      if (parsed.data.status) {
        values.push(parsed.data.status);
        filters.push(`t.status = $${values.length}`);
      }
      const { rows } = await database.query(
        `${TERMINATION_SELECT_SQL}
         WHERE ${filters.join(' AND ')}
         ORDER BY t.created_at DESC, t.id DESC`,
        values,
      );
      return response.json({ data: rows.map(terminationView) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được yêu cầu kết thúc sớm');
    }
  });

  router.patch('/early-termination-requests/:requestId/respond', async (request, response) => {
    if (!['MEMBER', 'COACH'].includes(request.authUser.role)) {
      return fail(response, 403, 'FORBIDDEN', 'Chỉ Member hoặc Coach được phản hồi yêu cầu kết thúc sớm');
    }
    if (!uuid.safeParse(request.params.requestId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã yêu cầu không hợp lệ');
    }
    const parsed = earlyTerminationRespondSchema.safeParse(request.body);
    if (!parsed.success || (parsed.data.decision === 'REJECT' && !parsed.data.reason)) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Quyết định hoặc lý do phản hồi không hợp lệ');
    }
    const { decision, reason } = parsed.data;

    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const peek = await client.query(
        `SELECT t.id, t.relationship_id, t.requested_by_user_id, t.counterparty_user_id,
                r.coach_id, r.member_id
         FROM coach_termination_requests t
         JOIN coach_relationships r ON r.id = t.relationship_id
         WHERE t.id = $1`,
        [request.params.requestId],
      );
      if (!peek.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy yêu cầu kết thúc sớm');
      }
      const target = peek.rows[0];
      const isRequester = target.requested_by_user_id === request.authUser.id;
      const isCounterparty = target.counterparty_user_id === request.authUser.id;
      if (!isRequester && !isCounterparty) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy yêu cầu kết thúc sớm');
      }
      if (decision === 'WITHDRAW' && !isRequester) {
        await client.query('ROLLBACK');
        return fail(response, 403, 'FORBIDDEN', 'Chỉ người gửi mới có quyền rút yêu cầu kết thúc sớm');
      }
      if ((decision === 'ACCEPT' || decision === 'REJECT') && !isCounterparty) {
        await client.query('ROLLBACK');
        return fail(response, 403, 'FORBIDDEN', 'Chỉ đối tác mới có quyền chấp nhận hoặc từ chối yêu cầu');
      }

      // Canonical lock order: Coach FIRST, Member SECOND, then relationship, entitlements, termination request
      const coachUser = (await client.query(
        'SELECT id, status, session_version FROM users WHERE id = $1 FOR UPDATE',
        [target.coach_id],
      )).rows[0];
      const memberUser = (await client.query(
        'SELECT id, status, session_version FROM users WHERE id = $1 FOR UPDATE',
        [target.member_id],
      )).rows[0];
      const callerUser = request.authUser.id === target.coach_id ? coachUser : memberUser;
      if (!callerUser || callerUser.status !== 'ACTIVE' ||
          callerUser.session_version !== request.authUser.session_version) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }

      const rel = (await client.query(
        'SELECT * FROM coach_relationships WHERE id = $1 FOR UPDATE',
        [target.relationship_id],
      )).rows[0];
      const lockedEntitlements = (await client.query(
        `SELECT * FROM coach_entitlements
         WHERE relationship_id = $1 AND status IN ('ACTIVE', 'QUEUED')
         ORDER BY id ASC FOR UPDATE`,
        [target.relationship_id],
      )).rows;
      const item = (await client.query(
        `SELECT *, (response_deadline_at <= statement_timestamp()) AS deadline_expired
         FROM coach_termination_requests WHERE id = $1 FOR UPDATE`,
        [target.id],
      )).rows[0];

      if (!item) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy yêu cầu kết thúc sớm');
      }

      // Inline 72h timeout escalation — COMMIT before returning 409 so escalation persists!
      if (item.status === 'PENDING_COUNTERPARTY' && item.deadline_expired) {
        await client.query(
          `UPDATE coach_termination_requests
           SET status = 'DISPUTED',
               disputed_at = response_deadline_at,
               escalation_reason = 'TIMEOUT_72H'
           WHERE id = $1`,
          [item.id],
        );
        await client.query(
          `INSERT INTO coach_notifications (user_id, kind, subject_id)
           VALUES ($1, 'TERMINATION_DISPUTED', $3),
                  ($2, 'TERMINATION_DISPUTED', $3)`,
          [item.requested_by_user_id, item.counterparty_user_id, item.id],
        );
        await client.query('COMMIT');
        return fail(
          response,
          409,
          'TERMINATION_DEADLINE_EXPIRED',
          'Đã quá hạn 72 giờ phản hồi; yêu cầu đã chuyển sang trạng thái tranh chấp để Admin phán quyết',
        );
      }

      if (item.status === 'DISPUTED' && item.escalation_reason === 'TIMEOUT_72H') {
        await client.query('ROLLBACK');
        return fail(
          response,
          409,
          'TERMINATION_DEADLINE_EXPIRED',
          'Đã quá hạn 72 giờ phản hồi; yêu cầu đang chờ Admin phán quyết tranh chấp',
        );
      }

      if (item.status !== 'PENDING_COUNTERPARTY') {
        await client.query('ROLLBACK');
        return fail(response, 409, 'REQUEST_NOT_PENDING', 'Yêu cầu kết thúc sớm không còn ở trạng thái chờ phản hồi');
      }

      if (!rel || rel.status === 'ENDED') {
        await client.query('ROLLBACK');
        return fail(response, 409, 'RELATIONSHIP_ENDED', 'Quan hệ Coach đã kết thúc');
      }
      if (rel.status === 'PAUSED' && rel.pause_reason === 'COACH_LOCKED') {
        await client.query('ROLLBACK');
        return fail(
          response,
          409,
          'USE_COACH_INCIDENT_FLOW',
          'Quan hệ đang tạm ngưng do Coach bị khóa; vui lòng xử lý qua luồng sự cố khóa Coach',
        );
      }

      if (decision === 'WITHDRAW') {
        await client.query(
          `UPDATE coach_termination_requests
           SET status = 'CANCELLED',
               decided_at = statement_timestamp()
           WHERE id = $1`,
          [item.id],
        );
        await client.query(
          `INSERT INTO coach_notifications (user_id, kind, subject_id)
           VALUES ($1, 'TERMINATION_WITHDRAWN', $2)`,
          [item.counterparty_user_id, item.id],
        );
        const fullRow = await fetchTerminationRow(client, item.id);
        await client.query('COMMIT');
        return response.json({ data: terminationView(fullRow) });
      }

      if (decision === 'REJECT') {
        await client.query(
          `UPDATE coach_termination_requests
           SET status = 'DISPUTED',
               counterparty_decision = 'REJECTED',
               counterparty_reason = $1,
               counterparty_decided_at = statement_timestamp(),
               disputed_at = statement_timestamp(),
               escalation_reason = 'COUNTERPARTY_REJECTED'
           WHERE id = $2`,
          [reason, item.id],
        );
        await client.query(
          `INSERT INTO coach_notifications (user_id, kind, subject_id)
           VALUES ($1, 'TERMINATION_DISPUTED', $3),
                  ($2, 'TERMINATION_DISPUTED', $3)`,
          [item.requested_by_user_id, item.counterparty_user_id, item.id],
        );
        const fullRow = await fetchTerminationRow(client, item.id);
        await client.query('COMMIT');
        return response.json({ data: terminationView(fullRow) });
      }

      // decision === 'ACCEPT': mark request ACCEPTED FIRST, then end relationship & forfeit unused sessions
      await client.query(
        `UPDATE coach_termination_requests
         SET status = 'ACCEPTED',
             counterparty_decision = 'ACCEPTED',
             counterparty_reason = $1,
             counterparty_decided_at = statement_timestamp(),
             decided_at = statement_timestamp()
         WHERE id = $2`,
        [reason ?? null, item.id],
      );

      const effects = await executeEarlyTermination(client, {
        relationship: rel,
        lockedEntitlements,
        endedBy: request.authUser.id,
        endReason: item.reason,
      });

      await client.query(
        `INSERT INTO coach_notifications (user_id, kind, subject_id)
         VALUES ($1, 'TERMINATION_ACCEPTED', $3),
                ($2, 'TERMINATION_ACCEPTED', $3)`,
        [item.requested_by_user_id, item.counterparty_user_id, item.id],
      );

      const fullRow = await fetchTerminationRow(client, item.id);
      await client.query('COMMIT');
      return response.json({ data: { ...terminationView(fullRow), effects } });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không xử lý được phản hồi yêu cầu kết thúc sớm');
    } finally { client.release(); }
  });

  // =========================================================================
  // Legacy V1 Termination Endpoints (retired with 410 via legacy-v1.routes.js;
  // kept reachable only when enableLegacyWrites: true in legacy V1 tests)
  // =========================================================================

  router.post('/relationships/:relationshipId/terminations', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được kết thúc quan hệ');
    if (!uuid.safeParse(request.params.relationshipId).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã quan hệ không hợp lệ');
    const parsed = z.strictObject({
      reason: z.string().trim().min(1).max(1000),
    }).safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Cần lý do kết thúc');
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const member = await client.query(
        `SELECT id FROM users WHERE id = $1 AND role = 'MEMBER' AND status = 'ACTIVE'
         AND session_version = $2 FOR UPDATE`,
        [request.authUser.id, request.authUser.session_version],
      );
      if (!member.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const result = await client.query(
        `SELECT * FROM coach_relationships WHERE id = $1 AND member_id = $2
         AND status IN ('ACTIVE', 'PAUSED') FOR UPDATE`,
        [request.params.relationshipId, request.authUser.id],
      );
      if (!result.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy quan hệ hiện tại');
      }
      await client.query(
        `UPDATE coach_relationships SET status = 'ENDED', ended_at = now(),
         ended_by = $1, end_reason = $2 WHERE id = $3`,
        [request.authUser.id, parsed.data.reason, result.rows[0].id],
      );
      await client.query(
        `UPDATE coach_termination_requests SET status = 'CANCELLED', decided_at = now()
         WHERE relationship_id = $1 AND status IN ('PENDING_COUNTERPARTY', 'DISPUTED')`,
        [result.rows[0].id],
      );
      await client.query(
        `UPDATE training_sessions SET status = 'CANCELLED', cancelled_at = now(),
         cancellation_reason = 'Quan hệ Coach đã kết thúc'
         WHERE relationship_id = $1 AND status = 'SCHEDULED'
         AND scheduled_start_at > now()`, [result.rows[0].id],
      );
      const ended = await client.query('SELECT * FROM coach_relationships WHERE id = $1', [result.rows[0].id]);
      await client.query('COMMIT');
      return response.json({ data: relationshipView(ended.rows[0]) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết thúc được quan hệ');
    } finally { client.release(); }
  });

  router.post('/coach/termination-requests', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được gửi yêu cầu');
    const parsed = z.strictObject({
      relationshipId: uuid, reason: z.string().trim().min(1).max(1000),
    }).safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu không hợp lệ');
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const relationship = await client.query(
        `SELECT id, member_id FROM coach_relationships WHERE id = $1 AND coach_id = $2
         AND status IN ('ACTIVE', 'PAUSED') FOR UPDATE`,
        [parsed.data.relationshipId, request.authUser.id],
      );
      if (!relationship.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy quan hệ hiện tại');
      }
      const created = await client.query(
        `INSERT INTO coach_termination_requests
         (id, relationship_id, coach_id, reason, status,
          requested_by_user_id, requested_by_role, counterparty_user_id,
          response_deadline_at, created_at)
         VALUES ($1, $2, $3, $4, 'PENDING_COUNTERPARTY',
                 $3, 'COACH', $5,
                 statement_timestamp() + interval '72 hours', statement_timestamp())
         RETURNING *`,
        [randomUUID(), parsed.data.relationshipId, request.authUser.id,
          parsed.data.reason, relationship.rows[0].member_id],
      );
      await client.query('COMMIT');
      return response.status(201).json({ data: created.rows[0] });
    } catch (cause) {
      await client.query('ROLLBACK').catch(() => {});
      return cause.code === '23505'
        ? fail(response, 409, 'REQUEST_EXISTS', 'Đã có yêu cầu đang chờ')
        : fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không gửi được yêu cầu');
    } finally { client.release(); }
  });

  router.get('/coach/termination-requests', async (request, response) => {
    if (request.authUser.role !== 'COACH') return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được xem yêu cầu');
    try {
      await escalateOverdueTerminations(database, 'AND coach_id = $1', [request.authUser.id]);
      const result = await database.query(
        `${TERMINATION_SELECT_SQL}
         WHERE t.coach_id = $1 ORDER BY t.created_at DESC, t.id DESC`,
        [request.authUser.id],
      );
      return response.json({ data: result.rows.map(terminationView) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được yêu cầu'); }
  });

  // =========================================================================
  // Admin Operational Relationships, Termination Disputes & Coach Transfers V2
  // =========================================================================

  router.get('/admin/relationships', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    const parsed = adminRelationshipsQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Bộ lọc quan hệ không hợp lệ');
    }
    const { status, pauseReason, coachId, memberId, search, page, pageSize } = parsed.data;
    const filters = [];
    const values = [];
    if (status) {
      values.push(status);
      filters.push(`r.status = $${values.length}`);
    }
    if (pauseReason) {
      values.push(pauseReason);
      filters.push(`r.pause_reason = $${values.length}`);
    }
    if (coachId) {
      values.push(coachId);
      filters.push(`r.coach_id = $${values.length}`);
    }
    if (memberId) {
      values.push(memberId);
      filters.push(`r.member_id = $${values.length}`);
    }
    if (search) {
      values.push(`%${escapeLike(search)}%`);
      const p = `$${values.length}`;
      filters.push(
        `(m.full_name ILIKE ${p} ESCAPE '\\' OR m.email::text ILIKE ${p} ESCAPE '\\' OR c.full_name ILIKE ${p} ESCAPE '\\' OR c.email::text ILIKE ${p} ESCAPE '\\' OR r.id::text ILIKE ${p} ESCAPE '\\')`,
      );
    }
    const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    try {
      await escalateOverdueTerminations(database);
      const [totalResult, rowsResult] = await Promise.all([
        database.query(
          `SELECT count(*)::int AS count
           FROM coach_relationships r
           JOIN users m ON m.id = r.member_id
           JOIN users c ON c.id = r.coach_id
           ${whereClause}`,
          values,
        ),
        database.query(
          `SELECT r.id, r.member_id, r.coach_id, r.status, r.pause_reason,
                  r.started_at, r.paused_at, r.ended_at, r.end_reason,
                  m.full_name AS member_name, m.email::text AS member_email,
                  c.full_name AS coach_name, c.email::text AS coach_email,
                  ae.id AS active_entitlement_id,
                  ae.plan_code AS active_plan_code,
                  ae.plan_name AS active_plan_name,
                  ae.total_sessions AS active_total_sessions,
                  ae.remaining_sessions AS active_remaining_sessions,
                  ae.starts_on::text AS active_starts_on,
                  ae.ends_on::text AS active_ends_on,
                  ae.frozen_at AS active_frozen_at,
                  ae.frozen_days_total AS active_frozen_days_total,
                  ae.grace_days_added AS active_grace_days_added,
                  EXISTS (
                    SELECT 1 FROM coach_entitlements qe
                    WHERE qe.relationship_id = r.id AND qe.status = 'QUEUED'
                  ) AS has_queued_package,
                  ot.id AS open_termination_request_id,
                  ot.status AS open_termination_status,
                  oi.id AS open_incident_id
           FROM coach_relationships r
           JOIN users m ON m.id = r.member_id
           JOIN users c ON c.id = r.coach_id
           LEFT JOIN LATERAL (
             SELECT e.id,
                    COALESCE(e.plan_code, h.plan_code) AS plan_code,
                    COALESCE(e.plan_name, h.plan_name) AS plan_name,
                    e.total_sessions, e.remaining_sessions,
                    e.starts_on, e.ends_on, e.frozen_at,
                    e.frozen_days_total, e.grace_days_added
             FROM coach_entitlements e
             LEFT JOIN coach_payment_holds h ON h.id = COALESCE(e.original_hold_id, e.hold_id)
             WHERE e.relationship_id = r.id AND e.status = 'ACTIVE'
             LIMIT 1
           ) ae ON true
           LEFT JOIN LATERAL (
             SELECT t.id, t.status
             FROM coach_termination_requests t
             WHERE t.relationship_id = r.id
               AND t.status IN ('PENDING_COUNTERPARTY', 'DISPUTED')
             ORDER BY t.created_at DESC
             LIMIT 1
           ) ot ON true
           LEFT JOIN LATERAL (
             SELECT i.id
             FROM coach_lock_incidents i
             WHERE i.relationship_id = r.id AND i.status = 'OPEN'
             LIMIT 1
           ) oi ON true
           ${whereClause}
           ORDER BY (ot.status = 'DISPUTED') DESC NULLS LAST,
                    (r.status = 'ACTIVE') DESC,
                    (r.status = 'PAUSED') DESC,
                    r.started_at DESC, r.id DESC
           LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
          [...values, pageSize, (page - 1) * pageSize],
        ),
      ]);
      const totalItems = totalResult.rows[0].count;
      return response.json({
        data: rowsResult.rows.map(adminRelationshipListView),
        pagination: {
          page,
          pageSize,
          totalItems,
          totalPages: Math.ceil(totalItems / pageSize),
        },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được quan hệ');
    }
  });

  router.get('/admin/relationships/:relationshipId', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    if (!uuid.safeParse(request.params.relationshipId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã quan hệ không hợp lệ');
    }
    const relationshipId = request.params.relationshipId;
    try {
      await escalateOverdueTerminations(database, 'AND relationship_id = $1', [relationshipId]);

      // STRICT PRIVACY ALLOWLIST: only operational metadata (zero member_profiles/plans/nutrition/chat)
      const relResult = await database.query(
        `SELECT r.id, r.member_id, r.coach_id, r.status, r.pause_reason,
                r.started_at, r.paused_at, r.ended_at, r.ended_by, r.end_reason,
                m.full_name AS member_name, m.email::text AS member_email, m.status AS member_status,
                c.full_name AS coach_name, c.email::text AS coach_email, c.status AS coach_status,
                eb.full_name AS ended_by_name,
                (SELECT count(*)::int FROM coach_bookings b
                 JOIN coach_entitlements e ON e.id = b.entitlement_id
                 WHERE e.relationship_id = r.id AND b.status = 'BOOKED'
                   AND b.starts_at > statement_timestamp()) AS upcoming_bookings_count,
                (SELECT count(*)::int FROM coach_payment_holds h
                 WHERE h.member_id = r.member_id AND h.coach_id = r.coach_id
                   AND h.status = 'HELD' AND h.expires_at > statement_timestamp()) AS open_holds_count
         FROM coach_relationships r
         JOIN users m ON m.id = r.member_id
         JOIN users c ON c.id = r.coach_id
         LEFT JOIN users eb ON eb.id = r.ended_by
         WHERE r.id = $1`,
        [relationshipId],
      );
      if (!relResult.rows.length) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy quan hệ');
      }
      const rel = relResult.rows[0];

      const [entitlementsRes, transfersRes, terminationsRes, incidentsRes] = await Promise.all([
        database.query(
          `SELECT e.id,
                  COALESCE(e.plan_code, h.plan_code) AS plan_code,
                  COALESCE(e.plan_name, h.plan_name) AS plan_name,
                  COALESCE(e.snapshot_price, h.amount) AS snapshot_price,
                  e.status, e.total_sessions, e.remaining_sessions, e.duration_days,
                  e.starts_on::text AS starts_on,
                  e.original_ends_on::text AS original_ends_on,
                  e.ends_on::text AS ends_on,
                  e.frozen_at, e.frozen_days_total, e.grace_days_added,
                  e.close_reason, e.ended_at
           FROM coach_entitlements e
           LEFT JOIN coach_payment_holds h ON h.id = COALESCE(e.original_hold_id, e.hold_id)
           WHERE e.relationship_id = $1
           ORDER BY (e.status = 'ACTIVE') DESC, (e.status = 'QUEUED') DESC,
                    e.ended_at DESC NULLS LAST, e.id DESC`,
          [relationshipId],
        ),
        database.query(
          `SELECT t.id, t.member_id, m.full_name AS member_name,
                  t.old_relationship_id, t.new_relationship_id,
                  t.old_coach_id, oc.full_name AS old_coach_name,
                  t.new_coach_id, nc.full_name AS new_coach_name,
                  t.reason, t.admin_id, adm.full_name AS admin_name,
                  t.created_at
           FROM coach_transfer_history t
           JOIN users m ON m.id = t.member_id
           JOIN users oc ON oc.id = t.old_coach_id
           JOIN users nc ON nc.id = t.new_coach_id
           JOIN users adm ON adm.id = t.admin_id
           WHERE t.old_relationship_id = $1 OR t.new_relationship_id = $1
           ORDER BY t.created_at DESC, t.id DESC`,
          [relationshipId],
        ),
        database.query(
          `${TERMINATION_SELECT_SQL}
           WHERE t.relationship_id = $1
           ORDER BY t.created_at DESC, t.id DESC`,
          [relationshipId],
        ),
        database.query(
          `SELECT i.id, i.coach_id, i.member_id, i.relationship_id,
                  i.active_entitlement_id, i.queued_entitlement_id,
                  i.lock_reason, i.locked_by, lb.full_name AS locked_by_name,
                  i.locked_at, i.frozen_started_at, i.frozen_ended_at,
                  i.frozen_days_applied, i.member_choice, i.member_choice_at,
                  i.member_choice_note, i.status, i.transfer_history_id,
                  i.refund_batch_id, i.resolved_by, rb.full_name AS resolved_by_name,
                  i.resolved_at, i.created_at
           FROM coach_lock_incidents i
           LEFT JOIN users lb ON lb.id = i.locked_by
           LEFT JOIN users rb ON rb.id = i.resolved_by
           WHERE i.relationship_id = $1
           ORDER BY i.created_at DESC, i.id DESC`,
          [relationshipId],
        ),
      ]);

      const entitlements = entitlementsRes.rows.map(operationalEntitlementView);
      const activeEntitlement = entitlements.find((e) => e.status === 'ACTIVE') ?? null;
      const queuedEntitlement = entitlements.find((e) => e.status === 'QUEUED') ?? null;
      const terminationRequests = terminationsRes.rows.map(terminationView);
      const openTerm = terminationRequests.find((t) =>
        t.status === 'PENDING_COUNTERPARTY' || t.status === 'DISPUTED') ?? null;

      return response.json({
        data: {
          id: rel.id,
          memberId: rel.member_id,
          memberName: rel.member_name,
          memberEmail: rel.member_email,
          memberStatus: rel.member_status,
          coachId: rel.coach_id,
          coachName: rel.coach_name,
          coachEmail: rel.coach_email,
          coachStatus: rel.coach_status,
          status: rel.status,
          pauseReason: rel.pause_reason ?? null,
          startedAt: rel.started_at,
          pausedAt: rel.paused_at ?? null,
          endedAt: rel.ended_at ?? null,
          endedBy: rel.ended_by ?? null,
          endedByName: rel.ended_by_name ?? null,
          endReason: rel.end_reason ?? null,
          upcomingBookingsCount: rel.upcoming_bookings_count,
          openHoldsCount: rel.open_holds_count,
          activeEntitlement,
          queuedEntitlement,
          hasQueuedPackage: Boolean(queuedEntitlement),
          openTerminationStatus: openTerm?.status ?? null,
          entitlements,
          transferHistory: transfersRes.rows.map(transferHistoryView),
          terminationRequests,
          lockIncidents: incidentsRes.rows.map(lockIncidentSummaryView),
        },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được chi tiết quan hệ');
    }
  });

  router.get('/admin/termination-requests', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    const parsed = adminTerminationsQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Bộ lọc yêu cầu kết thúc sớm không hợp lệ');
    }
    const { status, search, page, pageSize } = parsed.data;
    const filters = [];
    const values = [];
    if (status) {
      values.push(status);
      filters.push(`t.status = $${values.length}`);
    }
    if (search) {
      values.push(`%${escapeLike(search)}%`);
      const p = `$${values.length}`;
      filters.push(
        `(m.full_name ILIKE ${p} ESCAPE '\\' OR m.email::text ILIKE ${p} ESCAPE '\\' OR c.full_name ILIKE ${p} ESCAPE '\\' OR c.email::text ILIKE ${p} ESCAPE '\\' OR t.reason ILIKE ${p} ESCAPE '\\' OR COALESCE(t.counterparty_reason, '') ILIKE ${p} ESCAPE '\\' OR COALESCE(t.admin_note, '') ILIKE ${p} ESCAPE '\\' OR t.id::text ILIKE ${p} ESCAPE '\\')`,
      );
    }
    const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    try {
      await escalateOverdueTerminations(database);
      const [totalRes, rowsRes] = await Promise.all([
        database.query(
          `SELECT count(*)::int AS count
           FROM coach_termination_requests t
           JOIN coach_relationships r ON r.id = t.relationship_id
           JOIN users m ON m.id = r.member_id
           JOIN users c ON c.id = r.coach_id
           ${whereClause}`,
          values,
        ),
        database.query(
          `${TERMINATION_SELECT_SQL}
           ${whereClause}
           ORDER BY (t.status = 'DISPUTED') DESC,
                    t.disputed_at DESC NULLS LAST,
                    t.created_at DESC, t.id DESC
           LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
          [...values, pageSize, (page - 1) * pageSize],
        ),
      ]);
      const totalItems = totalRes.rows[0].count;
      return response.json({
        data: rowsRes.rows.map(terminationView),
        pagination: {
          page,
          pageSize,
          totalItems,
          totalPages: Math.ceil(totalItems / pageSize),
        },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được yêu cầu kết thúc sớm');
    }
  });

  router.patch('/admin/termination-requests/:requestId', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    if (!uuid.safeParse(request.params.requestId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã yêu cầu không hợp lệ');
    }
    const parsed = adminTerminationDecisionSchema.safeParse(request.body);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Quyết định hoặc lý do phán quyết không hợp lệ');
    }
    const { decision, reason } = parsed.data;

    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      // Canonical lock order step 2: activeAdmin FOR SHARE
      if (!await activeAdmin(client, request.authUser)) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }

      const peek = await client.query(
        `SELECT t.id, t.relationship_id, r.coach_id, r.member_id
         FROM coach_termination_requests t
         JOIN coach_relationships r ON r.id = t.relationship_id
         WHERE t.id = $1`,
        [request.params.requestId],
      );
      if (!peek.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy yêu cầu kết thúc sớm');
      }
      const target = peek.rows[0];

      // Canonical lock order steps 3-6: Coach -> Member -> relationship -> entitlements -> termination request
      await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [target.coach_id]);
      await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [target.member_id]);
      const rel = (await client.query(
        'SELECT * FROM coach_relationships WHERE id = $1 FOR UPDATE',
        [target.relationship_id],
      )).rows[0];
      const lockedEntitlements = (await client.query(
        `SELECT * FROM coach_entitlements
         WHERE relationship_id = $1 AND status IN ('ACTIVE', 'QUEUED')
         ORDER BY id ASC FOR UPDATE`,
        [target.relationship_id],
      )).rows;
      let item = (await client.query(
        `SELECT *, (response_deadline_at <= statement_timestamp()) AS deadline_expired
         FROM coach_termination_requests WHERE id = $1 FOR UPDATE`,
        [target.id],
      )).rows[0];

      if (!item) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy yêu cầu kết thúc sớm');
      }

      // Inline 72h timeout escalation inside transaction
      if (item.status === 'PENDING_COUNTERPARTY' && item.deadline_expired) {
        item = (await client.query(
          `UPDATE coach_termination_requests
           SET status = 'DISPUTED',
               disputed_at = response_deadline_at,
               escalation_reason = 'TIMEOUT_72H'
           WHERE id = $1
           RETURNING *`,
          [item.id],
        )).rows[0];
        await client.query(
          `INSERT INTO coach_notifications (user_id, kind, subject_id)
           VALUES ($1, 'TERMINATION_DISPUTED', $3),
                  ($2, 'TERMINATION_DISPUTED', $3)`,
          [item.requested_by_user_id, item.counterparty_user_id, item.id],
        );
      }

      if (item.status !== 'DISPUTED') {
        await client.query('ROLLBACK');
        return fail(
          response,
          409,
          'NOT_DISPUTED',
          'Chỉ được phán quyết khi yêu cầu đã ở trạng thái tranh chấp (DISPUTED)',
        );
      }

      if (!rel || rel.status === 'ENDED') {
        await client.query('ROLLBACK');
        return fail(response, 409, 'RELATIONSHIP_ENDED', 'Quan hệ đã kết thúc');
      }
      if (rel.status === 'PAUSED' && rel.pause_reason === 'COACH_LOCKED') {
        await client.query('ROLLBACK');
        return fail(
          response,
          409,
          'USE_COACH_INCIDENT_FLOW',
          'Quan hệ đang tạm ngưng do Coach bị khóa; vui lòng xử lý qua luồng sự cố khóa Coach',
        );
      }

      const targetStatus = decision === 'APPROVED' ? 'ADMIN_APPROVED' : 'ADMIN_REJECTED';
      await client.query(
        `UPDATE coach_termination_requests
         SET status = $1,
             admin_note = $2,
             decided_by = $3,
             decided_at = statement_timestamp()
         WHERE id = $4`,
        [targetStatus, reason, request.authUser.id, item.id],
      );

      let effects;
      if (decision === 'APPROVED') {
        effects = await executeEarlyTermination(client, {
          relationship: rel,
          lockedEntitlements,
          endedBy: request.authUser.id,
          endReason: reason,
        });
        await client.query(
          `INSERT INTO coach_notifications (user_id, kind, subject_id)
           VALUES ($1, 'TERMINATION_ADMIN_APPROVED', $3),
                  ($2, 'TERMINATION_ADMIN_APPROVED', $3)`,
          [rel.member_id, rel.coach_id, item.id],
        );
      } else {
        effects = {
          relationshipStatus: rel.status,
          forfeitedActiveSessions: 0,
          forfeitedQueuedPackage: false,
          cancelledFutureBookingsCount: 0,
          plansArchived: false,
          coachSeatReleased: false,
        };
        await client.query(
          `INSERT INTO coach_notifications (user_id, kind, subject_id)
           VALUES ($1, 'TERMINATION_ADMIN_REJECTED', $3),
                  ($2, 'TERMINATION_ADMIN_REJECTED', $3)`,
          [rel.member_id, rel.coach_id, item.id],
        );
      }

      await client.query(
        `INSERT INTO admin_audit_logs
         (id, admin_id, action, entity_type, entity_id, summary, metadata)
         VALUES ($1, $2, 'TERMINATION_DISPUTE_DECIDED', 'COACH_RELATIONSHIP', $3, $4, $5)`,
        [
          randomUUID(),
          request.authUser.id,
          rel.id,
          decision === 'APPROVED'
            ? 'Phán quyết chấp thuận kết thúc sớm quan hệ Coach'
            : 'Phán quyết bác bỏ yêu cầu kết thúc sớm quan hệ Coach',
          JSON.stringify({
            requestId: item.id,
            relationshipId: rel.id,
            memberId: rel.member_id,
            coachId: rel.coach_id,
            requestedByRole: item.requested_by_role,
            escalationReason: item.escalation_reason,
            decision,
            resultingStatus: targetStatus,
            reason,
            effects,
          }),
        ],
      );

      const fullRow = await fetchTerminationRow(client, item.id);
      await client.query('COMMIT');
      return response.json({ data: { ...terminationView(fullRow), effects } });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không xử lý được phán quyết tranh chấp');
    } finally { client.release(); }
  });

  router.post('/admin/coach-transfers', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    const parsed = z.strictObject({
      memberId: uuid,
      newCoachId: uuid,
      reason: z.string().trim().min(1).max(1000),
    }).safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu chuyển Coach không hợp lệ');

    const rawKey = request.get('idempotency-key');
    let idempotencyKey = null;
    if (rawKey !== undefined) {
      const parsedKey = uuid.safeParse(rawKey);
      if (!parsedKey.success) {
        return fail(response, 422, 'VALIDATION_ERROR', 'Header Idempotency-Key phải là UUID hợp lệ');
      }
      idempotencyKey = parsedKey.data;
    }

    const result = await executeCoachTransfer(database, {
      adminUser: request.authUser,
      memberId: parsed.data.memberId,
      newCoachId: parsed.data.newCoachId,
      reason: parsed.data.reason,
      idempotencyKey,
      mode: 'DIRECT',
    });

    if (!result.ok) {
      return fail(response, result.status, result.code, result.message, result.details);
    }
    return response.status(result.status).json({ data: result.data });
  });

  router.get('/admin/coach-transfers', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    const parsed = adminTransfersQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Bộ lọc lịch sử chuyển Coach không hợp lệ');
    }
    const { memberId, oldCoachId, newCoachId, from, to, search, page, pageSize } = parsed.data;
    if (from && to && from > to) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Khoảng ngày lọc không hợp lệ');
    }
    const filters = [];
    const values = [];
    if (memberId) {
      values.push(memberId);
      filters.push(`t.member_id = $${values.length}`);
    }
    if (oldCoachId) {
      values.push(oldCoachId);
      filters.push(`t.old_coach_id = $${values.length}`);
    }
    if (newCoachId) {
      values.push(newCoachId);
      filters.push(`t.new_coach_id = $${values.length}`);
    }
    if (from) {
      values.push(from);
      filters.push(`t.created_at >= ($${values.length}::date::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh')`);
    }
    if (to) {
      values.push(to);
      filters.push(`t.created_at < (($${values.length}::date + 1)::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh')`);
    }
    if (search) {
      values.push(`%${escapeLike(search)}%`);
      const p = `$${values.length}`;
      filters.push(
        `(m.full_name ILIKE ${p} ESCAPE '\\' OR oc.full_name ILIKE ${p} ESCAPE '\\' OR nc.full_name ILIKE ${p} ESCAPE '\\' OR adm.full_name ILIKE ${p} ESCAPE '\\' OR t.reason ILIKE ${p} ESCAPE '\\' OR t.id::text ILIKE ${p} ESCAPE '\\')`,
      );
    }
    const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    try {
      const [totalRes, rowsRes] = await Promise.all([
        database.query(
          `SELECT count(*)::int AS count
           FROM coach_transfer_history t
           JOIN users m ON m.id = t.member_id
           JOIN users oc ON oc.id = t.old_coach_id
           JOIN users nc ON nc.id = t.new_coach_id
           JOIN users adm ON adm.id = t.admin_id
           ${whereClause}`,
          values,
        ),
        database.query(
          `SELECT t.id, t.member_id, m.full_name AS member_name,
                  t.old_relationship_id, t.new_relationship_id,
                  t.old_coach_id, oc.full_name AS old_coach_name,
                  t.new_coach_id, nc.full_name AS new_coach_name,
                  t.reason, t.admin_id, adm.full_name AS admin_name,
                  t.created_at
           FROM coach_transfer_history t
           JOIN users m ON m.id = t.member_id
           JOIN users oc ON oc.id = t.old_coach_id
           JOIN users nc ON nc.id = t.new_coach_id
           JOIN users adm ON adm.id = t.admin_id
           ${whereClause}
           ORDER BY t.created_at DESC, t.id DESC
           LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
          [...values, pageSize, (page - 1) * pageSize],
        ),
      ]);
      const totalItems = totalRes.rows[0].count;
      return response.json({
        data: rowsRes.rows.map(transferHistoryView),
        pagination: {
          page,
          pageSize,
          totalItems,
          totalPages: Math.ceil(totalItems / pageSize),
        },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được lịch sử chuyển Coach');
    }
  });

  return router;
}
