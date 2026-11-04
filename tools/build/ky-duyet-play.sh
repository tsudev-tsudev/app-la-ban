#!/usr/bin/env bash
# Kill-switch Worker cho kỳ duyệt Google Play (Q57 / Q62 / Q63, docs/store/huong-dan-play-console.md mục E1.2 / E2.3).
#   ./tools/build/ky-duyet-play.sh bat         CHAN_DEV_MODE="0" (env prod) + deploy prod  - TRƯỚC khi gửi duyệt
#   ./tools/build/ky-duyet-play.sh tat         CHAN_DEV_MODE="1" (env prod) + deploy prod  - SAU khi được duyệt
#   ./tools/build/ky-duyet-play.sh trang-thai  giá trị trong wrangler.toml + bản Worker prod đang chạy
# Phần app (cờ chanDevMode, SOC four-eyes) và miễn trừ ASN Google làm ở SOC. Sau bat / tat: commit wrangler.toml qua PR.
set -euo pipefail
cd "$(dirname "$0")/../.."
TOML=workers/api/wrangler.toml
lenh=${1:-trang-thai}

giaTri() { awk '/^\[env\./{exit} /^CHAN_DEV_MODE *=/{gsub(/[" ]/,"",$0); split($0,a,"="); print a[2]}' "$TOML"; }

datGiaTri() {
  local v=$1 so
  so=$(awk '/^\[env\./{exit} /^CHAN_DEV_MODE *=/{print NR; exit}' "$TOML")
  [[ -n $so ]] || { echo "Không thấy CHAN_DEV_MODE ở env prod (đầu $TOML)" >&2; exit 1; }
  sed -i "${so}s/.*/CHAN_DEV_MODE = \"$v\"/" "$TOML"
}

wr() {
  set -a; . "$HOME/.config/la-ban/cf.env"; set +a
  # shellcheck disable=SC1091
  # nvm.sh hỏng dưới `set -u` -> tắt tạm (trước 04/11 deploy chết im lặng vì `|| true` bên dưới).
  set +u; source "$HOME/.nvm/nvm.sh" >/dev/null; nvm use >/dev/null; set -u
  (cd workers/api && npx wrangler "$@")
}

case $lenh in
  bat|tat)
    v=$([[ $lenh == bat ]] && echo 0 || echo 1)
    datGiaTri "$v"
    echo "CHAN_DEV_MODE (prod) = $(giaTri)"
    kq=$(wr deploy 2>&1) || { echo "$kq" | tail -20 >&2; echo "Deploy LỖI - CHAN_DEV_MODE đã đổi trong $TOML nhưng Worker prod CHƯA nhận" >&2; exit 1; }
    echo "$kq" | grep -E "Current Version ID|Deployed"
    echo "Nhớ: commit $TOML qua PR; SOC: cờ chanDevMode + miễn trừ ASN Google (mục E1 / E2)."
    ;;
  trang-thai)
    echo "wrangler.toml prod CHAN_DEV_MODE = $(giaTri) (1 = chặn, 0 = kỳ duyệt)"
    wr deployments list 2>/dev/null | tail -6 || true
    ;;
  *) sed -n 2,6p "$0"; exit 2 ;;
esac
