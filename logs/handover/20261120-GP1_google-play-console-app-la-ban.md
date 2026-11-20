# 20261120-GP1 - app-la-ban: đưa La bàn - TsuDev Compass lên Google Play Console (phần B của phiếu toàn hệ)

- **Người lập**: phiên điều phối `tsudev-62`, 20/11/2026.
- **Người làm**: phiên app-la-ban. **Trạng thái**: MỞ.
- **Phiếu mẹ**: `~/projects/logs/handover/20261120-GP1_google-play-console-toan-he.md` - làm theo **mục 4 (checklist
  mỗi app)**; mục 2 (phần A dùng chung) ĐÃ XONG ở phiên tsudev, đừng làm lại.
- **Công cụ trình duyệt**: `~/projects/logs/tools/browser/README.md` (`tsb`, hồ sơ `play` = Edge `tsudev-play`, đã đăng
  nhập Play Console). Dùng tsb, KHÔNG viết script Playwright thô không rào chắn.

## 1. Hiện trạng (đo 20/11/2026)

| Package | Trên Play Console | Pro/ủng hộ qua Play |
|---|---|---|
| `com.tsudev.laban (+ bản nháp com.tsudev.laban.pro)` | ✅ Thử nghiệm nội bộ (`com.tsudev.laban`); `com.tsudev.laban.pro` ✅ Bản nháp | đang tự xác minh mua hàng (Q55) - về sau chuyển sang máy chủ quyền lợi tsudev (`PLAY_PACKAGES`) |

## 2. Việc riêng của repo này

1. **Quyết trước tiên**: `com.tsudev.laban.pro` là app Pro TÁCH RIÊNG - lệch PRODUCT_POLICY (Pro = gói `tsudev_pro` trong CÙNG app). Bỏ bản nháp hay giữ có lý do ⇒ ghi ADR. CHƯA quyết thì KHÔNG nộp bản nháp đó.
2. Chuyển `com.tsudev.laban` từ Thử nghiệm nội bộ sang **Thử nghiệm kín** (≥ 12 người × 14 ngày liên tục - GP1 mục 4 bước 5).
3. Đã có tài liệu cửa hàng ở `docs/store/` (`play-listing*.md`, `data-safety*.md`, `doi-chieu-play-console.md`) - đối chiếu với checklist GP1 mục 4 bước 2-3, bổ sung chỗ thiếu (URL xoá tài khoản, đối tượng 13+/18+).
4. Tài khoản dịch vụ `la-ban-integrity@app-la-ban.iam.gserviceaccount.com` đang có trong Play Console - giữ cho Play Integrity; xác minh mua hàng về sau đi qua `tsudev-play-verify` (đã mời mức tài khoản, không cần mời lại).
5. Khi chuyển Q55 sang tsudev: báo phiên tsudev nối `laban=com.tsudev.laban` vào `PLAY_PACKAGES` ở Render (khoá trái = `client_id` OIDC).

## 3. Ranh giới

- Nút gửi duyệt / xuất bản / thanh toán / xoá app: **👤 bấm** (tsb chặn sẵn) - agent điền rồi dừng, chụp màn hình.
- Danh sách ≥ 12 người thử kín, hồ sơ thanh toán, mật khẩu tài khoản thử cho người duyệt: 👤.
- Không tạo khoá tài khoản dịch vụ mới; `tsudev-play-verify` đã có quyền mức tài khoản (phủ app mới).
- Bằng chứng: ảnh "Tổng quan về việc xuất bản" vào `logs/trust/`, ghi `logs/trust/TRUST.md`.

## 4. Xong khi

GP1 mục 4 bước 1-7 đạt cho app này; ghi một dòng vào mục 5 phiếu này VÀ mục 6 phiếu mẹ.

## 5. Kết quả xử lý (mỗi phiên ghi một dòng)


## Bổ sung 20/11/2026 (tsudev điều phối) - điền biểu mẫu đứng tên chủ dự án

Theo tsudev-standards v4.2.0 `STORE_SUBMISSION.md` mục 0.1 (PR tsudev-standards #65): mọi trường Play Console điền như
chủ dự án tự điền, KHÔNG chọn/ghi "do AI thực hiện". Câu hỏi về tính năng thật của app (có tính năng AI tạo sinh
không...) trả lời đúng mã, ghi tệp mã làm nguồn trong `docs/store/google-play.md`.
