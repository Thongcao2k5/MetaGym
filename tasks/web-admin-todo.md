# Web Admin Meta Gym — danh sách thực hiện

Chi tiết, phụ thuộc, nghiệm thu và cách kiểm chứng của từng task nằm trong [web-admin-plan.md](web-admin-plan.md). Repository đã xác minh trực tiếp tại `f:/AndroidProjects/MetaGym` trên nhánh `feat/web-admin` (Bước 0a `0bb5e61` & Bước 0b `0a95ef2`).

## Giai đoạn 0 — Xác minh và hợp đồng
- [x] T1. Kiểm toán repository và chênh lệch nghiệp vụ (`docs/requirements/web-admin-t1-audit.md`, commit `a22c433`)
- [x] T2. Chốt D1–D7 và ma trận trạng thái (`docs/requirements/web-admin-decisions-and-states.md`, commit `288b341`)
- [x] T3. Chốt hợp đồng API, migration và quyền riêng tư (`docs/requirements/web-admin-api-contract.md`, commit `96035ea`)
- [x] Checkpoint 0. Baseline chạy được, quyết định và contract đã chốt (`backend` check + 87/88 Postgres tests PASS, `admin-web` 7/7 + build PASS, `mobile-app` 216/216 PASS, migration `0001`..`0028` + `schema_assertions.sql` PASS)

## Giai đoạn 1 — Thiết kế
- [x] T4. Brief, sitemap và hành trình tác vụ (`design-system/meta-gym/pages/admin-web.md`, commit `74471fb`)
- [x] T5. Wireframe và preview luồng rủi ro cao (`docs/previews/admin-web-preview.html`, commit `6d19e60`)
- [x] T6. Component và giao diện chi tiết (`design-system/meta-gym/adapters/bootstrap-theme.css`, commit `9cfad02`)
- [ ] Checkpoint 1. Duyệt thiết kế trước khi sửa Web Admin (chờ chủ sản phẩm nghiệm thu `docs/previews/admin-web-preview.html`)

## Giai đoạn 2 — MVP
- [ ] T7. Xác thực Admin và audit nền
- [ ] T8. App shell và pattern dữ liệu
- [ ] T9. Tài khoản Member/Coach
- [ ] T10. Danh mục gói Gym/Coach và entitlement
- [ ] T11. Giao dịch tại quầy Gym và lịch sử
- [ ] Checkpoint 2. Luồng tài khoản/gói/thanh toán chạy đầu-cuối

## Giai đoạn 3 — Quan hệ và ngoại lệ
- [ ] T12. Quan hệ và kết thúc sớm
- [ ] T13. Hàng chờ sự cố và chuyển Coach
- [ ] T14. Hoàn tiền mô phỏng
- [ ] T15. Dashboard theo dữ liệu thật
- [ ] Checkpoint 3. Khóa/chờ/chuyển/hoàn/kết thúc được kiểm chứng đầu-cuối

## Giai đoạn 4 — Hoàn thiện và phát hành
- [ ] T16. Thực phẩm và kcal
- [ ] T17. Phòng gym và thiết bị
- [ ] T18. Audit, bảo mật, khả dụng và hiệu năng
- [ ] T19. Staging, diễn tập migration và phát hành
- [ ] Checkpoint cuối. Nghiệm thu staging và smoke test production
