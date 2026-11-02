import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import { gzipSync } from 'node:zlib';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';
import { giaiMa } from './sao-luu.mjs';

async function napThuan() {
  const kq = await build({ entryPoints: [fileURLToPath(import.meta.resolve('../../workers/api/src/thuan/sao-luu.ts'))], bundle: true, format: 'esm', platform: 'node', write: false });
  return import(`data:text/javascript;base64,${Buffer.from(kq.outputFiles[0].text).toString('base64')}`);
}

test('giaiMa: bản Worker đóng gói -> SQL khôi phục, kiểm số dòng theo tiêu đề', async () => {
  const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const sl = await napThuan();
  const nd = sl.dongNdjson('devices', { id: 'd1' }) + sl.dongNdjson('audit_logs', { id: 'a1' });
  const congKhai = publicKey.export({ type: 'spki', format: 'der' }).toString('base64');
  const rieng = new Uint8Array(privateKey.export({ type: 'pkcs8', format: 'der' }));
  const tep = await sl.dongGoi(nd, new Uint8Array(gzipSync(nd)), { devices: 1, audit_logs: 1 }, congKhai, 'test', 0);
  const kq = await giaiMa(tep, rieng);
  assert.deepEqual(kq.dem, { devices: 1, audit_logs: 1 });
  assert.match(kq.sql, /INSERT INTO devices \("id"\) VALUES \('d1'\);/);
  const lech = await sl.dongGoi(nd, new Uint8Array(gzipSync(nd)), { devices: 2, audit_logs: 1 }, congKhai, 'test', 0);
  await assert.rejects(giaiMa(lech, rieng), /số dòng devices lệch/);
});
