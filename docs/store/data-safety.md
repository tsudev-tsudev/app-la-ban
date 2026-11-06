# Google Play - mục An toàn dữ liệu (Data Safety) khớp thực tế

Đối chiếu bản prod `0.1.0-beta.10` (31/10/2026). Đổi luồng dữ liệu / thêm SDK -> sửa tệp này + trang Quyền riêng tư landing
(`web/landing/src/i18n/noi-dung.ts`, mục `rieng`) CÙNG một PR. Nguồn: QUYET_DINH Q7, Q13, Q35, Q42, Q43, Q44.

## 1. Quyền Android của bản prod (manifest đã gộp, đo bằng `bundletool dump manifest`)

| Quyền | Dùng cho | Hỏi lúc |
|---|---|---|
| `INTERNET` | máy chủ bảo mật (sau khi đồng ý), tải vùng bản đồ | - |
| `ACCESS_COARSE_LOCATION` / `ACCESS_FINE_LOCATION` | bắc thực (WMM), toạ độ, dẫn đường - chỉ xử lý TRÊN MÁY | khi dùng tính năng (chỉ khi đang mở app) |
| `CAMERA` | Camera AR: khung hình đi thẳng vào texture hiển thị, không đọc pixel / chụp / lưu / gửi | khi mở màn AR |
| `ACCESS_NETWORK_STATE` | freeRASP + MapLibre: biết có mạng hay không (không đọc nội dung) | - (quyền thường) |
| `ACCESS_WIFI_STATE` | MapLibre: trạng thái kết nối khi tải tile | - (quyền thường) |
| `USE_BIOMETRIC` / `USE_FINGERPRINT` | androidx.biometric trong freeRASP: chỉ kiểm máy CÓ khoá màn hình / sinh trắc (tín hiệu RASP), không đọc vân tay | - (quyền thường) |
| `BILLING` (com.android.vending) | Play Billing Library qua `in_app_purchase` (M1a, Q55): mở luồng mua La bàn Pro của Google Play | - (quyền thường) |
| `CHUYEN_PRO` (`com.tsudev.laban.permission.CHUYEN_PRO`, tự khai, `signature`) | M2b (Q66): chỉ La bàn Pro cùng chứng chỉ ký được đọc gói chuyển dữ liệu do người dùng bấm Gửi - dữ liệu đi giữa hai app trên máy, không rời máy | - (quyền chữ ký) |
| `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | androidx.core: bảo vệ receiver nội bộ (quyền chữ ký của chính app) | - |

**Đã gỡ** bằng `tools:node="remove"` trong `app/android/app/src/main/AndroidManifest.xml` (Q46):
`READ_GSERVICES` (fingerprint-android trong freeRASP đọc GSF ID - định danh cố định, trái Q7) và `RECEIVE_BOOT_COMPLETED`
(truetime trong freeRASP). Plugin mới kéo thêm quyền -> `build-aab.sh` dừng tới khi khai ở bảng này.

Không có: vị trí nền, danh bạ, bộ nhớ ngoài (xuất / nhập tệp qua SAF), `QUERY_ALL_PACKAGES`, quảng cáo (`AD_ID`).
Kiểm lại mỗi bản: `./tools/build/build-aab.sh` đọc quyền từ AAB (`bundletool dump manifest`) và so với bảng này.

## 2. Câu trả lời tổng quát

| Câu hỏi | Trả lời | Lý do |
|---|---|---|
| Ứng dụng có thu thập hoặc chia sẻ loại dữ liệu bắt buộc khai báo? | **Có** | dữ liệu bảo mật kỹ thuật khi người dùng đồng ý (mục 3) |
| Mọi dữ liệu được mã hoá khi truyền? | **Có** | HTTPS TLS 1.2+ có ghim chứng chỉ (SEC-NET); freeRASP gửi qua HTTPS |
| Người dùng có thể yêu cầu xoá dữ liệu? | **Có** | Cài đặt > Quyền riêng tư > Xoá toàn bộ (trên máy) + email privacy@tsudev.com kèm mã thiết bị (máy chủ, 72 giờ làm việc) |
| Tài khoản | Không có tài khoản -> không cần URL xoá tài khoản | |
| Tuân thủ Chính sách gia đình | Không nhắm trẻ em (13+) | |
| Đánh giá bảo mật độc lập (MASA) | Không (chưa) | |

## 3. Loại dữ liệu khai báo

Mọi dòng dưới đây là **tuỳ chọn** ("Users can choose whether this data is collected" = Có): chỉ thu sau khi người dùng bấm
"Đồng ý và bắt đầu" ở màn giới thiệu; "Chỉ dùng ngoại tuyến" hoặc rút đồng ý ở Cài đặt -> ứng dụng không gửi gì (đo M32
31/10: 0 byte theo uid). Không dòng nào dùng cho quảng cáo, phân tích hành vi hay cá nhân hoá.

| Nhóm Play | Loại | Thu thập | Chia sẻ | Mục đích | Dữ liệu cụ thể |
|---|---|---|---|---|---|
| Location | Approximate location | Có | Không | Fraud prevention, security, and compliance | quốc gia + ASN suy từ địa chỉ IP ở máy chủ (Cloudflare); IP chi tiết rút gọn sau 90 ngày |
| Device or other IDs | Device or other IDs | Có | **Có (Talsec)** | Fraud prevention, security, and compliance | mã cài đặt ngẫu nhiên + khoá công khai ECDSA phần cứng (không IMEI / serial / MAC / Android ID); freeRASP gửi Talsec mã phiên bản cài của riêng nó |
| App info and performance | Crash logs | Có (tuỳ chọn RIÊNG, mặc định tắt) | Không | App functionality | S10b (Q49): loại lỗi, ngăn xếp đã che mã, phiên bản app / Android - chỉ khi bật "Gửi báo cáo sự cố"; về Worker của TsuDev, lưu 90 ngày |
| Financial info | Purchase history | Có (chỉ khi mua Pro) | Không | App functionality | M1a (Q55): `POST /v1/mua/xac-minh` gửi purchase token + mã sản phẩm; D1 `quyen_loi` lưu sản phẩm, trạng thái, hết hạn, mã đơn, băm + bản mã hoá AES-GCM của token, mã cài đặt gắn kèm. Thanh toán do Google Play xử lý - không nhận thông tin thẻ. Mục này BẮT BUỘC khi mua (không tuỳ chọn) |
| App info and performance | Diagnostics | Có | **Có (Talsec)** | Fraud prevention, security, and compliance | loại máy, phiên bản Android / app, tên gói, nguồn cài, kết quả kiểm tra môi trường (root, trình gỡ lỗi, hook, giả lập, chữ ký), phán quyết Play Integrity |

Không khai (không rời máy hoặc được miễn theo định nghĩa của Play):
- **Vị trí chính xác**: xử lý trên máy (bắc thực, toạ độ, dẫn đường) - "on-device processing" không phải thu thập.
- **Điểm mốc, ảnh điểm mốc, cài đặt**: SQLCipher trên máy, `allowBackup=false`.
- **Chia sẻ điểm mốc**: link / QR do người dùng chủ động gửi qua bảng chia sẻ hệ thống -> "user-initiated sharing", được miễn.
- **Camera**: không lưu / không gửi khung hình.
- **Xuất JSON / GPX / KML**: người dùng chọn nơi lưu qua SAF.
- **Tải tile bản đồ** (`compass-api.tsudev.com/ban-do/...`): yêu cầu HTTP thông thường, máy chủ không ghi nhật ký theo thiết bị
  (chỉ nhật ký kỹ thuật tạm thời của Cloudflare) -> "ephemeral processing".
- **Khiếu nại** (email, mô tả): gửi ở WEBSITE, không qua app.

## 4. Bên thứ ba

| Bên | Vai trò | Khai ở |
|---|---|---|
| Cloudflare | hạ tầng xử lý thay mặt TsuDev (service provider) -> KHÔNG tính là "chia sẻ" | Chính sách quyền riêng tư mục 5 |
| Google Play Integrity | API của Google Play services; token đi qua máy chủ TsuDev để giải mã -> đã gộp vào "Diagnostics" | mục 5 |
| Google Play Billing | Google xử lý thanh toán; máy chủ TsuDev hỏi Play Developer API để xác minh -> không phải "chia sẻ" (Google là bên bán hộ / xử lý thanh toán) | mục 3 |
| Talsec (freeRASP, Cộng hoà Séc) | dùng dữ liệu để thống kê mối đe doạ của chính họ -> **chia sẻ** | mục 5; đối chiếu hướng dẫn Data Safety mới nhất của Talsec khi điền |

Không có SDK quảng cáo, phân tích, crash. Báo cáo sự cố tự xây (S10b, QUYET_DINH Q49) đi thẳng về Worker của TsuDev - không bên thứ ba; tỷ lệ crash / ANR native lấy từ Android vitals của Play Console (không cần SDK).
