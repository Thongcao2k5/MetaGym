# Kế hoạch triển khai MetaGym lên Cloud (100% Free)

Tài liệu này hướng dẫn chi tiết từng bước triển khai **Database**, **Backend** và **WebAdmin** của dự án **MetaGym** lên các nền tảng miễn phí, đồng thời đảm bảo vẫn có thể tiếp tục phát triển song song trên GitHub mà không làm gián đoạn hệ thống.

---

## 1. Kiến trúc & Nền tảng sử dụng (All Free)

| Thành phần | Thư mục repo | Nền tảng đề xuất | Giới hạn gói Free cần lưu ý |
|---|---|---|---|
| **Database & File Storage** | `database/` | **Supabase Free** | 500 MB PostgreSQL, 1 GB Storage, 2 project miễn phí; có thể tạm dừng (pause) nếu 7 ngày không có hoạt động. |
| **Backend REST API** | `backend/` | **Render Free** (Web Service) | 750 giờ/tháng; tự sleep sau **15 phút** không có request (cold start ~30–50s ở request đầu tiên); ổ đĩa ephemeral (không lưu file lâu dài). |
| **WebAdmin** | `admin-web/` | **Cloudflare Pages** (hoặc **Vercel**) | Băng thông không giới hạn (Cloudflare Pages), build Vite static nhanh, hỗ trợ HTTPS mặc định. |

> **Lưu ý về ảnh & media:** Vì ổ đĩa của Render Free sẽ bị xóa mỗi lần server sleep hoặc redeploy, nên **bắt buộc dùng Supabase Storage** (đã được backend tích hợp sẵn trong `backend/src/storage/supabase-image-storage.js`) thay cho `MEDIA_STORAGE_DIR` cục bộ. Để tối ưu dung lượng ảnh tĩnh và tiết kiệm hạn mức 1 GB Supabase Storage, xem thêm [`docs/deployment/image-optimization-plan.md`](./image-optimization-plan.md).

---

## 2. Chuẩn bị trước khi triển khai (trên máy & GitHub)

### 2.1. Chiến lược nhánh Git (tránh lỗi khi code chưa hoàn thiện)
- Giữ nhánh phát triển hằng ngày (ví dụ `thong` hoặc nhánh feature).
- Dùng một nhánh ổn định (ví dụ `main` hoặc tạo nhánh `deploy`) để kết nối **Auto-Deploy** với Render và Cloudflare Pages.
- Chỉ merge vào nhánh deploy khi đã kiểm tra:
  - Backend: `cd backend && npm run check` (không lỗi cú pháp).
  - WebAdmin: `cd admin-web && npm run build` (build Vite ra `dist/` thành công).

### 2.2. Kiểm tra bảo mật repository
- File `.gitignore` đã loại trừ `.env`, `.env.*`, `node_modules/`, `dist/`, `.media-storage/`.
- **Tuyệt đối không** commit `DATABASE_URL`, `JWT_SECRET`, `SUPABASE_SECRET_KEY`, hoặc khóa API vào Git.

---

## 3. Giai đoạn 1 — Triển khai Database & Storage (Supabase Free)

### Bước 1.1: Tạo Project trên Supabase
1. Đăng nhập [Supabase Dashboard](https://supabase.com/dashboard) và tạo **New Project**.
2. Lưu lại mật khẩu Database vừa tạo.
3. Vào **Project Settings → Database → Connection string** (hoặc nút **Connect** trên thanh trên cùng):
   - Chọn mode **Session pooler** (cổng `5432`, chuẩn IPv4) để tương thích ổn định với Render Free.
   - Lưu lại chuỗi kết nối dạng:
     `postgresql://postgres.<project-ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres`

### Bước 1.2: Chạy Migration & Kiểm tra Schema
Chạy toàn bộ các file `*.up.sql` theo thứ tự tăng dần (`0001` → `0024`) bằng `psql`:

```powershell
$env:DATABASE_URL = 'postgresql://postgres.<project-ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres'

Get-ChildItem database/migrations/*.up.sql |
  Sort-Object Name |
  ForEach-Object { psql $env:DATABASE_URL -v ON_ERROR_STOP=1 -f $_.FullName }
```

Kiểm tra schema sau khi chạy migration:

```powershell
psql $env:DATABASE_URL -v ON_ERROR_STOP=1 -f database/tests/schema_assertions.sql
```

### Bước 1.3: Tạo dữ liệu khởi tạo (Seed)
1. **Baseline seed** (tạo Admin đầu tiên và `gym_profile`):
   - Tạo bcrypt hash cho mật khẩu Admin (có thể dùng `node -e "import('bcryptjs').then(b => console.log(b.default.hashSync('MatKhauManh!', 10)))"`).
   - Chạy:
     ```powershell
     psql $env:DATABASE_URL -v ON_ERROR_STOP=1 `
       -v admin_id='00000000-0000-4000-8000-000000000001' `
       -v admin_email='admin@metagym.local' `
       -v admin_password_hash='<bcrypt-hash>' `
       -v admin_full_name='Meta Gym Admin' `
       -v gym_name='Meta Gym' `
       -v gym_address='Địa chỉ phòng gym' `
       -f database/seeds/0001_baseline.sql
     ```
2. **Demo seed (chỉ dùng cho môi trường thử nghiệm/đồ án, không dùng cho production thật):**
   ```powershell
   psql $env:DATABASE_URL -v ON_ERROR_STOP=1 `
     -v demo_seed_environment='development' `
     -f database/seeds/0002_demo.sql
   ```
   Tài khoản mẫu sau khi chạy `0002_demo.sql`:
   - Admin: `admin@metagym.local` / `MetaGymAdmin!2026`
   - Coach: `coach@metagym.local` / `MetaGymCoach!2026`
   - Member: `member@metagym.local` / `MetaGymMember!2026`

### Bước 1.4: Cấu hình Supabase Storage (lưu ảnh)
1. Vào **Storage → New bucket**, đặt tên `meta-gym-media`.
2. Chọn **Private** (không public trực tiếp).
3. Đặt giới hạn file `5 MB` và chỉ cho phép `image/jpeg`, `image/png`.
4. Vào **Project Settings → API Keys**, lấy **Project URL** và **Secret key** (`sb_secret_...`).

*(Tùy chọn)* Nếu muốn bật Realtime cho tin nhắn/cuộc gọi đến: chạy `docs/deployment/supabase-realtime.sql` trong **SQL Editor** của Supabase và lấy thêm `SUPABASE_PUBLISHABLE_KEY` + Legacy JWT Secret (`SUPABASE_REALTIME_JWT_SECRET`).

---

## 4. Giai đoạn 2 — Triển khai Backend (Render Free)

### Bước 2.1: Tạo Web Service trên Render
1. Đăng nhập [Render](https://render.com/), chọn **New + → Web Service**.
2. Kết nối tới repository GitHub `MetaGym`, chọn nhánh deploy (ví dụ `main` hoặc `deploy`).
3. Điền thông tin dịch vụ:
   - **Root Directory:** `backend`
   - **Runtime:** `Node` (Node `>= 22.0.0` theo `backend/package.json`)
   - **Build Command:** `npm ci`
   - **Start Command:** `npm start`
   - **Instance Type:** `Free`
   - **Health Check Path:** `/api/v1/health`

### Bước 2.2: Cấu hình Environment Variables trên Render
Thêm các biến môi trường sau trong mục **Environment**:

| Biến | Giá trị | Bắt buộc? |
|---|---|---|
| `NODE_ENV` | `production` | Bắt buộc |
| `DATABASE_URL` | Connection string Session Pooler của Supabase | Bắt buộc |
| `JWT_SECRET` | Chuỗi ngẫu nhiên >= 32 ký tự | Bắt buộc |
| `CORS_ALLOWED_ORIGINS` | URL HTTPS của WebAdmin (ví dụ `https://metagym-admin.pages.dev`) | **Bắt buộc** khi `NODE_ENV=production` |
| `SUPABASE_URL` | `https://<project-ref>.supabase.co` | Khuyến nghị (lưu ảnh) |
| `SUPABASE_SECRET_KEY` | `sb_secret_...` | Khuyến nghị (lưu ảnh) |
| `SUPABASE_STORAGE_BUCKET` | `meta-gym-media` | Khuyến nghị (lưu ảnh) |
| `MEDIA_STORAGE_DIR` | *(Để trống)* | Không |

*(Các tích hợp mở rộng như `OPENAI_API_KEY`, `OPENAI_MODEL`, `LIVEKIT_*`, `PASSWORD_RESET_DELIVERY_URL` có thể thêm sau; nếu chưa cấu hình, backend vẫn chạy bình thường và chỉ trả `503 SERVICE_UNAVAILABLE` tại các endpoint tương ứng).*

### Bước 2.3: Kiểm tra Backend sau Deploy
Truy cập `https://<ten-service>.onrender.com/api/v1/health`. Kết quả trả về API & PostgreSQL ở trạng thái sẵn sàng là thành công.

---

## 5. Giai đoạn 3 — Triển khai WebAdmin (Cloudflare Pages / Vercel Free)

### Bước 3.1: Tạo Project trên Cloudflare Pages
1. Đăng nhập [Cloudflare Dashboard](https://dash.cloudflare.com/) → **Workers & Pages → Create → Pages → Connect to Git**.
2. Chọn repository `MetaGym` và nhánh deploy.
3. Cấu hình build:
   - **Root directory (Path):** `admin-web`
   - **Build command:** `npm run build`
   - **Build output directory:** `dist`

### Bước 3.2: Cấu hình Biến môi trường Build
Trong phần **Environment variables** (Production):
- `VITE_API_BASE_URL` = `https://<ten-service>.onrender.com/api/v1`

*(Biến này được đọc trực tiếp tại `admin-web/src/main.js` lúc Vite build).*

### Bước 3.3: Đồng bộ lại CORS trên Render
1. Sau khi Cloudflare Pages cấp URL (ví dụ `https://metagym-admin.pages.dev`), quay lại **Render → Environment**.
2. Cập nhật `CORS_ALLOWED_ORIGINS` đúng bằng URL đó (không có dấu `/` ở cuối; nếu có nhiều domain thì ngăn cách bằng dấu phẩy `,`).
3. Nhấn **Save Changes** để Render khởi động lại backend với cấu hình CORS mới.

---

## 6. Giai đoạn 4 — Kết nối Mobile App & Kiểm thử đầu-cuối

### 6.1. Kiểm thử WebAdmin
1. Mở URL WebAdmin (`https://metagym-admin.pages.dev`).
2. Đăng nhập bằng tài khoản Admin đã seed ở Bước 1.3.
3. Mở DevTools → Network để xác nhận các request tới `onrender.com/api/v1/...` trả `200 OK`, không bị lỗi CORS.

### 6.2. Chạy Mobile App (Flutter) kết nối Cloud Backend
```powershell
cd mobile-app
flutter run --release `
  --dart-define=APP_ENV=production `
  --dart-define=API_BASE_URL=https://<ten-service>.onrender.com/api/v1
```

---

## 7. Quy trình cập nhật code về sau (CI/CD thủ công)
Mỗi lần phát triển thêm tính năng ở local và muốn cập nhật lên bản Cloud:
1. Nếu có **file migration mới** trong `database/migrations/`, chạy file `.up.sql` mới đó lên Supabase trước bằng `psql`.
2. Kiểm tra local:
   - `cd backend && npm run check && npm test`
   - `cd admin-web && npm run build`
3. Merge code vào nhánh deploy và `git push`.
4. Render và Cloudflare Pages sẽ tự động build lại bản mới.
