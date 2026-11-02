#!/usr/bin/env node
// R3a (SEC-TEST, mục Web): tỷ lệ request TỰ ĐỘNG không token / token rác tới API được bảo vệ bị chặn hoặc challenge.
// Chỉ chạy vào STAGING (mặc định https://compass-api-stg.tsudev.com) - từ chối host prod. Mục tiêu >= 99 %.
//   node tools/thu/ty-le-chan.mjs [goc] [--so 210]
// "Bị chặn" = 4xx (401 / 403 / 429 / 400 / 415 / 422) hoặc trang challenge Cloudflare; 2xx = LỌT; 5xx = lỗi máy chủ (tính
// là không đạt - API bảo vệ không được sập trước request rác).
/* global URL, setTimeout */
const doiSo = process.argv.slice(2);
const GOC = doiSo.find((x) => x.startsWith('https://')) ?? 'https://compass-api-stg.tsudev.com';
const so = Number(doiSo[doiSo.indexOf('--so') + 1]) || 210;
const host = new URL(GOC).hostname;
if (['compass-api.tsudev.com', 'compass-admin.tsudev.com', 'compass.tsudev.com'].includes(host)) {
  console.error(`từ chối: ${host} là production`);
  process.exit(2);
}

const jwtRac = ['eyJ' + 'hbGciOiJFUzI1NiJ9', 'eyJ' + 'zdWIiOiJ4In0', 'x'.repeat(43)].join('.');
const DICH = [
  { m: 'GET', p: '/v1/status' },
  { m: 'GET', p: '/v1/device/me' },
  { m: 'POST', p: '/v1/events', b: { su_kien: [] } },
  { m: 'POST', p: '/v1/app/su-co', b: { ds: [] } },
  { m: 'POST', p: '/v1/device/attest', b: {} },
  { m: 'POST', p: '/v1/session/refresh', b: { refresh_token: 'rac' } },
  { m: 'GET', p: '/admin/v1/toi' },
  { m: 'GET', p: '/admin/v1/thiet-bi' },
  { m: 'POST', p: '/admin/v1/can-thiep', b: { loai: 'ip' } },
];
const TOKEN = [null, 'Bearer rac', `Bearer ${jwtRac}`];
const UA = ['python-requests/2.32', 'curl/8.9', 'Go-http-client/2.0', 'okhttp/4.12.0', 'Mozilla/5.0 (Linux; Android 14)'];

const dem = { chan: 0, lot: 0, loi: 0 };
const theoMa = new Map();
const lot = [];
for (let i = 0; i < so; i++) {
  const d = DICH[i % DICH.length];
  const tk = TOKEN[Math.floor(i / DICH.length) % TOKEN.length];
  const h = { 'user-agent': UA[i % UA.length], ...(tk ? { authorization: tk } : {}) };
  if (d.b) h['content-type'] = 'application/json';
  if (d.m === 'POST') h['idempotency-key'] = `r3a-${Date.now()}-${i}`;
  let ma;
  try {
    const r = await fetch(GOC + d.p, { method: d.m, headers: h, body: d.b ? JSON.stringify(d.b) : undefined, redirect: 'manual' });
    ma = r.status;
    await r.arrayBuffer();
  } catch {
    ma = -1;
  }
  theoMa.set(ma, (theoMa.get(ma) ?? 0) + 1);
  if (ma >= 400 && ma < 500) dem.chan++;
  else if (ma >= 200 && ma < 400) {
    dem.lot++;
    lot.push(`${d.m} ${d.p} ${tk ? 'token-rac' : 'khong-token'} -> ${ma}`);
  } else dem.loi++;
  await new Promise((r) => setTimeout(r, 120));
}
const tyLe = (dem.chan / so) * 100;
console.log(`đích ${GOC} · ${so} request · mã: ${[...theoMa].map(([k, v]) => `${k}x${v}`).join(' ')}`);
for (const l of lot.slice(0, 10)) console.log(`  LỌT ${l}`);
console.log(`bị chặn ${dem.chan} · lọt ${dem.lot} · lỗi ${dem.loi} -> ${tyLe.toFixed(2)} % (mục tiêu >= 99 %)`);
process.exit(tyLe >= 99 && dem.loi === 0 ? 0 : 1);
