# Meta Gym Admin web

Admin web là ứng dụng Vite dùng JavaScript modules, Bootstrap và Chart.js. Trong
môi trường phát triển, chạy backend tại `http://127.0.0.1:3000`, sau đó:

```bash
npm ci
npm run dev
```

Vite chuyển tiếp `/api` tới backend. Khi triển khai ở origin khác, đặt
`VITE_API_BASE_URL` thành URL của API có hậu tố `/api/v1` trước khi build.
Không đặt JWT secret hoặc mật khẩu vào biến Vite vì chúng sẽ xuất hiện trong
JavaScript gửi tới trình duyệt. Access token Admin chỉ được giữ trong
`sessionStorage` của tab và bị xóa khi đăng xuất hoặc đổi mật khẩu.

```bash
npm run build
npm test
```

`npm test` kiểm tra thao tác khóa/mở tài khoản và payload gửi tới API, gồm
lý do khóa bắt buộc và các trường hợp hủy nhập.

Tài khoản đăng nhập phải có vai trò `ADMIN`. Backend chịu trách nhiệm kiểm tra
vai trò và trạng thái tài khoản ở mỗi yêu cầu.
