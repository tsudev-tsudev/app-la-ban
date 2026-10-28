#!/usr/bin/env python3
# Sinh asset địa giới hành chính Việt Nam ngoại tuyến (QUYET_DINH Q28) từ bản trích OSM của Geofabrik.
#
#   python3 -m venv /tmp/dg && /tmp/dg/bin/pip install -r tools/build/dia-ly.requirements.txt
#   curl -L -o /tmp/vn.osm.pbf https://download.geofabrik.de/asia/vietnam-latest.osm.pbf
#   /tmp/dg/bin/python -I tools/build/dia-gioi.py /tmp/vn.osm.pbf
#
# Tỉnh / thành = admin_level 4 có ISO3166-2 "VN-*"; xã / phường / đặc khu (sau sắp xếp 01/07/2025, bỏ cấp huyện)
# = admin_level 6 nằm trong một tỉnh. Ranh giới đơn giản hoá (Douglas-Peucker) rồi mã hoá nhị phân gọn - định dạng
# ở `packages/location_feature/lib/src/domain/dia_gioi.dart` (giaiMaDiaGioi). Dữ liệu © OpenStreetMap contributors (ODbL).
import hashlib
import struct
import sys
from pathlib import Path

import osmium
from shapely import wkb
from shapely.geometry import MultiPolygon, Polygon
from shapely.ops import polygonize, unary_union

GOC = Path(__file__).resolve().parents[2]
RA = GOC / 'packages/location_feature/assets/dia_gioi_vn.bin'
# Lượng tử toạ độ 1e-5 độ (~1,1 m) - nhỏ hơn nhiều sai số do đơn giản hoá.
LUONG_TU = 100000
# Dung sai đơn giản hoá (độ): tỉnh ~110 m, xã ~33 m.
DUNG_SAI = {4: 0.001, 6: 0.0003}
MA_GIA_TRI = b'LBDG'
PHIEN_BAN = 1

# Bản trích Geofabrik cắt theo đường bao gần bờ nên KHÔNG có quần đảo Hoàng Sa, Trường Sa (quan hệ Khánh Hòa vì thế
# không khép vòng). Thêm vùng bao biển của hai đặc khu (theo Nghị quyết 1656/NQ-UBTVQH15 và 1667/NQ-UBTVQH15, 2025)
# để tra toạ độ ở đó ra đúng đơn vị hành chính Việt Nam. Vùng bao xấp xỉ (lon, lat), chỉ dùng tra cứu, không vẽ.
DAC_KHU_BIEN = [
    ('VN-DN', 'Đặc khu Hoàng Sa', 'Hoang Sa Special Zone',
     [(110.9, 15.6), (113.0, 15.6), (113.0, 17.3), (110.9, 17.3)]),
    ('VN-34', 'Đặc khu Trường Sa', 'Truong Sa Special Zone',
     [(111.3, 6.0), (115.0, 6.0), (117.9, 9.5), (117.9, 12.0), (113.5, 12.0), (111.3, 9.5)]),
]


def la_tinh_vn(t):
    return t.get('boundary') == 'administrative' and t.get('admin_level') == '4' and \
        t.get('ISO3166-2', '').startswith('VN-')


def thanh_vien_tinh(tep):
    """Lượt 1: id quan hệ tỉnh -> (thẻ, id các way thành viên) - để dựng lại tỉnh không khép vòng."""
    ra = {}
    for r in osmium.FileProcessor(tep, osmium.osm.RELATION):
        if la_tinh_vn(r.tags):
            ra[r.id] = ({k: v for k, v in r.tags}, [m.ref for m in r.members if m.type == 'w'])
    return ra


class GomVung(osmium.SimpleHandler):
    def __init__(self, can_way):
        super().__init__()
        self.vung = {4: [], 6: []}
        self.wkb = osmium.geom.WKBFactory()
        self.can_way = can_way
        self.toa_do_way = {}

    def way(self, w):
        if w.id in self.can_way:
            self.toa_do_way[w.id] = [(n.lon, n.lat) for n in w.nodes if n.location.valid()]

    def area(self, a):
        if a.from_way():
            return
        t = a.tags
        if t.get('boundary') != 'administrative':
            return
        try:
            cap = int(t.get('admin_level', '0'))
        except ValueError:
            return
        if cap not in self.vung:
            return
        if cap == 4 and not t.get('ISO3166-2', '').startswith('VN-'):
            return
        try:
            hinh = wkb.loads(self.wkb.create_multipolygon(a), hex=True)
        except Exception as e:  # vùng hỏng (vòng không khép) - bỏ, ghi ra để biết
            print(f'bỏ {t.get("name")}: {e}', file=sys.stderr)
            return
        self.vung[cap].append({
            'id': a.orig_id(),
            'ten': t.get('name', ''),
            'ten_en': t.get('name:en', ''),
            'ma': t.get('ISO3166-2', ''),
            'hinh': hinh,
        })


def varint(n):
    ra = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            ra.append(b | 0x80)
        else:
            ra.append(b)
            return bytes(ra)


def zigzag(n):
    return (n << 1) ^ (n >> 63)


def chuoi(s):
    b = s.encode('utf-8')
    return varint(len(b)) + b


def ma_hoa_hinh(hinh):
    """MultiPolygon -> [số vòng][mỗi vòng: số điểm, điểm đầu tuyệt đối, các điểm sau là hiệu] (zigzag varint).
    Vòng ngoài và lỗ không phân biệt: tra điểm dùng quy tắc chẵn-lẻ trên mọi vòng của một vùng."""
    vong = []
    ds = hinh.geoms if isinstance(hinh, MultiPolygon) else [hinh]
    for p in ds:
        vong.append(p.exterior.coords)
        vong.extend(r.coords for r in p.interiors)
    ra = bytearray(varint(len(vong)))
    for v in vong:
        diem = [(round(x * LUONG_TU), round(y * LUONG_TU)) for x, y in v][:-1]  # bỏ điểm lặp đóng vòng
        gon = []
        for d in diem:
            if not gon or gon[-1] != d:
                gon.append(d)
        ra += varint(len(gon))
        tx = ty = 0
        for x, y in gon:
            ra += varint(zigzag(x - tx)) + varint(zigzag(y - ty))
            tx, ty = x, y
    return bytes(ra)


def hop_bao(hinh):
    x0, y0, x1, y1 = hinh.bounds
    return struct.pack('<iiii', *(round(v * LUONG_TU) for v in (x0, y0, x1, y1)))


def don_gian(hinh, dung_sai):
    g = hinh.simplify(dung_sai, preserve_topology=True)
    if isinstance(g, Polygon):
        g = MultiPolygon([g])
    return g


def main():
    if len(sys.argv) != 2:
        sys.exit('dùng: dia-gioi.py <vietnam-latest.osm.pbf>')
    quan_he = thanh_vien_tinh(sys.argv[1])
    h = GomVung({w for _, ds in quan_he.values() for w in ds})
    h.apply_file(sys.argv[1], locations=True, idx='flex_mem')
    # Tỉnh có thành viên nằm ngoài bản trích: ghép các way có sẵn thành vòng (polygonize), bỏ đoạn hở.
    co = {v['id'] for v in h.vung[4]}
    for rid, (t, ds) in quan_he.items():
        if rid in co:
            continue
        hinh = unary_union(list(polygonize([h.toa_do_way[w] for w in ds if len(h.toa_do_way.get(w, [])) >= 2])))
        if hinh.is_empty:
            sys.exit(f'không dựng được {t.get("name")}')
        print(f'dựng lại {t.get("name")} từ way có sẵn: {hinh.area:.3f} độ²', file=sys.stderr)
        h.vung[4].append({'id': rid, 'ten': t.get('name', ''), 'ten_en': t.get('name:en', ''),
                          'ma': t['ISO3166-2'], 'hinh': hinh})
    tinh = sorted(h.vung[4], key=lambda v: v['ma'])
    ma_tinh = {t['ma']: t for t in tinh}
    # Đặc khu biển: thay hình OSM (nếu có, thường thiếu đảo) bằng vùng bao, nhập vào hình tỉnh.
    ten_dk = {ten for _, ten, _, _ in DAC_KHU_BIEN}
    h.vung[6] = [x for x in h.vung[6] if x['ten'] not in ten_dk]
    for ma, ten, ten_en, vong in DAC_KHU_BIEN:
        hinh = Polygon(vong)
        ma_tinh[ma]['hinh'] = unary_union([ma_tinh[ma]['hinh'], hinh])
        h.vung[6].append({'id': 0, 'ten': ten, 'ten_en': ten_en, 'ma': '', 'hinh': hinh})
    print(f'tỉnh: {len(tinh)}, vùng cấp 6 (cả ngoài VN): {len(h.vung[6])}')

    # Xã thuộc tỉnh chứa điểm đại diện; xã ngoài VN (Trung Quốc, Lào...) bị bỏ.
    xa_theo_tinh = {i: [] for i in range(len(tinh))}
    for x in h.vung[6]:
        p = x['hinh'].representative_point()
        for i, t in enumerate(tinh):
            if t['hinh'].contains(p):
                xa_theo_tinh[i].append(x)
                break
    tong_xa = sum(len(v) for v in xa_theo_tinh.values())
    print(f'xã / phường trong VN: {tong_xa}')

    r = osmium.io.Reader(sys.argv[1], osmium.osm.NOTHING)
    moc = r.header().get('osmosis_replication_timestamp', '')[:10]
    r.close()
    print(f'dữ liệu OSM đến: {moc}')
    ra = bytearray(MA_GIA_TRI + struct.pack('<HH', PHIEN_BAN, len(tinh)) + chuoi(f'OpenStreetMap {moc}'))
    for i, t in enumerate(tinh):
        dsxa = sorted(xa_theo_tinh[i], key=lambda v: v['ten'])
        ra += chuoi(t['ma']) + chuoi(t['ten']) + chuoi(t['ten_en'])
        g = don_gian(t['hinh'], DUNG_SAI[4])
        ra += hop_bao(g) + ma_hoa_hinh(g)
        ra += varint(len(dsxa))
        for x in dsxa:
            gx = don_gian(x['hinh'], DUNG_SAI[6])
            ra += chuoi(x['ten']) + chuoi(x['ten_en'])
            ra += hop_bao(gx) + ma_hoa_hinh(gx)
        print(f'  {t["ma"]:6} {t["ten"]:32} {len(dsxa):4} xã')

    RA.parent.mkdir(parents=True, exist_ok=True)
    RA.write_bytes(bytes(ra))
    print(f'{RA.relative_to(GOC)}: {len(ra)} byte, sha256 {hashlib.sha256(ra).hexdigest()}')


if __name__ == '__main__':
    main()
