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
              <span class="tnum" style="position:absolute;top:-2px;right:-2px;min-width:18px;height:18px;padding:0 5px;border-radius:999px;background:var(--primary);border:2px solid var(--bg-canvas);color:#FFF;font-size:9.5px;font-weight:700;display:flex;align-items:center;justify-content:center;">2</span>
            </div>
          </div>

          <!-- _buildQuickActionDock: 4 nút squircle đối xứng -->
          <div class="quick-dock">
            <div class="quick-tile">
              <img class="ico-dock" src="../../meta-gym/assets/svg/quick_actions/action_schedule.svg" alt="Lịch tập" />
              <div class="quick-lbl">Lịch tập</div>
            </div>
            <div class="quick-tile">
              <img class="ico-dock" src="../../meta-gym/assets/svg/quick_actions/action_curriculum.svg" alt="Giáo trình" />
              <div class="quick-lbl">Giáo trình</div>
            </div>
            <div class="quick-tile">
              <img class="ico-dock" src="../../meta-gym/assets/svg/quick_actions/action_nutrition.svg" alt="Dinh dưỡng" />
              <div class="quick-lbl">Dinh dưỡng</div>
            </div>
            <div class="quick-tile">
              <img class="ico-dock" src="../../meta-gym/assets/svg/quick_actions/action_coach.svg" alt="Coach" />
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
                <div class="tnum" style="font-size:19px;font-weight:800;margin-top:2px;">42 ngày</div>
                <div class="txt-xs" style="margin-top:2px;">Hết hạn 03/01/2027</div>
              </div>
              <div class="metric-box">
                <div class="row" style="gap:7px;">
                  <div class="avatar-ln" style="width:28px;height:28px;font-size:10.5px;">LN</div>
                  <div style="min-width:0;">
                    <div class="txt-xs">Coach cá nhân</div>
                    <div class="txt-sm txt-bold" style="font-size:12.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Lê Hoàng Nam</div>
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
                <div style="font-size:15.5px;font-weight:600;">Upper Body &amp; Core</div>
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
              <div style="font-size:12.5px;font-weight:700;line-height:1.2;">Thực đơn tăng cơ</div>
              <div style="font-size:10.5px;color:var(--text-secondary);margin-top:2px;">1.8–2.0g đạm / kg</div>
              <div style="margin-top:auto;">
                <div class="row-between" style="margin-bottom:4px;">
                  <span class="tnum" style="font-size:10.5px;font-weight:600;">Đạm: 140 / 160g</span>
                  <span style="font-size:9.5px;font-weight:700;color:var(--success);background:rgba(46,204,113,0.14);padding:1px 5px;border-radius:5px;">85%</span>
                </div>
                <div class="prog-track" style="height:3px;margin-top:0;"><div class="prog-fill" style="width:85%;"></div></div>
              </div>
            </div>

            <div class="card-liquid" style="margin-bottom:0;min-height:128px;padding:12px;display:flex;flex-direction:column;">
              <div class="row-between" style="margin-bottom:8px;">
                <div class="row" style="gap:4px;">
                  <img class="ico-sm" src="../../meta-gym/assets/svg/progress/stats_chart_line.svg" alt="Tiến độ" />
                  <strong style="font-size:12px;">Tiến độ</strong>
                </div>
                <span class="tnum" style="font-size:8.5px;font-weight:600;color:var(--success);background:rgba(46,204,113,0.15);border:1px solid rgba(46,204,113,0.3);padding:1px 6px;border-radius:20px;">3/7 buổi</span>
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
                <div class="row-between" style="margin-bottom:4px;">
                  <span style="font-size:10.5px;font-weight:600;">Chuỗi: 5 ngày <img class="ico-xs" src="../../meta-gym/assets/svg/states/streak_flame.svg" alt="Chuỗi" /></span>
                  <span style="font-size:9.5px;font-weight:700;color:var(--success);background:rgba(46,204,113,0.14);padding:1px 5px;border-radius:5px;">Tốt</span>
                </div>
                <div class="prog-track" style="height:3px;margin-top:0;"><div class="prog-fill" style="width:43%;"></div></div>
              </div>
            </div>
          </div>

          <!-- 1. KHÁM PHÁ META GYM (4 tính năng quan trọng bằng 4 icon) -->
          <div class="row-between" style="margin:6px 0 8px;">
            <div class="row" style="gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/catalog/exercise_step_guide.svg" alt="Khám phá" /><strong style="font-size:13.5px;">Khám phá Meta Gym</strong></div>
            <span class="txt-xs" style="color:var(--reflection);" data-go="member-training-hub">Tất cả ›</span>
          </div>
          <div class="explore-4grid">
            <div class="explore-tile" data-go="member-gym-equipment">
              <img class="ico-dock" src="../../meta-gym/assets/svg/catalog/equip_machine.svg" alt="Thiết bị" />
              <div class="explore-lbl">Thiết bị</div>
            </div>
            <div class="explore-tile" data-go="member-gym-visits">
              <img class="ico-dock" src="../../meta-gym/assets/svg/states/checkin_badge.svg" alt="Điểm danh" />
              <div class="explore-lbl">Điểm danh</div>
            </div>
            <div class="explore-tile" data-go="member-measurement">
              <img class="ico-dock" src="../../meta-gym/assets/svg/progress/body_weight_scale.svg" alt="Chỉ số" />
              <div class="explore-lbl">Chỉ số</div>
            </div>
            <div class="explore-tile" data-go="member-coach-selection">
              <img class="ico-dock" src="../../meta-gym/assets/svg/coaching/coach_pkg_1on1.svg" alt="Coach" />
              <div class="explore-lbl">Coach</div>
            </div>
          </div>

          <!-- 2. ĐẶC QUYỀN HỘI VIÊN — THẺ QUẸT PHÒNG TẬP DẠNG HÌNH QUẠT + THÔNG TIN BÊN DƯỚI -->
          <div class="row-between" style="margin:4px 0 6px;">
            <div class="row" style="gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/membership/premium_crown.svg" alt="Hạng hội viên" /><strong style="font-size:13.5px;">Đặc quyền Hội viên</strong></div>
            <span class="txt-xs" style="color:var(--primary);font-weight:600;" data-go="member-membership">Xem tất cả ›</span>
          </div>

          <div class="fan-deck-wrap" data-fan-deck data-active="2">
            <div class="fan-stage">
              <div class="fan-card" data-fan-idx="0" data-pos="2"
                   data-badge="Hạng Đồng · 1 Tháng"
                   data-title="Thẻ Đồng — Starter"
                   data-price="890.000đ / tháng"
                   data-sub="Quẹt thẻ NFC vào phòng tập · Tủ khóa cá nhân">
                <img src="../../meta-gym/assets/images/membership/card_bronze.jpg?v=3" alt="Thẻ Hội viên Hạng Đồng" />
              </div>
              <div class="fan-card" data-fan-idx="1" data-pos="-1"
                   data-badge="Hạng Bạc · 3 Tháng"
                   data-title="Thẻ Bạc — Plus"
                   data-price="2.490.000đ / 3 tháng"
                   data-sub="Quẹt thẻ NFC · Tặng 1 lần InBody · Giảm 10% PT">
                <img src="../../meta-gym/assets/images/membership/card_silver.jpg?v=2" alt="Thẻ Hội viên Hạng Bạc" />
              </div>
              <div class="fan-card" data-fan-idx="2" data-pos="0"
                   data-badge="★ Phổ biến nhất · 6 Tháng"
                   data-title="Thẻ Vàng — Pro VIP"
                   data-price="4.490.000đ / 6 tháng"
                   data-sub="Quẹt thẻ NFC · InBody hàng tháng · Tặng 2 buổi PT 1:1">
                <img src="../../meta-gym/assets/images/membership/card_gold.jpg?v=3" alt="Thẻ Hội viên Hạng Vàng" />
              </div>
              <div class="fan-card" data-fan-idx="3" data-pos="1"
                   data-badge="Kim Cương · 12 Tháng"
                   data-title="Thẻ Kim Cương — Elite"
                   data-price="8.490.000đ / năm"
                   data-sub="Thẻ kim loại VIP · InBody không giới hạn · Ưu tiên Coach">
                <img src="../../meta-gym/assets/images/membership/card_diamond.jpg?v=2" alt="Thẻ Hội viên Kim Cương" />
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
            <strong style="font-size:13.5px;">Tin tức &amp; Bài viết</strong>
            <span class="txt-xs" style="color:var(--reflection);" data-go="member-article-detail">Xem thêm ›</span>
          </div>
          <div class="card-solid" style="padding:12px 13px;margin-bottom:8px;" data-go="member-article-detail">
            <div class="row-between" style="margin-bottom:5px;">
              <span class="pill pill-orange" style="font-size:10px;padding:2px 8px;">Kiến thức tập luyện</span>
              <span class="txt-xs tnum">4 phút đọc</span>
            </div>
            <div class="txt-sm txt-bold">Nguyên tắc tăng tiến tải trọng (Progressive Overload)</div>
            <div class="txt-xs" style="margin-top:3px;">Cách ghi tạ và phục hồi hiệu quả để tăng cơ bền vững...</div>
          </div>
          <div class="card-solid" style="padding:12px 13px;" data-go="member-article-detail">
            <div class="row-between" style="margin-bottom:5px;">
              <span class="pill pill-success" style="font-size:10px;padding:2px 8px;">Dinh dưỡng</span>
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
              <span class="tnum" style="font-size:11.5px;color:#8E95A5;">ID MG-2048</span>
            </div>
            <div style="font-size:17px;font-weight:800;">QR Check-in Phòng Tập</div>
            <div style="font-size:12px;color:#8E95A5;margin-top:2px;">Mã riêng của Nguyễn Minh Quân · Chỉ dùng trong ngày</div>

            <div class="qr-box-white" data-qr-svg-host></div>

            <div style="background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.12);border-radius:12px;padding:8px 10px;margin-bottom:12px;">
              <div class="row-between" style="font-size:11.5px;">
                <span style="color:#8E95A5;">Mã phiên duy nhất</span>
                <strong class="tnum" style="color:#FF5E36;letter-spacing:0.04em;" data-qr-token>MG-261122-8F4A</strong>
              </div>
              <div class="tnum" style="font-size:10.5px;color:#C8C2BC;margin-top:3px;text-align:left;" data-qr-meta>
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

          <!-- Thẻ Hội viên Kim loại nằm ngang (16:10) -->
          <div style="border-radius:20px;overflow:hidden;box-shadow:0 16px 36px rgba(0,0,0,0.55);margin-bottom:10px;">
            <img src="../../meta-gym/assets/images/membership/card_gold_horizontal.jpg?v=2" alt="Thẻ Vàng Meta Gym nằm ngang" style="width:100%;aspect-ratio:16/10;object-fit:cover;display:block;" />
          </div>

          <div class="card-solid" style="padding:12px 14px;margin-bottom:14px;">
            <div class="row-between" style="margin-bottom:6px;">
              <div>
                <div style="font-size:15px;font-weight:800;">Hạng Vàng — Pro 6 Tháng</div>
                <div class="txt-xs tnum">22/10/2026 → 03/01/2027 · Nguyễn Minh Quân</div>
              </div>
              <span class="pill pill-orange tnum">Còn 42 ngày</span>
            </div>
            <div class="txt-xs">Quẹt thẻ NFC vào phòng tập · InBody hàng tháng · Tặng 2 buổi PT 1:1</div>
          </div>

          <div class="sec-head"><h3 class="row" style="gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/membership/premium_crown.svg" alt="Nâng cấp" /><span>Nâng cấp hạng thẻ</span></h3><span class="txt-xs tnum">Vuốt ngang · 4 hạng</span></div>
          <div class="tier-carousel">
            <div class="card-liquid tier-pkg-card" style="border-color:rgba(112,174,232,0.55);">
              <div class="row-between" style="margin-bottom:4px;">
                <strong style="font-size:14.5px;">Kim Cương VIP</strong>
                <span class="pill" style="background:rgba(112,174,232,0.18);color:#70AEE8;">Đề xuất</span>
              </div>
              <div class="tnum" style="font-size:20px;font-weight:800;margin:4px 0;">8.490.000đ <span class="txt-xs">/ năm</span></div>
              <div class="txt-xs" style="margin-bottom:12px;line-height:1.45;">Thẻ Kim Cương NFC · InBody không giới hạn · Ưu tiên lịch Coach · 6 buổi PT 1:1</div>
              <button class="btn-primary tier-pkg-cta" data-go="member-payments">Nâng cấp gói này</button>
            </div>

            <div class="card-solid tier-pkg-card" style="border-color:rgba(218,176,102,0.55);">
              <div class="row-between" style="margin-bottom:4px;">
                <strong style="font-size:14.5px;">Hạng Vàng — Pro</strong>
                <span class="pill pill-success">Đang dùng</span>
              </div>
              <div class="tnum" style="font-size:20px;font-weight:800;margin:4px 0;">4.490.000đ <span class="txt-xs">/ 6 tháng</span></div>
              <div class="txt-xs" style="margin-bottom:12px;line-height:1.45;">Thẻ Vàng NFC · InBody hàng tháng · Tặng 2 buổi PT 1:1 · Thanh toán MoMo / VNPay</div>
              <button class="btn-secondary tier-pkg-cta" style="width:100%;" data-go="member-payments">Gia hạn thêm</button>
            </div>

            <div class="card-solid tier-pkg-card" style="border-color:rgba(196,204,218,0.42);">
              <div class="row-between" style="margin-bottom:4px;">
                <strong style="font-size:14.5px;">Hạng Bạc — Plus</strong>
                <span class="pill pill-muted">3 Tháng</span>
              </div>
              <div class="tnum" style="font-size:20px;font-weight:800;margin:4px 0;">2.490.000đ <span class="txt-xs">/ 3 tháng</span></div>
              <div class="txt-xs" style="margin-bottom:12px;line-height:1.45;">Thẻ Bạc NFC · Tập full khung giờ · 1 lần đo InBody &amp; tư vấn lộ trình</div>
              <button class="btn-secondary tier-pkg-cta" style="width:100%;" data-go="member-payments">Chọn gói này</button>
            </div>

            <div class="card-solid tier-pkg-card" style="border-color:rgba(210,145,98,0.45);">
              <div class="row-between" style="margin-bottom:4px;">
                <strong style="font-size:14.5px;">Hạng Đồng — Base</strong>
                <span class="pill pill-muted">1 Tháng</span>
              </div>
              <div class="tnum" style="font-size:20px;font-weight:800;margin:4px 0;">890.000đ <span class="txt-xs">/ tháng</span></div>
              <div class="txt-xs" style="margin-bottom:12px;line-height:1.45;">Thẻ Đồng NFC · Tập không giới hạn khu máy, Cardio &amp; tủ Locker cá nhân</div>
              <button class="btn-secondary tier-pkg-cta" style="width:100%;" data-go="member-payments">Chọn gói này</button>
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

        <div class="phone-body no-nav">
          <div class="mg-header">
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_back.svg" alt="Quay lại" /></div>
            <div class="mg-header-text">
              <div class="mg-eyebrow">HỘI VIÊN &amp; ƯU ĐÃI</div>
              <div class="mg-title">Gói tập</div>
            </div>
          </div>

          <!-- Empty State: Chưa đăng ký gói -->
          <div class="card-warm-glass" style="text-align:center;padding:22px 16px;">
            <div style="width:60px;height:60px;border-radius:50%;margin:0 auto 12px;background:rgba(255,94,54,0.16);border:1px solid rgba(255,94,54,0.45);display:flex;align-items:center;justify-content:center;">
              <img class="ico-lg" src="../../meta-gym/assets/svg/membership/premium_unlock.svg" alt="Chưa có gói" style="background:transparent;padding:0;" />
            </div>
            <div style="font-size:17px;font-weight:800;">Chưa có gói tập hiệu lực</div>
            <div class="txt-xs" style="margin:6px 0 14px;line-height:1.5;">
              Đăng ký gói Hội viên để nhận thẻ NFC quẹt cổng phòng tập, theo dõi nhật ký và đặt lịch Coach 1:1.
            </div>
          </div>

          <div class="sec-head"><h3 class="row" style="gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/membership/premium_crown.svg" alt="Gói đang bán" /><span>Chọn gói bắt đầu</span></h3><span class="txt-xs tnum">4 hạng thẻ</span></div>

          <div class="card-solid" style="border-color:rgba(255,94,54,0.55);margin-bottom:10px;">
            <div class="row-between" style="margin-bottom:4px;">
              <strong style="font-size:15px;">Hạng Vàng — Pro 6 Tháng</strong>
              <span class="pill pill-orange">Phổ biến</span>
            </div>
            <div class="tnum" style="font-size:21px;font-weight:800;margin:4px 0;">4.490.000đ <span class="txt-xs">/ 6 tháng</span></div>
            <div class="txt-xs" style="margin-bottom:10px;">Thẻ Vàng NFC · InBody hàng tháng · Tặng 2 buổi PT 1:1</div>
            <button class="btn-primary" data-go="member-payments">Đăng ký ngay →</button>
          </div>

          <div class="card-solid" style="margin-bottom:10px;">
            <div class="row-between">
              <div>
                <strong class="txt-sm">Hạng Bạc — Plus 3 Tháng</strong>
                <div class="tnum txt-sm txt-bold" style="margin-top:2px;">2.490.000đ <span class="txt-xs">/ 3 tháng</span></div>
              </div>
              <span class="btn-secondary" data-go="member-payments">Chọn gói</span>
            </div>
          </div>

          <div class="card-solid">
            <div class="row-between">
              <div>
                <strong class="txt-sm">Hạng Đồng — Starter 1 Tháng</strong>
                <div class="tnum txt-sm txt-bold" style="margin-top:2px;">890.000đ <span class="txt-xs">/ tháng</span></div>
              </div>
              <span class="btn-secondary" data-go="member-payments">Chọn gói</span>
            </div>
          </div>
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
              <div class="mg-title" style="font-size:19px;">Lịch Coach</div>
              <div class="mg-sub">Đặt lịch &amp; quản lý buổi tập 1:1</div>
            </div>
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/workout/workout_history.svg" alt="Lịch sử" /></div>
          </div>

          <!-- _buildSegmentedTabs: 4 tab -->
          <div class="seg-tabs">
            <div class="seg-tab active">Tất cả</div>
            <div class="seg-tab">Gói Coach</div>
            <div class="seg-tab">Sắp tới</div>
            <div class="seg-tab">Lịch sử</div>
          </div>

          <!-- Gói Coach đang hiệu lực -->
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

          <!-- Buổi tập sắp tới -->
          <div class="sec-head"><h3>Buổi tập sắp tới</h3><span class="txt-xs tnum">2 lịch hẹn</span></div>
          <div class="card-liquid">
            <div class="row-between" style="margin-bottom:6px;">
              <span class="pill pill-success">Đã đặt lịch</span>
              <span class="txt-xs tnum">90 phút</span>
            </div>
            <div class="txt-sm txt-bold">Buổi tập với Coach Lê Hoàng Nam</div>
            <div class="txt-xs tnum" style="margin:4px 0 10px;">Thứ 6, 22/11/2026 · 18:00 – 19:30</div>
            <div class="grid-2">
              <span class="btn-secondary">Xem kế hoạch ngày</span>
              <span class="btn-secondary" style="color:var(--error);">Hủy lịch</span>
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

          <div class="sec-head" style="margin-top:4px;"><h3>Gói đang hoạt động</h3></div>
          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:6px;">
              <div class="row" style="gap:7px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/membership/membership_active_seal.svg" alt="Hiệu lực" />
                <strong style="font-size:15px;">PT VIP 3 Tháng</strong>
              </div>
              <span class="pill pill-success">Hiệu lực</span>
            </div>
            <div class="txt-xs tnum">22/10/2026 → 03/01/2027 · Còn 42 ngày</div>
          </div>

          <div class="sec-head"><h3>Lịch sử giao dịch</h3><span class="txt-xs tnum">3 hóa đơn</span></div>
          <div class="card-liquid" style="padding:13px 14px;margin-bottom:9px;">
            <div class="row-between" style="margin-bottom:6px;">
              <div class="row" style="gap:8px;">
                <img class="ico-md" src="../../meta-gym/assets/svg/brand/pay_vnpay.svg" alt="VNPay" />
                <div>
                  <div class="txt-sm txt-bold">Gói Coach 24 buổi</div>
                  <div class="txt-xs tnum">20/11/2026 · #MG-261120</div>
                </div>
              </div>
              <div style="text-align:right;">
                <div class="tnum txt-bold" style="font-size:14px;">8.900.000đ</div>
                <span class="pill pill-success" style="font-size:10px;padding:1px 7px;">Thành công</span>
              </div>
            </div>
          </div>

          <div class="card-liquid" style="padding:13px 14px;margin-bottom:9px;">
            <div class="row-between">
              <div class="row" style="gap:8px;">
                <img class="ico-md" src="../../meta-gym/assets/svg/brand/pay_momo.svg" alt="MoMo" />
                <div>
                  <div class="txt-sm txt-bold">Gói Hội viên 3 Tháng</div>
                  <div class="txt-xs tnum">22/10/2026 · #MG-261022</div>
                </div>
              </div>
              <div style="text-align:right;">
                <div class="tnum txt-bold" style="font-size:14px;">2.490.000đ</div>
                <span class="pill pill-success" style="font-size:10px;padding:1px 7px;">Thành công</span>
              </div>
            </div>
          </div>

          <div class="card-liquid" style="padding:13px 14px;">
            <div class="row-between">
              <div class="row" style="gap:8px;">
                <img class="ico-md" src="../../meta-gym/assets/svg/membership/payment_receipt_invoice.svg" alt="Hóa đơn" />
                <div>
                  <div class="txt-sm txt-bold">Gói Hội viên 1 Tháng</div>
                  <div class="txt-xs tnum">20/09/2026 · #MG-260920</div>
                </div>
              </div>
              <div style="text-align:right;">
                <div class="tnum txt-bold" style="font-size:14px;">890.000đ</div>
                <span class="pill pill-muted" style="font-size:10px;padding:1px 7px;">Đã hoàn tất</span>
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
            <div style="font-size:18px;font-weight:800;line-height:1.3;">
              Nguyên tắc tăng tiến tải trọng (Progressive Overload)
            </div>
            <div class="row" style="gap:8px;margin-top:10px;">
              <div class="avatar-ln" style="width:28px;height:28px;font-size:10px;">LN</div>
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
