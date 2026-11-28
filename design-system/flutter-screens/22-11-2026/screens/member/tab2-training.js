// Meta Gym Flutter Mockups — MEMBER / 2. Tập luyện (Từ ngoài vào trong)
window.METAGYM_SCREENS = window.METAGYM_SCREENS || {};
window.METAGYM_SCREENS.member = (window.METAGYM_SCREENS.member || []).concat([
  {
    id: 'member-training-hub',
    group: 'tab2-training',
    groupLabel: '2. Tập luyện',
    title: '2.1 Trung tâm Tập luyện',
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
            <div class="mg-logo"><img src="../../meta-gym/assets/svg/brand/app_icon_mark.svg" alt="Meta Gym" /></div>
            <div class="mg-header-text">
              <div class="mg-eyebrow">META GYM · TẬP LUYỆN</div>
              <div class="mg-title">Tập luyện</div>
            </div>
            <div class="circle-btn" title="Thư viện bài tập" data-go="member-exercises" style="cursor:pointer;"><img class="ico-md" src="../../meta-gym/assets/svg/catalog/equip_dumbbell.svg" alt="Thư viện" /></div>
            <div class="circle-btn" title="Lịch sử tập" data-go="member-gym-visits" style="cursor:pointer;"><img class="ico-md" src="../../meta-gym/assets/svg/workout/workout_history.svg" alt="Lịch sử" /></div>
          </div>

          <!-- Hero Card: Buổi tập hôm nay (Thích ứng mượt Dark & Light Mode) -->
          <div class="card-warm-glass" style="padding:15px;margin-bottom:11px;border-color:rgba(255,94,54,0.45);">
            <div class="row-between" style="margin-bottom:8px;">
              <span class="pill pill-orange tnum" style="font-size:11px;white-space:nowrap;">● Hôm nay · 18:00</span>
              <span class="pill pill-muted tnum" style="font-size:11px;white-space:nowrap;">90 phút · Push Day</span>
            </div>
            <div style="font-size:16px;font-weight:800;line-height:1.25;letter-spacing:-0.02em;margin-bottom:7px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">
              Ngực &amp; Tay sau · Chest &amp; Triceps
            </div>
            <div class="row" style="gap:7px;margin-bottom:12px;min-width:0;">
              <div class="avatar-ln" style="width:22px;height:22px;font-size:11px;flex-shrink:0;">LN</div>
              <span class="txt-xs" style="color:var(--text-warm-muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Giáo trình tuần 4 · <strong style="color:var(--text-primary);">HLV Lê Hoàng Nam</strong></span>
            </div>

            <div class="grid-3" style="gap:7px;margin-bottom:12px;">
              <div class="metric-box" style="text-align:center;padding:8px 4px;border-radius:12px;min-width:0;">
                <div class="tnum" style="font-size:16px;font-weight:800;color:var(--text-primary);white-space:nowrap;">6</div>
                <div class="txt-xs" style="font-size:12px;white-space:nowrap;">Bài tập</div>
              </div>
              <div class="metric-box" style="text-align:center;padding:8px 4px;border-radius:12px;min-width:0;">
                <div class="tnum" style="font-size:16px;font-weight:800;color:var(--primary);white-space:nowrap;">22</div>
                <div class="txt-xs" style="font-size:12px;white-space:nowrap;">Tổng hiệp</div>
              </div>
              <div class="metric-box" style="text-align:center;padding:8px 4px;border-radius:12px;min-width:0;">
                <div class="tnum" style="font-size:16px;font-weight:800;color:var(--success);white-space:nowrap;">~540</div>
                <div class="txt-xs" style="font-size:12px;white-space:nowrap;">Kcal</div>
              </div>
            </div>

            <div class="grid-2" style="gap:8px;">
              <button type="button" class="btn-primary" style="height:40px;font-size:14px;white-space:nowrap;" data-go="member-curriculum">Bắt đầu tập →</button>
              <button type="button" class="btn-secondary" style="height:40px;font-size:14px;white-space:nowrap;" data-go="member-curriculum">Xem giáo trình</button>
            </div>
          </div>

          <!-- 2 Cột Bento sang trọng: Thẻ Hội viên & Coach 1:1 (tất cả 1 dòng, tuyệt đối không xuống hàng) -->
          <div class="grid-2" style="gap:10px;margin-bottom:12px;align-items:stretch;">
            <!-- Card Trái: Thẻ Hội viên -->
            <div class="card-warm-glass" style="margin-bottom:0;padding:13px 12px 12px;cursor:pointer;display:flex;flex-direction:column;justify-content:space-between;position:relative;overflow:hidden;min-width:0;border-color:rgba(245,176,65,0.42);" data-go="member-membership">
              <div style="position:absolute;top:-22px;right:-22px;width:72px;height:72px;border-radius:50%;background:radial-gradient(circle, rgba(245,176,65,0.22) 0%, transparent 72%);pointer-events:none;"></div>
              <div style="min-width:0;">
                <div class="row-between" style="margin-bottom:8px;">
                  <div class="row" style="gap:5px;min-width:0;">
                    <img class="ico-xs" src="../../meta-gym/assets/svg/membership/premium_crown.svg" alt="Hạng Vàng" />
                    <span style="font-size:12px;font-weight:800;letter-spacing:0.06em;color:var(--warning);white-space:nowrap;">HẠNG VÀNG</span>
                  </div>
                  <span style="width:7px;height:7px;border-radius:50%;background:var(--success);box-shadow:0 0 8px rgba(46,204,113,0.75);flex-shrink:0;"></span>
                </div>
                <div class="row" style="align-items:baseline;gap:4px;margin-bottom:3px;white-space:nowrap;">
                  <span class="tnum" style="font-size:22px;font-weight:800;letter-spacing:-0.03em;line-height:1;color:var(--text-primary);">42</span>
                  <span style="font-size:12px;font-weight:600;color:var(--text-warm-muted);white-space:nowrap;">ngày còn lại</span>
                </div>
                <div class="txt-xs tnum" style="font-size:12px;color:var(--text-secondary);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Hạn 03/01/2027</div>
              </div>
              <div>
                <div class="prog-track" style="height:4px;margin:10px 0 8px;"><div class="prog-fill" style="width:74%;background:linear-gradient(90deg, #F5B041, #2ECC71);"></div></div>
                <div class="row-between">
                  <span style="font-size:11px;font-weight:700;color:var(--warning);white-space:nowrap;">Xem gói tập</span>
                  <span style="font-size:12px;font-weight:700;color:var(--warning);">›</span>
                </div>
              </div>
            </div>

            <!-- Card Phải: Coach 1:1 -->
            <div class="card-warm-glass" style="margin-bottom:0;padding:13px 12px 12px;cursor:pointer;display:flex;flex-direction:column;justify-content:space-between;position:relative;overflow:hidden;min-width:0;border-color:rgba(255,94,54,0.42);" data-go="member-coach-booking">
              <div style="position:absolute;top:-22px;right:-22px;width:72px;height:72px;border-radius:50%;background:radial-gradient(circle, rgba(255,94,54,0.20) 0%, transparent 72%);pointer-events:none;"></div>
              <div style="min-width:0;">
                <div class="row-between" style="margin-bottom:8px;">
                  <span style="font-size:12px;font-weight:800;letter-spacing:0.06em;color:var(--primary);white-space:nowrap;">COACH 1:1</span>
                  <span style="width:7px;height:7px;border-radius:50%;background:var(--success);box-shadow:0 0 8px rgba(46,204,113,0.75);flex-shrink:0;"></span>
                </div>
                <div class="row" style="gap:7px;margin-bottom:3px;min-width:0;">
                  <div class="avatar-ln" style="width:28px;height:28px;font-size:11px;flex-shrink:0;box-shadow:0 4px 10px rgba(245,176,65,0.28);">LN</div>
                  <div style="min-width:0;flex:1;">
                    <div style="font-size:14px;font-weight:800;line-height:1.2;color:var(--text-primary);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Lê Hoàng Nam</div>
                    <div class="txt-xs tnum" style="font-size:12px;color:var(--text-warm-muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Còn 14/24 buổi</div>
                  </div>
                </div>
              </div>
              <div>
                <div class="prog-track" style="height:4px;margin:10px 0 8px;"><div class="prog-fill" style="width:58%;background:linear-gradient(90deg, var(--primary), #FF9B73);"></div></div>
                <div class="row-between">
                  <span style="font-size:11px;font-weight:700;color:var(--primary);white-space:nowrap;">Lịch Coach</span>
                  <span style="font-size:12px;font-weight:700;color:var(--primary);">›</span>
                </div>
              </div>
            </div>
          </div>

          <!-- Mục Kế hoạch & Dinh dưỡng -->
          <div class="sec-head" style="margin-top:2px;">
            <h3 style="white-space:nowrap;">Kế hoạch &amp; Dinh dưỡng</h3>
            <span class="txt-xs tnum" style="white-space:nowrap;">Tuần 4</span>
          </div>

          <!-- Card Dinh dưỡng hôm nay -->
          <div class="card-warm-glass" style="padding:13px 14px;margin-bottom:9px;cursor:pointer;" data-go="member-nutrition">
            <div class="row-between" style="margin-bottom:8px;gap:8px;">
              <div class="row" style="gap:10px;min-width:0;flex:1;">
                <div class="quick-ico" style="width:38px;height:38px;border-radius:12px;flex-shrink:0;background:rgba(46,204,113,0.16);border:1px solid rgba(46,204,113,0.38);">
                  <img class="ico-md" src="../../meta-gym/assets/svg/quick_actions/action_nutrition.svg" alt="Dinh dưỡng" />
                </div>
                <div style="min-width:0;flex:1;">
                  <div class="txt-sm txt-bold" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Dinh dưỡng hôm nay</div>
                  <div class="txt-xs tnum" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">1.840 / 2.400 kcal · Đạm 140/160g</div>
                </div>
              </div>
              <span class="pill pill-success tnum" style="font-size:11px;flex-shrink:0;white-space:nowrap;">77%</span>
            </div>
            <div class="prog-track" style="height:5px;margin:0;"><div class="prog-fill" style="width:77%;background:linear-gradient(90deg, var(--success), #59E59A);"></div></div>
          </div>

          <!-- Card Lịch tập tuần của tôi -->
          <div class="card-warm-glass" style="padding:13px 14px;margin-bottom:13px;cursor:pointer;" data-go="member-self-training">
            <div class="row-between" style="margin-bottom:9px;gap:8px;">
              <div class="row" style="gap:10px;min-width:0;flex:1;">
                <div class="quick-ico" style="width:38px;height:38px;border-radius:12px;flex-shrink:0;background:rgba(169,199,232,0.16);border:1px solid rgba(169,199,232,0.38);">
                  <img class="ico-md" src="../../meta-gym/assets/svg/workout/workout_plan_calendar.svg" alt="Lịch tập" />
                </div>
                <div style="min-width:0;flex:1;">
                  <div class="txt-sm txt-bold" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Lịch tập tuần của tôi</div>
                  <div class="txt-xs" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Hoàn thành 3/5 buổi mục tiêu</div>
                </div>
              </div>
              <span class="txt-xs" style="color:var(--primary);font-weight:700;flex-shrink:0;white-space:nowrap;">Mở ›</span>
            </div>
            <div class="row-between tnum" style="gap:5px;">
              <div style="flex:1;min-width:0;text-align:center;padding:5px 0;border-radius:9px;background:rgba(46,204,113,0.16);border:1px solid rgba(46,204,113,0.42);font-size:12px;font-weight:700;color:var(--success);white-space:nowrap;">T2✓</div>
              <div style="flex:1;min-width:0;text-align:center;padding:5px 0;border-radius:9px;background:rgba(46,204,113,0.16);border:1px solid rgba(46,204,113,0.42);font-size:12px;font-weight:700;color:var(--success);white-space:nowrap;">T3✓</div>
              <div style="flex:1;min-width:0;text-align:center;padding:5px 0;border-radius:9px;background:var(--primary);border:1px solid var(--primary);font-size:12px;font-weight:800;color:#FFFFFF;white-space:nowrap;">T4</div>
              <div style="flex:1;min-width:0;text-align:center;padding:5px 0;border-radius:9px;background:var(--surface-raised);border:1px solid var(--border-solid);font-size:12px;color:var(--text-secondary);white-space:nowrap;">T5</div>
              <div style="flex:1;min-width:0;text-align:center;padding:5px 0;border-radius:9px;background:var(--surface-raised);border:1px solid var(--border-solid);font-size:12px;color:var(--text-secondary);white-space:nowrap;">T6</div>
              <div style="flex:1;min-width:0;text-align:center;padding:5px 0;border-radius:9px;background:var(--surface-raised);border:1px solid var(--border-solid);font-size:12px;color:var(--text-secondary);white-space:nowrap;">T7</div>
              <div style="flex:1;min-width:0;text-align:center;padding:5px 0;border-radius:9px;background:var(--surface-raised);border:1px solid var(--border-solid);font-size:12px;color:var(--text-secondary);opacity:0.75;white-space:nowrap;">CN</div>
            </div>
          </div>

          <!-- Công cụ & Khám phá (Bento 2x2 Warm Smoked Glass — 1 dòng gọn gàng) -->
          <div class="sec-head" style="margin-top:0;">
            <h3 style="white-space:nowrap;">Công cụ &amp; Thư viện</h3>
            <span class="txt-xs" style="white-space:nowrap;">4 tiện ích</span>
          </div>
          <div class="grid-2" style="gap:9px;margin-bottom:9px;">
            <div class="card-warm-glass" style="margin-bottom:0;padding:12px;cursor:pointer;min-width:0;" data-go="member-journal">
              <div class="row-between" style="margin-bottom:8px;">
                <div class="quick-ico" style="width:34px;height:34px;border-radius:10px;background:rgba(255,94,54,0.16);border:1px solid rgba(255,94,54,0.38);">
                  <img class="ico-md" src="../../meta-gym/assets/svg/progress/stats_report.svg" alt="Nhật ký" />
                </div>
                <span class="txt-xs" style="color:var(--text-warm-muted);">›</span>
              </div>
              <div style="font-size:14px;font-weight:800;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Nhật ký tập luyện</div>
              <div class="txt-xs" style="font-size:12px;margin-top:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Lưu PR, ảnh &amp; số đo</div>
            </div>

            <div class="card-warm-glass" style="margin-bottom:0;padding:12px;cursor:pointer;min-width:0;" data-go="member-gym-visits">
              <div class="row-between" style="margin-bottom:8px;">
                <div class="quick-ico" style="width:34px;height:34px;border-radius:10px;background:rgba(46,204,113,0.16);border:1px solid rgba(46,204,113,0.38);">
                  <img class="ico-md" src="../../meta-gym/assets/svg/workout/workout_history.svg" alt="Lịch sử" />
                </div>
                <span class="txt-xs" style="color:var(--text-warm-muted);">›</span>
              </div>
              <div style="font-size:14px;font-weight:800;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Lịch sử &amp; Check-in</div>
              <div class="txt-xs tnum" style="font-size:12px;margin-top:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">18 lượt đến phòng gym</div>
            </div>
          </div>

          <div class="grid-2" style="gap:9px;">
            <div class="card-warm-glass" style="margin-bottom:0;padding:12px;cursor:pointer;min-width:0;" data-go="member-exercises">
              <div class="row-between" style="margin-bottom:8px;">
                <div class="quick-ico" style="width:34px;height:34px;border-radius:10px;background:rgba(245,176,65,0.16);border:1px solid rgba(245,176,65,0.38);">
                  <img class="ico-md" src="../../meta-gym/assets/svg/catalog/equip_barbell.svg" alt="Thư viện bài tập" />
                </div>
                <span class="txt-xs" style="color:var(--text-warm-muted);">›</span>
              </div>
              <div style="font-size:14px;font-weight:800;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Thư viện bài tập</div>
              <div class="txt-xs tnum" style="font-size:12px;margin-top:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">120+ bài chuẩn form</div>
            </div>

            <div class="card-warm-glass" style="margin-bottom:0;padding:12px;cursor:pointer;min-width:0;" data-go="member-gym-equipment">
              <div class="row-between" style="margin-bottom:8px;">
                <div class="quick-ico" style="width:34px;height:34px;border-radius:10px;background:rgba(169,199,232,0.16);border:1px solid rgba(169,199,232,0.38);">
                  <img class="ico-md" src="../../meta-gym/assets/svg/catalog/equip_machine.svg" alt="Phòng gym & thiết bị" />
                </div>
                <span class="txt-xs" style="color:var(--text-warm-muted);">›</span>
              </div>
              <div style="font-size:14px;font-weight:800;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Phòng gym &amp; Thiết bị</div>
              <div class="txt-xs" style="font-size:12px;margin-top:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Hướng dẫn máy &amp; nội quy</div>
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
    id: 'member-nutrition',
    group: 'tab2-training',
    groupLabel: '2. Tập luyện',
    title: '2.2 Theo dõi dinh dưỡng',
    shortFile: 'nutrition_tracking_page.dart',
    flutterFile: 'mobile-app/lib/features/training/presentation/nutrition_tracking_page.dart',
    tag: 'P0 • 2.577 dòng',
    tagClass: 'p0',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body" style="padding-bottom:94px;">
          <!-- Transparent AppBar: back circle + Theo dõi dinh dưỡng -->
          <div class="mg-header">
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_back.svg" alt="Quay lại" /></div>
            <div class="mg-header-text">
              <div class="mg-title" style="font-size:20px;">Theo dõi dinh dưỡng</div>
            </div>
          </div>

          <!-- _summary (Date selector + 2 centered metrics) -->
          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:12px;">
              <span class="btn-secondary" style="height:30px;padding:0 10px;">‹</span>
              <span class="txt-sm txt-bold tnum">Hôm nay · 22/11/2026</span>
              <span class="btn-secondary" style="height:30px;padding:0 10px;opacity:0.45;">›</span>
            </div>
            <div class="grid-2">
              <div class="metric-box" style="text-align:center;">
                <div class="txt-xs">Tổng năng lượng</div>
                <div class="tnum txt-green" style="font-size:22px;font-weight:800;margin-top:2px;" data-nutri-kcal="1840">1.840 kcal</div>
              </div>
              <div class="metric-box" style="text-align:center;">
                <div class="txt-xs">Số món đã ghi</div>
                <div class="tnum" style="font-size:22px;font-weight:800;margin-top:2px;" data-nutri-count="4">4 món</div>
              </div>
            </div>
          </div>

          <!-- _coachSummary -->
          <div class="card-liquid" style="padding:12px 14px;">
            <div class="row-between">
              <div class="row" style="gap:8px;">
                <div class="avatar-ln" style="width:28px;height:28px;font-size:11px;">LN</div>
                <div>
                  <div class="txt-xs">Thực đơn từ Coach</div>
                  <div class="txt-sm txt-bold">Tăng cơ sạch — Tuần 4</div>
                </div>
              </div>
              <span class="pill pill-success">Đang áp dụng</span>
            </div>
          </div>

          <div class="sec-head"><h3 style="font-size:16px;">Nhật ký bữa ăn</h3></div>
          <div data-nutri-extra-meals></div>

          <!-- _mealSection: Bữa sáng -->
          <div class="card-liquid" style="padding:14px;">
            <div class="row-between">
              <div class="row" style="gap:10px;">
                <div class="quick-ico" style="width:34px;height:34px;"><img class="ico-md" src="../../meta-gym/assets/svg/nutrition/meal_breakfast.svg" alt="Bữa sáng" /></div>
                <div>
                  <div style="font-size:16px;font-weight:700;">Bữa sáng</div>
                  <div class="txt-xs tnum">1 món</div>
                </div>
              </div>
              <div class="btn-secondary" data-open-log-meal="Bữa sáng" data-meal-food="4" data-meal-grams="120" style="width:34px;height:34px;padding:0;cursor:pointer;" title="Chỉnh sửa Bữa sáng"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_edit.svg" alt="Sửa" /></div>
            </div>
            <div class="divider"></div>
            <div class="row" style="gap:10px;">
              <div class="quick-ico" style="width:28px;height:28px;background:rgba(46,204,113,0.14);"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/nutrition_dish_logged.svg" alt="Món đã ghi" /></div>
              <div style="flex:1;">
                <div class="txt-sm txt-bold tnum">Yến mạch + Chuối · 120 g</div>
                <div class="txt-xs txt-green txt-bold tnum">460 kcal</div>
                <div class="txt-xs tnum">Gợi ý 100 g · lệch +20 g</div>
              </div>
            </div>
          </div>

          <!-- _mealSection: Bữa trưa (có cả món đã ghi + món Gợi ý) -->
          <div class="card-liquid" style="padding:14px;">
            <div class="row-between">
              <div class="row" style="gap:10px;">
                <div class="quick-ico" style="width:34px;height:34px;background:rgba(46,204,113,0.14);"><img class="ico-md" src="../../meta-gym/assets/svg/nutrition/meal_lunch.svg" alt="Bữa trưa" /></div>
                <div>
                  <div style="font-size:16px;font-weight:700;">Bữa trưa</div>
                  <div class="txt-xs tnum">2 món</div>
                </div>
              </div>
              <div class="btn-secondary" data-open-log-meal="Bữa trưa" data-meal-food="0" data-meal-grams="200" style="width:34px;height:34px;padding:0;cursor:pointer;" title="Chỉnh sửa Bữa trưa"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_edit.svg" alt="Sửa" /></div>
            </div>
            <div class="divider"></div>
            <div class="row" style="gap:10px;margin-bottom:8px;">
              <div class="quick-ico" style="width:28px;height:28px;background:rgba(46,204,113,0.14);"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/nutrition_dish_logged.svg" alt="Món đã ghi" /></div>
              <div style="flex:1;">
                <div class="txt-sm txt-bold tnum">Ức gà áp chảo · 200 g</div>
                <div class="txt-xs txt-green txt-bold tnum">330 kcal</div>
              </div>
            </div>
            <div class="divider"></div>
            <div class="row-between">
              <div class="row" style="gap:10px;">
                <div class="quick-ico" style="width:28px;height:28px;background:rgba(245,176,65,0.14);"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/nutrition_coach_plan.svg" alt="Gợi ý" /></div>
                <div class="txt-sm tnum" style="color:var(--text-warm-muted);">Cơm gạo lứt · 180 g</div>
              </div>
              <span class="pill" style="background:rgba(245,176,65,0.14);color:var(--warning);border:1px solid rgba(245,176,65,0.35);">Gợi ý</span>
            </div>
          </div>
        </div>

        <!-- bottomNavigationBar: + Ghi lại bữa ăn -->
        <div class="bottom-cta-dock">
          <button type="button" class="btn-primary" data-open-log-meal>＋ Ghi lại bữa ăn</button>
        </div>
      </div>
    `
  },
  {
    id: 'member-journal',
    group: 'tab2-training',
    groupLabel: '2. Tập luyện',
    title: '2.3 Nhật ký tập luyện',
    shortFile: 'member_journal_page.dart',
    flutterFile: 'mobile-app/lib/features/progress/presentation/member_journal_page.dart',
    tag: 'P0 • 2.683 dòng',
    tagClass: 'p0',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body" style="padding-bottom:84px;">
          <div class="mg-header">
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_back.svg" alt="Quay lại" /></div>
            <div class="mg-header-text">
              <div class="mg-title" style="font-size:20px;">Nhật ký tập luyện</div>
            </div>
          </div>

          <!-- 2 Segmented Tabs: Nhật ký | Tiến độ -->
          <div class="seg-tabs">
            <div class="seg-tab active" data-state-btn="journal" style="cursor:pointer;">Nhật ký</div>
            <div class="seg-tab" data-state-btn="progress" style="cursor:pointer;">Tiến độ</div>
          </div>

          <!-- Panel 1: Nhật ký -->
          <div data-state-pane="journal">
            <div class="card-liquid" style="padding:12px;">
              <div class="row-between" style="margin-bottom:8px;">
                <strong class="txt-sm">Tuần này</strong>
                <span class="txt-xs" data-pick-date="2026-11-22" style="color:var(--primary);font-weight:600;cursor:pointer;">Xem tháng ›</span>
              </div>
              <div class="day-strip tnum" style="margin-bottom:0;">
                <div class="day-pill done">T2<strong>18</strong></div>
                <div class="day-pill done">T3<strong>19</strong></div>
                <div class="day-pill">T4<strong>20</strong></div>
                <div class="day-pill done">T5<strong>21</strong></div>
                <div class="day-pill active">T6<strong>22</strong></div>
                <div class="day-pill">T7<strong>23</strong></div>
                <div class="day-pill">CN<strong>24</strong></div>
              </div>
            </div>

            <div class="card-liquid">
              <div class="row-between" style="margin-bottom:8px;">
                <strong class="txt-sm">Thứ 6, 22 tháng 11</strong>
                <span class="pill pill-success">Hôm nay</span>
              </div>
              <div class="grid-2" style="margin-bottom:8px;">
                <div class="metric-box" style="cursor:pointer;" data-open-body-picker="weight" data-value="72.4"><div class="txt-xs">Cân nặng (kg)</div><div class="tnum txt-bold" style="font-size:16px;" data-field-weight>72.4</div></div>
                <div class="metric-box"><div class="txt-xs">Mỡ cơ thể (%)</div><div class="tnum txt-bold" style="font-size:16px;">16.8</div></div>
              </div>
              <div class="grid-3">
                <div class="metric-box" style="text-align:center;padding:6px;cursor:pointer;border:1px solid rgba(255,94,54,0.28);" data-open-tape="chest"><div class="txt-xs">Ngực</div><div class="tnum txt-bold txt-sm" data-vong-chest>98 cm</div></div>
                <div class="metric-box" style="text-align:center;padding:6px;cursor:pointer;border:1px solid rgba(46,204,113,0.28);" data-open-tape="waist"><div class="txt-xs">Eo</div><div class="tnum txt-bold txt-sm" data-vong-waist>78 cm</div></div>
                <div class="metric-box" style="text-align:center;padding:6px;cursor:pointer;border:1px solid rgba(112,174,232,0.28);" data-open-tape="hip"><div class="txt-xs">Hông</div><div class="tnum txt-bold txt-sm" data-vong-hip>94 cm</div></div>
              </div>
            </div>

            <div class="card-liquid">
              <div class="row-between" style="margin-bottom:8px;">
                <strong class="txt-sm">Thành tích buổi tập</strong>
                <span class="sec-link" data-open-add-pr style="cursor:pointer;">+ Thêm</span>
              </div>
              <div data-pr-list>
                <div class="row-between txt-sm" style="padding:6px 0;">
                  <span>Barbell Bench Press</span>
                  <strong class="tnum txt-orange">85 kg × 6</strong>
                </div>
              </div>
              <div class="divider"></div>
              <div class="txt-xs">Ghi chú: Cảm giác cơ ngực trên tốt, tăng +2.5kg so với tuần trước.</div>
            </div>
          </div>

          <!-- Panel 2: Tiến độ (Biểu đồ 30 ngày + Kỷ lục PR) -->
          <div data-state-pane="progress" style="display:none;">
            <div class="card-warm-glass" style="padding:13px 14px;">
              <div class="row-between" style="margin-bottom:8px;">
                <strong class="txt-sm">Tổng quan 30 ngày qua</strong>
                <span class="pill pill-success tnum">↑ Tiến bộ tốt</span>
              </div>
              <div class="grid-3">
                <div class="metric-box" style="text-align:center;padding:8px 4px;">
                  <div class="txt-xs">Cân nặng</div>
                  <div class="tnum txt-bold" style="font-size:15px;margin-top:2px;">72.4 kg</div>
                  <div class="txt-xs txt-green tnum">-1.8 kg</div>
                </div>
                <div class="metric-box" style="text-align:center;padding:8px 4px;">
                  <div class="txt-xs">Mỡ cơ thể</div>
                  <div class="tnum txt-bold" style="font-size:15px;margin-top:2px;">16.8%</div>
                  <div class="txt-xs txt-green tnum">-1.4%</div>
                </div>
                <div class="metric-box" style="text-align:center;padding:8px 4px;">
                  <div class="txt-xs">Số buổi</div>
                  <div class="tnum txt-bold txt-orange" style="font-size:15px;margin-top:2px;">16 buổi</div>
                  <div class="txt-xs tnum">Tháng 11</div>
                </div>
              </div>
            </div>

            <!-- Biểu đồ xu hướng Cân nặng SVG -->
            <div class="card-solid" style="padding:13px 14px;margin-bottom:10px;">
              <div class="row-between" style="margin-bottom:8px;">
                <div class="row" style="gap:6px;">
                  <img class="ico-sm" src="../../meta-gym/assets/svg/progress/stats_chart_line.svg" alt="Biểu đồ" />
                  <strong class="txt-sm">Xu hướng cân nặng (kg)</strong>
                </div>
                <span class="txt-xs tnum txt-green">74.2 → 72.4</span>
              </div>
              <svg viewBox="0 0 280 96" style="width:100%;height:92px;display:block;">
                <defs>
                  <linearGradient id="mgProgFill" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stop-color="#FF5E36" stop-opacity="0.34"/>
                    <stop offset="100%" stop-color="#FF5E36" stop-opacity="0.02"/>
                  </linearGradient>
                </defs>
                <line x1="12" y1="20" x2="268" y2="20" stroke="rgba(255,255,255,0.07)" stroke-dasharray="3 3"/>
                <line x1="12" y1="48" x2="268" y2="48" stroke="rgba(255,255,255,0.07)" stroke-dasharray="3 3"/>
                <line x1="12" y1="74" x2="268" y2="74" stroke="rgba(255,255,255,0.07)" stroke-dasharray="3 3"/>
                <path d="M18 22 L80 34 L142 46 L204 54 L262 66 L262 82 L18 82 Z" fill="url(#mgProgFill)"/>
                <polyline points="18,22 80,34 142,46 204,54 262,66" fill="none" stroke="#FF5E36" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>
                <circle cx="18" cy="22" r="3.5" fill="#FF5E36"/><circle cx="80" cy="34" r="3.5" fill="#FF5E36"/><circle cx="142" cy="46" r="3.5" fill="#FF5E36"/><circle cx="204" cy="54" r="3.5" fill="#FF5E36"/><circle cx="262" cy="66" r="4.5" fill="#2ECC71" stroke="#FFF" stroke-width="1.5"/>
                <text x="18" y="93" text-anchor="middle" fill="#8E95A5" font-size="9.5" font-family="Be Vietnam Pro,sans-serif">T1</text>
                <text x="80" y="93" text-anchor="middle" fill="#8E95A5" font-size="9.5" font-family="Be Vietnam Pro,sans-serif">T2</text>
                <text x="142" y="93" text-anchor="middle" fill="#8E95A5" font-size="9.5" font-family="Be Vietnam Pro,sans-serif">T3</text>
                <text x="204" y="93" text-anchor="middle" fill="#8E95A5" font-size="9.5" font-family="Be Vietnam Pro,sans-serif">T4</text>
                <text x="262" y="93" text-anchor="middle" fill="#2ECC71" font-size="9.5" font-weight="700" font-family="Be Vietnam Pro,sans-serif">Nay</text>
              </svg>
            </div>

            <!-- Kỷ lục cá nhân (PR) -->
            <div class="card-solid" style="padding:13px 14px;">
              <div class="row-between" style="margin-bottom:8px;">
                <strong class="txt-sm">Kỷ lục sức mạnh (PR)</strong>
                <span class="pill pill-orange tnum">3 bài chính</span>
              </div>
              <div class="row-between txt-sm" style="padding:6px 0;">
                <span>Barbell Bench Press</span>
                <span class="tnum"><strong>85 kg × 6</strong> <span class="txt-xs txt-green">(+5 kg)</span></span>
              </div>
              <div class="divider" style="margin:2px 0;"></div>
              <div class="row-between txt-sm" style="padding:6px 0;">
                <span>Back Squat</span>
                <span class="tnum"><strong>110 kg × 5</strong> <span class="txt-xs txt-green">(+10 kg)</span></span>
              </div>
              <div class="divider" style="margin:2px 0;"></div>
              <div class="row-between txt-sm" style="padding:6px 0;">
                <span>Romanian Deadlift</span>
                <span class="tnum"><strong>100 kg × 8</strong> <span class="txt-xs txt-green">(+7.5 kg)</span></span>
              </div>
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
    id: 'member-gym-visits',
    group: 'tab2-training',
    groupLabel: '2. Tập luyện',
    title: '2.4 Lịch sử đến gym',
    shortFile: 'gym_visits_page.dart',
    flutterFile: 'mobile-app/lib/features/training/presentation/gym_visits_page.dart',
    tag: 'P1 • Điểm danh QR',
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
              <div class="mg-eyebrow">ĐIỂM DANH QR</div>
              <div class="mg-title">Lịch sử đến gym</div>
            </div>
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_refresh.svg" alt="Tải lại" /></div>
          </div>

          <!-- Trạng thái chưa điểm danh hôm nay + Nút điểm danh nhanh -->
          <div class="card-solid checkin-alert-card" style="padding:12px 14px;border-color:rgba(255,94,54,0.48);background:linear-gradient(135deg,rgba(255,94,54,0.14),rgba(24,27,34,0.92));">
            <div class="row-between" style="gap:10px;">
              <div class="row" style="gap:10px;min-width:0;flex:1;">
                <div class="quick-ico" style="background:rgba(255,94,54,0.18);border:1px solid rgba(255,94,54,0.42);">
                  <img class="ico-md" src="../../meta-gym/assets/svg/states/qr_scan_frame.svg" alt="Điểm danh" style="background:transparent;padding:0;" />
                </div>
                <div style="min-width:0;">
                  <div style="font-size:14px;font-weight:700;">Hôm nay chưa điểm danh</div>
                  <div class="txt-xs">Mở mã QR hoặc quẹt thẻ NFC tại cổng</div>
                </div>
              </div>
              <button type="button" class="btn-mini-orange" data-open-qr style="height:36px;padding:0 12px;border-radius:11px;cursor:pointer;flex-shrink:0;">Điểm danh</button>
            </div>
          </div>

          <!-- MetaGymHeroGlassCard: Lịch đến gym -->
          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:12px;">
              <div class="row" style="gap:7px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/workout/workout_plan_calendar.svg" alt="Lịch" />
                <strong style="font-size:15px;">Lịch đến gym</strong>
              </div>
              <div class="row" style="gap:6px;background:var(--metric-panel-bg);border:1px solid var(--metric-panel-border);border-radius:999px;padding:4px 10px;font-size:12px;font-weight:700;">
                <span>‹</span>
                <span class="tnum">11/2026</span>
                <span style="opacity:0.4;">›</span>
              </div>
            </div>

            <!-- 2 Stat Panels -->
            <div class="grid-2" style="margin-bottom:14px;">
              <div class="metric-box">
                <div class="row" style="gap:6px;margin-bottom:4px;">
                  <img class="ico-xs" src="../../meta-gym/assets/svg/states/checkin_badge.svg" alt="Đã đến" />
                  <span class="txt-xs">Đã đến gym</span>
                </div>
                <div class="tnum txt-orange" style="font-size:22px;font-weight:800;">16 <span class="txt-xs">ngày</span></div>
              </div>
              <div class="metric-box">
                <div class="row" style="gap:6px;margin-bottom:4px;">
                  <img class="ico-xs" src="../../meta-gym/assets/svg/workout/workout_plan_calendar.svg" alt="Chưa đến" />
                  <span class="txt-xs">Ngày chưa đến</span>
                </div>
                <div class="tnum" style="font-size:22px;font-weight:800;">6 <span class="txt-xs">ngày</span></div>
              </div>
            </div>

            <!-- Lịch tháng 11/2026 -->
            <div class="cal-grid">
              <div class="cal-head">T2</div><div class="cal-head">T3</div><div class="cal-head">T4</div><div class="cal-head">T5</div><div class="cal-head">T6</div><div class="cal-head">T7</div><div class="cal-head">CN</div>
              <div class="cal-cell future"></div><div class="cal-cell future"></div><div class="cal-cell future"></div><div class="cal-cell future"></div><div class="cal-cell future"></div><div class="cal-cell future"></div><div class="cal-cell visited">1</div>
              <div class="cal-cell visited">2</div><div class="cal-cell visited">3</div><div class="cal-cell">4</div><div class="cal-cell visited">5</div><div class="cal-cell visited">6</div><div class="cal-cell visited">7</div><div class="cal-cell">8</div>
              <div class="cal-cell visited">9</div><div class="cal-cell visited">10</div><div class="cal-cell visited">11</div><div class="cal-cell">12</div><div class="cal-cell visited">13</div><div class="cal-cell visited">14</div><div class="cal-cell">15</div>
              <div class="cal-cell visited">16</div><div class="cal-cell visited">17</div><div class="cal-cell visited">18</div><div class="cal-cell visited">19</div><div class="cal-cell">20</div><div class="cal-cell visited">21</div><div class="cal-cell today">22</div>
              <div class="cal-cell future">23</div><div class="cal-cell future">24</div><div class="cal-cell future">25</div><div class="cal-cell future">26</div><div class="cal-cell future">27</div><div class="cal-cell future">28</div><div class="cal-cell future">29</div>
            </div>

            <div class="txt-xs" style="margin-top:10px;">Ngày chưa đến chỉ tính khi gói tập có hiệu lực.</div>
          </div>

          <!-- Các lần đến gym -->
          <div class="sec-head" style="margin-bottom:2px;">
            <h3 class="row" style="gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/workout/workout_history.svg" alt="Lịch sử" /><span>Các lần đến gym</span></h3>
            <span class="pill pill-success tnum">18 lượt quét</span>
          </div>
          <div class="txt-xs" style="margin-bottom:10px;">18 lượt quét trong tháng · Có thể vào nhiều lần mỗi ngày</div>

          <div class="card-liquid" style="padding:12px 14px;margin-bottom:9px;">
            <div class="row">
              <div class="quick-ico" style="background:rgba(46,204,113,0.14);"><img class="ico-md" src="../../meta-gym/assets/svg/states/checkin_badge.svg" alt="Check-in" /></div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong class="txt-sm">Meta Gym Flagship — Q1</strong>
                  <span class="pill pill-success">Hôm nay</span>
                </div>
                <div class="txt-xs tnum" style="margin-top:2px;">22/11/2026 · 17:54 · Cổng vào chính</div>
              </div>
            </div>
          </div>

          <div class="card-liquid" style="padding:12px 14px;">
            <div class="row">
              <div class="quick-ico"><img class="ico-md" src="../../meta-gym/assets/svg/states/checkin_badge.svg" alt="Check-in" /></div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong class="txt-sm">Meta Gym Flagship — Q1</strong>
                  <span class="txt-xs tnum">21/11</span>
                </div>
                <div class="txt-xs tnum" style="margin-top:2px;">21/11/2026 · 18:10 · Cổng vào chính</div>
              </div>
            </div>
          </div>
        </div>

        <div class="bottom-cta-dock">
          <button type="button" class="btn-primary" data-open-qr>
            <img class="ico-sm" src="../../meta-gym/assets/svg/states/qr_scan_frame.svg" alt="QR" style="background:transparent;padding:0;" />
            <span>Điểm danh ngay (Mã QR)</span>
          </button>
        </div>

        <!-- Level 3 Overlay Glass: Mã QR Check-in động trong ngày -->
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
    id: 'member-curriculum',
    group: 'tab2-training',
    groupLabel: '2. Tập luyện',
    title: '2.5 Giáo trình của Coach',
    shortFile: 'member_curriculum_detail_page.dart',
    flutterFile: 'mobile-app/lib/features/training/presentation/member_curriculum_detail_page.dart',
    tag: 'P1 • Giáo trình',
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
              <div class="mg-eyebrow">GIÁO TRÌNH COACH</div>
              <div class="mg-title">Hypertrophy 8 tuần</div>
            </div>
            <span class="btn-mini-orange">Nhắn Coach</span>
          </div>

          <div class="card-warm-glass" style="padding:13px 14px;">
            <div class="row-between">
              <div class="row" style="gap:9px;">
                <div class="avatar-ln" style="width:34px;height:34px;font-size:12px;">LN</div>
                <div>
                  <div class="txt-sm txt-bold">HLV Lê Hoàng Nam</div>
                  <div class="txt-xs tnum">Tuần 4 / 8 · 5 buổi/tuần</div>
                </div>
              </div>
              <span class="pill pill-success">Đang áp dụng</span>
            </div>
          </div>

          <div class="seg-tabs">
            <div class="seg-tab active" data-state-btn="workout" style="cursor:pointer;">Tập luyện</div>
            <div class="seg-tab" data-state-btn="meal" style="cursor:pointer;">Thực đơn</div>
          </div>

          <!-- Panel 1: Tập luyện -->
          <div data-state-pane="workout">
            <!-- Chọn ngày tập -->
            <div class="filter-row tnum">
              <div class="filter-pill">Ngày 1 · 4 bài</div>
              <div class="filter-pill active">Ngày 2 · 5 bài</div>
              <div class="filter-pill">Ngày 3 · 4 bài</div>
              <div class="filter-pill">Ngày 4 · 5 bài</div>
            </div>

            <div class="sec-head" style="margin-top:4px;"><h3>Ngày 2 · Upper Body &amp; Core</h3><span class="txt-xs tnum">60 phút</span></div>
            <div class="card-solid" style="padding:12px 14px;margin-bottom:9px;">
              <div class="row-between">
                <div class="row" style="gap:10px;">
                  <div class="quick-ico"><img class="ico-md" src="../../meta-gym/assets/svg/workout/workout_weight.svg" alt="Bài tập" /></div>
                  <div>
                    <div class="txt-sm txt-bold">Incline Dumbbell Press</div>
                    <div class="txt-xs tnum">4 hiệp × 10 reps · 24 kg · Nghỉ 90s</div>
                  </div>
                </div>
                <span class="pill pill-success">Xong</span>
              </div>
            </div>

            <div class="card-solid" style="padding:12px 14px;margin-bottom:9px;">
              <div class="row-between">
                <div class="row" style="gap:10px;">
                  <div class="quick-ico"><img class="ico-md" src="../../meta-gym/assets/svg/workout/workout_set_reps.svg" alt="Bài tập" /></div>
                  <div>
                    <div class="txt-sm txt-bold">Barbell Bench Press</div>
                    <div class="txt-xs tnum">4 hiệp × 8 reps · 80 kg · Nghỉ 120s</div>
                  </div>
                </div>
                <span class="pill pill-orange">Tiếp theo</span>
              </div>
            </div>

            <div class="card-solid" style="padding:12px 14px;">
              <div class="row-between">
                <div class="row" style="gap:10px;">
                  <div class="quick-ico"><img class="ico-md" src="../../meta-gym/assets/svg/catalog/equip_cable.svg" alt="Bài tập" /></div>
                  <div>
                    <div class="txt-sm txt-bold">Cable Crossover Fly</div>
                    <div class="txt-xs tnum">3 hiệp × 12 reps · 15 kg · Nghỉ 60s</div>
                  </div>
                </div>
                <span class="pill pill-muted">Chờ</span>
              </div>
            </div>
          </div>

          <!-- Panel 2: Thực đơn của Coach -->
          <div data-state-pane="meal" style="display:none;">
            <div class="card-solid" style="padding:12px 14px;margin-bottom:10px;">
              <div class="row-between" style="margin-bottom:8px;">
                <div class="row" style="gap:6px;">
                  <img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/nutrition_coach_plan.svg" alt="Thực đơn" />
                  <strong class="txt-sm">Mục tiêu Macro hôm nay</strong>
                </div>
                <span class="pill pill-orange tnum">2.450 kcal</span>
              </div>
              <div class="grid-3">
                <div class="metric-box" style="text-align:center;padding:7px 4px;"><div class="tnum txt-bold txt-green">160g</div><div class="txt-xs">Đạm</div></div>
                <div class="metric-box" style="text-align:center;padding:7px 4px;"><div class="tnum txt-bold">260g</div><div class="txt-xs">Tinh bột</div></div>
                <div class="metric-box" style="text-align:center;padding:7px 4px;"><div class="tnum txt-bold">65g</div><div class="txt-xs">Chất béo</div></div>
              </div>
            </div>

            <div class="sec-head" style="margin-top:4px;"><h3>Thực đơn 4 bữa trong ngày</h3><span class="txt-xs" style="color:var(--primary);cursor:pointer;" data-go="member-nutrition">Ghi bữa ăn ›</span></div>

            <div class="card-solid" style="padding:12px 14px;margin-bottom:9px;">
              <div class="row-between">
                <div class="row" style="gap:10px;">
                  <div class="quick-ico" style="background:rgba(245,176,65,0.14);"><img class="ico-md" src="../../meta-gym/assets/svg/nutrition/meal_breakfast.svg" alt="Bữa sáng" /></div>
                  <div>
                    <div class="txt-sm txt-bold">Bữa sáng · 07:30</div>
                    <div class="txt-xs tnum">Yến mạch 80g + 3 trứng gà + 1 chuối</div>
                  </div>
                </div>
                <span class="pill pill-success tnum">540 kcal</span>
              </div>
            </div>

            <div class="card-solid" style="padding:12px 14px;margin-bottom:9px;">
              <div class="row-between">
                <div class="row" style="gap:10px;">
                  <div class="quick-ico" style="background:rgba(46,204,113,0.14);"><img class="ico-md" src="../../meta-gym/assets/svg/nutrition/meal_lunch.svg" alt="Bữa trưa" /></div>
                  <div>
                    <div class="txt-sm txt-bold">Bữa trưa · 12:00</div>
                    <div class="txt-xs tnum">Ức gà 200g + Cơm gạo lứt 180g + Bông cải</div>
                  </div>
                </div>
                <span class="pill pill-success tnum">720 kcal</span>
              </div>
            </div>

            <div class="card-solid" style="padding:12px 14px;margin-bottom:9px;">
              <div class="row-between">
                <div class="row" style="gap:10px;">
                  <div class="quick-ico" style="background:rgba(255,94,54,0.14);"><img class="ico-md" src="../../meta-gym/assets/svg/quick_actions/action_nutrition.svg" alt="Sau tập" /></div>
                  <div>
                    <div class="txt-sm txt-bold">Sau tập · 19:30</div>
                    <div class="txt-xs tnum">1 muỗng Whey Isolate + 1 táo xanh</div>
                  </div>
                </div>
                <span class="pill pill-orange tnum">220 kcal</span>
              </div>
            </div>

            <div class="card-solid" style="padding:12px 14px;">
              <div class="row-between">
                <div class="row" style="gap:10px;">
                  <div class="quick-ico" style="background:rgba(112,174,232,0.14);"><img class="ico-md" src="../../meta-gym/assets/svg/nutrition/meal_dinner.svg" alt="Bữa tối" /></div>
                  <div>
                    <div class="txt-sm txt-bold">Bữa tối · 20:30</div>
                    <div class="txt-xs tnum">Cá hồi áp chảo 180g + Khoai lang 150g + Salad</div>
                  </div>
                </div>
                <span class="pill pill-muted tnum">680 kcal</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'member-gym-equipment',
    group: 'tab2-training',
    groupLabel: '2. Tập luyện',
    title: '2.6 Phòng gym & Thiết bị',
    shortFile: 'gym_equipment_page.dart',
    flutterFile: 'mobile-app/lib/features/catalog/presentation/gym_equipment_page.dart',
    tag: 'P1 • Thiết bị',
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
              <div class="mg-eyebrow">KHÁM PHÁ PHÒNG TẬP</div>
              <div class="mg-title">Phòng gym &amp; Thiết bị</div>
            </div>
          </div>

          <div class="input-box" style="height:42px;margin-bottom:10px;color:var(--text-secondary);font-size:14px;">
            <span class="row" style="gap:8px;"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_search.svg" alt="Tìm" /><span>Tìm tên máy hoặc nhóm cơ...</span></span>
          </div>

          <div class="filter-row">
            <div class="filter-pill active">Tất cả</div>
            <div class="filter-pill">Máy M3</div>
            <div class="filter-pill">Máy cáp</div>
            <div class="filter-pill">Cardio</div>
          </div>

          <!-- Nội quy an toàn -->
          <div class="card-warm-glass" style="padding:12px 14px;">
            <div class="row" style="gap:10px;">
              <img class="ico-md" src="../../meta-gym/assets/svg/catalog/exercise_safety_shield.svg" alt="Nội quy" />
              <div style="flex:1;">
                <div class="txt-sm txt-bold">Nội quy phòng tập Meta Gym</div>
                <div class="txt-xs">Trả tạ về kệ sau khi tập · Lau ghế máy · Mang giày thể thao</div>
              </div>
            </div>
          </div>

          <div class="sec-head"><h3>Danh mục thiết bị</h3><span class="txt-xs tnum">24 máy</span></div>
          <div class="card-liquid" style="padding:13px;margin-bottom:9px;">
            <div class="row-between">
              <div class="row" style="gap:11px;">
                <div class="quick-ico" style="width:48px;height:48px;"><img style="width:30px;height:30px;" src="../../meta-gym/assets/svg/equipment_m3/equip_m3_pec_fly_rear_delt.svg" alt="M3-1017" /></div>
                <div>
                  <div class="txt-sm txt-bold">Máy ép ngực / vai sau M3-1017</div>
                  <div class="txt-xs">Máy Realleader M3 · Ngực, Vai sau</div>
                </div>
              </div>
              <span class="pill pill-success">Sẵn sàng</span>
            </div>
          </div>

          <div class="card-liquid" style="padding:13px;margin-bottom:9px;">
            <div class="row-between">
              <div class="row" style="gap:11px;">
                <div class="quick-ico" style="width:48px;height:48px;"><img style="width:30px;height:30px;" src="../../meta-gym/assets/svg/equipment_m3/equip_m3_seated_leg_curl.svg" alt="M3-1018" /></div>
                <div>
                  <div class="txt-sm txt-bold">Máy cuốn đùi sau ngồi M3-1018</div>
                  <div class="txt-xs">Máy Realleader M3 · Đùi sau</div>
                </div>
              </div>
              <span class="pill pill-success">Sẵn sàng</span>
            </div>
          </div>

          <div class="card-liquid" style="padding:13px;margin-bottom:9px;">
            <div class="row-between">
              <div class="row" style="gap:11px;">
                <div class="quick-ico" style="width:48px;height:48px;"><img style="width:30px;height:30px;" src="../../meta-gym/assets/svg/equipment_m3/equip_m3_chin_dip_assist.svg" alt="M3-1020" /></div>
                <div>
                  <div class="txt-sm txt-bold">Máy xà đơn / xà kép trợ lực M3-1020</div>
                  <div class="txt-xs">Máy Realleader M3 · Lưng, Tay sau</div>
                </div>
              </div>
              <span class="pill pill-success">Sẵn sàng</span>
            </div>
          </div>

          <div class="card-liquid" style="padding:13px;">
            <div class="row-between">
              <div class="row" style="gap:11px;">
                <div class="quick-ico" style="width:48px;height:48px;"><img class="ico-md" src="../../meta-gym/assets/svg/catalog/equip_treadmill.svg" alt="Treadmill" /></div>
                <div>
                  <div class="txt-sm txt-bold">Technogym Artis Run</div>
                  <div class="txt-xs">Khu Cardio · Đốt mỡ &amp; Sức bền</div>
                </div>
              </div>
              <span class="pill pill-warning">Đang bảo trì</span>
            </div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'member-equipment-detail',
    group: 'tab2-training',
    groupLabel: '2. Tập luyện',
    title: '2.7 Chi tiết thiết bị',
    shortFile: 'equipment_detail_page.dart',
    flutterFile: 'mobile-app/lib/features/catalog/presentation/equipment_detail_page.dart',
    tag: 'P2 • Hướng dẫn máy',
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
              <div class="mg-eyebrow">HƯỚNG DẪN THIẾT BỊ</div>
              <div class="mg-title">Máy ép ngực / vai sau M3-1017</div>
            </div>
          </div>

          <div class="card-warm-glass">
            <div class="row" style="gap:12px;margin-bottom:10px;">
              <div class="quick-ico" style="width:60px;height:60px;border-radius:16px;"><img style="width:36px;height:36px;" src="../../meta-gym/assets/svg/equipment_m3/equip_m3_pec_fly_rear_delt.svg" alt="M3-1017" /></div>
              <div style="flex:1;">
                <div style="font-size:16px;font-weight:800;">Máy ép ngực / vai sau M3-1017</div>
                <div class="txt-xs">Máy Realleader M3 · Khối tạ xếp</div>
                <div style="margin-top:6px;"><span class="pill pill-success">● Sẵn sàng sử dụng</span></div>
              </div>
            </div>
            <div class="row" style="flex-wrap:wrap;gap:6px;">
              <span class="pill pill-orange">Ngực</span>
              <span class="pill pill-muted">Vai sau</span>
            </div>
          </div>

          <div class="card-solid" style="padding:14px;">
            <div class="row" style="gap:7px;margin-bottom:10px;">
              <img class="ico-sm" src="../../meta-gym/assets/svg/catalog/exercise_step_guide.svg" alt="Hướng dẫn" />
              <strong style="font-size:14px;">Hướng dẫn sử dụng từng bước</strong>
            </div>
            <div class="txt-xs" style="line-height:1.55;margin-bottom:8px;"><strong style="color:var(--primary);">Bước 1:</strong> Chỉnh độ cao ghế và góc tay đòn tương ứng bài ép ngực hoặc vai sau.</div>
            <div class="txt-xs" style="line-height:1.55;margin-bottom:8px;"><strong style="color:var(--primary);">Bước 2:</strong> Giữ lưng áp sát đệm, kéo hoặc ép tay đòn mượt mà theo cung tròn.</div>
            <div class="txt-xs" style="line-height:1.55;"><strong style="color:var(--primary);">Bước 3:</strong> Siết cơ 1 giây ở điểm đỉnh trước khi thả tạ chậm về vị trí mở.</div>
          </div>

          <div class="card-solid" style="padding:14px;">
            <div class="row" style="gap:7px;margin-bottom:6px;">
              <img class="ico-sm" src="../../meta-gym/assets/svg/catalog/exercise_safety_shield.svg" alt="An toàn" />
              <strong style="font-size:14px;">Lưu ý an toàn</strong>
            </div>
            <div class="txt-xs" style="line-height:1.5;">
              Khóa chốt biên độ tay đòn chắc chắn trước khi lên tạ nặng; không thả tạ rơi tự do.
            </div>
          </div>
        </div>
      </div>
    `
  }
]);
