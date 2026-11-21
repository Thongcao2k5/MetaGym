# DATABASE DESIGN — Image Server & WebAdmin Extension

> **Quy ước**: Sử dụng PostgreSQL với hệ thống SQL migrations trong `database/migrations/` (tiếp nối từ `0033`, bắt đầu từ `0034+`). Mọi bảng đều có Primary Key (`UUID` hoặc `BIGINT`), Foreign Key rõ ràng, Index cho cột truy vấn/lọc, Unique Constraint hợp lý, `created_at`, `updated_at`, và `deleted_at` (soft delete) cho dữ liệu nghiệp vụ chính.

---

## 1. Bảng hiện có được tái sử dụng / mở rộng
- **`users`**: Bổ sung/chuẩn hóa các cột:
  - `role_id` (FK -> `roles.id`, hoặc giữ `role` + đồng bộ bảng `roles`)
  - `storage_quota_bytes` (`BIGINT NOT NULL DEFAULT 1073741824` — mặc định 1GB)
  - `storage_used_bytes` (`BIGINT NOT NULL DEFAULT 0`)
  - `is_locked` (`BOOLEAN NOT NULL DEFAULT FALSE`)
- **`audit_logs`**: Tái sử dụng để ghi lại toàn bộ thao tác admin/user (upload, xóa ảnh, đổi quyền, thu hồi API key, thay đổi system settings).

---

## 2. Danh sách bảng mới / mở rộng chi tiết

### 2.1 `roles`
Quản lý phân quyền RBAC (`super_admin`, `admin`, `user`).
- `id` (`UUID PK`)
- `code` (`VARCHAR(50) UNIQUE NOT NULL`) — `super_admin`, `admin`, `user`
- `name` (`VARCHAR(100) NOT NULL`)
- `permissions` (`JSONB NOT NULL DEFAULT '[]'`)
- `created_at`, `updated_at` (`TIMESTAMPTZ NOT NULL DEFAULT NOW()`)

### 2.2 `storage_providers`
Quản lý cấu hình các Storage Backend (Local, Supabase, Cloudflare R2, AWS S3, MinIO).
- `id` (`UUID PK`)
- `name` (`VARCHAR(100) NOT NULL`)
- `type` (`VARCHAR(30) NOT NULL`) — `local`, `supabase`, `s3`, `r2`, `minio`
- `config` (`JSONB NOT NULL DEFAULT '{}'`) — endpoint, bucket, region, base_path (secret đọc từ env hoặc mã hóa)
- `is_default` (`BOOLEAN NOT NULL DEFAULT FALSE`)
- `is_active` (`BOOLEAN NOT NULL DEFAULT TRUE`)
- `health_status` (`VARCHAR(30) NOT NULL DEFAULT 'unknown'`)
- `last_checked_at` (`TIMESTAMPTZ`)
- `created_at`, `updated_at`

### 2.3 `folders`
Cấu trúc thư mục nhiều cấp (Self-referencing).
- `id` (`UUID PK`)
- `owner_id` (`UUID NOT NULL FK -> users.id`)
- `parent_id` (`UUID NULL FK -> folders.id ON DELETE CASCADE`)
- `name` (`VARCHAR(150) NOT NULL`)
- `slug` (`VARCHAR(180) NOT NULL`)
- `created_at`, `updated_at`, `deleted_at`
- **Unique**: `(owner_id, parent_id, name)` WHERE `deleted_at IS NULL`
- **Index**: `(owner_id, parent_id)`

### 2.4 `images`
Bảng trung tâm lưu metadata của ảnh (không lưu Base64).
- `id` (`UUID PK`)
- `owner_id` (`UUID NOT NULL FK -> users.id`)
- `folder_id` (`UUID NULL FK -> folders.id ON DELETE SET NULL`)
- `storage_provider_id` (`UUID NOT NULL FK -> storage_providers.id`)
- `filename` (`VARCHAR(255) NOT NULL`) — tên hiển thị
- `original_filename` (`VARCHAR(255) NOT NULL`)
- `storage_key` (`VARCHAR(500) UNIQUE NOT NULL`) — đường dẫn vật lý an toàn theo UUID
- `extension` (`VARCHAR(20) NOT NULL`)
- `mime_type` (`VARCHAR(100) NOT NULL`)
- `size_bytes` (`BIGINT NOT NULL`)
- `width` (`INTEGER`)
- `height` (`INTEGER`)
- `sha256_hash` (`CHAR(64) NOT NULL`)
- `exif_data` (`JSONB`)
- `description` (`TEXT`)
- `visibility` (`VARCHAR(20) NOT NULL DEFAULT 'private'`) — `public`, `private`
- `view_count` (`BIGINT NOT NULL DEFAULT 0`)
- `download_count` (`BIGINT NOT NULL DEFAULT 0`)
- `created_at`, `updated_at`, `deleted_at`
- **Index**: `(owner_id, created_at DESC)`, `(mime_type)`, `(sha256_hash)`, `(folder_id)`, `(visibility)`

### 2.5 `image_variants`
Lưu các phiên bản của ảnh (thumbnail, WebP/AVIF tự động, và các bản chỉnh sửa từ Image Editor để không ghi đè ảnh gốc).
- `id` (`UUID PK`)
- `image_id` (`UUID NOT NULL FK -> images.id ON DELETE CASCADE`)
- `variant_type` (`VARCHAR(40) NOT NULL`) — `thumbnail`, `webp`, `avif`, `edited`, `custom`
- `label` (`VARCHAR(100)`) — ví dụ: `"Crop 16:9"`, `"Compressed 75%"`
- `storage_key` (`VARCHAR(500) UNIQUE NOT NULL`)
- `extension` (`VARCHAR(20) NOT NULL`)
- `mime_type` (`VARCHAR(100) NOT NULL`)
- `size_bytes` (`BIGINT NOT NULL`)
- `width` (`INTEGER`)
- `height` (`INTEGER`)
- `transform_params` (`JSONB`) — lưu thông số crop/resize/rotate/flip/quality
- `created_at`, `updated_at`
- **Index**: `(image_id, variant_type)`

### 2.6 `albums` & `album_images`
Quản lý Album và liên kết N-N với `images`.
- **`albums`**:
  - `id` (`UUID PK`)
  - `owner_id` (`UUID NOT NULL FK -> users.id`)
  - `title` (`VARCHAR(180) NOT NULL`)
  - `description` (`TEXT`)
  - `cover_image_id` (`UUID NULL FK -> images.id ON DELETE SET NULL`)
  - `visibility` (`VARCHAR(20) NOT NULL DEFAULT 'private'`) — `public`, `private`
  - `share_slug` (`VARCHAR(100) UNIQUE`)
  - `created_at`, `updated_at`, `deleted_at`
- **`album_images`**:
  - `album_id` (`UUID NOT NULL FK -> albums.id ON DELETE CASCADE`)
  - `image_id` (`UUID NOT NULL FK -> images.id ON DELETE CASCADE`)
  - `sort_order` (`INTEGER NOT NULL DEFAULT 0`)
  - `added_at` (`TIMESTAMPTZ NOT NULL DEFAULT NOW()`)
  - **PK**: `(album_id, image_id)`

### 2.7 `tags` & `image_tags`
Phân loại & tìm kiếm đa điều kiện.
- **`tags`**:
  - `id` (`UUID PK`)
  - `name` (`VARCHAR(80) NOT NULL`)
  - `slug` (`VARCHAR(100) UNIQUE NOT NULL`)
  - `color` (`VARCHAR(20)`)
  - `created_at`, `updated_at`
- **`image_tags`**:
  - `image_id` (`UUID NOT NULL FK -> images.id ON DELETE CASCADE`)
  - `tag_id` (`UUID NOT NULL FK -> tags.id ON DELETE CASCADE`)
  - `created_at` (`TIMESTAMPTZ NOT NULL DEFAULT NOW()`)
  - **PK**: `(image_id, tag_id)`

### 2.8 `share_links`
Chia sẻ ảnh hoặc album với thời hạn, mật khẩu và quyền tải xuống.
- `id` (`UUID PK`)
- `created_by` (`UUID NOT NULL FK -> users.id`)
- `target_type` (`VARCHAR(20) NOT NULL`) — `image`, `album`
- `image_id` (`UUID NULL FK -> images.id ON DELETE CASCADE`)
- `album_id` (`UUID NULL FK -> albums.id ON DELETE CASCADE`)
- `token` (`VARCHAR(128) UNIQUE NOT NULL`)
- `password_hash` (`VARCHAR(255) NULL`)
- `allow_download` (`BOOLEAN NOT NULL DEFAULT TRUE`)
- `expires_at` (`TIMESTAMPTZ NULL`)
- `revoked_at` (`TIMESTAMPTZ NULL`)
- `access_count` (`BIGINT NOT NULL DEFAULT 0`)
- `created_at`, `updated_at`
- **Index**: `(token)`, `(created_by)`, `(expires_at)`

### 2.9 `api_keys` & `api_logs`
Quản lý API Key tích hợp ngoài & theo dõi lưu lượng.
- **`api_keys`**:
  - `id` (`UUID PK`)
  - `user_id` (`UUID NOT NULL FK -> users.id ON DELETE CASCADE`)
  - `name` (`VARCHAR(120) NOT NULL`)
  - `key_prefix` (`VARCHAR(16) NOT NULL`) — hiển thị nhận diện (vd: `mg_live_ab12`)
  - `key_hash` (`CHAR(64) UNIQUE NOT NULL`) — SHA-256 hash của secret key
  - `scopes` (`JSONB NOT NULL DEFAULT '["images:read"]'`)
  - `rate_limit_per_minute` (`INTEGER NOT NULL DEFAULT 60`)
  - `request_count` (`BIGINT NOT NULL DEFAULT 0`)
  - `last_used_at` (`TIMESTAMPTZ NULL`)
  - `expires_at` (`TIMESTAMPTZ NULL`)
  - `revoked_at` (`TIMESTAMPTZ NULL`)
  - `created_at`, `updated_at`
- **`api_logs`**:
  - `id` (`BIGSERIAL PK`)
  - `api_key_id` (`UUID NULL FK -> api_keys.id ON DELETE SET NULL`)
  - `user_id` (`UUID NULL FK -> users.id ON DELETE SET NULL`)
  - `method` (`VARCHAR(10) NOT NULL`)
  - `endpoint` (`VARCHAR(255) NOT NULL`)
  - `status_code` (`SMALLINT NOT NULL`)
  - `response_time_ms` (`INTEGER`)
  - `bytes_transferred` (`BIGINT NOT NULL DEFAULT 0`)
  - `ip_address` (`INET`)
  - `user_agent` (`TEXT`)
  - `created_at` (`TIMESTAMPTZ NOT NULL DEFAULT NOW()`)
  - **Index**: `(created_at DESC)`, `(api_key_id, created_at DESC)`, `(status_code)`

### 2.10 `image_views`
Thống kê lượt xem, tải xuống, bandwidth và phân biệt bot.
- `id` (`BIGSERIAL PK`)
- `image_id` (`UUID NOT NULL FK -> images.id ON DELETE CASCADE`)
- `event_type` (`VARCHAR(20) NOT NULL DEFAULT 'view'`) — `view`, `download`
- `is_bot` (`BOOLEAN NOT NULL DEFAULT FALSE`)
- `referer` (`TEXT`)
- `ip_hash` (`CHAR(64)`)
- `user_agent` (`TEXT`)
- `bytes_served` (`BIGINT NOT NULL DEFAULT 0`)
- `created_at` (`TIMESTAMPTZ NOT NULL DEFAULT NOW()`)
- **Index**: `(image_id, created_at DESC)`, `(created_at DESC, is_bot)`

### 2.11 `system_settings`
Lưu cấu hình toàn hệ thống (key-value JSONB).
- `key` (`VARCHAR(100) PK`) — ví dụ: `site_branding`, `upload_limits`, `image_processing`, `smtp`, `rate_limits`, `maintenance_mode`, `backup_policy`
- `value` (`JSONB NOT NULL`)
- `updated_by` (`UUID NULL FK -> users.id`)
- `updated_at` (`TIMESTAMPTZ NOT NULL DEFAULT NOW()`)
