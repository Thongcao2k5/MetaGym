# Meta Gym

Khung dự án đồ án chuyên ngành Meta Gym.

## Thành phần

- `mobile-app/`: Flutter dành cho Member và Coach.
- `admin-web/`: HTML, CSS, JavaScript, Bootstrap và Chart.js, chạy bằng Vite.
- `backend/`: Node.js, Express và PostgreSQL client.
- `database/`: nơi đặt migration và tài liệu cơ sở dữ liệu sau này.
- `docs/`: tài liệu yêu cầu và kiến trúc.

## Chạy từng phần

### Backend

```powershell
cd backend
Copy-Item .env.example .env
npm run dev
```

Trước khi chạy backend, tạo database và chạy migration theo [hướng dẫn database](database/README.md). Backend mặc định chạy tại `http://localhost:3000`. Kiểm tra kết nối API và PostgreSQL bằng `GET /api/v1/health`.

### Admin web

```powershell
cd admin-web
npm run dev
```

### Flutter mobile

```powershell
cd mobile-app
F:\flutter\bin\flutter.bat run
```

## Trạng thái hiện tại

Dự án đã có schema PostgreSQL gồm 33 bảng, baseline seed, API health và luồng đăng ký/đăng nhập có giới hạn thử đăng nhập. Các API nghiệp vụ còn lại và dữ liệu demo chưa được triển khai.
