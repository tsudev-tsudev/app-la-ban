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
