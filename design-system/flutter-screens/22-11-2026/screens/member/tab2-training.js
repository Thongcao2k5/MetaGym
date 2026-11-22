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
              <div class="mg-title" style="font-size:19px;">Theo dõi dinh dưỡng</div>
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
                <div class="tnum txt-green" style="font-size:21px;font-weight:800;margin-top:2px;">1.840 kcal</div>
              </div>
              <div class="metric-box" style="text-align:center;">
                <div class="txt-xs">Số món đã ghi</div>
                <div class="tnum" style="font-size:21px;font-weight:800;margin-top:2px;">4 món</div>
              </div>
            </div>
          </div>

          <!-- _coachSummary -->
          <div class="card-liquid" style="padding:12px 14px;">
            <div class="row-between">
              <div class="row" style="gap:8px;">
                <div class="avatar-ln" style="width:28px;height:28px;font-size:10px;">LN</div>
                <div>
                  <div class="txt-xs">Thực đơn từ Coach</div>
                  <div class="txt-sm txt-bold">Tăng cơ sạch — Tuần 4</div>
                </div>
              </div>
              <span class="pill pill-success">Đang áp dụng</span>
            </div>
          </div>

          <div class="sec-head"><h3 style="font-size:16px;">Nhật ký bữa ăn</h3></div>

          <!-- _mealSection: Bữa sáng -->
          <div class="card-liquid" style="padding:14px;">
            <div class="row-between">
              <div class="row" style="gap:10px;">
                <div class="quick-ico" style="width:34px;height:34px;"><img class="ico-md" src="../../meta-gym/assets/svg/nutrition/meal_breakfast.svg" alt="Bữa sáng" /></div>
                <div>
                  <div style="font-size:15.5px;font-weight:700;">Bữa sáng</div>
                  <div class="txt-xs tnum">1 món</div>
                </div>
              </div>
              <div class="btn-secondary" style="width:34px;height:34px;padding:0;"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_edit.svg" alt="Sửa" /></div>
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
                  <div style="font-size:15.5px;font-weight:700;">Bữa trưa</div>
                  <div class="txt-xs tnum">2 món</div>
                </div>
              </div>
              <div class="btn-secondary" style="width:34px;height:34px;padding:0;"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_edit.svg" alt="Sửa" /></div>
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
              <span class="pill" style="background:rgba(245,176,65,0.14);color:var(--coach-avatar-bg);border:1px solid rgba(245,176,65,0.35);">Gợi ý</span>
            </div>
          </div>
        </div>

        <!-- bottomNavigationBar: + Ghi lại bữa ăn -->
        <div class="bottom-cta-dock">
          <button class="btn-primary">＋ Ghi lại bữa ăn</button>
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
              <div class="mg-title" style="font-size:19px;">Nhật ký tập luyện</div>
            </div>
          </div>

          <!-- 2 Segmented Tabs: Nhật ký | Tiến độ -->
          <div class="seg-tabs">
            <div class="seg-tab active">Nhật ký</div>
            <div class="seg-tab">Tiến độ</div>
          </div>

          <div class="card-liquid" style="padding:12px;">
            <div class="row-between" style="margin-bottom:8px;">
              <strong class="txt-sm">Tuần này</strong>
              <span class="txt-xs" style="color:var(--reflection);">Xem tháng</span>
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
              <div class="metric-box"><div class="txt-xs">Cân nặng (kg)</div><div class="tnum txt-bold" style="font-size:16px;">72.4</div></div>
              <div class="metric-box"><div class="txt-xs">Mỡ cơ thể (%)</div><div class="tnum txt-bold" style="font-size:16px;">16.8</div></div>
            </div>
            <div class="grid-3">
              <div class="metric-box" style="text-align:center;padding:6px;"><div class="txt-xs">Ngực</div><div class="tnum txt-bold txt-sm">98 cm</div></div>
              <div class="metric-box" style="text-align:center;padding:6px;"><div class="txt-xs">Eo</div><div class="tnum txt-bold txt-sm">78 cm</div></div>
              <div class="metric-box" style="text-align:center;padding:6px;"><div class="txt-xs">Hông</div><div class="tnum txt-bold txt-sm">94 cm</div></div>
            </div>
          </div>

          <div class="card-liquid">
            <div class="row-between" style="margin-bottom:8px;">
              <strong class="txt-sm">Thành tích buổi tập</strong>
              <span class="sec-link">+ Thêm</span>
            </div>
            <div class="row-between txt-sm" style="padding:6px 0;">
              <span>Barbell Bench Press</span>
              <strong class="tnum txt-orange">85 kg × 6</strong>
            </div>
            <div class="divider"></div>
            <div class="txt-xs">Ghi chú: Cảm giác cơ ngực trên tốt, tăng +2.5kg so với tuần trước.</div>
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
          <button class="btn-primary">
            <img class="ico-sm" src="../../meta-gym/assets/svg/states/qr_scan_frame.svg" alt="QR" style="background:transparent;padding:0;" />
            <span>Quét mã QR điểm danh</span>
          </button>
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
                <div class="avatar-ln" style="width:34px;height:34px;font-size:11.5px;">LN</div>
                <div>
                  <div class="txt-sm txt-bold">HLV Lê Hoàng Nam</div>
                  <div class="txt-xs tnum">Tuần 4 / 8 · 5 buổi/tuần</div>
                </div>
              </div>
              <span class="pill pill-success">Đang áp dụng</span>
            </div>
          </div>

          <div class="seg-tabs">
            <div class="seg-tab active">Tập luyện</div>
            <div class="seg-tab">Thực đơn</div>
          </div>

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

          <div class="input-box" style="height:42px;margin-bottom:10px;color:var(--text-secondary);font-size:13px;">
            <span class="row" style="gap:8px;"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_search.svg" alt="Tìm" /><span>Tìm tên máy hoặc nhóm cơ...</span></span>
          </div>

          <div class="filter-row">
            <div class="filter-pill active">Tất cả</div>
            <div class="filter-pill">Máy cáp</div>
            <div class="filter-pill">Free Weight</div>
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
                <div class="quick-ico"><img class="ico-md" src="../../meta-gym/assets/svg/catalog/equip_cable.svg" alt="Cable" /></div>
                <div>
                  <div class="txt-sm txt-bold">Cable Crossover Dual</div>
                  <div class="txt-xs">Khu Máy Cáp · Ngực, Vai, Tay sau</div>
                </div>
              </div>
              <span class="pill pill-success">Sẵn sàng</span>
            </div>
          </div>

          <div class="card-liquid" style="padding:13px;margin-bottom:9px;">
            <div class="row-between">
              <div class="row" style="gap:11px;">
                <div class="quick-ico"><img class="ico-md" src="../../meta-gym/assets/svg/catalog/equip_machine.svg" alt="Smith" /></div>
                <div>
                  <div class="txt-sm txt-bold">Smith Machine Pro 3D</div>
                  <div class="txt-xs">Khu Free Weight · Squat, Bench Press</div>
                </div>
              </div>
              <span class="pill pill-success">Sẵn sàng</span>
            </div>
          </div>

          <div class="card-liquid" style="padding:13px;">
            <div class="row-between">
              <div class="row" style="gap:11px;">
                <div class="quick-ico"><img class="ico-md" src="../../meta-gym/assets/svg/catalog/equip_treadmill.svg" alt="Treadmill" /></div>
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
              <div class="mg-title">Cable Crossover Dual</div>
            </div>
          </div>

          <div class="card-warm-glass">
            <div class="row" style="gap:12px;margin-bottom:10px;">
              <div class="quick-ico" style="width:52px;height:52px;border-radius:16px;"><img class="ico-lg" src="../../meta-gym/assets/svg/catalog/equip_cable.svg" alt="Cable Crossover" /></div>
              <div style="flex:1;">
                <div style="font-size:17px;font-weight:800;">Cable Crossover Dual</div>
                <div class="txt-xs">Khu Máy Cáp · Tầng 2 · Tải tối đa 120 kg</div>
                <div style="margin-top:6px;"><span class="pill pill-success">● Sẵn sàng sử dụng</span></div>
              </div>
            </div>
            <div class="row" style="flex-wrap:wrap;gap:6px;">
              <span class="pill pill-orange">Ngực giữa</span>
              <span class="pill pill-muted">Vai trước</span>
              <span class="pill pill-muted">Tay sau</span>
            </div>
          </div>

          <div class="card-solid" style="padding:14px;">
            <div class="row" style="gap:7px;margin-bottom:10px;">
              <img class="ico-sm" src="../../meta-gym/assets/svg/catalog/exercise_step_guide.svg" alt="Hướng dẫn" />
              <strong style="font-size:14px;">Hướng dẫn sử dụng từng bước</strong>
            </div>
            <div class="txt-xs" style="line-height:1.55;margin-bottom:8px;"><strong style="color:var(--primary);">Bước 1:</strong> Chỉnh chốt ròng rọc hai bên ngang tầm vai và cài mức tạ phù hợp.</div>
            <div class="txt-xs" style="line-height:1.55;margin-bottom:8px;"><strong style="color:var(--primary);">Bước 2:</strong> Bước nhẹ một chân lên trước, giữ lưng thẳng và hơi gập khuỷu tay.</div>
            <div class="txt-xs" style="line-height:1.55;"><strong style="color:var(--primary);">Bước 3:</strong> Ép hai tay về phía trước ngực, siết cơ 1 giây rồi trả chậm có kiểm soát.</div>
          </div>

          <div class="card-solid" style="padding:14px;">
            <div class="row" style="gap:7px;margin-bottom:6px;">
              <img class="ico-sm" src="../../meta-gym/assets/svg/catalog/exercise_safety_shield.svg" alt="An toàn" />
              <strong style="font-size:14px;">Lưu ý an toàn</strong>
            </div>
            <div class="txt-xs" style="line-height:1.5;">
              Kiểm tra chốt tạ đã cắm chặt trước khi kéo; không thả rơi tạ tự do gây đứt dây cáp.
            </div>
          </div>
        </div>
      </div>
    `
  }
]);
