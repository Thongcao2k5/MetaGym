# SỔ TAY NHANH: WORKFLOW NHÁNH GITHUB METAGYM (`feat` · `fix` · `release`)

> [!IMPORTANT]
> **Đã hoàn tất nâng cấp & phát hành mốc [`v1.0.0`](https://github.com/Thongcao2k5/MetaGym/releases/tag/v1.0.0) (24/11/2026).**
> Repo hiện chỉ duy trì **2 nhánh chính được bảo vệ** là **`main`** (Production) và **`develop`** (Integration).
> Toàn bộ 5 nhánh cũ đã gộp 100% vào `main` & `develop` và được lưu thành **7 tag backup bất biến `backup/2026-11-24/*`**.

---

## 1. Luồng 4 chặng & Bảng nhớ nhanh (`feat` · `fix` · `release`)

```text
feature / fix / update   (dev tách từ develop để code từng task)
          │  PR + 1 người review + CI check
          ▼
       develop           (nhánh tích hợp chung của cả 3 dev)
          │  Đóng băng tính năng của đợt -> tách nhánh UAT
          ▼
    release/vX.Y.Z       (UAT / QA — chỉ vá bug UAT, không thêm tính năng mới)
          │  PR + CI PostgreSQL & Cloudflare Pages xanh
          ▼
        main             (Code chính Production · Render deploy · gắn tag vX.Y.Z)
```

> Trong lúc `release/vX.Y.Z` đang UAT, team vẫn tiếp tục phát triển đợt tiếp theo trên `develop` bình thường; nếu có vá bug UAT thì sau khi merge `release/vX.Y.Z` → `main` nhớ merge ngược lại `develop`.

| Khi cần làm | Tách từ | Đặt tên nhánh | Commit | Mở PR vào |
|---|---|---|---|---|
| **Tính năng mới (`feat`)** | `develop` | `feature/<folder>/<task>` | `feat(<folder>): ...` | `develop` |
| **Sửa lỗi thường (`fix`)** | `develop` | `fix/<folder>/<task>` | `fix(<folder>): ...` | `develop` |
| **Cập nhật nhẹ (`update`)** | `develop` | `update/<folder>/<task>` | `update(<folder>): ...` | `develop` |
| **Phát hành / UAT (`release`)** | `develop` | `release/vX.Y.Z` | `chore(release): ...` | `main` *(gắn tag `vX.Y.Z`)* |
| **Vá khẩn cấp (`hotfix`)** | `main` | `hotfix/<folder>/<task>` | `fix(<folder>): ...` | `main` **+** `develop` |

**`<folder>` tương ứng thư mục gốc:** `mobile` (`mobile-app/`), `backend` (`backend/` + `database/`), `admin` (`admin-web/`), `landing` (`landing-web/`), `design` (`design-system/`), `docs` (`docs/` + `tasks/`).

---

## 2. Lệnh copy-paste dùng hằng ngày

### A. Làm tính năng mới (`feat`) hoặc sửa lỗi (`fix`)
```bash
git fetch origin --prune
git checkout develop && git pull origin develop

# Tạo nhánh theo loại việc + folder + task con
git checkout -b feature/mobile/ten-task       # hoặc fix/backend/ten-loi

# Code, test local, rồi commit & push
git add .
git commit -m "feat(mobile): mô tả ngắn gọn"  # hoặc "fix(backend): ..."
git push -u origin feature/mobile/ten-task
```
→ Lên GitHub mở **Pull Request vào `develop`** → Review & CI xanh → Merge & xóa nhánh tạm.

### B. Phát hành bản mới (`release`) lên `main`
```bash
git fetch origin --prune
git checkout develop && git pull origin develop
git checkout -b release/v1.1.0
git push -u origin release/v1.1.0
```
→ Chạy QA toàn bộ module → Mở **Pull Request `release/v1.1.0` → `main`** → Chờ CI PostgreSQL & Cloudflare Pages xanh → Merge `main` (Render tự deploy) → Gắn tag `v1.1.0` và tạo GitHub Release.

### C. Vá lỗi khẩn cấp trên Production (`hotfix`)
```bash
git fetch origin --prune
git checkout main && git pull origin main
git checkout -b hotfix/backend/ten-loi-khan
# Sửa lỗi, test kỹ, commit & push
git push -u origin hotfix/backend/ten-loi-khan
```
→ Mở **PR vào `main`** (gắn tag patch `v1.0.1`) **và** mở thêm **PR vào `develop`** để đồng bộ bản vá.

---

## 3. Nếu máy bạn vẫn còn nhánh cũ / code dở chưa đẩy lên

```bash
# 1. Lưu commit trên máy của bạn
git add .
git commit -m "feat(mobile): mô tả phần đang làm"
git log -1 --oneline    # ghi lại mã commit (vd: abc1234)

# 2. Đồng bộ repo & tách nhánh mới từ develop
git fetch origin --prune
git checkout -b feature/<folder>/<task-con> origin/develop

# 3. Đem commit sang nhánh mới & đẩy lên
git cherry-pick <mã-commit>
git push -u origin feature/<folder>/<task-con>
```

---

## 4. Khôi phục code cũ (Recovery)

Toàn bộ lịch sử cũ trước ngày 24/11/2026 luôn khôi phục được qua 7 tag bất biến `backup/2026-11-24/*`:
```bash
git fetch --tags origin
git checkout -b recovery/xem-lai backup/2026-11-24/<main|thong|thuc|truong_ship_it|design|codex-thong-mobile-integrated>
```

> Xem sổ tay quy trình đầy đủ (quy ước commit, DB migration, bảo mật, CI/CD) tại **[`CONTRIBUTING.md`](CONTRIBUTING.md)**.
