# Meta Gym — Kế hoạch hoàn thiện luồng nghiệp vụ và API backend

> Cập nhật: 22/10/2026. Mốc code để lập kế hoạch: `origin/main` tại `e8394dc`.
> Phạm vi hiện tại: PostgreSQL, backend Node.js, API REST, kiểm thử nghiệp vụ và tài liệu API để chuẩn bị cho việc thiết kế frontend sau này.

## Ranh giới công việc

- Tập trung vào hành vi backend: trạng thái, quyền truy cập, transaction, dữ liệu trả về, lỗi và các trường hợp gửi yêu cầu lặp hoặc đồng thời.
- Chỉ bổ sung hoặc sửa API khi kiểm thử và API contract cho thấy điểm thiếu hoặc sai. Backend MVP đã có nhiều route; sự tồn tại của route chưa đủ để đánh dấu luồng hoàn thành.
- Không tạo trang Flutter/Dart, Admin Web, thiết kế màn hình hay APK trong các task đang hoạt động. Các phần frontend đã có trên `main` được giữ nguyên; việc thiết kế tiếp sẽ có kế hoạch riêng theo quyết định của chủ dự án.
- Thanh toán `MOCK_QR`, media local và các provider AI/email/RTC chưa cấu hình chỉ dùng development/test. Tích hợp thật và triển khai production cần một đợt công việc riêng.
- `docs/requirements/api-contract.md` là hợp đồng API gốc. Khi cần đổi contract, ghi rõ request/response, mã lỗi và tác động đến client trước khi sửa; tránh phá vỡ client hiện có nếu không cần thiết.

## Cách làm và điều kiện hoàn thành

1. Đọc `AGENTS.md`, task hiện tại, API contract và test hiện có. Dùng checkout hiện tại; giữ nguyên thay đổi chưa commit. Tạo nhánh `codex/<mã-task>-<tên-ngắn>` từ `main` đã đồng bộ cho mỗi task.
2. Viết test cho trường hợp còn thiếu trước khi đổi logic. Ưu tiên test API với PostgreSQL thật trên `TEST_DATABASE_URL` tách biệt. Dùng dữ liệu test có thể dọn dẹp; không reset database đang có dữ liệu.
3. Chạy `npm run check` và `npm test` trong `backend/`; xác nhận test PostgreSQL thực sự chạy, không bị skip vì thiếu `TEST_DATABASE_URL`. Khi task chạm luồng chạy thực tế, chạy thêm health và `npm run smoke` trên database demo local.
4. Review correctness, readability, architecture, security, performance; kiểm tra diff và không commit `.env`, secret, token, media, `node_modules` hoặc dữ liệu PostgreSQL. Chỉ đánh dấu task hoàn thành khi tiêu chí và test tương ứng đạt. Báo kết quả từng task bằng tiếng Việt trước khi chuyển task kế tiếp.
5. Sau checkpoint, chạy lại bộ test liên quan và review hợp đồng API. Việc commit, push hoặc merge thực hiện theo yêu cầu của chủ dự án và quy trình Git trong `AGENTS.md`.

Trong môi trường Codex Cloud, source `/workspace/setup-metagym/runtime.sh` trước khi chạy lệnh. Nếu shell đã export `JWT_SECRET`, chạy test trong subshell `(unset JWT_SECRET; npm test)` để test trường hợp thiếu secret hoạt động đúng; giữ `TEST_DATABASE_URL`.

## Trạng thái đã có trước kế hoạch này

| Task | Kết quả đã ghi nhận trên `main` | Liên quan phạm vi hiện tại |
| --- | --- | --- |
| T01 | Đối chiếu checklist với code | Tài liệu nền |
| T02 | Tạo demo seed Admin, Coach, Member | Dữ liệu kiểm thử API |
| T03 | Tạo smoke test health, đăng nhập và API ba vai trò | Cổng kiểm tra backend |
| T04 | Chuẩn hóa cấu trúc, router và cấu hình Flutter | Lịch sử frontend, ngoài phạm vi hiện tại |
| T05 | API client và lỗi dùng chung trong Flutter | Lịch sử frontend, ngoài phạm vi hiện tại |
| T06 | Lưu token và quản lý phiên trong Flutter | Lịch sử frontend, ngoài phạm vi hiện tại |
| T07 | Luồng đăng nhập/đăng ký trong Flutter | Lịch sử frontend, ngoài phạm vi hiện tại |
| T08 | Hồ sơ và khôi phục mật khẩu trong Flutter | Lịch sử frontend, ngoài phạm vi hiện tại |
| T09 | Trang Member và danh mục trong Flutter | Lịch sử frontend, ngoài phạm vi hiện tại |
| T10 | Gói tập và thanh toán QR mô phỏng trong Flutter | Lịch sử frontend, ngoài phạm vi hiện tại |

T01–T10 đã được đánh dấu hoàn thành trong phiên bản kế hoạch trước tại commit `e8394dc`; bảng này chỉ ghi lại lịch sử, không khẳng định các màn hình đã qua kiểm thử end-to-end với backend thật. Backend Node.js, schema và nhiều API nghiệp vụ đã tồn tại từ trước T11. Không suy ra phần API của T11–T15 đã đạt chỉ từ việc có route hoặc có một test tổng hợp.

## Thứ tự công việc backend

```text
T11 Chọn Coach ───────────────┬─> T12 Giáo trình/dinh dưỡng/lịch
                              └───────────────────┐
T13 Nhật ký ──> T14 Ảnh/tiến độ ──────────────────┴─> T15 Nhắn tin
T11–T15 ──> T16 Luồng liên thông ──> T17 Bảo mật & lỗi ──> T18 Chốt API contract
```

T13 có thể làm khi T11/T12 đang được review vì dùng dữ liệu và route khác; không triển khai song song trên cùng checkout nếu có nguy cơ ghi đè. T15 cần quan hệ Coach từ T11 và media ảnh từ T14. Không đánh dấu task sau hoàn thành khi dependency chưa đạt.

### T11 — Kiểm chứng API chọn Coach và vòng đời quan hệ

**Trạng thái:** Hoàn thành ngày 22/10/2026. Đối chiếu contract, route và schema; không phát hiện sai lệch cần sửa logic. Bổ sung `backend/test/coaching-lifecycle.postgres.test.js` cho membership, quyền sở hữu, gửi trùng/đồng thời, hủy, từ chối, chấp nhận, hết suất và lịch sử sau kết thúc. Backend check và 50/50 test PostgreSQL/đơn vị đạt, không skip; smoke đạt 7/7.

**API hiện có:** `GET /coaches`, `POST /coach-requests`, `GET /coach-requests/me`, `DELETE /coach-requests/:requestId`, `PATCH /coach/requests/:requestId`, `GET /relationships/me`, các API Coach/Admin liên quan trong `backend/src/routes/coaching.routes.js`.

**Công việc:** Đối chiếu contract với route và dữ liệu thật. Kiểm tra Member có/không có membership đang hiệu lực; một yêu cầu `PENDING` hoặc quan hệ `ACTIVE`/`PAUSED`; hủy, chấp nhận, từ chối kèm lý do; giới hạn suất Coach; yêu cầu đồng thời; dữ liệu lịch sử sau kết thúc/chuyển Coach. Bổ sung test riêng cho khoảng trống, sửa logic nếu test chứng minh lỗi.

**Hoàn thành khi:** Một Member không thể có hai yêu cầu chờ hoặc hai Coach hiện hành; người sai vai trò/chủ thể không đọc hay đổi yêu cầu; trạng thái và suất Coach nhất quán sau mọi chuyển trạng thái; response và mã lỗi đúng contract.

**Kiểm tra:** Test API với PostgreSQL thật cho gửi, gửi trùng/đồng thời, hủy, từ chối, chấp nhận, hết suất và quan hệ hiện tại/lịch sử. Chạy backend check/test và smoke khi sửa route.

**Phụ thuộc:** Gói tập/membership và demo seed đã có từ T02/T03. **Quy mô:** M.

### T12 — Kiểm chứng API giáo trình, dinh dưỡng và buổi tập

**Trạng thái:** Hoàn thành ngày 22/10/2026. Test PostgreSQL tái hiện và sửa lỗi công bố đồng thời trả `500`, cùng lỗi công bố bản nháp thuộc quan hệ Coach cũ. Đã kiểm tra quyền xem/sửa bản nháp, snapshot, lịch sử, trạng thái quan hệ và thời gian buổi tập. Backend check và 50/50 test đạt, không skip; smoke đạt 7/7. Contract đã ghi rõ quy tắc công bố.

**API hiện có:** `/training-plans`, `/nutrition-guides`, `/training-sessions` trong `backend/src/routes/training.routes.js` và `sessions.routes.js`.

**Công việc:** Kiểm tra Coach chỉ tạo/sửa nội dung cho Member đang phụ trách; giáo trình/hướng dẫn `DRAFT` không lộ cho Member; công bố lưu phiên bản cũ và chỉ một bản `ACTIVE`; buổi tập cho phép đúng chuyển trạng thái, thời gian và quyền xem. Test Member có/không có quan hệ và Coach khác/Coach cũ.

**Hoàn thành khi:** Đọc bản hiện hành, lịch sử và chi tiết nhất quán; nội dung chưa công bố hoặc thuộc người khác bị chặn; lịch tập không nhận chuyển trạng thái trái phép. Mọi sửa contract được ghi vào tài liệu.

**Kiểm tra:** Test với PostgreSQL thật cho draft → publish → archive, dữ liệu snapshot, lịch buổi tập và ma trận quyền. Chạy backend check/test.

**Phụ thuộc:** T11 cung cấp quan hệ Coach hợp lệ để kiểm thử. **Quy mô:** M.

### T13 — Kiểm chứng API nhật ký tập luyện và ăn uống

**Trạng thái:** Hoàn thành ngày 22/10/2026. Bổ sung test PostgreSQL cho validation ngày, thời lượng, bài tập, loại bữa và ảnh không hợp lệ; membership hết hạn, quyền sửa của Member, Coach và Admin, bài tập sau cập nhật, cùng phân trang ổn định khi trùng thời điểm. Không phát hiện lỗi route cần sửa. Backend check và 50/50 test đạt, không skip; contract ghi rõ thứ tự và giới hạn offset pagination.

**API hiện có:** `GET/POST/PATCH /workout-logs` và `/meal-logs` trong `backend/src/routes/progress.routes.js`.

**Công việc:** Kiểm tra validation ngày, thời lượng, bài tập, loại bữa ăn và dữ liệu ảnh liên quan; điều kiện membership khi ghi/sửa; phân trang ổn định; ownership của Member; quyền đọc của Coach hiện tại so với Coach khác hoặc quan hệ đã kết thúc.

**Hoàn thành khi:** Không thể tạo/sửa nhật ký sai dữ liệu hoặc sửa của người khác; danh sách trả pagination đúng, không lặp/mất dữ liệu trong trường hợp kiểm thử; dữ liệu bài tập được lưu và trả nhất quán.

**Kiểm tra:** Test API create/edit/list nhiều trang và trường hợp 401/403/404/422 phù hợp contract; chạy backend check/test.

**Phụ thuộc:** T02/T03 và membership test fixture. Độc lập với T11/T12 về thứ tự triển khai. **Quy mô:** M.

### T14 — Kiểm chứng API số đo, ảnh và thống kê tiến độ

**Trạng thái:** Hoàn thành ngày 22/10/2026. Bổ sung test PostgreSQL cho số đo/biểu đồ rỗng và nhiều điểm, ảnh tiến độ đúng `READY`/purpose/owner, quyền của Coach, PNG/JPEG, URL có chữ ký và hết hạn, lỗi lưu trữ. Sửa upload quá 5 MB trả HTML thành JSON `413 PAYLOAD_TOO_LARGE`; cập nhật API contract. Backend check và 50/50 test đạt, không skip; smoke đạt 7/7.

**API hiện có:** `/body-measurements`, `/progress-photos`, `/progress/me/summary`, `/progress/me/charts`, `/media/images` và access URL trong `progress.routes.js`, `media.routes.js`.

**Công việc:** Kiểm tra số đo/đơn vị/ngày và dữ liệu biểu đồ rỗng, một điểm, nhiều điểm; upload chỉ PNG/JPEG trong giới hạn hiện hành, đúng `purpose` và owner; ảnh phải `READY` trước khi gắn; URL ảnh có hạn và chỉ cấp cho chủ sở hữu/Coach còn quyền. Local media dùng để kiểm thử, không xem đó là lưu trữ production.

**Hoàn thành khi:** Ảnh của người khác hoặc sai purpose không thể gắn/xem; biểu đồ không lộ dữ liệu chéo, dùng đúng thời gian/đơn vị; lỗi upload/storage trả mã và trạng thái rõ ràng.

**Kiểm tra:** Test API upload thành công/thất bại, quyền mở URL và hết hạn, CRUD số đo/ảnh, summary/charts; chạy backend check/test.

**Phụ thuộc:** T13 cho dữ liệu tiến độ và quyền nhật ký; T11 cho quan hệ Coach khi kiểm thử quyền xem. **Quy mô:** M.

### T15 — Kiểm chứng API nhắn tin Member–Coach

**Trạng thái:** Hoàn thành ngày 22/10/2026. Bổ sung test PostgreSQL cho quyền hai bên/người ngoài/Admin, tin ảnh đúng owner và `READY`, gửi đồng thời/retry, phân trang, unread/read cursor, quan hệ `PAUSED`/`ENDED`. Test tái hiện và sửa race gửi tin trong transaction kết thúc quan hệ. Backend check và 51/51 test đạt, không skip; smoke đạt 7/7. Contract đã ghi rõ idempotency và quy tắc trạng thái.

**API hiện có:** `/conversations`, `/conversations/:relationshipId/messages`, `/conversations/:relationshipId/read-state` trong `backend/src/routes/messaging.routes.js`.

**Công việc:** Kiểm tra chỉ hai người trong quan hệ xem hội thoại; chỉ quan hệ `ACTIVE` được gửi; `PAUSED`/`ENDED` chỉ đọc lịch sử; tin ảnh phải là media `MESSAGE` đã sẵn sàng và thuộc người gửi; retry dùng cùng `clientMessageId` phải trả cùng một tin; cùng ID nhưng nội dung khác phải lỗi; read cursor không lùi.

**Hoàn thành khi:** Phân trang và số tin chưa đọc nhất quán, gửi lặp không tạo bản ghi mới, người ngoài/Admin không xem được nội dung, quan hệ đã kết thúc không gửi được tin mới.

**Kiểm tra:** Test API hai tài khoản và người ngoài, gửi đồng thời/retry, phân trang, read-state và tin ảnh với PostgreSQL thật; chạy backend check/test.

**Phụ thuộc:** T11 và T14. **Quy mô:** M.

### Checkpoint B — Năm luồng API Member–Coach

- [x] T11–T15 đạt tiêu chí với test PostgreSQL thực sự chạy, không skip.
- [x] `npm run check`, `npm test` đạt; sửa code backend thì health và smoke test đạt.
- [x] Đã review quyền Member/Coach/Admin, dữ liệu riêng tư và diff của T11–T15 trước bước gộp.

### T16 — Kiểm thử luồng nghiệp vụ liên thông bằng API thật

**Trạng thái:** Chưa thực hiện.

**Công việc:** Tự động hóa một kịch bản trên database test riêng: đăng ký/đăng nhập → mua gói `MOCK_QR` → chọn Coach → Coach chấp nhận → công bố giáo trình/dinh dưỡng → tạo buổi tập → Member ghi nhật ký/ảnh/số đo → hai bên nhắn tin → kết thúc hoặc chuyển quan hệ. Kiểm tra trạng thái và dữ liệu sau từng bước, kể cả gọi lại thao tác idempotent. Dùng fixture sạch và dọn dữ liệu; không dựa vào màn hình Flutter hay tài khoản production.

**Hoàn thành khi:** Kịch bản chạy lặp được trên PostgreSQL test; các trường hợp lỗi trọng yếu có assertion; không dùng test giả để thay thế API thật.

**Kiểm tra:** `npm run check`, `npm test`, health và smoke test với demo local. **Phụ thuộc:** T11–T15. **Quy mô:** M.

### T17 — Rà soát bảo mật, lỗi và vòng đời dữ liệu của API

**Trạng thái:** Chưa thực hiện.

**Công việc:** Kiểm tra ma trận quyền, IDOR bằng cách đổi ID, trạng thái tài khoản bị khóa, token cũ sau đổi mật khẩu, hết hạn membership, Coach cũ sau kết thúc/chuyển quan hệ; validation, phân trang và lỗi provider chưa cấu hình. Xác nhận log không in token, mật khẩu, mã khôi phục; CORS/secret production cần cấu hình riêng trước khi triển khai Internet.

**Hoàn thành khi:** Không còn lỗi nghiêm trọng hoặc cao trong phạm vi backend MVP; các giới hạn/dependency bên ngoài được ghi rõ, không mô tả API 503 là tích hợp thật đã hoạt động.

**Kiểm tra:** Test hồi quy backend cho từng lỗi phát hiện, review code và chạy đầy đủ backend check/test. **Phụ thuộc:** T16. **Quy mô:** M.

### T18 — Chốt tài liệu API để frontend tự thiết kế

**Trạng thái:** Chưa thực hiện.

**Công việc:** Đối chiếu `docs/requirements/api-contract.md` với route/test thực tế; ghi rõ endpoint, vai trò, request/response mẫu, mã lỗi, pagination, timezone/ngày, quy tắc idempotency và media URL. Ghi rõ môi trường `MOCK_QR`, media local và provider 503. Tạo checklist tích hợp để frontend tự quyết định giao diện mà không đoán quy tắc backend.

**Hoàn thành khi:** Một người làm frontend có thể gọi từng luồng chỉ từ tài liệu và tài khoản test; mọi khác biệt tài liệu/code đã giải quyết hoặc ghi thành issue cụ thể. Không cần tạo màn hình để đóng task này.

**Kiểm tra:** Review contract ↔ route ↔ test cho T11–T17, chạy backend check/test lần cuối. **Phụ thuộc:** T17. **Quy mô:** M.

### Checkpoint cuối — Backend sẵn sàng cho frontend

- [ ] T11–T18 có bằng chứng test và review, không chỉ có route tồn tại.
- [ ] Schema assertions, backend check/test và smoke test API đạt; ghi rõ số test pass/fail/skip.
- [ ] API contract khớp code về quyền, trạng thái, response, lỗi và dữ liệu riêng tư.
- [ ] Mọi tích hợp mock/chưa cấu hình được ghi rõ để frontend không hiểu nhầm là production.

## Phân chia công việc gợi ý khi có nhóm

| Người phụ trách | Task | Trọng tâm review chéo |
| --- | --- | --- |
| Backend nghiệp vụ Member–Coach | T11–T12 | Transaction, suất Coach, công bố nội dung |
| Backend tiến độ và giao tiếp | T13–T15 | Ownership, phân trang, media, idempotency |
| QA và hợp đồng API | T16–T18 | Luồng liên thông, ma trận quyền, tài liệu |

Thứ tự phụ thuộc ở trên vẫn áp dụng nếu các thành viên cùng làm. Mỗi task dùng nhánh riêng và review trước khi gộp; không dùng chung database test có dữ liệu đang thay đổi khi chạy song song.

## Để dành cho giai đoạn sau

- Chủ dự án quyết định thiết kế và thứ tự màn hình Flutter/Admin Web. Code Flutter T04–T10 hiện có được xem là lịch sử phát triển, không quyết định thiết kế tương lai.
- Email thật, OpenAI, RTC, object storage, staging/production, CI, APK và demo trên điện thoại cần kế hoạch riêng sau khi API contract được chốt. Không lấy việc có adapter hoặc endpoint làm bằng chứng dịch vụ thật hoạt động.
- Phiên bản kế hoạch cũ (T11–T36 thiên về Flutter và triển khai production) vẫn xem được trong Git history trước lần sửa file này; các task đó không còn là backlog đang thực hiện của giai đoạn backend.
