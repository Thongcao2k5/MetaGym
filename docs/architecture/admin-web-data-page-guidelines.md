# Quy chuẩn thiết kế & triển khai Trang dữ liệu WebAdmin (`admin-web/`)

Tài liệu này tổng hợp toàn bộ khung UI, component dùng chung và quy ước hành vi đã chuẩn hóa trên nhánh **`thong`**, làm mẫu để các thành viên (`thong`, `thuc`, `truong_ship_it`) triển khai đồng bộ cho các trang dữ liệu còn lại.

> **Trang mẫu tham chiếu:** [`admin-web/src/pages/accounts.js`](../../admin-web/src/pages/accounts.js)  
> **Quy chuẩn thiết kế nền:** [`DESIGN.md`](../../DESIGN.md) · [`design-system/meta-gym/pages/admin-web.md`](../../design-system/meta-gym/pages/admin-web.md)

---

## 1. Khung App Shell, Điều hướng & Theme

- **Persistent AppShell (`components/layout.js`):**
  - Sau khi đăng nhập, `.admin-shell` được giữ cố định khi chuyển trang; chỉ cập nhật `#main-content`, tiêu đề Topbar, nút hành động và trạng thái `active` trên Sidebar (giữ nguyên vị trí cuộn Sidebar).
  - Sidebar trên Desktop hỗ trợ thu gọn (`76px`) / mở rộng (`260px`) qua nút 3 gạch ngang `#sidebar-collapse-btn`; trên Mobile (`<= 991px`) chuyển thành Offcanvas Drawer.
  - Logo `MG` luôn trỏ về `#/admin/dashboard` ở cả trạng thái mở rộng lẫn thu gọn.
- **Header góc phải (`topbar-account`):**
  - Chứa nút đổi Dark/Light (`services/theme.js`), thẻ Hồ sơ Admin (`#/admin/profile`) và nút Đăng xuất (`#logout`) trên cùng 1 hàng ngang.
  - Trên Mobile (`<= 767px`), ẩn phần tiêu đề/mô tả trang ở `.topbar-left > div` để Header chỉ còn 1 hàng gọn.
- **URL chuẩn & gọn:**
  - Dùng Hash Routing (`#/admin/<section>`): `dashboard`, `incidents`, `members`, `coaches`, `relationships`, `plans`, `coach-packages`, `payments`, `foods`, `gym`, `equipment`, `audit-logs`, `profile`.

---

## 2. Trạng thái Loading, Empty, Error & Modal

- **Skeleton Loading chỉ bọc vùng dữ liệu (`components/states.js`):**
  - Giữ nguyên **Tabs** (`.meta-tabs`) và **Thanh lọc** (`.filter-bar`) cố định khi đang tải; chỉ thay vùng bảng bằng `renderTableSkeleton()` (hoặc `renderDashboardSkeleton()` ở Tổng quan) để không bị giật layout.
- **Phân biệt rõ `Empty Data` và `System Error`:**
  - **Không có dữ liệu (`200 OK`, `0` dòng):** dùng `renderEmptyState()` hoặc `renderFilterEmptyState()` (hiển thị hình minh họa SVG tự thích ứng Dark/Light).
  - **Lỗi hệ thống / Mất kết nối:** dùng `renderErrorState()` (hoặc `renderDashboardSkeleton()` kèm Toast lỗi ở Tổng quan) và Modal báo lỗi giữa màn hình khi không khởi chạy được trang.
- **Không dùng `meta-banner banner-info` dài dòng trên trang:**
  - Giao diện vận hành giữ gọn sạch; chỉ giữ cảnh báo nghiệp vụ bắt buộc (như cảnh báo Snapshot giá/thời hạn trong modal hoặc thẻ gói).
- **Khóa scroll nền & Toast (`components/modal.js`, `components/drawer.js`, `components/toast.js`):**
  - Mở Modal/Drawer tự gắn `meta-scroll-locked` lên cả `html` và `body` để không trôi nền bên dưới.
  - `toast()` hiển thị ở góc trên bên phải, tự tắt sau `3.5s`, và tự gom + đếm lặp (`×2`, `×3`...) nếu thông báo giống nhau xuất hiện lại trong lúc đang hiển thị (ví dụ khi retry).

---

## 3. Thanh lọc, Bộ lọc nâng cao & Date Picker

- **Thanh `.filter-bar` tối giản (dùng chung Desktop & Mobile):**
  - Gồm: Ô tìm kiếm (`debounce 280ms`) + Dropdown lọc chính (trên Desktop) + Nút icon **Bộ lọc** (mở Modal bộ lọc tổng hợp kèm badge đếm số filter đang bật) + Nút **Xuất Excel**.
  - Các bộ lọc dạng checkbox (`Có gói Gym`, `Đang thuê Coach`, `Còn suất nhận...`) và bộ lọc ngày đều đặt gọn bên trong Modal **Bộ lọc** để thanh công cụ không bị phình dòng.
- **Date Picker tách theo thiết bị (`components/date-picker.js`, `components/date-range.js`):**
  - **Desktop (`> 767px`):** dùng 2 ô riêng `Từ ngày` / `Đến ngày` (`renderDateInput` + `bindDatePickers`) kèm các nút chọn nhanh; lịch popover dùng `position: fixed; z-index: 1700` để không bị cắt bởi khung modal.
  - **Mobile (`<= 767px`):** dùng 1 nút gộp (`renderDateRangePicker` + `bindDateRangePicker`) mở hộp chọn khoảng ngày trên tầng trên Modal (`z-index: 1700`).
  - **Ngày hiện tại (`.is-today`):** luôn được tô sáng rõ bằng viền & nền cam dịu `#FF5E36`.

---

## 4. Bảng dữ liệu, Phân trang, Toggle, Xuất Excel & Phân quyền

- **Checkbox chọn dòng & chọn tất cả (`components/data-table.js`):**
  - Truyền `selectable: true` vào `renderDataTable(...)` và gọi `bindDataTableSelection(root, { onSelectionChange })` để đồng bộ checkbox header (`indeterminate` / `checked`).
- **Xuất Excel (`components/export.js`):**
  - Dùng `exportToExcel({ filename, columns, rows })` (xuất `.csv` chuẩn UTF-8 BOM `\uFEFF` mở mượt trên Excel tiếng Việt).
  - Nếu người dùng có tick chọn dòng thì chỉ xuất các dòng đã chọn; nếu chưa tick dòng nào thì xuất toàn bộ dữ liệu đang hiển thị.
- **Phân trang chuẩn (`components/pagination.js`):**
  - **Mặc định `pageSize = 10` dòng/trang**, có dropdown chọn **`10 / 20 / 50 / 100`** dòng/trang (`onPageSizeChange` tự đưa về trang `1`).
  - Cụm nút phân trang căn giữa bảng:
    - **Desktop (`> 767px`):** liệt kê danh sách nút số trang (`1`, `2`, `3`..., rút gọn `…` nếu > 7 trang).
    - **Mobile (`<= 767px`):** tự thu gọn thành `Trước | Trang X / Y | Sau`.
- **Boolean ưu tiên dùng Toggle (`components/toggle.js`, `.meta-switch-btn`):**
  - Các trường/bộ lọc boolean dùng `renderToggle(...)` (ví dụ `login-remember`, `cp-frozen-only`).
  - Cột Trạng thái hoạt động/khóa trên bảng dùng switch trực tiếp (`ON` xanh `#2ECC71` = Đang hoạt động, `OFF` = Bị khóa) nối vào modal xác nhận nghiệp vụ thay vì lặp nút Khóa/Mở khóa ở cột Thao tác.
- **Nút thao tác gọn & Phân quyền `disabled` (`components/action-button.js`, `services/permissions.js`):**
  - Các nút thao tác cuối dòng dùng icon button (`.btn-icon`, `44×44px`) kèm `aria-label` và `title`.
  - Mọi nút thao tác dùng `renderActionButton({ permission, ... })` để **luôn hiển thị ở trạng thái `disabled`** (kèm tooltip giải thích lý do khi hover) nếu tài khoản chưa được phân quyền — không ẩn nút làm xô lệch cột.

---

## 5. Checklist trước khi commit / mở PR

1. Không dùng `window.confirm()`, `window.prompt()`, `window.alert()`.
2. Không dùng `backdrop-filter: blur` trên bảng, form, card hoặc modal Admin.
3. Chạy và pass toàn bộ:
   ```powershell
   cd admin-web
   npm test
   npm run build
   ```
