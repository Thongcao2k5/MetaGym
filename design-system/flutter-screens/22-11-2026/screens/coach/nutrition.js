// Meta Gym Flutter Mockups — COACH / 3.5 Thực đơn 7 ngày chi tiết (MealPlansPage V2 — tách riêng bài tập)
window.METAGYM_SCREENS = window.METAGYM_SCREENS || {};
window.METAGYM_SCREENS.coach = (window.METAGYM_SCREENS.coach || []).concat([
  {
    id: 'coach-meal-plan',
    group: 'coach-tab3-training',
    groupLabel: '3. Giáo án & Thực đơn',
    title: '3.5 Thực đơn 7 ngày chi tiết',
    shortFile: 'meal_plans_page.dart',
    flutterFile: 'mobile-app/lib/features/training/presentation/meal_plans_page.dart',
    tag: 'P0 • MealPlansPage V2',
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
              <div class="mg-eyebrow">MINH QUÂN · MEAL PLAN</div>
              <div class="mg-title">Thực đơn 7 ngày</div>
            </div>
            <div class="circle-btn" data-open-coach-modal="add-food" title="Thêm món ăn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_add.svg" alt="Thêm món" /></div>
          </div>

          <div class="card-warm-glass">
            <div class="field" style="margin-bottom:10px;">
              <label>Tên thực đơn</label>
              <div class="input-box">Thực đơn Tăng cơ giảm mỡ · Tuần 4</div>
            </div>
            <div class="grid-3">
              <div class="metric-box" style="text-align:center;padding:8px 4px;">
                <div class="tnum txt-bold txt-orange" style="font-size:16px;">~2.155</div>
                <div class="txt-xs">TB kcal/ngày</div>
              </div>
              <div class="metric-box" style="text-align:center;padding:8px 4px;">
                <div class="tnum txt-bold" style="font-size:16px;">21 bữa</div>
                <div class="txt-xs">Sáng · Trưa · Tối</div>
              </div>
              <div class="metric-box" style="text-align:center;padding:8px 4px;">
                <div class="tnum txt-bold txt-green" style="font-size:16px;">7/7</div>
                <div class="txt-xs">Ngày T2 – CN</div>
              </div>
            </div>
          </div>

          <!-- Bộ chọn 7 ngày T2 - CN (chuyển đổi thực đơn thật từng ngày) -->
          <div class="filter-row">
            <div class="filter-pill active" data-state-btn="t2">T2</div>
            <div class="filter-pill" data-state-btn="t3">T3</div>
            <div class="filter-pill" data-state-btn="t4">T4</div>
            <div class="filter-pill" data-state-btn="t5">T5</div>
            <div class="filter-pill" data-state-btn="t6">T6</div>
            <div class="filter-pill" data-state-btn="t7">T7</div>
            <div class="filter-pill" data-state-btn="cn">CN</div>
          </div>

          <!-- Thứ 2 -->
          <div data-state-pane="t2">
            <div class="sec-head" style="margin-top:4px;">
              <h3>Thứ 2 · 2.185 kcal</h3>
              <span class="sec-link" data-open-coach-modal="add-food" style="cursor:pointer;">+ Thêm món</span>
            </div>
            <div class="card-liquid" style="padding:13px;">
              <div class="row-between" style="margin-bottom:8px;">
                <div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_breakfast.svg" alt="Bữa sáng" /><strong class="txt-sm">Bữa sáng</strong></div>
                <span class="pill pill-muted tnum">540 kcal</span>
              </div>
              <div class="metric-box" style="margin-bottom:6px;"><div class="row-between" style="gap:8px;"><div style="min-width:0;"><div class="txt-sm txt-bold">Yến mạch nguyên hạt + Sữa tách béo</div><div class="txt-xs tnum" style="margin-top:2px;">70 g yến mạch · 250 ml sữa · 320 kcal</div></div><button type="button" style="background:none;border:none;padding:2px;cursor:pointer;" data-coach-toast="Đã xóa món khỏi Bữa sáng"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></button></div></div>
              <div class="metric-box"><div class="row-between" style="gap:8px;"><div style="min-width:0;"><div class="txt-sm txt-bold">Trứng gà luộc</div><div class="txt-xs tnum" style="margin-top:2px;">180 g · 122 kcal/100g · 220 kcal</div></div><button type="button" style="background:none;border:none;padding:2px;cursor:pointer;" data-coach-toast="Đã xóa món khỏi Bữa sáng"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></button></div></div>
            </div>
            <div class="card-liquid" style="padding:13px;">
              <div class="row-between" style="margin-bottom:8px;">
                <div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_lunch.svg" alt="Bữa trưa" /><strong class="txt-sm">Bữa trưa</strong></div>
                <span class="pill pill-muted tnum">795 kcal</span>
              </div>
              <div class="metric-box" style="margin-bottom:6px;"><div class="row-between" style="gap:8px;"><div style="min-width:0;"><div class="txt-sm txt-bold">Ức gà áp chảo</div><div class="txt-xs tnum" style="margin-top:2px;">200 g · 165 kcal/100g · 330 kcal</div></div><button type="button" style="background:none;border:none;padding:2px;cursor:pointer;" data-coach-toast="Đã xóa món khỏi Bữa trưa"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></button></div></div>
              <div class="metric-box"><div class="row-between" style="gap:8px;"><div style="min-width:0;"><div class="txt-sm txt-bold">Cơm gạo lứt + Bông cải xanh</div><div class="txt-xs tnum" style="margin-top:2px;">400 g · 465 kcal</div></div><button type="button" style="background:none;border:none;padding:2px;cursor:pointer;" data-coach-toast="Đã xóa món khỏi Bữa trưa"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></button></div></div>
            </div>
            <div class="card-liquid" style="padding:13px;">
              <div class="row-between" style="margin-bottom:8px;">
                <div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_dinner.svg" alt="Bữa tối" /><strong class="txt-sm">Bữa tối</strong></div>
                <span class="pill pill-muted tnum">850 kcal</span>
              </div>
              <div class="metric-box"><div class="row-between" style="gap:8px;"><div style="min-width:0;"><div class="txt-sm txt-bold">Cá hồi phi lê nướng + Khoai lang</div><div class="txt-xs tnum" style="margin-top:2px;">380 g · 850 kcal</div></div><button type="button" style="background:none;border:none;padding:2px;cursor:pointer;" data-coach-toast="Đã xóa món khỏi Bữa tối"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></button></div></div>
            </div>
          </div>

          <!-- Thứ 3 -->
          <div data-state-pane="t3" style="display:none;">
            <div class="sec-head" style="margin-top:4px;"><h3>Thứ 3 · 2.090 kcal</h3><span class="sec-link" data-open-coach-modal="add-food" style="cursor:pointer;">+ Thêm món</span></div>
            <div class="card-liquid" style="padding:13px;"><div class="row-between" style="margin-bottom:8px;"><div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_breakfast.svg" alt="Sáng" /><strong class="txt-sm">Bữa sáng</strong></div><span class="pill pill-muted tnum">510 kcal</span></div><div class="metric-box"><div class="row-between"><div><div class="txt-sm txt-bold">Bánh mì nguyên cám + Trứng ốp la + Bơ</div><div class="txt-xs tnum">220 g · 510 kcal</div></div><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></div></div></div>
            <div class="card-liquid" style="padding:13px;"><div class="row-between" style="margin-bottom:8px;"><div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_lunch.svg" alt="Trưa" /><strong class="txt-sm">Bữa trưa</strong></div><span class="pill pill-muted tnum">810 kcal</span></div><div class="metric-box"><div class="row-between"><div><div class="txt-sm txt-bold">Thịt bò thăn áp chảo + Cơm trắng + Rau</div><div class="txt-xs tnum">450 g · 810 kcal</div></div><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></div></div></div>
            <div class="card-liquid" style="padding:13px;"><div class="row-between" style="margin-bottom:8px;"><div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_dinner.svg" alt="Tối" /><strong class="txt-sm">Bữa tối</strong></div><span class="pill pill-muted tnum">770 kcal</span></div><div class="metric-box"><div class="row-between"><div><div class="txt-sm txt-bold">Tôm hấp + Miến dong trộn rau</div><div class="txt-xs tnum">360 g · 770 kcal</div></div><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></div></div></div>
          </div>

          <!-- Thứ 4 -->
          <div data-state-pane="t4" style="display:none;">
            <div class="sec-head" style="margin-top:4px;"><h3>Thứ 4 · 2.240 kcal</h3><span class="sec-link" data-open-coach-modal="add-food" style="cursor:pointer;">+ Thêm món</span></div>
            <div class="card-liquid" style="padding:13px;"><div class="row-between" style="margin-bottom:8px;"><div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_breakfast.svg" alt="Sáng" /><strong class="txt-sm">Bữa sáng</strong></div><span class="pill pill-muted tnum">560 kcal</span></div><div class="metric-box"><div class="row-between"><div><div class="txt-sm txt-bold">Phở ức gà ít béo + 2 trứng trần</div><div class="txt-xs tnum">480 g · 560 kcal</div></div><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></div></div></div>
            <div class="card-liquid" style="padding:13px;"><div class="row-between" style="margin-bottom:8px;"><div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_lunch.svg" alt="Trưa" /><strong class="txt-sm">Bữa trưa</strong></div><span class="pill pill-muted tnum">880 kcal</span></div><div class="metric-box"><div class="row-between"><div><div class="txt-sm txt-bold">Cá thu kho gừng + Khoai tây nướng</div><div class="txt-xs tnum">430 g · 880 kcal</div></div><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></div></div></div>
            <div class="card-liquid" style="padding:13px;"><div class="row-between" style="margin-bottom:8px;"><div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_dinner.svg" alt="Tối" /><strong class="txt-sm">Bữa tối</strong></div><span class="pill pill-muted tnum">800 kcal</span></div><div class="metric-box"><div class="row-between"><div><div class="txt-sm txt-bold">Ức gà nướng + Mỳ Ý nguyên cám</div><div class="txt-xs tnum">400 g · 800 kcal</div></div><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></div></div></div>
          </div>

          <!-- Thứ 5 -->
          <div data-state-pane="t5" style="display:none;">
            <div class="sec-head" style="margin-top:4px;"><h3>Thứ 5 · 2.050 kcal (Ngày nhẹ)</h3><span class="sec-link" data-open-coach-modal="add-food" style="cursor:pointer;">+ Thêm món</span></div>
            <div class="card-liquid" style="padding:13px;"><div class="row-between" style="margin-bottom:8px;"><div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_breakfast.svg" alt="Sáng" /><strong class="txt-sm">Bữa sáng</strong></div><span class="pill pill-muted tnum">490 kcal</span></div><div class="metric-box"><div class="row-between"><div><div class="txt-sm txt-bold">Sữa chua Hy Lạp + Granola + Chuối</div><div class="txt-xs tnum">280 g · 490 kcal</div></div><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></div></div></div>
            <div class="card-liquid" style="padding:13px;"><div class="row-between" style="margin-bottom:8px;"><div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_lunch.svg" alt="Trưa" /><strong class="txt-sm">Bữa trưa</strong></div><span class="pill pill-muted tnum">780 kcal</span></div><div class="metric-box"><div class="row-between"><div><div class="txt-sm txt-bold">Phi lê cá basa áp chảo + Cơm gạo lứt</div><div class="txt-xs tnum">420 g · 780 kcal</div></div><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></div></div></div>
            <div class="card-liquid" style="padding:13px;"><div class="row-between" style="margin-bottom:8px;"><div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_dinner.svg" alt="Tối" /><strong class="txt-sm">Bữa tối</strong></div><span class="pill pill-muted tnum">780 kcal</span></div><div class="metric-box"><div class="row-between"><div><div class="txt-sm txt-bold">Salad thịt bò nướng + Khoai lang tím</div><div class="txt-xs tnum">380 g · 780 kcal</div></div><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></div></div></div>
          </div>

          <!-- Thứ 6 -->
          <div data-state-pane="t6" style="display:none;">
            <div class="sec-head" style="margin-top:4px;"><h3>Thứ 6 · 2.195 kcal</h3><span class="sec-link" data-open-coach-modal="add-food" style="cursor:pointer;">+ Thêm món</span></div>
            <div class="card-liquid" style="padding:13px;"><div class="row-between" style="margin-bottom:8px;"><div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_breakfast.svg" alt="Sáng" /><strong class="txt-sm">Bữa sáng</strong></div><span class="pill pill-muted tnum">545 kcal</span></div><div class="metric-box"><div class="row-between"><div><div class="txt-sm txt-bold">Yến mạch + Trứng luộc + Táo xanh</div><div class="txt-xs tnum">350 g · 545 kcal</div></div><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></div></div></div>
            <div class="card-liquid" style="padding:13px;"><div class="row-between" style="margin-bottom:8px;"><div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_lunch.svg" alt="Trưa" /><strong class="txt-sm">Bữa trưa</strong></div><span class="pill pill-muted tnum">840 kcal</span></div><div class="metric-box"><div class="row-between"><div><div class="txt-sm txt-bold">Đùi gà góc tư bỏ da nướng + Cơm</div><div class="txt-xs tnum">460 g · 840 kcal</div></div><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></div></div></div>
            <div class="card-liquid" style="padding:13px;"><div class="row-between" style="margin-bottom:8px;"><div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_dinner.svg" alt="Tối" /><strong class="txt-sm">Bữa tối</strong></div><span class="pill pill-muted tnum">810 kcal</span></div><div class="metric-box"><div class="row-between"><div><div class="txt-sm txt-bold">Cá hồi sốt cam + Bông cải hấp</div><div class="txt-xs tnum">360 g · 810 kcal</div></div><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></div></div></div>
          </div>

          <!-- Thứ 7 -->
          <div data-state-pane="t7" style="display:none;">
            <div class="sec-head" style="margin-top:4px;"><h3>Thứ 7 · 2.310 kcal (Ngày tập nặng)</h3><span class="sec-link" data-open-coach-modal="add-food" style="cursor:pointer;">+ Thêm món</span></div>
            <div class="card-liquid" style="padding:13px;"><div class="row-between" style="margin-bottom:8px;"><div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_breakfast.svg" alt="Sáng" /><strong class="txt-sm">Bữa sáng</strong></div><span class="pill pill-muted tnum">600 kcal</span></div><div class="metric-box"><div class="row-between"><div><div class="txt-sm txt-bold">Xôi đậu xanh ức gà xé + Trứng</div><div class="txt-xs tnum">320 g · 600 kcal</div></div><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></div></div></div>
            <div class="card-liquid" style="padding:13px;"><div class="row-between" style="margin-bottom:8px;"><div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_lunch.svg" alt="Trưa" /><strong class="txt-sm">Bữa trưa</strong></div><span class="pill pill-muted tnum">890 kcal</span></div><div class="metric-box"><div class="row-between"><div><div class="txt-sm txt-bold">Bít tết bò Úc + Khoai nghiền</div><div class="txt-xs tnum">460 g · 890 kcal</div></div><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></div></div></div>
            <div class="card-liquid" style="padding:13px;"><div class="row-between" style="margin-bottom:8px;"><div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_dinner.svg" alt="Tối" /><strong class="txt-sm">Bữa tối</strong></div><span class="pill pill-muted tnum">820 kcal</span></div><div class="metric-box"><div class="row-between"><div><div class="txt-sm txt-bold">Cơm gạo lứt + Thịt nạc vai + Canh bí</div><div class="txt-xs tnum">480 g · 820 kcal</div></div><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></div></div></div>
          </div>

          <!-- Chủ nhật -->
          <div data-state-pane="cn" style="display:none;">
            <div class="sec-head" style="margin-top:4px;"><h3>Chủ nhật · 1.980 kcal (Ngày nghỉ)</h3><span class="sec-link" data-open-coach-modal="add-food" style="cursor:pointer;">+ Thêm món</span></div>
            <div class="card-liquid" style="padding:13px;"><div class="row-between" style="margin-bottom:8px;"><div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_breakfast.svg" alt="Sáng" /><strong class="txt-sm">Bữa sáng</strong></div><span class="pill pill-muted tnum">480 kcal</span></div><div class="metric-box"><div class="row-between"><div><div class="txt-sm txt-bold">Cháo yến mạch thịt bằm + Rau thơm</div><div class="txt-xs tnum">360 g · 480 kcal</div></div><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></div></div></div>
            <div class="card-liquid" style="padding:13px;"><div class="row-between" style="margin-bottom:8px;"><div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_lunch.svg" alt="Trưa" /><strong class="txt-sm">Bữa trưa</strong></div><span class="pill pill-muted tnum">760 kcal</span></div><div class="metric-box"><div class="row-between"><div><div class="txt-sm txt-bold">Cá chẽm hấp gừng + Cơm gạo lứt</div><div class="txt-xs tnum">420 g · 760 kcal</div></div><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></div></div></div>
            <div class="card-liquid" style="padding:13px;"><div class="row-between" style="margin-bottom:8px;"><div class="row" style="gap:7px;"><img class="ico-sm" src="../../meta-gym/assets/svg/nutrition/meal_dinner.svg" alt="Tối" /><strong class="txt-sm">Bữa tối</strong></div><span class="pill pill-muted tnum">740 kcal</span></div><div class="metric-box"><div class="row-between"><div><div class="txt-sm txt-bold">Salad ức gà nướng + Hạt hạnh nhân</div><div class="txt-xs tnum">340 g · 740 kcal</div></div><img class="ico-sm" src="../../meta-gym/assets/svg/setting/common_delete.svg" alt="Xóa" /></div></div></div>
          </div>
        </div>

        <div class="bottom-cta-dock" style="display:grid;grid-template-columns:1fr 1fr;gap:10px;">
          <button type="button" class="btn-secondary" data-open-coach-modal="add-food">+ Thêm món</button>
          <button type="button" class="btn-primary" data-coach-toast="Đã lưu Thực đơn 7 ngày (PUT /coach/meal-plans)">Lưu thực đơn</button>
        </div>

        <!-- Level 3 Modal: Thêm món ăn từ Catalog (/nutrition-foods) -->
        <div class="qr-overlay" data-coach-modal="add-food">
          <div class="qr-sheet" style="text-align:left;">
            <div class="row-between" style="margin-bottom:10px;">
              <div style="font-size:16px;font-weight:800;">Thêm món ăn vào Thực đơn</div>
              <button type="button" class="circle-btn" style="width:32px;height:32px;font-size:14px;" data-close-coach-modal>✕</button>
            </div>
            <div class="grid-2" style="gap:8px;">
              <div class="field">
                <label>Ngày</label>
                <div class="input-box" style="height:40px;">Thứ 2 – CN</div>
              </div>
              <div class="field">
                <label>Bữa ăn</label>
                <div class="input-box" style="height:40px;">Bữa tối</div>
              </div>
            </div>
            <div class="field">
              <label>Thực phẩm (Catalog)</label>
              <div class="input-box" style="height:42px;">
                <span>Sữa chua Hy Lạp không đường</span>
                <span class="txt-xs txt-orange">Chọn ›</span>
              </div>
            </div>
            <div class="field" style="margin-bottom:12px;">
              <label>Khối lượng (gram)</label>
              <div class="input-box tnum" style="height:42px;">150 g <span class="txt-xs" style="color:var(--text-warm-muted);">(90 kcal/100g · ~135 kcal)</span></div>
            </div>
            <div class="grid-2" style="gap:10px;">
              <button type="button" class="btn-secondary" style="height:44px;" data-close-coach-modal>Hủy</button>
              <button type="button" class="btn-primary" style="height:44px;" data-close-coach-modal data-coach-toast="Đã thêm 150g Sữa chua Hy Lạp vào thực đơn">Thêm vào ngày</button>
            </div>
          </div>
        </div>
      </div>
    `
  }
]);
