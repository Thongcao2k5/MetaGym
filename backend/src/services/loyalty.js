import { randomBytes, randomUUID } from 'node:crypto';

export const LOYALTY_TIERS = [
  {
    code: 'BRONZE',
    name: 'Đồng',
    tierLabel: 'Hạng Đồng',
    minPoints: 0,
    coachDiscountPercent: 0,
    pointsMultiplier: 1.0,
    inBodyLabel: 'Trả phí lẻ',
    tagline: 'Khởi đầu hành trình tập luyện tại Meta Gym',
    perks: [
      'Check-in QR/NFC không chạm tại phòng tập',
      'Tích điểm khả dụng & xét hạng khi đăng ký gói hoặc check-in',
      'Truy cập danh mục ưu đãi thành viên cơ bản',
    ],
  },
  {
    code: 'SILVER',
    name: 'Bạc',
    tierLabel: 'Hạng Bạc',
    minPoints: 800,
    coachDiscountPercent: 3,
    pointsMultiplier: 1.2,
    inBodyLabel: '1 lần / quý',
    tagline: 'Tăng nhịp ổn định cùng đặc quyền InBody & ưu đãi Coach',
    perks: [
      'Giảm tự động 3% mọi gói Coach 1:1',
      'Hệ số tích điểm check-in ×1.2',
      'Đo chỉ số InBody chuyên sâu 1 lần / quý',
    ],
  },
  {
    code: 'GOLD',
    name: 'Vàng',
    tierLabel: 'Hạng Vàng',
    minPoints: 2000,
    coachDiscountPercent: 5,
    pointsMultiplier: 1.5,
    inBodyLabel: 'Miễn phí / tháng',
    tagline: 'Hội viên gắn bó với ưu đãi Coach 1:1 và InBody định kỳ',
    perks: [
      'Giảm tự động 5% mọi gói Coach 1:1',
      'Đo chỉ số InBody chuyên sâu miễn phí hàng tháng',
      'Hệ số tích điểm check-in ×1.5 & mở khóa ưu đãi Vàng',
    ],
  },
  {
    code: 'DIAMOND',
    name: 'Kim Cương',
    tierLabel: 'Hạng Kim Cương',
    minPoints: 6000,
    coachDiscountPercent: 10,
    pointsMultiplier: 2.0,
    inBodyLabel: 'Không giới hạn',
    tagline: 'Hạng cao nhất dành cho hội viên đồng hành bền vững cùng Meta Gym',
    perks: [
      'Giảm tự động 10% mọi gói Coach 1:1',
      'Đo chỉ số InBody chuyên sâu không giới hạn',
      'Hệ số tích điểm check-in ×2.0 & ưu tiên chăm sóc câu lạc bộ',
    ],
  },
];

export function resolveTierFromPoints(rawTierPoints) {
  const tierPoints = Math.max(0, Number(rawTierPoints) || 0);
  let currentIdx = 0;
  for (let i = 0; i < LOYALTY_TIERS.length; i += 1) {
    if (tierPoints >= LOYALTY_TIERS[i].minPoints) {
      currentIdx = i;
    }
  }
  const current = LOYALTY_TIERS[currentIdx];
  const next = currentIdx < LOYALTY_TIERS.length - 1
    ? LOYALTY_TIERS[currentIdx + 1]
    : null;
  const remainingToNextTier = next ? Math.max(0, next.minPoints - tierPoints) : 0;
  let progressFraction = 1.0;
  if (next) {
    const span = Math.max(1, next.minPoints - current.minPoints);
    progressFraction = Math.min(1, Math.max(0, (tierPoints - current.minPoints) / span));
  }
  return {
    current,
    next,
    tierPoints,
    remainingToNextTier,
    progressFraction,
  };
}

export function bonusPointsForDurationDays(durationDays) {
  const days = Math.max(1, Number(durationDays) || 30);
  if (days >= 1000) return 5000;
  if (days >= 300) return 1500;
  if (days >= 150) return 650;
  if (days >= 60) return 250;
  return 100;
}

export function formatLoyaltyReward(row) {
  const stockRemaining = row.stock_remaining == null ? null : Number(row.stock_remaining);
  return {
    id: row.id,
    code: row.code,
    category: row.category,
    title: row.title,
    description: row.description,
    pointsCost: Number(row.points_cost),
    discountAmount: Number(row.discount_amount ?? 0),
    requiresStaffConfirm: Boolean(row.requires_staff_confirm),
    stockRemaining,
    isOutOfStock: stockRemaining !== null && stockRemaining <= 0,
    validDays: Number(row.valid_days ?? 30),
    terms: Array.isArray(row.terms) ? row.terms : [],
    status: row.status,
  };
}

export function formatLoyaltyRedemption(row) {
  return {
    id: row.id,
    rewardId: row.reward_id,
    rewardCode: row.reward_code_snapshot,
    category: row.category_snapshot,
    title: row.title_snapshot,
    pointsSpent: Number(row.points_spent),
    discountAmount: Number(row.discount_amount_snapshot ?? 0),
    voucherCode: row.voucher_code,
    requiresStaffConfirm: Boolean(row.requires_staff_confirm),
    conditionText: row.condition_text,
    status: row.status,
    redeemedAt: row.redeemed_at,
    expiresAt: row.expires_at,
    usedAt: row.used_at ?? null,
  };
}

export function formatLoyaltyTransaction(row) {
  return {
    id: row.id,
    txType: row.tx_type,
    pointsDelta: Number(row.points_delta),
    tierPointsDelta: Number(row.tier_points_delta ?? 0),
    title: row.title,
    detail: row.detail ?? '',
    referenceType: row.reference_type ?? null,
    referenceId: row.reference_id ?? null,
    statusLabel: row.status_label ?? 'Thành công',
    createdAt: row.created_at,
  };
}

export async function expireOverdueRedemptions(database, memberId) {
  await database.query(
    `UPDATE loyalty_redemptions
     SET status = 'EXPIRED'
     WHERE member_id = $1 AND status = 'UNUSED' AND expires_at < now()`,
    [memberId],
  );
}

export async function buildLoyaltySummary(database, memberId) {
  await expireOverdueRedemptions(database, memberId);
  const { rows: [account] } = await database.query(
    `SELECT available_points, tier_points, updated_at
     FROM loyalty_accounts WHERE member_id = $1`,
    [memberId],
  );
  const { rows: [counts] } = await database.query(
    `SELECT count(*)::int AS unused_count
     FROM loyalty_redemptions
     WHERE member_id = $1 AND status = 'UNUSED' AND expires_at >= now()`,
    [memberId],
  );
  const availablePoints = Number(account?.available_points ?? 0);
  const tierPoints = Number(account?.tier_points ?? 0);
  const tierInfo = resolveTierFromPoints(tierPoints);

  return {
    availablePoints,
    tierPoints,
    tier: tierInfo.current.code,
    tierName: tierInfo.current.name,
    tierLabel: tierInfo.current.tierLabel,
    nextTier: tierInfo.next?.code ?? null,
    nextTierName: tierInfo.next?.name ?? null,
    nextTierLabel: tierInfo.next?.tierLabel ?? null,
    nextTierMinPoints: tierInfo.next?.minPoints ?? null,
    remainingToNextTier: tierInfo.remainingToNextTier,
    progressFraction: tierInfo.progressFraction,
    coachDiscountPercent: tierInfo.current.coachDiscountPercent,
    pointsMultiplier: tierInfo.current.pointsMultiplier,
    inBodyLabel: tierInfo.current.inBodyLabel,
    perks: tierInfo.current.perks,
    unusedRedemptionsCount: Number(counts?.unused_count ?? 0),
    tiers: LOYALTY_TIERS,
  };
}

export async function ensureLoyaltyAccount(client, memberId, { lock = false } = {}) {
  await client.query(
    `INSERT INTO loyalty_accounts (member_id, available_points, tier_points)
     VALUES ($1, 0, 0)
     ON CONFLICT (member_id) DO NOTHING`,
    [memberId],
  );
  const { rows: [account] } = await client.query(
    `SELECT member_id, available_points, tier_points
     FROM loyalty_accounts WHERE member_id = $1 ${lock ? 'FOR UPDATE' : ''}`,
    [memberId],
  );
  return account ?? null;
}

export async function awardMembershipPaymentPoints(client, payment) {
  const bonus = bonusPointsForDurationDays(payment.duration_days_snapshot);
  const existing = await client.query(
    `SELECT id FROM loyalty_point_transactions
     WHERE member_id = $1 AND reference_type = 'MEMBERSHIP_PAYMENT'
       AND reference_id = $2 AND tx_type = 'EARN'
     LIMIT 1`,
    [payment.member_id, payment.id],
  );
  if (existing.rows.length) return null;

  const account = await ensureLoyaltyAccount(client, payment.member_id, { lock: true });
  if (!account) return null;

  await client.query(
    `UPDATE loyalty_accounts
     SET available_points = available_points + $2,
         tier_points = tier_points + $2
     WHERE member_id = $1`,
    [payment.member_id, bonus],
  );
  const detail = payment.renewed_membership_id
    ? `Gia hạn ${payment.plan_name_snapshot} · Cộng vào khả dụng & xét hạng`
    : `Đăng ký ${payment.plan_name_snapshot} · Cộng vào khả dụng & xét hạng`;
  await client.query(
    `INSERT INTO loyalty_point_transactions
     (id, member_id, tx_type, points_delta, tier_points_delta, title, detail,
      reference_type, reference_id, status_label)
     VALUES ($1, $2, 'EARN', $3, $3, $4, $5, 'MEMBERSHIP_PAYMENT', $6, 'Thành công')
     ON CONFLICT DO NOTHING`,
    [
      randomUUID(),
      payment.member_id,
      bonus,
      payment.renewed_membership_id
        ? 'Cộng điểm khi gia hạn gói tập'
        : 'Cộng điểm khi đăng ký gói tập',
      detail,
      payment.id,
    ],
  );
  return { pointsEarned: bonus };
}

export async function awardGymCheckinPoints(client, { memberId, visitId }) {
  const account = await ensureLoyaltyAccount(client, memberId, { lock: true });
  if (!account) return null;

  const todayEarn = await client.query(
    `SELECT 1 FROM loyalty_point_transactions
     WHERE member_id = $1
       AND reference_type = 'GYM_CHECKIN'
       AND tx_type = 'EARN'
       AND (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
         = (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
     LIMIT 1`,
    [memberId],
  );
  if (todayEarn.rows.length) return { pointsEarned: 0 };

  const tierInfo = resolveTierFromPoints(account.tier_points);
  const points = Math.max(10, Math.round(10 * tierInfo.current.pointsMultiplier));

  await client.query(
    `UPDATE loyalty_accounts
     SET available_points = available_points + $2,
         tier_points = tier_points + $2
     WHERE member_id = $1`,
    [memberId, points],
  );
  await client.query(
    `INSERT INTO loyalty_point_transactions
     (id, member_id, tx_type, points_delta, tier_points_delta, title, detail,
      reference_type, reference_id, status_label)
     VALUES ($1, $2, 'EARN', $3, $3, $4, $5, 'GYM_CHECKIN', $6, 'Thành công')
     ON CONFLICT DO NOTHING`,
    [
      randomUUID(),
      memberId,
      points,
      'Cộng điểm check-in phòng tập',
      `Hệ số ${tierInfo.current.tierLabel} (×${tierInfo.current.pointsMultiplier}) · Mỗi ngày 1 lần`,
      visitId,
    ],
  );
  return { pointsEarned: points };
}

export async function consumeVoucherOnPaymentConfirmation(client, payment) {
  if (!payment.loyalty_redemption_id) return;
  await client.query(
    `UPDATE loyalty_redemptions
     SET status = 'USED', used_at = COALESCE(used_at, now())
     WHERE id = $1 AND member_id = $2 AND status = 'UNUSED'`,
    [payment.loyalty_redemption_id, payment.member_id],
  );
}

export async function redeemLoyaltyReward(client, { memberId, rewardId, idempotencyKey }) {
  await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [memberId]);
  const account = await ensureLoyaltyAccount(client, memberId, { lock: true });
  if (!account) {
    const err = new Error('Không khởi tạo được ví Meta Points');
    err.status = 500;
    err.code = 'INTERNAL_SERVER_ERROR';
    throw err;
  }

  if (idempotencyKey) {
    const prior = await client.query(
      `SELECT * FROM loyalty_redemptions
       WHERE member_id = $1 AND idempotency_key = $2`,
      [memberId, idempotencyKey],
    );
    if (prior.rows.length) {
      const existing = prior.rows[0];
      if (existing.reward_id !== rewardId) {
        const err = new Error('Idempotency-Key đã được dùng cho ưu đãi khác');
        err.status = 422;
        err.code = 'IDEMPOTENCY_KEY_CONFLICT';
        throw err;
      }
      const { rows: [txRow] } = await client.query(
        `SELECT * FROM loyalty_point_transactions
         WHERE member_id = $1 AND reference_type = 'REWARD_REDEMPTION' AND reference_id = $2
         LIMIT 1`,
        [memberId, existing.id],
      );
      const summary = await buildLoyaltySummary(client, memberId);
      return {
        replayed: true,
        redemption: formatLoyaltyRedemption(existing),
        transaction: txRow ? formatLoyaltyTransaction(txRow) : null,
        summary,
      };
    }
  }

  const { rows: [reward] } = await client.query(
    `SELECT * FROM loyalty_rewards WHERE id = $1 FOR UPDATE`,
    [rewardId],
  );
  if (!reward || reward.status !== 'ACTIVE') {
    const err = new Error('Không tìm thấy ưu đãi đang mở đổi');
    err.status = 404;
    err.code = 'NOT_FOUND';
    throw err;
  }
  if (reward.stock_remaining !== null && Number(reward.stock_remaining) <= 0) {
    const err = new Error('Ưu đãi này đã hết lượt đổi trong đợt hiện tại');
    err.status = 409;
    err.code = 'REWARD_OUT_OF_STOCK';
    throw err;
  }

  const cost = Number(reward.points_cost);
  const available = Number(account.available_points);
  if (available < cost) {
    const missing = cost - available;
    const err = new Error(`Còn thiếu ${missing.toLocaleString('vi-VN')} điểm khả dụng để đổi ưu đãi này`);
    err.status = 409;
    err.code = 'INSUFFICIENT_POINTS';
    throw err;
  }

  // Only deduct available_points; tier_points stays untouched so tier never drops on redemption.
  await client.query(
    `UPDATE loyalty_accounts
     SET available_points = available_points - $2
     WHERE member_id = $1`,
    [memberId, cost],
  );

  if (reward.stock_remaining !== null) {
    await client.query(
      `UPDATE loyalty_rewards
       SET stock_remaining = stock_remaining - 1
       WHERE id = $1`,
      [reward.id],
    );
  }

  const redemptionId = randomUUID();
  const voucherCode = `MG-${randomBytes(3).toString('hex').toUpperCase()}`;
  const conditionText = reward.requires_staff_confirm
    ? 'Cần nhân viên lễ tân hoặc Huấn luyện viên xác nhận khi sử dụng tại câu lạc bộ.'
    : 'Dùng mã này khi gia hạn gói tập phòng gym hoặc xác nhận tại quầy.';

  const { rows: [redemptionRow] } = await client.query(
    `INSERT INTO loyalty_redemptions
     (id, member_id, reward_id, reward_code_snapshot, category_snapshot, title_snapshot,
      points_spent, discount_amount_snapshot, voucher_code, requires_staff_confirm,
      condition_text, status, idempotency_key, redeemed_at, expires_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'UNUSED', $12, now(),
       now() + ($13::int * interval '1 day'))
     RETURNING *`,
    [
      redemptionId,
      memberId,
      reward.id,
      reward.code,
      reward.category,
      reward.title,
      cost,
      Number(reward.discount_amount ?? 0),
      voucherCode,
      Boolean(reward.requires_staff_confirm),
      conditionText,
      idempotencyKey ?? null,
      Number(reward.valid_days ?? 30),
    ],
  );

  const txId = randomUUID();
  const { rows: [txRow] } = await client.query(
    `INSERT INTO loyalty_point_transactions
     (id, member_id, tx_type, points_delta, tier_points_delta, title, detail,
      reference_type, reference_id, status_label)
     VALUES ($1, $2, 'SPEND', $3, 0, $4, $5, 'REWARD_REDEMPTION', $6, 'Đã đổi ưu đãi')
     RETURNING *`,
    [
      txId,
      memberId,
      -cost,
      `Trừ điểm đổi ưu đãi: ${reward.title}`,
      'Chỉ trừ Điểm khả dụng · Giữ nguyên Điểm xét hạng',
      redemptionId,
    ],
  );

  const summary = await buildLoyaltySummary(client, memberId);
  return {
    replayed: false,
    redemption: formatLoyaltyRedemption(redemptionRow),
    transaction: formatLoyaltyTransaction(txRow),
    summary,
  };
}
