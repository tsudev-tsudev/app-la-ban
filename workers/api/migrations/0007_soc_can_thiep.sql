-- 0007 - Admin SOC 2 phần b (S7b, Spec §8.2-5): lịch sử phiên bản rule, yêu cầu four-eyes cho thao tác hàng loạt, cài đặt
-- SOC toàn hệ thống (thuỷ vân bật / tắt do Super Admin). Chỉ MỞ RỘNG (expand): bảng / chỉ mục mới.

-- Ảnh chụp mỗi phiên bản rule (sửa rule = phiên bản mới; mô phỏng / so sánh / quay lại bản cũ dựa vào đây).
CREATE TABLE rule_versions (
  rule_id TEXT NOT NULL,
  version INTEGER NOT NULL CHECK (version >= 1),
  name TEXT NOT NULL,
  condition TEXT NOT NULL CHECK (json_valid(condition)),
  "window" INTEGER NOT NULL CHECK ("window" > 0),
  threshold INTEGER NOT NULL CHECK (threshold > 0),
  action TEXT NOT NULL CHECK (json_valid(action)),
  note TEXT CHECK (note IS NULL OR length(note) <= 500),
  created_by TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (rule_id, version)
);
INSERT INTO rule_versions (rule_id, version, name, condition, "window", threshold, action, note, created_by, created_at)
  SELECT id, version, name, condition, "window", threshold, action, 'ban dau', coalesce(updated_by, 'migration'),
         coalesce(shadow_since, CAST(strftime('%s', 'now') AS INTEGER) * 1000)
  FROM rules WHERE json_valid(action);
CREATE INDEX rule_hits_rule_ts ON rule_hits (rule_id, ts);

-- Four-eyes: thao tác hàng loạt (chặn / gỡ chặn nhiều đích) là YÊU CẦU chờ người thứ hai duyệt; người tạo không tự duyệt
-- được (CHECK ở D1, Worker cũng kiểm). Hết hạn sau 24 giờ.
CREATE TABLE approval_requests (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL CHECK (kind IN ('chan', 'go-chan')),
  payload TEXT NOT NULL CHECK (json_valid(payload)),
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
CREATE INDEX approval_requests_status_ts ON approval_requests (status, created_at);

-- Cài đặt SOC toàn hệ thống (khoá -> JSON). Lịch sử thay đổi nằm ở audit_logs chuỗi băm.
CREATE TABLE soc_settings (
  key TEXT PRIMARY KEY CHECK (key GLOB '[a-z]*' AND length(key) <= 40),
  value TEXT NOT NULL CHECK (json_valid(value)),
  updated_by TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX enforcements_pending ON enforcements (pending_approval, approved_by, revoked_at, created_at);
CREATE INDEX enforcements_created ON enforcements (created_at, id);
