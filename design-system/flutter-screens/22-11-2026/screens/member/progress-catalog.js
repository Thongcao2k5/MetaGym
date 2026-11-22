// Meta Gym Flutter Mockups — MEMBER / Tiến độ & Thư viện
window.METAGYM_SCREENS = window.METAGYM_SCREENS || {};
window.METAGYM_SCREENS.member = (window.METAGYM_SCREENS.member || []).concat([
  {
    id: 'member-journal',
    group: 'progress',
    groupLabel: 'Tiến độ & Thư viện',
    title: '9. Nhật ký tập luyện',
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
  }
]);
