// Meta Gym Flutter Mockups — MEMBER / Coach & Đặt lịch
window.METAGYM_SCREENS = window.METAGYM_SCREENS || {};
window.METAGYM_SCREENS.member = (window.METAGYM_SCREENS.member || []).concat([
  {
    id: 'member-coach-booking',
    group: 'coaching',
    groupLabel: 'Coach & Đặt lịch',
    title: '7. Lịch Coach',
    shortFile: 'coach_booking_page.dart',
    flutterFile: 'mobile-app/lib/features/sessions/presentation/coach_booking_page.dart',
    tag: 'P0 • 125 hex',
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
              <div class="mg-title" style="font-size:19px;">Lịch Coach</div>
              <div class="mg-sub">Đặt lịch &amp; quản lý buổi tập 1:1</div>
            </div>
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/workout/workout_history.svg" alt="Lịch sử" /></div>
          </div>

          <!-- _buildSegmentedTabs: 4 tab -->
          <div class="seg-tabs">
            <div class="seg-tab active">Tất cả</div>
            <div class="seg-tab">Gói Coach</div>
            <div class="seg-tab">Sắp tới</div>
            <div class="seg-tab">Lịch sử</div>
          </div>

          <!-- Gói Coach đang hiệu lực -->
          <div class="sec-head"><h3>Gói Coach đang hiệu lực</h3><span class="txt-xs tnum">1 gói</span></div>
          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:10px;">
              <div class="row" style="gap:8px;">
                <div class="avatar-ln">LN</div>
                <div>
                  <div class="txt-sm txt-bold">Lê Hoàng Nam</div>
                  <div class="txt-xs">Gói PT 24 buổi · Khung 90 phút</div>
                </div>
              </div>
              <span class="pill pill-success">Hiệu lực</span>
            </div>
            <div class="grid-3" style="margin-bottom:10px;">
              <div class="metric-box" style="text-align:center;padding:8px 4px;"><div class="tnum txt-bold">14</div><div class="txt-xs">Còn lại</div></div>
              <div class="metric-box" style="text-align:center;padding:8px 4px;"><div class="tnum txt-bold">10</div><div class="txt-xs">Đã tập</div></div>
              <div class="metric-box" style="text-align:center;padding:8px 4px;"><div class="tnum txt-bold">03/01</div><div class="txt-xs">Hết hạn</div></div>
            </div>
            <button class="btn-primary">Đặt buổi tập mới</button>
          </div>

          <!-- Buổi tập sắp tới -->
          <div class="sec-head"><h3>Buổi tập sắp tới</h3><span class="txt-xs tnum">2 lịch hẹn</span></div>
          <div class="card-liquid">
            <div class="row-between" style="margin-bottom:6px;">
              <span class="pill pill-success">Đã đặt lịch</span>
              <span class="txt-xs tnum">90 phút</span>
            </div>
            <div class="txt-sm txt-bold">Buổi tập với Coach Lê Hoàng Nam</div>
            <div class="txt-xs tnum" style="margin:4px 0 10px;">Thứ 6, 22/11/2026 · 18:00 – 19:30</div>
            <div class="grid-2">
              <span class="btn-secondary">Xem kế hoạch ngày</span>
              <span class="btn-secondary" style="color:var(--error);">Hủy lịch</span>
            </div>
          </div>
        </div>
      </div>
    `
  }
]);
