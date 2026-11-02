#!/usr/bin/env bash
# R3c (Q52): độ trễ PHÍA SERVER theo route + thời gian chờ I/O trung bình từng bước, đọc từ Analytics Engine.
# Chạy: set -a; . ~/.config/la-ban/cf.env; set +a; ./tools/thu/do-tre-ae.sh [prod|staging] [số giờ, mặc định 24]
# Cột: n, p50 / p95 / max tổng (ms), rồi trung bình ms của chan rlIp phien nonce gioiHan luuTru d1, tỷ lệ isolate lạnh.
# Chỉ tính điểm có blob5 (colo) = bản đã có đo từng bước (từ R3c); _sample_interval để p50 / p95 đúng khi AE lấy mẫu.
set -euo pipefail
moiTruong="${1:-prod}"
gio="${2:-24}"
[[ "$gio" =~ ^[0-9]+$ ]] || { echo "số giờ phải là số nguyên" >&2; exit 2; }
case "$moiTruong" in
  prod) bang=la_ban_su_kien ;;
  staging) bang=la_ban_su_kien_staging ;;
  *) echo "môi trường: prod | staging" >&2; exit 2 ;;
esac
: "${CLOUDFLARE_ACCOUNT_ID:?nạp cf.env bằng set -a}" "${CLOUDFLARE_API_TOKEN:?nạp cf.env bằng set -a}"
sql="SELECT blob2, count() AS n,
 round(quantileWeighted(0.5)(double1, _sample_interval)) AS p50,
 round(quantileWeighted(0.95)(double1, _sample_interval)) AS p95, max(double1) AS max,
 round(avg(double2)) AS chan, round(avg(double3)) AS rlIp, round(avg(double4)) AS phien, round(avg(double5)) AS nonce,
 round(avg(double6)) AS gioiHan, round(avg(double7)) AS luuTru, round(avg(double8)) AS d1, round(avg(double9), 2) AS lanh
 FROM $bang WHERE timestamp > NOW() - INTERVAL '$gio' HOUR AND blob5 != '' AND blob2 LIKE '/v1/%'
 GROUP BY blob2 ORDER BY n DESC FORMAT TabSeparated"
{
  printf 'tuyen\tn\tp50\tp95\tmax\tchan\trlIp\tphien\tnonce\tgioiHan\tluuTru\td1\tlanh\n'
  curl -sf "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/analytics_engine/sql" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" --data "$sql"
} | column -t -s $'\t'
