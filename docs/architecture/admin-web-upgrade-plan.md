# Kế hoạch nâng cấp WebAdmin (`admin-web/`) — Desktop & Mobile UX

Tài liệu này là lộ trình từng bước dành cho **Coding Agent** trên nhánh **`thong`** để tái cấu trúc và nâng cấp giao diện `admin-web/` thành một hệ thống quản trị **đẹp, hiện đại, dễ dùng trên cả Desktop và Mobile**, sử dụng **component tái sử dụng** và **commit tách bạch theo từng bước**.

---

## 1. Mục tiêu & Quy chuẩn bắt buộc

1. **Tuân thủ Design System:**
   - Đọc `.agents/rules/meta-gym-design.md`, `DESIGN.md`, `design-system/meta-gym/MASTER.md` và `.agents/skills/admin-web-design/SKILL.md` trước khi sửa UI.
   - Bắt buộc dùng token từ `design-system/meta-gym/adapters/bootstrap-theme.css` (font **Be Vietnam Pro**, màu nhấn Coral Orange `#ff5a36`, hỗ trợ `[data-bs-theme="dark"]` & `[data-bs-theme="light"]`).
   - Loại bỏ toàn bộ màu xanh lá cũ (`#245942`, `#198754`, `#e6f4eb`) trong `admin-web/src/style.css`.
2. **UX tốt trên Desktop & Mobile:**
   - **Desktop (`>= 992px`):** Sidebar cố định bên trái (`240px–260px`) + Topbar gọn + vùng nội dung thoáng.
   - **Mobile / Tablet (`375px–991px`):** Chuyển Sidebar thành **Bootstrap Offcanvas Drawer** (nút menu 44×44px trên Topbar) thay vì dàn ngang chiếm hết màn hình; bảng dữ liệu có `table-responsive` hoặc hiển thị gọn các cột chính.
   - **Touch Target & Trạng thái:** Nút bấm tối thiểu `44×44px`, số liệu/giá/ngày dùng `.font-data` (`tabular-nums`), mọi màn hình đều có **Loading**, **Empty**, **Error** và **ConfirmModal** trước thao tác xóa/khóa.
3. **Giữ nguyên các tính năng & kiểm thử hiện có:**
   - Giữ nguyên `@media print` cho `#checkin-print` (in mã QR Check-in phòng gym).
   - Mọi bước đều phải pass `cd admin-web && npm run build && npm test` trước khi commit.

---

## 2. Hiệu năng, Tốc độ tải & Tối ưu đường truyền mạng

Để WebAdmin chạy mượt trên mạng yếu (3G/4G) và kết hợp tốt với Backend Render Free (có cold start):

1. **Không load lại khung giao diện khi chuyển trang (Persistent AppShell):**
   - Hiện tại `main.js` xóa toàn bộ `root.innerHTML` mỗi lần đổi hash. Khi nâng cấp, `AppShell` (Sidebar + Topbar) chỉ render **1 lần** sau khi đăng nhập; chuyển route chỉ cập nhật vùng `#page-content` và class `active` trên menu.
2. **Code Splitting (Tải lười theo trang với Vite):**
   - Router dùng dynamic `import()` cho từng file trong `pages/`.
   - Thư viện nặng như `chart.js` chỉ tải khi vào `DashboardPage`; `qrcode` chỉ tải khi vào `GymPage` — giảm kích thước bundle ban đầu.
3. **Cache ngắn hạn & Chống gọi API trùng lặp:**
   - Tạo helper cache in-memory (TTL ~30–60s) cho các danh mục ít thay đổi (`membership-plans`, `coach-packages`, `gym-profile`, danh sách Coach dùng cho dropdown) và tự xóa cache khi Admin thực hiện `POST`/`PATCH`/`DELETE`.
   - Dùng `AbortController` để hủy request của trang cũ nếu người dùng chuyển trang nhanh, kết hợp `debounce (300ms)` cho ô tìm kiếm.
4. **Thích ứng mạng chậm & Cold Start (Render Free):**
   - Cấu hình timeout rõ ràng trong `api.js`; nếu request mất > 3 giây, hiển thị trạng thái *"Đang kết nối máy chủ (có thể mất vài chục giây nếu server vừa khởi động lại)…"*.
   - Dùng **Skeleton Loading** cục bộ trong `#page-content`; khi mất mạng (`Failed to fetch`), hiện thông báo + nút **Thử lại** tại chỗ mà không văng ra trang lỗi trắng.
   - Tối ưu static assets bằng `vite-plugin-image-optimizer` và `loading="lazy"` cho ảnh.

---

## 3. Kiến trúc thư mục mục tiêu (`admin-web/src/`)

Tách toàn bộ mã đang dồn trong `admin-web/src/main.js` (423 dòng) thành cấu trúc module tái sử dụng:

```text
admin-web/src/
├── main.js                      # Khởi tạo app, theme, đăng ký router
├── style.css                    # Import bootstrap-theme.css + layout/print CSS
├── services/
│   ├── api.js                   # Fetch wrapper (VITE_API_BASE_URL, Bearer token, error parsing)
│   ├── auth.js                  # Quản lý session/token/currentUser
│   ├── theme.js                 # Chuyển đổi Dark/Light theme (lưu localStorage)
│   └── formatters.js            # Định dạng tiền VND, ngày giờ, escape HTML
├── components/
│   ├── AppShell.js              # Khung Sidebar (Desktop) + Offcanvas (Mobile) + Topbar
│   ├── LoadingState.js          # Skeleton (table/card/grid) + thông báo mạng chậm/cold start (> 3s)
│   ├── EmptyState.js            # Trạng thái No data (chưa có dữ liệu vs không khớp filter) & Error + nút Thử lại
│   ├── StatCard.js              # Thẻ KPI dashboard tái sử dụng
│   ├── FilterBar.js             # Thanh lọc chuẩn: Search (debounce) + Dropdown + Checkbox/Toggle + Reset
│   ├── DataTable.js             # Bảng tái sử dụng (skeleton, empty, phân trang page/pageSize, bulk checkbox)
│   ├── StatusBadge.js           # Badge trạng thái đồng bộ enum (ACTIVE, SUSPENDED, PAID...)
│   ├── FormModal.js             # Modal tạo/sửa dữ liệu dùng Bootstrap 5 Modal
│   ├── ConfirmModal.js          # Modal xác nhận thao tác nguy hiểm (khóa, duyệt, xóa ảnh, đổi mã QR)
│   ├── ImagePickerModal.js      # Modal chọn/tải ảnh tái sử dụng cho Thiết bị, Phòng gym, Bài tập
│   └── ToastNotice.js           # Thông báo nổi (Bootstrap Toast) thay thế banner tĩnh
└── pages/
    ├── LoginPage.js             # #/login
    ├── DashboardPage.js         # #/admin/dashboard
    ├── UsersPage.js             # #/admin/members & #/admin/coaches (dùng chung 1 component trang)
    ├── MembershipPlansPage.js   # #/admin/plans
    ├── CoachPackagesPage.js     # #/admin/coach-packages
    ├── PaymentsPage.js          # #/admin/payments
    ├── RelationshipsPage.js     # #/admin/relationships
    ├── TerminationsPage.js      # #/admin/terminations
    ├── NutritionFoodsPage.js    # #/admin/nutrition-foods
    ├── GymPage.js               # #/admin/gym (hồ sơ + in QR #checkin-print)
    ├── EquipmentPage.js         # #/admin/equipment
    ├── MediaPage.js             # #/admin/media (Quản lý hình ảnh theo folder & dung lượng 1 GB)
    └── ProfilePage.js           # #/admin/profile
```

### 3.1. Đặc tả chi tiết các Component tái sử dụng

| Component | Chi tiết triển khai bắt buộc |
|---|---|
| **`LoadingState.js`** | Dùng **Bootstrap 5 Placeholders** (`placeholder-glow`, `placeholder`) hỗ trợ Dark/Light và `prefers-reduced-motion` với 3 biến thể: `table` (5–8 dòng giả lập cột bảng), `dashboard` (4 thẻ KPI + khung giữ chỗ `300px` cho Chart.js chống giật CLS), `grid` (lưới ô vuông `aspect-ratio: 1/1` cho `MediaPage`). Nếu request > **3 giây**, tự hiển thị thêm thông báo *"Máy chủ đang khởi động hoặc mạng chậm, vui lòng đợi…"*. |
| **`EmptyState.js`** | Phân biệt rõ 3 trạng thái: **(1) Chưa có dữ liệu** (icon + mô tả + nút hành động *Tạo mới*), **(2) Không khớp bộ lọc / tìm kiếm** (thông báo rõ + nút *Xóa bộ lọc*), **(3) Lỗi mạng / Server lỗi** (thông báo lỗi + nút *Thử lại* tại chỗ, không văng trang trắng). |
| **`FilterBar.js`** | Thanh lọc responsive (tự xếp dọc gọn trên Mobile `375px`): gồm **Ô tìm kiếm** (`debounce 300ms` + nút xóa nhanh), **Dropdown** (`<select>` lọc vai trò/trạng thái/folder), **Checkbox / Toggle Switch** (ví dụ: *Chỉ hiện đang hoạt động*), và nút **Đặt lại bộ lọc**. |
| **`DataTable.js`** | Nhận `columns`, `rows`, `pagination` (`page`, `pageSize`, `totalItems`, `totalPages`), `selectable` (checkbox từng dòng + checkbox chọn tất cả ở header). Hỗ trợ đổi `pageSize` (`10 / 20 / 50`), nút Trước/Sau, cuộn ngang `table-responsive` trên Mobile, tích hợp `LoadingState` & `EmptyState`. |
| **`ToastNotice.js`** | Dùng **Bootstrap 5 Toast** nổi ở góc màn hình (không đẩy layout), phân loại `success`, `warning`, `danger`, tự đóng sau 3.5s và có `role="status"` / `aria-live="polite"`. |
| **`ConfirmModal.js` & `FormModal.js`** | Dùng **Bootstrap 5 Modal** (hỗ trợ phím `Esc` đóng modal): `ConfirmModal` bắt buộc dùng trước các thao tác khóa/mở tài khoản, duyệt/từ chối, xóa ảnh, xoay vòng mã QR; tự khóa nút (`disabled`) + hiện spinner khi đang gửi request để chống double-submit. |
| **`ImagePickerModal.js`** | Modal tái sử dụng để chọn ảnh từ thư viện folder (`MediaPage`) hoặc upload ảnh mới trực tiếp trong form của `EquipmentPage` / `GymPage`. |

---

## 4. Lộ trình thực hiện từng bước (Mỗi bước = 1 Commit sạch)

> **Quy tắc cho Agent:** Làm xong từng bước → chạy `cd admin-web && npm run build && npm test` → kiểm tra giao diện Desktop (`1280px`) & Mobile (`375px`) → `git commit` đúng phạm vi bước đó rồi mới sang bước tiếp theo.

### Bước 1: Nền tảng Theme, Icons & Build
- Cài `bootstrap-icons` (hoặc `lucide`) và `vite-plugin-image-optimizer` trong `admin-web/`.
- Import `../../design-system/meta-gym/adapters/bootstrap-theme.css` vào `admin-web/src/style.css`.
- Viết `src/services/theme.js` hỗ trợ nút chuyển **Dark / Light** (`data-bs-theme`).
- Cập nhật `admin-web/index.html` (import font `Be Vietnam Pro` hoặc fallback sạch).
- **Commit:** `style(admin-web): integrate MetaGym bootstrap-theme, icons, and dark/light switcher`

### Bước 2: Tách tầng Services & Hash Router
- Tách `api()`, `signOut()`, `esc()`, format tiền/ngày từ `main.js` sang `src/services/api.js`, `src/services/auth.js`, `src/services/formatters.js`.
- Tách logic định tuyến `#/admin/<section>` ra `src/router.js` (hoặc giữ gọn trong `main.js`).
- Đảm bảo `admin-web/test/account-status.test.js` vẫn pass.
- **Commit:** `refactor(admin-web): extract api, auth, formatters, and hash router`

### Bước 3: Xây dựng bộ Components tái sử dụng
- Tạo `AppShell.js` (Sidebar Desktop + Offcanvas Mobile + Topbar có nút Theme Toggle & nút Profile/Đăng xuất).
- Tạo `FilterBar.js` hỗ trợ đầy đủ **Search (`debounce 300ms`) + Dropdown (`<select>`) + Checkbox / Toggle Switch + nút Reset bộ lọc**.
- Tạo `DataTable.js` hỗ trợ **Phân trang (`page`, `pageSize`, chọn số dòng/trang)**, **Checkbox chọn dòng**, Skeleton Loading, Empty State.
- Tạo `LoadingState.js` (Skeleton cho bảng, thẻ KPI, lưới ảnh; tự hiện thông báo *"Máy chủ đang khởi động…"* nếu request > 3s) và `EmptyState.js` (hiển thị **No data** phân biệt rõ: *Chưa có dữ liệu* kèm nút Tạo mới vs *Không có kết quả lọc* kèm nút Xóa bộ lọc, và trạng thái **Lỗi mạng** kèm nút Thử lại).
- Tạo `StatCard.js`, `StatusBadge.js`, `FormModal.js`, `ConfirmModal.js`, `ToastNotice.js`.
- Đảm bảo mọi nút >= `44px`, bảng cuộn ngang mượt trên `375px`.
- **Commit:** `feat(admin-web): add reusable UI components and responsive AppShell`

### Bước 4: Trang Đăng nhập (`LoginPage.js`) & Hồ sơ Admin (`ProfilePage.js`)
- Nâng cấp màn hình Login (centered card, hiện/ẩn mật khẩu, thông báo lỗi rõ ràng, đẹp trên cả Mobile và Desktop).
- Nâng cấp trang Hồ sơ & Đổi mật khẩu Admin (`PATCH /users/me`, `PATCH /users/me/password`).
- **Commit:** `feat(admin-web): upgrade login and admin profile pages`

### Bước 5: Trang Tổng quan (`DashboardPage.js`)
- Hiển thị lưới `StatCard` responsive (4 cột Desktop, 2 cột Tablet, 1–2 cột Mobile).
- Cấu hình lại `Chart.js` theo theme Dark/Light của MetaGym (màu `#ff5a36`, `#70aee8`, `#23c997`, grid mờ, tooltip đồng bộ).
- **Commit:** `feat(admin-web): upgrade dashboard KPI cards and Chart.js theme`

### Bước 6: Trang Quản lý Hội viên & Coach (`UsersPage.js`)
- Dùng chung `UsersPage.js` cho cả `#/admin/members` và `#/admin/coaches` (tham số hóa theo `role`).
- Bổ sung thanh tìm kiếm (`?search=`), lọc trạng thái (`?status=`), phân trang bằng `DataTable`, modal tạo/sửa Coach (`FormModal`), xác nhận khóa/mở tài khoản (`ConfirmModal`) và đặt mật khẩu tạm cho Coach.
- **Commit:** `feat(admin-web): upgrade members and coaches management with reusable UsersPage`

### Bước 7: Trang Gói Hội viên & Gói Coach (`MembershipPlansPage.js`, `CoachPackagesPage.js`)
- Dùng `DataTable`, `StatusBadge` và `FormModal` để tạo/sửa gói, hiển thị giá VND rõ ràng bằng `.font-data`.
- **Commit:** `feat(admin-web): upgrade membership plans and coach packages pages`

### Bước 8: Trang Thanh toán (`PaymentsPage.js`)
- Hiển thị bảng giao dịch kèm lọc trạng thái (`PENDING`, `PAID`, `CANCELLED`).
- Nâng cấp form **Thanh toán tại quầy** (`POST /admin/front-desk-payments` kèm `Idempotency-Key`) và modal xác nhận cập nhật trạng thái giao dịch.
- **Commit:** `feat(admin-web): upgrade payments and front-desk checkout page`

### Bước 9: Trang Quan hệ Coach–Member & Yêu cầu chấm dứt (`RelationshipsPage.js`, `TerminationsPage.js`)
- Nâng cấp bảng quan hệ Coach–Member, modal **Chuyển Coach** (`POST /admin/coach-transfers`), và bảng lịch sử chuyển Coach.
- Nâng cấp trang duyệt/từ chối yêu cầu chấm dứt hợp tác (`PATCH /admin/termination-requests/:id`) bằng `ConfirmModal`.
- **Commit:** `feat(admin-web): upgrade coaching relationships and termination requests pages`

### Bước 10: Trang Phòng Gym & QR Check-in, Thiết bị, Thực phẩm (`GymPage.js`, `EquipmentPage.js`, `NutritionFoodsPage.js`)
- Nâng cấp `GymPage.js`: form cập nhật thông tin phòng gym + khu vực `#checkin-print` in mã QR sắc nét + `ConfirmModal` trước khi xoay vòng mã QR (`rotate`).
- Nâng cấp `EquipmentPage.js` và `NutritionFoodsPage.js` dùng `DataTable` + `FormModal` + `loading="lazy"` cho ảnh.
- Dọn sạch code cũ còn sót trong `main.js`.
- **Commit:** `feat(admin-web): upgrade gym QR, equipment, and nutrition catalog pages`

### Bước 11: Trang Quản lý Hình ảnh (`MediaPage.js` & `ImagePickerModal.js`)
> **Điều kiện tiên quyết:** Backend đã triển khai xong phần Image Server theo [`docs/architecture/image-server-media-management.md`](./image-server-media-management.md) (API `GET/POST/PATCH/DELETE /media/images` và `GET /admin/media/folders`).
- Xây dựng `MediaPage.js` (`#/admin/media`):
  - Bộ lọc `FilterBar`: lọc theo **Folder** (dropdown `equipment/`, `exercises/`, `gym/`, `avatars/`, `progress/`...), tìm theo tên file, checkbox chọn nhiều ảnh.
  - Hiển thị thanh tiến độ dung lượng đã dùng so với hạn mức **1 GB Supabase Storage Free**.
  - Lưới ảnh (`loading="lazy"`) + phân trang, hỗ trợ **Upload ảnh mới**, **Đổi tên / Chuyển folder** (`FormModal`), và **Xóa ảnh** (`ConfirmModal`).
- Xây dựng `ImagePickerModal.js` tái sử dụng để chọn/upload ảnh trực tiếp ngay trong form của `EquipmentPage.js` và `GymPage.js`.
- **Commit:** `feat(admin-web): add media library page and reusable ImagePickerModal`

---

## 5. Checklist nghiệm thu cuối cùng
- [ ] `cd admin-web && npm run build` thành công không lỗi/warning nghiêm trọng (kiểm tra Vite tách chunk cho các trang/thư viện nặng).
- [ ] `cd admin-web && npm test` pass toàn bộ.
- [ ] Kiểm tra chuyển qua lại giữa các trang: **Sidebar/Topbar không nhấp nháy load lại**, chỉ `#page-content` cập nhật.
- [ ] Kiểm tra giả lập mạng chậm (**Slow 3G** trong DevTools): có Skeleton Loading, timeout/retry rõ ràng, không văng trang trắng.
- [ ] Kiểm tra hiển thị ở **Desktop (`1280×800`)**, **Tablet (`768×1024`)**, **Mobile (`375×812`)** (Offcanvas menu mở/đóng mượt, không tràn ngang).
- [ ] Kiểm tra cả **Dark mode** và **Light mode** (độ tương phản chữ rõ ràng).
- [ ] Kiểm tra **Print Preview** trang Phòng gym (`#checkin-print` hiển thị sạch mã QR).
