#!/usr/bin/env node
// Công cụ sao lưu / khôi phục / nhật ký bất biến (S10a, MON-01 + MON-03). Khoá RIÊNG giải mã ở
// ~/.config/la-ban/sao-luu/khoa-rieng.pem (NGOÀI repo, quyền 600) - xem docs/runbook/sao-luu-khoi-phuc.md.
//
//   node tools/sao-luu/sao-luu.mjs giai-ma <tep.lbsl> [--ra khoi-phuc.sql]   giải mã + kiểm băm -> SQL nạp vào D1 mới
//   node tools/sao-luu/sao-luu.mjs dien-tap --env staging|prod [--ngay YYYY-MM-DD]
//        tải bản sao lưu từ R2 -> tạo D1 tạm la-ban-dien-tap -> migrations -> nạp -> so số dòng -> xoá D1 tạm; in RTO
//   node tools/sao-luu/sao-luu.mjs kiem-nhat-ky --env staging|prod   tải mọi đoạn nhat-ky/ từ R2, tính lại chuỗi băm,
//        so với trang-thai/dau-chuoi.json (thiếu / chèn / sửa đoạn -> báo số đoạn)
import { execFileSync } from 'node:child_process';
import { createPrivateKey } from 'node:crypto';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { gunzipSync } from 'node:zlib';
import { build } from 'esbuild';

const GOC = join(dirname(fileURLToPath(import.meta.url)), '../..');
const API = 'https://api.cloudflare.com/client/v4';
const KHOA_RIENG = join(homedir(), '.config/la-ban/sao-luu/khoa-rieng.pem');
const BUCKET = { prod: 'la-ban-nhat-ky', staging: 'la-ban-nhat-ky-staging' };
const D1_TAM = 'la-ban-dien-tap';

/** Nạp hàm thuần TypeScript của Worker (một nguồn sự thật cho định dạng tệp / chuỗi băm). */
async function napThuan(ten) {
  const kq = await build({
    entryPoints: [join(GOC, `workers/api/src/thuan/${ten}.ts`)],
    bundle: true,
    format: 'esm',
    platform: 'node',
    write: false,
  });
  return import(`data:text/javascript;base64,${Buffer.from(kq.outputFiles[0].text).toString('base64')}`);
}

function napEnv() {
  const tep = join(homedir(), '.config/la-ban/cf.env');
  if (!existsSync(tep)) return;
  for (const dong of readFileSync(tep, 'utf8').split('\n')) {
    const m = /^\s*([A-Z_]+)\s*=\s*"?([^"\n]*)"?\s*$/.exec(dong);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
  }
}

function thamSo(ten) {
  const i = process.argv.indexOf(ten);
  return i > 0 ? process.argv[i + 1] : undefined;
}

function khoaRieng() {
  if (!existsSync(KHOA_RIENG)) throw new Error(`Thiếu khoá riêng ${KHOA_RIENG}`);
  return new Uint8Array(createPrivateKey(readFileSync(KHOA_RIENG)).export({ type: 'pkcs8', format: 'der' }));
}

/** Giải mã tệp -> { tieuDe, ndjson, sql, dem } và kiểm băm + số dòng khớp tiêu đề. */
export async function giaiMa(tep, rieng) {
  const sl = await napThuan('sao-luu');
  const { tieuDe, nen } = await sl.moGoi(tep, rieng);
  const ndjson = gunzipSync(nen).toString('utf8');
  const { sha256Hex } = await napThuan('bam');
  if ((await sha256Hex(ndjson)) !== tieuDe.bam) throw new Error('băm nội dung không khớp tiêu đề');
  const { sql, dem } = sl.sqlKhoiPhuc(ndjson);
  for (const [bang, n] of Object.entries(tieuDe.bang)) {
    if ((dem[bang] ?? 0) !== n) throw new Error(`số dòng ${bang} lệch: tiêu đề ${n}, tệp ${dem[bang] ?? 0}`);
  }
  return { tieuDe, ndjson, sql, dem };
}

function cf(path, init = {}) {
  const { CLOUDFLARE_API_TOKEN: token, CLOUDFLARE_ACCOUNT_ID: acc } = process.env;
  if (!token || !acc) throw new Error('Thiếu CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID (~/.config/la-ban/cf.env)');
  return fetch(`${API}/accounts/${acc}${path}`, { ...init, headers: { authorization: `Bearer ${token}`, ...(init.headers ?? {}) } });
}

async function lietKe(bucket, tienTo) {
  const ra = [];
  let cursor = '';
  for (;;) {
    const res = await cf(`/r2/buckets/${bucket}/objects?prefix=${encodeURIComponent(tienTo)}&per_page=1000${cursor ? `&cursor=${cursor}` : ''}`);
    const j = await res.json();
    if (!j.success) throw new Error(`liệt kê R2 lỗi: ${JSON.stringify(j.errors)}`);
    ra.push(...j.result.map((o) => o.key));
    cursor = j.result_info?.cursor ?? '';
    if (!j.result_info?.is_truncated || !cursor) return ra;
  }
}

async function taiR2(bucket, khoa) {
  const res = await cf(`/r2/buckets/${bucket}/objects/${khoa.split('/').map(encodeURIComponent).join('/')}`);
  if (!res.ok) throw new Error(`tải R2 ${khoa}: ${res.status}`);
  return new Uint8Array(await res.arrayBuffer());
}

function wrangler(args, cwd) {
  return execFileSync(join(GOC, 'node_modules/.bin/wrangler'), args, {
    cwd,
    encoding: 'utf8',
    env: { ...process.env, WRANGLER_SEND_METRICS: 'false' },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

async function dienTap(env) {
  const bucket = BUCKET[env];
  if (!bucket) throw new Error('--env staging|prod');
  const ngay = thamSo('--ngay');
  const ds = (await lietKe(bucket, 'sao-luu/')).sort();
  const khoa = ngay ? `sao-luu/${ngay}.lbsl` : ds.at(-1);
  if (!khoa || !ds.includes(khoa)) throw new Error(`Không có bản sao lưu ${ngay ?? ''} trong ${bucket}`);
  const t0 = Date.now();
  const { tieuDe, sql, dem } = await giaiMa(await taiR2(bucket, khoa), khoaRieng());
  console.log(`• ${khoa}: tạo ${new Date(tieuDe.tao).toISOString()} (${tieuDe.moiTruong}), ${Object.values(dem).reduce((a, b) => a + b, 0)} dòng`);

  // Thư mục tạm TRỐNG (bẫy WRANGLER AUTOCONFIG) + cấu hình riêng trỏ migrations thật.
  const tam = mkdtempSync(join(tmpdir(), 'la-ban-dien-tap-'));
  try {
    const tao = wrangler(['d1', 'create', D1_TAM], tam);
    const id = /([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/.exec(tao)?.[1];
    if (!id) throw new Error(`không đọc được id D1 tạm:\n${tao}`);
    try {
      writeFileSync(
        join(tam, 'wrangler.toml'),
        `name = "la-ban-dien-tap"\ncompatibility_date = "2026-10-01"\n[[d1_databases]]\nbinding = "DB"\ndatabase_name = "${D1_TAM}"\ndatabase_id = "${id}"\nmigrations_dir = "${join(GOC, 'workers/api/migrations')}"\n`,
      );
      wrangler(['d1', 'migrations', 'apply', D1_TAM, '--remote'], tam);
      writeFileSync(join(tam, 'khoi-phuc.sql'), sql);
      wrangler(['d1', 'execute', D1_TAM, '--remote', '--file', join(tam, 'khoi-phuc.sql'), '--yes'], tam);
      const lech = [];
      for (const [bang, n] of Object.entries(dem)) {
        const ra = wrangler(['d1', 'execute', D1_TAM, '--remote', '--json', '--command', `SELECT count(*) AS n FROM ${bang}`], tam);
        const thuc = JSON.parse(ra)[0].results[0].n;
        if (thuc !== n) lech.push(`${bang}: ${thuc}/${n}`);
      }
      const giay = Math.round((Date.now() - t0) / 1000);
      if (lech.length) throw new Error(`số dòng sau khôi phục lệch: ${lech.join(', ')}`);
      console.log(`✓ Diễn tập đạt: ${Object.keys(dem).length} bảng khớp số dòng, RTO đo được ${giay} s (mục tiêu <= 4 h); RPO <= 24 h (bản hằng ngày) / phút (Time Travel)`);
    } finally {
      wrangler(['d1', 'delete', D1_TAM, '-y'], tam);
    }
  } finally {
    rmSync(tam, { recursive: true, force: true });
  }
}

async function kiemNhatKy(env) {
  const bucket = BUCKET[env];
  if (!bucket) throw new Error('--env staging|prod');
  const nk = await napThuan('nhat-ky-bat-bien');
  const dau = JSON.parse(Buffer.from(await taiR2(bucket, nk.KHOA_DAU_CHUOI)).toString('utf8'));
  const khoa = (await lietKe(bucket, nk.TIEN_TO_DOAN)).sort((a, b) => a.split('/').at(-1).localeCompare(b.split('/').at(-1)));
  let hash = nk.HASH_GOC_NHAT_KY;
  for (const [i, k] of khoa.entries()) {
    const so = Number(k.split('/').at(-1).split('.')[0]);
    if (so !== i + 1) throw new Error(`thiếu / chèn đoạn: mong ${i + 1}, gặp ${so} (${k})`);
    hash = (await nk.bamMatXich(hash, Buffer.from(await taiR2(bucket, k)).toString('utf8'))).hash;
  }
  if (khoa.length !== dau.so || hash !== dau.hash) throw new Error(`chuỗi KHÔNG khớp đầu chuỗi: ${khoa.length}/${dau.so} đoạn`);
  console.log(`✓ Nhật ký ${bucket}: ${khoa.length} đoạn nguyên vẹn; mốc neo audit ${dau.auditSoDong} dòng, cuối ${dau.auditCuoi ?? '-'}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  napEnv();
  const [lenh, doi] = process.argv.slice(2);
  try {
    if (lenh === 'giai-ma' && doi) {
      const { tieuDe, sql, dem } = await giaiMa(readFileSync(doi), khoaRieng());
      const ra = thamSo('--ra') ?? 'khoi-phuc.sql';
      writeFileSync(ra, sql, { mode: 0o600 });
      console.log(`✓ ${ra}: ${JSON.stringify(dem)} (bản ${tieuDe.moiTruong} ${new Date(tieuDe.tao).toISOString()}, kid ${tieuDe.kid})`);
    } else if (lenh === 'dien-tap') await dienTap(thamSo('--env'));
    else if (lenh === 'kiem-nhat-ky') await kiemNhatKy(thamSo('--env'));
    else {
      console.error('Lệnh: giai-ma <tep> [--ra x.sql] | dien-tap --env staging|prod [--ngay YYYY-MM-DD] | kiem-nhat-ky --env staging|prod');
      process.exit(2);
    }
  } catch (e) {
    console.error(`✗ ${e.message}`);
    process.exit(1);
  }
}
