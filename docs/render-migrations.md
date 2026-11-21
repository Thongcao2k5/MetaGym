# Tự động migration khi deploy Render

Workflow `.github/workflows/render-migrations.yml` kiểm tra thay đổi trong
`database/`, `backend/` trên PR và push `main`. PR chỉ kiểm thử. Push `main`
hoặc chạy thủ công trên `main` sẽ gọi deploy hook **sau khi kiểm tra thành công**.
Hook deploy đúng commit đã kiểm tra. Job thành công nghĩa là Render đã nhận
yêu cầu, chưa khẳng định deploy/migration đã hoàn thành: kiểm tra Render Deploys.

Database production chỉ được truy cập từ Render. Actions dùng PostgreSQL 17
tạm, chạy toàn bộ migration hai lần và chạy `database/tests/schema_assertions.sql`.

## Cấu hình service metagym-api hiện có

Trong Render → Settings:

| Mục | Giá trị |
| --- | --- |
| Branch | `main` |
| Root Directory | để trống (gốc repo) |
| Build Command | `npm ci --prefix backend` |
| Start Command | `npm run start:render --prefix backend` |
| Auto-Deploy | `Off` (Actions gọi hook sau kiểm tra) |
| Health Check Path | `/api/v1/health` |

Không giữ Root Directory là `backend`: Render không cung cấp các file ngoài
root directory, trong khi migration nằm ở `database/migrations`.
Render Free không có pre-deploy command; `start:render` chạy migration xong
mới khởi động API, và dừng nếu migration lỗi. Mỗi lần thức dậy/restart cũng
kiểm tra lịch sử, chỉ áp dụng file chưa chạy. Giữ các migration tương thích
với API cũ vì phiên bản cũ có thể còn phục vụ trong lúc deploy.

Giữ nguyên các biến môi trường backend hiện có trên Render, gồm `DATABASE_URL`.
Không thêm database production vào GitHub Secrets.

GitHub → repo Settings → Secrets and variables → Actions → New repository secret:

- Name: `RENDER_DEPLOY_HOOK_URL`
- Secret: giá trị Deploy Hook của **metagym-api**, lấy ở Render → Settings.

Không commit hoặc chia sẻ hook URL; URL cho phép người sở hữu kích hoạt deploy.
Không tạo service mới bằng Blueprint cho thiết lập này.

## Khởi tạo lịch sử cho database đã có dữ liệu (một lần)

Repo trước đây chạy SQL thủ công và chưa ghi lịch sử. **Không đoán mốc baseline**
từ commit đang deploy, số bảng hay health `200`. Kiểm tra lịch sử thực thi SQL,
đối chiếu các thay đổi schema/dữ liệu và sao lưu database trước.

Trên máy tin cậy, tại gốc repo, cung cấp `DATABASE_URL` bằng biến môi trường riêng
(không dán vào file theo dõi bởi Git). Sau khi xác nhận đã chạy liên tục đến
migration `NNNN`, chạy:

```powershell
npm ci --prefix backend
# Ví dụ CHỈ khi đã xác nhận database chạy hết 0001–0023:
npm run db:migrate --prefix backend -- --baseline=0023
# Baseline chỉ ghi lịch sử, KHÔNG chạy migration SQL.
npm run db:migrate --prefix backend
psql -X $env:DATABASE_URL -v ON_ERROR_STOP=1 -f database/tests/schema_assertions.sql
```

Database mới hoàn toàn: bỏ lệnh baseline, chạy `db:migrate` trực tiếp.
Runner từ chối database đã có bảng nhưng chưa có lịch sử để tránh chạy lại SQL.
Runner cũng từ chối baseline khi đã có lịch sử. Không để lệnh baseline trong
Start Command định kỳ. Baseline không tự kiểm chứng trạng thái schema.

Lịch sử nằm tại `metagym_ops.schema_migrations` (schema riêng để không thay đổi
số bảng `public`). Mỗi file có SHA-256, chuẩn hóa CRLF/LF. Không sửa/xóa/đổi tên
file đã chạy, không chèn migration cũ: tạo số mới lớn hơn phiên bản đã áp dụng.
SQL và bản ghi lịch sử commit trong cùng transaction; lỗi sẽ rollback file đó.
Các file đã thành công trước file lỗi vẫn được giữ; sửa lỗi bằng migration mới
hoặc khôi phục backup theo kế hoạch, không tự chạy toàn bộ `.down.sql`.

## Migration mới

1. Thêm cặp `NNNN_name.up.sql` / `NNNN_name.down.sql` sau số cuối hiện có.
   Dùng SQL chạy trong transaction; nếu dùng wrapper thì đặt `BEGIN;` đầu file
   và `COMMIT;` cuối file như các migration hiện tại. Không dùng transaction
   control ở giữa hoặc `CREATE INDEX CONCURRENTLY` trong runner này.
2. Cập nhật schema assertions nếu schema thay đổi, mở PR và kiểm tra Actions.
3. Merge `main`: Actions kiểm tra rồi gọi Render; xem log `Applying ...` và
   `Database ready` ở Render, sau đó kiểm tra health.

Supabase backend-only: khi tạo object mới, tiếp tục áp dụng chính sách thu hồi
quyền public/anon/authenticated theo tài liệu triển khai và thiết lập default
privileges cho đúng role tạo object. Runner không tự đổi quyền các bảng nghiệp vụ.

Tài liệu chính thức: [Deploy hooks](https://render.com/docs/deploy-hooks),
[Root directory](https://render.com/docs/monorepo-support#setting-a-root-directory),
[Build pipeline](https://render.com/docs/build-pipeline).

## Hiểu luồng thực thi

```text
Bạn thêm migration rồi push/merge main
  → GitHub Actions tạo PostgreSQL 17 tạm trên runner
  → npm ci, kiểm tra cú pháp và chạy bộ test sẵn có của backend
  → Chạy 0001 đến migration mới nhất trên database tạm
  → Chạy lần hai: phải báo 0 migration mới
  → Kiểm tra schema_assertions.sql
  → Nếu tất cả đạt: gọi Deploy Hook với SHA của commit đã kiểm tra
  → Render lấy đúng commit, cài dependency
  → start:render kết nối DATABASE_URL của Render
  → Lấy khóa để không có hai tiến trình migrate cùng lúc
  → Đọc metagym_ops.schema_migrations và đối chiếu checksum
  → Chạy từng file mới, ghi lịch sử trong cùng transaction
  → Chạy API, Render kiểm tra /api/v1/health
```

Database tạm bị xóa khi job kết thúc. Không có database test chạy lâu dài và
không thêm endpoint test vào API. Bộ test riêng cho runner đã được dùng để xác
minh triển khai rồi bỏ khỏi thay đổi theo yêu cầu; giữ bộ test hiện hữu của đồ án.

## Các bước tự thiết lập lại từ đầu

1. Trong repo đồ án, kiểm tra đã có `backend/scripts/migrate.js`, hai script
   `db:migrate` / `start:render` trong `backend/package.json` và file workflow.
2. Chạy `npm ci --prefix backend`. Database mới có thể dùng `db:migrate` ngay;
   database cũ cần sao lưu và xác nhận baseline theo phần phía trên trước.
3. Vào Render → service `metagym-api` → Settings, điền đủ các mục trong bảng
   cấu hình. Khi đổi Root Directory, modal Verify Settings sẽ xuất hiện: sửa
   cả Build Command và Start Command theo bảng rồi bấm Update Fields.
4. Giữ `DATABASE_URL`, `JWT_SECRET` và các cấu hình backend trong Render →
   Environment. Root Directory đổi không cần chuyển các secret sang GitHub.
5. Ở Render → Settings → Deploy Hook, copy URL. Sang repo GitHub → Settings →
   Secrets and variables → Actions → New repository secret; nhập tên
   `RENDER_DEPLOY_HOOK_URL`, dán URL vào Secret và bấm Add secret.
6. Push/merge thay đổi vào `main`. Trên GitHub mở Actions →
   **Database migrations and Render deploy** → chọn run mới nhất.
7. Nếu cần chạy lại mà không sửa code: ở trang workflow chọn **Run workflow**,
   chọn nhánh `main`, rồi bấm nút chạy. Nút này xuất hiện sau khi workflow đã
   có trên nhánh mặc định. Chạy trên nhánh khác chỉ kiểm thử, không deploy.
8. Sau khi job **Request Render deploy** xanh, sang Render → Deploys → mở
   deployment mới. Chờ trạng thái Live và xem log migration/API.

## Cách thêm migration tiếp theo (ví dụ 0032)

Tại gốc repo, tạo `database/migrations/0032_ten_thay_doi.up.sql`:

```sql
BEGIN;
-- Đặt ALTER TABLE / CREATE TABLE thật của tính năng tại đây.
COMMIT;
```

Tạo file rollback `0032_ten_thay_doi.down.sql` tương ứng. Ví dụ trên chỉ là khung,
không tạo/commit file rỗng. Không chỉnh sửa file `0001`–`0031` đã được ghi lịch sử.
Cập nhật schema assertions nếu thay đổi số bảng/constraint được kiểm tra.

Sau đó chạy trên database development của bạn:

```powershell
# DATABASE_URL trỏ đến database development riêng, đã đặt bằng cấu hình kín.
npm run db:migrate --prefix backend
npm run db:migrate --prefix backend
psql -X $env:DATABASE_URL -v ON_ERROR_STOP=1 -f database/tests/schema_assertions.sql
git diff --check
git add database/migrations database/tests/schema_assertions.sql
git commit -m "feat: add migration for the new feature"
git push
```

Nếu làm ở nhánh tính năng thì tạo PR vào `main`, đợi check xanh rồi merge.
Actions tự chạy khi đường dẫn liên quan thay đổi; không cần bấm Run workflow
mỗi lần. Thay đổi chỉ ở mobile/frontend không kích hoạt workflow backend này.

## Đọc kết quả và xử lý lỗi

| Dấu hiệu | Ý nghĩa / cách làm |
| --- | --- |
| `Applying 0032_...up.sql` | Render đang áp dụng file chưa có trong lịch sử. |
| `Database ready: 0 migration(s) applied.` | Schema đã theo kịp các file, không chạy lại SQL cũ. |
| Job check đỏ | Render chưa được workflow này gọi. Mở step lỗi, sửa rồi push commit mới. |
| Thiếu `RENDER_DEPLOY_HOOK_URL` | Thêm secret đúng repo, sau đó chạy lại workflow trên main. |
| `Existing database has no migration history` | Chưa khởi tạo baseline; xác nhận mốc thật trước khi dùng `--baseline`. |
| `Migration checksum changed` | File đã chạy bị sửa; khôi phục đúng nội dung gốc và tạo migration mới. |
| `Migration failed: ... (PostgreSQL ...)` | File đó đã rollback. Xem mã lỗi, kiểm tra schema/dữ liệu; không xóa lịch sử hoặc chạy lại cả thư mục thủ công. |
| Actions xanh, Render chưa Live | Actions chỉ xác nhận gửi yêu cầu; mở Render Deploys để xem build/start/migration. |
| Health 200 | API kết nối được database; đối chiếu lịch sử migration để xác nhận đúng phiên bản schema. |

Kiểm tra lịch sử bằng Supabase SQL Editor hoặc `psql`:

```sql
SELECT name, applied_at
FROM metagym_ops.schema_migrations
ORDER BY name;
```

Không chạy file `.down.sql` thủ công trong khi giữ nguyên lịch sử: runner sẽ hiểu
file up vẫn đã áp dụng. Khi có sự cố production, xác định file đã commit và phục
hồi backup theo kế hoạch hoặc viết migration sửa tiếp; không xóa bảng lịch sử.

## Nhật ký tích hợp thực tế — 21/11/2026

1. Kiểm tra repo `main`: có migration `0001`–`0031`, chưa có migration runner
   hoặc lịch sử database. Service Render Free dùng Root Directory `backend`.
2. Đọc schema Supabase và chạy schema assertions của bản cũ: xác nhận mốc
   `0023`, không có dấu vết schema của `0024`–`0031`.
3. Sao lưu schema `public` và dữ liệu ứng dụng bằng `pg_dump --format=custom`.
   Đây là backup phần ứng dụng, không bao gồm Supabase Auth/Storage.
4. Kiểm thử runner trên PostgreSQL 17 tạm: chạy đồng thời, rollback khi lỗi,
   checksum, baseline và thứ tự migration. Chạy đủ 31 file rồi chạy lại được 0
   file; schema assertions đạt. Khôi phục backup production vào database tạm
   và nâng từ `0023` lên `0031` cũng đạt.
5. Ghi baseline `0023` trên database thật, không chạy lại SQL cũ. Thu hồi default
   privileges cho object public mới của role tạo migration theo mô hình chỉ
   backend truy cập database.
6. Tạo workflow, runner và tài liệu. Kiểm thử Actions trên PR thành công.
   Bỏ file test runner mới theo yêu cầu; giữ test và schema checks sẵn có.
7. Với sự cho phép của chủ repo, lưu Deploy Hook vào secret
   `RENDER_DEPLOY_HOOK_URL`. Đổi Root Directory về gốc repo và lưu các lệnh
   build/start, Auto-Deploy Off và health check như bảng phía trên.
8. Merge [PR #15](https://github.com/Thongcao2k5/MetaGym/pull/15) thành commit
   `d5d7b6a`. [Workflow main đầu tiên](https://github.com/Thongcao2k5/MetaGym/actions/runs/44902511102)
   kiểm tra đạt và gọi Deploy Hook thành công.
9. Render deploy đúng commit: log ghi `Database ready: 8 migration(s) applied.`;
   trạng thái **Deploy succeeded | Live**. Truy vấn database xác nhận 31 bản
   ghi lịch sử, mới nhất `0031`; schema assertions đạt; health trả HTTP 200.
   Bảng mới vẫn không cho role `anon` / `authenticated` đọc trực tiếp.
10. Tích hợp cùng cấu hình vào repo đồ án local `F:\AndroidProjects\MetaGym`
    trên nhánh `thong`, không đưa các tính năng đang phát triển khác lên main.
    File test runner mới đã bỏ khỏi thay đổi cuối; môi trường PostgreSQL tạm
    đã dừng. Bộ duyệt tự động từ chối lệnh xóa thư mục tạm và file environment
    tải xuống (`blocked by policy`), nên hai mục này cần chủ máy dọn thủ công.
    Giữ backup để phục hồi khi cần.

**Mốc production sau thiết lập là `0031`.** Migration ở nhánh khác (ví dụ `0032`
trong repo local) chỉ lên production sau khi PR/merge vào `main` và workflow đạt.
Các lệnh baseline trong hướng dẫn là để thiết lập một database cũ khác; không
chạy lại baseline trên database production đã được ghi lịch sử này.

### Dọn thủ công phần tạm còn lại

Hai đường dẫn dưới đây được tạo riêng cho lần thiết lập này, không phải repo
đồ án `F:\AndroidProjects\MetaGym`. Đóng tiến trình đang dùng chúng rồi xóa bằng
File Explorer hoặc chạy PowerShell:

```powershell
Remove-Item -LiteralPath 'C:\Users\thong\OneDrive\Đính kèm\Documents\ChatGPT\Meta Gym\.tmp\metagym-render-migrations' -Recurse -Force
Remove-Item -LiteralPath 'C:\Users\thong\Downloads\metagym-api.env' -Force
```

File `.env` tải xuống chứa cấu hình kín, không chia sẻ hoặc commit. Backup hợp
lệ được giữ tại `C:\Users\thong\AppData\Local\MetaGym\backups\before-automated-migrations-1795262696183.dump`
(195.081 byte); bản dump dung lượng 0 cùng thư mục là lần sao lưu không thành công,
không dùng để phục hồi.
