import { Router } from 'express';
import { z } from 'zod';

import { isCoachScheduleConfigured } from '../services/coach-capacity.js';
import {
  buildD2TransferProposals,
  checkD2Capacity,
  computeActiveSimulatedRefund,
  executeCoachTransfer,
} from '../services/coach-transfer.js';
import { executeSimulatedRefund } from '../services/simulated-refunds.js';
import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();

const memberChoiceSchema = z.strictObject({
  choice: z.enum(['WAIT', 'REFUND']),
  note: z.string().trim().max(500).nullable().optional(),
});

const incidentListQuerySchema = z.strictObject({
  status: z.enum([
    'OPEN',
    'RESOLVED_COACH_UNLOCKED',
    'RESOLVED_TRANSFERRED',
    'RESOLVED_REFUNDED',
    'RESOLVED_ENDED',
  ]).optional(),
  coachId: uuid.optional(),
  memberChoice: z.enum(['WAIT', 'REFUND']).optional(),
  search: z.string().trim().max(120).optional(),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});

const incidentTransferBodySchema = z.strictObject({
  newCoachId: uuid,
  reason: z.string().trim().min(1).max(1000),
});

const simulatedRefundBodySchema = z.strictObject({
  reason: z.string().trim().min(1).max(500),
});

const simulatedRefundListQuerySchema = z.strictObject({
  memberId: uuid.optional(),
  coachId: uuid.optional(),
  incidentId: uuid.optional(),
  from: z.iso.date().optional(),
  to: z.iso.date().optional(),
  search: z.string().trim().max(120).optional(),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});

function simulatedRefundView(row) {
  return {
    id: row.id,
    refundBatchId: row.refund_batch_id,
    incidentId: row.incident_id,
    coachEntitlementId: row.coach_entitlement_id,
    relationshipId: row.relationship_id,
    memberId: row.member_id,
    memberName: row.member_name,
    memberEmail: row.member_email,
    coachId: row.coach_id,
    coachName: row.coach_name,
    coachEmail: row.coach_email,
    entitlementKind: row.entitlement_kind,
    planCode: row.plan_code ?? null,
    planName: row.plan_name ?? null,
    snapshotPrice: Number(row.snapshot_price),
    totalSessions: Number(row.total_sessions),
    remainingSessions: Number(row.remaining_sessions),
    refundAmount: Number(row.refund_amount),
    status: row.status,
    reason: row.reason,
    createdBy: row.created_by,
    createdByName: row.created_by_name ?? null,
    createdAt: row.created_at,
  };
}

function fail(response, status, code, message, details = {}) {
  return response.status(status).json({ error: { code, message, details } });
}

function escapeLike(value) {
  return value.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
}

function incidentQueueItemView(row) {
  const activeSnapshotPrice = row.active_snapshot_price === null || row.active_snapshot_price === undefined
    ? null
    : Number(row.active_snapshot_price);
  const queuedSnapshotPrice = row.queued_snapshot_price === null || row.queued_snapshot_price === undefined
    ? null
    : Number(row.queued_snapshot_price);

  const activeEntitlement = row.active_entitlement_id ? {
    id: row.active_entitlement_id,
    planCode: row.active_plan_code ?? null,
    planName: row.active_plan_name ?? null,
    snapshotPrice: activeSnapshotPrice,
    status: row.active_status,
    totalSessions: row.active_total_sessions,
    remainingSessions: row.active_remaining_sessions,
    durationDays: row.active_duration_days,
    startsOn: row.active_starts_on ?? null,
    originalEndsOn: row.active_original_ends_on ?? null,
    endsOn: row.active_ends_on ?? null,
    frozenAt: row.active_frozen_at ?? null,
    frozenDaysTotal: row.active_frozen_days_total ?? 0,
    graceDaysAdded: row.active_grace_days_added ?? 0,
  } : null;

  const queuedEntitlement = row.queued_entitlement_id ? {
    id: row.queued_entitlement_id,
    planCode: row.queued_plan_code ?? null,
    planName: row.queued_plan_name ?? null,
    snapshotPrice: queuedSnapshotPrice,
    status: row.queued_status,
    totalSessions: row.queued_total_sessions,
    remainingSessions: row.queued_remaining_sessions,
    durationDays: row.queued_duration_days,
  } : null;

  const estimatedActiveRefund = activeEntitlement
    ? computeActiveSimulatedRefund(
        activeEntitlement.snapshotPrice,
        activeEntitlement.remainingSessions,
        activeEntitlement.totalSessions,
      )
    : 0;
  const estimatedQueuedRefund = queuedEntitlement && queuedEntitlement.snapshotPrice !== null
    ? queuedEntitlement.snapshotPrice
    : 0;
  const estimatedTotalRefund = estimatedActiveRefund + estimatedQueuedRefund;

  return {
    id: row.id,
    coachId: row.coach_id,
    coachName: row.coach_name,
    coachEmail: row.coach_email,
    memberId: row.member_id,
    memberName: row.member_name,
    memberEmail: row.member_email,
    relationshipId: row.relationship_id,
    relationshipStatus: row.relationship_status,
    relationshipPauseReason: row.relationship_pause_reason ?? null,
    lockReason: row.lock_reason,
    lockedBy: row.locked_by,
    lockedByName: row.locked_by_name ?? null,
    lockedAt: row.locked_at,
    frozenStartedAt: row.frozen_started_at ?? null,
    frozenEndedAt: row.frozen_ended_at ?? null,
    frozenDaysApplied: row.frozen_days_applied ?? null,
    frozenDaysCurrent: Number(row.frozen_days_current ?? 0),
    memberChoice: row.member_choice,
    memberChoiceAt: row.member_choice_at ?? null,
    memberChoiceNote: row.member_choice_note ?? null,
    status: row.status,
    transferHistoryId: row.transfer_history_id ?? null,
    refundBatchId: row.refund_batch_id ?? null,
    resolvedBy: row.resolved_by ?? null,
    resolvedByName: row.resolved_by_name ?? null,
    resolvedAt: row.resolved_at ?? null,
    memberGymMembershipStatus: row.member_gym_membership_status,
    memberGymMembershipEndDate: row.member_gym_membership_end_date ?? null,
    activeEntitlement,
    queuedEntitlement,
    estimatedActiveRefund,
    estimatedQueuedRefund,
    estimatedTotalRefund,
    createdAt: row.created_at,
  };
}

export function createCoachIncidentsRouter({ database, jwtSecret }) {
  const router = Router();
  router.use(
    ['/relationships/me/coach-lock-choice', '/admin/coach-incidents', '/admin/simulated-refunds'],
    createAuthentication({ database, jwtSecret }),
  );

  // =========================================================================
  // MEMBER: Submit WAIT / REFUND choice for an open COACH_LOCKED incident
  // =========================================================================
  router.post('/relationships/me/coach-lock-choice', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') {
      return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được gửi lựa chọn xử lý sự cố khóa Coach');
    }
    const parsed = memberChoiceSchema.safeParse(request.body);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Lựa chọn hoặc ghi chú không hợp lệ');
    }
    const { choice, note } = parsed.data;
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const member = await client.query(
        `SELECT id FROM users
         WHERE id = $1 AND role = 'MEMBER' AND status = 'ACTIVE' AND session_version = $2
         FOR UPDATE`,
        [request.authUser.id, request.authUser.session_version],
      );
      if (!member.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }

      const rel = (await client.query(
        `SELECT * FROM coach_relationships
         WHERE member_id = $1 AND status IN ('ACTIVE', 'PAUSED')
         ORDER BY id ASC FOR UPDATE`,
        [request.authUser.id],
      )).rows[0] ?? null;

      if (!rel || rel.status !== 'PAUSED' || rel.pause_reason !== 'COACH_LOCKED') {
        await client.query('ROLLBACK');
        return fail(
          response,
          409,
          'NO_OPEN_COACH_LOCK_INCIDENT',
          'Hiện không có sự cố khóa Coach đang mở cho quan hệ của bạn',
        );
      }

      const incident = (await client.query(
        `SELECT * FROM coach_lock_incidents
         WHERE relationship_id = $1 AND status = 'OPEN'
         ORDER BY id ASC FOR UPDATE`,
        [rel.id],
      )).rows[0] ?? null;

      if (!incident) {
        await client.query('ROLLBACK');
        return fail(
          response,
          409,
          'NO_OPEN_COACH_LOCK_INCIDENT',
          'Hiện không có sự cố khóa Coach đang mở cho quan hệ của bạn',
        );
      }

      const { rows: [updated] } = await client.query(
        `UPDATE coach_lock_incidents
         SET member_choice = $2,
             member_choice_at = statement_timestamp(),
             member_choice_note = $3
         WHERE id = $1 AND status = 'OPEN'
         RETURNING id, relationship_id, coach_id, member_id, status,
                   member_choice, member_choice_at, member_choice_note`,
        [incident.id, choice, note ?? null],
      );

      await client.query('COMMIT');
      return response.json({
        data: {
          id: updated.id,
          incidentId: updated.id,
          relationshipId: updated.relationship_id,
          coachId: updated.coach_id,
          memberId: updated.member_id,
          status: updated.status,
          memberChoice: updated.member_choice,
          memberChoiceAt: updated.member_choice_at,
          memberChoiceNote: updated.member_choice_note ?? null,
        },
      });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không lưu được lựa chọn xử lý sự cố');
    } finally {
      client.release();
    }
  });

  // =========================================================================
  // ADMIN: Coach Lock Incident Queue, Eligible Coaches, and D2 Transfer
  // =========================================================================
  router.use(['/admin/coach-incidents', '/admin/simulated-refunds'], (request, response, next) =>
    request.authUser.role === 'ADMIN'
      ? next()
      : fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị'));

  router.get('/admin/coach-incidents', async (request, response) => {
    const parsed = incidentListQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Bộ lọc hàng chờ sự cố khóa Coach không hợp lệ');
    }
    const { status, coachId, memberChoice, search, page, pageSize } = parsed.data;
    const filters = [];
    const values = [];

    if (status) {
      values.push(status);
      filters.push(`i.status = $${values.length}`);
    }
    if (coachId) {
      values.push(coachId);
      filters.push(`i.coach_id = $${values.length}`);
    }
    if (memberChoice) {
      values.push(memberChoice);
      filters.push(`i.member_choice = $${values.length}`);
    }
    if (search) {
      values.push(`%${escapeLike(search)}%`);
      const p = `$${values.length}`;
      filters.push(
        `(m.full_name ILIKE ${p} ESCAPE '\\' OR m.email::text ILIKE ${p} ESCAPE '\\' OR c.full_name ILIKE ${p} ESCAPE '\\' OR c.email::text ILIKE ${p} ESCAPE '\\' OR i.lock_reason ILIKE ${p} ESCAPE '\\' OR COALESCE(i.member_choice_note, '') ILIKE ${p} ESCAPE '\\' OR i.id::text ILIKE ${p} ESCAPE '\\')`,
      );
    }

    const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    try {
      const [totalRes, rowsRes] = await Promise.all([
        database.query(
          `SELECT count(*)::int AS count
           FROM coach_lock_incidents i
           JOIN users m ON m.id = i.member_id
           JOIN users c ON c.id = i.coach_id
           ${whereClause}`,
          values,
        ),
        database.query(
          `SELECT i.id, i.coach_id, i.member_id, i.relationship_id,
                  i.active_entitlement_id, i.queued_entitlement_id,
                  i.lock_reason, i.locked_by, i.locked_at,
                  i.frozen_started_at, i.frozen_ended_at, i.frozen_days_applied,
                  i.member_choice, i.member_choice_at, i.member_choice_note,
                  i.status, i.transfer_history_id, i.refund_batch_id,
                  i.resolved_by, i.resolved_at, i.created_at,
                  m.full_name AS member_name, m.email::text AS member_email,
                  c.full_name AS coach_name, c.email::text AS coach_email,
                  lb.full_name AS locked_by_name,
                  rb.full_name AS resolved_by_name,
                  r.status AS relationship_status,
                  r.pause_reason AS relationship_pause_reason,
                  CASE
                    WHEN i.status = 'OPEN' AND i.frozen_started_at IS NOT NULL
                    THEN GREATEST(
                      0,
                      ((statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
                        - (i.frozen_started_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date)
                    )::int
                    WHEN i.status <> 'OPEN'
                    THEN COALESCE(i.frozen_days_applied, 0)
                    ELSE 0
                  END AS frozen_days_current,
                  CASE
                    WHEN EXISTS (
                      SELECT 1 FROM member_memberships mm
                      WHERE mm.member_id = i.member_id
                        AND mm.status = 'ACTIVE'
                        AND (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
                            BETWEEN mm.start_date AND mm.end_date
                    ) THEN 'ACTIVE'
                    WHEN EXISTS (
                      SELECT 1 FROM member_memberships mm
                      WHERE mm.member_id = i.member_id
                        AND mm.status = 'SCHEDULED'
                        AND mm.start_date > (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
                    ) THEN 'SCHEDULED'
                    WHEN EXISTS (
                      SELECT 1 FROM member_memberships mm
                      WHERE mm.member_id = i.member_id
                        AND (
                          mm.status = 'EXPIRED'
                          OR (
                            mm.status = 'ACTIVE'
                            AND mm.end_date < (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
                          )
                        )
                    ) THEN 'EXPIRED'
                    ELSE 'NONE'
                  END AS member_gym_membership_status,
                  (SELECT mm.end_date::text
                   FROM member_memberships mm
                   WHERE mm.member_id = i.member_id
                     AND mm.status = 'ACTIVE'
                     AND (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
                         BETWEEN mm.start_date AND mm.end_date
                   ORDER BY mm.end_date DESC
                   LIMIT 1) AS member_gym_membership_end_date,
                  COALESCE(ae.plan_code, ah.plan_code) AS active_plan_code,
                  COALESCE(ae.plan_name, ah.plan_name) AS active_plan_name,
                  COALESCE(ae.snapshot_price, ah.amount) AS active_snapshot_price,
                  ae.status AS active_status,
                  ae.total_sessions AS active_total_sessions,
                  ae.remaining_sessions AS active_remaining_sessions,
                  ae.duration_days AS active_duration_days,
                  ae.starts_on::text AS active_starts_on,
                  ae.original_ends_on::text AS active_original_ends_on,
                  ae.ends_on::text AS active_ends_on,
                  ae.frozen_at AS active_frozen_at,
                  ae.frozen_days_total AS active_frozen_days_total,
                  ae.grace_days_added AS active_grace_days_added,
                  COALESCE(qe.plan_code, qh.plan_code) AS queued_plan_code,
                  COALESCE(qe.plan_name, qh.plan_name) AS queued_plan_name,
                  COALESCE(qe.snapshot_price, qh.amount) AS queued_snapshot_price,
                  qe.status AS queued_status,
                  qe.total_sessions AS queued_total_sessions,
                  qe.remaining_sessions AS queued_remaining_sessions,
                  qe.duration_days AS queued_duration_days
           FROM coach_lock_incidents i
           JOIN coach_relationships r ON r.id = i.relationship_id
           JOIN users m ON m.id = i.member_id
           JOIN users c ON c.id = i.coach_id
           LEFT JOIN users lb ON lb.id = i.locked_by
           LEFT JOIN users rb ON rb.id = i.resolved_by
           LEFT JOIN coach_entitlements ae ON ae.id = i.active_entitlement_id
           LEFT JOIN coach_payment_holds ah ON ah.id = COALESCE(ae.original_hold_id, ae.hold_id)
           LEFT JOIN coach_entitlements qe ON qe.id = i.queued_entitlement_id
           LEFT JOIN coach_payment_holds qh ON qh.id = COALESCE(qe.original_hold_id, qe.hold_id)
           ${whereClause}
           ORDER BY (i.status = 'OPEN') DESC,
                    (i.member_choice = 'REFUND') DESC,
                    i.locked_at DESC,
                    i.id DESC
           LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
          [...values, pageSize, (page - 1) * pageSize],
        ),
      ]);

      const totalItems = totalRes.rows[0].count;
      return response.json({
        data: rowsRes.rows.map(incidentQueueItemView),
        pagination: {
          page,
          pageSize,
          totalItems,
          totalPages: Math.ceil(totalItems / pageSize),
        },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được danh sách sự cố khóa Coach');
    }
  });

  router.get('/admin/coach-incidents/:incidentId/eligible-coaches', async (request, response) => {
    if (!uuid.safeParse(request.params.incidentId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã sự cố không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      const incidentRes = await client.query(
        `SELECT i.id, i.coach_id, i.member_id, i.relationship_id,
                i.status, i.frozen_started_at, i.frozen_days_applied,
                (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS today_vn,
                CASE
                  WHEN i.frozen_started_at IS NOT NULL AND i.frozen_days_applied IS NULL
                  THEN GREATEST(
                    0,
                    ((statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
                      - (i.frozen_started_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date)
                  )::int
                  ELSE 0
                END AS computed_delta_days
         FROM coach_lock_incidents i
         WHERE i.id = $1`,
        [request.params.incidentId],
      );
      if (!incidentRes.rows.length) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy sự cố khóa Coach');
      }
      const incident = incidentRes.rows[0];
      if (incident.status !== 'OPEN') {
        return fail(response, 409, 'INCIDENT_ALREADY_RESOLVED', 'Sự cố khóa Coach này đã được xử lý trước đó');
      }

      const entRows = (await client.query(
        `SELECT e.*,
                e.starts_on::text AS starts_on_text,
                e.original_ends_on::text AS original_ends_on_text,
                e.ends_on::text AS ends_on_text
         FROM coach_entitlements e
         WHERE e.relationship_id = $1 AND e.status IN ('ACTIVE', 'QUEUED')
         ORDER BY e.id ASC`,
        [incident.relationship_id],
      )).rows;
      const activeEntitlement = entRows.find((e) => e.status === 'ACTIVE') ?? null;
      const queuedEntitlement = entRows.find((e) => e.status === 'QUEUED') ?? null;
      const frozenDaysAdded = activeEntitlement && activeEntitlement.frozen_at && incident.frozen_days_applied === null
        ? Math.max(0, Number(incident.computed_delta_days ?? 0))
        : 0;

      const proposalBundle = await buildD2TransferProposals(client, {
        memberId: incident.member_id,
        oldRelationshipId: incident.relationship_id,
        activeEntitlement,
        queuedEntitlement,
        frozenDaysAdded,
        todayVn: incident.today_vn,
      });

      const candidates = (await client.query(
        `SELECT u.id, u.full_name, u.email::text,
                LEAST(c.member_limit, 8) AS member_limit,
                coach_occupied_seats(u.id) AS used_slots
         FROM users u
         JOIN coach_profiles c ON c.user_id = u.id
         WHERE u.role = 'COACH'
           AND u.status = 'ACTIVE'
           AND u.id <> $1
         ORDER BY u.full_name ASC, u.id ASC`,
        [incident.coach_id],
      )).rows;

      const slotsByCoach = new Map();
      if (candidates.length) {
        const { rows: slotRows } = await client.query(
          `SELECT coach_id, weekday, start_minute
           FROM coach_weekly_slots
           WHERE coach_id = ANY($1::uuid[])
           ORDER BY coach_id, weekday ASC, start_minute ASC`,
          [candidates.map((c) => c.id)],
        );
        for (const row of slotRows) {
          let list = slotsByCoach.get(row.coach_id);
          if (!list) {
            list = [];
            slotsByCoach.set(row.coach_id, list);
          }
          list.push(row);
        }
      }

      const evaluated = [];
      for (const candidate of candidates) {
        const usedSlots = Number(candidate.used_slots);
        const memberLimit = Math.min(8, Number(candidate.member_limit));
        const seatAvailable = usedSlots < memberLimit;
        const scheduleConfigured = isCoachScheduleConfigured(slotsByCoach.get(candidate.id) ?? []);
        const capacityEligibleForActiveAndQueued = scheduleConfigured
          ? await checkD2Capacity(client, candidate.id, proposalBundle)
          : false;

        let ineligibleReason = null;
        if (!seatAvailable) {
          ineligibleReason = 'COACH_FULL';
        } else if (!scheduleConfigured) {
          ineligibleReason = 'SCHEDULE_REQUIRED';
        } else if (!capacityEligibleForActiveAndQueued) {
          ineligibleReason = 'CAPACITY_UNAVAILABLE';
        }

        evaluated.push({
          id: candidate.id,
          coachId: candidate.id,
          fullName: candidate.full_name,
          email: candidate.email,
          usedSlots,
          memberLimit,
          availableSlots: Math.max(0, memberLimit - usedSlots),
          seatAvailable,
          scheduleConfigured,
          capacityEligibleForActiveAndQueued,
          eligible: ineligibleReason === null,
          checkedEntitlements: proposalBundle.checkedEntitlements,
          ineligibleReason,
        });
      }

      evaluated.sort((a, b) => {
        if (a.eligible !== b.eligible) return a.eligible ? -1 : 1;
        if (a.usedSlots !== b.usedSlots) return a.usedSlots - b.usedSlots;
        return a.fullName.localeCompare(b.fullName) || a.id.localeCompare(b.id);
      });

      return response.json({ data: evaluated });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kiểm tra được danh sách Coach đủ điều kiện');
    } finally {
      client.release();
    }
  });

  router.post('/admin/coach-incidents/:incidentId/transfer', async (request, response) => {
    if (!uuid.safeParse(request.params.incidentId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã sự cố không hợp lệ');
    }
    const idempotencyKey = uuid.safeParse(request.get('idempotency-key'));
    if (!idempotencyKey.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Thiếu hoặc sai định dạng header Idempotency-Key (UUID)');
    }
    const parsed = incidentTransferBodySchema.safeParse(request.body);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu chuyển Coach không hợp lệ');
    }

    const result = await executeCoachTransfer(database, {
      adminUser: request.authUser,
      incidentId: request.params.incidentId,
      newCoachId: parsed.data.newCoachId,
      reason: parsed.data.reason,
      idempotencyKey: idempotencyKey.data,
      mode: 'INCIDENT',
    });

    if (!result.ok) {
      return fail(response, result.status, result.code, result.message, result.details);
    }
    return response.status(result.status).json({ data: result.data });
  });

  // =========================================================================
  // ADMIN: D2 + D3 Simulated Refunds Execution & History
  // =========================================================================
  router.post('/admin/coach-incidents/:incidentId/simulated-refunds', async (request, response) => {
    if (!uuid.safeParse(request.params.incidentId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã sự cố không hợp lệ');
    }
    const idempotencyKey = uuid.safeParse(request.get('idempotency-key'));
    if (!idempotencyKey.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Thiếu hoặc sai định dạng header Idempotency-Key (UUID)');
    }
    const parsed = simulatedRefundBodySchema.safeParse(request.body);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Lý do hoàn tiền mô phỏng không hợp lệ (1–500 ký tự)');
    }

    const result = await executeSimulatedRefund(database, {
      adminUser: request.authUser,
      incidentId: request.params.incidentId,
      reason: parsed.data.reason,
      idempotencyKey: idempotencyKey.data,
    });

    if (!result.ok) {
      return fail(response, result.status, result.code, result.message, result.details);
    }
    return response.status(result.status).json({ data: result.data });
  });

  router.get('/admin/simulated-refunds', async (request, response) => {
    const parsed = simulatedRefundListQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Bộ lọc lịch sử hoàn tiền mô phỏng không hợp lệ');
    }
    const { memberId, coachId, incidentId, from, to, search, page, pageSize } = parsed.data;
    if (from && to && from > to) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Khoảng ngày lọc không hợp lệ');
    }

    const filters = [];
    const values = [];

    if (memberId) {
      values.push(memberId);
      filters.push(`sr.member_id = $${values.length}`);
    }
    if (coachId) {
      values.push(coachId);
      filters.push(`sr.coach_id = $${values.length}`);
    }
    if (incidentId) {
      values.push(incidentId);
      filters.push(`sr.incident_id = $${values.length}`);
    }
    if (from) {
      values.push(from);
      filters.push(`(sr.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date >= $${values.length}::date`);
    }
    if (to) {
      values.push(to);
      filters.push(`(sr.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date <= $${values.length}::date`);
    }
    if (search) {
      values.push(`%${escapeLike(search)}%`);
      const p = `$${values.length}`;
      filters.push(
        `(m.full_name ILIKE ${p} ESCAPE '\\' OR m.email::text ILIKE ${p} ESCAPE '\\' OR c.full_name ILIKE ${p} ESCAPE '\\' OR c.email::text ILIKE ${p} ESCAPE '\\' OR sr.reason ILIKE ${p} ESCAPE '\\' OR COALESCE(e.plan_name, h.plan_name, '') ILIKE ${p} ESCAPE '\\' OR sr.id::text ILIKE ${p} ESCAPE '\\' OR sr.refund_batch_id::text ILIKE ${p} ESCAPE '\\' OR sr.incident_id::text ILIKE ${p} ESCAPE '\\')`,
      );
    }

    const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    const baseJoins = `
      FROM simulated_refunds sr
      JOIN coach_entitlements e ON e.id = sr.coach_entitlement_id
      LEFT JOIN coach_payment_holds h ON h.id = COALESCE(e.original_hold_id, e.hold_id)
      JOIN users m ON m.id = sr.member_id
      JOIN users c ON c.id = sr.coach_id
      LEFT JOIN users cb ON cb.id = sr.created_by
      ${whereClause}
    `;

    try {
      const [summaryRes, rowsRes] = await Promise.all([
        database.query(
          `SELECT count(*)::int AS count,
                  COALESCE(sum(sr.refund_amount), 0)::text AS total_refund_amount
           ${baseJoins}`,
          values,
        ),
        database.query(
          `SELECT sr.id, sr.refund_batch_id, sr.incident_id, sr.coach_entitlement_id,
                  sr.relationship_id, sr.member_id, sr.coach_id, sr.entitlement_kind,
                  sr.snapshot_price, sr.total_sessions, sr.remaining_sessions,
                  sr.refund_amount, sr.status, sr.reason, sr.created_by, sr.created_at,
                  COALESCE(e.plan_code, h.plan_code) AS plan_code,
                  COALESCE(e.plan_name, h.plan_name) AS plan_name,
                  m.full_name AS member_name, m.email::text AS member_email,
                  c.full_name AS coach_name, c.email::text AS coach_email,
                  cb.full_name AS created_by_name
           ${baseJoins}
           ORDER BY sr.created_at DESC, (sr.entitlement_kind = 'ACTIVE') DESC, sr.id DESC
           LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
          [...values, pageSize, (page - 1) * pageSize],
        ),
      ]);

      const totalItems = summaryRes.rows[0].count;
      const totalRefundAmount = Number(summaryRes.rows[0].total_refund_amount ?? 0);
      const items = rowsRes.rows.map(simulatedRefundView);

      return response.json({
        data: items,
        items,
        summary: {
          totalRefundAmount,
          count: totalItems,
        },
        pagination: {
          page,
          pageSize,
          totalItems,
          totalPages: Math.ceil(totalItems / pageSize),
        },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được lịch sử hoàn tiền mô phỏng');
    }
  });

  return router;
}
