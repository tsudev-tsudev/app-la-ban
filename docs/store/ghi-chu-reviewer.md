# Ghi chú cho người duyệt (Play Console > App content > App access + ghi chú phát hành nội bộ)

App access: chọn **"All functionality is available without special access"** (không tài khoản, không đăng nhập).
Dán bản en vào ô "Instructions" nếu Play hỏi thêm; bản vi để người dùng đối chiếu.

## en (dán vào Play Console)

No account or login is required. All features work without credentials.

1. On first launch the welcome screen shows a data notice. Tap "Agree and start" to enable the online security checks,
   or "Use offline only" - every feature (compass, calibration, waypoints, downloaded maps, Camera AR) keeps working and the
   app sends no data.
2. Location permission (while in use) is requested only when a feature needs it (true north, coordinates, navigation).
   Camera permission is requested only when opening Camera AR from the compass screen; the camera image is displayed
   only and is never captured, stored or sent.
3. Security mechanism: the app includes runtime self-protection (freeRASP by Talsec plus our own native checks) and Play
   Integrity attestation. Client checks only report signals; the decision is made by our server. On a rooted device,
   emulator or modified build the app may show an informational banner, and online features may be limited. The full
   lock screen appears only when the server bans a device (very high risk score, e.g. a repackaged build, or a manual ban
   by our security team); it always shows a reference code
   (REF-...) and a link to the appeal form at https://compass.tsudev.com/en/appeal/.
   Google review and pre-launch test devices are allow-listed on the server and are never restricted.
   The production build normally asks the user to turn off Developer options / USB debugging before use; this check is
   switched off on our server for the whole review period, so review devices with debugging enabled can use every feature.
4. Offline maps: Settings or the Map tab > download a region of Vietnam; the map then works in airplane mode.
5. Privacy controls: Settings > Privacy (withdraw consent, export data as JSON, erase all data on the device).

Contact during review: contact@tsudev.com

## vi (đối chiếu)

Không cần tài khoản / đăng nhập.
1. Lần mở đầu: màn giới thiệu có thông báo dữ liệu - "Đồng ý và bắt đầu" bật kiểm tra bảo mật trực tuyến; "Chỉ dùng ngoại
   tuyến" thì mọi tính năng vẫn dùng được và app không gửi dữ liệu.
2. Quyền vị trí (khi dùng app) chỉ hỏi khi tính năng cần; quyền camera chỉ hỏi khi mở Camera AR, hình chỉ hiển thị.
3. Cơ chế bảo mật: RASP (freeRASP + kiểm tra native tự viết) + Play Integrity; client chỉ gửi tín hiệu, máy chủ quyết định.
   Máy root / giả lập / bản sửa: băng thông báo + hạn chế tính năng trực tuyến; màn khoá CHỈ khi máy chủ cấm (điểm rủi ro vượt ngưỡng `banned`, vd bản đóng gói lại, hoặc SOC cấm tay), luôn có mã
   REF + link khiếu nại. Thiết bị duyệt / pre-launch của Google được miễn trừ ở máy chủ (xem runbook phat-hanh-play mục 4).
   Màn chặn chế độ Nhà phát triển (Q57) được TẮT bằng kill-switch suốt kỳ duyệt (huong-dan-play-console.md mục E1).
4. Bản đồ offline: tab Bản đồ > tải vùng; dùng được ở chế độ máy bay.
5. Quyền riêng tư: Cài đặt > Quyền riêng tư.

## Kiểm trước khi gửi duyệt
- [ ] Kill-switch `chanDevMode` (Remote Config ký số) + `CHAN_DEV_MODE = "0"` prod đã bật - `huong-dan-play-console.md` mục E1; duyệt xong làm E2.
- [ ] Quy tắc miễn trừ thiết bị duyệt đã bật trên Worker prod (runbook mục 4) và đã thử một thiết bị giả lập không bị cấm.
- [ ] Data Safety điền theo `docs/store/data-safety.md`; Privacy policy URL mở được (vi + en).
- [ ] Nhãn nút ở mục 1 khớp chuỗi ARB hiện hành (`consentAccept` / `consentOffline`).

## La bàn Pro `com.tsudev.laban.pro` (M2b) - App access + ghi chú

App access: **"All functionality is available without special access"**. Dán bản en; các bước 1-5 ở trên áp nguyên cho app Pro.

### en (dán vào Play Console của app Pro)

No account or login is required. La bàn Pro is the one-time paid, ad-free edition of La bàn (com.tsudev.laban) from the
same developer; both apps share the same code base and features. Steps 1-5 of the La bàn notes apply unchanged:

1. Welcome screen: "Agree and start" enables online security checks and license verification; "Use offline only" keeps
   every feature working and sends no data.
2. License: the app verifies its Google Play license through Play Integrity on our server. A copy installed from Google
   Play (including review and pre-launch devices) is licensed automatically. Only a copy NOT installed from Google Play
   shows "Not verified" under Settings > Compass Pro license; tapping it opens Google Play's own GET_LICENSED dialog. No
   feature is hard-locked on the device.
3. The app contains no ads, no advertising SDK and no in-app purchases (no Billing permission).
4. Optional data transfer from the free app: if La bàn (shown as "Compass" in English) is installed, open it > Settings > Move to
   Compass Pro > Send to Compass Pro. La bàn Pro shows a review screen and imports nothing until "Import" is tapped. Transfer stays on the device (Content Provider
   protected by a signature permission shared only by the two apps). Without the free app: La bàn Pro > Settings > Import from
   Compass > Pick an export file (made in La bàn: Settings > Privacy > Export data (JSON)).
5. Security mechanism and review-device allow-listing: identical to La bàn (see its notes); Developer options check is
   switched off on our server during review.

Contact during review: contact@tsudev.com

### vi (đối chiếu)

Không tài khoản. La bàn Pro = bản trả phí một lần, không quảng cáo của La bàn, cùng nhà phát triển, cùng mã nguồn.
1. Màn giới thiệu như bản miễn phí ("Đồng ý" bật kiểm tra bảo mật + xác minh bản quyền).
2. Bản quyền: Play Integrity `appLicensingVerdict` ở máy chủ; bản cài từ Play (kể cả máy duyệt) tự LICENSED; bản sideload
   hiện "Chưa xác minh" ở Cài đặt > Bản quyền La bàn Pro, chạm mở hộp thoại GET_LICENSED của Google. Không khoá cứng.
3. Không quảng cáo, không SDK quảng cáo, không mua trong app (đã gỡ quyền BILLING).
4. Chuyển dữ liệu từ bản miễn phí (tuỳ chọn): La bàn > Cài đặt > Chuyển sang La bàn Pro > Gửi -> Pro xem lại -> Nhập.
   Dự phòng: Pro > Cài đặt > Nhập dữ liệu từ La bàn > Chọn tệp xuất dữ liệu (La bàn > Cài đặt > Quyền riêng tư > Xuất).
5. Bảo mật + miễn trừ thiết bị duyệt + kill-switch Developer options: như La bàn.

### Kiểm trước khi gửi duyệt app Pro
- [ ] Phần F của `huong-dan-play-console.md` xong: app có phí 99.000 đ, F2 DÙNG CHUNG khoá ký với La bàn (bắt buộc cho quyền
  `signature` chuyển dữ liệu), liên kết Play Integrity + quyền service account.
- [ ] Data Safety điền theo `docs/store/data-safety-pro.md` (không Advertising ID, không Purchase history); Ads = No.
- [ ] Listing theo `docs/store/play-listing-pro.md`, ảnh `design/store/pro/<vi|en>/light-*.png`.
- [ ] Nhãn mục Cài đặt ở bước 2 / 4 khớp ARB hiện hành (`m2LicenseTitle`, `m2bMoveTitle`, `m2bImportTitle`).
