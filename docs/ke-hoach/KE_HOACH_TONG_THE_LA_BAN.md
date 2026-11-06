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
4. Quảng cáo / IAP chỉ bật sau Release Gate (Spec §12.1). Người dùng có quyền lợi `khongQuangCao` (gói Pro trong app hoặc
   app trả phí "La bàn Pro") KHÔNG BAO GIỜ khởi tạo SDK quảng cáo; quyền lợi do Worker xác minh với Google Play (Q55, Q56).
5. Mọi tính năng: vi + en, light + dark, không overflow, có test.
6. **Android trước** (QUYET_DINH Q33, chốt 28/10/2026): mọi phase chỉ thi công + nghiệm thu phần Android; phần iOS gom vào
   phase I1 (đầu năm 2027, khi có máy Mac + Apple Developer). Bản thử phát hành dạng APK tải trực tiếp (R0, Q34) trước khi lên Play.

## 1. Kiến trúc thực hiện

| Thành phần | Công nghệ | Tên miền |
|---|---|---|
| App | Flutter + Riverpod + go_router + Drift/SQLCipher + dio; native Kotlin/NDK, Swift | - |
| API | Worker `la-ban-api` (Hono + zod), D1 `la-ban-prod` (SIN), Durable Objects, KV, R2, Analytics Engine, Cron | `compass-api.tsudev.com` |
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
| 10 | S2 | Định danh thiết bị + attestation + phiên | S1, A5 | ✅ 30/10 · máy thật M32 staging: mức `device` khi chưa lên Play; prod + staging e2e đạt |
| 11 | S3 | Ký request, pinning, Remote Config ký số | S2 | ✅ 30/10 · e2e staging + prod đạt; máy thật M32 30/10: xoay pin staging chỉ ISRG -> chỉ /v1/config tới Worker, về mặc định -> /v1/status 200, không build lại |
| 12 | S4 | Làm cứng app | S3 | ✅ 30/10 (1bd395f, v0.1.0-beta.7) · máy thật M32 release prod + staging: chỉ ADB_ENABLED / DEV_MODE / UNOFFICIAL_STORE mức info, điểm 0, không báo nhầm |
| 13 | S5 | Threat Engine + enforcement | S1 | ✅ 28/10 |
| 14 | S6 | Admin SOC 1 | S5 | ✅ 30/10 · e2e staging qua Access thật: realtime 587-722 ms, danh sách D1 45 ms |
| 15 | S7 | Admin SOC 2 (chia S7a / S7b / S7c) | S6 | ✅ 02/11 · S7a ✅ 30/10 (4ae38f9, PR #29) · S7b ✅ 30/10 (f1a6d3c, PR #32: rule + mô phỏng 7 ngày, can thiệp, four-eyes, Under Attack, Super Admin bật / tắt thuỷ vân; staging + prod) · S7c1 ✅ 31/10 (khiếu nại + Turnstile, xem / kiểm chuỗi audit) · S7c2 ✅ 02/11 (báo cáo CSV / PDF, Remote Config ký số four-eyes, kill-switch, Q47) |
| 16 | A6 | Waypoint, chia sẻ, deep link | A5, S3 | ✅ 30/10 (53e946b + cf74304, v0.1.0-beta.8) · máy thật M32: App Links `verified`, link /w/ mở thẳng app (cold 1,5 s) |
| 17 | A7 | Bản đồ offline + Camera AR (chia A7a / A7b / A7c) | A6 | ✅ 30/10 · A7a (a0e1d1b: tile VN trên R2 + Worker /ban-do) · A7b (d6de6a2: màn bản đồ + vùng offline) · A7c (62e4cab PR #33: Camera AR Camera2 nội bộ, v0.1.0-beta.9 đã phát hành) · máy thật M32 31/10: chế độ máy bay hiển thị bản đồ từ vùng offline, đổi Sáng / Tối không mạng |
| 18 | R1 | Landing hoàn chỉnh (kéo lên làm cùng R0 theo yêu cầu người dùng) | N2 | ✅ 28/10 |
| 19 | S8 | Bảo vệ edge web (CSP, header, WAF as code) | R1 | ✅ 29/10 (CSP `strict-dynamic` chặn từ 03/11, Trusted Types Report-Only; Access ở S6, Turnstile ở S7) |
| 20 | S9 | Lớp bảo vệ nội dung web + build sạch | S8 | ✅ 29/10 (bdbd740; CSV audit ở S6) |
| 21 | A8 | Cài đặt, quyền riêng tư, trợ năng, hiệu năng (chia A8a / A8b) | A7, S4 | ✅ 31/10 · A8a ✅ 31/10 (0191b2d PR #34: quyền riêng tư + đồng ý NĐ 13, Q43; máy thật M32 đạt; chưa phát hành APK - gộp A8b) · A8b ✅ 31/10 (trợ năng + Reduce motion, Q45; v0.1.0-beta.10) |
| 22 | S10 | Giám sát, log bất biến, backup, ứng phó sự cố (chia S10a / S10b) | S7 | ✅ 02/11 · S10a ✅ 02/11 (máy chủ: nhật ký bất biến R2 + mốc neo audit, sao lưu mã hoá + diễn tập, đột biến -> Telegram, security.txt, runbook IR, Q48) · S10b ✅ 02/11 (báo cáo sự cố tự xây, 0 đồng, đồng ý riêng, Q49) |
| 23 | R2 | Sẵn sàng store | A8, S4 | ⛔ R2a ✅ 31/10 (AAB + Data Safety + listing + ảnh store, Q46) · R2b: tài khoản Play cá nhân duyệt 04/11, app đã tạo, thiết lập 2/11; hướng dẫn từng trang `docs/store/huong-dan-play-console.md` (04/11, bản 2: E0-E2); **Thử nghiệm nội bộ chạy 04/11**: AAB beta.16 lên kênh, link `https://play.google.com/apps/internaltest/4700876326543944136`, M32 cài từ Play ✅; khoá ký Google Play tạo -> chấp nhận 2 chứng chỉ (Q63, beta.17) · ⛔ còn: liên kết Play Integrity (Được bảo vệ bằng Play) -> `PLAY_RECOGNIZED`, Phần A 11/11, thử kín 12 x 14 ngày |
| 24 | R3 | QA tổng + kiểm thử bảo mật (chia R3a / R3b) | R2, S9, S10 | ✅ 03/11 (0 Critical / High mở) · R3a ✅ 02/11 (gitleaks / osv-scanner / Semgrep vào cổng, ZAP + MobSF + SSL Labs A+, 0 High, minSdk 26, Q50) · R3b ✅ 02/11 (E2E + nâng cấp beta.7->13 + 5 kịch bản SEC-TEST trên M32, sửa 2 lỗi, Q51) · R3c ✅ 03/11 (#48-#50, Q52: DO -> D1 nonce + giới hạn; staging p95 < 300 ms; D1 prod chuyển ICN -> SIN (Q53): prod p50 8-49 ms, p95 < 250 ms mẫu nhỏ - đo lại 24 h) |
| 25 | R4 | Phát hành v1.0.0 + OTA | R3 | ⬜ (tài khoản cá nhân: cần thử kín >= 12 người x 14 ngày trước production) |
| 26 | M1 | Gói Pro trong app + quảng cáo (chia M1a quyền lợi + Play Billing / M1b quảng cáo), v1.1.0 sau Release Gate | R4 | 🟨 M1a bước 3 (máy chủ) ✅ 03/11 (b145e92, PR #66) · bước 2 (app) ✅ 04/11 (`packages/quyen_loi` + Paywall, Q61; prod chưa mở bán) · bước 4 phần SOC + 5 (trang Quyền lợi SOC, Q64) ✅ 04/11 · còn bước 1 (người dùng tạo sản phẩm + RTDN_EMAIL), cổng máy thật license tester |
| 27 | R0 | Bản APK thử: khoá ký, script phát hành GitHub Release + R2, trang tải | A5 | ✅ 28/10 |
| 28 | I1 | iOS (đầu 2027): build, App Attest, Privacy Manifest, TestFlight, App Store | R4, máy Mac | ⬜ |
| 29 | M2 | App song song "La bàn Pro" trả phí một lần, không quảng cáo (Q56) | R2b, M1a bước 3 (bảng `quyen_loi`) | 🟨 M2a ✅ 05/11 (vỏ app `app_shell` + `app_pro`, bản quyền GET_LICENSED, Worker + SOC theo gói, Q65) · M2b bước 3 code ✅ 05/11 (build Kotlin ✅ 06/11, chưa thử máy thật) · M2b bước 4 listing / Data Safety / ảnh store ✅ 06/11 · còn thử máy thật + Play Console Phần F (người dùng) · chạy CÙNG R4 (người dùng chốt 03/11: dùng chung cửa sổ thử kín 14 ngày; M1a bước 3 phần máy chủ làm trước) · logo Pro ✅ 03/11 |
| 30 | A9 | Thiết bị thiếu phần cứng + làm mới giao diện web / nút app + chống nhấp nháy (chia A9a / A9b / A9c) - PHIÊN SONG SONG `../app-la-ban-a9` | A8 | ✅ 04/11 · A9c #70 (3f7c3a6) · A9a #71 (b970562) · A9b #72 (e5bd627) · web đã deploy · APK gộp + thử M32 staging ở phiên chính |
| 31 | S11 | Chặn chế độ Nhà phát triển (app) + khiên web mạnh (Q57, Q58) | S4, S9, M1a bước 3 (cùng Worker) | 🟨 03/11 (adf3102 PR #67, v0.1.0-beta.15 PR #68): Worker staging + prod, landing + admin, APK đã phát hành · M32 04/11: prod bật ADB -> màn chặn ✅, staging không chặn ✅ · ⛔ còn tắt -> dùng lại <= 5 s + 403 ở SOC (người dùng) · kill-switch ký được từ Q62 |

Có thể giao agent thứ hai song song: S1 với A2-A3 · A5 với A4 · S5 với S4 · A6 với S6-S7 · R1 với A7 · A8 với S8-S9.

**Việc người dùng:** trước N2 tạo API token Cloudflare (zone tsudev.com: DNS, WAF, Lists; Workers, Pages, D1, R2) lưu ở
`~/.config/la-ban/cf.env` · trước A2 bật Wireless debugging trên 1 điện thoại Android · trước S2 Google Cloud project + Play
Integrity API + service account (Apple Team ID dời sang I1) · trước S6 bật Cloudflare Zero Trust · trước R2 tài khoản Play Console (hoãn ~7 ngày từ 29/10 do lỗi thanh toán - dự kiến từ 05/11/2026), duyệt Privacy
Policy · trước I1 (đầu 2027) máy Mac hoặc Codemagic + Apple Developer · trước R4 chốt đơn vị pentest, bấm phát hành · trước M1 / M2: hồ sơ thanh toán Play (merchant) + khai báo
nhà giao dịch (trader - địa chỉ / điện thoại có thể hiện công khai trên Play), giá đã chốt 03/11 (Q55 / Q56), Pub/Sub
cho RTDN trong dự án Cloud 930761930572, cấp service account quyền "Xem dữ liệu tài chính / quản lý đơn hàng" trong Play
Console · trước M1b tài khoản AdMob (RevenueCat KHÔNG còn cần - Q55).

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
- Kết quả (29/10): Worker - migration 0004 (expand: `sessions.chuoi / thay_boi / xoay_luc / ly_do_thu_hoi`,
  `devices.attested_at / attest_signals`); route `/v1/device/challenge|register|attest|me`, `/v1/session/refresh`
  (`src/dinh-danh.ts`); thách thức dùng một lần ở DO `KhoNonce` (`/cap`, `/dung`); chữ ký thiết bị P-256 DER kiểm bằng
  WebCrypto; Play Integrity giải mã bằng service account (`attest/google.ts`, token Google đệm theo isolate) + đánh giá
  thuần (`thuan/play-integrity.ts`: requestHash = base64url(SHA-256(chuỗi ký)) chống phát lại, gói + chứng chỉ upload,
  strong / device / basic / failed / unverified); JWT ES256 15 phút có `cnf.jkt` (khoá `KHOA_PHIEN`, xoay bằng mảng JWK);
  refresh 30 ngày xoay vòng, ân hạn 30 s, dùng lại -> thu hồi cả chuỗi + `TOKEN_REUSE` (điểm 40); middleware `xacThuc`
  (đọc D1 mỗi yêu cầu - thu hồi / cấm có hiệu lực ngay) qua cờ `xacThuc` của BoTuyen. App - plugin nội bộ
  `security_sdk` (Keystore EC StrongBox -> TEE, Play Integrity Standard 1.6.0 với project number 930761930572),
  `DichVuDinhDanh` (Installation ID UUID v4 ở `dinh_danh.json`, đăng ký / làm mới / xác minh lại, chạy nền 3 s sau khung
  đầu, offline vẫn chạy), `network.ApiClientIo` (dart:io, không thêm SDK). Test: Worker 17 thuần + 13 tích hợp
  Miniflare (Google giả), Dart 13 + 4 + 2.
- Phát sinh (từ S2) -> S3: ký MỌI request bằng khoá thiết bị, server kiểm khớp `cnf.jkt` của JWT; chuyển `ApiClientIo`
  sang dio + interceptor (hoặc giữ dart:io) + SPKI pinning + `network_security_config` release chặt; kiểm chuỗi chứng
  thực khoá Keystore (key attestation) ở server để xác nhận khoá nằm trong phần cứng (hiện app chỉ báo `mucBaoMat`).
  -> R2: sau khi liên kết Play Console (Q35), bản tải từ Play nhận `PLAY_RECOGNIZED`. -> S6: SOC hiển thị
  `attestation_level` + `attest_signals`.
- Nghiệm thu (30/10): `KHOA_PHIEN` đã đặt staging + prod (người dùng); `tools/thu/dinh-danh-e2e.mjs` đạt cả hai môi
  trường; Galaxy M32 (Android 13) cài APK staging qua USB -> Keystore EC + Play Integrity Standard -> Google giải mã ->
  `device` (`UNRECOGNIZED_VERSION`, `MEETS_DEVICE_INTEGRITY`, khoá Keystore TEE). Lần mở đầu trượt do Wi-Fi đang chuyển
  -> thêm thử lại 30 s / 2 phút / 10 phút + chạy lại khi app về foreground (`ChayDinhDanh`). "App is not found" (chỉ token
  rác) đổi từ `unverified` sang `failed`. Phát hành v0.1.0-beta.5 (APK prod có S2).

### S3 - Bảo vệ kênh truyền
- Đọc thêm: SEC-NET.
- Làm: chữ ký request bằng khóa thiết bị (chuỗi chuẩn Spec §7.5); dio interceptor; SPKI pinning >= 2 pin + xoay pin qua config
  ký số; `network_security_config` + ATS chặt; `/v1/config` (Ed25519, KV) + `/v1/status`; force/soft update.
- Cổng: request sai chữ ký / replay / hết hạn bị từ chối (test); xoay pin thử trên staging không cần bản mới.
- Kết quả (30/10, nhánh `phase/s3-kenh-truyen`): Worker - middleware `xacThuc` (mọi route có phiên) kiểm thêm chữ ký request
  bằng khoá thiết bị: chuỗi chuẩn `METHOD\nPATH\nSORTED_QUERY\nSHA256_HEX(BODY)\nTS\nNONCE` (`thuan/ky-yeu-cau.ts`, query
  RFC 3986, vector chung với Dart), header `x-timestamp` (ms, lệch <= 60 s -> 401 `lech-gio` + `x-server-time` để app tự
  hiệu chỉnh), `x-nonce` (DO KhoNonce 5 phút, kiểm SAU chữ ký), `x-signature`, `x-device-id` tuỳ chọn; khoá đang lưu phải khớp
  `cnf.jkt`; sai chữ ký -> `SIGNATURE_MISMATCH` (<= 1/phút/thiết bị). Route mới: `GET /v1/config` (gói Ed25519 kid `app-1`
  nguyên văn từ KV `app-cau-hinh`), `GET /v1/status` (trạng thái kể cả bị cấm + mã `REF-xxxxx-xxxxx` + bản APK mới từ R2
  `android/latest.json`), `POST /v1/events` (lô <= 50, loại chỉ server sinh -> 422, chống trùng event_id, đồng bộ List khi
  cần). App - `network`: ghim CA ở mức NEO TIN CẬY (dart:io chỉ lộ chứng chỉ lá; Cloudflare đổi khoá lá mỗi lần gia hạn) - bộ
  5 CA gốc GTS R1/R3/R4 + ISRG X1/X2 sinh bởi `tools/build/goc-tin-cay.mjs` (cổng `--check`, kể cả pin-set Android), Ed25519
  kiểm thuần Dart (RFC 8032, không thêm SDK), `DichVuCauHinh` (tải bằng kho CA hệ thống vì gói tự ký, chống gói cũ hơn, hết
  hạn -> mặc định, >= 2 CA dùng được), `quyetDinhCapNhat`. `security_sdk`: `goiKy` (ký + thử lại 1 lần khi lệch giờ / token),
  `tinhTrang`, `guiSuKien`, `moTrangLaBan` (Kotlin, chỉ https://compass.tsudev.com/). App: `KenhApp` (client ghim cho định
  danh, đổi ghim khi Remote Config đổi), kill-switch nối `tinhCo(tatTuXa:)`, màn bắt buộc cập nhật + băng gợi ý (vi/en,
  golden). Android `xml/mang.xml`: cấm cleartext, chỉ CA hệ thống, pin-set compass-api (hết hạn 2027-12-31); dev giữ HTTP
  10.0.2.2/localhost; iOS ATS tường minh. Công cụ: `ky-cau-hinh.mjs ky-app|dua-len-app` (khoá `~/.config/la-ban/cau-hinh/app-1.pem`
  NGOÀI repo). Test: Worker +20 (18 S3), network 33, security_sdk +8, app +8; `tools/thu/dinh-danh-e2e.mjs` thêm bước ký.
  Gate xoay pin: KV staging chỉ ISRG -> client ghim `LoiMang(tls)`; xoay về mặc định -> 200, không build lại. Bản beta.5
  ngoài thực tế chỉ dùng challenge/register/refresh nên không bị vỡ khi bắt buộc ký.
- Phát sinh (từ S3): thử máy thật (Galaxy M32) cài v0.1.0-beta.6: `wrangler tail --env staging` thấy `/v1/config` +
  `/v1/status` 200 sau mở app; xoay pin bằng `dua-len-app --pin` rồi mở lại app. Key attestation (chuỗi chứng thực Keystore)
  ở server chưa làm -> S4 hoặc S10. Gia hạn `pin-set expiration` (mang.xml) trước R2. -> S4: dùng `guiSuKien` cho tín hiệu
  RASP, `tinhTrangProvider` cho màn khoá + REF. -> S6: SOC tra thiết bị theo hậu tố REF (10 ký tự cuối id).

### S4 - Làm cứng app
- Đọc thêm: SEC-APP.
- Làm: freeRASP + kiểm tra native bổ sung (bộ tín hiệu theo Spec §7.3b, chỉ báo về server); build `--obfuscate
  --split-debug-info` + R8 full + upload symbol; chuỗi cấu hình mã hóa lúc build; FLAG_SECURE / che app switcher ở màn nhạy cảm;
  phản ứng theo Risk Level (Spec §7.3 bảng) + màn khóa có mã REF; không chạy kiểm tra ở bản debug nội bộ.
- Phát sinh (từ A5, SEC-APP-STORAGE): logger chung (`core`) che token / tọa độ chính xác ở release; báo `LyDoAnToan` +
  `KetQuaMoCsdl.loi` / `lamMoiDoMatKhoa` về server (đã ẩn PII) khi có kênh ký request; nối kill-switch Remote Config vào
  `tinhCo(tatTuXa:)` (`coTinhNangProvider` ở `app/lib/src/luu_tru.dart`).
- Cổng: bản release trên máy thật sạch không báo nhầm; bản debug/giả lập sinh đúng sự kiện.
- Kết quả (30/10, PR #21, main `1bd395f`): `security_sdk` - freeRASP 8.2 (Q13, watcher security@tsudev.com, isProd chỉ
  release, chứng chỉ mong đợi = khoá upload) + thư viện C++ `native/android/cpp/la_ban_kt` (su / Magisk / Frida / Xposed /
  TracerPid / giả lập; chuỗi XOR lúc biên dịch, -fvisibility=hidden, LTO, strip) qua `MoiTruong.kt`; domain `rasp.dart` gộp
  tín hiệu -> sự kiện, `DichVuRasp` gửi qua `guiSuKien` (kênh ký S3), lưu hàng chờ offline `rasp.json`; báo `LyDoAnToan` / lỗi CSDL / mất khoá (phát sinh A5). Lịch kiểm ngẫu nhiên
  (2-8 s sau khung đầu, 15-45 phút, khi về foreground >= 5 phút). App - `KhungRuiRo`: mức từ SERVER (`tinhTrangProvider`), HIGH
  băng hạn chế, CRITICAL màn khoá + REF + khiếu nại + FLAG_SECURE, gửi nốt hàng chờ rồi huỷ phiên; MEDIUM+ tắt cờ nhạy cảm;
  khoá đã lưu hiện cả khi offline. Debug: không gửi server. `core` - `NhatKy` che token / toạ độ ở release. Worker -
  `diemTheoLo`: mỗi loại tín hiệu app chỉ tính điểm 1 lần / thiết bị / cửa sổ (lặp lịch kiểm không leo thang giả).
  Release: R8 + shrinkResources + không debuggable; loại ABI thừa của plugin theo `target-platform` (Flutter ghi đè
  abiFilters); `tools/build/kiem-apk.mjs` (không debuggable, exported chỉ MainActivity / quyền DUMP, có libla_ban_kt.so
  không lộ chuỗi) chạy trong `phat-hanh-apk.sh`. Landing Quyền riêng tư khai freeRASP (Talsec). Worker staging + prod,
  e2e đạt. Kích thước: freeRASP `libts.so` ~13 MB nén / ABI -> arm64 12,6 -> 28,3 MB (vượt ngân sách 25 MB).
- Máy thật (30/10, Galaxy M32 Android 13, USB debugging bật, cài ngoài Play): APK release prod beta.7 + staging - kênh ký
  hoạt động (config / refresh / status 200, events 202), server nhận đúng 3 tín hiệu info `ADB_ENABLED`, `DEV_MODE`,
  `UNOFFICIAL_STORE` (risk_delta 0, `clean`), không root / hook / đóng gói lại; mở lại nhiều lần không sinh sự kiện trùng.
  ~78 FPS. Bản debug không gửi server (theo thiết kế) - nhánh debug chỉ có unit test; giả lập không chạy được trên WSL.
  GitGuardian báo JWT ở `nhat_ky_test.dart` (PR #21) - token giả, không cần xoay; PR #22 ghép token lúc chạy + cổng chặn
  JWT nguyên văn (gitleaks chưa cài trên máy nên trước đó bị bỏ qua).
- Phát sinh (từ S4): `devices.app_version` không cập nhật khi làm mới phiên (vẫn beta.5) và `_app` trong tín hiệu mất hậu
  tố `-beta.N` -> S6 (SOC hiển thị) / A8; cài gitleaks vào ~/tools cho cổng -> S10; kích
  thước APK vượt ngân sách do freeRASP -> R2 cân nhắc bỏ bản universal (Play dùng AAB tách ABI); freeRASP áp KGP - theo dõi
  bản hỗ trợ Built-in Kotlin trước khi Flutter bỏ KGP; key attestation Keystore ở server -> S10.

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
- Kết quả (30/10, QUYET_DINH Q37, runbook `docs/runbook/admin-soc.md`): Access (IdP One-time PIN email, app `la-ban-admin`
  phủ compass-admin + `*.la-ban-admin.pages.dev`, phiên 8 giờ, cấu hình dạng mã `tools/cloudflare/access.mjs`, email ngoài
  repo). Worker `/admin/v1` (`src/admin/`): JWT Access kiểm lại (iss / aud / JWKS xoay khoá) -> vai trò D1 -> phiên passkey
  WebAuthn tự kiểm (`thuan/webauthn.ts` + `thuan/cbor.ts`, ES256 / EdDSA / RS256, bắt buộc UV, bộ đếm chống sao chép) ->
  cookie `__Host-soc` (nhàn rỗi 15 phút, request nền không gia hạn, tuyệt đối 8 giờ, step-up 5 phút); chống CSRF; Viewer
  nhận IP /24 và không xem chi tiết; audit chuỗi băm cho đăng nhập / passkey / xem chi tiết / quản trị viên. Migration 0005.
  DO `PhongSoc` WebSocket hibernation, Threat Engine phát sau mỗi lô. Pages `_worker` (esbuild) kiểm JWT trước khi trả
  SPA, `/api/*` -> service binding (prod `la-ban-api`, preview `la-ban-api-staging`), CSP 'self' không unsafe-*. SPA: tổng
  quan realtime, danh sách thiết bị ảo hoá + lọc (ID / IP / dải / ASN / phiên bản / loại sự kiện / trạng thái) + cursor,
  chi tiết (timeline, IP/ASN, liên quan, chặn, khiếu nại), quản trị viên (Super Admin). 33 test mới (thuần + Miniflare +
  _worker); e2e `tools/thu/soc-e2e.mjs` trên staging thật (service token chỉ staging nhận).
- Phát sinh (từ S6) -> S7: xoá / đổi tên passkey trên giao diện (hiện qua wrangler d1); bảng alerts trong Tổng quan chỉ
  xem - trạng thái / phân công ở Alert Center; heatmap tỉnh (cần geo IP cấp tỉnh). -> người dùng: thêm IdP Google (OAuth
  client) khi muốn bỏ OTP email.

### S7 - Admin SOC 2
- Làm: trung tâm cảnh báo (dedup, trạng thái, Telegram); rule UI + mô phỏng 7 ngày; can thiệp (Spec §8.2-5) với lý do bắt
  buộc; four-eyes cho hành động hàng loạt; khiếu nại; báo cáo CSV/PDF; xem + kiểm chuỗi audit; quản lý Remote Config / phiên
  bản tối thiểu / pin dự phòng (ký số, cần duyệt).
- Cổng: kill-switch <= 5 s; audit sửa tay bị phát hiện; four-eyes không tự duyệt được.
- Chia phiên (30/10, phase quá lớn cho một phiên): **S7a** khung SOC mới + thuỷ vân dễ đọc + trung tâm cảnh báo (trạng thái,
  phân công, kết luận, ghi chú, hàng loạt, Telegram) + tự quản passkey. **S7b** rule UI (bật active chỉ khi
  `coTheBatThucThi`) + mô phỏng 7 ngày trên `rule_hits` + sửa `threat_config` (phiên bản + audit) + can thiệp Spec §8.2-5
  (lý do bắt buộc + step-up: chặn / gỡ chặn thiết bị, IP, dải; thu hồi phiên) + four-eyes (`approved_by <> created_by`
  đã có CHECK D1) cho hàng loạt / duyệt đề xuất chặn dải `pending_approval` + bật Under Attack. **S7c** khiếu nại (form landing
  + Turnstile + `siteverify` + duyệt ở SOC) + xem / kiểm chuỗi audit (phát hiện sửa tay) + báo cáo CSV / PDF + Remote Config /
  phiên bản tối thiểu / pin dự phòng ký số có duyệt + đo kill-switch <= 5 s.
- Kết quả S7a (30/10): migration 0006 (expand: cột `assignee` / `resolution` / `updated_*` / `notified_at` cho `alerts`,
  chỉ mục gộp open + ack, bảng `alert_notes`). Thuần `thuan/canh-bao.ts` (lọc -> SQL keyset, vòng đời + thao tác hàng loạt,
  che khoá nhóm theo vai trò - sửa lỗi S6: `ip:<ip>` không bị che cho viewer, nội dung Telegram không PII). Route
  `admin/canh-bao.ts` (`/canh-bao` lọc + đếm, `/:id`, `/thao-tac`, `/nguoi-xu-ly`, `/thu-telegram`), Threat Engine gộp
  bằng `ON CONFLICT ... WHERE status IN ('open','ack') RETURNING` + `threat/telegram.ts` (giành quyền gửi bằng
  `notified_at`). Passkey: `/passkey` xem, `/passkey/doi-ten`, `/passkey/xoa` (step-up, không xoá cái cuối). Quyền mới
  `canh-bao:xem` (viewer) / `canh-bao:xu-ly` (analyst). SPA: bố cục thanh bên + thanh trên, bảng lệnh Ctrl K, phím tắt,
  toast, `<dialog>`, mật độ, trang Cảnh báo (bảng chọn nhiều + ngăn chi tiết), trang Tài khoản; thuỷ vân canvas + mã dấu
  vết (QUYET_DINH Q39, runbook admin-soc). Test mới: 9 thuần Worker + 3 tích hợp Miniflare + 11 SPA.
- Phát hành S7a (30/10): migration 0006 staging + prod, Worker build 4ae38f9 (staging + prod), Pages admin preview
  `staging` + main (bundle mới đang phục vụ). e2e staging qua Access thật (`tools/thu/soc-e2e.mjs`, thêm `/canh-bao` +
  `/passkey`): tất cả đạt; realtime khi ấm 734-1470 ms (< 1,5 s), 2 lần đầu ngay sau deploy (lạnh) 3,5 s / 1,8 s.
- Phát sinh (từ S7a) -> S10: đo p95 realtime SOC theo thời gian (S6 đo 587-722 ms; S7a khi ấm tới 1,47 s - sát ngân
  sách) - cân nhắc phát tin SOC trước khi chạy rule (`phatSoc` sớm, kích hoạt rule gửi tin thứ hai).
- Kết quả S7b (30/10, QUYET_DINH Q41): migration 0007 (expand: `rule_versions` có dữ liệu bản đầu, `approval_requests`
  four-eyes CHECK `decided_by <> created_by`, `soc_settings`, chỉ mục enforcement chờ duyệt). Thuần `thuan/mo-phong.ts`
  (chạy lại rule ỨNG VIÊN trên `security_events` 7 ngày: cửa sổ trượt + không kích hoạt lặp như engine, theo ngày giờ VN,
  trần 50.000 sự kiện; đổi logic -> shadow), `thuan/can-thiep.ts` (chuẩn hoá đích, dải tối thiểu /16 - /32, TTL cố định
  hoặc leo thang, loại duyệt ngay / đề xuất / yêu cầu), cài đặt SOC trong `thuan/soc.ts`. Route `admin/luat.ts`,
  `admin/can-thiep.ts`, `admin/cai-dat.ts`; ghi có điều kiện phiên bản (409). 6 quyền mới. SPA: Can thiệp (`g x`), Rule
  (`g l`, ngăn sửa + mô phỏng + lịch sử), Cấu hình điểm + Under Attack (`g n`), Cài đặt hệ thống (`g s`, Super Admin:
  thuỷ vân bật / tắt, độ đậm tối thiểu, ép che khi rời), nút chặn / thu hồi phiên ở chi tiết thiết bị. Test mới: 11 thuần +
  5 tích hợp Miniflare Worker, 5 SPA. Phát hành: D1 0007 staging + prod, Worker f1a6d3c staging + prod, Pages admin
  `staging` + main; e2e staging (thêm kiểm S7b chỉ đọc) đạt mọi mục S7b.
- Phát sinh (từ S7b) -> S10 (ƯU TIÊN): realtime SOC staging dao động 663-1829 ms (3/5 lần vượt 1,5 s) - không do S7b
  (đường Threat Engine -> DO không đổi); xem gợi ý phát tin SOC trước khi chạy rule ở mục S7a.
- Phát sinh (từ S7a): người dùng tạo bot Telegram + đặt 2 secret (runbook admin-soc) - chưa có thì Worker bỏ qua im lặng;
  contract chỉ mục `alerts_open` cũ ở bản migration sau S7c.
- Chia S7c (31/10, QUYET_DINH Q44): **S7c1** khiếu nại (form landing + Turnstile + `siteverify` + duyệt ở SOC) + xem / kiểm
  chuỗi audit. **S7c2** báo cáo CSV / PDF + Remote Config / phiên bản tối thiểu / pin dự phòng ký số có duyệt (four-eyes,
  thêm kind mới cho `approval_requests` = bảng mới hoặc tạo lại theo expand / contract) + đo kill-switch <= 5 s.
- Kết quả S7c1 (31/10, QUYET_DINH Q44): migration 0008 (expand: `appeals` thêm `contact` / `lang` / `ip` / `reviewed_at`
  / `decision_note`, UNIQUE một khiếu nại đang mở / thiết bị). Thuần `thuan/khieu-nai.ts` (REF -> hậu tố id, đọc kết quả
  siteverify, lọc khiếu nại / audit). Route công khai `POST /v1/khieu-nai` (CORS landing, 6 / giờ / IP), admin
  `/khieu-nai` + `/khieu-nai/quyet` (chấp nhận = gỡ chặn thiết bị + điểm 0), `/audit` + `/audit/kiem` (kiểm theo lô 2000).
  Cron dọn xoá email + IP khiếu nại 90 ngày sau quyết định. SPA: trang Khiếu nại (`g i`, huy hiệu số đang mở), Nhật ký
  kiểm toán (`g a`, kiểm chuỗi, xem trước / sau). Landing: form + Turnstile (chỉ hiện khi có site key; CSP chỉ nới cho 2
  trang khiếu nại ở edge), trang Quyền riêng tư cập nhật theo A8a (đồng ý, chế độ ngoại tuyến, Cài đặt > Quyền riêng tư)
  + Turnstile + dữ liệu form khiếu nại. Test mới: 6 thuần + 3 tích hợp Miniflare Worker, 2 SPA, 4 landing.
- Phát sinh (từ S7c1) -> S10: mốc neo chuỗi audit ngoài D1 (hash cuối + số dòng mỗi ngày vào R2 log bất biến) để phát
  hiện xoá dòng CUỐI chuỗi; cron kiểm chuỗi hằng ngày + cảnh báo. -> người dùng: tạo widget Turnstile (token cf.env chỉ
  có quyền đọc) - runbook admin-soc mục S7c1. -> A (app): màn khoá có nút mở `compass.tsudev.com/khieu-nai/?ref=<REF>`
  (trang tự điền mã).
- Kết quả S7c2 (02/11, QUYET_DINH Q47): migration 0009 (expand: `config_requests` four-eyes CHECK `decided_by <>
  created_by`, `config_versions`; contract: bỏ chỉ mục `alerts_open` cũ). Thuần `thuan/cau-hinh-tu-xa.ts` (đề xuất app /
  web, pin chỉ trong 5 CA đóng gói, giữ CA thêm ngoại tuyến, mã tối thiểu <= bản APK đã phát hành, `phatHanh` tăng, ký /
  kiểm Ed25519 WebCrypto, khoá secret phải khớp khoá công khai app-1 / web-1) + `thuan/bao-cao.ts` (CSV BOM + CRLF, chặn
  công thức, che IP / email liên hệ theo vai trò, khoảng <= 92 ngày giờ VN). Route `admin/cau-hinh-tu-xa.ts`
  (xem / đề xuất / duyệt -> ký + KV + lịch sử + audit / huỷ; gói đổi giữa chừng 409) + `admin/bao-cao.ts` (`/bao-cao/tong-hop`,
  `/bao-cao/xuat` passkey + audit). 5 quyền mới (21). Kill-switch: đệm danh sách chặn IP / dải / ASN 15 s -> 3 s (thiết bị
  đã đọc D1 mỗi yêu cầu). SPA: trang Báo cáo (`g b`, in / lưu PDF bằng trình duyệt) + Cấu hình từ xa (`g r`, bảng thay đổi,
  duyệt / bác / huỷ, lịch sử). `soc-e2e.mjs` thêm kiểm S7c2 + `--kill-switch`. Test mới: 11 thuần + 2 tích hợp Worker, 3 SPA.

### A6 - Waypoint + chia sẻ
- Làm: CRUD waypoint (ghi chú, ảnh), điều hướng (Vincenty), GPX/KML import/export, link `compass.tsudev.com/w/<token>` hết hạn,
  QR; App Links + Universal Links (assetlinks.json, AASA trên landing).
- Cổng: round-trip GPX không mất dữ liệu; deep link mở đúng app trên máy thật.
- Phát sinh (từ A5): bảng `diem` (schema v1) đã có trong `CsdlLaBan` (`packages/storage`); mở rộng cột / bảng = migration v2
  CHỈ THÊM: tăng `schemaVersion` (số literal), thêm bước vào `buocMigration`, `dart run drift_dev make-migrations` + `schema
  generate ... test/drift/csdl/generated/`, chạy `build_runner build`; test ma trận `test/drift` tự phủ v1 -> v2. Cần
  `csdlProvider` (app đã có `khoLuuTruProvider`, `KhoLuuTru.csdl` null ở chế độ an toàn) + màn xuất điểm ở chế độ an toàn
  (Spec §10.4 "cho phép xuất dữ liệu waypoint") - đọc thô cột v1 bằng `sqlite3` khi Drift không mở được.
- Kết quả (30/10, phiên song song agent-laban-app, 53e946b PR #26 + cf74304 PR #27): CSDL v2 CHỈ THÊM bảng `anh_diem` + đọc
  thô điểm ở chế độ an toàn (xuất điểm khi Drift không mở); waypoint CRUD + ảnh (plugin nội bộ `DiemPlugin` Kotlin, không SDK
  mới); dẫn đường Vincenty; GPX/KML nhập/xuất round-trip (`xml_nho` tự viết); link `compass.tsudev.com/w/<token>` tự chứa (tọa
  độ + hạn + CRC, không cần server) + QR tự sinh (`ma_qr.dart`); App Links autoVerify + `assetlinks.json` prod/stg/dev trên
  landing, trang `/w` fallback xem điểm. v0.1.0-beta.8 (arm64 28,6 MB / armv7 25,7 MB). `phat-hanh-apk.sh` chấp nhận HEAD tách
  rời trùng origin/main (worktree).
- Nghiệm thu máy thật (30/10, M32 Android 13): `pm get-app-links` -> compass.tsudev.com `verified`; link `/w/<token>` từ
  trình duyệt / Zalo mở THẲNG app (cold 1,5 s, không hộp chọn), "Lưu vào Điểm" tạo điểm mới -> cổng A6 đạt. AASA iOS -> I1.

### A7 - Bản đồ + AR
- Làm: MapLibre + PMTiles VN trên R2 (xác minh hỗ trợ PMTiles trong bản plugin; không được thì MBTiles); tải gói offline có
  quản lý dung lượng; lớp la bàn + waypoint; Camera AR bằng camera + fusion (không ARCore/ARKit để giữ dung lượng).
- Cổng: dùng được ở chế độ máy bay; app vẫn < 25 MB (tile tải riêng).
- Chia phiên (30/10, theo phiếu phiên song song HGLB-1030-154547): **A7a** dữ liệu bản đồ (tile + style + glyph, Worker
  `/ban-do/*`) · **A7b** màn bản đồ MapLibre (`maplibre_gl`, Q14) + lớp điểm + vị trí / hướng + tải vùng offline (z <= 14,
  danh sách / xoá / dung lượng) + ghi công OSM / Noto ở màn Giấy phép · **A7c** Camera AR (camera + fusion, không ARCore).
- Kết quả A7a (30/10, a0e1d1b PR #28, QUYET_DINH Q38): tile vector VN (Protomaps 20261029, OSM ODbL) đất liền + Hoàng Sa +
  Trường Sa trích bằng `tools/build/tile-vn.mjs`; R2 `la-ban-cdn/ban-do/20261029/` (vn-0-13 255 MB + vn-14 225 MB) + glyph
  Noto Sans; Worker `/ban-do/{z}/{x}/{y}.mvt` (cache edge 1 năm), `kieu/<sang|toi>-<vi|en>.json`, `phong/<font>/<dai>.pbf`,
  rate limit `RL_BAN_DO` 3000/phút/IP. Bẫy: deploy Worker bằng `npm run deploy` / `deploy:staging` (gắn BAN_BUILD).
- Phát sinh (từ A7a) -> A7b / R2: APK đã 28,6 MB (> 25 MB do freeRASP), đo thêm MapLibre rồi ghi lại ở R2.
- Kết quả A7b (30/10, d6de6a2 PR #31, QUYET_DINH Q40): tab Bản đồ `maplibre_gl` 0.27.1 + style Worker (sáng / tối x vi / en,
  dev dùng staging); lớp điểm (chạm mở chi tiết), chấm vị trí + vòng sai số theo mét từ location_feature (không GPS thứ hai),
  xoay theo bắc thực (bỏ lệch < 3°); màn Vùng offline: "Tổng quan Việt Nam" z0-8 + vùng đang xem tới z14, trần 6000 tile,
  lưu kèm 3 style còn lại, dung lượng / xoá; ghi công OSM / Protomaps / Noto ở Giấy phép. Build Android cần JDK 21
  (`~/tools/java/jdk21`, phat-hanh-apk.sh đã đổi). APK arm64 release 33,0 MB (+4,4 MB `libmaplibre.so`), kiem-apk đạt.
- Phát sinh A7b: (1) nghiệm thu chế độ máy bay trên máy thật CHƯA (không có thiết bị adb 30/10) - cài bản kế, tải vùng,
  bật máy bay, mở tab Bản đồ + đổi sáng / tối; (2) chưa phát hành APK mới - gộp với A7c; (3) kích thước -> R2.
- Kết quả A7c (30/10, 62e4cab PR #33, QUYET_DINH Q42): Camera AR bằng plugin Camera2 nội bộ (`packages/ar_feature`,
  không ARCore / gói `camera`), chiếu lỗ kim từ tư thế cảm biến + WMM: đường chân trời, phương vị, điểm đã lưu; quyền CAMERA
  just-in-time. Máy thật M32: ảnh đúng chiều / tỉ lệ, lớp phủ khớp kim; APK arm64 +28 KB. Phát hành v0.1.0-beta.9
  (arm64 33,0 MB / armv7 29,6 MB, GitHub Release + CDN + /tai-ve). Còn treo: nghiệm thu chế độ máy bay (A7b) trên máy thật.

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
  >= 3 lần/giờ -> chặn IP). Zone as code tổng quát: `quyTac` (rule theo phase, nhận diện bằng description), gồm Config Rule
  `disable_rum` cho compass-* (Web Analytics tự chèn cả zone - bẫy WEB ANALYTICS TU CHEN; luật Exclude của RUM cần gói Pro); WAF custom MỘT rule "la-ban: chặn edge" (`$la_ban_chan_ip` cho
  mọi host compass-* + admin ngoài VN) - Free zone dùng chung chỉ còn 2/5 custom rule, 0/1 rate-limit rule (bẫy WAF FREE ZONE
  DUNG CHUNG). Managed: "Cloudflare Managed Free Ruleset" mặc định của zone (OWASP cần Pro). Observatory A+ (145) trước và sau.
- Phát sinh (từ S8) -> 05/11/2026: đọc báo cáo CSP 7 ngày, chuyển `strict-dynamic` sang header chặn (runbook csp-bao-cao).
  -> S6: Access chặn admin (cần Zero Trust) + CSP nonce cho admin (dùng lại `web/landing/edge` qua gói chung khi admin có
  HTML thật). -> S7: Turnstile (widget + `siteverify` ở Worker) cùng form khiếu nại. -> S10: bảng CSP / honeypot trong SOC.
- Kết quả phát sinh CSP (03/11, người dùng cho bật sớm, #56 + #58): tắt Email Obfuscation (Config Rule zone.json);
  header CHẶN landing `script-src 'self' 'strict-dynamic' 'nonce-X'`, Trusted Types giữ Report-Only (script Cloudflare);
  bỏ `interest-cohort` khỏi Permissions-Policy. Prod headless 10 trang 0 vi phạm chặn (runbook csp-bao-cao).

### S9 - Bảo vệ nội dung web + build sạch
- Đọc thêm: SEC-WEB-SHIELD, SEC-WEB-BUILD.
- Làm: gói `web/shield` áp cho landing + admin, bật/tắt + mức độ qua config ký số; watermark động ở admin; ảnh qua URL ký; build
  xoá 100% comment, console, sourcemap, LICENSE.txt; làm rối mã module nhạy cảm (tương thích CSP); script `ve-sinh-ban-build`.
- Cổng: script vệ sinh xanh; không ảnh hưởng trợ năng (ô nhập vẫn chọn/dán được); tín hiệu về Threat Engine.
- Kết quả (29/10, PR #17, main bdbd740): gói `web/shield` -> `/js/khien.js` (IIFE 5,4 KB, terser đổi tên thuộc tính nội
  bộ, không eval / innerHTML / style nội tuyến) nạp ở landing (`Trang.astro`) + admin (`index.html`), nonce tự gắn. Mức
  `chat` mặc định; gói ký Ed25519 (khoá bí mật `~/.config/la-ban/cau-hinh/web-1.pem`, công khai ở `khoa.ts`) ở KV
  `web-khien` staging + prod, hết hạn 27/01/2027, Chromium kiểm chữ ký OK. Dò DevTools: ước lượng zoom từ chiều ngang ->
  phần thanh dọc (phóng 80-125% / toàn màn hình không báo nhầm), giữ 2 lần đo + điểm phím / chuột phải. Tín hiệu
  `POST /v1/web/signals` -> `WEB_DEVTOOLS` theo IP (đã thấy trong D1 prod). URL ký `/v1/tn/*` (HMAC, <= 7 ngày, hotlink
  403) - `KHOA_URL_KY` người dùng đặt 29/10 (staging + prod, route trả 403 với chữ ký sai). Watermark admin (Access email +
  giờ UTC+7). `ve-sinh-ban-build` chặn thêm script / `on*` nội tuyến. CSP landing `connect-src` + compass-api; trang
  Quyền riêng tư mục 7 nêu tín hiệu khiên. Production: 0 vi phạm enforce; report-only còn vi phạm từ script Cloudflare
  chèn (Email Obfuscation `email-decode.min.js`, JS detections) - xử lý trước khi bật `strict-dynamic` 05/11.
  Runbook: `docs/runbook/khien-web.md`.
- Phát sinh (từ S9) -> S6: xuất CSV ghi audit (SH-04 nửa sau - cần API admin + Access); CSP admin thật (nonce + `connect-src`
  compass-api cho khiên) khi bỏ `_worker.js` 403; API admin cấp URL ký bằng `kyUrl` (SH-05) cho ảnh bằng chứng; watermark
  lấy email từ Access `get-identity` (đã nối, chờ Access). -> S10: bảng `WEB_DEVTOOLS` theo IP / quốc gia trong SOC; cân nhắc
  rule theo IP (shadow). -> Lịch: ký lại gói `web-khien` trước 27/01/2027 (runbook khien-web.md).

### A8 - Hoàn thiện app
- Làm: màn Quyền riêng tư (xem/xuất/xóa, rút đồng ý); onboarding + thông báo xử lý dữ liệu (NĐ 13/2023); VoiceOver/TalkBack;
  Reduce motion; tối ưu cold start (lazy SDK), dung lượng, pin.
- Cổng: ngân sách mục 2 đạt trên máy tham chiếu; audit trợ năng.
- Chia phiên (30/10, phiên song song agent-laban-app): **A8a** quyền riêng tư - thông báo xử lý dữ liệu + đồng ý ở màn
  giới thiệu (NĐ 13/2023, có phiên bản thông báo), cổng đồng ý chặn đăng ký thiết bị / kênh / RASP, màn Quyền riêng tư
  (xem / xuất JSON / xoá toàn bộ dữ liệu app, rút đồng ý, mã thiết bị + yêu cầu xoá phía máy chủ), giấy phép lưu trữ ·
  **A8b** trợ năng (TalkBack semantics, tap target, Reduce motion) + hiệu năng (cold start lazy SDK, dung lượng, pin - đo máy thật).
- Kết quả A8a (31/10, QUYET_DINH Q43): màn giới thiệu kèm thông báo xử lý dữ liệu + "Đồng ý và bắt đầu" / "Chỉ dùng ngoại
  tuyến" (`dongY {ban, trucTuyen, luc}`, `banThongBaoDuLieu` = 1, người dùng bản cũ được hỏi một lần); `CongTrucTuyen` chặn
  định danh / kênh / RASP khi chưa đồng ý hoặc đã rút, đồng ý muộn chạy ngay; màn Quyền riêng tư (Cài đặt): công tắc đồng ý,
  số điểm, xuất JSON qua SAF, xoá toàn bộ (`clearApplicationUserData` + xoá khoá Keystore), mã thiết bị + thư
  privacy@tsudev.com điền sẵn, mở cài đặt app; giấy phép SQLCipher + OpenSSL. Hook pre-commit bỏ qua tệp nhị phân (`grep -I`).
- Nghiệm thu A8a máy thật M32 (31/10, bản thử `--thu` cài đè beta.9): người dùng cũ được hỏi lại; "Chỉ dùng ngoại tuyến" 0 byte
  mạng / 25 s (netstats theo uid); bật đồng ý ở Quyền riêng tư -> 65 KB / 20 s ngay, không cần mở lại; rút -> 0 byte, mở lại
  app vẫn 0 byte (freeRASP không chạy); xuất JSON qua SAF vào Download (1,1 KB, đủ 2 điểm + mã thiết bị); thư yêu cầu xoá mở
  Gmail điền sẵn người nhận / tiêu đề / mã (đã loại bỏ, không gửi); mở cài đặt app; xoá toàn bộ -> app đóng, mở lại như cài
  mới: màn giới thiệu, 0 điểm, không còn vùng offline, mã thiết bị MỚI sau khi đồng ý. Cold start 655-683 ms (lần đầu sau cài 2,0 s).
  A7b: bật máy bay -> bản đồ hiện từ vùng offline, đổi Tối vẫn hiện (chưa thử thu nhỏ tới z0-8 bằng adb).
- Phát sinh A8a: (1) (đã nghiệm thu máy thật 31/10 - xem trên); dung lượng màn Vùng offline giảm 6,0 -> 5,9 MB khi tải thêm
  "Tổng quan Việt Nam" (cách tính tổng của MapLibre?) - A8b xem lại;
  (2) landing `/quyen-rieng-tu` mục 6 nên nêu Cài đặt > Quyền riêng tư trong app + lựa chọn ngoại tuyến (vùng web - phiên chính);
  (3) phát hành APK gộp A8b (tăng version beta.10).
- Kết quả A8b (31/10, QUYET_DINH Q45): `kiemTroNang` (test_kit) chạy audit vùng chạm Android 48 dp / iOS 44 pt, nhãn nút,
  tương phản chữ AA cho mọi màn chính ở sáng / tối, vi / en, chữ x1 / x2 - là phần của cổng; `ChuChonDuoc` thay
  `SelectableText` (vùng chạm 48 dp). Reduce motion: mặt la bàn nhảy thẳng (`BoNoiSuyGoc.nhay`), chuyển trang hiện ngay
  (`LbChuyenTrang`), logo + hiệu chuẩn tĩnh. Cold start: freeRASP / MapLibre / Camera đã lazy (sau khung đầu + cổng đồng ý;
  nhánh tab dựng khi ghé). Màn khoá + băng hạn chế: nút khiếu nại mở landing kèm `?ref=` (S7c1). Phát hành v0.1.0-beta.10.
- Nghiệm thu A8b máy thật M32 (31/10, beta.10 release arm64, Android 13, cáp USB): cold start 612-773 ms (lần đầu sau cài
  2,1 s); uiautomator soát Bản đồ / Điểm / Cài đặt / Quyền riêng tư / Giấy phép: mọi nút có nhãn, vùng chạm >= 48 dp (tab La
  bàn không đạt idle vì nhãn hướng đổi liên tục - đã có widget test); tắt 3 thang hoạt ảnh -> mở Quyền riêng tư: ảnh chụp
  ngay sau chạm đã ở vị trí cuối; pin 30 phút tab La bàn (`battery unplug`, ước tính power profile): app 94,5 mAh, trong đó
  màn hình 91,3 + cảm biến 2,86 -> phần app ~0,13 %/giờ + CPU (máy không định giá CPU, fg 9 phút 47 giây / 30 phút, ước
  ~1 %/giờ) < 3 %/giờ. FPS không đo lại (A8b không đổi đường vẽ; A3: 60 Hz 58 FPS rớt 0,35 %). Bẫy mới: DO COLD START RA
  CHE DO AN TOAN, UIAUTOMATOR MAN LA BAN, DO PIN KHI CAM CAP.
- Phát sinh A8b -> R2: APK arm64 ~33 MB > ngân sách tải 25 MB - đo "download size" thật của AAB trên Play (nén + tách ABI)
  trước khi cắt tính năng; đo pin thật không cắm cáp (Wi-Fi adb) để có số CPU; TalkBack nghe đọc bằng tay (người dùng);
  số 6,0 -> 5,9 MB vùng offline (A8a phát sinh 1) chưa xem.
- Phát sinh (từ A5): màn Giấy phép thêm SQLCipher (BSD, Zetetic) + OpenSSL (Apache 2, bản Android) + drift / sqlite3 (MIT)
  vào `LicenseRegistry`; đo cold start gồm `KhoLuuTru.mo` (mở CSDL ở isolate nền, khoá Keystore) trên máy thật.

### S10 - Vận hành an ninh
- Đọc thêm: SEC-MON.
- Làm: Sentry + Crashlytics (che PII); Tail Worker -> R2 có hash chain + object lock; cảnh báo Telegram; backup D1 hằng ngày ->
  R2 + diễn tập khôi phục; trang status; runbook sự cố, xoay khóa/pin, gỡ chặn (`docs/runbook/`).
- Cổng: diễn tập khôi phục đạt RPO/RTO; cảnh báo thử tới < 2 phút.
- Chia (02/11, QUYET_DINH Q48): **S10a** phía máy chủ (nhật ký bất biến, mốc neo audit từ S7c1, sao lưu + diễn tập, cảnh báo
  đột biến, security.txt + chính sách lỗ hổng, runbook IR / sao lưu / xoay khoá). **S10b** Sentry / Crashlytics trong app
  (SDK bên thứ ba -> người dùng chốt trước, cập nhật Data Safety + Quyền riêng tư) + trang status nếu cần thêm.
- Kết quả S10a (02/11, QUYET_DINH Q48): cron 5 phút xuất `audit_logs` / `security_events` (IP rút gọn) / `rule_hits` -> R2
  `nhat-ky/` đoạn NDJSON nối chuỗi băm + mốc neo audit (`trang-thai/dau-chuoi.json`); sao lưu D1 hằng ngày 02:30 VN mã hoá lai
  AES-GCM + RSA-OAEP 4096 (khoá công khai trong `wrangler.toml`, khoá riêng `~/.config/la-ban/sao-luu/`); R2 bucket lock
  (prod 400 / 30 ngày, staging 30 / 7) + lifecycle (`tools/cloudflare/r2-khoa.mjs`) - xoá thử bị từ chối "locked by the
  bucket policy"; đột biến 5xx / 4xx / từ chối / attestation lỗi / phát lại từ Analytics Engine -> Telegram (chống lặp KV),
  việc định kỳ lỗi -> Telegram; security.txt có `Policy` + trang `/bao-cao-lo-hong/` `/en/security/`; runbook
  `ung-pho-su-co.md` (NĐ 13: 72 giờ) / `sao-luu-khoi-phuc.md` / `xoay-khoa.md`. **Diễn tập staging đạt**: 12 bảng khớp số
  dòng, RTO 52 s; **prod đạt** (bản 02/11 kích tay `cron=thu:sao-luu`): 13 bảng, RTO 35 s; chuỗi nhật ký nguyên vẹn cả hai. Test mới: 11 Worker (thuần + tích hợp workerd) + 2 tools.
  CHƯA (người dùng): bot Telegram (`TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID`) + token chỉ Account Analytics Read
  (`CF_AE_TOKEN`) -> mới đo được "cảnh báo thử < 2 phút"; sao lưu khoá riêng ra ngoài máy.
- Kết quả S10b (02/11, QUYET_DINH Q49 - người dùng giao chọn, chi phí 0): báo cáo sự cố TỰ XÂY thay Sentry / Crashlytics.
  App: `packages/core` `BaoCaoLoi` (che + cắt + bỏ trùng), `app/lib/src/bao_loi.dart` (bắt lỗi Flutter / isolate, hàng đợi
  tệp, gửi lô ký thiết bị khi cổng trực tuyến mở + công tắc riêng "Gửi báo cáo sự cố" mặc định TẮT ở Quyền riêng tư, rút
  thì xoá hàng đợi). Worker: migration 0010 `app_crashes` (90 ngày, vào bản sao lưu), `POST /v1/app/su-co`, SOC
  `/su-co-app` (nhóm + tỷ lệ không lỗi) + trang admin "Sự cố app". `tools/build/giai-ngan-xep.sh` (flutter symbolize với
  symbol ngoài repo). Landing Quyền riêng tư mục 3 / 4 + Data Safety "Crash logs". Crash native / ANR + crash-free cho R4 =
  Android vitals Play Console. Phiên bản app 0.1.0-beta.12 (APK do người dùng chạy `phat-hanh-apk.sh`).
- Nghiệm thu S10 (02/11): Telegram nhóm "La bàn - Cảnh báo SOC" người dùng thử đạt; `TELEGRAM_*` + `CF_AE_TOKEN` cả hai
  môi trường; cron prod `dot-bien` -> `{"dotBien":[]}` (đọc được Analytics Engine). Máy thật M32 (beta.12 cài đè beta.11, giữ
  dữ liệu): cold start 588-666 ms, công tắc "Gửi báo cáo sự cố" mặc định tắt / bật được / lưu bền qua khởi động lại, đi qua
  La bàn / Bản đồ / Điểm / Hiệu chuẩn / Tuỳ chọn / Camera AR không lỗi Flutter trong logcat, D1 `app_crashes` = 0. **Lỗi tìm
  thấy + sửa**: `devices.app_version` / `last_seen` không cập nhật sau nâng cấp (D1 ghi beta.10 khi máy chạy beta.12; mẫu số
  tỷ lệ không lỗi thiếu) -> `/v1/status` ghi nền theo header `x-app-version` (PR #44, #45) - đo lại M32: `0.1.0-beta.12` build 12.

### R2 - Sẵn sàng store
- Làm: khóa upload Android (ngoài repo) + Play App Signing; scheme/configuration flavor iOS dev/staging/prod (Xcode trên Codemagic/Mac); Codemagic cho iOS (App Store Connect API key); Privacy Manifest +
  Required Reason API; Data Safety khớp thực tế (gồm SDK bên thứ ba); `NS*UsageDescription` vi/en; ảnh store sinh tự động từ
  integration test; listing vi/en; ghi chú reviewer về cơ chế bảo mật; allow-list thiết bị review.
- Cổng: bản internal (Play) cài được (TestFlight dời sang I1 - Q33).
- Chặn (29/10/2026): thanh toán 25 USD Play Console lỗi -> người dùng tạo tài khoản nhà phát triển Play sau ~7 ngày
  (dự kiến từ 05/11/2026). Khi có tài khoản, làm theo thứ tự: tạo app `La bàn - TsuDev Compass` -> App integrity ->
  liên kết dự án Cloud `app-la-ban` (Project number 930761930572, QUYET_DINH Q35 - không đổi mã) -> tải AAB internal
  (gắn tên gói `com.tsudev.laban`) -> Play App Signing dùng khoá upload R0 -> kiểm phán quyết app chuyển từ
  `UNRECOGNIZED_VERSION` sang `PLAY_RECOGNIZED` cho bản tải từ Play (bản APK R0 vẫn đạt nhờ cùng chứng chỉ).
- Ghi chú (Q33/Q34): phần iOS của thẻ này (scheme flavor, Codemagic, Privacy Manifest, `NS*UsageDescription`) chuyển sang I1.
  Play App Signing: chọn tải lên khoá upload R0 làm khoá ký ứng dụng để người đã cài APK thử cập nhật thẳng từ Play.
- Kết quả R2a (31/10/2026, Q46, phần không cần Play Console): `tools/build/build-aab.sh` (AAB prod 3 ABI ký khoá upload,
  so quyền manifest gộp với `docs/store/data-safety.md`, đo download size bằng bundletool trong cache Gradle); gỡ quyền thư
  viện `READ_GSERVICES` (GSF ID qua fingerprint-android của freeRASP) + `RECEIVE_BOOT_COMPLETED` (truetime) - cài đè trên M32
  (bundletool split ký khoá upload, giữ dữ liệu): freeRASP `libts.so` nạp, không crash. **Download size thật** (bản beta.10):
  arm64 32,4 MB · armv7 29,0 MB · x86_64 31,0 MB (APK tải trực tiếp 33,0 MB) - vượt ngân sách 25 MB hoàn toàn do freeRASP
  (`libts.so` 12,5 MB nén / arm64; phần còn lại ~20 MB: Flutter 5,2 · MapLibre 3,6 · Dart 2,6 · SQLCipher 1,9 · dex + tài
  nguyên) - giữ theo Q13 / Q36. Listing vi / en (`docs/store/play-listing.md`, cổng kiểm độ dài + từ cấm), Data Safety,
  ghi chú reviewer (en / vi), runbook `docs/runbook/phat-hanh-play.md` (PEPK, liên kết Play Integrity, internal track),
  ảnh nổi bật 1024x500 + 24 ảnh điện thoại 1080x1920 (`./tools/build/anh-store.sh`, widget test `app/test_store`).
- Còn lại R2b (sau khi có Play Console): tạo app + Play App Signing PEPK + internal track + phán quyết `PLAY_RECOGNIZED`
  (runbook mục 2-3); agent-laban: quy tắc miễn trừ ASN Google cho thiết bị duyệt (runbook mục 4) + landing đổi nút Play;
  TalkBack nghe đọc tay (người dùng).
- Kết quả R2 miễn trừ (02/11, từ ghi chú R2a): ASN của kết nối (`request.cf.asn`) đi vào Threat Engine ở mọi nguồn sự
  kiện (trước đây thiếu -> allow-list theo ASN không khớp); allow-list quản lý từ SOC (`/cho-phep`, `/cho-phep/them` /
  `go`, quyền `cho-phep` security_admin + passkey + audit, hạn 24 giờ - 90 ngày, nút điền ASN Google), trang Can thiệp
  có mục Danh sách cho phép. Landing: bỏ nhãn "Sắp có" ở 5 tính năng đã phát hành; Quyền riêng tư mục 5 nói rõ freeRASP
  không được đọc GSF ID. Test mới: 2 thuần + 1 tích hợp Worker.

- Kết quả R2b internal (04/11/2026, Q63): người dùng tải `la-ban-0.1.0-beta.16.aab` lên **Thử nghiệm nội bộ** (bản
  `16 (0.1.0-beta.16)`, danh sách `TsuDev Compass noi bo` 2 người), link tham gia
  `https://play.google.com/apps/internaltest/4700876326543944136`; M32 cài từ Play (installer `com.android.vending`), mở
  được. Không qua PEPK -> Play tự tạo khoá ký: SHA-256 `B8:4D:41:...:8B:7B` (đo `apksigner` trên `base.apk` kéo từ M32).
  Sửa: Worker prod `PI_CHUNG_CHI` thêm chứng chỉ Play (trước đó bản Play bị chấm `failed` / `chung-chi`), app
  `Flavor.chungChiHopLe` (native + freeRASP - beta.16 bản Play tự báo `APP_REPACKAGED`), `assetlinks.json`; v0.1.0-beta.17.
  Hướng dẫn Play Console bản 2: B2 khoá ký, B2b trang "Được bảo vệ bằng Play", E0 danh sách kiểm trước gửi duyệt, E1 / E2
  từng bước + `tools/build/ky-duyet-play.sh bat / tat / trang-thai`.
- Còn R2b: người dùng liên kết Play Integrity (B2b) -> agent kiểm `PLAY_RECOGNIZED` trên SOC; tải AAB beta.17 lên internal;
  Phần A 11/11; thử kín (Phần C) - mỗi lần gửi duyệt làm E0 -> E1, duyệt xong E2.

### R3 - QA tổng
- Đọc thêm: SEC-TEST.
- Làm: E2E (cài mới -> attest -> la bàn -> waypoint -> chia sẻ -> nâng cấp); ma trận nâng cấp + OTA + rollback; benchmark;
  MobSF + ZAP + Semgrep; bộ kịch bản kiểm thử bảo mật nội bộ trên thiết bị thử của dự án; chuẩn bị gói cho pentest độc lập.
- Cổng: tiêu chí Spec §15 mục 1-11 đạt; 0 Critical/High mở.
- Kế hoạch chia (02/11, bàn giao từ phiên S10 - máy chưa có công cụ nào: semgrep / osv-scanner / gitleaks / docker / ZAP /
  MobSF đều KHÔNG có; RAM 7 GB, không docker -> cài bản độc lập vào `~/tools/` NGOÀI repo, chi phí 0):
  - **R3a - quét tự động + web** (một phiên): (1) cài `gitleaks` + `osv-scanner` (binary GitHub release vào `~/tools/bin`),
    `semgrep` (venv `~/tools/semgrep`), ZAP (bản cross-platform chạy bằng JDK 21 sẵn có, `zap.sh -cmd` / baseline), MobSF
    (venv Python, chỉ phân tích tĩnh APK - nếu quá nặng RAM thì ghi lý do + thay bằng `apkanalyzer` / `aapt2` + kiểm tay);
    (2) nối `cong.sh day-du`: gitleaks toàn lịch sử, osv-scanner `package-lock.json` + `pubspec.lock` (hiện cổng bỏ qua vì
    thiếu lệnh), semgrep (`p/typescript`, `p/secrets`, luật tự viết cho Worker: SQL nối chuỗi, thiếu `canQuyen`); (3) ZAP
    baseline vào landing / admin (preview) / API **staging** (không quét prod), securityheaders + SSL Labs (A+), kiểm CSP
    không `unsafe-*`, tỷ lệ request tự động không token tới API bảo vệ bị chặn >= 99 %; (4) MobSF APK beta.12: 0 High
    (quyền, `exported`, cleartext, debuggable, khoá cứng). Mọi phát hiện Critical / High sửa ngay trong phase; Medium ghi
    hạn. Kết quả vào `docs/kiem-thu/R3a-<ngày>.md` (không dán bí mật / PII).
  - **R3b - E2E + kịch bản nội bộ trên M32** (một phiên, cần người dùng mở khoá PIN M32 - adb đã bật `svc power stayon usb`):
    (1) E2E tay có kịch bản qua adb (`uiautomator dump` + `input tap`, ảnh chụp): cài mới -> đồng ý -> attest -> la bàn ->
    điểm mốc -> chia sẻ link /w/ -> mở lại -> nâng cấp; (2) ma trận nâng cấp beta.7 -> beta.12 (APK trên GitHub Release),
    dữ liệu còn, migration Drift đúng; Remote Config ép `toiThieu` + rollback; (3) kịch bản bảo mật nội bộ SEC-TEST: APK đóng
    gói lại (apktool + ký khoá khác) -> SOC ghi nhận + chặn, phát lại request (nonce) -> 401, sửa thân sau ký -> 401, giả vị
    trí (mock location app) -> tín hiệu, proxy chặn giữa (mitmproxy, CA người dùng) -> pin từ chối; mục tiêu >= 95 % được
    ghi nhận, 100 % request nhạy cảm không hợp lệ bị từ chối; (4) đối chiếu ngân sách Spec §15 (mục 0 / 2 của kế hoạch:
    cold start, FPS, jank, tải về, pin) - số đã đo ở A3 / A8b / R2a / S10, đo lại phần thiếu; (5) chuẩn bị gói pentest độc
    lập (`docs/kiem-thu/goi-pentest.md`: phạm vi, tài khoản thử staging, service token, quy tắc - chưa chốt đơn vị, Q25).
  - Kết quả R3b (02/11, Q51, `docs/kiem-thu/R3b-20261102.md`): E2E + ma trận nâng cấp beta.7 -> 13 đạt (dữ liệu giữ, 0
    crash); Remote Config `toiThieu` + rollback thử trên staging (đẩy cấu hình prod bị chế độ auto chặn); 5/5 kịch bản
    SEC-TEST ghi nhận / chặn, 14/14 request ký sai bị từ chối. Sửa 2 lỗi: link /w/ thứ hai giữ nội dung cũ (`ValueKey`
    route); **High** - bản đóng gói lại bị cấm, mở lại sau khi access token hết hạn vẫn vào la bàn (làm mới phiên 403
    `thiet-bi-bi-cam` chỉ là lỗi) -> `tinhTrang()` coi đó là `banned` + REF. Thêm nguồn `Location.isMock` -> `MOCK_LOCATION`.
    Ngân sách §15 đạt trừ tải về (freeRASP, Q13 / Q36) và **API p95 phía server** (AE prod 7 ngày: `/v1/health` p50 213 ms,
    `/v1/status` p95 1,85 s, `/v1/session/refresh` p95 2,6 s, `/v1/events` p95 3,7 s) -> R3c.
  - **R3c - tối ưu độ trễ API** (một phiên, không cần M32): (1) đo từng đoạn trong Worker (thêm `doubles` theo bước vào AE:
    middleware `chanTheoThucThi` / `gioiHanThoIp` / `bayQuet`, D1, DO nonce, DO rate) trên staging - `Date.now()` trong
    Worker chỉ nhảy khi có I/O nên đúng là thời gian chờ I/O; (2) nghi phạm: mỗi request gọi nhiều DO tuần tự (rate + nonce
    + realtime) và D1 primary APAC không bật read replication (`d1 info`: `read_replication.mode disabled`) - gộp / song song
    hoá lời gọi, cache danh sách chặn trong bộ nhớ isolate + KV, bật D1 read replication (Sessions API) cho truy vấn đọc,
    `/v1/health` không chạm D1 / DO; (3) đo lại AE sau 24 h: p95 < 300 ms cho `/v1/status`, `/v1/config`, `/v1/events`,
    `/v1/session/refresh`. Không đổi hợp đồng API / chữ ký. Staging trước, prod sau.
  - Kết quả R3c (03/11, Q52): đo từng bước vào AE (doubles `chan` / `rlIp` / `phien` / `nonce` / `gioiHan` / `luuTru` /
    `d1` / `lanh` + blob5 colo) chỉ ra thủ phạm KHÔNG phải D1 (~10 ms từ SIN) mà là **Durable Object: ~485 ms mỗi lần một
    isolate chạm DO lần đầu** (nonce + rate + PhongSoc). Chuyển nonce + giới hạn sang D1 (migration 0011 / 0012, nonce + luật
    thiết bị chung một batch), route công khai chỉ đọc dùng Rate Limiting binding + Cache API colo, Threat Engine sau ghi sự
    kiện chạy `waitUntil`, `/v1/health` không chạm D1, refresh gộp ghi IP. Staging lưu lượng thưa: p50 16-46 ms mọi route,
    p95 `/v1/status` 118 ms, `/v1/session/refresh` 46 ms, `/v1/config` 211 ms, `/v1/web/cau-hinh` 36 ms (trước, prod 7 ngày:
    1,3-4,4 s). Không đổi hợp đồng API / chữ ký; e2e staging + prod đạt. **Prod**: D1 primary ở ICN (staging SIN) ->
    mỗi vòng D1 từ SIN ~70-100 ms; thêm kiểm chặn song song (#49, #50); mẫu nhỏ prod p50 ~100 ms mọi route, p95
    `/v1/status` 374 ms, `/v1/config` 188 ms, refresh 596 ms. Đo lại 24 h (`./tools/thu/do-tre-ae.sh prod 24`); chuyển D1
    prod sang DC gần hơn chỉ khi người dùng duyệt (`docs/kiem-thu/R3c-20261103.md` mục 5).
  - Chuyển D1 prod sang SIN (03/11, Q53, #52, người dùng duyệt): `la-ban-prod`, chép giữ rowid, đối chiếu trùng 100 %;
    prod p50 8-49 ms, p95 45-246 ms mọi route (mẫu nhỏ). Xoá D1 cũ `la-ban` (ICN) sau 17/11.
  - Đo 24 h prod (04/11): ~110 request / ngày, isolate lạnh 45-88 %, `luuTru` (KV / R2 khi Cache API trượt) 132-185 ms;
    p95 `/v1/status` 728 ms (n 11) - mẫu lạnh, chưa đại diện tải. Đo lại khi có lưu lượng thử kín (R2b / R4)
    (`docs/kiem-thu/R3c-20261103.md` mục 6).
  - Phát sinh: bỏ lớp DO `KhoNonce` / `GioiHanToc` (deleted_classes) ở bản Worker sau.
  - Cổng R3 = R3a + R3b + R3c đạt + 0 Critical / High mở. iOS ngoài phạm vi (I1).

### R4 - Phát hành v1.0.0
- Làm: staged rollout Play (1->5->20->50->100%) (iOS phased ở I1); Shorebird kênh staging -> stable; theo dõi crash-free, ANR, chặn
  nhầm; runbook trực.
- Song song (người dùng chốt 03/11): M1a bước 3 (máy chủ quyền lợi) -> M2 app "La bàn Pro"; thử kín app chính và app Pro
  cùng 12 tester trong CÙNG cửa sổ 14 ngày (tài khoản cá nhân), production hai app cùng đợt.
- Cổng: crash-free >= 99,8%; không sự cố mở. Bắt đầu đếm 4 tuần Release Gate.

### M1 - Gói Pro trong app + quảng cáo (chia M1a / M1b)
- Đọc thêm: Spec §12; SEC-IAP; QUYET_DINH Q17, Q55.
- Nguyên tắc: (1) quyền lợi (entitlement) do Worker quyết - app chỉ hiển thị theo `/v1/status` đã ký; (2) có quyền lợi
  `khongQuangCao` thì KHÔNG khởi tạo AdMob / UMP (không chỉ ẩn banner); (3) KHÔNG khoá lại tính năng đang miễn phí ở bản beta
  (la bàn, toạ độ, điểm mốc, chia sẻ, bản đồ offline, Camera AR) - giới hạn miễn phí chỉ áp cho tính năng MỚI; (4) không tài
  khoản người dùng: quyền lợi gắn với tài khoản Google trên Play, khôi phục bằng Restore trên máy mới.
- **M1a - Quyền lợi + Google Play Billing** (làm trước, có thể phát hành trước khi bật quảng cáo):
  1. Sản phẩm Play (người dùng tạo trong Play Console theo runbook): gói đăng ký `pro_thang`, `pro_nam` (base plan +
     dùng thử 7 ngày cho `pro_nam`) và sản phẩm mua một lần `pro_tron_doi` (non-consumable; mã cũ `pro_vinh_vien` đã xoá trên Play, đổi 06/11 - Q67) - giá chốt 03/11 (Q55): 19.000 đ / tháng, 99.000 đ / năm, 149.000 đ vĩnh viễn.
  2. App: gói `packages/quyen_loi` (thay phần IAP của `ads_iap`) dùng plugin chính chủ `in_app_purchase` (Play Billing
     Library, không SDK bên thứ ba); `obfuscatedAccountId` = băm định danh cài đặt (không định danh phần cứng); màn Paywall
     vi / en, giá lấy từ Play (`ProductDetails`, không ghi cứng), nút Khôi phục, Quản lý gói (deep link Play subscriptions),
     hiển thị điều khoản tự gia hạn đúng chính sách Play. Domain thuần: máy trạng thái quyền lợi + thời gian ân hạn offline.
  3. Worker: `POST /v1/mua/xac-minh` (ký request như S3) -> Google Play Developer API (`purchases.subscriptionsv2.get` /
     `purchases.products.get`) bằng service account sẵn có -> acknowledge trong 3 ngày -> ghi D1 bảng mới `quyen_loi`
     (migration mới: nguồn `play_sub` / `play_inapp` / `pro_app`, sản phẩm, trạng thái, hết hạn, băm token, token mã hoá
     AES-GCM khoá `wrangler secret`, thiết bị gắn). `/v1/status` trả `quyenLoi { pro, khongQuangCao, hetHan }` trong phản hồi
     đã ký. RTDN: Pub/Sub push -> `POST /v1/play/rtdn` (xác minh JWT OIDC của Google, audience riêng) cập nhật gia hạn / huỷ /
     tạm giữ / thu hồi; cron hằng ngày đọc Voided Purchases API -> thu hồi khi hoàn tiền / chargeback.
  4. Chống gian lận: một token tối đa N cài đặt đang hoạt động (mặc định 5, Remote Config), token dùng lại vượt ngưỡng ->
     sự kiện `PURCHASE_TOKEN_SHARED` vào Threat Engine; giao dịch từ bản không phải Play (`appRecognitionVerdict` khác
     `PLAY_RECOGNIZED`) không cấp quyền; thiết bị `banned` không mua / không nhận quyền lợi mới (quyền lợi cũ giữ nguyên để
     xử lý hoàn tiền qua khiếu nại).
  5. SOC: trang Quyền lợi (tra theo thiết bị / băm token, lịch sử RTDN, thu hồi thủ công four-eyes + audit), số liệu doanh
     thu ước tính từ AE (không PII). Data Safety: thêm "Lịch sử mua hàng" (thu thập, không chia sẻ); chính sách quyền riêng tư.
- **M1b - Quảng cáo** (chỉ bật qua Remote Config khi đạt Release Gate §12.1): gói `packages/quang_cao` (AdMob + UMP; ATT ở
  I1) CHỈ app miễn phí phụ thuộc; khởi tạo lười sau đồng ý UMP VÀ khi `khongQuangCao = false`; banner thích ứng chỗ dành
  sẵn, không che la bàn / telemetry, ẩn trong AR; interstitial giới hạn tần suất (<= 1 / 5 phút, <= 3 / phiên, không bao
  giờ khi đang đo / điều hướng); rewarded xác minh SSV ở Worker; thiết bị restricted / banned không nhận quảng cáo / thưởng;
  kill-switch từng loại quảng cáo; Paywall có lối "Gỡ quảng cáo" từ banner.
- Kết quả M1a bước 3 (03/11, PR #66, main `b145e92`): migration 0013 `quyen_loi` + `quyen_loi_devices` + `quyen_loi_events`
  (vào bản sao lưu D1); `POST /v1/mua/xac-minh` (ký S3; hỏi `subscriptionsv2` / `products` bằng service account sẵn có, phạm vi
  androidpublisher; acknowledge nền; token AES-GCM `KHOA_QUYEN_LOI` + SHA-256; `linkedPurchaseToken` -> thu hồi token cũ; tối
  đa `QL_THIET_BI_TOI_DA`=5 cài đặt / 30 ngày -> 403 + `PURCHASE_TOKEN_SHARED`; prod `QL_YEU_CAU_PLAY=1` chỉ nhận bản
  `PLAY_RECOGNIZED`); `POST /v1/play/rtdn` (JWT OIDC Google: iss / aud `RTDN_AUD` / email `RTDN_EMAIL` / email_verified, sai -> 401 +
  `RTDN_INVALID`; Google lỗi -> 503 để Pub/Sub gửi lại); cron 02:15 VN: Voided Purchases 3 ngày -> thu hồi, hỏi lại gói sắp hết
  hạn; `/v1/status.quyenLoi {pro, khongQuangCao, hetHan}`; app Pro LICENSED + PLAY_RECOGNIZED -> `pro_app`, UNLICENSED ->
  thu hồi + `PRO_UNLICENSED` (0 điểm). 29 test mới. Staging + prod đã deploy; `RTDN_EMAIL` chờ người dùng tạo Pub/Sub
  (runbook phat-hanh-play mục 6) - tới lúc đó route RTDN trả 503.
- Kết quả M1a bước 2 (04/11, nhánh `phase/m1a-app`): gói `packages/quyen_loi` - domain thuần `tinhQuyenLoi` (ân hạn offline
  3 ngày, lùi đồng hồ không kéo dài hạn, vĩnh viễn giữ tới khi máy chủ báo khác), `chonUuDai` (dùng thử > base plan), máy
  trạng thái Paywall, `loiTuPhanHoi` (mã Worker -> chuỗi); `CuaHangPlay` bọc `in_app_purchase` 3.3 (giá / kỳ / dùng thử từ
  Play, `obfuscatedAccountId` = SHA-256 định danh cài đặt); `DichVuQuyenLoi` chỉ `completePurchase` sau khi Worker cấp quyền
  lợi, giao dịch dở gửi lại khi mở app, Khôi phục = `queryPastPurchases`; `/v1/status.quyenLoi` -> lưu `quyen_loi.json`.
  Paywall vi / en (giá Play, điều khoản tự gia hạn + dùng thử, Khôi phục, Quản lý gói -> trang Gói thuê bao của Play qua
  kênh `moTrang`), mục "La bàn Pro" trong Cài đặt. Mở bán (Q61): dev / staging mở, prod đóng (`moBanProTrongProd`) tới R4,
  kill-switch `mua-pro`. Data Safety + chính sách: "Purchase history". 40 test gói + 8 test app + golden `man_pro`.
  Chưa thử máy thật: cần sản phẩm Play (bước 1) + license tester + bản cài từ Play (internal testing).
- Kết quả M1a bước 4 phần SOC + bước 5 (04/11, nhánh `phase/m1a-soc`, Q64): migration 0015 `quyen_loi_requests` (four-eyes
  thu hồi, một yêu cầu chờ / quyền lợi) + chỉ mục `order_id` / `updated_at`; Admin API `/admin/v1/quyen-loi` (tra cứu theo mã
  thiết bị / băm token / mã đơn GPA. / mã quyền lợi, lọc trạng thái / nguồn, cursor), `/chi-tiet` (thiết bị gắn + hoạt động 30
  ngày, lịch sử `quyen_loi_events`, yêu cầu; không `token_enc`, băm tài khoản rút gọn), `/so-lieu` (D1 theo sản phẩm + doanh
  thu ước tính AE 7 / 30 / 90 ngày), `/go-thiet-bi` (đổi máy chạm N), `/thu-hoi` -> `/yeu-cau/quyet` (người thứ hai) -> revoked
  + audit. Luồng mua ghi điểm AE `doanh-thu` (mua mới khi dòng vừa tạo, gia hạn RTDN 1 / 2, hoàn tiền). Trang SOC "Quyền lợi
  Pro" (`g p`) vi / en. Bản sao lưu D1 thêm `quyen_loi_requests`. Test: 6 thuần + 1 tích hợp workerd (quyền theo vai trò,
  chống tự duyệt, 409 trùng / đã quyết / đã thu hồi, audit).
- Cổng M1a: mua / gia hạn / huỷ / hoàn tiền / khôi phục trên máy thật bằng tài khoản thử license tester đúng trạng thái ở
  app + D1 + SOC; RTDN tới Worker < 1 phút; test thuần + tích hợp Worker (token giả, JWT RTDN sai -> 401).
- Cổng M1b: chênh FPS có / không quảng cáo < 2 %; không che la bàn; người có `khongQuangCao` không có request nào tới
  máy chủ quảng cáo (kiểm bằng proxy); v1.1.0.

### M2 - App song song "La bàn Pro" (trả phí một lần, không quảng cáo - Q56)
- Đọc thêm: SEC-IAP; QUYET_DINH Q56.
- Mục tiêu: listing Play riêng `com.tsudev.laban.pro`, tên `La bàn Pro - TsuDev Compass`, giá một lần 99.000 đ (chốt 03/11, Q56); chạy CÙNG R4;
  đủ mọi tính năng Pro, KHÔNG chứa SDK quảng cáo trong APK (Data Safety không có Advertising ID). Cùng mã nguồn, cùng Worker.
- Làm:
  1. Tách vỏ app: chuyển entry / DI / router / theme từ `app/lib` sang gói `packages/app_shell` nhận `CauHinhSanPham`
     (`mienPhi` / `pro`); `app/` (miễn phí, phụ thuộc `quang_cao`) và `app_pro/` mới (KHÔNG phụ thuộc `quang_cao`) chỉ còn
     `main` + Android (applicationId, icon / tên riêng, flavor dev / staging / prod). Golden + test chung vẫn xanh. Cập nhật
     cấu trúc thư mục ở CLAUDE.md + AGENTS.md trong cùng PR. Icon: chép `design/logo/pro/android/res/mipmap-*` vào
     `app_pro/android/app/src/main/res` (adaptive XML, nền, monochrome dùng chung bản miễn phí; flavor dev / staging của
     app Pro giữ nhãn DEV / STG) - logo đã sinh 03/11: icon bản DEV với viên nhãn `PRO` nền xanh lá token `success`.
  2. Bản quyền: app Pro gửi Play Integrity như S2; Worker thêm `com.tsudev.laban.pro` vào danh sách gói (biến môi trường
     sẵn có) và cấp quyền lợi `pro_app` khi `accountDetails.appLicensingVerdict = LICENSED`. `UNLICENSED` (bản sao tải
     ngoài) -> tín hiệu `PRO_UNLICENSED`, app hiện hộp thoại khắc phục GET_LICENSED của Play Integrity, chỉ còn tính năng
     của bản miễn phí (không khoá cứng ở client - server quyết). KHÔNG phát hành APK Pro trên GitHub / CDN (R0 chỉ bản miễn phí).
  3. Chuyển dữ liệu từ bản miễn phí: Content Provider trong app miễn phí bảo vệ bằng permission `signature` (hai app cùng
     khoá ký - Play App Signing dùng chung khoá upload R0 qua PEPK) -> app Pro nhập điểm mốc / vùng offline / cài đặt một
     lần, có màn xác nhận; dự phòng: tệp xuất mã hoá chia sẻ qua Android Sharesheet. App miễn phí thấy app Pro đã cài (khai
     báo `<queries>` đúng một gói) -> gợi ý mở app Pro, không hiện quảng cáo.
  4. Store: listing vi / en riêng nêu rõ quan hệ bản miễn phí / bản Pro (tránh vi phạm chính sách nội dung lặp lại), ảnh store
     sinh bằng `anh-store.sh` với cờ Pro, Data Safety riêng, ghi chú reviewer, miễn trừ ASN Google áp chung. Tài khoản cá nhân:
     thử kín >= 12 người x 14 ngày RIÊNG cho app này - dùng chung 12 tester, chạy cùng lúc với app chính nếu kéo M2 lên.
  5. SOC: lọc thiết bị theo gói; báo cáo tách bản miễn phí / Pro.
- Kết quả M2a (05/11, nhánh `phase/m2a-vo-app`, Q65): bước 1 - vỏ app chuyển sang `packages/app_shell` (`CauHinhSanPham` +
  `LoaiApp`, toàn bộ test + golden giữ nguyên, 0 golden đổi); `app/` + `app_pro/` chỉ còn `main` + Android + test khớp phiên
  bản / Gradle; icon Pro sinh thẳng vào `app_pro` (`thuong-hieu.mjs`); luật lớp cấm quảng cáo bắc cầu vào `la_ban_pro` /
  `app_shell`; `build-aab.sh --pro` kiểm AAB không có lớp / quyền quảng cáo. Bước 2 - app Pro không bán gói (`CuaHangKhongBan`),
  mục "Bản quyền La bàn Pro" + hộp thoại GET_LICENSED (Play Integrity Standard `showDialog`) -> xác minh lại + làm mới
  status; Worker thêm gói Pro vào `PI_GOI`, `goiBanTrongApp` loại gói Pro khỏi mua / RTDN / Voided. Bước 5 - migration 0016
  `devices.package_name`, SOC lọc `ungDung`, thẻ "Ứng dụng (30 ngày)", nhãn Pro ở danh sách thiết bị. Runbook Play Phần F
  (tạo app có phí, DÙNG CHUNG khoá ký với La bàn, liên kết Integrity, quyền service account).
- Phát sinh M2b: bước 3 (Content Provider `signature` + màn nhập, `<queries>` một gói), bước 4 (listing vi / en, `anh-store.sh`
  cờ Pro, Data Safety riêng, `assetlinks.json` thêm gói Pro sau khi biết chứng chỉ Play của app Pro); cổng máy thật
  (LICENSED từ Play, sideload UNLICENSED + hộp thoại) chờ người dùng làm Phần F.
- Kết quả M2b bước 3 (05/11, nhánh `phase/m2b-chuyen-du-lieu`, Q66): domain thuần `app_shell/lib/src/domain/chuyen_pro.dart`
  (`taoGoiChuyen` / `docGoiChuyen` nhận cả tệp xuất cá nhân / `keHoachNhapPro`), `chuyen_pro.dart` (kênh `la_ban/chuyen_pro`,
  `ManChuyenSangPro`, `ManNhapTuMienPhi` + tải lại vùng, `MucChuyenPro`, `KhungChuyenPro` nghe yêu cầu lúc mở / quay lại app),
  Kotlin `ChuyenProProvider` + `MoChuyenProActivity` + `KenhChuyenPro` (app/) và `NhanTuMienPhiActivity` + `KenhChuyenPro`
  (app_pro/), quyền signature + `<queries>` theo flavor, `VungOffline.khung` + `taiVung` (map_feature), 29 chuỗi vi / en,
  11 test (`chuyen_pro_test.dart`), luật APK chấp nhận exported giữ bằng quyền signature tự khai báo.
- Phát sinh M2b còn lại: build APK dev hai app + thử máy thật (gửi / nhận / Lấy từ La bàn / tệp dự phòng, đủ 100 % điểm);
  `aapt2 dump xmltree` kiểm định dạng `protectionLevel` khớp `kiem-apk-luat.mjs`; bước 4 store (listing vi / en Pro,
  `anh-store.sh --pro`, Data Safety Pro, ghi chú reviewer, `assetlinks.json` gói Pro sau Phần F).
- Kết quả M2b build + bước 4 (06/11, cùng nhánh `phase/m2b-chuyen-du-lieu`, PR #102): Kotlin hai app biên dịch được (APK
  dev debug + staging release, JDK 21 `~/tools/java/jdk21` - JDK 17 vỡ ở `maplibre_gl` "invalid source release: 21");
  `aapt2` build-tools 36 in `protectionLevel(0x01010009)=0x00000002` -> thêm test định dạng thật vào `kiem-apk.test.mjs`,
  `kiem-apk.mjs` APK release hai app xanh. Manifest Pro gỡ `com.android.vending.BILLING` (in_app_purchase kéo theo, Pro không
  bán trong app) + `build-aab.sh --pro` dừng nếu còn và so quyền với `data-safety-pro.md`. Bước 4: `docs/store/play-listing-pro.md`
  (vi / en, nêu rõ quan hệ miễn phí / Pro, `kiem-listing.mjs` kiểm cả hai tệp), `data-safety-pro.md` (không Advertising ID,
  không Purchase history), `ghi-chu-reviewer.md` mục La bàn Pro, `huong-dan-play-console.md` F5 trỏ tệp, `anh-store.sh --pro`
  (`--dart-define=PRO=true` -> `design/store/pro/<vi|en>/` 28 ảnh, ảnh 7 riêng Pro: Cài đặt bản quyền đã xác minh), chính sách quyền riêng tư landing nêu app Pro (06/11).
- Phát sinh M2b còn lại (cần người dùng): thử máy thật M32 (APK staging release hai app ký cùng khoá upload: gửi / nhận /
  Lấy từ La bàn / tệp dự phòng, đủ 100 % điểm); Phần F (F2 dùng chung khoá ký) -> LICENSED / UNLICENSED trên máy thật;
  `assetlinks.json` thêm gói Pro sau F (chứng chỉ Play app Pro).
- Cổng: APK Pro không chứa lớp `com.google.android.gms.ads` (kiểm bằng `apkanalyzer dex packages`); bản cài từ Play nhận
  `LICENSED` + quyền lợi `pro_app`, bản sideload nhận `UNLICENSED` + hộp thoại; chuyển dữ liệu từ bản miễn phí trên máy
  thật đủ 100 % điểm mốc; golden + cổng `day-du` xanh.

### A9 - Thiết bị thiếu phần cứng + làm mới giao diện + chống nhấp nháy (PHIÊN SONG SONG, chia A9a / A9b / A9c)
- Đọc thêm: QUYET_DINH Q59, Q60; thẻ A2, A3, A7, A8; `docs/BAY_DA_GAP.md` (golden, font).
- Chạy ở worktree `../app-la-ban-a9` (cùng ổ đĩa), agent `agent-laban-a9`. Mỗi phần một nhánh từ `origin/main` mới nhất
  (`phase/a9a`, `phase/a9b`, `phase/a9c`) -> PR -> squash merge. Rebase lên `origin/main` ngay trước mỗi PR (phiên chính
  đang làm M1a bước 3 / S11 ở `workers/`, `web/shield/`, `packages/security_sdk/`).
- **Vùng ĐƯỢC sửa**: `packages/{sensors,compass_feature,location_feature,map_feature,waypoint_feature,ar_feature,settings_feature,design_system}`,
  `packages/i18n` (chuỗi mới gom MỘT khối cuối tệp ARB, tiền tố `a9`), `design/tokens.json` + `design/tools`, `web/landing/src`
  (giao diện), `web/admin/src` CHỈ phần trình bày (CSS, theme, component hiển thị - không đổi luồng tải dữ liệu / auth),
  golden trong các gói trên, `app/lib` chỉ khi bắt buộc (khai báo trong PR).
- **CẤM sửa** (phiên chính giữ): `workers/**`, `web/shield/**`, `packages/{security_sdk,network,storage,ads_iap,core}`,
  `native/**`, `app/lib/src/lam_cung.dart`, `tools/**`, `QUYET_DINH.md`, `docs/ke-hoach/**`, `CLAUDE.md` / `AGENTS.md`,
  pubspec `version` + `phienBanApp` (phiên chính phát hành APK). Cần đổi vùng cấm -> ghi vào phiếu bàn giao, không tự làm.
- **A9a - Thiết bị thiếu phần cứng (Q59)**: domain thuần `NangLucThietBi` (có từ kế / gyro / gia tốc / GPS / camera) +
  `NguonHuong` theo thứ tự: từ kế (fusion A2) > GPS course (tốc độ >= ~1 m/s, độ tin cậy theo `speedAccuracy` / độ dài
  vệt) > Mặt trời / Mặt trăng (phương vị + độ cao NOAA / Meeus thuần Dart, ngắm qua camera A7c hoặc theo bóng) > con quay
  neo hướng (tích phân gyro sau khi neo, ước lượng trôi, nhắc neo lại) > xoay bản đồ thủ công. Mặt la bàn hiện nguồn đang
  dùng + độ tin cậy + hướng dẫn; dẫn đường (`wpNoCompass`) dùng chuỗi nguồn mới; màn "Thiết bị của bạn" liệt kê năng lực.
  Máy cũ / yếu: chế độ nhẹ tự bật (giảm tần số vẽ, tắt hiệu ứng nặng), không đổi minSdk 26. Test: thiên văn so bảng NOAA
  (sai số <= 0,5°), máy trạng thái chọn nguồn, golden màn mới.
- **A9b - Giao diện (Q60)**: token web xanh dương + trắng + gradient trong `design/tokens.json` -> landing + admin (trang
  chủ, tải về, quyền riêng tư, khiếu nại, SOC) light / dark, tương phản AA; app: nút trên Bản đồ (Bắc lên trên, Vị trí của
  tôi, ...) và Điểm mốc (Lưu vị trí, ...) chỉ còn icon (+ nhãn) không nền, vùng chạm >= 48 dp, màu nổi trên nền bản đồ
  (viền / bóng chữ nhẹ khi cần); header mờ khi cuộn (widget dùng chung trong `design_system`, BackdropFilter + lớp phủ,
  tắt blur khi Reduce motion / máy yếu, thay bằng nền đặc). Golden cập nhật có chủ ý.
- **A9c - Rà nhấp nháy toàn bộ app + web**: lỗi đã biết - Vị trí & thông số > thẻ Từ trường: cảnh báo đỏ "Từ trường bất
  thường" bật / tắt liên tục khi đưa nam châm lại gần làm thẻ Thước thuỷ / Mặt trời bên dưới nhảy. Sửa gốc: trễ hai ngưỡng +
  giữ tối thiểu (domain thuần, có test), chỗ dành sẵn cố định, crossfade. Rà mọi thông báo / badge / snackbar / trạng thái
  tải (app + landing + admin) theo cùng mẫu; liệt kê từng chỗ đã sửa trong PR. Test widget mô phỏng tín hiệu dao động:
  không đổi kích thước layout.
- Cổng mỗi phần: `cong.sh day-du` xanh trong worktree · golden không overflow · vi / en · Reduce motion · máy thật M32
  (bản staging - Q57 chặn bản prod khi bật ADB) cho A9a / A9c.
- Bàn giao: mỗi phần merge xong -> `cd ~/projects/app-la-ban && ./agents.sh log '...'` rồi cuối cùng
  `./agents.sh handoff agent-laban-a9 agent-laban "A9 xong" "<tóm tắt + PR + việc cần phiên chính: phát hành APK, deploy web, cập nhật kế hoạch>"`
  (ghi vào LOG của repo chính - phiên chính commit), nhả lock, tóm tắt cho người dùng và gợi ý đóng phiên.
- Phát hành: agent A9 được deploy Pages landing / admin sau merge (preview `--branch` trước nếu đổi header / CSP - không
  được đổi CSP); KHÔNG phát hành APK (phiên chính gom phiên bản).

### S11 - Chặn chế độ Nhà phát triển + khiên web mạnh (phiên chính, Q57, Q58)
- Đọc thêm: SEC-APP, SEC-WEB-SHIELD, SEC-DET; QUYET_DINH Q57, Q58; thẻ S4, S9.
- Làm (app): tín hiệu `DEV_MODE` / `ADB_ENABLED` (freeRASP + `Settings.Global` ADB / Wi-Fi ADB qua `MoiTruong.kt`) kiểm
  lúc mở app, resume, định kỳ; bản prod hiện màn chặn toàn phần (vi / en, hướng dẫn tắt Developer options, mở thẳng
  Cài đặt nhà phát triển, nút Kiểm tra lại), không chạy tiếp tính năng; bản dev / staging chỉ ghi nhận.
- Làm (Worker): luật `DEV_MODE` / `ADB_ENABLED` -> trạng thái `devmode` (không cộng điểm rủi ro, tự gỡ khi tín hiệu sạch
  mới), `/v1/status` trả trạng thái đã ký, các route nghiệp vụ trả 403 `che-do-nha-phat-trien`; cờ Remote Config `chanDevMode`.
- Làm (web): `web/shield` thêm dò CDP / webdriver / headless / debugger timing, gỡ nội dung khỏi DOM khi nghi ngờ (không
  chỉ phủ), màn chặn; admin chỉ nạp dữ liệu sau khiên sạch, Worker chặn API admin cửa sổ ngắn sau `WEB_DEVTOOLS` cùng
  phiên; closed shadow DOM cho bảng nhạy cảm. Không nới CSP, không ảnh hưởng trợ năng.
- Kết quả (03/11, nhánh `phase/s11`): Worker - migration 0014 `devices.dev_mode_at`; app báo `pt=0|1` trong `GET /v1/status`
  (nằm trong chuỗi ký S3 - sửa query -> 401); `CHAN_DEV_MODE=1` (prod) -> mọi route có phiên trả 403 `che-do-nha-phat-trien`,
  trừ `/v1/status`, `/v1/events`, `/v1/app/su-co`, `/v1/device/attest`; `/v1/status.cheDoPhatTrien`; staging `0` chỉ ghi
  nhận. App - `ThietBiPlugin` đọc `Settings.Global` DEVELOPMENT_SETTINGS_ENABLED / ADB_ENABLED / adb_wifi_enabled (không
  quyền, < 1 ms), mở thẳng Tùy chọn nhà phát triển; `GiamSatPhatTrien` kiểm lúc mở, khi resume, mỗi 2 s khi đang chặn, mỗi
  phút khi sạch; `ManChanPhatTrien` (vi / en, liệt kê công tắc đang bật, chỗ dành sẵn cố định, golden + ma trận + trợ năng);
  chỉ bản prod; kill-switch `chanDevMode` trong `tat` Remote Config ký số. Web - khiên: câu lệnh `debugger` mỗi 2 s (bắt
  DevTools kể cả tách cửa sổ và remote debugging qua USB / Wi-Fi từ điện thoại), webdriver / headless -> chặn cả phiên
  (miễn UA bot tìm kiếm / Lighthouse để giữ SEO), GỠ toàn bộ nội dung `body` khỏi DOM khi nghi (trả lại khi sạch), màn chặn
  xanh - trắng, tín hiệu `debugger` / `tu-dong-hoa`; admin chỉ gọi API sau `data-khien-san`, Worker từ chối API admin 10 phút
  (403 `khien-devtools`) sau tín hiệu từ trang admin cùng IP. Rủi ro đã nêu ở Q57: thiết bị pre-launch / reviewer của Play
  bật ADB -> bật kill-switch đúng lúc duyệt.
- Cổng: máy thật M32 bản prod bật ADB -> màn chặn + 403; tắt Developer options -> dùng lại trong <= 5 s; staging không
  chặn; web: mở DevTools -> nội dung bị gỡ khỏi DOM; 0 báo nhầm ở zoom 80-125% / toàn màn hình; `day-du` xanh.
- Kết quả máy thật (04/11, M32 SM-M325FV qua adb.exe Windows): cài APK prod beta.16 đè beta.15 -> bật Developer options + gỡ lỗi
  USB -> màn "Hãy tắt chế độ Nhà phát triển" liệt kê đúng hai công tắc đang bật + nút Mở Tùy chọn nhà phát triển / Kiểm tra
  lại; bản staging `com.tsudev.laban.stg` cùng máy chạy la bàn bình thường (chỉ ghi nhận). CHƯA đo (cần tay người dùng, vì tắt
  Developer options là mất ADB): tắt -> dùng lại <= 5 s; 403 `che-do-nha-phat-trien` trong SOC (đọc D1 prod bị chế độ auto
  chặn). Phát hiện khi viết hướng dẫn duyệt Play: kill-switch `chanDevMode` + `mua-pro` KHÔNG ký được (zod `TINH_NANG` của
  Worker + công cụ `ky-cau-hinh.mjs` chỉ có 5 cờ tính năng) -> sửa ở PR r2b (Q62).

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
