# Meta Gym — UI design specification

**Trạng thái:** áp dụng cho mọi công việc thiết kế, đánh giá hoặc sửa giao diện Member, Coach và Admin.  
**Nguồn màu và hình thái:** [DESIGN.md](../../DESIGN.md).  
**Theme Flutter đang chạy:** `mobile-app/lib/core/theme/app_theme.dart`.

## 1. Quy tắc phải đọc trước khi làm màn hình

1. Đọc spec này và `DESIGN.md` trước khi dựng bố cục hoặc viết UI.
2. Đọc màn hiện tại, dữ liệu/điều kiện hiển thị, `confirmed-workflows.md` và brief của màn nếu có.
3. Xác định loại màn: trang giới thiệu/Trang chủ, tác vụ nhập liệu, danh sách, chi tiết, lịch, biểu đồ hay quản trị. Chọn mức kính theo loại màn; không áp một hiệu ứng cho toàn app.
4. Liệt kê trạng thái nghiệp vụ trước khi thiết kế: chưa mua gói, có gói tự tập, có Coach, chờ Coach, hết hạn/tạm khóa, không có dữ liệu, loading và lỗi nếu liên quan.
5. Khi người dùng yêu cầu preview trước, dựng và kiểm tra preview tách khỏi code ứng dụng; chỉ triển khai sau khi phương án được chốt.
6. Sau khi sửa, xem ảnh render thật ở kích thước điện thoại và trạng thái liên quan. Sửa lỗi đọc, tràn, che bởi thanh điều hướng, tương phản và nhịp cuộn trước khi coi là xong.

## 2. Bản sắc thị giác đã chốt

- **Futuristic Performance Glass:** hiện đại, sang trọng, mạnh mẽ, dễ đọc.
- Canvas `#0F1115`; card graphite `#181B22`; viền 1px `#262A34`.
- Coral orange `#FF5E36` chỉ dành cho CTA chính, active và tiến trình quan trọng. Mọi chữ/icon trên nền cam là `#FFFFFF`. Nút cam có chữ nhỏ dùng biến thể viền hoặc chữ cam trên graphite để giữ tương phản.
- Chữ chính `#FFFFFF`, chữ phụ `#8E95A5`; xanh hiệu lực/hoàn thành `#2ECC71`; vàng cảnh báo `#F39C12`.
- Avatar Coach LN: nền `#F5B041`, chữ đậm `#181B22` ở mọi màn.
- Font **Be Vietnam Pro**. Không làm toàn bộ nội dung card cùng đậm; số liệu và tiêu đề có phân cấp rõ.
- Kính màu ấm trên ảnh gym dùng ở Trang chủ, thanh điều hướng và card nổi bật. Form, danh sách dài, lịch, biểu đồ và Admin dùng bề mặt graphite ổn định. Ảnh nền đủ nhận ra nhưng không xuyên qua chữ đến mức khó đọc.

## 3. Quy tắc bố cục và tương tác

- Một màn có một mục tiêu chính; mỗi card có một chức năng hoặc nhóm thông tin liên quan. Không thêm card để lấp chỗ trống.
- Các card cùng hàng cân chiều cao và lượng thông tin. Dùng lề điện thoại 16px, nhịp khoảng cách 8px và khoảng section 20–24px.
- Nút dẫn sang trang khác có nhãn hành động cụ thể, không tạo cảm giác đang chọn trạng thái của trang hiện tại. Không dùng nút không có tác dụng thật.
- Member giữ năm mục điều hướng: Trang chủ, Tập luyện, AI, Tin nhắn, Hồ sơ. Chừa safe area và phần cuộn để nội dung cuối không bị che.
- Dùng một họ icon vector và hit target tối thiểu 48dp. Màu trạng thái luôn đi kèm chữ/biểu tượng. Hỗ trợ text scaling, reduced motion và focus.
- Hiệu ứng kính cần blur được clip và fallback đặc. Không animate blur, không đặt blur sau danh sách dài, không dùng glow/ảnh chỉ để trang trông đầy.

## 4. Điều kiện nghiệm thu

- Nội dung và CTA khớp luồng thật; không xuất hiện dữ liệu Coach, giáo trình hoặc tiến độ ở trạng thái chưa có quyền sử dụng.
- Kiểm tra loading, empty, error, disabled, offline và success nơi chức năng có các trạng thái đó.
- Chữ thường đạt tương phản tối thiểu 4.5:1; thành phần điều khiển và chữ lớn tối thiểu 3:1 trên ảnh đã ghép.
- Kiểm tra điện thoại rộng khoảng 375px, máy lớn, landscape, bàn phím mở và thanh điều hướng cố định.
- Trên thiết bị demo, cuộn và chuyển trang mượt; khi ảnh nền/blur không tải hoặc bị tắt, màn vẫn sử dụng được.
- Nếu điều chỉnh một màn đã duyệt, giữ nguyên bố cục và phong cách ngoài phạm vi người dùng yêu cầu.

## 5. Quản lý thay đổi

Quyết định mới nhất của người dùng được ưu tiên. Khi quyết định đó thay đổi màu hoặc nguyên tắc chung, cập nhật spec này, `DESIGN.md`, theme/component liên quan và brief của màn trong cùng thay đổi. Nếu chỉ đổi một màn, ghi tại brief của màn để không tạo quy tắc toàn app ngoài ý muốn. Impeccable hỗ trợ đánh giá chất lượng nhưng không được thay thế quyết định đã chốt của Meta Gym.
