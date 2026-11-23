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
      }
    ]
  }
];
