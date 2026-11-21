# Meta Gym

Hệ thống quản lý phòng tập & huấn luyện cá nhân **Meta Gym** (đồ án chuyên ngành), gồm ứng dụng di động cho **Member & Coach**, trang quản trị **Admin Web**, và **REST API + PostgreSQL**.

Repository: <https://github.com/Thongcao2k5/MetaGym>

---

## Kiến trúc & Thành phần

| Thành phần | Công nghệ chính | Mô tả |
|---|---|---|
| [`mobile-app/`](mobile-app/README.md) | Flutter (Dart `^3.13.2`), Provider, GoRouter, Dio, `fl_chart`, `livekit_client` | Ứng dụng cho **Member** và **Coach** (tập luyện, dinh dưỡng, tiến độ, nhắn tin, gọi thoại/video, trợ lý AI, check-in QR). |
| [`admin-web/`](admin-web/README.md) | Vite (`^8.3.0`), Bootstrap 5 (`^5.3.8`), Chart.js (`^4.5.1`), QRCode | Trang quản trị **Admin** (quản lý người dùng, gói tập, thanh toán, thiết bị, bài tập, in mã QR check-in). |
| [`backend/`](backend/package.json) | Node.js (`>= 22`), Express 5, PostgreSQL (`pg`), Zod, JWT, Sharp, LiveKit SDK | REST API nghiệp vụ, xác thực/phân quyền RBAC, xử lý ảnh và kết nối dịch vụ ngoài. |
| [`database/`](database/README.md) | PostgreSQL 17+ (`citext`, `btree_gist`) | Migrations (`0001`–`0024`), baseline/demo seeds và `schema_assertions.sql`. |
| [`design-system/`](design-system/meta-gym/MASTER.md) & [`DESIGN.md`](DESIGN.md) | Futuristic Performance Glass | Hệ thống thiết kế, token màu/font (`Be Vietnam Pro`), adapter cho Flutter & Bootstrap 5. |
| [`docs/`](docs/README.md) | Markdown & SQL | Đặc tả yêu cầu, hợp đồng API, kiến trúc và kế hoạch triển khai Cloud Free. |

---

## Cấu trúc thư mục

```text
MetaGym/
├── mobile-app/          # Ứng dụng Flutter (lib/app, lib/core, lib/features)
├── admin-web/           # Web Admin (Vite + Bootstrap 5 + Chart.js)
├── backend/             # Express 5 REST API (src/routes, controllers, services, storage)
├── database/            # migrations/*.sql, seeds/*.sql, tests/schema_assertions.sql
├── design-system/       # MASTER.md, page specs và adapters (Bootstrap / Flutter)
├── docs/                # requirements/, architecture/, deployment/, decisions/
└── tasks/               # Kế hoạch và tiến độ công việc
```

---

## Hướng dẫn chạy Local

### 1. Chuẩn bị Database (PostgreSQL)

Tạo một database trống (hỗ trợ PostgreSQL 17+ với extension `citext` và `btree_gist`), sau đó chạy toàn bộ migration (`0001` → `0024`) theo hướng dẫn chi tiết tại [database/README.md](database/README.md):

```powershell
$env:DATABASE_URL = 'postgresql://postgres:password@localhost:5432/meta_gym'

Get-ChildItem database/migrations/*.up.sql |
  Sort-Object Name |
  ForEach-Object { psql $env:DATABASE_URL -v ON_ERROR_STOP=1 -f $_.FullName }
```

Chạy baseline seed và (tùy chọn) demo seed cho môi trường `development`/`test` (tài khoản mẫu `admin@metagym.local`, `coach@metagym.local`, `member@metagym.local` xem trong [database/README.md](database/README.md#L92-L115)).

### 2. Chạy Backend (`http://localhost:3000`)

```powershell
cd backend
Copy-Item .env.example .env
# Mở backend/.env để điền DATABASE_URL và JWT_SECRET (>= 32 ký tự)
npm install
npm run dev
```

Kiểm tra API và kết nối PostgreSQL qua `GET http://localhost:3000/api/v1/health`.

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

### 3. Chạy Admin Web

```powershell
cd admin-web
npm install
npm run dev
```

### 4. Chạy Mobile App (Flutter)

```powershell
cd mobile-app
flutter pub get

# Chạy trên Chrome / Windows (cùng máy với backend)
flutter run -d chrome --dart-define=APP_ENV=local

# Chạy trên Android Emulator (trỏ backend qua 10.0.2.2:3000)
flutter run --dart-define=APP_ENV=emulator
```

---

## Tích hợp bên ngoài & Bảo mật Production

Các tích hợp ngoài trong `backend/.env` chỉ được bật khi cấu hình đủ biến môi trường; nếu chưa cấu hình, API trả `503 SERVICE_UNAVAILABLE` thay vì dùng token giả:

| Tính năng | Biến môi trường (`backend/.env`) | Ghi chú |
|---|---|---|
| **Trợ lý AI** | `OPENAI_API_KEY`, `OPENAI_MODEL` | Backend gọi OpenAI Responses API. |
| **Email đặt lại mật khẩu** | `PASSWORD_RESET_DELIVERY_URL`, `PASSWORD_RESET_DELIVERY_TOKEN` | Nhận `POST` JSON gồm `email`, `code`, `requestId`. |
| **Gọi thoại/video (LiveKit)** | `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` | Lấy từ [LiveKit Cloud](https://cloud.livekit.io/). Cần 2 thiết bị đăng nhập Member & Coach đang có quan hệ hoạt động. |
| **RTC Token Provider (tùy chọn)** | `CALL_TOKEN_SERVICE_URL`, `CALL_TOKEN_SERVICE_TOKEN` | Trả về `accessToken`, `providerCallId`, `channelId`, `expiresAt`. |
| **Lưu trữ ảnh Cloud & Realtime** | `SUPABASE_URL`, `SUPABASE_SECRET_KEY`, `SUPABASE_STORAGE_BUCKET` | Xem thêm [docs/deployment/supabase-free.md](docs/deployment/supabase-free.md). |

> **Yêu cầu khi `NODE_ENV=production`:**
> - Bắt buộc cấu hình `CORS_ALLOWED_ORIGINS` là danh sách origin **HTTPS** cách nhau bằng dấu phẩy (ví dụ `https://app.example.com,https://admin.example.com`); thiếu hoặc sai định dạng sẽ làm backend từ chối khởi động. Ở `development`/`test`, mặc định cho phép mọi origin local.
> - Dùng `JWT_SECRET` đủ mạnh, HTTPS/TLS qua reverse proxy, database và secret riêng; không dùng tài khoản demo trên môi trường production.

---

## Kiểm thử & Xác minh

| Thành phần | Lệnh kiểm tra |
|---|---|
| **Backend** | `cd backend && npm run check && npm test` |
| **Smoke test API** *(sau khi seed & cấu hình `SMOKE_*` trong `.env`)* | `cd backend && npm run smoke` |
| **Admin Web** | `cd admin-web && npm run build && npm test` |
| **Mobile App** | `cd mobile-app && flutter analyze && flutter test` |

---

## Tài liệu tham khảo nhanh

- **Hợp đồng API & Tích hợp Frontend:** [api-contract.md](docs/requirements/api-contract.md) · [frontend-api-integration.md](docs/requirements/frontend-api-integration.md)
- **Hệ thống thiết kế UI/UX:** [DESIGN.md](DESIGN.md) · [MASTER.md](design-system/meta-gym/MASTER.md)
- **Triển khai Cloud (100% Free):** [free-cloud-deployment-plan.md](docs/deployment/free-cloud-deployment-plan.md) · [supabase-free.md](docs/deployment/supabase-free.md)
- **Tối ưu dung lượng ảnh:** [image-optimization-plan.md](docs/deployment/image-optimization-plan.md)
