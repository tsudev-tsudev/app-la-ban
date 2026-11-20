# ADR-0002: TsuDEV Pro bán trong cùng app `com.tsudev.laban`, bỏ app Pro tách riêng

Ngày: 2026-11-21 · Trạng thái: Chấp nhận · Thay: QUYET_DINH Q55 (phần sản phẩm), Q56, Q67 · Ghi ở QUYET_DINH Q70

## Bối cảnh

- Bộ quy ước tsudev-standards v4.2.0, `PRODUCT_POLICY.md` mục 3.3, 7.2, 7.4: nguồn thu DUY NHẤT là gói **TsuDEV Pro kỳ 1
  năm, không tự gia hạn** (Play: thuê bao `tsudev_pro`, MỘT gói cơ sở **trả trước** `nam`, P1Y, 490.000 đ) và nút Ủng hộ
  (`ung_ho_20k` ... `ung_ho_200k`). Không gói tháng, không mua một lần (`pro_tron_doi` của repo này được nêu tên là bị bỏ),
  không dùng thử. Pro gắn với **tài khoản TsuDEV** (JWS quyền lợi do tsudev.com ký), không gắn với thiết bị.
- Repo đang có (Q55-Q67): `pro_thang` / `pro_nam` (tự gia hạn, dùng thử 7 ngày) / `pro_tron_doi` (mua một lần) xác minh ở
  Worker; app riêng `com.tsudev.laban.pro` trả phí một lần (Q56) - lệch PRODUCT_POLICY (Pro = gói trong CÙNG app).
- Chủ dự án xác nhận chưa có người dùng/người mua thật (19/11/2026) và giao agent chốt câu hỏi mở. Bán Pro ở bản prod vẫn
  đóng (`moBanProTrongProd = false`, Q61).
- Kiểm kê dữ liệu rời thiết bị (`docs/store/data-safety.md`): điểm mốc, ảnh, cài đặt nằm SQLCipher trên máy
  (`allowBackup=false`); thứ gửi lên Worker chỉ là tín hiệu bảo mật/thiết bị, báo cáo sự cố có đồng ý, purchase token. Không
  có đồng bộ / sao lưu đám mây dữ liệu người dùng ⇒ bản miễn phí đã đạt N2 (0 byte dữ liệu người dùng rời máy).

## Quyết định

1. **Bỏ app Pro tách riêng `com.tsudev.laban.pro`**: KHÔNG nộp bản nháp trên Play Console (👤 có thể xoá bản nháp chưa
   từng xuất bản); `app_pro/` đóng băng (không build phát hành), gỡ hẳn ở phase dọn sau cùng các phần chỉ nó dùng (Q66
   chuyển dữ liệu, `MucBanQuyenPro`, `pro_app`). Lý do: một app, một danh sách thử kín 12 người x 14 ngày, một hồ sơ Data
   Safety; đúng PRODUCT_POLICY 3.3.
2. **Sản phẩm Play của `com.tsudev.laban`** theo đúng hợp đồng 7.4: thuê bao `tsudev_pro` + gói cơ sở trả trước `nam`
   (P1Y, cho phép nạp thêm) + tiêu hao `ung_ho_20k/50k/100k/200k`. `pro_thang` và `pro_nam` trên Play Console: **lưu trữ**
   (archive) - không tạo `thang`. `pro_tron_doi`: lưu trữ/ngừng bán. Mã đã xoá không dùng lại được nên không xoá.
3. **Mã (PR này)**: `SanPham` (app) và `SAN_PHAM` (Worker) chỉ còn `tsudev_pro`; Paywall chỉ hiện ưu đãi của gói cơ sở
   `nam`; điều khoản 7.5 nguyên văn đứng TRƯỚC nút mua (test so với `.standards/docs/PRODUCT_POLICY.md`); bỏ mọi chữ "tự
   gia hạn / dùng thử / vĩnh viễn"; Worker đọc `prepaidPlan` ⇒ `tuDongGiaHan = false`; mã cũ bị `/v1/mua/xac-minh` từ chối
   (422). Giá niêm yết SOC 490.000 đ.
4. **Phần chờ đăng nhập TsuDEV (PRO-B)** - chưa làm, ghi rõ để không ai tưởng đã xong:
   - JWS quyền lợi + `EntitlementsRepository` của `tsudev_ui` v0.2.0, nhắc gia hạn 7.6 (`ProRenewalController`,
     `maybeShowProRenewal`, 6 test), thông báo nhiều thiết bị 7.3, huy hiệu `TsuBadge`, màn Ủng hộ: đều cần `sub` tài khoản
     TsuDEV và `client_id` OIDC của La bàn - app chưa có đăng nhập. Khi nối: dùng nguyên thành phần `tsudev_ui` (không viết
     lại), `obfuscatedAccountId` = base64url(SHA-256(`tsudev-pro|` + `sub`)), biên nhận gửi
     `POST https://tsudev.com/api/rp/entitlements/play`; Worker giữ `/v1/status` cho bản đã cài tới khi gói cũ hết hạn.
   - Cho tới lúc đó bản prod **KHÔNG bán** Pro/Ủng hộ (Q61 giữ nguyên). Staging/dev vẫn thử được luồng mua `tsudev_pro`.
5. **Xoá có xác minh (PRODUCT_POLICY 7.4 kênh trạng thái)**: KHÔNG áp dụng - La bàn không giữ dữ liệu người dùng trên đám
   mây. Nếu sau này đồng bộ điểm mốc thì đi qua TsuDEV Sync (`tsudev-org/tsusync`), nơi đã có `verifyExpired`.

## Hệ quả

- Hồ sơ Play Console cần 👤: lưu trữ `pro_thang` / `pro_nam` / `pro_tron_doi`; tạo `tsudev_pro` + gói `nam` trả trước +
  4 sản phẩm `ung_ho_*` (cần hồ sơ thanh toán); bỏ bản nháp `com.tsudev.laban.pro`. Các bước cụ thể:
  `docs/store/doi-chieu-play-console.md` mục "TsuDEV Pro (Q70)".
- Pro hiện chưa mở tính năng riêng nào ngoài ủng hộ - đúng 7.2 ("tính năng cốt lõi MUST dùng được miễn phí"); tính năng Pro
  riêng của La bàn (vd. đồng bộ điểm mốc giữa thiết bị) ghi ADR mới khi có, chủ dự án duyệt.
