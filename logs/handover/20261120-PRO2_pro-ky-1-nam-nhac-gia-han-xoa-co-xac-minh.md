# 20261120-PRO2 - app-la-ban: TsuDEV Pro kỳ 1 năm, nhắc gia hạn 7 ngày, xoá có xác minh

- **Người lập**: phiên điều phối `projects-a6`, 20/11/2026 - phiếu mẹ `~/projects/logs/handover/20261120-PRO2_pro-ky-1-nam-xoa-co-xac-minh-toan-he.md`
- **Hợp đồng**: `tsudev-org/tsudev-standards` **v4.0.0** - `docs/PRODUCT_POLICY.md` v1.2.0 mục 3.3, 7.2, 7.4, 7.5,
  **7.6**, 8. Lệch giữa phiếu và PRODUCT_POLICY ⇒ PRODUCT_POLICY thắng.
- **Thay phần tương ứng** của phiếu `20261119-PRO1` trong repo này (giá tháng/năm, mã `thang`, "tự gia hạn").
- **Người làm**: phiên app-la-ban (repo `tsudev-tsudev/app-la-ban`, gh `tsudev-tsudev`)

## 1. Bối cảnh (chủ dự án 20/11/2026)

- Pro áp dụng **1 năm**, **không tự gia hạn**; hết kỳ mà không gia hạn ⇒ về **trạng thái miễn phí ("khách mời")**:
  dùng đủ tính năng cục bộ, KHÔNG đồng bộ/sao lưu lên đám mây; dữ liệu trên thiết bị giữ nguyên; bản sao đám mây kéo/xuất
  được 90 ngày rồi bị xoá **có xác minh**.
- 7 ngày cuối trước khi hết hạn: **nhắc gia hạn mỗi lần mở app**; hết kỳ: báo **một lần**.
- Lỗi cần chặn: người **gia hạn trên web mà không mở app suốt 90 ngày** bị máy chủ xoá nhầm bản sao đám mây (máy chủ chỉ
  biết `pro_until` cũ; kênh RP `GET /api/rp/entitlements/{sub}` trả 404 khi grant OIDC quá 30 ngày).

## 2. Việc phải làm

### 2.0. Điểm riêng của repo

- `packages/quyen_loi` (`lib/src/domain/san_pham.dart`, `man_pro`, test): bỏ gói `thang`, chỉ còn `nam` **trả trước**;
  sửa test `domain_test.dart`, `man_pro_test.dart`. Máy chủ D1 `quyen_loi` (Q55): `pro_until` theo công thức cộng dồn
  khi nạp thêm; giữ `/v1/status` cho bản đã cài.
- Dữ liệu người dùng đồng bộ (nếu có) mà xoá vì hết Pro ⇒ mục 2.3; nếu chuyển sang TsuDEV Sync thì bỏ mục 2.3.
- Hồ sơ Play Console (lưu trữ `thang`, tạo `nam` trả trước) là việc 👤 qua phiên nộp duyệt - ghi lệnh/bước cụ thể.

### 2.1. Màn mua / điều khoản (PRODUCT_POLICY 3.3, 7.2, 7.5)

- Chỉ còn **một lựa chọn Pro: 490.000 ₫ / 1 năm** (Play: gói cơ sở **trả trước** `nam` của `tsudev_pro`; App Store 2027:
  Non-Renewing `com.tsudev.pro.nam`; ngoài cửa hàng: `https://tsudev.com/pro?app=<client_id>`). Gỡ mọi chỗ còn gói tháng,
  mã `thang`, chữ "tự gia hạn / huỷ bất cứ lúc nào".
- Điều khoản đứng TRƯỚC nút mua, **nguyên văn** mục 7.5 mới (vi/en); test so nguyên văn với `.standards/docs/PRODUCT_POLICY.md`.
- Ủng hộ giữ nguyên (`ung_ho_20k` … `ung_ho_200k`).

### 2.2. Nhắc gia hạn + báo hết kỳ (PRODUCT_POLICY 7.6 - nội dung nguyên văn ở đó)

- Nhắc khi 0 < `pro_until` - bây giờ ≤ 7 ngày: **mỗi lần mở app** (khởi động mới, hoặc quay lại sau ≥ 30 phút ở nền),
  tối đa một lần mỗi lần mở; đóng được, không chặn, không hiện giữa lúc nhập liệu. Nút "Gia hạn" theo kênh (Play/App Store
  ⇒ IAP gói `nam`; ngoài cửa hàng ⇒ `tsudev.com/pro?app=<client_id>`; bản Play `MUST NOT` dẫn ra web).
- Báo hết kỳ **một lần** cho mỗi `pro_until` (khoá cục bộ `tsu.pro_expired.notified_until`), kèm ngày xoá đám mây
  (`pro_until` + 90 ngày; bỏ câu này nếu sản phẩm không có đồng bộ đám mây).
- Nguồn `pro_until` = JWS quyền lợi còn hạn; không có JWS còn hạn ⇒ không hiện gì, không lỗi.
- Flutter: dùng `ProRenewalNotice` của `tsudev_ui` **v0.2.0**.
- **6 test bắt buộc**: còn 8 ngày ⇒ không; còn 7 ngày ⇒ có; mở 2 lần ⇒ 2 lần, quay lại < 30 phút ⇒ không; hết hạn ⇒ báo
  1 lần, mở lại ⇒ không; gia hạn (JWS mới) ⇒ thôi nhắc, kỳ sau báo lại; ngoại tuyến JWS hết hạn ⇒ không, không lỗi.

### 2.3. Máy chủ: xoá có xác minh (PRODUCT_POLICY 7.4 "Kênh trạng thái")

- Mọi đường xoá dữ liệu đám mây vì hết Pro (job dọn, xoá kèm yêu cầu, ...) `MUST` gọi
  `POST https://tsudev.com/api/rp/entitlements/status` NGAY TRƯỚC khi xoá: `Authorization: Bearer <client assertion>`
  (`private_key_jwt` như kênh RP; `aud` = đúng URL kênh trạng thái, `exp` ≤ 300 giây, `jti` một lần), thân
  `{"client_id": "<client_id của repo>", "subs": [...]}` (≤ 100). Kết quả:
  - `ok` và `pro_until` + 90 ngày còn ở tương lai ⇒ **đã gia hạn**: cập nhật hạn đã đệm, GIỮ dữ liệu;
  - `ok` đã quá 90 ngày, hoặc `deleted` ⇒ xoá;
  - `unknown_subject`, lỗi mạng/HTTP, khung sai ⇒ **hoãn**, hỏi lại sau ≥ 24 giờ (ghi mốc đã hỏi, không dội tsudev.com).
- `MUST NOT` xoá chỉ dựa trên `pro_until` đệm cục bộ. Kênh trạng thái chưa lên production ⇒ đường xoá tự động phải ở
  trạng thái **hoãn** (không xoá), không phải "xoá theo đệm".
- Tham chiếu mã: `tsudev-org/tsusync` v0.2.0 `worker/src/rp.ts`, `worker/src/maintenance.ts` (`verifyExpired`), test
  `worker/test/lifecycle.test.ts` (giả lập tsudev.com bằng mock fetch).
- Test bắt buộc: hết hạn thật ⇒ xoá; **gia hạn trên web mà không mở app ⇒ không xoá + cập nhật hạn**; kênh lỗi /
  `unknown_subject` ⇒ hoãn và không hỏi lại trong 24 giờ; `deleted` ⇒ xoá; client assertion đúng `iss`/`sub`/`aud`/`jti`.
- JWS do app gửi thẳng lên máy chủ (nếu có đường như vậy) chỉ nhận `iat` ≤ 24 giờ ⇒ cũ hơn `401 {"error":"invalid_token","reason":"stale"}`.

## 3. Điều kiện xong

- [ ] Các mục ở phần 2 xong, test xanh, CI xanh; sync bộ quy ước **v4.0.0** trong cùng PR (thay v3.9.1 của PRO1).
- [ ] Checklist PRODUCT_POLICY mục 8 (các dòng Pro) đạt; số liệu/ảnh chụp nhắc gia hạn vi/en Sáng/Tối trong PR.
- [ ] Việc cần chủ dự án (Play Console, App Store Connect, deploy production, merge bị bộ phân loại chặn): ghi rõ lệnh
  `!` cho chủ dự án, không lách.

## 4. Không làm

- Không thêm tự gia hạn, gói tháng, dùng thử miễn phí, popup nhắc Ủng hộ (chỉ nhắc Pro đúng điều kiện 7.6).
- Không xoá dữ liệu trên thiết bị trong bất kỳ trường hợp nào.

## 5. Kết quả xử lý (mỗi phiên ghi một dòng)

