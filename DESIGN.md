---
name: Meta Gym
description: Futuristic Performance Glass for the Member and Coach app, with stable graphite work surfaces and restrained warm optical glass.
colors:
  canvas: "#0F1115"
  card: "#181B22"
  elevated-card: "#1F242D"
  card-border: "#262A34"
  primary: "#FF5E36"
  on-primary: "#FFFFFF"
  text-primary: "#FFFFFF"
  text-secondary: "#8E95A5"
  success: "#2ECC71"
  warning: "#F39C12"
  coach-avatar: "#F5B041"
  on-coach-avatar: "#181B22"
  reflection: "#A9C7E8"
typography:
  heading:
    fontFamily: Be Vietnam Pro
    fontSize: 24px
    fontWeight: 700
    lineHeight: 1.25
  title:
    fontFamily: Be Vietnam Pro
    fontSize: 17px
    fontWeight: 600
    lineHeight: 1.35
  body:
    fontFamily: Be Vietnam Pro
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: Be Vietnam Pro
    fontSize: 12px
    fontWeight: 600
    lineHeight: 1.35
rounded:
  control: 14px
  card: 20px
  glass-dock: 24px
spacing:
  base: 4px
  rhythm: 8px
  phone-gutter: 16px
  section: 20px
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.control}"
    height: 48px
  card-default:
    backgroundColor: "{colors.card}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.card}"
  card-elevated:
    backgroundColor: "{colors.elevated-card}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.card}"
  card-divider:
    backgroundColor: "{colors.card-border}"
    height: 1px
  secondary-copy:
    backgroundColor: "{colors.card}"
    textColor: "{colors.text-secondary}"
    typography: "{typography.body}"
  status-success:
    backgroundColor: "{colors.success}"
    textColor: "{colors.canvas}"
  status-warning:
    backgroundColor: "{colors.warning}"
    textColor: "{colors.canvas}"
  reflection-icon:
    backgroundColor: "{colors.card}"
    textColor: "{colors.reflection}"
  app-canvas:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.text-primary}"
  coach-avatar:
    backgroundColor: "{colors.coach-avatar}"
    textColor: "{colors.on-coach-avatar}"
---

# Meta Gym — Design Rules

## Overview

**Futuristic Performance Glass**: hiện đại, sang trọng, mạnh mẽ và rõ ràng khi sử dụng. Member và Coach là giao diện dark-first. Kính màu ấm tạo chiều sâu ở Trang chủ, thanh điều hướng và một số card nổi bật; màn nhập liệu, danh sách dài, lịch sử và biểu đồ dùng bề mặt graphite ổn định. Admin ưu tiên bề mặt đặc để đọc dữ liệu nhanh.

Đây là rule thiết kế cho sản phẩm, không phải lệnh đổi toàn bộ màn hiện có. Bản thiết kế người dùng đã chốt và luồng nghiệp vụ đã xác nhận được giữ nguyên khi chỉ tinh chỉnh một thành phần. Trước khi thiết kế, đọc màn hiện tại, trạng thái dữ liệu và yêu cầu cụ thể của màn đó.

## Colors

| Vai trò | Màu | Cách dùng |
| --- | --- | --- |
| Canvas | `#0F1115` | Nền mặc định |
| Card | `#181B22` | Nội dung và danh sách |
| Card nâng | `#1F242D` | Phân cấp bề mặt khi cần |
| Viền card | `#262A34`, 1px | Ngăn cách nhẹ |
| Cam chính | `#FF5E36` | CTA chính, mục active, tiến trình quan trọng |
| Trên nền cam | `#FFFFFF` | **Mọi chữ và icon trên nút cam** |
| Chữ chính | `#FFFFFF` | Tiêu đề và dữ liệu quan trọng |
| Chữ phụ | `#8E95A5` | Mô tả, metadata, trạng thái chưa diễn ra |
| Hoàn thành/hiệu lực | `#2ECC71` | Trạng thái tích cực và dinh dưỡng |
| Cảnh báo | `#F39C12` | Trạng thái cần chú ý |
| Avatar Coach LN | nền `#F5B041`, chữ `#181B22` đậm | Đồng nhất trên mọi màn |

Cam không dùng làm màu nền cho nhiều card cùng lúc. Mỗi vùng quyết định chỉ có một CTA nổi bật. Trạng thái luôn có chữ hoặc biểu tượng đi kèm màu. Không đưa chữ đen lên nền cam. Màu ảnh nền không được làm đổi nghĩa các token semantic.

Chữ trắng trên cam này đạt khoảng 3:1, phù hợp cho nhãn lớn/đậm và icon nhưng chưa đạt 4.5:1 cho chữ nhỏ. Vì vậy nút cam đặc dùng nhãn tối thiểu khoảng 19px đậm; hành động nhỏ dùng chữ cam trên nền graphite hoặc nút viền. Giữ đúng cặp màu người dùng đã chốt.

## Typography

Dùng **Be Vietnam Pro** đã đóng gói trong ứng dụng. Cấp độ tham khảo: tiêu đề màn 24px/700; tên card 17px/600; nội dung 14–16px/400; nhãn phụ 12–13px/400–600. Số liệu chính có thể lớn hơn nhưng chỉ khi thực sự là trọng tâm. Không in đậm toàn bộ card. Dùng chữ thường theo câu, giữ nguyên dấu tiếng Việt, và tabular figures cho thời gian, cân nặng, mức tạ, giá, số buổi.

Văn bản ưu tiên ngắn, chính xác với luồng thật. Một card trả lời một câu hỏi chính. Tên Coach, thời hạn gói và CTA không được cắt mất nghĩa; cho xuống dòng hoặc mở chi tiết thay vì cố nhét một hàng.

## Layout

Lề điện thoại 16px; khoảng cách cùng nhóm 8–12px; khoảng cách giữa các section 20–24px; padding card 16–20px. Một màn có một điểm nhìn chính, sau đó là các bước tiếp theo theo thứ tự sử dụng. Card cùng hàng phải cân chiều cao và mật độ thông tin. Không tạo card cao chỉ để chứa ít chữ, không lồng nhiều viền/card khi một divider hoặc khoảng trắng là đủ.

Nút điều hướng Member giữ đúng năm mục: Trang chủ, Tập luyện, AI, Tin nhắn, Hồ sơ. Card mở trang khác không được tô như trạng thái chọn lâu dài. Nội dung cuộn phải chừa khoảng cho thanh điều hướng, safe area và bàn phím.

## Elevation & Depth

Bề mặt mặc định là graphite đặc. **Warm smoked glass** chỉ dùng khi có ảnh nền thực sự nhìn qua và hiệu ứng giúp tạo phân cấp: Trang chủ, thanh điều hướng, card nổi bật. Giữ ảnh phòng gym đủ nhận ra nhưng tăng độ đục của card trước khi hy sinh độ rõ của chữ. Màu kính ấm phải cùng tông với ánh đèn và sàn trong ảnh nền, có viền sáng mảnh và một highlight trên cạnh trên; tránh lớp xám bạc đục hoặc nền quá trong.

Mẫu tham chiếu hiện tại trên Trang chủ Flutter: fill `0xC42B2622` cho card thường, `0xB82D2824` cho card nổi bật, viền ấm `0xA3A79D92`; kính nổi bật dùng blur khoảng 10–12px và có fallback không blur. Đây là giá trị của màn đã duyệt, không phải lệnh sao chép blur sang mọi card. Không lồng hai vùng blur. Không animate blur. Ảnh nền phải có lớp tối và fallback màu canvas.

## Shapes

Control khoảng 14px; card tiêu chuẩn 20px; dock/sheet kính 24px. Viền thường 1px; viền chọn hoặc focus được tăng rõ khi cần. Icon dùng cùng một họ vector, nét 1.75–2px; không dùng emoji làm icon chức năng. Avatar Coach LN luôn giữ đúng cặp màu đã chốt.

## Components

- **CTA chính:** cam, chữ/icon trắng, mục đích rõ. Các trạng thái pressed, loading, disabled và lỗi phải nhận biết được.
- **Card thông tin:** nền graphite hoặc kính theo vai trò của màn; toàn card chỉ bấm được khi có đúng một đích.
- **Chips:** nhỏ, dễ đọc; màu xanh chỉ cho trạng thái hoàn thành/hiệu lực, màu vàng cho cảnh báo. Đừng biến mọi nhãn thành nút.
- **Form, bảng, lịch, biểu đồ:** bề mặt đặc, độ tương phản ổn định, thứ tự đọc rõ. Kính không nằm sau đoạn văn dài hoặc ô nhập liệu.
- **Thanh điều hướng:** kính có giới hạn blur, mục active rõ bằng cả icon và nhãn; AI có thể nổi bật nhưng không che bốn mục còn lại.
- **Ảnh và nền:** dùng asset thật của dự án, crop có chủ ý, che tối đủ đọc; không dùng hình minh họa không liên quan chỉ để lấp chỗ trống.

## Do's and Don'ts

**Làm:** kiểm tra màn ở 375px, điện thoại lớn và landscape; kiểm tra loading, empty, error, disabled, offline và trạng thái nghiệp vụ tương ứng; giữ touch target tối thiểu 48dp trên Android; kiểm tra chữ thường tối thiểu 4.5:1 và thành phần tương tác 3:1 trên ảnh đã ghép; tôn trọng text scaling và reduced motion; chụp giao diện thật để so với bản người dùng đã chốt.

**Tránh:** cyberpunk, neon nhiều màu, HUD/game, kính trên mọi card, glow quanh mọi CTA, chữ quá đậm, icon không đồng bộ, màu hex tùy tiện, nút thật sự không có tác dụng, dữ liệu hoặc trạng thái bịa cho đẹp. Không đưa các thành phần người dùng đã yêu cầu bỏ trở lại màn chỉ để lấp khoảng trống.

**Hiệu năng demo:** ảnh nền nén và precache, vùng blur được clip, không blur toàn màn khi cuộn, không parallax hoặc hiệu ứng chạy liên tục. Nếu hiệu năng giảm, dùng fallback kính đặc; giữ độ rõ chữ và bố cục trước hiệu ứng.

## Source of truth and review

`DESIGN.md` là rule toàn dự án. `mobile-app/lib/core/theme/app_theme.dart` là token đã triển khai trong Flutter; khi hai nơi lệch nhau, đối chiếu quyết định mới nhất của người dùng rồi đồng bộ, không âm thầm dùng giá trị cũ. `design-system/meta-gym/MASTER.md` là bản tóm tắt. Các adapter mẫu cũ không được copy trực tiếp vào app.

Với mỗi màn mới: xác định vai trò và trạng thái của màn → phác bố cục → dựng preview nếu người dùng yêu cầu duyệt trước → xem ảnh render ở kích thước thiết bị → triển khai bằng token chung → kiểm tra các trạng thái và hiệu năng. Thay đổi được chấp nhận khi giữ đúng nghiệp vụ, đọc rõ, đồng nhất với Trang chủ đã chốt và vận hành mượt trên thiết bị demo.
