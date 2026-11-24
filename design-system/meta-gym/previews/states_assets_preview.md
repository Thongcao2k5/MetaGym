# Bản Review & Xem Trước: Điểm Danh QR, Streak, 13 Empty States & 14 Trạng Thái Hệ Thống (`svg/states/`) (31 SVG)

![Bảng Contact Sheet states](./sheets/states_svg_sheet.webp)

## 1. Đánh Giá Kiểm Duyệt Chất Lượng (Rubric 5 Tiêu Chí — Đạt `9.6/10`)
- **Style Fidelity (`2/2`):** Đồng bộ ngôn ngữ **MetaGym Soft-Line Duotone**, nét mở `2.2px` bo tròn, lớp ửng gradient mềm và huy hiệu điểm nhấn `#FF5E36`.
- **Object Construction (`2/2`):** Chi tiết định danh đặc trưng rõ ràng, nhận diện tức thì ở cả kích thước `2x` (`82px`) trên nền tối `#181B22` lẫn `1x` (`34px`) trên ô nền sáng `#F5F7FA`.
- **Knockout & Badge Harmony (`1.8/2`):** Huy hiệu hành động đặt đúng trọng tâm góc, không đè nét rối mắt.
- **Composition & Safe Margin (`1.8/2`):** Căn tâm chuẩn xác, lề thoáng `≥ 4px`.
- **Technical SVG Lint (`2/2`):** `0` thẻ cấm, `100%` ID gradient có tiền tố riêng, dung lượng siêu nhẹ.

## 2. Bảng Danh Mục Chi Tiết 31 Icon Trong `assets/svg/states/`

| STT | `assetKey` | Têp SVG | Tầng | `viewBox` | Dung lượng | Ý nghĩa & Vị trí sử dụng |
| :-: | :--- | :--- | :-: | :-: | :-: | :--- |
| 1 | `checkin_badge` | [`checkin_badge.svg`](../assets/svg/states/checkin_badge.svg) | Tầng B | `48×48` | `1.14 KB` | Huy hiệu xác nhận đã điểm danh vào phòng tập thành công |
| 2 | `default` | [`default.svg`](../assets/svg/states/default.svg) | Tầng C | `48×48` | `1.05 KB` | Minh họa trạng thái trống mặc định |
| 3 | `empty_ai_chat` | [`empty_ai_chat.svg`](../assets/svg/states/empty_ai_chat.svg) | Tầng C | `48×48` | `1.25 KB` | Empty State: Bắt đầu cuộc trò chuyện đầu tiên với AI Coach |
| 4 | `empty_calls` | [`empty_calls.svg`](../assets/svg/states/empty_calls.svg) | Tầng C | `48×48` | `1.13 KB` | Empty State: Chưa có lịch sử cuộc gọi âm thanh / video |
| 5 | `empty_coach` | [`empty_coach.svg`](../assets/svg/states/empty_coach.svg) | Tầng C | `48×48` | `1.73 KB` | Empty State: Chưa đăng ký Huấn luyện viên đồng hành (Pose #14) |
| 6 | `empty_curriculum` | [`empty_curriculum.svg`](../assets/svg/states/empty_curriculum.svg) | Tầng C | `48×48` | `1.42 KB` | Empty State: Chưa có giáo trình tập luyện được gán |
| 7 | `empty_measurements` | [`empty_measurements.svg`](../assets/svg/states/empty_measurements.svg) | Tầng C | `48×48` | `1.28 KB` | Empty State: Chưa có bản ghi số đo cơ thể |
| 8 | `empty_messages` | [`empty_messages.svg`](../assets/svg/states/empty_messages.svg) | Tầng C | `48×48` | `1.16 KB` | Empty State: Hộp thư hội thoại chưa có tin nhắn |
| 9 | `empty_nutrition` | [`empty_nutrition.svg`](../assets/svg/states/empty_nutrition.svg) | Tầng C | `48×48` | `1.14 KB` | Empty State: Chưa có thực đơn hoặc món ăn nào được ghi nhận |
| 10 | `empty_payments` | [`empty_payments.svg`](../assets/svg/states/empty_payments.svg) | Tầng C | `48×48` | `1.18 KB` | Empty State: Chưa phát sinh giao dịch thanh toán nào |
| 11 | `empty_photos` | [`empty_photos.svg`](../assets/svg/states/empty_photos.svg) | Tầng C | `48×48` | `1.19 KB` | Empty State: Chưa có ảnh chụp theo dõi biến đổi hình thể |
| 12 | `empty_progress` | [`empty_progress.svg`](../assets/svg/states/empty_progress.svg) | Tầng C | `48×48` | `1.29 KB` | Empty State: Chưa đủ dữ liệu biểu đồ tiến độ |
| 13 | `empty_sessions` | [`empty_sessions.svg`](../assets/svg/states/empty_sessions.svg) | Tầng C | `48×48` | `1.38 KB` | Empty State: Chưa có lịch hẹn buổi tập 1-1 nào |
| 14 | `empty_visits` | [`empty_visits.svg`](../assets/svg/states/empty_visits.svg) | Tầng C | `48×48` | `1.21 KB` | Empty State: Chưa có lịch sử lượt đến phòng tập |
| 15 | `empty_workout` | [`empty_workout.svg`](../assets/svg/states/empty_workout.svg) | Tầng C | `48×48` | `1.33 KB` | Empty State: Chưa có bài tập nào trong buổi tập hôm nay |
| 16 | `qr_scan_frame` | [`qr_scan_frame.svg`](../assets/svg/states/qr_scan_frame.svg) | Tầng B/C | `48×48` | `1.32 KB` | Khung ngắm quét mã QR điểm danh tại quầy lễ tân phòng tập |
| 17 | `state_access_denied` | [`state_access_denied.svg`](../assets/svg/states/state_access_denied.svg) | Tầng A/C | `48×48` | `0.61 KB` | Trạng thái hệ thống: Từ chối truy cập / Không đủ quyền (Access Denied) |
| 18 | `state_broken_image` | [`state_broken_image.svg`](../assets/svg/states/state_broken_image.svg) | Tầng A/C | `48×48` | `1.01 KB` | Trạng thái hệ thống: Ảnh tải bị lỗi hoặc không tồn tại |
| 19 | `state_coming_soon` | [`state_coming_soon.svg`](../assets/svg/states/state_coming_soon.svg) | Tầng A/C | `48×48` | `0.77 KB` | Trạng thái hệ thống: Tính năng sắp ra mắt (Coming Soon) |
| 20 | `state_empty_search` | [`state_empty_search.svg`](../assets/svg/states/state_empty_search.svg) | Tầng A/C | `48×48` | `1.01 KB` | Trạng thái hệ thống: Không tìm thấy kết quả khớp từ khóa |
| 21 | `state_empty_workout` | [`state_empty_workout.svg`](../assets/svg/states/state_empty_workout.svg) | Tầng C | `48×48` | `1.33 KB` | Khóa chuẩn state_empty_workout: Trạng thái danh sách tập luyện trống |
| 22 | `state_error` | [`state_error.svg`](../assets/svg/states/state_error.svg) | Tầng A/C | `48×48` | `1.04 KB` | Trạng thái hệ thống: Đã xảy ra lỗi xử lý (Error Alert) |
| 23 | `state_info` | [`state_info.svg`](../assets/svg/states/state_info.svg) | Tầng A/C | `48×48` | `0.59 KB` | Trạng thái hệ thống: Thông tin hướng dẫn chi tiết (Info) |
| 24 | `state_loading` | [`state_loading.svg`](../assets/svg/states/state_loading.svg) | Tầng A/C | `48×48` | `0.88 KB` | Trạng thái hệ thống: Đang tải & Đồng bộ dữ liệu (Loading Orbit) |
| 25 | `state_maintenance` | [`state_maintenance.svg`](../assets/svg/states/state_maintenance.svg) | Tầng A/C | `48×48` | `0.89 KB` | Trạng thái hệ thống: Hệ thống đang bảo trì nâng cấp (Maintenance) |
| 26 | `state_no_network` | [`state_no_network.svg`](../assets/svg/states/state_no_network.svg) | Tầng A/C | `48×48` | `1.10 KB` | Khóa chuẩn state_no_network: Mất kết nối mạng Internet |
| 27 | `state_offline` | [`state_offline.svg`](../assets/svg/states/state_offline.svg) | Tầng A/C | `48×48` | `1.10 KB` | Trạng thái hệ thống: Đang ở chế độ ngoại tuyến (Offline Mode) |
| 28 | `state_success` | [`state_success.svg`](../assets/svg/states/state_success.svg) | Tầng A/C | `48×48` | `0.92 KB` | Trạng thái hệ thống: Thao tác hoàn tất thành công (Success) |
| 29 | `state_update` | [`state_update.svg`](../assets/svg/states/state_update.svg) | Tầng A/C | `48×48` | `0.95 KB` | Trạng thái hệ thống: Có bản cập nhật ứng dụng mới (Update Available) |
| 30 | `state_warning` | [`state_warning.svg`](../assets/svg/states/state_warning.svg) | Tầng A/C | `48×48` | `0.79 KB` | Trạng thái hệ thống: Cảnh báo lưu ý quan trọng (Warning) |
| 31 | `streak_flame` | [`streak_flame.svg`](../assets/svg/states/streak_flame.svg) | Tầng B | `48×48` | `1.36 KB` | Huy hiệu ngọn lửa chuỗi ngày đi tập chuyên cần (Streak) |
