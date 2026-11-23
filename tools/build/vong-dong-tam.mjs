// Hoạ tiết `vong-dong-tam` của bản sắc compass (tsudev-standards v5.0.0, DESIGN_SYSTEM 1.2.4): các vòng đồng tâm TĨNH
// quanh mặt la bàn, vạch chia 8 hướng ở vòng ngoài. Hàm THUẦN, tất định - dùng chung cho hero landing và og-image.
// Phủ <= 15%: nét mảnh, độ đục thấp, giảm dần ra ngoài.

/** @returns {{ vong: { r: number, w: number, a: number }[], vach: { x1: number, y1: number, x2: number, y2: number }[] }} */
export function vongDongTam({ cx = 300, cy = 300, rTrong = 70, rNgoai = 290, so = 6 } = {}) {
  if (so < 2 || rNgoai <= rTrong) throw new Error('vongDongTam: cần so >= 2 và rNgoai > rTrong');
  const buoc = (rNgoai - rTrong) / (so - 1);
  const vong = Array.from({ length: so }, (_, i) => ({
    r: +(rTrong + buoc * i).toFixed(2),
    w: i === so - 1 ? 1.5 : 1,
    a: +(0.5 - (0.35 * i) / (so - 1)).toFixed(3),
  }));
  const vach = [];
  for (let g = 0; g < 360; g += 45) {
    const rad = (g * Math.PI) / 180;
    const dai = g % 90 === 0 ? 18 : 10;
    const r1 = rNgoai - dai;
    const p = (r) => [+(cx + r * Math.sin(rad)).toFixed(2), +(cy - r * Math.cos(rad)).toFixed(2)];
    const [x1, y1] = p(r1);
    const [x2, y2] = p(rNgoai);
    vach.push({ x1, y1, x2, y2 });
  }
  return { vong, vach };
}

/** Chuỗi SVG (không có thẻ <svg> ngoài) - `mau` là màu nét (CSS var hoặc hex). */
export function svgVongDongTam(mau, tuyChon = {}) {
  const { cx = 300, cy = 300 } = tuyChon;
  const { vong, vach } = vongDongTam(tuyChon);
  const v = vong.map(
    (c) =>
      `<circle cx="${cx}" cy="${cy}" r="${c.r}" fill="none" stroke="${mau}" stroke-width="${c.w}" stroke-opacity="${c.a}"/>`,
  );
  const k = vach.map(
    (l) =>
      `<line x1="${l.x1}" y1="${l.y1}" x2="${l.x2}" y2="${l.y2}" stroke="${mau}" stroke-width="2" stroke-opacity="0.4" stroke-linecap="round"/>`,
  );
  return v.join('') + k.join('');
}
