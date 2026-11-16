# Meta Gym — Member và Coach, đặc tả V2

Nguồn quyết định: `C:\Users\thong\Downloads\MetaGym_BanDacTa.pdf`, ngày 13/11/2026. Tài liệu này ghi lại yêu cầu để triển khai trong repository. Các quy tắc V2 dưới đây thay thế phần tương ứng trong `confirmed-workflows.md` và `api-contract.md` trước đây; các API cũ chưa được xem là tương thích cho đến khi có test chứng minh.

## Quy tắc sản phẩm đã chốt

- Một Member có tối đa một Coach hiện hành. Coach có tối đa 8 Member, tính cả quan hệ `PAUSED` và slot giữ thanh toán. Việc xem hồ sơ/lịch Coach không giữ khung giờ.
- Thuê Coach yêu cầu gói Gym `ACTIVE`. Member chọn một trong ba gói Coach (10 buổi/30 ngày, 20 buổi/60 ngày, 30 buổi/90 ngày), thanh toán mô phỏng trực tiếp, không gửi yêu cầu chờ Coach duyệt. Bắt đầu thanh toán giữ một slot tối đa 15 phút; xác nhận thanh toán kiểm tra lại công suất trong transaction. Hủy/thất bại/hết hạn trả slot.
- Trước khi giữ suất thanh toán gói Coach, Member phải hoàn thành khai báo thể trạng trong hồ sơ: chiều cao, cân nặng, có/không có bệnh nền và chấn thương; nếu có phải mô tả. Body fat và mục tiêu tập luyện có thể để trống. Khai báo được tái sử dụng và có thể cập nhật. Chỉ Coach đang phụ trách với quan hệ `ACTIVE` được xem để lên giáo án.
- Mỗi buổi Coach dài 90 phút, một Coach phục vụ một Member; tối đa một buổi/Member/ngày. Coach có lịch cố định ít nhất 6 ngày/tuần và 4 khung/ngày. Member tự đặt giờ trống, server chống đặt trùng. Đặt lịch không tự kéo dài gói.
- Member hủy/đổi trước ít nhất 12 giờ không trừ buổi. Dưới 12 giờ hoặc vắng không lý do trừ một lần. Coach hủy có lý do không trừ buổi. Coach xác nhận hoàn thành mới trừ một lần. Buổi đã đặt có trạng thái `BOOKED`, `COMPLETED`, `CANCELLED` cùng người/lý do/thời điểm/cờ trừ lượt.
- Gói Coach kết thúc khi hết buổi hoặc hết thời hạn gốc cộng tối đa một lần 7 ngày khi còn buổi. Gói chờ `QUEUED` tối đa một/Member; kích hoạt khi gói hiện hành kết thúc và giữ quan hệ. Nếu gói Gym hết hạn, quan hệ `PAUSED` vẫn giữ slot; thời hạn gói Coach vẫn chạy. Chat vẫn hoạt động.
- Chat 1–1 giữa Member và bất kỳ Coach nào, không cần mua gói và tiếp tục sau `PAUSED`/`ENDED`. Gọi thoại/video vẫn chỉ giữa hai bên có quan hệ `ACTIVE`. Admin không đọc nội dung chat.
- Một giáo án hiện hành của Coach hiện tại gồm tập luyện và thực đơn dinh dưỡng 7 ngày, ba bữa/ngày, món/gram, kcal tính từ danh mục thực phẩm. Coach lưu là Member thấy ngay; không có nháp/công bố/phiên bản trong quan hệ hiện hành. Sau kết thúc, nội dung quan hệ cũ chỉ đọc. Coach mới không kế thừa giáo án cũ.
- Nhật ký tập của Member là riêng tư: tối đa một bản/ngày theo ngày ghi; tối đa ba ảnh; ba số đo tùy chọn (ngực, eo, mông); danh sách thành tích tự do không giới hạn, mỗi mục tên và kết quả. Member được xem/sửa/xóa; Coach/Admin không được truy cập nhật ký, ảnh, số đo hoặc biểu đồ. Nhật ký chỉ đọc khi gói Gym hết hạn. Biểu đồ ba vòng nằm trong trang Nhật ký, chỉ dùng ngày có số đo tương ứng. Nhật ký không trừ buổi Coach.
- Không có nhật ký ăn, module tiến độ tách riêng hoặc màn Coach theo dõi tiến độ. Thông báo trong app cho các mốc gói và lịch; không cần push notification trong MVP.

## Những điều kiện kỹ thuật phải chứng minh

1. Thuật toán công suất phải xét lịch đã đặt, buổi đã bán chưa đặt và gói `QUEUED` có thể kích hoạt sớm; không hứa mọi khung giờ người dùng muốn. Kiểm thử giao dịch đồng thời khi giữ slot 15 phút và đặt cùng khung 90 phút.
2. Quy tắc hủy dưới 12 giờ và hoàn thành phải trừ lượt đúng một lần, kể cả request lặp/đồng thời. Mọi đường kết thúc quan hệ phải giải phóng slot, hủy lịch tương lai và lưu giáo án cũ, nhưng giữ chat.
3. Quyền riêng tư phải được cưỡng chế ở route, truy vấn media và URL truy cập ảnh, không chỉ ở Flutter. Test Member/Coach/Admin/người ngoài và quan hệ `ACTIVE`, `PAUSED`, `ENDED`.
4. Migrations phải bảo toàn lịch sử hiện có và có rollback. API và Flutter phải chuyển cùng lúc theo từng luồng; route cũ không được âm thầm cho phép nghiệp vụ đã bỏ.

## Những điểm cần quy định chính xác khi viết code

- Gói `QUEUED` kích hoạt khi gói hiện tại kết thúc do hết buổi hoặc hết hạn; nếu Gym đã hết hạn thì quan hệ tiếp tục `PAUSED` và thời hạn gói Coach vẫn chạy theo quy tắc PDF. UI phải báo điều này trước khi mua.
- Mốc 12 giờ tính bằng thời điểm server tại `Asia/Ho_Chi_Minh`, chính xác tới giây. Một lịch bị hủy có trường `charged_session`/`charged_at`; không dựa vào số lần gọi API.
- Bản ghi nhật ký dùng ngày server tại `Asia/Ho_Chi_Minh` khi tạo. Sửa không đổi ngày nhật ký. Điều này ngăn tạo hai bản trong cùng ngày bằng cách gửi ngày tùy ý.
- Việc thay kcal/100g cập nhật ước tính cho giáo án hiện hành khi đọc; lúc lưu vào lịch sử cần chụp giá trị để nội dung đã lưu không đổi.

## Trạng thái mã khi bắt đầu V2

| Vùng | Trạng thái cũ cần thay |
|---|---|
| Database | `coach_requests` và quan hệ từ yêu cầu; `conversations` khóa theo `relationship_id`; chưa có gói Coach, slot giữ, lịch làm việc hoặc danh mục thực phẩm; nhật ký cũ gồm meal/weight/ảnh và comment Coach |
| Backend | Có API Coach chấp nhận/từ chối, Coach tạo lịch, Coach đọc/nhận xét tiến độ, chat chỉ khi quan hệ `ACTIVE` |
| Flutter | Chọn Coach theo yêu cầu duyệt; Coach có màn yêu cầu và tiến độ; Member có nhật ký ăn, số đo/ảnh/tiến độ tách riêng |
| Admin | Quản lý gói Gym và quan hệ kiểu cũ; chưa có quản trị gói Coach/giá thực phẩm |

## Thứ tự triển khai

1. Quyền riêng tư: chặn Coach/Admin đọc/nhận xét nhật ký, chặn lấy URL ảnh; cập nhật UI/contract và test.
2. Schema V2 cho gói Coach, giá tại thời điểm mua, slot giữ, lịch Coach, buổi đặt, thực phẩm/giáo án, nhật ký riêng tư; migration thử trên database test biệt lập.
3. Thuê Coach: giao dịch giữ slot, thanh toán mô phỏng, công suất, gói chờ, vòng đời quan hệ; test đồng thời.
4. Lịch 90 phút: Coach lập/khóa giờ, Member đặt/đổi/hủy, trừ lượt idempotent, thông báo trong app.
5. Chat độc lập với quan hệ; quyền gọi vẫn `ACTIVE`.
6. Giáo án tập + thực đơn 7 ngày; dữ liệu kcal và lịch sử chỉ đọc.
7. Nhật ký Member một bản/ngày, ảnh và biểu đồ ba vòng; chuyển dữ liệu cũ khi có thể.
8. Flutter Member/Coach và Admin theo API mới; kiểm thử luồng liên thông, quyền và giao diện.

Mỗi bước chỉ được đánh dấu hoàn thành khi code, migration, test và giao diện liên quan khớp nhau. Không dùng kết quả test cũ để xác nhận V2.

## Trạng thái triển khai hiện tại

- Migration `0012` thêm API giữ suất 15 phút `POST /coach-payment-holds` (Member có gói Gym còn hạn, gửi mã Coach, mã gói và header `Idempotency-Key` dạng UUID) và hủy `POST /coach-payment-holds/:id/cancel`. Giá được lưu khi giữ suất.
- Migration `0013` thêm gói Coach và đặt lịch. Tích hợp thanh toán gọi `settleCoachHold(database, holdId, { paid, amount })` ở máy chủ sau khi xác minh giao dịch. `amount` là số nguyên VND khớp giá đã giữ. Gọi lặp thành công trả cùng mã gói. Khi thất bại hàm trả trạng thái và lý do để tầng thanh toán xử lý giao dịch. Endpoint `POST /coach-payment-holds/:id/mock-confirmations` phục vụ xác nhận thanh toán mô phỏng cho Member.
- Migration `0022` thêm `weight_kg`, `body_fat_percent` và `health_declaration_completed_at` vào `member_profiles` cùng `PATCH /users/me/health-declaration`; `POST /coach-payment-holds` từ chối bằng `HEALTH_DECLARATION_REQUIRED` khi chưa hoàn tất và `GET /coach/members/:memberId` chỉ trả dữ liệu thể trạng khi quan hệ đang `ACTIVE`.
- Migration `0023` thêm bảng `coach_outcome_cases` và loại ảnh `COACH_OUTCOME` trên `media_assets` cùng các API `/coach/members/:memberId/outcomes`, `/member/coach-outcomes`, `/coaches/:coachId/outcomes` và `/coach-outcomes/:outcomeId/photos/:side`. Coach gửi thành quả kèm ảnh trước/sau tùy chọn; chỉ Member liên quan mới duyệt công khai, bật/tắt `allowRealName` (`Học viên ẩn danh` khi chưa bật) hoặc thu hồi/xóa ảnh bất kỳ lúc nào. Quan hệ Coach kết thúc tự động khi hết số buổi hoặc hết thời hạn gói; màn `Coach của tôi` bỏ nút tự kết thúc thủ công và giữ `Nhắn Coach` khi tạm ngưng do Gym hết hạn.
- API `GET /coach-entitlements`, `GET /coach-bookings/available-slots`, `GET/POST /coach-bookings` và `PATCH /coach-bookings/:id` phục vụ luồng đặt/đổi/hủy/hoàn thành/vắng. Danh sách khung là kết quả sơ bộ, server kiểm tra lại công suất khi đặt. Với gói chờ, server xét phần giao của các khoảng ngày có thể kích hoạt, nên có thể từ chối một số gói còn khả thi ở từng kịch bản riêng. Migration `0014` và `GET/PUT /coach-bookings/blocks` cho phép Coach khóa/mở từng giờ với kiểm tra công suất. Flutter dùng các API này từ mục Lịch Coach.

- Bước 1 đang hoàn thiện: backend từ chối Coach/Admin đọc nhật ký, số đo, ảnh, biểu đồ và tạo nhận xét; Coach cũng không thể xin URL ảnh tiến trình của Member. Lối vào màn Coach xem tiến độ đã được gỡ khỏi Flutter. Các kiểm thử PostgreSQL đã chạy trên database test biệt lập.
- Bước 5 đã có chat 1–1 độc lập: migration `0009` giữ lịch sử chat cũ, cho phép Member và Coach mở trò chuyện với nhau không cần quan hệ qua `POST /conversations`; trang hồ sơ Coach có nút nhắn tin kể cả khi hết suất. Gửi/đọc theo mã cuộc trò chuyện, vẫn chấp nhận mã quan hệ của luồng cũ. Quyền gọi tiếp tục dựa trên quan hệ `ACTIVE`. Cần kiểm tra lại các màn Coach sau khi các luồng thuê/đặt lịch V2 hoàn thành.
- Migration `0019` chuyển nhật ký tập, bài đã tập, ba số đo và tối đa ba ảnh hợp lệ mỗi ngày sang Nhật ký V2. Ngày đã có bản ghi V2 được giữ nguyên. Bảng nguồn giữ lại để đọc lịch sử. Dữ liệu nhật ký ăn và các số đo ngoài ba vòng vẫn ở bảng nguồn.
- Migration `0010` thêm ba gói Coach cố định 10/20/30 buổi và 30/60/90 ngày. Admin cấu hình giá qua `/admin/coach-packages`. Danh sách công khai chỉ hiển thị các gói đã kích hoạt.
- Migration `0011` và API `/coach/work-slots` lưu lịch làm việc cố định của Coach: tối thiểu sáu ngày/tuần, mỗi ngày bốn khung 90 phút liên tiếp; database ngăn khung chồng lấn. `GET /coaches/:coachId/work-slots` chỉ là lịch cố định, chưa phải danh sách giờ có thể đặt. Coach chỉ sửa được lịch tuần khi không có gói hoạt động hoặc đang chờ. Có thể khóa từng giờ nếu vẫn đủ công suất.
- Flutter đã nối giữ suất từ hồ sơ Coach, đặt/đổi/hủy lịch 90 phút, quản lý lịch theo vai trò và hộp thông báo. Admin có màn cấu hình giá gói Coach và danh mục thực phẩm. Coach lưu giáo trình hiện hành qua PUT, Member xem ngay. Thực đơn 7 ngày có món theo bữa, gram và kcal, giữ kcal tại thời điểm lưu vào lịch sử.
- Hộp thông báo tạo nhắc hết hạn một lần mỗi gói khi Member mở hộp và gói còn tối đa bảy ngày. Menu ẩn các mô-đun V1 đã thay, API đã ngừng cho phép ghi mới qua các luồng V1 được thay thế và giữ đường đọc lịch sử. Phương thức thanh toán sẽ tích hợp riêng qua kết quả đã xác minh phía máy chủ.
- Migration `0018` giữ tính năng giáo trình theo ngày của nhánh GitHub và có thể chạy trên database đã áp dụng `0008_daily_training_meals` của nhánh đó.

## API nhật ký V2 hiện có

| Route | Vai trò | Ý nghĩa |
|---|---|---|
| `GET /api/v1/journal` | Member | Phân trang nhật ký của chính mình, kể cả khi gói Gym hết hạn |
| `GET /api/v1/journal/:id` | Member | Xem một bản ghi của chính mình |
| `GET /api/v1/journal/charts` | Member | Trả ngày và số đo ngực/eo/mông, bỏ ngày không có số đo |
| `POST /api/v1/journal` | Member có gói Gym ACTIVE | Tạo bản ghi hôm nay; trùng ngày trả `JOURNAL_EXISTS` |
| `PATCH /api/v1/journal/:id` | Member có gói Gym ACTIVE | Sửa nội dung, không đổi ngày ghi |
| `DELETE /api/v1/journal/:id` | Member có gói Gym ACTIVE | Xóa bản ghi và liên kết ảnh |

Body tạo/sửa hỗ trợ `notes`, `chestCm`, `waistCm`, `hipsCm`, `achievements: [{title, result}]` và `photoMediaIds` tối đa ba ảnh đã tải lên bằng mục đích `PROGRESS_PHOTO`. API không nhận ngày ghi từ client. Mọi truy vấn nhật ký lọc theo Member trong JWT; Coach/Admin nhận 403.
