import { createHash, randomInt, randomUUID } from 'node:crypto';

import bcrypt from 'bcryptjs';
import { Router } from 'express';
import { z } from 'zod';

const uuid = z.uuid();
const code = z.string().regex(/^\d{6}$/);
const password = z.string().min(8).refine((value) =>
  Buffer.byteLength(value, 'utf8') <= 72 && /[a-z]/.test(value) &&
  /[A-Z]/.test(value) && /[0-9]/.test(value));

function fail(response, status, codeName, message) {
  return response.status(status).json({ error: {
    code: codeName, message, details: {},
  } });
}

function bucket(scope, value) {
  return { scope, key: createHash('sha256').update(`PASSWORD_RESET:${scope}:${value}`)
    .digest('hex') };
}

async function recordRequest(client, email, ip) {
  const buckets = [bucket('ACCOUNT', email), bucket('IP', ip)]
    .sort((a, b) => a.key.localeCompare(b.key));
  let limited = false;
  for (const item of buckets) {
    const result = await client.query(
      `INSERT INTO auth_password_reset_rate_limits
       (key_hash, scope, request_count, window_started_at)
       VALUES ($1, $2, 1, now())
       ON CONFLICT (key_hash) DO UPDATE SET
         request_count = CASE WHEN auth_password_reset_rate_limits.window_started_at
           <= now() - interval '15 minutes' THEN 1
           ELSE auth_password_reset_rate_limits.request_count + 1 END,
         window_started_at = CASE WHEN auth_password_reset_rate_limits.window_started_at
           <= now() - interval '15 minutes' THEN now()
           ELSE auth_password_reset_rate_limits.window_started_at END,
         updated_at = now()
       RETURNING request_count`, [item.key, item.scope],
    );
    if (result.rows[0].request_count > 3) limited = true;
  }
  return limited;
}

async function checkCode(client, requestId, enteredCode) {
  const found = await client.query(
    `SELECT * FROM password_reset_codes WHERE id = $1 FOR UPDATE`, [requestId],
  );
  const row = found.rows[0];
  if (!row || row.used_at || row.invalidated_at ||
    new Date(row.expires_at) <= new Date() || row.attempt_count >= 5) return null;
  if (!await bcrypt.compare(enteredCode, row.code_hash)) {
    await client.query(
      `UPDATE password_reset_codes SET attempt_count = attempt_count + 1,
       invalidated_at = CASE WHEN attempt_count + 1 >= 5 THEN now()
         ELSE invalidated_at END WHERE id = $1`, [requestId],
    );
    return null;
  }
  return row;
}

export function createPasswordResetsRouter({ database, sendPasswordResetCode }) {
  const router = Router();

  router.post('/password-reset-requests', async (request, response) => {
    const parsed = z.strictObject({
      email: z.string().trim().toLowerCase().email(),
    }).safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Email không hợp lệ');
    if (typeof sendPasswordResetCode !== 'function') {
      return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Dịch vụ email chưa được cấu hình');
    }
    const { email } = parsed.data;
    const requestId = randomUUID();
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    let delivery;
    try {
      await client.query('BEGIN');
      const limited = await recordRequest(client, email, request.ip ?? 'unknown');
      if (limited) {
        await client.query('COMMIT');
        return fail(response, 429, 'TOO_MANY_REQUESTS', 'Quá nhiều yêu cầu, vui lòng thử lại sau');
      }
      const user = await client.query(
        `SELECT id, email::text FROM users WHERE email = $1 AND status = 'ACTIVE'`,
        [email],
      );
      const resetCode = randomInt(0, 1000000).toString().padStart(6, '0');
      const hash = await bcrypt.hash(resetCode, 12);
      if (user.rows.length) {
        await client.query(
          `UPDATE password_reset_codes SET invalidated_at = now()
           WHERE user_id = $1 AND used_at IS NULL AND invalidated_at IS NULL`,
          [user.rows[0].id],
        );
        await client.query(
          `INSERT INTO password_reset_codes
           (id, user_id, code_hash, expires_at)
           VALUES ($1, $2, $3, now() + interval '15 minutes')`,
          [requestId, user.rows[0].id, hash],
        );
        delivery = { email: user.rows[0].email, code: resetCode, requestId };
      }
      await client.query('COMMIT');
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tạo được mã đặt lại');
    } finally { client.release(); }
    if (delivery) {
      try {
        await sendPasswordResetCode(delivery);
      } catch {
        await database.query(
          `UPDATE password_reset_codes SET invalidated_at = now()
           WHERE id = $1 AND used_at IS NULL AND invalidated_at IS NULL`,
          [requestId],
        ).catch(() => {});
      }
    }
    return response.status(202).json({ data: { accepted: true, requestId } });
  });

  router.post('/password-reset-verifications', async (request, response) => {
    const parsed = z.strictObject({ requestId: uuid, code }).safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu không hợp lệ');
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const valid = await checkCode(client, parsed.data.requestId, parsed.data.code);
      await client.query('COMMIT');
      return valid ? response.json({ data: { valid: true } })
        : fail(response, 401, 'INVALID_RESET_CODE', 'Mã không hợp lệ hoặc đã hết hạn');
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kiểm tra được mã');
    } finally { client.release(); }
  });

  router.post('/password-resets', async (request, response) => {
    const parsed = z.strictObject({
      requestId: uuid, code, newPassword: password,
    }).safeParse(request.body);
    if (!parsed.success) return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu không hợp lệ');
    const hash = await bcrypt.hash(parsed.data.newPassword, 12);
    const client = await database.connect().catch(() => null);
    if (!client) return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    try {
      await client.query('BEGIN');
      const valid = await checkCode(client, parsed.data.requestId, parsed.data.code);
      if (!valid) {
        await client.query('COMMIT');
        return fail(response, 401, 'INVALID_RESET_CODE', 'Mã không hợp lệ hoặc đã hết hạn');
      }
      const user = await client.query(
        `SELECT id FROM users WHERE id = $1 AND status = 'ACTIVE' FOR UPDATE`,
        [valid.user_id],
      );
      if (!user.rows.length) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'INVALID_RESET_CODE', 'Mã không hợp lệ hoặc đã hết hạn');
      }
      await client.query(
        `UPDATE users SET password_hash = $1,
         session_version = session_version + 1 WHERE id = $2`,
        [hash, valid.user_id],
      );
      await client.query(
        `UPDATE password_reset_codes SET used_at = now() WHERE id = $1`,
        [valid.id],
      );
      await client.query('COMMIT');
      return response.json({ data: { changed: true } });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không đặt lại được mật khẩu');
    } finally { client.release(); }
  });
  return router;
}
