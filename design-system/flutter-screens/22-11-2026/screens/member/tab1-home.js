// Meta Gym Flutter Mockups — MEMBER / 1. Trang chủ (Từ ngoài vào trong)
window.METAGYM_SCREENS = window.METAGYM_SCREENS || {};
window.METAGYM_SCREENS.member = (window.METAGYM_SCREENS.member || []).concat([
  {
    id: 'member-home',
    group: 'tab1-home',
    groupLabel: '1. Trang chủ',
    title: '1.1 Trang chủ Hội viên',
    shortFile: 'member_dashboard_view.dart',
    flutterFile: 'mobile-app/lib/features/member/presentation/member_dashboard_view.dart',
    tag: 'P0 • Demo chính',
    tagClass: 'p0',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body">
          <!-- _buildHeader -->
          <div class="mg-header">
            <button type="button" class="qr-checkin-btn" data-open-qr title="Mã QR Check-in vào phòng tập">
              <img src="../../meta-gym/assets/svg/states/qr_scan_frame.svg" alt="QR Check-in" />
            </button>
            <div class="mg-header-text">
              <div class="mg-eyebrow">META GYM</div>
              <div class="mg-title">Chào, Minh Quân</div>
            </div>
            <div style="position:relative;">
              <div class="circle-btn" title="Thông báo"><img class="ico-md" src="../../meta-gym/assets/svg/setting/setting_notifications_bell.svg" alt="Thông báo" /></div>
              <span class="tnum" style="position:absolute;top:-2px;right:-2px;min-width:18px;height:18px;padding:0 5px;border-radius:999px;background:var(--primary);border:2px solid var(--bg-canvas);color:#FFF;font-size:11px;font-weight:700;display:flex;align-items:center;justify-content:center;">2</span>
            </div>
          </div>

          <!-- _buildQuickActionDock: 4 nút squircle đối xứng -->
          <div class="quick-dock">
            <div class="quick-tile">
              <img class="ico-dock ico-3d" src="../../meta-gym/assets/images/icons_3d/action_schedule_3d.webp" alt="Lịch tập" />
              <div class="quick-lbl">Lịch tập</div>
            </div>
            <div class="quick-tile">
              <img class="ico-dock ico-3d" src="../../meta-gym/assets/images/icons_3d/action_curriculum_3d.webp" alt="Giáo trình" />
              <div class="quick-lbl">Giáo trình</div>
            </div>
            <div class="quick-tile">
              <img class="ico-dock ico-3d" src="../../meta-gym/assets/images/icons_3d/action_nutrition_3d.webp" alt="Dinh dưỡng" />
              <div class="quick-lbl">Dinh dưỡng</div>
            </div>
            <div class="quick-tile">
              <img class="ico-dock ico-3d" src="../../meta-gym/assets/images/icons_3d/action_coach_3d.webp" alt="Coach" />
              <div class="quick-lbl">Coach</div>
            </div>
          </div>

          <!-- _buildMembershipAndCoachCard -->
          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:10px;">
              <span class="txt-sm txt-bold">Gói tập &amp; Coach</span>
              <span class="pill pill-success">Hiệu lực</span>
            </div>
            <div class="grid-2">
              <div class="metric-box">
                <div class="txt-xs">Gói tập</div>
                <div class="tnum" style="font-size:20px;font-weight:800;margin-top:2px;">42 ngày</div>
                <div class="txt-xs" style="margin-top:2px;">Hết hạn 03/01/2027</div>
              </div>
              <div class="metric-box">
                <div class="row" style="gap:7px;">
                  <div class="avatar-ln" style="width:28px;height:28px;font-size:11px;">LN</div>
                  <div style="min-width:0;">
                    <div class="txt-xs">Coach cá nhân</div>
                    <div class="txt-sm txt-bold" style="font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Lê Hoàng Nam</div>
                  </div>
                </div>
                <div class="txt-xs" style="color:var(--reflection);margin-top:6px;">Xem gói Coach ›</div>
              </div>
            </div>
          </div>

          <!-- _buildTodaySection (Liquid Glass featured + nút Xem ngay bên phải) -->
          <div class="card-liquid featured">
            <div class="row-between" style="margin-bottom:12px;">
              <div class="row" style="gap:6px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/workout/workout_plan_calendar.svg" alt="Hôm nay" />
                <strong style="font-size:15px;">Hôm nay</strong>
              </div>
              <div class="row" style="gap:4px;">
                <span class="txt-xs txt-green txt-bold">Đã lên lịch</span>
                <span class="txt-xs">›</span>
              </div>
            </div>
            <div class="row-between" style="gap:10px;">
              <div style="flex:1;min-width:0;">
                <div style="font-size:16px;font-weight:600;">Upper Body &amp; Core</div>
                <div class="txt-xs tnum" style="margin-top:4px;">4 bài tập · 2 bữa ăn · 18:00</div>
              </div>
              <div style="min-width:84px;height:40px;padding:0 12px;border-radius:14px;background:var(--primary);color:#FFF;font-size:12px;font-weight:700;display:flex;align-items:center;justify-content:center;">Xem ngay</div>
            </div>
          </div>

          <!-- _buildBentoSection (height: 128px, 2 cột) -->
          <div class="grid-2" style="margin-bottom:12px;">
            <div class="card-liquid" style="margin-bottom:0;min-height:128px;padding:12px;display:flex;flex-direction:column;">
              <div class="row" style="gap:5px;margin-bottom:6px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/quick_actions/action_nutrition.svg" alt="Dinh dưỡng" />
                <strong style="font-size:12px;">Dinh dưỡng</strong>
              </div>
              <div style="font-size:14px;font-weight:700;line-height:1.25;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Thực đơn tăng cơ</div>
              <div style="font-size:12px;color:var(--text-secondary);margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">1.8–2.0g đạm / kg</div>
              <div style="margin-top:auto;">
                <div class="row-between" style="margin-bottom:4px;gap:4px;">
                  <span class="tnum" style="font-size:11px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Đạm: 140/160g</span>
                  <span style="font-size:11px;font-weight:700;color:var(--success);background:rgba(46,204,113,0.14);padding:1px 5px;border-radius:5px;white-space:nowrap;flex-shrink:0;">85%</span>
                </div>
                <div class="prog-track" style="height:3px;margin-top:0;"><div class="prog-fill" style="width:85%;"></div></div>
              </div>
            </div>

            <div class="card-liquid" style="margin-bottom:0;min-height:128px;padding:12px;display:flex;flex-direction:column;">
              <div class="row-between" style="margin-bottom:8px;gap:4px;">
                <div class="row" style="gap:4px;min-width:0;">
                  <img class="ico-sm" src="../../meta-gym/assets/svg/progress/stats_chart_line.svg" alt="Tiến độ" />
                  <strong style="font-size:12px;white-space:nowrap;">Tiến độ</strong>
                </div>
                <span class="tnum" style="font-size:11px;font-weight:600;color:var(--success);background:rgba(46,204,113,0.15);border:1px solid rgba(46,204,113,0.3);padding:1px 6px;border-radius:20px;white-space:nowrap;flex-shrink:0;">3/7</span>
              </div>
              <div class="day-bubble-row">
                <div class="day-bubble"><div class="day-dot done">✓</div><span>T2</span></div>
                <div class="day-bubble"><div class="day-dot done">✓</div><span>T3</span></div>
                <div class="day-bubble"><div class="day-dot active">✓</div><span style="color:var(--primary);font-weight:700;">T4</span></div>
                <div class="day-bubble"><div class="day-dot"></div><span>T5</span></div>
                <div class="day-bubble"><div class="day-dot"></div><span>T6</span></div>
                <div class="day-bubble"><div class="day-dot"></div><span>T7</span></div>
                <div class="day-bubble"><div class="day-dot"></div><span>CN</span></div>
              </div>
              <div style="margin-top:auto;">
                <div class="row-between" style="margin-bottom:4px;gap:4px;">
                  <span style="font-size:11px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Chuỗi: 5 ngày <img class="ico-xs" src="../../meta-gym/assets/svg/states/streak_flame.svg" alt="Chuỗi" /></span>
                  <span style="font-size:11px;font-weight:700;color:var(--success);background:rgba(46,204,113,0.14);padding:1px 5px;border-radius:5px;white-space:nowrap;flex-shrink:0;">Tốt</span>
                </div>
                <div class="prog-track" style="height:3px;margin-top:0;"><div class="prog-fill" style="width:43%;"></div></div>
              </div>
            </div>
          </div>

          <!-- Meta Kong Streak Motivation Banner (bấm mở Modal Chúc mừng Cúp lửa) -->
          <div class="card-solid" data-open-sys-modal="streak" style="padding:10px 12px;margin-bottom:12px;cursor:pointer;border-color:rgba(255,94,54,0.32);">
            <div class="row" style="gap:10px;">
              <img src="../../meta-gym/assets/images/mascot/meta_kong_streak.webp?v=20261124m4" alt="Meta Kong Streak" style="width:58px;height:58px;flex-shrink:0;display:block;object-fit:contain;" />
              <div style="flex:1;min-width:0;">
                <div class="row-between" style="gap:6px;margin-bottom:2px;">
                  <strong style="font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Chuỗi 5 ngày bền bỉ!</strong>
                  <span class="pill pill-orange" style="font-size:11px;padding:2px 7px;flex-shrink:0;">+150 điểm ›</span>
                </div>
                <div class="txt-xs" style="line-height:1.35;">Meta Kong cổ vũ bạn — chỉ còn 2 ngày nữa đạt cúp tuần mới.</div>
              </div>
            </div>
          </div>

          <!-- 1. KHÁM PHÁ META GYM (4 tính năng quan trọng bằng 4 icon) -->
          <div class="row-between" style="margin:6px 0 8px;">
            <div class="row" style="gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/catalog/exercise_step_guide.svg" alt="Khám phá" /><strong style="font-size:14px;">Khám phá Meta Gym</strong></div>
            <span class="txt-xs" style="color:var(--reflection);" data-go="member-training-hub">Tất cả ›</span>
          </div>
          <div class="explore-4grid">
            <div class="explore-tile" data-go="member-gym-equipment">
              <img class="ico-dock ico-3d" src="../../meta-gym/assets/images/icons_3d/equip_machine_3d.webp" alt="Thiết bị" />
              <div class="explore-lbl">Thiết bị</div>
            </div>
            <div class="explore-tile" data-go="member-gym-visits">
              <img class="ico-dock ico-3d" src="../../meta-gym/assets/images/icons_3d/checkin_badge_3d.webp" alt="Điểm danh" />
              <div class="explore-lbl">Điểm danh</div>
            </div>
            <div class="explore-tile" data-go="member-measurement">
              <img class="ico-dock ico-3d" src="../../meta-gym/assets/images/icons_3d/body_weight_scale_3d.webp" alt="Chỉ số" />
              <div class="explore-lbl">Chỉ số</div>
            </div>
            <div class="explore-tile" data-go="member-coach-selection">
              <img class="ico-dock ico-3d" src="../../meta-gym/assets/images/icons_3d/coach_search_3d.webp" alt="Coach" />
              <div class="explore-lbl">Coach</div>
            </div>
          </div>

          <!-- 2. ĐẶC QUYỀN HỘI VIÊN — THẺ QUẸT PHÒNG TẬP DẠNG HÌNH QUẠT + THÔNG TIN BÊN DƯỚI -->
          <div class="row-between" style="margin:4px 0 6px;">
            <div class="row" style="gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/membership/premium_crown.svg" alt="Hạng hội viên" /><strong style="font-size:14px;">Đặc quyền Hội viên</strong></div>
            <span class="txt-xs" style="color:var(--primary);font-weight:600;" data-go="member-membership">Xem tất cả ›</span>
          </div>

          <div class="fan-deck-wrap" data-fan-deck data-active="2">
            <div class="fan-stage">
              <div class="fan-card" data-fan-idx="0" data-pos="2"
                   data-badge="Hạng Đồng · 1 Tháng"
                   data-title="Thẻ Đồng — Starter"
                   data-price="890.000đ / tháng"
                   data-sub="Quẹt thẻ từ vĩnh viễn vào phòng tập · Tủ khóa cá nhân">
                <img src="../../meta-gym/assets/images/membership/card_bronze.jpg?v=20261124c" alt="Thẻ Hội viên Hạng Đồng" />
              </div>
              <div class="fan-card" data-fan-idx="1" data-pos="-1"
                   data-badge="Hạng Bạc · 3 Tháng"
                   data-title="Thẻ Bạc — Plus"
                   data-price="2.490.000đ / 3 tháng"
                   data-sub="Thẻ Brushed Titanium · Tặng 1 lần InBody · Giảm 3% PT">
                <img src="../../meta-gym/assets/images/membership/card_silver.jpg?v=20261124c" alt="Thẻ Hội viên Hạng Bạc" />
              </div>
              <div class="fan-card" data-fan-idx="2" data-pos="0"
                   data-badge="★ Phổ biến nhất · 6 Tháng"
                   data-title="Thẻ Vàng — Pro VIP"
                   data-price="4.490.000đ / 6 tháng"
                   data-sub="Thẻ Champagne Gold · InBody hàng tháng · Tặng 2 buổi PT 1:1">
                <img src="../../meta-gym/assets/images/membership/card_gold.jpg?v=20261124c" alt="Thẻ Hội viên Hạng Vàng" />
              </div>
              <div class="fan-card" data-fan-idx="3" data-pos="1"
                   data-badge="Kim Cương · 12 Tháng"
                   data-title="Thẻ Kim Cương — Elite"
                   data-price="8.490.000đ / năm"
                   data-sub="Thẻ Obsidian Platinum · InBody không giới hạn · Ưu tiên Coach">
                <img src="../../meta-gym/assets/images/membership/card_diamond.jpg?v=20261124c" alt="Thẻ Hội viên Kim Cương" />
              </div>
            </div>

            <!-- Thông tin gói bên dưới thẻ (giống bố cục MoMo Cinema) -->
            <div class="fan-info">
              <div class="fan-badge-row" data-fan-badge>★ Phổ biến nhất · 6 Tháng</div>
              <div class="fan-title" data-fan-title>Thẻ Vàng — Pro VIP</div>
              <div class="fan-price" data-fan-price>4.490.000đ / 6 tháng</div>
              <div class="fan-sub" data-fan-sub>Quẹt thẻ NFC · InBody hàng tháng · Tặng 2 buổi PT 1:1</div>
              <div class="fan-controls">
                <div class="fan-dots">
                  <button type="button" class="fan-dot" data-fan-dot="0" aria-label="Hạng Đồng"></button>
                  <button type="button" class="fan-dot" data-fan-dot="1" aria-label="Hạng Bạc"></button>
                  <button type="button" class="fan-dot active" data-fan-dot="2" aria-label="Hạng Vàng"></button>
                  <button type="button" class="fan-dot" data-fan-dot="3" aria-label="Kim Cương"></button>
                </div>
                <span class="btn-mini-orange" data-go="member-membership">Xem gói tập ›</span>
              </div>
            </div>
          </div>

          <!-- 3. TIN TỨC & BÀI VIẾT -->
          <div class="row-between" style="margin:4px 0 8px;">
            <strong style="font-size:14px;">Tin tức &amp; Bài viết</strong>
            <span class="txt-xs" style="color:var(--reflection);" data-go="member-article-detail">Xem thêm ›</span>
          </div>
          <div class="card-solid" style="padding:12px 13px;margin-bottom:8px;" data-go="member-article-detail">
            <div class="row-between" style="margin-bottom:5px;">
              <span class="pill pill-orange" style="font-size:11px;padding:2px 8px;">Kiến thức tập luyện</span>
              <span class="txt-xs tnum">4 phút đọc</span>
            </div>
            <div class="txt-sm txt-bold">Nguyên tắc tăng tiến tải trọng (Progressive Overload)</div>
            <div class="txt-xs" style="margin-top:3px;">Cách ghi tạ và phục hồi hiệu quả để tăng cơ bền vững...</div>
          </div>
          <div class="card-solid" style="padding:12px 13px;" data-go="member-article-detail">
            <div class="row-between" style="margin-bottom:5px;">
              <span class="pill pill-success" style="font-size:11px;padding:2px 8px;">Dinh dưỡng</span>
              <span class="txt-xs tnum">3 phút đọc</span>
            </div>
            <div class="txt-sm txt-bold">Bữa ăn trước &amp; sau tập giúp tối ưu tổng hợp đạm</div>
            <div class="txt-xs" style="margin-top:3px;">Khung giờ vàng nạp carb và protein cho buổi tập 90 phút...</div>
          </div>
        </div>

        <div class="bottom-nav-wrap">
          <nav class="bottom-nav">
            <div class="nav-item active"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_home_filled.svg" alt="Trang chủ" /></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_training_outline.svg" alt="Tập luyện" /></div>
            <div class="nav-ai-wrap"><div class="nav-ai-btn"><img class="nav-ai-svg" src="../../meta-gym/assets/svg/navigation/nav_ai_on_primary.svg" alt="AI" /></div></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_messages_outline.svg" alt="Tin nhắn" /></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_profile_outline.svg" alt="Hồ sơ" /></div>
          </nav>
        </div>

        <!-- Level 3 Overlay Glass: Mã QR Check-in động (chỉ hiệu lực trong ngày, đổi mỗi lần tạo) -->
        <div class="qr-overlay" data-qr-modal>
          <div class="qr-sheet">
            <div class="row-between" style="margin-bottom:8px;">
              <span class="pill pill-success tnum">● Hôm nay · 22/11/2026</span>
              <span class="tnum" style="font-size:12px;color:var(--text-secondary);">ID MG-2048</span>
            </div>
            <div style="font-size:16px;font-weight:800;">QR Check-in Phòng Tập</div>
            <div style="font-size:12px;color:var(--text-secondary);margin-top:2px;">Mã riêng của Nguyễn Minh Quân · Chỉ dùng trong ngày</div>

            <div class="qr-box-white" data-qr-svg-host></div>

            <div style="background:var(--surface-raised);border:1px solid var(--border-solid);border-radius:12px;padding:8px 10px;margin-bottom:12px;">
              <div class="row-between" style="font-size:12px;">
                <span style="color:var(--text-secondary);">Mã phiên duy nhất</span>
                <strong class="tnum" style="color:var(--primary);letter-spacing:0.04em;" data-qr-token>MG-261122-8F4A</strong>
              </div>
              <div class="tnum" style="font-size:12px;color:var(--text-secondary);margin-top:3px;text-align:left;" data-qr-meta>
                Hết hạn 23:59 hôm nay · Đổi mã mới mỗi lần mở hoặc tạo lại
              </div>
            </div>

            <div class="grid-2">
              <button type="button" class="btn-secondary" style="height:44px;gap:6px;" data-regen-qr>
                <img class="ico-xs" src="../../meta-gym/assets/svg/setting/common_refresh.svg" alt="Tạo mã mới" style="background:transparent;padding:0;" />
                <span>Tạo mã mới</span>
              </button>
              <button type="button" class="btn-primary" style="height:44px;" data-close-qr>Đóng</button>
            </div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'member-membership',
    group: 'tab1-home',
    groupLabel: '1. Trang chủ',
    title: '1.2a Gói tập (Đang hiệu lực)',
    shortFile: 'membership_page.dart',
    flutterFile: 'mobile-app/lib/features/membership/presentation/membership_page.dart',
    tag: 'Happy Case',
    tagClass: '',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body no-nav">
          <div class="mg-header">
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_back.svg" alt="Quay lại" /></div>
            <div class="mg-header-text">
              <div class="mg-eyebrow">HỘI VIÊN &amp; ƯU ĐÃI</div>
              <div class="mg-title">Gói tập</div>
            </div>
          </div>

          <div class="sec-head" style="margin-top:4px;">
            <h3 class="row" style="gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/membership/membership_active_seal.svg" alt="Gói của tôi" /><span>Thẻ hội viên của tôi</span></h3>
            <span class="pill pill-success">● Hiệu lực</span>
          </div>

          <!-- Thẻ Hội viên Kim loại nằm ngang (CR80 16:10 — Mặt sau dải từ vĩnh viễn) -->
          <div style="border-radius:20px;overflow:hidden;box-shadow:0 16px 36px rgba(0,0,0,0.55);margin-bottom:10px;">
            <img src="../../meta-gym/assets/images/membership/card_gold_horizontal.jpg?v=20261124c" alt="Thẻ Vàng Meta Gym nằm ngang" style="width:100%;aspect-ratio:16/10;object-fit:cover;display:block;" />
          </div>

          <div class="card-solid" style="padding:12px 14px;margin-bottom:10px;">
            <div class="row-between" style="margin-bottom:6px;">
              <div>
                <div style="font-size:15px;font-weight:800;">Hạng Vàng — Pro 6 Tháng</div>
                <div class="txt-xs tnum">22/10/2026 → 03/01/2027 · Nguyễn Minh Quân</div>
              </div>
              <span class="pill pill-orange tnum">Còn 42 ngày</span>
            </div>
            <div class="txt-xs" style="margin-bottom:10px;">Quẹt thẻ NFC vào phòng tập · InBody hàng tháng · Tặng 2 buổi PT 1:1</div>
            <div class="grid-2" style="gap:8px;">
              <button type="button" class="btn-primary" style="height:38px;font-size:14px;" data-go="member-checkout">Gia hạn thẻ</button>
              <button type="button" class="btn-secondary" style="height:38px;font-size:14px;" data-open-redeem-points>Đổi điểm ưu đãi</button>
            </div>
          </div>

          <!-- Ví điểm Meta Points & Tiến độ nâng hạng -->
          <div class="card-warm-glass" style="padding:12px 14px;margin-bottom:10px;">
            <div class="row-between" style="margin-bottom:6px;">
              <div class="row" style="gap:6px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/states/streak_flame.svg" alt="Meta Points" />
                <strong style="font-size:14px;">Meta Points</strong>
              </div>
              <strong class="tnum txt-orange" style="font-size:16px;" data-meta-points="1240">1.240 điểm</strong>
            </div>
            <div class="prog-track" style="height:5px;margin:4px 0 6px;"><div class="prog-fill" style="width:62%;"></div></div>
            <div class="row-between txt-xs tnum">
              <span>Còn 760 điểm lên Hạng Kim Cương</span>
              <span style="color:var(--primary);font-weight:700;cursor:pointer;" data-open-redeem-points>Đổi quà ›</span>
            </div>
          </div>

          <!-- Ưu đãi đặc quyền Hạng Vàng -->
          <div class="card-solid" style="padding:12px 14px;margin-bottom:14px;">
            <div class="row-between" style="margin-bottom:8px;">
              <strong style="font-size:14px;">Ưu đãi Hạng Vàng đang áp dụng</strong>
              <span class="pill pill-success" style="font-size:11px;">3 đặc quyền</span>
            </div>
            <div style="display:flex;flex-direction:column;gap:6px;font-size:12px;">
              <div class="row-between"><span>✓ Giảm tự động phí Gói Coach 1:1</span><strong class="tnum txt-orange">-5%</strong></div>
              <div class="row-between"><span>✓ Đo chỉ số InBody chuyên sâu</span><strong class="txt-green">Miễn phí / tháng</strong></div>
              <div class="row-between"><span>✓ Tích điểm Check-in &amp; Gia hạn</span><strong class="tnum">×1.5 điểm</strong></div>
            </div>
          </div>

          <div class="sec-head"><h3 class="row" style="gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/membership/premium_crown.svg" alt="Nâng cấp" /><span>Nâng cấp hạng thẻ</span></h3><span class="txt-xs tnum">Vuốt ngang · 4 hạng</span></div>
          <div class="tier-carousel">
            <div class="card-liquid tier-pkg-card" style="border-color:rgba(112,174,232,0.55);">
              <div class="row-between" style="margin-bottom:4px;">
                <strong style="font-size:15px;">Kim Cương VIP</strong>
                <span class="pill" style="background:rgba(112,174,232,0.18);color:var(--info);">Đề xuất</span>
              </div>
              <div class="tnum" style="font-size:20px;font-weight:800;margin:4px 0;">8.490.000đ <span class="txt-xs">/ năm</span></div>
              <div class="txt-xs" style="margin-bottom:12px;line-height:1.45;">Thẻ Kim Cương NFC · InBody không giới hạn · Ưu tiên lịch Coach · 6 buổi PT 1:1</div>
              <button class="btn-primary tier-pkg-cta" data-go="member-checkout">Nâng cấp gói này</button>
            </div>

            <div class="card-solid tier-pkg-card" style="border-color:rgba(218,176,102,0.55);">
              <div class="row-between" style="margin-bottom:4px;">
                <strong style="font-size:15px;">Hạng Vàng — Pro</strong>
                <span class="pill pill-success">Đang dùng</span>
              </div>
              <div class="tnum" style="font-size:20px;font-weight:800;margin:4px 0;">4.490.000đ <span class="txt-xs">/ 6 tháng</span></div>
              <div class="txt-xs" style="margin-bottom:12px;line-height:1.45;">Thẻ Vàng NFC · InBody hàng tháng · Tặng 2 buổi PT 1:1 · MoMo / ZaloPay / VNPay</div>
              <button class="btn-secondary tier-pkg-cta" style="width:100%;" data-go="member-checkout">Gia hạn thêm</button>
            </div>

            <div class="card-solid tier-pkg-card" style="border-color:rgba(196,204,218,0.42);">
              <div class="row-between" style="margin-bottom:4px;">
                <strong style="font-size:15px;">Hạng Bạc — Plus</strong>
                <span class="pill pill-muted">3 Tháng</span>
              </div>
              <div class="tnum" style="font-size:20px;font-weight:800;margin:4px 0;">2.490.000đ <span class="txt-xs">/ 3 tháng</span></div>
              <div class="txt-xs" style="margin-bottom:12px;line-height:1.45;">Thẻ Bạc NFC · Tập full khung giờ · 1 lần đo InBody &amp; tư vấn lộ trình</div>
              <button class="btn-secondary tier-pkg-cta" style="width:100%;" data-go="member-checkout">Chọn gói này</button>
            </div>

            <div class="card-solid tier-pkg-card" style="border-color:rgba(210,145,98,0.45);">
              <div class="row-between" style="margin-bottom:4px;">
                <strong style="font-size:15px;">Hạng Đồng — Base</strong>
                <span class="pill pill-muted">1 Tháng</span>
              </div>
              <div class="tnum" style="font-size:20px;font-weight:800;margin:4px 0;">890.000đ <span class="txt-xs">/ tháng</span></div>
              <div class="txt-xs" style="margin-bottom:12px;line-height:1.45;">Thẻ Đồng NFC · Tập không giới hạn khu máy, Cardio &amp; tủ Locker cá nhân</div>
              <button class="btn-secondary tier-pkg-cta" style="width:100%;" data-go="member-checkout">Chọn gói này</button>
            </div>
          </div>

          <div class="sec-head"><h3 class="row" style="gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/workout/workout_history.svg" alt="Lịch sử gói" /><span>Lịch sử gói</span></h3><span class="sec-link row" style="gap:4px;"><img class="ico-xs" src="../../meta-gym/assets/svg/membership/payment_receipt_invoice.svg" alt="Giao dịch" /><span>Giao dịch</span></span></div>
          <div class="card-liquid" style="padding:12px 14px;">
            <div class="row-between">
              <div>
                <div class="txt-sm txt-bold">Hạng Đồng — 1 Tháng</div>
                <div class="txt-xs tnum">20/09/2026 → 20/10/2026</div>
              </div>
              <span class="pill pill-muted">Đã hết hạn</span>
            </div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'member-membership-empty',
    group: 'tab1-home',
    groupLabel: '1. Trang chủ',
    title: '1.2b Gói tập (Chưa đăng ký)',
    shortFile: 'membership_page.dart (Empty)',
    flutterFile: 'mobile-app/lib/features/membership/presentation/membership_page.dart',
    tag: 'Empty State',
    tagClass: '',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body" style="padding-bottom:88px;">
          <div class="mg-header" style="margin-bottom:8px;">
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_back.svg" alt="Quay lại" /></div>
            <div class="mg-header-text">
              <div class="mg-eyebrow">THẺ HỘI VIÊN NFC · 4 HẠNG</div>
              <div class="mg-title">Chọn gói tập</div>
            </div>
            <span class="pill pill-muted" style="font-size:11px;">Chưa có gói</span>
          </div>

          <!-- Meta Kong VIP Membership Promo Strip -->
          <div class="card-solid" data-open-sys-modal="promo" style="padding:10px 12px;margin-bottom:10px;cursor:pointer;border-color:rgba(245,176,65,0.36);">
            <div class="row" style="gap:10px;">
              <img src="../../meta-gym/assets/images/mascot/meta_kong_membership_promo.webp?v=20261124m7" alt="Meta Kong Mời nâng hạng VIP" style="width:58px;height:58px;flex-shrink:0;display:block;object-fit:contain;" />
              <div style="flex:1;min-width:0;">
                <div class="row-between" style="gap:6px;">
                  <div class="txt-sm txt-bold" style="line-height:1.25;">Mở khóa đặc quyền VIP</div>
                  <span class="pill pill-orange" style="font-size:11px;padding:2px 7px;flex-shrink:0;">Ưu đãi ›</span>
                </div>
                <div class="txt-xs" style="margin-top:2px;line-height:1.35;">Meta Kong mời bạn chọn thẻ kim loại NFC để nhận ngay 2 buổi PT 1:1!</div>
              </div>
            </div>
          </div>

          <!-- 4 Thẻ Đứng Trượt Ngang Mượt Mà (Vertical Swipe Deck) -->
          <div data-wallet-deck data-active="2">
            <div class="wallet-tabs">
              <div class="wallet-tab" data-wallet-idx="0">Đồng</div>
              <div class="wallet-tab" data-wallet-idx="1">Bạc</div>
              <div class="wallet-tab active" data-wallet-idx="2">Vàng ★</div>
              <div class="wallet-tab" data-wallet-idx="3">Kim Cương</div>
            </div>

            <div class="fan-stage" data-wallet-stage style="height:296px;margin-bottom:8px;">
              <div class="fan-card" data-wallet-card="0" data-pos="2"
                   data-name="Hạng Đồng — Starter 1 Tháng" data-badge="Khởi đầu" data-badge-cls="pill-muted"
                   data-price="890.000đ" data-period="/ tháng" data-sub="~29.600đ / ngày · Linh hoạt trải nghiệm"
                   data-coach="0%" data-inbody="Trả phí lẻ" data-pts="×1.0 điểm" data-cta="Đăng ký Hạng Đồng · 890.000đ →">
                <img src="../../meta-gym/assets/images/membership/card_bronze.jpg?v=20261124c" alt="Thẻ Đồng Meta Gym" />
              </div>
              <div class="fan-card" data-wallet-card="1" data-pos="-1"
                   data-name="Hạng Bạc — Plus 3 Tháng" data-badge="Tiết kiệm" data-badge-cls="pill-muted"
                   data-price="2.490.000đ" data-period="/ 3 tháng" data-sub="~830.000đ / tháng · Tặng 1 lần đo InBody"
                   data-coach="-3%" data-inbody="1 lần miễn phí" data-pts="×1.2 điểm" data-cta="Đăng ký Hạng Bạc · 2.490.000đ →">
                <img src="../../meta-gym/assets/images/membership/card_silver.jpg?v=20261124c" alt="Thẻ Bạc Meta Gym" />
              </div>
              <div class="fan-card" data-wallet-card="2" data-pos="0"
                   data-name="Hạng Vàng — Pro 6 Tháng" data-badge="Phổ biến nhất" data-badge-cls="pill-orange"
                   data-price="4.490.000đ" data-period="/ 6 tháng" data-sub="~748.000đ / tháng · Tặng 2 buổi PT 1:1"
                   data-coach="-5%" data-inbody="Hàng tháng" data-pts="×1.5 điểm" data-cta="Đăng ký Hạng Vàng · 4.490.000đ →">
                <img src="../../meta-gym/assets/images/membership/card_gold.jpg?v=20261124c" alt="Thẻ Vàng Meta Gym" />
              </div>
              <div class="fan-card" data-wallet-card="3" data-pos="1"
                   data-name="Kim Cương VIP — 12 Tháng" data-badge="VIP Cao cấp" data-badge-cls="pill-success"
                   data-price="8.490.000đ" data-period="/ năm" data-sub="~707.000đ / tháng · Tặng 6 buổi PT 1:1"
                   data-coach="-10%" data-inbody="Không giới hạn" data-pts="×2.0 điểm" data-cta="Đăng ký Kim Cương · 8.490.000đ →">
                <img src="../../meta-gym/assets/images/membership/card_diamond.jpg?v=20261124c" alt="Thẻ Kim Cương Meta Gym" />
              </div>
            </div>

            <div class="fan-dots" style="margin:0 0 10px;">
              <span class="fan-dot" data-wallet-idx="0"></span>
              <span class="fan-dot" data-wallet-idx="1"></span>
              <span class="fan-dot active" data-wallet-idx="2"></span>
              <span class="fan-dot" data-wallet-idx="3"></span>
            </div>

            <!-- Chi tiết quyền lợi hạng thẻ đang chọn -->
            <div class="card-solid" style="padding:14px;">
              <div class="row-between" style="margin-bottom:4px;">
                <strong style="font-size:15px;" data-w-name>Hạng Vàng — Pro 6 Tháng</strong>
                <span class="pill pill-orange" data-w-badge>Phổ biến nhất</span>
              </div>
              <div class="row" style="gap:6px;align-items:baseline;margin:4px 0 2px;">
                <span class="tnum txt-orange" style="font-size:22px;font-weight:800;" data-w-price>4.490.000đ</span>
                <span class="txt-xs" data-w-period>/ 6 tháng</span>
              </div>
              <div class="txt-xs tnum" style="margin-bottom:10px;" data-w-sub>~748.000đ / tháng · Tặng 2 buổi PT 1:1</div>

              <div class="divider" style="margin:8px 0;"></div>

              <div style="display:flex;flex-direction:column;gap:6px;font-size:12px;">
                <div class="row-between"><span>✓ Quẹt thẻ kim loại NFC &amp; QR Check-in</span><strong class="txt-green">Full giờ</strong></div>
                <div class="row-between"><span>✓ Giảm trực tiếp phí Gói Coach 1:1</span><strong class="tnum txt-orange" data-w-coach>-5%</strong></div>
                <div class="row-between"><span>✓ Đo chỉ số cơ thể InBody</span><strong data-w-inbody>Hàng tháng</strong></div>
                <div class="row-between"><span>✓ Hệ số tích điểm Meta Points</span><strong class="tnum" data-w-pts>×1.5 điểm</strong></div>
              </div>
            </div>
          </div>
        </div>

        <div class="bottom-cta-dock">
          <button type="button" class="btn-primary tnum" data-go="member-checkout" data-w-cta>Đăng ký Hạng Vàng · 4.490.000đ →</button>
        </div>
      </div>
    `
  },
  {
    id: 'member-checkout',
    group: 'tab1-home',
    groupLabel: '1. Trang chủ',
    title: '1.2c Thanh toán gói tập',
    shortFile: 'membership_checkout_page.dart',
    flutterFile: 'mobile-app/lib/features/membership/presentation/membership_checkout_page.dart',
    tag: 'Checkout • 4 Cổng',
    tagClass: '',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body" style="padding-bottom:92px;">
          <div class="mg-header">
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_back.svg" alt="Quay lại" /></div>
            <div class="mg-header-text">
              <div class="mg-eyebrow">XÁC NHẬN ĐƠN HÀNG</div>
              <div class="mg-title">Thanh toán gói tập</div>
            </div>
          </div>

          <!-- Tóm tắt gói đã chọn -->
          <div class="card-warm-glass" style="padding:12px 13px;">
            <div class="row" style="gap:11px;">
              <div style="width:76px;height:48px;border-radius:10px;overflow:hidden;flex-shrink:0;box-shadow:0 6px 14px rgba(0,0,0,0.45);">
                <img src="../../meta-gym/assets/images/membership/card_gold_horizontal.jpg?v=20261124c" alt="Thẻ Vàng" style="width:100%;height:100%;object-fit:cover;display:block;" />
              </div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong style="font-size:14px;">Hạng Vàng — Pro 6 Tháng</strong>
                  <span class="pill pill-orange" style="font-size:11px;">NFC</span>
                </div>
                <div class="txt-xs tnum" style="margin-top:2px;">Hiệu lực: 22/11/2026 → 22/05/2027</div>
                <div class="txt-xs" style="color:var(--success);margin-top:2px;">✓ Tặng 2 buổi PT 1:1 · InBody hàng tháng</div>
              </div>
            </div>
          </div>

          <!-- Nhập mã Voucher & Chọn nhanh ưu đãi -->
          <div class="card-solid" style="padding:11px 13px;margin-bottom:10px;">
            <div class="row-between" style="margin-bottom:8px;">
              <div class="row" style="gap:6px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/membership/premium_crown.svg" alt="Voucher" />
                <strong class="txt-sm">Mã ưu đãi (Voucher)</strong>
              </div>
              <span class="pill pill-success tnum" data-voucher-badge>METAGYM200 · -200k</span>
            </div>
            <div class="row" style="gap:7px;margin-bottom:7px;">
              <input type="text" data-voucher-input value="METAGYM200" placeholder="Nhập mã giảm giá..." style="flex:1;height:38px;padding:0 11px;border-radius:11px;background:var(--surface-raised);border:1px solid var(--border-solid);color:var(--text-primary);font-size:14px;font-weight:700;text-transform:uppercase;letter-spacing:0.04em;min-width:0;" />
              <button type="button" class="btn-mini-orange" data-apply-voucher-input style="height:38px;padding:0 12px;border-radius:11px;cursor:pointer;flex-shrink:0;">Áp dụng</button>
            </div>
            <div class="row" style="gap:6px;flex-wrap:wrap;">
              <span class="pill pill-orange tnum" data-quick-voucher="METAGYM200" style="cursor:pointer;font-size:11px;">METAGYM200 (−200k)</span>
              <span class="pill pill-muted tnum" data-quick-voucher="VIP500" style="cursor:pointer;font-size:11px;">VIP500 (−500k)</span>
              <span class="pill pill-muted" data-quick-voucher="" style="cursor:pointer;font-size:11px;">Bỏ mã</span>
            </div>
          </div>

          <!-- 4 Phương thức thanh toán: ZaloPay · VNPay · MoMo · Chuyển khoản -->
          <div class="sec-head" style="margin-top:2px;">
            <h3>Phương thức thanh toán</h3>
            <span class="txt-xs">4 cổng hỗ trợ</span>
          </div>

          <div style="display:flex;flex-direction:column;gap:8px;margin-bottom:10px;" data-pay-methods>
            <!-- MoMo -->
            <div class="card-solid" data-pay-method="MoMo" style="padding:11px 13px;margin-bottom:0;cursor:pointer;border-color:var(--primary);background:rgba(255,94,54,0.08);">
              <div class="row-between">
                <div class="row" style="gap:10px;">
                  <div style="width:36px;height:36px;border-radius:10px;background:#A50064;color:#FFF;font-size:11px;font-weight:800;display:flex;align-items:center;justify-content:center;flex-shrink:0;">MoMo</div>
                  <div>
                    <div class="txt-sm txt-bold">Ví điện tử MoMo</div>
                    <div class="txt-xs">Mở ứng dụng MoMo · Kích hoạt tức thì</div>
                  </div>
                </div>
                <span data-pay-radio style="width:18px;height:18px;border-radius:50%;border:5px solid var(--primary);background:#FFF;flex-shrink:0;"></span>
              </div>
            </div>

            <!-- ZaloPay -->
            <div class="card-solid" data-pay-method="ZaloPay" style="padding:11px 13px;margin-bottom:0;cursor:pointer;">
              <div class="row-between">
                <div class="row" style="gap:10px;">
                  <div style="width:36px;height:36px;border-radius:10px;background:#0068FF;color:#FFF;font-size:12px;font-weight:800;display:flex;align-items:center;justify-content:center;flex-shrink:0;">Zalo</div>
                  <div>
                    <div class="txt-sm txt-bold">Ví ZaloPay</div>
                    <div class="txt-xs">Thanh toán nhanh qua Zalo · Hoàn tiền 2%</div>
                  </div>
                </div>
                <span data-pay-radio style="width:18px;height:18px;border-radius:50%;border:2px solid var(--border-solid);flex-shrink:0;"></span>
              </div>
            </div>

            <!-- VNPay -->
            <div class="card-solid" data-pay-method="VNPay QR" style="padding:11px 13px;margin-bottom:0;cursor:pointer;">
              <div class="row-between">
                <div class="row" style="gap:10px;">
                  <div style="width:36px;height:36px;border-radius:10px;background:linear-gradient(135deg,#005BAA,#E11D48);color:#FFF;font-size:12px;font-weight:800;display:flex;align-items:center;justify-content:center;flex-shrink:0;">VNPay</div>
                  <div>
                    <div class="txt-sm txt-bold">VNPay QR / Thẻ nội địa</div>
                    <div class="txt-xs">Hỗ trợ 35+ ứng dụng ngân hàng Việt Nam</div>
                  </div>
                </div>
                <span data-pay-radio style="width:18px;height:18px;border-radius:50%;border:2px solid var(--border-solid);flex-shrink:0;"></span>
              </div>
            </div>

            <!-- Chuyển khoản VietQR (CK) -->
            <div class="card-solid" data-pay-method="Chuyển khoản (VietQR)" style="padding:11px 13px;margin-bottom:0;cursor:pointer;">
              <div class="row-between">
                <div class="row" style="gap:10px;">
                  <div style="width:36px;height:36px;border-radius:10px;background:rgba(46,204,113,0.16);border:1px solid rgba(46,204,113,0.45);color:var(--success);font-size:11px;font-weight:800;display:flex;align-items:center;justify-content:center;flex-shrink:0;">CK</div>
                  <div>
                    <div class="txt-sm txt-bold">Chuyển khoản ngân hàng (VietQR)</div>
                    <div class="txt-xs">MB Bank · Đối soát tự động 24/7 trong 5 giây</div>
                  </div>
                </div>
                <span data-pay-radio style="width:18px;height:18px;border-radius:50%;border:2px solid var(--border-solid);flex-shrink:0;"></span>
              </div>
              <!-- Thông tin CK hiện khi chọn CK -->
              <div data-ck-box style="display:none;margin-top:10px;padding-top:10px;border-top:1px solid var(--border-solid);">
                <div class="row-between txt-xs" style="margin-bottom:4px;"><span>Ngân hàng</span><strong style="color:var(--text-primary);">MB Bank · Meta Gym JSC</strong></div>
                <div class="row-between txt-xs tnum" style="margin-bottom:4px;"><span>Số tài khoản</span><strong style="color:var(--primary);">8888 2026 9999</strong></div>
                <div class="row-between txt-xs tnum"><span>Nội dung CK</span><strong style="color:var(--success);">MG2048 GOLD6M</strong></div>
              </div>
            </div>
          </div>

          <!-- Chi tiết thanh toán -->
          <div class="card-solid" style="padding:12px 14px;">
            <div class="row-between txt-xs" style="margin-bottom:5px;">
              <span>Giá gói Hạng Vàng (6 tháng)</span>
              <span class="tnum">4.490.000đ</span>
            </div>
            <div class="row-between txt-xs" style="margin-bottom:7px;">
              <span>Ưu đãi METAGYM200</span>
              <span class="tnum txt-green" data-ck-discount>-200.000đ</span>
            </div>
            <div class="divider" style="margin:6px 0;"></div>
            <div class="row-between">
              <strong class="txt-sm">Tổng thanh toán</strong>
              <strong class="tnum txt-orange" style="font-size:20px;" data-ck-total>4.290.000đ</strong>
            </div>
          </div>
        </div>

        <div class="bottom-cta-dock">
          <button type="button" class="btn-primary tnum" data-open-checkout-pay>Thanh toán 4.290.000đ · MoMo</button>
        </div>
      </div>
    `
  },
  {
    id: 'member-coach-booking',
    group: 'tab1-home',
    groupLabel: '1. Trang chủ',
    title: '1.3 Lịch Coach',
    shortFile: 'coach_booking_page.dart',
    flutterFile: 'mobile-app/lib/features/sessions/presentation/coach_booking_page.dart',
    tag: 'P0 • 125 hex',
    tagClass: 'p0',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body no-nav">
          <div class="mg-header">
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_back.svg" alt="Quay lại" /></div>
            <div class="mg-header-text">
              <div class="mg-title" style="font-size:20px;">Lịch Coach</div>
              <div class="mg-sub">Đặt lịch &amp; quản lý buổi tập 1:1</div>
            </div>
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/workout/workout_history.svg" alt="Lịch sử" /></div>
          </div>

          <!-- _buildSegmentedTabs: 4 tab tương tác lọc thực -->
          <div class="seg-tabs">
            <div class="seg-tab active" data-state-btn="all" style="cursor:pointer;">Tất cả</div>
            <div class="seg-tab" data-state-btn="pkg" style="cursor:pointer;">Gói Coach</div>
            <div class="seg-tab" data-state-btn="upcoming" style="cursor:pointer;">Sắp tới</div>
            <div class="seg-tab" data-state-btn="history" style="cursor:pointer;">Lịch sử</div>
          </div>

          <!-- Gói Coach đang hiệu lực -->
          <div data-state-pane="pkg">
            <div class="sec-head"><h3>Gói Coach đang hiệu lực</h3><span class="txt-xs tnum">1 gói</span></div>
            <div class="card-warm-glass">
              <div class="row-between" style="margin-bottom:10px;">
                <div class="row" style="gap:8px;">
                  <div class="avatar-ln">LN</div>
                  <div>
                    <div class="txt-sm txt-bold">Lê Hoàng Nam</div>
                    <div class="txt-xs">Gói PT 24 buổi · Khung 90 phút</div>
                  </div>
                </div>
                <span class="pill pill-success">Hiệu lực</span>
              </div>
              <div class="grid-3" style="margin-bottom:10px;">
                <div class="metric-box" style="text-align:center;padding:8px 4px;"><div class="tnum txt-bold">14</div><div class="txt-xs">Còn lại</div></div>
                <div class="metric-box" style="text-align:center;padding:8px 4px;"><div class="tnum txt-bold">10</div><div class="txt-xs">Đã tập</div></div>
                <div class="metric-box" style="text-align:center;padding:8px 4px;"><div class="tnum txt-bold">03/01</div><div class="txt-xs">Hết hạn</div></div>
              </div>
              <button class="btn-primary">Đặt buổi tập mới</button>
            </div>
          </div>

          <!-- Buổi tập sắp tới -->
          <div data-state-pane="upcoming">
            <div class="sec-head"><h3>Buổi tập sắp tới</h3><span class="txt-xs tnum">2 lịch hẹn</span></div>
            <div class="card-liquid">
              <div class="row-between" style="margin-bottom:6px;">
                <span class="pill pill-success">Đã đặt lịch</span>
                <span class="txt-xs tnum">90 phút</span>
              </div>
              <div class="txt-sm txt-bold">Buổi tập với Coach Lê Hoàng Nam</div>
              <div class="txt-xs tnum" style="margin:4px 0 10px;">Thứ 6, 22/11/2026 · 18:00 – 19:30</div>
              <div class="grid-2">
                <span class="btn-secondary" data-go="member-curriculum">Kế hoạch</span>
                <span class="btn-secondary" style="color:var(--error);">Hủy lịch</span>
              </div>
            </div>
          </div>

          <!-- Lịch sử buổi tập -->
          <div data-state-pane="history">
            <div class="sec-head"><h3>Lịch sử buổi tập</h3><span class="txt-xs tnum">10 buổi</span></div>
            <div class="card-solid" style="padding:12px 14px;margin-bottom:9px;">
              <div class="row-between" style="margin-bottom:4px;">
                <strong class="txt-sm">Upper Body &amp; Core</strong>
                <span class="pill pill-success">Hoàn thành</span>
              </div>
              <div class="txt-xs tnum">Thứ 4, 20/11/2026 · 18:00 – 19:30 · HLV Lê Hoàng Nam</div>
            </div>
            <div class="card-solid" style="padding:12px 14px;">
              <div class="row-between" style="margin-bottom:4px;">
                <strong class="txt-sm">Lower Body · Squat &amp; RDL</strong>
                <span class="pill pill-success">Hoàn thành</span>
              </div>
              <div class="txt-xs tnum">Thứ 2, 18/11/2026 · 18:00 – 19:30 · HLV Lê Hoàng Nam</div>
            </div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'member-payments',
    group: 'tab1-home',
    groupLabel: '1. Trang chủ',
    title: '1.4 Thanh toán & Giao dịch',
    shortFile: 'payment_history_page.dart',
    flutterFile: 'mobile-app/lib/features/membership/presentation/payment_history_page.dart',
    tag: 'P2 • Giao dịch',
    tagClass: '',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body no-nav">
          <div class="mg-header">
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_back.svg" alt="Quay lại" /></div>
            <div class="mg-header-text">
              <div class="mg-eyebrow">GIAO DỊCH HỘI VIÊN</div>
              <div class="mg-title">Thanh toán</div>
            </div>
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_refresh.svg" alt="Tải lại" /></div>
          </div>

          <div class="sec-head" style="margin-top:4px;"><h3>Dịch vụ đang hoạt động</h3></div>
          <div class="grid-2" style="gap:8px;margin-bottom:10px;">
            <div class="card-warm-glass" style="margin-bottom:0;padding:11px 12px;cursor:pointer;" data-go="member-membership">
              <div class="txt-xs">Thẻ Hội viên</div>
              <div style="font-size:14px;font-weight:800;margin:2px 0;">Hạng Vàng 6T</div>
              <span class="pill pill-success tnum" style="font-size:11px;">Còn 42 ngày</span>
            </div>
            <div class="card-solid" style="margin-bottom:0;padding:11px 12px;cursor:pointer;" data-go="member-coach-booking">
              <div class="txt-xs">Gói Coach 1:1</div>
              <div style="font-size:14px;font-weight:800;margin:2px 0;">PT 24 buổi</div>
              <span class="pill pill-orange tnum" style="font-size:11px;">Còn 14 buổi</span>
            </div>
          </div>

          <div class="seg-tabs" style="margin-bottom:10px;">
            <div class="seg-tab active" data-state-btn="all" style="cursor:pointer;">Tất cả</div>
            <div class="seg-tab" data-state-btn="membership" style="cursor:pointer;">Thẻ Hội viên</div>
            <div class="seg-tab" data-state-btn="coach" style="cursor:pointer;">Gói Coach</div>
          </div>

          <div class="sec-head" style="margin-top:0;"><h3>Lịch sử giao dịch</h3><span class="txt-xs tnum">3 hóa đơn</span></div>

          <div data-state-pane="coach">
            <div class="card-liquid" style="padding:13px 14px;margin-bottom:9px;">
              <div class="row-between">
                <div class="row" style="gap:8px;">
                  <img class="ico-md" src="../../meta-gym/assets/svg/brand/pay_vnpay.svg" alt="VNPay" />
                  <div>
                    <div class="txt-sm txt-bold">Gói Coach 24 buổi</div>
                    <div class="txt-xs tnum">20/11/2026 · Giảm 5% Hạng Vàng</div>
                  </div>
                </div>
                <div style="text-align:right;">
                  <div class="tnum txt-bold" style="font-size:14px;">8.455.000đ</div>
                  <span class="pill pill-success" style="font-size:11px;padding:1px 7px;">+420 điểm</span>
                </div>
              </div>
            </div>
          </div>

          <div data-state-pane="membership">
            <div class="card-liquid" style="padding:13px 14px;margin-bottom:9px;">
              <div class="row-between">
                <div class="row" style="gap:8px;">
                  <img class="ico-md" src="../../meta-gym/assets/svg/brand/pay_momo.svg" alt="MoMo" />
                  <div>
                    <div class="txt-sm txt-bold">Thẻ Vàng — Pro 6 Tháng</div>
                    <div class="txt-xs tnum">22/10/2026 · #MG-261022</div>
                  </div>
                </div>
                <div style="text-align:right;">
                  <div class="tnum txt-bold" style="font-size:14px;">4.290.000đ</div>
                  <span class="pill pill-success" style="font-size:11px;padding:1px 7px;">+215 điểm</span>
                </div>
              </div>
            </div>

            <div class="card-liquid" style="padding:13px 14px;">
              <div class="row-between">
                <div class="row" style="gap:8px;">
                  <img class="ico-md" src="../../meta-gym/assets/svg/membership/payment_receipt_invoice.svg" alt="Hóa đơn" />
                  <div>
                    <div class="txt-sm txt-bold">Thẻ Đồng — 1 Tháng</div>
                    <div class="txt-xs tnum">20/09/2026 · #MG-260920</div>
                  </div>
                </div>
                <div style="text-align:right;">
                  <div class="tnum txt-bold" style="font-size:14px;">890.000đ</div>
                  <span class="pill pill-muted" style="font-size:11px;padding:1px 7px;">Đã hoàn tất</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'member-article-detail',
    group: 'tab1-home',
    groupLabel: '1. Trang chủ',
    title: '1.5 Chi tiết bài viết',
    shortFile: 'member_explore_articles.dart',
    flutterFile: 'mobile-app/lib/features/member/presentation/member_explore_articles.dart',
    tag: 'P2 • Kiến thức',
    tagClass: '',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body no-nav">
          <div class="mg-header">
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_back.svg" alt="Quay lại" /></div>
            <div class="mg-header-text">
              <div class="mg-eyebrow">KIẾN THỨC TẬP LUYỆN</div>
              <div class="mg-title">Chi tiết bài viết</div>
            </div>
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/community/social_bookmark.svg" alt="Lưu bài" /></div>
          </div>

          <div class="card-warm-glass" style="padding:16px;">
            <div class="row-between" style="margin-bottom:8px;">
              <span class="pill pill-orange">Kiến thức tập luyện</span>
              <span class="txt-xs tnum">4 phút đọc · 22/11/2026</span>
            </div>
            <div style="font-size:20px;font-weight:800;line-height:1.3;">
              Nguyên tắc tăng tiến tải trọng (Progressive Overload)
            </div>
            <div class="row" style="gap:8px;margin-top:10px;">
              <div class="avatar-ln" style="width:28px;height:28px;font-size:11px;">LN</div>
              <span class="txt-xs">Biên soạn bởi <strong>HLV Lê Hoàng Nam</strong></span>
            </div>
          </div>

          <div class="card-solid" style="padding:15px;">
            <div style="font-size:14px;font-weight:700;margin-bottom:6px;">1. Progressive Overload là gì?</div>
            <div class="txt-xs" style="line-height:1.6;margin-bottom:12px;">
              Tăng tiến tải trọng là việc tăng dần áp lực lên cơ bắp theo thời gian — có thể tăng mức tạ (+2.5 kg), tăng số lần lặp (+1–2 reps) hoặc cải thiện tốc độ kiểm soát nhịp tạ (tempo).
            </div>

            <div style="font-size:14px;font-weight:700;margin-bottom:6px;">2. Cách áp dụng an toàn mỗi tuần</div>
            <div class="txt-xs" style="line-height:1.6;margin-bottom:12px;">
              • Ghi lại mức tạ &amp; số reps sau mỗi buổi trong <strong>Nhật ký tập luyện</strong>.<br />
              • Khi hoàn thành đủ 4 hiệp × 10 reps đúng kỹ thuật, tăng thêm 2.5 kg ở tuần kế tiếp.<br />
              • Đảm bảo ngủ đủ 7–8 tiếng và nạp đủ 1.8–2.0g đạm / kg cân nặng.
            </div>

            <div class="metric-box" style="padding:10px 12px;margin-bottom:12px;">
              <div class="txt-xs txt-orange txt-bold" style="margin-bottom:2px;">Gợi ý thực hành ngay</div>
              <div class="txt-xs">Mở Nhật ký tập luyện để lưu lại kỷ lục mức tạ (PR) buổi tập tối nay.</div>
            </div>

            <button class="btn-primary" data-go="member-journal">Mở Nhật ký tập luyện →</button>
          </div>
        </div>
      </div>
    `
  }
]);
