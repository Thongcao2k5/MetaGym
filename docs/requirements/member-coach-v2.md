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

- Bước 1 đang hoàn thiện: backend từ chối Coach/Admin đọc nhật ký, số đo, ảnh, biểu đồ và tạo nhận xét; Coach cũng không thể xin URL ảnh tiến trình của Member. Lối vào màn Coach xem tiến độ đã được gỡ khỏi Flutter. Test độc lập PostgreSQL chứng minh các quyền này; test PostgreSQL vẫn cần chạy trên database test biệt lập.
- Các bước 2–8 chưa triển khai. Những màn và API cũ khác vẫn phục vụ luồng V1, nên chưa thể coi ứng dụng là bản V2 hoặc dùng nó để chứng minh các quy tắc thanh toán, công suất và đặt lịch trong PDF.
