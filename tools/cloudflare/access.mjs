#!/usr/bin/env node
// Cloudflare Zero Trust Access cho Admin SOC (S6, SEC-ADM) dạng mã. MẶC ĐỊNH dry-run: chỉ in kế hoạch.
//   node tools/cloudflare/access.mjs            # xem sẽ đổi gì
//   node tools/cloudflare/access.mjs --apply    # thực hiện (idempotent, chạy lại an toàn)
// Làm: IdP One-time PIN (email) · ứng dụng Access "la-ban-admin" (compass-admin + *.la-ban-admin.pages.dev, phiên 8 giờ,
// cookie HttpOnly + SameSite=Strict) · policy cho phép đúng danh sách email · service token thử e2e (chỉ staging nhận) ·
// biến môi trường ACCESS_TEAM / ACCESS_AUD + service binding API cho Pages la-ban-admin.
// Email quản trị là dữ liệu cá nhân -> NGOÀI repo: ~/.config/la-ban/cau-hinh/admin-emails.txt (mỗi dòng một email).
// Token cần thêm quyền: Access: Apps and Policies Edit · Access: Service Tokens Edit · Access: Organizations, Identity
// Providers, and Groups Edit (+ Cloudflare Pages Edit đã có).
import { chmodSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const API = 'https://api.cloudflare.com/client/v4';
const apDung = process.argv.includes('--apply');
const TEAM = 'purple-cake-8f2a.cloudflareaccess.com';
const TEN_APP = 'la-ban-admin';
const MIEN = ['compass-admin.tsudev.com', 'la-ban-admin.pages.dev', '*.la-ban-admin.pages.dev'];
const TEN_TOKEN = 'la-ban-soc-e2e';
const THU_MUC = join(homedir(), '.config/la-ban/cau-hinh');

function napEnv() {
  const tep = join(homedir(), '.config/la-ban/cf.env');
  if (!existsSync(tep)) return;
  for (const dong of readFileSync(tep, 'utf8').split('\n')) {
    const m = /^\s*([A-Z_]+)\s*=\s*"?([^"\n]*)"?\s*$/.exec(dong);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
  }
}
napEnv();
const { CLOUDFLARE_API_TOKEN: token, CLOUDFLARE_ACCOUNT_ID: acc } = process.env;
if (!token || !acc) {
  console.error('Thiếu CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID');
  process.exit(2);
}

async function goi(method, path, body) {
  const res = await fetch(API + path, {
    method,
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const j = await res.json().catch(() => ({ success: false, errors: [{ message: `HTTP ${res.status}` }] }));
  if (!j.success) throw new Error(`${method} ${path}: ${JSON.stringify(j.errors)}`);
  return j.result;
}

const tepEmail = join(THU_MUC, 'admin-emails.txt');
const emails = existsSync(tepEmail)
  ? readFileSync(tepEmail, 'utf8')
      .split('\n')
      .map((x) => x.trim().toLowerCase())
      .filter((x) => /^[^\s@#]+@[^\s@]+$/.test(x))
  : [];
if (emails.length === 0) {
  console.error(`Chưa có email quản trị trong ${tepEmail}`);
  process.exit(2);
}

const ke = [];
const lam = async (moTa, fn) => {
  ke.push(moTa);
  console.log(`${apDung ? '•' : '(dry-run)'} ${moTa}`);
  return apDung ? fn() : null;
};

// 1. IdP One-time PIN
const dsIdp = await goi('GET', `/accounts/${acc}/access/identity_providers`);
let otp = dsIdp.find((x) => x.type === 'onetimepin');
if (!otp) otp = await lam('Tạo IdP One-time PIN (email)', () => goi('POST', `/accounts/${acc}/access/identity_providers`, { name: 'Email OTP', type: 'onetimepin', config: {} }));

// 2. Service token thử e2e (bí mật chỉ hiện MỘT lần lúc tạo -> lưu ngoài repo, quyền 600)
const dsToken = await goi('GET', `/accounts/${acc}/access/service_tokens`);
let st = dsToken.find((x) => x.name === TEN_TOKEN);
if (!st) {
  st = await lam(`Tạo service token ${TEN_TOKEN} (thời hạn 1 năm)`, async () => {
    const r = await goi('POST', `/accounts/${acc}/access/service_tokens`, { name: TEN_TOKEN, duration: '8760h' });
    mkdirSync(THU_MUC, { recursive: true, mode: 0o700 });
    const tep = join(THU_MUC, 'access-svc-e2e.json');
    writeFileSync(tep, JSON.stringify({ client_id: r.client_id, client_secret: r.client_secret }, null, 2), { mode: 0o600 });
    chmodSync(tep, 0o600);
    return r;
  });
}

// 3. Ứng dụng Access
const muonApp = {
  name: TEN_APP,
  type: 'self_hosted',
  domain: MIEN[0],
  destinations: MIEN.map((uri) => ({ type: 'public', uri })),
  session_duration: '8h',
  app_launcher_visible: false,
  auto_redirect_to_identity: true,
  allowed_idps: otp ? [otp.id] : [],
  http_only_cookie_attribute: true,
  same_site_cookie_attribute: 'strict',
  skip_interstitial: true,
  policies: [
    { name: 'la-ban-admin: email quản trị', decision: 'allow', include: emails.map((email) => ({ email: { email } })), precedence: 1 },
    ...(st ? [{ name: 'la-ban-admin: service token e2e', decision: 'non_identity', include: [{ service_token: { token_id: st.id } }], precedence: 2 }] : []),
  ],
};
const dsApp = await goi('GET', `/accounts/${acc}/access/apps`);
const cu = dsApp.find((x) => x.name === TEN_APP);
const app = cu
  ? await lam(`Cập nhật ứng dụng Access ${TEN_APP} (${emails.length} email)`, () => goi('PUT', `/accounts/${acc}/access/apps/${cu.id}`, muonApp))
  : await lam(`Tạo ứng dụng Access ${TEN_APP} cho ${MIEN.join(', ')} (${emails.length} email)`, () => goi('POST', `/accounts/${acc}/access/apps`, muonApp));
const aud = app?.aud ?? cu?.aud ?? null;

// 4. Pages la-ban-admin: biến Access + service binding API (prod -> la-ban-api, preview -> la-ban-api-staging)
if (aud) {
  const bien = { ACCESS_TEAM: { type: 'plain_text', value: TEAM }, ACCESS_AUD: { type: 'plain_text', value: aud } };
  await lam('Đặt ACCESS_TEAM / ACCESS_AUD + binding API cho Pages la-ban-admin', () =>
    goi('PATCH', `/accounts/${acc}/pages/projects/la-ban-admin`, {
      deployment_configs: {
        production: { env_vars: bien, services: { API: { service: 'la-ban-api' } } },
        preview: { env_vars: bien, services: { API: { service: 'la-ban-api-staging' } } },
      },
    }),
  );
}

console.log('');
console.log(`TEAM=${TEAM}`);
console.log(`AUD=${aud ?? '(có sau khi --apply)'}`);
console.log(`SERVICE_TOKEN_CN=${st?.client_id ?? '(có sau khi --apply)'}`);
if (!apDung) console.log(`\n${ke.length} thay đổi. Chạy lại với --apply để thực hiện.`);
