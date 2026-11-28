/**
 * Pure Voucher evaluation, phase calculation, and discount pricing helper.
 * Used across Voucher preview, Admin UI display, Online checkout, and Front-Desk POS.
 */

export function evaluateVoucherPhase(voucher, nowMs = Date.now()) {
  if (!voucher) return 'ARCHIVED';
  if (voucher.status === 'ARCHIVED') return 'ARCHIVED';
  if (voucher.status === 'PAUSED') return 'PAUSED';

  const startMs = voucher.starts_at ? Date.parse(voucher.starts_at) : null;
  const endMs = voucher.ends_at ? Date.parse(voucher.ends_at) : null;

  if (Number.isFinite(startMs) && nowMs < startMs) return 'UPCOMING';
  if (Number.isFinite(endMs) && nowMs > endMs) return 'EXPIRED';

  const maxTotal = voucher.max_total_uses !== null && voucher.max_total_uses !== undefined
    ? Number(voucher.max_total_uses)
    : null;
  const usedCount = Number(voucher.used_count ?? 0);
  if (maxTotal !== null && usedCount >= maxTotal) return 'DEPLETED';

  return 'ACTIVE';
}

export function computeVoucherDiscount({
  voucher,
  orderAmount,
  scope = 'GYM_PLAN',
  planId = null,
  memberHasPriorSuccessPayment = false,
  memberRedemptionCount = 0,
  nowMs = Date.now(),
}) {
  const originalAmount = Math.max(0, Number(orderAmount ?? 0));
  if (!voucher) {
    return {
      valid: false,
      code: 'VOUCHER_NOT_FOUND',
      message: 'Mã voucher không tồn tại.',
    };
  }

  const phase = evaluateVoucherPhase(voucher, nowMs);
  if (phase === 'ARCHIVED') {
    return { valid: false, code: 'VOUCHER_INACTIVE', message: 'Voucher đã ngừng lưu hành.' };
  }
  if (phase === 'PAUSED') {
    return { valid: false, code: 'VOUCHER_PAUSED', message: 'Voucher đang tạm ngưng áp dụng.' };
  }
  if (phase === 'UPCOMING') {
    return { valid: false, code: 'VOUCHER_NOT_STARTED', message: 'Voucher chưa tới thời gian áp dụng.' };
  }
  if (phase === 'EXPIRED') {
    return { valid: false, code: 'VOUCHER_EXPIRED', message: 'Voucher đã hết hạn sử dụng.' };
  }
  if (phase === 'DEPLETED') {
    return { valid: false, code: 'VOUCHER_DEPLETED', message: 'Voucher đã hết lượt sử dụng.' };
  }

  const maxPerMember = Number(voucher.max_uses_per_member ?? 1);
  if (Number(memberRedemptionCount ?? 0) >= maxPerMember) {
    return {
      valid: false,
      code: 'VOUCHER_MEMBER_LIMIT_REACHED',
      message: `Bạn đã dùng tối đa ${maxPerMember} lượt cho voucher này.`,
    };
  }

  const applyScope = voucher.apply_scope || 'ALL';
  if (applyScope !== 'ALL' && applyScope !== scope) {
    const scopeName = applyScope === 'GYM_PLAN' ? 'Gói Gym' : 'Gói Huấn luyện viên';
    return {
      valid: false,
      code: 'VOUCHER_SCOPE_MISMATCH',
      message: `Voucher này chỉ áp dụng cho ${scopeName}.`,
    };
  }

  if (voucher.target_plan_id && planId && voucher.target_plan_id !== planId) {
    return {
      valid: false,
      code: 'VOUCHER_PLAN_MISMATCH',
      message: 'Voucher không áp dụng cho gói tập đang chọn.',
    };
  }

  const targetMemberScope = voucher.target_member_scope || 'ALL';
  if (targetMemberScope === 'NEW_MEMBER' && memberHasPriorSuccessPayment) {
    return {
      valid: false,
      code: 'VOUCHER_NEW_MEMBER_ONLY',
      message: 'Voucher chỉ dành cho hội viên mua gói lần đầu.',
    };
  }
  if (targetMemberScope === 'RENEWAL' && !memberHasPriorSuccessPayment) {
    return {
      valid: false,
      code: 'VOUCHER_RENEWAL_ONLY',
      message: 'Voucher chỉ áp dụng cho hội viên gia hạn gói.',
    };
  }

  const minOrder = Number(voucher.min_order_amount ?? 0);
  if (originalAmount < minOrder) {
    const formatted = minOrder.toLocaleString('vi-VN');
    return {
      valid: false,
      code: 'VOUCHER_MIN_ORDER_NOT_MET',
      message: `Đơn hàng tối thiểu ${formatted} ₫ để áp dụng voucher này.`,
    };
  }

  let discountAmount = 0;
  const discountValue = Number(voucher.discount_value ?? 0);
  if (voucher.discount_type === 'PERCENT') {
    discountAmount = Math.floor((originalAmount * discountValue) / 100);
    if (voucher.max_discount_amount !== null && voucher.max_discount_amount !== undefined) {
      discountAmount = Math.min(discountAmount, Number(voucher.max_discount_amount));
    }
  } else {
    discountAmount = discountValue;
  }

  discountAmount = Math.max(0, Math.min(originalAmount, discountAmount));
  const finalAmount = Math.max(0, originalAmount - discountAmount);

  return {
    valid: true,
    originalAmount,
    discountAmount,
    finalAmount,
  };
}

export function serializeVoucher(row) {
  const imageMediaId = row.image_media_id ?? null;
  const maxTotalUses = row.max_total_uses !== null && row.max_total_uses !== undefined
    ? Number(row.max_total_uses)
    : null;
  const usedCount = Number(row.used_count ?? 0);
  const phase = evaluateVoucherPhase(row);

  return {
    id: row.id,
    code: row.code,
    title: row.title,
    description: row.description ?? null,
    imageMediaId,
    imageUrl: imageMediaId ? `/api/v1/media/public/${imageMediaId}?v=${imageMediaId}` : null,
    imageThumbnailUrl: imageMediaId ? `/api/v1/media/public/${imageMediaId}?size=120&v=${imageMediaId}` : null,
    discountType: row.discount_type,
    discountValue: Number(row.discount_value),
    maxDiscountAmount: row.max_discount_amount !== null && row.max_discount_amount !== undefined
      ? Number(row.max_discount_amount)
      : null,
    applyScope: row.apply_scope || 'ALL',
    targetPlanId: row.target_plan_id ?? null,
    targetPlanName: row.target_plan_name ?? null,
    targetMemberScope: row.target_member_scope || 'ALL',
    minOrderAmount: Number(row.min_order_amount ?? 0),
    maxTotalUses,
    maxUsesPerMember: Number(row.max_uses_per_member ?? 1),
    usedCount,
    remainingUses: maxTotalUses !== null ? Math.max(0, maxTotalUses - usedCount) : null,
    startsAt: row.starts_at ? new Date(row.starts_at).toISOString() : null,
    endsAt: row.ends_at ? new Date(row.ends_at).toISOString() : null,
    status: row.status,
    phase,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
