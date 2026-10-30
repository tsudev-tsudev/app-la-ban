// Hàm thuần đọc / ghi PMTiles v3 (https://github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md) cho tile-vn.mjs.
// Tự viết thay CLI go-pmtiles: không chạy binary ngoài, chỉ cần phần trích vùng + ghi lại thư mục.
import { gunzipSync, gzipSync } from 'node:zlib';

export const CO_HEADER = 127;
// Số tile của mọi mức zoom thấp hơn z: (4^z - 1) / 3.
const truocZoom = (z) => (4 ** z - 1) / 3;

function xoay(n, xy, rx, ry) {
  if (ry === 0) {
    if (rx === 1) {
      xy[0] = n - 1 - xy[0];
      xy[1] = n - 1 - xy[1];
    }
    [xy[0], xy[1]] = [xy[1], xy[0]];
  }
}

// z <= 15 để mọi phép bit nằm trong int32.
export function zxyRaId(z, x, y) {
  if (z > 15) throw new Error('zoom > 15');
  const xy = [x, y];
  let d = 0;
  for (let s = 2 ** z / 2; s >= 1; s /= 2) {
    const rx = (xy[0] & s) > 0 ? 1 : 0;
    const ry = (xy[1] & s) > 0 ? 1 : 0;
    d += s * s * ((3 * rx) ^ ry);
    xoay(s, xy, rx, ry);
  }
  return truocZoom(z) + d;
}

export function idRaZxy(id) {
  let z = 0;
  while (truocZoom(z + 1) <= id) z++;
  let t = id - truocZoom(z);
  const xy = [0, 0];
  for (let s = 1; s < 2 ** z; s *= 2) {
    const rx = 1 & Math.floor(t / 2);
    const ry = 1 & (t ^ rx);
    xoay(s, xy, rx, ry);
    xy[0] += s * rx;
    xy[1] += s * ry;
    t = Math.floor(t / 4);
  }
  return [z, xy[0], xy[1]];
}

// Tile (x, y) phủ hình chữ nhật [tây, nam, đông, bắc] (độ) ở zoom z - Web Mercator.
export function tileTrongKhung(z, [tay, nam, dong, bac]) {
  const n = 2 ** z;
  const tx = (lon) => Math.min(n - 1, Math.max(0, Math.floor(((lon + 180) / 360) * n)));
  const ty = (lat) => {
    const r = (lat * Math.PI) / 180;
    return Math.min(n - 1, Math.max(0, Math.floor(((1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2) * n)));
  };
  return { x0: tx(tay), x1: tx(dong), y0: ty(bac), y1: ty(nam) };
}

// Tập id (đã sắp, không trùng) của mọi tile zMin..zMax giao một trong các khung.
export function idTrongVung(dsKhung, zMax, zMin = 0) {
  const tap = new Set();
  for (let z = zMin; z <= zMax; z++) {
    for (const k of dsKhung) {
      const { x0, x1, y0, y1 } = tileTrongKhung(z, k);
      for (let x = x0; x <= x1; x++) for (let y = y0; y <= y1; y++) tap.add(zxyRaId(z, x, y));
    }
  }
  return Float64Array.from(tap).sort();
}

function docVarint(buf, vt) {
  let v = 0;
  let nhan = 1;
  for (;;) {
    const b = buf[vt.i++];
    if (b === undefined) throw new Error('varint cụt');
    v += (b & 0x7f) * nhan;
    if (b < 0x80) return v;
    nhan *= 128;
  }
}

function ghiVarint(ra, v) {
  while (v >= 0x80) {
    ra.push((v % 128) | 0x80);
    v = Math.floor(v / 128);
  }
  ra.push(v);
}

// Mục thư mục: { id, chay (run length; 0 = trỏ thư mục lá), vt (offset), dai (length) }.
export function giaiThuMuc(nen) {
  const buf = gunzipSync(nen);
  const vt = { i: 0 };
  const n = docVarint(buf, vt);
  const ds = Array.from({ length: n }, () => ({ id: 0, chay: 0, vt: 0, dai: 0 }));
  let id = 0;
  for (const m of ds) m.id = id += docVarint(buf, vt);
  for (const m of ds) m.chay = docVarint(buf, vt);
  for (const m of ds) m.dai = docVarint(buf, vt);
  ds.forEach((m, i) => {
    const v = docVarint(buf, vt);
    m.vt = v === 0 && i > 0 ? ds[i - 1].vt + ds[i - 1].dai : v - 1;
  });
  return ds;
}

export function maThuMuc(ds) {
  const ra = [];
  ghiVarint(ra, ds.length);
  let truoc = 0;
  for (const m of ds) {
    ghiVarint(ra, m.id - truoc);
    truoc = m.id;
  }
  for (const m of ds) ghiVarint(ra, m.chay);
  for (const m of ds) ghiVarint(ra, m.dai);
  ds.forEach((m, i) => ghiVarint(ra, i > 0 && m.vt === ds[i - 1].vt + ds[i - 1].dai ? 0 : m.vt + 1));
  return gzipSync(Buffer.from(ra), { level: 9 });
}

// Mục chứa id (mục tile) hoặc mục lá cần đọc tiếp; null nếu không có.
export function timMuc(ds, id) {
  let lo = 0;
  let hi = ds.length - 1;
  while (lo <= hi) {
    const giua = (lo + hi) >> 1;
    if (ds[giua].id <= id) lo = giua + 1;
    else hi = giua - 1;
  }
  const m = ds[hi];
  if (!m) return null;
  if (m.chay === 0) return m;
  return id < m.id + m.chay ? m : null;
}

const TRUONG = [
  ['gocVt', 8], ['gocDai', 16], ['metaVt', 24], ['metaDai', 32], ['laVt', 40], ['laDai', 48],
  ['duLieuVt', 56], ['duLieuDai', 64], ['soTileDinhDanh', 72], ['soMuc', 80], ['soNoiDung', 88],
];

export function docHeader(buf) {
  if (buf.subarray(0, 7).toString('latin1') !== 'PMTiles' || buf[7] !== 3) throw new Error('không phải PMTiles v3');
  const h = Object.fromEntries(TRUONG.map(([k, o]) => [k, Number(buf.readBigUInt64LE(o))]));
  return {
    ...h,
    gom: buf[96] === 1, nenTrong: buf[97], nenTile: buf[98], loaiTile: buf[99], zMin: buf[100], zMax: buf[101],
    khung: [102, 106, 110, 114].map((o) => buf.readInt32LE(o) / 1e7),
    zGiua: buf[118], giua: [119, 123].map((o) => buf.readInt32LE(o) / 1e7),
  };
}

export function ghiHeader(h) {
  const buf = Buffer.alloc(CO_HEADER);
  buf.write('PMTiles', 0, 'latin1');
  buf[7] = 3;
  for (const [k, o] of TRUONG) buf.writeBigUInt64LE(BigInt(h[k]), o);
  buf[96] = h.gom ? 1 : 0;
  buf[97] = h.nenTrong;
  buf[98] = h.nenTile;
  buf[99] = h.loaiTile;
  buf[100] = h.zMin;
  buf[101] = h.zMax;
  [102, 106, 110, 114].forEach((o, i) => buf.writeInt32LE(Math.round(h.khung[i] * 1e7), o));
  buf[118] = h.zGiua;
  [119, 123].forEach((o, i) => buf.writeInt32LE(Math.round(h.giua[i] * 1e7), o));
  return buf;
}

// Gộp mục tile liên tiếp cùng nội dung (id kề nhau, cùng vt) thành một mục chạy dài.
export function gopChay(ds) {
  const ra = [];
  for (const m of ds) {
    const t = ra.at(-1);
    if (t && t.vt === m.vt && t.dai === m.dai && t.id + t.chay === m.id) t.chay++;
    else ra.push({ ...m, chay: 1 });
  }
  return ra;
}

// Thư mục gốc + lá như go-pmtiles: gốc <= 16 KiB (đủ nằm trong lần đọc đầu 16 KiB); không vừa thì chia lá
// cỡ tăng dần.
export function dungThuMuc(ds) {
  const goc = maThuMuc(ds);
  if (goc.length <= 16384 - CO_HEADER) return { goc, la: Buffer.alloc(0) };
  for (let co = 4096; ; co *= 2) {
    const la = [];
    const tro = [];
    let vt = 0;
    for (let i = 0; i < ds.length; i += co) {
      const b = maThuMuc(ds.slice(i, i + co));
      tro.push({ id: ds[i].id, chay: 0, vt, dai: b.length });
      la.push(b);
      vt += b.length;
    }
    const g = maThuMuc(tro);
    if (g.length <= 16384 - CO_HEADER) return { goc: g, la: Buffer.concat(la) };
  }
}

// Gom các khoảng [vt, vt + dai) thành lần đọc HTTP, nối khi khe < khe byte và lần đọc <= toiDa byte.
export function gomLanDoc(dsKhoang, khe, toiDa) {
  const sx = [...dsKhoang].sort((a, b) => a.vt - b.vt);
  const ra = [];
  for (const k of sx) {
    const t = ra.at(-1);
    const cuoi = k.vt + k.dai;
    if (t && k.vt <= t.cuoi + khe && Math.max(cuoi, t.cuoi) - t.vt <= toiDa) {
      t.cuoi = Math.max(t.cuoi, cuoi);
      t.ds.push(k);
    } else ra.push({ vt: k.vt, cuoi, ds: [k] });
  }
  return ra;
}
