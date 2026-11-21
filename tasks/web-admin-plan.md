# Kế hoạch thiết kế và triển khai Web Admin Meta Gym

**Ngày lập:** 21/11/2026  
**Trạng thái:** đã hoàn tất Bước 0a/0b, Giai đoạn 0 (T1–T3, Checkpoint 0), Giai đoạn 1 (T4–T6, Checkpoint 1), Giai đoạn 2 (T7–T11, Checkpoint 2), **T12 Backend + Migration `0032`** và **T13 Backend** (UI tạm dừng theo chỉ đạo người dùng — tiếp tục từng task Backend + DB + test)  
**Repository & nhánh xác minh:** `f:/AndroidProjects/MetaGym`, nhánh `thong` (`origin/thong`, chỉ push nhánh `thong`, không merge vào `main`). Đã đồng bộ `origin/main` và giữ nguyên Swagger UI (`/api-docs`, `ddd8942`) + `/ping` keep-alive (`f4a53b0`), áp dụng migration `0001`..`0032` (55 bảng `public` + `uq_termination_open_relationship` qua `schema_assertions.sql`), hoàn tất Web Admin Dark Graphite Operate Mode + API/DB cho T7–T11, đồng bộ Flutter T7–T10, hoàn tất **T12 Backend + Migration `0032` (`e47ad89`)** (Relationships V2 API + D5 kết thúc sớm thỏa thuận 2 bên 72h + tự động chuyển `DISPUTED` + Admin phán quyết tranh chấp + retire luồng ghi cũ `410 LEGACY_WORKFLOW_RETIRED`), và hoàn tất **T13 Backend (`7f88e93`)** (Hàng chờ sự cố Coach `COACH_LOCKED`, Member chọn `WAIT`/`REFUND`, kiểm tra công suất Coach đủ điều kiện nhận chuyển và chuyển Coach D2 bảo toàn cả gói `ACTIVE` kèm ngày đóng băng đúng 1 lần + gói `QUEUED`, 98/99 backend tests PASS).

**Tài liệu & sản phẩm đã hoàn tất (Wave 1):**
- T1 Audit: [`docs/requirements/web-admin-t1-audit.md`](../docs/requirements/web-admin-t1-audit.md)
- T2 Quyết định D1–D7 & ma trận trạng thái: [`docs/requirements/web-admin-decisions-and-states.md`](../docs/requirements/web-admin-decisions-and-states.md)
- T3 Hợp đồng API, allowlist quyền riêng tư & kế hoạch migration `0029`–`0033`: [`docs/requirements/web-admin-api-contract.md`](../docs/requirements/web-admin-api-contract.md)
- T4 Brief & đặc tả 12 màn Web Admin (Operate Mode Dark Graphite): [`design-system/meta-gym/pages/admin-web.md`](../design-system/meta-gym/pages/admin-web.md)
- T5 Preview HTML tương tác độc lập: [`docs/previews/admin-web-preview.html`](../docs/previews/admin-web-preview.html)
- T6 Bộ token Bootstrap đồng bộ `DESIGN.md`: [`design-system/meta-gym/adapters/bootstrap-theme.css`](../design-system/meta-gym/adapters/bootstrap-theme.css)

## 1. Mục tiêu và ranh giới

Web Admin phục vụ **một Admin của một phòng gym**: theo dõi vận hành, quản lý tài khoản, danh mục gói Gym và Coach, giao dịch mô phỏng, quan hệ Member–Coach và ngoại lệ, danh mục thực phẩm, thông tin phòng gym và thiết bị. Member/Coach tiếp tục dùng Flutter. Mọi thay đổi phải phản ánh đúng quyền và trạng thái trên hai vai trò đó.

**Định nghĩa hoàn thành:** Admin hoàn tất được các tác vụ vận hành thực tế từ đầu đến cuối; các quy tắc quyền, tiền, buổi tập, thời hạn và công suất được kiểm tra trên server; có audit và các màn lỗi/trống; chạy được trên môi trường triển khai đã chọn với quy trình phục hồi.

**Không suy diễn thành tính năng:** Admin không duyệt yêu cầu chọn Coach; không đọc chat, nhật ký riêng, số đo, ảnh, biểu đồ, AI hay ghi chú sức khỏe nhạy cảm; không sửa trần cứng 8 Member/Coach; không bán gói Coach tại quầy; không tích hợp hoàn tiền thật. Đề xuất luồng Admin cũ trong `admin-flow-proposal.md` đã bị tài liệu quyết định 13/11 thay thế ở các điểm này.

## 2. Nguồn quyết định và thứ tự ưu tiên

1. Quyết định người dùng mới nhất và `docs/requirements/approved-decisions-2026-11-13.md`.
2. PDF Admin cuối cùng và PDF Member–Coach được trích dẫn trong sổ quyết định, cần mở tại repository ứng dụng khi truy cập được.
3. `docs/requirements/ui-design-spec.md` và `DESIGN.md` cho giao diện.
4. Luồng và mã hiện hành chỉ là trạng thái cần kiểm toán, không tự động là nghiệp vụ đích.

Không có brief Admin riêng trong `design-system/meta-gym/pages/`; phải tạo brief màn Admin sau khi xác minh tài liệu và mã, trước khi dựng preview.

## 3. Quyết định D1–D7 (đã chốt ngày 21/11/2026)

| ID | Vấn đề | Quy tắc đã chốt (chi tiết tại `docs/requirements/web-admin-decisions-and-states.md`) | Trạng thái |
| --- | --- | --- | --- |
| D1 | Mở khóa Coach trước khi chuyển Member | Tự động khôi phục các quan hệ `COACH_LOCKED` chưa chuyển/hoàn về `ACTIVE` (hoặc `PAUSED / MEMBERSHIP_EXPIRED` nếu Gym hết hạn trong lúc khóa), cộng đúng số ngày đóng băng vào `ends_on` (một lần duy nhất, idempotent, audit + thông báo) | Đã chốt (T2) |
| D2 | Gói Coach `QUEUED` khi chuyển hoặc hoàn mô phỏng | Chuyển: chuyển cả gói `ACTIVE` còn lại và gói `QUEUED` sang Coach mới (giữ snapshot, kiểm tra công suất cả 2 cửa sổ hợp lệ `from <= through`); Hoàn: hoàn `ACTIVE` theo D3 + hoàn 100% giá snapshot `QUEUED` | Đã chốt (T2) |
| D3 | Hoàn tiền mô phỏng | `Math.floor((snapshotPrice * remainingSessions / totalSessions) / 1000) * 1000` (làm tròn xuống bội số 1.000 VND); lưu bảng hoàn mô phỏng riêng + unique theo `coach_entitlement_id` + `Idempotency-Key` + lý do bắt buộc; Dashboard báo cáo Gross / Refunds / Net | Đã chốt (T2) |
| D4 | Khóa Member đang thuê Coach | Chuyển quan hệ sang `PAUSED (MEMBER_LOCKED)`: ẩn hồ sơ sức khỏe nhạy cảm với Coach, hủy lịch `BOOKED` tương lai không trừ buổi, giữ suất Coach, đồng hồ gói Gym & Coach vẫn chạy (không đóng băng); mở khóa khôi phục theo hiệu lực thực tế | Đã chốt (T2) |
| D5 | Kết thúc sớm/tranh chấp | Một bên gửi yêu cầu kèm lý do → đối phương có 72 giờ Chấp nhận (kết thúc ngay, mất buổi chưa dùng, hủy lịch tương lai, lưu giáo án chỉ đọc, trả suất 1 lần) hoặc Từ chối / quá 72 giờ tự chuyển `DISPUTED` để Admin phán quyết (có lý do + audit) | Đã chốt (T2) |
| D6 | Sửa giao dịch tại quầy đã `SUCCESS` | Không bao giờ sửa âm thầm bản gốc; cho phép `VOID/REVERSAL` bằng bản ghi điều chỉnh riêng (+ lý do + audit) chỉ khi cùng ngày nghiệp vụ Việt Nam hoặc quyền gói chưa phát sinh sử dụng, hủy quyền gói liên quan để tạo giao dịch thay thế sạch | Đã chốt (T2) |
| D7 | Kiến trúc triển khai | Giữ Supabase (PostgreSQL + `meta-gym-media`) + Render Free (`backend`) + Cloudflare Pages (`admin-web`); giữ `admin-web` trên Vite 8 + Vanilla ESM JS mô-đun + Bootstrap 5.3.8; diễn tập migration `0029`–`0033` & smoke test trước khi phát hành | Đã chốt (T2–T3) |

**Bổ sung phạm vi đã chốt (21/11/2026):** giữ mã QR check-in ở Hồ sơ phòng gym; giữ `member_nutrition_tracking` ngoài phạm vi Web Admin (403 cho Admin/Coach); **thêm** quản lý Thư viện bài tập (`exercises`) vào Web Admin; cho phép sửa trực tiếp giá/ngày gói Gym (bỏ `409 PLAN_TERMS_LOCKED`, chỉ áp dụng giao dịch mới nhờ snapshot) và CRUD đầy đủ gói Coach (bỏ giới hạn 3 mã cứng); khóa cứng trần `member_limit = 8` trên DB/server; chặn gửi chat mới khi người nhận `DISABLED`; mật khẩu tạm Coach đăng nhập bình thường kèm nhắc đổi mật khẩu trên UI; gỡ/chặn `AdminHomePage` cũ trong Flutter.

## 4. Sơ đồ thông tin và màn hình

| Khu vực | Màn/chức năng | Hành động chính và trạng thái phải thiết kế |
| --- | --- | --- |
| Đăng nhập | Đăng nhập, hết phiên, đổi mật khẩu | Lỗi xác thực, khóa tài khoản, tải lại phiên; mật khẩu tạm nếu luồng hiện hành hỗ trợ |
| Tổng quan | KPI theo kỳ, việc cần xử lý | Member/Coach, gói Gym/Coach, giao dịch, Member chờ xử lý do `COACH_LOCKED`; KPI dẫn tới danh sách đã lọc, không có yêu cầu chọn Coach `PENDING` |
| Tài khoản | Danh sách/chi tiết Member và Coach | Tìm/lọc/phân trang, tạo Coach, khóa/mở khóa, lý do và lịch sử; không lộ dữ liệu riêng |
| Gói Gym | Danh sách, tạo/sửa/ngừng bán, quyền sử dụng | Giá VND, ngày hiệu lực, snapshot giao dịch, `ACTIVE`/`SCHEDULED`/hết hạn |
| Gói Coach | Danh mục, tạo/sửa/ngừng bán, quyền sử dụng | Số buổi, thời hạn, giá, `QUEUED`; cảnh báo thay đổi chỉ áp dụng giao dịch mới |
| Giao dịch | Tại quầy Gym, lịch sử, chi tiết | Tìm Member toàn bộ danh sách, xác nhận nhận tiền, idempotency, lọc/phân trang, giao dịch hoàn mô phỏng theo D3 |
| Quan hệ | Danh sách, chi tiết, kết thúc/tranh chấp | `ACTIVE`/`PAUSED`/`ENDED`, lý do, lịch sử, tác động lịch và giáo án, D5 |
| Sự cố Coach | Khóa, Member ảnh hưởng, chờ/chuyển/hoàn, mở khóa | `COACH_LOCKED`, đóng băng gói Coach, công suất Coach thay thế, lựa chọn của Member, audit, D1–D3 |
| Nội dung vận hành | Thực phẩm/kcal, phòng gym, thiết bị | CRUD phù hợp, ảnh/video khi được hỗ trợ, ẩn/hiện, preview nội dung công khai |
| Nhật ký hệ thống | Audit thao tác Admin | Ai, khi nào, đối tượng, lý do, trước/sau ở mức an toàn; lọc và chi tiết |

Mỗi danh sách có loading, empty toàn bộ, không có kết quả lọc, lỗi và phân trang. Mỗi form có kiểm tra hợp lệ, đang lưu, thành công, lỗi mạng và xung đột đồng thời; lỗi giữ dữ liệu đã nhập. Thao tác có hậu quả lớn dùng trang/xác nhận nêu rõ đối tượng, tác động và trạng thái sau thao tác.

## 5. Thiết kế giao diện

- **Mode:** Operate. Admin ưu tiên đọc nhanh, thao tác chắc chắn và lịch sử truy vết. Desktop là màn chính; tablet và màn hẹp vẫn dùng được, bảng chuyển sang danh sách/chi tiết khi thiếu chiều ngang.
- **Hệ thống thị giác:** Be Vietnam Pro; canvas `#0F1115`, card `#181B22`, viền `#262A34`, chữ chính `#FFFFFF`, chữ phụ `#8E95A5`. Cam `#FF5E36` chỉ cho hành động chính/active; chữ và icon trên cam trắng, nhãn nhỏ dùng kiểu viền hoặc chữ cam trên graphite. Form, bảng, biểu đồ và Admin dùng graphite đặc; không trải kính/blur trên bề mặt dữ liệu.
- **Khung trang:** điều hướng trái theo tác vụ; tiêu đề trang + mô tả kỳ/bộ lọc; vùng nội dung ưu tiên bảng tìm kiếm và việc cần xử lý. Không đặt KPI chỉ để lấp khoảng trống. Chi tiết giữ đường quay lại danh sách và trạng thái lọc.
- **Bảng:** tên người thay UUID ở danh sách; UUID chỉ hiện trong chi tiết/audit. Số liệu VND, số buổi, thời gian dùng tabular figures; trạng thái có chữ và màu; cột hành động có nhãn rõ và menu khi nhiều lựa chọn.
- **Trợ năng:** tương phản chữ thường tối thiểu 4.5:1; control/focus 3:1; điều khiển bằng bàn phím; focus nhìn thấy được; thông báo lỗi gắn ô; không phụ thuộc màu; text scaling và reduced motion. Kiểm tra ít nhất desktop 1440px, laptop 1024px, tablet 768px và màn hẹp 375px.
- **Đầu ra thiết kế:** brief Admin, sơ đồ điều hướng, ma trận quyền/trạng thái, wireframe tác vụ, preview tương tác của các luồng rủi ro cao, bộ component/table/form/dialog, bản mô tả API dữ liệu từng màn và ảnh kiểm tra ở các kích thước. Nếu yêu cầu preview trước code, duyệt preview rồi mới thay đổi ứng dụng.

## 6. Kiến trúc và hợp đồng dữ liệu dự kiến

Giữ stack hiện có sau khi kiểm toán repository; không chọn framework mới theo suy đoán. Web Admin gọi API server, không chứa logic quyết định quyền hoặc tiền chỉ ở client. Server xác thực phiên Admin tại mọi endpoint và giới hạn dữ liệu theo vai trò; thu hồi phiên khi khóa. Giao dịch quan trọng (giữ suất, thanh toán, khóa Coach, chuyển, kết thúc, hoàn mô phỏng) phải atomic hoặc có cơ chế nhất quán được chứng minh; mọi retry dùng idempotency theo ý định nghiệp vụ.

Trước khi code, lập bảng cho từng endpoint: dữ liệu trả về, quyền, lọc/phân trang, mã lỗi, audit, tác động Member/Coach và trường tuyệt đối không được trả. Schema phải phân biệt gói Gym với gói Coach; cấu hình danh mục với entitlement snapshot; `PAUSED` do Gym hết hạn với `COACH_LOCKED`; `QUEUED` với `SCHEDULED`; giao dịch mua với giao dịch hoàn. Dữ liệu thời gian lưu nhất quán và hiển thị theo múi giờ Việt Nam.

## 7. Lộ trình triển khai theo lát cắt

### Giai đoạn 0 — Xác minh nền tảng và chốt thiết kế kỹ thuật

**T1. Kiểm toán repository và chênh lệch nghiệp vụ.** Kiểm tra cấu trúc `admin-web`, backend, database, auth, Flutter, test và cách chạy/deploy; đối chiếu từng quy tắc mới với mã. **Nghiệm thu:** bảng `đã có / thiếu / luồng cũ / cần migration`, đường dẫn mã cụ thể, lệnh build/test thực tế. **Kiểm chứng:** chạy ứng dụng và test hiện hành, ghi baseline. **Phụ thuộc:** truy cập repository.

**T2. Chốt D1–D7 và ma trận trạng thái.** Viết quy tắc chuyển trạng thái, actor, điều kiện, hiệu ứng, thông báo và ví dụ biên cho khóa/mở, chuyển, chờ, hoàn, kết thúc. **Nghiệm thu:** từng quyết định có ví dụ đầu vào/kết quả, người chốt, ngày chốt; không còn nhánh UI phải tự đoán. **Kiểm chứng:** walkthrough với các ca Gym hết hạn, Coach khóa, gói `QUEUED`, thanh toán đang giữ suất. **Phụ thuộc:** T1.

**T3. Chốt hợp đồng API, migration và quyền riêng tư.** Thiết kế endpoint, query, pagination, validation, versioning, audit, idempotency, dữ liệu ẩn; kế hoạch chuyển từ `coach_requests` và luồng chat/giáo án cũ. **Nghiệm thu:** contract có request/response/error mẫu; migration lên/xuống hoặc phục hồi; bảng quyền Admin/Coach/Member. **Kiểm chứng:** review contract với frontend và backend, kiểm tra ca quyền bị từ chối. **Phụ thuộc:** T1–T2.

**Checkpoint 0:** không bắt đầu UI dữ liệu thật khi T2–T3 chưa chốt; có baseline chạy được và danh sách rủi ro migration.

### Giai đoạn 1 — Thiết kế Web Admin

**T4. Brief, sitemap và hành trình tác vụ.** Ghi mục tiêu từng màn, thứ tự điều hướng, deep link KPI, ma trận quyền/trạng thái. **Nghiệm thu:** mọi màn mục 4 có entry, hành động và trạng thái; không còn mục `PENDING` cũ. **Kiểm chứng:** walkthrough 5 tác vụ: tìm Member, bán Gym, sửa gói, khóa Coach, xử lý chờ/chuyển/hoàn. **Phụ thuộc:** T2–T3.

**T5. Wireframe và preview luồng rủi ro cao.** Thiết kế dashboard, danh sách/chi tiết, form giao dịch tại quầy, khóa Coach, chuyển/hoàn, trạng thái lỗi. **Nghiệm thu:** tác động và dữ liệu được thấy trước xác nhận; không cần nhớ UUID; dữ liệu nhạy cảm vắng mặt. **Kiểm chứng:** xem preview ở 1440/1024/768/375px, bàn phím và text scaling. **Phụ thuộc:** T4.

**T6. Component và giao diện chi tiết.** Chuẩn hóa table, filter, status, form, confirmation, toast/inline error, empty, pagination; mapping token sang web. **Nghiệm thu:** các trạng thái tương tác đủ; tương phản/focus đúng; không dùng blur ở bảng/form. **Kiểm chứng:** review ảnh render và thao tác bàn phím. **Phụ thuộc:** T5.

**Checkpoint 1:** duyệt thiết kế và contract trước khi thay Web Admin; ghi quyết định thay đổi trong brief Admin, không sửa token toàn sản phẩm nếu không cần.

### Giai đoạn 2 — Nền tảng chức năng (MVP)

**T7. Xác thực Admin và audit nền.** Phiên, hết phiên, kiểm tra quyền server, thu hồi khi khóa; cơ chế log thao tác. **Nghiệm thu:** API không có quyền trả 401/403; thay đổi ghi actor/time/reason; không lộ dữ liệu ngoài phạm vi. **Kiểm chứng:** test API và thử trực tiếp endpoint không qua UI. **Phụ thuộc:** T3.

**T8. App shell và pattern dữ liệu.** Route, navigation, loading/error, API client, filter/query state, pagination, responsive layout. **Nghiệm thu:** reload/deep link giữ đúng trang; lỗi không làm mất bộ lọc/form; 375px không tràn tác vụ cốt lõi. **Kiểm chứng:** build web, kiểm tra bàn phím và các breakpoint. **Phụ thuộc:** T6–T7.

**T9. Tài khoản Member/Coach.** Tìm/lọc/phân trang, chi tiết vận hành, tạo Coach, khóa/mở Member và Coach theo D1/D4. **Nghiệm thu:** khóa Coach ngay dù có Member; phiên bị thu hồi; quan hệ chuyển `COACH_LOCKED` và gói Coach đóng băng; không sửa trần 8. **Kiểm chứng:** API + UI + Flutter cho ca có/không có quan hệ, lỗi đồng thời. **Phụ thuộc:** T7–T8, D1/D4.

**T10. Danh mục gói Gym/Coach và entitlement.** CRUD/ngừng bán, snapshot giá/quyền lợi, các trạng thái đang dùng/chờ. **Nghiệm thu:** sửa gói chỉ ảnh hưởng giao dịch mới; gói Coach `QUEUED` tối đa một; gói cũ vẫn đọc được. **Kiểm chứng:** test snapshot sau sửa gói và UI Member liên quan. **Phụ thuộc:** T7–T8, migration T3.

**T11. Giao dịch tại quầy Gym và lịch sử.** Tìm Member toàn bộ dữ liệu, xác nhận gói/giá/ngày, idempotency, `ACTIVE`/`SCHEDULED`, lọc và phân trang. **Nghiệm thu:** thử lại cùng payload/khóa không nhân đôi; đổi Member/gói tạo khóa mới; giao dịch Coach không xuất hiện tại quầy. **Kiểm chứng:** test retry, mất mạng, Member >100, gói nối tiếp. **Phụ thuộc:** T10.

**Checkpoint 2:** Admin đăng nhập, quản lý tài khoản/gói và bán Gym được đầu-cuối; Flutter hiển thị đúng quyền gói; audit đầy đủ; test quyền riêng tư qua API đạt.

### Giai đoạn 3 — Quan hệ Coach và xử lý ngoại lệ

**T12. Quan hệ và tác vụ kết thúc sớm.** Danh sách/chi tiết, trạng thái/lý do, đồng ý hai bên và tranh chấp theo D5. **Nghiệm thu:** mọi đường `ENDED` hủy lịch tương lai, lưu giáo án cũ chỉ đọc, giải phóng suất đúng một lần; chat vẫn hoạt động khi tài khoản hợp lệ. **Kiểm chứng:** test trạng thái và quyền Coach/Member sau mỗi đường kết thúc. **Phụ thuộc:** T9–T10, D5.

**T13. Hàng chờ sự cố Coach và chuyển Coach.** Hiển thị Member ảnh hưởng, lựa chọn chờ/chuyển, suất tối đa 8 cộng hold, kiểm tra đủ công suất lịch, giữ buổi/thời hạn còn lại. **Nghiệm thu:** lịch cũ hủy không trừ buổi; phần đóng băng cộng đúng một lần; Coach mới không kế thừa giáo án; chat không bị khóa/tạo lại bắt buộc. **Kiểm chứng:** test đồng thời khóa/chuyển/hold/đặt lịch, kiểm tra ngày qua mốc nửa đêm Việt Nam. **Phụ thuộc:** T9–T12, D1–D2.

**T14. Hoàn tiền mô phỏng.** Luồng Member chọn hoàn, công thức D3, giao dịch hoàn và audit. **Nghiệm thu:** giá snapshot được dùng; hai lần gửi không hoàn hai lần; quyền và `QUEUED` xử lý đúng D2; không tạo yêu cầu hoàn tiền thật. **Kiểm chứng:** test làm tròn, retry, lỗi giữa giao dịch, xem lịch sử. **Phụ thuộc:** T11–T13, D2–D3.

**T15. Dashboard theo dữ liệu thật.** KPI theo kỳ, việc cần xử lý, liên kết danh sách có filter tương ứng. **Nghiệm thu:** không có KPI yêu cầu chọn Coach `PENDING`; số liệu đối chiếu được với danh sách và kỳ thống kê; trạng thái rỗng/lỗi rõ. **Kiểm chứng:** đối soát số liệu mẫu và deep link. **Phụ thuộc:** T11–T14.

**Checkpoint 3:** kịch bản khóa Coach → Member chờ/chuyển/hoàn → mở khóa, và kết thúc sớm chạy đầu-cuối trên Admin + Flutter; invariants suất/buổi/thời hạn đúng.

### Giai đoạn 4 — Danh mục vận hành và phát hành

**T16. Thực phẩm và kcal.** Tìm/lọc, tạo/sửa/ẩn, kiểm tra đơn vị/giá trị; tác động thực đơn 7 ngày. **Nghiệm thu:** thực đơn hiện hành dùng quy tắc snapshot/tra cứu đã chốt trong contract; không phát sinh giá trị kcal sai âm/tham chiếu mất. **Kiểm chứng:** kiểm tra Coach tạo thực đơn và Member xem sau khi đổi danh mục. **Phụ thuộc:** T3, T8.

**T17. Phòng gym và thiết bị.** Chỉnh thông tin gym, CRUD/ẩn thiết bị, hướng dẫn và an toàn, preview nội dung công khai. **Nghiệm thu:** trường bắt buộc hợp lệ; ẩn không xóa lịch sử; Member/Coach thấy nội dung sau lưu. **Kiểm chứng:** UI và API với danh sách >100, ảnh/video hỏng, lỗi mạng. **Phụ thuộc:** T8.

**T18. Hoàn thiện audit, bảo mật và khả dụng.** Trang audit, kiểm tra payload/log, focus, tương phản, empty/error, responsive, hiệu năng danh sách. **Nghiệm thu:** dữ liệu riêng không có trong API/web/log; mọi hành động quan trọng có bản ghi; thao tác bàn phím hoàn tất được. **Kiểm chứng:** API authorization matrix, accessibility pass, kiểm tra tải với dữ liệu thực tế. **Phụ thuộc:** T9–T17.

**T19. Staging, migration rehearsal và phát hành.** Tạo cấu hình môi trường, secrets, HTTPS, backup, migrate, smoke test, rollback, giám sát lỗi. **Nghiệm thu:** cùng bản build chạy staging; migration thử trên bản sao dữ liệu; checklist release và rollback được diễn tập; Admin hoàn tất 5 tác vụ chính sau deploy. **Kiểm chứng:** CI build/test, smoke test staging và production, kiểm tra audit/monitoring. **Phụ thuộc:** T18, D7.

**Checkpoint cuối:** không còn luồng cũ trong Web Admin; mọi ca kiểm thử quyết định đã duyệt đạt; chủ sản phẩm xác nhận nghiệm thu trên staging trước phát hành.

## 8. Ưu tiên và mốc dự kiến

**MVP vận hành:** T1–T11, trang vào/điều hướng cơ bản của T8, kiểm tra T18 và phát hành T19 cho phạm vi MVP. **Đợt tiếp:** T12–T15; **đợt hoàn thiện:** T16–T17. Nếu việc khóa Coach đã có thể phát sinh trong vận hành thật, T12–T14 trở thành điều kiện bắt buộc trước phát hành; không phát hành thao tác khóa Coach với xử lý hậu quả còn dang dở. Phạm vi phát hành hoàn thiện là T1–T19.

Ước lượng chỉ lập sau T1–T3; repository và hạ tầng chưa được kiểm chứng nên không gán số ngày giả chính xác. Khi đã có baseline, ước lượng từng task theo frontend/backend/migration/test và thêm dự phòng cho migration cùng kiểm thử đồng thời. Mỗi task nên cắt thành phiên làm việc nhỏ, có bản chạy được và kiểm chứng riêng.

## 9. Các ca kiểm thử bắt buộc trước phát hành

1. Hai giao dịch đồng thời tranh suất thứ 8; hold 15 phút hết hạn được trả; gói `QUEUED` và lịch đã bán được tính trong công suất.
2. Khóa Coach khi còn Member: phiên Coach mất ngay, quan hệ `COACH_LOCKED`, gói Coach đóng băng, gói Gym vẫn hết hạn theo lịch; chuyển/chờ/hoàn và mở khóa theo D1–D3.
3. Mọi đường `ENDED`: hủy lịch tương lai, lưu giáo án chỉ đọc, trả suất đúng một lần; chat 1–1 còn dùng nếu tài khoản hợp lệ.
4. Bán Gym tại quầy mất mạng/retry không nhân đôi; mua nối tiếp `SCHEDULED`; gói mua giữ snapshot khi danh mục đổi.
5. Coach/Admin gọi API nhật ký, ảnh, số đo, biểu đồ, AI và ghi chú nhạy cảm đều bị từ chối; không lộ qua dữ liệu dashboard/audit.
6. Quy tắc 12 giờ hủy lịch, trừ buổi đúng một lần, giới hạn 7 ngày không cộng dồn; thời gian hiển thị theo Asia/Ho_Chi_Minh.
7. Danh sách >100 bản ghi, lọc/phân trang/deep link, hết phiên, lỗi 409, offline, form giữ dữ liệu; desktop, tablet, màn hẹp và bàn phím.

## 10. Rủi ro và cách kiểm soát

| Rủi ro | Tác động | Kiểm soát |
| --- | --- | --- |
| Repository không truy cập được ở phiên lập kế hoạch | Chưa xác nhận stack và mức độ code cũ | T1 là gate; không ước lượng/deploy trước khi kiểm toán |
| Mã và API còn luồng `coach_requests` | Dashboard và quyền sai nghiệp vụ | Migration/contract T3, test không còn `PENDING` cũ |
| Tranh chấp công suất và thời hạn | Bán quá suất, sai quyền lợi | Transaction/lock/idempotency, test đồng thời và mốc thời gian |
| Quy tắc D1–D6 chưa chốt | UI/API tự đoán, khó sửa dữ liệu | Chốt từng quyết định bằng state table trước task phụ thuộc |
| Dữ liệu riêng lọt vào Admin | Vi phạm quyền riêng tư | Allowlist response trên server và test gọi API trực tiếp |
| Màn Admin nhiều dữ liệu, khó đọc | Sai thao tác vận hành | Bảng graphite đặc, tên người, filter, phân trang, xác nhận tác động |

## 11. Việc cần làm ngay

1. **Giai đoạn 3 (tiếp theo — Backend + DB + test, UI tạm dừng theo chỉ đạo người dùng):** đã hoàn tất **T12 Backend + Migration `0032` (`e47ad89`)** và **T13 Backend (`7f88e93`)**; tiếp tục từng task T14 (hoàn tiền mô phỏng D3), T15 (Dashboard dữ liệu thật Gross/Refund/Net & việc cần xử lý) trên nhánh `thong`.
2. Hoàn thiện Giai đoạn 4 (T16 Thực phẩm & kcal, T17 Phòng gym, Thiết bị & Thư viện bài tập `exercises`, T18 Audit/bảo mật/khả dụng, T19 Staging & diễn tập migration) và nghiệm thu tại Checkpoint 3 & Checkpoint cuối.

