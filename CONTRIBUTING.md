# Quy trình Git & Workflow Chuẩn — MetaGym (Team 3 người)

Tài liệu sổ tay chính thức cho toàn bộ team **MetaGym** về cấu trúc nhánh GitHub và quy trình thực hiện từng luồng công việc: **`feat`**, **`fix`**, **`update`**, **`refactor`**, **`release`** và **`hotfix`**.

---

## 1. Bảng tra cứu nhanh (Nhìn 1 lần biết ngay lệnh cần dùng)

| Luồng | Mục đích | Tách từ nhánh | Tên nhánh chuẩn | Tiền tố Commit | Mở PR vào | Tự động Deploy? |
|---|---|---|---|---|---|---|
| **`feat`** | Thêm tính năng / màn hình / API mới | `develop` | `feature/<folder>/<task-con>` | `feat(<scope>): ...` | `develop` | Không |
| **`fix`** | Sửa lỗi thông thường đang phát triển | `develop` | `fix/<folder>/<task-con>` | `fix(<scope>): ...` | `develop` | Không |
| **`update`** | Cập nhật UI nhẹ, deps, config, tài liệu | `develop` | `update/<folder>/<task-con>` | `update(<scope>): ...` / `docs(<scope>): ...` | `develop` | Không |
| **`refactor`** | Tái cấu trúc code không đổi nghiệp vụ | `develop` | `refactor/<folder>/<task-con>` | `refactor(<scope>): ...` | `develop` | Không |
| **`release`** | Đóng băng, QA & phát hành phiên bản mới | `develop` | `release/vX.Y.Z` | `chore(release): ...` / `fix(...): ...` | `main` *(rồi đồng bộ `develop` nếu có vá QA)* | **Có** (Render API + Cloudflare Pages) |
| **`hotfix`** | Vá lỗi khẩn cấp trên Production (`main`) | `main` | `hotfix/<folder>/<task-con>` | `fix(<scope>): ...` | `main` **và** `develop` | **Có** (Render API + Cloudflare Pages) |

### Ánh xạ `<folder>` / `<scope>` ↔ Thư mục chính trong Monorepo

| `<folder>` | Thư mục chính | Ví dụ nhánh `feat` / `fix` |
|---|---|---|
| `mobile` | `mobile-app/` | `feature/mobile/tab2-training-hub`, `fix/mobile/meal-plans-overflow` |
| `backend` | `backend/`, `database/` | `feature/backend/coach-schedule-api`, `fix/backend/zalopay-callback` |
| `admin` | `admin-web/` | `feature/admin/member-create-modal`, `fix/admin/search-focus` |
| `landing` | `landing-web/` | `feature/landing/pricing-section`, `update/landing/hero-copy` |
| `design` | `design-system/` | `feature/design/membership-cards`, `update/design/svg-icons` |
| `docs` | `docs/`, `tasks/`, root `.md` | `update/docs/api-contract-v2`, `feature/docs/onboarding` |

---

## 2. Cây nhánh GitHub chuẩn

```text
main                                    # Production ổn định (đã bật Branch Protection, gắn tag v1.0.0, v1.1.0...)
├── release/vX.Y.Z                      # Nhánh đóng băng & kiểm thử phát hành -> PR vào main -> gắn tag vX.Y.Z
├── hotfix/<folder>/<task-con>          # Vá lỗi khẩn cấp production -> PR vào main + develop
│
└── develop                             # Nhánh tích hợp chính của team (đã bật Branch Protection)
    ├── feature/<folder>/<task-con>     # Tính năng mới (feat)
    ├── fix/<folder>/<task-con>         # Sửa lỗi thường (fix)
    ├── update/<folder>/<task-con>      # Nâng cấp nhẹ, UI polish, docs, deps
    └── refactor/<folder>/<task-con>    # Tái cấu trúc code
```

> **Nguyên tắc bắt buộc (đã bật Branch Protection trên GitHub):**
> - **Không push trực tiếp** lên `main` và `develop` — mọi thay đổi phải đi qua **Pull Request** và có tối thiểu **1 người review/approve**.
> - **Không tạo nhánh cố định theo tên thành viên** (`thong`, `thuc`, `truong_ship_it`).
> - **Xóa nhánh tạm sau khi PR đã merge** để cây nhánh GitHub luôn gọn sạch (chỉ còn `main`, `develop` và các nhánh task đang chạy).

---

## 3. Quy trình chi tiết từng luồng (Copy-Paste)

### Luồng A — `feat`: Làm tính năng mới (`feature/<folder>/<task-con>`)

```bash
# 1. Lấy code mới nhất từ develop
git fetch origin --prune
git checkout develop
git pull origin develop

# 2. Tạo nhánh tính năng đúng folder & task con
git checkout -b feature/mobile/ten-tinh-nang

# 3. Code và chạy kiểm thử local của module bạn sửa
#    - mobile-app:  flutter analyze --no-fatal-infos && flutter test <file-test>
#    - backend:     npm run check && npm test
#    - admin-web:   npm test && npm run build
#    - landing-web: npm run build

# 4. Commit theo chuẩn Conventional Commits
git add <các-file-liên-quan>
git commit -m "feat(mobile): mô tả ngắn gọn tính năng"

# 5. Đẩy nhánh lên GitHub
git push -u origin feature/mobile/ten-tinh-nang
```

**Trên GitHub:**
1. Mở **Pull Request** với **base: `develop`** ← **compare: `feature/mobile/ten-tinh-nang`**.
2. Điền đầy đủ checklist trong PR Template (chọn folder chính, test đã chạy).
3. Chờ CI xanh (`Check migrations on PostgreSQL` nếu sửa `backend/` hoặc `database/`) + 1 thành viên/Team Leader approve.
4. Merge vào `develop` và bấm **Delete branch**.

---

### Luồng B — `fix`: Sửa lỗi thường (`fix/<folder>/<task-con>`)

Dùng cho mọi lỗi phát hiện trên `develop` hoặc lỗi thường không cần vá khẩn cấp ngay lập tức lên production:

```bash
# 1. Lấy develop mới nhất
git fetch origin --prune
git checkout develop
git pull origin develop

# 2. Tạo nhánh sửa lỗi
git checkout -b fix/mobile/meal-plans-overflow

# 3. Sửa lỗi + bổ sung/chạy test xác nhận hết lỗi
git add <các-file-đã-sửa>
git commit -m "fix(mobile): fix Row overflow on 375x812 meal plans screen"

# 4. Đẩy nhánh và mở Pull Request vào develop
git push -u origin fix/mobile/meal-plans-overflow
```

- Mở **Pull Request** vào **`develop`**, mô tả rõ nguyên nhân lỗi & cách kiểm chứng → review → merge → xóa nhánh tạm.
- Với `update/*` (chỉnh copy, cập nhật deps/UI nhỏ) hoặc `refactor/*`: làm y hệt luồng này, chỉ đổi tên nhánh thành `update/<folder>/<task-con>` hoặc `refactor/<folder>/<task-con>`.

---

### Luồng C — `release`: Phát hành phiên bản mới lên `main` (`release/vX.Y.Z`)

**Quy ước đánh số phiên bản (Semantic Versioning `vMAJOR.MINOR.PATCH`):**
- **`v1.0.0` → `v1.1.0` (MINOR):** Thêm tính năng mới từ `develop` (mốc sprint/demo mới).
- **`v1.1.0` → `v1.1.1` (PATCH):** Chỉ gồm bản sửa lỗi / `hotfix`.
- **`v1.x.x` → `v2.0.0` (MAJOR):** Thay đổi kiến trúc lớn hoặc breaking change.

**Các bước thực hiện (Team Leader chủ trì):**

```bash
# 1. Đồng bộ develop mới nhất và tạo nhánh release
git fetch origin --prune
git checkout develop
git pull origin develop
git checkout -b release/v1.1.0
git push -u origin release/v1.1.0
```

2. **Đóng băng tính năng & QA tổng thể trên `release/v1.1.0`:**
   - **Không thêm tính năng mới** vào nhánh `release/*` — chỉ commit các bản vá bug phát sinh trong lúc QA (`fix(...): ...`).
   - Chạy kiểm thử toàn bộ:
     - `backend`: `npm run check` & `npm test`
     - `admin-web`: `npm test` & `npm run build`
     - `landing-web`: `npm run build`
     - `mobile-app`: `flutter analyze --no-fatal-infos` & `flutter test`
3. **Mở Pull Request `release/v1.1.0` → `main`:**
   - Chờ toàn bộ checks xanh:
     - `Check migrations on PostgreSQL` *(nếu có thay đổi `backend/` hoặc `database/`)*
     - `Cloudflare Pages: metagym-admin` & `metagym-landing`
     - `Branch workflow reminder`
   - Merge PR vào `main` và xóa nhánh `release/v1.1.0`.
   - Khi merge vào `main`, nếu có thay đổi `backend/` hoặc `database/`, GitHub Actions sẽ tự kiểm tra PostgreSQL 17 lần cuối và gọi **Render Deploy Hook**; Cloudflare Pages tự build `admin-web` và `landing-web`.
4. **Gắn Git Tag & tạo GitHub Release:**
   ```bash
   git fetch origin --prune
   git checkout main
   git pull origin main
   git tag -a v1.1.0 -m "Release v1.1.0: <tóm tắt mốc phát hành>"
   git push origin v1.1.0
   ```
   Sau đó tạo **GitHub Release** từ tag `v1.1.0` (hoặc dùng `gh release create v1.1.0 --title "MetaGym v1.1.0" --notes "..."`).
5. **Đồng bộ ngược về `develop` (BẮT BUỘC nếu nhánh `release/v1.1.0` có commit vá lỗi QA):**
   - Mở PR nhỏ từ `main` → `develop` (hoặc `git checkout develop && git merge origin/main`) để các bản vá QA không bị sót ở đợt phát triển sau.

---

### Luồng D — `hotfix`: Vá lỗi khẩn cấp trên Production (`hotfix/<folder>/<task-con>`)

Chỉ dùng khi bản đang chạy trên `main` (Render / Cloudflare / bản APK đã phát hành) gặp sự cố nghiêm trọng cần sửa ngay mà không thể đợi các tính năng dở dang trên `develop`:

```bash
# 1. Tách trực tiếp từ main (KHÔNG tách từ develop)
git fetch origin --prune
git checkout main
git pull origin main
git checkout -b hotfix/backend/fix-payment-crash

# 2. Sửa lỗi tối thiểu, test kỹ và push
git add <file-sửa>
git commit -m "fix(backend): handle null callback payload on ZaloPay webhook"
git push -u origin hotfix/backend/fix-payment-crash
```

3. Mở **PR #1: `hotfix/...` → `main`** → chờ CI xanh → merge → gắn tag patch (vd `v1.0.1`) + tạo Release.
4. Mở **PR #2: `hotfix/...` → `develop`** (hoặc merge `main` về `develop`) để toàn team nhận bản vá ngay.

---

## 4. Quy ước Commit (Conventional Commits)

Định dạng chuẩn: `<type>(<scope>): <mô tả ngắn gọn>`

| `type` | Dùng khi nào | Ví dụ |
|---|---|---|
| `feat` | Thêm tính năng mới | `feat(mobile): implement Tab 2 training hub` |
| `fix` | Sửa lỗi | `fix(backend): reject expired payment hold cleanly` |
| `update` | Nâng cấp nhẹ, cập nhật UI/deps/config | `update(admin): refine dashboard KPI date presets` |
| `refactor` | Tái cấu trúc code, không đổi hành vi | `refactor(backend): extract auth guard helper` |
| `docs` | Cập nhật tài liệu | `docs(git): add feat, fix, and release workflow guide` |
| `test` | Thêm hoặc sửa test | `test(mobile): add Member Profile 5.1-5.14 sync tests` |
| `style` | Format, CSS/token, icon thuần giao diện | `style(design): align Dark Graphite border tokens` |
| `chore` | CI/CD, build scripts, tooling | `chore(ci): run PostgreSQL migration check on develop PRs` |

---

## 5. Lưu ý kỹ thuật bắt buộc cho Monorepo MetaGym

- **Database Migrations (`database/migrations/`):**
  - Đã có sẵn `0001` → `0033`. **Không sửa/xóa các file migration đã merge.**
  - Trước khi tạo cặp `0034_*.up.sql` & `0034_*.down.sql`, luôn `git pull origin develop` để kiểm tra số thứ tự mới nhất, tránh trùng số giữa các thành viên.
  - Xem quy trình migration & Render chi tiết tại [docs/render-migrations.md](docs/render-migrations.md).
- **Bảo mật môi trường:** Tuyệt đối **không commit** `.env`, `DATABASE_URL`, `JWT_SECRET`, API keys hay `RENDER_DEPLOY_HOOK_URL`. Xem thêm [SECURITY.md](SECURITY.md).
- **Design System (`design-system/`):**
  - Thiết kế Figma/prototype quản lý ở Figma & GitHub Projects.
  - Khi chỉnh sửa source code trong `design-system/` (preview studio, SVG icons, tokens), tách nhánh `feature/design/<task>` hoặc `update/design/<task>` từ `develop`.

---

## 6. Lịch sử chuyển đổi & Recovery Code

Dự án đã hoàn tất chuẩn hóa cây nhánh ở mốc **[`v1.0.0`](https://github.com/Thongcao2k5/MetaGym/releases/tag/v1.0.0)** (24/11/2026). Toàn bộ các nhánh cũ đã được gộp đầy đủ vào `main` + `develop` và lưu thành **7 Git Tag bất biến** trên GitHub để khôi phục bất kỳ lúc nào:

- `backup/2026-11-24/main`
- `backup/2026-11-24/thong`
- `backup/2026-11-24/thuc`
- `backup/2026-11-24/truong_ship_it`
- `backup/2026-11-24/design` & `backup/2026-11-24/design-remote`
- `backup/2026-11-24/codex-thong-mobile-integrated`

**Lệnh khôi phục (Recovery) về một nhánh tạm để xem/lấy lại code cũ:**
```bash
git fetch --tags origin
git checkout -b recovery/xem-lai-code backup/2026-11-24/<tên-nhánh>
```
