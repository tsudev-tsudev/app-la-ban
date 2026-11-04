-- M1a bước 5 (SEC-IAP, Q55): SOC tra cứu quyền lợi + thu hồi thủ công có duyệt four-eyes. Chỉ thêm bảng / chỉ mục.
-- Bảng riêng thay vì nới CHECK `approval_requests.kind` (D1 không ALTER CHECK - cùng cách 0009 config_requests).
-- kind 'khoi-phuc' để sẵn (CHECK bất biến); Worker hiện chỉ tạo 'thu-hoi'.
CREATE TABLE quyen_loi_requests (
  id TEXT PRIMARY KEY,
  entitlement_id TEXT NOT NULL REFERENCES quyen_loi (id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('thu-hoi', 'khoi-phuc')),
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
CREATE INDEX quyen_loi_requests_status_ts ON quyen_loi_requests (status, created_at);
-- Một quyền lợi chỉ có một yêu cầu đang chờ (tránh hai người cùng đề xuất).
CREATE UNIQUE INDEX quyen_loi_requests_cho ON quyen_loi_requests (entitlement_id) WHERE status = 'pending';

-- Tra theo mã đơn Play (GPA....) từ trang Quyền lợi + danh sách mới nhất.
CREATE INDEX quyen_loi_order ON quyen_loi (order_id) WHERE order_id IS NOT NULL;
CREATE INDEX quyen_loi_cap_nhat ON quyen_loi (updated_at, id);
