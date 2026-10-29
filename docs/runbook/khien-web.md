# Runbook - khiên web (S9, SEC-WEB-SHIELD)

Khiên là lớp RĂN ĐE + thu tín hiệu. Lớp bảo vệ chính vẫn là SH-07: Worker không gửi dữ liệu nhạy cảm xuống client khi
chưa đủ quyền. Đừng dựa vào khiên để giấu thứ gì.

## Thành phần

| Phần | Ở đâu | Ghi chú |
|---|---|---|
| Gói `@laban/web-shield` | `web/shield/src` | hàm thuần (mức, phím, dò công cụ, cấu hình ký số, watermark) + lớp DOM `khien.ts` |
| Bản chạy `/js/khien.js` | `web/shield/dong-goi.mjs` | IIFE ~5 KB, terser làm rối (SH-06), tệp NGOÀI -> nhận nonce CSP, không eval |
| CSS | `@laban/web-shield/khien.css` | `user-select`, `@media print` ẩn nội dung, lớp phủ `.khien-phu`, `[data-nhay-cam]` |
| Cấu hình mức | KV `CAU_HINH` khoá `web-khien` | gói Ed25519 ký NGOÀI máy chủ, `GET /v1/web/cau-hinh` trả nguyên văn |
| Tín hiệu | `POST /v1/web/signals` | `WEB_DEVTOOLS` theo IP -> Threat Engine (`security_events`, Analytics Engine) |
| URL ký | `GET /v1/tn/<khoá>?het=&ky=` | R2 `CDN` tiền tố `ky/`, HMAC `KHOA_URL_KY`, hạn <= 7 ngày, chặn hotlink |
| Watermark | `web/admin/src/khien/` | email (Access `get-identity`) + giờ UTC+7, đổi mỗi phút |

## Mức

| Mức | Hành vi |
|---|---|
| `tat` | tắt hết (kể cả ẩn khi in) |
| `nhe` | chặn phím tắt xem nguồn / lưu / in / công cụ, kéo ảnh, ẩn khi in |
| `chat` | `nhe` + chặn menu chuột phải, chọn / sao chép / cắt nội dung trình bày, dò công cụ nhà phát triển |

Mặc định và mọi lỗi (mạng, sai chữ ký, hết hạn, trình duyệt thiếu Ed25519 WebCrypto) -> `chat`. Ô nhập liệu và phần tử
`[data-cho-chon]` (mã SHA-256, lệnh mẫu) luôn chọn / sao chép được. Ctrl+C / Ctrl+V / Ctrl+A không bị chặn.

## Đổi mức (ký số)

Khoá bí mật: `~/.config/la-ban/cau-hinh/web-1.pem` (quyền 600, NGOÀI repo). Mất khoá -> sinh kid mới (mục Xoay khoá).

```bash
# staging trước, rồi prod; gói hết hạn sau --ngay ngày (mặc định 90) -> hết hạn thì trang tự về chat
node tools/cau-hinh/ky-cau-hinh.mjs dua-len --env staging --landing chat --admin chat
node tools/cau-hinh/ky-cau-hinh.mjs dua-len --env prod --landing chat --admin chat
curl -s https://compass-api.tsudev.com/v1/web/cau-hinh   # gói mới (cache KV + trình duyệt <= 5 phút)
```

Lịch: KÝ LẠI trước khi gói hết hạn (gói ký 29/10/2026 hết hạn 27/01/2027). Hết hạn không làm hỏng trang, chỉ về `chat`.

## Xoay khoá

1. `node tools/cau-hinh/ky-cau-hinh.mjs khoa --kid web-2` -> in khoá công khai.
2. Thêm `'web-2': '<khoá>'` vào `web/shield/src/khoa.ts`, build + deploy landing (+ admin).
3. `dua-len --kid web-2 ...` cho staging + prod.
4. Bản sau: bỏ `web-1` khỏi `khoa.ts`, xoá tệp pem cũ.

## Tín hiệu và dò công cụ (SH-03)

- Tín hiệu: công cụ GẮN cạnh / đáy (ước lượng mức phóng to từ chiều ngang -> phần thanh trình duyệt dọc phải nằm trong
  khoảng hợp lý), giữ >= 2 lần đo 1 giây; phím F12 / Ctrl+Shift+I/J/C (+2 điểm), chuột phải (+1), ngưỡng 4, giảm 1 / 10 s.
  Màn cảm ứng bỏ qua tín hiệu kích thước. Công cụ tách cửa sổ riêng không đo được - chấp nhận.
- Khi nghi: phủ màn tối (`role=alertdialog`), ẩn `[data-nhay-cam]`, gửi MỘT tín hiệu / lượt tải trang. Đóng công cụ ->
  tự gỡ phủ sau lần đo kế.
- Worker: chỉ nhận Origin landing / admin, 10 / phút / IP, nén 60 s / IP / isolate. Sự kiện không có thiết bị nên không cộng
  điểm thiết bị; dùng cho SOC (S10) và rule theo IP nếu cần (chưa có rule - thêm qua migration, shadow trước).

Xem số liệu (Analytics Engine, dataset `la_ban_su_kien`):

```sql
SELECT blob5 AS quoc_gia, SUM(_sample_interval) AS so
FROM la_ban_su_kien WHERE index1 = 'WEB_DEVTOOLS' AND timestamp > NOW() - INTERVAL '7' DAY
GROUP BY quoc_gia ORDER BY so DESC
```

## URL ký (SH-05)

- Bí mật: `cd workers/api && openssl rand -base64 32 | npx wrangler secret put KHOA_URL_KY` (prod) và `--env staging`.
  Thiếu bí mật -> route trả 503.
- Tải vật lên: `npx wrangler r2 object put la-ban-cdn/ky/<khoá> --file <tệp> --content-type <mime> --remote`.
- Sinh URL: `kyUrl(bimat, khoa, het)` trong `workers/api/src/thuan/url-ky.ts` (admin API S6 dùng hàm này).
- 403 sai chữ ký / hotlink, 410 hết hạn, 404 không có vật. Cache trình duyệt `private`, không quá hạn URL, trần 1 giờ.

## Kiểm sau deploy

- `curl -sL https://compass.tsudev.com/js/khien.js | head -c 200` có nội dung (không phải HTML 404).
- Header CSP landing có `connect-src 'self' https://compass-api.tsudev.com`.
- Chromium headless: `document.documentElement.dataset.khien` = mức trong gói, 0 vi phạm CSP enforce.
- `node tools/kiem-tra/ve-sinh-ban-build.mjs web/landing/dist web/admin/dist` xanh.
