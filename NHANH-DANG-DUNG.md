# MetaGym — bản Trường đã đồng bộ các nhánh

Ngày đồng bộ: 22/11/2026 (giờ Việt Nam).

## Nhận diện bản local

- Thư mục: `F:\MetaGym-truong_ship_it`.
- Nhánh làm việc: `codex/truong_ship_it-sync`.
- Nhánh gốc được giữ nguyên tại local: `truong_ship_it`.
- Repository: https://github.com/Thongcao2k5/MetaGym.
- Đây là bản gộp local; chưa push, mở PR hoặc deploy.

## Nguồn đã tích hợp

| Nguồn | Commit đã lấy |
| --- | --- |
| `origin/truong_ship_it` | `1d30ba77c79095958510134ac51d011c446a746e` |
| `origin/main` | `be7d032f6b8d5411b3c1d82ef0cd5b3efbb73206` |
| `origin/thong` | `9b7e8b28f4a9feb92117bb83297c01da95b8cedb` (đã nằm trong main) |
| `origin/thuc` | `0cc7d6d9ee6fb17886ff4ab5b8d3651f51650ef4` (đã nằm trong main) |

Đã merge toàn bộ main vào bản Trường, bao gồm backend, mobile, admin-web,
landing-web và tài liệu. Không có xung đột Git; `mobile-app/test/widget_test.dart`
được Git tự gộp, giữ cả thay đổi riêng của Trường và interface mới từ main.

Phần mobile bổ sung gồm WAIT/REFUND khi Coach bị khóa, kết thúc sớm 72 giờ,
service/model/giao diện và test tương ứng, cùng splash mới. Các thay đổi riêng
của Trường về Coach, tin nhắn, AI và ZaloPay được giữ lại.

## Kiểm chứng tại máy

| Kiểm tra | Kết quả |
| --- | --- |
| `git diff --cached --check` trước commit | Đạt |
| Backend `npm run check` | Đạt |
| Backend `npm test` | 66 đạt, 50 bỏ qua do chưa có database kiểm thử |
| Admin Web `npm test` | 35 đạt |
| Admin Web `npm run build` | Đạt; có cảnh báo bundle trên 500 kB |
| Landing `npm run build` | Đạt |
| Mobile `flutter test --reporter expanded` | 234 đạt, 2 lỗi cũ ở meal plans |
| Mobile `flutter analyze` | Không có error/warning; 1 info, exit code 1 |

Hai test lỗi thuộc `mobile-app/test/features/training/meal_plans_page_test.dart`:

- Coach edits structured 7-day meal plan, adds dish via sheet, and saves at 375x812.
- Member views structured 7-day meal plan cleanly at 375x812.

Đã chạy lại riêng hai test trên worktree nguyên bản `origin/truong_ship_it`
(`1d30ba7`) và tái hiện cùng lỗi. Màn hình và file test này không đổi trong lần
gộp. Lỗi gồm kỳ vọng tiêu đề không khớp, tràn Row và assertion về nền ListTile.
Giữ nguyên để sửa riêng; không bỏ test hoặc che lỗi nhằm làm xanh kết quả.

Góp ý analyzer cũ: `unnecessary_nullable_for_final_variable_declarations` tại
`mobile-app/test/features/training/meal_plans_page_test.dart:105`.

Log kiểm tra nằm trong `.tmp/verification/`; log đối chiếu bản gốc nằm tại
`.tmp/baseline-meal-test.log`. Các log này được Git bỏ qua.

Chưa kiểm thử kết nối API/database production, chưa chạy migration/seed và
chưa build APK. Bản clone không chứa cấu hình bí mật của môi trường đang chạy.

## Chọn đúng bản khi làm việc

```powershell
Set-Location 'F:\MetaGym-truong_ship_it'
git branch --show-current
git status --short --branch
```

Nhánh cần hiển thị là `codex/truong_ship_it-sync`.
Mở thư mục `mobile-app` trong Android Studio để làm việc với ứng dụng Flutter.

Muốn xem lại bản gốc Trường, bảo đảm đã lưu/commit công việc hiện tại trước khi
chuyển nhánh bằng `git switch truong_ship_it`. Quay lại bản gộp bằng
`git switch codex/truong_ship_it-sync`.
