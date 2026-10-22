# Meta Gym — Kế hoạch các phần còn lại

> Cập nhật: 22/10/2026
> Điểm bắt đầu: `main` tại commit `92ca738`
> Phạm vi: hoàn thiện Flutter Member/Coach, tích hợp dịch vụ thật, triển khai cloud, kiểm thử và demo.
> Lưu ý: database, backend API MVP và admin web MVP đã có; không xây lại nếu API hiện tại đã đáp ứng.

## Cách thực hiện

- Làm theo thứ tự task và dependency bên dưới.
- Mỗi task dùng một nhánh `codex/<mã-task>-<tên-ngắn>`.
- Mỗi task chỉ được đánh dấu hoàn thành sau khi đạt toàn bộ tiêu chí và bước kiểm tra.
- Sau mỗi checkpoint: review code, chạy lại test liên quan, rồi mới gộp vào `main`.
- Không commit `.env`, khóa API, token hoặc mật khẩu thật.

## Tóm tắt thứ tự

| Giai đoạn | Task | Kết quả |
|---|---|---|
| 0. Đồng bộ dự án | T01–T03 | Checklist đúng, dữ liệu demo, kiểm tra API nền |
| 1. Flutter nền tảng | T04–T08 | App có cấu trúc, API client và xác thực |
| 2. Luồng Member | T09–T16 | Member sử dụng được toàn bộ nghiệp vụ MVP |
| 3. Luồng Coach | T17–T21 | Coach quản lý Member và nội dung huấn luyện |
| 4. Hoàn thiện Admin | T22–T23 | Bổ sung nội dung và trạng thái lỗi/loading |
| 5. Dịch vụ bên ngoài | T24–T27 | Email, AI, ảnh và RTC hoạt động thật |
| 6. Cloud và CI | T28–T32 | Hệ thống có URL public và quy trình kiểm tra tự động |
| 7. Kiểm thử và demo | T33–T36 | Ba vai trò chạy end-to-end, có APK và tài liệu bảo vệ |

---

## Giai đoạn 0 — Đồng bộ trạng thái và dữ liệu nền

### T01 — Cập nhật checklist theo code hiện tại

**Trạng thái:** Hoàn thành ngày 22/10/2026 trên nhánh `codex/t01-sync-checklist`.

**Mô tả:** Đối chiếu `tasks/todo.md` với backend, admin web và kết quả test đã merge; chỉ đánh dấu những mục có bằng chứng trong code/test.

**Tiêu chí hoàn thành:**
- [x] Các mục backend/admin đã làm được đánh dấu đúng.
- [x] Các mục chỉ mới có API nhưng chưa có Flutter được ghi chú rõ.
- [x] Không đánh dấu hoàn thành dựa trên suy đoán.

**Kiểm tra:** [x] Đã review diff của `tasks/todo.md` và đối chiếu từng mục với file hoặc test tương ứng.

**Phụ thuộc:** Không.
**File dự kiến:** `tasks/todo.md`, `README.md`.
**Quy mô:** S.

### T02 — Tạo demo seed độc lập

**Mô tả:** Tạo seed development/test có ba tài khoản Admin, Coach, Member và dữ liệu gói tập, thiết bị, bài tập mẫu.

**Tiêu chí hoàn thành:**
- [ ] Seed chạy lặp không tạo dữ liệu trùng.
- [ ] Có thông tin đăng nhập demo không dùng trong production.
- [ ] Baseline seed production không bị thay đổi mục đích.

**Kiểm tra:** Dựng database mới, chạy migration + baseline + demo seed hai lần và xác nhận dữ liệu hợp lệ.

**Phụ thuộc:** Không.
**File dự kiến:** `database/seeds/0002_demo.sql`, `database/README.md`.
**Quy mô:** S.

### T03 — Tạo bộ smoke test cho API MVP

**Mô tả:** Ghi lại và tự động hóa các yêu cầu API tối thiểu cho đăng nhập, health, Member, Coach và Admin để dùng sau mỗi lần triển khai.

**Tiêu chí hoàn thành:**
- [ ] Kiểm tra được health và đăng nhập ba vai trò.
- [ ] Mỗi vai trò có ít nhất một API nghiệp vụ được kiểm tra.
- [ ] Script thất bại với mã thoát khác 0 khi response sai.

**Kiểm tra:** Chạy smoke test trên database demo và backend local.

**Phụ thuộc:** T02.
**File dự kiến:** `backend/test/smoke/`, `backend/package.json`.
**Quy mô:** M.

### Checkpoint A — Nền tảng dữ liệu

- [ ] Backend check/test thành công.
- [ ] Database dựng mới được từ tài liệu.
- [ ] Ba tài khoản demo đăng nhập được qua API.

---

## Giai đoạn 1 — Flutter nền tảng và xác thực

### T04 — Chuẩn hóa cấu trúc Flutter

**Mô tả:** Chia app theo `core` và `features`, thiết lập theme, router và cấu hình API theo môi trường.

**Tiêu chí hoàn thành:**
- [ ] Không còn đặt toàn bộ app trong `main.dart`.
- [ ] Có cấu hình API URL cho local/emulator/production.
- [ ] Có route công khai, route Member và route Coach.

**Kiểm tra:** `flutter analyze`, `flutter test`; mở app không lỗi và điều hướng được màn hình mẫu.

**Phụ thuộc:** Không.
**File dự kiến:** `mobile-app/lib/main.dart`, `mobile-app/lib/app/`, `mobile-app/lib/core/`.
**Quy mô:** M.

### T05 — Xây API client và chuẩn hóa lỗi

**Mô tả:** Bọc Dio thành client dùng chung, giải mã response/error, timeout và log an toàn.

**Tiêu chí hoàn thành:**
- [ ] Base URL, timeout và header được cấu hình tập trung.
- [ ] Lỗi mạng, 401, 403, 422 và 5xx có kiểu lỗi rõ ràng.
- [ ] Log không chứa token hoặc mật khẩu.

**Kiểm tra:** Unit test client bằng mock adapter cho response thành công, validation và hết phiên.

**Phụ thuộc:** T04.
**File dự kiến:** `mobile-app/lib/core/network/`, `mobile-app/test/core/network/`.
**Quy mô:** M.

### T06 — Quản lý phiên và token an toàn

**Mô tả:** Lưu access token bằng secure storage, khôi phục phiên khi mở app và xóa phiên khi hết hạn/đăng xuất.

**Tiêu chí hoàn thành:**
- [ ] Token không lưu trong SharedPreferences hoặc log.
- [ ] Mở lại app khôi phục đúng vai trò.
- [ ] Response 401 đưa người dùng về đăng nhập một lần, không lặp vô hạn.

**Kiểm tra:** Widget/unit test cho trạng thái chưa đăng nhập, đã đăng nhập và token hết hạn.

**Phụ thuộc:** T05.
**File dự kiến:** `mobile-app/lib/features/auth/`, `mobile-app/lib/core/storage/`.
**Quy mô:** M.

### T07 — Màn hình đăng nhập và đăng ký Member

**Mô tả:** Kết nối form đăng nhập/đăng ký với API và hiển thị lỗi xác thực bằng tiếng Việt.

**Tiêu chí hoàn thành:**
- [ ] Member đăng ký và đăng nhập được.
- [ ] Coach/Admin đăng nhập được nhưng không thể tự đăng ký.
- [ ] Form chặn dữ liệu sai cơ bản và tránh gửi lặp.

**Kiểm tra:** Widget test form; thử thật với ba tài khoản demo.

**Phụ thuộc:** T06.
**File dự kiến:** `mobile-app/lib/features/auth/`, `mobile-app/test/features/auth/`.
**Quy mô:** M.

### T08 — Hồ sơ, đổi mật khẩu và quên mật khẩu

**Mô tả:** Hoàn thiện màn hình hồ sơ, sửa thông tin, đổi mật khẩu và quy trình mã khôi phục.

**Tiêu chí hoàn thành:**
- [ ] Member/Coach chỉ sửa được trường backend cho phép.
- [ ] Đổi mật khẩu làm phiên cũ mất hiệu lực theo contract.
- [ ] Luồng yêu cầu mã → xác minh → đặt mật khẩu mới hoạt động.

**Kiểm tra:** Widget test và chạy thủ công toàn bộ luồng với backend local.

**Phụ thuộc:** T07.
**File dự kiến:** `mobile-app/lib/features/profile/`, `mobile-app/lib/features/auth/`.
**Quy mô:** M.

### Checkpoint B — Flutter xác thực

- [ ] `flutter analyze` và `flutter test` thành công.
- [ ] Member, Coach và Admin được điều hướng đúng vai trò.
- [ ] Đóng/mở app vẫn giữ hoặc hủy phiên đúng điều kiện.

---

## Giai đoạn 2 — Luồng Member

### T09 — Trang chủ Member và nội dung phòng gym

**Mô tả:** Tạo shell điều hướng Member, trang chủ, thông tin phòng gym, thiết bị và bài tập.

**Tiêu chí hoàn thành:**
- [ ] Có navigation nhất quán trên kích thước điện thoại phổ biến.
- [ ] Danh sách có loading, empty, error và tìm kiếm cơ bản.
- [ ] Nội dung bị ẩn không hiển thị.

**Kiểm tra:** Widget test các trạng thái; thử với API demo.

**Phụ thuộc:** T07.
**File dự kiến:** `mobile-app/lib/features/member_home/`, `mobile-app/lib/features/catalog/`.
**Quy mô:** M.

### T10 — Gói tập và thanh toán QR mô phỏng

**Mô tả:** Cho Member xem gói, tạo giao dịch, xem QR/thông tin thanh toán và xác nhận mô phỏng.

**Tiêu chí hoàn thành:**
- [ ] Chỉ hiển thị gói đang áp dụng.
- [ ] Nút xác nhận chống gửi lặp.
- [ ] Sau thành công hiển thị membership hiện tại và lịch sử.

**Kiểm tra:** Chạy luồng mua gói đầu tiên và mua nối tiếp; xác nhận lặp không tạo hai membership.

**Phụ thuộc:** T09.
**File dự kiến:** `mobile-app/lib/features/membership/`, `mobile-app/test/features/membership/`.
**Quy mô:** M.

### T11 — Danh sách Coach và yêu cầu chọn Coach

**Mô tả:** Cho Member xem Coach, sức chứa còn lại, gửi/hủy yêu cầu và theo dõi kết quả.

**Tiêu chí hoàn thành:**
- [ ] Member không có gói hoạt động không gửi được yêu cầu.
- [ ] Chỉ tạo được một yêu cầu chờ.
- [ ] Hiển thị lý do từ chối và quan hệ đang hoạt động.

**Kiểm tra:** Test luồng gửi, gửi trùng, hủy và xem kết quả.

**Phụ thuộc:** T10.
**File dự kiến:** `mobile-app/lib/features/coaching/`, `mobile-app/test/features/coaching/`.
**Quy mô:** M.

### T12 — Giáo trình, dinh dưỡng và lịch tập của Member

**Mô tả:** Hiển thị giáo trình đã công bố, hướng dẫn dinh dưỡng và lịch buổi tập.

**Tiêu chí hoàn thành:**
- [ ] Member chỉ xem nội dung được phép và bản đã công bố.
- [ ] Lịch phân biệt đúng trạng thái buổi tập.
- [ ] Có lịch sử giáo trình/dinh dưỡng theo contract.

**Kiểm tra:** Widget test và kiểm tra bằng tài khoản có/không có Coach.

**Phụ thuộc:** T11.
**File dự kiến:** `mobile-app/lib/features/training/`, `mobile-app/lib/features/nutrition/`, `mobile-app/lib/features/sessions/`.
**Quy mô:** M.

### T13 — Nhật ký tập luyện và ăn uống

**Mô tả:** Cho Member tạo, sửa và phân trang nhật ký tập/ăn uống.

**Tiêu chí hoàn thành:**
- [ ] Form validate dữ liệu và ngày hợp lệ.
- [ ] Danh sách phân trang không lặp/mất item.
- [ ] Người dùng chỉ sửa dữ liệu của mình.

**Kiểm tra:** Widget test create/edit/list và kiểm tra quyền qua API.

**Phụ thuộc:** T09.
**File dự kiến:** `mobile-app/lib/features/logs/`, `mobile-app/test/features/logs/`.
**Quy mô:** M.

### T14 — Số đo, ảnh và biểu đồ tiến bộ

**Mô tả:** Cho Member nhập số đo, tải ảnh, xem lịch sử và biểu đồ theo thời gian.

**Tiêu chí hoàn thành:**
- [ ] Upload ảnh có giới hạn loại/kích thước và trạng thái tiến trình.
- [ ] Biểu đồ dùng đúng đơn vị, ngày và xử lý dữ liệu trống.
- [ ] Ảnh riêng tư chỉ mở bằng URL/quyền hợp lệ.

**Kiểm tra:** Test dữ liệu trống, một điểm, nhiều điểm và upload lỗi/thành công.

**Phụ thuộc:** T13.
**File dự kiến:** `mobile-app/lib/features/progress/`, `mobile-app/test/features/progress/`.
**Quy mô:** M.

### T15 — Tin nhắn Member–Coach

**Mô tả:** Hiển thị hội thoại, phân trang tin nhắn, gửi văn bản/ảnh và đánh dấu đã đọc.

**Tiêu chí hoàn thành:**
- [ ] Chỉ quan hệ hợp lệ được gửi tin.
- [ ] Có trạng thái đang gửi, lỗi và gửi lại mà không tạo trùng.
- [ ] Quan hệ kết thúc chỉ xem lịch sử.

**Kiểm tra:** Test hai tài khoản, pagination, read-state và retry.

**Phụ thuộc:** T11, T14.
**File dự kiến:** `mobile-app/lib/features/messaging/`, `mobile-app/test/features/messaging/`.
**Quy mô:** M.

### T16 — AI Advisor trên Flutter

**Mô tả:** Cho người dùng tạo/đổi tên/xóa cuộc trò chuyện và hỏi đáp AI dạng văn bản.

**Tiêu chí hoàn thành:**
- [ ] Lịch sử chỉ thuộc người dùng hiện tại.
- [ ] UI xử lý timeout, giới hạn và provider chưa cấu hình.
- [ ] Không hiển thị câu trả lời lỗi như câu trả lời thành công.

**Kiểm tra:** Test provider mock thành công, timeout và 503.

**Phụ thuộc:** T09.
**File dự kiến:** `mobile-app/lib/features/ai_advisor/`, `mobile-app/test/features/ai_advisor/`.
**Quy mô:** M.

### Checkpoint C — Member MVP

- [ ] Member đăng ký → mua gói → chọn Coach → xem nội dung → ghi tiến độ được.
- [ ] Tin nhắn và AI lỗi độc lập, không làm app sập.
- [ ] `flutter analyze`, `flutter test`, backend test đều thành công.

---

## Giai đoạn 3 — Luồng Coach

### T17 — Trang chủ Coach và danh sách Member

**Mô tả:** Tạo shell Coach, thống kê cơ bản, danh sách Member hiện tại và trang chi tiết.

**Tiêu chí hoàn thành:**
- [ ] Coach chỉ thấy Member thuộc quan hệ hợp lệ.
- [ ] Hiển thị rõ suất đang dùng/còn lại.
- [ ] Không lộ dữ liệu của Coach khác.

**Kiểm tra:** Widget test và thử hai Coach với dữ liệu tách biệt.

**Phụ thuộc:** T07.
**File dự kiến:** `mobile-app/lib/features/coach_home/`, `mobile-app/lib/features/coach_members/`.
**Quy mô:** M.

### T18 — Coach xử lý yêu cầu và kết thúc quan hệ

**Mô tả:** Cho Coach chấp nhận/từ chối yêu cầu, xem trạng thái quan hệ và gửi/hủy yêu cầu kết thúc.

**Tiêu chí hoàn thành:**
- [ ] Từ chối/kết thúc bắt buộc có lý do khi contract yêu cầu.
- [ ] Chấp nhận không vượt giới hạn Member.
- [ ] UI làm mới đúng sau thay đổi trạng thái.

**Kiểm tra:** Test chấp nhận, từ chối, quá sức chứa, gửi và hủy yêu cầu kết thúc.

**Phụ thuộc:** T17.
**File dự kiến:** `mobile-app/lib/features/coach_requests/`, `mobile-app/test/features/coach_requests/`.
**Quy mô:** M.

### T19 — Coach quản lý giáo trình và dinh dưỡng

**Mô tả:** Tạo/sửa bản nháp, công bố giáo trình và hướng dẫn dinh dưỡng cho Member.

**Tiêu chí hoàn thành:**
- [ ] Có trình soạn ngày tập và bài tập với validation.
- [ ] Công bố lưu lịch sử và chỉ có một bản hoạt động.
- [ ] Coach cũ/không liên quan bị chặn.

**Kiểm tra:** Test draft → edit → publish và kiểm tra Member nhận đúng bản.

**Phụ thuộc:** T17.
**File dự kiến:** `mobile-app/lib/features/coach_training/`, `mobile-app/lib/features/coach_nutrition/`.
**Quy mô:** M.

### T20 — Coach quản lý buổi tập

**Mô tả:** Cho Coach tạo/sửa lịch và cập nhật trạng thái buổi tập.

**Tiêu chí hoàn thành:**
- [ ] Chỉ cho phép chuyển trạng thái hợp lệ.
- [ ] Các timestamp/lý do kết quả hiển thị đúng.
- [ ] Member thấy lịch cập nhật sau refresh.

**Kiểm tra:** Test các chuyển trạng thái hợp lệ và bị cấm.

**Phụ thuộc:** T17.
**File dự kiến:** `mobile-app/lib/features/coach_sessions/`, `mobile-app/test/features/coach_sessions/`.
**Quy mô:** M.

### T21 — Coach xem tiến độ và nhận xét

**Mô tả:** Cho Coach xem biểu đồ, nhật ký, số đo của Member và gửi nhận xét.

**Tiêu chí hoàn thành:**
- [ ] Chỉ Coach hiện tại truy cập được dữ liệu riêng tư.
- [ ] Nhận xét gắn đúng bản ghi/Member.
- [ ] Coach mất quyền sau khi quan hệ kết thúc.

**Kiểm tra:** Test Coach hiện tại, Coach khác và Coach cũ.

**Phụ thuộc:** T14, T17.
**File dự kiến:** `mobile-app/lib/features/coach_progress/`, `mobile-app/test/features/coach_progress/`.
**Quy mô:** M.

### Checkpoint D — Coach MVP

- [ ] Coach nhận Member, giao kế hoạch, xếp lịch và nhận xét tiến độ được.
- [ ] Member thấy đúng dữ liệu Coach vừa công bố.
- [ ] Ma trận quyền Member/Coach vượt qua test liên quan.

---

## Giai đoạn 4 — Hoàn thiện Admin web

### T22 — Bổ sung quản lý bài tập/nội dung còn thiếu

**Mô tả:** Mở rộng Admin web để quản lý đầy đủ catalog backend hỗ trợ, đặc biệt bài tập và trạng thái ẩn/hiện.

**Tiêu chí hoàn thành:**
- [ ] Admin tạo/sửa/ẩn bài tập được.
- [ ] Form có validation và xác nhận hành động ảnh hưởng dữ liệu.
- [ ] Nội dung ẩn biến mất khỏi Flutter sau refresh.

**Kiểm tra:** `npm run build`; kiểm tra CRUD và quyền bằng tài khoản Admin/non-Admin.

**Phụ thuộc:** T09.
**File dự kiến:** `admin-web/src/main.js`, `admin-web/src/style.css`, test mới nếu bổ sung framework.
**Quy mô:** M.

### T23 — Chuẩn hóa loading, lỗi và accessibility Admin

**Mô tả:** Bổ sung trạng thái tải, lỗi mạng, xác nhận thao tác, focus/label và responsive cho các màn hình Admin.

**Tiêu chí hoàn thành:**
- [ ] Không có thao tác bất đồng bộ im lặng hoặc gửi lặp.
- [ ] Có thể dùng bàn phím cho các hành động chính.
- [ ] Màn hình dùng được ở chiều rộng tablet.

**Kiểm tra:** `npm run build`; kiểm tra thủ công bằng bàn phím và responsive mode.

**Phụ thuộc:** T22.
**File dự kiến:** `admin-web/src/main.js`, `admin-web/src/style.css`.
**Quy mô:** M.

---

## Giai đoạn 5 — Dịch vụ bên ngoài

### T24 — Kết nối dịch vụ gửi email thật

**Mô tả:** Chọn một nhà cung cấp email, triển khai endpoint giao nhận phù hợp adapter hiện tại và cấu hình secret phía server.

**Tiêu chí hoàn thành:**
- [ ] Email mã khôi phục đến được hộp thư thử nghiệm.
- [ ] Không tiết lộ email tồn tại hay không.
- [ ] Có timeout, retry có giới hạn và log không chứa mã/mật khẩu.

**Kiểm tra:** Gửi email thử nghiệm và hoàn tất đổi mật khẩu từ Flutter.

**Phụ thuộc:** T08.
**File dự kiến:** cấu hình triển khai dịch vụ email, `README.md`, tài liệu vận hành.
**Quy mô:** M.

### T25 — Kết nối OpenAI production

**Mô tả:** Cấu hình model, secret, timeout và giới hạn an toàn cho AI responder hiện có.

**Tiêu chí hoàn thành:**
- [ ] Backend nhận được câu trả lời thật qua Responses API.
- [ ] Khóa chỉ tồn tại ở secret store của backend.
- [ ] 429/timeout/lỗi provider trả thông báo an toàn cho Flutter.

**Kiểm tra:** Chạy một hội thoại thử, kiểm tra lỗi khóa sai và timeout.

**Phụ thuộc:** T16.
**File dự kiến:** cấu hình cloud, `README.md`, tài liệu vận hành.
**Quy mô:** S.

### T26 — Chuyển lưu trữ ảnh sang object storage

**Mô tả:** Thêm provider lưu ảnh production tương thích API media hiện tại, giữ local storage cho development.

**Tiêu chí hoàn thành:**
- [ ] Ảnh không phụ thuộc filesystem tạm của server cloud.
- [ ] Quyền truy cập và thời hạn URL tuân theo dữ liệu riêng tư.
- [ ] Xóa/rollback lỗi không để rác ngoài ý muốn.

**Kiểm tra:** Upload, mở ảnh có quyền, từ chối người không quyền và restart server vẫn còn ảnh.

**Phụ thuộc:** T14.
**File dự kiến:** `backend/src/storage/`, `backend/test/media.postgres.test.js`, `.env.example`.
**Quy mô:** M.

### T27 — Tích hợp RTC và màn hình gọi

**Mô tả:** Chọn provider RTC, nối token service với backend và thêm màn hình gọi thoại/video trên Flutter.

**Tiêu chí hoàn thành:**
- [ ] Hai thiết bị trong quan hệ hoạt động gọi được.
- [ ] Người không thuộc quan hệ không lấy/join token được.
- [ ] Lịch sử lưu loại, trạng thái, thời lượng; không lưu nội dung.

**Kiểm tra:** Thử hai thiết bị thật cho gọi thành công, từ chối, mất mạng và kết thúc.

**Phụ thuộc:** T15.
**File dự kiến:** `mobile-app/lib/features/calls/`, `backend/src/config/providers.js`, tài liệu RTC.
**Quy mô:** M.

### Checkpoint E — Tích hợp thật

- [ ] Email, AI, ảnh và RTC dùng secret phía server.
- [ ] Từng dịch vụ lỗi độc lập không làm app/backend sập.
- [ ] Không có khóa bí mật trong Git hoặc Flutter bundle.

---

## Giai đoạn 6 — Cloud và CI

### T28 — Đóng gói backend để triển khai

**Mô tả:** Tạo cấu hình chạy production có healthcheck, user không đặc quyền và quy trình migration rõ ràng.

**Tiêu chí hoàn thành:**
- [ ] Backend khởi động bằng một lệnh trong môi trường sạch.
- [ ] Healthcheck phân biệt ứng dụng chạy và database sẵn sàng.
- [ ] Image/config không chứa secret.

**Kiểm tra:** Build và chạy container/config local; gọi `/api/v1/health`.

**Phụ thuộc:** T03.
**File dự kiến:** `backend/Dockerfile`, `.dockerignore`, tài liệu triển khai.
**Quy mô:** S.

### T29 — Tạo PostgreSQL cloud và chạy migration

**Mô tả:** Tạo database production/staging, cấu hình SSL/backup và chạy migration bằng tài khoản phù hợp.

**Tiêu chí hoàn thành:**
- [ ] Có database staging và thông tin kết nối trong secret store.
- [ ] Migration + baseline seed chạy thành công.
- [ ] Có cách backup và khôi phục đã thử ít nhất một lần.

**Kiểm tra:** Chạy schema assertions và phục hồi một bản backup thử nghiệm.

**Phụ thuộc:** T28.
**File dự kiến:** tài liệu triển khai/database; không commit credentials.
**Quy mô:** M.

### T30 — Triển khai backend và Admin web

**Mô tả:** Đưa backend và Admin web lên cloud, cấu hình HTTPS, API URL, CORS và biến môi trường.

**Tiêu chí hoàn thành:**
- [ ] Có URL HTTPS cho API và Admin.
- [ ] Admin đăng nhập và thực hiện nghiệp vụ trên database staging.
- [ ] CORS chỉ cho phép origin dự kiến ở production.

**Kiểm tra:** Chạy T03 trên URL cloud và smoke test Admin.

**Phụ thuộc:** T23, T29.
**File dự kiến:** cấu hình nền tảng cloud, `admin-web/.env.example`, tài liệu triển khai.
**Quy mô:** M.

### T31 — Cấu hình Flutter dùng backend cloud

**Mô tả:** Tạo flavor/build config staging và production, trỏ app tới URL HTTPS phù hợp.

**Tiêu chí hoàn thành:**
- [ ] Không hard-code URL local trong bản release.
- [ ] Bản staging và production phân biệt được cấu hình.
- [ ] Android thiết bị thật đăng nhập được vào cloud.

**Kiểm tra:** Build APK staging, cài lên điện thoại và hoàn thành đăng nhập + một API nghiệp vụ.

**Phụ thuộc:** T30.
**File dự kiến:** `mobile-app/lib/core/config/`, cấu hình Android/build.
**Quy mô:** M.

### T32 — Thiết lập CI kiểm tra tự động

**Mô tả:** Tạo pipeline chạy backend check/test, Admin build và Flutter analyze/test cho pull request.

**Tiêu chí hoàn thành:**
- [ ] PR lỗi test/build bị báo thất bại.
- [ ] Cache dependency hợp lý nhưng không cache secret.
- [ ] Pipeline không triển khai production nếu chưa được phép.

**Kiểm tra:** Mở PR thử thành công và một commit thử cố ý làm test lỗi rồi hoàn nguyên.

**Phụ thuộc:** T28.
**File dự kiến:** `.github/workflows/ci.yml` hoặc cấu hình CI tương đương.
**Quy mô:** M.

### Checkpoint F — Cloud

- [ ] API, Admin và database staging hoạt động qua HTTPS.
- [ ] APK staging kết nối được từ mạng ngoài.
- [ ] CI xanh trên `main` và không lộ secret trong log.

---

## Giai đoạn 7 — Kiểm thử, ổn định và demo

### T33 — Kiểm thử end-to-end ba vai trò

**Mô tả:** Tự động hóa hoặc ghi kịch bản lặp lại cho Member, Coach và Admin trên staging.

**Tiêu chí hoàn thành:**
- [ ] Luồng Member mua gói và chọn Coach hoàn chỉnh.
- [ ] Coach nhận Member, giao kế hoạch và nhận xét hoàn chỉnh.
- [ ] Admin quản lý tài khoản, thanh toán và chuyển Coach hoàn chỉnh.

**Kiểm tra:** Chạy toàn bộ kịch bản từ database demo sạch và lưu kết quả.

**Phụ thuộc:** T27, T31.
**File dự kiến:** `docs/testing/`, test E2E phù hợp.
**Quy mô:** M.

### T34 — Kiểm thử bảo mật và vòng đời dữ liệu

**Mô tả:** Kiểm tra ma trận quyền, IDOR, trạng thái tài khoản, hết hạn membership, chuyển/kết thúc Coach và dữ liệu lịch sử.

**Tiêu chí hoàn thành:**
- [ ] Không truy cập chéo dữ liệu bằng cách đổi ID.
- [ ] Khóa tài khoản/hết hạn quan hệ thu hồi đúng quyền.
- [ ] Lịch sử cần giữ không bị mất sau chuyển trạng thái.

**Kiểm tra:** Backend test cho từng trường hợp và review không còn lỗi nghiêm trọng/cao.

**Phụ thuộc:** T33.
**File dự kiến:** `backend/test/`, `docs/testing/security-matrix.md`.
**Quy mô:** M.

### T35 — Hoàn thiện APK và kịch bản demo dự phòng

**Mô tả:** Tạo APK release/staging ổn định, ba tài khoản demo và kịch bản dự phòng khi mạng/dịch vụ ngoài lỗi.

**Tiêu chí hoàn thành:**
- [ ] APK cài được trên ít nhất hai điện thoại mục tiêu.
- [ ] Có dữ liệu reset được trước buổi demo.
- [ ] Có video/ảnh/kịch bản dự phòng cho email, AI hoặc RTC.

**Kiểm tra:** Diễn tập toàn bộ demo theo thời gian dự kiến hai lần.

**Phụ thuộc:** T33, T34.
**File dự kiến:** `docs/demo/`, artifact APK ngoài Git nếu dung lượng lớn.
**Quy mô:** M.

### T36 — Đồng bộ tài liệu, báo cáo và slide

**Mô tả:** Cập nhật README, sơ đồ, API, hướng dẫn cài đặt và nội dung báo cáo/slide theo hệ thống đã chạy thật.

**Tiêu chí hoàn thành:**
- [ ] Một thành viên mới dựng được dự án từ hướng dẫn.
- [ ] Sơ đồ/database/API trong báo cáo khớp code production.
- [ ] Slide và kịch bản không tuyên bố tính năng chưa hoàn thành.

**Kiểm tra:** Người khác làm dry-run cài đặt; review chéo code ↔ tài liệu ↔ slide.

**Phụ thuộc:** T35.
**File dự kiến:** `README.md`, `docs/`, báo cáo và slide của đồ án.
**Quy mô:** M.

### Checkpoint cuối — Sẵn sàng bảo vệ

- [ ] Backend test/check thành công.
- [ ] Admin web build thành công.
- [ ] Flutter analyze/test và APK release thành công.
- [ ] Không còn lỗi nghiêm trọng hoặc cao.
- [ ] Ba luồng vai trò chạy end-to-end trên cloud.
- [ ] Demo đã diễn tập và có phương án dự phòng.

---

## Phân công gợi ý cho nhóm 3 người

| Thành viên | Trọng tâm | Task chính |
|---|---|---|
| Thành viên 1 | Flutter Member | T04–T16, phối hợp T31 |
| Thành viên 2 | Flutter Coach và Admin | T17–T23, phối hợp T27 |
| Thành viên 3 | Backend, dịch vụ, cloud, QA | T01–T03, T24–T36 |

Các task dùng chung API contract phải chốt kiểu dữ liệu/response trước khi làm song song. Tất cả thành viên cùng review tại mỗi checkpoint.

## Thứ tự ưu tiên nếu thiếu thời gian

1. Bắt buộc: T01–T15, T17–T21, T28–T35.
2. Nên có: T16, T22–T27, T36.
3. Nếu provider thật gây rủi ro: giữ adapter hiện có, trình bày rõ chế độ 503 và dùng video demo dự phòng; không nhúng token giả hoặc secret vào Flutter.
