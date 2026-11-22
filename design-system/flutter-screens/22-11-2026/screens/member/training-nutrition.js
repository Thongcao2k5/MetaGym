// Meta Gym Flutter Mockups — MEMBER / Tập luyện & Dinh dưỡng
window.METAGYM_SCREENS = window.METAGYM_SCREENS || {};
window.METAGYM_SCREENS.member = (window.METAGYM_SCREENS.member || []).concat([
  {
    id: 'member-nutrition',
    group: 'training',
    groupLabel: 'Tập luyện & Dinh dưỡng',
    title: '8. Theo dõi dinh dưỡng',
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
  }
]);
