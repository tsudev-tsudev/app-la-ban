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
4. Bản đồ offline: tab Bản đồ > tải vùng; dùng được ở chế độ máy bay.
5. Quyền riêng tư: Cài đặt > Quyền riêng tư.

## Kiểm trước khi gửi duyệt
- [ ] Quy tắc miễn trừ thiết bị duyệt đã bật trên Worker prod (runbook mục 4) và đã thử một thiết bị giả lập không bị cấm.
- [ ] Data Safety điền theo `docs/store/data-safety.md`; Privacy policy URL mở được (vi + en).
- [ ] Nhãn nút ở mục 1 khớp chuỗi ARB hiện hành (`consentAccept` / `consentOffline`).
