# Implementation Plan: Meta Gym MVP

## Overview

Meta Gym được triển khai trong 8 tuần bởi 3 thành viên có trình độ tương đương. Kế hoạch dùng lát cắt dọc: mỗi tính năng được hoàn thành từ database → API → giao diện → kiểm thử trước khi chuyển sang tính năng tiếp theo. Phạm vi nghiệp vụ chuẩn nằm tại `docs/requirements/confirmed-workflows.md`.

## Quyết định kiến trúc

- Backend là modular monolith Node.js/Express; mỗi module có route, controller/service, validation và truy vấn dữ liệu riêng.
- PostgreSQL là nguồn dữ liệu duy nhất; migration và seed được lưu trong `database/`.
- API REST dùng JWT và kiểm tra quyền tại backend.
- Flutter tổ chức theo feature; `dio`, `provider`, `go_router` và `flutter_secure_storage` tiếp tục được sử dụng.
- Admin web dùng JavaScript modules, Bootstrap và Chart.js; không thêm framework frontend khác.
- Messaging dùng REST và polling trong MVP; không thêm push notification.
- Voice/video dùng SDK bên thứ ba qua một lớp adapter; không tự triển khai WebRTC.
- AI chỉ được gọi từ backend qua một lớp provider; khóa API không đi vào ứng dụng Flutter.
- Email đặt lại mật khẩu, AI và voice/video phải được chạy thử kỹ thuật ngay trong tuần 1 để phát hiện sớm rủi ro dịch vụ ngoài.
- Ảnh tải lên đi qua một lớp lưu trữ thống nhất. Bản demo có thể dùng lưu trữ cục bộ; giao diện adapter cho phép đổi sang dịch vụ đám mây mà không sửa nghiệp vụ.
- Backend lưu thời gian theo UTC; ứng dụng hiển thị theo múi giờ `Asia/Ho_Chi_Minh`.

## Thứ tự phụ thuộc

```text
Schema + migration
    └── Identity & Access
          ├── Membership & Payment
          │     └── Coaching Relationship
          │            ├── Training & Nutrition
          │            │       └── Progress Tracking
          │            ├── Messaging
          │            └── Voice & Video Call
          ├── AI Advisor
          ├── Gym Content
          └── Admin Dashboard (đọc dữ liệu từ các module trên)
```

## Phân công chính

| Thành viên | Sở hữu chính | Trách nhiệm bổ sung |
| --- | --- | --- |
| Thành viên 1 | Identity & Access; Membership & Payment | Nền tảng backend, migration, bảo mật và tích hợp cuối |
| Thành viên 2 | Coaching Relationship; Training & Nutrition; Progress Tracking | Flutter cho luồng Member/Coach và biểu đồ |
| Thành viên 3 | Messaging; Voice & Video Call; AI Advisor; Gym Content; Admin Dashboard | Admin web và các dịch vụ bên thứ ba |

Mỗi module phải có một người sở hữu và một người review. Không để một thành viên tự merge phần mình mà chưa có review chéo.

## Kế hoạch 8 tuần

### Tuần 1 — Nền tảng và kiểm chứng rủi ro

- Chốt schema, quy ước API, cấu trúc thư mục và quy trình Git.
- Tạo migration/seed nền tảng và lớp truy cập database.
- Dựng khung xác thực, xử lý lỗi và validation.
- Chạy thử email đặt lại mật khẩu, AI API và SDK voice/video trên thiết bị thật.
- Chọn provider hoạt động ổn định sau thử nghiệm; giữ mã nguồn qua adapter.

**Checkpoint:** backend kết nối PostgreSQL, Flutter gọi health API, admin web gọi API, ba dịch vụ ngoài có bản thử nghiệm hoặc phương án thay thế.

### Tuần 2 — Tài khoản và nội dung phòng gym

- Hoàn thành đăng ký, đăng nhập, phân quyền, hồ sơ và quên mật khẩu.
- Hoàn thành quản lý tài khoản trên Admin web.
- Hoàn thành Gym Content từ database đến Flutter và Admin web.

**Checkpoint:** Member tự đăng ký/đăng nhập; Coach do Admin tạo; quyền sai vai trò bị backend từ chối.

### Tuần 3 — Gói tập, thanh toán và yêu cầu Coach

- Hoàn thành gói tập, QR mô phỏng, giao dịch tại quầy và quy tắc nối tiếp thời hạn.
- Hoàn thành danh sách Coach, chi tiết Coach và gửi/hủy yêu cầu.
- Hoàn thành Coach chấp nhận/từ chối và kiểm tra giới hạn.

**Checkpoint:** Member mua gói và tạo được một quan hệ Coach hợp lệ từ đầu đến cuối.

### Tuần 4 — Vòng đời quan hệ và giáo trình

- Hoàn thành tạm ngưng/kích hoạt lại theo gói tập.
- Hoàn thành kết thúc, yêu cầu kết thúc và chuyển Coach do Admin.
- Hoàn thành giáo trình tập, ngày tập, bài tập và công bố kế hoạch.

**Checkpoint:** quyền dữ liệu thay đổi đúng khi quan hệ hoạt động, tạm ngưng hoặc kết thúc.

### Tuần 5 — Dinh dưỡng, lịch tập và tiến độ

- Hoàn thành hướng dẫn dinh dưỡng và lịch buổi tập.
- Hoàn thành nhật ký tập, nhật ký ăn, số đo, ảnh và nhận xét Coach.
- Hoàn thành biểu đồ tiến độ cơ bản.

**Checkpoint:** Coach giao kế hoạch; Member ghi tiến độ; Coach xem và phản hồi được.

### Tuần 6 — Nhắn tin, cuộc gọi và AI

- Hoàn thành nhắn tin văn bản/hình ảnh, phân trang, polling và trạng thái đã đọc.
- Hoàn thành gọi thoại/video một-một và lịch sử cuộc gọi.
- Hoàn thành AI hỏi đáp văn bản, lịch sử và giới hạn an toàn.

**Checkpoint:** các chức năng giao tiếp chỉ hoạt động với quan hệ đang hoạt động; khóa dịch vụ ngoài chỉ tồn tại ở backend/cấu hình an toàn.

### Tuần 7 — Dashboard và tích hợp toàn hệ thống

- Hoàn thành Admin Dashboard.
- Ghép các module, sửa lỗi điều hướng, trạng thái tải/rỗng/lỗi.
- Kiểm tra dữ liệu lịch sử khi hết hạn, đổi Coach và khóa tài khoản.
- Hoàn thiện responsive của Admin web và luồng Android chính.

**Checkpoint:** ba luồng Member, Coach và Admin chạy end-to-end trên dữ liệu seed và dữ liệu tạo mới.

### Tuần 8 — Ổn định, tài liệu và bảo vệ

- Kiểm thử phân quyền, API, Flutter và Admin web.
- Sửa lỗi mức nghiêm trọng/cao; đóng băng tính năng mới.
- Chuẩn bị dữ liệu demo, tài khoản demo, kịch bản trình bày và video dự phòng.
- Hoàn thiện báo cáo, sơ đồ, hướng dẫn cài đặt và slide.

**Checkpoint cuối:** build sạch, kiểm thử đạt, demo hoàn chỉnh và có phương án khi dịch vụ ngoài gián đoạn.

## Mốc review bắt buộc

- Cuối mỗi tuần: demo chức năng chạy thật, không chỉ trình bày ảnh.
- Sau mỗi 2–3 task: chạy test/build và review chéo.
- Cuối tuần 4: khóa schema chính; thay đổi sau đó cần cả nhóm đồng ý.
- Đầu tuần 8: ngừng thêm chức năng, chỉ sửa lỗi và hoàn thiện tài liệu.

## Rủi ro và cách giảm thiểu

| Rủi ro | Mức độ | Giảm thiểu |
| --- | --- | --- |
| SDK cuộc gọi khó tích hợp hoặc giới hạn tài khoản | Cao | Spike tuần 1; adapter; chuẩn bị chế độ demo bằng hai thiết bị |
| AI API hết hạn mức hoặc phản hồi chậm | Cao | Provider adapter, timeout, thông báo thử lại, kịch bản demo dự phòng |
| Email xác nhận không đến | Trung bình | Kiểm tra SMTP sớm; mã có hạn; Admin có thể hỗ trợ đặt lại Coach |
| Phạm vi quá lớn | Cao | Không thêm tính năng ngoài tài liệu; khóa tính năng từ đầu tuần 8 |
| Xung đột code giữa 3 người | Trung bình | Chia theo module, nhánh ngắn, pull request nhỏ, review chéo |
| Sai quyền truy cập dữ liệu riêng tư | Cao | Test ma trận vai trò và trạng thái quan hệ ở backend |
| Ảnh làm tăng dung lượng | Trung bình | Giới hạn loại/kích thước, nén phía ứng dụng, adapter lưu trữ |
| Dữ liệu hết hạn không đồng bộ | Trung bình | Một service trung tâm cập nhật membership và relationship trong transaction |

## Điều kiện bắt đầu lập trình

- Tài liệu nghiệp vụ được người dùng review lần cuối.
- Schema và API contract được nhóm đồng ý.
- Ba thử nghiệm email, AI và voice/video có kết quả.
- `tasks/todo.md` được dùng làm danh sách công việc chung.

## Bổ sung 23/10/2026 — Giao diện Flutter cơ bản để thử API

Phần này bổ sung cho kế hoạch MVP phía trên, không thay đổi trạng thái các task
cũ. Danh sách thực hiện chi tiết mang mã `UI01`–`UI28` nằm ở cuối
[`todo.md`](./todo.md). Phạm vi chỉ là app Flutter Member/Coach; Admin tiếp tục
dùng `admin-web`. Khung JSON trên nhánh `codex/functional-ui-scaffold` là công
cụ thử API tạm thời, **không được xem là trang nghiệp vụ hoàn chỉnh**.

**Quyết định triển khai:** Mỗi trang dùng danh sách/chi tiết/biểu mẫu tối giản,
gọi API qua `ApiClient` hiện có; có tải, rỗng, lỗi, thử lại và chống gửi lặp.
Không làm màu sắc, hình ảnh thương hiệu, animation hoặc bố cục cuối. Mỗi task
chỉ hoàn thành khi widget/controller test đạt và kiểm thử thủ công với backend
demo nếu môi trường sẵn sàng. Nếu backend chưa chạy, ghi rõ `chưa xác nhận E2E`.

**Thứ tự phụ thuộc:** UI01 điều hướng → UI04–UI07 quan hệ Coach → UI08–UI14
giáo trình/dinh dưỡng/lịch và UI15–UI20 tiến độ → UI21–UI25 giao tiếp;
UI26–UI27 AI độc lập sau UI01. UI02–UI03 có thể làm ngay sau UI01. UI28 là
kiểm thử liên thông sau toàn bộ trang cơ bản.

**Checkpoint:** Sau UI03 kiểm tra nền điều hướng; sau UI07 kiểm tra Member chọn
Coach → Coach duyệt; sau UI14 kiểm tra Coach giao kế hoạch → Member xem; sau
UI20 kiểm tra Member ghi tiến độ → Coach nhận xét; sau UI27 kiểm tra giao tiếp
và xử lý dịch vụ ngoài không khả dụng. Mỗi checkpoint chạy toàn bộ `flutter
test`, `flutter analyze` và build web/Android phù hợp.

**Ranh giới:** UI25 chỉ thử API metadata và trạng thái cuộc gọi. Gọi thoại/video
trực tiếp cần provider/SDK và thử trên hai thiết bị — đây là công việc tích hợp
riêng, không đánh dấu hoàn thành nhờ khung API. UI19/UI24 bao gồm chọn và tải ảnh
multipart; không dùng ảnh giả để đánh dấu luồng hoàn thành. Thiết kế cuối cùng
và rà soát UX chuyên sâu làm sau đợt kiểm thử API này.

**Khoảng trống API cần quyết định khi tới UI07/UI20:** đặc tả có lịch sử Member
Coach từng phụ trách và biểu đồ tiến độ theo từng Member cho Coach, nhưng route
hiện tại chỉ có danh sách quan hệ `ACTIVE`/`PAUSED` và tổng quan tiến độ. Không
tự hiển thị dữ liệu riêng qua API Member hoặc đánh dấu hai màn hình đó xong;
nếu vẫn cần, tạo task backend nhỏ bổ sung contract/quyền trước khi làm UI.

