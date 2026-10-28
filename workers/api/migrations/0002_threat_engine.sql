-- 0002 - Threat Engine (S5, SEC-DET, Spec §7.6c-d). Chỉ MỞ RỘNG schema 0001 (expand): thêm cột có mặc định + bảng mới.

-- Hồi phục uy tín (-5 / tuần không vi phạm): mốc vi phạm cuối + mốc lần trừ điểm cuối.
ALTER TABLE devices ADD COLUMN last_violation_at INTEGER;
ALTER TABLE devices ADD COLUMN risk_decayed_at INTEGER;

-- Dải IP (/24 IPv4, /48 IPv6 - rutGonIp) để rule gom nhóm theo dải mà không phải so chuỗi IP.
ALTER TABLE security_events ADD COLUMN ip_prefix TEXT;
CREATE INDEX security_events_type_ts ON security_events (type, ts);
CREATE INDEX security_events_prefix_ts ON security_events (ip_prefix, ts);
CREATE INDEX security_events_ip_ts ON security_events (ip, ts);

-- Rule mới luôn ở shadow (chỉ ghi log) >= 7 ngày trước khi được bật thực thi.
ALTER TABLE rules ADD COLUMN mode TEXT NOT NULL DEFAULT 'shadow' CHECK (mode IN ('shadow', 'active'));
ALTER TABLE rules ADD COLUMN shadow_since INTEGER;
ALTER TABLE rules ADD COLUMN updated_by TEXT;

-- Chặn dải (cidr / asn) do máy đề xuất chờ người duyệt (QUYET_DINH Q12); level = bậc leo thang TTL (0 = 24h).
ALTER TABLE enforcements ADD COLUMN pending_approval INTEGER NOT NULL DEFAULT 0 CHECK (pending_approval IN (0, 1));
ALTER TABLE enforcements ADD COLUMN rule_id TEXT;
ALTER TABLE enforcements ADD COLUMN level INTEGER NOT NULL DEFAULT 0 CHECK (level >= 0);
CREATE INDEX enforcements_active ON enforcements (target_type, revoked_at, expires_at);

-- Allow-list chống chặn nhầm (IP văn phòng, dải kiểm thử, thiết bị / IP review của store). expires_at NULL = không hạn.
CREATE TABLE allow_list (
  id TEXT PRIMARY KEY,
  target_type TEXT NOT NULL CHECK (target_type IN ('device', 'ip', 'cidr', 'asn')),
  target_value TEXT NOT NULL,
  reason TEXT NOT NULL,
  created_by TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER,
  revoked_at INTEGER,
  CHECK (expires_at IS NULL OR expires_at > created_at)
);
CREATE INDEX allow_list_target ON allow_list (target_type, target_value);

-- Bảng điểm + ngưỡng có phiên bản (chỉnh ở Admin S7); bản mới nhất có hiệu lực, thiếu thì dùng mặc định trong mã.
CREATE TABLE threat_config (
  version INTEGER PRIMARY KEY,
  config TEXT NOT NULL CHECK (json_valid(config)),
  created_by TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

-- Cảnh báo cho SOC: gộp theo (rule, nhóm) khi đang mở.
CREATE TABLE alerts (
  id TEXT PRIMARY KEY,
  rule_id TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  group_key TEXT NOT NULL,
  count INTEGER NOT NULL DEFAULT 1 CHECK (count >= 1),
  shadow INTEGER NOT NULL DEFAULT 0 CHECK (shadow IN (0, 1)),
  first_ts INTEGER NOT NULL,
  last_ts INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'ack', 'closed'))
);
CREATE UNIQUE INDEX alerts_open ON alerts (rule_id, group_key) WHERE status = 'open';
CREATE INDEX alerts_status_ts ON alerts (status, last_ts);

-- Lần kích hoạt rule: chống thực thi lặp trong cùng cửa sổ + dữ liệu cho mô phỏng 7 ngày (S7).
CREATE TABLE rule_hits (
  rule_id TEXT NOT NULL,
  rule_version INTEGER NOT NULL,
  group_key TEXT NOT NULL,
  ts INTEGER NOT NULL,
  shadow INTEGER NOT NULL CHECK (shadow IN (0, 1)),
  actions TEXT NOT NULL CHECK (json_valid(actions))
);
CREATE INDEX rule_hits_rule_group_ts ON rule_hits (rule_id, group_key, ts);

-- Liên kết thiết bị bằng tín hiệu mềm (Spec §7.6d) - KHÔNG dùng định danh phần cứng.
CREATE TABLE device_links (
  device_id TEXT NOT NULL REFERENCES devices (id) ON DELETE CASCADE,
  linked_device_id TEXT NOT NULL REFERENCES devices (id) ON DELETE CASCADE,
  score REAL NOT NULL CHECK (score >= 0 AND score <= 1),
  signals TEXT NOT NULL CHECK (json_valid(signals)),
  ts INTEGER NOT NULL,
  PRIMARY KEY (device_id, linked_device_id),
  CHECK (device_id <> linked_device_id)
);

-- Rule khởi điểm Spec §7.6d - shadow từ lúc migrate. window = giây, threshold = ngưỡng >=.
INSERT INTO rules (id, name, condition, "window", threshold, action, enabled, version, mode, shadow_since, updated_by) VALUES
  ('R-001', 'Lạm dụng tốc độ lặp lại từ một IP', '{"event":["RATE_ABUSE"],"group_by":"ip","count":"events"}', 600, 3,
   '["block_ip","alert_medium"]', 1, 1, 'shadow', CAST(strftime('%s', 'now') AS INTEGER) * 1000, 'migration'),
  ('R-002', 'Nhiều thiết bị bị cấm chung dải IP', '{"event":["DEVICE_BANNED"],"group_by":"cidr24","count":"devices"}', 86400, 5,
   '["alert_high","propose_cidr_block"]', 1, 1, 'shadow', CAST(strftime('%s', 'now') AS INTEGER) * 1000, 'migration'),
  ('R-003', 'Sai chữ ký liên tiếp', '{"event":["SIGNATURE_MISMATCH"],"group_by":"device","count":"events"}', 600, 5,
   '["add_risk_40","restrict_device"]', 1, 1, 'shadow', CAST(strftime('%s', 'now') AS INTEGER) * 1000, 'migration'),
  ('R-004', 'Hook + gói lại cùng thiết bị', '{"event":["HOOK_FRIDA","HOOK_XPOSED","APP_REPACKAGED"],"group_by":"device","count":"types"}', 86400, 2,
   '["ban_device","alert_high"]', 1, 1, 'shadow', CAST(strftime('%s', 'now') AS INTEGER) * 1000, 'migration'),
  ('R-005', 'Attestation lỗi lặp lại', '{"event":["ATTEST_FAIL"],"group_by":"device","count":"events"}', 3600, 3,
   '["restrict_device","alert_medium"]', 1, 1, 'shadow', CAST(strftime('%s', 'now') AS INTEGER) * 1000, 'migration');
