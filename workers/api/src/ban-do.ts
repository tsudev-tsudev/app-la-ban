// A7a - đường /ban-do/* (QUYET_DINH Q37): tile vector XYZ đọc từ PMTiles trên R2 + style + glyph cho MapLibre (app tải vùng
// offline theo chuẩn offline region). Đứng NGOÀI app Hono: không ký request / Analytics Engine mỗi tile (một màn hình bản đồ
// = vài chục tile, một vùng offline = hàng nghìn). Chỉ GET công khai, cache edge theo URL (đường dẫn tile có mã bộ -> bất biến)
// và giới hạn tốc độ riêng theo IP.
import type { Env } from './moi-truong';
import { ghiLog } from './mw/ghi-log';
import { ganTieuDe } from './thuan/tieu-de';
import { BO_TILE, DAI_GLYPH, kieuBanDo, phanTichDuongDan, tepChoZoom } from './thuan/ban-do';
import { DOC_DAU, docHeader, giaiThuMuc, type HeaderPmtiles, type MucThuMuc, timMuc, zxyRaId } from './thuan/pmtiles';

const NAM = 'public, max-age=31536000, immutable';

async function giaiNen(b: ArrayBuffer | Uint8Array): Promise<Uint8Array> {
  const ra = new Response(new Blob([b]).stream().pipeThrough(new DecompressionStream('gzip')));
  return new Uint8Array(await ra.arrayBuffer());
}

async function docR2(r2: R2Bucket, khoa: string, vt: number, dai: number): Promise<Uint8Array> {
  const v = await r2.get(khoa, { range: { offset: vt, length: dai } });
  if (!v) throw new Error(`thieu ${khoa}`);
  return new Uint8Array(await v.arrayBuffer());
}

// Header + thư mục gốc / lá giữ trong isolate (tệp bất biến theo bộ). Lá giới hạn số lượng để không phình bộ nhớ.
const dauTep = new Map<string, Promise<{ h: HeaderPmtiles; goc: MucThuMuc[] }>>();
const laTep = new Map<string, MucThuMuc[]>();
const LA_TOI_DA = 256;

function docDau(r2: R2Bucket, khoa: string) {
  let p = dauTep.get(khoa);
  if (!p) {
    p = (async () => {
      const b = await docR2(r2, khoa, 0, DOC_DAU);
      const h = docHeader(b);
      if (h.nenTrong !== 2) throw new Error('chi-ho-tro-gzip');
      return { h, goc: giaiThuMuc(await giaiNen(b.subarray(h.gocVt, h.gocVt + h.gocDai))) };
    })();
    p.catch(() => dauTep.delete(khoa));
    dauTep.set(khoa, p);
  }
  return p;
}

/** Dữ liệu tile đã giải nén; null = không có tile (biển / ngoài vùng). */
export async function docTile(r2: R2Bucket, z: number, x: number, y: number): Promise<Uint8Array | null> {
  const tep = tepChoZoom(z);
  if (!tep) return null;
  const khoa = `ban-do/${BO_TILE}/${tep}`;
  const { h, goc } = await docDau(r2, khoa);
  const id = zxyRaId(z, x, y);
  let ds = goc;
  for (let sau = 0; sau < 4; sau++) {
    const m = timMuc(ds, id);
    if (!m) return null;
    if (m.chay > 0) {
      const b = await docR2(r2, khoa, h.duLieuVt + m.vt, m.dai);
      return h.nenTile === 2 ? giaiNen(b) : b;
    }
    const khoaLa = `${khoa}#${m.vt}`;
    let la = laTep.get(khoaLa);
    if (!la) {
      la = giaiThuMuc(await giaiNen(await docR2(r2, khoa, h.laVt + m.vt, m.dai)));
      if (laTep.size >= LA_TOI_DA) laTep.delete(laTep.keys().next().value as string);
      laTep.set(khoaLa, la);
    }
    ds = la;
  }
  throw new Error('thu-muc-qua-sau');
}

function traLoi(than: BodyInit | null, status: number, loaiNoiDung: string, cache: string): Response {
  const h = ganTieuDe(new Headers({ 'content-type': loaiNoiDung, 'cache-control': cache, 'access-control-allow-origin': '*' }));
  return new Response(than, { status, headers: h });
}

export async function phucVuBanDo(req: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
  if (req.method !== 'GET' && req.method !== 'HEAD') return traLoi(null, 405, 'text/plain', 'no-store');
  const url = new URL(req.url);
  const yc = phanTichDuongDan(url.pathname);
  if (!yc || url.search) return traLoi(null, 404, 'text/plain', 'public, max-age=300');
  if (yc.loai === 'tile' && yc.bo !== BO_TILE) return traLoi(null, 404, 'text/plain', 'public, max-age=300');

  const cache = (caches as unknown as { default: Cache }).default;
  const daCo = await cache.match(req);
  if (daCo) return daCo;

  const ip = req.headers.get('cf-connecting-ip');
  if (env.RL_BAN_DO && ip) {
    const { success } = await env.RL_BAN_DO.limit({ key: ip });
    if (!success) return new Response(null, { status: 429, headers: { 'retry-after': '60' } });
  }
  const r2 = env.BAN_DO;
  if (!r2) return traLoi(null, 503, 'text/plain', 'no-store');

  let ra: Response;
  try {
    if (yc.loai === 'kieu') {
      ra = traLoi(JSON.stringify(kieuBanDo(url.origin, yc.giaoDien, yc.ngonNgu)), 200, 'application/json; charset=utf-8', 'public, max-age=3600');
    } else if (yc.loai === 'glyph') {
      const v = DAI_GLYPH.includes(yc.dai) ? await r2.get(`ban-do/phong/${yc.phong}/${yc.dai}.pbf`) : null;
      ra = traLoi(v ? v.body : new Uint8Array(0), 200, 'application/x-protobuf', 'public, max-age=604800');
    } else {
      const b = await docTile(r2, yc.z, yc.x, yc.y);
      ra = b ? traLoi(b, 200, 'application/vnd.mapbox-vector-tile', NAM) : traLoi(null, 204, 'application/vnd.mapbox-vector-tile', NAM);
    }
  } catch (e) {
    ghiLog('error', 'ban-do-loi', { loi: String(e), duongDan: url.pathname });
    return traLoi(null, 503, 'text/plain', 'no-store');
  }
  if (req.method === 'GET') ctx.waitUntil(cache.put(req, ra.clone()));
  return ra;
}
