# Meta Gym — Bản đồ màn hình, thành phần và trạng thái UI

Ngày rà soát: 28/10/2026. Phạm vi: ứng dụng Flutter cho Member/Coach và web Admin. Đây là danh mục để thiết kế lại giao diện; không khẳng định mọi trạng thái bên dưới đã được triển khai đẹp hoặc có API tổng hợp.

## 1. Cách đọc và nguyên tắc

- **Có khung**: đã có màn hình/luồng trong mã, nhưng giao diện hiện tại chủ yếu để thử API. **Mẫu**: dữ liệu hoặc nội dung đang cố định. **Cần thiết kế**: chưa có trang riêng hoặc còn là đề xuất. **Cần API**: không thể hiển thị số liệu đáng tin cậy bằng dữ liệu hiện tại.
- Route công khai lấy từ `mobile-app/lib/app/app_router.dart` và `feature_navigation.dart`; một số trang chi tiết/form được mở bằng `Navigator.push`, không có URL riêng. Web Admin dùng hash route `#/admin/...` trong `admin-web/src/main.js`.
- Dữ liệu từ server là nguồn sự thật. Không biến `dayNumber` trong giáo trình thành ngày lịch; “bài tập hôm nay” chỉ có cơ sở khi gắn với buổi tập có `scheduledStartAt`. Nội dung dinh dưỡng hiện là văn bản tự do, chưa phải từng bữa có cấu trúc.
- Trang chủ đưa **tóm tắt + lối vào**; nội dung đầy đủ ở trang đích. Các thông số không có API phải ghi rõ “đề xuất/cần API”, không dùng số mẫu khi nối dữ liệu thật.
- Bản đồ cũ `docs/requirements/page-map.md` viết trước giao diện mới, có route và bottom navigation không còn đúng. Không dùng nó làm chuẩn điều hướng hiện tại.

## 2. Trạng thái dùng chung cho mọi màn hình

| Lớp trạng thái | Thành phần cần thiết |
|---|---|
| Khởi động/tải | Skeleton hoặc tiến trình, chặn thao tác trùng, thông báo khi tải lâu |
| Có dữ liệu | Nội dung, thời điểm/cách làm mới khi dữ liệu có thể đổi, tải thêm nếu phân trang |
| Trống lần đầu | Lời giải thích theo vai trò và một hành động cụ thể; khác với danh sách rỗng do bộ lọc |
| Lỗi | Nội dung lỗi dễ hiểu, nút Thử lại, giữ dữ liệu cũ khi làm mới thất bại |
| Không đủ điều kiện | Phân biệt chưa đăng nhập, sai vai trò, chưa có gói, gói hết hạn, không có Coach, quan hệ tạm ngưng/kết thúc, tài khoản bị khóa |
| Biểu mẫu | Ban đầu, nhập sai, đang gửi, thành công, lỗi server/xung đột; chỉ cho gửi lại an toàn |
| Truyền thông/ảnh | Đang tải, đã gửi, thất bại/cần gửi lại, ảnh lỗi hoặc URL hết hạn, không có quyền truy cập |
| Mất mạng/phiên | Hiển thị dữ liệu cũ nếu có, kết nối lại; hết phiên quay về đăng nhập và giữ điều hướng hợp lý |

Các trạng thái nghiệp vụ phải có cách biểu đạt thống nhất: gói `ACTIVE / SCHEDULED / EXPIRED`; thanh toán `PENDING / SUCCESS / FAILED / CANCELLED`; yêu cầu Coach `PENDING / ACCEPTED / REJECTED / CANCELLED`; quan hệ `ACTIVE / PAUSED / ENDED`; giáo trình và dinh dưỡng `DRAFT / ACTIVE / ARCHIVED`; buổi tập `SCHEDULED / COMPLETED / MEMBER_ABSENT / CANCELLED`; AI `PROCESSING / COMPLETED / FAILED`. Không dùng cùng một màu/chữ cho “chờ”, “tạm ngưng” và “đã kết thúc”.

## 3. Khung điều hướng và xác thực

| Trang | Thành phần chính | Trạng thái riêng | Hiện trạng |
|---|---|---|---|
| Mở app/khôi phục phiên | Logo, tiến trình, kiểm tra token, chuyển hướng theo vai trò | Chưa đăng nhập, Member, Coach, Admin, token hết hạn, lỗi mạng | Có khung |
| Chào mừng `/` | Giới thiệu ngắn, đăng nhập, đăng ký | Khách, đã có phiên | Có khung |
| Đăng nhập `/login` | Email, mật khẩu, hiện/ẩn mật khẩu, quên mật khẩu | Sai thông tin, tài khoản khóa, đang đăng nhập, thành công | Có khung |
| Đăng ký `/register` | Họ tên, email, mật khẩu/xác nhận, điều khoản nếu sản phẩm quyết định dùng | Email trùng, dữ liệu sai, đang gửi, tạo xong | Có khung |
| Quên mật khẩu `/forgot-password` | Yêu cầu mã, nhập mã, đặt mật khẩu mới | Mã chưa gửi/hết hạn/sai, gửi lại, hoàn tất | Có khung |
| Hồ sơ `/profile` | Ảnh, tên, thông tin cá nhân; Coach thêm chuyên môn/giới thiệu/giới hạn nếu API trả; sửa hồ sơ, đổi mật khẩu, đăng xuất | Chưa đủ thông tin, đang lưu, lỗi, ảnh lỗi | Có khung |
| Đổi mật khẩu `/profile/change-password` | Mật khẩu cũ/mới/xác nhận | Sai mật khẩu cũ, quy tắc mật khẩu, lưu thành công | Có khung |

Bottom navigation Member hiện có đúng 5 mục: **Trang chủ · Tập luyện · AI · Tin nhắn · Hồ sơ**; AI ở giữa. Coach hiện **chưa có** bottom navigation tương đương, chỉ là menu chức năng; thiết kế của Coach phải chốt riêng trước khi lập trình. Admin dùng sidebar web, không dùng bottom navigation.

## 4. Member — danh mục trang cần thiết kế

| Trang/đường vào | Thành phần nên có | Trạng thái nghiệp vụ phải vẽ | Hiện trạng |
|---|---|---|---|
| **Trang chủ** `/member` | Header chào/tìm kiếm/hồ sơ; banner ngắn; truy cập nhanh 2 ngăn vuốt với icon nhỏ không nền; thẻ gói; tóm tắt buổi tập/dinh dưỡng/nhật ký; khám phá; bottom nav | Người mới chưa gói; có gói không Coach; chờ Coach; có Coach chưa được giao nội dung; có Coach có lịch hôm nay; nghỉ/không có lịch; gói sắp hết hạn/hết hạn; quan hệ PAUSED; lỗi tải từng khối | Có mẫu, cần nối dữ liệu và thiết kế lại |
| **Gói tập / mua gói** cần đường vào riêng | Gói hiện tại, ngày bắt đầu/hết hạn/còn lại, số ngày đã tập *nếu định nghĩa rõ*, các gói bán, giá/quyền lợi, CTA mua/gia hạn, gói chờ kích hoạt | Chưa có gói; ACTIVE; SCHEDULED; EXPIRED; nhiều gói nối tiếp; gói ngừng bán; đang tạo thanh toán | `MembershipPage` có khung mua nhưng hiện không được mở ở đâu trong Flutter; cần gắn route/CTA |
| **Thanh toán mô phỏng** từ trang gói | Tóm tắt gói, số tiền, QR/nội dung thanh toán, nút xác nhận, kết quả | PENDING, SUCCESS, FAILED, CANCELLED, hết thời gian, xác nhận lặp, mất mạng | Nằm trong `MembershipPage` chưa được điều hướng tới |
| **Lịch sử/chi tiết thanh toán** `/member/features/payments` | Danh sách theo ngày/trạng thái; chi tiết mã, gói, giá, thời gian, phương thức | Chưa giao dịch, đang chờ, thành công, lỗi/hủy | Có khung; route hiện tại mở `PaymentHistoryPage` |
| **Khám phá Coach** `/member/features/coaching` | Danh sách Coach, ảnh, chuyên môn, suất còn, lọc/tìm nếu cần; hồ sơ Coach, nút gửi yêu cầu | Chưa có gói (được xem nhưng chặn gửi); đang chờ một yêu cầu; đã có Coach; Coach hết suất; yêu cầu vừa bị từ chối | Có khung |
| **Coach của tôi** `/member/features/my-coach` | Coach hiện tại, trạng thái quan hệ, nhắn tin, lịch, kết thúc quan hệ; yêu cầu đang chờ; lịch sử | Chưa có; PENDING/hủy; ACTIVE; PAUSED do hết gói; ENDED; yêu cầu cũ bị từ chối | Có khung |
| **Tập luyện / giáo trình** tab 2 hoặc `/member/features/training` | Giáo trình ACTIVE, mục tiêu, phiên bản, ngày/buổi/bài tập và hướng dẫn; bản cũ | Không Coach; có Coach chưa công bố; có bản hiện hành; bản ARCHIVED; PAUSED chỉ xem lịch sử | Có khung |
| **Lịch tập và buổi chi tiết** `/member/features/sessions` | Lịch ngày/tuần hoặc danh sách, giờ, Coach, địa điểm, mục tiêu, ghi chú | Không có lịch; SCHEDULED hôm nay/sắp tới; COMPLETED; MEMBER_ABSENT; CANCELLED; PAUSED | Có khung |
| **Dinh dưỡng Coach** `/member/features/nutrition` | Hướng dẫn hiện hành, mục tiêu/ghi chú, lịch sử phiên bản | Chưa có Coach; Coach chưa gửi; ACTIVE; ARCHIVED; PAUSED chỉ xem | Có khung; chưa có từng bữa có cấu trúc |
| **Tiến độ** `/member/features/progress` | Tổng quan, biểu đồ số đo theo khoảng ngày, nhật ký gần đây, nhận xét Coach, lối vào các loại dữ liệu | Chưa ghi gì; có một loại dữ liệu; nhiều dữ liệu; không đủ điểm vẽ biểu đồ; không Coach/không nhận xét | Có khung |
| **Nhật ký tập** `/member/features/workouts` | Danh sách, chi tiết, thêm bản ghi: ngày, thời lượng, nội dung, cảm nhận; nhận xét Coach | Chưa ghi → “Bắt đầu ghi lại”; có bản ghi; thêm/sửa nếu được phép; PAUSED/EXPIRED chỉ xem | Có khung |
| **Nhật ký ăn** `/member/features/meals` | Danh sách, thêm bữa: thời gian, món/ghi chú/ảnh nếu API hỗ trợ; nhận xét | Chưa ghi → “Ghi bữa đầu tiên”; có bản ghi; PAUSED/EXPIRED chỉ xem | Có khung |
| **Số đo cơ thể** `/member/features/measurements` | Lịch sử, nhập cân nặng/số đo, biểu đồ/so sánh | Chưa có; một điểm; đủ điểm; giá trị không hợp lệ | Có khung |
| **Ảnh tiến trình** `/member/features/photos` | Lưới ảnh, xem ảnh, thêm ảnh/chú thích/ngày | Chưa có; đang tải lên; ảnh lỗi; ảnh đã xóa/URL hết hạn | Có khung |
| **Tin nhắn** tab 4 | Danh sách hội thoại, số chưa đọc/thời điểm; trang chat với văn bản, ảnh, xem ảnh, gửi lại | Chưa có Coach/hội thoại; ACTIVE; PAUSED/ENDED chỉ đọc; đang gửi; gửi lỗi; tải tin cũ | Có khung; API danh sách chưa có preview văn bản |
| **Cuộc gọi** `/member/features/calls` | Lịch sử và trang trạng thái cuộc gọi | Chưa có Coach; CREATED/RINGING/ANSWERED/REJECTED/MISSED/ENDED/FAILED; PAUSED chặn gọi | Có khung trạng thái/log; cần xác nhận lại SDK thoại/video thực tế trước khi thiết kế như cuộc gọi live |
| **AI** tab giữa | Danh sách hội thoại, tạo/đổi tên/xóa; hội thoại hỏi đáp, trạng thái trả lời, nhắc giới hạn tư vấn | Chưa hội thoại; PROCESSING; COMPLETED; FAILED; AI không sẵn; hết giới hạn nếu backend có | Có khung |
| **Phòng gym/thiết bị** `/member/features/gym` | Giới thiệu cơ sở, giờ mở, danh sách thiết bị; chi tiết thiết bị và hướng dẫn | Danh mục rỗng, thiết bị ẩn/ngừng hoạt động, ảnh lỗi | Có khung |
| **Khám phá bài viết** từ Home | Danh sách bài ngắn, chi tiết giới thiệu phòng tập/Coach/hướng dẫn tập | Chưa có bài; ảnh lỗi; nội dung mới | Mẫu cố định 2 bài, chưa có CMS/API bài viết |

**Thẻ gói ở Home theo quyết định thiết kế:** không có gói → “Đăng ký ngay”; có gói mà không có Coach → vùng gói chiếm toàn khung; có Coach → 2 phần: bên gói gồm ngày còn lại và ngày đã tập (nếu có định nghĩa dữ liệu), bên Coach gồm số buổi đã tập và số buổi còn lại. Không suy ra số buổi Coach từ số buổi trong giáo trình; cần nguồn dữ liệu/định nghĩa nghiệp vụ riêng. Gói SCHEDULED phải ghi rõ ngày bắt đầu, không được tính như ACTIVE.

## 5. Coach — danh mục trang cần thiết kế

| Trang/đường vào | Thành phần nên có | Trạng thái nghiệp vụ phải vẽ | Hiện trạng |
|---|---|---|---|
| **Trang chủ** `/coach` | Header; số Member đang phụ trách/suất còn; yêu cầu mới; lịch hôm nay/tuần; việc cần làm: soạn giáo trình, dinh dưỡng, xem tiến độ; lối vào chat/AI | Coach mới chưa Member; có yêu cầu nhưng chưa nhận; hết suất; có Member ACTIVE; Member PAUSED; không lịch hôm nay; lỗi từng khối | Hiện chỉ FeatureMenu, cần thiết kế |
| **Yêu cầu chọn Coach** `/coach/features/requests` | Danh sách chờ, hồ sơ/yêu cầu chi tiết, chấp nhận/từ chối kèm lý do | Rỗng; PENDING; ACCEPTED; REJECTED; hết suất; Member vừa hết gói; xung đột khi xử lý | Có khung |
| **Hội viên của tôi** `/coach/features/members` | Danh sách, trạng thái, tìm/lọc; chi tiết Member với hồ sơ, mục tiêu, liên kết các dữ liệu | Chưa có; ACTIVE; PAUSED; ENDED trong lịch sử; hết suất; Member không còn quyền truy cập | Có khung |
| **Yêu cầu kết thúc phụ trách** từ chi tiết Member | Lý do, xác nhận, trạng thái yêu cầu | Chưa gửi; PENDING; APPROVED; REJECTED; CANCELLED; quan hệ ENDED | Có khung |
| **Giáo trình** `/coach/features/training` | Chọn Member → danh sách phiên bản → xem/soạn ngày & bài tập → công bố | Member ACTIVE/PAUSED; chưa có; DRAFT; ACTIVE; ARCHIVED; lỗi bài tập bị ẩn; xác nhận thay bản hiện hành | Có khung |
| **Dinh dưỡng** `/coach/features/nutrition` | Chọn Member → danh sách → trình biên tập → công bố | Chưa có; DRAFT; ACTIVE; ARCHIVED; Member PAUSED; lưu lỗi | Có khung; văn bản tự do |
| **Lịch/buổi tập** `/coach/features/sessions` | Danh sách lịch, tạo/sửa buổi, chọn Member, giờ/nội dung; cập nhật kết quả | Chưa có Member; chưa có buổi; SCHEDULED; COMPLETED; MEMBER_ABSENT; CANCELLED; trùng giờ/ngoài quan hệ | Có khung |
| **Tiến độ hội viên** `/coach/features/progress` | Chọn Member, số buổi/bữa/ảnh, nhật ký, số đo/ảnh, nhận xét từng bản ghi hoặc chung | Chưa có dữ liệu; có dữ liệu; đã nhận xét; Member PAUSED chỉ đọc; ảnh lỗi | Có khung; chưa có API biểu đồ riêng cho Coach |
| **Tin nhắn/cuộc gọi/AI** | Dùng các trang chung với Member nhưng danh sách theo Member | Chưa có Member; ACTIVE; PAUSED/ENDED chỉ đọc hoặc chặn gọi; trạng thái gửi/gọi/AI như mục 4 | Có khung |
| **Phòng gym/thiết bị** `/coach/features/gym` | Xem danh mục và hướng dẫn để tham khảo khi soạn bài | Rỗng, thiết bị ẩn, ảnh lỗi | Có khung |
| **Hồ sơ Coach** `/profile` | Ảnh, chuyên môn, giới thiệu, kinh nghiệm, giờ hướng dẫn, đổi mật khẩu | Hồ sơ thiếu, đang lưu, lỗi | Có khung |

Đề xuất điều hướng Coach cần quyết định trong bước thiết kế: **Trang chủ · Hội viên · AI · Tin nhắn · Hồ sơ**; lịch, giáo trình, dinh dưỡng và tiến độ nằm trong trang Hội viên và truy cập nhanh ở Home. Đây là đề xuất, chưa được cài trong Flutter.

## 6. Admin web — trang và trạng thái

| Route | Thành phần/chức năng | Trạng thái đặc thù | Hiện trạng |
|---|---|---|---|
| `#/admin/login` | Form đăng nhập | Sai quyền/sai mật khẩu, tài khoản khóa, đang đăng nhập | Có khung |
| `#/admin/dashboard` | Chỉ số Member/Coach/gói/yêu cầu/doanh thu, biểu đồ doanh thu | Không dữ liệu, lỗi tải biểu đồ, khoảng ngày | Có khung |
| `#/admin/members` | Bảng, phân trang, sửa, khóa/mở | Rỗng, ACTIVE/DISABLED, lỗi thao tác | Có khung |
| `#/admin/coaches` | Bảng, tạo/sửa Coach, giới hạn Member, khóa/mở, mật khẩu tạm | ACTIVE/DISABLED, hết suất, lỗi trùng email | Có khung |
| `#/admin/plans` | Danh sách gói, tạo/sửa, bật/tắt bán | ACTIVE/INACTIVE, có Member đang dùng, lỗi biểu mẫu | Có khung |
| `#/admin/payments` | Giao dịch, ghi nhận mua/gia hạn tại quầy, xử lý trạng thái | PENDING/SUCCESS/FAILED/CANCELLED; giao dịch trùng | Có khung |
| `#/admin/relationships` | Danh sách quan hệ, gán/chuyển Coach kèm lý do | ACTIVE/PAUSED/ENDED, Coach hết suất, xung đột | Có khung |
| `#/admin/terminations` | Yêu cầu kết thúc do Coach gửi, duyệt/từ chối | PENDING/APPROVED/REJECTED/CANCELLED | Có khung |
| `#/admin/gym` | Thông tin phòng gym | Chưa nhập, chỉnh sửa, lỗi lưu | Có khung |
| `#/admin/equipment` | Danh sách/biểu mẫu thiết bị | ACTIVE/HIDDEN, ảnh/video lỗi, rỗng | Có khung |
| `#/admin/profile` | Hồ sơ Admin, bảo mật, đăng xuất | Đang lưu, lỗi, phiên hết hạn | Có khung |

Admin web hiện là một SPA với form/bảng trong từng section; chưa cần tách mỗi biểu mẫu thành route riêng để thiết kế. Các yêu cầu loading, lỗi, xác nhận thao tác nguy cơ cao và phân trang vẫn phải có trong thiết kế.

## 7. Khoảng trống dữ liệu/thiết kế cần giải quyết trước khi vẽ chi tiết

1. **Luồng mua gói đang đứt:** `/member/features/payments` trỏ tới `PaymentHistoryPage`, còn `MembershipPage` có chức năng mua/QR không có chỗ nào mở. Phải thêm đường vào trang gói và nối CTA “Đăng ký ngay” trước khi coi luồng người mới hoàn chỉnh.
2. **Home Member:** số 18 ngày/8 buổi, 3/5 tiến độ tuần trong mẫu hiện là giả. Cần nối API gói + nhật ký/buổi tập và định nghĩa “ngày đã tập”, “buổi với Coach còn lại”. Nếu gói là không giới hạn lượt, dùng cách hiển thị khác.
3. **Home Coach:** chưa có bố cục/dashboard. Có thể lấy danh sách Member, yêu cầu và buổi tập, nhưng chưa có API tổng hợp việc “cần phản hồi”; không hiện số tồn đọng chưa xác thực.
4. **Bài viết/khám phá:** hiện 2 nội dung cố định trong app. Nếu Admin cần quản lý bài, phải bổ sung model/API/CMS; nếu chỉ demo thiết kế, ghi rõ mẫu cố định.
5. **Tìm kiếm toàn app:** header hiện có nút tìm, cần quyết định phạm vi (Coach, thiết bị, bài viết, v.v.) trước khi thiết kế trang kết quả; không hứa tìm toàn hệ thống khi chưa có API.
6. **Gọi thoại/video:** tài liệu nghiệp vụ dự định dùng SDK, nhưng code hiện chủ yếu quản lý trạng thái cuộc gọi. Phải kiểm tra và bổ sung tích hợp media thực trước khi thiết kế màn hình gọi như đã hoạt động.
7. **Dinh dưỡng dạng bữa:** hướng dẫn Coach là văn bản; nhật ký ăn là dữ liệu Member nhập. Không gộp hai nguồn thành một lịch ăn hằng ngày nếu chưa định nghĩa dữ liệu.
8. **Thông báo:** chưa thấy trang/thực thể thông báo riêng trong điều hướng hiện tại; không thêm tab thông báo vào MVP nếu không chốt nguồn sự kiện và API.

## 8. Thứ tự thiết kế để triển khai ít làm lại

1. Chốt hệ màu/chữ/khoảng cách, card, trạng thái rỗng/lỗi, input, bottom nav, dialog; làm 1 lần cho hai vai trò.
2. Vẽ **Member Home theo 6 trạng thái** ở mục 4; sau đó gói tập/thanh toán và Coach selection để giải quyết nhánh “người mới”.
3. Vẽ tập luyện, lịch, dinh dưỡng, nhật ký và tiến độ; kiểm tra cặp “có Coach / không Coach” và “ACTIVE / PAUSED”.
4. Vẽ Coach Home, yêu cầu và chi tiết Member; sau đó form giáo trình, dinh dưỡng, lịch và trang xem tiến độ.
5. Vẽ chat, AI, hồ sơ và Admin web; bổ sung trạng thái lỗi, mất mạng, nội dung dài, màn hình nhỏ.

**Tiêu chí chốt mỗi trang:** có layout ở trạng thái dữ liệu thật, rỗng, tải, lỗi; có mọi trạng thái nghiệp vụ liên quan; CTA đúng quyền; liên kết đến trang đích; tên trường khớp API; không dùng số giả dưới nhãn dữ liệu thật.

## Nguồn đã đối chiếu

- `mobile-app/lib/app/app_router.dart`, `mobile-app/lib/app/feature_navigation.dart`, các `mobile-app/lib/features/**/presentation/*page.dart`.
- `mobile-app/lib/features/member/presentation/member_dashboard_view.dart` và `member_home_page.dart`.
- `admin-web/src/main.js`.
- `backend/src/routes/{payments,coaching,training,sessions,messaging,calls,ai-conversations}.routes.js` và `backend/src/services/membership-lifecycle.js`.
- `docs/requirements/confirmed-workflows.md` (ý định nghiệp vụ, có điểm chưa trùng triển khai).
