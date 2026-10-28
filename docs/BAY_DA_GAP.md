# Bẫy đã gặp - app "La bàn"

Mỗi bẫy: tiêu đề IN HOA (từ khoá cho `./agents.sh find`), triệu chứng, nguyên nhân, cách tránh, ngày + phase.
Kế thừa từ repo anh em (ban-do-3d / ubnd) - áp dụng vì cùng hạ tầng Cloudflare:

- CSP NONCE + BOT FIGHT MODE: Cloudflare Bot Fight Mode chèn script nội tuyến vào trang HTML -> CSP nonce phải gắn TỪNG lượt
  bằng Pages Function `_middleware`; trang HTML mới phải vào `_routes.json`. (ban-do-3d, 10/2026)
- CSP THAT CHI CO O PAGES: máy dev không có `_headers` -> mọi đổi worker / wasm / bộ nạp phải thử trên preview `*.pages.dev`
  trước khi lên main (ban-do-3d treo production 10 phút 16/10/2026).
- PUSH KHONG DEPLOY: Pages project kiểu tải thẳng - push `main` không phát hành, phải `wrangler pages deploy`.
- PR XEP CHONG: PR merge vào nhánh cơ sở đã chết -> `main` thiếu mã. Mỗi phase PR base `main`, sau merge kiểm `git log origin/main`.
- PKILL -F: `pkill -f <mẫu>` tự khớp dòng lệnh của chính shell -> giết shell (exit 144). Dùng `fuser -k <cổng>/tcp`.
- WORKER KHONG CO import.meta.env: mã dùng chung giữa web và Worker đọc `import.meta.env.X` trần -> Worker chết lúc khởi động.
- TRAI MANG VAO DOI SO: `push(...a)` / `Math.max(...a)` với mảng lớn -> tràn ngăn xếp. Dùng vòng lặp.

## Bẫy của repo này
- NODE 24: repo dùng Node 24 (`.nvmrc`); mặc định máy là Node 20 cho repo khác. Astro 7 / vitest 5 / vite 8 KHÔNG chạy trên 20.
  Luôn `nvm use` (cong.sh và hook tự làm). (N0, 28/10/2026)
- NPM AUDIT 400: npm 10 gọi endpoint audit cũ đã ngừng -> lỗi 400. npm 11 (đi kèm Node 24) chạy được. (N0)
- NPM INSTALL-SCRIPTS: npm 11 chặn postinstall; `esbuild`, `workerd` đã approve theo ĐÚNG phiên bản trong `allowScripts`
  (package.json). Nâng phiên bản -> `npm install-scripts approve <gói>` lại, không thì wrangler / vite hỏng ngầm. (N0)
- NPM EDGESOUT: `npm i -D -w <ws> ...` trên workspace có thể lỗi arborist `edgesOut` -> sửa package.json rồi `npm install` ở gốc. (N0)
- TYPESCRIPT 6: typescript-eslint chỉ hỗ trợ TS < 6.1 -> ghim `~6.0.0`, Renovate đã chặn TS 7. (N0)
- MANG CHAM: tải từ storage.googleapis.com ~20 KB/s (Dart SDK 239 MB, engine Android lớn hơn) -> chạy nền, đừng chờ đồng bộ;
  `tools/flutter` có khoá tải, đừng chạy hai lệnh flutter song song lần đầu. (N0)
- TAI BINARY BI CHAN: tải binary gitleaks / osv-scanner từ GitHub Releases bị chặn quyền -> cổng dùng secretlint + npm audit,
  gitleaks / osv-scanner là tùy chọn nếu người dùng tự cài vào `~/tools/bin`. (N0)
- DART 3.13: very_good_analysis 11 bật `unnecessary_type_name_in_constructor` -> constructor viết `const new(...)`. Sửa nhanh:
  `cd <package> && dart fix --apply` (chạy ở gốc workspace KHÔNG áp). `description:` trong pubspec có dấu `:` phải trong ngoặc kép. (N0)
- PUB WORKSPACE: `flutter pub get` ở gốc; package con không có `pubspec.lock` riêng (xóa nếu `flutter create` sinh ra). (N0)
- AGP 9 RESVALUE: `resValue(...)` trong productFlavors bị tắt mặc định ("custom resource values... disabled") -> tên app theo
  flavor dùng `manifestPlaceholders["appName"]` + `android:label="${appName}"`. Build debug đầu tiên ~5 phút (tải Gradle,
  cài SDK Platform 36 vào `~/tools/android-sdk` dùng chung). (N0)
- WRANGLER AUTOCONFIG: `wrangler pages project create` / `pages deploy` chạy trong `web/*` (hoặc gốc workspace -> lỗi
  "application detection") tự `npm i @astrojs/cloudflare wrangler`, sửa `web/admin/vite.config.ts` + `package.json`, tạo
  `wrangler.jsonc` - không hỏi. Dùng `./tools/build/deploy-web.sh` (gọi từ thư mục tạm); tạo Pages project bằng API. (N2)
- ANALYTICS ENGINE 10089: deploy Worker có `analytics_engine_datasets` lỗi "You need to enable Analytics Engine" cho tới khi
  người dùng bật trên dashboard -> binding SU_KIEN tạm bỏ khỏi wrangler.toml. (N2)
- ZONE DUNG CHUNG: `tsudev.com` có Worker / rule / bản ghi của dự án khác (tsudev, PTSAM...). Không PUT đè ruleset
  entrypoint; thêm rule qua `POST .../rulesets/<id>/rules`, nhận diện rule mình bằng description `la-ban: ...`. HSTS đặt ở
  header từng site, KHÔNG bật HSTS cấp zone (sẽ ép mọi tên miền con). (N2)
- GOLDEN THEME DO: chụp nhiều ô golden bằng `pumpWidget` liên tiếp lên cùng MaterialApp -> theme đang `AnimatedTheme` (200 ms)
  nên ảnh "dark" ra nền sáng. Dùng `chupGolden` của `test_kit` (bơm `SizedBox.shrink()` trước mỗi ô). (A1)
- TRAN CAO 0: RenderFlex tràn với con cao 0 (`SizedBox(width: 700)`) KHÔNG báo lỗi -> test "bắt tràn" phải dùng con có
  chiều cao. (A1)
- FONT THIEU GLYPH: Be Vietnam Pro không có `ȧ ƀ ḗ ƒ ŀ ƥ ẋ ẏ ⟦ ⟧`... -> pseudo-locale chỉ dùng ký tự có trong font (test
  `arb-gia.test.mjs` kiểm cmap), nếu không golden vẽ bằng font dự phòng. (A1)
- RIVERPOD 3 OVERRIDE: kiểu `Override` không còn export từ `flutter_riverpod.dart` -> `import
  'package:flutter_riverpod/misc.dart' show Override;`. (A1)
- NAV ICON TRANG: M3 vẽ icon tab đang chọn bằng `onSecondaryContainer`; ColorScheme tự dựng mà không đặt thì ra trắng trên
  nền cyan nhạt -> LbTheme đặt `secondaryContainer` / `onSecondaryContainer` + `iconTheme` của NavigationBar / Rail. (A1)
- MINIFLARE 5: `new Miniflare({ modules, script, d1Databases... })` báo "Unrecognized keys" - cấu trúc mới là
  `workers: [{ config: ... }]`; giữ dạng cũ và bọc `convertV4MiniflareOptions(...)`. `ratelimits` bắt buộc `namespace_id`,
  `period` chỉ 10 | 60. Test tích hợp: `workers/api/test/tich-hop/mf.ts`. (S1)
- WORKER TYPES VS NODE: không thêm `@types/node` vào `workers/api` (xung đột Request / Response toàn cục với
  workers-types) - test chạy trong Node dùng shim `test/node-shim.d.ts`. (S1)
- ZOD BUNDLE: zod 4 đẩy gói Worker 65 KiB -> 870 KiB; `minify = true` + tách `src/openapi.ts` (z.toJSONSchema) khỏi mã chạy
  -> ~490 KiB / gzip 111 KiB. (S1)
- SQLCIPHER HOOK: `sqlcipher_flutter_libs` / `sqlite3_flutter_libs` đã EOL (0.x+eol) - SQLCipher bật bằng `hooks: user_defines:
  sqlite3: source: sqlcipher` ở pubspec GỐC workspace; hook tải binary (kể cả cho `flutter test` Linux, lần đầu ~40 s).
  Kiểm: `PRAGMA cipher_version`. Khoá sai chỉ lộ ở lệnh đọc ĐẦU TIÊN ("file is not a database"). (A5)
- BUILD_RUNNER ANALYZER: `build_runner` 2.17 cần analyzer 14 nhưng `test` (core) + flutter_test ghim analyzer < 14 -> để
  khoảng `build_runner: ">=2.10.0 <3.0.0"`, `drift_dev` tương tự, pub tự chọn 2.16.1. (A5)
- DRIFT SCHEMAVERSION: `drift_dev make-migrations` chỉ đọc `schemaVersion => <số literal>` ("Could not read schema version")
  -> không trả biến / tham số; test giả lập phiên bản mới bằng lớp con override `schemaVersion`. (A5)
- DRIFT ISNULL: `package:drift/drift.dart` export `isNull` / `isNotNull` trùng matcher của flutter_test -> trong test
  `import 'package:drift/drift.dart' hide isNull, isNotNull;`. (A5)
- TRANG TRONG AM: `LbTrangTrong` trong vùng thấp hơn 48 px (băng an toàn + chữ x2 trên máy nhỏ) ném "negative minimum
  height" -> đã kẹp `max(0, ...)`; widget tự tính chiều cao từ `LayoutBuilder` phải kẹp >= 0. (A5)

- RIVERPOD 3 RETRY: provider lỗi được Riverpod 3 TỰ thử lại (backoff) -> `StreamProvider` báo lỗi "không có cảm biến" cứ
  quay về loading. Lỗi không thể tự hết thì khai `retry: (_, _) => null`. (A2)
- KENH NEN TANG TRONG TEST: widget test gọi MethodChannel thật (plugin không có trên máy test) thì kết quả về bằng event loop
  THẬT, không theo đồng hồ giả -> vòng xoay chờ không dừng, `pumpAndSettle` timed out. Test app override provider dùng nền
  tảng (`huongThu` trong `app/test/ho_tro.dart`, `dungApp(ghiDeThem: ...)`). (A2)
- CAM BIEN HUONG MAN HINH: phương vị phải lấy theo mép trên MÀN HÌNH (`Display.getRotation`), không phải đỉnh máy - xoay
  ngang lệch 90°. Máy dựng đứng thì hình chiếu suy biến -> dùng hướng camera sau (-Z). Xem `tuTheTuQuat`. (A2)
