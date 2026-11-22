// Meta Gym Flutter Mockups — AUTH / Khởi động & Xác thực
window.METAGYM_SCREENS = window.METAGYM_SCREENS || {};
window.METAGYM_SCREENS.auth = (window.METAGYM_SCREENS.auth || []).concat([
  {
    id: 'auth-splash',
    group: 'auth',
    groupLabel: 'Khởi động & Xác thực',
    title: '1. Chào mừng / Splash Screen',
    shortFile: 'app_loading_page.dart',
    flutterFile: 'mobile-app/lib/features/public/presentation/app_loading_page.dart',
    tag: 'P1 • Morph Logo',
    tagClass: '',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body no-nav" style="display:flex;flex-direction:column;align-items:center;justify-content:space-between;text-align:center;">
          <div style="height:24px;"></div>

          <div style="display:flex;flex-direction:column;align-items:center;">
            <!-- Ambient warm performance aura + Wordmark MetaGym (M, G màu cam) -->
            <div style="position:relative;width:280px;height:180px;display:flex;align-items:center;justify-content:center;">
              <div style="position:absolute;inset:-10px;border-radius:50%;background:radial-gradient(circle, rgba(255,94,54,0.22) 0%, rgba(245,176,65,0.08) 54%, transparent 74%);pointer-events:none;"></div>
              <div style="position:relative;font-size:44px;font-weight:800;letter-spacing:-0.03em;line-height:1;">
                <span style="color:var(--primary);">M</span><span style="color:var(--text-primary);">eta</span><span style="color:var(--primary);">G</span><span style="color:var(--text-primary);">ym</span>
              </div>
            </div>

            <!-- Subtitle -->
            <div style="color:var(--text-warm-muted);font-size:13.5px;font-weight:500;margin-top:4px;">
              Đang khởi động không gian tập luyện...
            </div>

            <!-- _WarmGlassProgressBar (172px x 5px + % tabular-nums) -->
            <div class="row" style="justify-content:center;gap:10px;margin-top:18px;">
              <div style="width:172px;height:5px;border-radius:999px;background:rgba(33,30,28,0.55);border:1px solid rgba(167,157,146,0.4);overflow:hidden;">
                <div style="width:78%;height:100%;border-radius:999px;background:linear-gradient(90deg, var(--primary), #F5B041);"></div>
              </div>
              <span class="tnum" style="width:36px;text-align:right;font-size:12.5px;font-weight:700;color:var(--primary);">78%</span>
            </div>
          </div>

          <!-- Version Footer -->
          <div class="auth-version-footer" style="margin-top:0;">
            <img class="ico-xs" src="../../meta-gym/assets/svg/setting/setting_version.svg" alt="Phiên bản" />
            <span>Meta Gym v1.0.0 · Build 2026.11</span>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'auth-login',
    group: 'auth',
    groupLabel: 'Khởi động & Xác thực',
    title: '2. Đăng nhập',
    shortFile: 'login_page.dart',
    flutterFile: 'mobile-app/lib/features/auth/presentation/login_page.dart',
    tag: 'P2',
    tagClass: '',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body no-nav" style="display:flex;flex-direction:column;justify-content:center;">
          <!-- AuthTopHeader -->
          <div class="row" style="justify-content:center;gap:10px;margin-bottom:14px;">
            <div class="mg-logo">MG</div>
            <div>
              <div class="mg-eyebrow">META GYM</div>
              <div style="font-size:15px;font-weight:700;">Performance Studio</div>
            </div>
          </div>

          <!-- WarmSmokeGlass -->
          <div class="card-warm-glass" style="padding:18px 20px;">
            <!-- AuthModeSegmentSwitch -->
            <div class="seg-tabs" style="margin-bottom:14px;">
              <div class="seg-tab active">Đăng nhập</div>
              <div class="seg-tab">Đăng ký</div>
            </div>

            <div style="font-size:23px;font-weight:800;letter-spacing:-0.02em;line-height:1.2;">Chào mừng trở lại</div>
            <div style="font-size:12.5px;color:var(--text-secondary);margin:4px 0 14px;">Đăng nhập để tiếp tục lịch tập và kết nối cùng Coach của bạn.</div>

            <div class="field">
              <label>Email</label>
              <div class="input-box focus"><span class="row" style="gap:8px;"><img class="ico-sm" src="../../meta-gym/assets/svg/community/comm_email.svg" alt="Email" /><span>minhquan@metagym.vn</span></span></div>
            </div>
            <div class="field">
              <label>Mật khẩu</label>
              <div class="input-box"><span class="row" style="gap:8px;"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/setting_password_key.svg" alt="Mật khẩu" /><span>••••••••••</span></span><img class="ico-sm" src="../../meta-gym/assets/svg/setting/auth_show_password.svg" alt="Hiện mật khẩu" /></div>
            </div>

            <div class="row-between" style="margin:6px 0 14px;">
              <div class="row" style="gap:8px;">
                <span style="width:18px;height:18px;border-radius:5px;background:var(--primary);color:#FFF;display:inline-flex;align-items:center;justify-content:center;font-size:11px;font-weight:800;">✓</span>
                <span style="font-size:12.5px;font-weight:500;">Ghi nhớ đăng nhập</span>
              </div>
              <span style="font-size:12.5px;font-weight:600;color:var(--reflection);">Quên mật khẩu?</span>
            </div>

            <div class="row" style="gap:10px;">
              <button class="btn-primary" style="flex:1;">Đăng nhập →</button>
              <button type="button" class="btn-secondary" data-open-biometric="login" title="Đăng nhập bằng Face ID / Vân tay" style="width:48px;height:48px;padding:0;flex-shrink:0;border-radius:14px;border-color:rgba(255,94,54,0.45);background:rgba(255,94,54,0.12);">
                <img class="ico-md" src="../../meta-gym/assets/svg/setting/auth_face_id.svg" alt="Face ID" style="background:transparent;padding:0;" />
              </button>
            </div>

            <!-- Điều khoản & Chính sách bảo mật -->
            <div class="auth-legal">
              Bằng việc đăng nhập, bạn đồng ý với <span class="auth-policy-link">Điều khoản sử dụng</span> và <span class="auth-policy-link">Chính sách bảo mật</span> của Meta Gym.
            </div>

            <div style="text-align:center;margin-top:10px;font-size:11px;color:var(--text-secondary);">
              <span class="row" style="justify-content:center;gap:6px;"><img class="ico-xs" src="../../meta-gym/assets/svg/setting/auth_verified.svg" alt="Xác thực" /><span>Không gian Hội viên &amp; Huấn luyện viên Meta Gym</span></span>
            </div>
          </div>

          <!-- Version Footer -->
          <div class="auth-version-footer">
            <img class="ico-xs" src="../../meta-gym/assets/svg/setting/setting_version.svg" alt="Phiên bản" />
            <span>Meta Gym v1.0.0 · Build 2026.11</span>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'auth-register',
    group: 'auth',
    groupLabel: 'Khởi động & Xác thực',
    title: '3. Đăng ký',
    shortFile: 'register_page.dart',
    flutterFile: 'mobile-app/lib/features/auth/presentation/register_page.dart',
    tag: 'P2',
    tagClass: '',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body no-nav">
          <!-- AuthTopHeader (có nút quay lại) -->
          <div class="mg-header" style="margin-top:4px;margin-bottom:14px;">
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_back.svg" alt="Quay lại" /></div>
            <div class="mg-logo">MG</div>
            <div class="mg-header-text">
              <div class="mg-eyebrow">META GYM</div>
              <div style="font-size:15px;font-weight:700;">Performance Studio</div>
            </div>
          </div>

          <!-- WarmSmokeGlass -->
          <div class="card-warm-glass" style="padding:18px 20px;">
            <!-- AuthModeSegmentSwitch -->
            <div class="seg-tabs" style="margin-bottom:16px;">
              <div class="seg-tab">Đăng nhập</div>
              <div class="seg-tab active">Đăng ký</div>
            </div>

            <div style="font-size:22px;font-weight:800;letter-spacing:-0.02em;line-height:1.2;">Tạo tài khoản hội viên</div>
            <div style="font-size:12.5px;color:var(--text-secondary);margin:5px 0 16px;">Khởi tạo hồ sơ cá nhân để đặt lịch PT 1:1 và theo dõi chỉ số cơ thể.</div>

            <div class="field">
              <label>Họ và tên</label>
              <div class="input-box"><span class="row" style="gap:8px;"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/setting_personal_info.svg" alt="Họ và tên" /><span>Nguyễn Minh Quân</span></span></div>
            </div>
            <div class="field">
              <label>Email</label>
              <div class="input-box"><span class="row" style="gap:8px;"><img class="ico-sm" src="../../meta-gym/assets/svg/community/comm_email.svg" alt="Email" /><span>minhquan@metagym.vn</span></span></div>
            </div>
            <div class="field">
              <label>Mật khẩu</label>
              <div class="input-box focus"><span class="row" style="gap:8px;"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/setting_password_key.svg" alt="Mật khẩu" /><span>••••••••••</span></span><img class="ico-sm" src="../../meta-gym/assets/svg/setting/auth_show_password.svg" alt="Hiện mật khẩu" /></div>
            </div>

            <!-- _PasswordStrengthMeter (đúng 4 thanh + 4 điều kiện) -->
            <div class="metric-box" style="border-radius:14px;padding:11px 13px;margin-bottom:16px;">
              <div class="row-between" style="margin-bottom:8px;">
                <span style="font-size:12px;font-weight:600;color:var(--text-secondary);">Độ mạnh mật khẩu</span>
                <span style="font-size:12px;font-weight:700;color:var(--success);">Đạt chuẩn</span>
              </div>
              <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:6px;margin-bottom:10px;">
                <div style="height:4px;border-radius:999px;background:var(--success);"></div>
                <div style="height:4px;border-radius:999px;background:var(--success);"></div>
                <div style="height:4px;border-radius:999px;background:var(--success);"></div>
                <div style="height:4px;border-radius:999px;background:var(--success);"></div>
              </div>
              <div class="grid-2" style="gap:6px 8px;font-size:11.5px;font-weight:600;color:var(--success);">
                <div>✓ ≥ 8 ký tự</div>
                <div>✓ Chữ hoa</div>
                <div>✓ Chữ thường</div>
                <div>✓ Chữ số</div>
              </div>
            </div>

            <!-- Đồng ý Điều khoản & Chính sách bảo mật -->
            <div class="auth-consent">
              <span style="width:18px;height:18px;border-radius:5px;background:var(--primary);color:#FFF;display:inline-flex;align-items:center;justify-content:center;font-size:11px;font-weight:800;flex-shrink:0;margin-top:1px;">✓</span>
              <span>Tôi đồng ý với <span class="auth-policy-link">Điều khoản dịch vụ</span> và <span class="auth-policy-link">Chính sách bảo mật</span> dữ liệu sức khỏe của Meta Gym.</span>
            </div>

            <button class="btn-primary">Đăng ký →</button>
          </div>

          <!-- Version Footer -->
          <div class="auth-version-footer" style="margin-top:10px;padding-top:4px;">
            <img class="ico-xs" src="../../meta-gym/assets/svg/setting/setting_version.svg" alt="Phiên bản" />
            <span>Meta Gym v1.0.0 · Build 2026.11</span>
          </div>
        </div>
      </div>
    `
  }
]);
