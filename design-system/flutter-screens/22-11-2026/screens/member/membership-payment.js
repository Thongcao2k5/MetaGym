// Meta Gym Flutter Mockups — MEMBER / Gói tập & Thanh toán
window.METAGYM_SCREENS = window.METAGYM_SCREENS || {};
window.METAGYM_SCREENS.member = (window.METAGYM_SCREENS.member || []).concat([
  {
    id: 'member-membership',
    group: 'membership',
    groupLabel: 'Gói tập & Thanh toán',
    title: '6. Gói tập',
    shortFile: 'membership_page.dart',
    flutterFile: 'mobile-app/lib/features/membership/presentation/membership_page.dart',
    tag: 'P1',
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
              <div class="mg-eyebrow">HỘI VIÊN &amp; ƯU ĐÃI</div>
              <div class="mg-title">Gói tập</div>
            </div>
          </div>

          <div class="sec-head" style="margin-top:4px;"><h3 class="row" style="gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/membership/membership_active_seal.svg" alt="Gói của tôi" /><span>Gói của tôi</span></h3></div>
          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:6px;">
              <span class="pill pill-success">Hiệu lực</span>
              <span class="txt-xs tnum">22/10/2026 → 03/01/2027</span>
            </div>
            <div style="font-size:17px;font-weight:800;">Gói Hội viên 3 Tháng</div>
            <div class="txt-xs tnum" style="margin-top:4px;">Còn lại 42 ngày sử dụng phòng tập</div>
          </div>

          <div class="sec-head"><h3 class="row" style="gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/membership/premium_crown.svg" alt="Gói đang bán" /><span>Gói đang bán</span></h3><span class="txt-xs tnum">3 lựa chọn</span></div>
          <div class="card-liquid" style="border-color:rgba(255,94,54,0.5);">
            <div class="row-between" style="margin-bottom:4px;">
              <strong style="font-size:15px;">Gói Pro 6 Tháng</strong>
              <span class="pill pill-orange">Phổ biến</span>
            </div>
            <div class="tnum" style="font-size:21px;font-weight:800;margin:4px 0;">4.490.000đ <span class="txt-xs">/ 180 ngày</span></div>
            <div class="txt-xs" style="margin-bottom:10px;">Toàn quyền phòng gym · Thanh toán MoMo / VNPay</div>
            <button class="btn-primary">Đăng ký gói này</button>
          </div>

          <div class="sec-head"><h3 class="row" style="gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/workout/workout_history.svg" alt="Lịch sử gói" /><span>Lịch sử gói</span></h3><span class="sec-link row" style="gap:4px;"><img class="ico-xs" src="../../meta-gym/assets/svg/membership/payment_receipt_invoice.svg" alt="Giao dịch" /><span>Giao dịch</span></span></div>
          <div class="card-liquid" style="padding:12px 14px;">
            <div class="row-between">
              <div>
                <div class="txt-sm txt-bold">Gói Hội viên 1 Tháng</div>
                <div class="txt-xs tnum">20/09/2026 → 20/10/2026</div>
              </div>
              <span class="pill pill-muted">Đã hết hạn</span>
            </div>
          </div>
        </div>
      </div>
    `
  }
]);
