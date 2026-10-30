-- 0006 - Trung tâm cảnh báo (S7a, Spec §8.2 mục 3). Chỉ MỞ RỘNG (expand): cột mới cho phép NULL + bảng / chỉ mục mới.
-- Vòng đời: open -> ack (đã nhận, đang xử lý) -> closed (có kết luận). Gộp (dedup) theo (rule, nhóm) khi còn open HOẶC ack;
-- chỉ mục cũ `alerts_open` giữ tới bản contract sau (không ảnh hưởng: mọi dòng open cũng nằm trong chỉ mục mới).

ALTER TABLE alerts ADD COLUMN assignee TEXT;
ALTER TABLE alerts ADD COLUMN resolution TEXT CHECK (resolution IS NULL OR resolution IN ('true_positive', 'false_positive', 'benign'));
ALTER TABLE alerts ADD COLUMN updated_at INTEGER;
ALTER TABLE alerts ADD COLUMN updated_by TEXT;
-- Lần gửi Telegram (NULL = chưa gửi): chống gửi lặp khi cảnh báo gộp thêm lần mới.
ALTER TABLE alerts ADD COLUMN notified_at INTEGER;

CREATE UNIQUE INDEX alerts_hoat_dong ON alerts (rule_id, group_key) WHERE status IN ('open', 'ack');
CREATE INDEX alerts_assignee ON alerts (assignee, status, last_ts);
CREATE INDEX alerts_last_ts ON alerts (last_ts, id);

-- Dòng thời gian xử lý cảnh báo: ghi chú + đổi trạng thái + phân công (audit chuỗi băm vẫn ghi riêng).
CREATE TABLE alert_notes (
  id TEXT PRIMARY KEY,
  alert_id TEXT NOT NULL REFERENCES alerts (id) ON DELETE CASCADE,
  actor TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('note', 'status', 'assign')),
  body TEXT NOT NULL CHECK (length(body) <= 2000),
  ts INTEGER NOT NULL
);
CREATE INDEX alert_notes_alert_ts ON alert_notes (alert_id, ts);
