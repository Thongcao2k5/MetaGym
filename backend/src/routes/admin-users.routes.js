import { randomBytes, randomUUID } from 'node:crypto';

import bcrypt from 'bcryptjs';
import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();
const PASSWORD_RESET_REMINDER =
  'Hãy gửi mật khẩu tạm cho Coach qua kênh nội bộ và nhắc Coach đổi mật khẩu sau khi đăng nhập.';

const coachCreate = z.strictObject({
  email: z.string().trim().toLowerCase().email(),
  fullName: z.string().trim().min(2).max(120),
  password: z.string().min(8).refine((value) =>
    Buffer.byteLength(value, 'utf8') <= 72 && /[a-z]/.test(value) &&
    /[A-Z]/.test(value) && /[0-9]/.test(value)),
  memberLimit: z.literal(8).optional(),
});

const accountPatch = z.strictObject({
  fullName: z.string().trim().min(2).max(120).optional(),
  phone: z.string().trim().max(20).nullable().optional(),
});

const statusPatch = z.strictObject({
  status: z.enum(['ACTIVE', 'DISABLED']),
  reason: z.string().trim().min(1).max(500).optional(),
});

function fail(response, status, code, message, details = {}) {
  return response.status(status).json({ error: { code, details, message } });
}

function validationError(response, issue, message = 'Dữ liệu không hợp lệ') {
  const fields = {};
  for (const item of issue.issues) {
    if (item.code === 'unrecognized_keys') {
      for (const key of item.keys) {
        fields[key] = [...(fields[key] ?? []), 'Trường này không được phép'];
      }
    } else if (typeof item.path[0] === 'string') {
      const key = item.path[0];
      fields[key] = [...(fields[key] ?? []), item.message];
    }
  }
  return fail(response, 422, 'VALIDATION_ERROR', message, { fields });
}

function escapeLike(value) {
  return value.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
}

function publicAccount(row) {
  const base = {
    id: row.id,
    email: row.email,
    fullName: row.full_name,
    phone: row.phone ?? null,
    role: row.role,
    status: row.status,
    disabledAt: row.disabled_at ?? null,
    disabledReason: row.disabled_reason ?? null,
    memberLimit: row.role === 'COACH' ? 8 : null,
    lastLoginAt: row.last_login_at ?? null,
    createdAt: row.created_at,
  };
  if (row.role === 'COACH' && row.used_slots !== undefined) {
    base.usedSlots = Number(row.used_slots);
  }
  if (row.role === 'MEMBER' && 'active_membership_end_date' in row) {
    base.activeMembershipEndDate = row.active_membership_end_date ?? null;
    base.coachRelationshipStatus = row.coach_relationship_status ?? null;
    base.coachPauseReason = row.coach_pause_reason ?? null;
  }
  return base;
}

async function audit(client, adminId, action, entityId, summary, metadata) {
  await client.query(
    `INSERT INTO admin_audit_logs
     (id, admin_id, action, entity_type, entity_id, summary, metadata)
     VALUES ($1, $2, $3, 'USER', $4, $5, $6)`,
    [randomUUID(), adminId, action, entityId, summary, JSON.stringify(metadata)],
  );
}

async function fetchAccount(database, id, lock = false) {
  const result = await database.query(
    `SELECT u.id, u.email::text, u.full_name, u.phone, u.role,
            u.status, u.disabled_at, u.disabled_reason, u.last_login_at,
            u.created_at, c.member_limit
     FROM users u LEFT JOIN coach_profiles c ON c.user_id = u.id
     WHERE u.id = $1 AND u.role IN ('MEMBER', 'COACH')
     ${lock ? 'FOR UPDATE OF u' : ''}`,
    [id],
  );
  return result.rows[0];
}

async function activeAdmin(client, user) {
  const result = await client.query(
    `SELECT id FROM users WHERE id = $1 AND role = 'ADMIN' AND status = 'ACTIVE'
     AND session_version = $2 FOR SHARE`,
    [user.id, user.session_version],
  );
  return result.rows.length === 1;
}

async function hasActiveGymMembershipToday(client, memberId, todayVn) {
  const { rows } = await client.query(
    `SELECT 1 FROM member_memberships
     WHERE member_id = $1
       AND status = 'ACTIVE'
       AND start_date <= $2::date
       AND end_date >= $2::date
     LIMIT 1`,
    [memberId, todayVn],
  );
  return rows.length === 1;
}

async function reconcileSingleMemberLifecycle(client, memberId, todayVn) {
  await client.query(
    `UPDATE member_memberships SET status = 'EXPIRED', expired_at = statement_timestamp()
     WHERE member_id = $1 AND status = 'ACTIVE' AND end_date < $2::date`,
    [memberId, todayVn],
  );
  await client.query(
    `UPDATE member_memberships
     SET status = 'EXPIRED',
         activated_at = start_date::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh',
         expired_at = statement_timestamp()
     WHERE member_id = $1 AND status = 'SCHEDULED' AND end_date < $2::date`,
    [memberId, todayVn],
  );
  await client.query(
    `UPDATE member_memberships
     SET status = 'ACTIVE', activated_at = statement_timestamp()
     WHERE member_id = $1 AND status = 'SCHEDULED'
       AND start_date <= $2::date AND end_date >= $2::date`,
    [memberId, todayVn],
  );
  await client.query(
    `UPDATE coach_entitlements
     SET grace_days_added = 7,
         ends_on = original_ends_on + frozen_days_total + 7
     WHERE member_id = $1
       AND status = 'ACTIVE'
       AND frozen_at IS NULL
       AND grace_days_added = 0
       AND remaining_sessions > 0
       AND original_ends_on + frozen_days_total < $2::date`,
    [memberId, todayVn],
  );
  await client.query(
    `WITH expired AS (
       UPDATE coach_entitlements
       SET status = 'ENDED', ended_at = statement_timestamp(), close_reason = 'EXPIRED'
       WHERE member_id = $1 AND status = 'ACTIVE' AND frozen_at IS NULL AND ends_on < $2::date
       RETURNING relationship_id, ends_on
     ), activated AS (
       UPDATE coach_entitlements e
       SET status = CASE WHEN expired.ends_on + e.duration_days + 7 < $2::date THEN 'ENDED' ELSE 'ACTIVE' END,
           starts_on = expired.ends_on + 1,
           original_ends_on = expired.ends_on + e.duration_days,
           grace_days_added = CASE WHEN expired.ends_on + e.duration_days < $2::date THEN 7 ELSE 0 END,
           ends_on = expired.ends_on + e.duration_days
             + CASE WHEN expired.ends_on + e.duration_days < $2::date THEN 7 ELSE 0 END,
           ended_at = CASE WHEN expired.ends_on + e.duration_days + 7 < $2::date
                           THEN statement_timestamp() END,
           close_reason = CASE WHEN expired.ends_on + e.duration_days + 7 < $2::date
                               THEN 'EXPIRED' END
       FROM expired WHERE e.relationship_id = expired.relationship_id AND e.status = 'QUEUED'
       RETURNING e.relationship_id, e.status
     )
     UPDATE coach_relationships r
     SET status = 'ENDED', ended_at = statement_timestamp(),
         ended_by = r.coach_id, end_reason = 'Gói Coach đã hết hạn'
     FROM expired
     WHERE r.id = expired.relationship_id
       AND r.status IN ('ACTIVE', 'PAUSED')
       AND NOT EXISTS (
         SELECT 1 FROM activated a WHERE a.relationship_id = r.id AND a.status = 'ACTIVE'
       )`,
    [memberId, todayVn],
  );
}

export function createAdminUsersRouter({ database, jwtSecret }) {
  const router = Router();
  router.use(createAuthentication({ database, jwtSecret }));
  router.use((request, response, next) => request.authUser.role === 'ADMIN'
    ? next() : fail(response, 403, 'FORBIDDEN', 'Không có quyền quản trị'));

  router.get('/users', async (request, response) => {
    const parsed = z.strictObject({
      role: z.enum(['MEMBER', 'COACH']).optional(),
      status: z.enum(['ACTIVE', 'DISABLED']).optional(),
      search: z.string().trim().max(120).optional(),
      page: z.coerce.number().int().min(1).default(1),
      pageSize: z.coerce.number().int().min(1).max(100).default(20),
    }).safeParse(request.query);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Bộ lọc không hợp lệ');
    const { role, status, search, page, pageSize } = parsed.data;
    const filters = [`u.role IN ('MEMBER', 'COACH')`];
    const values = [];
    if (role) { values.push(role); filters.push(`u.role = $${values.length}`); }
    if (status) { values.push(status); filters.push(`u.status = $${values.length}`); }
    if (search) {
      values.push(`%${escapeLike(search)}%`);
      const p = `$${values.length}`;
      filters.push(
        `(u.email::text ILIKE ${p} ESCAPE '\\' OR u.full_name ILIKE ${p} ESCAPE '\\' OR COALESCE(u.phone, '') ILIKE ${p} ESCAPE '\\')`,
      );
    }
    try {
      const total = await database.query(
        `SELECT count(*)::int AS count FROM users u WHERE ${filters.join(' AND ')}`,
        values,
      );
      const rows = await database.query(
        `SELECT u.id, u.email::text, u.full_name, u.phone, u.role, u.status,
                u.disabled_at, u.disabled_reason, u.last_login_at, u.created_at,
                c.member_limit,
                CASE WHEN u.role = 'COACH' THEN coach_occupied_seats(u.id) ELSE NULL END AS used_slots,
                CASE WHEN u.role = 'MEMBER' THEN (
                  SELECT m.end_date::text
                  FROM member_memberships m
                  WHERE m.member_id = u.id
                    AND m.status = 'ACTIVE'
                    AND (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
                        BETWEEN m.start_date AND m.end_date
                  ORDER BY m.end_date DESC
                  LIMIT 1
                ) ELSE NULL END AS active_membership_end_date,
                rel.status AS coach_relationship_status,
                rel.pause_reason AS coach_pause_reason
         FROM users u
         LEFT JOIN coach_profiles c ON c.user_id = u.id
         LEFT JOIN LATERAL (
           SELECT r.status, r.pause_reason
           FROM coach_relationships r
           WHERE u.role = 'MEMBER' AND r.member_id = u.id AND r.status IN ('ACTIVE', 'PAUSED')
           LIMIT 1
         ) rel ON true
         WHERE ${filters.join(' AND ')}
         ORDER BY u.created_at DESC, u.id DESC
         LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
        [...values, pageSize, (page - 1) * pageSize],
      );
      const totalItems = total.rows[0].count;
      return response.json({
        data: rows.rows.map(publicAccount),
        pagination: {
          page,
          pageSize,
          totalItems,
          totalPages: Math.ceil(totalItems / pageSize),
        },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được tài khoản');
    }
  });

  router.get('/users/:userId', async (request, response) => {
    if (!uuid.safeParse(request.params.userId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã tài khoản không hợp lệ');
    }
    try {
      const account = await fetchAccount(database, request.params.userId);
      if (!account) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy tài khoản');

      const auditRows = (await database.query(
        `SELECT l.id, l.action, l.admin_id, u.full_name AS admin_name,
                l.summary, l.metadata->>'reason' AS reason, l.created_at
         FROM admin_audit_logs l
         LEFT JOIN users u ON u.id = l.admin_id
         WHERE l.entity_type = 'USER'
           AND l.entity_id = $1
           AND l.action IN ('USER_DISABLED', 'USER_ENABLED')
         ORDER BY l.created_at DESC, l.id DESC
         LIMIT 10`,
        [account.id],
      )).rows.map((entry) => ({
        id: entry.id,
        action: entry.action,
        adminId: entry.admin_id,
        adminName: entry.admin_name ?? null,
        summary: entry.summary,
        reason: entry.reason ?? null,
        createdAt: entry.created_at,
      }));

      const data = publicAccount(account);
      data.recentLockHistory = auditRows;

      if (account.role === 'COACH') {
        const { rows: [stats] } = await database.query(
          `SELECT coach_occupied_seats($1) AS used_slots,
                  (SELECT count(*)::int FROM coach_relationships
                   WHERE coach_id = $1 AND status = 'ACTIVE') AS active_relationships_count,
                  (SELECT count(*)::int FROM coach_relationships
                   WHERE coach_id = $1 AND status = 'PAUSED') AS paused_relationships_count,
                  (SELECT count(*)::int FROM coach_payment_holds
                   WHERE coach_id = $1 AND status = 'HELD'
                     AND expires_at > statement_timestamp()) AS open_hold_count,
                  ((SELECT count(*) FROM (
                     SELECT weekday FROM coach_weekly_slots
                     WHERE coach_id = $1
                     GROUP BY weekday HAVING count(*) >= 4
                   ) valid_days) >= 6) AS schedule_configured`,
          [account.id],
        );
        data.usedSlots = Number(stats.used_slots);
        data.activeRelationshipsCount = stats.active_relationships_count;
        data.pausedRelationshipsCount = stats.paused_relationships_count;
        data.openHoldCount = stats.open_hold_count;
        data.scheduleConfigured = Boolean(stats.schedule_configured);
      } else {
        const [membershipRes, relRes] = await Promise.all([
          database.query(
            `SELECT m.id, m.plan_id, p.plan_name_snapshot AS plan_name,
                    m.start_date::text, m.end_date::text, m.status
             FROM member_memberships m
             JOIN payments p ON p.id = m.source_payment_id
             WHERE m.member_id = $1 AND m.status IN ('ACTIVE', 'SCHEDULED')
             ORDER BY (m.status = 'ACTIVE') DESC, m.start_date ASC
             LIMIT 1`,
            [account.id],
          ),
          database.query(
            `SELECT r.id, r.coach_id, u.full_name AS coach_name,
                    r.status, r.pause_reason, r.started_at, r.paused_at
             FROM coach_relationships r
             JOIN users u ON u.id = r.coach_id
             WHERE r.member_id = $1 AND r.status IN ('ACTIVE', 'PAUSED')
             LIMIT 1`,
            [account.id],
          ),
        ]);
        const mem = membershipRes.rows[0] ?? null;
        const rel = relRes.rows[0] ?? null;
        data.activeMembershipEndDate = mem?.status === 'ACTIVE' ? mem.end_date : null;
        data.coachRelationshipStatus = rel?.status ?? null;
        data.coachPauseReason = rel?.pause_reason ?? null;
        data.currentMembership = mem ? {
          id: mem.id,
          planId: mem.plan_id,
          planName: mem.plan_name,
          startDate: mem.start_date,
          endDate: mem.end_date,
          status: mem.status,
        } : null;
        data.currentCoachRelationship = rel ? {
          id: rel.id,
          coachId: rel.coach_id,
          coachName: rel.coach_name,
          status: rel.status,
          pauseReason: rel.pause_reason ?? null,
          startedAt: rel.started_at,
          pausedAt: rel.paused_at ?? null,
        } : null;
      }

      return response.json({ data });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được tài khoản');
    }
  });

  router.get('/users/:userId/lock-preview', async (request, response) => {
    if (!uuid.safeParse(request.params.userId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã tài khoản không hợp lệ');
    }
    try {
      const account = await fetchAccount(database, request.params.userId);
      if (!account) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy tài khoản');

      if (account.role === 'COACH') {
        const [relRes, bookingRes, holdRes] = await Promise.all([
          database.query(
            `SELECT r.id AS relationship_id, r.member_id, u.full_name AS member_name,
                    r.status AS relationship_status, r.pause_reason,
                    e.id AS active_entitlement_id, e.remaining_sessions,
                    e.ends_on::text AS ends_on, e.frozen_at,
                    EXISTS (
                      SELECT 1 FROM member_memberships m
                      WHERE m.member_id = r.member_id AND m.status = 'ACTIVE'
                        AND (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
                            BETWEEN m.start_date AND m.end_date
                    ) AS has_active_gym
             FROM coach_relationships r
             JOIN users u ON u.id = r.member_id
             LEFT JOIN coach_entitlements e
               ON e.relationship_id = r.id AND e.status = 'ACTIVE'
             WHERE r.coach_id = $1 AND r.status IN ('ACTIVE', 'PAUSED')
             ORDER BY u.full_name ASC, r.id ASC`,
            [account.id],
          ),
          database.query(
            `SELECT count(*)::int AS count FROM coach_bookings
             WHERE coach_id = $1 AND status = 'BOOKED' AND starts_at > statement_timestamp()`,
            [account.id],
          ),
          database.query(
            `SELECT count(*)::int AS count FROM coach_payment_holds
             WHERE coach_id = $1 AND status = 'HELD' AND expires_at > statement_timestamp()`,
            [account.id],
          ),
        ]);

        const affectedMembers = relRes.rows
          .filter((row) => row.relationship_status === 'ACTIVE' || row.pause_reason === 'MEMBERSHIP_EXPIRED')
          .map((row) => ({
            relationshipId: row.relationship_id,
            memberId: row.member_id,
            memberName: row.member_name,
            relationshipStatus: row.relationship_status,
            pauseReason: row.pause_reason ?? null,
            willFreezeEntitlement: Boolean(row.active_entitlement_id) && Boolean(row.has_active_gym),
            activeEntitlementRemainingSessions: row.remaining_sessions ?? null,
            activeEntitlementEndsOn: row.ends_on ?? null,
          }));

        return response.json({
          data: {
            user: {
              id: account.id,
              fullName: account.full_name,
              email: account.email,
              role: account.role,
              status: account.status,
            },
            affectedRelationshipsCount: affectedMembers.length,
            affectedMembers,
            currentCoachRelationship: null,
            futureBookingsToCancelCount: bookingRes.rows[0].count,
            openHoldsToCancelCount: holdRes.rows[0].count,
            policy: {
              freezeCoachEntitlements: true,
              freezeGymMemberships: false,
              keepCoachSeatsOccupied: true,
              blockIncomingChat: true,
              revokeSessions: true,
              summary:
                'Khóa Coach sẽ thu hồi phiên đăng nhập, hủy suất giữ đang mở, hủy lịch tập tương lai không trừ buổi, chuyển các quan hệ sang COACH_LOCKED và đóng băng thời hạn gói Coach (không đóng băng gói Gym).',
            },
          },
        });
      }

      const [relRes, bookingRes, holdRes] = await Promise.all([
        database.query(
          `SELECT r.id AS relationship_id, r.coach_id, u.full_name AS coach_name,
                  r.status AS relationship_status, r.pause_reason
           FROM coach_relationships r
           JOIN users u ON u.id = r.coach_id
           WHERE r.member_id = $1 AND r.status IN ('ACTIVE', 'PAUSED')
           LIMIT 1`,
          [account.id],
        ),
        database.query(
          `SELECT count(*)::int AS count FROM coach_bookings
           WHERE member_id = $1 AND status = 'BOOKED' AND starts_at > statement_timestamp()`,
          [account.id],
        ),
        database.query(
          `SELECT count(*)::int AS count FROM coach_payment_holds
           WHERE member_id = $1 AND status = 'HELD' AND expires_at > statement_timestamp()`,
          [account.id],
        ),
      ]);
      const rel = relRes.rows[0] ?? null;
      const willPauseMemberLocked = Boolean(rel)
        && (rel.relationship_status === 'ACTIVE' || rel.pause_reason === 'MEMBERSHIP_EXPIRED');

      return response.json({
        data: {
          user: {
            id: account.id,
            fullName: account.full_name,
            email: account.email,
            role: account.role,
            status: account.status,
          },
          affectedRelationshipsCount: willPauseMemberLocked ? 1 : 0,
          affectedMembers: [],
          currentCoachRelationship: rel ? {
            relationshipId: rel.relationship_id,
            coachId: rel.coach_id,
            coachName: rel.coach_name,
            status: rel.relationship_status,
            pauseReason: rel.pause_reason ?? null,
          } : null,
          futureBookingsToCancelCount: bookingRes.rows[0].count,
          openHoldsToCancelCount: holdRes.rows[0].count,
          policy: {
            freezeCoachEntitlements: false,
            freezeGymMemberships: false,
            keepCoachSeatsOccupied: true,
            hideHealthProfileFromCoach: true,
            blockIncomingChat: true,
            revokeSessions: true,
            summary:
              'Khóa Member sẽ thu hồi phiên đăng nhập, hủy suất giữ đang mở, hủy lịch tập tương lai không trừ buổi, ẩn hồ sơ sức khỏe khỏi Coach và chuyển quan hệ sang MEMBER_LOCKED. Suất Coach vẫn được giữ và thời hạn gói Gym/Coach tiếp tục chạy bình thường.',
          },
        },
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tạo được xem trước tác động khóa');
    }
  });

  router.post('/coaches', async (request, response) => {
    const parsed = coachCreate.safeParse(request.body);
    if (!parsed.success) {
      return validationError(response, parsed.error, 'Dữ liệu Coach không hợp lệ');
    }
    const { email, fullName, password } = parsed.data;
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      const hash = await bcrypt.hash(password, 12);
      const id = randomUUID();
      await client.query('BEGIN');
      if (!await activeAdmin(client, request.authUser)) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      await client.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, $3, 'COACH', $4)`,
        [id, email, hash, fullName],
      );
      await client.query(
        'INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 8)',
        [id],
      );
      await audit(client, request.authUser.id, 'COACH_CREATED', id, `Tạo tài khoản Coach: ${fullName}`, {
        before: null,
        after: { email, fullName, memberLimit: 8 },
      });
      const coach = await fetchAccount(client, id);
      await client.query('COMMIT');
      return response.status(201).json({ data: publicAccount({ ...coach, used_slots: 0 }) });
    } catch (cause) {
      await client.query('ROLLBACK').catch(() => {});
      if (cause.code === '23505' && cause.constraint === 'users_email_key') {
        return fail(response, 409, 'EMAIL_ALREADY_EXISTS', 'Email đã được sử dụng');
      }
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tạo được Coach');
    } finally { client.release(); }
  });

  router.post('/coaches/:coachId/password-resets', async (request, response) => {
    if (!uuid.safeParse(request.params.coachId).success ||
      !z.strictObject({}).safeParse(request.body ?? {}).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu không hợp lệ');
    }
    const temporaryPassword = `A1a${randomBytes(18).toString('base64url')}`;
    const hash = await bcrypt.hash(temporaryPassword, 12);
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      if (!await activeAdmin(client, request.authUser)) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const coach = await client.query(
        `SELECT id, full_name FROM users WHERE id = $1 AND role = 'COACH' FOR UPDATE`,
        [request.params.coachId],
      );
      if (!coach.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy Coach');
      }
      await client.query(
        `UPDATE users SET password_hash = $1, session_version = session_version + 1
         WHERE id = $2`,
        [hash, request.params.coachId],
      );
      await audit(
        client,
        request.authUser.id,
        'COACH_PASSWORD_RESET',
        request.params.coachId,
        `Đặt lại mật khẩu tạm cho Coach: ${coach.rows[0].full_name}`,
        { sessionRevoked: true },
      );
      await client.query('COMMIT');
      return response.status(201).json({
        data: {
          temporaryPassword,
          reminder: PASSWORD_RESET_REMINDER,
        },
      });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không đặt lại được mật khẩu Coach');
    } finally { client.release(); }
  });

  router.patch('/users/:userId', async (request, response) => {
    if (!uuid.safeParse(request.params.userId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã tài khoản không hợp lệ');
    }
    const parsed = accountPatch.safeParse(request.body);
    if (!parsed.success) {
      return validationError(response, parsed.error, 'Dữ liệu cập nhật không hợp lệ');
    }
    if (!Object.keys(parsed.data).length) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu cập nhật không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      if (!await activeAdmin(client, request.authUser)) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const before = await fetchAccount(client, request.params.userId, true);
      if (!before) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy tài khoản');
      }
      const fields = [['fullName', 'full_name'], ['phone', 'phone']]
        .filter(([key]) => key in parsed.data);
      if (fields.length) {
        await client.query(
          `UPDATE users SET ${fields.map(([, column], index) => `${column} = $${index + 1}`).join(', ')} WHERE id = $${fields.length + 1}`,
          [...fields.map(([key]) => parsed.data[key]), before.id],
        );
      }
      const after = await fetchAccount(client, before.id);
      await audit(client, request.authUser.id, 'USER_UPDATED', before.id, `Cập nhật tài khoản: ${after.full_name}`, {
        before: publicAccount(before),
        after: publicAccount(after),
      });
      await client.query('COMMIT');
      return response.json({ data: publicAccount(after) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không cập nhật được tài khoản');
    } finally { client.release(); }
  });

  router.patch('/users/:userId/status', async (request, response) => {
    if (!uuid.safeParse(request.params.userId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã tài khoản không hợp lệ');
    }
    const parsed = statusPatch.safeParse(request.body);
    if (!parsed.success || (parsed.data.status === 'DISABLED' && !parsed.data.reason)) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Trạng thái hoặc lý do không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      // Canonical lock order (T2 §4):
      // 1. Membership lifecycle advisory lock
      await client.query(`SELECT pg_advisory_xact_lock(hashtext('meta-gym-membership-lifecycle'))`);
      // 2. Active Admin FOR SHARE
      if (!await activeAdmin(client, request.authUser)) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      // Read target role first to acquire user locks strictly Coach-before-Member
      const targetLookup = await client.query(
        `SELECT id, role FROM users WHERE id = $1 AND role IN ('MEMBER', 'COACH')`,
        [request.params.userId],
      );
      if (!targetLookup.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy tài khoản');
      }
      const targetRole = targetLookup.rows[0].role;
      const { rows: [{ today_vn: todayVn }] } = await client.query(
        `SELECT (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS today_vn`,
      );

      // 3. Lock users: Coach FIRST, Member SECOND (id ASC within role)
      let before;
      let lockedCoach = null;
      const lockedMembersById = new Map();
      if (targetRole === 'COACH') {
        before = await fetchAccount(client, request.params.userId, true);
        const relatedMemberIds = (await client.query(
          `SELECT DISTINCT member_id FROM (
             SELECT member_id FROM coach_relationships
             WHERE coach_id = $1 AND status IN ('ACTIVE', 'PAUSED')
             UNION
             SELECT member_id FROM coach_lock_incidents
             WHERE coach_id = $1 AND status = 'OPEN'
             UNION
             SELECT member_id FROM coach_payment_holds
             WHERE coach_id = $1 AND status = 'HELD'
           ) affected ORDER BY member_id ASC`,
          [before.id],
        )).rows.map((r) => r.member_id);
        if (relatedMemberIds.length) {
          const lockedMembers = await client.query(
            `SELECT id, status, full_name FROM users
             WHERE id = ANY($1::uuid[]) ORDER BY id ASC FOR UPDATE`,
            [relatedMemberIds],
          );
          for (const m of lockedMembers.rows) lockedMembersById.set(m.id, m);
        }
      } else {
        const currentRelCoach = await client.query(
          `SELECT coach_id FROM coach_relationships
           WHERE member_id = $1 AND status IN ('ACTIVE', 'PAUSED') LIMIT 1`,
          [request.params.userId],
        );
        if (currentRelCoach.rows.length) {
          lockedCoach = (await client.query(
            `SELECT id, status, full_name FROM users WHERE id = $1 FOR UPDATE`,
            [currentRelCoach.rows[0].coach_id],
          )).rows[0] ?? null;
        }
        before = await fetchAccount(client, request.params.userId, true);
      }

      if (!before) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy tài khoản');
      }

      // Idempotent no-op when already in target status
      if (before.status === parsed.data.status) {
        await client.query('COMMIT');
        const noOpEffects = targetRole === 'COACH'
          ? (parsed.data.status === 'DISABLED'
            ? {
                sessionsRevoked: false,
                cancelledHoldsCount: 0,
                cancelledFutureBookingsCount: 0,
                affectedRelationshipsCount: 0,
                incidentsCreated: [],
              }
            : { restoredRelationshipsCount: 0, restored: [] })
          : (parsed.data.status === 'DISABLED'
            ? {
                sessionsRevoked: false,
                cancelledHoldsCount: 0,
                cancelledFutureBookingsCount: 0,
                relationshipStatus: null,
                pauseReason: null,
                coachSeatKept: false,
                entitlementFrozen: false,
                gymMembershipFrozen: false,
              }
            : { relationshipStatus: null, pauseReason: null });
        return response.json({ data: { user: publicAccount(before), effects: noOpEffects } });
      }

      // ============================================================
      // BRANCH 1: LOCK COACH (ACTIVE -> DISABLED) — D1
      // ============================================================
      if (targetRole === 'COACH' && parsed.data.status === 'DISABLED') {
        // 4. Lock coach_relationships
        const rels = (await client.query(
          `SELECT * FROM coach_relationships
           WHERE coach_id = $1 AND status IN ('ACTIVE', 'PAUSED')
           ORDER BY id ASC FOR UPDATE`,
          [before.id],
        )).rows;
        // 5. Lock coach_entitlements
        const entitlements = (await client.query(
          `SELECT * FROM coach_entitlements
           WHERE coach_id = $1 AND status IN ('ACTIVE', 'QUEUED')
           ORDER BY id ASC FOR UPDATE`,
          [before.id],
        )).rows;
        // 6. Lock coach_payment_holds
        await client.query(
          `SELECT id FROM coach_payment_holds
           WHERE coach_id = $1 AND status = 'HELD' ORDER BY id ASC FOR UPDATE`,
          [before.id],
        );
        // 7. Lock future coach_bookings
        await client.query(
          `SELECT id FROM coach_bookings
           WHERE coach_id = $1 AND status = 'BOOKED' AND starts_at > statement_timestamp()
           ORDER BY id ASC FOR UPDATE`,
          [before.id],
        );

        await client.query(
          `UPDATE users
           SET status = 'DISABLED', disabled_at = statement_timestamp(),
               disabled_reason = $1, session_version = session_version + 1
           WHERE id = $2`,
          [parsed.data.reason, before.id],
        );

        const cancelledHolds = await client.query(
          `UPDATE coach_payment_holds SET status = 'CANCELLED'
           WHERE coach_id = $1 AND status = 'HELD' RETURNING id`,
          [before.id],
        );

        // Cancel future BOOKED bookings BEFORE updating relationships so we get exact count
        // and never charge sessions (charged_at remains NULL).
        const cancelledBookings = await client.query(
          `UPDATE coach_bookings
           SET status = 'CANCELLED',
               resolved_at = statement_timestamp(),
               resolved_by = $2,
               reason = 'Tài khoản Coach bị khóa'
           WHERE coach_id = $1
             AND status = 'BOOKED'
             AND starts_at > statement_timestamp()
           RETURNING id`,
          [before.id, request.authUser.id],
        );

        const incidentsCreated = [];
        for (const rel of rels) {
          // Do not overwrite MEMBER_LOCKED (T2 §2 D1 edge case)
          if (rel.status === 'PAUSED' && rel.pause_reason === 'MEMBER_LOCKED') continue;

          const activeEnt = entitlements.find(
            (e) => e.relationship_id === rel.id && e.status === 'ACTIVE',
          ) ?? null;
          const queuedEnt = entitlements.find(
            (e) => e.relationship_id === rel.id && e.status === 'QUEUED',
          ) ?? null;

          const hasGym = await hasActiveGymMembershipToday(client, rel.member_id, todayVn);
          const shouldFreeze = Boolean(activeEnt) && hasGym;

          await client.query(
            `UPDATE coach_relationships
             SET status = 'PAUSED',
                 paused_at = statement_timestamp(),
                 pause_reason = 'COACH_LOCKED'
             WHERE id = $1`,
            [rel.id],
          );

          await client.query(
            `UPDATE training_sessions
             SET status = 'CANCELLED', cancelled_at = statement_timestamp(),
                 cancellation_reason = 'Tài khoản Coach bị khóa'
             WHERE relationship_id = $1 AND status = 'SCHEDULED'
               AND scheduled_start_at > statement_timestamp()`,
            [rel.id],
          );

          let frozenStartedAt = null;
          if (shouldFreeze) {
            if (activeEnt.frozen_at) {
              frozenStartedAt = activeEnt.frozen_at;
            } else {
              const { rows: [frozenRow] } = await client.query(
                `UPDATE coach_entitlements
                 SET frozen_at = statement_timestamp()
                 WHERE id = $1 AND frozen_at IS NULL
                 RETURNING frozen_at`,
                [activeEnt.id],
              );
              frozenStartedAt = frozenRow?.frozen_at ?? null;
            }
          }

          const incidentId = randomUUID();
          await client.query(
            `INSERT INTO coach_lock_incidents (
               id, coach_id, member_id, relationship_id,
               active_entitlement_id, queued_entitlement_id,
               lock_reason, locked_by, locked_at, frozen_started_at, status
             ) VALUES (
               $1, $2, $3, $4, $5, $6, $7, $8, statement_timestamp(), $9, 'OPEN'
             )`,
            [
              incidentId,
              before.id,
              rel.member_id,
              rel.id,
              activeEnt?.id ?? null,
              queuedEnt?.id ?? null,
              parsed.data.reason,
              request.authUser.id,
              frozenStartedAt,
            ],
          );

          await client.query(
            `INSERT INTO coach_notifications (user_id, kind, subject_id)
             VALUES ($1, 'COACH_LOCKED', $2)`,
            [rel.member_id, incidentId],
          );

          incidentsCreated.push({
            incidentId,
            relationshipId: rel.id,
            memberId: rel.member_id,
            memberName: lockedMembersById.get(rel.member_id)?.full_name ?? null,
            entitlementFrozen: Boolean(frozenStartedAt),
            frozenStartedAt,
          });
        }

        const after = await fetchAccount(client, before.id);
        const effects = {
          sessionsRevoked: true,
          cancelledHoldsCount: cancelledHolds.rowCount,
          cancelledFutureBookingsCount: cancelledBookings.rowCount,
          affectedRelationshipsCount: incidentsCreated.length,
          incidentsCreated,
        };
        await audit(client, request.authUser.id, 'USER_DISABLED', before.id, `Khóa tài khoản Coach: ${before.full_name}`, {
          before: publicAccount(before),
          after: publicAccount(after),
          reason: parsed.data.reason,
          cancelledHoldsCount: effects.cancelledHoldsCount,
          cancelledFutureBookingsCount: effects.cancelledFutureBookingsCount,
          affectedRelationshipsCount: effects.affectedRelationshipsCount,
          incidentIds: incidentsCreated.map((item) => item.incidentId),
        });
        await client.query('COMMIT');
        return response.json({ data: { user: publicAccount(after), effects } });
      }

      // ============================================================
      // BRANCH 2: UNLOCK COACH (DISABLED -> ACTIVE) — D1 AUTO-RESTORE
      // ============================================================
      if (targetRole === 'COACH' && parsed.data.status === 'ACTIVE') {
        // 4-6. Lock relationships, entitlements, and OPEN incidents in canonical order
        const rels = (await client.query(
          `SELECT * FROM coach_relationships
           WHERE coach_id = $1 AND status IN ('ACTIVE', 'PAUSED')
           ORDER BY id ASC FOR UPDATE`,
          [before.id],
        )).rows;
        const relMap = new Map(rels.map((r) => [r.id, r]));

        const entitlements = (await client.query(
          `SELECT * FROM coach_entitlements
           WHERE coach_id = $1 AND status IN ('ACTIVE', 'QUEUED')
           ORDER BY id ASC FOR UPDATE`,
          [before.id],
        )).rows;
        const entMap = new Map(entitlements.map((e) => [e.id, e]));

        const incidents = (await client.query(
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
           WHERE coach_id = $1 AND status = 'OPEN'
           ORDER BY id ASC FOR UPDATE`,
          [before.id],
        )).rows;

        await client.query(
          `UPDATE users
           SET status = 'ACTIVE', disabled_at = NULL, disabled_reason = NULL,
               session_version = session_version + 1
           WHERE id = $1`,
          [before.id],
        );

        const restored = [];
        for (const incident of incidents) {
          const rel = relMap.get(incident.relationship_id);
          if (!rel || rel.status === 'ENDED') {
            await client.query(
              `UPDATE coach_lock_incidents
               SET status = 'RESOLVED_ENDED',
                   resolved_by = $2,
                   resolved_at = statement_timestamp()
               WHERE id = $1 AND status = 'OPEN'`,
              [incident.id, request.authUser.id],
            );
            continue;
          }

          // Reconcile this member's Gym memberships (not frozen Coach entitlements)
          await client.query(
            `UPDATE member_memberships SET status = 'EXPIRED', expired_at = statement_timestamp()
             WHERE member_id = $1 AND status = 'ACTIVE' AND end_date < $2::date`,
            [incident.member_id, todayVn],
          );
          await client.query(
            `UPDATE member_memberships SET status = 'ACTIVE', activated_at = statement_timestamp()
             WHERE member_id = $1 AND status = 'SCHEDULED'
               AND start_date <= $2::date AND end_date >= $2::date`,
            [incident.member_id, todayVn],
          );

          const activeEnt = incident.active_entitlement_id
            ? entMap.get(incident.active_entitlement_id) ?? null
            : entitlements.find((e) => e.relationship_id === rel.id && e.status === 'ACTIVE') ?? null;

          let frozenDaysAdded = 0;
          let newEndsOn = activeEnt?.ends_on
            ? (activeEnt.ends_on instanceof Date
                ? activeEnt.ends_on.toISOString().slice(0, 10)
                : String(activeEnt.ends_on))
            : null;

          if (activeEnt && activeEnt.frozen_at && incident.frozen_days_applied === null) {
            frozenDaysAdded = Math.max(0, Number(incident.computed_delta_days ?? 0));
            const { rows: [thawed] } = await client.query(
              `UPDATE coach_entitlements
               SET frozen_days_total = frozen_days_total + $2,
                   ends_on = original_ends_on + frozen_days_total + $2 + grace_days_added,
                   frozen_at = NULL
               WHERE id = $1 AND frozen_at IS NOT NULL
               RETURNING ends_on::text AS ends_on`,
              [activeEnt.id, frozenDaysAdded],
            );
            if (thawed) newEndsOn = thawed.ends_on;
          } else if (activeEnt && activeEnt.frozen_at) {
            const { rows: [cleared] } = await client.query(
              `UPDATE coach_entitlements SET frozen_at = NULL
               WHERE id = $1 RETURNING ends_on::text AS ends_on`,
              [activeEnt.id],
            );
            if (cleared) newEndsOn = cleared.ends_on;
          }

          await client.query(
            `UPDATE coach_lock_incidents
             SET frozen_ended_at = CASE WHEN frozen_started_at IS NOT NULL THEN statement_timestamp() ELSE NULL END,
                 frozen_days_applied = COALESCE(frozen_days_applied, $2),
                 status = 'RESOLVED_COACH_UNLOCKED',
                 resolved_by = $3,
                 resolved_at = statement_timestamp()
             WHERE id = $1 AND status = 'OPEN'`,
            [incident.id, frozenDaysAdded, request.authUser.id],
          );

          const memberRow = lockedMembersById.get(incident.member_id);
          let newRelationshipStatus;
          let newPauseReason;
          if (memberRow?.status === 'DISABLED') {
            newRelationshipStatus = 'PAUSED';
            newPauseReason = 'MEMBER_LOCKED';
            await client.query(
              `UPDATE coach_relationships
               SET status = 'PAUSED', paused_at = statement_timestamp(), pause_reason = 'MEMBER_LOCKED'
               WHERE id = $1`,
              [rel.id],
            );
          } else {
            const hasGym = await hasActiveGymMembershipToday(client, incident.member_id, todayVn);
            if (hasGym) {
              newRelationshipStatus = 'ACTIVE';
              newPauseReason = null;
              await client.query(
                `UPDATE coach_relationships
                 SET status = 'ACTIVE', paused_at = NULL, pause_reason = NULL
                 WHERE id = $1`,
                [rel.id],
              );
            } else {
              newRelationshipStatus = 'PAUSED';
              newPauseReason = 'MEMBERSHIP_EXPIRED';
              await client.query(
                `UPDATE coach_relationships
                 SET status = 'PAUSED', paused_at = statement_timestamp(), pause_reason = 'MEMBERSHIP_EXPIRED'
                 WHERE id = $1`,
                [rel.id],
              );
            }
          }

          await client.query(
            `INSERT INTO coach_notifications (user_id, kind, subject_id)
             VALUES ($1, 'COACH_UNLOCKED_RESTORED', $3),
                    ($2, 'COACH_UNLOCKED_RESTORED', $3)`,
            [incident.member_id, before.id, rel.id],
          );

          restored.push({
            incidentId: incident.id,
            relationshipId: rel.id,
            memberId: incident.member_id,
            memberName: memberRow?.full_name ?? null,
            newRelationshipStatus,
            newPauseReason,
            frozenDaysAdded,
            newEndsOn,
          });
        }

        const after = await fetchAccount(client, before.id);
        const effects = {
          restoredRelationshipsCount: restored.length,
          restored,
        };
        await audit(client, request.authUser.id, 'USER_ENABLED', before.id, `Mở khóa tài khoản Coach: ${before.full_name}`, {
          before: publicAccount(before),
          after: publicAccount(after),
          restoredCount: restored.length,
          restoredRelationships: restored.map((item) => ({
            incidentId: item.incidentId,
            relationshipId: item.relationshipId,
            memberId: item.memberId,
            newRelationshipStatus: item.newRelationshipStatus,
            newPauseReason: item.newPauseReason,
            frozenDaysAdded: item.frozenDaysAdded,
          })),
        });
        await client.query('COMMIT');
        return response.json({ data: { user: publicAccount(after), effects } });
      }

      // ============================================================
      // BRANCH 3: LOCK MEMBER (ACTIVE -> DISABLED) — D4
      // ============================================================
      if (targetRole === 'MEMBER' && parsed.data.status === 'DISABLED') {
        const currentRel = (await client.query(
          `SELECT * FROM coach_relationships
           WHERE member_id = $1 AND status IN ('ACTIVE', 'PAUSED')
           ORDER BY id ASC FOR UPDATE`,
          [before.id],
        )).rows[0] ?? null;

        await client.query(
          `SELECT id FROM coach_entitlements
           WHERE member_id = $1 AND status IN ('ACTIVE', 'QUEUED')
           ORDER BY id ASC FOR UPDATE`,
          [before.id],
        );
        await client.query(
          `SELECT id FROM coach_payment_holds
           WHERE member_id = $1 AND status = 'HELD' ORDER BY id ASC FOR UPDATE`,
          [before.id],
        );
        await client.query(
          `SELECT id FROM coach_bookings
           WHERE member_id = $1 AND status = 'BOOKED' AND starts_at > statement_timestamp()
           ORDER BY id ASC FOR UPDATE`,
          [before.id],
        );

        await client.query(
          `UPDATE users
           SET status = 'DISABLED', disabled_at = statement_timestamp(),
               disabled_reason = $1, session_version = session_version + 1
           WHERE id = $2`,
          [parsed.data.reason, before.id],
        );

        const cancelledHolds = await client.query(
          `UPDATE coach_payment_holds SET status = 'CANCELLED'
           WHERE member_id = $1 AND status = 'HELD' RETURNING id`,
          [before.id],
        );

        const cancelledBookings = await client.query(
          `UPDATE coach_bookings
           SET status = 'CANCELLED',
               resolved_at = statement_timestamp(),
               resolved_by = $2,
               reason = 'Tài khoản Member bị khóa'
           WHERE member_id = $1
             AND status = 'BOOKED'
             AND starts_at > statement_timestamp()
           RETURNING id`,
          [before.id, request.authUser.id],
        );

        let resultRelStatus = currentRel?.status ?? null;
        let resultPauseReason = currentRel?.pause_reason ?? null;
        if (currentRel && (currentRel.status === 'ACTIVE' || currentRel.pause_reason === 'MEMBERSHIP_EXPIRED')) {
          // Do NOT overwrite COACH_LOCKED; do NOT freeze Gym or Coach entitlements!
          await client.query(
            `UPDATE coach_relationships
             SET status = 'PAUSED',
                 paused_at = statement_timestamp(),
                 pause_reason = 'MEMBER_LOCKED'
             WHERE id = $1`,
            [currentRel.id],
          );
          await client.query(
            `UPDATE training_sessions
             SET status = 'CANCELLED', cancelled_at = statement_timestamp(),
                 cancellation_reason = 'Tài khoản Member bị khóa'
             WHERE relationship_id = $1 AND status = 'SCHEDULED'
               AND scheduled_start_at > statement_timestamp()`,
            [currentRel.id],
          );
          await client.query(
            `INSERT INTO coach_notifications (user_id, kind, subject_id)
             VALUES ($1, 'MEMBER_LOCKED', $2)`,
            [currentRel.coach_id, currentRel.id],
          );
          resultRelStatus = 'PAUSED';
          resultPauseReason = 'MEMBER_LOCKED';
        }

        const after = await fetchAccount(client, before.id);
        const effects = {
          sessionsRevoked: true,
          cancelledHoldsCount: cancelledHolds.rowCount,
          cancelledFutureBookingsCount: cancelledBookings.rowCount,
          relationshipStatus: resultRelStatus,
          pauseReason: resultPauseReason,
          coachSeatKept: Boolean(currentRel),
          entitlementFrozen: false,
          gymMembershipFrozen: false,
        };
        await audit(client, request.authUser.id, 'USER_DISABLED', before.id, `Khóa tài khoản Member: ${before.full_name}`, {
          before: publicAccount(before),
          after: publicAccount(after),
          reason: parsed.data.reason,
          cancelledHoldsCount: effects.cancelledHoldsCount,
          cancelledFutureBookingsCount: effects.cancelledFutureBookingsCount,
          relationshipStatus: resultRelStatus,
          pauseReason: resultPauseReason,
        });
        await client.query('COMMIT');
        return response.json({ data: { user: publicAccount(after), effects } });
      }

      // ============================================================
      // BRANCH 4: UNLOCK MEMBER (DISABLED -> ACTIVE) — D4
      // ============================================================
      const existingRel = (await client.query(
        `SELECT * FROM coach_relationships
         WHERE member_id = $1 AND status IN ('ACTIVE', 'PAUSED')
         ORDER BY id ASC FOR UPDATE`,
        [before.id],
      )).rows[0] ?? null;

      await client.query(
        `SELECT id FROM coach_entitlements
         WHERE member_id = $1 AND status IN ('ACTIVE', 'QUEUED')
         ORDER BY id ASC FOR UPDATE`,
        [before.id],
      );

      await client.query(
        `UPDATE users
         SET status = 'ACTIVE', disabled_at = NULL, disabled_reason = NULL,
             session_version = session_version + 1
         WHERE id = $1`,
        [before.id],
      );

      // Reconcile Member's Gym & Coach entitlements immediately in this transaction
      await reconcileSingleMemberLifecycle(client, before.id, todayVn);

      // Re-fetch relationship after lifecycle reconciliation (may already have ENDED if Coach package expired)
      const relAfterReconcile = existingRel
        ? (await client.query('SELECT * FROM coach_relationships WHERE id = $1', [existingRel.id])).rows[0]
        : null;

      let finalRelStatus = relAfterReconcile?.status ?? null;
      let finalPauseReason = relAfterReconcile?.pause_reason ?? null;

      if (relAfterReconcile && relAfterReconcile.status === 'PAUSED' && relAfterReconcile.pause_reason === 'MEMBER_LOCKED') {
        const { rows: [entInfo] } = await client.query(
          `SELECT EXISTS (SELECT 1 FROM coach_entitlements WHERE relationship_id = $1) AS has_any_entitlement,
                  (SELECT id FROM coach_entitlements WHERE relationship_id = $1 AND status = 'ACTIVE' LIMIT 1) AS active_entitlement_id,
                  (SELECT id FROM coach_entitlements WHERE relationship_id = $1 AND status = 'QUEUED' LIMIT 1) AS queued_entitlement_id`,
          [relAfterReconcile.id],
        );
        const coachDisabled = lockedCoach?.status === 'DISABLED';
        const hasGym = await hasActiveGymMembershipToday(client, before.id, todayVn);

        if (entInfo.has_any_entitlement && !entInfo.active_entitlement_id) {
          await client.query(
            `UPDATE coach_relationships
             SET status = 'ENDED', ended_at = statement_timestamp(),
                 ended_by = $2, end_reason = 'Gói Coach đã hết hạn'
             WHERE id = $1`,
            [relAfterReconcile.id, request.authUser.id],
          );
          finalRelStatus = 'ENDED';
          finalPauseReason = null;
        } else if (coachDisabled) {
          await client.query(
            `UPDATE coach_relationships
             SET status = 'PAUSED', paused_at = statement_timestamp(), pause_reason = 'COACH_LOCKED'
             WHERE id = $1`,
            [relAfterReconcile.id],
          );
          let frozenStartedAt = null;
          if (entInfo.active_entitlement_id && hasGym) {
            const { rows: [frozenRow] } = await client.query(
              `UPDATE coach_entitlements SET frozen_at = statement_timestamp()
               WHERE id = $1 AND frozen_at IS NULL RETURNING frozen_at`,
              [entInfo.active_entitlement_id],
            );
            frozenStartedAt = frozenRow?.frozen_at ?? null;
          }
          const incidentId = randomUUID();
          await client.query(
            `INSERT INTO coach_lock_incidents (
               id, coach_id, member_id, relationship_id,
               active_entitlement_id, queued_entitlement_id,
               lock_reason, locked_by, locked_at, frozen_started_at, status
             ) VALUES (
               $1, $2, $3, $4, $5, $6, 'Coach đang bị khóa khi Member được mở khóa',
               $7, statement_timestamp(), $8, 'OPEN'
             )`,
            [
              incidentId,
              relAfterReconcile.coach_id,
              before.id,
              relAfterReconcile.id,
              entInfo.active_entitlement_id ?? null,
              entInfo.queued_entitlement_id ?? null,
              request.authUser.id,
              frozenStartedAt,
            ],
          );
          await client.query(
            `INSERT INTO coach_notifications (user_id, kind, subject_id)
             VALUES ($1, 'COACH_LOCKED', $2)`,
            [before.id, incidentId],
          );
          finalRelStatus = 'PAUSED';
          finalPauseReason = 'COACH_LOCKED';
        } else if (hasGym) {
          await client.query(
            `UPDATE coach_relationships
             SET status = 'ACTIVE', paused_at = NULL, pause_reason = NULL
             WHERE id = $1`,
            [relAfterReconcile.id],
          );
          await client.query(
            `INSERT INTO coach_notifications (user_id, kind, subject_id)
             VALUES ($1, 'MEMBER_UNLOCKED_RESTORED', $3),
                    ($2, 'MEMBER_UNLOCKED_RESTORED', $3)`,
            [before.id, relAfterReconcile.coach_id, relAfterReconcile.id],
          );
          finalRelStatus = 'ACTIVE';
          finalPauseReason = null;
        } else {
          await client.query(
            `UPDATE coach_relationships
             SET status = 'PAUSED', paused_at = statement_timestamp(), pause_reason = 'MEMBERSHIP_EXPIRED'
             WHERE id = $1`,
            [relAfterReconcile.id],
          );
          await client.query(
            `INSERT INTO coach_notifications (user_id, kind, subject_id)
             VALUES ($1, 'MEMBER_UNLOCKED_RESTORED', $3),
                    ($2, 'MEMBER_UNLOCKED_RESTORED', $3)`,
            [before.id, relAfterReconcile.coach_id, relAfterReconcile.id],
          );
          finalRelStatus = 'PAUSED';
          finalPauseReason = 'MEMBERSHIP_EXPIRED';
        }
      }

      const after = await fetchAccount(client, before.id);
      const effects = {
        relationshipStatus: finalRelStatus,
        pauseReason: finalPauseReason,
      };
      await audit(client, request.authUser.id, 'USER_ENABLED', before.id, `Mở khóa tài khoản Member: ${before.full_name}`, {
        before: publicAccount(before),
        after: publicAccount(after),
        relationshipStatus: finalRelStatus,
        pauseReason: finalPauseReason,
      });
      await client.query('COMMIT');
      return response.json({ data: { user: publicAccount(after), effects } });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không cập nhật được trạng thái');
    } finally { client.release(); }
  });

  return router;
}
