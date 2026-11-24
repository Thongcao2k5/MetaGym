# Accessibility Statement — MetaGym

Đội ngũ **MetaGym** cam kết xây dựng trải nghiệm dễ tiếp cận, rõ ràng và thân thiện cho mọi người dùng (Member, Coach và Admin) trên cả ứng dụng di động Flutter và giao diện web.

---

## 1. Cam kết & Tiêu chuẩn hướng tới

Dự án thiết kế và kiểm thử các giao diện theo hệ thống **Futuristic Performance Glass** (`DESIGN.md` & `design-system/`) với các mục tiêu thực tế theo chuẩn **WCAG 2.1 Level AA**:

- **Độ tương phản màu sắc (Contrast):** Calibrate riêng cho cả giao diện tối (Dark Graphite) và giao diện sáng, bảo đảm chữ nội dung, nhãn KPI và trạng thái lỗi/cảnh báo đạt độ tương phản dễ đọc.
- **Vùng chạm tối thiểu (Touch Targets):** Các nút bấm, hàng danh sách và thành phần tương tác trên `mobile-app/` (Flutter) và `admin-web/` (Bootstrap 5) tuân thủ kích thước chạm tối thiểu **44×44 px / 48×48 dp**, kèm phản hồi xúc giác (haptic feedback) trên di động.
- **Kiểu chữ & Tiếng Việt:** Sử dụng bộ font `Be Vietnam Pro` hỗ trợ đầy đủ dấu tiếng Việt, phân cấp kích thước chữ rõ ràng và tránh tràn khung (`overflow`) trên các màn hình nhỏ (kiểm thử chuẩn từ `375×812` trở lên).
- **Điều hướng & Trạng thái rõ ràng:** Không chỉ dựa vào màu sắc để báo trạng thái (luôn kết hợp nhãn văn bản/biểu tượng); hỗ trợ tiêu điểm bàn phím (focus ring) và nhãn biểu mẫu trên `admin-web/` và `landing-web/`.

---

## 2. Môi trường hỗ trợ

- **Mobile App (`mobile-app/`):** Android & Flutter Web (kiểm thử responsive tại `375×812` và `800×600`).
- **Admin Web (`admin-web/`) & Landing Web (`landing-web/`):** Các trình duyệt hiện đại (Chrome, Edge, Firefox, Safari phiên bản mới nhất) trên desktop và mobile.

---

## 3. Hạn chế đã biết (Known Limitations)

- Một số màn hình prototype xem trước trong `design-system/flutter-screens/` phục vụ review nội bộ chưa tối ưu đầy đủ cho trình đọc màn hình (screen reader) như bản ứng dụng Flutter chính thức.
- Hỗ trợ trình đọc màn hình đầy đủ (TalkBack / VoiceOver semantics) và chế độ giảm chuyển động (`prefers-reduced-motion`) đang được bổ sung dần qua các đợt nâng cấp UI.

---

## 4. Báo cáo rào cản tiếp cận (Feedback)

Nếu bạn gặp khó khăn khi sử dụng bất kỳ màn hình nào của MetaGym (chữ khó đọc, tràn bố cục, nút quá nhỏ, thiếu nhãn mô tả hoặc lỗi điều hướng bàn phím):
- Mở **GitHub Issue** bằng mẫu **Bug Report** và gắn nhãn liên quan tới module (`mobile-app/`, `admin-web/`, `landing-web/`).
- Hoặc liên hệ trực tiếp Maintainer qua email: **minhthong0610.it@gmail.com**.
