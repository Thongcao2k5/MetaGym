# Meta Gym — Sơ đồ trang và điều hướng

> Cập nhật: 20/10/2026  
> Mục tiêu: Chốt toàn bộ route trước khi thiết kế wireframe và lập trình.

## 1. Nguyên tắc điều hướng

- Flutter dùng chung một ứng dụng cho Member và Coach, sau đăng nhập sẽ mở shell theo vai trò.
- Mỗi shell có tối đa 5 mục bottom navigation.
- Messaging, AI và cuộc gọi là chức năng dùng chung, mở từ nút hành động hoặc từ trang Coach/Member liên quan.
- Các form ngắn, xác nhận và kết quả thao tác dùng dialog/bottom sheet khi hợp lý, không tạo route riêng.
- Admin web dùng sidebar; màn hình chỉnh sửa có thể dùng lại một form cho cả tạo mới và cập nhật.
- Mọi trang chi tiết phải có đường quay lại dự đoán được và hỗ trợ deep link nội bộ.
- Danh sách dài dùng phân trang/lazy loading; mọi trang có trạng thái loading, rỗng, lỗi và thử lại.

## 2. Flutter — Trang xác thực dùng chung

| Route | Trang | Vai trò |
| --- | --- | --- |
| `/splash` | Khởi động và khôi phục phiên | Tất cả |
| `/login` | Đăng nhập chung | Member, Coach |
| `/register` | Đăng ký Member | Khách |
| `/forgot-password` | Nhập email quên mật khẩu | Member, Coach |
| `/verify-reset-code` | Xác nhận mã email | Member, Coach |
| `/reset-password` | Tạo mật khẩu mới | Member, Coach |

Sau đăng nhập:

- `member` → `/member/home`
- `coach` → `/coach/home`
- `admin` → bị từ chối trên Flutter và phải dùng Admin web.

## 3. Flutter — Khu vực Member

### 3.1. Bottom navigation

| Vị trí | Mục | Route gốc | Mục đích |
| ---: | --- | --- | --- |
| 1 | Trang chủ | `/member/home` | Tổng quan gói, Coach, lịch và lối tắt |
| 2 | Coach | `/member/coaches` | Tìm, chọn và quản lý quan hệ Coach |
| 3 | Kế hoạch | `/member/plan` | Giáo trình, dinh dưỡng và buổi tập |
| 4 | Tiến độ | `/member/progress` | Nhật ký, số đo, ảnh và biểu đồ |
| 5 | Cá nhân | `/profile` | Hồ sơ, gói tập, giao dịch và cài đặt |

Inbox đặt ở AppBar. AI là nút hành động nổi hoặc thẻ nổi bật trên Trang chủ. Gọi thoại/video bắt đầu từ trang Coach hiện tại hoặc trang Chat.

### 3.2. Trang chủ

| Route | Trang |
| --- | --- |
| `/member/home` | Tổng quan Member |

Trang chủ hiển thị gói hiện tại, Coach hiện tại, buổi tập sắp tới, tiến độ gần nhất và lối tắt tới AI/Messaging.

### 3.3. Gói tập và thanh toán

| Route | Trang |
| --- | --- |
| `/member/membership` | Gói hiện tại và gói nối tiếp |
| `/member/membership/plans` | Danh sách gói tập |
| `/member/membership/plans/:planId` | Chi tiết gói tập |
| `/member/payments/qr/:paymentId` | QR thanh toán mô phỏng |
| `/member/payments` | Lịch sử giao dịch |
| `/member/payments/:paymentId` | Chi tiết giao dịch |

Kết quả thành công/thất bại là trạng thái của trang QR hoặc dialog, không tạo trang riêng.

### 3.4. Coach và quan hệ

| Route | Trang |
| --- | --- |
| `/member/coaches` | Danh sách Coach |
| `/member/coaches/:coachId` | Chi tiết Coach |
| `/member/coach-request` | Trạng thái yêu cầu hiện tại |
| `/member/current-coach` | Coach và quan hệ hiện tại |
| `/member/coach-history` | Lịch sử Coach |

Gửi yêu cầu, hủy yêu cầu và kết thúc quan hệ dùng dialog xác nhận.

### 3.5. Giáo trình, dinh dưỡng và lịch tập

| Route | Trang |
| --- | --- |
| `/member/plan` | Tổng quan kế hoạch hiện tại |
| `/member/plan/training/:planId` | Chi tiết giáo trình |
| `/member/plan/training/:planId/day/:dayId` | Chi tiết ngày tập |
| `/member/exercises/:exerciseId` | Chi tiết bài tập |
| `/member/plan/nutrition/:guideId` | Hướng dẫn dinh dưỡng |
| `/member/sessions` | Lịch buổi tập |
| `/member/sessions/:sessionId` | Chi tiết buổi tập |
| `/member/plan/history` | Lịch sử kế hoạch |

### 3.6. Theo dõi tiến độ

| Route | Trang |
| --- | --- |
| `/member/progress` | Tổng quan tiến độ |
| `/member/progress/workouts` | Nhật ký tập luyện |
| `/member/progress/workouts/new` | Ghi nhật ký tập luyện |
| `/member/progress/workouts/:logId/edit` | Sửa nhật ký tập luyện |
| `/member/progress/measurements` | Lịch sử số đo |
| `/member/progress/measurements/new` | Cập nhật số đo |
| `/member/progress/photos` | Ảnh tiến trình |
| `/member/progress/photos/new` | Thêm ảnh tiến trình |
| `/member/progress/charts` | Biểu đồ tiến bộ |
| `/member/progress/comments` | Nhận xét của Coach |

## 4. Flutter — Khu vực Coach

### 4.1. Bottom navigation

| Vị trí | Mục | Route gốc | Mục đích |
| ---: | --- | --- | --- |
| 1 | Trang chủ | `/coach/home` | Tổng quan công việc và cảnh báo |
| 2 | Yêu cầu | `/coach/requests` | Xử lý yêu cầu chọn Coach |
| 3 | Member | `/coach/members` | Quản lý người đang phụ trách |
| 4 | Lịch tập | `/coach/sessions` | Quản lý các buổi tập |
| 5 | Cá nhân | `/profile` | Hồ sơ Coach và cài đặt |

Inbox đặt ở AppBar. AI được mở từ Trang chủ hoặc hồ sơ. Giáo trình và tiến độ được mở trong chi tiết từng Member để tránh làm bottom navigation quá tải.

### 4.2. Trang chủ và yêu cầu

| Route | Trang |
| --- | --- |
| `/coach/home` | Tổng quan Coach |
| `/coach/requests` | Danh sách yêu cầu đang chờ |
| `/coach/requests/:requestId` | Chi tiết và xử lý yêu cầu |

Chấp nhận hoặc từ chối được thực hiện trên trang chi tiết; từ chối yêu cầu nhập lý do.

### 4.3. Quản lý Member

| Route | Trang |
| --- | --- |
| `/coach/members` | Danh sách Member đang phụ trách |
| `/coach/members/:memberId` | Tổng quan một Member |
| `/coach/member-history` | Lịch sử Member |
| `/coach/relationships/:relationshipId/termination` | Yêu cầu ngừng phụ trách |
| `/coach/termination-requests` | Trạng thái các yêu cầu kết thúc |

### 4.4. Giáo trình và dinh dưỡng

| Route | Trang |
| --- | --- |
| `/coach/members/:memberId/plans` | Kế hoạch hiện tại và lịch sử |
| `/coach/members/:memberId/plans/new` | Tạo giáo trình |
| `/coach/training-plans/:planId/edit` | Chỉnh sửa giáo trình |
| `/coach/training-plans/:planId/preview` | Xem trước và công bố |
| `/coach/members/:memberId/nutrition` | Tạo hoặc sửa hướng dẫn dinh dưỡng |

Chọn bài tập và cấu hình hiệp/lần/nghỉ được thực hiện trong luồng chỉnh sửa bằng trang con hoặc bottom sheet dùng lại.

### 4.5. Lịch tập và tiến độ Member

| Route | Trang |
| --- | --- |
| `/coach/sessions` | Lịch các buổi tập |
| `/coach/sessions/new` | Tạo buổi tập |
| `/coach/sessions/:sessionId` | Chi tiết và cập nhật trạng thái |
| `/coach/members/:memberId/progress` | Tổng quan tiến độ Member |
| `/coach/members/:memberId/workouts` | Nhật ký tập luyện |
| `/coach/members/:memberId/measurements` | Số đo và biểu đồ |
| `/coach/members/:memberId/photos` | Ảnh tiến trình |

Nhận xét được nhập ngay tại bản ghi bằng bottom sheet, không tạo trang riêng.

## 5. Flutter — Trang dùng chung sau đăng nhập

### 5.1. Hồ sơ và nội dung phòng gym

| Route | Trang |
| --- | --- |
| `/profile` | Hồ sơ cá nhân theo vai trò |
| `/profile/edit` | Chỉnh sửa hồ sơ |
| `/profile/change-password` | Đổi mật khẩu |
| `/gym` | Thông tin và nội quy phòng gym |
| `/equipment` | Danh sách thiết bị |
| `/equipment/:equipmentId` | Chi tiết và hướng dẫn thiết bị |

### 5.2. Messaging

| Route | Trang |
| --- | --- |
| `/messages` | Danh sách cuộc trò chuyện |
| `/messages/:relationshipId` | Chat Member–Coach |
| `/messages/image` | Xem ảnh toàn màn hình |

Khi quan hệ không hoạt động, trang Chat chỉ cho xem lịch sử và ẩn vùng nhập.

### 5.3. Voice & Video Call

| Route | Trang |
| --- | --- |
| `/calls/active/:callId` | Toàn bộ trạng thái gọi đến, gọi đi và đang gọi |
| `/calls/history` | Lịch sử cuộc gọi |

Không tách nhiều route cho các trạng thái cuộc gọi; cùng một màn hình thay đổi theo trạng thái để giảm lỗi vòng đời.

### 5.4. AI Advisor

| Route | Trang |
| --- | --- |
| `/ai` | Danh sách cuộc trò chuyện AI |
| `/ai/new` | Bắt đầu cuộc trò chuyện mới |
| `/ai/:conversationId` | Hỏi đáp và xem lịch sử |
| `/ai/safety` | Giới hạn và cảnh báo sử dụng |

Đổi tên và xóa cuộc trò chuyện dùng menu/dialog.

## 6. Admin web

### 6.1. Sidebar chính

| Mục | Route gốc |
| --- | --- |
| Dashboard | `/admin/dashboard` |
| Member | `/admin/members` |
| Coach | `/admin/coaches` |
| Gói tập | `/admin/membership-plans` |
| Giao dịch | `/admin/payments` |
| Quan hệ | `/admin/relationships` |
| Nội dung phòng gym | `/admin/gym-content` |

Hồ sơ Admin, đổi mật khẩu và đăng xuất nằm trong menu tài khoản, không chiếm một mục sidebar.

### 6.2. Route chi tiết

| Route | Trang |
| --- | --- |
| `/admin/login` | Đăng nhập Admin |
| `/admin/dashboard` | Dashboard tổng quan |
| `/admin/profile` | Hồ sơ và đổi mật khẩu Admin |
| `/admin/members` | Danh sách Member |
| `/admin/members/:memberId` | Chi tiết tài khoản và gói của Member |
| `/admin/coaches` | Danh sách Coach |
| `/admin/coaches/new` | Tạo tài khoản Coach |
| `/admin/coaches/:coachId` | Chi tiết Coach và giới hạn Member |
| `/admin/coaches/:coachId/edit` | Chỉnh sửa Coach |
| `/admin/membership-plans` | Danh sách gói tập |
| `/admin/membership-plans/new` | Tạo gói tập |
| `/admin/membership-plans/:planId/edit` | Chỉnh sửa gói tập |
| `/admin/memberships` | Danh sách gói của Member |
| `/admin/payments` | Danh sách giao dịch |
| `/admin/payments/front-desk` | Tạo giao dịch tại quầy |
| `/admin/payments/:paymentId` | Chi tiết giao dịch |
| `/admin/relationships` | Danh sách quan hệ Member–Coach |
| `/admin/relationships/:relationshipId` | Chi tiết quan hệ |
| `/admin/termination-requests` | Yêu cầu Coach ngừng phụ trách |
| `/admin/termination-requests/:requestId` | Xử lý yêu cầu kết thúc |
| `/admin/relationships/:relationshipId/transfer` | Chuyển Coach khi có sự cố |
| `/admin/coach-transfers` | Lịch sử chuyển Coach |
| `/admin/gym-content/profile` | Thông tin và nội quy phòng gym |
| `/admin/gym-content/equipment` | Danh sách thiết bị |
| `/admin/gym-content/equipment/new` | Tạo thiết bị |
| `/admin/gym-content/equipment/:equipmentId/edit` | Chỉnh sửa thiết bị |

Khóa/mở tài khoản, đổi trạng thái giao dịch và bật/ẩn nội dung dùng dialog xác nhận, không tạo trang riêng.

## 7. Kiểm soát truy cập trang

| Tình trạng | Hành vi điều hướng |
| --- | --- |
| Chưa đăng nhập | Chỉ vào nhóm Auth và nội dung công khai được cho phép |
| Member chưa có gói | Xem Coach/Gym/AI; bị chặn khi gửi yêu cầu hoặc ghi tiến độ chính thức |
| Member có gói, chưa có Coach | Mở chọn Coach; chưa có trang kế hoạch chính thức |
| Quan hệ hoạt động | Mở toàn bộ kế hoạch, tiến độ, chat và call |
| Quan hệ tạm ngưng | Chỉ đọc lịch sử; khóa ghi mới, chat và call |
| Quan hệ kết thúc | Coach cũ không được mở dữ liệu tiến độ; Member vẫn giữ lịch sử của mình |
| Tài khoản bị khóa | Xóa phiên và quay về đăng nhập với thông báo |
| Sai vai trò | Hiển thị trang không có quyền và quay về shell hợp lệ |

## 8. Thành phần tái sử dụng bắt buộc

- App shell riêng cho Member và Coach nhưng dùng chung theme, AppBar, loading/error/empty state.
- Một trang danh sách dùng chung cho tìm kiếm, lọc, phân trang và pull-to-refresh.
- Một form dùng lại cho tạo/sửa gói, Coach, thiết bị và các nhật ký tương ứng.
- Một màn hình Chat dùng chung cho Member và Coach.
- Một màn hình cuộc gọi dùng chung cho mọi trạng thái.
- Một bộ widget thống kê dùng chung cho Admin Dashboard.
- Mọi vùng chạm tối thiểu 44×44px; nhãn form luôn hiển thị; lỗi đặt cạnh trường; không dùng màu làm tín hiệu duy nhất.

## 9. Thứ tự thiết kế wireframe

1. Auth và app shell.
2. Member Home → gói tập → chọn Coach.
3. Coach Home → yêu cầu → Member detail.
4. Giáo trình, dinh dưỡng và lịch tập.
5. Progress Tracking.
6. Messaging và Voice/Video Call.
7. AI Advisor và Gym Content.
8. Admin Dashboard và các trang CRUD.

Mỗi nhóm phải hoàn tất wireframe cho trạng thái bình thường, loading, rỗng, lỗi và không có quyền trước khi bắt đầu code giao diện.

