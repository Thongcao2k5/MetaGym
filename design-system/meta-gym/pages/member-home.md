# Trang chủ Hội viên (Member Home) — Quy tắc Thiết kế Trang

Trang này kế thừa từ [`../MASTER.md`](../MASTER.md). Các quy tắc dưới đây chuẩn hóa bố cục màn hình Trang chủ trong concept hiện tại của Meta Gym.

## Phân cấp thị giác

1. Lời chào (`META GYM` / `Chào, <Tên>`) và nút tìm kiếm hình tròn hiệu ứng kính.
2. Thanh thao tác nhanh (Quick-action dock): 4 ô vuông bo góc (squircle) đều nhau (`Lịch tập`, `Giáo trình`, `Dinh dưỡng`, `Coach`).
3. Thẻ tóm tắt Gói tập & Coach (`Gói tập & Coach` dạng Warm Glass, hoặc `Gói tập của bạn` khi hội viên chưa có Coach hoạt động).
4. Buổi tập hôm nay (thẻ nổi bật `Hôm nay` dạng Liquid Glass, hoặc thẻ `Tự tập hôm nay` khi hội viên không có Coach).
5. Cặp thẻ Bento 2 cột cân đối (`Dinh dưỡng` và `Tiến độ tập luyện` / `Tiến độ tuần`, đồng chiều cao `128px`).
6. Khu vực `Khám phá Meta Gym`, danh mục tính năng đầy đủ có thể thu gọn và thanh điều hướng đáy 5 mục với nút AI là hành động duy nhất được nâng nổi.

## Phân bổ vật liệu & Bố cục Warm Glass + Bento

- **Nền chính & Chiều sâu không gian:** Nền Deep Graphite (`#0F1115`) nằm dưới duy nhất một ảnh nền phòng tập tĩnh đã làm tối với lớp phủ dọc obsidian scrim (`0x9E0F1115` → `0x900F1115` → `0xAA0F1115`), ánh phản xạ lạnh góc trên-phải (`rgba(169, 199, 232, 0.16)`) và quầng sáng ấm góc dưới-trái (`rgba(255, 94, 54, 0.10)`).
- **Thanh thao tác nhanh (Quick-action Dock):** 4 ô squircle Warm Glass đối xứng (`radius: 18px`, gradient khói ấm `0xC637302A` → `0xBB2C2621`, viền `0xB7ADA396`), không dùng đường kẻ ngăn giữa các ô, vùng chạm tối thiểu `>= 48dp`.
- **Thẻ Gói tập & Coach (`Gói tập & Coach`):** Thẻ Warm Glass (`radius: 24px`, `BackdropFilter` blur `sigma: 10`, gradient khói ấm `0xCD342D28` → `0xC829241F`, viền `0xB7B3A99D`, ánh phản chiếu cạnh trên `0x75FFF5E9`), các ô chỉ số bên trong (`radius: 17px`, chiều cao tối thiểu `82px`, nền bán trong suốt `#80211E1C` kèm viền `#9A8C8176`), avatar chữ viết tắt của Coach và nhãn trạng thái tiếng Việt (`"Hiệu lực"`).
- **Thẻ nổi bật (`Hôm nay`) & Thẻ Bento (`Dinh dưỡng` + `Tiến độ`):** Bề mặt Liquid Glass (`sigma: 12` cho thẻ nổi bật, vệt sáng cạnh trên tinh tế `0x70FFF6EA`). Hàng Bento 2 cột chia đều `Dinh dưỡng` (bên trái) và tiến độ tập trong tuần (bên phải) với chiều cao đồng nhất `128px`.
- **Thanh điều hướng đáy & Khoảng trống cuộn:** Thanh điều hướng nổi gồm 5 mục đích với nút AI nâng cao ở chính giữa; danh sách cuộn phải chừa khoảng đệm `bottomPadding + 32` để các mục Khám phá / danh mục bên dưới không bao giờ bị che khuất.
- **Thuật ngữ & Tinh chỉnh kiểu chữ:**
  - Thay toàn bộ nhãn trạng thái tiếng Anh sang tiếng Việt (`"Hiệu lực"` thay vì `"Active"`).
  - Hiển thị chữ sắc nét (`Be Vietnam Pro`), không đổ bóng mờ chữ hoặc viền sắc sai RGB, dùng số dạng bảng (`tabularFigures`) cho số ngày còn lại và các chỉ số tập luyện.
- **Tiêu chuẩn bảng màu:**
  - Nền khung (Scaffold / Canvas): `#0F1115` (Deep Graphite).
  - Bề mặt thẻ (nền dự phòng đặc & các khung không blur): `#181B22` kèm viền 1px `#262A34`.
  - Màu nhấn chính: `#FF5E36` (Coral Orange) cho CTA chính, mục điều hướng đang chọn, ô đang kích hoạt và tiến độ chính; chữ và icon trên nút chính bắt buộc dùng màu trắng `#FFFFFF`.
  - Màu ngữ nghĩa: Xanh lá `#2ECC71` (Hoàn thành / Đang hiệu lực / Dinh dưỡng), Vàng `#F39C12` (Cảnh báo / Avatar phụ), Xám `#8E95A5` (Chữ phụ / Trạng thái tương lai chưa diễn ra).
  - Avatar Coach `"LN"` (Lê Hoàng Nam): nền `#F5B041`, chữ `#181B22` đậm, đồng bộ trên toàn bộ các thẻ.
- **Chế độ dự phòng hiệu năng (`useSolidGlassFallback` / Giảm chuyển động / Kiểm thử):**
  - Tắt `BackdropFilter` blur và chuyển về bề mặt graphite/nâu tối đặc (`#181B22` / `#302923` cho ô dock, `rgba(24,27,34,0.92)` cho thanh điều hướng) nhưng vẫn giữ nguyên viền và độ tương phản.

## Quy tắc tinh giản

- Bỏ đường viền bao quanh nội dung bên trong khi thẻ cha đã tạo ranh giới rõ ràng.
- Chỉ dùng bố cục 2 cột cho các cụm số liệu tóm tắt ngắn gọn.
- Giữ tối đa một thẻ nổi bật dùng hình ảnh trên mỗi khung nhìn; các thẻ còn lại sử dụng icon và kiểu chữ.
- Tránh cắt ngắn tên Coach trừ khi toàn bộ hàng đó có thể bấm vào và hiển thị đầy đủ họ tên ở màn hình đích.
- Dùng khoảng cách giữa các mục (section spacing) thay vì bọc thêm một khung chứa mới cho từng tiểu mục.

## Phân bổ màu cam

- Ô thao tác nhanh đang kích hoạt hoặc nút CTA chính.
- Ngày tập hiện tại / đang được chọn.
- Mục điều hướng đáy đang hoạt động.
- Nút AI trung tâm.

Không áp dụng quầng sáng mạnh (glow) đồng thời cho cả bốn vị trí trên. Điểm nhấn sáng mạnh nhất chỉ dành cho hành động mà người dùng được kỳ vọng bấm tiếp theo.

## Mục tiêu hiệu năng khi trình diễn (Demo)

- Giới hạn `BackdropFilter` Warm/Liquid Glass (`sigma: 10–12`) trong `RepaintBoundary` trên các thẻ hero/tóm tắt và thanh điều hướng, có sẵn chế độ dự phòng nền đặc (`useSolidGlassFallback` / giảm chuyển động) cho thiết bị cấu hình thấp.
- Tải trước ảnh nền duy nhất (`assets/images/gym_banner.png`).
- Tránh hiệu ứng thị sai (parallax) và hoạt ảnh phát sáng chạy liên tục.
- Chỉ dùng `opacity`/`transform` cho hiệu ứng xuất hiện thẻ và chuyển đổi trạng thái.

## Tiêu chí nghiệm thu

- Người dùng nhận ra buổi tập tiếp theo trong vòng 3 giây.
- Thanh điều hướng và các ô thao tác nhanh giữ vùng chạm tối thiểu `48dp`.
- Chữ phụ luôn dễ đọc trên nền ảnh thực tế sau khi ghép lớp.
- Nội dung cuối trang không bị thanh điều hướng kính che mất.
- Trang chủ vẫn rõ ràng và sử dụng bình thường nếu ảnh nền không tải được.
