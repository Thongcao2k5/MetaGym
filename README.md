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

## Trạng thái hiện tại

Dự án đã có schema PostgreSQL, API nghiệp vụ MVP, admin web và các luồng Member/Coach chính. Các tích hợp AI, email và RTC cần được cấu hình riêng theo môi trường triển khai.
