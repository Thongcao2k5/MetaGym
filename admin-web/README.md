# Meta Gym Admin web

Admin web là ứng dụng Vite dùng JavaScript modules, Bootstrap và Chart.js. Trong
môi trường phát triển, chạy backend tại `http://127.0.0.1:3000`, sau đó:

```bash
npm ci
npm run dev
```

Vite chuyển tiếp `/api` tới backend. Khi triển khai ở origin khác, đặt
`VITE_API_BASE_URL` thành URL của API có hậu tố `/api/v1` trước khi build.
Không đặt JWT secret hoặc mật khẩu vào biến Vite vì chúng sẽ xuất hiện trong
JavaScript gửi tới trình duyệt. Access token Admin chỉ được giữ trong
`sessionStorage` của tab và bị xóa khi đăng xuất hoặc đổi mật khẩu.

```bash
npm run build
npm test
```

`npm test` kiểm tra thao tác khóa/mở tài khoản và payload gửi tới API, gồm
lý do khóa bắt buộc và các trường hợp hủy nhập.

Tài khoản đăng nhập phải có vai trò `ADMIN`. Backend chịu trách nhiệm kiểm tra
vai trò và trạng thái tài khoản ở mỗi yêu cầu.

## Thư viện Component dùng chung (`#/admin/design`)

Dev có thể vào mục **Thiết kế** ở cuối menu sidebar (`#/admin/design`, triển khai tại `src/pages/design-system.js`) để xem trước trực tiếp các component ở cả chế độ **Desktop** và **Mobile (`375px`)**, đồng thời tái sử dụng từ `src/components/`:

| Module | Thành phần chính | Công dụng |
| --- | --- | --- |
| `src/components/layout.js` | `renderShell`, `NAV_GROUPS`, `PAGE_META` | Khung AppShell cố định, Sidebar thu gọn, Header & nút điều khiển. |
| `src/components/notifications.js` | `bindNotificationBell`, `refreshNotifications` | Chuông thông báo realtime trên Header (Desktop popover, Mobile chuyển `#/admin/notification`). |
| `src/components/select-dropdown.js` | `renderSelectDropdown`, `bindSelectDropdowns` | Dropdown chọn 1 mục dạng pill, mục đang chọn tô nền cam hệ thống. |
| `src/components/multi-select.js` | `renderMultiSelect`, `bindMultiSelects` | Dropdown checkbox chọn nhiều mục kèm ô `Tất cả`. |
| `src/components/date-picker.js` & `date-range.js` | `renderDateInput`, `renderDateRangePicker`, `DATE_PRESETS` | Bộ chọn ngày tách Desktop (2 ô) / Mobile (1 khung gộp) + chọn nhanh. |
| `src/components/data-table.js` | `renderDataTable`, `bindDataTableSelection` | Bảng dữ liệu có checkbox chọn dòng; tự thu gọn thẻ trên Mobile kèm nút `Xem thêm / Thu gọn`. |
| `src/components/pagination.js` | `renderPagination`, `bindPagination` | Phân trang có chọn `10/20/50/100` dòng; Desktop hiện số trang, Mobile thu gọn `Trước \| X / Y \| Sau`. |
| `src/components/action-button.js` | `renderActionButton` | Nút icon thao tác cuối dòng, tự động hiển thị `disabled` + tooltip khi thiếu quyền. |
| `src/components/toggle.js` | `renderToggle` | Công tắc gạt boolean chuẩn `44px`. |
| `src/components/modal.js` & `drawer.js` | `openModal`, `openConfirmModal`, `openAlertModal`, `openDrawer` | Modal chuẩn, Confirm có lý do bắt buộc, Alert 4 trạng thái (`success`/`warn`/`danger`/`info`) & Detail Drawer. |
| `src/components/toast.js` | `toast`, `notice` | Toast nền theo loại (`success`/`warn`/`danger`/`info`), chữ & icon trắng, viền trái cam; trượt từ đáy trên Mobile. |
| `src/components/states.js` | `renderTableSkeleton`, `renderEmptyState`, `renderFilterEmptyState`, `renderErrorState`, `renderBanner` | Skeleton đa cột (Desktop & Mobile), trạng thái rỗng, lỗi hệ thống và banner. |
| `src/components/export.js` | `exportToExcel` | Xuất CSV chuẩn UTF-8 BOM cho Excel tiếng Việt (hỗ trợ xuất theo dòng đã chọn). |
| `src/components/format.js` & `icons.js` | `vnd`, `formatDateVN`, `emailInitial`, `statusBadge`, `seatMeterHtml`, `icon` | Định dạng tiền tệ/ngày giờ VN, badge trạng thái, thanh suất Coach và bộ icon SVG. |

Xem thêm quy chuẩn áp dụng cho các trang dữ liệu tại [`docs/architecture/admin-web-data-page-guidelines.md`](../docs/architecture/admin-web-data-page-guidelines.md).
