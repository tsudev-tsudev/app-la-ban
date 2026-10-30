// Giải mã CBOR (RFC 8949) TỐI GIẢN cho WebAuthn: attestationObject + khoá COSE. Chỉ độ dài xác định, không tag, không
// số thực; giới hạn độ sâu / kích thước để dữ liệu lạ không làm treo Worker. Hàm thuần.

export type GiaTriCbor = number | bigint | string | boolean | null | Uint8Array | GiaTriCbor[] | Map<GiaTriCbor, GiaTriCbor>;

const DO_SAU_TOI_DA = 8;
const PHAN_TU_TOI_DA = 256;

export class LoiCbor extends Error {}

/** Giải mã MỘT giá trị từ đầu [b]; trả giá trị + số byte đã đọc (authData chứa khoá COSE nối tiếp dữ liệu khác). */
export function giaiMaCbor(b: Uint8Array, batDau = 0): { giaTri: GiaTriCbor; ketThuc: number } {
  let i = batDau;
  const byte = (): number => {
    if (i >= b.length) throw new LoiCbor('het-du-lieu');
    return b[i++] as number;
  };
  const doDai = (phu: number): number => {
    if (phu < 24) return phu;
    let n = phu === 24 ? 1 : phu === 25 ? 2 : phu === 26 ? 4 : 0;
    if (n === 0) throw new LoiCbor('do-dai-khong-ho-tro');
    let kq = 0;
    while (n-- > 0) kq = kq * 256 + byte();
    return kq;
  };
  const doc = (sau: number): GiaTriCbor => {
    if (sau > DO_SAU_TOI_DA) throw new LoiCbor('qua-sau');
    const dau = byte();
    const loai = dau >> 5;
    const phu = dau & 0x1f;
    switch (loai) {
      case 0:
        return doDai(phu);
      case 1:
        return -1 - doDai(phu);
      case 2:
      case 3: {
        const n = doDai(phu);
        if (i + n > b.length) throw new LoiCbor('het-du-lieu');
        const doan = b.slice(i, i + n);
        i += n;
        return loai === 2 ? doan : new TextDecoder('utf-8', { fatal: true, ignoreBOM: false }).decode(doan);
      }
      case 4: {
        const n = doDai(phu);
        if (n > PHAN_TU_TOI_DA) throw new LoiCbor('qua-nhieu');
        const ds: GiaTriCbor[] = [];
        for (let k = 0; k < n; k++) ds.push(doc(sau + 1));
        return ds;
      }
      case 5: {
        const n = doDai(phu);
        if (n > PHAN_TU_TOI_DA) throw new LoiCbor('qua-nhieu');
        const m = new Map<GiaTriCbor, GiaTriCbor>();
        for (let k = 0; k < n; k++) {
          const khoa = doc(sau + 1);
          m.set(khoa, doc(sau + 1));
        }
        return m;
      }
      case 7:
        if (phu === 20) return false;
        if (phu === 21) return true;
        if (phu === 22) return null;
        throw new LoiCbor('kieu-don-khong-ho-tro');
      default:
        throw new LoiCbor('tag-khong-ho-tro');
    }
  };
  const giaTri = doc(0);
  return { giaTri, ketThuc: i };
}
