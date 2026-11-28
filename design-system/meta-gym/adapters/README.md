# Bộ Chuyển đổi Theme Meta Gym (Theme Adapters)

Các tệp trong thư mục này chuyển đổi bộ token từ tệp chuẩn gốc `DESIGN.md` sang hai nền tảng giao diện của dự án. `DESIGN.md` vẫn luôn là nguồn chuẩn cao nhất.

## Flutter (Ứng dụng Di động)

Tệp `meta_gym_theme.dart.example` là adapter mẫu để tham khảo, không phải mã ứng dụng đang chạy. Đuôi `.example` giúp Dart analyzer không phân tích tệp nằm ngoài package Flutter như mã nguồn thực thi.

Theme hiện tại của ứng dụng nằm tại [`mobile-app/lib/core/theme/app_theme.dart`](../../../mobile-app/lib/core/theme/app_theme.dart). Không sao chép adapter mẫu đè lên theme này; khi sửa giao diện Meta Gym, dùng theme và component hiện hành của ứng dụng.

Nếu tái sử dụng mẫu cho một ứng dụng Flutter khác, sao chép vào package của ứng dụng đó, đổi đuôi về `.dart` và điều chỉnh theo phiên bản Flutter đang dùng. Ví dụ cấu hình:

```dart
MaterialApp.router(
  theme: MetaGymTheme.light,
  darkTheme: MetaGymTheme.dark,
  themeMode: ThemeMode.system,
  routerConfig: router,
);
```

Đóng gói phông chữ **Be Vietnam Pro** dưới dạng tệp tài nguyên nội bộ (local variable-font asset) và giữ chính xác tên họ phông `Be Vietnam Pro` trong `pubspec.yaml`. Dùng tài nguyên nội bộ giúp tránh tải phông qua mạng khi chạy ứng dụng và đảm bảo hoạt động ổn định khi mất kết nối (offline).

Sử dụng `go_router` khi dựng cấu trúc điều hướng của ứng dụng Flutter. Hội viên (Member) và Huấn luyện viên (Coach) có thể có cây định tuyến (route tree) riêng, nhưng cả hai đều phải dùng định tuyến khai báo (declarative routing), hành vi nút quay lại nhất quán và không vượt quá 5 mục đích cấp cao nhất trên thanh điều hướng di động.

## Bootstrap Admin (Cổng Quản trị Web)

Nạp Bootstrap 5.3 trước, sau đó nạp `bootstrap-theme.css` để các biến màu và phần ghi đè component của Meta Gym có độ ưu tiên cao hơn trong CSS cascade:

```js
import 'bootstrap/dist/css/bootstrap.min.css';
import './styles/bootstrap-theme.css';
```

Thiết lập `data-bs-theme="light"` hoặc `data-bs-theme="dark"` trên phần tử gốc của tài liệu (`<html>`). Sử dụng tùy chọn hệ thống làm giá trị khởi tạo và lưu lại lựa chọn chủ động của người dùng.

Tự lưu trữ (self-host) phông **Be Vietnam Pro** bằng `@font-face` trước tệp theme này. Không dùng liên kết stylesheet trực tuyến của Google Fonts trên môi trường production.

Ứng dụng Flutter mang trọn vẹn bản sắc nền tối **Futuristic Performance Glass**. Cổng Quản trị Admin chủ động ưu tiên các bề mặt đặc của Bootstrap vì giao diện dữ liệu mật độ cao cần độ tương phản ổn định và chi phí kết xuất (rendering cost) thấp.

## Kiểm tra hợp lệ (Validation)

Chạy lệnh sau mỗi khi thay đổi các design token:

```powershell
designmd lint DESIGN.md
```

Mức chuẩn hiện tại là 0 lỗi (zero errors) và 0 cảnh báo (zero warnings).
