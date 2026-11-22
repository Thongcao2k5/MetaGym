// Meta Gym Flutter Mockups — MEMBER / 4. Tin nhắn (Từ ngoài vào trong)
window.METAGYM_SCREENS = window.METAGYM_SCREENS || {};
window.METAGYM_SCREENS.member = (window.METAGYM_SCREENS.member || []).concat([
  {
    id: 'member-conversations',
    group: 'tab4-messages',
    groupLabel: '4. Tin nhắn',
    title: '4.1 Tin nhắn',
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
  }
]);
