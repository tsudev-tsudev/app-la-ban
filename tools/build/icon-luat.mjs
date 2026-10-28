// Hàm THUẦN kiểm quy ước bộ icon 24dp (Spec §2.3): lưới 24, nét 2, đầu / góc tròn, không tô, màu theo currentColor.
const BAT_BUOC = {
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  'stroke-width': '2',
  'stroke-linecap': 'round',
  'stroke-linejoin': 'round',
};

/** Trả mảng lỗi (rỗng = đạt) cho nội dung một tệp SVG icon. */
export function kiemIcon(noiDung) {
  const loi = [];
  const goc = /<svg\b([^>]*)>/.exec(noiDung);
  if (!goc) return ['không có thẻ <svg>'];
  const thuocTinh = Object.fromEntries([...goc[1].matchAll(/([\w-]+)="([^"]*)"/g)].map((m) => [m[1], m[2]]));
  for (const [k, v] of Object.entries(BAT_BUOC)) {
    if (thuocTinh[k] !== v) loi.push(`<svg ${k}> phải là "${v}" (đang "${thuocTinh[k] ?? ''}")`);
  }
  const ben = noiDung.slice(goc.index + goc[0].length);
  if (/\b(fill|stroke)="(?!none|currentColor)[^"]*"/.test(ben)) loi.push('phần tử con có màu cứng (chỉ none / currentColor)');
  if (/stroke-width=/.test(ben)) loi.push('phần tử con đổi độ dày nét');
  if (/<(text|image|style|script)\b/.test(ben)) loi.push('có <text> / <image> / <style> / <script>');
  if (/#[0-9a-f]{3,8}\b/i.test(ben)) loi.push('có mã màu hex');
  return loi;
}
