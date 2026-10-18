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

Backend mặc định chạy tại `http://localhost:3000`. Kiểm tra bằng `GET /health`.

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

Dự án mới chỉ có khung kỹ thuật và dependency nền. Chưa có schema PostgreSQL, dữ liệu mẫu hay nghiệp vụ.
