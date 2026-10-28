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
| 5 | A2 | Cảm biến + sensor fusion | A1 | ⬜ |
| 6 | A3 | Mặt la bàn, bắc thực WMM, hiệu chuẩn | A2 | ⬜ |
| 7 | S1 | API lõi + schema D1 | N2 | ✅ 28/10 |
| 8 | A4 | Vị trí + telemetry | A3 | ⬜ |
| 9 | A5 | Lưu trữ mã hóa, migration, safe mode | A1 | ⬜ |
| 10 | S2 | Định danh thiết bị + attestation + phiên | S1, A5 | ⬜ |
| 11 | S3 | Ký request, pinning, Remote Config ký số | S2 | ⬜ |
| 12 | S4 | Làm cứng app | S3 | ⬜ |
| 13 | S5 | Threat Engine + enforcement | S1 | ⬜ |
| 14 | S6 | Admin SOC 1 | S5 | ⬜ |
| 15 | S7 | Admin SOC 2 | S6 | ⬜ |
| 16 | A6 | Waypoint, chia sẻ, deep link | A5, S3 | ⬜ |
| 17 | A7 | Bản đồ offline + Camera AR | A6 | ⬜ |
| 18 | R1 | Landing hoàn chỉnh | N2, S7 | ⬜ |
| 19 | S8 | Bảo vệ edge web (CSP, header, WAF as code) | R1 | ⬜ |
| 20 | S9 | Lớp bảo vệ nội dung web + build sạch | S8 | ⬜ |
| 21 | A8 | Cài đặt, quyền riêng tư, trợ năng, hiệu năng | A7, S4 | ⬜ |
| 22 | S10 | Giám sát, log bất biến, backup, ứng phó sự cố | S7 | ⬜ |
| 23 | R2 | Sẵn sàng store | A8, S4 | ⬜ |
| 24 | R3 | QA tổng + kiểm thử bảo mật | R2, S9, S10 | ⬜ |
| 25 | R4 | Phát hành v1.0.0 + OTA | R3 | ⬜ |
| 26 | M1 | Quảng cáo + IAP (v1.1.0) sau Release Gate | R4 | ⬜ |

Có thể giao agent thứ hai song song: S1 với A2-A3 · A5 với A4 · S5 với S4 · A6 với S6-S7 · R1 với A7 · A8 với S8-S9.

**Việc người dùng:** trước N2 tạo API token Cloudflare (zone tsudev.com: DNS, WAF, Lists; Workers, Pages, D1, R2) lưu ở
`~/.config/la-ban/cf.env` · trước A2 bật Wireless debugging trên 1 điện thoại Android · trước S2 Google Cloud project + Play
Integrity API + service account, Apple Team ID · trước S6 bật Cloudflare Zero Trust · trước R2 tài khoản Play Console + Apple
Developer, Codemagic, duyệt Privacy Policy · trước R4 chốt đơn vị pentest, bấm phát hành · trước M1 tài khoản AdMob + RevenueCat.

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

### A3 - Mặt la bàn
- Làm: CustomPainter + RepaintBoundary; heading 0,1°, 8 hướng; WMM2025 nhúng offline (hệ số cập nhật qua config ký số); bắc
  từ/bắc thực; mức tin cậy High/Medium/Low; luồng hiệu chuẩn hình 8; haptic; cảnh báo nhiễu từ.
- Cổng: declination so bảng NOAA < 0,2°; 60 FPS profile trên máy thật; golden.

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

### A5 - Lưu trữ + cập nhật an toàn
- Đọc thêm: Spec §10, SEC-APP-STORAGE.
- Làm: Drift + SQLCipher, khóa sinh ngẫu nhiên bọc Keystore/Keychain; loại khỏi backup; schemaVersion + snapshot trước
  migration + khôi phục khi lỗi; khung test migration mọi phiên bản (10.000 waypoint, so checksum); crash sentinel 3 lần ->
  safe mode; feature flag cục bộ.
- Cổng: test migration + khôi phục xanh.
- Phát sinh (từ A1): `CaiDat` (ngôn ngữ, sáng/tối, `daXemGioiThieu`) trong `settings_feature` mới giữ trong bộ nhớ -> lưu
  bền qua storage (đọc trước khung đầu để không nháy theme / không hiện lại màn giới thiệu).

### S2 - Định danh + attestation + phiên
- Đọc thêm: SEC-ID.
- Làm: Installation ID; khóa ECDSA P-256 phần cứng; `/v1/device/register|attest`, `/v1/session/refresh`; xác minh Play Integrity
  ở server; xác minh App Attest (attestation + assertion) ở server; JWT ES256 15 phút gắn khóa thiết bị; refresh xoay vòng +
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
- Cổng: bản release trên máy thật sạch không báo nhầm; bản debug/giả lập sinh đúng sự kiện.

### S5 - Threat Engine
- Đọc thêm: SEC-DET.
- Làm: ingest lô ký số; bảng điểm + ngưỡng cấu hình (Spec §7.6c); rule engine JSON có cửa sổ thời gian, shadow mode >= 7 ngày;
  enforcement TTL leo thang; allow-list (gồm IP review của store); liên kết thiết bị bằng tín hiệu mềm; đồng bộ chặn IP lên
  Cloudflare Lists (có TTL); cron hạ điểm theo thời gian; ghi Analytics Engine.
- Cổng: test thuần cho chấm điểm/rule; mô phỏng lô sự kiện -> đúng trạng thái; đồng bộ chặn <= 30 s.

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

### A7 - Bản đồ + AR
- Làm: MapLibre + PMTiles VN trên R2 (xác minh hỗ trợ PMTiles trong bản plugin; không được thì MBTiles); tải gói offline có
  quản lý dung lượng; lớp la bàn + waypoint; Camera AR bằng camera + fusion (không ARCore/ARKit để giữ dung lượng).
- Cổng: dùng được ở chế độ máy bay; app vẫn < 25 MB (tile tải riêng).

### R1 - Landing
- Làm: Astro vi/en: giới thiệu, nút tải store, hướng dẫn hiệu chuẩn, `/privacy`, `/terms`, `/appeal` (Turnstile, gửi Worker),
  `/w/<token>` fallback; SEO, OG; Core Web Vitals Good.
- Cổng: Lighthouse >= 95; form khiếu nại vào Admin.

### S8 - Bảo vệ edge web
- Đọc thêm: SEC-EDGE, SEC-WEB-CSP.
- Làm: CSP nonce qua Pages Function middleware (Report-Only 1 tuần -> chặn), Trusted Types, SRI/tự host; header A+; WAF managed
  + custom rule + rate-limit rule ở `tools/cloudflare` (log-only trước); Access chặn admin; honeypot endpoint ghi sự kiện;
  Turnstile.
- Cổng: securityheaders A+, SSL Labs A+, Observatory A+; preview branch trước main.

### S9 - Bảo vệ nội dung web + build sạch
- Đọc thêm: SEC-WEB-SHIELD, SEC-WEB-BUILD.
- Làm: gói `web/shield` áp cho landing + admin, bật/tắt + mức độ qua config ký số; watermark động ở admin; ảnh qua URL ký; build
  xoá 100% comment, console, sourcemap, LICENSE.txt; làm rối mã module nhạy cảm (tương thích CSP); script `ve-sinh-ban-build`.
- Cổng: script vệ sinh xanh; không ảnh hưởng trợ năng (ô nhập vẫn chọn/dán được); tín hiệu về Threat Engine.

### A8 - Hoàn thiện app
- Làm: màn Quyền riêng tư (xem/xuất/xóa, rút đồng ý); onboarding + thông báo xử lý dữ liệu (NĐ 13/2023); VoiceOver/TalkBack;
  Reduce motion; tối ưu cold start (lazy SDK), dung lượng, pin.
- Cổng: ngân sách mục 2 đạt trên máy tham chiếu; audit trợ năng.

### S10 - Vận hành an ninh
- Đọc thêm: SEC-MON.
- Làm: Sentry + Crashlytics (che PII); Tail Worker -> R2 có hash chain + object lock; cảnh báo Telegram; backup D1 hằng ngày ->
  R2 + diễn tập khôi phục; trang status; runbook sự cố, xoay khóa/pin, gỡ chặn (`docs/runbook/`).
- Cổng: diễn tập khôi phục đạt RPO/RTO; cảnh báo thử tới < 2 phút.

### R2 - Sẵn sàng store
- Làm: khóa upload Android (ngoài repo) + Play App Signing; scheme/configuration flavor iOS dev/staging/prod (Xcode trên Codemagic/Mac); Codemagic cho iOS (App Store Connect API key); Privacy Manifest +
  Required Reason API; Data Safety khớp thực tế (gồm SDK bên thứ ba); `NS*UsageDescription` vi/en; ảnh store sinh tự động từ
  integration test; listing vi/en; ghi chú reviewer về cơ chế bảo mật; allow-list thiết bị review.
- Cổng: bản internal (Play) + TestFlight cài được.

### R3 - QA tổng
- Đọc thêm: SEC-TEST.
- Làm: E2E (cài mới -> attest -> la bàn -> waypoint -> chia sẻ -> nâng cấp); ma trận nâng cấp + OTA + rollback; benchmark;
  MobSF + ZAP + Semgrep; bộ kịch bản kiểm thử bảo mật nội bộ trên thiết bị thử của dự án; chuẩn bị gói cho pentest độc lập.
- Cổng: tiêu chí Spec §15 mục 1-11 đạt; 0 Critical/High mở.

### R4 - Phát hành v1.0.0
- Làm: staged rollout Play (1->5->20->50->100%) + iOS phased; Shorebird kênh staging -> stable; theo dõi crash-free, ANR, chặn
  nhầm; runbook trực.
- Cổng: crash-free >= 99,8%; không sự cố mở. Bắt đầu đếm 4 tuần Release Gate.

### M1 - Quảng cáo + IAP
- Đọc thêm: Spec §12.
- Làm: AdMob + UMP + ATT; banner thích ứng có chỗ dành sẵn; interstitial giới hạn tần suất; rewarded xác minh SSV ở Worker;
  RevenueCat Pro + webhook + Restore; thiết bị restricted/banned không nhận quảng cáo/thưởng; kill-switch từng loại quảng cáo;
  cập nhật Data Safety / Privacy Label.
- Cổng: chênh FPS có/không quảng cáo < 2%; không che la bàn; v1.1.0.
