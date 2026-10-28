# AGENTS_LOG.md - nhật ký app "La bàn" (append-only · tra bằng `./agents.sh find` · ĐỪNG đọc cả tệp)

Chỉ ghi thứ GIT KHÔNG thấy: quyết định, bẫy, kết quả đo. Ghi bằng `./agents.sh log '...'` rồi COMMIT ngay.
Format: `[YYYY-MM-DD HH:MM] agent-X | LOẠI | nội dung` - LOẠI ∈ {QUYẾT ĐỊNH, GOTCHA, TEST, KHÁC}. Phiếu bàn giao: mã `HGLB-...`.

---
[2026-10-28 09:41] agent-laban | QUYẾT ĐỊNH | 28/10 lập bộ tài liệu điều phối + 2 kế hoạch (26 phase N/A/S/R/M). Người dùng đồng ý toàn bộ phương án mặc định QUYET_DINH (Q2 subdomain 1 cấp compass-api./compass-admin., Q6 Codemagic, Q22 Workers Paid khi production...). Backend Cloudflare thay K8s/Postgres của spec. find CHUA CO GIT / SSL SUBDOMAIN / IOS CAN MACOS / CONG DEV
[2026-10-28 09:41] agent-laban | BÀN GIAO HGLB-1028-094113 → agent-laban | Phase N0 | Làm N0 theo docs/ke-hoach/KE_HOACH_TONG_THE_LA_BAN.md mục 4: git init + repo GitHub private, FVM Flutter vào ~/tools, khung monorepo, cong.sh, gitleaks. Commit đầu gồm cả tài liệu điều phối (tài liệu gốc 2026*.md đã gitignore).
[2026-10-28 10:29] agent-laban | GOTCHA | N0 phiên 1 (main a41e1e7, repo tsudev-tsudev/app-la-ban private): mạng ~20 KB/s tới storage.googleapis.com -> Flutter SDK chưa tải xong, bước flutter create/test dời sang phiên sau. Node 24 cho repo (astro 7/vitest 5 cần >=22), npm 11 install-scripts (esbuild, workerd approve), TS ghim 6.0. Tải binary gitleaks/osv-scanner bị chặn quyền -> secretlint + npm audit. Branch protection cần GitHub Pro (403) -> quy tắc PR chỉ theo quy trình. Git identity đặt cục bộ (Dev Tsu). find MANG CHAM / NODE 24
[2026-10-28 10:29] ĐÓNG HGLB-1028-094113
[2026-10-28 10:29] agent-laban | BÀN GIAO HGLB-1028-102936 → agent-laban | Phase N0 (phần còn lại) | Khi ~/tools/flutter có bin/cache/flutter.version.json: (1) cd app && flutter create --platforms android,ios --org com.tsudev --project-name la_ban . (GIỮ lib/ + test/ đã có); (2) flavor dev/staging/prod: applicationId com.tsudev.laban[.dev|.stg], tên app theo Flavor, iOS scheme; (3) flutter pub get ở gốc + analyze --fatal-infos + test; (4) cong.sh day-du xanh; (5) cập nhật Tiến độ N0 = ✅, xoá lưu ý FLUTTER DANG TAI. Nhánh phase/n0-flutter -> PR base main.
