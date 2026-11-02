# Runbook - ứng phó sự cố an ninh (S10a, MON-04)

Quy trình 5 bước: **phát hiện -> cô lập -> loại bỏ -> khôi phục -> rút kinh nghiệm**. Mỗi sự cố có một người chỉ huy (IC),
ghi dòng thời gian ngay từ phút đầu (giờ VN, ai làm gì) trong ghi chú cảnh báo SOC hoặc `docs/su-co/<ngày>-<tên>.md` (chỉ
mô tả, KHÔNG dán dữ liệu cá nhân / bí mật).

## Mức độ

| Mức | Ví dụ | Phản hồi |
|---|---|---|
| S1 Nghiêm trọng | lộ khoá ký / dữ liệu cá nhân, chiếm quyền SOC, Worker bị sửa | ngay, mọi kênh |
| S2 Cao | tấn công đang diễn ra vượt qua chặn, 5xx kéo dài > 15 phút, chặn nhầm hàng loạt | < 1 giờ |
| S3 Trung bình | đột biến bị chặn tốt, một thiết bị / IP vi phạm | trong ngày |

## 1. Phát hiện

Nguồn: Telegram (cảnh báo rule high / critical; tăng đột biến 5xx / 4xx / từ chối / attestation lỗi / phát lại; việc định kỳ
lỗi), Trung tâm cảnh báo SOC, Workers Logs (`request_id`), báo cáo qua `security@tsudev.com` (security.txt), trang trạng thái.
Đột biến: so khung 5 phút với trung bình 1 giờ trước (`workers/api/src/thuan/dot-bien.ts`, ngưỡng ở `NGUONG`).

## 2. Cô lập (theo thứ tự nhẹ -> mạnh, đều có audit)

- Thiết bị / IP / dải / ASN: SOC -> Can thiệp (kill-switch <= 5 s, Q47). Dải rộng cần four-eyes.
- Tấn công diện rộng vào web: SOC -> Cài đặt -> Under Attack (S7b).
- Tắt tính năng app: Remote Config ký số cờ `tat` (SOC four-eyes hoặc `tools/cau-hinh/ky-cau-hinh.mjs dua-len-app`).
- Ép cập nhật: Remote Config `toiThieu` (không vượt bản đã phát hành). Gỡ ép = ký gói MỚI `--toi-thieu 1` (đặt lại gói cũ bị app từ chối - chống lùi cấu hình, R3b).
- Lộ khoá: xoay ngay theo `xoay-khoa.md`. Nghi tài khoản quản trị bị chiếm: gỡ email khỏi Access policy
  (`tools/cloudflare/access.mjs`), thu hồi passkey + vô hiệu admin trong SOC.

## 3. Loại bỏ

Vá lỗ hổng trên nhánh `fix/<tên>` -> cổng `day-du` -> PR -> deploy staging -> prod (mục Phát hành của CLAUDE.md). Rule mới
chạy shadow + mô phỏng 7 ngày trước khi bật.

## 4. Khôi phục

Dữ liệu: `sao-luu-khoi-phuc.md`. Gỡ chặn nhầm: SOC -> khiếu nại (chấp nhận = gỡ chặn + điểm 0) hoặc thu hồi enforcement.
Kiểm `kiem-nhat-ky` + Nhật ký kiểm toán -> Kiểm chuỗi để chắc audit nguyên vẹn. Theo dõi thêm 24 giờ.

## 5. Rút kinh nghiệm (trong 5 ngày làm việc)

Nguyên nhân gốc, cái gì phát hiện được / bỏ sót, việc khắc phục có hạn + người làm; thêm bẫy vào `docs/BAY_DA_GAP.md` nếu
liên quan quy trình.

## Thông báo theo Nghị định 13/2023/NĐ-CP (vi phạm dữ liệu cá nhân)

- Bên kiểm soát dữ liệu thông báo **Cục An ninh mạng và phòng, chống tội phạm sử dụng công nghệ cao (A05 - Bộ Công an)**
  **chậm nhất 72 giờ** sau khi xảy ra vi phạm (Điều 23), theo Mẫu số 03 của Nghị định; quá 72 giờ phải kèm lý do chậm.
- Nội dung: mô tả vi phạm (thời gian, địa điểm, hành vi, tổ chức / cá nhân, loại và số lượng dữ liệu), người liên hệ, hậu
  quả có thể xảy ra, biện pháp đã làm.
- Lập biên bản xác nhận vi phạm; báo người dùng bị ảnh hưởng qua landing / trong app khi có rủi ro cho họ.
- Dữ liệu La bàn giữ tối thiểu (không định danh phần cứng, IP rút gọn sau 90 ngày) -> phạm vi ảnh hưởng thường nhỏ, nhưng
  vẫn đánh giá và ghi lại MỌI nghi vấn lộ dữ liệu.

## Liên hệ

- Báo lỗ hổng: `security@tsudev.com` - chính sách `/bao-cao-lo-hong/` (`/en/security/`).
- Cloudflare: dashboard tài khoản `9541f44e...` (KHÔNG dùng OAuth wrangler mặc định - nạp `~/.config/la-ban/cf.env`).
