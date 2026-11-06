#!/usr/bin/env bash
# Ảnh chụp màn hình Google Play (R2): 6 màn x {light, dark} x {vi, en}, 1080x1920 -> design/store/play/<vi|en>/.
# Dựng từ app thật trong widget test (font Be Vietnam Pro cố định, dữ liệu mẫu) - chạy lại khi đổi UI.
# --pro (M2b): dựng app La bàn Pro (LoaiApp.pro) -> design/store/pro/<vi|en>/ cho listing com.tsudev.laban.pro.
set -euo pipefail
cd "$(dirname "$0")/../../packages/app_shell"
export PATH="$HOME/tools/flutter/bin:$PATH"
thu=play
co=()
for a in "$@"; do
  if [ "$a" = "--pro" ]; then
    thu=pro
    co+=(--dart-define=PRO=true)
  else
    co+=("$a")
  fi
done
flutter test test_store --update-goldens "${co[@]+"${co[@]}"}"
# Play nhận PNG 24-bit (không alpha) -> bỏ kênh alpha (nền app luôn đặc).
for f in ../../design/store/"$thu"/*/*.png; do
  "$HOME/tools/ffmpeg" -loglevel error -y -i "$f" -pix_fmt rgb24 "$f.rgb.png" && mv "$f.rgb.png" "$f"
done
ls -1 ../../design/store/"$thu"/*/
