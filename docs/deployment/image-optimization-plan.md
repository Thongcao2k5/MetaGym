# Kế hoạch tối ưu dung lượng ảnh tĩnh & media trên Server (Free Tier)

Tài liệu này đề xuất phương án giảm dung lượng ảnh mà vẫn giữ độ sắc nét khi hiển thị trên **WebAdmin**, **Mobile App** và khi lưu trữ/phục vụ qua **Backend + Supabase Storage (Free 1 GB)**.

---

## 1. Hiện trạng ảnh tĩnh trong Repository

Kết quả rà soát các file ảnh hiện có trong mã nguồn (không tính `node_modules`, `build`, `.dart_tool`):

| File | Dung lượng hiện tại | Vị trí / Mục đích | Đánh giá |
|---|---|---|---|
| `mobile-app/assets/images/gym_banner.png` | **930.3 KB** | Banner trong Flutter app | Quá nặng cho ảnh tĩnh; cần chuyển sang **WebP** (hoặc JPEG tối ưu) + resize đúng kích thước hiển thị. |
| `mobile-app/assets/images/loading_arm_lift.jpg` | **413.8 KB** | Ảnh màn hình loading Flutter | Có thể nén xuống ~60–120 KB bằng WebP/JPEG progressive mà không giảm chất lượng mắt thường. |
| `admin-web/src/assets/hero.png` | **12.8 KB** | Ảnh hero của Admin Web | Nhỏ, có thể chuyển WebP hoặc nén lossless nếu muốn. |
| `mobile-app/web/icons/*.png` | **5.2 – 20.5 KB** | Icon PWA/Web | Đã nhỏ, giữ PNG để đảm bảo tương thích manifest. |
| `admin-web/public/*.svg` | **4.9 – 9.3 KB** | Favicon & icon vector | Đã nhẹ, có thể chạy SVGO nếu cần. |

> Ngoài ảnh tĩnh trong repo, các ảnh người dùng/Admin upload lên Supabase Storage (như ảnh thiết bị, ảnh đại diện, ảnh tiến độ, ảnh chat) đang đi qua `backend/src/routes/media.routes.js` và `users.routes.js` — nơi đã cài sẵn thư viện **`sharp` (`^0.35.5`)**.

---

## 2. Nguyên tắc giảm dung lượng mà vẫn giữ chất lượng

1. **Chọn đúng định dạng cho từng loại ảnh:**
   - **Ảnh chụp / banner / background** (`gym_banner`, `loading_arm_lift`, ảnh bài tập/thiết bị): dùng **WebP** (giảm 25–35% so với JPEG và 60–80% so với PNG ở cùng chất lượng nhìn thấy). Nếu cần tương thích cũ hơn, dùng JPEG (`mozjpeg`, quality `80–85`, progressive).
   - **Icon / logo / hình minh họa ít màu:** dùng **SVG** (nhẹ nhất, nét mọi độ phân giải) hoặc **PNG-8 / PNG nén lossless** (`oxipng` / `pngquant`).
2. **Không lưu độ phân giải thừa (Resize theo đúng khung hiển thị):**
   - Banner mobile/web: chiều rộng tối đa `1200px–1440px` (thay vì ảnh gốc 3000–4000px).
   - Ảnh card/thumbnail: `400px–800px`.
   - Ảnh avatar: `256px–512px`.
3. **Loại bỏ metadata thừa (EXIF, ICC profile không cần thiết, comment):**
   - Thường tiết kiệm thêm 5–15% dung lượng mỗi file mà không đụng tới pixel ảnh.

---

## 3. Kế hoạch thực hiện theo 3 lớp

### Lớp 1: Tối ưu ảnh tĩnh có sẵn trong Source Code (làm ngay, 1 lần)
- **Mục tiêu:** Giảm tổng dung lượng thư mục `mobile-app/assets/images/` từ ~1.34 MB xuống dưới **250–300 KB** (giảm ~75–80%).
- **Hành động cụ thể:**
  1. Chuyển `gym_banner.png` (930.3 KB) sang `gym_banner.webp` (hoặc nén lại nếu code đang hardcode đuôi `.png`, hoặc cập nhật reference trong Dart + `pubspec.yaml`), resize max-width `1200px`, quality `82–85`.
  2. Tối ưu `loading_arm_lift.jpg` (413.8 KB): resize đúng kích thước hiển thị (max-width `1000px`), nén lại ở quality `80–82` (progressive JPEG hoặc WebP).
  3. Nén lossless các file PNG nhỏ trong `admin-web/src/assets/` và `mobile-app/web/icons/`.
- **Công cụ gợi ý:** Có thể dùng ngay `sharp` (đã có sẵn trong `backend/node_modules`) qua một script Node nhỏ, hoặc công cụ miễn phí như [Squoosh](https://squoosh.app/) / `cwebp`.

### Lớp 2: Tối ưu ảnh tĩnh khi WebAdmin / Server phục vụ (Cloudflare Pages & Render)
1. **Cache-Control dài hạn cho static assets:**
   - Khi build `admin-web` bằng Vite (`npm run build`), các file trong `src/assets/` được hash tên file tự động (ví dụ `hero-abc123.png`).
   - Cloudflare Pages mặc định cache static assets ở CDN edge, giúp trình duyệt không phải tải lại ảnh nhiều lần → giảm tải hoàn toàn cho server gốc.
2. **Lazy loading cho ảnh trên WebAdmin:**
   - Với các danh sách có nhiều ảnh (thiết bị, bài tập, hội viên), thêm thuộc tính `loading="lazy"` và `decoding="async"` vào thẻ `<img>` để trình duyệt chỉ tải ảnh khi cuộn tới.

### Lớp 3: Chuẩn hóa nén ảnh khi Upload lên Backend (bảo vệ hạn mức 1 GB Supabase Storage)
Hiện tại `backend/src/routes/media.routes.js` và `users.routes.js` đã dùng `sharp` (`limitInputPixels: 20000000`). Để tiết kiệm tối đa dung lượng Supabase Storage Free (1 GB) và băng thông Render Free:
1. **Giới hạn kích thước đầu ra bằng `sharp` trước khi lưu:**
   - Resize theo tỷ lệ (`fit: 'inside', withoutEnlargement: true`) về tối đa `1280x1280` (ảnh nội dung/tiến độ) hoặc `512x512` (avatar).
2. **Nén chuẩn trước khi upload lên bucket `meta-gym-media`:**
   - Xuất sang **WebP** (`quality: 82`) hoặc **JPEG** (`quality: 82, mozjpeg: true`) nếu giữ định dạng `image/jpeg`, `image/png`.
   - Tự động xóa EXIF metadata (`rotate()` theo EXIF rồi strip metadata mặc định của `sharp`) để vừa xoay đúng chiều ảnh chụp từ điện thoại, vừa giảm dung lượng.
3. **Tạo thumbnail (nếu cần cho danh sách dài):**
   - Khi xem danh sách thiết bị/bài tập/tin nhắn, có thể dùng bản ảnh nhỏ (`~400px`) thay vì tải ảnh gốc `> 1000px`.

---

## 4. Open Source miễn phí trên GitHub (Tài liệu tham khảo cho Agent Coding)

Các công cụ/thư viện mã nguồn mở miễn phí dưới đây đã được kiểm chứng và phù hợp nhất với kiến trúc Free Tier của MetaGym (không cần thuê thêm server/proxy riêng):

| Dự án GitHub | Vai trò trong MetaGym | Ghi chú triển khai cho Agent |
|---|---|---|
| **[lovell/sharp](https://github.com/lovell/sharp)** | Xử lý, resize, nén & đổi định dạng ảnh phía Backend và script local | **Đã cài sẵn** trong `backend/package.json` (`^0.35.5`). Dùng `libvips`, hỗ trợ WebP/AVIF/MozJPEG, `.rotate()` theo EXIF và tự strip metadata. |
| **[FatehAK/vite-plugin-image-optimizer](https://github.com/FatehAK/vite-plugin-image-optimizer)** | Tự động nén ảnh tĩnh lúc build `admin-web/` | Plugin Vite dùng `sharp` + `svgo`. Nén PNG/JPEG/WebP/SVG trong `src/assets/` và `public/` ngay khi `npm run build` (Cloudflare Pages). |
| **[calibreapp/image-actions](https://github.com/calibreapp/image-actions)** | Tự động nén ảnh trên GitHub Pull Request | GitHub Action miễn phí, dùng `sharp`/`libvips`, tự nén JPEG/PNG/WebP/AVIF mới thêm trong PR và commit lại vào nhánh PR. |
| **[oxipng/oxipng](https://github.com/oxipng/oxipng)** *(trước là `shssoichiro/oxipng`)* | Nén PNG **lossless** bằng CLI | Phù hợp cho icon PWA/app (`mobile-app/web/icons/*.png`) cần giữ nguyên 100% pixel gốc. |
| **[svg/svgo](https://github.com/svg/svgo)** | Tối ưu file `.svg` | Dùng cho `admin-web/public/favicon.svg`, `icons.svg` (hoặc chạy tự động qua `vite-plugin-image-optimizer`). |
| **[GoogleChromeLabs/squoosh](https://github.com/GoogleChromeLabs/squoosh)** | Công cụ web so sánh chất lượng trực quan | Dùng khi cần tinh chỉnh thủ công từng ảnh lớn (như `gym_banner`, `loading_arm_lift`) để kiểm tra mắt thường trước/sau nén. |

> **Không khuyến nghị cho gói Free:** Các image proxy tự host như `imgproxy/imgproxy` hoặc `thumbor/thumbor` miễn phí nhưng tốn RAM/CPU riêng, không phù hợp với giới hạn 512 MB RAM của Render Free.

### 4.1. Mẫu cấu hình gợi ý cho Coding Agent

#### A. Bật tối ưu ảnh lúc build `admin-web` (`admin-web/vite.config.js`)
Cài devDependency: `npm install vite-plugin-image-optimizer --save-dev` (cùng `sharp` và `svgo` nếu peer dependency yêu cầu), sau đó cấu hình:

```javascript
import { defineConfig } from 'vite';
import { ViteImageOptimizer } from 'vite-plugin-image-optimizer';

export default defineConfig({
  server: { proxy: { '/api': 'http://127.0.0.1:3000' } },
  plugins: [
    ViteImageOptimizer({
      test: /\.(jpe?g|png|gif|tiff|webp|svg|avif)$/i,
      includePublic: true,
      logStats: true,
      png: { quality: 80 },
      jpeg: { quality: 80 },
      jpg: { quality: 80 },
      webp: { lossless: true },
    }),
  ],
});
```

#### B. Tự động nén ảnh khi tạo PR trên GitHub (`.github/workflows/image-actions.yml`)

```yaml
name: Compress Images
on:
  pull_request:
    paths:
      - '**.jpg'
      - '**.jpeg'
      - '**.png'
      - '**.webp'
      - '**.avif'

jobs:
  build:
    name: calibreapp/image-actions
    runs-on: ubuntu-latest
    if: github.event.pull_request.head.repo.full_name == github.repository
    steps:
      - name: Checkout Repo
        uses: actions/checkout@v4
      - name: Compress PR Images
        uses: calibreapp/image-actions@main
        with:
          githubToken: ${{ secrets.GITHUB_TOKEN }}
```

---

## 5. Thứ tự ưu tiên triển khai

1. **Ưu tiên 1 (Nhanh nhất):** Nén 2 ảnh lớn nhất trong `mobile-app/assets/images/` (`gym_banner.png` 930.3 KB và `loading_arm_lift.jpg` 413.8 KB) bằng `sharp` hoặc Squoosh (lưu ý cập nhật đường dẫn trong Dart và `pubspec.yaml` nếu đổi đuôi `.png`/`.jpg` sang `.webp`).
2. **Ưu tiên 2:** Tích hợp `FatehAK/vite-plugin-image-optimizer` vào `admin-web/vite.config.js` và thêm `loading="lazy"` cho các danh sách ảnh trong `admin-web/`.
3. **Ưu tiên 3:** Rà soát cấu hình `sharp` trong `backend/src/routes/media.routes.js` và `users.routes.js` để đảm bảo resize + nén tối ưu trước khi đẩy lên Supabase Storage Free.
4. **Ưu tiên 4:** Thêm `.github/workflows/image-actions.yml` nếu nhóm thường xuyên push ảnh tĩnh mới qua Pull Request.
