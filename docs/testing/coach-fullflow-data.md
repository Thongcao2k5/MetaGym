# Dữ liệu kiểm thử Coach

Chạy từ `C:\MetaGym\backend`:

```powershell
npm run seed:coach:preview
npm run seed:coach
npm run verify:coach-data
```

Script chỉ chấp nhận PostgreSQL trên localhost. Preview chạy trong transaction rồi rollback; apply thêm dữ liệu vào database được cấu hình trong backend `.env`.

Coach chính là `coach@metagym.local`, giữ nguyên mật khẩu và hồ sơ. Tài khoản Coach mới `schedule@coachtest.metagym.local` có danh sách học viên/lịch trống để thử thiết lập ban đầu. Mật khẩu tài khoản mới, danh sách học viên và checklist được lưu riêng ngoài Git tại `%USERPROFILE%\Documents\MetaGym-Coach-Test\README.md` và `accounts.json`.

Các tình huống bao gồm học viên đang hoạt động, tạm dừng, kết thúc; yêu cầu chờ/chấp nhận/từ chối/hủy; gói PT đang dùng/gia hạn chờ/hết buổi/sắp hết hạn; lịch PT đã đặt/hoàn thành/hủy sớm/hủy sát giờ; lịch cố định và khung bận; giáo trình/thực đơn nháp/đang dùng/lưu trữ; bài tập và bữa ăn theo ngày; buổi tập theo giáo trình đủ bốn trạng thái; tin nhắn, lịch sử cuộc gọi minh họa, thông báo, thành tích có phản hồi đồng ý/từ chối/chờ/rút lại. Có học viên chưa có giáo trình/thực đơn và học viên chưa khai báo sức khỏe.

UUID của bản ghi mẫu bắt đầu bằng `c0ac2026`, tài khoản mẫu dùng miền `coachtest.metagym.local`, nội dung mẫu có nhãn `TEST`/`COACH_TEST`. Script chỉ thêm bản ghi còn thiếu; chạy lại không reset mật khẩu, trạng thái hay nội dung người dùng đã sửa khi test. Lịch làm việc Coach Demo được bổ sung các ca liên tiếp nhưng giữ nguyên ca hiện có. Seed kiểm tra giới hạn học viên, sức chứa lịch và cân đối số buổi trước khi commit. Không dùng script cleanup dữ liệu demo cũ để xóa bộ dữ liệu này.

## Giới hạn hiện tại

Đặt `ENABLE_COACH_WORKFLOWS=true` trong `backend/.env`, sau đó khởi động lại backend để mở gửi/duyệt yêu cầu Coach, tạo/sửa/công bố training-plan, nutrition-guide và training-session mà giao diện Coach đang gọi. Khi cờ tắt, các API này trả `410 LEGACY_WORKFLOW_RETIRED`. Các API vẫn kiểm tra đăng nhập, vai trò, quyền sở hữu, quan hệ đang hoạt động và trạng thái nháp/đã công bố. API ghi nhật ký V1 vẫn bị ngừng. Luồng V2 `training-plans/current`, `meal-plans`, `coach-bookings` hoạt động song song. Học viên được Coach nhận chưa tự có quyền PT; gói PT đầu tiên vẫn cần kết quả thanh toán được xác minh và được gắn vào quan hệ có sẵn, tránh tạo trùng hoặc bị treo trong hàng chờ.

Nhật ký và biểu đồ cá nhân Member vẫn là riêng tư: Coach nhận 403 khi truy cập các API đó. Seed không thay đổi phân quyền.

Không tạo giao dịch thật, không gọi Sandbox thanh toán, LiveKit, AI hoặc email. Các khoản thanh toán Gym mẫu dùng FRONT_DESK, có giá và thông tin gói lấy từ catalog hiện tại. Lịch sử PT mô tả fixture, không phải giao dịch đã được nhà cung cấp Sandbox xác thực. Không tạo tệp media giả hoặc gán READY cho ảnh không tồn tại. Upload ảnh, gọi điện/video, AI và chuyển cổng thanh toán cần test riêng với dịch vụ thực đã cấu hình.
