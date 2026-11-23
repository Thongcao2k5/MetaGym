# Thư mục `images/backgrounds` — Ảnh nền Không gian Phòng Gym (Desktop & Mobile)

## 1. Vị trí sử dụng trên App & Web
- **Màn hình Đăng nhập / Đăng ký (`bg_exterior_*`):** `mobile-app/lib/features/auth/presentation/auth_glass_scaffold.dart`, `login_page.dart`, `register_page.dart` và trang đăng nhập `admin-web`.
- **Trang chủ Hội viên & Trung tâm Tập luyện (`bg_interior_*`):** `mobile-app/lib/features/member/presentation/member_dashboard_view.dart`, `member_training_hub_page.dart`, `meta_gym_glass_surface.dart`.
- **Trang chủ Huấn luyện viên (`bg_coach_home_*`):** `mobile-app/lib/features/coach/presentation/coach_home_page.dart`.

## 2. Mô tả thiết kế & Quy chuẩn kỹ thuật (`gym-space-bible.md`)
- **Bối cảnh:** 100% **Tầng trệt mặt đất (Ground-Floor Street-Level)** của studio flagship Meta Gym tại Việt Nam lúc chạng vạng (Blue-hour dusk).
  - **Trước phòng Gym (Zone 1):** Mặt tiền bê tông than chì, trần lam gỗ óc chó, bảng hiệu `MetaGym` (`M`, `G` cam `#FF5E36`), nhìn xuyên qua kính thấy quầy lễ tân đá đen nguyên khối và cổng QR check-in, phía trước là vỉa hè đá bazan và phố Việt Nam.
  - **Trong phòng Gym (Zone 2 & 3):** Khu tạ tự do (rack đen, bánh tạ viền cam mảnh, gương đèn hắt dọc ấm), cuối phòng là vách kính sọc mờ (Zone 5 Studio PT), bên phải là máy tập kháng lực cạnh cửa kính tầng trệt nhìn ra vỉa hè, cây xanh và phố ngang tầm mắt.
- **Bố cục UI-Safe Framing:** Chừa khoảng tối tự nhiên ở 25–30% đỉnh (trần/bầu trời tối) và 30% đáy (sàn cao su/vỉa hè đá đen) để chữ trắng `#F7F9FC` và các thẻ Glass đọc sắc nét.
- **Định dạng & Ngân sách dung lượng:** `.webp` (`quality: 82`), Desktop `1376×768` (`≤ 180 KB`), Mobile `768×1376` (`≤ 120 KB`).

## 3. Danh sách tệp trong thư mục
- `bg_exterior_desktop.webp` (`1376×768`, `125.9 KB`) — Trước phòng Gym (Desktop `16:9`).
- `bg_exterior_mobile.webp` (`768×1376`, `41.7 KB`) — Trước phòng Gym (Mobile `9:16`).
- `bg_interior_desktop.webp` (`1376×768`, `96.9 KB`) — Trong phòng Gym tầng trệt (Desktop `16:9`).
- `bg_interior_mobile.webp` (`768×1376`, `73.6 KB`) — Trong phòng Gym tầng trệt (Mobile `9:16`).
- `default.png`: Ảnh nền gốc đối chiếu.
