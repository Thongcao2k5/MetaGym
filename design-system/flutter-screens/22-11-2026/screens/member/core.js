// Meta Gym Flutter Mockups — MEMBER / 5 Tab chính
window.METAGYM_SCREENS = window.METAGYM_SCREENS || {};
window.METAGYM_SCREENS.member = (window.METAGYM_SCREENS.member || []).concat([
  {
    id: 'member-home',
    group: 'core',
    groupLabel: '5 Tab chính',
    title: '1. Trang chủ Hội viên',
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
            <div class="mg-logo">MG</div>
            <div class="mg-header-text">
              <div class="mg-eyebrow">META GYM</div>
              <div class="mg-title">Chào, Minh Quân</div>
            </div>
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_search.svg" alt="Tìm kiếm" /></div>
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

          <!-- _buildExploreSection -->
          <div class="row-between" style="margin-bottom:8px;">
            <div class="row" style="gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/catalog/exercise_step_guide.svg" alt="Khám phá" /><strong style="font-size:13.5px;">Khám phá Meta Gym</strong></div>
            <span class="txt-xs" style="color:var(--reflection);">Xem thêm ›</span>
          </div>
          <div class="card-liquid" style="padding:12px;">
            <span class="pill pill-orange" style="margin-bottom:6px;">Kiến thức tập luyện</span>
            <div class="txt-sm txt-bold">Nguyên tắc tăng tiến tải trọng (Progressive Overload)</div>
            <div class="txt-xs" style="margin-top:3px;">Cách ghi tạ và phục hồi hiệu quả cho người mới...</div>
          </div>
        </div>

        <div class="bottom-nav-wrap">
          <nav class="bottom-nav">
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_home_outline.svg" alt="Trang chủ" /></div>
            <div class="nav-item active"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_training_filled.svg" alt="Tập luyện" /></div>
            <div class="nav-ai-wrap"><div class="nav-ai-btn"><img class="nav-ai-svg" src="../../meta-gym/assets/svg/navigation/nav_ai_on_primary.svg" alt="AI" /></div></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_messages_outline.svg" alt="Tin nhắn" /></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_profile_outline.svg" alt="Hồ sơ" /></div>
          </nav>
        </div>
      </div>
    `
  },
  {
    id: 'member-training-hub',
    group: 'core',
    groupLabel: '5 Tab chính',
    title: '2. Trung tâm Tập luyện',
    shortFile: 'member_training_hub_page.dart',
    flutterFile: 'mobile-app/lib/features/training/presentation/member_training_hub_page.dart',
    tag: 'P0 • 5 blurs',
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
              <div class="mg-eyebrow">META GYM · TẬP LUYỆN</div>
              <div class="mg-title">Tập luyện</div>
            </div>
            <div class="circle-btn" title="Thư viện"><img class="ico-md" src="../../meta-gym/assets/svg/catalog/equip_dumbbell.svg" alt="Thư viện" /></div>
            <div class="circle-btn" title="Lịch sử"><img class="ico-md" src="../../meta-gym/assets/svg/workout/workout_history.svg" alt="Lịch sử" /></div>
          </div>

          <div class="sec-head" style="margin-top:4px;"><h3>Dịch vụ của bạn</h3></div>
          <div class="card-warm-glass">
            <div class="grid-2">
              <div class="metric-box">
                <div class="row-between" style="margin-bottom:6px;">
                  <span class="txt-xs txt-bold" style="color:var(--text-primary);">Gói tập</span>
                  <span class="txt-xs txt-green txt-bold">Hiệu lực</span>
                </div>
                <div class="tnum" style="font-size:18px;font-weight:800;">42 ngày</div>
                <div class="txt-xs" style="margin-top:2px;">Còn lại · Hết hạn 03/01/2027</div>
                <div class="txt-xs" style="color:var(--reflection);margin-top:8px;font-weight:600;">Xem gói tập ›</div>
              </div>
              <div class="metric-box">
                <div class="row-between" style="margin-bottom:6px;">
                  <div class="row" style="gap:5px;">
                    <div class="avatar-ln" style="width:20px;height:20px;font-size:8.5px;">LN</div>
                    <span class="txt-xs txt-bold" style="color:var(--text-primary);">Gói Coach</span>
                  </div>
                  <span class="txt-xs txt-green txt-bold">Hiệu lực</span>
                </div>
                <div style="font-size:14px;font-weight:700;">Lê Hoàng Nam</div>
                <div class="txt-xs" style="margin-top:2px;">Coach cá nhân · Hiệu lực</div>
                <div class="txt-xs" style="color:var(--reflection);margin-top:8px;font-weight:600;">Xem gói Coach ›</div>
              </div>
            </div>
          </div>

          <div class="sec-head"><h3 class="txt-orange">Kế hoạch tập luyện</h3></div>
          <div class="card-liquid" style="padding:13px;margin-bottom:10px;">
            <div class="row-between">
              <div class="row">
                <div class="quick-ico"><img class="ico-md" src="../../meta-gym/assets/svg/quick_actions/action_curriculum.svg" alt="Giáo trình" /></div>
                <div>
                  <div class="txt-sm txt-bold">Giáo trình của Coach</div>
                  <div class="txt-xs">Kế hoạch tập luyện và ăn uống từ Coach</div>
                </div>
              </div>
              <span class="txt-xs">›</span>
            </div>
          </div>
          <div class="card-liquid" style="padding:13px;margin-bottom:10px;">
            <div class="row-between">
              <div class="row">
                <div class="quick-ico" style="background:rgba(169,199,232,0.14);"><img class="ico-md" src="../../meta-gym/assets/svg/workout/workout_plan_calendar.svg" alt="Lịch tập" /></div>
                <div>
                  <div class="row" style="gap:6px;"><strong class="txt-sm">Lịch tập của tôi</strong><span class="pill pill-orange" style="padding:1px 6px;font-size:9.5px;">Hôm nay</span></div>
                  <div class="txt-xs tnum">Hôm nay · 18:00 · Push Day</div>
                </div>
              </div>
              <span class="txt-xs">›</span>
            </div>
          </div>
          <div class="card-liquid" style="padding:13px;margin-bottom:14px;">
            <div class="row-between">
              <div class="row">
                <div class="quick-ico" style="background:rgba(46,204,113,0.14);"><img class="ico-md" src="../../meta-gym/assets/svg/quick_actions/action_nutrition.svg" alt="Dinh dưỡng" /></div>
                <div>
                  <div class="txt-sm txt-bold">Theo dõi dinh dưỡng</div>
                  <div class="txt-xs">Ghi bữa ăn &amp; đối chiếu thực đơn Coach</div>
                </div>
              </div>
              <span class="btn-mini-orange">Mở</span>
            </div>
          </div>

          <div class="sec-head"><h3>Công cụ &amp; Khám phá</h3></div>
          <div class="grid-2" style="margin-bottom:10px;">
            <div class="card-liquid" style="margin-bottom:0;padding:12px;">
              <div style="margin-bottom:6px;"><img class="ico-lg" src="../../meta-gym/assets/svg/progress/stats_report.svg" alt="Nhật ký" /></div>
              <div class="txt-sm txt-bold">Nhật ký tập luyện</div>
              <div class="txt-xs" style="margin-top:3px;">Ghi thành tích, ảnh và số đo theo ngày</div>
            </div>
            <div class="card-liquid" style="margin-bottom:0;padding:12px;">
              <div style="margin-bottom:6px;"><img class="ico-lg" src="../../meta-gym/assets/svg/workout/workout_history.svg" alt="Lịch sử" /></div>
              <div class="txt-sm txt-bold">Lịch sử tập luyện</div>
              <div class="txt-xs" style="margin-top:3px;">Xem các ngày và lượt đến phòng gym</div>
            </div>
          </div>
          <div class="grid-2">
            <div class="card-liquid" style="margin-bottom:0;padding:12px;">
              <div style="margin-bottom:6px;"><img class="ico-lg" src="../../meta-gym/assets/svg/catalog/equip_barbell.svg" alt="Thư viện bài tập" /></div>
              <div class="txt-sm txt-bold">Thư viện bài tập</div>
              <div class="txt-xs" style="margin-top:3px;">Tìm bài theo nhóm cơ và cách thực hiện</div>
            </div>
            <div class="card-liquid" style="margin-bottom:0;padding:12px;">
              <div style="margin-bottom:6px;"><img class="ico-lg" src="../../meta-gym/assets/svg/catalog/equip_machine.svg" alt="Phòng gym & thiết bị" /></div>
              <div class="txt-sm txt-bold">Phòng gym &amp; thiết bị</div>
              <div class="txt-xs" style="margin-top:3px;">Nội quy và hướng dẫn dùng máy</div>
            </div>
          </div>
        </div>

        <div class="bottom-nav-wrap">
          <nav class="bottom-nav">
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_home_outline.svg" alt="Trang chủ" /></div>
            <div class="nav-item active"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_training_filled.svg" alt="Tập luyện" /></div>
            <div class="nav-ai-wrap"><div class="nav-ai-btn"><img class="nav-ai-svg" src="../../meta-gym/assets/svg/navigation/nav_ai_on_primary.svg" alt="AI" /></div></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_messages_outline.svg" alt="Tin nhắn" /></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_profile_outline.svg" alt="Hồ sơ" /></div>
          </nav>
        </div>
      </div>
    `
  },
  {
    id: 'member-ai-messages',
    group: 'core',
    groupLabel: '5 Tab chính',
    title: '3. Trợ lý AI',
    shortFile: 'ai_messages_page.dart',
    flutterFile: 'mobile-app/lib/features/ai/presentation/ai_messages_page.dart',
    tag: 'P1',
    tagClass: '',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body no-nav" style="display:flex;flex-direction:column;">
          <div class="mg-header">
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_back.svg" alt="Quay lại" /></div>
            <div class="mg-header-text">
              <div class="mg-title" style="font-size:17px;">Tư vấn đạm sau buổi tập</div>
            </div>
          </div>

          <!-- Disclaimer Card (đúng code thực tế dòng 233) -->
          <div class="card-liquid" style="padding:10px 12px;margin-bottom:14px;">
            <div class="row" style="gap:8px;align-items:flex-start;">
              <img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_info.svg" alt="Lưu ý" />
              <div class="txt-xs" style="color:var(--text-warm-muted);">Nội dung AI chỉ để tham khảo; không thay thế tư vấn y tế hoặc huấn luyện cá nhân.</div>
            </div>
          </div>

          <!-- Messages full-width cards (đúng code thực tế dòng 314) -->
          <div style="flex:1;">
            <div class="ai-msg-card ai-msg-user">
              <div class="row" style="gap:6px;margin-bottom:5px;">
                <img class="ico-xs" src="../../meta-gym/assets/svg/setting/setting_personal_info.svg" alt="Bạn" />
                <strong class="txt-xs" style="color:var(--text-primary);">Bạn</strong>
              </div>
              <div>Tối nay mình tập Upper Body xong thì nên ăn thêm bao nhiêu đạm nữa để đủ mục tiêu 160g?</div>
            </div>

            <div class="ai-msg-card ai-msg-bot">
              <div class="row" style="gap:6px;margin-bottom:5px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/navigation/nav_ai_emblem.svg" alt="Trợ lý AI" />
                <strong class="txt-xs txt-orange">Trợ lý AI</strong>
              </div>
              <div>Nếu bạn đã nạp 140g đạm trong ngày, bạn chỉ cần bổ sung thêm khoảng <strong class="tnum">20–25g đạm</strong> sau tập:</div>
              <div class="txt-xs" style="color:var(--text-secondary);margin-top:6px;">• 1 muỗng Whey Isolate (~25g đạm)<br />• Hoặc 100g ức gà luộc + 1 quả chuối</div>
            </div>
          </div>

          <div class="row" style="margin-top:10px;">
            <div class="input-box" style="flex:1;height:44px;color:var(--text-secondary);font-size:13px;">Nhập câu hỏi cho Trợ lý AI...</div>
            <div style="width:44px;height:44px;border-radius:14px;background:var(--primary);display:flex;align-items:center;justify-content:center;font-weight:800;">↑</div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'member-conversations',
    group: 'core',
    groupLabel: '5 Tab chính',
    title: '4. Tin nhắn',
    shortFile: 'conversations_page.dart',
    flutterFile: 'mobile-app/lib/features/messaging/presentation/conversations_page.dart',
    tag: 'P0 • 6 blurs',
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
            <div class="mg-logo">MG</div>
            <div class="mg-header-text">
              <div class="mg-eyebrow">META GYM</div>
              <div class="mg-title">Tin nhắn</div>
              <div style="font-size:11px;color:var(--text-secondary);">Trao đổi cùng Coach &amp; hỗ trợ</div>
            </div>
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_search.svg" alt="Tìm kiếm" /></div>
            <div class="circle-btn" style="font-size:12px;font-weight:800;">MQ</div>
          </div>

          <!-- _buildQuickFilterDock: 4 nút lọc -->
          <div class="filter-row">
            <div class="filter-pill active">Tất cả</div>
            <div class="filter-pill">Coach</div>
            <div class="filter-pill">Chưa đọc</div>
            <div class="filter-pill">Hỗ trợ</div>
          </div>

          <!-- _buildFeaturedCoachCard -->
          <div class="card-liquid featured" style="padding:11px 12px;">
            <div class="row" style="gap:6px;margin-bottom:7px;">
              <img class="ico-xs" src="../../meta-gym/assets/svg/community/comm_chat.svg" alt="Coach cá nhân" />
              <strong style="font-size:10.5px;letter-spacing:0.05em;">COACH CÁ NHÂN</strong>
              <span class="pill" style="background:rgba(35,201,151,0.16);color:#23C997;font-size:9px;padding:1px 6px;">● Đang hoạt động</span>
            </div>
            <div class="row">
              <div class="avatar-ln">LN</div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong class="txt-sm">Lê Hoàng Nam</strong>
                  <span class="txt-xs tnum txt-orange">17:45</span>
                </div>
                <div class="row-between" style="margin-top:2px;">
                  <span class="txt-xs" style="color:var(--text-primary);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Tối nay 18h anh đợi ở khu Free Weight nhé!</span>
                  <span class="pill pill-orange tnum" style="padding:1px 6px;">2</span>
                </div>
              </div>
            </div>
          </div>

          <div class="card-liquid" style="padding:12px;">
            <div class="row">
              <div class="avatar-member" style="width:38px;height:38px;font-size:12px;background:#262A34;">HT</div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong class="txt-sm">Hỗ trợ Meta Gym</strong>
                  <span class="txt-xs tnum">Hôm qua</span>
                </div>
                <div class="txt-xs" style="margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Đã xác nhận gia hạn gói Hội viên 3 tháng.</div>
              </div>
            </div>
          </div>
        </div>

        <div class="bottom-nav-wrap">
          <nav class="bottom-nav">
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_home_outline.svg" alt="Trang chủ" /></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_training_outline.svg" alt="Tập luyện" /></div>
            <div class="nav-ai-wrap"><div class="nav-ai-btn"><img class="nav-ai-svg" src="../../meta-gym/assets/svg/navigation/nav_ai_on_primary.svg" alt="AI" /></div></div>
            <div class="nav-item active"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_messages_filled.svg" alt="Tin nhắn" /></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_profile_outline.svg" alt="Hồ sơ" /></div>
          </nav>
        </div>
      </div>
    `
  },
  {
    id: 'member-profile',
    group: 'core',
    groupLabel: '5 Tab chính',
    title: '5. Hồ sơ',
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
              <div style="position:relative;">
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

          <!-- 3 _ProfileCategoryCard Accordions -->
          <div class="card-liquid" style="padding:13px 14px;">
            <div class="accordion-head">
              <div class="row"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/setting_personal_info.svg" alt="Cá nhân" /><strong class="txt-sm">Cá nhân &amp; thể trạng</strong></div>
              <div class="row" style="gap:6px;"><span class="count-pill">3</span><span class="txt-xs">⌄</span></div>
            </div>
            <div class="divider"></div>
            <div class="row-between txt-sm" style="padding:6px 0;"><span>Thông tin cá nhân</span><span class="txt-xs">›</span></div>
            <div class="row-between txt-sm" style="padding:6px 0;"><span>Hồ sơ tập luyện</span><span class="txt-xs">›</span></div>
            <div class="row-between txt-sm" style="padding:6px 0;"><span>Khai báo thể trạng cho Coach</span><span class="txt-xs">›</span></div>
          </div>

          <div class="card-liquid" style="padding:13px 14px;">
            <div class="accordion-head">
              <div class="row"><img class="ico-sm" src="../../meta-gym/assets/svg/catalog/equip_dumbbell.svg" alt="Tập luyện" /><strong class="txt-sm">Tập luyện &amp; dịch vụ</strong></div>
              <div class="row" style="gap:6px;"><span class="count-pill">3</span><span class="txt-xs">›</span></div>
            </div>
          </div>

          <div class="card-liquid" style="padding:13px 14px;">
            <div class="accordion-head">
              <div class="row"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/setting_security_shield.svg" alt="Tài khoản" /><strong class="txt-sm">Tài khoản &amp; hỗ trợ</strong></div>
              <div class="row" style="gap:6px;"><span class="count-pill">4</span><span class="txt-xs">›</span></div>
            </div>
          </div>

          <div class="card-liquid" style="padding:13px;text-align:center;color:var(--error);font-weight:600;font-size:14px;">
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
      </div>
    `
  }
]);
