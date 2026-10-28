# AGENTS_LOG.md - nhật ký app "La bàn" (append-only · tra bằng `./agents.sh find` · ĐỪNG đọc cả tệp)

Chỉ ghi thứ GIT KHÔNG thấy: quyết định, bẫy, kết quả đo. Ghi bằng `./agents.sh log '...'` rồi COMMIT ngay.
Format: `[YYYY-MM-DD HH:MM] agent-X | LOẠI | nội dung` - LOẠI ∈ {QUYẾT ĐỊNH, GOTCHA, TEST, KHÁC}. Phiếu bàn giao: mã `HGLB-...`.

---
[2026-10-28 09:41] agent-laban | QUYẾT ĐỊNH | 28/10 lập bộ tài liệu điều phối + 2 kế hoạch (26 phase N/A/S/R/M). Người dùng đồng ý toàn bộ phương án mặc định QUYET_DINH (Q2 subdomain 1 cấp compass-api./compass-admin., Q6 Codemagic, Q22 Workers Paid khi production...). Backend Cloudflare thay K8s/Postgres của spec. find CHUA CO GIT / SSL SUBDOMAIN / IOS CAN MACOS / CONG DEV
[2026-10-28 09:41] agent-laban | BÀN GIAO HGLB-1028-094113 → agent-laban | Phase N0 | Làm N0 theo docs/ke-hoach/KE_HOACH_TONG_THE_LA_BAN.md mục 4: git init + repo GitHub private, FVM Flutter vào ~/tools, khung monorepo, cong.sh, gitleaks. Commit đầu gồm cả tài liệu điều phối (tài liệu gốc 2026*.md đã gitignore).
