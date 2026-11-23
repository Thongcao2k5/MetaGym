# Theo dõi Dinh dưỡng Hội viên (Member Nutrition Tracking)

Kế thừa từ [`../MASTER.md`](../MASTER.md) và [`../../../DESIGN.md`](../../../DESIGN.md). Tài liệu này áp dụng cho màn hình nhật ký dinh dưỡng được mở từ trung tâm Tập luyện (Member Training hub). Tính năng này bổ trợ cho thực đơn của Coach, không thay thế thực đơn của Coach.

## Bố cục và vật liệu

- Tái sử dụng ảnh nền phòng tập của Hội viên, ánh sáng môi trường và lớp phủ scrim tối.
- Dùng nút quay lại hình tròn hiện có kèm tiêu đề trang tiếng Việt rõ ràng.
- Giữ trình tự đọc nhất quán: bộ chọn ngày, các chỉ số trong ngày, tóm tắt thực đơn Coach và bốn khung bữa ăn.
- Gom bộ chọn ngày và hai chỉ số dinh dưỡng trong ngày vào cùng một thẻ hero nhỏ gọn. Đặt nút **Thêm món** ngay trên tiêu đề của từng bữa ăn để tách bạch thao tác thêm mới với thao tác quản lý món đã lưu. Mỗi món đã lưu dùng một menu mở rộng (overflow menu) cho **Sửa món** và **Xóa món** thay vì đặt cố định hai nút icon cạnh nhau. Hiển thị tên thực đơn Coach mà không lặp lại dòng hướng dẫn bên dưới.
- Căn giữa cả hai cột chỉ số theo nhãn và giá trị riêng của từng cột. Trong một món đã ghi nhận, gom tên món, năng lượng (kcal) và chênh lệch số học gần nhau; căn nút menu mở rộng ngay sát nội dung đó thay vì tạo ra một hàng trống trải.
- Dùng các bề mặt kính khói ấm, viền ấm tiết chế và vệt phản xạ cạnh trên để đồng bộ với Trang chủ và Hồ sơ Hội viên. Nội dung danh sách bữa ăn thông thường giữ nền đặc không blur; không lồng nhiều `BackdropFilter` hoặc làm mờ mọi thẻ trong danh sách cuộn.
- Giữ nguyên nền graphite dự phòng và bề mặt biểu mẫu dễ đọc. Màu cam san hô (Coral) dành cho hành động; màu xanh lá (Green) dành cho định lượng dinh dưỡng; chữ phụ luôn ở cấp độ thứ yếu.
- Giữ nguyên hệ thống token khoảng cách/bo góc dùng chung và không tự thêm bảng màu mới.

## Lối vào từ mục Tập luyện (Training entry)

- Đặt dòng lối vào dinh dưỡng ngay sau lịch tự tập cá nhân trong mục `Kế hoạch tập luyện` của trung tâm Tập luyện (Training hub).
- Bấm vào toàn bộ dòng hoặc nút **Mở** ở cuối dòng đều dẫn tới cùng màn hình nhật ký dinh dưỡng.
- Giữ lịch sử ở chế độ đọc được sau khi gói Gym hết hạn; quyền ghi dữ liệu do API kiểm soát.

## Hành vi và tiêu chí nghiệm thu

- Giữ nguyên toàn bộ hành vi API hiện có cho thêm/sửa/xóa món, danh mục thực phẩm, ảnh món ăn và đối chiếu với thực đơn Coach, bao gồm giới hạn chỉ cho ghi theo ngày giờ Việt Nam và chỉ hiển thị chênh lệch dạng số.
- Nút lưu và thông báo khôi phục lỗi phải luôn hiển thị phía trên bàn phím ảo; khi lưu thất bại phải giữ nguyên dữ liệu người dùng vừa nhập để có thể thử lại.
- Kiểm thử đầy đủ các trạng thái: đang tải (`loading`), trống (`empty`), lỗi (`error`), hết hạn gói Gym (`expired membership`), màn hình điện thoại hẹp / phóng to chữ và điều hướng từ mục Tập luyện.
- Nghiệm thu trực quan bắt buộc phải chạy ứng dụng thực tế trên máy ảo/thiết bị kết nối backend thật với dữ liệu đã lưu, kèm ảnh chụp màn hình của lối vào từ Tập luyện, màn hình nhật ký và biểu mẫu nhập món. Ảnh chụp từ widget test dùng dữ liệu giả lập (fixture) không được tính là hoàn thành.
- Báo cáo tách bạch rõ các bước kiểm tra thực tế (runtime checks), ảnh chụp màn hình và bài kiểm thử tự động đã thực sự chạy. Tuyệt đối không suy đoán độ căn chỉnh trực quan chỉ qua việc đọc code token theme.
