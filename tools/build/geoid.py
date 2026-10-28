#!/usr/bin/env python3
# Sinh lưới độ cao geoid EGM96 1° toàn cầu (asset nhỏ) để đổi độ cao GPS (trên elipxoit WGS84) sang độ cao trên mực
# nước biển trung bình khi máy không trả sẵn (Android < 14). Nguồn: lưới us_nga_egm96_15 của PROJ (NGA, phạm vi công cộng).
#
#   python3 -m venv /tmp/dg && /tmp/dg/bin/pip install -r tools/build/dia-ly.requirements.txt
#   /tmp/dg/bin/python -I tools/build/geoid.py
#
# Định dạng: "LBGE" + u16 phiên bản + 181 hàng (vĩ độ 90 -> -90) x 360 cột (kinh độ -180 -> 179), int16 LE, đơn vị dm.
# Nội suy song tuyến ở `packages/location_feature/lib/src/domain/geoid.dart`; sai số so lưới 15' < 2 m ở đa số nơi.
import hashlib
import struct
from pathlib import Path

import pyproj

GOC = Path(__file__).resolve().parents[2]
RA = GOC / 'packages/location_feature/assets/geoid_egm96_1do.bin'

pyproj.network.set_network_enabled(True)
doi = pyproj.Transformer.from_crs('EPSG:4979', 'EPSG:4326+5773', always_xy=True)
ra = bytearray(b'LBGE' + struct.pack('<H', 1))
for vi in range(90, -91, -1):
    for kinh in range(-180, 180):
        # Độ cao elipxoit 0 -> độ cao EGM96 = -N.
        n = -doi.transform(kinh, vi, 0, errcheck=True)[2]
        ra += struct.pack('<h', round(n * 10))
RA.write_bytes(bytes(ra))
print(f'{RA.relative_to(GOC)}: {len(ra)} byte, sha256 {hashlib.sha256(ra).hexdigest()}')
