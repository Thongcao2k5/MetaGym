---
trigger: model_decision
description: "Bắt buộc áp dụng trước khi thiết kế, chỉnh sửa, triển khai hoặc review bất kỳ UI/UX, màn hình Flutter, component hay giao diện Admin nào của Meta Gym."
---

# Meta Gym Design Gate

Trước mọi tác vụ liên quan đến giao diện Meta Gym:

1. Đọc `@../../DESIGN.md`. Đây là nguồn chuẩn cao nhất về phong cách, token, vật liệu, layout, component, motion, accessibility và hiệu năng.
2. Đọc `@../../design-system/meta-gym/MASTER.md` để lấy bản tóm tắt triển khai.
3. Nếu đang làm một trang cụ thể, kiểm tra `@../../design-system/meta-gym/pages/` và áp dụng page rule tương ứng sau MASTER.
4. Trước khi chỉnh sửa, xác nhận ngắn gọn rằng đã nạp quy tắc và nêu các ràng buộc liên quan trực tiếp đến màn hình đang làm.
5. Không tự phát minh màu, font, radius, spacing, glass level hoặc motion ngoài hệ thống. Nếu thật sự cần ngoại lệ, giải thích lý do và xin người dùng chốt trước.
6. Giữ đúng phong cách **Futuristic Performance Glass**: dark-first, hiện đại, sang trọng, mạnh mẽ; không cyberpunk, gaming hoặc rainbow neon.
7. Tuân thủ công thức 80/20: tối thiểu 80% bề mặt ổn định, tối đa 20% true backdrop glass; không lồng các lớp blur.
8. Ưu tiên độ đọc, accessibility và độ mượt khi demo. Không animate blur, kích thước layout hoặc shadow lớn; ưu tiên opacity và transform.
9. Sau khi hoàn thành, đối chiếu mục **Screen review checklist** trong `DESIGN.md` và báo rõ những mục đã kiểm tra.

Nếu tài liệu và mockup hiện tại mâu thuẫn, tài liệu thắng trừ khi người dùng xác nhận thay đổi Design System.
