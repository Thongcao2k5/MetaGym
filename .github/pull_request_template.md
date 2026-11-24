<!--
QUY ƯỚC TIÊU ĐỀ PR (BẮT BUỘC):
  <type>(<folder>): <tóm tắt ngắn gọn 1 dòng cho cả PR>
  Ví dụ: feat(mobile): hoàn thiện Tab 2 Training Hub và bộ test widget
  (GitHub sẽ dùng chính Tiêu đề PR + nội dung bên dưới làm commit log khi merge vào develop/main)
-->

## 1. Tóm tắt các phần đã làm (ánh xạ theo từng commit)

<!--
Bắt buộc liệt kê đủ các phần đã làm. Nếu PR có nhiều commit, gom hoặc ánh xạ rõ từng đầu việc với commit tương ứng theo đúng format:
- [<type>] <Mô tả rõ phần đã làm> — (`<type>(<scope>): <tiêu đề commit>`)

Ví dụ PR nhiều commit:
- [feat] Xây dựng màn hình Tab 2 Training Hub & thẻ gói tập — (`feat(mobile): build member training hub layout`)
- [fix] Sửa lỗi tràn dòng trên màn hình 375x812 — (`fix(mobile): resolve row overflow on small viewport`)
- [test] Bổ sung 8 widget tests kiểm chứng các trạng thái — (`test(mobile): add training hub widget tests`)
-->

- [feat/fix/update] ... — (`...`)

---

## 2. Phạm vi & Phân loại

**Loại công việc:**
- [ ] `feat` — Tính năng mới (`feature/<folder>/<task-con>` → `develop`)
- [ ] `fix` — Sửa lỗi thường (`fix/<folder>/<task-con>` → `develop`)
- [ ] `update` — Cập nhật UI / deps / config / docs (`update/<folder>/<task-con>` → `develop`)
- [ ] `refactor` — Tái cấu trúc code (`refactor/<folder>/<task-con>` → `develop`)
- [ ] `release` / `hotfix` — Phát hành UAT hoặc vá lỗi production (→ `main`)

**Folder chính bị ảnh hưởng:**
- [ ] `mobile-app/`
- [ ] `backend/`
- [ ] `database/` *(kiểm tra số migration mới nhất trên `develop`, hiện từ `0034+`)*
- [ ] `admin-web/`
- [ ] `landing-web/`
- [ ] `design-system/`
- [ ] `docs/` hoặc `tasks/`

**Ảnh hưởng API / Database / Env:**
- Không thay đổi *(hoặc ghi rõ endpoint mới, file migration `0034_*.sql`, biến môi trường mới)*

---

## 3. Kết quả kiểm thử (Verification)

<!-- Ghi rõ lệnh đã chạy và kết quả -->
- [ ] `mobile-app`: `flutter analyze --no-fatal-infos` & `flutter test ...`
- [ ] `backend`: `npm run check` & `npm test`
- [ ] `admin-web`: `npm test` & `npm run build`
- [ ] `landing-web`: `npm run build`

---

## 4. Checklist trước khi Merge

- [ ] Tiêu đề PR đúng chuẩn `<type>(<folder>): <mô tả>` và mục **1** đã liệt kê đủ các commit/hạng mục
- [ ] Nhánh đích đúng: **`develop`** cho `feature/fix/update/refactor`; **`main`** chỉ cho `release/*` hoặc `hotfix/*`
- [ ] Không commit file `.env` hoặc thông tin bí mật
- [ ] Chọn đúng kiểu merge:
  - **`Squash and merge`** khi merge nhánh nhỏ vào `develop` *(gom nhiều commit lẻ thành 1 commit sạch có đủ tóm tắt)*
  - **`Create a merge commit`** khi merge `release/vX.Y.Z` hoặc `hotfix/*` vào `main`
