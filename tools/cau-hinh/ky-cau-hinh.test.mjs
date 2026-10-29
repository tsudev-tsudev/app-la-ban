import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createPublicKey, generateKeyPairSync, verify } from 'node:crypto';
import { kyGoi, taoNoiDung } from './ky-cau-hinh.mjs';

test('kyGoi: chữ ký Ed25519 trên đúng byte duLieu', () => {
  const { privateKey } = generateKeyPairSync('ed25519');
  const nd = taoNoiDung({ landing: 'nhe', admin: 'chat', ngay: 30, bayGio: 1000 });
  const goi = kyGoi(privateKey, 'web-1', nd);
  const byte = Buffer.from(goi.duLieu, 'base64url');
  assert.deepEqual(JSON.parse(byte.toString('utf8')), { v: 1, phatHanh: 1000, het: 1000 + 30 * 86_400_000, muc: { landing: 'nhe', admin: 'chat' } });
  assert.equal(verify(null, byte, createPublicKey(privateKey), Buffer.from(goi.chuKy, 'base64url')), true);
  assert.match(goi.duLieu + goi.chuKy, /^[A-Za-z0-9_-]+$/);
});

test('taoNoiDung: mức / số ngày sai bị từ chối', () => {
  assert.throws(() => taoNoiDung({ landing: 'tat', admin: 'manh', ngay: 1, bayGio: 0 }));
  assert.throws(() => taoNoiDung({ landing: 'tat', admin: 'tat', ngay: 0, bayGio: 0 }));
  assert.throws(() => taoNoiDung({ landing: 'tat', admin: 'tat', ngay: 400, bayGio: 0 }));
});

test('taoNoiDungApp: mặc định = mọi pin đóng gói; ràng buộc build / cờ / pin', async () => {
  const { taoNoiDungApp } = await import('./ky-cau-hinh.mjs');
  const pinDongGoi = ['A'.repeat(43) + '=', 'B'.repeat(43) + '=', 'C'.repeat(43) + '='];
  const nd = taoNoiDungApp({ toiThieu: 5, khuyenNghi: 6, tat: ['ar', 'ban-do', 'ar'], pinDongGoi, ngay: 90, bayGio: 1000 });
  assert.deepEqual(nd, { v: 1, phatHanh: 1000, het: 1000 + 90 * 86_400_000, capNhat: { toiThieu: 5, khuyenNghi: 6 }, tat: ['ar', 'ban-do'], pin: pinDongGoi, gocThem: [] });
  const co = { pinDongGoi, ngay: 30, bayGio: 0 };
  assert.deepEqual(taoNoiDungApp({ ...co, pin: [pinDongGoi[2], pinDongGoi[0]] }).pin, [pinDongGoi[2], pinDongGoi[0]]);
  assert.throws(() => taoNoiDungApp({ ...co, pin: [pinDongGoi[0]] }), />= 2 pin/);
  assert.throws(() => taoNoiDungApp({ ...co, pin: [pinDongGoi[0], 'D'.repeat(43) + '='] }), /goc-them/);
  assert.throws(() => taoNoiDungApp({ ...co, toiThieu: 6, khuyenNghi: 5 }));
  assert.throws(() => taoNoiDungApp({ ...co, tat: ['camera'] }), /cờ lạ/);
  assert.throws(() => taoNoiDungApp({ ...co, ngay: 0 }));
});

test('taoNoiDungApp: CA mới qua --goc-them phải có pin trong --pin', async () => {
  const { taoNoiDungApp, pinPem } = await import('./ky-cau-hinh.mjs');
  const { readFileSync } = await import('node:fs');
  const { fileURLToPath } = await import('node:url');
  const pem = readFileSync(fileURLToPath(import.meta.resolve('../build/goc-tin-cay/ISRG_Root_X2.pem')), 'utf8');
  const p = pinPem(pem);
  assert.equal(p, 'diGVwiVYbubAI3RW4hB9xU8e/CH2GnkuvVFZE8zmgzI=');
  const khac = 'A'.repeat(43) + '=';
  assert.deepEqual(taoNoiDungApp({ pin: [khac, p], gocThem: [pem], pinDongGoi: [khac], ngay: 1, bayGio: 0 }).gocThem, [pem.trim()]);
  assert.throws(() => taoNoiDungApp({ pin: [khac, 'B'.repeat(43) + '='], gocThem: [pem], pinDongGoi: [khac, 'B'.repeat(43) + '='], ngay: 1, bayGio: 0 }), /không nằm trong/);
});
