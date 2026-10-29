# Kế hoạch tổng thể - app "La bàn"

28/10/2026 · Nguồn: SPEC-COMPASS-MASTER-2026-V3 (gốc repo) + SPEC-SEC-2026-V2 + hướng dẫn che comment + mẫu kế hoạch phase của
World Editor 3D. Yêu cầu bảo mật chi tiết (mã `SEC-...`): `KE_HOACH_BAO_MAT_CHONG_XAM_NHAP.md`. Quyết định: `QUYET_DINH.md`.

**Agent đọc:** mục 0-3 + ĐÚNG thẻ phase của mình ở mục 4. Không đọc thẻ khác. Tài liệu gốc chỉ mở khi thẻ trỏ tới số mục cụ thể
(viết `Spec §x.y` = mục x.y của `20261028-tai-lieu-ky-thuat-tong-hop-la-ban-chong-can-thiep.md`).

---

## 0. Nguyên tắc chốt

1. Mục tiêu bảo mật là **phòng thủ nhiều lớp, đo được**; server quyết định tin cậy, client chỉ gửi tín hiệu (Spec §0, §15).
2. Backend Cloudflare thay cho K8s/Postgres của spec (QUYET_DINH Q3); bảng dữ liệu giữ đúng tên trường Spec §6.4.
3. Bảo vệ giao diện web (chống sao chép, chuột phải, DevTools) là lớp răn đe có bật/tắt từ xa, không thay kiểm soát server.
4. Quảng cáo / IAP chỉ bật sau Release Gate (Spec §12.1).
5. Mọi tính năng: vi + en, light + dark, không overflow, có test.
6. **Android trước** (QUYET_DINH Q33, chốt 28/10/2026): mọi phase chỉ thi công + nghiệm thu phần Android; phần iOS gom vào
   phase I1 (đầu năm 2027, khi có máy Mac + Apple Developer). Bản thử phát hành dạng APK tải trực tiếp (R0, Q34) trước khi lên Play.

## 1. Kiến trúc thực hiện

| Thành phần | Công nghệ | Tên miền |
|---|---|---|
| App | Flutter + Riverpod + go_router + Drift/SQLCipher + dio; native Kotlin/NDK, Swift | - |
| API | Worker `la-ban-api` (Hono + zod), D1 `la-ban`, Durable Objects, KV, R2, Analytics Engine, Cron | `compass-api.tsudev.com` |
| Landing | Pages `la-ban-landing` (Astro, vi/en) | `compass.tsudev.com` |
| Admin SOC | Pages `la-ban-admin` (Vite + React + TS) sau Cloudflare Access | `compass-admin.tsudev.com` |
| Tài nguyên | R2 công khai (WMM, tile, i18n, config ký số) | `compass-cdn.tsudev.com` |
| Trạng thái | trang tĩnh + health check | `compass-status.tsudev.com` |

Ánh xạ spec -> Cloudflare: Postgres -> D1 · Redis (nonce, rate, deny-list) -> Durable Objects + Rate Limiting binding (KV chỉ
cache đọc, không dùng cho nonce) · Kafka -> ghi lô + `waitUntil` (Queues khi lên Workers Paid) · ClickHouse -> Analytics Engine ·
WebSocket SOC -> DO hibernation · Vault -> `wrangler secret` · Terraform -> `tools/cloudflare/*.json` + script áp idempotent ·
Grafana/Loki -> Workers Logs + Tail Worker -> R2 + Sentry + cảnh báo Telegram.

## 2. Chuẩn chung

- **Hoàn thành phase:** `cong.sh day-du` xanh · test logic mới >= 85% · chuỗi vi/en · golden không overflow · bảng Tiến độ +
  dòng `Kết quả:` · LOG ghi quyết định/bẫy · không bí mật trong diff.
- **Ngân sách (Spec §15):** cold start < 1,2 s · 60 FPS (120 Hz: >= 110) · jank < 1% · tải về < 25 MB · pin < 3%/giờ ·
  API p95 < 300 ms · cảnh báo SOC < 1,5 s · kill-switch <= 5 s · đồng bộ chặn IP lên Cloudflare <= 30 s.
- **Giao diện (Spec §2):** tokens một nguồn `design/tokens.json`; 3 breakpoint; golden 12 kích thước × light/dark × vi/en ×
  font 0.85/1.0/2.0. Cyan `#00E5FF` không đạt tương phản cho chữ trên nền sáng - chỉ làm điểm nhấn; chữ dùng `#1A56DB`.

## 3. Thứ tự phase và Tiến độ

Một phase = một phiên = nhánh `phase/<mã>` = một PR. Ký hiệu: ⬜ chưa · 🟨 đang (x/y) · ✅ xong (ngày, commit) · ⛔ chờ người dùng.

| # | Mã | Tên | Phụ thuộc | Trạng thái |
|---|---|---|---|---|
| 1 | N0 | Khởi tạo repo, toolchain, cổng kiểm | - | ✅ 28/10 |
| 2 | N1 | Thương hiệu: logo, icon, tokens | N0 | ✅ 28/10 |
| 3 | N2 | Nền Cloudflare + landing tạm | N0 | ✅ 28/10 |
| 4 | A1 | Khung app (theme, i18n, router, responsive, golden) | N1 | ✅ 28/10 |
| 5 | A2 | Cảm biến + sensor fusion | A1 | ✅ 28/10 · máy thật 29/10: đứng yên ±0,45°, nhiễu từ OK (sai số tuyệt đối / trễ / pin ⛔) |
| 6 | A3 | Mặt la bàn, bắc thực WMM, hiệu chuẩn | A2 | ✅ 29/10 · máy thật M32: 60 Hz rớt 0,35%, 90 Hz 86 FPS |
| 7 | S1 | API lõi + schema D1 | N2 | ✅ 28/10 |
| 8 | A4 | Vị trí + telemetry | A3 | ✅ 29/10 (chưa thử GPS máy thật) |
| 9 | A5 | Lưu trữ mã hóa, migration, safe mode | A1 | ✅ 28/10 |
| 10 | S2 | Định danh thiết bị + attestation + phiên | S1, A5 | ⬜ |
| 11 | S3 | Ký request, pinning, Remote Config ký số | S2 | ⬜ |
| 12 | S4 | Làm cứng app | S3 | ⬜ |
| 13 | S5 | Threat Engine + enforcement | S1 | ✅ 28/10 |
| 14 | S6 | Admin SOC 1 | S5 | ⬜ |
| 15 | S7 | Admin SOC 2 | S6 | ⬜ |
| 16 | A6 | Waypoint, chia sẻ, deep link | A5, S3 | ⬜ |
| 17 | A7 | Bản đồ offline + Camera AR | A6 | ⬜ |
| 18 | R1 | Landing hoàn chỉnh (kéo lên làm cùng R0 theo yêu cầu người dùng) | N2 | ✅ 28/10 |
| 19 | S8 | Bảo vệ edge web (CSP, header, WAF as code) | R1 | ✅ 29/10 (CSP nghiêm Report-Only tới 05/11; Access ở S6, Turnstile ở S7) |
| 20 | S9 | Lớp bảo vệ nội dung web + build sạch | S8 | ⬜ |
| 21 | A8 | Cài đặt, quyền riêng tư, trợ năng, hiệu năng | A7, S4 | ⬜ |
| 22 | S10 | Giám sát, log bất biến, backup, ứng phó sự cố | S7 | ⬜ |
| 23 | R2 | Sẵn sàng store | A8, S4 | ⬜ |
| 24 | R3 | QA tổng + kiểm thử bảo mật | R2, S9, S10 | ⬜ |
| 25 | R4 | Phát hành v1.0.0 + OTA | R3 | ⬜ |
| 26 | M1 | Quảng cáo + IAP (v1.1.0) sau Release Gate | R4 | ⬜ |
| 27 | R0 | Bản APK thử: khoá ký, script phát hành GitHub Release + R2, trang tải | A5 | ✅ 28/10 |
| 28 | I1 | iOS (đầu 2027): build, App Attest, Privacy Manifest, TestFlight, App Store | R4, máy Mac | ⬜ |

Có thể giao agent thứ hai song song: S1 với A2-A3 · A5 với A4 · S5 với S4 · A6 với S6-S7 · R1 với A7 · A8 với S8-S9.

**Việc người dùng:** trước N2 tạo API token Cloudflare (zone tsudev.com: DNS, WAF, Lists; Workers, Pages, D1, R2) lưu ở
`~/.config/la-ban/cf.env` · trước A2 bật Wireless debugging trên 1 điện thoại Android · trước S2 Google Cloud project + Play
Integrity API + service account (Apple Team ID dời sang I1) · trước S6 bật Cloudflare Zero Trust · trước R2 tài khoản Play Console, duyệt Privacy
Policy · trước I1 (đầu 2027) máy Mac hoặc Codemagic + Apple Developer · trước R4 chốt đơn vị pentest, bấm phát hành · trước M1 tài khoản AdMob + RevenueCat.

## 4. Thẻ phase

### N0 - Khởi tạo repo, toolchain, cổng kiểm
- Đọc thêm: SEC-SUP, SEC-WEB-BUILD.
- Làm: `git init -b main` + repo GitHub private (mặc định `tsudev/app-la-ban`); Flutter stable clone vào `~/tools/flutter` (ghim commit `.flutter-version`),
  dùng `~/tools/android-sdk`, `~/tools/java`; khung `app/` (flavors dev/staging/prod, `com.tsudev.laban`), `packages/*`, pub workspace,
  npm workspaces `workers/api`, `web/landing`, `web/admin`, `web/shield` (TS strict, ESLint); `very_good_analysis`;
  `tools/kiem-tra/cong.sh nhanh|day-du`; hook pre-commit (gitleaks, check-agents-md, chặn dash không phải ASCII); ADR-0001,
  README, SECURITY.md, CONTRIBUTING.md (quy định comment), LICENSE độc quyền; osv-scanner trong cổng.
- Cổng: `day-du` xanh trên khung rỗng; `flutter test` xanh; commit đầu + PR. Xoá lưu ý CHUA CO GIT khỏi Board.
- Kết quả (28/10): repo `tsudev-tsudev/app-la-ban` (private). Flutter 3.47.8 / Dart 3.13.7 ở `~/tools/flutter` (ghim
  `.flutter-version`); app `android/` + `ios/` sinh bằng `flutter create`, Android 3 flavor `com.tsudev.laban[.dev|.stg]`,
  `allowBackup=false`, `flutter build apk --flavor dev --debug` OK (com.tsudev.laban.dev, targetSdk 36); iOS mới đổi bundle id + tên (scheme flavor iOS cần Xcode -> R2). Node 24 + npm workspaces (Hono, zod 4,
  Astro 7, Vite 8 + React 19, shield). `cong.sh day-du` xanh: eslint, tsc, vitest, astro check, 15 gói Dart analyze
  `--fatal-infos` + test, build web, vệ sinh bản build, secretlint, npm audit 0 lỗ hổng. Khác thẻ: FVM -> git clone ghim commit;
  gitleaks / osv-scanner -> secretlint + npm audit (tải binary bị chặn; tùy chọn nếu tự cài vào `~/tools/bin`); bảo vệ nhánh
  cần GitHub Pro (403) -> chỉ theo quy trình. Dart 3.13 dùng cú pháp constructor `const new(...)` (lint
  `unnecessary_type_name_in_constructor`) - `dart fix --apply` trong từng package.

### N1 - Thương hiệu
- Làm: tokens (Spec §2.1) -> Style Dictionary -> Dart + CSS; script kiểm tương phản WCAG AA; 3 phương án logo SVG (hoa gió +
  kim cyan/coral + wordmark "La bàn") -> xuất PNG -> HỎI người dùng chọn; app icon iOS 1024 + Android adaptive/monochrome;
  favicon, OG image; bộ icon 24dp (Spec §2.3); splash + animation onboarding < 300 KB; `design/LICENSES.md`, `design/BRAND.md`.
- Cổng: sinh token không đổi diff; tương phản đạt; ảnh icon trên launcher.
- Kết quả (28/10): người dùng chọn logo **B** (vòng gradient xanh + kim kim cương Bắc cyan / Nam coral) trong 3 phương án
  (`design/logo/phuong-an/so-sanh.png`). `design/tokens.json` -> `tools/build/tokens.mjs` (tự viết thay Style Dictionary,
  hàm thuần + test 100%) -> `tokens.g.dart` (LbColors/LbSpacing/LbRadius/LbShadows/LbGlass/LbType/LbBreakpoint/LbMotion)
  + `design/gen/tokens.css` (đã import ở landing + admin). Thêm biến thể chữ an toàn `*Strong`, `on*`; 54 cặp tương phản
  đạt AA (`tuong-phan.mjs`). Cổng thêm bước "Thương hiệu" (token --check, tương phản, quy ước icon). App icon iOS (không
  alpha) + Android adaptive / monochrome / legacy, nhãn DEV / STG cho flavor; splash Android < 12 + 12+ (SplashScreen API)
  + iOS (màu LaunchBackground light/dark); favicon svg/ico, apple-touch, OG 1200x630; 11 icon 24dp. Hoạt ảnh onboarding
  = `LbLogoDong` (CustomPainter, dao động tắt dần, tôn trọng reduce motion) thay Lottie/Rive - 0 KB, không thêm SDK;
  golden `lb_logo.png`. `design/BRAND.md`, `design/LICENSES.md` (Be Vietnam Pro OFL). Khác thẻ: Style Dictionary -> script
  riêng; brand guideline dạng Markdown (không PDF/Figma); "ảnh icon trên launcher" kiểm bằng ảnh xem trước
  `design/logo/xem-truoc-launcher.png` + build APK dev - chưa thử trên máy thật (chưa có thiết bị, làm ở A2).

### N2 - Nền Cloudflare
- Đọc thêm: SEC-EDGE, SEC-TLS, SEC-HDR.
- Làm: DNS proxied 5 tên miền (mục 1), DNSSEC, CAA, TLS >= 1.2, Always HTTPS (`tools/cloudflare/zone.json` + `ap-dung.mjs`
  dry-run mặc định); Worker khung env dev/staging/prod + `/v1/health`; D1, KV, R2, khai báo DO; Pages landing ("Sắp ra mắt") +
  admin (403 tới S6); `_headers` nền; `security.txt`, `robots.txt`; `docs/chi-phi.md` (hạn mức hiện hành).
- Cổng: `curl -sI` đúng header ở mọi tên miền; SSL Labs >= A; health trả mã build.
- Kết quả (28/10): cổng đạt - 5 tên miền đúng header (`curl -sI`), SSL Labs A+ (`compass`, `compass-api`), TLS 1.1 bị từ
  chối, health trả mã build. Zone áp bởi người dùng (min TLS 1.0 -> 1.2, CAA apex, 3 CNAME, domain Pages / R2, rule header cdn). Worker `la-ban-api` (prod `compass-api.tsudev.com`) + `la-ban-api-staging`
  (`compass-api-stg.tsudev.com`, tên miền thứ 6 cho staging) + env dev cục bộ; `/v1/health` trả `build` = commit
  (`BAN_BUILD`); header bảo mật mọi phản hồi (`thuan/tieu-de.ts`), CORS allowlist khớp nguyên chuỗi (`thuan/cors.ts`).
  D1 `la-ban[-staging]` (APAC), KV `la-ban-cau-hinh[-staging]`, R2 `la-ban-cdn` / `la-ban-nhat-ky` (+ staging), DO khung
  `KhoNonce` / `GioiHanToc` / `PhongSoc` (SQLite, trả 501). `workers_dev` + preview URL tắt. Pages `la-ban-landing`
  ("Sắp ra mắt" vi/en, `_headers` CSP không inline, `security.txt`, `robots.txt`, `sitemap.xml`), `la-ban-admin`
  (`_worker.js` 403 mọi đường dẫn tới S6), `la-ban-status` (tĩnh, gọi health). Zone as code: `tools/cloudflare/zone.json`
  + `ke-hoach.mjs` (thuần, test 100% dòng) + `ap-dung.mjs` (dry-run mặc định, không bao giờ xoá - zone dùng chung).
  `tools/build/deploy-web.sh`, `docs/chi-phi.md`, `docs/runbook/trien-khai-cloudflare.md`. Khác thẻ: DNSSEC đã bật sẵn;
  Analytics Engine chờ người dùng bật dashboard; HSTS đặt theo site (không cấp zone); `security@tsudev.com` cần người dùng tạo
  rule Email Routing (token thiếu quyền); `*.pages.dev` vẫn truy cập được (admin 403 ở đó; S6 thêm Access); script dò bot
  Cloudflare chèn `<script>` nội tuyến vào landing -> CSP chặn (trang vẫn chạy), S8 làm nonce middleware.

### A1 - Khung app
- Làm: shell route 4 tab (La bàn · Bản đồ · Điểm · Cài đặt); theme từ tokens; ARB vi/en đổi tức thì không mất state; layout 3
  breakpoint + SafeArea; tiện ích golden (alchemist) 12 kích thước × theme × locale × font scale; pseudo-locale test; lint chặn
  import ngược lớp.
- Cổng: golden xanh; đổi ngôn ngữ/theme không rebuild toàn cây.
- Phát sinh (từ N1): đóng gói font `design/fonts/BeVietnamPro-*.ttf` vào `packages/design_system` (family `BeVietnamPro`,
  `LbType` đã trỏ `package: design_system`) + đăng ký OFL vào `LicenseRegistry`; vẽ icon 24dp `design/icons` theo
  **QUYET_DINH Q30 (đã chốt - sinh mã Dart, không flutter_svg, không icon font)**: viết `tools/build/icon-dart.mjs` (hàm
  thuần ở `icon-dart-sinh.mjs` + `node --test`: đủ lệnh path M/L/H/V/C/S/Q/T/A/Z cả hoa/thường, circle/rect(rx)/ellipse,
  bỏ qua `v.01` chấm thì vẫn vẽ chấm tròn) -> `packages/design_system/lib/src/icons/lb_icons.g.dart` qua `dart format`
  (giống `tokens.mjs`) + widget `LbIcon(LbIcons.xxx, size, color, semanticLabel)` dùng `IconTheme`, nét = size/12, đầu /
  góc tròn; thêm `node tools/build/icon-dart.mjs --check` vào bước "Thương hiệu" của `cong.sh`; golden 11 icon light/dark
  so với `design/icons/xem-truoc.png`. Onboarding dùng `LbLogoDong`.
- Kết quả (28/10): go_router `StatefulShellRoute.indexedStack` 4 tab + `/chao` (giới thiệu, `LbLogoDong`); rail ở medium /
  expanded, thanh dưới ở compact; `LbTheme` sáng/tối + `LbThemeExt` từ tokens; font Be Vietnam Pro đóng gói + OFL vào
  `LicenseRegistry`; i18n gen-l10n `LbL10n` vi/en + pseudo-locale en-XA sinh từ en (`tools/build/arb-gia.mjs`); icon 24dp ->
  `LbIcons` (`tools/build/icon-dart.mjs`, đủ lệnh path) + `LbIcon`, thêm icon `cai-dat`; gói `test_kit` (QUYET_DINH Q31,
  thay alchemist): ma trận 12 kích thước x 2 theme x 3 ngôn ngữ x 3 cỡ chữ (216 ô / màn, app thử cả 4 tab) không tràn +
  golden 5 ô đại diện; test "đổi ngôn ngữ / theme giữ router, tab, State, số lần build"; luật lớp `tools/kiem-tra/lop.mjs`
  trong cổng. Độ phủ lib: app 100%, design_system / settings / feature >= 89%.

### A2 - Cảm biến + fusion
- Đọc thêm: Spec §4.1.
- Làm: plugin nội bộ `sensors` (EventChannel) Android `TYPE_ROTATION_VECTOR`/mag/accel/gyro/baro + accuracy, iOS CoreMotion +
  `CLHeading`; Dart thuần: Madgwick + bù nghiêng + lọc thích ứng + thống kê vòng (359°->0°); xử lý ngoài UI isolate; dừng khi nền.
- Cổng: unit test bộ lọc với dữ liệu ghi sẵn; đo trên điện thoại thật (ghi `TEST` vào LOG).
- Kết quả (28/10): `packages/sensors` thành plugin nội bộ CHỈ Android (Q33) - `CamBienPlugin.kt` nghe ROTATION_VECTOR /
  GAME_ROTATION_VECTOR / MAGNETIC_FIELD / ACCELEROMETER / GYROSCOPE (100 Hz) / PRESSURE (5 Hz) trên HandlerThread riêng,
  gom lô `DoubleArray` 7 số/mẫu mỗi 16 ms + mẫu hướng màn hình, không gửi tên / hãng cảm biến. Dart thuần (`lib/src/domain`):
  thống kê vòng (`hieuGoc`, `thongKeVong`, `CuaSoVong`, 8 hướng), quaternion, bù nghiêng gia tốc + từ (như
  `getRotationMatrix`), phương vị theo mép trên MÀN HÌNH (xoay 0/90/180/270) và tự chuyển sang hướng camera sau khi dựng
  đứng (liền mạch ở 45°), Madgwick MARG/IMU (khởi tạo bằng bù nghiêng, beta 1,5 trong 1,5 s đầu rồi 0,08), Kalman góc vòng
  2 trạng thái + lọc thông thấp thích ứng có dự báo theo tốc độ (không trễ khi xoay đều), phát hiện nhiễu từ (dải 18-75 µT
  + lệch > 20% so với nền EMA -> bỏ từ trường, giữ hướng bằng con quay), mức tin cậy cao / trung bình / thấp + cần hiệu
  chuẩn, phát hiện đứng yên 3 s -> hạ 20 Hz. Nguồn tự chọn: Madgwick (đủ con quay) > ROTATION_VECTOR > bù nghiêng.
  `DichVuHuong` chạy hợp nhất trong isolate riêng, một kết quả / lô; tab La bàn chỉ nghe khi app tiền cảnh + tab đang thấy
  (autoDispose -> nền tảng huỷ đăng ký cảm biến). Màn tạm: hoa gió xoay + chữ B, vạch mốc, số độ + 8 hướng, độ tin cậy,
  ngóc / nghiêng, cảnh báo nhiễu từ / hiệu chuẩn (vi/en, golden). Test sensors 56 (dữ liệu mô phỏng seed cố định: quỹ đạo
  nghiêng, xoay qua 0°, lệch con quay, nam châm, tạm dừng), phủ 99%; compass_feature 8; app 20. Phát hành APK
  v0.1.0-beta.2 để đo trên máy thật - CHƯA đo (chưa có thiết bị adb).

### A3 - Mặt la bàn
- Làm: CustomPainter + RepaintBoundary; heading 0,1°, 8 hướng; WMM2025 nhúng offline (hệ số cập nhật qua config ký số); bắc
  từ/bắc thực; mức tin cậy High/Medium/Low; luồng hiệu chuẩn hình 8; haptic; cảnh báo nhiễu từ.
- Cổng: declination so bảng NOAA < 0,2°; 60 FPS profile trên máy thật; golden.
- Phát sinh (từ A2): thay `_DocHuong` / `_HoaGio` tạm trong `man_la_ban.dart` bằng mặt la bàn CustomPainter; đọc
  `huongProvider` (`HuongDoc`: phuongVi đã lọc, doc / lan, theoCamera, muc, nhieuTu, canHieuChuan, cuongDoTu) - bắc thực =
  phuongVi + độ lệch WMM. Đo trên máy thật phần A2 còn treo (sai số đứng yên, độ trễ khi xoay, pin) - làm cùng A3 khi có
  adb; nếu Madgwick kém hơn ROTATION_VECTOR trên máy thật thì đổi mặc định `uuTienHeThong` (hoặc thêm lựa chọn ở A8).
- Kết quả (29/10): WMM2025 thuần Dart trong `packages/sensors/lib/src/domain/wmm.dart` (hệ số WMM.COF NOAA nhúng nguyên văn
  ở `wmm2025_cof.dart`, sha256 ghi ở đầu tệp; `HeSoWmm.tuCof` đọc COF để S3 thay bằng config ký số qua `heSoWmmProvider`;
  Legendre Schmidt + chuyển trắc địa/địa tâm WGS84). Cổng: 100/100 điểm `WMM2025_TestValues.txt` của NOAA lệch D/I < 0,006°,
  X/Y/Z/H/F < 1 nT. `compass_feature`: mặt số CustomPainter (vạch 2/10/30°, số độ, 8 hướng dịch, Bắc màu nhấn, chữ dài tự
  co) vẽ 1 lần trong RepaintBoundary, mỗi khung chỉ xoay layer; vạch mốc cố định; số độ 0,1° (`decimalPatternDigits`,
  vi "127,4°"); bố cục ngang 2 cột. Bắc thực mặc định = phương vị từ + D tại `viTriProvider` (CHƯA có nguồn vị trí -> hiện
  bắc từ + ghi chú "Chưa có vị trí"); µT, chế độ camera sau; cảnh báo nhiễu / hiệu chuẩn có nút mở màn hiệu chuẩn hình 8
  (hoạt ảnh lemniscate, tôn trọng Giảm chuyển động, phủ 8 cung + 4 tư thế hoặc tin cậy cao 1,5 s). Rung `selectionClick` khi
  qua 8 hướng (trễ 3°, không rung lặp ở ranh giới). Tuỳ chọn bắc thực / rung lưu `la_ban.json` (KhoLuuTru.laBan). Test
  compass_feature 37, sensors +16; golden mới `man_hieu_chuan`. APK v0.1.0-beta.3. CHƯA đo 60 FPS / sai số trên máy thật.
- Đo máy thật (29/10, Galaxy M32 SM-M325FV, Android 13, Helio G80, 90 Hz, Impeller GLES; bản dev profile, atrace qua
  USB - runbook `do-may-that-adb.md`): mặt số trong RepaintBoundary tốn ~12,8 ms raster MỖI khung (Impeller không có raster
  cache, bẫy IMPELLER RASTER CACHE) -> raster mặt số thành `ui.Image` một lần, mỗi khung chỉ xoay ảnh: 7,3 ms. Lô cảm biến
  chỉ ~45 lần/giây -> mặt số đổi mỗi 2 vsync (~45 FPS) -> `BoNoiSuyGoc` (domain, test) + Ticker nội suy góc theo vsync, chỉ
  dựng lại phép xoay. Kết quả: 60 Hz 58 FPS, rớt khung 0,35%, UI/raster p99 10,0/10,8 ms (cổng đạt); 90 Hz 86 FPS, rớt
  1,9% (0,26% do raster, còn lại pipeline UI+raster sát 11,1 ms trên G80). Đứng yên 58 s: ±0,45°, trôi +0,1°. Nam châm:
  66 µT -> cảnh báo nhiễu + tin cậy Thấp, hướng giữ (308,5 -> 308,2°), bỏ nam châm -> 38 µT, Cao, hết cảnh báo. Dựng
  đứng + xoay ngang: nhãn "Theo hướng camera sau", ngóc 89° (chưa so lệch 90° - thiếu hướng chuẩn). CHƯA đo: sai số tuyệt đối (cáp sạc gây lệch, cần
  hướng chuẩn), độ trễ xoay 90° (cần video 60 fps + ffmpeg), pin (phải rút cáp), Madgwick vs ROTATION_VECTOR -> làm khi có
  máy rảnh / Wi-Fi ổn định (Samsung tự tắt Gỡ lỗi không dây sau ~2 phút trên mạng này).
- Phát sinh (từ A3) cho A4: đẩy vị trí GPS / vị trí lưu gần nhất vào `viTriProvider` (`ref.read(viTriProvider.notifier).viTri
  = ViTriDiaLy(...)`, kiểu ở `sensors`) - app nối vì tính năng không gọi nhau; khi đó bắc thực tự bật.

### S1 - API lõi
- Đọc thêm: SEC-API, SEC-DATA.
- Làm: Hono `/v1`, zod validate (chặn trường lạ, giới hạn body), RFC 7807, Idempotency-Key, cursor; migration D1 0001 đủ bảng
  Spec §6.4 (audit có `hash_prev/hash_self`); DO `NonceGuard`, `RateWindow`; Rate Limiting binding; OpenAPI sinh tự động (không
  công khai); test vitest + miniflare.
- Cổng: test xanh; `wrangler deploy --env staging`; mọi lỗi không lộ stack.
- Kết quả (28/10, main 55b8dfa, PR #5): migration 0001 đủ 9 bảng §6.4 + `idempotency_keys` (audit chuỗi băm, trigger chỉ
  thêm, enforcement bắt buộc TTL + four-eyes khác người); `BoTuyen` sinh middleware + OpenAPI (`openapi.json`, không công
  khai); RFC 7807 chung chung + `x-request-id`, log che PII; DO `KhoNonce` / `GioiHanToc` thật; binding `RL_IP`,
  Analytics Engine `SU_KIEN`, cron dọn hạn lưu. 61 vitest (gồm tích hợp Miniflare D1 + workerd). Đã migrate + deploy staging
  rồi prod (`/v1/health` build 55b8dfa). Chưa có route nghiệp vụ: S2 thêm `/v1/device/*`, `/v1/session/refresh`.

### A4 - Vị trí + telemetry
- Làm: quyền just-in-time (While Using, ưu tiên approximate); DD/DMS/UTM/MGRS; cao độ GPS + baro; tốc độ, độ chính xác; µT +
  cảnh báo 25-65 µT; bubble level; mặt trời/mặt trăng offline; tra địa giới hành chính VN offline (Q28). VN-2000 để sau v1.0.
- Cổng: unit test chuyển đổi tọa độ với điểm mẫu chuẩn; golden thẻ telemetry tự lấp.
- Kết quả (29/10, nhánh `phase/a4-vi-tri`): plugin nội bộ `ViTriPlugin.kt` trong `packages/location_feature/android` dùng
  LocationManager của hệ điều hành (FUSED_PROVIDER Android 12+, máy cũ GPS + mạng) - KHÔNG Play Services / SDK mới; quyền
  COARSE + FINE "khi đang dùng", chỉ hỏi khi người dùng bấm "Cho phép vị trí" (tự nhớ đã hỏi để phân biệt chưa hỏi / từ chối
  hẳn -> nút mở Cài đặt), dịch vụ vị trí tắt -> nút mở cài đặt vị trí. Domain thuần Dart (`lib/src/domain`): DD / DMS / UTM
  (Krüger bậc 6) / MGRS khớp 328 điểm PROJ + GeoTrans (UTM < 1 mm, MGRS từng ký tự kể cả Na Uy / Svalbard); geoid EGM96 1°
  (asset 130 KB, VN < 1,5 m so lưới 15'); độ cao khí áp + hiệu chỉnh QNH theo GPS; mặt trời / mặt trăng Meeus (so ephem 60
  ca: mặt trời < 0,02°, mọc / lặn < 1 phút; mặt trăng < 0,1°, < 2 phút; pha); thước thuỷ có trễ; µT so WMM (25-65 µT, lệch >
  20%); địa giới VN ngoại tuyến (Q28) - asset 2,2 MB từ OSM 27/10/2026: 34 tỉnh + 3320 xã / phường / đặc khu (Hoàng Sa thuộc
  Đà Nẵng, Trường Sa thuộc Khánh Hòa), giải mã lười + chẵn-lẻ, công cụ `tools/build/dia-gioi.py`. Provider dùng chung
  (`huongProvider`, `viTriProvider`, `tuTruongProvider`...) chuyển xuống `sensors` (compass_feature re-export) để la bàn và
  vị trí dùng CHUNG một luồng cảm biến. Tab La bàn: `ManLaBan(theDuoi: TheViTri())` (app nối) - thẻ toạ độ (chạm đổi định
  dạng, giữ để chép), xã / tỉnh, độ cao, sai số; mỗi lần đọc đẩy vào `viTriProvider` -> bắc thực tự bật; vị trí làm tròn 0,1°
  lưu `vi_tri.json` làm vị trí ban đầu lần mở sau. Màn "Vị trí & thông số": 4 định dạng + chép, địa giới + © OpenStreetMap,
  di chuyển, độ cao GPS / khí áp / áp suất, từ trường, thước thuỷ, mặt trời, mặt trăng. Giấy phép ODbL + EGM96 vào
  `LicenseRegistry` và `design/LICENSES.md`. location_feature 422 test (domain phủ 94-100%), golden `the_vi_tri` +
  `man_vi_tri`. CHƯA thử GPS / quyền trên máy thật.
- Phát sinh (từ A4): iOS CoreLocation + Info.plist NSLocationWhenInUse -> I1. Thử GPS máy thật (quyền xấp xỉ / chính xác,
  FUSED_PROVIDER, độ cao Android 14 mslAltitude) cùng đợt đo A2/A3 còn treo. VN-2000 vẫn để sau v1.0 (Q26). Màn vị trí mở
  qua nút "Chi tiết" trên thẻ - A8 cân nhắc lối vào riêng (tab / phím tắt) và tuỳ chọn đơn vị (ft, mph). Dữ liệu địa giới
  cập nhật qua config ký số / R2 ở S3 nếu cần (hiện nhúng trong APK).

### A5 - Lưu trữ + cập nhật an toàn
- Đọc thêm: Spec §10, SEC-APP-STORAGE.
- Làm: Drift + SQLCipher, khóa sinh ngẫu nhiên bọc Keystore/Keychain; loại khỏi backup; schemaVersion + snapshot trước
  migration + khôi phục khi lỗi; khung test migration mọi phiên bản (10.000 waypoint, so checksum); crash sentinel 3 lần ->
  safe mode; feature flag cục bộ.
- Cổng: test migration + khôi phục xanh.
- Phát sinh (từ A1): `CaiDat` (ngôn ngữ, sáng/tối, `daXemGioiThieu`) trong `settings_feature` mới giữ trong bộ nhớ -> lưu
  bền qua storage (đọc trước khung đầu để không nháy theme / không hiện lại màn giới thiệu).
- Kết quả (28/10, QUYET_DINH Q32): `packages/storage` thành plugin nội bộ - SQLCipher 4.19 qua hook `sqlite3` 3.8
  (`source: sqlcipher`), Drift 2.35 `CsdlLaBan` schema v1 (`diem`, `lich_su_migration`, ảnh chụp `drift_schemas/`); khoá
  32 byte bọc Android Keystore AES-GCM (StrongBox nếu có, `noBackupFilesDir`) / iOS Keychain ThisDeviceOnly + Application
  Support loại khỏi backup; Android `dataExtractionRules` loại cloud-backup + device-transfer. `moCsdl`: kiểm khoá (mất khoá
  -> `.hong` + CSDL mới) -> `user_version` -> snapshot tệp mã hoá -> migrate 1 transaction + `quick_check` -> lỗi thì khôi
  phục snapshot; CSDL của bản mới hơn không mở. Canh gác crash 3 lần -> chế độ an toàn ghim theo phiên bản (lên bản mới tự
  gỡ), ổn định = 5 s sau khung đầu hoặc về nền; cờ tính năng cục bộ `tinhCo` (an toàn > kill-switch > cục bộ > mặc định);
  băng an toàn vi/en + tab Bản đồ tạm tắt. `CaiDat` lưu bền tệp JSON nguyên tử đọc trước khung đầu. Test: storage 43
  (migration 10.000 điểm so checksum, khôi phục, sai khoá, ma trận schema drift), độ phủ lib 93%; app thêm 9 (ma trận 216
  ô không tràn + golden `an_toan`). APK dev debug build OK (`libsqlcipher.so` 3 ABI). Chưa thử trên máy thật / iOS.

### S2 - Định danh + attestation + phiên
- Đọc thêm: SEC-ID.
- Làm: Installation ID; khóa ECDSA P-256 phần cứng; `/v1/device/register|attest`, `/v1/session/refresh`; xác minh Play Integrity
  ở server (xác minh App Attest dời sang I1 - Q33); JWT ES256 15 phút gắn khóa thiết bị; refresh xoay vòng +
  phát hiện dùng lại; trạng thái `UNVERIFIED` khi dịch vụ lỗi.
- Cổng: test với token mẫu; luồng end-to-end trên máy thật (staging).
- Phát sinh (từ S1): route mới đăng ký qua `boTuyen.dangKy` (workers/api/src/tuyen.ts - schema zod strict, giới hạn, Idempotency
  tự gắn) rồi `CAP_NHAT_OPENAPI=1 npx vitest run test/openapi.test.ts`; middleware xác thực đặt `phamViIdem` =
  `thiet-bi:<id>` / `phien:<id>` để Idempotency + giới hạn chiều `thiet-bi` / `phien` có hiệu lực; nonce dùng DO `KHO_NONCE`
  (`idFromName('thiet-bi:<id>')`, POST {nonce, ttlMs}); ghi `device_ips` khi đăng ký / làm mới phiên.

### S3 - Bảo vệ kênh truyền
- Đọc thêm: SEC-NET.
- Làm: chữ ký request bằng khóa thiết bị (chuỗi chuẩn Spec §7.5); dio interceptor; SPKI pinning >= 2 pin + xoay pin qua config
  ký số; `network_security_config` + ATS chặt; `/v1/config` (Ed25519, KV) + `/v1/status`; force/soft update.
- Cổng: request sai chữ ký / replay / hết hạn bị từ chối (test); xoay pin thử trên staging không cần bản mới.

### S4 - Làm cứng app
- Đọc thêm: SEC-APP.
- Làm: freeRASP + kiểm tra native bổ sung (bộ tín hiệu theo Spec §7.3b, chỉ báo về server); build `--obfuscate
  --split-debug-info` + R8 full + upload symbol; chuỗi cấu hình mã hóa lúc build; FLAG_SECURE / che app switcher ở màn nhạy cảm;
  phản ứng theo Risk Level (Spec §7.3 bảng) + màn khóa có mã REF; không chạy kiểm tra ở bản debug nội bộ.
- Phát sinh (từ A5, SEC-APP-STORAGE): logger chung (`core`) che token / tọa độ chính xác ở release; báo `LyDoAnToan` +
  `KetQuaMoCsdl.loi` / `lamMoiDoMatKhoa` về server (đã ẩn PII) khi có kênh ký request; nối kill-switch Remote Config vào
  `tinhCo(tatTuXa:)` (`coTinhNangProvider` ở `app/lib/src/luu_tru.dart`).
- Cổng: bản release trên máy thật sạch không báo nhầm; bản debug/giả lập sinh đúng sự kiện.

### S5 - Threat Engine
- Đọc thêm: SEC-DET.
- Làm: ingest lô ký số; bảng điểm + ngưỡng cấu hình (Spec §7.6c); rule engine JSON có cửa sổ thời gian, shadow mode >= 7 ngày;
  enforcement TTL leo thang; allow-list (gồm IP review của store); liên kết thiết bị bằng tín hiệu mềm; đồng bộ chặn IP lên
  Cloudflare Lists (có TTL); cron hạ điểm theo thời gian; ghi Analytics Engine.
- Cổng: test thuần cho chấm điểm/rule; mô phỏng lô sự kiện -> đúng trạng thái; đồng bộ chặn <= 30 s.
- Kết quả (28/10): migration 0002 (expand: `allow_list`, `threat_config` có phiên bản, `alerts` gộp theo rule + nhóm,
  `rule_hits`, `device_links`, cột hồi phục / `ip_prefix` / `pending_approval` / `level`; 5 rule khởi điểm R-001..R-005 ở
  shadow). Thuần: `thuan/nguy-co.ts` (bảng điểm §7.6c cấu hình được, ngưỡng, -5/tuần tới sàn, TTL 24h -> 7d -> 30d -> 365d
  - "vĩnh viễn" của spec đổi thành 365 ngày để mọi chặn có hạn theo Q12), `thuan/luat.ts` (rule JSON: event + group_by
  device/ip/cidr24 + đếm events/devices/types, shadow >= 7 ngày, không kích hoạt lặp trong cửa sổ), `thuan/ip.ts`,
  `thuan/thuc-thi.ts` (allow-list, chặn dải chỉ đề xuất trừ Under Attack, chênh lệch Cloudflare List, liên kết thiết bị
  tín hiệu mềm). `threat/dong-co.ts` `xuLySuKien`: chèn chống trùng event_id -> điểm -> rule -> enforcement + audit ->
  trạng thái; bị cấm -> thu hồi phiên + `DEVICE_BANNED` (cho R-002) + liên kết. Middleware `chanTheoThucThi` chặn IP / dải
  / ASN ở Worker (403 `bi-chan`, allow-list thắng); DO `GioiHanToc` báo `lanDauVuot` -> sự kiện `RATE_ABUSE`. Cron đổi sang
  `*/5` (hồi phục, hạ trạng thái khi chặn hết hạn, đồng bộ List; dọn hạn lưu ở lượt 19:15 UTC). Cloudflare List
  `la_ban_chan_ip` (gói Free chỉ cho 1 List -> chỉ prod; staging chặn ở Worker). 33 test mới (thuần + mô phỏng lô trên
  Miniflare D1).
- Phát sinh (từ S5) -> S3: route `POST /v1/events` (schema `schemaLoSuKien` ở `thuan/su-kien.ts`, chữ ký lô) gọi
  `xuLySuKien` + `dongBoLists` qua waitUntil; `SIGNATURE_MISMATCH` / `ATTEST_FAIL` do server sinh cũng qua `xuLySuKien`.
  -> S2: middleware xác thực từ chối thiết bị `status = banned` + gọi `lienKetThietBi` khi đăng ký. -> S7: UI rule (bật
  active chỉ khi `coTheBatThucThi`), duyệt đề xuất chặn dải (`pending_approval`), bật Under Attack, sửa `threat_config`
  (tạo phiên bản mới + audit). -> S8: WAF custom rule `ip.src in $la_ban_chan_ip` cho compass-api.

### S6 - Admin SOC 1
- Đọc thêm: SEC-ADM.
- Làm: Access (Google) + kiểm JWT Access ở Worker + vai trò D1 (5 vai trò Spec §8.1); passkey WebAuthn step-up; phiên ngắn;
  tổng quan realtime qua DO WebSocket; danh sách thiết bị ảo hóa + lọc + chi tiết (timeline, IP/ASN, liên quan); ẩn PII cho
  Viewer; vi/en, light/dark.
- Cổng: người không có vai trò bị 403; cảnh báo hiện < 1,5 s.

### S7 - Admin SOC 2
- Làm: trung tâm cảnh báo (dedup, trạng thái, Telegram); rule UI + mô phỏng 7 ngày; can thiệp (Spec §8.2-5) với lý do bắt
  buộc; four-eyes cho hành động hàng loạt; khiếu nại; báo cáo CSV/PDF; xem + kiểm chuỗi audit; quản lý Remote Config / phiên
  bản tối thiểu / pin dự phòng (ký số, cần duyệt).
- Cổng: kill-switch <= 5 s; audit sửa tay bị phát hiện; four-eyes không tự duyệt được.

### A6 - Waypoint + chia sẻ
- Làm: CRUD waypoint (ghi chú, ảnh), điều hướng (Vincenty), GPX/KML import/export, link `compass.tsudev.com/w/<token>` hết hạn,
  QR; App Links + Universal Links (assetlinks.json, AASA trên landing).
- Cổng: round-trip GPX không mất dữ liệu; deep link mở đúng app trên máy thật.
- Phát sinh (từ A5): bảng `diem` (schema v1) đã có trong `CsdlLaBan` (`packages/storage`); mở rộng cột / bảng = migration v2
  CHỈ THÊM: tăng `schemaVersion` (số literal), thêm bước vào `buocMigration`, `dart run drift_dev make-migrations` + `schema
  generate ... test/drift/csdl/generated/`, chạy `build_runner build`; test ma trận `test/drift` tự phủ v1 -> v2. Cần
  `csdlProvider` (app đã có `khoLuuTruProvider`, `KhoLuuTru.csdl` null ở chế độ an toàn) + màn xuất điểm ở chế độ an toàn
  (Spec §10.4 "cho phép xuất dữ liệu waypoint") - đọc thô cột v1 bằng `sqlite3` khi Drift không mở được.

### A7 - Bản đồ + AR
- Làm: MapLibre + PMTiles VN trên R2 (xác minh hỗ trợ PMTiles trong bản plugin; không được thì MBTiles); tải gói offline có
  quản lý dung lượng; lớp la bàn + waypoint; Camera AR bằng camera + fusion (không ARCore/ARKit để giữ dung lượng).
- Cổng: dùng được ở chế độ máy bay; app vẫn < 25 MB (tile tải riêng).

### R1 - Landing
- Làm: Astro vi/en: giới thiệu, nút tải store, hướng dẫn hiệu chuẩn, `/privacy`, `/terms`, `/appeal` (Turnstile, gửi Worker),
  `/w/<token>` fallback; SEO, OG; Core Web Vitals Good.
- Cổng: Lighthouse >= 95; form khiếu nại vào Admin.
- Kết quả (28/10, làm cùng R0 theo yêu cầu người dùng): 13 trang tĩnh vi/en (`/`, `/tai-ve`, `/huong-dan`,
  `/quyen-rieng-tu`, `/dieu-khoan`, `/khieu-nai` + `/en/*`, 404, sitemap hreflang sinh từ `DUONG_DAN`), chữ ở một nguồn
  `src/i18n/noi-dung.ts` (kiểu bắt buộc đủ khoá hai ngôn ngữ); 0 JS phía trình duyệt (menu di động `<details>`, hỏi đáp
  `<details>`), không thuộc tính `style` inline (CSP hiện có giữ nguyên); minh hoạ điện thoại + mặt la bàn bằng SVG theo
  token sáng / tối, kim lắc bằng CSS (tắt khi reduced-motion); font Be Vietnam Pro tách tập Việt + Latin woff2 (~36 KB / độ
  đậm); trang tải đọc `latest.json` LÚC BUILD (QR sinh lúc build bằng `qrcode`, chỉ devDependency). Đã soát ảnh chụp 390 /
  1280 px sáng / tối: không tràn ngang.
- Phát sinh -> S7: form khiếu nại (Turnstile + route Worker vào bảng `appeals`) thay mailto hiện tại; Lighthouse đo sau
  deploy. -> S8: CSP nonce cho script dò bot của Cloudflare vẫn như cũ.

### S8 - Bảo vệ edge web
- Đọc thêm: SEC-EDGE, SEC-WEB-CSP.
- Làm: CSP nonce qua Pages Function middleware (Report-Only 1 tuần -> chặn), Trusted Types, SRI/tự host; header A+; WAF managed
  + custom rule + rate-limit rule ở `tools/cloudflare` (log-only trước); Access chặn admin; honeypot endpoint ghi sự kiện;
  Turnstile.
- Cổng: securityheaders A+, SSL Labs A+, Observatory A+; preview branch trước main.
- Kết quả (29/10): landing chạy Pages advanced mode `_worker.js` (nguồn `web/landing/edge/`, esbuild sau `astro build`,
  `_routes.json` sinh tự động - tài sản tĩnh không gọi worker): mỗi trang HTML nhận nonce 128 bit mới, gắn vào CẢ hai header
  CSP + mọi thẻ `<script>` (HTMLRewriter); bỏ ETag / header điều kiện (bẫy NONCE + 304), bỏ ACAO `*`. CSP CHẶN =
  `script-src 'self' 'nonce-X'` (script dò bot Cloudflare chạy được, không `unsafe-*`); CSP REPORT-ONLY = `'strict-dynamic'`
  + Trusted Types (`require-trusted-types-for 'script'; trusted-types 'none'`), cả hai `report-uri` + `report-to` ->
  `POST /v1/web/csp` (Worker, CORS chỉ landing/admin, 30/phút/IP, chuẩn hoá không PII -> Analytics Engine). Đọc + tiêu chí bật
  chặn: `docs/runbook/csp-bao-cao.md`. Honeypot: middleware `bayQuet` (đường dẫn máy quét `/.env`, `/wp-*`, `*.php`...) -> 404
  + sự kiện `HONEYPOT_HIT` (nhãn bẫy, không nguyên đường dẫn; nén 10 s/IP/isolate) + rule R-006 (migration 0003, shadow:
  >= 3 lần/giờ -> chặn IP). Zone as code tổng quát: `quyTac` (rule theo phase, nhận diện bằng description) + `rumLoaiTru`
  (loại trừ Web Analytics tự chèn - bẫy WEB ANALYTICS TU CHEN); WAF custom MỘT rule "la-ban: chặn edge" (`$la_ban_chan_ip` cho
  mọi host compass-* + admin ngoài VN) - Free zone dùng chung chỉ còn 2/5 custom rule, 0/1 rate-limit rule (bẫy WAF FREE ZONE
  DUNG CHUNG). Managed: "Cloudflare Managed Free Ruleset" mặc định của zone (OWASP cần Pro). Observatory A+ (145) trước và sau.
- Phát sinh (từ S8) -> 05/11/2026: đọc báo cáo CSP 7 ngày, chuyển `strict-dynamic` sang header chặn (runbook csp-bao-cao).
  -> S6: Access chặn admin (cần Zero Trust) + CSP nonce cho admin (dùng lại `web/landing/edge` qua gói chung khi admin có
  HTML thật). -> S7: Turnstile (widget + `siteverify` ở Worker) cùng form khiếu nại. -> S10: bảng CSP / honeypot trong SOC.

### S9 - Bảo vệ nội dung web + build sạch
- Đọc thêm: SEC-WEB-SHIELD, SEC-WEB-BUILD.
- Làm: gói `web/shield` áp cho landing + admin, bật/tắt + mức độ qua config ký số; watermark động ở admin; ảnh qua URL ký; build
  xoá 100% comment, console, sourcemap, LICENSE.txt; làm rối mã module nhạy cảm (tương thích CSP); script `ve-sinh-ban-build`.
- Cổng: script vệ sinh xanh; không ảnh hưởng trợ năng (ô nhập vẫn chọn/dán được); tín hiệu về Threat Engine.

### A8 - Hoàn thiện app
- Làm: màn Quyền riêng tư (xem/xuất/xóa, rút đồng ý); onboarding + thông báo xử lý dữ liệu (NĐ 13/2023); VoiceOver/TalkBack;
  Reduce motion; tối ưu cold start (lazy SDK), dung lượng, pin.
- Cổng: ngân sách mục 2 đạt trên máy tham chiếu; audit trợ năng.
- Phát sinh (từ A5): màn Giấy phép thêm SQLCipher (BSD, Zetetic) + OpenSSL (Apache 2, bản Android) + drift / sqlite3 (MIT)
  vào `LicenseRegistry`; đo cold start gồm `KhoLuuTru.mo` (mở CSDL ở isolate nền, khoá Keystore) trên máy thật.

### S10 - Vận hành an ninh
- Đọc thêm: SEC-MON.
- Làm: Sentry + Crashlytics (che PII); Tail Worker -> R2 có hash chain + object lock; cảnh báo Telegram; backup D1 hằng ngày ->
  R2 + diễn tập khôi phục; trang status; runbook sự cố, xoay khóa/pin, gỡ chặn (`docs/runbook/`).
- Cổng: diễn tập khôi phục đạt RPO/RTO; cảnh báo thử tới < 2 phút.

### R2 - Sẵn sàng store
- Làm: khóa upload Android (ngoài repo) + Play App Signing; scheme/configuration flavor iOS dev/staging/prod (Xcode trên Codemagic/Mac); Codemagic cho iOS (App Store Connect API key); Privacy Manifest +
  Required Reason API; Data Safety khớp thực tế (gồm SDK bên thứ ba); `NS*UsageDescription` vi/en; ảnh store sinh tự động từ
  integration test; listing vi/en; ghi chú reviewer về cơ chế bảo mật; allow-list thiết bị review.
- Cổng: bản internal (Play) cài được (TestFlight dời sang I1 - Q33).
- Ghi chú (Q33/Q34): phần iOS của thẻ này (scheme flavor, Codemagic, Privacy Manifest, `NS*UsageDescription`) chuyển sang I1.
  Play App Signing: chọn tải lên khoá upload R0 làm khoá ký ứng dụng để người đã cài APK thử cập nhật thẳng từ Play.

### R3 - QA tổng
- Đọc thêm: SEC-TEST.
- Làm: E2E (cài mới -> attest -> la bàn -> waypoint -> chia sẻ -> nâng cấp); ma trận nâng cấp + OTA + rollback; benchmark;
  MobSF + ZAP + Semgrep; bộ kịch bản kiểm thử bảo mật nội bộ trên thiết bị thử của dự án; chuẩn bị gói cho pentest độc lập.
- Cổng: tiêu chí Spec §15 mục 1-11 đạt; 0 Critical/High mở.

### R4 - Phát hành v1.0.0
- Làm: staged rollout Play (1->5->20->50->100%) (iOS phased ở I1); Shorebird kênh staging -> stable; theo dõi crash-free, ANR, chặn
  nhầm; runbook trực.
- Cổng: crash-free >= 99,8%; không sự cố mở. Bắt đầu đếm 4 tuần Release Gate.

### M1 - Quảng cáo + IAP
- Đọc thêm: Spec §12.
- Làm: AdMob + UMP + ATT; banner thích ứng có chỗ dành sẵn; interstitial giới hạn tần suất; rewarded xác minh SSV ở Worker;
  RevenueCat Pro + webhook + Restore; thiết bị restricted/banned không nhận quảng cáo/thưởng; kill-switch từng loại quảng cáo;
  cập nhật Data Safety / Privacy Label.
- Cổng: chênh FPS có/không quảng cáo < 2%; không che la bàn; v1.1.0.

### R0 - Bản APK thử nghiệm (Android, QUYET_DINH Q34)
- Làm: khoá upload RSA 4096 ngoài repo (`~/.config/la-ban/android/upload.jks` + `key.properties`, người dùng sao lưu);
  `build.gradle.kts` ký release bằng khoá đó khi có, không có thì ký debug (máy khác vẫn build được); `tools/build/phat-hanh-apk.sh`:
  kiểm cây git sạch + đúng tag -> `flutter build apk --flavor prod --release --obfuscate --split-debug-info` (arm64-v8a +
  universal) -> `apksigner verify` -> SHA-256 -> R2 `la-ban-cdn/android/` (tên có phiên bản + `latest.json`) -> GitHub
  Release pre-release (APK + `SHA256SUMS`) -> ghi `web/landing/src/data/apk.json` cho trang tải; symbol giữ ngoài repo.
- Cổng: `apksigner verify` đạt; tải từ `compass-cdn` đúng SHA-256; cài được trên máy Android thật (người dùng thử).
- Kết quả (28/10, main fac899e, PR #8): khoá upload RSA 4096 (chứng chỉ SHA-256 `CF:09:E7:24:...:F6:BD`, hạn 2056);
  nén thư viện native (`useLegacyPackaging`) -> arm64 10,3 MB / universal 28,7 MB. Phát hành `v0.1.0-beta.1`: GitHub
  pre-release (2 APK + `SHA256SUMS`), R2 `compass-cdn.tsudev.com/android/` (đúng `content-type` + `attachment`, SHA-256
  khớp), `latest.json`; landing `/tai-ve` đã deploy hiện phiên bản + SHA-256 + QR. Người dùng đã tải + cài thành công
  trên điện thoại Android thật (28/10, sau sửa PR #9: bỏ CSP sandbox ở `/android/`, cảnh báo trình duyệt Zalo/Facebook). Phát hành bản sau: tăng `version` ở `app/pubspec.yaml` + `phienBanApp` -> PR -> `./tools/build/phat-hanh-apk.sh`
  trên main sạch -> `./tools/build/deploy-web.sh landing`.
- Phát sinh -> S3: `/v1/status` đọc `latest.json` để app báo có bản mới (bản tải ngoài Play chưa có cơ chế tự cập nhật).

### I1 - iOS (đầu năm 2027, QUYET_DINH Q33)
- Làm: build iOS trên Mac / Codemagic (Q6); scheme flavor dev/staging/prod; plugin `storage` Keychain + `sensors` CoreMotion
  thử thật; App Attest (client + xác minh attestation / assertion ở Worker); kiểm tra jailbreak (S4 phần iOS); Privacy Manifest
  + Required Reason API; `NS*UsageDescription` vi/en; TestFlight -> App Store (Q21 tên "La bàn: Smart Compass"); nút App Store
  trên landing.
- Phát sinh (từ A2): `packages/sensors` hiện chỉ khai báo plugin Android - thêm `ios/` (CoreMotion deviceMotion
  xArbitraryCorrectedZVertical + magnetometer đã hiệu chuẩn, CLHeading cho độ chính xác) phát đúng định dạng lô 7 số của
  `giaiMaLo`; trước đó iOS hiện "không có cảm biến la bàn".
- Cổng: TestFlight cài được; golden + test chung vẫn xanh; App Attest end-to-end trên staging.
