// A7a - bản đồ: đường dẫn /ban-do/*, bộ tile hiện hành và style MapLibre theo token thiết kế (QUYET_DINH Q37).
// Tile: lược đồ Protomaps basemap (lớp earth / landcover / landuse / water / roads / buildings / boundaries / places / pois,
// trường kind, name, name:vi, name:en, min_zoom, population_rank). Dữ liệu © OpenStreetMap (ODbL).

/** Bộ tile đang phục vụ (ngày bản Protomaps); đổi bộ = tải tệp mới lên R2 `ban-do/<bo>/` rồi đổi hằng này. */
export const BO_TILE = '20261029';
/** Tệp PMTiles của bộ, tách theo zoom cho vừa giới hạn tải lên. */
export const TEP_TILE: readonly { tep: string; zMin: number; zMax: number }[] = [
  { tep: 'vn-0-13.pmtiles', zMin: 0, zMax: 13 },
  { tep: 'vn-14.pmtiles', zMin: 14, zMax: 14 },
];
export const Z_TOI_DA = 14;
/** [tây, nam, đông, bắc]: đất liền + Hoàng Sa + Trường Sa (tools/build/tile-vn.mjs KHUNG_VN). */
export const KHUNG_VN: readonly [number, number, number, number] = [102.1, 6.0, 117.9, 23.45];
export const PHONG: readonly string[] = ['Noto Sans Regular', 'Noto Sans Medium', 'Noto Sans Italic'];
/** Dải glyph có sẵn (Latin + tiếng Việt). Dải khác trả PBF rỗng: MapLibre bỏ ký tự, không lỗi khi tải offline. */
export const DAI_GLYPH: readonly string[] = ['0-255', '256-511', '512-767', '768-1023', '7680-7935', '8192-8447'];

export type YeuCauBanDo =
  | { loai: 'tile'; bo: string; z: number; x: number; y: number }
  | { loai: 'kieu'; giaoDien: 'sang' | 'toi'; ngonNgu: 'vi' | 'en' }
  | { loai: 'glyph'; phong: string; dai: string }
  | null;

export function phanTichDuongDan(duongDan: string): YeuCauBanDo {
  let p: string;
  try {
    p = decodeURIComponent(duongDan);
  } catch {
    return null;
  }
  const t = /^\/ban-do\/(\d{8})\/(\d{1,2})\/(\d{1,5})\/(\d{1,5})\.mvt$/.exec(p);
  if (t) {
    const [z, x, y] = [Number(t[2]), Number(t[3]), Number(t[4])];
    if (z > Z_TOI_DA || x >= 2 ** z || y >= 2 ** z) return null;
    return { loai: 'tile', bo: t[1] as string, z, x, y };
  }
  const k = /^\/ban-do\/kieu\/(sang|toi)-(vi|en)\.json$/.exec(p);
  if (k) return { loai: 'kieu', giaoDien: k[1] as 'sang' | 'toi', ngonNgu: k[2] as 'vi' | 'en' };
  const g = /^\/ban-do\/phong\/([^/]+)\/(\d+-\d+)\.pbf$/.exec(p);
  if (g) {
    // fontstack có thể là danh sách "A,B": lấy phông đầu có sẵn.
    const phong = (g[1] as string).split(',').map((s) => s.trim()).find((s) => PHONG.includes(s));
    return phong ? { loai: 'glyph', phong, dai: g[2] as string } : null;
  }
  return null;
}

export function tepChoZoom(z: number): string | null {
  return TEP_TILE.find((t) => z >= t.zMin && z <= t.zMax)?.tep ?? null;
}

type Bang = {
  dat: string;
  nuoc: string;
  nuocChu: string;
  xanh: string;
  rung: string;
  dacBiet: string;
  nha: string;
  duongNho: string;
  duongNhoVien: string;
  duongChinh: string;
  duongChinhVien: string;
  caoToc: string;
  caoTocVien: string;
  duongMon: string;
  ranhGioi: string;
  chu: string;
  chuPhu: string;
  vienChu: string;
};

// Bảng màu bản đồ dẫn xuất từ design/tokens.json: nền = bg, chữ = text / textMuted, đường cao tốc = accent (Sunrise
// Coral) dịu, nước ngả Electric Cyan. Tương phản chữ / viền chữ >= 4.5:1 ở cả hai giao diện.
export const BANG_MAU: Readonly<Record<'sang' | 'toi', Bang>> = {
  sang: {
    dat: '#F8FAFC', nuoc: '#BFE9F7', nuocChu: '#1A56DB', xanh: '#DCF2E1', rung: '#CDEBD5', dacBiet: '#EEF1F6', nha: '#E2E8F0',
    duongNho: '#FFFFFF', duongNhoVien: '#CBD5E1', duongChinh: '#FFE7D1', duongChinhVien: '#F2B68A', caoToc: '#FFC9A3',
    caoTocVien: '#E08A50', duongMon: '#94A3B8', ranhGioi: '#64748B', chu: '#0B1220', chuPhu: '#475569', vienChu: '#FFFFFF',
  },
  toi: {
    dat: '#0B1220', nuoc: '#0E2C42', nuocChu: '#7FD8F0', xanh: '#11261D', rung: '#0F2A1E', dacBiet: '#131C2E', nha: '#1B2740',
    duongNho: '#26344F', duongNhoVien: '#1B2740', duongChinh: '#3A4A68', duongChinhVien: '#1B2740', caoToc: '#7A4A2A',
    caoTocVien: '#3A2A20', duongMon: '#475569', ranhGioi: '#7C8BA1', chu: '#E8EEF7', chuPhu: '#94A3B8', vienChu: '#0B1220',
  },
};

type GiaTri = unknown;
const noiSuy = (...cap: number[]): GiaTri => ['interpolate', ['exponential', 1.6], ['zoom'], ...cap];
const loai = (...ds: string[]): GiaTri => ['in', ['get', 'kind'], ['literal', ds]];

/** Style MapLibre (spec v8) cho bộ tile hiện hành. goc = origin Worker (https://compass-api.tsudev.com). */
export function kieuBanDo(goc: string, giaoDien: 'sang' | 'toi', ngonNgu: 'vi' | 'en'): Record<string, unknown> {
  const m = BANG_MAU[giaoDien];
  const ten: GiaTri =
    ngonNgu === 'vi'
      ? ['coalesce', ['get', 'name:vi'], ['get', 'name:en'], ['get', 'name']]
      : ['coalesce', ['get', 'name:en'], ['get', 'name']];
  const chu = (co: GiaTri, mau = m.chu, phong = 'Noto Sans Regular') => ({
    layout: { 'text-field': ten, 'text-font': [phong], 'text-size': co, 'text-max-width': 8 },
    paint: { 'text-color': mau, 'text-halo-color': m.vienChu, 'text-halo-width': 1.5 },
  });
  const duong = (id: string, ds: string[], zMin: number, rong: GiaTri, mau: string, vien?: { mau: string; them: number }) => {
    const loc = ['all', loai(...ds), ['!=', ['get', 'is_tunnel'], true]];
    const lop: Record<string, unknown>[] = [];
    if (vien) {
      lop.push({
        id: `${id}-vien`, type: 'line', source: 'vn', 'source-layer': 'roads', minzoom: zMin, filter: loc,
        layout: { 'line-cap': 'round', 'line-join': 'round' },
        paint: { 'line-color': vien.mau, 'line-width': ['+', rong, vien.them] },
      });
    }
    lop.push({
      id, type: 'line', source: 'vn', 'source-layer': 'roads', minzoom: zMin, filter: loc,
      layout: { 'line-cap': 'round', 'line-join': 'round' }, paint: { 'line-color': mau, 'line-width': rong },
    });
    return lop;
  };
  return {
    version: 8,
    name: `La bàn ${giaoDien} ${ngonNgu}`,
    glyphs: `${goc}/ban-do/phong/{fontstack}/{range}.pbf`,
    sources: {
      vn: {
        type: 'vector',
        tiles: [`${goc}/ban-do/${BO_TILE}/{z}/{x}/{y}.mvt`],
        minzoom: 0,
        maxzoom: Z_TOI_DA,
        bounds: KHUNG_VN,
        attribution: '© OpenStreetMap · Protomaps',
      },
    },
    layers: [
      { id: 'nen', type: 'background', paint: { 'background-color': m.nuoc } },
      { id: 'dat', type: 'fill', source: 'vn', 'source-layer': 'earth', paint: { 'fill-color': m.dat } },
      {
        id: 'phu-xanh', type: 'fill', source: 'vn', 'source-layer': 'landcover', filter: loai('forest', 'grassland', 'scrub'),
        paint: { 'fill-color': m.rung, 'fill-opacity': 0.6 },
      },
      {
        id: 'cong-vien', type: 'fill', source: 'vn', 'source-layer': 'landuse',
        filter: loai('park', 'nature_reserve', 'national_park', 'protected_area', 'forest', 'wood', 'garden', 'golf_course', 'cemetery'),
        paint: { 'fill-color': m.xanh },
      },
      {
        id: 'khu-dac-biet', type: 'fill', source: 'vn', 'source-layer': 'landuse', minzoom: 12,
        filter: loai('hospital', 'school', 'university', 'college', 'industrial', 'military', 'aerodrome'),
        paint: { 'fill-color': m.dacBiet },
      },
      {
        id: 'nuoc', type: 'fill', source: 'vn', 'source-layer': 'water', filter: ['==', ['geometry-type'], 'Polygon'],
        paint: { 'fill-color': m.nuoc },
      },
      {
        id: 'song', type: 'line', source: 'vn', 'source-layer': 'water', minzoom: 9, filter: ['==', ['geometry-type'], 'LineString'],
        paint: { 'line-color': m.nuoc, 'line-width': noiSuy(9, 0.5, 14, 2.5, 18, 6) },
      },
      {
        id: 'nha', type: 'fill', source: 'vn', 'source-layer': 'buildings', minzoom: 14,
        paint: { 'fill-color': m.nha, 'fill-outline-color': m.duongNhoVien },
      },
      ...duong('duong-mon', ['path'], 14, noiSuy(14, 0.75, 18, 2), m.duongMon),
      ...duong('duong-nho', ['minor_road', 'other'], 12, noiSuy(12, 0.5, 14, 2, 18, 12), m.duongNho, { mau: m.duongNhoVien, them: 1.5 }),
      ...duong('duong-chinh', ['major_road'], 7, noiSuy(7, 0.5, 12, 2, 14, 4, 18, 18), m.duongChinh, { mau: m.duongChinhVien, them: 1.5 }),
      ...duong('cao-toc', ['highway'], 5, noiSuy(5, 0.6, 10, 2, 14, 5, 18, 22), m.caoToc, { mau: m.caoTocVien, them: 1.5 }),
      {
        id: 'duong-sat', type: 'line', source: 'vn', 'source-layer': 'roads', minzoom: 10, filter: loai('rail'),
        paint: { 'line-color': m.ranhGioi, 'line-width': 1, 'line-dasharray': [3, 2] },
      },
      {
        id: 'ranh-gioi-tinh', type: 'line', source: 'vn', 'source-layer': 'boundaries', minzoom: 5,
        filter: ['all', loai('region'), ['!=', ['get', 'disputed'], true]],
        paint: { 'line-color': m.ranhGioi, 'line-width': noiSuy(5, 0.5, 12, 1.2), 'line-dasharray': [2, 2], 'line-opacity': 0.6 },
      },
      {
        id: 'ranh-gioi-quoc-gia', type: 'line', source: 'vn', 'source-layer': 'boundaries',
        filter: ['all', loai('country'), ['!=', ['get', 'disputed'], true]],
        paint: { 'line-color': m.ranhGioi, 'line-width': noiSuy(0, 0.6, 10, 2) },
      },
      {
        id: 'ten-nuoc', type: 'symbol', source: 'vn', 'source-layer': 'water',
        filter: ['all', ['==', ['geometry-type'], 'Point'], ['has', 'name']],
        ...((c) => ({ ...c, layout: { ...c.layout, 'text-letter-spacing': 0.1 } }))(chu(noiSuy(3, 11, 10, 14), m.nuocChu, 'Noto Sans Italic')),
      },
      {
        id: 'ten-duong', type: 'symbol', source: 'vn', 'source-layer': 'roads', minzoom: 13,
        filter: ['all', loai('highway', 'major_road', 'minor_road'), ['has', 'name']],
        layout: { ...chu(noiSuy(13, 10, 18, 14)).layout, 'symbol-placement': 'line' },
        paint: chu(0).paint,
      },
      {
        id: 'ten-dao', type: 'symbol', source: 'vn', 'source-layer': 'earth',
        filter: ['all', ['==', ['geometry-type'], 'Point'], ['has', 'name']],
        ...chu(noiSuy(4, 10, 12, 13), m.chuPhu, 'Noto Sans Italic'),
      },
      {
        id: 'ten-dia-danh', type: 'symbol', source: 'vn', 'source-layer': 'places',
        filter: ['all', loai('locality', 'neighbourhood', 'macrohood'), ['>=', ['zoom'], ['coalesce', ['get', 'min_zoom'], 0]]],
        layout: {
          ...chu(0).layout,
          'text-size': ['interpolate', ['linear'], ['coalesce', ['get', 'population_rank'], 1], 1, 11, 15, 18],
          'symbol-sort-key': ['-', 20, ['coalesce', ['get', 'population_rank'], 0]],
        },
        paint: chu(0).paint,
      },
      {
        id: 'ten-vung', type: 'symbol', source: 'vn', 'source-layer': 'places', minzoom: 5, maxzoom: 10, filter: loai('region'),
        ...chu(noiSuy(5, 10, 9, 13), m.chuPhu, 'Noto Sans Medium'),
      },
      {
        id: 'ten-quoc-gia', type: 'symbol', source: 'vn', 'source-layer': 'places', maxzoom: 8, filter: loai('country'),
        ...chu(noiSuy(2, 12, 7, 18), m.chu, 'Noto Sans Medium'),
      },
    ],
  };
}
