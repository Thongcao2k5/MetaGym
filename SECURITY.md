# Security Policy — MetaGym

## Supported Branches & Versions

Các bản sửa lỗi bảo mật được áp dụng ưu tiên trên các nhánh đang duy trì:

| Nhánh / Phiên bản | Hỗ trợ bảo mật | Ghi chú |
| --- | :---: | --- |
| `main` (Production / Render) | :white_check_mark: | Nhận bản vá qua nhánh `hotfix/*` hoặc `release/*` |
| `develop` (Integration) | :white_check_mark: | Nhận bản vá qua PR từ `fix/*` hoặc `hotfix/*` |
| Các nhánh cũ (`thong`, `thuc`, `truong_ship_it`, `design`, `codex/*`) | :x: | Chỉ giữ lại để chuyển tiếp & khôi phục mã nguồn |

---

## Reporting a Vulnerability (Báo cáo lỗ hổng bảo mật)

**Vui lòng KHÔNG mở GitHub Issue công khai cho các lỗ hổng bảo mật** (lộ khóa bí mật, lỗ hổng xác thực JWT/RBAC, SQL injection, bỏ qua kiểm tra thanh toán, hoặc truy cập trái phép dữ liệu người dùng).

Hãy báo cáo riêng qua một trong hai kênh sau:
1. **GitHub Security Advisories** *(khuyên dùng)*: vào tab **Security → Advisories → Report a vulnerability** trên repository `Thongcao2k5/MetaGym`.
2. **Email trực tiếp tới Maintainer**: `minhthong0610.it@gmail.com` với tiêu đề `[SECURITY][MetaGym] <mô tả ngắn>`.

Nội dung báo cáo nên kèm theo:
- Module bị ảnh hưởng (`mobile-app/`, `backend/`, `database/`, `admin-web/`, `landing-web/`).
- Các bước tái hiện chi tiết hoặc Proof of Concept (PoC).
- Mức độ ảnh hưởng dự kiến và đề xuất khắc phục (nếu có).

**Cam kết phản hồi:**
- Xác nhận đã tiếp nhận trong vòng **48 giờ**.
- Đánh giá và lập kế hoạch bản vá `hotfix/*` trong vòng **3–7 ngày** tùy mức độ nghiêm trọng.

---

## Nguyên tắc bảo mật nội bộ cho đội phát triển

- **Không bao giờ commit** file `.env`, `DATABASE_URL`, `JWT_SECRET`, khóa LiveKit, khóa cổng thanh toán (VNPay/MoMo/ZaloPay), hoặc `RENDER_DEPLOY_HOOK_URL` vào Git.
- Chỉ dùng file mẫu `.env.example` với giá trị giả lập trong repo.
- Các bảng nghiệp vụ trên PostgreSQL/Supabase tuân thủ chính sách backend-only (không cấp quyền trực tiếp cho role `anon` / `authenticated`).
- Mọi thay đổi liên quan đến `backend/` và `database/` phải đi qua Pull Request và vượt qua CI `Check migrations on PostgreSQL` trước khi merge vào `main`.
