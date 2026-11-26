---
trigger: always_on
description: "Quy trình Git bắt buộc cho Antigravity và coding agent trong Meta Gym: làm trên nhánh công việc, push nhánh, review rồi mới gộp vào develop."
---

# Meta Gym — Quy trình nhánh công việc

## Workspace và nhánh hiện tại

- Repository chính trên máy người dùng là `F:\MetaGym`; Flutter app là `F:\MetaGym\mobile-app`.
- Không dùng đường dẫn cũ `F:\AndroidProjects\MetaGym` hoặc `MetaGym-test`.
- Công việc đồng bộ giao diện preview hiện tại dùng nhánh `codex/ui-preview-refinement`, đã được người dùng yêu cầu tạo từ `develop` và push lên `origin`.
- Tiếp tục nhiệm vụ giao diện hiện tại trên nhánh này; không tự tạo nhánh trùng hoặc quay về `develop` để sửa code.
- Tên nhánh `codex/ui-preview-refinement` là ngoại lệ đã được người dùng chấp thuận. Với nhiệm vụ độc lập sau này, dùng cách đặt tên nhánh trong `CONTRIBUTING.md`, tách từ `develop` mới nhất.

## Trước khi sửa

1. Kiểm tra thư mục bằng `git rev-parse --show-toplevel`, nhánh bằng `git branch --show-current`, và thay đổi bằng `git status --short --branch`.
2. Báo ngắn gọn repository và nhánh đang dùng. Tên thư mục trong Explorer hoặc nội dung chat cũ không thay thế kiểm tra này.
3. Nếu đang ở `main` hoặc `develop`, chuyển sang nhánh công việc phù hợp trước khi chỉnh sửa. Nếu có thay đổi chưa commit hoặc chưa rõ chủ sở hữu, giữ nguyên và làm rõ trước thao tác có thể ảnh hưởng chúng.
4. Không reset, clean, checkout đè, tự stash hoặc xóa thay đổi của người dùng/agent khác.

## Làm việc, commit và push

1. Chỉ sửa phạm vi người dùng giao; giữ các yêu cầu thiết kế và nghiệp vụ đã được duyệt.
2. Chạy các kiểm tra phù hợp trước khi commit. Với UI Flutter, kiểm tra giao diện render thật; không dùng ảnh preview HTML thay cho ảnh app.
3. Xem diff và chỉ stage các file thuộc công việc của mình; không dùng `git add .` khi có thay đổi không liên quan.
4. Commit theo Conventional Commits và quy định trong `CONTRIBUTING.md`.
5. Khi một phần công việc đã hoàn thành và kiểm tra đạt, commit rồi push lên chính nhánh công việc. Nhánh hiện tại dùng `git push -u origin codex/ui-preview-refinement` cho lần đầu hoặc `git push` khi upstream đã được thiết lập.
6. Nếu kiểm tra chưa đạt, báo lỗi và phần chưa hoàn tất; không ghi rằng kiểm tra đã đạt hoặc tự skip/xóa test để vượt qua.
7. Không push trực tiếp lên `main` hoặc `develop`; không force-push hoặc viết lại lịch sử nhánh đã chia sẻ nếu chưa được yêu cầu rõ ràng.

## Pull request và gộp nhánh

- Sau khi push, chuẩn bị hoặc mở Pull Request với base `develop`, compare là nhánh công việc; mô tả thay đổi và kết quả kiểm chứng thực tế.
- Không tự merge chỉ vì code đã xong, push thành công, hoặc CI xanh.
- Chỉ gộp khi người dùng yêu cầu rõ ràng và các điều kiện bảo vệ nhánh/review trong `CONTRIBUTING.md` đã đáp ứng. Không bỏ qua CI hoặc yêu cầu approve.
- Không tự xóa nhánh sau merge nếu người dùng chưa yêu cầu.
- Bàn giao phải nêu nhánh, commit đã push, liên kết PR nếu có và trạng thái đã/chưa gộp vào `develop`.

Quy tắc này áp dụng cho các công việc tiếp theo trong workspace, kể cả khi mở chat Antigravity mới. Chỉ dẫn mới nhất của người dùng được ưu tiên khi thay đổi phạm vi hoặc quy trình.
