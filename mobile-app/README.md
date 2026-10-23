# Meta Gym mobile

Ứng dụng Flutter được chia theo hai lớp chính:

- `lib/app`: khai báo ứng dụng và router.
- `lib/core`: cấu hình API, theme và API client dùng chung.
- `lib/features`: mã theo từng nghiệp vụ công khai, Member và Coach.

## Chạy theo môi trường

Android emulator dùng địa chỉ backend `http://10.0.2.2:3000/api/v1`:

```powershell
F:\flutter\bin\flutter.bat run --dart-define=APP_ENV=emulator
```

Flutter web hoặc Windows chạy cùng máy backend dùng loopback:

```powershell
F:\flutter\bin\flutter.bat run -d chrome --dart-define=APP_ENV=local
```

Production bắt buộc truyền URL HTTPS, không có URL mặc định:

```powershell
F:\flutter\bin\flutter.bat run --release `
  --dart-define=APP_ENV=production `
  --dart-define=API_BASE_URL=https://api.your-domain.com/api/v1
```

Có thể truyền `API_BASE_URL` để ghi đè URL ở môi trường local hoặc emulator.

API client chuẩn hóa response `{data, pagination?}` và chuyển lỗi mạng, xác
thực, phân quyền, validation hoặc lỗi máy chủ thành `ApiException`. Log mạng
chỉ chứa phương thức, trạng thái và loại lỗi; không ghi header hoặc body.

## Khung kiểm thử luồng Member và Coach

Ở môi trường `local` hoặc `emulator`, sau khi đăng nhập hãy mở nút **Kiểm thử
các luồng** trên trang chính. Các nhóm chức năng dẫn tới biểu mẫu gọi API thật:
điền mã đối tượng lấy từ phản hồi bước trước, chỉnh JSON theo hợp đồng API tại
`docs/requirements/api-contract.md`, rồi bấm **Thực hiện**. Màn hình thể hiện
đang tải, lỗi, dữ liệu rỗng và phản hồi có phân trang. Thao tác xóa có xác nhận.
Khung này tự ẩn và không thể mở qua router trong `APP_ENV=production`.

Khung ưu tiên kiểm thử tích hợp, chưa phải giao diện sản phẩm cuối. Phần tải ảnh
multipart lên `/media/images` và gọi thoại/video trực tiếp qua SDK chưa có;
chỉ kiểm thử được metadata cuộc gọi và URL ảnh. Chức năng AI/token cuộc gọi sẽ
trả 503 nếu backend chưa cấu hình dịch vụ tương ứng. Các biểu mẫu JSON là mẫu
khởi đầu; mã UUID của Coach/Member/quan hệ/ảnh phải thay bằng mã thật.

Trang chính Member và Coach có danh mục điều hướng theo vai trò. Các mục chưa
được làm ở UI02–UI27 hiện mở trang giữ chỗ ghi mã task tương ứng, không gọi API
và không được xem là tính năng đã hoàn thành. Khung JSON vẫn là công cụ phụ
trong môi trường phát triển.

## Kiểm tra

```powershell
F:\flutter\bin\flutter.bat analyze
F:\flutter\bin\flutter.bat test
```
