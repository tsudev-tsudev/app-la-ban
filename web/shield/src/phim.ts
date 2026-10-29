// SH-02: phím tắt trang được phép chặn (trình duyệt vẫn cho mở công cụ qua menu - đây là lớp răn đe, không phải rào cứng).

export type PhimNhan = { key: string; code: string; ctrlKey: boolean; metaKey: boolean; altKey: boolean; shiftKey: boolean };

/** Loại thao tác của phím tắt: công cụ nhà phát triển, xem nguồn, lưu trang, in. */
export type LoaiPhim = 'devtools' | 'nguon' | 'luu' | 'in';

const DEVTOOLS = new Set(['KeyI', 'KeyJ', 'KeyC']);

/**
 * Nhận diện theo `code` (vị trí phím) vì trên macOS Option đổi `key` thành ký tự khác (⌥⌘I -> "ˆ"). Phím chữ không kèm
 * Ctrl / ⌘ không bao giờ bị chặn (gõ chữ trong ô nhập vẫn bình thường).
 */
export function phanLoaiPhim(p: PhimNhan): LoaiPhim | null {
  if (p.key === 'F12' || p.code === 'F12') return 'devtools';
  const mod = p.ctrlKey || p.metaKey;
  if (!mod) return null;
  if ((p.shiftKey || (p.metaKey && p.altKey)) && DEVTOOLS.has(p.code)) return 'devtools';
  if (p.shiftKey || p.altKey) return p.metaKey && p.altKey && p.code === 'KeyU' ? 'nguon' : null;
  if (p.code === 'KeyU') return 'nguon';
  if (p.code === 'KeyS') return 'luu';
  if (p.code === 'KeyP') return 'in';
  return null;
}
