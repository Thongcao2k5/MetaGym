import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const VIETNAM_TIMEZONE = 'Asia/Ho_Chi_Minh';

const dashboardQuerySchema = z.strictObject({
  from: z.iso.date().optional(),
  to: z.iso.date().optional(),
});

const vnDateFormatter = new Intl.DateTimeFormat('en-CA', {
  timeZone: VIETNAM_TIMEZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

function formatVietnamDate(value) {
  return vnDateFormatter.format(value);
}

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, message, details: {} } });
}

async function escalateOverdueTerminations(database) {
  await database.query(
    `WITH escalated AS (
       UPDATE coach_termination_requests
       SET status = 'DISPUTED',
           disputed_at = response_deadline_at,
           escalation_reason = 'TIMEOUT_72H'
       WHERE status = 'PENDING_COUNTERPARTY'
         AND response_deadline_at <= statement_timestamp()
       RETURNING id, requested_by_user_id, counterparty_user_id
     )
     INSERT INTO coach_notifications (user_id, kind, subject_id)
     SELECT recipient.user_id, 'TERMINATION_DISPUTED', escalated.id
     FROM escalated
     CROSS JOIN LATERAL (
       VALUES (escalated.requested_by_user_id), (escalated.counterparty_user_id)
     ) AS recipient(user_id)`,
  );
}

function accumulateRevenueByDay({
  gymRows,
  voidRows,
  coachRows,
  refundRows,
}) {
  const days = new Map();
  const ensureDay = (day) => {
    let bucket = days.get(day);
    if (!bucket) {
      bucket = {
        gymGross: 0n,
        voidReversals: 0n,
        coachGross: 0n,
        simulatedRefunds: 0n,
      };
      days.set(day, bucket);
    }
    return bucket;
  };

  let gymGrossPayments = 0n;
  let gymPaymentCount = 0;
  for (const row of gymRows) {
    const amount = BigInt(row.amount);
    gymGrossPayments += amount;
    gymPaymentCount += row.count;
    ensureDay(row.day).gymGross += amount;
  }

  let totalVoidReversals = 0n;
  let voidReversalCount = 0;
  for (const row of voidRows) {
    const amount = BigInt(row.amount);
    totalVoidReversals += amount;
    voidReversalCount += row.count;
    ensureDay(row.day).voidReversals += amount;
  }

  let coachGrossPayments = 0n;
  let coachPackageCount = 0;
  for (const row of coachRows) {
    const amount = BigInt(row.amount);
    coachGrossPayments += amount;
    coachPackageCount += row.count;
    ensureDay(row.day).coachGross += amount;
  }

  let totalSimulatedRefunds = 0n;
  let simulatedRefundCount = 0;
  for (const row of refundRows) {
    const amount = BigInt(row.amount);
    totalSimulatedRefunds += amount;
    simulatedRefundCount += row.count;
    ensureDay(row.day).simulatedRefunds += amount;
  }

  const grossRevenue = gymGrossPayments - totalVoidReversals + coachGrossPayments;
  const netRevenue = grossRevenue - totalSimulatedRefunds;

  const byDay = [...days.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([day, bucket]) => {
      const dayGross = bucket.gymGross - bucket.voidReversals + bucket.coachGross;
      const dayNet = dayGross - bucket.simulatedRefunds;
      return {
        day,
        gymGross: Number(bucket.gymGross),
        voidReversals: Number(bucket.voidReversals),
        coachGross: Number(bucket.coachGross),
        grossRevenue: Number(dayGross),
        simulatedRefunds: Number(bucket.simulatedRefunds),
        netRevenue: Number(dayNet),
      };
    });

  return {
    gymGrossPayments: Number(gymGrossPayments),
    totalVoidReversals: Number(totalVoidReversals),
    coachGrossPayments: Number(coachGrossPayments),
    grossRevenue: Number(grossRevenue),
    totalSimulatedRefunds: Number(totalSimulatedRefunds),
    netRevenue: Number(netRevenue),
    gymPaymentCount,
    paymentCount: gymPaymentCount,
    coachPackageCount,
    voidReversalCount,
    simulatedRefundCount,
    byDay,
  };
}

export function createDashboardRouter({ database, jwtSecret }) {
  const router = Router();
  router.use(createAuthentication({ database, jwtSecret }));

  router.get('/admin/dashboard', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') {
      return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    }

    const parsed = dashboardQuerySchema.safeParse(request.query);
    if (!parsed.success || (parsed.data.from && parsed.data.to && parsed.data.from > parsed.data.to)) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Khoảng ngày không hợp lệ');
    }

    const now = new Date();
    const today = formatVietnamDate(now);
    const start = formatVietnamDate(new Date(now.getTime() - 29 * 86400000));
    const from = parsed.data.from ?? start;
    const to = parsed.data.to ?? today;
    if (from > to) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Khoảng ngày không hợp lệ');
    }

    try {
      // Ensure overdue 72h D5 termination requests are escalated to DISPUTED before counting
      await escalateOverdueTerminations(database);

      const [
        usersResult,
        membershipsResult,
        checkinsResult,
        relationshipsResult,
        incidentsResult,
        disputedTerminationsResult,
        gymPaymentsResult,
        voidReversalsResult,
        coachPaymentsResult,
        simulatedRefundsResult,
        newMembersResult,
      ] = await Promise.all([
        database.query(
          `SELECT role, status, count(*)::int AS count
           FROM users
           WHERE role IN ('MEMBER', 'COACH')
           GROUP BY role, status`,
        ),
        database.query(
          `SELECT count(*)::int AS count
           FROM member_memberships
           WHERE status = 'ACTIVE'
             AND start_date <= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
             AND end_date >= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date`,
        ),
        database.query(
          `SELECT count(*)::int AS count
           FROM gym_visits
           WHERE visit_day = (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date`,
        ),
        database.query(
          `SELECT status, pause_reason, count(*)::int AS count
           FROM coach_relationships
           WHERE status IN ('ACTIVE', 'PAUSED')
           GROUP BY status, pause_reason`,
        ),
        database.query(
          `SELECT member_choice, count(*)::int AS count
           FROM coach_lock_incidents
           WHERE status = 'OPEN'
           GROUP BY member_choice`,
        ),
        database.query(
          `SELECT count(*)::int AS count
           FROM coach_termination_requests
           WHERE status = 'DISPUTED'`,
        ),
        database.query(
          `SELECT (confirmed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS day,
                  coalesce(sum(amount), 0)::text AS amount,
                  count(*)::int AS count
           FROM payments
           WHERE status = 'SUCCESS'
             AND (confirmed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date BETWEEN $1::date AND $2::date
           GROUP BY day
           ORDER BY day`,
          [from, to],
        ),
        database.query(
          `SELECT (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS day,
                  coalesce(sum(reversed_amount), 0)::text AS amount,
                  count(*)::int AS count
           FROM payment_adjustments
           WHERE adjustment_type = 'VOID_REVERSAL'
             AND (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date BETWEEN $1::date AND $2::date
           GROUP BY day
           ORDER BY day`,
          [from, to],
        ),
        database.query(
          `SELECT (coalesce(settled_at, created_at) AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS day,
                  coalesce(sum(amount), 0)::text AS amount,
                  count(*)::int AS count
           FROM coach_payment_holds
           WHERE status = 'CONSUMED'
             AND (coalesce(settled_at, created_at) AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
               BETWEEN $1::date AND $2::date
           GROUP BY day
           ORDER BY day`,
          [from, to],
        ),
        database.query(
          `SELECT (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS day,
                  coalesce(sum(refund_amount), 0)::text AS amount,
                  count(*)::int AS count
           FROM simulated_refunds
           WHERE status = 'COMPLETED'
             AND (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date BETWEEN $1::date AND $2::date
           GROUP BY day
           ORDER BY day`,
          [from, to],
        ),
        database.query(
          `SELECT (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS day,
                  count(*)::int AS count
           FROM users
           WHERE role = 'MEMBER'
             AND (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date BETWEEN $1::date AND $2::date
           GROUP BY day
           ORDER BY day`,
          [from, to],
        ),
      ]);

      const userCounts = Object.fromEntries(
        usersResult.rows.map((row) => [`${row.role}_${row.status}`, row.count]),
      );

      let activeCoachRelationships = 0;
      let pausedMembershipExpired = 0;
      let pausedCoachLocked = 0;
      let pausedMemberLocked = 0;
      let pausedTotal = 0;
      for (const row of relationshipsResult.rows) {
        if (row.status === 'ACTIVE') {
          activeCoachRelationships += row.count;
        } else if (row.status === 'PAUSED') {
          pausedTotal += row.count;
          if (row.pause_reason === 'MEMBERSHIP_EXPIRED') pausedMembershipExpired += row.count;
          else if (row.pause_reason === 'COACH_LOCKED') pausedCoachLocked += row.count;
          else if (row.pause_reason === 'MEMBER_LOCKED') pausedMemberLocked += row.count;
        }
      }

      const incidentCounts = Object.fromEntries(
        incidentsResult.rows.map((row) => [row.member_choice, row.count]),
      );

      const revenue = accumulateRevenueByDay({
        gymRows: gymPaymentsResult.rows,
        voidRows: voidReversalsResult.rows,
        coachRows: coachPaymentsResult.rows,
        refundRows: simulatedRefundsResult.rows,
      });

      return response.json({
        data: {
          from,
          to,
          timezone: VIETNAM_TIMEZONE,
          members: {
            active: userCounts.MEMBER_ACTIVE ?? 0,
            disabled: userCounts.MEMBER_DISABLED ?? 0,
          },
          coaches: {
            active: userCounts.COACH_ACTIVE ?? 0,
            disabled: userCounts.COACH_DISABLED ?? 0,
          },
          activeMemberships: membershipsResult.rows[0].count,
          todayCheckins: checkinsResult.rows[0].count,
          activeCoachRelationships,
          pausedCoachRelationships: {
            total: pausedTotal,
            membershipExpired: pausedMembershipExpired,
            coachLocked: pausedCoachLocked,
            memberLocked: pausedMemberLocked,
          },
          actionQueue: {
            coachLockedWaitingCount: incidentCounts.WAIT ?? 0,
            coachLockedRefundRequestedCount: incidentCounts.REFUND ?? 0,
            disputedTerminationCount: disputedTerminationsResult.rows[0].count,
          },
          revenue,
          newMembersByDay: newMembersResult.rows,
        },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được dashboard');
    }
  });

  return router;
}
