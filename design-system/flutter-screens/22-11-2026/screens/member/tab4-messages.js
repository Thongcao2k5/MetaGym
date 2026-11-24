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
          </div>

          <!-- _buildQuickFilterDock: 4 nút lọc -->
          <div class="filter-row">
            <div class="filter-pill active">Tất cả</div>
            <div class="filter-pill">Coach</div>
            <div class="filter-pill">Chưa đọc</div>
            <div class="filter-pill">Hỗ trợ</div>
          </div>

          <!-- _buildFeaturedCoachCard -->
          <div class="card-liquid featured" data-go="member-chat-detail" style="padding:11px 12px;cursor:pointer;">
            <div class="row" style="gap:6px;margin-bottom:7px;">
              <img class="ico-xs" src="../../meta-gym/assets/svg/community/comm_chat.svg" alt="Coach cá nhân" />
              <strong style="font-size:10.5px;letter-spacing:0.05em;">COACH CÁ NHÂN</strong>
              <span class="pill" style="background:rgba(35,201,151,0.16);color:var(--success);font-size:9px;padding:1px 6px;">● Đang hoạt động</span>
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

          <div class="card-liquid" data-go="member-chat-detail" style="padding:12px;cursor:pointer;">
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
    id: 'member-chat-detail',
    group: 'tab4-messages',
    groupLabel: '4. Tin nhắn',
    title: '4.2 Chi tiết tin nhắn',
    shortFile: 'chat_detail_page.dart',
    flutterFile: 'mobile-app/lib/features/messaging/presentation/chat_detail_page.dart',
    tag: 'P1 • Chat 1:1',
    tagClass: '',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body no-nav" style="padding-bottom:92px;">
          <div class="mg-header" style="margin-bottom:10px;">
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_back.svg" alt="Quay lại" /></div>
            <div class="avatar-ln" style="width:36px;height:36px;font-size:12px;">LN</div>
            <div class="mg-header-text">
              <div class="mg-title" style="font-size:15.5px;">Lê Hoàng Nam</div>
              <div class="txt-xs txt-green">● Đang hoạt động · Coach 1:1</div>
            </div>
            <div class="circle-btn"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/call_audio_badge.svg" alt="Gọi thoại" /></div>
          </div>

          <div style="text-align:center;margin:4px 0 12px;">
            <span class="pill pill-muted tnum" style="font-size:10px;">Hôm nay · 22/11/2026</span>
          </div>

          <!-- Coach (Trái) -->
          <div class="chat-row-ai">
            <div class="avatar-ln" style="width:28px;height:28px;font-size:10px;flex-shrink:0;">LN</div>
            <div style="flex:1;min-width:0;">
              <div class="chat-bubble-ai">
                Chào Quân, tối nay <strong>18:00</strong> anh đợi ở khu Free Weight nhé! Nhớ khởi động khớp vai 5 phút trước khi đẩy Bench Press.
              </div>
              <div class="chat-time">17:45</div>
            </div>
          </div>

          <!-- Hội viên (Phải) -->
          <div class="chat-row-user">
            <div class="chat-bubble-user">
              Dạ ok anh, em vừa check-in QR ở cổng xong đang thay đồ xuống liền ạ!
            </div>
            <span class="chat-time">17:55 · Đã xem</span>
          </div>

          <!-- Coach (Trái) -->
          <div class="chat-row-ai">
            <div class="avatar-ln" style="width:28px;height:28px;font-size:10px;flex-shrink:0;">LN</div>
            <div style="flex:1;min-width:0;">
              <div class="chat-bubble-ai">
                Tuyệt vời! Nay anh xếp sẵn cặp tạ <strong>Incline Dumbbell 24kg</strong> và lịch đo InBody cuối tuần này cho em luôn.
              </div>
              <div class="chat-time">17:56</div>
            </div>
          </div>

          <!-- Thẻ buổi tập đính kèm trong chat -->
          <div class="card-solid" data-go="member-curriculum" style="padding:11px 13px;border-color:rgba(255,94,54,0.4);cursor:pointer;margin-top:4px;">
            <div class="row-between">
              <div>
                <div class="txt-xs txt-orange txt-bold">GIÁO TRÌNH HÔM NAY</div>
                <div class="txt-sm txt-bold" style="margin-top:2px;">Ngày 2 · Upper Body &amp; Core</div>
                <div class="txt-xs tnum">5 bài tập · 60 phút</div>
              </div>
              <span class="btn-mini-orange" style="height:32px;padding:0 10px;border-radius:10px;">Xem ›</span>
            </div>
          </div>
        </div>

        <div class="bottom-cta-dock" style="padding:10px 14px 16px;">
          <div class="row" style="gap:8px;">
            <div class="circle-btn" style="width:40px;height:40px;"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/media_gallery.svg" alt="Gửi ảnh" /></div>
            <div class="input-box" style="flex:1;height:42px;color:var(--text-secondary);font-size:13px;">Nhập tin nhắn cho Coach...</div>
            <div style="width:42px;height:42px;border-radius:13px;background:var(--primary);color:#FFF;display:flex;align-items:center;justify-content:center;font-weight:800;flex-shrink:0;">↑</div>
          </div>
        </div>
      </div>
    `
  }
]);
