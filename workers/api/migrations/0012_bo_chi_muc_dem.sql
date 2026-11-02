-- R3c (QUYET_DINH Q52): bỏ chỉ mục het_han của hai bảng tạm 0011. Mỗi yêu cầu ký ghi 1 dòng nonce + 1 dòng bộ đếm; chỉ
-- mục nhân đôi số "dòng ghi" D1 (gói Free 100.000 / ngày - tài nguyên khan hiếm), trong khi cron 5 phút chỉ quét vài
-- trăm dòng còn sống (đọc dư dả: 5 triệu / ngày). 0011 đã áp staging nên không sửa tệp cũ (migration bất biến).
DROP INDEX IF EXISTS idx_nonce_dung_het_han;
DROP INDEX IF EXISTS idx_gioi_han_dem_het_han;
