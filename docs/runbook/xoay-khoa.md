# Runbook - xoay khoá, pin, gỡ chặn (S10a, MON-04)

Nguyên tắc: khoá mới thêm TRƯỚC, khoá cũ gỡ SAU (chồng lấp) -> không làm rơi người dùng. Mọi bước nạp
`set -a; . ~/.config/la-ban/cf.env; set +a` trước wrangler (bẫy WRANGLER OAUTH). Ghi audit / nhật ký mỗi lần xoay.

| Khoá | Ở đâu | Xoay thế nào | Hậu quả nếu lộ |
|---|---|---|---|
| `KHOA_PHIEN` (ES256 ký phiên thiết bị) | `wrangler secret` | secret là MẢNG JWK có `kid`: thêm khoá mới đứng đầu (ký bằng khoá đầu, xác minh mọi khoá), deploy; sau thời hạn phiên gỡ khoá cũ | giả phiên thiết bị |
| `KHOA_URL_KY` (HMAC URL `/v1/tn/*`) | `wrangler secret` | đặt giá trị mới -> URL ký cũ hết hiệu lực ngay (URL sống ngắn) | tải tài nguyên trái phép |
| `KHOA_KY_APP` / `KHOA_KY_WEB` + khoá ngoại tuyến app-1 / web-1 (Ed25519 Remote Config) | `~/.config/la-ban/cau-hinh/` + secret | sinh kid mới (`ky-cau-hinh.mjs khoa --kid app-2`), đưa khoá CÔNG KHAI mới vào app (bản phát hành) / web shield TRƯỚC, khi đa số đã cập nhật mới ký bằng kid mới | đẩy cấu hình giả (tắt tính năng, pin) |
| Pin TLS app | Remote Config `pin` | chọn pin trong 5 CA đóng gói (>= 2) ở SOC four-eyes; CA mới phải theo bản app | app không kết nối được (pin sai) |
| `TELEGRAM_BOT_TOKEN` | secret | @BotFather `/revoke` -> secret mới | gửi tin giả vào nhóm SOC |
| `CF_LISTS_TOKEN`, `CF_AE_TOKEN` | secret | tạo token mới cùng quyền hẹp ở dashboard -> secret mới -> xoá token cũ | sửa danh sách chặn / đọc số liệu |
| `TURNSTILE_SECRET` | secret | Turnstile -> Rotate secret -> secret mới | bỏ qua Turnstile ở form khiếu nại |
| `PLAY_INTEGRITY_SA_JSON` | secret | Cloud Console: tạo key mới cho service account -> secret -> xoá key cũ | giải mã phán quyết Play Integrity |
| Sao lưu `KHOA_SAO_LUU` (RSA-OAEP) | công khai trong `wrangler.toml`, riêng ở `~/.config/la-ban/sao-luu/` | sinh cặp mới, đổi biến công khai, deploy; GIỮ khoá riêng cũ tới khi bản cũ hết hạn (90 ngày) - tiêu đề tệp có `kid` | lộ khoá riêng = đọc được bản sao lưu: xoay ngay, xoá các bản cũ khi hết khoá R2 |
| Khoá upload Android | `~/.config/la-ban/android/` | Play Console -> yêu cầu đặt lại khoá upload (Play App Signing giữ khoá ký ứng dụng) | phát hành bản giả lên Play (cần cả tài khoản Play) |
| `cf.env` (token Cloudflare của agent) | máy dev | dashboard -> Roll token | toàn quyền hạ tầng trong phạm vi token |

## Gỡ chặn

- Một thiết bị / IP: SOC -> Can thiệp -> Thu hồi (lý do + passkey + audit), hoặc duyệt khiếu nại (chấp nhận = gỡ + điểm 0).
- Chặn nhầm hàng loạt do rule: SOC -> Luật -> đưa rule về shadow / khôi phục phiên bản trước (four-eyes), rồi thu hồi các
  enforcement rule đã tạo (lọc theo rule ở Can thiệp). Sau đó theo `ung-pho-su-co.md` bước 5.
- Thiết bị duyệt của Google Play: allow-list ASN có hạn ở SOC -> Danh sách cho phép (R2, không bao giờ tự động chặn).
