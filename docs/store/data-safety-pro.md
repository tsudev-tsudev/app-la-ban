# Google Play - An toàn dữ liệu (Data Safety) của La bàn Pro `com.tsudev.laban.pro`

App Pro dùng chung mã nguồn và máy chủ với La bàn (M2, Q56 / Q65 / Q66) nên phần lớn câu trả lời GIỐNG `data-safety.md`.
Tệp này chỉ ghi phần KHÁC và bảng quyền của AAB Pro (`./tools/build/build-aab.sh --pro` đọc quyền từ AAB và so với bảng
dưới; quyền mới -> build dừng tới khi khai ở đây). Đổi luồng dữ liệu -> sửa CẢ hai tệp + trang Quyền riêng tư landing.

## 1. Quyền Android của bản prod Pro

| Quyền | Dùng cho | Hỏi lúc |
|---|---|---|
| `INTERNET` | máy chủ bảo mật + xác minh bản quyền (sau khi đồng ý), tải vùng bản đồ | - |
| `ACCESS_COARSE_LOCATION` / `ACCESS_FINE_LOCATION` | bắc thực (WMM), toạ độ, dẫn đường - chỉ xử lý TRÊN MÁY | khi dùng tính năng |
| `CAMERA` | Camera AR, hình chỉ hiển thị | khi mở màn AR |
| `ACCESS_NETWORK_STATE` / `ACCESS_WIFI_STATE` | freeRASP + MapLibre: biết có mạng hay không | - (quyền thường) |
| `USE_BIOMETRIC` / `USE_FINGERPRINT` | androidx.biometric trong freeRASP: chỉ kiểm máy CÓ khoá màn hình (tín hiệu RASP) | - (quyền thường) |
| `CHUYEN_PRO` (`com.tsudev.laban.permission.CHUYEN_PRO` - cùng tên ở hai app, tự khai, `signature`) | M2b (Q66): nhận gói chuyển dữ liệu từ La bàn bản miễn phí CÙNG chứng chỉ ký, trên máy - không rời máy | - (quyền chữ ký) |
| `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | androidx.core: bảo vệ receiver nội bộ | - |

**Đã gỡ** (`app_pro/android/app/src/main/AndroidManifest.xml`): `READ_GSERVICES`, `RECEIVE_BOOT_COMPLETED` (như bản miễn
phí, Q46) và `com.android.vending.BILLING` (app Pro không bán gì trong app - `build-aab.sh --pro` dừng nếu còn).
Không có: `AD_ID` / SDK quảng cáo (`build-aab.sh --pro` kiểm dex + quyền), vị trí nền, danh bạ, bộ nhớ ngoài,
`QUERY_ALL_PACKAGES` (chỉ `<queries>` đúng một gói `com.tsudev.laban` để chuyển dữ liệu).

## 2. Câu trả lời tổng quát

Như `data-safety.md` mục 2 (có thu thập tuỳ chọn, mã hoá khi truyền, xoá được, không tài khoản, 13+).

## 3. Loại dữ liệu khai báo - KHÁC bản miễn phí

| Nhóm Play | Bản miễn phí | La bàn Pro | Lý do |
|---|---|---|---|
| Location > Approximate location | Có | **Có** (giống) | quốc gia + ASN từ IP ở máy chủ |
| Device or other IDs | Có, chia sẻ Talsec | **Có, chia sẻ Talsec** (giống) | mã cài đặt ngẫu nhiên + khoá công khai phần cứng; freeRASP |
| App info and performance > Crash logs | Có (tuỳ chọn riêng) | **Có** (giống) | S10b |
| App info and performance > Diagnostics | Có, chia sẻ Talsec | **Có, chia sẻ Talsec** (giống) | thêm `appLicensingVerdict` của Play Integrity (bản quyền Pro) trong cùng phán quyết - không phải loại dữ liệu mới |
| Financial info > Purchase history | Có (khi mua Pro trong app) | **KHÔNG khai** | app Pro không có mua trong app; giá tải do Google Play thu, TsuDev không nhận lịch sử mua (chỉ nhận phán quyết LICENSED / UNLICENSED) |
| Device or other IDs > Advertising ID | Không (tới M1b) | **KHÔNG** (vĩnh viễn) | APK không có SDK quảng cáo, không quyền `AD_ID` |

Mọi dòng "Có" vẫn là **tuỳ chọn**: "Chỉ dùng ngoại tuyến" hoặc rút đồng ý -> app không gửi gì (khi đó bản quyền chưa xác
minh, app vẫn đủ tính năng bản miễn phí - không khoá cứng ở client, Q56).

Không khai (không rời máy): điểm mốc / ảnh / cài đặt (SQLCipher), **gói chuyển dữ liệu từ bản miễn phí** (đi giữa hai app
trên cùng máy qua Content Provider quyền `signature`, tệp tạm trong cache tự xoá sau 10 phút - không qua mạng), tệp
"Xuất dữ liệu cá nhân" người dùng tự chọn nơi lưu (SAF).

## 4. Bên thứ ba

Như `data-safety.md` mục 4, BỎ dòng Google Play Billing. Google Play Integrity thêm vai trò xác minh giấy phép
(`appLicensingVerdict`) - vẫn gộp ở "Diagnostics".

## 5. Mục khác của Play Console (App content) cho app Pro

| Mục | Trả lời |
|---|---|
| Ads | **No, my app does not contain ads** |
| Advertising ID | **No** |
| Content rating (IARC) | như bản miễn phí, BỎ "mua hàng kỹ thuật số" (không IAP) |
| Target audience | 13+ |
| Government / Financial / Health apps | Không |
