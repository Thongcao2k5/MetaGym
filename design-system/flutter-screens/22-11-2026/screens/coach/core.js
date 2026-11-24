// Meta Gym Flutter Mockups — COACH / Màn hình chính
window.METAGYM_SCREENS = window.METAGYM_SCREENS || {};
window.METAGYM_SCREENS.coach = (window.METAGYM_SCREENS.coach || []).concat([
  {
    id: 'coach-home',
    group: 'core',
    groupLabel: 'Màn hình chính',
    title: '1. Trang chủ Coach',
    shortFile: 'coach_home_page.dart',
    flutterFile: 'mobile-app/lib/features/coach/presentation/coach_home_page.dart',
    tag: 'P0 • 3.591 dòng',
    tagClass: 'p0',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body">
          <!-- _buildHeader (MG + META GYM · COACH / Xin chào + Bell badge + LN avatar) -->
          <div class="mg-header" style="margin-bottom:4px;">
            <div class="mg-logo"><img src="../../meta-gym/assets/svg/brand/app_icon_mark.svg" alt="Meta Gym" /></div>
            <div class="mg-header-text">
              <div class="mg-eyebrow">META GYM · COACH</div>
              <div class="mg-title">Xin chào, Lê Hoàng Nam</div>
            </div>
            <div style="position:relative;">
              <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/setting_notifications_bell.svg" alt="Thông báo" /></div>
              <span class="tnum" style="position:absolute;top:-2px;right:-2px;min-width:18px;height:18px;padding:0 5px;border-radius:999px;background:var(--primary);border:2px solid var(--bg-canvas);font-size:11px;font-weight:700;display:flex;align-items:center;justify-content:center;">3</span>
            </div>
            <div class="avatar-ln" style="width:40px;height:40px;">LN</div>
          </div>
          <div class="txt-xs" style="color:var(--text-warm-muted);margin-bottom:12px;">Không gian dành cho huấn luyện viên</div>

          <!-- _buildQuickActionDock: Học viên, Giáo trình, Dinh dưỡng, Lịch tập -->
          <div class="quick-dock">
            <div class="quick-tile"><img class="ico-dock" src="../../meta-gym/assets/svg/quick_actions/action_members.svg" alt="Học viên" /><div class="quick-lbl">Học viên</div></div>
            <div class="quick-tile"><img class="ico-dock" src="../../meta-gym/assets/svg/quick_actions/action_coach_plans.svg" alt="Giáo trình" /><div class="quick-lbl">Giáo trình</div></div>
            <div class="quick-tile"><img class="ico-dock" src="../../meta-gym/assets/svg/quick_actions/action_nutrition.svg" alt="Dinh dưỡng" /><div class="quick-lbl">Dinh dưỡng</div></div>
            <div class="quick-tile"><img class="ico-dock" src="../../meta-gym/assets/svg/quick_actions/action_coach_sessions.svg" alt="Lịch tập" /><div class="quick-lbl">Lịch tập</div></div>
          </div>

          <!-- _buildHeroSummaryCard -->
          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:8px;">
              <span class="txt-sm txt-bold">Tổng quan hôm nay</span>
              <span class="pill pill-success">Đang nhận lịch</span>
            </div>
            <div class="grid-3">
              <div class="metric-box" style="text-align:center;padding:8px 4px;"><div class="tnum txt-bold" style="font-size:16px;">4</div><div class="txt-xs">Ca dạy</div></div>
              <div class="metric-box" style="text-align:center;padding:8px 4px;"><div class="tnum txt-bold txt-green" style="font-size:16px;">12</div><div class="txt-xs">Học viên</div></div>
              <div class="metric-box" style="text-align:center;padding:8px 4px;"><div class="tnum txt-bold txt-orange" style="font-size:16px;">6/7</div><div class="txt-xs">Ngày mở</div></div>
            </div>
          </div>

          <!-- Quản lý & Thiết lập lịch (_buildManagementCard) -->
          <div class="sec-head"><h3 class="row" style="gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/quick_actions/action_coach_workweek.svg" alt="Quản lý" /><span>Quản lý &amp; Thiết lập lịch</span></h3></div>
          <div class="card-liquid" style="padding:4px 14px;">
            <div class="row-between" style="padding:10px 0;"><div><div class="txt-sm txt-bold">Hội viên của tôi</div><div class="txt-xs">12 hội viên đang đồng hành</div></div><span class="txt-xs">›</span></div>
            <div class="divider" style="margin:0;"></div>
            <div class="row-between" style="padding:10px 0;"><div><div class="txt-sm txt-bold">Lịch làm việc cố định theo tuần</div><div class="txt-xs tnum">Đang mở 6/7 ngày · Khung 90 phút</div></div><span class="txt-xs">›</span></div>
            <div class="divider" style="margin:0;"></div>
            <div class="row-between" style="padding:10px 0;"><div><div class="txt-sm txt-bold">Chặn khung giờ bận</div><div class="txt-xs">Khóa lịch nghỉ cá nhân</div></div><span class="txt-xs">›</span></div>
            <div class="divider" style="margin:0;"></div>
            <div class="row-between" style="padding:10px 0;"><div><div class="txt-sm txt-bold">Gói PT &amp; Bảng giá</div><div class="txt-xs">Quản lý đề xuất gói Coaching</div></div><span class="txt-xs">›</span></div>
          </div>

          <!-- _buildTodayBookingsSection -->
          <div class="sec-head"><h3>Lịch dạy hôm nay</h3><span class="txt-xs tnum">Khung 90 phút</span></div>
          <div class="card-liquid" style="padding:12px 14px;">
            <div class="row-between">
              <div>
                <div class="txt-sm txt-bold">Nguyễn Minh Quân</div>
                <div class="txt-xs tnum">18:00 – 19:30 (90 phút) · Upper Body · Sức mạnh</div>
              </div>
              <span class="pill pill-orange">Sắp tới</span>
            </div>
          </div>
        </div>

        <div class="bottom-nav-wrap">
          <nav class="bottom-nav">
            <div class="nav-item active"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_home_filled.svg" alt="Trang chủ" /></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_coach_schedule_outline.svg" alt="Lịch dạy" /></div>
            <div class="nav-ai-wrap"><div class="nav-ai-btn"><img class="nav-ai-svg" src="../../meta-gym/assets/svg/navigation/nav_ai_on_primary.svg" alt="AI" /></div></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_messages_outline.svg" alt="Tin nhắn" /></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_profile_outline.svg" alt="Hồ sơ" /></div>
          </nav>
        </div>
      </div>
    `
  },
  {
    id: 'coach-sessions',
    group: 'core',
    groupLabel: 'Màn hình chính',
    title: '2. Lịch dạy &amp; Buổi hẹn',
    shortFile: 'coach_sessions_page.dart',
    flutterFile: 'mobile-app/lib/features/sessions/presentation/coach_sessions_page.dart',
    tag: 'P1 • 1.181 dòng',
    tagClass: '',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>
        <div class="phone-body">
          <div class="mg-header">
            <div class="mg-logo"><img src="../../meta-gym/assets/svg/brand/app_icon_mark.svg" alt="Meta Gym" /></div>
            <div class="mg-header-text">
              <div class="mg-eyebrow">META GYM · COACH</div>
              <div class="mg-title">Lịch dạy</div>
            </div>
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/setting_notifications_bell.svg" alt="Thông báo" /></div>
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_refresh.svg" alt="Tải lại" /></div>
          </div>

          <div class="seg-tabs">
            <div class="seg-tab active">Tất cả</div>
            <div class="seg-tab">Sắp tới</div>
            <div class="seg-tab">Đã xong</div>
          </div>

          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:6px;">
              <strong class="txt-sm">Lịch làm việc hằng tuần</strong>
              <span class="pill pill-success tnum">6/7 ngày</span>
            </div>
            <div class="txt-xs" style="margin-bottom:10px;">Khung 90 phút · Đã khóa 2 khung giờ bận tuần này</div>
            <button class="btn-primary">Cấu hình lịch &amp; khung giờ</button>
          </div>

          <div class="sec-head"><h3>Buổi hẹn sắp tới</h3><span class="txt-xs tnum">3 ca</span></div>
          <div class="card-liquid" style="padding:13px;">
            <div class="row-between" style="margin-bottom:6px;">
              <span class="pill pill-orange">Hôm nay · 18:00 – 19:30</span>
              <span class="pill pill-success">Đã đặt</span>
            </div>
            <div class="txt-sm txt-bold">Nguyễn Minh Quân</div>
            <div class="txt-xs" style="margin:3px 0 10px;">Upper Body · Sức mạnh · Khung 90 phút</div>
            <div class="grid-2">
              <span class="btn-secondary">Hủy buổi dạy</span>
              <span class="btn-primary" style="height:38px;font-size:14px;">Hoàn thành ca</span>
            </div>
          </div>

          <div class="card-liquid" style="padding:13px;">
            <div class="row-between" style="margin-bottom:6px;">
              <span class="pill pill-muted">T7, 23/11 · 09:00 – 10:30</span>
              <span class="pill pill-success">Đã đặt</span>
            </div>
            <div class="txt-sm txt-bold">Trần Thảo Vy</div>
            <div class="txt-xs" style="margin-top:3px;">Glutes &amp; Core · Giảm mỡ · Khung 90 phút</div>
          </div>
        </div>
        <div class="bottom-nav-wrap">
          <nav class="bottom-nav">
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_home_outline.svg" alt="Trang chủ" /></div>
            <div class="nav-item active"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_coach_schedule_filled.svg" alt="Lịch dạy" /></div>
            <div class="nav-ai-wrap"><div class="nav-ai-btn"><img class="nav-ai-svg" src="../../meta-gym/assets/svg/navigation/nav_ai_on_primary.svg" alt="AI" /></div></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_messages_outline.svg" alt="Tin nhắn" /></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_profile_outline.svg" alt="Hồ sơ" /></div>
          </nav>
        </div>
      </div>
    `
  },
  {
    id: 'coach-members',
    group: 'core',
    groupLabel: 'Màn hình chính',
    title: '3. Hội viên của tôi',
    shortFile: 'coach_members_page.dart',
    flutterFile: 'mobile-app/lib/features/coaching/presentation/coach_members_page.dart',
    tag: 'P2 • 493 dòng',
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
              <div class="mg-eyebrow">META GYM · COACH</div>
              <div class="mg-title">Hội viên của tôi</div>
            </div>
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_refresh.svg" alt="Tải lại" /></div>
          </div>

          <div class="sec-head" style="margin-top:4px;"><h3>Đang phụ trách</h3><span class="txt-xs tnum">12 hội viên</span></div>
          <div class="card-liquid" style="padding:13px;">
            <div class="row">
              <div class="avatar-member" style="width:40px;height:40px;font-size:14px;">MQ</div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong class="txt-sm">Nguyễn Minh Quân</strong>
                  <span class="pill pill-success">Hiệu lực</span>
                </div>
                <div class="txt-xs tnum" style="margin-top:2px;">Còn 14/24 buổi · Tăng cơ Hypertrophy</div>
              </div>
              <span class="txt-xs">›</span>
            </div>
          </div>

          <div class="card-liquid" style="padding:13px;">
            <div class="row">
              <div class="avatar-member" style="width:40px;height:40px;font-size:14px;background:#262A34;">TV</div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong class="txt-sm">Trần Thảo Vy</strong>
                  <span class="pill pill-success">Hiệu lực</span>
                </div>
                <div class="txt-xs tnum" style="margin-top:2px;">Còn 6/12 buổi · Giảm mỡ &amp; Core</div>
              </div>
              <span class="txt-xs">›</span>
            </div>
          </div>

          <div class="sec-head"><h3>Yêu cầu ngừng phụ trách</h3><span class="txt-xs tnum">0 yêu cầu</span></div>
          <div class="card-liquid" style="padding:14px;">
            <div class="txt-sm txt-bold">Chưa có yêu cầu nào.</div>
            <div class="txt-xs" style="margin-top:3px;">Các yêu cầu kết thúc gói Coaching sẽ hiển thị tại đây.</div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'coach-training',
    group: 'core',
    groupLabel: 'Màn hình chính',
    title: '4. Giáo trình của Coach',
    shortFile: 'coach_training_page.dart',
    flutterFile: 'mobile-app/lib/features/training/presentation/coach_training_page.dart',
    tag: 'P2 • 693 dòng',
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
              <div class="mg-eyebrow">GIÁO TRÌNH</div>
              <div class="mg-title">Giáo trình của Coach</div>
            </div>
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_add.svg" alt="Thêm" /></div>
          </div>

          <div class="sec-head" style="margin-top:4px;"><h3>Chọn hội viên</h3><span class="txt-xs tnum">Đang đồng hành</span></div>
          <div class="card-warm-glass" style="padding:13px;">
            <div class="row-between">
              <div class="row">
                <div class="avatar-member" style="width:38px;height:38px;font-size:14px;">MQ</div>
                <div>
                  <div class="txt-sm txt-bold">Nguyễn Minh Quân</div>
                  <div class="txt-xs">Đang áp dụng: Giáo trình tăng cơ 8 tuần</div>
                </div>
              </div>
              <span class="pill pill-success">Đang tập</span>
            </div>
          </div>

          <div class="sec-head"><h3>Danh sách giáo trình</h3><span class="sec-link">+ Tạo giáo trình</span></div>
          <div class="card-liquid" style="padding:13px;">
            <div class="row-between" style="margin-bottom:4px;">
              <strong class="txt-sm">Hypertrophy 8 tuần — Giai đoạn 2</strong>
              <span class="pill pill-success">Đang chạy</span>
            </div>
            <div class="txt-xs tnum">28 ngày tập · 5 buổi/tuần · Kèm thực đơn ngày</div>
          </div>
          <div class="card-liquid" style="padding:13px;">
            <div class="row-between" style="margin-bottom:4px;">
              <strong class="txt-sm">Nền tảng sức mạnh — Tuần 1–4</strong>
              <span class="pill pill-muted">Hoàn thành</span>
            </div>
            <div class="txt-xs tnum">16 ngày tập · Đã hoàn tất 100%</div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'coach-nutrition',
    group: 'core',
    groupLabel: 'Màn hình chính',
    title: '5. Dinh dưỡng của Coach',
    shortFile: 'coach_nutrition_page.dart',
    flutterFile: 'mobile-app/lib/features/training/presentation/coach_nutrition_page.dart',
    tag: 'P2 • 597 dòng',
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
              <div class="mg-eyebrow">DINH DƯỠNG</div>
              <div class="mg-title">Dinh dưỡng của Coach</div>
            </div>
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_add.svg" alt="Thêm" /></div>
          </div>

          <div class="sec-head" style="margin-top:4px;"><h3>Chọn hội viên</h3></div>
          <div class="card-warm-glass" style="padding:13px;">
            <div class="row-between">
              <div class="row">
                <div class="avatar-member" style="width:38px;height:38px;font-size:14px;">MQ</div>
                <div>
                  <div class="txt-sm txt-bold">Nguyễn Minh Quân</div>
                  <div class="txt-xs tnum">Mục tiêu: 2.200 kcal · 160g đạm/ngày</div>
                </div>
              </div>
              <span class="pill pill-success">Hiệu lực</span>
            </div>
          </div>

          <div class="sec-head"><h3>Danh sách hướng dẫn</h3><span class="sec-link">+ Tạo hướng dẫn</span></div>
          <div class="card-liquid" style="padding:13px;">
            <div class="row-between" style="margin-bottom:4px;">
              <strong class="txt-sm">Tăng cơ sạch — Tuần 4</strong>
              <span class="pill pill-success">Đang áp dụng</span>
            </div>
            <div class="txt-xs tnum">4 bữa/ngày · 1.8–2.0g đạm/kg · Cập nhật 20/11</div>
          </div>
          <div class="card-liquid" style="padding:13px;">
            <div class="row-between" style="margin-bottom:4px;">
              <strong class="txt-sm">Giai đoạn làm quen — Tuần 1–3</strong>
              <span class="pill pill-muted">Lưu trữ</span>
            </div>
            <div class="txt-xs tnum">2.050 kcal · 145g đạm/ngày</div>
          </div>
        </div>
      </div>
    `
  }
]);
