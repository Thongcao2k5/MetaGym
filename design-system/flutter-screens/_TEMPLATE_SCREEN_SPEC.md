# [Tên Màn Hình] — Thiết kế & Mockup

- **Vai trò:** Member / Coach / Shared
- **File Flutter liên quan:** `mobile-app/lib/features/...`
- **Mockup đính kèm:** `../mockups/<role>-<screen-name>.png` (hoặc `.html`)
- **Trạng thái:** Draft / In Review / Approved / Implemented

---

## 1. Mục tiêu & Điểm nhấn thị giác (3-Second Focus)
- **Người dùng cần làm gì chính trên màn hình này?**
- **Focal point đầu tiên (nhận diện trong 3 giây):**
- **CTA chính duy nhất (Coral Orange `#FF5E36`):**

## 2. Vấn đề hiện tại (nếu là màn hình Fix / Update)
- [ ] Vấn đề 1: ...
- [ ] Vấn đề 2: ...

## 3. Bố cục & Phân bổ vật liệu (80/20 Rule)
- **Level 0 — Canvas:** `#0F1115` (+ ảnh nền tĩnh phủ scrim 72–84% nếu có)
- **Level 1 — Solid Surface (>= 80%):** `#181B22`, viền 1px `#262A34`, radius `20px` (dùng cho thẻ nội dung, form, danh sách)
- **Level 2 — Performance Glass (<= 20%):** `rgba(24, 27, 34, 0.78)`, blur `12px`, radius `24px` (chỉ cho dock, thanh lọc nổi, bottom nav; không lồng blur)
- **Level 3 — Overlay Glass:** `rgba(15, 17, 21, 0.90)`, blur `18px` + scrim (chỉ cho dialog/sheet/AI overlay)

### Cấu trúc phân tầng từ trên xuống dưới
1. **Header:** ...
2. **Hero / Khu vực chính:** ...
3. **Nội dung chi tiết / Danh sách:** ...
4. **Bottom CTA / Navigation clearance:** ...

## 4. Token & Typography (Be Vietnam Pro)
- **Tiêu đề màn hình:** `headline-md` / `title-lg` (`#F7F9FC`)
- **Nội dung chính:** `body-lg` / `body-md` (`#F7F9FC`)
- **Metadata / Phụ:** `body-md` / `label-md` (`#8E95A5`)
- **Số liệu / Thời gian / Giá:** bật `tabularFigures` (`tnum`)
- **Màu trạng thái:** Success `#2ECC71`, Warning `#F39C12`, Error `#F15B64`, Info `#70AEE8`

## 5. Các trạng thái bắt buộc
- **Loading:** Skeleton / indicator phù hợp
- **Empty:** Thông điệp rõ ràng + CTA hướng dẫn
- **Error / Offline:** Thông báo ngắn gọn + nút Thử lại
- **Disabled / Submitting:** Giữ chữ dễ đọc, chặn bấm trùng
- **Success:** Phản hồi rõ ràng (snackbar/badge/transition)

## 6. Checklist Nghiệm thu (`DESIGN.md`)
- [ ] Điểm nhấn đầu tiên rõ ràng trong 3 giây.
- [ ] >= 80% bề mặt đặc, không lồng lớp blur.
- [ ] Màu cam `#FF5E36` chỉ chiếm ~5–10%, dành cho CTA / active / tiến độ chính.
- [ ] Tương phản chữ >= 4.5:1; thành phần phi văn bản >= 3:1.
- [ ] Vùng chạm (touch target) >= 44pt iOS / 48dp Android.
- [ ] Không lỗi overflow trên màn 375px, xoay ngang và text scaling hệ thống.
- [ ] Tôn trọng Reduced Motion & chế độ dự phòng không blur.
- [ ] Không bị che bởi status bar, bàn phím ảo hoặc thanh điều hướng đáy.
