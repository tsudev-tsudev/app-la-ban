// Hàm THUẦN: kiểm listing Google Play trong docs/store/play-listing.md (R2) - giới hạn ký tự + chính sách Metadata.
// Dùng bởi tools/build/kiem-listing.mjs (cổng day-du).

/** Giới hạn của Play Console (ký tự Unicode, không phải byte). */
export const GIOI_HAN = { ten: 30, ngan: 80, day: 4000 };

/** Từ ngữ xếp hạng / khuyến mãi Play cấm trong tên + mô tả ngắn (so khớp không phân biệt hoa thường). */
const CAM = [/\b(top|best|#1|no\.? ?1|free|sale|download now)\b/i, /(số 1|tốt nhất|miễn phí|giảm giá)/i];

const muc = (khoi, tieuDe) => {
  const m = khoi.match(new RegExp(`### ${tieuDe}\\n([\\s\\S]*?)(?=\\n### |$)`));
  return m ? m[1].trim() : null;
};

/** Tách khối `<!-- listing:<ma> -->` ... `<!-- /listing:<ma> -->` -> { ma: { ten, ngan, day } }. */
export function phanTichListing(md) {
  const ra = {};
  for (const m of md.matchAll(/<!-- listing:([a-z-]+) -->([\s\S]*?)<!-- \/listing:\1 -->/g)) {
    const [, ma, khoi] = m;
    const tieuDe = ma === 'vi' ? ['Tên', 'Mô tả ngắn', 'Mô tả đầy đủ'] : ['Title', 'Short description', 'Full description'];
    const [ten, ngan, day] = tieuDe.map((t) => muc(khoi, t));
    ra[ma] = { ten, ngan, day };
  }
  return ra;
}

/** Danh sách lỗi (rỗng = đạt). Cần đủ vi + en. */
export function kiemListing(ds) {
  const loi = [];
  for (const ma of ['vi', 'en']) {
    const l = ds[ma];
    if (!l) {
      loi.push(`${ma}: thiếu khối listing`);
      continue;
    }
    for (const k of Object.keys(GIOI_HAN)) {
      const v = l[k];
      if (!v) loi.push(`${ma}.${k}: trống`);
      else if ([...v].length > GIOI_HAN[k]) loi.push(`${ma}.${k}: ${[...v].length} > ${GIOI_HAN[k]} ký tự`);
    }
    for (const k of ['ten', 'ngan']) {
      if (l[k] && CAM.some((r) => r.test(l[k]))) loi.push(`${ma}.${k}: có từ xếp hạng / khuyến mãi`);
      if (l[k] && /\p{Extended_Pictographic}/u.test(l[k])) loi.push(`${ma}.${k}: có emoji`);
    }
  }
  return loi;
}
