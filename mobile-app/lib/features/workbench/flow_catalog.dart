import 'flow_action.dart';

const _empty = '{}';

const memberFlows = <FlowGroup>[
  FlowGroup('Gói tập và thanh toán', [
    FlowAction('Gói đang mở bán', 'GET', '/membership-plans'),
    FlowAction('Chi tiết gói tập', 'GET', '/membership-plans/:planId'),
    FlowAction('Gói của tôi', 'GET', '/memberships/me'),
    FlowAction('Lịch sử gói tập', 'GET', '/memberships/me/history'),
    FlowAction('Lịch sử thanh toán', 'GET', '/payments/me'),
    FlowAction('Chi tiết thanh toán', 'GET', '/payments/:paymentId'),
  ]),
  FlowGroup('Chọn Coach', [
    FlowAction('Danh sách Coach', 'GET', '/coaches'),
    FlowAction('Hồ sơ Coach', 'GET', '/coaches/:coachId'),
    FlowAction(
      'Gửi yêu cầu',
      'POST',
      '/coach-requests',
      sampleBody: '{"coachId":"","message":""}',
    ),
    FlowAction('Yêu cầu của tôi', 'GET', '/coach-requests/me'),
    FlowAction('Hủy yêu cầu', 'DELETE', '/coach-requests/:requestId'),
    FlowAction('Coach hiện tại', 'GET', '/relationships/me'),
    FlowAction('Lịch sử Coach', 'GET', '/relationships/me/history'),
    FlowAction(
      'Kết thúc quan hệ',
      'POST',
      '/relationships/:relationshipId/terminations',
      sampleBody: '{"reason":"Tôi muốn đổi Coach"}',
    ),
  ]),
  FlowGroup('Tập luyện và dinh dưỡng', [
    FlowAction('Giáo trình hiện tại', 'GET', '/training-plans/me/active'),
    FlowAction('Lịch sử giáo trình', 'GET', '/training-plans/me/history'),
    FlowAction('Chi tiết giáo trình', 'GET', '/training-plans/:planId'),
    FlowAction('Dinh dưỡng hiện tại', 'GET', '/nutrition-guides/me/active'),
    FlowAction('Lịch sử dinh dưỡng', 'GET', '/nutrition-guides/me/history'),
    FlowAction('Lịch tập', 'GET', '/training-sessions/me'),
    FlowAction('Chi tiết buổi tập', 'GET', '/training-sessions/:sessionId'),
    FlowAction('Danh mục bài tập', 'GET', '/exercises'),
    FlowAction('Chi tiết bài tập', 'GET', '/exercises/:exerciseId'),
  ]),
  FlowGroup('Tiến độ', [
    FlowAction('Tổng quan', 'GET', '/progress/me/summary'),
    FlowAction('Biểu đồ', 'GET', '/progress/me/charts'),
    FlowAction('Nhật ký tập', 'GET', '/workout-logs'),
    FlowAction(
      'Ghi buổi tập',
      'POST',
      '/workout-logs',
      sampleBody:
          '{"performedAt":"2026-10-23T08:00:00+07:00","notes":"Buổi tập thử"}',
    ),
    FlowAction(
      'Sửa nhật ký tập',
      'PATCH',
      '/workout-logs/:logId',
      sampleBody: _empty,
    ),
    FlowAction('Nhật ký ăn', 'GET', '/meal-logs'),
    FlowAction(
      'Ghi bữa ăn',
      'POST',
      '/meal-logs',
      sampleBody:
          '{"eatenAt":"2026-10-23T12:00:00+07:00","mealName":"Bữa trưa"}',
    ),
    FlowAction('Sửa bữa ăn', 'PATCH', '/meal-logs/:logId', sampleBody: _empty),
    FlowAction('Lịch sử số đo', 'GET', '/body-measurements'),
    FlowAction(
      'Thêm số đo',
      'POST',
      '/body-measurements',
      sampleBody: '{"measuredAt":"2026-10-23T07:00:00+07:00","weightKg":70}',
    ),
    FlowAction(
      'Sửa số đo',
      'PATCH',
      '/body-measurements/:measurementId',
      sampleBody: '{"weightKg":70}',
    ),
    FlowAction('Ảnh tiến trình', 'GET', '/progress-photos'),
    FlowAction(
      'Gắn ảnh tiến trình',
      'POST',
      '/progress-photos',
      sampleBody: '{"mediaId":"","takenAt":"2026-10-23T07:00:00+07:00"}',
    ),
    FlowAction(
      'Sửa ảnh tiến trình',
      'PATCH',
      '/progress-photos/:photoId',
      sampleBody: _empty,
    ),
    FlowAction('Nhận xét', 'GET', '/progress-comments'),
  ]),
  FlowGroup('Tin nhắn và cuộc gọi', [
    FlowAction('Cuộc trò chuyện', 'GET', '/conversations'),
    FlowAction(
      'Tải tin nhắn',
      'GET',
      '/conversations/:relationshipId/messages',
    ),
    FlowAction(
      'Gửi tin nhắn',
      'POST',
      '/conversations/:relationshipId/messages',
      sampleBody:
          '{"messageType":"TEXT","clientMessageId":"","content":"Xin chào"}',
    ),
    FlowAction(
      'Đánh dấu đã đọc',
      'PATCH',
      '/conversations/:relationshipId/read-state',
      sampleBody: '{"messageId":""}',
    ),
    FlowAction('Lấy URL ảnh', 'GET', '/media/images/:mediaId/access-url'),
    FlowAction('Lịch sử cuộc gọi', 'GET', '/calls'),
    FlowAction(
      'Tạo cuộc gọi',
      'POST',
      '/calls',
      sampleBody: '{"relationshipId":"","callType":"VOICE"}',
    ),
    FlowAction(
      'Lấy token cuộc gọi',
      'POST',
      '/calls/:callId/access-tokens',
      sampleBody: _empty,
    ),
    FlowAction(
      'Cập nhật cuộc gọi',
      'PATCH',
      '/calls/:callId',
      sampleBody: '{"status":"ENDED"}',
    ),
  ]),
  FlowGroup('AI và phòng gym', [
    FlowAction('Danh sách hội thoại AI', 'GET', '/ai-conversations'),
    FlowAction(
      'Tạo hội thoại AI',
      'POST',
      '/ai-conversations',
      sampleBody: '{"title":"Hỏi về tập luyện"}',
    ),
    FlowAction(
      'Chi tiết hội thoại AI',
      'GET',
      '/ai-conversations/:conversationId',
    ),
    FlowAction(
      'Đổi tên hội thoại AI',
      'PATCH',
      '/ai-conversations/:conversationId',
      sampleBody: '{"title":"Tên mới"}',
    ),
    FlowAction(
      'Xóa hội thoại AI',
      'DELETE',
      '/ai-conversations/:conversationId',
    ),
    FlowAction(
      'Tin nhắn AI',
      'GET',
      '/ai-conversations/:conversationId/messages',
    ),
    FlowAction(
      'Hỏi AI',
      'POST',
      '/ai-conversations/:conversationId/messages',
      sampleBody: '{"clientRequestId":"","content":"Gợi ý lịch tập"}',
    ),
    FlowAction('Thông tin phòng gym', 'GET', '/gym-profile'),
    FlowAction('Thiết bị', 'GET', '/equipment'),
    FlowAction('Chi tiết thiết bị', 'GET', '/equipment/:equipmentId'),
  ]),
];

const coachFlows = <FlowGroup>[
  FlowGroup('Yêu cầu và hội viên', [
    FlowAction('Yêu cầu chọn Coach', 'GET', '/coach/requests'),
    FlowAction('Chi tiết yêu cầu', 'GET', '/coach/requests/:requestId'),
    FlowAction(
      'Duyệt hoặc từ chối',
      'PATCH',
      '/coach/requests/:requestId',
      sampleBody: '{"decision":"ACCEPTED"}',
    ),
    FlowAction('Hội viên đang phụ trách', 'GET', '/coach/members'),
    FlowAction('Hồ sơ hội viên', 'GET', '/coach/members/:memberId'),
    FlowAction(
      'Xin ngừng phụ trách',
      'POST',
      '/coach/termination-requests',
      sampleBody:
          '{"relationshipId":"","reason":"Không thể tiếp tục phụ trách"}',
    ),
    FlowAction('Theo dõi yêu cầu ngừng', 'GET', '/coach/termination-requests'),
  ]),
  FlowGroup('Giáo trình và lịch tập', [
    FlowAction(
      'Giáo trình hội viên',
      'GET',
      '/coach/members/:memberId/training-plans',
    ),
    FlowAction(
      'Tạo giáo trình nháp',
      'POST',
      '/coach/members/:memberId/training-plans',
      sampleBody: '{"title":"Giáo trình mới","days":[{"dayNumber":1,"title":"Ngày 1","exercises":[]}]}',
    ),
    FlowAction('Chi tiết giáo trình', 'GET', '/training-plans/:planId'),
    FlowAction(
      'Sửa giáo trình',
      'PATCH',
      '/coach/training-plans/:planId',
      sampleBody: '{"title":"Giáo trình đã sửa"}',
    ),
    FlowAction(
      'Công bố giáo trình',
      'POST',
      '/coach/training-plans/:planId/publications',
      sampleBody: _empty,
    ),
    FlowAction(
      'Hướng dẫn dinh dưỡng',
      'GET',
      '/coach/members/:memberId/nutrition-guides',
    ),
    FlowAction(
      'Tạo hướng dẫn',
      'POST',
      '/coach/members/:memberId/nutrition-guides',
      sampleBody:
          '{"title":"Hướng dẫn dinh dưỡng","content":"Nội dung hướng dẫn"}',
    ),
    FlowAction(
      'Sửa/công bố hướng dẫn',
      'PATCH',
      '/coach/nutrition-guides/:guideId',
      sampleBody: _empty,
    ),
    FlowAction('Lịch tập Coach', 'GET', '/coach/training-sessions'),
    FlowAction(
      'Tạo buổi tập',
      'POST',
      '/coach/training-sessions',
      sampleBody: '{"memberId":"","title":"Buổi tập thử","scheduledStartAt":"2026-10-23T08:00:00+07:00"}',
    ),
    FlowAction(
      'Sửa buổi tập',
      'PATCH',
      '/coach/training-sessions/:sessionId',
      sampleBody: _empty,
    ),
    FlowAction('Danh mục bài tập', 'GET', '/exercises'),
  ]),
  FlowGroup('Theo dõi tiến độ', [
    FlowAction(
      'Tổng quan hội viên',
      'GET',
      '/coach/members/:memberId/progress/summary',
    ),
    FlowAction('Nhật ký tập', 'GET', '/coach/members/:memberId/workout-logs'),
    FlowAction('Nhật ký ăn', 'GET', '/coach/members/:memberId/meal-logs'),
    FlowAction('Số đo', 'GET', '/coach/members/:memberId/body-measurements'),
    FlowAction(
      'Ảnh tiến trình',
      'GET',
      '/coach/members/:memberId/progress-photos',
    ),
    FlowAction(
      'Nhận xét',
      'GET',
      '/progress-comments',
      sampleQuery: '{"memberId":""}',
    ),
    FlowAction(
      'Gửi nhận xét',
      'POST',
      '/coach/progress-comments',
      sampleBody: '{"memberId":"","content":"Tiến bộ tốt"}',
    ),
  ]),
  FlowGroup('Liên lạc và AI', [
    FlowAction('Cuộc trò chuyện', 'GET', '/conversations'),
    FlowAction(
      'Tải tin nhắn',
      'GET',
      '/conversations/:relationshipId/messages',
    ),
    FlowAction(
      'Gửi tin nhắn',
      'POST',
      '/conversations/:relationshipId/messages',
      sampleBody:
          '{"messageType":"TEXT","clientMessageId":"","content":"Xin chào"}',
    ),
    FlowAction(
      'Đánh dấu đã đọc',
      'PATCH',
      '/conversations/:relationshipId/read-state',
      sampleBody: '{"messageId":""}',
    ),
    FlowAction('Lịch sử cuộc gọi', 'GET', '/calls'),
    FlowAction(
      'Tạo cuộc gọi',
      'POST',
      '/calls',
      sampleBody: '{"relationshipId":"","callType":"VOICE"}',
    ),
    FlowAction(
      'Lấy token cuộc gọi',
      'POST',
      '/calls/:callId/access-tokens',
      sampleBody: _empty,
    ),
    FlowAction(
      'Cập nhật cuộc gọi',
      'PATCH',
      '/calls/:callId',
      sampleBody: '{"status":"ENDED"}',
    ),
    FlowAction('Hội thoại AI', 'GET', '/ai-conversations'),
    FlowAction(
      'Tạo hội thoại AI',
      'POST',
      '/ai-conversations',
      sampleBody: '{"title":"Trao đổi"}',
    ),
    FlowAction(
      'Chi tiết hội thoại AI',
      'GET',
      '/ai-conversations/:conversationId',
    ),
    FlowAction(
      'Tin nhắn AI',
      'GET',
      '/ai-conversations/:conversationId/messages',
    ),
    FlowAction(
      'Đổi tên hội thoại AI',
      'PATCH',
      '/ai-conversations/:conversationId',
      sampleBody: '{"title":"Tên mới"}',
    ),
    FlowAction(
      'Xóa hội thoại AI',
      'DELETE',
      '/ai-conversations/:conversationId',
    ),
    FlowAction(
      'Hỏi AI',
      'POST',
      '/ai-conversations/:conversationId/messages',
      sampleBody: '{"clientRequestId":"","content":"Gợi ý tập luyện"}',
    ),
    FlowAction('Thông tin phòng gym', 'GET', '/gym-profile'),
    FlowAction('Thiết bị', 'GET', '/equipment'),
    FlowAction('Chi tiết thiết bị', 'GET', '/equipment/:equipmentId'),
  ]),
];
