-- S8: rule bẫy quét (honeypot). Đường dẫn máy quét hay dò trên compass-api -> sự kiện HONEYPOT_HIT theo IP; lặp >= 3 lần
-- trong 1 giờ -> chặn IP (đồng bộ Cloudflare List -> WAF rule "la-ban: chặn edge"). Shadow >= 7 ngày như mọi rule mới.
INSERT INTO rules (id, name, condition, "window", threshold, action, enabled, version, mode, shadow_since, updated_by) VALUES
  ('R-006', 'Máy quét lỗ hổng chạm bẫy lặp lại', '{"event":["HONEYPOT_HIT"],"group_by":"ip","count":"events"}', 3600, 3,
   '["block_ip","alert_medium"]', 1, 1, 'shadow', CAST(strftime('%s', 'now') AS INTEGER) * 1000, 'migration');
