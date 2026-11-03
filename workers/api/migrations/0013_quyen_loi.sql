-- M1a bước 3 (QUYET_DINH Q55, Q56, SEC-IAP): quyền lợi Pro do Worker cấp sau khi xác minh với Google. Chỉ thêm bảng.
-- source: play_sub (gói đăng ký) / play_inapp (mua một lần) / pro_app (app trả phí, appLicensingVerdict) / manual (SOC).
-- token_hash = SHA-256 hex của purchase token (tra trùng, IAP-03); token_enc = token mã hoá AES-GCM (khoá wrangler secret
-- KHOA_QUYEN_LOI) để cron xác minh lại - không bao giờ ghi token gốc.
CREATE TABLE quyen_loi (
  id TEXT PRIMARY KEY,
  source TEXT NOT NULL CHECK (source IN ('play_sub', 'play_inapp', 'pro_app', 'manual')),
  package_name TEXT NOT NULL,
  product_id TEXT NOT NULL,
  state TEXT NOT NULL CHECK (state IN ('active', 'grace', 'canceled', 'on_hold', 'paused', 'pending', 'expired', 'revoked')),
  expires_at INTEGER,
  token_hash TEXT CHECK (token_hash IS NULL OR length(token_hash) = 64),
  token_enc TEXT,
  order_id TEXT,
  account_hash TEXT,
  auto_renew INTEGER,
  acknowledged INTEGER NOT NULL DEFAULT 0,
  test_purchase INTEGER NOT NULL DEFAULT 0,
  reason TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE UNIQUE INDEX quyen_loi_token ON quyen_loi (token_hash) WHERE token_hash IS NOT NULL;
CREATE INDEX quyen_loi_het_han ON quyen_loi (source, state, expires_at);

-- Thiết bị gắn với quyền lợi (một token tối đa N cài đặt đang hoạt động - IAP-04). seen_at = lần xác minh / khôi phục cuối.
CREATE TABLE quyen_loi_devices (
  entitlement_id TEXT NOT NULL REFERENCES quyen_loi (id) ON DELETE CASCADE,
  device_id TEXT NOT NULL REFERENCES devices (id) ON DELETE CASCADE,
  linked_at INTEGER NOT NULL,
  seen_at INTEGER NOT NULL,
  PRIMARY KEY (entitlement_id, device_id)
);
CREATE INDEX quyen_loi_devices_tb ON quyen_loi_devices (device_id);

-- Lịch sử xác minh / RTDN / hoàn tiền / thu hồi (SOC tra cứu, M1a bước 5). Không chứa token, không PII.
CREATE TABLE quyen_loi_events (
  id TEXT PRIMARY KEY,
  entitlement_id TEXT,
  kind TEXT NOT NULL,
  detail TEXT,
  ts INTEGER NOT NULL
);
CREATE INDEX quyen_loi_events_ql ON quyen_loi_events (entitlement_id, ts);
CREATE INDEX quyen_loi_events_ts ON quyen_loi_events (ts);
