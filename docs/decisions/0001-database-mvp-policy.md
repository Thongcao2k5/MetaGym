# ADR-001: Chuẩn hóa chính sách database cho MVP Meta Gym

## Trạng thái

Accepted.

## Ngày

2026-10-21

## Bối cảnh

Meta Gym được thực hiện bởi ba sinh viên trong hai tháng và chỉ phục vụ một phòng gym. Database spec đã có 33 bảng nhưng các review D1–D19 bổ sung những yêu cầu chưa được biểu diễn đầy đủ: chống race condition, lịch sử bất biến, vô hiệu phiên đăng nhập, vòng đời media, audit và AI idempotency.

Mục tiêu là làm schema đủ chặt để tạo migration mà không mở rộng sang multi-gym, đa tiền tệ, message queue hoặc thêm bảng điều phối không cần thiết.

## Quyết định

- Giữ 33 bảng hiện tại.
- Múi giờ nghiệp vụ là `Asia/Ho_Chi_Minh`; timestamp lưu bằng `timestamptz`, membership dùng ngày lịch Việt Nam.
- Tiền chỉ dùng VND và lưu số đồng nguyên bằng `bigint`.
- Tài khoản khóa bằng `users.status = 'DISABLED'`; `session_version` vô hiệu JWT cũ sau khóa hoặc đặt lại mật khẩu.
- Đặt lại mật khẩu tiếp tục dùng mã email một lần, không đổi sang liên kết token.
- Payment chỉ chuyển một chiều khỏi `PENDING`. Member sở hữu giao dịch `MOCK_QR` tự xác nhận thanh toán mô phỏng thành công và hệ thống tự kích hoạt/xếp nối membership, không cần Admin duyệt; giao dịch `FRONT_DESK` do Admin ghi nhận. Xác nhận payment và tạo membership nằm trong cùng transaction.
- Membership không `CANCELLED` của cùng Member không được chồng ngày hiệu lực.
- Quan hệ `ACTIVE` và `PAUSED` đều chiếm suất Coach; quan hệ `ENDED` không tái kích hoạt.
- Giáo trình và hướng dẫn dinh dưỡng đã công bố là bất biến; sửa đổi tạo phiên bản mới.
- Media dùng upload hai giai đoạn và state machine `UPLOADING/READY/FAILED/DELETED`, kèm cleanup idempotent.
- `gym_profile` là singleton `id = 1`.
- Audit Admin dùng bảng hiện có, append-only; khóa đối tượng lưu dạng `text` để hỗ trợ cả UUID và khóa số.
- AI idempotency được bổ sung vào `ai_messages`; không thêm bảng `ai_requests`.
- Baseline seed là lệnh độc lập. Nếu bổ sung demo seed ở giai đoạn phát triển sau này, nó phải là lệnh riêng và không được tự chạy trong production.

## Phương án đã loại

### Thêm bảng `ai_requests`

Mô hình rõ hơn nhưng làm tăng số bảng và khối lượng triển khai. Các field request, trạng thái và liên kết phản hồi có thể nằm trong `ai_messages` với CHECK/UNIQUE phù hợp.

### Đa tiền tệ hoặc multi-gym

Không thuộc phạm vi một phòng gym; làm tăng cột, FK, JOIN và nhánh nghiệp vụ không phục vụ đồ án.

### Chỉ kiểm tra toàn vẹn trong Node.js

Không đủ bảo vệ trước request đồng thời hoặc lỗi triển khai. Các bất biến cốt lõi phải dùng transaction, UNIQUE, CHECK, composite FK hoặc exclusion constraint trong PostgreSQL.

### Tự động retry AI sau timeout

Có thể làm provider xử lý và tính phí hai lần. Yêu cầu timeout chuyển `FAILED`; người dùng thử lại bằng `client_request_id` mới.

## Hệ quả

- Migration cần extension `citext` và `btree_gist`.
- Backend phải kiểm tra `status` và `session_version` trên mọi API xác thực.
- Một số bảng có thêm field và CHECK; API contract phải được đồng bộ trước khi viết code.
- Media cleanup và AI timeout cần tác vụ nền đơn giản, idempotent.
- Dữ liệu demo phải tách khỏi baseline seed.

## Điều kiện chấp nhận

- Database spec, API contract, confirmed workflows và task list không còn mâu thuẫn về trạng thái, quyền hoặc seed.
- Có thể biểu diễn D1–D19 bằng đúng 33 bảng.
- Mọi transaction nhiều bước và constraint chống trùng/race được ghi rõ trước khi tạo migration.
