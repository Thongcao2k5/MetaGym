# Meta Gym — Quy chuẩn Thiết kế SVG & Icon (Soft-Line Duotone & Craft Rules)

> **Nguồn đúc kết:**
> 1. **Tham chiếu thị giác trực tiếp:** Bộ icon **Soft-Line Duotone + Knockout Badge** (từ 5 ảnh chụp màn hình ứng dụng mẫu người dùng cung cấp).
> 2. **Phương pháp `mengto/skills` (`illustration/*`, `references/craft.md`, `workflow-score-to-target`):** Hợp đồng tệp SVG độc lập (SVG File Contract), tiền tố ID chống xung đột, tỷ lệ diện tích màu (Pixel Share Budget), kiểm tra chi tiết ở độ phóng đại lớn và vòng lặp **Render → Sheet → Critique (Rubric 8/10) → Lint**.
> 3. **Phương pháp `shaom/brand-to-design-md-skill`:** Phân loại bằng chứng thị giác (Direct Evidence → Role Mapping) và định nghĩa rõ 3 chiều cho mỗi token: *(Nguồn gốc — Dùng cho đâu — Cấm dùng ở đâu)*.
> 4. **Nguồn chuẩn cao nhất:** [`../../DESIGN.md`](../../DESIGN.md) và [`MASTER.md`](./MASTER.md).

---

## 1. Ngôn ngữ Thị giác Cốt lõi: "MetaGym Soft-Line Duotone"

**Mô tả trong một câu:** Mỗi icon là một vật thể bo góc mềm mại vẽ bằng đường viền mở (`2.2px`), bên trong phủ lớp chuyển sắc ửng cam san hô nhẹ (`3% → 28%`), kết hợp một huy hiệu hành động màu cam thương hiệu (`#FF5E36`) đặt lệch góc với khoảng hở ngắt nét (knockout gap) sạch sẽ.

### 1.1. 5 Quy tắc Tạo hình Bắt buộc (Tránh lỗi thô cứng & đơn điệu)

1. **Không đóng khung hộp vuông bên ngoài (No Heavy Outer Box):**
   - **Cấm:** Nhốt tất cả icon vào trong cùng một khung `<rect rx="16" fill="#181B22"/>` đồng phục.
   - **Bắt buộc:** Để chính đường bao đặc trưng của vật thể (tấm vé có rãnh khuyết bán nguyệt, tờ hướng dẫn có mép lượn, đôi bàn tay nâng trái tim, bánh tạ tròn, chiếc mũ vinh danh, máy chạy bộ...) làm khung hình tự thân.
2. **Đường nét mở & Khoảng hở ngắt nét (Open-Path & Knockout Gap):**
   - Đường viền của vật thể chính không đóng kín cứng nhắc mà **chủ động dừng lại trước huy hiệu phụ một khoảng `2.5–4px`** (hoặc dùng `<mask>`).
   - Các đầu nét ngắt luôn bo tròn (`stroke-linecap="round"`, `stroke-linejoin="round"`), tạo cảm giác thanh thoát, có nhịp thở.
3. **Lớp tô ửng chuyển sắc mềm (`Soft Gradient Blush`):**
   - Mọi vật thể chính đều có một lớp `<linearGradient>` chéo từ trên-trái xuống dưới-phải (`#FF5E36` từ `stop-opacity="0.03"` đến `0.28`).
   - Lớp tô này giúp icon có chiều sâu mềm mại, tách biệt khỏi nền mà không làm nặng nề nét vẽ.
4. **Cấu trúc 2 lớp "Thân chính + Huy hiệu hành động `#FF5E36`":**
   - **Lớp 1 (Thân vật thể chính):** Nét `#E8EDF5` (trên nền tối) / `#1E2229` (trên nền sáng), mang hình khối nhận diện cốt lõi.
   - **Lớp 2 (Badge / Chi tiết điểm nhấn `#FF5E36`):** Đặt ở góc dưới-phải (hoặc trên-phải / tâm điểm) — như dấu `+`, ngôi sao khởi đầu, vòng tròn nhịp tim, bánh răng cơ khí, chữ thập y tế, bút ký, ổ khóa bảo lưu — giúp phân biệt ngay chức năng của từng icon.
5. **Độ cong mềm mại & Chi tiết định danh (Self-Naming Details — theo `mengto/craft.md`):**
   - Một hình chữ nhật trống không tự nói lên nó là gì; phải thêm **chi tiết định danh đặc trưng** đọc được ngay ở kích thước `1x`: rãnh khuyết vé (`coach_pkg_trial`), nếp giấy cuộn & mép răng cưa mềm (`exercise_step_guide`), kẹp giấy đỉnh bìa (`health_medical`), dây tua rua mũ (`coach_achievement`).
6. **Quy tắc riêng cho Sơ đồ Giải phẫu Cơ thể (`svg/muscles` — Full-Body Segmented Fascia Muscle Map):**
   - **Bắt buộc** sử dụng sơ đồ giải phẫu vận động viên **toàn thân từ đầu đến bàn chân (`viewBox="0 0 180 330"`)** có đầy đủ mái tóc, vành tai, bàn tay 5 ngón xòe, khung mạc cơ nền (`#7E92B2` → `#5B6E8C`) và **162 bó cơ giải phẫu tách rãnh riêng biệt** (80 bó cơ mặt trước, 82 bó cơ mặt sau).
   - Các bó cơ chưa kích hoạt tô `#283347` → `#1B2333`; chỉ các bó cơ thuộc nhóm `MuscleFocus` mục tiêu mới tô chuyển sắc cam san hô `#FF8563` → `#FF5E36` → `#D63B16` (giữ nguyên màu trung tính cho bàn tay và bàn chân).

---

## 2. Bảng Token Vai trò & Tỷ lệ Diện tích Màu (Theo `shaom/brand-to-design-md` & `mengto/skills`)

| Vai trò Token | Giá trị | Nguồn gốc (Evidence) | Dùng cho đâu (Use for) | Cấm dùng ở đâu (Never use for) | Tỷ lệ diện tích |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **Không gian thoáng (`Canvas Clear`)** | `none` (trong suốt) | Ảnh mẫu ứng dụng & `DESIGN.md` | Vùng đệm xung quanh vật thể để icon "thở" | Không phủ nền kín toàn bộ `viewBox` | `~70–78%` |
| **Lớp ửng mềm (`Blush Fill`)** | `linearGradient` `#FF5E36` (`0.03 → 0.28`) | Đo trực tiếp từ hiệu ứng hồng/cam phấn trong lòng icon mẫu | Tô bên trong thân vật thể chính tạo khối mềm | Không tô đặc `100%` lên toàn bộ thân vật thể | `~12–18%` |
| **Nét thân chính (`Primary Contour`)** | `#E8EDF5` (Dark) / `#1E2229` (Light) | Nét chính tương phản cao trên nền thẻ | Đường bao vật thể chính, các vạch cấu trúc phụ | Không dùng cho huy hiệu điểm nhấn chính | `~5–7%` |
| **Điểm nhấn cam (`Coral Spot`)** | `#FF5E36` (kèm nền phụ `fill-opacity="0.16..0.22"`) | Token `colors.primary` trong `DESIGN.md` | Huy hiệu góc, tia năng lượng, chấm đầu dòng, chi tiết chuyển động | Không dùng làm đường viền cho toàn bộ vật thể | `~3–6%` |

### Thông số Hình học Chuẩn (`viewBox="0 0 48 48"`)
- **Nét thân chính (`Primary Stroke`):** `2.2px` (`2.0–2.1px` cho chi tiết nhỏ bên trong).
- **Nét huy hiệu điểm nhấn (`Accent Stroke`):** `2.1–2.4px`.
- **Bán kính bo góc (`Corner Radius`):** `5.5px – 8px` cho thân vật thể lớn; `2.5px – 3.5px` cho chi tiết nhỏ.
- **Lề an toàn (`Safe Margin`):** Tối thiểu `4px – 6px` tính từ mép `viewBox 48×48` tới nét ngoài cùng.

---

## 3. Hợp đồng Kỹ thuật Tệp SVG (SVG File Contract — Theo `mengto/craft.md`)

Mọi tệp `.svg` trong `design-system/meta-gym/assets/svg/` bắt buộc tuân thủ 5 điều khoản kỹ thuật sau để không bao giờ lỗi trên `flutter_svg` và trình duyệt Web:

1. **Tệp độc lập hoàn toàn:** Khai báo `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" fill="none">` (hoặc `80×92` cho giải phẫu cơ thể, `160×120` cho minh họa trạng thái trống).
2. **Chỉ dùng thuộc tính trình bày trực tiếp (Presentation Attributes Only):**
   - **Cấm:** `<style>`, `class`, `<script>`, `<image>`, `<foreignObject>`, `<filter>` Gaussian blur nặng.
   - *Lỗi ngăn chặn:* Tránh mất màu khi nhúng inline vào trang Web có CSS trùng tên class, hoặc không render được trên `flutter_svg`.
3. **Tiền tố ID duy nhất cho từng tệp (Unique ID Prefix per File):**
   - Mọi `id` trong `<defs>` (`linearGradient`, `clipPath`, `mask`) **bắt buộc** bắt đầu bằng tiền tố riêng của tệp đó (ví dụ: `id="cat-cardio-blush"`, `id="coa-trial-blush"`).
   - *Lỗi ngăn chặn:* Khi một màn hình hiển thị 10 icon SVG cùng lúc, nếu cả 10 tệp đều đặt `id="blush"`, 9 icon sau sẽ lấy nhầm tọa độ gradient của icon đầu tiên.
4. **Không dùng thẻ `<text>` trong Icon & Minh họa:**
   - Mọi ký hiệu (`+`, `✓`, `⚡`, số bước, chữ viết tắt) trong icon đều phải vẽ bằng `<path>` với `stroke-linecap="round"`. (Chỉ ngoại lệ cho file `brand_wordmark` hoặc chuyển luôn chữ thương hiệu thành path).
5. **Ngân sách dung lượng:**
   - Icon `48×48`: **`≤ 1.8 KB / file`**.
   - Giải phẫu cơ thể / Minh họa trạng thái: **`≤ 5.5 KB / file`**.

---

## 4. Quy trình Kiểm duyệt 4 Bước & Thang điểm 8/10 (Theo `mengto/workflow-score-to-target`)

Trước khi chốt bất kỳ thư mục SVG nào, Agent bắt buộc chạy vòng lặp kiểm duyệt sau:

1. **Render & Sheet (Bảng đặt cạnh nhau):**
   - Dùng `sharp` kết xuất toàn bộ các file `.svg` trong thư mục ra một bảng `.webp` ở kích thước thực và `2x`, đặt cạnh nhau để hỏi: *"Có giống cùng một bàn tay vẽ, cùng một bộ sản phẩm không?"* (độ dày nét, độ ửng gradient, tỷ lệ màu cam, khoảng thở).
2. **Kiểm tra điểm giao cắt (Zoom Check):**
   - Quan sát kỹ các vị trí nét mở (knockout gap) nơi thân vật thể gặp huy hiệu `#FF5E36`, đảm bảo không có nét đè chồng chéo hoặc góc nhọn bị lệch.
3. **Chấm điểm theo 5 Tiêu chí (`0 / 1 / 2` điểm mỗi mục — Ngưỡng đạt: `≥ 8/10`):**
   - **(1) Style Fidelity (2đ):** Đúng nét mở `2.2px`, đúng lớp ửng gradient `#FF5E36`, không có khung hộp vuông cứng.
   - **(2) Object Construction (2đ):** Hình khối mềm mại, có chi tiết định danh đặc trưng, không giống hình học thô.
   - **(3) Knockout & Badge Harmony (2đ):** Huy hiệu `#FF5E36` đặt đúng trọng tâm góc, khoảng hở ngắt nét sạch sẽ.
   - **(4) Composition & Margin (2đ):** Căn tâm cân đối, lề thoáng `≥ 4px`, mật độ chi tiết vừa phải (không quá trống, không rối).
   - **(5) 1x Readability & Craft (2đ):** Nhìn ở kích thước nhỏ trên màn hình điện thoại hiểu ngay ý nghĩa mà không cần đọc nhãn chữ.
4. **Lint kỹ thuật (Automated SVG Lint):**
   - Kiểm tra tự động: không có `<style>`/`<image>`, mọi `id` đều có prefix riêng theo tên file, dung lượng nằm trong ngân sách.

---

## 5. Kiến trúc 3 Tầng Icon Ứng dụng Di động & Quy ước Chuẩn hóa Toàn Hệ Thống

Một ứng dụng di động chuẩn sản phẩm được tổ chức thành **3 tầng icon rõ ràng** để tối ưu dung lượng, tốc độ render và sự đồng bộ thị giác giữa các màn hình:

### 5.1. Kiến trúc 3 Tầng (3-Tier Icon Architecture)

| Tầng | Tên tầng & Kích thước chuẩn | Phạm vi & Nguồn sử dụng trong Meta Gym |
| :--- | :--- | :--- |
| **Tầng A — Bộ Lõi Dùng Chung (`Core UI Icons`)** | **`24×24 px`** (`viewBox="0 0 24 24"`, stroke `1.75–2.0px`) | Các hành động vi mô & điều khiển hệ thống (`add`, `edit`, `delete`, `copy`, `paste`, `share`, `save`, `refresh`, `download`, `upload`, `filter`, `sort`, `search`, `more`, `chevron` 4 hướng, `back`, `close`, `menu`, `show/hide password`, `mic`, `mute`, `speaker`...).<br>**Chiến lược tối ưu:** Dùng thư viện chuẩn mở (**Material Symbols Rounded** trên Flutter / **Lucide** hoặc **Phosphor** trên Web) đồng bộ độ dày nét `1.75–2px`, kết hợp bộ SVG tùy biến cho **Thanh điều hướng (`svg/navigation/`)**, **Cài đặt & Bảo mật (`svg/setting/`)** và **Tiện ích thiết bị đeo (`common_bluetooth`, `common_wearable`)**. |
| **Tầng B — Bộ Đặc Thù Theo Lĩnh Vực (`Domain Pack — Gym, Fitness & Health`)** | **`48×48 px`** (`viewBox="0 0 48 48"`, stroke `2.2px` Soft-Line Duotone) + Bản đồ cơ `180×330` / Focus `100×100` | Toàn bộ các nhóm đặc thù của **Meta Gym** không thư viện mở nào có sẵn:<br>1. **Tập luyện & Điều khiển buổi tập (`svg/workout/`):** `workout_start`, `workout_pause`, `workout_stop`, `workout_rest_timer`, `workout_set_reps`, `workout_weight`, `workout_superset`, `workout_warmup`, `workout_cooldown`, `workout_add_exercise`, `workout_plan_calendar`, `workout_history`, `workout_favorite`, `workout_ai_coach`.<br>2. **Nhóm cơ & Thiết bị (`svg/muscles/`, `svg/catalog/`):** 26 bản đồ cơ toàn thân + 26 chip lọc nhóm cơ `1:1` (`muscle_chest`, `muscle_back`...) + thiết bị phòng tập (`equip_dumbbell`, `equip_barbell`, `equip_kettlebell`, `equip_machine`, `equip_cable`, `equip_resistance_band`, `equip_bodyweight`, `equip_treadmill`, `equip_bench`, `equip_mat`).<br>3. **Tiến độ, Sinh hiệu & Đo lường (`svg/progress/`):** Cân nặng, thước dây, tỷ lệ mỡ, BMI, biểu đồ đường/cột, kỷ lục cá nhân (PR), tổng khối lượng tạ (volume), nhịp tim, bước chân, giấc ngủ.<br>4. **Dinh dưỡng (`svg/nutrition/`):** 4 Macro, 4 Bữa ăn, nước uống, quét mã vạch (`food_scan_barcode`), ghi chép món nhanh (`food_log_add`).<br>5. **Huấn luyện viên & Y tế (`svg/coaching/`, `svg/quick_actions/`):** Gói PT 1-1, khai báo sức khỏe, chấn thương, bảo lưu, thành tích, gamification & cộng đồng (`svg/community/`).<br>6. **Gói tập & Premium (`svg/membership/`):** Hạng thẻ Basic/Plus/VIP, vương miện Premium, mở khóa quyền lợi, hoàn tiền. |
| **Tầng C — Bộ Minh Họa & Thương Hiệu (`Illustrations & Brand Pack`)** | **`96–160 px`** (`viewBox="0 0 48 48"` mở rộng hoặc `160×120`, `180×330`) & Logo chuẩn hãng | 1. **Thương hiệu & Cửa hàng ứng dụng (`svg/brand/`):** `brand_mark`, `brand_wordmark_dark`, `brand_wordmark_light`, `app_icon_mark` (iOS/Android adaptive), `notification_small_monochrome` (đơn sắc cho thanh trạng thái), cờ ngôn ngữ (`flag_vn`, `flag_en`).<br>2. **Đăng nhập thương hiệu (`Brand Login`):** `auth_google`, `auth_apple`, `auth_facebook`, `auth_zalo` (theo chuẩn hình học chính thức của từng hãng).<br>3. **Cổng thanh toán thị trường Việt Nam (`Payment Gateways VN`):** `pay_vnpay`, `pay_momo`, `pay_zalopay`, `pay_napas`, `pay_visa`, `pay_mastercard`.<br>4. **Onboarding, Splash & Empty/System States (`svg/states/`):** Minh họa giới thiệu app, trạng thái trống (`empty_workout`, `empty_nutrition`...), trạng thái hệ thống (`state_error`, `state_offline`, `state_loading`, `state_success`, `state_warning`, `state_update`) và khung ngắm chụp ảnh cơ thể (`photo_pose_front/side/back`). |

---

### 5.2. 4 Quy ước Bắt buộc Trước & Trong Khi Vẽ Hàng Loạt

1. **Quy ước 3 Cấp Kích Thước (`3 Size Tiers`):**
   - **UI Icon (`24 px`):** Chi tiết tối giản (tối đa 2–3 nét), đọc rõ ở kích thước nhỏ trên thanh công cụ, danh sách cài đặt hoặc nút phụ.
   - **Feature Icon (`48 px`):** Phong cách **MetaGym Soft-Line Duotone** (thân chính nét mở `2.2px` + lớp ửng gradient `#FF5E36` + huy hiệu góc có khoảng hở knockout `2.5–4px`).
   - **Illustration (`96–160 px`):** Minh họa trạng thái hệ thống, empty states, onboarding và khung ngắm tư thế gymmer; có thêm vòng hào quang nền hoặc bóng đổ sàn mềm để lấp đầy không gian trống mà vẫn giữ dung lượng `≤ 3.5 KB`.

2. **Quy ước 3 Trạng Thái (`outline` / `filled` / `disabled`):**
   - Đặc biệt với thanh điều hướng (`svg/navigation/`):
     - **`outline` (Mặc định / Chưa chọn):** Nét viền thanh mảnh `#8E95A5`, lòng trong suốt.
     - **`filled` (Active / Đang chọn):** Tô lớp duotone chuyển sắc `#FF5E36` (`12% → 28%`) kèm đường nét & điểm nhấn cam san hô `#FF5E36` nổi bật.
     - **`disabled` (Vô hiệu hóa / Khóa tạm thời):** Nét đứt nhẹ hoặc nét liền màu xám trầm `#525A6B` (`opacity="0.45"`), không có điểm nhấn cam, giúp người dùng nhận biết ngay tính năng chưa khả dụng.

3. **Quy ước Token Màu Ngữ Nghĩa (`Semantic Color Tokens` & Biến Đổi Theme Sáng/Tối):**
   - Để các tệp SVG vừa chạy trực tiếp hoàn hảo trên `flutter_svg` (vốn cần mã hex fallback trực tiếp), vừa tự động đổi màu mượt mà trên Web/Admin hoặc thông qua `ColorFilter` / CSS Variables khi chuyển đổi Theme Sáng/Tối:
     - **`primary` (Hành động & Điểm nhấn chính):** `var(--mg-primary, #FF5E36)`
     - **`neutral` (Nét thân vật thể chính):** `var(--mg-neutral, #E8EDF5)` trên nền Tối / `#1E2229` trên nền Sáng (hoặc `currentColor` cho các icon đơn sắc 24px và `notification_small_monochrome`).
     - **`success` (Hoàn thành / Dinh dưỡng / Đang hoạt động):** `var(--mg-success, #2ECC71)`
     - **`warning` (Cảnh báo / Chuỗi Streak / HLV):** `var(--mg-warning, #F39C12)`
     - **`error` (Lỗi / Hủy / Cảnh báo chấn thương):** `var(--mg-error, #F15B64)`
     - **`info` (Ánh phản xạ lạnh / Nước / Bảo lưu):** `var(--mg-info, #A9C7E8)` / `#70AEE8`

4. **Quy ước Đặt Tên Chuẩn `nhóm_đối-tượng_hành-động` (`group_object_action`):**
   - Mọi tên tệp `assetKey` đều viết thường (`snake_case`), bắt đầu bằng tiền tố nhóm chức năng, theo sau là đối tượng và trạng thái/hành động:
     - Điều hướng: `nav_home_outline`, `nav_home_filled`, `nav_home_disabled`, `nav_workout_outline`...
     - Tập luyện: `workout_start`, `workout_rest_timer`, `workout_set_reps`, `workout_ai_coach`...
     - Nhóm cơ & Dụng cụ: `muscle_chest`, `equip_dumbbell`, `equip_kettlebell`, `equip_resistance_band`...
     - Chỉ số & Tiến độ: `body_weight_scale`, `body_bmi`, `stats_personal_record`, `stats_heart_rate`...
     - Dinh dưỡng: `food_meal`, `food_scan_barcode`, `food_log_add`, `macro_protein`...
     - Gamification & Cộng đồng: `reward_badge`, `reward_leaderboard`, `social_friends`, `social_share`...
     - Trạng thái: `state_error`, `state_no_network`, `state_loading`, `state_success`, `state_update`...
     - Thanh toán & Thương hiệu: `brand_mark`, `auth_google`, `pay_vnpay`, `pay_momo`, `premium_crown`...
