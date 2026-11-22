# Thư mục `svg/muscles` — Giải phẫu Nhóm cơ Mục tiêu (`MuscleFocus`)

## 1. Vị trí sử dụng trên App & Web
- **Widget Giải phẫu Cơ thể Hội viên & HLV:**
  - `mobile-app/lib/core/widgets/muscle_anatomy_tile.dart`
  - `mobile-app/lib/features/sessions/presentation/coach_muscle_anatomy_tile.dart`
- **Màn hình Tự tập & Lưu Icon Lịch tập Cá nhân:** `mobile-app/lib/features/training/presentation/member_self_training_page.dart`, `self_training_icon_store.dart`
- **Bộ lọc Thư viện Bài tập & Thiết bị:** `mobile-app/lib/features/catalog/presentation/exercise_library_page.dart`, `gym_equipment_page.dart`
- **Cổng Quản trị Web Admin (Màn 11):** `admin-web` (`#/admin/catalog-training`)

## 2. Mô tả thiết kế & Quy chuẩn kỹ thuật (`svg-icon-craft-rules.md`)
- **Ánh xạ Key-Value chuẩn:** Khớp 1-1 với `enum MuscleFocus` trong `muscle_anatomy_tile.dart` (`chest`, `shoulders`, `back`, `arms`, `core`, `legs`, `glutes`, `upper`, `full`, `cardio`, `none`).
- **Ngôn ngữ tạo hình "Full-Body Segmented Fascia Muscle Map":**
  - Toàn bộ 12 tệp đều là sơ đồ giải phẫu cơ thể vận động viên **toàn thân từ đầu đến bàn chân** (`viewBox="0 0 180 330"`), bao gồm đầy đủ mái tóc, vành tai, bàn tay 5 ngón xòe, khung mạc cơ (Fascia base `#7E92B2` → `#5B6E8C`) và **162 bó cơ giải phẫu riêng biệt** (80 bó cơ mặt trước, 82 bó cơ mặt sau).
  - **Các bó cơ nền (chưa kích hoạt):** Tô chuyển sắc đá phiến tối `mus-*-muscle` (`#283347` → `#1B2333`), tách bạch rõ ràng với khung mạc cơ.
  - **Nhóm cơ mục tiêu đang kích hoạt (`hot`):** Tô chuyển sắc cam san hô rực rỡ `mus-*-hot` (`#FF8563` → `#FF5E36` → `#D63B16`) kèm viền sáng `#FFA88E` (`0.65px`).
- **Cơ chế Thích ứng Đa Nền tảng (Desktop Full-Body vs Mobile Focused Zoom `1:1`):**
  1. **Thư mục gốc `svg/muscles/*.svg` (26 tệp Full-Body — `viewBox="0 0 180 330"`):** Hiển thị toàn thân từ đầu đến bàn chân, dùng cho **Desktop / Web Admin**, thẻ giải phẫu lớn hoặc Modal xem chi tiết trên Mobile.
  2. **Thư mục con `svg/muscles/focus/*.svg` (26 tệp Mobile Focus — `viewBox` vuông `1:1` zoom cận cảnh `2x–3x`):** Cùng tên file 1-1 với thư mục gốc nhưng khung `viewBox` tự động khóa tâm và phóng cận cảnh thẳng vào đúng vùng cơ đang kích hoạt (kèm lớp `<mask>` làm mờ viền cắt `radialGradient` mềm mại). Nhờ đó khi hiển thị trong các ô tile nhỏ `44×44px` – `72×72px` trên **Điện thoại**, người dùng nhìn thấy ngay từng bó cơ Ngực, Vai, Tay trước, Tay sau, Cẳng tay, Cầu vai, Xô, Lưng dưới, 6 múi bụng, Đùi trước, Đùi sau, Bắp chân to rõ gấp 3 lần!
- **Tiền tố ID duy nhất:** `mus-<tên>-*` (cho bản Full-Body) và `foc-<tên>-*` (cho bản Mobile Focus).
- **Ngân sách dung lượng:** `~45 – 54 KB / file` (chứa trọn 80+ path Bézier giải phẫu độc lập).

## 3. Danh sách `assetKey` trong thư mục (26 tệp — Đầy đủ Nhóm Gộp & Nhóm Cơ Giải Phẫu Chuyên Sâu Thực Tế)

### A. 12 Tệp Nhóm cơ Cốt lõi (Khớp 1-1 `enum MuscleFocus` hiện tại trên App)
- `default.svg`: Sơ đồ giải phẫu mặt trước mặc định.
- `default_back.svg`: Sơ đồ giải phẫu mặt sau mặc định.
- `muscle_chest.svg`: **Ngực (`chest`)** — Cơ ngực lớn (Pectoralis Major).
- `muscle_shoulders.svg`: **Vai (`shoulders`)** — Cơ cầu vai (Deltoids).
- `muscle_back.svg`: **Lưng · Xô tổng hợp (`back`)** — Toàn bộ cơ thang, vai sau, cơ xô & lưng dưới.
- `muscle_arms.svg`: **Tay tổng hợp (`arms`)** — Cơ nhị đầu, cánh tay ngoài & cẳng tay.
- `muscle_core.svg`: **Bụng tổng hợp (`core`)** — Cơ bụng 6 múi + cơ liên sườn & răng cưa.
- `muscle_legs.svg`: **Chân · Đùi tổng hợp (`legs`)** — Toàn bộ cơ đùi, khép đùi & bắp chân.
- `muscle_glutes.svg`: **Mông (`glutes`)** — Cơ mông lớn, mông nhỡ & phần tiếp giáp đùi sau.
- `muscle_upper.svg`: **Thân trên (`upper`)** — Tổ hợp Ngực + Vai + Tay.
- `muscle_full.svg`: **Toàn thân (`full`)** — Toàn bộ các nhóm cơ chính từ đầu tới chân.
- `muscle_cardio.svg`: **Cardio (`cardio`)** — Vùng ngực/tim mạch kích hoạt kèm sóng xung nhịp ECG.

### B. 14 Tệp Nhóm cơ Chuyên sâu Thực tế (Rào trước cho Giáo án PT, Split Routine & Catalog Máy tập)
- **Tách riêng vùng Tay:**
  - `muscle_biceps.svg`: **Tay trước (Biceps & Brachialis)** — mặt trước cánh tay trên.
  - `muscle_triceps.svg`: **Tay sau (Triceps Brachii)** — mặt sau cánh tay trên.
  - `muscle_forearms.svg`: **Cẳng tay (Forearms)** — nhóm cơ gấp/duỗi cẳng tay.
- **Tách riêng vùng Vai & Lưng:**
  - `muscle_rear_delts.svg`: **Vai sau (Posterior Deltoids)** — mặt sau cầu vai.
  - `muscle_traps.svg`: **Cầu vai / Cơ thang (Trapezius)** — cơ thang cổ và lưng trên.
  - `muscle_lats.svg`: **Cơ xô (Latissimus Dorsi & Teres Major)** — hai cánh xô lưng giữa/ngoài.
  - `muscle_lower_back.svg`: **Lưng dưới (Lower Back / Erector Spinae)** — cơ dựng sống lưng & thắt lưng.
- **Tách riêng vùng Bụng (Core):**
  - `muscle_abs.svg`: **Cơ bụng thẳng 6 múi (Rectus Abdominis)** — trục bụng chính diện.
  - `muscle_obliques.svg`: **Cơ liên sườn & Răng cưa (Obliques & Serratus Anterior)** — hai bên thành bụng.
- **Tách riêng vùng Thân dưới (Lower Body):**
  - `muscle_quads.svg`: **Đùi trước (Quadriceps)** — 4 dải cơ mặt trước đùi.
  - `muscle_hamstrings.svg`: **Đùi sau (Hamstrings)** — 3 dải cơ gân kheo mặt sau đùi.
  - `muscle_calves.svg`: **Bắp chân (Calves / Gastrocnemius & Soleus)** — cơ bắp chuối cẳng chân sau.
  - `muscle_adductors.svg`: **Đùi trong / Khép đùi (Adductors & Hip Flexors)** — nhóm cơ khép đùi trong.
  - `muscle_lower.svg`: **Thân dưới tổng hợp (Lower Body)** — toàn bộ Đùi + Bắp chân cho buổi Leg Day.
