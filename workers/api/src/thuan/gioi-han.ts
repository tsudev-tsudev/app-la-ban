// SEC-API API-01: cửa sổ trượt xấp xỉ (2 cửa sổ cố định có trọng số) - O(1) bộ nhớ mỗi khoá, sai số nhỏ ở biên.

export type TrangThaiCuaSo = { batDau: number; dem: number; demTruoc: number };

export type KetQuaGioiHan = {
  choPhep: boolean;
  conLai: number;
  /** Giây nên chờ trước khi thử lại (header Retry-After), 0 khi được phép. */
  thuLaiSau: number;
  trangThai: TrangThaiCuaSo;
};

/** Ước lượng số yêu cầu trong [cuaSoMs] gần nhất. */
export function uocLuong(t: TrangThaiCuaSo, bayGio: number, cuaSoMs: number): number {
  const troiQua = Math.min(1, Math.max(0, (bayGio - t.batDau) / cuaSoMs));
  return t.demTruoc * (1 - troiQua) + t.dem;
}

/** Ghi nhận một yêu cầu (nếu được phép) và trả trạng thái mới. [cu] null = khoá mới. */
export function ghiNhan(cu: TrangThaiCuaSo | null, bayGio: number, gioiHan: number, cuaSoMs: number): KetQuaGioiHan {
  if (gioiHan < 1 || cuaSoMs < 1) throw new RangeError('giới hạn / cửa sổ phải >= 1');
  let t: TrangThaiCuaSo = cu ?? { batDau: bayGio - (bayGio % cuaSoMs), dem: 0, demTruoc: 0 };
  // Trượt sang cửa sổ cố định hiện tại.
  const soCuaSo = Math.floor((bayGio - t.batDau) / cuaSoMs);
  if (soCuaSo >= 2) t = { batDau: bayGio - (bayGio % cuaSoMs), dem: 0, demTruoc: 0 };
  else if (soCuaSo === 1) t = { batDau: t.batDau + cuaSoMs, dem: 0, demTruoc: t.dem };

  const daDung = uocLuong(t, bayGio, cuaSoMs);
  if (daDung + 1 > gioiHan) {
    // Chờ tới khi phần trọng số của cửa sổ trước giảm đủ (hoặc sang cửa sổ mới).
    const ketThuc = t.batDau + cuaSoMs;
    let cho = ketThuc - bayGio;
    if (t.demTruoc > 0 && t.dem + 1 <= gioiHan) {
      const tiLeCan = 1 - (gioiHan - 1 - t.dem) / t.demTruoc;
      cho = Math.max(0, t.batDau + tiLeCan * cuaSoMs - bayGio);
    }
    return { choPhep: false, conLai: 0, thuLaiSau: Math.max(1, Math.ceil(cho / 1000)), trangThai: t };
  }
  const moi = { ...t, dem: t.dem + 1 };
  return {
    choPhep: true,
    conLai: Math.max(0, Math.floor(gioiHan - uocLuong(moi, bayGio, cuaSoMs))),
    thuLaiSau: 0,
    trangThai: moi,
  };
}

export type ChieuGioiHan = 'ip' | 'thiet-bi' | 'phien' | 'endpoint';

export type LuatGioiHan = { chieu: ChieuGioiHan; gioiHan: number; cuaSoMs: number };

/** Khoá DO cho một chiều: `<chieu>:<giá trị>[:<endpoint>]` (giá trị đã chuẩn hoá, không chứa PII thô ngoài IP). */
export function khoaGioiHan(chieu: ChieuGioiHan, giaTri: string, endpoint?: string): string {
  return endpoint ? `${chieu}:${giaTri}:${endpoint}` : `${chieu}:${giaTri}`;
}
