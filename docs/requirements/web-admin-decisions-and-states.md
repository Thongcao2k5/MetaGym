# T2 — Sổ Quyết định D1–D7, Quy tắc Chốt 21/11/2026 & Ma trận Chuyển Trạng thái

**Ngày chốt:** 21/11/2026  
**Người chốt:** Chủ sản phẩm (Product Owner)  
**Trạng thái:** Đã khóa (Locked) — dùng làm nguồn sự thật duy nhất cho Giai đoạn 1–4  
**Phụ thuộc:** `docs/requirements/web-admin-t1-audit.md` (T1), `docs/requirements/approved-decisions-2026-11-13.md`

---

## 1. Quy ước nền tảng bắt buộc cho mọi quy tắc

### 1.1. Múi giờ & chuẩn tính ngày (`Asia/Ho_Chi_Minh`, UTC+7)
- Mọi mốc thời điểm lưu trong PostgreSQL dạng `timestamptz` (UTC), trả qua JSON theo chuẩn ISO-8601 (`YYYY-MM-DDTHH:mm:ss.sssZ`), hiển thị trên Web Admin và Flutter theo múi giờ **`Asia/Ho_Chi_Minh` (`UTC+7`)**.
- **Ngày làm việc Việt Nam (`vn_date(ts)`):** `(ts AT TIME ZONE 'Asia/Ho_Chi_Minh')::date`.
- **Cửa sổ thời gian chính xác tới giây (server clock `statement_timestamp()`):**
  - Giữ suất thanh toán gói Coach (`coach_payment_holds`): `15 phút` (`created_at + interval '15 minutes'`).
  - Hủy/đổi lịch Member không trừ buổi: trước giờ bắt đầu buổi tối thiểu `12 giờ` (`starts_at >= statement_timestamp() + interval '12 hours'`).
  - Phản hồi yêu cầu kết thúc sớm (D5): `72 giờ` (`response_deadline_at = created_at + interval '72 hours'`).
- **Quy tắc tính số ngày đóng băng gói Coach (`COACH_LOCKED`):**
  $$\text{delta\_days} = \max\bigl(0,\; \text{vn\_date}(\text{resolved\_at}) - \text{vn\_date}(\text{frozen\_started\_at})\bigr)$$
  - Khóa và mở khóa (hoặc chuyển Coach) trong **cùng một ngày lịch Việt Nam** → `delta_days = 0` (ngăn trục lợi cộng thêm ngày khi bấm nhầm khóa/mở).
  - Vượt qua `N` mốc nửa đêm `00:00+07:00` → `delta_days = N`.
  - Mỗi sự cố khóa Coach (`coach_lock_incidents`) chỉ được cộng ngày đóng băng **đúng một lần** (idempotent: khóa bằng cột `frozen_days_applied IS NULL` trên incident và `frozen_at IS NOT NULL` trên `coach_entitlements`).
- **Quy tắc gia hạn 7 ngày bổ sung một lần (`grace_days_added`):**
  - Chỉ áp dụng **một lần duy nhất** (`grace_days_added` từ `0 → 7`, `CHECK (grace_days_added IN (0, 7))`) khi gói Coach `ACTIVE` không bị đóng băng (`frozen_at IS NULL`), còn buổi (`remaining_sessions > 0`) và đã qua `original_ends_on + frozen_days_total`.
  - Ngoại lệ tập bù do Coach hủy lịch dùng **cùng trần 7 ngày**, tuyệt đối không cộng dồn (`<= 7`).
  - Khi chuyển Coach (D2), giá trị `grace_days_added` được giữ nguyên sang Coach mới để không bao giờ được cấp 7 ngày lần thứ hai.

### 1.2. Các quy tắc phạm vi & bất biến đã khóa ngày 21/11/2026

| Mã | Quy tắc đã khóa | Bất biến kiểm thử được (Testable Invariant) |
|---|---|---|
| **S1** | Phạm vi Web Admin & Mobile | Giữ mã QR điểm danh trên màn Phòng gym (`gym_checkin_code`); **thêm** màn Quản lý Thư viện Bài tập (`exercises`) vào Web Admin; **giữ `member_nutrition_tracking` ngoài Web Admin** (`403 FORBIDDEN` với Admin và Coach); **gỡ/chặn `AdminHomePage`** trong Flutter (`ADMIN` đăng nhập mobile bị chặn vào giao diện vận hành và hướng dẫn mở Web Admin); sửa dứt điểm 3 Flutter test fail nền trước khi code tính năng mới. |
| **S2** | Danh mục Gói Gym (`membership_plans`) | Admin được sửa trực tiếp `name`, `description`, `price`, `durationDays`, `status` **kể cả sau khi đã có giao dịch `SUCCESS`** (bỏ `409 PLAN_TERMS_LOCKED`). Mọi thay đổi **chỉ áp dụng cho giao dịch tạo mới**; giao dịch cũ bất biến nhờ `plan_name_snapshot`, `duration_days_snapshot`, `amount` trên `payments`. |
| **S3** | Danh mục Gói Coach (`coach_package_plans`) | Admin được **tạo gói mới** và **sửa** `name`, `description`, `sessionCount`, `durationDays`, `price`, `status`; bỏ ràng buộc 3 mã cố định (`BASIC`/`STANDARD`/`ADVANCED`) và `ck_coach_package_fixed_terms`. Thay đổi **chỉ áp dụng cho hold/giao dịch mới**; mọi gói đã mua/`QUEUED` giữ nguyên snapshot (`plan_code`, `plan_name`, `snapshot_price`, `total_sessions`, `duration_days`). Mỗi buổi giữ chuẩn 90 phút; tối đa 1 gói `QUEUED`/Member. |
| **S4** | Trần cứng 8 Member/Coach | DB ép `coach_profiles.member_limit = 8` (`CHECK (member_limit = 8)`); API không cho Admin cấu hình số khác (`POST /admin/coaches` bỏ `memberLimit` hoặc từ chối `422` nếu khác `8`; `PATCH /admin/users/:id` từ chối trường `memberLimit`). `coach_occupied_seats(coach_id)` = số `member_id` phân biệt thuộc `coach_relationships (ACTIVE, PAUSED)` ∪ `coach_payment_holds (HELD & expires_at > now())` luôn `<= 8`. |
| **S5** | Chat khi tài khoản bị khóa & Mật khẩu tạm Coach | (a) Khi **người nhận** có `users.status = 'DISABLED'`, server chặn `POST /conversations/:id/messages` bằng `403 RECIPIENT_ACCOUNT_DISABLED` và chặn `POST /conversations` mở mới bằng `404`/`403`; **lịch sử hội thoại vẫn đọc được** (`GET /conversations`, `GET /conversations/:id/messages`). (b) Đặt lại mật khẩu tạm Coach (`POST /admin/coaches/:id/password-resets`) thu hồi phiên cũ (`session_version + 1`), trả mật khẩu tạm 1 lần; Coach đăng nhập bình thường (không có cờ ép đổi mật khẩu khóa API), UI hiển thị nhắc đổi mật khẩu qua `PATCH /users/me/password`. |

---

## 2. Sổ Quyết định D1–D7 (Chi tiết kiểm thử được)

### D1 — Mở khóa Coach trước khi Member chuyển Coach hoặc nhận hoàn tiền mô phỏng
- **Bối cảnh:** Admin khóa Coach A (`ACTIVE → DISABLED`, lý do bắt buộc) trong khi Coach A có Member đang thuê. Quan hệ bị ảnh hưởng chuyển sang `PAUSED (pause_reason = 'COACH_LOCKED')`, gói Coach `ACTIVE` bị đóng băng (`frozen_at = locked_at`), các lịch `BOOKED` tương lai bị hủy **không trừ buổi**, các hold `HELD` trên Coach A bị hủy (`CANCELLED`), tạo bản ghi sự cố `coach_lock_incidents (status = 'OPEN')`. Gói Gym **không** đóng băng.
- **Quyết định chốt (21/11/2026):** Khi Admin mở khóa Coach A (`DISABLED → ACTIVE`):
  1. Mọi Member thuộc sự cố khóa Coach A **đã được chuyển sang Coach khác** (`RESOLVED_TRANSFERRED`) hoặc **đã nhận hoàn tiền mô phỏng** (`RESOLVED_REFUNDED`) hoặc quan hệ đã `ENDED` → **KHÔNG bị ảnh hưởng**.
  2. Mọi quan hệ còn đang `PAUSED (pause_reason = 'COACH_LOCKED')` với sự cố `OPEN` của Coach A → **tự động khôi phục trong cùng transaction mở khóa Coach**:
     - Tính `delta_days = GREATEST(0, vn_date(now()) - vn_date(incident.frozen_started_at))`.
     - Nếu `entitlement.frozen_at IS NOT NULL` và `incident.frozen_days_applied IS NULL` (**idempotent, cộng đúng 1 lần**):
       - `frozen_days_total = frozen_days_total + delta_days`
       - `ends_on = original_ends_on + frozen_days_total + grace_days_added`
       - `frozen_at = NULL`
       - `incident.frozen_ended_at = now()`, `incident.frozen_days_applied = delta_days`, `incident.status = 'RESOLVED_COACH_UNLOCKED'`, `incident.resolved_by = admin_id`, `incident.resolved_at = now()`.
     - Đánh giá lại trạng thái quan hệ đầu ra cho từng Member:
       - Nếu `member.status = 'DISABLED'` → quan hệ chuyển `PAUSED (pause_reason = 'MEMBER_LOCKED')` (gói Coach hết đóng băng và chạy bình thường theo D4).
       - Ngược lại, nếu Member còn gói Gym `ACTIVE` phủ ngày hôm nay (`vn_date(now()) BETWEEN start_date AND end_date`) → khôi phục quan hệ về **`ACTIVE`** (`paused_at = NULL`, `pause_reason = NULL`).
       - Ngược lại (gói Gym đã hết hạn trong thời gian Coach bị khóa) → chuyển quan hệ sang **`PAUSED` (`pause_reason = 'MEMBERSHIP_EXPIRED'`, `paused_at = now()`)**; gói Coach hết đóng băng (đã được cộng đủ `delta_days`) và đồng hồ gói Coach chạy lại bình thường.
     - Ghi `admin_audit_logs` (`USER_ENABLED`, metadata chứa `restoredCount`, `restoredRelationships[]` chỉ gồm ID vận hành & `frozenDaysAdded` — không chứa dữ liệu nhạy cảm) và tạo `coach_notifications` (`COACH_UNLOCKED_RESTORED`) gửi từng Member được khôi phục và gửi Coach A.
- **Tương tác biên (Khóa Coach khi quan hệ đang `PAUSED` sẵn):**
  - Nếu quan hệ đang `PAUSED (MEMBERSHIP_EXPIRED)` lúc Coach bị khóa: vẫn mở `coach_lock_incidents` và đổi `pause_reason = 'COACH_LOCKED'`, nhưng **chỉ bắt đầu đóng băng** (`frozen_at`) nếu Gym đang `ACTIVE` (nếu Gym đã hết hạn trước khi Coach bị khóa, `frozen_at` giữ `NULL` cho tới khi Member gia hạn Gym thành công trong lúc Coach vẫn đang bị khóa — lúc gia hạn Gym mới đặt `frozen_at = now()`). Điều này đảm bảo quy tắc *"Tạm ngưng vì Gym hết hạn vẫn làm thời hạn gói Coach chạy như bình thường"*.
  - Nếu quan hệ đang `PAUSED (MEMBER_LOCKED)` lúc Coach bị khóa: giữ nguyên `pause_reason = 'MEMBER_LOCKED'` (không đóng băng vì lỗi thuộc Member); nếu Member được mở khóa trong khi Coach vẫn `DISABLED` thì mới chuyển sang `PAUSED (COACH_LOCKED)` và bắt đầu đóng băng từ lúc mở khóa Member.
- **Ví dụ đầu vào / kết quả:**
  - *Input:* Member M1 có gói Gym `2026-11-01..2026-11-30`, gói Coach 10 buổi (`starts_on = 2026-11-01`, `original_ends_on = 2026-11-30`, `ends_on = 2026-11-30`, còn 6 buổi). Member M2 có gói Gym `2026-10-25..2026-11-23`, gói Coach còn 8 buổi (`ends_on = 2026-12-10`). Ngày `2026-11-21 10:00+07`, Admin khóa Coach A. Ngày `2026-11-25 14:00+07`, Admin mở khóa Coach A (chưa chuyển/hoàn M1, M2).
  - *Output:* `delta_days = 2026-11-25 - 2026-11-21 = 4` ngày.
    - M1 (Gym còn hạn đến `11-30`): quan hệ về **`ACTIVE`**, `ends_on = 2026-12-04`, `frozen_days_total = 4`, `frozen_at = NULL`, còn 6 buổi.
    - M2 (Gym đã hết hạn ngày `11-23`): quan hệ về **`PAUSED (MEMBERSHIP_EXPIRED)`**, `ends_on = 2026-12-14`, `frozen_days_total = 4`, `frozen_at = NULL`, còn 8 buổi; đồng hồ Coach tiếp tục chạy cho tới khi M2 gia hạn Gym.
    - Gọi lại mở khóa lần 2 (retry): no-op, `ends_on` không đổi (không cộng 4 ngày lần thứ 2).

---

### D2 — Xử lý gói Coach `QUEUED` khi chuyển Coach hoặc hoàn tiền mô phỏng
- **Quyết định chốt (21/11/2026):**
  1. **Khi chuyển Coach (Member chuyển từ Coach A → Coach B):**
     - Chuyển **CẢ HAI**: phần còn lại của gói `ACTIVE` **VÀ** gói `QUEUED` (nếu có) sang quan hệ mới với Coach B.
     - Bảo toàn nguyên vẹn snapshot gốc (`plan_code`, `plan_name`, `snapshot_price`, `total_sessions`, `remaining_sessions`, `duration_days`, `starts_on`, `original_ends_on`, `grace_days_added`, `frozen_days_total`, `original_hold_id`, `source_entitlement_id`).
     - Nếu chuyển từ sự cố `COACH_LOCKED`: cộng `delta_days` đóng băng **đúng 1 lần** vào `ends_on` của gói `ACTIVE` chuyển sang (không cộng vào `QUEUED` vì `QUEUED` chưa bắt đầu chạy thời hạn).
     - Kiểm tra điều kiện Coach B trong cùng transaction:
       - Coach B `ACTIVE`, `newCoachId !== oldCoachId`, đã cấu hình lịch tuần hợp lệ (`>= 6` ngày/tuần, `>= 4` khung 90 phút liên tiếp/ngày).
       - `coach_occupied_seats(Coach B) < 8` (tính cả `ACTIVE`, `PAUSED`, và `HELD` chưa hết hạn).
       - `hasCoachCapacity(client, Coach B, proposals)` phải **đạt cho CẢ HAI gói đồng thời** (đồng thời sửa lỗi `from > through` ở `coach-capacity.js:63-65` và mở rộng `generate_series(0, GREATEST(190, max_through - today))`):
         - Proposal 1 (`ACTIVE`): `from = GREATEST(today, starts_on)`, `through = new_ends_on`, `remaining = active.remaining_sessions` (luôn bảo đảm `from <= through`).
         - Proposal 2 (`QUEUED`, nếu tồn tại): luôn bảo đảm cửa sổ không rỗng `from <= through` (`through - from + 1 = queued.duration_days`), kiểm tra ở **cả hai kịch bản biên** kích hoạt nối tiếp:
           - *Kịch bản kích hoạt theo hạn gói cũ (late/expiry):* `from_late = active.original_ends_on + new_frozen_days_total + 8` (tính cả trần 7 ngày bổ sung), `through_late = from_late + queued.duration_days - 1`, `remaining = queued.total_sessions`.
           - *Kịch bản kích hoạt sớm nếu học hết buổi nhanh (early, tối đa 1 buổi/ngày):* `from_early = today + active.remaining_sessions`, `through_early = from_early + queued.duration_days - 1`, `remaining = queued.total_sessions`.
           - *(Kiểm chứng với ví dụ bên dưới: `today = 2026-11-24`, `original_ends_on = 2026-12-20`, `frozen = 3`, `remaining = 12`, `queued = 30 ngày` → `late = [2026-12-31, 2027-01-29]` (30 ngày) và `early = [2026-12-06, 2027-01-04]` (30 ngày) — cả hai đều hợp lệ và không bao giờ rỗng.)*
       - Nếu không đủ công suất cho cả hai → trả `409 CAPACITY_UNAVAILABLE`, **rollback toàn bộ** (không chuyển tách rời 1 gói).
     - Trên Coach A: đóng quan hệ cũ (`ENDED`), đóng entitlement cũ với `close_reason = 'TRANSFERRED'`, hủy toàn bộ `coach_bookings` tương lai không trừ buổi, lưu trữ `training_plans`/`nutrition_guides` sang `ARCHIVED` (chỉ đọc; Coach B không kế thừa), hủy `HELD` hold mở trên Coach A, giải phóng 1 suất của Coach A.
     - Trạng thái quan hệ mới trên Coach B:
       - `ACTIVE` nếu Member đang có Gym `ACTIVE` phủ hôm nay;
       - `PAUSED (MEMBERSHIP_EXPIRED)` nếu Gym hết hạn trong lúc chờ chuyển.
     - Chat 1–1 không bị khóa với Coach A (trừ khi Coach A `DISABLED` thì áp quy tắc S5 chặn gửi mới, lịch sử vẫn đọc được) và không bắt buộc tạo phòng chat mới với Coach B.
  2. **Khi hoàn tiền mô phỏng (`COACH_LOCKED` → Member chọn hoàn / Admin thực thi hoàn):**
     - Hoàn gói `ACTIVE` theo công thức **D3**.
     - Hoàn **100% giá snapshot (`snapshot_price`)** của gói `QUEUED` (vì gói chờ chưa kích hoạt, chưa dùng buổi nào).
     - Tạo bản ghi `simulated_refunds` riêng cho từng `coach_entitlement_id` (1 dòng cho `ACTIVE`, 1 dòng cho `QUEUED`, chung `refund_batch_id` và `incident_id`).
     - Đóng cả hai gói (`status = 'ENDED'`, `close_reason = 'SIMULATED_REFUND'`) và đóng quan hệ Coach (`ENDED`), lưu trữ giáo án chỉ đọc, hủy lịch tương lai không trừ buổi, giải phóng suất Coach A **đúng 1 lần**, đóng incident `RESOLVED_REFUNDED`.
- **Ví dụ đầu vào / kết quả:**
  - *Input (Transfer):* M1 đang `PAUSED (COACH_LOCKED)` từ `2026-11-21` đến `2026-11-24` (`delta_days = 3`). Gói `ACTIVE`: Tiêu chuẩn `20 buổi / 60 ngày`, `snapshot_price = 4.000.000 ₫`, còn `12 buổi`, `ends_on = 2026-12-20`. Gói `QUEUED`: Cơ bản `10 buổi / 30 ngày`, `snapshot_price = 2.200.000 ₫` (dù giá danh mục hiện đã tăng lên `2.500.000 ₫`). Admin chuyển sang Coach B (đang có 7/8 suất và đủ công suất lịch cho cả 12 + 10 buổi).
  - *Output:* Coach A về `0` suất từ M1; Coach B lên `8/8` suất; M1 có quan hệ mới `ACTIVE` với Coach B; gói `ACTIVE` mới còn `12/20 buổi`, `snapshot_price = 4.000.000 ₫`, `ends_on = 2026-12-23` (`+3 ngày`), `frozen_days_total = 3`; gói `QUEUED` mới còn `10/10 buổi`, `snapshot_price = 2.200.000 ₫`, `starts_on = NULL`.
  - *Input (Simulated Refund):* Cùng M1 ở trên nhưng không có Coach B thay thế; M1 chọn hoàn tiền mô phỏng.
  - *Output:*
    - Dòng 1 (`ACTIVE`): `floor((4.000.000 * 12 / 20) / 1000) * 1000 = 2.400.000 ₫`.
    - Dòng 2 (`QUEUED`): `100% * 2.200.000 = 2.200.000 ₫`.
    - Tổng hoàn mô phỏng: **`4.600.000 ₫`**. Cả 2 gói và quan hệ đều `ENDED`.

---

### D3 — Công thức Hoàn tiền Mô phỏng, Chống hoàn hai lần & Báo cáo Doanh thu Dashboard
- **Quyết định chốt (21/11/2026):**
  1. **Công thức bắt buộc (tính bằng số nguyên `BigInt`, làm tròn xuống bội số 1.000 VND):**
     - Với gói `ACTIVE`:
       $$\text{refund\_active} = \left\lfloor \frac{\text{snapshot\_price} \times \text{remaining\_sessions}}{\text{total\_sessions} \times 1000} \right\rfloor \times 1000$$
       (tương đương JS: `Math.floor((snapshotPrice * remainingSessions / totalSessions) / 1000) * 1000`, triển khai bằng `BigInt` để loại bỏ sai số dấu phẩy động: `Number(((BigInt(snapshotPrice) * BigInt(remainingSessions)) / BigInt(totalSessions) / 1000n) * 1000n)`).
     - Với gói `QUEUED`: `refund_queued = snapshot_price` (100% giá snapshot).
     - Không bao giờ gọi cổng thanh toán thật; mọi hoàn tiền đều là **hoàn tiền mô phỏng** ghi nhận trong DB.
  2. **Lưu trữ & chống hoàn hai lần:**
     - Lưu ở bảng riêng **`simulated_refunds`** (không sửa bản gốc `coach_payment_holds`).
     - Ràng buộc cứng DB: **`UNIQUE (coach_entitlement_id)`** (1 entitlement không thể hoàn quá 1 lần) + **`UNIQUE (created_by, idempotency_key, entitlement_kind)`** + `request_hash` (`Idempotency-Key` UUID bắt buộc).
     - Bắt buộc `reason` (`1..500` ký tự) + `admin_audit_logs` (`SIMULATED_REFUND_CREATED`) + `coach_notifications` (`SIMULATED_REFUND_COMPLETED`).
  3. **Báo cáo Doanh thu trên Dashboard (`GET /api/v1/admin/dashboard?from&to`):**
     - `gymGrossPayments`: tổng `payments.amount` (`status = 'SUCCESS'`, `vn_date(confirmed_at) ∈ [from, to]`).
     - `totalVoidReversals`: tổng `payment_adjustments.reversed_amount` (`adjustment_type = 'VOID_REVERSAL'`, `vn_date(created_at) ∈ [from, to]`).
     - `coachGrossPayments`: tổng `coach_payment_holds.amount` (`status = 'CONSUMED'`, `vn_date(COALESCE(settled_at, created_at)) ∈ [from, to]`).
     - **`grossRevenue` (Doanh thu gộp hiệu lực):** `gymGrossPayments - totalVoidReversals + coachGrossPayments`.
     - **`totalSimulatedRefunds` (Tổng hoàn tiền mô phỏng):** tổng `simulated_refunds.refund_amount` (`status = 'COMPLETED'`, `vn_date(created_at) ∈ [from, to]`).
     - **`netRevenue` (Doanh thu ròng):** `grossRevenue - totalSimulatedRefunds`.
- **Ví dụ kiểm thử làm tròn & biên:**
  - *Case A (chia lẻ):* `snapshotPrice = 5.000.000`, `totalSessions = 30`, `remainingSessions = 11` → `5.000.000 * 11 / 30 = 1.833.333,33...` → làm tròn xuống 1.000 VND = **`1.833.000 ₫`**.
  - *Case B (chia rất sát ngưỡng trên):* `snapshotPrice = 2.999.000`, `totalSessions = 10`, `remainingSessions = 3` → `899.700` → làm tròn xuống 1.000 VND = **`899.000 ₫`** (không làm tròn lên 900.000).
  - *Case C (nhỏ hơn 1.000 VND):* `snapshotPrice = 5.000`, `totalSessions = 10`, `remainingSessions = 1` → `500` → **`0 ₫`** (vẫn tạo bản ghi `refund_amount = 0` và đóng gói/quan hệ bình thường).
  - *Case D (retry cùng `Idempotency-Key`):* trả lại đúng kết quả batch hoàn trước đó (`200 OK`), không tạo thêm bản ghi; đổi `Idempotency-Key` trên cùng incident đã hoàn → trả `409 INCIDENT_ALREADY_RESOLVED` / `409 ALREADY_REFUNDED`.

---

### D4 — Khóa và Mở khóa Member đang có Coach
- **Quyết định chốt (21/11/2026):**
  1. **Khi Admin khóa Member (`ACTIVE → DISABLED`, lý do bắt buộc 1–500 ký tự):**
     - Thu hồi ngay mọi phiên Member (`session_version = session_version + 1`).
     - Hủy mọi suất giữ thanh toán gói Coach đang mở (`coach_payment_holds`: `HELD → CANCELLED`).
     - Nếu Member có quan hệ Coach đang `ACTIVE` (hoặc `PAUSED (MEMBERSHIP_EXPIRED)`):
       - Chuyển quan hệ sang **`PAUSED` với `pause_reason = 'MEMBER_LOCKED'`**, `paused_at = now()`.
       - **Ẩn hồ sơ sức khỏe nhạy cảm khỏi Coach**: mọi trường `fitnessGoal`, `heightCm`, `weightKg`, `bodyFatPercent`, `healthNotes`, `injuryNotes`, `healthDeclarationCompletedAt` trong `GET /coach/members/:memberId` trả `null`; Coach không thể sửa giáo án/thực đơn/gọi điện/gửi outcome vì yêu cầu `r.status = 'ACTIVE'`.
       - **Hủy toàn bộ lịch `BOOKED` tương lai** (`starts_at > statement_timestamp()`) **không trừ buổi** (`charged_at IS NULL`, `reason = 'Tài khoản Member bị khóa'`).
       - **Giữ nguyên suất của Coach** (`coach_occupied_seats` vẫn đếm `PAUSED`).
       - **KHÔNG đóng băng thời hạn**: cả gói Gym (`member_memberships`) lẫn gói Coach (`coach_entitlements`, `frozen_at` giữ `NULL`) **vẫn tiếp tục chạy thời hạn bình thường** (nếu hết hạn trong lúc Member bị khóa, reconciliation tự chuyển hết hạn / kích hoạt `QUEUED` / đóng quan hệ và trả suất bình thường).
       - Gửi thông báo (`MEMBER_LOCKED`) cho Coach đang phụ trách; ghi `admin_audit_logs` (`USER_DISABLED`).
     - *(Biên tương tác D1+D4)*: Nếu Member đang ở `PAUSED (COACH_LOCKED)` (lỗi Coach trước đó), chuyển `pause_reason = 'MEMBER_LOCKED'`, **tạm dừng đóng băng** kể từ lúc Member bị khóa (chốt phần đóng băng trước đó hoặc không tích lũy ngày đóng băng trong khoảng Member bị khóa).
  2. **Khi Admin mở khóa Member (`DISABLED → ACTIVE`):**
     - Chạy đối soát vòng đời gói Gym & gói Coach của Member ngay trong transaction mở khóa.
     - Nếu quan hệ vẫn còn ở `PAUSED (MEMBER_LOCKED)`:
       - Nếu gói Coach `ACTIVE` không còn (đã hết hạn trong lúc Member bị khóa) → chuyển quan hệ sang **`ENDED`** (lưu trữ giáo án, trả suất Coach).
       - Else nếu Coach hiện đang `DISABLED` → chuyển sang **`PAUSED (COACH_LOCKED)`**, mở incident `OPEN` và bắt đầu đóng băng từ thời điểm mở khóa Member.
       - Else nếu Member còn gói Gym `ACTIVE` phủ ngày hôm nay **VÀ** gói Coach `ACTIVE` còn hiệu lực → khôi phục về **`ACTIVE`** (`paused_at = NULL`, `pause_reason = NULL`); Coach xem lại được hồ sơ sức khỏe và hai bên đặt lịch/gọi lại bình thường.
       - Else (gói Coach còn hạn nhưng gói Gym đã hết hạn trong lúc Member bị khóa) → chuyển sang **`PAUSED (MEMBERSHIP_EXPIRED)`** (`paused_at = now()`).
     - Ghi `admin_audit_logs` (`USER_ENABLED`) và thông báo (`MEMBER_UNLOCKED_RESTORED`) cho Member và Coach.
- **Ví dụ đầu vào / kết quả:**
  - *Input:* Member M3 có Gym `11-01..11-25`, gói Coach `11-01..11-30` (còn 7 buổi), đã đặt lịch ngày `11-22` và `11-24`. Ngày `11-21`, Admin khóa M3 (`"Vi phạm nội quy"`).
  - *Output (lúc khóa):* M3 bị đăng xuất ngay; quan hệ → `PAUSED (MEMBER_LOCKED)`; lịch `11-22` và `11-24` → `CANCELLED` (`charged_at = NULL`, còn nguyên 7 buổi); Coach vẫn thấy `usedSlots` giữ suất M3 nhưng `GET /coach/members/M3` trả `null` toàn bộ mục sức khỏe; gửi chat cho M3 bị `403 RECIPIENT_ACCOUNT_DISABLED` (S5).
  - *Output (mở khóa ngày `11-23`):* Gym còn hạn (`<= 11-25`), gói Coach còn hạn (`<= 11-30`) → quan hệ khôi phục **`ACTIVE`**, `ends_on` vẫn là `11-30` (không cộng ngày nào).
  - *Output (nếu mở khóa ngày `11-27`):* Gym đã hết hạn (`11-25`), gói Coach còn hạn (`11-30`) → quan hệ sang **`PAUSED (MEMBERSHIP_EXPIRED)`**.
  - *Output (nếu mở khóa ngày `12-10`):* Gói Coach đã quá hạn + 7 ngày (`12-07`) → quan hệ đã chuyển **`ENDED`**, giải phóng suất Coach.

---

### D5 — Kết thúc sớm quan hệ hai bên & Cơ chế Tranh chấp 72 giờ
- **Quyết định chốt (21/11/2026):**
  - Thay thế hoàn toàn luồng Member tự kết thúc đơn phương (`POST /relationships/:id/terminations` → `410 LEGACY_WORKFLOW_RETIRED`) và luồng Coach gửi thẳng Admin bỏ qua Member.
  - **Phạm vi áp dụng:** Quan hệ ở trạng thái `ACTIVE` hoặc `PAUSED (MEMBERSHIP_EXPIRED)` (không áp dụng cho `PAUSED (COACH_LOCKED)` — đi qua luồng Sự cố Coach chờ/chuyển/hoàn D1–D3; và không cho Member gửi khi đang `MEMBER_LOCKED`).
  - **Bước 1 — Gửi yêu cầu:** **Bất kỳ bên nào** (`MEMBER` hoặc `COACH`) gửi yêu cầu kèm lý do bắt buộc (`1..1000` ký tự). Mỗi quan hệ chỉ có tối đa **1 yêu cầu đang mở** (`status IN ('PENDING_COUNTERPARTY', 'DISPUTED')`).
    - Trạng thái khởi tạo: **`PENDING_COUNTERPARTY`**, `response_deadline_at = created_at + interval '72 hours'`.
    - Thông báo `TERMINATION_REQUESTED` gửi đối tác. Người gửi có thể tự rút yêu cầu (`WITHDRAW → CANCELLED`) khi vẫn còn `PENDING_COUNTERPARTY`.
  - **Bước 2 — Phản hồi trong 72 giờ của bên còn lại:**
    - **Đồng ý (`ACCEPT`):**
      - Yêu cầu → **`ACCEPTED`**.
      - Quan hệ → **`ENDED` ngay lập tức**.
      - Toàn bộ buổi chưa dùng của gói `ACTIVE` và gói `QUEUED` (nếu có) **mất hiệu lực** (`status = 'ENDED'`, `close_reason = 'EARLY_TERMINATION'`, **không hoàn tiền, không chuyển**).
      - Hủy mọi `coach_bookings` tương lai (`BOOKED → CANCELLED`, không trừ lượt nữa vì gói đã đóng), hủy `HELD` hold mở, chuyển `training_plans` và `nutrition_guides` sang `ARCHIVED` (chỉ đọc), giải phóng suất Coach **đúng 1 lần**, giữ chat 1–1 hoạt động bình thường.
      - Gửi thông báo `TERMINATION_ACCEPTED` cho cả 2 bên.
    - **Từ chối (`REJECT`, lý do bắt buộc `1..1000` ký tự):**
      - Yêu cầu → **`DISPUTED` ngay lập tức** (`escalation_reason = 'COUNTERPARTY_REJECTED'`, `disputed_at = now()`).
      - Quan hệ giữ nguyên trạng thái hiện tại, đẩy lên hàng chờ tranh chấp Web Admin, thông báo `TERMINATION_DISPUTED` cho 2 bên.
    - **Quá 72 giờ không phản hồi (`now() >= response_deadline_at`):**
      - Hệ thống **tự động leo thang** `PENDING_COUNTERPARTY → DISPUTED` (`escalation_reason = 'TIMEOUT_72H'`, `disputed_at = response_deadline_at`) — thực thi cả trong `reconcileMembershipLifecycles()` lẫn kiểm tra nội tuyến tại mọi endpoint đọc/phản hồi/phán quyết để chính xác tới từng giây mà không phụ thuộc cron ngoài.
  - **Bước 3 — Admin phán quyết (`DISPUTED`):**
    - Admin **chỉ được phán quyết khi trạng thái là `DISPUTED`** (không vượt rào 72h khi đang `PENDING_COUNTERPARTY` → `409 NOT_DISPUTED`). Bắt buộc lý do phán quyết (`1..1000` ký tự) + `admin_audit_logs` (`TERMINATION_DISPUTE_DECIDED`).
    - **`APPROVED` (`ADMIN_APPROVED`):** Thực thi cùng tập hiệu ứng kết thúc ở Bước 2 (đóng quan hệ, hủy gói không hoàn tiền, hủy lịch tương lai, lưu giáo án chỉ đọc, giải phóng suất 1 lần, giữ chat), thông báo `TERMINATION_ADMIN_APPROVED`.
    - **`REJECTED` (`ADMIN_REJECTED`):** Giữ nguyên quan hệ hiện hành, đóng yêu cầu tranh chấp, thông báo `TERMINATION_ADMIN_REJECTED`.
- **Ví dụ đầu vào / kết quả:**
  - *Input:* Ngày `2026-11-21 09:00:00+07`, Member M4 gửi yêu cầu kết thúc sớm với Coach C1 (`"Không phù hợp lịch tập"`). `response_deadline_at = 2026-11-24 09:00:00+07`.
  - *Nhánh A (C1 bấm `ACCEPT` lúc `2026-11-22 10:00+07`):* Quan hệ → `ENDED`, 9 buổi còn lại của M4 mất hiệu lực (0 ₫ hoàn), 2 lịch tương lai bị hủy, giáo án sang `ARCHIVED`, suất Coach C1 giảm 1.
  - *Nhánh B (C1 không phản hồi tới `2026-11-24 09:00:01+07`):* Yêu cầu tự chuyển `DISPUTED (TIMEOUT_72H)` xuất hiện trên Dashboard & trang Quan hệ/Tranh chấp của Web Admin; nếu C1 cố bấm `ACCEPT` lúc `09:00:05+07` → trả `409 TERMINATION_DEADLINE_EXPIRED`. Admin vào duyệt `ADMIN_APPROVED` kèm lý do `"Coach không phản hồi quá 72 giờ"` → quan hệ kết thúc và ghi audit.

---

### D6 — Điều chỉnh giao dịch gói Gym tại quầy đã `SUCCESS` (`VOID/REVERSAL`)
- **Quyết định chốt (21/11/2026):**
  - **Tuyệt đối không sửa âm thầm bản ghi gốc `payments`** (`amount`, `plan_id`, `plan_name_snapshot`, `duration_days_snapshot`, `status = 'SUCCESS'`, `confirmed_at` là bất biến).
  - Cho phép Admin thực hiện **`VOID_REVERSAL`** bằng **bản ghi điều chỉnh riêng** trong bảng `payment_adjustments` (`UNIQUE (payment_id)`, `UNIQUE (created_by, idempotency_key)` + `Idempotency-Key` + lý do bắt buộc `1..500` ký tự + `admin_audit_logs` `PAYMENT_VOID_REVERSED`).
  - **Điều kiện cho phép (tất cả điều kiện tiên quyết + ít nhất 1 nhánh hợp lệ):**
    - *Tiên quyết:* `payment.method = 'FRONT_DESK'`, `payment.status = 'SUCCESS'`, chưa từng bị đảo (`NOT EXISTS payment_adjustments`), và không có giao dịch gia hạn gộp (`renewed_membership_id`) mới hơn trên cùng chuỗi membership chưa được đảo trước (đảo theo thứ tự LIFO).
    - *Chặn an toàn phụ thuộc Coach:* Nếu sau `payment.confirmed_at` đã phát sinh `coach_payment_holds (HELD/CONSUMED)` hoặc `coach_entitlements` phụ thuộc gói Gym này (tức nếu hủy gói này thì Member không còn gói Gym `ACTIVE` nào khác bọc ngày đó) → chặn **`409 PAYMENT_HAS_COACH_DEPENDENCY`**.
    - *Nhánh hợp lệ (chỉ cần thỏa 1 trong 2):*
      1. **Cùng ngày làm việc Việt Nam:** `vn_date(payment.confirmed_at) = vn_date(statement_timestamp())` (xử lý sai sót gõ nhầm tại quầy ngay trong ngày).
      2. **Gói chưa phát sinh sử dụng (bất kể ngày tạo):** Không có lượt điểm danh `gym_visits` nào phát sinh từ `payment.confirmed_at` trong khoảng hiệu lực của phần gói do giao dịch này tạo ra (bao gồm mọi gói `SCHEDULED` tương lai và gói `ACTIVE` chưa ai check-in) VÀ không có thuê Coach gắn với gói.
    - *Ngoài hai nhánh trên* (đã qua ngày làm việc Việt Nam **VÀ** đã có check-in sử dụng): từ chối **`409 PAYMENT_ADJUSTMENT_WINDOW_EXPIRED`**.
  - **Hiệu ứng lên `member_memberships` (tuân thủ `ck_membership_state_details` tại `0001_foundation.up.sql:165-171`):**
    - Nếu giao dịch tạo bản ghi riêng (`payment.renewed_membership_id IS NULL`): cập nhật `member_memberships SET status = 'CANCELLED', expired_at = NULL` (bắt buộc `expired_at IS NULL` theo `0001:171`; giữ nguyên `payments.status = 'SUCCESS'`, liên kết qua `payment_adjustments`).
    - Nếu giao dịch là gia hạn gộp (`payment.renewed_membership_id IS NOT NULL`, từ migration `0024_membership_renewals`): kiểm tra đoạn ngày được nối thêm `[end_date - duration_days_snapshot + 1, end_date]` chưa bị sử dụng (hoặc cùng ngày tạo), thu hẹp `member_memberships.end_date = end_date - duration_days_snapshot`; nếu `restored_end_date < today` thì bắt buộc chuyển `status = 'EXPIRED', activated_at = COALESCE(activated_at, start_date::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh'), expired_at = statement_timestamp()` (tuân thủ `0001:169`), và lưu `previous_end_date`, `restored_end_date` vào `payment_adjustments`.
    - Sau khi `VOID_REVERSAL` thành công, Admin tạo giao dịch tại quầy mới thay thế sạch bằng `POST /api/v1/admin/front-desk-payments` với `Idempotency-Key` mới.
- **Ví dụ đầu vào / kết quả:**
  - *Case 1 (Nhầm gói trong cùng ngày VN):* Lúc `2026-11-21 08:30+07`, Admin bán nhầm gói 90 ngày `1.500.000 ₫` cho Member M5 thay vì 30 ngày `600.000 ₫`. Lúc `2026-11-21 08:45+07`, Admin gọi `VOID_REVERSAL` với lý do `"Nhập nhầm gói 90 ngày thay vì 30 ngày"`.
    - *Kết quả:* `payments` gốc giữ nguyên `SUCCESS` `1.500.000 ₫`; tạo 1 dòng `payment_adjustments` (`VOID_REVERSAL`, `reversed_amount = 1.500.000`); `member_memberships` tương ứng chuyển `CANCELLED`; `totalVoidReversals` ngày `11-21` ghi `+1.500.000 ₫` (doanh thu gộp hiệu lực về `0 ₫`). Admin lập giao dịch mới 30 ngày `600.000 ₫` → doanh thu gộp hiệu lực = `600.000 ₫`.
  - *Case 2 (Gói `SCHEDULED` mua cách đây 3 ngày, chưa tới ngày bắt đầu):* Chưa phát sinh check-in/Coach → vẫn cho phép `VOID_REVERSAL`.
  - *Case 3 (Gói `ACTIVE` mua ngày `2026-11-18`, M5 đã check-in ngày `2026-11-19`, hôm nay `2026-11-21`):* Khác ngày VN **VÀ** đã có usage → từ chối `409 PAYMENT_ADJUSTMENT_WINDOW_EXPIRED`.
  - *Case 4 (Giao dịch VNPay/MoMo/ZaloPay):* `method <> 'FRONT_DESK'` → từ chối `409 ONLY_FRONT_DESK_ADJUSTABLE`.

---

### D7 — Kiến trúc Triển khai & Stack Web Admin
- **Quyết định chốt (21/11/2026):**
  - **Hạ tầng Cloud:** Giữ nguyên **Supabase** (PostgreSQL 17 Session pooler + `?uselibpqcompat=true&sslmode=require` + Storage Private `meta-gym-media`) + **Render Free** (`backend`, Node `>= 22`, `npm ci` / `npm start`, health `/api/v1/health`) + **Cloudflare Pages** (`admin-web`, `npm run build` → `dist`, `VITE_API_BASE_URL`).
  - **Stack Web Admin:** Giữ nguyên **Vite 8 (`^8.3.0`) + Vanilla ESM JS phân tách module** (`src/api/`, `src/state/`, `src/components/`, `src/pages/`) + **Bootstrap 5.3.8** (+ adapter token `design-system/meta-gym/adapters/bootstrap-theme.css`) + **Chart.js 4.5.1** + **QRCode 1.5.4**. Không viết lại bằng React/Vue/Next.
  - **Quy trình phát hành bắt buộc:** Mọi migration `0024..0028` và `0029..0033` phải được diễn tập áp dụng, kiểm tra `schema_assertions.sql`, diễn tập rollback `*.down.sql`, chạy `REVOKE ALL ON ALL TABLES/SEQUENCES/FUNCTIONS IN SCHEMA public FROM anon, authenticated;` và chạy smoke test đầu-cuối trên DB biệt lập / staging **trước khi merge `main` và nâng cấp production**.

---

## 3. Ma trận Chuyển Trạng thái Chi tiết (State Transition Tables)

### 3.1. `coach_relationships`

| Trạng thái nguồn | Sự kiện / Hành động | Actor | Điều kiện (Guard) | Trạng thái đích | Hiệu ứng phụ bắt buộc | Audit / Thông báo |
|---|---|---|---|---|---|---|
| *(chưa có)* | Xác nhận thanh toán gói Coach đầu tiên (`settleCoachHold`) | System / Member | Gym `ACTIVE`, khai báo thể trạng xong, Coach `ACTIVE`, `occupied_seats <= 8`, `hasCoachCapacity = true` | `ACTIVE` | Tạo `coach_entitlements (ACTIVE)`, `hold → CONSUMED` | Notif `PACKAGE_ACTIVE` |
| `ACTIVE` | Hết hạn gói Gym (`reconcileMembershipLifecycles`) | System | Không còn `member_memberships ACTIVE` phủ hôm nay | `PAUSED` (`MEMBERSHIP_EXPIRED`) | Hủy `coach_bookings` tương lai không trừ buổi; **giữ suất**; đồng hồ gói Coach **tiếp tục chạy**; ẩn hồ sơ sức khỏe với Coach | — |
| `PAUSED` (`MEMBERSHIP_EXPIRED`) | Member gia hạn / mua gói Gym `ACTIVE` | Member / Admin | Gói Gym `ACTIVE` phủ hôm nay; Member & Coach `ACTIVE`; còn `entitlement ACTIVE` | `ACTIVE` | Khôi phục đặt lịch, gọi, xem hồ sơ sức khỏe | — |
| `ACTIVE` | Admin khóa Coach (`DISABLED`) | Admin | Lý do bắt buộc 1–500 ký tự | `PAUSED` (`COACH_LOCKED`) | Hủy phiên Coach; hủy `coach_bookings` tương lai không trừ buổi; **đóng băng `entitlement ACTIVE`** (`frozen_at = now()`); hủy `HELD` hold trên Coach; mở `coach_lock_incidents (OPEN)`; **Gym không đóng băng** | Audit `USER_DISABLED`; Notif `COACH_LOCKED` (Member) |
| `PAUSED` (`MEMBERSHIP_EXPIRED`) | Admin khóa Coach (`DISABLED`) | Admin | Lý do bắt buộc 1–500 ký tự | `PAUSED` (`COACH_LOCKED`) | Mở `coach_lock_incidents (OPEN)`; `frozen_at` giữ `NULL` cho tới khi Gym được gia hạn (nếu có); hủy `HELD` hold | Audit `USER_DISABLED`; Notif `COACH_LOCKED` |
| `PAUSED` (`COACH_LOCKED`) | Admin mở khóa Coach (**D1**) | Admin | Incident còn `OPEN` (chưa chuyển/hoàn); Gym `ACTIVE` hôm nay; Member `ACTIVE` | `ACTIVE` | Cộng `delta_days` **1 lần** vào `ends_on`, `frozen_at = NULL`, đóng incident `RESOLVED_COACH_UNLOCKED` | Audit `USER_ENABLED`; Notif `COACH_UNLOCKED_RESTORED` |
| `PAUSED` (`COACH_LOCKED`) | Admin mở khóa Coach (**D1**) | Admin | Incident còn `OPEN`; Gym hết hạn lúc Coach khóa; Member `ACTIVE` | `PAUSED` (`MEMBERSHIP_EXPIRED`) | Cộng `delta_days` **1 lần** vào `ends_on`, `frozen_at = NULL`, đóng incident `RESOLVED_COACH_UNLOCKED`; đồng hồ Coach chạy lại | Audit `USER_ENABLED`; Notif `COACH_UNLOCKED_RESTORED` |
| `ACTIVE` hoặc `PAUSED (MEMBERSHIP_EXPIRED)` | Admin khóa Member (**D4**) | Admin | Lý do bắt buộc 1–500 ký tự | `PAUSED` (`MEMBER_LOCKED`) | Hủy phiên Member; hủy `coach_bookings` tương lai không trừ buổi; ẩn hồ sơ sức khỏe với Coach; **giữ suất Coach**; **không đóng băng Gym/Coach**; hủy `HELD` hold của Member | Audit `USER_DISABLED`; Notif `MEMBER_LOCKED` (Coach) |
| `PAUSED` (`MEMBER_LOCKED`) | Admin mở khóa Member (**D4**) | Admin | Đối soát xong: Coach `ACTIVE`, gói Coach còn hạn, Gym `ACTIVE` hôm nay | `ACTIVE` | Khôi phục quyền bình thường | Audit `USER_ENABLED`; Notif `MEMBER_UNLOCKED_RESTORED` |
| `PAUSED` (`MEMBER_LOCKED`) | Admin mở khóa Member (**D4**) | Admin | Coach `ACTIVE`, gói Coach còn hạn, Gym đã hết hạn | `PAUSED` (`MEMBERSHIP_EXPIRED`) | Đợi Member gia hạn Gym | Audit `USER_ENABLED`; Notif `MEMBER_UNLOCKED_RESTORED` |
| `PAUSED` (`MEMBER_LOCKED`) | Admin mở khóa Member (**D4**) | Admin | Coach hiện `DISABLED`, gói Coach còn hạn | `PAUSED` (`COACH_LOCKED`) | Mở incident `OPEN`, bắt đầu đóng băng từ lúc mở khóa Member (nếu Gym `ACTIVE`) | Audit `USER_ENABLED`; Notif `COACH_LOCKED` |
| `ACTIVE` hoặc `PAUSED` | Chuyển Coach (**D2**) | Admin | Coach B `ACTIVE`, `< 8` suất, đủ `hasCoachCapacity` cho cả `ACTIVE` + `QUEUED` | Cũ: `ENDED`; Mới (Coach B): `ACTIVE` hoặc `PAUSED (MEMBERSHIP_EXPIRED)` | Đóng entitlement cũ (`TRANSFERRED`), tạo bản kế thừa `ACTIVE` (+`QUEUED`) trên Coach B giữ snapshot + cộng `delta_days` 1 lần (nếu từ `COACH_LOCKED`); hủy lịch cũ không trừ buổi; lưu giáo án `ARCHIVED`; trả suất Coach A, chiếm suất Coach B; đóng incident `RESOLVED_TRANSFERRED` | Audit `COACH_TRANSFERRED`; `coach_transfer_history`; Notif `COACH_TRANSFERRED` |
| `PAUSED` (`COACH_LOCKED`) | Hoàn tiền mô phỏng (**D2/D3**) | Admin | Incident `OPEN`, `Idempotency-Key`, lý do bắt buộc | `ENDED` | Tạo `simulated_refunds` cho `ACTIVE` (D3) + `QUEUED` (100% snapshot); đóng cả 2 gói (`SIMULATED_REFUND`); hủy lịch tương lai; lưu giáo án `ARCHIVED`; giải phóng suất Coach 1 lần; đóng incident `RESOLVED_REFUNDED` | Audit `SIMULATED_REFUND_CREATED`; Notif `SIMULATED_REFUND_COMPLETED` |
| `ACTIVE` hoặc `PAUSED` | Hết buổi (`remaining = 0`) hoặc hết hạn (+7 ngày) & không có `QUEUED` | System / Coach (`COMPLETE`/`NO_SHOW`/late cancel) | Không có `QUEUED` hợp lệ | `ENDED` | Hủy lịch tương lai, lưu giáo án/thực đơn `ARCHIVED`, hủy `HELD` hold, đóng `termination_requests` mở thành `CANCELLED`, giải phóng suất 1 lần | Notif `PACKAGE_ENDED` |
| `ACTIVE` hoặc `PAUSED (MEMBERSHIP_EXPIRED)` | Kết thúc sớm hai bên đồng ý hoặc Admin duyệt `DISPUTED` (**D5**) | Counterparty (`ACCEPT`) hoặc Admin (`ADMIN_APPROVED`) | Yêu cầu đang `PENDING_COUNTERPARTY` (trong 72h) hoặc `DISPUTED` | `ENDED` | Đóng cả `ACTIVE` & `QUEUED` (`EARLY_TERMINATION`, mất buổi, 0 ₫ hoàn); hủy lịch tương lai; lưu giáo án `ARCHIVED`; hủy `HELD` hold; giải phóng suất 1 lần; chat giữ nguyên | Audit `TERMINATION_DISPUTE_DECIDED` (nếu Admin); Notif `TERMINATION_ACCEPTED` / `TERMINATION_ADMIN_APPROVED` |

### 3.2. `coach_entitlements`

| Trạng thái nguồn | Sự kiện | Điều kiện | Trạng thái đích | Trường cập nhật & Bất biến |
|---|---|---|---|---|
| *(mới)* | `settleCoachHold` khi chưa có quan hệ | Hold `HELD`, paid `true`, amount khớp | `ACTIVE` | Lưu snapshot `plan_code`, `plan_name`, `snapshot_price`, `total_sessions`, `remaining_sessions = total_sessions`, `starts_on = today`, `original_ends_on = today + duration_days - 1`, `ends_on = original_ends_on`, `frozen_days_total = 0`, `grace_days_added = 0`, `frozen_at = NULL`. |
| *(mới)* | `settleCoachHold` khi đã có quan hệ với cùng Coach & chưa có `QUEUED` | Hold `HELD`, chưa có `QUEUED` | `QUEUED` | Lưu snapshot; `starts_on = original_ends_on = ends_on = NULL`. |
| `ACTIVE` (running) | Coach bị khóa (`COACH_LOCKED`) & Gym `ACTIVE` | `frozen_at IS NULL` | `ACTIVE` (frozen) | `frozen_at = statement_timestamp()`; reconciliation bỏ qua gói này. |
| `ACTIVE` (frozen) | Coach mở khóa (**D1**) hoặc Chuyển Coach (**D2**) | `frozen_at IS NOT NULL` | `ACTIVE` (running) / mới | `frozen_days_total += delta_days`, `ends_on = original_ends_on + frozen_days_total + grace_days_added`, `frozen_at = NULL`. |
| `ACTIVE` (running) | Qua `original_ends_on + frozen_days_total` mà vẫn còn buổi | `grace_days_added = 0`, `frozen_at IS NULL`, `remaining_sessions > 0` | `ACTIVE` (grace) | `grace_days_added = 7`, `ends_on = original_ends_on + frozen_days_total + 7` (chỉ 1 lần duy nhất). Notif `PACKAGE_EXTENDED`. |
| `ACTIVE` | Trừ buổi cuối (`remaining_sessions: 1 → 0`) | `COMPLETE` / `NO_SHOW` / Member hủy `< 12h` | `ENDED` (`COMPLETED_SESSIONS`) | `ended_at = now()`; nếu có `QUEUED` → kích hoạt `QUEUED → ACTIVE` (`starts_on = today`, `original_ends_on = today + duration_days - 1`, `ends_on = original_ends_on`). |
| `ACTIVE` (running) | Quá `ends_on` (đã qua cả 7 ngày bổ sung) | `frozen_at IS NULL`, `ends_on < today` | `ENDED` (`EXPIRED`) | `ended_at = now()`; nếu có `QUEUED` → kích hoạt nối tiếp từ `expired.ends_on + 1`. |
| `ACTIVE` / `QUEUED` | Chuyển Coach (**D2**) | Coach B đủ suất & công suất | Cũ: `ENDED` (`TRANSFERRED`); Mới trên Coach B: `ACTIVE` / `QUEUED` | Giữ nguyên toàn bộ snapshot, `remaining_sessions`, `grace_days_added`, `frozen_days_total`; `source_entitlement_id = old.id`. |
| `ACTIVE` / `QUEUED` | Hoàn tiền mô phỏng (**D2/D3**) | Incident `OPEN` | `ENDED` (`SIMULATED_REFUND`) | `ended_at = now()`; mỗi `coach_entitlement_id` có tối đa 1 dòng `simulated_refunds`. |
| `ACTIVE` / `QUEUED` | Kết thúc sớm (**D5**) | `ACCEPTED` / `ADMIN_APPROVED` | `ENDED` (`EARLY_TERMINATION`) | `ended_at = now()`; không hoàn tiền, không chuyển. |

### 3.3. `coach_payment_holds`

| Trạng thái nguồn | Sự kiện | Trạng thái đích | Ghi chú |
|---|---|---|---|
| *(mới)* | Member chọn Coach + gói (`POST /coach-payment-holds`, `Idempotency-Key`) | `HELD` | `expires_at = created_at + 15 minutes`; chiếm 1 suất tạm (nếu thuê mới). |
| `HELD` | Xác nhận thanh toán hợp lệ trong hạn (`settleCoachHold`) | `CONSUMED` | Ghi `settled_at = now()`; tạo `coach_entitlements` (`ACTIVE` hoặc `QUEUED`). |
| `HELD` | Member hủy thủ công / Admin khóa Coach / Admin khóa Member / Quan hệ kết thúc | `CANCELLED` | Giải phóng suất ngay lập tức. |
| `HELD` | Quá 15 phút (`expires_at <= statement_timestamp()`) | `EXPIRED` | Không còn được tính vào `coach_occupied_seats()`. |
| `HELD` | Thanh toán thất bại / sai số tiền / mất điều kiện Gym / không đủ công suất lúc settle | `FAILED` | Giải phóng suất, trả mã lỗi cụ thể cho tầng thanh toán. |

### 3.4. `coach_lock_incidents`

| Trạng thái nguồn | Sự kiện | Actor | Trạng thái đích | Ghi chú |
|---|---|---|---|---|
| *(mới)* | Admin khóa Coach có Member `ACTIVE`/`PAUSED (MEMBERSHIP_EXPIRED)` | Admin | `OPEN` (`member_choice = 'WAIT'`) | Ghi `frozen_started_at` (nếu Gym `ACTIVE`), `frozen_days_applied = NULL`. |
| `OPEN` | Member cập nhật lựa chọn (`POST /relationships/me/coach-lock-choice`) | Member | `OPEN` (`member_choice = 'WAIT'` hoặc `'REFUND'`) | Cập nhật `member_choice`, `member_choice_at`, `member_choice_note`. |
| `OPEN` | Admin mở khóa Coach (**D1**) | Admin | `RESOLVED_COACH_UNLOCKED` | Cộng `delta_days` 1 lần, khôi phục quan hệ. |
| `OPEN` | Admin chuyển Member sang Coach B (**D2**) | Admin | `RESOLVED_TRANSFERRED` | Lưu `transfer_history_id`, `frozen_days_applied = delta_days`. |
| `OPEN` | Admin thực thi hoàn tiền mô phỏng (**D2/D3**) | Admin | `RESOLVED_REFUNDED` | Lưu `refund_batch_id`; đóng cả `ACTIVE` + `QUEUED` + quan hệ. |
| `OPEN` | Quan hệ kết thúc ngoại lệ khác (nếu có) | System / Admin | `RESOLVED_ENDED` | Đảm bảo không còn incident treo khi quan hệ đã `ENDED`. |

### 3.5. `payments`, `payment_adjustments` (D6) & `member_memberships`

| Thực thể | Chuyển trạng thái | Quy tắc bất biến |
|---|---|---|
| `payments` | `PENDING → SUCCESS` (confirm `MOCK_QR`/gateway callback) · `PENDING → FAILED \| CANCELLED` (Admin/Member/gateway) · *(mới)* `→ SUCCESS` (`FRONT_DESK`) | **`SUCCESS` là bất biến tuyệt đối.** Không bao giờ `UPDATE` `amount`, `plan_id`, `status` của `payments` sau khi đã `SUCCESS`. |
| `payment_adjustments` | *(mới)* `→ VOID_REVERSAL` (D6) | Chỉ cho `payments (method = 'FRONT_DESK', status = 'SUCCESS')`; `UNIQUE (payment_id)`; thỏa cùng ngày VN hoặc chưa phát sinh usage; không có phụ thuộc Coach chưa xử lý; ghi audit `PAYMENT_VOID_REVERSED`. |
| `member_memberships` | `SCHEDULED → ACTIVE` (tới `start_date`) · `ACTIVE → EXPIRED` (qua `end_date`) · `SCHEDULED → EXPIRED` (lỡ hạn) · `SCHEDULED/ACTIVE → CANCELLED` (do D6 `VOID_REVERSAL` trên gói lẻ với `expired_at = NULL` theo `0001:171`, hoặc fold `0024`) | Nếu D6 đảo giao dịch gia hạn gộp (`renewed_membership_id IS NOT NULL`), rút gọn `end_date = end_date - duration_days_snapshot` (nếu `end_date < today` bắt buộc đặt `status = 'EXPIRED', activated_at = COALESCE(activated_at, start_date::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh'), expired_at = statement_timestamp()` theo `0001:169`). Exclusion `ex_memberships_no_overlap` luôn được bảo toàn. |

### 3.6. `simulated_refunds` (D3)

| Trạng thái | Nguồn gốc | Bất biến |
|---|---|---|
| `COMPLETED` (trạng thái duy nhất khi commit thành công) | `POST /api/v1/admin/coach-incidents/:incidentId/simulated-refunds` | Không có trạng thái pending/gateway; bất biến sau khi tạo; `UNIQUE (coach_entitlement_id)` chống hoàn 2 lần; `UNIQUE (created_by, idempotency_key, entitlement_kind)` chống trùng retry. |

### 3.7. `coach_termination_requests` (D5 — Early Termination & Dispute)

| Trạng thái nguồn | Sự kiện | Actor | Điều kiện | Trạng thái đích |
|---|---|---|---|---|
| *(mới)* | Gửi yêu cầu kết thúc sớm | Member hoặc Coach | Quan hệ `ACTIVE` hoặc `PAUSED (MEMBERSHIP_EXPIRED)`; chưa có yêu cầu mở | `PENDING_COUNTERPARTY` (`response_deadline_at = now() + 72h`) |
| `PENDING_COUNTERPARTY` | Người gửi tự rút yêu cầu | Requester | `now() < response_deadline_at` | `CANCELLED` |
| `PENDING_COUNTERPARTY` | Đối tác chấp nhận (`ACCEPT`) | Counterparty | `now() < response_deadline_at` | `ACCEPTED` → Quan hệ `ENDED` ngay, mất buổi chưa dùng |
| `PENDING_COUNTERPARTY` | Đối tác từ chối (`REJECT` + lý do) | Counterparty | `now() < response_deadline_at` | `DISPUTED` (`COUNTERPARTY_REJECTED`) |
| `PENDING_COUNTERPARTY` | Hết 72 giờ không phản hồi | System (reconcile / inline) | `now() >= response_deadline_at` | `DISPUTED` (`TIMEOUT_72H`) |
| `DISPUTED` | Admin duyệt kết thúc (`APPROVED` + lý do) | Admin | Yêu cầu đang `DISPUTED` | `ADMIN_APPROVED` → Quan hệ `ENDED` ngay, mất buổi chưa dùng |
| `DISPUTED` | Admin bác yêu cầu (`REJECTED` + lý do) | Admin | Yêu cầu đang `DISPUTED` | `ADMIN_REJECTED` → Quan hệ giữ nguyên |
| `PENDING_COUNTERPARTY` hoặc `DISPUTED` | Quan hệ kết thúc bởi sự kiện khác (hết buổi/hết hạn/chuyển/hoàn) | System / Admin | Quan hệ chuyển `ENDED` | `CANCELLED` |

---

## 4. Thứ tự khóa bản ghi chống Deadlock (Canonical Lock Ordering)

Mọi transaction đa bảng trên backend **bắt buộc** lấy lock theo đúng thứ tự sau để tránh deadlock giữa các request đồng thời (giữ suất 15 phút, thanh toán, đặt lịch, khóa Coach, khóa Member, chuyển Coach, hoàn tiền, đối soát vòng đời):

1. **Advisory lock vòng đời** *(chỉ khi cập nhật `member_memberships` hoặc chạy `reconcileMembershipLifecycles`)*:
   `SELECT pg_advisory_xact_lock(hashtext('meta-gym-membership-lifecycle'))`
2. **Tài khoản Admin thực thi** *(nếu endpoint `/admin/*`)*:
   `SELECT id FROM users WHERE id = $adminId AND role = 'ADMIN' AND status = 'ACTIVE' AND session_version = $sv FOR SHARE`
3. **Các bản ghi `users` liên quan (Coach TRƯỚC, Member SAU; trong cùng vai trò sắp xếp tăng dần theo `id ASC`)**:
   - Ví dụ **Chuyển Coach (D2)**: khóa `[oldCoachId, newCoachId].sort()` (`FOR UPDATE`), rồi khóa `memberId` (`FOR UPDATE`).
   - Ví dụ **Khóa/Mở khóa Coach (D1)**: khóa `coachId` (`FOR UPDATE`), rồi khóa toàn bộ `member_id` bị ảnh hưởng sắp theo `id ASC` (`FOR UPDATE`).
   - Ví dụ **Khóa/Mở khóa Member (D4)**: tra `coach_id` của quan hệ hiện tại (nếu có), khóa `coach_id` (`FOR UPDATE`), rồi khóa `memberId` (`FOR UPDATE`).
   - Ví dụ **Giữ suất 15 phút / Settle Hold / Đặt lịch 90 phút**: khóa `coachId` (`FOR UPDATE`), rồi khóa `memberId` (`FOR UPDATE`).
4. **`coach_relationships`** (`FOR UPDATE`, `ORDER BY id ASC`)
5. **`coach_entitlements`** (`FOR UPDATE`, `ORDER BY id ASC`)
6. **`coach_lock_incidents` / `coach_termination_requests` / `coach_payment_holds` / `payments` / `member_memberships`** (`FOR UPDATE`, `ORDER BY id ASC`)
7. **`coach_bookings`** (`FOR UPDATE`, `ORDER BY id ASC`)
8. **Ghi cuối transaction:** `INSERT INTO admin_audit_logs` và `INSERT INTO coach_notifications` ngay trước `COMMIT`.

---

## 5. Kịch bản Walkthrough Biên (Ngày, Tiền VND & Đồng thời)

### Walkthrough 1: Khóa Coach qua nửa đêm VN + Gym hết hạn giữa chừng + Mở khóa (D1)
- **Trạng thái đầu:**
  - Member A: Gym `2026-11-01..2026-11-22`, gói Coach 10 buổi (`starts_on = 2026-11-01`, `original_ends_on = 2026-11-30`, `ends_on = 2026-11-30`, còn 6 buổi), có 1 buổi `BOOKED` lúc `2026-11-22 09:00+07`.
- **Diễn biến:**
  1. `2026-11-21 23:45+07`: Admin khóa Coach X (`"Nghỉ đột xuất"`).
     - Phiên Coach X mất hiệu lực ngay (`session_version + 1`).
     - Quan hệ Member A → `PAUSED (COACH_LOCKED)`; lịch `11-22 09:00` → `CANCELLED` (`charged_at = NULL`, còn 6 buổi); `entitlement.frozen_at = 2026-11-21T16:45:00Z`; tạo incident `OPEN`.
  2. `2026-11-23 00:05+07`: `reconcileMembershipLifecycles` chạy.
     - Gym của Member A (`end_date = 2026-11-22 < 2026-11-23`) chuyển `EXPIRED`.
     - Quan hệ Member A vẫn giữ `PAUSED (COACH_LOCKED)` (không bị ghi đè mất sự cố Coach) và `entitlement.frozen_at IS NOT NULL` nên gói Coach **không** bị tự hết hạn.
  3. `2026-11-24 00:10+07`: Admin mở khóa Coach X (Member A vẫn đang chọn `WAIT`, chưa chuyển/hoàn).
     - `delta_days = 2026-11-24 - 2026-11-21 = 3` ngày.
     - Gói Coach Member A: `frozen_days_total = 3`, `ends_on = 2026-11-30 + 3 = 2026-12-03`, `frozen_at = NULL`.
     - Vì Gym đã `EXPIRED` → quan hệ Member A chuyển **`PAUSED (MEMBERSHIP_EXPIRED)`**; incident đóng `RESOLVED_COACH_UNLOCKED` (`frozen_days_applied = 3`).
     - Member A nhận thông báo `COACH_UNLOCKED_RESTORED` nhắc gia hạn Gym để tiếp tục đặt lịch với Coach X (hạn gói Coach mới: `03/12/2026`).

### Walkthrough 2: Chuyển Coach đồng thời khi đang có hold 15 phút ở suất thứ 8 + gói `QUEUED` (D2)
- **Trạng thái đầu:** Coach B có 7 Member `ACTIVE`. Lúc `10:00+07`, Member mới M9 mở hold 15 phút (`HELD`, `expires_at = 10:15+07`) trên Coach B → `coach_occupied_seats(B) = 8`.
- **Diễn biến:**
  1. Lúc `10:05+07`, Admin thử chuyển Member M1 (đang có `ACTIVE` 8 buổi + `QUEUED` 10 buổi từ sự cố Coach A) sang Coach B.
     - Transaction lấy lock Coach A, Coach B (`FOR UPDATE`), đếm `coach_occupied_seats(B) = 8 >= 8` → trả **`409 COACH_FULL`**.
  2. Lúc `10:16+07` (hold M9 hết hạn), Admin thử chuyển lại M1 sang Coach B.
     - `coach_occupied_seats(B) = 7 < 8`.
     - `hasCoachCapacity(client, B, [activeProposal(8 buổi), queuedProposal(10 buổi)])` chạy bipartite augmenting-path cho cả hai gói cùng lúc:
       - Nếu lịch Coach B không ghép nổi 10 buổi của gói `QUEUED` sau khi đã gánh 7 Member kia + 8 buổi `ACTIVE` → trả **`409 CAPACITY_UNAVAILABLE`**, giữ nguyên M1 ở trạng thái chờ.
       - Nếu đạt → chuyển nguyên vẹn cả `ACTIVE` + `QUEUED` sang Coach B, `occupied_seats(B) = 8`, hủy lịch cũ ở Coach A, lưu giáo án cũ chỉ đọc.

### Walkthrough 3: Hoàn tiền mô phỏng gói `ACTIVE` + `QUEUED` + Đối chiếu Dashboard (D2 + D3)
- **Trạng thái đầu:** Trong ngày `2026-11-21`, tổng thu Gym tại quầy `2.000.000 ₫` (không void), tổng thu gói Coach `CONSUMED` `3.000.000 ₫` → `grossRevenue = 5.000.000 ₫`.
- Member M6 bị `COACH_LOCKED`, có:
  - `ACTIVE`: Gói Nâng cao `30 buổi / 90 ngày`, `snapshot_price = 5.000.000 ₫`, còn `11 buổi`.
  - `QUEUED`: Gói Cơ bản `10 buổi / 30 ngày`, `snapshot_price = 1.950.000 ₫`.
- **Thực thi hoàn tiền mô phỏng:**
  - `ACTIVE`: `floor((5.000.000 * 11 / 30) / 1000) * 1000 = 1.833.000 ₫`.
  - `QUEUED`: `1.950.000 ₫` (100% snapshot).
  - Tổng hoàn mô phỏng: `3.783.000 ₫`.
- **Đối chiếu Dashboard ngày `2026-11-21`:**
  - `grossRevenue = 5.000.000 ₫`
  - `totalSimulatedRefunds = 3.783.000 ₫`
  - `netRevenue = 1.217.000 ₫`
- Retry cùng `Idempotency-Key` trả `200 OK` cùng batch `3.783.000 ₫`; gửi `Idempotency-Key` mới trả `409 INCIDENT_ALREADY_RESOLVED`.

### Walkthrough 4: Đảo giao dịch gia hạn gộp tại quầy (D6 + `0024_membership_renewals`)
- **Trạng thái đầu:** Member M7 đang có gói Gym `ACTIVE` (`2026-11-01..2026-11-30`). Lúc `2026-11-21 14:00+07`, Admin bán tại quầy thêm gói 60 ngày (`1.100.000 ₫`). Theo `0024_membership_renewals`, bản ghi `member_memberships` được nối dài `end_date: 2026-11-30 → 2027-01-29`, và `payment.renewed_membership_id` trỏ tới bản ghi đó.
- **Lúc `2026-11-23` (khác ngày VN):** Admin phát hiện nhập nhầm gói 60 ngày thay vì 30 ngày. Khoảng nối thêm `2026-12-01..2027-01-29` chưa bắt đầu (chưa sử dụng).
- **Thực thi `VOID_REVERSAL`:**
  - Hợp lệ theo nhánh *chưa phát sinh sử dụng* trên đoạn gia hạn.
  - `payments` gốc giữ nguyên `SUCCESS 1.100.000 ₫`.
  - Tạo `payment_adjustments` (`previous_end_date = 2027-01-29`, `restored_end_date = 2026-11-30`, `reversed_amount = 1.100.000`).
  - `member_memberships.end_date` được thu hẹp lại đúng `2026-11-30`, gói `ACTIVE` gốc của M7 không hề bị hủy oan!
  - Admin lập giao dịch thay thế 30 ngày (`600.000 ₫`) → `end_date` mới là `2026-12-30`.
