-- 0009 - Remote Config / phiên bản tối thiểu / pin dự phòng ký số có duyệt four-eyes (S7c2, Spec §8.2-7).
-- MỞ RỘNG: bảng mới thay vì nới CHECK `approval_requests.kind` (D1 không ALTER CHECK; tạo lại bảng = contract 2 bản).
-- CONTRACT duy nhất: bỏ chỉ mục `alerts_open` cũ (0006 đã thay bằng `alerts_hoat_dong` phủ open + ack, Worker không dùng).

-- Yêu cầu đổi cấu hình ký số: người tạo không tự duyệt (CHECK + Worker kiểm). `base_issued` = phatHanh của gói đang phục
-- vụ lúc tạo - gói đã đổi trước khi duyệt -> từ chối áp (tránh ghi đè thay đổi của người khác).
CREATE TABLE config_requests (
  id TEXT PRIMARY KEY,
  target TEXT NOT NULL CHECK (target IN ('app', 'web')),
  payload TEXT NOT NULL CHECK (json_valid(payload)),
  base_issued INTEGER,
  reason TEXT NOT NULL CHECK (length(reason) BETWEEN 10 AND 500),
  created_by TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  decided_by TEXT,
  decided_at INTEGER,
  decision_note TEXT CHECK (decision_note IS NULL OR length(decision_note) <= 500),
  CHECK (expires_at > created_at),
  CHECK (decided_by IS NULL OR decided_by <> created_by OR status = 'cancelled')
);
CREATE INDEX config_requests_status_ts ON config_requests (status, created_at);

-- Lịch sử gói đã ký + đưa lên KV (nội dung giải mã, không có chữ ký): xem lại / so sánh / khôi phục bằng yêu cầu mới.
CREATE TABLE config_versions (
  id TEXT PRIMARY KEY,
  target TEXT NOT NULL CHECK (target IN ('app', 'web')),
  kid TEXT NOT NULL,
  issued_at INTEGER NOT NULL,
  content TEXT NOT NULL CHECK (json_valid(content)),
  request_id TEXT REFERENCES config_requests (id),
  created_by TEXT NOT NULL,
  approved_by TEXT NOT NULL,
  CHECK (approved_by <> created_by)
);
CREATE INDEX config_versions_target_ts ON config_versions (target, issued_at);

DROP INDEX IF EXISTS alerts_open;
