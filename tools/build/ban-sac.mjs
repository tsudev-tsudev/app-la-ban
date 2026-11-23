// Bản sắc sản phẩm (tsudev-standards v5.0.0, phiếu STD50): bảng màu KHÔNG khai tại repo này.
// Lớp nền (nền / chữ / viền / trạng thái) lấy từ .standards/tokens/design-tokens.json, lớp sản phẩm
// (màu chính / nhấn / glow) lấy từ .standards/tokens/products/compass.json, rồi ánh xạ sang tên vai trò
// của design_system (LbColors) lúc build. Hàm THUẦN: gopMau(nen, sanPham); docTokens() đọc tệp.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tuongPhan } from './mau.mjs';

export const MA_SAN_PHAM = 'compass';
const THEME = ['light', 'dark'];

/** 'rgba(r, g, b, a)' | '#RRGGBB' -> { r, g, b, a }. */
export function docMau(s) {
  const m = /^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)$/i.exec(s);
  if (m) return { r: +m[1], g: +m[2], b: +m[3], a: m[4] === undefined ? 1 : +m[4] };
  const h = /^#([0-9a-f]{6})$/i.exec(s);
  if (!h) throw new Error(`Màu không hợp lệ: ${s}`);
  const n = parseInt(h[1], 16);
  return { r: n >> 16, g: (n >> 8) & 255, b: n & 255, a: 1 };
}

const hai = (v) => Math.round(v).toString(16).padStart(2, '0').toUpperCase();

/** Màu (có thể trong suốt) -> '#RRGGBB' hoặc '#AARRGGBB' (định dạng của design_system). */
export function hexAlpha(s) {
  const { r, g, b, a } = docMau(s);
  return a === 1 ? `#${hai(r)}${hai(g)}${hai(b)}` : `#${hai(a * 255)}${hai(r)}${hai(g)}${hai(b)}`;
}

/** Phủ màu trong suốt `tren` lên nền đặc `duoi` -> '#RRGGBB'. */
export function phu(tren, duoi) {
  const t = docMau(tren);
  const d = docMau(duoi);
  const k = (x, y) => x * t.a + y * (1 - t.a);
  return `#${hai(k(t.r, d.r))}${hai(k(t.g, d.g))}${hai(k(t.b, d.b))}`;
}

/**
 * Bản an toàn cho chữ: pha dần `mau` về đen (theme sáng) / trắng (theme tối) tới khi đạt `min` trên mọi nền.
 * Màu đã đạt thì giữ nguyên - chỉ dẫn xuất, không khai màu mới.
 */
export function chuAnToan(mau, nens, toi, min = 4.5) {
  const dich = toi ? 255 : 0;
  const { r, g, b } = docMau(mau);
  for (let i = 0; i <= 100; i++) {
    const k = (x) => x + (dich - x) * (i / 100);
    const ung = `#${hai(k(r))}${hai(k(g))}${hai(k(b))}`;
    if (nens.every((n) => tuongPhan(ung, n) >= min)) return i === 0 ? mau : ung;
  }
  throw new Error(`Không dẫn xuất được màu chữ an toàn từ ${mau}`);
}

/**
 * nen = color.<theme> của design-tokens.json; sp = colors.<theme> của products/<id>.json.
 * Trả bảng màu theo tên vai trò LbColors (cùng bộ khoá, cùng thứ tự cho light / dark).
 */
export function gopMauTheme(nen, sp, theme) {
  const c = { ...nen, ...sp };
  const toi = theme === 'dark';
  const nens = [c['bg-base'], c['bg-subtle'], c['bg-surface']];
  const manh = (k) => chuAnToan(c[k], nens, toi);
  return {
    primary: c.primary,
    primaryDeep: c['primary-hover'],
    secondary: c['text-link'],
    accent: c.accent,
    accentStrong: manh('accent'),
    bg: c['bg-base'],
    surface: c['bg-subtle'],
    surfaceRaised: c['bg-surface'],
    outline: c.border,
    outlineStrong: c['border-control'],
    text: c['text-primary'],
    textMuted: c['text-muted'],
    onPrimary: c['on-primary'],
    onPrimaryDeep: c['on-primary'],
    onAccent: c['on-primary'],
    danger: c.danger,
    dangerStrong: manh('danger'),
    onDanger: c['on-status'],
    warning: c.warning,
    warningStrong: manh('warning'),
    onWarning: c['on-status'],
    success: c.success,
    successStrong: manh('success'),
    onSuccess: c['on-status'],
    scrim: hexAlpha(c.overlay),
    gradientStart: toi ? c.primary : c['primary-active'],
    gradientEnd: toi ? c.accent : c.primary,
    onGradient: c['on-primary'],
    tint: phu(c.glow, c['bg-base']),
  };
}

export function gopMau(nen, sanPham) {
  if (!sanPham?.colors) throw new Error('products/<id>.json thiếu colors');
  const ra = {};
  for (const t of THEME) ra[t] = gopMauTheme(nen.color[t], sanPham.colors[t], t);
  return ra;
}

/**
 * Bo góc theo `shape` của sản phẩm: bảng shape KHÔNG có dạng máy đọc trong bộ quy ước, chỉ có trong products.css
 * sinh ra -> đọc khối `:root[data-product="<id>"]` lấy --radius-sm/md/lg/control (px).
 */
export function docBoGoc(css, id) {
  const m = new RegExp(`:root\\[data-product="${id}"\\]\\s*\\{([^}]*)\\}`).exec(css);
  if (!m) throw new Error(`products.css thiếu khối data-product="${id}"`);
  const ra = {};
  for (const [, k, v] of m[1].matchAll(/--radius-(sm|md|lg|control):\s*(\d+)px/g)) ra[k] = Number(v);
  for (const k of ['sm', 'md', 'lg', 'control']) if (!(k in ra)) throw new Error(`products.css thiếu --radius-${k} của ${id}`);
  return ra;
}

/** Đọc design/tokens.json + lớp nền + lớp sản phẩm -> tokens đầy đủ (có color đã gộp). */
export function docTokens(goc = join(dirname(fileURLToPath(import.meta.url)), '../..')) {
  const doc = (p) => JSON.parse(readFileSync(join(goc, p), 'utf8'));
  const tokens = doc('design/tokens.json');
  const nen = doc('.standards/tokens/design-tokens.json');
  const sp = doc(`.standards/tokens/products/${MA_SAN_PHAM}.json`);
  const boGoc = docBoGoc(readFileSync(join(goc, '.standards/tokens/products.css'), 'utf8'), sp.id);
  return { ...tokens, color: gopMau(nen, sp), radius: { ...tokens.radius, ...boGoc } };
}
