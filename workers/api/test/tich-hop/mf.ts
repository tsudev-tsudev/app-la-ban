// Dựng Miniflare (workerd thật) cho test tích hợp: bundle worker-thu bằng esbuild, D1 chạy đủ migrations/*.sql.
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { build } from 'esbuild';
import { convertV4MiniflareOptions, Miniflare } from 'miniflare';

const GOC = join(__dirname, '../..');

/** Tách tệp SQL thành câu lệnh; giữ nguyên khối BEGIN ... END; của trigger. Bỏ dòng chú thích. */
export function tachSql(sql: string): string[] {
  const ds: string[] = [];
  let hienTai = '';
  let trongKhoi = false;
  for (const dong of sql.split('\n')) {
    if (/^\s*--/.test(dong) || !dong.trim()) continue;
    hienTai += `${dong}\n`;
    if (/^\s*BEGIN\s*$/i.test(dong)) trongKhoi = true;
    if (trongKhoi ? /^\s*END;\s*$/i.test(dong) : /;\s*$/.test(dong)) {
      ds.push(hienTai.trim());
      hienTai = '';
      trongKhoi = false;
    }
  }
  if (hienTai.trim()) ds.push(hienTai.trim());
  return ds;
}

export async function taoMf(rl: { limit: number; period: 10 | 60 } = { limit: 1000, period: 60 }): Promise<Miniflare> {
  const kq = await build({
    entryPoints: [join(__dirname, 'worker-thu.ts')],
    bundle: true,
    format: 'esm',
    platform: 'neutral',
    target: 'es2022',
    write: false,
    mainFields: ['module', 'main'],
    conditions: ['workerd', 'worker', 'import'],
    external: ['cloudflare:*', 'node:*'],
  });
  const ma = kq.outputFiles[0]?.text;
  if (!ma) throw new Error('esbuild không ra tệp');
  // Miniflare 5 đổi cấu trúc tuỳ chọn; giữ dạng v4 dễ đọc rồi chuyển bằng hàm của chính Miniflare.
  const mf = new Miniflare(convertV4MiniflareOptions({
    workers: [
      {
        name: 'la-ban-api-thu',
        modules: true,
        script: ma,
        compatibilityDate: '2026-10-01',
        compatibilityFlags: ['nodejs_compat'],
        bindings: { MOI_TRUONG: 'test', KHOA_URL_KY: 'khoa-url-ky-thu' },
        d1Databases: { DB: 'db-thu' },
        kvNamespaces: ['CAU_HINH'],
        r2Buckets: ['CDN'],
        durableObjects: { KHO_NONCE: 'KhoNonce', GIOI_HAN_TOC: 'GioiHanToc', PHONG_SOC: 'PhongSoc' },
        ratelimits: { RL_IP: { namespace_id: '1001', simple: rl } },
      },
    ],
  }));
  const db = await mf.getD1Database('DB');
  const thuMuc = join(GOC, 'migrations');
  for (const tep of readdirSync(thuMuc).filter((t) => t.endsWith('.sql')).sort()) {
    const cau = tachSql(readFileSync(join(thuMuc, tep), 'utf8'));
    await db.batch(cau.map((c) => db.prepare(c)));
  }
  return mf;
}
