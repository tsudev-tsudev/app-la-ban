# PHIẾU YÊU CẦU - CI bảo mật tối thiểu cho tsudev-tsudev/app-la-ban (AN1)

- **Mã phiếu**: 20261118-AN1C
- **Từ**: phiên điều phối `~/projects` (projects-25), 18/11/2026
- **Đến**: phiên kế tiếp của repo này
- **Trạng thái**: MỞ
- **Nối tiếp**: `~/projects/logs/handover/20261118-AN1_yeu-cau-ra-quet-va-va-lo-hong-toan-he.md` ("Lượt rà 3")

## 1. Phát hiện (đo 18/11/2026 qua API trên nhánh mặc định)

- Repo KHÔNG có `.github/workflows/` nào ⇒ không có cổng chạy trên GitHub cho PR (kể cả PR Dependabot): không gitleaks, không
  `npm audit`, không typecheck/test/build trước khi gộp.
- compass.tsudev.com: HSTS thiếu `preload` (các site tsudev khác có) - thêm cho đồng bộ.

## 2. Yêu cầu

1. Thêm `.github/workflows/ci.yml` theo chuẩn tsudev (`.standards`): `permissions: contents: read` cấp workflow, action ghim
   SHA + chú thích phiên bản (`~/projects/logs/tools/ghim_sha.py`), các job: lint + typecheck + test + build; gitleaks bằng
   binary ghim sha256 (KHÔNG `gitleaks/gitleaks-action`); `npm audit --omit=dev --audit-level=high` (site/app tĩnh - quyết
   định phương án (a) của chủ dự án; picomatch dev đã chấp nhận có hạn 31/12/2026).
2. `.github/dependabot.yml` (npm + github-actions, hằng tuần, gom nhóm minor/patch).
3. Kiểm bằng `python3 ~/projects/logs/tools/quet_workflow.py .github/workflows` ⇒ 0 vấn đề, rồi PR; CI xanh mới gộp.
4. Sau khi gộp: chủ dự án đặt check CI thành bắt buộc (repo cá nhân công khai ⇒ ruleset dùng được).
5. Xong ghi một dòng vào phiếu AN1 ở `~/projects/logs/handover/`.
