#!/usr/bin/env bash
# Kiểm tệp phát hành trên VirusTotal TRƯỚC khi công bố (phiếu AV1, DISTRIBUTION_TRUST mục 3):
#   ./tools/build/kiem-virustotal.sh <tệp>...
# Tra băm SHA-256; tệp chưa có trên VT thì tải lên rồi chờ kết quả (tối đa ~10 phút / tệp).
# Đỏ (exit 1) nếu một hãng báo malicious / suspicious -> KHÔNG công bố, ghi docs/store/antivirus.md + nộp báo nhầm.
# Khoá API: ~/.config/tsudev/virustotal.env (một dòng, chỉ khoá; NGOÀI repo). Không in khoá. Không có khoá -> bỏ qua (exit 2).
set -euo pipefail
TEP_KHOA="${VT_KHOA_TEP:-$HOME/.config/tsudev/virustotal.env}"
if [ ! -r "$TEP_KHOA" ]; then
  echo "⚠ Không có $TEP_KHOA - bỏ qua kiểm VirusTotal (kiểm tay trước khi công bố)." >&2
  exit 2
fi
VT_KHOA=$(sed -n 's/^\(VT_API_KEY=\|VIRUSTOTAL_API_KEY=\)\{0,1\}//p' "$TEP_KHOA" | tr -d ' \r\n"')
export VT_KHOA
API=https://www.virustotal.com/api/v3

goi() { curl -sS -H "x-apikey: $VT_KHOA" "$@"; }

thong_ke() {
  python3 -c 'import json,sys
d=json.load(sys.stdin)
if "error" in d: print("LOI", d["error"].get("code")); sys.exit()
a=d["data"]["attributes"]; s=a.get("last_analysis_stats") or a.get("stats") or {}
print(a.get("status","completed"), s.get("malicious",0), s.get("suspicious",0), s.get("undetected",0)+s.get("harmless",0))'
}

do_=0
for tep in "$@"; do
  bam=$(sha256sum "$tep" | cut -d' ' -f1)
  read -r tt mal sus sach < <(goi "$API/files/$bam" | thong_ke)
  if [ "$tt" = "LOI" ]; then
    co=$(stat -c %s "$tep")
    if [ "$co" -gt 33554432 ]; then
      dich=$(goi "$API/files/upload_url" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"])')
    else
      dich="$API/files"
    fi
    id=$(goi -F "file=@$tep" "$dich" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["id"])')
    for _ in $(seq 1 40); do
      read -r tt mal sus sach < <(goi "$API/analyses/$id" | thong_ke)
      [ "$tt" = "completed" ] && break
      sleep 15
    done
    [ "$tt" = "completed" ] || { echo "✗ $(basename "$tep"): VT chưa xong sau 10 phút - kiểm lại sau" >&2; do_=1; continue; }
  fi
  if [ "$mal" -gt 0 ] || [ "$sus" -gt 0 ]; then
    echo "✗ $(basename "$tep"): malicious=$mal suspicious=$sus - https://www.virustotal.com/gui/file/$bam" >&2
    do_=1
  else
    echo "✓ $(basename "$tep"): 0 cờ ($sach hãng sạch) - https://www.virustotal.com/gui/file/$bam"
  fi
done
exit "$do_"
