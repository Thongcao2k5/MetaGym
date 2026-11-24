// Meta Gym Flutter Mockups — MEMBER / 3. Trợ lý AI (Từ ngoài vào trong)
window.METAGYM_SCREENS = window.METAGYM_SCREENS || {};
window.METAGYM_SCREENS.member = (window.METAGYM_SCREENS.member || []).concat([
  {
    id: 'member-ai-messages',
    group: 'tab3-ai',
    groupLabel: '3. Trợ lý AI',
    title: '3.1 Trợ lý AI',
    shortFile: 'ai_messages_page.dart',
    flutterFile: 'mobile-app/lib/features/ai/presentation/ai_messages_page.dart',
    tag: 'P1',
    tagClass: '',
    status: 'Đang review',
    html: `
<div class="phone">
        <div class="phone-bg-photo"></div>
        <div class="phone-scrim"></div>
        <div class="status-bar"><span class="tnum">18:02</span><div class="notch"></div><span class="tnum">5G 92%</span></div>

        <div class="phone-body" style="padding-bottom:206px;">
          <div class="mg-header">
            <div class="circle-btn"><img class="ico-md" src="../../meta-gym/assets/svg/setting/common_back.svg" alt="Quay lại" /></div>
            <div class="mg-header-text">
              <div class="mg-title" style="font-size:16px;">Tư vấn đạm sau buổi tập</div>
            </div>
          </div>

          <!-- Meta Kong AI Companion + Disclaimer Card -->
          <div class="card-liquid" style="padding:10px 12px;margin-bottom:14px;">
            <div class="row" style="gap:10px;align-items:center;">
              <img src="../../meta-gym/assets/images/mascot/meta_kong_hero.webp?v=20261124m4" alt="Meta Kong AI" style="width:52px;height:52px;flex-shrink:0;display:block;object-fit:contain;" />
              <div style="flex:1;min-width:0;">
                <div class="txt-xs txt-orange txt-bold" style="margin-bottom:2px;">Meta Kong · Trợ lý AI Meta Gym</div>
                <div class="txt-xs" style="color:var(--text-warm-muted);line-height:1.35;">Nội dung AI chỉ để tham khảo; không thay thế tư vấn y tế hoặc huấn luyện cá nhân.</div>
              </div>
            </div>
          </div>

          <!-- Tin nhắn xen kẽ: AI bên trái, User bên phải -->
          <div>
            <!-- User (Phải) -->
            <div class="chat-row-user">
              <div class="chat-bubble-user">
                Tối nay mình tập Upper Body xong thì nên ăn thêm bao nhiêu đạm nữa để đủ mục tiêu 160g?
              </div>
              <span class="chat-time">18:00</span>
            </div>

            <!-- AI (Trái) -->
            <div class="chat-row-ai">
              <div class="chat-ai-avatar"><img src="../../meta-gym/assets/svg/navigation/nav_ai_emblem.svg" alt="AI" /></div>
              <div style="flex:1;min-width:0;">
                <div class="chat-bubble-ai">
                  <div class="txt-xs txt-orange txt-bold" style="margin-bottom:4px;">Trợ lý AI Meta Gym</div>
                  Bạn đã nạp <strong class="tnum">140g / 160g</strong> đạm hôm nay. Sau tập chỉ cần thêm <strong class="tnum">20–25g đạm</strong>:
                  <div class="txt-xs" style="margin-top:5px;">• 1 muỗng Whey Isolate (~25g đạm)<br />• Hoặc 100g ức gà luộc + 1 quả chuối</div>
                </div>
                <div class="chat-time">18:01</div>
              </div>
            </div>

            <!-- User (Phải) -->
            <div class="chat-row-user">
              <div class="chat-bubble-user">
                Vai phải mình hơi mỏi nhẹ, nên khởi động thế nào trước khi đẩy Bench Press?
              </div>
              <span class="chat-time">18:02</span>
            </div>

            <!-- AI (Trái) -->
            <div class="chat-row-ai">
              <div class="chat-ai-avatar"><img src="../../meta-gym/assets/svg/navigation/nav_ai_emblem.svg" alt="AI" /></div>
              <div style="flex:1;min-width:0;">
                <div class="chat-bubble-ai">
                  Dành <strong class="tnum">5 phút</strong> xoay khớp vai với dây kháng lực (Band Pull-Apart 2×15 + External Rotation 2×12) và 2 hiệp khởi động thanh đòn rỗng trước khi lên tạ chính nhé!
                </div>
                <div class="chat-time">18:02</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Thanh nhập câu hỏi + gợi ý nhanh cố định phía trên Bottom Nav -->
        <div class="ai-composer-dock" style="position:absolute;left:0;right:0;bottom:96px;z-index:9;padding:8px 14px 10px;background:linear-gradient(180deg,rgba(15,17,21,0) 0%,rgba(15,17,21,0.92) 24%,rgba(15,17,21,0.98) 100%);">
          <div class="filter-row" style="margin-bottom:7px;padding-bottom:0;">
            <span class="filter-pill" style="font-size:11px;padding:5px 11px;">Gợi ý bữa phụ 25g đạm</span>
            <span class="filter-pill" style="font-size:11px;padding:5px 11px;">Chỉnh form Bench Press</span>
            <span class="filter-pill" style="font-size:11px;padding:5px 11px;">Lịch phục hồi vai</span>
          </div>
          <div class="row" style="gap:8px;">
            <div class="input-box" style="flex:1;height:44px;color:var(--text-secondary);font-size:14px;">Nhập câu hỏi cho Trợ lý AI...</div>
            <div style="width:44px;height:44px;border-radius:14px;background:var(--primary);color:#FFF;display:flex;align-items:center;justify-content:center;font-weight:800;flex-shrink:0;">↑</div>
          </div>
        </div>
      
        <div class="bottom-nav-wrap">
          <nav class="bottom-nav">
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_home_outline.svg" alt="Trang chủ" /></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_training_outline.svg" alt="Tập luyện" /></div>
            <div class="nav-ai-wrap active"><div class="nav-ai-btn"><img class="nav-ai-svg" src="../../meta-gym/assets/svg/navigation/nav_ai_on_primary.svg" alt="AI" /></div></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_messages_outline.svg" alt="Tin nhắn" /></div>
            <div class="nav-item"><img class="nav-svg" src="../../meta-gym/assets/svg/navigation/nav_profile_outline.svg" alt="Hồ sơ" /></div>
          </nav>
        </div>
      </div>
    `
  }
]);
