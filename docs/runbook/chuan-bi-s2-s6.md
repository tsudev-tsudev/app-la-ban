# Chuẩn bị cho S2 (Play Integrity) và S6 (Cloudflare Zero Trust) - việc người dùng làm

Hai phase này cần tài khoản / bảng điều khiển mà agent không tự tạo được. Làm xong phần nào thì báo agent phần đó; agent
lo phần mã, test, deploy. **Không dán khoá / mật khẩu vào chat hay vào repo** - chỉ đặt vào đúng chỗ ghi dưới đây.

Tóm tắt thứ agent cần nhận lại:

| Phase | Thứ cần | Bí mật? | Đặt ở đâu |
|---|---|---|---|
| S2 | Số dự án Google Cloud (Project number, 12 chữ số) | Không | báo trong chat |
| S2 | Tệp khoá JSON của service account | **Có** | `~/.config/la-ban/google/play-integrity-sa.json` (quyền 600) |
| S2 | Xác nhận đã liên kết dự án Cloud với app trong Play Console | Không | báo trong chat |
| S6 | Team domain Zero Trust (`<team>.cloudflareaccess.com`) | Không | báo trong chat |
| S6 | Application Audience (AUD) tag của từng ứng dụng Access | Không | báo trong chat |

---

## Phần 1 - S2: Google Cloud project + Play Integrity API + service account

Mục đích: app gọi Play Integrity để lấy token chứng thực thiết bị; Worker `la-ban-api` gửi token đó cho Google giải mã
(`decodeIntegrityToken`) bằng service account rồi mới tin thiết bị. Khoá service account chỉ nằm trong `wrangler secret`.

### 1.1 Tạo Google Cloud project

1. Mở https://console.cloud.google.com/ bằng tài khoản Google sẽ quản lý app (nên là tài khoản sở hữu Play Console "TsuDev").
2. Thanh trên cùng -> chọn dự án -> **New Project**.
   - Project name: `la-ban` (gợi ý).
   - Project ID: để mặc định hoặc `la-ban-tsudev` (không đổi được về sau).
   - Organization / Location: tài khoản Gmail cá nhân thì để "No organization".
3. **Create**, chờ vài giây rồi chọn đúng dự án vừa tạo ở thanh trên cùng.
4. Vào **Dashboard** (hoặc IAM & Admin -> Settings), ghi lại **Project number** (dãy 12 chữ số, KHÁC Project ID).
   App cần số này (`cloudProjectNumber`) khi xin token Play Integrity.

Không cần bật billing cho Play Integrity. Hạn mức miễn phí mặc định 10.000 lượt / ngày là đủ cho giai đoạn này.

### 1.2 Bật Play Integrity API

1. Trong dự án `la-ban`: menu ☰ -> **APIs & Services** -> **Library**.
2. Tìm **Google Play Integrity API** -> **Enable**.
3. Kiểm: APIs & Services -> **Enabled APIs & services** có dòng "Google Play Integrity API".

### 1.3 Tạo service account + khoá JSON

1. Menu ☰ -> **IAM & Admin** -> **Service Accounts** -> **Create service account**.
   - Name: `la-ban-integrity`
   - ID: `la-ban-integrity` (email sẽ là `la-ban-integrity@<project-id>.iam.gserviceaccount.com`)
   - Description: `Worker la-ban-api giải mã token Play Integrity`
2. **Create and continue**. Bước "Grant this service account access to project": **bỏ trống, không cấp vai trò nào**
   (giải mã token chỉ cần API đã bật trong cùng dự án; không cấp Owner / Editor). -> **Continue** -> **Done**.
3. Bấm vào service account vừa tạo -> tab **Keys** -> **Add key** -> **Create new key** -> **JSON** -> **Create**.
   Trình duyệt tải về một tệp `.json` - đây là bí mật, ai có nó thì gọi API dưới danh nghĩa dự án.
   - Nếu báo "Service account key creation is disabled": tài khoản đang thuộc một Organization có chính sách
     `iam.disableServiceAccountKeyCreation`. Tài khoản Gmail cá nhân không gặp. Gặp thì báo agent để chọn cách khác.
4. Chuyển tệp vào chỗ cố định NGOÀI repo (WSL, sửa đường dẫn tệp tải về cho đúng):

   ```bash
   mkdir -p ~/.config/la-ban/google && chmod 700 ~/.config/la-ban/google
   mv "/mnt/c/Users/<tên>/Downloads/la-ban-xxxxxxxx.json" ~/.config/la-ban/google/play-integrity-sa.json
   chmod 600 ~/.config/la-ban/google/play-integrity-sa.json
   ```

   Rồi XOÁ bản trong thư mục Downloads (và Thùng rác) của Windows.
5. Đẩy khoá lên Worker (chế độ auto của agent không được ghi secret nên bạn chạy lệnh này; tên secret đã chốt cho S2):

   ```bash
   cd ~/projects/app-la-ban/workers/api && source ~/.nvm/nvm.sh && nvm use \
     && set -a && . ~/.config/la-ban/cf.env && set +a \
     && npx wrangler secret put PLAY_INTEGRITY_SA_JSON --env staging < ~/.config/la-ban/google/play-integrity-sa.json \
     && npx wrangler secret put PLAY_INTEGRITY_SA_JSON --env= < ~/.config/la-ban/google/play-integrity-sa.json
   ```

   Thấy hai dòng "Success! Uploaded secret PLAY_INTEGRITY_SA_JSON" là xong. Giữ tệp ở `~/.config/la-ban/google/` làm
   bản dự phòng (sao lưu cùng khoá upload Android ở `~/.config/la-ban/android/`).

### 1.4 Liên kết dự án Cloud với app trong Play Console

> **Hoãn (29/10/2026):** thanh toán Play Console lỗi - làm bước này sau khi tạo được tài khoản nhà phát triển (dự kiến
> từ 05/11/2026). S2 đã chạy không cần bước này (QUYET_DINH Q35); khi liên kết, chọn ĐÚNG dự án `app-la-ban`
> (Project number 930761930572) - không đổi mã, không phát hành lại.

Token Play Integrity chỉ giải mã được bằng dự án Cloud đã liên kết với app.

1. Mở https://play.google.com/console (tài khoản nhà phát triển "TsuDev").
2. Nếu chưa có app: **Create app**
   - App name: `La bàn` · Default language: Tiếng Việt · App or game: App · Free or paid: Free.
   - Đánh dấu các cam kết -> **Create app**.
   - Tên gói (`com.tsudev.laban`) được gắn khi tải bản AAB / APK đầu tiên lên (việc của R2). Liên kết Integrity làm được
     trước đó; nếu Play Console đòi tên gói trước thì báo agent, agent build bản internal để tải lên.
3. Trong app: menu trái **Test and release** -> **App integrity** (ở bản cũ: Release -> Setup -> App integrity).
4. Mục **Play Integrity API** -> **Link a Cloud project** -> chọn dự án `la-ban` vừa tạo -> **Link**.
5. (Tuỳ chọn, nên làm) cùng trang -> **Settings** của Play Integrity API: để mặc định các phản hồi (device, app, account).
   Không bật "Play Protect verdict" hay "recent device activity" lúc này (agent sẽ quyết ở S2 nếu cần).

Lưu ý: bản `com.tsudev.laban.dev` / `.stg` (flavor dev, staging) và APK cài tay sẽ nhận phán quyết app
`UNRECOGNIZED_VERSION` - bình thường; Worker S2 xử lý mức tin cậy theo đó. Phán quyết thiết bị vẫn có giá trị để thử.

### 1.5 Báo agent

Gửi trong chat: "S2 sẵn sàng - project number `<12 chữ số>`, đã đặt PLAY_INTEGRITY_SA_JSON staging + prod, đã link
Play Console". Không gửi nội dung tệp JSON.

---

## Phần 2 - S6: Bật Cloudflare Zero Trust + Access cho admin

Mục đích: `compass-admin.tsudev.com` (SOC) và đường dẫn API quản trị `compass-api.tsudev.com/admin/*` chỉ mở sau khi đăng
nhập Google bằng email của bạn (Q24). Worker kiểm thêm JWT Access + vai trò D1; WebAuthn step-up làm trong app (S6).

Tài khoản Cloudflare đã dùng Access cho repo khác (ubnd...)? Thì Zero Trust đã bật - bỏ qua 2.1, kiểm 2.2 xem đã có
Google login chưa, rồi làm từ 2.3. Các ứng dụng Access của repo khác KHÔNG sửa.

### 2.1 Bật Zero Trust (một lần cho tài khoản)

1. https://dash.cloudflare.com -> chọn tài khoản -> menu trái **Zero Trust**.
2. Lần đầu: chọn **team name** (gợi ý `tsudev`) -> team domain sẽ là `tsudev.cloudflareaccess.com`. Đổi sau được nhưng phiền.
3. Chọn gói **Free** (tối đa 50 người dùng). Cloudflare có thể yêu cầu thêm phương thức thanh toán dù gói 0 USD.
4. Ghi lại **team domain**: Zero Trust -> Settings -> Custom Pages (hoặc góc trên trang Settings).

### 2.2 Đăng nhập bằng Google

Cần một OAuth client của Google trỏ về team domain.

1. Google Cloud Console (có thể dùng chung dự án `la-ban` ở phần 1) -> **APIs & Services** -> **OAuth consent screen**
   (bản mới: **Google Auth Platform**).
   - User type: **External** -> App name `La bàn SOC` -> support email + developer email: email của bạn -> lưu.
   - Audience / Test users: thêm **email của bạn** (để ở chế độ Testing là đủ; chỉ người trong danh sách đăng nhập được).
2. **APIs & Services** -> **Credentials** -> **Create credentials** -> **OAuth client ID**.
   - Application type: **Web application**, Name: `cloudflare-access`.
   - Authorized JavaScript origins: `https://<team>.cloudflareaccess.com`
   - Authorized redirect URIs: `https://<team>.cloudflareaccess.com/cdn-cgi/access/callback`
   - **Create** -> chép **Client ID** + **Client secret** (dán thẳng vào bước 3, không lưu nơi khác).
3. Zero Trust -> **Settings** -> **Authentication** -> **Login methods** -> **Add new** -> **Google**.
   - Dán App ID (Client ID) + Client secret -> **Save** -> bấm **Test**: đăng nhập Google thành công là được.
   - Có thể tắt "One-time PIN" nếu không muốn đăng nhập bằng mã gửi email.

### 2.3 Ứng dụng Access cho trang admin

1. Zero Trust -> **Access** -> **Applications** -> **Add an application** -> **Self-hosted**.
2. Cấu hình:
   - Application name: `la-ban-admin`
   - Session duration: **2 hours** (admin SOC cần phiên ngắn; sửa sau được)
   - Public hostname: subdomain `compass-admin`, domain `tsudev.com`, path để trống.
   - Identity providers: chỉ chọn **Google**; bật **Instant Auth** (bỏ qua trang chọn IdP).
3. Policy: **Add a policy**
   - Name: `la-ban-admin-chu`, Action: **Allow**, Session duration: theo ứng dụng.
   - Include -> Selector **Emails** -> nhập email của bạn (chỉ email này; thêm người sau qua vai trò D1 ở S6).
4. Mục Settings / Advanced (tuỳ bản dashboard):
   - Cookie settings: bật **HTTP Only**, **Binding Cookie**; SameSite **Strict**.
   - CORS: để mặc định (tắt).
   - Bỏ chọn "Enable automatic cloudflared authentication" (không dùng).
5. **Save**. Mở lại ứng dụng -> tab **Overview / Basic information** -> chép **Application Audience (AUD) Tag**
   (chuỗi hex 64 ký tự). Đây không phải bí mật nhưng Worker cần đúng giá trị.

### 2.4 Ứng dụng Access cho API quản trị

Giống 2.3, khác:
- Application name: `la-ban-api-admin`
- Public hostname: subdomain `compass-api`, domain `tsudev.com`, **path `admin`** (chỉ chặn `/admin/*`; KHÔNG để trống path -
  để trống sẽ chặn cả API của app và trang trạng thái).
- Policy: dùng lại `la-ban-admin-chu` (hoặc tạo policy cùng điều kiện email).
- Chép **AUD Tag** của ứng dụng này.

### 2.5 Kiểm

```bash
curl -sI https://compass-admin.tsudev.com/ | grep -iE '^HTTP|^location'
# mong đợi: HTTP 302, location: https://<team>.cloudflareaccess.com/cdn-cgi/access/login/...
curl -s -o /dev/null -w '%{http_code}\n' https://compass-api.tsudev.com/v1/health
# mong đợi: 200 (API của app KHÔNG bị Access chặn)
curl -sI https://compass-api.tsudev.com/admin/v1/x | grep -iE '^HTTP|^location'
# mong đợi: 302 về cloudflareaccess.com
```

Mở `https://compass-admin.tsudev.com` trong trình duyệt -> đăng nhập Google -> thấy trang **403** của La bàn: ĐÚNG (trang
SOC thật làm ở S6; lúc này Access đã chặn trước, 403 là của worker tạm). Từ mạng ngoài Việt Nam admin vẫn bị WAF chặn (S8).

### 2.6 Báo agent

Gửi trong chat: "S6 sẵn sàng - team `<team>.cloudflareaccess.com`, AUD admin `<...>`, AUD api-admin `<...>`".
Nếu muốn agent tự kiểm cấu hình Access bằng API: thêm quyền **Account -> Access: Apps and Policies -> Read** cho token
`la-ban-agent` (cf.env). Không bắt buộc.

---

## Sự cố thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| `wrangler` báo cần Node >= 22 | quên `source ~/.nvm/nvm.sh && nvm use` (shell mặc định Node 20) |
| `wrangler secret put` báo Authentication error | quên nạp `~/.config/la-ban/cf.env`, hoặc token thiếu quyền Workers Scripts Edit |
| Google "Error 400: redirect_uri_mismatch" khi test login | redirect URI phải đúng `https://<team>.cloudflareaccess.com/cdn-cgi/access/callback`, không dấu `/` thừa |
| Google "Access blocked: app has not completed verification" | email chưa nằm trong Test users của OAuth consent screen |
| Vào admin không thấy trang Access mà thấy 403 ngay | Access chưa áp cho đúng hostname `compass-admin.tsudev.com` hoặc policy chưa lưu |
| Play Console không có mục App integrity | app chưa tạo xong, hoặc tài khoản nhà phát triển chưa xác minh danh tính - hoàn tất xác minh trước |
