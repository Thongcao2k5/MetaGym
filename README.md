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
| [`database/`](database/README.md) | PostgreSQL 17+ (`citext`, `btree_gist`) | Migrations (`0001`–`0028`), baseline/demo seeds và `schema_assertions.sql`. |
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

Tạo một database trống (hỗ trợ PostgreSQL 17+ với extension `citext` và `btree_gist`), sau đó chạy toàn bộ migration (`0001` → `0028`) theo hướng dẫn chi tiết tại [database/README.md](database/README.md):

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

Kiểm tra API và kết nối PostgreSQL qua `GET http://localhost:3000/api/v1/health` (tài liệu Swagger UI tại `http://localhost:3000/api-docs`, endpoint keep-alive tại `GET /ping`).

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
| **Thanh toán ZaloPay Sandbox** | `ZALOPAY_APP_ID`, `ZALOPAY_KEY1`, `ZALOPAY_KEY2`, `ZALOPAY_PUBLIC_ORIGIN` | Tạo đơn QR & đối soát kết quả qua API Sandbox (`0027_zalopay_sandbox.up.sql`). |
| **Thanh toán MoMo Sandbox** | `MOMO_PARTNER_CODE`, `MOMO_ACCESS_KEY`, `MOMO_SECRET_KEY`, `MOMO_PUBLIC_ORIGIN`, `MOMO_WEB_RETURN_URL` | Tạo đơn, IPN/return & đối soát MoMo Sandbox (`0026_momo_sandbox.up.sql`). |
| **Thanh toán VNPay Sandbox** | `VNPAY_TMN_CODE`, `VNPAY_HASH_SECRET`, `VNPAY_PUBLIC_ORIGIN`, `VNPAY_WEB_RETURN_URL` | IPN, return & đối soát QueryDR VNPay Sandbox (`0025_vnpay_sandbox.up.sql`). |

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
