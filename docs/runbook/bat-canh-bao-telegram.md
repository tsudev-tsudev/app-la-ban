# Hướng dẫn bật cảnh báo Telegram cho La bàn (S10, MON-02)

Làm xong các bước dưới đây thì Worker `la-ban-api` sẽ gửi vào nhóm Telegram:

- cảnh báo SOC thật mức high / critical (S7a), mỗi cảnh báo một tin;
- tăng đột biến 5xx / 4xx / từ chối hàng loạt / attestation lỗi / phát lại request (S10a), mỗi loại tối đa 1 tin / giờ;
- việc định kỳ lỗi (sao lưu, nhật ký bất biến...), mỗi việc tối đa 1 tin / giờ.

Tốn khoảng 10 phút. Chi phí 0 đồng (Telegram Bot API và token Cloudflare đều miễn phí).

> **Dùng bot RIÊNG cho La bàn, đừng dùng lại bot của dự án khác.** Repo này không dùng chung bí mật với repo khác
> (CLAUDE.md). Hai dự án dùng chung một token thì một bên bị lộ là cả hai bị lộ, và khi cần thu hồi token (`/revoke`) thì
> cảnh báo của dự án kia cũng tắt theo. Tài khoản Telegram thì dùng chung được, mỗi tài khoản tạo được tới 20 bot.

---

## Bước 1 - Tạo bot mới bằng @BotFather

1. Mở Telegram, tìm **@BotFather** (có dấu tích xanh) và bấm **Start**.
2. Gửi lệnh `/newbot`.
3. Khi được hỏi **name** (tên hiển thị), gửi ví dụ: `La bàn SOC`
4. Khi được hỏi **username** (phải kết thúc bằng `bot`, không trùng ai), gửi ví dụ: `laban_soc_tsudev_bot`
5. BotFather trả về **token** dạng `123456789:AAH...` (khoảng 46 ký tự).
   - Coi token như mật khẩu: KHÔNG dán vào chat, issue, repo hay ảnh chụp màn hình.
   - Chỉ chép tạm vào clipboard để dùng ở Bước 4.
6. (Nên làm) Siết quyền bot, gửi lần lượt cho @BotFather:
   - `/setjoingroups` -> chọn bot -> **Enable** (cho phép vào nhóm ở Bước 2; xong Bước 2 thì quay lại chọn **Disable** để
     không ai kéo được bot vào nhóm lạ).
   - `/setprivacy` -> chọn bot -> **Enable** (bot không đọc tin nhắn thường trong nhóm - nó chỉ cần GỬI tin).

## Bước 2 - Tạo nhóm nhận cảnh báo và thêm bot

1. Telegram -> **New Group** -> đặt tên, ví dụ `La bàn - Cảnh báo SOC`.
2. Thêm thành viên: tìm username của bot (`@laban_soc_tsudev_bot`) và thêm vào.
3. Thêm người trực SOC khác nếu có (sau này thêm cũng được).
4. Gửi một tin bất kỳ vào nhóm, ví dụ `/start@laban_soc_tsudev_bot` (cần có ít nhất một tin để lấy chat id ở Bước 3).

> Muốn nhận riêng cho mình (không cần nhóm): bỏ qua Bước 2, nhắn `/start` trực tiếp cho bot rồi làm Bước 3 - chat id khi
> đó là số DƯƠNG (id tài khoản của bạn).

## Bước 3 - Lấy chat id của nhóm

Chạy trên máy dev (WSL). Lệnh đọc token từ bàn phím nên token không nằm trong lịch sử shell:

```bash
read -rsp 'Token bot: ' TG; echo
curl -s "https://api.telegram.org/bot$TG/getUpdates" | python3 -c '
import json, sys
for u in json.load(sys.stdin).get("result", []):
    m = u.get("message") or u.get("my_chat_member") or {}
    c = m.get("chat", {})
    if c:
        print(c.get("id"), c.get("type"), c.get("title") or c.get("username"))
' | sort -u
```

- Kết quả ví dụ: `-1002345678901 supergroup La bàn - Cảnh báo SOC` -> chat id là **`-1002345678901`** (số ÂM, giữ cả dấu `-`).
- Không thấy dòng nào: gửi thêm một tin vào nhóm rồi chạy lại. Nếu vẫn trống, có thể bot đang có webhook (bot cũ dùng
  lại) - chạy `curl -s "https://api.telegram.org/bot$TG/deleteWebhook"` rồi thử lại. Bot mới tạo ở Bước 1 thì không có webhook.

Thử gửi một tin trước khi đưa lên Cloudflare:

```bash
CHAT=-1002345678901   # thay bằng chat id vừa lấy
curl -s "https://api.telegram.org/bot$TG/sendMessage" -d chat_id="$CHAT" -d text="La bàn: thử kênh cảnh báo" | head -c 120; echo
```

Thấy `{"ok":true,...` và tin hiện trong nhóm là đúng.

## Bước 4 - Đặt bí mật cho Worker (staging + prod)

Luôn nạp token Cloudflare của repo trước (bẫy WRANGLER OAUTH: `source` trơn KHÔNG export biến, wrangler sẽ rơi về OAuth
của tài khoản khác và tạo Worker rác):

```bash
cd ~/projects/app-la-ban/workers/api
set -a; . ~/.config/la-ban/cf.env; set +a
source ~/.nvm/nvm.sh && nvm use

# wrangler đọc giá trị từ stdin -> không hiện trên màn hình, không vào lịch sử shell
printf '%s' "$TG"   | npx wrangler secret put TELEGRAM_BOT_TOKEN --env staging
printf '%s' "$CHAT" | npx wrangler secret put TELEGRAM_CHAT_ID   --env staging
printf '%s' "$TG"   | npx wrangler secret put TELEGRAM_BOT_TOKEN
printf '%s' "$CHAT" | npx wrangler secret put TELEGRAM_CHAT_ID
```

- Không có `--env` = **prod** (`la-ban-api`); `--env staging` = `la-ban-api-staging`.
- Muốn tách tin staging và prod: tạo nhóm thứ hai cho staging và dùng chat id đó cho hai lệnh `--env staging` (cùng một
  bot cũng được). Tin đã có sẵn tiền tố `[staging]` / `[prod]`.
- Kiểm tra: `npx wrangler secret list` và `npx wrangler secret list --env staging` phải có cả hai tên.

## Bước 5 - Token đọc số liệu cho cảnh báo tăng đột biến (`CF_AE_TOKEN`)

Cảnh báo SOC ở Bước 4 đã chạy được rồi. Riêng phần tăng đột biến cần đọc Analytics Engine, nên cần một token **chỉ đọc**:

1. Mở https://dash.cloudflare.com/profile/api-tokens -> **Create Token** -> **Create Custom Token**.
2. Token name: `la-ban-ae-doc`.
3. Permissions: **Account** · **Account Analytics** · **Read** (chỉ một dòng này, không thêm quyền nào khác).
4. Account Resources: **Include** · chọn đúng tài khoản của La bàn (id bắt đầu `9541f44e`).
5. Client IP Address Filtering: để trống (Worker gọi từ nhiều IP của Cloudflare). TTL: để trống, hoặc đặt 1 năm và ghi
   lịch xoay theo `xoay-khoa.md`.
6. **Continue to summary** -> **Create Token** -> chép token (chỉ hiện một lần).
7. Đặt cho cả hai môi trường:

```bash
read -rsp 'Token AE: ' AE; echo
printf '%s' "$AE" | npx wrangler secret put CF_AE_TOKEN --env staging
printf '%s' "$AE" | npx wrangler secret put CF_AE_TOKEN
unset TG CHAT AE
```

## Bước 6 - Thử từ SOC (đo "cảnh báo thử tới < 2 phút")

1. Mở https://compass-admin.tsudev.com -> đăng nhập (Access + passkey).
2. **Tài khoản** -> **Gửi tin thử Telegram** (cần quyền Super Admin + xác nhận passkey).
3. Tin phải tới nhóm trong vài giây. Ghi lại giờ bấm và giờ nhận rồi báo agent để ghi vào cổng S10 (mục tiêu < 2 phút).
4. Phần đột biến chạy theo cron 5 phút. Workers Logs (dashboard -> Workers -> `la-ban-api` -> Logs) phải có dòng
   `dot-bien` với `{"dotBien":[]}` thay vì `{"bo":"thieu-cau-hinh"}`, nghĩa là đã đọc được số liệu.

## Khi có sự cố

| Triệu chứng | Cách xử lý |
|---|---|
| SOC báo `chua-cau-hinh-telegram` | Thiếu một trong hai secret ở môi trường đó - làm lại Bước 4 |
| Bấm thử không có tin | Bot chưa ở trong nhóm, hoặc sai chat id (nhóm nâng lên supergroup thì id đổi sang `-100...`) - làm lại Bước 3 |
| Log `dot-bien-loi` kèm `ae-401` / `ae-403` | Token AE sai hoặc thiếu quyền Account Analytics Read - làm lại Bước 5 |
| Lộ token bot | @BotFather -> `/revoke` -> chọn bot -> lấy token mới -> làm lại Bước 4 (xem `xoay-khoa.md`) |
| Muốn tạm tắt | `npx wrangler secret delete TELEGRAM_CHAT_ID [--env staging]` - Worker tự bỏ qua khi thiếu |
