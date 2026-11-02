-- R3c (QUYET_DINH Q52): nonce chống phát lại + bộ đếm giới hạn tốc độ chuyển từ Durable Object sang D1. Đo trên staging:
-- isolate gọi một DO lần đầu tốn ~485 ms (tra vị trí DO) - lưu lượng thưa nên gần như yêu cầu nào cũng trả; D1 primary
-- APAC từ colo SIN ~10 ms. D1 một primary (tuần tự hoá ghi) -> khoá chính bảo đảm mỗi nonce dùng đúng một lần như DO.
-- Bảng TẠM (không sao lưu, không xuất nhật ký): cron 5 phút xoá dòng hết hạn.

-- loai 'n' = nonce yêu cầu ký / làm mới (dùng một lần trong hạn); 'c' = thách thức server cấp (S2, xoá khi dùng).
CREATE TABLE nonce_dung (
  pham_vi TEXT NOT NULL,
  loai TEXT NOT NULL CHECK (loai IN ('n', 'c')),
  nonce TEXT NOT NULL CHECK (length(nonce) BETWEEN 16 AND 128),
  het_han INTEGER NOT NULL,
  PRIMARY KEY (pham_vi, loai, nonce)
) WITHOUT ROWID;
CREATE INDEX idx_nonce_dung_het_han ON nonce_dung (het_han);

-- Cửa sổ trượt xấp xỉ (2 cửa sổ cố định có trọng số, như DO GioiHanToc): bat_dau căn theo bội số cửa sổ.
CREATE TABLE gioi_han_dem (
  khoa TEXT PRIMARY KEY CHECK (length(khoa) <= 256),
  bat_dau INTEGER NOT NULL,
  dem INTEGER NOT NULL,
  dem_truoc INTEGER NOT NULL,
  het_han INTEGER NOT NULL
) WITHOUT ROWID;
CREATE INDEX idx_gioi_han_dem_het_han ON gioi_han_dem (het_han);
