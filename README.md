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
- Gọi thoại/video từ Tin nhắn: thêm `LIVEKIT_URL` (`wss://...`),
  `LIVEKIT_API_KEY` và `LIVEKIT_API_SECRET` vào `backend/.env` rồi khởi động lại backend.
  Lấy các giá trị từ project trong [LiveKit Cloud](https://cloud.livekit.io/).
  Flutter Android dùng `lib/main.dart`. Đăng nhập Member và Coach có quan hệ
  đang hoạt động trên hai thiết bị, mở cả hai ứng dụng rồi bấm nút gọi trong Tin nhắn.
  Hai thiết bị phải truy cập được cùng backend. Bản này báo cuộc gọi đến khi app đang mở.
- Provider token RTC ngoài (tùy chọn): `CALL_TOKEN_SERVICE_URL`; có thể thêm
  `CALL_TOKEN_SERVICE_TOKEN`. Dịch vụ RTC nhận thông tin cuộc gọi và trả về
  `accessToken`, `providerCallId`, `channelId`, `expiresAt`.

Nếu chưa cấu hình tích hợp tương ứng, API trả `503 SERVICE_UNAVAILABLE` thay vì
dùng khóa hoặc token giả.

### Kiểm thử thanh toán gói tập bằng ZaloPay Sandbox

1. Sao lưu database đang dùng và chạy các migration tới `0027_zalopay_sandbox.up.sql`.
2. Đặt `ZALOPAY_APP_ID` và `ZALOPAY_KEY1` trong `backend/.env` từ
   [bộ demo ZaloPay](https://developers.zalopay.vn/v2/start/) rồi khởi động lại backend.
3. Chọn **Gói tập → Mua → Thanh toán bằng ZaloPay**, rồi mở ví ZaloPay Sandbox trên
   điện thoại thật để quét mã QR trong MetaGym. Mã QR dùng đúng `order_url` mà ZaloPay
   trả về. Bấm **Kiểm tra trạng thái** nếu kết quả chưa hiện.

Bản demo dùng API Sandbox cho cả tạo đơn và truy vấn kết quả. Backend chỉ kích hoạt
hoặc gia hạn sau khi truy vấn thành công đúng đơn và đúng số tiền.

Để nhận callback, đặt thêm `ZALOPAY_KEY2` và `ZALOPAY_PUBLIC_ORIGIN` (HTTPS)
trỏ về endpoint `POST /api/v1/payments/zalopay/callback`. Backend gửi URL này
khi tạo đơn mới. Sau khi xác thực chữ ký callback, backend vẫn truy vấn trực tiếp
ZaloPay vì bộ khóa demo được công khai. Khi không có callback, app tra cứu kết quả
khi quay lại màn thanh toán hoặc nhấn **Kiểm tra trạng thái**.

### Cấu hình MoMo Sandbox cho các giao dịch MoMo

1. Sao lưu database đang dùng và chạy các migration tới `0026_momo_sandbox.up.sql`.
2. Lấy ba khóa Test trong [MoMo for Business](https://business.momo.vn/) và điền
   `MOMO_PARTNER_CODE`, `MOMO_ACCESS_KEY`, `MOMO_SECRET_KEY` trong `backend/.env`.
3. `MOMO_PUBLIC_ORIGIN` là địa chỉ HTTPS công khai phục vụ
   `POST /api/v1/payments/momo/ipn` và `GET /api/v1/payments/momo/return`.
   Backend dùng `VNPAY_PUBLIC_ORIGIN` nếu để trống. Với Flutter Web, có thể đặt
   `MOMO_WEB_RETURN_URL` về màn Gói tập, ví dụ
   `https://app-test.example.com/#/member/features/membership`.
4. Khởi động lại backend. Trong app chọn **Gói tập → Mua → Thanh toán bằng MoMo**
   rồi dùng [MoMo Test](https://developers.momo.vn/v3/vi/docs/payment/onboarding/test-instructions/).

### VNPay Sandbox và lịch sử giao dịch

Giao diện hiện tại tạo đơn mới qua MoMo. Cấu hình VNPay dưới đây dùng để xử lý
callback, đối soát đơn VNPay đã tạo và hỗ trợ bản app cũ khi chưa bật MoMo.

1. Chạy các migration tới `0025_vnpay_sandbox.up.sql`. Sao lưu nếu nâng cấp database đã có dữ liệu.
2. Đăng ký merchant [VNPay Sandbox](https://sandbox.vnpayment.vn/devreg/) và điền
   `VNPAY_TMN_CODE`, `VNPAY_HASH_SECRET`, `VNPAY_PUBLIC_ORIGIN` vào `backend/.env`.
   Origin cần là địa chỉ HTTPS public trỏ vào backend, không có đường dẫn (ví dụ
   `https://api-test.example.com`). Giữ secret trên backend.
3. Đăng ký IPN trong cấu hình merchant Sandbox với URL
   `https://api-test.example.com/api/v1/payments/vnpay/ipn`. Backend gửi Return URL
   `https://api-test.example.com/api/v1/payments/vnpay/return` khi tạo giao dịch.
   Khi chạy Flutter Web, đặt `VNPAY_WEB_RETURN_URL` về màn Gói tập,
   ví dụ `https://app-test.example.com/#/member/features/membership`.
   Khi chạy local, có thể dùng `http://localhost:8080/#/member/features/membership`
   với cổng cố định. Thêm origin web vào CORS của backend nếu web chạy ở origin khác.
4. Trên bản app cũ có nút **Thanh toán bằng VNPay**, dùng
   [thẻ thử nghiệm chính thức](https://sandbox.vnpayment.vn/apis/vnpay-demo/).
   Trên trang kết quả, bấm **Mở ứng dụng MetaGym** hoặc **Mở MetaGym Web**.
   App tự kiểm tra trạng thái và có nút **Kiểm tra trạng thái** để truy vấn lại.

Backend chỉ ghi nhận giao dịch từ IPN đã xác minh hoặc kết quả đối soát QueryDR đã
xác minh. Mỗi Member có tối đa một giao dịch VNPay chờ xác nhận. Giao dịch thành
công được ghi vào lịch sử và kích hoạt/gia hạn đúng một lần. VNPay Sandbox chỉ
áp dụng cho gói tập hội viên. Thanh toán tại quầy và các luồng gói Coach giữ cách
xử lý riêng.

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

Để thiết kế frontend theo ý riêng, dùng [hợp đồng API](docs/requirements/api-contract.md) và [hướng dẫn tích hợp frontend](docs/requirements/frontend-api-integration.md). Backend đã có test liên thông với PostgreSQL; các màn hình hiện có không quyết định thiết kế giao diện tiếp theo.
