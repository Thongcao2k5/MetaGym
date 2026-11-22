# Thư mục `images/profile` — Ảnh Đại diện Mặc định (Avatar Fallback)

## 1. Vị trí sử dụng trên App
- **Hồ sơ Cá nhân Hội viên & HLV:** `mobile-app/lib/features/profile/presentation/profile_page.dart`
- **Danh sách Hội thoại & Cuộc gọi:** `conversations_page.dart`, `calls_page.dart`, `live_call_page.dart`

## 2. Mô tả thiết kế & Quy chuẩn kỹ thuật
- **Bối cảnh:** Dùng làm ảnh đại diện dự phòng khi người dùng chưa tải lên ảnh cá nhân (bên cạnh cơ chế hiển thị chữ viết tắt tên như `"LN"` màu `#F5B041`/`#181B22`).
- **Kích thước & Dung lượng:** `400×400` (`1:1`), định dạng `.webp` (`≤ 20–30 KB`).

## 3. Danh sách `assetKey` trong thư mục
- `default.png`: Biểu tượng mặc định hiện hành.
- `avatar_member_fallback.webp`: Ảnh đại diện hội viên mặc định.
