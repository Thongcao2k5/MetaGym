// Meta Gym Flutter Mockups — MEMBER / 5. Hồ sơ (Các trang con 5.7 -> 5.14)
window.METAGYM_SCREENS = window.METAGYM_SCREENS || {};
window.METAGYM_SCREENS.member = (window.METAGYM_SCREENS.member || []).concat([
  {
    id: 'member-coach-selection',
    group: 'tab5-profile',
    groupLabel: '5. Hồ sơ',
    title: '5.7 Khám phá Coach',
    shortFile: 'coach_selection_page.dart',
    flutterFile: 'mobile-app/lib/features/coaching/presentation/coach_selection_page.dart',
    tag: 'P1 • Danh sách Coach',
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
              <div class="mg-eyebrow">HUẤN LUYỆN VIÊN</div>
              <div class="mg-title">Khám phá Coach</div>
            </div>
          </div>

          <div class="input-box" style="height:42px;margin-bottom:10px;color:var(--text-secondary);font-size:14px;">
            <span class="row" style="gap:8px;"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_search.svg" alt="Tìm" /><span>Tìm tên hoặc chuyên môn Coach...</span></span>
          </div>

          <div class="filter-row">
            <div class="filter-pill active">Tất cả</div>
            <div class="filter-pill">Còn suất</div>
            <div class="filter-pill">Tăng cơ</div>
            <div class="filter-pill">Giảm mỡ</div>
          </div>

          <div class="card-liquid" style="padding:14px;">
            <div class="row" style="gap:11px;margin-bottom:10px;">
              <div class="avatar-ln" style="width:48px;height:48px;font-size:16px;">LN</div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong style="font-size:15px;">Lê Hoàng Nam</strong>
                  <span class="pill pill-success tnum">Còn 2 suất</span>
                </div>
                <div class="txt-xs" style="margin-top:2px;">Hypertrophy &amp; Sức mạnh · 6 năm KN</div>
                <div class="row" style="gap:6px;margin-top:4px;">
                  <img class="ico-xs" src="../../meta-gym/assets/svg/community/social_star_rating.svg" alt="Đánh giá" />
                  <span class="txt-xs tnum txt-bold" style="color:var(--text-primary);">4.9</span>
                  <span class="txt-xs tnum">(48 đánh giá)</span>
                </div>
              </div>
            </div>
            <div class="row-between">
              <span class="txt-xs tnum">Từ <strong style="color:var(--text-primary);">400.000đ</strong> / buổi</span>
              <span class="btn-mini-orange">Xem hồ sơ ›</span>
            </div>
          </div>

          <div class="card-liquid" style="padding:14px;">
            <div class="row" style="gap:11px;margin-bottom:10px;">
              <div class="avatar-member" style="width:48px;height:48px;font-size:15px;background:#2E4057;">MD</div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong style="font-size:15px;">Trần Minh Đức</strong>
                  <span class="pill pill-success tnum">Còn 4 suất</span>
                </div>
                <div class="txt-xs" style="margin-top:2px;">Giảm mỡ &amp; Phục hồi · 4 năm KN</div>
                <div class="row" style="gap:6px;margin-top:4px;">
                  <img class="ico-xs" src="../../meta-gym/assets/svg/community/social_star_rating.svg" alt="Đánh giá" />
                  <span class="txt-xs tnum txt-bold" style="color:var(--text-primary);">4.8</span>
                  <span class="txt-xs tnum">(31 đánh giá)</span>
                </div>
              </div>
            </div>
            <div class="row-between">
              <span class="txt-xs tnum">Từ <strong style="color:var(--text-primary);">360.000đ</strong> / buổi</span>
              <span class="btn-mini-orange">Xem hồ sơ ›</span>
            </div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'member-coach-detail',
    group: 'tab5-profile',
    groupLabel: '5. Hồ sơ',
    title: '5.8 Chi tiết Coach',
    shortFile: 'coach_detail_page.dart',
    flutterFile: 'mobile-app/lib/features/coaching/presentation/coach_detail_page.dart',
    tag: 'P1 • Hồ sơ Coach',
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
              <div class="mg-eyebrow">HỒ SƠ HUẤN LUYỆN VIÊN</div>
              <div class="mg-title">Lê Hoàng Nam</div>
            </div>
          </div>

          <div class="card-warm-glass">
            <div class="row" style="gap:12px;margin-bottom:12px;">
              <div class="avatar-ln" style="width:58px;height:58px;font-size:20px;">LN</div>
              <div style="flex:1;">
                <div style="font-size:20px;font-weight:800;">Lê Hoàng Nam</div>
                <div class="txt-xs" style="margin-top:2px;">Chuyên gia Hypertrophy &amp; Sức mạnh</div>
                <div class="row" style="gap:6px;margin-top:5px;">
                  <span class="pill pill-success tnum">Còn 2 suất</span>
                  <span class="pill pill-warning tnum">★ 4.9</span>
                </div>
              </div>
            </div>
            <div class="grid-3">
              <div class="metric-box" style="text-align:center;padding:8px 4px;"><div class="tnum txt-bold">6 năm</div><div class="txt-xs">Kinh nghiệm</div></div>
              <div class="metric-box" style="text-align:center;padding:8px 4px;"><div class="tnum txt-bold">12</div><div class="txt-xs">Học viên</div></div>
              <div class="metric-box" style="text-align:center;padding:8px 4px;"><div class="tnum txt-bold">90p</div><div class="txt-xs">Mỗi ca tập</div></div>
            </div>
          </div>

          <div class="card-liquid" style="padding:14px;">
            <div class="row" style="gap:7px;margin-bottom:6px;">
              <img class="ico-sm" src="../../meta-gym/assets/svg/coaching/coach_achievement.svg" alt="Chứng chỉ" />
              <strong class="txt-sm">Chứng chỉ &amp; Giới thiệu</strong>
            </div>
            <div class="row" style="flex-wrap:wrap;gap:6px;margin-bottom:8px;">
              <span class="pill pill-orange">NASM-CPT</span>
              <span class="pill pill-muted">CSCS Strength</span>
              <span class="pill pill-muted">Dinh dưỡng thể hình</span>
            </div>
            <div class="txt-xs" style="line-height:1.5;">
              Chuyên thiết kế giáo án tăng cơ bền vững, chỉnh kỹ thuật Squat/Bench/Deadlift an toàn và theo sát thực đơn hàng ngày cho người bận rộn.
            </div>
          </div>

          <div class="card-liquid" style="padding:14px;">
            <div class="row" style="gap:7px;margin-bottom:6px;">
              <img class="ico-sm" src="../../meta-gym/assets/svg/quick_actions/action_coach_workweek.svg" alt="Lịch dạy" />
              <strong class="txt-sm">Lịch dạy cố định</strong>
            </div>
            <div class="txt-xs tnum">Thứ 2 – Thứ 7 · 06:30 – 20:30 · Khung 90 phút/buổi</div>
          </div>
        </div>

        <div class="bottom-cta-dock">
          <button class="btn-primary">Xem các gói Coach →</button>
        </div>
      </div>
    `
  },
  {
    id: 'member-coach-offers',
    group: 'tab5-profile',
    groupLabel: '5. Hồ sơ',
    title: '5.9 Xem gói Coach',
    shortFile: 'coach_offers_page.dart',
    flutterFile: 'mobile-app/lib/features/coaching/presentation/coach_offers_page.dart',
    tag: 'P1 • Bảng giá PT',
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
              <div class="mg-eyebrow">GÓI COACHING 1:1</div>
              <div class="mg-title">Gói của Lê Hoàng Nam</div>
            </div>
          </div>

          <!-- Khai báo thể trạng status -->
          <div class="card-liquid" style="padding:11px 14px;">
            <div class="row-between">
              <div class="row" style="gap:8px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/coaching/health_shield.svg" alt="Thể trạng" />
                <div>
                  <div class="txt-xs txt-green txt-bold">● Đã khai báo thể trạng</div>
                  <div class="txt-xs">174 cm · 72.4 kg · Sẵn sàng thuê Coach</div>
                </div>
              </div>
              <span class="sec-link">Xem / sửa</span>
            </div>
          </div>

          <!-- Ưu đãi Hạng Vàng tự động giảm phí Coach -->
          <div class="card-solid" style="padding:10px 13px;border-color:rgba(218,176,102,0.5);margin-bottom:10px;">
            <div class="row-between">
              <div class="row" style="gap:7px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/membership/premium_crown.svg" alt="Hạng Vàng" />
                <div>
                  <div class="txt-xs txt-bold" style="color:var(--warning);">Đặc quyền Thẻ Vàng đang áp dụng</div>
                  <div class="txt-xs">Giảm trực tiếp 5% mọi gói Coach 1:1 + Tích Meta Points</div>
                </div>
              </div>
              <span class="pill pill-orange tnum">-5%</span>
            </div>
          </div>

          <!-- Gói nổi bật -->
          <div class="card-warm-glass" style="border-color:rgba(255,94,54,0.65);">
            <div class="row-between" style="margin-bottom:6px;">
              <div class="row" style="gap:6px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/coaching/coach_pkg_intensive.svg" alt="Gói 24 buổi" />
                <strong style="font-size:16px;">Gói Chuyên Sâu 24 buổi</strong>
              </div>
              <span class="pill pill-orange">Phổ biến</span>
            </div>
            <div class="tnum" style="font-size:22px;font-weight:800;margin:4px 0;">8.455.000đ <span class="txt-xs" style="text-decoration:line-through;opacity:0.65;">8.900.000đ</span></div>
            <div class="txt-xs" style="margin-bottom:12px;">24 buổi tập 1:1 (90 phút) · Giáo trình riêng + Thực đơn tuần + Hỗ trợ chat 24/7</div>
            <button class="btn-primary" data-go="member-checkout">Chọn gói &amp; Thanh toán</button>
          </div>

          <!-- Gói tiêu chuẩn -->
          <div class="card-liquid" style="padding:14px;">
            <div class="row-between" style="margin-bottom:4px;">
              <div class="row" style="gap:6px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/coaching/coach_pkg_standard.svg" alt="Gói 12 buổi" />
                <strong style="font-size:15px;">Gói Tiêu Chuẩn 12 buổi</strong>
              </div>
              <span class="txt-xs tnum">45 ngày</span>
            </div>
            <div class="tnum" style="font-size:20px;font-weight:800;margin:4px 0 8px;">4.560.000đ <span class="txt-xs" style="text-decoration:line-through;opacity:0.65;">4.800.000đ</span></div>
            <div class="row-between">
              <span class="txt-xs">12 buổi 1:1 · Giáo trình cá nhân</span>
              <span class="btn-secondary" data-go="member-checkout" style="height:32px;font-size:12px;cursor:pointer;">Chọn gói</span>
            </div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'member-notifications',
    group: 'tab5-profile',
    groupLabel: '5. Hồ sơ',
    title: '5.10 Thông báo',
    shortFile: 'coach_notifications_page.dart',
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
              <div class="mg-eyebrow">META GYM</div>
              <div class="mg-title">Thông báo</div>
            </div>
            <span class="sec-link" style="font-size:12px;">Đọc tất cả</span>
          </div>

          <div class="sec-head" style="margin-top:4px;"><h3>Hôm nay</h3><span class="pill pill-orange tnum">2 chưa đọc</span></div>
          <div class="card-liquid" style="padding:13px;border-color:rgba(255,94,54,0.45);">
            <div class="row" style="align-items:flex-start;">
              <div class="quick-ico"><img class="ico-md" src="../../meta-gym/assets/svg/community/comm_notification_unread.svg" alt="Chưa đọc" /></div>
              <div style="flex:1;">
                <div class="row-between"><strong class="txt-sm">Sắp đến giờ tập với Coach</strong><span class="txt-xs tnum txt-orange">15 phút trước</span></div>
                <div class="txt-xs" style="margin-top:3px;">Buổi Upper Body &amp; Core lúc 18:00 cùng HLV Lê Hoàng Nam tại khu Free Weight.</div>
              </div>
            </div>
          </div>

          <div class="card-liquid" style="padding:13px;border-color:rgba(255,94,54,0.45);">
            <div class="row" style="align-items:flex-start;">
              <div class="quick-ico"><img class="ico-md" src="../../meta-gym/assets/svg/quick_actions/action_nutrition.svg" alt="Dinh dưỡng" /></div>
              <div style="flex:1;">
                <div class="row-between"><strong class="txt-sm">Coach đã cập nhật thực đơn</strong><span class="txt-xs tnum txt-orange">2 giờ trước</span></div>
                <div class="txt-xs" style="margin-top:3px;">Thực đơn "Tăng cơ sạch — Tuần 4" đã sẵn sàng trong mục Dinh dưỡng.</div>
              </div>
            </div>
          </div>

          <div class="sec-head"><h3>Trước đó</h3></div>
          <div class="card-liquid" style="padding:13px;opacity:0.82;">
            <div class="row" style="align-items:flex-start;">
              <div class="quick-ico" style="background:rgba(46,204,113,0.14);"><img class="ico-md" src="../../meta-gym/assets/svg/membership/payment_success.svg" alt="Thanh toán" /></div>
              <div style="flex:1;">
                <div class="row-between"><strong class="txt-sm">Thanh toán gói tập thành công</strong><span class="txt-xs tnum">20/11</span></div>
                <div class="txt-xs" style="margin-top:3px;">Gói Hội viên 3 Tháng đã được kích hoạt đến 03/01/2027.</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'member-security',
    group: 'tab5-profile',
    groupLabel: '5. Hồ sơ',
    title: '5.11 Bảo mật & Tài khoản',
    shortFile: 'profile_page.dart (Security)',
    flutterFile: 'mobile-app/lib/features/profile/presentation/profile_page.dart',
    tag: 'P1 • Bảo mật',
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
              <div class="mg-eyebrow">TÀI KHOẢN &amp; THIẾT BỊ</div>
              <div class="mg-title">Bảo mật &amp; Tài khoản</div>
            </div>
          </div>

          <div class="card-warm-glass">
            <div class="row" style="gap:10px;">
              <div class="quick-ico"><img class="ico-md" src="../../meta-gym/assets/svg/setting/setting_security_shield.svg" alt="Bảo mật" /></div>
              <div style="flex:1;min-width:0;">
                <div class="txt-sm txt-bold">minhquan@metagym.vn</div>
                <div class="txt-xs txt-green">● Tài khoản Hội viên · Đang hoạt động</div>
              </div>
            </div>
          </div>

          <div class="card-solid" style="padding:15px;">
            <div class="row" style="gap:7px;margin-bottom:12px;">
              <img class="ico-sm" src="../../meta-gym/assets/svg/setting/setting_password_key.svg" alt="Mật khẩu" />
              <strong style="font-size:14px;">Đổi mật khẩu đăng nhập</strong>
            </div>
            <div class="field">
              <label>Mật khẩu hiện tại</label>
              <div class="input-box pass-input-box">
                <input type="password" class="pass-field-input" value="MetaGym@2025" aria-label="Mật khẩu hiện tại" />
                <button type="button" class="pass-eye-btn" data-toggle-pass aria-label="Hiện mật khẩu" title="Hiện mật khẩu" aria-pressed="false">
                  <img class="ico-sm" src="../../meta-gym/assets/svg/setting/auth_show_password.svg" alt="Hiện mật khẩu" />
                </button>
              </div>
            </div>
            <div class="field">
              <label>Mật khẩu mới</label>
              <div class="input-box focus pass-input-box">
                <input type="password" class="pass-field-input" value="MetaGym#2026" aria-label="Mật khẩu mới" />
                <button type="button" class="pass-eye-btn" data-toggle-pass aria-label="Hiện mật khẩu" title="Hiện mật khẩu" aria-pressed="false">
                  <img class="ico-sm" src="../../meta-gym/assets/svg/setting/auth_show_password.svg" alt="Hiện mật khẩu" />
                </button>
              </div>
            </div>
            <div class="field" style="margin-bottom:0;">
              <label>Xác nhận mật khẩu mới</label>
              <div class="input-box pass-input-box">
                <input type="password" class="pass-field-input" value="MetaGym#2026" aria-label="Xác nhận mật khẩu mới" />
                <button type="button" class="pass-eye-btn" data-toggle-pass aria-label="Hiện mật khẩu" title="Hiện mật khẩu" aria-pressed="false">
                  <img class="ico-sm" src="../../meta-gym/assets/svg/setting/auth_show_password.svg" alt="Hiện mật khẩu" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <div class="bottom-cta-dock">
          <button class="btn-primary">Cập nhật mật khẩu</button>
        </div>
      </div>
    `
  },
  {
    id: 'member-support',
    group: 'tab5-profile',
    groupLabel: '5. Hồ sơ',
    title: '5.12 Thông tin phòng tập',
    shortFile: 'catalog.routes.js (GET /gym-profile)',
    flutterFile: 'mobile-app/lib/features/profile/presentation/profile_page.dart',
    tag: 'P2 • Phòng tập',
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
              <div class="mg-eyebrow">META GYM CENTER</div>
              <div class="mg-title">Thông tin phòng tập</div>
            </div>
          </div>

          <div class="card-warm-glass">
            <div class="row" style="gap:12px;">
              <div class="mg-logo" style="width:46px;height:46px;"><img src="../../meta-gym/assets/svg/brand/app_icon_mark.svg" alt="Meta Gym" /></div>
              <div>
                <div style="font-size:16px;font-weight:800;">Meta Gym Flagship Studio</div>
                <div class="txt-xs">Không gian tập luyện hiệu suất cao</div>
              </div>
            </div>
          </div>

          <div class="card-solid" style="padding:6px 14px;">
            <div class="row-between" style="padding:11px 0;">
              <span class="txt-xs">Giờ mở cửa</span>
              <strong class="txt-sm tnum">05:30 – 22:00 (Hàng ngày)</strong>
            </div>
            <div class="divider" style="margin:0;"></div>
            <div class="row-between" style="padding:11px 0;">
              <span class="txt-xs">Điện thoại</span>
              <strong class="txt-sm tnum txt-orange">1900 6868</strong>
            </div>
            <div class="divider" style="margin:0;"></div>
            <div class="row-between" style="padding:11px 0;">
              <span class="txt-xs">Email</span>
              <strong class="txt-sm">cskh@metagym.vn</strong>
            </div>
            <div class="divider" style="margin:0;"></div>
            <div class="row-between" style="padding:11px 0;">
              <span class="txt-xs">Địa chỉ</span>
              <strong class="txt-sm" style="text-align:right;">128 Nguyễn Huệ, Q.1, TP.HCM</strong>
            </div>
          </div>

          <div class="card-liquid" style="padding:14px;">
            <div class="txt-sm txt-bold" style="margin-bottom:6px;">Nội quy phòng tập</div>
            <div class="txt-xs" style="color:var(--text-warm-muted);line-height:1.5;">
              • Mang giày thể thao sạch và khăn cá nhân khi vào khu tập luyện.<br />
              • Đặt tạ đơn, bánh tạ về đúng giá kệ và lau sạch ghế sau khi dùng.<br />
              • Tuân thủ hướng dẫn an toàn với máy cáp và tạ tự do.
            </div>
          </div>
        </div>
      </div>
    `
  }
]);
