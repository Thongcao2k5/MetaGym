# Báo cáo công việc nhánh Coach và trạng thái bàn giao

Ngày lập: 26/11/2026
Workspace: `C:\MetaGym`
Nhánh hiện tại: `feature/design-coach-preview`

## 1. Phạm vi và trạng thái Git

Báo cáo này tổng hợp **commit riêng của nhánh so với nhánh `develop` đang có trên máy** và **các thay đổi đang có trong workspace nhưng chưa commit**. Không suy ra rằng tất cả thay đổi đều do cùng một người hoặc cùng một phiên thực hiện. Chưa fetch trong lúc lập báo cáo, do đó chưa khẳng định nhánh `origin/develop` được lưu trên máy là mới nhất trên GitHub.

- Commit đang đứng: `8aed25b` — `feat(design-system): add Coach preview screens and align preview with V2 backend`.
- So với `develop` local, có một commit riêng nói trên. Commit thay đổi 9 tệp preview/design system (2.592 dòng thêm, 468 dòng xóa).
- Workspace có nhiều tệp Flutter, test, cấu hình và preview đang sửa nhưng chưa commit; cũng có tệp mới Git chưa theo dõi. Danh sách chi tiết ở phụ lục.
- Các thống kê thêm/xóa là diff, không phải số dòng tính năng hoàn toàn mới; tệp mới chưa theo dõi không có trong `git diff --stat` thông thường.
- Chưa thực hiện commit, push hay mở PR trong lúc lập báo cáo này.

## 2. Phần đã có trong commit của nhánh

Commit `8aed25b` cập nhật preview tại `design-system/flutter-screens/22-11-2026/`:

- Bổ sung các mô-đun preview Coach về dinh dưỡng và không gian làm việc; cập nhật màn hình Coach chính và chi tiết.
- Chỉnh preview trang chủ/hồ sơ Member và token CSS liên quan.
- Commit là thay đổi preview/design system; không đồng nghĩa tự nó đã hoàn thành kết nối backend của ứng dụng Flutter.

## 3. Thay đổi Flutter và giao diện trong workspace

### 3.1. Coach — trang chủ, học viên và hồ sơ

- Điều chỉnh trang chủ Coach theo phong cách Warm Glass, bố cục tóm tắt công việc, ca dạy và lối tắt.
- Có các màn danh sách học viên, chi tiết hội viên, thông báo Coach và gói PT; bổ sung/cập nhật điều hướng giữa các phần này.
- Điều chỉnh hồ sơ Coach và các trang phụ, bao gồm các lối tắt đến công việc, lịch và thiết lập.
- Tab thứ hai của thanh điều hướng Coach mang nhãn **Lịch dạy** và mở trang lịch dạy mới.

### 3.2. Lịch và buổi dạy

- Các màn lịch dạy/buổi hẹn, lịch làm việc tuần, chặn khung giờ bận và lịch sử buổi dạy.
- Nối các lối tắt từ trang chủ/hồ sơ vào lịch và lịch sử; hỗ trợ các trạng thái danh sách và thao tác theo nghiệp vụ hiện có.
- Điều chỉnh vị trí nút `+ Tạo buổi tập` để tránh bị thanh điều hướng che; có regression test.
- Form buổi tập được bổ sung nhãn Coach; các vùng chạm đã chỉnh trong phần này lên 48dp.

### 3.3. Giáo trình và dinh dưỡng

- Màn chọn học viên cho luồng tập luyện và dinh dưỡng; danh sách, chi tiết, tạo/sửa giáo trình.
- Hiển thị nội dung ngày tập/bài tập, hướng dẫn dinh dưỡng và thực đơn 7 ngày.
- Đồng bộ nhiều card sang Warm Glass và truyền tùy chọn nền dự phòng; không đặt blur sau các form dày đã chỉnh.
- Sửa màu chữ, trường nhập và hộp thoại của trình sửa hướng dẫn dinh dưỡng để phù hợp giao diện sáng.

### 3.4. Tin nhắn, cuộc gọi và AI

- Danh sách hội thoại và chi tiết chat Coach–học viên; bổ sung các lối tắt liên quan đến hồ sơ/giáo trình.
- Hub cuộc gọi Coach và giao diện cuộc gọi thoại/video; điều chỉnh chống tràn ở LiveCallPage. Màn gọi thoại và nền chờ dùng màu theo theme; lớp phủ trên video giữ nền tối để dễ đọc.
- Trợ lý AI Coach: header, gợi ý nhanh, bong bóng hội thoại và composer; có test responsive và dữ liệu demo.
- Các test demo không chứng minh việc gửi tin, gọi LiveKit hoặc gọi dịch vụ AI thật đầu cuối.

### 3.5. Theme, khả năng đọc và bề mặt dùng chung

- Nối lựa chọn sáng/tối ở Cài đặt với theme cấp ứng dụng và lưu lựa chọn trên thiết bị thông qua `ThemeController`.
- Nối và lưu tùy chọn giảm hiệu ứng mờ; truyền tới card, nền, điều hướng và các lớp phủ đã cập nhật. Card nổi bật trên trang chủ tôn trọng tùy chọn nền đặc dự phòng.
- Ô minh họa nhóm cơ có nền/viền theo theme; điều chỉnh các nút, header và vùng chạm liên quan.
- Sửa một số màu chữ/icon, ô tìm kiếm và bộ lọc trong Catalog (phòng gym, thiết bị, bài tập) cho Light Mode.
- Các thay đổi component dùng chung ảnh hưởng cả luồng Member, không chỉ Coach; cần review phạm vi PR.

### 3.6. Dữ liệu demo và định tuyến

- Mở rộng `local_demo_interceptor.dart` và model để các màn Coach có dữ liệu mẫu, trạng thái và liên kết phục vụ kiểm thử UI offline.
- Điều chỉnh router và các kết nối giữa màn; có test kiểm tra điều hướng bằng fixture/demo.
- Tài khoản và dữ liệu demo là mô phỏng cục bộ, không phải bằng chứng dữ liệu đã được ghi vào backend thật.

## 4. Các kiểm tra đã ghi nhận trong phiên làm việc

Các kết quả dưới đây là kết quả đã chạy trong các lượt trước, không phải kết quả vừa chạy lại khi lập tệp báo cáo:

| Phạm vi | Kết quả gần nhất được ghi nhận | Giới hạn |
| --- | --- | --- |
| Toàn bộ test Flutter | **334/334 đạt** sau các thay đổi về theme, giảm mờ và cuộc gọi | Widget/unit test không chứng minh mọi pixel, mọi thiết bị hoặc dịch vụ thật. |
| Nhóm tập trung Coach, lịch, hồ sơ, cuộc gọi và surface | **105/105 đạt** | Có test sáng/tối, kích thước và phóng chữ theo các trường hợp test đã viết. |
| Phân tích Flutter | Không có error/warning; **8 thông báo info** | `flutter analyze` thông thường vẫn trả mã khác 0 khi tính info. |
| Backend `npm run check` | Đạt | Kiểm tra cú pháp, không phải kiểm thử tất cả luồng. |
| Backend `npm test` | **68 đạt, 0 lỗi, 50 bỏ qua** | Các bài bỏ qua phần lớn cần database test hoặc dịch vụ ngoài. |
| API/backend local | Health 200 khi khởi động tạm PostgreSQL và backend; nhiều GET Coach trả 200 với token thử nghiệm | Không xác nhận app trên máy ảo gọi backend thật; chưa test đầy đủ thao tác ghi, dịch vụ AI/LiveKit/thanh toán thật. |
| Đăng nhập backend bằng bộ tài khoản kiểm thử cũ | **HTTP 401** | Không thể xác nhận bộ mật khẩu test cũ còn đúng; GET xác thực được thử bằng token thử nghiệm cho tài khoản fixture. |

Trên máy ảo đã quan sát trực tiếp một số màn Coach ở giao diện sáng/tối, gồm trang chủ, hồ sơ, danh sách và chi tiết học viên. Chưa có bằng chứng kiểm tra trực quan tất cả màn, tất cả trạng thái và tất cả thiết bị sau những sửa đổi cuối.

## 5. Việc còn tồn tại và giới hạn quan trọng

1. **Demo Offline:** máy ảo đã hiển thị `Chế độ Demo Offline · Không gọi API`. `ApiClient` hiện mặc định bật interceptor demo; cần phân tách rõ demo và backend thật trước khi đánh giá tích hợp/production.
2. **Backend đầu cuối:** cần môi trường test riêng và kiểm tra đăng nhập thật, tạo/sửa giáo trình, lịch, gửi tin, cuộc gọi và AI với dịch vụ tương ứng. Không coi GET 200 hoặc test mock là xác nhận toàn bộ nghiệp vụ.
3. **Face ID/vân tay:** giao diện hiện tại là luồng demo, chưa phải xác thực sinh trắc học thật. Chưa tích hợp `local_auth` trong phạm vi được ghi nhận.
4. **Cài đặt khác:** đơn vị và nhắc lịch trong hồ sơ từng được xác định mới giữ trong trạng thái trang; chưa chứng minh lưu lâu dài hay gửi thông báo thật.
5. **Rà soát giao diện:** test không bao phủ toàn bộ độ tương phản, vùng chạm và trạng thái trên thiết bị thật; cần kiểm tra trực quan bổ sung, đặc biệt nội dung video và điều kiện lỗi.
6. **Sự cố tệp test:** trong phiên trước, phần sau của `mobile-app/test/widget_test.dart` đã bị xóa nhầm khi chỉnh sửa, sau đó được khôi phục từ Git và điều chỉnh để test đạt. Không có bản sao để xác nhận toàn bộ thay đổi chưa commit trước thời điểm đó đã được phục hồi; cần review tệp này trước commit.
7. **Backend/DB sau kiểm tra:** backend và PostgreSQL được khởi động tạm cho lần kiểm tra đã được dừng lại để trả môi trường về trạng thái ban đầu.

## 6. Gợi ý chuẩn bị PR

- Review cả commit `8aed25b` và từng thay đổi chưa commit, kể cả tệp mới, ảnh nền và thay đổi dùng chung Member/Coach.
- Không tự động đưa `Meta-Gym-UI-Design-Rules.zip`, `.env`, token, dữ liệu cá nhân hoặc các tệp không liên quan vào commit; kiểm tra nội dung và phạm vi trước.
- Làm rõ và xử lý chế độ Demo Offline trước khi quảng bá như tích hợp backend thật; phân biệt các test mock, test database và test thiết bị thật.
- Theo quy trình trong `CONTRIBUTING.md`, tạo/đưa công việc sang nhánh theo chuẩn từ `develop`, mở PR vào `develop`, chờ CI và review. Cần fetch và kiểm tra lịch sử thực tế trước khi chọn merge/cherry-pick; không push trực tiếp vào `main`.

## 7. Phụ lục: tệp trong commit và workspace

Các danh sách dưới đây là snapshot lúc lập báo cáo. Tệp báo cáo mới này không được tính vào snapshot.

### 7.1. Tệp trong commit riêng so với develop local (9)

- `M	design-system/flutter-screens/22-11-2026/screens-preview.html`
- `M	design-system/flutter-screens/22-11-2026/screens/coach/core.js`
- `M	design-system/flutter-screens/22-11-2026/screens/coach/detail.js`
- `A	design-system/flutter-screens/22-11-2026/screens/coach/nutrition.js`
- `A	design-system/flutter-screens/22-11-2026/screens/coach/workspace.js`
- `M	design-system/flutter-screens/22-11-2026/screens/member/tab1-home.js`
- `M	design-system/flutter-screens/22-11-2026/screens/member/tab5-profile-sub.js`
- `M	design-system/flutter-screens/22-11-2026/screens/member/tab5-profile.js`
- `M	design-system/flutter-screens/22-11-2026/tokens.css`

### 7.2. Tệp đã theo dõi có thay đổi chưa commit (52)

- `design-system/flutter-screens/22-11-2026/screens-preview.html`
- `mobile-app/lib/app/app_router.dart`
- `mobile-app/lib/app/meta_gym_app.dart`
- `mobile-app/lib/core/network/local_demo_interceptor.dart`
- `mobile-app/lib/core/widgets/meta_gym_bottom_nav.dart`
- `mobile-app/lib/core/widgets/meta_gym_glass_surface.dart`
- `mobile-app/lib/core/widgets/muscle_anatomy_tile.dart`
- `mobile-app/lib/core/widgets/system_state_modals.dart`
- `mobile-app/lib/features/ai/presentation/ai_conversations_page.dart`
- `mobile-app/lib/features/ai/presentation/ai_messages_page.dart`
- `mobile-app/lib/features/auth/presentation/auth_glass_scaffold.dart`
- `mobile-app/lib/features/calls/presentation/calls_page.dart`
- `mobile-app/lib/features/calls/presentation/live_call_page.dart`
- `mobile-app/lib/features/catalog/presentation/equipment_detail_page.dart`
- `mobile-app/lib/features/catalog/presentation/exercise_library_page.dart`
- `mobile-app/lib/features/catalog/presentation/gym_equipment_page.dart`
- `mobile-app/lib/features/coach/presentation/coach_home_page.dart`
- `mobile-app/lib/features/coaching/domain/coach_member_models.dart`
- `mobile-app/lib/features/coaching/presentation/coach_member_detail_page.dart`
- `mobile-app/lib/features/coaching/presentation/coach_members_page.dart`
- `mobile-app/lib/features/coaching/presentation/coach_notifications_page.dart`
- `mobile-app/lib/features/coaching/presentation/coach_offers_page.dart`
- `mobile-app/lib/features/coaching/presentation/termination_reason_dialog.dart`
- `mobile-app/lib/features/member/presentation/widgets/member_home_qr_modal.dart`
- `mobile-app/lib/features/membership/presentation/widgets/membership_empty_deck_view.dart`
- `mobile-app/lib/features/membership/presentation/widgets/meta_points_redeem_sheet.dart`
- `mobile-app/lib/features/messaging/presentation/chat_message_image.dart`
- `mobile-app/lib/features/messaging/presentation/conversations_page.dart`
- `mobile-app/lib/features/profile/presentation/profile_page.dart`
- `mobile-app/lib/features/profile/presentation/widgets/body_metric_pickers.dart`
- `mobile-app/lib/features/profile/presentation/widgets/profile_secondary_pages.dart`
- `mobile-app/lib/features/profile/presentation/widgets/profile_shared_widgets.dart`
- `mobile-app/lib/features/sessions/presentation/coach_booking_history_page.dart`
- `mobile-app/lib/features/sessions/presentation/coach_booking_page.dart`
- `mobile-app/lib/features/sessions/presentation/coach_sessions_page.dart`
- `mobile-app/lib/features/training/presentation/coach_nutrition_editor_page.dart`
- `mobile-app/lib/features/training/presentation/coach_nutrition_page.dart`
- `mobile-app/lib/features/training/presentation/coach_plan_detail_page.dart`
- `mobile-app/lib/features/training/presentation/coach_plan_form_page.dart`
- `mobile-app/lib/features/training/presentation/coach_training_page.dart`
- `mobile-app/lib/features/training/presentation/meal_plans_page.dart`
- `mobile-app/lib/features/training/presentation/member_curriculum_detail_page.dart`
- `mobile-app/lib/features/training/presentation/training_plan_content.dart`
- `mobile-app/pubspec.lock`
- `mobile-app/pubspec.yaml`
- `mobile-app/test/features/calls/live_call_page_test.dart`
- `mobile-app/test/features/catalog/gym_equipment_page_test.dart`
- `mobile-app/test/features/coach/coach_home_page_test.dart`
- `mobile-app/test/features/profile/profile_controller_test.dart`
- `mobile-app/test/features/sessions/coach_sessions_page_test.dart`
- `mobile-app/test/features/training/coach_nutrition_page_test.dart`
- `mobile-app/test/widget_test.dart`

### 7.3. Tệp mới chưa được Git theo dõi (16)

- `Meta-Gym-UI-Design-Rules.zip`
- `mobile-app/assets/images/backgrounds/bg_app_dark.webp`
- `mobile-app/assets/images/backgrounds/bg_app_light.webp`
- `mobile-app/lib/core/theme/theme_controller.dart`
- `mobile-app/lib/features/calls/presentation/coach_calls_view.dart`
- `mobile-app/lib/features/coach/presentation/coach_schedule_management_pages.dart`
- `mobile-app/lib/features/messaging/presentation/chat_detail_page.dart`
- `mobile-app/lib/features/messaging/presentation/messaging_session_cache.dart`
- `mobile-app/test/core/widgets/surface_preferences_test.dart`
- `mobile-app/test/features/coach/coach_demo_data_and_links_test.dart`
- `mobile-app/test/features/coach/coach_group1_preview_sync_test.dart`
- `mobile-app/test/features/coach/coach_group2_preview_sync_test.dart`
- `mobile-app/test/features/coach/coach_group3_preview_sync_test.dart`
- `mobile-app/test/features/coach/coach_group4_ai_preview_sync_test.dart`
- `mobile-app/test/features/coach/coach_group5_messages_calls_test.dart`
- `mobile-app/test/features/profile/coach_profile_preview_sync_test.dart`
