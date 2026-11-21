# Triển khai MetaGym lên Supabase, Cloudflare Pages và Render

Tài liệu thực hành cho người muốn triển khai nhánh `main` của [Thongcao2k5/MetaGym](https://github.com/Thongcao2k5/MetaGym). Ghi lại quy trình đã làm ngày 21/11/2026 và các lỗi thực tế đã gặp. Làm theo thứ tự: **Supabase → Cloudflare Pages → Render → nối web với API → kiểm tra đăng nhập**.

> Không sao chép mật khẩu, `DATABASE_URL`, `JWT_SECRET` hoặc `sb_secret_...` từ một người khác. Mỗi người tự tạo giá trị cho project của mình. Những giá trị trong dấu `<...>` dưới đây là chỗ cần thay, không gõ cả dấu `<` và `>`.

## 0. Chuẩn bị

1. Có tài khoản GitHub, Supabase, Cloudflare và Render; kết nối GitHub với Cloudflare/Render khi được hỏi.
2. Cài Node.js **22 trở lên**, Git và PostgreSQL client `psql`; kiểm tra trong PowerShell bằng `node --version`, `git --version`, `psql --version`.
3. Clone nhánh `main` vào một thư mục riêng nếu chưa có repo. Các lệnh ở phần database chạy tại **thư mục gốc repo**, nơi có `database/` và `backend/`.
4. Kiểm tra nhanh repo bằng `git status` và `git branch --show-current`. Không lấy các file migration từ nhánh khác rồi trộn vào `main`.

```powershell
git clone --branch main https://github.com/Thongcao2k5/MetaGym.git MetaGym-deploy-main
Set-Location '.\MetaGym-deploy-main'
git status --short
git branch --show-current
```

Nếu đã clone, bỏ dòng `git clone` và `Set-Location` tới thư mục repo hiện có. Trong các lệnh sau, thay `<DUONG_DAN_THU_MUC_GOC_REPO>` bằng **đường dẫn tuyệt đối** của thư mục này.

## 1. Tạo database và Storage trên Supabase

### 1.1. Tạo project, lấy thông số kết nối

1. Vào [Supabase Dashboard](https://supabase.com/dashboard) → **New project**. Ghi nhớ **Database password** của project.
2. Mở project → bấm **Connect** ở phía trên → chọn **Session pooler**. Chọn URI, cổng **5432**. Ghi lại `Host` và `User` đúng như Supabase hiển thị. User của pooler có dạng `postgres.<project-ref>`; host có dạng `aws-...pooler.supabase.com`. **Không tự đoán host theo region.**
3. Trong **Project Settings → API Keys**, ghi lại **Project URL** dạng `https://<project-ref>.supabase.co`. Khóa Storage sẽ lấy sau ở bước 1.5.

Ví dụ cấu trúc URL (không phải giá trị dùng chung):

```text
postgresql://postgres.<project-ref>:<database-password>@<pooler-host>:5432/postgres
```

Nếu mật khẩu chứa `@`, `#`, `%`, `:` hoặc ký tự đặc biệt khác, phải mã hóa phần mật khẩu khi đặt trong URL. PowerShell có thể dùng `[uri]::EscapeDataString($password)`.

### 1.2. Kết nối bằng `psql` trước khi chạy migration

Mở PowerShell ở đâu cũng được, rồi chuyển vào **thư mục gốc repo**. Thay `PGHOST` và `PGUSER` bằng giá trị trong **Connect → Session pooler**. `PGPASSWORD` là **Database password của Supabase**, không phải mật khẩu đăng nhập Admin của MetaGym.

```powershell
Set-Location '<DUONG_DAN_THU_MUC_GOC_REPO>'
$env:PGHOST = '<pooler-host-khong-co-dau-ngoac>'
$env:PGUSER = 'postgres.<project-ref>'
$env:PGPASSWORD = [System.Net.NetworkCredential]::new('', (Read-Host 'Supabase Database password' -AsSecureString)).Password
$env:PGSSLMODE = 'require'

if (-not $env:PGHOST -or -not $env:PGUSER) { throw 'Thieu PGHOST hoac PGUSER' }
& psql -X -h $env:PGHOST -p 5432 -U $env:PGUSER -d postgres -v ON_ERROR_STOP=1 -c 'SELECT 1;'
if ($LASTEXITCODE -ne 0) { throw 'Khong ket noi duoc database; dung tai day' }
```

Kết quả cần có một dòng `1`. Nếu gặp `could not translate host name "<aws-...>"`, bạn đã dán cả dấu `< >` vào `PGHOST`. Nếu `could not translate host name "-p"`, `$env:PGHOST` đang rỗng. Sửa hai biến rồi thử lại, **chưa chạy migration**.

### 1.3. Chạy migration của đúng nhánh `main`

Chỉ làm vòng lặp này trên **database mới, chưa có bảng**. Lấy toàn bộ `*.up.sql` của bản `main` đang triển khai và chạy theo tên file tăng dần. Dừng ngay khi một file lỗi.

```powershell
Get-ChildItem '.\database\migrations' -Filter '*.up.sql' |
  Sort-Object Name |
  ForEach-Object {
    Write-Host "Running $($_.Name)"
    & psql -X -h $env:PGHOST -p 5432 -U $env:PGUSER -d postgres -v ON_ERROR_STOP=1 -f $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "Migration failed: $($_.Name)" }
  }

& psql -X -h $env:PGHOST -p 5432 -U $env:PGUSER -d postgres -v ON_ERROR_STOP=1 -f '.\database\tests\schema_assertions.sql'
if ($LASTEXITCODE -ne 0) { throw 'Schema assertions failed' }
```

Có thể kiểm tra thêm trên Supabase **SQL Editor**:

```sql
SELECT count(*) AS public_tables
FROM pg_tables
WHERE schemaname = 'public';
```

Tại thời điểm ghi tài liệu, nhánh `main` có migration `0001` đến `0027` và `schema_assertions.sql` của chính nhánh này kiểm tra **50 bảng**. Con số này có thể thay đổi khi repo được cập nhật; luôn tin file assertion đi cùng commit đang deploy. **Không chạy lại migration cũ** trên database đã có dữ liệu. Khi repo thêm migration, sao lưu database rồi chỉ chạy các file mới theo thứ tự.

### 1.4. Chặn truy cập trực tiếp qua khóa public của Supabase

Backend MetaGym dùng kết nối PostgreSQL riêng. Sau khi chạy **tất cả** migration, chạy trên Supabase **SQL Editor**:

```sql
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon, authenticated;
```

Kiểm tra:

```sql
SELECT
  has_table_privilege('anon', 'public.users', 'SELECT') AS anon_can_read_users,
  has_table_privilege('authenticated', 'public.users', 'SELECT') AS auth_can_read_users;
```

Cả hai cột phải là `false`. Sau migration mới tạo bảng, sequence hoặc function, kiểm tra lại quyền truy cập các object mới.

### 1.5. Tạo bucket ảnh

Trong Supabase → **Storage → New bucket**, đặt tên `meta-gym-media`, chọn **Private**. Nếu muốn theo kế hoạch ban đầu, giới hạn mỗi file 5 MB và MIME `image/jpeg`, `image/png`.

Trong **Project Settings → API Keys**, tạo/lấy **Secret key** bắt đầu bằng `sb_secret_...` để dùng **chỉ ở backend Render**. `sb_publishable_...` là khóa public, không thay thế được `SUPABASE_SECRET_KEY` cho Storage của backend.

### 1.6. Tạo tài khoản Admin và hồ sơ phòng gym ban đầu

Làm **một lần** trên database mới. Schema chỉ cho phép **một** tài khoản có role `ADMIN`. Tại thư mục gốc repo, nhập email Admin, địa chỉ và mật khẩu Admin mới. Lệnh tạo bcrypt hash cần chạy trong `backend/` vì package `bcryptjs` nằm ở đó.

```powershell
Set-Location '<DUONG_DAN_THU_MUC_GOC_REPO>\backend'
npm ci
$adminEmail = Read-Host 'Email Admin'
$gymAddress = Read-Host 'Dia chi phong gym (nen nhap ASCII lan dau tren Windows)'
$env:ADMIN_SEED_PASSWORD = [System.Net.NetworkCredential]::new('', (Read-Host 'Mat khau Admin moi' -AsSecureString)).Password
try {
  $adminHash = & node --input-type=module -e 'import bcrypt from "bcryptjs"; process.stdout.write(await bcrypt.hash(process.env.ADMIN_SEED_PASSWORD, 12))'
  if ($LASTEXITCODE -ne 0) { throw 'Khong tao duoc password hash' }
} finally {
  Remove-Item Env:\ADMIN_SEED_PASSWORD -ErrorAction SilentlyContinue
}

Set-Location ..
$adminId = [guid]::NewGuid().ToString()
& psql -X -h $env:PGHOST -p 5432 -U $env:PGUSER -d postgres -v ON_ERROR_STOP=1 -v "admin_id=$adminId" -v "admin_email=$adminEmail" -v "admin_password_hash=$adminHash" -v "admin_full_name=Meta Gym Admin" -v "gym_name=Meta Gym" -v "gym_address=$gymAddress" -f '.\database\seeds\0001_baseline.sql'
if ($LASTEXITCODE -ne 0) { throw 'Seed Admin that bai' }
```

Dòng `psql` cuối được cố ý viết **trên một dòng**: trong PowerShell, dấu xuống dòng/backtick sai có thể khiến `-p` bị hiểu là host. Kết quả seed thành công có `BEGIN`, `INSERT`, `COMMIT` và bước kiểm tra cuối không lỗi. Nếu Windows báo `invalid multibyte character` tại `gym_address`, dùng địa chỉ ASCII tạm rồi cập nhật địa chỉ thật trong **Supabase → Table Editor → gym_profile**; không chạy lại seed nếu giao dịch trước đã commit. Mật khẩu Admin khác Database password.

Kết thúc phần lệnh database thì xóa biến mật khẩu khỏi PowerShell:

```powershell
Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
```

Xác nhận có đúng một Admin trong Supabase **SQL Editor**:

```sql
SELECT email, role, status FROM public.users WHERE role = 'ADMIN';
```

## 2. Tạo web admin đúng loại trên Cloudflare Pages

1. Vào [Cloudflare Dashboard](https://dash.cloudflare.com/) → **Workers & Pages → Create application**. Chọn **Pages**. Nếu giao diện dẫn vào luồng tạo **Worker**, bấm **Continue to Pages** ở dòng “Need to use the legacy Pages workflow?”. Đừng triển khai repo `admin-web/` như một Worker trống.
2. Chọn **Import an existing Git repository → GitHub → Thongcao2k5/MetaGym**.
3. Điền: **Project name** `metagym-admin` (hoặc tên chưa bị dùng), **Production branch** `main`, **Framework preset** `None`, **Build command** `npm run build`, **Build output directory** `dist`, **Root directory / Path** `admin-web`.
4. Bấm **Save and Deploy**. Ghi lại URL Pages được cấp, ví dụ `https://metagym-admin.pages.dev`.

Lúc này trang web có thể mở được nhưng **chưa đăng nhập được**, vì Vite chưa biết URL API. Biến nối API được thêm ở bước 4 sau khi Render có URL thật.

## 3. Tạo backend trên Render

### 3.1. Web Service

Vào [Render Dashboard](https://dashboard.render.com/) → **New + → Web Service** → chọn repo `Thongcao2k5/MetaGym`. Cấu hình:

| Trường | Giá trị |
|---|---|
| Name | `metagym-api` hoặc tên chưa bị dùng |
| Language | Node |
| Branch | `main` |
| Region | Singapore nếu có lựa chọn này |
| Root Directory | `backend` |
| Build Command | `npm ci` |
| Start Command | `npm start` |
| Compute | **Free / $0**; kiểm tra kỹ vì mặc định có thể là gói trả phí |
| Health Check Path | `/api/v1/health` nếu màn hình có ô này |

### 3.2. Environment Variables

Trong Render → service **metagym-api → Environment**, thêm từng **KEY / VALUE**. Nếu đang ở trang **Settings**, bấm **Environment trong thanh trái, dưới MANAGE**; dòng “← Environment” phía trên là breadcrumb của project, không phải mục biến môi trường của service.

| KEY | VALUE |
|---|---|
| `NODE_ENV` | `production` |
| `DATABASE_URL` | URI **Session pooler** của Supabase, có mật khẩu database đã mã hóa URL nếu cần |
| `JWT_SECRET` | Chuỗi ngẫu nhiên ít nhất 32 ký tự, chỉ dùng cho backend |
| `CORS_ALLOWED_ORIGINS` | URL Pages chính xác, ví dụ `https://metagym-admin.pages.dev` (không `/` cuối) |
| `SUPABASE_URL` | Project URL `https://<project-ref>.supabase.co` |
| `SUPABASE_SECRET_KEY` | Secret API key bắt đầu `sb_secret_...` |
| `SUPABASE_STORAGE_BUCKET` | `meta-gym-media` |

Ô VALUE của `DATABASE_URL` chỉ chứa URL; **không** thêm `DATABASE_URL=`, dấu ngoặc kép hoặc dấu `< >`. Không đặt `MEDIA_STORAGE_DIR` trên Render Free vì ổ đĩa cục bộ không bền sau redeploy/sleep. Không đặt `JWT_SECRET`, database password hay Supabase secret key ở Cloudflare Pages.

#### Lỗi SSL mà chúng tôi đã gặp

Với bản `pg` của dự án, URL kết thúc bằng `?sslmode=require` đã làm kết nối Node báo `SELF_SIGNED_CERT_IN_CHAIN`, khiến `/api/v1/health` trả `503 DATABASE_UNAVAILABLE`. Chúng tôi đã thử trực tiếp và `SELECT 1` thành công khi thay phần cuối URI bằng:

```text
?uselibpqcompat=true&sslmode=require
```

Giữ nguyên phần host/user/password/port của URI Supabase, chỉ thay **phần query** như trên. Kết nối vẫn mã hóa TLS, nhưng cách tương thích `libpq` này không xác minh chứng chỉ máy chủ; về sau có thể cấu hình CA của Supabase để xác minh đầy đủ. Sau khi chỉnh biến trên Render, bấm **Save, rebuild, and deploy**.

Nếu health vẫn `503`, tại Render **Environment** bấm **Copy value** ở dòng `DATABASE_URL`, rồi thử **đúng giá trị đang lưu trên Render** trong PowerShell. Không in hoặc gửi URL đầy đủ:

```powershell
$env:TEST_DATABASE_URL = (Get-Clipboard -Raw).Trim()
Set-Location '<DUONG_DAN_THU_MUC_GOC_REPO>\backend'
node --input-type=module -e 'import pg from "pg"; const db = new pg.Pool({connectionString: process.env.TEST_DATABASE_URL, connectionTimeoutMillis: 10000}); try { await db.query("SELECT 1"); console.log("DB OK"); } catch (e) { console.error("DB ERROR:", e.code, e.message); } finally { await db.end(); }'
Remove-Item Env:\TEST_DATABASE_URL -ErrorAction SilentlyContinue
Set-Clipboard -Value ' '
```

`DB OK` nghĩa là chính URL đó kết nối được từ Node. `ENOTFOUND base` hoặc host lạ nghĩa là ô VALUE không chứa URL đúng; `SELF_SIGNED_CERT_IN_CHAIN` là lỗi SSL nêu trên.

### 3.3. Kiểm tra API

Mở `https://<ten-service>.onrender.com/api/v1/health`. Thành công là HTTP `200` và JSON:

```json
{"data":{"api":"AVAILABLE","database":"AVAILABLE"}}
```

`GET /` hoặc `HEAD /` của API trả `404` là **bình thường**. `/heath` là gõ sai; đường đúng là `/api/v1/health`. Render Free có thể mất thời gian khởi động sau khi ngủ.

Nếu health `503`, kiểm tra trước `DATABASE_URL`/mật khẩu/host/cổng/SSL. Log “Build successful” hoặc “Your service is live” chỉ chứng minh server đã khởi động, **chưa chứng minh database hoạt động**.

## 4. Nối web admin với API

Sau khi health trả `200`:

1. Cloudflare → **Workers & Pages → metagym-admin → Settings**.
2. Chọn môi trường **Production** → **Variables and secrets → Add**.
3. Chọn **Type: Text**, **Variable name:** `VITE_API_BASE_URL`, **Value:** `https://<ten-service>.onrender.com/api/v1`. Ví dụ của lần triển khai này là `https://metagym-api.onrender.com/api/v1`.
4. Bấm **Save**. Vào tab **Deployments**, ở bản Production mới nhất bấm **More actions → Retry deployment**. Biến `VITE_` được Vite chèn vào lúc build, nên chỉ lưu biến mà không build lại thì trang cũ vẫn dùng URL cũ.
5. Chờ trạng thái deployment là **success**; phần **Build settings → Environment variables** phải hiện đúng `VITE_API_BASE_URL`.

## 5. Kiểm tra đăng nhập và xử lý lỗi thường gặp

1. Mở URL Pages, ví dụ [web admin đã triển khai](https://metagym-admin.pages.dev).
2. **Tải lại tab** sau khi vừa deploy mới (`Ctrl+Shift+R`). Chúng tôi từng gặp `HTTP 405` vì tab còn giữ file JavaScript cũ và gửi `POST /api/v1/auth/sessions` vào chính Cloudflare Pages. Sau khi reload, tab tải file JS mới và gửi tới Render.
3. Nhập **email Admin và mật khẩu Admin của bước 1.6**. Thành công là vào dashboard; API `/api/v1/auth/sessions` trả HTTP `200` và role `ADMIN`.
4. Nếu báo `Email hoặc mật khẩu không đúng` (`401`), kiểm tra email/mật khẩu Admin. Không dùng Database password của Supabase để đăng nhập web.
5. Nếu báo CORS, kiểm tra `CORS_ALLOWED_ORIGINS` trên Render đúng **origin** của Pages, và biến `VITE_API_BASE_URL` đã vào **bản build mới nhất**.

Schema chỉ cho phép một `ADMIN`. Khi quên mật khẩu, **đặt lại hash cho Admin hiện có**, không thêm Admin thứ hai. Trong lần triển khai này chúng tôi đã đặt lại mật khẩu Admin hiện có và kiểm tra đăng nhập API trả `200`. Không ghi mật khẩu đó trong tài liệu chia sẻ.

Nếu cần đặt lại mật khẩu Admin trên **database do bạn sở hữu**, lấy `DATABASE_URL` hiện tại từ Render vào clipboard, rồi chạy trong `backend/`. Lệnh này thay mật khẩu của Admin hiện có và tăng `session_version` để phiên cũ hết hiệu lực:

```powershell
Set-Location '<DUONG_DAN_THU_MUC_GOC_REPO>\backend'
$env:TEST_DATABASE_URL = (Get-Clipboard -Raw).Trim()
$env:NEW_ADMIN_PASSWORD = [System.Net.NetworkCredential]::new('', (Read-Host 'Mat khau Admin moi' -AsSecureString)).Password
$script = @'
import pg from 'pg';
import bcrypt from 'bcryptjs';
const pool = new pg.Pool({ connectionString: process.env.TEST_DATABASE_URL });
try {
  const hash = await bcrypt.hash(process.env.NEW_ADMIN_PASSWORD, 12);
  const result = await pool.query(
    "UPDATE users SET password_hash = $1, session_version = session_version + 1 WHERE role = 'ADMIN' AND status = 'ACTIVE' RETURNING email::text",
    [hash],
  );
  if (result.rowCount !== 1) throw new Error('Expected exactly one active Admin');
  console.log('Updated Admin:', result.rows[0].email);
} finally {
  await pool.end();
}
'@
try {
  node --input-type=module -e $script
  if ($LASTEXITCODE -ne 0) { throw 'Khong dat lai duoc mat khau Admin' }
} finally {
  Remove-Item Env:\NEW_ADMIN_PASSWORD -ErrorAction SilentlyContinue
  Remove-Item Env:\TEST_DATABASE_URL -ErrorAction SilentlyContinue
  Set-Clipboard -Value ' '
}
```

Sau đó đăng nhập web bằng mật khẩu vừa nhập. Chỉ làm bước này khi đã xác nhận đúng database/project; không dùng script đặt lại mật khẩu của người khác.

## 6. Trạng thái của lần triển khai được ghi lại

| Thành phần | Địa chỉ / trạng thái đã kiểm tra |
|---|---|
| Cloudflare Pages | `https://metagym-admin.pages.dev` — HTTP `200`, bản build chứa URL API |
| Render API | `https://metagym-api.onrender.com` — nhánh `main`, Free, build `npm ci`, start `npm start` |
| API health | `https://metagym-api.onrender.com/api/v1/health` — HTTP `200`, API và database `AVAILABLE` |
| Supabase | Project riêng; bucket `meta-gym-media` Private; baseline Admin đã seed |

**Việc còn cần kiểm tra khi code tiếp tục thay đổi:** lúc database lần đầu được dựng, migration đã chạy đến `0023` và có 50 bảng. Nhánh `main` sau đó có thêm `0024`–`0027`; chưa có bằng chứng các file mới này đã chạy trên database của lần triển khai này. Trước khi dùng tính năng liên quan, sao lưu và áp dụng **chỉ các migration còn thiếu**. Không suy ra rằng health `200` nghĩa là schema đã theo kịp commit mới.

## Tài liệu gốc

- [Supabase: lấy connection string và chọn Session pooler](https://supabase.com/docs/guides/database/connecting-to-postgres)
- [Supabase: phân biệt publishable key và secret key](https://supabase.com/docs/guides/getting-started/api-keys)
- [Cloudflare Pages: build configuration và biến môi trường](https://developers.cloudflare.com/pages/configuration/build-configuration/)
- [Render: Environment Variables](https://render.com/docs/configure-environment-variables)
