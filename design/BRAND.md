# Bộ nhận diện "La bàn" (TsuDev Compass)

Chốt 28/10/2026 (phase N1): người dùng chọn **phương án B - Vòng tối giản + kim kim cương** trong 3 phương án
(`design/logo/phuong-an/so-sanh.png`; A hoa gió cổ điển, C sao bốn cánh trong ô bo tròn - giữ làm lưu trữ, không dùng).

## 1. Nguồn và cách sinh lại

| Thứ | Nguồn duy nhất | Lệnh sinh |
|---|---|---|
| Màu, khoảng cách, bo góc, bóng, chữ, breakpoint, chuyển động | `design/tokens.json` | `node tools/build/tokens.mjs` -> `packages/design_system/lib/src/tokens/tokens.g.dart` + `design/gen/tokens.css` |
| Hình logo (3 phương án) | `tools/build/logo-hinh.mjs` (hình học tham số) | `node tools/build/logo.mjs phuong-an` |
| Logo chốt, app icon, splash, favicon, OG, xem trước launcher | `tools/build/thuong-hieu.mjs` | `node tools/build/thuong-hieu.mjs` |
| Bộ icon 24dp | `design/icons/*.svg` (viết tay) | `node tools/build/icon.mjs xem-truoc` |

Cổng (`cong.sh`) kiểm: tệp token sinh khớp nguồn, mọi cặp màu trong `contrast` của tokens.json đạt WCAG AA cả light /
dark (`node tools/kiem-tra/tuong-phan.mjs -v` để xem tỉ lệ), icon đúng quy ước. Đừng sửa tay tệp sinh hoặc PNG xuất ra -
sửa nguồn rồi chạy lại lệnh. Logo trong Flutter (`LbLogo`, `packages/design_system`) vẽ cùng hình học - đổi hình B ở
`logo-hinh.mjs` thì sửa `lb_logo.dart` theo và cập nhật golden.

## 2. Logo

- Biểu tượng: vòng tròn gradient Electric Blue `#2962FF` -> Royal Blue `#1A56DB`, hai chấm Đông / Tây `#4C8DFF`, kim kim
  cương đứng: nửa Bắc cyan (`#00E5FF` / `#00B8D4`), nửa Nam coral (`#FF6D00` / `#FF8A3D`), tâm trắng viền `#0B1220`.
- Wordmark "La bàn": Be Vietnam Pro Bold, đã chuyển sang path (không phụ thuộc font máy xem). "La" màu chữ, "bàn" Royal
  Blue (nền tối: trắng + `#4C8DFF`).
- Bản: `bieu-tuong.svg`, `ngang.svg` / `ngang-nen-toi.svg`, `doc.svg` / `doc-nen-toi.svg`, `don-sac.svg`
  (`currentColor`, mặt sáng phân biệt bằng độ mờ), PNG `bieu-tuong-1024.png`, `ngang-1200.png`.
- **Vùng an toàn:** để trống quanh logo tối thiểu bằng 1/4 cạnh biểu tượng. **Cỡ nhỏ nhất:** biểu tượng 16 px (favicon),
  bản ngang rộng 96 px.

**Đúng:** dùng nguyên tệp xuất; nền sáng dùng bản thường, nền tối dùng `*-nen-toi`; ảnh / màu lạ dùng `don-sac.svg`.
**Sai:** kéo méo tỉ lệ; xoay kim lệch Bắc trong logo tĩnh (chỉ hoạt ảnh splash được xoay); đổi màu kim (Bắc luôn cyan,
Nam luôn coral); thêm bóng / viền / hiệu ứng; đặt bản thường lên nền có tương phản thấp với vòng xanh; gõ lại wordmark
bằng font khác.

## 3. App icon

- iOS: `AppIcon.appiconset` - toàn bộ cỡ sinh từ bản 1024 nền gradient `#FFFFFF` -> `#DCE9FF`, PNG **không kênh alpha**
  (App Store từ chối icon có alpha). Biểu tượng chiếm 68% cạnh.
- Android: adaptive (`mipmap-anydpi-v26`) - nền `drawable/ic_launcher_background.xml` (gradient), tiền cảnh PNG 108dp
  (biểu tượng 60dp, trong vùng an toàn 66dp), **monochrome** cho themed icon Android 13+; legacy `ic_launcher` /
  `ic_launcher_round` cho API 24-25. Flavor `dev` / `staging` ghi đè tiền cảnh + legacy bằng nhãn **DEV** (coral) /
  **STG** (amber) để không nhầm bản cài.
- App trả phí "La bàn Pro" (QUYET_DINH Q56, người dùng chốt 03/11/2026): cùng icon, viên nhãn **PRO** nền xanh lá
  (token `success` #00C853, chữ #0B1220) để phân biệt với bản miễn phí có quảng cáo. Tài nguyên: `design/logo/pro/`
  (mipmap Android + icon 1024), `design/store/pro/play-icon-512.png`.
- Store: `design/store/play-icon-512.png` (Play, không alpha). Xem trước trên nền sáng / tối / ảnh với mặt nạ tròn,
  squircle, bo góc, themed: `design/logo/xem-truoc-launcher.png`.

## 4. Splash và hoạt ảnh

- Android < 12: `drawable/launch_background.xml` = nền `@color/lb_splash_bg` (token `color.bg`, có `values-night`) +
  biểu tượng 120dp. Android 12+: `values(-night)-v31/styles.xml` dùng SplashScreen API (icon 288dp, nội dung trong vòng
  192dp). iOS: `LaunchScreen.storyboard` nền màu tên `LaunchBackground` (light / dark) + `LaunchImage` 128pt.
- Flutter: `LbLogoDong` - kim dao động tắt dần (`gocKimTatDan`) rồi chỉ Bắc trong ~1,8 s; bật "giảm chuyển động" thì vẽ
  tĩnh. Vẽ bằng `CustomPainter`, không cần Lottie / Rive (0 KB tài nguyên, không thêm SDK) - đạt yêu cầu < 300 KB.
  Biểu tượng cùng chỗ với splash native nên chuyển cảnh liền mạch.

## 5. Màu và chữ

- Nguồn: `design/tokens.json` (Spec §2.1). **Từ Q68 (10/11/2026) giao diện dùng bảng đen tuyền + tím của hệ tsudev**:
  `primary` tím `#A970FF` là NỀN (chữ `onPrimary` mực đen), không làm màu chữ trên nền sáng; chữ nhấn dùng `primaryDeep`
  (Sáng `#7C3AED`, Tối `#C4A1FF`). Kim logo GIỮ cyan / coral (nhận diện riêng của La bàn, mục 2). Coral `#FF6D00` trên nền sáng 2,7:1 -> chỉ làm hình có viền / chữ trên coral dùng
  `onAccent`; chữ màu coral dùng `accentStrong`. Biến thể `*Strong` là bản an toàn cho chữ trạng thái.
- Chữ: Be Vietnam Pro (đủ dấu tiếng Việt). Telemetry (`LbType.telemetry*`) bật tabular figures. Web: biến CSS
  `--lb-*`, lớp `.lb-tabular`; theme theo `data-theme="light|dark"` trên `<html>` (mặc định Tối; "Hệ thống" do JavaScript giải - Q68).

## 6. Bộ icon 24dp

12 icon tự vẽ (Spec §2.3 + `cai-dat` cho tab Cài đặt từ A1): `la-ban-hoa-gio`, `mat-la-ban-3d`, `bac-thuc`,
`ghim-gps`, `hieu-chuan-so-8`, `khien`, `thuoc-thuy`, `camera-ar`, `ban-do`, `diem-moc`, `chia-se-qr`, `cai-dat`. Quy ước
(kiểm tự động): `viewBox 0 0 24 24`, nét 2, đầu / góc tròn, không tô, màu `currentColor`, vùng vẽ trong lề 2. Icon mới
theo đúng quy ước rồi chạy `node tools/build/icon.mjs xem-truoc` và `node tools/build/icon-dart.mjs` (mã Dart
`LbIcons.*`, QUYET_DINH Q30; cổng kiểm `--check`).

## 7. Web

`web/landing/public` và `web/admin/public`: `favicon.svg`, `favicon.ico` (16/32/48), `apple-touch-icon.png` (180, không
alpha); landing thêm `icon-192.png`, `icon-512.png`, `og.png` (1200x630, có thẻ `og:*` trong `index.astro`).
