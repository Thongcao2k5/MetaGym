import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, message, details: {} } });
}

export function createDashboardRouter({ database, jwtSecret }) {
  const router = Router();
  router.use(createAuthentication({ database, jwtSecret }));
  router.get('/admin/dashboard', async (request, response) => {
    if (request.authUser.role !== 'ADMIN') return fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị');
    const parsed = z.strictObject({
      from: z.iso.date().optional(), to: z.iso.date().optional(),
    }).safeParse(request.query);
    if (!parsed.success || (parsed.data.from && parsed.data.to && parsed.data.from > parsed.data.to)) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Khoảng ngày không hợp lệ');
    }
    const localDate = (value) => new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Ho_Chi_Minh', year: 'numeric', month: '2-digit', day: '2-digit',
    }).format(value);
    const today = localDate(new Date());
    const start = localDate(new Date(Date.now() - 29 * 86400000));
    const from = parsed.data.from ?? start;
    const to = parsed.data.to ?? today;
    if (from > to) return fail(response, 422, 'VALIDATION_ERROR', 'Khoảng ngày không hợp lệ');
    try {
      const [users, memberships, pendingRequests, pendingTerminations,
        revenue, dailyRevenue, newMembers] = await Promise.all([
        database.query(
          `SELECT role, status, count(*)::int AS count FROM users
           WHERE role IN ('MEMBER', 'COACH') GROUP BY role, status`,
        ),
        database.query(
          `SELECT count(*)::int AS count FROM member_memberships
           WHERE status = 'ACTIVE'
           AND start_date <= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
           AND end_date >= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date`,
        ),
        database.query("SELECT count(*)::int AS count FROM coach_requests WHERE status = 'PENDING'"),
        database.query("SELECT count(*)::int AS count FROM coach_termination_requests WHERE status = 'PENDING'"),
        database.query(
          `SELECT coalesce(sum(amount), 0)::text AS total,
                  count(*)::int AS count FROM payments
           WHERE status = 'SUCCESS'
           AND (confirmed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
             BETWEEN $1::date AND $2::date`, [from, to],
        ),
        database.query(
          `SELECT (confirmed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS day,
                  sum(amount)::text AS amount, count(*)::int AS count
           FROM payments WHERE status = 'SUCCESS'
           AND (confirmed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
             BETWEEN $1::date AND $2::date
           GROUP BY day ORDER BY day`, [from, to],
        ),
        database.query(
          `SELECT (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS day,
                  count(*)::int AS count FROM users WHERE role = 'MEMBER'
           AND (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
             BETWEEN $1::date AND $2::date
           GROUP BY day ORDER BY day`, [from, to],
        ),
      ]);
      const counts = Object.fromEntries(users.rows.map((row) =>
        [`${row.role}_${row.status}`, row.count]));
      return response.json({ data: {
        from, to,
        members: { active: counts.MEMBER_ACTIVE ?? 0,
          disabled: counts.MEMBER_DISABLED ?? 0 },
        coaches: { active: counts.COACH_ACTIVE ?? 0,
          disabled: counts.COACH_DISABLED ?? 0 },
        activeMemberships: memberships.rows[0].count,
        pendingCoachRequests: pendingRequests.rows[0].count,
        pendingTerminationRequests: pendingTerminations.rows[0].count,
        revenue: { amount: revenue.rows[0].total,
          paymentCount: revenue.rows[0].count, byDay: dailyRevenue.rows },
        newMembersByDay: newMembers.rows,
      } });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được dashboard'); }
  });
  return router;
}
