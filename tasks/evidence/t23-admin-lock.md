# T23-UI-5 — Hồi quy nút khóa/mở tài khoản Admin

Ngày 24/10/2026. Kiểm thử trên PostgreSQL test riêng `meta_gym_ui_test_20261024`
(`127.0.0.1:55434`), backend `3022`, Admin Web `5177`. Không dùng stack demo.
Bản sửa mã: `38e0718`.

## Trước khi sửa

Theo báo cáo agent T23-UI-5 và mã nguồn: nút **Khóa** gửi `{status: 'DISABLED'}`
nhưng API yêu cầu thêm `reason`, nên trả 422. Kiểm thử `admin-web/test/account-status.test.js`
đã tái hiện: 4/5 ca đỏ (thiếu lý do, hủy/trống/quá dài vẫn gửi PATCH).

## Sau khi sửa

- Admin đăng nhập trên Chrome tách biệt, mở trang Member và bấm **Khóa**.
  Hộp thoại hỏi lý do; nhập lý do có khoảng trắng ở hai đầu. PATCH trả 200;
  database lưu lý do đã cắt khoảng trắng, `status=DISABLED`, ghi audit
  `USER_DISABLED`. Giao diện đổi sang **Mở**. [Ảnh khi khóa](t23-admin-lock-disabled.png).
- Phiên Member cũ: `GET /users/me` trước khóa 200, sau khóa 401; đăng nhập
  khi bị khóa trả 403. Không in hoặc lưu access token.
- Admin bấm **Mở**: không hỏi/gửi `reason`; PATCH trả 200, database trở về
  `ACTIVE`, `disabled_reason=NULL`, session version tăng từ 3 lên 4 và ghi
  `USER_ENABLED`. Token cũ vẫn nhận 401; đăng nhập mới trả 200.
  [Ảnh sau khi mở](t23-admin-lock-restored.png).
- `admin-web/index.html` trỏ tới favicon SVG sẵn có. Lượt mở trang Admin cuối:
  không có console error/warning hoặc HTTP 4xx.

## Hồi quy tự động

- Admin Web `npm test`: 5 pass, 0 fail; `npm run build`: đạt.
- Backend `npm run check`: đạt; `npm test` với database PostgreSQL trống,
  tách demo (`meta_gym_t23_fix_20261024`): 54 pass, 0 fail, 0 skip.
- Flutter `flutter analyze`: không có issue; `flutter test`: 138 pass.

Hai ảnh chỉ chứa tài khoản demo trong database test. PostgreSQL test, backend
và Vite được dừng sau lượt kiểm thử; không thay đổi stack demo.
