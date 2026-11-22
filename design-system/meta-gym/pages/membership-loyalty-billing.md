# Meta Gym — Kiến trúc Thẻ Hội viên, Ưu đãi Hạng thẻ, Meta Points & Chi phí Coach 1:1

> Tài liệu đặc tả UI/UX & luồng nghiệp vụ cho Flutter App (`mobile-app/`) và đối chiếu với Screen Preview Studio (`design-system/flutter-screens/22-11-2026/`).

---

## 1. Nguyên tắc tách bạch 2 lớp chi phí (Membership vs Coach 1:1)

Để tránh rối giữa phí phòng tập định kỳ và chi phí thuê Huấn luyện viên riêng, hệ thống tách rõ **2 lớp dịch vụ độc lập nhưng liên kết ưu đãi**:

| Lớp dịch vụ | Bản chất | Quản lý trên App |
|---|---|---|
| **1. Thẻ Hội viên (Membership NFC)** | Quyền vào cửa phòng tập (thẻ kim loại NFC / QR Check-in trong ngày), sử dụng khu máy, tiện ích chung và **hệ số ưu đãi theo hạng**. | `1.1 Trang chủ` (Thẻ dọc hình quạt) · `1.2a Gói tập — Đang hiệu lực` (Thẻ ngang 16:10) · `1.2b Chưa đăng ký`. |
| **2. Gói Coach 1:1 (PT Add-on)** | Chi phí thuê riêng từng HLV theo số buổi (`12 / 24 / 36 buổi`, khung `90 phút`). Mua nối thêm hoặc đổi Coach **không ảnh hưởng** thời hạn Thẻ Hội viên. | `1.3 Lịch Coach` · `5.6a/b Coach & Lịch hẹn` · `5.9 Xem gói Coach`. |

---

## 2. Hệ thống 4 Hạng Thẻ & Quyền lợi (Tier Perks)

Mỗi thẻ có **2 mặt đồng bộ**: hiển thị **dọc (2:3)** dạng hình quạt ở `1.1 Trang chủ` và **ngang (16:10)** tràn viền tại `1.2a Gói tập` & Modal kích hoạt.

| Hạng thẻ | Chu kỳ mẫu | Giá tham khảo | Giảm phí Coach 1:1 | Hệ số Meta Points | Quyền lợi nổi bật |
|---|---|---|---|---|---|
| **Hạng Đồng** (`card_bronze.jpg`) | 1 Tháng | `890.000đ` | `0%` | `×1.0` | Thẻ Đồng NFC · Full khu máy & Locker cá nhân |
| **Hạng Bạc** (`card_silver.jpg`) | 3 Tháng | `2.490.000đ` | **`-3%`** | `×1.2` | Thẻ Bạc NFC · 1 lần đo InBody + Tư vấn lộ trình |
| **Hạng Vàng** (`card_gold.jpg` / `card_gold_horizontal.jpg`) | 6 Tháng | `4.490.000đ` | **`-5%`** | `×1.5` | Thẻ Vàng NFC · InBody hàng tháng · Tặng 2 buổi PT 1:1 |
| **Hạng Kim Cương** (`card_diamond.jpg`) | 12 Tháng | `8.490.000đ` | **`-10%`** | `×2.0` | Thẻ Kim Cương NFC · InBody không giới hạn · Ưu tiên lịch Coach · 6 buổi PT 1:1 |

---

## 3. Hệ thống Điểm thưởng (Meta Points)

- **Nguồn tích điểm chung cho cả 2 lớp dịch vụ:**
  - Điểm danh QR / quẹt thẻ NFC hợp lệ tại phòng tập.
  - Hoàn thành buổi tập / chuỗi ngày tập (Streak).
  - Mua mới, gia hạn Thẻ Hội viên và mua Gói Coach 1:1 (nhân theo hệ số hạng thẻ).
- **Quy đổi ưu đãi (`1.2a → Đổi điểm ưu đãi`):**
  - `300 điểm` → Voucher giảm `100.000đ` (dùng khi gia hạn thẻ hoặc mua gói Coach).
  - `400 điểm` → 1 lần đo InBody VIP + báo cáo phân tích cho Coach.
  - `900 điểm` → 1 buổi PT 1:1 trải nghiệm (90 phút).
- **Lên hạng tự động:** Thanh tiến độ trên `1.2a` hiển thị số điểm còn thiếu để nâng lên hạng kế tiếp (ví dụ `1.240 / 2.000 điểm` lên Hạng Kim Cương).

---

## 4. Luồng Gia hạn, Đăng ký & Thanh toán 4 cổng (`1.2c`)

1. **Điểm vào Checkout (`1.2c Thanh toán gói tập`):**
   - Từ `1.2b Gói tập (Chưa đăng ký)` → **Đăng ký ngay →** / **Chọn gói**.
   - Từ `1.2a Gói tập (Đang hiệu lực)` → **Gia hạn thẻ** hoặc carousel **Nâng cấp hạng thẻ**.
   - Từ `5.9 Xem gói Coach` → **Chọn gói & Thanh toán** *(tự động trừ `-5%` đặc quyền Hạng Vàng)*.
2. **4 cổng thanh toán hỗ trợ:**
   - **Ví MoMo** (xác nhận tức thì)
   - **Ví ZaloPay** (hoàn tiền 2%)
   - **VNPay QR / Thẻ nội địa** (35+ ngân hàng)
   - **Chuyển khoản ngân hàng (VietQR / CK)** — mở khung số tài khoản + nội dung chuyển khoản tự động đối soát 24/7.
3. **Kích hoạt & Đối soát tập trung:**
   - Thanh toán thành công → bật **Modal Kích hoạt Thẻ NFC** → chuyển thẳng về `1.2a Gói tập (Đang hiệu lực)`.
   - Mọi hóa đơn (cả **Thẻ Hội viên** lẫn **Gói Coach 1:1**) được gom vào `1.4 Thanh toán & Giao dịch` với bộ lọc 3 tab: **`Tất cả | Thẻ Hội viên | Gói Coach`** kèm số điểm Meta Points đã cộng trên từng hóa đơn.
