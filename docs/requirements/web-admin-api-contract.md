# T3 — Hợp đồng API Web Admin, Allowlist Quyền Riêng Tư & Kế hoạch Migration `0029+`

**Ngày lập:** 21/11/2026  
**Phạm vi:** Giai đoạn 0 — T3 (Contract API cho toàn bộ endpoint Web Admin & các endpoint Member/Coach chịu tác động, Ma trận Quyền Riêng Tư, và Kế hoạch Migration `0029`–`0033` kèm Rollback)  
**Phụ thuộc:** `docs/requirements/web-admin-t1-audit.md` (T1), `docs/requirements/web-admin-decisions-and-states.md` (T2)

---

## 1. Quy ước chung của API (`/api/v1`)

### 1.1. Xác thực, phân trang, lỗi & múi giờ
- **Prefix:** `/api/v1`
- **Auth Header:** `Authorization: Bearer <jwt>` (HS256, `iss = meta-gym-api`, `aud = meta-gym-clients`, TTL 3600s). Mọi request đi qua `createAuthentication()` kiểm tra `users.status = 'ACTIVE'`, `role`, `session_version` và chạy `reconcileMembershipLifecycles(database)`.
- **Idempotency Header:** `Idempotency-Key: <uuid-v4>` bắt buộc trên mọi thao tác tài chính / chuyển đổi trạng thái rủi ro cao (`POST /admin/front-desk-payments`, `POST /admin/payments/:id/void-reversal`, `POST /admin/coach-transfers`, `POST /admin/coach-incidents/:id/transfer`, `POST /admin/coach-incidents/:id/simulated-refunds`, `POST /coach-payment-holds`).
  - Gửi lại cùng key + cùng payload (`request_hash` SHA-256) → trả `200 OK` cùng kết quả ban đầu.
  - Gửi lại cùng key + khác payload → trả `409 IDEMPOTENCY_KEY_CONFLICT` (hoặc `422 IDEMPOTENCY_KEY_CONFLICT` trên endpoint legacy payments để giữ tương thích test hiện có).
- **Phong bì phản hồi chuẩn:**
  - Thành công danh sách: `{ "data": [...], "pagination": { "page": 1, "pageSize": 20, "totalItems": 124, "totalPages": 7 } }`
  - Thành công đơn lẻ: `{ "data": { ... } }`
  - Lỗi: `{ "error": { "code": "ERROR_CODE", "message": "Thông báo tiếng Việt rõ ràng", "details": {} } }`
- **Mã lỗi nền chuẩn:** `401 UNAUTHORIZED`, `403 FORBIDDEN`, `404 NOT_FOUND`, `409 CONFLICT` (kèm mã nghiệp vụ cụ thể), `422 VALIDATION_ERROR`, `429 TOO_MANY_REQUESTS`, `500 INTERNAL_SERVER_ERROR`, `503 SERVICE_UNAVAILABLE`.
  ```json
  // Ví dụ lỗi 403 quyền riêng tư / bị chặn gửi chat tới tài khoản DISABLED
  { "error": { "code": "RECIPIENT_ACCOUNT_DISABLED", "message": "Không thể gửi tin nhắn vì tài khoản người nhận đang bị khóa", "details": {} } }
  // Ví dụ lỗi 409 công suất khi chuyển Coach (D2)
  { "error": { "code": "CAPACITY_UNAVAILABLE", "message": "Lịch Coach mới không đủ công suất cho cả gói đang dùng và gói chờ", "details": { "checkedEntitlements": ["ACTIVE", "QUEUED"] } } }
  // Ví dụ lỗi 422 validation
  { "error": { "code": "VALIDATION_ERROR", "message": "Dữ liệu không hợp lệ", "details": { "fields": { "memberLimit": ["Trường này không được phép"] } } } }
  ```
- **Quy tắc hiển thị danh sách:** Mọi endpoint danh sách Admin (`payments`, `relationships`, `coach-incidents`, `coach-transfers`, `termination-requests`, `simulated-refunds`, `audit-logs`) **phải join và trả tên người (`memberName`, `coachName`, `adminName`)** để bảng Web Admin hiển thị tên người thay vì UUID thô; UUID chỉ hiển thị trong drawer/màn chi tiết và nhật ký audit.
- **Múi giờ:** Tham số lọc ngày (`from`, `to`) theo định dạng `YYYY-MM-DD` tính trong `Asia/Ho_Chi_Minh`.

---

## 2. Hợp đồng chi tiết các Endpoint Web Admin & Endpoint Member/Coach chịu tác động

### 2.1. Tổng quan (Dashboard) — `backend/src/routes/dashboard.routes.js`

#### `GET /api/v1/admin/dashboard`
- **Quyền:** `ADMIN` (`403` cho Member/Coach).
- **Query:** `from` (`YYYY-MM-DD`, mặc định hôm nay − 29 ngày VN), `to` (`YYYY-MM-DD`, mặc định hôm nay VN); `from <= to`.
- **Thay đổi bắt buộc:** **XÓA hoàn toàn `pendingCoachRequests`** (luồng V1 đã bỏ). Bổ sung KPI hàng chờ `COACH_LOCKED`, tranh chấp `DISPUTED` (D5), và tách rõ doanh thu **Gross / Void Reversal / Simulated Refund / Net** (D3 + D6).
- **Response `200 OK`:**
```json
{
  "data": {
    "from": "2026-10-23",
    "to": "2026-11-21",
    "timezone": "Asia/Ho_Chi_Minh",
    "members": { "active": 142, "disabled": 5 },
    "coaches": { "active": 8, "disabled": 1 },
    "activeMemberships": 96,
    "activeCoachRelationships": 38,
    "pausedCoachRelationships": {
      "total": 5,
      "membershipExpired": 2,
      "coachLocked": 2,
      "memberLocked": 1
    },
    "actionQueue": {
      "coachLockedWaitingCount": 2,
      "coachLockedRefundRequestedCount": 1,
      "disputedTerminationCount": 1
    },
    "revenue": {
      "gymGrossPayments": 28500000,
      "totalVoidReversals": 1500000,
      "coachGrossPayments": 18000000,
      "grossRevenue": 45000000,
      "totalSimulatedRefunds": 3783000,
      "netRevenue": 41217000,
      "gymPaymentCount": 31,
      "coachPackageCount": 6,
      "voidReversalCount": 1,
      "simulatedRefundCount": 2,
      "byDay": [
        {
          "day": "2026-11-21",
          "gymGross": 2000000,
          "voidReversals": 0,
          "coachGross": 3000000,
          "grossRevenue": 5000000,
          "simulatedRefunds": 3783000,
          "netRevenue": 1217000
        }
      ]
    },
    "newMembersByDay": [{ "day": "2026-11-21", "count": 4 }]
  }
}
```
- **Trường cấm tuyệt đối:** Mọi thông tin sức khỏe, số đo, nhật ký, tin nhắn, AI.

---

### 2.2. Quản lý Tài khoản Member & Coach (D1, D4, S4, S5) — `backend/src/routes/admin-users.routes.js`

| Method & Path | Role | Mục đích & Tham số chính | Audit Action |
|---|---|---|---|
| `GET /api/v1/admin/users` | `ADMIN` | Danh sách Member/Coach. Query: `role` (`MEMBER`\|`COACH`), `status` (`ACTIVE`\|`DISABLED`), `search` (tên/email/SĐT), `page`, `pageSize` (`1..100`). Trả thêm `usedSlots` & `memberLimit: 8` cho Coach, `activeMembershipEndDate` & `coachRelationshipStatus` cho Member. | — |
| `GET /api/v1/admin/users/:userId` | `ADMIN` | Chi tiết vận hành 1 Member/Coach: thông tin định danh (`id`, `email`, `fullName`, `phone`, `role`, `status`, `disabledAt`, `disabledReason`, `createdAt`, `lastLoginAt`), tóm tắt vận hành (Coach: `memberLimit: 8`, `usedSlots`, `activeRelationshipsCount`, `openHoldCount`, `scheduleConfigured`; Member: gói Gym hiện tại, quan hệ Coach hiện tại & `pauseReason`, lịch sử khóa/mở từ `admin_audit_logs`). **Tuyệt đối không trả trường nào từ `member_profiles` nhạy cảm.** | — |
| `GET /api/v1/admin/users/:userId/lock-preview` | `ADMIN` | Xem trước tác động trước khi mở modal khóa Member/Coach (read-only): danh sách tên Member bị ảnh hưởng (nếu khóa Coach), số lịch `BOOKED` tương lai sẽ bị hủy không trừ buổi, số `HELD` hold sẽ bị hủy, cảnh báo đóng băng gói Coach (Coach) hoặc giữ suất & đồng hồ tiếp tục chạy (Member). | — |
| `POST /api/v1/admin/coaches` | `ADMIN` | Tạo tài khoản Coach mới. Body: `{ email, fullName, password }`. **Trần cứng 8:** không nhận `memberLimit` cấu hình tự do (nếu client gửi `memberLimit` khác `8` → `422 VALIDATION_ERROR`; DB luôn lưu `member_limit = 8`). | `COACH_CREATED` |
| `PATCH /api/v1/admin/users/:userId` | `ADMIN` | Sửa `fullName`, `phone`. **Từ chối `memberLimit`** (`422 VALIDATION_ERROR` vì `z.strictObject` không cho phép sửa trần cứng 8). | `USER_UPDATED` |
| `PATCH /api/v1/admin/users/:userId/status` | `ADMIN` | Khóa (`DISABLED`, bắt buộc `reason` 1–500 ký tự) hoặc Mở khóa (`ACTIVE`). Thực thi nguyên tử toàn bộ hiệu ứng **D1** (Coach) hoặc **D4** (Member) theo thứ tự lock chuẩn T2 §4. | `USER_DISABLED` / `USER_ENABLED` |
| `POST /api/v1/admin/coaches/:coachId/password-resets` | `ADMIN` | Sinh mật khẩu tạm 1 lần, tăng `session_version + 1` thu hồi phiên cũ. Trả `{ temporaryPassword, reminder: "Hãy gửi mật khẩu tạm cho Coach qua kênh nội bộ và nhắc Coach đổi mật khẩu sau khi đăng nhập." }`. Không lưu `temporaryPassword` vào audit log. | `COACH_PASSWORD_RESET` |

#### Ví dụ Request/Response `PATCH /api/v1/admin/users/:coachId/status` (Khóa Coach — D1)
- **Request:**
```json
{ "status": "DISABLED", "reason": "Coach nghỉ phép đột xuất dài ngày" }
```
- **Response `200 OK`:**
```json
{
  "data": {
    "user": {
      "id": "c0a10000-0000-4000-8000-000000000001",
      "email": "coach.a@metagym.vn",
      "fullName": "Nguyễn Minh Quân",
      "role": "COACH",
      "status": "DISABLED",
      "disabledAt": "2026-11-21T03:00:00.000Z",
      "disabledReason": "Coach nghỉ phép đột xuất dài ngày",
      "memberLimit": 8
    },
    "effects": {
      "sessionsRevoked": true,
      "cancelledHoldsCount": 1,
      "cancelledFutureBookingsCount": 4,
      "affectedRelationshipsCount": 2,
      "incidentsCreated": [
        {
          "incidentId": "inc-0001-...",
          "relationshipId": "rel-0001-...",
          "memberId": "m001-...",
          "memberName": "Trần Thu Hà",
          "entitlementFrozen": true,
          "frozenStartedAt": "2026-11-21T03:00:00.000Z"
        }
      ]
    }
  }
}
```
#### Ví dụ Response `PATCH /api/v1/admin/users/:coachId/status` (Mở khóa Coach — D1 auto-restore)
- **Request:** `{ "status": "ACTIVE" }`
- **Response `200 OK`:**
```json
{
  "data": {
    "user": { "id": "c0a10000-0000-4000-8000-000000000001", "status": "ACTIVE", "memberLimit": 8 },
    "effects": {
      "restoredRelationshipsCount": 2,
      "restored": [
        {
          "incidentId": "inc-0001-...",
          "relationshipId": "rel-0001-...",
          "memberId": "m001-...",
          "memberName": "Trần Thu Hà",
          "newRelationshipStatus": "ACTIVE",
          "newPauseReason": null,
          "frozenDaysAdded": 4,
          "newEndsOn": "2026-12-04"
        },
        {
          "incidentId": "inc-0002-...",
          "relationshipId": "rel-0002-...",
          "memberId": "m002-...",
          "memberName": "Lê Quang Huy",
          "newRelationshipStatus": "PAUSED",
          "newPauseReason": "MEMBERSHIP_EXPIRED",
          "frozenDaysAdded": 4,
          "newEndsOn": "2026-12-14"
        }
      ]
    }
  }
}
```
- **Lỗi chuẩn:** `404 NOT_FOUND`, `422 VALIDATION_ERROR` (thiếu `reason` khi `DISABLED`), `401 UNAUTHORIZED`.

---

### 2.3. Danh mục Gói Gym (`membership_plans`) — `backend/src/routes/membership-plans.routes.js`

| Method & Path | Role | Chi tiết | Audit Action |
|---|---|---|---|
| `GET /api/v1/admin/membership-plans` | `ADMIN` | Query: `status` (`ACTIVE`\|`INACTIVE`), `search`, `page`, `pageSize`. Trả kèm `activeMembershipCount`, `scheduledMembershipCount`. | — |
| `POST /api/v1/admin/membership-plans` | `ADMIN` | Body: `{ name, description?, price (int >= 0), durationDays (1..3650), status }`. | `MEMBERSHIP_PLAN_CREATED` |
| `PATCH /api/v1/admin/membership-plans/:planId` | `ADMIN` | Body partial: `{ name?, description?, price?, durationDays?, status? }`. **KHÔNG còn `409 PLAN_TERMS_LOCKED`** — cho phép sửa `price` và `durationDays` trực tiếp kể cả khi đã có giao dịch `SUCCESS`; thay đổi chỉ ảnh hưởng giao dịch mới (nhờ snapshot trên `payments`). | `MEMBERSHIP_PLAN_UPDATED` |

---

### 2.4. Danh mục Gói Coach (`coach_package_plans`) & Entitlements — `backend/src/routes/coach-packages.routes.js`

| Method & Path | Role | Chi tiết | Audit Action |
|---|---|---|---|
| `GET /api/v1/coach-packages` | Public | Danh sách gói `ACTIVE` sắp theo `session_count ASC, price ASC`. Trả `code`, `name`, `description`, `sessionCount`, `durationDays`, `price`, `status`. | — |
| `GET /api/v1/admin/coach-packages` | `ADMIN` | Query: `status` (`ACTIVE`\|`INACTIVE`), `search`. Trả tất cả gói (kể cả gói mới tạo ngoài 3 gói mặc định) kèm `activeEntitlementCount`, `queuedEntitlementCount`. | — |
| `POST /api/v1/admin/coach-packages` | `ADMIN` | **Mới:** Tạo gói Coach vào danh mục. Body: `{ code (^[A-Z0-9][A-Z0-9_-]{1,39}$), name (1..100), description? (0..1000), sessionCount (1..365), durationDays (1..730), price (int >= 0), status ('ACTIVE'\|'INACTIVE') }`. Lỗi trùng mã: `409 COACH_PACKAGE_CODE_EXISTS`. | `COACH_PACKAGE_CREATED` |
| `PATCH /api/v1/admin/coach-packages/:code` | `ADMIN` | **Mở rộng:** Cho sửa `name`, `description`, `sessionCount`, `durationDays`, `price`, `status` trên bất kỳ `code` nào trong bảng (bỏ enum 3 mã cứng). Thay đổi chỉ áp dụng cho hold/giao dịch mới; gói đã mua/`QUEUED` giữ nguyên snapshot. | `COACH_PACKAGE_UPDATED` |
| `GET /api/v1/admin/coach-entitlements` | `ADMIN` | **Mới:** Xem danh sách gói Coach đã mua của hội viên (vận hành). Query: `memberId`, `coachId`, `status` (`ACTIVE`\|`QUEUED`\|`ENDED`), `frozenOnly` (`true`\|`false`), `page`, `pageSize`. Trả tên Member/Coach, `planCode`, `planName`, `snapshotPrice`, `totalSessions`, `remainingSessions`, `startsOn`, `originalEndsOn`, `endsOn`, `frozenAt`, `frozenDaysTotal`, `graceDaysAdded`, `closeReason`. | — |
| `POST /api/v1/coach-payment-holds` | `MEMBER` | **Cập nhật (`coach-payment-holds.routes.js`):** Bỏ `z.enum(['BASIC','STANDARD','ADVANCED'])`, kiểm tra `planCode` regex `^[A-Z0-9][A-Z0-9_-]{1,39}$` đối chiếu trực tiếp bảng `coach_package_plans WHERE code = $1 AND status = 'ACTIVE'`. | — |

#### Ví dụ Request/Response `POST /api/v1/admin/coach-packages`
- **Request:**
```json
{
  "code": "PRO_40",
  "name": "Chuyên sâu 40 buổi",
  "description": "Lộ trình 120 ngày dành cho mục tiêu thi đấu/tăng cơ dài hạn",
  "sessionCount": 40,
  "durationDays": 120,
  "price": 7200000,
  "status": "ACTIVE"
}
```
- **Response `201 Created`:**
```json
{
  "data": {
    "code": "PRO_40",
    "name": "Chuyên sâu 40 buổi",
    "description": "Lộ trình 120 ngày dành cho mục tiêu thi đấu/tăng cơ dài hạn",
    "sessionCount": 40,
    "durationDays": 120,
    "price": 7200000,
    "status": "ACTIVE",
    "createdAt": "2026-11-21T06:00:00.000Z"
  }
}
```

---

### 2.5. Giao dịch Gym tại quầy, Lịch sử & Điều chỉnh `VOID_REVERSAL` (D6) — `backend/src/routes/payments.routes.js`

| Method & Path | Role | Chi tiết | Audit Action |
|---|---|---|---|
| `GET /api/v1/admin/payments` | `ADMIN` | **Nâng cấp:** Query `status`, `method` (`FRONT_DESK`\|`MOCK_QR`\|`VNPAY`\|`MOMO`\|`ZALOPAY`), `memberId`, `search` (mã GD / tên Member / email), `from`, `to` (`Asia/Ho_Chi_Minh`), `adjusted` (`true`\|`false`), `page`, `pageSize`. Trả tên Member (`memberName`, `memberEmail`), `planName`, `durationDays`, `amount`, `method`, `status`, `renewedMembershipId`, `adjustment` (nếu đã `VOID_REVERSAL`), `canVoidReversal` (`boolean` + `voidBlockedReason` để UI disable nút đúng lý do). | — |
| `GET /api/v1/admin/payments/:paymentId` | `ADMIN` | Chi tiết 1 giao dịch Gym kèm bản ghi `member_memberships` gắn kèm và bản ghi `payment_adjustments` (nếu có). | — |
| `POST /api/v1/admin/front-desk-payments` | `ADMIN` | Giữ nguyên bán **chỉ gói Gym** tại quầy; bắt buộc header `Idempotency-Key` (UUID); frontend bắt buộc sinh key mới mỗi khi đổi `memberId` hoặc `planId` (chỉ tái dùng key khi retry cùng payload). | `FRONT_DESK_PAYMENT_CONFIRMED` |
| `PATCH /api/v1/admin/payments/:paymentId` | `ADMIN` | Chỉ đánh dấu `FAILED`/`CANCELLED` cho giao dịch `PENDING` không thuộc cổng thanh toán kiểm soát. | `PAYMENT_DECIDED` |
| `POST /api/v1/admin/payments/:paymentId/void-reversal` | `ADMIN` | **Mới (D6):** Tạo bản ghi `payment_adjustments (VOID_REVERSAL)` cho giao dịch `FRONT_DESK` đã `SUCCESS`. Bắt buộc header `Idempotency-Key` (UUID) + body `{ reason (1..500) }`. Không sửa bảng `payments`. | `PAYMENT_VOID_REVERSED` |
| `GET /api/v1/admin/memberships` | `ADMIN` | **Nâng cấp:** Thêm query `status`, `memberId`, `search`, `page`, `pageSize` + trả `memberName`, `memberEmail`, `planName`. | — |

#### Ví dụ Request/Response/Error `POST /api/v1/admin/payments/:paymentId/void-reversal` (D6)
- **Headers:** `Authorization: Bearer <admin-jwt>`, `Idempotency-Key: 9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d`
- **Request:** `{ "reason": "Thu ngân chọn nhầm gói 90 ngày thay vì gói 30 ngày" }`
- **Response `201 Created`:**
```json
{
  "data": {
    "adjustment": {
      "id": "adj-0001-...",
      "paymentId": "pay-0001-...",
      "adjustmentType": "VOID_REVERSAL",
      "reversedAmount": 1500000,
      "affectedMembershipId": "mem-0001-...",
      "previousMembershipStatus": "ACTIVE",
      "newMembershipStatus": "CANCELLED",
      "previousEndDate": "2027-02-18",
      "restoredEndDate": null,
      "reason": "Thu ngân chọn nhầm gói 90 ngày thay vì gói 30 ngày",
      "createdBy": "adm-0001-...",
      "createdAt": "2026-11-21T01:45:00.000Z"
    },
    "payment": { "id": "pay-0001-...", "status": "SUCCESS", "amount": 1500000 }
  }
}
```
- **Mã lỗi nghiệp vụ D6:**
  - `409 ONLY_FRONT_DESK_ADJUSTABLE`: giao dịch không phải `FRONT_DESK` hoặc không phải `SUCCESS`.
  - `409 PAYMENT_ALREADY_REVERSED`: giao dịch đã có bản ghi `payment_adjustments` (với `Idempotency-Key` khác).
  - `409 PAYMENT_ADJUSTMENT_WINDOW_EXPIRED`: đã qua ngày làm việc Việt Nam **và** gói đã phát sinh lượt điểm danh sử dụng.
  - `409 PAYMENT_HAS_COACH_DEPENDENCY`: có suất giữ hoặc gói Coach phụ thuộc gói Gym này mà không có gói Gym khác bọc thay.
  - `409 RENEWAL_LIFO_REQUIRED`: tồn tại giao dịch gia hạn gộp mới hơn trên cùng `renewed_membership_id` chưa được đảo trước.

---

### 2.6. Hàng chờ Sự cố Coach, Chuyển Coach (D2) & Hoàn tiền Mô phỏng (D3) — `backend/src/routes/coach-incidents.routes.js` & `coaching.routes.js`

| Method & Path | Role | Chi tiết | Audit Action |
|---|---|---|---|
| `POST /api/v1/relationships/me/coach-lock-choice` | `MEMBER` | **Mới:** Khi quan hệ của Member đang `PAUSED (COACH_LOCKED)` và có incident `OPEN`, Member gửi `{ choice: "WAIT" \| "REFUND", note?: string (max 500) }`. | — |
| `GET /api/v1/admin/coach-incidents` | `ADMIN` | **Mới:** Hàng chờ sự cố khóa Coach. Query: `status` (`OPEN`\|`RESOLVED_*`), `coachId`, `memberChoice` (`WAIT`\|`REFUND`), `search`, `page`, `pageSize`. Trả tên Member/Coach, ngày khóa, số ngày đang đóng băng (tính động theo VN date), thông tin gói `ACTIVE` + `QUEUED`, `estimatedActiveRefund`, `estimatedQueuedRefund`, `estimatedTotalRefund`, `memberChoice`, trạng thái gói Gym của Member. | — |
| `GET /api/v1/admin/coach-incidents/:incidentId/eligible-coaches` | `ADMIN` | **Mới:** Liệt kê toàn bộ Coach `ACTIVE` khác Coach cũ kèm: `usedSlots`, `memberLimit: 8`, `seatAvailable`, `scheduleConfigured`, `capacityEligibleForActiveAndQueued` (kiểm tra đồng thời cả `ACTIVE` + `QUEUED` theo D2), `ineligibleReason`. | — |
| `POST /api/v1/admin/coach-incidents/:incidentId/transfer` (và nâng cấp `POST /api/v1/admin/coach-transfers`) | `ADMIN` | **D2:** Chuyển Member sang `newCoachId` (cả trong sự cố `COACH_LOCKED` lẫn chuyển chủ động trên quan hệ `ACTIVE`/`PAUSED`). Header `Idempotency-Key` (UUID), body `{ newCoachId, reason (1..1000) }` (với `/coach-transfers` thêm `memberId`). Kiểm tra `< 8` suất + `hasCoachCapacity` cho **cả `ACTIVE` + `QUEUED`**, bảo toàn snapshot, cộng `delta_days` 1 lần nếu `COACH_LOCKED`, hủy lịch cũ không trừ buổi, lưu giáo án cũ chỉ đọc, đóng incident `RESOLVED_TRANSFERRED`. | `COACH_TRANSFERRED` |
| `POST /api/v1/admin/coach-incidents/:incidentId/simulated-refunds` | `ADMIN` | **Mới (D2 + D3):** Thực thi hoàn tiền mô phỏng cho incident đang `OPEN` (`COACH_LOCKED`). Header `Idempotency-Key` (UUID), body `{ reason (1..500) }`. Hoàn `ACTIVE` theo công thức D3 + hoàn 100% snapshot `QUEUED` (nếu có); đóng cả 2 gói và quan hệ; trả suất Coach 1 lần. | `SIMULATED_REFUND_CREATED` |
| `GET /api/v1/admin/simulated-refunds` | `ADMIN` | **Mới:** Lịch sử hoàn tiền mô phỏng phân trang. Query: `memberId`, `coachId`, `from`, `to`, `search`, `page`, `pageSize`. Trả tên Member/Coach, `entitlementKind` (`ACTIVE`\|`QUEUED`), `snapshotPrice`, `remainingSessions`, `totalSessions`, `refundAmount`, `reason`, `createdAt`. | — |

#### Ví dụ Request/Response `POST /api/v1/admin/coach-incidents/:incidentId/simulated-refunds` (D2 + D3)
- **Headers:** `Authorization: Bearer <admin-jwt>`, `Idempotency-Key: 3f2504e0-4f89-41d3-9a0c-0305e82c3301`
- **Request:** `{ "reason": "Chưa có Coach thay thế phù hợp; Member chọn nhận hoàn tiền mô phỏng" }`
- **Response `201 Created`:**
```json
{
  "data": {
    "refundBatchId": "bat-0001-...",
    "incidentId": "inc-0001-...",
    "relationshipId": "rel-0001-...",
    "totalRefundAmount": 3783000,
    "items": [
      {
        "id": "ref-0001-...",
        "coachEntitlementId": "ent-active-...",
        "entitlementKind": "ACTIVE",
        "planName": "Nâng cao",
        "snapshotPrice": 5000000,
        "totalSessions": 30,
        "remainingSessions": 11,
        "refundAmount": 1833000,
        "status": "COMPLETED"
      },
      {
        "id": "ref-0002-...",
        "coachEntitlementId": "ent-queued-...",
        "entitlementKind": "QUEUED",
        "planName": "Cơ bản",
        "snapshotPrice": 1950000,
        "totalSessions": 10,
        "remainingSessions": 10,
        "refundAmount": 1950000,
        "status": "COMPLETED"
      }
    ],
    "relationshipStatus": "ENDED",
    "incidentStatus": "RESOLVED_REFUNDED"
  }
}
```
- **Mã lỗi nghiệp vụ:** `409 INCIDENT_ALREADY_RESOLVED`, `409 ALREADY_REFUNDED`, `409 IDEMPOTENCY_KEY_CONFLICT`, `409 COACH_FULL`, `409 CAPACITY_UNAVAILABLE`, `409 TRANSFER_NOT_ALLOWED`.

#### Ví dụ Request/Response `POST /api/v1/admin/coach-incidents/:incidentId/transfer` (D2)
- **Headers:** `Authorization: Bearer <admin-jwt>`, `Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000`
- **Request:** `{ "newCoachId": "c0a20000-0000-4000-8000-000000000002", "reason": "Chuyển sang Coach B còn suất và đủ lịch trống" }`
- **Response `201 Created`:**
```json
{
  "data": {
    "transferId": "trf-0001-...",
    "oldRelationshipId": "rel-0001-...",
    "newRelationshipId": "rel-0002-...",
    "newRelationshipStatus": "ACTIVE",
    "frozenDaysAdded": 3,
    "transferredEntitlements": [
      { "kind": "ACTIVE", "oldId": "ent-a1", "newId": "ent-a2", "remainingSessions": 12, "totalSessions": 20, "snapshotPrice": 4000000, "endsOn": "2026-12-23" },
      { "kind": "QUEUED", "oldId": "ent-q1", "newId": "ent-q2", "remainingSessions": 10, "totalSessions": 10, "snapshotPrice": 2200000, "endsOn": null }
    ],
    "cancelledOldBookingsCount": 2,
    "incidentStatus": "RESOLVED_TRANSFERRED"
  }
}
```

---

### 2.7. Quan hệ Member–Coach & Kết thúc sớm / Tranh chấp 72h (D5) — `backend/src/routes/coaching.routes.js`

| Method & Path | Role | Chi tiết | Audit Action |
|---|---|---|---|
| `GET /api/v1/admin/relationships` | `ADMIN` | **Nâng cấp:** Query `status` (`ACTIVE`\|`PAUSED`\|`ENDED`), `pauseReason` (`MEMBERSHIP_EXPIRED`\|`COACH_LOCKED`\|`MEMBER_LOCKED`), `coachId`, `memberId`, `search`, `page`, `pageSize`. Trả `memberName`, `coachName`, `activeEntitlement` (tên gói, `remainingSessions`/`totalSessions`, `endsOn`, `frozenAt`), `hasQueuedPackage`, `openTerminationStatus`. | — |
| `GET /api/v1/admin/relationships/:relationshipId` | `ADMIN` | Chi tiết quan hệ vận hành + gói `ACTIVE`/`QUEUED` + lịch sử chuyển + yêu cầu kết thúc sớm + sự cố khóa Coach (tuyệt đối không có nội dung giáo án/thực đơn/sức khỏe/chat). | — |
| `GET /api/v1/admin/coach-transfers` | `ADMIN` | **Nâng cấp:** Phân trang, lọc `memberId`/`oldCoachId`/`newCoachId`/`from`/`to`/`search`, trả tên Member, Coach cũ, Coach mới, Admin. | — |
| `POST /api/v1/relationships/:relationshipId/early-termination-requests` | `MEMBER` \| `COACH` | **Mới (D5):** Gửi yêu cầu kết thúc sớm kèm `{ reason (1..1000) }`. Tạo bản ghi `PENDING_COUNTERPARTY`, `responseDeadlineAt = createdAt + 72h`. Từ chối nếu `COACH_LOCKED` (`409 USE_COACH_INCIDENT_FLOW`) hoặc đã có yêu cầu mở (`409 REQUEST_EXISTS`). | — |
| `GET /api/v1/early-termination-requests/me` | `MEMBER` \| `COACH` | **Mới (D5):** Danh sách yêu cầu liên quan tới Member/Coach hiện tại (tự động leo thang inline các bản ghi quá 72h sang `DISPUTED` trước khi trả về). | — |
| `PATCH /api/v1/early-termination-requests/:requestId/respond` | `MEMBER` \| `COACH` | **Mới (D5):** Đối tác phản hồi `{ decision: "ACCEPT" \| "REJECT", reason?: string }` (bắt buộc `reason` khi `REJECT`) hoặc người gửi rút `{ decision: "WITHDRAW" }`. Nếu đã quá `responseDeadlineAt` → tự động chuyển `DISPUTED` và trả `409 TERMINATION_DEADLINE_EXPIRED`. | — |
| `GET /api/v1/admin/termination-requests` | `ADMIN` | **Nâng cấp (D5):** Tự động leo thang inline các ca quá 72h sang `DISPUTED`. Query: `status` (`DISPUTED`\|`PENDING_COUNTERPARTY`\|`ACCEPTED`\|`ADMIN_APPROVED`\|`ADMIN_REJECTED`\|`CANCELLED`), `search`, `page`, `pageSize`. Trả tên Member, Coach, vai trò người gửi, lý do 2 bên, `responseDeadlineAt`, `disputedAt`, `escalationReason`. | — |
| `PATCH /api/v1/admin/termination-requests/:requestId` | `ADMIN` | **Nâng cấp (D5):** Chỉ chấp nhận khi `status = 'DISPUTED'` (nếu `PENDING_COUNTERPARTY` chưa quá 72h → `409 NOT_DISPUTED`). Body: `{ decision: "APPROVED" \| "REJECTED", reason (1..1000 bắt buộc) }`. | `TERMINATION_DISPUTE_DECIDED` |
| `POST /api/v1/relationships/:relationshipId/terminations` & `POST /api/v1/coach/termination-requests` & `DELETE /api/v1/coach-requests/:requestId` | Legacy | Chuyển sang **`410 LEGACY_WORKFLOW_RETIRED`** trong `legacy-v1.routes.js` để không còn đường vòng vượt qua D5 hoặc luồng `coach_requests` cũ. | — |

#### Ví dụ Request/Response D5 (`PATCH /api/v1/admin/termination-requests/:requestId`)
- **Request:** `{ "decision": "APPROVED", "reason": "Coach không phản hồi quá 72 giờ; xác nhận kết thúc sớm theo quy định D5" }`
- **Response `200 OK`:**
```json
{
  "data": {
    "id": "term-0001-...",
    "relationshipId": "rel-0001-...",
    "status": "ADMIN_APPROVED",
    "requestedByRole": "MEMBER",
    "escalationReason": "TIMEOUT_72H",
    "adminNote": "Coach không phản hồi quá 72 giờ; xác nhận kết thúc sớm theo quy định D5",
    "decidedAt": "2026-11-24T03:15:00.000Z",
    "effects": {
      "relationshipStatus": "ENDED",
      "forfeitedActiveSessions": 9,
      "forfeitedQueuedPackage": false,
      "cancelledFutureBookingsCount": 2,
      "plansArchived": true,
      "coachSeatReleased": true
    }
  }
}
```

---

### 2.8. Nội dung Vận hành: Thực phẩm/kcal, Phòng Gym (+ QR), Thiết bị & Thư viện Bài tập (`exercises`)

| Method & Path | Role | File & Thay đổi | Audit Action |
|---|---|---|---|
| `GET /api/v1/admin/nutrition-foods` | `ADMIN` | `structured-nutrition.routes.js`: thêm `search`, `active` (`true`\|`false`), `page`, `pageSize`. | — |
| `POST /api/v1/admin/nutrition-foods` | `ADMIN` | Giữ payload `{ name, kcalPer100g (0..1000), active }`; **bổ sung ghi `admin_audit_logs` trong transaction**. | `NUTRITION_FOOD_CREATED` |
| `PATCH /api/v1/admin/nutrition-foods/:id` | `ADMIN` | Giữ quy tắc snapshot kcal: thực đơn `ACTIVE` tra cứu live khi đọc, khi `ARCHIVED` trigger `trg_freeze_nutrition_calories` chụp cố định kcal; **bổ sung ghi `admin_audit_logs` (`before`/`after`)**. | `NUTRITION_FOOD_UPDATED` |
| `GET /api/v1/gym-profile` & `PATCH /api/v1/admin/gym-profile` | Public / `ADMIN` | `catalog.routes.js`: hỗ trợ đủ `name`, `address`, `phone`, `email`, `description`, `openingHours`, `rules`, `coverMediaId`. | `GYM_PROFILE_UPDATED` |
| `GET /api/v1/admin/gym-checkin-code` & `POST /api/v1/admin/gym-checkin-code/rotate` | `ADMIN` | `gym-visits.routes.js`: **giữ nguyên** chức năng xem/in/đổi mã QR điểm danh trên trang Phòng gym. | `GYM_CHECKIN_CODE_ROTATED` |
| `GET/POST/PATCH /api/v1/admin/equipment` | `ADMIN` | `catalog.routes.js`: bổ sung `search`, `category`, `status` vào `GET /admin/equipment`; lưu `before`/`after` vào audit. | `EQUIPMENT_CREATED` / `EQUIPMENT_UPDATED` |
| `GET/POST/PATCH /api/v1/admin/exercises` | `ADMIN` | **Thêm vào phạm vi Web Admin (`catalog.routes.js`):** bổ sung `search`, `status`, `difficulty`, `equipmentId` vào `GET /admin/exercises` và join `equipmentName` để hiển thị tên thiết bị thay UUID. CRUD đầy đủ `name`, `equipmentId`, `description`, `targetMuscles[]`, `instructions`, `safetyNotes`, `difficulty`, `videoUrl`, `status`. | `EXERCISES_CREATED` / `EXERCISES_UPDATED` |
| `POST /api/v1/media/images` & `GET /api/v1/media/public/:mediaId` | `ADMIN` (chỉ `GYM`/`EQUIPMENT`) | `media.routes.js`: mở rộng `POST /media/images` cho phép `ADMIN` upload ảnh với `x-image-purpose` chỉ thuộc `['GYM', 'EQUIPMENT']` và `access_scope = 'PUBLIC'`, phục vụ `coverMediaId` phòng gym & `imageMediaId` thiết bị. **Admin tuyệt đối vẫn bị chặn đọc `PROGRESS_PHOTO`, `MEAL_PHOTO`, `MESSAGE`, `COACH_OUTCOME` chưa duyệt.** | — |

---

### 2.9. Nhật ký Hệ thống (Audit Log Viewer) & Chặn Chat Tài khoản Khóa (S5)

| Method & Path | Role | File & Chi tiết |
|---|---|---|
| `GET /api/v1/admin/audit-logs` | `ADMIN` | **Mới (`admin-audit.routes.js`):** Query `action`, `entityType`, `entityId`, `from`, `to` (`Asia/Ho_Chi_Minh`), `search`, `page`, `pageSize` (`1..100`). Trả `id`, `adminId`, `adminName`, `action`, `entityType`, `entityId`, `summary`, `metadata` (đã allowlist/redact), `createdAt`. |
| `POST /api/v1/conversations/:relationshipId/messages` | `MEMBER` \| `COACH` | **Cập nhật (`messaging.routes.js` — S5):** Trong transaction sau khi tìm hội thoại, kiểm tra `SELECT status FROM users WHERE id = $recipientId`. Nếu `status = 'DISABLED'` → trả **`403 RECIPIENT_ACCOUNT_DISABLED`** (`"Không thể gửi tin nhắn vì tài khoản người nhận đang bị khóa"`). Các endpoint đọc (`GET /conversations`, `GET /conversations/:id/messages`) vẫn hoạt động bình thường để giữ lịch sử đọc được. |

#### Ví dụ Response `GET /api/v1/admin/audit-logs?action=SIMULATED_REFUND_CREATED&page=1&pageSize=20`
```json
{
  "data": [
    {
      "id": "aud-0001-...",
      "adminId": "adm-0001-...",
      "adminName": "Meta Gym Admin",
      "action": "SIMULATED_REFUND_CREATED",
      "entityType": "COACH_LOCK_INCIDENT",
      "entityId": "inc-0001-...",
      "summary": "Hoàn tiền mô phỏng 3.783.000 ₫ cho sự cố khóa Coach",
      "metadata": {
        "refundBatchId": "bat-0001-...",
        "memberId": "m001-...",
        "coachId": "c0a1-...",
        "totalRefundAmount": 3783000,
        "reason": "Chưa có Coach thay thế phù hợp; Member chọn nhận hoàn tiền mô phỏng"
      },
      "createdAt": "2026-11-21T07:10:00.000Z"
    }
  ],
  "pagination": { "page": 1, "pageSize": 20, "totalItems": 1, "totalPages": 1 }
}
```

---

## 3. Ma trận Quyền Riêng Tư & Allowlist Dữ liệu (Role Privacy Matrix)

### 3.1. Ma trận truy cập theo vai trò (Server-Enforced)

| Nhóm dữ liệu / Endpoint | Member | Coach | Admin | Ghi chú cưỡng chế bắt buộc |
|---|---|---|---|---|
| Nhật ký tập & Biểu đồ 3 vòng (`/api/v1/journal*`, `member_journal_*`) | Đọc/Ghi (chỉ đọc khi Gym hết hạn) | **`403 FORBIDDEN`** | **`403 FORBIDDEN`** | Lọc tuyệt đối theo `req.authUser.id`; ảnh `PROGRESS_PHOTO` chỉ chủ sở hữu lấy được signed URL. |
| Nhật ký dinh dưỡng cá nhân (`/api/v1/member/nutrition*`, `member_nutrition_days`, `nutrition_guide_revisions`, `meal_logs`) | Đọc/Ghi (hôm nay VN khi Gym `ACTIVE`) | **`403 FORBIDDEN`** | **`403 FORBIDDEN`** | **Khóa phạm vi 21/11/2026:** Giữ hoàn toàn ngoài Web Admin. |
| Lịch tự tập cá nhân (`/api/v1/member/self-training-days*`) | Đọc/Ghi | **`403 FORBIDDEN`** | **`403 FORBIDDEN`** | — |
| Tiến độ V1 lịch sử (`/api/v1/progress*`, `/workout-logs`, `/body-measurements`, `/progress-photos`, `/progress-comments`) | Chỉ đọc lịch sử của mình (write `410`) | **`403 FORBIDDEN`** | **`403 FORBIDDEN`** | — |
| Trò chuyện 1–1 (`/api/v1/conversations*`, `messages`) | Đọc/Ghi (trừ khi người nhận `DISABLED` → gửi `403`) | Đọc/Ghi (trừ khi người nhận `DISABLED` → gửi `403`) | **`403 FORBIDDEN`** | Admin không bao giờ thấy nội dung hay danh sách hội thoại. |
| Cuộc gọi thoại/video (`/api/v1/calls*`, `call_logs`) | Chỉ khi quan hệ `ACTIVE` | Chỉ khi quan hệ `ACTIVE` | **`403 FORBIDDEN`** | Tự động vô hiệu khi quan hệ `PAUSED`/`ENDED`. |
| Trò chuyện AI (`/api/v1/ai-conversations*`, `ai_messages`) | Chỉ của chính mình | Chỉ của chính mình | **`403 FORBIDDEN`** | — |
| Hồ sơ sức khỏe nhạy cảm (`member_profiles`: `health_notes`, `injury_notes`, `height_cm`, `weight_kg`, `body_fat_percent`, `fitness_goal`, `dietary_preferences`, `health_declaration_completed_at`) | Đọc/Sửa của chính mình | **CHỈ khi quan hệ `ACTIVE`** (`null` khi `PAUSED` gồm `MEMBER_LOCKED`/`COACH_LOCKED`/`MEMBERSHIP_EXPIRED`; `404` khi `ENDED`) | **CẤM TUYỆT ĐỐI** (không có trong bất kỳ response/audit nào) | Kiểm tra bằng test gọi trực tiếp `/admin/users/:id`, `/admin/relationships/:id`, `/admin/dashboard`, `/admin/audit-logs`. |
| Giáo án tập & Thực đơn 7 ngày (`training_plans`, `nutrition_guides`) | Xem bản `ACTIVE` và lịch sử `ARCHIVED` của mình | Ghi khi `ACTIVE`; xem bản mình tạo ở `ARCHIVED` chỉ đọc sau `ENDED` | **Không đọc nội dung chi tiết** (chỉ thao tác lưu trữ tự động ở DB khi đóng quan hệ) | Coach mới không kế thừa giáo án cũ. |
| Dữ liệu vận hành Admin (`/api/v1/admin/*`) | **`403 FORBIDDEN`** | **`403 FORBIDDEN`** | Đọc/Ghi theo contract | Mọi endpoint `/admin/*` đều qua middleware xác thực `role === 'ADMIN'`. |

### 3.2. Danh sách trường CẤM trong Response Web Admin & `admin_audit_logs.metadata`
Server sử dụng **explicit allowlist** (chỉ `SELECT` và map trường định danh/vận hành). Tuyệt đối không bao giờ xuất hiện các khóa sau trong bất kỳ JSON nào trả cho `ADMIN` hoặc ghi vào `admin_audit_logs`:
- Bí mật & xác thực: `password`, `passwordHash`, `password_hash`, `temporaryPassword` (chỉ trả 1 lần ở response `201` của `/password-resets`, **cấm** ghi vào audit/log), `codeHash`, `accessToken`, `jwt`.
- Sức khỏe & hồ sơ nhạy cảm: `healthNotes`, `health_notes`, `injuryNotes`, `injury_notes`, `heightCm`, `weightKg`, `bodyFatPercent`, `fitnessGoal`, `dietaryPreferences`, `dateOfBirth`, `healthDeclarationCompletedAt`.
- Nội dung riêng tư: `journal`, `chestCm`, `waistCm`, `hipsCm`, `achievements`, `messages`, `messageContent`, `aiMessages`, `mealLogs`, `memberNutritionDays`, `progressPhotos`, `storageKey`.

---

## 4. Kế hoạch Migration `0029+` (Up / Down & Quy trình Phục hồi)

> **Điểm xuất phát bắt buộc:** Nhánh `feat/web-admin` sau `Bước 0a` có đủ `0001`–`0028` (**52 bảng `public`**). Toàn bộ migration Web Admin mới bắt đầu từ **`0029`** đến **`0033`** (thêm **3 bảng mới**: `coach_lock_incidents`, `simulated_refunds`, `payment_adjustments` → tổng **55 bảng `public`**).

| Số hiệu | File Migration (`.up.sql` / `.down.sql`) | Thay đổi Schema (`UP`) | Rollback (`DOWN`) & Lưu ý an toàn dữ liệu |
|---|---|---|---|
| **`0029`** | `0029_web_admin_hard_cap_and_packages.{up,down}.sql` | 1. `coach_profiles`: `UPDATE ... SET member_limit = 8 WHERE member_limit <> 8`; `ALTER COLUMN member_limit SET DEFAULT 8`; drop `coach_profiles_member_limit_check`; add `ck_coach_profiles_member_limit_fixed CHECK (member_limit = 8)`.<br>2. `coach_package_plans`: drop `coach_package_plans_code_check` & `ck_coach_package_fixed_terms`; widen `code varchar(40)` (`CONSTRAINT ck_coach_package_code_format CHECK (code ~ '^[A-Z0-9][A-Z0-9_-]{1,39}$')`), `name varchar(100)`; add `description text`, `created_at timestamptz NOT NULL DEFAULT now()`, `created_by uuid REFERENCES users(id)`.<br>3. `coach_payment_holds`: widen `plan_code varchar(40)`, `plan_name varchar(100)`, add `settled_at timestamptz` (backfill từ `created_at` cho dòng `CONSUMED`).<br>4. `coach_entitlements`: add `plan_code varchar(40)`, `plan_name varchar(100)`, `snapshot_price bigint CHECK (snapshot_price >= 0)`, `original_hold_id uuid REFERENCES coach_payment_holds(id)`, `source_entitlement_id uuid REFERENCES coach_entitlements(id)`, `close_reason varchar(30) CHECK (close_reason IN ('COMPLETED_SESSIONS','EXPIRED','EARLY_TERMINATION','TRANSFERRED','SIMULATED_REFUND'))`; backfill snapshot từ `coach_payment_holds`; drop `UNIQUE` toàn cục trên `hold_id` và đổi `hold_id` thành nullable cho bản ghi chuyển gói, thay bằng partial unique index `uq_coach_entitlement_origin_hold ON coach_entitlements (hold_id) WHERE hold_id IS NOT NULL` và `CHECK ((source_entitlement_id IS NULL) = (hold_id IS NOT NULL))`. | Gỡ các cột mới, khôi phục constraint cũ *(lưu ý: `DOWN` chỉ an toàn nếu chưa phát sinh gói ngoài 3 mã hoặc entitlement chuyển gói; trên production ưu tiên khôi phục từ `pg_dump` trước nâng cấp)*. |
| **`0030`** | `0030_coach_lock_incidents_and_freeze.{up,down}.sql` | 1. `coach_relationships`: drop `coach_relationships_pause_reason_check`; add `CHECK (pause_reason IN ('MEMBERSHIP_EXPIRED', 'COACH_LOCKED', 'MEMBER_LOCKED'))`.<br>2. `coach_entitlements`: add `frozen_at timestamptz`, `frozen_days_total integer NOT NULL DEFAULT 0 CHECK (frozen_days_total >= 0)`, `grace_days_added integer NOT NULL DEFAULT 0 CHECK (grace_days_added IN (0, 7))`; backfill `grace_days_added = CASE WHEN ends_on = original_ends_on + 7 THEN 7 ELSE 0 END`; drop `ck_coach_entitlement_dates`; add `ck_coach_entitlement_dates CHECK ((starts_on IS NULL AND original_ends_on IS NULL AND ends_on IS NULL AND frozen_at IS NULL AND frozen_days_total = 0 AND grace_days_added = 0) OR (starts_on IS NOT NULL AND original_ends_on IS NOT NULL AND ends_on IS NOT NULL AND original_ends_on = starts_on + duration_days - 1 AND ends_on = original_ends_on + frozen_days_total + grace_days_added))`.<br>3. **Tạo bảng `coach_lock_incidents`**: `id uuid PK`, `coach_id uuid NOT NULL REFERENCES users(id)`, `member_id uuid NOT NULL REFERENCES users(id)`, `relationship_id uuid NOT NULL REFERENCES coach_relationships(id)`, `active_entitlement_id uuid REFERENCES coach_entitlements(id)`, `queued_entitlement_id uuid REFERENCES coach_entitlements(id)`, `lock_reason text NOT NULL`, `locked_by uuid NOT NULL REFERENCES users(id)`, `locked_at timestamptz NOT NULL DEFAULT now()`, `frozen_started_at timestamptz`, `frozen_ended_at timestamptz`, `frozen_days_applied integer CHECK (frozen_days_applied IS NULL OR frozen_days_applied >= 0)`, `member_choice varchar(20) NOT NULL DEFAULT 'WAIT' CHECK (member_choice IN ('WAIT', 'REFUND'))`, `member_choice_at timestamptz`, `member_choice_note text`, `status varchar(30) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'RESOLVED_COACH_UNLOCKED', 'RESOLVED_TRANSFERRED', 'RESOLVED_REFUNDED', 'RESOLVED_ENDED'))`, `transfer_history_id uuid REFERENCES coach_transfer_history(id)`, `refund_batch_id uuid`, `resolved_by uuid REFERENCES users(id)`, `resolved_at timestamptz`, `created_at`, `updated_at`; partial unique index `uq_coach_lock_incident_open ON coach_lock_incidents (relationship_id) WHERE status = 'OPEN'`.<br>4. Cập nhật trigger `close_coach_entitlements()` (ghi `reason` hủy booking theo đúng `pause_reason`/`end_reason`, không ghi đè `close_reason` nếu đã đặt sẵn `'TRANSFERRED'`/`'SIMULATED_REFUND'`/`'EARLY_TERMINATION'`) và `notify_coach_package()`: (a) trên `INSERT`, bỏ qua không bắn `PACKAGE_ACTIVE`/`PACKAGE_QUEUED` khi `NEW.source_entitlement_id IS NOT NULL` (vì luồng D2 Transfer đã phát `COACH_TRANSFERRED`); (b) trên `UPDATE`, chỉ bắn `PACKAGE_EXTENDED` khi `NEW.grace_days_added > OLD.grace_days_added` (không bắn khi `ends_on` tăng do cộng ngày đóng băng D1 — luồng D1 đã phát `COACH_UNLOCKED_RESTORED`); (c) khi `NEW.status = 'ENDED'`, bỏ qua `PACKAGE_ENDED` nếu `NEW.close_reason IN ('TRANSFERRED', 'SIMULATED_REFUND')`. | Drop `coach_lock_incidents`, khôi phục trigger `0013`/`0015`, khôi phục `ck_coach_entitlement_dates` và `pause_reason` cũ. |
| **`0031`** | `0031_simulated_refunds_and_payment_adjustments.{up,down}.sql` | 1. **Tạo bảng `simulated_refunds`** (D3): `id uuid PK`, `refund_batch_id uuid NOT NULL`, `incident_id uuid NOT NULL REFERENCES coach_lock_incidents(id)`, `coach_entitlement_id uuid NOT NULL UNIQUE REFERENCES coach_entitlements(id)`, `relationship_id uuid NOT NULL REFERENCES coach_relationships(id)`, `member_id uuid NOT NULL REFERENCES users(id)`, `coach_id uuid NOT NULL REFERENCES users(id)`, `entitlement_kind varchar(10) NOT NULL CHECK (entitlement_kind IN ('ACTIVE', 'QUEUED'))`, `snapshot_price bigint NOT NULL CHECK (snapshot_price >= 0)`, `total_sessions integer NOT NULL CHECK (total_sessions > 0)`, `remaining_sessions integer NOT NULL CHECK (remaining_sessions BETWEEN 0 AND total_sessions)`, `refund_amount bigint NOT NULL CHECK (refund_amount >= 0 AND refund_amount <= snapshot_price)`, `status varchar(20) NOT NULL DEFAULT 'COMPLETED' CHECK (status = 'COMPLETED')`, `reason text NOT NULL CHECK (btrim(reason) <> '')`, `idempotency_key varchar(100) NOT NULL`, `request_hash varchar(64) NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$')`, `created_by uuid NOT NULL REFERENCES users(id)`, `created_at timestamptz NOT NULL DEFAULT now()`, `CONSTRAINT uq_simulated_refund_idempotency UNIQUE (created_by, idempotency_key, entitlement_kind)`, `CONSTRAINT ck_simulated_refund_formula CHECK ((entitlement_kind = 'QUEUED' AND remaining_sessions = total_sessions AND refund_amount = snapshot_price) OR (entitlement_kind = 'ACTIVE' AND refund_amount = (div(div(snapshot_price::numeric * remaining_sessions, total_sessions), 1000) * 1000)::bigint))`.<br>2. **Tạo bảng `payment_adjustments`** (D6): `id uuid PK`, `payment_id uuid NOT NULL UNIQUE REFERENCES payments(id)`, `member_id uuid NOT NULL REFERENCES users(id)`, `affected_membership_id uuid NOT NULL REFERENCES member_memberships(id)`, `adjustment_type varchar(30) NOT NULL DEFAULT 'VOID_REVERSAL' CHECK (adjustment_type = 'VOID_REVERSAL')`, `reversed_amount bigint NOT NULL CHECK (reversed_amount >= 0)`, `previous_membership_status varchar(20) NOT NULL`, `previous_end_date date NOT NULL`, `restored_end_date date`, `reason text NOT NULL CHECK (btrim(reason) <> '')`, `idempotency_key varchar(100) NOT NULL`, `request_hash varchar(64) NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$')`, `created_by uuid NOT NULL REFERENCES users(id)`, `created_at timestamptz NOT NULL DEFAULT now()`, `CONSTRAINT uq_payment_adjustment_idempotency UNIQUE (created_by, idempotency_key)`. | Drop `payment_adjustments` và `simulated_refunds`. |
| **`0032`** | `0032_early_termination_v2_disputes.{up,down}.sql` | Mở rộng `coach_termination_requests` (D5):<br>1. Thêm cột `requested_by_user_id uuid REFERENCES users(id)`, `requested_by_role varchar(10) CHECK (requested_by_role IN ('MEMBER', 'COACH'))`, `counterparty_user_id uuid REFERENCES users(id)`, `counterparty_decision varchar(20) CHECK (counterparty_decision IN ('ACCEPTED', 'REJECTED'))`, `counterparty_reason text`, `counterparty_decided_at timestamptz`, `response_deadline_at timestamptz`, `disputed_at timestamptz`, `escalation_reason varchar(30) CHECK (escalation_reason IN ('COUNTERPARTY_REJECTED', 'TIMEOUT_72H'))`.<br>2. Backfill dữ liệu lịch sử: `requested_by_user_id = coach_id`, `requested_by_role = 'COACH'`, `counterparty_user_id = r.member_id`, `response_deadline_at = created_at + interval '72 hours'`; chuyển mọi dòng cũ đang `PENDING` (nếu có) sang `DISPUTED` (`disputed_at = now()`, `escalation_reason = 'TIMEOUT_72H'`). Sau backfill đặt `NOT NULL` cho `requested_by_user_id`, `requested_by_role`, `counterparty_user_id`, `response_deadline_at`. **Giữ nguyên cột `coach_id` (= `coach_relationships.coach_id`) và FK `fk_termination_relationship_coach` cho mọi dòng mới (kể cả khi `requested_by_role = 'MEMBER'`) để bảo toàn toàn vẹn tham chiếu.**<br>3. Mở rộng kiểu và mặc định cột `status`: `ALTER TABLE coach_termination_requests ALTER COLUMN status TYPE varchar(30), ALTER COLUMN status SET DEFAULT 'PENDING_COUNTERPARTY';` rồi cập nhật `status CHECK` thành `('PENDING_COUNTERPARTY', 'ACCEPTED', 'DISPUTED', 'ADMIN_APPROVED', 'ADMIN_REJECTED', 'CANCELLED', 'APPROVED', 'REJECTED')` (giữ `'APPROVED'`/`'REJECTED'` cho lịch sử đã đóng); cập nhật `ck_termination_state_details` (yêu cầu `admin_note` không rỗng khi `ADMIN_APPROVED`/`ADMIN_REJECTED`); đổi unique index `uq_termination_pending_relationship` thành `uq_termination_open_relationship ON coach_termination_requests (relationship_id) WHERE status IN ('PENDING_COUNTERPARTY', 'DISPUTED')`. | Drop các cột mới, khôi phục `ALTER COLUMN status SET DEFAULT 'PENDING'`, `TYPE varchar(20)` và constraint/index `0002`. |
| **`0033`** | `0033_web_admin_reporting_and_audit_indexes.{up,down}.sql` | Thêm index phục vụ tìm kiếm/lọc/phân trang danh sách >100 bản ghi & báo cáo Dashboard theo `Asia/Ho_Chi_Minh`:<br>- `ix_audit_created_desc ON admin_audit_logs (created_at DESC, id DESC)`<br>- `ix_audit_action_created ON admin_audit_logs (action, created_at DESC)`<br>- `ix_payments_confirmed_success ON payments (confirmed_at DESC) WHERE status = 'SUCCESS'`<br>- `ix_coach_holds_consumed_settled ON coach_payment_holds (settled_at DESC) WHERE status = 'CONSUMED'`<br>- `ix_coach_incidents_status_created ON coach_lock_incidents (status, created_at DESC)`<br>- `ix_simulated_refunds_created_at ON simulated_refunds (created_at DESC, id DESC)`<br>- `ix_payment_adjustments_created_at ON payment_adjustments (created_at DESC, id DESC)`<br>- `ix_termination_disputed_created ON coach_termination_requests (disputed_at DESC) WHERE status = 'DISPUTED'`<br>- `ix_nutrition_foods_name_lower ON nutrition_foods (lower(name))` | Drop toàn bộ index tạo ở `0033`. |

### 4.1. Kế hoạch chuyển tiếp luồng cũ & kiểm soát rủi ro phát hành (Release & Rollback Runbook)
1. **Sao lưu bắt buộc trước mọi nâng cấp:** `pg_dump --dbname=$env:DATABASE_URL --format=custom --file=meta_gym_pre_0029_$(Get-Date -Format yyyyMMdd_HHmm).dump`.
2. **Xác minh mốc DB hiện tại (tránh va chạm production `0023` vs `0028`):**
   - Chạy `SELECT count(*) FROM pg_tables WHERE schemaname = 'public';` và kiểm tra tồn tại `payments.renewed_membership_id`, `member_nutrition_days`.
   - Áp các migration còn thiếu (`0024..0028` nếu chưa có), chạy `schema_assertions.sql` (52 bảng), sau đó mới áp `0029..0033` và `schema_assertions.sql` mới (**55 bảng**; gỡ `ck_coach_package_fixed_terms` đã bỏ ở `0029` và thay bằng các constraint mới `ck_coach_profiles_member_limit_fixed`, `ck_coach_package_code_format`, `uq_simulated_refund_idempotency`, `ck_simulated_refund_formula`, `uq_payment_adjustment_idempotency`, `uq_coach_lock_incident_open`, `uq_termination_open_relationship`).
3. **Khóa quyền Supabase sau migration (bắt buộc):**
   ```sql
   REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
   REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
   REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon, authenticated;
   ```
   Xác nhận `has_table_privilege('anon', 'public.simulated_refunds', 'SELECT') = false` và tương tự cho `coach_lock_incidents`, `payment_adjustments`, `admin_audit_logs`.
4. **Chiến lược Rollback:**
   - Trên môi trường test/staging sạch: chạy tuần tự `0033.down.sql` → `0029.down.sql` để xác minh tính khả nghịch.
   - Trên production (khi đã có dữ liệu thật hoặc nếu phát sinh lỗi giữa migration): **không chạy `down.sql` phá dữ liệu**, mà dừng traffic/rollback bản Render backend trước đó và phục hồi bằng `pg_restore` từ bản sao lưu `pg_dump` trước cửa sổ bảo trì.
5. **Chuyển tiếp luồng cũ (`coach_requests`, giáo án V1, `AdminHomePage` Flutter):**
   - Bảng `coach_requests` giữ lại chỉ đọc ở DB để bảo toàn FK lịch sử `coach_relationships.source_request_id`; mọi endpoint ghi (`POST /coach-requests`, `PATCH /coach/requests/:id`, `DELETE /coach-requests/:id`, `POST /relationships/:id/terminations`) trả `410 LEGACY_WORKFLOW_RETIRED`.
   - `GET /admin/dashboard` bỏ `pendingCoachRequests`.
   - Flutter gỡ hoàn toàn `mobile-app/lib/features/admin/` CRUD và chặn `UserRole.admin` tại `app_router.dart` bằng màn thông báo *"Tài khoản Quản trị viên chỉ sử dụng trên Web Admin"* kèm nút đăng xuất.
