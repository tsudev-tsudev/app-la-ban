# CLAUDE.md - app "La bàn" (Smart Compass) · `compass.tsudev.com`

Repo ĐỘC LẬP `~/projects/app-la-ban` (GitHub private, tên chốt ở N0). Không dùng chung mã, dữ liệu, bí mật, Worker, D1, Pages
project hay cổng dev với các repo khác trên máy (`ubnd`, `ban-do-3d`, `ttpvhcc`, `wedding-sumy`, ...). ĐỪNG sửa tệp ngoài thư mục này.

> Tệp này là NGỮ CẢNH TĨNH, nạp đầu mọi phiên. Đừng sửa giữa phiên. `AGENTS.md` là BẢN SAO cho công cụ agent khác - sửa tệp
> này rồi chạy `./agents.sh sync-agents-md` (cổng phát hành kiểm tra hai tệp trùng nhau).

## Sản phẩm (tóm tắt - chi tiết ở kế hoạch)
- App la bàn Flutter cho Android + iOS, song ngữ vi/en, màu tươi sáng (Electric Cyan / Royal Blue / Sunrise Coral), logo + bộ icon riêng.
- Nền tảng bảo mật: Security SDK trong app (RASP + attestation + ký request) -> API Worker -> Threat Engine -> Admin SOC giám sát
  thiết bị / IP, can thiệp thiết bị vi phạm. Web (landing + admin) có lớp khiên chống sao chép / DevTools + CSP nghiêm.
- Phát hành Google Play + App Store; quảng cáo / IAP CHỈ bật sau Release Gate (phase M1).

## Stack (chốt ở QUYET_DINH.md - đổi phải ghi lại ở đó)
- App: Flutter stable (ghim commit ở `.flutter-version`, SDK tại `~/tools/flutter`), Dart 3, Impeller, Riverpod, go_router, Drift + SQLCipher, dio, ARB i18n,
  pub workspace (gốc repo). Native: Kotlin (+ NDK C++ cho kiểm tra bảo mật) / Swift.
- Máy chủ: Cloudflare - Worker `la-ban-api` (Hono + zod, TypeScript) · D1 `la-ban-prod` (SIN) · Durable Objects (nonce, rate, realtime SOC)
  · KV (cấu hình ký số) · R2 (tile bản đồ, bản sao lưu, log bất biến) · Analytics Engine (chuỗi thời gian sự kiện).
- Web: Pages `la-ban-landing` (Astro tĩnh, vi/en) · Pages `la-ban-admin` (Vite + React + TS SPA) sau Cloudflare Access.
- Không có CI GitHub Actions (billing) - cổng DUY NHẤT là `./tools/kiem-tra/cong.sh` chạy ở máy. Build iOS: xem QUYET_DINH Q6.

## Cấu trúc thư mục (dựng ở N0 - phase sau chỉ thêm đúng chỗ)
```
app/                    Flutter app (entry, DI, routing, flavors dev/staging/prod)
packages/               core · design_system · sensors · compass_feature · location_feature · waypoint_feature · map_feature
                        ar_feature · settings_feature · security_sdk · network · storage · i18n · ads_iap · quyen_loi (Pro + Play Billing)
native/                 android/ (Kotlin + cpp/) · ios/ (Swift) - mã nền tảng của plugin nội bộ
workers/api/            Worker la-ban-api: src/ (routes, threat/, attest/, admin/) · migrations/ (D1, BẤT BIẾN) · wrangler.toml
web/landing/            Astro - compass.tsudev.com
web/admin/              Vite React - SOC dashboard
web/shield/             gói @laban/web-shield (chống sao chép / DevTools) dùng chung cho landing + admin
design/                 tokens.json (nguồn duy nhất) · logo/ · icons/ · store/ · LICENSES
tools/                  kiem-tra/ (cổng) · cloudflare/ (WAF / DNS as code) · thu/ (red-team, tải) · build/
docs/ke-hoach/          KE_HOACH_TONG_THE_LA_BAN.md (phase) · KE_HOACH_BAO_MAT_CHONG_XAM_NHAP.md (yêu cầu bảo mật)
docs/adr/  docs/runbook/  docs/BAY_DA_GAP.md
2026*.md (gốc repo)     tài liệu gốc người dùng - KHÔNG sửa, KHÔNG commit (đã .gitignore)
```

## Cổng dev (không đụng cổng repo khác: 3008 ubnd, 3010 ban-do-3d, 3000-3006/8080 dùng chung)
- Admin `npm run dev -w web/admin` -> :3030 · Landing -> :3031 · Worker `wrangler dev` -> :8797 (inspector :9239).
- Tắt: `fuser -k 3030/tcp` (KHÔNG `pkill -f` - tự giết shell).

## Chạy và kiểm
- `./tools/kiem-tra/cong.sh nhanh` = lint + test CHỈ gói đã đổi (so với `main`: package Dart, workspace npm). Dùng giữa phase.
- `./tools/kiem-tra/cong.sh day-du` = toàn bộ: analyze 0 warning · test · golden · tsc · vitest · build web · vệ sinh bản build
  (không comment / console / sourcemap / LICENSE.txt) · gitleaks · đồng bộ AGENTS.md. Bắt buộc trước merge.
- Golden test chạy trên Linux (font cố định trong `design/fonts`), cập nhật bằng `--update-goldens` CHỈ khi đổi UI có chủ ý.
- Máy không card đồ hoạ, WSL2 thường không có KVM -> giả lập Android chậm/không chạy: thử cảm biến trên ĐIỆN THOẠI THẬT
  (`adb` qua Wi-Fi), đừng kết luận FPS từ giả lập.

## Phát hành (agent tự làm khi cổng xanh, trừ khi QUYET_DINH ghi khác)
- Nhánh `phase/<mã>` -> PR base `main` (KHÔNG xếp chồng PR) -> squash merge -> kiểm `git log origin/main`.
- Worker: `cd workers/api && npx wrangler d1 migrations apply la-ban-prod --remote && npx wrangler deploy` (staging trước: `--env staging`).
- Web: `npx wrangler pages deploy web/<x>/dist --project-name la-ban-<x> --branch main`. Đổi CSP / worker / wasm -> deploy
  `--branch <nhanh>` và thử `https://<id>.la-ban-<x>.pages.dev` TRƯỚC (CSP thật chỉ có ở Pages).
- Đo bản đang phục vụ bằng chuỗi CHỈ có ở bản mới (`curl -sL`), đừng tin mã 200.
- App store: KHÔNG tự đẩy lên store; agent build + ký bản internal, người dùng bấm phát hành (R2/R4).

## Luật
- Gạch nối CHỈ ASCII `-`. Conventional Commits, tiêu đề <= 95 ký tự.
- Server là nguồn tin cậy cuối cùng: kiểm tra phía client chỉ là TÍN HIỆU; quyết định chặn nằm ở Worker / Threat Engine.
- Không bí mật dài hạn trong app / web / repo (chỉ khóa công khai, pin hash). Bí mật: `wrangler secret`, `.dev.vars` (gitignore).
- Không định danh phần cứng cố định (IMEI, serial, MAC, Android ID dùng làm khóa chính, IDFA khi chưa có ATT).
- Comment: thoải mái ở mã nguồn, nhưng KHÔNG chứa bí mật / đường dẫn nội bộ / logic bypass. Bản build web phải sạch 100% comment.
- Migration D1 và Drift BẤT BIẾN: tệp mới, chỉ mở rộng (expand -> contract qua 2 bản).
- CSP: không `unsafe-inline` / `unsafe-eval`; không nới CSP để chữa lỗi.
- Logic mới đặt trong hàm THUẦN có test (Dart: `packages/*/lib/src/domain`, TS: `workers/api/src/thuan/`).
- Mọi chuỗi giao diện qua ARB / i18n vi + en; không nối chuỗi.
- Không thêm SDK bên thứ ba ngoài danh sách QUYET_DINH mà không hỏi người dùng (ảnh hưởng Data Safety / Privacy Manifest).

## Điều phối (một repo, có thể nhiều agent)
Đầu phiên: `./agents.sh brief` -> `./agents.sh inbox agent-laban` -> `./agents.sh runners` -> `git log --oneline -10` ->
`git status --short`. Chi tiết: `AGENTS_KICKOFF.md`. Bẫy đã gặp: `docs/BAY_DA_GAP.md`.
