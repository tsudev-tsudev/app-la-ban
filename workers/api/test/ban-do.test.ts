// A7a: đường /ban-do - PMTiles (thuần) + style + tích hợp workerd đọc R2 thật (Miniflare).
import { gunzipSync, gzipSync } from 'node:zlib';
import type { Miniflare } from 'miniflare';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { BANG_MAU, BO_TILE, kieuBanDo, phanTichDuongDan, tepChoZoom } from '../src/thuan/ban-do';
import { docHeader, giaiThuMuc, timMuc, zxyRaId } from '../src/thuan/pmtiles';
// Công cụ dựng tệp (tools/build) - dùng để tạo archive thử, đồng thời kiểm hai bên đọc / ghi khớp nhau.
import { dungThuMuc, ghiHeader } from '../../../tools/build/pmtiles-luat.mjs';
import { taoMf } from './tich-hop/mf';

describe('pmtiles thuần', () => {
  it('id Hilbert khớp giá trị mẫu của spec', () => {
    expect(zxyRaId(0, 0, 0)).toBe(0);
    expect([[1, 0, 0], [1, 0, 1], [1, 1, 1], [1, 1, 0]].map(([z, x, y]) => zxyRaId(z as number, x as number, y as number))).toEqual([1, 2, 3, 4]);
    expect(zxyRaId(15, 32767, 0)).toBe((4 ** 15 - 1) / 3 + 4 ** 15 - 1);
    expect(() => zxyRaId(16, 0, 0)).toThrow();
    expect(() => zxyRaId(2, 4, 0)).toThrow();
  });

  it('đọc thư mục do công cụ ghi (offset liền kề, lá)', () => {
    const ds = Array.from({ length: 60000 }, (_, i) => ({ id: i * 2, chay: 1 + (i % 2), vt: i * 1000 + (i % 7), dai: 900 + (i % 13) }));
    const { goc, la } = dungThuMuc(ds);
    const tro = giaiThuMuc(gunzipSync(goc));
    const m = timMuc(tro, 2 * 50000);
    if (!m) throw new Error('thiếu mục lá');
    expect(m.chay).toBe(0);
    const laDs = giaiThuMuc(gunzipSync(la.subarray(m.vt, m.vt + m.dai)));
    expect(timMuc(laDs, 100000)).toEqual(ds[50000]);
    expect(timMuc(laDs, 100002 + 1)).toEqual(ds[50001]);
    expect(timMuc(laDs, 100001)).toBeNull();
  });
});

describe('đường dẫn + style', () => {
  it('chỉ nhận tile trong phạm vi, style / glyph đúng mẫu', () => {
    expect(phanTichDuongDan(`/ban-do/${BO_TILE}/14/13009/7212.mvt`)).toEqual({ loai: 'tile', bo: BO_TILE, z: 14, x: 13009, y: 7212 });
    expect(phanTichDuongDan(`/ban-do/${BO_TILE}/15/0/0.mvt`)).toBeNull();
    expect(phanTichDuongDan(`/ban-do/${BO_TILE}/2/4/0.mvt`)).toBeNull();
    expect(phanTichDuongDan('/ban-do/kieu/toi-en.json')).toEqual({ loai: 'kieu', giaoDien: 'toi', ngonNgu: 'en' });
    expect(phanTichDuongDan('/ban-do/phong/Noto%20Sans%20Medium,Arial/0-255.pbf')).toEqual({ loai: 'glyph', phong: 'Noto Sans Medium', dai: '0-255' });
    expect(phanTichDuongDan('/ban-do/phong/..%2F..%2Fx/0-255.pbf')).toBeNull();
    expect(phanTichDuongDan('/ban-do/phong/%E0%A4%A/0-255.pbf')).toBeNull();
    expect([tepChoZoom(0), tepChoZoom(13), tepChoZoom(14), tepChoZoom(15)]).toEqual(['vn-0-13.pmtiles', 'vn-0-13.pmtiles', 'vn-14.pmtiles', null]);
  });

  it('style: id lớp không trùng, mọi lớp vector trỏ nguồn vn, URL theo origin, tên theo ngôn ngữ', () => {
    for (const gd of ['sang', 'toi'] as const) {
      const k = kieuBanDo('https://x.test', gd, 'vi') as { layers: { id: string; source?: string }[]; glyphs: string; sources: { vn: { tiles: string[] } } };
      const ids = k.layers.map((l) => l.id);
      expect(new Set(ids).size).toBe(ids.length);
      expect(k.layers.filter((l) => l.source && l.source !== 'vn')).toEqual([]);
      expect(k.sources.vn.tiles[0]).toBe(`https://x.test/ban-do/${BO_TILE}/{z}/{x}/{y}.mvt`);
      expect(k.glyphs).toBe('https://x.test/ban-do/phong/{fontstack}/{range}.pbf');
      expect(JSON.stringify(k)).toContain(BANG_MAU[gd].nuoc);
    }
    expect(JSON.stringify(kieuBanDo('https://x.test', 'sang', 'vi'))).toContain('name:vi');
    expect(JSON.stringify(kieuBanDo('https://x.test', 'sang', 'en'))).not.toContain('name:vi');
  });
});

// Archive thử: z0-13, một tile z13 (Hà Nội) + tile z0, nén gzip như Protomaps.
function taoArchive(): { tep: Uint8Array; noiDung: string } {
  const noiDung = 'tile-ha-noi';
  const t0 = gzipSync(Buffer.from('tile-z0'));
  const t13 = gzipSync(Buffer.from(noiDung));
  const ds = [
    { id: zxyRaId(0, 0, 0), chay: 1, vt: 0, dai: t0.length },
    { id: zxyRaId(13, 6504, 3606), chay: 1, vt: t0.length, dai: t13.length },
  ];
  const { goc, la } = dungThuMuc(ds);
  const meta = gzipSync(Buffer.from('{}'));
  const duLieu = Buffer.concat([t0, t13]);
  const h = ghiHeader({
    gocVt: 127, gocDai: goc.length, metaVt: 127 + goc.length, metaDai: meta.length, laVt: 127 + goc.length + meta.length,
    laDai: la.length, duLieuVt: 127 + goc.length + meta.length + la.length, duLieuDai: duLieu.length, soTileDinhDanh: 2,
    soMuc: 2, soNoiDung: 2, gom: true, nenTrong: 2, nenTile: 2, loaiTile: 1, zMin: 0, zMax: 13, khung: [102, 8, 110, 24],
    zGiua: 5, giua: [106, 16],
  });
  const tep = new Uint8Array(Buffer.concat([h, goc, meta, la, duLieu]));
  expect(docHeader(tep).zMax).toBe(13);
  return { tep, noiDung };
}

describe('tích hợp workerd: /ban-do', () => {
  let mf: Miniflare;
  const goc = 'https://compass-api.tsudev.com';
  beforeAll(async () => {
    mf = await taoMf();
    const r2 = await mf.getR2Bucket('BAN_DO');
    await r2.put(`ban-do/${BO_TILE}/vn-0-13.pmtiles`, taoArchive().tep);
    await r2.put('ban-do/phong/Noto Sans Regular/0-255.pbf', new Uint8Array([1, 2, 3]));
  }, 60_000);
  afterAll(async () => mf?.dispose());

  it('tile có -> 200 đã giải nén, cache bất biến; biển -> 204; bộ cũ -> 404', async () => {
    const r = await mf.dispatchFetch(`${goc}/ban-do/${BO_TILE}/13/6504/3606.mvt`);
    expect(r.status).toBe(200);
    expect(r.headers.get('cache-control')).toContain('immutable');
    expect(r.headers.get('content-type')).toBe('application/vnd.mapbox-vector-tile');
    expect(await r.text()).toBe('tile-ha-noi');
    const bien = await mf.dispatchFetch(`${goc}/ban-do/${BO_TILE}/13/6600/3700.mvt`);
    expect(bien.status).toBe(204);
    await bien.arrayBuffer();
    const cu = await mf.dispatchFetch(`${goc}/ban-do/20200101/0/0/0.mvt`);
    expect(cu.status).toBe(404);
    await cu.arrayBuffer();
  });

  it('style theo origin, glyph có / dải lạ rỗng 200, POST 405, không qua middleware API', async () => {
    const k = await mf.dispatchFetch(`${goc}/ban-do/kieu/sang-vi.json`);
    expect(k.status).toBe(200);
    expect(((await k.json()) as { glyphs: string }).glyphs).toContain(goc);
    const g = await mf.dispatchFetch(`${goc}/ban-do/phong/Noto%20Sans%20Regular/0-255.pbf`);
    expect(new Uint8Array(await g.arrayBuffer())).toEqual(new Uint8Array([1, 2, 3]));
    const rong = await mf.dispatchFetch(`${goc}/ban-do/phong/Noto%20Sans%20Regular/19968-20223.pbf`);
    expect(rong.status).toBe(200);
    expect((await rong.arrayBuffer()).byteLength).toBe(0);
    const p = await mf.dispatchFetch(`${goc}/ban-do/kieu/sang-vi.json`, { method: 'POST' });
    expect(p.status).toBe(405);
    await p.arrayBuffer();
    expect(k.headers.get('x-request-id')).toBeNull();
  });
});
