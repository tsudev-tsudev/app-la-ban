#!/usr/bin/env bash
# Cổng kiểm DUY NHẤT của repo (không có CI). Xem CLAUDE.md mục "Chạy và kiểm".
#   nhanh  : giữa phase - chỉ phần đã đổi so với main (Dart package / workspace web).
#   day-du : trước merge - toàn bộ + build web + vệ sinh bản build + quét bí mật / lỗ hổng phụ thuộc.
set -euo pipefail
cd "$(dirname "$0")/../.."
CHE_DO="${1:-nhanh}"
export PATH="$HOME/tools/flutter/bin:$HOME/tools/bin:$PATH"
export ASTRO_TELEMETRY_DISABLED=1 WRANGLER_SEND_METRICS=false
# Node theo .nvmrc (repo này dùng Node 24; mặc định máy vẫn là 20 cho repo khác).
if [ -s "$HOME/.nvm/nvm.sh" ]; then set +u; . "$HOME/.nvm/nvm.sh"; nvm use >/dev/null; set -u; fi

buoc() { printf '\n\033[1;36m== %s\033[0m\n' "$1"; }
loi() { printf '\033[1;31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

# Tệp đã đổi so với main (cả chưa commit). Repo chưa có main -> coi như đổi tất cả.
tep_doi() {
  if git rev-parse --verify -q main >/dev/null && [ "$CHE_DO" = nhanh ]; then
    { git diff --name-only main...HEAD; git diff --name-only; git diff --name-only --cached; git ls-files -o --exclude-standard; } | sort -u
  else
    { git ls-files; git ls-files -o --exclude-standard; } | sort -u
  fi
}
DOI=$(tep_doi)

buoc "Luật chung"
./agents.sh check-agents-md
dash=$(printf '%s\n' "$DOI" | grep -vE '^2026.*\.md$' | grep -E '\.(md|ts|tsx|mjs|js|dart|kt|swift|astro|json|yaml|yml|sh|toml|css|html|arb)$' \
  | while read -r f; do [ -f "$f" ] && grep -lP '[\x{2013}\x{2014}]' "$f" || true; done)
[ -z "$dash" ] || loi "Có em/en dash (chỉ dùng '-'):\n$dash"

# --- Web / Worker ---
ws_doi() { printf '%s\n' "$DOI" | grep -qE "^($1)/" ; }
WEB_DOI=0
printf '%s\n' "$DOI" | grep -qE '^(workers|web|tools)/|^(package(-lock)?\.json|tsconfig\.base\.json|eslint\.config\.mjs)$' && WEB_DOI=1
if [ "$CHE_DO" = day-du ] || [ "$WEB_DOI" = 1 ]; then
  buoc "Web: lint + typecheck + test"
  npx eslint --max-warnings 0 .
  for ws in workers/api web/shield web/admin web/landing; do
    if [ "$CHE_DO" = day-du ] || ws_doi "$ws" || printf '%s\n' "$DOI" | grep -qE '^(package-lock\.json|tsconfig\.base\.json)$'; then
      echo "-- $ws"
      npm run typecheck -w "$ws" --if-present --silent
      npm run test -w "$ws" --if-present --silent
    fi
  done
fi

# --- Flutter (pub workspace ở gốc) ---
FLUTTER_SAN_SANG=0
[ -x "$HOME/tools/flutter/bin/cache/dart-sdk/bin/dart" ] && [ -f "$HOME/tools/flutter/bin/cache/flutter.version.json" ] && FLUTTER_SAN_SANG=1
if [ -f pubspec.yaml ] && [ "$FLUTTER_SAN_SANG" = 0 ]; then
  [ "$CHE_DO" = day-du ] && loi "Flutter SDK chưa sẵn sàng (~/tools/flutter) - cổng day-du cần Flutter"
  echo "(Flutter SDK chưa sẵn sàng - bỏ qua phần Dart ở cổng nhanh)"
fi
if [ -f pubspec.yaml ] && [ "$FLUTTER_SAN_SANG" = 1 ]; then
  DART_DOI=$(printf '%s\n' "$DOI" | grep -E '^(app|packages/[^/]+)/' | sed -E 's#^(app|packages/[^/]+)/.*#\1#' | sort -u || true)
  printf '%s\n' "$DOI" | grep -qE '^(pubspec\.(yaml|lock)|analysis_options\.yaml)$' && DART_DOI="ALL"
  [ "$CHE_DO" = day-du ] && DART_DOI="ALL"
  if [ -n "$DART_DOI" ]; then
    buoc "Flutter: analyze + test"
    flutter pub get >/dev/null
    if [ "$DART_DOI" = ALL ]; then
      DART_DOI=$(ls -d app packages/*/ 2>/dev/null | sed 's#/$##')
    fi
    for goi in $DART_DOI; do
      [ -f "$goi/pubspec.yaml" ] || continue
      echo "-- $goi"
      if ! kq=$(cd "$goi" && flutter analyze --fatal-infos --fatal-warnings 2>&1); then
        printf '%s\n' "$kq" | grep '•' >&2; loi "flutter analyze đỏ ở $goi"
      fi
      echo "   analyze ✓"
      if [ -d "$goi/test" ]; then (cd "$goi" && flutter test --reporter failures-only); fi
    done
  fi
fi

if [ "$CHE_DO" = day-du ]; then
  buoc "Build web + vệ sinh bản build"
  npm run build -w web/landing --silent
  npm run build -w web/admin --silent
  npm run build -w workers/api --silent >/dev/null
  node tools/kiem-tra/ve-sinh-ban-build.mjs web/landing/dist web/admin/dist

  buoc "Quét bí mật"
  npx secretlint --secretlintignore .secretlintignore "**/*"
  if command -v gitleaks >/dev/null; then gitleaks dir . --no-banner --redact -c .gitleaks.toml; else echo "(gitleaks chưa cài - bỏ qua, secretlint đã chạy)"; fi

  buoc "Lỗ hổng phụ thuộc"
  npm audit --omit=dev --audit-level=high
  if command -v osv-scanner >/dev/null; then
    osv-scanner scan source --lockfile=package-lock.json $( [ -f pubspec.lock ] && echo --lockfile=pubspec.lock ) || loi "osv-scanner báo lỗ hổng"
  else echo "(osv-scanner chưa cài - pubspec.lock chưa được quét lỗ hổng)"; fi
fi

printf '\n\033[1;32m✓ Cổng %s xanh\033[0m\n' "$CHE_DO"
