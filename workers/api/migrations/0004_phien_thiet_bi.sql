-- S2 (SEC-ID ID-04): refresh token xoay vòng theo CHUỖI. Mỗi lần làm mới: dòng cũ ghi thay_boi + xoay_luc + revoked_at,
-- dòng mới cùng chuoi. Token đã xoay bị gửi lại (ngoài ân hạn) -> thu hồi cả chuỗi. Chỉ THÊM cột (expand).
ALTER TABLE sessions ADD COLUMN chuoi TEXT;
ALTER TABLE sessions ADD COLUMN thay_boi TEXT;
ALTER TABLE sessions ADD COLUMN xoay_luc INTEGER;
ALTER TABLE sessions ADD COLUMN ly_do_thu_hoi TEXT;
CREATE INDEX sessions_chuoi ON sessions (chuoi);

-- Lần attestation gần nhất: thời điểm + tín hiệu đã rút gọn (không PII) cho SOC.
ALTER TABLE devices ADD COLUMN attested_at INTEGER;
ALTER TABLE devices ADD COLUMN attest_signals TEXT CHECK (attest_signals IS NULL OR json_valid(attest_signals));
