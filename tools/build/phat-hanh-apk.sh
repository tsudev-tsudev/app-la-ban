#!/usr/bin/env bash
# Phát hành APK thử nghiệm (QUYET_DINH Q34): ./tools/build/phat-hanh-apk.sh [--khong-github] [--thu]
#   1. kiểm: đang ở main (hoặc HEAD tách rời) sạch, trùng origin/main, có khoá upload ngoài repo, tag chưa tồn tại
#   2. build prod release --obfuscate --split-debug-info: một APK cho mỗi ABI - arm64-v8a (gần như mọi máy) + armeabi-v7a (máy 32-bit) - KHÔNG universal (QUYET_DINH Q36)
#   3. apksigner verify + so chứng chỉ với khoá upload, SHA-256
#   4. R2 la-ban-cdn/android/ (tên có phiên bản, bất biến) + latest.json -> compass-cdn.tsudev.com/android/
#   5. GitHub Release pre-release v<phiên bản> kèm SHA256SUMS
# --thu: chỉ build + kiểm (không tải lên, không cần main sạch). Phiên bản lấy từ app/pubspec.yaml (vd 0.1.0-beta.1+1).
# Sau khi phát hành: ./tools/build/deploy-web.sh landing (trang /tai-ve đọc latest.json lúc build).
set -euo pipefail
cd "$(dirname "$0")/../.."
GOC="$PWD"
THU=0; GITHUB=1
for a in "$@"; do
  case "$a" in --thu) THU=1 ;; --khong-github) GITHUB=0 ;; *) echo "tham số lạ: $a" >&2; exit 2 ;; esac
done

KHOA_DIR="$HOME/.config/la-ban/android"
KEY_PROPS="${LA_BAN_KEY_PROPERTIES:-$KHOA_DIR/key.properties}"
[ -f "$KEY_PROPS" ] || { echo "Thiếu khoá upload: $KEY_PROPS (xem QUYET_DINH Q34)" >&2; exit 1; }
# JDK 21: maplibre_gl 0.27 biên dịch Java 21 (QUYET_DINH Q40).
export PATH="$HOME/tools/flutter/bin:$HOME/tools/java/jdk21/bin:$PATH" JAVA_HOME="$HOME/tools/java/jdk21" ANDROID_HOME="$HOME/tools/android-sdk"
export GRADLE_USER_HOME="$HOME/tools/java/gradle-home"
if [ -s "$HOME/.nvm/nvm.sh" ]; then set +u; . "$HOME/.nvm/nvm.sh"; nvm use >/dev/null; set -u; fi
BT="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)"

DONG=$(grep -E '^version:' app/pubspec.yaml | awk '{print $2}')
TEN="${DONG%%+*}"; MA="${DONG##*+}"
[[ "$TEN" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-z]+\.[0-9]+)?$ && "$MA" =~ ^[0-9]+$ ]] || { echo "version pubspec sai dạng: $DONG" >&2; exit 1; }
TAG="v$TEN"

if [ "$THU" = 0 ]; then
  # Worktree song song không giữ được nhánh main (đã checkout ở cây chính) -> chấp nhận HEAD tách rời, vẫn phải trùng origin/main.
  NHANH=$(git rev-parse --abbrev-ref HEAD)
  [ "$NHANH" = main ] || [ "$NHANH" = HEAD ] || { echo "Chỉ phát hành từ main (hoặc HEAD tách rời ở origin/main)" >&2; exit 1; }
  [ -z "$(git status --porcelain)" ] || { echo "Cây git chưa sạch" >&2; exit 1; }
  git fetch -q origin main
  [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "main chưa trùng origin/main" >&2; exit 1; }
  ! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || { echo "Tag $TAG đã có - tăng version trong app/pubspec.yaml" >&2; exit 1; }
fi

RA="$GOC/build/phat-hanh/$TEN"
SYM="$KHOA_DIR/symbols/$TEN"
rm -rf "$RA"; mkdir -p "$RA" "$SYM"
APK_DIR="$GOC/app/build/app/outputs/flutter-apk"

build() { # $1 = hậu tố tệp, $2 = target-platform
  (cd app && flutter build apk --flavor prod -t lib/main_prod.dart --release --obfuscate \
    --split-debug-info="$SYM/$1" --target-platform "$2")
  cp "$APK_DIR/app-prod-release.apk" "$RA/la-ban-$TEN-$1.apk"
}
build arm64 android-arm64
build armv7 android-arm

# Chứng chỉ mong đợi = chứng chỉ khoá upload.
STORE=$(grep '^storeFile=' "$KEY_PROPS" | cut -d= -f2-)
PASS=$(grep '^storePassword=' "$KEY_PROPS" | cut -d= -f2-)
ALIAS=$(grep '^keyAlias=' "$KEY_PROPS" | cut -d= -f2-)
CERT=$("$JAVA_HOME/bin/keytool" -exportcert -keystore "$STORE" -alias "$ALIAS" -storepass "$PASS" | sha256sum | cut -d' ' -f1)
for f in "$RA"/*.apk; do
  "$BT/apksigner" verify --min-sdk-version 26 "$f"
  CO=$("$BT/apksigner" verify --print-certs "$f" | sed -n 's/.*certificate SHA-256 digest: //p' | head -1)
  [ "$CO" = "$CERT" ] || { echo "Chứng chỉ $f không khớp khoá upload" >&2; exit 1; }
done
# SEC-APP APP-02 / APP-06: không debuggable, exported tối thiểu, có libla_ban_kt.so sạch chuỗi.
node "$GOC/tools/build/kiem-apk.mjs" "$RA"/*.apk
(cd "$RA" && sha256sum ./*.apk | sed 's| \./| |' > SHA256SUMS)
MIN_SDK=$("$BT/aapt2" dump badging "$RA/la-ban-$TEN-arm64.apk" | sed -n "s/^minSdkVersion:'\([0-9]*\)'.*/\1/p")
cat "$RA/SHA256SUMS"

node - "$RA" "$TEN" "$MA" "$MIN_SDK" "$CERT" "$TAG" <<'EOF' > "$RA/latest.json"
const [ra, ten, ma, minSdk, cert, tag] = process.argv.slice(2);
const fs = require('node:fs');
const sums = Object.fromEntries(fs.readFileSync(`${ra}/SHA256SUMS`, 'utf8').trim().split('\n').map((d) => d.split(/\s+/).reverse()));
const tep = (loai) => {
  const tenTep = `la-ban-${ten}-${loai}.apk`;
  return { loai, ten: tenTep, url: `https://compass-cdn.tsudev.com/android/${tenTep}`, co: fs.statSync(`${ra}/${tenTep}`).size, sha256: sums[tenTep] };
};
process.stdout.write(JSON.stringify({
  phienBan: ten, maPhienBan: Number(ma), ngay: new Date().toISOString(), minSdk: Number(minSdk), chungChiSha256: cert,
  github: `https://github.com/tsudev-tsudev/app-la-ban/releases/tag/${tag}`, tep: [tep('arm64'), tep('armv7')],
}, null, 2) + '\n');
EOF
cat "$RA/latest.json"
[ "$THU" = 1 ] && { echo "✓ Bản thử ở $RA (không tải lên)"; exit 0; }

set -a; . "$HOME/.config/la-ban/cf.env"; set +a
export WRANGLER_SEND_METRICS=false
TAM=$(mktemp -d); trap 'rm -rf "$TAM"' EXIT
put() { # $1 tệp, $2 khoá, $3 content-type, $4 cache-control, [$5 disposition]
  (cd "$TAM" && "$GOC/node_modules/.bin/wrangler" r2 object put "la-ban-cdn/$2" --remote --file "$1" \
    --content-type "$3" --cache-control "$4" ${5:+--content-disposition "$5"})
}
for f in "$RA"/*.apk; do
  b=$(basename "$f")
  put "$f" "android/$b" application/vnd.android.package-archive 'public, max-age=31536000, immutable' "attachment; filename=\"$b\""
done
put "$RA/SHA256SUMS" "android/la-ban-$TEN-SHA256SUMS.txt" 'text/plain; charset=utf-8' 'public, max-age=31536000, immutable'
put "$RA/latest.json" android/latest.json 'application/json' 'public, max-age=60'

for f in "$RA"/*.apk; do
  b=$(basename "$f")
  THAT=$(curl -sfL "https://compass-cdn.tsudev.com/android/$b" | sha256sum | cut -d' ' -f1)
  grep -q "$THAT  $b" "$RA/SHA256SUMS" || { echo "SHA-256 bản trên CDN khác bản build: $b" >&2; exit 1; }
done
echo "✓ CDN đúng SHA-256"

if [ "$GITHUB" = 1 ]; then
  export GH_TOKEN="${GH_TOKEN:-$(gh auth token --user tsudev-tsudev)}"
  {
    echo "Bản thử nghiệm Android (APK ký bằng khoá upload TsuDev, chưa qua Google Play)."
    echo
    echo "- \`la-ban-$TEN-arm64.apk\`: điện thoại Android 64-bit đời mới (khuyên dùng)"
    echo "- \`la-ban-$TEN-armv7.apk\`: máy Android 32-bit đời cũ (Android $MIN_SDK+) - chỉ dùng khi bản arm64 không cài được"
    echo
    echo "Kiểm toàn vẹn: \`sha256sum -c SHA256SUMS\`. Chứng chỉ ký SHA-256: \`$CERT\`."
    echo "Tải công khai + hướng dẫn cài: https://compass.tsudev.com/tai-ve"
  } > "$TAM/ghi-chu.md"
  gh release create "$TAG" "$RA"/*.apk "$RA/SHA256SUMS" --target main --prerelease --title "La bàn $TEN (Android)" --notes-file "$TAM/ghi-chu.md"
  git fetch -q --tags
fi
echo "✓ Đã phát hành $TAG - nhớ ./tools/build/deploy-web.sh landing"
