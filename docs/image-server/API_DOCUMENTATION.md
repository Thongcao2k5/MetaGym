# API DOCUMENTATION — Image Server & WebAdmin REST API (`/api/v1`)

> **Tài liệu tương tác**: Tích hợp sẵn qua `swagger-ui-express` tại `/api-docs`.
> **Xác thực**:
> - WebAdmin / User Session: `Authorization: Bearer <access_token>` (JWT)
> - External Integration: `X-API-Key: <api_key>`

---

## 1. Quy ước Response chuẩn
Mọi endpoint trả về cấu trúc thống nhất:
```json
{
  "success": true,
  "data": {},
  "meta": { "page": 1, "limit": 24, "total": 120 },
  "error": null
}
```
Khi lỗi:
```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "INVALID_MIME_TYPE",
    "message": "Định dạng file không hợp lệ hoặc không được phép."
  }
}
```

---

## 2. Authentication & User Management
- `POST /api/v1/auth/register` — Đăng ký tài khoản
- `POST /api/v1/auth/login` — Đăng nhập (trả về Access Token & Refresh Token)
- `POST /api/v1/auth/refresh` — Làm mới Access Token
- `POST /api/v1/auth/logout` — Đăng xuất / thu hồi Refresh Token
- `POST /api/v1/auth/forgot-password` & `POST /api/v1/auth/reset-password` — Quên & đặt lại mật khẩu
- `GET /api/v1/users/me` & `PATCH /api/v1/users/me` — Xem & cập nhật profile
- `POST /api/v1/users/me/change-password` — Đổi mật khẩu
- `GET /api/v1/admin/users` — Danh sách user + dung lượng đã dùng/quota
- `PATCH /api/v1/admin/users/:id` — Phân quyền (`super_admin`, `admin`, `user`), khóa/mở khóa tài khoản, cập nhật `storage_quota_bytes`

---

## 3. Image Upload & Management
- `POST /api/v1/images/upload` — Upload 1 hoặc nhiều ảnh (`multipart/form-data`, hỗ trợ `folderId`, `albumId`, `visibility`, `tags`). Trả về:
  ```json
  {
    "success": true,
    "data": {
      "id": "uuid",
      "filename": "photo.webp",
      "originalUrl": "https://domain.com/storage/original/uuid.jpg",
      "thumbnailUrl": "https://domain.com/storage/thumbnails/uuid.webp",
      "width": 1920,
      "height": 1080,
      "size": 245000
    }
  }
  ```
- `POST /api/v1/images/import-url` — Upload ảnh từ URL bên ngoài (nếu bật trong System Settings)
- `GET /api/v1/images` — Danh sách ảnh (hỗ trợ `q`, `format`, `minSize`, `maxSize`, `fromDate`, `toDate`, `tag`, `albumId`, `folderId`, `sortBy`, `order`, `page`, `limit`)
- `GET /api/v1/images/:id` — Chi tiết ảnh (kèm `variants`, `tags`, `exif_data`, `sha256_hash`, URLs, lịch sử thao tác)
- `PATCH /api/v1/images/:id` — Đổi tên, cập nhật mô tả, visibility, di chuyển folder/album, gắn tags
- `DELETE /api/v1/images/:id` — Soft delete (hoặc `?permanent=true` để xóa vĩnh viễn)
- `POST /api/v1/images/bulk-delete` — Xóa nhiều ảnh cùng lúc (`{ ids: [...] }`)
- `GET /api/v1/images/:id/download` — Tải ảnh (ghi nhận `download_count`)

---

## 4. Image Editor & Variants (Không ghi đè ảnh gốc)
- `POST /api/v1/images/:id/transform` — Xử lý ảnh với `sharp`:
  - Body: `{ crop: { left, top, width, height }, resize: { width, height, fit }, rotate, flipHorizontal, flipVertical, format, quality, label, saveAsVariant: true }`
  - Tạo bản ghi mới trong `image_variants` và trả về URL của variant mới.
- `GET /api/v1/images/:id/variants` — Danh sách tất cả biến thể của ảnh
- `DELETE /api/v1/images/:id/variants/:variantId` — Xóa một biến thể

---

## 5. Albums, Folders & Tags
- `GET /api/v1/folders` & `POST /api/v1/folders` — Lấy cây thư mục / tạo thư mục con (`parentId`)
- `PATCH /api/v1/folders/:id` & `DELETE /api/v1/folders/:id` — Đổi tên / xóa thư mục
- `GET /api/v1/albums` & `POST /api/v1/albums` — Danh sách / tạo album
- `GET /api/v1/albums/:id` & `PATCH /api/v1/albums/:id` — Chi tiết / đổi tên / chọn `coverImageId` / đặt `visibility`
- `DELETE /api/v1/albums/:id` — Xóa album
- `POST /api/v1/albums/:id/images` & `DELETE /api/v1/albums/:id/images` — Thêm / gỡ ảnh khỏi album
- `GET /api/v1/tags`, `POST /api/v1/tags`, `DELETE /api/v1/tags/:id` — Quản lý Tags tập trung

---

## 6. Sharing
- `GET /api/v1/shares` — Danh sách share links đã tạo
- `POST /api/v1/shares` — Tạo Share Link cho `image` hoặc `album` (`expiresAt`, `password`, `allowDownload`)
- `DELETE /api/v1/shares/:id` — Thu hồi Share Link
- `GET /api/v1/public/shares/:token` — Truy cập link chia sẻ (kiểm tra hết hạn, xác thực mật khẩu qua `POST /api/v1/public/shares/:token/verify`)

---

## 7. API Keys Management
- `GET /api/v1/api-keys` — Danh sách API Key của user/admin (chỉ trả `key_prefix`, không lộ secret)
- `POST /api/v1/api-keys` — Tạo mới (`name`, `scopes`, `rateLimitPerMinute`, `expiresAt`) -> chỉ hiển thị full key **1 lần duy nhất** khi tạo
- `DELETE /api/v1/api-keys/:id` — Thu hồi API Key
- `GET /api/v1/api-keys/:id/usage` — Thống kê request & thời gian dùng gần nhất

---

## 8. Dashboard, Analytics, Storage & System Settings
- `GET /api/v1/stats` — Tổng quan Dashboard (tổng ảnh, dung lượng đã dùng, số album, tổng lượt xem, upload hôm nay, biểu đồ theo ngày/tháng, ảnh mới nhất)
- `GET /api/v1/analytics/overview` — Analytics chi tiết (lượt xem thực tế vs bot, top ảnh xem/tải nhiều nhất, bandwidth, API requests theo HTTP status code)
- `GET /api/v1/admin/storage/summary` — Tổng dung lượng đĩa, theo user, theo định dạng, tình trạng Storage Provider
- `POST /api/v1/admin/storage/scan-orphans` — Quét file mồ côi giữa DB và Storage
- `POST /api/v1/admin/storage/backup-metadata` & `POST /api/v1/admin/storage/restore-metadata` — Backup & Restore metadata JSON
- `GET /api/v1/admin/settings` & `PATCH /api/v1/admin/settings` — Cấu hình hệ thống (tên web, logo, favicon, upload limits, allowed formats, default visibility, storage provider, image processing, SMTP, rate limit, maintenance mode)
