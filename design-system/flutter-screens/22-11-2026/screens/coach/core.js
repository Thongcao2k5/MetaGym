// Meta Gym Flutter Mockups — COACH / 1. Trang chủ & Học viên (Từ ngoài vào trong)
window.METAGYM_SCREENS = window.METAGYM_SCREENS || {};
window.METAGYM_SCREENS.coach = (window.METAGYM_SCREENS.coach || []).concat([
  {
    id: 'coach-home',
    group: 'coach-tab1-home',
    groupLabel: '1. Trang chủ & Học viên',
    title: '1.1 Trang chủ Coach',
    shortFile: 'coach_home_page.dart',
    flutterFile: 'mobile-app/lib/features/coach/presentation/coach_home_page.dart',
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
          <div class="mg-header" style="margin-bottom:10px;">
            <div class="mg-logo"><img src="../../meta-gym/assets/svg/brand/app_icon_mark.svg" alt="Meta Gym" /></div>
            <div class="mg-header-text">
              <div class="mg-eyebrow">META GYM · COACH</div>
              <div class="mg-title">Chào, Hoàng Nam</div>
              <div class="txt-xs" style="color:var(--text-warm-muted);margin-top:1px;">Huấn luyện viên 1:1</div>
            </div>
            <div style="position:relative;" data-go="coach-notifications" title="Thông báo Coach">
              <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/setting_notifications_bell.svg" alt="Thông báo" /></div>
              <span class="tnum" style="position:absolute;top:-2px;right:-2px;min-width:18px;height:18px;padding:0 5px;border-radius:999px;background:var(--primary);border:2px solid var(--bg-canvas);color:#FFFFFF;font-size:11px;font-weight:700;display:flex;align-items:center;justify-content:center;">3</span>
            </div>
            <div class="avatar-ln" data-go="coach-profile" style="width:42px;height:42px;font-size:14px;cursor:pointer;" title="Hồ sơ Coach">LN</div>
          </div>

          <!-- _buildQuickActionDock: 4 nút squircle đối xứng chuẩn Member 1.1 -->
          <div class="quick-dock">
            <div class="quick-tile" data-go="coach-members">
              <img class="ico-dock" src="../../meta-gym/assets/svg/quick_actions/action_members.svg" alt="Học viên" />
              <div class="quick-lbl">Học viên</div>
            </div>
            <div class="quick-tile" data-go="coach-training">
              <img class="ico-dock" src="../../meta-gym/assets/svg/quick_actions/action_coach_plans.svg" alt="Giáo trình" />
              <div class="quick-lbl">Giáo trình</div>
            </div>
            <div class="quick-tile" data-go="coach-nutrition">
              <img class="ico-dock" src="../../meta-gym/assets/svg/quick_actions/action_nutrition.svg" alt="Dinh dưỡng" />
              <div class="quick-lbl">Dinh dưỡng</div>
            </div>
            <div class="quick-tile" data-go="coach-sessions">
              <img class="ico-dock" src="../../meta-gym/assets/svg/quick_actions/action_coach_sessions.svg" alt="Lịch dạy" />
              <div class="quick-lbl">Lịch dạy</div>
            </div>
          </div>

          <!-- _buildHeroSummaryCard (Warm Smoked Liquid Glass) -->
          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:10px;">
              <span class="txt-sm txt-bold">Tổng quan hôm nay</span>
              <span class="pill pill-success">● Đang nhận lịch</span>
            </div>
            <div class="grid-3" style="margin-bottom:10px;">
              <div class="metric-box" data-go="coach-sessions" style="text-align:center;padding:9px 4px;cursor:pointer;">
                <div class="tnum txt-bold" style="font-size:20px;line-height:1.15;">4</div>
                <div class="txt-xs" style="margin-top:2px;">Ca hôm nay</div>
              </div>
              <div class="metric-box" data-go="coach-members" style="text-align:center;padding:9px 4px;cursor:pointer;">
                <div class="tnum txt-bold txt-green" style="font-size:20px;line-height:1.15;">6/8</div>
                <div class="txt-xs" style="margin-top:2px;">Học viên</div>
              </div>
              <div class="metric-box" data-go="coach-workweek" style="text-align:center;padding:9px 4px;cursor:pointer;">
                <div class="tnum txt-bold txt-orange" style="font-size:20px;line-height:1.15;">6/7</div>
                <div class="txt-xs" style="margin-top:2px;">Ngày mở</div>
              </div>
            </div>
            <div class="day-bubble-row">
              <div class="day-bubble"><div class="day-dot done">✓</div><span>T2</span></div>
              <div class="day-bubble"><div class="day-dot done">✓</div><span>T3</span></div>
              <div class="day-bubble"><div class="day-dot active">4</div><span style="color:var(--primary);font-weight:700;">T4</span></div>
              <div class="day-bubble"><div class="day-dot done">3</div><span>T5</span></div>
              <div class="day-bubble"><div class="day-dot done">4</div><span>T6</span></div>
              <div class="day-bubble"><div class="day-dot done">2</div><span>T7</span></div>
              <div class="day-bubble"><div class="day-dot">–</div><span>CN</span></div>
            </div>
          </div>

          <!-- _buildNextSessionCard (Featured Liquid Glass đồng bộ Hôm nay của Member) -->
          <div class="card-liquid featured" data-go="coach-sessions" style="cursor:pointer;">
            <div class="row-between" style="margin-bottom:10px;">
              <div class="row" style="gap:6px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/quick_actions/action_coach_sessions.svg" alt="Ca tiếp theo" />
                <strong style="font-size:15px;">Ca dạy tiếp theo</strong>
              </div>
              <div class="row" style="gap:4px;">
                <span class="pill pill-orange tnum" style="padding:2px 8px;">18:00 – 19:30</span>
              </div>
            </div>
            <div class="row-between" style="gap:10px;">
              <div class="row" style="gap:10px;flex:1;min-width:0;">
                <div class="avatar-member" style="width:40px;height:40px;font-size:14px;">MQ</div>
                <div style="flex:1;min-width:0;">
                  <div style="font-size:16px;font-weight:700;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Nguyễn Minh Quân</div>
                  <div class="txt-xs tnum" style="margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Upper Body · Sức mạnh · 90 phút</div>
                </div>
              </div>
              <div style="min-width:86px;height:40px;padding:0 12px;border-radius:14px;background:var(--primary);color:#FFFFFF;font-size:12px;font-weight:700;display:flex;align-items:center;justify-content:center;flex-shrink:0;">Điểm danh</div>
            </div>
          </div>

          <!-- _buildBentoSection (2 cột cân đối chuẩn Member 1.1 — 100% khớp backend Coach V2) -->
          <div class="grid-2" style="margin-bottom:12px;">
            <div class="card-liquid" data-go="coach-booking-history" style="margin-bottom:0;min-height:126px;padding:12px;display:flex;flex-direction:column;cursor:pointer;">
              <div class="row" style="gap:5px;margin-bottom:6px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/progress/stats_chart_line.svg" alt="Lịch sử ca" />
                <strong style="font-size:12px;">Ca dạy hoàn thành</strong>
              </div>
              <div class="tnum" style="font-size:20px;font-weight:800;line-height:1.15;">142 ca</div>
              <div class="txt-xs" style="margin-top:2px;">Tổng hợp từ lịch Coach</div>
              <div style="margin-top:auto;">
                <div class="row-between" style="margin-bottom:4px;gap:4px;">
                  <span class="tnum" style="font-size:11px;font-weight:600;">4 hủy / vắng</span>
                  <span class="txt-orange" style="font-size:11px;font-weight:700;">Lịch sử ›</span>
                </div>
                <div class="prog-track" style="height:4px;margin-top:0;"><div class="prog-fill" style="width:97%;"></div></div>
              </div>
            </div>

            <div class="card-liquid" data-go="coach-members" style="margin-bottom:0;min-height:126px;padding:12px;display:flex;flex-direction:column;cursor:pointer;">
              <div class="row-between" style="margin-bottom:6px;gap:4px;">
                <div class="row" style="gap:4px;min-width:0;">
                  <img class="ico-sm" src="../../meta-gym/assets/svg/quick_actions/action_members.svg" alt="Hạn mức HV" />
                  <strong style="font-size:12px;white-space:nowrap;">Hạn mức 1:1</strong>
                </div>
                <span class="pill pill-success tnum" style="font-size:11px;padding:1px 6px;">Còn 2</span>
              </div>
              <div class="tnum" style="font-size:20px;font-weight:800;line-height:1.15;">6 / 8 HV</div>
              <div class="txt-xs" style="margin-top:2px;">Giới hạn chất lượng Meta Gym</div>
              <div style="margin-top:auto;">
                <div class="row-between" style="margin-bottom:4px;gap:4px;">
                  <span class="tnum" style="font-size:11px;color:var(--text-secondary);">5 hiệu lực · 1 sắp hết</span>
                  <span class="txt-orange" style="font-size:11px;font-weight:700;">Hội viên ›</span>
                </div>
                <div class="prog-track" style="height:4px;margin-top:0;"><div class="prog-fill orange" style="width:75%;"></div></div>
              </div>
            </div>
          </div>

          <!-- _buildManagementCard -->
          <div class="sec-head">
            <h3 class="row" style="gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/quick_actions/action_coach_workweek.svg" alt="Quản lý" /><span>Quản lý &amp; Thiết lập</span></h3>
          </div>
          <div class="card-liquid" style="padding:4px 14px;">
            <div class="row-between" data-go="coach-members" style="padding:11px 0;cursor:pointer;">
              <div class="row" style="gap:10px;min-width:0;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/quick_actions/action_members.svg" alt="Hội viên" />
                <div style="min-width:0;"><div class="txt-sm txt-bold">Hội viên của tôi</div><div class="txt-xs tnum">6/8 hội viên · 1 yêu cầu cần phản hồi</div></div>
              </div>
              <span class="txt-xs">›</span>
            </div>
            <div class="divider" style="margin:0;"></div>
            <div class="row-between" data-go="coach-workweek" style="padding:11px 0;cursor:pointer;">
              <div class="row" style="gap:10px;min-width:0;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/quick_actions/action_coach_workweek.svg" alt="Lịch tuần" />
                <div style="min-width:0;"><div class="txt-sm txt-bold">Lịch làm việc cố định theo tuần</div><div class="txt-xs tnum">Đang mở 6/7 ngày · Khung 90 phút</div></div>
              </div>
              <span class="txt-xs">›</span>
            </div>
            <div class="divider" style="margin:0;"></div>
            <div class="row-between" data-go="coach-blocked-slots" style="padding:11px 0;cursor:pointer;">
              <div class="row" style="gap:10px;min-width:0;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/quick_actions/action_coach_block_slot.svg" alt="Chặn giờ" />
                <div style="min-width:0;"><div class="txt-sm txt-bold">Chặn khung giờ bận</div><div class="txt-xs tnum">Đã khóa 2 khung giờ tuần này</div></div>
              </div>
              <span class="txt-xs">›</span>
            </div>
            <div class="divider" style="margin:0;"></div>
            <div class="row-between" data-go="coach-booking-history" style="padding:11px 0;cursor:pointer;">
              <div class="row" style="gap:10px;min-width:0;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/setting/time_clock.svg" alt="Lịch sử" />
                <div style="min-width:0;"><div class="txt-sm txt-bold">Lịch sử buổi dạy</div><div class="txt-xs tnum">142 buổi hoàn thành · Thống kê ca</div></div>
              </div>
              <span class="txt-xs">›</span>
            </div>
          </div>

          <!-- _buildTodayBookingsSection -->
          <div class="sec-head">
            <h3>Lịch dạy hôm nay</h3>
            <span class="sec-link" data-go="coach-sessions" style="cursor:pointer;">Xem tất cả ›</span>
          </div>
          <div class="card-liquid" data-go="coach-member-detail" style="padding:12px 14px;cursor:pointer;">
            <div class="row-between" style="gap:8px;">
              <div style="min-width:0;">
                <div class="txt-sm txt-bold">Nguyễn Minh Quân</div>
                <div class="txt-xs tnum" style="margin-top:2px;">18:00 – 19:30 · Upper Body &amp; Sức mạnh</div>
              </div>
              <span class="pill pill-orange">Sắp tới</span>
            </div>
          </div>
          <div class="card-liquid" data-go="coach-member-detail" style="padding:12px 14px;cursor:pointer;">
            <div class="row-between" style="gap:8px;">
              <div style="min-width:0;">
                <div class="txt-sm txt-bold">Trần Thảo Vy</div>
                <div class="txt-xs tnum" style="margin-top:2px;">19:45 – 21:15 · Glutes &amp; Core</div>
              </div>
              <span class="pill pill-success">Đã đặt</span>
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
    id: 'coach-members',
    group: 'coach-tab1-home',
    groupLabel: '1. Trang chủ & Học viên',
    title: '1.2 Hội viên của tôi',
    shortFile: 'coach_members_page.dart',
    flutterFile: 'mobile-app/lib/features/coaching/presentation/coach_members_page.dart',
    tag: 'P1 • Quản lý HV',
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

          <!-- _MembersOverviewHero -->
          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:10px;">
              <div class="row" style="gap:8px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/quick_actions/action_members.svg" alt="Công suất" />
                <strong class="txt-sm">Công suất phụ trách 1:1</strong>
              </div>
              <span class="pill pill-success tnum">6 / 8 suất</span>
            </div>
            <div class="grid-3" style="margin-bottom:10px;">
              <div class="metric-box" style="text-align:center;padding:8px 4px;">
                <div class="tnum txt-bold txt-green" style="font-size:20px;">5</div>
                <div class="txt-xs">Hiệu lực</div>
              </div>
              <div class="metric-box" style="text-align:center;padding:8px 4px;">
                <div class="tnum txt-bold txt-warn" style="font-size:20px;">1</div>
                <div class="txt-xs">Sắp hết</div>
              </div>
              <div class="metric-box" style="text-align:center;padding:8px 4px;">
                <div class="tnum txt-bold txt-orange" style="font-size:20px;">2</div>
                <div class="txt-xs">Suất trống</div>
              </div>
            </div>
            <div class="row-between" style="margin-bottom:4px;">
              <span class="txt-xs">Giới hạn chất lượng Meta Gym</span>
              <span class="txt-xs txt-bold tnum">75%</span>
            </div>
            <div class="prog-track" style="height:5px;margin-top:0;"><div class="prog-fill orange" style="width:75%;"></div></div>
          </div>

          <div class="filter-row">
            <div class="filter-pill active" data-filter-cat="all">Tất cả (6)</div>
            <div class="filter-pill" data-filter-cat="active">Hiệu lực (5)</div>
            <div class="filter-pill" data-filter-cat="expiring">Sắp hết buổi (1)</div>
            <div class="filter-pill" data-filter-cat="pending">Chờ xử lý (1)</div>
          </div>

          <div class="sec-head" style="margin-top:6px;">
            <h3>Đang phụ trách</h3>
            <span class="txt-xs tnum">Chạm để xem hồ sơ</span>
          </div>

          <div class="card-liquid" data-filter-item="active" data-go="coach-member-detail" style="padding:13px;cursor:pointer;">
            <div class="row" style="gap:11px;">
              <div class="avatar-member" style="width:42px;height:42px;font-size:14px;">MQ</div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong class="txt-sm">Nguyễn Minh Quân</strong>
                  <span class="pill pill-success">Hiệu lực</span>
                </div>
                <div class="txt-xs tnum" style="margin-top:2px;">Còn 14/24 buổi · Tăng cơ Hypertrophy</div>
                <div class="prog-track" style="height:4px;margin-top:7px;"><div class="prog-fill" style="width:58%;"></div></div>
              </div>
              <span class="txt-xs">›</span>
            </div>
          </div>

          <div class="card-liquid" data-filter-item="active" data-go="coach-member-detail" style="padding:13px;cursor:pointer;">
            <div class="row" style="gap:11px;">
              <div class="avatar-member" style="width:42px;height:42px;font-size:14px;background:linear-gradient(135deg,#2ECC71,#1D63B8);">TV</div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong class="txt-sm">Trần Thảo Vy</strong>
                  <span class="pill pill-success">Hiệu lực</span>
                </div>
                <div class="txt-xs tnum" style="margin-top:2px;">Còn 6/12 buổi · Giảm mỡ &amp; Core</div>
                <div class="prog-track" style="height:4px;margin-top:7px;"><div class="prog-fill" style="width:50%;"></div></div>
              </div>
              <span class="txt-xs">›</span>
            </div>
          </div>

          <div class="card-liquid" data-filter-item="expiring" data-go="coach-member-detail" style="padding:13px;cursor:pointer;">
            <div class="row" style="gap:11px;">
              <div class="avatar-member" style="width:42px;height:42px;font-size:14px;background:linear-gradient(135deg,#F39C12,#D9431E);">PB</div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong class="txt-sm">Phạm Quốc Bảo</strong>
                  <span class="pill pill-warning">Còn 2 buổi</span>
                </div>
                <div class="txt-xs tnum" style="margin-top:2px;">Còn 2/12 buổi · Sức mạnh Powerbuilding</div>
                <div class="prog-track" style="height:4px;margin-top:7px;"><div class="prog-fill orange" style="width:84%;"></div></div>
              </div>
              <span class="txt-xs">›</span>
            </div>
          </div>

          <!-- EarlyTerminationCard (72h Mutual Termination) -->
          <div class="sec-head" data-filter-item="pending">
            <h3>Yêu cầu ngừng phụ trách</h3>
            <span class="pill pill-warning tnum">1 chờ phản hồi</span>
          </div>
          <div class="card-liquid" data-filter-item="pending" style="padding:14px;border-color:rgba(243,156,18,0.52);">
            <div class="row-between" style="margin-bottom:6px;">
              <span class="pill pill-warning tnum">Hạn phản hồi: 58h</span>
              <span class="txt-xs">Gửi bởi: Hội viên</span>
            </div>
            <div class="txt-sm txt-bold">Đỗ Khánh Linh · Gói 12 buổi</div>
            <div class="txt-xs" style="color:var(--text-warm-muted);margin:4px 0 10px;line-height:1.45;">
              "Em phải đi công tác dài ngày ngoài tỉnh 2 tháng nên xin kết thúc sớm gói Coach hiện tại."
            </div>
            <div class="grid-2" style="gap:8px;">
              <button type="button" class="btn-secondary" style="height:40px;color:var(--error);border-color:rgba(241,91,100,0.45);" data-open-coach-modal="term-reject">Từ chối</button>
              <button type="button" class="btn-primary" style="height:40px;font-size:14px;" data-open-coach-modal="term-accept">Chấp nhận</button>
            </div>
          </div>
        </div>

        <!-- Level 3 Modal: Từ chối ngừng phụ trách (chuyển Admin phân xử) -->
        <div class="qr-overlay" data-coach-modal="term-reject">
          <div class="qr-sheet" style="text-align:left;">
            <div class="row" style="gap:10px;margin-bottom:10px;">
              <div style="width:40px;height:40px;border-radius:12px;background:rgba(241,91,100,0.16);border:1px solid rgba(241,91,100,0.42);display:flex;align-items:center;justify-content:center;flex-shrink:0;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/coaching/coaching_termination.svg" alt="Từ chối" />
              </div>
              <div style="min-width:0;">
                <div style="font-size:16px;font-weight:800;">Từ chối yêu cầu kết thúc sớm?</div>
                <div class="txt-xs" style="color:var(--text-warm-muted);margin-top:2px;">Đỗ Khánh Linh · Gói 12 buổi</div>
              </div>
            </div>
            <div class="txt-xs" style="color:var(--text-warm-muted);line-height:1.45;margin-bottom:10px;">
              Khi Coach từ chối, yêu cầu sẽ tự động chuyển sang trạng thái <strong>Tranh chấp</strong> để Admin xem xét và phân xử.
            </div>
            <div class="field">
              <label>Lý do phản hồi gửi Admin &amp; học viên *</label>
              <div class="input-box" style="height:64px;align-items:flex-start;padding-top:10px;font-size:14px;">Đề nghị bảo lưu gói thay vì hủy ngang vì đã xếp lịch cố định.</div>
            </div>
            <div class="grid-2" style="gap:10px;">
              <button type="button" class="btn-secondary" style="height:44px;" data-close-coach-modal>Đóng</button>
              <button type="button" class="btn-primary" style="height:44px;background:#E5484D;border-color:#F15B64;" data-close-coach-modal data-coach-toast="Đã gửi phản hồi từ chối &amp; chuyển Admin phân xử">Xác nhận từ chối</button>
            </div>
          </div>
        </div>

        <!-- Level 3 Modal: Chấp nhận kết thúc sớm -->
        <div class="qr-overlay" data-coach-modal="term-accept">
          <div class="qr-sheet" style="text-align:left;">
            <div style="font-size:16px;font-weight:800;margin-bottom:6px;">Chấp nhận ngừng phụ trách?</div>
            <div class="txt-xs" style="color:var(--text-warm-muted);line-height:1.5;margin-bottom:10px;">
              Quan hệ phụ trách với <strong>Đỗ Khánh Linh</strong> sẽ kết thúc ngay, giải phóng 1 suất học viên và hủy các lịch đặt tương lai.
            </div>
            <div class="field">
              <label>Ghi chú phản hồi (không bắt buộc)</label>
              <div class="input-box" style="height:56px;align-items:flex-start;padding-top:10px;font-size:14px;">Chúc em công tác thuận lợi, hẹn gặp lại tại Meta Gym!</div>
            </div>
            <div class="grid-2" style="gap:10px;">
              <button type="button" class="btn-secondary" style="height:44px;" data-close-coach-modal>Quay lại</button>
              <button type="button" class="btn-primary" style="height:44px;" data-close-coach-modal data-coach-toast="Đã chấp nhận kết thúc sớm gói Coach">Xác nhận chấp nhận</button>
            </div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'coach-member-detail',
    group: 'coach-tab1-home',
    groupLabel: '1. Trang chủ & Học viên',
    title: '1.3 Hồ sơ hội viên (Chi tiết)',
    shortFile: 'coach_member_detail_page.dart',
    flutterFile: 'mobile-app/lib/features/coaching/presentation/coach_member_detail_page.dart',
    tag: 'P1 • 1.085 dòng',
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
              <div class="mg-eyebrow">HỒ SƠ HỘI VIÊN</div>
              <div class="mg-title">Nguyễn Minh Quân</div>
            </div>
            <div class="circle-btn" data-go="coach-chat-detail" title="Nhắn tin hội viên"><img class="ico-md" src="../../meta-gym/assets/svg/community/comm_chat.svg" alt="Nhắn tin" /></div>
          </div>

          <!-- _MemberHeroCard -->
          <div class="card-warm-glass">
            <div class="row" style="gap:12px;margin-bottom:12px;">
              <div class="avatar-member" style="width:52px;height:52px;font-size:18px;">MQ</div>
              <div style="flex:1;min-width:0;">
                <div class="row-between" style="gap:6px;">
                  <strong style="font-size:16px;">Nguyễn Minh Quân</strong>
                  <span class="pill pill-success">Hiệu lực</span>
                </div>
                <div class="txt-xs" style="color:var(--text-warm-muted);margin-top:2px;">Mục tiêu: Tăng cơ giảm mỡ · 4 buổi/tuần</div>
              </div>
            </div>
            <div class="grid-2" style="margin-bottom:12px;">
              <div class="metric-box">
                <div class="txt-xs">Buổi PT còn lại</div>
                <div class="tnum txt-bold" style="font-size:20px;margin-top:2px;">14 / 24</div>
              </div>
              <div class="metric-box">
                <div class="txt-xs">Hết hạn gói</div>
                <div class="tnum txt-bold" style="font-size:20px;margin-top:2px;">03/01/27</div>
              </div>
            </div>
            <div class="grid-3" style="gap:8px;">
              <button type="button" class="btn-secondary" data-go="coach-member-plans" style="height:38px;font-size:12px;padding:0 6px;">Giáo trình</button>
              <button type="button" class="btn-secondary" data-go="coach-meal-plan" style="height:38px;font-size:12px;padding:0 6px;">Dinh dưỡng</button>
              <button type="button" class="btn-primary" data-go="coach-chat-detail" style="height:38px;font-size:12px;padding:0 6px;">Nhắn tin</button>
            </div>
          </div>

          <!-- _HealthDeclarationCard -->
          <div class="card-liquid" style="padding:14px;">
            <div class="row-between" style="margin-bottom:10px;">
              <div class="row" style="gap:7px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/coaching/health_shield.svg" alt="Thể trạng" />
                <strong class="txt-sm">Khai báo thể trạng &amp; Y tế</strong>
              </div>
              <span class="pill pill-success tnum">BMI 23.9</span>
            </div>
            <div class="grid-3" style="margin-bottom:10px;">
              <div class="metric-box" style="text-align:center;padding:8px 4px;">
                <div class="txt-xs">Chiều cao</div>
                <div class="tnum txt-bold" style="font-size:15px;margin-top:2px;">174 cm</div>
              </div>
              <div class="metric-box" style="text-align:center;padding:8px 4px;">
                <div class="txt-xs">Cân nặng</div>
                <div class="tnum txt-bold" style="font-size:15px;margin-top:2px;">72.4 kg</div>
              </div>
              <div class="metric-box" style="text-align:center;padding:8px 4px;">
                <div class="txt-xs">Tỷ lệ mỡ</div>
                <div class="tnum txt-bold" style="font-size:15px;margin-top:2px;">16.8%</div>
              </div>
            </div>
            <div class="metric-box" style="border-color:rgba(243,156,18,0.45);padding:10px 12px;">
              <div class="row" style="gap:7px;align-items:flex-start;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/coaching/health_injury.svg" alt="Chấn thương" />
                <div style="flex:1;min-width:0;">
                  <div class="txt-xs txt-warn txt-bold">Lưu ý chấn thương</div>
                  <div class="txt-xs" style="color:var(--text-primary);margin-top:2px;line-height:1.4;">Đau nhẹ khớp vai phải khi đẩy tạ nặng trên 80 kg. Không có bệnh nền tim mạch.</div>
                </div>
              </div>
            </div>
          </div>

          <!-- Thành quả học viên (_CreateOutcomeDialog + DELETE /coach/outcomes/:id) -->
          <div class="sec-head">
            <h3 class="row" style="gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/coaching/outcome_consent_badge.svg" alt="Thành quả" /><span>Thành quả học viên</span></h3>
            <span class="btn-mini-orange" data-open-coach-modal="outcome" style="cursor:pointer;">+ Gửi thành quả</span>
          </div>
          <div class="card-liquid" style="padding:13px;">
            <div class="row-between" style="margin-bottom:4px;">
              <strong class="txt-sm">Giảm 3.2 kg mỡ sau 6 tuần</strong>
              <span class="pill pill-success">Đã duyệt</span>
            </div>
            <div class="txt-xs tnum" style="margin-bottom:4px;">75.6 kg → 72.4 kg · Mỡ 18.9% → 16.8% · Kèm ảnh Before/After</div>
            <div class="txt-xs" style="color:var(--text-warm-muted);line-height:1.4;">Học viên đã đồng ý chia sẻ công khai trên hồ sơ Coach · 18/11/2026</div>
          </div>

          <div class="card-liquid" style="padding:13px;">
            <div class="row-between" style="margin-bottom:4px;gap:6px;">
              <strong class="txt-sm">Tăng sức bền &amp; kiểm soát form vai</strong>
              <div class="row" style="gap:6px;">
                <span class="pill pill-warning">Chờ HV duyệt</span>
                <button type="button" style="background:none;border:none;padding:2px;cursor:pointer;" data-coach-toast="Đã xóa bản ghi thành quả chờ duyệt" title="Xóa thành quả">
                  <img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" />
                </button>
              </div>
            </div>
            <div class="txt-xs tnum" style="color:var(--text-warm-muted);line-height:1.4;">4 tuần · 74.0 kg → 72.4 kg · Đang chờ học viên xác nhận</div>
          </div>

          <!-- Yêu cầu ngừng phụ trách sớm -->
          <div class="card-liquid" data-open-coach-modal="termination" style="padding:13px;text-align:center;border-color:rgba(241,91,100,0.42);cursor:pointer;">
            <span class="row" style="justify-content:center;gap:7px;color:var(--error);font-weight:700;font-size:14px;">
              <img class="ico-sm" src="../../meta-gym/assets/svg/coaching/coaching_termination.svg" alt="Ngừng phụ trách" />
              <span>Xin ngừng phụ trách sớm</span>
            </span>
          </div>
        </div>

        <!-- Level 3 Modal: Gửi thành quả học viên -->
        <div class="qr-overlay" data-coach-modal="outcome">
          <div class="qr-sheet" style="text-align:left;">
            <div class="row" style="gap:10px;margin-bottom:10px;">
              <div style="width:40px;height:40px;border-radius:12px;background:rgba(255,94,54,0.16);border:1px solid rgba(255,94,54,0.42);display:flex;align-items:center;justify-content:center;flex-shrink:0;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/coaching/outcome_consent_badge.svg" alt="Thành quả" />
              </div>
              <div>
                <div style="font-size:16px;font-weight:800;">Gửi thành quả học viên</div>
                <div class="txt-xs">Học viên cần duyệt trước khi hiển thị công khai</div>
              </div>
            </div>
            <div class="field">
              <label>Tiêu đề thành quả</label>
              <div class="input-box" style="font-size:14px;">Tăng 15 kg Bench Press sau 8 tuần</div>
            </div>
            <div class="field">
              <label>Tóm tắt kết quả</label>
              <div class="input-box" style="height:68px;align-items:flex-start;padding-top:10px;font-size:14px;">Cải thiện kỹ thuật giữ vai, tỷ lệ mỡ giảm từ 18.5% xuống 16.8%.</div>
            </div>
            <div class="grid-2" style="gap:10px;margin-top:12px;">
              <button type="button" class="btn-secondary" style="height:44px;" data-close-coach-modal>Đóng</button>
              <button type="button" class="btn-primary" style="height:44px;" data-close-coach-modal data-coach-toast="Đã gửi thành quả chờ học viên duyệt">Gửi duyệt</button>
            </div>
          </div>
        </div>

        <!-- Level 3 Modal: Xin ngừng phụ trách sớm (72h) -->
        <div class="qr-overlay" data-coach-modal="termination">
          <div class="qr-sheet" style="text-align:left;">
            <div class="row" style="gap:10px;margin-bottom:10px;">
              <div style="width:40px;height:40px;border-radius:12px;background:rgba(241,91,100,0.16);border:1px solid rgba(241,91,100,0.42);display:flex;align-items:center;justify-content:center;flex-shrink:0;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/coaching/coaching_termination.svg" alt="Kết thúc sớm" />
              </div>
              <div style="font-size:16px;font-weight:800;">Xin ngừng phụ trách?</div>
            </div>
            <div class="txt-xs" style="color:var(--text-warm-muted);line-height:1.5;margin-bottom:12px;">
              Yêu cầu sẽ gửi tới hội viên với thời hạn phản hồi 72 giờ. Nếu hội viên từ chối hoặc quá hạn, hệ thống tự chuyển Admin phân xử.
            </div>
            <div class="field">
              <label>Lý do ngừng phụ trách</label>
              <div class="input-box" style="height:74px;align-items:flex-start;padding-top:10px;font-size:14px;color:var(--text-secondary);">Nhập lý do cụ thể gửi tới học viên...</div>
            </div>
            <div class="grid-2" style="gap:10px;">
              <button type="button" class="btn-secondary" style="height:44px;" data-close-coach-modal>Quay lại</button>
              <button type="button" class="btn-primary" style="height:44px;" data-close-coach-modal data-coach-toast="Đã gửi yêu cầu ngừng phụ trách (hạn 72h)">Gửi yêu cầu</button>
            </div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'coach-notifications',
    group: 'coach-tab1-home',
    groupLabel: '1. Trang chủ & Học viên',
    title: '1.4 Thông báo Coach',
    shortFile: 'coach_notifications_page.dart (Coach)',
    flutterFile: 'mobile-app/lib/features/coaching/presentation/coach_notifications_page.dart',
    tag: 'P2 • Thông báo',
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
              <div class="mg-title">Thông báo</div>
            </div>
            <span class="sec-link" data-coach-toast="Đã đánh dấu tất cả thông báo đã đọc" style="cursor:pointer;white-space:nowrap;">Đọc tất cả</span>
          </div>

          <!-- Dải tóm tắt đồng bộ Member 5.10 -->
          <div class="card-liquid" style="padding:10px 12px;">
            <div class="grid-2">
              <div class="metric-box" style="padding:8px 10px;">
                <div class="txt-xs">Chưa đọc</div>
                <div class="tnum txt-bold txt-orange" style="font-size:20px;margin-top:2px;">3</div>
              </div>
              <div class="metric-box" style="padding:8px 10px;">
                <div class="txt-xs">Tổng tuần này</div>
                <div class="tnum txt-bold" style="font-size:20px;margin-top:2px;">18</div>
              </div>
            </div>
          </div>

          <div class="filter-row">
            <div class="filter-pill active" data-filter-cat="all">Tất cả</div>
            <div class="filter-pill" data-filter-cat="unread">Chưa đọc (3)</div>
            <div class="filter-pill" data-filter-cat="schedule">Lịch dạy</div>
            <div class="filter-pill" data-filter-cat="member">Học viên</div>
          </div>

          <div class="sec-head" style="margin-top:6px;">
            <h3>Hôm nay</h3>
            <span class="pill pill-orange tnum">3 chưa đọc</span>
          </div>

          <div class="card-liquid" data-filter-item="unread schedule" data-go="coach-sessions" style="padding:13px;border-color:rgba(255,94,54,0.48);cursor:pointer;">
            <div class="row" style="gap:10px;align-items:flex-start;">
              <div class="quick-ico"><img class="ico-sm" src="../../meta-gym/assets/svg/quick_actions/action_coach_sessions.svg" alt="Lịch mới" /></div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong class="txt-sm">Lịch tập 1:1 mới được đặt</strong>
                  <span class="txt-xs tnum txt-orange">10 phút</span>
                </div>
                <div class="txt-xs" style="color:var(--text-warm-muted);margin-top:3px;line-height:1.4;">Nguyễn Minh Quân vừa đặt khung 18:00 – 19:30 ngày T6, 27/11.</div>
              </div>
            </div>
          </div>

          <div class="card-liquid" data-filter-item="unread member" data-go="coach-members" style="padding:13px;border-color:rgba(243,156,18,0.52);cursor:pointer;">
            <div class="row" style="gap:10px;align-items:flex-start;">
              <div class="quick-ico" style="background:rgba(243,156,18,0.16);"><img class="ico-sm" src="../../meta-gym/assets/svg/coaching/coaching_termination.svg" alt="Kết thúc sớm" /></div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong class="txt-sm">Yêu cầu ngừng phụ trách (72h)</strong>
                  <span class="txt-xs tnum txt-warn">1 giờ</span>
                </div>
                <div class="txt-xs" style="color:var(--text-warm-muted);margin-top:3px;line-height:1.4;">Đỗ Khánh Linh gửi yêu cầu kết thúc sớm gói 12 buổi · Hạn phản hồi 58h.</div>
              </div>
            </div>
          </div>

          <div class="card-liquid" data-filter-item="unread member" data-go="coach-member-detail" style="padding:13px;border-color:rgba(46,204,113,0.45);cursor:pointer;">
            <div class="row" style="gap:10px;align-items:flex-start;">
              <div class="quick-ico" style="background:rgba(46,204,113,0.16);"><img class="ico-sm" src="../../meta-gym/assets/svg/coaching/outcome_consent_badge.svg" alt="Duyệt thành quả" /></div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong class="txt-sm">Học viên đã duyệt thành quả</strong>
                  <span class="txt-xs tnum txt-green">3 giờ</span>
                </div>
                <div class="txt-xs" style="color:var(--text-warm-muted);margin-top:3px;line-height:1.4;">Nguyễn Minh Quân đồng ý công khai kết quả "Giảm 3.2 kg mỡ sau 6 tuần".</div>
              </div>
            </div>
          </div>

          <div class="sec-head">
            <h3>Trước đó</h3>
          </div>

          <div class="card-liquid" data-filter-item="member" data-go="coach-members" style="padding:13px;opacity:0.86;cursor:pointer;">
            <div class="row" style="gap:10px;align-items:flex-start;">
              <div class="quick-ico" style="background:rgba(142,149,165,0.16);"><img class="ico-sm" src="../../meta-gym/assets/svg/coaching/coach_pkg_intensive.svg" alt="Gói mới" /></div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong class="txt-sm">Gói 24 buổi mới được kích hoạt</strong>
                  <span class="txt-xs tnum">Hôm qua</span>
                </div>
                <div class="txt-xs" style="margin-top:3px;line-height:1.4;">Trần Thảo Vy đã thanh toán gói Tiêu chuẩn 12 buổi thành công.</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    `
  }
]);
