// Meta Gym Flutter Mockups — COACH / 3. Trợ lý AI, 4. Tin nhắn & 5. Hồ sơ Coach
window.METAGYM_SCREENS = window.METAGYM_SCREENS || {};
window.METAGYM_SCREENS.coach = (window.METAGYM_SCREENS.coach || []).concat([
  {
    id: 'coach-ai',
    group: 'coach-tab4-ai',
    groupLabel: '4. Trợ lý AI',
    title: '4.1 Trợ lý AI Coach',
    shortFile: 'ai_messages_page.dart (Coach)',
    flutterFile: 'mobile-app/lib/features/ai/presentation/ai_messages_page.dart',
    tag: 'P1 • AI Huấn luyện',
    tagClass: '',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body" style="padding-bottom:206px;">
          <div class="mg-header">
            <div class="mg-logo"><img src="../../meta-gym/assets/svg/brand/app_icon_mark.svg" alt="Meta Gym" /></div>
            <div class="mg-header-text">
              <div class="mg-eyebrow">META GYM · COACH</div>
              <div class="mg-title" style="font-size:16px;">Tối ưu giáo án bảo vệ vai</div>
            </div>
            <div class="circle-btn" data-coach-toast="Bắt đầu cuộc hội thoại AI mới"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_add.svg" alt="Mới" /></div>
          </div>

          <!-- Meta Kong AI Coach Companion Card -->
          <div class="card-liquid" style="padding:10px 12px;margin-bottom:14px;">
            <div class="row" style="gap:10px;align-items:center;">
              <img src="../../meta-gym/assets/images/mascot/meta_kong_hero.webp?v=20261124m4" alt="Meta Kong AI" style="width:52px;height:52px;flex-shrink:0;display:block;object-fit:contain;" />
              <div style="flex:1;min-width:0;">
                <div class="txt-xs txt-orange txt-bold" style="margin-bottom:2px;">Meta Kong · Trợ lý Huấn luyện AI</div>
                <div class="txt-xs" style="color:var(--text-warm-muted);line-height:1.35;">Hỗ trợ gợi ý bài tập thay thế an toàn chấn thương và gợi ý định lượng món ăn theo kcal cho học viên.</div>
              </div>
            </div>
          </div>

          <!-- Hội thoại Coach <-> AI -->
          <div>
            <div class="chat-row-user">
              <div class="chat-bubble-user">
                Học viên 72kg đau nhẹ khớp vai phải khi đẩy Barbell Bench Press trên 80kg. Gợi ý giúp anh bài thay thế cùng nhóm cơ ngực trên nhé!
              </div>
              <span class="chat-time">17:58</span>
            </div>

            <div class="chat-row-ai">
              <div class="chat-ai-avatar"><img src="../../meta-gym/assets/svg/navigation/nav_ai_emblem.svg" alt="AI" /></div>
              <div style="flex:1;min-width:0;">
                <div class="chat-bubble-ai">
                  <div class="txt-xs txt-orange txt-bold" style="margin-bottom:4px;">Trợ lý AI Coach</div>
                  Với học viên đau vai phải mức nhẹ, anh nên giảm biên độ mở vai &amp; chuyển sang góc trung tính:
                  <div class="txt-xs" style="margin-top:6px;line-height:1.45;">
                    • <strong>Neutral-Grip Incline DB Press</strong> (30°): 4×8–10, khuỷu tay khép 45°.<br />
                    • <strong>Machine Chest Press</strong>: ổn định khớp vai, tăng tải an toàn.<br />
                    • Khởi động <strong>5 phút</strong>: Band Pull-Apart 2×15 + External Rotation 2×12.
                  </div>
                </div>
                <div class="chat-time">17:59</div>
              </div>
            </div>

            <div class="chat-row-user">
              <div class="chat-bubble-user">
                Gợi ý thực đơn khoảng 2.200 kcal/ngày cho học viên tập 4 buổi/tuần.
              </div>
              <span class="chat-time">18:01</span>
            </div>

            <div class="chat-row-ai">
              <div class="chat-ai-avatar"><img src="../../meta-gym/assets/svg/navigation/nav_ai_emblem.svg" alt="AI" /></div>
              <div style="flex:1;min-width:0;">
                <div class="chat-bubble-ai">
                  Đề xuất định lượng ngày <strong class="tnum">~2.200 kcal</strong>: <strong>Bữa sáng</strong> Yến mạch 70g + Trứng gà 180g (540 kcal) · <strong>Bữa trưa</strong> Ức gà 200g + Cơm gạo lứt 250g (795 kcal) · <strong>Bữa tối</strong> Cá hồi 180g + Khoai lang 200g (850 kcal).
                </div>
                <div class="chat-time">18:01</div>
              </div>
            </div>
          </div>
        </div>

        <div class="ai-composer-dock" style="position:absolute;left:0;right:0;bottom:96px;z-index:9;padding:8px 14px 10px;background:linear-gradient(180deg,rgba(15,17,21,0) 0%,rgba(15,17,21,0.92) 24%,rgba(15,17,21,0.98) 100%);">
          <div class="filter-row" style="margin-bottom:7px;padding-bottom:0;">
            <span class="filter-pill" style="font-size:11px;padding:5px 11px;" data-coach-toast="Đã chèn gợi ý: Bài thay thế vai yếu">Bài thay thế vai yếu</span>
            <span class="filter-pill" style="font-size:11px;padding:5px 11px;" data-coach-toast="Đã chèn gợi ý: Lịch Deload tuần 5">Lịch Deload tuần 5</span>
            <span class="filter-pill" style="font-size:11px;padding:5px 11px;" data-coach-toast="Đã chèn gợi ý: Thực đơn 2.200 kcal">Gợi ý thực đơn 2.200 kcal</span>
          </div>
          <div class="row" style="gap:8px;">
            <div class="input-box" style="flex:1;height:44px;color:var(--text-secondary);font-size:14px;">Hỏi AI về giáo trình, kỹ thuật...</div>
            <button type="button" style="width:44px;height:44px;border:none;border-radius:14px;background:var(--primary);color:#FFFFFF;display:flex;align-items:center;justify-content:center;font-weight:800;flex-shrink:0;cursor:pointer;" data-coach-toast="Đã gửi câu hỏi tới Trợ lý AI Meta Kong">↑</button>
          </div>
        </div>

        <div class="bottom-nav-wrap">
          <nav class="bottom-nav">
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_home_outline.svg" alt="Trang chủ" /></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_coach_schedule_outline.svg" alt="Lịch dạy" /></div>
            <div class="nav-ai-wrap active"><div class="nav-ai-btn"><img class="nav-ai-svg" src="../../meta-gym/assets/svg/navigation/nav_ai_on_primary.svg" alt="AI" /></div></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_messages_outline.svg" alt="Tin nhắn" /></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_profile_outline.svg" alt="Hồ sơ" /></div>
          </nav>
        </div>
      </div>
    `
  },
  {
    id: 'coach-conversations',
    group: 'coach-tab5-messages',
    groupLabel: '5. Tin nhắn & Cuộc gọi',
    title: '5.1 Tin nhắn học viên',
    shortFile: 'conversations_page.dart (Coach)',
    flutterFile: 'mobile-app/lib/features/messaging/presentation/conversations_page.dart',
    tag: 'P1 • Chat học viên',
    tagClass: '',
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
              <div class="mg-eyebrow">META GYM · COACH</div>
              <div class="mg-title">Tin nhắn</div>
              <div class="txt-xs" style="color:var(--text-warm-muted);">Trao đổi cùng học viên &amp; hỗ trợ</div>
            </div>
            <div class="circle-btn" data-go="coach-calls" title="Cuộc gọi 1:1"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/call_audio_badge.svg" alt="Cuộc gọi" /></div>
            <div class="circle-btn" data-coach-toast="Tìm kiếm hội thoại học viên"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_search.svg" alt="Tìm kiếm" /></div>
          </div>

          <div class="filter-row">
            <div class="filter-pill active" data-filter-cat="all">Tất cả</div>
            <div class="filter-pill" data-filter-cat="student">Học viên (3)</div>
            <div class="filter-pill" data-filter-cat="unread">Chưa đọc (2)</div>
            <div class="filter-pill" data-filter-cat="support">Quản trị</div>
          </div>

          <!-- Học viên có ca dạy sắp tới -->
          <div class="card-liquid featured" data-filter-item="student unread" data-go="coach-chat-detail" style="padding:12px;cursor:pointer;">
            <div class="row" style="gap:6px;margin-bottom:7px;">
              <img class="ico-xs" src="../../meta-gym/assets/svg/quick_actions/action_coach_sessions.svg" alt="Ca sắp tới" />
              <strong style="font-size:12px;letter-spacing:0.04em;">CA DẠY 18:00 HÔM NAY</strong>
              <span class="pill pill-success" style="font-size:11px;padding:1px 7px;">● Trực tuyến</span>
            </div>
            <div class="row">
              <div class="avatar-member" style="width:40px;height:40px;font-size:14px;">MQ</div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong class="txt-sm">Nguyễn Minh Quân</strong>
                  <span class="txt-xs tnum txt-orange">17:55</span>
                </div>
                <div class="row-between" style="margin-top:2px;">
                  <span class="txt-xs" style="color:var(--text-primary);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Dạ ok anh, em vừa check-in QR xong xuống liền ạ!</span>
                  <span class="pill pill-orange tnum" style="padding:1px 7px;">2</span>
                </div>
              </div>
            </div>
          </div>

          <div class="card-liquid" data-filter-item="student unread" data-go="coach-chat-detail" style="padding:12px;cursor:pointer;">
            <div class="row">
              <div class="avatar-member" style="width:40px;height:40px;font-size:14px;background:linear-gradient(135deg,#2ECC71,#1D63B8);">TV</div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong class="txt-sm">Trần Thảo Vy</strong>
                  <span class="txt-xs tnum">16:20</span>
                </div>
                <div class="row-between" style="margin-top:2px;">
                  <span class="txt-xs" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Em gửi ảnh bữa trưa ức gà + gạo lứt anh xem giúp nhé!</span>
                  <span class="pill pill-orange tnum" style="padding:1px 7px;">1</span>
                </div>
              </div>
            </div>
          </div>

          <div class="card-liquid" data-filter-item="student" data-go="coach-chat-detail" style="padding:12px;cursor:pointer;">
            <div class="row">
              <div class="avatar-member" style="width:40px;height:40px;font-size:14px;background:linear-gradient(135deg,#F39C12,#D9431E);">PB</div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong class="txt-sm">Phạm Quốc Bảo</strong>
                  <span class="txt-xs tnum">Hôm qua</span>
                </div>
                <div class="txt-xs" style="margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Thứ 6 tuần này em muốn dời sang khung 19h30 được không anh?</div>
              </div>
            </div>
          </div>

          <div class="card-liquid" data-filter-item="support" data-go="coach-chat-detail" style="padding:12px;cursor:pointer;">
            <div class="row">
              <div class="avatar-member" style="width:40px;height:40px;font-size:12px;background:#262A34;">QT</div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong class="txt-sm">Quản trị Meta Gym</strong>
                  <span class="txt-xs tnum">20/11</span>
                </div>
                <div class="txt-xs" style="margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Đã xác nhận lịch họp chuyên môn Coach sáng thứ 5.</div>
              </div>
            </div>
          </div>
        </div>

        <div class="bottom-nav-wrap">
          <nav class="bottom-nav">
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_home_outline.svg" alt="Trang chủ" /></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_coach_schedule_outline.svg" alt="Lịch dạy" /></div>
            <div class="nav-ai-wrap"><div class="nav-ai-btn"><img class="nav-ai-svg" src="../../meta-gym/assets/svg/navigation/nav_ai_on_primary.svg" alt="AI" /></div></div>
            <div class="nav-item active"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_messages_filled.svg" alt="Tin nhắn" /></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_profile_outline.svg" alt="Hồ sơ" /></div>
          </nav>
        </div>
      </div>
    `
  },
  {
    id: 'coach-chat-detail',
    group: 'coach-tab5-messages',
    groupLabel: '5. Tin nhắn & Cuộc gọi',
    title: '5.2 Chi tiết tin nhắn (Coach ↔ HV)',
    shortFile: 'chat_detail_page.dart (Coach)',
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
            <div class="avatar-member" data-go="coach-member-detail" style="width:36px;height:36px;font-size:12px;cursor:pointer;">MQ</div>
            <div class="mg-header-text" data-go="coach-member-detail" style="cursor:pointer;">
              <div class="mg-title" style="font-size:16px;">Nguyễn Minh Quân</div>
              <div class="txt-xs txt-green tnum">● Trực tuyến · Còn 14/24 buổi</div>
            </div>
            <div class="circle-btn" data-open-coach-modal="voice-call" title="Gọi thoại 1:1"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/call_audio_badge.svg" alt="Gọi thoại" /></div>
          </div>

          <div style="text-align:center;margin:4px 0 12px;">
            <span class="pill pill-muted tnum" style="font-size:11px;">Hôm nay · 26/11/2026</span>
          </div>

          <!-- Coach (Phải — màu cam) -->
          <div class="chat-row-user">
            <div class="chat-bubble-user">
              Chào Quân, tối nay <strong>18:00</strong> anh đợi ở khu Free Weight nhé! Nhớ khởi động khớp vai 5 phút trước khi đẩy Incline DB Press.
            </div>
            <span class="chat-time">17:45 · Đã xem</span>
          </div>

          <!-- Học viên (Trái) -->
          <div class="chat-row-ai">
            <div class="avatar-member" style="width:28px;height:28px;font-size:11px;flex-shrink:0;">MQ</div>
            <div style="flex:1;min-width:0;">
              <div class="chat-bubble-ai">
                Dạ ok anh, em vừa check-in QR ở cổng xong đang thay đồ xuống liền ạ! Vai phải hôm nay ổn hơn nhiều rồi anh.
              </div>
              <div class="chat-time">17:55</div>
            </div>
          </div>

          <!-- Coach (Phải) -->
          <div class="chat-row-user">
            <div class="chat-bubble-user">
              Tốt lắm! Anh vừa cập nhật giáo trình Push Giai đoạn 2 và thực đơn 7 ngày Tuần 4 cho em rồi nhé.
            </div>
            <span class="chat-time">17:56 · Đã xem</span>
          </div>

          <!-- Thẻ giáo án đính kèm -->
          <div class="card-liquid" data-go="coach-plan-detail" style="padding:11px 13px;border-color:rgba(255,94,54,0.42);cursor:pointer;margin-top:4px;">
            <div class="row-between">
              <div>
                <div class="txt-xs txt-orange txt-bold">GIÁO TRÌNH ĐANG ÁP DỤNG</div>
                <div class="txt-sm txt-bold" style="margin-top:2px;">Upper / Lower Split · Ngày 1 Push</div>
                <div class="txt-xs tnum">4 bài tập · Upper Body · 60 phút</div>
              </div>
              <span class="btn-mini-orange" style="height:32px;padding:0 10px;border-radius:10px;">Mở ›</span>
            </div>
          </div>
        </div>

        <div class="bottom-cta-dock" style="padding:10px 14px var(--safe-bottom);">
          <div class="row" style="gap:8px;">
            <div class="circle-btn" style="width:40px;height:40px;" data-coach-toast="Đính kèm ảnh kỹ thuật tập luyện"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/media_gallery.svg" alt="Gửi ảnh" /></div>
            <div class="input-box" style="flex:1;height:42px;color:var(--text-secondary);font-size:14px;">Nhập tin nhắn cho học viên...</div>
            <button type="button" style="width:42px;height:42px;border:none;border-radius:13px;background:var(--primary);color:#FFFFFF;display:flex;align-items:center;justify-content:center;font-weight:800;flex-shrink:0;cursor:pointer;" data-coach-toast="Đã gửi tin nhắn tới Nguyễn Minh Quân">↑</button>
          </div>
        </div>

        <!-- Level 3 Modal: Cuộc gọi thoại đang diễn ra (POST /calls -> PATCH /calls/:id) -->
        <div class="qr-overlay" data-coach-modal="voice-call">
          <div class="qr-sheet" style="text-align:center;">
            <div class="pill pill-success tnum" style="margin-bottom:12px;">● Đang kết nối thoại 1:1 · 00:18</div>
            <div class="avatar-member" style="width:72px;height:72px;font-size:22px;margin:0 auto 10px;">MQ</div>
            <div style="font-size:18px;font-weight:800;">Nguyễn Minh Quân</div>
            <div class="txt-xs" style="color:var(--text-warm-muted);margin:4px 0 16px;">Cuộc gọi nội bộ Meta Gym · Bảo mật đầu cuối</div>
            <div class="grid-3" style="gap:10px;margin-bottom:14px;">
              <button type="button" class="btn-secondary" style="height:46px;" data-coach-toast="Đã tắt micro"><img class="ico-sm" src="../../meta-gym/assets/svg/community/comm_mute.svg" alt="Tắt mic" /></button>
              <button type="button" class="btn-secondary" style="height:46px;" data-coach-toast="Đã bật loa ngoài"><img class="ico-sm" src="../../meta-gym/assets/svg/community/comm_speaker.svg" alt="Loa ngoài" /></button>
              <button type="button" class="btn-primary" style="height:46px;background:#E5484D;border-color:#F15B64;" data-close-coach-modal data-coach-toast="Đã kết thúc cuộc gọi · Lưu vào lịch sử">Kết thúc</button>
            </div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'coach-calls',
    group: 'coach-tab5-messages',
    groupLabel: '5. Tin nhắn & Cuộc gọi',
    title: '5.3 Cuộc gọi 1:1 (CallsPage)',
    shortFile: 'calls_page.dart (Coach)',
    flutterFile: 'mobile-app/lib/features/calls/presentation/calls_page.dart',
    tag: 'P1 • /calls backend',
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
              <div class="mg-eyebrow">META GYM · CALLS</div>
              <div class="mg-title">Cuộc gọi 1:1</div>
            </div>
          </div>

          <div class="card-warm-glass">
            <div class="row-between" style="margin-bottom:10px;">
              <div class="row" style="gap:8px;">
                <img class="ico-sm" src="../../meta-gym/assets/svg/setting/call_audio_badge.svg" alt="Cuộc gọi" />
                <strong class="txt-sm">Tổng quan liên lạc</strong>
              </div>
              <span class="pill pill-success">Kênh 1:1 ACTIVE</span>
            </div>
            <div class="grid-2">
              <div class="metric-box">
                <div class="txt-xs">Cuộc gọi tuần này</div>
                <div class="tnum txt-bold" style="font-size:20px;margin-top:2px;">4</div>
              </div>
              <div class="metric-box">
                <div class="txt-xs">Cuộc gọi nhỡ</div>
                <div class="tnum txt-bold txt-warn" style="font-size:20px;margin-top:2px;">1</div>
              </div>
            </div>
          </div>

          <div class="filter-row">
            <div class="filter-pill active" data-filter-cat="all">Tất cả (3)</div>
            <div class="filter-pill" data-filter-cat="voice">Thoại</div>
            <div class="filter-pill" data-filter-cat="video">Video</div>
            <div class="filter-pill" data-filter-cat="missed">Gọi nhỡ</div>
          </div>

          <div class="sec-head" style="margin-top:6px;">
            <h3>Lịch sử cuộc gọi</h3>
            <span class="txt-xs">GET /calls</span>
          </div>

          <div class="card-liquid" data-filter-item="voice" style="padding:13px;">
            <div class="row-between">
              <div class="row" style="gap:10px;min-width:0;">
                <div class="avatar-member" style="width:40px;height:40px;font-size:13px;">MQ</div>
                <div style="min-width:0;">
                  <div class="txt-sm txt-bold">Nguyễn Minh Quân</div>
                  <div class="txt-xs tnum">Cuộc gọi thoại · 06 phút 42 giây · Hôm nay</div>
                </div>
              </div>
              <button type="button" class="circle-btn" style="width:36px;height:36px;" data-open-coach-modal="quick-call" title="Gọi lại">
                <img class="ico-sm" src="../../meta-gym/assets/svg/setting/call_audio_badge.svg" alt="Gọi lại" />
              </button>
            </div>
          </div>

          <div class="card-liquid" data-filter-item="video" style="padding:13px;">
            <div class="row-between">
              <div class="row" style="gap:10px;min-width:0;">
                <div class="avatar-member" style="width:40px;height:40px;font-size:13px;background:linear-gradient(135deg,#2ECC71,#1D63B8);">TV</div>
                <div style="min-width:0;">
                  <div class="txt-sm txt-bold">Trần Thảo Vy</div>
                  <div class="txt-xs tnum">Video Check-in form · 09 phút 15 giây · Hôm qua</div>
                </div>
              </div>
              <button type="button" class="circle-btn" style="width:36px;height:36px;" data-open-coach-modal="quick-call" title="Gọi lại">
                <img class="ico-sm" src="../../meta-gym/assets/svg/community/comm_mic.svg" alt="Gọi lại" />
              </button>
            </div>
          </div>

          <div class="card-liquid" data-filter-item="missed voice" style="padding:13px;border-color:rgba(243,156,18,0.45);">
            <div class="row-between">
              <div class="row" style="gap:10px;min-width:0;">
                <div class="avatar-member" style="width:40px;height:40px;font-size:13px;background:linear-gradient(135deg,#F39C12,#D9431E);">PB</div>
                <div style="min-width:0;">
                  <div class="row" style="gap:6px;"><strong class="txt-sm">Phạm Quốc Bảo</strong><span class="pill pill-warning">Gọi nhỡ</span></div>
                  <div class="txt-xs tnum" style="margin-top:2px;">Hội viên gọi · T4, 25/11 · 20:10</div>
                </div>
              </div>
              <button type="button" class="circle-btn" style="width:36px;height:36px;" data-open-coach-modal="quick-call" title="Gọi lại">
                <img class="ico-sm" src="../../meta-gym/assets/svg/setting/call_audio_badge.svg" alt="Gọi lại" />
              </button>
            </div>
          </div>
        </div>

        <!-- Level 3 Modal: Bắt đầu cuộc gọi -->
        <div class="qr-overlay" data-coach-modal="quick-call">
          <div class="qr-sheet" style="text-align:center;">
            <div class="pill pill-orange tnum" style="margin-bottom:12px;">Đang đổ chuông...</div>
            <div class="avatar-member" style="width:68px;height:68px;font-size:20px;margin:0 auto 10px;">MQ</div>
            <div style="font-size:17px;font-weight:800;">Gọi tới học viên</div>
            <div class="txt-xs" style="color:var(--text-warm-muted);margin:4px 0 14px;">Đang tạo phòng gọi LiveKit qua POST /calls</div>
            <div class="grid-2" style="gap:10px;">
              <button type="button" class="btn-secondary" style="height:44px;" data-go="coach-chat-detail">Mở tin nhắn</button>
              <button type="button" class="btn-primary" style="height:44px;background:#E5484D;border-color:#F15B64;" data-close-coach-modal data-coach-toast="Đã dừng cuộc gọi">Kết thúc</button>
            </div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'coach-profile',
    group: 'coach-tab6-profile',
    groupLabel: '6. Hồ sơ Coach',
    title: '6.1 Hồ sơ Huấn luyện viên',
    shortFile: 'profile_page.dart (Coach)',
    flutterFile: 'mobile-app/lib/features/profile/presentation/profile_page.dart',
    tag: 'P0 • Hồ sơ Coach',
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
              <div class="mg-eyebrow">META GYM · COACH</div>
              <div class="mg-title">Hồ sơ cá nhân</div>
              <div class="txt-xs" style="color:var(--text-warm-muted);">Tài khoản &amp; thiết lập huấn luyện viên</div>
            </div>
          </div>

          <!-- Hero Coach Profile Card (Avatar LN vàng gold #F5B041 chuẩn DESIGN.md) -->
          <div class="card-warm-glass" data-go="coach-pro-profile" style="cursor:pointer;">
            <div class="row" style="gap:12px;">
              <div style="position:relative;cursor:pointer;" data-open-avatar title="Đổi ảnh đại diện">
                <div class="avatar-ln" style="width:60px;height:60px;font-size:20px;">LN</div>
                <div style="position:absolute;right:-2px;bottom:-2px;width:22px;height:22px;border-radius:50%;background:#2B2622;border:1px solid #B3A99D;display:flex;align-items:center;justify-content:center;"><img class="ico-xs" src="../../meta-gym/assets/svg/setting/common_camera.svg" alt="Đổi ảnh" /></div>
              </div>
              <div style="flex:1;min-width:0;">
                <div style="font-size:20px;font-weight:700;line-height:1.2;">Lê Hoàng Nam</div>
                <div class="row" style="gap:8px;margin-top:3px;flex-wrap:wrap;">
                  <span class="txt-xs" style="color:var(--text-warm-muted);">Huấn luyện viên</span>
                  <span class="txt-xs txt-green txt-bold">● Đang nhận lịch</span>
                </div>
                <div class="txt-xs" style="color:var(--text-secondary);margin-top:7px;"><img class="ico-xs" src="../../meta-gym/assets/svg/community/comm_email.svg" alt="Email" /> <span style="vertical-align:middle;">coach.nam@metagym.vn</span></div>
                <div class="txt-xs tnum" style="color:var(--text-secondary);margin-top:2px;"><img class="ico-xs" src="../../meta-gym/assets/svg/setting/call_audio_badge.svg" alt="SĐT" /> <span style="vertical-align:middle;">0912 345 678</span></div>
              </div>
              <span class="txt-xs">›</span>
            </div>
          </div>

          <!-- 3 Accordion Cards đồng bộ Member 5.1 (100% khớp backend Coach) -->
          <div class="card-liquid accordion-card is-open" style="padding:13px 14px;">
            <div class="accordion-head" data-accordion-toggle>
              <div class="row"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/setting_personal_info.svg" alt="Cá nhân" /><strong class="txt-sm">Cá nhân &amp; chuyên môn</strong></div>
              <div class="row" style="gap:6px;"><span class="count-pill">1</span><span class="accordion-chev">›</span></div>
            </div>
            <div class="accordion-body">
              <div class="divider"></div>
              <div class="accordion-row" data-go="coach-pro-profile"><span>Chuyên môn, Bằng cấp &amp; Liên hệ</span><span class="txt-xs">›</span></div>
            </div>
          </div>

          <div class="card-liquid accordion-card is-open" style="padding:13px 14px;">
            <div class="accordion-head" data-accordion-toggle>
              <div class="row"><img class="ico-sm" src="../../meta-gym/assets/svg/coaching/coach_achievement.svg" alt="Giảng dạy" /><strong class="txt-sm">Công việc &amp; giảng dạy</strong></div>
              <div class="row" style="gap:6px;"><span class="count-pill">7</span><span class="accordion-chev">›</span></div>
            </div>
            <div class="accordion-body">
              <div class="divider"></div>
              <div class="accordion-row" data-go="coach-members"><span>Hội viên đang phụ trách (6/8)</span><span class="txt-xs">›</span></div>
              <div class="accordion-row" data-go="coach-sessions"><span>Lịch dạy &amp; buổi hẹn</span><span class="txt-xs">›</span></div>
              <div class="accordion-row" data-go="coach-training"><span>Giáo án tập luyện</span><span class="txt-xs">›</span></div>
              <div class="accordion-row" data-go="coach-meal-plan"><span>Thực đơn 7 ngày</span><span class="txt-xs">›</span></div>
              <div class="accordion-row" data-go="coach-booking-history"><span>Lịch sử buổi dạy</span><span class="txt-xs">›</span></div>
              <div class="accordion-row" data-go="coach-calls"><span>Cuộc gọi 1:1 học viên</span><span class="txt-xs">›</span></div>
              <div class="accordion-row" data-go="member-gym-equipment"><span>Phòng gym &amp; Thiết bị</span><span class="txt-xs">›</span></div>
            </div>
          </div>

          <div class="card-liquid accordion-card is-open" style="padding:13px 14px;">
            <div class="accordion-head" data-accordion-toggle>
              <div class="row"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/setting_security_shield.svg" alt="Tài khoản" /><strong class="txt-sm">Tài khoản &amp; bảo mật</strong></div>
              <div class="row" style="gap:6px;"><span class="count-pill">2</span><span class="accordion-chev">›</span></div>
            </div>
            <div class="accordion-body">
              <div class="divider"></div>
              <div class="accordion-row" data-go="coach-notifications"><span>Thông báo Coach</span><span class="txt-xs">›</span></div>
              <div class="accordion-row" data-open-coach-modal="coach-password"><span>Đổi mật khẩu tài khoản</span><span class="txt-xs">›</span></div>
            </div>
          </div>

          <div class="card-liquid" data-open-logout style="padding:13px;text-align:center;color:var(--error);font-weight:600;font-size:14px;cursor:pointer;">
            <span class="row" style="justify-content:center;gap:6px;"><img class="ico-sm" src="../../meta-gym/assets/svg/setting/setting_logout.svg" alt="Đăng xuất" /><span>Đăng xuất</span></span>
          </div>
        </div>

        <div class="bottom-nav-wrap">
          <nav class="bottom-nav">
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_home_outline.svg" alt="Trang chủ" /></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_coach_schedule_outline.svg" alt="Lịch dạy" /></div>
            <div class="nav-ai-wrap"><div class="nav-ai-btn"><img class="nav-ai-svg" src="../../meta-gym/assets/svg/navigation/nav_ai_on_primary.svg" alt="AI" /></div></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_messages_outline.svg" alt="Tin nhắn" /></div>
            <div class="nav-item active"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_profile_filled.svg" alt="Hồ sơ" /></div>
          </nav>
        </div>

        <!-- Level 3 Modal: Đổi mật khẩu Coach (PATCH /users/me/password) -->
        <div class="qr-overlay" data-coach-modal="coach-password">
          <div class="qr-sheet" style="text-align:left;">
            <div class="row-between" style="margin-bottom:10px;">
              <div style="font-size:16px;font-weight:800;">Đổi mật khẩu tài khoản</div>
              <button type="button" class="circle-btn" style="width:32px;height:32px;font-size:14px;" data-close-coach-modal>✕</button>
            </div>
            <div class="field">
              <label>Mật khẩu hiện tại</label>
              <div class="input-box">••••••••••••</div>
            </div>
            <div class="field">
              <label>Mật khẩu mới (8–72 ký tự, chữ hoa, thường, số)</label>
              <div class="input-box">••••••••••••</div>
            </div>
            <div class="grid-2" style="gap:10px;margin-top:4px;">
              <button type="button" class="btn-secondary" style="height:44px;" data-close-coach-modal>Hủy</button>
              <button type="button" class="btn-primary" style="height:44px;" data-close-coach-modal data-coach-toast="Đã cập nhật mật khẩu tài khoản Coach">Lưu mật khẩu</button>
            </div>
          </div>
        </div>

        <!-- Level 3 Modal xác nhận đăng xuất Coach -->
        <div class="qr-overlay" data-logout-modal>
          <div class="qr-sheet" style="text-align:center;">
            <div style="width:56px;height:56px;border-radius:50%;margin:0 auto 12px;background:rgba(241,91,100,0.16);border:1px solid rgba(241,91,100,0.45);display:flex;align-items:center;justify-content:center;">
              <img class="ico-md" src="../../meta-gym/assets/svg/setting/setting_logout.svg" alt="Đăng xuất" />
            </div>
            <div style="font-size:16px;font-weight:800;color:var(--text-primary);">Đăng xuất tài khoản Coach?</div>
            <div style="font-size:14px;color:var(--text-secondary);margin:6px 0 12px;line-height:1.5;">
              Bạn sẽ cần đăng nhập lại để điểm danh ca dạy, cập nhật giáo án và nhận thông báo từ học viên.
            </div>
            <div style="background:var(--surface-raised);border:1px solid var(--border-solid);border-radius:12px;padding:9px 12px;margin-bottom:14px;text-align:left;">
              <div style="font-size:14px;font-weight:700;color:var(--text-primary);">Lê Hoàng Nam</div>
              <div style="font-size:11px;color:var(--text-secondary);margin-top:2px;">coach.nam@metagym.vn · Huấn luyện viên 1:1</div>
            </div>
            <div class="grid-2" style="gap:10px;">
              <button type="button" class="btn-secondary" style="height:44px;" data-close-logout>Huỷ</button>
              <button type="button" class="btn-primary" style="height:44px;background:#E5484D;border-color:#F15B64;color:#FFFFFF;" data-confirm-logout>Đăng xuất</button>
            </div>
          </div>
        </div>
      </div>
    `
  },
  {
    id: 'coach-pro-profile',
    group: 'coach-tab6-profile',
    groupLabel: '6. Hồ sơ Coach',
    title: '6.2 Chuyên môn &amp; Bằng cấp Coach',
    shortFile: 'profile_secondary_pages.dart (Coach)',
    flutterFile: 'mobile-app/lib/features/profile/presentation/widgets/profile_secondary_pages.dart',
    tag: 'P1 • Hồ sơ chuyên môn',
    tagClass: '',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body">
          <div class="mg-header">
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_back.svg" alt="Quay lại" /></div>
            <div class="mg-header-text">
              <div class="mg-eyebrow">HỒ SƠ HUẤN LUYỆN VIÊN</div>
              <div class="mg-title">Chuyên môn &amp; Lịch dạy</div>
            </div>
          </div>

          <!-- Hero Chứng chỉ & Uy tín -->
          <div class="card-warm-glass">
            <div class="row" style="gap:12px;">
              <div class="quick-ico" style="width:46px;height:46px;border-radius:14px;">
                <img class="ico-md" src="../../meta-gym/assets/svg/coaching/coach_achievement.svg" alt="Chứng chỉ" />
              </div>
              <div style="flex:1;min-width:0;">
                <div class="row-between">
                  <strong class="txt-sm">Hồ sơ công khai với Hội viên</strong>
                  <span class="pill pill-success">Đã xác thực</span>
                </div>
                <div class="txt-xs tnum" style="color:var(--text-warm-muted);margin-top:3px;">NASM-CPT · Precision Nutrition L1 · 6 năm KN</div>
              </div>
            </div>
          </div>

          <!-- Biểu mẫu CoachProfileDetailPage + PATCH /users/me -->
          <div class="card-liquid" style="padding:14px;">
            <div class="grid-2" style="gap:8px;">
              <div class="field">
                <label>Họ và tên</label>
                <div class="input-box" style="height:42px;">Lê Hoàng Nam</div>
              </div>
              <div class="field">
                <label>Số điện thoại</label>
                <div class="input-box tnum" style="height:42px;">0912 345 678</div>
              </div>
            </div>
            <div class="field">
              <label>Giới thiệu bản thân (Bio)</label>
              <div class="input-box" style="height:82px;align-items:flex-start;padding-top:10px;font-size:14px;line-height:1.45;">
                Chuyên gia Hypertrophy và tái cấu trúc hình thể với hơn 6 năm đồng hành cùng hơn 180 hội viên tại Meta Gym.
              </div>
            </div>

            <div class="field">
              <label>Chuyên môn nổi bật</label>
              <div style="display:flex;flex-wrap:wrap;gap:6px;margin-bottom:8px;">
                <span class="filter-pill active" style="font-size:12px;padding:5px 11px;">Hypertrophy</span>
                <span class="filter-pill active" style="font-size:12px;padding:5px 11px;">Sức mạnh</span>
                <span class="filter-pill active" style="font-size:12px;padding:5px 11px;">Giảm mỡ bền vững</span>
                <span class="filter-pill" style="font-size:12px;padding:5px 11px;">Phục hồi vận động</span>
              </div>
            </div>

            <div class="field">
              <label>Chứng chỉ / Bằng cấp</label>
              <div class="input-box" style="height:44px;">NASM-CPT · Precision Nutrition Level 1</div>
            </div>

            <div class="field">
              <div class="row-between" style="margin-bottom:6px;">
                <label style="margin:0;">Số năm kinh nghiệm</label>
                <span class="pill pill-orange tnum">6 năm</span>
              </div>
              <div class="prog-track" style="height:6px;margin-top:4px;"><div class="prog-fill orange" style="width:60%;"></div></div>
            </div>

            <div class="field" style="margin-bottom:0;">
              <label>Khung giờ dạy &amp; Lưu ý lịch</label>
              <div class="input-box" style="height:58px;align-items:flex-start;padding-top:10px;font-size:14px;">Thứ 2 – Thứ 7 (06:00–21:00) · Khung 90 phút, nhận tối đa 8 học viên.</div>
            </div>
          </div>
        </div>

        <div class="bottom-cta-dock">
          <button type="button" class="btn-primary" data-coach-toast="Đã lưu hồ sơ Huấn luyện viên">Lưu hồ sơ Huấn luyện viên</button>
        </div>
      </div>
    `
  }
]);
