# Meta Gym Database

PostgreSQL schema cho MVP Meta Gym gồm 38 bảng nghiệp vụ và 2 bảng vận hành
cho giới hạn đăng nhập/khôi phục mật khẩu. Migration được chia theo thứ tự phụ
thuộc và có file rollback tương ứng.

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
7. `0007_password_reset_limits.up.sql`
8. `0008_member_journal.up.sql`
9. `0009_direct_conversations.up.sql`
10. `0010_coach_package_catalog.up.sql`
11. `0011_coach_weekly_schedule.up.sql`
12. `0012_coach_payment_holds.up.sql`

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

## Demo seed (chỉ development/test)

Sau khi chạy migration và baseline seed, có thể tạo bộ dữ liệu demo riêng:

```powershell
psql $env:DATABASE_URL -v ON_ERROR_STOP=1 `
  -v demo_seed_environment='development' `
  -f database/seeds/0002_demo.sql
```

Seed này dùng UUID cố định và upsert nên có thể chạy lặp mà không tạo bản ghi
trùng. Seed sẽ đặt lại tài khoản Admin hiện có và tạo một Coach, một Member,
một gói tập, một thiết bị và một bài tập mẫu.

| Vai trò | Email | Mật khẩu |
|---|---|---|
| Admin | `admin@metagym.local` | `MetaGymAdmin!2026` |
| Coach | `coach@metagym.local` | `MetaGymCoach!2026` |
| Member | `member@metagym.local` | `MetaGymMember!2026` |

Các thông tin trên chỉ dành cho local/test demo, không được dùng ở production.
File seed chỉ chứa bcrypt hash; không chứa khóa API hoặc thông tin production.
Seed từ chối chạy nếu không truyền `demo_seed_environment` bằng `development`
hoặc `test`.

Kiểm tra riêng dữ liệu demo:

```powershell
psql $env:DATABASE_URL -v ON_ERROR_STOP=1 `
  -f database/tests/demo_seed_assertions.sql
```

## Kiểm tra schema

Sau migration, chạy:

```powershell
psql $env:DATABASE_URL -v ON_ERROR_STOP=1 -f database/tests/schema_assertions.sql
```

Kiểm tra xác nhận đủ 33 bảng nghiệp vụ và 2 bảng vận hành giới hạn đăng
nhập/khôi phục mật khẩu, các FK sở hữu quan trọng, constraint chỉ cho phép tối
đa một Admin và constraint chống chồng ngày membership. Sự tồn tại của Admin
và `gym_profile` được kiểm tra khi chạy baseline seed.

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
