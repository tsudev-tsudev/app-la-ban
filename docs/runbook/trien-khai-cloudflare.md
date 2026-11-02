# Runbook - triển khai Cloudflare (N2)

Token: `~/.config/la-ban/cf.env` (`CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_ZONE_ID`), không bao giờ commit.

## Worker `la-ban-api`
```bash
cd workers/api && set -a && . ~/.config/la-ban/cf.env && set +a
npx wrangler d1 migrations apply la-ban-staging --env staging --remote && npm run deploy:staging   # staging trước
npx wrangler d1 migrations apply la-ban-prod --env= --remote && npm run deploy                         # production
curl -s https://compass-api.tsudev.com/v1/health    # build = mã commit vừa deploy
```
`npm run deploy*` gắn `BAN_BUILD` = `git rev-parse --short HEAD` -> deploy SAU khi commit.

Từ S1: migration D1 ở `workers/api/migrations/` (BẤT BIẾN, chạy `migrations apply` TRƯỚC deploy); binding Rate Limiting
`RL_IP` (namespace_id 1001 prod / 1002 staging / 1003 dev, 600 yêu cầu / 60 s / IP); Analytics Engine `SU_KIEN`; cron
`17 19 * * *` (02:17 giờ VN) dọn idempotency hết hạn, sự kiện > 180 ngày, rút gọn IP > 90 ngày. `minify = true`
(zod làm gói ~870 KiB -> ~490 KiB). Tài liệu API: `workers/api/openapi.json` (sinh bằng test, KHÔNG phục vụ công khai). Cấp cao nhất của `wrangler.toml`
là production (`--env=` để wrangler không cảnh báo), `--env dev` chỉ cho `npm run dev` (:8797).

## Web (Pages)
```bash
./tools/build/deploy-web.sh landing            # production (nhánh main)
./tools/build/deploy-web.sh admin phase-s6     # preview https://<id>.la-ban-admin.pages.dev
./tools/build/deploy-web.sh status
```
KHÔNG gọi `wrangler pages ...` trong thư mục `web/*` hay gốc repo: wrangler 4 tự "autoconfig" (cài `@astrojs/cloudflare`,
sửa `vite.config.ts`, tạo `wrangler.jsonc`) - xem bẫy WRANGLER AUTOCONFIG. Script đã gọi từ thư mục tạm.

Admin hiện là `web/admin/public/_worker.js` trả 403 mọi đường dẫn (kể cả `*.pages.dev`). S6 THAY tệp này bằng kiểm JWT
Cloudflare Access trước khi phục vụ SPA.

## Zone `tsudev.com` (DÙNG CHUNG với dự án khác)
```bash
node tools/cloudflare/ap-dung.mjs           # dry-run: in kế hoạch
node tools/cloudflare/ap-dung.mjs --apply   # áp
```
Nguồn: `tools/cloudflare/zone.json`. Script chỉ thêm / sửa mục khai báo, không bao giờ xoá bản ghi hay rule của dự án khác.
Đổi mức TLS tối thiểu / CAA ảnh hưởng MỌI tên miền con của `tsudev.com` - ghi LOG khi đổi.

## Kiểm sau triển khai
```bash
for h in compass compass-api compass-admin compass-cdn compass-status; do echo "## $h"; curl -sI https://$h.tsudev.com/ | grep -iE '^HTTP|strict-transport|x-content-type|x-frame|content-security'; done
curl -s https://compass.tsudev.com/.well-known/security.txt
```
SSL Labs: https://www.ssllabs.com/ssltest/analyze.html?d=compass.tsudev.com (mục tiêu >= A).
