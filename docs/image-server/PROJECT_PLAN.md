# PROJECT PLAN — MetaGym WebAdmin & Image Server Platform

## 1. Tổng quan & Mục tiêu
Nâng cấp **MetaGym WebAdmin (`admin-web/`)** và **Backend (`backend/`)** để tích hợp hoàn chỉnh nền tảng **Image Server – Image Management & Hosting Platform** đạt chuẩn SaaS thương mại:
- Upload, lưu trữ, tối ưu dung lượng, chuyển đổi định dạng, resize/crop và phân phối hình ảnh qua URL (Public / Private / Share Link có mật khẩu & thời hạn).
- Quản lý thư viện hình ảnh (Grid/List, Drag & Drop, Paste Clipboard, URL Import, EXIF, Hash chống trùng lặp), Album & Folder đa cấp, Collections & Tags.
- Chỉnh sửa ảnh không phá hủy bản gốc (lưu thành `image_variants`).
- Cung cấp Public REST API (`/api/v1/*`) với API Key, Scope, Rate Limiting và Swagger/OpenAPI.
- Quản trị toàn diện: Dashboard, Analytics (phân biệt bot vs user), Storage Management (kiểm tra file mồ côi, backup/restore metadata), User & Quota Management, System Settings.

---

## 2. Kiến trúc & Công nghệ (Đồng bộ với MetaGym)

| Thành phần | Công nghệ hiện tại & Mở rộng | Ghi chú kiến trúc |
| :--- | :--- | :--- |
| **Frontend (`admin-web/`)** | Vite (`^8.3.0`), Vanilla JS (ESM), Bootstrap (`^5.3.8`), Chart.js (`^4.5.1`), `qrcode` (`^1.5.4`), Lucide/Bootstrap Icons | Giữ stack Phương án A theo `.agents/skills/admin-web-design/SKILL.md` và `DESIGN.md` / `design-system/meta-gym/MASTER.md` (Dark/Light mode, solid surfaces cho dense data, `#FF5E36`, `Be Vietnam Pro`). |
| **Backend (`backend/`)** | Node.js (`>=22.0.0`, ESM), Express (`^5.3.0`), `pg` (`^8.23.1`), `sharp` (`^0.35.5`), `zod` (`^4.6.7`), `jsonwebtoken`, `bcryptjs`, `helmet`, `swagger-ui-express` | Tách lớp rõ: `routes/`, `controllers/`, `services/`, `repositories/`, `middlewares/`, `validators/`, `storage/`, `workers/`, `config/`. |
| **Database (`database/`)** | PostgreSQL + Raw SQL Migrations (`database/migrations/0034+`) | Tiếp tục chuẩn `.up.sql` / `.down.sql` chạy qua `npm run db:migrate`, tái sử dụng `users`, `audit_logs` sẵn có. |
| **Image Processing** | `sharp` + Magic-bytes MIME validator + SVG Sanitizer | Hỗ trợ JPEG, PNG, WebP, AVIF, GIF, SVG (chính sách bảo mật riêng). Tạo thumbnail & variant bất đồng bộ/đồng bộ, đọc EXIF, SHA-256 hash. |
| **Storage** | `LocalImageStorage`, `SupabaseImageStorage`, `S3CompatibleStorage` (Cloudflare R2 / AWS S3 / MinIO) | Mở rộng `backend/src/storage/image-storage.js` theo Strategy Pattern. Không lưu Base64 trong DB. |
| **Deployment** | Docker, Docker Compose, Nginx Reverse Proxy | Có cấu hình production, HTTPS/reverse proxy, volume persistent cho local storage & PostgreSQL. |

---

## 3. Quy trình xử lý Upload hình ảnh (11 bước chuẩn)
1. Kiểm tra MIME Type thực tế bằng magic bytes (không tin phần mở rộng file).
2. Kiểm tra dung lượng file theo giới hạn hệ thống & quota của user.
3. Kiểm tra tính hợp lệ của file ảnh (và sanitize SVG nếu là SVG).
4. Sinh `UUID` cho hình ảnh.
5. Tạo tên file vật lý an toàn (không dùng `original_filename`, chặn Path Traversal).
6. Lưu ảnh gốc vào Storage Provider đang kích hoạt.
7. Tạo thumbnail (WebP) bằng `sharp`.
8. Tạo phiên bản tối ưu (WebP/AVIF) nếu được bật trong `system_settings`.
9. Đọc kích thước (`width`, `height`), EXIF metadata và tính SHA-256 hash.
10. Lưu metadata + đường dẫn storage vào PostgreSQL (có rollback xóa file nếu DB transaction lỗi).
11. Trả về Image ID, `originalUrl`, `thumbnailUrl`, `width`, `height`, `size`.

---

## 4. Yêu cầu bảo mật bắt buộc
- **Authentication & RBAC**: JWT Access Token + Refresh Token, Password Hashing (`bcryptjs` / Argon2), phân quyền `super_admin`, `admin`, `user`.
- **API & Input Protection**: Zod validation, parameterized SQL queries (`pg`) chống SQL Injection, XSS & CSRF protection, Helmet headers, CORS cấu hình chặt chẽ, Rate Limiting cho Auth & Public API.
- **File & Storage Security**: Magic-bytes MIME check, SVG sanitization (loại bỏ `<script>`, `on*` event handlers, `foreignObject`, external entities), chặn Path Traversal, không expose thư mục nội bộ server, không lộ API Secret (chỉ lưu hash của API Key).
- **Auditability**: Ghi nhận `audit_logs` cho các thao tác nhạy cảm và `api_logs` cho Public API.

---

## 5. Lộ trình triển khai theo 7 Phase

- **Phase 1: Architecture & Database** — Hoàn thiện tài liệu kiến trúc (`PROJECT_PLAN.md`, `DATABASE_DESIGN.md`, `API_DOCUMENTATION.md`, `TASKS.md`), thiết kế và chạy SQL migrations `0034+`.
- **Phase 2: Authentication, RBAC & User Quota** — Hoàn thiện phân quyền `super_admin`/`admin`/`user`, quản lý profile, khóa tài khoản, giới hạn dung lượng (storage quota) từng user.
- **Phase 3: Core Image Upload, Storage & Processing** — Pipeline upload đơn/nhiều ảnh, URL import, magic-bytes MIME, SVG sanitizer, `sharp` thumbnail/WebP/AVIF/EXIF/hash, rollback lỗi, S3-compatible/Local/Supabase adapter.
- **Phase 4: Image Library, Albums, Folders & Tags** — UI & API cho Image Library (Grid/List, Drag & Drop, Paste, Search/Filter/Sort, Bulk actions, Detail Drawer), Albums & Folders đa cấp, Collections & Tags.
- **Phase 5: Image Editor, Sharing & Public API** — Công cụ chỉnh sửa ảnh (Crop, Resize, Rotate, Flip, Compress, Convert format) lưu thành `image_variants`; Share Links (Public/Private, hết hạn, mật khẩu, chặn tải, thu hồi); API Keys & Public REST API `/api/v1/*` + Swagger.
- **Phase 6: Dashboard, Analytics, Storage & System Settings** — Dashboard KPI & biểu đồ Chart.js dữ liệu thật, Analytics (lượt xem, bandwidth, status code, lọc bot), Storage Management (kiểm tra file mồ côi, backup/restore metadata), System Settings.
- **Phase 7: Testing & Deployment** — Unit/Integration/API/Security tests (MIME spoofing, SVG XSS, Path Traversal, Rate limit), tối ưu build `admin-web`, Docker Compose + Nginx Reverse Proxy + hướng dẫn deploy VPS.

---

## 6. Tiêu chuẩn hoàn thành (Definition of Done)
Một tính năng chỉ được xem là hoàn thành khi:
1. Frontend hoạt động thực tế (không reload trang khi CRUD, có Loading Skeleton, Empty/Error/Success states, Confirm modal trước khi xóa).
2. Backend API hoạt động thực tế với Validation (Zod) & Error Handling chuẩn.
3. Database lưu dữ liệu đúng chuẩn, có migration `.up.sql` & `.down.sql`.
4. Không có dữ liệu giả (mock data) hay nút bấm vô tác dụng.
5. Có test cơ bản (unit/integration) và build sạch (`npm run build`, `npm test`).
