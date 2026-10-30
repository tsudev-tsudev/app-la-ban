// Bảng lệnh (Ctrl K) - phần thuần: chuẩn hoá tiếng Việt không dấu, xếp hạng khớp, nhận dạng ID / IP gõ vào.

export type Lenh = { id: string; nhan: string; nhom: string; tuKhoa?: string; chay: () => void };

/** Thường hoá + bỏ dấu tiếng Việt (gõ "canh bao" khớp "Cảnh báo"). */
export function khongDau(s: string): string {
  return s
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase();
}

/** Điểm khớp: 3 = đầu chuỗi, 2 = đầu một từ, 1 = chứa, 0 = mọi từ của truy vấn đều có mặt (bất kỳ thứ tự), -1 = không. */
export function diemKhop(nhan: string, q: string): number {
  const n = khongDau(nhan);
  const t = khongDau(q.trim());
  if (!t) return 1;
  if (n.startsWith(t)) return 3;
  if (n.includes(` ${t}`)) return 2;
  if (n.includes(t)) return 1;
  return t.split(/\s+/).every((w) => n.includes(w)) ? 0 : -1;
}

export function locLenh<T extends Pick<Lenh, 'nhan' | 'tuKhoa'>>(ds: readonly T[], q: string, toiDa = 12): T[] {
  return ds
    .map((l, i) => ({ l, i, d: Math.max(diemKhop(l.nhan, q), l.tuKhoa ? diemKhop(l.tuKhoa, q) : -1) }))
    .filter((x) => x.d >= 0)
    .sort((a, b) => b.d - a.d || a.i - b.i)
    .slice(0, toiDa)
    .map((x) => x.l);
}

/** Chuỗi gõ vào trông như gì: ULID / UUID (thiết bị hoặc cảnh báo), IPv4 / dải /24, IPv6. */
export function nhanDang(q: string): { loai: 'id' | 'ip'; giaTri: string } | null {
  const s = q.trim();
  if (/^[0-9A-Za-z]{26}$/.test(s) || /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(s)) return { loai: 'id', giaTri: s };
  const v4 = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(\/24)?$/.exec(s);
  if (v4 && v4.slice(1, 5).every((x) => Number(x) <= 255)) return { loai: 'ip', giaTri: s };
  if (/^[0-9a-fA-F:]{2,39}$/.test(s) && s.includes(':')) return { loai: 'ip', giaTri: s };
  return null;
}
