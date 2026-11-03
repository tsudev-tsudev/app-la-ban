# Runbook - phát hành Google Play (R2)

Người dùng bấm trong Play Console (CLAUDE.md: agent KHÔNG tự đẩy lên store); agent chuẩn bị AAB + tài liệu.
Tài khoản nhà phát triển Play dự kiến có từ 05/11/2026 (QUYET_DINH Q19) - tới lúc đó dừng ở bước 1.

## 1. Chuẩn bị (agent, không cần Play Console)

```bash
./tools/build/build-aab.sh          # AAB prod ký khoá upload + kiểm quyền + đo download size -> build/phat-hanh/<pb>/
./tools/build/anh-store.sh          # 6 ảnh x {light, dark} x {vi, en} 1080x1920 -> design/store/play/
node tools/build/thuong-hieu.mjs    # icon 512 + ảnh nổi bật 1024x500 -> design/store/
node tools/build/kiem-listing.mjs   # độ dài tên / mô tả ngắn / mô tả đầy đủ của docs/store/play-listing.md
```

- Biểu tượng `design/store/play-icon-512.png`, ảnh nổi bật `design/store/play-feature-1024x500.png` (PNG 24-bit, không alpha).
- Ảnh điện thoại: tải bộ `light-1..6` (thứ tự = tên tệp), tối đa 8 ảnh / ngôn ngữ.
- Listing: `docs/store/play-listing.md`; Data Safety: `docs/store/data-safety.md`; App access: `docs/store/ghi-chu-reviewer.md`.

## 1b. Trạng thái tài khoản (03/11/2026)

- Người dùng đã tạo tài khoản nhà phát triển **cá nhân** "TsuDev" (mã tài khoản 6673606179625007616) và thanh toán
  25 USD thành công 03/11.
- Thứ tự xác minh thật của Play Console: **danh tính (CCCD) trước** -> mới mở xác minh số điện thoại -> thiết bị Android
  thật (app Play Console trên M32) -> nút "Tạo ứng dụng" sáng. 03/11 17:04: danh tính đang chờ Google duyệt (vài giờ - vài
  ngày); số điện thoại hiện "Việc cần làm" nhưng bị khoá chờ - không phải lỗi.
- Tài khoản cá nhân (tạo sau 13/11/2023): trước production phải **thử nghiệm kín >= 12 người kiểm thử liên tục 14 ngày**
  rồi "Đăng ký quyền truy cập bản phát hành công khai". Internal testing không bị điều kiện này -> R2b làm được ngay khi
  xác minh xong; R4 phụ thuộc thêm 14 ngày thử kín. Người dùng gom >= 12 Gmail.

## 2. Tạo ứng dụng + Play App Signing (người dùng, một lần)

1. Play Console > Create app: tên "La bàn - TsuDev Compass", ngôn ngữ mặc định Tiếng Việt, App, Free.
2. Release > Setup > App signing > **"Use a different key" -> "Export and upload a key from Java keystore"**: tải
   `pepk.jar` + khoá mã hoá của Google từ trang đó, chạy trên máy (KHÔNG chép khoá vào repo):
   ```bash
   java -jar pepk.jar --keystore=$HOME/.config/la-ban/android/upload.jks --alias=<keyAlias trong key.properties> \
     --output=$HOME/.config/la-ban/android/play-signing.zip --include-cert --rsa-aes-encryption \
     --encryption-key-path=<tệp khoá mã hoá tải từ Play>
   ```
   Lý do (Q34): khoá ký của Play = khoá đang ký APK tải trực tiếp -> người dùng beta cập nhật đè từ Play được, máy chủ giữ
   nguyên `PI_CHUNG_CHI`. Sau đó (tuỳ chọn) đăng ký khoá upload mới cho Play để tách vai trò; khoá cũ vẫn ký APK ngoài.
3. Ghi lại "App signing key certificate" SHA-256 trên Play = SHA-256 ở `build/phat-hanh/<pb>/kich-thuoc.txt`. Khác nhau ->
   dừng, kiểm lại bước 2.
4. Release > App integrity > Play Integrity API: **Link Cloud project `app-la-ban` (930761930572)** (Q35 - không đổi mã).

## 3. Bản internal

1. Testing > Internal testing > Create release > tải `build/phat-hanh/<pb>/la-ban-<pb>.aab`.
2. Ký hiệu Dart (obfuscate) ở `~/.config/la-ban/android/symbols/<pb>/aab` - giải stack trace bằng `flutter symbolize`; mapping R8 Play tự nhận trong AAB.
3. Testers: danh sách email (người dùng + máy thử). Release notes ở cuối `play-listing.md`.
4. Cổng R2: cài từ link opt-in trên Galaxy M32 -> mở app -> SOC thấy thiết bị có phán quyết app `PLAY_RECOGNIZED`.
5. Đo download size Play hiển thị (Android vitals > App size) và đối chiếu `kich-thuoc.txt`.

## 4. Miễn trừ thiết bị duyệt / pre-launch (agent-laban, Worker)

Thiết bị duyệt của Google và pre-launch report (Firebase Test Lab) có thể là giả lập / máy đã mở khoá -> điểm rủi ro cao.
Không dùng định danh phần cứng (CLAUDE.md) -> thêm quy tắc cho phép (`choPhep`, khớp `asn`) ở SOC cho ASN của Google
(AS15169, AS396982) trong thời gian duyệt, có hạn + lý do + audit; gỡ sau khi duyệt xong. Trạng thái `banned` (màn khoá)
không bao giờ áp tự động cho thiết bị khớp quy tắc này.

Cách làm (đã có từ 02/11/2026): SOC -> **Can thiệp** -> mục **Danh sách cho phép** -> nút **ASN Google Play review**
(điền AS15169 + AS396982) -> chọn hạn 7 hoặc 30 ngày -> lý do + passkey (Security Admin). Worker chuyển ASN của kết nối
(`request.cf.asn`) vào Threat Engine cho mọi sự kiện (app, bẫy, giới hạn tốc độ, khiên web), nên thiết bị qua mạng Google
được cho điểm 0 + rule chỉ shadow (vẫn ghi sự kiện để xem lại). Gỡ bằng nút **Gỡ miễn trừ** khi duyệt xong. Mọi lần thêm /
gỡ ghi audit `cho-phep:them` / `cho-phep:go`.

## 5. Sau duyệt

- Trang `/tai-ve` landing: đổi nút "Google Play - sắp có" thành link Play (agent-laban).
- Bản APK tải trực tiếp vẫn phát hành song song (Q34) - cùng `versionCode` tăng dần với bản Play.

## 6. Gói Pro + RTDN (M1a bước 3 - máy chủ xong 03/11/2026, Q55)

Worker đã có `POST /v1/mua/xac-minh`, `POST /v1/play/rtdn`, cron hằng ngày (Voided Purchases + hỏi lại gói sắp hết hạn) và
`quyenLoi` trong `/v1/status`. Bí mật `KHOA_QUYEN_LOI` (AES-GCM, bản sao `~/.config/la-ban/quyen-loi/` NGOÀI repo) đã đặt
cho staging + prod. Người dùng làm (sau khi tài khoản Play được duyệt + hồ sơ thanh toán):

1. **Quyền service account** (Play Console -> Người dùng và quyền -> mời email service account đang dùng cho Play
   Integrity): quyền ứng dụng "Xem dữ liệu tài chính" + "Quản lý đơn hàng và gói thuê bao" cho `com.tsudev.laban`
   (và `com.tsudev.laban.pro` khi có). Thiếu quyền -> `/v1/mua/xac-minh` trả 503 `google-loi` (`google-403`).
2. **Pub/Sub** (Cloud project 930761930572, gói miễn phí 10 GB/tháng - RTDN chỉ vài KB):
   - Tạo topic `play-rtdn`; cấp `google-play-developer-notifications@system.gserviceaccount.com` vai trò *Pub/Sub Publisher* trên topic.
   - Tạo service account `rtdn-day` (không cần khoá JSON) để Pub/Sub ký JWT OIDC.
   - Tạo subscription **Push**: endpoint `https://compass-api.tsudev.com/v1/play/rtdn`, bật *Authentication* với service
     account `rtdn-day`, audience = đúng URL endpoint (khớp `RTDN_AUD` trong `wrangler.toml`).
   - Báo agent email `rtdn-day@...iam.gserviceaccount.com` -> agent đặt `RTDN_EMAIL` (biến thường) + deploy. Chưa đặt -> route trả 503 (Pub/Sub tự gửi lại tối đa 7 ngày).
3. **Play Console -> Kiếm tiền -> Thiết lập kiếm tiền**: dán topic `projects/930761930572/topics/play-rtdn` -> *Gửi thông
   báo thử* -> agent kiểm sự kiện `rtdn-thu` trong D1 `quyen_loi_events`.
4. Tạo sản phẩm `pro_thang`, `pro_nam` (base plan + dùng thử 7 ngày), `pro_vinh_vien` theo giá Q55; thêm license tester.

Kiểm nhanh (agent): `npx wrangler d1 execute la-ban-prod --remote --command "SELECT kind, count(*) FROM quyen_loi_events GROUP BY kind"`.
