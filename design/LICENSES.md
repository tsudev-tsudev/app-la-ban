# Giấy phép tài sản thiết kế

| Tài sản | Nguồn | Giấy phép | Ghi chú |
|---|---|---|---|
| Logo La bàn (biểu tượng + wordmark), app icon, splash, favicon, OG image | Tự thiết kế (TsuDev, 28/10/2026), sinh bằng `tools/build/*.mjs` | Độc quyền - xem `LICENSE` gốc repo | Wordmark là path dựng từ font Be Vietnam Pro (OFL cho phép nhúng / chuyển path trong sản phẩm, kể cả thương mại) |
| Bộ icon 24dp `design/icons/*.svg` | Tự vẽ (TsuDev) | Độc quyền | Không lấy từ bộ icon bên thứ ba |
| Font Be Vietnam Pro (Regular, Medium, SemiBold, Bold, ExtraBold) `design/fonts/*.ttf` | github.com/google/fonts `ofl/bevietnampro` (The Be Vietnam Pro Project Authors) | SIL Open Font License 1.1 - `design/fonts/OFL.txt` | Khi đóng gói font vào app (A1) phải đăng ký văn bản OFL vào `LicenseRegistry` để hiện ở màn "Giấy phép" |
| Design tokens `design/tokens.json` | Spec §2.1 + chỉnh tương phản | Độc quyền | |

Công cụ chỉ dùng lúc build (devDependencies, không vào app / web): `@resvg/resvg-js` (MPL-2.0) dựng PNG từ SVG,
`opentype.js` (MIT) chuyển chữ sang path.

Thêm tài sản mới: ghi một dòng vào bảng này (nguồn, giấy phép, đường dẫn tệp giấy phép) TRƯỚC khi commit. Không dùng ảnh /
font / icon không rõ giấy phép thương mại.
