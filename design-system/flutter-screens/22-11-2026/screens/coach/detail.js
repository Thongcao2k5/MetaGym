// Meta Gym Flutter Mockups — COACH / 2. Lịch dạy & 3. Giáo án tập luyện (Tách riêng khỏi Dinh dưỡng)
window.METAGYM_SCREENS = window.METAGYM_SCREENS || {};
window.METAGYM_SCREENS.coach = (window.METAGYM_SCREENS.coach || []).concat([
  // ===========================================================================
  // 2. LỊCH DẠY (QUẢN LÝ CA TẬP, LỊCH TUẦN, CHẶN GIỜ, LỊCH SỬ)
  // ===========================================================================
  {
    id: 'coach-sessions',
    group: 'coach-tab2-schedule',
    groupLabel: '2. Lịch dạy',
    title: '2.1 Lịch dạy &amp; Buổi hẹn',
    shortFile: 'coach_sessions_page.dart',
    flutterFile: 'mobile-app/lib/features/sessions/presentation/coach_sessions_page.dart',
    tag: 'P0 • Điểm danh ca',
    tagClass: 'p0',
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
              <div class="txt-xs" style="color:var(--text-warm-muted);">Quản lý ca 1:1 &amp; điểm danh</div>
            </div>
            <div class="circle-btn" data-go="coach-notifications" title="Thông báo"><img class="ico-md" src="../../meta-gym/assets/svg/setting/setting_notifications_bell.svg" alt="Thông báo" /></div>
            <div class="circle-btn" data-go="coach-booking-history" title="Lịch sử buổi dạy"><img class="ico-md" src="../../meta-gym/assets/svg/setting/time_clock.svg" alt="Lịch sử" /></div>
          </div>

          <div class="seg-tabs">
            <div class="seg-tab active" data-state-btn="today">Hôm nay</div>
            <div class="seg-tab" data-state-btn="upcoming">Sắp tới</div>
            <div class="seg-tab" data-state-btn="done">Đã xong</div>
            <div class="seg-tab" data-state-btn="cancelled">Đã hủy</div>
          </div>

          <!-- Banner cấu hình lịch làm việc tuần & chặn khung bận -->
          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:6px;">
              <div class="row" style="gap:7px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/quick_actions/action_coach_workweek.svg" alt="Lịch tuần" />
                <strong class="txt-sm">Lịch làm việc hằng tuần</strong>
              </div>
              <span class="pill pill-success tnum">6/7 ngày</span>
            </div>
            <div class="txt-xs" style="color:var(--text-warm-muted);margin-bottom:10px;">Khung 90 phút · Đang khóa 2 khung giờ bận tuần này</div>
            <div class="grid-2" style="gap:8px;">
              <button type="button" class="btn-primary" data-go="coach-workweek" style="height:40px;font-size:14px;">Lịch tuần</button>
              <button type="button" class="btn-secondary" data-go="coach-blocked-slots" style="height:40px;font-size:14px;">Chặn khung giờ</button>
            </div>
          </div>

          <!-- Trạng thái 1: Hôm nay -->
          <div data-state-pane="today">
            <div class="sec-head">
              <h3>Buổi hẹn hôm nay (2)</h3>
              <span class="sec-link" data-go="coach-booking-history" style="cursor:pointer;">Lịch sử ›</span>
            </div>

            <!-- Ca dạy 1: Hôm nay — Điểm danh trực tiếp -->
            <div class="card-liquid featured" style="padding:14px;">
              <div class="row-between" style="margin-bottom:8px;">
                <span class="pill pill-orange tnum">Hôm nay · 18:00 – 19:30</span>
                <span class="pill pill-success">Đã lên lịch</span>
              </div>
              <div class="row" style="gap:10px;margin-bottom:10px;cursor:pointer;" data-go="coach-member-detail">
                <div class="avatar-member" style="width:38px;height:38px;font-size:14px;">MQ</div>
                <div style="flex:1;min-width:0;">
                  <div class="txt-sm txt-bold">Nguyễn Minh Quân</div>
                  <div class="txt-xs tnum">Upper Body · Sức mạnh · Buổi 11/24</div>
                </div>
                <span class="txt-xs">›</span>
              </div>
              <div class="grid-3" style="gap:6px;">
                <button type="button" class="btn-secondary" style="height:38px;font-size:12px;padding:0 6px;color:var(--error);border-color:rgba(241,91,100,0.42);" data-open-coach-modal="cancel-session">Hủy ca</button>
                <button type="button" class="btn-secondary" style="height:38px;font-size:12px;padding:0 6px;color:var(--warning);border-color:rgba(243,156,18,0.45);" data-coach-toast="Đã đánh dấu hội viên vắng mặt">HV vắng</button>
                <button type="button" class="btn-primary" style="height:38px;font-size:12px;padding:0 6px;" data-coach-toast="Đã hoàn thành ca dạy &amp; trừ 1 buổi PT">Hoàn thành</button>
              </div>
            </div>

            <!-- Ca dạy 2: Hôm nay -->
            <div class="card-liquid" data-open-coach-modal="session-detail" style="padding:14px;cursor:pointer;">
              <div class="row-between" style="margin-bottom:6px;">
                <span class="pill pill-muted tnum">Hôm nay · 19:45 – 21:15</span>
                <span class="pill pill-success">Đã lên lịch</span>
              </div>
              <div class="row-between">
                <div style="min-width:0;">
                  <div class="txt-sm txt-bold">Trần Thảo Vy</div>
                  <div class="txt-xs tnum" style="margin-top:2px;">Glutes &amp; Core · Giảm mỡ · Chạm để điểm danh</div>
                </div>
                <span class="txt-xs">›</span>
              </div>
            </div>
          </div>

          <!-- Trạng thái 2: Sắp tới (Các ngày tới) -->
          <div data-state-pane="upcoming" style="display:none;">
            <div class="sec-head">
              <h3>Buổi hẹn sắp tới (2)</h3>
              <span class="sec-link" data-go="coach-booking-history" style="cursor:pointer;">Lịch sử ›</span>
            </div>

            <div class="card-liquid" data-open-coach-modal="session-detail" style="padding:14px;cursor:pointer;">
              <div class="row-between" style="margin-bottom:6px;">
                <span class="pill pill-muted tnum">T5, 27/11 · 07:30 – 09:00</span>
                <span class="pill pill-success">Đã lên lịch</span>
              </div>
              <div class="row-between">
                <div style="min-width:0;">
                  <div class="txt-sm txt-bold">Phạm Quốc Bảo</div>
                  <div class="txt-xs tnum" style="margin-top:2px;">Lower Body · Powerbuilding · Buổi 11/12</div>
                </div>
                <span class="txt-xs">›</span>
              </div>
            </div>

            <div class="card-liquid" data-open-coach-modal="session-detail" style="padding:14px;cursor:pointer;">
              <div class="row-between" style="margin-bottom:6px;">
                <span class="pill pill-muted tnum">T6, 28/11 · 18:00 – 19:30</span>
                <span class="pill pill-success">Đã lên lịch</span>
              </div>
              <div class="row-between">
                <div style="min-width:0;">
                  <div class="txt-sm txt-bold">Nguyễn Minh Quân</div>
                  <div class="txt-xs tnum" style="margin-top:2px;">Pull &amp; Core · Hypertrophy · Buổi 12/24</div>
                </div>
                <span class="txt-xs">›</span>
              </div>
            </div>
          </div>

          <!-- Trạng thái 3: Đã xong -->
          <div data-state-pane="done" style="display:none;">
            <div class="sec-head">
              <h3>Ca dạy đã xong (142)</h3>
              <span class="sec-link" data-go="coach-booking-history" style="cursor:pointer;">Xem tất cả ›</span>
            </div>

            <div class="card-liquid" data-go="coach-member-detail" style="padding:14px;cursor:pointer;">
              <div class="row-between" style="margin-bottom:6px;">
                <span class="pill pill-muted tnum">T4, 25/11 · 18:00 – 19:30</span>
                <span class="pill pill-success">Đã hoàn thành</span>
              </div>
              <div class="txt-sm txt-bold">Nguyễn Minh Quân</div>
              <div class="txt-xs tnum" style="margin-top:2px;">Upper Body &amp; Core · Đã trừ 1 buổi PT</div>
            </div>

            <div class="card-liquid" data-go="coach-member-detail" style="padding:14px;cursor:pointer;">
              <div class="row-between" style="margin-bottom:6px;">
                <span class="pill pill-muted tnum">T3, 24/11 · 19:45 – 21:15</span>
                <span class="pill pill-success">Đã hoàn thành</span>
              </div>
              <div class="txt-sm txt-bold">Trần Thảo Vy</div>
              <div class="txt-xs tnum" style="margin-top:2px;">Glutes &amp; Core · Đã trừ 1 buổi PT</div>
            </div>
          </div>

          <!-- Trạng thái 4: Đã hủy / HV vắng -->
          <div data-state-pane="cancelled" style="display:none;">
            <div class="sec-head">
              <h3>Ca dạy đã hủy (4)</h3>
              <span class="sec-link" data-go="coach-booking-history" style="cursor:pointer;">Xem tất cả ›</span>
            </div>

            <div class="card-liquid" data-go="coach-member-detail" style="padding:14px;cursor:pointer;">
              <div class="row-between" style="margin-bottom:6px;">
                <span class="pill pill-muted tnum">T2, 23/11 · 17:00 – 18:30</span>
                <span class="pill pill-warning">Hội viên vắng</span>
              </div>
              <div class="txt-sm txt-bold">Đỗ Khánh Linh</div>
              <div class="txt-xs tnum" style="margin-top:2px;">Full Body · Đã ghi nhận vắng mặt</div>
            </div>

            <div class="card-liquid" data-go="coach-member-detail" style="padding:14px;cursor:pointer;">
              <div class="row-between" style="margin-bottom:6px;">
                <span class="pill pill-muted tnum">T7, 21/11 · 09:00 – 10:30</span>
                <span class="pill pill-muted">Đã hủy</span>
              </div>
              <div class="txt-sm txt-bold">Phạm Quốc Bảo</div>
              <div class="txt-xs tnum" style="margin-top:2px;">Dời lịch trước 12 giờ · Hoàn lại 1 buổi PT</div>
            </div>
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

        <!-- Level 3 Modal: Hủy buổi dạy -->
        <div class="qr-overlay" data-coach-modal="cancel-session">
          <div class="qr-sheet" style="text-align:left;">
            <div class="row" style="gap:10px;margin-bottom:10px;">
              <div style="width:40px;height:40px;border-radius:12px;background:rgba(241,91,100,0.16);border:1px solid rgba(241,91,100,0.42);display:flex;align-items:center;justify-content:center;flex-shrink:0;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/coaching/coaching_termination.svg" alt="Hủy ca dạy" />
              </div>
              <div style="min-width:0;">
                <div style="font-size:16px;font-weight:800;">Hủy buổi dạy này?</div>
                <div class="txt-xs tnum" style="color:var(--text-warm-muted);margin-top:2px;">Nguyễn Minh Quân · Hôm nay 18:00 – 19:30</div>
              </div>
            </div>
            <div class="txt-xs" style="color:var(--text-warm-muted);line-height:1.5;margin-bottom:10px;">
              Hủy ca sẽ hoàn lại 1 buổi PT vào gói của học viên và gửi thông báo ngay lập tức.
            </div>
            <div class="filter-row" style="margin-bottom:10px;">
              <div class="filter-pill active">Bận đột xuất</div>
              <div class="filter-pill">HV xin dời lịch</div>
              <div class="filter-pill">Lý do sức khỏe</div>
            </div>
            <div class="field">
              <label>Ghi chú gửi học viên (không bắt buộc)</label>
              <div class="input-box" style="height:64px;align-items:flex-start;padding-top:10px;font-size:14px;color:var(--text-secondary);">Hẹn lại anh khung 18:00 ngày mai nhé!</div>
            </div>
            <div class="grid-2" style="gap:10px;">
              <button type="button" class="btn-secondary" style="height:44px;" data-close-coach-modal>Giữ lịch</button>
              <button type="button" class="btn-primary" style="height:44px;background:#E5484D;border-color:#F15B64;" data-close-coach-modal data-coach-toast="Đã hủy ca dạy &amp; hoàn 1 buổi cho học viên">Xác nhận hủy ca</button>
            </div>
          </div>
        </div>

        <!-- Level 3 Modal: Chi tiết & Điểm danh ca dạy (PATCH /coach-bookings/:id) -->
        <div class="qr-overlay" data-coach-modal="session-detail">
          <div class="qr-sheet" style="text-align:left;">
            <div class="row-between" style="margin-bottom:10px;">
              <div class="row" style="gap:10px;min-width:0;">
                <div class="avatar-member" style="width:40px;height:40px;font-size:14px;background:linear-gradient(135deg,#2ECC71,#1D63B8);">TV</div>
                <div style="min-width:0;">
                  <div style="font-size:16px;font-weight:800;">Trần Thảo Vy</div>
                  <div class="txt-xs tnum" style="color:var(--text-warm-muted);">Hôm nay · 19:45 – 21:15 (90 phút)</div>
                </div>
              </div>
              <button type="button" class="circle-btn" style="width:32px;height:32px;font-size:14px;" data-close-coach-modal>✕</button>
            </div>
            <div class="metric-box" style="margin-bottom:12px;">
              <div class="row-between">
                <span class="txt-xs">Trạng thái ca tập</span>
                <span class="pill pill-success">BOOKED · Đã lên lịch</span>
              </div>
              <div class="txt-xs" style="color:var(--text-warm-muted);margin-top:6px;line-height:1.4;">Chạm hành động bên dưới để điểm danh hoặc mở hồ sơ hội viên.</div>
            </div>
            <div class="grid-3" style="gap:8px;margin-bottom:10px;">
              <button type="button" class="btn-secondary" style="height:40px;font-size:12px;padding:0 6px;color:var(--error);border-color:rgba(241,91,100,0.42);" data-close-coach-modal data-open-coach-modal="cancel-session">Hủy ca</button>
              <button type="button" class="btn-secondary" style="height:40px;font-size:12px;padding:0 6px;color:var(--warning);border-color:rgba(243,156,18,0.45);" data-close-coach-modal data-coach-toast="Đã đánh dấu hội viên vắng mặt">HV vắng</button>
              <button type="button" class="btn-primary" style="height:40px;font-size:12px;padding:0 6px;" data-close-coach-modal data-coach-toast="Đã hoàn thành ca dạy &amp; trừ 1 buổi PT">Hoàn thành</button>
            </div>
            <button type="button" class="btn-secondary" style="height:42px;font-size:14px;" data-close-coach-modal data-go="coach-member-detail">Xem hồ sơ hội viên ›</button>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'coach-workweek',
    group: 'coach-tab2-schedule',
    groupLabel: '2. Lịch dạy',
    title: '2.2 Lịch làm việc cố định (Tuần)',
    shortFile: 'coach_home_page.dart (WorkWeek)',
    flutterFile: 'mobile-app/lib/features/coach/presentation/coach_home_page.dart',
    tag: 'P1 • Thiết lập tuần',
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
              <div class="mg-eyebrow">THIẾT LẬP LỊCH DẠY</div>
              <div class="mg-title">Lịch làm việc tuần</div>
            </div>
          </div>

          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:8px;">
              <div class="row" style="gap:8px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/quick_actions/action_coach_workweek.svg" alt="Tuần" />
                <strong class="txt-sm">Quy chuẩn lịch Coach</strong>
              </div>
              <span class="pill pill-success tnum">6 / 7 ngày</span>
            </div>
            <div class="txt-xs" style="color:var(--text-warm-muted);line-height:1.45;margin-bottom:8px;">
              Cần mở tối thiểu <strong style="color:var(--text-primary);">6 ngày/tuần</strong>, mỗi ngày tối thiểu <strong class="tnum" style="color:var(--text-primary);">4 khung 90 phút liên tiếp</strong>.
            </div>
            <div style="background:rgba(243,156,18,0.12);border:1px solid rgba(243,156,18,0.34);border-radius:10px;padding:7px 10px;">
              <div class="txt-xs tnum" style="color:var(--warning);line-height:1.4;">Lưu ý backend: Đang có gói HV hiệu lực → lịch cố định tạm khóa thay đổi (409) để bảo toàn ca đặt trước.</div>
            </div>
          </div>

          <div class="card-liquid" style="padding:4px 14px;">
            <div style="padding:11px 0;">
              <div class="row-between" style="margin-bottom:6px;">
                <div class="txt-sm txt-bold">Thứ 2</div>
                <div class="toggle-pill on"><div class="toggle-knob"></div></div>
              </div>
              <div class="row" style="gap:5px;flex-wrap:wrap;">
                <span class="pill pill-success tnum" style="font-size:11px;padding:2px 7px;">06:00</span>
                <span class="pill pill-success tnum" style="font-size:11px;padding:2px 7px;">07:30</span>
                <span class="pill pill-success tnum" style="font-size:11px;padding:2px 7px;">09:00</span>
                <span class="pill pill-success tnum" style="font-size:11px;padding:2px 7px;">10:30</span>
                <span class="pill pill-muted tnum" style="font-size:11px;padding:2px 7px;">+4 ca chiều</span>
              </div>
            </div>
            <div class="divider" style="margin:0;"></div>
            <div class="row-between" style="padding:11px 0;">
              <div>
                <div class="txt-sm txt-bold">Thứ 3</div>
                <div class="txt-xs tnum txt-green">06:00 – 11:30 · 14:00 – 21:00</div>
              </div>
              <div class="toggle-pill on"><div class="toggle-knob"></div></div>
            </div>
            <div class="divider" style="margin:0;"></div>
            <div class="row-between" style="padding:11px 0;">
              <div>
                <div class="txt-sm txt-bold">Thứ 4</div>
                <div class="txt-xs tnum txt-green">06:00 – 11:30 · 14:00 – 21:00</div>
              </div>
              <div class="toggle-pill on"><div class="toggle-knob"></div></div>
            </div>
            <div class="divider" style="margin:0;"></div>
            <div class="row-between" style="padding:11px 0;">
              <div>
                <div class="txt-sm txt-bold">Thứ 5</div>
                <div class="txt-xs tnum txt-green">06:00 – 11:30 · 14:00 – 21:00</div>
              </div>
              <div class="toggle-pill on"><div class="toggle-knob"></div></div>
            </div>
            <div class="divider" style="margin:0;"></div>
            <div class="row-between" style="padding:11px 0;">
              <div>
                <div class="txt-sm txt-bold">Thứ 6</div>
                <div class="txt-xs tnum txt-green">06:00 – 11:30 · 14:00 – 21:00</div>
              </div>
              <div class="toggle-pill on"><div class="toggle-knob"></div></div>
            </div>
            <div class="divider" style="margin:0;"></div>
            <div class="row-between" style="padding:11px 0;">
              <div>
                <div class="txt-sm txt-bold">Thứ 7</div>
                <div class="txt-xs tnum txt-green">07:00 – 12:00 · 15:00 – 20:00</div>
              </div>
              <div class="toggle-pill on"><div class="toggle-knob"></div></div>
            </div>
            <div class="divider" style="margin:0;"></div>
            <div class="row-between" style="padding:11px 0;">
              <div>
                <div class="txt-sm txt-bold" style="color:var(--text-secondary);">Chủ nhật</div>
                <div class="txt-xs">Ngày nghỉ định kỳ</div>
              </div>
              <div class="toggle-pill"><div class="toggle-knob"></div></div>
            </div>
          </div>
        </div>

        <div class="bottom-cta-dock">
          <button type="button" class="btn-primary" data-coach-toast="Đã lưu lịch làm việc tuần (6/7 ngày)">Lưu lịch làm việc tuần</button>
        </div>
      </div>
    `
  },
  {
    id: 'coach-blocked-slots',
    group: 'coach-tab2-schedule',
    groupLabel: '2. Lịch dạy',
    title: '2.3 Chặn khung giờ bận',
    shortFile: 'coach_home_page.dart (BlockedSlots)',
    flutterFile: 'mobile-app/lib/features/coach/presentation/coach_home_page.dart',
    tag: 'P2 • Khóa lịch cá nhân',
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
              <div class="mg-eyebrow">KHÓA LỊCH CÁ NHÂN</div>
              <div class="mg-title">Chặn khung giờ bận</div>
            </div>
          </div>

          <div class="card-warm-glass">
            <div class="row" style="gap:8px;margin-bottom:10px;">
              <img class="ico-sm" src="../../meta-gym/assets/svg/quick_actions/action_coach_block_slot.svg" alt="Chặn khung" />
              <strong class="txt-sm">Khóa 1 ca 90 phút bận cá nhân</strong>
            </div>
            <div class="field">
              <label>Ngày cần khóa</label>
              <div class="input-box" data-pick-date="Ngày cần khóa khung giờ" style="cursor:pointer;">
                <span class="tnum">28/11/2026</span>
                <img class="ico-sm" src="../../meta-gym/assets/svg/workout/workout_plan_calendar.svg" alt="Lịch" />
              </div>
            </div>
            <div class="field" style="margin-bottom:8px;">
              <label>Chọn ca 90 phút theo lịch tuần (PUT /coach-bookings/blocks)</label>
              <div class="filter-row" style="margin-bottom:2px;">
                <div class="filter-pill">06:00 – 07:30</div>
                <div class="filter-pill">09:00 – 10:30</div>
                <div class="filter-pill active">14:00 – 15:30</div>
                <div class="filter-pill">18:00 – 19:30</div>
                <div class="filter-pill">19:30 – 21:00</div>
              </div>
            </div>
            <div class="field" style="margin-bottom:10px;">
              <label>Lý do khóa ca</label>
              <div class="input-box" style="color:var(--text-secondary);">Họp chuyên môn huấn luyện viên</div>
            </div>
            <button type="button" class="btn-primary" style="height:44px;font-size:14px;" data-coach-toast="Đã khóa ca 14:00 – 15:30 ngày 28/11 (startsAt)">Khóa ca 90 phút này</button>
          </div>

          <div class="sec-head">
            <h3>Các ca 90 phút đang khóa</h3>
            <span class="txt-xs tnum">2 ca</span>
          </div>

          <div class="card-liquid" style="padding:13px;">
            <div class="row-between">
              <div style="min-width:0;">
                <div class="txt-sm txt-bold tnum">T7, 28/11 · 14:00 – 15:30</div>
                <div class="txt-xs" style="margin-top:2px;">Họp chuyên môn nội bộ · Học viên không thể đặt</div>
              </div>
              <button type="button" class="circle-btn" style="width:34px;height:34px;border-color:rgba(241,91,100,0.42);" data-coach-toast="Đã mở lại ca 14:00 ngày 28/11">
                <img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" />
              </button>
            </div>
          </div>

          <div class="card-liquid" style="padding:13px;">
            <div class="row-between">
              <div style="min-width:0;">
                <div class="txt-sm txt-bold tnum">T3, 01/12 · 09:00 – 10:30</div>
                <div class="txt-xs" style="margin-top:2px;">Kiểm tra thể lực định kỳ cá nhân</div>
              </div>
              <button type="button" class="circle-btn" style="width:34px;height:34px;border-color:rgba(241,91,100,0.42);" data-coach-toast="Đã mở lại ca 09:00 ngày 01/12">
                <img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" />
              </button>
            </div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'coach-booking-history',
    group: 'coach-tab2-schedule',
    groupLabel: '2. Lịch dạy',
    title: '2.4 Lịch sử buổi dạy',
    shortFile: 'coach_booking_history_page.dart',
    flutterFile: 'mobile-app/lib/features/sessions/presentation/coach_booking_history_page.dart',
    tag: 'P2 • Thống kê ca dạy',
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
              <div class="mg-eyebrow">THỐNG KÊ GIẢNG DẠY</div>
              <div class="mg-title">Lịch sử buổi dạy</div>
            </div>
          </div>

          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:10px;">
              <strong class="txt-sm">Tổng hợp chuyên cần</strong>
              <span class="pill pill-success tnum">97,3% hoàn thành</span>
            </div>
            <div class="grid-2">
              <div class="metric-box">
                <div class="txt-xs">Đã hoàn thành</div>
                <div class="tnum txt-bold txt-green" style="font-size:22px;margin-top:2px;">142</div>
                <div class="txt-xs">Buổi 90 phút</div>
              </div>
              <div class="metric-box">
                <div class="txt-xs">Đã hủy / HV vắng</div>
                <div class="tnum txt-bold txt-warn" style="font-size:22px;margin-top:2px;">4</div>
                <div class="txt-xs">Trong 90 ngày qua</div>
              </div>
            </div>
          </div>

          <div class="filter-row">
            <div class="filter-pill active" data-filter-cat="all">Tất cả</div>
            <div class="filter-pill" data-filter-cat="completed">Hoàn thành</div>
            <div class="filter-pill" data-filter-cat="absent">HV vắng</div>
            <div class="filter-pill" data-filter-cat="cancelled">Đã hủy</div>
          </div>

          <div class="sec-head" style="margin-top:6px;">
            <h3>Tháng 11 / 2026</h3>
            <span class="txt-xs tnum">4 bản ghi gần nhất</span>
          </div>

          <div class="card-liquid" data-filter-item="completed" style="padding:13px;">
            <div class="row-between" style="margin-bottom:4px;">
              <strong class="txt-sm">Nguyễn Minh Quân</strong>
              <span class="pill pill-success">Hoàn thành</span>
            </div>
            <div class="txt-xs tnum">T4, 25/11 · 18:00 – 19:30 · Upper Body &amp; Core</div>
          </div>

          <div class="card-liquid" data-filter-item="completed" style="padding:13px;">
            <div class="row-between" style="margin-bottom:4px;">
              <strong class="txt-sm">Trần Thảo Vy</strong>
              <span class="pill pill-success">Hoàn thành</span>
            </div>
            <div class="txt-xs tnum">T3, 24/11 · 19:45 – 21:15 · Glutes &amp; Core</div>
          </div>

          <div class="card-liquid" data-filter-item="absent" style="padding:13px;">
            <div class="row-between" style="margin-bottom:4px;">
              <strong class="txt-sm">Đỗ Khánh Linh</strong>
              <span class="pill pill-warning">Hội viên vắng</span>
            </div>
            <div class="txt-xs tnum">T2, 23/11 · 17:00 – 18:30 · Full Body Conditioning</div>
          </div>

          <div class="card-liquid" data-filter-item="cancelled" style="padding:13px;">
            <div class="row-between" style="margin-bottom:4px;">
              <strong class="txt-sm">Phạm Quốc Bảo</strong>
              <span class="pill pill-muted">Đã hủy</span>
            </div>
            <div class="txt-xs tnum">T7, 21/11 · 09:00 – 10:30 · Dời lịch trước 12 giờ</div>
          </div>
        </div>
      </div>
    `
  },

  // ===========================================================================
  // 3. GIÁO ÁN TẬP LUYỆN (TÁCH RIÊNG HOÀN TOÀN KHỎI DINH DƯỠNG)
  // ===========================================================================
  {
    id: 'coach-training',
    group: 'coach-tab3-training',
    groupLabel: '3. Giáo án tập luyện',
    title: '3.1 Chọn hội viên tập luyện',
    shortFile: 'coach_training_page.dart',
    flutterFile: 'mobile-app/lib/features/training/presentation/coach_training_page.dart',
    tag: 'P0 • Tập luyện (Bước 1)',
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
              <div class="mg-eyebrow">GIÁO ÁN TẬP LUYỆN</div>
              <div class="mg-title">Chọn hội viên tập luyện</div>
              <div class="txt-xs" style="color:var(--text-warm-muted);">Quản lý giáo trình bài tập &amp; tiến độ từng học viên</div>
            </div>
          </div>

          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:10px;">
              <div class="row" style="gap:8px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/quick_actions/action_coach_plans.svg" alt="Giáo án" />
                <strong class="txt-sm">Tổng quan giáo án tập</strong>
              </div>
              <span class="pill pill-orange tnum">6 HV đang theo</span>
            </div>
            <div class="grid-3">
              <div class="metric-box" style="text-align:center;padding:8px 4px;">
                <div class="tnum txt-bold txt-orange" style="font-size:20px;">5</div>
                <div class="txt-xs">Đang áp dụng</div>
              </div>
              <div class="metric-box" style="text-align:center;padding:8px 4px;">
                <div class="tnum txt-bold txt-warn" style="font-size:20px;">1</div>
                <div class="txt-xs">Chưa có lịch</div>
              </div>
              <div class="metric-box" style="text-align:center;padding:8px 4px;">
                <div class="tnum txt-bold txt-green" style="font-size:20px;">62</div>
                <div class="txt-xs">Bài tập giao</div>
              </div>
            </div>
          </div>

          <div class="input-box" style="margin-bottom:12px;">
            <img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_search.svg" alt="Tìm" />
            <span style="flex:1;color:var(--text-secondary);">Tìm hội viên hoặc tên giáo trình...</span>
          </div>

          <div class="filter-row">
            <div class="filter-pill active" data-filter-cat="all" style="min-height:44px;display:inline-flex;align-items:center;">Tất cả (4)</div>
            <div class="filter-pill" data-filter-cat="has-plan" style="min-height:44px;display:inline-flex;align-items:center;">Đã có giáo án (3)</div>
            <div class="filter-pill" data-filter-cat="no-plan" style="min-height:44px;display:inline-flex;align-items:center;">Chưa có giáo án (1)</div>
          </div>

          <div class="sec-head" style="margin-top:6px;">
            <h3>Hội viên tập luyện</h3>
            <span class="txt-xs">Chạm để mở giáo trình tập</span>
          </div>

          <div class="card-solid" data-filter-item="has-plan" data-go="coach-member-plans" style="padding:13px;border-color:rgba(255,94,54,0.45);cursor:pointer;">
            <div class="row" style="gap:11px;margin-bottom:8px;">
              <div class="avatar-member" style="width:42px;height:42px;font-size:14px;">MQ</div>
              <div style="flex:1;min-width:0;">
                <div class="row-between" style="gap:6px;">
                  <strong class="txt-sm">Nguyễn Minh Quân</strong>
                  <span class="pill pill-success">Đang áp dụng</span>
                </div>
                <div class="txt-xs tnum" style="margin-top:2px;">Upper / Lower Split · 4 ngày/tuần · 18 bài tập</div>
                <div class="txt-xs tnum" style="color:var(--warning);margin-top:2px;">Lưu ý vai phải · Tiến độ: Tuần 3/4 (9/16 buổi)</div>
              </div>
            </div>
            <div class="prog-track" style="height:4px;margin-bottom:9px;"><div class="prog-fill" style="width:56%;"></div></div>
            <div class="row-between">
              <span class="txt-xs tnum" style="color:var(--text-warm-muted);">Cập nhật gần nhất: Hôm qua</span>
              <span class="txt-orange txt-xs txt-bold">Mở giáo trình tập ›</span>
            </div>
          </div>

          <div class="card-solid" data-filter-item="has-plan" data-go="coach-member-plans" style="padding:13px;cursor:pointer;">
            <div class="row" style="gap:11px;margin-bottom:8px;">
              <div class="avatar-member" style="width:42px;height:42px;font-size:14px;background:linear-gradient(135deg,#2ECC71,#1D63B8);">TV</div>
              <div style="flex:1;min-width:0;">
                <div class="row-between" style="gap:6px;">
                  <strong class="txt-sm">Trần Thảo Vy</strong>
                  <span class="pill pill-success">Đang áp dụng</span>
                </div>
                <div class="txt-xs tnum" style="margin-top:2px;">Glutes &amp; Core · 3 ngày/tuần · 12 bài tập</div>
              </div>
            </div>
            <div class="prog-track" style="height:4px;margin-bottom:8px;"><div class="prog-fill" style="width:68%;"></div></div>
            <div class="row-between">
              <span class="txt-xs tnum">Tuần 4/6 · Đạt 92% hoàn thành</span>
              <span class="txt-orange txt-xs txt-bold">Mở giáo trình ›</span>
            </div>
          </div>

          <div class="card-solid" data-filter-item="has-plan" data-go="coach-member-plans" style="padding:13px;cursor:pointer;">
            <div class="row" style="gap:11px;margin-bottom:8px;">
              <div class="avatar-member" style="width:42px;height:42px;font-size:14px;background:linear-gradient(135deg,#F39C12,#D9431E);">PB</div>
              <div style="flex:1;min-width:0;">
                <div class="row-between" style="gap:6px;">
                  <strong class="txt-sm">Phạm Quốc Bảo</strong>
                  <span class="pill pill-success">Đang áp dụng</span>
                </div>
                <div class="txt-xs tnum" style="margin-top:2px;">Powerbuilding · 4 ngày/tuần · 16 bài tập</div>
              </div>
            </div>
            <div class="prog-track" style="height:4px;margin-bottom:8px;"><div class="prog-fill orange" style="width:82%;"></div></div>
            <div class="row-between">
              <span class="txt-xs tnum">Tuần 5/6 · Sức mạnh tăng +12%</span>
              <span class="txt-orange txt-xs txt-bold">Mở giáo trình ›</span>
            </div>
          </div>

          <div class="card-solid" data-filter-item="no-plan" data-go="coach-plan-form" style="padding:13px;border-color:rgba(243,156,18,0.45);cursor:pointer;">
            <div class="row" style="gap:11px;margin-bottom:9px;">
              <div class="avatar-member" style="width:42px;height:42px;font-size:14px;background:linear-gradient(135deg,#6B7280,#374151);">KL</div>
              <div style="flex:1;min-width:0;">
                <div class="row-between" style="gap:6px;">
                  <strong class="txt-sm">Đỗ Khánh Linh</strong>
                  <span class="pill pill-warning">Chưa có giáo án</span>
                </div>
                <div class="txt-xs tnum" style="margin-top:2px;">Hội viên mới · Mục tiêu: Săn chắc toàn thân 3 buổi/tuần</div>
              </div>
            </div>
            <button type="button" class="btn-primary" style="height:44px;font-size:14px;" data-go="coach-plan-form">+ Tạo giáo trình tập luyện</button>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'coach-member-plans',
    group: 'coach-tab3-training',
    groupLabel: '3. Giáo án tập luyện',
    title: '3.2 Danh sách giáo trình tập',
    shortFile: 'coach_training_page.dart (_MemberPlansPage)',
    flutterFile: 'mobile-app/lib/features/training/presentation/coach_training_page.dart',
    tag: 'P0 • Bước 2: DS Giáo án',
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
              <div class="mg-eyebrow">GIÁO ÁN TẬP LUYỆN</div>
              <div class="mg-title">Nguyễn Minh Quân</div>
            </div>
            <div class="circle-btn" data-go="coach-plan-form" title="Tạo giáo trình mới"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_add.svg" alt="Tạo giáo trình" /></div>
          </div>

          <!-- Tóm tắt hội viên đang soạn giáo án -->
          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:8px;">
              <div class="row" style="gap:10px;min-width:0;">
                <div class="avatar-member" style="width:40px;height:40px;font-size:14px;">MQ</div>
                <div style="min-width:0;">
                  <strong class="txt-sm">Tăng cơ Hypertrophy</strong>
                  <div class="txt-xs tnum" style="color:var(--text-warm-muted);">4 buổi/tuần · 60 phút/buổi</div>
                </div>
              </div>
              <span class="pill pill-success tnum">14/24 buổi PT</span>
            </div>
            <div style="background:rgba(243,156,18,0.12);border:1px solid rgba(243,156,18,0.34);border-radius:10px;padding:8px 10px;">
              <div class="row" style="gap:6px;align-items:flex-start;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/coaching/health_injury.svg" alt="Cảnh báo" />
                <span class="txt-xs" style="color:var(--warning);line-height:1.4;">Tránh góc đẩy vai &gt; 90° (Impingement nhẹ vai phải)</span>
              </div>
            </div>
          </div>

          <div class="filter-row">
            <div class="filter-pill active" data-filter-cat="all" style="min-height:44px;display:inline-flex;align-items:center;">Tất cả (2)</div>
            <div class="filter-pill" data-filter-cat="active" style="min-height:44px;display:inline-flex;align-items:center;">Đang áp dụng (1)</div>
            <div class="filter-pill" data-filter-cat="archived" style="min-height:44px;display:inline-flex;align-items:center;">Lưu trữ (1)</div>
          </div>

          <div class="sec-head" style="margin-top:6px;">
            <h3>Giáo trình bài tập</h3>
            <span class="txt-xs tnum">Chạm để xem chi tiết</span>
          </div>

          <!-- Giáo trình 1: Đang áp dụng -->
          <div class="card-solid" data-filter-item="active" data-go="coach-plan-detail" style="padding:14px;border-color:rgba(46,204,113,0.48);cursor:pointer;">
            <div class="row-between" style="margin-bottom:6px;">
              <span class="pill pill-success">Đang áp dụng</span>
              <span class="txt-xs tnum">Phiên bản #3</span>
            </div>
            <div class="txt-sm txt-bold">Upper / Lower Split — Hypertrophy 4 tuần</div>
            <div class="txt-xs tnum" style="color:var(--text-warm-muted);margin-top:3px;">4 ngày/tuần · 18 bài tập · Ngực, Lưng, Chân, Vai</div>
            <div class="row" style="gap:6px;margin-top:7px;">
              <img class="ico-sm" src="../../meta-gym/assets/svg/workout/workout_plan_calendar.svg" alt="Thời gian" />
              <span class="txt-xs tnum">10/11/2026 – 08/12/2026</span>
            </div>
            <div class="row-between" style="margin-top:8px;">
              <span class="txt-xs tnum">Tiến độ: Tuần 3/4 · 9/16 buổi</span>
              <span class="txt-orange txt-xs txt-bold">Chi tiết ›</span>
            </div>
            <div class="prog-track" style="height:4px;margin-top:6px;"><div class="prog-fill" style="width:56%;"></div></div>
          </div>

          <!-- Giáo trình 2: Lưu trữ -->
          <div class="card-solid" data-filter-item="archived" data-go="coach-plan-detail" style="padding:14px;opacity:0.86;cursor:pointer;">
            <div class="row-between" style="margin-bottom:6px;">
              <span class="pill pill-muted">Lưu trữ</span>
              <span class="txt-xs tnum">Phiên bản #2</span>
            </div>
            <div class="txt-sm txt-bold">Làm quen kỹ thuật cơ bản (Nền tảng)</div>
            <div class="txt-xs tnum" style="margin-top:3px;">3 ngày/tuần · 12 bài tập · Toàn thân · Hoàn thành 12/12 buổi</div>
          </div>
        </div>

        <div class="bottom-cta-dock">
          <button type="button" class="btn-primary" data-go="coach-plan-form">Cập nhật giáo trình hiện tại</button>
        </div>
      </div>
    `
  },
  {
    id: 'coach-plan-detail',
    group: 'coach-tab3-training',
    groupLabel: '3. Giáo án tập luyện',
    title: '3.3 Chi tiết giáo trình tập',
    shortFile: 'coach_plan_detail_page.dart',
    flutterFile: 'mobile-app/lib/features/training/presentation/coach_plan_detail_page.dart',
    tag: 'P0 • Chi tiết bài tập',
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
              <div class="mg-eyebrow">GIÁO ÁN TẬP · MINH QUÂN</div>
              <div class="mg-title">Chi tiết giáo trình</div>
            </div>
            <div class="circle-btn" data-go="coach-plan-form" title="Chỉnh sửa"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_edit.svg" alt="Sửa" /></div>
          </div>

          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:6px;">
              <span class="pill pill-success">Đang áp dụng · Phiên bản #3</span>
              <span class="txt-xs tnum">4 ngày/tuần</span>
            </div>
            <div style="font-size:16px;font-weight:800;">Upper / Lower Split — Hypertrophy</div>
            <div class="row" style="gap:6px;margin-top:4px;margin-bottom:10px;">
              <img class="ico-sm" src="../../meta-gym/assets/svg/workout/workout_plan_calendar.svg" alt="Lịch" />
              <span class="txt-xs tnum" style="color:var(--text-warm-muted);">01/12/2026 – 29/12/2026 · Tăng cơ nạc</span>
            </div>
            <div class="grid-3">
              <div class="metric-box" style="padding:8px;text-align:center;">
                <div class="tnum txt-bold" style="font-size:16px;">4</div>
                <div class="txt-xs">Ngày tập</div>
              </div>
              <div class="metric-box" style="padding:8px;text-align:center;">
                <div class="tnum txt-bold txt-orange" style="font-size:16px;">18</div>
                <div class="txt-xs">Bài tập</div>
              </div>
              <div class="metric-box" style="padding:8px;text-align:center;">
                <div class="tnum txt-bold txt-green" style="font-size:16px;">60p</div>
                <div class="txt-xs">Mỗi buổi</div>
              </div>
            </div>
          </div>

          <div class="filter-row">
            <div class="filter-pill active" data-state-btn="day1" style="min-height:44px;display:inline-flex;align-items:center;">Ngày 1 · Push</div>
            <div class="filter-pill" data-state-btn="day2" style="min-height:44px;display:inline-flex;align-items:center;">Ngày 2 · Pull</div>
            <div class="filter-pill" data-state-btn="day3" style="min-height:44px;display:inline-flex;align-items:center;">Ngày 3 · Legs</div>
            <div class="filter-pill" data-state-btn="day4" style="min-height:44px;display:inline-flex;align-items:center;">Ngày 4 · Upper</div>
          </div>

          <!-- Ngày 1: Push -->
          <div data-state-pane="day1">
            <div class="card-solid" style="padding:11px 13px;border-color:rgba(255,159,67,0.38);">
              <div class="row" style="gap:8px;align-items:flex-start;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/workout/workout_warmup.svg" alt="Khởi động" />
                <div style="flex:1;min-width:0;">
                  <div class="txt-xs txt-bold" style="color:var(--text-primary);">Ngực trên · Vai trước · Tay sau</div>
                  <div class="txt-xs" style="color:var(--text-warm-muted);margin-top:2px;line-height:1.4;">Khởi động khớp vai 5 phút với dây kháng lực nhẹ trước khi vào bài chính.</div>
                </div>
              </div>
            </div>
            <div class="sec-head" style="margin-top:4px;"><h3>Bài tập Ngày 1 (4 bài)</h3><span class="txt-xs tnum">~60 phút · Nghỉ 60–120s</span></div>
            <div class="card-solid" style="padding:13px;"><div class="row" style="gap:10px;align-items:flex-start;"><img class="ico-lg" src="../../meta-gym/assets/svg/catalog/equip_dumbbell.svg" alt="Tạ đơn" /><div style="flex:1;min-width:0;"><div class="row-between" style="gap:6px;"><strong class="txt-sm">1. Incline Dumbbell Press</strong><span class="pill pill-orange">Ngực trên</span></div><div class="txt-xs tnum" style="margin-top:3px;">4 hiệp · 8–10 lần · Nghỉ 90s · Gợi ý 22 kg/tay</div><div class="txt-xs" style="color:var(--text-warm-muted);margin-top:4px;line-height:1.4;">Kiểm soát pha hạ tạ 3 giây, giữ khuỷu tay 45° tránh ép khớp vai.</div></div></div></div>
            <div class="card-solid" style="padding:13px;"><div class="row" style="gap:10px;align-items:flex-start;"><img class="ico-lg" src="../../meta-gym/assets/svg/catalog/equip_barbell.svg" alt="Thanh đòn" /><div style="flex:1;min-width:0;"><div class="row-between" style="gap:6px;"><strong class="txt-sm">2. Flat Barbell Bench Press</strong><span class="pill pill-muted">Ngực giữa</span></div><div class="txt-xs tnum" style="margin-top:3px;">3 hiệp · 6–8 lần · Nghỉ 120s · Gợi ý 60 kg</div></div></div></div>
            <div class="card-solid" style="padding:13px;"><div class="row" style="gap:10px;align-items:flex-start;"><img class="ico-lg" src="../../meta-gym/assets/svg/catalog/equip_cable.svg" alt="Máy cáp" /><div style="flex:1;min-width:0;"><div class="row-between" style="gap:6px;"><strong class="txt-sm">3. Cable Lateral Raise</strong><span class="pill pill-muted">Vai giữa</span></div><div class="txt-xs tnum" style="margin-top:3px;">4 hiệp · 12–15 lần · Nghỉ 60s · Tạ cáp 7,5 kg</div></div></div></div>
            <div class="card-solid" style="padding:13px;"><div class="row" style="gap:10px;align-items:flex-start;"><img class="ico-lg" src="../../meta-gym/assets/svg/catalog/equip_machine.svg" alt="Máy tập" /><div style="flex:1;min-width:0;"><div class="row-between" style="gap:6px;"><strong class="txt-sm">4. Rope Triceps Pushdown</strong><span class="pill pill-muted">Tay sau</span></div><div class="txt-xs tnum" style="margin-top:3px;">3 hiệp · 12 lần · Nghỉ 60s · Mức tạ 25 kg</div></div></div></div>
          </div>

          <!-- Ngày 2: Pull -->
          <div data-state-pane="day2" style="display:none;">
            <div class="card-solid" style="padding:11px 13px;border-color:rgba(46,204,113,0.38);">
              <div class="row" style="gap:8px;align-items:flex-start;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/workout/workout_warmup.svg" alt="Khởi động" />
                <div style="flex:1;min-width:0;">
                  <div class="txt-xs txt-bold" style="color:var(--text-primary);">Lưng xô · Vai sau · Tay trước</div>
                  <div class="txt-xs" style="color:var(--text-warm-muted);margin-top:2px;line-height:1.4;">Tập trung ép bả vai trước khi kéo, không nhún vai trên.</div>
                </div>
              </div>
            </div>
            <div class="sec-head" style="margin-top:4px;"><h3>Bài tập Ngày 2 (4 bài)</h3><span class="txt-xs tnum">~60 phút · Nghỉ 60–90s</span></div>
            <div class="card-solid" style="padding:13px;"><div class="row" style="gap:10px;"><img class="ico-lg" src="../../meta-gym/assets/svg/catalog/equip_cable.svg" alt="Cáp" /><div style="flex:1;min-width:0;"><div class="row-between"><strong class="txt-sm">1. Wide-Grip Lat Pulldown</strong><span class="pill pill-success">Lưng xô</span></div><div class="txt-xs tnum" style="margin-top:3px;">4 hiệp · 10–12 lần · Nghỉ 90s · Mức tạ 55 kg</div></div></div></div>
            <div class="card-solid" style="padding:13px;"><div class="row" style="gap:10px;"><img class="ico-lg" src="../../meta-gym/assets/svg/catalog/equip_machine.svg" alt="Máy" /><div style="flex:1;min-width:0;"><div class="row-between"><strong class="txt-sm">2. Seated Cable Row</strong><span class="pill pill-muted">Lưng giữa</span></div><div class="txt-xs tnum" style="margin-top:3px;">4 hiệp · 10 lần · Nghỉ 90s · Mức tạ 50 kg</div></div></div></div>
            <div class="card-solid" style="padding:13px;"><div class="row" style="gap:10px;"><img class="ico-lg" src="../../meta-gym/assets/svg/catalog/equip_cable.svg" alt="Cáp" /><div style="flex:1;min-width:0;"><div class="row-between"><strong class="txt-sm">3. Rope Face Pull</strong><span class="pill pill-muted">Vai sau</span></div><div class="txt-xs tnum" style="margin-top:3px;">3 hiệp · 15 lần · Nghỉ 60s · Tốt cho khớp vai</div></div></div></div>
            <div class="card-solid" style="padding:13px;"><div class="row" style="gap:10px;"><img class="ico-lg" src="../../meta-gym/assets/svg/catalog/equip_dumbbell.svg" alt="Tạ đơn" /><div style="flex:1;min-width:0;"><div class="row-between"><strong class="txt-sm">4. Incline Dumbbell Curl</strong><span class="pill pill-muted">Tay trước</span></div><div class="txt-xs tnum" style="margin-top:3px;">3 hiệp · 12 lần · Nghỉ 60s · 12 kg/tay</div></div></div></div>
          </div>

          <!-- Ngày 3: Legs -->
          <div data-state-pane="day3" style="display:none;">
            <div class="card-solid" style="padding:11px 13px;border-color:rgba(112,174,232,0.38);">
              <div class="row" style="gap:8px;align-items:flex-start;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/workout/workout_warmup.svg" alt="Khởi động" />
                <div style="flex:1;min-width:0;">
                  <div class="txt-xs txt-bold" style="color:var(--text-primary);">Đùi trước · Đùi sau · Bắp chuối</div>
                  <div class="txt-xs" style="color:var(--text-warm-muted);margin-top:2px;line-height:1.4;">Giãn khớp hông và cổ chân 6 phút trước buổi thân dưới.</div>
                </div>
              </div>
            </div>
            <div class="sec-head" style="margin-top:4px;"><h3>Bài tập Ngày 3 (4 bài)</h3><span class="txt-xs tnum">~65 phút · Nghỉ 90–120s</span></div>
            <div class="card-solid" style="padding:13px;"><div class="row" style="gap:10px;"><img class="ico-lg" src="../../meta-gym/assets/svg/catalog/equip_machine.svg" alt="Máy" /><div style="flex:1;min-width:0;"><div class="row-between"><strong class="txt-sm">1. 45° Leg Press</strong><span class="pill pill-orange">Đùi trước</span></div><div class="txt-xs tnum" style="margin-top:3px;">4 hiệp · 10–12 lần · Nghỉ 120s · 140 kg</div></div></div></div>
            <div class="card-solid" style="padding:13px;"><div class="row" style="gap:10px;"><img class="ico-lg" src="../../meta-gym/assets/svg/catalog/equip_barbell.svg" alt="Thanh đòn" /><div style="flex:1;min-width:0;"><div class="row-between"><strong class="txt-sm">2. Romanian Deadlift (RDL)</strong><span class="pill pill-muted">Đùi sau · Mông</span></div><div class="txt-xs tnum" style="margin-top:3px;">3 hiệp · 8–10 lần · Nghỉ 120s · 70 kg</div></div></div></div>
            <div class="card-solid" style="padding:13px;"><div class="row" style="gap:10px;"><img class="ico-lg" src="../../meta-gym/assets/svg/catalog/equip_machine.svg" alt="Máy" /><div style="flex:1;min-width:0;"><div class="row-between"><strong class="txt-sm">3. Leg Extension</strong><span class="pill pill-muted">Đùi trước</span></div><div class="txt-xs tnum" style="margin-top:3px;">3 hiệp · 12–15 lần · Nghỉ 60s · 45 kg</div></div></div></div>
            <div class="card-solid" style="padding:13px;"><div class="row" style="gap:10px;"><img class="ico-lg" src="../../meta-gym/assets/svg/catalog/equip_machine.svg" alt="Máy" /><div style="flex:1;min-width:0;"><div class="row-between"><strong class="txt-sm">4. Seated Calf Raise</strong><span class="pill pill-muted">Bắp chân</span></div><div class="txt-xs tnum" style="margin-top:3px;">4 hiệp · 15 lần · Nghỉ 45s · 35 kg</div></div></div></div>
          </div>

          <!-- Ngày 4: Upper -->
          <div data-state-pane="day4" style="display:none;">
            <div class="sec-head" style="margin-top:4px;"><h3>Bài tập Ngày 4 · Upper Balance (3 bài)</h3><span class="txt-xs tnum">~55 phút</span></div>
            <div class="card-solid" style="padding:13px;"><div class="row" style="gap:10px;"><img class="ico-lg" src="../../meta-gym/assets/svg/catalog/equip_machine.svg" alt="Máy" /><div style="flex:1;min-width:0;"><div class="row-between"><strong class="txt-sm">1. Machine Shoulder Press</strong><span class="pill pill-orange">Vai</span></div><div class="txt-xs tnum" style="margin-top:3px;">4 hiệp · 10 lần · Nghỉ 90s · An toàn khớp vai</div></div></div></div>
            <div class="card-solid" style="padding:13px;"><div class="row" style="gap:10px;"><img class="ico-lg" src="../../meta-gym/assets/svg/catalog/equip_dumbbell.svg" alt="Tạ đơn" /><div style="flex:1;min-width:0;"><div class="row-between"><strong class="txt-sm">2. Chest-Supported DB Row</strong><span class="pill pill-muted">Lưng</span></div><div class="txt-xs tnum" style="margin-top:3px;">4 hiệp · 10–12 lần · Nghỉ 90s · 20 kg/tay</div></div></div></div>
            <div class="card-solid" style="padding:13px;"><div class="row" style="gap:10px;"><img class="ico-lg" src="../../meta-gym/assets/svg/catalog/equip_cable.svg" alt="Cáp" /><div style="flex:1;min-width:0;"><div class="row-between"><strong class="txt-sm">3. Cable Chest Fly</strong><span class="pill pill-muted">Ngực giữa</span></div><div class="txt-xs tnum" style="margin-top:3px;">3 hiệp · 12–15 lần · Nghỉ 60s</div></div></div></div>
          </div>
        </div>

        <div class="bottom-cta-dock">
          <button type="button" class="btn-primary" data-go="coach-plan-form">Chỉnh sửa giáo trình</button>
        </div>
      </div>
    `
  },
  {
    id: 'coach-plan-form',
    group: 'coach-tab3-training',
    groupLabel: '3. Giáo án tập luyện',
    title: '3.4 Tạo / Sửa giáo trình tập',
    shortFile: 'coach_plan_form_page.dart',
    flutterFile: 'mobile-app/lib/features/training/presentation/coach_plan_form_page.dart',
    tag: 'P0 • Soạn bài tập',
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
              <div class="mg-eyebrow">MINH QUÂN · GIÁO TRÌNH TẬP</div>
              <div class="mg-title">Cập nhật giáo trình tập</div>
            </div>
          </div>

          <div class="card-warm-glass">
            <div class="field">
              <label>Tên giáo trình tập luyện</label>
              <div class="input-box">Upper / Lower Split — Hypertrophy</div>
            </div>
            <div class="grid-2" style="gap:8px;">
              <div class="field">
                <label>Mục tiêu chính</label>
                <div class="input-box">Tăng cơ nạc</div>
              </div>
              <div class="field">
                <label>Tần suất tuần</label>
                <div class="input-box tnum">4 ngày / tuần</div>
              </div>
            </div>
            <div class="grid-2" style="gap:8px;">
              <div class="field" style="margin-bottom:0;">
                <label>Ngày bắt đầu</label>
                <div class="input-box tnum" data-pick-date="Ngày bắt đầu giáo trình" style="cursor:pointer;">01/12/2026</div>
              </div>
              <div class="field" style="margin-bottom:0;">
                <label>Ngày kết thúc</label>
                <div class="input-box tnum" data-pick-date="Ngày kết thúc giáo trình" style="cursor:pointer;">29/12/2026</div>
              </div>
            </div>
          </div>

          <div class="sec-head">
            <h3>Cấu trúc ngày &amp; bài tập</h3>
            <span class="txt-xs tnum">4 ngày</span>
          </div>

          <div class="filter-row">
            <div class="filter-pill active" data-state-btn="fday1" style="min-height:44px;display:inline-flex;align-items:center;">Ngày 1 · Push</div>
            <div class="filter-pill" data-state-btn="fday2" style="min-height:44px;display:inline-flex;align-items:center;">Ngày 2 · Pull</div>
            <div class="filter-pill" data-state-btn="fday3" style="min-height:44px;display:inline-flex;align-items:center;">Ngày 3 · Legs</div>
            <div class="filter-pill" data-coach-toast="Đã thêm Ngày 4 · Upper Body" style="min-height:44px;display:inline-flex;align-items:center;">+ Thêm ngày</div>
          </div>

          <div class="card-solid" data-state-pane="fday1" style="padding:14px;">
            <div class="field" style="margin-bottom:10px;">
              <label>Nhóm cơ &amp; trọng tâm Ngày 1</label>
              <div class="input-box">Ngực trên · Vai trước &amp; giữa · Tay sau (~60 phút)</div>
            </div>

            <div class="metric-box" style="margin-bottom:8px;">
              <div class="row-between" style="margin-bottom:6px;gap:6px;">
                <strong class="txt-sm">1. Incline Dumbbell Press</strong>
                <button type="button" style="background:none;border:none;width:44px;height:44px;display:inline-flex;align-items:center;justify-content:center;cursor:pointer;flex-shrink:0;" data-coach-toast="Đã xóa bài tập khỏi Ngày 1" aria-label="Xóa bài tập">
                  <img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" />
                </button>
              </div>
              <div class="row" style="gap:6px;flex-wrap:wrap;">
                <span class="pill pill-muted tnum">4 hiệp</span>
                <span class="pill pill-muted tnum">8–10 lần</span>
                <span class="pill pill-muted tnum">Nghỉ 90s</span>
                <span class="pill pill-orange tnum">22 kg/tay</span>
              </div>
            </div>

            <div class="metric-box" style="margin-bottom:8px;">
              <div class="row-between" style="margin-bottom:6px;gap:6px;">
                <strong class="txt-sm">2. Cable Lateral Raise</strong>
                <button type="button" style="background:none;border:none;width:44px;height:44px;display:inline-flex;align-items:center;justify-content:center;cursor:pointer;flex-shrink:0;" data-coach-toast="Đã xóa bài tập khỏi Ngày 1" aria-label="Xóa bài tập">
                  <img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" />
                </button>
              </div>
              <div class="row" style="gap:6px;flex-wrap:wrap;">
                <span class="pill pill-muted tnum">4 hiệp</span>
                <span class="pill pill-muted tnum">12–15 lần</span>
                <span class="pill pill-muted tnum">Nghỉ 60s</span>
                <span class="pill pill-orange tnum">7,5 kg</span>
              </div>
            </div>

            <div class="metric-box" style="margin-bottom:10px;">
              <div class="row-between" style="margin-bottom:6px;gap:6px;">
                <strong class="txt-sm">3. Rope Triceps Pushdown</strong>
                <button type="button" style="background:none;border:none;width:44px;height:44px;display:inline-flex;align-items:center;justify-content:center;cursor:pointer;flex-shrink:0;" data-coach-toast="Đã xóa bài tập khỏi Ngày 1" aria-label="Xóa bài tập">
                  <img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" />
                </button>
              </div>
              <div class="row" style="gap:6px;flex-wrap:wrap;">
                <span class="pill pill-muted tnum">3 hiệp</span>
                <span class="pill pill-muted tnum">12 lần</span>
                <span class="pill pill-muted tnum">Nghỉ 60s</span>
                <span class="pill pill-orange tnum">25 kg</span>
              </div>
            </div>

            <button type="button" class="btn-secondary" style="height:44px;font-size:14px;gap:6px;" data-open-coach-modal="add-exercise">
              <img class="ico-sm" src="../../meta-gym/assets/svg/workout/workout_add_exercise.svg" alt="Thêm bài" />
              <span>+ Thêm bài tập từ danh mục</span>
            </button>
          </div>

          <div class="card-solid" data-state-pane="fday2" style="display:none;padding:14px;">
            <div class="field" style="margin-bottom:10px;">
              <label>Nhóm cơ &amp; trọng tâm Ngày 2</label>
              <div class="input-box">Lưng xô · Lưng giữa · Vai sau · Tay trước</div>
            </div>
            <div class="metric-box" style="margin-bottom:8px;"><div class="row-between" style="margin-bottom:6px;gap:6px;"><strong class="txt-sm">1. Wide-Grip Lat Pulldown</strong><button type="button" style="background:none;border:none;width:44px;height:44px;display:inline-flex;align-items:center;justify-content:center;cursor:pointer;flex-shrink:0;" data-coach-toast="Đã xóa bài tập khỏi Ngày 2" aria-label="Xóa bài tập"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></button></div><div class="row" style="gap:6px;"><span class="pill pill-muted tnum">4 hiệp</span><span class="pill pill-muted tnum">10–12 lần</span><span class="pill pill-orange tnum">55 kg</span></div></div>
            <div class="metric-box" style="margin-bottom:10px;"><div class="row-between" style="margin-bottom:6px;gap:6px;"><strong class="txt-sm">2. Seated Cable Row</strong><button type="button" style="background:none;border:none;width:44px;height:44px;display:inline-flex;align-items:center;justify-content:center;cursor:pointer;flex-shrink:0;" data-coach-toast="Đã xóa bài tập khỏi Ngày 2" aria-label="Xóa bài tập"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></button></div><div class="row" style="gap:6px;"><span class="pill pill-muted tnum">4 hiệp</span><span class="pill pill-muted tnum">10 lần</span><span class="pill pill-orange tnum">50 kg</span></div></div>
            <button type="button" class="btn-secondary" style="height:44px;font-size:14px;gap:6px;" data-open-coach-modal="add-exercise"><img class="ico-sm" src="../../meta-gym/assets/svg/workout/workout_add_exercise.svg" alt="Thêm" /><span>+ Thêm bài tập Ngày 2</span></button>
          </div>

          <div class="card-solid" data-state-pane="fday3" style="display:none;padding:14px;">
            <div class="field" style="margin-bottom:10px;">
              <label>Nhóm cơ &amp; trọng tâm Ngày 3</label>
              <div class="input-box">Thân dưới · Đùi trước · Đùi sau · Bắp chuối</div>
            </div>
            <div class="metric-box" style="margin-bottom:8px;"><div class="row-between" style="margin-bottom:6px;gap:6px;"><strong class="txt-sm">1. 45° Leg Press</strong><button type="button" style="background:none;border:none;width:44px;height:44px;display:inline-flex;align-items:center;justify-content:center;cursor:pointer;flex-shrink:0;" data-coach-toast="Đã xóa bài tập khỏi Ngày 3" aria-label="Xóa bài tập"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></button></div><div class="row" style="gap:6px;"><span class="pill pill-muted tnum">4 hiệp</span><span class="pill pill-muted tnum">10–12 lần</span><span class="pill pill-orange tnum">140 kg</span></div></div>
            <div class="metric-box" style="margin-bottom:10px;"><div class="row-between" style="margin-bottom:6px;gap:6px;"><strong class="txt-sm">2. Romanian Deadlift (RDL)</strong><button type="button" style="background:none;border:none;width:44px;height:44px;display:inline-flex;align-items:center;justify-content:center;cursor:pointer;flex-shrink:0;" data-coach-toast="Đã xóa bài tập khỏi Ngày 3" aria-label="Xóa bài tập"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></button></div><div class="row" style="gap:6px;"><span class="pill pill-muted tnum">3 hiệp</span><span class="pill pill-muted tnum">8–10 lần</span><span class="pill pill-orange tnum">70 kg</span></div></div>
            <button type="button" class="btn-secondary" style="height:44px;font-size:14px;gap:6px;" data-open-coach-modal="add-exercise"><img class="ico-sm" src="../../meta-gym/assets/svg/workout/workout_add_exercise.svg" alt="Thêm" /><span>+ Thêm bài tập Ngày 3</span></button>
          </div>
        </div>

        <div class="bottom-cta-dock">
          <button type="button" class="btn-primary" data-coach-toast="Đã lưu và áp dụng giáo trình hiện tại cho Nguyễn Minh Quân">Lưu &amp; Áp dụng giáo trình</button>
        </div>

        <!-- Level 3 Modal: Chọn bài tập từ thư viện -->
        <div class="qr-overlay" data-coach-modal="add-exercise">
          <div class="qr-sheet" style="text-align:left;">
            <div class="row-between" style="margin-bottom:10px;">
              <div style="font-size:16px;font-weight:800;">Thêm bài tập · Ngày 1</div>
              <button type="button" class="circle-btn" style="width:44px;height:44px;font-size:15px;" data-close-coach-modal aria-label="Đóng">✕</button>
            </div>
            <div class="input-box" style="margin-bottom:10px;height:44px;">
              <img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_search.svg" alt="Tìm" />
              <span style="flex:1;color:var(--text-secondary);">Tìm bài tập (VD: Chest Fly, Dip...)</span>
            </div>
            <div class="metric-box" style="margin-bottom:8px;cursor:pointer;" data-close-coach-modal data-coach-toast="Đã thêm Cable Chest Fly vào Ngày 1">
              <div class="row-between">
                <div><strong class="txt-sm">Cable Chest Fly</strong><div class="txt-xs">Ngực giữa · Máy cáp</div></div>
                <span class="pill pill-orange">+ Chọn</span>
              </div>
            </div>
            <div class="metric-box" style="margin-bottom:12px;cursor:pointer;" data-close-coach-modal data-coach-toast="Đã thêm Machine Chest Press vào Ngày 1">
              <div class="row-between">
                <div><strong class="txt-sm">Machine Chest Press</strong><div class="txt-xs">Ngực toàn phần · Máy tập</div></div>
                <span class="pill pill-orange">+ Chọn</span>
              </div>
            </div>
            <div class="grid-2" style="gap:8px;">
              <div class="field" style="margin-bottom:0;"><label>Số hiệp</label><div class="input-box tnum" style="height:44px;">3 hiệp</div></div>
              <div class="field" style="margin-bottom:0;"><label>Số lần (Reps)</label><div class="input-box tnum" style="height:44px;">12–15 lần</div></div>
            </div>
          </div>
        </div>
      </div>
    `
  }
]);
