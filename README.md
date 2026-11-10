# La bàn (Smart Compass)

App la bàn đa nền tảng (Flutter, Android + iOS, vi/en) kèm nền tảng chống can thiệp và Admin SOC trên Cloudflare.
Một sản phẩm của [tsudev](https://tsudev.com).

**Hạng sản phẩm: B - app có kết nối** (tsudev `AUTH_AND_ACCOUNT.md` mục 1): người dùng không cần tài khoản, nhưng
xác minh thiết bị, quyền lợi Pro và báo cáo sự cố cần máy chủ `compass-api.tsudev.com`. Admin SOC sau Cloudflare Access.

Mã nguồn độc quyền - xem `LICENSE`.

| Thành phần | Thư mục | Tên miền |
|---|---|---|
| App | `app/`, `packages/` | Google Play, App Store |
| API | `workers/api` | `compass-api.tsudev.com` |
| Landing | `web/landing` | `compass.tsudev.com` |
| Admin SOC | `web/admin` | `compass-admin.tsudev.com` |

## Bắt đầu
```bash
nvm use                                # Node 24 (.nvmrc)
npm install                            # web + worker
export PATH="$HOME/tools/flutter/bin:$PATH"
flutter pub get                        # pub workspace (app + packages)
./tools/kiem-tra/cong.sh nhanh         # cổng nhanh;  day-du trước merge
```

Dev: admin `npm run dev -w web/admin` (:3030) · landing `npm run dev -w web/landing` (:3031) · API `npm run dev -w workers/api` (:8797)
· app `cd app && flutter run --flavor dev -t lib/main_dev.dart`.

Tài liệu: `CLAUDE.md` (luật) · `AGENTS_KICKOFF.md` (quy trình agent) · `docs/ke-hoach/` (kế hoạch phase + bảo mật) ·
`QUYET_DINH.md` · `docs/adr/` · `SECURITY.md` · `CONTRIBUTING.md`.
