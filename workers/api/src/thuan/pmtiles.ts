// A7a - đọc PMTiles v3 (spec: github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md) cho đường /ban-do của Worker.
// Phần thuần: id Hilbert, header, thư mục (đã giải nén). Giải nén gzip + đọc R2 ở src/ban-do.ts.
// Bản ghi tương ứng phía công cụ: tools/build/pmtiles-luat.mjs (tạo tệp); hai bên test theo cùng giá trị mẫu của spec.

export type HeaderPmtiles = {
  gocVt: number;
  gocDai: number;
  laVt: number;
  duLieuVt: number;
  nenTrong: number;
  nenTile: number;
  zMin: number;
  zMax: number;
};

/** Mục thư mục: chay = 0 -> trỏ thư mục lá (vt, dai trong vùng lá); ngược lại tile [id, id + chay) ở vùng dữ liệu. */
export type MucThuMuc = { id: number; chay: number; vt: number; dai: number };

export const DOC_DAU = 16384;

const truocZoom = (z: number): number => (4 ** z - 1) / 3;

/** Id Hilbert của tile; z <= 15 để phép bit nằm trong int32. */
export function zxyRaId(z: number, x: number, y: number): number {
  if (!Number.isInteger(z) || z < 0 || z > 15) throw new RangeError('zoom');
  const n = 2 ** z;
  if (!Number.isInteger(x) || !Number.isInteger(y) || x < 0 || y < 0 || x >= n || y >= n) throw new RangeError('xy');
  let px = x;
  let py = y;
  let d = 0;
  for (let s = n / 2; s >= 1; s /= 2) {
    const rx = (px & s) > 0 ? 1 : 0;
    const ry = (py & s) > 0 ? 1 : 0;
    d += s * s * ((3 * rx) ^ ry);
    if (ry === 0) {
      if (rx === 1) {
        px = s - 1 - px;
        py = s - 1 - py;
      }
      [px, py] = [py, px];
    }
  }
  return truocZoom(z) + d;
}

const u64 = (v: DataView, o: number): number => Number(v.getBigUint64(o, true));

export function docHeader(b: Uint8Array): HeaderPmtiles {
  if (b.length < 127 || String.fromCharCode(...b.subarray(0, 7)) !== 'PMTiles' || b[7] !== 3) throw new Error('khong-phai-pmtiles-v3');
  const v = new DataView(b.buffer, b.byteOffset, b.byteLength);
  return {
    gocVt: u64(v, 8),
    gocDai: u64(v, 16),
    laVt: u64(v, 40),
    duLieuVt: u64(v, 56),
    nenTrong: b[97] ?? 0,
    nenTile: b[98] ?? 0,
    zMin: b[100] ?? 0,
    zMax: b[101] ?? 0,
  };
}

/** Thư mục đã giải nén -> mục (offset 0 ở mục sau = nối liền mục trước). */
export function giaiThuMuc(b: Uint8Array): MucThuMuc[] {
  let i = 0;
  const varint = (): number => {
    let v = 0;
    let nhan = 1;
    for (;;) {
      const x = b[i++];
      if (x === undefined) throw new Error('varint-cut');
      v += (x & 0x7f) * nhan;
      if (x < 0x80) return v;
      nhan *= 128;
    }
  };
  const n = varint();
  const ds: MucThuMuc[] = Array.from({ length: n }, () => ({ id: 0, chay: 0, vt: 0, dai: 0 }));
  let id = 0;
  for (const m of ds) m.id = id += varint();
  for (const m of ds) m.chay = varint();
  for (const m of ds) m.dai = varint();
  let truoc: MucThuMuc | undefined;
  for (const m of ds) {
    const v = varint();
    m.vt = v === 0 && truoc ? truoc.vt + truoc.dai : v - 1;
    truoc = m;
  }
  return ds;
}

/** Mục chứa id (tile) hoặc mục lá cần đọc tiếp; null = không có tile. */
export function timMuc(ds: readonly MucThuMuc[], id: number): MucThuMuc | null {
  let lo = 0;
  let hi = ds.length - 1;
  while (lo <= hi) {
    const giua = (lo + hi) >> 1;
    if ((ds[giua] as MucThuMuc).id <= id) lo = giua + 1;
    else hi = giua - 1;
  }
  const m = ds[hi];
  if (!m) return null;
  if (m.chay === 0) return m;
  return id < m.id + m.chay ? m : null;
}
