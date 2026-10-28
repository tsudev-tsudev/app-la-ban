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
