# Meta Gym MVP — Task List

> Đã đối chiếu với `main` tại commit `92ca738` ngày 22/10/2026. Chỉ đánh dấu
> hoàn thành khi toàn bộ nội dung của tiêu chí đã có code/test hoặc bằng chứng chạy.
> Ký hiệu **Một phần** nghĩa là backend API đã có nhưng Flutter, provider thật hoặc
> kiểm thử end-to-end vẫn còn thiếu. Các phần còn lại được chia nhỏ tại
> [`remaining-work-tasks.md`](./remaining-work-tasks.md).
> Các nhận định trạng thái T01–T24 bên dưới là ảnh chụp tại mốc commit nêu trên,
> không phản ánh toàn bộ code Flutter ngày 23/10. Phần UI mới ở cuối file.

## Giai đoạn 1 — Nền tảng

### Task 1: Chuẩn hóa cấu trúc và quy ước dự án

**Chủ trì:** Thành viên 1  
**Phụ thuộc:** Không

**Tiêu chí hoàn thành:**

- [ ] Backend, Flutter và Admin web có cấu trúc theo module/feature thống nhất. **Một phần:** Backend đã chia route/service và Admin đã tách asset; Flutter vẫn chỉ có `main.dart`.
- [x] Có quy ước response lỗi, phân trang, tên endpoint và biến môi trường.
- [x] `.env.example` không chứa bí mật thật.

**Kiểm tra:** Backend check, Flutter analyze/test và Admin build đều chạy được.

### Task 2: Tạo schema, migration và seed nền tảng

**Chủ trì:** Thành viên 1  
**Phụ thuộc:** Task 1

**Tiêu chí hoàn thành:**

- [x] Migration tạo được 33 bảng nghiệp vụ và các ràng buộc quan trọng.
- [x] Baseline seed chỉ tạo một Admin và một `gym_profile` hợp lệ, chạy lặp không tạo trùng.
- [x] Demo seed là lệnh riêng cho development/test; tạo tài khoản, gói tập, Coach, thiết bị và bài tập mẫu; chạy lặp không tạo trùng.
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

- [x] Ba ứng dụng build/chạy được.
- [x] Database dựng lại được.
- [ ] Các tích hợp rủi ro đã được thử sớm.

## Giai đoạn 2 — Identity và Gym Content

### Task 4: Đăng ký và đăng nhập theo vai trò

**Chủ trì:** Thành viên 1  
**Phụ thuộc:** Tasks 1–2

**Tiêu chí hoàn thành:**

- [x] Member đăng ký và đăng nhập được qua backend API và test.
- [x] Coach/Admin không thể tự đăng ký công khai.
- [x] JWT và trạng thái tài khoản được kiểm tra ở backend.

**Kiểm tra:** Test thành công, sai mật khẩu, sai vai trò và tài khoản bị khóa.

### Task 5: Khôi phục phiên, hồ sơ và đổi mật khẩu

**Chủ trì:** Thành viên 1  
**Phụ thuộc:** Task 4

**Tiêu chí hoàn thành:**

- [ ] Flutter lưu token an toàn và tự điều hướng đúng vai trò.
- [x] Member/Coach sửa được trường hồ sơ cho phép qua backend API.
- [x] Người dùng đổi mật khẩu và phiên cũ được xử lý đúng ở backend.

**Kiểm tra:** Khởi động lại ứng dụng, đăng xuất và đăng nhập lại.

### Task 6: Quên mật khẩu qua email

**Chủ trì:** Thành viên 1  
**Phụ thuộc:** Tasks 3–4

**Tiêu chí hoàn thành:**

- [x] Mã được băm, có hạn và chỉ dùng một lần.
- [x] Email không tồn tại không làm lộ thông tin tài khoản.
- [x] Mật khẩu mới đăng nhập được; mã cũ bị từ chối.

**Còn thiếu:** Kết nối dịch vụ gửi email thật và giao diện Flutter.

**Kiểm tra:** Test mã đúng, sai, hết hạn và dùng lại.

### Task 7: Quản lý tài khoản trên Admin web

**Chủ trì:** Thành viên 3  
**Phụ thuộc:** Tasks 4–5

**Tiêu chí hoàn thành:**

- [x] Admin xem Member và tạo Coach được.
- [x] Admin khóa/mở tài khoản với xác nhận.
- [x] Người không phải Admin bị API từ chối.

**Kiểm tra:** Build Admin web và test ma trận vai trò.

### Task 8: Gym Content end-to-end

**Chủ trì:** Thành viên 3  
**Phụ thuộc:** Tasks 2, 4

**Tiêu chí hoàn thành:**

- [x] Admin quản lý thông tin gym và thiết bị.
- [ ] Member/Coach tìm kiếm và xem hướng dẫn thiết bị. **Một phần:** API catalog đã có; Flutter chưa có.
- [ ] Nội dung bị ẩn không xuất hiện trên Flutter. **Một phần:** API đã lọc; Flutter chưa có.

**Kiểm tra:** Tạo/sửa/ẩn thiết bị và kiểm tra trên ứng dụng.

### Checkpoint 2

- [ ] Identity hoạt động end-to-end. **Một phần:** Backend và Admin hoạt động; Flutter chưa có.
- [x] Phân quyền backend được test.
- [ ] Gym Content chạy trên Admin web và Flutter.

## Giai đoạn 3 — Membership và Coaching

### Task 9: Quản lý gói tập

**Chủ trì:** Thành viên 1  
**Phụ thuộc:** Tasks 2, 7

**Tiêu chí hoàn thành:**

- [x] Admin tạo/sửa/ngừng áp dụng gói.
- [x] Member chỉ thấy gói đang áp dụng qua API.
- [x] Gói đã có giao dịch không bị xóa vật lý.

**Kiểm tra:** CRUD có kiểm tra validation và quyền Admin.

### Task 10: QR thanh toán mô phỏng và nối tiếp gói

**Chủ trì:** Thành viên 1  
**Phụ thuộc:** Task 9

**Tiêu chí hoàn thành:**

- [x] Member tạo giao dịch, nhận dữ liệu QR và tự xác nhận thanh toán mô phỏng qua API mà không cần Admin duyệt.
- [x] Gói đầu tiên kích hoạt ngay; gói mua thêm nối tiếp đúng ngày.
- [x] Xác nhận lặp không tạo hai membership.
- [x] Backend chỉ cho chủ giao dịch xác nhận và xử lý payment, membership, quyền theo gói trong cùng transaction.

**Còn thiếu:** Giao diện thanh toán Flutter.

**Kiểm tra:** Test chủ sở hữu, transaction cho gói mới, gia hạn, xác nhận lặp và request đồng thời.

### Task 11: Thanh toán tại quầy

**Chủ trì:** Thành viên 3  
**Phụ thuộc:** Tasks 9–10

**Tiêu chí hoàn thành:**

- [x] Admin tạo giao dịch cho đúng Member và gói.
- [x] Giao dịch lưu người tạo và phương thức `front_desk`.
- [x] Quy tắc nối tiếp giống thanh toán trên ứng dụng.

**Kiểm tra:** Test từ Admin web đến membership của Member.

### Task 12: Danh sách Coach và yêu cầu chọn Coach

**Chủ trì:** Thành viên 2  
**Phụ thuộc:** Tasks 5, 10

**Tiêu chí hoàn thành:**

- [x] Member xem được Coach, chuyên môn và số suất còn lại qua API.
- [x] Chỉ Member có gói hoạt động gửi yêu cầu được.
- [x] Mỗi Member chỉ có một yêu cầu đang chờ.

**Còn thiếu:** Giao diện danh sách/yêu cầu Coach trên Flutter.

**Kiểm tra:** Test Member chưa có gói, Coach đủ suất và yêu cầu trùng.

### Task 13: Coach xử lý yêu cầu và tạo quan hệ

**Chủ trì:** Thành viên 2  
**Phụ thuộc:** Task 12

**Tiêu chí hoàn thành:**

- [x] Coach chấp nhận/từ chối kèm lý do qua API.
- [x] Chấp nhận tạo đúng một quan hệ và giữ giới hạn Coach.
- [x] Member xem được trạng thái và lý do từ chối qua API.

**Còn thiếu:** Giao diện Coach/Member trên Flutter.

**Kiểm tra:** Test đồng thời hai yêu cầu tranh suất cuối cùng.

### Task 14: Tạm ngưng, kết thúc và chuyển Coach

**Chủ trì:** Thành viên 2  
**Phụ thuộc:** Tasks 11, 13

**Tiêu chí hoàn thành:**

- [x] Hết hạn/tái kích hoạt cập nhật quan hệ đúng và giữ suất.
- [x] Coach gửi yêu cầu kết thúc; Admin duyệt/từ chối được qua API/Admin web.
- [x] Admin chuyển Coach có lý do, kiểm tra suất và giữ lịch sử.

**Kiểm tra:** Test đầy đủ chuyển trạng thái và quyền truy cập sau mỗi trạng thái.

### Checkpoint 3

- [ ] Luồng Member mua gói và chọn Coach chạy end-to-end. **Một phần:** Backend đã được test; Flutter chưa có.
- [x] Không thể vượt giới hạn Coach hoặc tạo quan hệ trùng ở backend/database.
- [x] Lịch sử được giữ khi kết thúc/chuyển Coach.

## Giai đoạn 4 — Hướng dẫn và tiến độ

### Task 15: Giáo trình tập luyện

**Chủ trì:** Thành viên 2  
**Phụ thuộc:** Task 14

**Tiêu chí hoàn thành:**

- [x] Coach tạo bản nháp gồm ngày tập và bài tập qua API.
- [x] Công bố kế hoạch lưu trữ bản cũ và chỉ để một bản hoạt động.
- [x] Member chỉ xem bản đã công bố qua API.

**Còn thiếu:** Giao diện Flutter cho Coach và Member.

**Kiểm tra:** Test quyền Coach khác, quan hệ tạm ngưng và lịch sử kế hoạch.

### Task 16: Dinh dưỡng và lịch buổi tập

**Chủ trì:** Thành viên 2  
**Phụ thuộc:** Task 15

**Tiêu chí hoàn thành:**

- [x] Coach công bố một hướng dẫn dinh dưỡng hoạt động qua API.
- [x] Coach tạo/sửa buổi tập và cập nhật trạng thái qua API.
- [x] Member xem được lịch và nội dung tương ứng qua API.

**Còn thiếu:** Giao diện Flutter cho Coach và Member.

**Kiểm tra:** Test trạng thái buổi tập và quyền khi quan hệ tạm ngưng.

### Task 17: Nhật ký tập và ăn uống

**Chủ trì:** Thành viên 2  
**Phụ thuộc:** Task 16

**Tiêu chí hoàn thành:**

- [x] Member tạo/sửa nhật ký của mình qua API.
- [x] Coach hiện tại xem được; Admin và Coach khác không xem được.
- [x] Danh sách được phân trang.

**Còn thiếu:** Giao diện nhật ký Flutter.

**Kiểm tra:** Test quyền sở hữu, tải ảnh và giới hạn kích thước.

### Task 18: Số đo, ảnh và biểu đồ tiến bộ

**Chủ trì:** Thành viên 2  
**Phụ thuộc:** Task 17

**Tiêu chí hoàn thành:**

- [x] Member ghi số đo và ảnh theo ngày qua API.
- [ ] Flutter hiển thị biểu đồ cân nặng/số đo.
- [x] Coach nhận xét được; Coach cũ mất quyền sau khi quan hệ kết thúc qua API.

**Kiểm tra:** Test chuỗi thời gian, giá trị rỗng và ma trận quyền.

### Checkpoint 4

- [ ] Coach giao kế hoạch và Member ghi tiến độ end-to-end. **Một phần:** Backend đã có; Flutter chưa có.
- [x] Dữ liệu riêng tư không lộ cho Admin hoặc Coach khác ở backend.
- [ ] Biểu đồ hiển thị đúng dữ liệu theo ngày.

## Giai đoạn 5 — Giao tiếp và AI

### Task 19: Nhắn tin văn bản và hình ảnh

**Chủ trì:** Thành viên 3  
**Phụ thuộc:** Task 14

**Tiêu chí hoàn thành:**

- [ ] Member/Coach trong quan hệ hoạt động gửi và nhận được tin nhắn. **Một phần:** API đã có; Flutter chưa có.
- [ ] Có phân trang, polling, đã đọc, chưa đọc và gửi lại khi lỗi. **Một phần:** Backend có phân trang/đã đọc; polling/retry thuộc Flutter chưa có.
- [x] Quan hệ tạm ngưng/kết thúc chỉ được đọc lịch sử ở backend.

**Kiểm tra:** Test hai tài khoản, quyền truy cập và mất mạng tạm thời.

### Task 20: Cuộc gọi thoại và video

**Chủ trì:** Thành viên 3  
**Phụ thuộc:** Tasks 3, 14

**Tiêu chí hoàn thành:**

- [ ] Hai người trong quan hệ hoạt động gọi thoại/video được.
- [x] Quan hệ không hợp lệ không lấy được token cuộc gọi.
- [x] Lịch sử lưu loại, trạng thái và thời lượng; không ghi nội dung.

**Còn thiếu:** Provider RTC thật và màn hình gọi trên hai thiết bị.

**Kiểm tra:** Demo trên hai thiết bị, từ chối, nhỡ và kết thúc cuộc gọi.

### Task 21: AI Advisor

**Chủ trì:** Thành viên 3  
**Phụ thuộc:** Tasks 3–4

**Tiêu chí hoàn thành:**

- [ ] Member/Coach tạo cuộc trò chuyện và hỏi đáp văn bản được. **Một phần:** API đã có; Flutter và cấu hình OpenAI production chưa có.
- [x] Lịch sử chỉ thuộc người dùng hiện tại; có đổi tên/xóa qua API.
- [ ] Có timeout, thử lại và thông báo giới hạn an toàn. **Một phần:** Backend xử lý timeout/lỗi provider; Flutter chưa hiển thị.

**Kiểm tra:** Test quyền sở hữu, API lỗi, nội dung nguy hiểm và không lưu phản hồi dang dở.

### Checkpoint 5

- [ ] Messaging, call và AI hoạt động độc lập. **Một phần:** Các route/provider backend độc lập; Flutter chưa có.
- [ ] Dịch vụ ngoài lỗi không làm ứng dụng sập. **Một phần:** Backend trả lỗi `503`; Flutter chưa có để xác minh.
- [x] Không có khóa bí mật trong Flutter hoặc Git theo diff và cấu hình mẫu hiện tại.

## Giai đoạn 6 — Dashboard và hoàn thiện

### Task 22: Admin Dashboard

**Chủ trì:** Thành viên 3  
**Phụ thuộc:** Tasks 7, 11, 14, 18

**Tiêu chí hoàn thành:**

- [x] Hiển thị đúng các thẻ số liệu và biểu đồ theo thời gian trên Admin web.
- [x] Có danh sách Coach gần đủ suất, gói sắp hết hạn và yêu cầu chờ.
- [x] Các liên kết mở đúng màn hình nghiệp vụ Admin.

**Kiểm tra:** Đối chiếu số liệu với truy vấn database và dữ liệu seed.

### Task 23: Kiểm thử end-to-end và bảo mật quyền

**Chủ trì:** Cả nhóm  
**Phụ thuộc:** Tasks 4–22

**Tiêu chí hoàn thành:**

- [ ] Ba luồng Member, Coach, Admin chạy hoàn chỉnh.
- [ ] Ma trận quyền theo vai trò và trạng thái quan hệ vượt qua kiểm thử. **Một phần:** Backend có integration test; chưa có Flutter E2E.
- [ ] Dữ liệu lịch sử còn nguyên sau hết hạn, đổi Coach và khóa tài khoản. **Một phần:** Backend đã test hết hạn/đổi Coach; vẫn cần E2E khi khóa tài khoản.

**Kiểm tra:** Backend tests, Flutter tests, Admin build và checklist thủ công.

### Task 24: Hoàn thiện demo và tài liệu

**Chủ trì:** Cả nhóm  
**Phụ thuộc:** Task 23

**Tiêu chí hoàn thành:**

- [x] Có hướng dẫn cài đặt, biến môi trường và seed demo.
- [ ] Có ba tài khoản demo và kịch bản trình bày dự phòng. **Một phần:** Ba tài khoản demo đã có; kịch bản dự phòng chưa có.
- [ ] Báo cáo, sơ đồ và slide khớp với hệ thống thực tế.

**Kiểm tra:** Một thành viên không phụ trách phần đó cài lại và chạy demo từ tài liệu.

### Checkpoint cuối

- [x] `flutter analyze` và `flutter test` thành công với app khung hiện tại.
- [x] Backend check/test thành công tại thời điểm merge `92ca738`.
- [x] Admin web build thành công tại thời điểm merge `92ca738`.
- [x] Không còn lỗi nghiêm trọng hoặc cao trong phạm vi code đã review.
- [x] Người dùng review và duyệt kế hoạch trước khi bắt đầu code.

## Bằng chứng đối chiếu trạng thái

- Backend route được gắn tập trung tại `backend/src/app.js`; các module nghiệp vụ nằm trong `backend/src/routes/`.
- Backend có integration/unit test trong `backend/test/`, bao gồm auth, user, database, catalog, payment/coaching, training, progress, media, password reset và membership lifecycle.
- Admin web gọi các API dashboard, user, Coach, gói, payment, quan hệ, gym và thiết bị tại `admin-web/src/main.js`.
- Tại mốc đối chiếu `92ca738`, Flutter chỉ có màn hình khung tại `mobile-app/lib/main.dart`; nhận định này là lịch sử, không phải trạng thái hiện tại.
- Các provider AI, email và RTC chỉ hoạt động khi có biến môi trường; chưa có bằng chứng thử nghiệm provider thật hoặc hai thiết bị.

## Bổ sung 23/10/2026 — Task giao diện Flutter cơ bản để thử API

Đây là phần mở rộng của kế hoạch MVP, **không thay thế** trạng thái T01–T24 ở
trên. Mã `UI` chỉ áp dụng cho Member/Coach Flutter; Admin dùng web riêng. Mỗi
task dưới đây tạo trang hoặc lát cắt nhỏ có điều hướng, dữ liệu API thật, trạng
thái tải/rỗng/lỗi và test. Dùng giao diện Material tối giản, chưa làm design.
Khung nhập JSON hiện tại chỉ là công cụ đối chiếu, không tính là trang đã xong.

**Kiểm tra chung cho từng task:** `flutter test --no-pub` (test liên quan và
toàn bộ), `flutter analyze --no-pub`; kiểm thử tay với backend demo khi chạy
được. Nếu không có backend, báo rõ chỉ mới test bằng fake API. Mỗi task nên
chạm khoảng 3–5 file: trang, service/controller, router và test; nếu lớn hơn,
chia tiếp trước khi code. Giữ nguyên các thay đổi/nhánh chưa merge.

### Nền điều hướng và phần đã có

#### UI01 — Điều hướng nghiệp vụ theo vai trò

- [x] Member/Coach có danh mục trang riêng; không cần mở khung JSON để đi tới đường dẫn màn hình nghiệp vụ. Trang chưa làm hiển thị rõ mã task, không giả là đã có chức năng.
- [x] Chặn truy cập sai vai trò, giữ nút quay lại và trạng thái phiên; test điều hướng hai vai trò.
- **Phụ thuộc:** Không. **Phạm vi file:** `mobile-app/lib/app/`, hai trang home và test router. **Cỡ:** M.
- **Bằng chứng:** `flutter test --no-pub` 44/44, `flutter analyze --no-pub` sạch và build web thành công; màn hình nghiệp vụ thật triển khai từ UI02.

#### UI02 — Lịch sử và chi tiết thanh toán Member

- [x] Danh sách giao dịch, chi tiết, kết quả thanh toán và gói hiện tại dùng `/payments/me`, `/payments/:paymentId`, `/memberships/me`.
- [x] Có trạng thái chưa mua/chưa trả và thử lại khi lỗi; không phá luồng mua QR đã có.
- **Phụ thuộc:** UI01. **Kiểm thử tay:** mua QR → xác nhận → xem lịch sử/chi tiết. **Cỡ:** M.
- **Bằng chứng:** `flutter test --no-pub` 47/47, `flutter analyze --no-pub` sạch và build web thành công. Chưa kiểm thử tay luồng mua QR với backend đang chạy.

#### UI03 — Thông tin gym và chi tiết thiết bị

- [x] Member/Coach xem thông tin, giờ mở cửa, nội quy; tìm/lọc và mở chi tiết/hướng dẫn thiết bị.
- [x] Thiết bị ẩn không hiển thị; trạng thái rỗng/lỗi rõ ràng.
- **Phụ thuộc:** UI01. **Kiểm thử tay:** tìm thiết bị seed và mở chi tiết. **Cỡ:** M.
- **Bằng chứng:** `flutter test --no-pub` 51/51, `flutter analyze --no-pub` sạch và build web thành công. Chưa kiểm thử tay với backend và dữ liệu seed đang chạy.

**Checkpoint A:** UI01–UI03: điều hướng đúng vai trò; test/analyze và build đạt.

### Quan hệ Member–Coach

#### UI04 — Member xem Coach và gửi yêu cầu

- [x] Danh sách, chi tiết, suất trống Coach; biểu mẫu gửi yêu cầu có lời nhắn qua `/coaches` và `/coach-requests`.
- [x] Khóa nút khi gửi, hiển thị lỗi thiếu gói/đã có yêu cầu/hết suất; test các trạng thái.
- **Phụ thuộc:** UI01–UI02. **Kiểm thử tay:** chọn Coach bằng tài khoản Member có gói. **Cỡ:** M.
- **Bằng chứng:** `flutter test --no-pub` 57/57, `flutter analyze --no-pub` sạch và build web thành công. Chưa kiểm thử tay với backend và tài khoản Member có gói đang chạy.

#### UI05 — Member theo dõi và kết thúc quan hệ

- [x] Trang yêu cầu chờ/lịch sử, hủy yêu cầu; Coach hiện tại/lịch sử và kết thúc kèm lý do.
- [x] Xác nhận thao tác kết thúc; giao diện làm mới đúng sau hủy hoặc kết thúc.
- **Phụ thuộc:** UI04. **Kiểm thử tay:** gửi → hủy; gửi lại → được duyệt → kết thúc. **Cỡ:** M.
- **Bằng chứng:** `flutter test --no-pub` 61/61, `flutter analyze --no-pub` sạch và build web thành công. Chưa kiểm thử tay với hai tài khoản Member/Coach và backend đang chạy.

#### UI06 — Coach xử lý yêu cầu

- [x] Danh sách, chi tiết yêu cầu; chấp nhận hoặc từ chối kèm lý do bắt buộc.
- [x] Sau quyết định, danh sách và số suất cập nhật; lỗi yêu cầu hết hiệu lực được hiển thị.
- **Phụ thuộc:** UI04. **Kiểm thử tay:** Coach duyệt yêu cầu Member vừa gửi. **Cỡ:** M.
- **Bằng chứng:** `flutter test --no-pub` 65/65, `flutter analyze --no-pub` sạch và build web thành công. Chưa kiểm thử tay với hai tài khoản Member/Coach và backend đang chạy.

#### UI07 — Coach xem Member và xin ngừng phụ trách

- [x] Danh sách/chi tiết Member đang phụ trách; gửi lý do và xem trạng thái yêu cầu ngừng phụ trách.
- [x] Member không còn thuộc quyền thì không giữ dữ liệu riêng trên màn hình.
- **Khoảng trống:** lịch sử Member Coach từng phụ trách trong đặc tả chưa có API riêng; không dùng API Member để thay thế.
- **Phụ thuộc:** UI06. **Kiểm thử tay:** duyệt → xem Member → gửi yêu cầu ngừng. **Cỡ:** M.
- **Bằng chứng:** `flutter test --no-pub` 70/70, `flutter analyze --no-pub` sạch và build web thành công. Chưa kiểm thử tay với hai tài khoản Member/Coach và backend đang chạy.

**Checkpoint B:** UI04–UI07: Member chọn Coach → Coach duyệt → hai bên thấy quan hệ; test/analyze/build đạt.

### Giáo trình, dinh dưỡng và lịch tập

#### UI08 — Member xem giáo trình

- [x] Trang kế hoạch hiện hành/lịch sử; chi tiết ngày tập, bài tập và trạng thái công bố.
- [x] Không hiện bản nháp; có thông báo khi chưa được giao kế hoạch.
- **Phụ thuộc:** UI06. **Kiểm thử tay:** Coach công bố, Member xem đúng bản. **Cỡ:** M.
- **Bằng chứng:** `flutter test --no-pub` 72/72, `flutter analyze --no-pub` sạch và build web thành công. Chưa kiểm thử tay với Coach/Member và backend đang chạy.

#### UI09 — Coach tạo và sửa giáo trình nháp

- [x] Danh sách kế hoạch theo Member; biểu mẫu tiêu đề, mục tiêu, ngày tập và bài tập cơ bản.
- [x] Tạo/sửa bản nháp, xem trước dữ liệu đã nhập; test validation tối thiểu.
- **Phụ thuộc:** UI07. **Kiểm thử tay:** tạo kế hoạch một ngày, một bài tập. **Cỡ:** M.
- **Bằng chứng:** `flutter test --no-pub` 74/74, `flutter analyze --no-pub` sạch và build web thành công. Chưa kiểm thử tay với backend đang chạy.

#### UI10 — Coach công bố giáo trình

- [x] Từ chi tiết bản nháp có nút công bố kèm xác nhận; hiển thị trạng thái và phiên bản.
- [x] Sau công bố, bản cũ vào lịch sử và Member thấy bản mới; lỗi quan hệ hết hiệu lực rõ ràng.
- **Phụ thuộc:** UI09. **Kiểm thử tay:** công bố hai phiên bản liên tiếp. **Cỡ:** S–M.
- **Bằng chứng:** `flutter test --no-pub` 76/76, `flutter analyze --no-pub` sạch và build web thành công. Chưa kiểm thử tay với backend đang chạy.

#### UI11 — Member xem hướng dẫn dinh dưỡng

- [x] Trang hướng dẫn hiện hành và lịch sử qua API dinh dưỡng.
- [x] Hiển thị nội dung, ngày công bố và trạng thái chưa có hướng dẫn.
- **Phụ thuộc:** UI01. **Kiểm thử tay:** xem hướng dẫn Coach đã công bố. **Cỡ:** S–M.
- **Bằng chứng:** `flutter test --no-pub` 78/78, `flutter analyze --no-pub` sạch và build web thành công. Chưa kiểm thử tay với backend đang chạy.

#### UI12 — Coach tạo và công bố hướng dẫn dinh dưỡng

- [x] Theo từng Member, Coach xem danh sách, tạo/sửa nội dung và công bố.
- [x] Member chỉ thấy bản đã công bố; lỗi khi quan hệ không hoạt động được xử lý.
- **Phụ thuộc:** UI07. **Kiểm thử tay:** tạo → sửa → công bố → kiểm tra ở UI11. **Cỡ:** M.
- **Bằng chứng:** `flutter test --no-pub` 80/80, `flutter analyze --no-pub` sạch và build web thành công. Chưa kiểm thử tay với backend đang chạy.

#### UI13 — Member xem lịch buổi tập

- [x] Danh sách lịch và chi tiết buổi tập, thời gian/ghi chú/trạng thái.
- [x] Có trạng thái chưa có lịch, làm mới và định dạng giờ địa phương.
- **Phụ thuộc:** UI01. **Kiểm thử tay:** xem buổi Coach tạo. **Cỡ:** S–M.
- **Bằng chứng:** `flutter test --no-pub` 83/83, `flutter analyze --no-pub` sạch và build web thành công. Chưa kiểm thử tay với backend đang chạy.

#### UI14 — Coach quản lý buổi tập

- [ ] Tạo/sửa lịch cho Member; đổi trạng thái hoàn thành, vắng hoặc hủy theo API.
- [ ] Kiểm tra thời gian và lý do hủy; sau cập nhật Member thấy trạng thái mới.
- **Phụ thuộc:** UI07. **Kiểm thử tay:** tạo → đổi lịch → hoàn thành/hủy. **Cỡ:** M.

**Checkpoint C:** UI08–UI14: Coach giao giáo trình/dinh dưỡng/lịch → Member xem; test/analyze/build đạt.

### Tiến độ và ảnh

#### UI15 — Member xem tổng quan và biểu đồ

- [ ] Tổng quan số liệu gần nhất và biểu đồ theo khoảng thời gian từ API tiến độ.
- [ ] Có lọc khoảng ngày, trạng thái chưa có dữ liệu và test dữ liệu chuỗi thời gian.
- **Phụ thuộc:** UI01. **Kiểm thử tay:** thêm số đo rồi xem biểu đồ. **Cỡ:** M.

#### UI16 — Member ghi nhật ký tập

- [ ] Danh sách, chi tiết tóm tắt, tạo và sửa nhật ký tập; chọn ngày, thời lượng, bài tập cơ bản.
- [ ] Validation và lỗi quyền/quan hệ; danh sách cập nhật sau lưu.
- **Phụ thuộc:** UI01. **Kiểm thử tay:** tạo → sửa → mở lại. **Cỡ:** M.

#### UI17 — Member ghi nhật ký ăn

- [ ] Danh sách, tạo/sửa bữa ăn với thời gian, tên, loại và calo tùy chọn.
- [ ] Có trạng thái rỗng/lỗi và test dữ liệu nhập hợp lệ/không hợp lệ.
- **Phụ thuộc:** UI01. **Kiểm thử tay:** tạo → sửa → mở lại. **Cỡ:** M.

#### UI18 — Member cập nhật số đo

- [ ] Lịch sử, thêm/sửa cân nặng và số đo cơ bản theo ngày.
- [ ] Không gửi giá trị sai/âm; sau lưu UI15 làm mới được.
- **Phụ thuộc:** UI15. **Kiểm thử tay:** thêm hai lần đo và đối chiếu biểu đồ. **Cỡ:** M.

#### UI19 — Member tải và xem ảnh tiến trình

- [ ] Chọn ảnh, tải multipart qua `/media/images`, tạo bản ghi ảnh tiến trình và xem ảnh qua URL có chữ ký.
- [ ] Giới hạn loại/dung lượng, trạng thái đang tải/lỗi/thử lại; không xem được ảnh người khác.
- **Phụ thuộc:** UI01. **Kiểm thử tay:** chọn ảnh thật → tải → mở lại ảnh. **Cỡ:** M; tách tiếp nếu vượt 5 file.

#### UI20 — Coach xem tiến độ và gửi nhận xét

- [ ] Từ chi tiết Member mở tổng quan, nhật ký, số đo, ảnh và nhận xét.
- [ ] Gửi nhận xét theo Member hoặc một bản ghi; hết quan hệ thì mất quyền truy cập.
- **Khoảng trống:** biểu đồ theo Member cho Coach trong đặc tả chưa có API riêng; tổng quan/số đo vẫn thử được.
- **Phụ thuộc:** UI07, UI16–UI19. **Kiểm thử tay:** Member ghi → Coach xem/nhận xét → Member đọc. **Cỡ:** M; tách nếu vượt 5 file.

**Checkpoint D:** UI15–UI20: Member ghi tiến độ → Coach nhận xét; test/analyze/build đạt.

### Giao tiếp và AI

#### UI21 — Danh sách cuộc trò chuyện

- [ ] Member/Coach thấy các cuộc trò chuyện và số tin chưa đọc, mở đúng quan hệ.
- [ ] Danh sách rỗng/lỗi, quan hệ kết thúc vẫn mở được lịch sử chỉ đọc.
- **Phụ thuộc:** UI05–UI07. **Kiểm thử tay:** hai tài khoản cùng quan hệ mở hội thoại. **Cỡ:** S–M.

#### UI22 — Chat văn bản cơ bản

- [ ] Tải tin theo trang, gửi văn bản với `clientMessageId` ổn định; hiển thị tin mới.
- [ ] Chặn gửi khi quan hệ không hoạt động; chống gửi trùng do chạm nhiều lần.
- **Phụ thuộc:** UI21. **Kiểm thử tay:** Member gửi, Coach đọc và trả lời. **Cỡ:** M.

#### UI23 — Đã đọc, polling và gửi lại

- [ ] Hội thoại tự làm mới bằng polling khi đang mở; cập nhật đã đọc và số tin chưa đọc.
- [ ] Tin gửi lỗi có nút thử lại cùng `clientMessageId`; dừng polling khi rời trang.
- **Phụ thuộc:** UI22. **Kiểm thử tay:** mất mạng tạm thời rồi gửi lại. **Cỡ:** M.

#### UI24 — Ảnh trong tin nhắn

- [ ] Tái dùng upload ảnh UI19; gửi tin `IMAGE` và hiển thị ảnh qua URL có chữ ký.
- [ ] Có trạng thái ảnh lỗi/hết hạn và thử tải lại; không hỗ trợ tệp khác.
- **Phụ thuộc:** UI19, UI22. **Kiểm thử tay:** gửi và mở ảnh trên hai tài khoản. **Cỡ:** M.

#### UI25 — Màn hình trạng thái và lịch sử cuộc gọi

- [ ] Có trang lịch sử, tạo cuộc gọi, cập nhật trạng thái và màn hình đang gọi/đã kết thúc ở mức metadata API.
- [ ] Nếu token/provider RTC chưa cấu hình, hiển thị rõ không thể kết nối; **không** giả làm cuộc gọi thoại/video thật.
- **Phụ thuộc:** UI05–UI07. **Kiểm thử tay:** tạo bản ghi → cập nhật → xem lịch sử. **Cỡ:** M.

#### UI26 — Danh sách và quản lý hội thoại AI

- [ ] Member/Coach xem, tạo, đổi tên và xóa hội thoại AI của chính mình.
- [ ] Có xác nhận xóa, trạng thái rỗng/lỗi và không lộ hội thoại người khác.
- **Phụ thuộc:** UI01. **Kiểm thử tay:** tạo → đổi tên → xóa. **Cỡ:** M.

#### UI27 — Hỏi đáp AI cơ bản

- [ ] Trang tin nhắn AI, gửi câu hỏi với `clientRequestId` ổn định, hiển thị câu trả lời và cảnh báo tham khảo.
- [ ] API 503/timeout có thông báo và thử lại; không hiển thị phản hồi dang dở như thành công.
- **Phụ thuộc:** UI26. **Kiểm thử tay:** hỏi thật khi provider sẵn; nếu chưa, xác nhận 503. **Cỡ:** M.

**Checkpoint E:** UI21–UI27: chat/AI xử lý lỗi tốt; call chỉ metadata nếu chưa có RTC; test/analyze/build đạt.

### Tích hợp

#### UI28 — Kiểm thử liên thông và dọn khung tạm

- [ ] Chạy kịch bản Member mua gói → chọn Coach → Coach giao kế hoạch → Member ghi tiến độ → Coach nhận xét/chat.
- [ ] Mọi chức năng cơ bản đi được qua trang nghiệp vụ; khung JSON chỉ còn chế độ developer hoặc được gỡ sau khi đối chiếu độ phủ.
- **Phụ thuộc:** UI01–UI27. **Kiểm thử:** hai tài khoản demo, backend thật, toàn bộ test/analyze/build và ma trận quyền. **Cỡ:** M; chia lỗi phát hiện thành task riêng.

**Ngoài phạm vi đợt UI cơ bản:** tích hợp RTC thoại/video thật trên hai thiết
bị, email provider thật, thiết kế hình ảnh cuối và phát hành production. Các
phần này vẫn thuộc kế hoạch MVP chung, không được đánh dấu hoàn thành nhờ UI25.

