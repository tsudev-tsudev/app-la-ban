-- 0005 - Admin SOC 1 (S6, SEC-ADM). Chỉ MỞ RỘNG (expand): cột mới có mặc định + bảng mới.
-- Danh tính lấy từ Cloudflare Access (email trong JWT); vai trò ở admin_users; MFA = passkey WebAuthn của chính SOC.

ALTER TABLE admin_users ADD COLUMN created_at INTEGER;
ALTER TABLE admin_users ADD COLUMN created_by TEXT;
-- Vô hiệu hoá thay vì xoá: giữ lịch sử audit trỏ tới email.
ALTER TABLE admin_users ADD COLUMN disabled_at INTEGER;

-- Passkey (WebAuthn). id = credential id base64url; public_key = JWK JSON (đã đổi từ COSE khi đăng ký).
CREATE TABLE admin_passkeys (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL COLLATE NOCASE,
  public_key TEXT NOT NULL CHECK (json_valid(public_key)),
  alg INTEGER NOT NULL CHECK (alg IN (-7, -8, -257)),
  sign_count INTEGER NOT NULL DEFAULT 0 CHECK (sign_count >= 0),
  rp_id TEXT NOT NULL,
  name TEXT,
  created_at INTEGER NOT NULL,
  last_used INTEGER
);
CREATE INDEX admin_passkeys_email ON admin_passkeys (email);

-- Thách thức WebAuthn dùng một lần, hạn ngắn (đọc + xoá trong cùng lệnh).
CREATE TABLE admin_challenges (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL COLLATE NOCASE,
  kind TEXT NOT NULL CHECK (kind IN ('dang-ky', 'xac-thuc')),
  challenge TEXT NOT NULL,
  rp_id TEXT NOT NULL,
  expires_at INTEGER NOT NULL
);
CREATE INDEX admin_challenges_expires ON admin_challenges (expires_at);

-- Phiên SOC sau passkey: cookie __Host- chỉ chứa id ngẫu nhiên, D1 lưu SHA-256 của nó. Hết hạn nhàn rỗi + tuyệt đối.
CREATE TABLE admin_sessions (
  id_hash TEXT PRIMARY KEY CHECK (length(id_hash) = 64),
  email TEXT NOT NULL COLLATE NOCASE,
  created_at INTEGER NOT NULL,
  last_active INTEGER NOT NULL,
  step_up_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  revoked_at INTEGER,
  ip TEXT,
  CHECK (expires_at > created_at)
);
CREATE INDEX admin_sessions_email ON admin_sessions (email, expires_at);

-- Danh sách thiết bị SOC: lọc / sắp theo lần hoạt động cuối, điểm rủi ro, phiên bản.
CREATE INDEX devices_last_seen ON devices (last_seen, id);
CREATE INDEX devices_risk ON devices (risk_score, last_seen);
CREATE INDEX devices_app_version ON devices (app_version, last_seen);
CREATE INDEX device_ips_device_last ON device_ips (device_id, last_seen);
CREATE INDEX enforcements_target_created ON enforcements (target_value, created_at);
