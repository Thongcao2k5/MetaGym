# Bàn giao agent kiểm thử — Task 23 UI E2E

Trạng thái 24/10/2026: nhánh `codex/t23-qa-plan`, HEAD gốc bàn giao
`a78d978`. T23-A/B đã đạt; backend PostgreSQL 54/54 test (0 skip), Flutter
138/138 test, analyze và APK debug đạt, Admin build đạt. T23-C/D **chưa đạt**
vì còn thiếu thao tác UI liên thông. Đọc `tasks/plan.md`, mục Task 23 và
`tasks/todo.md`, mục T23-C/D/E trước khi bắt đầu. Nếu HEAD đã thay đổi, ghi
commit thực tế trong báo cáo.

## Quy tắc chung

- Chỉ kiểm thử trên PostgreSQL và các port riêng. Không reset/sửa database demo
  đang phục vụ trên `55432`, không dừng backend demo `3010` hoặc Flutter demo
  `8086`. Cluster test tạm từng dùng `55433` đã dừng; không phụ thuộc vào nó.
- Tạo database test trống, chạy bảy migration và demo seed theo
  `database/README.md`; kiểm tra `GET /api/v1/health` trả API/database
  `AVAILABLE`. Chỉ dùng thanh toán mô phỏng `MOCK_QR`, không giao dịch thật.
- Dùng ít nhất hai phiên trình duyệt tách cookie/storage cho Member và Coach;
  Admin ở phiên riêng. Ghi ảnh màn hình, console và network lỗi, request ID
  hoặc UUID liên quan, kết quả đối chiếu API/DB. Không ghi mật khẩu, token,
  connection string vào Git hoặc báo cáo.
- Không sửa code khi chỉ được giao kiểm thử. Nếu phát hiện lỗi, ghi bước tái
  hiện, mong đợi/thực tế, ảnh/log đã che secret và mức độ ưu tiên; báo người
  giao task trước khi mở phạm vi sửa. Không push/merge.
- Chỉ đánh dấu ô hoàn tất khi đã có bằng chứng UI thật; test API/widget đạt
  không thay thế thao tác tay. Nếu công cụ điều khiển trình duyệt bị chặn,
  báo rõ bước dừng; không ghi giả là pass.

## Các lượt giao việc (thực hiện tuần tự)

### T23-UI-1 — Môi trường riêng (S)

Đầu vào: repo nhánh Task 23, PostgreSQL và Flutter/Node/Vite theo README.
Chạy migration/seed trên database test riêng, backend cổng riêng, Admin Web và
Flutter Web trỏ vào API đó; đăng nhập được ba vai trò. Ghi HEAD, cổng,
database **chỉ bằng tên**, kết quả health, và xác nhận demo stack không đổi.
Không tiếp tục lượt 2 nếu health/database hoặc đăng nhập lỗi.

### T23-UI-2 — Admin → gói → Member (M; sau UI-1)

Admin tạo Coach và gói mới có tên nhận diện riêng; Member thấy đúng gói,
thực hiện mua và xác nhận `MOCK_QR` qua UI; Admin thấy payment/membership,
dashboard và các danh sách phù hợp. Đối chiếu cùng plan/member/payment ID ở
API/DB. Thử Member và Coach mở route/API Admin, phải bị chặn. Không dùng gói
demo cũ để suy ra luồng tạo mới đã hoạt động.

### T23-UI-3 — Member → Coach → giáo trình (M; sau UI-2)

Trên Member có membership hiệu lực ở UI-2, gửi yêu cầu Coach; Coach vừa tạo
nhận/duyệt yêu cầu, tạo và công bố giáo trình; Member đọc đúng giáo trình và
phiên bản hiện hành. Đối chiếu cùng request/relationship/plan ID qua API/DB;
kiểm tra sai vai trò không sửa/công bố hoặc đọc dữ liệu người khác. Lưu trạng
thái trước/sau và console/network cả hai phiên.

### T23-UI-4 — Hết hạn, tạm ngưng, đổi Coach (M; sau UI-3)

Trên dữ liệu **test riêng**, tạo tình huống hết hạn/tạm ngưng theo contract
(nếu cần chỉnh thời gian bằng SQL, ghi chính xác câu lệnh và chỉ áp dụng lên
fixture test). Xác nhận UI Member/Coach không tạo nội dung mới khi quan hệ bị
khóa, Member vẫn đọc được lịch sử. Sau khi đổi/kết thúc quan hệ, Coach cũ mất
quyền đọc/ghi dữ liệu riêng, Coach mới chỉ có quyền hợp lệ; lịch sử Member
không mất. Đối chiếu HTTP status và row ID. Không suy diễn từ test backend.

### T23-UI-5 — Khóa/mở tài khoản (S; sau UI-3)

Giữ phiên/token Member trước khi Admin khóa tài khoản. Khóa qua UI Admin;
phiên Member cũ không được gọi hồ sơ, nhật ký, tiến độ hay thanh toán; người
khác không đọc được dữ liệu riêng. Mở khóa và xác nhận token cũ vẫn vô hiệu,
đăng nhập mới theo contract. Ghi status API, màn hình tương ứng và audit/ID.

### T23-UI-6 — Tổng hợp và hồi quy (S; sau UI-2 đến UI-5)

Lập bảng mỗi case: pass/fail/blocked, bằng chứng, ID test, commit. Tách lỗi
thành task sửa cụ thể và chạy lại case liên quan sau sửa. Chạy các bộ test/build
đã nêu ở `tasks/todo.md` sau **mọi thay đổi mã**; không lặp vô ích khi không
có thay đổi. Cập nhật checklist T23-C/D/E đúng bằng chứng, dừng dịch vụ/DB
test của mình mà không ảnh hưởng demo, báo còn gì chặn merge. Không tự push
hoặc merge.

## Prompt giao cho agent mới

> Kiểm thử Task 23 UI E2E của Meta Gym. Làm tuần tự T23-UI-1 đến T23-UI-6
> theo `tasks/t23-ui-test-handoff.md` trên nhánh `codex/t23-qa-plan`; đọc
> `tasks/plan.md` và `tasks/todo.md` phần T23 trước. Dùng database/port riêng,
> không động vào stack demo, không push/merge. Mỗi lượt xong báo pass/fail/
> blocked cùng bằng chứng UI + API/DB và chỉ đánh dấu checklist khi thực sự
> đạt. Nếu lỗi, ghi cách tái hiện và dừng ở điểm phụ thuộc, không tự nhận đã
> hoàn thành từ test tự động. Bắt đầu ngay từ T23-UI-1.
