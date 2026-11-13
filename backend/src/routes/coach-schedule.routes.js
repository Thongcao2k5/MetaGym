import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();
const scheduleSchema = z.strictObject({
  days: z.array(z.strictObject({
    weekday: z.number().int().min(1).max(7),
    starts: z.array(z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/))
      .min(4).max(16),
  })).min(6).max(7),
});

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, details: {}, message } });
}

function minute(time) {
  const [hour, value] = time.split(':').map(Number);
  return hour * 60 + value;
}

function clock(value) {
  return `${String(Math.floor(value / 60)).padStart(2, '0')}:` +
    `${String(value % 60).padStart(2, '0')}`;
}

function validDays(days) {
  if (new Set(days.map((day) => day.weekday)).size !== days.length) return false;
  return days.every((day) => {
    const starts = day.starts.map(minute);
    return starts.at(-1) + 90 <= 1440 &&
      starts.every((value, index) => index === 0 || value - starts[index - 1] === 90);
  });
}

function view(rows) {
  const days = [];
  for (const row of rows) {
    let day = days.at(-1);
    if (day?.weekday !== row.weekday) {
      day = { weekday: row.weekday, starts: [] };
      days.push(day);
    }
    day.starts.push(clock(row.start_minute));
  }
  return { days, configured: days.length >= 6 };
}

export function createCoachScheduleRouter({ database, jwtSecret }) {
  const router = Router();

  router.get('/coaches/:coachId/work-slots', async (request, response) => {
    if (!uuid.safeParse(request.params.coachId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã Coach không hợp lệ');
    }
    try {
      const coach = await database.query(
        `SELECT 1 FROM users WHERE id = $1 AND role = 'COACH' AND status = 'ACTIVE'`,
        [request.params.coachId],
      );
      if (!coach.rows.length) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy Coach');
      const result = await database.query(
        `SELECT weekday, start_minute FROM coach_weekly_slots
         WHERE coach_id = $1 ORDER BY weekday, start_minute`,
        [request.params.coachId],
      );
      return response.json({ data: view(result.rows) });
    } catch { return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được lịch Coach'); }
  });

  router.put('/coach/work-slots', createAuthentication({ database, jwtSecret }),
    async (request, response) => {
      if (request.authUser.role !== 'COACH') {
        return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được sửa lịch làm việc');
      }
      const parsed = scheduleSchema.safeParse(request.body);
      if (!parsed.success || !validDays(parsed.data.days)) {
        return fail(response, 422, 'VALIDATION_ERROR',
          'Cần ít nhất 6 ngày, mỗi ngày 4 khung 90 phút liên tiếp');
      }
      const client = await database.connect().catch(() => null);
      if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
      try {
        await client.query('BEGIN');
        const actor = await client.query(
          `SELECT 1 FROM users WHERE id = $1 AND role = 'COACH'
           AND status = 'ACTIVE' AND session_version = $2 FOR UPDATE`,
          [request.authUser.id, request.authUser.session_version],
        );
        if (!actor.rows.length) {
          await client.query('ROLLBACK');
          return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
        }
        const commitments = await client.query(
          `SELECT 1 FROM coach_entitlements WHERE coach_id = $1
           AND status IN ('ACTIVE', 'QUEUED') LIMIT 1`, [request.authUser.id],
        );
        if (commitments.rowCount) {
          await client.query('ROLLBACK');
          return fail(response, 409, 'SCHEDULE_HAS_COMMITMENTS',
            'Chưa thể đổi lịch cố định trong khi có gói Coach đang hiệu lực hoặc đang chờ');
        }
        await client.query('DELETE FROM coach_weekly_slots WHERE coach_id = $1',
          [request.authUser.id]);
        for (const day of parsed.data.days) {
          for (const start of day.starts) {
            await client.query(
              `INSERT INTO coach_weekly_slots (id, coach_id, weekday, start_minute)
               VALUES ($1, $2, $3, $4)`,
              [randomUUID(), request.authUser.id, day.weekday, minute(start)],
            );
          }
        }
        const result = await client.query(
          `SELECT weekday, start_minute FROM coach_weekly_slots
           WHERE coach_id = $1 ORDER BY weekday, start_minute`,
          [request.authUser.id],
        );
        await client.query('COMMIT');
        return response.json({ data: view(result.rows) });
      } catch {
        await client.query('ROLLBACK').catch(() => {});
        return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không lưu được lịch Coach');
      } finally { client.release(); }
    });

  return router;
}
