# Flutter Screens — Ý tưởng, Thiết kế & Mockup

Thư mục này là nơi tập trung toàn bộ **ý tưởng cải tiến UX**, **bản đặc tả thiết kế (spec)** và **mockup trực quan** cho các màn hình của ứng dụng Flutter Meta Gym (`mobile-app/`).

Mọi thiết kế trong thư mục này đều tuân thủ hệ thống chuẩn tại:
- [`../../DESIGN.md`](../../DESIGN.md) — Nguồn chuẩn cao nhất (*Futuristic Performance Glass*, token màu, chữ **Be Vietnam Pro**, lưới 4/8px, quy tắc 80/20).
- [`../meta-gym/MASTER.md`](../meta-gym/MASTER.md) — Bản tóm tắt triển khai nhanh.
- [`../meta-gym/pages/`](../meta-gym/pages/) — Quy tắc trang đã chốt (nếu có).

---

## Cấu trúc thư mục

```text
design-system/flutter-screens/
├── README.md                    # Tổng quan & bảng theo dõi màn hình
├── _TEMPLATE_SCREEN_SPEC.md     # Mẫu tài liệu ý tưởng & thiết kế chuẩn
├── 22-11-2026/                  # Bản Review UI/UX toàn bộ màn hình Flutter hiện tại (22/11/2026)
├── ideas/                       # Ý tưởng UX, ghi chú audit, wireframe luồng
├── specs/                       # Đặc tả thiết kế chi tiết trước khi code Flutter
└── mockups/                     # Mockup trực quan (PNG/WebP/SVG/HTML preview)
```

### Quy ước đặt tên
Dùng định dạng `kebab-case` theo vai trò + tên màn hình:
- Ý tưởng: `ideas/<role>-<screen-name>.md` (VD: `ideas/member-training-hub.md`)
- Đặc tả: `specs/<role>-<screen-name>.md` (VD: `specs/member-training-hub.md`)
- Mockup: `mockups/<role>-<screen-name>.png` hoặc `mockups/<role>-<screen-name>.html`

---

## Quy trình làm việc cho mỗi màn hình

1. **Ý tưởng (`ideas/`):** Ghi nhận vấn đề UI/UX hiện tại, mục tiêu cải thiện và bố cục đề xuất.
2. **Mockup (`mockups/`):** Tạo bản xem trước trực quan (ảnh hoặc HTML preview tỷ lệ 375×812 / 393×852) để chốt hướng nhìn.
3. **Đặc tả (`specs/`):** Chốt token, vật liệu (Level 0–3), spacing, typography, trạng thái (`loading`, `empty`, `error`, `offline`, `disabled`, `success`) bằng mẫu [`_TEMPLATE_SCREEN_SPEC.md`](./_TEMPLATE_SCREEN_SPEC.md).
4. **Triển khai Flutter (`mobile-app/`):** Code theo spec và nghiệm thu theo **Screen Review Checklist** trong `DESIGN.md`.

---

## Danh mục màn hình Flutter hiện có

| Nhóm tính năng | Các màn hình chính (`mobile-app/lib/features/`) | Ý tưởng | Mockup | Đặc tả | Trạng thái |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Public & Auth** | `app_loading_page`, `login_page`, `register_page`, `forgot_password_page` | — | — | — | Chưa tạo |
| **Member Home** | `member_home_page` | — | — | [`member-home.md`](../meta-gym/pages/member-home.md) | Đã có page rule |
| **Training (Member)** | `member_training_hub_page`, `member_training_page`, `member_day_plan_page`, `member_curriculum_detail_page`, `member_self_training_page`, `gym_visits_page` | — | — | — | Chưa tạo |
| **Nutrition (Member)** | `member_nutrition_page`, `meal_plans_page`, `nutrition_tracking_page` | — | — | [`member-nutrition.md`](../meta-gym/pages/member-nutrition.md) | Đã có page rule |
| **Sessions & Booking** | `coach_booking_page`, `coach_schedule_picker_page`, `coach_booking_history_page`, `coach_sessions_page` | — | — | — | Chưa tạo |
| **Coaching** | `member_coaching_page`, `coach_selection_page`, `coach_detail_page`, `coach_offers_page`, `member_health_declaration_page`, `member_outcome_consent_page` | — | — | — | Chưa tạo |
| **Membership & Billing** | `membership_page`, `membership_checkout_page`, `payment_history_page`, `payment_detail_page` | — | — | — | Chưa tạo |
| **Progress** | `member_progress_page`, `member_measurement_page`, `member_journal_page`, `member_photo_page` | — | — | — | Chưa tạo |
| **Catalog** | `exercise_library_page`, `gym_equipment_page`, `equipment_detail_page` | — | — | — | Chưa tạo |
| **AI Assistant** | `ai_conversations_page`, `ai_messages_page` | — | — | — | Chưa tạo |
| **Messaging & Calls** | `conversations_page`, `calls_page`, `live_call_page` | — | — | — | Chưa tạo |
| **Profile** | `profile_page` | — | — | — | Chưa tạo |
| **Coach App** | `coach_home_page`, `coach_members_page`, `coach_member_detail_page`, `coach_training_page`, `coach_plan_detail_page`, `coach_plan_form_page`, `coach_nutrition_page`, `coach_nutrition_editor_page`, `coach_notifications_page` | — | — | — | Chưa tạo |
