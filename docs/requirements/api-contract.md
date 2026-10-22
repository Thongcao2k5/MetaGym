# Meta Gym — Danh sách API REST cho MVP

> Cập nhật: 20/10/2026  
> Trạng thái: Bản thiết kế để duyệt trước khi lập trình.  
> Phạm vi: Một phòng gym, Flutter cho Member/Coach, web cho Admin.

## 1. Quy ước chung

- Base URL: `/api/v1`.
- API cần đăng nhập dùng `Authorization: Bearer <accessToken>`.
- Vai trò: `MEMBER`, `COACH`, `ADMIN`.
- Tất cả danh sách dùng phân trang: `page`, `pageSize`, `sortBy`, `sortOrder`.
- Bộ lọc dùng query string dạng camelCase, ví dụ `?status=ACTIVE&search=an`.
- Dữ liệu trả về dùng camelCase; giá trị enum dùng `UPPER_SNAKE_CASE`.
- `PATCH` chỉ cập nhật những trường được gửi lên.
- Các API tạo thanh toán phải nhận header `Idempotency-Key` để gửi lại không tạo giao dịch trùng.
- Backend luôn kiểm tra quyền sở hữu và quan hệ Coach–Member; không chỉ dựa vào việc ẩn nút ở giao diện.

Phản hồi thành công cho một đối tượng:

```json
{ "data": {} }
```

Phản hồi thành công cho danh sách:

```json
{
  "data": [],
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "totalItems": 0,
    "totalPages": 0
  }
}
```

Phản hồi lỗi thống nhất:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Dữ liệu không hợp lệ",
    "details": {}
  }
}
```

## 2. System

| Method | Endpoint | Quyền | Mục đích |
| --- | --- | --- | --- |
| `GET` | `/health` | Public | Kiểm tra backend và database có hoạt động |

## 3. Identity & Access

| Method | Endpoint | Quyền | Mục đích |
| --- | --- | --- | --- |
| `POST` | `/auth/registrations` | Public | Đăng ký tài khoản Member |
| `POST` | `/auth/sessions` | Public | Đăng nhập chung cho ba vai trò |
| `GET` | `/users/me` | Đã đăng nhập | Khôi phục phiên và lấy hồ sơ hiện tại |
| `PATCH` | `/users/me` | Đã đăng nhập | Cập nhật hồ sơ cá nhân |
| `PATCH` | `/users/me/password` | Đã đăng nhập | Đổi mật khẩu |
| `POST` | `/password-reset-requests` | Public | Gửi mã đặt lại mật khẩu qua email |
| `POST` | `/password-reset-verifications` | Public | Kiểm tra mã đặt lại mật khẩu |
| `POST` | `/password-resets` | Public | Đặt mật khẩu mới sau khi xác minh |
| `GET` | `/admin/users` | Admin | Danh sách Member/Coach; lọc theo vai trò, trạng thái, từ khóa |
| `GET` | `/admin/users/:userId` | Admin | Chi tiết một tài khoản |
| `POST` | `/admin/coaches` | Admin | Tạo tài khoản Coach |
| `PATCH` | `/admin/users/:userId` | Admin | Sửa thông tin tài khoản hoặc giới hạn Member của Coach |
| `PATCH` | `/admin/users/:userId/status` | Admin | Khóa hoặc mở lại tài khoản |
| `POST` | `/admin/coaches/:coachId/password-resets` | Admin | Đặt mật khẩu tạm thời cho Coach |

### 3.1. Đăng ký Member

`POST /auth/registrations` chỉ nhận đúng ba trường:

```json
{
  "fullName": "Nguyen Van A",
  "email": "member@example.com",
  "password": "StrongPass1"
}
```

- `fullName` được bỏ khoảng trắng hai đầu, dài từ 2 đến 120 ký tự.
- `email` được bỏ khoảng trắng hai đầu, chuyển thành chữ thường và phải đúng định dạng email.
- `password` dài từ 8 đến 72 byte, có ít nhất một chữ hoa, một chữ thường và một chữ số.
- Request là strict: client không được truyền `role` hoặc trường ngoài contract. Backend luôn tạo `role = MEMBER`, `status = ACTIVE` và một `member_profiles` rỗng trong cùng thao tác nguyên tử.

Thành công trả `201` và không bao giờ trả password/hash:

```json
{
  "data": {
    "id": "00000000-0000-4000-8000-000000000000",
    "email": "member@example.com",
    "fullName": "Nguyen Van A",
    "role": "MEMBER",
    "status": "ACTIVE",
    "createdAt": "2026-10-21T08:00:00.000Z"
  }
}
```

Input không hợp lệ trả `422 VALIDATION_ERROR`; email đã tồn tại trả `409 EMAIL_ALREADY_EXISTS`.

### 3.2. Đăng nhập

`POST /auth/sessions` dùng chung cho Member, Coach và Admin:

```json
{
  "email": "member@example.com",
  "password": "StrongPass1"
}
```

- Request là strict, email được bỏ khoảng trắng hai đầu và chuyển thành chữ thường.
- Sai email và sai mật khẩu đều trả cùng lỗi `401 INVALID_CREDENTIALS`.
- Tài khoản có mật khẩu đúng nhưng `status = DISABLED` trả `403 ACCOUNT_DISABLED`.
- Đăng nhập thành công cập nhật `last_login_at` và trả access token JWT sống 3.600 giây.
- JWT dùng `HS256`, có `issuer = meta-gym-api`, `audience = meta-gym-clients`; payload nghiệp vụ gồm `sub`, `role` và `sessionVersion`.
- Backend chỉ phát token nếu tài khoản vẫn `ACTIVE` và `session_version` không đổi tại thời điểm cập nhật lần đăng nhập cuối.
- Năm lần đăng nhập sai trong 15 phút theo tài khoản hoặc IP sẽ khóa bucket tương ứng trong 15 phút; trạng thái được lưu trong PostgreSQL để dùng chung giữa nhiều instance. API trả `429 TOO_MANY_REQUESTS` khi bị giới hạn.
- Backend từ chối khởi động nếu `JWT_SECRET` thiếu, ngắn hơn 32 byte, là placeholder trong `.env.example` hoặc có độ đa dạng ký tự quá thấp.

```json
{
  "data": {
    "accessToken": "<jwt>",
    "tokenType": "Bearer",
    "expiresIn": 3600,
    "user": {
      "id": "00000000-0000-4000-8000-000000000000",
      "email": "member@example.com",
      "fullName": "Nguyen Van A",
      "role": "MEMBER",
      "status": "ACTIVE"
    }
  }
}
```

Ghi chú: đăng xuất trong MVP chỉ xóa access token ở ứng dụng. Không cần API đăng xuất khi chưa xây refresh token hoặc danh sách thu hồi token.

### 3.3. Phiên hiện tại và hồ sơ

`GET /users/me`, `PATCH /users/me` và `PATCH /users/me/password` yêu cầu
`Authorization: Bearer <accessToken>`. Mỗi request kiểm tra chữ ký HS256,
`issuer`, `audience`, thời hạn token, vai trò, trạng thái tài khoản và
`sessionVersion` hiện tại trong PostgreSQL. Token cũ hoặc tài khoản bị khóa trả
`401 UNAUTHORIZED`.

`GET /users/me` trả `data` gồm `id`, `email`, `fullName`, `phone`, `role`,
`status` và `profile` cho Member/Coach. `profile` chỉ chứa trường thuộc vai trò
của chính người gọi; mật khẩu, hash, ghi chú nội bộ và phiên bản token không
được trả về.

`PATCH /users/me` chỉ nhận các trường cần sửa, với JSON object không rỗng:

- Mọi vai trò: `fullName` (2–120 ký tự sau khi trim), `phone` (tối đa 20 ký tự hoặc `null`).
- Member: `dateOfBirth`, `gender`, `heightCm`, `fitnessGoal`, `experienceLevel`,
  `activityLevel`, `healthNotes`, `injuryNotes`, `dietaryPreferences`.
- Coach: `biography`, `specialties`, `qualifications`, `experienceYears`,
  `availabilityNote`. Giới hạn Member của Coach do Admin quản lý, không sửa ở đây.

Các trường khác, gồm `role`, `status`, `email`, trả `422 VALIDATION_ERROR`.
Cập nhật bảng tài khoản và hồ sơ tương ứng trong cùng transaction rồi trả hồ sơ
mới. Member chỉ sửa hồ sơ của mình; Coach chỉ sửa hồ sơ của mình.

`PATCH /users/me/password` nhận đúng `currentPassword` và `newPassword`.
Mật khẩu mới theo quy tắc đăng ký: 8–72 byte, có chữ hoa, chữ thường và chữ số.
Sai mật khẩu hiện tại trả `401 INVALID_CREDENTIALS`. Khi thành công, backend
khóa dòng tài khoản, lưu bcrypt hash mới và tăng `session_version` trong cùng
transaction, trả `{ "data": { "changed": true } }`. Tất cả token cũ hết hiệu
lực và ứng dụng phải đăng nhập lại.

## 4. Membership & Payment

### 4.1. Gói tập

| Method | Endpoint | Quyền | Mục đích |
| --- | --- | --- | --- |
| `GET` | `/membership-plans` | Public | Danh sách gói đang mở bán |
| `GET` | `/membership-plans/:planId` | Public | Chi tiết gói tập |
| `GET` | `/memberships/me` | Member | Gói hiện tại và gói đang chờ kích hoạt |
| `GET` | `/memberships/me/history` | Member | Lịch sử gói tập |
| `GET` | `/admin/memberships` | Admin | Danh sách gói của tất cả Member |
| `GET` | `/admin/membership-plans` | Admin | Danh sách tất cả gói, kể cả gói đã ngừng bán |
| `GET` | `/admin/members/:memberId/memberships` | Admin | Lịch sử gói của một Member |
| `POST` | `/admin/membership-plans` | Admin | Tạo gói tập |
| `PATCH` | `/admin/membership-plans/:planId` | Admin | Sửa hoặc ngừng bán gói tập |

### 4.2. Thanh toán mô phỏng

| Method | Endpoint | Quyền | Mục đích |
| --- | --- | --- | --- |
| `POST` | `/payments` | Member | Tạo giao dịch QR mô phỏng; bắt buộc `Idempotency-Key` |
| `POST` | `/payments/:paymentId/mock-confirmations` | Chủ giao dịch | Mô phỏng thanh toán thành công; backend tự xác nhận và kích hoạt/xếp nối gói, không cần Admin duyệt |
| `GET` | `/payments/me` | Member | Lịch sử giao dịch của chính mình |
| `GET` | `/payments/:paymentId` | Chủ giao dịch/Admin | Chi tiết giao dịch |
| `GET` | `/admin/payments` | Admin | Danh sách và lọc tất cả giao dịch |
| `POST` | `/admin/front-desk-payments` | Admin | Ghi nhận mua/gia hạn tại quầy; bắt buộc `Idempotency-Key` |
| `PATCH` | `/admin/payments/:paymentId` | Admin | Đánh dấu giao dịch chờ là thất bại hoặc hủy |

Quy tắc xác nhận `MOCK_QR`:

- Member chỉ được xác nhận giao dịch do chính mình tạo và còn `PENDING`.
- Backend dùng conditional update để chỉ một request thắng, sau đó tạo membership trong cùng transaction.
- Nếu giao dịch đã `SUCCESS`, request lặp trả lại kết quả hiện có; không tạo membership thứ hai.
- Gói đầu tiên có hiệu lực từ ngày hiện tại được kích hoạt ngay. Gói mua thêm được xếp nối tiếp sau chuỗi membership chưa hủy.
- Quan hệ Coach chỉ tự chuyển từ `PAUSED` về `ACTIVE` khi có membership thực sự có hiệu lực trong ngày hiện tại và `pause_reason = MEMBERSHIP_EXPIRED`.
- Admin không duyệt giao dịch `MOCK_QR`; Admin chỉ xem lịch sử hoặc xử lý giao dịch lỗi/hủy. Thanh toán tại quầy tiếp tục do Admin ghi nhận.

## 5. Coaching Relationship

### 5.1. Tìm và yêu cầu Coach

| Method | Endpoint | Quyền | Mục đích |
| --- | --- | --- | --- |
| `GET` | `/coaches` | Đã đăng nhập | Danh sách Coach và số suất còn lại |
| `GET` | `/coaches/:coachId` | Đã đăng nhập | Hồ sơ chi tiết Coach |
| `POST` | `/coach-requests` | Member | Gửi yêu cầu chọn một Coach |
| `GET` | `/coach-requests/me` | Member | Xem yêu cầu hiện tại và lịch sử yêu cầu |
| `DELETE` | `/coach-requests/:requestId` | Member | Hủy yêu cầu khi còn `PENDING` |
| `GET` | `/coach/requests` | Coach | Danh sách yêu cầu gửi đến mình |
| `GET` | `/coach/requests/:requestId` | Coach | Chi tiết yêu cầu |
| `PATCH` | `/coach/requests/:requestId` | Coach | Chấp nhận hoặc từ chối; kiểm tra gói tập và giới hạn suất |

### 5.2. Quan hệ đang phụ trách

| Method | Endpoint | Quyền | Mục đích |
| --- | --- | --- | --- |
| `GET` | `/relationships/me` | Member | Coach hiện tại và trạng thái quan hệ |
| `GET` | `/relationships/me/history` | Member | Lịch sử Coach đã từng phụ trách |
| `POST` | `/relationships/:relationshipId/terminations` | Member | Member kết thúc quan hệ trực tiếp |
| `GET` | `/coach/members` | Coach | Danh sách Member đang được phụ trách |
| `GET` | `/coach/members/:memberId` | Coach | Hồ sơ Member thuộc quyền phụ trách |
| `POST` | `/coach/termination-requests` | Coach | Xin Admin cho ngừng phụ trách Member |
| `GET` | `/coach/termination-requests` | Coach | Theo dõi yêu cầu của mình |
| `GET` | `/admin/relationships` | Admin | Danh sách quan hệ và lịch sử |
| `GET` | `/admin/relationships/:relationshipId` | Admin | Chi tiết quan hệ |
| `GET` | `/admin/termination-requests` | Admin | Danh sách yêu cầu ngừng phụ trách |
| `PATCH` | `/admin/termination-requests/:requestId` | Admin | Duyệt hoặc từ chối yêu cầu |
| `POST` | `/admin/coach-transfers` | Admin | Chuyển Coach khi có sự cố và lưu lý do |

## 6. Training & Nutrition

### 6.1. Giáo trình tập luyện

| Method | Endpoint | Quyền | Mục đích |
| --- | --- | --- | --- |
| `GET` | `/training-plans/me/active` | Member | Giáo trình đang áp dụng |
| `GET` | `/training-plans/me/history` | Member | Lịch sử giáo trình đã công bố |
| `GET` | `/training-plans/:planId` | Member liên quan/Coach liên quan | Chi tiết ngày tập và bài tập |
| `GET` | `/coach/members/:memberId/training-plans` | Coach | Danh sách giáo trình của Member |
| `POST` | `/coach/members/:memberId/training-plans` | Coach | Tạo giáo trình nháp |
| `PATCH` | `/coach/training-plans/:planId` | Coach | Sửa nội dung hoặc trạng thái giáo trình |
| `POST` | `/coach/training-plans/:planId/publications` | Coach | Công bố giáo trình và lưu bản cũ |

Mỗi Member chỉ có một giáo trình `ACTIVE`. Nếu hai bản nháp được công bố đồng thời, API xử lý tuần tự: cả hai yêu cầu hợp lệ trả thành công, bản được xử lý sau trở thành `ACTIVE` và bản trước chuyển `ARCHIVED`. Thứ tự hoàn tất phụ thuộc lịch xử lý của server.
Chỉ được công bố bản nháp thuộc đúng quan hệ Coach–Member đang `ACTIVE`; quan hệ mới với cùng Coach không cấp quyền công bố bản nháp của quan hệ đã kết thúc.

### 6.2. Hướng dẫn dinh dưỡng

| Method | Endpoint | Quyền | Mục đích |
| --- | --- | --- | --- |
| `GET` | `/nutrition-guides/me/active` | Member | Hướng dẫn dinh dưỡng hiện tại |
| `GET` | `/nutrition-guides/me/history` | Member | Lịch sử hướng dẫn dinh dưỡng |
| `GET` | `/coach/members/:memberId/nutrition-guides` | Coach | Danh sách hướng dẫn của Member |
| `POST` | `/coach/members/:memberId/nutrition-guides` | Coach | Tạo hướng dẫn dinh dưỡng |
| `PATCH` | `/coach/nutrition-guides/:guideId` | Coach | Sửa hoặc công bố hướng dẫn |

Quy tắc công bố đồng thời và chỉ một bản `ACTIVE` cũng áp dụng cho hướng dẫn dinh dưỡng của cùng Member.

### 6.3. Lịch buổi tập và danh mục bài tập

| Method | Endpoint | Quyền | Mục đích |
| --- | --- | --- | --- |
| `GET` | `/training-sessions/me` | Member | Lịch các buổi tập của Member |
| `GET` | `/training-sessions/:sessionId` | Người liên quan | Chi tiết buổi tập |
| `GET` | `/coach/training-sessions` | Coach | Lịch các buổi tập do Coach quản lý |
| `POST` | `/coach/training-sessions` | Coach | Tạo buổi tập |
| `PATCH` | `/coach/training-sessions/:sessionId` | Coach | Sửa lịch, ghi chú hoặc trạng thái buổi tập |
| `GET` | `/exercises` | Đã đăng nhập | Tìm và lọc danh mục bài tập |
| `GET` | `/exercises/:exerciseId` | Đã đăng nhập | Chi tiết bài tập |
| `POST` | `/admin/exercises` | Admin | Tạo bài tập dùng chung |
| `PATCH` | `/admin/exercises/:exerciseId` | Admin | Sửa hoặc ẩn bài tập |

## 7. Progress Tracking

| Method | Endpoint | Quyền | Mục đích |
| --- | --- | --- | --- |
| `GET` | `/progress/me/summary` | Member | Số liệu tiến độ gần nhất |
| `GET` | `/progress/me/charts` | Member | Dữ liệu biểu đồ theo khoảng thời gian |
| `GET` | `/workout-logs` | Member | Nhật ký tập luyện của chính mình |
| `POST` | `/workout-logs` | Member | Ghi nhật ký tập luyện |
| `PATCH` | `/workout-logs/:logId` | Member | Sửa nhật ký của mình |
| `GET` | `/meal-logs` | Member | Nhật ký ăn uống của chính mình |
| `POST` | `/meal-logs` | Member | Ghi bữa ăn |
| `PATCH` | `/meal-logs/:logId` | Member | Sửa bữa ăn |
| `GET` | `/body-measurements` | Member | Lịch sử cân nặng và số đo |
| `POST` | `/body-measurements` | Member | Thêm lần đo |
| `PATCH` | `/body-measurements/:measurementId` | Member | Sửa lần đo |
| `GET` | `/progress-photos` | Member | Danh sách ảnh tiến trình |
| `POST` | `/progress-photos` | Member | Thêm ảnh tiến trình |
| `PATCH` | `/progress-photos/:photoId` | Member | Sửa ngày hoặc ghi chú ảnh |
| `GET` | `/coach/members/:memberId/progress/summary` | Coach | Tổng quan tiến độ Member đang phụ trách |
| `GET` | `/coach/members/:memberId/workout-logs` | Coach | Xem nhật ký tập của Member |
| `GET` | `/coach/members/:memberId/meal-logs` | Coach | Xem nhật ký ăn của Member |
| `GET` | `/coach/members/:memberId/body-measurements` | Coach | Xem lịch sử số đo |
| `GET` | `/coach/members/:memberId/progress-photos` | Coach | Xem ảnh tiến trình |
| `GET` | `/progress-comments` | Member/Coach liên quan | Xem nhận xét theo đối tượng |
| `POST` | `/coach/progress-comments` | Coach | Gửi nhận xét cho Member |

`GET /workout-logs` và `GET /meal-logs` dùng `page` (từ 1) và `pageSize` (1–100, mặc định 20), trả `pagination`. Nhật ký tập xếp theo `performedAt DESC, id DESC`; nhật ký ăn xếp theo `eatenAt DESC, id DESC` để phân trang ổn định khi nhiều bản ghi cùng thời điểm. Việc thêm bản ghi giữa hai lần tải trang có thể làm dịch vị trí vì API hiện dùng offset pagination.

Admin không có API đọc nhật ký, số đo hoặc ảnh tiến trình chi tiết.

## 8. Messaging

| Method | Endpoint | Quyền | Mục đích |
| --- | --- | --- | --- |
| `GET` | `/conversations` | Member/Coach | Danh sách cuộc trò chuyện và số tin chưa đọc |
| `GET` | `/conversations/:relationshipId/messages` | Hai bên của quan hệ | Tải tin nhắn theo trang |
| `POST` | `/conversations/:relationshipId/messages` | Hai bên, quan hệ `ACTIVE` | Gửi văn bản hoặc hình ảnh |
| `PATCH` | `/conversations/:relationshipId/read-state` | Hai bên của quan hệ | Đánh dấu đã đọc đến một tin nhắn |
| `POST` | `/media/images` | Member/Coach | Tải ảnh lên cho tin nhắn hoặc tiến trình |

Quan hệ `PAUSED` hoặc `ENDED` chỉ được đọc lịch sử. Admin không có API đọc nội dung tin nhắn.

## 9. Voice & Video Call

| Method | Endpoint | Quyền | Mục đích |
| --- | --- | --- | --- |
| `POST` | `/calls` | Member/Coach, quan hệ `ACTIVE` | Tạo bản ghi cuộc gọi thoại hoặc video |
| `POST` | `/calls/:callId/access-tokens` | Hai người tham gia | Nhận token ngắn hạn từ dịch vụ gọi bên thứ ba |
| `PATCH` | `/calls/:callId` | Hai người tham gia | Cập nhật trạng thái bắt máy, từ chối, nhỡ hoặc kết thúc |
| `GET` | `/calls` | Member/Coach | Lịch sử cuộc gọi của chính mình |

SDK bên thứ ba xử lý truyền âm thanh/hình ảnh. Backend chỉ cấp quyền và lưu metadata, không lưu nội dung cuộc gọi. Admin không có API nghe/xem cuộc gọi.

## 10. AI Advisor

| Method | Endpoint | Quyền | Mục đích |
| --- | --- | --- | --- |
| `GET` | `/ai-conversations` | Member/Coach | Danh sách cuộc trò chuyện AI của chính mình |
| `POST` | `/ai-conversations` | Member/Coach | Tạo cuộc trò chuyện mới |
| `GET` | `/ai-conversations/:conversationId` | Chủ sở hữu | Chi tiết cuộc trò chuyện |
| `PATCH` | `/ai-conversations/:conversationId` | Chủ sở hữu | Đổi tên cuộc trò chuyện |
| `DELETE` | `/ai-conversations/:conversationId` | Chủ sở hữu | Xóa mềm cuộc trò chuyện |
| `GET` | `/ai-conversations/:conversationId/messages` | Chủ sở hữu | Tải lịch sử hỏi đáp theo trang |
| `POST` | `/ai-conversations/:conversationId/messages` | Chủ sở hữu | Gửi câu hỏi văn bản tới dịch vụ AI |

Backend phải kiểm tra và chuẩn hóa phản hồi từ dịch vụ AI trước khi lưu. AI không tự đọc hồ sơ, nhật ký, giáo trình hay tin nhắn. Admin không có API đọc lịch sử AI.

## 11. Gym Content

| Method | Endpoint | Quyền | Mục đích |
| --- | --- | --- | --- |
| `GET` | `/gym-profile` | Public | Thông tin phòng gym, giờ mở cửa và nội quy |
| `PATCH` | `/admin/gym-profile` | Admin | Cập nhật thông tin phòng gym |
| `GET` | `/equipment` | Public | Danh sách, tìm kiếm và lọc thiết bị |
| `GET` | `/equipment/:equipmentId` | Public | Hướng dẫn và cảnh báo của thiết bị |
| `POST` | `/admin/equipment` | Admin | Thêm thiết bị |
| `PATCH` | `/admin/equipment/:equipmentId` | Admin | Sửa hoặc ẩn thiết bị |
| `GET` | `/admin/equipment` | Admin | Danh sách tất cả thiết bị, kể cả thiết bị đã ẩn |
| `GET` | `/admin/exercises` | Admin | Danh sách tất cả bài tập, kể cả bài tập đã ẩn |

## 12. Admin Dashboard

| Method | Endpoint | Quyền | Mục đích |
| --- | --- | --- | --- |
| `GET` | `/admin/dashboard` | Admin | Thẻ số liệu, biểu đồ và danh sách cần xử lý theo `from`, `to` |

## 13. Kiểm tra nghiệp vụ bắt buộc ở backend

- Member phải có gói `ACTIVE` mới được gửi yêu cầu Coach và sử dụng chức năng theo dõi chính thức.
- Một Member chỉ có một yêu cầu Coach `PENDING` và một quan hệ `ACTIVE` hoặc `PAUSED`.
- Khi Coach chấp nhận yêu cầu, backend phải kiểm tra lại số suất trong cùng transaction để tránh nhận vượt giới hạn.
- Quan hệ `PAUSED` vẫn chiếm suất; gia hạn gói thành công tự chuyển lại `ACTIVE`.
- Tin nhắn và cuộc gọi mới chỉ được tạo khi quan hệ `ACTIVE`.
- Coach chỉ xem dữ liệu Member đang thuộc quyền phụ trách; khi kết thúc quan hệ thì mất quyền xem chi tiết.
- Admin không được đọc tin nhắn, nội dung cuộc gọi, lịch sử AI, nhật ký, số đo hoặc ảnh tiến trình.
- Cùng một `Idempotency-Key` và cùng nội dung thanh toán phải trả lại kết quả cũ; cùng key nhưng khác nội dung phải trả lỗi `422`.
- Không tin trực tiếp phản hồi từ API AI, dịch vụ email, lưu ảnh hoặc SDK cuộc gọi; luôn kiểm tra cấu trúc trước khi sử dụng.

## 14. Thứ tự triển khai API

1. System + Identity & Access.
2. Membership & Payment.
3. Coaching Relationship.
4. Training & Nutrition.
5. Progress Tracking.
6. Messaging.
7. Voice & Video Call.
8. AI Advisor.
9. Gym Content.
10. Admin Dashboard.

Chỉ bắt đầu nhóm API tiếp theo sau khi nhóm trước có kiểm tra phân quyền và các luồng lỗi trọng yếu.
