# TASKS — Lộ trình nâng cấp WebAdmin & Image Server

## Phase 1: Architecture & Database
- [x] Phân tích hiện trạng `admin-web/`, `backend/`, `database/` và thiết kế kiến trúc tổng thể.
- [x] Tạo bộ tài liệu: `PROJECT_PLAN.md`, `DATABASE_DESIGN.md`, `API_DOCUMENTATION.md`, `TASKS.md`.
- [ ] Viết SQL migration `0034_image_server_core.up.sql` & `.down.sql` (`roles`, `storage_providers`, `folders`, `images`, `image_variants`, `albums`, `album_images`, `tags`, `image_tags`).
- [ ] Viết SQL migration `0035_image_server_sharing_api_analytics.up.sql` & `.down.sql` (`share_links`, `api_keys`, `api_logs`, `image_views`, `system_settings`, mở rộng quota trên `users`).
- [ ] Chạy `npm run db:migrate` kiểm tra up/down sạch sẽ.

## Phase 2: Authentication, RBAC & User Management
- [ ] Chuẩn hóa RBAC (`super_admin`, `admin`, `user`) ở middleware backend.
- [ ] Bổ sung API & UI quản lý quota dung lượng từng user, khóa/mở khóa tài khoản, phân quyền.
- [ ] Hoàn thiện luồng đăng ký, quên/đổi mật khẩu, cập nhật profile trên WebAdmin.

## Phase 3: Image Upload, Storage & Processing
- [ ] Xây dựng validator kiểm tra MIME thực tế (magic bytes) & sanitize SVG.
- [ ] Nâng cấp `sharp` pipeline: lưu bản gốc theo UUID, tạo thumbnail WebP, tùy chọn WebP/AVIF, đọc EXIF metadata, tính SHA-256 hash.
- [ ] Triển khai cơ chế rollback xóa file vật lý khi DB transaction thất bại.
- [ ] Mở rộng `src/storage/` hỗ trợ `LocalImageStorage`, `SupabaseImageStorage`, và `S3CompatibleStorage` (R2 / AWS S3 / MinIO).
- [ ] Bổ sung endpoint `POST /api/v1/images/upload` (multi-file) và `POST /api/v1/images/import-url`.

## Phase 4: Image Library, Albums, Folders & Tags
- [ ] Xây dựng trang **Image Library** (`admin-web/src/pages/media-library.js`): Grid/List view, Drag & Drop, Paste từ Clipboard, URL Import, Progress bar từng file, Preview trước khi upload.
- [ ] Tìm kiếm, lọc (định dạng, dung lượng, ngày upload, tags), sắp xếp, chọn nhiều ảnh & xóa hàng loạt, Copy URL/Direct Link, Download.
- [ ] Xây dựng **Image Detail Drawer/Modal**: Preview, metadata đầy đủ (ID, filename, original filename, extension, MIME, size, WxH, hash, EXIF, URLs, lịch sử).
- [ ] Xây dựng trang **Albums & Folders** (cây thư mục nhiều cấp, cover album, public/private, di chuyển ảnh) và **Collections & Tags**.

## Phase 5: Image Editor, Sharing & Public API
- [ ] Xây dựng **Image Editor** (Crop, Resize, Rotate, Flip H/V, Compress, Convert format, Quality, Preview trước/sau, lưu thành `image_variants` không ghi đè ảnh gốc).
- [ ] Xây dựng **Sharing** (Public/Private URL, Share Link có thời hạn, Password Protected Link, bật/tắt Download, Thu hồi link).
- [ ] Xây dựng **API Management** (Generate/Revoke API Key, đặt tên, phân quyền scope, rate limit, theo dõi usage & last used).
- [ ] Hoàn thiện Swagger/OpenAPI spec tại `/api-docs` cho toàn bộ `/api/v1/*`.

## Phase 6: Dashboard, Analytics, Storage & System Settings
- [ ] Nâng cấp **Dashboard** với KPI cards & biểu đồ Chart.js dữ liệu thật (tổng ảnh, dung lượng, album, lượt xem, upload trong ngày, biểu đồ theo thời gian).
- [ ] Xây dựng trang **Analytics** (lượt xem thực tế vs bot, top ảnh xem/tải, bandwidth, API requests, HTTP status code).
- [ ] Xây dựng trang **Storage Management** (dung lượng đĩa, theo user/định dạng, cảnh báo gần đầy, quét file mồ côi, backup/restore metadata, kiểm tra Storage Provider).
- [ ] Xây dựng trang **System Settings** (tên web, logo, favicon, upload limits, định dạng cho phép, default visibility, storage provider, image processing, SMTP, rate limit, maintenance mode).

## Phase 7: Testing & Deployment
- [ ] Viết Unit/Integration/API tests cho Auth, Upload, Sharp Processing, Albums, Share Links, API Keys.
- [ ] Viết Security tests (MIME spoofing, SVG XSS payload, Path Traversal, Rate Limiting, RBAC bypass).
- [ ] Kiểm tra UI/UX theo `DESIGN.md` & `admin-web-design` (Desktop 1280px+, Tablet 768px, Mobile 375px, Dark/Light mode).
- [ ] Tạo `Dockerfile`, `docker-compose.yml`, cấu hình **Nginx Reverse Proxy** và hướng dẫn deploy VPS.
