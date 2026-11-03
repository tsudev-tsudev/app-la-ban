# Báo cáo CSP và chuyển Report-Only -> chặn (S8)

Landing gửi hai chính sách mỗi trang HTML (`web/landing/public/_headers`, nonce gắn bởi `web/landing/edge/_worker.ts`):

| Header | Chính sách | Vai trò |
|---|---|---|
| `Content-Security-Policy` | `script-src 'self' 'nonce-X'` | CHẶN. Nonce cho script dò bot Cloudflare chèn vào trang. |
| `Content-Security-Policy-Report-Only` | `script-src 'strict-dynamic' 'nonce-X'` + `require-trusted-types-for 'script'; trusted-types 'none'` | THỬ (CSP-01, CSP-03): chỉ báo cáo. |

Báo cáo (cả hai) -> `POST https://compass-api.tsudev.com/v1/web/csp` -> Analytics Engine dataset `la_ban_su_kien`
(`index1 = 'csp'`, `blob2` chỉ thị, `blob3` thứ bị chặn, `blob4` trang, `blob5` enforce/report, `blob6` origin nguồn,
`blob7` quốc gia). Không lưu URL đầy đủ / query (`workers/api/src/thuan/bao-cao-csp.ts`).

## Đọc báo cáo 7 ngày

```bash
set -a; . ~/.config/la-ban/cf.env; set +a
curl -s "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/analytics_engine/sql" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" --data "
SELECT blob5 AS che_do, blob2 AS chi_thi, blob3 AS bi_chan, blob4 AS trang, SUM(_sample_interval) AS so
FROM la_ban_su_kien WHERE index1 = 'csp' AND timestamp > NOW() - INTERVAL '7' DAY
GROUP BY che_do, chi_thi, bi_chan, trang ORDER BY so DESC LIMIT 50 FORMAT JSON"
```

## Tiêu chí bật chặn (sớm nhất 05/11/2026 - đủ 1 tuần sau deploy 29/10)

1. Không có báo cáo `report` nào từ script CỦA MÌNH (`bi_chan` = `https://compass.tsudev.com` hoặc `inline` trên trang không
   có script Cloudflare).
2. Báo cáo còn lại chỉ đến từ script Cloudflare chèn (`/cdn-cgi/...`, `email-decode`) hoặc tiện ích trình duyệt
   (`chrome-extension`, `moz-extension`) -> xử lý từng nguồn: Email Obfuscation có nonce không; Trusted Types: script
   challenge của Cloudflare gán `innerHTML` cho thẻ script -> GIỮ Trusted Types ở Report-Only nếu còn vi phạm từ nguồn này.
3. Đạt -> chuyển phần `script-src` của Report-Only sang header chặn (giữ `'self'` cho trình duyệt CSP 2), deploy preview
   `./tools/build/deploy-web.sh landing <nhanh>` rồi main; đo bằng `curl -sI` + kiểm headless không lỗi console.

## Ghi chú 29/10 (S9)

Headless Chromium trên compass.tsudev.com thấy vi phạm REPORT-ONLY từ script Cloudflare chèn ở mức zone: Email Obfuscation
(`/cdn-cgi/scripts/.../email-decode.min.js` - nạp bởi script nội tuyến, không mang nonce -> `strict-dynamic` chặn) và sink
Trusted Types của JS detections. Trước khi chuyển `strict-dynamic` sang header chặn: tắt Email Obfuscation cho compass-*
bằng Config Rule (`email_obfuscation: off`, thêm vào `tools/cloudflare` zone.json, người dùng chạy `ap-dung --apply`) - trang
chỉ có email liên hệ dạng văn bản, không cần làm rối. Trusted Types của script Cloudflare: giữ Report-Only nếu còn vi phạm.

## Ghi chú 03/11 (chuẩn bị bật chặn)

Báo cáo 29/10 - 03/11 (AE, theo `blob6` nguồn): KHÔNG có vi phạm từ script của mình.

| Chế độ | Chỉ thị | Bị chặn | Nguồn thật | Số |
|---|---|---|---|---|
| report | `script-src-elem` | `https://compass.tsudev.com` | `email-decode.min.js` của Email Obfuscation (thẻ không nonce) | ~167 |
| report | `require-trusted-types-for` | `trusted-types-sink` | script JS detections Cloudflare (`d.innerHTML`, `a.src`) | ~170 |
| enforce + report | `script-src-elem` | `inline` | trang admin: script nội tuyến Cloudflare chèn, không nonce -> bị chặn, vô hại | 23 |
| enforce + report | `connect-src` | `https://compass-admin.tsudev.com` | admin 30/10 (trước khi xong Access / S7) | 9 |

- 03/11 15:00: Config Rule sẵn có (`tools/cloudflare/zone.json`, rule "tắt Web Analytics (RUM)") thêm
  `email_obfuscation: false` -> `ap-dung.mjs --apply`; trang không còn `email-decode`, email liên hệ dạng văn bản.
- Thử trước ở preview `csp-chan.la-ban-landing.pages.dev`: header CHẶN `script-src 'self' 'strict-dynamic' 'nonce-X'`
  -> Chromium headless 10 trang (vi / en), `data-khien="chat"` (khiên chạy), 0 vi phạm CSP. Lưu ý: `pages.dev` không có
  script Cloudflare chèn ở mức zone -> phải kiểm lại headless trên compass.tsudev.com sau khi deploy main.
- Kiểm headless: `chrome --headless=new --enable-logging=stderr --v=0 --virtual-time-budget=6000 --dump-dom <url>` rồi
  `grep CONSOLE` (thông điệp Trusted Types là `requires 'TrustedHTML'`, KHÔNG chứa "Content Security Policy").
- 05/11: đọc lại bảng - kỳ vọng `script-src-elem https://compass.tsudev.com` về 0 kể từ 03/11 15:00 -> đổi dòng 4
  `web/landing/public/_headers` thành `script-src 'self' 'strict-dynamic'` (worker tự thêm nonce), GIỮ Trusted Types ở
  Report-Only (vi phạm từ script Cloudflare). Cùng PR: bỏ `interest-cohort=()` khỏi `Permissions-Policy` (landing
  `_headers` + admin `worker/tieu-de.ts`) - Chromium báo lỗi console "Unrecognized feature".

## Đã bật chặn 03/11 (người dùng yêu cầu, không chờ 05/11 - PR #58, main d276f27)

- Header CHẶN landing: `script-src 'self' 'strict-dynamic' 'nonce-X'`. Trusted Types GIỮ ở Report-Only (vi phạm từ script
  JS detections Cloudflare). Bỏ `interest-cohort=()` khỏi `Permissions-Policy` landing + admin.
- Đo prod (headless, compass.tsudev.com có script Cloudflare chèn): 10 trang vi / en, khiên chạy, `jsd/main.js` của Cloudflare
  vẫn nạp (do script có nonce tạo), 0 vi phạm chặn, 3 thông điệp Report-Only Trusted Types / trang (Cloudflare).
- Theo dõi: báo cáo `enforce` từ landing trong vài ngày tới - có `script-src-elem` từ origin mình -> rollback bằng cách bỏ
  `'strict-dynamic'` ở dòng 4 `_headers` rồi deploy landing.
- Turnstile (`/khieu-nai/`) chưa có site key nên chưa hiện form; thẻ `<script>` Turnstile được worker gắn nonce như mọi
  thẻ khác -> khi có site key, kiểm headless `/khieu-nai/?ref=...` không vi phạm.

## Theo dõi 03/11 17:15 (sau bật chặn 2 h)

- AE: 0 báo cáo `csp` kể từ 07:28 UTC (cả `enforce` lẫn Trusted Types Report-Only). KHÔNG phải hỏng: header prod còn
  đủ `report-uri` / `report-to csp` / `Reporting-Endpoints` (PR #58 chỉ thêm `'strict-dynamic'`), preflight
  `OPTIONS /v1/web/csp` 204, `POST` `application/reports+json` và `application/csp-report` 204 và có dòng route trong AE.
- Lịch sử 7 ngày: báo cáo đến theo đợt khi có người xem thật (VN, lẻ tẻ US / DE / RO), khoảng trống 5-13 h là bình thường.
- Bẫy: Chromium headless (`--headless=new`, cả khi giữ trang 100 s và đóng êm qua CDP `Browser.close`) KHÔNG gửi báo cáo
  Reporting API - net-log không có request tới `/v1/web/csp`. Kiểm vi phạm bằng `grep CONSOLE`, kiểm đường gửi bằng
  `curl` ở trên hoặc trình duyệt thật (DevTools > Application > Reporting API).
- Hành động: tiếp tục đọc bảng 7 ngày vào 05/11 - 10/11; rollback chỉ khi có `enforce` `script-src-elem` từ origin mình.
