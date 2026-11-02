// Cron sao lưu D1 hằng ngày -> R2 NHAT_KY/sao-luu/ (S10a, MON-03), mã hoá lai bằng khoá CÔNG KHAI KHOA_SAO_LUU.
// Lớp khôi phục thứ nhất vẫn là D1 Time Travel (30 ngày, theo phút); bản này phòng mất cả CSDL / tài khoản bị chiếm.
import type { Env } from '../moi-truong';
import { BANG_SAO_LUU, dongGoi, dongNdjson, khoaSaoLuu, LO_SAO_LUU } from '../thuan/sao-luu';

async function gzip(vanBan: string): Promise<Uint8Array<ArrayBuffer>> {
  const luong = new Blob([vanBan]).stream().pipeThrough(new CompressionStream('gzip'));
  return new Uint8Array(await new Response(luong).arrayBuffer());
}

export type KetQuaSaoLuu = { khoa: string; co: number; dong: number } | { bo: string };

export async function saoLuuD1(env: Env, bayGio = Date.now()): Promise<KetQuaSaoLuu> {
  const db = env.DB;
  const r2 = env.NHAT_KY;
  if (!db || !r2) return { bo: 'thieu-binding' };
  if (!env.KHOA_SAO_LUU) return { bo: 'thieu-khoa' };
  const khoa = khoaSaoLuu(bayGio);
  // Mỗi ngày một bản: lượt cron lặp lại trong ngày (thử lại) không ghi đè.
  if (await r2.head(khoa)) return { bo: 'da-co' };

  const phan: string[] = [];
  const dem: Record<string, number> = {};
  for (const bang of BANG_SAO_LUU) {
    let sau = 0;
    dem[bang] = 0;
    for (;;) {
      const { results } = await db
        .prepare(`SELECT rowid AS _so, * FROM ${bang} WHERE rowid > ? ORDER BY rowid LIMIT ?`)
        .bind(sau, LO_SAO_LUU)
        .all<Record<string, unknown> & { _so: number }>();
      for (const { _so, ...dong } of results) {
        phan.push(dongNdjson(bang, dong));
        sau = _so;
      }
      dem[bang] += results.length;
      if (results.length < LO_SAO_LUU) break;
    }
  }
  const ndjson = phan.join('');
  const tep = await dongGoi(ndjson, await gzip(ndjson), dem, env.KHOA_SAO_LUU, env.MOI_TRUONG, bayGio);
  await r2.put(khoa, tep, {
    httpMetadata: { contentType: 'application/octet-stream' },
    customMetadata: { dong: String(phan.length), tao: String(bayGio) },
  });
  return { khoa, co: tep.length, dong: phan.length };
}
