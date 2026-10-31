#!/usr/bin/env bash
# Ảnh chụp màn hình Google Play (R2): 6 màn x {light, dark} x {vi, en}, 1080x1920 -> design/store/play/<vi|en>/.
# Dựng từ app thật trong widget test (font Be Vietnam Pro cố định, dữ liệu mẫu) - chạy lại khi đổi UI.
set -euo pipefail
cd "$(dirname "$0")/../../app"
export PATH="$HOME/tools/flutter/bin:$PATH"
flutter test test_store --update-goldens "$@"
# Play nhận PNG 24-bit (không alpha) -> bỏ kênh alpha (nền app luôn đặc).
for f in ../design/store/play/*/*.png; do
  "$HOME/tools/ffmpeg" -loglevel error -y -i "$f" -pix_fmt rgb24 "$f.rgb.png" && mv "$f.rgb.png" "$f"
done
ls -1 ../design/store/play/*/
