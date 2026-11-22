# Thư mục `images/catalog` — Hình ảnh Thiết bị Phòng Gym & Thumbnail Bài tập

## 1. Vị trí sử dụng trên App & Web
- **Danh sách & Chi tiết Thiết bị Phòng Gym (`CatalogItem`):**
  - `mobile-app/lib/features/catalog/presentation/gym_equipment_page.dart`
  - `mobile-app/lib/features/catalog/presentation/equipment_detail_page.dart`
- **Thư viện Bài tập & Khung xem trước Video:**
  - `mobile-app/lib/features/catalog/presentation/exercise_library_page.dart`
  - `mobile-app/lib/features/catalog/presentation/exercise_video_player.dart`
- **Cổng Quản trị Web Admin (Màn 11 — Thiết bị & Thư viện bài tập):** `admin-web` (`#/admin/catalog-training`)

## 2. Mô tả thiết kế & Quy chuẩn kỹ thuật (`gym-space-bible.md` — Zone 2, 3, 4)
- **Bối cảnh chụp thiết bị:** Đặt đúng trong không gian tầng trệt của Meta Gym (sàn cao su EPDM đen mờ, tường bê tông than chì và lam gỗ óc chó mờ nhẹ phía sau). Đèn spotlight trần rọi tập trung từ trên xuống giúp tách khối từng máy tập rõ ràng.
- **Ngôn ngữ thiết bị:** Khung thép sơn tĩnh điện đen mờ (matte charcoal/black), đệm da đen cao cấp, bánh tạ hoặc chi tiết điểm nhấn màu cam san hô `#FF5E36` tinh tế.
- **Kích thước & Dung lượng:**
  - Ảnh thiết bị theo danh mục / từng máy: `800×600` (`4:3`) hoặc `600×600` (`1:1`), định dạng `.webp` (`≤ 35–50 KB`).
  - Thumbnail bài tập (khung preview 16:9 trước khi phát video): `800×450` (`16:9`), định dạng `.webp` (`≤ 35–50 KB`).

## 3. Danh sách `assetKey` trong thư mục
- `default.jpg`: Ảnh mặc định hiện hành.
- **Ảnh đại diện theo nhóm thiết bị:**
  - `equip_cardio_treadmill.webp`: Máy chạy bộ / Khu Cardio (Zone 4 sát kính tầng trệt — khớp dữ liệu seed *"Máy chạy bộ demo"*).
  - `equip_free_weight_rack.webp`: Giàn Power Rack & Ghế tạ đơn (Zone 2).
  - `equip_selectorized_machine.webp`: Máy tập kháng lực khối tạ (Zone 3).
  - `equip_cable_crossover.webp`: Giàn kéo cáp đa năng (Zone 3).
- **Thumbnail bài tập mẫu:**
  - `exercise_warmup_walk.webp`: Đi bộ khởi động trên máy chạy bộ (khớp dữ liệu seed *"Đi bộ khởi động demo"*).
  - `exercise_strength_default.webp`: Thumbnail mặc định cho bài tập kháng lực khi chưa có thumbnail riêng từ video.
