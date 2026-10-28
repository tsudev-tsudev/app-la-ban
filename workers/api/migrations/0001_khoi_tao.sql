-- 0001 - schema lõi theo Spec §6.4 (Postgres -> D1/SQLite, QUYET_DINH Q3). BẤT BIẾN: sửa bằng migration mới.
-- Quy ước: id TEXT (UUID / ULID), thời gian INTEGER mili giây Unix, jsonb -> TEXT có CHECK json_valid, inet -> TEXT.

CREATE TABLE devices (
  id TEXT PRIMARY KEY,
  installation_id_hash TEXT NOT NULL UNIQUE,
  public_key TEXT,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  os_version TEXT,
  model TEXT,
  app_version TEXT,
  build INTEGER,
  locale TEXT,
  first_seen INTEGER NOT NULL,
  last_seen INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'clean' CHECK (status IN ('clean', 'suspicious', 'restricted', 'banned')),
  risk_score INTEGER NOT NULL DEFAULT 0 CHECK (risk_score >= 0),
  attestation_level TEXT NOT NULL DEFAULT 'unverified',
  country TEXT
);
CREATE INDEX devices_status_last_seen ON devices (status, last_seen);

-- ip_masked = 1: ip đã rút gọn / băm theo hạn lưu 90 ngày (SEC-DATA DAT-01).
CREATE TABLE device_ips (
  device_id TEXT NOT NULL REFERENCES devices (id) ON DELETE CASCADE,
  ip TEXT NOT NULL,
  asn INTEGER,
  country TEXT,
  first_seen INTEGER NOT NULL,
  last_seen INTEGER NOT NULL,
  count INTEGER NOT NULL DEFAULT 1 CHECK (count >= 1),
  ip_masked INTEGER NOT NULL DEFAULT 0 CHECK (ip_masked IN (0, 1)),
  PRIMARY KEY (device_id, ip)
);
CREATE INDEX device_ips_ip ON device_ips (ip);
CREATE INDEX device_ips_last_seen ON device_ips (ip_masked, last_seen);

CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL REFERENCES devices (id) ON DELETE CASCADE,
  issued_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  refresh_hash TEXT NOT NULL UNIQUE,
  revoked_at INTEGER,
  CHECK (expires_at > issued_at)
);
CREATE INDEX sessions_device ON sessions (device_id, issued_at);

CREATE TABLE security_events (
  id TEXT PRIMARY KEY,
  device_id TEXT REFERENCES devices (id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('info', 'low', 'medium', 'high', 'critical')),
  signals TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(signals)),
  ip TEXT,
  ts INTEGER NOT NULL,
  rule_id TEXT,
  risk_delta INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX security_events_device_ts ON security_events (device_id, ts);
CREATE INDEX security_events_ts ON security_events (ts);

CREATE TABLE rules (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  condition TEXT NOT NULL CHECK (json_valid(condition)),
  "window" INTEGER NOT NULL CHECK ("window" > 0),
  threshold INTEGER NOT NULL CHECK (threshold > 0),
  action TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 0 CHECK (enabled IN (0, 1)),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  UNIQUE (name, version)
);

-- Mọi chặn có hạn (QUYET_DINH Q12): expires_at bắt buộc, sau created_at.
CREATE TABLE enforcements (
  id TEXT PRIMARY KEY,
  target_type TEXT NOT NULL CHECK (target_type IN ('device', 'ip', 'cidr', 'asn')),
  target_value TEXT NOT NULL,
  action TEXT NOT NULL,
  reason TEXT NOT NULL,
  created_by TEXT NOT NULL,
  approved_by TEXT,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  revoked_at INTEGER,
  source TEXT NOT NULL CHECK (source IN ('auto', 'manual')),
  CHECK (expires_at > created_at),
  CHECK (approved_by IS NULL OR approved_by <> created_by)
);
CREATE INDEX enforcements_target ON enforcements (target_type, target_value, expires_at);

CREATE TABLE appeals (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL REFERENCES devices (id) ON DELETE CASCADE,
  enforcement_id TEXT REFERENCES enforcements (id),
  message TEXT NOT NULL CHECK (length(message) <= 2000),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'approved', 'rejected')),
  reviewed_by TEXT,
  ts INTEGER NOT NULL
);
CREATE INDEX appeals_status_ts ON appeals (status, ts);

-- 5 vai trò Spec §8.1.
CREATE TABLE admin_users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE COLLATE NOCASE,
  role TEXT NOT NULL CHECK (role IN ('viewer', 'analyst', 'responder', 'security_admin', 'super_admin')),
  mfa_enrolled INTEGER NOT NULL DEFAULT 0 CHECK (mfa_enrolled IN (0, 1)),
  last_login INTEGER
);

-- Chuỗi băm chỉ thêm (SEC-DATA DAT-02): hash_prev UNIQUE chặn rẽ nhánh khi hai lệnh ghi đồng thời; trigger chặn sửa / xoá.
CREATE TABLE audit_logs (
  id TEXT PRIMARY KEY,
  actor TEXT NOT NULL,
  action TEXT NOT NULL,
  target TEXT,
  before TEXT CHECK (before IS NULL OR json_valid(before)),
  after TEXT CHECK (after IS NULL OR json_valid(after)),
  ip TEXT,
  ts INTEGER NOT NULL,
  hash_prev TEXT NOT NULL UNIQUE CHECK (length(hash_prev) = 64),
  hash_self TEXT NOT NULL UNIQUE CHECK (length(hash_self) = 64)
);
CREATE INDEX audit_logs_ts ON audit_logs (ts);
CREATE TRIGGER audit_logs_khong_sua BEFORE UPDATE ON audit_logs
BEGIN
  SELECT RAISE(ABORT, 'audit_logs chi them');
END;
CREATE TRIGGER audit_logs_khong_xoa BEFORE DELETE ON audit_logs
BEGIN
  SELECT RAISE(ABORT, 'audit_logs chi them');
END;

-- Idempotency-Key cho POST (SEC-API API-03). pham_vi = thiết bị / phiên / IP rút gọn: hai người dùng trùng khoá không lẫn nhau.
CREATE TABLE idempotency_keys (
  pham_vi TEXT NOT NULL,
  khoa TEXT NOT NULL,
  bam_yeu_cau TEXT NOT NULL,
  trang_thai TEXT NOT NULL CHECK (trang_thai IN ('dang', 'xong')),
  ma_http INTEGER,
  noi_dung TEXT,
  loai_noi_dung TEXT,
  tao_luc INTEGER NOT NULL,
  het_han INTEGER NOT NULL,
  PRIMARY KEY (pham_vi, khoa)
);
CREATE INDEX idempotency_keys_het_han ON idempotency_keys (het_han);
