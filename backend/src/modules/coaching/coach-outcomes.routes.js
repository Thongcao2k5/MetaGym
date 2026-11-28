import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { createAuthentication } from '../users/users.routes.js';

const uuid = z.uuid();

function fail(response, status, code, message) {
  return response.status(status).json({ error: { code, details: {}, message } });
}

function studentInitials(name) {
  const parts = String(name ?? '')
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  if (parts.length === 0) return 'HV';
  if (parts.length === 1) return parts[0][0].toUpperCase();
  return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase();
}

function photoUrl(outcomeId, side, mediaId) {
  return mediaId ? `/api/v1/coach-outcomes/${outcomeId}/photos/${side}` : null;
}

async function deleteOutcomeMedia(database, imageStorage, mediaIds) {
  const validIds = mediaIds.filter(Boolean);
  if (!validIds.length) return;
  const deletedMedia = await database.query(
    `UPDATE media_assets SET status = 'DELETED', deleted_at = now()
     WHERE id = ANY($1::uuid[]) AND status = 'READY'
     RETURNING storage_key`,
    [validIds],
  );
  if (imageStorage && typeof imageStorage.remove === 'function') {
    await Promise.all(
      deletedMedia.rows.map((row) =>
        imageStorage.remove(row.storage_key).catch(() => {}),
      ),
    );
  }
}

function publicOutcomeView(row) {
  const showName = row.allow_real_name === true;
  return {
    id: row.id,
    coachId: row.coach_id,
    goal: row.goal,
    durationWeeks: row.duration_weeks,
    beforeWeightKg: Number(row.before_weight_kg),
    afterWeightKg: Number(row.after_weight_kg),
    beforeBodyFatPercent:
      row.before_body_fat_percent != null
        ? Number(row.before_body_fat_percent)
        : null,
    afterBodyFatPercent:
      row.after_body_fat_percent != null
        ? Number(row.after_body_fat_percent)
        : null,
    beforePhotoUrl: photoUrl(row.id, 'before', row.before_media_id),
    afterPhotoUrl: photoUrl(row.id, 'after', row.after_media_id),
    allowRealName: showName,
    studentName: showName ? row.member_full_name : 'Học viên ẩn danh',
    studentInitials: showName ? studentInitials(row.member_full_name) : 'HV',
    submittedAt: row.submitted_at,
  };
}

function participantOutcomeView(row) {
  return {
    id: row.id,
    coachId: row.coach_id,
    coachName: row.coach_name ?? null,
    memberId: row.member_id,
    memberName: row.member_full_name ?? null,
    relationshipId: row.relationship_id,
    goal: row.goal,
    durationWeeks: row.duration_weeks,
    beforeWeightKg: Number(row.before_weight_kg),
    afterWeightKg: Number(row.after_weight_kg),
    beforeBodyFatPercent:
      row.before_body_fat_percent != null
        ? Number(row.before_body_fat_percent)
        : null,
    afterBodyFatPercent:
      row.after_body_fat_percent != null
        ? Number(row.after_body_fat_percent)
        : null,
    beforePhotoUrl: photoUrl(row.id, 'before', row.before_media_id),
    afterPhotoUrl: photoUrl(row.id, 'after', row.after_media_id),
    status: row.status,
    allowRealName: row.allow_real_name === true,
    submittedAt: row.submitted_at,
    respondedAt: row.responded_at,
  };
}

const createOutcomeSchema = z.strictObject({
  goal: z.string().trim().min(1).max(200),
  durationWeeks: z.number().int().min(1).max(520),
  beforeWeightKg: z.number().positive().max(999.99),
  afterWeightKg: z.number().positive().max(999.99),
  beforeBodyFatPercent: z.number().positive().max(100).nullable().optional(),
  afterBodyFatPercent: z.number().positive().max(100).nullable().optional(),
  beforeMediaId: uuid.nullable().optional(),
  afterMediaId: uuid.nullable().optional(),
});

const consentSchema = z.strictObject({
  decision: z.enum(['APPROVED', 'DECLINED', 'WITHDRAWN']).optional(),
  allowRealName: z.boolean().optional(),
  removePhotos: z.boolean().optional(),
});

export function createCoachOutcomesRouter({ database, jwtSecret, imageStorage }) {
  const router = Router();
  router.use(createAuthentication({ database, jwtSecret }));

  router.get('/coaches/:coachId/outcomes', async (request, response) => {
    if (!uuid.safeParse(request.params.coachId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã Coach không hợp lệ');
    }
    try {
      const { rows } = await database.query(
        `SELECT o.*, u.full_name AS member_full_name
         FROM coach_outcome_cases o
         JOIN users u ON u.id = o.member_id
         WHERE o.coach_id = $1 AND o.status = 'APPROVED'
         ORDER BY o.responded_at DESC NULLS LAST, o.submitted_at DESC`,
        [request.params.coachId],
      );
      return response.json({ data: rows.map(publicOutcomeView) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được thành quả học viên');
    }
  });

  router.get('/coach-outcomes/:outcomeId/photos/:side', async (request, response) => {
    const { outcomeId, side } = request.params;
    if (!uuid.safeParse(outcomeId).success || !['before', 'after'].includes(side)) {
      return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh thành quả');
    }
    if (!imageStorage || typeof imageStorage.get !== 'function') {
      return fail(response, 503, 'SERVICE_UNAVAILABLE', 'Lưu ảnh chưa được cấu hình');
    }
    try {
      const column = side === 'before' ? 'before_media_id' : 'after_media_id';
      const { rows } = await database.query(
        `SELECT o.status AS outcome_status, o.coach_id, o.member_id,
                m.storage_key, m.mime_type
         FROM coach_outcome_cases o
         JOIN media_assets m ON m.id = o.${column} AND m.status = 'READY'
         WHERE o.id = $1`,
        [outcomeId],
      );
      const found = rows[0];
      const userId = request.authUser.id;
      const canRead =
        found &&
        (found.outcome_status === 'APPROVED' ||
          found.coach_id === userId ||
          found.member_id === userId);
      if (!canRead) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy ảnh thành quả');
      }
      const bytes = await imageStorage.get(found.storage_key);
      if (!Buffer.isBuffer(bytes)) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy tệp ảnh');
      }
      response.set('Cache-Control', 'private, max-age=60');
      response.type(found.mime_type || 'image/jpeg');
      return response.send(bytes);
    } catch {
      return fail(response, 502, 'STORAGE_ERROR', 'Không tải được ảnh thành quả');
    }
  });

  router.get('/coach/members/:memberId/outcomes', async (request, response) => {
    if (request.authUser.role !== 'COACH') {
      return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được xem thành quả đã gửi');
    }
    if (!uuid.safeParse(request.params.memberId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã Member không hợp lệ');
    }
    try {
      const { rows } = await database.query(
        `SELECT o.*, m.full_name AS member_full_name
         FROM coach_outcome_cases o
         JOIN users m ON m.id = o.member_id
         WHERE o.coach_id = $1 AND o.member_id = $2
         ORDER BY o.submitted_at DESC`,
        [request.authUser.id, request.params.memberId],
      );
      return response.json({ data: rows.map(participantOutcomeView) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được thành quả');
    }
  });

  router.post('/coach/members/:memberId/outcomes', async (request, response) => {
    if (request.authUser.role !== 'COACH') {
      return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được gửi thành quả học viên');
    }
    if (!uuid.safeParse(request.params.memberId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã Member không hợp lệ');
    }
    const parsed = createOutcomeSchema.safeParse(request.body);
    if (!parsed.success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Thông tin thành quả không hợp lệ');
    }
    const data = parsed.data;
    const coachId = request.authUser.id;
    const memberId = request.params.memberId;

    try {
      const relationship = (await database.query(
        `SELECT id FROM coach_relationships
         WHERE coach_id = $1 AND member_id = $2 AND status = 'ACTIVE'
         LIMIT 1`,
        [coachId, memberId],
      )).rows[0];
      if (!relationship) {
        return fail(
          response,
          409,
          'ACTIVE_RELATIONSHIP_REQUIRED',
          'Chỉ gửi được thành quả cho Member đang phụ trách',
        );
      }

      const mediaIds = [data.beforeMediaId, data.afterMediaId].filter(Boolean);
      if (mediaIds.length) {
        const mediaCheck = await database.query(
          `SELECT id FROM media_assets
           WHERE id = ANY($1::uuid[]) AND owner_id = $2
             AND purpose = 'COACH_OUTCOME' AND status = 'READY'`,
          [mediaIds, coachId],
        );
        if (mediaCheck.rows.length !== new Set(mediaIds).size) {
          return fail(response, 422, 'VALIDATION_ERROR', 'Ảnh minh chứng không hợp lệ');
        }
      }

      const outcomeId = randomUUID();
      await database.query(
        `INSERT INTO coach_outcome_cases (
           id, coach_id, member_id, relationship_id, goal, duration_weeks,
           before_weight_kg, after_weight_kg, before_body_fat_percent,
           after_body_fat_percent, before_media_id, after_media_id
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
        [
          outcomeId,
          coachId,
          memberId,
          relationship.id,
          data.goal,
          data.durationWeeks,
          data.beforeWeightKg,
          data.afterWeightKg,
          data.beforeBodyFatPercent ?? null,
          data.afterBodyFatPercent ?? null,
          data.beforeMediaId ?? null,
          data.afterMediaId ?? null,
        ],
      );

      const saved = (await database.query(
        `SELECT o.*, m.full_name AS member_full_name
         FROM coach_outcome_cases o
         JOIN users m ON m.id = o.member_id
         WHERE o.id = $1`,
        [outcomeId],
      )).rows[0];

      return response.status(201).json({ data: participantOutcomeView(saved) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không lưu được thành quả học viên');
    }
  });

  router.delete('/coach/outcomes/:outcomeId', async (request, response) => {
    if (request.authUser.role !== 'COACH') {
      return fail(response, 403, 'FORBIDDEN', 'Chỉ Coach được xóa thành quả đã tạo');
    }
    if (!uuid.safeParse(request.params.outcomeId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã thành quả không hợp lệ');
    }
    try {
      const removed = (await database.query(
        `DELETE FROM coach_outcome_cases
         WHERE id = $1 AND coach_id = $2
         RETURNING id, before_media_id, after_media_id`,
        [request.params.outcomeId, request.authUser.id],
      )).rows[0];
      if (!removed) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy thành quả');
      }
      await deleteOutcomeMedia(database, imageStorage, [
        removed.before_media_id,
        removed.after_media_id,
      ]);
      return response.json({ data: { deleted: true, id: removed.id } });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không xóa được thành quả');
    }
  });

  router.get('/member/coach-outcomes', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') {
      return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được xem yêu cầu duyệt thành quả');
    }
    try {
      const { rows } = await database.query(
        `SELECT o.*, c.full_name AS coach_name, m.full_name AS member_full_name
         FROM coach_outcome_cases o
         JOIN users c ON c.id = o.coach_id
         JOIN users m ON m.id = o.member_id
         WHERE o.member_id = $1
         ORDER BY CASE WHEN o.status = 'PENDING_MEMBER' THEN 0 ELSE 1 END,
                  o.submitted_at DESC`,
        [request.authUser.id],
      );
      return response.json({ data: rows.map(participantOutcomeView) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không tải được danh sách thành quả');
    }
  });

  router.patch('/member/coach-outcomes/:outcomeId', async (request, response) => {
    if (request.authUser.role !== 'MEMBER') {
      return fail(response, 403, 'FORBIDDEN', 'Chỉ Member được duyệt thành quả của mình');
    }
    if (!uuid.safeParse(request.params.outcomeId).success) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Mã thành quả không hợp lệ');
    }
    const parsed = consentSchema.safeParse(request.body);
    if (!parsed.success || (parsed.data.decision == null && parsed.data.allowRealName == null)) {
      return fail(response, 422, 'VALIDATION_ERROR', 'Lựa chọn duyệt thành quả không hợp lệ');
    }
    const { decision, allowRealName, removePhotos } = parsed.data;
    try {
      const existing = (await database.query(
        `SELECT * FROM coach_outcome_cases WHERE id = $1 AND member_id = $2`,
        [request.params.outcomeId, request.authUser.id],
      )).rows[0];
      if (!existing) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy thành quả');
      }
      const nextStatus = decision ?? existing.status;
      const nextAllowRealName =
        nextStatus === 'APPROVED'
          ? (allowRealName ?? existing.allow_real_name)
          : false;
      const shouldDropPhotos =
        removePhotos === true && ['DECLINED', 'WITHDRAWN'].includes(nextStatus);

      const updated = (await database.query(
        `UPDATE coach_outcome_cases
         SET status = $1,
             allow_real_name = $2,
             before_media_id = CASE WHEN $3::boolean THEN NULL ELSE before_media_id END,
             after_media_id = CASE WHEN $3::boolean THEN NULL ELSE after_media_id END,
             responded_at = now(),
             updated_at = now()
         WHERE id = $4 AND member_id = $5
         RETURNING *`,
        [nextStatus, nextAllowRealName, shouldDropPhotos, existing.id, request.authUser.id],
      )).rows[0];

      if (shouldDropPhotos) {
        await deleteOutcomeMedia(database, imageStorage, [
          existing.before_media_id,
          existing.after_media_id,
        ]);
      }

      const full = (await database.query(
        `SELECT o.*, c.full_name AS coach_name, m.full_name AS member_full_name
         FROM coach_outcome_cases o
         JOIN users c ON c.id = o.coach_id
         JOIN users m ON m.id = o.member_id
         WHERE o.id = $1`,
        [updated.id],
      )).rows[0];
      return response.json({ data: participantOutcomeView(full) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không cập nhật được trạng thái thành quả');
    }
  });

  return router;
}
