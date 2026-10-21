# Meta Gym MVP — Task List

> Chưa bắt đầu triển khai. Chỉ đánh dấu hoàn thành khi có code, kiểm thử và bằng chứng chạy thực tế.

## Giai đoạn 1 — Nền tảng

### Task 1: Chuẩn hóa cấu trúc và quy ước dự án

**Chủ trì:** Thành viên 1  
**Phụ thuộc:** Không

**Tiêu chí hoàn thành:**

- [ ] Backend, Flutter và Admin web có cấu trúc theo module/feature thống nhất.
- [ ] Có quy ước response lỗi, phân trang, tên endpoint và biến môi trường.
- [ ] `.env.example` không chứa bí mật thật.

**Kiểm tra:** Backend check, Flutter analyze/test và Admin build đều chạy được.

### Task 2: Tạo schema, migration và seed nền tảng

**Chủ trì:** Thành viên 1  
**Phụ thuộc:** Task 1

**Tiêu chí hoàn thành:**

- [x] Migration tạo được 33 bảng nghiệp vụ và các ràng buộc quan trọng.
- [x] Baseline seed chỉ tạo một Admin và một `gym_profile` hợp lệ, chạy lặp không tạo trùng.
- [ ] Demo seed là lệnh riêng cho development/test; có thể tạo gói tập, Coach, thiết bị và bài tập mẫu.
- [x] Có thể dựng lại database từ đầu bằng một quy trình được ghi lại.

**Kiểm tra:** Chạy migration, schema assertions, constraint behavior tests và baseline seed hai lần trên database trống.

### Task 3: Spike email, AI và voice/video

**Chủ trì:** Thành viên 3  
**Phụ thuộc:** Task 1

**Tiêu chí hoàn thành:**

- [ ] Gửi được một email thử nghiệm.
- [ ] Backend nhận được một câu trả lời AI thử nghiệm.
- [ ] Hai thiết bị tham gia được một cuộc gọi thử nghiệm.
- [ ] Lựa chọn provider và phương án dự phòng được ghi vào tài liệu.

**Kiểm tra:** Demo trực tiếp ba thử nghiệm; không commit khóa bí mật.

### Checkpoint 1

- [ ] Ba ứng dụng build/chạy được.
- [ ] Database dựng lại được.
- [ ] Các tích hợp rủi ro đã được thử sớm.

## Giai đoạn 2 — Identity và Gym Content

### Task 4: Đăng ký và đăng nhập theo vai trò

**Chủ trì:** Thành viên 1  
**Phụ thuộc:** Tasks 1–2

**Tiêu chí hoàn thành:**

- [ ] Member đăng ký và đăng nhập được.
- [ ] Coach/Admin không thể tự đăng ký công khai.
- [ ] JWT và trạng thái tài khoản được kiểm tra ở backend.

**Kiểm tra:** Test thành công, sai mật khẩu, sai vai trò và tài khoản bị khóa.

### Task 5: Khôi phục phiên, hồ sơ và đổi mật khẩu

**Chủ trì:** Thành viên 1  
**Phụ thuộc:** Task 4

**Tiêu chí hoàn thành:**

- [ ] Flutter lưu token an toàn và tự điều hướng đúng vai trò.
- [ ] Member/Coach sửa được trường hồ sơ cho phép.
- [ ] Người dùng đổi mật khẩu và phiên cũ được xử lý đúng.

**Kiểm tra:** Khởi động lại ứng dụng, đăng xuất và đăng nhập lại.

### Task 6: Quên mật khẩu qua email

**Chủ trì:** Thành viên 1  
**Phụ thuộc:** Tasks 3–4

**Tiêu chí hoàn thành:**

- [ ] Mã được băm, có hạn và chỉ dùng một lần.
- [ ] Email không tồn tại không làm lộ thông tin tài khoản.
- [ ] Mật khẩu mới đăng nhập được; mã cũ bị từ chối.

**Kiểm tra:** Test mã đúng, sai, hết hạn và dùng lại.

### Task 7: Quản lý tài khoản trên Admin web

**Chủ trì:** Thành viên 3  
**Phụ thuộc:** Tasks 4–5

**Tiêu chí hoàn thành:**

- [ ] Admin xem Member và tạo Coach được.
- [ ] Admin khóa/mở tài khoản với xác nhận.
- [ ] Người không phải Admin bị API từ chối.

**Kiểm tra:** Build Admin web và test ma trận vai trò.

### Task 8: Gym Content end-to-end

**Chủ trì:** Thành viên 3  
**Phụ thuộc:** Tasks 2, 4

**Tiêu chí hoàn thành:**

- [ ] Admin quản lý thông tin gym và thiết bị.
- [ ] Member/Coach tìm kiếm và xem hướng dẫn thiết bị.
- [ ] Nội dung bị ẩn không xuất hiện trên Flutter.

**Kiểm tra:** Tạo/sửa/ẩn thiết bị và kiểm tra trên ứng dụng.

### Checkpoint 2

- [ ] Identity hoạt động end-to-end.
- [ ] Phân quyền backend được test.
- [ ] Gym Content chạy trên Admin web và Flutter.

## Giai đoạn 3 — Membership và Coaching

### Task 9: Quản lý gói tập

**Chủ trì:** Thành viên 1  
**Phụ thuộc:** Tasks 2, 7

**Tiêu chí hoàn thành:**

- [ ] Admin tạo/sửa/ngừng áp dụng gói.
- [ ] Member chỉ thấy gói đang áp dụng.
- [ ] Gói đã có giao dịch không bị xóa vật lý.

**Kiểm tra:** CRUD có kiểm tra validation và quyền Admin.

### Task 10: QR thanh toán mô phỏng và nối tiếp gói

**Chủ trì:** Thành viên 1  
**Phụ thuộc:** Task 9

**Tiêu chí hoàn thành:**

- [ ] Member tạo giao dịch, nhận QR và tự xác nhận thanh toán mô phỏng thành công mà không cần Admin duyệt.
- [ ] Gói đầu tiên kích hoạt ngay; gói mua thêm nối tiếp đúng ngày.
- [ ] Xác nhận lặp không tạo hai membership.
- [ ] Backend chỉ cho chủ giao dịch xác nhận và xử lý payment, membership, quyền theo gói trong cùng transaction.

**Kiểm tra:** Test chủ sở hữu, transaction cho gói mới, gia hạn, xác nhận lặp và request đồng thời.

### Task 11: Thanh toán tại quầy

**Chủ trì:** Thành viên 3  
**Phụ thuộc:** Tasks 9–10

**Tiêu chí hoàn thành:**

- [ ] Admin tạo giao dịch cho đúng Member và gói.
- [ ] Giao dịch lưu người tạo và phương thức `front_desk`.
- [ ] Quy tắc nối tiếp giống thanh toán trên ứng dụng.

**Kiểm tra:** Test từ Admin web đến membership của Member.

### Task 12: Danh sách Coach và yêu cầu chọn Coach

**Chủ trì:** Thành viên 2  
**Phụ thuộc:** Tasks 5, 10

**Tiêu chí hoàn thành:**

- [ ] Member xem được Coach, chuyên môn và số suất còn lại.
- [ ] Chỉ Member có gói hoạt động gửi yêu cầu được.
- [ ] Mỗi Member chỉ có một yêu cầu đang chờ.

**Kiểm tra:** Test Member chưa có gói, Coach đủ suất và yêu cầu trùng.

### Task 13: Coach xử lý yêu cầu và tạo quan hệ

**Chủ trì:** Thành viên 2  
**Phụ thuộc:** Task 12

**Tiêu chí hoàn thành:**

- [ ] Coach chấp nhận/từ chối kèm lý do.
- [ ] Chấp nhận tạo đúng một quan hệ và giữ giới hạn Coach.
- [ ] Member xem được trạng thái và lý do từ chối.

**Kiểm tra:** Test đồng thời hai yêu cầu tranh suất cuối cùng.

### Task 14: Tạm ngưng, kết thúc và chuyển Coach

**Chủ trì:** Thành viên 2  
**Phụ thuộc:** Tasks 11, 13

**Tiêu chí hoàn thành:**

- [ ] Hết hạn/tái kích hoạt cập nhật quan hệ đúng và giữ suất.
- [ ] Coach gửi yêu cầu kết thúc; Admin duyệt/từ chối được.
- [ ] Admin chuyển Coach có lý do, kiểm tra suất và giữ lịch sử.

**Kiểm tra:** Test đầy đủ chuyển trạng thái và quyền truy cập sau mỗi trạng thái.

### Checkpoint 3

- [ ] Luồng Member mua gói và chọn Coach chạy end-to-end.
- [ ] Không thể vượt giới hạn Coach hoặc tạo quan hệ trùng.
- [ ] Lịch sử được giữ khi kết thúc/chuyển Coach.

## Giai đoạn 4 — Hướng dẫn và tiến độ

### Task 15: Giáo trình tập luyện

**Chủ trì:** Thành viên 2  
**Phụ thuộc:** Task 14

**Tiêu chí hoàn thành:**

- [ ] Coach tạo bản nháp gồm ngày tập và bài tập.
- [ ] Công bố kế hoạch lưu trữ bản cũ và chỉ để một bản hoạt động.
- [ ] Member chỉ xem bản đã công bố.

**Kiểm tra:** Test quyền Coach khác, quan hệ tạm ngưng và lịch sử kế hoạch.

### Task 16: Dinh dưỡng và lịch buổi tập

**Chủ trì:** Thành viên 2  
**Phụ thuộc:** Task 15

**Tiêu chí hoàn thành:**

- [ ] Coach công bố một hướng dẫn dinh dưỡng hoạt động.
- [ ] Coach tạo/sửa buổi tập và cập nhật trạng thái.
- [ ] Member xem được lịch và nội dung tương ứng.

**Kiểm tra:** Test trạng thái buổi tập và quyền khi quan hệ tạm ngưng.

### Task 17: Nhật ký tập và ăn uống

**Chủ trì:** Thành viên 2  
**Phụ thuộc:** Task 16

**Tiêu chí hoàn thành:**

- [ ] Member tạo/sửa nhật ký của mình.
- [ ] Coach hiện tại xem được; Admin và Coach khác không xem được.
- [ ] Danh sách được phân trang.

**Kiểm tra:** Test quyền sở hữu, tải ảnh và giới hạn kích thước.

### Task 18: Số đo, ảnh và biểu đồ tiến bộ

**Chủ trì:** Thành viên 2  
**Phụ thuộc:** Task 17

**Tiêu chí hoàn thành:**

- [ ] Member ghi số đo và ảnh theo ngày.
- [ ] Flutter hiển thị biểu đồ cân nặng/số đo.
- [ ] Coach nhận xét được; Coach cũ mất quyền sau khi quan hệ kết thúc.

**Kiểm tra:** Test chuỗi thời gian, giá trị rỗng và ma trận quyền.

### Checkpoint 4

- [ ] Coach giao kế hoạch và Member ghi tiến độ end-to-end.
- [ ] Dữ liệu riêng tư không lộ cho Admin hoặc Coach khác.
- [ ] Biểu đồ hiển thị đúng dữ liệu theo ngày.

## Giai đoạn 5 — Giao tiếp và AI

### Task 19: Nhắn tin văn bản và hình ảnh

**Chủ trì:** Thành viên 3  
**Phụ thuộc:** Task 14

**Tiêu chí hoàn thành:**

- [ ] Member/Coach trong quan hệ hoạt động gửi và nhận được tin nhắn.
- [ ] Có phân trang, polling, đã đọc, chưa đọc và gửi lại khi lỗi.
- [ ] Quan hệ tạm ngưng/kết thúc chỉ được đọc lịch sử.

**Kiểm tra:** Test hai tài khoản, quyền truy cập và mất mạng tạm thời.

### Task 20: Cuộc gọi thoại và video

**Chủ trì:** Thành viên 3  
**Phụ thuộc:** Tasks 3, 14

**Tiêu chí hoàn thành:**

- [ ] Hai người trong quan hệ hoạt động gọi thoại/video được.
- [ ] Quan hệ không hợp lệ không lấy được token cuộc gọi.
- [ ] Lịch sử lưu loại, trạng thái và thời lượng; không ghi nội dung.

**Kiểm tra:** Demo trên hai thiết bị, từ chối, nhỡ và kết thúc cuộc gọi.

### Task 21: AI Advisor

**Chủ trì:** Thành viên 3  
**Phụ thuộc:** Tasks 3–4

**Tiêu chí hoàn thành:**

- [ ] Member/Coach tạo cuộc trò chuyện và hỏi đáp văn bản được.
- [ ] Lịch sử chỉ thuộc người dùng hiện tại; có đổi tên/xóa.
- [ ] Có timeout, thử lại và thông báo giới hạn an toàn.

**Kiểm tra:** Test quyền sở hữu, API lỗi, nội dung nguy hiểm và không lưu phản hồi dang dở.

### Checkpoint 5

- [ ] Messaging, call và AI hoạt động độc lập.
- [ ] Dịch vụ ngoài lỗi không làm ứng dụng sập.
- [ ] Không có khóa bí mật trong Flutter hoặc Git.

## Giai đoạn 6 — Dashboard và hoàn thiện

### Task 22: Admin Dashboard

**Chủ trì:** Thành viên 3  
**Phụ thuộc:** Tasks 7, 11, 14, 18

**Tiêu chí hoàn thành:**

- [ ] Hiển thị đúng các thẻ số liệu và biểu đồ theo thời gian.
- [ ] Có danh sách Coach gần đủ suất, gói sắp hết hạn và yêu cầu chờ.
- [ ] Các liên kết mở đúng màn hình nghiệp vụ.

**Kiểm tra:** Đối chiếu số liệu với truy vấn database và dữ liệu seed.

### Task 23: Kiểm thử end-to-end và bảo mật quyền

**Chủ trì:** Cả nhóm  
**Phụ thuộc:** Tasks 4–22

**Tiêu chí hoàn thành:**

- [ ] Ba luồng Member, Coach, Admin chạy hoàn chỉnh.
- [ ] Ma trận quyền theo vai trò và trạng thái quan hệ vượt qua kiểm thử.
- [ ] Dữ liệu lịch sử còn nguyên sau hết hạn, đổi Coach và khóa tài khoản.

**Kiểm tra:** Backend tests, Flutter tests, Admin build và checklist thủ công.

### Task 24: Hoàn thiện demo và tài liệu

**Chủ trì:** Cả nhóm  
**Phụ thuộc:** Task 23

**Tiêu chí hoàn thành:**

- [ ] Có hướng dẫn cài đặt, biến môi trường và seed demo.
- [ ] Có ba tài khoản demo và kịch bản trình bày dự phòng.
- [ ] Báo cáo, sơ đồ và slide khớp với hệ thống thực tế.

**Kiểm tra:** Một thành viên không phụ trách phần đó cài lại và chạy demo từ tài liệu.

### Checkpoint cuối

- [ ] `flutter analyze` và `flutter test` thành công.
- [ ] Backend check/test thành công.
- [ ] Admin web build thành công.
- [ ] Không còn lỗi nghiêm trọng hoặc cao.
- [ ] Người dùng review và duyệt kế hoạch trước khi bắt đầu code.

