# Triển khai Meta Gym bằng Supabase Free

Việc chuyển đổi được thực hiện từng bước để bản local luôn sử dụng được. Không
đưa khóa bí mật hoặc mật khẩu database vào Git, Flutter hay Admin Web.

## Bước 1 — Supabase Storage

Backend đã hỗ trợ đồng thời hai chế độ:

- Local: dùng `MEDIA_STORAGE_DIR` như trước.
- Supabase: được ưu tiên khi cấu hình đủ ba biến `SUPABASE_*`.

### Tạo bucket

1. Tạo một project tại <https://supabase.com/dashboard>.
2. Mở **Storage**, tạo bucket tên `meta-gym-media`.
3. Để bucket ở chế độ **Private**.
4. Đặt giới hạn file là `5 MB`.
5. Chỉ cho phép MIME type `image/jpeg` và `image/png`.

Ảnh chỉ được backend đọc và ghi bằng secret key. Flutter không kết nối trực
tiếp tới bucket; API Meta Gym tiếp tục kiểm tra quyền và cấp URL ảnh ngắn hạn.

### Cấu hình backend local

Trong `backend/.env`, để trống `MEDIA_STORAGE_DIR` và điền:

```dotenv
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_SECRET_KEY=sb_secret_REPLACE_ME
SUPABASE_STORAGE_BUCKET=meta-gym-media
```

Lấy **Project URL** và **Secret key** trong phần API Keys của Supabase. Chỉ dùng
secret key mới có tiền tố `sb_secret_` trên backend. Không gửi khóa qua chat,
không đặt nó trong `mobile-app`, `admin-web` hoặc file đã được Git theo dõi.

Nếu chưa điền các biến trên, backend vẫn dùng local storage như trước. Nếu chỉ
điền một phần, backend sẽ dừng ngay và báo cấu hình chưa đầy đủ.

### Kiểm tra

```powershell
cd F:\AndroidProjects\MetaGym-supabase\backend
npm run check
npm test
npm start
```

Sau đó đăng nhập Member hoặc Coach và gửi một ảnh trong tin nhắn. Bảng
`media_assets` vẫn lưu metadata và quyền sở hữu; byte ảnh được lưu trong bucket
`meta-gym-media`.

## Các bước tiếp theo

1. Chuyển PostgreSQL sang database Supabase bằng migrations hiện có.
2. Triển khai backend Express lên Render Free.
3. Triển khai Flutter Web và Admin Web lên Cloudflare Pages.
4. Sau khi ba phần trên ổn định mới thay polling bằng realtime.

Tài liệu chính thức:

- <https://supabase.com/docs/guides/getting-started/api-keys>
- <https://supabase.com/docs/guides/storage/security/access-control>
- <https://supabase.com/docs/reference/javascript/storage-from-upload>
- <https://supabase.com/docs/reference/javascript/file-buckets-download>
