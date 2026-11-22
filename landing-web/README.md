# Meta Gym — Landing Page (`landing-web/`)

Trang chủ giới thiệu **Hệ thống Phòng tập & Huấn luyện Cá nhân Meta Gym** (học hỏi cấu trúc chuyển đổi từ **The New Gym** & **CITIGYM**), xây dựng bằng **Vite (`^8.3.0`) + Bootstrap 5 (`^5.3.8`)** theo hướng **Mobile-first**.

> **Định vị nội dung:** Đây là trang giới thiệu thương hiệu phòng tập dành cho **khách hàng / hội viên đi tập**, không phải trang thuyết trình kỹ thuật đồ án.

---

## 1. Hướng dẫn chạy Local

```powershell
cd landing-web
npm install
npm run dev      # Chạy dev server tại http://localhost:5174
npm run build    # Kiểm tra build production ra thư mục dist/
```

---

## 2. Cấu trúc thư mục

```text
landing-web/
├── index.html                  # Khung HTML (lang="vi", data-bs-theme="dark", Be Vietnam Pro)
├── vite.config.js              # Cấu hình Vite (port 5174)
├── public/
│   ├── favicon.svg             # Favicon Meta Gym
│   └── images/                 # Ảnh không gian phòng tập & PT 1-1
│       ├── hero-gym.jpg        # Ảnh nền Hero (có scrim tối 78–98%)
│       ├── zone-strength.jpg   # Khu Tạ tự do & Strength
│       ├── zone-cardio.jpg     # Khu Cardio & Functional
│       └── pt-coaching.jpg     # Huấn luyện 1-1 cùng Coach
└── src/
    ├── components/
    │   └── icons.js            # Bộ vector icon SVG nét 1.85px thống nhất
    ├── data/
    │   └── landingData.js      # Toàn bộ dữ liệu text, gói tập, FAQ, link footer (có TODO)
    ├── styles/
    │   └── main.css            # Stylesheet Mobile-first theo DESIGN.md
    └── main.js                 # Render các section & gắn sự kiện tương tác
```

---

## 3. Quy tắc thiết kế bắt buộc cho thành viên (`DESIGN.md`)

Trước khi chỉnh sửa hoặc thêm trang mới, các thành viên cần đọc [`../DESIGN.md`](../DESIGN.md) và [`../design-system/meta-gym/MASTER.md`](../design-system/meta-gym/MASTER.md):

- **Phong cách:** **Futuristic Performance Glass** (dark-first, hiện đại, sang trọng; không cyberpunk/gaming/rainbow neon).
- **Quy tắc vật liệu 80/20:**
  - Tối thiểu **80%** giao diện là bề mặt tối đặc (`#0F1115` nền canvas, `#181B22` card solid kèm viền `1px solid #262A34`, **không blur**).
  - Tối đa **20%** sử dụng backdrop glass (`rgba(24, 27, 34, 0.78)`, `blur(12px)`) — chỉ dùng cho Navbar nổi và 1 dock tóm tắt ở Hero; Level 3 glass (`rgba(15, 17, 21, 0.90)`, `blur(18px)`) chỉ dùng cho Modal/Drawer. **Không lồng các lớp blur.**
- **Màu sắc:**
  - Coral Orange `#FF5E36`: chỉ chiếm khoảng **5–10% viewport** (dùng cho CTA chính, tab/toggle đang chọn, gói nổi bật). Chữ/icon trên nút cam bắt buộc `#FFFFFF`.
  - Coach Avatar `"LN"` (Lê Hoàng Nam): nền `#F5B041`, chữ `#181B22` đậm.
  - Semantic Green `#2ECC71` (dinh dưỡng/hoàn thành), Cool Reflection `#A9C7E8` (viền kính/nhấn nhẹ), Subtext `#8E95A5`.
- **Ảnh nền:** Khi đặt chữ lên ảnh, bắt buộc phủ dark scrim `72–84%+` để đảm bảo tương phản chữ ≥ `4.5:1`.
- **Mobile-first & Trợ năng:**
  - Thiết kế ưu tiên màn hình nhỏ (`320px/375px`) trước, mở rộng dần qua `@media (min-width: 576px / 768px / 992px)`.
  - Mọi nút, tab, link điều hướng đạt tối thiểu **`44×44px`** vùng chạm.
  - Dùng `class="tabular"` (`font-variant-numeric: tabular-nums`) cho giá tiền, giờ mở cửa, số buổi, suất Coach.
  - Chỉ animate `opacity` và `transform`, tôn trọng `prefers-reduced-motion`.

---

## 4. Các phần đã có (Skeleton) & Việc để Member làm tiếp

### Đã hoàn thiện phần sườn trên `index.html` / `main.js`:
1. **Floating Glass Navbar:** `CLB`, `Dịch vụ`, `Chính sách giá`, `Tin tức`, `MetaRewards`, nút `Tải App` & `Tập thử miễn phí`.
2. **Hero Banner:** Ảnh nền phòng tập + scrim tối, thông điệp chính, 2 CTA, 3 chỉ số cam kết, card minh họa buổi tập cùng Coach `"LN"` + 1 dock glass.
3. **Dải tiện ích miễn phí:** Locker, phòng tắm nước nóng, gửi xe & Wi-Fi, check-in QR.
4. **Không gian & Cơ sở vật chất (`#zones`):** 3 phân khu kèm ảnh 16:9.
5. **Dịch vụ & Giải pháp (`#services`):** 4 tab tương tác (*Tập luyện tự do*, *Huấn luyện 1-1*, *Dinh dưỡng & Tiến độ*, *Trợ lý AI Coach 24/7*).
6. **Đội ngũ Huấn luyện viên (`#coaches`):** Hiển thị chuyên môn và suất `x/8`.
7. **Bảng giá (`#plans`):** Toggle chuyển đổi giữa **Gói tập Gym** và **Gói PT 1-1 (Coach)**.
8. **Ứng dụng Meta Gym (`#app-companion`) & Hỏi đáp (`#faq`):** 4 điểm nổi bật của app + FAQ Accordion.
9. **Tin tức & MetaRewards (`#news`):** 3 card skeleton để team mở rộng.
10. **Form Đăng ký tập thử trực tiếp (`#trial-section`) + Modal + Footer 4 cột** (tham khảo cấu trúc CITIGYM).

### Danh sách việc để các Member làm tiếp (`TODO`):
- [ ] **Trang / Chi tiết Câu lạc bộ (CLB):** Danh sách chi nhánh, địa chỉ, bản đồ, giờ mở cửa từng cơ sở.
- [ ] **Trang Tin tức & Chi tiết bài viết (`/tin-tuc`):** Thay dữ liệu mẫu `NEWS_SKELETON` trong `src/data/landingData.js` bằng bài viết thật và trang đọc chi tiết.
- [ ] **Trang MetaRewards:** Giới thiệu cơ chế tích điểm check-in QR và đổi ưu đãi hội viên.
- [ ] **Các trang Danh mục & Chính sách ở Footer:**
  - Phương thức thanh toán (VNPay, MoMo, ZaloPay, tại quầy)
  - Chính sách bảo vệ thông tin người dùng
  - Quy trình giải quyết, tiếp nhận khiếu nại
  - Mẫu hợp đồng, chính sách và tài liệu khác
  - Trang Liên hệ chi tiết
- [ ] **Kết nối API (nếu cần):** Gửi form đăng ký tập thử về Backend (`backend/`) hoặc đồng bộ danh sách gói tập động từ API thay vì dữ liệu tĩnh.
- [ ] **Cập nhật thông tin pháp lý & mạng xã hội:** Điền Mã số thuế, địa chỉ CLB chính thức và liên kết Facebook / YouTube / TikTok thật ở Footer.
