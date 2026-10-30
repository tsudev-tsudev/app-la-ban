#!/usr/bin/env bash
# Điều phối agent cho repo app "La bàn" (rút gọn từ agents.sh của repo ban-do-3d).
# Trạng thái sống: AGENTS_BOARD.md · nhật ký append-only: AGENTS_LOG.md · quy trình: AGENTS_KICKOFF.md.
set -euo pipefail
cd "$(dirname "$0")"
BOARD=AGENTS_BOARD.md
LOG=AGENTS_LOG.md

chen_sau() { # chen_sau <mẫu tiêu đề> <dòng>: chèn ngay dưới tiêu đề.
  local mau="$1" dong="$2" tam
  tam=$(mktemp)
  awk -v mau="$mau" -v dong="$dong" '{ print } $0 ~ mau && !xong { print dong; xong = 1 }' "$BOARD" > "$tam" && mv "$tam" "$BOARD"
}

case "${1:-help}" in
  brief) sed -n '/^## LOCKS/,/^> /p' "$BOARD" ;;
  status) cat "$BOARD" ;;
  lock)
    [ -n "${2:-}" ] || { echo 'Cần: ./agents.sh lock "agent-X · tệp · việc"' >&2; exit 2; }
    chen_sau '^## LOCKS' "- $2"; echo "Đã khoá: $2" ;;
  unlock)
    # Khớp CHUỖI CON trên đúng mục LOCKS - dùng mẫu HẸP kẻo xoá lock của người khác.
    [ -n "${2:-}" ] || { echo 'Cần: ./agents.sh unlock "<mẫu hẹp>"' >&2; exit 2; }
    tam=$(mktemp)
    awk -v m="$2" '/^## /{ trong = ($0 ~ /^## LOCKS/) } !(trong && index($0, m) && /^- /)' "$BOARD" > "$tam" && mv "$tam" "$BOARD"
    echo "Đã gỡ lock khớp: $2" ;;
  note)
    [ -n "${2:-}" ] || { echo 'Cần: ./agents.sh note "<cảnh báo còn hiệu lực>"' >&2; exit 2; }
    chen_sau '^## Lưu ý' "- $2"; echo "Đã ghi lưu ý (KHÔNG chạy lại - sẽ thành dòng trùng)." ;;
  log)
    [ -n "${2:-}" ] || { echo 'Cần: ./agents.sh log "<nội dung>" (dùng nháy ĐƠN)' >&2; exit 2; }
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M')" "$2" >> "$LOG"; echo "Đã ghi nhật ký - nhớ COMMIT AGENTS_LOG.md." ;;
  find)
    [ -n "${2:-}" ] || { echo 'Cần: ./agents.sh find "<từ khoá>"' >&2; exit 2; }
    grep -nF -- "$2" "$LOG" docs/BAY_DA_GAP.md docs/ke-hoach/*.md QUYET_DINH.md 2>/dev/null | cut -c1-400 || echo "(không thấy)" ;;
  handoff)
    [ $# -ge 5 ] || { echo 'Cần: ./agents.sh handoff <từ> <đến> "<vùng>" "<việc còn lại>"' >&2; exit 2; }
    ma="HGLB-$(date '+%m%d-%H%M%S')"
    # Hai phiếu trong cùng một giây trùng mã (đóng một phiếu = đóng cả hai) -> tăng giây tới khi chưa dùng.
    while grep -qF "$ma" "$LOG"; do ma="HGLB-$(date -d "@$(( $(date -d "$(date '+%Y')-${ma:5:2}-${ma:7:2} ${ma:10:2}:${ma:12:2}:${ma:14:2}" +%s) + 1 ))" '+%m%d-%H%M%S')"; done
    printf '[%s] %s | BÀN GIAO %s → %s | %s | %s\n' "$(date '+%Y-%m-%d %H:%M')" "$2" "$ma" "$3" "$4" "$5" >> "$LOG"
    echo "Đã mở phiếu $ma gửi $3. Đóng: ./agents.sh handoff-done $ma" ;;
  inbox)
    [ -n "${2:-}" ] || { echo 'Cần: ./agents.sh inbox <agent>' >&2; exit 2; }
    mo=0
    while IFS= read -r dong; do
      ma=$(grep -oE 'HGLB-[0-9]{4}-[0-9]{6}' <<<"$dong" | head -1)
      [ -n "$ma" ] || continue
      grep -qF "ĐÓNG $ma" "$LOG" && continue
      mo=$((mo + 1)); echo "  $dong"
    done < <(grep -F "→ $2 |" "$LOG" | grep -F 'BÀN GIAO' || true)
    [ "$mo" -eq 0 ] && echo "✓ Không có phiếu nào đang mở cho $2." || true ;;
  handoff-done)
    [ -n "${2:-}" ] || { echo 'Cần: ./agents.sh handoff-done <mã>' >&2; exit 2; }
    printf '[%s] ĐÓNG %s\n' "$(date '+%Y-%m-%d %H:%M')" "$2" >> "$LOG"; echo "Đã đóng $2." ;;
  runners)
    # Ngoặc vuông trong mẫu: grep không tự khớp chính dòng lệnh này.
    ds=$(ps -eo pid,etime,args | grep -E '[f]lutter_tools|[d]art .*test|[g]radle|[v]itest|[v]ite build|[a]stro build|[w]rangler (dev|deploy|pages)|[m]elos' | grep -v 'shell-snapshots' || true)
    if [ -z "$ds" ]; then echo "✓ Không có tiến trình nặng - được chạy test / build."
    else echo "⏳ ĐANG CHẠY (xếp hàng, đừng chạy chồng):"; printf '%s\n' "$ds" | cut -c1-200 | sed 's/^/  /'; fi
    for c in 3030 3031 8797; do ss -ltn 2>/dev/null | grep -q ":$c " && echo "ℹ️  Cổng :$c đang mở." || true; done ;;
  sync-agents-md)
    cp CLAUDE.md AGENTS.md && echo "AGENTS.md = CLAUDE.md" ;;
  check-agents-md)
    cmp -s CLAUDE.md AGENTS.md && echo "✓ AGENTS.md đồng bộ" || { echo "✗ AGENTS.md lệch CLAUDE.md - chạy ./agents.sh sync-agents-md" >&2; exit 1; } ;;
  *)
    cat <<'EOT'
./agents.sh brief | status | runners
./agents.sh lock "agent-X · tệp · việc"     |  unlock "<mẫu hẹp>"
./agents.sh log '<nội dung>'                 |  note '<cảnh báo>'   |  find '<từ khoá>'
./agents.sh handoff <từ> <đến> "<vùng>" "<việc>"  |  inbox <agent>  |  handoff-done <mã>
./agents.sh sync-agents-md | check-agents-md
EOT
    ;;
esac
