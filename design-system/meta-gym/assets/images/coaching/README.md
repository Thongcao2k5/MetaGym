# Thư mục `images/coaching` — Ảnh bìa Gói Coach & Chân dung Huấn luyện viên

## 1. Vị trí sử dụng trên App
- **Danh sách & Hồ sơ Chi tiết HLV:** `mobile-app/lib/features/coaching/presentation/coach_selection_page.dart`, `coach_detail_page.dart`
- **Thẻ Gói Coach (`CoachPackagePlan`) & Đặt lịch:** `coach_offers_page.dart`, `coach_booking_page.dart`, `member_coaching_page.dart`

## 2. Mô tả thiết kế & Quy chuẩn kỹ thuật (`gym-space-bible.md` — Zone 5 & Zone 2)
- **Bối cảnh:** Studio PT 1-1 bán riêng tư ngăn bằng vách kính sọc mờ (Zone 5) hoặc khu tạ tự do (Zone 2) trong phòng tập Meta Gym tầng trệt.
- **Nhân vật & Đồng phục:** HLV người Việt Nam (25–35 tuổi) mặc áo polo/áo tập thể thao màu đen charcoal có điểm nhấn màu cam `#FF5E36` nhỏ gọn bên ngực trái, thần thái điềm tĩnh, đang hướng dẫn kỹ thuật hoặc phân tích chỉ số cùng hội viên.
- **Kích thước & Dung lượng:**
  - Ảnh bìa gói Coach (`coach_cover_*`): `960×540` (`16:9`), `.webp` (`≤ 50–70 KB`).
  - Ảnh chân dung HLV mặc định (`coach_avatar_fallback`): `400×400` (`1:1`), `.webp` (`≤ 25–35 KB`).

## 3. Danh sách `assetKey` trong thư mục
- `default.jpg`: Ảnh mặc định hiện hành.
- `coach_cover_1on1.webp`: Ảnh bìa gói Kèm 1-1 tiêu chuẩn / trải nghiệm.
- `coach_cover_transformation.webp`: Ảnh bìa gói Chuyển đổi hình thể & Theo dõi chỉ số chuyên sâu.
- `coach_cover_strength.webp`: Ảnh bìa gói Tăng cơ & Sức mạnh kháng lực.
- `coach_avatar_fallback.webp`: Ảnh chân dung HLV mặc định (dùng kết hợp với avatar chữ `"LN"`).
