# Meta Gym — Member và Coach, đặc tả V2

Nguồn quyết định: `C:\Users\thong\Downloads\MetaGym_BanDacTa.pdf`, ngày 13/11/2026. Tài liệu này ghi lại yêu cầu để triển khai trong repository. Các quy tắc V2 dưới đây thay thế phần tương ứng trong `confirmed-workflows.md` và `api-contract.md` trước đây; các API cũ chưa được xem là tương thích cho đến khi có test chứng minh.

## Quy tắc sản phẩm đã chốt

- Một Member có tối đa một Coach hiện hành. Coach có tối đa 8 Member, tính cả quan hệ `PAUSED` và slot giữ thanh toán. Việc xem hồ sơ/lịch Coach không giữ khung giờ.
- Thuê Coach yêu cầu gói Gym `ACTIVE`. Member chọn một trong ba gói Coach (10 buổi/30 ngày, 20 buổi/60 ngày, 30 buổi/90 ngày), thanh toán mô phỏng trực tiếp, không gửi yêu cầu chờ Coach duyệt. Bắt đầu thanh toán giữ một slot tối đa 15 phút; xác nhận thanh toán kiểm tra lại công suất trong transaction. Hủy/thất bại/hết hạn trả slot.
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

- Bước 1 đang hoàn thiện: backend từ chối Coach/Admin đọc nhật ký, số đo, ảnh, biểu đồ và tạo nhận xét; Coach cũng không thể xin URL ảnh tiến trình của Member. Lối vào màn Coach xem tiến độ đã được gỡ khỏi Flutter. Các kiểm thử PostgreSQL đã chạy trên database test biệt lập.
- Bước 5 đã có chat 1–1 độc lập: migration `0009` giữ lịch sử chat cũ, cho phép Member và Coach mở trò chuyện với nhau không cần quan hệ qua `POST /conversations`; trang hồ sơ Coach có nút nhắn tin kể cả khi hết suất. Gửi/đọc theo mã cuộc trò chuyện, vẫn chấp nhận mã quan hệ của luồng cũ. Quyền gọi tiếp tục dựa trên quan hệ `ACTIVE`. Cần kiểm tra lại các màn Coach sau khi các luồng thuê/đặt lịch V2 hoàn thành.
- Bước 7 đã có luồng nhật ký V2 mới: migration `0008`, API `/journal`, màn Member và kiểm thử trên PostgreSQL. Một Member ghi tối đa một bản/ngày theo ngày server, có thành tích, ba số đo tùy chọn, tối đa ba ảnh; gói Gym hết hạn thì chỉ đọc. Dữ liệu `workout_logs` V1 chưa chuyển sang bảng mới; các trang nhật ký ăn, ảnh và tiến độ V1 vẫn còn trong menu/Home để tránh làm hỏng các tệp giao diện đang được thiết kế lại.
- Bước 2 đã bắt đầu ở migration `0010`: ba gói Coach cố định 10/20/30 buổi và 30/60/90 ngày; giá do Admin cấu hình qua `/admin/coach-packages`, gói chỉ hiện công khai khi được kích hoạt. Chưa có giao dịch mua, giữ slot thanh toán, buổi đặt hoặc chụp giá tại thời điểm mua.
- Migration `0011` và API `/coach/work-slots` lưu lịch làm việc cố định của Coach: tối thiểu sáu ngày/tuần, mỗi ngày bốn khung 90 phút liên tiếp; database ngăn khung chồng lấn. `GET /coaches/:coachId/work-slots` chỉ là lịch cố định, chưa phải danh sách giờ có thể đặt. Chưa có cơ chế khóa giờ hoặc bảo vệ công suất khi Coach sửa lịch sau khi đã bán gói.
- Các phần còn lại của bước 2–4, bước 6 và phần còn lại của bước 7–8 chưa triển khai. Các màn và API cũ khác vẫn phục vụ luồng V1, nên chưa thể coi ứng dụng là bản V2 hoặc dùng nó để chứng minh các quy tắc thanh toán, công suất và đặt lịch trong PDF.

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
