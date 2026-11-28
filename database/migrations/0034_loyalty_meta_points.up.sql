BEGIN;

-- Loyalty · Meta Points schema (tách bạch Gói tập theo thời hạn vs Hạng thành viên theo điểm xét hạng)
CREATE TABLE loyalty_accounts (
  member_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  available_points integer NOT NULL DEFAULT 0 CHECK (available_points >= 0),
  tier_points integer NOT NULL DEFAULT 0 CHECK (tier_points >= 0),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE loyalty_rewards (
  id uuid PRIMARY KEY,
  code varchar(60) NOT NULL UNIQUE,
  category varchar(20) NOT NULL CHECK (category IN ('VOUCHER', 'SERVICE')),
  title varchar(120) NOT NULL,
  description text NOT NULL,
  points_cost integer NOT NULL CHECK (points_cost > 0),
  discount_amount bigint NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
  requires_staff_confirm boolean NOT NULL DEFAULT false,
  stock_remaining integer CHECK (stock_remaining IS NULL OR stock_remaining >= 0),
  valid_days integer NOT NULL DEFAULT 30 CHECK (valid_days > 0),
  terms jsonb NOT NULL DEFAULT '[]'::jsonb,
  status varchar(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE loyalty_redemptions (
  id uuid PRIMARY KEY,
  member_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reward_id uuid NOT NULL REFERENCES loyalty_rewards(id),
  reward_code_snapshot varchar(60) NOT NULL,
  category_snapshot varchar(20) NOT NULL CHECK (category_snapshot IN ('VOUCHER', 'SERVICE')),
  title_snapshot varchar(120) NOT NULL,
  points_spent integer NOT NULL CHECK (points_spent > 0),
  discount_amount_snapshot bigint NOT NULL DEFAULT 0 CHECK (discount_amount_snapshot >= 0),
  voucher_code varchar(40) NOT NULL UNIQUE,
  requires_staff_confirm boolean NOT NULL DEFAULT false,
  condition_text text NOT NULL,
  status varchar(20) NOT NULL DEFAULT 'UNUSED' CHECK (status IN ('UNUSED', 'USED', 'EXPIRED')),
  idempotency_key varchar(100),
  redeemed_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  CONSTRAINT uq_loyalty_redemptions_member_idemp UNIQUE (member_id, idempotency_key),
  CONSTRAINT ck_loyalty_redemptions_dates CHECK (expires_at >= redeemed_at)
);

CREATE TABLE loyalty_point_transactions (
  id uuid PRIMARY KEY,
  member_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tx_type varchar(20) NOT NULL CHECK (tx_type IN ('EARN', 'SPEND', 'ADJUST')),
  points_delta integer NOT NULL,
  tier_points_delta integer NOT NULL DEFAULT 0,
  title varchar(160) NOT NULL,
  detail text,
  reference_type varchar(40),
  reference_id uuid,
  status_label varchar(40) NOT NULL DEFAULT 'Thành công',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Link optional redeemed voucher to package payments (used only when member selects an unused voucher)
ALTER TABLE payments
  ADD COLUMN loyalty_redemption_id uuid REFERENCES loyalty_redemptions(id),
  ADD COLUMN loyalty_discount_amount bigint NOT NULL DEFAULT 0 CHECK (loyalty_discount_amount >= 0);

CREATE INDEX ix_loyalty_rewards_active_sort
  ON loyalty_rewards (status, sort_order, created_at);

CREATE INDEX ix_loyalty_redemptions_member_redeemed
  ON loyalty_redemptions (member_id, redeemed_at DESC, id DESC);

CREATE INDEX ix_loyalty_transactions_member_created
  ON loyalty_point_transactions (member_id, created_at DESC, id DESC);

CREATE UNIQUE INDEX uq_loyalty_tx_idempotent_ref
  ON loyalty_point_transactions (member_id, reference_type, reference_id, tx_type)
  WHERE reference_id IS NOT NULL;

CREATE TRIGGER trg_loyalty_accounts_updated_at
  BEFORE UPDATE ON loyalty_accounts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_loyalty_rewards_updated_at
  BEFORE UPDATE ON loyalty_rewards
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Default catalog rewards
INSERT INTO loyalty_rewards (
  id, code, category, title, description, points_cost, discount_amount,
  requires_staff_confirm, stock_remaining, valid_days, terms, status, sort_order
)
VALUES
  (
    'a0000000-0000-4000-8000-000000000001',
    'rw-voucher-100',
    'VOUCHER',
    'Voucher giảm 100.000đ',
    'Giảm trực tiếp 100.000đ khi gia hạn gói tập phòng gym hoặc áp dụng tại quầy.',
    300,
    100000,
    false,
    NULL,
    30,
    '["Áp dụng 1 lần khi gia hạn hoặc đăng ký gói tập tại Meta Gym.","Đổi ưu đãi chỉ trừ Điểm khả dụng, giữ nguyên Điểm xét hạng.","Không quy đổi thành tiền mặt."]'::jsonb,
    'ACTIVE',
    1
  ),
  (
    'a0000000-0000-4000-8000-000000000002',
    'rw-inbody',
    'SERVICE',
    'Một lần đo InBody',
    'Phân tích tỷ lệ cơ, mỡ và nước cơ thể tại khu vực đo chỉ số của câu lạc bộ.',
    400,
    0,
    true,
    NULL,
    30,
    '["Cần nhân viên tại quầy xác nhận trước khi thực hiện đo InBody.","Áp dụng 1 lượt cho chính chủ tài khoản trong thời hạn hiệu lực.","Khuyến nghị nhịn ăn nhẹ 2 giờ trước khi đo để số liệu ổn định."]'::jsonb,
    'ACTIVE',
    2
  ),
  (
    'a0000000-0000-4000-8000-000000000003',
    'rw-pt-trial',
    'SERVICE',
    'Một buổi PT trải nghiệm',
    'Một buổi tập 1:1 cùng Huấn luyện viên Meta Gym để đánh giá kỹ thuật và tư thế.',
    900,
    0,
    true,
    NULL,
    30,
    '["Cần nhân viên lễ tân hoặc Huấn luyện viên xác nhận khung giờ tập phù hợp.","Áp dụng cho 1 hội viên chính chủ theo thông tin tài khoản.","Đổi ưu đãi không làm giảm Điểm xét hạng."]'::jsonb,
    'ACTIVE',
    3
  ),
  (
    'a0000000-0000-4000-8000-000000000004',
    'rw-vip-perk',
    'VOUCHER',
    'Ưu đãi cao cấp',
    'Gói đặc quyền nâng cấp trải nghiệm và voucher dịch vụ cao cấp tại Meta Gym.',
    1500,
    300000,
    true,
    NULL,
    45,
    '["Áp dụng tại quầy dịch vụ với xác nhận của nhân viên phụ trách.","Không áp dụng cộng dồn với các chương trình giảm giá khác."]'::jsonb,
    'ACTIVE',
    4
  ),
  (
    'a0000000-0000-4000-8000-000000000005',
    'rw-sold-out',
    'VOUCHER',
    'Quà tặng bình giữ nhiệt Meta Gym',
    'Quà tặng lưu niệm phiên bản giới hạn tại quầy lễ tân câu lạc bộ.',
    600,
    0,
    true,
    0,
    30,
    '["Nhận trực tiếp tại quầy khi đợt phát hành có hàng trở lại."]'::jsonb,
    'ACTIVE',
    5
  )
ON CONFLICT (id) DO NOTHING;

REVOKE ALL ON TABLE
  loyalty_accounts,
  loyalty_rewards,
  loyalty_redemptions,
  loyalty_point_transactions
FROM PUBLIC;

COMMIT;
