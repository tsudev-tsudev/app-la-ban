// Hàm THUẦN về màu: đọc hex, độ chói tương đối và tỉ lệ tương phản theo WCAG 2.1 (mục 1.4.3 / 1.4.11).

/** '#RRGGBB' hoặc '#AARRGGBB' -> { r, g, b, a } (0-255, a 0-1). */
export function docHex(hex) {
  const m = /^#([0-9a-f]{6}|[0-9a-f]{8})$/i.exec(hex);
  if (!m) throw new Error(`Màu không hợp lệ: ${hex}`);
  const s = m[1];
  const co8 = s.length === 8;
  const a = co8 ? parseInt(s.slice(0, 2), 16) / 255 : 1;
  const o = co8 ? 2 : 0;
  return {
    r: parseInt(s.slice(o, o + 2), 16),
    g: parseInt(s.slice(o + 2, o + 4), 16),
    b: parseInt(s.slice(o + 4, o + 6), 16),
    a,
  };
}

function kenh(c) {
  const v = c / 255;
  return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
}

/** Độ chói tương đối (0 = đen, 1 = trắng), bỏ qua alpha. */
export function doChoi(hex) {
  const { r, g, b } = docHex(hex);
  return 0.2126 * kenh(r) + 0.7152 * kenh(g) + 0.0722 * kenh(b);
}

/** Tỉ lệ tương phản 1..21 giữa hai màu đặc. */
export function tuongPhan(a, b) {
  const l1 = doChoi(a);
  const l2 = doChoi(b);
  const [sang, toi] = l1 > l2 ? [l1, l2] : [l2, l1];
  return (sang + 0.05) / (toi + 0.05);
}

/**
 * Kiểm danh sách cặp { fg, bg, min, theme } trên bảng màu theo theme.
 * Trả mảng kết quả { theme, fg, bg, min, ratio, dat }.
 */
export function kiemCap(bangMau, cap) {
  return cap.flatMap(({ fg, bg, min }) =>
    Object.keys(bangMau).map((theme) => {
      const mau = bangMau[theme];
      if (!(fg in mau) || !(bg in mau)) throw new Error(`Thiếu token ${theme}.${fg} hoặc ${theme}.${bg}`);
      const ratio = tuongPhan(mau[fg], mau[bg]);
      return { theme, fg, bg, min, ratio, dat: ratio >= min };
    }),
  );
}
