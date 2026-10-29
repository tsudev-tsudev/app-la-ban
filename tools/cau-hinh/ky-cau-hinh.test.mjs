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
