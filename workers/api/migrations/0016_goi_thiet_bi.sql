-- M2 (QUYET_DINH Q56): app "La bàn Pro" dùng chung Worker -> SOC lọc thiết bị theo gói, báo cáo tách miễn phí / Pro.
-- Chỉ mở rộng: cột mới cho phép NULL (thiết bị đăng ký trước M2 = app miễn phí, cập nhật ở lần xác minh lại kế tiếp).
ALTER TABLE devices ADD COLUMN package_name TEXT;
CREATE INDEX devices_package_last_seen ON devices (package_name, last_seen);
