# PHIẾU YÊU CẦU - Bản sắc riêng của La bàn (tsudev-standards v5.0.0)

- **Mã phiếu**: 20261121-STD50
- **Từ**: phiên tsudev-standards, 21/11/2026 - **Đến**: phiên kế tiếp của `app-la-ban`
- **Trạng thái**: ĐÓNG (24/11/2026)
- **Nguồn**: https://github.com/tsudev-org/tsudev-standards/releases/tag/v5.0.0 - `docs/DESIGN_SYSTEM.md` mục 1.2,
  CHANGELOG 5.0.0 "Hướng dẫn nâng cấp"
- **Bối cảnh**: chủ dự án muốn mỗi sản phẩm có đặc trưng nổi bật riêng (màu, giao diện, bố cục). Trước v5.0.0, 9/11
  sản phẩm dùng cùng một màu xanh. Từ v5.0.0: nền/chữ/trạng thái/tiếp cận là chung; màu nhấn, bố cục, bo góc, hoạ
  tiết, font tiêu đề là riêng, khai ở `.standards/tokens/products/compass.json` - KHÔNG tự khai lại tại repo này.

## Bản sắc đã chốt cho `app-la-ban`

| Trường | Giá trị |
| --- | --- |
| `data-product` | `compass` |
| Màu chính Tối / Sáng | `#FF843F` / `#B14C03` (hue OKLCH 47; lý do: cam của kim la bàn (nửa kim phía nam); vòng xanh hoàng gia của logo trùng xanh TsuDEV ở chế độ Sáng (cách 10°)) |
| Bố cục `layout` | `do-luong` - một mặt đồng hồ/biểu đồ lớn ở trung tâm, số liệu phụ xếp quanh |
| Bo góc `shape` | `tron` - 8/14/20px, nút viên thuốc 999px |
| Hoạ tiết `motif` | `vong-dong-tam` (tĩnh, ở hero + `og-image`, phủ ≤ 15%) |
| Font tiêu đề | Montserrat (tự host woff2 bộ `vietnamese`, tối đa 2 độ đậm) |

Muốn đổi bất kỳ giá trị nào: PR vào tsudev-standards (sửa `hue`/`layout`... + chạy `gen-product-palette.mjs`), cổng
kiểm chống trùng phải xanh. KHÔNG ghi đè tại repo này.

## Việc cần làm - chia hai PR, mỗi PR một phiên

**PR 1 - màu + hình** (`feat(ui): bản sắc compass theo tsudev-standards v5.0.0`):
1. Sync `.standards/` lên v5.0.0 (bước `curl` sync-standards.sh trước, theo `docs/SYNC.md`).
2. Web: nạp `.standards/tokens/tokens.css` rồi `.standards/tokens/products.css`; `<html data-product="compass">` (cạnh
   `data-theme`). Desktop/di động: gộp đè `products/compass.json` lên `color.light`/`color.dark` lúc build.
3. Xoá bảng màu tự khai (`palette.css`, `extensions.*.json`, dải `--color-*` riêng) và mã màu cứng còn sót.
4. Giá trị đã lưu `warm` đọc thành `light` (khối `warm` đã gỡ khỏi token).
5. Nút dùng `var(--radius-control)`; h1-h3 và số liệu lớn dùng `var(--font-display)`.
6. Ảnh chụp trước/sau, Sáng + Tối, đính vào PR. Cổng kiểm + test xanh.

**PR 2 - bố cục** (`feat(ui): bố cục do-luong + hoạ tiết vong-dong-tam`):
1. Dựng phần THÂN trang chủ website / màn hình đầu app theo `do-luong`; header, khu tài khoản, chân trang, bộ chọn
   giao diện giữ theo `ECOSYSTEM_IDENTITY.md` mục 4.
2. Hoạ tiết `vong-dong-tam` tĩnh ở hero, vẽ bằng `accent`/`glow`; sinh lại `og-image.png` cùng hoạ tiết.
3. Ảnh chụp trước/sau, Sáng + Tối.

## Việc riêng của repo này

- Màu cam của kim la bàn (hue 47): vòng xanh hoàng gia của logo cách xanh TsuDEV 10° ở chế độ Sáng nên cổng kiểm chặn. Logo giữ nguyên. Repo nằm ở `tsudev-tsudev/app-la-ban` (chưa chuyển vào org - đừng chuyển hộ).

## Kết quả xử lý

- **PR 1** (23/11/2026, nhánh `phase/std50-mau-hinh`, QUYET_DINH Q71): `.standards` v5.0.0; `design/tokens.json` bỏ bảng màu
  tự khai - `tools/build/ban-sac.mjs` gộp lớp nền + `products/compass.json` lúc build (Dart `LbColors` + `design/gen/tokens.css`),
  68 cặp tương phản AA; bo góc `tron` đọc từ `products.css`; web nạp `tokens.css` + `products.css`, `data-product="compass"`,
  nút `--radius-control`, h1-h3 + số lớn Montserrat 700 tự host; khiên web + mockup điện thoại hết mã tím cứng; admin `warm` ->
  Sáng; app nút viên thuốc, 122 golden sinh lại; logo giữ nguyên (golden logo không đổi). Ảnh trước/sau Sáng + Tối trong PR.
- **PR 2** (24/11/2026, nhánh `phase/std50-bo-cuc`): thân trang chủ landing theo `do-luong` (mặt la bàn lớn ở giữa, 4 số liệu
  xếp hai bên; điện thoại: mặt trên, số liệu lưới 2x2); hoạ tiết `vong-dong-tam` tĩnh (module tất định
  `tools/build/vong-dong-tam.mjs`, màu `accent`) ở hero + `og.png` (`thuong-hieu.mjs --chi og`). Header / chân trang / bộ chọn
  giao diện giữ nguyên. Màn đầu app (La bàn) vốn đã là `do-luong` - không đổi. -> phiếu ĐÓNG.
