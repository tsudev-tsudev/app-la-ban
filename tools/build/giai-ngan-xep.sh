#!/usr/bin/env bash
# Giải mã ngăn xếp bản release đã che mã (S10b, QUYET_DINH Q49): dán ngăn xếp từ SOC > Sự cố app vào tệp rồi
#   ./tools/build/giai-ngan-xep.sh <tep-ngan-xep.txt> <phien-ban> [arm64|armv7]
# Symbol nằm NGOÀI repo ở ~/.config/la-ban/android/symbols/<phien-ban>/<abi>/ (phat-hanh-apk.sh / build-aab.sh ghi).
# Cần nguyên văn ngăn xếp kể cả dòng đầu ('*** *** ***', build_id, isolate_dso_base) - SOC lưu tối đa 8000 ký tự.
set -euo pipefail
TEP="${1:?can tep ngan xep}"; BAN="${2:?can phien ban, vd 0.1.0-beta.12}"; ABI="${3:-arm64}"
BAN="${BAN%%+*}"
case "$ABI" in arm64) TEN=app.android-arm64.symbols ;; armv7) TEN=app.android-arm.symbols ;; *) echo "abi la: $ABI" >&2; exit 2 ;; esac
SYM="$HOME/.config/la-ban/android/symbols/$BAN/$ABI/$TEN"
[ -f "$SYM" ] || { echo "Thieu symbol: $SYM" >&2; exit 1; }
export PATH="$HOME/tools/flutter/bin:$PATH"
flutter symbolize -i "$TEP" -d "$SYM"
