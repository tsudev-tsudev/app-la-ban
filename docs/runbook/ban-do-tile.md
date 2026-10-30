# Runbook - tile bản đồ (A7a, QUYET_DINH Q38)

Tile vector Việt Nam (đất liền + Hoàng Sa + Trường Sa) trích từ bản PMTiles hành tinh của Protomaps (dữ liệu
© OpenStreetMap, ODbL), lưu ở R2 `la-ban-cdn/ban-do/<bộ>/`, Worker `la-ban-api` phục vụ dạng XYZ ở `/ban-do/*`.

## Làm mới bộ tile (vài tháng một lần)

```bash
. ~/.nvm/nvm.sh && nvm use
B=20261029   # ngày bản Protomaps (https://build.protomaps.com/ - giữ ~1 tuần)
N=https://build.protomaps.com/$B.pmtiles
node tools/build/tile-vn.mjs --nguon $N --thu --zmax 14                 # đo dung lượng theo zoom
node tools/build/tile-vn.mjs --nguon $N --zmin 0 --zmax 13 --ra build/tile/$B/vn-0-13.pmtiles
node tools/build/tile-vn.mjs --nguon $N --zmin 14 --zmax 14 --ra build/tile/$B/vn-14.pmtiles
set -a; . ~/.config/la-ban/cf.env; set +a
for t in vn-0-13 vn-14; do
  npx wrangler r2 object put la-ban-cdn/ban-do/$B/$t.pmtiles --remote --file build/tile/$B/$t.pmtiles \
    --content-type application/vnd.pmtiles --cache-control 'public, max-age=31536000, immutable'
done
```

Rồi đổi `BO_TILE` trong `workers/api/src/thuan/ban-do.ts` -> PR -> deploy staging rồi prod. Bộ cũ GIỮ trên R2 ít nhất
30 ngày: vùng offline đã tải trên máy trỏ URL bộ cũ (Worker trả 404 cho bộ khác `BO_TILE` -> app phải tải lại vùng; A7b
xử lý). Mỗi tệp phải < 300 MiB (giới hạn `wrangler r2 object put`); vượt thì tách thêm theo zoom ở `TEP_TILE`.

Mạng tới build.protomaps.com hay đứt giữa chừng: công cụ tự thử lại 5 lần / đoạn; chạy lại từ đầu nếu vẫn lỗi.

## Kiểm sau deploy

```bash
curl -s -o /dev/null -w '%{http_code} %{size_download}\n' https://compass-api.tsudev.com/ban-do/$B/13/6504/3606.mvt   # 200, ~170 KB (Hà Nội)
curl -s https://compass-api.tsudev.com/ban-do/kieu/sang-vi.json | head -c 200
```

## Glyph

`ban-do/phong/Noto Sans {Regular,Medium,Italic}/<dải>.pbf` từ github.com/protomaps/basemaps-assets (OFL). Chỉ dải trong
`DAI_GLYPH` (Latin + tiếng Việt); thêm dải = tải lên R2 + thêm vào mảng.
