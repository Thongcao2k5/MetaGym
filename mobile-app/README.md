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

## Kiểm tra

```powershell
F:\flutter\bin\flutter.bat analyze
F:\flutter\bin\flutter.bat test
```
