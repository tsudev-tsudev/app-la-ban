#!/usr/bin/env node
// Trích gói tile vector Việt Nam từ bản PMTiles hành tinh của Protomaps (dữ liệu OSM, ODbL) bằng HTTP Range - QUYET_DINH Q37.
//   node tools/build/tile-vn.mjs --thu                 # chỉ đọc thư mục, in số tile + dung lượng theo zoom
//   node tools/build/tile-vn.mjs --ra build/tile/vn-0-13.pmtiles [--zmin 0] [--zmax 13] [--nguon <url>]
// Tách theo zoom (z0-13 ~255 MB + z14 ~225 MB) cho vừa giới hạn 300 MiB của `wrangler r2 object put`.
// Vùng = đất liền + quần đảo Hoàng Sa + Trường Sa (KHUNG_VN). Tải lên R2: tools/build/tai-tile.sh.
import { createHash } from 'node:crypto';
import { closeSync, createReadStream, mkdirSync, openSync, readFileSync, renameSync, rmSync, writeSync } from 'node:fs';
import { dirname } from 'node:path';
import { setTimeout as nghi } from 'node:timers/promises';
import { parseArgs } from 'node:util';
import {
  CO_HEADER, docHeader, dungThuMuc, ghiHeader, giaiThuMuc, gomLanDoc, gopChay, idRaZxy, idTrongVung, timMuc,
} from './pmtiles-luat.mjs';

// [tây, nam, đông, bắc] (độ).
export const KHUNG_VN = [
  [102.1, 8.3, 109.6, 23.45], // đất liền + ven biển
  [110.9, 15.6, 113.1, 17.2], // Hoàng Sa
  [111.4, 6.0, 117.9, 12.1], // Trường Sa
];

const { values: tham } = parseArgs({
  options: {
    thu: { type: 'boolean', default: false },
    ra: { type: 'string' },
    zmin: { type: 'string', default: '0' },
    zmax: { type: 'string', default: '14' },
    nguon: { type: 'string' },
  },
});
const zMin = Number(tham.zmin);
const zMax = Number(tham.zmax);
const homQua = new Date(Date.now() - 864e5).toISOString().slice(0, 10).replaceAll('-', '');
const NGUON = tham.nguon ?? `https://build.protomaps.com/${homQua}.pmtiles`;
if (!tham.thu && !tham.ra) throw new Error('cần --thu hoặc --ra <tệp>');

async function doc(vt, dai, lan = 0) {
  try {
    const r = await fetch(NGUON, { headers: { range: `bytes=${vt}-${vt + dai - 1}` } });
    if (r.status !== 206) throw new Error(`HTTP ${r.status}`);
    const b = Buffer.from(await r.arrayBuffer());
    if (b.length !== dai) throw new Error(`thiếu byte ${b.length}/${dai}`);
    return b;
  } catch (e) {
    if (lan >= 5) throw e;
    await nghi(1000 * 2 ** lan);
    return doc(vt, dai, lan + 1);
  }
}

// Chạy fn trên ds với tối đa `song` việc cùng lúc; trả kết quả theo đúng thứ tự qua onKetQua (ghi tuần tự).
async function chayTheoThuTu(ds, song, fn, onKetQua) {
  const cho = [];
  let i = 0;
  for (; i < Math.min(song, ds.length); i++) cho.push(fn(ds[i]));
  for (let j = 0; j < ds.length; j++) {
    const kq = await cho[j];
    if (i < ds.length) cho.push(fn(ds[i++]));
    await onKetQua(kq, ds[j]);
    cho[j] = null;
  }
}

const dau = await doc(0, 16384);
const h = docHeader(dau);
if (h.nenTrong !== 2) throw new Error('chỉ hỗ trợ thư mục nén gzip');
console.error(`nguồn ${NGUON}: z${h.zMin}-${h.zMax}, ${h.soTileDinhDanh} tile`);
const goc = giaiThuMuc(dau.subarray(h.gocVt, h.gocVt + h.gocDai));

// Tra từng id: mục lá cần đọc gom theo đợt (đọc song song), lặp tới khi hết lá.
const ids = idTrongVung(KHUNG_VN, Math.min(zMax, h.zMax), zMin);
const bo = new Map();
let cho = [...ids].map((id) => ({ id, dsMuc: goc }));
const tim = [];
while (cho.length) {
  const canLa = new Map();
  const sau = [];
  for (const c of cho) {
    const m = timMuc(c.dsMuc, c.id);
    if (!m) continue;
    if (m.chay > 0) tim.push({ id: c.id, vt: m.vt, dai: m.dai });
    else {
      if (!bo.has(m.vt)) canLa.set(m.vt, m);
      sau.push({ id: c.id, la: m.vt });
    }
  }
  await chayTheoThuTu([...canLa.values()], 16, (m) => doc(h.laVt + m.vt, m.dai), (b, m) => {
    bo.set(m.vt, giaiThuMuc(b));
  });
  cho = sau.map((s) => ({ id: s.id, dsMuc: bo.get(s.la) }));
}
tim.sort((a, b) => a.id - b.id);

const noiDung = new Map();
for (const t of tim) if (!noiDung.has(t.vt)) noiDung.set(t.vt, { vt: t.vt, dai: t.dai, z: idRaZxy(t.id)[0] });
const theoZoom = new Map();
for (const n of noiDung.values()) theoZoom.set(n.z, (theoZoom.get(n.z) ?? 0) + n.dai);
let cong = 0;
for (const [z, b] of [...theoZoom].sort((a, b) => a[0] - b[0])) {
  cong += b;
  console.error(`z${z}: ${(b / 1e6).toFixed(1)} MB, cộng dồn ${(cong / 1e6).toFixed(1)} MB`);
}
console.error(`${ids.length} id vùng, ${tim.length} có tile, ${noiDung.size} nội dung riêng, ${bo.size} thư mục lá đọc`);
if (tham.thu) process.exit(0);

// Dữ liệu mới theo thứ tự offset nguồn (nguồn đã gom theo id -> vẫn gom theo id).
const lanDoc = gomLanDoc([...noiDung.values()], 4096, 8 << 20);
const viTriMoi = new Map();
const ra = tham.ra;
mkdirSync(dirname(ra), { recursive: true });
const tepDuLieu = `${ra}.du-lieu`;
const fd = openSync(tepDuLieu, 'w');
let vtMoi = 0;
let daTai = 0;
await chayTheoThuTu(lanDoc, 8, (l) => doc(h.duLieuVt + l.vt, l.cuoi - l.vt), (b, l) => {
  for (const k of l.ds) {
    writeSync(fd, b, k.vt - l.vt, k.dai);
    viTriMoi.set(k.vt, vtMoi);
    vtMoi += k.dai;
  }
  daTai += b.length;
  process.stderr.write(`\rtải ${(daTai / 1e6).toFixed(0)} MB`);
});
closeSync(fd);
process.stderr.write('\n');

const ds = gopChay(tim.map((t) => ({ id: t.id, vt: viTriMoi.get(t.vt), dai: t.dai })));
// Gom theo id (spec): nội dung mới xuất hiện đúng ở offset kế tiếp; mục trùng trỏ về offset đã có.
let gom = true;
let ke = 0;
for (const m of ds) {
  if (m.vt === ke) ke += m.dai;
  else if (m.vt > ke) gom = false;
}
const { goc: gocMoi, la } = dungThuMuc(ds);
const meta = await doc(h.metaVt, h.metaDai);
const tay = Math.min(...KHUNG_VN.map((k) => k[0]));
const nam = Math.min(...KHUNG_VN.map((k) => k[1]));
const dong = Math.max(...KHUNG_VN.map((k) => k[2]));
const bac = Math.max(...KHUNG_VN.map((k) => k[3]));
const hMoi = {
  gocVt: CO_HEADER, gocDai: gocMoi.length,
  metaVt: CO_HEADER + gocMoi.length, metaDai: meta.length,
  laVt: CO_HEADER + gocMoi.length + meta.length, laDai: la.length,
  duLieuVt: CO_HEADER + gocMoi.length + meta.length + la.length, duLieuDai: vtMoi,
  soTileDinhDanh: tim.length, soMuc: ds.length, soNoiDung: noiDung.size,
  gom, nenTrong: 2, nenTile: h.nenTile, loaiTile: h.loaiTile, zMin, zMax: Math.min(zMax, h.zMax),
  khung: [tay, nam, dong, bac], zGiua: Math.max(zMin, 5), giua: [106.0, 16.0],
};
const tam = `${ra}.tam`;
const fo = openSync(tam, 'w');
for (const b of [ghiHeader(hMoi), gocMoi, meta, la]) writeSync(fo, b);
for await (const b of createReadStream(tepDuLieu, { highWaterMark: 8 << 20 })) writeSync(fo, b);
closeSync(fo);
rmSync(tepDuLieu);
renameSync(tam, ra);

// Kiểm lại: đọc header + vài tile từ tệp ra.
const kiem = readFileSync(ra);
const hk = docHeader(kiem);
if (hk.duLieuDai !== vtMoi || kiem.length !== hk.duLieuVt + hk.duLieuDai) throw new Error('độ dài tệp ra sai');
const sha = createHash('sha256').update(kiem).digest('hex');
console.log(JSON.stringify({ tep: ra, co: kiem.length, sha256: sha, zMax: hMoi.zMax, nguon: NGUON, gom }));
