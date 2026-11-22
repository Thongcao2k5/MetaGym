# Báo cáo Review UI/UX các Màn hình Flutter — 22/11/2026

> **Phạm vi kiểm duyệt:** Toàn bộ 53 file màn hình (`*_page.dart` + `member_dashboard_view.dart`) và hệ thống theme/widget lõi (`app_theme.dart`, `meta_gym_glass_surface.dart`, `meta_gym_bottom_nav.dart`, `app_router.dart`) trong `mobile-app/lib/`.
> **Tiêu chuẩn đối chiếu:** [`DESIGN.md`](../../../DESIGN.md), [`MASTER.md`](../../meta-gym/MASTER.md), [`member-home.md`](../../meta-gym/pages/member-home.md) và bộ kiểm duyệt **UI/UX Pro Max**.

---

## 1. Tóm tắt điều hành (Executive Summary)

| Hạng mục kiểm duyệt | Đánh giá | Số liệu thực tế từ mã nguồn |
| :--- | :---: | :--- |
| **Nền tảng Theme & Navigation lõi** | `PASS` | `Be Vietnam Pro`, Material 3 dark-first, `48×48dp` hit target trên button/icon, `MetaGymBottomNav` có `RepaintBoundary` & `disableAnimations`, 0 nhãn tiếng Anh lạc tông. |
| **Token màu & Đồng bộ Design System** | `CRITICAL` | **>1.200** giá trị `Color(0x...)` hardcode rải rác trong `features/`; `MetaGymTheme.textPrimary` là `#FFFFFF` lệch với `DESIGN.md` (`#F7F9FC`, khiến dev phải hardcode `0xFFF7F9FC` tới **311 lần**). |
| **Quy tắc vật liệu 80/20 & Hiệu năng Blur** | `CRITICAL` | Chỉ **6/100** `MetaGymGlassCard` dùng `solid: true`; **37** `MetaGymHeroGlassCard` dùng `BackdropFilter` nhưng **thiếu `RepaintBoundary` và thiếu fallback `disableAnimations`**. |
| **Kiến trúc file UI (Maintainability)** | `WARNING` | **8 màn hình** vượt ngưỡng 1.500–3.591 dòng/file (`coach_home_page`, `profile_page`, `conversations_page`, `member_journal_page`, `nutrition_tracking_page`, `coach_booking_page`, `member_dashboard_view`, `member_training_hub_page`). |
| **Trạng thái màn hình & SafeArea** | `WARNING` | **14 màn hình** chưa xử lý `SafeArea`/`viewInsets` tường minh trong file page; một số màn thiếu trạng thái `Loading` hoặc `Error/Retry` riêng biệt. |
| **Typography (`tnum`) & Reduced Motion** | `WARNING` | Chỉ **38/132** file bật `tabularFigures`; chỉ **11/132** file xử lý `MediaQuery.disableAnimationsOf(context)`. |

- **Xem trước trực quan 11 màn hình Flutter có đầy đủ dữ liệu (HTML/CSS chỉnh sửa trực tiếp):** [`screens-preview.html`](./screens-preview.html) + [`tokens.css`](./tokens.css)
- Xem bảng kiểm duyệt chi tiết từng màn hình: [`screen-audit-matrix.md`](./screen-audit-matrix.md)
- Mở giao diện bảng audit lọc theo mức độ ưu tiên: [`review-board.html`](./review-board.html)

---

## 2. Các phát hiện trọng yếu cấp hệ thống (System-Wide Findings)

### [CRITICAL-01] Rò rỉ Token màu & Lệch nhẹ giữa `MetaGymTheme` và `DESIGN.md`
- **Hiện trạng:**
  - `MetaGymTheme.textPrimary` đang là `0xFFFFFFFF` thay vì `#F7F9FC` như `DESIGN.md`, dẫn đến việc các màn hình hardcode `Color(0xFFF7F9FC)` **311 lần**.
  - Các màu warm-glass (`0xFFC8C2BC` ×257, `0x9A8C8176` ×112, `0x80211E1C` ×100, `0xA3A79D92` ×78, `0xC42B2622` ×42) chưa được gom thành semantic token trong `MetaGymTheme`, gây phân mảnh khi cập nhật màu.
  - `MetaGymTheme.performanceGlass` (`rgba(18,23,30,0.72)`, blur `14px`) lệch nhẹ so với `DESIGN.md` (`rgba(24,27,34,0.78)`, blur `12px`); `brandOrangeHover` (`0xFFE84729`) lệch nhẹ so với `#E84E27`.
- **Hành động đề xuất:** Đồng bộ `app_theme.dart` theo đúng `DESIGN.md`, bổ sung nhóm token `WarmGlassTokens` (nếu giữ phong cách warm-glass của `member-home.md`), sau đó refactor dần các file có >40 hex hardcode.

### [CRITICAL-02] Lạm dụng Glass mặc định & Thiếu `RepaintBoundary` / Reduced Motion trên `BackdropFilter`
- **Hiện trạng:**
  - `MetaGymGlassCard` có mặc định `solid = false` (nền bán trong suốt `0xC42B2622`). Trong 100 lần sử dụng toàn app, chỉ **6 lần** truyền `solid: true` → vi phạm tinh thần **80% bề mặt đặc `#181B22`** trong `DESIGN.md` khi dùng cho thẻ danh sách, form, nội dung dài.
  - `MetaGymHeroGlassCard` (dùng **37 lần** trên 25+ màn hình) bọc `BackdropFilter(sigma: 10)` nhưng **không bọc `RepaintBoundary`** và **không tắt blur khi `MediaQuery.disableAnimationsOf(context)` bật**.
  - `conversations_page.dart` có **6** lớp blur/glass; `member_training_hub_page.dart` có **5** lớp blur/glass → nguy cơ tụt FPS khi cuộn nhanh trên máy demo thực tế.
- **Hành động đề xuất:**
  1. Bổ sung `RepaintBoundary` và kiểm tra `MediaQuery.disableAnimationsOf(context)` ngay bên trong `MetaGymHeroGlassCard` và `MetaGymGlassCard`.
  2. Chuyển mặc định hoặc rà soát các thẻ nội dung dài / danh sách sang `solid: true` (`#181B22` + viền `1px #262A34`).

### [WARNING-01] God-Files UI khó bảo trì & dễ phát sinh lỗi Overflow
- **Top 8 file UI lớn nhất cần tách modular widget khi Fix/Update:**
  1. `coach/presentation/coach_home_page.dart` — **3.591 dòng**, 97 hex colors
  2. `profile/presentation/profile_page.dart` — **3.393 dòng**, 118 hex colors
  3. `messaging/presentation/conversations_page.dart` — **3.073 dòng**, 83 hex colors, 6 blurs
  4. `progress/presentation/member_journal_page.dart` — **2.683 dòng**, 111 hex colors, 14 Material colors
  5. `training/presentation/nutrition_tracking_page.dart` — **2.577 dòng**, 42 hex colors
  6. `sessions/presentation/coach_booking_page.dart` — **2.486 dòng**, 125 hex colors
  7. `member/presentation/member_dashboard_view.dart` — **1.995 dòng**, 4 blurs
  8. `training/presentation/member_training_hub_page.dart` — **1.533 dòng**, 5 blurs

### [WARNING-02] Khoảng trống SafeArea, State Coverage & Tabular Figures
- **SafeArea / Keyboard inset:** Cần kiểm tra thực tế trên thiết bị 375px + bàn phím ảo cho nhóm `catalog/*`, `progress/*` (`measurement`, `photo`, `progress`), `training/coach_*`, `meal_plans_page`, `member_day_plan_page`, `calls_page`.
- **State Coverage:** Bổ sung trạng thái `Error/Retry` rõ ràng cho `coach_booking_history_page` và `member_day_plan_page`; bổ sung `Loading` cho `meal_plans_page`, `coach_nutrition_editor_page`, `live_call_page`.
- **Tabular Figures (`tnum`):** Đảm bảo toàn bộ giá tiền (VNĐ), số ngày còn lại, calo/macro, cân nặng, bộ đếm thời gian đều dùng `MetaGymTheme.tabularFigures`.

### [PASS] Các điểm mạnh đã làm tốt cần giữ vững
- `MetaGymBottomNav`: Cô lập `RepaintBoundary`, tôn trọng `disableAnimations`, có `useSolidFallback`, vùng chạm `48×48dp`, có `contentBottomPadding(context)` chống che nội dung.
- `MetaGymCircleIconButton`: Vùng chạm `48×48dp` (vòng hiển thị `44×44`), có `Semantics`, `Tooltip` và khóa chống nhấn đúp (`_tapGuard`).
- `app_router.dart`: Transition mượt (`Fade` + `Slide`), tự tắt khi bật Reduced Motion.
- Tiếng Việt đồng nhất trên các nhãn trạng thái chính.

---

## 3. Lộ trình Fix - Update đề xuất (Ưu tiên theo tác động)

1. **Đợt 1 — Lõi Design System (Tác động toàn app trong 1 lần sửa):**
   - Chuẩn hóa `app_theme.dart` (`#F7F9FC`, token warm-glass, hover/glass alignment).
   - Bọc `RepaintBoundary` + `disableAnimations` fallback trong `MetaGymHeroGlassCard` & `MetaGymGlassCard`.
2. **Đợt 2 — Các màn hình chính của Hội viên (Demo Path):**
   - `member_home_page` / `member_dashboard_view` → `member_training_hub_page` → `nutrition_tracking_page` → `coach_booking_page` → `membership_page`.
3. **Đợt 3 — Nhóm Trợ lý AI, Tin nhắn, Tiến độ & Hồ sơ:**
   - `ai_conversations_page` / `ai_messages_page`, `conversations_page`, `member_journal_page`, `member_progress_page`, `profile_page`.
4. **Đợt 4 — Nhóm Coach & Màn hình phụ:**
   - `coach_home_page`, `coach_sessions_page`, `coach_members_page`, `catalog/*`, `auth/*`.
