# Meta Gym

Khung dự án đồ án chuyên ngành Meta Gym.

## Thành phần

- `mobile-app/`: Flutter dành cho Member và Coach.
- `admin-web/`: HTML, CSS, JavaScript, Bootstrap và Chart.js, chạy bằng Vite.
- `backend/`: Node.js, Express và PostgreSQL client.
- `database/`: nơi đặt migration và tài liệu cơ sở dữ liệu sau này.
- `docs/`: tài liệu yêu cầu và kiến trúc.

## Chạy từng phần

### Backend

```powershell
cd backend
Copy-Item .env.example .env
npm run dev
```

Trước khi chạy backend, tạo database và chạy migration theo [hướng dẫn database](database/README.md). Backend mặc định chạy tại `http://localhost:3000`. Kiểm tra kết nối API và PostgreSQL bằng `GET /api/v1/health`.

Khi `NODE_ENV=production`, backend yêu cầu `CORS_ALLOWED_ORIGINS` là danh sách origin HTTPS cách nhau bằng dấu phẩy (ví dụ `https://app.example.com,https://admin.example.com`); thiếu hoặc dùng origin không hợp lệ sẽ làm backend từ chối khởi động. Ở môi trường development/test, mặc định cho phép mọi origin để chạy local. Production cũng cần `JWT_SECRET` đủ mạnh, HTTPS/TLS ở reverse proxy, database và secret riêng; không dùng tài khoản demo hoặc cấu hình local để mở Internet.

Các tích hợp bên ngoài chỉ được bật khi cấu hình đủ biến môi trường:

- AI: `OPENAI_API_KEY` và `OPENAI_MODEL`; backend gọi OpenAI Responses API.
- Email đặt lại mật khẩu: `PASSWORD_RESET_DELIVERY_URL`; có thể thêm
  `PASSWORD_RESET_DELIVERY_TOKEN`. Dịch vụ nhận `POST` JSON gồm `email`, `code`
  và `requestId` rồi chịu trách nhiệm gửi email.
- Token gọi thoại/video: `CALL_TOKEN_SERVICE_URL`; có thể thêm
  `CALL_TOKEN_SERVICE_TOKEN`. Dịch vụ RTC nhận thông tin cuộc gọi và trả về
  `accessToken`, `providerCallId`, `channelId`, `expiresAt`.

Nếu chưa cấu hình tích hợp tương ứng, API trả `503 SERVICE_UNAVAILABLE` thay vì
dùng khóa hoặc token giả.

### Admin web

```powershell
cd admin-web
npm run dev
```

### Flutter mobile

```powershell
cd mobile-app
F:\flutter\bin\flutter.bat run
```

### Smoke test API

Sau khi chạy migration, baseline seed và demo seed, khởi động backend rồi cấu
hình các biến `SMOKE_*` trong `backend/.env`. Chạy bộ kiểm tra nhanh:

```powershell
cd backend
npm run smoke
```

Script kiểm tra health, đăng nhập Admin/Coach/Member và một API nghiệp vụ có
phân quyền cho mỗi vai trò. Lệnh trả mã thoát khác `0` nếu một bước thất bại và
không in mật khẩu hoặc access token ra log.

## Trạng thái hiện tại

Dự án đã có schema PostgreSQL, API nghiệp vụ MVP, admin web và các luồng Member/Coach chính. Các tích hợp AI, email và RTC cần được cấu hình riêng theo môi trường triển khai.
