# Thư mục `svg/navigation` — Thanh Điều Hướng Đáy 3 Trạng Thái (`outline`/`filled`/`disabled`) & AI Coach (`svg/navigation/`) (30 SVG)

## 1. Quy chuẩn Kỹ thuật & Ngôn ngữ Thiết kế
- **Phong cách:** MetaGym Soft-Line Duotone (nét mở `2.2px`, lớp ửng chuyển sắc `#FF5E36` `5% → 30%`, huy hiệu điểm nhấn cam san hô `#FF5E36` với khoảng hở knockout sạch sẽ).
- **Tương thích Đa nền tảng (Flutter & Web/Admin):** 100% độc lập, không dùng `<style>` hay `class`, mọi `linearGradient` đều có tiền tố ID duy nhất chống xung đột DOM, kiểm thử song song trên cả nền tối `#181B22` và nền sáng `#F5F7FA`.

## 2. Bảng Danh Mục Chi Tiết 30 Icon & Thông Tin Kỹ Thuật

| STT | `assetKey` | Têp SVG | Tầng | `viewBox` | Dung lượng | Ý nghĩa & Vị trí sử dụng |
| :-: | :--- | :--- | :-: | :-: | :-: | :--- |
| 1 | `default` | [`default.svg`](./default.svg) | Tầng A/B | `48×48` | `0.78 KB` | Biểu tượng điều hướng mặc định |
| 2 | `nav_ai_emblem` | [`nav_ai_emblem.svg`](./nav_ai_emblem.svg) | Tầng B | `48×48` | `0.96 KB` | Nút nổi trung tâm AI Coach (Phiên bản cam #FF5E36 trên nền tối) |
| 3 | `nav_ai_on_primary` | [`nav_ai_on_primary.svg`](./nav_ai_on_primary.svg) | Tầng B | `48×48` | `0.88 KB` | Nút nổi trung tâm AI Coach (Phiên bản trắng #FFFFFF trên nền cam) |
| 4 | `nav_coach_schedule_disabled` | [`nav_coach_schedule_disabled.svg`](./nav_coach_schedule_disabled.svg) | Tầng A/B | `48×48` | `0.69 KB` | Tab Lịch dạy HLV — Trạng thái vô hiệu hóa (Disabled) |
| 5 | `nav_coach_schedule_filled` | [`nav_coach_schedule_filled.svg`](./nav_coach_schedule_filled.svg) | Tầng A/B | `48×48` | `1.43 KB` | Tab Lịch dạy HLV — Trạng thái đang chọn (Filled Duotone) |
| 6 | `nav_coach_schedule_outline` | [`nav_coach_schedule_outline.svg`](./nav_coach_schedule_outline.svg) | Tầng A/B | `48×48` | `0.86 KB` | Tab Lịch dạy HLV — Trạng thái chưa chọn (Outline) |
| 7 | `nav_community_disabled` | [`nav_community_disabled.svg`](./nav_community_disabled.svg) | Tầng A/B | `48×48` | `0.52 KB` | Tab Cộng đồng — Trạng thái vô hiệu hóa (Disabled) |
| 8 | `nav_community_filled` | [`nav_community_filled.svg`](./nav_community_filled.svg) | Tầng A/B | `48×48` | `0.93 KB` | Tab Cộng đồng — Trạng thái đang chọn (Filled Duotone) |
| 9 | `nav_community_outline` | [`nav_community_outline.svg`](./nav_community_outline.svg) | Tầng A/B | `48×48` | `0.59 KB` | Tab Cộng đồng — Trạng thái chưa chọn (Outline) |
| 10 | `nav_home_disabled` | [`nav_home_disabled.svg`](./nav_home_disabled.svg) | Tầng A | `48×48` | `0.64 KB` | Tab Trang chủ — Trạng thái vô hiệu hóa (Disabled) |
| 11 | `nav_home_filled` | [`nav_home_filled.svg`](./nav_home_filled.svg) | Tầng A | `48×48` | `1.11 KB` | Tab Trang chủ — Trạng thái đang chọn (Filled Duotone) |
| 12 | `nav_home_outline` | [`nav_home_outline.svg`](./nav_home_outline.svg) | Tầng A | `48×48` | `0.59 KB` | Tab Trang chủ — Trạng thái chưa chọn (Outline) |
| 13 | `nav_messages_disabled` | [`nav_messages_disabled.svg`](./nav_messages_disabled.svg) | Tầng A | `48×48` | `0.59 KB` | Tab Tin nhắn — Trạng thái vô hiệu hóa (Disabled) |
| 14 | `nav_messages_filled` | [`nav_messages_filled.svg`](./nav_messages_filled.svg) | Tầng A | `48×48` | `1.10 KB` | Tab Tin nhắn — Trạng thái đang chọn (Filled Duotone) |
| 15 | `nav_messages_outline` | [`nav_messages_outline.svg`](./nav_messages_outline.svg) | Tầng A | `48×48` | `0.52 KB` | Tab Tin nhắn — Trạng thái chưa chọn (Outline) |
| 16 | `nav_nutrition_disabled` | [`nav_nutrition_disabled.svg`](./nav_nutrition_disabled.svg) | Tầng A/B | `48×48` | `0.54 KB` | Tab Dinh dưỡng — Trạng thái vô hiệu hóa (Disabled) |
| 17 | `nav_nutrition_filled` | [`nav_nutrition_filled.svg`](./nav_nutrition_filled.svg) | Tầng A/B | `48×48` | `0.89 KB` | Tab Dinh dưỡng — Trạng thái đang chọn (Filled Duotone) |
| 18 | `nav_nutrition_outline` | [`nav_nutrition_outline.svg`](./nav_nutrition_outline.svg) | Tầng A/B | `48×48` | `0.58 KB` | Tab Dinh dưỡng — Trạng thái chưa chọn (Outline) |
| 19 | `nav_profile_disabled` | [`nav_profile_disabled.svg`](./nav_profile_disabled.svg) | Tầng A | `48×48` | `0.46 KB` | Tab Hồ sơ cá nhân — Trạng thái vô hiệu hóa (Disabled) |
| 20 | `nav_profile_filled` | [`nav_profile_filled.svg`](./nav_profile_filled.svg) | Tầng A | `48×48` | `1.12 KB` | Tab Hồ sơ cá nhân — Trạng thái đang chọn (Filled Duotone) |
| 21 | `nav_profile_outline` | [`nav_profile_outline.svg`](./nav_profile_outline.svg) | Tầng A | `48×48` | `0.40 KB` | Tab Hồ sơ cá nhân — Trạng thái chưa chọn (Outline) |
| 22 | `nav_progress_disabled` | [`nav_progress_disabled.svg`](./nav_progress_disabled.svg) | Tầng A/B | `48×48` | `0.42 KB` | Tab Tiến độ — Trạng thái vô hiệu hóa (Disabled) |
| 23 | `nav_progress_filled` | [`nav_progress_filled.svg`](./nav_progress_filled.svg) | Tầng A/B | `48×48` | `0.87 KB` | Tab Tiến độ — Trạng thái đang chọn (Filled Duotone) |
| 24 | `nav_progress_outline` | [`nav_progress_outline.svg`](./nav_progress_outline.svg) | Tầng A/B | `48×48` | `0.46 KB` | Tab Tiến độ — Trạng thái chưa chọn (Outline) |
| 25 | `nav_training_disabled` | [`nav_training_disabled.svg`](./nav_training_disabled.svg) | Tầng A/B | `48×48` | `0.82 KB` | Tab Tập luyện (App hiện hành) — Trạng thái vô hiệu hóa (Disabled) |
| 26 | `nav_training_filled` | [`nav_training_filled.svg`](./nav_training_filled.svg) | Tầng A/B | `48×48` | `1.37 KB` | Tab Tập luyện (App hiện hành) — Trạng thái đang chọn (Filled Duotone) |
| 27 | `nav_training_outline` | [`nav_training_outline.svg`](./nav_training_outline.svg) | Tầng A/B | `48×48` | `0.69 KB` | Tab Tập luyện (App hiện hành) — Trạng thái chưa chọn (Outline) |
| 28 | `nav_workout_disabled` | [`nav_workout_disabled.svg`](./nav_workout_disabled.svg) | Tầng A/B | `48×48` | `0.82 KB` | Tab Tập luyện (Alias chuẩn nav_workout) — Trạng thái Disabled |
| 29 | `nav_workout_filled` | [`nav_workout_filled.svg`](./nav_workout_filled.svg) | Tầng A/B | `48×48` | `1.38 KB` | Tab Tập luyện (Alias chuẩn nav_workout) — Trạng thái Filled Duotone |
| 30 | `nav_workout_outline` | [`nav_workout_outline.svg`](./nav_workout_outline.svg) | Tầng A/B | `48×48` | `0.69 KB` | Tab Tập luyện (Alias chuẩn nav_workout) — Trạng thái Outline |
