# Thư mục `images/explore` — Ảnh bìa Chuyên đề Khám phá Meta Gym

## 1. Vị trí sử dụng trên App
- **Danh sách & Chi tiết Bài viết Khám phá (`ExploreArticleType`):** `mobile-app/lib/features/member/presentation/member_explore_articles.dart` (được mở từ mục `Khám phá Meta Gym` trên Trang chủ Hội viên `member_dashboard_view.dart`).

## 2. Mô tả thiết kế & Quy chuẩn kỹ thuật
- **Ánh xạ Key-Value chuẩn:** Khớp với 2 giá trị của `enum ExploreArticleType`:
  1. `gymIntroduction` (`id: 'explore-meta-gym'` — *"Khám phá phòng tập Meta Gym"*): Góc chụp tổng quan nối từ Zone 1 (Sảnh đón & cổng QR) vào Zone 2 & 3 (Khu thiết bị tập luyện tầng trệt), thể hiện không gian hiện đại, sạch sẽ và chuyên nghiệp.
  2. `beginnerGuide` (`id: 'beginner-training-guide'` — *"Hướng dẫn tập luyện cho người mới"*): Góc chụp Zone 4 (Khu khởi động / Cardio sát kính tầng trệt) hoặc HLV hướng dẫn hội viên mới làm quen mức tạ nhẹ an toàn.
- **Kích thước & Dung lượng:** `960×540` (`16:9`), định dạng `.webp` (`≤ 50–70 KB`).

## 3. Danh sách `assetKey` trong thư mục
- `default.png`: Ảnh mặc định hiện hành.
- `explore_gym_intro.webp`: Ảnh bìa bài *"Khám phá phòng tập Meta Gym"*.
- `explore_beginner_guide.webp`: Ảnh bìa bài *"Hướng dẫn tập luyện cho người mới"*.
