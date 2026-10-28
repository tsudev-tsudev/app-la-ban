#!/usr/bin/env bash
# Deploy một site web lên Cloudflare Pages: ./tools/build/deploy-web.sh <landing|admin|status> [nhanh]
#   nhanh mặc định main (production). Nhánh khác -> URL preview https://<id>.la-ban-<site>.pages.dev
# Wrangler 4 tự chạy "autoconfig" (npm i @astrojs/cloudflare, sửa vite.config) khi gọi trong thư mục workspace
# (bẫy WRANGLER AUTOCONFIG) -> luôn gọi từ thư mục tạm trống, truyền đường dẫn dist tuyệt đối.
set -euo pipefail
cd "$(dirname "$0")/../.."
GOC="$PWD"
SITE="${1:?cần landing|admin|status}"
NHANH="${2:-main}"
case "$SITE" in landing|admin|status) ;; *) echo "site không hợp lệ: $SITE" >&2; exit 2 ;; esac
if [ -s "$HOME/.nvm/nvm.sh" ]; then set +u; . "$HOME/.nvm/nvm.sh"; nvm use >/dev/null; set -u; fi
set -a; . "$HOME/.config/la-ban/cf.env"; set +a
export WRANGLER_SEND_METRICS=false ASTRO_TELEMETRY_DISABLED=1

if [ "$SITE" = status ]; then node web/status/build.mjs; else npm run build -w "web/$SITE" --silent; fi
node tools/kiem-tra/ve-sinh-ban-build.mjs "web/$SITE/dist"

TAM=$(mktemp -d)
trap 'rm -rf "$TAM"' EXIT
(cd "$TAM" && "$GOC/node_modules/.bin/wrangler" pages deploy "$GOC/web/$SITE/dist" \
  --project-name "la-ban-$SITE" --branch "$NHANH" --commit-hash "$(git -C "$GOC" rev-parse HEAD)" --commit-dirty=true)
