# TASKS — Lộ trình nâng cấp WebAdmin & Image Server

## Phase 1: Architecture & Database
- [x] Phân tích hiện trạng `admin-web/`, `backend/`, `database/` và thiết kế kiến trúc tổng thể.
- [x] Tạo bộ tài liệu: `PROJECT_PLAN.md`, `DATABASE_DESIGN.md`, `API_DOCUMENTATION.md`, `TASKS.md`.
- [x] Viết SQL migration `0034_image_server_core.up.sql` & `.down.sql` (`roles`, `storage_providers`, `folders`, `images`, `image_variants`, `albums`, `album_images`, `tags`, `image_tags`).
- [x] Viết SQL migration `0035_image_server_sharing_api_analytics.up.sql` & `.down.sql` (`share_links`, `api_keys`, `api_logs`, `image_views`, `system_settings`, mở rộng quota trên `users`).
- [x] Chạy `npm run db:migrate` kiểm tra up/down sạch sẽ.

## Phase 2: Authentication, RBAC & User Management
- [x] Chuẩn hóa RBAC (`super_admin`, `admin`, `user`) ở middleware backend.
- [x] Bổ sung API & UI quản lý quota dung lượng từng user, khóa/mở khóa tài khoản, phân quyền.
- [x] Hoàn thiện luồng đăng ký, quên/đổi mật khẩu, cập nhật profile trên WebAdmin.

## Phase 3: Image Upload, Storage & Processing
- [x] Xây dựng validator kiểm tra MIME thực tế (magic bytes) & sanitize SVG.
- [x] Nâng cấp `sharp` pipeline: lưu bản gốc theo UUID, tạo thumbnail WebP, tùy chọn WebP/AVIF, đọc EXIF metadata, tính SHA-256 hash.
- [x] Triển khai cơ chế rollback xóa file vật lý khi DB transaction thất bại.
- [x] Mở rộng `src/storage/` hỗ trợ `LocalImageStorage`, `SupabaseImageStorage`, và `S3CompatibleStorage` (R2 / AWS S3 / MinIO).
- [x] Bổ sung endpoint `POST /api/v1/images/upload` (multi-file) và `POST /api/v1/images/import-url`.

## Phase 4: Image Library, Albums, Folders & Tags
- [x] Xây dựng trang **Image Library** (`admin-web/src/pages/media-library.js`): Grid/List view, Drag & Drop, Paste từ Clipboard, URL Import, Progress bar từng file, Preview trước khi upload.
- [x] Tìm kiếm, lọc (định dạng, dung lượng, ngày upload, tags), sắp xếp, chọn nhiều ảnh & xóa hàng loạt, Copy URL/Direct Link, Download.
- [x] Xây dựng **Image Detail Drawer/Modal**: Preview, metadata đầy đủ (ID, filename, original filename, extension, MIME, size, WxH, hash, EXIF, URLs, lịch sử).
- [x] Xây dựng trang **Albums & Folders** (cây thư mục nhiều cấp, cover album, public/private, di chuyển ảnh) và **Collections & Tags**.

## Phase 5: Image Editor, Sharing & Public API
- [x] Xây dựng **Image Editor** (Crop, Resize, Rotate, Flip H/V, Compress, Convert format, Quality, Preview trước/sau, lưu thành `image_variants` không ghi đè ảnh gốc).
- [x] Xây dựng **Sharing** (Public/Private URL, Share Link có thời hạn, Password Protected Link, bật/tắt Download, Thu hồi link).
- [x] Xây dựng **API Management** (Generate/Revoke API Key, đặt tên, phân quyền scope, rate limit, theo dõi usage & last used).
- [x] Hoàn thiện Swagger/OpenAPI spec tại `/api-docs` cho toàn bộ `/api/v1/*`.

## Phase 6: Dashboard, Analytics, Storage & System Settings
- [x] Nâng cấp **Dashboard** với KPI cards & biểu đồ Chart.js dữ liệu thật (tổng ảnh, dung lượng, album, lượt xem, upload trong ngày, biểu đồ theo thời gian).
- [x] Xây dựng trang **Analytics** (lượt xem thực tế vs bot, top ảnh xem/tải, bandwidth, API requests, HTTP status code).
- [x] Xây dựng trang **Storage Management** (dung lượng đĩa, theo user/định dạng, cảnh báo gần đầy, quét file mồ côi, backup/restore metadata, kiểm tra Storage Provider).
- [x] Xây dựng trang **System Settings** (tên web, logo, favicon, upload limits, định dạng cho phép, default visibility, storage provider, image processing, SMTP, rate limit, maintenance mode).

## Phase 7: Testing & Deployment
- [x] Viết Unit/Integration/API tests cho Auth, Upload, Sharp Processing, Albums, Share Links, API Keys.
- [x] Viết Security tests (MIME spoofing, SVG XSS payload, Path Traversal, Rate Limiting, RBAC bypass).
- [x] Kiểm tra UI/UX theo `DESIGN.md` & `admin-web-design` (Desktop 1280px+, Tablet 768px, Mobile 375px, Dark/Light mode).
- [ ] Tạo `Dockerfile`, `docker-compose.yml`, cấu hình **Nginx Reverse Proxy** và hướng dẫn deploy VPS.
