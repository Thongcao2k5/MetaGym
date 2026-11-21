# Đặc tả nâng cấp Image Server & Quản lý Hình ảnh theo Folder

Tài liệu này cung cấp đầy đủ hiện trạng mã nguồn và thiết kế mục tiêu để **Coding Agent** nâng cấp hệ thống lưu trữ ảnh hiện tại thành **Image Server có phân folder và đầy đủ thao tác Thêm / Xem / Sửa / Xóa (CRUD)**, chạy trực tiếp trên **Backend Express + Supabase Storage Free** (không tốn thêm chi phí server).

---

## 1. Hiện trạng mã nguồn (Baseline)

### 1.1. Tầng lưu trữ (`backend/src/storage/`)
- [image-storage.js](../../backend/src/storage/image-storage.js): Tự động chọn **Supabase Storage** (khi cấu hình đủ `SUPABASE_URL`, `SUPABASE_SECRET_KEY`, `SUPABASE_STORAGE_BUCKET`) hoặc **Local** (`MEDIA_STORAGE_DIR`).
- [local-image-storage.js](../../backend/src/storage/local-image-storage.js) & [supabase-image-storage.js](../../backend/src/storage/supabase-image-storage.js):
  - Chỉ cung cấp 3 hàm: `put(key, bytes, mimeType)`, `get(key)`, `remove(key)`.
  - **Giới hạn hiện tại:** Cả hai file đều khóa `keyPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/` (chỉ cho phép UUID phẳng, **chưa hỗ trợ dấu `/` phân folder**).
  - `local-image-storage.js` chưa gọi `mkdir(path.dirname(...))` cho thư mục con.

### 1.2. Route & Database (`backend/src/routes/media.routes.js`)
- Bảng DB: `media_assets` (khai báo ở `database/migrations/0002_coaching_and_content.up.sql`).
- Hiện chỉ có 3 endpoint:
  - `POST /api/v1/media/images`: Upload ảnh PNG/JPEG tối đa `5 MB`, xử lý qua `sharp`, bắt buộc `x-image-purpose` (`MESSAGE`, `PROGRESS_PHOTO`, `MEAL_PHOTO`, `COACH_OUTCOME`). **Đang chặn `ADMIN`** (chỉ cho `MEMBER` và `COACH`).
  - `GET /api/v1/media/images/:mediaId/access-url`: Cấp URL có chữ ký HMAC (hết hạn `300s`).
  - `GET /api/v1/media/images/:mediaId`: Trả về bytes ảnh khi chữ ký HMAC hợp lệ.
- **Chưa có:** API liệt kê danh sách ảnh theo folder, sửa metadata/thay ảnh, xóa ảnh (`DELETE`), và thống kê dung lượng đã dùng.

---

## 2. Thiết kế mục tiêu (Target Architecture)

### 2.1. Quy ước Folder (Prefix)
Chuẩn hóa lưu trữ theo dạng `<folder>/<uuid>` (tương thích cả Local filesystem lẫn Supabase Storage Bucket `meta-gym-media`):

| Folder | Mục đích (`purpose`) | Đối tượng được upload |
|---|---|---|
| `avatars/` | `AVATAR` | `MEMBER`, `COACH`, `ADMIN` (tùy chọn hợp nhất từ `users.routes.js`) |
| `equipment/` | `EQUIPMENT` | `ADMIN` |
| `exercises/` | `EXERCISE` | `ADMIN` |
| `gym/` | `GYM_BANNER` | `ADMIN` |
| `progress/` | `PROGRESS_PHOTO` | `MEMBER` |
| `meals/` | `MEAL_PHOTO` | `MEMBER` |
| `messages/` | `MESSAGE` | `MEMBER`, `COACH` |
| `outcomes/` | `COACH_OUTCOME` | `COACH` |
| `misc/` | Mặc định nếu không chỉ định | Theo quyền hợp lệ |

### 2.2. Nâng cấp Storage Adapter (`local-image-storage.js` & `supabase-image-storage.js`)
1. **Cập nhật regex kiểm tra `key`:**
   - Chấp nhận **cả key UUID cũ** (để không vỡ dữ liệu cũ) **lẫn key có folder** dạng `^[a-z0-9_-]{2,32}\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`.
   - Tuyệt đối chặn path traversal (`..`, `\`, `//`, ký tự ngoài whitelist).
2. **Trong `local-image-storage.js`:**
   - Khi `put(key, bytes)`, gọi `await mkdir(path.dirname(location(key)), { recursive: true, mode: 0o700 })` để tự tạo thư mục con nếu chưa tồn tại.
   - Khi `remove(key)`, bỏ qua lỗi `ENOENT` nếu file đã bị xóa trước đó để đảm bảo idempotent.

---

## 3. Thay đổi Database (Migration `0025`)

> **Lưu ý cho Coding Agent:** Đọc `database/migrations/0002_coaching_and_content.up.sql` trước để kiểm tra các `CHECK` constraint hiện có trên `media_assets.purpose` và `media_assets.status`.

Tạo cặp migration `0025_media_folders_and_management.up.sql` / `.down.sql`:
1. Thêm cột vào `media_assets` (nếu chưa có):
   - `folder TEXT NOT NULL DEFAULT 'misc'`
   - `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`
   - `deleted_at TIMESTAMPTZ` (nếu hỗ trợ soft-delete trước khi dọn storage, hoặc xóa hẳn kèm `imageStorage.remove`)
2. Mở rộng `CHECK` constraint của `purpose` để cho phép thêm `EQUIPMENT`, `EXERCISE`, `GYM_BANNER` (phục vụ Admin Web).
3. Tạo index phục vụ lọc theo folder:
   - `CREATE INDEX idx_media_assets_folder_status ON media_assets (folder, status, created_at DESC);`
   - `CREATE INDEX idx_media_assets_owner_status ON media_assets (owner_id, status, created_at DESC);`
4. Cập nhật `database/tests/schema_assertions.sql` tương ứng.

---

## 4. Đặc tả API cần bổ sung (`backend/src/routes/media.routes.js`)

Tất cả endpoint mới phải qua `createAuthentication` và kiểm tra phân quyền rõ ràng:

| Method | Endpoint | Quyền | Chức năng |
|---|---|---|---|
| `POST` | `/api/v1/media/images` | `MEMBER`, `COACH`, `ADMIN` | Mở rộng cho `ADMIN` upload với `purpose` thuộc catalog (`EQUIPMENT`, `EXERCISE`, `GYM_BANNER`). Tự ánh xạ `purpose` → `folder` (hoặc nhận header `x-media-folder` đã validate whitelist). Áp dụng nén/resize `sharp` theo `docs/deployment/image-optimization-plan.md`. |
| `GET` | `/api/v1/media/images` | Đã đăng nhập | Liệt kê danh sách ảnh có phân trang (`page`, `pageSize`), lọc theo `folder`, `purpose`, `search`. **`ADMIN`** xem được toàn bộ; **`MEMBER`/`COACH`** chỉ xem ảnh có `owner_id = request.authUser.id`. |
| `PATCH` | `/api/v1/media/images/:mediaId` | Chủ ảnh hoặc `ADMIN` | Đổi tên (`originalName`), chuyển `folder` (nếu đổi `storage_key` trên storage thì copy/upload key mới xong mới xóa key cũ), hoặc cập nhật metadata. |
| `DELETE` | `/api/v1/media/images/:mediaId` | Chủ ảnh hoặc `ADMIN` | Xóa ảnh khỏi Storage (`imageStorage.remove(storage_key)`) và cập nhật/xóa bản ghi `media_assets`. Nếu `ADMIN` xóa, ghi log vào `admin_audit_logs`. |
| `GET` | `/api/v1/admin/media/folders` | `ADMIN` | Thống kê danh sách folder, số lượng ảnh và tổng `size_bytes` theo từng folder (giúp theo dõi hạn mức **1 GB Supabase Storage Free**). |

---

## 5. Ràng buộc bảo mật & Lưu ý triển khai

1. **Giữ Bucket ở chế độ Private:** Không bật public bucket trên Supabase; mọi lượt xem ảnh vẫn đi qua signed HMAC URL (`/media/images/:mediaId?expires=...&signature=...`) hoặc URL công khai có kiểm soát (như ảnh catalog thiết bị/bài tập nếu cần).
2. **Xác thực nội dung ảnh bằng `sharp`:** Tiếp tục kiểm tra `metadata.format` (`png`/`jpeg`, mở rộng `webp` nếu cấu hình bucket cho phép), `.rotate()` theo EXIF, và giới hạn `MAX_BYTES = 5 MB`.
3. **Đồng bộ tài liệu & kiểm thử:**
   - Cập nhật `docs/requirements/openapi.yaml` và `backend/docs/openapi.yaml` sau khi thêm route.
   - Viết unit/integration test cho `local-image-storage`, `supabase-image-storage` (key có folder + chặn `..`), và `media.routes.js` (CRUD + RBAC).
   - Chạy `cd backend && npm run check && npm test` để xác nhận toàn bộ pass.
