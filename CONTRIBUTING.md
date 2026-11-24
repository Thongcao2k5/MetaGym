# Quy trình Git & Đóng góp cho MetaGym (Team 3 người)

Tài liệu này quy định cấu trúc nhánh GitHub, quy ước đặt tên, quy trình Pull Request, phát hành phiên bản (`release`), vá lỗi khẩn cấp (`hotfix`) và khôi phục mã nguồn (`recovery`) cho toàn bộ Monorepo **MetaGym**.

---

## 1. Cấu trúc GitHub Branch Tree

```text
main                                    # Production ổn định (CI check + auto-deploy Render, gắn tag vX.Y.Z)
├── release/
│   └── vX.Y.Z                          # Đóng băng tính năng & QA trước khi phát hành (tạo từ develop -> PR vào main & develop)
├── hotfix/
│   └── <folder>/<task-con>             # Sửa lỗi khẩn cấp trên production (tạo từ main -> PR vào main & develop)
│
└── develop                             # Nhánh tích hợp chung của team (mọi nhánh công việc đều tách từ đây & PR về đây)
    ├── feature/
    │   └── <folder>/<task-con>         # Phát triển tính năng mới
    ├── fix/
    │   └── <folder>/<task-con>         # Sửa lỗi thông thường
    ├── update/
    │   └── <folder>/<task-con>         # Cập nhật/nâng cấp UI, dependencies, config, copywriting
    └── refactor/
        └── <folder>/<task-con>         # Tái cấu trúc code không đổi nghiệp vụ
```

### Ánh xạ `<folder>` ↔ Thư mục chính trong Monorepo

| `<folder>` | Thư mục chính | Ví dụ tên nhánh chuẩn |
|---|---|---|
| `mobile` | `mobile-app/` | `feature/mobile/tab2-training-hub`, `fix/mobile/meal-plans-overflow` |
| `backend` | `backend/`, `database/` | `feature/backend/coach-schedule-api`, `fix/backend/payment-webhook` |
| `admin` | `admin-web/` | `feature/admin/member-create-modal`, `update/admin/dashboard-kpi` |
| `landing` | `landing-web/` | `feature/landing/pricing-section`, `update/landing/hero-copy` |
| `design` | `design-system/` | `feature/design/membership-cards`, `update/design/svg-icons` |
| `docs` | `docs/`, `tasks/` | `feature/docs/api-contract-v2`, `update/docs/deployment-guide` |

> **Quy tắc chung:**
> - **Không tạo nhánh mới theo tên thành viên** (như `thong`, `thuc`, `truong_ship_it`).
> - **Không push trực tiếp lên `main`** (mọi push lên `main` có đụng `backend/` hoặc `database/` sẽ kích hoạt GitHub Actions và **deploy tự động lên Render**).
> - Dùng chữ thường, gạch nối `-` cho `<task-con>`, tách cấp bằng dấu `/` để GitHub & IDE hiển thị thành cây thư mục rõ ràng.

---

## 2. Quy trình làm việc hằng ngày (Feature / Fix / Update)

### Bước 1 — Lấy code mới nhất từ `develop`
```bash
git fetch origin
git checkout develop
git pull origin develop
```

### Bước 2 — Tạo nhánh theo folder chính & task con
```bash
git checkout -b feature/mobile/ten-task-con
# hoặc fix/backend/ten-loi, update/admin/ten-cap-nhat
```

### Bước 3 — Code, kiểm thử local & Commit theo quy ước
Định dạng commit (Conventional Commits):
```text
<type>(<scope>): <mô tả ngắn gọn, rõ ràng>
```

| `type` | Ý nghĩa | Ví dụ |
|---|---|---|
| `feat` | Thêm tính năng mới | `feat(mobile): implement Tab 2 training hub` |
| `fix` | Sửa lỗi | `fix(backend): handle expired ZaloPay callback` |
| `update` | Nâng cấp nhẹ / cập nhật UI, deps, config | `update(admin): refine dashboard KPI date range` |
| `refactor` | Tái cấu trúc code | `refactor(backend): extract auth guard helper` |
| `docs` | Cập nhật tài liệu | `docs(api): document admin lock endpoints` |
| `test` | Bổ sung/sửa test | `test(mobile): fix meal plans widget overflow test` |
| `style` | Format, CSS/token, giao diện thuần | `style(design): align dark graphite border tokens` |
| `chore` | Cấu hình build, CI, scripts | `chore(ci): run postgres migration check on develop` |

### Bước 4 — Đẩy nhánh & mở Pull Request vào `develop`
```bash
git push -u origin feature/mobile/ten-task-con
```
- Mở **Pull Request** trên GitHub với nhánh đích **`develop`**.
- Điền đầy đủ checklist trong PR Template.
- Chờ CI kiểm tra (nếu có thay đổi `backend/` hoặc `database/`, job `Check migrations on PostgreSQL` sẽ chạy tự động) và có ít nhất 1 thành viên/Team Leader review trước khi merge.

---

## 3. Quy trình Phát hành (`release/*`) và Vá khẩn cấp (`hotfix/*`)

### A. Phát hành phiên bản mới (`release/vX.Y.Z`)
1. Khi `develop` đã đủ tính năng cho 1 mốc phát hành, tạo nhánh release từ `develop`:
   ```bash
   git checkout develop && git pull origin develop
   git checkout -b release/v1.0.0
   git push -u origin release/v1.0.0
   ```
2. Chạy kiểm thử toàn bộ (`backend`, `admin-web`, `landing-web`, `mobile-app`) trên `release/v1.0.0`. Chỉ sửa bug phát sinh của bản release này trên nhánh `release/v1.0.0` (không thêm tính năng mới).
3. Mở **Pull Request `release/v1.0.0` → `main`**. Chờ CI `Check migrations on PostgreSQL` xanh và merge vào `main` (Render sẽ tự động deploy).
4. Gắn **Git Tag phiên bản** trên `main`:
   ```bash
   git checkout main && git pull origin main
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```
5. Merge ngược `main` (hoặc `release/v1.0.0`) về `develop` để không sót các bản vá QA.

### B. Vá lỗi khẩn cấp trên Production (`hotfix/<folder>/<task-con>`)
1. Tách trực tiếp từ `main`:
   ```bash
   git checkout main && git pull origin main
   git checkout -b hotfix/backend/fix-payment-crash
   ```
2. Sửa lỗi, test kỹ và mở **PR vào `main`** → gắn tag patch (vd `v1.0.1`).
3. Mở thêm **PR vào `develop`** để đồng bộ bản vá cho toàn team.

---

## 4. Lưu ý quan trọng cho Monorepo MetaGym

- **Database Migrations (`database/migrations/`):**
  - Hiện tại migrations đã đánh số từ `0001` đến `0033`.
  - Trước khi tạo file migration mới (`0034_*.up.sql` & `.down.sql`), luôn `git pull origin develop` để kiểm tra số thứ tự mới nhất, tránh trùng số với thành viên khác.
- **Bảo mật môi trường:** Tuyệt đối không commit file `.env`, key bí mật, hoặc dữ liệu nhạy cảm.
- **Phần Design (`design-system/`):**
  - Thiết kế trên Figma/prototype quản lý ở Figma & GitHub Projects.
  - Khi cập nhật source code trong `design-system/` (HTML/JS preview studio, SVG icons, CSS tokens), tạo nhánh `feature/design/<task>` hoặc `update/design/<task>` từ `develop`.

---

## 5. Chuyển tiếp từ các nhánh cũ & Recovery Code

### Bảo toàn nhánh cũ & Tag backup
Toàn bộ các nhánh trước ngày 24/11/2026 (`main`, `thong`, `thuc`, `truong_ship_it`, `design`, `codex/thong-mobile-integrated`) **đều được giữ nguyên trên GitHub** và đã lưu thành các tag bất biến:
- `backup/2026-11-24/main`
- `backup/2026-11-24/thong`
- `backup/2026-11-24/thuc`
- `backup/2026-11-24/truong_ship_it`
- `backup/2026-11-24/design`
- `backup/2026-11-24/design-remote`
- `backup/2026-11-24/codex-thong-mobile-integrated`

Khôi phục bất kỳ bản chụp nào về nhánh làm việc tạm:
```bash
git fetch --tags origin
git checkout -b recovery/ten-can-xem backup/2026-11-24/<tên-nhánh>
```

### Đang code dở ở nhánh cũ chưa đẩy lên?
Xem hướng dẫn nhanh 2 cách chuyển code không mất dữ liệu tại [`THONG-BAO-CHUYEN-NHANH.md`](THONG-BAO-CHUYEN-NHANH.md).
