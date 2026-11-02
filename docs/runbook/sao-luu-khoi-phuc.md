# Runbook - sao lưu, khôi phục, nhật ký bất biến (S10a, MON-01 / MON-03, QUYET_DINH Q48)

Mục tiêu: **RPO <= 24 giờ** (bản mã hoá hằng ngày; Time Travel còn tới mức phút) · **RTO <= 4 giờ** · diễn tập **mỗi quý**.

## Ba lớp

| Lớp | Ở đâu | Giữ | Dùng khi |
|---|---|---|---|
| D1 Time Travel | sẵn có của D1 | 30 ngày, theo phút | lỡ tay xoá / migration hỏng - lớp đầu tiên, nhanh nhất |
| Bản sao lưu hằng ngày | R2 `la-ban-nhat-ky/sao-luu/YYYY-MM-DD.lbsl` | khoá 30 ngày, xoá sau 90 ngày | mất cả CSDL, tài khoản bị chiếm, Time Travel không đủ |
| Nhật ký bất biến | R2 `la-ban-nhat-ky/nhat-ky/YYYY/MM/DD/<số>.ndjson` | khoá 400 ngày (>= 12 tháng) | điều tra, chứng minh audit không bị sửa |

- Bản sao lưu: cron 19:30-19:59 UTC (02:30 giờ VN), một bản / ngày, mã hoá lai AES-256-GCM + RSA-OAEP 4096. Worker chỉ có
  khoá **công khai** (`KHOA_SAO_LUU` trong `wrangler.toml`) -> kẻ chiếm Worker / R2 không đọc được bản sao lưu.
- Bỏ qua bảng tạm: `sessions`, `idempotency_keys`, `admin_challenges`, `admin_sessions` (sau khôi phục người dùng / quản trị
  đăng nhập lại; thiết bị tự xin phiên mới).
- Nhật ký bất biến: cron 5 phút xuất dòng mới của `audit_logs`, `security_events` (IP rút gọn), `rule_hits` thành đoạn nối
  chuỗi băm; đầu chuỗi ở `trang-thai/dau-chuoi.json` (không khoá) kèm **mốc neo audit** (hash cuối + số dòng).
- Khoá bucket + vòng đời là mã: `node tools/cloudflare/r2-khoa.mjs [--apply]`.

## Giữ khoá riêng (QUAN TRỌNG)

- Khoá riêng: `~/.config/la-ban/sao-luu/khoa-rieng.pem` (quyền 600, NGOÀI repo). **Người dùng sao lưu tệp này ra nơi an toàn
  ngoài máy** (USB mã hoá / trình quản lý mật khẩu). Mất khoá riêng = mọi bản sao lưu thành rác (Time Travel vẫn còn).
- Xoay khoá: xem `xoay-khoa.md` mục Sao lưu. Tiêu đề mỗi tệp có `kid` (16 hex đầu SHA-256 SPKI) để chọn đúng khoá cũ.

## Khôi phục thật

1. Thử Time Travel trước: `npx wrangler d1 time-travel info la-ban-prod` -> `npx wrangler d1 time-travel restore la-ban-prod --timestamp <ISO>`.
2. Nếu cần bản hằng ngày: tải tệp (`npx wrangler r2 object get la-ban-nhat-ky/sao-luu/<ngày>.lbsl --remote --file x.lbsl`) ->
   `node tools/sao-luu/sao-luu.mjs giai-ma x.lbsl --ra khoi-phuc.sql` (kiểm băm + số dòng theo tiêu đề).
3. Tạo D1 mới (hoặc làm trống), `wrangler d1 migrations apply <db> --remote`, rồi `wrangler d1 execute <db> --remote --file khoi-phuc.sql`.
   Đổi `database_id` trong `wrangler.toml` nếu là D1 mới -> deploy Worker -> `/v1/health` + SOC đọc được.
4. Ghi sự cố theo `ung-pho-su-co.md`; xoá `khoi-phuc.sql` (có dữ liệu cá nhân) sau khi xong.

## Diễn tập hằng quý (cổng S10)

```bash
node tools/sao-luu/sao-luu.mjs dien-tap --env staging      # hoặc --env prod (chỉ đọc prod, nạp vào D1 tạm)
node tools/sao-luu/sao-luu.mjs kiem-nhat-ky --env prod      # chuỗi đoạn khớp đầu chuỗi
```

Công cụ tải bản mới nhất -> tạo D1 tạm `la-ban-dien-tap` -> migrations -> nạp -> so số dòng từng bảng -> **xoá D1 tạm** -> in
thời gian (RTO đo được). Ghi kết quả vào nhật ký (`./agents.sh log 'Dien tap khoi phuc ...'`).

## Sự cố thường gặp

- Log Worker `sao-luu-loi` / `nhat-ky-loi` -> Telegram gửi tối đa 1 tin / giờ / việc (nếu đã cài bot).
- `dau-chuoi-hong`: đầu chuỗi bị sửa / hỏng. KHÔNG xoá để chạy lại từ đầu. Chạy `kiem-nhat-ky` để biết đoạn cuối hợp lệ, dựng
  lại `trang-thai/dau-chuoi.json` từ đoạn cuối (số, hash_self, con trỏ = rowid lớn nhất mỗi bảng trong đoạn), ghi sự cố.
- `dau-chuoi-doi-giua-chung`: hai lượt cron chồng nhau; lượt sau tự làm tiếp. Lặp lại nhiều lần -> xem thời gian CPU cron.
