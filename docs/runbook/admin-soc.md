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
cd workers/api && npx wrangler d1 execute la-ban --remote --command \
  "INSERT INTO admin_users (id, email, role, created_at, created_by) VALUES (lower(hex(randomblob(16))), '<email>', 'super_admin', unixepoch()*1000, 'runbook')"
```

5. Mở trang SOC -> nhập email -> mã OTP gửi về mail -> **Tạo passkey** (vân tay / Windows Hello / khoá bảo mật).
   Passkey gắn với tên miền: passkey tạo ở prod không dùng được ở staging và ngược lại.

## Thêm người

Super Admin vào **Quản trị viên** -> email + vai trò (hỏi passkey lại nếu quá 5 phút) + thêm email vào
`admin-emails.txt` rồi chạy lại `access.mjs --apply`. Thiếu một trong hai lớp thì người đó không vào được.
Vô hiệu hoá = thu hồi ngay mọi phiên SOC của người đó; Access vẫn cho vào tới hết phiên Access (8 giờ) nhưng bị 403.

## Mất passkey / bị khoá ngoài

Super Admin khác xoá passkey không có giao diện (S7). Tạm thời (ghi audit thủ công vào LOG):

```bash
npx wrangler d1 execute la-ban --remote --command "DELETE FROM admin_passkeys WHERE email = '<email>'"
```

Lần đăng nhập sau người đó được tạo passkey mới (chỉ cần Access).

## Thử e2e staging bằng service token (không có người)

Header `CF-Access-Client-Id` / `CF-Access-Client-Secret` từ `access-svc-e2e.json`; danh tính trong SOC là
`svc:<client_id>` - chỉ staging nhận (`ACCESS_DICH_VU`), cần dòng `admin_users` ở D1 staging. Passkey được giả lập
bằng khoá phần mềm trong script thử (`tools/thu/soc-e2e.mjs`). Prod KHÔNG bao giờ đặt `ACCESS_DICH_VU`.
