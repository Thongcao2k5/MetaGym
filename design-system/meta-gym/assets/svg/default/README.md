# Thư mục `svg/default` — SVG Mặc định & Dự phòng (Fallback)

## 1. Vị trí sử dụng trên App
- Dùng làm biểu tượng vector dự phòng chung trên toàn bộ ứng dụng Flutter (`mobile-app/lib/`) khi một `assetKey` từ Backend chưa có tệp SVG tương ứng hoặc đang ở trạng thái mặc định.
- Áp dụng tại các thẻ danh sách chung, chip phân loại hoặc placeholder icon trước khi nạp icon chuyên biệt.

## 2. Mô tả thiết kế & Quy chuẩn kỹ thuật
- **Phong cách:** Vector tối giản theo chuẩn **Futuristic Performance Glass** (`DESIGN.md`).
- **Khung vẽ (`viewBox`):** `0 0 24 24` (hoặc `0 0 32 32`).
- **Nét vẽ (Stroke):** `1.85px`, bo tròn đầu nét (`stroke-linecap="round"`, `stroke-linejoin="round"`).
- **Bảng màu:** Cam thương hiệu `#FF5E36`, kết hợp trắng sáng `#F7F9FC` hoặc xám phụ `#8E95A5`.
- **Ngân sách dung lượng:** `≤ 1.5 KB / file`.

## 3. Danh sách tệp trong thư mục
- `default.svg`: Biểu tượng tạ đơn (dumbbell) mặc định hiện hành của hệ thống.
