#!/usr/bin/env python3
# Sinh điểm mẫu chuẩn cho test location_feature từ thư viện tham chiếu độc lập: UTM (pyproj / PROJ), MGRS (mgrs /
# GeoTrans NGA), mặt trời + mặt trăng (ephem / libastro), geoid EGM96 lưới 15' (pyproj). Chạy lại chỉ khi đổi bộ điểm.
#
#   /tmp/dg/bin/pip install -r tools/build/dia-ly.requirements.txt mgrs==1.7.0 ephem==4.2.1
#   /tmp/dg/bin/python -I tools/build/mau-test-vi-tri.py
import json
import math
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path

import ephem
import mgrs
import pyproj

GOC = Path(__file__).resolve().parents[2]
RA = GOC / 'packages/location_feature/test/du_lieu/mau_chuan.json'
rnd = random.Random(20261029)

# Điểm cố định: Hà Nội, TP.HCM, xích đạo / kinh tuyến gốc, Na Uy (vùng 32V), Svalbard (31X-37X), Nam bán cầu, biên vùng.
co_dinh = [
    (21.028511, 105.804817), (10.776889, 106.700806), (16.054407, 108.202167), (8.6820, 106.6090),
    (0.0, 0.0), (0.0, 179.9999), (-0.000001, -0.000001), (60.0, 5.0), (56.5, 3.5), (63.9, 11.9),
    (78.0, 8.0), (78.0, 10.0), (78.0, 20.0), (78.0, 22.0), (78.0, 32.0), (78.0, 34.0), (83.99, 41.0),
    (-33.8688, 151.2093), (-79.99, -70.0), (-45.0, -0.0001), (51.5007, -0.1246), (40.6892, -74.0445),
    (64.0, 6.0), (72.0, 0.5), (-23.4, -46.6), (35.6762, 139.6503), (8.0, 102.0), (23.39, 105.32),
]
diem = co_dinh + [(rnd.uniform(-79.9, 83.9), rnd.uniform(-180, 179.999)) for _ in range(300)]
m = mgrs.MGRS()
utm = []
for vi, kinh in diem:
    z = int((kinh + 180) // 6) + 1
    if 56 <= vi < 64 and 3 <= kinh < 12:
        z = 32
    if 72 <= vi < 84 and kinh >= 0:
        z = 31 if kinh < 9 else 33 if kinh < 21 else 35 if kinh < 33 else 37 if kinh < 42 else z
    epsg = (32600 if vi >= 0 else 32700) + z
    e, n = pyproj.Transformer.from_crs('EPSG:4326', f'EPSG:{epsg}', always_xy=True).transform(kinh, vi)
    utm.append({'viDo': vi, 'kinhDo': kinh, 'vung': z, 'dong': round(e, 4), 'bac': round(n, 4),
                'mgrs': m.toMGRS(vi, kinh, MGRSPrecision=5)})

pyproj.network.set_network_enabled(True)
geo = pyproj.Transformer.from_crs('EPSG:4979', 'EPSG:4326+5773', always_xy=True)
geoid = []
for _ in range(400):
    vi, kinh = rnd.uniform(-89, 89), rnd.uniform(-180, 179.99)
    geoid.append({'viDo': vi, 'kinhDo': kinh, 'n': round(-geo.transform(kinh, vi, 0, errcheck=True)[2], 3)})
for vi, kinh in [(21.0285, 105.8048), (10.7769, 106.7008), (16.0544, 108.2022), (22.33, 103.84)]:
    geoid.append({'viDo': vi, 'kinhDo': kinh, 'n': round(-geo.transform(kinh, vi, 0, errcheck=True)[2], 3), 'vn': True})


def iso(d):
    return d.datetime().replace(tzinfo=timezone.utc).isoformat().replace('+00:00', 'Z') if d else None


thien_van = []
noi = [(21.0285, 105.8048), (10.7769, 106.7008), (16.0544, 108.2022), (51.4779, -0.0015), (-33.8688, 151.2093),
       (64.1466, -21.9426), (0.0, 0.0), (35.6762, 139.6503)]
for i in range(60):
    vi, kinh = noi[i % len(noi)] if i < 24 else (rnd.uniform(-60, 60), rnd.uniform(-180, 180))
    t0 = datetime(2026, 1, 1, tzinfo=timezone.utc) + timedelta(seconds=rnd.uniform(0, 4 * 365 * 86400))
    o = ephem.Observer()
    o.lat, o.lon, o.elevation, o.pressure = str(vi), str(kinh), 0, 0
    o.date = ephem.Date(t0.replace(tzinfo=None))
    s, mo = ephem.Sun(o), ephem.Moon(o)

    def su_kien(than, chan_troi, tam):
        o2 = ephem.Observer()
        o2.lat, o2.lon, o2.elevation, o2.pressure, o2.horizon = str(vi), str(kinh), 0, 0, chan_troi
        o2.date = o.date
        kq = {}
        for ten, ham in (('moc', o2.next_rising), ('lan', o2.next_setting)):
            try:
                kq[ten] = iso(ham(than, use_center=tam))
            except (ephem.AlwaysUpError, ephem.NeverUpError):
                kq[ten] = None
        kq['dinh'] = iso(o2.next_transit(than))
        return kq

    thien_van.append({
        'viDo': vi, 'kinhDo': kinh, 'luc': t0.isoformat().replace('+00:00', 'Z'),
        'matTroi': {'phuongVi': math.degrees(s.az), 'doCao': math.degrees(s.alt),
                    **su_kien(ephem.Sun(), '-0:50', True)},
        'matTrang': {'phuongVi': math.degrees(mo.az), 'doCao': math.degrees(mo.alt), 'sang': mo.moon_phase,
                     **su_kien(ephem.Moon(), '-0:34', False)},
    })

RA.write_text(json.dumps({'nguon': 'pyproj 3.8.0 (PROJ), mgrs 1.7.0 (GeoTrans), ephem 4.2.1',
                          'utm': utm, 'geoid': geoid, 'thienVan': thien_van}, ensure_ascii=False, indent=0) + '\n')
print(f'{RA.relative_to(GOC)}: {len(utm)} UTM, {len(geoid)} geoid, {len(thien_van)} thiên văn')
