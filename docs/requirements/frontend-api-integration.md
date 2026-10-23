# Meta Gym — Hướng dẫn tích hợp API cho frontend

Tài liệu này mô tả cách gọi backend hiện có để chủ dự án tự thiết kế giao diện sau này. Route và quyền đầy đủ ở [api-contract.md](api-contract.md); ví dụ ở đây dùng base URL `/api/v1`. Các ID trong ví dụ lấy từ response ngay trước đó. Dùng [demo seed trong database/README.md](../../database/README.md#demo-seed-chỉ-developmenttest) chỉ ở local/test; `TEST_DATABASE_URL` dành riêng cho test tự động.

## Quy ước gọi API

- Đăng nhập bằng `POST /auth/sessions` với `{"email":"member@example.com","password":"..."}`; đọc `data.accessToken`, `data.expiresIn` (3600 giây) và `data.user.role`. Các request sau gửi `Authorization: Bearer <accessToken>`. Sau đổi mật khẩu, khóa tài khoản hoặc token hết hạn, đăng nhập lại; backend chưa có refresh token.
- Gửi JSON với `Content-Type: application/json`, trừ upload ảnh gửi bytes PNG/JPEG. Các trường thời điểm phải là ISO 8601 có offset, ví dụ `2026-10-22T08:00:00+07:00`; response timestamp là ISO UTC. Membership và lọc biểu đồ tính ngày theo `Asia/Ho_Chi_Minh`.
- Response một đối tượng là `{"data":{...}}`, nhiều đối tượng là `{"data":[...]}`; chỉ endpoint có phân trang thêm `pagination`. Response lỗi là `{"error":{"code":"...","message":"...","details":{}}}`. Xử lý theo HTTP status và `error.code`, đừng phụ thuộc ngôn ngữ của `message`.
- `401` là thiếu hoặc token hết hiệu lực; `403` là sai vai trò/thiếu membership/quan hệ không hoạt động; `404` cũng dùng để che dữ liệu không thuộc quyền; `409` là xung đột trạng thái; `422` là request sai; `502` là provider/storage lỗi; `503` là provider chưa cấu hình.

## Luồng Member và Coach

1. Nếu chưa có tài khoản, Member gửi `POST /auth/registrations` với `email`, `fullName`, `password`; chỉ tạo vai trò `MEMBER`. Admin tạo Coach qua `POST /admin/coaches` với `email`, `fullName`, `password`, `memberLimit`.
2. Gọi `GET /membership-plans` để lấy `planId`. Member mua gói bằng `POST /payments`, body `{"planId":"<planId>"}` và header `Idempotency-Key: <UUID riêng cho lần mua>`. Response `201` chứa `data.id`, `data.status=PENDING`. Gửi lại cùng key/body trả `200` với cùng payment; cùng key nhưng body khác trả `422 IDEMPOTENCY_KEY_CONFLICT`. Trong local/test, `POST /payments/:paymentId/mock-confirmations` với `{}` chuyển thành `SUCCESS` và trả `data.membership`; gọi lại trả cùng membership. Gói mua thêm có thể ở `SCHEDULED`, chưa tạo quyền sử dụng ngay.
3. Member xem `GET /coaches` (có `availableSlots`), rồi `POST /coach-requests` với `{"coachId":"<coachId>","message":"Mục tiêu của tôi"}`. Cần membership `ACTIVE`; chỉ một yêu cầu `PENDING` hoặc quan hệ `ACTIVE`/`PAUSED`. Coach xem `GET /coach/requests`, sau đó `PATCH /coach/requests/:requestId` với `{"decision":"ACCEPTED"}` hoặc `{"decision":"REJECTED","reason":"Không còn lịch trống"}`. Chấp nhận trả `data.request` và `data.relationship`; `relationship.id` dùng cho hội thoại và kết thúc quan hệ. Member xem `GET /relationships/me`, lịch sử ở `/relationships/me/history`.
4. Coach chỉ tạo nội dung cho Member đang thuộc quan hệ `ACTIVE`. Tạo giáo trình nháp bằng `POST /coach/members/:memberId/training-plans`, ví dụ:

   ```json
   {
     "title": "Tập sức mạnh",
     "days": [{"dayNumber": 1, "title": "Ngày một", "exercises": [
       {"exerciseId": "<exerciseId>", "displayOrder": 1, "sets": 3, "reps": "10"}
     ]}]
   }
   ```

   Lấy `exerciseId` từ `GET /exercises`. Member không thấy bản `DRAFT`. Coach công bố bằng `POST /coach/training-plans/:planId/publications` với `{}`; Member xem `/training-plans/me/active` và `/training-plans/me/history`. Bản được công bố lưu snapshot tên/hướng dẫn bài tập; bản `ACTIVE` cũ thành `ARCHIVED`. Hướng dẫn dinh dưỡng: `POST /coach/members/:memberId/nutrition-guides` với `{"title":"Dinh dưỡng","content":"Ăn đủ chất"}`, rồi `PATCH /coach/nutrition-guides/:guideId` với `{"publish":true}`. Member xem `/nutrition-guides/me/active` và `/nutrition-guides/me/history`.
5. Coach tạo buổi tập bằng `POST /coach/training-sessions` với `{"memberId":"<memberId>","title":"Buổi đầu","scheduledStartAt":"2026-11-01T08:00:00+07:00","scheduledEndAt":"2026-11-01T09:00:00+07:00"}`. Member xem `/training-sessions/me`. Chỉ buổi `SCHEDULED` trong quan hệ `ACTIVE` được Coach sửa; chuyển sang `COMPLETED`, `MEMBER_ABSENT` hoặc `CANCELLED` qua `PATCH`, hủy phải có `cancellationReason`.
6. Member có membership hiệu lực ghi `POST /workout-logs` với `performedAt`, `durationMinutes`, `exercises` (mỗi bài có `exerciseId` hoặc `exerciseName`, `displayOrder`); ghi `POST /meal-logs` với `eatenAt`, `mealName`, tùy chọn `mealType`, `estimatedCalories`, `imageMediaId`. `GET /workout-logs` và `/meal-logs` dùng `page`, `pageSize` (1–100) và trả `pagination`. Member sửa của mình bằng `PATCH /.../:logId`; nhật ký đã được Coach nhận xét trả `409 PROGRESS_ALREADY_REVIEWED`. Coach hiện tại xem qua `/coach/members/:memberId/workout-logs` và `/meal-logs`; Coach cũ mất quyền khi quan hệ kết thúc.
7. Member ghi `POST /body-measurements` với `{"measuredAt":"2026-10-22T07:00:00+07:00","weightKg":72.5}`, xem `GET /progress/me/summary` và `/progress/me/charts?from=2026-10-01&to=2026-10-31`. Biểu đồ trả mảng theo thời điểm tăng dần, không tự đổi đơn vị. Ảnh: upload `POST /media/images` với body bytes PNG/JPEG tối đa 5 MB, header `x-image-purpose: PROGRESS_PHOTO` hoặc `MEAL_PHOTO`; lấy `data.id` sau khi asset `READY`, rồi gắn bằng `POST /progress-photos` với `{"mediaId":"<mediaId>","takenAt":"2026-10-22T07:00:00+07:00"}` hoặc truyền `imageMediaId` khi tạo bữa ăn. Ảnh khác owner, sai purpose hoặc chưa `READY` bị từ chối. Để hiển thị ảnh, gọi `GET /media/images/:mediaId/access-url`, dùng `data.url` trước `expiresAt` (5 phút); khi hết hạn lấy URL mới.
8. Hội thoại được tạo khi Coach chấp nhận. `GET /conversations` trả `unreadCount`; `GET /conversations/:relationshipId/messages?page=1&pageSize=20` trả tin mới nhất trước. Gửi văn bản bằng `POST /conversations/:relationshipId/messages` với `{"messageType":"TEXT","clientMessageId":"<UUID mới>","content":"Xin chào"}`. Tin ảnh dùng `messageType=IMAGE`, `mediaId` của asset `MESSAGE` đã `READY` thuộc người gửi. Gửi lại cùng ID và cùng nội dung trả `200` với cùng tin; cùng ID khác nội dung trả `409 MESSAGE_ID_CONFLICT`. `PATCH /conversations/:relationshipId/read-state` với `{"messageId":"<id tin do người còn lại gửi>"}` cập nhật cursor, không lùi; dùng ID tin do chính mình gửi trả `422 VALIDATION_ERROR`. Quan hệ `PAUSED`/`ENDED` được đọc lịch sử nhưng không gửi tin mới.
9. Member kết thúc qua `POST /relationships/:relationshipId/terminations` với `{"reason":"Đã hoàn thành"}`. Coach có thể xin Admin duyệt kết thúc; Admin có API chuyển Coach. Sau kết thúc, `/relationships/me` trả `{"data":null}`; lịch sử vẫn đọc được. Coach cũ không đọc nhật ký, giáo trình, hướng dẫn hay buổi tập của quan hệ cũ, kể cả khi Member quay lại cùng Coach. Member vẫn đọc nội dung đã công bố của chính mình.

## Giới hạn môi trường và checklist tích hợp

- `MOCK_QR` chỉ là xác nhận mô phỏng dành cho local/test; không kết nối cổng thanh toán thật. Media dùng ổ đĩa local nếu có `MEDIA_STORAGE_DIR`, chưa phải object storage production. URL ảnh có chữ ký là bearer URL: người đã có URL có thể dùng đến hết hạn, kể cả khi quyền cấp URL mới đã bị thu hồi.
- AI, email khôi phục mật khẩu và RTC cần provider riêng. Khi thiếu cấu hình, API liên quan trả `503 SERVICE_UNAVAILABLE`; không hiển thị chúng như chức năng đã hoạt động thật. Provider lỗi có thể trả `502`. Production cần HTTPS, secret riêng, `CORS_ALLOWED_ORIGINS` là các origin HTTPS được phép, và quy trình triển khai riêng.
- Khi tích hợp frontend: đăng nhập riêng từng vai trò; thử membership chưa có/đang chờ/đã hết; thử yêu cầu Coach trùng và hết suất; che bản nháp với Member; xử lý `401/403/404/409/422/502/503`; retry thanh toán và tin nhắn bằng cùng key/ID; làm mới URL ảnh hết hạn; hiển thị `PAUSED`/`ENDED` đúng quyền; kiểm tra trang rỗng và nhiều trang. Không cần chọn bố cục hay dựng màn hình để thực hiện các kiểm tra API này.

Kịch bản tích hợp tự động ở `backend/test/api-journey.postgres.test.js` chạy các bước chính trên PostgreSQL test riêng và dọn dữ liệu sau khi chạy.
