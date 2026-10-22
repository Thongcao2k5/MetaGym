# Meta Gym Database

PostgreSQL schema cho MVP Meta Gym gồm 33 bảng nghiệp vụ và 1 bảng vận hành cho giới hạn đăng nhập. Migration được chia theo thứ tự phụ thuộc và có file rollback tương ứng.

## Yêu cầu

- PostgreSQL 17 hoặc phiên bản tương thích.
- Quyền tạo extension `citext` và `btree_gist`.
- Một database trống.

## Thứ tự migration

Chạy các file `*.up.sql` theo thứ tự:

1. `0001_foundation.up.sql`
2. `0002_coaching_and_content.up.sql`
3. `0003_training_and_nutrition.up.sql`
4. `0004_progress_tracking.up.sql`
5. `0005_communication_ai_audit.up.sql`
6. `0006_auth_rate_limits.up.sql`

Ví dụ với PowerShell và `psql`:

```powershell
$env:DATABASE_URL = 'postgresql://postgres:password@localhost:5432/meta_gym'
Get-ChildItem database/migrations/*.up.sql |
  Sort-Object Name |
  ForEach-Object { psql $env:DATABASE_URL -v ON_ERROR_STOP=1 -f $_.FullName }
```

Rollback chạy các file `*.down.sql` theo thứ tự ngược lại.

## Baseline seed

Baseline chỉ tạo một Admin và `gym_profile` có dữ liệu hợp lệ. Không chứa Member, Coach, gói tập hoặc dữ liệu demo.

```powershell
psql $env:DATABASE_URL -v ON_ERROR_STOP=1 `
  -v admin_id='00000000-0000-4000-8000-000000000001' `
  -v admin_email='admin@example.com' `
  -v admin_password_hash='<bcrypt-hash>' `
  -v admin_full_name='Meta Gym Admin' `
  -v gym_name='Meta Gym' `
  -v gym_address='Địa chỉ phòng gym' `
  -f database/seeds/0001_baseline.sql
```

Không đưa mật khẩu gốc vào câu lệnh hoặc file seed. `admin_password_hash` phải là hash bcrypt được tạo bên ngoài database.

## Kiểm tra schema

Sau migration, chạy:

```powershell
psql $env:DATABASE_URL -v ON_ERROR_STOP=1 -f database/tests/schema_assertions.sql
```

Kiểm tra xác nhận đủ 33 bảng nghiệp vụ và bảng vận hành giới hạn đăng nhập, các FK sở hữu quan trọng, constraint chỉ cho phép tối đa một Admin và constraint chống chồng ngày membership. Sự tồn tại của Admin và `gym_profile` được kiểm tra khi chạy baseline seed.

## Quy tắc nằm ở backend

PostgreSQL bảo vệ cấu trúc, ownership tĩnh, trạng thái của từng dòng và uniqueness. Những quy tắc động sau phải được kiểm tra trong transaction tại Node.js:

- Vai trò thực tế của Member, Coach và Admin.
- Payment phải `SUCCESS` trước khi tạo membership.
- Xác nhận `MOCK_QR`, tạo membership và kích hoạt quyền là một transaction idempotent.
- Giới hạn Coach và việc `ACTIVE`/`PAUSED` cùng chiếm suất.
- Quyền đọc dữ liệu theo trạng thái quan hệ.
- Media phải `READY`, đúng `purpose` và `access_scope` trước khi gắn.
- Giáo trình đã công bố và progress đã có nhận xét không được sửa.
- Participant chat phải đúng hai người của relationship; read cursor không được lùi.
- Caller/receiver phải đúng cặp Member–Coach.
- AI reply phải trỏ tới tin `USER`; cập nhật timeout/provider response dùng conditional update.
