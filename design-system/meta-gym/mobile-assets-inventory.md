# Meta Gym Mobile — Danh mục Rà soát SVG & Hình ảnh (PD)

> **Tài liệu chuẩn:** Kế thừa từ [`../../DESIGN.md`](../../DESIGN.md), [`MASTER.md`](./MASTER.md) (phong cách **Futuristic Performance Glass**), [`svg-icon-craft-rules.md`](./svg-icon-craft-rules.md) (Quy chuẩn thiết kế SVG **Soft-Line Duotone & Craft Rules** đúc kết từ ảnh mẫu & `mengto/skills` + `shaom/brand-to-design-md-skill`) và [`gym-space-bible.md`](./gym-space-bible.md) (Hồ sơ Không gian & Bối cảnh Cửa hàng Meta Gym).
> **Kho lưu trữ Design System:** Toàn bộ tài nguyên gốc được đặt tại `design-system/meta-gym/assets/` (tách riêng `svg/` và `images/`), tối ưu để dùng chung sắc nét trên cả **Desktop** và **Mobile** với dung lượng nhẹ nhất.
> **Nguyên tắc rào trước key-value:** Mọi SVG và ảnh PD đều được định danh bằng `assetKey` thống nhất trước khi tích hợp vào BE/CMS, Admin Web hoặc Flutter, tránh hardcode tên file rời rạc hoặc lệch key giữa BE và FE.

---

## 1. Quy chuẩn kỹ thuật & Ngân sách dung lượng (Desktop + Mobile)

### A. Quy chuẩn vẽ SVG (Vector — Sắc nét mọi màn hình từ Mobile tới Desktop 4K)
- **Thư mục đích:** `design-system/meta-gym/assets/svg/<category>/<assetKey>.svg` (có thư mục `default/` chứa fallback chung).
- **Dung lượng & Tối ưu:**
  - Icon / Badge tiêu chuẩn: **≤ 1.5 – 2.5 KB / file**.
  - Hình giải phẫu nhóm cơ / Minh họa Empty State: **≤ 3 – 6 KB / file**.
  - Chỉ dùng vector thuần (`<path>`, `<circle>`, `<rect>`, `<linearGradient>` tối giản); **tuyệt đối không** nhúng ảnh raster base64, không dùng `<filter>` blur phức tạp gây tụt FPS trên Mobile, làm tròn tọa độ tối đa 1–2 chữ số thập phân.
- **Kích thước `viewBox` chuẩn đa nền tảng:**
  - Icon điều hướng & Quick-Action: `viewBox="0 0 24 24"` (hoặc `0 0 32 32` cho quick-action squircle).
  - Huy hiệu (Gói Coach, Membership, Macro) & Giải phẫu nhóm cơ: `viewBox="0 0 64 64"` (hoặc `0 0 80 80`).
  - Minh họa trạng thái (Empty States / Pose Guide): `viewBox="0 0 160 120"`.
- **Nét vẽ (Stroke):** Đồng nhất `1.75px` – `2px`, bo tròn đầu nét (`stroke-linecap="round"`, `stroke-linejoin="round"`).
- **Bảng màu chuẩn & Quy tắc Tương thích Đa Giao diện (Dark & Light Mode Ready):**
  - Mặc dù App hiện vận hành ở `ThemeMode.dark`, toàn bộ SVG **bắt buộc phải hiển thị rõ ràng trên cả nền Tối (`#0F1115` / `#181B22`) lẫn nền Sáng (`#F5F7FA` / `#FFFFFF`)** để sẵn sàng nếu hệ thống bật chuyển đổi Sáng/Tối trong tương lai:
    1. **Nhóm Badge / Tile Icon (`64×64` trong `catalog`, `coaching`, `membership`, `progress`, `quick_actions`):** Luôn bọc trong khung Squircle tự thân (`fill="#181B22" stroke="#262A34"` hoặc viền màu ngữ nghĩa) để khóa độ tương phản nội bộ — đặt lên nền tối hay nền trắng đều nổi khối sắc nét, không bao giờ bị chìm nét sáng `#F7F9FC`.
    2. **Nhóm Icon Trần / Không khung nền (`24×24` trong `navigation`, `nutrition`, `default`):** Tuyệt đối không vẽ nét trắng `#FFFFFF` đơn độc trên nền trong suốt; sử dụng màu thương hiệu/ngữ nghĩa có độ tương phản cao trên cả hai nền (`#FF5E36`, `#2ECC71`, `#F39C12`, `#536685` / `#64748B`, `#70AEE8`) hoặc cấu trúc tách riêng cho `brand` (`brand_wordmark_dark.svg` & `brand_wordmark_light.svg`).
  - Primary Accent (Coral Orange): `#FF5E36` *(điểm nhấn chính, vùng cơ mục tiêu, trạng thái active)*
  - Cool Reflection: `#A9C7E8` / `#70AEE8` *(viền sáng nhẹ, chi tiết công nghệ)*
  - Primary Light / Icon sáng (chỉ đặt bên trong khung tối tự thân): `#F7F9FC`
  - Secondary / Silhouette / Neutral Adaptive: `#8E95A5` / `#536685`
  - Semantic Success / Nutrition: `#2ECC71`
  - Semantic Warning / Coach Accent: `#F39C12` / `#F5B041`
  - Surface tối tự thân của Badge: `#181B22` và `#1F232C`, viền `#262A34`

### B. Quy chuẩn hình ảnh từ PD (Raster: WebP / AVIF nhẹ, nét trên cả Desktop & Mobile)
- **Thư mục đích:** `design-system/meta-gym/assets/images/<category>/` (có thư mục `default/` chứa fallback chung).
- **Ngân sách dung lượng & Kích thước theo loại ảnh:**

| Nhóm ảnh | Thư mục | Kích thước chuẩn (Desktop & Mobile) | Định dạng | Dung lượng tối đa |
| :--- | :--- | :--- | :---: | :---: |
| **Ảnh nền (Backgrounds)** | `images/backgrounds/` | Desktop: `1920×1080` · Mobile: `1080×1920` (hoặc `900×1600`) | `.webp` (q=75–80) | **≤ 120 KB** (Mobile) / **≤ 180 KB** (Desktop) |
| **Ảnh bìa (Covers / Cards)** | `images/coaching/`, `images/explore/`, `images/membership/` | `960×540` (16:9) hoặc `800×500` (16:10) — hiển thị tốt trên cả card Desktop & Mobile `@2x/@3x` | `.webp` (q=80) | **≤ 50 – 70 KB** |
| **Ảnh thiết bị & Bài tập** | `images/catalog/` | `600×600` (1:1) hoặc `800×600` (4:3) nền tối đồng bộ `#181B22` | `.webp` (q=80) | **≤ 35 – 50 KB** |
| **Thumbnail món ăn & Avatar** | `images/nutrition/`, `images/profile/` | `400×400` (1:1) | `.webp` (q=80) | **≤ 20 – 30 KB** |

- **Phong cách & Scrim bắt buộc:** Môi trường tập luyện cao cấp, ánh sáng ấm vừa phải; ảnh nền hoặc cover luôn tương thích với lớp phủ tối `72–84%` (`#0F1115`) để chữ `#F7F9FC` đạt tương phản tối thiểu `4.5:1`.

---

## 2. Rà soát chi tiết theo từng phân hệ (`mobile-app/lib/`)

### 2.1. Thương hiệu, Khởi động & Xác thực (`public`, `auth`, `core`, `admin`)

| Vị trí / Màn hình | Nguồn file code | Loại | `assetKey` đề xuất | Mô tả & Ghi chú | Ưu tiên |
| :--- | :--- | :---: | :--- | :--- | :---: |
| App Launcher Icon (Android/iOS/Web) | `android/.../ic_launcher.png`, `web/icons/Icon-512.png` | **SVG + PNG** | `app_icon_mark`, `app_icon_512` | Hiện `ic_launcher.png` đang là icon mặc định Flutter; cần xuất từ SVG thương hiệu | P0 |
| Logo Mark & Wordmark MetaGym | `login_page.dart`, `register_page.dart`, `app_loading_page.dart` | **SVG** | `brand_mark`, `brand_wordmark_dark` | Đồng bộ concept chữ `M`, `G` màu `#FF5E36` trong splash animation | P0 |
| Thanh điều hướng đáy (5 tab) | `meta_gym_bottom_nav.dart` | **SVG** | `nav_home`, `nav_training`, `nav_coach_schedule`, `nav_messages`, `nav_profile` | Mỗi tab có cặp `outline` / `filled`; riêng nút giữa dùng `nav_ai_emblem` | P0 |
| Huy hiệu Quản trị (Admin Mobile) | `admin_home_page.dart` | **SVG** | `admin_badge` | Thay `Icons.admin_panel_settings_outlined` | P2 |
| Nền màn hình Đăng nhập / Đăng ký | `auth_glass_scaffold.dart` | **Ảnh PD** | `bg_auth` | Ảnh không gian gym tối, ánh sáng ấm nhẹ, phủ scrim tối | P1 |

### 2.2. Trang chủ Hội viên & HLV (`member`, `coach`)

| Vị trí / Màn hình | Nguồn file code | Loại | `assetKey` đề xuất | Mô tả & Ghi chú | Ưu tiên |
| :--- | :--- | :---: | :--- | :--- | :---: |
| Quick-Action Dock (Member) | `member_dashboard_view.dart` | **SVG** | `action_schedule`, `action_curriculum`, `action_nutrition`, `action_coach` | 4 icon đồng bộ cho Lịch tập, Giáo trình, Dinh dưỡng, Coach | P0 |
| Quick-Action & Thẻ (Coach) | `coach_home_page.dart` | **SVG** | `action_members`, `action_offers`, `action_coach_sessions`, `action_coach_plans` | Icon cho Học viên, Đề nghị, Lịch dạy, Giáo trình/Dinh dưỡng | P0 |
| Trạng thái Ngày nghỉ phục hồi | `member_dashboard_view.dart`, `coach_home_page.dart` | **SVG** | `rest_day_recovery` | Thay `Icons.spa_outlined` khi hôm nay là ngày nghỉ / không có lịch tập | P1 |
| Ảnh nền Trang chủ Member & Coach | `member_dashboard_view.dart`, `coach_home_page.dart` | **Ảnh PD** | `bg_member_home`, `bg_coach_home` | Tách riêng ảnh nền thay vì dùng chung `gym_banner.png` | P1 |
| Ảnh bìa Bài viết Khám phá | `member_explore_articles.dart` | **Ảnh PD** | `explore_gym_intro`, `explore_beginner_guide` | Khớp 2 giá trị `ExploreArticleType` (`gymIntroduction`, `beginnerGuide`) | P1 |

### 2.3. Tập luyện & Điểm danh (`training`)

| Vị trí / Màn hình | Nguồn file code | Loại | `assetKey` đề xuất | Mô tả & Ghi chú | Ưu tiên |
| :--- | :--- | :---: | :--- | :--- | :---: |
| Giải phẫu nhóm cơ mục tiêu | `muscle_anatomy_tile.dart`, `coach_muscle_anatomy_tile.dart`, `member_self_training_page.dart` | **SVG** | `muscle_chest`, `muscle_shoulders`, `muscle_back`, `muscle_arms`, `muscle_core`, `muscle_legs`, `muscle_glutes`, `muscle_upper`, `muscle_full`, `muscle_cardio` | Khớp 1-1 với `enum MuscleFocus`; silhouette `#8E95A5`/`#A9C7E8`, vùng cơ `#FF5E36` | P0 |
| Điểm danh QR & Chuyên cần | `gym_visits_page.dart` | **SVG** | `qr_scan_frame`, `streak_flame`, `checkin_badge`, `empty_visits` | Khung ngắm quét QR, huy hiệu streak, empty state | P1 |
| Empty state Tập luyện & Giáo trình | `member_training_page.dart`, `coach_training_page.dart` | **SVG** | `empty_workout`, `empty_curriculum` | Minh họa khi chưa có buổi tập hoặc giáo trình | P1 |
| Nền Training Hub | `member_training_hub_page.dart` | **Ảnh PD** | `bg_training_hub` | Ảnh nền khu vực tập luyện | P2 |

### 2.4. Dinh dưỡng (`training` — Nutrition)

| Vị trí / Màn hình | Nguồn file code | Loại | `assetKey` đề xuất | Mô tả & Ghi chú | Ưu tiên |
| :--- | :--- | :---: | :--- | :--- | :---: |
| Chỉ số Macro & 4 Bữa ăn theo BE | `nutrition_tracking_page.dart`, `member_nutrition_page.dart`, `meal_plans_page.dart` | **SVG** | `macro_kcal`, `macro_protein`, `macro_carbs`, `macro_fat`, `meal_breakfast` (`BREAKFAST`), `meal_lunch` (`LUNCH`), `meal_dinner` (`DINNER`), `meal_snack` (`SNACK`) | Khớp trực tiếp 4 mã bữa ăn trong `nutrition_tracking_page.dart:706-711` | P0 |
| Empty state Dinh dưỡng | `nutrition_tracking_page.dart`, `member_nutrition_page.dart`, `coach_nutrition_page.dart` | **SVG** | `empty_nutrition` | Thay `Icons.no_meals_outlined` khi chưa có thực đơn / món ăn | P1 |
| Ảnh món ăn mẫu (Catalog) | `nutrition_tracking_page.dart` | **Ảnh PD** | `food_placeholder` (+ URL món ăn từ BE) | Thumbnail món ăn phổ biến nếu BE mở catalog món có ảnh | P2 |

### 2.5. Huấn luyện viên, Gói Coach & Lịch tập (`coaching`, `sessions`)

| Vị trí / Màn hình | Nguồn file code | Loại | `assetKey` đề xuất | Mô tả & Ghi chú | Ưu tiên |
| :--- | :--- | :---: | :--- | :--- | :---: |
| Huy hiệu Gói Coach (`CoachPackagePlan`) | `coach_models.dart`, `coach_detail_page.dart`, `coach_offers_page.dart`, `coach_booking_page.dart`, `member_coaching_page.dart` | **SVG** | `coach_pkg_trial`, `coach_pkg_standard`, `coach_pkg_intensive`, `coach_pkg_1on1` | Hiện `CoachPackagePlan` chưa có `iconKey`/`imageUrl`; map theo `plan.code` hoặc `sessionCount` | P0 |
| Ảnh bìa Gói Coach & Chân dung HLV | `coach_selection_page.dart`, `coach_detail_page.dart`, `coach_offers_page.dart` | **Ảnh PD** | `coach_cover_1on1`, `coach_cover_transformation`, `coach_cover_strength`, `coach_avatar_fallback` | Ảnh huấn luyện 1-1 thực tế & chân dung HLV bên cạnh avatar chữ `"LN"` | P1 |
| Nghiệp vụ Coaching đặc thù | `member_coaching_page.dart`, `early_termination_widgets.dart`, `coach_member_detail_page.dart` | **SVG** | `coaching_freeze` (bảo lưu), `coaching_termination` (hủy sớm), `coach_achievement` (thành tựu học viên) | Thay `ac_unit_rounded`, `gavel_rounded`, `emoji_events_outlined` | P2 |
| Khai báo sức khỏe, Cam kết & Empty | `member_health_declaration_page.dart`, `member_outcome_consent_page.dart`, `coach_sessions_page.dart` | **SVG** | `health_shield`, `health_medical`, `health_injury`, `outcome_consent_badge`, `empty_coach`, `empty_sessions` | Thay `medical_information_outlined`, `healing_outlined` & trạng thái trống | P2 |

### 2.6. Thư viện Thiết bị & Bài tập (`catalog`)

| Vị trí / Màn hình | Nguồn file code | Loại | `assetKey` đề xuất | Mô tả & Ghi chú | Ưu tiên |
| :--- | :--- | :---: | :--- | :--- | :---: |
| Danh mục Máy tập | `gym_equipment_page.dart`, `equipment_detail_page.dart` | **Ảnh PD + SVG** | **PD:** ảnh từng máy · **SVG:** `equip_cardio`, `equip_free_weight`, `equip_cable`, `equip_machine` | Hiện đang dùng `Icons.fitness_center_rounded` thay cho ảnh máy | P1 |
| Thư viện Bài tập | `exercise_library_page.dart` | **Ảnh PD + SVG** | **PD:** thumbnail động tác · **SVG:** tái sử dụng bộ `muscle_*` | Ảnh preview trước khi phát video trong `exercise_video_player.dart` | P1 |

### 2.7. Tiến độ, Nhật ký & Đo lường (`progress`)

| Vị trí / Màn hình | Nguồn file code | Loại | `assetKey` đề xuất | Mô tả & Ghi chú | Ưu tiên |
| :--- | :--- | :---: | :--- | :--- | :---: |
| Chỉ số đo cơ thể | `member_measurement_page.dart` | **SVG** | `measure_weight`, `measure_bodyfat`, `measure_muscle`, `measure_waist`, `empty_measurements` | Icon chỉ số nhân trắc học & trạng thái chưa có dữ liệu | P1 |
| Tiến độ, Nhật ký & Khung chụp ảnh | `member_progress_page.dart`, `member_journal_page.dart`, `member_photo_page.dart` | **SVG** | `empty_progress`, `empty_journal`, `empty_photos`, `photo_pose_front`, `photo_pose_side`, `photo_pose_back` | Silhouette hướng dẫn góc chụp ảnh tiến độ cơ thể | P1 |

### 2.8. Gói tập Gym & Thanh toán (`membership`)

| Vị trí / Màn hình | Nguồn file code | Loại | `assetKey` đề xuất | Mô tả & Ghi chú | Ưu tiên |
| :--- | :--- | :---: | :--- | :--- | :---: |
| Hạng gói tập (`MembershipPlan`) | `membership_page.dart` | **SVG + Ảnh PD** | **SVG:** `membership_tier_basic`, `membership_tier_plus`, `membership_tier_vip`, `membership_active_seal` · **PD:** `membership_featured_cover` | Hiện `MembershipPlan` trong `membership_models.dart` mới có `id`, `name`, `price`, `durationDays`, `status` | P1 |
| Thanh toán & Lịch sử giao dịch | `membership_checkout_page.dart`, `payment_history_page.dart` | **SVG** | `payment_vnpay_badge`, `payment_success`, `payment_pending`, `empty_payments` | Trạng thái giao dịch & empty state | P2 |

### 2.9. AI Coach, Nhắn tin, Cuộc gọi, Hồ sơ & Trạng thái hệ thống (`ai`, `messaging`, `calls`, `profile`)

| Vị trí / Màn hình | Nguồn file code | Loại | `assetKey` đề xuất | Mô tả & Ghi chú | Ưu tiên |
| :--- | :--- | :---: | :--- | :--- | :---: |
| AI Coach | `ai_conversations_page.dart`, `ai_messages_page.dart` | **SVG** | `ai_coach_emblem`, `empty_ai_chat` | Thay `Icons.auto_awesome_rounded` | P0 |
| Tin nhắn & Cuộc gọi | `conversations_page.dart`, `calls_page.dart`, `live_call_page.dart` | **SVG** | `empty_messages`, `empty_calls`, `call_video_badge`, `call_audio_badge` | Trạng thái trống & badge loại cuộc gọi | P2 |
| Hỗ trợ CSKH & Hồ sơ | `profile_page.dart`, `member_coaching_page.dart` | **SVG + Ảnh PD** | **SVG:** `support_agent`, `photo_permission_guide` · **PD:** `avatar_member_fallback` | Thay `support_agent_rounded` / `headset_mic_outlined` | P2 |
| Trạng thái hệ thống dùng chung | `chat_message_image.dart`, `member_journal_page.dart`, `gym_equipment_page.dart`, `nutrition_tracking_page.dart` | **SVG** | `state_offline`, `state_error`, `state_broken_image`, `state_empty_search` | Thay `cloud_off_rounded`, `broken_image_outlined`, `search_off_rounded` cho ảnh lỗi & tìm kiếm trống | P1 |

---

## 3. Phạm vi KHÔNG vẽ SVG (giữ Material Rounded mặc định)

Qua quét toàn bộ **188 mã `Icons.*`** đang xuất hiện trong `mobile-app/lib/`, khoảng **~140 icon là micro-icon điều khiển hệ thống** (`arrow_back_rounded`, `chevron_right_rounded`, `close_rounded`, `check_rounded`, `refresh_rounded`, `add_rounded`, `edit_outlined`, `delete_outline_rounded`, `copy_rounded`, `visibility_outlined`, `mic_rounded`, `volume_up_rounded`, `search_rounded`...).

> **Quyết định kỹ thuật:** Giữ nguyên font icon Material Rounded cho nhóm micro-icon điều khiển hệ thống để giữ app nhẹ, tốc độ render nhanh và đồng bộ chuẩn Material 3 theo `DESIGN.md`. Chỉ thiết kế SVG tùy biến cho các nhóm **nhận diện thương hiệu, giải phẫu nhóm cơ, huy hiệu gói, chỉ số fitness/macro và minh họa trạng thái** đã liệt kê ở Mục 2.

---

## 4. Lộ trình triển khai đề xuất (không đụng code cho tới khi chốt asset)

1. **Đợt 1 (P0 — Nhận diện cốt lõi & Tác động thị giác cao nhất):**
   - Bộ `brand/` (`brand_mark`, `brand_wordmark_dark`, `ai_coach_emblem`)
   - Bộ `muscles/` (10 SVG nhóm cơ khớp `enum MuscleFocus`)
   - Bộ `icons/` (Quick Actions Member/Coach, 4 Macro + 4 Bữa ăn, 4 Huy hiệu Gói Coach)
   - Xuất kèm `mobile-app/assets/svg/svg_manifest.json` để rào sẵn key-value cho BE & FE.
2. **Đợt 2 (P1 — Empty States, Membership & Chụp tiến độ):**
   - Bộ `illustrations/` (`empty_workout`, `empty_nutrition`, `empty_progress`, `empty_measurements`, `empty_photos`, `photo_pose_*`, `qr_scan_frame`)
   - Bộ `badges/` (Membership tiers, Thiết bị fallback)
   - Bàn giao danh sách **Ảnh PD P1** (`bg_member_home`, `bg_coach_home`, `bg_auth`, `explore_*`, `coach_cover_*`, ảnh máy tập & bài tập).
3. **Đợt 3 (P2 — Hoàn thiện trạng thái phụ & Ảnh mở rộng):**
   - SVG cho `calls`, `messaging`, `payment`, `state_offline`, `state_error` và các ảnh PD bổ sung.
