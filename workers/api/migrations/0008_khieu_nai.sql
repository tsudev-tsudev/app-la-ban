-- 0008 - Admin SOC 2 phần c (S7c1): khiếu nại từ form landing (Turnstile) + duyệt ở SOC. Chỉ MỞ RỘNG (expand): cột mới
-- cho `appeals` (0001) + chỉ mục. Không đụng audit_logs (xem / kiểm chuỗi chỉ đọc).

-- Thông tin người gửi (tuỳ chọn) + vết xử lý. `contact` là email để trả lời - PII, chỉ analyst trở lên thấy.
ALTER TABLE appeals ADD COLUMN contact TEXT CHECK (contact IS NULL OR length(contact) <= 254);
ALTER TABLE appeals ADD COLUMN lang TEXT CHECK (lang IS NULL OR lang IN ('vi', 'en'));
ALTER TABLE appeals ADD COLUMN ip TEXT;
ALTER TABLE appeals ADD COLUMN reviewed_at INTEGER;
ALTER TABLE appeals ADD COLUMN decision_note TEXT CHECK (decision_note IS NULL OR length(decision_note) <= 500);

-- Mỗi thiết bị chỉ MỘT khiếu nại đang mở (chặn gửi lặp; gửi lại sau khi đã có kết quả).
CREATE UNIQUE INDEX appeals_mot_dang_mo ON appeals (device_id) WHERE status = 'open';
CREATE INDEX appeals_ts ON appeals (ts, id);
