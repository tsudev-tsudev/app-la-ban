# Admin SOC - đăng nhập, cấp quyền, vận hành (S6)

`https://compass-admin.tsudev.com` (prod) · `https://staging.la-ban-admin.pages.dev` (staging, dữ liệu D1 staging).

## Ba lớp xác thực (đều kiểm ở server)

| Lớp | Ở đâu | Hỏng thì |
|---|---|---|
| 1. Cloudflare Access (email OTP; Google khi có OAuth client) | edge Cloudflare + Pages `_worker` + Worker kiểm lại JWT (iss, aud, chữ ký JWKS) | 403 trang / 401 API |
| 2. Vai trò D1 `admin_users` (viewer · analyst · responder · security_admin · super_admin) | Worker `src/admin/xac-thuc.ts` | 403 `khong-co-vai-tro` |
| 3. Passkey WebAuthn (MFA của SOC) -> phiên `__Host-soc` | Worker; nhàn rỗi 15 phút, tuyệt đối 8 giờ; step-up 5 phút cho thao tác nhạy cảm | 401 `can-phien` / `can-step-up` |

Viewer chỉ thấy dải IP (/24, /48) và không mở được chi tiết thiết bị; xem chi tiết ghi audit `xem:thiet-bi`.

## Lần đầu (người dùng làm, chế độ auto của agent không được đổi Access)

1. Token `la-ban-agent` cần thêm quyền: **Access: Apps and Policies Edit**, **Access: Service Tokens Edit**,
   **Access: Organizations, Identity Providers, and Groups Edit** (dash -> My Profile -> API Tokens -> Edit).
2. Email quản trị (NGOÀI repo): `~/.config/la-ban/cau-hinh/admin-emails.txt`, mỗi dòng một email.
3. Áp cấu hình: `node tools/cloudflare/access.mjs` (xem) rồi `node tools/cloudflare/access.mjs --apply`.
   Script in `AUD=...` và `SERVICE_TOKEN_CN=...`; bí mật service token lưu `~/.config/la-ban/cau-hinh/access-svc-e2e.json` (600).
4. Agent: đặt `ACCESS_AUD` (prod + staging) và `ACCESS_DICH_VU` (staging) trong `workers/api/wrangler.toml`, deploy Worker,
   thêm Super Admin vào D1:

```bash
cd workers/api && npx wrangler d1 execute la-ban-prod --remote --command \
  "INSERT INTO admin_users (id, email, role, created_at, created_by) VALUES (lower(hex(randomblob(16))), '<email đã chuẩn hoá: Gmail bỏ dấu chấm>', 'super_admin', unixepoch()*1000, 'runbook')"
```

5. Mở trang SOC -> nhập email -> mã OTP gửi về mail -> **Tạo passkey** (vân tay / Windows Hello / khoá bảo mật).
   Passkey gắn với tên miền: passkey tạo ở prod không dùng được ở staging và ngược lại.

## Không nhận được mã OTP

Access KHÔNG gửi mã cho email không khớp policy nhưng vẫn hiện "A code has been emailed" (chống dò email). Hay gặp nhất:
gõ Gmail khác dạng trong policy (`devnguyen...` vs `dev.nguyen...`). `access.mjs` đã đưa cả dạng ghi trong tệp lẫn dạng
không chấm vào policy; dạng chấm khác thì thêm dòng vào `admin-emails.txt` rồi `--apply`. Worker tự chuẩn hoá Gmail
(`chuanHoaEmail`) nên mọi dạng đều ra cùng một quản trị viên. Kiểm thêm thư mục Spam / Promotions; người gửi
`noreply@notify.cloudflare.com`. Muốn bỏ hẳn OTP email: thêm IdP Google (cần OAuth client).

## Thêm người

Super Admin vào **Quản trị viên** -> email + vai trò (hỏi passkey lại nếu quá 5 phút) + thêm email vào
`admin-emails.txt` rồi chạy lại `access.mjs --apply`. Thiếu một trong hai lớp thì người đó không vào được.
Vô hiệu hoá = thu hồi ngay mọi phiên SOC của người đó; Access vẫn cho vào tới hết phiên Access (8 giờ) nhưng bị 403.

## Mất passkey / bị khoá ngoài

Super Admin khác xoá passkey không có giao diện (S7). Tạm thời (ghi audit thủ công vào LOG):

```bash
npx wrangler d1 execute la-ban-prod --remote --command "DELETE FROM admin_passkeys WHERE email = '<email>'"
```

Lần đăng nhập sau người đó được tạo passkey mới (chỉ cần Access).

## Thử e2e staging bằng service token (không có người)

Header `CF-Access-Client-Id` / `CF-Access-Client-Secret` từ `access-svc-e2e.json`; danh tính trong SOC là
`svc:<client_id>` - chỉ staging nhận (`ACCESS_DICH_VU`), cần dòng `admin_users` ở D1 staging. Passkey được giả lập
bằng khoá phần mềm trong script thử (`tools/thu/soc-e2e.mjs`). Prod KHÔNG bao giờ đặt `ACCESS_DICH_VU`.

## Trung tâm cảnh báo + Telegram (S7a)

- Vòng đời: `open` -> `ack` (Nhận xử lý / Đã nhận) -> `closed` (bắt buộc kết luận: vi phạm thật / báo nhầm / vô hại) ->
  có thể `Mở lại`. Cảnh báo mới cùng (rule, nhóm) khi đang open / ack được GỘP (tăng số lần), không sinh dòng mới.
- Thao tác hàng loạt tối đa 100 / lần; mọi thay đổi vào `alert_notes` (dòng thời gian) + audit chuỗi băm.
- Bật Telegram: tạo bot với @BotFather -> lấy token; thêm bot vào nhóm SOC -> lấy chat id (số âm của nhóm). Rồi:
  `cd workers/api && npx wrangler secret put TELEGRAM_BOT_TOKEN [--env staging]` và `... TELEGRAM_CHAT_ID`. Thử ở
  Tài khoản -> "Gửi tin thử Telegram" (Super Admin, cần passkey). Chỉ cảnh báo THẬT (không shadow) mức high / critical, một
  lần mỗi cảnh báo; tin chỉ có rule, mức, dải IP / 8 ký tự device id và liên kết `#/canh-bao/<id>`.

## Thuỷ vân + mã dấu vết (S7a, QUYET_DINH Q39)

- Mọi màn dữ liệu có thuỷ vân: email · giờ VN · `#<mã 8 hex>`; người xem chỉ chọn Nhẹ / Chuẩn (Tài khoản -> Hiển thị),
  không tắt được. Rời cửa sổ / ẩn tab / in -> tự đậm lên; tuỳ chọn che mờ dữ liệu khi rời cửa sổ.
- Ảnh chụp lọt ra ngoài: đọc mã ở nhãn (hoặc tăng tương phản để thấy lưới chấm 6 x 6 cạnh nhãn: chấm to = 1, chấm nhỏ = 0,
  đọc theo hàng, 4 chấm góc là mốc; 32 bit đầu = mã, 4 bit cuối = chẵn lẻ từng byte). Dò ngược: với mỗi quản trị viên và
  mỗi giờ quanh thời điểm nghi ngờ, tính `sha256("soc|<email>|<floor(ms / 3600000)>")` lấy 8 hex đầu, so với mã.

## S7b - rule, can thiệp, four-eyes, cài đặt hệ thống (QUYET_DINH Q41)

- **Thuỷ vân bật / tắt**: Super Admin -> Quản trị -> Cài đặt hệ thống (`g s`). Lưu cần passkey + lý do; mọi màn SOC đang
  mở nhận trong <= 5 phút. Lịch sử ở cùng trang (đọc từ audit). Kiểm nhanh qua D1:
  `npx wrangler d1 execute la-ban-prod --remote --command "SELECT * FROM soc_settings"` (staging: `la-ban-staging --env staging`).
- **Rule** (`g l`): mô phỏng 7 ngày trước khi lưu; đổi logic tự về shadow 7 ngày; bật thực thi chỉ khi đủ 7 ngày shadow.
- **Can thiệp** (`g x`): chặn 1 thiết bị / IP có hiệu lực ngay; dải / ASN đơn = đề xuất chờ người khác duyệt (trừ Under
  Attack); nhiều đích = yêu cầu four-eyes (hết hạn 24 giờ). Người tạo không tự duyệt được (Worker + CHECK D1).
- **Under Attack** (`g n`): bật khi bị tấn công diện rộng - đề xuất chặn dải có hiệu lực ngay. Tắt ngay khi qua đợt.
- Kẹt yêu cầu four-eyes (người duyệt vắng): người tạo huỷ yêu cầu rồi chặn từng đích (mỗi đích một thao tác có audit).

## S7c1 - khiếu nại + nhật ký kiểm toán (QUYET_DINH Q44)

- **Turnstile (một lần, người dùng làm - token trong `cf.env` chỉ có quyền ĐỌC Turnstile)**: Cloudflare dashboard ->
  Turnstile -> Add widget `la-ban-khieu-nai`, chế độ Managed, hostname `compass.tsudev.com`, `la-ban-landing.pages.dev`,
  `localhost`. Site key (công khai) -> `TURNSTILE_SITE_KEY` trong `web/landing/src/lib/khieu-nai.ts` (PR + deploy landing).
  Secret -> `cd workers/api && npx wrangler secret put TURNSTILE_SECRET` (prod). Staging dùng secret THỬ của Cloudflare
  `1x0000000000000000000000000000000AA` (luôn đạt) - `npx wrangler secret put TURNSTILE_SECRET --env staging`.
  Thiếu secret -> `/v1/khieu-nai` trả 503; thiếu site key -> trang khiếu nại chỉ có nút email (như trước S7c1).
- **Khiếu nại** (`g i`, analyst xem, responder quyết): form landing gửi mã REF + mô tả + email tuỳ chọn; Worker kiểm
  Turnstile (`siteverify`, hostname theo `TURNSTILE_TEN_MIEN`), chỉ nhận cho thiết bị đang `restricted` / `banned`, mỗi
  thiết bị một khiếu nại đang mở. **Chấp nhận** = gỡ mọi chặn thiết bị còn hiệu lực + điểm rủi ro về 0 (chặn IP / dải
  không gỡ - xử lý ở Can thiệp); **từ chối** giữ nguyên. Cả hai cần lý do + passkey, ghi audit. Trả lời người dùng qua
  email liên hệ (nếu có) bằng hộp thư security@ - SOC chưa tự gửi email.
- **Nhật ký kiểm toán** (`g a`, Security Admin trở lên): lọc người làm / tiền tố hành động; nút **Kiểm chuỗi băm** chạy
  lại toàn chuỗi ở Worker theo lô 2000 dòng. Báo `CHUỖI BỊ SỬA` ở dòng #N = có người sửa D1 ngoài API (đã gỡ trigger):
  KHÔNG sửa lại tay; chụp kết quả, xuất bản sao D1 (`npx wrangler d1 export la-ban-prod --remote --output=...`) ra ngoài repo,
  báo Super Admin khác, xem `wrangler` / Cloudflare audit log của tài khoản để tìm ai có quyền D1. Lượt kiểm nào cũng
  thành một dòng `audit:kiem`. Giới hạn: xoá dòng CUỐI chuỗi chưa phát hiện được (mốc neo ngoài D1 làm ở S10).

## S7c2 - báo cáo + Remote Config ký số + kill-switch (QUYET_DINH Q47)

- **Khoá ký cho SOC (một lần / mỗi môi trường, người giữ khoá làm)** - chính khoá ngoại tuyến, KHÔNG sinh khoá mới (app chỉ
  tin `app-1`, web chỉ tin `web-1`):
  `set -a; . ~/.config/la-ban/cf.env; set +a; cd workers/api` rồi
  `npx wrangler secret put KHOA_KY_APP --env staging < ~/.config/la-ban/cau-hinh/app-1.pem` (tương tự `KHOA_KY_WEB` với
  `web-1.pem`; prod: `--env=`). Thiếu / sai khoá -> trang **Cấu hình từ xa** báo "chưa có khoá ký", nút Duyệt và ký bị khoá, API trả 409 `chua-co-khoa-ky`
  (trước 04/11 trả 503 không kèm mã -> SOC chỉ hiện "Không tải được dữ liệu").
  Rút quyền ký online: `npx wrangler secret delete KHOA_KY_APP` - công cụ ngoại tuyến vẫn dùng được.
- **Cấu hình từ xa** (`g r`, analyst xem, Security Admin đề xuất / duyệt): form điền sẵn từ gói đang phục vụ, bảng
  "Thay đổi" so với hiện tại. Đề xuất cần lý do + passkey; một yêu cầu chờ / mục; hết hạn sau 24 giờ. Người thứ hai duyệt
  -> Worker ký + ghi KV ngay. App nhận khi mở / làm mới (đệm KV <= ~60 s), khiên web <= 5 phút. Tình huống khẩn (tắt AR /
  bản đồ do lỗi, nâng mã tối thiểu sau bản vá bảo mật): đề xuất rồi gọi Security Admin thứ hai. CA mới (Google / Let's
  Encrypt đổi gốc) -> công cụ ngoại tuyến `ky-cau-hinh.mjs dua-len-app --goc-them` (SOC không nhận PEM); gói do công cụ
  ký không có trong "Lịch sử gói đã ký" (chỉ gói SOC ký) - ghi chú vào audit bằng một yêu cầu bất kỳ nếu cần dấu vết.
- **Báo cáo** (`g b`): chọn khoảng (<= 92 ngày, giờ VN) -> **In / lưu PDF** (trình duyệt, chọn "Lưu dưới dạng PDF"; thuỷ
  vân in kèm). **Xuất CSV** (analyst trở lên): passkey + một dòng audit `bao-cao:xuat` mỗi lần; mở bằng Excel đúng tiếng
  Việt (BOM); ô bắt đầu bằng `= + - @` bị thêm `'`. Email liên hệ khiếu nại chỉ Security Admin thấy nguyên văn.
- **Đo kill-switch** (staging): `node tools/thu/soc-e2e.mjs https://staging.la-ban-admin.pages.dev --kill-switch` (service
  token cần vai trò responder trở lên) - đăng ký thiết bị thử, gọi API ký liên tục, SOC cấm, đo tới yêu cầu đầu bị 403
  (chỉ tiêu <= 5 s), rồi gỡ chặn. Dọn thiết bị thử `model = 'node'` như `dinh-danh-e2e.mjs`.
