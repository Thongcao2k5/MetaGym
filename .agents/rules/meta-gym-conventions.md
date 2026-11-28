---
trigger: model_decision
description: "Bắt buộc áp dụng khi thiết kế, thêm mới hoặc chỉnh sửa các tính năng quản trị và media của Meta Gym (Coach, Gói tập, Banner, Slide, Thiết bị, Phòng tập, Tài khoản...) để thống nhất kiến trúc backend module, tối ưu ảnh WebP/thumbnail, phân cấp thư mục Supabase Storage, xóa sạch DB+Storage và UX Admin Web."
---

# Quy ước chung hệ thống Meta Gym (Backend, Media & Admin Web)

Các quy chuẩn dưới đây được đúc kết từ phân hệ Hội viên & Media để áp dụng đồng bộ cho toàn bộ các phần tiếp theo (**Coach, Gói tập, Banner, Slide, Thiết bị, Phòng tập...**).

## 1. Kiến trúc Backend Feature-First (`backend/src/modules/`)
- Mỗi tính năng đặt gọn cả routes và services liên quan trong `backend/src/modules/<domain>/` với `index.js` làm điểm xuất công khai (`auth`, `users`, `coaching`, `memberships`, `payments`, `media`, `training`, `nutrition`, `tracking`, `communication`, `system`).
- `backend/src/app.js` chỉ import router từ `./modules/<domain>/index.js` và **giữ nguyên URL endpoint** (`/api/v1/...`) để không làm vỡ frontend/mobile.
- Không nhân bản logic giữa các route; tách helper dùng chung (ví dụ xử lý ảnh trong `backend/src/modules/media/image-processor.js`, dọn dẹp avatar trong `backend/src/modules/users/users.routes.js`).

## 2. Quy chuẩn Hình ảnh, Nén WebP & Thumbnail
- **Định dạng & Nén mặc định:**
  - Ảnh hiển thị UI/avatar/banner/gói tập ưu tiên nén sang **`image/webp`** bằng Sharp (`effort: 6, smartSubsample: true`).
  - Với ảnh đại diện / ảnh vuông vừa (`processAvatarImages`): xuất bản chính tối đa **`512x512`** (`quality: 72, alphaQuality: 75`) và bản thu nhỏ **`120x120`** (`quality: 65, alphaQuality: 70`) cho bảng danh sách.
  - Với ảnh upload chuẩn JPEG/PNG giữ format qua `/api/v1/media/images` (`optimizeUploadedMedia`): tự động resize tối đa `1600x1600` (`fit: 'inside', withoutEnlargement: true`), JPEG bật `mozjpeg: true, progressive: true, quality: 75`, PNG bật `compressionLevel: 9, effort: 10, palette: true`.
  - Trên trình duyệt, khung cắt (`admin-web/src/components/image-cropper.js`) xuất kích thước mục tiêu (`outputSize = 512` cho ảnh vuông) ở định dạng `image/webp` (`0.8`) trước khi gửi lên server.
- **Tải ảnh đúng kích thước theo ngữ cảnh:**
  - **Bảng danh sách & Detail Drawer nhỏ:** luôn tải bản thumbnail (`?size=120&v=<mediaId>`) để tiết kiệm băng thông.
  - **Modal chỉnh sửa & Xem phóng to (`ImageViewer`):** mới tải bản đầy đủ (`?v=<mediaId>`).
- **Cache-busting:** Endpoint phục vụ ảnh gắn `ETag` (`"<mediaId>"` cho bản chính, `"<mediaId>-120"` cho thumbnail) và `Cache-Control: no-cache, private`; URL phía client luôn gắn `?v=<mediaId>` khi đổi ảnh.

## 3. Phân cấp Thư mục trên Storage (`meta-gym-media`)
- **Không lưu UUID trần ở thư mục gốc bucket** cho các upload mới. Mọi file mới phải đi qua các helper trong `backend/src/storage/storage-key.js` (`buildAvatarStorageKeys`, `buildMediaStorageKey`, `buildLibraryStorageKey`).
- Cấu trúc thư mục chuẩn theo tính năng (`MEDIA_PURPOSE_FOLDERS`):
  - `users/avatars/<uuid>.webp` và `users/avatars/thumbs/<uuid>.webp` (`AVATAR`)
  - `packages/<uuid>.<ext>` (`PACKAGE` — Gói tập / Coach packages)
  - `marketing/banners/<uuid>.<ext>` (`BANNER`) và `marketing/slides/<uuid>.<ext>` (`SLIDE`)
  - `coaching/outcomes/<uuid>.<ext>` (`COACH_OUTCOME`)
  - `gym/<uuid>.<ext>` (`GYM`), `equipment/<uuid>.<ext>` (`EQUIPMENT`), `exercises/<uuid>.<ext>` (`EXERCISE`)
  - `tracking/progress/<uuid>.<ext>`, `nutrition/meals/<uuid>.<ext>`, `communication/messages/<uuid>.<ext>`
  - `library/{original,thumbnails,variants}/<uuid>.<ext>` (Image Server)
- Duy trì tương thích ngược khi đọc/dọn file cũ (`resolveAvatarThumbKeys`, giữ regex `BARE_UUID_PATTERN` cho dữ liệu cũ) và dùng `list()` đệ quy trong `supabase-image-storage.js`.

## 4. Gỡ / Thay ảnh phải xóa sạch cả DB lẫn Storage
- Khi người dùng **Gỡ ảnh** (`DELETE .../avatar` hoặc `PATCH` với `avatarMediaId: null`) hoặc **Thay ảnh mới** (`POST .../avatar` / upload đè):
  1. Trong transaction DB: gỡ/cập nhật liên kết trên bảng chính, xóa bản ghi `media_assets` cũ (dùng `SAVEPOINT` an toàn như `prepareAvatarCleanup`).
  2. Sau khi `COMMIT` thành công: xóa **cả bản chính lẫn bản thumbnail** trên Supabase/Local/S3 Storage để tiết kiệm dung lượng.
  3. Nếu upload file lên Storage thành công nhưng ghi DB thất bại (`ROLLBACK`): phải xóa ngay file vừa upload để không tạo file rác.

## 5. Quy chuẩn Giao diện & Luồng lưu trên Admin Web (`admin-web/`)
- **Upload nhị phân:** dùng helper `uploadRaw` / `uploadFormData` từ `admin-web/src/services/api.js`; không tự gọi `fetch` thiếu token hoặc xử lý 401.
- **Nút thao tác ảnh thu gọn:** gom các tác vụ ảnh (`Xem ảnh phóng to`, `Tải ảnh mới...`, `Cắt lại ảnh`, `Gỡ ảnh`) vào 1 nút dropdown gọn gàng, đảm bảo độ tương phản rõ ở cả theme Dark và Light.
- **Bố cục Modal chỉnh sửa:** với biểu mẫu có ảnh + nhiều trường hồ sơ, dùng bố cục ngang 2 cột (cột trái: Ảnh + thông tin tài khoản cơ bản; cột phải: nhóm trường hồ sơ/cấu hình).
- **Thông báo phản hồi:** dùng `toast(..., 'success')` từ `admin-web/src/components/toast.js` (tự ẩn sau vài giây, có nút đóng), tránh chèn thêm banner thành công cố định làm dư thừa nội dung trang; lỗi form hiển thị inline trong modal (`ctrl.showError`) và giữ nguyên dữ liệu đã nhập.
- **Ngôn ngữ hiển thị thuần tiếng Việt:** Nhãn hiển thị trên UI (chi tiết, select option, badge...) dùng tiếng Việt thuần túy và tự nhiên, **không kèm mã enum tiếng Anh trong ngoặc** (ví dụ hiển thị `Nữ`, `Trung cấp`, `Vừa phải` thay vì `Nữ (FEMALE)`, `Trung cấp (INTERMEDIATE)`, `Vừa phải (MODERATE)`); chỉ giữ mã enum ở giá trị `value` khi gửi API.
- **Bất biến nghiệp vụ bắt buộc:** giữ nguyên các ràng buộc quyền riêng tư & vận hành như trần cứng Coach `memberLimit = 8` và không rò rỉ dữ liệu nhạy cảm (`healthNotes`, `injuryNotes`, `journal`, tin nhắn riêng tư) trên giao diện Admin.
