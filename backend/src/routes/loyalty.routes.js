import { Router } from 'express';
import { z } from 'zod';

import {
  buildLoyaltySummary,
  expireOverdueRedemptions,
  formatLoyaltyRedemption,
  formatLoyaltyReward,
  formatLoyaltyTransaction,
  redeemLoyaltyReward,
} from '../services/loyalty.js';
import { createAuthentication } from './users.routes.js';

const uuid = z.uuid();
const redeemSchema = z.strictObject({
  rewardId: uuid,
});

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, details: {}, message } });
}

export function createLoyaltyRouter({ database, jwtSecret }) {
  const router = Router();
  router.use(createAuthentication({ database, jwtSecret }));

  router.get('/loyalty/me', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') {
      return fail(response, 403, 'FORBIDDEN', 'Chỉ Hội viên được xem thông tin Meta Points');
    }
    try {
      const summary = await buildLoyaltySummary(database, request.authUser.id);
      response.set('Cache-Control', 'no-store');
      return response.json({ data: summary });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được thông tin Meta Points');
    }
  });

  router.get('/loyalty/rewards', async (request, response) => {
    const parsed = z.strictObject({
      category: z.enum(['ALL', 'VOUCHER', 'SERVICE']).default('ALL'),
    }).safeParse(request.query);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Bộ lọc ưu đãi không hợp lệ');
    }
    try {
      const { category } = parsed.data;
      const filters = ["status = 'ACTIVE'"];
      const values = [];
      if (category !== 'ALL') {
        values.push(category);
        filters.push(`category = $${values.length}`);
      }
      const { rows } = await database.query(
        `SELECT * FROM loyalty_rewards
         WHERE ${filters.join(' AND ')}
         ORDER BY sort_order ASC, created_at ASC`,
        values,
      );
      response.set('Cache-Control', 'no-store');
      return response.json({ data: rows.map(formatLoyaltyReward) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được danh mục ưu đãi');
    }
  });

  router.get('/loyalty/redemptions/me', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') {
      return fail(response, 403, 'FORBIDDEN', 'Chỉ Hội viên được xem ưu đãi đã đổi');
    }
    const parsed = z.strictObject({
      status: z.enum(['ALL', 'UNUSED', 'USED', 'EXPIRED']).default('ALL'),
    }).safeParse(request.query);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Trạng thái lọc ưu đãi không hợp lệ');
    }
    try {
      await expireOverdueRedemptions(database, request.authUser.id);
      const values = [request.authUser.id];
      const statusClause = parsed.data.status === 'ALL'
        ? ''
        : `AND status = $2`;
      if (parsed.data.status !== 'ALL') {
        values.push(parsed.data.status);
      }
      const { rows } = await database.query(
        `SELECT * FROM loyalty_redemptions
         WHERE member_id = $1 ${statusClause}
         ORDER BY redeemed_at DESC, id DESC`,
        values,
      );
      response.set('Cache-Control', 'no-store');
      return response.json({ data: rows.map(formatLoyaltyRedemption) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được ưu đãi của tôi');
    }
  });

  router.post('/loyalty/redemptions', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') {
      return fail(response, 403, 'FORBIDDEN', 'Chỉ Hội viên được đổi ưu đãi');
    }
    const parsed = redeemSchema.safeParse(request.body);
    const idempotencyKey = request.get('idempotency-key')?.trim() || null;
    if (!parsed.success || (idempotencyKey !== null && (idempotencyKey.length === 0 || idempotencyKey.length > 100))) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Dữ liệu đổi ưu đãi không hợp lệ');
    }
    const client = await database.connect().catch(() => null);
    if (!client) {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    }
    try {
      await client.query('BEGIN');
      const actor = await client.query(
        `SELECT id FROM users
         WHERE id = $1 AND role = 'MEMBER' AND status = 'ACTIVE' AND session_version = $2
         FOR UPDATE`,
        [request.authUser.id, request.authUser.session_version],
      );
      if (actor.rows.length !== 1) {
        await client.query('ROLLBACK');
        return fail(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const result = await redeemLoyaltyReward(client, {
        memberId: request.authUser.id,
        rewardId: parsed.data.rewardId,
        idempotencyKey,
      });
      await client.query('COMMIT');
      response.set('Cache-Control', 'no-store');
      return response.status(result.replayed ? 200 : 201).json({
        data: {
          redemption: result.redemption,
          transaction: result.transaction,
          summary: result.summary,
        },
      });
    } catch (error) {
      await client.query('ROLLBACK').catch(() => {});
      if (error?.status && error?.code) {
        return fail(response, error.status, error.code, error.message);
      }
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể đổi ưu đãi lúc này');
    } finally {
      client.release();
    }
  });

  router.post('/loyalty/redemptions/:redemptionId/use', async (request, response) => {
    const id = uuid.safeParse(request.params.redemptionId);
    if (!id.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã ưu đãi không hợp lệ');
    }
    if (!['MEMBER', 'ADMIN'].includes(request.authUser.role)) {
      return fail(response, 403, 'FORBIDDEN', 'Không có quyền xác nhận ưu đãi');
    }
    const client = await database.connect().catch(() => null);
    if (!client) {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không kết nối được database');
    }
    try {
      await client.query('BEGIN');
      const { rows: [row] } = await client.query(
        `SELECT * FROM loyalty_redemptions WHERE id = $1 FOR UPDATE`,
        [id.data],
      );
      if (!row || (request.authUser.role === 'MEMBER' && row.member_id !== request.authUser.id)) {
        await client.query('ROLLBACK');
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ưu đãi đã đổi');
      }
      if (row.status === 'USED') {
        await client.query('COMMIT');
        return response.json({ data: formatLoyaltyRedemption(row) });
      }
      if (row.status === 'EXPIRED' || new Date(row.expires_at).getTime() < Date.now()) {
        await client.query(
          `UPDATE loyalty_redemptions SET status = 'EXPIRED' WHERE id = $1`,
          [row.id],
        );
        await client.query('COMMIT');
        return fail(response, 409, 'REDEMPTION_EXPIRED', 'Ưu đãi đã hết hạn sử dụng');
      }
      if (row.requires_staff_confirm && request.authUser.role !== 'ADMIN') {
        await client.query('ROLLBACK');
        return fail(
          response,
          403,
          'STAFF_CONFIRM_REQUIRED',
          'Ưu đãi dịch vụ cần nhân viên lễ tân hoặc Huấn luyện viên xác nhận tại quầy',
        );
      }
      const { rows: [updated] } = await client.query(
        `UPDATE loyalty_redemptions
         SET status = 'USED', used_at = now()
         WHERE id = $1
         RETURNING *`,
        [row.id],
      );
      await client.query('COMMIT');
      return response.json({ data: formatLoyaltyRedemption(updated) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể cập nhật trạng thái ưu đãi');
    } finally {
      client.release();
    }
  });

  router.get('/loyalty/transactions/me', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') {
      return fail(response, 403, 'FORBIDDEN', 'Chỉ Hội viên được xem lịch sử điểm');
    }
    const parsed = z.strictObject({
      type: z.enum(['ALL', 'EARN', 'SPEND', 'ADJUST']).default('ALL'),
    }).safeParse(request.query);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Bộ lọc lịch sử điểm không hợp lệ');
    }
    try {
      const values = [request.authUser.id];
      const typeClause = parsed.data.type === 'ALL' ? '' : `AND tx_type = $2`;
      if (parsed.data.type !== 'ALL') {
        values.push(parsed.data.type);
      }
      const { rows } = await database.query(
        `SELECT * FROM loyalty_point_transactions
         WHERE member_id = $1 ${typeClause}
         ORDER BY created_at DESC, id DESC`,
        values,
      );
      response.set('Cache-Control', 'no-store');
      return response.json({ data: rows.map(formatLoyaltyTransaction) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được lịch sử điểm Meta Points');
    }
  });

  return router;
}
