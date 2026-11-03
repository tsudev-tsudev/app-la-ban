-- S11 (QUYET_DINH Q57): thời điểm app báo thiết bị đang bật Developer options / USB - Wireless debugging (qua
-- GET /v1/status?pt=1, query nằm trong chuỗi ký S3). NULL = sạch. Prod (CHAN_DEV_MODE=1) chặn route nghiệp vụ khi khác NULL.
ALTER TABLE devices ADD COLUMN dev_mode_at INTEGER;
