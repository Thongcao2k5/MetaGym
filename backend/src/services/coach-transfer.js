import { createHash, randomUUID } from 'node:crypto';

import { hasCoachCapacity, isCoachScheduleConfigured } from './coach-capacity.js';

// D3 integer BigInt formula (floor to 1,000 VND multiple)
export function computeActiveSimulatedRefund(snapshotPrice, remainingSessions, totalSessions) {
  if (snapshotPrice === null || snapshotPrice === undefined) return 0;
  const price = BigInt(snapshotPrice);
  const remaining = BigInt(remainingSessions ?? 0);
  const total = BigInt(totalSessions ?? 0);
  if (price <= 0n || remaining <= 0n || total <= 0n) return 0;
  return Number(((price * remaining) / total / 1000n) * 1000n);
}

// Compute the exact D2 transfer capacity proposal windows (ACTIVE + QUEUED late & early)
// using PostgreSQL date arithmetic and excluding future BOOKED bookings on oldRelationshipId
// that will be cancelled without charging upon transfer.
export async function buildD2TransferProposals(
  client,
  { memberId, oldRelationshipId, activeEntitlement, queuedEntitlement, frozenDaysAdded = 0, todayVn },
) {
  const checkedEntitlements = [];
  if (activeEntitlement) checkedEntitlements.push('ACTIVE');
  if (queuedEntitlement) checkedEntitlements.push('QUEUED');

  if (!activeEntitlement && !queuedEntitlement) {
    return {
      checkedEntitlements,
      newActiveEndsOn: null,
      activeProposal: null,
      queuedLateProposal: null,
      queuedEarlyProposal: null,
    };
  }

  const { rows: bookedRows } = await client.query(
    `SELECT DISTINCT booking_date::text AS date
     FROM coach_bookings
     WHERE member_id = $1
       AND (
         status = 'COMPLETED'
         OR charged_at IS NOT NULL
         OR (
           status = 'BOOKED'
           AND NOT (
             starts_at > statement_timestamp()
             AND entitlement_id IN (
               SELECT id FROM coach_entitlements WHERE relationship_id = $2
             )
           )
         )
       )`,
    [memberId, oldRelationshipId],
  );
  const bookedDates = new Set(bookedRows.map((row) => row.date));

  let activeProposal = null;
  let queuedLateProposal = null;
  let queuedEarlyProposal = null;
  let newActiveEndsOn = null;

  if (activeEntitlement) {
    const startsOn = activeEntitlement.starts_on_text ?? activeEntitlement.starts_on;
    const originalEndsOn = activeEntitlement.original_ends_on_text ?? activeEntitlement.original_ends_on;
    const newFrozenTotal = Number(activeEntitlement.frozen_days_total ?? 0) + Number(frozenDaysAdded ?? 0);
    const graceDays = Number(activeEntitlement.grace_days_added ?? 0);
    const remainingSessions = Number(activeEntitlement.remaining_sessions);

    const { rows: [win] } = await client.query(
      `SELECT GREATEST($1::date, $2::date)::text AS active_from,
              ($3::date + $4::int + $5::int)::text AS active_through,
              ($3::date + $4::int + 8)::text AS late_from,
              CASE WHEN $6::int IS NOT NULL
                   THEN (($3::date + $4::int + 8) + $6::int - 1)::text
                   ELSE NULL END AS late_through,
              ($1::date + $7::int)::text AS early_from,
              CASE WHEN $6::int IS NOT NULL
                   THEN (($1::date + $7::int) + $6::int - 1)::text
                   ELSE NULL END AS early_through`,
      [
        todayVn,
        startsOn,
        originalEndsOn,
        newFrozenTotal,
        graceDays,
        queuedEntitlement ? Number(queuedEntitlement.duration_days) : null,
        remainingSessions,
      ],
    );

    newActiveEndsOn = win.active_through;
    activeProposal = {
      memberId,
      from: win.active_from,
      through: win.active_through,
      remaining: remainingSessions,
      bookedDates,
    };

    if (queuedEntitlement) {
      const queuedSessions = Number(queuedEntitlement.total_sessions);
      queuedLateProposal = {
        memberId,
        from: win.late_from,
        through: win.late_through,
        remaining: queuedSessions,
        bookedDates,
      };
      queuedEarlyProposal = {
        memberId,
        from: win.early_from,
        through: win.early_through,
        remaining: queuedSessions,
        bookedDates,
      };
    }
  } else if (queuedEntitlement) {
    const durationDays = Number(queuedEntitlement.duration_days);
    const { rows: [win] } = await client.query(
      `SELECT $1::date::text AS from_date,
              ($1::date + $2::int - 1)::text AS through_date`,
      [todayVn, durationDays],
    );
    queuedLateProposal = {
      memberId,
      from: win.from_date,
      through: win.through_date,
      remaining: Number(queuedEntitlement.total_sessions),
      bookedDates,
    };
  }

  return {
    checkedEntitlements,
    newActiveEndsOn,
    activeProposal,
    queuedLateProposal,
    queuedEarlyProposal,
  };
}

// Check Coach capacity for BOTH ACTIVE and QUEUED (both late & early edge windows per T2 §2 D2)
export async function checkD2Capacity(client, coachId, proposalBundle) {
  const { activeProposal, queuedLateProposal, queuedEarlyProposal } = proposalBundle;
  if (!activeProposal && !queuedLateProposal) return true;

  if (activeProposal && queuedLateProposal && queuedEarlyProposal) {
    const lateOk = await hasCoachCapacity(client, coachId, [activeProposal, queuedLateProposal]);
    if (!lateOk) return false;
    return hasCoachCapacity(client, coachId, [activeProposal, queuedEarlyProposal]);
  }
  if (activeProposal) {
    return hasCoachCapacity(client, coachId, [activeProposal]);
  }
  return hasCoachCapacity(client, coachId, [queuedLateProposal]);
}

function buildTransferResponse(metadata) {
  return {
    transferId: metadata.transferId,
    oldRelationshipId: metadata.oldRelationshipId,
    newRelationshipId: metadata.newRelationshipId,
    memberId: metadata.memberId,
    oldCoachId: metadata.oldCoachId,
    newCoachId: metadata.newCoachId,
    newRelationshipStatus: metadata.newRelationshipStatus,
    newPauseReason: metadata.newPauseReason ?? null,
    frozenDaysAdded: metadata.frozenDaysAdded ?? 0,
    transferredEntitlements: metadata.transferredEntitlements ?? [],
    cancelledOldBookingsCount: metadata.cancelledOldBookingsCount ?? 0,
    incidentId: metadata.incidentId ?? null,
    incidentStatus: metadata.incidentStatus ?? null,
  };
}

function errorResult(status, code, message, details = {}) {
  return { ok: false, status, code, message, details };
}

export async function executeCoachTransfer(
  database,
  { adminUser, incidentId = null, memberId = null, newCoachId, reason, idempotencyKey = null, mode = 'INCIDENT' },
) {
  const requestHash = idempotencyKey
    ? createHash('sha256')
        .update(JSON.stringify(
          mode === 'INCIDENT'
            ? { mode: 'INCIDENT', incidentId, newCoachId, reason }
            : { mode: 'DIRECT', memberId, newCoachId, reason },
        ))
        .digest('hex')
    : null;

  const client = await database.connect().catch(() => null);
  if (!client) {
    return errorResult(500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
  }

  let transactionOpen = false;
  try {
    await client.query('BEGIN');
    transactionOpen = true;

    // Canonical lock order step 2: activeAdmin FOR SHARE
    const adminCheck = await client.query(
      `SELECT id FROM users
       WHERE id = $1 AND role = 'ADMIN' AND status = 'ACTIVE' AND session_version = $2
       FOR SHARE`,
      [adminUser.id, adminUser.session_version],
    );
    if (!adminCheck.rows.length) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return errorResult(401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
    }

    // Serialize retries on the same (adminId, idempotencyKey) via transaction advisory lock
    if (idempotencyKey) {
      await client.query(
        `SELECT pg_advisory_xact_lock(hashtext('coach-transfer-idem:' || $1 || ':' || $2))`,
        [adminUser.id, idempotencyKey],
      );
      const priorAudit = await client.query(
        `SELECT metadata
         FROM admin_audit_logs
         WHERE admin_id = $1
           AND action = 'COACH_TRANSFERRED'
           AND metadata->>'idempotencyKey' = $2
         ORDER BY created_at DESC
         LIMIT 1`,
        [adminUser.id, idempotencyKey],
      );
      if (priorAudit.rows.length) {
        const meta = priorAudit.rows[0].metadata ?? {};
        await client.query('COMMIT');
        transactionOpen = false;
        if (meta.requestHash !== requestHash) {
          return errorResult(
            409,
            'IDEMPOTENCY_KEY_CONFLICT',
            'Khóa Idempotency-Key đã được dùng cho yêu cầu chuyển Coach khác',
          );
        }
        return { ok: true, status: 200, data: buildTransferResponse(meta) };
      }
    }

    // Non-locking peek to discover [oldCoachId, newCoachId, memberId] for canonical lock order
    let targetMemberId = memberId;
    let peekOldCoachId = null;
    let targetRelationshipId = null;

    if (mode === 'INCIDENT') {
      const incidentPeek = await client.query(
        `SELECT id, coach_id, member_id, relationship_id
         FROM coach_lock_incidents WHERE id = $1`,
        [incidentId],
      );
      if (!incidentPeek.rows.length) {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return errorResult(404, 'NOT_FOUND', 'Không tìm thấy sự cố khóa Coach');
      }
      const peek = incidentPeek.rows[0];
      targetMemberId = peek.member_id;
      peekOldCoachId = peek.coach_id;
      targetRelationshipId = peek.relationship_id;
    } else {
      const relPeek = await client.query(
        `SELECT id, coach_id
         FROM coach_relationships
         WHERE member_id = $1 AND status IN ('ACTIVE', 'PAUSED')
         LIMIT 1`,
        [memberId],
      );
      if (relPeek.rows.length) {
        peekOldCoachId = relPeek.rows[0].coach_id;
        targetRelationshipId = relPeek.rows[0].id;
      }
    }

    // Canonical lock order step 3:
    // Lock Coach users FIRST (sorted by UUID ASC), then Member user SECOND.
    const coachIdsToLock = [...new Set([peekOldCoachId, newCoachId].filter(Boolean))].sort();
    const lockedUsersById = new Map();
    for (const cid of coachIdsToLock) {
      const { rows } = await client.query(
        `SELECT u.id, u.role, u.status, u.full_name, c.member_limit
         FROM users u
         LEFT JOIN coach_profiles c ON c.user_id = u.id
         WHERE u.id = $1
         FOR UPDATE OF u`,
        [cid],
      );
      if (rows[0]) lockedUsersById.set(cid, rows[0]);
    }
    const memberRow = (await client.query(
      `SELECT id, role, status, full_name FROM users WHERE id = $1 FOR UPDATE`,
      [targetMemberId],
    )).rows[0] ?? null;

    const newCoach = lockedUsersById.get(newCoachId) ?? null;
    if (peekOldCoachId && newCoachId === peekOldCoachId) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return errorResult(409, 'TRANSFER_NOT_ALLOWED', 'Coach mới phải khác Coach hiện tại');
    }
    if (!newCoach || newCoach.role !== 'COACH' || newCoach.status !== 'ACTIVE' || !newCoach.member_limit) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return errorResult(404, 'NOT_FOUND', 'Không tìm thấy Coach mới đang hoạt động');
    }
    if (!memberRow || memberRow.role !== 'MEMBER') {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return errorResult(404, 'NOT_FOUND', 'Không tìm thấy Member');
    }
    if (memberRow.status !== 'ACTIVE') {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return errorResult(409, 'TRANSFER_NOT_ALLOWED', 'Không thể chuyển Coach khi tài khoản Member đang bị khóa');
    }

    // Canonical lock order step 4: lock coach_relationships
    let oldRel = null;
    if (mode === 'INCIDENT') {
      oldRel = (await client.query(
        'SELECT * FROM coach_relationships WHERE id = $1 FOR UPDATE',
        [targetRelationshipId],
      )).rows[0] ?? null;
    } else {
      oldRel = (await client.query(
        `SELECT * FROM coach_relationships
         WHERE member_id = $1 AND status IN ('ACTIVE', 'PAUSED')
         ORDER BY id ASC FOR UPDATE`,
        [targetMemberId],
      )).rows[0] ?? null;
    }

    // Canonical lock order step 5: lock coach_entitlements on old relationship
    const lockedEntitlements = oldRel
      ? (await client.query(
          `SELECT e.*,
                  COALESCE(e.plan_code, h.plan_code) AS eff_plan_code,
                  COALESCE(e.plan_name, h.plan_name) AS eff_plan_name,
                  COALESCE(e.snapshot_price, h.amount) AS eff_snapshot_price,
                  e.starts_on::text AS starts_on_text,
                  e.original_ends_on::text AS original_ends_on_text,
                  e.ends_on::text AS ends_on_text
           FROM coach_entitlements e
           LEFT JOIN coach_payment_holds h ON h.id = COALESCE(e.original_hold_id, e.hold_id)
           WHERE e.relationship_id = $1 AND e.status IN ('ACTIVE', 'QUEUED')
           ORDER BY e.id ASC
           FOR UPDATE OF e`,
          [oldRel.id],
        )).rows
      : [];

    // Canonical lock order step 6: lock coach_lock_incidents, coach_termination_requests, coach_payment_holds
    let openIncident = null;
    if (mode === 'INCIDENT') {
      const incidentRow = (await client.query(
        `SELECT *,
                CASE
                  WHEN frozen_started_at IS NOT NULL AND frozen_days_applied IS NULL
                  THEN GREATEST(
                    0,
                    ((statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
                      - (frozen_started_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date)
                  )::int
                  ELSE 0
                END AS computed_delta_days
         FROM coach_lock_incidents
         WHERE id = $1
         FOR UPDATE`,
        [incidentId],
      )).rows[0] ?? null;

      if (!incidentRow) {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return errorResult(404, 'NOT_FOUND', 'Không tìm thấy sự cố khóa Coach');
      }
      if (incidentRow.status !== 'OPEN' || !oldRel || oldRel.status === 'ENDED') {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return errorResult(409, 'INCIDENT_ALREADY_RESOLVED', 'Sự cố khóa Coach này đã được xử lý trước đó');
      }
      openIncident = incidentRow;
    } else {
      if (!oldRel || !['ACTIVE', 'PAUSED'].includes(oldRel.status)) {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return errorResult(409, 'TRANSFER_NOT_ALLOWED', 'Member không có quan hệ Coach đang hoạt động hoặc tạm ngưng');
      }
      if (oldRel.coach_id !== peekOldCoachId) {
        // Rare concurrent transfer changed oldCoachId between peek and lock
        await client.query('ROLLBACK');
        transactionOpen = false;
        return errorResult(409, 'TRANSFER_NOT_ALLOWED', 'Trạng thái quan hệ Coach vừa thay đổi; vui lòng thử lại');
      }
      if (oldRel.status === 'PAUSED' && oldRel.pause_reason === 'MEMBER_LOCKED') {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return errorResult(409, 'TRANSFER_NOT_ALLOWED', 'Không thể chuyển Coach khi quan hệ đang tạm ngưng do khóa Member');
      }
      openIncident = (await client.query(
        `SELECT *,
                CASE
                  WHEN frozen_started_at IS NOT NULL AND frozen_days_applied IS NULL
                  THEN GREATEST(
                    0,
                    ((statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
                      - (frozen_started_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date)
                  )::int
                  ELSE 0
                END AS computed_delta_days
         FROM coach_lock_incidents
         WHERE relationship_id = $1 AND status = 'OPEN'
         ORDER BY id ASC
         FOR UPDATE`,
        [oldRel.id],
      )).rows[0] ?? null;
    }

    if (oldRel.coach_id === newCoachId) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return errorResult(409, 'TRANSFER_NOT_ALLOWED', 'Coach mới phải khác Coach hiện tại');
    }

    // Lock open termination requests, open holds on old pair, and future bookings (steps 6-7)
    await client.query(
      `SELECT id FROM coach_termination_requests
       WHERE relationship_id = $1 AND status IN ('PENDING_COUNTERPARTY', 'DISPUTED')
       ORDER BY id ASC FOR UPDATE`,
      [oldRel.id],
    );
    await client.query(
      `SELECT id FROM coach_payment_holds
       WHERE member_id = $1 AND coach_id = $2 AND status = 'HELD'
       ORDER BY id ASC FOR UPDATE`,
      [memberRow.id, oldRel.coach_id],
    );
    await client.query(
      `SELECT b.id FROM coach_bookings b
       JOIN coach_entitlements e ON e.id = b.entitlement_id
       WHERE e.relationship_id = $1 AND b.status = 'BOOKED'
         AND b.starts_at > statement_timestamp()
       ORDER BY b.id ASC FOR UPDATE OF b`,
      [oldRel.id],
    );

    // Seat cap check: occupied seats (ACTIVE + PAUSED + live 15-min HELD holds) < 8
    const { rows: [{ count: occupiedSeats }] } = await client.query(
      'SELECT coach_occupied_seats($1) AS count',
      [newCoachId],
    );
    if (Number(occupiedSeats) >= Math.min(8, Number(newCoach.member_limit))) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return errorResult(409, 'COACH_FULL', 'Coach mới đã đủ 8 Member (tính cả suất giữ thanh toán 15 phút)');
    }

    const { rows: [{ today_vn: todayVn }] } = await client.query(
      `SELECT (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS today_vn`,
    );

    const oldActive = lockedEntitlements.find((e) => e.status === 'ACTIVE') ?? null;
    const oldQueued = lockedEntitlements.find((e) => e.status === 'QUEUED') ?? null;

    // Compute exact VN-date frozenDaysAdded (applied ONCE ONLY per T2 §1.1 & D2)
    let frozenDaysAdded = 0;
    if (openIncident && oldActive && oldActive.frozen_at && openIncident.frozen_days_applied === null) {
      frozenDaysAdded = Math.max(0, Number(openIncident.computed_delta_days ?? 0));
    } else if (!openIncident && oldActive && oldActive.frozen_at) {
      const { rows: [{ delta }] } = await client.query(
        `SELECT GREATEST(
           0,
           ((statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
             - ($1::timestamptz AT TIME ZONE 'Asia/Ho_Chi_Minh')::date)
         )::int AS delta`,
        [oldActive.frozen_at],
      );
      frozenDaysAdded = Math.max(0, Number(delta ?? 0));
    }

    // Require configured weekly schedule & D2 capacity for incident transfers and all V2 package transfers.
    // Legacy V1 relationships with zero entitlements and no open incident (legacy tests) bypass schedule/session math.
    const requireScheduleAndCapacity = mode === 'INCIDENT'
      || Boolean(openIncident)
      || Boolean(oldActive)
      || Boolean(oldQueued);

    if (requireScheduleAndCapacity) {
      const { rows: slotRows } = await client.query(
        `SELECT weekday, start_minute
         FROM coach_weekly_slots
         WHERE coach_id = $1
         ORDER BY weekday ASC, start_minute ASC`,
        [newCoachId],
      );
      if (!isCoachScheduleConfigured(slotRows)) {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return errorResult(
          409,
          'SCHEDULE_REQUIRED',
          'Coach mới chưa cấu hình đủ lịch làm việc (>= 6 ngày/tuần, >= 4 khung 90 phút liên tiếp/ngày)',
        );
      }

      if (oldActive || oldQueued) {
        const proposalBundle = await buildD2TransferProposals(client, {
          memberId: memberRow.id,
          oldRelationshipId: oldRel.id,
          activeEntitlement: oldActive,
          queuedEntitlement: oldQueued,
          frozenDaysAdded,
          todayVn,
        });
        const capacityOk = await checkD2Capacity(client, newCoachId, proposalBundle);
        if (!capacityOk) {
          await client.query('ROLLBACK');
          transactionOpen = false;
          return errorResult(
            409,
            'CAPACITY_UNAVAILABLE',
            oldQueued
              ? 'Lịch Coach mới không đủ công suất cho cả gói đang dùng và gói chờ'
              : 'Lịch Coach mới không đủ công suất cho gói đang dùng',
            { checkedEntitlements: proposalBundle.checkedEntitlements },
          );
        }
      }
    }

    // =========================================================================
    // Execute Atomic Transfer Mutations
    // =========================================================================

    // 1. Cancel future BOOKED coach_bookings on old relationship WITHOUT charging sessions
    const cancelledBookings = await client.query(
      `UPDATE coach_bookings b
       SET status = 'CANCELLED',
           resolved_at = statement_timestamp(),
           resolved_by = $2,
           reason = 'Member được chuyển sang Coach mới'
       FROM coach_entitlements e
       WHERE e.relationship_id = $1
         AND b.entitlement_id = e.id
         AND b.status = 'BOOKED'
         AND b.starts_at > statement_timestamp()
       RETURNING b.id`,
      [oldRel.id, adminUser.id],
    );
    const cancelledOldBookingsCount = cancelledBookings.rowCount;

    // 2. Cancel legacy future scheduled training_sessions
    await client.query(
      `UPDATE training_sessions
       SET status = 'CANCELLED',
           cancelled_at = statement_timestamp(),
           cancellation_reason = 'Member được chuyển sang Coach mới'
       WHERE relationship_id = $1
         AND status = 'SCHEDULED'
         AND scheduled_start_at > statement_timestamp()`,
      [oldRel.id],
    );

    // 3. Mark old ACTIVE/QUEUED entitlements ENDED with close_reason = 'TRANSFERRED' BEFORE ending old relationship
    //    so notify_coach_package skips bogus PACKAGE_ENDED and uq_coach_entitlement_current is released.
    await client.query(
      `UPDATE coach_entitlements
       SET status = 'ENDED',
           ended_at = statement_timestamp(),
           frozen_at = NULL,
           close_reason = 'TRANSFERRED'
       WHERE relationship_id = $1
         AND status IN ('ACTIVE', 'QUEUED')`,
      [oldRel.id],
    );

    // 4. Archive old training plans & nutrition guides read-only (new Coach NEVER inherits them)
    await client.query(
      `UPDATE training_plans
       SET status = 'ARCHIVED', archived_at = statement_timestamp()
       WHERE relationship_id = $1 AND status = 'ACTIVE'`,
      [oldRel.id],
    );
    await client.query(
      `UPDATE nutrition_guides
       SET status = 'ARCHIVED', archived_at = statement_timestamp()
       WHERE relationship_id = $1 AND status = 'ACTIVE'`,
      [oldRel.id],
    );

    // 5. Cancel open termination requests & open payment holds on old relationship
    await client.query(
      `UPDATE coach_termination_requests
       SET status = 'CANCELLED', decided_at = statement_timestamp()
       WHERE relationship_id = $1 AND status IN ('PENDING_COUNTERPARTY', 'DISPUTED')`,
      [oldRel.id],
    );
    await client.query(
      `UPDATE coach_payment_holds
       SET status = 'CANCELLED'
       WHERE member_id = $1 AND coach_id = $2 AND status = 'HELD'`,
      [memberRow.id, oldRel.coach_id],
    );

    // 6. End old relationship (releases old Coach seat & uq_relationship_current_member)
    await client.query(
      `UPDATE coach_relationships
       SET status = 'ENDED',
           ended_at = statement_timestamp(),
           ended_by = $1,
           end_reason = $2
       WHERE id = $3`,
      [adminUser.id, reason, oldRel.id],
    );

    // 7. Determine new relationship status from Member's active Gym membership today VN
    const { rows: gymRows } = await client.query(
      `SELECT 1 FROM member_memberships
       WHERE member_id = $1
         AND status = 'ACTIVE'
         AND start_date <= $2::date
         AND end_date >= $2::date
       LIMIT 1`,
      [memberRow.id, todayVn],
    );
    const hasActiveGym = gymRows.length === 1;
    const newRelationshipId = randomUUID();
    const newRelationshipStatus = hasActiveGym ? 'ACTIVE' : 'PAUSED';
    const newPauseReason = hasActiveGym ? null : 'MEMBERSHIP_EXPIRED';

    // NOTE: Do NOT call ensureConversation() — chat V2 is independent of coaching relationships!
    await client.query(
      `INSERT INTO coach_relationships
       (id, member_id, coach_id, status, paused_at, pause_reason)
       VALUES ($1, $2, $3, $4::varchar, CASE WHEN $4::varchar = 'PAUSED' THEN statement_timestamp() ELSE NULL END, $5)`,
      [newRelationshipId, memberRow.id, newCoachId, newRelationshipStatus, newPauseReason],
    );

    // 8. Clone/transfer ACTIVE + QUEUED entitlements onto newRelationshipId preserving snapshots
    const transferredEntitlements = [];

    if (oldActive) {
      const newActiveId = randomUUID();
      const newFrozenTotal = Number(oldActive.frozen_days_total ?? 0) + frozenDaysAdded;
      const graceDays = Number(oldActive.grace_days_added ?? 0);
      const originalHoldId = oldActive.original_hold_id ?? oldActive.hold_id ?? null;

      const { rows: [insertedActive] } = await client.query(
        `INSERT INTO coach_entitlements (
           id, hold_id, original_hold_id, source_entitlement_id,
           relationship_id, member_id, coach_id,
           plan_code, plan_name, snapshot_price,
           status, total_sessions, remaining_sessions, duration_days,
           starts_on, original_ends_on, ends_on,
           frozen_at, frozen_days_total, grace_days_added
         ) VALUES (
           $1, NULL, $2, $3,
           $4, $5, $6,
           $7, $8, $9,
           'ACTIVE', $10, $11, $12,
           $13::date, $14::date, ($14::date + $15::int + $16::int),
           NULL, $15::int, $16::int
         )
         RETURNING id, ends_on::text AS ends_on, snapshot_price, total_sessions, remaining_sessions`,
        [
          newActiveId,
          originalHoldId,
          oldActive.id,
          newRelationshipId,
          memberRow.id,
          newCoachId,
          oldActive.eff_plan_code ?? null,
          oldActive.eff_plan_name ?? null,
          oldActive.eff_snapshot_price ?? null,
          oldActive.total_sessions,
          oldActive.remaining_sessions,
          oldActive.duration_days,
          oldActive.starts_on_text,
          oldActive.original_ends_on_text,
          newFrozenTotal,
          graceDays,
        ],
      );

      transferredEntitlements.push({
        kind: 'ACTIVE',
        oldId: oldActive.id,
        newId: insertedActive.id,
        planCode: oldActive.eff_plan_code ?? null,
        planName: oldActive.eff_plan_name ?? null,
        remainingSessions: Number(insertedActive.remaining_sessions),
        totalSessions: Number(insertedActive.total_sessions),
        snapshotPrice: insertedActive.snapshot_price === null ? null : Number(insertedActive.snapshot_price),
        endsOn: insertedActive.ends_on,
      });
    }

    if (oldQueued) {
      const newQueuedId = randomUUID();
      const originalHoldId = oldQueued.original_hold_id ?? oldQueued.hold_id ?? null;

      const { rows: [insertedQueued] } = await client.query(
        `INSERT INTO coach_entitlements (
           id, hold_id, original_hold_id, source_entitlement_id,
           relationship_id, member_id, coach_id,
           plan_code, plan_name, snapshot_price,
           status, total_sessions, remaining_sessions, duration_days,
           starts_on, original_ends_on, ends_on,
           frozen_at, frozen_days_total, grace_days_added
         ) VALUES (
           $1, NULL, $2, $3,
           $4, $5, $6,
           $7, $8, $9,
           'QUEUED', $10, $11, $12,
           NULL, NULL, NULL,
           NULL, 0, 0
         )
         RETURNING id, snapshot_price, total_sessions, remaining_sessions`,
        [
          newQueuedId,
          originalHoldId,
          oldQueued.id,
          newRelationshipId,
          memberRow.id,
          newCoachId,
          oldQueued.eff_plan_code ?? null,
          oldQueued.eff_plan_name ?? null,
          oldQueued.eff_snapshot_price ?? null,
          oldQueued.total_sessions,
          oldQueued.remaining_sessions,
          oldQueued.duration_days,
        ],
      );

      transferredEntitlements.push({
        kind: 'QUEUED',
        oldId: oldQueued.id,
        newId: insertedQueued.id,
        planCode: oldQueued.eff_plan_code ?? null,
        planName: oldQueued.eff_plan_name ?? null,
        remainingSessions: Number(insertedQueued.remaining_sessions),
        totalSessions: Number(insertedQueued.total_sessions),
        snapshotPrice: insertedQueued.snapshot_price === null ? null : Number(insertedQueued.snapshot_price),
        endsOn: null,
      });
    }

    // 9. Insert coach_transfer_history
    const transferId = randomUUID();
    await client.query(
      `INSERT INTO coach_transfer_history
       (id, member_id, old_relationship_id, new_relationship_id,
        old_coach_id, new_coach_id, reason, admin_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [transferId, memberRow.id, oldRel.id, newRelationshipId, oldRel.coach_id, newCoachId, reason, adminUser.id],
    );

    // 10. Resolve open coach_lock_incidents -> RESOLVED_TRANSFERRED
    //     (Note: trg_close_coach_entitlements set it to RESOLVED_ENDED on step 6 inside this same tx;
    //      we update by locked incident id directly so final committed state is RESOLVED_TRANSFERRED.)
    let resolvedIncidentStatus = null;
    if (openIncident) {
      await client.query(
        `UPDATE coach_lock_incidents
         SET status = 'RESOLVED_TRANSFERRED',
             frozen_ended_at = CASE WHEN frozen_started_at IS NOT NULL THEN statement_timestamp() ELSE NULL END,
             frozen_days_applied = COALESCE(frozen_days_applied, $2),
             transfer_history_id = $3,
             resolved_by = $4,
             resolved_at = statement_timestamp()
         WHERE id = $1`,
        [openIncident.id, frozenDaysAdded, transferId, adminUser.id],
      );
      resolvedIncidentStatus = 'RESOLVED_TRANSFERRED';
    }

    // 11. Emit COACH_TRANSFERRED notifications to Member, old Coach, and new Coach
    await client.query(
      `INSERT INTO coach_notifications (user_id, kind, subject_id)
       VALUES ($1, 'COACH_TRANSFERRED', $4),
              ($2, 'COACH_TRANSFERRED', $4),
              ($3, 'COACH_TRANSFERRED', $4)`,
      [memberRow.id, oldRel.coach_id, newCoachId, newRelationshipId],
    );

    const responseData = {
      transferId,
      oldRelationshipId: oldRel.id,
      newRelationshipId,
      memberId: memberRow.id,
      oldCoachId: oldRel.coach_id,
      newCoachId,
      newRelationshipStatus,
      newPauseReason,
      frozenDaysAdded,
      transferredEntitlements,
      cancelledOldBookingsCount,
      incidentId: openIncident?.id ?? null,
      incidentStatus: resolvedIncidentStatus,
    };

    // 12. Write COACH_TRANSFERRED audit log (strict operational allowlist + idempotency metadata)
    const auditMetadata = {
      ...responseData,
      reason,
      ...(idempotencyKey ? { idempotencyKey, requestHash } : {}),
    };
    await client.query(
      `INSERT INTO admin_audit_logs
       (id, admin_id, action, entity_type, entity_id, summary, metadata)
       VALUES ($1, $2, 'COACH_TRANSFERRED', 'COACH_RELATIONSHIP', $3, $4, $5)`,
      [
        randomUUID(),
        adminUser.id,
        oldRel.id,
        `Chuyển Member ${memberRow.full_name} sang Coach ${newCoach.full_name}`,
        JSON.stringify(auditMetadata),
      ],
    );

    await client.query('COMMIT');
    transactionOpen = false;
    return { ok: true, status: 201, data: responseData };
  } catch {
    if (transactionOpen) await client.query('ROLLBACK').catch(() => {});
    return errorResult(500, 'INTERNAL_SERVER_ERROR', 'Không chuyển được Coach');
  } finally {
    client.release();
  }
}
