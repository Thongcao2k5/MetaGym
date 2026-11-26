# Meta Gym — Bộ Biểu Tượng Ứng Dụng (App Launcher Icon Handoff cho Dev)

> **Phong cách:** Symmetrical Front Double Biceps • **Coral Orange** (`#FF7B52` → `#FF5E36` → `#E64A22`) trên nền **Obsidian Graphite** (`#191D26` → `#080A0E`) kèm quầng sáng ấm và tia ember mảnh phía dưới.
> **Nguồn vector gốc:** [`../svg/brand/app_icon_mark.svg`](../svg/brand/app_icon_mark.svg) & [`../svg/brand/brand_mark.svg`](../svg/brand/brand_mark.svg)

![Meta Gym App Icon Preview](./meta_gym_app_icon_preview_sheet.png)

## 1. Danh sách tệp xuất chuẩn (`1024×1024 px`)

| Tệp | Kích thước | Mục đích sử dụng |
| :--- | :---: | :--- |
| [`meta_gym_app_icon_1024.png`](./meta_gym_app_icon_1024.png) | `1024×1024` | **iOS App Store & Android Legacy** (Full-bleed hình vuông, không bo góc cứng để hệ điều hành tự cắt squircle/circle). |
| [`meta_gym_app_icon_adaptive_fg_1024.png`](./meta_gym_app_icon_adaptive_fg_1024.png) | `1024×1024` | **Android Adaptive Icon — Foreground** (nền trong suốt, biểu tượng nằm gọn trong vùng an toàn `66%` trung tâm). |
| [`meta_gym_app_icon_monochrome_1024.png`](./meta_gym_app_icon_monochrome_1024.png) | `1024×1024` | **Android 13+ Themed Icon — Monochrome** (trắng thuần `#FFFFFF` trong vùng an toàn `66%`). |
| [`meta_gym_app_icon_squircle_1024.png`](./meta_gym_app_icon_squircle_1024.png) | `1024×1024` | **Web / Pitch Deck / Store Banner** (đã bo góc squircle chuẩn kèm viền specular mỏng). |
| [`../svg/brand/notification_small_monochrome.svg`](../svg/brand/notification_small_monochrome.svg) | `24×24` SVG | **Android Status Bar Notification Icon** (đơn sắc `#FFFFFF`, lược bớt nét mảnh để rõ nét ở `24dp`). |

## 2. Triển khai Android hiện tại — Trang 0

Launcher Android trong `mobile-app/android/app/src/main/` sử dụng trực tiếp các bản xuất ở trên:

- Tên hiển thị: **Meta Gym**; `icon` và `roundIcon` cùng trỏ tới `@mipmap/ic_launcher`.
- Android cũ: `meta_gym_app_icon_1024.png` được resize bằng Lanczos thành PNG RGB vuông 48/72/96/144/192px, tương ứng các thư mục `mipmap-mdpi` đến `mipmap-xxxhdpi`. Không dùng bản squircle đã bo góc.
- Android 8+: `mipmap-anydpi-v26/ic_launcher.xml` ghép nền đặc `#0F1115` với `drawable-nodpi/ic_launcher_foreground.png`.
- Android 13+: `mipmap-anydpi-v33/ic_launcher.xml` bổ sung `drawable-nodpi/ic_launcher_monochrome.png` để launcher hỗ trợ themed icons.
- Hai layer adaptive lấy từ PNG foreground/monochrome 1024px tương ứng: resize Lanczos thành 972px, đặt giữa canvas RGBA trong suốt 1024px. Khoảng đệm bổ sung giữ phần biểu tượng trong vùng an toàn 66dp trên layer 108dp; không sửa asset nguồn.

Task này chỉ thay launcher và tên app, không sửa màn Flutter Splash/Auth hay nền giao diện. Repository hiện chưa có target iOS; cấu hình bên dưới là tham khảo cho lúc bổ sung nền tảng đó.

## 3. Cấu hình mẫu cho Flutter Dev (`flutter_launcher_icons`)

Khi triển khai sang `mobile-app/`, copy 3 file PNG chính vào `mobile-app/assets/app_icon/` và dùng cấu hình:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  remove_alpha_ios: true
  image_path: "assets/app_icon/meta_gym_app_icon_1024.png"
  adaptive_icon_background: "#0F1115"
  adaptive_icon_foreground: "assets/app_icon/meta_gym_app_icon_adaptive_fg_1024.png"
  adaptive_icon_monochrome: "assets/app_icon/meta_gym_app_icon_monochrome_1024.png"
  web:
    generate: true
    image_path: "assets/app_icon/meta_gym_app_icon_1024.png"
    background_color: "#0F1115"
    theme_color: "#FF5E36"
```
