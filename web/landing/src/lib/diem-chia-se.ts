// Hàm THUẦN: đọc token link chia sẻ điểm `compass.tsudev.com/w/<token>` - cùng định dạng với app
// (packages/waypoint_feature/lib/src/domain/token_chia_se.dart; vector test dùng chung). Token tự chứa, KHÔNG ký:
// nội dung là dữ liệu không tin cậy, trang chỉ gán bằng textContent.

export type DiemChiaSe = { ten: string; viDo: number; kinhDo: number; caoDo: number | null; ghiChu: string; hetHan: number };
export type LoiToken = 'hong' | 'phienBanLa' | 'hetHan';
export type KetQua = { diem: DiemChiaSe } | { loi: LoiToken };

const PHIEN_BAN = 1;
const TEN_TOI_DA = 120;
const GHI_CHU_TOI_DA = 140;

const BANG_CRC = (() => {
  const b = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    b[n] = c >>> 0;
  }
  return b;
})();

/** CRC-32 (IEEE 802.3, như zlib). */
export function crc32(b: Uint8Array): number {
  let c = 0xffffffff;
  for (const x of b) c = (BANG_CRC[(c ^ x) & 0xff] ?? 0) ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function base64Url(s: string): Uint8Array | null {
  const chuan = s.replace(/-/g, '+').replace(/_/g, '/');
  try {
    const nhiPhan = atob(chuan + '='.repeat((4 - (chuan.length % 4)) % 4));
    return Uint8Array.from(nhiPhan, (c) => c.charCodeAt(0));
  } catch {
    return null;
  }
}

const utf8 = new TextDecoder('utf-8', { fatal: true });

/** Đọc token; bayGio: giây UNIX. */
export function giaiMaToken(token: string, bayGio: number): KetQua {
  const hong: KetQua = { loi: 'hong' };
  if (!token || token.length > 4096 || !/^[A-Za-z0-9_-]+$/.test(token)) return hong;
  const b = base64Url(token);
  if (!b || b.length < 19) return hong;
  const than = b.subarray(0, b.length - 4);
  const dv = new DataView(b.buffer, b.byteOffset, b.byteLength);
  if (dv.getUint32(b.length - 4) !== crc32(than)) return hong;
  if (b[0] !== PHIEN_BAN) return { loi: 'phienBanLa' };
  const co = b[1] ?? 0;
  if (co & ~3) return hong;
  const viDo = dv.getInt32(2) / 1e7;
  const kinhDo = dv.getInt32(6) / 1e7;
  const hetHan = dv.getUint32(10);
  let i = 14;
  let caoDo: number | null = null;
  if (co & 1) {
    if (i + 4 > than.length) return hong;
    caoDo = dv.getInt32(i) / 10;
    i += 4;
  }
  const docChuoi = (): string | null => {
    let n = 0;
    let dich = 0;
    for (;;) {
      if (dich > 14 || i >= than.length) return null;
      const x = than[i++] ?? 0;
      n |= (x & 0x7f) << dich;
      if (x < 0x80) break;
      dich += 7;
    }
    if (i + n > than.length) return null;
    try {
      const s = utf8.decode(than.subarray(i, i + n));
      i += n;
      return s;
    } catch {
      return null;
    }
  };
  const ten = docChuoi();
  if (ten === null) return hong;
  let ghiChu = '';
  if (co & 2) {
    const g = docChuoi();
    if (g === null) return hong;
    ghiChu = g;
  }
  if (i !== than.length) return hong;
  if (
    !ten.trim() ||
    [...ten].length > TEN_TOI_DA ||
    [...ghiChu].length > GHI_CHU_TOI_DA ||
    Math.abs(viDo) > 90 ||
    Math.abs(kinhDo) > 180 ||
    (caoDo !== null && (caoDo < -12000 || caoDo > 20000))
  ) {
    return hong;
  }
  if (bayGio > hetHan) return { loi: 'hetHan' };
  return { diem: { ten, viDo, kinhDo, caoDo, ghiChu, hetHan } };
}

/** Token trong đường dẫn `/w/<token>` (bỏ `/` cuối); null nếu không khớp. */
export function tokenTuDuongDan(p: string): string | null {
  const m = /^\/w\/([A-Za-z0-9_-]+)\/?$/.exec(p);
  return m?.[1] ?? null;
}

/** Link Intent (Chrome Android) mở thẳng app; chưa cài app -> về trang tải. */
export function linkMoApp(token: string): string {
  const veTai = encodeURIComponent('https://compass.tsudev.com/tai-ve/');
  return `intent://compass.tsudev.com/w/${token}#Intent;scheme=https;package=com.tsudev.laban;S.browser_fallback_url=${veTai};end`;
}

/** Link xem điểm trên OpenStreetMap. */
export function linkBanDo(d: { viDo: number; kinhDo: number }): string {
  const v = d.viDo.toFixed(6);
  const k = d.kinhDo.toFixed(6);
  return `https://www.openstreetmap.org/?mlat=${v}&mlon=${k}#map=16/${v}/${k}`;
}
