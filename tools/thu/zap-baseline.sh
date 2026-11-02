#!/usr/bin/env bash
# ZAP baseline (R3a, SEC-TEST): spider + quét THỤ ĐỘNG (không active scan, không tấn công) bằng ZAP bản cross-platform
# ở ~/tools/ZAP_<ver> (JDK ~/tools/java/jdk). CHỈ quét staging / preview - KHÔNG quét prod (luật R3a).
#   ./tools/thu/zap-baseline.sh <url> [--access] [đường-dẫn ...]
#     --access: gửi service token Access staging (soc-e2e) qua replacer · đường dẫn thêm: gọi GET trước spider (API không có
#     trang để bò - vd /v1/status /openapi.json).
# Proxy nội bộ ZAP nghe :8798 (8080 dùng chung với repo khác). Báo cáo JSON + HTML ra ~/tools/zap-bao-cao/<host>-<ngày>.{json,html} (NGOÀI repo). Thoát 1 nếu có cảnh báo High.
set -euo pipefail
URL="${1:?cần URL đích (staging / preview)}"
HOST=$(printf '%s' "$URL" | sed -E 's#^https?://([^/]+).*#\1#')
case "$HOST" in
  compass.tsudev.com|compass-api.tsudev.com|compass-admin.tsudev.com|compass-cdn.tsudev.com|compass-status.tsudev.com)
    echo "từ chối: $HOST là PRODUCTION - chỉ quét staging / preview" >&2; exit 2 ;;
esac
ZAP_DIR=$(ls -d "$HOME"/tools/ZAP_* 2>/dev/null | sort -V | tail -1)
[ -x "$ZAP_DIR/zap.sh" ] || { echo "thiếu ZAP - xem docs/runbook/cong-cu-quet.md" >&2; exit 2; }
export JAVA_HOME="$HOME/tools/java/jdk" PATH="$HOME/tools/java/jdk/bin:$PATH"
RA="$HOME/tools/zap-bao-cao"; mkdir -p "$RA"
TEN="$HOST-$(date +%Y%m%d-%H%M)"
umask 077; TAM=$(mktemp -d); trap 'rm -rf "$TAM"' EXIT

shift
ACCESS=0; [ "${1:-}" = --access ] && { ACCESS=1; shift; }
GOC_URL="https://$HOST"
GOI=""
for d in "$@"; do GOI="$GOI
      - url: \"$GOC_URL$d\""; done
[ -n "$GOI" ] && GOI="  - type: requestor
    requests:$GOI"
THAY=""
if [ "$ACCESS" = 1 ]; then
  SVC="$HOME/.config/la-ban/cau-hinh/access-svc-e2e.json"
  CF_ID=$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1])).client_id)' "$SVC")
  CF_SECRET=$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1])).client_secret)' "$SVC")
  # Replacer của Automation Framework KHÔNG thay biến ${VAR} -> ghi thẳng vào kế hoạch trong thư mục tạm 0700 (umask
  # 077, xoá khi thoát). Không bao giờ chép tệp kế hoạch có token ra ngoài (ZAP_LOG bỏ qua khi --access).
  THAY="  - type: replacer
    rules:
      - description: cf-access-client-id
        matchType: req_header
        matchString: CF-Access-Client-Id
        replacementString: \"$CF_ID\"
      - description: cf-access-client-secret
        matchType: req_header
        matchString: CF-Access-Client-Secret
        replacementString: \"$CF_SECRET\""
fi

cat > "$TAM/ke-hoach.yaml" <<EOF
env:
  contexts:
    - name: dich
      urls: ["$URL"]
      includePaths: ["https://$HOST/.*"]
  parameters:
    failOnError: false
    progressToStdout: false
jobs:
$THAY
$GOI
  - type: passiveScan-config
    parameters:
      maxAlertsPerRule: 10
      scanOnlyInScope: true
  - type: spider
    parameters:
      context: dich
      maxDuration: 3
      maxChildren: 50
  - type: passiveScan-wait
    parameters:
      maxDuration: 5
  - type: report
    parameters:
      template: traditional-json
      reportDir: "$RA"
      reportFile: "$TEN"
  - type: report
    parameters:
      template: traditional-html
      reportDir: "$RA"
      reportFile: "$TEN"
EOF

"$ZAP_DIR/zap.sh" -cmd -port 8798 -dir "$TAM/home" -autorun "$TAM/ke-hoach.yaml" -silent >"$TAM/zap.log" 2>&1 && { [ -z "${ZAP_LOG:-}" ] || [ "$ACCESS" = 1 ] || cp "$TAM/zap.log" "$TAM/ke-hoach.yaml" "$RA/"; } || {
  tail -20 "$TAM/zap.log" >&2; echo "ZAP lỗi khi chạy" >&2; exit 2; }

node - "$RA/$TEN.json" <<'EOF'
const fs = require('fs');
const bc = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const muc = ['Info', 'Low', 'Medium', 'High'];
let cao = 0;
for (const site of bc.site ?? []) {
  for (const a of site.alerts ?? []) {
    const r = Number(a.riskcode);
    if (r >= 3) cao++;
    console.log(`${muc[r].padEnd(6)} ${a.pluginid.padEnd(6)} ${a.name} (${a.count ?? a.instances?.length ?? 0})`);
  }
}
console.log(`-> ${process.argv[2]} · High: ${cao}`);
process.exit(cao ? 1 : 0);
EOF
