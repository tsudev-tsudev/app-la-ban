# Đóng góp mã - La bàn

Quy trình phase / agent: `AGENTS_KICKOFF.md`. Luật kỹ thuật: `CLAUDE.md`.

## Nhánh, commit, PR
- Nhánh `phase/<mã>` (hoặc `fix/<việc>`), PR base `main`, squash merge. Không xếp chồng PR.
- Conventional Commits, tiêu đề <= 95 ký tự. Chỉ dùng gạch nối ASCII `-`.
- Trước merge: `./tools/kiem-tra/cong.sh day-du` xanh.
- Hook pre-commit (`git config core.hooksPath tools/hooks`): đồng bộ AGENTS.md, chặn tài liệu gốc, chặn em/en dash, quét bí mật.

## Quy định comment (từ hướng dẫn che comment production)
Dev được comment thoải mái để giải thích mã. Bản build web production tự động xoá 100% comment, console, debugger, sourcemap
(kiểm bằng `tools/kiem-tra/ve-sinh-ban-build.mjs`); không ai phải xoá tay.

**Tuyệt đối KHÔNG ghi trong comment (mọi ngôn ngữ, mọi môi trường):**
- Logic bảo mật phía server (ngưỡng chấm điểm, cách xác minh, luật phân quyền chi tiết).
- Đường dẫn / thư mục nội bộ của máy chủ, tên tài nguyên hạ tầng, connection string.
- Tài khoản thử, mật khẩu mẫu, API key, token (kể cả "chỉ để test").
- Ghi chú kiểu "tạm tắt kiểm tra", "bypass để test".

Thông tin nhạy cảm để ở `wrangler secret` / `.dev.vars` (gitignore) / `~/.config/la-ban/`. Ghi chú kỹ thuật dài để ở `docs/`.

## Phụ thuộc
Không thêm SDK / gói mới ngoài QUYET_DINH.md nếu chưa hỏi chủ dự án (ảnh hưởng Data Safety / Privacy Manifest).
npm 11 chặn script cài đặt: gói mới cần script phải `npm install-scripts approve <gói>` có lý do.
