/* ==========================================================================
   Meta Gym — Loyalty & Meta Points Preview Module (Demo Data Only)
   Tich hop vao Preview Studio (screens-preview.html) theo DESIGN.md & MASTER.md
   5 man hinh tinh gon, khong trung lap (METAGYM_LOYALTY_DEMO).
   ========================================================================== */
(function (global) {
  'use strict';

  var ASSET = '../../meta-gym/assets';

  function ico(path, cls, alt) {
    return '<img src="' + ASSET + '/' + path + '?v=20261124svg3" class="' + (cls || 'ico-sm') + '" alt="' + esc(alt || '') + '" />';
  }

  function esc(val) {
    return String(val == null ? '' : val)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function fmtNum(n) {
    return Number(n || 0).toLocaleString('vi-VN');
  }

  var DISCLAIMER_SHORT = 'Số liệu điểm, hạng và ưu đãi chỉ dùng minh họa preview, chưa phải chính sách chính thức.';

  /* ------------------------------------------------------------------------
     Single Source of Truth: Tiers, Packages, Rewards, Scenarios
     ------------------------------------------------------------------------ */
  var TIERS = [
    {
      id: 'bronze',
      name: 'Đồng',
      minPoints: 0,
      cardImage: ASSET + '/images/membership/card_bronze_horizontal.jpg',
      accentVar: '#C87D55',
      tagline: 'Khởi đầu hành trình tập luyện tại Meta Gym',
      perks: [
        'Check-in QR không chạm tại phòng tập',
        'Tích điểm xét hạng minh họa khi đăng ký hoặc gia hạn gói',
        'Truy cập danh mục ưu đãi thành viên cơ bản'
      ]
    },
    {
      id: 'silver',
      name: 'Bạc',
      minPoints: 800,
      cardImage: ASSET + '/images/membership/card_silver_horizontal.jpg',
      accentVar: '#A9C7E8',
      tagline: 'Tăng nhịp ổn định cùng các đặc quyền đo chỉ số định kỳ',
      perks: [
        'Bao gồm toàn bộ quyền lợi minh họa của hạng Đồng',
        'Ưu tiên nhắc lịch kiểm tra chỉ số InBody định kỳ',
        'Tham gia đổi các ưu đãi dịch vụ trong danh mục Meta Points'
      ]
    },
    {
      id: 'gold',
      name: 'Vàng',
      minPoints: 2000,
      cardImage: ASSET + '/images/membership/card_gold_horizontal.jpg',
      accentVar: '#F5B041',
      tagline: 'Hội viên gắn bó với ưu đãi trải nghiệm PT & dịch vụ chuyên sâu',
      perks: [
        'Bao gồm toàn bộ quyền lợi minh họa của hạng Bạc',
        'Ưu tiên giữ suất trải nghiệm PT 1:1 theo chương trình từng kỳ',
        'Mở khóa gói voucher ưu đãi dành riêng cho hội viên Vàng',
        'Hỗ trợ bảo lưu gói tập linh hoạt tại quầy lễ tân'
      ]
    },
    {
      id: 'diamond',
      name: 'Kim Cương',
      minPoints: 6000,
      cardImage: ASSET + '/images/membership/card_diamond_horizontal.jpg',
      accentVar: '#70AEE8',
      tagline: 'Hạng cao nhất dành cho hội viên đồng hành bền vững cùng Meta Gym',
      perks: [
        'Bao gồm toàn bộ quyền lợi minh họa của hạng Vàng',
        'Đặc quyền ưu tiên khung giờ cao điểm & sự kiện nội bộ',
        'Suất ưu đãi cao cấp & quà tặng tri ân theo đợt phát hành',
        'Hỗ trợ chăm sóc riêng bởi đội ngũ vận hành câu lạc bộ'
      ]
    }
  ];

  var PACKAGES = [
    {
      id: 'pkg-1m',
      name: 'Cơ bản',
      durationLabel: '1 tháng',
      priceLabel: '890.000đ',
      priceNote: 'Giá tham chiếu từ dữ liệu Studio hiện tại',
      bonusPoints: 100,
      iconPath: 'svg/membership/membership_tier_basic.svg',
      badge: 'Linh hoạt',
      highlights: [
        'Tập luyện không giới hạn khu vực máy & tạ tự do trong 1 tháng',
        'Tặng +100 điểm thưởng minh họa (điểm thưởng gói, không ấn định hạng)',
        'Phù hợp trải nghiệm ngắn hạn hoặc theo dõi lịch công tác'
      ]
    },
    {
      id: 'pkg-6m',
      name: 'Tiêu chuẩn',
      durationLabel: '6 tháng',
      priceLabel: '4.490.000đ',
      priceNote: 'Giá tham chiếu từ dữ liệu Studio hiện tại',
      bonusPoints: 650,
      iconPath: 'svg/membership/membership_tier_plus.svg',
      badge: 'Phổ biến',
      highlights: [
        'Tập luyện toàn khu vực phòng tập & tủ đồ tiêu chuẩn trong 6 tháng',
        'Tặng +650 điểm thưởng minh họa góp vào hành trình xét hạng',
        'Định hướng lộ trình tập ban đầu với HLV trực khu'
      ]
    },
    {
      id: 'pkg-1y',
      name: 'Nâng cao',
      durationLabel: '1 năm',
      priceLabel: '8.490.000đ',
      priceNote: 'Giá tham chiếu từ dữ liệu Studio hiện tại',
      bonusPoints: 1500,
      iconPath: 'svg/membership/membership_tier_vip.svg',
      badge: 'Tiết kiệm',
      highlights: [
        'Sử dụng đầy đủ khu tập & phòng phục hồi trong 1 năm',
        'Tặng +1.500 điểm thưởng minh họa (hạng vẫn xét theo tổng điểm xét hạng)',
        'Hỗ trợ kiểm tra chỉ số định kỳ minh họa tại câu lạc bộ'
      ]
    },
    {
      id: 'pkg-3y',
      name: 'Dài hạn',
      durationLabel: '3 năm',
      priceLabel: 'Giá đang cập nhật',
      priceNote: 'Chưa công bố bảng giá trong bản preview này',
      bonusPoints: 5000,
      iconPath: 'svg/membership/premium_crown.svg',
      badge: 'Gắn bó',
      highlights: [
        'Cam kết đồng hành dài hạn 3 năm tại hệ thống Meta Gym',
        'Tặng +5.000 điểm thưởng minh họa — không tự động gán cố định một hạng',
        'Chính sách giá và điều khoản chi tiết sẽ cập nhật trước khi mở bán'
      ]
    }
  ];

  var REWARDS = [
    {
      id: 'rw-voucher-100',
      category: 'voucher',
      categoryLabel: 'Voucher',
      title: 'Voucher giảm 100.000đ',
      pointsCost: 300,
      description: 'Giảm trực tiếp 100.000đ hóa đơn gia hạn gói tập hoặc dịch vụ tại quầy (minh họa).',
      iconPath: 'svg/membership/payment_coupon_voucher.svg',
      requiresStaffConfirm: false,
      stockAvailable: true,
      terms: [
        'Ưu đãi minh họa dùng 1 lần, không quy đổi tiền mặt.',
        'Đổi quà chỉ trừ Điểm khả dụng, giữ nguyên Điểm xét hạng.',
        'Bản preview không phát hành mã voucher hay cổng thanh toán thật.'
      ]
    },
    {
      id: 'rw-inbody',
      category: 'service',
      categoryLabel: 'Dịch vụ',
      title: 'Một lần đo InBody',
      pointsCost: 400,
      description: 'Phân tích tỷ lệ cơ, mỡ và nước cơ thể tại khu vực đo chỉ số của câu lạc bộ.',
      iconPath: 'svg/workout/workout_history.svg',
      requiresStaffConfirm: true,
      stockAvailable: true,
      terms: [
        'Cần nhân viên tại quầy xác nhận trước khi thực hiện đo InBody.',
        'Demo chỉ ghi nhận mục ưu đãi, không giả lập đặt lịch hẹn thật.',
        'Khuyến nghị nhịn ăn nhẹ 2 giờ trước khi đo để số liệu ổn định.'
      ]
    },
    {
      id: 'rw-pt-trial',
      category: 'service',
      categoryLabel: 'Dịch vụ',
      title: 'Một buổi PT trải nghiệm',
      pointsCost: 900,
      description: 'Một buổi tập 1:1 cùng Huấn luyện viên Meta Gym để đánh giá kỹ thuật và tư thế.',
      iconPath: 'svg/coaching/coach_pkg_1on1.svg',
      requiresStaffConfirm: true,
      stockAvailable: true,
      terms: [
        'Cần nhân viên lễ tân hoặc HLV xác nhận khung giờ tập phù hợp.',
        'Chưa tạo lịch hẹn thật trong bản preview giao diện này.',
        'Áp dụng cho 1 hội viên chính chủ theo thông tin tài khoản.'
      ]
    },
    {
      id: 'rw-vip-perk',
      category: 'voucher',
      categoryLabel: 'Voucher',
      title: 'Ưu đãi cao cấp',
      pointsCost: 1500,
      description: 'Gói đặc quyền nâng cấp trải nghiệm và voucher dịch vụ cao cấp tại Meta Gym (minh họa).',
      iconPath: 'svg/membership/premium_crown.svg',
      requiresStaffConfirm: true,
      stockAvailable: true,
      terms: [
        'Áp dụng tại quầy dịch vụ với xác nhận của nhân viên phụ trách.',
        'Không áp dụng cộng dồn với các chương trình giảm giá khác.',
        'Thông số và hạn mức ưu đãi dùng cho mục đích xem trước UI.'
      ]
    },
    {
      id: 'rw-sold-out',
      category: 'voucher',
      categoryLabel: 'Voucher',
      title: 'Quà tặng bình giữ nhiệt Meta Gym',
      pointsCost: 600,
      description: 'Mẫu ưu đãi minh họa trạng thái đã hết lượt đổi trong đợt phát hành hiện tại.',
      iconPath: 'svg/membership/payment_gift.svg',
      requiresStaffConfirm: true,
      stockAvailable: false,
      terms: [
        'Mục này minh họa trạng thái Hết lượt trên Danh mục ưu đãi.',
        'Quà vật lý cần nhận trực tiếp tại quầy khi có hàng trở lại.'
      ]
    }
  ];

  function getDefaultMyRewards() {
    return [
      {
        uid: 'my-init-1',
        rewardId: 'rw-inbody',
        title: 'Một lần đo InBody',
        categoryLabel: 'Dịch vụ',
        redeemedAt: '20/11/2026',
        expiresAt: '20/12/2026',
        status: 'unused',
        requiresStaffConfirm: true,
        condition: 'Cần nhân viên tại quầy xác nhận lượt đo; chưa đặt lịch tự động trên app.',
        isNewDemo: false
      },
      {
        uid: 'my-init-2',
        rewardId: 'rw-voucher-100',
        title: 'Voucher giảm 100.000đ',
        categoryLabel: 'Voucher',
        redeemedAt: '05/10/2026',
        expiresAt: '05/11/2026',
        status: 'used',
        requiresStaffConfirm: false,
        condition: 'Đã áp dụng cho giao dịch minh họa tại câu lạc bộ.',
        isNewDemo: false
      },
      {
        uid: 'my-init-3',
        rewardId: 'rw-pt-trial',
        title: 'Một buổi PT trải nghiệm',
        categoryLabel: 'Dịch vụ',
        redeemedAt: '02/08/2026',
        expiresAt: '02/09/2026',
        status: 'expired',
        requiresStaffConfirm: true,
        condition: 'Cần nhân viên/HLV xác nhận khi còn hiệu lực. Đã quá hạn sử dụng minh họa.',
        isNewDemo: false
      }
    ];
  }

  function getDefaultHistory() {
    return [
      {
        id: 'his-1',
        type: 'earn',
        title: 'Cộng điểm khi gia hạn gói tập (minh họa)',
        detail: 'Gói Tiêu chuẩn · 6 tháng · Cộng vào khả dụng & xét hạng',
        date: '15/09/2026 · 09:24',
        points: 650,
        status: 'Thành công',
        statusTone: 'success'
      },
      {
        id: 'his-2',
        type: 'adjust',
        title: 'Hoàn điểm điều chỉnh giao dịch demo',
        detail: 'Điều chỉnh do hủy yêu cầu đổi dịch vụ trước đó tại quầy',
        date: '18/09/2026 · 14:10',
        points: 190,
        status: 'Đã hoàn điểm',
        statusTone: 'info'
      },
      {
        id: 'his-3',
        type: 'spend',
        title: 'Trừ điểm đổi ưu đãi: Một lần đo InBody',
        detail: 'Chỉ trừ Điểm khả dụng · Giữ nguyên Điểm xét hạng',
        date: '20/11/2026 · 17:45',
        points: -400,
        status: 'Đã đổi demo',
        statusTone: 'warning'
      },
      {
        id: 'his-4',
        type: 'earn',
        title: 'Cộng điểm khi đăng ký gói nâng cao kỳ trước',
        detail: 'Đăng ký gói tập · Ghi nhận điểm tích lũy xét hạng',
        date: '01/03/2026 · 10:05',
        points: 1500,
        status: 'Thành công',
        statusTone: 'success'
      }
    ];
  }

  var SCENARIOS = [
    {
      id: 'default',
      label: 'Mặc định (Vàng)',
      description: 'Nguyễn Minh Quân · Gói 6 tháng · Khả dụng 1.240đ · Xét hạng 2.150đ',
      build: function () {
        return {
          scenarioId: 'default',
          memberName: 'Nguyễn Minh Quân',
          memberCode: 'MG-2026-8421',
          packageId: 'pkg-6m',
          packageName: 'Gói 6 tháng',
          packagePeriod: '15/09/2026 – 14/03/2027 (Minh họa)',
          availablePoints: 1240,
          tierPoints: 2150,
          selectedRewardId: 'rw-voucher-100',
          rewardCategoryFilter: 'all',
          myRewardsFilter: 'all',
          historyFilter: 'all',
          selectedPackageId: null,
          redeemSuccessNotice: null,
          myRewards: getDefaultMyRewards(),
          history: getDefaultHistory()
        };
      }
    },
    {
      id: 'no-points',
      label: 'Chưa có điểm',
      description: 'Hội viên mới · 0 điểm khả dụng · 0 điểm xét hạng · Hạng Đồng',
      build: function () {
        return {
          scenarioId: 'no-points',
          memberName: 'Nguyễn Minh Quân',
          memberCode: 'MG-2026-8421',
          packageId: 'pkg-1m',
          packageName: 'Gói 1 tháng',
          packagePeriod: '27/11/2026 – 27/12/2026 (Minh họa)',
          availablePoints: 0,
          tierPoints: 0,
          selectedRewardId: 'rw-voucher-100',
          rewardCategoryFilter: 'all',
          myRewardsFilter: 'all',
          historyFilter: 'all',
          selectedPackageId: null,
          redeemSuccessNotice: null,
          myRewards: [],
          history: []
        };
      }
    },
    {
      id: 'no-rewards',
      label: 'Chưa có ưu đãi',
      description: 'Có 1.240đ khả dụng · Danh sách Ưu đãi của tôi đang rỗng',
      build: function () {
        var base = SCENARIOS[0].build();
        base.scenarioId = 'no-rewards';
        base.myRewards = [];
        return base;
      }
    },
    {
      id: 'insufficient',
      label: 'Không đủ điểm',
      description: 'Chỉ còn 150đ khả dụng · Toàn bộ ưu đãi hiện thiếu điểm',
      build: function () {
        var base = SCENARIOS[0].build();
        base.scenarioId = 'insufficient';
        base.availablePoints = 150;
        base.selectedRewardId = 'rw-voucher-100';
        return base;
      }
    },
    {
      id: 'used-expired',
      label: 'Đã dùng / Hết hạn',
      description: 'Ưu đãi của tôi chỉ gồm mục Đã sử dụng & Hết hạn',
      build: function () {
        var base = SCENARIOS[0].build();
        base.scenarioId = 'used-expired';
        base.myRewards = getDefaultMyRewards().filter(function (x) { return x.status !== 'unused'; });
        return base;
      }
    },
    {
      id: 'max-tier',
      label: 'Hạng Kim Cương',
      description: 'Đã đạt hạng cao nhất (6.450đ xét hạng · 2.400đ khả dụng)',
      build: function () {
        var base = SCENARIOS[0].build();
        base.scenarioId = 'max-tier';
        base.availablePoints = 2400;
        base.tierPoints = 6450;
        base.packageId = 'pkg-1y';
        base.packageName = 'Gói 1 năm';
        base.packagePeriod = '01/06/2026 – 01/06/2027 (Minh họa)';
        base.selectedRewardId = 'rw-vip-perk';
        return base;
      }
    },
    {
      id: 'no-package',
      label: 'Chưa có gói tập',
      description: 'Chưa đăng ký gói tập hiện tại · Xem 4 gói để nâng cấp',
      build: function () {
        var base = SCENARIOS[0].build();
        base.scenarioId = 'no-package';
        base.packageId = null;
        base.packageName = 'Chưa có gói tập';
        base.packagePeriod = 'Bạn có thể tham khảo 4 gói thời hạn bên dưới';
        base.availablePoints = 420;
        base.tierPoints = 850;
        return base;
      }
    }
  ];

  /* ------------------------------------------------------------------------
     State Derivation Helpers (Single Source of Truth)
     ------------------------------------------------------------------------ */
  function computeTierInfo(tierPoints) {
    var pts = Math.max(0, Number(tierPoints || 0));
    var currentIdx = 0;
    for (var i = 0; i < TIERS.length; i++) {
      if (pts >= TIERS[i].minPoints) currentIdx = i;
    }
    var currentTier = TIERS[currentIdx];
    var nextTier = currentIdx < TIERS.length - 1 ? TIERS[currentIdx + 1] : null;
    var remaining = nextTier ? Math.max(0, nextTier.minPoints - pts) : 0;
    var progressPct = 100;
    if (nextTier) {
      var span = Math.max(1, nextTier.minPoints - currentTier.minPoints);
      var gained = Math.max(0, pts - currentTier.minPoints);
      progressPct = Math.min(100, Math.max(4, Math.round((gained / span) * 100)));
      if (pts === 0) progressPct = 0;
    }
    return {
      currentIdx: currentIdx,
      currentTier: currentTier,
      nextTier: nextTier,
      remainingToNext: remaining,
      progressPct: progressPct,
      isMaxTier: !nextTier
    };
  }

  function findReward(id) {
    for (var i = 0; i < REWARDS.length; i++) {
      if (REWARDS[i].id === id) return REWARDS[i];
    }
    return REWARDS[0];
  }

  function findPackage(id) {
    for (var i = 0; i < PACKAGES.length; i++) {
      if (PACKAGES[i].id === id) return PACKAGES[i];
    }
    return null;
  }

  function getRewardState(reward, availablePoints) {
    if (!reward.stockAvailable) {
      return {
        code: 'out',
        label: 'Hết lượt',
        pillCls: 'pill-muted',
        canRedeem: false,
        shortfall: 0
      };
    }
    var diff = reward.pointsCost - availablePoints;
    if (diff > 0) {
      return {
        code: 'short',
        label: 'Chưa đủ điểm',
        pillCls: 'pill-warning',
        canRedeem: false,
        shortfall: diff
      };
    }
    return {
      code: 'ready',
      label: 'Có thể đổi',
      pillCls: 'pill-success',
      canRedeem: true,
      shortfall: 0
    };
  }

  function renderMemberBottomNav() {
    return (
      '<div class="bottom-nav-wrap">' +
        '<nav class="bottom-nav" aria-label="Điều hướng hội viên">' +
          '<button type="button" class="nav-item" style="background:none;border:none;" data-go="member-home" aria-label="Trang chủ">' +
            ico('svg/navigation/nav_home_outline.svg', 'nav-svg', 'Trang chủ') +
          '</button>' +
          '<button type="button" class="nav-item" style="background:none;border:none;" data-go="member-training-hub" aria-label="Tập luyện">' +
            ico('svg/navigation/nav_training_outline.svg', 'nav-svg', 'Tập luyện') +
          '</button>' +
          '<div class="nav-ai-wrap">' +
            '<button type="button" class="nav-ai-btn" style="border:none;cursor:pointer;" data-go="member-ai-messages" aria-label="Trợ lý AI">' +
              ico('svg/navigation/nav_ai_on_primary.svg', 'nav-ai-svg', 'AI') +
            '</button>' +
          '</div>' +
          '<button type="button" class="nav-item" style="background:none;border:none;" data-go="member-conversations" aria-label="Tin nhắn">' +
            ico('svg/navigation/nav_messages_outline.svg', 'nav-svg', 'Tin nhắn') +
          '</button>' +
          '<button type="button" class="nav-item active" style="background:none;border:none;" data-loyalty-action="reset-scroll" aria-label="Hồ sơ & Gói tập">' +
            ico('svg/navigation/nav_profile_filled.svg', 'nav-svg', 'Hồ sơ') +
          '</button>' +
        '</nav>' +
      '</div>'
    );
  }

  function renderSubHeader(eyebrow, title, rightHtml) {
    return (
      '<div class="mg-header">' +
        '<button type="button" class="circle-btn" data-back aria-label="Quay lại">' +
          ico('svg/setting/common_back.svg', 'ico-sm', 'Quay lại') +
        '</button>' +
        '<div class="mg-header-text">' +
          '<div class="mg-eyebrow">' + esc(eyebrow) + '</div>' +
          '<div class="mg-title">' + esc(title) + '</div>' +
        '</div>' +
        (rightHtml || '') +
      '</div>'
    );
  }

  function renderDisclaimerStrip() {
    return (
      '<div class="loyalty-disclaimer">' +
        ico('svg/states/state_info.svg', 'ico-xs', 'Lưu ý') +
        '<span>' + esc(DISCLAIMER_SHORT) + '</span>' +
      '</div>'
    );
  }

  /* ------------------------------------------------------------------------
     5 Screen Renderers (Pure Functions of State -> Guaranteed Sync)
     ------------------------------------------------------------------------ */

  // MÀN 1 — Tổng quan Gói tập & Meta Points (kèm 4 gói thời hạn & modal chi tiết gói)
  function renderScreenOverview(st) {
    var ti = computeTierInfo(st.tierPoints);
    var unusedCount = st.myRewards.filter(function (x) { return x.status === 'unused'; }).length;
    var hasPackage = !!st.packageId;
    var modalPkg = st.selectedPackageId ? findPackage(st.selectedPackageId) : null;

    var pkgPreviewCards = PACKAGES.map(function (pkg) {
      var isCur = pkg.id === st.packageId;
      return (
        '<div class="card-solid loyalty-mini-pkg' + (isCur ? ' is-current' : '') + '">' +
          '<div class="row-between" style="margin-bottom:6px;">' +
            ico(pkg.iconPath, 'ico-sm', pkg.name) +
            '<span class="pill ' + (isCur ? 'pill-orange' : 'pill-muted') + '">' + esc(isCur ? 'Đang dùng' : pkg.durationLabel) + '</span>' +
          '</div>' +
          '<div style="font-size:15px;font-weight:700;color:var(--text-primary);">' + esc(pkg.name) + ' · ' + esc(pkg.durationLabel) + '</div>' +
          '<div class="tnum" style="font-size:14px;font-weight:800;color:var(--primary-text);margin:4px 0;">' + esc(pkg.priceLabel) + '</div>' +
          '<div class="tnum" style="font-size:12px;color:var(--text-secondary);margin-bottom:10px;">Thưởng mẫu +' + fmtNum(pkg.bonusPoints) + ' điểm</div>' +
          '<button type="button" class="btn ' + (isCur ? 'btn-secondary' : 'btn-primary') + ' loyalty-btn-sm" data-loyalty-action="open-package" data-pkg-id="' + pkg.id + '">Xem chi tiết</button>' +
        '</div>'
      );
    }).join('');

    var pkgSheetOverlay = '';
    if (modalPkg) {
      pkgSheetOverlay = (
        '<div class="qr-overlay open" data-loyalty-action="close-package-backdrop" role="dialog" aria-modal="true" aria-label="Chi tiết gói tập minh họa">' +
          '<div class="qr-sheet loyalty-pkg-sheet">' +
            '<div class="row-between" style="margin-bottom:10px;">' +
              '<span class="pill pill-orange">Chi tiết gói minh họa</span>' +
              '<button type="button" class="circle-btn" style="width:44px;height:44px;" data-loyalty-action="close-package" aria-label="Đóng">' +
                ico('svg/setting/common_close.svg', 'ico-xs', 'Đóng') +
              '</button>' +
            '</div>' +
            '<div style="font-size:20px;font-weight:800;color:var(--text-primary);text-align:left;">Gói ' + esc(modalPkg.name) + ' · ' + esc(modalPkg.durationLabel) + '</div>' +
            '<div class="tnum" style="font-size:15px;font-weight:700;color:var(--primary-text);text-align:left;margin:4px 0 12px;">' + esc(modalPkg.priceLabel) + ' · Thưởng mẫu +' + fmtNum(modalPkg.bonusPoints) + ' điểm</div>' +
            '<div style="text-align:left;margin-bottom:12px;">' +
              modalPkg.highlights.map(function (h) {
                return '<div class="loyalty-perk-row">' + ico('svg/membership/membership_active_seal.svg', 'ico-xs', '') + '<span>' + esc(h) + '</span></div>';
              }).join('') +
            '</div>' +
            '<div class="loyalty-rule-callout" style="text-align:left;margin-bottom:14px;">' +
              ico('svg/states/state_info.svg', 'ico-xs', '') +
              '<span style="font-size:12px;line-height:1.45;">Đây là màn hình xem trước cấu trúc gói. Gói tập quy định thời hạn sử dụng, không tự ấn định hạng thành viên; việc mua hoặc gia hạn thực hiện tại luồng thanh toán chính thức.</span>' +
            '</div>' +
            '<button type="button" class="btn btn-primary" data-loyalty-action="close-package">Đã hiểu</button>' +
          '</div>' +
        '</div>'
      );
    }

    var body = (
      '<div class="mg-header">' +
        '<div class="mg-logo"><img src="' + ASSET + '/svg/brand/app_icon_mark.svg" alt="Meta Gym" /></div>' +
        '<div class="mg-header-text">' +
          '<div class="mg-eyebrow">HỘI VIÊN &amp; ƯU ĐÃI</div>' +
          '<div class="mg-title">Gói tập</div>' +
        '</div>' +
        '<button type="button" class="circle-btn" data-go="loyalty-history" aria-label="Lịch sử điểm" title="Lịch sử điểm">' +
          ico('svg/workout/workout_history.svg', 'ico-sm', 'Lịch sử') +
        '</button>' +
      '</div>' +

      renderDisclaimerStrip() +

      // Card vỏ thẻ kim loại theo hạng hiện tại
      '<div class="card-solid loyalty-member-hero">' +
        '<div class="loyalty-card-shell">' +
          '<img src="' + ti.currentTier.cardImage + '" alt="Thẻ hạng ' + esc(ti.currentTier.name) + '" class="loyalty-card-art" />' +
          '<div class="loyalty-card-scrim"></div>' +
          '<div class="loyalty-card-overlay">' +
            '<div class="row-between">' +
              '<span class="loyalty-card-badge">HẠNG ' + esc(ti.currentTier.name.toUpperCase()) + '</span>' +
              '<span class="pill ' + (hasPackage ? 'pill-success' : 'pill-warning') + '">' + (hasPackage ? 'Đang hiệu lực' : 'Chưa có gói') + '</span>' +
            '</div>' +
            '<div style="margin-top:auto;">' +
              '<div style="font-size:12px;color:rgba(247,249,252,0.78);">Hội viên</div>' +
              '<div style="font-size:18px;font-weight:800;color:#FFFFFF;letter-spacing:-0.01em;">' + esc(st.memberName) + '</div>' +
              '<div class="row-between" style="margin-top:6px;">' +
                '<div style="font-size:12px;color:rgba(247,249,252,0.88);font-weight:600;">' + esc(st.packageName) + '</div>' +
                '<div class="tnum" style="font-size:11px;color:rgba(247,249,252,0.76);">' + esc(st.memberCode) + '</div>' +
              '</div>' +
            '</div>' +
          '</div>' +
        '</div>' +
        '<div class="row-between" style="padding:10px 14px 12px;gap:8px;">' +
          '<div style="min-width:0;">' +
            '<div style="font-size:12px;color:var(--text-secondary);">Thời hạn gói đang dùng</div>' +
            '<div class="tnum" style="font-size:14px;font-weight:700;color:var(--text-primary);">' + esc(st.packagePeriod) + '</div>' +
          '</div>' +
          '<span class="pill pill-orange">Hạng ' + esc(ti.currentTier.name) + '</span>' +
        '</div>' +
      '</div>' +

      // Card Meta Points (Level 2 Warm Glass)
      '<div class="card-warm-glass">' +
        '<div class="row-between" style="margin-bottom:10px;">' +
          '<div>' +
            '<div style="font-size:12px;color:var(--text-warm-muted);font-weight:600;">Hệ thống điểm thưởng &amp; xếp hạng</div>' +
            '<div style="font-size:16px;font-weight:800;color:var(--text-primary);">Meta Points</div>' +
          '</div>' +
          '<span class="pill pill-orange">Hạng ' + esc(ti.currentTier.name) + '</span>' +
        '</div>' +

        '<div class="loyalty-2col" style="margin-bottom:12px;">' +
          '<div class="metric-box">' +
            '<div class="loyalty-metric-lbl">Điểm khả dụng (đổi quà)</div>' +
            '<div class="loyalty-metric-val tnum" style="font-size:22px;color:var(--primary-text);">' + fmtNum(st.availablePoints) + '</div>' +
            '<div class="loyalty-metric-sub">Trừ khi đổi ưu đãi</div>' +
          '</div>' +
          '<div class="metric-box">' +
            '<div class="loyalty-metric-lbl">Điểm xét hạng (tích lũy)</div>' +
            '<div class="loyalty-metric-val tnum" style="font-size:22px;">' + fmtNum(st.tierPoints) + '</div>' +
            '<div class="loyalty-metric-sub">Không giảm khi đổi quà</div>' +
          '</div>' +
        '</div>' +

        '<div style="margin-bottom:12px;">' +
          '<div class="row-between" style="font-size:12px;margin-bottom:4px;">' +
            '<span style="color:var(--text-warm-muted);">Tiến độ nâng hạng</span>' +
            (ti.isMaxTier
              ? '<span style="color:var(--success);font-weight:700;">Đã đạt hạng cao nhất</span>'
              : '<span class="tnum" style="color:var(--text-primary);font-weight:700;">' + fmtNum(st.tierPoints) + ' / ' + fmtNum(ti.nextTier.minPoints) + ' điểm</span>') +
          '</div>' +
          '<div class="prog-track" style="height:8px;"><div class="prog-fill orange" style="width:' + ti.progressPct + '%;"></div></div>' +
          '<div style="font-size:12px;color:var(--text-secondary);margin-top:6px;">' +
            (ti.isMaxTier
              ? 'Bạn đang ở hạng Kim Cương cao nhất của Meta Gym (minh họa).'
              : 'Còn thiếu <strong class="tnum" style="color:var(--text-primary);">' + fmtNum(ti.remainingToNext) + ' điểm</strong> để đạt hạng <strong>' + esc(ti.nextTier.name) + '</strong>.') +
          '</div>' +
        '</div>' +

        '<div class="loyalty-2col">' +
          '<button type="button" class="btn btn-primary" data-go="loyalty-rewards">Đổi ưu đãi</button>' +
          '<button type="button" class="btn btn-secondary" data-go="loyalty-history">Lịch sử điểm</button>' +
        '</div>' +
      '</div>' +

      // Lối vào Ưu đãi của tôi
      '<button type="button" class="card-solid loyalty-entry-card" data-go="loyalty-my-rewards">' +
        '<div class="loyalty-entry-icon">' + ico('svg/membership/payment_coupon_voucher.svg', 'ico-md', 'Ưu đãi') + '</div>' +
        '<div style="flex:1;min-width:0;text-align:left;">' +
          '<div style="font-size:15px;font-weight:700;color:var(--text-primary);">Ưu đãi của tôi</div>' +
          '<div class="tnum" style="font-size:12px;color:var(--text-secondary);">' +
            (unusedCount > 0 ? ('Đang có ' + unusedCount + ' ưu đãi chưa sử dụng') : 'Xem danh sách voucher & dịch vụ đã đổi') +
          '</div>' +
        '</div>' +
        '<span class="pill ' + (unusedCount > 0 ? 'pill-orange' : 'pill-muted') + ' tnum">' + st.myRewards.length + ' mục ›</span>' +
      '</button>' +

      // Quyền lợi hạng hiện tại
      '<div class="sec-head">' +
        '<h3>Quyền lợi hạng ' + esc(ti.currentTier.name) + '</h3>' +
        '<span class="txt-xs" style="color:var(--text-secondary);">Đang áp dụng</span>' +
      '</div>' +
      '<div class="card-solid">' +
        ti.currentTier.perks.map(function (p) {
          return (
            '<div class="loyalty-perk-row">' +
              ico('svg/membership/membership_active_seal.svg', 'ico-xs', 'Quyền lợi') +
              '<span>' + esc(p) + '</span>' +
            '</div>'
          );
        }).join('') +
      '</div>' +

      // Nâng cấp gói tập (4 gói thời hạn — bấm Xem chi tiết mở modal ngay tại đây)
      '<div class="sec-head" style="margin-top:14px;">' +
        '<h3>Nâng cấp gói tập</h3>' +
        '<span class="txt-xs tnum" style="color:var(--text-secondary);">4 gói thời hạn · Minh họa</span>' +
      '</div>' +
      '<div class="loyalty-hscroll">' + pkgPreviewCards + '</div>'
    );

    return {
      bodyClass: '',
      bodyHtml: body,
      overlaysHtml: renderMemberBottomNav() + pkgSheetOverlay
    };
  }

  // MÀN 2 — Danh mục ưu đãi
  function renderScreenRewards(st) {
    var cat = st.rewardCategoryFilter || 'all';
    var filtered = REWARDS.filter(function (rw) {
      return cat === 'all' || rw.category === cat;
    });

    var filtersHtml = [
      { id: 'all', label: 'Tất cả (' + REWARDS.length + ')' },
      { id: 'voucher', label: 'Voucher' },
      { id: 'service', label: 'Dịch vụ' }
    ].map(function (f) {
      return (
        '<button type="button" class="filter-pill loyalty-filter-btn' + (cat === f.id ? ' active' : '') + '" data-loyalty-action="filter-rewards" data-filter="' + f.id + '">' +
          esc(f.label) +
        '</button>'
      );
    }).join('');

    var cardsHtml = filtered.map(function (rw) {
      var rs = getRewardState(rw, st.availablePoints);
      var gapMsg = rs.code === 'short' ? ('Còn thiếu ' + fmtNum(rs.shortfall) + ' điểm') : (rs.code === 'out' ? 'Đã hết lượt đổi mẫu' : 'Đủ điểm để đổi ngay');
      return (
        '<div class="card-solid loyalty-reward-card" data-loyalty-action="open-reward" data-reward-id="' + rw.id + '" role="button" tabindex="0">' +
          '<div class="row-between" style="align-items:flex-start;gap:10px;">' +
            '<div class="loyalty-reward-ico">' + ico(rw.iconPath, 'ico-md', rw.title) + '</div>' +
            '<div style="flex:1;min-width:0;">' +
              '<div class="row-between" style="gap:6px;margin-bottom:4px;">' +
                '<span style="font-size:11px;font-weight:700;color:var(--text-secondary);">' + esc(rw.categoryLabel) + '</span>' +
                '<span class="pill ' + rs.pillCls + '">' + esc(rs.label) + '</span>' +
              '</div>' +
              '<div style="font-size:15px;font-weight:800;color:var(--text-primary);margin-bottom:4px;">' + esc(rw.title) + '</div>' +
              '<div style="font-size:12px;color:var(--text-secondary);line-height:1.45;">' + esc(rw.description) + '</div>' +
            '</div>' +
          '</div>' +
          '<div class="row-between" style="margin-top:12px;padding-top:10px;border-top:1px solid var(--border-solid);gap:8px;">' +
            '<div>' +
              '<div class="tnum" style="font-size:16px;font-weight:800;color:var(--primary-text);">' + fmtNum(rw.pointsCost) + ' điểm</div>' +
              '<div class="tnum" style="font-size:11px;color:' + (rs.code === 'short' ? 'var(--warning)' : 'var(--text-secondary)') + ';">' + esc(gapMsg) + '</div>' +
            '</div>' +
            '<button type="button" class="btn ' + (rs.canRedeem ? 'btn-primary' : 'btn-secondary') + ' loyalty-btn-compact" data-loyalty-action="open-reward" data-reward-id="' + rw.id + '">' +
              (rs.canRedeem ? 'Đổi ngay' : 'Xem chi tiết') +
            '</button>' +
          '</div>' +
        '</div>'
      );
    }).join('');

    var body = (
      renderSubHeader('META POINTS · ĐỔI QUÀ', 'Danh mục ưu đãi',
        '<button type="button" class="pill pill-orange loyalty-pill-link" data-go="loyalty-my-rewards">Của tôi ›</button>'
      ) +
      renderDisclaimerStrip() +

      '<div class="card-warm-glass" style="padding:14px;">' +
        '<div class="row-between" style="gap:8px;">' +
          '<div>' +
            '<div style="font-size:12px;color:var(--text-warm-muted);">Điểm khả dụng hiện có</div>' +
            '<div class="tnum" style="font-size:24px;font-weight:800;color:var(--primary-text);">' + fmtNum(st.availablePoints) + ' điểm</div>' +
          '</div>' +
          '<div style="text-align:right;">' +
            '<div style="font-size:11px;color:var(--text-secondary);">Điểm xét hạng</div>' +
            '<div class="tnum" style="font-size:14px;font-weight:700;color:var(--text-primary);">' + fmtNum(st.tierPoints) + ' điểm (Giữ nguyên)</div>' +
          '</div>' +
        '</div>' +
      '</div>' +

      '<div class="filter-row">' + filtersHtml + '</div>' +
      cardsHtml
    );

    return {
      bodyClass: 'no-nav',
      bodyHtml: body,
      overlaysHtml: ''
    };
  }

  // MÀN 4 — Chi tiết và xác nhận đổi ưu đãi
  function renderScreenRewardDetail(st) {
    var rw = findReward(st.selectedRewardId);
    var rs = getRewardState(rw, st.availablePoints);
    var afterPoints = st.availablePoints - rw.pointsCost;
    var ti = computeTierInfo(st.tierPoints);
    var noticeMatchesReward = st.redeemSuccessNotice && st.redeemSuccessNotice.rewardId === rw.id;

    var quickPickChips = REWARDS.map(function (item) {
      var active = item.id === rw.id;
      return (
        '<button type="button" class="filter-pill loyalty-filter-btn' + (active ? ' active' : '') + '" data-loyalty-action="select-reward-only" data-reward-id="' + item.id + '">' +
          esc(item.title.split(' ').slice(0, 3).join(' ')) +
        '</button>'
      );
    }).join('');

    var successBlock = noticeMatchesReward ? (
      '<div class="card-solid loyalty-success-box">' +
        '<div class="row-between" style="margin-bottom:6px;">' +
          '<div style="display:flex;align-items:center;gap:8px;">' +
            ico('svg/membership/payment_success.svg', 'ico-md', 'Thành công') +
            '<div>' +
              '<div style="font-size:15px;font-weight:800;color:var(--success);">Đổi ưu đãi thành công (Dữ liệu demo)</div>' +
              '<div style="font-size:12px;color:var(--text-secondary);">Không phát sinh mã thanh toán hay voucher thật</div>' +
            '</div>' +
          '</div>' +
        '</div>' +
        '<div class="tnum" style="font-size:13px;color:var(--text-primary);margin-bottom:10px;line-height:1.45;">' +
          'Đã trừ <strong>' + fmtNum(st.redeemSuccessNotice.cost) + ' điểm khả dụng</strong>. Điểm còn lại: <strong>' + fmtNum(st.availablePoints) + ' điểm</strong>. Điểm xét hạng giữ nguyên ở mức <strong>' + fmtNum(st.tierPoints) + ' điểm (Hạng ' + esc(ti.currentTier.name) + ')</strong>.' +
        '</div>' +
        '<div class="loyalty-2col">' +
          '<button type="button" class="btn btn-primary" data-go="loyalty-my-rewards">Xem Ưu đãi của tôi</button>' +
          '<button type="button" class="btn btn-secondary" data-go="loyalty-history">Xem Lịch sử điểm</button>' +
        '</div>' +
      '</div>'
    ) : '';

    var body = (
      renderSubHeader('XÁC NHẬN ĐỔI QUÀ', 'Chi tiết ưu đãi') +
      renderDisclaimerStrip() +

      '<div class="filter-row" title="Chọn nhanh ưu đãi mẫu">' + quickPickChips + '</div>' +

      successBlock +

      '<div class="card-warm-glass">' +
        '<div class="row-between" style="margin-bottom:10px;">' +
          '<div class="loyalty-reward-ico">' + ico(rw.iconPath, 'ico-md', rw.title) + '</div>' +
          '<span class="pill ' + rs.pillCls + '">' + esc(rs.label) + '</span>' +
        '</div>' +
        '<div style="font-size:18px;font-weight:800;color:var(--text-primary);margin-bottom:6px;">' + esc(rw.title) + '</div>' +
        '<div style="font-size:13px;color:var(--text-warm-muted);line-height:1.5;">' + esc(rw.description) + '</div>' +
      '</div>' +

      '<div class="card-solid">' +
        '<div style="font-size:14px;font-weight:700;color:var(--text-primary);margin-bottom:8px;">Chi tiết trừ điểm (Minh họa)</div>' +
        '<div class="loyalty-kv"><span>Điểm cần đổi</span><strong class="tnum" style="color:var(--primary-text);">-' + fmtNum(rw.pointsCost) + ' điểm</strong></div>' +
        '<div class="loyalty-kv"><span>Điểm khả dụng hiện tại</span><strong class="tnum">' + fmtNum(st.availablePoints) + ' điểm</strong></div>' +
        '<div class="loyalty-kv">' +
          '<span>Điểm khả dụng còn lại sau khi đổi</span>' +
          (rs.code === 'short'
            ? '<strong class="tnum" style="color:var(--warning);">Chưa đủ (thiếu ' + fmtNum(rs.shortfall) + 'đ)</strong>'
            : (rs.code === 'out'
              ? '<strong style="color:var(--text-secondary);">Hết lượt đổi mẫu</strong>'
              : '<strong class="tnum" style="color:var(--success);">' + fmtNum(afterPoints) + ' điểm</strong>')) +
        '</div>' +
        '<div class="loyalty-kv" style="border-bottom:none;padding-bottom:0;">' +
          '<span>Điểm xét hạng &amp; hạng thành viên</span>' +
          '<strong class="tnum" style="color:var(--info);">' + fmtNum(st.tierPoints) + 'đ · ' + esc(ti.currentTier.name) + ' (Không đổi)</strong>' +
        '</div>' +
      '</div>' +

      '<div class="card-solid">' +
        '<div style="font-size:14px;font-weight:700;color:var(--text-primary);margin-bottom:8px;">Điều kiện sử dụng minh họa</div>' +
        rw.terms.map(function (t) {
          return '<div class="loyalty-perk-row">' + ico('svg/setting/common_info.svg', 'ico-xs', '') + '<span>' + esc(t) + '</span></div>';
        }).join('') +
      '</div>'
    );

    var canClickConfirm = rs.canRedeem && !noticeMatchesReward;
    var dockBtnLabel = noticeMatchesReward
      ? 'Đã đổi trong demo'
      : (rs.code === 'short' ? ('Thiếu ' + fmtNum(rs.shortfall) + ' điểm') : (rs.code === 'out' ? 'Đã hết lượt' : 'Xác nhận đổi'));

    var overlays = (
      '<div class="bottom-cta-dock">' +
        '<div class="loyalty-2col">' +
          '<button type="button" class="btn btn-secondary" data-back>Để sau</button>' +
          '<button type="button" class="btn btn-primary" data-loyalty-action="confirm-redeem" data-reward-id="' + rw.id + '"' + (canClickConfirm ? '' : ' disabled aria-disabled="true"') + '>' +
            esc(dockBtnLabel) +
          '</button>' +
        '</div>' +
      '</div>'
    );

    return {
      bodyClass: 'no-nav',
      bodyHtml: body,
      overlaysHtml: overlays
    };
  }

  // MÀN 5 — Ưu đãi của tôi
  function renderScreenMyRewards(st) {
    var f = st.myRewardsFilter || 'all';
    var counts = {
      all: st.myRewards.length,
      unused: st.myRewards.filter(function (x) { return x.status === 'unused'; }).length,
      used: st.myRewards.filter(function (x) { return x.status === 'used'; }).length,
      expired: st.myRewards.filter(function (x) { return x.status === 'expired'; }).length
    };
    var filtered = st.myRewards.filter(function (item) {
      return f === 'all' || item.status === f;
    });

    var filterBar = [
      { id: 'all', label: 'Tất cả (' + counts.all + ')' },
      { id: 'unused', label: 'Chưa sử dụng (' + counts.unused + ')' },
      { id: 'used', label: 'Đã sử dụng (' + counts.used + ')' },
      { id: 'expired', label: 'Hết hạn (' + counts.expired + ')' }
    ].map(function (tab) {
      return (
        '<button type="button" class="filter-pill loyalty-filter-btn' + (f === tab.id ? ' active' : '') + '" data-loyalty-action="filter-my-rewards" data-filter="' + tab.id + '">' +
          esc(tab.label) +
        '</button>'
      );
    }).join('');

    var statusMeta = {
      unused: { label: 'Chưa sử dụng', cls: 'pill-orange' },
      used: { label: 'Đã sử dụng', cls: 'pill-success' },
      expired: { label: 'Hết hạn', cls: 'pill-muted' }
    };

    var contentHtml = '';
    if (filtered.length === 0) {
      contentHtml = (
        '<div class="card-solid loyalty-empty-box">' +
          ico('svg/states/empty_payments.svg', 'loyalty-empty-img', 'Chưa có ưu đãi') +
          '<div style="font-size:16px;font-weight:800;color:var(--text-primary);margin-bottom:4px;">' +
            (st.myRewards.length === 0 ? 'Bạn chưa có ưu đãi nào đã đổi' : 'Không có ưu đãi thuộc mục này') +
          '</div>' +
          '<div style="font-size:13px;color:var(--text-secondary);margin-bottom:14px;line-height:1.45;">' +
            'Sử dụng Điểm khả dụng (' + fmtNum(st.availablePoints) + ' điểm) để đổi thử ưu đãi trong bản preview. Điểm xét hạng luôn được giữ nguyên.' +
          '</div>' +
          '<button type="button" class="btn btn-primary" data-go="loyalty-rewards">Khám phá danh mục ưu đãi</button>' +
        '</div>'
      );
    } else {
      contentHtml = filtered.map(function (item) {
        var meta = statusMeta[item.status] || statusMeta.unused;
        return (
          '<div class="card-solid">' +
            '<div class="row-between" style="margin-bottom:6px;gap:8px;">' +
              '<span style="font-size:11px;font-weight:700;color:var(--text-secondary);">' + esc(item.categoryLabel) + (item.isNewDemo ? ' · Vừa đổi demo' : '') + '</span>' +
              '<span class="pill ' + meta.cls + '">' + esc(meta.label) + '</span>' +
            '</div>' +
            '<div style="font-size:15px;font-weight:800;color:var(--text-primary);margin-bottom:4px;">' + esc(item.title) + '</div>' +
            '<div class="tnum" style="font-size:12px;color:var(--text-secondary);margin-bottom:8px;">Ngày đổi: ' + esc(item.redeemedAt) + ' · Hạn minh họa: ' + esc(item.expiresAt) + '</div>' +
            '<div class="loyalty-rule-callout" style="margin-bottom:' + (item.status === 'unused' ? '10px' : '0') + ';padding:8px 10px;">' +
              ico(item.requiresStaffConfirm ? 'svg/coaching/coach_pkg_1on1.svg' : 'svg/setting/common_info.svg', 'ico-xs', '') +
              '<span style="font-size:12px;color:var(--text-primary);line-height:1.4;">' + esc(item.condition) + '</span>' +
            '</div>' +
            (item.status === 'unused'
              ? '<div class="row-between" style="gap:8px;">' +
                  '<span style="font-size:11px;color:var(--text-secondary);">Chế độ preview: không tạo mã thanh toán thật</span>' +
                  '<button type="button" class="loyalty-inline-action" data-loyalty-action="mark-reward-used" data-uid="' + esc(item.uid) + '">Đánh dấu đã dùng</button>' +
                '</div>'
              : '') +
          '</div>'
        );
      }).join('');
    }

    var body = (
      renderSubHeader('VÍ ƯU ĐÃI DEMO', 'Ưu đãi của tôi',
        '<button type="button" class="pill pill-orange loyalty-pill-link" data-go="loyalty-rewards">+ Đổi thêm</button>'
      ) +
      renderDisclaimerStrip() +
      '<div class="filter-row">' + filterBar + '</div>' +
      contentHtml
    );

    return {
      bodyClass: 'no-nav',
      bodyHtml: body,
      overlaysHtml: ''
    };
  }

  // MÀN 5 — Lịch sử điểm
  function renderScreenHistory(st) {
    var f = st.historyFilter || 'all';
    var filtered = st.history.filter(function (row) {
      if (f === 'earn') return row.points > 0;
      if (f === 'spend') return row.points < 0;
      return true;
    });

    var filterBar = [
      { id: 'all', label: 'Tất cả (' + st.history.length + ')' },
      { id: 'earn', label: 'Cộng điểm' },
      { id: 'spend', label: 'Trừ điểm' }
    ].map(function (tab) {
      return (
        '<button type="button" class="filter-pill loyalty-filter-btn' + (f === tab.id ? ' active' : '') + '" data-loyalty-action="filter-history" data-filter="' + tab.id + '">' +
          esc(tab.label) +
        '</button>'
      );
    }).join('');

    var rowsHtml = '';
    if (filtered.length === 0) {
      rowsHtml = (
        '<div class="card-solid loyalty-empty-box">' +
          ico('svg/states/empty_payments.svg', 'loyalty-empty-img', 'Chưa có lịch sử điểm') +
          '<div style="font-size:16px;font-weight:800;color:var(--text-primary);margin-bottom:4px;">Chưa có giao dịch điểm nào</div>' +
          '<div style="font-size:13px;color:var(--text-secondary);margin-bottom:14px;">Các giao dịch cộng điểm gói tập, trừ điểm đổi ưu đãi hoặc hoàn điểm sẽ hiển thị tại đây.</div>' +
          '<button type="button" class="btn btn-primary" data-go="loyalty-overview">Về Tổng quan gói tập</button>' +
        '</div>'
      );
    } else {
      rowsHtml = filtered.map(function (row) {
        var isPos = row.points > 0;
        var signText = isPos ? ('+' + fmtNum(row.points)) : ('−' + fmtNum(Math.abs(row.points)));
        var ptsColor = row.statusTone === 'info' ? 'var(--info)' : (isPos ? 'var(--success)' : 'var(--primary-text)');
        var pillCls = row.statusTone === 'success' ? 'pill-success' : (row.statusTone === 'warning' ? 'pill-warning' : 'pill-info');
        var iconPath = row.type === 'earn'
          ? 'svg/membership/payment_success.svg'
          : (row.type === 'adjust' ? 'svg/membership/payment_refund_reversal.svg' : 'svg/membership/payment_receipt_invoice.svg');

        return (
          '<div class="card-solid">' +
            '<div class="row-between" style="align-items:flex-start;gap:10px;">' +
              '<div style="display:flex;align-items:flex-start;gap:10px;min-width:0;flex:1;">' +
                '<div class="loyalty-his-ico">' + ico(iconPath, 'ico-sm', row.status) + '</div>' +
                '<div style="min-width:0;flex:1;">' +
                  '<div style="font-size:14px;font-weight:700;color:var(--text-primary);line-height:1.35;">' + esc(row.title) + '</div>' +
                  '<div style="font-size:12px;color:var(--text-secondary);margin-top:2px;line-height:1.4;">' + esc(row.detail) + '</div>' +
                  '<div class="tnum" style="font-size:11px;color:var(--text-secondary);margin-top:4px;">' + esc(row.date) + '</div>' +
                '</div>' +
              '</div>' +
              '<div style="text-align:right;flex-shrink:0;">' +
                '<div class="tnum" style="font-size:15px;font-weight:800;color:' + ptsColor + ';">' + signText + 'đ</div>' +
                '<span class="pill ' + pillCls + '" style="margin-top:4px;">' + esc(row.status) + '</span>' +
              '</div>' +
            '</div>' +
          '</div>'
        );
      }).join('');
    }

    var body = (
      renderSubHeader('BIẾN ĐỘNG META POINTS', 'Lịch sử điểm') +
      renderDisclaimerStrip() +

      '<div class="loyalty-2col" style="margin-bottom:12px;">' +
        '<div class="metric-box">' +
          '<div class="loyalty-metric-lbl">Điểm khả dụng</div>' +
          '<div class="loyalty-metric-val tnum" style="font-size:20px;color:var(--primary-text);">' + fmtNum(st.availablePoints) + 'đ</div>' +
        '</div>' +
        '<div class="metric-box">' +
          '<div class="loyalty-metric-lbl">Điểm xét hạng</div>' +
          '<div class="loyalty-metric-val tnum" style="font-size:20px;">' + fmtNum(st.tierPoints) + 'đ</div>' +
        '</div>' +
      '</div>' +

      '<div class="filter-row">' + filterBar + '</div>' +
      rowsHtml
    );

    return {
      bodyClass: 'no-nav',
      bodyHtml: body,
      overlaysHtml: ''
    };
  }

  /* ------------------------------------------------------------------------
     Screen Registry Export (Integrated with Preview Studio)
     ------------------------------------------------------------------------ */
  function shell(id) {
    return (
      '<div class="phone">' +
        '<div class="phone-bg-photo"></div>' +
        '<div class="phone-scrim"></div>' +
        '<div class="status-bar"><span>18:02</span><div class="notch"></div><span>5G · 92%</span></div>' +
        '<div class="phone-body" data-loyalty-body="' + id + '"></div>' +
        '<div class="loyalty-overlays" data-loyalty-overlays="' + id + '"></div>' +
      '</div>'
    );
  }

  global.METAGYM_SCREENS = global.METAGYM_SCREENS || {};
  global.METAGYM_SCREENS.loyalty = [
    {
      id: 'loyalty-overview',
      group: 'overview',
      groupLabel: '1. Tổng quan',
      title: '1. Tổng quan Gói tập & Meta Points',
      shortFile: 'loyalty/membership_overview_preview',
      flutterFile: 'Preview UI · Loyalty Màn 1 (Tổng quan & 4 gói)',
      tag: 'Màn 1 · Tổng quan',
      tagClass: 'p0',
      html: shell('loyalty-overview')
    },
    {
      id: 'loyalty-rewards',
      group: 'rewards',
      groupLabel: '2–3. Đổi ưu đãi',
      title: '2. Danh mục ưu đãi',
      shortFile: 'loyalty/rewards_catalog_preview',
      flutterFile: 'Preview UI · Loyalty Màn 2 (Danh mục ưu đãi)',
      tag: 'Màn 2 · Ưu đãi',
      tagClass: '',
      html: shell('loyalty-rewards')
    },
    {
      id: 'loyalty-reward-detail',
      group: 'rewards',
      groupLabel: '2–3. Đổi ưu đãi',
      title: '3. Chi tiết & Xác nhận đổi ưu đãi',
      shortFile: 'loyalty/reward_redeem_confirm_preview',
      flutterFile: 'Preview UI · Loyalty Màn 3 (Xác nhận đổi quà)',
      tag: 'Màn 3 · Xác nhận',
      tagClass: 'p0',
      html: shell('loyalty-reward-detail')
    },
    {
      id: 'loyalty-my-rewards',
      group: 'history-wallet',
      groupLabel: '4–5. Ví & Lịch sử',
      title: '4. Ưu đãi của tôi',
      shortFile: 'loyalty/my_rewards_preview',
      flutterFile: 'Preview UI · Loyalty Màn 4 (Ưu đãi đã đổi)',
      tag: 'Màn 4 · Của tôi',
      tagClass: '',
      html: shell('loyalty-my-rewards')
    },
    {
      id: 'loyalty-history',
      group: 'history-wallet',
      groupLabel: '4–5. Ví & Lịch sử',
      title: '5. Lịch sử điểm Meta Points',
      shortFile: 'loyalty/points_history_preview',
      flutterFile: 'Preview UI · Loyalty Màn 5 (Lịch sử điểm)',
      tag: 'Màn 5 · Lịch sử',
      tagClass: '',
      html: shell('loyalty-history')
    }
  ];

  /* ------------------------------------------------------------------------
     Reactive Engine: State Controller, Demo Scenario Bar, Event Wiring
     ------------------------------------------------------------------------ */
  var RENDERERS = {
    'loyalty-overview': renderScreenOverview,
    'loyalty-rewards': renderScreenRewards,
    'loyalty-reward-detail': renderScreenRewardDetail,
    'loyalty-my-rewards': renderScreenMyRewards,
    'loyalty-history': renderScreenHistory
  };

  var state = SCENARIOS[0].build();

  function getStudioToastFn() {
    return typeof global.showFlowToast === 'function' ? global.showFlowToast : function () {};
  }

  function getStudioNavFn() {
    return typeof global.navigateToScreen === 'function' ? global.navigateToScreen : function () {};
  }

  function renderScenarioBar(containerEl) {
    if (!containerEl) return;
    var activeScen = null;
    for (var i = 0; i < SCENARIOS.length; i++) {
      if (SCENARIOS[i].id === state.scenarioId) activeScen = SCENARIOS[i];
    }
    var btns = SCENARIOS.map(function (s) {
      var active = s.id === state.scenarioId;
      return (
        '<button type="button" class="sub-chip loyalty-scen-btn' + (active ? ' active' : '') + '" data-loyalty-action="set-scenario" data-scenario="' + s.id + '">' +
          esc(s.label) +
        '</button>'
      );
    }).join('');

    containerEl.innerHTML = (
      '<div class="loyalty-demo-banner">' +
        '<div class="loyalty-demo-top">' +
          '<div>' +
            '<div class="loyalty-demo-title">Loyalty · Meta Points Preview (Dữ liệu demo tập trung)</div>' +
            '<div class="loyalty-demo-desc">' + esc(activeScen ? activeScen.description : '') + ' · Thay đổi điểm hoặc đổi quà sẽ đồng bộ cả 5 màn hình.</div>' +
          '</div>' +
          '<button type="button" class="ctrl-btn" data-loyalty-action="reset-demo">Đặt lại demo</button>' +
        '</div>' +
        '<div class="loyalty-demo-scenarios">' + btns + '</div>' +
      '</div>'
    );
  }

  function renderAllScreens(rootEl) {
    var root = rootEl || global.document;
    if (!root || !root.querySelectorAll) return;

    var barHost = root.querySelector('[data-loyalty-scenario-bar]');
    if (barHost) renderScenarioBar(barHost);

    var ti = computeTierInfo(state.tierPoints);

    Object.keys(RENDERERS).forEach(function (screenId) {
      var bodyEl = root.querySelector('[data-loyalty-body="' + screenId + '"]');
      var ovEl = root.querySelector('[data-loyalty-overlays="' + screenId + '"]');
      if (!bodyEl || !ovEl) return;

      var prevScroll = bodyEl.scrollTop || 0;
      var out = RENDERERS[screenId](state, ti);
      bodyEl.className = 'phone-body' + (out.bodyClass ? ' ' + out.bodyClass : '');
      bodyEl.innerHTML = out.bodyHtml;
      ovEl.innerHTML = out.overlaysHtml || '';
      bodyEl.scrollTop = prevScroll;
    });
  }

  function performRedeem(rewardId) {
    var rw = findReward(rewardId);
    var rs = getRewardState(rw, state.availablePoints);
    if (!rs.canRedeem) {
      getStudioToastFn()(rs.code === 'short' ? ('Chưa đủ điểm — còn thiếu ' + fmtNum(rs.shortfall) + ' điểm') : 'Ưu đãi này đã hết lượt mẫu');
      return false;
    }
    // Check đủ điểm, trừ Điểm khả dụng đúng 1 lần, giữ nguyên Điểm xét hạng & hạng
    state.availablePoints -= rw.pointsCost;

    var newUid = 'my-demo-' + (state.myRewards.length + 1) + '-' + Date.now();
    state.myRewards.unshift({
      uid: newUid,
      rewardId: rw.id,
      title: rw.title,
      categoryLabel: rw.categoryLabel,
      redeemedAt: '27/11/2026 (Demo)',
      expiresAt: '27/12/2026 (Minh họa)',
      status: 'unused',
      requiresStaffConfirm: !!rw.requiresStaffConfirm,
      condition: rw.requiresStaffConfirm
        ? 'Cần nhân viên tại quầy hoặc Coach xác nhận sử dụng. Bản demo không tự động đặt lịch thật.'
        : 'Ưu đãi minh họa lưu trong ví demo, không phát sinh mã thanh toán thật.',
      isNewDemo: true
    });

    state.history.unshift({
      id: 'his-demo-' + Date.now(),
      type: 'spend',
      title: 'Trừ điểm đổi ưu đãi: ' + rw.title,
      detail: 'Chỉ trừ Điểm khả dụng · Giữ nguyên Điểm xét hạng',
      date: '27/11/2026 · Vừa xong (Demo)',
      points: -rw.pointsCost,
      status: 'Đã đổi demo',
      statusTone: 'warning'
    });

    state.redeemSuccessNotice = {
      rewardId: rw.id,
      cost: rw.pointsCost
    };
    getStudioToastFn()('Đã trừ ' + fmtNum(rw.pointsCost) + ' điểm khả dụng · Còn ' + fmtNum(state.availablePoints) + ' điểm');
    return true;
  }

  function setScenario(scenarioId) {
    for (var i = 0; i < SCENARIOS.length; i++) {
      if (SCENARIOS[i].id === scenarioId) {
        state = SCENARIOS[i].build();
        return state;
      }
    }
    return state;
  }

  var isWired = false;
  function wireEvents(rootEl) {
    if (isWired || !global.document) return;
    isWired = true;

    global.document.addEventListener('click', function (e) {
      var actEl = e.target.closest ? e.target.closest('[data-loyalty-action]') : null;
      if (!actEl) return;

      var action = actEl.getAttribute('data-loyalty-action');
      // Only backdrop close if clicked strictly on overlay backdrop
      if (action === 'close-package-backdrop' && e.target !== actEl) return;

      e.stopPropagation();
      var docRoot = global.document;

      if (action === 'set-scenario') {
        var scenId = actEl.getAttribute('data-scenario');
        setScenario(scenId);
        renderAllScreens(docRoot);
        getStudioToastFn()('Đã chuyển kịch bản demo: ' + (actEl.textContent || scenId).trim());
        return;
      }

      if (action === 'reset-demo') {
        setScenario('default');
        renderAllScreens(docRoot);
        getStudioToastFn()('Đã đặt lại dữ liệu demo Loyalty mặc định');
        return;
      }

      if (action === 'filter-rewards') {
        state.rewardCategoryFilter = actEl.getAttribute('data-filter') || 'all';
        renderAllScreens(docRoot);
        return;
      }

      if (action === 'open-reward') {
        var rwId = actEl.getAttribute('data-reward-id');
        state.selectedRewardId = rwId;
        state.redeemSuccessNotice = null;
        renderAllScreens(docRoot);
        getStudioNavFn()('loyalty-reward-detail');
        return;
      }

      if (action === 'select-reward-only') {
        state.selectedRewardId = actEl.getAttribute('data-reward-id');
        state.redeemSuccessNotice = null;
        renderAllScreens(docRoot);
        return;
      }

      if (action === 'confirm-redeem') {
        if (actEl.disabled) return;
        var targetRwId = actEl.getAttribute('data-reward-id') || state.selectedRewardId;
        if (performRedeem(targetRwId)) {
          renderAllScreens(docRoot);
        }
        return;
      }

      if (action === 'filter-my-rewards') {
        state.myRewardsFilter = actEl.getAttribute('data-filter') || 'all';
        renderAllScreens(docRoot);
        return;
      }

      if (action === 'mark-reward-used') {
        var uid = actEl.getAttribute('data-uid');
        state.myRewards.forEach(function (it) {
          if (it.uid === uid) it.status = 'used';
        });
        renderAllScreens(docRoot);
        getStudioToastFn()('Đã chuyển trạng thái ưu đãi sang Đã sử dụng (Demo)');
        return;
      }

      if (action === 'filter-history') {
        state.historyFilter = actEl.getAttribute('data-filter') || 'all';
        renderAllScreens(docRoot);
        return;
      }

      if (action === 'open-package') {
        state.selectedPackageId = actEl.getAttribute('data-pkg-id');
        renderAllScreens(docRoot);
        return;
      }

      if (action === 'close-package' || action === 'close-package-backdrop') {
        state.selectedPackageId = null;
        renderAllScreens(docRoot);
        return;
      }

      if (action === 'reset-scroll') {
        var phoneBody = actEl.closest('.phone')?.querySelector('.phone-body');
        if (phoneBody) phoneBody.scrollTo({ top: 0, behavior: 'smooth' });
      }
    });
  }

  function initMetaGymLoyalty(rootEl) {
    var docRoot = rootEl || global.document;
    var panel = docRoot && docRoot.querySelector ? docRoot.querySelector('.tab-panel[data-panel="loyalty"]') : null;
    if (panel && !panel.querySelector('[data-loyalty-scenario-bar]')) {
      var bar = docRoot.createElement('div');
      bar.className = 'loyalty-scenario-wrap';
      bar.setAttribute('data-loyalty-scenario-bar', '');
      panel.insertBefore(bar, panel.firstChild);
    }
    renderAllScreens(docRoot);
    wireEvents(docRoot);
  }

  global.METAGYM_LOYALTY_DEMO = {
    TIERS: TIERS,
    PACKAGES: PACKAGES,
    REWARDS: REWARDS,
    SCENARIOS: SCENARIOS,
    computeTierInfo: computeTierInfo,
    getRewardState: getRewardState,
    getState: function () { return state; },
    setScenario: setScenario,
    performRedeem: performRedeem,
    renderAll: renderAllScreens,
    init: initMetaGymLoyalty
  };
  global.initMetaGymLoyalty = initMetaGymLoyalty;
})(typeof window !== 'undefined' ? window : globalThis);
