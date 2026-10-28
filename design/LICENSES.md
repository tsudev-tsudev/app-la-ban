# Giấy phép tài sản thiết kế

| Tài sản | Nguồn | Giấy phép | Ghi chú |
|---|---|---|---|
| Logo La bàn (biểu tượng + wordmark), app icon, splash, favicon, OG image | Tự thiết kế (TsuDev, 28/10/2026), sinh bằng `tools/build/*.mjs` | Độc quyền - xem `LICENSE` gốc repo | Wordmark là path dựng từ font Be Vietnam Pro (OFL cho phép nhúng / chuyển path trong sản phẩm, kể cả thương mại) |
| Bộ icon 24dp `design/icons/*.svg` | Tự vẽ (TsuDev) | Độc quyền | Không lấy từ bộ icon bên thứ ba |
| Font Be Vietnam Pro (Regular, Medium, SemiBold, Bold, ExtraBold) `design/fonts/*.ttf` | github.com/google/fonts `ofl/bevietnampro` (The Be Vietnam Pro Project Authors) | SIL Open Font License 1.1 - `design/fonts/OFL.txt` | Đóng gói vào app từ A1 (bản sao `packages/design_system/fonts/`, cổng kiểm trùng `design/fonts`); văn bản OFL đăng ký vào `LicenseRegistry` (`dangKyGiayPhepFont`), hiện ở Cài đặt -> Giấy phép mã nguồn mở |
| Design tokens `design/tokens.json` | Spec §2.1 + chỉnh tương phản | Độc quyền | |
| Địa giới hành chính VN `packages/location_feature/assets/dia_gioi_vn.bin` | OpenStreetMap (bản trích Geofabrik), sinh bằng `tools/build/dia-gioi.py` | ODbL 1.0 - © OpenStreetMap contributors | Ghi công ở màn vị trí + `GIAY_PHEP_DU_LIEU.txt` đăng ký vào `LicenseRegistry` (`dangKyGiayPhepDuLieu`). Vùng bao Hoàng Sa / Trường Sa do TsuDev bổ sung |
| Lưới geoid EGM96 1° `packages/location_feature/assets/geoid_egm96_1do.bin` | NGA qua lưới `us_nga_egm96_15` của PROJ, sinh bằng `tools/build/geoid.py` | Phạm vi công cộng | |

Công cụ chỉ dùng lúc build (devDependencies, không vào app / web): `@resvg/resvg-js` (MPL-2.0) dựng PNG từ SVG,
`opentype.js` (MIT) chuyển chữ sang path. Python (venv tạm, `tools/build/dia-ly.requirements.txt`): `osmium` (BSD-2), `shapely` (BSD-3),
`pyproj` (MIT) sinh asset địa giới / geoid; `mgrs` (MIT), `ephem` (MIT) chỉ sinh điểm mẫu test.

Thêm tài sản mới: ghi một dòng vào bảng này (nguồn, giấy phép, đường dẫn tệp giấy phép) TRƯỚC khi commit. Không dùng ảnh /
font / icon không rõ giấy phép thương mại.
