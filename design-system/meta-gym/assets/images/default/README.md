# Thư mục `images/default` — Hình ảnh Dự phòng Chung (Fallback Images)

## 1. Vị trí sử dụng trên App
- Lưu trữ bản gốc đối chiếu của các hình ảnh mặc định đang có trong `mobile-app/assets/images/` (`gym_banner.png`, `loading_arm_lift.jpg`).
- Dùng làm ảnh fallback cuối cùng khi một màn hình hoặc thẻ nội dung chưa tải được ảnh chuyên biệt theo phân khu.

## 2. Mô tả thiết kế & Quy chuẩn kỹ thuật
- Tuân thủ [gym-space-bible.md](../../gym-space-bible.md): Không gian phòng tập Meta Gym tầng trệt, tông tối than chì `#0F1115` / `#181B22`, ánh sáng ấm tiết chế `#FF5E36`, tương thích với lớp phủ scrim tối `72–84%`.
- Khi xuất bản chính thức cho App/Web, ưu tiên chuyển sang `.webp` để giảm 70–85% dung lượng so với `.png`/`.jpg` gốc.

## 3. Danh sách tệp trong thư mục
- `default.png`: Bản gốc `gym_banner.png` hiện có trên App.
- `default_arm_lift.jpg`: Bản gốc `loading_arm_lift.jpg` hiện có trên App.
