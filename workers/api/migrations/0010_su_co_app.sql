-- S10b (QUYET_DINH Q49): báo cáo sự cố app tự xây (thay Sentry / Crashlytics). Chỉ thêm; lưu 90 ngày (cron dọn).
-- fingerprint = 16 hex đầu SHA-256(kiểu + 5 khung ngăn xếp đầu đã chuẩn hoá) - gom nhóm ở SOC.
CREATE TABLE app_crashes (
  id TEXT PRIMARY KEY,
  device_id TEXT REFERENCES devices (id) ON DELETE CASCADE,
  fingerprint TEXT NOT NULL CHECK (length(fingerprint) = 16),
  kind TEXT NOT NULL CHECK (kind IN ('flutter', 'dart')),
  type TEXT NOT NULL,
  message TEXT NOT NULL,
  stack TEXT NOT NULL,
  app_version TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  ts INTEGER NOT NULL
);
CREATE INDEX app_crashes_fp_ts ON app_crashes (fingerprint, ts);
CREATE INDEX app_crashes_ts ON app_crashes (ts);
