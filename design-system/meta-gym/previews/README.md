# Tổng Quan Bộ Xem Trước & Bản Review Toàn Hệ Thống Tài Nguyên Meta Gym (`previews/`)

Thư mục này lưu trữ trực tiếp trong source code (`design-system/meta-gym/previews/`) toàn bộ **15 bản Markdown Review (`.md`)** và **16 Bảng Contact Sheet Trực Quan (`previews/sheets/*.webp`)** của hệ thống tài nguyên **Meta Gym Design System** (`377 SVG` + `4 WebP Backgrounds`), được tổ chức theo đúng **Kiến trúc 3 Tầng Icon Ứng dụng Di động**:
- **Tầng A — Bộ Lõi Dùng Chung (`Core UI Icons`):** Hành động chung (`common_*`), Trạng thái phản hồi (`state_*`), Tài khoản & Bảo mật (`auth_*`), Giao tiếp (`comm_*`), Media & File (`media_*`), Thời gian & Vị trí (`time_*`, `location_*`), Tương tác xã hội (`social_*`), Cài đặt hệ thống (`setting_*`), Thanh toán cơ bản (`payment_*`) và Dữ liệu (`stats_*`).
- **Tầng B — Bộ Đặc Thù Theo Lĩnh Vực (`Gym, Fitness & Health Domain Pack`):** Tập luyện (`workout_*`), Bản đồ cơ & Chip lọc nhóm cơ (`muscle_*`), Dụng cụ phòng tập (`equip_*`), Chỉ số cơ thể & Sinh hiệu (`body_*`, `measure_*`, `stats_*`), Dinh dưỡng (`food_*`, `macro_*`, `meal_*`), Thành tích & Gamification (`reward_*`), Huấn luyện viên & Y tế (`coach_*`, `health_*`), Gói tập & Premium (`membership_*`, `premium_*`).
- **Tầng C — Bộ Minh Họa & Thương Hiệu (`Illustrations & Brand Pack`):** Logo MetaGym, App Store Icon, Notification Monochrome, Đăng nhập thương hiệu (`Google`, `Apple`, `Facebook`, `Zalo`), Cổng thanh toán Việt Nam (`VNPay`, `MoMo`, `ZaloPay`, `Napas`, `Visa`, `Mastercard`), Cờ ngôn ngữ (`VN`, `EN`), 3 Minh họa Onboarding, 13 Empty States, 3 Khung ngắm tư thế chụp ảnh tiến độ (`photo_pose_*`) và 4 Ảnh nền kiến trúc phòng tập.

---

## 1. Bảng Thống Kê Toàn Bộ 15 Bộ Tài Nguyên Đã Hoàn Thiện (`377 SVG` + `4 WebP Backgrounds`)

| STT | Phân hệ / Thư mục | Tầng Kiến Trúc | Số lượng File | Bản Review Chi Tiết (`.md`) | Bảng Contact Sheet (`.webp`) | Tài liệu Kỹ thuật (`README.md`) |
| :-: | :--- | :---: | :---: | :--- | :--- | :--- |
| 1 | **Ảnh Nền Kiến Trúc Phòng Tập (`images/backgrounds/`)** | **Tầng C** | `4 WebP` (+ `1 default`) | [meta_gym_backgrounds_preview.md](./meta_gym_backgrounds_preview.md) | `bg_exterior_*`, `bg_interior_*` | [backgrounds/README.md](../assets/images/backgrounds/README.md) |
| 2 | **Thương Hiệu, Đăng Nhập, Cổng Thanh Toán VN, Cờ & Onboarding (`svg/brand/`)** | **Tầng C** | `22 SVG` | [brand_assets_preview.md](./brand_assets_preview.md) | [brand_svg_sheet.webp](./sheets/brand_svg_sheet.webp) | [brand/README.md](../assets/svg/brand/README.md) |
| 3 | **Điều Khiển Tập Luyện & Buổi Tập Trực Tiếp (`svg/workout/`)** | **Tầng B** | `15 SVG` | [workout_assets_preview.md](./workout_assets_preview.md) | [workout_svg_sheet.webp](./sheets/workout_svg_sheet.webp) | [workout/README.md](../assets/svg/workout/README.md) |
| 4 | **Thiết Bị Phòng Tập, Dụng Cụ & Thư Viện Bài Tập (`svg/catalog/`)** | **Tầng B** | `20 SVG` | [catalog_assets_preview.md](./catalog_assets_preview.md) | [catalog_svg_sheet.webp](./sheets/catalog_svg_sheet.webp) | [catalog/README.md](../assets/svg/catalog/README.md) |
| 5 | **Gói Huấn Luyện Viên, Sức Khỏe & Cam Kết (`svg/coaching/`)** | **Tầng B** | `12 SVG` | [coaching_assets_preview.md](./coaching_assets_preview.md) | [coaching_svg_sheet.webp](./sheets/coaching_svg_sheet.webp) | [coaching/README.md](../assets/svg/coaching/README.md) |
| 6 | **Thành Tích, Gamification, Cộng Đồng & Giao Tiếp (`svg/community/`)** | **Tầng A & B** | `26 SVG` | [community_assets_preview.md](./community_assets_preview.md) | [community_svg_sheet.webp](./sheets/community_svg_sheet.webp) | [community/README.md](../assets/svg/community/README.md) |
| 7 | **Hạng Gói Tập Gym, Quyền Lợi Premium & Thanh Toán Cơ Bản (`svg/membership/`)** | **Tầng A & B** | `20 SVG` | [membership_assets_preview.md](./membership_assets_preview.md) | [membership_svg_sheet.webp](./sheets/membership_svg_sheet.webp) | [membership/README.md](../assets/svg/membership/README.md) |
| 8 | **Giải Phẫu Nhóm Cơ Toàn Thân & Chip Lọc Mobile Focus `1:1` (`svg/muscles/`)** | **Tầng B & C** | `62 SVG` (`31 Full` + `31 Focus 1:1`) | [muscles_assets_preview.md](./muscles_assets_preview.md) | [muscles_svg_sheet.webp](./sheets/muscles_svg_sheet.webp) · [muscles_detailed_svg_sheet.webp](./sheets/muscles_detailed_svg_sheet.webp) · [muscles_mobile_focus_sheet.webp](./sheets/muscles_mobile_focus_sheet.webp) | [muscles/README.md](../assets/svg/muscles/README.md) |
| 9 | **Thanh Điều Hướng Đáy 3 Trạng Thái (`outline`/`filled`/`disabled`) & AI Coach (`svg/navigation/`)** | **Tầng A & B** | `30 SVG` | [navigation_assets_preview.md](./navigation_assets_preview.md) | [navigation_svg_sheet.webp](./sheets/navigation_svg_sheet.webp) | [navigation/README.md](../assets/svg/navigation/README.md) |
| 10 | **Chỉ Số Dinh Dưỡng Macro, 4 Bữa Ăn, Nước & Quét Mã Vạch (`svg/nutrition/`)** | **Tầng B** | `20 SVG` | [nutrition_assets_preview.md](./nutrition_assets_preview.md) | [nutrition_svg_sheet.webp](./sheets/nutrition_svg_sheet.webp) | [nutrition/README.md](../assets/svg/nutrition/README.md) |
| 11 | **Tiến Độ, Số Đo Cơ Thể, Sinh Hiệu, Dữ Liệu & 3 Khung Ngắm Chụp Ảnh (`svg/progress/`)** | **Tầng A, B & C** | `31 SVG` (`28 Icon` + `3 Pose Guide`) | [progress_assets_preview.md](./progress_assets_preview.md) | [progress_svg_sheet.webp](./sheets/progress_svg_sheet.webp) | [progress/README.md](../assets/svg/progress/README.md) |
| 12 | **Thao Tác Nhanh Trang Chủ Member & Coach (`svg/quick_actions/`)** | **Tầng B** | `12 SVG` | [quick_actions_assets_preview.md](./quick_actions_assets_preview.md) | [quick_actions_svg_sheet.webp](./sheets/quick_actions_svg_sheet.webp) | [quick_actions/README.md](../assets/svg/quick_actions/README.md) |
| 13 | **Điểm Danh QR, Streak, 13 Empty States & 14 Trạng Thái Hệ Thống (`svg/states/`)** | **Tầng A & C** | `31 SVG` | [states_assets_preview.md](./states_assets_preview.md) | [states_svg_sheet.webp](./sheets/states_svg_sheet.webp) | [states/README.md](../assets/svg/states/README.md) |
| 14 | **Bộ Lõi Hành Động Chung, Bảo Mật, Media, Vị Trí, Cài Đặt & Thiết Bị Đeo (`svg/setting/`)** | **Tầng A & B** | `75 SVG` | [setting_assets_preview.md](./setting_assets_preview.md) | [setting_svg_sheet.webp](./sheets/setting_svg_sheet.webp) | [setting/README.md](../assets/svg/setting/README.md) |
| 15 | **Tuyển Tập Biểu Tượng Tư Thế Gymmer (`Gymmer Poses Upgrade`)** | **Tầng B & C** | `16 SVG` *(trên 8 thư mục)* | [gymmer_poses_analysis_preview.md](./gymmer_poses_analysis_preview.md) | [gymmer_poses_updated_sheet.webp](./sheets/gymmer_poses_updated_sheet.webp) | — |

---

## 2. Toàn Cảnh Trực Quan (Visual Gallery)

### 2.1. `svg/brand` — Thương Hiệu, Đăng Nhập, Cổng Thanh Toán VN, Cờ & Onboarding (`22 SVG`)
![Brand SVG Sheet](./sheets/brand_svg_sheet.webp)

### 2.2. `svg/workout` — Điều Khiển Tập Luyện & Buổi Tập Trực Tiếp (`15 SVG`)
![Workout SVG Sheet](./sheets/workout_svg_sheet.webp)

### 2.3. `svg/catalog` — Thiết Bị Phòng Tập, Dụng Cụ & Thư Viện Bài Tập (`20 SVG`)
![Catalog SVG Sheet](./sheets/catalog_svg_sheet.webp)

### 2.4. `svg/coaching` — Gói Huấn Luyện Viên, Sức Khỏe & Cam Kết (`12 SVG`)
![Coaching SVG Sheet](./sheets/coaching_svg_sheet.webp)

### 2.5. `svg/community` — Thành Tích, Gamification, Cộng Đồng & Giao Tiếp (`26 SVG`)
![Community SVG Sheet](./sheets/community_svg_sheet.webp)

### 2.6. `svg/membership` — Hạng Gói Tập Gym, Quyền Lợi Premium & Thanh Toán Cơ Bản (`20 SVG`)
![Membership SVG Sheet](./sheets/membership_svg_sheet.webp)

### 2.7. `svg/muscles` — Giải Phẫu Nhóm Cơ Toàn Thân (`31 SVG`) & Mobile Focus `1:1` (`31 SVG`)
![Muscles Core 12 SVG Sheet](./sheets/muscles_svg_sheet.webp)
![Muscles Granular 14 SVG Sheet](./sheets/muscles_detailed_svg_sheet.webp)
![Muscles Mobile Focus 26 SVG Sheet](./sheets/muscles_mobile_focus_sheet.webp)

### 2.8. `svg/navigation` — Thanh Điều Hướng Đáy 3 Trạng Thái (`outline` / `filled` / `disabled`) & Nút AI Coach (`30 SVG`)
![Navigation SVG Sheet](./sheets/navigation_svg_sheet.webp)

### 2.9. `svg/nutrition` — Chỉ Số Dinh Dưỡng (Macro), 4 Bữa Ăn, Nước & Quét Mã Vạch (`20 SVG`)
![Nutrition SVG Sheet](./sheets/nutrition_svg_sheet.webp)

### 2.10. `svg/progress` — Tiến Độ, Số Đo Cơ Thể, Sinh Hiệu, Dữ Liệu & 3 Khung Ngắm Chụp Ảnh (`31 SVG`)
![Progress SVG Sheet](./sheets/progress_svg_sheet.webp)

### 2.11. `svg/quick_actions` — Thao Tác Nhanh Trang Chủ Member & Coach (`12 SVG`)
![Quick Actions SVG Sheet](./sheets/quick_actions_svg_sheet.webp)

### 2.12. `svg/states` — Điểm Danh QR, Streak, 13 Empty States & 14 Trạng Thái Hệ Thống (`31 SVG`)
![States SVG Sheet](./sheets/states_svg_sheet.webp)

### 2.13. `svg/setting` — Bộ Lõi Hành Động Chung, Bảo Mật, Media, Vị Trí, Cài Đặt & Thiết Bị Đeo (`75 SVG`)
![Setting SVG Sheet](./sheets/setting_svg_sheet.webp)

### 2.14. `Gymmer Poses Upgrade` — Tuyển Tập Biểu Tượng Tư Thế Gymmer Thể Hình Thực Tế
![Gymmer Poses Updated Sheet](./sheets/gymmer_poses_updated_sheet.webp)
