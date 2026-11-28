# Khởi động & Auth

## Quyết định được duyệt ngày 26/11/2026

- Nền nhóm Khởi động & Auth, kể cả trang pháp lý và trang xem thử trạng thái: dùng đúng `assets/images/backgrounds/bg_app_dark.webp` / `bg_app_light.webp` từ design system, crop cover ở giữa và scrim theo `.phone-scrim` trong preview 22-11-2026. Thay yêu cầu giữ ảnh phòng gym trước đó.
- Các thẻ nội dung Điều khoản, Quyền riêng tư và Trạng thái hệ thống dùng tông kính khói nâu ấm như thẻ đầu trang, điểm nhấn cam Meta Gym. Đây là ngoại lệ theo trang do người dùng chọn; không thay màu thẻ toàn ứng dụng.
- Dùng `MetaGymGlassCard(solid: false)` không featured cho danh sách: màu `MetaGymWarmGlassTokens.cardFill`, viền và phản sáng cùng bộ token; không thêm backdrop blur trong vùng cuộn. Chữ phụ dùng `palette.textWarmMuted` để rõ trên kính ấm.
- Giữ nội dung, bố cục, cỡ chữ và luồng tương tác đã kiểm tra. Light mode vẫn dùng palette sáng của thành phần hiện có.
