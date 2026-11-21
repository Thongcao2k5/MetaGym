# Tự động migration khi deploy Render

Workflow `.github/workflows/render-migrations.yml` kiểm tra thay đổi trong
`database/`, `backend/` trên PR và push `main`. PR chỉ kiểm thử. Push `main`
hoặc chạy thủ công trên `main` sẽ gọi deploy hook **sau khi kiểm tra thành công**.
Hook deploy đúng commit đã kiểm tra. Job thành công nghĩa là Render đã nhận
yêu cầu, chưa khẳng định deploy/migration đã hoàn thành: kiểm tra Render Deploys.

Database production chỉ được truy cập từ Render. Actions dùng PostgreSQL 17
tạm, kiểm tra rollback, lịch sử, baseline, chạy đồng thời, chạy toàn bộ migration
hai lần và chạy `database/tests/schema_assertions.sql`.

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
