# Google Play - trang ứng dụng (listing) vi / en

Dán vào Play Console > Grow > Store presence > Main store listing. Mặc định: **vi-VN**, bản dịch thêm: **en-US**.
Giới hạn Play: tên <= 30, mô tả ngắn <= 80, mô tả đầy đủ <= 4000 ký tự (đếm ở `tools/build/kiem-listing.mjs`).
Không dùng từ ngữ xếp hạng / khuyến mãi ("số 1", "tốt nhất", "miễn phí" trong tên), không emoji trong tên (chính sách Metadata).

| Mục | Giá trị |
|---|---|
| Gói | `com.tsudev.laban` (flavor prod) |
| Tên nhà phát triển | TsuDev |
| Danh mục | Ứng dụng > Công cụ (Tools) |
| Thẻ | Compass, Navigation, Outdoor |
| Email liên hệ | contact@tsudev.com |
| Website | https://compass.tsudev.com |
| Chính sách quyền riêng tư | https://compass.tsudev.com/quyen-rieng-tu (en: https://compass.tsudev.com/en/privacy) |
| Quảng cáo | Không (ads chỉ bật sau Release Gate M1) |
| Mua trong ứng dụng | Không |
| Biểu tượng 512 x 512 | `design/store/play-icon-512.png` |
| Ảnh nổi bật 1024 x 500 | `design/store/play-feature-1024x500.png` (`node tools/build/thuong-hieu.mjs` sinh) |
| Ảnh điện thoại | `design/store/play/<vi|en>/light-*.png` (6 ảnh 1080 x 1920, `./tools/build/anh-store.sh`); bộ `dark-*` dùng cho bài đăng / A-B |

<!-- listing:vi -->
## vi-VN

### Tên
La bàn - TsuDev Compass

### Mô tả ngắn
Bắc thực chính xác, điểm mốc, bản đồ ngoại tuyến - không quảng cáo theo dõi

### Mô tả đầy đủ
La bàn của TsuDev chỉ hướng chính xác, mượt và hoạt động hoàn toàn ngoại tuyến - cho đi rừng, đi biển, đo hướng nhà và làm việc ngoài trời.

CHÍNH XÁC TỪ CẢM BIẾN TỚI CON SỐ
• Bắc thực tính bằng mô hình từ trường thế giới WMM theo vị trí và ngày, chạy ngay trên máy - không cần mạng.
• Hợp nhất từ kế, gia tốc kế và con quay: kim ổn định, không giật khi bạn di chuyển.
• Báo độ tin cậy cảm biến và hướng dẫn hiệu chuẩn hình số 8 khi cần.
• Cảnh báo nhiễu từ khi gần nam châm, kim loại hay thiết bị điện.

ĐIỂM MỐC VÀ DẪN ĐƯỜNG
• Lưu điểm với toạ độ, độ cao, ghi chú và ảnh.
• Chỉ hướng và khoảng cách tới điểm đích.
• Toạ độ DD, DMS, UTM, MGRS; nhập / xuất GPX, KML.
• Chia sẻ điểm bằng link hoặc mã QR có hạn dùng.

BẢN ĐỒ VÀ CAMERA
• Bản đồ Việt Nam tải một lần theo vùng, dùng cả khi ở chế độ máy bay.
• Camera AR chồng hướng và điểm mốc lên hình camera để tìm đường trực quan. Hình camera chỉ hiển thị, không chụp, không lưu, không gửi đi.

DỄ DÙNG CHO MỌI NGƯỜI
• Chế độ sáng / tối, chữ lớn, hỗ trợ TalkBack, tôn trọng tuỳ chọn giảm chuyển động.
• Tiếng Việt và English.

RIÊNG TƯ VÀ AN TOÀN
• Không cần tài khoản. Điểm mốc lưu trong cơ sở dữ liệu mã hoá trên máy, không đi theo bản sao lưu đám mây.
• Không đọc IMEI, số sê-ri, địa chỉ MAC. Không bán dữ liệu, không quảng cáo theo dõi.
• Chọn "Chỉ dùng ngoại tuyến" ở màn giới thiệu thì ứng dụng không gửi gì; la bàn, bản đồ đã tải và điểm mốc vẫn dùng đủ.
• Cài đặt > Quyền riêng tư: rút đồng ý, xuất dữ liệu ra JSON, xoá toàn bộ dữ liệu trên máy.

Lưu ý: la bàn điện thoại có thể sai do nhiễu từ hoặc cảm biến. Không dùng làm công cụ định hướng duy nhất trong tình huống nguy hiểm đến tính mạng, hàng hải hay hàng không.

Góp ý: contact@tsudev.com · Báo lỗ hổng bảo mật: security@tsudev.com
<!-- /listing:vi -->

<!-- listing:en -->
## en-US

### Title
La bàn - TsuDev Compass

### Short description
Accurate true-north compass, waypoints and offline maps - no tracking ads

### Full description
TsuDev's compass points the right way, stays smooth and works fully offline - for hiking, sailing, checking a house's orientation and working outdoors.

ACCURATE FROM SENSOR TO NUMBER
• True north from the World Magnetic Model (WMM) for your location and date, computed on the device - no network needed.
• Fuses magnetometer, accelerometer and gyroscope: a steady needle that does not jitter while you move.
• Shows sensor confidence and guides a figure-8 calibration when needed.
• Warns about magnetic interference near magnets, metal or electronics.

WAYPOINTS AND NAVIGATION
• Save places with coordinates, altitude, notes and photos.
• Direction and distance to your destination.
• DD, DMS, UTM and MGRS coordinates; GPX and KML import / export.
• Share a waypoint as a link or QR code that expires.

MAPS AND CAMERA
• Download Vietnam map regions once and use them even in airplane mode.
• Camera AR overlays direction and waypoints on the camera view. The camera image is only displayed - never captured, stored or sent.

EASY FOR EVERYONE
• Light / dark themes, large text, TalkBack support, respects reduce-motion.
• Vietnamese and English.

PRIVATE AND SECURE
• No account needed. Waypoints live in an encrypted database on your device and are excluded from cloud backup.
• Never reads IMEI, serial number or MAC address. No data selling, no tracking ads.
• Choose "Use offline only" on the welcome screen and the app sends nothing; the compass, downloaded maps and waypoints keep working.
• Settings > Privacy: withdraw consent, export your data to JSON, erase all data on the device.

Note: phone compasses can be wrong because of magnetic interference or sensor faults. Do not rely on it as your only means of navigation in life-threatening situations, at sea or in aviation.

Feedback: contact@tsudev.com · Security reports: security@tsudev.com
<!-- /listing:en -->

## Ghi chú phát hành (Release notes) bản internal đầu tiên
- vi: Bản thử nội bộ đầu tiên trên Google Play: la bàn bắc thực, điểm mốc, bản đồ ngoại tuyến, Camera AR, trợ năng.
- en: First internal test on Google Play: true-north compass, waypoints, offline maps, Camera AR, accessibility.
