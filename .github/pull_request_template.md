## Mục đích thay đổi

<!-- Mô tả ngắn gọn tính năng / lỗi được sửa / cập nhật trong PR này -->

> **Nhắc nhanh quy trình nhánh (`CONTRIBUTING.md`):**
> - PR tính năng / sửa lỗi / cập nhật thường (`feature/*`, `fix/*`, `update/*`, `refactor/*`) → chọn nhánh đích là **`develop`**.
> - Nhánh đích **`main`** chỉ dành cho **`release/vX.Y.Z`** hoặc **`hotfix/*`** (merge vào `main` sẽ kích hoạt CI & deploy Render).
> - Đang chuyển code từ nhánh cũ (`truong_ship_it`, `thuc`, `thong`, `codex/*`, `design`)? Hãy mở PR vào **`develop`** và xem [`THONG-BAO-CHUYEN-NHANH.md`](THONG-BAO-CHUYEN-NHANH.md).

---

## Loại công việc

- [ ] `feature` — Tính năng mới
- [ ] `fix` — Sửa lỗi
- [ ] `update` — Cập nhật UI / dependencies / config
- [ ] `refactor` — Tái cấu trúc code
- [ ] `release` / `hotfix` — Phát hành / vá lỗi production
- [ ] `docs` — Tài liệu

## Folder chính bị ảnh hưởng

- [ ] `mobile-app/`
- [ ] `backend/`
- [ ] `database/` *(lưu ý kiểm tra số thứ tự migration mới nhất trên `develop`)*
- [ ] `admin-web/`
- [ ] `landing-web/`
- [ ] `design-system/`
- [ ] `docs/` hoặc `tasks/`

---

## Checklist trước khi yêu cầu Review

- [ ] Đã cập nhật/đồng bộ mới nhất từ nhánh đích (`develop` hoặc `main`)
- [ ] Không commit file `.env` hoặc thông tin bí mật
- [ ] Đã chạy kiểm tra/test cho các module bị ảnh hưởng:
  - `backend`: `npm run check` & `npm test`
  - `admin-web`: `npm test` & `npm run build`
  - `landing-web`: `npm run build`
  - `mobile-app`: `flutter analyze` & `flutter test`
- [ ] Đã cập nhật tài liệu / API contract (nếu thay đổi API hoặc DB schema)

## Ảnh chụp / Ghi chú kiểm thử (nếu có)

<!-- Dán screenshot hoặc log test ngắn gọn tại đây -->
