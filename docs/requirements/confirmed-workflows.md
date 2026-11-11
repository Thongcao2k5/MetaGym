# Meta Gym — Đặc tả và kế hoạch MVP

> Cập nhật: 20/10/2026  
> Trạng thái: Bản chốt nghiệp vụ và kỹ thuật để người dùng thực hiện lượt review cuối trước khi lập trình.

## 1. Mục tiêu và phạm vi MVP

Meta Gym là hệ thống dành cho một phòng gym, hỗ trợ quản lý hội viên và quá trình tập luyện.

- Member và Coach sử dụng ứng dụng Flutter.
- Admin sử dụng một website quản trị riêng.
- Member quản lý gói tập, lựa chọn Coach, nhận hướng dẫn, ghi nhật ký và theo dõi tiến độ.
- Coach trực tiếp hướng dẫn và theo dõi Member.
- Admin quản lý hoạt động chung của phòng gym.
- AI chỉ cung cấp thông tin tham khảo, không thay thế Coach.

Luồng nghiệp vụ trọng tâm của MVP:

`Đăng ký → mua gói mô phỏng → chọn Coach → nhận hướng dẫn → ghi nhật ký → theo dõi tiến bộ`

## 2. Phạm vi đã loại khỏi MVP

- Nhiều phòng gym hoặc nhiều chi nhánh.
- Lớp học nhóm và đăng ký lớp.
- Thanh toán thật, hoàn tiền và xuất hóa đơn.
- Điểm danh bằng QR, khuôn mặt hoặc vân tay.
- Mạng xã hội, bảng tin và kết bạn.
- Đồng bộ đồng hồ thông minh hoặc ứng dụng sức khỏe.
- Hệ thống dinh dưỡng tự động chuyên sâu.
- AI chẩn đoán bệnh, thay thế Coach hoặc tự động sửa giáo trình.
- Phân quyền tùy chỉnh phức tạp.
- Báo cáo và phân tích dữ liệu chuyên sâu.
- Quản lý kho và bán sản phẩm.
- Quản lý lương, chấm công và hoa hồng nhân viên.
- Đặt lịch sử dụng từng máy tập.

Gọi thoại và gọi video giữa Member và Coach **nằm trong MVP** và được thực hiện trực tiếp trong ứng dụng bằng dịch vụ/SDK có sẵn, không tự xây dựng WebRTC.

## 3. Vai trò và quyền hạn

### 3.1. Member

- Tự đăng ký, đăng nhập và cập nhật hồ sơ cá nhân.
- Xem gói tập, thực hiện thanh toán mô phỏng và theo dõi thời hạn gói.
- Xem thông tin phòng gym, thiết bị và hồ sơ Coach.
- Gửi hoặc hủy yêu cầu chọn Coach khi yêu cầu còn chờ.
- Chỉ có một Coach đang phụ trách tại một thời điểm.
- Xem giáo trình, hướng dẫn ăn uống và lịch tập do Coach cung cấp.
- Ghi nhật ký tập luyện, bữa ăn, cân nặng, số đo và hình ảnh tiến trình.
- Xem lịch sử và biểu đồ tiến bộ.
- Nhắn tin, gọi thoại và gọi video với Coach đang phụ trách.
- Sử dụng AI để hỏi và tham khảo.
- Không được sửa giáo trình chính thức của Coach hoặc xem dữ liệu của Member khác.

### 3.2. Coach

- Tài khoản do Admin tạo.
- Cập nhật hồ sơ chuyên môn và thông tin giới thiệu.
- Có giới hạn số Member do Admin thiết lập.
- Xem, chấp nhận hoặc từ chối yêu cầu của Member.
- Xem dữ liệu của các Member mình đang phụ trách.
- Tạo và cập nhật giáo trình tập luyện, hướng dẫn ăn uống và lịch buổi tập.
- Theo dõi nhật ký, số đo và tiến trình của Member.
- Nhận xét, điều chỉnh giáo trình và ghi nhận trạng thái buổi tập.
- Nhắn tin, gọi thoại và gọi video với Member đang phụ trách.
- Sử dụng AI để tham khảo nhưng phải tự quyết định nội dung chính thức.
- Không được xem dữ liệu của Member không thuộc quyền phụ trách.
- Không được nhận Member vượt quá giới hạn.

### 3.3. Admin

- Hệ thống chỉ có một tài khoản Admin chính được tạo sẵn.
- Admin chỉ sử dụng website quản trị.
- Tạo và quản lý tài khoản Coach.
- Xem, khóa hoặc mở lại tài khoản Member và Coach.
- Thiết lập số Member tối đa cho từng Coach.
- Quản lý gói tập và giao dịch mô phỏng.
- Ghi nhận việc mua hoặc gia hạn gói tại quầy.
- Theo dõi và xử lý quan hệ Member–Coach.
- Xử lý yêu cầu kết thúc quan hệ do Coach gửi.
- Chỉ gán hoặc chuyển Coach khi có sự cố và phải lưu lý do.
- Quản lý thông tin phòng gym, thiết bị và hướng dẫn sử dụng.
- Xem thống kê quản trị cơ bản.
- Không được đọc tin nhắn, nội dung cuộc gọi hoặc sửa dữ liệu chuyên môn của Coach và Member.

## 4. Luồng tổng thể của Member

### 4.1. Đăng ký và sử dụng chức năng miễn phí

1. Member đăng ký bằng họ tên, email và mật khẩu.
2. Member đăng nhập và cập nhật hồ sơ.
3. Khi chưa có gói tập, Member vẫn được:
   - Xem thông tin phòng gym.
   - Xem hướng dẫn thiết bị.
   - Xem danh sách và hồ sơ Coach.
   - Sử dụng AI để hỏi và tham khảo.

### 4.2. Đăng ký gói tập

1. Member chọn một gói tập.
2. Hệ thống tạo giao dịch `MOCK_QR` và hiển thị mã QR cho Member.
3. Member hoàn tất thanh toán mô phỏng và xác nhận kết quả trên ứng dụng; không cần Admin duyệt.
4. Backend xác nhận thành công và tự động:
   - Lưu giao dịch.
   - Kích hoạt ngay gói đầu tiên hoặc xếp nối tiếp gói mua thêm.
   - Xác định ngày bắt đầu và ngày hết hạn.
   - Mở các chức năng tập luyện chính thức.
   - Kích hoạt lại quan hệ Coach đang tạm ngưng do hết hạn khi gói mới đã thực sự có hiệu lực.

### 4.3. Lựa chọn Coach

1. Member có gói tập đang hoạt động xem các Coach còn khả năng nhận người.
2. Member gửi yêu cầu cho một Coach.
3. Trong khi chờ, Member có thể hủy yêu cầu nhưng không được gửi đồng thời cho Coach khác.
4. Coach từ chối: Member được chọn Coach khác.
5. Coach chấp nhận: quan hệ được kích hoạt và Member chiếm một suất của Coach.

### 4.4. Quá trình được hướng dẫn

Member được:

- Xem giáo trình tập luyện và hướng dẫn ăn uống.
- Xem lịch các buổi tập.
- Ghi nhật ký tập luyện và bữa ăn.
- Cập nhật cân nặng, số đo và hình ảnh tiến trình.
- Nhận nhận xét từ Coach.
- Nhắn tin, gọi thoại và gọi video với Coach.
- Xem lịch sử và biểu đồ tiến bộ.

Dữ liệu do Coach tạo phải được phân biệt với dữ liệu Member tự ghi.

### 4.5. Gói tập hết hạn và gia hạn

Khi gói tập hết hạn:

- Quan hệ với Coach chuyển sang `Tạm ngưng`.
- Member vẫn chiếm một suất của Coach.
- Toàn bộ dữ liệu và lịch sử được giữ lại.
- Buổi tập tương lai và giáo án Coach đã tạo được giữ nguyên, hiển thị tạm khóa; không tự đổi lịch hoặc hủy khi gói hết hạn.
- Member chỉ được xem lịch sử, không được tạo nhật ký chính thức mới.
- Nhắn tin và cuộc gọi với Coach bị tạm khóa.
- Member vẫn được dùng AI và xem thông tin chung.

Khi Member thanh toán gia hạn thành công:

- Gói tập được kích hoạt lại.
- Quan hệ với Coach tự động trở lại trạng thái hoạt động.
- Các chức năng tập luyện và liên lạc được mở lại.
- Buổi tập và giáo án đã giữ được mở lại trên quan hệ Coach cũ; buổi có ngày hẹn đã qua cần Coach xếp lại lịch.

### 4.6. Đổi Coach

1. Member kết thúc quan hệ hiện tại.
2. Quan hệ cũ ngừng chiếm suất nhưng lịch sử được giữ lại.
3. Member gửi yêu cầu cho Coach mới.

## 5. Luồng tổng thể của Coach

### 5.1. Khởi tạo và cập nhật hồ sơ

1. Admin tạo tài khoản Coach.
2. Coach đăng nhập ứng dụng Flutter.
3. Coach cập nhật ảnh đại diện, giới thiệu, chuyên môn, kinh nghiệm và thời gian có thể hướng dẫn.

### 5.2. Xử lý yêu cầu của Member

1. Coach xem các yêu cầu đang chờ và thông tin cơ bản của Member.
2. Coach từ chối yêu cầu và cung cấp lý do ngắn; hoặc chấp nhận nếu còn suất.
3. Khi chấp nhận, quan hệ Coach–Member được kích hoạt.

### 5.3. Hướng dẫn Member

1. Coach xem mục tiêu, kinh nghiệm vận động, số đo, thói quen và lưu ý sức khỏe do Member khai báo.
2. Coach tạo giáo trình tập luyện, hướng dẫn ăn uống, mục tiêu và lịch tập riêng.
3. Coach quản lý trạng thái buổi tập: sắp diễn ra, hoàn thành, Member vắng hoặc đã hủy.
4. Coach xem nhật ký và tiến trình của Member.
5. Coach nhận xét và điều chỉnh giáo trình khi cần.
6. Coach nhắn tin, gọi thoại và gọi video với Member đang hoạt động.

Coach không thực hiện chẩn đoán y tế.

### 5.4. Member hết hạn gói tập

- Quan hệ chuyển sang `Tạm ngưng`.
- Member vẫn chiếm một suất.
- Coach chỉ được xem lịch sử, không tạo giáo trình hoặc buổi tập mới.
- Nhắn tin và cuộc gọi bị tạm khóa.
- Quan hệ tự động hoạt động lại khi Member gia hạn thành công.

### 5.5. Coach ngừng phụ trách Member

1. Coach nhập lý do và gửi yêu cầu đến Admin.
2. Trong khi chờ, quan hệ vẫn hoạt động.
3. Admin chấp nhận: quan hệ kết thúc và suất Coach được giải phóng.
4. Admin từ chối: Coach tiếp tục phụ trách Member.

## 6. Luồng tổng thể của Admin

### 6.1. Quản lý tổng quan

1. Admin đăng nhập website quản trị.
2. Admin xem bảng điều khiển gồm:
   - Tổng số Member và Coach.
   - Trạng thái tài khoản.
   - Trạng thái gói tập.
   - Khả năng nhận Member của Coach.
   - Trạng thái quan hệ Member–Coach.
   - Giao dịch trên ứng dụng và tại quầy.

### 6.2. Quản lý Member và Coach

- Xem và thay đổi trạng thái tài khoản Member.
- Tạo, cập nhật, khóa hoặc mở lại tài khoản Coach.
- Thiết lập giới hạn Member cho Coach.
- Hệ thống cảnh báo khi Admin khóa Coach đang phụ trách Member.

### 6.3. Quản lý gói tập và giao dịch

- Tạo, sửa, bật hoặc ngừng áp dụng gói tập.
- Không xóa vĩnh viễn gói đã phát sinh giao dịch.
- Xem lịch sử thanh toán mô phỏng và thanh toán tại quầy.
- Đánh dấu giao dịch lỗi hoặc bị hủy nhưng không xóa lịch sử.

Quy trình tại quầy:

1. Admin chọn Member và gói tập.
2. Admin ghi nhận phương thức `Tại quầy`.
3. Admin xác nhận giao dịch.
4. Gói tập được kích hoạt hoặc gia hạn.
5. Quan hệ Coach đang tạm ngưng được kích hoạt lại.

### 6.4. Quản lý quan hệ Member–Coach

Admin xem yêu cầu đang chờ, quan hệ hoạt động, tạm ngưng và đã kết thúc.

Khi xử lý yêu cầu kết thúc của Coach:

1. Admin xem lý do.
2. Chấp nhận: quan hệ kết thúc và giải phóng suất Coach.
3. Từ chối: quan hệ tiếp tục hoạt động.
4. Quyết định và lý do được lưu lại.

### 6.5. Chuyển Coach khi có sự cố

Admin chỉ thực hiện khi Coach nghỉ việc, bị khóa hoặc không thể tiếp tục hướng dẫn.

1. Admin nhập lý do chuyển.
2. Hệ thống kiểm tra Coach mới còn suất.
3. Quan hệ cũ được kết thúc.
4. Quan hệ mới được tạo.
5. Lịch sử với Coach cũ được giữ nguyên.
6. Giáo trình cũ không tự động trở thành giáo trình của Coach mới.

### 6.6. Quản lý nội dung phòng gym

Admin quản lý:

- Thông tin phòng gym.
- Nội quy.
- Danh sách thiết bị.
- Hướng dẫn sử dụng thiết bị.
- Cảnh báo an toàn cơ bản.

## 7. Luồng AI và giới hạn an toàn

### 7.1. Phạm vi sử dụng

- AI chỉ dành cho Member và Coach trong ứng dụng Flutter.
- Admin không có chức năng AI trên website quản trị.
- AI chỉ dùng để hỏi đáp và tham khảo, không thay thế Coach.

Người dùng có thể:

- Hỏi kiến thức cơ bản về tập luyện.
- Hỏi về dinh dưỡng và thói quen ăn uống.
- Hỏi cách sử dụng máy tập hoặc thực hiện bài tập.
- Yêu cầu gợi ý lịch tập tham khảo.
- Yêu cầu giải thích thuật ngữ liên quan đến gym.

### 7.2. Lịch sử trò chuyện

- Người dùng có thể tạo nhiều cuộc trò chuyện AI.
- Hệ thống lưu lịch sử để người dùng xem lại.
- Người dùng được đổi tên hoặc xóa cuộc trò chuyện của mình.
- Mỗi người chỉ được xem lịch sử AI của chính mình.
- Admin, Coach khác và Member khác không được xem lịch sử này.

### 7.3. Nguyên tắc dữ liệu

- AI chỉ sử dụng nội dung người dùng trực tiếp nhập vào cuộc trò chuyện.
- AI không tự động đọc hồ sơ, số đo hoặc nhật ký tập luyện.
- AI không đọc giáo trình do Coach tạo.
- AI không đọc tin nhắn hoặc nội dung cuộc gọi giữa Member và Coach.
- AI không tự động ghi câu trả lời vào nhật ký hoặc giáo trình.
- Coach phải tự kiểm tra và quyết định trước khi sử dụng nội dung AI trong giáo trình chính thức.

### 7.4. Giới hạn an toàn

AI phải:

- Thông báo nội dung chỉ mang tính tham khảo.
- Không chẩn đoán bệnh hoặc chấn thương.
- Không kê thuốc hoặc đưa ra hướng dẫn điều trị.
- Khuyên người dùng gặp bác sĩ hoặc chuyên gia khi có dấu hiệu bất thường.
- Không đề xuất mức tập luyện nguy hiểm.
- Không khẳng định một chế độ tập hoặc ăn uống phù hợp với tất cả mọi người.
- Nêu rõ khi không có đủ thông tin để trả lời chính xác.
- Khuyến nghị Member trao đổi với Coach trước khi áp dụng kế hoạch quan trọng.

### 7.5. Xử lý ngoại lệ

- API AI không phản hồi: thông báo người dùng thử lại sau.
- Câu hỏi không rõ: yêu cầu người dùng bổ sung thông tin.
- Nội dung ngoài phạm vi: từ chối lịch sự.
- Câu hỏi liên quan đến tình trạng nguy hiểm: khuyên người dùng ngừng tập và tìm hỗ trợ chuyên môn.
- Yêu cầu thất bại: không lưu câu trả lời đang dang dở.

## 8. Các module nghiệp vụ đã chốt

| STT | Module | Phạm vi chính |
| ---: | --- | --- |
| 1 | `Identity & Access` | Đăng ký, đăng nhập, hồ sơ, vai trò và trạng thái tài khoản |
| 2 | `Membership & Payment` | Gói tập, thanh toán mô phỏng, giao dịch tại quầy, kích hoạt và gia hạn |
| 3 | `Coaching Relationship` | Hồ sơ Coach, giới hạn Member, yêu cầu chọn Coach và vòng đời quan hệ |
| 4 | `Training & Nutrition` | Giáo trình, bài tập, hướng dẫn ăn uống, mục tiêu và lịch buổi tập |
| 5 | `Progress Tracking` | Nhật ký, cân nặng, số đo, hình ảnh và biểu đồ tiến bộ |
| 6 | `Messaging` | Nhắn tin riêng giữa Member và Coach |
| 7 | `Voice & Video Call` | Gọi thoại và gọi video trực tiếp trong ứng dụng |
| 8 | `AI Advisor` | Hỏi đáp tham khảo và lịch sử trò chuyện AI |
| 9 | `Gym Content` | Thông tin phòng gym, nội quy, thiết bị và hướng dẫn sử dụng |
| 10 | `Admin Dashboard` | Tổng hợp số liệu quản trị cơ bản |

### 8.1. Nguyên tắc tổ chức

- Giáo trình tập luyện và hướng dẫn dinh dưỡng được gộp trong `Training & Nutrition`.
- `Progress Tracking` được tách riêng vì dữ liệu chủ yếu do Member ghi nhận và Coach theo dõi.
- `Messaging` và `Voice & Video Call` là hai module độc lập.
- Thông tin phòng gym và thiết bị được gộp trong `Gym Content`.
- Admin web sử dụng các module nghiệp vụ chung; chức năng quản trị nằm trong module liên quan.
- `Admin Dashboard` chỉ tổng hợp dữ liệu thống kê, không chứa lại toàn bộ nghiệp vụ quản trị.
- Không xây dựng module thông báo riêng; trạng thái và huy hiệu chưa đọc nằm trong module phát sinh sự kiện.
- Push notification không thuộc phạm vi MVP.

## 9. Danh sách màn hình đã chốt

### 9.1. Identity & Access

**Flutter — Member và Coach**

- Khởi động và khôi phục phiên đăng nhập.
- Đăng nhập chung, tự điều hướng theo vai trò.
- Đăng ký Member.
- Quên mật khẩu, xác nhận mã email và tạo mật khẩu mới.
- Xem và chỉnh sửa hồ sơ cá nhân.
- Đổi mật khẩu.

**Admin web**

- Đăng nhập, hồ sơ và đổi mật khẩu Admin.
- Danh sách và chi tiết tài khoản Member.
- Danh sách, tạo và chỉnh sửa tài khoản Coach.
- Khóa hoặc mở lại tài khoản với hộp thoại xác nhận.
- Đặt lại mật khẩu Coach khi cần.

### 9.2. Membership & Payment

**Flutter — Member**

- Gói tập hiện tại.
- Danh sách và chi tiết gói tập.
- Thanh toán bằng QR mô phỏng.
- Kết quả thanh toán.
- Lịch sử và chi tiết giao dịch.

**Admin web**

- Danh sách, tạo và chỉnh sửa gói tập.
- Danh sách và chi tiết gói của Member.
- Tạo giao dịch tại quầy.
- Danh sách và chi tiết giao dịch.

Member chỉ có một gói đang hoạt động. Gói mua thêm bắt đầu sau ngày hết hạn của gói hiện tại.

### 9.3. Coaching Relationship

**Flutter — Member**

- Danh sách và chi tiết Coach.
- Gửi yêu cầu chọn Coach.
- Theo dõi hoặc hủy yêu cầu đang chờ.
- Xem Coach hiện tại.
- Kết thúc quan hệ.
- Xem lịch sử Coach.

**Flutter — Coach**

- Danh sách và chi tiết yêu cầu đang chờ.
- Chấp nhận hoặc từ chối kèm lý do.
- Danh sách và chi tiết Member đang phụ trách.
- Gửi và theo dõi yêu cầu ngừng phụ trách.
- Xem lịch sử Member.

**Admin web**

- Danh sách và chi tiết Coach cùng giới hạn Member.
- Danh sách và chi tiết quan hệ Member–Coach.
- Danh sách và xử lý yêu cầu kết thúc.
- Chuyển Coach khi có sự cố.
- Lịch sử chuyển Coach.

### 9.4. Training & Nutrition

**Flutter — Member**

- Kế hoạch hiện tại.
- Chi tiết giáo trình, ngày tập và bài tập.
- Hướng dẫn dinh dưỡng.
- Lịch và chi tiết buổi tập.
- Lịch sử kế hoạch.

**Flutter — Coach**

- Kế hoạch hiện tại và lịch sử của Member.
- Tạo, chỉnh sửa, xem trước và công bố giáo trình.
- Chọn và cấu hình bài tập.
- Tạo hoặc cập nhật hướng dẫn dinh dưỡng.
- Quản lý lịch buổi tập.
- Cập nhật trạng thái buổi tập.

Mỗi Member có tối đa một giáo trình tập và một hướng dẫn dinh dưỡng đang áp dụng. Bản cũ được lưu trữ; Member không thấy bản nháp.

### 9.5. Progress Tracking

**Flutter — Member**

- Tổng quan tiến độ.
- Xem và ghi nhật ký tập luyện.
- Xem và ghi nhật ký ăn uống.
- Xem và cập nhật số đo cơ thể.
- Xem và thêm ảnh tiến trình.
- Biểu đồ tiến bộ.
- Nhận xét của Coach.

**Flutter — Coach**

- Tổng quan tiến độ của từng Member.
- Nhật ký tập luyện và ăn uống.
- Lịch sử số đo và biểu đồ.
- Ảnh tiến trình.
- Gửi nhận xét.
- Danh sách Member lâu chưa cập nhật.

Admin không được xem nhật ký, số đo chi tiết hoặc ảnh tiến trình. Coach cũ mất quyền xem sau khi quan hệ kết thúc.

### 9.6. Messaging

**Flutter — Member và Coach**

- Danh sách cuộc trò chuyện.
- Màn hình trò chuyện.
- Xem hình ảnh trong tin nhắn.
- Trạng thái gửi thất bại và gửi lại.

Phạm vi MVP chỉ hỗ trợ văn bản và hình ảnh; không có tin nhắn thoại, tệp tùy ý, thu hồi hoặc chỉnh sửa tin nhắn. Lịch sử chuyển sang chỉ đọc khi quan hệ tạm ngưng hoặc kết thúc. Tin nhắn được tải theo trang và cập nhật bằng polling; chưa dùng push notification.

### 9.7. Voice & Video Call

**Flutter — Member và Coach**

- Cuộc gọi đến.
- Đang gọi đi.
- Cuộc gọi thoại.
- Cuộc gọi video.
- Kết quả cuộc gọi.
- Lịch sử cuộc gọi.

Chỉ hỗ trợ cuộc gọi một-một giữa Member và Coach có quan hệ hoạt động. Dùng SDK bên thứ ba, không tự xây dựng WebRTC; không ghi âm, ghi hình, gọi nhóm hoặc chia sẻ màn hình. Hệ thống chỉ lưu thông tin cuộc gọi như người gọi, người nhận, loại, thời điểm, thời lượng và trạng thái.

### 9.8. AI Advisor

**Flutter — Member và Coach**

- Danh sách cuộc trò chuyện AI.
- Tạo cuộc trò chuyện mới.
- Hỏi đáp dạng văn bản.
- Đổi tên hoặc xóa cuộc trò chuyện.
- Màn hình thông tin giới hạn an toàn.

MVP chỉ hỗ trợ văn bản, không gửi ảnh, tệp hoặc giọng nói cho AI. Mỗi câu trả lời hiển thị cảnh báo tham khảo. Khi API lỗi, người dùng được thử gửi lại và câu trả lời dang dở không được lưu.

### 9.9. Gym Content

**Flutter — Member và Coach**

- Thông tin phòng gym.
- Nội quy.
- Danh sách, tìm kiếm và lọc thiết bị.
- Chi tiết thiết bị và hướng dẫn sử dụng.

**Admin web**

- Chỉnh sửa thông tin phòng gym và nội quy.
- Danh sách, tạo và chỉnh sửa thiết bị.
- Bật hoặc ẩn thiết bị.

Nội dung thiết bị gồm tên, nhóm cơ, hình ảnh, mô tả, các bước sử dụng, cảnh báo và đường dẫn video tùy chọn.

### 9.10. Admin Dashboard

- Một màn hình tổng quan gồm các thẻ số liệu.
- Biểu đồ Member mới và giao dịch theo thời gian.
- Bảng Coach đã đủ hoặc sắp đủ suất.
- Danh sách gói sắp hết hạn và các yêu cầu cần xử lý.
- Bộ lọc thời gian cơ bản.

Dashboard chỉ tổng hợp và liên kết tới màn hình nghiệp vụ; không sao chép chức năng chỉnh sửa của các module khác.

## 10. Mô hình dữ liệu MVP

> Đặc tả database chuẩn hóa chính thức nằm tại [`database-spec.md`](./database-spec.md). Nếu phần tóm tắt bên dưới khác tài liệu đó thì ưu tiên `database-spec.md`.

### 10.1. Tài khoản và hồ sơ

| Bảng | Dữ liệu chính |
| --- | --- |
| `users` | email, password_hash, role, full_name, phone, avatar_media_id, status, session_version, timestamps |
| `member_profiles` | user_id, date_of_birth, height_cm, fitness_goal, health/injury/dietary notes |
| `password_reset_codes` | user_id, code_hash, attempt_count, expires_at, used_at, invalidated_at |
| `coach_profiles` | user_id, biography, specialties, experience_years, availability_note, member_limit |

Email phải duy nhất không phân biệt chữ hoa/thường. Enum database dùng `UPPER_SNAKE_CASE`: vai trò gồm `MEMBER`, `COACH`, `ADMIN`; trạng thái gồm `ACTIVE`, `DISABLED`.

### 10.2. Gói tập và thanh toán

| Bảng | Dữ liệu chính |
| --- | --- |
| `membership_plans` | name, description, price, duration_days, status |
| `member_memberships` | member_id, plan_id, start_date, end_date, status, source_payment_id |
| `payments` | member_id, plan_id, snapshot gói, amount, method, status, transaction_code, idempotency_key, created_by |

Phương thức gồm `MOCK_QR` và `FRONT_DESK`; trạng thái gồm `PENDING`, `SUCCESS`, `FAILED`, `CANCELLED`.

### 10.3. Quan hệ Coach–Member

| Bảng | Dữ liệu chính |
| --- | --- |
| `coach_requests` | member_id, coach_id, status, rejection_reason, timestamps |
| `coach_relationships` | member_id, coach_id, status, started_at, paused_at, ended_at, end_reason |
| `coach_termination_requests` | relationship_id, coach_id, reason, status, admin_note, decided_at |
| `coach_transfer_history` | member_id, old_coach_id, new_coach_id, reason, admin_id, created_at |

Mỗi Member chỉ có một yêu cầu đang chờ và một quan hệ `active` hoặc `paused`. Quan hệ tạm ngưng vẫn được tính vào giới hạn của Coach.

### 10.4. Giáo trình và lịch tập

| Bảng | Dữ liệu chính |
| --- | --- |
| `exercises` | name, description, target_muscles, equipment_id, instruction_video_url, status |
| `training_plans` | relationship_id, member_id, coach_id, title, goal, version, status, published_at, archived_at |
| `training_plan_days` | plan_id, day_number, title, notes |
| `training_plan_exercises` | plan_day_id, exercise_id, sets, reps, rest_seconds, notes, display_order |
| `nutrition_guides` | relationship_id, member_id, coach_id, title, content, version, status, timestamps |
| `training_sessions` | relationship_id, member_id, scheduled_start_at, scheduled_end_at, title, status, result timestamps |

Trạng thái kế hoạch gồm `DRAFT`, `ACTIVE`, `ARCHIVED`; trạng thái buổi tập gồm `SCHEDULED`, `COMPLETED`, `MEMBER_ABSENT`, `CANCELLED`.

### 10.5. Theo dõi tiến độ

| Bảng | Dữ liệu chính |
| --- | --- |
| `workout_logs` | member_id, training_session_id, training_plan_id, performed_at, completion_level, notes |
| `workout_log_exercises` | workout_log_id, exercise snapshot, sets/reps/weight/duration, display_order |
| `meal_logs` | member_id, eaten_at, meal_name, image_media_id, notes |
| `body_measurements` | member_id, measured_at, weight_kg, body_fat_percent, các vòng đo |
| `progress_photos` | member_id, taken_at, media_id, pose, notes |
| `progress_comments` | relationship_id, coach_id, member_id, một trong bốn FK đích, content, created_at |

Các trường số đo ngoài cân nặng được phép để trống. Dữ liệu được phân trang và không xóa vật lý sau khi đã phát sinh nhận xét.

### 10.6. Giao tiếp và AI

| Bảng | Dữ liệu chính |
| --- | --- |
| `conversations` | relationship_id, last_message_at, timestamps |
| `conversation_participants` | conversation_id, user_id, last_read_message_id, last_read_at |
| `messages` | conversation_id, sender_id, client_message_id, message_type, content, media_id, sent_at |
| `call_logs` | relationship_id, caller_id, receiver_id, call_type, status, initiated_at, answered_at, ended_at |
| `ai_conversations` | user_id, title, created_at, updated_at, deleted_at |
| `ai_messages` | conversation_id, role, content, client_request_id, request_hash, reply_to_message_id, status, timestamps |

Nội dung tin nhắn và AI chỉ truy cập được bởi chủ thể được phép; Admin không có API đọc nội dung.

### 10.7. Nội dung phòng gym

| Bảng | Dữ liệu chính |
| --- | --- |
| `gym_profile` | name, address, phone, description, opening_hours, rules |
| `equipment` | name, category, target_muscles, image_media_id, description, usage_steps, safety_notes, video_url, status |
| `media_assets` | owner_id, purpose, access_scope, storage_key, metadata ảnh, status, lifecycle timestamps |

Tất cả bảng nghiệp vụ có `created_at`, `updated_at` khi phù hợp. Những dữ liệu cần giữ lịch sử dùng trạng thái hoặc `deleted_at`, không xóa vật lý.

## 11. API REST MVP

Tất cả API dùng tiền tố `/api`; API bảo vệ phải kiểm tra JWT, vai trò, quyền sở hữu dữ liệu và trạng thái quan hệ.

> Danh sách endpoint chuẩn hóa chính thức nằm tại [`api-contract.md`](./api-contract.md). Nếu tên endpoint trong phần tóm tắt bên dưới khác tài liệu đó thì ưu tiên `api-contract.md`.

### 11.1. Identity & Access

- `POST /auth/register` — đăng ký Member.
- `POST /auth/login` — đăng nhập chung.
- `POST /auth/forgot-password` — gửi mã xác nhận.
- `POST /auth/verify-reset-code` — kiểm tra mã.
- `POST /auth/reset-password` — đặt mật khẩu mới.
- `GET /auth/me` — khôi phục phiên.
- `PATCH /users/me` — sửa hồ sơ cá nhân.
- `PATCH /users/me/password` — đổi mật khẩu.
- `GET /admin/users` và `GET /admin/users/:id` — quản lý tài khoản.
- `POST /admin/coaches` — tạo Coach.
- `PATCH /admin/users/:id/status` — khóa hoặc mở tài khoản.

### 11.2. Membership & Payment

- `GET /membership-plans` và `GET /membership-plans/:id`.
- `POST /admin/membership-plans`, `PATCH /admin/membership-plans/:id`.
- `GET /memberships/me` — gói hiện tại và gói nối tiếp.
- `POST /payments` — tạo giao dịch QR mô phỏng.
- `POST /payments/:id/mock-confirmations` — Member xác nhận thanh toán mô phỏng thành công; backend tự kích hoạt/xếp nối gói.
- `GET /payments/me` và `GET /payments/:id`.
- `POST /admin/payments/front-desk` — giao dịch tại quầy.
- `GET /admin/payments` và `GET /admin/memberships`.

### 11.3. Coaching Relationship

- `GET /coaches` và `GET /coaches/:id`.
- `POST /coach-requests`, `GET /coach-requests/me`, `DELETE /coach-requests/:id`.
- `GET /coach/requests`, `PATCH /coach/requests/:id/accept`, `PATCH /coach/requests/:id/reject`.
- `GET /relationships/me` và `GET /relationships/history`.
- `POST /relationships/:id/end-by-member`.
- `GET /coach/members` và `GET /coach/members/:memberId`.
- `POST /coach/relationships/:id/termination-requests`.
- `GET /admin/relationships`.
- `PATCH /admin/termination-requests/:id/approve` hoặc `/reject`.
- `POST /admin/relationships/:id/transfer`.

### 11.4. Training & Nutrition

- `GET /members/me/training-plans/active` và `GET /members/me/training-plans/history`.
- `GET /coach/members/:memberId/training-plans`.
- `POST /coach/members/:memberId/training-plans`.
- `PATCH /coach/training-plans/:id`, `POST /coach/training-plans/:id/publish`.
- `GET /members/me/nutrition-guide`.
- `POST /coach/members/:memberId/nutrition-guides`, `PATCH /coach/nutrition-guides/:id`.
- `GET /training-sessions/me`.
- `POST /coach/training-sessions`, `PATCH /coach/training-sessions/:id`.
- `PATCH /coach/training-sessions/:id/status`.
- `GET /exercises` và các API Admin quản lý danh mục bài tập khi cần.

### 11.5. Progress Tracking

- `GET /progress/me/summary`.
- `GET|POST|PATCH /workout-logs`.
- `GET|POST|PATCH /meal-logs`.
- `GET|POST|PATCH /body-measurements`.
- `GET|POST|PATCH /progress-photos`.
- `GET /progress/me/charts`.
- `GET /coach/members/:memberId/progress`.
- `POST /coach/progress-comments`.

### 11.6. Messaging

- `GET /conversations` — quan hệ có thể trò chuyện.
- `GET /relationships/:id/messages` — tải tin nhắn theo trang.
- `POST /relationships/:id/messages` — gửi văn bản hoặc hình ảnh.
- `PATCH /relationships/:id/messages/read` — đánh dấu đã đọc.

### 11.7. Voice & Video Call

- `POST /calls/token` — cấp thông tin tham gia cuộc gọi từ SDK bên thứ ba.
- `POST /calls` — tạo bản ghi cuộc gọi.
- `PATCH /calls/:id/status` — cập nhật trạng thái hoặc kết thúc.
- `GET /calls/history` — lịch sử của người dùng hiện tại.

### 11.8. AI Advisor

- `GET|POST /ai/conversations`.
- `PATCH|DELETE /ai/conversations/:id`.
- `GET /ai/conversations/:id/messages`.
- `POST /ai/conversations/:id/messages` — gửi câu hỏi qua backend đến dịch vụ AI.

### 11.9. Gym Content và Dashboard

- `GET /gym-profile`, `GET /equipment`, `GET /equipment/:id`.
- `PATCH /admin/gym-profile`.
- `POST /admin/equipment`, `PATCH /admin/equipment/:id`.
- `GET /admin/dashboard?from=&to=`.

## 12. Tiêu chí hoàn thành MVP

- Member hoàn thành được luồng đăng ký → mua gói → chọn Coach → nhận kế hoạch → ghi tiến độ.
- Coach hoàn thành được luồng nhận Member → công bố kế hoạch → theo dõi → phản hồi.
- Admin quản lý được tài khoản, gói, giao dịch, quan hệ và nội dung phòng gym.
- Nhắn tin và cuộc gọi chỉ hoạt động với quan hệ đang hoạt động.
- AI trả lời qua API, lưu lịch sử và không tự đọc dữ liệu nghiệp vụ.
- Quyền truy cập được kiểm tra ở backend, không chỉ ẩn nút trên giao diện.
- Dữ liệu lịch sử không bị mất khi gói hết hạn, đổi Coach hoặc khóa tài khoản.
- Flutter chạy qua `flutter analyze` và `flutter test` không lỗi.
- Backend vượt qua kiểm tra cú pháp, test API trọng yếu và kiểm tra phân quyền.
- Admin web build thành công và các màn hình chính hoạt động trên desktop.
- Không lưu mật khẩu, khóa API hoặc thông tin bí mật trong Git.

