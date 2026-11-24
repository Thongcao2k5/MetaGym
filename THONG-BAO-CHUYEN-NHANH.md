# THÔNG BÁO QUAN TRỌNG: NÂNG CẤP CẤU TRÚC NHÁNH GITHUB (24/11/2026)

> [!IMPORTANT]
> Repo **MetaGym** đã chính thức chuyển sang cấu trúc nhánh chuẩn (`main` / `develop` / `release/*` / `hotfix/*` / `feature|fix|update|refactor/<folder>/<task-con>`).
> **Toàn bộ nhánh cũ và code của mọi người ĐƯỢC GIỮ NGUYÊN 100% — KHÔNG BỊ XÓA.**

---

## 1. An toàn dữ liệu & Recovery Code

- Tất cả các nhánh cũ (`main`, `thong`, `thuc`, `truong_ship_it`, `design`, `codex/thong-mobile-integrated`) vẫn được giữ lại trên GitHub.
- Toàn bộ trạng thái trước thời điểm nâng cấp đã được lưu thành bộ **Git Tag bất biến**:
  - `backup/2026-11-24/main`
  - `backup/2026-11-24/thong`
  - `backup/2026-11-24/thuc`
  - `backup/2026-11-24/truong_ship_it`
  - `backup/2026-11-24/design` & `backup/2026-11-24/design-remote`
  - `backup/2026-11-24/codex-thong-mobile-integrated`
- Cần khôi phục code bất kỳ lúc nào:
  ```bash
  git fetch --tags origin
  git checkout backup/2026-11-24/<tên-nhánh>
  ```
- **Nhánh `develop`** hiện đã chứa đầy đủ 100% code mới nhất đã gộp của cả 3 thành viên (bao gồm `main`, `thuc`, `truong_ship_it`, `design`, `thong` và `codex/thong-mobile-integrated`).

---

## 2. Bạn đang code dở trên nhánh cũ chưa đẩy lên? Làm theo 1 trong 2 cách sau

Không cần hoảng và **không bị mất code**. Hãy commit phần bạn đang làm ở máy local trước, rồi chọn:

### Cách 1 — Nhanh nhất (đang có nhiều thay đổi dở dang)
Đẩy tiếp lên nhánh cũ của bạn rồi mở **Pull Request vào `develop`**:

```bash
# 1. Lưu code đang làm trên nhánh cũ của bạn
git add .
git commit -m "feat(mobile): <mô tả ngắn việc bạn đang làm>"

# 2. Kéo file thông báo mới nhất (không đụng file code nên không conflict)
git pull --no-rebase

# 3. Đẩy lên nhánh cũ của bạn bình thường
git push
```

Sau đó vào GitHub → tạo **Pull Request** với:
- **base:** `develop`
- **compare:** `<nhánh-cũ-của-bạn>`

Sau khi PR được review & merge vào `develop`, từ task tiếp theo bạn chuyển sang tách nhánh mới từ `develop`.

### Cách 2 — Sạch nhất (chuyển thẳng commit đang làm sang nhánh mới từ `develop`)

```bash
# 1. Commit phần code đang làm trên máy
git add .
git commit -m "feat(mobile): <mô tả ngắn việc bạn đang làm>"

# 2. Lấy mã commit vừa tạo (ví dụ: abc1234)
git log -1 --oneline

# 3. Lấy nhánh develop mới nhất và tạo nhánh đúng chuẩn
git fetch origin
git checkout -b feature/<folder>/<task-con> origin/develop

# 4. Đem commit vừa làm sang nhánh mới
git cherry-pick <mã-commit>

# 5. Đẩy nhánh mới và mở Pull Request vào develop
git push -u origin feature/<folder>/<task-con>
```

---

## 3. Cây nhánh chuẩn áp dụng từ hôm nay

```text
main                                    # Production ổn định (auto-deploy Render)
├── release/vX.Y.Z                      # Đóng băng & test trước khi phát hành -> PR vào main + develop
├── hotfix/<folder>/<task-con>          # Vá lỗi khẩn cấp từ main -> PR vào main + develop
│
└── develop                             # Nhánh tích hợp chính của team (mọi PR đổ về đây)
    ├── feature/<folder>/<task-con>     # Tính năng mới
    ├── fix/<folder>/<task-con>         # Sửa lỗi thường
    ├── update/<folder>/<task-con>      # Cập nhật UI, config, thư viện, nội dung
    └── refactor/<folder>/<task-con>    # Tái cấu trúc code
```

**Tên `<folder>` tương ứng với thư mục chính trong repo:**
- `mobile` → `mobile-app/`
- `backend` → `backend/` & `database/`
- `admin` → `admin-web/`
- `landing` → `landing-web/`
- `design` → `design-system/`
- `docs` → `docs/` & `tasks/`

**Ví dụ tên nhánh chuẩn:**
- `feature/mobile/tab2-training-hub`
- `feature/backend/coach-schedule-api`
- `fix/mobile/meal-plans-overflow`
- `update/admin/dashboard-kpi-cards`
- `feature/design/membership-cards`

> Xem tài liệu quy trình chi tiết đầy đủ tại **`CONTRIBUTING.md`** trên nhánh `develop`:
> <https://github.com/Thongcao2k5/MetaGym/blob/develop/CONTRIBUTING.md>
