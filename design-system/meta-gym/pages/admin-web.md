# Meta Gym — Web Admin Design Brief (Operate Mode)

**Phạm vi:** toàn bộ cổng quản trị Web Admin Meta Gym (`admin-web`, Vite + Vanilla ESM + Bootstrap 5.3.8).  
**Kế thừa bắt buộc:** [`../../../DESIGN.md`](../../../DESIGN.md) (nguồn chuẩn cao nhất), [`../MASTER.md`](../MASTER.md), `docs/requirements/ui-design-spec.md`, và `docs/requirements/approved-decisions-2026-11-13.md` cùng các quyết định đã khóa D1–D7 (21/11/2026).  
**Trạng thái:** T4 Design Brief — duyệt cùng preview tương tác (`docs/previews/admin-web-preview.html`) tại Checkpoint 1 trước khi chỉnh sửa `admin-web/src/`.

---

## 1. Mục tiêu vận hành & ranh giới nghiệp vụ

Web Admin phục vụ **một Admin của một phòng gym** thực hiện các tác vụ vận hành hằng ngày: theo dõi doanh thu và ngoại lệ, quản lý tài khoản Member/Coach, danh mục gói Gym/Coach, ghi nhận thanh toán gói Gym tại quầy, xử lý sự cố `COACH_LOCKED` (chờ/chuyển/hoàn mô phỏng/mở khóa), phân xử tranh chấp kết thúc sớm, quản lý danh mục thực phẩm, hồ sơ phòng gym + mã QR điểm danh, thiết bị + thư viện bài tập và nhật ký hệ thống (audit log).

### Ranh giới tuyệt đối (Không đưa vào UI hay API Admin)

1. **Không còn luồng duyệt chọn Coach (`PENDING`):** tuyệt đối không hiển thị KPI, tab, badge hay hàng đợi "yêu cầu chọn Coach đang chờ". Member chọn gói Coach và thanh toán mô phỏng trực tiếp trên app.
2. **Không sửa trần cứng 8 Member/Coach:** không có ô nhập `memberLimit` khi tạo hoặc sửa Coach; luôn hiển thị trần cứng `x/8` (đã gồm suất `ACTIVE`, `PAUSED` và giữ chỗ 15 phút).
3. **Không bán gói Coach tại quầy:** form thu tiền tại quầy chỉ bán **gói Gym**.
4. **Không hoàn tiền thật:** mọi hoàn tiền cho sự cố Coach là **hoàn tiền mô phỏng (D3)**, ghi nhận bút toán mô phỏng nội bộ và chống hoàn trùng.
5. **Tách biệt quyền riêng tư (Privacy Allowlist):** Admin chỉ thấy dữ liệu vận hành. Tuyệt đối **không hiển thị** nhật ký tập, ảnh tiến độ, số đo (ngực/eo/mông), biểu đồ cá nhân, nội dung chat 1–1, ghi chú sức khỏe nhạy cảm hay hội thoại AI Coach trên bất kỳ bảng, drawer, dashboard hay audit log nào.
6. **Không hiển thị UUID thô trong bảng danh sách:** mọi bảng danh sách hiển thị **họ tên người dùng** (kèm avatar/email hoặc mã giao dịch). UUID chỉ xuất hiện trong **Drawer chi tiết** và **Chi tiết Audit Log** phục vụ đối soát kỹ thuật.

---

## 2. Hệ thống thị giác (Operate Mode — Dark Graphite)

Admin Web vận hành ở **Operate Mode (Dark Graphite mặc định: `<html lang="vi" data-bs-theme="dark">`)**, thay thế hoàn toàn giao diện nền sáng xanh lá cũ. Ưu tiên đọc bảng dày đặc không mỏi mắt, phân cấp số liệu sắc nét và xác nhận an toàn trước thao tác rủi ro cao.

### 2.1 Bảng màu chuẩn (`DESIGN.md`)

| Vai trò | Token CSS | Hex / RGBA | Quy tắc sử dụng |
| --- | --- | --- | --- |
| Nền canvas chính | `--meta-background` | `#0F1115` | Scaffold nền ngoài, vùng main canvas |
| Bề mặt card / bảng / form | `--meta-surface` | `#181B22` | Bề mặt graphite đặc Level 1; không blur |
| Bề mặt nổi / hover / header bảng | `--meta-surface-raised` | `#1F232C` | Table header, row hover, input raised, sub-panel |
| Viền cấu trúc 1px | `--meta-border` | `#262A34` | Tách card, bảng, input, divider (không dùng shadow nặng) |
| Chữ chính | `--meta-text-primary` | `#F7F9FC` / `#FFFFFF` | Tiêu đề, số KPI, giá trị cột chính |
| Chữ phụ / metadata | `--meta-text-secondary` | `#8E95A5` | Nhãn phụ, mốc thời gian, trạng thái chưa diễn ra |
| Điểm nhấn thương hiệu (CTA chính) | `--meta-primary` | `#FF5E36` | Duy nhất CTA chính, mục nav/tab đang chọn, điểm nhấn cốt lõi (~5–10% viewport) |
| Hover CTA chính | `--meta-primary-hover` | `#E84E27` | Trạng thái hover/active nút Primary |
| Chữ & icon trên nền cam | `--meta-on-primary` | `#FFFFFF` | Bắt buộc `#FFFFFF` trên `#FF5E36` / `#E84E27` |
| Thành công / Hiệu lực / Net | `--meta-success` | `#2ECC71` | `ACTIVE`, hoàn thành, doanh thu ròng (`on-success: #06261D`) |
| Cảnh báo / Chờ xử lý | `--meta-warning` | `#F39C12` | `COACH_LOCKED`, `SCHEDULED`, `QUEUED`, cảnh báo đóng băng (`on-warning: #2A1900`) |
| Lỗi / Nguy hiểm / Tranh chấp / Hoàn | `--meta-danger` | `#F15B64` | `DISABLED`, `DISPUTED`, `MEMBER_LOCKED`, hoàn/hủy, lỗi 409 (`on-error: #2C080B`) |
| Thông tin / Snapshot | `--meta-info` | `#70AEE8` | Banner snapshot, thông tin hệ thống (`on-info: #071A2C`) |
| Phản xạ lạnh / Vòng focus | `--meta-reflection` / `--meta-focus` | `#A9C7E8` / `#8DBCF0` | Viền nhấn kỹ thuật & focus ring bàn phím 2–3px |
| Avatar Coach chuẩn | `--meta-coach-avatar` | `#F5B041` (chữ `#181B22` đậm) | Áp dụng nhất quán cho avatar Coach (ví dụ `LN` Lê Hoàng Nam) |
| Màn che Modal / Drawer | `--meta-scrim` | `rgba(4, 6, 9, 0.72)` | Chỉ dùng làm backdrop cho modal xác nhận và detail drawer |

### 2.2 Quy tắc vật liệu & chống lạm dụng cam/kính

- **100% Solid Graphite trên bề mặt dữ liệu:** bảng, form, biểu đồ, KPI card, sidebar và drawer dùng bề mặt đặc `#181B22` / `#1F232C` + viền `1px solid #262A34`. **Cấm `backdrop-filter` / glass blur** trên bảng, form, card và biểu đồ Admin.
- **Ngân sách Coral Orange `#FF5E36` (5–10% viewport):** tối đa **1 nút Primary cam** mỗi vùng quyết định. Badge/pill nhỏ không tô cam đặc; dùng nền graphite pha tint thấp (`rgba(..., 0.14)`) + viền mảnh `1px` + chữ đạt tương phản `>= 4.5:1`.
- **Không dùng cam cho cảnh báo:** cảnh báo luôn dùng `#F39C12`; lỗi/nguy hiểm luôn dùng `#F15B64`.

### 2.3 Kiểu chữ & Số liệu

- **Font duy nhất:** `Be Vietnam Pro` (self-host ở bản production `admin-web`; dùng Google Fonts trong file HTML preview độc lập).
- **Phân cấp:**
  - Tiêu đề trang (`headline-md`): `24px / 700 / 1.25`
  - Số KPI (`data-lg`): `28px / 700 / 1.15`, `font-variant-numeric: tabular-nums`
  - Tiêu đề card/modal (`title-md`): `17px / 600 / 1.4`
  - Nội dung bảng & form (`body-md`): `14px / 400 / 1.5`
  - Nhãn nút & cột (`label-lg` / `label-md`): `14px / 600` và `12px / 600`
- **Tabular figures bắt buộc (`font-variant-numeric: tabular-nums`):** toàn bộ số tiền VND (`5.400.000 ₫`), số buổi (`14/20`), suất Coach (`6/8`), ngày/giờ múi giờ Việt Nam (`Asia/Ho_Chi_Minh`), phân trang và trục/tooltip biểu đồ.

### 2.4 Hình khối, Khoảng cách, Trợ năng & Responsive

- **Nhịp khoảng cách:** đơn vị `4px`, nhịp mặc định `8px`; gutter trang `24px` (desktop/tablet) và `16px` (375px); padding card `16px` (compact) / `20px` (standard) / `24px` (modal/featured). Tránh lồng card trong card.
- **Bo góc:** `6px` (`xs` badge/code), `10px` (`sm` compact control/table pill), `14px` (`md` button/input), `20px` (`lg` card/modal/drawer), `999px` (`full` avatar/chip).
- **Trợ năng (WCAG AA + bàn phím):**
  - Tương phản chữ thường `>= 4.5:1` (`#F7F9FC` trên `#181B22` = 16.5:1; `#8E95A5` trên `#181B22` = 5.73:1; `#8E95A5` trên `#1F232C` = 5.24:1); thành phần điều khiển & focus `>= 3:1`.
  - Mọi control tương tác (nút, ô nhập, tab, mục điều hướng, phân trang, nút đóng modal) đạt tối thiểu **`44×44px`** hit target.
  - Hỗ trợ điều khiển hoàn toàn bằng bàn phím (`Tab`, `Shift+Tab`, `Enter`, `Escape` đóng modal/drawer), skip link, focus ring `#8DBCF0` rõ ràng, hỗ trợ `prefers-reduced-motion` và phóng to chữ đến 200%.
  - Mọi trạng thái luôn có **biểu tượng + nhãn chữ tiếng Việt + màu** (không phụ thuộc màu đơn lẻ).
  - Dùng một bộ icon vector nét `1.75–2px`, không dùng emoji làm icon cấu trúc.
- **4 Breakpoint kiểm thử bắt buộc:**
  - **Desktop `1440px`:** Sidebar cố định `260px`, KPI 3–4 cột, bảng đầy đủ cột, Detail Drawer `480px`.
  - **Laptop `1024px`:** Sidebar gọn `228px`, KPI 3 cột, bảng tự co giãn gọn cột phụ vào Drawer chi tiết.
  - **Tablet `768px`:** Sidebar chuyển thành Offcanvas Drawer mở bằng nút `44×44px` ở topbar; KPI 2 cột; bộ lọc xếp 2 hàng gọn.
  - **Màn hẹp `375px`:** Offcanvas Drawer sidebar, KPI 1 cột, **toàn bộ bảng dữ liệu chuyển thành thẻ dọc (stacked cards)** với cặp `Nhãn — Giá trị` rõ ràng, không tràn ngang (`overflow-x: hidden`), chân modal ghim nút hành động dễ bấm.

---

## 3. Sơ đồ thông tin (Sitemap) & Thứ tự điều hướng

### 3.1 Cấu trúc Sidebar (nhóm theo tác vụ vận hành)

| Nhóm | Mục điều hướng | Route đề xuất | Badge cảnh báo |
| --- | --- | --- | --- |
| *(Ngoài shell)* | 1. Đăng nhập & Hết phiên | `#/admin/login?returnUrl=...` | — |
| **Vận hành** | 2. Tổng quan | `#/admin/dashboard` | — |
| **Vận hành** | 7. Sự cố Coach (`COACH_LOCKED`) | `#/admin/coach-incidents` | Số Member đang chờ xử lý (`#F39C12`) |
| **Khách hàng** | 3. Tài khoản (Member & Coach) | `#/admin/accounts?role=MEMBER\|COACH` | — |
| **Khách hàng** | 8. Quan hệ & Kết thúc sớm | `#/admin/relationships` | Số ca `DISPUTED` (`#F15B64`) |
| **Gói & Tiền** | 4. Gói Gym & Quyền sử dụng | `#/admin/gym-plans` | — |
| **Gói & Tiền** | 5. Gói Coach & Quyền lợi | `#/admin/coach-packages` | — |
| **Gói & Tiền** | 6. Giao dịch tại quầy & Lịch sử | `#/admin/payments` | — |
| **Nội dung** | 9. Thực phẩm & kcal | `#/admin/nutrition-foods` | — |
| **Nội dung** | 10. Phòng gym & QR điểm danh | `#/admin/gym-profile` | — |
| **Nội dung** | 11. Thiết bị & Thư viện bài tập | `#/admin/catalog-training` | — |
| **Kiểm soát** | 12. Nhật ký hệ thống (Audit) | `#/admin/audit-logs` | — |
| *(Footer rail)* | Hồ sơ Admin & Đổi mật khẩu / Đăng xuất | `#/admin/profile` | — |

### 3.2 Bản đồ Deep-link từ Tổng quan (KPI -> Danh sách đã lọc)

| Thành phần trên Tổng quan | Đích điều hướng & Query giữ nguyên khi reload |
| --- | --- |
| Banner khẩn: Member chờ do `COACH_LOCKED` | `#/admin/coach-incidents?status=WAITING` |
| Banner khẩn: Tranh chấp kết thúc sớm (`DISPUTED`) | `#/admin/relationships?tab=terminations&status=DISPUTED` |
| KPI: Member hoạt động | `#/admin/accounts?role=MEMBER&status=ACTIVE` |
| KPI: Coach hoạt động | `#/admin/accounts?role=COACH&status=ACTIVE` |
| KPI: Gói Gym đang hiệu lực | `#/admin/gym-plans?tab=entitlements&status=ACTIVE` |
| KPI: Gói Coach đang hiệu lực | `#/admin/coach-packages?tab=entitlements&status=ACTIVE` |
| KPI: Doanh thu gộp / Hoàn mô phỏng / Doanh thu ròng | `#/admin/payments?from={from}&to={to}` (lọc sẵn `type=SIMULATED_REFUND` khi bấm thẻ Hoàn mô phỏng) |
| *(Đã loại bỏ vĩnh viễn)* | *Không có KPI "Yêu cầu chọn Coach `PENDING`"* |

---

## 4. Đặc tả chi tiết 12 màn hình & luồng rủi ro cao

Mọi màn danh sách đều hỗ trợ đủ 6 trạng thái: **Có dữ liệu**, **Đang tải (Skeleton)**, **Trống toàn bộ**, **Không khớp bộ lọc (có nút xóa lọc)**, **Lỗi mạng/409 (giữ bộ lọc & dữ liệu đã nhập)**, và **Phân trang**.

### Màn 1 — Đăng nhập, Hết phiên & Đổi mật khẩu Admin
- **Điểm tập trung đầu tiên:** thẻ đăng nhập graphite đặc `#181B22` căn giữa, nhận diện thương hiệu `META GYM ADMIN`, form Email + Mật khẩu.
- **Trạng thái bắt buộc:**
  - Sai email/mật khẩu (`401`): thông báo inline gắn sát form, giữ nguyên email đã nhập.
  - Tài khoản bị khóa (`403`): thông báo rõ tài khoản đã bị vô hiệu hóa và không cấp phiên.
  - Hết phiên (`SESSION_EXPIRED`): banner `#F39C12` thông báo *"Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại"* và hiển thị/giữ `returnUrl` để quay lại đúng trang + bộ lọc sau khi đăng nhập thành công.
  - Đổi mật khẩu Admin (từ Hồ sơ Admin): mật khẩu hiện tại, mật khẩu mới (hoa/thường/số >= 8 ký tự), xác nhận mật khẩu; thành công sẽ thu hồi phiên cũ và chuyển về màn Đăng nhập.

### Màn 2 — Tổng quan (Dashboard)
- **Header & Bộ lọc kỳ:** chọn `Từ ngày` / `Đến ngày` + phím nhanh `7 ngày`, `30 ngày`, `Tháng này`, hiển thị rõ múi giờ `Asia/Ho_Chi_Minh (GMT+7)`.
- **Banner việc cần xử lý ngay (Urgent Action Banner):** chỉ hiển thị khi có `COACH_LOCKED` đang chờ hoặc tranh chấp `DISPUTED` quá 72h; mỗi mục có nút hành động dẫn thẳng vào hàng chờ tương ứng.
- **Khối tài chính (D3):** 3 chỉ số đặt nổi bật với `tabular-nums`:
  1. `Doanh thu gộp (Gross)` — tổng thanh toán `SUCCESS` trong kỳ.
  2. `Hoàn tiền mô phỏng (Refunds)` — tổng bút toán hoàn mô phỏng trong kỳ (`#F15B64`).
  3. `Doanh thu ròng (Net = Gross − Refunds)` — (`#2ECC71`).
- **Lưới KPI vận hành (bấm được):** Member hoạt động, Coach hoạt động, Gói Gym `ACTIVE`, Gói Coach `ACTIVE`, Member chờ do `COACH_LOCKED`, Tranh chấp `DISPUTED`.
- **Biểu đồ doanh thu theo ngày:** biểu đồ cột graphite đặc (`#181B22`) dùng cột Coral `#FF5E36` (Gross) / Emerald `#2ECC71` (Net) và chỉ dấu `#F15B64` (Refund), trục và tooltip dùng `tabular-nums`.

### Màn 3 — Tài khoản (Member & Coach)
- **Cấu trúc:** 2 tab phân vai (`Hội viên` / `Huấn luyện viên`), thanh tìm kiếm server-side (tên, email, SĐT), lọc trạng thái (`ACTIVE`/`DISABLED`), phân trang, nút `+ Tạo Coach`.
- **Cột bảng (không UUID):**
  - Member: Họ tên + avatar, Liên hệ, Gói Gym (`ACTIVE`/`SCHEDULED`/`EXPIRED`), Quan hệ Coach hiện tại (tên Coach + badge trạng thái), Trạng thái tài khoản, Thao tác (`Chi tiết`, `Khóa/Mở`).
  - Coach: Họ tên + avatar (`#F5B041`/`#181B22` cho Coach), Liên hệ, **Suất học viên (`6/8` — thanh tiến trình + ghi chú số suất giữ chỗ 15 phút; trần cứng 8 không sửa được)**, Lịch cố định (`6 ngày/tuần · 4 khung`), Trạng thái, Thao tác (`Chi tiết`, `Mật khẩu tạm`, `Khóa/Mở`).
- **Modal Tạo Coach:** Họ tên, Email, SĐT, Mật khẩu ban đầu, Chuyên môn. **Tuyệt đối không có ô `memberLimit`**; hiển thị nhãn chỉ đọc *"Giới hạn suất cứng: 8 hội viên / Coach"*.
- **Drawer Chi tiết tài khoản (chỉ dữ liệu vận hành):** hiển thị UUID kỹ thuật, thông tin liên hệ, gói hiện hành, quan hệ hiện tại, lịch sử khóa/mở khóa. Có nhãn xác nhận phạm vi riêng tư (không hiển thị nhật ký, ảnh, số đo, chat 1–1, ghi chú sức khỏe nhạy cảm, AI).
- **Modal Cấp mật khẩu tạm (1 lần):** sinh mật khẩu tạm hiển thị đúng một lần kèm nút `Sao chép`, thông báo đã thu hồi toàn bộ phiên cũ của Coach, và ghi chú rõ *"Coach đăng nhập bình thường bằng mật khẩu tạm và được nhắc đổi mật khẩu trong ứng dụng"*.
- **Modal Khóa tài khoản (Luồng rủi ro cao #1 — Impact Confirmation):**
  - *Khóa Coach:* liệt kê danh sách Member đang thuê Coach đó, số lịch tương lai sẽ bị hủy không trừ buổi, và nêu rõ quy tắc: thu hồi phiên ngay, quan hệ chuyển `COACH_LOCKED`, **gói Coach đóng băng thời hạn & giữ nguyên số buổi**, **gói Gym vẫn chạy bình thường**. Bắt buộc nhập lý do (`1–500` ký tự).
  - *Khóa Member (D4):* nêu rõ tác động khi Member đang thuê Coach: ẩn hồ sơ sức khỏe với Coach, hủy lịch tương lai không trừ buổi, **giữ nguyên suất Coach**, **thời hạn gói Gym & Coach tiếp tục chạy**, quan hệ chuyển `PAUSED (MEMBER_LOCKED)`. Bắt buộc nhập lý do.
- **Modal Mở khóa Coach (D1 Auto-Restore Preview):** hiển thị danh sách Member đang ở trạng thái chờ (`COACH_LOCKED`, chưa chuyển và chưa hoàn) sẽ được tự động khôi phục về `ACTIVE` cùng số ngày đóng băng được cộng bù **đúng 1 lần**.

### Màn 4 — Gói Gym & Quyền sử dụng
- **2 tab:** `Danh mục gói Gym` và `Quyền sử dụng (Entitlements)`.
- **Danh mục:** cho phép tạo mới và **sửa trực tiếp giá VND và số ngày** (không khóa 409 khi đã có người mua). Luôn hiển thị banner thông tin `#70AEE8`: *"Thay đổi chỉ áp dụng cho giao dịch mới; các gói đã mua giữ nguyên snapshot giá và số ngày."*
- **Quyền sử dụng:** lọc theo `ACTIVE` / `SCHEDULED` / `EXPIRED`, hiển thị tên Member, tên gói snapshot, giá snapshot, ngày bắt đầu–kết thúc (VN), trạng thái.

### Màn 5 — Gói Coach & Quyền lợi
- **2 tab:** `Danh mục gói Coach` và `Quyền lợi gói Coach`.
- **Danh mục (Full CRUD):** không cố định 3 mã gói; hỗ trợ tạo mới và sửa tên, mô tả, số buổi (`sessionCount`), số ngày (`durationDays`), giá VND, trạng thái (`Đang bán` / `Ngừng bán`). Giữ banner cảnh báo snapshot chỉ áp dụng giao dịch mới và quy ước mỗi buổi 90 phút.
- **Quyền lợi:** lọc theo `ACTIVE` / `QUEUED` / `ENDED`; hiển thị tên Member, tên Coach, tên gói snapshot, số buổi còn/tổng (`14/20`), số ngày đóng băng (`COACH_LOCKED`), ngày hết hạn (kèm trạng thái gia hạn bổ sung tối đa 7 ngày không cộng dồn), trạng thái.

### Màn 6 — Giao dịch tại quầy Gym & Lịch sử
- **Khu vực Thu tiền tại quầy (chỉ gói Gym):**
  - Banner nhắc rõ không bán gói Coach tại quầy.
  - **Bộ chọn Member tìm kiếm server-side** (an toàn với >100 hội viên; tìm theo tên/email/SĐT và hiển thị trạng thái gói Gym hiện tại của Member).
  - **Bộ chọn gói Gym** (chỉ các gói `ACTIVE`).
  - **Khung xem trước trực tiếp:** số tiền VND (`tabular-nums`), trạng thái kết quả (`ACTIVE` ngay hoặc `SCHEDULED` nối tiếp sau ngày hết hạn hiện tại), ngày bắt đầu–kết thúc theo giờ Việt Nam, và `Idempotency-Key` tự sinh theo tổ hợp `(memberId, planId)` (retry giữ nguyên khóa; đổi Member/gói sinh khóa mới).
  - **Modal xác nhận thu tiền:** tóm tắt Member, gói, giá VND, hiệu lực dự kiến trước khi gửi.
- **Bảng Lịch sử giao dịch:** lọc theo mã giao dịch/tên Member, loại giao dịch (`Gói Gym tại quầy`, `Gói Gym trên app`, `Gói Coach trên app`, `Hoàn tiền mô phỏng D3`, `Điều chỉnh VOID/REVERSAL D6`), trạng thái, khoảng ngày; phân trang. Hiển thị tên người thay UUID.
- **Drawer Chi tiết & Modal Điều chỉnh `VOID / REVERSAL` (Luồng rủi ro cao #4 — D6):**
  - Chỉ mở cho giao dịch tại quầy `SUCCESS` trong ngày và chưa sử dụng.
  - Nêu rõ **không sửa hoặc xóa bản gốc**: hệ thống tạo bút toán đảo âm, thu hồi quyền lợi gói tương ứng và ghi audit. Bắt buộc lý do.

### Màn 7 — Sự cố Coach (`COACH_LOCKED`)
- **Hàng chờ sự cố:** liệt kê từng Coach đang bị khóa (`COACH_LOCKED`) cùng danh sách Member bị ảnh hưởng, số ngày gói Coach đã đóng băng, ghi chú gói Gym vẫn chạy, gói `QUEUED` đi kèm (nếu có), và lựa chọn của Member (`Chờ Coach` hoặc `Chọn hoàn mô phỏng`).
- **Modal Chuyển Coach thay thế (Luồng rủi ro cao #2 — D2):**
  - Hiển thị danh sách Coach thay thế với kiểm tra thực tế trên server: suất hiện tại `< 8` (gồm cả giữ chỗ 15 phút) **và** đủ công suất lịch cho **cả gói `ACTIVE` lẫn gói `QUEUED`** của Member.
  - Coach đủ điều kiện có thể chọn (ví dụ `Lê Hoàng Nam · 6/8 suất · Đủ công suất`); Coach đầy trần 8/8 hoặc thiếu công suất bị vô hiệu hóa kèm lý do cụ thể.
  - Khung xem trước tác động: cộng số ngày đóng băng **đúng 1 lần**, giữ nguyên số buổi còn lại, chuyển kèm gói `QUEUED`, hủy lịch tương lai với Coach cũ không trừ buổi, lưu giáo án cũ chỉ đọc (Coach mới không kế thừa), chat 1–1 không bị khóa/không ép tạo lại. Bắt buộc lý do.
- **Modal Hoàn tiền mô phỏng (Luồng rủi ro cao #3 — D3):**
  - Hiển thị bảng tính công thức minh bạch (`tabular-nums`):
    - Phần gói `ACTIVE`: `floor(giá_snapshot × buổi_còn / tổng_buổi / 1.000) × 1.000 VND`.
    - Phần gói `QUEUED` (D2): hoàn **100%** giá snapshot.
    - Tổng tiền hoàn mô phỏng + mã khóa chống hoàn trùng (unique guard).
  - Nêu rõ: chỉ ghi bút toán hoàn mô phỏng, không hoàn tiền thật; kết thúc quan hệ (`ENDED`), hủy lịch tương lai, lưu giáo án cũ chỉ đọc, giải phóng suất. Bắt buộc lý do.

### Màn 8 — Quan hệ & Kết thúc sớm
- **3 tab:** `Quan hệ Member–Coach`, `Kết thúc sớm & Tranh chấp (D5)`, `Lịch sử chuyển Coach`.
- **Phân biệt rõ mọi badge tạm ngưng & trạng thái:**
  - `Đang hoạt động` (`#2ECC71`)
  - `Tạm ngưng · Hết gói Gym` (`#8E95A5` — thời hạn gói Coach vẫn chạy)
  - `Tạm ngưng · Coach bị khóa` (`#F39C12` — gói Coach đóng băng)
  - `Tạm ngưng · Member bị khóa` (`#F15B64` — ẩn hồ sơ sức khỏe, hủy lịch không trừ buổi, giữ suất, thời hạn chạy)
  - `Chờ đồng ý 72h` (`#70AEE8`) & `Tranh chấp · DISPUTED` (`#F15B64`)
  - `Đã kết thúc` (`#8E95A5`)
- **Modal Phân xử tranh chấp (Luồng rủi ro cao #5 — D5):**
  - Hiển thị bên đề nghị kết thúc sớm, mốc đếm ngược 72h (tự động chuyển `DISPUTED` khi hết hạn hoặc bất đồng), số buổi còn lại, và 2 quyết định của Admin (`Chấp thuận kết thúc sớm → ENDED` hoặc `Từ chối → giữ quan hệ`).
  - Xem trước hậu quả mọi đường `ENDED`: hủy lịch tương lai, lưu giáo án cũ chỉ đọc, trả suất đúng 1 lần, chat 1–1 vẫn dùng khi 2 tài khoản hợp lệ; buổi chưa dùng mất hiệu lực ở kết thúc thông thường. Bắt buộc lý do.

### Màn 9 — Thực phẩm & kcal
- **Nâng cấp từ danh sách card rời rạc cũ sang bảng vận hành chuẩn:** tìm kiếm, lọc trạng thái (`Hiển thị`/`Ẩn`), phân trang, sắp xếp theo tên hoặc kcal/100g.
- **Modal Thêm / Sửa thực phẩm:** Tên thực phẩm (`<= 150` ký tự), `kcal / 100g` (số `0..1000`, bước `0.01`, `tabular-nums`), trạng thái `Cho phép chọn` / `Ẩn`. Ghi chú rõ việc ẩn không làm hỏng thực đơn 7 ngày đang dùng snapshot/tham chiếu.

### Màn 10 — Phòng gym & Mã QR điểm danh
- **Bố cục 2 cột (Desktop) / xếp chồng (Tablet & Mobile):**
  - **Cột trái — Form hồ sơ đầy đủ:** Tên phòng gym, Địa chỉ, Điện thoại, Email, Giờ mở cửa, Nội quy, Mô tả, Ảnh bìa (URL + kiểm tra ảnh lỗi an toàn).
  - **Cột phải — Xem trước công khai & Thẻ QR tại quầy:**
    - Card xem trước giao diện Member/Coach thấy trên app.
    - Card **Mã QR điểm danh tại quầy** có nền trắng vùng yên tĩnh (`quiet zone`) chuẩn in, tên + địa chỉ gym, nút `In mã QR` (`@media print` chỉ in thẻ QR sạch sẽ) và nút `Đổi mã QR` mở modal xác nhận cảnh báo mọi bản in cũ sẽ hết hiệu lực ngay lập tức.

### Màn 11 — Thiết bị & Thư viện bài tập (`exercises`)
- **Workspace 2 tab gọn gàng:**
  - **Tab 1 — Thiết bị:** bảng có tìm kiếm, lọc nhóm cơ/danh mục & trạng thái (`Hiển thị`/`Ẩn`), nút `Xem trước công khai`, modal Thêm/Sửa gồm: Tên thiết bị, Danh mục, Nhóm cơ mục tiêu, Các bước sử dụng, Lưu ý an toàn, Ảnh/Video URL (có fallback khi media hỏng), Trạng thái.
  - **Tab 2 — Thư viện bài tập (`exercises`):** bảng có tìm kiếm, lọc độ khó (`Cơ bản`/`Trung bình`/`Nâng cao`), thiết bị liên kết & trạng thái; modal Thêm/Sửa gồm: Tên bài tập, Thiết bị liên kết, Độ khó, Nhóm cơ chính/phụ, Hướng dẫn từng bước, Lưu ý an toàn, Video hướng dẫn URL, Trạng thái `Hiển thị`/`Ẩn`.

### Màn 12 — Nhật ký hệ thống (Audit Log)
- **Bảng lọc & phân trang:** lọc theo người thao tác, nhóm hành động (`USER_LOCKED`, `COACH_UNLOCKED`, `COACH_TRANSFER`, `SIMULATED_REFUND`, `PAYMENT_VOID_REVERSAL`, `DISPUTE_ADJUDICATED`, `CATALOG_UPDATED`, `GYM_QR_ROTATED`), đối tượng và khoảng thời gian VN.
- **Cột bảng:** Thời gian VN (`DD/MM/YYYY HH:mm:ss` `tabular-nums`), Người thao tác, Hành động, Đối tượng (tên người/gói + loại thực thể), Lý do, nút `Chi tiết`.
- **Drawer Chi tiết Audit:** hiển thị Audit UUID, Target UUID, Request/Idempotency ID, và **JSON Before/After đã qua bộ lọc an toàn** (tuyệt đối không ghi mật khẩu thô, mật khẩu tạm, nhật ký tập, ảnh, số đo, tin nhắn hay ghi chú sức khỏe).

---

## 5. Ma trận quyền, riêng tư & trạng thái nghiệp vụ

### 5.1 Ma trận phạm vi dữ liệu Admin (Privacy Allowlist)

| Nhóm dữ liệu | Admin Web | Ghi chú bắt buộc |
| --- | --- | --- |
| Hồ sơ vận hành tài khoản (tên, email, SĐT, vai trò, trạng thái, suất Coach `x/8`) | Cho phép | UUID chỉ hiện trong Detail Drawer & Audit |
| Gói Gym, Gói Coach, Entitlement snapshot, Giao dịch, Hoàn mô phỏng, `VOID/REVERSAL` | Cho phép | Kiểm tra & tính tiền ở server |
| Quan hệ Member–Coach, Sự cố `COACH_LOCKED`, Tranh chấp `DISPUTED`, Lịch sử chuyển | Cho phép | Mọi tác động đều ghi Audit + lý do |
| Thực phẩm/kcal, Phòng gym, QR điểm danh, Thiết bị, Bài tập (`exercises`) | Cho phép | Hỗ trợ `ACTIVE`/`HIDDEN`, không xóa lịch sử |
| Nhật ký tập, ảnh tiến độ, số đo (ngực/eo/mông), biểu đồ cá nhân Member | **Cấm tuyệt đối** | Server từ chối `403`, không có trường trong response |
| Tin nhắn chat 1–1, ghi chú sức khỏe nhạy cảm, hội thoại AI Coach | **Cấm tuyệt đối** | Không hiển thị ở UI, không xuất hiện trong Audit |

### 5.2 Hệ thống Badge trạng thái nhất quán

| Trạng thái | Màu chữ / Viền | Nền tint trên `#181B22` | Nhãn tiếng Việt chuẩn |
| --- | --- | --- | --- |
| `ACTIVE` / `SUCCESS` | `#2ECC71` / `rgba(46,204,113,0.35)` | `rgba(46,204,113,0.12)` | `Đang hoạt động` / `Thành công` |
| `SCHEDULED` / `QUEUED` | `#70AEE8` / `rgba(112,174,232,0.35)` | `rgba(112,174,232,0.12)` | `Đã xếp lịch` / `Chờ nối tiếp` |
| `COACH_LOCKED` / `WAITING` | `#F39C12` / `rgba(243,156,18,0.40)` | `rgba(243,156,18,0.14)` | `Coach bị khóa` / `Đang chờ Coach` |
| `MEMBER_LOCKED` / `DISPUTED` / `DISABLED` | `#FF7C84` (chữ AA >= 5.3:1) / `rgba(241,91,100,0.40)` | `rgba(241,91,100,0.12)` | `Member bị khóa` / `Tranh chấp` / `Bị khóa` |
| `PAUSED (GYM_EXPIRED)` / `EXPIRED` / `ENDED` / `HIDDEN` | `#8E95A5` / `rgba(142,149,165,0.30)` | `rgba(142,149,165,0.12)` | `Hết gói Gym` / `Hết hạn` / `Đã kết thúc` / `Đang ẩn` |
| `SIMULATED_REFUND` / `VOID_REVERSAL` | `#FF7C84` (chữ AA >= 5.3:1) / `rgba(241,91,100,0.38)` | `rgba(241,91,100,0.12)` | `Hoàn mô phỏng` / `Đã đảo bút toán` |

> **Lưu ý tương phản nút nguy hiểm (WCAG AA >= 4.5:1):** Nút hành động phá hủy đặc dùng nền `--meta-danger` (`#F15B64`) bắt buộc đi với chữ `--meta-on-danger` (`#2C080B`, đậm 700 — đạt `5.60:1` theo `DESIGN.md`); các badge/nút tint đỏ trên graphite `#181B22`/`#1F232C` dùng chữ `#FF7C84` trên nền `rgba(241,91,100,0.12)` để đạt `>= 5.3:1`.

---

## 6. Bộ component chuẩn & hợp đồng tương tác (T6 Mapping)

1. **App Shell & Sidebar:** Sidebar đặc `#181B22` viền phải `1px #262A34`. Mục đang chọn có thanh chỉ báo trái `3px #FF5E36`, nền `#1F232C`, chữ `#FFFFFF` đậm; không tô cam đặc toàn bộ menu.
2. **Filter Bar & Table:** Thanh lọc đặt trong card `#181B22` đầu danh sách, gồm ô tìm kiếm debounce, bộ chọn trạng thái/loại, nút `Xóa bộ lọc`. Header bảng dùng `#1F232C`, chữ `#8E95A5` `12px/600`; hàng hover `#1F232C`; không zebra quá chói. Ở `<= 767px`, bảng chuyển sang thẻ dọc giữ đủ cột thông tin & nút thao tác `>= 44px`.
3. **High-Risk Confirmation Modal:** Nền `#181B22`, viền `1px #262A34`, scrim `rgba(4, 6, 9, 0.72)`. Cấu trúc chuẩn 4 phần: (a) Tiêu đề + mức độ rủi ro, (b) Bảng tóm tắt đối tượng & tác động số liệu cụ thể, (c) Ô nhập lý do bắt buộc có đếm ký tự `0/500`, (d) Nút Hủy graphite + Nút xác nhận khóa cho tới khi hợp lệ và chống gửi trùng khi đang xử lý.
4. **Inline Validation & Error Recovery (409 / Mạng):** Lỗi từng ô gắn ngay dưới input bằng `#F15B64` + icon. Khi gặp `409 Conflict` hoặc mất mạng, hiển thị banner lỗi có hướng dẫn khôi phục và **giữ nguyên toàn bộ dữ liệu Admin đã nhập** để bấm `Thử lại`.
5. **Skeleton, Empty & Filter-Empty:** Skeleton dùng thanh xung nhẹ trên `#1F232C` (tắt animation khi `prefers-reduced-motion: reduce`). Empty tách biệt rõ giữa *"Chưa có bản ghi nào"* (CTA tạo mới) và *"Không có kết quả khớp bộ lọc"* (CTA xóa lọc).

---

## 7. Walkthrough 5 tác vụ cốt lõi (Kiểm chứng T4)

1. **Tìm Member trong danh sách >100 người:** Vào `Tài khoản → Hội viên`, gõ tên/SĐT ở ô tìm kiếm server-side → bảng trả danh sách tên người (không UUID) + phân trang; bấm `Chi tiết` mở Drawer vận hành (không lộ nhật ký/số đo/chat).
2. **Bán gói Gym tại quầy:** Vào `Giao dịch tại quầy & Lịch sử`, tìm Member bằng combobox server-side → chọn gói Gym `ACTIVE` → kiểm tra khung xem trước VND & ngày `ACTIVE`/`SCHEDULED` (VN) + Idempotency Key → bấm `Xác nhận thu tiền` → xem bản ghi mới trong lịch sử (và có thể `VOID/REVERSAL` trong ngày nếu chưa dùng).
3. **Sửa giá/số ngày gói Gym hoặc thêm gói Coach mới:** Vào `Gói Gym` hoặc `Gói Coach`, thấy banner snapshot → sửa trực tiếp giá/ngày hoặc tạo gói Coach mới không bị giới hạn 3 mã → lưu thành công; tab `Quyền sử dụng / Quyền lợi` giữ nguyên snapshot cũ.
4. **Khóa Coach đang có Member:** Vào `Tài khoản → Huấn luyện viên`, bấm `Khóa` → Modal Impact hiện rõ số Member ảnh hưởng, số lịch tương lai bị hủy không trừ buổi, quy tắc `COACH_LOCKED` đóng băng gói Coach (gói Gym vẫn chạy) → nhập lý do bắt buộc → xác nhận; Coach chuyển `Bị khóa`, Member xuất hiện ngay ở `Sự cố Coach`.
5. **Xử lý Member bị `COACH_LOCKED` (Chờ / Chuyển / Hoàn / Mở khóa):** Vào `Sự cố Coach`, thấy lựa chọn của từng Member →
   - Nếu chuyển: mở Modal `Chuyển Coach`, chỉ chọn được Coach `< 8` suất (gồm hold 15p) và đủ công suất lịch cho cả `ACTIVE` + `QUEUED`, xem trước số ngày đóng băng cộng đúng 1 lần.
   - Nếu hoàn: mở Modal `Hoàn mô phỏng`, kiểm tra công thức `floor(snapshot × còn / tổng / 1000) × 1000` + hoàn 100% `QUEUED` + mã chống hoàn trùng.
   - Nếu mở khóa trước khi chuyển: mở Modal `Mở khóa Coach (D1)`, xem trước danh sách Member tự động khôi phục + ngày bù đóng băng đúng 1 lần.

---

## 8. Screen Review Checklist (Đối chiếu `DESIGN.md` & UI/UX Pro Max)

- [x] Điểm tập trung đầu tiên của từng màn rõ ràng trong 3 giây (KPI/Urgent Banner, bảng lọc, hoặc form giao dịch).
- [x] 100% bề mặt dữ liệu Admin dùng Solid Graphite (`#0F1115` / `#181B22` / `#1F232C` / `#262A34`), không blur trên bảng/form/biểu đồ.
- [x] Coral Orange `#FF5E36` giới hạn 5–10% viewport cho CTA chính và trạng thái active; chữ/icon trên cam là `#FFFFFF`.
- [x] Đạt tương phản chữ `>= 4.5:1`, control/focus `>= 3:1`; màu trạng thái luôn đi kèm chữ và icon.
- [x] Mọi mục tương tác đạt hit target `>= 44×44px`; điều khiển trọn vẹn bằng bàn phím và hỗ trợ `prefers-reduced-motion`.
- [x] Đủ trạng thái: Dữ liệu mẫu, Skeleton Loading, Empty, Filter-Empty, Lỗi 409/Mạng giữ form, Disabled, Success.
- [x] Không còn KPI `PENDING` cũ, không còn ô sửa `memberLimit`, không bán gói Coach tại quầy, không lộ UUID ở danh sách, không lộ dữ liệu riêng tư.
- [x] Kiểm tra bố cục sạch ở 4 kích thước: `1440px`, `1024px`, `768px` và `375px` (không tràn ngang).
