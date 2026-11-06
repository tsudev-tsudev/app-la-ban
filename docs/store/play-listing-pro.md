# Google Play - trang ứng dụng La bàn Pro (listing) vi / en

Ứng dụng RIÊNG `com.tsudev.laban.pro` (M2, QUYET_DINH Q56 / Q65), trả phí một lần 99.000 đ, cùng mã nguồn với La bàn
(`play-listing.md`). Dán vào Play Console > (app La bàn Pro) > Grow > Store presence > Main store listing (tạo app: `huong-dan-play-console.md`
Phần F). Mặc định **vi-VN**, bản dịch thêm **en-US**. Giới hạn + từ cấm kiểm chung bằng `tools/build/kiem-listing.mjs`.

Chính sách "nội dung lặp lại / spam" của Play: hai listing PHẢI nói rõ quan hệ bản miễn phí / bản Pro và điểm khác nhau
(không quảng cáo, mua một lần, chuyển dữ liệu) - không chép nguyên mô tả bản miễn phí. Mô tả dưới đây viết lại theo hướng đó.

| Mục | Giá trị |
|---|---|
| Gói | `com.tsudev.laban.pro` (flavor prod) |
| Tên nhà phát triển | TsuDev |
| Danh mục | Ứng dụng > Công cụ (Tools) |
| Thẻ | Compass, Navigation, Outdoor |
| Giá | 99.000 đ (trả phí khi tải - Play tự quy đổi các quốc gia khác theo mẫu giá) |
| Email liên hệ | contact@tsudev.com |
| Website | https://compass.tsudev.com |
| Chính sách quyền riêng tư | https://compass.tsudev.com/quyen-rieng-tu (en: https://compass.tsudev.com/en/privacy) - dùng chung, đã nêu La bàn Pro |
| Quảng cáo | **Không** (APK không chứa SDK quảng cáo - `build-aab.sh --pro` kiểm) |
| Mua trong ứng dụng | **Không** (app Pro không mở Play Billing - `CuaHangKhongBan`) |
| An toàn dữ liệu | `data-safety-pro.md` |
| Ghi chú người duyệt | `ghi-chu-reviewer.md` mục "La bàn Pro" |
| Biểu tượng 512 x 512 | `design/store/pro/play-icon-512.png` |
| Ảnh nổi bật 1024 x 500 | dùng `design/store/play-feature-1024x500.png` (cùng thương hiệu) |
| Ảnh điện thoại | `design/store/pro/<vi|en>/light-*.png` (7 ảnh 1080 x 1920, `./tools/build/anh-store.sh --pro`; ảnh 7 = Cài đặt "Bản quyền La bàn Pro" đã xác minh + "Nhập dữ liệu từ La bàn" - riêng của Pro); bộ `dark-*` cho bài đăng |

<!-- listing:vi -->
## vi-VN

### Tên
La bàn Pro - TsuDev Compass

### Mô tả ngắn
Bản trả phí một lần của La bàn TsuDev: không quảng cáo, bắc thực, bản đồ offline

### Mô tả đầy đủ
La bàn Pro là bản trả phí một lần của ứng dụng La bàn (TsuDev Compass). Cùng la bàn chính xác, điểm mốc và bản đồ ngoại tuyến - không quảng cáo, không gói thuê bao, không cần tài khoản.

BẢN PRO KHÁC GÌ BẢN MIỄN PHÍ
• Trả một lần khi tải trên Google Play, dùng mãi trên mọi máy cùng tài khoản Google - không gia hạn, không mua thêm trong ứng dụng.
• Không có bộ công cụ quảng cáo nào trong ứng dụng, nên không có quảng cáo và không có mã quảng cáo (Advertising ID).
• Có ngay mọi tính năng Pro hiện tại và sau này.
• Đã dùng La bàn bản miễn phí? Mở La bàn > Cài đặt > Chuyển sang La bàn Pro: điểm mốc, ảnh, danh sách vùng bản đồ và lựa chọn giao diện chuyển thẳng giữa hai ứng dụng trên máy, xem lại trước khi nhập. Có thể giữ hoặc gỡ bản miễn phí sau đó.

LA BÀN CHÍNH XÁC
• Bắc thực theo mô hình từ trường thế giới WMM cho vị trí và ngày hiện tại, tính ngay trên máy.
• Hợp nhất từ kế, gia tốc kế, con quay: kim ổn định khi di chuyển.
• Báo độ tin cậy cảm biến, hướng dẫn hiệu chuẩn hình số 8, cảnh báo nhiễu từ.

ĐIỂM MỐC, BẢN ĐỒ, CAMERA
• Lưu điểm với toạ độ, độ cao, ghi chú, ảnh; chỉ hướng và khoảng cách tới đích.
• Toạ độ DD, DMS, UTM, MGRS; nhập / xuất GPX, KML; chia sẻ điểm bằng link hoặc mã QR có hạn dùng.
• Bản đồ Việt Nam tải theo vùng, dùng cả ở chế độ máy bay.
• Camera AR chồng hướng và điểm mốc lên hình camera - hình chỉ hiển thị, không chụp, không lưu, không gửi.

DỄ DÙNG VÀ RIÊNG TƯ
• Sáng / tối, chữ lớn, TalkBack, tôn trọng giảm chuyển động. Tiếng Việt và English.
• Điểm mốc nằm trong cơ sở dữ liệu mã hoá trên máy. Không đọc IMEI, số sê-ri, địa chỉ MAC. Không bán dữ liệu.
• "Chỉ dùng ngoại tuyến" ở màn giới thiệu: ứng dụng không gửi gì, mọi tính năng vẫn chạy (bản quyền xác minh lại khi bạn bật trực tuyến).
• Cài đặt > Quyền riêng tư: rút đồng ý, xuất dữ liệu JSON, xoá toàn bộ dữ liệu trên máy.

Bản quyền: La bàn Pro xác minh giấy phép qua Google Play. Bản cài không đến từ Google Play sẽ được mời mở Google Play để nhận giấy phép.

Lưu ý: la bàn điện thoại có thể sai do nhiễu từ hoặc cảm biến. Không dùng làm công cụ định hướng duy nhất trong tình huống nguy hiểm đến tính mạng, hàng hải hay hàng không.

Góp ý: contact@tsudev.com · Báo lỗ hổng bảo mật: security@tsudev.com
<!-- /listing:vi -->

<!-- listing:en -->
## en-US

### Title
La bàn Pro - TsuDev Compass

### Short description
One-time paid edition of TsuDev Compass: no ads, true north, offline maps

### Full description
La bàn Pro is the one-time paid edition of the La bàn app (TsuDev Compass). The same accurate compass, waypoints and offline maps - with no ads, no subscription and no account.

HOW PRO DIFFERS FROM THE FREE EDITION
• Pay once when you install from Google Play and keep it on every device with the same Google account - no renewals, no in-app purchases.
• No advertising SDK is included at all, so there are no ads and no Advertising ID.
• Every current and future Pro feature is included.
• Already using the free La bàn (Compass)? Open it > Settings > Move to Compass Pro: waypoints, photos, your offline map region list and display choices move directly between the two apps on your phone, with a review screen before anything is imported. Keep or uninstall the free edition afterwards.

ACCURATE COMPASS
• True north from the World Magnetic Model (WMM) for your location and date, computed on the device.
• Fuses magnetometer, accelerometer and gyroscope for a steady needle while you move.
• Shows sensor confidence, guides a figure-8 calibration and warns about magnetic interference.

WAYPOINTS, MAPS, CAMERA
• Save places with coordinates, altitude, notes and photos; direction and distance to your destination.
• DD, DMS, UTM and MGRS coordinates; GPX and KML import / export; share a waypoint as an expiring link or QR code.
• Download Vietnam map regions once and use them even in airplane mode.
• Camera AR overlays direction and waypoints on the camera view - the image is only displayed, never captured, stored or sent.

EASY AND PRIVATE
• Light / dark themes, large text, TalkBack, respects reduce-motion. Vietnamese and English.
• Waypoints live in an encrypted on-device database. Never reads IMEI, serial number or MAC address. No data selling.
• "Use offline only" on the welcome screen: the app sends nothing and every feature keeps working (the license is re-checked when you go online).
• Settings > Privacy: withdraw consent, export your data to JSON, erase all data on the device.

License: La bàn Pro verifies its license with Google Play. Copies not installed from Google Play are invited to open Google Play to get a license.

Note: phone compasses can be wrong because of magnetic interference or sensor faults. Do not rely on it as your only means of navigation in life-threatening situations, at sea or in aviation.

Feedback: contact@tsudev.com · Security reports: security@tsudev.com
<!-- /listing:en -->

## Ghi chú phát hành (Release notes) bản thử kín đầu tiên
- vi: Bản thử đầu tiên của La bàn Pro: không quảng cáo, đủ tính năng Pro, chuyển dữ liệu từ La bàn bản miễn phí.
- en: First test build of La bàn Pro: no ads, every Pro feature, data transfer from the free La bàn app.
