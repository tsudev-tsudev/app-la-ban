#!/usr/bin/env bash
# Build AAB prod cho Google Play (R2): ./tools/build/build-aab.sh [--pro] [--khong-build]
#   --pro: app "La bàn Pro" (app_pro/, M2 - Q56, Q65) -> build/phat-hanh/pro/<pb>/la-ban-pro-<pb>.aab + kiểm KHÔNG có quảng cáo.
#   1. flutter build appbundle prod release --obfuscate --split-debug-info (3 ABI - Play tự tách theo máy)
#   2. jarsigner verify + so chứng chỉ với khoá upload ngoài repo (QUYET_DINH Q34: Play App Signing dùng CHÍNH khoá này)
#   3. quyền trong manifest đã gộp phải khớp docs/store/data-safety.md mục 1
#   4. đo "download size" thật theo cấu hình máy (bundletool get-size total) - ngân sách 25 MB (KE_HOACH A8b phát sinh)
# bundletool lấy từ cache Gradle (AGP đã tải) - không tải jar ngoài. Kết quả: build/phat-hanh/<phiên bản>/la-ban-<pb>.aab + kich-thuoc.txt
set -euo pipefail
cd "$(dirname "$0")/../.."
GOC="$PWD"
BUILD=1
APP=app
TEN_TEP=la-ban
for a in "$@"; do
  case "$a" in --khong-build) BUILD=0 ;; --pro) APP=app_pro; TEN_TEP=la-ban-pro ;; *) echo "tham số lạ: $a" >&2; exit 2 ;; esac
done

KHOA_DIR="$HOME/.config/la-ban/android"
KEY_PROPS="${LA_BAN_KEY_PROPERTIES:-$KHOA_DIR/key.properties}"
[ -f "$KEY_PROPS" ] || { echo "Thiếu khoá upload: $KEY_PROPS (xem QUYET_DINH Q34)" >&2; exit 1; }
export PATH="$HOME/tools/flutter/bin:$HOME/tools/java/jdk21/bin:$PATH" JAVA_HOME="$HOME/tools/java/jdk21" ANDROID_HOME="$HOME/tools/android-sdk"
export GRADLE_USER_HOME="$HOME/tools/java/gradle-home"
# bundletool bản thư viện (cache Gradle) không kèm aapt2 -> dùng aapt2 của SDK.
BT="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)"

DONG=$(grep -E '^version:' "$APP/pubspec.yaml" | awk '{print $2}')
TEN="${DONG%%+*}"
PHU=""; [ "$APP" = app_pro ] && PHU="pro/"
RA="$GOC/build/phat-hanh/$PHU$TEN"
SYM="$KHOA_DIR/symbols/$PHU$TEN/aab"
AAB="$GOC/$APP/build/app/outputs/bundle/prodRelease/app-prod-release.aab"
mkdir -p "$RA" "$SYM"

if [ "$BUILD" = 1 ]; then
  (cd "$APP" && flutter build appbundle --flavor prod -t lib/main_prod.dart --release --obfuscate --split-debug-info="$SYM")
  # Gradle daemon JDK 21 giữ ~1,5 GB - máy 8 GB cần trả lại cho cổng / test.
  (cd "$APP/android" && ./gradlew --stop >/dev/null)
fi
[ -f "$AAB" ] || { echo "Chưa có $AAB" >&2; exit 1; }
cp "$AAB" "$RA/$TEN_TEP-$TEN.aab"
AAB="$RA/$TEN_TEP-$TEN.aab"

# Chứng chỉ ký AAB = chứng chỉ khoá upload.
STORE=$(grep '^storeFile=' "$KEY_PROPS" | cut -d= -f2-)
PASS=$(grep '^storePassword=' "$KEY_PROPS" | cut -d= -f2-)
ALIAS=$(grep '^keyAlias=' "$KEY_PROPS" | cut -d= -f2-)
CERT=$(keytool -exportcert -keystore "$STORE" -alias "$ALIAS" -storepass "$PASS" | sha256sum | cut -d' ' -f1)
jarsigner -verify "$AAB" >/dev/null || { echo "AAB chưa ký / chữ ký hỏng" >&2; exit 1; }
CO=$(keytool -printcert -jarfile "$AAB" | sed -n 's/.*SHA256: //p' | head -1 | tr -d ':' | tr 'A-F' 'a-f')
[ "$CO" = "$CERT" ] || { echo "Chứng chỉ AAB ($CO) khác khoá upload ($CERT)" >&2; exit 1; }

# bundletool + phụ thuộc từ cache Gradle (bản mới nhất có sẵn).
C="$GRADLE_USER_HOME/caches/modules-2/files-2.1"
jar() { ls "$C"/$1/*/*/*.jar 2>/dev/null | grep -v -- '-sources' | sort -V | tail -1; }
CP=$(ls "$C"/com.android.tools.build/bundletool/*/*/bundletool-*.jar | grep -v -- '-sources' | sort -V | tail -1)
for g in com.android.tools.build/aapt2-proto com.google.guava/guava com.google.guava/failureaccess com.google.protobuf/protobuf-java \
  com.google.protobuf/protobuf-java-util com.google.dagger/dagger javax.inject/javax.inject org.bitbucket.b_c/jose4j \
  com.google.code.gson/gson com.google.auto.value/auto-value-annotations; do
  j=$(jar "$g"); [ -n "$j" ] || { echo "Thiếu $g trong cache Gradle (chạy một bản build Android trước)" >&2; exit 1; }
  CP="$CP:$j"
done
bt() { java -cp "$CP" com.android.tools.build.bundletool.BundleToolMain "$@"; }

QUYEN=$(bt dump manifest --bundle "$AAB" | sed -n 's/.*uses-permission[^>]*android:name="\([^"]*\)".*/\1/p' | sort -u)
echo "Quyền: $(echo $QUYEN)"
for q in $QUYEN; do
  grep -q "\`${q##*.}\`" docs/store/data-safety.md || { echo "Quyền $q chưa khai ở docs/store/data-safety.md" >&2; exit 1; }
done

TAM=$(mktemp -d); trap 'rm -rf "$TAM"' EXIT
# M2 (Q56): AAB Pro không được chứa SDK quảng cáo / Advertising ID (Data Safety riêng không khai Advertising ID).
if [ "$APP" = app_pro ]; then
  (cd "$TAM" && unzip -qo "$AAB" 'base/dex/*' 'base/manifest/*')
  if grep -qa 'com/google/android/gms/ads' "$TAM"/base/dex/*.dex; then echo "AAB Pro có lớp com.google.android.gms.ads" >&2; exit 1; fi
  if printf '%s\n' $QUYEN | grep -qx 'com.google.android.gms.permission.AD_ID'; then echo "AAB Pro xin quyền AD_ID" >&2; exit 1; fi
  echo "✓ AAB Pro không có lớp / quyền quảng cáo"
fi
bt build-apks --bundle "$AAB" --output "$TAM/la-ban.apks" --overwrite --aapt2 "$BT/aapt2" >/dev/null
{
  echo "La bàn $TEN - download size Google Play (bundletool get-size total, byte nén, MIN-MAX)"
  for spec in "arm64-v8a 34 420 Galaxy-M32" "armeabi-v7a 28 320 may-32-bit" "x86_64 34 320 Chromebook"; do
    set -- $spec
    printf '{"supportedAbis":["%s"],"sdkVersion":%s,"screenDensity":%s,"supportedLocales":["vi-VN"]}' "$1" "$2" "$3" > "$TAM/spec.json"
    echo "$4 ($1, API $2, ${3}dpi): $(bt get-size total --apks "$TAM/la-ban.apks" --device-spec "$TAM/spec.json" | tail -1)"
  done
  echo "AAB: $(stat -c %s "$AAB") byte · SHA-256 $(sha256sum "$AAB" | cut -d' ' -f1)"
  echo "Chứng chỉ ký (khoá upload): $CERT"
} | tee "$RA/kich-thuoc.txt"
echo "✓ $AAB"
