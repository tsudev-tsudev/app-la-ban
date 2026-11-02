# Trạng thái SỐNG - quy trình: AGENTS_KICKOFF.md · lệnh: `./agents.sh help`

## LOCKS (chỉ tệp ĐANG sửa - xoá ngay khi xong)

## Lưu ý đang hiệu lực (<= 8 dòng)
- WRANGLER OAUTH SAI TAI KHOAN: luon 'set -a; . ~/.config/la-ban/cf.env; set +a' (source tran KHONG export) truoc moi lenh wrangler (OAuth may dang o tai khoan repo khac -> secret put tao Worker rac). find WRANGLER OAUTH
- GITLEAKS CHUA CAI: cong.sh bo qua gitleaks khi khong co lenh; secretlint khong bat JWT -> cong co buoc git grep JWT rieng. Test can token thi ghep luc chay. find GITGUARDIAN
- PHAT HANH APK: tăng version pubspec + phienBanApp -> PR -> ./tools/build/phat-hanh-apk.sh (main sạch) -> deploy-web.sh landing. Khoá upload ~/.config/la-ban/android/ NGOÀI repo. find PHAT HANH APK
- GRADLE HOME + GH TOKEN: export GRADLE_USER_HOME=~/tools/java/gradle-home; gh: GH_TOKEN=$(gh auth token --user tsudev-tsudev) (active account khác). find GRADLE HOME
- FLUTTER: PATH=$HOME/tools/flutter/bin (3.47.8, Dart 3.13 - constructor 'const new(...)'); JAVA_HOME=~/tools/java/jdk, ANDROID_HOME=~/tools/android-sdk. Mot 'flutter pub get' o GOC (pub workspace). find DART 3.13
- NODE 24: luon nvm use (.nvmrc); Node 20 mac dinh may khong chay astro 7 / vitest 5. Tai lieu goc 2026*.md KHONG commit. find NODE 24
- SSL SUBDOMAIN 2 CAP: Universal SSL cua Cloudflare KHONG phu *.compass.tsudev.com - dung ten 1 cap compass-api. / compass-admin. (QUYET_DINH Q2). find SSL SUBDOMAIN
- IOS CAN MACOS: WSL khong build duoc iOS - xem QUYET_DINH Q6 truoc phase R2. find IOS CAN MACOS
- CONG DEV 3030 / 3031 / 8797 rieng repo nay - KHONG dung 3008 (ubnd) / 3010 (ban-do-3d). find CONG DEV

> Board = TRẠNG THÁI SỐNG, chỉ ghi CÁI BẪY + từ khoá; bản đầy đủ: `./agents.sh find "<từ khoá>"`.
