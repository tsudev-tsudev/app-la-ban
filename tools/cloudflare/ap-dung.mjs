#!/usr/bin/env node
// Áp cấu hình Cloudflare dạng mã (SEC-EDGE EDG-07). MẶC ĐỊNH dry-run: chỉ in kế hoạch.
//   node tools/cloudflare/ap-dung.mjs            # xem sẽ đổi gì
//   node tools/cloudflare/ap-dung.mjs --apply    # thực hiện
// Token đọc từ ~/.config/la-ban/cf.env (CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_ZONE_ID) hoặc biến môi trường.
import { existsSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { dienId, lapKeHoach } from './ke-hoach.mjs';

const API = 'https://api.cloudflare.com/client/v4';
const goc = dirname(fileURLToPath(import.meta.url));
const apDung = process.argv.includes('--apply');

function napEnv() {
  const tep = join(homedir(), '.config/la-ban/cf.env');
  if (!existsSync(tep)) return;
  for (const dong of readFileSync(tep, 'utf8').split('\n')) {
    const m = /^\s*([A-Z_]+)\s*=\s*"?([^"\n]*)"?\s*$/.exec(dong);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
  }
}
napEnv();
const { CLOUDFLARE_API_TOKEN: token, CLOUDFLARE_ACCOUNT_ID: acc, CLOUDFLARE_ZONE_ID: zone } = process.env;
if (!token || !acc || !zone) {
  console.error('Thiếu CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID / CLOUDFLARE_ZONE_ID');
  process.exit(2);
}

async function goi(method, path, body) {
  const res = await fetch(API + path, {
    method,
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const j = await res.json().catch(() => ({ success: false, errors: [{ message: `HTTP ${res.status}` }] }));
  return j;
}

async function doc(path, macDinh) {
  const j = await goi('GET', path);
  if (!j.success) {
    const ma = j.errors?.[0]?.code;
    if (macDinh !== undefined && (ma === 10000 || ma === 8000007 || ma === 10006 || ma === 8000015 || ma === 7003)) return macDinh;
    throw new Error(`GET ${path}: ${JSON.stringify(j.errors)}`);
  }
  return j.result;
}

const muon = JSON.parse(readFileSync(join(goc, 'zone.json'), 'utf8'));

const caiDat = {};
for (const s of await doc(`/zones/${zone}/settings`)) caiDat[s.id] = s.value;
const dnssec = (await doc(`/zones/${zone}/dnssec`)).status;
const dns = await doc(`/zones/${zone}/dns_records?per_page=500`);
const pagesDomain = {};
for (const { project } of muon.pagesDomain) {
  pagesDomain[project] = (await doc(`/accounts/${acc}/pages/projects/${project}/domains`, [])).map((d) => d.name);
}
const r2Domain = {};
for (const { bucket } of muon.r2Domain) {
  r2Domain[bucket] = ((await doc(`/accounts/${acc}/r2/buckets/${bucket}/domains/custom`, { domains: [] })).domains ?? []).map((d) => d.domain);
}
const workerDomain = (await doc(`/accounts/${acc}/workers/domains?zone_id=${zone}`)).map((d) => d.hostname);
const headerRuleset = await doc(`/zones/${zone}/rulesets/phases/http_response_headers_transform/entrypoint`, null);

const phase = {};
for (const ten of new Set((muon.quyTac ?? []).map((q) => q.phase))) {
  const rs = await doc(`/zones/${zone}/rulesets/phases/${ten}/entrypoint`, null);
  phase[ten] = rs && { id: rs.id, rules: rs.rules ?? [] };
}
let rum = null;
if ((muon.rumLoaiTru ?? []).length) {
  const site = (await doc(`/accounts/${acc}/rum/site_info/list`, [])).find((x) => x.ruleset?.zone_tag === zone);
  if (site) {
    const r = await doc(`/accounts/${acc}/rum/v2/${site.ruleset.id}/rules`, null);
    rum = r && { id: site.ruleset.id, rules: r.rules ?? [] };
  }
}

const keHoach = lapKeHoach(muon, {
  caiDat,
  dnssec,
  dns,
  pagesDomain,
  r2Domain,
  workerDomain,
  headerRuleset: headerRuleset && { id: headerRuleset.id, rules: headerRuleset.rules ?? [] },
  phase,
  rum,
});

if (keHoach.length === 0) {
  console.log('✓ Cloudflare khớp tools/cloudflare/zone.json - không có gì để đổi.');
  process.exit(0);
}
console.log(`${apDung ? 'ÁP DỤNG' : 'DRY-RUN'} - ${keHoach.length} mục:`);
let loi = 0;
for (const h of keHoach) {
  console.log(`  [${h.loai}] ${h.moTa}`);
  if (!apDung || !h.method) continue;
  const { method, path, body } = dienId(h, zone, acc);
  const j = await goi(method, path, body);
  if (j.success) console.log('    ✓');
  else {
    loi++;
    console.log(`    ✗ ${JSON.stringify(j.errors)}`);
  }
}
if (!apDung) console.log('\nChạy lại với --apply để thực hiện.');
process.exit(loi ? 1 : 0);
