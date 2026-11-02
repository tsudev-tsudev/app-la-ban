#!/usr/bin/env node
// R2 bucket lock + lifecycle cho bucket nhật ký (S10a, MON-01 / MON-03) dạng mã. MẶC ĐỊNH dry-run: chỉ in kế hoạch.
//   node tools/cloudflare/r2-khoa.mjs            # xem sẽ đổi gì
//   node tools/cloudflare/r2-khoa.mjs --apply    # thực hiện (ghi đè toàn bộ quy tắc - idempotent)
// Khoá (object lock) = KHÔNG ai xoá / ghi đè được đối tượng trước tuổi quy định, kể cả token có quyền R2 Admin.
// trang-thai/ (đầu chuỗi) KHÔNG bị khoá vì Worker phải sửa nó mỗi lượt.
import { existsSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const API = 'https://api.cloudflare.com/client/v4';
const NGAY = 86_400;

/** Quy tắc mong muốn mỗi bucket (tuổi theo ngày). Lifecycle xoá phải SAU hạn khoá. */
export const QUY_TAC = {
  'la-ban-nhat-ky': { khoa: { 'nhat-ky/': 400, 'sao-luu/': 30 }, xoa: { 'nhat-ky/': 430, 'sao-luu/': 90 } },
  'la-ban-nhat-ky-staging': { khoa: { 'nhat-ky/': 30, 'sao-luu/': 7 }, xoa: { 'nhat-ky/': 60, 'sao-luu/': 30 } },
};

export function thanLock(q) {
  return {
    rules: Object.entries(q.khoa).map(([prefix, ngay]) => ({
      id: `khoa-${prefix.replace(/\/$/, '')}`,
      enabled: true,
      prefix,
      condition: { type: 'Age', maxAgeSeconds: ngay * NGAY },
    })),
  };
}

export function thanLifecycle(q) {
  for (const [p, ngay] of Object.entries(q.xoa)) {
    if (ngay <= (q.khoa[p] ?? 0)) throw new Error(`lifecycle ${p} (${ngay} ngày) phải sau hạn khoá (${q.khoa[p]} ngày)`);
  }
  return {
    rules: [
      {
        id: 'Default Multipart Abort Rule',
        enabled: true,
        conditions: {},
        abortMultipartUploadsTransition: { condition: { type: 'Age', maxAge: 7 * NGAY } },
      },
      ...Object.entries(q.xoa).map(([prefix, ngay]) => ({
        id: `xoa-${prefix.replace(/\/$/, '')}`,
        enabled: true,
        conditions: { prefix },
        deleteObjectsTransition: { condition: { type: 'Age', maxAge: ngay * NGAY } },
      })),
    ],
  };
}

function napEnv() {
  const tep = join(homedir(), '.config/la-ban/cf.env');
  if (!existsSync(tep)) return;
  for (const dong of readFileSync(tep, 'utf8').split('\n')) {
    const m = /^\s*([A-Z_]+)\s*=\s*"?([^"\n]*)"?\s*$/.exec(dong);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
  }
}

async function chay() {
  napEnv();
  const { CLOUDFLARE_API_TOKEN: token, CLOUDFLARE_ACCOUNT_ID: acc } = process.env;
  if (!token || !acc) throw new Error('Thiếu CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID');
  const apDung = process.argv.includes('--apply');
  const goi = async (method, path, body) => {
    const res = await fetch(`${API}/accounts/${acc}${path}`, {
      method,
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined,
    });
    const j = await res.json();
    if (!j.success) throw new Error(`${method} ${path}: ${JSON.stringify(j.errors)}`);
    return j.result;
  };
  for (const [bucket, q] of Object.entries(QUY_TAC)) {
    for (const [loai, than] of [
      ['lock', thanLock(q)],
      ['lifecycle', thanLifecycle(q)],
    ]) {
      const hien = await goi('GET', `/r2/buckets/${bucket}/${loai}`);
      const giong = JSON.stringify(hien.rules ?? []) === JSON.stringify(than.rules);
      console.log(`${giong ? '=' : '~'} ${bucket} ${loai}: ${than.rules.map((r) => r.id).join(', ')}`);
      if (!giong && apDung) await goi('PUT', `/r2/buckets/${bucket}/${loai}`, than);
    }
  }
  if (!apDung) console.log('(dry-run - thêm --apply để ghi)');
}

if (process.argv[1]?.endsWith('r2-khoa.mjs')) {
  chay().catch((e) => {
    console.error(`✗ ${e.message}`);
    process.exit(1);
  });
}
