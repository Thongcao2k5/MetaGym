BEGIN;

ALTER TABLE media_assets DROP CONSTRAINT media_assets_purpose_check;
ALTER TABLE media_assets ADD CONSTRAINT media_assets_purpose_check
  CHECK (purpose IN (
    'AVATAR',
    'MESSAGE',
    'PROGRESS_PHOTO',
    'MEAL_PHOTO',
    'EQUIPMENT',
    'GYM',
    'COACH_OUTCOME',
    'PACKAGE',
    'SYSTEM_ICON'
  ));

INSERT INTO system_settings (key, value)
VALUES
  (
    'legal_privacy_policy',
    '{
      "title": "Chính sách bảo mật",
      "badge": "BẢO VỆ DỮ LIỆU CÁ NHÂN",
      "version": "1.0",
      "effectiveDate": "2026-11-01",
      "contactEmail": "privacy@metagym.vn",
      "summary": "Mã hóa chuẩn AES-256 · Tuân thủ Nghị định 13/2023/NĐ-CP về bảo vệ dữ liệu cá nhân.",
      "sections": [
        {
          "id": "collected-data",
          "heading": "1. Dữ liệu chúng tôi thu thập",
          "body": "• Định danh: Họ tên, Email, Số điện thoại, Ngày sinh.\n• Sức khỏe & Tập luyện: Chiều cao, Cân nặng, BMI, InBody, nhật ký tập, lịch sử điểm danh QR/NFC.\n• Giao dịch: Mã hóa đơn gói tập (không lưu số thẻ ngân hàng)."
        },
        {
          "id": "coach-sharing",
          "heading": "2. Chia sẻ dữ liệu với Coach",
          "body": "Chỉ số cơ thể và nhật ký dinh dưỡng chỉ được chia sẻ với Huấn luyện viên đang trực tiếp phụ trách bạn. Bạn có thể bật hoặc tắt quyền này bất kỳ lúc nào tại Hồ sơ → Quyền riêng tư."
        },
        {
          "id": "biometric",
          "heading": "3. Bảo mật Sinh trắc học (Face ID / Vân tay)",
          "body": "Dữ liệu khuôn mặt và vân tay chỉ được xử lý cục bộ trong vùng bảo mật phần cứng (Secure Enclave / Keystore) trên điện thoại của bạn. Meta Gym không bao giờ thu thập hay lưu trữ lên máy chủ."
        },
        {
          "id": "data-rights",
          "heading": "4. Quyền kiểm soát & Xóa dữ liệu",
          "body": "Bạn có quyền xem, tải xuống bản sao dữ liệu hoặc yêu cầu xóa vĩnh viễn tài khoản trong vòng 7 ngày làm việc qua privacy@metagym.vn."
        }
      ]
    }'::jsonb
  ),
  (
    'legal_terms_of_service',
    '{
      "title": "Điều khoản sử dụng",
      "subtitle": "Meta Gym Member Agreement · Áp dụng cho Hội viên & Coach",
      "version": "1.0",
      "effectiveDate": "2026-11-01",
      "contactEmail": "legal@metagym.vn",
      "sections": [
        {
          "id": "account-nfc",
          "heading": "1. Tài khoản & Thẻ Hội viên NFC",
          "body": "Mỗi hội viên sử dụng một tài khoản định danh duy nhất. Thẻ hội viên kim loại NFC và mã QR Check-in trong ngày chỉ phục vụ cá nhân đăng ký và không được chuyển nhượng hoặc chia sẻ cho người khác."
        },
        {
          "id": "plans-cancellation",
          "heading": "2. Gói tập, Coach 1:1 & Chính sách hủy lịch",
          "body": "• Gói tập kích hoạt ngay sau khi thanh toán thành công qua MoMo, VNPay hoặc chuyển khoản.\n• Buổi tập 1:1 với Coach cần thông báo hủy hoặc đổi lịch trước tối thiểu 12 giờ để bảo lưu số buổi.\n• Yêu cầu bảo lưu gói tập từ 15 ngày trở lên cần xác nhận tại quầy lễ tân hoặc hỗ trợ trực tuyến."
        },
        {
          "id": "safety-parq",
          "heading": "3. An toàn tập luyện & Khai báo sức khỏe",
          "body": "Hội viên cam kết khai báo trung thực các chỉ số cơ thể, tiền sử chấn thương và bệnh nền trong mục Khai báo thể trạng (PAR-Q) để Huấn luyện viên xây dựng giáo án an toàn, phù hợp nhất."
        },
        {
          "id": "ip-contact",
          "heading": "4. Quyền sở hữu & Liên hệ pháp lý",
          "body": "Toàn bộ giáo trình, bài viết dinh dưỡng và thương hiệu thuộc quyền sở hữu của Meta Gym Studio. Mọi câu hỏi xin gửi về legal@metagym.vn."
        }
      ]
    }'::jsonb
  ),
  (
    'home_quick_icons',
    '{
      "items": [
        { "key": "action_schedule", "label": "Lịch tập tuần", "subtitle": "Xem lịch buổi tập & đặt lịch Coach", "roleTarget": "MEMBER", "route": "/schedule", "assetFile": "action_schedule_3d.webp", "mediaId": null, "accentColor": "#FF5E36", "sortOrder": 1, "enabled": true },
        { "key": "action_curriculum", "label": "Giáo trình tập", "subtitle": "Mở bài tập & kế hoạch ngày hôm nay", "roleTarget": "MEMBER", "route": "/training", "assetFile": "action_curriculum_3d.webp", "mediaId": null, "accentColor": "#FF5E36", "sortOrder": 2, "enabled": true },
        { "key": "action_nutrition", "label": "Dinh dưỡng", "subtitle": "Ghi nhận bữa ăn & mục tiêu kcal", "roleTarget": "MEMBER", "route": "/nutrition", "assetFile": "action_nutrition_3d.webp", "mediaId": null, "accentColor": "#2ECC71", "sortOrder": 3, "enabled": true },
        { "key": "action_coach", "label": "Huấn luyện viên 1:1", "subtitle": "Kết nối & trao đổi trực tiếp với Coach", "roleTarget": "MEMBER", "route": "/coaching", "assetFile": "action_coach_3d.webp", "mediaId": null, "accentColor": "#FF5E36", "sortOrder": 4, "enabled": true },
        { "key": "equip_machine", "label": "Thiết bị phòng tập", "subtitle": "Tra cứu máy tập & hướng dẫn an toàn", "roleTarget": "ALL", "route": "/equipment", "assetFile": "equip_machine_3d.webp", "mediaId": null, "accentColor": "#70AEE8", "sortOrder": 5, "enabled": true },
        { "key": "checkin_badge", "label": "Điểm danh QR / NFC", "subtitle": "Quét mã vào cửa & tích điểm Meta Points", "roleTarget": "MEMBER", "route": "/checkin", "assetFile": "checkin_badge_3d.webp", "mediaId": null, "accentColor": "#FF5E36", "sortOrder": 6, "enabled": true },
        { "key": "body_weight_scale", "label": "Chỉ số cơ thể", "subtitle": "Theo dõi cân nặng, BMI & lịch sử InBody", "roleTarget": "MEMBER", "route": "/progress", "assetFile": "body_weight_scale_3d.webp", "mediaId": null, "accentColor": "#70AEE8", "sortOrder": 7, "enabled": true },
        { "key": "coach_search", "label": "Tìm Coach phù hợp", "subtitle": "Khám phá HLV theo chuyên môn & lịch trống", "roleTarget": "MEMBER", "route": "/coaches", "assetFile": "coach_search_3d.webp", "mediaId": null, "accentColor": "#F5B041", "sortOrder": 8, "enabled": true }
      ]
    }'::jsonb
  ),
  (
    'payment_methods',
    '{
      "methods": [
        { "code": "MOMO", "name": "Ví điện tử MoMo", "channelLabel": "Trực tuyến (App)", "providerNote": "Cổng thanh toán MoMo QR / App", "minAmount": 1000, "maxAmount": 50000000, "feeNote": "Miễn phí giao dịch", "instructions": "Quét mã QR MoMo hoặc mở ví MoMo để xác nhận tức thì trong 15 phút.", "supportsGymPlans": true, "supportsCoachPackages": true, "sortOrder": 1, "enabled": true },
        { "code": "ZALOPAY", "name": "Ví điện tử ZaloPay", "channelLabel": "Trực tuyến (App)", "providerNote": "Cổng ZaloPay QR & ứng dụng", "minAmount": 1000, "maxAmount": 50000000, "feeNote": "Miễn phí giao dịch", "instructions": "Thanh toán qua ZaloPay và tự động đối soát trạng thái đơn hàng.", "supportsGymPlans": true, "supportsCoachPackages": true, "sortOrder": 2, "enabled": true },
        { "code": "VNPAY", "name": "VNPay QR & Thẻ nội địa", "channelLabel": "Trực tuyến (App)", "providerNote": "Napas / Visa / Mastercard qua VNPay", "minAmount": 10000, "maxAmount": 100000000, "feeNote": "Miễn phí QR nội địa", "instructions": "Hỗ trợ hơn 35 ngân hàng Việt Nam qua mã VNPay QR hoặc thẻ ATM nội địa.", "supportsGymPlans": true, "supportsCoachPackages": true, "sortOrder": 3, "enabled": true },
        { "code": "FRONT_DESK", "name": "Thanh toán tại quầy lễ tân", "channelLabel": "Tại quầy phòng tập", "providerNote": "Tiền mặt / Chuyển khoản trực tiếp quầy", "minAmount": 0, "maxAmount": 200000000, "feeNote": "Không phụ phí", "instructions": "Thu ngân tạo đơn tại quầy có Idempotency-Key. Chỉ áp dụng cho gói Gym.", "supportsGymPlans": true, "supportsCoachPackages": false, "sortOrder": 4, "enabled": true },
        { "code": "MOCK_QR", "name": "QR mô phỏng nội bộ", "channelLabel": "Sandbox kiểm thử", "providerNote": "Chỉ bật khi chạy môi trường thử nghiệm", "minAmount": 0, "maxAmount": 50000000, "feeNote": "Không phát sinh tiền thật", "instructions": "Phục vụ kiểm thử luồng kích hoạt gói nhanh khi chưa cấu hình cổng thanh toán.", "supportsGymPlans": true, "supportsCoachPackages": true, "sortOrder": 5, "enabled": true }
      ]
    }'::jsonb
  )
ON CONFLICT (key) DO NOTHING;

COMMIT;
