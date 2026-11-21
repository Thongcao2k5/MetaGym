import { createHash, randomUUID } from 'node:crypto';

export function computeActiveSimulatedRefundBigInt(snapshotPrice, remainingSessions, totalSessions) {
  if (snapshotPrice === null || snapshotPrice === undefined) return 0n;
  const price = BigInt(snapshotPrice);
  const remaining = BigInt(remainingSessions ?? 0);
  const total = BigInt(totalSessions ?? 0);
  if (price <= 0n || remaining <= 0n || total <= 0n) return 0n;
  return ((price * remaining) / total / 1000n) * 1000n;
}

export function computeQueuedSimulatedRefundBigInt(snapshotPrice) {
  if (snapshotPrice === null || snapshotPrice === undefined) return 0n;
  const price = BigInt(snapshotPrice);
  return price > 0n ? price : 0n;
}

function errorResult(status, code, message, details = {}) {
  return { ok: false, status, code, message, details };
}

function formatVnd(amount) {
  return new Intl.NumberFormat('vi-VN').format(amount);
}

function mapSavedBatchResponse(rows) {
  const first = rows[0];
  let totalBig = 0n;
  const items = rows.map((row) => {
    const refundAmountBig = BigInt(row.refund_amount);
    totalBig += refundAmountBig;
    return {
      id: row.id,
      coachEntitlementId: row.coach_entitlement_id,
      entitlementKind: row.entitlement_kind,
      planName: row.plan_name ?? null,
      snapshotPrice: Number(row.snapshot_price),
      totalSessions: Number(row.total_sessions),
      remainingSessions: Number(row.remaining_sessions),
      refundAmount: Number(refundAmountBig),
      status: row.status,
    };
  });

  return {
    refundBatchId: first.refund_batch_id,
    incidentId: first.incident_id,
    relationshipId: first.relationship_id,
    totalRefundAmount: Number(totalBig),
    items,
    relationshipStatus: first.relationship_status,
    incidentStatus: first.incident_status,
  };
}

export async function executeSimulatedRefund(
  database,
  { adminUser, incidentId, reason, idempotencyKey },
) {
  const requestHash = createHash('sha256')
    .update(JSON.stringify({ incidentId, reason }))
    .digest('hex');

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

    // Serialize retries on the same (adminId, idempotencyKey)
    await client.query(
      `SELECT pg_advisory_xact_lock(hashtext('simulated-refund-idem:' || $1 || ':' || $2))`,
      [adminUser.id, idempotencyKey],
    );

    const existingIdem = await client.query(
      `SELECT sr.id, sr.refund_batch_id, sr.incident_id, sr.coach_entitlement_id,
              sr.relationship_id, sr.entitlement_kind, sr.snapshot_price,
              sr.total_sessions, sr.remaining_sessions, sr.refund_amount,
              sr.status, sr.request_hash,
              COALESCE(e.plan_name, h.plan_name) AS plan_name,
              r.status AS relationship_status,
              i.status AS incident_status
       FROM simulated_refunds sr
       JOIN coach_entitlements e ON e.id = sr.coach_entitlement_id
       LEFT JOIN coach_payment_holds h ON h.id = COALESCE(e.original_hold_id, e.hold_id)
       JOIN coach_relationships r ON r.id = sr.relationship_id
       JOIN coach_lock_incidents i ON i.id = sr.incident_id
       WHERE sr.created_by = $1 AND sr.idempotency_key = $2
       ORDER BY (sr.entitlement_kind = 'ACTIVE') DESC, sr.id ASC`,
      [adminUser.id, idempotencyKey],
    );

    if (existingIdem.rows.length) {
      const savedHash = existingIdem.rows[0].request_hash;
      await client.query('COMMIT');
      transactionOpen = false;
      if (savedHash !== requestHash) {
        return errorResult(
          409,
          'IDEMPOTENCY_KEY_CONFLICT',
          'Khóa Idempotency-Key đã được dùng cho yêu cầu hoàn tiền mô phỏng khác',
        );
      }
      return { ok: true, status: 200, data: mapSavedBatchResponse(existingIdem.rows) };
    }

    // Non-locking peek to discover coach_id, member_id, relationship_id for canonical lock order
    const peekRes = await client.query(
      `SELECT id, coach_id, member_id, relationship_id
       FROM coach_lock_incidents
       WHERE id = $1`,
      [incidentId],
    );
    if (!peekRes.rows.length) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return errorResult(404, 'NOT_FOUND', 'Không tìm thấy sự cố khóa Coach');
    }
    const peek = peekRes.rows[0];

    // Canonical lock order step 3: Lock Coach user FIRST, then Member user SECOND
    await client.query(
      `SELECT id, role, status, full_name FROM users WHERE id = $1 FOR UPDATE`,
      [peek.coach_id],
    );
    await client.query(
      `SELECT id, role, status, full_name FROM users WHERE id = $1 FOR UPDATE`,
      [peek.member_id],
    );

    // Canonical lock order step 4: lock coach_relationships
    const rel = (await client.query(
      `SELECT * FROM coach_relationships WHERE id = $1 FOR UPDATE`,
      [peek.relationship_id],
    )).rows[0] ?? null;

    // Canonical lock order step 5: lock coach_entitlements on relationship
    const lockedEntitlements = rel
      ? (await client.query(
          `SELECT e.*,
                  COALESCE(e.plan_code, h.plan_code) AS eff_plan_code,
                  COALESCE(e.plan_name, h.plan_name) AS eff_plan_name,
                  COALESCE(e.snapshot_price, h.amount) AS eff_snapshot_price
           FROM coach_entitlements e
           LEFT JOIN coach_payment_holds h ON h.id = COALESCE(e.original_hold_id, e.hold_id)
           WHERE e.relationship_id = $1 AND e.status IN ('ACTIVE', 'QUEUED')
           ORDER BY e.id ASC
           FOR UPDATE OF e`,
          [rel.id],
        )).rows
      : [];

    // Canonical lock order step 6: lock coach_lock_incidents, coach_termination_requests, coach_payment_holds
    const incident = (await client.query(
      `SELECT * FROM coach_lock_incidents WHERE id = $1 FOR UPDATE`,
      [incidentId],
    )).rows[0] ?? null;

    if (!incident) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return errorResult(404, 'NOT_FOUND', 'Không tìm thấy sự cố khóa Coach');
    }

    await client.query(
      `SELECT id FROM coach_termination_requests
       WHERE relationship_id = $1 AND status IN ('PENDING_COUNTERPARTY', 'DISPUTED')
       ORDER BY id ASC FOR UPDATE`,
      [incident.relationship_id],
    );

    await client.query(
      `SELECT id FROM coach_payment_holds
       WHERE member_id = $1 AND coach_id = $2 AND status = 'HELD'
       ORDER BY id ASC FOR UPDATE`,
      [incident.member_id, incident.coach_id],
    );

    // Canonical lock order step 7: lock future BOOKED coach_bookings
    await client.query(
      `SELECT b.id FROM coach_bookings b
       JOIN coach_entitlements e ON e.id = b.entitlement_id
       WHERE e.relationship_id = $1
         AND b.status = 'BOOKED'
         AND b.starts_at > statement_timestamp()
       ORDER BY b.id ASC FOR UPDATE OF b`,
      [incident.relationship_id],
    );

    // Guards
    if (incident.status !== 'OPEN' || !rel || rel.status === 'ENDED') {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return errorResult(
        409,
        'INCIDENT_ALREADY_RESOLVED',
        'Sự cố khóa Coach này đã được xử lý trước đó',
      );
    }

    const activeEnt = lockedEntitlements.find((e) => e.status === 'ACTIVE') ?? null;
    const queuedEnt = lockedEntitlements.find((e) => e.status === 'QUEUED') ?? null;

    const candidateEntitlementIds = [...new Set([
      activeEnt?.id,
      queuedEnt?.id,
      incident.active_entitlement_id,
      incident.queued_entitlement_id,
    ].filter(Boolean))];

    if (candidateEntitlementIds.length) {
      const existingRefund = await client.query(
        `SELECT id, coach_entitlement_id
         FROM simulated_refunds
         WHERE coach_entitlement_id = ANY($1::uuid[])
         LIMIT 1`,
        [candidateEntitlementIds],
      );
      if (existingRefund.rows.length) {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return errorResult(
          409,
          'ALREADY_REFUNDED',
          'Gói Coach này đã được ghi nhận hoàn tiền mô phỏng trước đó',
        );
      }
    }

    const targets = [];
    if (activeEnt) targets.push({ kind: 'ACTIVE', ent: activeEnt });
    if (queuedEnt) targets.push({ kind: 'QUEUED', ent: queuedEnt });

    if (!targets.length) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return errorResult(
        409,
        'NO_REFUNDABLE_ENTITLEMENT',
        'Không còn gói Coach đang dùng hoặc gói chờ đủ điều kiện hoàn tiền mô phỏng',
      );
    }

    // =========================================================================
    // Execute Atomic Simulated Refund Mutations (D2 + D3)
    // =========================================================================
    const refundBatchId = randomUUID();
    const responseItems = [];
    let totalRefundBig = 0n;

    for (const { kind, ent } of targets) {
      const snapshotPriceBig = BigInt(ent.eff_snapshot_price ?? 0);
      const totalSessions = Number(ent.total_sessions);
      const remainingSessions = kind === 'QUEUED' ? totalSessions : Number(ent.remaining_sessions);
      const refundAmountBig = kind === 'QUEUED'
        ? computeQueuedSimulatedRefundBigInt(snapshotPriceBig)
        : computeActiveSimulatedRefundBigInt(snapshotPriceBig, remainingSessions, totalSessions);

      const refundId = randomUUID();
      const { rows: [inserted] } = await client.query(
        `INSERT INTO simulated_refunds (
           id, refund_batch_id, incident_id, coach_entitlement_id,
           relationship_id, member_id, coach_id, entitlement_kind,
           snapshot_price, total_sessions, remaining_sessions, refund_amount,
           status, reason, idempotency_key, request_hash, created_by
         ) VALUES (
           $1, $2, $3, $4,
           $5, $6, $7, $8,
           $9, $10, $11, $12,
           'COMPLETED', $13, $14, $15, $16
         )
         RETURNING id, status`,
        [
          refundId,
          refundBatchId,
          incident.id,
          ent.id,
          rel.id,
          incident.member_id,
          incident.coach_id,
          kind,
          snapshotPriceBig.toString(),
          totalSessions,
          remainingSessions,
          refundAmountBig.toString(),
          reason,
          idempotencyKey,
          requestHash,
          adminUser.id,
        ],
      );

      totalRefundBig += refundAmountBig;
      responseItems.push({
        id: inserted.id,
        coachEntitlementId: ent.id,
        entitlementKind: kind,
        planName: ent.eff_plan_name ?? null,
        snapshotPrice: Number(snapshotPriceBig),
        totalSessions,
        remainingSessions,
        refundAmount: Number(refundAmountBig),
        status: inserted.status,
      });
    }

    // 1. BEFORE ending relationship: close ACTIVE/QUEUED entitlements with close_reason = 'SIMULATED_REFUND'
    //    and frozen_at = NULL so notify_coach_package() does NOT emit bogus PACKAGE_ENDED.
    await client.query(
      `UPDATE coach_entitlements
       SET status = 'ENDED',
           ended_at = statement_timestamp(),
           close_reason = 'SIMULATED_REFUND',
           frozen_at = NULL
       WHERE relationship_id = $1
         AND status IN ('ACTIVE', 'QUEUED')`,
      [rel.id],
    );

    // 2. Cancel live HELD payment holds for this relationship
    await client.query(
      `UPDATE coach_payment_holds
       SET status = 'CANCELLED'
       WHERE member_id = $1 AND coach_id = $2 AND status = 'HELD'`,
      [incident.member_id, incident.coach_id],
    );

    // 3. End coach_relationships (trigger cancels future bookings uncharged, archives plans/guides read-only,
    //    cancels open termination requests, releases Coach seat once, leaves chat untouched)
    await client.query(
      `UPDATE coach_relationships
       SET status = 'ENDED',
           ended_at = statement_timestamp(),
           ended_by = $1,
           end_reason = $2
       WHERE id = $3`,
      [adminUser.id, reason, rel.id],
    );

    // 4. Resolve coach_lock_incidents -> RESOLVED_REFUNDED
    //    (Overrides RESOLVED_ENDED set by trg_close_coach_entitlements within the same transaction)
    await client.query(
      `UPDATE coach_lock_incidents
       SET status = 'RESOLVED_REFUNDED',
           refund_batch_id = $2,
           frozen_ended_at = CASE WHEN frozen_started_at IS NOT NULL THEN statement_timestamp() ELSE NULL END,
           resolved_by = $3,
           resolved_at = statement_timestamp()
       WHERE id = $1`,
      [incident.id, refundBatchId, adminUser.id],
    );

    // 5. Emit SIMULATED_REFUND_COMPLETED notifications
    await client.query(
      `INSERT INTO coach_notifications (user_id, kind, subject_id)
       VALUES ($1, 'SIMULATED_REFUND_COMPLETED', $3),
              ($2, 'SIMULATED_REFUND_COMPLETED', $3)`,
      [incident.member_id, incident.coach_id, refundBatchId],
    );

    const totalRefundAmount = Number(totalRefundBig);

    // 6. Write SIMULATED_REFUND_CREATED audit log (strict operational allowlist)
    await client.query(
      `INSERT INTO admin_audit_logs
       (id, admin_id, action, entity_type, entity_id, summary, metadata)
       VALUES ($1, $2, 'SIMULATED_REFUND_CREATED', 'COACH_LOCK_INCIDENT', $3, $4, $5)`,
      [
        randomUUID(),
        adminUser.id,
        incident.id,
        `Hoàn tiền mô phỏng ${formatVnd(totalRefundAmount)} ₫ cho sự cố khóa Coach`,
        JSON.stringify({
          refundBatchId,
          incidentId: incident.id,
          relationshipId: rel.id,
          memberId: incident.member_id,
          coachId: incident.coach_id,
          totalRefundAmount,
          itemCount: responseItems.length,
          entitlementIds: responseItems.map((item) => item.coachEntitlementId),
          reason,
        }),
      ],
    );

    await client.query('COMMIT');
    transactionOpen = false;

    return {
      ok: true,
      status: 201,
      data: {
        refundBatchId,
        incidentId: incident.id,
        relationshipId: rel.id,
        totalRefundAmount,
        items: responseItems,
        relationshipStatus: 'ENDED',
        incidentStatus: 'RESOLVED_REFUNDED',
      },
    };
  } catch (err) {
    if (transactionOpen) await client.query('ROLLBACK').catch(() => {});
    if (err?.code === '23505') {
      if (err.constraint === 'simulated_refunds_coach_entitlement_id_key') {
        return errorResult(
          409,
          'ALREADY_REFUNDED',
          'Gói Coach này đã được ghi nhận hoàn tiền mô phỏng trước đó',
        );
      }
      if (err.constraint === 'uq_simulated_refund_idempotency') {
        return errorResult(
          409,
          'IDEMPOTENCY_KEY_CONFLICT',
          'Khóa Idempotency-Key đã được dùng cho yêu cầu hoàn tiền mô phỏng khác',
        );
      }
    }
    return errorResult(500, 'INTERNAL_SERVER_ERROR', 'Không thực thi được hoàn tiền mô phỏng');
  } finally {
    client.release();
  }
}
