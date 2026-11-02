# Chi phí và hạn mức Cloudflare - app "La bàn"

Cập nhật 28/10/2026 (N2). Số liệu theo trang giá Cloudflare tại thời điểm viết - KIỂM LẠI trước khi lên production
(https://developers.cloudflare.com/workers/platform/pricing/). Gói hiện tại: zone `tsudev.com` **Free**, tài khoản
Workers **Free** (QUYET_DINH Q22: lên Workers Paid 5 USD/tháng khi production - S1 / R4).

## Tài nguyên đã tạo (N2)

| Loại | Production | Staging |
|---|---|---|
| Worker | `la-ban-api` -> `compass-api.tsudev.com` | `la-ban-api-staging` -> `compass-api-stg.tsudev.com` |
| D1 | `la-ban-prod` (SIN, từ 03/11 - Q53; `la-ban` ICN cũ chờ xoá) | `la-ban-staging` (APAC) |
| KV | `la-ban-cau-hinh` | `la-ban-cau-hinh-staging` |
| R2 | `la-ban-cdn` (-> `compass-cdn.tsudev.com`), `la-ban-nhat-ky` | `la-ban-cdn-staging`, `la-ban-nhat-ky-staging` |
| Durable Objects (SQLite) | `PhongSoc` (SOC realtime); `KhoNonce`, `GioiHanToc` không còn dùng từ R3c (Q52, chờ bỏ) | như production |
| Pages | `la-ban-landing` (`compass.tsudev.com`), `la-ban-admin` (`compass-admin.tsudev.com`, 403 tới S6), `la-ban-status` (`compass-status.tsudev.com`) | preview `<id>.la-ban-<x>.pages.dev` |
| Analytics Engine | CHƯA (cần bật trên dashboard) | |

## Hạn mức gói Free (mỗi tài khoản, dùng CHUNG với dự án khác của người dùng)

| Dịch vụ | Free | Paid (5 USD/tháng) |
|---|---|---|
| Workers request | 100.000 / ngày, CPU 10 ms / request | 10 triệu / tháng gồm sẵn, +0,30 USD / triệu; CPU 30 triệu ms gồm sẵn |
| Pages | static không giới hạn request; 500 build / tháng; Functions / `_worker.js` tính vào hạn mức Workers | như Free |
| D1 | 5 triệu dòng đọc / ngày, 100.000 dòng ghi / ngày, 5 GB | 25 tỷ dòng đọc, 50 triệu dòng ghi / tháng gồm sẵn |
| KV | 100.000 đọc / ngày, 1.000 ghi / ngày, 1 GB | 10 triệu đọc, 1 triệu ghi / tháng |
| R2 | 10 GB-tháng, 1 triệu thao tác loại A, 10 triệu loại B / tháng, KHÔNG tính phí egress | trả theo dùng vượt mức Free |
| Durable Objects (SQLite) | 100.000 request / ngày, 13.000 GB-s / ngày, 5 GB | 1 triệu request / tháng gồm sẵn |
| Analytics Engine | 100.000 điểm ghi / ngày, 10.000 truy vấn / ngày | 10 triệu điểm ghi / tháng |
| WAF (zone Free) | 5 custom rule, 1 rate-limit rule, Managed Free Ruleset | cần zone Pro (20 USD/tháng) cho Managed Rules đầy đủ + OWASP |

## Hệ quả cho kế hoạch
- KV ghi 1.000 / ngày -> KHÔNG dùng KV cho dữ liệu ghi thường xuyên (nonce, rate, phiên). Ban đầu chọn Durable Objects;
  R3c (Q52) chuyển nonce + rate sang D1 vì DO nguội tốn ~485 ms / lần: mỗi yêu cầu ký ghi ~2 dòng D1 -> gói Free
  (100.000 dòng ghi / ngày) đủ cho beta, production theo lượng người dùng cần Workers Paid (R4).
- 100.000 request Workers / ngày dùng chung cả tài khoản (Worker `tsudev`, cron...) -> đủ cho dev / staging; production
  cần Workers Paid trước khi phát hành (R4).
- WAF zone Free chỉ 5 custom rule và zone dùng chung -> S8 phải đếm rule hiện có (dự án khác đã dùng một số) trước khi thêm;
  EDG-02 (Managed Rules + OWASP đầy đủ) cần zone Pro - ghi lại ở S8 để người dùng quyết.
- Ước tính tháng đầu sau phát hành (< 10.000 người dùng hoạt động): Workers Paid 5 USD + R2 tile Việt Nam (~1-2 GB, trong
  hạn mức Free) -> khoảng 5 USD / tháng.
