# PHIẾU YÊU CẦU SEC1 - Nhận token/secret qua clipboard (app-la-ban)

- **Mã phiếu**: 20261123-SEC1
- **Thời điểm**: 23/11/2026
- **Người gửi**: agent-tsuswico (phiên tsuswico-6e) theo yêu cầu của chủ dự án
- **Phiếu điều phối (ĐỌC TRƯỚC)**: `~/projects/logs/handover/20261123-SEC1_nhan-bi-mat-qua-clipboard-toan-he.md`
- **Trạng thái**: ĐÓNG (23/11/2026, phiên agent-laban STD50/AV1/SEC1)

## 1. Quy tắc áp dụng ngay cho agent của repo này

- KHÔNG đề nghị chủ dự án dán token/secret vào chat, tệp hay lệnh `!`. Lỡ dán vào chat ⇒ coi là đã lộ, đề nghị thay.
- Nhận bí mật: chạy `tsu-nhan-bi-mat ...` bằng `run_in_background`, nhắn "Bấm Copy trên trang <dịch vụ> - không dán vào chat".
  Ưu tiên `--stdout | <lệnh đích>`; cần giữ ⇒ `--luu ~/.config/tsudev/<ten>.env` (chmod 600, ngoài repo).
- KHÔNG in giá trị bí mật (`cat .env`, `sed`…); chỉ in tên biến/độ dài/kết quả kiểm tra.
- Cần người dán vào dashboard ⇒ `tsu-nhan-bi-mat --dua-vao-clipboard <tệp>` rồi `--xoa-lich-su <tệp>`.
- Lịch sử Win+V trên máy đang BẬT ⇒ luôn để công cụ xoá mục khỏi lịch sử.

## 2. Việc cần làm

1. Rà tài liệu/hướng dẫn của repo (README thiết lập, `docs/`, `logs/STATE.md`, phiếu cũ còn mở) - chỗ nào bảo dán token
   vào chat/.env bằng tay ⇒ sửa theo phiếu điều phối mục 2-3.
2. Kiểm `.gitignore` có `.env*` (trừ `.env.example`); gitleaks/push protection theo SECURITY_BASELINE.
3. Liệt kê TÊN các bí mật repo dùng + nơi lưu (GitHub Actions secret / Cloudflare / Vercel / Render / `~/.config/tsudev/`)
   + phạm vi quyền vào mục 3 dưới (không ghi giá trị). Cái nào từng lộ trong chat/log ⇒ báo chủ dự án thay.
4. Ghi AKB của repo "áp dụng SEC1", đổi Trạng thái → ĐÓNG.

## 3. Bí mật của repo (agent điền - CHỈ TÊN)

| Tên | Nơi lưu | Phạm vi | Ghi chú |
| --- | --- | --- | --- |
| `KHOA_PHIEN`, `KHOA_URL_KY`, `KHOA_KY_APP`, `KHOA_KY_WEB`, `KHOA_QUYEN_LOI` | `wrangler secret` Worker `la-ban-api` + `la-ban-api-staging`; bản ngoại tuyến `~/.config/la-ban/cau-hinh/`, `~/.config/la-ban/quyen-loi/` (600) | ký phiên / URL / Remote Config, mã hoá purchase token | xoay theo `docs/runbook/xoay-khoa.md` |
| `PLAY_INTEGRITY_SA_JSON` | `wrangler secret` (prod + staging); `~/.config/la-ban/google/` | service account Play Integrity + Android Publisher (đọc) | |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` | `wrangler secret` (prod + staging) | gửi cảnh báo SOC vào nhóm | |
| `CF_AE_TOKEN` | `wrangler secret` (prod + staging) | Account Analytics Read | |
| `CF_LISTS_TOKEN` | `wrangler secret` (CHỈ prod) | sửa IP Lists | |
| `TURNSTILE_SECRET` | `wrangler secret` (CHỈ staging - secret thử) | form khiếu nại | prod CHƯA đặt (việc cũ: site key Turnstile) |
| `CLOUDFLARE_API_TOKEN` (+ account id) | `~/.config/la-ban/cf.env` (600) | Workers / D1 / R2 / Pages của tài khoản La bàn | nạp `set -a; . tệp; set +a` |
| Khoá upload Android (`upload.jks` + `key.properties`) | `~/.config/la-ban/android/` | ký APK/AAB | |
| Khoá sao lưu (`khoa-rieng.pem`) | `~/.config/la-ban/sao-luu/` | giải mã bản sao lưu R2 | |
| GitHub Actions secret | KHÔNG có (`gh secret list` rỗng) | - | repo không chạy CI GitHub |
| (dùng chung hệ) khoá VirusTotal | `~/.config/tsudev/virustotal.env` | API công khai VT | ⚠ 23/11 bị in ra log phiên agent (tệp chỉ chứa khoá trần, lệnh `. tệp` in giá trị trong thông báo lỗi bash) -> ĐỀ NGHỊ chủ dự án thay khoá VT |

## Kết quả xử lý (23/11/2026)

1. Rà tài liệu: `docs/runbook/bat-canh-bao-telegram.md` đổi `read -rsp` sang `tsu-nhan-bi-mat --stdout`; `docs/runbook/chuan-bi-s2-s6.md` đã có câu "không dán khoá vào chat"; các lệnh `wrangler secret put` khác đọc từ tệp ngoài repo hoặc stdin (không dán).
2. `.gitignore` có `.env` + `.env.*` (không có `.env.example` trong repo); push protection + secret scanning bật từ 09/11; cổng `cong.sh` chạy gitleaks (khi có lệnh) + grep JWT.
3. Bảng trên - chưa có bí mật nào của repo xuất hiện trong chat. Ngoại lệ: khoá VirusTotal dùng chung (dòng cuối).
4. AKB app-la-ban: "áp dụng SEC1".
