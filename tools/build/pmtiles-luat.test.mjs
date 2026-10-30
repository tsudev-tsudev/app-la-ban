import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  docHeader, dungThuMuc, ghiHeader, giaiThuMuc, gomLanDoc, gopChay, idRaZxy, idTrongVung, maThuMuc, timMuc,
  tileTrongKhung, zxyRaId,
} from './pmtiles-luat.mjs';

test('id Hilbert khớp giá trị mẫu của spec', () => {
  assert.equal(zxyRaId(0, 0, 0), 0);
  assert.deepEqual([[1, 0, 0], [1, 0, 1], [1, 1, 1], [1, 1, 0]].map((t) => zxyRaId(...t)), [1, 2, 3, 4]);
  assert.equal(zxyRaId(2, 0, 0), 5);
  // Đường Hilbert kết thúc ở góc (n - 1, 0).
  assert.equal(zxyRaId(15, 32767, 0), (4 ** 15 - 1) / 3 + 4 ** 15 - 1);
});

test('zxy <-> id khứ hồi mọi tile z0-6 và mẫu z14', () => {
  for (let z = 0; z <= 6; z++) {
    for (let x = 0; x < 2 ** z; x++) for (let y = 0; y < 2 ** z; y++) assert.deepEqual(idRaZxy(zxyRaId(z, x, y)), [z, x, y]);
  }
  for (const [x, y] of [[13023, 7146], [12000, 8000], [16383, 16383]]) assert.deepEqual(idRaZxy(zxyRaId(14, x, y)), [14, x, y]);
});

test('khung Hà Nội ở z14 rơi đúng tile', () => {
  // 105.85, 21.03 -> x 13009,6 / y 7212,9 theo Web Mercator
  const { x0, x1, y0, y1 } = tileTrongKhung(14, [105.85, 21.03, 105.85, 21.03]);
  assert.deepEqual([x0, x1, y0, y1], [13009, 13009, 7212, 7212]);
});

test('idTrongVung sắp tăng, không trùng, gồm z0', () => {
  const ds = idTrongVung([[102, 8, 110, 24], [105, 20, 106, 21]], 5);
  assert.equal(ds[0], 0);
  for (let i = 1; i < ds.length; i++) assert.ok(ds[i] > ds[i - 1]);
});

test('thư mục mã hoá -> giải khứ hồi, offset liền kề nén về 0', () => {
  const ds = [
    { id: 0, chay: 1, vt: 0, dai: 10 },
    { id: 1, chay: 3, vt: 10, dai: 20 },
    { id: 9, chay: 1, vt: 5, dai: 7 },
    { id: 4 ** 10, chay: 0, vt: 1e10, dai: 300 },
  ];
  assert.deepEqual(giaiThuMuc(maThuMuc(ds)), ds);
});

test('timMuc: trong chạy, ngoài chạy, lá', () => {
  const ds = [{ id: 5, chay: 2, vt: 0, dai: 1 }, { id: 10, chay: 0, vt: 0, dai: 9 }];
  assert.equal(timMuc(ds, 4), null);
  assert.equal(timMuc(ds, 6).id, 5);
  assert.equal(timMuc(ds, 7), null);
  assert.equal(timMuc(ds, 99).id, 10);
});

test('gopChay gộp tile kề nhau cùng nội dung', () => {
  const ra = gopChay([
    { id: 1, vt: 0, dai: 5 }, { id: 2, vt: 0, dai: 5 }, { id: 3, vt: 5, dai: 2 }, { id: 5, vt: 5, dai: 2 },
  ]);
  assert.deepEqual(ra.map((m) => [m.id, m.chay]), [[1, 2], [3, 1], [5, 1]]);
});

test('dungThuMuc: nhiều mục -> gốc <= 16 KiB trỏ lá, tra được mọi id', () => {
  const ds = Array.from({ length: 60000 }, (_, i) => ({ id: i * 3, chay: 1, vt: i * 1000 + (i % 7), dai: 900 + (i % 13) }));
  const { goc, la } = dungThuMuc(ds);
  assert.ok(goc.length <= 16384 - 127);
  const tro = giaiThuMuc(goc);
  for (const i of [0, 1, 4095, 4096, 59999]) {
    const m = timMuc(tro, i * 3);
    assert.equal(m.chay, 0);
    const lo = giaiThuMuc(la.subarray(m.vt, m.vt + m.dai));
    assert.deepEqual(timMuc(lo, i * 3), ds[i]);
  }
});

test('header ghi -> đọc khứ hồi', () => {
  const h = {
    gocVt: 127, gocDai: 100, metaVt: 227, metaDai: 50, laVt: 277, laDai: 0, duLieuVt: 277, duLieuDai: 2 ** 40,
    soTileDinhDanh: 7, soMuc: 6, soNoiDung: 5, gom: true, nenTrong: 2, nenTile: 2, loaiTile: 1, zMin: 0, zMax: 14,
    khung: [102.1, 6, 117.9, 23.45], zGiua: 5, giua: [106, 16],
  };
  assert.deepEqual(docHeader(ghiHeader(h)), h);
});

test('gomLanDoc nối khoảng gần, tách khi xa hoặc quá lớn', () => {
  const ra = gomLanDoc([{ vt: 100, dai: 10 }, { vt: 0, dai: 50 }, { vt: 5000, dai: 10 }, { vt: 5010, dai: 100 }], 100, 1000);
  assert.deepEqual(ra.map((l) => [l.vt, l.cuoi, l.ds.length]), [[0, 110, 2], [5000, 5110, 2]]);
  assert.equal(gomLanDoc([{ vt: 0, dai: 600 }, { vt: 600, dai: 600 }], 100, 1000).length, 2);
});
