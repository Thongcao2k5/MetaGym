# Changelog — MetaGym

Tài liệu ghi nhận toàn bộ lịch sử phiên bản phát hành trên nhánh **`main`** (gắn liền với Git Tag `vX.Y.Z` và [GitHub Releases](https://github.com/Thongcao2k5/MetaGym/releases)).

Mỗi đợt phát hành gồm **2 phần rõ ràng**:
1. **Ghi chú phát hành cho Cửa hàng / Người dùng (Store Release Notes — "What's New")**: dùng để copy thẳng lên Google Play, App Store hoặc báo cáo tiến độ (ngôn ngữ thân thiện, không chứa thuật ngữ kỹ thuật nội bộ).
2. **Chi tiết kỹ thuật (Technical Summary)**: danh sách PR/module thay đổi, version build, DB migrations và kết quả kiểm chứng.

---

## [v1.0.0] — 2026-11-24 *(Release Đợt 1 — Baseline Tích Hợp)*

### Ghi chú phát hành cho Cửa hàng / Người dùng (What's New)

**Tính năng mới:**
- Ra mắt giao diện ứng dụng di động **MetaGym** hoàn chỉnh cho Hội viên (Member) và Huấn luyện viên (Coach): Trang chủ, Gói hội viên 4 hạng thẻ, Đặt lịch Coach, Thanh toán trực tuyến (VNPay / MoMo / ZaloPay), Bài viết khám phá và chế độ dùng thử ngoại tuyến.
- Nâng cấp màn hình **Tập luyện (Tab 2 Training Hub)** hiển thị trạng thái gói tập, lịch tự tập theo nhóm cơ và truy cập nhanh nhật ký dinh dưỡng.
- Nâng cấp toàn diện khu vực **Hồ sơ cá nhân (Tab 5 Member Profile 5.1–5.14)**, chỉ số cơ thể, bảo mật tài khoản và luồng Coaching theo phong cách giao diện kính mờ hiện đại.
- Hoàn thiện hệ thống **Admin Web** (quản lý tài khoản, gói tập, thanh toán tại quầy, thiết bị, bài tập, đối soát, nhật ký hệ thống) và **Landing Web** giới thiệu thương hiệu.

**Cải tiến & Sửa lỗi:**
- Tối ưu độ tương phản giao diện Dark/Light, kích thước vùng chạm tối thiểu và phản hồi xúc giác (haptic feedback) trên di động.
- Bổ sung luồng xử lý minh bạch khi khóa/mở khóa Coach (tạm dừng/hoàn tiền) và quy trình kết thúc sớm 72 giờ.

### Chi tiết kỹ thuật (Technical Summary)

- **Tag / GitHub Release:** [`v1.0.0`](https://github.com/Thongcao2k5/MetaGym/releases/tag/v1.0.0) · **PR phát hành:** [#24](https://github.com/Thongcao2k5/MetaGym/pull/24)
- **Phiên bản thành phần:** `mobile-app` (`1.0.0+1`), `backend` (`1.0.0`), `admin-web` (`0.0.0`), `landing-web` (`1.0.0`)
- **PR tích hợp chính:** [#16](https://github.com/Thongcao2k5/MetaGym/pull/16) (Web Admin T1–T19), [#22](https://github.com/Thongcao2k5/MetaGym/pull/22) (Mobile Tab 5 Profile), [#23](https://github.com/Thongcao2k5/MetaGym/pull/23) (Mobile Tab 2 Training Hub)
- **Database Migrations:** `0001` → `0033` (đã qua CI PostgreSQL 17 & `schema_assertions.sql`)
- **Backend & Deploy:** Thêm `/database` dev UI (tự tắt khi `NODE_ENV=production`), Render API deploy xanh, Cloudflare Pages (`metagym-admin`, `metagym-landing`) xanh.
- **Kiểm chứng:** Flutter 93/93 tests đạt (0 errors), Admin Web 35/35 tests đạt, Backend syntax & unit tests đạt.

---

<!--
MẪU CHO ĐỢT RELEASE TIẾP THEO (copy khi tạo release/vX.Y.Z):

## [v1.1.0] — YYYY-MM-DD *(Release Đợt 2)*

### Ghi chú phát hành cho Cửa hàng / Người dùng (What's New)
**Tính năng mới:**
- ...

**Cải tiến:**
- ...

**Sửa lỗi:**
- ...

### Chi tiết kỹ thuật (Technical Summary)
- **Tag / GitHub Release:** `v1.1.0` · **PR phát hành:** `#...`
- **Phiên bản thành phần:** `mobile-app` (`1.1.0+2`), `backend` (`1.1.0`)
- **PR tích hợp từ `develop`:** `#...`, `#...`
- **Database Migrations:** Không (hoặc `0034_...`)
- **Kiểm chứng:** ...
-->
