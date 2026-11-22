export const NAV_LINKS = [
  { href: '#zones', label: 'CLB' },
  { href: '#services', label: 'Dịch vụ' },
  { href: '#plans', label: 'Chính sách giá' },
  { href: '#news', label: 'Tin tức' },
  { href: '#trial-section', label: 'MetaRewards' },
];

// TODO (Team): Cập nhật danh sách tin tức / sự kiện thực tế tại đây
export const NEWS_SKELETON = [
  {
    tag: 'Sự kiện CLB',
    date: 'Sắp diễn ra',
    title: 'Workshop Kỹ thuật Squat & Deadlift chuẩn cùng Coach',
    excerpt: 'Khung bài viết mẫu để thành viên nhóm bổ sung nội dung chi tiết hoặc liên kết trang Tin tức.',
  },
  {
    tag: 'Dinh dưỡng',
    date: 'Cẩm nang',
    title: 'Hướng dẫn tính Macro giảm mỡ bền vững cho người mới',
    excerpt: 'Khung bài viết mẫu — có thể mở rộng thành trang chi tiết bài viết (/tin-tuc) khi chia task.',
  },
  {
    tag: 'Ưu đãi',
    date: 'MetaRewards',
    title: 'Tích điểm check-in QR đổi quyền lợi hội viên Meta Gym',
    excerpt: 'Khung giới thiệu chương trình tích điểm khách hàng thân thiết để team phát triển thêm.',
  },
];

// TODO (Team): Liên kết các trang chính sách & danh mục con khi hoàn thiện
export const FOOTER_DISCOVER_LINKS = [
  { href: '#zones', label: 'CLB' },
  { href: '#services', label: 'Dịch vụ' },
  { href: '#plans', label: 'Chính sách giá' },
  { href: '#news', label: 'Tin tức' },
  { href: '#trial-section', label: 'MetaRewards' },
];

export const FOOTER_POLICY_LINKS = [
  { href: '#services', label: 'Dịch vụ' },
  { href: '#plans', label: 'Phương thức thanh toán' },
  { href: '#faq', label: 'Chính sách bảo vệ thông tin người dùng' },
  { href: '#faq', label: 'Quy trình giải quyết, tiếp nhận khiếu nại' },
  { href: '#trial-section', label: 'Mẫu hợp đồng, chính sách và tài liệu khác' },
  { href: '#trial-section', label: 'Liên hệ' },
];

export const HERO_METRICS = [
  { value: '05:30 – 22:00', label: 'Mở cửa mỗi ngày, kể cả cuối tuần' },
  { value: '< 1 giây', label: 'Check-in QR không cần thẻ cứng' },
  { value: 'Tối đa 8', label: 'Học viên / Coach để theo sát 1-1' },
];

export const FREE_AMENITIES = [
  { title: 'Tủ đồ Locker cá nhân', detail: 'An toàn, tiện lợi mỗi buổi tập' },
  { title: 'Phòng tắm nước nóng', detail: 'Sạch sẽ, tách biệt nam/nữ' },
  { title: 'Gửi xe & Wi-Fi miễn phí', detail: 'Không phát sinh phụ phí' },
  { title: 'Check-in QR 1 giây', detail: 'Vào cửa nhanh qua ứng dụng' },
];

export const TRAINING_ZONES = [
  {
    id: 'strength',
    title: 'Khu Tạ tự do & Strength',
    badge: 'Free Weights',
    image: '/images/zone-strength.jpg',
    imageAlt: 'Khu vực tạ tự do và giàn Squat Rack hiện đại tại Meta Gym',
    icon: 'dumbbell',
    accent: 'primary',
    description:
      'Trang bị đầy đủ giàn Squat Rack, Bench Press, tạ đơn và máy tập khối cơ chuyên biệt, giúp bạn phát triển sức mạnh an toàn và hiệu quả.',
    points: [
      'Thảm sàn cao su giảm chấn tiêu chuẩn phòng tập chuyên nghiệp',
      'Hệ thống máy tập tách nhóm cơ rõ ràng cho người mới lẫn vận động viên',
      'Quét mã xem hướng dẫn kỹ thuật động tác ngay trên ứng dụng Meta Gym',
    ],
  },
  {
    id: 'cardio',
    title: 'Khu Cardio & Functional',
    badge: 'Đốt mỡ & Sức bền',
    image: '/images/zone-cardio.jpg',
    imageAlt: 'Khu vực máy chạy bộ Cardio và thảm tập Functional tại Meta Gym',
    icon: 'chartLine',
    accent: 'info',
    description:
      'Không gian thoáng đãng với máy chạy bộ, máy chèo thuyền và khu vực tập chức năng (Functional) cho các bài HIIT, Core và Mobility.',
    points: [
      'Theo dõi nhịp tim, lượng calo tiêu thụ và thời lượng buổi tập',
      'Không gian tập linh hoạt cho giảm mỡ, cải thiện tim mạch và dẻo dai',
      'Phù hợp cả buổi tập nhanh 30 phút sau giờ làm việc',
    ],
  },
  {
    id: 'pt-zone',
    title: 'Khu Huấn luyện 1-1 & Phục hồi',
    badge: 'Private Coaching',
    image: '/images/pt-coaching.jpg',
    imageAlt: 'Huấn luyện viên Meta Gym đang hướng dẫn hội viên tập tạ 1-1',
    icon: 'award',
    accent: 'coach',
    description:
      'Không gian tối ưu cho các buổi tập 1-1 cùng Huấn luyện viên cá nhân, đánh giá thể trạng định kỳ và hướng dẫn kỹ thuật chuẩn xác.',
    points: [
      'Mỗi Coach chỉ đồng hành tối đa 8 học viên để đảm bảo theo sát',
      'Đo lường tiến độ, điều chỉnh mức tạ và tư thế từng buổi tập',
      'Kết nối nhắn tin, gọi video chỉnh form qua ứng dụng Meta Gym',
    ],
  },
];

export const SERVICE_TABS = [
  {
    id: 'gym-floor',
    label: 'Tập luyện tự do',
    icon: 'dumbbell',
    eyebrow: 'Membership',
    title: 'Chủ động lịch tập với thiết bị chuẩn & giáo án gợi ý',
    description:
      'Dù bạn là người mới bắt đầu hay đã tập luyện lâu năm, Meta Gym cung cấp thư viện bài tập chi tiết theo từng thiết bị có sẵn tại phòng, giúp bạn không còn bỡ ngỡ khi tự tập.',
    highlights: [
      'Lịch sử tập luyện, mức tạ và số hiệp được lưu gọn trên ứng dụng',
      'Gợi ý bài tập theo nhóm cơ và thiết bị đang có tại phòng tập',
      'Check-in nhanh gọn mọi khung giờ mở cửa từ 05:30 đến 22:00',
    ],
    preview: {
      header: 'Lịch tập hôm nay · Hội viên',
      status: 'Đang hiệu lực',
      statusTone: 'success',
      rows: [
        { k: 'Buổi tập', v: 'Upper Body · Ngực, Vai, Tay sau' },
        { k: 'Thời lượng dự kiến', v: '55 phút · 5 bài tập' },
        { k: 'Check-in tại quầy', v: '07:15 · Cổng chính Meta Gym' },
      ],
    },
  },
  {
    id: 'pt-1on1',
    label: 'Huấn luyện 1-1 (PT)',
    icon: 'award',
    eyebrow: 'Personal Training',
    title: 'Theo sát từng buổi tập với giới hạn tối đa 8 học viên / Coach',
    description:
      'Tại Meta Gym, mỗi Huấn luyện viên chỉ đồng hành cùng tối đa 8 học viên để đảm bảo từng người đều được thiết kế giáo án riêng, chỉnh sửa tư thế chuẩn xác và nhắc nhở đều đặn.',
    highlights: [
      'Đánh giá thể trạng & mục tiêu cá nhân (Tăng cơ, Giảm mỡ, Cải thiện vóc dáng)',
      'Đặt lịch tập trực tiếp với Coach và nhắn tin trao đổi mọi lúc',
      'Hỗ trợ gọi video 1-1 chỉnh kỹ thuật động tác khi bạn tập ở nhà hoặc đi công tác',
    ],
    preview: {
      header: 'Đồng hành cùng Coach',
      status: 'Còn 2 suất nhận mới',
      statusTone: 'info',
      rows: [
        { k: 'Huấn luyện viên', v: 'Lê Hoàng Nam (LN)' },
        { k: 'Chuyên môn', v: 'Tăng cơ & Sức mạnh nền tảng' },
        { k: 'Số học viên hiện tại', v: '6 / 8 học viên' },
      ],
    },
  },
  {
    id: 'nutrition',
    label: 'Dinh dưỡng & Tiến độ',
    icon: 'chartLine',
    eyebrow: '70% Kết quả từ Dinh dưỡng',
    title: 'Kiểm soát Calo, Macro và sự thay đổi cơ thể mỗi tuần',
    description:
      'Không cần ghi chép thủ công phức tạp. Bạn có thể tra cứu nhanh lượng calo, đạm, tinh bột, chất béo của từng món ăn Việt Nam và theo dõi biểu đồ tiến độ trực quan ngay trên điện thoại.',
    highlights: [
      'Danh mục thực phẩm phong phú, dễ tra cứu theo khẩu phần hằng ngày',
      'Theo dõi tiến độ cân nặng, số đo và chuỗi ngày hoàn thành mục tiêu',
      'Dữ liệu sức khỏe cá nhân được bảo mật riêng tư giữa bạn và Coach',
    ],
    preview: {
      header: 'Tổng kết Dinh dưỡng ngày',
      status: 'Đạt 86% mục tiêu',
      statusTone: 'success',
      rows: [
        { k: 'Năng lượng đã nạp', v: '1.980 / 2.300 kcal' },
        { k: 'Lượng đạm (Protein)', v: '148g / 160g' },
        { k: 'Chuỗi duy trì', v: '12 ngày liên tiếp' },
      ],
    },
  },
  {
    id: 'ai-coach',
    label: 'Trợ lý AI Coach 24/7',
    icon: 'sparkle',
    eyebrow: 'Hỗ trợ thông minh',
    title: 'Giải đáp kỹ thuật tập luyện & dinh dưỡng bất cứ lúc nào',
    description:
      'Khi bạn cần tìm bài tập thay thế nếu máy đang bận, hoặc thắc mắc về thực đơn sau buổi tập khuya, Trợ lý AI Coach tích hợp sẵn trên ứng dụng Meta Gym luôn sẵn sàng phản hồi ngay lập tức.',
    highlights: [
      'Gợi ý bài tập thay thế phù hợp với nhóm cơ đang tập',
      'Giải thích lỗi sai thường gặp và cách hít thở đúng kỹ thuật',
      'Hỗ trợ song hành cùng Huấn luyện viên cá nhân của bạn',
    ],
    preview: {
      header: 'Trợ lý AI Meta Gym',
      status: 'Trực tuyến 24/7',
      statusTone: 'success',
      rows: [
        { k: 'Câu hỏi gần nhất', v: 'Thay thế bài Barbell Row khi hết ghế?' },
        { k: 'Gợi ý tức thì', v: 'Chest-Supported Dumbbell Row · 4×10' },
        { k: 'Lưu ý kỹ thuật', v: 'Giữ lưng trung tính, siết bả vai 1 giây' },
      ],
    },
  },
];

export const COACH_TEAM = [
  {
    initials: 'LN',
    name: 'Lê Hoàng Nam',
    specialty: 'Hypertrophy & Sức mạnh nền tảng',
    slots: '6/8 học viên',
    isPrimaryCoach: true,
    bio: '6 năm kinh nghiệm huấn luyện tăng cơ, chỉnh sửa tư thế cột sống và xây dựng lộ trình cho dân văn phòng.',
    tags: ['Tăng cơ', 'Sức mạnh', 'Kỹ thuật tạ'],
  },
  {
    initials: 'MT',
    name: 'Nguyễn Minh Tuấn',
    specialty: 'Giảm mỡ & Conditioning',
    slots: '5/8 học viên',
    isPrimaryCoach: false,
    bio: 'Chuyên gia thiết kế lộ trình đốt mỡ bền vững kết hợp Cardio và tập kháng lực không gây mất cơ.',
    tags: ['Giảm mỡ', 'HIIT', 'Thể lực'],
  },
  {
    initials: 'HA',
    name: 'Trần Hải Anh',
    specialty: 'Body Recomposition & Dinh dưỡng',
    slots: '7/8 học viên',
    isPrimaryCoach: false,
    bio: 'Đồng hành xây dựng vóc dáng cân đối cho nữ giới, kết hợp thực đơn linh hoạt phù hợp thói quen ăn uống Việt.',
    tags: ['Vóc dáng nữ', 'Dinh dưỡng', 'Mobility'],
  },
];

export const GYM_PLANS = [
  {
    name: 'Basic Gym',
    price: '490.000 ₫',
    period: '/ tháng',
    summary: 'Dành cho bạn muốn chủ động tập luyện toàn thời gian với đầy đủ thiết bị chuẩn.',
    featured: false,
    cta: 'Đăng ký gói Basic',
    features: [
      'Tập luyện không giới hạn khung giờ 05:30 – 22:00',
      'Check-in QR nhanh chóng bằng ứng dụng Meta Gym',
      'Miễn phí tủ đồ cá nhân, phòng tắm nước nóng & gửi xe',
      'Truy cập thư viện hướng dẫn bài tập cơ bản',
    ],
  },
  {
    name: 'Pro + Dinh dưỡng & AI',
    price: '790.000 ₫',
    period: '/ tháng',
    summary: 'Gói hội viên được yêu thích nhất: kết hợp không gian tập chuẩn và công cụ theo dõi thông minh.',
    featured: true,
    badge: 'Phổ biến nhất',
    cta: 'Đăng ký gói Pro',
    features: [
      'Toàn bộ quyền lợi của gói Basic Gym',
      'Mở khóa Trợ lý AI Coach gợi ý lịch tập 24/7',
      'Nhật ký dinh dưỡng, tính Calo & Macro tự động',
      'Biểu đồ theo dõi tiến độ sức mạnh & vóc dáng',
    ],
  },
  {
    name: 'Gói 3 Tháng Tiết Kiệm',
    price: '1.990.000 ₫',
    period: '/ 3 tháng',
    summary: 'Cam kết lộ trình 90 ngày thay đổi vóc dáng với mức chi phí tối ưu hơn 16%.',
    featured: false,
    cta: 'Chọn gói 3 tháng',
    features: [
      'Toàn bộ quyền lợi của gói Pro + Dinh dưỡng & AI',
      '1 buổi đánh giá thể trạng đầu vào cùng Coach',
      'Thanh toán linh hoạt VNPay, MoMo, ZaloPay',
      'Ưu tiên giữ suất khi nâng cấp lên gói PT 1-1',
    ],
  },
];

export const PT_PLANS = [
  {
    name: 'PT Khởi Động (12 Buổi)',
    price: '3.600.000 ₫',
    period: '/ 12 buổi',
    summary: 'Phù hợp cho người mới bắt đầu cần học kỹ thuật chuẩn, tránh chấn thương và tạo thói quen.',
    featured: false,
    cta: 'Tư vấn gói 12 buổi',
    features: [
      '12 buổi tập 1-1 trực tiếp cùng Huấn luyện viên',
      'Xây dựng giáo án riêng theo thể trạng ban đầu',
      'Hướng dẫn sử dụng chuẩn toàn bộ máy móc phòng tập',
      'Nhắn tin hỏi đáp cùng Coach qua ứng dụng',
    ],
  },
  {
    name: 'PT Chuyên Sâu (24 Buổi)',
    price: '6.490.000 ₫',
    period: '/ 24 buổi',
    summary: 'Lộ trình toàn diện giúp tăng cơ, giảm mỡ rõ rệt với sự theo sát sát sao của Coach.',
    featured: true,
    badge: 'Hiệu quả cao nhất',
    cta: 'Đặt lịch tập thử PT',
    features: [
      '24 buổi tập 1-1 cùng Coach (trần tối đa 8 học viên/Coach)',
      'Theo dõi thực đơn, macro dinh dưỡng hằng ngày trên App',
      'Hỗ trợ gọi video chỉnh form động tác khi tự tập',
      'Cam kết bảo lưu quyền lợi nếu phát sinh sự cố gián đoạn',
    ],
  },
  {
    name: 'PT Đồng Hành Online + App',
    price: '1.490.000 ₫',
    period: '/ tháng',
    summary: 'Dành cho người bận rộn hoặc đã có nền tảng, cần Coach thiết kế lịch và chỉnh form từ xa.',
    featured: false,
    cta: 'Chọn gói Online PT',
    features: [
      'Giáo án cập nhật hằng tuần trên ứng dụng Meta Gym',
      '2 phiên gọi video 1-1 mỗi tuần để kiểm tra tiến độ',
      'Điều chỉnh dinh dưỡng theo lịch sinh hoạt thực tế',
      'Tích hợp sẵn Trợ lý AI Coach 24/7',
    ],
  },
];

export const APP_HIGHLIGHTS = [
  {
    title: 'Check-in QR trong 1 giây',
    icon: 'qr',
    description: 'Quét mã ngay tại quầy lễ tân, kiểm tra thời hạn gói tập và lịch sử điểm danh rõ ràng.',
  },
  {
    title: 'Nhật ký tập & Dinh dưỡng',
    icon: 'smartphone',
    description: 'Ghi nhận mức tạ, số hiệp, lượng calo và macro mỗi ngày để không bỏ lỡ bất kỳ cột mốc nào.',
  },
  {
    title: 'Kết nối trực tiếp với Coach',
    icon: 'video',
    description: 'Nhắn tin, đặt lịch hẹn và gọi video 1-1 với Huấn luyện viên của bạn ngay trong một ứng dụng.',
  },
  {
    title: 'Thanh toán & Gia hạn tiện lợi',
    icon: 'creditCard',
    description: 'Đăng ký hoặc gia hạn gói Gym, gói Coach nhanh chóng qua VNPay, MoMo, ZaloPay hoặc tại quầy.',
  },
];

export const FAQ_ITEMS = [
  {
    id: 'faq-1',
    question: 'Tôi chưa từng tập gym bao giờ, đến Meta Gym có bị bỡ ngỡ không?',
    answer:
      'Hoàn toàn không. Khi đăng ký tập thử, bạn sẽ được hướng dẫn làm quen với các khu vực máy móc và tư vấn lộ trình phù hợp với thể trạng. Ngoài ra, ứng dụng Meta Gym có sẵn hướng dẫn bài tập theo từng thiết bị và Trợ lý AI Coach hỗ trợ 24/7.',
  },
  {
    id: 'faq-2',
    question: 'Giá gói tập đã bao gồm tủ đồ, tắm nóng lạnh và gửi xe chưa?',
    answer:
      'Tất cả gói tập tại Meta Gym đều đã bao gồm miễn phí tủ đồ cá nhân (locker), phòng tắm nước nóng, nước lọc, Wi-Fi và gửi xe — cam kết minh bạch, không phát sinh phụ phí ẩn.',
  },
  {
    id: 'faq-3',
    question: 'Tại sao mỗi Coach tại Meta Gym chỉ nhận tối đa 8 học viên?',
    answer:
      'Để đảm bảo chất lượng huấn luyện 1-1 thực chất. Giới hạn 8 học viên giúp Coach có đủ thời gian thiết kế giáo án riêng, theo dõi dinh dưỡng và chỉnh sửa kỹ thuật cho từng người thay vì nhận ồ ạt.',
  },
  {
    id: 'faq-4',
    question: 'Tôi có thể thanh toán gói tập bằng những hình thức nào?',
    answer:
      'Bạn có thể thanh toán trực tuyến trên ứng dụng Meta Gym qua VNPay, MoMo, ZaloPay hoặc thanh toán trực tiếp tại quầy lễ tân phòng tập.',
  },
];
