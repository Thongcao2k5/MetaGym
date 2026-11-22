# Bảng Kiểm duyệt Chi tiết các Màn hình Flutter (22/11/2026)

Ký hiệu mức độ ưu tiên sửa chữa:
- `P0 (CRITICAL)`: Ảnh hưởng trực tiếp hiệu năng/quy tắc 80/20, rò rỉ >80 hex hardcode, hoặc luồng demo chính.
- `P1 (WARNING)`: Thiếu `SafeArea`/state, >20 hex hardcode, cần chuẩn hóa token/overflow/tnum.
- `P2 (POLISH)`: Cấu trúc gọn, chỉ cần tinh chỉnh nhỏ và kiểm thử 375px/landscape.

---

## 1. Public & Auth

| Màn hình | File (`mobile-app/lib/features/`) | Dòng | Blur/Glass | Hex | Loading / Empty / Error | SafeArea | Mức độ | Ghi chú Review |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| App Loading | `public/presentation/app_loading_page.dart` | 1.299 | 0 | 26 | — / ✓ / ✓ | ✓ | `P1` | File khá dài cho màn splash/loading; kiểm tra giảm hiệu ứng nặng khi khởi động. |
| Đăng nhập | `auth/presentation/login_page.dart` | 286 | 0* | 8 | ✓ / ✓ / ✓ | Wrapper | `P2` | Dùng `AuthGlassScaffold` (có `RepaintBoundary` & `disableAnimations`); kiểm tra keyboard inset trên 375px. |
| Đăng ký | `auth/presentation/register_page.dart` | 342 | 0* | 8 | ✓ / — / ✓ | Wrapper | `P2` | Kiểm tra validation on blur & cuộn mượt khi bàn phím mở. |
| Quên mật khẩu | `profile/presentation/forgot_password_page.dart` | 349 | 0* | 9 | ✓ / — / ✓ | Wrapper | `P2` | Đồng bộ hoàn toàn với `login_page` & `register_page`. |

---

## 2. Member Home & Khám phá

| Màn hình | File (`mobile-app/lib/features/`) | Dòng | Blur/Glass | Hex | Loading / Empty / Error | SafeArea | Mức độ | Ghi chú Review |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| Member Home Shell | `member/presentation/member_home_page.dart` | 59 | 0 | 0 | Delegate | ✓ | `PASS` | Shell gọn, quản lý `MetaGymBottomNav` có `contentBottomPadding`. |
| Member Dashboard | `member/presentation/member_dashboard_view.dart` | 1.995 | 4 | — | ✓ / ✓ / ✓ | ✓ | `P0` | Đã có `RepaintBoundary` & `disableAnimations`; nhưng file gần 2.000 dòng, cần tách thành sub-widgets và kiểm tra tỷ lệ 80/20 khi cuộn. |
| Khám phá bài viết | `member/presentation/member_explore_articles.dart` | 859 | Hero | — | ✓ / ✓ / ✓ | ✓ | `P1` | Thiếu `RepaintBoundary` & `disableAnimations` quanh thẻ Hero Glass. |

---

## 3. Training & Nutrition (Hội viên)

| Màn hình | File (`mobile-app/lib/features/`) | Dòng | Blur/Glass | Hex | Loading / Empty / Error | SafeArea | Mức độ | Ghi chú Review |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| Training Hub | `training/presentation/member_training_hub_page.dart` | 1.533 | 5 | 35 | ✓ / ✓ / ✓ | ✓ | `P0` | 5 lớp blur/glass — cần giảm blur trên thẻ cuộn về solid `#181B22`, tách widget con. |
| Chi tiết giáo trình | `training/presentation/member_curriculum_detail_page.dart` | 1.282 | 2 | 57 | ✓ / ✓ / ✓ | ✓ | `P1` | 57 hex hardcode; gom về token `MetaGymTheme`, kiểm tra `tnum` cho set/rep/kg. |
| Kế hoạch ngày | `training/presentation/member_day_plan_page.dart` | 471 | Hero | 23 | ✓ / ✓ / ✗ | ✗ | `P1` | Thiếu trạng thái `Error/Retry` và `SafeArea` tường minh. |
| Tự tập | `training/presentation/member_self_training_page.dart` | 1.079 | 0 | 46 | ✓ / ✓ / ✓ | ✓ | `P1` | 46 hex + 16 Material colors (`Colors.white`/khác) — cần kiểm tra tương phản nền tối. |
| Lịch sử ghé phòng | `training/presentation/gym_visits_page.dart` | 760 | Hero | 39 | ✓ / ✓ / ✓ | ✓ | `P1` | 39 hex hardcode; thiếu `RepaintBoundary` quanh Hero Glass. |
| Dinh dưỡng (Hub) | `training/presentation/member_nutrition_page.dart` | 398 | Hero | 20 | ✓ / ✓ / ✓ | ✓ | `P1` | Đối chiếu thêm với [`member-nutrition.md`](../../meta-gym/pages/member-nutrition.md). |
| Thực đơn mẫu | `training/presentation/meal_plans_page.dart` | 721 | Hero | 48 | ✗ / ✓ / ✓ | ✗ | `P1` | Thiếu trạng thái `Loading` & `SafeArea`; 48 hex hardcode. |
| Theo dõi dinh dưỡng | `training/presentation/nutrition_tracking_page.dart` | 2.577 | Hero | 42 | ✓ / ✓ / ✓ | ✓ | `P0` | God-file 2.577 dòng; nhiều chỉ số macro/calo cần đảm bảo `tnum` và chống overflow ở 375px. |

---

## 4. Sessions & Coaching

| Màn hình | File (`mobile-app/lib/features/`) | Dòng | Blur/Glass | Hex | Loading / Empty / Error | SafeArea | Mức độ | Ghi chú Review |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| Đặt lịch Coach | `sessions/presentation/coach_booking_page.dart` | 2.486 | Hero | 125 | ✓ / ✓ / ✓ | ✓ | `P0` | **125 hex hardcode** (cao nhất app) + 2.486 dòng; ưu tiên tách widget & chuẩn hóa token. |
| Chọn khung giờ | `sessions/presentation/coach_schedule_picker_page.dart` | 1.268 | Hero | 43 | ✓ / ✓ / ✓ | ✓ | `P1` | Kiểm tra touch target `>= 48dp` cho từng ô slot giờ và `tnum`. |
| Lịch sử đặt lịch | `sessions/presentation/coach_booking_history_page.dart` | 234 | Hero | 7 | ✗ / ✓ / ✗ | ✓ | `P1` | Thiếu trạng thái `Loading` và `Error/Retry`. |
| Coaching của tôi | `coaching/presentation/member_coaching_page.dart` | 1.313 | Hero | 29 | ✓ / ✓ / ✓ | ✓ | `P1` | Đồng bộ Avatar Coach `"LN"` (`#F5B041` / `#181B22`) và chuyển thẻ nội dung sang solid. |
| Chọn Coach | `coaching/presentation/coach_selection_page.dart` | 579 | Hero | 28 | ✓ / ✓ / ✓ | ✓ | `P1` | Tránh dùng blur cho từng thẻ Coach trong danh sách cuộn. |
| Chi tiết Coach | `coaching/presentation/coach_detail_page.dart` | 615 | Hero | 28 | ✓ / ✓ / ✓ | ✓ | `P1` | Kiểm tra phân cấp 1 CTA cam duy nhất (`#FF5E36`). |
| Gói đề xuất Coach | `coaching/presentation/coach_offers_page.dart` | 975 | Hero | 38 | ✓ / ✓ / ✓ | ✓ | `P1` | Kiểm tra `tnum` cho giá gói & hạn sử dụng. |
| Khai báo sức khỏe | `coaching/presentation/member_health_declaration_page.dart` | 998 | 1 | 39 | ✓ / ✓ / ✓ | ✓ | `P1` | Form dài — cấm đặt blur phía sau input/text dài (`DESIGN.md §11`). |
| Cam kết kết quả | `coaching/presentation/member_outcome_consent_page.dart` | 402 | 0 | 12 | ✓ / ✓ / ✓ | ✓ | `P2` | Nền đặc tốt; kiểm tra độ đọc chữ pháp lý (>= 14–16px). |

---

## 5. Membership, Progress & Catalog

| Màn hình | File (`mobile-app/lib/features/`) | Dòng | Blur/Glass | Hex | Loading / Empty / Error | SafeArea | Mức độ | Ghi chú Review |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| Gói hội viên | `membership/presentation/membership_page.dart` | 1.137 | Hero | 22 | ✓ / ✓ / ✓ | ✓ | `P1` | Kiểm tra rõ 1 gói nổi bật, giá dùng `tnum`, nhãn `"Hiệu lực"` tiếng Việt. |
| Thanh toán gói | `membership/presentation/membership_checkout_page.dart` | 957 | Hero | 14 | ✓ / ✓ / ✓ | ✓ | `P1` | Chặn bấm trùng khi gọi cổng MoMo/VNPay; kiểm tra nút CTA đáy có `SafeArea`. |
| Lịch sử thanh toán | `membership/presentation/payment_history_page.dart` | 323 | 0 | 6 | ✓ / ✓ / ✓ | ✓ | `P2` | Gọn, ít hex; kiểm tra trạng thái chip màu ngữ nghĩa. |
| Chi tiết thanh toán | `membership/presentation/payment_detail_page.dart` | 292 | Hero | 2 | ✓ / — / ✓ | ✓ | `P2` | Gọn, gần chuẩn token. |
| Nhật ký tập luyện | `progress/presentation/member_journal_page.dart` | 2.683 | 0 | 111 | ✓ / ✓ / ✓ | ✓ | `P0` | **111 hex + 14 Material colors** trong 2.683 dòng; cần tách component & chuẩn hóa bảng màu tối. |
| Tổng quan tiến độ | `progress/presentation/member_progress_page.dart` | 583 | 0 | 27 | ✓ / ✓ / ✓ | ✗ | `P1` | Thiếu `SafeArea` tường minh; 8 Material colors cần rà tương phản. |
| Chỉ số cơ thể | `progress/presentation/member_measurement_page.dart` | 539 | 0 | 16 | ✓ / ✓ / ✓ | ✗ | `P1` | Thiếu `SafeArea`; đảm bảo `tnum` cho toàn bộ chỉ số đo. |
| Ảnh tiến độ | `progress/presentation/member_photo_page.dart` | 653 | 0 | 25 | ✓ / ✓ / ✓ | ✗ | `P1` | Thiếu `SafeArea`; tối ưu lưới ảnh & trạng thái tải ảnh lỗi. |
| Thư viện bài tập | `catalog/presentation/exercise_library_page.dart` | 593 | Hero | 10 | ✓ / ✓ / ✓ | ✗ | `P1` | Thiếu `SafeArea`; kiểm tra filter chips không tô cam đặc toàn hàng. |
| Thiết bị phòng gym | `catalog/presentation/gym_equipment_page.dart` | 618 | Hero | 27 | ✓ / ✓ / ✓ | ✗ | `P1` | Thiếu `SafeArea`; 27 hex hardcode. |
| Chi tiết thiết bị | `catalog/presentation/equipment_detail_page.dart` | 296 | Hero | 10 | ✓ / — / ✓ | ✗ | `P2` | Gọn; bổ sung `SafeArea` đáy. |

---

## 6. AI Assistant, Messaging, Calls & Profile

| Màn hình | File (`mobile-app/lib/features/`) | Dòng | Blur/Glass | Hex | Loading / Empty / Error | SafeArea | Mức độ | Ghi chú Review |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| Danh sách hội thoại AI | `ai/presentation/ai_conversations_page.dart` | 543 | 0 | 29 | ✓ / ✓ / ✓ | ✓ | `P1` | 29 hex hardcode; cần tạo điểm nhấn nhận diện AI rõ ràng nhưng không neon/cyberpunk. |
| Chat Trợ lý AI | `ai/presentation/ai_messages_page.dart` | 497 | 0 | 17 | ✓ / ✓ / ✓ | ✓ | `P1` | Kiểm tra `viewInsets.bottom` khi nhập tin nhắn & độ đọc markdown/danh sách. |
| Tin nhắn | `messaging/presentation/conversations_page.dart` | 3.073 | 6 | 83 | ✓ / ✓ / ✓ | ✓ | `P0` | **6 lớp blur/glass** + 3.073 dòng + 83 hex; thiếu `disableAnimations` fallback. Cần tách danh sách hội thoại & màn chat. |
| Lịch sử cuộc gọi | `calls/presentation/calls_page.dart` | 674 | 0 | 27 | ✓ / ✓ / ✓ | ✗ | `P1` | Thiếu `SafeArea`; 27 hex hardcode. |
| Cuộc gọi trực tiếp | `calls/presentation/live_call_page.dart` | 1.307 | 0 | 35 | ✗ / ✓ / ✓ | ✓ | `P1` | Kiểm tra nút điều khiển gọi đạt `>= 48dp` và trạng thái đang kết nối (`Loading`). |
| Hồ sơ cá nhân | `profile/presentation/profile_page.dart` | 3.393 | 2 | 118 | ✓ / ✓ / ✓ | ✓ | `P0` | **118 hex hardcode** + 3.393 dòng; ưu tiên tách các section (Thông tin, Cài đặt, Gói tập, Bảo mật) thành file riêng. |

---

## 7. Coach App & Admin Shell

| Màn hình | File (`mobile-app/lib/features/`) | Dòng | Blur/Glass | Hex | Loading / Empty / Error | SafeArea | Mức độ | Ghi chú Review |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| Trang chủ Coach | `coach/presentation/coach_home_page.dart` | 3.591 | Hero | 97 | ✓ / ✓ / ✓ | ✓ | `P0` | **File lớn nhất toàn app (3.591 dòng)** + 97 hex; cần tách modular giống hướng `member_home_page` và chuẩn hóa mật độ thẻ. |
| Danh sách học viên | `coaching/presentation/coach_members_page.dart` | 493 | Hero | 11 | ✓ / ✓ / ✓ | ✓ | `P2` | Khá gọn; bỏ blur trong item cuộn. |
| Chi tiết học viên | `coaching/presentation/coach_member_detail_page.dart` | 1.085 | Hero | 36 | ✓ / ✓ / ✓ | ✓ | `P1` | 36 hex hardcode; kiểm tra tab/section spacing 20–24px. |
| Thông báo Coach | `coaching/presentation/coach_notifications_page.dart` | 540 | Hero | 22 | ✓ / ✓ / ✓ | ✓ | `P2` | Phân biệt rõ đã đọc / chưa đọc bằng chấm màu + đậm chữ. |
| Lịch dạy Coach | `sessions/presentation/coach_sessions_page.dart` | 1.181 | Hero | 54 | ✓ / ✓ / ✓ | ✓ | `P1` | 54 hex hardcode; kiểm tra `tnum` và lọc theo ngày. |
| Quản lý giáo án | `training/presentation/coach_training_page.dart` | 693 | 0 | 7 | ✓ / ✓ / ✓ | ✗ | `P2` | Ít hex; bổ sung `SafeArea`. |
| Form tạo giáo án | `training/presentation/coach_plan_form_page.dart` | 1.095 | 0 | 33 | ✓ / ✓ / ✓ | ✗ | `P1` | Form dài cần `SafeArea` + bàn phím + tránh lồng thẻ trong thẻ. |
| Chi tiết giáo án | `training/presentation/coach_plan_detail_page.dart` | 313 | 0 | 8 | ✓ / — / ✓ | ✓ | `P2` | Gọn, gần chuẩn. |
| Dinh dưỡng Coach | `training/presentation/coach_nutrition_page.dart` | 597 | 0 | 7 | ✓ / ✓ / ✓ | ✗ | `P2` | Ít hex; bổ sung `SafeArea`. |
| Soạn thực đơn Coach | `training/presentation/coach_nutrition_editor_page.dart` | 427 | 0 | 13 | ✗ / ✗ / ✓ | ✗ | `P1` | Thiếu `Loading`, `Empty` và `SafeArea`. |
| Admin Shell (Mobile) | `admin/presentation/admin_home_page.dart` | 307 | 0 | 4 | ✓ / — / ✓ | ✓ | `P2` | Màn phụ chuyển hướng quản trị; đã dùng bề mặt đặc gọn. |
