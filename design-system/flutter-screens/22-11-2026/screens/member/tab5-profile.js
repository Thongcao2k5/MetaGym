// Meta Gym Flutter Mockups — MEMBER / 5. Hồ sơ (Từ ngoài vào trong)
window.METAGYM_SCREENS = window.METAGYM_SCREENS || {};
window.METAGYM_SCREENS.member = (window.METAGYM_SCREENS.member || []).concat([
  {
    id: 'member-profile',
    group: 'tab5-profile',
    groupLabel: '5. Hồ sơ',
    title: '5.1 Hồ sơ',
    shortFile: 'profile_page.dart',
    flutterFile: 'mobile-app/lib/features/profile/presentation/profile_page.dart',
    tag: 'P0 • 3.393 dòng',
    tagClass: 'p0',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body">
          <div class="mg-header">
            <div class="mg-logo">MG</div>
            <div class="mg-header-text">
              <div class="mg-eyebrow">META GYM</div>
              <div class="mg-title">Hồ sơ</div>
            </div>
          </div>

          <!-- _buildHeroProfileCard (đúng layout 64px avatar + camera badge + email + phone) -->
          <div class="card-warm-glass">
            <div class="row" style="gap:12px;">
              <div style="position:relative;cursor:pointer;" data-open-avatar title="Đổi ảnh đại diện">
                <div class="avatar-member" style="width:60px;height:60px;font-size:19px;">MQ</div>
                <div style="position:absolute;right:-2px;bottom:-2px;width:20px;height:20px;border-radius:50%;background:#2B2622;border:1px solid #B3A99D;display:flex;align-items:center;justify-content:center;"><img class="ico-xs" src="../../meta-gym/assets/svg/setting/common_camera.svg" alt="Đổi ảnh" /></div>
              </div>
              <div style="flex:1;min-width:0;">
                <div style="font-size:18px;font-weight:700;line-height:1.2;">Nguyễn Minh Quân</div>
                <div class="row" style="gap:8px;margin-top:3px;">
                  <span class="txt-xs" style="color:var(--text-secondary);">Hội viên</span>
                  <span class="txt-xs txt-green txt-bold">● Đang hoạt động</span>
                </div>
                <div class="txt-xs" style="color:var(--text-secondary);margin-top:7px;"><img class="ico-xs" src="../../meta-gym/assets/svg/community/comm_email.svg" alt="Email" /> <span style="vertical-align:middle;">minhquan@metagym.vn</span></div>
                <div class="txt-xs tnum" style="color:var(--text-secondary);margin-top:2px;"><img class="ico-xs" src="../../meta-gym/assets/svg/setting/call_audio_badge.svg" alt="SĐT" /> <span style="vertical-align:middle;">0909 123 456</span></div>
              </div>
              <span class="txt-xs">›</span>
            </div>
          </div>

          <!-- 3 _ProfileCategoryCard Accordions (Bấm tiêu đề để thu gọn / mở rộng) -->
          <div class="card-liquid accordion-card is-open" style="padding:13px 14px;">
            <div class="accordion-head" data-accordion-toggle>
              <div class="row"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/setting_personal_info.svg" alt="Cá nhân" /><strong class="txt-sm">Cá nhân &amp; thể trạng</strong></div>
              <div class="row" style="gap:6px;"><span class="count-pill">3</span><span class="accordion-chev">›</span></div>
            </div>
            <div class="accordion-body">
              <div class="divider"></div>
              <div class="accordion-row" data-go="member-personal-info"><span>Thông tin cá nhân</span><span class="txt-xs">›</span></div>
              <div class="accordion-row" data-go="member-training-profile"><span>Thể trạng &amp; Mục tiêu</span><span class="txt-xs">›</span></div>
              <div class="accordion-row" data-go="member-health-declaration"><span>Khai báo thể trạng cho Coach</span><span class="txt-xs">›</span></div>
            </div>
          </div>

          <div class="card-liquid accordion-card" style="padding:13px 14px;">
            <div class="accordion-head" data-accordion-toggle>
              <div class="row"><img class="ico-sm" src="../../meta-gym/assets/svg/catalog/equip_dumbbell.svg" alt="Tập luyện" /><strong class="txt-sm">Tập luyện &amp; dịch vụ</strong></div>
              <div class="row" style="gap:6px;"><span class="count-pill">3</span><span class="accordion-chev">›</span></div>
            </div>
            <div class="accordion-body">
              <div class="divider"></div>
              <div class="accordion-row" data-go="member-measurement"><span>Nhật ký &amp; Số đo cơ thể</span><span class="txt-xs">›</span></div>
              <div class="accordion-row" data-go="member-coaching"><span>Coach &amp; Lịch hẹn</span><span class="txt-xs">›</span></div>
              <div class="accordion-row" data-go="member-membership"><span>Gói tập &amp; Ưu đãi</span><span class="txt-xs">›</span></div>
            </div>
          </div>

          <div class="card-liquid accordion-card" style="padding:13px 14px;">
            <div class="accordion-head" data-accordion-toggle>
              <div class="row"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/setting_security_shield.svg" alt="Tài khoản" /><strong class="txt-sm">Tài khoản &amp; hỗ trợ</strong></div>
              <div class="row" style="gap:6px;"><span class="count-pill">5</span><span class="accordion-chev">›</span></div>
            </div>
            <div class="accordion-body">
              <div class="divider"></div>
              <div class="accordion-row" data-go="member-notifications"><span>Thông báo</span><span class="txt-xs">›</span></div>
              <div class="accordion-row" data-go="member-security"><span>Bảo mật &amp; Tài khoản</span><span class="txt-xs">›</span></div>
              <div class="accordion-row" data-go="member-privacy"><span>Quyền riêng tư &amp; Chia sẻ</span><span class="txt-xs">›</span></div>
              <div class="accordion-row" data-go="member-app-settings"><span>Cài đặt ứng dụng</span><span class="txt-xs">›</span></div>
              <div class="accordion-row" data-go="member-support"><span>Phòng tập &amp; Hỗ trợ</span><span class="txt-xs">›</span></div>
            </div>
          </div>

          <div class="card-liquid" data-open-logout style="padding:13px;text-align:center;color:var(--error);font-weight:600;font-size:14px;cursor:pointer;">
            <span class="row" style="justify-content:center;gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/setting_logout.svg" alt="Đăng xuất" /><span>Đăng xuất</span></span>
          </div>
        </div>

        <div class="bottom-nav-wrap">
          <nav class="bottom-nav">
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_home_outline.svg" alt="Trang chủ" /></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_training_outline.svg" alt="Tập luyện" /></div>
            <div class="nav-ai-wrap"><div class="nav-ai-btn"><img class="nav-ai-svg" src="../../meta-gym/assets/svg/navigation/nav_ai_on_primary.svg" alt="AI" /></div></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_messages_outline.svg" alt="Tin nhắn" /></div>
            <div class="nav-item active"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_profile_filled.svg" alt="Hồ sơ" /></div>
          </nav>
        </div>

        <!-- Level 3 Overlay Glass: Modal xác nhận đăng xuất -->
        <div class="qr-overlay" data-logout-modal>
          <div class="qr-sheet" style="text-align:center;">
            <div style="width:56px;height:56px;border-radius:50%;margin:0 auto 12px;background:rgba(241,91,100,0.16);border:1px solid rgba(241,91,100,0.45);display:flex;align-items:center;justify-content:center;">
              <img class="ico-md" src="../../meta-gym/assets/svg/setting/setting_logout.svg" alt="Đăng xuất" style="background:transparent;padding:0;" />
            </div>
            <div style="font-size:17px;font-weight:800;color:#F7F9FC;">Đăng xuất tài khoản?</div>
            <div style="font-size:12.5px;color:#9BA3B4;margin:6px 0 12px;line-height:1.5;">
              Bạn sẽ cần đăng nhập lại để quẹt thẻ NFC, xem lịch Coach và đồng bộ nhật ký tập luyện.
            </div>
            <div style="background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.10);border-radius:12px;padding:9px 12px;margin-bottom:14px;text-align:left;">
              <div style="font-size:12.5px;font-weight:700;color:#F7F9FC;">Nguyễn Minh Quân</div>
              <div style="font-size:11px;color:#8E95A5;margin-top:2px;">minhquan@metagym.vn · Hội viên Hạng Vàng</div>
            </div>
            <div class="grid-2" style="gap:10px;">
              <button type="button" class="btn-secondary" style="height:44px;" data-close-logout>Huỷ</button>
              <button type="button" class="btn-primary" style="height:44px;background:#E5484D;border-color:#F15B64;color:#FFFFFF;" data-confirm-logout>Đăng xuất</button>
            </div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'member-personal-info',
    group: 'tab5-profile',
    groupLabel: '5. Hồ sơ',
    title: '5.2 Thông tin cá nhân',
    shortFile: 'profile_page.dart (PersonalInfo)',
    flutterFile: 'mobile-app/lib/features/profile/presentation/profile_page.dart',
    tag: 'P1 • Hồ sơ cá nhân',
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
              <div class="mg-eyebrow">HỒ SƠ CÁ NHÂN</div>
              <div class="mg-title">Thông tin cá nhân</div>
            </div>
          </div>

          <!-- Card 1: Ảnh đại diện (Avatar) -->
          <div class="card-warm-glass">
            <div class="row" style="gap:14px;">
              <div style="position:relative;cursor:pointer;" data-open-avatar title="Đổi ảnh đại diện">
                <div class="avatar-ln" style="width:64px;height:64px;font-size:20px;border:1.8px solid var(--primary);">MQ</div>
                <div style="position:absolute;right:-2px;bottom:-2px;width:24px;height:24px;border-radius:50%;background:var(--primary);border:2px solid #282320;display:flex;align-items:center;justify-content:center;">
                  <img src="../../meta-gym/assets/svg/setting/common_camera.svg" alt="Đổi ảnh" style="width:14px;height:14px;background:transparent;padding:0;" />
                </div>
              </div>
              <div style="flex:1;min-width:0;">
                <div style="font-size:15px;font-weight:700;">Ảnh đại diện (Avatar)</div>
                <div class="txt-xs" style="margin:2px 0 8px;">Quyền truy cập thư viện: Cho phép</div>
                <span class="btn-mini-orange" data-open-avatar style="border-radius:10px;height:32px;padding:0 11px;cursor:pointer;">
                  <img class="ico-xs" src="../../meta-gym/assets/svg/setting/media_gallery.svg" alt="Thư viện" style="background:transparent;padding:0;" />
                  <span>Tải ảnh từ điện thoại</span>
                </span>
              </div>
            </div>
          </div>

          <!-- Card 2: Form Thông tin cá nhân -->
          <div class="card-liquid" style="padding:16px;">
            <div class="field">
              <label>Họ và tên</label>
              <div class="input-box focus">
                <span class="row" style="gap:8px;">
                  <img class="ico-sm" src="../../meta-gym/assets/svg/setting/setting_personal_info.svg" alt="Họ tên" />
                  <span>Nguyễn Minh Quân</span>
                </span>
              </div>
            </div>

            <div class="field">
              <label>Số điện thoại</label>
              <div class="input-box">
                <span class="row" style="gap:8px;">
                  <img class="ico-sm" src="../../meta-gym/assets/svg/setting/call_audio_badge.svg" alt="SĐT" />
                  <span class="tnum">0909 123 456</span>
                </span>
              </div>
            </div>

            <div class="field">
              <label>Ngày sinh</label>
              <div class="input-box">
                <span class="tnum" style="font-weight:600;">14/05/1999</span>
                <img class="ico-sm" src="../../meta-gym/assets/svg/workout/workout_plan_calendar.svg" alt="Ngày sinh" />
              </div>
            </div>

            <div style="font-size:12.5px;font-weight:600;color:var(--text-secondary);margin:12px 0 8px;">Giới tính</div>
            <div class="row" style="flex-wrap:wrap;gap:8px;">
              <span class="filter-pill active">Nam</span>
              <span class="filter-pill">Nữ</span>
              <span class="filter-pill">Khác</span>
              <span class="filter-pill">Không tiết lộ</span>
            </div>
          </div>
        </div>

        <div class="bottom-cta-dock">
          <button class="btn-primary">Lưu thay đổi</button>
        </div>
      </div>
    `
  },
  {
    id: 'member-training-profile',
    group: 'tab5-profile',
    groupLabel: '5. Hồ sơ',
    title: '5.3 Thể trạng & Mục tiêu',
    shortFile: 'profile_page.dart (TrainingProfile)',
    flutterFile: 'mobile-app/lib/features/profile/presentation/profile_page.dart',
    tag: 'P1 • Thể trạng',
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
              <div class="mg-eyebrow">HỒ SƠ CÁ NHÂN</div>
              <div class="mg-title">Thể trạng &amp; Mục tiêu</div>
            </div>
          </div>

          <!-- Card 1: Mục tiêu tập luyện + Presets -->
          <div class="card-liquid" style="padding:15px;">
            <div class="row" style="gap:7px;margin-bottom:8px;">
              <img class="ico-sm" src="../../meta-gym/assets/svg/setting/setting_training_goal.svg" alt="Mục tiêu" />
              <strong style="font-size:13.5px;">Mục tiêu tập luyện</strong>
            </div>
            <div class="input-box focus" style="height:auto;padding:10px 12px;margin-bottom:10px;font-size:13px;line-height:1.4;">
              Tăng cơ giảm mỡ · Duy trì 4 buổi/tuần
            </div>
            <div class="row" style="flex-wrap:wrap;gap:6px;">
              <span class="filter-pill active" style="font-size:11px;padding:5px 10px;">Tăng cơ giảm mỡ · 4 buổi/tuần</span>
              <span class="filter-pill" style="font-size:11px;padding:5px 10px;">Giảm mỡ siết cơ · Cardio &amp; HIIT</span>
              <span class="filter-pill" style="font-size:11px;padding:5px 10px;">Tăng sức mạnh tối đa</span>
              <span class="filter-pill" style="font-size:11px;padding:5px 10px;">Cải thiện sức bền &amp; Phục hồi</span>
            </div>
          </div>

          <!-- Card 2: Chiều cao (Thước đo kéo trượt trực tiếp + Mở thước laser 3D) -->
          <div class="card-liquid" style="padding:15px;" data-inline-height-card>
            <div class="row-between" style="margin-bottom:4px;">
              <div class="row" style="gap:7px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/progress/body_measure_tape.svg" alt="Chiều cao" />
                <strong style="font-size:13.5px;">Chiều cao</strong>
              </div>
              <div class="row" style="gap:8px;">
                <span class="tnum txt-orange" style="font-size:19px;font-weight:800;cursor:pointer;" data-height-readout data-open-body-picker="height" data-value="174">174 cm</span>
                <span class="pill pill-orange" style="cursor:pointer;font-size:10px;padding:3px 8px;" data-open-body-picker="height" data-value="174">Thước laser ↗</span>
              </div>
            </div>
            <div class="txt-xs" style="margin-bottom:4px;">Kéo thước trái/phải hoặc mở thước đo đứng</div>
            <div class="inline-ruler-wrap" data-inline-ruler="height" data-min="120" data-max="220" data-val="174">
              <div class="inline-ruler-needle"></div>
              <div class="inline-ruler-track"></div>
            </div>
            <div class="row-between txt-xs tnum"><span>120 cm</span><span data-height-ft>5'9" · Chuẩn thể hình</span><span>220 cm</span></div>
          </div>

          <!-- Card 3: Trình độ & Mức độ vận động -->
          <div class="card-liquid" style="padding:15px;">
            <div style="font-size:13px;font-weight:700;margin-bottom:8px;">Trình độ tập luyện</div>
            <div class="row" style="flex-wrap:wrap;gap:8px;margin-bottom:16px;">
              <span class="filter-pill">Mới bắt đầu</span>
              <span class="filter-pill active">Trung cấp</span>
              <span class="filter-pill">Nâng cao</span>
            </div>

            <div style="font-size:13px;font-weight:700;margin-bottom:8px;">Mức độ vận động hàng ngày</div>
            <div class="row" style="flex-wrap:wrap;gap:8px;">
              <span class="filter-pill">Ít vận động</span>
              <span class="filter-pill active">Trung bình</span>
              <span class="filter-pill">Vận động cao</span>
            </div>
          </div>
        </div>

        <div class="bottom-cta-dock">
          <button class="btn-primary">Lưu thay đổi</button>
        </div>
      </div>
    `
  },
  {
    id: 'member-health-declaration',
    group: 'tab5-profile',
    groupLabel: '5. Hồ sơ',
    title: '5.4 Khai báo thể trạng',
    shortFile: 'member_health_declaration_page.dart',
    flutterFile: 'mobile-app/lib/features/coaching/presentation/member_health_declaration_page.dart',
    tag: 'P1 • Sức khỏe & PAR-Q',
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
              <div class="mg-eyebrow">HỒ SƠ SỨC KHỎE &amp; THỂ TRẠNG</div>
              <div class="mg-title">Khai báo thể trạng</div>
            </div>
          </div>

          <!-- Hero Summary Card -->
          <div class="card-warm-glass">
            <div class="row" style="gap:11px;margin-bottom:10px;">
              <div class="quick-ico"><img class="ico-md" src="../../meta-gym/assets/svg/coaching/health_shield.svg" alt="Thể trạng" /></div>
              <div style="flex:1;min-width:0;">
                <div style="font-size:15px;font-weight:700;">Tóm tắt thể trạng</div>
                <div class="txt-xs">Đồng bộ trực tiếp với Huấn luyện viên phụ trách</div>
              </div>
            </div>
            <div style="margin-bottom:10px;">
              <span class="pill pill-success tnum" data-bmi-pill>● BMI 23.9 · Bình thường</span>
            </div>
            <div class="grid-3">
              <div class="metric-box" style="padding:8px 8px;cursor:pointer;" data-open-body-picker="height" data-value="174">
                <div class="txt-xs">Chiều cao</div>
                <div class="tnum txt-bold" style="font-size:15px;margin-top:2px;" data-summary-height>174 cm</div>
              </div>
              <div class="metric-box" style="padding:8px 8px;cursor:pointer;" data-open-body-picker="weight" data-value="72.4">
                <div class="txt-xs">Cân nặng</div>
                <div class="tnum txt-bold" style="font-size:15px;margin-top:2px;" data-summary-weight>72.4 kg</div>
              </div>
              <div class="metric-box" style="padding:8px 8px;">
                <div class="txt-xs">Tỷ lệ mỡ</div>
                <div class="tnum txt-bold" style="font-size:15px;margin-top:2px;">16.8%</div>
              </div>
            </div>
          </div>

          <div class="txt-xs" style="margin-bottom:12px;line-height:1.45;">
            Cung cấp chỉ số cơ thể và lưu ý về bệnh nền hoặc chấn thương để Coach lên giáo án an toàn, phù hợp nhất.
          </div>

          <!-- Solid Form Section 1: Chỉ số cơ thể hiện tại -->
          <div class="card-solid" style="padding:15px;">
            <div class="row-between" style="margin-bottom:12px;">
              <div class="row" style="gap:7px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/progress/body_measure_tape.svg" alt="Chỉ số" />
                <strong style="font-size:14px;">Chỉ số cơ thể hiện tại</strong>
              </div>
              <span class="txt-xs" style="color:var(--primary);">Chạm để đo ↗</span>
            </div>
            <div class="grid-2">
              <div class="field" style="margin-bottom:10px;">
                <label>Chiều cao · cm</label>
                <div class="input-box tnum" style="cursor:pointer;" data-open-body-picker="height" data-value="174"><span data-field-height>174</span><span class="txt-xs">cm</span></div>
              </div>
              <div class="field" style="margin-bottom:10px;">
                <label>Cân nặng · kg</label>
                <div class="input-box tnum" style="cursor:pointer;" data-open-body-picker="weight" data-value="72.4"><span data-field-weight>72.4</span><span class="txt-xs">kg</span></div>
              </div>
            </div>
            <div class="field" style="margin-bottom:0;">
              <label>Tỷ lệ mỡ · % · tùy chọn</label>
              <div class="input-box tnum"><span>16.8</span><span class="txt-xs">%</span></div>
            </div>
          </div>

          <!-- Solid Form Section 2: Bệnh nền & Chấn thương -->
          <div class="card-solid" style="padding:15px;">
            <div class="row" style="gap:7px;margin-bottom:12px;">
              <img class="ico-sm" src="../../meta-gym/assets/svg/coaching/health_medical.svg" alt="Y tế" />
              <strong style="font-size:14px;">Bệnh nền &amp; Chấn thương</strong>
            </div>
            <div class="field">
              <label>Tiền sử chấn thương</label>
              <div class="input-box" style="height:auto;padding:10px 12px;font-size:13px;line-height:1.4;">
                Đau nhẹ khớp vai phải khi đẩy tạ nặng trên 80 kg
              </div>
            </div>
            <div class="field" style="margin-bottom:0;">
              <label>Bệnh nền / Lưu ý y tế</label>
              <div class="input-box" style="font-size:13px;">Không có bệnh nền tim mạch hay huyết áp</div>
            </div>
          </div>
        </div>

        <div class="bottom-cta-dock">
          <button class="btn-primary">Lưu khai báo thể trạng</button>
        </div>
      </div>
    `
  },
  {
    id: 'member-measurement',
    group: 'tab5-profile',
    groupLabel: '5. Hồ sơ',
    title: '5.5 Nhật ký tập luyện & Số đo',
    shortFile: 'member_measurement_page.dart',
    flutterFile: 'mobile-app/lib/features/progress/presentation/member_measurement_page.dart',
    tag: 'P1 • Số đo cơ thể',
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
              <div class="mg-eyebrow">TIẾN ĐỘ &amp; SỐ ĐO</div>
              <div class="mg-title">Nhật ký &amp; Số đo</div>
            </div>
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_add.svg" alt="Thêm" /></div>
          </div>

          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:10px;">
              <div class="row" style="gap:7px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/progress/body_weight_scale.svg" alt="Số đo" />
                <strong style="font-size:15px;">Chỉ số mới nhất</strong>
              </div>
              <span class="pill pill-success tnum">22/11/2026</span>
            </div>
            <div class="grid-3">
              <div class="metric-box" style="text-align:center;padding:8px 4px;">
                <div class="txt-xs">Cân nặng</div>
                <div class="tnum txt-bold" style="font-size:16px;margin-top:2px;">72.4 kg</div>
                <div class="txt-xs txt-green tnum">-1.2 kg</div>
              </div>
              <div class="metric-box" style="text-align:center;padding:8px 4px;">
                <div class="txt-xs">Mỡ cơ thể</div>
                <div class="tnum txt-bold" style="font-size:16px;margin-top:2px;">16.8%</div>
                <div class="txt-xs txt-green tnum">-0.9%</div>
              </div>
              <div class="metric-box" style="text-align:center;padding:8px 4px;">
                <div class="txt-xs">BMI</div>
                <div class="tnum txt-bold" style="font-size:16px;margin-top:2px;">23.9</div>
                <div class="txt-xs txt-green">Chuẩn</div>
              </div>
            </div>
          </div>

          <div class="sec-head"><h3>Lịch sử số đo vòng</h3><span class="txt-xs tnum">3 bản ghi</span></div>
          <div class="card-liquid" style="padding:13px 14px;margin-bottom:9px;">
            <div class="row-between" style="margin-bottom:8px;">
              <strong class="txt-sm tnum">22/11/2026</strong>
              <span class="pill pill-orange tnum">72.4 kg · 16.8%</span>
            </div>
            <div class="grid-3 tnum" style="text-align:center;">
              <div class="txt-xs">Ngực <strong style="color:var(--text-primary);display:block;">98 cm</strong></div>
              <div class="txt-xs">Eo <strong style="color:var(--text-primary);display:block;">78 cm</strong></div>
              <div class="txt-xs">Hông <strong style="color:var(--text-primary);display:block;">94 cm</strong></div>
            </div>
          </div>

          <div class="card-liquid" style="padding:13px 14px;">
            <div class="row-between" style="margin-bottom:8px;">
              <strong class="txt-sm tnum">08/11/2026</strong>
              <span class="pill pill-muted tnum">73.6 kg · 17.7%</span>
            </div>
            <div class="grid-3 tnum" style="text-align:center;">
              <div class="txt-xs">Ngực <strong style="color:var(--text-primary);display:block;">97 cm</strong></div>
              <div class="txt-xs">Eo <strong style="color:var(--text-primary);display:block;">80 cm</strong></div>
              <div class="txt-xs">Hông <strong style="color:var(--text-primary);display:block;">95 cm</strong></div>
            </div>
          </div>
        </div>

        <div class="bottom-cta-dock">
          <button class="btn-primary">+ Ghi nhận số đo mới</button>
        </div>
      </div>
    `
  },
  {
    id: 'member-coaching',
    group: 'tab5-profile',
    groupLabel: '5. Hồ sơ',
    title: '5.6a Coach & Lịch hẹn (Đã có Coach)',
    shortFile: 'member_coaching_page.dart',
    flutterFile: 'mobile-app/lib/features/coaching/presentation/member_coaching_page.dart',
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
              <div class="mg-eyebrow">COACHING 1:1</div>
              <div class="mg-title">Coach &amp; Lịch hẹn</div>
            </div>
          </div>

          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:10px;">
              <div class="row" style="gap:10px;">
                <div class="avatar-ln" style="width:46px;height:46px;font-size:15px;">LN</div>
                <div>
                  <div style="font-size:16px;font-weight:700;">Lê Hoàng Nam</div>
                  <div class="txt-xs">Coach cá nhân · Hypertrophy</div>
                </div>
              </div>
              <span class="pill pill-success">Hiệu lực</span>
            </div>
            <div class="grid-2" style="margin-bottom:12px;">
              <div class="metric-box"><div class="txt-xs">Buổi PT còn lại</div><div class="tnum txt-bold" style="font-size:18px;">14 / 24</div></div>
              <div class="metric-box"><div class="txt-xs">Hết hạn gói</div><div class="tnum txt-bold" style="font-size:18px;">03/01/27</div></div>
            </div>
            <button class="btn-primary">Xem lịch với Coach</button>
          </div>

          <!-- 3 Lối vào nhanh từ member_coaching_page.dart -->
          <div class="card-liquid" style="padding:4px 14px;">
            <div class="row-between" style="padding:11px 0;">
              <div class="row"><img class="ico-sm" src="../../meta-gym/assets/svg/quick_actions/action_curriculum.svg" alt="Giáo trình" /><div><div class="txt-sm txt-bold">Giáo trình</div><div class="txt-xs">Tập luyện và dinh dưỡng</div></div></div>
              <span class="txt-xs">›</span>
            </div>
            <div class="divider" style="margin:0;"></div>
            <div class="row-between" style="padding:11px 0;">
              <div class="row"><img class="ico-sm" src="../../meta-gym/assets/svg/community/comm_chat.svg" alt="Nhắn Coach" /><div><div class="txt-sm txt-bold">Nhắn Coach</div><div class="txt-xs">Trao đổi trực tiếp</div></div></div>
              <span class="txt-xs">›</span>
            </div>
            <div class="divider" style="margin:0;"></div>
            <div class="row-between" style="padding:11px 0;">
              <div class="row"><img class="ico-sm" src="../../meta-gym/assets/svg/coaching/coach_pkg_1on1.svg" alt="Gói Coach" /><div><div class="txt-sm txt-bold">Gói Coach</div><div class="txt-xs">Xem quyền lợi và thời hạn</div></div></div>
              <span class="txt-xs">›</span>
            </div>
            <div class="divider" style="margin:0;"></div>
            <div class="row-between" style="padding:11px 0;">
              <div class="row"><img class="ico-sm" src="../../meta-gym/assets/svg/coaching/outcome_consent_badge.svg" alt="Thành quả" /><div><div class="txt-sm txt-bold">Duyệt thành quả của bạn</div><div class="txt-xs">Quản lý chia sẻ kết quả tập luyện</div></div></div>
              <span class="txt-xs">›</span>
            </div>
          </div>

          <div class="card-liquid" style="padding:12px;text-align:center;color:var(--error);font-size:13px;font-weight:600;">
            Yêu cầu kết thúc sớm gói Coach
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'member-coaching-empty',
    group: 'tab5-profile',
    groupLabel: '5. Hồ sơ',
    title: '5.6b Coach & Lịch hẹn (Chưa có Coach)',
    shortFile: 'member_coaching_page.dart (Empty)',
    flutterFile: 'mobile-app/lib/features/coaching/presentation/member_coaching_page.dart',
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
              <div class="mg-eyebrow">COACHING 1:1</div>
              <div class="mg-title">Coach &amp; Lịch hẹn</div>
            </div>
          </div>

          <div class="card-warm-glass" style="text-align:center;padding:24px 18px;">
            <div style="width:62px;height:62px;border-radius:50%;margin:0 auto 12px;background:rgba(255,94,54,0.16);border:1px solid rgba(255,94,54,0.45);display:flex;align-items:center;justify-content:center;">
              <img class="ico-lg" src="../../meta-gym/assets/svg/states/empty_coach.svg" alt="Chưa có Coach" style="background:transparent;padding:0;" />
            </div>
            <div style="font-size:18px;font-weight:800;">Chưa có Coach</div>
            <div class="txt-xs" style="margin:6px 0 18px;line-height:1.5;">
              Xem hồ sơ, lịch làm việc và các gói huấn luyện trước khi chọn Coach đồng hành cho mình.
            </div>
            <button class="btn-primary" data-go="member-coach-selection">Khám phá Coach →</button>
          </div>

          <div class="card-solid" style="padding:14px;">
            <div class="txt-sm txt-bold" style="margin-bottom:10px;">Bắt đầu tập 1:1 trong 3 bước</div>
            <div class="row" style="gap:10px;margin-bottom:8px;" data-go="member-health-declaration">
              <span class="pill pill-orange tnum">1</span>
              <div style="flex:1;"><div class="txt-sm txt-bold">Khai báo thể trạng</div><div class="txt-xs">Cập nhật chiều cao, cân nặng &amp; chấn thương</div></div>
              <span class="txt-xs">›</span>
            </div>
            <div class="divider"></div>
            <div class="row" style="gap:10px;margin-bottom:8px;" data-go="member-coach-selection">
              <span class="pill pill-muted tnum">2</span>
              <div style="flex:1;"><div class="txt-sm txt-bold">Chọn Coach &amp; Gói tập</div><div class="txt-xs">So sánh chuyên môn, đánh giá &amp; lịch rảnh</div></div>
              <span class="txt-xs">›</span>
            </div>
            <div class="divider"></div>
            <div class="row" style="gap:10px;">
              <span class="pill pill-muted tnum">3</span>
              <div style="flex:1;"><div class="txt-sm txt-bold">Đặt lịch buổi tập 90 phút</div><div class="txt-xs">Nhận giáo trình &amp; thực đơn cá nhân hóa</div></div>
            </div>
          </div>
        </div>
      </div>
    `
  }
]);
