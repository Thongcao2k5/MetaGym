// Ghi chú — Danh sách yêu cầu & hành vi cần có trong ứng dụng Flutter Meta Gym
// Mỗi mục hỗ trợ:
// - title: Tiêu đề gạch đầu dòng ngắn gọn
// - summary: Mô tả dễ hiểu cho người dùng & team
// - details: Các ý diễn giải hành vi chi tiết (mảng chuỗi)
// - techStack: Gợi ý công nghệ / kiến trúc triển khai (mảng { name, note, status? })
window.METAGYM_NOTES = [
  {
    id: 'core-app-requirements',
    title: 'Yêu cầu chung của ứng dụng',
    subtitle: 'Các tính năng, hành vi hệ thống và trải nghiệm cốt lõi cần đáp ứng xuyên suốt app Flutter',
    tag: 'Core',
    items: [
      {
        title: 'Sử dụng Online / Offline mượt mà (Offline-First)',
        summary: 'Người dùng vẫn xem được lịch tập, giáo trình, thực đơn và ghi nhật ký tập ngay cả khi phòng gym mất sóng hoặc Wi-Fi chập chờn; tự động đồng bộ khi có mạng trở lại.',
        details: [
          'Khi mất kết nối, app không văng màn hình lỗi trắng mà hiển thị dữ liệu đã lưu gần nhất kèm thanh thông báo trạng thái Offline gọn nhẹ.',
          'Các thao tác ghi nhận mới (check-in buổi tập, ghi mức tạ/số rep, nhật ký dinh dưỡng) được lưu tạm an toàn trên máy vào hàng đợi chờ đồng bộ.',
          'Ngay khi thiết bị có Internet trở lại, hệ thống tự động đồng bộ ngầm lên máy chủ và cập nhật dữ liệu mới nhất mà không làm gián đoạn thao tác.',
          'Các chức năng bắt buộc trực tuyến (đặt lịch Coach mới, thanh toán, gọi video, chat AI) hiển thị rõ trạng thái tạm khóa kèm hướng dẫn thử lại khi có mạng.'
        ],
        techStack: [
          {
            name: 'connectivity_plus + Dio Interceptor',
            status: 'Đã có trong pubspec',
            note: 'Lắng nghe thay đổi Wi-Fi/4G thời gian thực và kiểm tra kết nối Internet thật qua tầng Dio (tránh trường hợp có sóng Wi-Fi nhưng không có mạng).'
          },
          {
            name: 'Drift (SQLite) hoặc Isar / Sqflite',
            status: 'Đề xuất bổ sung',
            note: 'Lưu trữ dữ liệu có cấu trúc cục bộ (giáo trình, lịch tập, nhật ký tập) và bảng sync_queue để giữ các bản ghi chưa đẩy lên server.'
          },
          {
            name: 'dio_cache_interceptor + cached_network_image',
            status: 'Đề xuất bổ sung',
            note: 'Áp dụng chiến lược Stale-While-Revalidate (hiển thị cache tức thì rồi âm thầm tải mới) và lưu cache ảnh bài tập/avatar.'
          },
          {
            name: 'Outbox Sync Queue + Exponential Backoff',
            status: 'Kiến trúc đề xuất',
            note: 'Quản lý trạng thái bản ghi (pending → syncing → synced), tự động thử lại giãn cách khi lỗi mạng và đối chiếu mốc updated_at để tránh ghi đè dữ liệu.'
          }
        ]
      },
      {
        title: 'Vuốt từ trên xuống nhiều lần để Loading lại dữ liệu (Pull-to-Refresh an toàn)',
        summary: 'Cho phép kéo từ trên xuống để làm mới dữ liệu ở mọi màn hình danh sách/tổng quan; xử lý chống spam request, không giật lag và không mất dữ liệu cũ khi vuốt liên tục.',
        details: [
          'Mọi màn hình có dữ liệu động (Trang chủ, Lịch tập, Dinh dưỡng, Nhật ký, Tin nhắn, Gói tập...) đều hỗ trợ thao tác vuốt từ trên xuống để tải lại.',
          'Khi người dùng vuốt liên tục nhiều lần trong thời gian ngắn, app gom/khóa yêu cầu đang chạy (không bắn trùng hàng loạt API gây nghẽn hoặc race condition ghi đè dữ liệu cũ).',
          'Trong lúc đang tải lại, vẫn giữ nguyên dữ liệu hiện tại trên màn hình thay vì xóa trắng thành skeleton; khi xong thì cập nhật mượt mà kèm phản hồi rung nhẹ.',
          'Vẫn cho phép kéo xuống làm mới ngay cả khi danh sách đang trống (Empty State) hoặc vừa gặp lỗi mạng (Error State) để người dùng chủ động thử lại.'
        ],
        techStack: [
          {
            name: 'RefreshIndicator.adaptive + AlwaysScrollableScrollPhysics',
            status: 'Có sẵn trong Flutter',
            note: 'Hiển thị vòng xoay chuẩn theo từng hệ điều hành (iOS/Android) và đảm bảo luôn kéo được kể cả khi nội dung ít hơn chiều cao màn hình.'
          },
          {
            name: 'Single-Flight Future Lock (Provider / ChangeNotifier)',
            status: 'Đã có Provider',
            note: 'Giữ biến _inFlightRefresh (Future<void>?): nếu người dùng kéo nhiều lần liên tiếp khi request trước chưa xong thì chờ chung một Future, kết hợp cooldown nhẹ 1.5–2 giây.'
          },
          {
            name: 'Dio CancelToken',
            status: 'Đã có trong pubspec',
            note: 'Hủy các request lỗi thời khi người dùng chuyển tab/thoát màn hình, tránh lỗi cập nhật state sau khi widget đã dispose.'
          },
          {
            name: 'HapticFeedback + Non-destructive Refresh',
            status: 'UX Best Practice',
            note: 'Rung nhẹ (HapticFeedback.lightImpact) khi kích hoạt tải lại; báo SnackBar gọn nếu đang Offline thay vì xóa dữ liệu đang hiển thị.'
          }
        ]
      },
      {
        title: 'Chế độ Sáng / Tối tự động theo cài đặt của máy (System Theme)',
        summary: 'Ứng dụng tự động chuyển giao diện Sáng hoặc Tối theo thiết lập hệ thống (iOS / Android) và vẫn cho phép người dùng chủ động chọn cố định (Theo máy · Tối · Sáng) trong Cài đặt.',
        details: [
          'Mặc định khi cài mới, app nhận diện tự động chế độ Sáng/Tối hiện tại của điện thoại (VD: tự chuyển Tối khi máy bật lịch Dark Mode buổi tối).',
          'Trong màn Cài đặt ứng dụng (5.13), cung cấp 3 tùy chọn rõ ràng: Theo thiết bị (Mặc định) · Luôn Tối · Luôn Sáng và lưu lại lựa chọn cho các lần mở sau.',
          'Khi người dùng đổi giao diện trong Control Center / Cài đặt máy mà app đang mở, toàn bộ màn hình, Modal, Bottom Sheet, Toast và thanh trạng thái (Status Bar) cập nhật ngay lập tức mà không cần khởi động lại app.',
          'Đồng bộ màu biểu tượng thanh trạng thái (SystemUiOverlayStyle: chữ/icon tối khi nền sáng, chữ/icon sáng khi nền tối) và bộ icon SVG thích ứng trên cả 2 nền.'
        ],
        techStack: [
          {
            name: 'MaterialApp (themeMode: ThemeMode.system)',
            status: 'Có sẵn trong Flutter',
            note: 'Khai báo song song theme (Light) và darkTheme (Dark) cùng ThemeMode.system để Flutter tự lắng nghe MediaQuery.platformBrightnessOf(context) theo thời gian thực.'
          },
          {
            name: 'ThemeProvider (ChangeNotifier) + shared_preferences',
            status: 'Đã có Provider',
            note: 'Quản lý 3 trạng thái ThemeMode (system / dark / light), lưu lựa chọn cục bộ để giữ nguyên khi mở lại app.'
          },
          {
            name: 'AnnotatedRegion<SystemUiOverlayStyle>',
            status: 'Có sẵn trong Flutter',
            note: 'Tự động đổi màu chữ giờ/pin trên Status Bar và thanh điều hướng Android khớp với nền Sáng/Tối của từng màn hình.'
          },
          {
            name: 'ThemeExtension<MetaGymColors>',
            status: 'Kiến trúc đề xuất',
            note: 'Định nghĩa toàn bộ token màu Sáng/Tối (surface, border, semantic, glass) tại một nơi duy nhất để mọi màn hình, Modal và Toast tự đổi màu không cần if/else rải rác.'
          }
        ]
      },
      {
        title: 'Thang Cỡ Chữ Chuẩn Mobile — 8 Bậc Số Nguyên (Be Vietnam Pro)',
        summary: 'Chuẩn hóa toàn bộ ứng dụng về đúng 8 bậc cỡ chữ số nguyên (11 / 12 / 14 / 15 / 16 / 20 / 22 / 28px), xóa hoàn toàn cỡ < 11px và số lẻ .5px để Tiếng Việt có dấu kép đọc sắc nét trên màn 375–393px.',
        details: [
          'Micro (11px · w700): Sàn tuyệt đối, chỉ dùng cho nhãn in hoa giãn chữ (.mg-eyebrow: META GYM), badge số thông báo (2, 3), ngày ngắn (T2–CN), vạch thước đo và nhãn phụ cực gọn. Cấm dùng cỡ < 11px.',
          'Label / Metadata (12px · w500–600): Sàn đọc chuẩn cho Tiếng Việt có dấu (.txt-xs, nhãn 4 ô Dock, pill trạng thái, label form, giờ tin nhắn, chỉ số phụ).',
          'Body Chuẩn (14px · w400–600): Nội dung đọc chính trên thẻ (.txt-sm), ô nhập liệu (Input), bong bóng Chat AI/Coach, nút phụ (.btn-secondary), danh sách bài tập.',
          'Body Lớn / CTA (15px · w400/700): Nút hành động chính (.btn-primary), nội dung bài viết / hướng dẫn tập luyện.',
          'Tiêu đề Mục & Thẻ (16px · w700): Tiêu đề mục (.sec-head h3) và tiêu đề thẻ nổi bật.',
          'Tiêu đề Màn hình (20px · w700): Tiêu đề AppBar (.mg-title), kết hợp maxLines: 1 + TextOverflow.ellipsis.',
          'Headline (22px · w800) & KPI Data (28px · w700–800 · tnum): Tiêu đề chào mừng Auth / Hero và chỉ số KPI lớn (42 ngày, 1.840 kcal, giá gói tập — bắt buộc bật FontFeature.tabularFigures()).'
        ],
        techStack: [
          {
            name: 'TextTheme trong MetaGymTheme (app_theme.dart)',
            status: 'Đã có nền tảng',
            note: 'Map trực tiếp 8 bậc vào labelSmall(11), labelMedium(12), bodyMedium(14), bodyLarge(15), titleMedium(16), titleLarge(20), headlineSmall(22), displaySmall(28) kèm fontFamily Be Vietnam Pro.'
          },
          {
            name: 'FontFeature.tabularFigures() (tnum)',
            status: 'Đã có trong MetaGymTheme',
            note: 'Áp dụng cho mọi số liệu đếm (calo, macro, số ngày còn lại, giá VNĐ, giờ hẹn, đồng hồ nghỉ) để cột số không bị rung lệch khi thay đổi.'
          },
          {
            name: 'MediaQuery.textScalerOf(context) + maxLines',
            status: 'Có sẵn trong Flutter',
            note: 'Hỗ trợ phóng to cỡ chữ hệ thống (Dynamic Type) mà không gây lỗi RenderFlex overflow nhờ Expanded/Flexible và ellipsis trên các thẻ 2 cột / Quick Dock ở 375px.'
          }
        ]
      },
      {
        title: 'Đồng bộ Khung Quang Học Icon SVG (82% Live Area · 20 / 24 / 29 / 34 / 38px)',
        summary: 'Toàn bộ 293 icon UI SVG đã được chuẩn hóa viewBox để hình vẽ chiếm đúng 82% khung vuông và căn tâm tuyệt đối; toàn bộ nhóm icon điều khiển được phóng lớn nổi bật, dễ bấm trên điện thoại.',
        details: [
          'Chuẩn hóa viewBox 293 tệp .svg (từ tình trạng lệch 52%–87.5% trước đây về đồng đều 81.3%–82.8%, tâm 50%/50%) mà không làm hỏng gradient hay độ dày nét.',
          'Thống nhất 5 mức khung chuẩn: 20px (.ico-xs · badge/pill), 24px (.ico-sm · tiêu đề mục/input/row), 29px (.ico-md · nút tròn điều khiển 46×46dp trên Header), 34px (.nav-svg & QR · thanh Bottom Navigation 64px), 38px (.ico-lg, .ico-dock & .nav-ai-svg · Quick Dock 4 ô & nút AI 56×56dp trung tâm).'
        ],
        techStack: [
          {
            name: 'flutter_svg (SvgPicture.asset với hằng số kích cỡ chuẩn)',
            status: 'Đã có trong pubspec',
            note: 'Dev truyền đúng bộ hằng số 20 / 24 / 29 / 34 / 38 (dp) — toàn bộ icon điều khiển hiển thị to rõ, đồng đều nhau mà không cần cộng trừ padding thủ công.'
          }
        ]
      },
      {
        title: 'Bảo vệ Chân Màn Hình (Bottom Safe Area & Khoảng Thở Đáy)',
        summary: 'Mọi màn hình, thanh điều hướng đáy, thanh nút CTA ghim đáy, ô nhập tin nhắn và Bottom Sheet đều bắt buộc chừa khoảng đệm an toàn phía trên thanh vuốt Home Indicator / thanh điều hướng Android.',
        details: [
          'Màn hình không có Bottom Nav (Chi tiết, Thanh toán, Auth, Pháp lý): luôn có khoảng đệm đáy tối thiểu 48px (34px vùng Home Indicator + 14px khoảng thở) để thẻ cuối cùng không bao giờ dính sát mép màn hình.',
          'Thanh điều hướng đáy (Bottom Navigation nổi): đặt cách chân màn hình tối thiểu 24px (cao hơn hẳn thanh Home Indicator) và danh sách cuộn bên dưới chừa padding-bottom 132px để nội dung cuối cuộn lên thoáng hoàn toàn.',
          'Thanh nút CTA ghim đáy & Ô nhập Chat (.bottom-cta-dock): luôn có padding-bottom tối thiểu 34px (kèm MediaQuery.viewInsets.bottom khi bàn phím ảo bật lên), danh sách phía trên chừa 118px.',
          'Khung nhập Chat AI phía trên Bottom Nav đặt cách đáy 96px, nội dung hội thoại chừa 206px để không bao giờ bị che tin nhắn cuối.'
        ],
        techStack: [
          {
            name: 'SafeArea(top: false, bottom: true) + MediaQuery.viewPaddingOf(context)',
            status: 'Có sẵn trong Flutter',
            note: 'Bọc mọi thanh CTA ghim đáy, BottomSheet và dùng viewPadding.bottom + 16–24dp làm khoảng đệm tối thiểu cho mọi ListView/SingleChildScrollView.'
          },
          {
            name: 'MetaGymBottomNav.contentBottomPadding(context)',
            status: 'Đã có trong core widgets',
            note: 'Tái sử dụng helper chuẩn trên toàn bộ màn hình có Bottom Nav (Member & Coach) để đảm bảo phần tử cuối không bao giờ lấp sau thanh điều hướng.'
          }
        ]
      },
      {
        title: 'Linh vật Thương hiệu Meta Kong (Studio WebP Nền Trong Suốt)',
        summary: 'Bộ 6 tư thế linh vật Meta Kong (Hero, Empty, Offline, Error, Loading, Streak) xuất ở định dạng 512×512 Transparent WebP (38–56 KB/tệp) hiển thị sắc nét trên cả Dark Mode và Light Mode.',
        details: [
          'Sử dụng ảnh Transparent WebP trong design-system/meta-gym/assets/images/mascot/ thay cho vector 2D để giữ trọn khối cơ bắp, biểu cảm thân thiện và ánh sáng viền Cool Rim Light #A9C7E8.',
          'Gắn điểm nhấn có tiết chế vào các điểm chạm giàu cảm xúc: Màn hình Trạng thái Hệ thống (Empty / Offline / Error / Loading / Streak), Banner cổ vũ chuỗi ngày tập trên Trang chủ (1.1), Màn Chọn gói tập trống (1.2b), Trợ lý AI (3.1) và lời chào Đăng nhập (Auth).',
          'Khi thiết kế thêm tư thế mới, dùng script tách nền chuẩn scripts/cutout_mascot.js để đồng bộ viền sạch, tỉ lệ khung 89.8% và cập nhật bảng tổng quan Dark + Light.'
        ],
        techStack: [
          {
            name: 'Image.asset (Transparent WebP 512×512)',
            status: 'Có sẵn trong Flutter',
            note: 'Nạp trực tiếp assets/images/mascot/meta_kong_*.webp (38–56 KB), không áp ColorFilter đảo màu ở Light Mode; đề xuất 136–164dp cho Modal/Empty toàn trang và 48–78dp cho Banner gọn.'
          }
        ]
      }
    ]
  }
];
