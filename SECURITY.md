# Chính sách bảo mật - La bàn

## Báo cáo lỗ hổng
Gửi email tới **security@tsudev.com** (chuyển tiếp bằng Cloudflare Email Routing - người dùng tạo rule, token agent không có quyền) (hoặc liên hệ ghi trong `https://compass.tsudev.com/.well-known/security.txt`).
Vui lòng mô tả: thành phần bị ảnh hưởng, bước tái hiện, tác động. KHÔNG công bố trước khi được phản hồi.

- Xác nhận đã nhận: trong 3 ngày làm việc.
- Vá lỗi: Critical <= 48 giờ, High <= 7 ngày, Medium theo kế hoạch.
- Không kiểm thử trên dữ liệu / thiết bị của người dùng khác; không tấn công từ chối dịch vụ.

## Phạm vi
App "La bàn" (Android, iOS), `compass.tsudev.com`, `compass-api.tsudev.com`, `compass-admin.tsudev.com`, `compass-cdn.tsudev.com`, `compass-status.tsudev.com`.

## Tài liệu nội bộ
Yêu cầu bảo mật: `docs/ke-hoach/KE_HOACH_BAO_MAT_CHONG_XAM_NHAP.md`. Runbook sự cố: `docs/runbook/` (phase S10).
