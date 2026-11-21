# Web Admin Meta Gym — danh sách thực hiện

Chi tiết, phụ thuộc, nghiệm thu và cách kiểm chứng của từng task nằm trong [web-admin-plan.md](web-admin-plan.md). Repository đã xác minh trực tiếp tại `f:/AndroidProjects/MetaGym` trên nhánh `thong` (Bước 0a `0dad52c` & Bước 0b `7770698` trên nền `f4a53b0`).

## Giai đoạn 0 — Xác minh và hợp đồng
- [x] T1. Kiểm toán repository và chênh lệch nghiệp vụ (`docs/requirements/web-admin-t1-audit.md`, commit `73e2971`)
- [x] T2. Chốt D1–D7 và ma trận trạng thái (`docs/requirements/web-admin-decisions-and-states.md`, commit `244e732`)
- [x] T3. Chốt hợp đồng API, migration và quyền riêng tư (`docs/requirements/web-admin-api-contract.md`, commit `1ef8494`)
- [x] Checkpoint 0. Baseline chạy được, quyết định và contract đã chốt (`backend` check + Postgres tests PASS, `admin-web` 7/7 + build PASS, `mobile-app` 216/216 PASS, migration `0001`..`0028` + `schema_assertions.sql` PASS)

## Giai đoạn 1 — Thiết kế
- [x] T4. Brief, sitemap và hành trình tác vụ (`design-system/meta-gym/pages/admin-web.md`, commit `0105e2c`)
- [x] T5. Wireframe và preview luồng rủi ro cao (`docs/previews/admin-web-preview.html`, commit `0331759`)
- [x] T6. Component và giao diện chi tiết (`design-system/meta-gym/adapters/bootstrap-theme.css`, commit `b696627`)
- [x] Checkpoint 1. Duyệt thiết kế trước khi sửa Web Admin (đã duyệt `docs/previews/admin-web-preview.html` và bắt đầu Giai đoạn 2)

## Giai đoạn 2 — MVP
- [x] T7. Xác thực Admin và audit nền (backend `1fb5dc4`, Flutter Web Admin notice `8ccc92a`)
- [x] T8. App shell và pattern dữ liệu (`admin-web` Dark Graphite Operate Mode & ESM `9b477f4`)
- [x] T9. Tài khoản Member/Coach (backend + `0029`–`0030` `a3c4b7e`, web UI `212695e`, Flutter sync `99c7c50`)
- [x] T10. Danh mục gói Gym/Coach và entitlement (backend `6b86b29`, web UI `1444628`, Flutter sync `99c7c50`)
- [x] T11. Giao dịch tại quầy Gym và lịch sử (backend + `0031` `1e6a40c`, web UI `62fa483`)
- [x] Checkpoint 2. Luồng tài khoản/gói/thanh toán chạy đầu-cuối (migration `0001`..`0031` / 55 bảng + `schema_assertions.sql` PASS, `backend` check & Postgres tests PASS, `admin-web` tests & build PASS, `mobile-app` `flutter analyze` & `flutter test` PASS)

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
