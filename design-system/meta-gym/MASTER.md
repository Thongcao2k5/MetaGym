# Meta Gym — Định hướng Thiết kế Tổng thể (Master)

Tệp `DESIGN.md` ở thư mục gốc của kho lưu trữ là nguồn chuẩn cao nhất. Tài liệu này là lớp tra cứu tóm tắt phục vụ trực tiếp cho công việc thiết kế trang và triển khai giao diện.

## Phong cách

**Futuristic Performance Glass** = kính không gian cao cấp × tinh thần tập luyện hiệu suất cao.

- Hiện đại, sang trọng, mạnh mẽ và đáng tin cậy.
- Ưu tiên nền tối (dark-first) trên giao diện Flutter dành cho Hội viên (Member) và Huấn luyện viên (Coach).
- Tuyệt đối không theo kiểu cyberpunk, gaming, neon cầu vồng hoặc phủ hiệu ứng kính lên mọi thẻ nội dung.
- Các chỉ số thị giác: độ biến thiên (variance) 5/10, chuyển động (motion) 4/10, mật độ thông tin (density) 6/10, hiệu ứng (effects) 4/10.

## Công thức bất biến

- Tối thiểu 80% bề mặt tối ổn định; tối đa 20% sử dụng kính mờ xuyên thấu (backdrop glass) thực thụ.
- Nền khung chính (Canvas / Scaffold): `#0F1115` (Deep Graphite).
- Thẻ bề mặt đặc (Solid card): `#181B22` kèm viền 1px `#262A34`, không dùng blur.
- Kính hiệu năng (Performance glass): `rgba(24, 27, 34, 0.78)`, độ mờ blur 12px, bo góc 24px.
- Kính lớp phủ (Overlay glass): `rgba(15, 17, 21, 0.90)`, độ mờ blur 18px, chỉ dùng cho hộp thoại (dialog), bottom sheet và lớp phủ AI.
- Không bao giờ lồng kính mờ bên trong một lớp kính mờ khác.
- Không bao giờ tạo hiệu ứng chuyển động (animate) cho blur. Chỉ animate độ mờ (`opacity`) và biến đổi hình học (`transform`).

## Token nhận diện

- Màu nhấn chính (Coral Orange): `#FF5E36` (nút hành động chính CTA, trạng thái đang chọn, tiến độ chính, điểm nhấn; chữ và icon trên nền nút chính bắt buộc dùng màu `#FFFFFF`).
- Ánh phản xạ lạnh (Cool reflection): `#A9C7E8`.
- Chữ chính: `#F7F9FC`.
- Chữ phụ (Secondary/Subtext): `#8E95A5` (chữ phụ / trạng thái tương lai chưa diễn ra).
- Màu ngữ nghĩa xanh lá (Success): `#2ECC71` (hoàn thành / đang hiệu lực / dinh dưỡng).
- Màu ngữ nghĩa vàng (Warning): `#F39C12` (cảnh báo / avatar phụ).
- Avatar HLV (Coach Avatar) `"LN"`: nền `#F5B041`, chữ `#181B22` đậm xuyên suốt toàn bộ các thẻ.
- Phông chữ: **Be Vietnam Pro**, đóng gói nội bộ trong ứng dụng (locally bundled).
- Màu cam chỉ chiếm khoảng 5–10% diện tích khung nhìn thông thường và dành riêng cho hành động, mục đang chọn và tiến độ cốt lõi.

## Hình khối và khoảng cách

- Đơn vị cơ sở 4px, nhịp khoảng cách mặc định 8px.
- Lề ngang (gutter): 16px trên điện thoại; 24px trên máy tính bảng.
- Bo góc: nút/điều khiển 10–14px; thẻ nội dung 20px; thanh dock kính và sheet 24px.
- Padding bên trong thẻ: 16/20/24px tùy theo mức độ nhấn mạnh.
- Tránh lồng thẻ trong thẻ; ưu tiên dùng khoảng trống, đường kẻ phân cách (divider) hoặc phân nhóm sắc độ trước.

## Thành phần giao diện (Components)

- Các thẻ nội dung tiêu chuẩn sử dụng bề mặt đặc; hiệu ứng kính chỉ dành cho điều hướng, thanh thao tác nhanh gọn và lớp phủ.
- Tối đa một nút hành động chính màu cam cho mỗi vùng ra quyết định.
- Thanh điều hướng đáy (bottom navigation) tối đa 5 mục đích.
- Sử dụng duy nhất một họ icon vector với độ dày nét 1.75–2px.
- Vùng chạm tối thiểu (touch targets): 48×48dp trên Android hoặc 44×44pt trên iOS.
- Mọi thao tác đều phải định nghĩa rõ các trạng thái: nhấn (`pressed`), đang tải (`loading`), vô hiệu hóa (`disabled`), thành công (`success`) và lỗi (`error`) khi phù hợp.

## Chuyển động và hiệu năng

- Phản hồi nhấn (Press): 80–150ms.
- Thay đổi trạng thái cục bộ (Local state): 180–240ms.
- Chuyển trang / mở sheet: 240–320ms.
- Tôn trọng cài đặt giảm chuyển động (reduced motion) của hệ thống.
- Giới hạn khung cắt (clip bounds) cho blur, không đặt blur trong các thẻ cuộn liên tục, và chỉ tách vùng vẽ lại (`RepaintBoundary`) ở nơi kết quả đo hiệu năng cho thấy cần thiết.
- Ảnh nền phải được nén tối ưu, đúng kích thước hiển thị, tải trước vào bộ nhớ đệm (precache) khi trình diễn và phủ lớp làm tối (scrim) đủ mạnh.

## Phân tách theo nền tảng

- Flutter Hội viên / Huấn luyện viên: mang trọn vẹn bản sắc nền tối và kính mờ có kiểm soát.
- Bootstrap Admin: dùng chung kiểu chữ, nút hành động màu cam, màu trạng thái ngữ nghĩa và nhịp khoảng cách; ưu tiên bề mặt đặc để đọc dữ liệu mật độ cao.

## Tiêu chuẩn kiểm duyệt bàn giao (Delivery gate)

- Tỷ lệ tương phản chữ đạt tối thiểu 4.5:1; thành phần phi văn bản có ý nghĩa đạt tối thiểu 3:1.
- Kiểm tra đầy đủ các trạng thái: đang tải (`loading`), trống (`empty`), lỗi (`error`), mất mạng (`offline`), vô hiệu hóa (`disabled`) và thành công (`success`).
- Kiểm tra vùng an toàn (safe areas), bàn phím ảo, thứ tự trình đọc màn hình (screen-reader) và co giãn cỡ chữ hệ thống (Dynamic Type / text scaling).
- Kiểm thử trên điện thoại chiều rộng 375px, điện thoại màn lớn / máy tính bảng và chế độ xoay ngang trên di động.
- Xác nhận màn hình vẫn dễ dùng và rõ ràng ngay cả khi tắt hiệu ứng blur và tắt ảnh nền.

Để tra cứu chính xác toàn bộ token, quy tắc thành phần, các lỗi cần tránh và danh sách kiểm tra demo đồ án, xem [`../../DESIGN.md`](../../DESIGN.md).
