# Quyết định đã chốt - app "La bàn"

Nguồn yêu cầu (gốc repo, không commit): `20261028-tai-lieu-ky-thuat-tong-hop-la-ban-chong-can-thiep.md` (SPEC-COMPASS-MASTER-2026-V3),
`20261027-SPEC-SEC-2026-V2-...md`, `20261015-KE-HOACH-BAO-MAT-WORLD-EDITOR-3D-XANUICAM.md`, `20260912-huong-dan-che-giau-comment-production.md`.
Đổi một quyết định = sửa dòng ở đây kèm ngày, đừng sửa im lặng trong mã. Mục `[CẦN CHỐT]` đang dùng PHƯƠNG ÁN MẶC ĐỊNH -
agent làm theo mặc định cho tới khi người dùng chốt khác; phase nào phụ thuộc thì hỏi lại trước khi làm phần đó.

## A. Đã chốt 28/10/2026 (theo tài liệu gốc + chuẩn hoá cho hạ tầng hiện có)

| Mã | Chủ đề | Chốt | Lý do |
|---|---|---|---|
| Q1 | Nền tảng app | **Flutter** (không React Native) | Spec V3 mục 5.1; render la bàn 60/120 FPS, golden test pixel |
| Q3 | Backend | **Cloudflare Workers + D1 + Durable Objects + KV + R2 + Analytics Engine** thay NestJS/Go + K8s + Postgres + Kafka của spec | Người dùng đã vận hành Cloudflare ở ubnd / ban-do-3d (wrangler, D1, Pages, Access); chi phí gần 0; không có máy chủ để vá. Spec cho phép đổi khi có văn bản - đây là văn bản đó. Bảng ánh xạ: kế hoạch tổng thể mục 1.2 |
| Q4 | Admin SOC | Vite + React + TS SPA trên Pages, sau **Cloudflare Access** + WebAuthn step-up trong app | Spec gợi ý Next.js; SPA tĩnh đủ dùng, CSP nonce đã có mẫu ở ban-do-3d |
| Q5 | Landing | **Astro** tĩnh vi/en | 0 JS mặc định, Core Web Vitals tốt |
| Q7 | Định danh thiết bị | Installation ID + khóa ECDSA phần cứng + Play Integrity / App Attest. CẤM IMEI / serial / MAC | Spec V3 điều chỉnh #1, chính sách store |
| Q8 | Phản ứng khi phát hiện can thiệp | Suy giảm có kiểm soát theo Risk Level, quyết định ở server; chỉ thoát app ở CRITICAL sau khi gửi sự kiện | Spec V3 điều chỉnh #2 |
| Q9 | Can thiệp từ xa | Khóa app + xóa dữ liệu CỦA APP; KHÔNG xóa thiết bị; có khiếu nại | Spec V3 điều chỉnh #4 |
| Q10 | OTA | **Shorebird**, chỉ hotfix Dart | Spec V3 điều chỉnh #5, #6 |
| Q11 | DB cục bộ | **Drift + SQLCipher** | Spec V3 điều chỉnh #7 |
| Q12 | Chặn hàng loạt | Four-eyes cho CIDR / ASN / quốc gia / >= 50 thiết bị; mọi chặn có TTL + log bất biến | Spec V3 #8, CGNAT ở VN |
| Q13 | RASP nền | **freeRASP (Talsec)** + kiểm tra native tự viết (NDK / Swift) | Miễn phí, có plugin Flutter; tự viết thêm để không phụ thuộc một nguồn. Phải khai báo Data Safety vì freeRASP gửi telemetry về Talsec |
| Q14 | Bản đồ | **MapLibre** + vector tile tự host trên R2 (PMTiles, vùng Việt Nam) | Không phí theo lượt như Mapbox / Google; OSM cấm tải hàng loạt từ tile.openstreetmap.org |
| Q15 | Lớp khiên web chống sao chép / DevTools | LÀM (theo yêu cầu người dùng) nhưng là lớp **răn đe + thu tín hiệu**, cấu hình bật/tắt từ xa, không thay kiểm soát server | SPEC-SEC CLI-04, CLI-07; giới hạn ghi ở kế hoạch bảo mật mục 6 |
| Q16 | CI | Cổng chạy ở máy `tools/kiem-tra/cong.sh`; không GitHub Actions | Billing GitHub Actions bị chặn ở các repo anh em |
| Q17 | Quảng cáo | AdMob (+ UMP / ATT) + RevenueCat IAP, CHỈ bật sau Release Gate (crash-free >= 99,8% trong 4 tuần) | Spec V3 mục 12 |
| Q18 | Cổng dev | :3030 admin, :3031 landing, :8797 Worker (CONG DEV) | Tránh 3008 (ubnd), 3010 (ban-do-3d), 3000-3006 |

## B. Chốt 28/10/2026 - người dùng đồng ý dùng PHƯƠNG ÁN MẶC ĐỊNH cho cả bảng (Q2, Q6, Q19-Q29)

| Mã | Câu hỏi | Chốt (mặc định) | Phương án khác (chỉ dùng khi người dùng đổi) | Cần trước phase |
|---|---|---|---|---|
| Q2 | Tên subdomain (SSL SUBDOMAIN) | Một cấp: `compass.tsudev.com` (landing), `compass-api.`, `compass-admin.`, `compass-cdn.`, `compass-status.` | Giữ tên spec `api.compass.tsudev.com`... cần Advanced Certificate Manager (~10 USD/tháng) vì Universal SSL chỉ phủ `*.tsudev.com` | N2 |
| Q6 | Máy build iOS (IOS CAN MACOS) - **hoãn tới I1 đầu 2027 (Q33)** | **Codemagic** gói miễn phí (macOS, ~500 phút/tháng), ký bằng App Store Connect API key | Máy Mac của người dùng; GitHub Actions macOS (đang bị chặn billing) | R2 (A1 cần nếu muốn thử iOS sớm) |
| Q19 | Tài khoản phát hành | Người dùng có Google Play Console (25 USD) + Apple Developer Program (99 USD/năm), tên nhà phát triển "TsuDev" | Tổ chức (cần D-U-N-S) | R2 |
| Q20 | Bundle ID / Application ID | `com.tsudev.laban` | | N0 (đổi sau rất tốn) |
| Q21 | Tên trên store | Play: "La bàn - TsuDev Compass"; App Store: "La bàn: Smart Compass" (App Store không cho trùng tên) | | R2 |
| Q22 | Gói Cloudflare | Workers Free cho dev/staging; **Workers Paid 5 USD/tháng** khi lên production (đủ hạn mức request, DO, Queues) | Free hoàn toàn (giới hạn 100k request/ngày, 5 WAF custom rule, 1 rate-limit rule) | S1 / R4 |
| Q23 | Tên miền / DNS tsudev.com | Đã ở Cloudflare, agent có token quyền DNS + Pages + Workers + WAF của zone `tsudev.com` | Người dùng tự tạo bản ghi theo hướng dẫn | N2 |
| Q24 | Đăng nhập Admin | Cloudflare Access (Google, email người dùng) + passkey WebAuthn trong app cho thao tác nhạy cảm | IdP riêng (Zitadel / Keycloak) | S6 |
| Q25 | Pentest độc lập | Đơn vị bên ngoài trước v1.0.0 (ngân sách người dùng chốt) | Chỉ red-team nội bộ + MobSF / ZAP (KHÔNG đạt tiêu chí 13 của spec) | R3 |
| Q26 | VN-2000 | Làm ở giai đoạn 2 (sau v1.0.0), cần tham số chuyển đổi chính thức theo tỉnh | Bỏ | A4 |
| Q27 | Thiết bị thật để thử | Ít nhất 1 Android (người dùng) qua `adb` Wi-Fi; iPhone qua TestFlight | Firebase Test Lab (hạn mức miễn phí) | A2 |
| Q28 | Reverse geocoding | Dữ liệu địa giới hành chính VN tĩnh (34 tỉnh / xã sau sắp xếp 2025) đóng gói offline, tra cục bộ; ngoài VN chỉ hiện tọa độ | Dịch vụ trả phí (Google / Mapbox) | A4 |
| Q29 | Độ tuổi / gia đình | Đối tượng >= 13 tuổi, không tham gia "Designed for Families" | | R2 |

## C. Chốt sau (người dùng giao agent chọn)

| Mã | Chủ đề | Chốt | Lý do | Phase |
|---|---|---|---|---|
| Q30 | Vẽ icon SVG 24dp trong Flutter (28/10/2026, người dùng giao agent chọn phương án tối ưu) | **Sinh mã Dart lúc build**: `tools/build/icon-dart.mjs` đọc `design/icons/*.svg` -> `packages/design_system/lib/src/icons/lb_icons.g.dart` (mỗi icon là danh sách lệnh `Path` - moveTo / lineTo / cubicTo / quadraticBezierTo / arcToPoint, kể cả lệnh tương đối; `circle` / `rect` / `ellipse` -> addOval / addRRect) + widget `LbIcon` (CustomPainter, nét 2/24 theo cỡ, màu từ `IconTheme`). KHÔNG dùng `flutter_svg`, KHÔNG icon font | 0 SDK bên thứ ba (không ảnh hưởng Data Safety / Privacy Manifest, không thêm chuỗi cung ứng); không parse XML / tải asset lúc chạy -> vẽ đồng bộ ngay khung đầu, golden ổn định; giữ đúng nét stroke (icon font cần chuyển nét thành viền, mất kiểm soát độ dày). Đổi icon = sửa SVG rồi chạy lệnh sinh; cổng `--check` như token | A1 |
| Q31 | Công cụ golden (28/10/2026, A1) | **Gói nội bộ `packages/test_kit`** (chỉ dev_dependencies) thay `alchemist`: nạp font Be Vietnam Pro thật, ma trận 12 kích thước x sáng/tối x vi/en/pseudo en-XA x cỡ chữ 0.85/1/2 CHỈ kiểm bố cục (không lưu ảnh), ảnh golden chụp 5 ô đại diện mỗi màn | alchemist chỉ gói `matchesGoldenFile` + lưới ảnh, mặc định chữ khối (Ahem) ở CI goldens; lưu ảnh cả ma trận (216 ô / màn) làm repo phình hàng chục MB. Tự viết ~150 dòng, không thêm phụ thuộc, kiểm soát tên ảnh | A1 |
| Q32 | Lưu trữ cục bộ (28/10/2026, A5, agent chọn theo Q11) | **SQLCipher qua hook của `package:sqlite3` 3.x** (`hooks: user_defines: sqlite3: source: sqlcipher` ở pubspec gốc) - `sqlcipher_flutter_libs` đã EOL. Khoá CSDL 32 byte ngẫu nhiên, `PRAGMA key` dạng khoá thô (không PBKDF2), bọc bằng **plugin nội bộ trong `packages/storage/{android,ios}`** (Android Keystore AES-GCM, StrongBox nếu có, tệp ở `noBackupFilesDir`; iOS Keychain `AfterFirstUnlockThisDeviceOnly`) - KHÔNG `flutter_secure_storage` / `path_provider`. Mã native của plugin nội bộ đặt trong chính gói (Flutter tool yêu cầu), `native/` để dành cho NDK C++ dùng chung (S4). Cài đặt giao diện, bộ đếm crash, cờ tính năng ở tệp JSON ghi nguyên tử (không nhạy cảm, phải sống khi CSDL lỗi); dữ liệu người dùng ở CSDL mã hoá | 0 SDK bên thứ ba mới (drift + sqlite3 thuộc Q11); bản SQLCipher dựng sẵn được kiểm sha256 + SLSA; khoá thô mở CSDL nhanh (ngân sách cold start). Lưu ý giấy phép: SQLCipher (BSD) + OpenSSL (Android) phải vào màn Giấy phép trước R2 | A5 |
| Q33 | Lộ trình nền tảng (28/10/2026, người dùng chốt) | **Android trước, iOS lùi sang đầu năm 2027** (chưa có máy Mac / tài khoản Apple Developer). Mọi phase chỉ thi công + nghiệm thu phần Android; phần iOS (Swift native, App Attest ở server, Keychain đã có từ A5 nhưng chưa build, Privacy Manifest, TestFlight, Codemagic Q6) gom vào phase **I1** chạy đầu 2027. Mã Dart viết đa nền tảng như cũ, không dùng API chỉ có Android trong lớp Dart chung | Không build / ký / thử iOS được trên WSL; tránh làm dở phần không nghiệm thu được | mọi phase |
| Q34 | Phân phối APK thử nghiệm trước khi lên Play (28/10/2026, người dùng giao agent chọn) | **APK prod ký bằng khoá upload riêng** (`~/.config/la-ban/android/`, NGOÀI repo, người dùng sao lưu) -> `tools/build/phat-hanh-apk.sh`: build `--release --obfuscate --split-debug-info` (bản arm64-v8a + bản universal), SHA-256 -> (1) **GitHub Release** `vX.Y.Z-beta.N` (pre-release, kèm `SHA256SUMS`) - repo private nên chỉ chủ repo tải được; (2) **bản công khai trên R2** `compass-cdn.tsudev.com/android/` (tên có phiên bản, bất biến + `latest.json`) để trang `compass.tsudev.com/tai-ve` dẫn tới (QR, cỡ, SHA-256, hướng dẫn cài). R2 thay Pages vì Pages giới hạn 25 MB/tệp. Khi lên Play (R2): chọn Play App Signing **dùng chính khoá này** để bản tải ngoài và bản Play cùng chữ ký, cập nhật đè được | Không cần Play Console để thử; tải trực tiếp không phụ thuộc trạng thái private của repo; có kiểm toàn vẹn (SHA-256 + chữ ký APK) | R0 |
